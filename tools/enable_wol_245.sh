#!/usr/bin/env bash
# Enable Wake-on-LAN on Pop!_OS 245 (ethernet enp12s0).
# Run ON 245 with sudo:
#   sudo bash ~/enable_wol_245.sh
#   # or from repo: sudo bash star_learning/tools/enable_wol_245.sh
set -euo pipefail

IFACE="${WOL_IFACE:-enp12s0}"
MAC="$(cat /sys/class/net/"$IFACE"/address 2>/dev/null || true)"
[[ -n "$MAC" ]] || { echo "ERROR: no iface $IFACE" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ethtool wakeonlan

echo "=== enable WoL magic packet on $IFACE ($MAC) ==="
ethtool -s "$IFACE" wol g
ethtool "$IFACE" | grep -i wake || true

# Persist across link-up (NetworkManager / networkd-dispatcher)
mkdir -p /etc/networkd-dispatcher/routable.d
cat >/etc/networkd-dispatcher/routable.d/50-wol-"$IFACE" <<EOF
#!/bin/sh
# Re-apply Wake-on-LAN after DHCP/link is routable.
[ "\$IFACE" = "$IFACE" ] || exit 0
/usr/sbin/ethtool -s "$IFACE" wol g || true
EOF
chmod +x /etc/networkd-dispatcher/routable.d/50-wol-"$IFACE"

# Also NM dispatcher (Pop often uses NetworkManager)
mkdir -p /etc/NetworkManager/dispatcher.d
cat >/etc/NetworkManager/dispatcher.d/99-wol-"$IFACE" <<EOF
#!/bin/sh
iface="\$1"
action="\$2"
[ "\$iface" = "$IFACE" ] || exit 0
case "\$action" in
  up|connectivity-change|dhcp4-change)
    /usr/sbin/ethtool -s "$IFACE" wol g || true
    ;;
esac
EOF
chmod +x /etc/NetworkManager/dispatcher.d/99-wol-"$IFACE"

# Allow PCI device to wake the system
if [[ -f /sys/class/net/"$IFACE"/device/power/wakeup ]]; then
  echo enabled >/sys/class/net/"$IFACE"/device/power/wakeup
  echo "PCI wakeup=$(cat /sys/class/net/"$IFACE"/device/power/wakeup)"
fi

# Prefer suspend-to-RAM over full poweroff for reliable WoL
# (user can still shut down; document that sleep/suspend wakes best)
mkdir -p /etc/systemd/logind.conf.d
cat >/etc/systemd/logind.conf.d/wol-idle.conf <<'EOF'
[Login]
# Keep lid/idle policy alone; do not force IdleAction here.
EOF

echo ""
echo "OK WoL enabled on $IFACE"
echo "  MAC: $MAC"
echo "  Verify: ethtool $IFACE | grep Wake"
echo "  Wake from Mac Studio:  ~/bin/wake_lan.sh 245"
echo "  UniFi: Clients → 245 → Wake device (or Tools → Wake on LAN) using that MAC"
echo ""
echo "Note: BIOS/UEFI must allow PME / Wake on LAN (System76 usually on by default)."
echo "      WoL works from suspend/sleep; cold power-off support varies by board."
