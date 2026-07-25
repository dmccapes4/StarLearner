#!/usr/bin/env bash
# Record Solar System Explorer walkthrough + narrated explainer.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
OUT="$ROOT/docs/demo"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
USER_DIR="${SOLAR_DEMO_USER:-/tmp/solar_demo_user}"
AVI="${SOLAR_DEMO_AVI:-/tmp/solar_playthrough.avi}"
PLAY_MP4="$OUT/solar_system_explorer_playthrough.mp4"
EXPLAIN_MP4="$OUT/solar_system_explorer_explainer.mp4"
SHOTS="$GAME/docs/screenshots"
TRIP_SHOTS="$SHOTS/trips"
DEMO_VO="$OUT/vo"

mkdir -p "$OUT"
rm -rf "$USER_DIR"
mkdir -p "$USER_DIR"

echo "=== 0) ensure explainer VO ==="
python3 "$ROOT/tools/gen_demo_vo.py" --force

echo "=== 1) capture fresh UI stills (title / orrery / scroll) ==="
# Best-effort; fall back to existing shots if DISPLAY unavailable.
if [[ -n "${DISPLAY:-}" ]]; then
  DISPLAY="$DISPLAY" "$GODOT" --path "$GAME" -s res://tools/capture_debug_ux.gd \
    >/tmp/solar_capture_ux.log 2>&1 || true
fi
# Copy trip plot / belt / orbit stills into a stable explainer path.
mkdir -p "$SHOTS"
[[ -f "$TRIP_SHOTS/earth_to_jupiter_0_plot.png" ]] && \
  cp -f "$TRIP_SHOTS/earth_to_jupiter_0_plot.png" "$SHOTS/earth_to_jupiter_0_plot.png"
[[ -f "$TRIP_SHOTS/earth_to_jupiter_1_fly_u040.png" ]] && \
  cp -f "$TRIP_SHOTS/earth_to_jupiter_1_fly_u040.png" "$SHOTS/earth_to_jupiter_1_fly_u040.png"
[[ -f "$TRIP_SHOTS/earth_to_jupiter_1_belt_u056.png" ]] && \
  cp -f "$TRIP_SHOTS/earth_to_jupiter_1_belt_u056.png" "$SHOTS/earth_to_jupiter_1_belt_u056.png"
[[ -f "$TRIP_SHOTS/earth_to_jupiter_2_orbit.png" ]] && \
  cp -f "$TRIP_SHOTS/earth_to_jupiter_2_orbit.png" "$SHOTS/earth_to_jupiter_2_orbit.png"
# Prefer a fresh title hub capture when available.
if [[ -n "${DISPLAY:-}" ]]; then
  DISPLAY="$DISPLAY" "$GODOT" --path "$GAME" -s res://tools/capture_preview_shots.gd \
    >/tmp/solar_capture_preview.log 2>&1 || true
fi

echo "=== 2) automated playthrough (Godot MovieWriter) ==="
export GODOT_USER_DATA_DIR="$USER_DIR"
export DISPLAY="${DISPLAY:-:1}"
"$GODOT" --path "$GAME" \
  --fixed-fps 24 \
  --disable-vsync \
  --write-movie "$AVI" \
  -s res://tools/record_playthrough_demo.gd
echo "wrote $AVI"

echo "=== 3) mux playthrough to mp4 ==="
ffmpeg -y -hide_banner -loglevel error -i "$AVI" \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -b:a 192k "$PLAY_MP4"
echo "OK $PLAY_MP4 ($(du -h "$PLAY_MP4" | awk '{print $1}'))"

echo "=== 4) narrated explainer ==="
WORK=/tmp/solar_explainer_work
rm -rf "$WORK" && mkdir -p "$WORK"
for need in 01_gift 02_tour 03_pick 04_plot 05_fly 06_close; do
  [[ -f "$DEMO_VO/${need}.wav" ]] || { echo "missing $DEMO_VO/${need}.wav"; exit 1; }
done

ffmpeg -y -hide_banner -loglevel error \
  -i "$DEMO_VO/01_gift.wav" -i "$DEMO_VO/02_tour.wav" -i "$DEMO_VO/03_pick.wav" \
  -i "$DEMO_VO/04_plot.wav" -i "$DEMO_VO/05_fly.wav" -i "$DEMO_VO/06_close.wav" \
  -filter_complex "[0:a][1:a][2:a][3:a][4:a][5:a]concat=n=6:v=0:a=1[a]" \
  -map "[a]" "$WORK/narration.wav"

dur() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }
d0=$(dur "$DEMO_VO/01_gift.wav"); d1=$(dur "$DEMO_VO/02_tour.wav")
d2=$(dur "$DEMO_VO/03_pick.wav"); d3=$(dur "$DEMO_VO/04_plot.wav")
d4=$(dur "$DEMO_VO/05_fly.wav"); d5=$(dur "$DEMO_VO/06_close.wav")
FPS=24; XFADE=0.6

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

# Open on the astronaut art (girl + ship), not the title/star screen — no on-image caption.
mkslide "$GAME/images/astronaut_girl.png" "$d0" "$WORK/s0.mp4" in
# Prefer the two-tile launch hub for the "choose your path" beat.
HUB="$SHOTS/01_title.png"
[[ -f "$HUB" ]] || HUB="$GAME/images/launch_solar.png"
mkslide "$HUB" "$d1" "$WORK/s1.mp4" out
mkslide "$SHOTS/04_scroll.png" "$d2" "$WORK/s2.mp4" in
mkslide "$SHOTS/earth_to_jupiter_0_plot.png" "$d3" "$WORK/s3.mp4" out
# Prefer the asteroid-belt crossing still when present.
FLY="$SHOTS/earth_to_jupiter_1_belt_u056.png"
[[ -f "$FLY" ]] || FLY="$SHOTS/earth_to_jupiter_1_fly_u040.png"
mkslide "$FLY" "$d4" "$WORK/s4.mp4" in
d5_pad=$(python3 -c "print(float('$d5') + 5 * float('$XFADE'))")
mkslide "$SHOTS/earth_to_jupiter_2_orbit.png" "$d5_pad" "$WORK/s5.mp4" out

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
    parts.append(f"{cur}[{i}:v]xfade=transition=fade:duration={xfade}:offset={offset:.4f}{out}")
    accum = offset + durs[i]
    cur = out
fc = ";".join(parts)
cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error"]
for c in clips:
    cmd += ["-i", str(c)]
cmd += ["-i", str(work / "narration.wav"),
        "-filter_complex", fc, "-map", "[vout]", "-map", f"{len(clips)}:a",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-preset", "fast", "-crf", "18",
        "-c:a", "aac", "-b:a", "192k", "-shortest", "$EXPLAIN_MP4"]
subprocess.check_call(cmd)
print("explainer total~", accum)
PY
echo "OK $EXPLAIN_MP4 ($(du -h "$EXPLAIN_MP4" | awk '{print $1}'))"

echo "=== demo videos ready ==="
ls -lh "$OUT"/*.mp4 2>/dev/null || true
