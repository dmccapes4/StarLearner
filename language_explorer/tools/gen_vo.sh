#!/usr/bin/env bash
# Dump VO manifest + bake ElevenLabs clips for Language Explorer.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$HOME/.local/bin/godot}"

echo "=== dump VO lines ==="
"$GODOT" --headless --path "$ROOT/game" -s res://tools/dump_vo_lines.gd

echo "=== bake ElevenLabs WAVs ==="
python3 "$ROOT/tools/gen_language_vo.py" "$@"
