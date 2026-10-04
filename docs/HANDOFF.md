# PujoRoute – Release Handoff

## Confirmed features and privacy (for marketing)

**What the app does (all checked against the code):**
- **504 Kolkata Durga Puja pandals** bundled in the app, with zone, style (heritage / theme / mega), nearest metro station and a short cultural note. Search by name, area or metro.
- **Circuit Studio route planner.** It auto-builds a walking route of 3–15 stops from your chosen zone, style and stop count, ordered to cut backtracking (nearest-neighbour + 2-opt). You can also **pick specific pandals yourself** ("Add Pandal to Circuit" in Circuit Studio, or "Add to Circuit" on the map and calendar) and regenerate the route around them. Pandals already stamped in your Passport can be skipped.
- **Pandal Passport.** Mark pandals as visited, unlock badges and share your progress on WhatsApp.
- **Durga Puja 2026 calendar.** Mahalaya (Sat 10 Oct) to Bijoya Dashami (Wed 21 Oct), plus Kojagori Lakshmi Puja, with tithi notes and crowd tips.
- **Kolkata Metro guide.** Blue, Green, Purple and Orange lines with interchanges (no Yellow line data).
- **Emergency section.** Lalbazar Police Control Room 100 / 033-2214-3230, Ambulance 102 / 108, Fire 101, Women helpline 1091, RailMadad 139, plus an optional personal emergency contact and blood group saved on the phone.
- **Directions** open in Google Maps. **Share route** opens WhatsApp.

**Privacy (safe to say publicly):**
- No accounts, no ads, no analytics, no tracking SDKs, and no developer server.
- Pandal data, planner, calendar, metro guide and emergency numbers work **offline**.
- The **map background needs internet**. Tiles load from OpenStreetMap, whose servers see the phone's IP address and the app's user agent.
- Location is used **only while the app is open** and never leaves the phone. The exception is when the user taps Directions: Google Maps then receives the start point.
- All saved data (bookmarks, visited pandals, emergency contact) stays on the device, and "Delete My Data" wipes it.
- Privacy policy: `docs/privacy-policy.html`, to be published at https://kaustav74.github.io/PujoRoute/privacy-policy.html (GitHub Pages → branch `main`, folder `/docs`). Developer: Kaustav Nath, contact: kaustav423@gmail.com.

**Do NOT claim:** "100% offline" (the map needs internet), "AI" (removed), "encrypted storage", "live crowd data", "live weather/news", "voice assistant", or a Yellow line.

---

## Source of truth

- **`Android App/` is the real, working app source.** Build everything from there.
- `app/` is a **stale, broken copy** (its tests do not compile). Do not build from it. Delete it after release.

## Android identifiers

| Item | Value |
|---|---|
| applicationId / namespace | `com.pujoroute.app` |
| versionName / versionCode | `1.0.0` / `1` (from `pubspec.yaml` `version: 1.0.0+1`; bump `+N` for every store upload) |
| minSdk | 24 (Android 7.0) |
| targetSdk | **36** (keep it, do not lower) |
| compileSdk | 36 (buildTools 36.0.0, NDK 27.0.12077973, Java 17) |
| App label | PujoRoute |

## Permissions (final)

| Permission | Why |
|---|---|
| `INTERNET` | Live OpenStreetMap tiles; opening Google Maps / WhatsApp links |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Blue dot, nearby pandals, start route from user (foreground only) |

**Removed:** `RECORD_AUDIO`, `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_CONNECT`, the speech-recognition `<queries>` intent, plus the packages `speech_to_text`, `flutter_tts`, `http`, `google_fonts` (font now bundled), `crypto`, `permission_handler` and `cupertino_icons`. There is **no** `ACCESS_BACKGROUND_LOCATION`.

**Google Play Services / Fire devices:** no Firebase, GMS or google_maps packages. `geolocator` (geolocator_android) prefers the Fused Location Provider but falls back to Android `LocationManager` when GMS is missing, so it works on Amazon Fire. Test on one Fire device before submitting there.

## Network behaviour

