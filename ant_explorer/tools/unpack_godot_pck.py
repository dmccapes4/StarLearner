#!/usr/bin/env python3
"""Unpack a Godot 4.x .pck into a directory (Android assets layout).

Paths like res://project.binary become <out>/project.binary.
"""
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path


def unpack(pck_path: Path, out_dir: Path) -> int:
    data = pck_path.read_bytes()
    if data[:4] != b"GDPC":
        raise SystemExit(f"not a Godot pck: {pck_path}")

    off = 4
    version, major, minor, patch = struct.unpack_from("<IIII", data, off)
    off += 16
    pack_flags, file_base = struct.unpack_from("<IQ", data, off)
    off += 12
    off += 16 * 4  # reserved
    (file_count,) = struct.unpack_from("<I", data, off)
    off += 4

    if version != 2:
        raise SystemExit(f"unsupported pack version {version}")

    pck_start = 0
    if pack_flags & 2:  # PACK_REL_FILEBASE
        file_base += pck_start

    out_dir.mkdir(parents=True, exist_ok=True)
    written = 0
    for _ in range(file_count):
        (sl,) = struct.unpack_from("<I", data, off)
        off += 4
        raw_path = data[off : off + sl]
        off += sl
        # Paths are C strings; strip trailing NULs / junk after first NUL.
        raw_path = raw_path.split(b"\x00", 1)[0]
        path = raw_path.decode("utf-8", "surrogateescape")
        ofs, size = struct.unpack_from("<QQ", data, off)
        off += 16
        off += 16  # md5
        (flags,) = struct.unpack_from("<I", data, off)
        off += 4
        if flags & 1:  # encrypted
            raise SystemExit(f"encrypted file not supported: {path}")

        if path.startswith("res://"):
            rel = path[6:]
        else:
            rel = path.lstrip("/")
        if not rel or rel.endswith("/") or "\x00" in rel:
            continue

        dest = out_dir / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        start = file_base + ofs
        dest.write_bytes(data[start : start + size])
        written += 1

    remaps = _imports_to_remaps(out_dir)
    print(f"unpacked {written} files → {out_dir} (engine {major}.{minor}.{patch})")
    print(f"wrote {remaps} .remap sidecars from .import (required on device)")
    return written


def _imports_to_remaps(out_dir: Path) -> int:
    """Godot runtime loads textures via .remap; .import is editor-only.

    export-pack often ships foo.png.import + .godot/imported/*.ctex but no
    foo.png. Convert each import's path= into foo.png.remap so load() works.
    """
    count = 0
    for imp in out_dir.rglob("*.import"):
        if not imp.name.endswith(".import"):
            continue
        text = imp.read_text(encoding="utf-8", errors="replace")
        dest_path = None
        for line in text.splitlines():
            line = line.strip()
            if line.startswith("path=") or line.startswith('path="'):
                # path="res://.godot/imported/....ctex"
                val = line.split("=", 1)[1].strip().strip('"')
                if val.startswith("res://"):
                    dest_path = val
                    break
        if not dest_path:
            continue
        # foo.png.import → foo.png.remap
        name = imp.name
        if not name.endswith(".import"):
            continue
        remap = imp.with_name(name[: -len(".import")] + ".remap")
        if remap.exists():
            continue
        remap.write_text(f'[remap]\n\npath="{dest_path}"\n', encoding="utf-8")
        count += 1
    return count


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("pck")
    ap.add_argument("out_dir")
    args = ap.parse_args()
    unpack(Path(args.pck), Path(args.out_dir))


if __name__ == "__main__":
    main()
