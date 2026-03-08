#!/usr/bin/env python3
import json
import os
import sqlite3
import time
from pathlib import Path

import requests
from faster_whisper import WhisperModel

INBOUND_DIR = Path(os.getenv("INBOUND_DIR", "/root/.openclaw/media/inbound"))
VOICE_DIR = Path(os.getenv("VOICE_STT_DIR", "/root/.openclaw/voice"))
TRANSCRIPTS_DIR = Path(os.getenv("VOICE_TRANSCRIPTS_DIR", str(VOICE_DIR / "transcripts")))
STATE_DB = Path(os.getenv("VOICE_STATE_DB", str(VOICE_DIR / "stt-state.sqlite3")))
LOG_PREFIX = os.getenv("VOICE_STT_LOG_PREFIX", "[voice-stt]")
OPENCLAW_CONFIG = Path(os.getenv("OPENCLAW_CONFIG", "/root/.openclaw/openclaw.json"))
MODEL_NAME = os.getenv("WHISPER_MODEL", "small")
COMPUTE_TYPE = os.getenv("WHISPER_COMPUTE_TYPE", "int8")
LANGUAGE = os.getenv("WHISPER_LANGUAGE", "en")
BEAM_SIZE = int(os.getenv("WHISPER_BEAM_SIZE", "5"))
BEST_OF = int(os.getenv("WHISPER_BEST_OF", "5"))
POLL_SECONDS = float(os.getenv("POLL_SECONDS", "5"))
MAX_MESSAGE_CHARS = int(os.getenv("VOICE_STT_MAX_MESSAGE_CHARS", "1700"))
POST_TO_DISCORD = os.getenv("VOICE_STT_POST_DISCORD", "1") == "1"
DISCORD_CHANNEL_ID = os.getenv("VOICE_STT_DISCORD_CHANNEL_ID", "")
SKIP_EXISTING_ON_START = os.getenv("VOICE_STT_SKIP_EXISTING_ON_START", "1") == "1"
PRUNE_EXISTING_ON_START = os.getenv("VOICE_STT_PRUNE_EXISTING_ON_START", "1") == "1"
DELETE_AFTER_TRANSCRIBE = os.getenv("VOICE_STT_DELETE_AFTER_TRANSCRIBE", "1") == "1"


def log(msg: str):
    print(f"{LOG_PREFIX} {msg}", flush=True)


