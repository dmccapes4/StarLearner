#!/usr/bin/env bash
# Record the automated playthrough demo and a short narrated explainer cut.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
OUT="$ROOT/docs/demo"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
USER_DIR="${ANT_DEMO_USER:-/tmp/ant_demo_user}"
AVI="${ANT_DEMO_AVI:-/tmp/ant_explorer_playthrough.avi}"
WAV="${AVI%.avi}.wav"
PLAY_MP4="$OUT/ant_explorer_playthrough.mp4"
EXPLAIN_MP4="$OUT/ant_explorer_explainer.mp4"

mkdir -p "$OUT"
rm -rf "$USER_DIR"
mkdir -p "$USER_DIR"

echo "=== 1) automated playthrough (Godot MovieWriter) ==="
# Fresh save so START + intro narration run.
export GODOT_USER_DATA_DIR="$USER_DIR"
# llvmpipe + movie writer: disable vsync; fixed 24 fps for stable timing.
"$GODOT" --path "$GAME" \
  --fixed-fps 24 \
  --disable-vsync \
  --write-movie "$AVI" \
  -s res://tools/record_playthrough_demo.gd
echo "wrote $AVI"

echo "=== 2) mux playthrough to mp4 ==="
# Godot 4.3 embeds PCM audio in the AVI when the driver allows it.
ffmpeg -y -i "$AVI" -c:v libx264 -pix_fmt yuv420p -c:a aac -b:a 192k "$PLAY_MP4"
echo "OK $PLAY_MP4 ($(du -h "$PLAY_MP4" | awk '{print $1}'))"

echo "=== 3) narrated explainer cut (screenshots + gift/overview VO) ==="
SHOTS="$ROOT/docs/screenshots"
# Gift + overview VO (not in-game intro/trail lines). Script: docs/demo/explainer_narration.json
DEMO_VO="$ROOT/docs/demo/vo"
WORK=/tmp/ant_explainer_work
rm -rf "$WORK"
mkdir -p "$WORK"

for need in 01_gift 02_console 03_colony 04_jobs 05_stars 06_close; do
  [[ -f "$DEMO_VO/${need}.wav" ]] || {
    echo "missing $DEMO_VO/${need}.wav — regenerate from explainer_narration.json via tools/gen_vo.py"
    exit 1
  }
done

# Overview narration bed (gift framing → how to play → close).
ffmpeg -y -hide_banner -loglevel error \
  -i "$DEMO_VO/01_gift.wav" \
  -i "$DEMO_VO/02_console.wav" \
  -i "$DEMO_VO/03_colony.wav" \
  -i "$DEMO_VO/04_jobs.wav" \
  -i "$DEMO_VO/05_stars.wav" \
  -i "$DEMO_VO/06_close.wav" \
  -filter_complex "[0:a][1:a][2:a][3:a][4:a][5:a]concat=n=6:v=0:a=1[a]" \
  -map "[a]" "$WORK/narration.wav"

dur() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }
d0=$(dur "$DEMO_VO/01_gift.wav")
d1=$(dur "$DEMO_VO/02_console.wav")
d2=$(dur "$DEMO_VO/03_colony.wav")
d3=$(dur "$DEMO_VO/04_jobs.wav")
d4=$(dur "$DEMO_VO/05_stars.wav")
d5=$(dur "$DEMO_VO/06_close.wav")

FPS=24
XFADE=0.6  # soft crossfade between slides (seconds)

# Smooth Ken Burns: upscale *before* zoompan so steps aren't pixel-staircased,
# and ease with a tiny continuous zoom (linear in frame index).
mkslide() {
  local img="$1" sec="$2" out="$3" direction="${4:-in}"
  local frames
  frames=$(python3 -c "print(max(2, int(round(float('$sec') * $FPS))))")
  # direction=in → 1.0→1.06; out → 1.06→1.0
  local zexpr
  if [[ "$direction" == "out" ]]; then
    zexpr="1.06-0.06*on/${frames}"
  else
    zexpr="1+0.06*on/${frames}"
  fi
  ffmpeg -y -hide_banner -loglevel error -loop 1 -i "$img" -frames:v "$frames" \
    -vf "scale=3840:1800:force_original_aspect_ratio=increase,crop=3840:1800,\
zoompan=z='${zexpr}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1280x600:fps=${FPS},\
format=yuv420p" \
    -c:v libx264 -pix_fmt yuv420p -preset fast -crf 18 "$out"
}

mkslide "$SHOTS/01_rails_soil.png" "$d0" "$WORK/s0.mp4" in
mkslide "$SHOTS/02_rails_revealed.png" "$d1" "$WORK/s1.mp4" out
mkslide "$SHOTS/05_nest_overview.png" "$d2" "$WORK/s2.mp4" in
mkslide "$SHOTS/03_garden.png" "$d3" "$WORK/s3.mp4" out
mkslide "$SHOTS/04_surface.png" "$d4" "$WORK/s4.mp4" in
# Pad the last slide so 5 crossfades don't shorten the film vs. narration.
d5_pad=$(python3 -c "print(float('$d5') + 5 * float('$XFADE'))")
mkslide "$SHOTS/02_rails_revealed.png" "$d5_pad" "$WORK/s5.mp4" out

