#!/usr/bin/env bash
# Capture phone VoiceTel logcat + local ASR while running "next" voice scenarios.
#
# Usage:
#   bash tools/voice_test_capture.sh          # run until Ctrl+C
#   bash tools/voice_test_capture.sh --asr    # also restart ASR with tee to same log dir
#
# After Ctrl+C, open the newest logs/voice_test/voice_*.log
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOGDIR="$ROOT/logs/voice_test"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$LOGDIR/voice_${STAMP}.log"
ASR_LOG="$LOGDIR/asr_${STAMP}.log"
RESTART_ASR=0
[[ "${1:-}" == "--asr" ]] && RESTART_ASR=1

mkdir -p "$LOGDIR"
adb devices | grep -q $'\tdevice$' || {
	echo "no adb device — connect phone (antphone_lan_connect.sh)"
	exit 1
}

if [[ "$RESTART_ASR" == 1 ]]; then
	fuser -k 8770/tcp 2>/dev/null || true
	sleep 1
	echo "Starting ASR on :8770 → $ASR_LOG"
	ASR_PORT=8770 bash "$ROOT/tools/asr_server/run.sh" 2>&1 | tee -a "$ASR_LOG" &
	ASR_PID=$!
	sleep 2
	curl -sf "http://127.0.0.1:8770/health" >/dev/null || echo "WARN: ASR health check failed"
fi

cat <<EOF
=== Voice "next" test capture ===
Phone log + ASR → $OUT
$( [[ "$RESTART_ASR" == 1 ]] && echo "ASR raw log → $ASR_LOG" )

Suggested sequence (say "next" each time):
  1. ENROLL — loud and clear (mic tile, ~2s record)
  2. START   — normal volume, phone close while practice begins
  3. TABLE   — phone flat on table, kid-writing posture, normal voice
  4. TV      — low TV on, phone on table, normal voice (louder only if needed)

Logcat filter: VoiceTel (structured), MicCapture warnings
Press Ctrl+C when finished.
---
EOF

adb logcat -c
trap 'echo; echo "Saved → $OUT"; kill ${ASR_PID:-} ${LOGCAT_PID:-} ${ASR_TAIL_PID:-} 2>/dev/null || true; exit 0' INT TERM

{
	echo "=== capture started $(date -Iseconds) ==="
	if [[ "$RESTART_ASR" == 1 ]]; then
		echo "=== ASR (tee) ==="
		touch "$ASR_LOG"
		tail -f "$ASR_LOG" | sed -u 's/^/[asr] /' &
		ASR_TAIL_PID=$!
	fi
	echo "=== adb logcat ==="
	adb logcat -v time 2>/dev/null | grep --line-buffered -E 'VoiceTel|MicCapture: silent|VoiceToWrite' | sed -u 's/^/[phone] /' &
	LOGCAT_PID=$!
	wait ${LOGCAT_PID:-} ${ASR_TAIL_PID:-} 2>/dev/null || true
} | tee "$OUT"
