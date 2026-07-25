#!/usr/bin/env python3
"""Composite 1..6 eggs into the open-carton sprite → carton_open_1..6.png.

The egg cartons in Math Explorer fill one egg at a time as she packs them. A
partly-filled *last* carton is how the game shows the leftover from division
("16 eggs is 2 full cartons and 4 in the last one"), so every count 1..6 needs a
picture. Rather than hand-draw six sprites, we reuse the two flat-vector sprites
we already have — carton_open.png and egg.png — and drop eggs into the cups.

Cups are a 2×3 grid: a back row (higher, slightly smaller in the art) and a
front row (lower, larger). We fill the fully-visible front row first, then the
back row, and always draw the back row before the front row so front eggs
overlap back eggs the way real eggs nest.

Usage:
    python3 tools/gen_carton_sprites.py
Idempotent / re-runnable. Tune SLOTS / EGG_H below if the art changes.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
STORY = ROOT / "game" / "images" / "story"
CARTON = STORY / "carton_open.png"
EGG = STORY / "egg.png"

# Egg height in carton-pixels (carton_open.png is 758×825).
EGG_H = 250

# Cup centres (x, y) where an egg centre sits, in carton_open.png coordinates.
# Front row is fully visible (fill first); back row nestles behind it.
FRONT = [(168, 640), (392, 660), (612, 655)]
BACK = [(196, 500), (398, 500), (600, 515)]

# Fill order: front-left, front-mid, front-right, then back row L→R.
FILL_ORDER = [("front", 0), ("front", 1), ("front", 2),
              ("back", 0), ("back", 1), ("back", 2)]


def _egg_scaled() -> Image.Image:
    egg = Image.open(EGG).convert("RGBA").crop(Image.open(EGG).getbbox())
    w, h = egg.size
    new_w = max(1, round(EGG_H * w / h))
    return egg.resize((new_w, EGG_H), Image.LANCZOS)


def _slot_xy(row: str, idx: int) -> tuple[int, int]:
    return (FRONT if row == "front" else BACK)[idx]


def render(count: int, egg: Image.Image, base: Image.Image) -> Image.Image:
    img = base.copy()
    present = FILL_ORDER[:count]
    # Draw back row before front row so front eggs overlap back eggs.
    order = sorted(present, key=lambda rc: 0 if rc[0] == "back" else 1)
    ew, eh = egg.size
    for row, idx in order:
        cx, cy = _slot_xy(row, idx)
        img.alpha_composite(egg, (round(cx - ew / 2), round(cy - eh / 2)))
    return img


def main() -> int:
    base = Image.open(CARTON).convert("RGBA")
    egg = _egg_scaled()
    for count in range(1, 7):
        out = STORY / f"carton_open_{count}.png"
        render(count, egg, base).save(out)
        print(f"wrote {out.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
