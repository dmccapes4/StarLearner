#!/usr/bin/env bash
# Build, validate, bundle, and deploy the complete Star Learner appliance.
# Existing game progress is preserved; only launcher media cache is refreshed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=packages.sh
source "$ROOT/tools/packages.sh"
# shellcheck source=adb_helpers.sh
source "$ROOT/tools/adb_helpers.sh"
CATALOG="$ROOT/ant_explorer/tools/catalog.json"
LAUNCHER="$ROOT/ant_explorer/kiosk_placeholder"
LAUNCHER_APK="$LAUNCHER/app/build/outputs/apk/release/app-release.apk"
BUILD_APKS=true
PREPARE=true
DEPLOY=true
BUNDLE="$ROOT/ant_explorer/tools/build/full_deploy"
ADB_BIN="${ADB:-adb}"
SERIAL=""
REQUIRE_KIOSK=false
VALIDATE=false

usage() {
  cat <<'EOF'
Usage: tools/full_deploy.sh [options]
  --prepare-only       Build/validate bundle without deploying
  --deploy-only        Deploy an existing bundle without building
  --skip-build         Validate/package current APKs, then deploy
  --bundle DIR         Bundle directory
  --adb PATH           adb executable (adb.exe under WSL is supported)
  --serial SERIAL      Explicit target device serial
  --require-kiosk      Fail unless device-owner lock-task is active
  --validate           Run tools/validate_deploy.sh after deploy
  -h, --help           Show help
EOF
}

while (($#)); do
  case "$1" in
    --prepare-only) DEPLOY=false ;;
    --deploy-only) BUILD_APKS=false; PREPARE=false ;;
    --skip-build) BUILD_APKS=false ;;
    --bundle) shift; BUNDLE="${1:?--bundle requires DIR}" ;;
    --adb) shift; ADB_BIN="${1:?--adb requires PATH}" ;;
    --serial) shift; SERIAL="${1:?--serial requires SERIAL}" ;;
    --require-kiosk) REQUIRE_KIOSK=true ;;
    --validate) VALIDATE=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

APKS=(
  "$ROOT/ant_explorer/tools/build/com.dylan.star_learner.apk"
  "$ROOT/ant_explorer/tools/build/com.dylan.ant_explorer.apk"
  "$ROOT/garden_explorer/tools/build/com.dylan.antexplorer.garden.apk"
  "$ROOT/solar_system_explorer/tools/build/com.dylan.solar_system_explorer.apk"
  "$ROOT/math_explorer/tools/build/com.dylan.math_explorer.apk"
  "$ROOT/language_explorer/tools/build/com.dylan.language_explorer.apk"
)
VIDEOS=(
  "$ROOT/ant_explorer/docs/demo/ant_explorer_explainer.mp4"
  "$ROOT/garden_explorer/docs/demo/garden_explorer_explainer.mp4"
  "$ROOT/solar_system_explorer/docs/demo/solar_system_explorer_explainer.mp4"
  "$ROOT/math_explorer/docs/demo/math_explorer_explainer.mp4"
  "$ROOT/language_explorer/docs/demo/language_explorer_explainer.mp4"
)

die() { echo "ERROR: $*" >&2; exit 1; }
required() { [[ -s "$1" ]] || die "missing or empty: $1"; }

find_aapt() {
  local sdk="${ANDROID_HOME:-$HOME/Android/Sdk}" latest
  latest="$(ls -1d "$sdk"/build-tools/* 2>/dev/null | sort -V | tail -1 || true)"
  [[ -x "$latest/aapt" ]] && printf '%s\n' "$latest/aapt"
}

build_all() {
  echo "=== Build all five games ==="
  "$ROOT/ant_explorer/tools/build_colony_apk.sh"
  "$ROOT/garden_explorer/tools/build_garden_apk.sh"
  "$ROOT/solar_system_explorer/tools/build_solar_apk.sh"
  "$ROOT/math_explorer/tools/build_math_apk.sh"
  "$ROOT/language_explorer/tools/build_language_apk.sh"

  echo "=== Build launcher with canonical catalog and current tiles ==="
  cmp -s "$CATALOG" "$LAUNCHER/app/src/main/assets/catalog.json" ||
    cp -f "$CATALOG" "$LAUNCHER/app/src/main/assets/catalog.json"
  (
    cd "$LAUNCHER"
    chmod +x gradlew
    ./gradlew assembleRelease --no-daemon
  )
  required "$LAUNCHER_APK"
  mkdir -p "$(dirname "${APKS[0]}")"
  cp -f "$LAUNCHER_APK" "${APKS[0]}"
}

