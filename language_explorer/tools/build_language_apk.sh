#!/usr/bin/env bash
# Build and sign com.dylan.antexplorer.language.apk.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
BUILD="$GAME/android/build"
ASSETS="$BUILD/assets"
OUT="$ROOT/tools/build/com.dylan.antexplorer.language.apk"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
KS="${ANTS_KEYSTORE:-$HOME/moto_fogona_backup/ants-debug.keystore}"
BT="${ANDROID_HOME:-$HOME/Android/Sdk}/build-tools/36.0.0"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"

mkdir -p "$ROOT/tools/build"

if [[ ! -x "$BUILD/gradlew" ]]; then
  echo "ERROR: Godot Android template missing at $BUILD" >&2
  echo "Install the Godot 4.3 Android build template, or copy a sibling title's game/android/build." >&2
  exit 1
fi

echo "=== export .pck ==="
"$GODOT" --headless --path "$GAME" --export-pack "Android" /tmp/language.pck

echo "=== sync GodotApp wipe/back overlay ==="
OVERLAY_APP="$GAME/android_src/com/godot/game/GodotApp.java"
TEMPLATE_APP="$BUILD/src/com/godot/game/GodotApp.java"
mkdir -p "$(dirname "$TEMPLATE_APP")"
cp -f "$OVERLAY_APP" "$TEMPLATE_APP"

echo "=== unpack pck into gradle assets/ ==="
find "$ASSETS" -mindepth 1 -maxdepth 1 ! -name 'dexopt' -exec rm -rf {} +
python3 "$ROOT/../ant_explorer/tools/unpack_godot_pck.py" /tmp/language.pck "$ASSETS"
python3 - "$ASSETS/_cl_" <<'PY'
import struct, sys
from pathlib import Path
Path(sys.argv[1]).write_bytes(struct.pack("<I", 0))
PY

echo "=== hub ASR assets (production token + pinned cert) ==="
HUB_SECRETS="${HUB_SECRETS:-$ROOT/../ant_explorer/tools/secrets/hub245}"
HUB_DATA="$ASSETS/data"
mkdir -p "$HUB_DATA"
HUB_DEV="${STARLEARNER_HUB_DEV:-0}"
if [[ "$HUB_DEV" == "1" ]]; then
  python3 "$ROOT/tools/render_hub_client.py" \
    --out "$HUB_DATA/hub_client.json" \
    --token-file "$HUB_SECRETS/token.txt" \
    --dev
elif [[ -f "$HUB_SECRETS/token.txt" ]]; then
  python3 "$ROOT/tools/render_hub_client.py" \
    --out "$HUB_DATA/hub_client.json" \
    --token-file "$HUB_SECRETS/token.txt"
else
  echo "ERROR: missing $HUB_SECRETS/token.txt (hub245 ASR token for production APK)" >&2
  echo "Copy hub245 secrets to that path on 245, or set STARLEARNER_HUB_DEV=1 for LAN dev bases." >&2
  exit 1
fi
if [[ -f "$HUB_SECRETS/hub.crt" ]]; then
  cp -f "$HUB_SECRETS/hub.crt" "$HUB_DATA/hub.crt"
elif [[ -f "$GAME/data/hub.crt" ]]; then
  cp -f "$GAME/data/hub.crt" "$HUB_DATA/hub.crt"
else
  echo "ERROR: missing hub.crt (expected $HUB_SECRETS/hub.crt or game/data/hub.crt)" >&2
  exit 1
fi

echo "=== gradle assembleRelease ==="
cd "$BUILD"
chmod +x gradlew
./gradlew assembleRelease --no-daemon \
  -Pexport_package_name=com.dylan.antexplorer.language \
  -Pexport_version_code=1 \
  -Pexport_version_name=1.0 \
  -Pexport_enabled_abis=arm64-v8a \
  -Prelease_keystore_file="$KS" \
  -Prelease_keystore_alias=ants \
  -Prelease_keystore_password=antsdebug \
  -Pgodot_editor_version=4.3.stable

RAW="$BUILD/build/outputs/apk/release/android_release.apk"
ALIGNED=/tmp/language_aligned.apk
SIGNED=/tmp/language_signed.apk
rm -f "$ALIGNED" "$SIGNED"
"$BT/zipalign" -f -p 4 "$RAW" "$ALIGNED"
"$BT/apksigner" sign --ks "$KS" --ks-key-alias ants \
  --ks-pass pass:antsdebug --key-pass pass:antsdebug \
  --out "$SIGNED" "$ALIGNED"
"$BT/apksigner" verify "$SIGNED"
cp -f "$SIGNED" "$OUT"
echo "OK $OUT ($(du -h "$OUT" | awk '{print $1}'))"
