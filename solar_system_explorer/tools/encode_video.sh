#!/usr/bin/env bash
# Encode a frame sequence written by game/tools/record_retrograde.gd into an mp4,
# plus a contact sheet for looking at the whole sequence at a glance.
#
# Usage: tools/encode_video.sh <name> [fps]
#   name  subdirectory under game/docs/video, e.g. mars_cancer_2024
#
# Idempotent and safe to re-run; it overwrites its own outputs and touches
# nothing else.
set -euo pipefail

NAME="${1:?usage: encode_video.sh <name> [fps]}"
FPS="${2:-30}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/game/docs/video/$NAME"

if [ ! -d "$DIR" ]; then
	echo "no such frame directory: $DIR" >&2
	exit 1
fi

COUNT=$(find "$DIR" -maxdepth 1 -name 'frame_*.png' | wc -l)
if [ "$COUNT" -eq 0 ]; then
	echo "no frames in $DIR" >&2
	exit 1
fi
echo "encoding $COUNT frames at ${FPS}fps"

# yuv420p and the even-dimension filter keep the result playable everywhere,
# including browsers and phones, which is the point of rendering it at all.
ffmpeg -v error -y -framerate "$FPS" -i "$DIR/frame_%05d.png" \
	-c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
	-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
	"$ROOT/game/docs/video/$NAME.mp4"

# Six evenly spaced frames in a 3x2 grid, so the progression can be seen in a
# still where a video cannot be embedded.
STEP=$(( COUNT / 6 ))
[ "$STEP" -lt 1 ] && STEP=1
ffmpeg -v error -y -framerate "$FPS" -i "$DIR/frame_%05d.png" \
	-vf "select='not(mod(n\,$STEP))',scale=512:-1,tile=3x2" \
	-frames:v 1 "$ROOT/game/docs/video/${NAME}_sheet.png"

ls -lh "$ROOT/game/docs/video/$NAME.mp4" \
	"$ROOT/game/docs/video/${NAME}_sheet.png"
