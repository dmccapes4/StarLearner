#!/usr/bin/env bash
# One-shot: deliver ALL pending/failed queued APKs to fogona via Pop 245.
# Triggered on demand (ops "Deliver now" or systemctl --user start starlearner-fogona-queue).
# Does NOT poll.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUEUE_DIR="${STARLEARNER_QUEUE_DIR:-$ROOT/deploy/queue}"
JOBS_DIR="$QUEUE_DIR/jobs"
HOST="${STARLEARNER_245_HOST:-dylanmccapes@104.53.183.230}"
PORT="${STARLEARNER_245_PORT:-2222}"
KEY="${STARLEARNER_245_KEY:-$HOME/.ssh/id_ed25519}"
REMOTE_DIR='~/star_learner/inbox'
# Dedicated known_hosts for Pop :2222 so Mac Studio :22 key on the same IP is untouched,
# and Pop reinstalls can rotate host keys without BatchMode authenticity failures.
KNOWN_245="${STARLEARNER_245_KNOWN_HOSTS:-$ROOT/deploy/known_hosts_245}"
HOST_ONLY="${HOST##*@}"

SSH_BASE=(
  -o BatchMode=yes
  -o IdentitiesOnly=yes
  -o ConnectTimeout=8
  -o StrictHostKeyChecking=accept-new
  -o UserKnownHostsFile="$KNOWN_245"
  -o GlobalKnownHostsFile=/dev/null
  -o UpdateHostKeys=no
  -i "$KEY"
)
SSH=(ssh "${SSH_BASE[@]}" -p "$PORT" "$HOST")
SCP=(scp "${SSH_BASE[@]}" -P "$PORT")

log() { printf '[fogona-queue] %s\n' "$*"; }

# Pop may have a new host key after reinstall. Refresh our private known_hosts for :PORT only.
refresh_245_host_key() {
  mkdir -p "$(dirname "$KNOWN_245")"
  touch "$KNOWN_245"
  chmod 600 "$KNOWN_245" 2>/dev/null || true
  # Drop stale entries for this host:port (and bare host if someone scanned wrong).
  ssh-keygen -R "[${HOST_ONLY}]:${PORT}" -f "$KNOWN_245" >/dev/null 2>&1 || true
  ssh-keygen -R "$HOST_ONLY" -f "$KNOWN_245" >/dev/null 2>&1 || true
  # Also clear any accidental :2222 pin in the user's default known_hosts (never touch :22 / Mac).
  if [[ -f "$HOME/.ssh/known_hosts" ]]; then
    ssh-keygen -R "[${HOST_ONLY}]:${PORT}" -f "$HOME/.ssh/known_hosts" >/dev/null 2>&1 || true
  fi
  local scan
  scan=$(ssh-keyscan -p "$PORT" -T 5 -H "$HOST_ONLY" 2>/dev/null || true)
  if [[ -n "$scan" ]]; then
    # rewrite file with just this host (one machine, one port)
    printf '%s\n' "$scan" >"$KNOWN_245"
    chmod 600 "$KNOWN_245"
    log "refreshed host key for [${HOST_ONLY}]:${PORT} → $KNOWN_245"
    return 0
  fi
  log "ssh-keyscan failed for [${HOST_ONLY}]:${PORT} (is 245 up?)"
  return 1
}

job_update() {
  local job_path="$1"
  shift
  python3 - "$job_path" "$@" <<'PY'
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
# mirror newest into legacy job.json
from pathlib import Path
legacy = Path(path).resolve().parent.parent / "job.json"
legacy.write_text(json.dumps(job, indent=2) + "\n", encoding="utf-8")
PY
}

host_up() {
  "${SSH[@]}" "echo ok" >/dev/null 2>&1
}

list_pending() {
  python3 - "$JOBS_DIR" "$QUEUE_DIR/job.json" <<'PY'
import json, sys
from pathlib import Path
jobs_dir, legacy = Path(sys.argv[1]), Path(sys.argv[2])
paths = sorted(jobs_dir.glob("*.json"))
if not paths and legacy.is_file():
    print(legacy)
    raise SystemExit(0)
for p in paths:
    try:
        j = json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        continue
    if j.get("status") in ("pending", "failed", "delivering"):
        print(p)
PY
}

deliver_one() {
  local job_path="$1"
  local apk pkg serial remote_apk remote_path out
  apk=$(python3 -c "import json; print(json.load(open('$job_path'))['apk'])")
  pkg=$(python3 -c "import json; print(json.load(open('$job_path'))['package'])")
  serial=$(python3 -c "import json; print(json.load(open('$job_path'))['serial'])")
  [[ -f "$apk" ]] || { job_update "$job_path" failed "apk missing on disk" "missing $apk"; return 1; }

  job_update "$job_path" delivering "245 reachable; copying $(basename "$apk")"
  "${SSH[@]}" "mkdir -p $REMOTE_DIR"
  remote_apk="${REMOTE_DIR}/$(basename "$apk")"
  remote_path=$("${SSH[@]}" "printf %s $remote_apk")
  "${SCP[@]}" "$apk" "$HOST:$remote_path"

  job_update "$job_path" delivering "adb install on fogona $serial"
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
"$ADB" -s "$SERIAL" uninstall com.dylan.antexplorer.garden >/dev/null 2>&1 || true
echo "INSTALL_OK $PKG"
EOS
  ); then
    job_update "$job_path" failed "adb/ssh install failed" "${out:-remote failed}"
    log "install failed ($pkg): $out"
    return 1
  fi
  job_update "$job_path" done "installed $pkg on $serial · ${out##*$'\n'}" ""
  log "done $pkg → $serial"
}

mkdir -p "$JOBS_DIR"

mapfile -t PENDING < <(list_pending || true)
if ((${#PENDING[@]} == 0)); then
  log "no pending jobs — nothing to deliver"
  exit 0
fi

log "one-shot deliver host=$HOST:$PORT jobs=${#PENDING[@]}"
# Always refresh Pop host key before BatchMode SSH (reinstalls change the SHA).
refresh_245_host_key || true
if ! host_up; then
  # One retry after another keyscan in case first scan raced boot.
  sleep 2
  refresh_245_host_key || true
fi
if ! host_up; then
  for jp in "${PENDING[@]}"; do
    job_update "$jp" failed "245 not reachable on :$PORT (or SSH key/auth) — check Pop + fogona USB, then Deliver now" \
      "245 unreachable $HOST:$PORT"
  done
  log "245 unreachable after host-key refresh"
  exit 1
fi

fail=0
for jp in "${PENDING[@]}"; do
  # reset delivering → pending path handled by deliver_one status updates
  if [[ "$(python3 -c "import json; print(json.load(open('$jp')).get('status',''))")" == "delivering" ]]; then
    job_update "$jp" pending "retry after interrupted delivering" ""
  fi
  if ! deliver_one "$jp"; then
    fail=1
  fi
done
exit "$fail"