- Map tiles: `https://tile.openstreetmap.org/{z}/{x}/{y}.png` via `flutter_map`, user agent `com.pujoroute.app`. Without network the map shows a placeholder tile (`assets/images/offline_tile.png`) and a banner ("Map tiles need internet…"). Nothing else in the app depends on the network.
- Attribution: an always-visible `SimpleAttributionWidget` ("flutter_map | © OpenStreetMap contributors", tap → openstreetmap.org/copyright) on the one map in the app (`map_screen.dart`).
- External links (Directions, WhatsApp) go through `lib/utils/external_links.dart`. It tries an external app, then the platform default. If nothing can open the link (e.g. a Fire device without a browser or Maps), it shows a SnackBar with "Copy link" instead of crashing.
- **OSM tile usage policy:** `tile.openstreetmap.org` is a donated service. Its policy (https://operations.osmfoundation.org/policies/tiles/) bans heavy or bulk app traffic and can block apps that cause it. It is fine for a small launch. If downloads grow, **switch to a commercial tile provider** (MapTiler, Stadia, Thunderforest, etc.; only the `urlTemplate` in `map_screen.dart` and the attribution change) **or bundle offline tiles** for Kolkata (e.g. MBTiles/PMTiles).

## Build commands

Run inside `Android App/`, with Flutter stable, Android SDK 36 and JDK 17:

```bash
flutter pub get
flutter analyze
flutter test

# Universal APK (armeabi-v7a + arm64-v8a + x86_64 in one file) – for Indus Appstore, vivo, Amazon, sideload
flutter build apk --release
#   -> build/app/outputs/flutter-apk/app-release.apk
#   Do NOT add --split-per-abi (stores need one APK carrying both armeabi-v7a and arm64-v8a).

# App Bundle – for Google Play
flutter build appbundle --release
#   -> build/app/outputs/bundle/release/app-release.aab
```

`android/app/build.gradle.kts` has **no `abiFilters` and no `splits {}` block**, so the release APK is universal. Check with `unzip -l app-release.apk | grep lib/` (you should see `lib/armeabi-v7a/` and `lib/arm64-v8a/`).

## Signing (action required)

- The old `upload-keystore.jks` and `key.properties` **were committed to the public repo**, so treat them as compromised. They are untracked on this branch but still in git history.
  - For Play: if this key was already enrolled as an upload key, request an **upload key reset** in Play Console. If the app was never uploaded, create a new key.
  - For other stores: sign with a **new** keystore. Changing keys later blocks updates for existing users.
- Create the new key outside the repo:
  `keytool -genkey -v -keystore ~/pujoroute-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
- Create `Android App/android/key.properties` (gitignored):
  ```
  storePassword=...
  keyPassword=...
  keyAlias=upload
  storeFile=/absolute/path/to/pujoroute-upload.jks
  ```
- Without `key.properties`, release builds fall back to the **debug key**, which is only for local testing. Never upload those.
- Optional: remove the old keystore from history with `git filter-repo` (rotation is still required, because forks and clones keep it).

## Store listing assets (in the repo)

| File | Pixels | Notes |
|---|---|---|
| `Android App/android/app/src/main/res/mipmap-mdpi/ic_launcher.png` | 48×48 | Launcher icon, **regenerated on this branch from `durga_logo`** (was the default Flutter logo) |
| `.../mipmap-hdpi/ic_launcher.png` | 72×72 | same |
| `.../mipmap-xhdpi/ic_launcher.png` | 96×96 | same |
| `.../mipmap-xxhdpi/ic_launcher.png` | 144×144 | same |
| `.../mipmap-xxxhdpi/ic_launcher.png` | 192×192 | same |
| `docs/store/icon-512.png` | 512×512 | Store icon (Play hi-res icon), made from `durga_logo` |
| `Android App/assets/images/durga_logo.png` | 1024×1024 | Actually a **JPEG** with a .png name (875 KB). Source artwork; **confirm its origin and licence** |
| `Android App/assets/images/offline_tile.png` | 256×256 | Offline map placeholder |
| `Android App/web/icons/Icon-192.png`, `Icon-512.png`, maskable | 192 / 512 | Default Flutter web icons (not used for Android) |
| `Android App/ios/Runner/Assets.xcassets/AppIcon.appiconset/*` | various | Default Flutter iOS icons (no iOS release planned) |

**Missing (needed for the stores):** phone screenshots (Play: at least 2, 16:9 or 9:16, e.g. 1080×1920), a feature graphic (Play: 1024×500) and an adaptive launcher icon (optional). No screenshots or banners exist in the repo.

## Store notes template

- **Short description (≤80):** Plan your Durga Puja 2026 pandal hopping in Kolkata – 504 pandals, routes, metro.
- **Category:** Travel & Local. **Content rating:** Everyone. **Ads:** No. **Data safety (Play):** "No data collected" and "No data shared" (location is processed only on the device; Google Maps / WhatsApp hand-offs are user-initiated and go to external apps). Declare approximate and precise location as used for app functionality and not collected.
- **Privacy policy URL:** https://kaustav74.github.io/PujoRoute/privacy-policy.html

## Repository clean-up done on `production-hardening`

Deleted because they are online-only or dead: `backend/`, `server/` (including the Cloudflare worker), `supabase/`, `schema.sql`, `.github/workflows/render-keepalive.yml`, `cors_proxy.py`, root `test_*.py`/`run_matrix_150.py`/`stress_test_ai.py`/`matrix_results.json`/`reports/`, `puja.py` (scraper for durgapujakolkata.in), `temp_user_code.dart`, `test_dedup.py`, `PLAY_STORE_SECURITY_BLUEPRINT.md`, `.env.example`, `lib/data/pujas_data.dart.bak`, plus the AI Sathi chat, Groq voice, live weather/news fetch and session sync code in the app. CI (`.github/workflows/ci.yml`) now runs only gitleaks and Flutter analyze/test.

**Recommended (not done):**
- Delete committed build artifacts `PujoRoute.apk`, `PujoRoute.aab`, `Android App/PujoRoute.apk`, `Android App/app-release.apk` and `app/PujoRoute.apk`. Publish builds as GitHub Releases instead. They were signed with the leaked key.
- Delete `app/` after release.
- Verify the data provenance: the pandal list appears to be scraped from durgapujakolkata.in (`puja.py`). Confirm you are allowed to redistribute it.
- Check the Kojagori Lakshmi Puja date (the app says Sun 25 Oct 2026; some panjikas list 26 Oct) against the panjika you cite.
