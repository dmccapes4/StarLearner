#!/usr/bin/env bash
# Bed approach / gap-routing suite for agents.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
OUT="$ROOT/qa/out/bed_approach"
mkdir -p "$OUT"

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  GODOT="${HOME}/.local/bin/godot"
fi

ARGS=(--path "$GAME" --fixed-fps 24 -s res://tools/bed_approach_suite.gd)
RUNNER=()
if [[ "${QA_HEADLESS:-0}" == "1" ]]; then
  ARGS=(--headless "${ARGS[@]}")
elif command -v xvfb-run >/dev/null 2>&1 && [[ -z "${DISPLAY:-}" || "${QA_XVFB:-0}" == "1" ]]; then
  RUNNER=(xvfb-run -a -s "-screen 0 1280x720x24")
elif [[ -n "${DISPLAY:-}" ]]; then
  echo ">> using DISPLAY=$DISPLAY"
else
  ARGS=(--headless "${ARGS[@]}")
fi

echo ">> bed approach suite"
"${RUNNER[@]}" "$GODOT" "${ARGS[@]}" "$@"
STATUS=$?

LATEST="$(ls -1dt "$OUT"/*/ 2>/dev/null | head -1 || true)"
if [[ -n "${LATEST:-}" && -f "${LATEST}report.json" ]]; then
  echo ">> latest: $LATEST"
  python3 - <<PY
import json, pathlib
d=json.loads(pathlib.Path("${LATEST}report.json").read_text())
ok=sum(1 for c in d.get("checks",[]) if c.get("ok"))
bad=[c for c in d.get("checks",[]) if not c.get("ok")]
print(f"passed={ok} failed={len(bad)} shots={len(d.get('shots',[]))}")
for c in bad:
    print(" FAIL", c.get("name"), "—", c.get("detail"))
PY
fi
exit "$STATUS"
