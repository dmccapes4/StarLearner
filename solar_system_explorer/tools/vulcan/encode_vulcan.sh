#!/usr/bin/env bash
# Encode the Mercury/Vulcan ladder frame sequences into mp4 + contact sheets.
# Usage: tools/vulcan/encode_vulcan.sh [shot ...]     (default: every shot dir)
# Idempotent; overwrites its own outputs only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VID="$ROOT/docs/MERCURY_VULCAN_LADDER_20261010/video"
FPS=30
if [ $# -gt 0 ]; then SHOTS=("$@"); else mapfile -t SHOTS < <(find "$VID" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort); fi
for NAME in "${SHOTS[@]}"; do
	DIR="$VID/$NAME"
	COUNT=$(find "$DIR" -maxdepth 1 -name 'frame_*.png' | wc -l)
	[ "$COUNT" -eq 0 ] && { echo "skip $NAME (no frames)"; continue; }
	echo "encoding $NAME: $COUNT frames"
	ffmpeg -v error -y -framerate "$FPS" -i "$DIR/frame_%05d.png" \
		-c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
		-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "$VID/$NAME.mp4"
	STEP=$(( COUNT / 6 )); [ "$STEP" -lt 1 ] && STEP=1
	ffmpeg -v error -y -framerate "$FPS" -i "$DIR/frame_%05d.png" \
		-vf "select='not(mod(n\,$STEP))',scale=640:-1,tile=3x2" -frames:v 1 "$VID/${NAME}_sheet.png"
done
ls -lh "$VID"/*.mp4
