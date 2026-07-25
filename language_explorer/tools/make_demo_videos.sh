#!/usr/bin/env bash
# Record the automated Language Explorer tour and convert it to kiosk MP4.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
OUT="$ROOT/docs/demo"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
AVI="${LANGUAGE_DEMO_AVI:-/tmp/language_explorer.avi}"
MP4="$OUT/language_explorer_explainer.mp4"
FPS=24

mkdir -p "$OUT"

if [[ -z "${DISPLAY:-}" ]]; then
  if command -v xvfb-run >/dev/null 2>&1; then
    exec xvfb-run -a -s "-screen 0 1280x720x24" env DISPLAY=:99 "$0" "$@"
  fi
  echo "ERROR: need DISPLAY or xvfb-run for Godot MovieWriter" >&2
  exit 1
fi

"$GODOT" --path "$GAME" \
  --fixed-fps "$FPS" \
  --disable-vsync \
  --write-movie "$AVI" \
  -s res://tools/record_playthrough_demo.gd

if ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 "$AVI" | rg -q audio; then
  ffmpeg -y -hide_banner -loglevel error -i "$AVI" \
    -c:v libx264 -pix_fmt yuv420p -preset fast -crf 18 \
    -c:a aac -b:a 192k "$MP4"
else
  ffmpeg -y -hide_banner -loglevel error -i "$AVI" \
    -c:v libx264 -pix_fmt yuv420p -preset fast -crf 18 -an "$MP4"
fi
echo "OK $MP4 ($(du -h "$MP4" | awk '{print $1}'))"
