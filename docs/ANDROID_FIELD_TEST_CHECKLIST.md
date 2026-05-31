# Android Field Test Checklist

This checklist is for controlled Android device tests only. Do not use early
builds on open roads, road crossings, crowded races, night runs, or unknown
routes.

## Test Setup

- Use a controlled track or closed route.
- Keep a sighted backup person physically near the runner.
- Use open-ear audio or a single-ear output that does not block ambient sound.
- Mount the phone so the world-facing camera shows the forward path and foot
  edge area.
- Fully charge the phone and keep a backup phone available.
- Use a short test session first, then increase distance only after repeated
  stable results.

## Before Starting Live

- Create a running-guide session.
- Select the correct runner mode: non-visually impaired, low-vision, or blind.
- Confirm every pre-run checklist item in the host app.
- Confirm the camera preview shows the route ahead and the lower path area.
- Confirm speaker or earphone output is loud enough.
- Confirm long-press emergency stop is understood by the tester.
- Confirm the supporter can join with the session code or link.

## WebRTC And Guide Flow

- Start the host stream.
- Confirm the supporter sees the live forward camera view.
- Confirm supporter voice reaches the runner.
- Send each guide cue from the supporter screen and confirm host TTS speaks it.
- Send a supporter chat message and confirm host TTS reads it.
- Pause and resume the session, confirming resume requires explicit safety
  confirmation.

## AI Assist Verification Mode

- Enable AI assist in running-guide world-camera mode.
- Enable verification mode.
- Press the slow-down cue test and confirm:
  - TTS speaks the slow-down verification message.
  - The recent cue list receives a system slow-down cue.
  - The stream remains live.
- Press the stop cue test and confirm:
  - TTS speaks the stop verification message.
  - The session safety state moves to stop.
  - The session pauses and requires resume confirmation.
  - AI analysis stops until the runner confirms resume.

## AI Camera Analysis

- Disable verification mode.
- Press analyze now while the phone points at a clear route.
- Confirm no stop cue is spoken on a clear route.
- Place a large safe test object in the forward path while stationary.
- Confirm AI assist gives a slow-down or stop cue.
- Remove the object and confirm the runner can resume only after safety
  confirmation if a stop cue occurred.

## Failure Cases

- Turn off supporter network and confirm connection-loss stop behavior.
- Lock and unlock the phone and confirm the screen-awake behavior.
- Rotate the phone slightly and confirm the camera guide overlay still makes the
  required framing obvious.
- Stop media and confirm AI analysis stops.

## Data And Privacy Checks

- Do not record video or audio during this field test unless explicit consent
  and a separate privacy review are complete.
- Do not enter contact details, exact addresses, or personal identifiers in
  chat.
- Do not save screenshots that include people, locations, or private messages.
- Do not collect raw camera frames for debugging in early field tests.
