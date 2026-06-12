import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../../core/env/app_config.dart';
import '../models/chat_message.dart';
import '../models/reflection.dart';
import 'ai_service.dart';

/// Which on-device model tier a device can run.
enum ModelTier {
  /// 6GB+ RAM → larger, higher-quality model (Gemma 4 E2B).
  large,

  /// ~4GB RAM → universal floor (Gemma 3 1B, ~530MB).
  small,

  /// <4GB or unsupported → cannot run on-device; use cloud fallback.
  unsupported,
}

/// Model files per tier (LiteRT community builds on Hugging Face).
/// Gemma weights require accepting the license — pass a HF token via
/// --dart-define=HUGGINGFACE_TOKEN=... (see FlutterGemma.initialize in main).
class _TierModel {
  const _TierModel(this.url, this.modelType);
  final String url;
  final ModelType modelType;
}

// Gemma 3 1B IT — good Vietnamese, ~600MB, runs on 4GB+ RAM devices.
// Downloads WITHOUT a Hugging Face token. Use .task (MediaPipe) format.
const _models = <ModelTier, _TierModel>{
  ModelTier.small: _TierModel(
    'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q8_ekv1280.task',
    ModelType.gemmaIt,
  ),
  ModelTier.large: _TierModel(
    'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q8_ekv1280.task',
    ModelType.gemmaIt,
  ),
};

/// PRIMARY engine: runs a small LLM fully on-device via flutter_gemma.
/// Free forever, offline, and the journal text never leaves the phone.
class OnDeviceAiService implements AiService {
  OnDeviceAiService();

  ModelTier? _tier;
  InferenceModel? _model;

  /// Platform channel to a tiny native method that returns total device RAM
  /// in MB (see android/.../MainActivity.kt → getTotalRamMb).
  static const _deviceChannel = MethodChannel('second_brain/device');

  /// Detect the device's capability tier from available RAM.
  Future<ModelTier> detectTier() async {
    if (_tier != null) return _tier!;
    int ramMb = 0;
    try {
      ramMb = await _deviceChannel.invokeMethod<int>('getTotalRamMb') ?? 0;
    } catch (_) {
      ramMb = 0; // unknown → be conservative (treat as unsupported → cloud)
    }
    if (ramMb >= AppConfig.ramMbForLargeModel) {
      _tier = ModelTier.large;
    } else if (ramMb >= AppConfig.minRamMbForOnDevice) {
      _tier = ModelTier.small;
    } else {
      _tier = ModelTier.unsupported;
    }
    return _tier!;
  }

  Future<bool> get canRunOnDevice async =>
      (await detectTier()) != ModelTier.unsupported;

  /// Download (first run) + load the model and keep it warm.
  /// Call from onboarding with a progress UI (0..1).
  Future<void> ensureModel({void Function(double progress)? onProgress}) async {
    if (_model != null) return;
    final tier = await detectTier();
    if (tier == ModelTier.unsupported) throw const OnDeviceUnsupported();
    final spec = _models[tier]!;

    await FlutterGemma.installModel(modelType: spec.modelType)
        .fromNetwork(spec.url)
        .withProgress((p) => onProgress?.call(p / 100.0))
        .install();

    _model = await FlutterGemma.getActiveModel(
      // ekv1280 build → match the model's cache size to avoid the OpenCL warning.
      maxTokens: 1280,
      // CPU backend: safest across all devices; GPU may be faster but less
      // stable on some Mali/Adreno chips. Switch to PreferredBackend.gpu
      // only after testing on target hardware.
      preferredBackend: PreferredBackend.cpu,
    );
  }

  @override
  Future<Reflection> reflect(String entryText, {String? language}) async {
    final raw = await _generate(
      AiPrompts.reflectInstruction(entryText, language: language),
    );
    final json = extractJson(raw);
    if (json.isEmpty || (json['reflection'] ?? '').toString().isEmpty) {
      throw const OnDeviceBadOutput();
    }
    return Reflection.fromJson(json, source: AiSource.onDevice);
  }

  @override
  Future<({String headline, String narrative})> weeklyNarrative({
    required Map<String, dynamic> stats,
    required List<String> snippets,
    String? language,
  }) async {
    final raw = await _generate(
      AiPrompts.weeklyInstruction(stats, snippets, language: language),
    );
    final json = extractJson(raw);
    final narrative = (json['narrative'] ?? '').toString();
    if (narrative.isEmpty) throw const OnDeviceBadOutput();
    return (
      headline: (json['headline'] ?? '').toString(),
      narrative: narrative,
    );
  }

  /// Generate a JSON response (reflection / weekly narrative).
  Future<String> _generate(String prompt) async {
    await ensureModel();
    final chat = await _model!.createChat(
      systemInstruction:
          'You return ONLY a single valid JSON object. No prose, no code fences.',
    );
    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    final response = await chat.generateChatResponse();
    return response.toString();
  }

  /// Generate a natural-text response (conversation mode).
  Future<String> _generateText(String prompt) async {
    await ensureModel();
    final chat = await _model!.createChat(
      systemInstruction: AiPrompts.conversationPersona,
    );
    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    final response = await chat.generateChatResponse();
    return response.toString().trim();
  }

  @override
  Future<String> chat(List<ChatMessage> history, {String? language}) async {
    final prompt = AiPrompts.chatInstruction(history, language: language);
    return _generateText(prompt);
  }

  /// Release the model (e.g. on low-memory warnings).
  Future<void> dispose() async {
    _model = null;
  }

  /// Small models sometimes wrap JSON in prose / code fences. Extract the first
  /// balanced {...} object and parse it. Backstop when constrained decoding
  /// isn't available.
  static Map<String, dynamic> extractJson(String raw) {
    final start = raw.indexOf('{');
    if (start == -1) return {};
    var depth = 0;
    var inString = false;
    for (var i = start; i < raw.length; i++) {
      final c = raw[i];
      if (c == '"' && (i == 0 || raw[i - 1] != r'\')) inString = !inString;
      if (inString) continue;
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) {
          try {
            return jsonDecode(raw.substring(start, i + 1))
                as Map<String, dynamic>;
          } catch (_) {
            return {};
          }
        }
      }
    }
    return {};
  }
}

/// Thrown when the device cannot run on-device AI (route to cloud instead).
class OnDeviceUnsupported implements Exception {
  const OnDeviceUnsupported();
  @override
  String toString() => 'Device cannot run the on-device model.';
}

/// Thrown when the on-device model returned unusable output (router may retry
/// or fall back to cloud when allowed).
class OnDeviceBadOutput implements Exception {
  const OnDeviceBadOutput();
  @override
  String toString() => 'On-device model returned invalid output.';
}
