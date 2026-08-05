# STRATEGY — Charted course is the only flight truth

*Invariant for Mission Flight: the plot-time timeline flies the ship; rendered
3D worlds are presentation and must never steer, bounce, or invent collisions.*

**Status:** Diagnosed + first fix landed (2026-08-04). Targeted Earth→Jupiter
vision suite **green** — stamp `qa/out/flight_video/2026-08-04T18-10-27/`
(Grok: no bounce, no fake mesh hit, cruise cap 56 px, orbit loom OK). Companion to
[`STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY.md`](STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY.md).

**Audience:** agents + Dylan.

---

## 0. Verdict

1. **Mission Flight has no live collision response.** `OrbitMath.plot_route` /
   `simulate_route` treat worlds as points; playback is `_place_ship_at_path` on
   the baked timeline. Playground bounce does **not** apply here.
2. **Earth→Jupiter “collision” was a render illusion.** Closest approach to
   Jupiter on the chart is ~**4.2× hero** (orbit standoff). The path never enters
   the planet. SIM_VIEW was still growing Jupiter’s disc to ~**120 px** before
   the orbit cut — that reads as impact.
3. **Meshes ≠ truth.** If the glass shows a hit while `course_clearance` is
   clear, fix presentation (cap / pin / cull), never steer the ship.

---

## 1. Evidence (Earth→Jupiter, chemical / Astrogator)

| Probe | Result |
|-------|--------|
| Dest min dist / hero | **4.17×** at path end (park), never `< 1` |
| Origin Earth at departure | ~**1.03×** hero (park leave — pin OK, mesh loom bad) |
| Charted encounters | **0** (no mid-cruise peer flyby on this hop) |
| Pre-fix SIM ang (path_u≈0.84) | Jupiter ~**94 px** then orbit ~**120 px** |
| Post-fix cruise cap | `SIM_DEST_CRUISE_MAX_PX = 56` until orbit |

---

## 2. Product rules (non-negotiable)

1. Ship heading follows the **charted timeline only**.
2. No collision detection, bounce, or deflection on Mission Flight.
3. Courses are **not** charted around collisions — empty space between points.
4. If a collision is *rendered*, that is a **bug in presentation**.
5. Orbit hard-cut is allowed (arrival park). A bounce mid-cruise is not.

---

## 3. Fixes shipped

| Area | Change |
|------|--------|
| `FlyScene` SIM_VIEW | Cap destination disc during cruise (`SIM_DEST_CRUISE_MAX_PX`); full loom only in orbit |
| `FlyScene` MARKERS | Never mesh-loom the **origin** (park departure looks like a hit) |
| Flight video suite | `FLIGHT_TRIPS=` filter; `route.course_clearance` + invariant string |
| Vision review | ~1 Hz second-tick frames + code excerpts; `course_honesty` schema |

---

## 4. QA recipe (targeted)

```bash
FLIGHT_TRIPS=earth_jupiter_astro REVIEW=1 ./qa/run_flight_video_suite.sh
# Read: qa/out/flight_video/<stamp>/REVIEW.md
#       …/earth_jupiter_astro/route.json → course_clearance
#       …/earth_jupiter_astro/sim.jsonl  → ang_radius_px per second
```

Reviewer must flag **fake_collision** when clearance is clear but the canopy
looks like impact / bounce.

---

## 5. Follow-ups (if still wrong on device)

1. Soften orbit cut (short blend) so park doesn’t feel like a rebound.
2. Dest MARKERS late-approach mesh: keep clearance-aware scale (already
   `FLYBY_CLEARANCE`); confirm origin pin-only on Quick Course hops.
3. Never reintroduce peer local blend while `_orbiting` (already gated).
4. Do **not** add runtime collision dodging — that violates this strategy.

---

## 6. Code anchors

- `OrbitMath.plot_route` — “NO collision dodging”
- `FlyScene._place_ship_at_path` — timeline playback, faces travel
- `FlyScene._update_sim_view` — shell discs; cruise dest cap
- `PlaygroundScene` — bounce lives **only** here (Free Flight)
