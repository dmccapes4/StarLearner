#!/usr/bin/env bash
# Download + trim solar-system clips into the Godot app tree.
# Mirrors ant_explorer/tools/build_stars.sh (same cache + cut strategy), plus
# multi-row concat so a short "real body" opener can prepend the explainer.
#
# Output: offline VideoStreamPlayer clips at game/videos/<id>.ogv, tapped from
# the scroll strip. <id> must match SolarData.gd (sun, mercury, … asteroid_belt).
#
# Usage:
#   ./build_clips.sh                 # all bodies in solar_bodies.tsv → ../game/videos/
#   ./build_clips.sh --id earth      # one body
#   ./build_clips.sh --mp4-only      # skip .ogv (preview / archival)
#   ./build_clips.sh --force         # re-cut even if outputs exist
#   ./build_clips.sh path/to.tsv
#
# Needs: yt-dlp, ffmpeg (with libtheora + libvorbis for .ogv)
#
# solar_bodies.tsv columns (TAB):  id  start(HH:MM:SS)  end(HH:MM:SS)  url
# Consecutive rows with the same id are cut and concatenated in order (live
# footage first, then the VectorGlobe explainer). Sources cached once per
# YouTube video id under tools/build/sources/

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$ROOT/solar_bodies.tsv"
OUT_DIR="$ROOT/../game/videos"
SRC_DIR="$ROOT/build/sources"
ONLY_ID=""
DO_OGV=1
FORCE=0

usage() {
  sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --id) ONLY_ID="${2:?}"; shift 2 ;;
    --mp4-only) DO_OGV=0; shift ;;
    --ogv) DO_OGV=1; shift ;;
    --force) FORCE=1; shift ;;
    --out) OUT_DIR="${2:?}"; shift 2 ;;
    *.tsv) MANIFEST="$1"; shift ;;
    *) echo "unknown arg: $1" >&2; usage 2 ;;
  esac
done

command -v yt-dlp >/dev/null || { echo "ERROR: yt-dlp not found (see install_yt_dlp.sh)"; exit 1; }
command -v ffmpeg >/dev/null || { echo "ERROR: ffmpeg not found"; exit 1; }
[[ -f "$MANIFEST" ]] || { echo "ERROR: manifest '$MANIFEST' not found"; exit 1; }

mkdir -p "$SRC_DIR" "$OUT_DIR"

