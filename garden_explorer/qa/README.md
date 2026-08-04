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
