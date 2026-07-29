#!/usr/bin/env bash
# Build on 82 → SCP bundle → deploy fogona on 245 USB (Windows adb.exe).
#
#   ./tools/full_deploy.sh --prepare-only
#   ./tools/deploy_via_245.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="${BUNDLE:-$ROOT/ant_explorer/tools/build/full_deploy}"
HOST="${STARLEARNER_245_HOST:-dylan@104.53.183.230}"
PORT="${STARLEARNER_245_PORT:-2222}"
KEY="${STARLEARNER_245_KEY:-$HOME/.ssh/id_ed25519}"
SERIAL="${STARLEARNER_FOGONA_SERIAL:-ZL8326G8ND}"
REMOTE_WIN='C:\Users\dylan\antphone\full_deploy'

[[ -s "$BUNDLE/SHA256SUMS" ]] || {
  echo "Missing bundle; run ./tools/full_deploy.sh --prepare-only first" >&2
  exit 1
}

SSH=(ssh -o BatchMode=yes -o IdentitiesOnly=yes -i "$KEY" -p "$PORT" "$HOST")
SCP=(scp -o BatchMode=yes -o IdentitiesOnly=yes -i "$KEY" -P "$PORT")

echo "=== Transfer bundle to 245 ($(du -sh "$BUNDLE" | awk '{print $1}')) ==="
"${SSH[@]}" "if exist $REMOTE_WIN rmdir /S /Q $REMOTE_WIN"
"${SCP[@]}" -r "$BUNDLE" "$HOST:C:/Users/dylan/antphone/"
for script in deploy_fogona_on_245.sh full_deploy.sh validate_deploy.sh \
  uninstall_legacy_packages.sh migrate_device_owner.sh adb_helpers.sh \
  finish_fogona_deploy.sh run_all_validation.sh publish_ota_staging.sh packages.sh; do
  "${SCP[@]}" "$ROOT/tools/$script" "$HOST:C:/Users/dylan/dev/star_learning/tools/$script"
done
"${SCP[@]}" "$ROOT/language_explorer/tools/voice_smoke_test.sh" \
  "$HOST:C:/Users/dylan/dev/star_learning/language_explorer/tools/voice_smoke_test.sh"

echo "=== Deploy fogona ($SERIAL) ==="
"${SSH[@]}" "wsl -e bash /mnt/c/Users/dylan/dev/star_learning/tools/deploy_fogona_on_245.sh $SERIAL"

echo "DEPLOY VIA 245 OK"
