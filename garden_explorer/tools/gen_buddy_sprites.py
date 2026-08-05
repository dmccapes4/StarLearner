#!/usr/bin/env python3
"""Build Buddy walk sheet from the authored new dog_idle.png.

Keeps the new puppy art; fixes the collar; adds front/back facings and a
mild 4-frame walk (legs + tail). Left facing is a mirror of right.

  python3 tools/gen_buddy_sprites.py

Writes:
  game/assets/animals/dog_idle.png
  game/assets/animals/dog_walk.png   (4×4 × 48px)
  game/assets/portraits/animal_dog.png
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "game/assets"
CELL = 48

COLLAR = (214, 46, 46, 255)
COLLAR_D = (168, 28, 28, 255)
COLLAR_H = (238, 78, 78, 255)
TAG = (236, 198, 64, 255)
TAG_D = (168, 120, 28, 255)
FUR_FALLBACK = (196, 148, 88, 255)


def is_red(p) -> bool:
    r, g, b, a = p
    return a > 180 and r > 150 and g < 100 and b < 100 and r > g + 60


def is_tag(p) -> bool:
    return p[:3] in (TAG[:3], TAG_D[:3])


def clear_red(im: Image.Image) -> Image.Image:
    out = im.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            if is_red(px[x, y]) or is_tag(px[x, y]):
                # sample nearby non-red
                fill = FUR_FALLBACK
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        q = px[nx, ny]
                        if q[3] > 180 and not is_red(q) and not is_tag(q):
                            fill = q
                            break
                px[x, y] = fill
    return out


def paint_side_collar(im: Image.Image, facing_right: bool) -> None:
    px = im.load()
    # Neck band for the new puppy silhouette (face-right design space).
    pts = [
        (28, 22, COLLAR_D),
        (29, 22, COLLAR),
        (30, 22, COLLAR_H),
        (31, 22, COLLAR),
        (32, 22, COLLAR_D),
        (28, 23, COLLAR),
        (29, 23, COLLAR_H),
        (30, 23, COLLAR),
        (31, 23, COLLAR),
        (32, 23, COLLAR),
        (29, 24, COLLAR_D),
        (30, 24, COLLAR),
        (31, 24, COLLAR_D),
        (31, 25, TAG),
        (32, 25, TAG_D),
        (31, 26, TAG_D),
        (32, 26, TAG),
    ]
    for x, y, c in pts:
        xx = x if facing_right else (47 - x)
        if 0 <= xx < 48 and 0 <= y < 48 and im.getpixel((xx, y))[3] > 10:
            px[xx, y] = c


def shift_legs_tail(im: Image.Image, walk: int) -> Image.Image:
    """Mild trot: nudge lower-leg band and tip of tail."""
    if walk == 0:
        return im
    out = im.copy()
    px_in = im.load()
    px = out.load()
    # Clear then redraw a 2px leg band with horizontal offset
    leg_shift = [0, 1, 0, -1][walk % 4]
    tail_shift = [0, -1, 0, 1][walk % 4]
    # Legs: rows 33-37
    for y in range(33, 38):
        row = [px_in[x, y] for x in range(48)]
        for x in range(48):
            px[x, y] = (0, 0, 0, 0)
        for x in range(48):
            src = x - leg_shift
            if 0 <= src < 48 and row[src][3] > 10:
                px[x, y] = row[src]
    # Tail tip: rows 17-22, left side — shift a few pixels
    for y in range(16, 24):
        for x in range(8, 18):
            p = px_in[x, y]
            if p[3] > 10 and p[0] > 200 and p[1] > 180:  # cream tip-ish
                nx = x + tail_shift
                if 0 <= nx < 48:
                    px[x, y] = FUR_FALLBACK if px_in[x, y + 1][3] > 10 else (0, 0, 0, 0)
                    px[nx, y] = p
    return out


def make_front_from_side(side: Image.Image) -> Image.Image:
    """Author a simple front view using the new dog palette."""
    im = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    sp = side.load()
    px = im.load()
    # Sample palette from side
    fur = FUR_FALLBACK
    cream = (249, 222, 180, 255)
    ear = (118, 64, 36, 255)
    outline = (87, 41, 63, 255)
    for y in range(48):
        for x in range(48):
            p = sp[x, y]
            if p[3] < 10:
                continue
            if p[0] > 200 and p[1] > 180:
                cream = p
            elif 150 < p[0] < 250 and 100 < p[1] < 200 and p[2] < 120:
                fur = p
            elif p[0] < 100 and p[1] < 70:
                outline = p
            elif 90 < p[0] < 140 and p[1] < 80:
                ear = p

    def oval(cx, cy, rx, ry, c):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if ((x - cx) / max(rx, 1)) ** 2 + ((y - cy) / max(ry, 1)) ** 2 <= 1.05:
                    px[x, y] = c

    oval(24, 27, 9, 8, fur)
    oval(24, 29, 6, 5, cream)
    oval(24, 17, 8, 7, fur)
    oval(24, 19, 4, 3, cream)
    oval(17, 13, 3, 4, ear)
    oval(31, 13, 3, 4, ear)
    px[21, 16] = (40, 24, 28, 255)
    px[27, 16] = (40, 24, 28, 255)
    px[24, 19] = (94, 53, 28, 255)
    for x in range(19, 30):
        px[x, 23] = COLLAR if 20 <= x <= 28 else COLLAR_D
    for x in range(20, 29):
        px[x, 24] = COLLAR_H if x in (23, 24, 25) else COLLAR
    px[23, 25] = TAG
    px[24, 25] = TAG_D
    for x in (19, 22, 26, 29):
        px[x, 35] = ear
        px[x, 36] = outline
    return im


def make_back_from_side(side: Image.Image) -> Image.Image:
    im = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    sp = side.load()
    px = im.load()
    fur = FUR_FALLBACK
    cream = (249, 222, 180, 255)
    ear = (118, 64, 36, 255)
    outline = (87, 41, 63, 255)
    for y in range(48):
        for x in range(48):
            p = sp[x, y]
            if p[3] < 10:
                continue
            if p[0] > 200 and p[1] > 180:
                cream = p
            elif 150 < p[0] < 250 and 100 < p[1] < 200 and p[2] < 120:
                fur = p
            elif p[0] < 100 and p[1] < 70:
                outline = p
            elif 90 < p[0] < 140 and p[1] < 80:
                ear = p

    def oval(cx, cy, rx, ry, c):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if ((x - cx) / max(rx, 1)) ** 2 + ((y - cy) / max(ry, 1)) ** 2 <= 1.05:
                    px[x, y] = c

    oval(24, 26, 9, 8, fur)
    oval(24, 16, 7, 6, fur)
    oval(18, 13, 3, 3, ear)
    oval(30, 13, 3, 3, ear)
    # Nape collar — short curved band (not a flat ruler across the back)
    for x, y, c in (
        (20, 21, COLLAR_D),
        (21, 20, COLLAR),
        (22, 20, COLLAR_H),
        (23, 20, COLLAR),
        (24, 20, COLLAR_H),
        (25, 20, COLLAR),
        (26, 20, COLLAR_H),
        (27, 20, COLLAR),
        (28, 21, COLLAR_D),
        (21, 21, COLLAR),
        (22, 21, COLLAR),
        (23, 21, COLLAR_D),
        (24, 21, COLLAR),
        (25, 21, COLLAR_D),
        (26, 21, COLLAR),
        (27, 21, COLLAR),
    ):
        px[x, y] = c
    # tail
    px[24, 18] = fur
    px[24, 17] = fur
    px[24, 16] = cream
    for x in (19, 22, 26, 29):
        px[x, 34] = ear
        px[x, 35] = outline
    return im


def main() -> None:
    base_path = ASSETS / "animals/dog_idle.png"
    base = Image.open(base_path).convert("RGBA")
    # If someone already overwrote with a blob, prefer git-restored look:
    # we expect a cream chest + recognizable puppy. Proceed with current file.
    side = clear_red(base)
    paint_side_collar(side, facing_right=True)
    side.save(base_path)
    print("wrote", base_path)

    front0 = make_front_from_side(side)
    back0 = make_back_from_side(side)
    left0 = side.transpose(Image.FLIP_LEFT_RIGHT)

    sheet = Image.new("RGBA", (CELL * 4, CELL * 4), (0, 0, 0, 0))
    for row in range(4):
        frames = [
            shift_legs_tail(back0, row),
            shift_legs_tail(side, row),
            shift_legs_tail(front0, row),
            shift_legs_tail(left0, row),
        ]
        # Re-apply collar after leg shifts on side views (legs don't overlap collar)
        paint_side_collar(frames[1], True)
        paint_side_collar(frames[3], False)
        for col, fr in enumerate(frames):
            sheet.paste(fr, (col * CELL, row * CELL))

    walk_path = ASSETS / "animals/dog_walk.png"
    sheet.save(walk_path)
    print("wrote", walk_path)

    port = side.resize((128, 128), Image.NEAREST)
    port_path = ASSETS / "portraits/animal_dog.png"
    port.save(port_path)
    print("wrote", port_path)

    prev = ROOT / ".cache/tree_preview"
    prev.mkdir(parents=True, exist_ok=True)
    side.resize((CELL * 4, CELL * 4), Image.NEAREST).save(prev / "dog_idle_x4.png")
    sheet.crop((0, 0, CELL * 4, CELL)).resize((CELL * 16, CELL * 4), Image.NEAREST).save(
        prev / "dog_walk_row0_x4.png"
    )
    print("previews →", prev)


if __name__ == "__main__":
    main()
