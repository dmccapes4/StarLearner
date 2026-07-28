#!/usr/bin/env bash
# Copy full_deploy bundle to 245 Windows OTA staging and regenerate manifest.json.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="${1:-$ROOT/ant_explorer/tools/build/full_deploy}"
STAGING="/mnt/c/Users/dylan/antphone/staging"
MAKE_MANIFEST="/mnt/c/Users/dylan/antphone/server/make_manifest.sh"

[[ -d "$BUNDLE/apks" ]] || { echo "ERROR: bundle apks missing: $BUNDLE/apks" >&2; exit 1; }
[[ -f "$BUNDLE/catalog.json" ]] || { echo "ERROR: catalog.json missing in bundle" >&2; exit 1; }

mkdir -p "$STAGING/videos"
cp -f "$BUNDLE/catalog.json" "$STAGING/catalog.json"
cp -f "$BUNDLE/apks/"*.apk "$STAGING/"
if [[ -d "$BUNDLE/videos" ]]; then
  cp -f "$BUNDLE/videos/"*.mp4 "$STAGING/videos/" 2>/dev/null || true
fi

if [[ -x "$MAKE_MANIFEST" ]] || [[ -f "$MAKE_MANIFEST" ]]; then
  bash "$MAKE_MANIFEST"
else
  echo "WARNING: $MAKE_MANIFEST not found; manifest not regenerated" >&2
fi
echo "OTA staging: C:\\Users\\dylan\\antphone\\staging"
