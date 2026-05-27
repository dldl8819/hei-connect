# Connect Web

Web client notes for computer screen broadcasting.

The web client should handle source modes that mobile cannot fully own:

- Screen share through the browser Screen Capture API.
- Audio-only DJ rooms with microphone publishing.
- Camera and microphone permission flow.
- Channel creation and live session creation.
- Support-enabled creator channel controls.
- WebRTC publishing to viewers and supporters.

The first mobile app can create live sessions with `screen_share` as a source
mode for API compatibility, but actual computer screen capture belongs in this
web or desktop client.

Do not record screens by default. Screen content can expose private documents,
messages, credentials, and personal information, so recording must be explicit
and consented.

Do not collect payment credentials in this client until the product has an
approved payment flow, platform policy review, fraud handling, and payout model.
