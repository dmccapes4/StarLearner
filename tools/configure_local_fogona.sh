#!/usr/bin/env bash
# Point local digs handset (shoal / ZL8324ZNRK) at production hub, and
# set a short Bluetooth/device codename distinct from production cove.
#
#   ./tools/configure_local_fogona.sh            # needs shoal on USB
#   ./tools/configure_local_fogona.sh --name shoal
# Production kiosk (cove / ZL8326G8ND) keeps Android device_name "Star Learner".
# Gift/travel reef (ZL8326FWKM): --serial ZL8326FWKM --name reef
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=packages.sh
source "$ROOT/tools/packages.sh"
# shellcheck source=devices.sh
source "$ROOT/tools/devices.sh"

SERIAL="${STARLEARNER_LOCAL_SERIAL:-$SERIAL_SHOAL}"
NAME="shoal"
APK="$ROOT/language_explorer/tools/build/com.dylan.language_explorer.apk"
ADB_BIN="${ADB:-adb}"

while (($#)); do
  case "$1" in
    --serial) shift; SERIAL="${1:?}" ;;
    --name) shift; NAME="${1:?}" ;;
    --apk) shift; APK="${1:?}" ;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown: $1" >&2; exit 2 ;;
  esac
  shift
done

ADB=("$ADB_BIN" -s "$SERIAL")
[[ -f "$APK" ]] || { echo "missing $APK — build with: (cd language_explorer && unset STARLEARNER_HUB_DEV && bash tools/build_language_apk.sh)" >&2; exit 1; }

"${ADB[@]}" get-state >/dev/null

echo "=== rename device to '$NAME' (was serial $SERIAL) ==="
"${ADB[@]}" shell settings put global device_name "$NAME"
"${ADB[@]}" shell settings put secure bluetooth_name "$NAME" 2>/dev/null || true
# Best-effort; some Motos also mirror via cmd bluetooth
"${ADB[@]}" shell cmd bluetooth_manager set-name "$NAME" 2>/dev/null || true
echo "device_name=$("${ADB[@]}" shell settings get global device_name | tr -d '\r')"

echo "=== install production Language APK (starlearner.dylanmccapes.systems) ==="
tmp=$(mktemp -d)
unzip -p "$APK" assets/data/hub_client.json >"$tmp/hub_client.json"
python3 - "$tmp/hub_client.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
bases = d.get("bases") or []
assert bases and bases[0] == "https://starlearner.dylanmccapes.systems/api/asr", bases
assert len(d.get("token") or "") >= 32
print("apk hub OK bases=", bases, "token_len=", len(d["token"]))
PY
"${ADB[@]}" install --no-streaming -r -g "$APK"
"${ADB[@]}" shell pm grant "$PKG_LANGUAGE_EXPLORER" android.permission.RECORD_AUDIO 2>/dev/null || true

echo "=== verify installed APK hub_client ==="
remote=$("${ADB[@]}" shell pm path "$PKG_LANGUAGE_EXPLORER" | head -1 | tr -d '\r' | sed 's/package://')
"${ADB[@]}" pull "$remote" "$tmp/installed.apk" >/dev/null
unzip -p "$tmp/installed.apk" assets/data/hub_client.json
echo
echo "LOCAL FOGONA OK: name=$NAME serial=$SERIAL hub=production"
rm -rf "$tmp"
