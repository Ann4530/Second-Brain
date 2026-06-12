import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/env/app_config.dart';
import '../models/reflection.dart';
import 'ai_service.dart';
import 'on_device_ai_service.dart' show OnDeviceAiService;

/// CLOUD engine: Groq (Llama 3.3 70B) — excellent multilingual quality,
/// including Vietnamese (the small on-device model garbles some characters).
///
/// INTERIM: calls the Groq API directly with a build-time key
/// (`--dart-define=GROQ_API_KEY=...`). For production, move this behind a
/// proxy (Cloudflare Worker) and drop the key from the client — it is
/// extractable from the APK.
class GroqAiService implements AiService {
  GroqAiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  Future<String> _chat(String prompt) async {
    if (!AppConfig.cloudConfigured) {
      throw const GroqUnavailable('Cloud engine not configured.');
    }
    // Decode bytes as UTF-8 explicitly so Vietnamese diacritics are correct.
    return AppConfig.useProxy ? _viaProxy(prompt) : _direct(prompt);
  }

  /// Production path: POST { prompt } to the Cloudflare Worker, which holds the
  /// Groq key. Returns { content }.
  Future<String> _viaProxy(String prompt) async {
    final res = await _client.post(
      Uri.parse(AppConfig.groqProxyUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt}),
    );
    if (res.statusCode != 200) {
      throw GroqUnavailable('Proxy HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['content'] ?? '').toString();
  }

  /// Interim/test path: call Groq directly with a build-time key.
  Future<String> _direct(String prompt) async {
    final res = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer ${AppConfig.groqApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': AppConfig.groqModel,
        'messages': [
          {
            'role': 'system',
            'content':
                'You return ONLY a single valid JSON object. No prose, no code fences. '
                    'Reply in the same language the user wrote in.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.7,
        'max_tokens': 900,
        'response_format': {'type': 'json_object'},
      }),
    );
    if (res.statusCode != 200) {
      throw GroqUnavailable('Groq HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw const GroqUnavailable('Groq returned no choices.');
    }
    return ((choices.first as Map)['message']['content'] ?? '').toString();
  }

  @override
  Future<Reflection> reflect(String entryText, {String? language}) async {
    final raw = await _chat(
      AiPrompts.reflectInstruction(entryText, language: language),
    );
    final json = OnDeviceAiService.extractJson(raw);
    if ((json['reflection'] ?? '').toString().isEmpty) {
      throw const GroqUnavailable('Groq returned an unusable reflection.');
    }
    return Reflection.fromJson(json, source: AiSource.cloud);
  }

  @override
  Future<({String headline, String narrative})> weeklyNarrative({
    required Map<String, dynamic> stats,
    required List<String> snippets,
    String? language,
  }) async {
    final raw = await _chat(
      AiPrompts.weeklyInstruction(stats, snippets, language: language),
    );
    final json = OnDeviceAiService.extractJson(raw);
    return (
      headline: (json['headline'] ?? '').toString(),
      narrative: (json['narrative'] ?? '').toString(),
    );
  }
}

/// Thrown when the cloud engine can't be used (not configured, offline, or a
/// non-200 response). The router catches it and falls back to on-device.
class GroqUnavailable implements Exception {
  const GroqUnavailable(this.message);
  final String message;
  @override
  String toString() => 'GroqUnavailable: $message';
}
