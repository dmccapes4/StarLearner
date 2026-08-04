#!/usr/bin/env python3
"""Process HD shed tool masters → 160×160 transparent UI tiles.

Masters live in tools/*_source.png (or Cursor assets/). Black backgrounds
become transparent; content is centered with light padding.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / "game/assets/ui"
TOOLS = ROOT / "tools"

# master → (tile out, optional carry out)
JOBS = [
    ("tile_return_item_source.png", "tile_return_item.png", None),
    ("tile_watering_can_source.png", "tile_watering_can.png", "carry_watering_can.png"),
    ("tile_spade_source.png", "tile_spade.png", "carry_spade.png"),
    ("tile_seed_pouch_source.png", "tile_seed_pouch.png", None),
]


def process(src: Path, out: Path) -> None:
    im = Image.open(src).convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r < 40 and g < 40 and b < 40:
                px[x, y] = (0, 0, 0, 0)
    bb = im.split()[-1].getbbox()
    crop = im.crop(bb) if bb else im
    pad = int(max(crop.size) * 0.08)
    side = max(crop.width, crop.height) + pad * 2
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(crop, ((side - crop.width) // 2, (side - crop.height) // 2), crop)
    final = sq.resize((160, 160), Image.Resampling.LANCZOS)
    out.parent.mkdir(parents=True, exist_ok=True)
    final.save(out, optimize=True)
    print(f"wrote {out.relative_to(ROOT)} ({final.size[0]}x{final.size[1]})")


def main() -> None:
    for master_name, tile_name, carry_name in JOBS:
        src = TOOLS / master_name
        if not src.exists():
            print(f"skip missing {src.name}")
            continue
        process(src, UI / tile_name)
        if carry_name:
            process(src, UI / carry_name)


if __name__ == "__main__":
    main()
