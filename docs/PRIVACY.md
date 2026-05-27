# Privacy

## Defaults

- Do not record audio or video by default.
- Do not store raw camera frames by default.
- Do not expose exact location history unless required for a specific safety
  feature and explicitly approved by the user.
- Do not include personal data in logs.

## Sensitive Data

Treat these values as confidential:

- Personal identifiers.
- Location traces.
- Audio and video streams.
- Live session IDs and invite links.
- Chat messages.
- Credentials, tokens, and TURN server secrets.
- SDP and ICE candidate payloads.

## Logging Rules

Allowed:

- Live session state transitions.
- Coarse connection quality.
- App version and device class.
- Safety event type.

Not allowed:

- Raw video frames.
- Raw audio.
- Raw SDP or ICE candidate payloads in logs.
- Access tokens.
- Exact private addresses.
- Contact details.
- Exact locations or contact details in chat.
- Unmasked error payloads that may include credentials.
