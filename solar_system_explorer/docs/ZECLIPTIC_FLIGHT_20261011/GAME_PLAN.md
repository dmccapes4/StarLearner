# Zecliptic Flight — game plan

**Date:** 2026-10-11 · **Requested:** "New Godot game mode with *EVERY* control you can think of." Hop planet to planet including Sol; poles and tropics; change point of reference and speed; free-fly; landing skips any video; tap to select pauses time and offers teleport; include the belt; Pluto/Charon with the camera on Charon facing Pluto, Pluto transparent, run a full Pluto year; a camera on Sol's equator looking at Charon.
**Status:** v0.0.1 shipped 2026-10-11 — mode on shoal as Solar 0.47; see §8.

## 0. Rules carried in

- Zecliptic frame by default (XZ plane = Sol's equator, +Y = Sol's north pole). Ecliptic, invariable plane and any body's equator selectable, each labelled on the HUD with the reason it exists.
- Real geometry, nothing faked: planets by Keplerian elements with secular rates (Standish 1800–2050 table — Mercury–Jupiter already in `Ephemeris.gd`, Saturn–Pluto added here with the same source), the big belt bodies from JPL SBDB (fetched 2026-10-11, epoch JD 2461200.5), Luna by the Meeus series already in `Ephemeris.gd`, other moons circular in their primary's equatorial plane at the catalogued period and inclination with an **epoch-arbitrary phase, said so on screen**. Spin poles from the IAU 2015 table (right-hand rule). Sizes and distances are real unless the user turns a scale knob, and the knob's value is always on the HUD.
- Numbers pulled, not typed: `tools/zecliptic_export.py` writes `game/data/zecliptic_bodies.json` from `docs/MERCURY_VULCAN_LADDER_20261010/data/*.json` and the SBDB files; the GDScript reads only that file. Literals in the exporter are listed in the JSON under `literals` with their reason.
- No video on landing. Landing is a camera placement on the surface at a chosen latitude/longitude, nothing else.
- Belt objects are first-class: Ceres, Vesta, Pallas, Hygiea, Psyche, Juno (real), Eros (real, near-Earth), plus a 600-body *representative* belt (seeded, Kirkwood gaps carved) drawn and labelled as representative.

## 1. Architecture

One mode `Control` (`scripts/ZeclipticFlight.gd`) in the resident-view pattern (`set_active`, `go_home`), registered in `FlightChooser` (sixth tile "Zecliptic Flight") and `Main.gd`. A `SubViewportContainer → SubViewport(own_world_3d) → Node3D` world with one `Camera3D`. Body math lives in `scripts/ZeclipticBodies.gd` (static: load JSON, Kepler solve, frame rotations, poles, moon orbits, Pis clocks). Chrome is built in code, same conventions as the rest of the game (default font, gold accent, round back button).

Units: the world is in **scene units = 1,000 km** when the distance scale is "real", so Sol's radius is 695.7 units and Pluto's aphelion is 7.4 million units — beyond float comfort for a camera near a planet. So the world is **re-centred on the reference body every frame** (floating origin): all positions are computed in km relative to the reference body, then scaled. Camera far plane 1e7, near plane adaptive to the nearest body's surface distance. Depth is handled by rendering bodies in one pass with sizes scaled honestly; the "body size ×" knob inflates radii without moving centres.

Frames: positions are computed in the J2000 ecliptic (from the Kepler code), then rotated by the chosen frame's matrix: Zecliptic `Rx(−7.25°)·Rz(−75.76°)`, Invariable `Rx(−1.5787°)·Rz(−107.5822°)`, Ecliptic identity, Body-equator = the basis built from that body's IAU pole. Godot mapping is the one `Ephemeris.godot_dir_from_ecliptic` already uses: `(x, y, z)_frame → (y, z, −x)_godot`, so +Y is the frame's north pole.

