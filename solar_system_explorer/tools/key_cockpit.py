#!/usr/bin/env python3
"""Key the flat-magenta window of a generated cockpit frame to transparent.

The cockpit art is generated with its window filled solid chroma magenta
(#FF00FF) so the live 3D scene shows through at runtime. This replaces that
region with alpha=0, keeps the frame (no crop), and optionally verifies by
compositing over a dark test background.

Usage:
    python3 tools/key_cockpit.py SRC_PNG [OUT_PNG]
    python3 tools/key_cockpit.py --verify [COCKPIT_PNG]

Defaults OUT = game/images/cockpit.png. Idempotent.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
DEFAULT_OUT = REPO / "game" / "images" / "cockpit.png"
VERIFY_DIR = REPO / "tools" / "build"


def is_magenta(r: int, g: int, b: int) -> bool:
    # Red+blue high, green clearly lower — skips cream frame / orange / blue buttons.
    return r > 150 and b > 150 and g < min(r, b) - 60


def key_magenta(img: Image.Image) -> tuple[Image.Image, int]:
    out = img.convert("RGBA")
    px = out.load()
    w, h = out.size
    keyed = 0
    for y in range(h):
        for x in range(w):
            r, g, b, _a = px[x, y]
            if is_magenta(r, g, b):
                px[x, y] = (0, 0, 0, 0)
                keyed += 1
    return out, keyed


def window_clear_ratio(img: Image.Image) -> float:
    """Fraction of the central canopy region that is fully transparent."""
    rgba = img.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    cx0, cx1 = int(w * 0.22), int(w * 0.78)
    cy0, cy1 = int(h * 0.10), int(h * 0.58)
    clear = total = 0
    for y in range(cy0, cy1):
        for x in range(cx0, cx1):
            total += 1
            if px[x, y][3] == 0:
                clear += 1
    return clear / total if total else 0.0


def leftover_magenta(img: Image.Image) -> int:
    rgba = img.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    n = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0 and is_magenta(r, g, b):
                n += 1
    return n


def verify(path: Path, write_composite: bool = True) -> int:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    ratio = window_clear_ratio(img)
    mag = leftover_magenta(img)
    print(f"verify {path}  {w}x{h}  window_clear={ratio * 100:.1f}%  leftover_magenta={mag}")
    ok = ratio >= 0.90 and mag == 0 and w >= 640 and h >= 360
    if write_composite:
        VERIFY_DIR.mkdir(parents=True, exist_ok=True)
        bg = Image.new("RGBA", (w, h), (8, 12, 28, 255))
        # Draw a simple "planet" behind the window so keyed holes are obvious.
        from PIL import ImageDraw

        d = ImageDraw.Draw(bg)
        d.ellipse((w * 0.35, h * 0.2, w * 0.65, h * 0.55), fill=(80, 140, 220, 255))
        comp = Image.alpha_composite(bg, img)
        out = VERIFY_DIR / "cockpit_verify.png"
        comp.convert("RGB").save(out)
        print(f"wrote composite {out}")
    if not ok:
        print("FAIL: cockpit window not cleanly keyed", file=sys.stderr)
        return 1
    print("OK")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[1] == "--verify":
        path = Path(argv[2]) if len(argv) > 2 else DEFAULT_OUT
        return verify(path)

    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    src = Path(argv[1])
    out = Path(argv[2]) if len(argv) > 2 else DEFAULT_OUT
    out.parent.mkdir(parents=True, exist_ok=True)

    keyed, n = key_magenta(Image.open(src))
    keyed.save(out)
    pct = 100.0 * n / (keyed.size[0] * keyed.size[1])
    print(f"keyed {n} px ({pct:.1f}%) -> {out}  ({keyed.size[0]}x{keyed.size[1]})")
    return verify(out)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
