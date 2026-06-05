# Android Field Test Failure Response

Use this guide when the first Android field test fails or becomes unclear. Stop
movement first, keep the backup person nearby, and record only operational
facts in `docs/ANDROID_FIELD_TEST_REPORT_TEMPLATE.md`.

Do not record or paste exact locations, session codes, join links, channel
links, chat text, camera frames, screenshots containing people, credentials, or
private URLs.

## Permission Denied

- Keep the runner stationary.
- Stop the live session.
- Reopen Android app settings and allow only the camera and microphone
  permissions required for this test.
- Restart the app and repeat the safety checklist before pressing `라이브 시작`.
- Record only that a permission prompt was denied. Do not copy device account
  details or private settings screens.

## Camera Preview Does Not Appear

- Keep the runner stationary.
- Confirm `방송 소스` is `눈앞 카메라`.
- Stop and restart live media.
- Confirm no other app is using the camera.
- Re-check the camera mount before any movement.
- If the preview still does not appear, block AI verification and AI analysis.

## Guide Voice Is Not Heard

- Stop movement and keep the runner in place.
- Confirm WebRTC is connected.
- Confirm the guide device granted microphone permission.
- Confirm runner audio uses open-ear, single-ear, or speaker output that does
  not block ambient sound.
- Test cue buttons before chat TTS.
- Do not check `가이드 음성/정지 흐름 확인 완료` until guide voice and stop/resume
  behavior are confirmed.

## WebRTC Does Not Connect

- Keep both devices stationary.
- Confirm the host has pressed `라이브 시작`.
- Confirm the guide joined with the current session code or link without
  pasting it into reports.
- Press `신호 새로고침`.
- Try a stable network for both devices.
- If WebRTC remains disconnected, stop the session and create a new one.

## AI Verification Mode Fails

- Keep the runner stationary.
- Confirm `가이드 음성/정지 흐름 확인 완료` is checked.
- Confirm `AI 보조 안내` is on.
- Confirm `검증 모드` is on.
- Press `감속 큐 테스트` first, then `정지 큐 테스트`.
- If stop verification does not require resume confirmation, block actual AI
  camera analysis.

## Real AI Analysis Fails

- Keep the runner stationary.
- Turn off `검증 모드`.
- Confirm the world-facing camera preview is visible and framed correctly.
- Press `지금 분석` with a controlled test object only.
- If the app says the camera frame is unavailable, restart live media and
  re-check camera permission.
- Treat AI output as assistive only. Do not use it as autonomous navigation.

## Connection Loss Or Resume Required

- Stop movement immediately.
- Keep the backup person near the runner.
- Do not continue because the video or audio reconnects by itself.
- Use `안전 확인 후 재개` only after the runner has stopped and camera/audio are
  stable.
- Re-check guide voice, cue buttons, and stop/resume behavior before enabling
  AI assist again.

