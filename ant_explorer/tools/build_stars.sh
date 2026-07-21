#!/usr/bin/env bash
# Download + trim documentary "star" clips into the Godot app tree.
#
# Phase 5 plan: offline VideoStreamPlayer clips at game/stars/<id>.ogv
# (see docs/IMPLEMENTATION_PLAN_ANT_EXPLORER.md § PHASE 5 / §6).
#
# Usage:
#   ./build_stars.sh                 # all rows in stars.tsv → ../game/stars/
#   ./build_stars.sh --id 01_queen   # one star
#   ./build_stars.sh --mp4-only      # skip .ogv (preview / archival)
#   ./build_stars.sh --force         # re-cut even if outputs exist
#   ./build_stars.sh path/to.tsv
#
# Needs: yt-dlp, ffmpeg (with libtheora + libvorbis for .ogv)
#
# stars.tsv columns (TAB):  id  start(HH:MM:SS)  end(HH:MM:SS)  url
# Sources cached once per YouTube video id under tools/build/sources/

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$ROOT/stars.tsv"
OUT_DIR="$ROOT/../game/stars"
SRC_DIR="$ROOT/build/sources"
ONLY_ID=""
DO_OGV=1
FORCE=0

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
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

command -v yt-dlp >/dev/null || { echo "ERROR: yt-dlp not found (pipx install yt-dlp)"; exit 1; }
command -v ffmpeg >/dev/null || { echo "ERROR: ffmpeg not found"; exit 1; }
[[ -f "$MANIFEST" ]] || { echo "ERROR: manifest '$MANIFEST' not found"; exit 1; }

mkdir -p "$SRC_DIR" "$OUT_DIR"

# Drop corrupt outputs from earlier stdin-bug runs (e.g. ueen.mp4).
rm -f "$OUT_DIR/ueen.mp4" "$OUT_DIR/ueen.ogv"

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
  local legacy="$SRC_DIR/${vid}.mp4"
  if [[ ! -f "$src" && -f "$legacy" && -s "$legacy" ]]; then
    mv "$legacy" "$src"
  fi
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
  # HH:MM:SS or MM:SS → integer seconds
  local t="$1"
  local a b c
  IFS=: read -r a b c <<<"$t"
  if [[ -n "${c:-}" ]]; then
    echo $((10#$a * 3600 + 10#$b * 60 + 10#$c))
  else
    echo $((10#$a * 60 + 10#$b))
  fi
}

built=0
skipped=0

# Read manifest on FD 3 so ffmpeg/yt-dlp cannot consume TSV lines on stdin.
while IFS=$'\t' read -r id start end url <&3 || [[ -n "${id:-}" ]]; do
  [[ -z "${id:-}" || "$id" == \#* ]] && continue
  [[ -n "$ONLY_ID" && "$id" != "$ONLY_ID" ]] && continue

  echo ">> star $id  [$start -> $end]"

  mp4="$OUT_DIR/$id.mp4"
  ogv="$OUT_DIR/$id.ogv"

  if [[ "$FORCE" -eq 0 && -f "$mp4" && -s "$mp4" && ( "$DO_OGV" -eq 0 || ( -f "$ogv" && -s "$ogv" ) ) ]]; then
    echo "   skip (exists; use --force to rebuild)"
    skipped=$((skipped + 1))
    continue
  fi

  src="$(ensure_source "$url")"
  src="${src//$'\r'/}"
  src="${src##*$'\n'}"

  # Single window: start/end. Multi-window (skip off-topic mid-roll):
  #   start = t1,t2,t3   end = u1,u2,u3   → concat those segments in order.
  IFS=',' read -r -a starts <<<"$start"
  IFS=',' read -r -a ends <<<"$end"
  if [[ "${#starts[@]}" -ne "${#ends[@]}" ]]; then
    echo "ERROR: $id start/end segment count mismatch ($start / $end)" >&2
    exit 1
  fi

  parts_dir="$(mktemp -d "${TMPDIR:-/tmp}/star_${id}.XXXXXX")"
  part_list="$parts_dir/list.txt"
  : > "$part_list"
  for i in "${!starts[@]}"; do
    s="$(hms_to_seconds "${starts[$i]}")"
    e="$(hms_to_seconds "${ends[$i]}")"
    dur=$((e - s))
    if [[ "$dur" -le 0 ]]; then
      echo "ERROR: bad window for $id segment $i (${starts[$i]} -> ${ends[$i]})" >&2
      rm -rf "$parts_dir"
      exit 1
    fi
    part="$parts_dir/part_${i}.mp4"
    # -ss/-t after -i = accurate cut. </dev/null = do not read the TSV.
    ffmpeg -hide_banner -loglevel error -nostdin -y -i "$src" \
           -ss "$s" -t "$dur" \
           -vf "scale=trunc(iw*min(1\\,720/ih)/2)*2:720" \
           -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 23 -preset veryfast \
           -c:a aac -b:a 96k -movflags +faststart \
           "$part" </dev/null
    printf "file '%s'\n" "$part" >> "$part_list"
  done

  if [[ "${#starts[@]}" -eq 1 ]]; then
    mv -f "$parts_dir/part_0.mp4" "$mp4"
  else
    ffmpeg -hide_banner -loglevel error -nostdin -y -f concat -safe 0 \
           -i "$part_list" -c copy "$mp4" </dev/null
  fi
  rm -rf "$parts_dir"
  echo "   wrote $mp4  ($(du -h "$mp4" | cut -f1))  [${#starts[@]} segment(s)]"

  if [[ "$DO_OGV" -eq 1 ]]; then
    if ! ffmpeg -hide_banner -loglevel error -nostdin -y -i "$mp4" \
           -c:v libtheora -q:v 7 -c:a libvorbis -q:a 4 \
           "$ogv" </dev/null; then
      echo "ERROR: .ogv encode failed (need ffmpeg libtheora + libvorbis)." >&2
      echo "       MP4 was written; re-run with --mp4-only if needed." >&2
      exit 1
    fi
    echo "   wrote $ogv  ($(du -h "$ogv" | cut -f1))"
  fi

  built=$((built + 1))
done 3< "$MANIFEST"

if [[ -n "$ONLY_ID" && "$built" -eq 0 && "$skipped" -eq 0 ]]; then
  echo "ERROR: no row matched --id $ONLY_ID" >&2
  exit 1
fi

echo
echo "Done. built=$built skipped=$skipped → $OUT_DIR"
echo "Godot expects: res://stars/<id>.ogv  (see game/data/stars.json)"
echo "Optional phone push (external, not APK):"
echo "  adb push \"$OUT_DIR\"/. /sdcard/AntPhone/stars/"
