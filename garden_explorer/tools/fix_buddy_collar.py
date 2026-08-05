#!/usr/bin/env python3
"""Paint Buddy's collar on idle / walk / portrait (all facings).

  python3 tools/fix_buddy_collar.py

Edits in place:
  game/assets/animals/dog_idle.png
  game/assets/animals/dog_walk.png
  game/assets/portraits/animal_dog.png

Walk sheet columns: 0=back, 1=right, 2=front, 3=left.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "game/assets"

RED = (214, 46, 46, 255)
RED_DARK = (168, 28, 28, 255)
RED_HI = (238, 78, 78, 255)
TAG = (236, 198, 64, 255)
TAG_DARK = (168, 120, 28, 255)


def is_collar_red(p: tuple[int, int, int, int]) -> bool:
    r, g, b, a = p
    return a > 180 and r > 150 and g < 100 and b < 100 and r > g + 60


def is_our_tag(p: tuple[int, int, int, int]) -> bool:
    return p[:3] in (TAG[:3], TAG_DARK[:3])


def fill_from_neighbors(im: Image.Image, x: int, y: int) -> tuple[int, int, int, int]:
    px = im.load()
    w, h = im.size
    for dy, dx in ((1, 0), (-1, 0), (2, 0), (-2, 0), (0, 1), (0, -1), (1, 1), (1, -1)):
        nx, ny = x + dx, y + dy
        if 0 <= nx < w and 0 <= ny < h:
            p = px[nx, ny]
            if p[3] > 180 and not is_collar_red(p) and not is_our_tag(p):
                return p
    return (196, 148, 88, 255)


def clear_collar_art(im: Image.Image) -> Image.Image:
    """Remove prior red bar / our previous collar+tag so re-runs are idempotent."""
    out = im.copy()
    px = out.load()
    w, h = out.size
    doomed = [
        (x, y)
        for y in range(h)
        for x in range(w)
        if is_collar_red(px[x, y]) or is_our_tag(px[x, y])
    ]
    for x, y in doomed:
        px[x, y] = fill_from_neighbors(out, x, y)
    return out


def put(px, x: int, y: int, c: tuple[int, int, int, int], w: int, h: int) -> None:
    if 0 <= x < w and 0 <= y < h:
        px[x, y] = c


def paint_pixels(im: Image.Image, pixels: list[tuple[float, float, tuple]]) -> None:
    """Stamp collar pixels in 48×48 design space (scales to image size)."""
    px = im.load()
    w, h = im.size
    sx = w / 48.0
    sy = h / 48.0
    brush = max(1, int(round(min(sx, sy))))
    for x, y, c in pixels:
        bx = int(round(x * sx))
        by = int(round(y * sy))
        for dy in range(brush):
            for dx in range(brush):
                put(px, bx + dx, by + dy, c, w, h)


def paint_back_collar(im: Image.Image) -> None:
    """Facing away — short band across the nape (no tag)."""
    pixels = [
        (18, 22, RED_DARK),
        (19, 22, RED),
        (20, 22, RED_HI),
        (21, 22, RED),
        (22, 22, RED),
        (23, 22, RED_HI),
        (24, 22, RED),
        (25, 22, RED),
        (26, 22, RED_HI),
        (27, 22, RED),
        (28, 22, RED_DARK),
        (19, 23, RED_DARK),
        (20, 23, RED),
        (21, 23, RED),
        (22, 23, RED_HI),
        (23, 23, RED),
        (24, 23, RED),
        (25, 23, RED),
        (26, 23, RED_DARK),
        (27, 23, RED_DARK),
    ]
    paint_pixels(im, pixels)


def paint_front_collar(im: Image.Image) -> None:
    """Facing camera — band under the chin + center tag."""
    pixels = [
        (19, 25, RED_DARK),
        (20, 25, RED),
        (21, 25, RED_HI),
        (22, 25, RED),
        (23, 25, RED),
        (24, 25, RED),
        (25, 25, RED_HI),
        (26, 25, RED),
        (27, 25, RED_DARK),
        (20, 26, RED_DARK),
        (21, 26, RED),
        (22, 26, RED),
        (23, 26, RED_HI),
        (24, 26, RED),
        (25, 26, RED),
        (26, 26, RED_DARK),
        (23, 27, TAG),
        (24, 27, TAG_DARK),
        (23, 28, TAG_DARK),
        (24, 28, TAG),
    ]
    paint_pixels(im, pixels)


def paint_side_collar(im: Image.Image, facing_right: bool) -> None:
    """Profile — wrap at the neck (where body meets head), not mid-flank."""
    # Design space assumes facing RIGHT (head toward +x / cream muzzle).
    # Neck sits ~x=30–34 at y=22–25 on the 48×48 walk cells.
    base = [
        # nape tuck (top of neck)
        (30, 22, RED_DARK),
        (31, 22, RED),
        (32, 22, RED_HI),
        # main wrap around neck
        (29, 23, RED_DARK),
        (30, 23, RED),
        (31, 23, RED_HI),
        (32, 23, RED),
        (33, 23, RED),
        (34, 23, RED_DARK),
        (29, 24, RED_DARK),
        (30, 24, RED_HI),
        (31, 24, RED),
        (32, 24, RED),
        (33, 24, RED_HI),
        (34, 24, RED),
        (30, 25, RED_DARK),
        (31, 25, RED),
        (32, 25, RED_DARK),
        (33, 25, RED),
        # tag hangs at throat (front of neck)
        (33, 26, TAG),
        (34, 26, TAG_DARK),
        (33, 27, TAG_DARK),
        (34, 27, TAG),
    ]
    if facing_right:
        pixels = base
    else:
        pixels = [(47 - x, y, c) for x, y, c in base]
    paint_pixels(im, pixels)


def fix_idle(path: Path) -> None:
    im = clear_collar_art(Image.open(path).convert("RGBA"))
    paint_side_collar(im, facing_right=True)
    im.save(path)
    print("fixed", path)


def fix_portrait(path: Path) -> None:
    im = clear_collar_art(Image.open(path).convert("RGBA"))
    paint_side_collar(im, facing_right=True)
    im.save(path)
    print("fixed", path)


def fix_walk(path: Path) -> None:
    sheet = Image.open(path).convert("RGBA")
    cell = 48
    out = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    for row in range(4):
        for col in range(4):
            box = (col * cell, row * cell, (col + 1) * cell, (row + 1) * cell)
            frame = clear_collar_art(sheet.crop(box))
            if col == 0:
                paint_back_collar(frame)
            elif col == 1:
                paint_side_collar(frame, facing_right=True)
            elif col == 2:
                paint_front_collar(frame)
            else:
                paint_side_collar(frame, facing_right=False)
            out.paste(frame, box[:2])
    out.save(path)
    print("fixed", path)


def main() -> None:
    fix_idle(ASSETS / "animals/dog_idle.png")
    walk = ASSETS / "animals/dog_walk.png"
    if walk.exists():
        fix_walk(walk)
    port = ASSETS / "portraits/animal_dog.png"
    if port.exists():
        fix_portrait(port)


if __name__ == "__main__":
    main()
