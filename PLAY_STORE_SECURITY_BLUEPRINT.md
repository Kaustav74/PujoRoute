# 🛡️ PujoRoute: Google Play Store Release & Security Architecture Blueprint

## Executive Overview
**PujoRoute** is built to withstand massive, hyper-concurrent real-world crowd spikes during Kolkata Durga Puja while strictly enforcing Google Play Store security standards, zero API key exposure, and edge-first zero-latency execution.

---

## 1. Zero Key Exposure & Cloudflare Worker Gateway
* **Client Hardening**: Raw Groq API keys (`gsk_...`) are **never bundled in plaintext, strings, or decompilable constant pools** inside the APK/AAB bytecode.
* **Serverless Edge Gateway**: A lightweight Cloudflare Worker (`server/cloudflare_worker/src/index.js`) acts as the secure inference proxy.
  * Secrets (`GROQ_API_KEY`, `APP_HMAC_SECRET`) are stored strictly in server-side encrypted environment variables.
  * In-memory IP rate limiting (`15 requests / user / minute`) prevents bot scraping and token exhaustion.
* **App-to-Proxy Cryptographic Handshake**:
  * Every request from the app generates an HMAC-SHA256 signature using `SecurityService.instance.generateSignature()`.
  * Sent via headers:
    * `X-PujoRoute-Signature: <hex_digest>`
    * `X-PujoRoute-Timestamp: <milliseconds_epoch>`
    * `X-PujoRoute-Session: <session_id>`
  * 5-minute anti-replay sliding window rejects replayed or intercepted requests.

---

## 2. Android Manifest & Component Lockdown
* **Backup Disabling**: `android:allowBackup="false"` in `AndroidManifest.xml` prevents adb extraction of user session data or bookmarks.
* **Cleartext Traffic Block**: `android:usesCleartextTraffic="false"` strictly disallows insecure `http://` transmissions.
* **Network Security Configuration**: `res/xml/network_security_config.xml` mandates system CA trust anchors and blocks user-installed MITM proxy certificates.
* **Minimal Permission Surface**: Foreground-only location (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`). No invasive background location permissions (`ACCESS_BACKGROUND_LOCATION`), ensuring rapid Google Play Policy approval.

---

## 3. Bytecode Obfuscation, R8 Minification & Resource Shrinking
* **R8 Minification Enabled**:
  ```kotlin
  buildTypes {
      release {
          isMinifyEnabled = true
          isShrinkResources = true
          proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
      }
  }
  ```
* **Log Stripping**: Production release builds strip `android.util.Log.v`, `d`, `i`, `w` statements using `-assumenosideeffects` rules in `proguard-rules.pro`.
* **Reflection & Serialization Safety**: Rules preserve Flutter engine bindings, native JNI bridges, and plugin reflections (`flutter_tts`, `speech_to_text`, `geolocator`, `shared_preferences`).

---

## 4. Infinite Scalability: Offline-First Edge Computing
* **Zero Server Bottleneck**: All **504 Kolkata pandals**, GPS distance math (Haversine formula), Traveling Salesperson Problem (TSP) nearest-neighbor circuit optimization, panjika tithi calculations, and Pandal Passport achievements execute **100% on-device**.
* **Zero-Latency Resilience**: When cellular networks crash to 2G or zero bars in congested hubs like Gariahat, Sreebhumi, or Maddox Square, the core application functions with zero degradation (<50ms execution).

---

## 5. Viral Social Mechanics & Cultural Gamification
* **1-Tap WhatsApp Itinerary Sharing**: Directly exports optimized pandal hopping circuits formatted with stop numbers, bold names, official metro exit gates, walk distance, and a Google Maps walking waypoint URL (`whatsapp://send?text=...`).
* **Pandal Passport**: Gamified cultural achievement system with 6 unlockable badges:
  1. 🪔 *Dakshin Kolkata Dhunuchi Master* (5 South Kolkata Pujas)
  2. 🏛️ *Bonedi Bari Explorer* (3 Heritage Mansions)
  3. 🌺 *Uttar Kolkata Sholoana Bangali* (5 North Kolkata Pujas)
  4. 🌙 *Midnight Legend* (After-hours check-in)
  5. 🚇 *Metro Hopping Pro* (5 Metro-connected pandals)
  6. 🍲 *Bhog Rasik* (Bhog hours check-in)
* **Hyper-Local Street Utility**:
  * Exact Metro Gate numbers with street orientations (e.g. *Kalighat Gate 3 - Rashbehari Ave*, *Sovabazar Gate 2*).
  * Kolkata Police one-way pedestrian barricade advisories.
  * Real-time ritual countdown badges (Pushpanjali, Sandhi Puja, Bhog).
  * 1-Tap crowdsourced line queue reporter (`Smooth <20m`, `Moderate 20-40m`, `Packed 40-60m`, `Standstill >60m`).
