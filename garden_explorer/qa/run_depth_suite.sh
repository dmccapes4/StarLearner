#!/usr/bin/env bash
# Agent depth stress suite — screenshots + report under qa/out/depth_suite/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
OUT="$ROOT/qa/out/depth_suite"
mkdir -p "$OUT"

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  GODOT="${HOME}/.local/bin/godot"
fi
if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "ERROR: godot not found (set GODOT=...)" >&2
  exit 1
fi

ARGS=(--path "$GAME" --fixed-fps 24 -s res://tools/depth_suite.gd)
RUNNER=()

if [[ "${QA_HEADLESS:-0}" == "1" ]]; then
  ARGS=(--headless "${ARGS[@]}")
elif [[ "${QA_DISPLAY:-0}" == "1" ]]; then
  :
elif command -v xvfb-run >/dev/null 2>&1; then
  RUNNER=(xvfb-run -a -s "-screen 0 1280x720x24")
elif [[ -n "${DISPLAY:-}" ]]; then
  echo ">> using DISPLAY=$DISPLAY"
else
  echo "!! no DISPLAY/xvfb; using --headless (PNGs may be blank)"
  ARGS=(--headless "${ARGS[@]}")
fi

echo ">> depth suite via ${RUNNER[*]:-} $GODOT ${ARGS[*]}"
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
print("agent_brief:", d.get("agent_brief", "")[:200], "...")
for c in d.get("checks", []):
    if not c.get("ok"):
        print(" FAIL", c.get("name"), "—", c.get("detail"))
PY
  fi
fi
exit "$STATUS"
