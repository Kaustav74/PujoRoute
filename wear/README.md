# PujoRoute for Wear OS (Samsung Galaxy Watch)

A light, fully offline Wear OS version of the PujoRoute phone app, built with Kotlin and Compose for Wear OS.

- **Galaxy Store package:** `com.pujoroute.wear`. This is separate from the phone app (`com.pujoroute.app`).
- **Standalone:** `com.google.android.wearable.standalone=true`. The app works without a phone and without Google Play Services.
- **No INTERNET permission.** No analytics, no crash reporting, and no GMS, Firebase or Play Services dependencies. Nothing is collected or sent.
- **Location:** only `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`, requested at runtime. Location is used **only while the Nearby, Navigate or Route-setup screen is visible**. The app uses the platform `LocationManager` (fused, GPS or network provider), not FusedLocationProvider. There is no background work.
- **Versions:** minSdk 30, targetSdk 36. versionCode is **1001** (watch codes stay at 1000+ so they never clash with the phone app). versionName is 1.0.0.

## Features (phone feature → watch)

| Phone feature | On the watch |
|---|---|
| Pandal browser (504) | Browse by zone (North / Central / South / Salt Lake). Search by name, landmark, metro or area using voice or keyboard (`RemoteInput`). The detail screen shows category (mega / heritage), zone and area, landmark, nearest metro and line, gate, and a short history. |
| Map / nearby | **Nearby:** the 25 closest pandals, sorted by GPS distance with walk time (75 m/min, as in the phone app). |
| Map navigation | **Navigate:** a compass arrow from the rotation-vector sensor, corrected for magnetic declination, plus distance and walk time. With no compass sensor, the screen shows a cardinal direction instead. **Offline OSM map tiles are not on the watch:** they are too heavy for the storage and screen. The compass replaces them. |
| Circuit studio (route optimizer) | **Route planner:** choose a zone and 3, 5, 8 or 10 stops, starting from your GPS position or the zone centre. Uses a simplified port of `hardened_pujo_optimizer.dart`: greedy nearest-neighbour with a preferred 1200 m hop limit (relaxed to 1800 m, then nearest), followed by 2-opt with the start anchored. Shows the ordered stops, the next stop (tap to navigate), each leg's distance and walk time, and a checkbox to mark each stop done. |
| Pandal Passport | Stamp visited pandals (finishing a route stop also stamps it). Shows your count, level title and the 6 badges from the phone app. Bookmarks are saved separately. Both are stored in SharedPreferences. |
| Metro guide | Lines and their stations, from `metro_graph_service.dart`. Each station lists the pandals for which it is the nearest station, and each pandal shows its station, line and gate. |
| Panjika | Countdown to the next puja day, all 8 days, tithi times and muhurats. Belur Math is the default; Beni Madhab is a toggle. |
| Emergency | Helplines (112, 100, 1073, 1091, 102, 108, 101, 139), police booths and 24x7 hospitals. Every number is **shown as text**, and tapping opens the dialer through `ACTION_DIAL`, so the app needs no CALL_PHONE permission. If the watch has no dialer, a toast asks you to call from your phone. |
| — | **Tile** "Pujo Countdown": the next puja and days left, plus the next route stop. **Complication** "Pujo days left": SHORT_TEXT, updated hourly. |

### Galaxy Watch UX

- `ScalingLazyColumn` with `rotaryScrollableBehavior`, so the bezel and crown scroll every list.
- `TimeText` scrolls away as you scroll. Every screen has a `PositionIndicator` and top and bottom vignettes.
- `SwipeDismissableNavHost`: swipe right to go back.
- True-black AMOLED background. Chips are at least 52 dp tall (above the 48 dp minimum).
- Text wraps or ellipsizes rather than clipping at font scale 1.3. See `screenshots/small_round_384_font130`.
- **Ambient:** the app does not opt into always-on. When the watch dims, the system shows the watch face, and GPS and sensors stop (they are tied to the `RESUMED` lifecycle). The Tile and complication are static ProtoLayout and complication data, so they are ambient-safe.

## Data

The JSON files in `app/src/main/assets/` are generated from the phone app's Dart sources:

```bash
python3 wear/tools/generate_assets.py   # Python 3 stdlib only
```

