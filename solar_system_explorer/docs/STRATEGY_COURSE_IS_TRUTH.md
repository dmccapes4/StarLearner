# STRATEGY — Charted course is the only flight truth

*Invariant for Mission Flight: the plot-time timeline flies the ship; rendered
3D worlds are presentation and must never steer, bounce, or invent collisions.*

**Status:** Handoff dialed in (2026-08-04) — marker LOD **0 fails**; Earth→Saturn
Jupiter pin + late Saturn loom verified.  
Companion to [`STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY.md`](STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY.md).

**Audience:** agents + Dylan.

---

## 0. Verdict

1. Charted timeline only — no Mission Flight collision / bounce.
2. Peers: pure AU + charted **AR pins** (`SIM_MARKER_PX`) — never local blend.
3. Dest: **AR pin until** `path_u ≥ SIM_DEST_LOCAL_U` (0.78), then local loom
   capped by `SIM_DEST_CRUISE_MAX_PX`; full local in orbit.
4. MARKERS handoff: mesh onset **≈ pin size** (`FLYBY_HOLD_X` plateau), then
   ease to hero inside hold — no planet-spawn pop.

---

## 1. Earth→Saturn / Jupiter

| | |
|--|--|
| Jupiter | AR marker while on glass (incl. high bearing ≤95°) |
| Saturn mid-cruise | AR marker until late local loom |
| Mars / Vesta | not charted — hidden unless truly visible |

Stamps: `flight_video/2026-08-04T18-42-46` · `marker_lod/2026-08-04T18-43-30`

---

## 2. Code anchors

| Area | Where |
|------|--------|
| Peer / dest SIM_VIEW | `FlyScene._update_sim_view` |
| Charted pin FOV | `FlyScene._dir_in_charted_marker_fov` |
| Mesh onset plateau | `OrbitMath.flyby_mesh_scale` + `FLYBY_HOLD_X` |
| Handoff gates | `FLYBY_HANDOFF_MAX_X` / `_DEST` |
| Marker art | `PlanetSkins.make_icon_texture` |
| Bounce (Free Flight only) | `PlaygroundScene` |

---

## 3. QA

```bash
./qa/run_marker_lod_suite.sh
FLIGHT_TRIPS=earth_saturn_astro REVIEW=0 ./qa/run_flight_video_suite.sh
python3 qa/review_jupiter_flyby_earth_saturn.py qa/out/flight_video/<stamp>
python3 qa/review_marker_icons.py qa/out/marker_lod/<stamp>
```
