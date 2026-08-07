#!/usr/bin/env bash
# Leave Star Learner lock-task so Motorola/Google check-in UIs can run
# (Developer options → OEM unlocking, USB debugging authorize, Magisk, etc.).
#
# Usage:
#   ./tools/kiosk_maintenance.sh              # exit kiosk → open Dev options
#   ./tools/kiosk_maintenance.sh on           # same
#   ./tools/kiosk_maintenance.sh off          # re-enter kiosk
#   ./tools/kiosk_maintenance.sh status
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=adb_helpers.sh
source "$ROOT/tools/adb_helpers.sh"
PKG=com.dylan.star_learner
ACT="$PKG/.MainActivity"
SERIAL="${STARLEARNER_SERIAL:-${ADB_SERIAL:-}}"
ADB=(adb)
[[ -n "$SERIAL" ]] && ADB+=(-s "$SERIAL")

cmd="${1:-on}"
case "$cmd" in
  on|maintenance|enter)
    # Keep the screen awake while OEM/carrier eligibility talks to the network.
    "${ADB[@]}" shell settings put global stay_on_while_plugged_in 7 || true
    "${ADB[@]}" shell svc power stayon true 2>/dev/null || true
    "${ADB[@]}" shell svc wifi enable 2>/dev/null || true
    "${ADB[@]}" shell am start -n "$ACT" -a "$PKG.MAINTENANCE"
    echo "Maintenance on. On the phone: Developer options → OEM unlocking."
    echo "When done: $0 off"
    ;;
  off|kiosk|exit)
    "${ADB[@]}" shell am start -n "$ACT" -a "$PKG.KIOSK_ON"
    echo "Kiosk re-asserted."
    ;;
  status)
    "${ADB[@]}" shell getprop sys.oem_unlock_allowed | awk '{print "sys.oem_unlock_allowed="$0}'
    "${ADB[@]}" shell getprop gsm.sim.state | awk '{print "sim="$0}'
    "${ADB[@]}" shell dumpsys activity activities | grep -E 'mLockTaskModeState=|topResumedActivity=' | head -5
    ;;
  -h|--help)
    sed -n '2,12p' "$0"
    ;;
  *)
    echo "unknown: $cmd (on|off|status)" >&2
    exit 2
    ;;
esac
