#!/usr/bin/env python3
"""Bake docs/demo explainer VO from explainer_narration.json (ElevenLabs)."""
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
SCRIPT = ROOT / "docs" / "demo" / "explainer_narration.json"
OUT = ROOT / "docs" / "demo" / "vo"
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
        sys.exit(f"ERROR: ELEVENLABS_API_KEY not set (see {SECRETS})")
    return key


def synth(text: str, wav: Path) -> None:
    voice = os.environ.get("ELEVEN_VOICE_ID", "XrExE9yKIg1WjnnlVkGX")
    model = os.environ.get("ELEVEN_MODEL", "eleven_multilingual_v2")
    payload = {
        "text": text,
        "model_id": model,
        "voice_settings": {
            "stability": 0.55,
            "similarity_boost": 0.75,
            "style": 0.0,
            "use_speaker_boost": True,
            "speed": 0.92,
        },
    }
    req = urllib.request.Request(
        f"{API_BASE}/{voice}?output_format=mp3_44100_128",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "xi-api-key": api_key(),
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        },
        method="POST",
    )
    with tempfile.TemporaryDirectory() as td:
        mp3 = Path(td) / "t.mp3"
        with urllib.request.urlopen(req, timeout=60) as resp:
            mp3.write_bytes(resp.read())
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
             "-i", str(mp3), "-ac", "1", "-ar", "22050", "-c:a", "pcm_s16le", str(wav)],
            check=True,
        )


def main() -> None:
    load_secrets()
    force = "--force" in sys.argv
    data = json.loads(SCRIPT.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    n = 0
    for line in data.get("lines", []):
        key = str(line["key"])
        text = str(line["text"]).strip()
        wav = OUT / f"{key}.wav"
        if wav.exists() and not force:
            print(f"  skip {key}")
            continue
        print(f"  synth {key}")
        synth(text, wav)
        n += 1
    print(f"Done. {n} new clips → {OUT}")


if __name__ == "__main__":
    main()
