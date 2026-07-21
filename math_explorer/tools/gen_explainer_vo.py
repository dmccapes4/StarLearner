#!/usr/bin/env python3
"""Bake the demo-explainer narration WAVs (docs/demo/vo/) with ElevenLabs.

Reads docs/demo/explainer_narration.json ({lines: [{key, text}]}) and writes
one WAV per line. Same voice knobs as gen_math_vo.py. Idempotent.
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_math_vo import load_secrets, synth_mp3, to_wav  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "docs" / "demo" / "explainer_narration.json"
VO_DIR = ROOT / "docs" / "demo" / "vo"


def main() -> None:
    load_secrets()
    force = "--force" in sys.argv[1:]
    lines = json.loads(SCRIPT.read_text(encoding="utf-8"))["lines"]
    VO_DIR.mkdir(parents=True, exist_ok=True)
    n = 0
    with tempfile.TemporaryDirectory() as td:
        for ln in lines:
            key, text = ln["key"], ln["text"].strip()
            wav = VO_DIR / f"{key}.wav"
            if wav.exists() and not force:
                continue
            print(f"  synth {key}: {text[:60]}")
            mp3 = Path(td) / f"{key}.mp3"
            synth_mp3(text, mp3)
            to_wav(mp3, wav)
            n += 1
    print(f"Done. {n} new clips → {VO_DIR}")


if __name__ == "__main__":
    main()
