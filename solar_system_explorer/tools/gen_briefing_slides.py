#!/usr/bin/env python3
"""Install Rocket Science briefing stills into game/images/briefing/.

Authoritative art lives in tools/briefing_slides_src/ (hand-generated
illustrations — not the old block diagrams). This script copies them into
the Godot tree. Re-run after replacing any source PNG:

  python3 tools/gen_briefing_slides.py
  (then) godot --headless --path game --import
"""
from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tools" / "briefing_slides_src"
OUT = ROOT / "game" / "images" / "briefing"

SLIDES = [
    "engine_chemical",
    "engine_ntp",
    "engine_orion",
    "window",
    "coast",
    "fuel",
    "assists",
]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    missing = []
    for name in SLIDES:
        src = SRC / f"{name}.png"
        if not src.is_file():
            missing.append(src.name)
            continue
        dst = OUT / f"{name}.png"
        shutil.copy2(src, dst)
        print(f"copied {src.relative_to(ROOT)} → {dst.relative_to(ROOT)}")
    if missing:
        raise SystemExit(
            "missing source slides in tools/briefing_slides_src/: "
            + ", ".join(missing)
        )


if __name__ == "__main__":
    main()
