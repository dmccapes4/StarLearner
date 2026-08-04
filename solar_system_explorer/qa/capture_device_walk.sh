#!/usr/bin/env bash
# Capture a timed on-device Free Flight / mission walkthrough for agent review.
# Usage:
#   ./qa/capture_device_walk.sh 20
#   SERIAL=ZL8326G8ND ./qa/capture_device_walk.sh 15
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEC="${1:-20}"
SERIAL="${SERIAL:-}"
OUT_ROOT="$ROOT/qa/out/device"
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"
OUT="$OUT_ROOT/$STAMP"
mkdir -p "$OUT"

ADB=(adb)
if [[ -n "$SERIAL" ]]; then
  ADB=(adb -s "$SERIAL")
elif [[ -n "$(adb get-state 2>/dev/null || true)" ]]; then
  :
else
  SERIAL="$(adb devices | awk '/device$/{print $1; exit}')"
  if [[ -z "$SERIAL" ]]; then
    echo "ERROR: no adb device" >&2
    exit 1
  fi
  ADB=(adb -s "$SERIAL")
fi

PKG="com.dylan.solar_system_explorer"
echo ">> device capture ${SEC}s → $OUT"
"${ADB[@]}" shell am start -n "${PKG}/com.godot.game.GodotApp" >/dev/null 2>&1 || true
sleep 1

"${ADB[@]}" shell "getevent -t" >"$OUT/getevent.txt" 2>&1 &
GEPID=$!

REMOTE="/sdcard/sse_qa_${STAMP}.mp4"
"${ADB[@]}" shell "screenrecord --time-limit $SEC $REMOTE"
kill "$GEPID" 2>/dev/null || true
wait "$GEPID" 2>/dev/null || true

"${ADB[@]}" pull "$REMOTE" "$OUT/walk.mp4"
"${ADB[@]}" shell "rm -f $REMOTE" >/dev/null 2>&1 || true

ffmpeg -y -hide_banner -loglevel error -i "$OUT/walk.mp4" -vf "fps=2" "$OUT/f_%02d.jpg"
ffmpeg -y -hide_banner -loglevel error -i "$OUT/walk.mp4" -vf "fps=1" "$OUT/s_%02d.jpg"

python3 - <<PY
import json, pathlib
out = pathlib.Path("$OUT")
frames = sorted([p.name for p in out.glob("f_*.jpg")])
meta = {
    "stamp": "$STAMP",
    "seconds": int("$SEC"),
    "video": "walk.mp4",
    "frames": frames,
    "getevent": "getevent.txt",
    "package": "$PKG",
    "agent_brief": "Review f_*.jpg in order. Note Free Flight speed pick, tilt/surge coaching, joy latch (speed keeps changing while phone is still after a pull), mission chart burn→coast readability, orbit capture. Extract tap XY from getevent if present.",
}
(out / "capture.json").write_text(json.dumps(meta, indent=2) + "\n")
print(f"frames={len(frames)} → {out}")
PY

echo "done: $OUT"
