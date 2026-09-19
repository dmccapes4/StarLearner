#!/usr/bin/env bash
# Queue an APK for on-demand delivery to production fogona via Pop 245.
#
#   ./tools/queue_fogona_deliver.sh garden
#   ./tools/queue_fogona_deliver.sh language
#   ./tools/queue_fogona_deliver.sh garden --build
#   ./tools/queue_fogona_deliver.sh --status
#
# Staging only — does not poll. When 245 is on, press Deliver now on
# https://starlearner.dylanmccapes.systems/ops/
# Multiple pending jobs are kept (garden + language can both sit queued).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=packages.sh
source "$ROOT/tools/packages.sh"
# shellcheck source=devices.sh
source "$ROOT/tools/devices.sh"

QUEUE_DIR="${STARLEARNER_QUEUE_DIR:-$ROOT/deploy/queue}"
JOBS_DIR="$QUEUE_DIR/jobs"
SERIAL="${STARLEARNER_FOGONA_SERIAL:-$SERIAL_COVE}"
TARGET=garden
DO_BUILD=0
APK=""
PKG=""
STATUS_ONLY=0

while (($#)); do
  case "$1" in
    garden|language|ant|math|solar)
      TARGET="$1" ;;
    --build) DO_BUILD=1 ;;
    --apk) shift; APK="${1:?}" ;;
    --package) shift; PKG="${1:?}" ;;
    --serial) shift; SERIAL="${1:?}" ;;
    --status) STATUS_ONLY=1 ;;
    -h|--help)
      sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "unknown: $1" >&2; exit 2 ;;
  esac
  shift
done

mkdir -p "$JOBS_DIR"

# Migrate legacy single job.json into jobs/ once.
if [[ -f "$QUEUE_DIR/job.json" && ! -f "$JOBS_DIR/.migrated" ]]; then
  python3 - "$QUEUE_DIR/job.json" "$JOBS_DIR" <<'PY'
import json, sys
from pathlib import Path
src, jobs_dir = Path(sys.argv[1]), Path(sys.argv[2])
try:
    job = json.loads(src.read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(0)
jid = str(job.get("id") or "legacy")
dest = jobs_dir / f"{jid}.json"
if not dest.exists():
    dest.write_text(json.dumps(job, indent=2) + "\n", encoding="utf-8")
(jobs_dir / ".migrated").write_text("ok\n", encoding="utf-8")
PY
fi

if ((STATUS_ONLY)); then
  python3 - "$JOBS_DIR" "$QUEUE_DIR/job.json" <<'PY'
import json, sys
from pathlib import Path
jobs_dir = Path(sys.argv[1])
legacy = Path(sys.argv[2])
jobs = []
for p in sorted(jobs_dir.glob("*.json")):
    try:
        jobs.append(json.loads(p.read_text(encoding="utf-8")))
    except Exception as e:
        jobs.append({"id": p.stem, "status": "error", "message": str(e)})
if not jobs and legacy.is_file():
    try:
        jobs.append(json.loads(legacy.read_text(encoding="utf-8")))
    except Exception:
        pass
pending = [j for j in jobs if j.get("status") in ("pending", "failed", "delivering")]
out = {
    "jobs": jobs,
    "pending_count": len(pending),
    "status": "pending" if pending else ("idle" if not jobs else "done"),
}
print(json.dumps(out, indent=2))
PY
  exit 0
fi

if [[ -z "$APK" ]]; then
  case "$TARGET" in
    garden)
      PKG="${PKG:-$PKG_GARDEN_EXPLORER}"
      APK="$ROOT/garden_explorer/tools/build/com.dylan.garden_explorer.apk"
      if ((DO_BUILD)); then
        echo "=== build garden ==="
        bash "$ROOT/garden_explorer/tools/build_garden_apk.sh"
      fi
      ;;
    language)
      PKG="${PKG:-$PKG_LANGUAGE_EXPLORER}"
      APK="$ROOT/language_explorer/tools/build/com.dylan.language_explorer.apk"
      if ((DO_BUILD)); then
        echo "=== build language ==="
        (cd "$ROOT/language_explorer" && unset STARLEARNER_HUB_DEV && bash tools/build_language_apk.sh)
      fi
      ;;
    ant)
      PKG="${PKG:-$PKG_ANT_EXPLORER}"
      APK="$ROOT/ant_explorer/tools/build/com.dylan.ant_explorer.apk"
      if ((DO_BUILD)); then
        bash "$ROOT/ant_explorer/tools/build_colony_apk.sh"
      fi
      ;;
    math)
      PKG="${PKG:-$PKG_MATH_EXPLORER}"
      APK="$ROOT/math_explorer/tools/build/com.dylan.math_explorer.apk"
      if ((DO_BUILD)); then
        bash "$ROOT/math_explorer/tools/build_math_apk.sh"
      fi
      ;;
    solar)
      PKG="${PKG:-$PKG_SOLAR_EXPLORER}"
      APK="$ROOT/solar_system_explorer/tools/build/com.dylan.solar_system_explorer.apk"
      if ((DO_BUILD)); then
        bash "$ROOT/solar_system_explorer/tools/build_solar_apk.sh"
      fi
      ;;
  esac
fi

[[ -n "$PKG" ]] || { echo "need --package" >&2; exit 1; }
[[ -f "$APK" ]] || { echo "missing APK: $APK (try --build)" >&2; exit 1; }

STAGED="$QUEUE_DIR/$(basename "$APK")"
cp -f "$APK" "$STAGED"
ID="$(date -u +%Y%m%dT%H%M%SZ)-${TARGET}"
SIZE="$(wc -c <"$STAGED" | tr -d ' ')"
JOB_PATH="$JOBS_DIR/${ID}.json"

python3 - "$JOB_PATH" "$QUEUE_DIR/job.json" "$ID" "$PKG" "$STAGED" "$SERIAL" "$SIZE" "$TARGET" <<'PY'
import json, sys, time
path, legacy, job_id, pkg, apk, serial, size, target = sys.argv[1:9]
job = {
    "id": job_id,
    "target": target,
    "status": "pending",
    "package": pkg,
    "apk": apk,
    "serial": serial,
    "bytes": int(size),
    "created": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "updated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "attempts": 0,
    "last_error": "",
    "log": [f"queued {pkg} ({size} bytes)"],
}
text = json.dumps(job, indent=2) + "\n"
open(path, "w", encoding="utf-8").write(text)
# keep legacy job.json pointing at newest for older tooling
open(legacy, "w", encoding="utf-8").write(text)
print(json.dumps(job, indent=2))
PY

UNIT_SRC="$ROOT/deploy/starlearner-fogona-queue.service"
UNIT_DST="$HOME/.config/systemd/user/starlearner-fogona-queue.service"
mkdir -p "$HOME/.config/systemd/user"
cp -f "$UNIT_SRC" "$UNIT_DST"
systemctl --user daemon-reload 2>/dev/null || true
systemctl --user disable starlearner-fogona-queue.service 2>/dev/null || true
systemctl --user stop starlearner-fogona-queue.service 2>/dev/null || true

echo ""
echo "QUEUED (pending) → serial $SERIAL (cove=$SERIAL_COVE reef=$SERIAL_REEF) · $PKG"
echo "  Deliver installs on whichever handset matches that serial on 245 USB."
echo "  When 245 is on: press Deliver now on /ops/"
echo "  status:  ./tools/queue_fogona_deliver.sh --status"
echo "  portal:  https://starlearner.dylanmccapes.systems/ops/"
