#!/usr/bin/env bash
# Fleet-wide ADB RSA key — one keypair trusted by all fogona handsets on every ops host.
#
# Private key storage (gitignored):
#   ant_explorer/tools/secrets/fleet/adbkey
#   ant_explorer/tools/secrets/fleet/adbkey.pub
#
# Usage:
#   ./tools/sync_fleet_adbkey.sh export     # ~/.android/adbkey* → secrets/fleet/
#   ./tools/sync_fleet_adbkey.sh install    # secrets/fleet/ → ~/.android/ (+ backup old)
#   ./tools/sync_fleet_adbkey.sh fingerprint
#   ./tools/sync_fleet_adbkey.sh push SERIAL  # root only: append pub to device adb_keys
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLEET_DIR="$ROOT/ant_explorer/tools/secrets/fleet"
ANDROID_DIR="${ANDROID_SDK_HOME:-$HOME/.android}"
cmd="${1:-help}"

die() { echo "ERROR: $*" >&2; exit 1; }

fingerprint() {
  local pub="$1"
  [[ -f "$pub" ]] || die "missing $pub"
  echo "file: $pub"
  md5sum "$pub"
  awk '{print "comment:", $NF}' "$pub"
}

backup_android_keys() {
  local ts
  ts="$(date +%Y%m%d_%H%M%S)"
  [[ -f "$ANDROID_DIR/adbkey" ]] && cp -a "$ANDROID_DIR/adbkey" "$ANDROID_DIR/adbkey.bak.$ts"
  [[ -f "$ANDROID_DIR/adbkey.pub" ]] && cp -a "$ANDROID_DIR/adbkey.pub" "$ANDROID_DIR/adbkey.pub.bak.$ts"
  echo "Backed up prior ~/.android keys → adbkey.bak.$ts"
}

case "$cmd" in
  export)
    [[ -f "$ANDROID_DIR/adbkey" && -f "$ANDROID_DIR/adbkey.pub" ]] ||
      die "no ~/.android/adbkey pair — run 'adb start-server' once to generate, or use install"
    mkdir -p "$FLEET_DIR"
    install -m 600 "$ANDROID_DIR/adbkey" "$FLEET_DIR/adbkey"
    install -m 644 "$ANDROID_DIR/adbkey.pub" "$FLEET_DIR/adbkey.pub"
    echo "Exported fleet key → $FLEET_DIR"
    fingerprint "$FLEET_DIR/adbkey.pub"
    ;;
  install)
    [[ -f "$FLEET_DIR/adbkey" && -f "$FLEET_DIR/adbkey.pub" ]] ||
      die "missing $FLEET_DIR/adbkey{,.pub} — copy from canonical host or run export there"
    mkdir -p "$ANDROID_DIR"
    backup_android_keys
    install -m 600 "$FLEET_DIR/adbkey" "$ANDROID_DIR/adbkey"
    install -m 644 "$FLEET_DIR/adbkey.pub" "$ANDROID_DIR/adbkey.pub"
    echo "Installed fleet key → $ANDROID_DIR"
    fingerprint "$ANDROID_DIR/adbkey.pub"
    echo "Run: adb kill-server && adb start-server && adb devices"
    ;;
  fingerprint)
    echo "=== fleet secrets ==="
    [[ -f "$FLEET_DIR/adbkey.pub" ]] && fingerprint "$FLEET_DIR/adbkey.pub" || echo "(no fleet secrets yet)"
    echo "=== active ~/.android ==="
    [[ -f "$ANDROID_DIR/adbkey.pub" ]] && fingerprint "$ANDROID_DIR/adbkey.pub" || echo "(no ~/.android key)"
    ;;
  push)
    serial="${2:-}"
    [[ -n "$serial" ]] || die "usage: $0 push SERIAL"
    [[ -f "$FLEET_DIR/adbkey.pub" ]] || die "missing fleet adbkey.pub"
    adb -s "$serial" root || die "adb root failed — Magisk/root required"
    adb -s "$serial" shell 'cat >> /data/misc/adb/adb_keys' < "$FLEET_DIR/adbkey.pub"
    echo "Appended fleet pubkey on $serial — reboot recommended"
    ;;
  help|-h|--help)
    sed -n '2,14p' "$0"
    ;;
  *)
    die "unknown: $cmd (export|install|fingerprint|push SERIAL)"
    ;;
esac
