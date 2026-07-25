# Demo videos

| File | What it is |
|------|------------|
| [`solar_system_explorer_playthrough.mp4`](solar_system_explorer_playthrough.mp4) | Automated in-engine walkthrough: hub → Solar System peek → Spaceship → plot Jupiter (belt) → fly → orbit → plot Sun → arrive |
| [`solar_system_explorer_explainer.mp4`](solar_system_explorer_explainer.mp4) | Short overview cut — astronaut art, two-tile hub, strip / plot / belt / orbit stills + dedicated VO |

Explainer script: [`explainer_narration.json`](explainer_narration.json) · WAVs in [`vo/`](vo/).

```bash
# Both videos (playthrough needs a display / GPU; slow on llvmpipe)
./tools/make_demo_videos.sh

# Explainer VO only
python3 tools/gen_demo_vo.py --force
```

Director script: `game/tools/record_playthrough_demo.gd`.