youtube_id() {
  local url="$1"
  if [[ "$url" =~ v=([A-Za-z0-9_-]{6,}) ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$url" =~ youtu\.be/([A-Za-z0-9_-]{6,}) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    printf '%s' "$url" | sha1sum | awk '{print $1}'
  fi
}

ensure_source() {
  local url="$1"
  local vid
  vid="$(youtube_id "$url")"
  # Prefix yt_ so ids like -6oKJ5FGk24 never look like CLI flags.
  local src="$SRC_DIR/yt_${vid}.mp4"
  if [[ -f "$src" && -s "$src" ]]; then
    printf '%s\n' "$src"
    return
  fi
  echo "   downloading source $vid …" >&2
  # </dev/null — never steal the manifest FD from the caller loop.
  yt-dlp -f "bv*[height<=720]+ba/b[height<=720]/b[height<=720]" \
         --merge-output-format mp4 \
         -o "$src" \
         "$url" </dev/null >&2
  [[ -f "$src" && -s "$src" ]] || {
    echo "ERROR: download failed for $vid → $src" >&2
    return 1
  }
  printf '%s\n' "$src"
}

hms_to_seconds() {
  local t="$1"
  local a b c
  IFS=: read -r a b c <<<"$t"
  if [[ -n "${c:-}" ]]; then
    echo $((10#$a * 3600 + 10#$b * 60 + 10#$c))
  else
    echo $((10#$a * 60 + 10#$b))
  fi
}

cut_part() {
  # Normalize fps / size / audio so multi-source concat is reliable.
  # (concat demuxer drops video when parts disagree on timebase — e.g. 29.97 vs 30.)
  local src="$1" start_s="$2" dur_s="$3" part="$4"
  ffmpeg -hide_banner -loglevel error -nostdin -y -i "$src" \
         -ss "$start_s" -t "$dur_s" \
         -vf "fps=30,scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1" \
         -r 30 \
         -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 23 -preset veryfast \
         -c:a aac -b:a 96k -ar 44100 -ac 2 \
         -movflags +faststart \
         "$part" </dev/null
}

build_body() {
  local id="$1"
  shift
  # Remaining args: triplets start end url …
  local -a segs=("$@")
  local n=$(( ${#segs[@]} / 3 ))
  if [[ "$n" -lt 1 || $(( ${#segs[@]} % 3 )) -ne 0 ]]; then
    echo "ERROR: $id bad segment payload (${#segs[@]} fields)" >&2
    return 1
  fi

  local mp4="$OUT_DIR/$id.mp4"
  local ogv="$OUT_DIR/$id.ogv"

  if [[ "$FORCE" -eq 0 && -f "$mp4" && -s "$mp4" && ( "$DO_OGV" -eq 0 || ( -f "$ogv" && -s "$ogv" ) ) ]]; then
    echo "   skip (exists; use --force to rebuild)"
    skipped=$((skipped + 1))
    return 0
  fi

  local parts_dir
  parts_dir="$(mktemp -d "${TMPDIR:-/tmp}/solar_${id}.XXXXXX")"

  local i=0
  local -a parts=()
  while [[ $i -lt $n ]]; do
    local start="${segs[$((i * 3))]}"
    local end="${segs[$((i * 3 + 1))]}"
    local url="${segs[$((i * 3 + 2))]}"
    local start_s end_s dur_s src part
    start_s="$(hms_to_seconds "$start")"
    end_s="$(hms_to_seconds "$end")"
    dur_s=$((end_s - start_s))
    if [[ "$dur_s" -le 0 ]]; then
      echo "ERROR: bad window for $id segment $i ($start -> $end)" >&2
      rm -rf "$parts_dir"
      return 1
    fi
    echo "   segment $((i + 1))/$n  [$start -> $end]  $(youtube_id "$url")"
    src="$(ensure_source "$url")"
    src="${src//$'\r'/}"
    src="${src##*$'\n'}"
    part="$parts_dir/part_${i}.mp4"
    cut_part "$src" "$start_s" "$dur_s" "$part"
    parts+=("$part")
    i=$((i + 1))
  done

  if [[ "$n" -eq 1 ]]; then
    mv -f "${parts[0]}" "$mp4"
  else
    # filter_complex concat keeps both video tracks; demuxer concat was dropping
    # the second video when source fps/timebases differed (asteroid belt, etc.).
    local -a ff_in=()
    local fc=""
    for i in "${!parts[@]}"; do
      ff_in+=(-i "${parts[$i]}")
      fc+="[$i:v][$i:a]"
    done
    fc+="concat=n=${n}:v=1:a=1[v][a]"
    ffmpeg -hide_banner -loglevel error -nostdin -y \
           "${ff_in[@]}" \
           -filter_complex "$fc" -map "[v]" -map "[a]" \
           -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 23 -preset veryfast \
           -c:a aac -b:a 96k -ar 44100 -ac 2 -movflags +faststart \
           "$mp4" </dev/null
  fi
  rm -rf "$parts_dir"
  echo "   wrote $mp4  ($(du -h "$mp4" | cut -f1))  [$n segment(s)]"

  if [[ "$DO_OGV" -eq 1 ]]; then
    if ! ffmpeg -hide_banner -loglevel error -nostdin -y -i "$mp4" \
           -c:v libtheora -q:v 7 -c:a libvorbis -q:a 4 \
           "$ogv" </dev/null; then
      echo "ERROR: .ogv encode failed (need ffmpeg libtheora + libvorbis)." >&2
      echo "       MP4 was written; re-run with --mp4-only if needed." >&2
      return 1
    fi
    echo "   wrote $ogv  ($(du -h "$ogv" | cut -f1))"
  fi

  built=$((built + 1))
}

built=0
skipped=0

cur_id=""
declare -a cur_segs=()

flush_body() {
  if [[ -z "$cur_id" ]]; then
    return 0
  fi
  echo ">> body $cur_id  (${#cur_segs[@]} / 3 segment fields)"
  build_body "$cur_id" "${cur_segs[@]}"
  cur_id=""
  cur_segs=()
}

# Read manifest on FD 3 so ffmpeg/yt-dlp cannot consume TSV lines on stdin.
while IFS=$'\t' read -r id start end url <&3 || [[ -n "${id:-}" ]]; do
  [[ -z "${id:-}" || "$id" == \#* ]] && continue
  [[ -n "$ONLY_ID" && "$id" != "$ONLY_ID" ]] && continue

  if [[ -n "$cur_id" && "$id" != "$cur_id" ]]; then
    flush_body
  fi
  cur_id="$id"
  cur_segs+=("$start" "$end" "$url")
done 3< "$MANIFEST"
flush_body

if [[ -n "$ONLY_ID" && "$built" -eq 0 && "$skipped" -eq 0 ]]; then
  echo "ERROR: no row matched --id $ONLY_ID" >&2
  exit 1
fi

echo
echo "Done. built=$built skipped=$skipped → $OUT_DIR"
echo "Godot expects: res://videos/<id>.ogv  (VideoPanel.play_body)"
