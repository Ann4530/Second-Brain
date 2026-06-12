import '../../core/env/app_config.dart';
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

  /// Cloud is preferred (better quality, esp. Vietnamese) when a Groq key is
  /// configured and the user hasn't forced on-device-only.
  bool get _preferCloud => AppConfig.cloudConfigured && !privacyModeOnly;

  /// Daily reflection.
  /// - Cloud configured + not privacy mode → cloud (Llama 70B) first, with
  ///   on-device fallback if the cloud call fails (e.g. offline).
  /// - Otherwise → on-device first (free + private), cloud only as a last
  ///   resort when the device can't run a model and privacy mode is off.
  @override
  Future<Reflection> reflect(String entryText, {String? language}) async {
    if (_preferCloud) {
      try {
        return await _cloud.reflect(entryText, language: language);
      } on GroqUnavailable {
        if (await _onDevice.canRunOnDevice) {
          return _onDevice.reflect(entryText, language: language);
        }
        rethrow;
      }
    }

    if (await _onDevice.canRunOnDevice) {
      try {
        return await _onDevice.reflect(entryText, language: language);
      } on OnDeviceBadOutput {
        try {
          return await _onDevice.reflect(entryText, language: language);
        } on OnDeviceBadOutput {
          if (privacyModeOnly || !AppConfig.cloudConfigured) rethrow;
          return _cloud.reflect(entryText, language: language);
        }
      }
    }
    if (privacyModeOnly || !AppConfig.cloudConfigured) {
      throw const OnDeviceUnsupported(); // surface "device too weak" to the UI
    }
    return _cloud.reflect(entryText, language: language);
  }

  /// Weekly narrative: cloud (Llama 70B) when configured & allowed, with
  /// on-device fallback; otherwise on-device.
  @override
  Future<({String headline, String narrative})> weeklyNarrative({
    required Map<String, dynamic> stats,
    required List<String> snippets,
    String? language,
  }) async {
    if (_preferCloud) {
      try {
        return await _cloud.weeklyNarrative(
            stats: stats, snippets: snippets, language: language);
      } on GroqUnavailable {
        if (await _onDevice.canRunOnDevice) {
          return _onDevice.weeklyNarrative(
              stats: stats, snippets: snippets, language: language);
        }
        rethrow;
      }
    }
    if (await _onDevice.canRunOnDevice) {
      return _onDevice.weeklyNarrative(
          stats: stats, snippets: snippets, language: language);
    }
    return _cloud.weeklyNarrative(
        stats: stats, snippets: snippets, language: language);
  }
}
