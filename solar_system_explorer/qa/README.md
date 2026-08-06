# Solar System Explorer QA

Agent-oriented playtest harnesses. Screenshots land under `qa/out/` (gitignored).

**Shared process for all Star Learner games:** [`../../docs/QA_SUITE_PROCESS.md`](../../docs/QA_SUITE_PROCESS.md)

**Sensor / kid-motion research (Free Flight):** [`../docs/RESEARCH_MOTO_G_PLAY_2024_SENSORS_AND_KID_MOTION.md`](../docs/RESEARCH_MOTO_G_PLAY_2024_SENSORS_AND_KID_MOTION.md)

## Flight mechanics suite

Covers **mission chart burn profile** (OrbitMath accel→coast→brake, transfer arc) and **Free Flight** (speed chooser, tilt helpers, gear speeds, Cruise & Stop tutorial tables, joystick latch invariants from the Moto G Play / six-year-old research).

```bash
./qa/run_flight_mechanics_suite.sh
```

## Marker LOD suite

Pixel AR pins vs 3D mesh handoff for **every** flyer body (far → handoff → near).

```bash
./qa/run_marker_lod_suite.sh
```

Outputs: `qa/out/marker_lod/<stamp>/report.json` + per-body PNGs.
Regenerate marker art: `python3 tools/gen_marker_icons.py`.

## Realism budget (Phase A)

Headless Hohmann Δv / propellant-fraction / synodic-window probe — no kid UI. See [`../docs/STRATEGY_REAL_ROCKET_SCIENCE.md`](../docs/STRATEGY_REAL_ROCKET_SCIENCE.md).

```bash
./tools/run_realism_budget.sh
```

Outputs: `qa/out/realism_budget/<stamp>/report.json`.

## Flight video + vision review

Captures ~12s Mission Flight clips (PNG sequence → `flight.mp4`) with per-frame
`sim.jsonl` ground truth (bearing, angular size, FOV, render flags), then asks
Grok (`XAI_API_KEY`) or OpenAI (`OPENAI_API_KEY`) to compare render vs sim.

```bash
./qa/run_flight_video_suite.sh              # capture + review
REVIEW=0 ./qa/run_flight_video_suite.sh     # capture only
# Targeted trip(s):
FLIGHT_TRIPS=earth_jupiter_astro REVIEW=1 ./qa/run_flight_video_suite.sh
# or review an existing stamp:
python3 qa/review_flight_videos.py qa/out/flight_video/<stamp>
```

Vision review sends **≈1 Hz second-tick** frames + `sim.jsonl` state and optional
`FlyScene`/`OrbitMath` excerpts so the model can judge course-honesty (charted
path is truth; meshes must not fake collisions). Concurrent calls are **staggered**
(default: start a trip every 2s, up to 3 in flight) with 429 backoff — see
`docs/QA_SUITE_PROCESS.md` § Vision review.

| Env | Default |
|-----|---------|
| `FLIGHT_TRIPS` | *(all)* — comma ids, e.g. `earth_jupiter_astro` |
| `REVIEW_CONCURRENCY` | `3` |
| `REVIEW_STAGGER_S` | `2.0` |
| `REVIEW_MAX_RETRIES` | `5` |
| `REVIEW_MAX_FRAMES` | `13` |
| `REVIEW_SECOND_TICKS` | `1` |
| `REVIEW_CODE_CONTEXT` | `1` |
| `REVIEW_MODEL` | `grok-4.5` |

Keys live in `star_learning/.env`. Outputs: `qa/out/flight_video/<stamp>/<trip>/`
(`flight.mp4`, `frames/`, `sim.jsonl`, `route.json`, `review.json`) plus
`reviews.json` and `REVIEW.md`.

## Astrogator suite (Phase B)

Optional PlotBoard Astrogator: Kid pace vs Astrogator, Chemical / NTP / Nuclear pulse, fuel bars + window/coast ledger, FlyScene calendar coast wipe. Math for **every** Earth→body hop.

```bash
./qa/run_astrogator_suite.sh
```

Outputs: `qa/out/astrogator/<stamp>/report.json` + PNGs.

Outputs: `qa/out/flight_mechanics/<stamp>/report.json` + PNGs (tap HUD / speed / turn / stop-cruise).

### Agent workflow

1. Run `./qa/run_flight_mechanics_suite.sh`.
2. Open `report.json` → read `agent_brief` and each shot’s `note`.
3. **Look at every PNG** (Read tool) — do not judge from filenames alone.
4. Any `FAIL` is a production regression — fix game code, re-run until `failed=0`.

### What “fail” looks like

| Area | Fail signal |
|------|-------------|
| Mission burn | Short hop coasts; long hop never brakes; progress not monotonic |
| Transfer arc | Course dives inside both orbit radii (Sun dive) |
| Speed pick / tutorial shots | Blank or missing tiles / coaching UI |
| Joy latch | Quiet clears ACCEL; weak opposite (~0.35) triggers backoff |
| Gear speeds | Non-monotonic steps or cruise ≠ `SPEED` |

Requires Godot 4.3 on `PATH` or `~/.local/bin/godot`. Uses `xvfb-run` when no `DISPLAY` is set.

## Device capture (optional)

```bash
./qa/capture_device_walk.sh 20
```

Screenrecord + frames → `qa/out/device/<stamp>/` for package `com.dylan.solar_system_explorer`.

## Related

- Headless logic tests: `godot --headless --path game -s res://tests/run_tests.gd`
- Flight dynamics notes: `docs/` (STRATEGY_3D_FLYER, flight dynamics)
