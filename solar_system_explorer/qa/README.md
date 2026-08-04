# Solar System Explorer QA

Agent-oriented playtest harnesses. Screenshots land under `qa/out/` (gitignored).

**Shared process for all Star Learner games:** [`../../docs/QA_SUITE_PROCESS.md`](../../docs/QA_SUITE_PROCESS.md)

**Sensor / kid-motion research (Free Flight):** [`../docs/RESEARCH_MOTO_G_PLAY_2024_SENSORS_AND_KID_MOTION.md`](../docs/RESEARCH_MOTO_G_PLAY_2024_SENSORS_AND_KID_MOTION.md)

## Flight mechanics suite

Covers **mission chart burn profile** (OrbitMath accel→coast→brake, transfer arc) and **Free Flight** (speed chooser, tilt helpers, gear speeds, Cruise & Stop tutorial tables, joystick latch invariants from the Moto G Play / six-year-old research).

```bash
./qa/run_flight_mechanics_suite.sh
```

Outputs: `qa/out/flight_mechanics/<stamp>/report.json` + PNGs.

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
