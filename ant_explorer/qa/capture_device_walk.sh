#!/usr/bin/env bash
# Capture a timed on-device walkthrough for later agent review.
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

PKG="${ANTS_PKG:-com.dylan.ant_explorer}"
echo ">> device capture ${SEC}s → $OUT (pkg=$PKG)"
"${ADB[@]}" shell am start -n "${PKG}/com.godot.game.GodotApp" >/dev/null 2>&1 \
  || "${ADB[@]}" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 \
  || true
sleep 1

"${ADB[@]}" shell "getevent -t" >"$OUT/getevent.txt" 2>&1 &
GEPID=$!

REMOTE="/sdcard/ae_qa_${STAMP}.mp4"
"${ADB[@]}" shell "screenrecord --time-limit $SEC $REMOTE"
kill "$GEPID" 2>/dev/null || true
wait "$GEPID" 2>/dev/null || true

"${ADB[@]}" pull "$REMOTE" "$OUT/walk.mp4"
"${ADB[@]}" shell "rm -f $REMOTE" >/dev/null 2>&1 || true

if command -v ffmpeg >/dev/null 2>&1; then
  ffmpeg -y -hide_banner -loglevel error -i "$OUT/walk.mp4" -vf "fps=2" "$OUT/f_%02d.jpg"
  ffmpeg -y -hide_banner -loglevel error -i "$OUT/walk.mp4" -vf "fps=1" "$OUT/s_%02d.jpg"
fi

echo ">> wrote $OUT"
ls -la "$OUT" | head -20
