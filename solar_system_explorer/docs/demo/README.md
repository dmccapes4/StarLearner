# Demo videos

| File | What it is |
|------|------------|
| [`solar_system_explorer_playthrough.mp4`](solar_system_explorer_playthrough.mp4) | Automated in-engine walkthrough: title → orrery → scroll → plot Mars → fly → orbit → plot Sun → safe standoff |
| [`solar_system_explorer_explainer.mp4`](solar_system_explorer_explainer.mp4) | Short overview cut — opens on astronaut/ship art (no caption), then navigation stills + dedicated VO |

Explainer script: [`explainer_narration.json`](explainer_narration.json) · WAVs in [`vo/`](vo/).

```bash
# Both videos (playthrough needs a display / GPU; slow on llvmpipe)
./tools/make_demo_videos.sh

# Explainer VO only
python3 tools/gen_demo_vo.py --force
```

Director script: `game/tools/record_playthrough_demo.gd`.
