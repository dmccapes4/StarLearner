#!/usr/bin/env python3
"""Generate seasonal meadow trees for Garden Explorer.

Sprout Lands–inspired: wide horizontal canopies, side-reaching branches,
layered cloud puffs (see large tree in Trees, stumps and bushes.png).
Winter exposes the same horizontal scaffold with light snow tips.

Atlas layout (nearest-neighbor friendly):
  rows = spring, summer, fall, winter
  cols = narrow_a, narrow_b, med_a, med_b, large_a, large_b, bush_a, bush_b
  cell = 56×48   (_a / _b = subtle wind frames)

  python3 tools/gen_seasonal_trees.py
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game/assets/trees/seasonal_trees.png"
PREVIEW = ROOT / ".cache/tree_preview/seasonal_trees_x4.png"

# Wider than tall — matches Sprout Lands large tree proportions.
CELL_W, CELL_H = 56, 48
SEASONS = ["spring", "summer", "fall", "winter"]
VARIANTS = ["narrow", "med", "large", "bush"]
WIND_FRAMES = 2

PALETTES = {
    "summer": [(40, 88, 34), (68, 132, 50), (102, 168, 72), (142, 200, 104)],
    "fall": [(105, 40, 16), (172, 74, 26), (212, 124, 40), (232, 178, 68)],
    "spring_leaf": [(48, 104, 44), (80, 150, 68), (118, 188, 96), (160, 218, 134)],
    "bark": [(58, 36, 22), (92, 62, 38), (122, 86, 54)],
    "blossom": [(236, 150, 180), (255, 232, 242), (220, 100, 148), (255, 250, 252)],
    "snow": [(230, 236, 242), (210, 220, 230)],
}

# Canopy is intentionally wide (rx >> ry). Branch arms reach sideways.
SPECS = {
    "narrow": {
        "trunk_w": 2, "trunk_top": 26,
        "arms": [(-10, -2, 7), (10, -1, 7)],
        "puffs": [(-4, -10, 7, 5), (4, -9, 7, 5), (0, -14, 6, 5)],
    },
    "med": {
        "trunk_w": 3, "trunk_top": 24,
        "arms": [(-14, -2, 9), (14, -1, 9), (-6, -5, 6), (7, -5, 6)],
        "puffs": [(-8, -10, 9, 6), (8, -9, 9, 6), (0, -14, 8, 6), (-2, -6, 7, 5), (3, -6, 7, 5)],
    },
    "large": {
        "trunk_w": 4, "trunk_top": 22,
        "arms": [(-18, -1, 11), (18, 0, 11), (-10, -5, 8), (11, -4, 8), (-4, -8, 6), (5, -8, 6)],
        "puffs": [
            (-12, -9, 11, 7), (12, -8, 11, 7), (0, -13, 12, 7),
            (-6, -5, 9, 6), (7, -4, 9, 6), (-14, -4, 7, 5), (15, -3, 7, 5),
            (0, -17, 8, 5),
        ],
    },
    "bush": {
        "trunk_w": 0, "trunk_top": 34,
        "arms": [(-8, 0, 5), (8, 0, 5)],
        "puffs": [(-6, -2, 8, 5), (6, -1, 8, 5), (0, -5, 7, 5), (0, 1, 8, 4)],
    },
}


def _hash(x: int, y: int, salt: int = 0) -> float:
    n = (x * 374761393 + y * 668265263 + salt * 1274126177) & 0x7FFFFFFF
    return (n % 10000) / 10000.0


def _put(arr: np.ndarray, x: int, y: int, rgb: tuple[int, int, int], a: int = 255) -> None:
    h, w = arr.shape[:2]
    if 0 <= x < w and 0 <= y < h:
        arr[y, x] = [rgb[0], rgb[1], rgb[2], a]


def _blend_put(arr: np.ndarray, x: int, y: int, rgb: tuple[int, int, int], a: int = 255) -> None:
    h, w = arr.shape[:2]
    if not (0 <= x < w and 0 <= y < h):
        return
    if a >= 250 or arr[y, x, 3] < 10:
        arr[y, x] = [rgb[0], rgb[1], rgb[2], a]
        return
    oa = arr[y, x, 3] / 255.0
    na = a / 255.0
    out_a = na + oa * (1 - na)
    if out_a <= 0:
        return
    for i in range(3):
        arr[y, x, i] = int((rgb[i] * na + arr[y, x, i] * oa * (1 - na)) / out_a)
    arr[y, x, 3] = int(out_a * 255)


def _pick_shade(palette: list[tuple[int, int, int]], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    idx = t * (len(palette) - 1)
    i0 = int(idx)
    i1 = min(i0 + 1, len(palette) - 1)
    f = idx - i0
    c0, c1 = palette[i0], palette[i1]
    return tuple(int(c0[i] * (1 - f) + c1[i] * f) for i in range(3))  # type: ignore[return-value]


def draw_trunk(arr: np.ndarray, cx: int, top: int, bottom: int, width: int) -> None:
    bark = PALETTES["bark"]
    if width <= 0:
        return
    for y in range(top, bottom):
        t = (y - top) / max(1, bottom - top)
        w = max(1, int(width * (0.75 + 0.4 * t)))
        for dx in range(-w, w + 1):
            shade = 0.35 + 0.45 * (dx + w) / max(1, 2 * w) + 0.12 * t
            _put(arr, cx + dx, y, _pick_shade(bark, shade))
    for dx in range(-(width + 1), width + 2):
        _put(arr, cx + dx, bottom - 1, bark[0 if abs(dx) > width else 1])
        if abs(dx) <= width:
            _put(arr, cx + dx, bottom - 2, bark[1])


def draw_horizontal_arm(
    arr: np.ndarray,
    cx: int,
    cy: int,
    dx: int,
    dy: int,
    length: int,
    wind: int,
    snow: bool,
) -> None:
    """Side branch: mostly horizontal with slight droop — Sprout Lands silhouette."""
    bark = PALETTES["bark"]
    # wind nudges tip
    tip_x = cx + dx + (1 if wind and dx > 0 else (-1 if wind and dx < 0 else 0))
    tip_y = cy + dy + abs(dx) // 10
    steps = max(3, length)
    for i in range(steps + 1):
        t = i / steps
        # ease outward, slight sag
        x = int(cx + (tip_x - cx) * t)
        y = int(cy + (tip_y - cy) * t + 1.2 * t * t)
        w = max(1, int(round(2.2 * (1.0 - 0.55 * t))))
        for ox in range(-w, w + 1):
            for oy in range(-(w // 2), w // 2 + 1):
                shade = 0.3 + 0.4 * (ox + w) / max(1, 2 * w)
                _put(arr, x + ox, y + oy, _pick_shade(bark, shade))
        # fine twigs near tip
        if t > 0.55 and i % 2 == 0:
            tw = 1 if dx >= 0 else -1
            _put(arr, x + tw, y - 1, bark[1])
            _put(arr, x + tw * 2, y - 1, bark[0])
            if snow:
                _put(arr, x + tw * 2, y - 2, PALETTES["snow"][0], 220)
    if snow:
        _put(arr, tip_x, tip_y - 1, PALETTES["snow"][0], 230)
        _put(arr, tip_x + (1 if dx >= 0 else -1), tip_y, PALETTES["snow"][1], 200)


def draw_puff(
    arr: np.ndarray,
    cx: int,
    cy: int,
    rx: int,
    ry: int,
    palette: list[tuple[int, int, int]],
    wind: int,
    salt: int,
) -> None:
    """Soft horizontal cloud lobe (wider than tall)."""
    wind_pull = wind * 1.1
    for y in range(cy - ry - 1, cy + ry + 2):
        for x in range(cx - rx - 2, cx + rx + 3):
            xw = x - int((cy - y) * 0.03 * wind_pull)
            dx = (xw - (cx + wind_pull * 0.35)) / max(1.0, rx)
            dy = (y - cy) / max(1.0, ry)
            d = dx * dx + dy * dy
            if d > 1.05:
                continue
            edge_n = _hash(xw, y, salt + 3)
            if d > 0.78 and edge_n > 0.58:
                continue
            if d > 0.90 and edge_n > 0.28:
                continue
            nx = (xw - cx) / max(1, rx)
            ny = (y - cy) / max(1, ry)
            light = 0.52 + (-nx * 0.26) + (-ny * 0.40)
            clump = _hash(xw // 3, y // 3, salt) * 0.26 - 0.10
            shade = max(0.0, min(1.0, light + clump))
            shade = round(shade * 3.0) / 3.0
            col = _pick_shade(palette, shade)
            if ny > 0.35 and shade < 0.45:
                col = _pick_shade(palette, max(0.0, shade - 0.22))
            _put(arr, xw, y, col)


def draw_blossoms_on_puffs(
    arr: np.ndarray,
    puffs: list[tuple[int, int, int, int]],
    salt: int,
) -> None:
    blooms = PALETTES["blossom"]
    for pi, (cx, cy, rx, ry) in enumerate(puffs):
        count = 3 + (salt + pi) % 4
        for i in range(count):
            a = _hash(i, salt + pi, 1) * math.tau
            r = 0.25 + _hash(i, salt, 2) * 0.65
            bx = int(cx + math.cos(a) * rx * r)
            by = int(cy - ry * 0.15 + math.sin(a) * ry * r * 0.7)
            if not (0 <= by < arr.shape[0] and 0 <= bx < arr.shape[1] and arr[by, bx, 3] > 20):
                continue
            _put(arr, bx, by, blooms[1])
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                _blend_put(arr, bx + dx, by + dy, blooms[0 if (dx + i) % 2 == 0 else 2], 240)


def draw_winter_twigs(arr: np.ndarray, cx: int, cy: int, arms: list, wind: int) -> None:
    """Extra fine horizontal twigs so winter reads as a scaffold, not an X."""
    for dx, dy, length in arms:
        draw_horizontal_arm(arr, cx, cy, dx, dy, length, wind, True)
        # secondary shorter arm above
        draw_horizontal_arm(arr, cx, cy - 3, int(dx * 0.7), dy - 2, max(4, length - 3), wind, True)


def draw_tree(variant: str, season: str, wind: int, salt: int) -> Image.Image:
    spec = SPECS[variant]
    arr = np.zeros((CELL_H, CELL_W, 4), dtype=np.uint8)
    cx = CELL_W // 2
    trunk_bottom = CELL_H - 2
    trunk_top = int(spec["trunk_top"])
    branch_y = trunk_top + 1

    if variant != "bush":
        draw_trunk(arr, cx, trunk_top, trunk_bottom, int(spec["trunk_w"]))

    arms = list(spec["arms"])
    # wind: lean tips
    if season == "winter":
        draw_winter_twigs(arr, cx, branch_y, arms, wind)
        return Image.fromarray(arr, "RGBA")

    # Leafy: draw horizontal arms first (peek under canopy edges), then puffs.
    for dx, dy, length in arms:
        draw_horizontal_arm(arr, cx, branch_y, dx, dy, max(5, length - 2), wind, False)

    if season == "fall":
        palette = PALETTES["fall"]
    elif season == "spring":
        palette = PALETTES["spring_leaf"]
    else:
        palette = PALETTES["summer"]

    placed: list[tuple[int, int, int, int]] = []
    for i, (ox, oy, rx, ry) in enumerate(spec["puffs"]):
        pcx = cx + ox + wind
        pcy = branch_y + oy
        draw_puff(arr, pcx, pcy, rx, ry, palette, wind, salt + i * 13)
        placed.append((pcx, pcy, rx, ry))

    if season == "spring":
        draw_blossoms_on_puffs(arr, placed, salt + 11)

    return Image.fromarray(arr, "RGBA")


def main() -> None:
    atlas = Image.new("RGBA", (CELL_W * len(VARIANTS) * WIND_FRAMES, CELL_H * len(SEASONS)), (0, 0, 0, 0))
    for si, season in enumerate(SEASONS):
        for vi, variant in enumerate(VARIANTS):
            for wi in range(WIND_FRAMES):
                salt = vi * 17 + si * 3 + 5
                frame = draw_tree(variant, season, wind=wi, salt=salt)
                col = vi * WIND_FRAMES + wi
                atlas.paste(frame, (col * CELL_W, si * CELL_H), frame)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    atlas.resize((atlas.size[0] * 4, atlas.size[1] * 4), Image.NEAREST).save(PREVIEW)
    print(f"wrote {OUT} {atlas.size}")
    print(f"preview {PREVIEW}")
    print(f"seasons={SEASONS} variants={VARIANTS} wind_frames={WIND_FRAMES} cell={CELL_W}x{CELL_H}")


if __name__ == "__main__":
    main()
