#!/usr/bin/env bash
# Verify every Star Learner APK embeds the canonical package id from packages.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=packages.sh
source "$ROOT/tools/packages.sh"
BT="${ANDROID_HOME:-$HOME/Android/Sdk}/build-tools/36.0.0/aapt"
[[ -x "$BT" ]] || BT="$(ls -d "$HOME"/Android/Sdk/build-tools/*/aapt 2>/dev/null | sort -V | tail -1)"

check() {
  local apk="$1" want="$2"
  [[ -f "$apk" ]] || { echo "MISSING $apk"; return 1; }
  local got
  got=$("$BT" dump badging "$apk" | awk -F"'" '/^package: /{print $2; exit}')
  if [[ "$got" == "$want" ]]; then
    echo "OK  $want"
  else
    echo "BAD $apk  got=$got want=$want"
    return 1
  fi
}

fail=0
check "$ROOT/ant_explorer/tools/build/com.dylan.star_learner.apk" "$PKG_LAUNCHER" || fail=1
check "$ROOT/ant_explorer/tools/build/com.dylan.ant_explorer.apk" "$PKG_ANT_EXPLORER" || fail=1
check "$ROOT/garden_explorer/tools/build/com.dylan.antexplorer.garden.apk" "$PKG_GARDEN_EXPLORER" || fail=1
check "$ROOT/solar_system_explorer/tools/build/com.dylan.solar_system_explorer.apk" "$PKG_SOLAR_EXPLORER" || fail=1
check "$ROOT/math_explorer/tools/build/com.dylan.math_explorer.apk" "$PKG_MATH_EXPLORER" || fail=1
check "$ROOT/language_explorer/tools/build/com.dylan.language_explorer.apk" "$PKG_LANGUAGE_EXPLORER" || fail=1
exit "$fail"
