#!/usr/bin/env bash
# Handset identities — model name "fogona" is Motorola's product; our codenames
# distinguish the physical units.
#
#   fogona  = Android product/device (all phones)
#   shoal   = local digs / Dylan's dev unit     ZL8324ZNRK
#   reef    = travel / nieces gift unit         ZL8326FWKM
#   cove    = production / gift kiosk           ZL8326G8ND
#
# USB homes move; serials do not. Check `adb devices -l` before assuming host.

SERIAL_SHOAL=ZL8324ZNRK
SERIAL_REEF=ZL8326FWKM
SERIAL_COVE=ZL8326G8ND

# Digs / local USB default (was reef; reef is now the nieces gift track)
SERIAL_LOCAL_DIGS="$SERIAL_SHOAL"
SERIAL_LOCAL_TEST="$SERIAL_SHOAL"
SERIAL_PRODUCTION_KIOSK="$SERIAL_COVE"
# Legacy name — prefer SERIAL_COVE
STARLEARNER_FOGONA_SERIAL="${STARLEARNER_FOGONA_SERIAL:-$SERIAL_COVE}"
