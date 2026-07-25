#!/usr/bin/env python3
"""Install / document the Star Learner tile_language drawable.

Preferred art is the cinematic agent-generated tile (Pixar-like 3D, glowing
knowledge star) kept beside the ants/garden tiles. This script only copies a
source PNG into the kiosk drawable path when provided.

  python3 tools/make_tile.py [path/to/tile_language.png]
"""
from __future__ import annotations

import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = (
    ROOT.parent
    / "ant_explorer/kiosk_placeholder/app/src/main/res/drawable/tile_language.png"
)


def main() -> None:
    if len(sys.argv) < 2:
        print(f"current tile: {OUT} exists={OUT.exists()}")
        print("usage: python3 tools/make_tile.py <source.png>")
        return
    src = Path(sys.argv[1]).expanduser().resolve()
    im = Image.open(src).convert("RGB").resize((512, 512), Image.Resampling.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    im.save(OUT, optimize=True)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
