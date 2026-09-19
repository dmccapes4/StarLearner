#!/usr/bin/env bash
# Clear legacy com.dylan.antexplorer device owner (rooted fogona), uninstall legacy
# packages, set com.dylan.star_learner device owner, and re-enable kiosk.
set -euo pipefail

SERIAL="${1:-${ADB_SERIAL:-ZL8326G8ND}}"
ADB_BIN="${ADB:-adb}"
LEGACY=com.dylan.antexplorer
NEW=com.dylan.star_learner
ADB=("$ADB_BIN")
[[ -n "$SERIAL" ]] && ADB+=(-s "$SERIAL")

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() { echo "ERROR: $*" >&2; exit 1; }

"${ADB[@]}" devices | tr -d '\r' | awk 'NR>1 && $2=="device" {found=1} END{exit !found}' ||
  die "no adb device"

echo "=== stop lock-task ==="
"${ADB[@]}" shell am task lock stop 2>/dev/null || true
"${ADB[@]}" shell am force-stop "$LEGACY" 2>/dev/null || true
"${ADB[@]}" shell am force-stop "$NEW" 2>/dev/null || true

if "${ADB[@]}" shell dpm list-owners | tr -d '\r' | grep -q "$LEGACY"; then
  echo "=== clear legacy device owner via root ==="
  "${ADB[@]}" shell su -c id | grep -q 'uid=0' ||
    die "root required to clear legacy device owner"
  "${ADB[@]}" shell su -c \
    'rm -f /data/system/device_owner_2.xml /data/system/device_policies.xml /data/system/device_policies_version /data/system/users/0/device_policies.xml'
  echo "rebooting to drop legacy device owner ..."
  "${ADB[@]}" reboot
  "${ADB[@]}" wait-for-device
  sleep 25
  timeout 120 bash -c "until [[ \"\$(${ADB[*]} get-state 2>/dev/null | tr -d '\r')\" == device ]]; do sleep 2; done"
fi

echo "=== uninstall legacy packages ==="
export ADB="$ADB_BIN"
"$ROOT/tools/uninstall_legacy_packages.sh" "$SERIAL" || true

echo "=== set new device owner ==="
if ! "${ADB[@]}" shell dpm list-owners | tr -d '\r' | grep -q "$NEW"; then
  "${ADB[@]}" shell dpm set-device-owner "$NEW/.AdminReceiver"
fi
"${ADB[@]}" shell dpm list-owners | tr -d '\r'

echo "=== kiosk settings ==="
"${ADB[@]}" shell settings put system user_rotation 1
"${ADB[@]}" shell settings put system accelerometer_rotation 0
"${ADB[@]}" shell settings put global policy_control immersive.full='*'
"${ADB[@]}" shell settings put global stay_on_while_plugged_in 3
"${ADB[@]}" shell settings put system screen_brightness_mode 0
"${ADB[@]}" shell settings put system screen_brightness 220
"${ADB[@]}" shell settings put secure lock_to_app_enabled 1
"${ADB[@]}" shell settings put secure lock_to_app_exit_locked 0
"${ADB[@]}" shell settings put secure lockscreen.disabled 1 2>/dev/null || true
"${ADB[@]}" shell wm dismiss-keyguard 2>/dev/null || true
"${ADB[@]}" shell cmd role add-role-holder android.app.role.HOME "$NEW" || true
"${ADB[@]}" shell am task lock stop 2>/dev/null || true
"${ADB[@]}" shell am force-stop "$NEW"
"${ADB[@]}" shell am start -n "$NEW/.MainActivity"
sleep 2
"${ADB[@]}" shell dumpsys activity activities | tr -d '\r' | grep -E 'topResumedActivity|mLockTaskModeState' | head -5 || true

echo "MIGRATE DEVICE OWNER OK"
