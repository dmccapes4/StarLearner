#!/usr/bin/env bash
# Send Wake-on-LAN magic packets on the UDM LAN (run from Mac Studio / any 192.168.0.x host).
#
#   ./wake_lan.sh           # wake both
#   ./wake_lan.sh 245       # Pop only
#   ./wake_lan.sh 108       # Mac Studio only (usually already awake)
#   ./wake_lan.sh cove-host # alias for 245
set -euo pipefail

# Ethernet MACs (LAN side) — update if NICs change.
MAC_108_STUDIO=a4:fc:14:48:f4:b4   # Mac Studio en0 @ 192.168.0.108
MAC_245_POP=d8:43:ae:76:35:f8      # Pop enp12s0 @ 192.168.0.245
BCAST=192.168.0.255
PORT=9

send_wol() {
  local name="$1" mac="$2"
  python3 - "$mac" "$BCAST" "$PORT" <<'PY'
import socket, sys
mac, bcast, port = sys.argv[1], sys.argv[2], int(sys.argv[3])
mac = mac.replace(":", "").replace("-", "").lower()
assert len(mac) == 12, mac
payload = bytes.fromhex("ff" * 6 + mac * 16)
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
sock.sendto(payload, (bcast, port))
sock.sendto(payload, (bcast, 7))
print(f"WoL sent → {sys.argv[1]} ({bcast}:{port})")
PY
  printf '  target %-12s %s\n' "$name" "$mac"
}

usage() {
  sed -n '2,10p' "$0"
}

target="${1:-all}"
case "$target" in
  -h|--help) usage; exit 0 ;;
  all|both)
    send_wol "108-studio" "$MAC_108_STUDIO"
    send_wol "245-pop" "$MAC_245_POP"
    ;;
  108|studio|mac|230)
    send_wol "108-studio" "$MAC_108_STUDIO"
    ;;
  245|pop|cove-host)
    send_wol "245-pop" "$MAC_245_POP"
    ;;
  *)
    echo "unknown target: $target" >&2
    usage
    exit 2
    ;;
esac
