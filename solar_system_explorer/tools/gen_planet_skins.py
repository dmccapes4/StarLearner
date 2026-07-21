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


SKINS = {
    "sun": sun,
    "mercury": mercury,
    "venus": venus,
    "earth": earth,
    "mars": mars,
    "asteroid_belt": asteroid_belt,
    "jupiter": jupiter,
    "saturn": saturn,
    "uranus": uranus,
    "neptune": neptune,
    "pluto": pluto,
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
