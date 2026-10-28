# MVP Safety Boundaries

Hei Connect is an accessibility-first live guidance platform. The MVP must be
treated as assisted guidance software, not as an autonomous mobility or medical
device.

## Must Block In The MVP

- No solo outdoor road running without a nearby backup person.
- No use at road crossings, vehicle traffic, crowded public races, night runs,
  or unknown trails.
- No automatic navigation command that tells the runner to cross, turn into
  traffic, or proceed through uncertain conditions.
- No AI-only decision path for continuing movement after a stop cue.
- No hidden recording of camera, microphone, chat, or location.
- No raw camera frame upload for debugging without explicit consent and a
  separate privacy review.
- No public room discovery for running-guide sessions before moderation,
  reporting, and abuse controls exist.
- No donation or payment flow until identity, refund, fraud, tax, and safety
  review are complete.
- No emergency contact notification until consent, verification, and false alarm
  handling are designed.

## Allowed In The MVP

- Private running-guide sessions with invite code or link.
- World-facing camera broadcast from the runner's phone to an invited guide.
- Supporter voice and short structured guide cues.
- Host-side TTS for cues and short supporter/system chat messages.
- Runner modes for non-visually impaired, low-vision, and blind runners.
- Pre-run checklist gating for running-guide sessions.
- Long-press and button-based stop requests.
- Connection-loss stop behavior and resume confirmation.
- On-device AI assist that can suggest slow-down or stop cues.
- AI verification mode that simulates cue flow without camera analysis.
- Android controlled-route field testing with a nearby backup person.
- iOS compile checks through macOS CI without shipping to testers.

## Required Product Language

Use these phrases in early builds and docs:

- "AI assist"
- "Guidance support"
- "Controlled-route test"
- "Backup person required"
- "Not autonomous navigation"

Avoid these phrases until validated and legally reviewed:

- "Run alone safely"
- "Replaces a guide runner"
- "Autonomous guide"
- "Detects all obstacles"
- "Emergency response system"

## Release Gate

Before any external pilot, the team must confirm:

- Android real-device camera, microphone, TTS, WebRTC, and screen-awake behavior.
- iOS compile result in CI, then TestFlight build with proper signing.
- AI assist false positive and false negative behavior on controlled routes.
- Privacy notice and consent text for live camera, microphone, and chat.
- Abuse handling for unexpected viewers, harmful chat, and unsafe guidance.
- Incident response process for stops, connection loss, or injury reports.
- Open-source license notices in the app for every bundled dependency. Flutter's
  license page collects Dart package licenses only, so native libraries the
  build downloads (for example `io.github.webrtc-sdk:android`, `audioswitch`
  and the ML Kit SDK on Android, and the matching CocoaPods on iOS) need their
  notices added separately.
