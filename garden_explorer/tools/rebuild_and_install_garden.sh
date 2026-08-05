#!/usr/bin/env bash
# Rebuild Garden Explorer with canonical package + install to USB phone.
# Package id: com.dylan.garden_explorer (not legacy com.dylan.antexplorer.garden).
set -euo pipefail
cd "$(dirname "$0")/.."
BT="${ANDROID_HOME:-$HOME/Android/Sdk}/build-tools/36.0.0/aapt"
APK="tools/build/com.dylan.garden_explorer.apk"
WANT="com.dylan.garden_explorer"
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
echo "=== install ==="
## Fogona USB often drops mid streamed-install — wait for a device, then push.
for _i in $(seq 1 30); do
	"${ADB[@]}" devices -l
	if "${ADB[@]}" get-state 2>/dev/null | grep -q device; then
		break
	fi
	echo "(waiting for adb device… ${_i}/30)"
	sleep 1
done
"${ADB[@]}" get-state | grep -q device || { echo "ERROR: no adb device"; exit 1; }
"${ADB[@]}" install --no-streaming -r -g "$APK"
echo "=== remove legacy package ==="
"${ADB[@]}" uninstall com.dylan.antexplorer.garden || true
echo "=== on-device packages ==="
"${ADB[@]}" shell pm list packages | grep -E 'garden|antexplorer' || true
echo "done"
