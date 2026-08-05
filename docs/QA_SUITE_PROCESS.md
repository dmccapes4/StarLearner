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
| Bed plants | `qa/run_bed_plants_suite.sh` → `game/tools/bed_plants_suite.gd` |
| Season trees | `qa/run_season_trees_suite.sh` → `game/tools/season_trees_suite.gd` |
| Local notes | `garden_explorer/qa/README.md` |

## Runner contract

Each `qa/run_<suite>.sh` should:

- Resolve Godot (`godot` or `~/.local/bin/godot`).
- **Prefer on-screen Godot** (`DISPLAY` + `XAUTHORITY`) — Vulkan/GPU is often
  an order of magnitude faster than `--headless` dummy rendering, and PNGs are real.
- Fall back to `xvfb-run`, then `--headless` only if no display is available.
- Invoke: `godot --path <game> --fixed-fps 24 -s res://tools/<suite>.gd`
- Print latest `report.json` summary (`passed` / `failed` / `FAIL` lines).
- Exit non-zero if any check failed.

Orchestrator: `tools/run_interactive_qa.sh` (auto-fills `:1` + gdm `XAUTHORITY` when possible).

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
| **Garden Explorer** | Depth · bed approach / gaps · bed plants · season trees · **Walk video + Grok vision** (`qa/run_walk_video_suite.sh`) |
| **Ant Explorer** | ✅ `qa/run_chamber_suite.sh` — chambers/stars/trails/rails · ✅ **Movement video + Grok vision** (`qa/run_movement_video_suite.sh`) · (next) phone UI chrome |
| **Solar System Explorer** | **Flight mechanics** · **Flight video + Grok vision** (`qa/run_flight_video_suite.sh`) · marker LOD · proximity |
| **Math Explorer** | Cube counts match numerals · tab contrast · word-problem layout |
| **Language Explorer** | Trace hitboxes · letter card contrast · bilingual label clarity |

Each game keeps suites under **its own** `qa/` so a Cursor window rooted on that game can run them without hunting the monorepo.

## Vision review (Grok / OpenAI) — frames + game-state sidecar

When screenshots alone are ambiguous (flight canopy, depth sort, motion), add a
**vision review** step: the agent (or a script) sends **sampled PNGs plus a
sim/game-state sidecar** to a multimodal model and gets a structured debug report.

Solar System Explorer pioneered this for Mission Flight; Garden Explorer mirrors
it for yard walks (`walk_video` + `review_walk_videos.py`); Ant Explorer mirrors
it for nest walks (`movement_video` + `review_movement_videos.py`).

### Artifact contract (per case / trip)

```
qa/out/<suite>/<stamp>/<case_id>/
  frames/f_0000.png …          # evenly spaced (or key poses)
  sim.jsonl  OR state.jsonl    # one JSON object per frame (ground truth)
  route.json / meta.json       # optional: charted path, mode, notes
  flight.mp4                   # optional mux for humans
  review.json                  # model output (structured)
```

Each `sim.jsonl` / `state.jsonl` line should include at least:

| Field | Purpose |
|-------|---------|
| `frame` / `movie_t` / progress `u` | Align image ↔ state |
| Expected visibility flags | What the game *intended* to draw |
| Render flags (`render_icon`, `render_mesh`, …) | What the engine actually enabled |
| Geometry cues | Bearing, depth, size, `in_fov`, mismatches |

The model prompt must say: **compare image vs sidecar; do not invent objects;
severity = blocker / major / minor / ok**.

### Reference implementation

| Piece | Path |
|-------|------|
| Capture suite (Solar) | `solar_system_explorer/game/tools/flight_video_suite.gd` |
| Runner + mux (Solar) | `solar_system_explorer/qa/run_flight_video_suite.sh` |
| Vision reviewer (Solar) | `solar_system_explorer/qa/review_flight_videos.py` |
| Capture suite (Garden) | `garden_explorer/game/tools/walk_video_suite.gd` |
| Runner + mux (Garden) | `garden_explorer/qa/run_walk_video_suite.sh` |
| Vision reviewer (Garden) | `garden_explorer/qa/review_walk_videos.py` |
| Capture suite (Ant) | `ant_explorer/game/tools/movement_video_suite.gd` |
| Runner + mux (Ant) | `ant_explorer/qa/run_movement_video_suite.sh` |
| Vision reviewer (Ant) | `ant_explorer/qa/review_movement_videos.py` |
| Keys | `star_learning/.env` → `XAI_API_KEY` (preferred) or `OPENAI_API_KEY` |

