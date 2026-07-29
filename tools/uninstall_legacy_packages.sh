#!/usr/bin/env bash
# Remove pre-rename / stray packages that are NOT the current canonical IDs.
# Garden Explorer intentionally keeps com.dylan.antexplorer.garden (her installs).
set -euo pipefail
SERIAL="${1:-${ADB_SERIAL:-}}"
ADB_BIN="${ADB:-adb}"
ADB=("$ADB_BIN")
[[ -n "$SERIAL" ]] && ADB+=( -s "$SERIAL" )

# shellcheck source=packages.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/packages.sh"

STRAY=(
  # Old Ant Phone launcher / games (except garden — see KEEP)
  com.dylan.antexplorer
  com.dylan.antexplorer.colony
  com.dylan.antexplorer.solar
  com.dylan.antexplorer.math
  com.dylan.antexplorer.language
  # Mis-renamed garden APK that briefly shipped as garden_explorer
  com.dylan.garden_explorer
)

KEEP=(
  "$PKG_GARDEN_EXPLORER"   # com.dylan.antexplorer.garden
)

if ! "${ADB[@]}" devices | tr -d '\r' | awk 'NR>1 && $2=="device" {found=1} END{exit !found}'; then
  echo "no adb device" >&2
  exit 1
fi

echo "=== keep (do not uninstall) ==="
printf '  %s\n' "${KEEP[@]}"

echo "=== stop lock-task / legacy launcher ==="
"${ADB[@]}" shell am task lock stop 2>/dev/null || true
"${ADB[@]}" shell am force-stop com.dylan.antexplorer 2>/dev/null || true

for pkg in "${STRAY[@]}"; do
  if "${ADB[@]}" shell pm path "$pkg" 2>/dev/null | grep -q package:; then
    echo "uninstall $pkg"
    "${ADB[@]}" shell pm uninstall --user 0 "$pkg" 2>/dev/null ||
      "${ADB[@]}" uninstall "$pkg" 2>/dev/null || true
  else
    echo "skip $pkg (not installed)"
  fi
done

echo "STRAY UNINSTALL DONE"
