#!/usr/bin/env bash
# Build com.dylan.antexplorer.solar.apk (Godot pack -> Android assets + gradle) and sign it.
# Mirrors ant_explorer/tools/build_colony_apk.sh. Run AFTER installing the Godot
# Android build template into game/ once (editor: Project > Install Android Build Template),
# and after adding an "Android" export preset in game/export_presets.cfg.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
BUILD="$GAME/android/build"
ASSETS="$BUILD/assets"
OUT="$ROOT/tools/build/com.dylan.antexplorer.solar.apk"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
KS="${ANTS_KEYSTORE:-$HOME/moto_fogona_backup/ants-debug.keystore}"
BT="${ANDROID_HOME:-$HOME/Android/Sdk}/build-tools/36.0.0"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"

mkdir -p "$ROOT/tools/build"

echo "=== export .pck ==="
"$GODOT" --headless --path "$GAME" --export-pack "Android" /tmp/solar.pck

echo "=== unpack pck into gradle assets/ (official Android layout) ==="
find "$ASSETS" -mindepth 1 -maxdepth 1 ! -name 'dexopt' -exec rm -rf {} +
python3 "$ROOT/../ant_explorer/tools/unpack_godot_pck.py" /tmp/solar.pck "$ASSETS"

echo "=== write assets/_cl_ (argc=0) ==="
python3 - "$ASSETS/_cl_" <<'PY'
import struct, sys
from pathlib import Path
Path(sys.argv[1]).write_bytes(struct.pack("<I", 0))
PY

echo "=== gradle assembleRelease ==="
cd "$BUILD"
chmod +x gradlew
./gradlew assembleRelease --no-daemon \
  -Pexport_package_name=com.dylan.antexplorer.solar \
  -Pexport_version_code=1 \
  -Pexport_version_name=0.1 \
  -Pexport_enabled_abis=arm64-v8a \
  -Prelease_keystore_file="$KS" \
  -Prelease_keystore_alias=ants \
  -Prelease_keystore_password=antsdebug \
  -Pgodot_editor_version=4.3.stable

RAW="$BUILD/build/outputs/apk/release/android_release.apk"
ALIGNED=/tmp/solar_aligned.apk
SIGNED=/tmp/solar_signed.apk
rm -f "$ALIGNED" "$SIGNED"
"$BT/zipalign" -f -p 4 "$RAW" "$ALIGNED"
"$BT/apksigner" sign --ks "$KS" --ks-key-alias ants \
  --ks-pass pass:antsdebug --key-pass pass:antsdebug \
  --out "$SIGNED" "$ALIGNED"
"$BT/apksigner" verify "$SIGNED"
cp -f "$SIGNED" "$OUT"
echo "OK $OUT ($(du -h "$OUT" | awk '{print $1}'))"
