#!/usr/bin/env python3
"""Bake chunky pixel AR marker icons for Mission Flight.

Relative disc sizes follow ScrollView draw_radius (Earth = 54 px baseline).
Markers are intentionally pixelated so they read as HUD pins, not nearby planets.

  python3 tools/gen_marker_icons.py
  → game/images/markers/<id>.png  (64×64 RGBA)
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "images" / "markers"
CANVAS = 64
EARTH_DRAW = 54.0

# id → (draw_radius, RGB, ring?)
BODIES: list[tuple[str, float, tuple[int, int, int], bool]] = [
    ("sun", 150.0, (255, 220, 60), False),
    ("mercury", 34.0, (168, 160, 152), False),
    ("venus", 52.0, (230, 184, 102), False),
    ("earth", 54.0, (70, 140, 220), False),
    ("mars", 40.0, (204, 92, 56), False),
    ("asteroid_belt", 74.0, (158, 148, 132), False),
    ("jupiter", 112.0, (210, 168, 122), False),
    ("saturn", 94.0, (220, 198, 140), True),
    ("uranus", 72.0, (140, 210, 218), False),
    ("neptune", 68.0, (60, 100, 230), False),
    ("pluto", 26.0, (198, 178, 158), False),
    ("ceres", 16.0, (170, 165, 160), False),
    ("vesta", 14.0, (190, 175, 150), False),
    ("psyche", 12.0, (150, 145, 155), False),
]


def disc_px(draw_radius: float) -> int:
    """Pixel diameter of the planet disc inside the 64px canvas."""
    # Sun nearly fills; Earth ~22px; Mercury ~14px — chunky and distinct.
    t = draw_radius / EARTH_DRAW
    d = int(round(22.0 * t))
    return max(8, min(d, 52))


def quantize(c: tuple[int, int, int], steps: int = 6) -> tuple[int, int, int]:
    def q(v: int) -> int:
        return int(round(v / 255.0 * (steps - 1))) * (255 // (steps - 1))

    return q(c[0]), q(c[1]), q(c[2])


def draw_ar_brackets(draw: ImageDraw.ImageDraw, pad: int = 3) -> None:
    """Corner brackets — classic AR reticle, 2px thick chunky lines."""
    c = (180, 255, 220, 220)
    L = 10
    t = 2
    x0, y0 = pad, pad
    x1, y1 = CANVAS - 1 - pad, CANVAS - 1 - pad
    # TL
    draw.rectangle([x0, y0, x0 + L, y0 + t - 1], fill=c)
    draw.rectangle([x0, y0, x0 + t - 1, y0 + L], fill=c)
    # TR
    draw.rectangle([x1 - L, y0, x1, y0 + t - 1], fill=c)
    draw.rectangle([x1 - t + 1, y0, x1, y0 + L], fill=c)
    # BL
    draw.rectangle([x0, y1 - t + 1, x0 + L, y1], fill=c)
    draw.rectangle([x0, y1 - L, x0 + t - 1, y1], fill=c)
    # BR
    draw.rectangle([x1 - L, y1 - t + 1, x1, y1], fill=c)
    draw.rectangle([x1 - t + 1, y1 - L, x1, y1], fill=c)


def paint_disc(
    img: Image.Image,
    rgb: tuple[int, int, int],
    diameter: int,
    ring: bool,
    body_id: str,
) -> None:
    """Nearest-neighbour chunky disc with a 1px outline; optional ring."""
    px = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    # Work in a small grid then scale up with NEAREST for true pixels.
    grid = max(8, diameter // 2)
    if grid % 2 == 0:
        grid += 1
    small = Image.new("RGBA", (grid, grid), (0, 0, 0, 0))
    sd = ImageDraw.Draw(small)
    col = quantize(rgb)
    # Flat fill — no limb darkening (markers are pins).
    inset = 1
    sd.ellipse([inset, inset, grid - 1 - inset, grid - 1 - inset], fill=col + (255,))
    # Pixel features so bodies differ at a glance.
    if body_id == "earth":
        sd.point((grid // 2 - 1, grid // 2), fill=(40, 120, 70, 255))
        sd.point((grid // 2 + 1, grid // 2 - 1), fill=(40, 120, 70, 255))
    elif body_id == "jupiter":
        for y in range(2, grid - 2, 2):
            sd.line([(2, y), (grid - 3, y)], fill=quantize((180, 120, 80)) + (255,))
    elif body_id == "mars":
        sd.point((grid // 2, grid // 2 - 1), fill=(120, 40, 30, 255))
    elif body_id == "sun":
        sd.ellipse([grid // 3, grid // 3, 2 * grid // 3, 2 * grid // 3], fill=(255, 255, 180, 255))
    elif body_id == "asteroid_belt":
        for p in [(2, 3), (4, 2), (5, 5), (3, 6), (6, 4)]:
            if p[0] < grid and p[1] < grid:
                sd.point(p, fill=(120, 110, 100, 255))
    # Upscale chunky.
    big = small.resize((diameter, diameter), Image.Resampling.NEAREST)
    ox = (CANVAS - diameter) // 2
    oy = (CANVAS - diameter) // 2
    if ring:
        rd = ImageDraw.Draw(px)
        cx, cy = CANVAS // 2, CANVAS // 2
        rx, ry = diameter // 2 + 6, max(3, diameter // 6)
        # Back ring
        rd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=(220, 200, 140, 230), width=2)
        px.alpha_composite(big, (ox, oy))
        # Front arc (bottom)
        rd.arc([cx - rx, cy - ry, cx + rx, cy + ry], 10, 170, fill=(220, 200, 140, 255), width=2)
    else:
        px.alpha_composite(big, (ox, oy))
        # Dark 1px outline on upscaled edge via mask
        outline = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        od = ImageDraw.Draw(outline)
        od.ellipse([ox, oy, ox + diameter - 1, oy + diameter - 1], outline=(20, 20, 30, 200), width=1)
        px.alpha_composite(outline)
    img.alpha_composite(px)


def bake_one(body_id: str, draw_r: float, rgb: tuple[int, int, int], ring: bool) -> Path:
    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw_ar_brackets(ImageDraw.Draw(img))
    paint_disc(img, rgb, disc_px(draw_r), ring, body_id)
    # Dim center crosshair (AR)
    d = ImageDraw.Draw(img)
    c = CANVAS // 2
    d.point((c, c), fill=(200, 255, 230, 160))
    path = OUT / f"{body_id}.png"
    img.save(path)
    return path


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for body_id, draw_r, rgb, ring in BODIES:
        p = bake_one(body_id, draw_r, rgb, ring)
        print(f"  {body_id:14s} disc={disc_px(draw_r):2d}px  tier≈{draw_r / EARTH_DRAW:.2f}  → {p.name}")
    print(f"Done. {len(BODIES)} markers → {OUT}")


if __name__ == "__main__":
    main()
