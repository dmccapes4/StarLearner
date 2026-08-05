#!/usr/bin/env bash
# Capture ~10s walk clips + state.jsonl, mux to mp4, optional vision review.
#
#   ./qa/run_movement_video_suite.sh
#   REVIEW=0 ./qa/run_movement_video_suite.sh          # capture only
#   REVIEW=1 ./qa/run_movement_video_suite.sh          # capture + Grok/OpenAI review
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
OUT_ROOT="$ROOT/qa/out/movement_video"
mkdir -p "$OUT_ROOT"

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  GODOT="${HOME}/.local/bin/godot"
fi
if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "ERROR: godot not found" >&2
  exit 1
fi

export GODOT_USER_DATA_DIR="${GODOT_USER_DATA_DIR:-$ROOT/qa/out/.godot_user}"
mkdir -p "$GODOT_USER_DATA_DIR"

ARGS=(--path "$GAME" --fixed-fps 24 -s res://tools/movement_video_suite.gd)
RUNNER=()

if [[ "${QA_HEADLESS:-0}" == "1" ]]; then
  echo "!! QA_HEADLESS=1 — PNGs may be blank; prefer DISPLAY/xvfb" >&2
  ARGS=(--headless "${ARGS[@]}")
elif [[ "${QA_DISPLAY:-0}" == "1" ]]; then
  echo ">> using DISPLAY=${DISPLAY:-<unset>}"
elif command -v xvfb-run >/dev/null 2>&1 && [[ -z "${DISPLAY:-}" || "${QA_XVFB:-0}" == "1" ]]; then
  RUNNER=(xvfb-run -a -s "-screen 0 1280x720x24")
elif [[ -n "${DISPLAY:-}" ]] && xdpyinfo >/dev/null 2>&1; then
  echo ">> using DISPLAY=$DISPLAY"
elif [[ -n "${DISPLAY:-}" ]]; then
  echo ">> using DISPLAY=$DISPLAY"
else
  echo "!! no DISPLAY/xvfb; using --headless" >&2
  ARGS=(--headless "${ARGS[@]}")
fi

echo ">> movement video suite via ${RUNNER[*]:-} $GODOT ${ARGS[*]}"
"${RUNNER[@]}" "$GODOT" "${ARGS[@]}" || true

LATEST="$(ls -1dt "$OUT_ROOT"/*/ 2>/dev/null | head -1 || true)"
if [[ -z "${LATEST:-}" ]]; then
  echo "ERROR: no output folder" >&2
  exit 1
fi
echo ">> latest: $LATEST"

# Mux each clip's frames → walk.mp4 @ capture fps from meta.json
if command -v ffmpeg >/dev/null 2>&1; then
  for clip_dir in "$LATEST"*/; do
    [[ -d "${clip_dir}frames" ]] || continue
    fps="$(python3 - <<PY
import json, pathlib
p = pathlib.Path("${clip_dir}meta.json")
print(json.loads(p.read_text()).get("capture_fps", 12) if p.exists() else 12)
PY
)"
    out_mp4="${clip_dir}walk.mp4"
    ffmpeg -y -hide_banner -loglevel error \
      -framerate "$fps" -i "${clip_dir}frames/f_%04d.png" \
      -c:v libx264 -pix_fmt yuv420p -crf 20 "$out_mp4"
    echo "  mp4 $(basename "$clip_dir") → $out_mp4 ($(du -h "$out_mp4" | awk '{print $1}'))"
  done
else
  echo "!! ffmpeg missing — frames only" >&2
fi

FAILED=0
if [[ -f "${LATEST}report.json" ]]; then
  python3 - <<PY
import json, pathlib
d = json.loads(pathlib.Path("${LATEST}report.json").read_text())
checks = d.get("checks", [])
failed = [c for c in checks if not c.get("ok")]
print(f"clips={len(d.get('clips', []))} checks={len(checks)} failed={len(failed)}")
for c in failed:
    print(" FAIL", c.get("name"), "—", c.get("detail"))
if d.get("fatal"):
    print(" FATAL", d.get("fatal"))
pathlib.Path("/tmp/movement_video_failed").write_text(str(len(failed) + (1 if d.get("fatal") else 0)))
PY
  FAILED="$(cat /tmp/movement_video_failed 2>/dev/null || echo 1)"
fi

if [[ "${REVIEW:-1}" == "1" ]]; then
  ENV_FILE="${ROOT}/../.env"
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    set -a; source "$ENV_FILE"; set +a
  fi
  echo ">> vision review → ${LATEST}"
  python3 "$ROOT/qa/review_movement_videos.py" "$LATEST" || FAILED=1
fi

exit "$FAILED"
