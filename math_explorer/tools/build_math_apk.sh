#!/usr/bin/env bash
# Build com.dylan.math_explorer.apk (Godot pack -> Android assets + gradle) and sign it.
# Mirrors solar_system_explorer/tools/build_solar_apk.sh. The gradle template in
# game/android/build was copied from solar (same Godot 4.3 android build template).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
BUILD="$GAME/android/build"
ASSETS="$BUILD/assets"
OUT="$ROOT/tools/build/com.dylan.math_explorer.apk"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
KS="${ANTS_KEYSTORE:-$HOME/moto_fogona_backup/ants-debug.keystore}"
BT="${ANDROID_HOME:-$HOME/Android/Sdk}/build-tools/36.0.0"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"

mkdir -p "$ROOT/tools/build"

echo "=== export .pck ==="
"$GODOT" --headless --path "$GAME" --export-pack "Android" /tmp/math.pck

echo "=== sync tracked Android overlay into Godot template ==="
# android/build is the huge export template (gitignored). Keep our activity in
# android_src/ so the kiosk's EXTRA_WIPE_SAVE "Start over" reaches this title.
OVERLAY_APP="$GAME/android_src/com/godot/game/GodotApp.java"
TEMPLATE_APP="$BUILD/src/com/godot/game/GodotApp.java"
if [[ -f "$OVERLAY_APP" ]]; then
  mkdir -p "$(dirname "$TEMPLATE_APP")"
  cp -f "$OVERLAY_APP" "$TEMPLATE_APP"
fi

echo "=== unpack pck into gradle assets/ (official Android layout) ==="
find "$ASSETS" -mindepth 1 -maxdepth 1 ! -name 'dexopt' -exec rm -rf {} +
python3 "$ROOT/../ant_explorer/tools/unpack_godot_pck.py" /tmp/math.pck "$ASSETS"

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
  -Pexport_package_name=com.dylan.math_explorer \
  -Pexport_version_code=1 \
  -Pexport_version_name=0.1 \
  -Pexport_enabled_abis=arm64-v8a \
  -Prelease_keystore_file="$KS" \
  -Prelease_keystore_alias=ants \
  -Prelease_keystore_password=antsdebug \
  -Pgodot_editor_version=4.3.stable

RAW="$BUILD/build/outputs/apk/release/android_release.apk"
ALIGNED=/tmp/math_aligned.apk
SIGNED=/tmp/math_signed.apk
rm -f "$ALIGNED" "$SIGNED"
"$BT/zipalign" -f -p 4 "$RAW" "$ALIGNED"
"$BT/apksigner" sign --ks "$KS" --ks-key-alias ants \
  --ks-pass pass:antsdebug --key-pass pass:antsdebug \
  --out "$SIGNED" "$ALIGNED"
"$BT/apksigner" verify "$SIGNED"
cp -f "$SIGNED" "$OUT"
echo "OK $OUT ($(du -h "$OUT" | awk '{print $1}'))"
