#!/usr/bin/env bash
# Record Solar System Explorer walkthrough + narrated explainer.
# Includes Mission Flight (chart/fly) and Free Flight playground.
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
MODE_SHOTS="$SHOTS/modes"
DEMO_VO="$OUT/vo"

mkdir -p "$OUT" "$MODE_SHOTS"
rm -rf "$USER_DIR"
mkdir -p "$USER_DIR"

echo "=== 0) ensure explainer VO ==="
python3 "$ROOT/tools/gen_demo_vo.py" --force

echo "=== 1) capture fresh UI stills (hub / chooser / playground / trips) ==="
RUN_GODOT=()
if command -v xvfb-run >/dev/null 2>&1 && [[ "${QA_DISPLAY:-0}" != "1" ]]; then
  RUN_GODOT=(xvfb-run -a -s "-screen 0 1280x720x24")
elif [[ -n "${DISPLAY:-}" ]]; then
  echo ">> using DISPLAY=$DISPLAY"
else
  echo "!! no DISPLAY/xvfb — stills may be stale"
fi

if [[ ${#RUN_GODOT[@]} -gt 0 || -n "${DISPLAY:-}" ]]; then
  "${RUN_GODOT[@]}" "$GODOT" --path "$GAME" -s res://tools/capture_preview_shots.gd \
    >/tmp/solar_capture_preview.log 2>&1 || true
  "${RUN_GODOT[@]}" "$GODOT" --path "$GAME" -s res://tools/capture_chooser.gd \
    >/tmp/solar_capture_chooser.log 2>&1 || true
  "${RUN_GODOT[@]}" "$GODOT" --path "$GAME" -s res://tools/capture_modes.gd \
    >/tmp/solar_capture_modes.log 2>&1 || true
fi

# Stable explainer paths from trip / mode captures.
mkdir -p "$SHOTS"
[[ -f "$TRIP_SHOTS/earth_to_jupiter_0_plot.png" ]] && \
  cp -f "$TRIP_SHOTS/earth_to_jupiter_0_plot.png" "$SHOTS/earth_to_jupiter_0_plot.png"
[[ -f "$TRIP_SHOTS/earth_to_jupiter_1_fly_u040.png" ]] && \
  cp -f "$TRIP_SHOTS/earth_to_jupiter_1_fly_u040.png" "$SHOTS/earth_to_jupiter_1_fly_u040.png"
for belt in earth_to_jupiter_1_belt_u056.png earth_to_jupiter_1_belt_u099.png; do
  if [[ -f "$TRIP_SHOTS/$belt" ]]; then
    cp -f "$TRIP_SHOTS/$belt" "$SHOTS/earth_to_jupiter_1_belt_u056.png"
    break
  fi
done
[[ -f "$TRIP_SHOTS/earth_to_jupiter_2_orbit.png" ]] && \
  cp -f "$TRIP_SHOTS/earth_to_jupiter_2_orbit.png" "$SHOTS/earth_to_jupiter_2_orbit.png"

# Fallbacks if capture_modes/chooser didn't write this run.
if [[ ! -f "$MODE_SHOTS/playground_flying.png" ]]; then
  LATEST_QA="$(ls -1dt "$ROOT/qa/out/flight_mechanics"/*/00_01_tap_flight.png 2>/dev/null | head -1 || true)"
  if [[ -n "${LATEST_QA:-}" ]]; then
    cp -f "$LATEST_QA" "$MODE_SHOTS/playground_flying.png"
  fi
fi
if [[ ! -f "$MODE_SHOTS/flight_chooser.png" && -f "$SHOTS/01_title.png" ]]; then
  echo "WARN: flight_chooser.png missing — explainer will need modes/flight_chooser.png"
fi

echo "=== 2) automated playthrough (Godot MovieWriter) ==="
export GODOT_USER_DATA_DIR="$USER_DIR"
if [[ ${#RUN_GODOT[@]} -gt 0 ]]; then
  "${RUN_GODOT[@]}" env GODOT_USER_DATA_DIR="$USER_DIR" "$GODOT" --path "$GAME" \
    --fixed-fps 24 \
    --disable-vsync \
    --write-movie "$AVI" \
    -s res://tools/record_playthrough_demo.gd
else
  export DISPLAY="${DISPLAY:-:1}"
  "$GODOT" --path "$GAME" \
    --fixed-fps 24 \
    --disable-vsync \
    --write-movie "$AVI" \
    -s res://tools/record_playthrough_demo.gd
fi
echo "wrote $AVI"

echo "=== 3) mux playthrough to mp4 ==="
ffmpeg -y -hide_banner -loglevel error -i "$AVI" \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -b:a 192k "$PLAY_MP4"
echo "OK $PLAY_MP4 ($(du -h "$PLAY_MP4" | awk '{print $1}'))"

echo "=== 4) narrated explainer (7 beats) ==="
WORK=/tmp/solar_explainer_work
rm -rf "$WORK" && mkdir -p "$WORK"
KEYS=(01_gift 02_hub 03_modes 04_plot 05_fly 06_playground 07_close)
for need in "${KEYS[@]}"; do
  [[ -f "$DEMO_VO/${need}.wav" ]] || { echo "missing $DEMO_VO/${need}.wav"; exit 1; }
done

ffmpeg -y -hide_banner -loglevel error \
  -i "$DEMO_VO/01_gift.wav" -i "$DEMO_VO/02_hub.wav" -i "$DEMO_VO/03_modes.wav" \
  -i "$DEMO_VO/04_plot.wav" -i "$DEMO_VO/05_fly.wav" -i "$DEMO_VO/06_playground.wav" \
  -i "$DEMO_VO/07_close.wav" \
  -filter_complex "[0:a][1:a][2:a][3:a][4:a][5:a][6:a]concat=n=7:v=0:a=1[a]" \
  -map "[a]" "$WORK/narration.wav"

dur() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }
d0=$(dur "$DEMO_VO/01_gift.wav"); d1=$(dur "$DEMO_VO/02_hub.wav")
d2=$(dur "$DEMO_VO/03_modes.wav"); d3=$(dur "$DEMO_VO/04_plot.wav")
d4=$(dur "$DEMO_VO/05_fly.wav"); d5=$(dur "$DEMO_VO/06_playground.wav")
d6=$(dur "$DEMO_VO/07_close.wav")
FPS=24; XFADE=0.6
N=7

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

resolve_img() {
  local rel="$1"
  if [[ -f "$SHOTS/$rel" ]]; then echo "$SHOTS/$rel"; return; fi
  if [[ -f "$GAME/images/$rel" ]]; then echo "$GAME/images/$rel"; return; fi
  if [[ -f "$rel" ]]; then echo "$rel"; return; fi
  echo "ERROR: missing slide image $rel" >&2
  exit 1
}

IMG0="$(resolve_img "astronaut_girl.png")"
# Prefer game/images for astronaut
[[ -f "$GAME/images/astronaut_girl.png" ]] && IMG0="$GAME/images/astronaut_girl.png"
HUB="$SHOTS/01_title.png"
[[ -f "$HUB" ]] || HUB="$GAME/images/launch_solar.png"
IMG1="$HUB"
IMG2="$(resolve_img "modes/flight_chooser.png")"
IMG3="$(resolve_img "earth_to_jupiter_0_plot.png")"
FLY="$SHOTS/earth_to_jupiter_1_belt_u056.png"
[[ -f "$FLY" ]] || FLY="$SHOTS/earth_to_jupiter_1_fly_u040.png"
IMG4="$FLY"
IMG5="$(resolve_img "modes/playground_flying.png")"
IMG6="$(resolve_img "earth_to_jupiter_2_orbit.png")"

mkslide "$IMG0" "$d0" "$WORK/s0.mp4" in
mkslide "$IMG1" "$d1" "$WORK/s1.mp4" out
mkslide "$IMG2" "$d2" "$WORK/s2.mp4" in
mkslide "$IMG3" "$d3" "$WORK/s3.mp4" out
mkslide "$IMG4" "$d4" "$WORK/s4.mp4" in
mkslide "$IMG5" "$d5" "$WORK/s5.mp4" out
d6_pad=$(python3 -c "print(float('$d6') + 6 * float('$XFADE'))")
mkslide "$IMG6" "$d6_pad" "$WORK/s6.mp4" out

python3 - <<PY
import subprocess
from pathlib import Path
work = Path("$WORK")
xfade = float("$XFADE")
n = int("$N")
clips = [work / f"s{i}.mp4" for i in range(n)]
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
for i in range(1, n):
    offset = accum - xfade
    out = f"[v{i}]" if i < n - 1 else "[vout]"
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
