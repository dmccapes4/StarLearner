#!/usr/bin/env bash
# Deploy full Star Learner stack to every fleet handset currently adb-authorized on USB.
#
# Usage:
#   ./tools/deploy_fleet_usb.sh [--require-kiosk] [--validate] [--skip-build]
#
# Environment:
#   ADB or WIN_ADB — adb binary (245 WSL: export ADB=/mnt/c/Users/.../adb.exe)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=devices.sh
source "$ROOT/tools/devices.sh"

ADB_BIN="${ADB:-${WIN_ADB:-adb}}"
EXTRA=()
while (($#)); do
  case "$1" in
    --require-kiosk|--validate|--skip-build|--prepare-only|--deploy-only)
      EXTRA+=("$1")
      ;;
    -h|--help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown: $1" >&2
      exit 2
      ;;
  esac
  shift
done

SERIALS=("$SERIAL_REEF" "$SERIAL_COVE" "$SERIAL_SHOAL")
deployed=0

for serial in "${SERIALS[@]}"; do
  state="$("$ADB_BIN" devices | awk -v s="$serial" '$1==s {print $2; exit}')"
  if [[ "$state" != "device" ]]; then
    echo "SKIP $serial (adb state: ${state:-absent})"
    continue
  fi
  echo "=== Deploy $serial ==="
  "$ROOT/tools/full_deploy.sh" --adb "$ADB_BIN" --serial "$serial" "${EXTRA[@]}"
  deployed=$((deployed + 1))
done

if ((deployed == 0)); then
  echo "ERROR: no fleet serial in 'device' state" >&2
  "$ADB_BIN" devices -l >&2
  exit 1
fi

echo "OK — deployed $deployed handset(s)"
