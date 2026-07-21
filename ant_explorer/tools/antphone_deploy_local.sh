#!/usr/bin/env bash
# Deploy APK(s) + catalog to ants phone over current adb connection (USB or tcpip).
# Usage: antphone_deploy_local.sh [apk...] 
# Always pushes tools/catalog.json
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="$ROOT/tools/catalog.json"
adb devices | grep -q $'\tdevice$' || { echo "no adb device — run antphone_lan_connect.sh"; exit 1; }

adb shell mkdir -p /sdcard/AntPhone
adb push "$CATALOG" /sdcard/AntPhone/catalog.json
# World-readable fallback — launcher often cannot read /sdcard (scoped storage).
adb push "$CATALOG" /data/local/tmp/antphone_catalog.json
adb shell chmod 644 /data/local/tmp/antphone_catalog.json || true

for apk in "$@"; do
  [[ -f "$apk" ]] || { echo "missing $apk"; exit 1; }
  echo "installing $apk"
  adb install -r -g "$apk"
done

adb shell am task lock stop 2>/dev/null || true
adb shell am force-stop com.dylan.antexplorer || true
adb shell am start -n com.dylan.antexplorer/.MainActivity || \
  adb shell am start -a android.intent.action.MAIN -c android.intent.category.HOME
sleep 1
# Enterprise lock-task is started by MainActivity when device-owner whitelist is set.
# Do not use `am task lock` — that is consumer screen pinning ("App is pinned" tab).
adb shell dumpsys activity activities | grep -E 'topResumedActivity|mLockTaskModeState' | head -5 || true
echo "deploy ok"
