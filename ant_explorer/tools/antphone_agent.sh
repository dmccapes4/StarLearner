#!/system/bin/sh
# Magisk late_start service: Wi-Fi + localhost-only adbd + reverse tunnel to 230.
# Tunnel-only: adb TCP is firewalled off wlan0; only reachable via hub reverse forward.

MODDIR=${0%/*}
ANT=/data/adb/antphone
LOG=$ANT/agent.log
BIN=$ANT/antphone_tunnel
KEY=$ANT/antphone_ed25519
WIFI_CONF=$ANT/wifi.conf
HUB_USER=2ndopinionmd
HUB_HOST=104.53.183.230

mkdir -p "$ANT"
exec >>"$LOG" 2>&1
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) agent start"

# Wait for network stack
sleep 15

# --- Wi-Fi: ensure known SSIDs (cmd wifi add-network on Android 10+) ---
if [ -f "$WIFI_CONF" ]; then
  while IFS='|' read -r SSID PSK PRIO; do
    case "$SSID" in
      ''|\#*) continue ;;
    esac
    echo "wifi ensure: $SSID"
    if [ -n "$PSK" ]; then
      cmd wifi connect-network "$SSID" wpa2 "$PSK" 2>/dev/null \
        || cmd wifi connect-network "$SSID" wpa3 "$PSK" 2>/dev/null \
        || true
    fi
  done < "$WIFI_CONF"
fi

# Passwords live only in $WIFI_CONF on device (not in git).

# --- adb TCP on port 5555 ---
setprop service.adb.tcp.port 5555
stop adbd 2>/dev/null
start adbd 2>/dev/null
sleep 2

# Tunnel-only: block inbound 5555 on Wi-Fi / non-loopback (iptables + iptables6 best-effort)
iptables -C INPUT -i lo -p tcp --dport 5555 -j ACCEPT 2>/dev/null \
  || iptables -I INPUT 1 -i lo -p tcp --dport 5555 -j ACCEPT
iptables -C INPUT -p tcp --dport 5555 -j DROP 2>/dev/null \
  || iptables -A INPUT -p tcp --dport 5555 -j DROP
# Also reject from wlan explicitly if policy is weird
iptables -C INPUT -i wlan0 -p tcp --dport 5555 -j DROP 2>/dev/null \
  || iptables -I INPUT 1 -i wlan0 -p tcp --dport 5555 -j DROP

echo "adbd tcp ready (loopback only via firewall)"

# --- reverse tunnel loop (binary has its own retry) ---
if [ ! -x "$BIN" ] || [ ! -f "$KEY" ]; then
  echo "MISSING tunnel binary or key under $ANT"
  exit 1
fi
chmod 600 "$KEY"
chmod 755 "$BIN"

# Kill prior instance
killall antphone_tunnel 2>/dev/null || true
"$BIN" -user "$HUB_USER" -host "$HUB_HOST" -key "$KEY" \
  -listen 127.0.0.1:5555 -local 127.0.0.1:5555 &
echo "tunnel pid $!"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) agent armed"
