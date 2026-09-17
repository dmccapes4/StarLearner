#!/usr/bin/env python3
"""Generate kid-readable equirectangular planet albedo PNGs (no external downloads).

Writes game/images/planets/<id>.png for each flyer body. Re-run anytime; idempotent.
"""
from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "images" / "planets"
W, H = 512, 256


def _png(rgba: bytes, w: int, h: int) -> bytes:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(
            ">I", zlib.crc32(tag + data) & 0xFFFFFFFF
        )

    raw = b"".join(b"\x00" + rgba[y * w * 4 : (y + 1) * w * 4] for y in range(h))
    return b"".join(
        [
            b"\x89PNG\r\n\x1a\n",
            chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)),
            chunk(b"IDAT", zlib.compress(raw, 9)),
            chunk(b"IEND", b""),
        ]
    )


def _hash(x: int, y: int, s: int) -> float:
    n = (x * 374761393 + y * 668265263 + s * 1274126177) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return (n & 0xFFFF) / 65535.0


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def _mix(c0, c1, t):
    return tuple(_lerp(a, b, t) for a, b in zip(c0, c1))


def _clamp(x: float) -> float:
    return max(0.0, min(1.0, x))


def _pix(fn, seed: int) -> bytes:
    out = bytearray(W * H * 4)
    for y in range(H):
        v = y / (H - 1)
        for x in range(W):
            u = x / (W - 1)
            r, g, b = fn(u, v, seed, x, y)
            i = (y * W + x) * 4
            out[i : i + 4] = (
                int(_clamp(r) * 255),
                int(_clamp(g) * 255),
                int(_clamp(b) * 255),
                255,
            )
    return bytes(out)


