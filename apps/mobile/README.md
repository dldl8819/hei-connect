# Connect Mobile

Cross-platform mobile app skeleton for accessibility-first live sessions.

## Current Scope

- Live host and supporter role selection.
- Live host screen with large controls.
- Supporter screen with invite code/link entry and short cue buttons.
- Shared live session and safety models.
- Mobile source modes for audio-only, selfie camera, and world-facing camera.
- Running-guide runner modes: non-visually impaired runner, low-vision runner,
  and blind runner.
- Support-enabled channel setting.
- WebRTC signaling client for offer, answer, and ICE candidate exchange.
- Initial `flutter_webrtc` media controller for camera, microphone, offer,
  answer, and ICE exchange.
- Automatic signaling polling while a WebRTC room is active.
- Connection-loss safety state reporting and stop cue behavior for
  running-guide rooms.
- Resume confirmation before restarting a running-guide room after connection
  loss.
- Running-guide pre-run checklist gate before media starts.
- Screen-wide long-press emergency stop request for running-guide sessions.
- World-camera guide overlay for checking forward path and foot-edge framing.
- Supporter cue buttons create structured API cue events.
- Supporter screen shows recent cue history.
- Host screen polls cue events and updates the current guide cue.
- Host screen shows recent cue history.
- Host screen speaks incoming cues with Korean TTS.
- Short live-room chat panel on host and supporter screens.
- Host screen reads new supporter/system chat messages through Korean TTS.
- Optional on-device AI assist for running-guide rooms. It samples the
  world-facing camera stream, runs ML Kit object detection, and speaks a
  slow-down or stop cue when the detected object geometry looks risky.
- Host-side field test status panel for running-guide rooms. It summarizes
  checklist readiness, live/WebRTC state, AI assist state, and resume
  confirmation without storing raw camera frames, chat text, or personal data.
- In-app route handling for shared live links and channel links.
- Android and iOS native permission declarations for camera and microphone.
- Screen-awake bridge while host or supporter media is connected.

## Next Implementation Steps

1. Test Android camera, microphone, speaker, and screen-awake behavior on a
   real device.
2. Test iPhone camera, microphone, speaker, and screen-awake behavior on a Mac
   with Xcode.
3. Add live camera angle calibration for running-guide rooms.
4. Add native camera switching between selfie and world-facing camera.
5. Calibrate AI assist thresholds on controlled tracks with a backup guide.
6. Add reconnect and background connection handling.
7. Add emergency contact notification after explicit consent and privacy review.

## Invite Routes

The Flutter router opens the supporter screen for these route shapes:

- `/join/live/YOUR_JOIN_CODE`
- `/channels/YOUR_CHANNEL_CODE`
- `/support?invite=YOUR_JOIN_CODE`
- `connect://open/join/live/YOUR_JOIN_CODE`

Android and iOS declare the `connect://` URL scheme for local deep-link pilots.

## Local Build Notes

On Windows machines where the user home path contains non-ASCII characters,
Android native builds should use an ASCII Pub cache path:

```powershell
$env:PUB_CACHE = 'C:\develop\pub-cache'
flutter pub get
flutter build apk --debug
```

## iOS Verification From Windows

Windows cannot run Xcode locally, so iOS compilation is checked through the
`Mobile iOS Compile` GitHub Actions workflow. Push the branch to GitHub and run
the workflow manually from the Actions tab, or open a pull request that changes
`apps/mobile/**`.

The workflow runs on a macOS runner and executes:

```bash
flutter pub get
dart analyze
dart run test
flutter build ios --release --no-codesign
```

This verifies that the iOS project compiles without Apple signing credentials.
Installing on an iPhone still requires a signed build through TestFlight or a
Mac/Xcode signing environment.

## Native Permissions

- Android declares camera, microphone, internet, audio settings, wake-lock, and
  `connect://open/...` invite links.
- iOS declares camera and microphone usage descriptions, background audio, and
  the `connect://` URL scheme.
- The app keeps the screen awake while host/supporter media is connected.

Do not record video or audio by default.

The current Flutter skeleton depends on `flutter_webrtc`. Native permission
behavior still needs to be tested on real Android and iPhone devices before
field pilots.

TTS uses `flutter_tts` and should be tested on real devices with the intended
open-ear audio output before any field pilot.

AI assist is a local safety aid, not an autonomous guide. It currently uses
ML Kit object detection and conservative bounding-box rules. It can miss hazards
or produce false alarms, so it must be tested only on controlled routes with a
backup guide until the model, camera mount, route type, and latency are
validated.

Use `docs/ANDROID_FIELD_TEST_CHECKLIST.md` for controlled Android field tests
and `docs/MVP_SAFETY_BOUNDARIES.md` for the MVP allow/block list.

Chat is for short room coordination only. Do not put contact details, exact
locations, credentials, or other sensitive personal data in chat.
