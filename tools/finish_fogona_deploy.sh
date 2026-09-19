#!/usr/bin/env bash
set -euo pipefail
SERIAL="${1:-ZL8326G8ND}"
REPO=/mnt/c/Users/dylan/dev/star_learning
ADB=/mnt/c/Users/dylan/Android/platform-tools/adb.exe
export ADB
export ADB_SERIAL="$SERIAL"

"$ADB" -s "$SERIAL" shell am force-stop com.dylan.star_learner
"$ADB" -s "$SERIAL" shell am start -n com.dylan.star_learner/.MainActivity
sleep 3
"$ADB" -s "$SERIAL" shell dumpsys activity activities | tr -d '\r' | grep -E 'topResumedActivity|mLockTaskModeState' || true

echo "=== validate_deploy ==="
REQUIRE_HUB_ASR=1 "$REPO/tools/validate_deploy.sh" "$SERIAL"

echo ""
echo "=== voice_smoke_test --remote ==="
REQUIRE_HUB_ASR=1 bash "$REPO/language_explorer/tools/voice_smoke_test.sh" --remote

echo ""
echo "=== publish OTA staging ==="
"$REPO/tools/publish_ota_staging.sh" /mnt/c/Users/dylan/antphone/full_deploy

echo "FOGONA FINISH OK"
