#!/usr/bin/env python3
"""Generate isometric pen-gate leaf frames (closed → open).

Leaf + free-swinging end post. FarmMap draws the hinge-side framing post.
Palette matches Sprout Lands Fences.png / FarmMap pen rails.

Rails sit mid-post so they line up with neighboring fence rails.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/assets/ui/gate"

WOOD_MID = (170, 121, 89, 255)
WOOD_LIGHT = (196, 154, 108, 255)
WOOD_HI = (232, 207, 166, 255)
WOOD_DARK = (122, 81, 40, 255)
WOOD_EDGE = (90, 58, 32, 255)

W, H = 64, 64


def _blank() -> Image.Image:
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def _draw_post(draw: ImageDraw.ImageDraw, bx: float, by: float, h: float = 26, r: float = 3.2) -> None:
    draw.polygon(
        [
            (bx - r, by - h + 4),
            (bx + r, by - h + 4),
            (bx + r + 1, by),
            (bx - r - 1, by),
        ],
        fill=WOOD_MID,
        outline=WOOD_EDGE,
    )
    draw.polygon(
        [
            (bx + 0.4, by - h + 4),
            (bx + r, by - h + 4),
            (bx + r + 1, by),
            (bx + 0.4, by),
        ],
        fill=WOOD_DARK,
    )
    draw.ellipse([bx - r, by - h - 2, bx + r, by - h + 6], fill=WOOD_LIGHT, outline=WOOD_EDGE)
    draw.ellipse([bx - r + 1, by - h - 1, bx + 1, by - h + 3], fill=WOOD_HI)


def _draw_rail(draw: ImageDraw.ImageDraw, a: tuple, b: tuple, y_off: float, thick: float = 3.4) -> None:
    ax, ay = a[0], a[1] + y_off
    bx, by = b[0], b[1] + y_off
    dx, dy = bx - ax, by - ay
    L = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / L * thick / 2, dx / L * thick / 2
    draw.polygon(
        [
            (ax - nx, ay - ny - 1),
            (bx - nx, by - ny - 1),
            (bx + nx, by + ny + 1),
            (ax + nx, ay + ny + 1),
        ],
        fill=WOOD_LIGHT,
        outline=WOOD_EDGE,
    )
    draw.line(
        [(ax - nx * 0.2, ay - ny * 0.2 - 1), (bx - nx * 0.2, by - ny * 0.2 - 1)],
        fill=WOOD_HI,
        width=1,
    )
    draw.line(
        [(ax + nx * 0.4, ay + ny * 0.4 + 1), (bx + nx * 0.4, by + ny * 0.4 + 1)],
        fill=WOOD_DARK,
        width=1,
    )


def make_frame(open_t: float) -> Image.Image:
    im = _blank()
    d = ImageDraw.Draw(im)
    ## Ground contact of the hinge (FarmMap draws the real hinge post).
    hinge = (14.0, 48.0)
    closed = (2.0, -1.0)  # west-edge iso dy/dx = -0.5
    opened = (1.6, 1.1)
    dx = closed[0] * (1 - open_t) + opened[0] * open_t
    dy = closed[1] * (1 - open_t) + opened[1] * open_t
    n = math.hypot(dx, dy) or 1.0
    dx, dy = dx / n, dy / n
    tip = (hinge[0] + dx * 40.0, hinge[1] + dy * 40.0)
    ## Seat rails into the end post (stop short of tip center).
    tip_rail = (tip[0] - dx * 2.5, tip[1] - dy * 2.5)
    _draw_post(d, tip[0], tip[1], h=28, r=3.1)
    _draw_rail(d, hinge, tip_rail, -16, thick=3.2)
    _draw_rail(d, hinge, tip_rail, -9, thick=3.2)
    for i in range(1, 4):
        t = i / 4.0
        px = hinge[0] + (tip_rail[0] - hinge[0]) * t
        py = hinge[1] + (tip_rail[1] - hinge[1]) * t
        d.line([(px, py - 17), (px, py - 7)], fill=WOOD_MID, width=2)
        d.point((int(px), int(py - 17)), fill=WOOD_HI)
    _draw_post(d, tip[0], tip[1], h=28, r=3.1)
    return im


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    frames = []
    for i, t in enumerate([0.0, 0.25, 0.5, 0.75, 1.0]):
        im = make_frame(t)
        path = OUT / f"open_{i}.png"
        im.save(path)
        frames.append(im)
        print(f"wrote {path.relative_to(ROOT)}")
    sheet = Image.new("RGBA", (W * 5, H), (20, 20, 20, 255))
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i * W, 0), fr)
    sheet.save(OUT / "sheet_preview.png")
    print(f"wrote {(OUT / 'sheet_preview.png').relative_to(ROOT)}")


if __name__ == "__main__":
    main()
