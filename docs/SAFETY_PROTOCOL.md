# Safety Protocol

## System Rule

The safest fallback cue is always:

```text
정지
```

## Required Pre-Run Checks

Running-guide rooms must block media start until these checks are confirmed:

- Runner confirms the route is controlled and known.
- Phone is mounted securely with a forward-facing camera angle.
- Earphone or open-ear audio output is connected.
- Guide can see the ground path ahead.
- Network quality is acceptable.
- Battery is sufficient for the planned run.
- Emergency contact flow is available.

## Connection Loss Behavior

If video, audio, or signaling becomes unreliable:

1. The runner app repeats the stop cue.
2. The guide app marks the session unsafe.
3. The session must not resume until video and audio are stable again.
4. Running-guide rooms require an explicit resume confirmation before
   restarting the stream.

## Test Restrictions

Do not use early builds for:

- Road crossings.
- Vehicle traffic.
- Crowded public races.
- Night running.
- Unknown trails.
- Solo tests without a backup person.
