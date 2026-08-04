#!/usr/bin/env python3
"""Generate isometric fence sprites.

Primary kit (used by FarmMap):
  rail_a / rail_b — rails only (no posts)
  post.png        — standalone post (placed on joints, above rails)

Legacy composites kept for reference / fallbacks:
  seg_diag_* (two posts), run_* (post on start)
Also: gate open frames
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
FENCE = ROOT / "game/assets/ui/fence"
GATE = ROOT / "game/assets/ui/gate"

WOOD_MID = (170, 121, 89, 255)
WOOD_LIGHT = (196, 154, 108, 255)
WOOD_HI = (232, 207, 166, 255)
WOOD_DARK = (122, 81, 40, 255)
WOOD_EDGE = (90, 58, 32, 255)


def _blank(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


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


def _draw_rail(draw: ImageDraw.ImageDraw, a: tuple, b: tuple, y_off: float, thick: float = 3.2) -> None:
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


def _segment(dx: float, dy: float, length: float, name: str, posts: str = "both") -> None:
    ## posts: "both" (corners), "start" (edge runs), "none" (rails only)
    n = math.hypot(dx, dy) or 1.0
    ux, uy = dx / n, dy / n
    p0 = (0.0, 0.0)
    p1 = (ux * length, uy * length)
    pad = 8
    xs = [p0[0], p1[0]]
    ys = [p0[1] - 28, p0[1], p1[1] - 28, p1[1]]
    minx, maxx = min(xs) - pad, max(xs) + pad
    miny, maxy = min(ys) - pad, max(ys) + pad
    im = _blank(int(math.ceil(maxx - minx)), int(math.ceil(maxy - miny)))
    d = ImageDraw.Draw(im)
    a = (p0[0] - minx, p0[1] - miny)
    b = (p1[0] - minx, p1[1] - miny)
    if posts in ("both", "start"):
        _draw_post(d, a[0], a[1])
    if posts == "both":
        _draw_post(d, b[0], b[1])
    _draw_rail(d, a, b, -18)
    _draw_rail(d, a, b, -10)
    ## No vertical balusters on rail-only — they read as extra posts at joins.
    if posts != "none":
        for i in range(1, 3):
            t = i / 3.0
            px = a[0] + (b[0] - a[0]) * t
            py = a[1] + (b[1] - a[1]) * t
            d.line([(px, py - 20), (px, py - 8)], fill=WOOD_MID, width=2)
    bb = im.split()[-1].getbbox()
    if bb:
        im = im.crop(bb)
    FENCE.mkdir(parents=True, exist_ok=True)
    im.save(FENCE / f"{name}.png")
    print(f"wrote fence/{name}.png {im.size} posts={posts}")


def _gate_leaf(open_t: float) -> Image.Image:
    length = 24.0
    im = _blank(48, 52)
    d = ImageDraw.Draw(im)
    hinge = (10.0, 40.0)
    closed = (2.0, -1.0)
    opened = (1.6, 1.1)
    dx = closed[0] * (1 - open_t) + opened[0] * open_t
    dy = closed[1] * (1 - open_t) + opened[1] * open_t
    n = math.hypot(dx, dy) or 1.0
    dx, dy = dx / n, dy / n
    tip = (hinge[0] + dx * length, hinge[1] + dy * length)
    _draw_post(d, tip[0], tip[1], h=22, r=2.8)
    _draw_post(d, hinge[0], hinge[1], h=22, r=2.4)
    _draw_rail(d, hinge, tip, -16, thick=2.8)
    _draw_rail(d, hinge, tip, -9, thick=2.8)
    for i in range(1, 3):
        t = i / 3.0
        px = hinge[0] + (tip[0] - hinge[0]) * t
        py = hinge[1] + (tip[1] - hinge[1]) * t
        d.line([(px, py - 18), (px, py - 8)], fill=WOOD_MID, width=2)
    bb = im.split()[-1].getbbox()
    if not bb:
        return im
    cropped = im.crop(bb)
    out = _blank(48, 52)
    ox = int(10 - (hinge[0] - bb[0]))
    oy = int(40 - (hinge[1] - bb[1]))
    out.paste(cropped, (ox, oy), cropped)
    return out


def main() -> None:
    ## Corners — two posts (existing style).
    _segment(2, -1, 40, "seg_diag_a", posts="both")
    _segment(2, 1, 40, "seg_diag_b", posts="both")
    ## Edge runs — post on start side only (chains without double posts).
    _segment(2, -1, 40, "run_a", posts="start")
    _segment(2, 1, 40, "run_b", posts="start")
    ## Rails only — bridges corner end-post → next run start-post.
    _segment(2, -1, 40, "rail_a", posts="none")
    _segment(2, 1, 40, "rail_b", posts="none")
    _segment(1, 0, 40, "seg_h", posts="both")  # kept for fallbacks

    post = _blank(20, 40)
    _draw_post(ImageDraw.Draw(post), 10, 36, h=30, r=4.2)
    bb = post.split()[-1].getbbox()
    if bb:
        post = post.crop(bb)
    post.save(FENCE / "post.png")
    print(f"wrote fence/post.png {post.size}")

    GATE.mkdir(parents=True, exist_ok=True)
    for i, t in enumerate([0.0, 0.25, 0.5, 0.75, 1.0]):
        im = _gate_leaf(t)
        im.save(GATE / f"open_{i}.png")
        print(f"wrote gate/open_{i}.png")

    ## Preview strip
    sheet = _blank(280, 90)
    x = 4
    for name in ["seg_diag_a", "run_a", "rail_a", "seg_diag_b", "run_b", "rail_b", "post"]:
        fr = Image.open(FENCE / f"{name}.png")
        sheet.paste(fr, (x, 45 - fr.height // 2), fr)
        x += fr.width + 8
    sheet.save(FENCE / "sheet_preview.png")
    print("done")


if __name__ == "__main__":
    main()
