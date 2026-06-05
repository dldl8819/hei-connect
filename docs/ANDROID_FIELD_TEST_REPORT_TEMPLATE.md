# Android Field Test Report Template

Use this template only for controlled-route Android tests with a nearby backup
person. Do not use it to approve solo running, public road use, road crossings,
crowded races, night runs, or unknown routes.

## Report Rules

- Do not record exact locations, home/workplace names, or route addresses.
- Do not paste join links, channel links, session codes, contact details, chat
  text, credentials, or private URLs.
- Do not attach raw camera frames, audio recordings, or screenshots containing
  people, private messages, or identifiable surroundings.
- Record only operational facts needed to reproduce app behavior.

## Test Metadata

- Test guide used: `docs/ANDROID_FIRST_FIELD_TEST_GUIDE.md` / other
- Failure response used: `docs/ANDROID_FIELD_TEST_FAILURE_RESPONSE.md` / none
- Test date:
- App build source: current branch debug APK
- Tester role:
- Device model:
- Android version:
- Network type: Wi-Fi / mobile data / hotspot / other
- Audio output: open-ear / single-ear / speaker / other
- Runner mode: non-visually impaired / low-vision / blind
- Source mode: world-facing camera / selfie camera / audio-only / screen share
- Route category: controlled track / closed loop / controlled park path / other
- Backup person physically nearby: yes / no

## Safety Gate

- Controlled route confirmed: pass / fail / not tested
- Backup person confirmed: pass / fail / not tested
- Phone mounted forward: pass / fail / not tested
- Camera preview shows forward path and lower edge: pass / fail / not tested
- Audio is audible without blocking ambient sound: pass / fail / not tested
- Long-press stop explained: pass / fail / not tested
- Resume confirmation understood: pass / fail / not tested

## Test Steps

| Step | Expected Result | Actual Result | Status | Notes |
| --- | --- | --- | --- | --- |
| Create running-guide session | Session is created |  | pass / fail / not tested |  |
| Start live media | Camera and microphone start |  | pass / fail / not tested |  |
| Supporter joins | WebRTC connects |  | pass / fail / not tested |  |
| Supporter voice | Runner hears supporter |  | pass / fail / not tested |  |
| Cue buttons | Host TTS speaks cues |  | pass / fail / not tested |  |
| Short chat TTS | Host TTS reads short safe test message |  | pass / fail / not tested |  |
| AI verification slow-down | Slow-down cue flow works while stationary |  | pass / fail / not tested |  |
| AI verification stop | Stop cue pauses session and requires resume |  | pass / fail / not tested |  |
| AI camera analysis | Safe test object triggers expected cue while stationary |  | pass / fail / not tested |  |
| Connection loss | Stop behavior appears and resume is gated |  | pass / fail / not tested |  |

## In-App Status Snapshot

Write only the visible status labels, not codes or links.

- Field test status panel next action:
- Live status:
- WebRTC phase:
- AI assist status:
- Resume confirmation: required / not required
- Visible error message with sensitive details removed:

## Failure Detail

Complete this section only for failed or unclear steps.

- Failed step:
- Reproduction steps:
- Expected behavior:
- Actual behavior:
- Last visible WebRTC phase:
- Last visible AI assist status:
- Permission prompt involved: yes / no
- Resume confirmation required: yes / no
- Network changed during test: yes / no
- Notes with sensitive details removed:

## Decision

- Continue same test plan: yes / no
- Retest needed before movement: yes / no
- Increase distance within controlled route with backup person: yes / no
- Blocked reason:
