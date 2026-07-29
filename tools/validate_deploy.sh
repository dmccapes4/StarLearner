#!/usr/bin/env bash
# Post-deploy checks: packages, kiosk, Language hub config in APK, logcat smoke.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=packages.sh
source "$ROOT/tools/packages.sh"
# shellcheck source=adb_helpers.sh
source "$ROOT/tools/adb_helpers.sh"
SERIAL="${1:-${ADB_SERIAL:-}}"
ADB_BIN="${ADB:-adb}"
ADB=("$ADB_BIN")
[[ -n "$SERIAL" ]] && ADB+=( -s "$SERIAL" )

failures=0
PKG_LANGUAGE=$PKG_LANGUAGE_EXPLORER
PKG_SOLAR=$PKG_SOLAR_EXPLORER
PKG_MATH=$PKG_MATH_EXPLORER
PKG_GARDEN=$PKG_GARDEN_EXPLORER
note() { echo "==> $*"; }
ok() { echo "OK  $*"; }
bad() { echo "FAIL $*" >&2; failures=$((failures + 1)); }

note "device"
"${ADB[@]}" get-state >/dev/null
"${ADB[@]}" shell getprop ro.serialno | tr -d '\r'

note "packages"
for pkg in "$PKG_LAUNCHER" "$PKG_LANGUAGE" "$PKG_SOLAR" "$PKG_MATH" "$PKG_GARDEN" "$PKG_ANT_EXPLORER"; do
  if "${ADB[@]}" shell pm path "$pkg" 2>/dev/null | grep -q package:; then
    ok "$pkg installed"
  else
    bad "$pkg missing"
  fi
done

note "Language hub_client.json in installed APK"
LANG_APK="$("${ADB[@]}" shell pm path "$PKG_LANGUAGE" 2>/dev/null | head -1 | sed 's/package://' | tr -d '\r')"
if [[ -n "$LANG_APK" ]]; then
  if [[ "$ADB_BIN" == *.exe ]]; then
    TMP=/mnt/c/Users/dylan/tmp/validate_lang_apk
  else
    TMP=/tmp/validate_lang_apk
  fi
  rm -rf "$TMP" && mkdir -p "$TMP"
  "${ADB[@]}" pull "$LANG_APK" "$(local_path_for_adb "$TMP/lang.apk")" >/dev/null
  if unzip -p "$TMP/lang.apk" assets/data/hub_client.json >/dev/null 2>&1; then
    unzip -p "$TMP/lang.apk" assets/data/hub_client.json >"$TMP/hub_client.json"
    if python3 - "$TMP/hub_client.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("bases"), "no bases"
assert d.get("token"), "empty token"
print("bases:", d["bases"][0], "token_len:", len(d["token"]))
PY
    then
      ok "hub_client.json present with token"
    else
      bad "hub_client.json missing token or bases"
    fi
  else
    bad "hub_client.json not in Language APK assets"
  fi
else
  bad "could not locate Language APK on device"
fi

note "hub ASR /health (from build host)"
HUB_CHECK="$ROOT/tools/asr_health_check.py"
HUB_JSON_SRC="$TMP/hub_client.json"
[[ -f "$HUB_JSON_SRC" ]] || HUB_JSON_SRC="$ROOT/language_explorer/game/data/hub_client.json"
if [[ -f "$HUB_JSON_SRC" && -f "$HUB_CHECK" ]]; then
  HUB_ARGS=("$HUB_JSON_SRC")
  [[ "${REQUIRE_HUB_ASR:-0}" == "1" ]] && HUB_ARGS+=(--require-hub)
  if python3 "$HUB_CHECK" "${HUB_ARGS[@]}"; then
    ok "hub ASR reachable"
  else
    bad "hub ASR health check failed"
  fi
else
  bad "missing hub_client for ASR health check"
fi

note "launcher focus (before Language cold start)"
"${ADB[@]}" shell am start -n "$PKG_LAUNCHER/.MainActivity" >/dev/null 2>&1 || true
sleep 2
FOCUS="$("${ADB[@]}" shell dumpsys activity activities 2>/dev/null | grep -E 'topResumedActivity|mResumedActivity' | head -1 || true)"
if echo "$FOCUS" | grep -q "$PKG_LAUNCHER"; then
  ok "launcher resumed"
else
  bad "launcher not foreground: ${FOCUS:-unknown}"
fi

note "Language mic permission + hardware"
MIC="$("${ADB[@]}" shell dumpsys package "$PKG_LANGUAGE" 2>/dev/null | grep 'android.permission.RECORD_AUDIO' | grep 'granted=true' | head -1 || true)"
if echo "$MIC" | grep -q 'granted=true'; then
  ok "RECORD_AUDIO granted"
else
  note "granting RECORD_AUDIO"
  "${ADB[@]}" shell pm grant "$PKG_LANGUAGE" android.permission.RECORD_AUDIO 2>/dev/null || true
  "${ADB[@]}" shell appops set "$PKG_LANGUAGE" RECORD_AUDIO allow 2>/dev/null || true
  MIC="$("${ADB[@]}" shell dumpsys package "$PKG_LANGUAGE" 2>/dev/null | grep 'android.permission.RECORD_AUDIO' | grep 'granted=true' | head -1 || true)"
  if echo "$MIC" | grep -q 'granted=true'; then
    ok "RECORD_AUDIO granted after pm grant"
  else
    bad "RECORD_AUDIO not granted"
  fi
fi
MIC_DEV="$("${ADB[@]}" shell dumpsys audio 2>/dev/null | grep -i 'Microphone' | head -3 || true)"
if [[ -n "$MIC_DEV" ]]; then
  echo "$MIC_DEV" | sed 's/^/    /'
  ok "microphone device present in audio dump"
fi

note "logcat smoke (Language cold start)"
"${ADB[@]}" logcat -c >/dev/null 2>&1 || true
"${ADB[@]}" shell am force-stop "$PKG_LANGUAGE" >/dev/null 2>&1 || true
"${ADB[@]}" shell am start -n "$PKG_LANGUAGE/com.godot.game.GodotApp" >/dev/null
sleep 4
LOG="$("${ADB[@]}" logcat -d -t 200 2>/dev/null || true)"
if echo "$LOG" | grep -E 'AndroidRuntime|FATAL EXCEPTION' | grep -q .; then
  bad "FATAL in logcat after Language start"
  echo "$LOG" | grep -E 'AndroidRuntime|FATAL' | tail -5 >&2
else
  ok "no FATAL after Language start"
fi
if echo "$LOG" | grep -qiE 'hub_client|HubClient|voice_needs_wifi|offline'; then
  echo "$LOG" | grep -iE 'hub_client|HubClient|voice_needs_wifi|offline' | tail -8
fi
if echo "$LOG" | grep -qi 'hub.starlearner.app'; then
  ok "log mentions hub.starlearner.app"
fi

note "summary"
if [[ "$failures" -eq 0 ]]; then
  echo "VALIDATE DEPLOY OK"
  exit 0
fi
echo "VALIDATE DEPLOY FAILED ($failures check(s))" >&2
exit 1
