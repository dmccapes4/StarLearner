#!/usr/bin/env bash
# Full build + deploy on 245 WSL → fogona USB (ZL8326G8ND). Run ON 245 after git pull.
#
# Uses Windows adb.exe directly (WSL→Windows TCP bridge at 192.168.64.1:5037 is unreliable).
#
# Prerequisites on 245 WSL (/mnt/c/Users/dylan/dev/star_learning):
#   - GODOT, JDK 17, Android SDK (see tools/245_env.sh)
#   - Windows adb: C:\Users\dylan\Android\platform-tools\adb.exe
#   - hub245 secrets: ant_explorer/tools/secrets/hub245/{token.txt,hub.crt}
#   - fogona USB on 245 Windows host
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=245_env.sh
[[ -f "$ROOT/tools/245_env.sh" ]] && source "$ROOT/tools/245_env.sh"

FOGONA_SERIAL="${FOGONA_SERIAL:-ZL8326G8ND}"
WIN_ADB="${WIN_ADB:-/mnt/c/Users/dylan/Android/platform-tools/adb.exe}"
export ADB="$WIN_ADB"

if [[ "${SKIP_GIT_PULL:-0}" != "1" ]]; then
  echo "=== git pull ==="
  git pull --ff-only
fi

[[ -x "$WIN_ADB" ]] || { echo "ERROR: WIN_ADB not found: $WIN_ADB" >&2; exit 1; }

echo "=== Windows adb ($WIN_ADB) ==="
"$WIN_ADB" devices -l
if ! "$WIN_ADB" devices | awk 'NR>1 && $1 ~ /^[0-9A-Z]+$/ {found=1} END{exit !found}'; then
  echo "ERROR: no adb device via Windows adb.exe" >&2
  exit 1
fi

echo "=== hub245 secrets ==="
HUB_SEC="$ROOT/ant_explorer/tools/secrets/hub245"
for f in token.txt hub.crt; do
  [[ -f "$HUB_SEC/$f" ]] || {
    echo "ERROR: missing $HUB_SEC/$f — copy from 82 secrets before production deploy" >&2
    exit 1
  }
done

echo "=== bootstrap Godot Android templates ==="
"$ROOT/tools/bootstrap_godot_android.sh"

echo "=== legacy package cleanup ==="
"$ROOT/tools/uninstall_legacy_packages.sh" "$FOGONA_SERIAL" || true

echo "=== full deploy fogona ==="
"$ROOT/tools/full_deploy.sh" --adb "$WIN_ADB" --serial "$FOGONA_SERIAL" --require-kiosk

echo "=== validate ==="
REQUIRE_HUB_ASR=1 "$ROOT/tools/run_all_validation.sh" "$FOGONA_SERIAL"

echo "=== OTA staging ==="
"$ROOT/tools/publish_ota_staging.sh"

echo "FULL DEPLOY 245 OK ($FOGONA_SERIAL)"
