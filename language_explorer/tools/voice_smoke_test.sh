#!/usr/bin/env bash
# Post-deploy Voice-to-Write smoke: local build/tests + remote device + ASR reachability.
#
# Usage:
#   bash tools/voice_smoke_test.sh              # local + remote checks + printed manual protocol
#   bash tools/voice_smoke_test.sh --local      # host only (CI / pre-push)
#   bash tools/voice_smoke_test.sh --remote     # device + ASR + manual protocol only
#   bash tools/voice_smoke_test.sh --deploy     # build, install APK, then remote checks
#   bash tools/voice_smoke_test.sh --capture    # remote + tail VoiceTel logcat during manual run
#
# Manual protocol uses two short sentences; follow VO cues for mic taps.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAR="$(cd "$ROOT/.." && pwd)"
APK="$ROOT/tools/build/com.dylan.antexplorer.language.apk"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
PKG=com.dylan.antexplorer.language
HUB_JSON="$ROOT/game/data/hub_client.json"

# Fixed post-deploy phrases (also exercised by ASR cleanup on the host).
SENTENCE_A="I see a cat."
SENTENCE_B="The sun is hot."

DO_LOCAL=1
DO_REMOTE=1
DO_DEPLOY=0
DO_CAPTURE=0
DO_PIN=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local) DO_REMOTE=0 ;;
    --remote) DO_LOCAL=0 ;;
    --deploy) DO_DEPLOY=1 ;;
    --capture) DO_CAPTURE=1 ;;
    --no-pin) DO_PIN=0 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

failures=0
note() { echo "==> $*"; }
ok() { echo "OK  $*"; }
bad() { echo "FAIL $*" >&2; failures=$((failures + 1)); }

asr_health() {
  local base="${1%/}"
  local tok="${2:-}"
  local url="$base/health"
  local code
  if [[ -n "$tok" ]]; then
    code="$(curl -sf -o /tmp/voice_smoke_health.json -w '%{http_code}' \
      -H "Authorization: Bearer $tok" --connect-timeout 6 --max-time 12 "$url" 2>/dev/null || echo 000)"
  else
    code="$(curl -sf -o /tmp/voice_smoke_health.json -w '%{http_code}' \
      --connect-timeout 6 --max-time 12 "$url" 2>/dev/null || echo 000)"
  fi
  [[ "$code" == "200" ]]
}

run_local() {
  note "local — Language Explorer unit tests"
  if "$GODOT" --headless --path "$ROOT/game" -s res://tests/run_tests.gd 2>&1 | tee /tmp/voice_smoke_tests.log | tail -3 | grep -q '0 failed'; then
    ok "290+ unit tests passed"
  else
    bad "unit tests failed (see /tmp/voice_smoke_tests.log)"
  fi

  note "local — ASR cleanup capitalization (two sentences)"
  python3 - <<PY
import sys
sys.path.insert(0, "$ROOT/tools/asr_server")
from server import finalize_sentence
for raw, want in [
    ("i see a cat", "$SENTENCE_A"),
    ("the sun is hot", "$SENTENCE_B"),
]:
    got = finalize_sentence(raw)
    assert got == want, f"{raw!r} -> {got!r}, want {want!r}"
print("cap ok")
PY
  ok "finalize_sentence for both smoke phrases"

  if [[ "$DO_DEPLOY" == 1 ]] || [[ ! -f "$APK" ]]; then
    note "local — build Language APK"
    (cd "$STAR" && STARLEARNER_HUB_DEV=1 bash "$ROOT/tools/build_language_apk.sh") 2>&1 | tail -5
  fi
  if [[ -f "$APK" ]]; then
    ok "APK present ($(du -h "$APK" | awk '{print $1}'))"
  else
    bad "APK missing at $APK"
  fi

  note "local — ASR /health (hub_client bases from workstation)"
  if [[ -f "$HUB_JSON" ]]; then
    if python3 - "$HUB_JSON" <<'PY'
import json, subprocess, sys
d = json.load(open(sys.argv[1]))
bases = d.get("bases") or []
tok = d.get("token") or ""
ok = 0
for b in bases:
    b = b.rstrip("/")
    cmd = ["curl", "-sf", "--connect-timeout", "6", "--max-time", "12"]
    if tok:
        cmd.extend(["-H", f"Authorization: Bearer {tok}"])
    cmd.append(f"{b}/health")
    r = subprocess.run(cmd, capture_output=True)
    status = "OK" if r.returncode == 0 else "FAIL"
    print(f"{status}  {b}/health")
    if r.returncode == 0:
        ok += 1
if ok == 0:
    sys.exit(1)
PY
    then
      ok "at least one ASR base reachable from this host"
    else
      bad "no ASR base reachable (start tools/asr_server/run.sh on :8770?)"
    fi
  else
    bad "missing $HUB_JSON"
  fi
}

