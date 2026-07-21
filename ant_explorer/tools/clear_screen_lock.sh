#!/usr/bin/env bash
# Remove the lock-screen PIN/pattern/password on the connected Ant Phone.
# Usage: ./clear_screen_lock.sh <current-pin>
set -euo pipefail

OLD="${1:-}"
if [[ -z "$OLD" ]]; then
  echo "Usage: $0 <current-pin>"
  echo "Android requires the existing credential once to clear it."
  exit 1
fi

adb devices | grep -q 'device$' || { echo "no adb device"; exit 1; }

adb shell locksettings clear --old "$OLD"
adb shell locksettings set-disabled true || true
adb shell settings put secure lockscreen.disabled 1
adb shell settings put secure lock_to_app_exit_locked 0
adb shell wm dismiss-keyguard 2>/dev/null || true

echo "--- lock state ---"
adb shell dumpsys lock_settings 2>/dev/null | grep -E 'CredentialType|Quality' | head -5
adb shell locksettings get-disabled || true
echo "done (expect CredentialType: None / no PIN)"
