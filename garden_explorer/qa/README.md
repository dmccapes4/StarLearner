# Garden Explorer QA

Agent-oriented playtest harnesses. Screenshots land under `qa/out/` (gitignored).

**Shared process for all Star Learner games:** [`../../docs/QA_SUITE_PROCESS.md`](../../docs/QA_SUITE_PROCESS.md)

## Depth suite

Stress-tests isometric depth + solids at known interaction points (beds, path, gate, coop, shed), then along short walk segments.

```bash
./qa/run_depth_suite.sh
```

## Bed approach suite

Checks that tapping a bed picks a **natural stand face** (from tap + player) and a **short path through gaps / the dirt path** — not a long loop around the whole row.

```bash
./qa/run_bed_approach_suite.sh
```

Outputs: `qa/out/bed_approach/<stamp>/report.json` + start/approach PNGs.
Agent: re-run after routing changes; any `FAIL` in the report is a regression.

## Bed plants suite

Confirms raised beds + crop packs render correctly: furrow geometry, seed vs four-plant packs, foot landings in plots, harvest star above grown plants.

```bash
./qa/run_bed_plants_suite.sh
```

Outputs: `qa/out/bed_plants/<stamp>/report.json` + empty / seed / sprout / growing / grown / multi-bed PNGs.

### What “fail” looks like

| Area | Fail signal |
|------|-------------|
| Seed | Four seeds, or art far off the furrow cross |
| Grown pack | Plants SE-shifted onto the wood lip; feet not in furrow plots |
| Star | Missing when harvestable, or covering roots / floating randomly far |
| Multi-bed | Packs painting over path/fence; beds empty when stages were forced |

## Season trees suite

Walks spring → summer → fall → winter: meadow tree art, ground tint, decor, and weather (flowers / clear / leaves / rain).

```bash
./qa/run_season_trees_suite.sh
```

Outputs: `qa/out/season_trees/<stamp>/report.json` + per-season yard / trees / fx PNGs.

### What “fail” looks like

| Area | Fail signal |
|------|-------------|
| Trees | Inside the fence; missing textures; same atlas row every season |
| Spring | No flower decals, or rain/leaves storm active |
| Fall | No falling leaves / ground leaf scatter |
| Winter | No rain overlay, or particles ignoring bed depth |

## Walk video + vision review

Captures ~7s yard-walk clips (PNG sequence → `walk.mp4`) with per-frame
`state.jsonl` ground truth (player depth, bed stages, seed/pack flags, Buddy,
bugs), then asks Grok (`XAI_API_KEY`) or OpenAI (`OPENAI_API_KEY`) to compare
render vs state and flag **all clear UX / unnatural issues**.

```bash
./qa/run_walk_video_suite.sh              # capture + review
REVIEW=0 ./qa/run_walk_video_suite.sh     # capture only
# or review an existing stamp:
python3 qa/review_walk_videos.py qa/out/walk_video/<stamp>
```

Clips: path past beds · south lip depth · seed plant · gate/pen · Buddy walk ·
shed approach. Same concurrency knobs as Solar (`REVIEW_CONCURRENCY`,
`REVIEW_STAGGER_S`, …) — see [`../../docs/QA_SUITE_PROCESS.md`](../../docs/QA_SUITE_PROCESS.md).

Outputs: `qa/out/walk_video/<stamp>/<clip>/` (`walk.mp4`, `frames/`,
`state.jsonl`, `route.json`, `review.json`) plus `reviews.json` and `REVIEW.md`.

Requires Godot 4.3 on `PATH` or `~/.local/bin/godot`. Uses `xvfb-run` when no `DISPLAY` is set.

### Outputs

```
qa/out/depth_suite/<timestamp>/
  report.json          # shot list + notes + agent_brief
  00_01_spawn.png
  01_02_path_north_bed1.png
  …
```

### Agent workflow

1. Run `./qa/run_depth_suite.sh`.
2. Open `report.json` → read `agent_brief` and each shot’s `note`.
3. **Look at every PNG** (Read tool) — do not judge from filenames alone.
4. Reply with a short per-shot verdict (pass / fail + what looks wrong).
5. Fix code, re-run, compare.

### What “fail” looks like

| Area | Fail signal |
|------|-------------|
| South beds | Player sprite painted **on top of** soil / wood while standing on the path side or “in” the bed |
| North beds | Standing north of bed but fully in front (bed never occludes) |
| Gate | Rails stepped above/below fence; free end is a bare rail **fork** with no post |
| Coop / shed | Feet drawn through the building; path cuts through solid |

## Device capture (optional)

For a kid walkthrough on a phone:

```bash
./qa/capture_device_walk.sh 20          # 20s screenrecord + dense frames
./qa/capture_device_walk.sh 20 --replay # later: replay last tap log if present
```

Tap log + frames go to `qa/out/device/<timestamp>/`.

## Related

- Broader UX checks: `./tools/run_ux_suite.sh` (logic + shots under `game/docs/screenshots/ux/`)
- Depth conventions: `docs/ARCHITECTURE_MOVEMENT_AND_DEPTH.md`
