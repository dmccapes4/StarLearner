#!/usr/bin/env bash
# Agent flight-mechanics suite — screenshots + report under qa/out/flight_mechanics/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
OUT="$ROOT/qa/out/flight_mechanics"
mkdir -p "$OUT"

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  GODOT="${HOME}/.local/bin/godot"
fi
if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "ERROR: godot not found (set GODOT=...)" >&2
  exit 1
fi

ARGS=(--path "$GAME" --fixed-fps 24 -s res://tools/flight_mechanics_suite.gd)
RUNNER=()

if [[ "${QA_HEADLESS:-0}" == "1" ]]; then
  ARGS=(--headless "${ARGS[@]}")
elif [[ "${QA_DISPLAY:-0}" == "1" ]]; then
  echo ">> using DISPLAY=${DISPLAY:-<unset>} (QA_DISPLAY=1)"
elif command -v xvfb-run >/dev/null 2>&1; then
  # Prefer Xvfb over a stale DISPLAY (e.g. :1 with no X) — avoids Godot SIGSEGV.
  RUNNER=(xvfb-run -a -s "-screen 0 1280x720x24")
elif [[ -n "${DISPLAY:-}" ]] && xdpyinfo >/dev/null 2>&1; then
  echo ">> using DISPLAY=$DISPLAY"
else
  echo "!! no usable DISPLAY/xvfb; using --headless (PNGs may be blank)"
  ARGS=(--headless "${ARGS[@]}")
fi

echo ">> flight mechanics suite via ${RUNNER[*]:-} $GODOT ${ARGS[*]}"
"${RUNNER[@]}" "$GODOT" "${ARGS[@]}" "$@"
STATUS=$?

LATEST="$(ls -1dt "$OUT"/*/ 2>/dev/null | head -1 || true)"
if [[ -n "${LATEST:-}" ]]; then
  echo ">> latest: $LATEST"
  ls -la "$LATEST" | head -40
  if [[ -f "${LATEST}report.json" ]]; then
    python3 - <<PY
import json, pathlib
p = pathlib.Path("${LATEST}report.json")
d = json.loads(p.read_text())
print(f"shots={len(d.get('shots', []))} checks={len(d.get('checks', []))}")
print("agent_brief:", d.get("agent_brief", "")[:220], "...")
for c in d.get("checks", []):
    if not c.get("ok"):
        print(" FAIL", c.get("name"), "—", c.get("detail"))
passed = sum(1 for c in d.get("checks", []) if c.get("ok"))
failed = sum(1 for c in d.get("checks", []) if not c.get("ok"))
print(f"passed={passed} failed={failed}")
PY
  fi
fi
exit "$STATUS"
