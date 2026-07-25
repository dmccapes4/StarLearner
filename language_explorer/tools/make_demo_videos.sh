#!/usr/bin/env bash
# Build the two Language Explorer demo videos (same pattern as Math / Ant / Solar):
#   docs/demo/language_explorer_playthrough.mp4  — automated in-game run (MovieWriter)
#   docs/demo/language_explorer_explainer.mp4    — narrated slideshow of screenshots
#
# Prereqs: baked in-game VO, explainer VO (tools/gen_explainer_vo.py), screenshots
# (game/tools/capture_shots.gd), a display for --write-movie (DISPLAY=:1), ffmpeg.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
OUT="$ROOT/docs/demo"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
AVI="${LANGUAGE_DEMO_AVI:-/tmp/language_playthrough.avi}"
PLAY_MP4="$OUT/language_explorer_playthrough.mp4"
EXPLAIN_MP4="$OUT/language_explorer_explainer.mp4"
SHOTS="$GAME/docs/screenshots"
DEMO_VO="$OUT/vo"
FPS=24
XFADE=0.6

mkdir -p "$OUT"

if [[ -z "${DISPLAY:-}" ]]; then
  if command -v xvfb-run >/dev/null 2>&1; then
    echo ">> using xvfb-run for MovieWriter"
    exec xvfb-run -a -s "-screen 0 1280x720x24" env DISPLAY=:99 "$0" "$@"
  fi
  echo "ERROR: need DISPLAY or xvfb-run for Godot MovieWriter" >&2
  exit 1
fi

echo "=== 1) automated playthrough (Godot MovieWriter) ==="
"$GODOT" --path "$GAME" \
  --fixed-fps "$FPS" \
  --disable-vsync \
  --write-movie "$AVI" \
  -s res://tools/record_playthrough_demo.gd
echo "wrote $AVI"

echo "=== 2) mux playthrough to mp4 ==="
if ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 "$AVI" 2>/dev/null | grep -q audio; then
  ffmpeg -y -hide_banner -loglevel error -i "$AVI" \
    -c:v libx264 -pix_fmt yuv420p -preset fast -crf 18 \
    -c:a aac -b:a 192k "$PLAY_MP4"
else
  echo "(AVI has no audio track — muxing video only)"
  ffmpeg -y -hide_banner -loglevel error -i "$AVI" \
    -c:v libx264 -pix_fmt yuv420p -preset fast -crf 18 -an "$PLAY_MP4"
fi
echo "OK $PLAY_MP4 ($(du -h "$PLAY_MP4" | awk '{print $1}'))"

echo "=== 3) ensure explainer VO ==="
python3 "$ROOT/tools/gen_explainer_vo.py"

echo "=== 4) narrated explainer (screenshots + VO slides) ==="
for need in 01_open 02_read 03_write 04_alphabet 05_menu 06_close; do
  [[ -f "$DEMO_VO/${need}.wav" ]] || {
    echo "missing $DEMO_VO/${need}.wav — run tools/gen_explainer_vo.py --force"
    exit 1
  }
done
for shot in 00_home 02_read_home 04_write_home 06_alphabet_apple 01_tutorial_read 07_write_narration; do
  [[ -f "$SHOTS/${shot}.png" ]] || {
    echo "missing $SHOTS/${shot}.png — run: godot --path game -s res://tools/capture_shots.gd"
    exit 1
  }
done

WORK=/tmp/language_explainer_work
rm -rf "$WORK"
mkdir -p "$WORK"

ffmpeg -y -hide_banner -loglevel error \
  -i "$DEMO_VO/01_open.wav" -i "$DEMO_VO/02_read.wav" \
  -i "$DEMO_VO/03_write.wav" -i "$DEMO_VO/04_alphabet.wav" \
  -i "$DEMO_VO/05_menu.wav" -i "$DEMO_VO/06_close.wav" \
  -filter_complex "[0:a][1:a][2:a][3:a][4:a][5:a]concat=n=6:v=0:a=1[a]" \
  -map "[a]" "$WORK/narration.wav"

dur() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }
d0=$(dur "$DEMO_VO/01_open.wav")
d1=$(dur "$DEMO_VO/02_read.wav")
d2=$(dur "$DEMO_VO/03_write.wav")
d3=$(dur "$DEMO_VO/04_alphabet.wav")
d4=$(dur "$DEMO_VO/05_menu.wav")
d5=$(dur "$DEMO_VO/06_close.wav")

# Ken Burns slide: upscale before zoompan (same recipe as Math Explorer).
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

mkslide "$SHOTS/00_home.png"            "$d0" "$WORK/s0.mp4" in
mkslide "$SHOTS/02_read_home.png"       "$d1" "$WORK/s1.mp4" out
mkslide "$SHOTS/04_write_home.png"      "$d2" "$WORK/s2.mp4" in
mkslide "$SHOTS/06_alphabet_apple.png"  "$d3" "$WORK/s3.mp4" out
mkslide "$SHOTS/01_tutorial_read.png"   "$d4" "$WORK/s4.mp4" in
d5_pad=$(python3 -c "print(float('$d5') + 5 * float('$XFADE'))")
mkslide "$SHOTS/07_write_narration.png" "$d5_pad" "$WORK/s5.mp4" out

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
