#!/usr/bin/env python3
"""Compose the garden shed sprite from the owned Sprout Lands premium house
tilesets: plank walls + wide shingle roof + a centered arched door (drawn in
the same palette). Output: game/assets/buildings/shed_v2.png (1x pixel art;
the game scales with NEAREST filtering)."""
from PIL import Image, ImageDraw
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PARTS = os.path.join(
    ROOT, "game/assets/tiles/sprout_lands/Tilesets/Building parts")
OUT = os.path.join(ROOT, "game/assets/buildings/shed_v2.png")

walls = Image.open(os.path.join(PARTS, "Wooden_House_Walls_Tilset.png")).convert("RGBA")
roof = Image.open(os.path.join(PARTS, "Wooden_House_Roof_Tilset.png")).convert("RGBA")

# Sprout Lands palette (sampled from the tilesets).
OUTLINE = (110, 74, 86, 255)      # dark plum outline
WOOD_DARK = (154, 99, 72, 255)
WOOD_MID = (198, 137, 92, 255)
WOOD_LIGHT = (222, 168, 118, 255)

CREAM = (238, 213, 164, 255)      # window glow / brick cream

# ---- source crops ------------------------------------------------------
# Wide roof slab: left edge / mid / right edge columns from the big slab.
slab = roof.crop((48, 30, 112, 80))          # 64x50
roof_l = slab.crop((0, 0, 16, 50))
roof_m = slab.crop((16, 0, 48, 50))          # 32 wide repeatable
roof_r = slab.crop((48, 0, 64, 50))

# ---- canvas ------------------------------------------------------------
W, H = 104, 88
im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(im)

# Wall band: solid palette planks (drawn, not sampled — the tileset pieces
# carry transparent margins that leak the background).
wall_top, wall_bot = 42, H - 2
d.rectangle([8, wall_top, 95, wall_bot], fill=WOOD_MID, outline=OUTLINE)
for yy in range(wall_top + 6, wall_bot - 1, 6):
    d.line([(9, yy), (94, yy)], fill=WOOD_DARK)
    d.line([(9, yy + 1), (94, yy + 1)], fill=WOOD_LIGHT)
# Corner posts.
d.rectangle([8, wall_top, 12, wall_bot], fill=WOOD_DARK, outline=OUTLINE)
d.rectangle([91, wall_top, 95, wall_bot], fill=WOOD_DARK, outline=OUTLINE)

# Two square shuttered windows.
for wx in (20, 68):
    d.rectangle([wx - 1, 52, wx + 16, 69], fill=OUTLINE)
    d.rectangle([wx + 1, 54, wx + 14, 67], fill=CREAM)
    d.line([(wx + 7, 54), (wx + 7, 67)], fill=OUTLINE)
    d.line([(wx + 1, 60), (wx + 14, 60)], fill=OUTLINE)

# Centered arched door (drawn in palette): 20 wide x 28 tall.
d = ImageDraw.Draw(im)
dx0, dy1 = W // 2 - 10, wall_bot
dy0 = dy1 - 28
d.rectangle([dx0 - 1, dy0 + 4, dx0 + 20, dy1], fill=OUTLINE)          # frame
d.ellipse([dx0 - 1, dy0 - 2, dx0 + 20, dy0 + 12], fill=OUTLINE)       # arch
d.rectangle([dx0 + 1, dy0 + 5, dx0 + 18, dy1 - 1], fill=WOOD_MID)
d.ellipse([dx0 + 1, dy0, dx0 + 18, dy0 + 12], fill=WOOD_MID)
for px in range(dx0 + 4, dx0 + 18, 5):                                 # planks
    d.line([(px, dy0 + 3), (px, dy1 - 1)], fill=WOOD_DARK)
d.ellipse([dx0 + 14, dy1 - 14, dx0 + 17, dy1 - 11], fill=WOOD_LIGHT)   # knob

# Roof: covers y 0..46, overhangs walls by ~4px each side.
rx = 0
im.alpha_composite(roof_l, (rx, 0)); rx += 16
while rx < W - 16:
    seg = roof_m.crop((0, 0, min(32, W - 16 - rx), 50))
    im.alpha_composite(seg, (rx, 0)); rx += seg.width
im.alpha_composite(roof_r, (W - 16, 0))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
im.save(OUT)
print("wrote", OUT, im.size)

# Preview against grass for inspection.
prev = Image.new("RGBA", (W, H), (96, 158, 90, 255))
prev.alpha_composite(im)
prev = prev.resize((W * 5, H * 5), Image.NEAREST)
prev.save("/tmp/shed_parts/shed_preview.png")
