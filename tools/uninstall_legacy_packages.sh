#!/usr/bin/env bash
# Remove pre-2026-07-28 com.dylan.antexplorer* packages before installing star_learner IDs.
# Run once per device during the package rename migration (kiosk requires re-provisioning).
set -euo pipefail
SERIAL="${1:-${ADB_SERIAL:-}}"
ADB_BIN="${ADB:-adb}"
ADB=("$ADB_BIN")
[[ -n "$SERIAL" ]] && ADB+=( -s "$SERIAL" )

LEGACY=(
  com.dylan.antexplorer
  com.dylan.antexplorer.colony
  com.dylan.antexplorer.garden
  com.dylan.antexplorer.solar
  com.dylan.antexplorer.math
  com.dylan.antexplorer.language
)

"${ADB[@]}" devices | grep -q $'\tdevice$' || { echo "no adb device" >&2; exit 1; }

echo "=== stop lock-task / legacy launcher ==="
"${ADB[@]}" shell am task lock stop 2>/dev/null || true
"${ADB[@]}" shell am force-stop com.dylan.antexplorer 2>/dev/null || true

for pkg in "${LEGACY[@]}"; do
  if "${ADB[@]}" shell pm path "$pkg" 2>/dev/null | grep -q package:; then
    echo "uninstall $pkg"
    "${ADB[@]}" shell pm uninstall --user 0 "$pkg" 2>/dev/null ||
      "${ADB[@}" uninstall "$pkg" 2>/dev/null || true
  else
    echo "skip $pkg (not installed)"
  fi
done

echo "LEGACY UNINSTALL DONE — run full_deploy + enable_device_owner on production kiosk"
