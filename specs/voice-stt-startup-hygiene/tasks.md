# Task Breakdown: Voice STT Startup Hygiene

## Goal
Prevent startup replay spam from historical inbound audio files while keeping transcript artifacts.

## Tasks
- [x] Skip pre-existing inbound audio files on watcher startup.
- [x] Optionally prune pre-existing inbound audio files on startup (default enabled).
- [x] Delete processed audio files after successful transcript write (default enabled).
- [x] Keep transcript persistence under `/root/.openclaw/voice/transcripts`.
- [x] Document new env toggles in `README.md`.

## Env Toggles
- `VOICE_STT_SKIP_EXISTING_ON_START` (default `1`)
- `VOICE_STT_PRUNE_EXISTING_ON_START` (default `1`)
- `VOICE_STT_DELETE_AFTER_TRANSCRIBE` (default `1`)

## Validation
- Restart container with historical inbound files present.
- Confirm no historical transcript messages are posted.
- Confirm historical files are removed when prune is enabled.
- Send a new voice note and verify transcript is posted and source audio removed.
