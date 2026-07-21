#!/usr/bin/env bash
# Re-apply ants appliance lockdown on the connected fogona device.
set -euo pipefail
PKG=com.dylan.antexplorer
ACT=$PKG/.MainActivity

adb devices | grep -q 'device$' || { echo "no adb device"; exit 1; }

adb shell settings put system user_rotation 1
adb shell settings put system accelerometer_rotation 0
adb shell settings put global policy_control immersive.full=*
adb shell settings put global stay_on_while_plugged_in 3
# Kid appliance: bright, manual — auto-brightness often parks near minimum indoors.
adb shell settings put system screen_brightness_mode 0
adb shell settings put system screen_brightness 220
adb shell cmd display set-brightness 0.86 2>/dev/null || true
adb shell settings put secure lock_to_app_enabled 1
# Never drop to the keyguard/PIN when lock-task ends (kid appliance).
adb shell settings put secure lock_to_app_exit_locked 0
adb shell settings put secure lockscreen.disabled 1 2>/dev/null || true
adb shell wm dismiss-keyguard 2>/dev/null || true

# Prefer enterprise lock-task (no "App is pinned" chrome). am task lock = PINNED toast.
if ! adb shell dpm list-owners 2>/dev/null | grep -q "$PKG"; then
  echo "NOTE: $PKG is not device owner yet — run tools/enable_device_owner.sh"
fi

adb shell cmd role add-role-holder android.app.role.HOME "$PKG" || true
# Clear any leftover consumer screen-pin session.
adb shell am task lock stop 2>/dev/null || true
adb shell am start -n "$ACT"
sleep 1

adb shell dumpsys activity activities | grep -E 'topResumedActivity|mLockTaskModeState' | head -5
echo "kiosk on"
