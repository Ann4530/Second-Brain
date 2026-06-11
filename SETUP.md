# SETUP — Hướng dẫn cài đặt & build (đã kiểm chứng trên máy này)

> Trạng thái: **ĐÃ BUILD THÀNH CÔNG** → `build\app\outputs\flutter-apk\app-debug.apk`
> `flutter analyze` = 0 lỗi · `flutter test` = 16/16 pass.

Tài liệu này ghi lại **đúng** cách môi trường đã được dựng (không phải hướng dẫn chung chung).
Mọi thứ đặt trên **ổ D:** vì ổ C: gần đầy (chỉ còn ~2GB).

---

## 0. Đã cài sẵn ở đâu

| Thành phần | Vị trí | Ghi chú |
|---|---|---|
| Flutter SDK 3.44.1 (Dart 3.12.1) | `D:\flutter` | clone stable, `--depth 1` |
| Android SDK | `D:\android-sdk` | cmdline-tools + platform-tools + platforms;android-35 + build-tools;35.0.0 **và** 36.0.0 |
| Gradle cache | `D:\gradle` | `GRADLE_USER_HOME` (KHÔNG để mặc định trên C:) |
| pub cache | `D:\flutter\.pub-cache` | `PUB_CACHE` |
| Build temp | `D:\temp` | `TEMP`/`TMP` |
| JDK 17 (Temurin) | hệ thống | có sẵn, `java` trên PATH |
| Git 2.51 | hệ thống | có sẵn |

## 1. Biến môi trường (đã set ở cấp User — terminal MỚI tự nhận)

```powershell
# Đã chạy sẵn — chỉ cần lại nếu dựng máy mới:
[Environment]::SetEnvironmentVariable('Path', "$([Environment]::GetEnvironmentVariable('Path','User'));D:\flutter\bin", 'User')
[Environment]::SetEnvironmentVariable('PUB_CACHE',        'D:\flutter\.pub-cache', 'User')
[Environment]::SetEnvironmentVariable('GRADLE_USER_HOME', 'D:\gradle',             'User')
[Environment]::SetEnvironmentVariable('ANDROID_HOME',     'D:\android-sdk',        'User')
[Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', 'D:\android-sdk',        'User')
```

> ⚠️ Tiến trình ĐANG chạy không tự cập nhật các biến này. Trong script/CI, **set thẳng**
> `$env:GRADLE_USER_HOME='D:\gradle'` (v.v.) trước khi gọi `flutter build` — xem §4.

## 2. Tinh chỉnh đã áp vào project (để build qua được trên Windows)

- **`android/app/build.gradle.kts`**
  - `minSdk = 24` (flutter_gemma + Firebase cần ≥24).
  - Bật core library desugaring (cho `flutter_local_notifications`):
    `isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.
- **`android/gradle.properties`** (thêm vào cuối):
  ```properties
  org.gradle.parallel=false
  org.gradle.workers.max=1
  kotlin.incremental=false
  kotlin.compiler.execution.strategy=in-process
  ```
  Lý do: chạy tuần tự + Kotlin compiler in-process **tránh lỗi** "Could not close incremental
  caches / Daemon compilation failed" do Windows Defender khóa file cache `.tab`.
- **`android/app/src/main/AndroidManifest.xml`**: thêm quyền INTERNET, RECORD_AUDIO,
  POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED.
- **`android/.../MainActivity.kt`**: MethodChannel `second_brain/device` trả RAM (chọn model tier).
- **`pubspec.yaml`**: đã bỏ `riverpod_annotation`/`riverpod_generator`/`build_runner`/`custom_lint`/
  `riverpod_lint` (dùng provider thủ công, KHÔNG codegen → KHÔNG cần `build_runner`).

## 3. Kiểm tra code (nhanh, không cần Android SDK)

```powershell
cd D:\anhhp\xxx
D:\flutter\bin\flutter.bat pub get
D:\flutter\bin\flutter.bat analyze      # kỳ vọng: No issues found!
D:\flutter\bin\flutter.bat test         # kỳ vọng: 16/16 pass
```

## 4. Build APK (lệnh ĐÃ chạy thành công)

```powershell
$env:GRADLE_USER_HOME='D:\gradle'
$env:ANDROID_HOME='D:\android-sdk'; $env:ANDROID_SDK_ROOT='D:\android-sdk'
$env:TEMP='D:\temp'; $env:TMP='D:\temp'
cd D:\anhhp\xxx
D:\flutter\bin\flutter.bat build apk --debug --target-platform android-arm64
# Ra: build\app\outputs\flutter-apk\app-debug.apk  (~324MB debug; release nhỏ hơn nhiều)
```

> 🛡️ **Lỗi "Failed to delete original file after copy" / "Could not download …"**: do
> Windows Defender khóa file `.jar/.aar` ngay sau khi Gradle tải. File ĐÃ vào cache thành công,
> chỉ xóa file tạm thất bại → **chạy lại lệnh build vài lần**, mỗi lần cache thêm và bỏ qua
> module đã compile, sẽ hội tụ. (Lần đầu mất ~12 lần do tải toàn bộ toolchain; từ lần sau chỉ
> vài chục giây.) Nếu được quyền admin, thêm `D:\gradle` vào loại trừ Defender sẽ hết hẳn.

## 5. Cấu hình thủ công còn lại (trước khi chạy thật / lên store)

1. **Token Hugging Face** (để tải model Gemma — cần chấp nhận license Gemma trên HF):
   ```powershell
   D:\flutter\bin\flutter.bat run --dart-define=HUGGINGFACE_TOKEN=hf_xxx
   ```
2. **Firebase** (tạo `lib/firebase_options.dart`):
   ```powershell
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   flutterfire configure
   ```
   Rồi mở comment khối `Firebase.initializeApp` trong `lib/main.dart`.
3. **Groq API key** → đặt trong Cloud Function (`functions/`), KHÔNG để trong app. Xem `functions/README.md`.
4. **RevenueCat**: tạo project + app Android, entitlement `premium`, gói tháng/năm + dùng thử;
   bỏ public SDK key vào `lib/core/env/app_config.dart`.
5. **firestore.rules** đã có sẵn — deploy: `firebase deploy --only firestore:rules`.

## 6. Chạy / cài lên điện thoại

```powershell
D:\flutter\bin\flutter.bat devices        # liệt kê thiết bị
D:\flutter\bin\flutter.bat install        # cài app-debug.apk lên máy đang cắm
D:\flutter\bin\flutter.bat run            # chạy + log trực tiếp (nên dùng máy thật cho AI)
```

## 7. Build bản phát hành cho Play Store

```powershell
$env:GRADLE_USER_HOME='D:\gradle'; $env:ANDROID_HOME='D:\android-sdk'; $env:TEMP='D:\temp'; $env:TMP='D:\temp'
cd D:\anhhp\xxx
D:\flutter\bin\flutter.bat build appbundle --release
# Ra: build\app\outputs\bundle\release\app-release.aab  (Play Store tách theo máy → tải nhẹ)
```
Cần ký release: tạo keystore + `android/key.properties` + cấu hình `signingConfig` (hiện
release đang ký tạm bằng debug key). Play Console: closed test ≥12 tester × 14 ngày trước production.

---

### Dọn dẹp ổ C: (khuyến nghị — C: chỉ còn ~2GB)
Mọi cache build đã ở D:. Có thể xoá an toàn nếu còn sót trên C::
`C:\Users\AnhNB\.gradle` (đã xoá), thư mục Temp cũ. KHÔNG xoá `D:\flutter`, `D:\android-sdk`, `D:\gradle`.