| Source | Output |
|---|---|
| `Android App/lib/data/puja_calendar_data.dart` | `calendar.json` (Belur Math and Beni Madhab modes) |
| `Android App/lib/data/pujas_data.dart` | `pandals.json` (essential fields, gate rules, history trimmed to about 240 characters) |
| `Android App/lib/services/metro_graph_service.dart` | `metro.json` and the station and line for each pandal |
| `Android App/lib/services/emergency_service.dart` | `emergency.json` |

All dates and times are Kolkata local time. The countdown always uses `Asia/Kolkata`, whatever time zone the watch is set to.

## Build

You need JDK 17 and an Android SDK with platform 36 and build-tools 36. On the shared build box, run `source /opt/pujoroute-android-env.sh` first.

```bash
cd wear
./gradlew testDebugUnitTest   # unit tests + screenshot tests (writes wear/screenshots/)
./gradlew assembleDebug       # app/build/outputs/apk/debug/app-debug.apk
./gradlew assembleRelease     # app/build/outputs/apk/release/app-release.apk (signed) or app-release-unsigned.apk
# Google Play variant (same listing as the phone app):
./gradlew assembleRelease -PwearAppId=com.pujoroute.app
```

### Release signing

The release build reads the **first** `key.properties` it finds:

1. `-PwearKeyProps=/path/to/key.properties`
2. `wear/key.properties` (git-ignored)
3. `/home/box/secure/pujoroute/key.properties` (the build box's secure store)

The file contains `storeFile` (absolute path), `storePassword`, `keyAlias` and `keyPassword`. If none of these files exists, the release APK is **unsigned**.

**Never commit key.properties or any `.jks` file.** Do not use the old `upload-keystore.jks` that was committed in the repo root. Galaxy Store ties future updates to this signing key, so back up the keystore safely.

Release builds are minified with R8 and resource-shrunk. They include ARM ABIs only (arm64-v8a, armeabi-v7a). The only native code is the tiny `libandroidx.graphics.path.so` that comes with Compose.

## Screenshots (JVM, no emulator)

Robolectric native-graphics tests (`ScreenshotTest.kt`) render 12 screens on a black background as round PNGs:

- `screenshots/small_round_384/`: 384×384 px (Galaxy Watch 40 mm class)
- `screenshots/large_round_450/`: 450×450 px (44 mm and larger). Galaxy Store accepts 384×384 or 450×450 round watch screenshots.
- `screenshots/small_round_384_font130/`: font scale 1.3
- `screenshots/contact_sheet_*.png`: overviews

Paparazzi is not used: its only build for the latest SDKs is an alpha. Robolectric (the engine behind Roborazzi) renders reliably here.

## Run on a watch or emulator

- **Emulator:** in Android Studio's Device Manager, create a Wear OS "Small Round" and a "Large Round" device (API 34+). Then run:
  `adb install -r app/build/outputs/apk/debug/app-debug.apk`
  Use the emulator's extended controls to send a fake location and rotary input.
- **Galaxy Watch:**
  1. Turn on Developer options: Settings → About watch → Software → tap "Software version" 5 times.
  2. Turn on ADB debugging and Wireless debugging.
  3. Connect with `adb pair <ip>:<port>` and then `adb connect <ip>:<port>`.
  4. Install with `adb install -r PujoRoute-Wear-1.0.0.apk`.
- **Tile:** long-press the watch face or swipe to Tiles → **+** → "Pujo Countdown".
- **Complication:** long-press the watch face → Customize → Complications → "Pujo days left".

## Galaxy Store notes

- Submit as a **Wear OS standalone** app with the signed APK.
- **Screenshots:** round, 384×384 or 450×450 px (see `screenshots/`).
- **Privacy:** location is used on-device only, while the app is open. Nothing is collected, stored off-device or sent, and the app has no network permission.

## Limitations

- There is no map. The compass, distance and walk time replace the phone app's OSM map, because offline tiles are too heavy for a watch.
- Routes are open walking paths. The watch has no home-bound terminal or metro-hop guidance, which stay in the phone app.
- The data is a snapshot taken at build time. Regenerate the JSON and ship a new build to update it.
- Dialing depends on the watch: LTE watches dial directly, and Bluetooth-only watches need the Samsung Phone setup or show the number to call from your phone.
- Compass accuracy depends on calibration. A figure-8 wrist motion helps.
