#!/usr/bin/env python3
"""Generate kid-readable 2-frame pixel bug sprites for the yard.

  python3 tools/gen_bug_sprites.py

Writes game/assets/bugs/<id>.png as 64×32 sheets (2 × 32×32 frames).
Frame 0 = pose A, frame 1 = pose B (legs/wings/body shift).
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game/assets/bugs"
CELL = 32
BUGS = [
    "ladybug",
    "rolly_polly",
    "earthworm",
    "honeybee",
    "butterfly",
    "ant",
    "aphid",
    "caterpillar",
    "spider",
    "grasshopper",
    "snail",
    "praying_mantis",
]


def blank(w: int = CELL, h: int = CELL) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(px, x: int, y: int, c, w: int = CELL, h: int = CELL) -> None:
    if 0 <= x < w and 0 <= y < h:
        px[x, y] = c


def oval(px, cx, cy, rx, ry, c) -> None:
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if ((x - cx) / max(rx, 1)) ** 2 + ((y - cy) / max(ry, 1)) ** 2 <= 1.05:
                put(px, x, y, c)


def draw_ladybug(frame: int) -> Image.Image:
    im = blank()
    px = im.load()
    bob = frame  # 0/1 body bob
    oval(px, 16, 16 + bob, 10, 8, (220, 48, 48, 255))
    oval(px, 16, 16 + bob, 8, 6, (235, 60, 60, 255))
    # head
    oval(px, 7, 15 + bob, 4, 4, (28, 28, 28, 255))
    put(px, 5, 14 + bob, (28, 28, 28, 255))  # antenna tip
    # spots (shift on frame 1)
    spots = ((13, 13), (19, 14), (14, 18), (20, 19), (16, 16))
    for i,(x,y) in enumerate(spots):
        yy = y + bob + (1 if frame and i % 2 == 0 else 0)
        put(px, x, yy, (20, 20, 20, 255))
        put(px, x + 1, yy, (20, 20, 20, 255))
        put(px, x, yy + 1, (20, 20, 20, 255))
    # midline
    for y in range(10, 24):
        put(px, 16, y + bob, (30, 30, 30, 255))
    # legs — alternate crawl
    legs0 = ((10, 0), (12, 1), (14, 0), (18, 1), (20, 0), (22, 1))
    legs1 = ((10, 1), (12, 0), (14, 1), (18, 0), (20, 1), (22, 0))
    for x, dy in (legs1 if frame else legs0):
        put(px, x, 24 + bob + dy, (30, 30, 30, 255))
        put(px, x, 25 + bob + dy, (30, 30, 30, 255))
    return im


def draw_rolly(frame: int) -> Image.Image:
    im = blank()
    px = im.load()
    r = 8 + frame
    oval(px, 16, 16, r, r - 1, (140, 120, 90, 255))
    oval(px, 16, 16, r - 2, r - 3, (170, 150, 110, 255))
    # segments
    for y in range(10, 23, 2):
        for x in range(10, 23):
            if abs(x - 16) + abs(y - 16) < r + 1 and (x + y) % 4 == 0:
                put(px, x, y, (110, 90, 60, 255))
    put(px, 11, 14, (40, 40, 40, 255))
    put(px, 11, 16, (40, 40, 40, 255))
    return im


def draw_worm(frame: int) -> Image.Image:
    im = blank()
    px = im.load()
    # Sine-ish body
    for i, x in enumerate(range(6, 26)):
        y = 16 + (1 if (i + frame) % 4 < 2 else -1) * (1 if i % 2 == 0 else 0)
        put(px, x, y, (180, 110, 100, 255))
        put(px, x, y + 1, (150, 80, 70, 255))
        put(px, x, y - 1, (200, 140, 120, 255))
    put(px, 25, 15 + frame, (120, 60, 50, 255))  # tip
    return im


def draw_bee(frame: int) -> Image.Image:
    im = blank()
    px = im.load()
    wing_y = 10 - frame
    oval(px, 16, 17, 7, 5, (240, 200, 40, 255))
    for x in range(11, 22, 3):
        for y in range(14, 21):
            put(px, x, y, (30, 30, 30, 255))
    oval(px, 9, 16, 3, 3, (30, 30, 30, 255))
    # wings
    oval(px, 14, wing_y, 4, 3, (200, 230, 255, 180))
    oval(px, 20, wing_y + frame, 4, 3, (200, 230, 255, 180))
    return im


def draw_butterfly(frame: int) -> Image.Image:
    im = blank()
    px = im.load()
    open_w = 2 if frame == 0 else 0
    # wings
    oval(px, 10 - open_w, 14, 5, 6, (180, 100, 220, 255))
    oval(px, 22 + open_w, 14, 5, 6, (180, 100, 220, 255))
    oval(px, 10 - open_w, 20, 4, 4, (120, 180, 240, 255))
    oval(px, 22 + open_w, 20, 4, 4, (120, 180, 240, 255))
    # body
    for y in range(10, 24):
        put(px, 16, y, (40, 40, 40, 255))
    return im


def draw_ant(frame: int) -> Image.Image:
    im = blank()
    px = im.load()
    oval(px, 10, 16, 3, 3, (40, 40, 40, 255))
    oval(px, 16, 16, 3, 2, (50, 50, 50, 255))
    oval(px, 22, 16, 4, 3, (40, 40, 40, 255))
    # legs
    for x, dy in ((12, 0), (16, frame), (20, 1 - frame)):
        put(px, x, 20 + dy, (30, 30, 30, 255))
        put(px, x - 1, 21 + dy, (30, 30, 30, 255))
        put(px, x + 1, 21 + dy, (30, 30, 30, 255))
    put(px, 7, 14, (30, 30, 30, 255))  # antenna
    put(px, 6, 13 - frame, (30, 30, 30, 255))
    return im


def draw_aphid(frame: int) -> Image.Image:
    im = blank()
    px = im.load()
    oval(px, 16, 17 + frame, 6, 4, (90, 170, 70, 255))
    oval(px, 11, 16 + frame, 2, 2, (70, 140, 50, 255))
    put(px, 9, 15 + frame, (40, 80, 30, 255))
    put(px, 21, 15 + frame, (40, 80, 30, 255))
    return im


def draw_caterpillar(frame: int) -> Image.Image:
    im = blank()
    px = im.load()
    for i, x in enumerate(range(8, 25, 3)):
        y = 16 + ((i + frame) % 2)
        oval(px, x, y, 3, 3, (80, 160, 60, 255))
        put(px, x, y - 2, (200, 80, 80, 255))  # bristle
    put(px, 8, 15, (40, 40, 40, 255))
    put(px, 8, 17, (40, 40, 40, 255))
    return im


def draw_spider(frame: int) -> Image.Image:
    im = blank()
    px = im.load()
    oval(px, 16, 16, 4, 4, (50, 40, 40, 255))
    oval(px, 16, 20, 5, 4, (60, 50, 50, 255))
    # 8 legs
    for i, (dx, dy) in enumerate(
        [(-6, -2), (-7, 0), (-6, 2), (-5, 4), (6, -2), (7, 0), (6, 2), (5, 4)]
    ):
        ox = frame if i % 2 == 0 else -frame
        put(px, 16 + dx + ox, 16 + dy, (40, 30, 30, 255))
        put(px, 16 + dx + ox * 2, 16 + dy + 1, (40, 30, 30, 255))
    return im


def draw_grasshopper(frame: int) -> Image.Image:
    im = blank()
    px = im.load()
    oval(px, 14, 18, 7, 3, (90, 160, 50, 255))
    oval(px, 22, 16, 3, 3, (70, 130, 40, 255))
    # big hind leg
    put(px, 18, 20 + frame, (60, 100, 30, 255))
    put(px, 20, 22, (60, 100, 30, 255))
    put(px, 22, 24 - frame, (60, 100, 30, 255))
    put(px, 10, 19, (40, 40, 40, 255))
    return im


def draw_snail(frame: int) -> Image.Image:
    im = blank()
    px = im.load()
    oval(px, 18, 14, 7, 7, (180, 140, 90, 255))
    oval(px, 18, 14, 4, 4, (150, 110, 70, 255))
    # foot
    for x in range(8, 24):
        put(px, x, 22 + (frame if x % 2 == 0 else 0), (200, 180, 140, 255))
        put(px, x, 23, (180, 160, 120, 255))
    put(px, 8, 18, (200, 180, 140, 255))
    put(px, 7, 16 - frame, (40, 40, 40, 255))  # eyestalk
    put(px, 9, 16 - frame, (40, 40, 40, 255))
    return im


def draw_mantis(frame: int) -> Image.Image:
    im = blank()
    px = im.load()
    # body upright-ish
    for y in range(10, 24):
        put(px, 16, y, (100, 160, 60, 255))
        put(px, 17, y, (80, 140, 50, 255))
    oval(px, 16, 9, 3, 3, (120, 180, 70, 255))
    # arms
    arm = 0 if frame == 0 else 1
    for x in range(10, 16):
        put(px, x, 12 + arm, (90, 150, 55, 255))
    for x in range(17, 23):
        put(px, x, 12 + (1 - arm), (90, 150, 55, 255))
    put(px, 14, 24, (60, 100, 40, 255))
    put(px, 18, 24, (60, 100, 40, 255))
    return im


DRAWERS = {
    "ladybug": draw_ladybug,
    "rolly_polly": draw_rolly,
    "earthworm": draw_worm,
    "honeybee": draw_bee,
    "butterfly": draw_butterfly,
    "ant": draw_ant,
    "aphid": draw_aphid,
    "caterpillar": draw_caterpillar,
    "spider": draw_spider,
    "grasshopper": draw_grasshopper,
    "snail": draw_snail,
    "praying_mantis": draw_mantis,
}


def build_sheet(bug_id: str) -> Image.Image:
    drawer = DRAWERS[bug_id]
    sheet = Image.new("RGBA", (CELL * 2, CELL), (0, 0, 0, 0))
    sheet.paste(drawer(0), (0, 0))
    sheet.paste(drawer(1), (CELL, 0))
    return sheet


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    prev = ROOT / ".cache/tree_preview/bugs"
    prev.mkdir(parents=True, exist_ok=True)
    for bug_id in BUGS:
        sheet = build_sheet(bug_id)
        path = OUT / f"{bug_id}.png"
        sheet.save(path)
        sheet.resize((CELL * 2 * 3, CELL * 3), Image.NEAREST).save(prev / f"{bug_id}_x3.png")
        print("wrote", path)
    print("previews →", prev)


if __name__ == "__main__":
    main()
