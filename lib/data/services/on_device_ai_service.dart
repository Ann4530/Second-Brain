import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../../core/env/app_config.dart';
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

// Qwen2.5 — strong small multilingual (good Vietnamese), downloads WITHOUT a
// Hugging Face token. IMPORTANT: use the `.task` (MediaPipe) format — it loads
// via getActiveModel/EngineFactory. `.litertlm` files need a different FFI path
// and throw "should be handled by Dart FFI" with this API.
const _models = <ModelTier, _TierModel>{
  ModelTier.small: _TierModel(
    // Qwen2.5 0.5B (q8 .task) — ~0.5GB, fast, universal floor.
    'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
    ModelType.qwen,
  ),
  // For now large tier uses the same 0.5B .task (fast download, proven path).
  // To upgrade quality on 6GB+ devices, switch to Qwen2.5-1.5B (.task, ~1.6GB):
  // '.../Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task'
  ModelTier.large: _TierModel(
    'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
    ModelType.qwen,
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
      // CPU backend: the Qwen .task models use INT64 CAST ops that crash the
      // GPU/OpenCL executor on many mobile GPUs (e.g. Mali). CPU is slower but
      // runs everywhere. A 0.5B model is fast enough on a modern SoC.
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

  /// Run one generation on-device. A fresh chat per request keeps outputs
  /// independent (no cross-entry context bleed).
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
