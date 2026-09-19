#!/usr/bin/env bash
# From Mac Studio (or anywhere): ask 82's portal to queue garden → fogona.
#
#   export STARLEARNER_OPS_USER=dylan
#   export STARLEARNER_OPS_PASS='…'   # same htpasswd as other dylanmccapes.systems sites
#   ./tools/trigger_garden_fogona_queue.sh
#
# Or one-shot:
#   curl -u dylan:PASS -X POST https://starlearner.dylanmccapes.systems/ops/queue/garden \
#     -H 'Accept: application/json'
set -euo pipefail
BASE="${STARLEARNER_OPS_URL:-https://starlearner.dylanmccapes.systems}"
USER="${STARLEARNER_OPS_USER:?set STARLEARNER_OPS_USER}"
PASS="${STARLEARNER_OPS_PASS:?set STARLEARNER_OPS_PASS}"

echo "=== queue status ==="
curl -fsS -u "$USER:$PASS" "$BASE/ops/status.json" | python3 -m json.tool 2>/dev/null \
  || curl -fsS -u "$USER:$PASS" "$BASE/ops/status.json"
echo
echo "=== queue garden ==="
curl -fsS -u "$USER:$PASS" -X POST "$BASE/ops/queue/garden" \
  -H 'Accept: application/json' | python3 -m json.tool 2>/dev/null \
  || curl -fsS -u "$USER:$PASS" -X POST "$BASE/ops/queue/garden" -H 'Accept: application/json'
echo
echo "Watch: $BASE/ops/"
