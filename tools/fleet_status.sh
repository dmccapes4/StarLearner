#!/usr/bin/env bash
# Report adb trust + installed Star Learner package versions for fleet handsets.
#
# Usage:
#   ./tools/fleet_status.sh              # connected fleet devices only
#   ./tools/fleet_status.sh --all      # include absent serials as MISSING
#   STARLEARNER_SERIAL=ZL8326G8ND ./tools/fleet_status.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=devices.sh
source "$ROOT/tools/devices.sh"
# shellcheck source=packages.sh
source "$ROOT/tools/packages.sh"

ADB_BIN="${ADB:-adb}"
SHOW_ALL=false
[[ "${1:-}" == "--all" ]] && SHOW_ALL=true

declare -A CODENAME=(
  ["$SERIAL_SHOAL"]=shoal
  ["$SERIAL_REEF"]=reef
  ["$SERIAL_COVE"]=cove
)

pkg_version() {
  local serial="$1" pkg="$2"
  adb -s "$serial" shell dumpsys package "$pkg" 2>/dev/null |
    tr -d '\r' |
    awk -F= '/versionName=/{print $2; exit}'
}

local_apk_version() {
  local apk="$1"
  [[ -f "$apk" ]] || return 0
  if command -v aapt >/dev/null 2>&1; then
    aapt dump badging "$apk" 2>/dev/null | awk -F"'" '/versionName/{print $2; exit}'
  fi
}

build_apk_path() {
  case "$1" in
    "$PKG_LAUNCHER") echo "$ROOT/ant_explorer/tools/build/com.dylan.star_learner.apk" ;;
    "$PKG_ANT_EXPLORER") echo "$ROOT/ant_explorer/tools/build/com.dylan.ant_explorer.apk" ;;
    "$PKG_GARDEN_EXPLORER") echo "$ROOT/garden_explorer/tools/build/com.dylan.garden_explorer.apk" ;;
    "$PKG_SOLAR_EXPLORER") echo "$ROOT/solar_system_explorer/tools/build/com.dylan.solar_system_explorer.apk" ;;
    "$PKG_MATH_EXPLORER") echo "$ROOT/math_explorer/tools/build/com.dylan.math_explorer.apk" ;;
    "$PKG_LANGUAGE_EXPLORER") echo "$ROOT/language_explorer/tools/build/com.dylan.language_explorer.apk" ;;
  esac
}

connected_serials() {
  "$ADB_BIN" devices -l | awk 'NR>1 && $2=="device" {print $1}'
}

adb_state() {
  local serial="$1"
  "$ADB_BIN" devices | awk -v s="$serial" '$1==s {print $2; exit}'
}

report_serial() {
  local serial="$1"
  local name="${CODENAME[$serial]:-unknown}"
  local state
  state="$(adb_state "$serial")"
  [[ -n "$state" ]] || state="absent"

  echo ""
  echo "=== $name ($serial) — adb: $state ==="
  if [[ "$state" != "device" ]]; then
    return 0
  fi

  "$ADB_BIN" -s "$serial" shell getprop ro.product.model | tr -d '\r' | awk '{print "model:", $0}'
  if "$ADB_BIN" -s "$serial" shell dpm list-owners 2>/dev/null | grep -q com.dylan.star_learner; then
    echo "device_owner: com.dylan.star_learner"
  else
    echo "device_owner: (none)"
  fi

  local pkg ver build
  for pkg in "${PACKAGES[@]}"; do
    ver="$(pkg_version "$serial" "$pkg")"
    build="$(local_apk_version "$(build_apk_path "$pkg")")"
    if [[ -n "$ver" ]]; then
      if [[ -n "$build" && "$ver" != "$build" ]]; then
        printf "  %-40s device=%s  build=%s  MISMATCH\n" "$pkg" "$ver" "$build"
      else
        printf "  %-40s device=%s" "$pkg" "${ver:-MISSING}"
        [[ -n "$build" ]] && printf "  build=%s" "$build"
        echo
      fi
    else
      printf "  %-40s NOT INSTALLED\n" "$pkg"
    fi
  done
}

targets=()
if [[ -n "${STARLEARNER_SERIAL:-${ADB_SERIAL:-}}" ]]; then
  targets+=("${STARLEARNER_SERIAL:-${ADB_SERIAL:-}}")
elif $SHOW_ALL; then
  targets=("$SERIAL_SHOAL" "$SERIAL_REEF" "$SERIAL_COVE")
else
  mapfile -t targets < <(connected_serials)
  if ((${#targets[@]} == 0)); then
    echo "No adb devices in 'device' state. Plug in a handset or use --all."
    "$ADB_BIN" devices -l
    exit 1
  fi
fi

echo "git: $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')"
echo "host adb: $ADB_BIN"
"$ADB_BIN" devices -l

for serial in "${targets[@]}"; do
  report_serial "$serial"
done