# Crossfade chain (hard cuts were fine; zoom edges felt abrupt without this).
# offset_n = sum(dur[0..n]) - n*XFADE  — start of fade into slide n+1.
python3 - <<PY
import subprocess
from pathlib import Path
work = Path("$WORK")
xfade = float("$XFADE")
clips = [work / f"s{i}.mp4" for i in range(6)]
durs = []
for c in clips:
    out = subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "csv=p=0", str(c),
    ], text=True).strip()
    durs.append(float(out))

# Build filter_complex for sequential xfade.
# [0][1]xfade=...:offset=o0[v1]; [v1][2]xfade=...:offset=o1[v2]; ...
parts = []
labels_in = [f"[{i}:v]" for i in range(6)]
accum = durs[0]
cur = "[0:v]"
for i in range(1, 6):
    offset = accum - xfade
    out = f"[v{i}]" if i < 5 else "[vout]"
    parts.append(
        f"{cur}[{i}:v]xfade=transition=fade:duration={xfade}:offset={offset:.4f}{out}"
    )
    accum = offset + durs[i]
    cur = out

fc = ";".join(parts)
cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error"]
for c in clips:
    cmd += ["-i", str(c)]
cmd += ["-i", str(work / "narration.wav")]
cmd += [
    "-filter_complex", fc,
    "-map", "[vout]", "-map", f"{len(clips)}:a",
    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-preset", "fast", "-crf", "18",
    "-c:a", "aac", "-b:a", "192k", "-shortest",
    "$EXPLAIN_MP4",
]
subprocess.check_call(cmd)
print("xfade offsets ok, total~", accum)
PY
echo "OK $EXPLAIN_MP4 ($(du -h "$EXPLAIN_MP4" | awk '{print $1}'))"

echo "=== 4) homeostasis viz (optional; needs display) ==="
if [[ "${SKIP_HOMEO:-0}" != "1" ]]; then
  HOMEO_AVI="${ANT_HOMEO_AVI:-/tmp/ant_homeostasis.avi}"
  HOMEO_MP4="$OUT/ant_explorer_homeostasis.mp4"
  HOMEO_USER="${ANT_HOMEO_USER:-/tmp/ant_homeo_demo}"
  HOMEO_VO="$ROOT/docs/demo/vo_homeo"
  rm -rf "$HOMEO_USER"
  mkdir -p "$HOMEO_USER"
  GODOT_USER_DATA_DIR="$HOMEO_USER" "$GODOT" --path "$GAME" \
    --fixed-fps 24 --disable-vsync --write-movie "$HOMEO_AVI" \
    -s res://tools/record_homeostasis_demo.gd || true
  if [[ -f "$HOMEO_AVI" && -d "$HOMEO_VO" ]]; then
    HOMEO_WORK=/tmp/ant_homeo_mux
    rm -rf "$HOMEO_WORK" && mkdir -p "$HOMEO_WORK"
    ffmpeg -y -hide_banner -loglevel error \
      -i "$HOMEO_VO/01_open.wav" -i "$HOMEO_VO/02_larval.wav" -i "$HOMEO_VO/03_shock.wav" \
      -i "$HOMEO_VO/04_surplus.wav" -i "$HOMEO_VO/05_wide.wav" -i "$HOMEO_VO/06_close.wav" \
      -filter_complex "\
        aevalsrc=0:d=0.6[g0];aevalsrc=0:d=0.25[g1];aevalsrc=0:d=0.25[g2];\
        aevalsrc=0:d=0.25[g3];aevalsrc=0:d=0.25[g4];aevalsrc=0:d=0.25[g5];aevalsrc=0:d=0.8[g6];\
        [g0][0:a][g1][1:a][g2][2:a][g3][3:a][g4][4:a][g5][5:a][g6]concat=n=13:v=0:a=1[a]" \
      -map "[a]" "$HOMEO_WORK/narration.wav"
    ffmpeg -y -hide_banner -loglevel error \
      -i "$HOMEO_AVI" -i "$HOMEO_WORK/narration.wav" \
      -map 0:v:0 -map 1:a:0 \
      -c:v libx264 -pix_fmt yuv420p -preset fast -crf 18 \
      -c:a aac -b:a 192k -shortest "$HOMEO_MP4"
    echo "OK $HOMEO_MP4 ($(du -h "$HOMEO_MP4" | awk '{print $1}'))"
  fi
fi

echo "=== demo videos ready ==="
ls -lh "$OUT"/*.mp4 2>/dev/null || true