```bash
# Solar — Mission Flight
REVIEW=0 ./qa/run_flight_video_suite.sh
REVIEW=1 ./qa/run_flight_video_suite.sh
python3 qa/review_flight_videos.py qa/out/flight_video/<stamp>

# Garden — yard walks / depth / seeds / Buddy
REVIEW=0 ./qa/run_walk_video_suite.sh
REVIEW=1 ./qa/run_walk_video_suite.sh
python3 qa/review_walk_videos.py qa/out/walk_video/<stamp>

# Ant — nest tunnels / stars / trails / reveal tour
REVIEW=0 ./qa/run_movement_video_suite.sh
REVIEW=1 ./qa/run_movement_video_suite.sh
python3 qa/review_movement_videos.py qa/out/movement_video/<stamp>
```

### Rate limits (do not serialize naively)

Vision calls are slow (~30–90s each). **Do not** fire every trip at once (429s)
and **do not** wait for each to finish before starting the next.

`review_flight_videos.py` defaults:

| Env | Default | Meaning |
|-----|---------|---------|
| `REVIEW_CONCURRENCY` | `3` | Max trips in flight |
| `REVIEW_STAGGER_S` | `2.0` | Seconds between *starting* each trip |
| `REVIEW_MAX_RETRIES` | `5` | Backoff on 429 / 5xx (`Retry-After` honored) |
| `REVIEW_MAX_FRAMES` | `12` | Images per trip |
| `REVIEW_MODEL` | `grok-4.5` / `gpt-4o` | Provider default |

Staggered overlap: start trip A, wait 2s, start B, wait 2s, start C — while A/B
still run. Wall time drops sharply vs sequential; 429s stay rare.

Garden’s `review_walk_videos.py` already shares the concurrency knobs; other
games can copy either reviewer and swap the system prompt / schema fields.

### Agent workflow (vision suites)

1. Run the capture suite → stamped folder with frames + sidecar.
2. Run (or let the runner invoke) the vision reviewer.
3. Read `REVIEW.md` / per-case `review.json` **and** open failing PNGs.
4. Fix production code; re-capture only the affected cases when possible.
5. Treat `blocker` / `major` as suite red; `minor` is polish.

## Device capture (optional)

When desktop suites are green but the phone still feels wrong:

```bash
./qa/capture_device_walk.sh 20
```

Pull screenrecord + frames into `qa/out/device/<stamp>/`. Use for motion/feel, not as the only gate.

## Deploy gate

Interactive-world titles must be green before packaging / fogona install:

```bash
./tools/run_interactive_qa.sh          # ant + garden + solar
./tools/require_qa_green.sh garden --apk garden_explorer/tools/build/com.dylan.garden_explorer.apk
```

`garden_explorer/tools/build_garden_apk.sh` runs the garden suites first (unless `SKIP_QA=1`).
`tools/recover_garden_fogona.sh install-245` refuses an APK newer than the latest green report.
Math / Language are not in this gate (no world routing/depth suites yet).

## Do / don’t

**Do**

- Assert the production API the game actually calls (`bed_approach_world`, door apron, etc.).
- Keep cases kid-shaped (“tap other side of middle bed → walk the gap”).
- Gitignore `qa/out/`.
- Link the game’s `qa/README.md` from the game README.
- Run `./tools/run_interactive_qa.sh` as the last game-side step before deploy.

**Don’t**

- Judge screenshots from filenames or JSON alone.
- Soften asserts to match a bad visual — fix the game.
- Require host `sudo` for suites (user-local Godot only).
- Put shared suite *code* in this docs folder — only the **process** is shared; implementations stay per game.

## Reference implementation

- Process exemplar: `garden_explorer/qa/`
- Depth contract notes: `garden_explorer/docs/ARCHITECTURE_MOVEMENT_AND_DEPTH.md`
- This file: living checklist for new titles and new Cursor windows
