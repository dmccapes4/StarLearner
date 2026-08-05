#!/usr/bin/env python3
"""Bake four-plant bed packs for Garden Explorer.

Each pack is one PNG whose center = the bed furrow cross. Four Mana Seed plant
frames are stamped so each plant's *landing* (feet / soil contact) sits on an
iso plot-center offset — same math as FarmMap.plot_offsets_from_cross.

  python3 tools/gen_bed_plant_packs.py

Outputs: game/assets/plants/bed_packs/<plant_id>_<stage>.png
Also writes offsets.json (plot offsets + per-stage star hover).
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CROPS = ROOT / "game/assets/tiles/mana_seed_crops/crops"
SEEDS = ROOT / "game/data/seeds.json"
OUT = ROOT / "game/assets/plants/bed_packs"
PREVIEW = ROOT / ".cache/tree_preview/bed_pack_preview.png"

TILE_W, TILE_H = 64.0, 32.0
HALF = (1.05, 0.8)  # matches map.json beds
PLOT_SOIL_SCALE = 0.82
CELL_W, CELL_H = 16, 32
SPRITE_SCALE = 2  # fit inside one plot at play zoom
STAGES = {
    "sprout": 3,
    "growing": 5,
    "grown": 7,
}
# Alpha threshold for opaque "landed" pixels.
ALPHA_MIN = 32
# Near-black outline/shadow under Mana Seed plants — exclude from foot detect.
SHADOW_MAX = 90
# How far from furrow cross toward each soil corner (0.5 = geometric centroid).
# Slightly under 0.5 keeps feet in the visual middle of each plot (not on the lip).
CORNER_T = 0.42
# Optional per-stage nudge of the landing point within the cell (px in scaled space).
# Positive dy moves the stamp south (feet appear higher on the sprite).
STAGE_LANDING_NUDGE = {
    "sprout": (0.0, 1.0),
    "growing": (0.0, 0.0),
    "grown": (0.0, 0.0),
}


def tile_to_world(tx: float, ty: float) -> tuple[float, float]:
    return ((tx - ty) * (TILE_W * 0.5), (tx + ty) * (TILE_H * 0.5))


def diamond_world(tile: tuple[float, float], half: tuple[float, float]) -> list[tuple[float, float]]:
    cx, cy = tile
    hx, hy = half
    c = tile_to_world(cx, cy)
    e = tile_to_world(cx + hx, cy)
    s = tile_to_world(cx, cy + hy)
    ex, ey = e[0] - c[0], e[1] - c[1]
    sx, sy = s[0] - c[0], s[1] - c[1]
    return [
        (c[0] - ex - sx, c[1] - ey - sy),  # N
        (c[0] + ex - sx, c[1] + ey - sy),  # E
        (c[0] + ex + sx, c[1] + ey + sy),  # S
        (c[0] - ex + sx, c[1] - ey + sy),  # W
    ]


def plot_offsets() -> list[tuple[float, float]]:
    """Midpoint from furrow cross to each soil-diamond corner (N,E,S,W).

    Matches FarmMap._plot_centers_raised — the four furrow regions, not tile NW/NE.
    """
    soil = (HALF[0] * PLOT_SOIL_SCALE, HALF[1] * PLOT_SOIL_SCALE)
    corners = diamond_world((0.0, 0.0), soil)
    # Center is origin in local space.
    return [(p[0] * CORNER_T, p[1] * CORNER_T) for p in corners]


def load_plant_ids() -> list[tuple[str, str]]:
    data = json.loads(SEEDS.read_text())
    out = []
    for p in data.get("plants", []):
        pid = str(p.get("id", ""))
        sheet = str(p.get("sheet", pid))
        if pid:
            out.append((pid, sheet))
    return out


def _is_plant_pixel(p: tuple[int, int, int, int]) -> bool:
    r, g, b, a = p
    if a <= ALPHA_MIN:
        return False
    # Skip near-black outline / ground shadow under the root.
    if r < SHADOW_MAX and g < SHADOW_MAX and b < SHADOW_MAX:
        return False
    return True


def landing_xy(scaled: Image.Image) -> tuple[float, float] | None:
    """Bottom-center of plant art (not shadow) = where the plant meets the soil."""
    px = scaled.load()
    w, h = scaled.size
    bottom = None
    for y in range(h - 1, -1, -1):
        for x in range(w):
            if _is_plant_pixel(px[x, y]):
                bottom = y
                break
        if bottom is not None:
            break
    if bottom is None:
        return None
    xs: list[float] = []
    ys: list[float] = []
    for y in range(max(0, bottom - 1), bottom + 1):
        for x in range(w):
            if _is_plant_pixel(px[x, y]):
                xs.append(float(x))
                ys.append(float(y))
    if not xs:
        return None
    return (sum(xs) / len(xs), sum(ys) / len(ys))


def paste_plant(
    canvas: Image.Image,
    cell: Image.Image,
    cx: float,
    cy: float,
    nudge: tuple[float, float] = (0.0, 0.0),
) -> None:
    """Stamp scaled plant so its landing (feet) lands on (cx, cy)."""
    scaled = cell.resize((CELL_W * SPRITE_SCALE, CELL_H * SPRITE_SCALE), Image.NEAREST)
    land = landing_xy(scaled)
    if land is None:
        return
    lx, ly = land
    lx += nudge[0]
    ly += nudge[1]
    x = int(round(cx - lx))
    y = int(round(cy - ly))
    # Pillow paste origin must be in-bounds; allow overhang via alpha_composite on padded blit.
    if x >= 0 and y >= 0 and x + scaled.width <= canvas.width and y + scaled.height <= canvas.height:
        canvas.alpha_composite(scaled, (x, y))
        return
    # Safe path when stamp clips the canvas edge.
    tmp = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    tmp.paste(scaled, (x, y), scaled)
    canvas.alpha_composite(tmp)


def make_pack(
    sheet_path: Path,
    col: int,
    offsets: list[tuple[float, float]],
    nudge: tuple[float, float],
) -> Image.Image:
    src = Image.open(sheet_path).convert("RGBA")
    cell = src.crop((col * CELL_W, 0, col * CELL_W + CELL_W, CELL_H))
    pad = max(abs(o[0]) for o in offsets) + max(abs(o[1]) for o in offsets) + CELL_H * SPRITE_SCALE + 16
    side = int(math.ceil(pad * 2 / 2) * 2)  # even
    side = max(side, 96)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    cx = cy = side * 0.5
    for ox, oy in offsets:
        paste_plant(canvas, cell, cx + ox, cy + oy, nudge)
    return canvas


def star_hover_y(pack: Image.Image) -> float:
    """Y offset from pack center (furrow cross) to sit just above foliage."""
    a = pack.split()[-1]
    bb = a.getbbox()
    if bb is None:
        return -40.0
    cy = pack.height * 0.5
    # bb[1] = top opaque row; place star a few px above that.
    return float(bb[1] - cy - 10)


def main() -> None:
    offsets = plot_offsets()
    OUT.mkdir(parents=True, exist_ok=True)
    star_by_stage: dict[str, list[float]] = {s: [] for s in STAGES}
    meta = {
        "half_tiles": list(HALF),
        "plot_soil_scale": PLOT_SOIL_SCALE,
        "sprite_scale": SPRITE_SCALE,
        "anchor": "landing_feet",
        "plot_layout": "diamond_corner_n_e_s_w",
        "corner_t": CORNER_T,
        "stage_landing_nudge": {k: {"x": v[0], "y": v[1]} for k, v in STAGE_LANDING_NUDGE.items()},
        "offsets_n_e_s_w": [{"x": o[0], "y": o[1]} for o in offsets],
        "note": (
            "Pack image center = bed furrow cross. Each plant's feet sit along the "
            "cross→corner ray (N,E,S,W furrow regions) at corner_t. "
            "Draw Sprite2D.centered at bed_plot_cross."
        ),
    }

    preview_row = []
    count = 0
    for pid, sheet in load_plant_ids():
        path = CROPS / f"{sheet}.png"
        if not path.exists():
            print("missing sheet", sheet, "for", pid)
            continue
        for stage, col in STAGES.items():
            nudge = STAGE_LANDING_NUDGE.get(stage, (0.0, 0.0))
            pack = make_pack(path, col, offsets, nudge)
            out_path = OUT / f"{pid}_{stage}.png"
            pack.save(out_path)
            star_by_stage[stage].append(star_hover_y(pack))
            count += 1
            if stage == "grown" and len(preview_row) < 8:
                preview_row.append(pack)

    meta["star_hover_y"] = {
        stage: round(sum(vals) / len(vals), 1) if vals else -40.0
        for stage, vals in star_by_stage.items()
    }
    (OUT / "offsets.json").write_text(json.dumps(meta, indent=2) + "\n")
    print("offsets", offsets)
    print("star_hover_y", meta["star_hover_y"])

    if preview_row:
        PREVIEW.parent.mkdir(parents=True, exist_ok=True)
        h = max(p.height for p in preview_row)
        w = sum(p.width for p in preview_row) + 4 * len(preview_row)
        prev = Image.new("RGBA", (w, h), (40, 40, 45, 255))
        x = 2
        for p in preview_row:
            prev.paste(p, (x, (h - p.height) // 2), p)
            x += p.width + 4
        prev.save(PREVIEW)
        print("preview", PREVIEW)
    print(f"wrote {count} packs → {OUT}")


if __name__ == "__main__":
    main()
