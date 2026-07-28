#!/usr/bin/env python3
"""Probe ASR /health for hub_client bases (supports pinned TLS via curl -k)."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def probe(base: str, token: str = "", insecure: bool = True) -> bool:
    base = base.rstrip("/")
    cmd = ["curl", "-sf", "--connect-timeout", "6", "--max-time", "12"]
    if insecure and base.startswith("https://"):
        cmd.append("-k")
    if token:
        cmd.extend(["-H", f"Authorization: Bearer {token}"])
    cmd.append(f"{base}/health")
    return subprocess.run(cmd, capture_output=True).returncode == 0


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: asr_health_check.py hub_client.json [--require-hub]", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    require_hub = "--require-hub" in sys.argv[2:]
    d = json.loads(path.read_text(encoding="utf-8"))
    bases = d.get("bases") or []
    tok = d.get("token") or ""
    if not bases:
        print("FAIL no bases in hub_client.json", file=sys.stderr)
        return 1
    ok_any = 0
    ok_hub = 0
    for b in bases:
        good = probe(b, tok)
        tag = "OK" if good else "FAIL"
        print(f"{tag}  {b.rstrip('/')}/health")
        if good:
            ok_any += 1
            if "hub.starlearner.app" in b:
                ok_hub += 1
    if require_hub and ok_hub == 0:
        print("FAIL production hub ASR unreachable", file=sys.stderr)
        return 1
    if ok_any == 0:
        print("FAIL no ASR base reachable", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
