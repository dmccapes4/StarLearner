# Demo videos

| File | What it is |
|------|------------|
| [`ant_explorer_playthrough.mp4`](ant_explorer_playthrough.mp4) | Automated in-engine playthrough (~2–3 min): START → intro → entrance star → tunnel to leaf-cutter trail → surface star → wander → star-rail replay |
| [`ant_explorer_explainer.mp4`](ant_explorer_explainer.mp4) | Short overview cut — gift framing + how to play (screenshots + dedicated VO) |
| [`ant_explorer_homeostasis.mp4`](ant_explorer_homeostasis.mp4) | Live sim viz (~71s): caste census, pressures, larva nutrition/JH histogram, speed & zoom; narrated |

Explainer script: [`explainer_narration.json`](explainer_narration.json) · WAVs in [`vo/`](vo/).  
Homeostasis script: [`homeostasis_narration.json`](homeostasis_narration.json) · WAVs in [`vo_homeo/`](vo_homeo/).

```bash
# Re-record homeostasis viz
GODOT_USER_DATA_DIR=/tmp/ant_homeo_demo \
godot --path game --fixed-fps 24 --disable-vsync \
  --write-movie /tmp/ant_homeostasis.avi \
  -s res://tools/record_homeostasis_demo.gd
```

## Re-record

```bash
# Both videos (playthrough needs a display / GPU; slow on llvmpipe)
./tools/make_demo_videos.sh

# Playthrough only
GODOT_USER_DATA_DIR=/tmp/ant_demo_user \
godot --path game --fixed-fps 24 --disable-vsync \
  --write-movie /tmp/ant_explorer_playthrough.avi \
  -s res://tools/record_playthrough_demo.gd
```

Director script: `game/tools/record_playthrough_demo.gd`.
