#!/usr/bin/env bash
# Leave ants appliance mode (for maintenance / Magisk / normal use).
set -euo pipefail
adb devices | grep -q 'device$' || { echo "no adb device"; exit 1; }

adb shell am task lock stop || true
adb shell settings put global policy_control 'null*'
adb shell cmd role remove-role-holder android.app.role.HOME com.dylan.antexplorer || true

echo "Unpinned. Pick a home launcher on the phone if prompted."
echo "Bars restored. Magisk / Settings reachable again."
echo "kiosk off"
