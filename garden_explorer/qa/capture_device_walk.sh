#!/usr/bin/env bash
# Capture a timed on-device walkthrough for later agent review / replay.
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
  # Prefer first device
  SERIAL="$(adb devices | awk '/device$/{print $1; exit}')"
  if [[ -z "$SERIAL" ]]; then
    echo "ERROR: no adb device" >&2
    exit 1
  fi
  ADB=(adb -s "$SERIAL")
fi

echo ">> device capture ${SEC}s → $OUT"
"${ADB[@]}" shell am start -n com.dylan.garden_explorer/com.godot.game.GodotApp >/dev/null 2>&1 || true
sleep 1

# Touch log (best-effort): dump all getevent while recording
"${ADB[@]}" shell "getevent -t" >"$OUT/getevent.txt" 2>&1 &
GEPID=$!

REMOTE="/sdcard/ge_qa_${STAMP}.mp4"
"${ADB[@]}" shell "screenrecord --time-limit $SEC $REMOTE"
kill "$GEPID" 2>/dev/null || true
wait "$GEPID" 2>/dev/null || true

"${ADB[@]}" pull "$REMOTE" "$OUT/walk.mp4"
"${ADB[@]}" shell "rm -f $REMOTE" >/dev/null 2>&1 || true

# Dense frames for agent Read tool
ffmpeg -y -hide_banner -loglevel error -i "$OUT/walk.mp4" -vf "fps=2" "$OUT/f_%02d.jpg"
# Also keep a handful of keyframe-ish stills
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
    "agent_brief": "Review f_*.jpg in order. Note gate height, bed depth (walk-on-top), coop taps, ANIMALS label absence. Extract tap XY from getevent if present for replay.",
}
(out / "capture.json").write_text(json.dumps(meta, indent=2) + "\n")
print(f"frames={len(frames)} → {out}")
PY

echo "done: $OUT"
