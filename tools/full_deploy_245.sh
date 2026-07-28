#!/usr/bin/env bash
# Full build + deploy on 245 WSL → fogona USB (ZL8326G8ND). Run ON 245 after git pull.
#
# Prerequisites on 245:
#   - WSL repo at ~/dev/star_learning (or STARLEARNER_ROOT)
#   - Windows adb at C:\Users\dylan\Android\platform-tools\adb.exe
#   - hub245 secrets: ant_explorer/tools/secrets/hub245/{token.txt,hub.crt}
#   - fogona USB attached to 245 Windows host
#
# Workflow (from 82):
#   1. ./tools/full_deploy.sh --serial ZL8326FWKM && ./tools/validate_deploy.sh ZL8326FWKM
#   2. git push
#   3. ssh 245 'cd ~/dev/star_learning && git pull && ./tools/full_deploy_245.sh'
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=245_env.sh
[[ -f "$ROOT/tools/245_env.sh" ]] && source "$ROOT/tools/245_env.sh"

FOGONA_SERIAL="${FOGONA_SERIAL:-ZL8326G8ND}"
WIN_ADB="${WIN_ADB:-/mnt/c/Users/dylan/Android/platform-tools/adb.exe}"
GATEWAY="$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}')"
[[ -n "$GATEWAY" ]] || { echo "ERROR: no default route (WSL gateway?)" >&2; exit 1; }

if [[ "${SKIP_GIT_PULL:-0}" != "1" ]]; then
  echo "=== git pull ==="
  git pull --ff-only
fi

echo "=== Windows adb bridge ($GATEWAY:5037) ==="
if [[ ! -x "$WIN_ADB" ]]; then
  echo "ERROR: WIN_ADB not found: $WIN_ADB" >&2
  exit 1
fi
"$WIN_ADB" kill-server 2>/dev/null || true
"$WIN_ADB" -a -P 5037 nodaemon server &
BRIDGE_PID=$!
sleep 2
export ADB_SERVER_SOCKET="tcp:${GATEWAY}:5037"
trap '"$WIN_ADB" kill-server 2>/dev/null; kill $BRIDGE_PID 2>/dev/null' EXIT

adb devices -l
if ! adb devices | awk 'NR>1 && $1 ~ /^[0-9A-Z]+$/ {found=1} END{exit !found}'; then
  echo "ERROR: no adb device via Windows bridge" >&2
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

echo "=== full deploy fogona ==="
"$ROOT/tools/full_deploy.sh" --serial "$FOGONA_SERIAL" --require-kiosk

echo "=== validate ==="
REQUIRE_HUB_ASR=1 "$ROOT/tools/run_all_validation.sh" "$FOGONA_SERIAL"

echo "=== OTA staging ==="
"$ROOT/tools/publish_ota_staging.sh"

echo "FULL DEPLOY 245 OK ($FOGONA_SERIAL)"
