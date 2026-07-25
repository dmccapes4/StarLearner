#!/usr/bin/env bash
# Dump VO lines + bake ElevenLabs WAVs for Garden Explorer.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
cd "$ROOT"
"$GODOT" --headless --path game -s res://tools/dump_vo_lines.gd
python3 "$ROOT/tools/gen_garden_vo.py" "$@"
echo "VO ready: game/audio/vo/"
ls "$ROOT/game/audio/vo" | wc -l
