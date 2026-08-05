#!/usr/bin/env bash
# Run agent QA suites for interactive-world games (Ant, Garden, Solar).
# Math / Language have no world routing/depth suites — skip them.
#
#   ./tools/run_interactive_qa.sh           # all three
#   ./tools/run_interactive_qa.sh garden    # garden depth + bed approach + plants + seasons
#   ./tools/run_interactive_qa.sh ant
#   ./tools/run_interactive_qa.sh solar
#
# Prefer on-screen Godot (Vulkan/GPU) — often ~10× faster than --headless
# dummy rendering, and PNGs are real. Set QA_HEADLESS=1 only as a last resort.
#
# Exit non-zero if any suite fails. Artifacts: <game>/qa/out/<suite>/<stamp>/
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Inherit a working X11 session when the agent shell has none.
if [[ -z "${DISPLAY:-}" || -z "${XAUTHORITY:-}" ]]; then
  if [[ -S /tmp/.X11-unix/X1 ]]; then
    export DISPLAY="${DISPLAY:-:1}"
  fi
  if [[ -z "${XAUTHORITY:-}" ]]; then
    for xa in /run/user/"${UID:-1000}"/gdm/Xauthority "$HOME/.Xauthority"; do
      [[ -r "$xa" ]] && export XAUTHORITY="$xa" && break
    done
  fi
fi

run_one() {
  local label="$1" script="$2"
  echo ""
  echo "======== QA: $label ========"
  bash "$script"
}

TARGET="${1:-all}"
case "$TARGET" in
  all|interactive)
    run_one "garden/depth" "$ROOT/garden_explorer/qa/run_depth_suite.sh"
    run_one "garden/bed_approach" "$ROOT/garden_explorer/qa/run_bed_approach_suite.sh"
    run_one "garden/bed_plants" "$ROOT/garden_explorer/qa/run_bed_plants_suite.sh"
    run_one "garden/season_trees" "$ROOT/garden_explorer/qa/run_season_trees_suite.sh"
    run_one "ant/chamber" "$ROOT/ant_explorer/qa/run_chamber_suite.sh"
    # Capture-only here — Grok vision majors are a polish gate, not APK-blocking.
    REVIEW=0 run_one "ant/movement_video" "$ROOT/ant_explorer/qa/run_movement_video_suite.sh"
    run_one "solar/flight_mechanics" "$ROOT/solar_system_explorer/qa/run_flight_mechanics_suite.sh"
    ;;
  garden)
    run_one "garden/depth" "$ROOT/garden_explorer/qa/run_depth_suite.sh"
    run_one "garden/bed_approach" "$ROOT/garden_explorer/qa/run_bed_approach_suite.sh"
    run_one "garden/bed_plants" "$ROOT/garden_explorer/qa/run_bed_plants_suite.sh"
    run_one "garden/season_trees" "$ROOT/garden_explorer/qa/run_season_trees_suite.sh"
    ;;
  ant|ants)
    run_one "ant/chamber" "$ROOT/ant_explorer/qa/run_chamber_suite.sh"
    REVIEW=0 run_one "ant/movement_video" "$ROOT/ant_explorer/qa/run_movement_video_suite.sh"
    ;;
  solar|space)
    run_one "solar/flight_mechanics" "$ROOT/solar_system_explorer/qa/run_flight_mechanics_suite.sh"
    ;;
  -h|--help)
    sed -n '2,12p' "$0"
    exit 0
    ;;
  *)
    echo "unknown target: $TARGET (use all|garden|ant|solar)" >&2
    exit 2
    ;;
esac

echo ""
echo "=== interactive QA green ==="
