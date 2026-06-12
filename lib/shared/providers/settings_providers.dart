import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reflection language the user picked. `null` = Auto (match what they wrote).
/// Persisted across app restarts via shared_preferences.
final reflectionLanguageProvider =
    StateNotifierProvider<ReflectionLanguageNotifier, String?>(
  (ref) => ReflectionLanguageNotifier(),
);

/// Supported explicit choices (label shown in Settings → value sent to the AI).
const reflectionLanguageOptions = <String, String?>{
  'Auto (match my writing)': null,
  'Tiếng Việt': 'Vietnamese',
  'English': 'English',
};

class ReflectionLanguageNotifier extends StateNotifier<String?> {
  ReflectionLanguageNotifier() : super(null) {
    _load();
  }

  static const _key = 'reflection_language';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key); // null if unset → Auto
  }

  Future<void> set(String? language) async {
    state = language;
    final prefs = await SharedPreferences.getInstance();
    if (language == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, language);
    }
  }
}

/// App theme choice. Cosmic is a custom space-y dark theme.
enum AppThemeChoice { system, light, dark, cosmic }

extension AppThemeChoiceLabel on AppThemeChoice {
  String get label => switch (this) {
        AppThemeChoice.system => 'Theo hệ thống',
        AppThemeChoice.light => 'Sáng',
        AppThemeChoice.dark => 'Tối',
        AppThemeChoice.cosmic => 'Vũ trụ 🌌',
      };

  IconData get icon => switch (this) {
        AppThemeChoice.system => Icons.brightness_auto,
        AppThemeChoice.light => Icons.light_mode,
        AppThemeChoice.dark => Icons.dark_mode,
        AppThemeChoice.cosmic => Icons.auto_awesome,
      };
}

final themeChoiceProvider =
    StateNotifierProvider<ThemeChoiceNotifier, AppThemeChoice>(
  (ref) => ThemeChoiceNotifier(),
);

class ThemeChoiceNotifier extends StateNotifier<AppThemeChoice> {
  ThemeChoiceNotifier() : super(AppThemeChoice.system) {
    _load();
  }

  static const _key = 'theme_choice';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    state = AppThemeChoice.values.firstWhere(
      (e) => e.name == v,
      orElse: () => AppThemeChoice.system,
    );
  }

  Future<void> set(AppThemeChoice choice) async {
    state = choice;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, choice.name);
  }
}
