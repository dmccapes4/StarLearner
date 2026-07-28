#!/usr/bin/env bash
# Post-deploy validation suite for a connected phone (local USB or 245 adb bridge).
#
# Usage:
#   ./tools/run_all_validation.sh [SERIAL]
#   REQUIRE_HUB_ASR=1 ./tools/run_all_validation.sh ZL8326G8ND   # production kiosk
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERIAL="${1:-${ADB_SERIAL:-}}"
export ADB="${ADB:-adb}"
export ADB_SERIAL="$SERIAL"

echo "=== validate_deploy ==="
"$ROOT/tools/validate_deploy.sh" ${SERIAL:+"$SERIAL"}

echo ""
echo "=== voice_smoke_test --remote ==="
bash "$ROOT/language_explorer/tools/voice_smoke_test.sh" --remote

if command -v "${GODOT:-$HOME/.local/bin/godot}" >/dev/null 2>&1; then
  echo ""
  echo "=== voice_smoke_test --local (host unit tests + ASR) ==="
  bash "$ROOT/language_explorer/tools/voice_smoke_test.sh" --local
else
  echo "SKIP voice_smoke --local (godot not installed on this host)"
fi

echo ""
echo "ALL VALIDATION OK"
