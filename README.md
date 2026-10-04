# PujoRoute

An offline-first Android guide to Kolkata's Durga Puja 2026: 504 pandals, a route planner (Circuit Studio), Pandal Passport, the 2026 puja calendar, a metro guide and emergency contacts.

- **App source:** [`Android App/`](Android%20App/) (Flutter). `app/` is a stale copy, so do not use it.
- **Release, signing and store notes:** [`docs/HANDOFF.md`](docs/HANDOFF.md)
- **Privacy policy:** [`docs/privacy-policy.html`](docs/privacy-policy.html) (served via GitHub Pages from `/docs`)

## Network use
All content is bundled in the app. Only the map background (OpenStreetMap tiles) needs internet. Directions open Google Maps, and sharing opens WhatsApp. The app has no backend, accounts, analytics or ads.

## Develop
```bash
cd "Android App"
flutter pub get
flutter analyze
flutter test
flutter run
```

## Build
```bash
flutter build apk --release        # universal APK (armeabi-v7a + arm64-v8a)
flutter build appbundle --release  # Google Play
```
Signing needs `Android App/android/key.properties` (gitignored). See `docs/HANDOFF.md`.
