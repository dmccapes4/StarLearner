# Demo videos

Language Explorer follows the same two-cut pattern as the other Star Learner titles:

| Sibling | Explainer | Playthrough / walkthrough |
|---------|-----------|---------------------------|
| [Ant Explorer](../../ant_explorer/docs/demo/README.md) | screenshots + gift VO | MovieWriter in-engine run |
| [Solar System Explorer](../../solar_system_explorer/docs/demo/README.md) | Ken-Burns stills + VO | MovieWriter fly / orbit tour |
| [Math Explorer](../../math_explorer/docs/demo/) | screenshot slideshow + VO | MovieWriter walkthrough |
| [Garden Explorer](../../garden_explorer/docs/demo/) | (kiosk uses playthrough) | MovieWriter farm tour |

| File | What it is |
|------|------------|
| [`language_explorer_playthrough.mp4`](language_explorer_playthrough.mp4) | Automated in-engine tour: home icons → Read / books → Write / alphabet word → narration picker → home |
| [`language_explorer_explainer.mp4`](language_explorer_explainer.mp4) | Short overview cut — screenshot stills + dedicated VO (kiosk enter video) |

Explainer script: [`explainer_narration.json`](explainer_narration.json) · WAVs in [`vo/`](vo/).

```bash
# Both videos (playthrough needs a display / GPU; DISPLAY=:1 works)
./tools/make_demo_videos.sh

# Explainer VO only
python3 tools/gen_explainer_vo.py --force

# Refresh stills used by the explainer
godot --path game -s res://tools/capture_shots.gd
```

Director script: `game/tools/record_playthrough_demo.gd`.
