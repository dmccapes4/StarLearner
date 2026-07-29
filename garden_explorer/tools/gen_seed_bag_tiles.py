#!/usr/bin/env python3
"""Shed seed-bag tiles live at game/assets/ui/seeds/<plant_id>.png.

These are curated HD tiles (kid-readable plant art on a consistent seed-packet
frame), not nearest-neighbor upscales of the 16×32 Mana Seed shop bags.

This script only verifies the set is complete and prints a status report.
To regenerate from Mana Seed sheets (debug / fallback only):

  GEN_SEED_BAGS_FROM_MANA=1 tools/gen_seed_bag_tiles.py
"""
from __future__ import annotations

import json
import os
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SEEDS_JSON = ROOT / "game/data/seeds.json"
CROPS = ROOT / "game/assets/tiles/mana_seed_crops/crops"
OUT_DIR = ROOT / "game/assets/ui/seeds"

CELL_W, CELL_H = 16, 32
BAG_COL = 1
TILE = 256
BAG_TARGET = 220


def opaque_bbox(im: Image.Image) -> tuple[int, int, int, int]:
    alpha = im.split()[-1]
    bb = alpha.getbbox()
    return bb if bb else (0, 0, im.width, im.height)


def extract_bag(sheet_path: Path) -> Image.Image:
    sheet = Image.open(sheet_path).convert("RGBA")
    cell = sheet.crop((BAG_COL * CELL_W, 0, (BAG_COL + 1) * CELL_W, CELL_H))
    x0, y0, x1, y1 = opaque_bbox(cell)
    x0, y0 = max(0, x0 - 1), max(0, y0 - 1)
    x1, y1 = min(cell.width, x1 + 1), min(cell.height, y1 + 1)
    return cell.crop((x0, y0, x1, y1))


def nearest_fit(im: Image.Image, long_edge: int) -> Image.Image:
    scale = max(1, int(round(long_edge / max(im.width, im.height))))
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def make_tile(bag: Image.Image) -> Image.Image:
    tile = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(tile)
    draw.rounded_rectangle(
        (2, 2, TILE - 3, TILE - 3),
        radius=28,
        fill=(32, 48, 30, 255),
        outline=(255, 209, 100, 255),
        width=5,
    )
    bag_big = nearest_fit(bag, BAG_TARGET)
    while max(bag_big.width, bag_big.height) < BAG_TARGET - 8:
        bag_big = bag_big.resize((bag_big.width * 2, bag_big.height * 2), Image.NEAREST)
        if bag_big.width > TILE - 16:
            break
    x = (TILE - bag_big.width) // 2
    y = (TILE - bag_big.height) // 2
    tile.alpha_composite(bag_big, (x, y))
    return tile


def verify_curated() -> None:
    data = json.loads(SEEDS_JSON.read_text())
    missing = []
    tiny = []
    for plant in data["plants"]:
        pid = plant["id"]
        path = OUT_DIR / f"{pid}.png"
        if not path.exists():
            missing.append(pid)
            continue
        im = Image.open(path)
        if min(im.size) < 128:
            tiny.append(f"{pid}={im.size}")
        print(f"  ok  {pid:16s} {im.size[0]}×{im.size[1]}")
    if missing:
        print("MISSING:", ", ".join(missing))
        raise SystemExit(1)
    if tiny:
        print("WARN small tiles:", ", ".join(tiny))
    print(f"verified {len(data['plants'])} curated tiles → {OUT_DIR}")


def regen_from_mana() -> None:
    data = json.loads(SEEDS_JSON.read_text())
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    ok = 0
    missing = []
    for plant in data["plants"]:
        pid = plant["id"]
        sheet = str(plant.get("sheet", pid))
        src = CROPS / f"{sheet}.png"
        if not src.exists():
            missing.append(f"{pid} ({sheet})")
            continue
        bag = extract_bag(src)
        tile = make_tile(bag)
        out = OUT_DIR / f"{pid}.png"
        tile.save(out, optimize=True)
        ok += 1
        print(f"  {pid:16s} ← {sheet:20s} bag={bag.size} → {out.name}")
    print(f"wrote {ok} Mana-upscale tiles → {OUT_DIR}")
    if missing:
        print("MISSING sheets:", ", ".join(missing))
        raise SystemExit(1)


def main() -> None:
    if os.environ.get("GEN_SEED_BAGS_FROM_MANA") == "1":
        print("WARNING: overwriting curated HD tiles with Mana Seed upscales")
        regen_from_mana()
    else:
        verify_curated()


if __name__ == "__main__":
    main()