validate_sources() {
  local i aapt actual tile
  required "$CATALOG"
  for i in "${!APKS[@]}"; do
    required "${APKS[$i]}"
  done
  for i in "${!VIDEOS[@]}"; do
    required "${VIDEOS[$i]}"
  done

  python3 - "$CATALOG" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
want = {
 "com.dylan.ant_explorer", "com.dylan.antexplorer.garden",
 "com.dylan.solar_system_explorer", "com.dylan.math_explorer",
 "com.dylan.language_explorer",
}
got = {a["package"] for a in d["apps"]}
assert got == want, f"catalog package mismatch: got={sorted(got)} want={sorted(want)}"
assert len(d["apps"]) == 5, "catalog must contain exactly five games"
for a in d["apps"]:
    for key in ("id", "label", "package", "activity", "tile", "video"):
        assert a.get(key), f"{a.get('id', '?')} lacks {key}"
print("catalog: five complete game entries")
PY

  aapt="$(find_aapt)"
  [[ -n "$aapt" ]] || die "Android aapt not found"
  for i in "${!APKS[@]}"; do
    actual="$("$aapt" dump badging "${APKS[$i]}" |
      awk -F"'" '/^package: name=/{print $2; exit}')"
    [[ "$actual" == "${PACKAGES[$i]}" ]] ||
      die "$(basename "${APKS[$i]}") package is $actual, expected ${PACKAGES[$i]}"
  done
  for tile in tile_ants tile_garden tile_solar tile_math tile_language; do
    "$aapt" dump resources "${APKS[0]}" | grep -q "$tile" ||
      die "launcher APK lacks drawable $tile"
  done
  for i in 1 2 3 4 5; do
    unzip -Z1 "${APKS[$i]}" |
      awk '$0=="assets/project.binary"{found=1} END{exit !found}' ||
      die "$(basename "${APKS[$i]}") lacks Godot project.binary"
  done
  echo "APKs: package IDs, launcher tiles, and Godot payloads verified"
}

make_bundle() {
  local f
  echo "=== Create portable deployment bundle ==="
  rm -rf "$BUNDLE"
  mkdir -p "$BUNDLE/apks" "$BUNDLE/videos"
  cp -f "$CATALOG" "$BUNDLE/catalog.json"
  for f in "${APKS[@]}"; do cp -f "$f" "$BUNDLE/apks/"; done
  for f in "${VIDEOS[@]}"; do cp -f "$f" "$BUNDLE/videos/"; done
  cp -f "$ROOT/tools/full_deploy.sh" "$BUNDLE/full_deploy.sh"
  (
    cd "$BUNDLE"
    find apks videos -type f -print0 | sort -z |
      xargs -0 sha256sum > SHA256SUMS
    sha256sum catalog.json >> SHA256SUMS
  )
  echo "bundle: $BUNDLE ($(du -sh "$BUNDLE" | awk '{print $1}'))"
}