def sun(u, v, seed, x, y):
    n = _hash(x // 3, y // 3, seed)
    core = (1.0, 0.85, 0.25)
    rim = (1.0, 0.55, 0.05)
    t = abs(v - 0.5) * 1.6 + n * 0.15
    return _mix(core, rim, _clamp(t))


def mercury(u, v, seed, x, y):
    n = _hash(x // 2, y // 2, seed)
    crater = 1.0 - 0.35 * (1.0 if n > 0.82 else 0.0)
    base = (0.55, 0.52, 0.48)
    return tuple(c * crater * (0.75 + 0.25 * n) for c in base)


def venus(u, v, seed, x, y):
    swirl = 0.5 + 0.5 * math.sin((u * 8 + v * 2) * math.pi + seed)
    n = _hash(x // 4, y // 2, seed)
    return _mix((0.95, 0.78, 0.35), (0.75, 0.55, 0.25), swirl * 0.6 + n * 0.2)


def earth(u, v, seed, x, y):
    lat = abs(v - 0.5) * 2.0
    n = _hash(x // 3, y // 3, seed)
    if lat > 0.78:
        return (0.92, 0.95, 0.98)
    land = n > 0.55
    if land:
        return _mix((0.18, 0.45, 0.18), (0.45, 0.35, 0.18), n)
    return _mix((0.12, 0.28, 0.70), (0.25, 0.55, 0.85), n)


def mars(u, v, seed, x, y):
    n = _hash(x // 2, y // 2, seed)
    polar = abs(v - 0.5) * 2.0 > 0.82
    if polar:
        return (0.9, 0.9, 0.95)
    return _mix((0.55, 0.22, 0.12), (0.85, 0.45, 0.25), n)


def asteroid_belt(u, v, seed, x, y):
    n = _hash(x, y, seed)
    rock = (0.45 + n * 0.25, 0.40 + n * 0.2, 0.35 + n * 0.15)
    return rock if n > 0.35 else (0.08, 0.08, 0.1)


def ceres(u, v, seed, x, y):
    n = _hash(x // 2, y // 2, seed)
    # Occator's famous bright salt spots.
    spot = (u - 0.58) ** 2 + (v - 0.42) ** 2 < 0.0012 or \
        (u - 0.62) ** 2 + (v - 0.44) ** 2 < 0.0005
    if spot:
        return (0.95, 0.95, 0.90)
    crater = 1.0 - 0.30 * (1.0 if n > 0.80 else 0.0)
    base = (0.52, 0.50, 0.46)
    return tuple(c * crater * (0.75 + 0.25 * n) for c in base)


def vesta(u, v, seed, x, y):
    n = _hash(x // 2, y // 2, seed)
    # The huge Rheasilvia mound near the south pole.
    mound = v > 0.82 and _hash(x // 3, y // 3, seed + 5) > 0.3
    if mound:
        return (0.80, 0.74, 0.62)
    crater = 1.0 - 0.35 * (1.0 if n > 0.83 else 0.0)
    base = (0.62, 0.56, 0.46)
    return tuple(c * crater * (0.7 + 0.3 * n) for c in base)


def psyche(u, v, seed, x, y):
    n = _hash(x // 2, y // 2, seed)
    # Metal world: cool gray with mirror-bright glints.
    glint = n > 0.92
    if glint:
        return (0.92, 0.94, 1.0)
    return _mix((0.38, 0.40, 0.46), (0.62, 0.65, 0.72), n)


def jupiter(u, v, seed, x, y):
    bands = 0.5 + 0.5 * math.sin(v * 22 * math.pi)
    n = _hash(x // 6, y // 2, seed)
    spot = (u - 0.62) ** 2 + (v - 0.55) ** 2 < 0.004
    if spot:
        return (0.85, 0.35, 0.22)
    return _mix((0.78, 0.62, 0.42), (0.92, 0.78, 0.55), bands * 0.7 + n * 0.2)


def saturn(u, v, seed, x, y):
    bands = 0.5 + 0.5 * math.sin(v * 14 * math.pi)
    n = _hash(x // 5, y // 2, seed)
    return _mix((0.75, 0.68, 0.45), (0.95, 0.88, 0.65), bands * 0.6 + n * 0.15)


def uranus(u, v, seed, x, y):
    n = _hash(x // 8, y // 4, seed)
    return _mix((0.45, 0.75, 0.80), (0.65, 0.90, 0.92), 0.4 + n * 0.3 + abs(v - 0.5))


def neptune(u, v, seed, x, y):
    n = _hash(x // 6, y // 3, seed)
    storm = (u - 0.4) ** 2 + (v - 0.5) ** 2 < 0.006
    if storm:
        return (0.35, 0.55, 0.95)
    return _mix((0.12, 0.25, 0.70), (0.30, 0.50, 0.95), n)


def pluto(u, v, seed, x, y):
    n = _hash(x // 2, y // 2, seed)
    heart = (u - 0.55) ** 2 * 1.4 + (v - 0.45) ** 2 < 0.02
    if heart:
        return (0.95, 0.85, 0.80)
    return _mix((0.55, 0.48, 0.42), (0.78, 0.70, 0.60), n)


def _blob(u, v, cu, cv, ru, rv):
    """Soft elliptical falloff, 1.0 at the centre and 0.0 at the rim."""
    d = ((u - cu) / ru) ** 2 + ((v - cv) / rv) ** 2
    if d >= 1.0:
        return 0.0
    return 1.0 - d


# Near-side maria, as (u, v, half-width, half-height) in equirectangular
# coordinates where u = 0.5 + lon/360 and v = 0.5 - lat/180. Positions are the
# real selenographic ones, so the face that turns toward Earth is recognisable
# rather than generic grey noise.
_MARIA = (
    (0.339, 0.394, 0.085, 0.150),  # Oceanus Procellarum
    (0.450, 0.317, 0.058, 0.078),  # Mare Imbrium
    (0.547, 0.344, 0.040, 0.052),  # Mare Serenitatis
    (0.586, 0.450, 0.040, 0.050),  # Mare Tranquillitatis
    (0.664, 0.406, 0.028, 0.036),  # Mare Crisium
    (0.453, 0.617, 0.042, 0.040),  # Mare Nubium
    (0.392, 0.633, 0.030, 0.032),  # Mare Humorum
    (0.594, 0.583, 0.028, 0.032),  # Mare Nectaris
    (0.644, 0.544, 0.032, 0.044),  # Mare Fecunditatis
)

# Bright ray craters, as (u, v, radius).
_RAY_CRATERS = ((0.469, 0.739, 0.020), (0.444, 0.444, 0.014))


def moon(u, v, seed, x, y):
    # Coarse cells for terrain, a gentler fine grain on top. Kept low-contrast
    # so the disc reads as the Moon and not as sandpaper -- the maria have to
    # be the thing the eye picks up.
    n = _hash(x // 4, y // 4, seed)
    mid = _hash(x // 2, y // 2, seed + 11)
    fine = _hash(x, y, seed + 3)
    # Bright, heavily cratered highlands.
    base = _mix((0.60, 0.58, 0.55), (0.72, 0.70, 0.66), n * 0.6 + mid * 0.4)
    # Dark basalt plains sit on top of the highlands.
    mare = 0.0
    for cu, cv, ru, rv in _MARIA:
        mare = max(mare, _blob(u, v, cu, cv, ru, rv))
    if mare > 0.0:
        edge = _clamp(mare * 2.4)
        base = _mix(base, _mix((0.30, 0.30, 0.32), (0.36, 0.36, 0.38), mid),
                    edge)
    # Craters: sparse dark pits with bright rims.
    if mid > 0.955:
        base = tuple(c * 0.80 for c in base)
    elif mid > 0.930:
        base = tuple(min(1.0, c * 1.14) for c in base)
    # Fresh craters throw bright rays across everything.
    for cu, cv, r in _RAY_CRATERS:
        d = math.hypot(u - cu, v - cv)
        if d < r:
            base = (0.92, 0.91, 0.88)
        elif d < r * 4.0 and fine > 0.70:
            t = 1.0 - (d - r) / (r * 3.0)
            base = _mix(base, (0.88, 0.87, 0.84), _clamp(t) * 0.55)
    return tuple(c * (0.97 + 0.03 * fine) for c in base)


SKINS = {
    "sun": sun,
    "mercury": mercury,
    "venus": venus,
    "earth": earth,
    "mars": mars,
    "asteroid_belt": asteroid_belt,
    "ceres": ceres,
    "vesta": vesta,
    "psyche": psyche,
    "jupiter": jupiter,
    "saturn": saturn,
    "uranus": uranus,
    "neptune": neptune,
    "pluto": pluto,
    # Appended deliberately: the seed is 1000 + index, so inserting anywhere
    # above would reshuffle every later body's texture.
    "moon": moon,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for i, (body_id, fn) in enumerate(SKINS.items()):
        rgba = _pix(fn, seed=1000 + i * 17)
        path = OUT / f"{body_id}.png"
        path.write_bytes(_png(rgba, W, H))
        print(f"wrote {path.relative_to(ROOT)} ({W}x{H})")
    print("OK", len(SKINS), "skins")


if __name__ == "__main__":
    main()
