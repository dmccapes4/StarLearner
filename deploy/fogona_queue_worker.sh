#!/usr/bin/env bash
# One-shot deliver of the queued APK to fogona via Pop!_OS 245 (WAN :2222).
# Triggered on demand (ops portal "Deliver now" or: systemctl --user start starlearner-fogona-queue).
# Does NOT poll — exits after one attempt.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUEUE_DIR="${STARLEARNER_QUEUE_DIR:-$ROOT/deploy/queue}"
JOB="$QUEUE_DIR/job.json"
HOST="${STARLEARNER_245_HOST:-dylanmccapes@104.53.183.230}"
PORT="${STARLEARNER_245_PORT:-2222}"
KEY="${STARLEARNER_245_KEY:-$HOME/.ssh/id_ed25519}"
REMOTE_DIR='~/star_learner/inbox'

SSH=(ssh -o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=8
  -o StrictHostKeyChecking=accept-new
  -i "$KEY" -p "$PORT" "$HOST")
SCP=(scp -o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=8
  -o StrictHostKeyChecking=accept-new
  -i "$KEY" -P "$PORT")

log() { printf '[fogona-queue] %s\n' "$*"; }

job_update() {
  python3 - "$JOB" "$@" <<'PY'
import json, sys, time
path = sys.argv[1]
status = sys.argv[2]
msg = sys.argv[3] if len(sys.argv) > 3 else ""
err = sys.argv[4] if len(sys.argv) > 4 else None
with open(path, encoding="utf-8") as f:
    job = json.load(f)
job["status"] = status
job["updated"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
if msg:
    job.setdefault("log", []).append(msg)
    job["log"] = job["log"][-40:]
if err is not None:
    job["last_error"] = err
if status == "delivering":
    job["attempts"] = int(job.get("attempts") or 0) + 1
with open(path, "w", encoding="utf-8") as f:
    json.dump(job, f, indent=2)
    f.write("\n")
PY
}

host_up() {
  "${SSH[@]}" "echo ok" >/dev/null 2>&1
}

deliver() {
  local apk pkg serial remote_apk remote_path out
  apk=$(python3 -c "import json; print(json.load(open('$JOB'))['apk'])")
  pkg=$(python3 -c "import json; print(json.load(open('$JOB'))['package'])")
  serial=$(python3 -c "import json; print(json.load(open('$JOB'))['serial'])")
  [[ -f "$apk" ]] || { job_update failed "apk missing on disk" "missing $apk"; return 1; }

  job_update delivering "245 reachable; copying $(basename "$apk")"
  "${SSH[@]}" "mkdir -p $REMOTE_DIR"
  remote_apk="${REMOTE_DIR}/$(basename "$apk")"
  remote_path=$("${SSH[@]}" "printf %s $remote_apk")
  "${SCP[@]}" "$apk" "$HOST:$remote_path"

  job_update delivering "adb install on fogona $serial"
  if ! out=$("${SSH[@]}" bash -s -- "$remote_path" "$serial" "$pkg" 2>&1 <<'EOS'
set -euo pipefail
APK="$1"; SERIAL="$2"; PKG="$3"
ADB="$(command -v adb || true)"
if [[ -z "$ADB" ]]; then
  for c in "$HOME/Android/Sdk/platform-tools/adb" /usr/bin/adb; do
    [[ -x "$c" ]] && ADB=$c && break
  done
fi
[[ -n "$ADB" ]] || { echo "adb not found on 245 — install platform-tools" >&2; exit 3; }
"$ADB" start-server >/dev/null 2>&1 || true
state="$("$ADB" -s "$SERIAL" get-state 2>/dev/null || true)"
if [[ "$state" != "device" ]]; then
  echo "fogona not ready (state=${state:-none}). Plug USB on 245?" >&2
  "$ADB" devices -l >&2 || true
  exit 4
fi
"$ADB" -s "$SERIAL" install --no-streaming -r -g "$APK"
"$ADB" -s "$SERIAL" shell pm path "$PKG"
# drop legacy garden id if present
"$ADB" -s "$SERIAL" uninstall com.dylan.antexplorer.garden >/dev/null 2>&1 || true
echo "INSTALL_OK $PKG"
EOS
  ); then
    job_update failed "adb/ssh install failed" "${out:-remote failed}"
    log "install failed: $out"
    return 1
  fi
  job_update done "installed $pkg on $serial · ${out##*$'\n'}" ""
  log "done $pkg → $serial"
}

if [[ ! -f "$JOB" ]]; then
  log "no job.json — nothing to deliver"
  exit 0
fi

status=$(python3 -c "import json; print(json.load(open('$JOB')).get('status',''))" 2>/dev/null || echo "")
case "$status" in
  pending|failed)
    log "one-shot deliver host=$HOST:$PORT status=$status"
    if ! host_up; then
      job_update failed "245 not reachable on :$PORT — turn on Pop, then Deliver now" \
        "245 unreachable $HOST:$PORT"
      log "245 unreachable"
      exit 1
    fi
    if deliver; then
      exit 0
    fi
    exit 1
    ;;
  done)
    log "job already done — nothing to do"
    exit 0
    ;;
  delivering)
    log "job stuck in delivering — resetting to failed; press Deliver now again"
    job_update failed "interrupted previous delivering state" "was delivering"
    exit 1
    ;;
  *)
    log "job status='$status' — nothing to deliver"
    exit 0
    ;;
esac