configure_adb() {
  command -v "$ADB_BIN" >/dev/null 2>&1 || [[ -x "$ADB_BIN" ]] ||
    die "adb executable not found: $ADB_BIN"
  ADB_CMD=("$ADB_BIN")
  [[ -n "$SERIAL" ]] && ADB_CMD+=(-s "$SERIAL")
  "${ADB_CMD[@]}" start-server >/dev/null
  if [[ -z "$SERIAL" ]]; then
    mapfile -t DEVICES < <("$ADB_BIN" devices |
      awk 'NR>1 && $2=="device" {print $1}')
    ((${#DEVICES[@]} == 1)) ||
      die "expected exactly one authorized adb device, found ${#DEVICES[@]}; use --serial"
    SERIAL="${DEVICES[0]}"
    ADB_CMD=("$ADB_BIN" -s "$SERIAL")
  fi
  [[ "$("${ADB_CMD[@]}" get-state | tr -d '\r')" == "device" ]] ||
    die "device $SERIAL is not ready"
}

wait_for_adb() {
  local state=""
  state="$("${ADB_CMD[@]}" get-state 2>/dev/null | tr -d '\r' || true)"
  [[ "$state" == "device" ]] && return 0
  echo "adb is $state; reconnecting $SERIAL ..."
  "$ADB_BIN" reconnect offline >/dev/null 2>&1 || true
  timeout 45 "${ADB_CMD[@]}" wait-for-device || return 1
  [[ "$("${ADB_CMD[@]}" get-state 2>/dev/null | tr -d '\r' || true)" == "device" ]]
}

install_apk() {
  local apk="$1" attempt
  apk="$(local_path_for_adb "$apk")"
  for attempt in 1 2 3; do
    wait_for_adb || true
    if "${ADB_CMD[@]}" install --no-streaming -r -g "$apk"; then
      return 0
    fi
    echo "install attempt $attempt failed for $(basename "$apk"); retrying ..." >&2
    sleep 5
  done
  die "could not install $(basename "$apk") after three attempts"
}

deploy_bundle() {
  local i file remote_size local_size
  required "$BUNDLE/SHA256SUMS"
  (
    cd "$BUNDLE"
    sha256sum -c SHA256SUMS
  )
  configure_adb

  echo "=== Target $SERIAL ==="
  "${ADB_CMD[@]}" shell getprop ro.product.model
  "${ADB_CMD[@]}" shell getprop ro.build.version.release
  "${ADB_CMD[@]}" shell df -h /data | tail -1

  echo "=== Push catalog and fresh launcher media ==="
  "${ADB_CMD[@]}" shell mkdir -p /sdcard/AntPhone/videos \
    /data/local/tmp/antphone_videos
  "${ADB_CMD[@]}" shell rm -f '/sdcard/AntPhone/videos/*' \
    '/data/local/tmp/antphone_videos/*'
  "${ADB_CMD[@]}" push "$(local_path_for_adb "$BUNDLE/catalog.json")" /sdcard/AntPhone/catalog.json
  "${ADB_CMD[@]}" push "$(local_path_for_adb "$BUNDLE/catalog.json")" /data/local/tmp/antphone_catalog.json
  "${ADB_CMD[@]}" shell chmod 644 /data/local/tmp/antphone_catalog.json
  for file in "$BUNDLE"/videos/*.mp4; do
    local win_file
    win_file="$(local_path_for_adb "$file")"
    "${ADB_CMD[@]}" push "$win_file" "/sdcard/AntPhone/videos/$(basename "$file")"
    "${ADB_CMD[@]}" push "$win_file" "/data/local/tmp/antphone_videos/$(basename "$file")"
    "${ADB_CMD[@]}" shell chmod 644 \
      "/data/local/tmp/antphone_videos/$(basename "$file")"
  done

  echo "=== Install games, then launcher ==="
  for i in 1 2 3 4 5; do
    # Push install is slower but more reliable than Android's streamed
    # PackageInstaller transport on these Moto G Play units.
    install_apk "$BUNDLE/apks/${PACKAGES[$i]}.apk"
  done
  install_apk "$BUNDLE/apks/${PACKAGES[0]}.apk"
  wait_for_adb || die "device did not return after APK installation"

  # The launcher copies external videos to private storage. Remove derived
  # copies so an updated video with the same filename is never stale.
  if "${ADB_CMD[@]}" shell su -c id 2>/dev/null | grep -q 'uid=0'; then
    "${ADB_CMD[@]}" shell su -c \
      'rm -rf /data/data/com.dylan.star_learner/files/videos'
  elif ! "${ADB_CMD[@]}" shell dpm list-owners |
      grep -q com.dylan.star_learner; then
    # Developer/test phones cannot use root to remove the private cache.
    # Clearing launcher-only data is safe; game progress belongs to game APKs.
    "${ADB_CMD[@]}" shell pm clear com.dylan.star_learner >/dev/null
  else
    echo "WARNING: root unavailable; launcher may retain same-length cached videos" >&2
  fi

  echo "=== Restore appliance policy and launch home ==="
  "${ADB_CMD[@]}" shell settings put system user_rotation 1
  "${ADB_CMD[@]}" shell settings put system accelerometer_rotation 0
  "${ADB_CMD[@]}" shell settings put global policy_control immersive.full='*'
  "${ADB_CMD[@]}" shell settings put global stay_on_while_plugged_in 3
  "${ADB_CMD[@]}" shell settings put system screen_brightness_mode 0
  "${ADB_CMD[@]}" shell settings put system screen_brightness 220
  "${ADB_CMD[@]}" shell settings put secure lock_to_app_enabled 1
  "${ADB_CMD[@]}" shell settings put secure lock_to_app_exit_locked 0
  "${ADB_CMD[@]}" shell settings put secure lockscreen.disabled 1 || true
  "${ADB_CMD[@]}" shell wm dismiss-keyguard || true
  "${ADB_CMD[@]}" shell cmd role add-role-holder android.app.role.HOME \
    com.dylan.star_learner
  "${ADB_CMD[@]}" shell am task lock stop 2>/dev/null || true
  "${ADB_CMD[@]}" shell am force-stop com.dylan.star_learner
  "${ADB_CMD[@]}" shell am start -n com.dylan.star_learner/.MainActivity
  sleep 2

  echo "=== Verify complete installation ==="
  for i in "${!PACKAGES[@]}"; do
    "${ADB_CMD[@]}" shell pm path "${PACKAGES[$i]}" |
      grep -q '^package:' || die "package missing after install: ${PACKAGES[$i]}"
    "${ADB_CMD[@]}" shell cmd package resolve-activity --brief \
      -a android.intent.action.MAIN -c android.intent.category.LAUNCHER \
      "${PACKAGES[$i]}" >/dev/null ||
      die "package is not launchable: ${PACKAGES[$i]}"
  done
  for file in "$BUNDLE"/videos/*.mp4; do
    local_size="$(stat -c %s "$file")"
    remote_size="$("${ADB_CMD[@]}" shell stat -c %s \
      "/data/local/tmp/antphone_videos/$(basename "$file")" | tr -d '\r')"
    [[ "$local_size" == "$remote_size" ]] ||
      die "video size mismatch: $(basename "$file")"
  done
  local is_owner=false
  if "${ADB_CMD[@]}" shell dpm list-owners | grep -q com.dylan.star_learner; then
    is_owner=true
  elif "$REQUIRE_KIOSK"; then
    die "Star Learner is not device owner"
  else
    echo "WARNING: test device has accounts and no device owner; lock-task is unavailable" >&2
  fi
  local activity
  activity="$("${ADB_CMD[@]}" shell dumpsys activity activities)"
  if "$is_owner"; then
    grep -q 'topResumedActivity=.*com.dylan.star_learner/.MainActivity' <<<"$activity" ||
      die "launcher is not top-resumed"
    grep -q 'mLockTaskModeState=LOCKED' <<<"$activity" ||
      die "enterprise lock-task is not LOCKED"
  else
    local window
    window="$("${ADB_CMD[@]}" shell dumpsys window)"
    if ! grep -q 'topResumedActivity=.*com.dylan.star_learner/.MainActivity' <<<"$activity" &&
       ! grep -q 'mFocusedApp=.*com.dylan.star_learner/.MainActivity' <<<"$window"; then
      die "launcher is not the focused app"
    fi
  fi
  echo "FULL DEPLOY OK: $SERIAL"
  if "$VALIDATE"; then
    "$ROOT/tools/validate_deploy.sh" "$SERIAL"
  fi
}

if "$BUILD_APKS"; then
  build_all
fi
if "$PREPARE"; then
  validate_sources
  make_bundle
else
  [[ -d "$BUNDLE" ]] || die "bundle does not exist: $BUNDLE"
fi
"$DEPLOY" && deploy_bundle
