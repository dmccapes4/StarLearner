# Agent QA suite process (all Star Learner games)

Garden Explorer pioneered an agent-friendly playtest loop: **scripted Godot suites → PNGs + `report.json` → agent reads images → fix → re-run**. Other titles should get the same treatment from their own windows so regressions stay visible and kid-facing.

## Why this exists

Unit tests catch API contracts. Kids notice **routing, depth, and stand points**. Suites freeze those into:

1. Deterministic setup (skip intro, pause idle clocks).
2. Named cases with **asserts** (`OK` / `FAIL`).
3. **Screenshots** the agent must open with the Read tool (never judge from filenames alone).
4. A stamped output folder under `qa/out/<suite>/<timestamp>/`.

## Layout (per game)

```
<game>/
  qa/
    README.md                 # suite list + how to run
    run_<suite>.sh            # thin wrapper → Godot -s
    capture_device_walk.sh    # optional phone screenrecord
    out/                      # gitignored artifacts
  game/tools/<suite>.gd       # SceneTree script (asserts + shots)
  docs/…                      # depth / movement contracts when relevant
```

Mirror Garden Explorer:

| Piece | Garden Explorer example |
|-------|-------------------------|
| Runner | `garden_explorer/qa/run_bed_approach_suite.sh` |
| Script | `garden_explorer/game/tools/bed_approach_suite.gd` |
| Depth suite | `qa/run_depth_suite.sh` → `game/tools/depth_suite.gd` |
| Local notes | `garden_explorer/qa/README.md` |

## Runner contract

Each `qa/run_<suite>.sh` should:

- Resolve Godot (`godot` or `~/.local/bin/godot`).
- Prefer on-screen `DISPLAY`; else `xvfb-run` or `--headless`.
- Invoke: `godot --path <game> --fixed-fps 24 -s res://tools/<suite>.gd`
- Print latest `report.json` summary (`passed` / `failed` / `FAIL` lines).
- Exit non-zero if any check failed.

## Suite script contract

Each `game/tools/<suite>.gd` (`extends SceneTree`) should:

1. Boot the real main scene (or a minimal world that shares production code paths).
2. Skip intros / disable idle season advance so time stays frozen.
3. Run **named checks** via a helper (`_check(name, ok, detail)`).
4. Write PNGs for start / mid / approach poses that matter.
5. Write `report.json` with:
   - `suite`, `checks[]`, `shots[]`
   - `agent_brief` — one paragraph telling the next agent what FAIL means
6. `quit(0)` on all pass, `quit(1)` on any fail.

### Agent workflow (every suite)

1. Run `./qa/run_<suite>.sh` from the game root.
2. Open `qa/out/<suite>/<stamp>/report.json`.
3. **Read every PNG** with the image Read tool.
4. Fix production code (not the suite, unless the assert was wrong).
5. Re-run until `failed=0`.
6. Only then install to a device if playtest needs hands-on confirmation.

### What “fail” looks like (examples)

| Domain | Fail signal |
|--------|-------------|
| Depth / iso | Character painted **under** a building they stand in front of |
| Approach / path | Long loop around a cluster instead of a short gap / aisle |
| Interact stand | Feet inside a solid, or overlapping a pet sprite |
| Gate / fence | Missing end post; rails sorted above/below the walker wrongly |

## Suggested suites by game

Start small — one suite that catches the pain kids already notice.

| Game | First suite ideas |
|------|-------------------|
| **Garden Explorer** | Depth · bed approach / gaps · (next) animal stand-off |
| **Ant Explorer** | ✅ `qa/run_chamber_suite.sh` — all chambers/stars/trails/rails · (next) phone UI chrome |
| **Solar System Explorer** | **Flight mechanics** (`qa/run_flight_mechanics_suite.sh`) · proximity / camera framing · burn→coast readability |
| **Math Explorer** | Cube counts match numerals · tab contrast · word-problem layout |
| **Language Explorer** | Trace hitboxes · letter card contrast · bilingual label clarity |

Each game keeps suites under **its own** `qa/` so a Cursor window rooted on that game can run them without hunting the monorepo.

## Device capture (optional)

When desktop suites are green but the phone still feels wrong:

```bash
./qa/capture_device_walk.sh 20
```

Pull screenrecord + frames into `qa/out/device/<stamp>/`. Use for motion/feel, not as the only gate.

## Do / don’t

**Do**

- Assert the production API the game actually calls (`bed_approach_world`, door apron, etc.).
- Keep cases kid-shaped (“tap other side of middle bed → walk the gap”).
- Gitignore `qa/out/`.
- Link the game’s `qa/README.md` from the game README.

**Don’t**

- Judge screenshots from filenames or JSON alone.
- Soften asserts to match a bad visual — fix the game.
- Require host `sudo` for suites (user-local Godot only).
- Put shared suite *code* in this docs folder — only the **process** is shared; implementations stay per game.

## Reference implementation

- Process exemplar: `garden_explorer/qa/`
- Depth contract notes: `garden_explorer/docs/ARCHITECTURE_MOVEMENT_AND_DEPTH.md`
- This file: living checklist for new titles and new Cursor windows
