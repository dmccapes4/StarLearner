# Ant Explorer QA

Agent-oriented playtest harnesses. Screenshots land under `qa/out/` (gitignored).

**Shared process for all Star Learner games:** [`../../docs/QA_SUITE_PROCESS.md`](../../docs/QA_SUITE_PROCESS.md)

## Chamber + interaction suite

Covers **every nest chamber** (star stand / in-room path), **every pheromone trail**,
sample **doorway** routes, **rails** (occlude → reveal → locked reveal-tour → collected
video arm), and a **live star tap** approach in the nursery.

```bash
./qa/run_chamber_suite.sh
```

Outputs: `qa/out/chamber_suite/<stamp>/report.json` + PNGs.

Requires Godot 4.3 on `PATH` or `~/.local/bin/godot`. Uses `xvfb-run` when no `DISPLAY`
is set. Prefer a display for readable screenshots (`DISPLAY=:1 ./qa/run_chamber_suite.sh`).

### Outputs

```
qa/out/chamber_suite/<timestamp>/
  report.json
  chamber_<zone>_star.png
  trail_<role>_<zone>.png
  rails_*.png
  live_nursery_star_approach.png
  nest_overview.png
  surface_overview.png
```

### Agent workflow

1. Run `./qa/run_chamber_suite.sh`.
2. Open `report.json` → read `agent_brief` and each shot’s `note`.
3. **Look at every PNG** (Read tool) — do not judge from filenames alone.
4. Fix production code on any `FAIL` or bad visual; re-run until `failed=0`.

### What “fail” looks like

| Area | Fail signal |
|------|-------------|
| Chamber star | Star outside walkable room; path from center loops out of the chamber |
| Mouth pad | Star sits inside tunnel auto-transit suck zone (player yanked away) |
| Trail | Marker missing / not hit-testable where kids stand |
| Doorway | Path from A toward B does not end in a chamber |
| Rails | Locked tile no longer arms “reveal tour”; collected tile no longer arms video |
| Live tap | Tap on nursery star does not path / arrive inside approach radius |

## Device capture (optional)

```bash
./qa/capture_device_walk.sh 20
```

Tap log + frames go to `qa/out/device/<timestamp>/`.

## Related

- Logic unit tests: `godot --headless --path game -s res://tests/run_tests.gd`
- Shared process: [`../../docs/QA_SUITE_PROCESS.md`](../../docs/QA_SUITE_PROCESS.md)
- Garden exemplar: [`../../garden_explorer/qa/`](../../garden_explorer/qa/)
