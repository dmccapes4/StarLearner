#!/usr/bin/env bash
for base in /mnt/c/Users/dylan/StarLearner /mnt/c/Users/dylan/dev/star_learning; do
  echo "=== $base ==="
  if [[ -d "$base/.git" ]]; then
    git -C "$base" log -1 --oneline 2>/dev/null
  fi
  for g in ant_explorer garden_explorer language_explorer math_explorer solar_system_explorer; do
    p="$base/$g/game"
    ep="$p/export_presets.cfg"
    gw="$p/android/build/gradlew"
    [[ -f "$ep" ]] && echo "  $g export_presets OK" || echo "  $g export_presets MISSING"
    [[ -f "$gw" ]] && echo "  $g android/build OK" || echo "  $g android/build MISSING"
  done
done
