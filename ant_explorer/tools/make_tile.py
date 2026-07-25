#!/usr/bin/env python3
"""Install the Ant Explorer kiosk tile (512×512) into the launcher drawable.

Source art lives at tools/tile_ants_source.png (generated illustration:
leafcutter ant + knowledge star in a warm nest cutaway). Re-run after
replacing the source:

  python3 tools/make_tile.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = Path(__file__).resolve().parent / "tile_ants_source.png"
OUT = ROOT / "kiosk_placeholder/app/src/main/res/drawable/tile_ants.png"
DOCS = ROOT / "docs/tile_ants.png"


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"missing source: {SRC}")
    im = Image.open(SRC).convert("RGB")
    w, h = im.size
    side = min(w, h)
    left = (w - side) // 2
    top = max(0, (h - side) // 2 - side // 20)
    if top + side > h:
        top = h - side
    tile = im.crop((left, top, left + side, top + side)).resize(
        (512, 512), Image.Resampling.LANCZOS
    )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    DOCS.parent.mkdir(parents=True, exist_ok=True)
    tile.save(OUT, optimize=True)
    tile.save(DOCS, optimize=True)
    print(f"wrote {OUT}")
    print(f"wrote {DOCS}")


if __name__ == "__main__":
    main()
