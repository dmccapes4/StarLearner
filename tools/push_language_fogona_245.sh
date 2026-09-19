#!/usr/bin/env bash
# Push the already-built Language APK to fogona on 245 USB (Windows adb.exe).
#
#   ./tools/push_language_fogona_245.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APK="${1:-$ROOT/language_explorer/tools/build/com.dylan.language_explorer.apk}"
HOST="${STARLEARNER_245_HOST:-dylan@104.53.183.230}"
PORT="${STARLEARNER_245_PORT:-2222}"
KEY="${STARLEARNER_245_KEY:-$HOME/.ssh/id_ed25519}"
SERIAL="${STARLEARNER_FOGONA_SERIAL:-ZL8326G8ND}"

[[ -f "$APK" ]] || { echo "missing $APK — build first" >&2; exit 1; }

SSH=(ssh -o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=20 -i "$KEY" -p "$PORT" "$HOST")
SCP=(scp -o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=20 -i "$KEY" -P "$PORT")

echo "=== ensure Windows adb on 245 ==="
"${SSH[@]}" "powershell -NoProfile -Command \"New-Item -ItemType Directory -Force -Path 'C:\\Users\\dylan\\work\\system','C:\\Users\\dylan\\work\\star_learner\\tmp' | Out-Null\""
"${SCP[@]}" "$ROOT/tools/245_ensure_platform_tools.ps1" "$HOST:C:/Users/dylan/work/system/245_ensure_platform_tools.ps1"
"${SCP[@]}" "$ROOT/tools/245_install_language_fogona.ps1" "$HOST:C:/Users/dylan/work/system/245_install_language_fogona.ps1"
"${SSH[@]}" "powershell -NoProfile -ExecutionPolicy Bypass -File C:\\Users\\dylan\\work\\system\\245_ensure_platform_tools.ps1"

echo "=== devices ==="
"${SSH[@]}" "powershell -NoProfile -Command \"& 'C:\\Users\\dylan\\work\\system\\platform-tools\\adb.exe' devices -l\""

echo "=== stage APK ($(du -h "$APK" | awk '{print $1}')) ==="
"${SCP[@]}" "$APK" "$HOST:C:/Users/dylan/work/star_learner/tmp/com.dylan.language_explorer.apk"

echo "=== install on fogona ($SERIAL) ==="
"${SSH[@]}" "powershell -NoProfile -ExecutionPolicy Bypass -File C:\\Users\\dylan\\work\\system\\245_install_language_fogona.ps1 -Serial $SERIAL"
