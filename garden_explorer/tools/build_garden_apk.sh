#!/usr/bin/env bash
# Build com.dylan.antexplorer.garden.apk (Godot pack → Android assets + gradle).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
BUILD="$GAME/android/build"
ASSETS="$BUILD/assets"
OUT="$ROOT/tools/build/com.dylan.antexplorer.garden.apk"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
KS="${ANTS_KEYSTORE:-$HOME/moto_fogona_backup/ants-debug.keystore}"
BT="${ANDROID_HOME:-$HOME/Android/Sdk}/build-tools/36.0.0"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"

mkdir -p "$ROOT/tools/build"

echo "=== export .pck ==="
"$GODOT" --headless --path "$GAME" --export-pack "Android" /tmp/garden.pck

echo "=== sync GodotApp wipe overlay ==="
OVERLAY_APP="$GAME/android_src/com/godot/game/GodotApp.java"
TEMPLATE_APP="$BUILD/src/com/godot/game/GodotApp.java"
if [[ -f "$OVERLAY_APP" ]]; then
  mkdir -p "$(dirname "$TEMPLATE_APP")"
  cp -f "$OVERLAY_APP" "$TEMPLATE_APP"
fi

echo "=== unpack pck into gradle assets/ ==="
find "$ASSETS" -mindepth 1 -maxdepth 1 ! -name 'dexopt' -exec rm -rf {} +
python3 "$ROOT/../ant_explorer/tools/unpack_godot_pck.py" /tmp/garden.pck "$ASSETS"

## Mana Seed crop PNGs are gitignored / may lack .import — force-copy into APK assets.
MANA_SRC="$GAME/assets/tiles/mana_seed_crops"
MANA_DST="$ASSETS/assets/tiles/mana_seed_crops"
if [[ -d "$MANA_SRC/crops" ]]; then
  mkdir -p "$MANA_DST"
  rsync -a --delete "$MANA_SRC/" "$MANA_DST/"
  echo "Mana Seed crops → $MANA_DST ($(find "$MANA_DST/crops" -name '*.png' | wc -l) sheets)"
fi

## Gardener avatar (may lack .import) — force into APK assets.
CHAR_SRC="$GAME/assets/characters"
CHAR_DST="$ASSETS/assets/characters"
if [[ -d "$CHAR_SRC" ]]; then
  mkdir -p "$CHAR_DST"
  rsync -a "$CHAR_SRC/" "$CHAR_DST/"
  echo "Characters → $CHAR_DST ($(find "$CHAR_DST" -name '*.png' | wc -l) png)"
fi

## Animals / shed / SFX (may lack .import)
for pair in \
  "animals:animals" \
  "buildings:buildings" \
  "audio/animals:audio/animals" \
  "ui:ui"; do
  SRC_REL="${pair%%:*}"
  DST_REL="${pair##*:}"
  SRC="$GAME/assets/$SRC_REL"
  DST="$ASSETS/assets/$DST_REL"
  if [[ -d "$SRC" ]]; then
    mkdir -p "$DST"
    rsync -a --exclude '_dl' "$SRC/" "$DST/"
    echo "$SRC_REL → $DST"
  fi
done

python3 - "$ASSETS/_cl_" <<'PY'
import struct, sys
from pathlib import Path
Path(sys.argv[1]).write_bytes(struct.pack("<I", 0))
PY

echo "=== gradle assembleRelease ==="
cd "$BUILD"
chmod +x gradlew
./gradlew assembleRelease --no-daemon \
  -Pexport_package_name=com.dylan.antexplorer.garden \
  -Pexport_version_code=1 \
  -Pexport_version_name=0.1 \
  -Pexport_enabled_abis=arm64-v8a \
  -Prelease_keystore_file="$KS" \
  -Prelease_keystore_alias=ants \
  -Prelease_keystore_password=antsdebug \
  -Pgodot_editor_version=4.3.stable

RAW="$BUILD/build/outputs/apk/release/android_release.apk"
ALIGNED=/tmp/garden_aligned.apk
SIGNED=/tmp/garden_signed.apk
rm -f "$ALIGNED" "$SIGNED"
"$BT/zipalign" -f -p 4 "$RAW" "$ALIGNED"
"$BT/apksigner" sign --ks "$KS" --ks-key-alias ants \
  --ks-pass pass:antsdebug --key-pass pass:antsdebug \
  --out "$SIGNED" "$ALIGNED"
"$BT/apksigner" verify "$SIGNED"
cp -f "$SIGNED" "$OUT"
echo "OK $OUT ($(du -h "$OUT" | awk '{print $1}'))"
