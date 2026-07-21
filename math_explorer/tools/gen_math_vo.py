#!/usr/bin/env python3
"""Bake Math Explorer narration WAVs with ElevenLabs.

Pipeline:
  1. godot --headless --path game -s res://tools/dump_vo_lines.gd
       -> game/data/math_vo_manifest.json   (md5 key -> sentence)
  2. ./tools/gen_math_vo.py                 (this script; idempotent)
       -> game/audio/vo/<md5>.wav           (16-bit PCM mono 22050 Hz)

Narrator.gd hashes each spoken sentence the same way at runtime and plays the
baked clip, falling back to OS TTS only if a clip is missing.

Auth: ELEVENLABS_API_KEY in env, or ant_explorer/tools/secrets/elevenlabs.env
(shared family key; that folder is gitignored).

Voice knobs match the other Star Learner titles (warm Matilda narrator):
  ELEVEN_VOICE_ID / ELEVEN_MODEL / ELEVEN_SPEED / ELEVEN_STABILITY
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "game" / "data" / "math_vo_manifest.json"
VO_DIR = ROOT / "game" / "audio" / "vo"
SECRETS = ROOT.parent / "ant_explorer" / "tools" / "secrets" / "elevenlabs.env"

API_BASE = "https://api.elevenlabs.io/v1/text-to-speech"


def load_secrets() -> None:
    if SECRETS.exists():
        for line in SECRETS.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def api_key() -> str:
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not key:
        sys.exit(
            "ERROR: ELEVENLABS_API_KEY not set.\n"
            f"  Put it in {SECRETS} as:  ELEVENLABS_API_KEY=sk_...\n"
            "  — or export it in your shell."
        )
    return key


def synth_mp3(text: str, out_mp3: Path) -> None:
    voice = os.environ.get("ELEVEN_VOICE_ID", "XrExE9yKIg1WjnnlVkGX")
    model = os.environ.get("ELEVEN_MODEL", "eleven_multilingual_v2")
    speed = float(os.environ.get("ELEVEN_SPEED", "0.92"))
    stability = float(os.environ.get("ELEVEN_STABILITY", "0.55"))
    payload = {
        "text": text,
        "model_id": model,
        "voice_settings": {
            "stability": stability,
            "similarity_boost": 0.75,
            "style": 0.0,
            "use_speaker_boost": True,
            "speed": speed,
        },
    }
    url = f"{API_BASE}/{voice}?output_format=mp3_44100_128"
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "xi-api-key": api_key(),
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            out_mp3.write_bytes(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:400]
        sys.exit(f"ERROR: ElevenLabs {e.code} for '{text[:40]}...': {body}")


def to_wav(mp3: Path, wav: Path) -> None:
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
         "-i", str(mp3), "-ac", "1", "-ar", "22050",
         "-c:a", "pcm_s16le", str(wav)],
        check=True,
    )


def main() -> None:
    load_secrets()
    force = "--force" in sys.argv[1:]
    if not MANIFEST.exists():
        sys.exit(f"ERROR: {MANIFEST} missing — run dump_vo_lines.gd first.")
    entries: dict[str, str] = json.loads(MANIFEST.read_text(encoding="utf-8"))
    VO_DIR.mkdir(parents=True, exist_ok=True)

    todo = {k: v for k, v in entries.items()
            if force or not (VO_DIR / f"{k}.wav").exists()}
    print(f"{len(entries)} sentences in manifest; {len(todo)} to synthesize.")
    chars = sum(len(v) for v in todo.values())
    print(f"~{chars} ElevenLabs characters.")

    n = 0
    with tempfile.TemporaryDirectory() as td:
        for key, text in sorted(todo.items()):
            mp3 = Path(td) / f"{key}.mp3"
            wav = VO_DIR / f"{key}.wav"
            print(f"  [{n + 1}/{len(todo)}] {text[:64]}")
            synth_mp3(text, mp3)
            to_wav(mp3, wav)
            n += 1

    # Prune clips whose sentence no longer exists (text edits leave orphans).
    stale = [p for p in VO_DIR.glob("*.wav") if p.stem not in entries]
    for p in stale:
        p.unlink()
        print(f"  pruned stale {p.name}")

    print(f"\nDone. {n} new clips, {len(stale)} pruned → {VO_DIR}")


if __name__ == "__main__":
    main()
