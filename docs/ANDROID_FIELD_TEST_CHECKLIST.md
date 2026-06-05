# Android Field Test Checklist

This checklist is for controlled Android device tests only. Do not use early
builds on open roads, road crossings, crowded races, night runs, or unknown
routes.

## Test Setup

- Use `docs/ANDROID_FIRST_FIELD_TEST_GUIDE.md` for the first full button-by-
  button Android test.
- Use a controlled track or closed route.
- Keep a sighted backup person physically near the runner.
- Use open-ear audio or a single-ear output that does not block ambient sound.
  Do not use noise-cancelling or sealed in-ear audio for running-guide tests.
- Mount the phone so the world-facing camera shows the forward path, center
  lane or path, and lower ground edge near the runner.
- Fully charge the phone and keep a backup phone available.
- Use a short test session first, then increase distance only after repeated
  stable results.

## APK Build And Install

From the repository root:

```powershell
.\scripts\flutter-mobile.cmd build apk --debug --no-pub
adb devices
adb install -r apps\mobile\build\app\outputs\flutter-apk\app-debug.apk
```

If `adb` is not on `PATH`, use the Android SDK `platform-tools` `adb.exe`.
Install only the debug APK built from the current branch. Do not distribute it
outside the test group.

## Recommended Test Order

1. Install the APK and open the app.
2. Choose host mode and create a running-guide session.
3. Select the runner vision mode being tested.
4. Confirm every pre-run checklist item.
5. Start live media while stationary and grant camera and microphone
   permissions.
6. Confirm the world-facing camera angle still shows forward path and lower
   ground edge.
7. Join from a second device using the session code or link.
8. Confirm WebRTC video, supporter voice, cue buttons, chat TTS, and
   stop/resume behavior.
9. Check the in-app guide-flow confirmation.
10. Run AI verification mode while stationary.
11. Run AI camera analysis while stationary with a controlled test object.
12. Test connection loss, stop cue, and resume confirmation.

## Before Starting Live

- Create a running-guide session.
- Select the correct runner mode: non-visually impaired, low-vision, or blind.
- Confirm every pre-run checklist item in the host app.
- Confirm the camera preview shows the route ahead and the lower path area.
- Confirm speaker or earphone output is loud enough without blocking ambient
  sound.
- Confirm long-press emergency stop is understood by the tester.
- Confirm the supporter can join with the session code or link.
- Confirm the in-app field test status panel shows the controlled route and
  backup-person checks as ready before live movement.

## WebRTC And Guide Flow

- Start the host stream.
- Confirm the supporter sees the live forward camera view.
- Confirm supporter voice reaches the runner.
- Send each guide cue from the supporter screen and confirm host TTS speaks it.
- Send a supporter chat message and confirm host TTS reads it.
- Pause and resume the session, confirming resume requires explicit safety
  confirmation.

## AI Assist Verification Mode

- Enable AI assist in running-guide world-camera mode.
- Enable verification mode.
- Keep the runner stationary. Verification mode checks the cue flow only and
  does not analyze camera frames.
- Press the slow-down cue test and confirm:
  - TTS speaks the slow-down verification message.
  - The recent cue list receives a system slow-down cue.
  - The stream remains live.
- Press the stop cue test and confirm:
  - TTS speaks the stop verification message.
  - The session safety state moves to stop.
  - The session pauses and requires resume confirmation.
  - AI analysis stops until the runner confirms resume.
- Record whether the in-app field test status panel shows resume confirmation
  as required after the stop cue.

## AI Camera Analysis

- Disable verification mode.
- Press analyze now while the phone points at a clear route.
- Confirm no stop cue is spoken on a clear route.
- Place a large safe test object in the forward path while stationary.
- Confirm AI assist gives a slow-down or stop cue.
- Remove the object and confirm the runner can resume only after safety
  confirmation if a stop cue occurred.

## Failure Record

When a test fails, record only operational facts:

- Test step.
- Device model and Android version.
- App build source: current branch debug APK.
- Network type: Wi-Fi, mobile data, or hotspot.
- Runner mode and source mode.
- Expected result and actual result.
- WebRTC phase shown in the app.
- AI assist state shown in the app.
- Whether resume confirmation was required.
- Permission prompt or visible error message, with sensitive details removed.
- Short reproduction steps.

Do not record exact locations, contact details, session links, chat text,
camera frames, screenshots containing people, or any credentials.

Use `docs/ANDROID_FIELD_TEST_REPORT_TEMPLATE.md` for the written test report.
Use `docs/ANDROID_FIRST_FIELD_TEST_GUIDE.md` when the tester needs the exact
button order.

## Failure Cases

- Turn off supporter network and confirm connection-loss stop behavior.
- Lock and unlock the phone and confirm the screen-awake behavior.
- Rotate the phone slightly and confirm the camera guide overlay still makes the
  required framing obvious.
- Stop media and confirm AI analysis stops.

## Data And Privacy Checks

- Do not record video or audio during this field test unless explicit consent
  and a separate privacy review are complete.
- Do not enter contact details, exact addresses, or personal identifiers in
  chat.
- Do not save screenshots that include people, locations, or private messages.
- Do not collect raw camera frames for debugging in early field tests.
