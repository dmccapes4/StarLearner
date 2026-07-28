#!/usr/bin/env bash
# Ensure every Godot game has export_presets.cfg and android/build gradle template.
# Safe to re-run. Uses language_explorer as the canonical Android template donor.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

find_template() {
  local t
  for t in \
    "$ROOT/language_explorer/game/android/build" \
    "/mnt/c/Users/dylan/StarLearner/language_explorer/game/android/build"; do
    if [[ -x "$t/gradlew" ]]; then
      echo "$t"
      return 0
    fi
  done
  return 1
}

TEMPLATE="$(find_template)" || {
  echo "ERROR: no language_explorer android/build template (gradlew)" >&2
  exit 1
}
echo "=== Android template: $TEMPLATE ==="

games=(ant_explorer garden_explorer math_explorer solar_system_explorer language_explorer)
for g in "${games[@]}"; do
  game="$ROOT/$g/game"
  [[ -d "$game" ]] || continue
  ep="$game/export_presets.cfg"
  if [[ ! -f "$ep" ]]; then
    echo "ERROR: missing $ep (commit export_presets.cfg to git)" >&2
    exit 1
  fi
  dst="$game/android/build"
  if [[ ! -x "$dst/gradlew" ]]; then
    echo "=== seed $g/android/build from template ==="
    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst"
    cp -a "$TEMPLATE" "$dst"
  else
    echo "OK  $g/android/build"
  fi
done
echo "BOOTSTRAP GODOT ANDROID OK"
