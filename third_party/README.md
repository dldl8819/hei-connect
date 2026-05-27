# Third-party Flutter plugin patches

This directory contains local overrides for Flutter plugins whose latest
published versions still apply the legacy Kotlin Gradle Plugin from their
Android `build.gradle` files.

The app uses these overrides until upstream releases migrate to Android Gradle
Plugin 9 built-in Kotlin support.

Current overrides:

- `flutter_tts` 4.2.5
- `flutter_webrtc` 1.4.1

