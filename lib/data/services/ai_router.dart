import '../models/reflection.dart';
import 'ai_service.dart';
import 'groq_ai_service.dart';
import 'on_device_ai_service.dart';

/// Decides whether a given task runs on-device (free, private) or on the cloud
/// (Groq — higher quality / fallback), based on:
///  - device capability (RAM tier),
///  - the user's "on-device only" privacy toggle,
///  - whether the user is premium (premium weekly recap → cloud for quality).
class AiRouter implements AiService {
  AiRouter({
    required OnDeviceAiService onDevice,
    required GroqAiService cloud,
    required this.privacyModeOnly,
    required this.isPremium,
  })  : _onDevice = onDevice,
        _cloud = cloud;

  final OnDeviceAiService _onDevice;
  final GroqAiService _cloud;

  /// User toggled "never call the cloud".
  final bool privacyModeOnly;

  /// Premium unlocks cloud-quality weekly recaps.
  final bool isPremium;

  /// Daily reflection: prefer on-device (private + free). Fall back to cloud
  /// only when the device can't run a model AND privacy mode is off.
  /// One retry on bad on-device output, then cloud (if allowed).
  @override
  Future<Reflection> reflect(String entryText, {String? language}) async {
    if (await _onDevice.canRunOnDevice) {
      try {
        return await _onDevice.reflect(entryText, language: language);
      } on OnDeviceBadOutput {
        try {
          return await _onDevice.reflect(entryText, language: language);
        } on OnDeviceBadOutput {
          if (privacyModeOnly) rethrow;
          return _cloud.reflect(entryText, language: language);
        }
      }
    }
    if (privacyModeOnly) {
      throw const OnDeviceUnsupported(); // surface "device too weak" to the UI
    }
    return _cloud.reflect(entryText, language: language);
  }

  /// Weekly narrative: premium + cloud-allowed → cloud (Llama 70B) for quality;
  /// otherwise on-device. Always on-device when privacy mode is on.
  @override
  Future<({String headline, String narrative})> weeklyNarrative({
    required Map<String, dynamic> stats,
    required List<String> snippets,
  }) async {
    final canDevice = await _onDevice.canRunOnDevice;
    final preferCloud = isPremium && !privacyModeOnly;
    if (preferCloud || !canDevice) {
      if (privacyModeOnly && canDevice) {
        return _onDevice.weeklyNarrative(stats: stats, snippets: snippets);
      }
      return _cloud.weeklyNarrative(stats: stats, snippets: snippets);
    }
    return _onDevice.weeklyNarrative(stats: stats, snippets: snippets);
  }
}
