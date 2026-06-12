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

  /// Groq API key. Passed at build time: --dart-define=GROQ_API_KEY=gsk_...
  /// (Interim: the app calls Groq directly. For production, move behind a
  /// Cloudflare Worker / proxy and remove this — the key is extractable from
  /// the APK.)
  static const String groqApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  /// Groq model — Llama 3.3 70B (excellent multilingual incl. Vietnamese).
  static const String groqModel = 'llama-3.3-70b-versatile';

  /// Cloudflare Worker proxy URL (production path — keeps the key server-side).
  /// --dart-define=GROQ_PROXY_URL=https://second-brain-groq.<acct>.workers.dev
  /// When set, the app calls this instead of Groq directly (no key in the app).
  static const String groqProxyUrl =
      String.fromEnvironment('GROQ_PROXY_URL', defaultValue: '');

  /// True when the cloud (Groq) engine is usable — via the proxy (preferred)
  /// or a direct build-time key (interim/test).
  static bool get cloudConfigured =>
      groqProxyUrl.isNotEmpty || groqApiKey.isNotEmpty;

  /// Prefer the proxy when configured (key never ships in the app).
  static bool get useProxy => groqProxyUrl.isNotEmpty;

  /// Free tier: max reflections per day. 0 = UNLIMITED.
  /// Journaling is a daily-habit app — we don't cap the core action. Premium
  /// monetizes via deeper features (monthly Wrapped, trend graphs, insights),
  /// not by limiting reflections.
  static const int freeReflectionsPerDay = 0;

  /// Minimum device RAM (MB) to attempt on-device AI. Below this → cloud only.
  static const int minRamMbForOnDevice = 3800; // ~4GB devices

  /// RAM (MB) at/above which we use the larger, higher-quality on-device model.
  static const int ramMbForLargeModel = 6000; // 6GB+ → Gemma 4 E2B / Phi-4 Mini

  /// Default value for the "on-device only" privacy toggle.
  static const bool privacyModeDefault = false;
}
