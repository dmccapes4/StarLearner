#!/usr/bin/env bash
# Build antphone_updater for the phone (static linux/arm64, runs on Android via Magisk).
set -euo pipefail
cd "$(dirname "$0")"

# Embedded Let's Encrypt root (public cert; refreshed from the host CA store).
if [ ! -f isrg_root_x1.pem ]; then
  cp /etc/ssl/certs/ISRG_Root_X1.pem isrg_root_x1.pem
fi

CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
  go build -trimpath -ldflags='-s -w' -o ../build/antphone_updater .
echo "built ../build/antphone_updater"
