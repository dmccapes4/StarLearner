#!/usr/bin/env python3
"""Chroma-key a flat-magenta background out of a generated sprite, then autocrop.

Our story sprites are generated on a solid flat magenta (#FF00FF) background so the
subject can sit over the live game scene. This replaces that magenta with alpha=0,
then crops to the sprite's bounding box (with a little padding).

Pink subjects (piggy bank!) survive: magenta has a very LOW green channel and HIGH
blue; pink keeps green mid-high, so the key below never touches it.

Usage:
    python3 tools/key_sprite.py SRC.png OUT.png [--pad N]
Re-runnable / idempotent.
"""
import argparse
from pathlib import Path

from PIL import Image


def is_magenta(r: int, g: int, b: int) -> bool:
    # Pure #FF00FF and its anti-aliased fringe: red & blue high, green clearly low.
    return r > 150 and b > 150 and g < 120 and (min(r, b) - g) > 70


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--pad", type=int, default=8)
    args = ap.parse_args()

    src = Path(args.src)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)

    img = Image.open(src).convert("RGBA")
    px = img.load()
    w, h = img.size
    keyed = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if is_magenta(r, g, b):
                px[x, y] = (0, 0, 0, 0)
                keyed += 1

    bbox = img.getbbox()  # tight box of non-zero-alpha content
    if bbox:
        l, t, rgt, bot = bbox
        l = max(0, l - args.pad)
        t = max(0, t - args.pad)
        rgt = min(w, rgt + args.pad)
        bot = min(h, bot + args.pad)
        img = img.crop((l, t, rgt, bot))

    img.save(out)
    pct = 100.0 * keyed / (w * h)
    print(f"keyed {pct:4.1f}% -> {out}  ({img.size[0]}x{img.size[1]})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
