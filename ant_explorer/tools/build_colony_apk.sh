#!/usr/bin/env bash
# Build com.dylan.ant_explorer.apk (Godot pack → Android assets + gradle) and sign it.
#
# Godot's Android loader does NOT open assets/main.pck. Official export writes each
# res:// file into assets/ (project.binary, .godot/..., etc.) and an empty-ish _cl_.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
BUILD="$GAME/android/build"
ASSETS="$BUILD/assets"
OUT="$ROOT/tools/build/com.dylan.ant_explorer.apk"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
KS="${ANTS_KEYSTORE:-$HOME/moto_fogona_backup/ants-debug.keystore}"
BT="${ANDROID_HOME:-$HOME/Android/Sdk}/build-tools/36.0.0"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"

mkdir -p "$ROOT/tools/build"

echo "=== export .pck ==="
"$GODOT" --headless --path "$GAME" --export-pack "Android" /tmp/ant_colony.pck

echo "=== sync tracked Android overlay into Godot template ==="
# android/build is the huge export template (gitignored). Keep our activity in android_src/.
OVERLAY_APP="$GAME/android_src/com/godot/game/GodotApp.java"
TEMPLATE_APP="$BUILD/src/com/godot/game/GodotApp.java"
if [[ -f "$OVERLAY_APP" ]]; then
  mkdir -p "$(dirname "$TEMPLATE_APP")"
  cp -f "$OVERLAY_APP" "$TEMPLATE_APP"
fi

echo "=== unpack pck into gradle assets/ (official Android layout) ==="
# Keep only non-game junk out; wipe previous game assets.
find "$ASSETS" -mindepth 1 -maxdepth 1 ! -name 'dexopt' -exec rm -rf {} +
python3 "$ROOT/tools/unpack_godot_pck.py" /tmp/ant_colony.pck "$ASSETS"

echo "=== write assets/_cl_ (argc=0) ==="
python3 - <<'PY'
import struct
from pathlib import Path
Path("/home/dylanmccapes/dev/star_learning/ant_explorer/game/android/build/assets/_cl_").write_bytes(
    struct.pack("<I", 0)
)
PY

# Match Godot template: do not ignore hidden assets (.godot/...), keep pck uncompressed if present.
# (noCompress 'pck' is harmless; primary payload is loose files now.)

echo "=== gradle assembleRelease ==="
cd "$BUILD"
chmod +x gradlew
./gradlew assembleRelease --no-daemon \
  -Pexport_package_name=com.dylan.ant_explorer \
  -Pexport_version_code=28 \
  -Pexport_version_name=0.28 \
  -Pexport_enabled_abis=arm64-v8a \
  -Prelease_keystore_file="$KS" \
  -Prelease_keystore_alias=ants \
  -Prelease_keystore_password=antsdebug \
  -Pgodot_editor_version=4.3.stable

RAW="$BUILD/build/outputs/apk/release/android_release.apk"
ALIGNED=/tmp/colony_aligned.apk
SIGNED=/tmp/colony_signed.apk
rm -f "$ALIGNED" "$SIGNED"
"$BT/zipalign" -f -p 4 "$RAW" "$ALIGNED"
"$BT/apksigner" sign --ks "$KS" --ks-key-alias ants \
  --ks-pass pass:antsdebug --key-pass pass:antsdebug \
  --out "$SIGNED" "$ALIGNED"
"$BT/apksigner" verify "$SIGNED"
cp -f "$SIGNED" "$OUT"

python3 - <<PY
import zipfile
z=zipfile.ZipFile("$OUT")
names=z.namelist()
print("has project.binary", any(n.endswith("project.binary") for n in names))
print("has main.pck", any(n.endswith("main.pck") for n in names))
print("sample assets", [n for n in names if n.startswith("assets/") and not n.endswith("/")][:8])
print("asset file count", sum(1 for n in names if n.startswith("assets/") and not n.endswith("/")))
PY
echo "OK $OUT ($(du -h "$OUT" | awk '{print $1}'))"
