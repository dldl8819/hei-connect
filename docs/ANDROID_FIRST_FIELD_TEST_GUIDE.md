# Android First Field Test Guide

Use this guide for the first Android real-device test only. The test must stay
inside a controlled route with a nearby backup person. This guide does not
approve solo running, public roads, road crossings, crowded races, night runs,
or unknown routes.

## Before The App Opens

- Choose a controlled track, closed loop, or controlled park path.
- Keep a sighted backup person physically near the runner.
- Use open-ear or single-ear audio so ambient sound remains available.
- Mount the phone so the world-facing camera sees the forward path and lower
  edge area.
- Prepare a second device for the guide.
- Do not record exact locations, join links, chat text, raw camera frames,
  screenshots containing people, or credentials.

## Install And Open

From the repository root:

```powershell
.\scripts\flutter-mobile.cmd build apk --debug --no-pub
adb devices
adb install -r apps\mobile\build\app\outputs\flutter-apk\app-debug.apk
```

Open the app on the Android test phone after installation.

## Host Phone Button Order

1. Choose the host/live-opening flow.
2. In `방 종류`, choose `러닝 가이드`.
3. In `러너 모드`, choose the actual test mode.
4. In `방송 소스`, choose `눈앞 카메라`.
5. Complete every item in `러닝 전 안전 체크`.
6. Confirm `현장 테스트 상태` shows the controlled-route and backup-person
   safety gate as ready.
7. Press `라이브 세션 생성`.
8. Keep the runner stationary and press `라이브 시작`.
9. Allow camera and microphone permissions.
10. On the guide device, join with the session code or link.
11. Press `신호 새로고침` if WebRTC does not move to connected after the guide
    joins.
12. Confirm guide voice, cue buttons, short chat TTS, and stop/resume behavior.
13. Turn on `AI 보조 안내` only after the guide voice and stop flow work.
14. Turn on `검증 모드`.
15. Press `감속 큐 테스트`, then `정지 큐 테스트`, while the runner is stationary.
16. After resume confirmation works, turn off `검증 모드`.
17. Press `지금 분석` only while stationary and only with a safe test object.

## Runner Mode Notes

### Non-Visually Impaired Runner

- The tester may read the screen, but still follows the same safety gate.
- Do not skip backup-person confirmation because the tester can see the screen.
- Use this mode to verify screen wording, button order, and camera mounting.

### Low-Vision Runner

- Confirm text size, contrast, TTS volume, and button spacing before movement.
- Keep the phone mounted; do not require frequent visual screen checks while
  moving.
- Use voice confirmation from the backup person before pressing resume.

### Blind Runner

- Do not depend on visible buttons during movement.
- Confirm long-press stop behavior before live media starts.
- Keep the runner stationary for permission prompts, verification mode, resume,
  and AI camera analysis.
- The backup person stays close enough to intervene immediately.

## Test Order Rule

Do not start AI camera analysis first. The order is:

1. Safety checklist.
2. Live media permissions.
3. Guide joins and WebRTC connects.
4. Guide voice, cue buttons, chat TTS.
5. Stop cue and resume confirmation.
6. AI verification mode.
7. AI camera analysis while stationary.

## If Something Fails

- Stop movement first.
- Record only operational facts in `docs/ANDROID_FIELD_TEST_REPORT_TEMPLATE.md`.
- Do not paste exact location, links, session codes, chat text, camera frames,
  screenshots with people, credentials, or private URLs.
- Keep the test blocked until the failed step is reproduced and fixed.

