#!/usr/bin/env bash
# Run Garden Explorer UX suite (screenshots + log/event checks).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
OUT="$GAME/docs/screenshots/ux"
mkdir -p "$OUT"
mkdir -p "${HOME}/.local/share/godot/app_userdata/Garden Explorer/logs" 2>/dev/null || true

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  GODOT="${HOME}/.local/bin/godot"
fi

ARGS=(--path "$GAME" -s res://tools/ux_suite.gd)
RUNNER=()

# Screenshot capture needs a real (or virtual) display + non-dummy renderer.
# Priority:
#   1) UX_HEADLESS=1     → --headless (logic only; shots skipped)
#   2) UX_DISPLAY=1      → use current $DISPLAY
#   3) xvfb-run if present
#   4) $DISPLAY already set → use it (typical desktop terminal)
#   5) else --headless
if [[ "${UX_HEADLESS:-0}" == "1" ]]; then
  ARGS=(--headless "${ARGS[@]}")
elif [[ "${UX_DISPLAY:-0}" == "1" ]]; then
  :
elif command -v xvfb-run >/dev/null 2>&1; then
  RUNNER=(xvfb-run -a -s "-screen 0 1280x720x24")
elif [[ -n "${DISPLAY:-}" ]]; then
  echo ">> using DISPLAY=$DISPLAY for screenshots"
else
  echo "!! no DISPLAY/xvfb; falling back to --headless (screenshots skip)"
  ARGS=(--headless "${ARGS[@]}")
fi

echo ">> UX suite via ${RUNNER[*]:-} $GODOT ${ARGS[*]}"
"${RUNNER[@]}" "$GODOT" "${ARGS[@]}" "$@"
STATUS=$?

echo ">> shots:"
ls -la "$OUT"/*.png 2>/dev/null || echo "(none)"
echo ">> report:"
python3 - <<'PY'
import json, pathlib
p=pathlib.Path("/home/dylanmccapes/dev/star_learning/garden_explorer/game/docs/screenshots/ux/ux_report.json")
if not p.exists():
    print("no report"); raise SystemExit
d=json.loads(p.read_text())
print(f"passed={d.get('passed')} failed={d.get('failed')} shots={d.get('shots')}")
for c in d.get("checks", []):
    if not c.get("ok"):
        print(" FAIL", c.get("name"), "—", c.get("detail"))
    elif "skipped" in str(c.get("detail", "")):
        print(" SKIP", c.get("name"), "—", c.get("detail"))
PY
exit "$STATUS"
