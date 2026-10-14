# PujoRoute on iOS

The Flutter app already targets iOS. Bundle ID is `com.pujoroute.app` (same as Android). Location, speech, and microphone usage strings are set.

## Install on your iPhone

iOS will not install an unsigned APK-style file. You need a Mac once.

1. Install Xcode from the Mac App Store.
2. Clone this repo and open `app/ios/Runner.xcworkspace` in Xcode.
3. Select the Runner target → Signing & Capabilities → Team → your Apple ID.
4. Plug in the iPhone, select it as the run destination, press Run.
5. On the iPhone: Settings → General → VPN & Device Management → trust the developer.

A free Apple ID works for personal install (expires after 7 days). TestFlight and the App Store need a paid Apple Developer account ($99/year).

## CI build

`.github/workflows/build-ios.yml` builds an **unsigned** IPA and publishes it to the `ios-ci` release. That file is for archive only — it will not install until it is signed in Xcode.
