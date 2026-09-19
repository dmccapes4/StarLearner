#!/usr/bin/env bash
# Manual recovery / fogona garden install when the queue worker cannot finish.
# Canonical package: com.dylan.garden_explorer (NOT com.dylan.antexplorer.garden).
#
# Typical paths:
#   A) 245 up + fogona USB  → install from 82 via :2222
#   B) 245 down             → install from Mac Studio staging ~/starlearner_apks
#   C) Local reef USB       → rebuild_and_install_garden.sh
set -euo pipefail

PKG=com.dylan.garden_explorer
SERIAL_FOGONA=ZL8326G8ND
SERIAL_REEF=ZL8326FWKM
APK_82="${HOME}/dev/star_learning/garden_explorer/tools/build/${PKG}.apk"
APK_QUEUE="${HOME}/dev/star_learning/deploy/queue/${PKG}.apk"
APK_230="~/starlearner_apks/${PKG}.apk"
HOST_245="${STARLEARNER_245_HOST:-dylanmccapes@104.53.183.230}"
PORT_245="${STARLEARNER_245_PORT:-2222}"
HOST_230="${STARLEARNER_230_HOST:-2ndopinionmd@104.53.183.230}"

usage() {
  sed -n '2,20p' "$0"
  cat <<EOF

Usage:
  $0 status
  $0 push-230                 # copy current 82 APK → Mac Studio ~/starlearner_apks
  $0 install-245              # 82 → 245 inbox → adb install fogona
  $0 install-from-230-via-245 # Mac APK → 245 → fogona (when 82 APK path awkward)
  $0 install-reef             # USB reef on 82
  $0 requeue                  # re-queue pending job on 82 worker
EOF
}

need_apk_82() {
  local a="$APK_82"
  [[ -f "$a" ]] || a="$APK_QUEUE"
  [[ -f "$a" ]] || { echo "missing APK on 82: $APK_82" >&2; exit 1; }
  printf '%s\n' "$a"
}

cmd_status() {
  echo "=== 82 queue ==="
  "$HOME/dev/star_learning/tools/queue_fogona_deliver.sh" --status || true
  echo "=== 82 APK ==="
  ls -lh "$APK_82" "$APK_QUEUE" 2>/dev/null || true
  echo "=== 230 staged ==="
  ssh -o BatchMode=yes -o ConnectTimeout=8 "$HOST_230" "ls -lh ~/starlearner_apks/${PKG}.apk* 2>/dev/null || echo none"
  echo "=== 245 :${PORT_245} ==="
  ssh -o BatchMode=yes -o ConnectTimeout=5 -p "$PORT_245" "$HOST_245" 'echo 245_OK; adb devices -l' 2>&1 || echo "245 unreachable"
}

cmd_push_230() {
  local a; a="$(need_apk_82)"
  ssh -o BatchMode=yes "$HOST_230" 'mkdir -p ~/starlearner_apks'
  scp -o BatchMode=yes "$a" "$HOST_230:starlearner_apks/${PKG}.apk"
  ssh -o BatchMode=yes "$HOST_230" "date -u +%Y-%m-%dT%H:%M:%SZ > ~/starlearner_apks/${PKG}.apk.staged_at"
  echo "staged on 230: ~/starlearner_apks/${PKG}.apk"
}

cmd_install_245() {
  local a; a="$(need_apk_82)"
  # Last gate before shipping to a fogona: green garden QA (depth + bed approach).
  if [[ "${SKIP_QA:-0}" != "1" ]]; then
    bash "$HOME/dev/star_learning/tools/require_qa_green.sh" garden --apk "$a"
  fi
  ssh -o BatchMode=yes -p "$PORT_245" "$HOST_245" 'mkdir -p ~/star_learner/inbox'
  remote=$(ssh -o BatchMode=yes -p "$PORT_245" "$HOST_245" "printf %s ~/star_learner/inbox/${PKG}.apk")
  scp -o BatchMode=yes -P "$PORT_245" "$a" "$HOST_245:$remote"
  ssh -o BatchMode=yes -p "$PORT_245" "$HOST_245" bash -s -- "$remote" "$SERIAL_FOGONA" "$PKG" <<'EOS'
set -euo pipefail
APK="$1"; SERIAL="$2"; PKG="$3"
ADB="$(command -v adb || true)"
[[ -n "$ADB" ]] || ADB="$HOME/Android/Sdk/platform-tools/adb"
"$ADB" -s "$SERIAL" install --no-streaming -r -g "$APK"
"$ADB" -s "$SERIAL" shell pm path "$PKG"
# drop legacy twin if present
"$ADB" -s "$SERIAL" uninstall com.dylan.antexplorer.garden >/dev/null 2>&1 || true
# point catalog at garden_explorer if override exists
if [[ -f ~/star_learner/inbox/catalog.json ]]; then
  "$ADB" -s "$SERIAL" push ~/star_learner/inbox/catalog.json /sdcard/AntPhone/catalog.json || true
fi
echo INSTALL_OK
EOS
}

cmd_install_reef() {
  bash "$HOME/dev/star_learning/garden_explorer/tools/rebuild_and_install_garden.sh" "$SERIAL_REEF"
}

cmd_requeue() {
  "$HOME/dev/star_learning/tools/queue_fogona_deliver.sh" garden
}

case "${1:-}" in
  status) cmd_status ;;
  push-230) cmd_push_230 ;;
  install-245) cmd_install_245 ;;
  install-reef) cmd_install_reef ;;
  requeue) cmd_requeue ;;
  -h|--help|"") usage ;;
  *) echo "unknown: $1" >&2; usage; exit 2 ;;
esac
