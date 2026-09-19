#!/usr/bin/env bash
# Tap-mash / latest-wins walk video suite + optional vision review.
#
# Stresses: bed↔bed retarget under mash, ground navigate while walking,
# cancellable water VO, bed path-dirt near-miss. See docs/REPORT_TAP_MASHING.md.
#
#   ./qa/run_mash_video_suite.sh
#   REVIEW=0 ./qa/run_mash_video_suite.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export WALK_CLIP_SET=mash
export WALK_TARGET_S="${WALK_TARGET_S:-10}"
export REVIEW="${REVIEW:-1}"
export REVIEW_MAX_FRAMES="${REVIEW_MAX_FRAMES:-12}"
exec "$ROOT/qa/run_walk_video_suite.sh" "$@"
