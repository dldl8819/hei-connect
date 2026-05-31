# Connect

Connect is an accessibility-first live platform where disabled and non-disabled
people can create channels, open live audio/video rooms, become audio DJs,
share camera or screen feeds, ask for help, guide each other, talk, broadcast,
and receive supporter-backed contributions in a familiar community format.

The first concrete use case is a phone-based remote guide runner. A runner
starts a live session, shares the forward camera and microphone with a trusted
guide, and receives short real-time voice cues while running in controlled
environments. The same live-session foundation also supports everyday help,
conversation rooms, DJ audio rooms, channel broadcasts, computer screen sharing,
supporter contributions, and later AI smart glasses.

## MVP Scope

- Live host and supporter roles in one cross-platform mobile app.
- Channel creation for persistent live spaces.
- Live source modes for audio-only, screen share, selfie camera, and
  world-facing camera.
- Shareable channel links and live session join links.
- Support-enabled channels and support intent skeletons without payment details.
- Real-time live session lifecycle for opening, joining, pausing, and ending.
- Safety-first voice cue model for remote running guidance.
- API skeleton for live sessions, safety state, and event logging.
- Privacy-first defaults: no recording by default, no secrets in source files.

## Repository Layout

```text
apps/mobile       Cross-platform mobile app skeleton
apps/web          Web client notes for screen sharing and desktop broadcasting
services/api      Rust API service skeleton
docs              Product, safety, privacy, and architecture notes
```

## Safety Position

Connect may be used for social live rooms, everyday assistance, and guided
running, but safety-critical use cases need stricter boundaries. The remote
guide runner feature is assistive technology, not an autonomous navigation
replacement. The first running version must be tested only in controlled
environments such as tracks, closed loops, or parks without vehicle traffic.
Road crossings, crowded races, and solo runs without a fallback plan are outside
the MVP scope.

Operational safety documents:

- `docs/ANDROID_FIELD_TEST_CHECKLIST.md` for controlled Android field tests.
- `docs/MVP_SAFETY_BOUNDARIES.md` for MVP allow/block decisions.
- `docs/SAFETY_PROTOCOL.md` for stop, connection-loss, and AI assist behavior.

## Local Development

Flutter/Dart, Android SDK, and Rust/Cargo are installed under
`C:\Users\Public\GuideRunToolchains`. New terminals should pick them up from the
user PATH. In an already-open PowerShell session, run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
. .\scripts\dev-env.ps1
```

Because some Flutter tooling is sensitive to non-ASCII project paths, use the
wrapper commands from the repository root:

```powershell
.\scripts\flutter-mobile.cmd analyze --no-pub
.\scripts\flutter-mobile.cmd build web --no-pub
.\scripts\flutter-mobile.cmd build apk --debug --no-pub
```

For the Rust service:

```powershell
.\scripts\cargo-project.cmd check
.\scripts\cargo-project.cmd build
```

To run the API directly after configuring the shell environment:

```powershell
cargo run -p connect-api
```

## Environment

Use `.env.example` as a template and keep real environment files out of Git.
Never commit credentials, tokens, private URLs, or personally identifying data.
Set `CONNECT_PUBLIC_APP_URL` at runtime to generate shareable channel and live
session links.
