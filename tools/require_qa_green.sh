#!/usr/bin/env bash
# Gate deploys / APK builds on the latest interactive-world QA reports.
#
#   ./tools/require_qa_green.sh              # ant + garden + solar
#   ./tools/require_qa_green.sh garden       # depth + bed_approach + bed_plants + season_trees
#   ./tools/require_qa_green.sh garden --apk path/to.apk
#       → also require newest green report mtime >= APK mtime
#
# Reads <game>/qa/out/<suite>/*/report.json (gitignored). Fails if missing,
# if any check.ok is false, or if --apk is newer than the newest green report.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TARGET="all"
APK=""
while (($#)); do
  case "$1" in
    all|garden|ant|ants|solar|space) TARGET="$1" ;;
    --apk) shift; APK="${1:?--apk needs path}" ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown: $1" >&2; exit 2 ;;
  esac
  shift
done

suites_for() {
  case "$1" in
    all)
      echo "garden_explorer/qa/out/depth_suite"
      echo "garden_explorer/qa/out/bed_approach"
      echo "garden_explorer/qa/out/bed_plants"
      echo "garden_explorer/qa/out/season_trees"
      echo "ant_explorer/qa/out/chamber_suite"
      echo "solar_system_explorer/qa/out/flight_mechanics"
      ;;
    garden)
      echo "garden_explorer/qa/out/depth_suite"
      echo "garden_explorer/qa/out/bed_approach"
      echo "garden_explorer/qa/out/bed_plants"
      echo "garden_explorer/qa/out/season_trees"
      ;;
    ant|ants) echo "ant_explorer/qa/out/chamber_suite" ;;
    solar|space) echo "solar_system_explorer/qa/out/flight_mechanics" ;;
  esac
}

check_suite() {
  local rel="$1"
  local dir="$ROOT/$rel"
  local latest report
  latest="$(ls -1dt "$dir"/*/ 2>/dev/null | head -1 || true)"
  [[ -n "$latest" ]] || { echo "ERROR: no QA runs under $rel — run tools/run_interactive_qa.sh" >&2; return 1; }
  report="${latest}report.json"
  [[ -f "$report" ]] || { echo "ERROR: missing $report" >&2; return 1; }

  python3 - "$report" "$rel" <<'PY'
import json, sys
path, rel = sys.argv[1], sys.argv[2]
d = json.loads(open(path).read())
checks = d.get("checks") or []
bad = [c for c in checks if not c.get("ok")]
ok = len(checks) - len(bad)
print(f"OK  {rel}: passed={ok} failed={len(bad)}  ({path})")
if bad:
    for c in bad:
        print(f" FAIL {c.get('name')} — {c.get('detail')}", file=sys.stderr)
    sys.exit(1)
PY

  if [[ -n "$APK" && -f "$APK" ]]; then
    local apk_m report_m skew grace
    apk_m="$(stat -c %Y "$APK")"
    report_m="$(stat -c %Y "$report")"
    # Build scripts run QA then package; APK mtime is naturally a few minutes
    # newer. Allow a same-session skew (default 20 min).
    grace="${QA_APK_GRACE_SEC:-1200}"
    skew=$((apk_m - report_m))
    if (( skew > grace )); then
      echo "ERROR: $APK is ${skew}s newer than green QA at $report (grace ${grace}s)" >&2
      echo "       Re-run tools/run_interactive_qa.sh after code changes." >&2
      return 1
    fi
  fi
}

echo "=== require QA green ($TARGET) ==="
while read -r rel; do
  [[ -z "$rel" ]] && continue
  check_suite "$rel"
done < <(suites_for "$TARGET")
echo "QA gate passed"