Time: one sim clock in JD (TT≈UTC for display). Rates: pause · real time · 1 min/s · 1 h/s · 6 h/s · 1 d/s · 1 wk/s · 1 mo/s · 1 yr/s · 10 yr/s · 1 Pluto-year/min, with a reverse toggle. Date picker (year/month/day steppers), "now", and a jump list of dated events (BepiColombo MOI 2026-11-21, the 2028-02-23 Luna–Mercury occultation, the solar equinoxes where B₀ = 0, Pluto perihelion 1989-09-05, Pluto's next aphelion 2114, New Horizons flyby 2015-07-14). Pis clocks on the HUD: Luna Pis and Charon Pis elapsed since the epoch you set.

## 2. Controls (the full list)

**Navigation**
- Free-fly: W/S forward/back, A/D strafe, Q/E down/up, mouse-drag look, scroll = speed; touch: left half drag = move (joystick), right half drag = look, two-finger pinch = speed, three-finger tap = pause.
- Speed presets: 1 km/s · 100 km/s · 1 R☉/s · 1 Luna-distance/s · 10 R☉/s · 215 R☉/s (Earth mean) · 1000 R☉/s, plus "auto" (speed ∝ distance to nearest surface). Classical AU is not a display unit.
- Hop: Prev/Next body (ordered by distance from Sol), hop to Sol, hop to barycentre, hop list (every body incl. moons and the seven real belt bodies).
- Teleport (from the tap card): place the camera at `standoff × radius` from the body on the sunward-side quarter, looking at it.
- Orbit cam: lock to a body at a distance; drag to orbit around it; scroll to change distance; auto-rotate toggle.
- Follow: camera moves with the body (reference = body) but keeps free look.
- Look-at target: the camera always faces a chosen body while you stand/move elsewhere (camera on Charon, target Pluto).

**Landing (no video)**
- Land on the selected body at: North pole · Arctic circle · Tropic (north) · Equator · Tropic (south) · Antarctic circle · South pole · subsolar point · antisolar point · sub-primary point (for a moon: the point facing its planet) · custom lat/lon steppers. Tropic/circle latitudes are computed from the body's own obliquity to its orbit (e.g. 23.44° / 66.56° for Earth, 122.5°-derived for Pluto — shown on the card).
- On the surface: look around (horizon-locked), eye height stepper, "stand up / lie down" (±90° pitch), toggle local horizon ring, zenith/nadir marks, cardinal marks (body-north from its pole).
- Lift off: back to orbit cam at 3 radii.

**Reference & frame**
- Reference body (floating origin): Sol · barycentre (Sol + Jupiter + Saturn, mass-weighted) · any body. With a planet as reference, Sol and the other planets trace epicycles — that is what an Earth-centred frame looks like and the HUD says so.
- Reference plane: Zecliptic (default) · Ecliptic · Invariable · selected body's equator. The grid disc and the "north" of the world follow the plane.
- Frame declaration always on the HUD: plane, origin, and why.

**Time**
- Pause/play, reverse, rate presets, ±step (1 h, 1 d, 1 month, 1 year, 1 orbit of the selected body), scrub bar over ±1 Pluto year around the epoch, date steppers, "now", events list.
- Tap-to-select **pauses time**; "resume" is one tap.

**Scale**
- Body size ×1 (real) · ×10 · ×100 · ×1000 (centres fixed).
- Distance scale: real · log-compressed (the Playground's compression, labelled "not to scale").
- Sol glare on/off, exposure slider.

**Overlays (each toggleable)**
- Orbit lines (full orbit, re-solved every N frames in the current frame), trails (last N days), labels (with distance from camera), spin axes (through the poles, length 3 radii), equator ring, tropics and polar circles rings, prime-meridian mark, Zecliptic/Ecliptic/Invariable grid discs (R = 1.2 × reference-plane radius of the farthest shown body, with R☉ rings (1 = photosphere)), node markers (where each orbit crosses the chosen plane), perihelion/aphelion ticks, Hill spheres (translucent), Mercury's survival annulus (from `v4_annulus.json`: 13,254–81,473 km prograde, to 136,457 km retrograde), the belt sample on/off, moon orbits on/off, constellation-free star sphere on/off (from `star_positions/*.jsonl` if present), light-time circles (1, 8.3, 60 light-minutes), Sol's B₀ line (where Sol's equator meets the view).
- Transparency: per-body alpha slider (default 1.0; "Pluto transparent" = 0.25), wireframe toggle, hide body.

**Readouts (HUD, selectable)**
- Camera position in reference frame (km / R☉ / light-min), altitude above nearest surface, speed. 1 R☉ = Sol-centre to the bubbling surface.
- For the selected body: distance to camera, angular diameter as seen from camera, phase angle, distance from Sol (AU and R☉), heliocentric latitude in the chosen plane (the body's "B₀"), spin tilt to the Zecliptic (from `tilt_curve.json`), its companion's Pis, orbital period, current true anomaly, time to next perihelion / node crossing.
- Luna Pis and Charon Pis elapsed; Sol's B₀ as seen from Earth (the real one, for cross-checking against `_solar_equator_view`).

**Utility**
- Bookmarks: save/recall 9 camera+time+frame states (slot keys 1–9 with Shift to save); two presets shipped: **"Charon → Pluto"** (land on Charon at the sub-Pluto point, target Pluto, Pluto alpha 0.25, rate 1 d/s) and **"Sol equator → Charon"** (land on Sol at the equator at the sub-Charon longitude, target Charon, rate 1 month/s).
- Screenshot to `user://zecliptic/` (desktop) with the HUD state in the filename.
- Help overlay (H / ? button) listing every control; FPS/perf line; reset.
- Narration off by default in this mode (one line on entry).

## 3. Scenes & files

- `game/scripts/ZeclipticBodies.gd` — data + math (static).
- `game/scripts/ZeclipticFlight.gd` — the mode.
- `game/data/zecliptic_bodies.json` — exported data.
- `tools/zecliptic_export.py` — exporter (reads ladder JSON + SBDB, asserts Standish vs bodies_metrics agreement).
- `game/tools/record_zecliptic.gd` — headless recorder: runs the two shipped presets for N sim-days and writes PNG frames to `docs/ZECLIPTIC_FLIGHT_20261011/video/<preset>/`; `tools/vulcan/encode_vulcan.sh`-style encode.
- Registration: `FlightChooser.gd` (tile + `zecliptic_pressed`), `Main.gd` (preload, `_on_zecliptic_flight`, `_show_title`, `_hide_all_views`).

## 4. Order of work

1. Exporter + JSON (with asserts). 2. `ZeclipticBodies.gd` + a headless test that checks: Earth's heliocentric latitude in the Zecliptic frame on 2026-03-20 ≈ −7.06° (matches the DE421 value used in the video), Pluto/Charon plane tilt 119.1°, Luna Pis after one year = 42.0. 3. The mode: world, camera, free-fly, time, frames, tap card, teleport, land. 4. Overlays, readouts, bookmarks, help. 5. Registration + run the existing test runner (it force-loads every script). 6. Recorder: the Pluto/Charon and Sol-equator presets as frame sequences → mp4. 7. Commit.

## 5. Falsification hooks

- If the Zecliptic-frame latitude of Earth does not swing ±7.25° with zeros near 6 June / 7 December, the frame matrix is wrong.
- If Charon's angular diameter from Pluto's surface is not ≈ 3.9° at the sub-Charon point (606 km radius at 19,591 − 1,188 km), the scale is wrong.
- If the Mercury annulus does not sit inside Mercury's Hill sphere overlay, one of the two is misread from JSON.

## 6. Cost / limits

No TTS in this mode beyond one entry line (ElevenLabs cache reused if a matching WAV exists; otherwise the Narrator's TTS fallback). Rendering on the Android "mobile" renderer: no transparency sorting guarantees, so transparent bodies are drawn with `ALPHA` blend and `render_priority` by distance each frame.

## 7. Authorship

The request, the frame rule, the Pis clocks, the "landing skips video" rule and the two presets are the operator's. The data plumbing, the floating origin, the control list and the code are the agent's.

## 8. Shipped (2026-10-11)

**Mode.** FlightChooser sixth tile "Zecliptic Flight" / "Real system, every control" → `ZeclipticFlight` (`game/scripts/ZeclipticFlight.gd`, 1,657 lines). Math/data in `ZeclipticBodies.gd`. JSON from `tools/zecliptic_export.py` → `game/data/zecliptic_bodies.json` (44 bodies: Sol, 8 planets, Pluto, 25 named moons, 7 real belt bodies; plus a seeded representative belt). Frames: Zecliptic (default), ecliptic, invariable, selected body's equator. Floating origin, km units, landing is a camera placement (no video).

**Controls that actually run.** Free-fly (WASD/QE, mouse look, wheel speed, Shift ×10, touch left-move / right-look). Hop N/P including Sol. Tap/click a body: **pauses time**, opens the card (Teleport / Orbit / Land / Set reference / Look-at / Equator frame / Transparent / Hide). Land spots: N pole, arctic circle, tropic N, equator, tropic S, antarctic circle, S pole, subsolar, antisolar, sub-primary, custom lat/lon. Time: pause, reverse, 11 rates through 1 Pluto-year/min, ±1 day / ±1 year, now. Scale ×1/10/100/1000 and log-compressed distances (labelled). Overlays: orbits, moon orbits, grid, axes, equators/tropics, Hill, Mercury annulus, belt, trails. Bookmarks 1–9 / Shift+1–9. Presets: Charon→Pluto (Pluto transparent, look-at Pluto), Sol equator→Charon, Luna-Earth, Mercury, overview. Help (H). Screenshot to `user://zecliptic/`.

**Numbers, not typed.** Spin tilts from `tilt_curve.json` / IAU poles. Pis clocks (Luna 42, Charon 180). Annulus from `v4_annulus.json`. Standish elements: Mercury–Jupiter parsed from `Ephemeris.gd`; Saturn–Pluto listed in the exporter `literals`. SBDB epoch JD 2461200.5 for Ceres, Vesta, Pallas, Hygiea, Psyche, Juno, Eros.

**Tests (2026-10-11 03:3x, Godot 4.3.stable).** `game/tests/zecliptic_numbers.gd`: **0 failures**. B₀ 2026-03-20 −7.055 / 2026-06-06 −0.097 / 2026-09-22 +7.067; Pluto/Earth/Mercury/Uranus/Venus spin tilts to Zecliptic; Luna Pis 41.999; Charon Pis 179.65; Charon angular diameter from Pluto surface 3.774° (the plan's 3.9° was 2 asin(r/a) without subtracting Pluto's radius — the hook in §5 is the surface value); Charon orbit in Pluto's equator to 0.08°. `run_tests.gd`: 815 passed, **2 failed** — both pre-existing EarthNightSky triad checks, not this mode. Headless `load("res://scripts/Main.gd")` still fails because `GalacticView.gd` has four `:=` inference errors (also pre-existing). ZeclipticFlight / ZeclipticBodies added to the compile list; they load.

**Falsification hooks, status.**
- Earth B₀ swings ±7.25° with zeros near 6 June / 7 December: **holds** (test).
- Charon from Pluto's surface ≈ 3.77° (606 km at 19,591 − 1,188 km): **holds**. The 3.9° in §5 was the wrong formula.
- Mercury annulus ⊂ Hill overlay: **not machine-tested**; both numbers are read from the same JSON the integrator used (13,254–81,473 km prograde inside R_Hill 175,282 km). Visual check is on the phone.

**Phone.** shoal `ZL8324ZNRK` — `com.dylan.solar_system_explorer` **0.47** (versionCode 51), installed 2026-10-11 03:28, launched. Path: hub → Spaceship → Zecliptic Flight.

**Not shipped (order-of-work 6).** Headless recorder (`record_zecliptic.gd`) and the two preset mp4s. The mode is the deliverable; frames of Charon→Pluto / Sol-equator→Charon can be cut later from the same presets. Dedicated Zecliptic tile art: still `tile_solar.png`.

**Also this night, not this mode.** Tilt curve (`docs/MERCURY_VULCAN_LADDER_20261010/TILT_CURVE_20261011.md`, commit `05da4a2f`): Sol 0°, Earth/Luna 26.13° at 42 Pis, Pluto/Charon 119.14° at 180 Pis; 1 AU := R☉ (Earth 215 R☉, Pluto 8,490 R☉); birdie leans not combed (resultant 0.17); Zecliptic to invariable plane **5.97°**, not 1°.

**Authorship.** Operator: the request, Zecliptic default, Pis clocks, landing-skips-video, the two presets, "nothing should sum to 180." Agent: exporter, floating origin, control list, tests, APK, this section.
