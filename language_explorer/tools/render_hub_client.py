#!/usr/bin/env python3
"""Render res://data/hub_client.json for Language Explorer APK assets."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Phone reaches the hub over WAN (hairpin OK). LAN dev ASR is editor-only.
PRODUCTION_BASES = [
    "https://hub.starlearner.app:8443/api/asr",
]


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--out", required=True, help="Output hub_client.json path")
    p.add_argument("--token-file", help="Bearer token (hub245/token.txt)")
    p.add_argument("--token", help="Bearer token inline (overrides --token-file)")
    p.add_argument(
        "--bases-json",
        help='JSON array of base URLs (default: production hub ASR only)',
    )
    p.add_argument("--dev", action="store_true", help="Include LAN ASR base for desktop")
    args = p.parse_args()

    token = ""
    if args.token:
        token = args.token.strip()
    elif args.token_file:
        path = Path(args.token_file)
        if path.is_file():
            token = path.read_text(encoding="utf-8").strip()

    if args.bases_json:
        bases = json.loads(args.bases_json)
    elif args.dev:
        bases = ["http://10.0.0.82:8770", *PRODUCTION_BASES]
    else:
        bases = list(PRODUCTION_BASES)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        json.dumps({"bases": bases, "token": token}, indent=2) + "\n",
        encoding="utf-8",
    )
    if not token:
        print(
            "WARNING: hub_client.json has empty token — hub ASR will 403",
            file=sys.stderr,
        )
        return 1
    print(f"OK {out} bases={len(bases)} token_len={len(token)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
