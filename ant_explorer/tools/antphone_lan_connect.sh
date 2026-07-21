#!/usr/bin/env bash
# Enable adb-over-TCP on the USB-connected ants phone and connect via LAN IP.
# Home path (82 ↔ phone on 10.0.0.0/24). See STRATEGY_ANT_PHONE_UPDATES.md.
set -euo pipefail

PORT=5555
adb devices | grep -q $'\tdevice$' || { echo "plug phone via USB first (authorized)"; exit 1; }

echo "enabling tcpip :$PORT (root)..."
adb shell "su -c 'setprop service.adb.tcp.port $PORT; stop adbd; start adbd'" || {
  adb tcpip "$PORT"
}

# Prefer wlan0 IPv4
IP=$(adb shell ip -f inet addr show wlan0 | awk '/inet /{print $2}' | cut -d/ -f1 | tr -d '\r')
if [[ -z "${IP:-}" ]]; then
  echo "no wlan0 IP — is Wi-Fi up?"
  exit 1
fi
echo "phone LAN IP: $IP"
sleep 1
adb connect "$IP:$PORT"
adb devices -l
echo "connected. You can unplug USB; deploys use adb -s $IP:$PORT ..."
