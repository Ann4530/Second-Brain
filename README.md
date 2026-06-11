# Second Brain — AI Reflection Journal (private, on-device first)

A daily AI reflection journal that learns you over time. You speak or type ~2 minutes
about your day; an AI gives you a thoughtful reflection + one nudge **instantly and
privately — running on your phone**. Over weeks it surfaces patterns about you.

- **AI engine:** Hybrid. **On-device** (`flutter_gemma` running Gemma 3 / Gemma 4 / Phi-4 Mini)
  is the primary engine — free forever, offline, data never leaves the phone.
  **Groq cloud** (Llama 3.3 70B, zero data retention) is a fallback for low-RAM devices and
  high-quality premium weekly recaps. **No paid per-call API (no Claude/OpenAI).**
- **Stack:** Flutter (Android first) · Firebase (Auth/Firestore/Functions/FCM/Remote Config/
  Analytics/Crashlytics) · Riverpod · RevenueCat.
- **Monetization:** Freemium + subscription, no ads.

> Full product/build plan: `C:\Users\AnhNB\.claude\plans\gi-p-t-i-x-y-d-ng-breezy-lantern.md`
> **Verified setup/build steps (this machine): see [`SETUP.md`](SETUP.md).**

---

## 1. Toolchain — ALREADY INSTALLED on this machine (on drive D:)

Flutter 3.44.1 (`D:\flutter`), Android SDK (`D:\android-sdk`), JDK 17, Git — all set up.
The build is **verified**: `flutter analyze` = 0 issues, `flutter test` = 16/16,
`flutter build apk` → `build\app\outputs\flutter-apk\app-debug.apk`.

Everything lives on **D:** (C: is nearly full). Env vars `GRADLE_USER_HOME`, `PUB_CACHE`,
`ANDROID_HOME`, plus `D:\flutter\bin` on PATH are set at User level. **Full details +
exact commands + the Windows-Defender file-lock workaround are in [`SETUP.md`](SETUP.md).**

## 2. Quick commands

```powershell
cd D:\anhhp\xxx
D:\flutter\bin\flutter.bat pub get
D:\flutter\bin\flutter.bat analyze    # No issues found!
D:\flutter\bin\flutter.bat test       # 16/16 pass

# Build APK (set Gradle/temp on D: first — see SETUP.md §4)
$env:GRADLE_USER_HOME='D:\gradle'; $env:ANDROID_HOME='D:\android-sdk'; $env:TEMP='D:\temp'; $env:TMP='D:\temp'
D:\flutter\bin\flutter.bat build apk --debug --target-platform android-arm64
```

Note: no `build_runner` step — providers are hand-written (no codegen).
Firebase wiring (`flutterfire configure`) and keys are in **[`SETUP.md`](SETUP.md) §5**.

## 3. Secrets / config you must add

- **Groq API key** — create at https://console.groq.com → put it in the Cloud Function
  config (`functions/`), **never in the app**. See `functions/README.md`.
- **RevenueCat** — create a project + Android app, configure the `premium` entitlement and
  a monthly + annual product with a free trial. Put the public SDK key in
  `lib/core/env/app_config.dart`.
- **Gemma model download** — `flutter_gemma` fetches the model on first run from the
  LiteRT Hugging Face org; Gemma weights require accepting the license / a HF token. See
  `lib/data/services/on_device_ai_service.dart`.

## 4. Run

```powershell
flutter run            # on a real Android device (recommended — on-device LLM needs GPU)
```

> ⚠️ Use a **physical Android device** for AI testing — emulators run on-device LLMs poorly.

## 5. Project layout

```
lib/
  main.dart                     app entry
  app.dart                      MaterialApp.router + theme + ProviderScope
  core/
    env/app_config.dart         keys/flags (RevenueCat public key, etc.)
    router/app_router.dart      go_router routes
    theme/app_theme.dart        design system (also used by the share card)
  data/
    models/                     Entry, EntryMetadata, Reflection, WeeklyRecap
    services/
      on_device_ai_service.dart flutter_gemma wrapper + model tiering (PRIMARY engine)
      groq_ai_service.dart      calls the Cloud Function proxy (FALLBACK / premium)
      ai_router.dart            picks on-device vs cloud (RAM + privacy mode + tier)
    repositories/               entry_repository, reflection_repository
  features/
    onboarding/  journal/  history/  insights/  paywall/  settings/  auth/
  shared/
    providers/                  entitlement_provider, ...
functions/                      Firebase Cloud Functions (Groq proxy, weekly recap)
```

## 6. Status — implemented

- **On-device AI wired** (`flutter_gemma`): model download with progress (onboarding),
  RAM-tiered model choice (Gemma 3 1B on 4GB / Gemma 4 E2B on 6GB+), JSON extraction
  with retry → cloud fallback. Pass a HF token: `flutter run --dart-define=HUGGINGFACE_TOKEN=hf_xxx`
  (Gemma weights require license acceptance on Hugging Face).
- **Native RAM detection**: `android/.../MainActivity.kt` MethodChannel `second_brain/device`.
  Keep the Kotlin package in sync with your `--org` (default `com.yourname`).
- **Encryption at rest**: AES-256-GCM (`cryptography`), key in the platform keystore.
- **Firestore repository**: auto-selected once Firebase is configured + anonymous auth;
  falls back to in-memory in dev.
- **Habit loop**: streak computation (+ chip on Today), daily reminder notification
  (time configurable in Settings).
- **Memory engine**: weekly stats computed in plain Dart (mood-by-weekday,
  mood-with/without-activity, top topics) + AI narrative; Insights screen.
- **Viral loop**: branded "Wrapped" share card (screenshot → share sheet).
- **Billing**: RevenueCat entitlement service (no-ops until the key is set), paywall
  purchase/restore flows.
- **Cloud Functions**: `groqReflect`, `groqWeeklyNarrative`, `deleteAccount` (syntax-checked).

### Done ✅
- Flutter/Android toolchain installed (D:), `flutter analyze` clean, `flutter test` 16/16,
  **debug APK builds** (`build\app\outputs\flutter-apk\app-debug.apk`). See `SETUP.md`.

### Remaining before launch
1. `flutterfire configure` + uncomment `Firebase.initializeApp` in `main.dart` (SETUP.md §5).
2. Groq key in the Cloud Function; RevenueCat products; HF token for the Gemma model.
3. Deploy `firestore.rules`; add a server-side daily cap.
4. Host a privacy policy URL; fill the Play data-safety form.
5. Release signing keystore; build `.aab`; Play Console closed test (12 testers × 14 days).
