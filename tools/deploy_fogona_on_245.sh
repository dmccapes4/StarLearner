#!/usr/bin/env bash
# Run on 245 WSL after bundle SCP. Invoked by deploy_via_245.sh from 82.
set -euo pipefail
BUNDLE=/mnt/c/Users/dylan/antphone/full_deploy
REPO=/mnt/c/Users/dylan/dev/star_learning
ADB=/mnt/c/Users/dylan/Android/platform-tools/adb.exe
SERIAL="${1:-ZL8326G8ND}"
export ADB

[[ -x "$ADB" ]] || { echo "ERROR: $ADB missing" >&2; exit 1; }
[[ -d "$BUNDLE/apks" ]] || { echo "ERROR: bundle missing" >&2; exit 1; }

"$ADB" devices -l

if [[ -d "$REPO/.git" ]]; then
  git -C "$REPO" pull --ff-only origin master 2>/dev/null || true
  "$REPO/tools/migrate_device_owner.sh" "$SERIAL" || true
  "$REPO/tools/uninstall_legacy_packages.sh" "$SERIAL" || true
  "$REPO/tools/full_deploy.sh" --deploy-only --bundle "$BUNDLE" --adb "$ADB" --serial "$SERIAL" --require-kiosk
  "$REPO/tools/finish_fogona_deploy.sh" "$SERIAL"
else
  "$BUNDLE/full_deploy.sh" --deploy-only --bundle "$BUNDLE" --adb "$ADB" --serial "$SERIAL" --require-kiosk
  bash /mnt/c/Users/dylan/antphone/server/make_manifest.sh
fi

echo "FOGONA DEPLOY OK"
