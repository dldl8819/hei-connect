# Architecture

## Phase 1: Live Help Platform

```text
Host mobile app
  -> audio-only, selfie camera, world camera, microphone, and room controls
  -> WebRTC media stream
  -> signaling API: offer, answer, ICE candidates
  -> supporter mobile app
  -> voice, chat, and quick cue feedback
  -> host audio output

Host web or desktop app
  -> screen share, camera, microphone, and channel controls
  -> WebRTC media stream
  -> signaling API
  -> supporter mobile app
  -> voice, chat, and quick cue feedback
  -> host audio output
```

Persistent channels sit above live sessions:

```text
Channel
  -> live session
  -> source mode: audio-only | screen share | selfie camera | world camera
  -> room purpose: audio room | daily help | conversation | broadcast | running guide
  -> channel link and live session join link
  -> optional support intents
```

Room purposes:

- Audio room.
- Daily help.
- Conversation.
- Broadcast.
- Running guide.

## Phase 2: AI-Assisted Phone App

```text
Host camera
  -> on-device safety model
  -> remote supporter
  -> rule-based cue engine
  -> audio or vibration output
```

## Phase 3: Smart Glasses

```text
Smart glasses camera and microphone
  -> phone companion app or glasses SDK
  -> on-device or edge inference
  -> remote guide fallback
  -> open-ear audio cue
```

## Components

- Mobile app: role selection, live room UI, camera modes, WebRTC, audio cues.
- Mobile invite routing: shared live and channel links open the supporter join
  screen with the invite prefilled.
- Mobile chat panel: host and supporter screens exchange short room messages.
- Web or desktop app: screen share broadcasting and channel management.
- API service: channel lifecycle, live session lifecycle, safety state,
  join-code resolution, support intents, guidance cue events, short chat
  messages, signaling metadata.
- Realtime media: WebRTC with TURN support for unreliable networks.
- Mobile media controller: creates local camera/microphone streams, publishes
  offer/answer, polls signaling state while the room is active, exchanges ICE
  candidates, renders remote streams, and marks connection loss as a safety
  stop condition.
- Signaling privacy: SDP and ICE values may identify networks and must not be
  logged or persisted longer than needed for the active room.
- Safety engine: connection monitoring, safety-state reporting, and
  conservative stop decisions. Running-guide rooms require a pre-run checklist
  before media starts and explicit resume confirmation after connection loss.
- Cue event model: guide buttons send structured enum events only; free-form
  speech text is not stored in the MVP.
- Cue playback: the host app speaks incoming structured cues through Korean
  device TTS.
- Payments integration: future boundary after platform policy, payout, tax, and
  abuse review.

## Guiding Principle

When the system is uncertain, it should tell the runner to stop.