def init_db(conn: sqlite3.Connection):
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS processed (
            path TEXT PRIMARY KEY,
            mtime REAL NOT NULL,
            transcript TEXT,
            processed_at REAL NOT NULL
        )
        """
    )
    conn.commit()


def already_processed(conn: sqlite3.Connection, path: Path, mtime: float) -> bool:
    row = conn.execute("SELECT mtime FROM processed WHERE path = ?", (str(path),)).fetchone()
    return row is not None and float(row[0]) == float(mtime)


def mark_processed(conn: sqlite3.Connection, path: Path, mtime: float, transcript: str):
    conn.execute(
        "INSERT OR REPLACE INTO processed(path, mtime, transcript, processed_at) VALUES (?, ?, ?, ?)",
        (str(path), mtime, transcript, time.time()),
    )
    conn.commit()


def wait_until_stable(path: Path, checks: int = 3, delay: float = 1.0) -> bool:
    last_size = -1
    stable = 0
    for _ in range(checks * 2):
        if not path.exists():
            return False
        size = path.stat().st_size
        if size > 0 and size == last_size:
            stable += 1
            if stable >= checks:
                return True
        else:
            stable = 0
        last_size = size
        time.sleep(delay)
    return False


def save_transcript_file(audio_path: Path, transcript: str):
    TRANSCRIPTS_DIR.mkdir(parents=True, exist_ok=True)
    out = TRANSCRIPTS_DIR / f"{audio_path.stem}.md"
    out.write_text(
        f"# Transcript\n\n- Source: {audio_path}\n- Processed UTC: {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\n\n## Text\n{transcript}\n",
        encoding="utf-8",
    )


def load_openclaw_config() -> dict:
    try:
        return json.loads(OPENCLAW_CONFIG.read_text(encoding="utf-8"))
    except Exception:
        return {}


def first_allowed_discord_channel_id(cfg: dict) -> str:
    channels = (cfg.get("channels") or {}).get("discord") or {}
    guilds = channels.get("guilds") or {}
    for guild in guilds.values():
        channel_map = guild.get("channels") or {}
        for cid, cmeta in channel_map.items():
            if isinstance(cmeta, dict) and cmeta.get("allow", False):
                return str(cid)
    return ""


def resolve_discord_token(cfg: dict) -> str:
    if os.getenv("DISCORD_BOT_TOKEN"):
        return os.getenv("DISCORD_BOT_TOKEN", "")
    # Legacy/older config compatibility
    return ((cfg.get("channels") or {}).get("discord") or {}).get("token", "")


def send_discord_message(token: str, channel_id: str, content: str):
    if not token or not channel_id:
        return
    url = f"https://discord.com/api/v10/channels/{channel_id}/messages"
    resp = requests.post(
        url,
        headers={"Authorization": f"Bot {token}", "Content-Type": "application/json"},
        json={"content": content[:MAX_MESSAGE_CHARS]},
        timeout=30,
    )
    if resp.status_code >= 300:
        raise RuntimeError(f"Discord API error {resp.status_code}: {resp.text[:300]}")


def transcribe_file(model: WhisperModel, audio_path: Path) -> str:
    kwargs = {
        "vad_filter": True,
        "beam_size": BEAM_SIZE,
        "best_of": BEST_OF,
    }
    if LANGUAGE and LANGUAGE.lower() != "auto":
        kwargs["language"] = LANGUAGE

    segments, _info = model.transcribe(str(audio_path), **kwargs)
    text = " ".join(seg.text.strip() for seg in segments).strip()
    return text or "(No speech detected)"


def list_audio_files() -> list[Path]:
    patterns = ["*.ogg", "*.mp3", "*.wav", "*.m4a", "*.webm"]
    files = []
    for pat in patterns:
        files.extend(INBOUND_DIR.glob(pat))
    return sorted(set(files), key=lambda p: p.stat().st_mtime)


def bootstrap_existing_files(conn: sqlite3.Connection, startup_epoch: float):
    if not SKIP_EXISTING_ON_START:
        return

    skipped = 0
    pruned = 0
    for path in list_audio_files():
        try:
            mtime = path.stat().st_mtime
        except FileNotFoundError:
            continue
        if mtime > startup_epoch:
            continue

        if not already_processed(conn, path, mtime):
            mark_processed(conn, path, mtime, "")
            skipped += 1

        if PRUNE_EXISTING_ON_START:
            try:
                path.unlink(missing_ok=True)
                pruned += 1
            except Exception as e:
                log(f"WARN prune failed for {path.name}: {e}")

    if skipped:
        log(f"Startup skip: marked {skipped} pre-existing audio files as processed")
    if pruned:
        log(f"Startup cleanup: removed {pruned} pre-existing audio files")


def main():
    VOICE_DIR.mkdir(parents=True, exist_ok=True)
    TRANSCRIPTS_DIR.mkdir(parents=True, exist_ok=True)

    log(f"Loading model '{MODEL_NAME}' ({COMPUTE_TYPE}, lang={LANGUAGE})...")
    model = WhisperModel(MODEL_NAME, device="cpu", compute_type=COMPUTE_TYPE)

    cfg = load_openclaw_config()
    token = resolve_discord_token(cfg)
    channel_id = DISCORD_CHANNEL_ID or first_allowed_discord_channel_id(cfg)
    if POST_TO_DISCORD and token and channel_id:
        log(f"Discord posting enabled -> channel {channel_id}")
    else:
        log("Discord posting disabled or missing token/channel")

    conn = sqlite3.connect(STATE_DB)
    init_db(conn)

    startup_epoch = time.time()
    bootstrap_existing_files(conn, startup_epoch)

    log(f"Watching {INBOUND_DIR}")
    while True:
        try:
            files = list_audio_files()

            for path in files:
                mtime = path.stat().st_mtime
                if already_processed(conn, path, mtime):
                    continue
                if not wait_until_stable(path):
                    continue

                log(f"Transcribing {path.name}")
                transcript = transcribe_file(model, path)
                save_transcript_file(path, transcript)

                if POST_TO_DISCORD and token and channel_id:
                    msg = f"📝 Voice transcript ({path.name}):\n{transcript}"
                    send_discord_message(token, channel_id, msg)
                mark_processed(conn, path, mtime, transcript)

                if DELETE_AFTER_TRANSCRIBE:
                    try:
                        path.unlink(missing_ok=True)
                    except Exception as e:
                        log(f"WARN cleanup failed for {path.name}: {e}")

                log(f"Done {path.name}")

        except Exception as e:
            log(f"ERROR: {e}")

        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
