#!/usr/bin/env bash
# Routing-focused walk video suite + Grok vision review.
#
# Stresses shed taps from beside the westernmost south bed (bed_3) and other
# short-corridor walks. Dumps mechanics/ sources + nav_diagnostics.json into
# the stamp folder for the reviewer.
#
#   ./qa/run_route_video_suite.sh
#   REVIEW=0 ./qa/run_route_video_suite.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export WALK_CLIP_SET=routing
export WALK_TARGET_S="${WALK_TARGET_S:-10}"
export REVIEW="${REVIEW:-1}"
# More second-ticks for 10s clips
export REVIEW_MAX_FRAMES="${REVIEW_MAX_FRAMES:-12}"
exec "$ROOT/qa/run_walk_video_suite.sh" "$@"
