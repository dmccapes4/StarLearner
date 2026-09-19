#!/usr/bin/env bash
# Poll a fogona unit's OEM-unlock eligibility over ADB and log every change.
#
# Motorola gates the "OEM unlocking" developer toggle server-side: it stays
# `sys.oem_unlock_allowed=0` until the device is deemed eligible (no carrier
# binding, enough online check-in time). We can't force it — only watch for it.
#
# Runs forever, sampling on an interval, appending one TSV row per sample and a
# prominent ALERT line + marker file the moment `oem_unlock_allowed` flips to 1.
#
# Usage:
#   tools/poll_oem_unlock.sh [SERIAL] [INTERVAL_SECONDS] [LOGFILE]
# Defaults: reef (ZL8326FWKM), 21600s (6h), ~/star_learner/logs/oem_unlock_poll.log
#
# Meant to be launched detached on the USB host (245):
#   setsid nohup tools/poll_oem_unlock.sh >/dev/null 2>&1 &
set -uo pipefail

SERIAL="${1:-ZL8326FWKM}"
INTERVAL="${2:-21600}"
LOG="${3:-$HOME/star_learner/logs/oem_unlock_poll.log}"
MARKER="${LOG%.log}.UNLOCKED"

ADB="$(command -v adb || echo adb)"
mkdir -p "$(dirname "$LOG")"

# TSV header once.
if [[ ! -s "$LOG" ]]; then
  printf 'timestamp\tserial\tstate\toem_unlock_allowed\tflash_locked\tverifiedboot\tsim\tnote\n' >>"$LOG"
fi

get() { "$ADB" -s "$SERIAL" shell getprop "$1" 2>/dev/null | tr -d '\r'; }

while true; do
  ts="$(date -Is)"
  state="$("$ADB" -s "$SERIAL" get-state 2>/dev/null | tr -d '\r')"
  if [[ "$state" == "device" ]]; then
    allowed="$(get sys.oem_unlock_allowed)"
    flash="$(get ro.boot.flash.locked)"
    vbs="$(get ro.boot.verifiedbootstate)"
    sim="$(get gsm.sim.state)"
    note=""
    if [[ "$allowed" == "1" ]]; then
      note="OEM_UNLOCK_AVAILABLE"
      if [[ ! -f "$MARKER" ]]; then
        {
          echo "==== OEM UNLOCK AVAILABLE on $SERIAL at $ts ===="
          echo "sys.oem_unlock_allowed=1  flash.locked=$flash  verifiedbootstate=$vbs"
          echo "Next: enable the OEM unlocking toggle, then unlock the bootloader"
          echo "(this factory-resets the device; re-run tools/full_deploy.sh afterward)."
        } >"$MARKER"
      fi
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$ts" "$SERIAL" "$state" "${allowed:-?}" "${flash:-?}" "${vbs:-?}" "${sim:-?}" "$note" >>"$LOG"
  else
    printf '%s\t%s\t%s\t\t\t\t\tdevice_not_ready\n' "$ts" "$SERIAL" "${state:-offline}" >>"$LOG"
  fi
  sleep "$INTERVAL"
done
