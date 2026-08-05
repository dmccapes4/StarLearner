#!/usr/bin/env python3
"""Generate rain splash + spinning/landing leaf sprites for Garden Explorer.

Outputs under game/assets/trees/:
  raindrop.png          — single slanted drop (8×14)
  rain_splash.png       — 4 frames × 16×12 splash ring
  leaf_spin.png         — 4 colors × 8 spin frames, 12×12 cells
  leaf_land.png         — 4 colors × 3 land poses, 12×12 cells

  python3 tools/gen_weather_fx.py
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "game/assets/trees"
PREVIEW = ROOT / ".cache/tree_preview/weather_fx_x4.png"

LEAF_COLORS = [
    (210, 95, 40),   # orange
    (180, 55, 30),   # russet
    (220, 150, 50),  # gold
    (140, 70, 35),   # brown
]


def _put(arr: np.ndarray, x: int, y: int, rgb: tuple[int, int, int], a: int = 255) -> None:
    h, w = arr.shape[:2]
    if 0 <= x < w and 0 <= y < h:
        arr[y, x] = [rgb[0], rgb[1], rgb[2], a]


def make_raindrop() -> Image.Image:
    arr = np.zeros((14, 8, 4), dtype=np.uint8)
    # slanted bright streak
    for i in range(11):
        x = 2 + i // 4
        y = 1 + i
        _put(arr, x, y, (200, 220, 255), 230)
        _put(arr, x + 1, y, (170, 200, 245), 180)
    _put(arr, 4, 12, (220, 235, 255), 200)
    return Image.fromarray(arr, "RGBA")


def make_splash_atlas() -> Image.Image:
    fw, fh, n = 16, 12, 4
    atlas = Image.new("RGBA", (fw * n, fh), (0, 0, 0, 0))
    for fi in range(n):
        arr = np.zeros((fh, fw, 4), dtype=np.uint8)
        cx, cy = 8, 7
        # expanding ring + droplets
        r = 1.5 + fi * 1.6
        for ang_i in range(16):
            a = ang_i * math.tau / 16
            x = int(cx + math.cos(a) * r)
            y = int(cy + math.sin(a) * r * 0.55)
            alpha = max(40, 220 - fi * 45)
            _put(arr, x, y, (210, 225, 255), alpha)
            if fi >= 1 and ang_i % 2 == 0:
                _put(arr, x + int(math.cos(a)), y - 1, (190, 215, 250), alpha // 2)
        if fi == 0:
            _put(arr, cx, cy, (230, 240, 255), 240)
            _put(arr, cx - 1, cy, (200, 220, 255), 180)
            _put(arr, cx + 1, cy, (200, 220, 255), 180)
        atlas.paste(Image.fromarray(arr, "RGBA"), (fi * fw, 0))
    return atlas


def _draw_leaf(arr: np.ndarray, cx: float, cy: float, angle: float, rgb: tuple[int, int, int], scale: float = 1.0) -> None:
    # diamond leaf with stem tip
    pts = [
        (0.0, -4.2 * scale),
        (2.6 * scale, 0.0),
        (0.0, 3.6 * scale),
        (-2.6 * scale, 0.0),
    ]
    ca, sa = math.cos(angle), math.sin(angle)
    rot = []
    for x, y in pts:
        rot.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
    # fill bounding box with point-in-diamond test via barycentric-ish
    xs = [p[0] for p in rot]
    ys = [p[1] for p in rot]
    for y in range(int(min(ys)) - 1, int(max(ys)) + 2):
        for x in range(int(min(xs)) - 1, int(max(xs)) + 2):
            # approximate: distance to center along leaf long axis
            lx = (x - cx) * ca + (y - cy) * sa
            ly = -(x - cx) * sa + (y - cy) * ca
            # diamond: |lx|/w + |ly|/h <= 1
            if abs(lx) / max(0.1, 4.2 * scale) + abs(ly) / max(0.1, 2.6 * scale) <= 1.05:
                shade = 0.75 + 0.25 * (1.0 - (abs(lx) + abs(ly)) * 0.12)
                col = tuple(min(255, int(c * shade)) for c in rgb)
                _put(arr, x, y, col)  # type: ignore[arg-type]
    # midrib
    for t in range(-3, 4):
        x = int(cx + math.cos(angle) * t * scale)
        y = int(cy + math.sin(angle) * t * scale)
        dark = tuple(max(0, c - 35) for c in rgb)
        _put(arr, x, y, dark)  # type: ignore[arg-type]


def make_leaf_spin_atlas() -> Image.Image:
    cell, frames, colors = 12, 8, len(LEAF_COLORS)
    atlas = Image.new("RGBA", (cell * frames, cell * colors), (0, 0, 0, 0))
    for ci, rgb in enumerate(LEAF_COLORS):
        for fi in range(frames):
            arr = np.zeros((cell, cell, 4), dtype=np.uint8)
            ang = fi * (math.tau / frames)
            # foreshorten on edge-on frames for spin feel
            foreshorten = 0.55 + 0.45 * abs(math.cos(ang))
            _draw_leaf(arr, 5.5, 5.5, ang, rgb, scale=foreshorten)
            atlas.paste(Image.fromarray(arr, "RGBA"), (fi * cell, ci * cell))
    return atlas


def make_leaf_land_atlas() -> Image.Image:
    cell, poses, colors = 12, 3, len(LEAF_COLORS)
    atlas = Image.new("RGBA", (cell * poses, cell * colors), (0, 0, 0, 0))
    pose_angs = [0.35, -0.55, 1.15]
    pose_scales = [1.0, 0.85, 1.05]
    for ci, rgb in enumerate(LEAF_COLORS):
        for pi in range(poses):
            arr = np.zeros((cell, cell, 4), dtype=np.uint8)
            _draw_leaf(arr, 5.5, 6.2, pose_angs[pi], rgb, scale=pose_scales[pi])
            # soft ground shadow
            for dx in range(-3, 4):
                _put(arr, 5 + dx, 10, (40, 30, 20), 50)
            atlas.paste(Image.fromarray(arr, "RGBA"), (pi * cell, ci * cell))
    return atlas


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    drop = make_raindrop()
    splash = make_splash_atlas()
    spin = make_leaf_spin_atlas()
    land = make_leaf_land_atlas()
    drop.save(OUT_DIR / "raindrop.png")
    splash.save(OUT_DIR / "rain_splash.png")
    spin.save(OUT_DIR / "leaf_spin.png")
    land.save(OUT_DIR / "leaf_land.png")
    # keep leaf_particle as first spin frame tinted for fallbacks
    spin.crop((0, 0, 12, 12)).save(OUT_DIR / "leaf_particle.png")

    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    # compose preview strip
    pw = splash.width + spin.width + 8
    ph = max(splash.height, spin.height) + land.height + 16
    prev = Image.new("RGBA", (pw, ph), (30, 30, 35, 255))
    prev.paste(drop.resize((drop.width * 4, drop.height * 4), Image.NEAREST), (4, 4))
    prev.paste(splash.resize((splash.width * 4, splash.height * 4), Image.NEAREST), (40, 4))
    prev.paste(spin.resize((spin.width * 2, spin.height * 2), Image.NEAREST), (4, 60))
    prev.paste(land.resize((land.width * 2, land.height * 2), Image.NEAREST), (4, 60 + spin.height * 2 + 8))
    prev.save(PREVIEW)
    print(f"wrote weather fx → {OUT_DIR}")
    print(f"preview {PREVIEW}")


if __name__ == "__main__":
    main()
