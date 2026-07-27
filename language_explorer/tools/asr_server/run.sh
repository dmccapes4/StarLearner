#!/usr/bin/env bash
# Run Language Explorer ASR + llama cleanup on this machine (dev / desktop Godot).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export ASR_HOST="${ASR_HOST:-0.0.0.0}"
# 8765 is often taken by other local MCP tools on this machine — default 8770.
export ASR_PORT="${ASR_PORT:-8770}"
export ASR_MODEL="${ASR_MODEL:-tiny.en}"
export OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
export OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2:3b}"
cd "$ROOT"
exec python3 "$ROOT/tools/asr_server/server.py"
