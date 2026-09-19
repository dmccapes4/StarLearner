#!/usr/bin/env bash
# Deploy staged Star Learner APKs from Mac Studio (~/starlearner_apks)
# through Pop 245 to production fogona (USB on 245).
#
# On Mac Studio (108 / 230):
#   cd ~/starlearner_apks
#   ./deploy_to_fogona.sh                  # all *.apk here
#   ./deploy_to_fogona.sh garden language  # by short name
#   ./deploy_to_fogona.sh com.dylan.garden_explorer.apk
#
# Path: Mac → 245 (LAN :22 preferred, else WAN :2222) → adb → fogona ZL8326G8ND
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERIAL="${STARLEARNER_FOGONA_SERIAL:-ZL8326G8ND}"
REMOTE_INBOX='~/star_learner/inbox'
USER245="${STARLEARNER_245_USER:-dylanmccapes}"
LAN_HOST="${STARLEARNER_245_LAN:-192.168.0.245}"
WAN_HOST="${STARLEARNER_245_WAN:-104.53.183.230}"
WAN_PORT="${STARLEARNER_245_PORT:-2222}"
KEY="${STARLEARNER_245_KEY:-}"

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new)
[[ -n "$KEY" ]] && SSH_OPTS+=(-o IdentitiesOnly=yes -i "$KEY")

log() { printf '[deploy-fogona] %s\n' "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

pick_245() {
  # Prefer LAN from Mac Studio; fall back to UniFi WAN forward :2222.
  if ssh "${SSH_OPTS[@]}" "${USER245}@${LAN_HOST}" "echo ok" >/dev/null 2>&1; then
    SSH=(ssh "${SSH_OPTS[@]}" "${USER245}@${LAN_HOST}")
    SCP=(scp "${SSH_OPTS[@]}")
    SCP_HOST="${USER245}@${LAN_HOST}"
    log "using 245 LAN ${USER245}@${LAN_HOST}:22"
    return 0
  fi
  if ssh "${SSH_OPTS[@]}" -p "$WAN_PORT" "${USER245}@${WAN_HOST}" "echo ok" >/dev/null 2>&1; then
    SSH=(ssh "${SSH_OPTS[@]}" -p "$WAN_PORT" "${USER245}@${WAN_HOST}")
    SCP=(scp "${SSH_OPTS[@]}" -P "$WAN_PORT")
    SCP_HOST="${USER245}@${WAN_HOST}"
    log "using 245 WAN ${USER245}@${WAN_HOST}:${WAN_PORT}"
    return 0
  fi
  die "245 unreachable (tried ${LAN_HOST}:22 and ${WAN_HOST}:${WAN_PORT}). Is Pop on?"
}

resolve_apks() {
  local arg base
  APKS=()
  if (($# == 0)); then
    while IFS= read -r -d '' f; do
      APKS+=("$f")
    done < <(find "$DIR" -maxdepth 1 -type f -name 'com.dylan.*.apk' -print0 | sort -z)
    ((${#APKS[@]})) || die "no com.dylan.*.apk in $DIR"
    return
  fi
  for arg in "$@"; do
    case "$arg" in
      *.apk)
        [[ -f "$DIR/$arg" ]] && APKS+=("$DIR/$arg")
        [[ -f "$arg" ]] && APKS+=("$arg")
        [[ -f "$DIR/$arg" || -f "$arg" ]] || die "missing APK: $arg"
        ;;
      garden|garden_explorer)
        base="$DIR/com.dylan.garden_explorer.apk"
        [[ -f "$base" ]] || die "missing $base"
        APKS+=("$base")
        ;;
      language|language_explorer)
        base="$DIR/com.dylan.language_explorer.apk"
        [[ -f "$base" ]] || die "missing $base"
        APKS+=("$base")
        ;;
      ant|ant_explorer|colony)
        base="$DIR/com.dylan.ant_explorer.apk"
        [[ -f "$base" ]] || die "missing $base"
        APKS+=("$base")
        ;;
      math|math_explorer)
        base="$DIR/com.dylan.math_explorer.apk"
        [[ -f "$base" ]] || die "missing $base"
        APKS+=("$base")
        ;;
      solar|solar_system_explorer)
        base="$DIR/com.dylan.solar_system_explorer.apk"
        [[ -f "$base" ]] || die "missing $base"
        APKS+=("$base")
        ;;
      launcher|star_learner)
        base="$DIR/com.dylan.star_learner.apk"
        [[ -f "$base" ]] || die "missing $base"
        APKS+=("$base")
        ;;
      *)
        die "unknown target: $arg (use garden|language|ant|math|solar|launcher or *.apk)"
        ;;
    esac
  done
}

pkg_from_name() {
  local bn="$1"
  bn="${bn%.apk}"
  printf '%s\n' "$bn"
}

install_one() {
  local apk="$1"
  local bn pkg remote_apk remote_path out
  bn="$(basename "$apk")"
  pkg="$(pkg_from_name "$bn")"
  [[ -f "$apk" ]] || die "missing $apk"

  log "copy $bn → 245 inbox"
  "${SSH[@]}" "mkdir -p $REMOTE_INBOX"
  remote_apk="${REMOTE_INBOX}/${bn}"
  remote_path=$("${SSH[@]}" "printf %s $remote_apk")
  "${SCP[@]}" "$apk" "${SCP_HOST}:${remote_path}"

  log "adb install on fogona $SERIAL ($pkg)"
  if ! out=$("${SSH[@]}" bash -s -- "$remote_path" "$SERIAL" "$pkg" 2>&1 <<'EOS'
set -euo pipefail
APK="$1"; SERIAL="$2"; PKG="$3"
ADB="$(command -v adb || true)"
if [[ -z "$ADB" ]]; then
  for c in "$HOME/Android/Sdk/platform-tools/adb" /usr/bin/adb /opt/homebrew/bin/adb; do
    [[ -x "$c" ]] && ADB=$c && break
  done
fi
[[ -n "$ADB" ]] || { echo "adb not found on 245 — install platform-tools" >&2; exit 3; }
"$ADB" start-server >/dev/null 2>&1 || true
state="$("$ADB" -s "$SERIAL" get-state 2>/dev/null || true)"
if [[ "$state" != "device" ]]; then
  echo "fogona not ready (state=${state:-none}). Plug USB on 245?" >&2
  "$ADB" devices -l >&2 || true
  exit 4
fi
"$ADB" -s "$SERIAL" install --no-streaming -r -g "$APK"
"$ADB" -s "$SERIAL" shell pm path "$PKG"
# legacy garden id — remove if present
"$ADB" -s "$SERIAL" uninstall com.dylan.antexplorer.garden >/dev/null 2>&1 || true
echo "INSTALL_OK $PKG"
EOS
  ); then
    echo "$out" >&2
    die "install failed for $pkg"
  fi
  log "OK $pkg · ${out##*$'\n'}"
}

usage() {
  sed -n '2,14p' "$0"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

resolve_apks "$@"
pick_245

log "APKs (${#APKS[@]}):"
for a in "${APKS[@]}"; do
  ls -lh "$a" | awk '{print "  "$0}'
done

fail=0
for a in "${APKS[@]}"; do
  if ! install_one "$a"; then
    fail=1
  fi
done

log "verify packages on fogona"
"${SSH[@]}" "adb -s $SERIAL shell pm list packages" | grep com.dylan || true

exit "$fail"
