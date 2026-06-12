import 'package:flutter/material.dart';

/// Design system. Also used to render the shareable "Wrapped" insight card,
/// so keep brand colors here in one place.
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF5B6CFF); // calm indigo
  static const Color accent = Color(0xFFFF9F68); // warm amber accent

  // "Cosmic" theme — deep space violet.
  static const Color cosmicSeed = Color(0xFF8B5CF6);
  static const Color cosmicBg = Color(0xFF07061A); // deep space
  static const Color cosmicSurface = Color(0xFF14122E);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  /// A distinct dark, space-y theme (violet/indigo on near-black with a hint
  /// of purple), applied regardless of the system brightness.
  static ThemeData get cosmic {
    final scheme = ColorScheme.fromSeed(
      seedColor: cosmicSeed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: cosmicSurface,
      primary: const Color(0xFFB794FF),
      secondary: const Color(0xFFF472B6), // nebula pink accent
    );
    return _themeFrom(scheme, scaffold: cosmicBg, appBar: cosmicBg);
  }

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return _themeFrom(scheme, scaffold: scheme.surface, appBar: scheme.surface);
  }

  static ThemeData _themeFrom(
    ColorScheme scheme, {
    required Color scaffold,
    required Color appBar,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: appBar,
        elevation: 0,
        centerTitle: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
