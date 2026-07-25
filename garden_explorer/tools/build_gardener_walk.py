#!/usr/bin/env python3
"""Compose the gardener-girl walk sheet from the Mana Seed Farmer Sprite free sample.

Layers (bottom -> top): body, pants, shirt, shoes, hair — palette-swapped to match
the reference avatar (light-brown hair, green overalls, yellow boots).

Source: game/assets/characters/mana_farmer/ (gitignored; Seliel the Shaper,
free sample — game use permitted, redistribution not).

Output: game/assets/characters/gardener_walk.png
  3 rows x 6 cols of 64x64 cells:
    row 0 = walk down  (cells 048,049,050 + mirrored)
    row 1 = walk right (cells 064..069, right-facing; flip_h in-engine for left)
    row 2 = walk up    (cells 052,053,054 + mirrored)
  Column 1 of each row doubles as the idle pose for that direction.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "game/assets/characters/mana_farmer/farmer base sheets"
OUT = ROOT / "game/assets/characters/gardener_walk.png"

CELL = 64

## Source base ramps (light -> dark), from the sample's palette guides.
HAIR_SRC = ["f8f0e0", "c8c8b8", "8898a0", "686878", "503850"]
CLOTH_SRC = ["58e0a0", "289860", "205040"]

## Targets matched to the reference gardener_girl.png.
HAIR_LIGHT_BROWN = ["e8ae6e", "cf8f4a", "b5732f", "8f5722", "6b3d18"]
OVERALLS_GREEN = ["8fae5c", "728d47", "4f6630"]
SHIRT_GREEN = ["cfe08e", "a8bf68", "7d9346"]
BOOTS_YELLOW = ["f2d15a", "d1a636", "9c7a22"]

LAYERS = [
    ("01body/fbas_1body_human_00.png", None, None),
    ("04lwr1/fbas_04lwr1_longpants_00a.png", CLOTH_SRC, OVERALLS_GREEN),
    ("05shrt/fbas_05shrt_shortshirt_00a.png", CLOTH_SRC, SHIRT_GREEN),
    ("03fot1/fbas_03fot1_shoes_00a.png", CLOTH_SRC, BOOTS_YELLOW),
    ("13hair/fbas_13hair_bob1_00a.png", HAIR_SRC, HAIR_LIGHT_BROWN),
]

## (cell_index, flip_h) per output frame.
DOWN = [(48, False), (49, False), (50, False), (48, True), (49, True), (50, True)]
RIGHT = [(64, False), (65, False), (66, False), (67, False), (68, False), (69, False)]
UP = [(52, False), (53, False), (54, False), (52, True), (53, True), (54, True)]


def hex_rgb(s: str) -> tuple:
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def remap(img: Image.Image, src: list, dst: list) -> Image.Image:
    table = {hex_rgb(a): hex_rgb(b) for a, b in zip(src, dst)}
    out = img.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in table:
                nr, ng, nb = table[(r, g, b)]
                px[x, y] = (nr, ng, nb, a)
    return out


def cell(img: Image.Image, i: int) -> Image.Image:
    c, r = i % 16, i // 16
    return img.crop((c * CELL, r * CELL, (c + 1) * CELL, (r + 1) * CELL))


def main() -> None:
    layers = []
    for rel, src, dst in LAYERS:
        img = Image.open(SRC / rel).convert("RGBA")
        if src:
            img = remap(img, src, dst)
        layers.append(img)

    sheet = Image.new("RGBA", (CELL * 6, CELL * 3), (0, 0, 0, 0))
    for row, frames in enumerate([DOWN, RIGHT, UP]):
        for col, (idx, flip) in enumerate(frames):
            frame = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            for layer in layers:
                piece = cell(layer, idx)
                if flip:
                    piece = piece.transpose(Image.FLIP_LEFT_RIGHT)
                frame.alpha_composite(piece)
            sheet.alpha_composite(frame, (col * CELL, row * CELL))
    sheet.save(OUT)
    print(f"OK {OUT} ({sheet.size[0]}x{sheet.size[1]})")


if __name__ == "__main__":
    main()
