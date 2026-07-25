#!/usr/bin/env bash
# Download + trim per-plant media into the Godot app tree.
#
# Usage:
#   ./build_plant_media.sh
#   ./build_plant_media.sh --id tomato
#   ./build_plant_media.sh --kind sprout
#   ./build_plant_media.sh --force
#
# Manifest columns (TAB): plant_id  kind  start  end  url
# Output: ../game/assets/plants/<plant_id>/<kind>.ogv (+ .mp4)

set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$ROOT/plant_media.tsv"
OUT_ROOT="$ROOT/../game/assets/plants"
SRC_DIR="$ROOT/build/sources"
ONLY_ID=""
ONLY_KIND=""
DO_OGV=1
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ONLY_ID="${2:?}"; shift 2 ;;
    --kind) ONLY_KIND="${2:?}"; shift 2 ;;
    --mp4-only) DO_OGV=0; shift ;;
    --force) FORCE=1; shift ;;
    *) MANIFEST="$1"; shift ;;
  esac
done

command -v yt-dlp >/dev/null || { echo "need yt-dlp (see ant_explorer/tools/install_yt_dlp.sh)"; exit 1; }
command -v ffmpeg >/dev/null || { echo "need ffmpeg"; exit 1; }
mkdir -p "$SRC_DIR"

yt_id() {
  local url="$1"
  if [[ "$url" =~ v=([A-Za-z0-9_-]{6,}) ]]; then echo "${BASH_REMATCH[1]}"
  elif [[ "$url" =~ youtu\.be/([A-Za-z0-9_-]{6,}) ]]; then echo "${BASH_REMATCH[1]}"
  else echo "unknown"; fi
}

ensure_source() {
  local url="$1"
  local vid="$2"
  local dest="$SRC_DIR/${vid}.mp4"
  [[ -f "$dest" && "$FORCE" -eq 0 ]] && return 0
  yt-dlp --remote-components ejs:github -f "bv*[height<=720]+ba/b[height<=720]/b" --merge-output-format mp4 -o "$dest" "$url"
}

cut_clip() {
  local src="$1" start="$2" end="$3" out_mp4="$4" out_ogv="$5"
  mkdir -p "$(dirname "$out_mp4")"
  if [[ -f "$out_mp4" && "$FORCE" -eq 0 ]]; then
    echo "skip $out_mp4"
  else
    ffmpeg -nostdin -y -ss "$start" -to "$end" -i "$src" \
      -vf "scale='min(854,iw)':-2" -c:v libx264 -pix_fmt yuv420p -c:a aac -movflags +faststart "$out_mp4"
  fi
  if [[ "$DO_OGV" -eq 1 ]]; then
    if [[ -f "$out_ogv" && "$FORCE" -eq 0 ]]; then
      echo "skip $out_ogv"
    else
      ffmpeg -nostdin -y -i "$out_mp4" \
        -vf "scale='min(854,iw)':-2" -c:v libtheora -q:v 5 -c:a libvorbis -q:a 4 "$out_ogv"
    fi
  fi
}

while IFS=$'\t' read -r plant kind start end url; do
  [[ -z "${plant:-}" || "$plant" == \#* ]] && continue
  [[ -n "$ONLY_ID" && "$plant" != "$ONLY_ID" ]] && continue
  [[ -n "$ONLY_KIND" && "$kind" != "$ONLY_KIND" ]] && continue
  vid="$(yt_id "$url")"
  echo ">> $plant/$kind  [$start -> $end]  $vid"
  ensure_source "$url" "$vid"
  cut_clip "$SRC_DIR/${vid}.mp4" "$start" "$end" \
    "$OUT_ROOT/$plant/${kind}.mp4" "$OUT_ROOT/$plant/${kind}.ogv"
done < "$MANIFEST"
echo "done."
