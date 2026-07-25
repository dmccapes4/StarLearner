#!/usr/bin/env python3
"""Install the Math Explorer kiosk tile (512×512) into the launcher drawable.

Source art lives at tools/tile_math_source.png (generated illustration: the
Star Learner girl packing eggs into a carton, with a hen and the knowledge
star). Re-run after replacing the source:

  python3 tools/make_tile.py

The launcher resolves the drawable by name (catalog.json "tile": "tile_math"),
so the output filename must not change. Rebuild the kiosk APK to pick it up.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = Path(__file__).resolve().parent / "tile_math_source.png"
OUT = (
    ROOT.parent
    / "ant_explorer/kiosk_placeholder/app/src/main/res/drawable/tile_math.png"
)


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"missing source: {SRC}")
    im = Image.open(SRC).convert("RGB")
    w, h = im.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    tile = im.crop((left, top, left + side, top + side)).resize(
        (512, 512), Image.Resampling.LANCZOS
    )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    tile.save(OUT, optimize=True)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
