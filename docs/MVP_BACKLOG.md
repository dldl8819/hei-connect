# MVP Backlog

## Milestone 1: Static App Skeleton

- Live host and supporter role selection.
- Live host screen.
- Live supporter screen.
- Channel creation.
- Channel code and share link generation.
- Live session join code and share link generation.
- Join-code lookup API.
- Join screen for live session codes and links.
- Channel lookup from channel links.
- Source mode selection: audio-only, screen share, selfie camera, world camera.
- DJ audio room purpose.
- Support-enabled channel setting.
- Support intent API without payment details.
- WebRTC signaling API.
- Mobile signaling client.
- Initial Flutter WebRTC media controller.
- Automatic signaling polling while rooms are active.
- Connection-loss safety state reporting and running-guide stop cue behavior.
- Resume confirmation before restarting running-guide rooms after connection
  loss.
- Running-guide pre-run checklist gate before media starts.
- Structured API events for supporter cue buttons.
- Recent cue history on the supporter screen.
- Host cue-event polling for the current guide cue.
- Recent cue history on the host screen.
- Korean TTS playback for incoming host cues.
- Short live-room chat on host and supporter screens.
- In-app invite route handling for live links and channel links.
- Safety cue model.
- API health and live session skeleton.

## Milestone 2: Session API Integration

- Create live session.
- Attach live session to a channel.
- Join live session.
- Update live session status.
- Update safety state.
- Show connection state on both devices.

## Milestone 3: WebRTC Prototype

- Runner camera stream.
- Guide remote video view.
- Guide voice back to runner.
- Live help room without running-specific controls.
- Web screen-share prototype.
- Audio-only room prototype.
- Support button prototype using support intents only.
- TURN configuration.
- Bind real WebRTC media tracks to the signaling client.
- Add native iOS/Android camera and microphone permission configuration.
- Add platform URL intent declarations for invite links.
- Reconnect and background resume behavior.

## Milestone 4: Field Test Build

- Field-test pre-run checklist validation.
- Camera angle calibration.
- Battery and network warning.
- Emergency stop flow.
- Privacy-safe event logging.
- Real-device TTS volume and latency validation.

## Milestone 5: AI Assist Research

- Obstacle detection prototype.
- Lane or path boundary detection.
- Conservative stop classifier.
- On-device inference feasibility.
