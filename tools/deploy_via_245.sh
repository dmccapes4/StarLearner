#!/usr/bin/env bash
# DEPRECATED: SCP bundle from 82 → 245. Use 245-native build instead:
#   On 245 WSL: ./tools/full_deploy_245.sh
#   From 82:    ssh -p 2222 … 'cd ~/dev/star_learning && git pull && ./tools/full_deploy_245.sh'
#
# Legacy: transfer a pre-built bundle from 82 and deploy to fogona USB.
set -euo pipefail

echo "WARNING: deploy_via_245.sh is deprecated — prefer full_deploy_245.sh on 245 after git pull" >&2
sleep 2

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="${BUNDLE:-$ROOT/ant_explorer/tools/build/full_deploy}"
HOST="${STARLEARNER_245_HOST:-dylan@104.53.183.230}"
PORT="${STARLEARNER_245_PORT:-2222}"
KEY="${STARLEARNER_245_KEY:-$HOME/.ssh/id_ed25519}"
SERIAL="${STARLEARNER_FOGONA_SERIAL:-ZL8326G8ND}"
REMOTE_WIN='C:\Users\dylan\antphone\full_deploy'
REMOTE_WSL='/mnt/c/Users/dylan/antphone/full_deploy'
WIN_ADB='C:\Users\dylan\Android\platform-tools\adb.exe'

[[ -s "$BUNDLE/SHA256SUMS" ]] || {
  echo "Missing bundle; run ./tools/full_deploy.sh --prepare-only first" >&2
  exit 1
}

SSH=(ssh -o BatchMode=yes -o IdentitiesOnly=yes -i "$KEY" -p "$PORT" "$HOST")
SCP=(scp -o BatchMode=yes -o IdentitiesOnly=yes -i "$KEY" -P "$PORT")

echo "=== Transfer validated bundle to 245 ==="
"${SSH[@]}" "if exist $REMOTE_WIN rmdir /S /Q $REMOTE_WIN"
"${SCP[@]}" -r "$BUNDLE" "$HOST:C:/Users/dylan/antphone/"

echo "=== Start temporary Windows adb bridge for WSL ==="
"${SSH[@]}" "$WIN_ADB kill-server & wmic process call create \"$WIN_ADB -a -P 5037 nodaemon server\" >nul & ping -n 3 127.0.0.1 >nul"
GATEWAY="$("${SSH[@]}" "wsl -e sh -c \"ip route show default | cut -d' ' -f3\"" |
  tr -d '\r' | tail -1)"
[[ -n "$GATEWAY" ]] || { echo "Could not determine WSL gateway" >&2; exit 1; }

cleanup() {
  "${SSH[@]}" "$WIN_ADB kill-server" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "=== Deploy 245 -> fogona ($SERIAL) ==="
"${SSH[@]}" "wsl -e env ADB_SERVER_SOCKET=tcp:$GATEWAY:5037 bash $REMOTE_WSL/full_deploy.sh --deploy-only --bundle $REMOTE_WSL --adb /usr/bin/adb --serial $SERIAL --require-kiosk"

echo "=== Publish identical artifacts to 245 OTA staging ==="
"${SSH[@]}" "copy /Y $REMOTE_WIN\\apks\\*.apk C:\\Users\\dylan\\antphone\\staging\\ >nul & copy /Y $REMOTE_WIN\\catalog.json C:\\Users\\dylan\\antphone\\staging\\catalog.json >nul & if not exist C:\\Users\\dylan\\antphone\\staging\\videos mkdir C:\\Users\\dylan\\antphone\\staging\\videos & copy /Y $REMOTE_WIN\\videos\\*.mp4 C:\\Users\\dylan\\antphone\\staging\\videos\\ >nul & wsl -e bash /mnt/c/Users/dylan/antphone/server/make_manifest.sh"

echo "245 FULL DEPLOY + OTA PUBLISH OK"
