/// Static app configuration and feature flags.
///
/// Only NON-secret, client-safe values belong here. The Groq API key lives
/// server-side in the Cloud Function — never in the app.
class AppConfig {
  AppConfig._();

  /// RevenueCat public SDK key (safe to ship in the client).
  /// Replace with your real key from the RevenueCat dashboard.
  static const String revenueCatAndroidKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY', defaultValue: '');

  /// The entitlement id configured in RevenueCat that unlocks premium.
  static const String premiumEntitlementId = 'premium';

  /// Free tier: how many reflections per day (enforced client + server side).
  static const int freeReflectionsPerDay = 5;

  /// Minimum device RAM (MB) to attempt on-device AI. Below this → cloud only.
  static const int minRamMbForOnDevice = 3800; // ~4GB devices

  /// RAM (MB) at/above which we use the larger, higher-quality on-device model.
  static const int ramMbForLargeModel = 6000; // 6GB+ → Gemma 4 E2B / Phi-4 Mini

  /// Default value for the "on-device only" privacy toggle.
  static const bool privacyModeDefault = false;
}
