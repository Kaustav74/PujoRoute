# 🪔 PujoRoute — Kolkata Durga Puja Companion (Android App)

This folder contains the complete, verified Android application package and ready-to-install APK for **PujoRoute**, optimized specifically for Android smartphones.

---

## 📦 What's in This Folder

- **`PujoRoute.apk`** (**18.5 MB**): Optimized ARM64 release APK with all 504 pandals pre-indexed, dark theme glassmorphism UI, OpenStreetMap offline tile caching, offline session storage, and Puja AI Guide.
- **`app-release.apk`**: Direct Gradle release build mirror (18.5 MB).
- **`lib/`**: Complete Flutter Dart source code (`main.dart`, `models/`, `screens/`, `services/`, `data/`).
- **`android/`**: Native Android wrapper, Gradle configuration, permissions, and manifest (`AndroidManifest.xml`).
- **`assets/`**: Pre-indexed festival datasets and static assets (`assets/data/pujas.json`).
- **`pubspec.yaml`**: Flutter package manifest and dependencies.

---

## 📲 How to Install & Test on Your Mobile Phone

### Step 1: Transfer the APK to Your Phone
Choose any convenient method:
- **Option A (USB Cable)**: Connect your phone to your PC, open File Explorer, and copy `PujoRoute.apk` to your phone's `Download` or `Internal Storage` folder.
- **Option B (WhatsApp / Telegram)**: Send `PujoRoute.apk` to your own chat or saved messages and download it on your phone.
- **Option C (Google Drive)**: Upload `PujoRoute.apk` to your Google Drive and download it onto your mobile device.

### Step 2: Install the APK
1. Open the **Files** or **File Manager** app on your phone and tap **`PujoRoute.apk`**.
2. If Android displays *"For your security, your phone is not allowed to install unknown apps from this source"*:
   - Tap **Settings**.
   - Enable **Allow from this source**.
   - Press the back button.
3. Tap **Install** (or **Update**).
4. Tap **Open** to launch **PujoRoute**!

---

## 🌟 Quality Audit & Verifications Completed

- **Zero Errors / Zero Warnings**: Flutter static analysis passed cleanly with zero errors.
- **Unit & Widget Tests Passed**: 100% test pass rate (`flutter test`).
- **Permissions Configured**:
  - `android.permission.INTERNET`
  - `android.permission.ACCESS_FINE_LOCATION`
  - `android.permission.ACCESS_COARSE_LOCATION`
  - `android:usesCleartextTraffic="true"` (prevents network blocking on Android 9–15)
- **Graceful Location Handling**: If location services are disabled on your device or permission is denied, the app automatically defaults to the South Kolkata Festival Hub (`22.5152, 88.3845`) without crashing.
- **Optimized ARM64 Binary**: Compiled specifically for modern 64-bit Android smartphones, dropping the package footprint from 54 MB to just **18.5 MB**.
