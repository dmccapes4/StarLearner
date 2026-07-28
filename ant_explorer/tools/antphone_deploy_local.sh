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

# Explainer videos for the ▶ chips under kiosk tiles (catalog "video" field).
STAR="$(cd "$ROOT/.." && pwd)"
VIDEOS=(
  "$ROOT/docs/demo/ant_explorer_explainer.mp4"
  "$STAR/solar_system_explorer/docs/demo/solar_system_explorer_explainer.mp4"
  "$STAR/math_explorer/docs/demo/math_explorer_explainer.mp4"
  "$STAR/garden_explorer/docs/demo/garden_explorer_explainer.mp4"
  "$STAR/language_explorer/docs/demo/language_explorer_explainer.mp4"
)
adb shell mkdir -p /sdcard/AntPhone/videos /data/local/tmp/antphone_videos
for v in "${VIDEOS[@]}"; do
  [[ -f "$v" ]] || { echo "skip missing video $v"; continue; }
  adb push "$v" "/sdcard/AntPhone/videos/$(basename "$v")"
  adb push "$v" "/data/local/tmp/antphone_videos/$(basename "$v")"
  adb shell chmod 644 "/data/local/tmp/antphone_videos/$(basename "$v")" || true
done

# Prefer the gradle release kiosk build over a stale tools/build copy.
# An old launcher APK lacks tile_solar/tile_math and falls back to tile_ants for every tile.
KIOSK_RELEASE="$ROOT/kiosk_placeholder/app/build/outputs/apk/release/app-release.apk"
for apk in "$@"; do
  [[ -f "$apk" ]] || { echo "missing $apk"; exit 1; }
  base="$(basename "$apk")"
  if [[ "$base" == "com.dylan.star_learner.apk" && -f "$KIOSK_RELEASE" ]]; then
    if [[ "$KIOSK_RELEASE" -nt "$apk" ]]; then
      echo "refreshing stale kiosk APK from $KIOSK_RELEASE"
      mkdir -p "$(dirname "$apk")"
      cp -f "$KIOSK_RELEASE" "$apk"
    fi
  fi
  echo "installing $apk"
  adb install -r -g "$apk"
done

adb shell am task lock stop 2>/dev/null || true
adb shell am force-stop com.dylan.star_learner || true
adb shell am start -n com.dylan.star_learner/.MainActivity || \
  adb shell am start -a android.intent.action.MAIN -c android.intent.category.HOME
sleep 1
# Enterprise lock-task is started by MainActivity when device-owner whitelist is set.
# Do not use `am task lock` — that is consumer screen pinning ("App is pinned" tab).
adb shell dumpsys activity activities | grep -E 'topResumedActivity|mLockTaskModeState' | head -5 || true
echo "deploy ok"
