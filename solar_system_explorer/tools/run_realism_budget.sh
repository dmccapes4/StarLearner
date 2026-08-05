#!/usr/bin/env bash
# Phase A — Hohmann / fuel / synodic realism budget probe.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
OUT="$ROOT/qa/out/realism_budget"
mkdir -p "$OUT"

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  GODOT="${HOME}/.local/bin/godot"
fi
if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "ERROR: godot not found (set GODOT=...)" >&2
  exit 1
fi

echo ">> realism budget via $GODOT --headless -s res://tools/probe_realism_budget.gd"
"$GODOT" --headless --path "$GAME" -s res://tools/probe_realism_budget.gd "$@"
STATUS=$?

LATEST="$(ls -1dt "$OUT"/*/ 2>/dev/null | head -1 || true)"
if [[ -n "${LATEST:-}" && -f "${LATEST}report.json" ]]; then
  echo ">> latest: $LATEST"
  python3 - <<PY
import json, pathlib
d = json.loads(pathlib.Path("${LATEST}report.json").read_text())
checks = d.get("checks", [])
failed = [c for c in checks if not c.get("ok")]
print(f"checks={len(checks)} failed={len(failed)} hops={len(d.get('hops', []))}")
for c in failed:
    print(" FAIL", c.get("name"), "—", c.get("detail"))
PY
fi
exit "$STATUS"
