# Third-party Flutter plugin patches

This directory contains local overrides for Flutter plugins whose latest
published versions still apply the legacy Kotlin Gradle Plugin from their
Android `build.gradle` files.

The app uses these overrides until upstream releases migrate to Android Gradle
Plugin 9 built-in Kotlin support. `apps/mobile/pubspec.yaml` points to them
through `dependency_overrides`.

## Overrides

| Plugin | Version | Upstream | License |
| --- | --- | --- | --- |
| `flutter_tts` | 4.2.5 | [pub.dev](https://pub.dev/packages/flutter_tts/versions/4.2.5), [GitHub](https://github.com/dlutton/flutter_tts) | MIT, Copyright (c) 2018 Daniel Lutton |
| `flutter_webrtc` | 1.4.1 | [pub.dev](https://pub.dev/packages/flutter_webrtc/versions/1.4.1), [GitHub](https://github.com/cloudwebrtc/flutter-webrtc) | MIT, Copyright (c) 2018 湖北捷智云技术有限公司 |

Each directory keeps its upstream `LICENSE` unchanged. `flutter_webrtc` also
keeps its upstream `NOTICE` and per-file license headers:

- Apache License 2.0: `SimulcastVideoEncoderFactoryWrapper.kt` (Shiguredo, see
  `NOTICE`), `org/webrtc/Camera1Helper.java` and `org/webrtc/Camera2Helper.java`
  (LiveKit, Inc.).
- MIT: code from react-native-webrtc (see `NOTICE`).
- BSD-style: 34 files under `android/`, `common/`, `ios/`, `linux/` and
  `windows/` whose headers say so (most are the Flutter embedding under
  `linux/`), and `third_party/svpng` (see its `LICENSE`).

None of the Apache 2.0 or BSD-licensed files above are modified.

## Changes from upstream

Only these files differ from the published archives. Line endings aside, every
other file is byte-for-byte upstream.

`flutter_tts/android/build.gradle` and `flutter_webrtc/android/build.gradle`:

- Removed the `buildscript` block that pinned an Android Gradle Plugin and the
  Kotlin Gradle Plugin (`flutter_tts`: AGP 8.13.0, Kotlin 2.2.20;
  `flutter_webrtc`: AGP 7.1.1, Kotlin 1.8.10).
- Removed `apply plugin: 'kotlin-android'`, so the module uses the built-in
  Kotlin support of Android Gradle Plugin 9.
- Raised Java source and target compatibility to 17 (from 11 in `flutter_tts`,
  1.8 in `flutter_webrtc`) and replaced `kotlinOptions` with
  `kotlin { compilerOptions { jvmTarget = JVM_17 } }`.
- Removed the explicit Kotlin standard library dependency (`kotlin-stdlib`,
  `kotlin-stdlib-jdk7`).

`flutter_tts/pubspec.yaml` and `flutter_webrtc/pubspec.yaml`:

- Raised the SDK lower bounds to Dart `>=3.12.0` and Flutter `>=3.44.0`
  (from Dart `>=3.4.0` / `>=3.3.0` and Flutter `>=1.22.0`).

Directories left out of the copies because the app does not build them:

- `flutter_tts`: `example/`, `gen/`, `ios/Assets/`, `test/`
- `flutter_webrtc`: `Documentation/`, `assets/`, `example/`, `ios/Assets/`,
  `test/`

Last compared against the pub.dev archives on 2026-10-28.

## Removing an override

When an upstream release no longer applies the Kotlin Gradle Plugin, delete the
matching entry under `dependency_overrides` in `apps/mobile/pubspec.yaml`,
delete its directory here, and update the table above.