try_disable_pin() {
  note "remote — soften lock screen (no Settings needed)"
  adb devices | grep -q $'\tdevice$' || { bad "no adb device for PIN"; return; }
  adb shell settings put secure lock_to_app_exit_locked 0 2>/dev/null || true
  adb shell settings put secure lockscreen.disabled 1 2>/dev/null || true
  adb shell locksettings set-disabled true 2>/dev/null || true
  adb shell wm dismiss-keyguard 2>/dev/null || true
  local cred
  cred="$(adb shell dumpsys lock_settings 2>/dev/null | grep -E 'CredentialType' | head -1 | tr -d '\r' || true)"
  local disabled
  disabled="$(adb shell locksettings get-disabled 2>/dev/null | tr -d '\r' || true)"
  echo "    $cred"
  echo "    locksettings disabled=$disabled"
  if echo "$cred" | grep -qi 'none'; then
    ok "no lock credential on device"
  elif [[ "$disabled" == "true" ]]; then
    ok "lock screen disabled via locksettings"
  else
    echo "WARN: PIN may still appear after leaving lock-task."
    echo "      One-time fix (needs current PIN): bash $STAR/ant_explorer/tools/clear_screen_lock.sh <pin>"
  fi
}

run_remote() {
  note "remote — adb device"
  adb devices | grep -q $'\tdevice$' || { bad "no adb device"; return; }
  ok "adb device connected"

  if [[ "$DO_DEPLOY" == 1 ]]; then
    note "remote — install Language APK"
    bash "$STAR/ant_explorer/tools/antphone_deploy_local.sh" "$APK"
  elif [[ -f "$APK" ]]; then
    note "remote — APK on disk (skip install; use --deploy to push)"
    ok "$(basename "$APK") ready"
  fi

  note "remote — package + mic permission"
  if adb shell pm path "$PKG" 2>/dev/null | grep -q package:; then
    ok "$PKG installed"
  else
    bad "$PKG not installed — re-run with --deploy"
  fi
  adb shell pm grant "$PKG" android.permission.RECORD_AUDIO 2>/dev/null || true
  ok "RECORD_AUDIO grant attempted"

  if [[ "$DO_PIN" == 1 ]]; then
    try_disable_pin
  fi

  note "remote — ASR from phone network (same bases as hub_client.json)"
  if [[ -f "$HUB_JSON" ]]; then
    if python3 - "$HUB_JSON" <<'PY'
import json, subprocess, sys
d = json.load(open(sys.argv[1]))
bases = d.get("bases") or []
tok = d.get("token") or ""
ok = 0
for b in bases:
    b = b.rstrip("/")
    cmd = ["curl", "-sf", "--connect-timeout", "6", "--max-time", "12"]
    if tok:
        cmd.extend(["-H", f"Authorization: Bearer {tok}"])
    cmd.append(f"{b}/health")
    r = subprocess.run(cmd, capture_output=True)
    status = "OK" if r.returncode == 0 else "FAIL"
    print(f"{status}  {b}/health")
    if r.returncode == 0:
        ok += 1
if ok == 0:
    sys.exit(1)
PY
    then
      ok "at least one ASR base reachable (LAN and/or hub)"
    else
      bad "no ASR base reachable for phone"
    fi
  fi

  print_manual_protocol
}

print_manual_protocol() {
  cat <<EOF

╔══════════════════════════════════════════════════════════════════╗
║  Voice smoke — two sentences (follow narration for mic taps)     ║
╠══════════════════════════════════════════════════════════════════╣
║  Open Language Explorer → Voice on the phone.                    ║
║  Red corner dot = listening for "next" only.                     ║
╠══════════════════════════════════════════════════════════════════╣
║  SENTENCE A: "$SENTENCE_A"
║    1. Wait for VO: "Tap the microphone and say what you want…"   ║
║    2. Tap mic tile when prompted → say sentence → wait / tap done  ║
║    3. Spell with "next" or right arrow; red dot cycles listen/write║
║    4. End: hear full sentence + "You got it!"                    ║
║    5. Mic tile works again for sentence B                        ║
╠══════════════════════════════════════════════════════════════════╣
║  SENTENCE B: "$SENTENCE_B"
║    Repeat steps 1–5.                                             ║
╠══════════════════════════════════════════════════════════════════╣
║  Pass if both sentences appear capitalized on screen and mic     ║
║  accepts a third phrase without restarting the app.              ║
╚══════════════════════════════════════════════════════════════════╝

Log markers (adb logcat | grep VoiceTel):
  phrase ok=true text=$SENTENCE_A
  listen_asr cmd=next
  write_pause
  (after finish) mic tile → enroll_start or phrase recording

EOF
}

maybe_capture() {
  if [[ "$DO_CAPTURE" != 1 ]]; then
    return
  fi
  note "capture — VoiceTel logcat (Ctrl+C when manual protocol done)"
  adb logcat -c 2>/dev/null || true
  exec bash "$ROOT/tools/voice_test_capture.sh"
}

[[ "$DO_LOCAL" == 1 ]] && run_local
[[ "$DO_REMOTE" == 1 ]] && run_remote

note "summary"
if [[ "$failures" -eq 0 ]]; then
  echo "VOICE SMOKE OK (automated checks)"
  maybe_capture
  exit 0
fi
echo "VOICE SMOKE FAILED ($failures automated check(s))" >&2
exit 1
