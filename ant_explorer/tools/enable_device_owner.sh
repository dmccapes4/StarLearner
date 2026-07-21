#!/usr/bin/env bash
# Make Star Learner the device owner so enterprise lock-task works
# (no "App is pinned" SystemUI tab). Safe to re-run.
set -euo pipefail
PKG=com.dylan.antexplorer
ADMIN="$PKG/.AdminReceiver"

adb devices | grep -q $'\tdevice$' || { echo "no adb device"; exit 1; }

adb shell am task lock stop 2>/dev/null || true

if adb shell dpm list-owners | grep -q "$PKG"; then
  echo "already device owner: $PKG"
else
  echo "setting device owner $ADMIN ..."
  adb shell dpm set-device-owner "$ADMIN"
fi

adb shell dpm list-owners
echo "OK — relaunch Star Learner; it will whitelist lock-task packages."
