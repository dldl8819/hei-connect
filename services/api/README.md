# Connect API

Rust API skeleton for live session lifecycle and safety state.

## Run

```bash
cargo run -p connect-api
```

## Endpoints

- `GET /healthz`
- `POST /v1/channels`
- `GET /v1/channels/code/{channel_code}`
- `GET /v1/channels/{channel_id}`
- `POST /v1/live-sessions`
- `GET /v1/live-sessions/join-code/{join_code}`
- `GET /v1/live-sessions/{session_id}`
- `PATCH /v1/live-sessions/{session_id}/status`
- `PATCH /v1/live-sessions/{session_id}/safety`
- `GET /v1/live-sessions/{session_id}/cues`
- `POST /v1/live-sessions/{session_id}/cues`
- `GET /v1/live-sessions/{session_id}/messages`
- `POST /v1/live-sessions/{session_id}/messages`
- `GET /v1/live-sessions/{session_id}/signal`
- `POST /v1/live-sessions/{session_id}/signal/offer`
- `POST /v1/live-sessions/{session_id}/signal/answer`
- `POST /v1/live-sessions/{session_id}/signal/ice-candidates`
- `POST /v1/support-intents`

## Create Channel

Request fields:

- `title`: channel title, 1 to 40 characters
- `support_enabled`: whether the channel can receive support intents

Response fields:

- `channel_id`: internal channel identifier
- `channel_code`: short code for later discovery and joining flows
- `channel_link`: shareable channel link generated from `CONNECT_PUBLIC_APP_URL`
- `title`: channel title
- `support_enabled`: support setting for the channel

## Resolve Channel By Code

`GET /v1/channels/code/{channel_code}` resolves a channel from a short channel
code. The server normalizes the code to uppercase before matching.

## Create Live Session

Request fields:

- `purpose`: one of `audio_room`, `daily_help`, `conversation`, `broadcast`,
  `running_guide`
- `source_mode`: one of `audio_only`, `screen_share`, `selfie_camera`,
  `world_camera`
- `runner_vision_mode`: optional for running-guide rooms; one of `sighted`,
  `low_vision`, `blind`
- `channel_id`: optional existing channel identifier
- `host_alias`: optional temporary alias

Response fields:

- `session_id`: internal live session identifier
- `join_code`: short code for later join flows
- `join_link`: shareable live session link generated from `CONNECT_PUBLIC_APP_URL`
- `channel_id`: channel identifier, if the session belongs to a channel
- `purpose`: live room purpose
- `source_mode`: selected broadcast source
- `runner_vision_mode`: runner visibility mode, if provided
- `status`: current live session state
- `safety_state`: current safety state

## Resolve Live Session By Join Code

`GET /v1/live-sessions/join-code/{join_code}` resolves a live session from a
short join code. The server normalizes the code to uppercase before matching.

Mobile clients can accept either the raw code or a share link and call this
endpoint after extracting the code.

## Update Live Session Status

Use this when the host starts, pauses, resumes, or ends a room.

Request fields:

- `status`: one of `waiting_for_supporter`, `connected`, `live`, `paused`,
  `ended`
- `reason`: optional short machine-readable reason, up to 120 characters

The response is the updated live session. Do not put personal details,
locations, contact info, or credentials in `reason`.

## Invite Link Base

Set `CONNECT_PUBLIC_APP_URL` in the runtime environment to control generated
share links. Use a public web or deep-link base owned by the app. Do not commit
real private domains or internal URLs.

## Create Support Intent

Request fields:

- `channel_id`: optional channel identifier
- `session_id`: optional live session identifier
- `tier`: one of `small`, `medium`, `large`
- `message`: optional short supporter message

This endpoint does not process money, cards, accounts, payouts, or receipts.
It only creates a placeholder support intent so the product flow has a safe API
boundary before real payment policy and provider work.

## WebRTC Signaling

The signaling endpoints store WebRTC offer, answer, and ICE candidate state in
memory for one live session.

- `GET /v1/live-sessions/{session_id}/signal`: fetch signaling state
- `POST /v1/live-sessions/{session_id}/signal/offer`: publish host offer
- `POST /v1/live-sessions/{session_id}/signal/answer`: publish supporter answer
- `POST /v1/live-sessions/{session_id}/signal/ice-candidates`: add ICE candidate

SDP and ICE payloads can contain network-identifying information. Do not log,
persist, print, or expose raw signaling payloads outside the active connection
flow.

The current service uses in-memory state only. Replace it with persistent
storage before real pilots.

## Guidance Cues

The cue endpoints store short, structured guide cues for one live session.

- `GET /v1/live-sessions/{session_id}/cues`: list recent cue events
- `POST /v1/live-sessions/{session_id}/cues`: create a cue event

Request fields:

- `cue`: one of `stop_now`, `slow_down`, `keep_straight`, `left_small`,
  `right_small`, `obstacle_ahead`, `person_ahead`, `curb_ahead`,
  `narrow_path`, `hold_pace`
- `sender_role`: one of `supporter`, `system`

The API stores enum values only, not free-form speech text. A `stop_now` cue
also moves the session safety state to `stop_now`.

## Live Chat

The chat endpoints store short text messages for one live session.

- `GET /v1/live-sessions/{session_id}/messages`: list recent messages
- `POST /v1/live-sessions/{session_id}/messages`: create a message

Request fields:

- `sender_role`: one of `host`, `supporter`, `system`
- `body`: trimmed text, 1 to 280 characters

Do not send contact details, exact locations, credentials, or other sensitive
personal data in chat. The current implementation is in-memory and intended
only for MVP flow testing.

On the runner host screen, new supporter and system chat messages are read out
through TTS so a guide who cannot speak can still send short instructions.
Keep those messages brief and safety-focused.

Use temporary aliases in live session payloads. Do not send real names, contact
details, or exact private addresses to this API unless a later consented feature
explicitly requires them.
