#!/usr/bin/env bash
# Watering-can + bed approach walk video suite + Grok vision review.
#
# Stresses: shed can → bed face panes, north-bed path lip (not north loop),
# thirst clear on arrive, double-tap VO. Dumps mechanics/ + code review into
# the stamp folder for the reviewer.
#
#   ./qa/run_water_video_suite.sh
#   REVIEW=0 ./qa/run_water_video_suite.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export WALK_CLIP_SET=water
export WALK_TARGET_S="${WALK_TARGET_S:-10}"
export REVIEW="${REVIEW:-1}"
export REVIEW_MAX_FRAMES="${REVIEW_MAX_FRAMES:-12}"
exec "$ROOT/qa/run_walk_video_suite.sh" "$@"
