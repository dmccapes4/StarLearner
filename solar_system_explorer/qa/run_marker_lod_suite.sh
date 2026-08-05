#!/usr/bin/env bash
# Agent marker LOD suite — pixel AR pins vs 3D handoff for every flyer body.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
OUT="$ROOT/qa/out/marker_lod"
mkdir -p "$OUT"

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  GODOT="${HOME}/.local/bin/godot"
fi
if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "ERROR: godot not found (set GODOT=...)" >&2
  exit 1
fi

ARGS=(--path "$GAME" --fixed-fps 24 -s res://tools/marker_lod_suite.gd)
RUNNER=()

if [[ "${QA_HEADLESS:-0}" == "1" ]]; then
  ARGS=(--headless "${ARGS[@]}")
elif [[ "${QA_DISPLAY:-0}" == "1" ]]; then
  echo ">> using DISPLAY=${DISPLAY:-<unset>} (QA_DISPLAY=1)"
elif command -v xvfb-run >/dev/null 2>&1; then
  RUNNER=(xvfb-run -a -s "-screen 0 1280x720x24")
elif [[ -n "${DISPLAY:-}" ]] && xdpyinfo >/dev/null 2>&1; then
  echo ">> using DISPLAY=$DISPLAY"
else
  echo "!! no usable DISPLAY/xvfb; using --headless (PNGs may be blank)"
  ARGS=(--headless "${ARGS[@]}")
fi

echo ">> marker LOD suite via ${RUNNER[*]:-} $GODOT ${ARGS[*]}"
"${RUNNER[@]}" "$GODOT" "${ARGS[@]}" "$@" || true

LATEST="$(ls -1dt "$OUT"/*/ 2>/dev/null | head -1 || true)"
FAILED=0
if [[ -n "${LATEST:-}" && -f "${LATEST}report.json" ]]; then
  echo ">> latest: $LATEST"
  FAILED="$(python3 - <<PY
import json, pathlib
d = json.loads(pathlib.Path("${LATEST}report.json").read_text())
checks = d.get("checks", [])
failed = [c for c in checks if not c.get("ok")]
print(f"shots={len(d.get('shots', []))} checks={len(checks)} failed={len(failed)}")
for c in failed:
    print(" FAIL", c.get("name"), "—", c.get("detail"))
print(len(failed))
PY
)"
  FAILED="$(echo "$FAILED" | tail -1)"
fi
exit "$FAILED"
