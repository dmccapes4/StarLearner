#!/usr/bin/env bash
# Build the two Math Explorer demo videos:
#   docs/demo/math_explorer_walkthrough.mp4  — automated in-game run (MovieWriter)
#   docs/demo/math_explorer_explainer.mp4    — narrated slideshow of screenshots
#
# Prereqs: baked in-game VO (tools/gen_math_vo.py), explainer VO
# (tools/gen_explainer_vo.py), screenshots (game/tools/capture_shots.gd),
# a display for --write-movie (DISPLAY=:1 works), and ffmpeg.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
OUT="$ROOT/docs/demo"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
AVI="${MATH_DEMO_AVI:-/tmp/math_walkthrough.avi}"
WALK_MP4="$OUT/math_explorer_walkthrough.mp4"
EXPLAIN_MP4="$OUT/math_explorer_explainer.mp4"
SHOTS="$GAME/docs/screenshots"
DEMO_VO="$OUT/vo"
FPS=24
XFADE=0.6

mkdir -p "$OUT"

echo "=== 1) automated walkthrough (Godot MovieWriter) ==="
"$GODOT" --path "$GAME" \
  --fixed-fps $FPS \
  --disable-vsync \
  --write-movie "$AVI" \
  -s res://tools/record_walkthrough_demo.gd
echo "wrote $AVI"

echo "=== 2) mux walkthrough to mp4 ==="
ffmpeg -y -hide_banner -loglevel error -i "$AVI" \
  -c:v libx264 -pix_fmt yuv420p -preset fast -crf 18 \
  -c:a aac -b:a 192k "$WALK_MP4"
echo "OK $WALK_MP4 ($(du -h "$WALK_MP4" | awk '{print $1}'))"

echo "=== 3) narrated explainer (screenshots + VO slides) ==="
for need in 01_open 02_tabs 03_tutorial 04_stories 05_practice 06_close; do
  [[ -f "$DEMO_VO/${need}.wav" ]] || {
    echo "missing $DEMO_VO/${need}.wav — run tools/gen_explainer_vo.py"
    exit 1
  }
done

WORK=/tmp/math_explainer_work
rm -rf "$WORK"
mkdir -p "$WORK"

ffmpeg -y -hide_banner -loglevel error \
  -i "$DEMO_VO/01_open.wav" -i "$DEMO_VO/02_tabs.wav" \
  -i "$DEMO_VO/03_tutorial.wav" -i "$DEMO_VO/04_stories.wav" \
  -i "$DEMO_VO/05_practice.wav" -i "$DEMO_VO/06_close.wav" \
  -filter_complex "[0:a][1:a][2:a][3:a][4:a][5:a]concat=n=6:v=0:a=1[a]" \
  -map "[a]" "$WORK/narration.wav"

dur() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }
d0=$(dur "$DEMO_VO/01_open.wav")
d1=$(dur "$DEMO_VO/02_tabs.wav")
d2=$(dur "$DEMO_VO/03_tutorial.wav")
d3=$(dur "$DEMO_VO/04_stories.wav")
d4=$(dur "$DEMO_VO/05_practice.wav")
d5=$(dur "$DEMO_VO/06_close.wav")

# Ken Burns slide: upscale before zoompan so the drift isn't pixel-staircased.
mkslide() {
  local img="$1" sec="$2" out="$3" direction="${4:-in}"
  local frames
  frames=$(python3 -c "print(max(2, int(round(float('$sec') * $FPS))))")
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

mkslide "$SHOTS/00_card.png" "$d0" "$WORK/s0.mp4" in
mkslide "$SHOTS/00_card_mul.png" "$d1" "$WORK/s1.mp4" out
mkslide "$SHOTS/02_tutorial_done.png" "$d2" "$WORK/s2.mp4" in
mkslide "$SHOTS/04_trains_done.png" "$d3" "$WORK/s3.mp4" out
mkslide "$SHOTS/09_practice_add.png" "$d4" "$WORK/s4.mp4" in
# Pad the last slide so 5 crossfades don't shorten the film vs. narration.
d5_pad=$(python3 -c "print(float('$d5') + 5 * float('$XFADE'))")
mkslide "$SHOTS/06_eggs_cartons.png" "$d5_pad" "$WORK/s5.mp4" out

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

parts = []
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

echo "=== demo videos ready ==="
ls -lh "$OUT"/*.mp4
