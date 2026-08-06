#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
export DISPLAY="${DISPLAY:-:1}"
exec "$GODOT" --path "$ROOT/game" -s res://tools/zodiac_suite.gd "$@"
