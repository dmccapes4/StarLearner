#!/usr/bin/env bash
# Rebuild Garden Explorer with canonical package + install to USB phone.
# Package id: com.dylan.antexplorer.garden (kept — not com.dylan.garden_explorer).
set -euo pipefail
cd "$(dirname "$0")/.."
BT="${ANDROID_HOME:-$HOME/Android/Sdk}/build-tools/36.0.0/aapt"
APK="tools/build/com.dylan.antexplorer.garden.apk"
WANT="com.dylan.antexplorer.garden"
SERIAL="${1:-${ADB_SERIAL:-}}"
ADB=(adb)
[[ -n "$SERIAL" ]] && ADB+=( -s "$SERIAL" )

echo "=== rebuild ==="
./tools/build_garden_apk.sh
echo "=== verify package id inside APK ==="
"$BT" dump badging "$APK" | awk '/^package: /{print; exit}'
PKG="$("$BT" dump badging "$APK" | awk -F"'" '/^package: /{print $2; exit}')"
echo "embedded package: $PKG"
test "$PKG" = "$WANT" || { echo "ERROR: expected $WANT, got $PKG"; exit 1; }
echo "=== install over the app she's been using ==="
"${ADB[@]}" devices -l
"${ADB[@]}" install -r "$APK"
echo "=== remove stray misnamed install ==="
"${ADB[@]}" uninstall com.dylan.garden_explorer || true
echo "=== on-device packages ==="
"${ADB[@]}" shell pm list packages | grep -E 'garden|antexplorer' || true
echo "done"
