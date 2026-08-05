# Demo videos

| File | What it is |
|------|------------|
| [`solar_system_explorer_playthrough.mp4`](solar_system_explorer_playthrough.mp4) | Automated in-engine walkthrough: hub → Solar System peek → Spaceship chooser → Mission Flight (plot Jupiter + belt) → Free Flight playground |
| [`solar_system_explorer_explainer.mp4`](solar_system_explorer_explainer.mp4) | Short overview cut — astronaut art, hub, Mission/Free chooser, plot / belt / playground / orbit stills + dedicated VO |

Explainer script: [`explainer_narration.json`](explainer_narration.json) · WAVs in [`vo/`](vo/).

```bash
# Both videos (playthrough needs a display / GPU or xvfb; slow on llvmpipe)
./tools/make_demo_videos.sh

# Explainer VO only (ElevenLabs)
python3 tools/gen_demo_vo.py --force
```

Director script: `game/tools/record_playthrough_demo.gd`.

Related discovery: [`../STRATEGY_REAL_ROCKET_SCIENCE.md`](../STRATEGY_REAL_ROCKET_SCIENCE.md) (uber-realistic propulsion — not in the kid demos yet).
