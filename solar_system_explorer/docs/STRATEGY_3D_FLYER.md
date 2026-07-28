# STRATEGY — 3D Flyer (Solar System Explorer, next iteration)

*Design brief for turning the 2D scroll-strip preview into a **3D piloting game**: pick a
destination, watch a course get plotted on an overhead board, drop into a procedurally-generated
cockpit, and fly the route through a **compact** solar system where planets are big and heroic but
distant worlds stay small until you're on top of them. Product names: device + home app =
**Star Learner**; this title = **Solar System Explorer** under `star_learning/solar_system_explorer/`.
This supersedes the 2D piloting strip; the video/narration/catalog plumbing is reused as-is.*

---

## COLD OPEN — WHY THIS IS HARD

**McCLANE:** You want a real solar system? Fine. Draw Earth one pixel wide and Neptune's four
football fields to the right, off the screen, in the dark, forever. Kid taps "Neptune," stares at
black for a minute, and quits. Real scale is a screensaver, not a game.

**FEYNMAN:** So we lie — carefully. We keep the *ordering* and the *feeling* true (Jupiter dwarfs
Mercury; the Sun is the center everything falls around) and we compress the *distances* until they
fit a six-year-old's patience. The honest part isn't the metres; it's the relationships. A planet
is small when it's far and grows huge as you arrive — that's real perspective, just with the ruler
bent.

**McCLANE:** And the planets *move*. She picks Mars, but by the time she gets there Mars has
wandered off.

**FEYNMAN:** Good — that's the best teaching moment in the whole game. You don't fly to where Mars
*is*, you fly to where Mars *will be*. The overhead board shows the lead, the curve, the intercept.
She learns orbits by aiming at a moving thing. We just have to make the aiming automatic and the
math invisible.

**McCLANE:** One screen, one kid, one thumb. No astrophysics homework.

**FEYNMAN:** Right. The simulation is rigorous under the hood; the surface is "point, watch the
line draw itself, sit in the cockpit, go."

---

## 1. What changes vs. the current preview

The shipped preview (2D) flow is: **Title → orrery tour → astronaut briefing → horizontal piloting
strip → tap a body → video**. The 3D flyer keeps the bookends (title, astronaut briefing, per-body
documentary clips, narration, PREVIEW badge, kiosk tile) and **replaces the middle** — the flat
scroll strip becomes a real 3D flight with two staged views:

| Stage | 2D preview (today) | 3D flyer (this doc) |
|-------|--------------------|---------------------|
| Choose a place | tap a cell in a strip | tap a body on the **plotting board** (or a body ahead through the canopy) |
| Travel | ship tweens along a row | **course plotted overhead**, then **flown in-cockpit** through 3D space |
| Motion | static bodies | bodies **orbit**; route leads the moving target |
| Arrive | video opens | ship pulls up to the (now huge) body → same documentary clip |
| Art | procedural discs + 2 sprites | procedural 3D spheres + **agent-generated cockpit asset** + starfield |

Everything else (SolarData ids, `res://videos/<id>.ogv`, TTS narration, `.gitignore` for the
YouTube cache, the launcher catalog entry) is unchanged.

---

## 2. The core loop (the four beats the design calls for)

```
   ┌────────────────────────────────────────────────────────────────────┐
   │  A. SNAPSHOT + PLOT          B. OVERHEAD RUN-THROUGH                 │
   │  pick a destination →        top-down board: planets orbiting,      │
   │  freeze current orbit        a line charts the course to the        │
   │  state, compute intercept    target's *future* position (a ghost)   │
   │            │                            │                           │
   │            ▼                            ▼                           │
   │  D. ARRIVE + LEARN           C. COCKPIT FLIGHT                       │
   │  target fills the canopy →   drop into generated cockpit, fly the    │
   │  documentary clip plays      same route in compact 3D; far worlds    │
   │  (reuses videos/<id>.ogv)    stay small until they swell into view   │
   └────────────────────────────────────────────────────────────────────┘
```

### Beat A — snapshot & route (given rotations)
On destination select, freeze the orbital clock at `t0` and record every body's angle. Because the
planets keep orbiting during the trip, we don't aim at the target's *current* spot — we solve for
an **intercept** (see §4). Output: an arrival time `t_arr`, the target's predicted position, and a
smooth path from the ship's current body to that point.

### Beat B — overhead plotting board
A top-down view (evolution of today's `OrreryBodies`) shows the system, fast-forwards the orbits so
the child can *see* the target drift, and draws the **course line** to the predicted intercept with
a translucent "ghost" of the destination sitting where it will be on arrival. A ship marker runs
the line once as a preview. Narration: *"Plotting a course to Jupiter. It's moving, so we aim ahead
of it!"* A big **GO** button (or auto-advance) commits.

### Beat C — cockpit flight
Cut to first person inside a **procedurally-generated cockpit** (canopy frame + dashboard) looking
out at the 3D scene. The camera flies the committed path with the same **ease-in / ease-out speed
feel** the 2D ship already uses (accelerate out, coast, decelerate onto the target). Autopilot on
rails by default (see §7); the child just watches / can tap "boost."

### Beat D — arrive & learn
As the ship closes, the destination grows from a distant dot to a full hero-sized world filling the
canopy. On arrival the body's `res://videos/<id>.ogv` documentary plays (same VideoPanel contract),
then it returns to the cockpit/plotting board to pick the next hop.

---

## 3. The scale problem — finding the "happy medium"

This is the crux. We want **three things that fight each other**: (1) big, characterful planets;
(2) a *compact* system you can cross in ~15–40 s; (3) the truthful feel that distant things are
small. Resolution = **decouple distance-scale from apparent-size-scale**, and only ever "inflate"
the world you're near.

### 3.1 Compress distance, preserve order
Map each body's real semi-major axis `a` (AU) to a game radius with a **sub-linear** compression so
the outer system doesn't run off to infinity:

```
r_game = BASE + SPAN * pow(a_AU / a_MAX, 0.45)      # 0.45 ≈ between sqrt and log
```

Tune `BASE`/`SPAN` so Mercury→Neptune spans a crossable board. Keep strict ordering (Mercury inner,
Neptune outer) so the map is still *true*, just squeezed. The asteroid belt becomes a thin ring/
field between Mars and Jupiter's radii.

### 3.2 Hero sizes, not real sizes
Draw planets at **legible "hero" radii** with the *relative ordering* preserved (Jupiter clearly
biggest, Mercury/Pluto smallest) but the *ratio* heavily compressed — real ratios (Jupiter is ~28×
Mercury) would make small worlds invisible. A gentle curve (e.g. `hero_r = lerp(min,max, pow(rank,
0.5))`) keeps them all readable while Jupiter still visibly wins.

### 3.3 Apparent-size LOD = "small until in view"
Here's the trick that makes big planets + compact distances coexist without everything overlapping:
**a body only renders at its hero size inside a focus bubble around the ship.** Outside it, clamp it
to a small minimum on-screen size (a billboard `Sprite3D` / point of light), so it reads as a far
dot. Blend by distance to avoid pop:

```
apparent = clamp(hero_r * (FOCUS_DIST / dist), MIN_DOT, hero_r)
# far away  → MIN_DOT (a dot),  close → hero_r (fills the canopy)
```

So at any instant only the **origin and destination** are "big"; the rest are stars-with-mass in the
distance. That is exactly the requested behavior — *"other planets small until in view"* — and it
sidesteps the overlap that huge planets in a compressed field would otherwise cause.

### 3.4 Two knobs to tune together (the "happy medium")
- `DISTANCE_COMPRESSION` (§3.1 exponent + span): how squeezed the map is.
- `FOCUS_BUBBLE` (§3.3 `FOCUS_DIST`, `MIN_DOT`): how close you must get before a world "blooms."

Ship them as exported constants and tune on-device. Target: a hop feels like a short, exciting
cruise (dots streaming past) that ends in a dramatic bloom as the destination fills the glass.
**Do not chase realism here** — chase "reads clearly + feels like flying."

### 3.5 Coplanar first
Keep all orbits in one plane (inclination ≈ 0) for v1. It massively simplifies intercept math,
camera framing, and the overhead board. Add slight tilts later only if they read as charming, not
confusing.

---

## 4. Route computation with rotating bodies (intercept)

Travel time depends on distance, which depends on the target's *future* position, which depends on
travel time — a fixed point. Solve it cheaply:

```
# bodies orbit: pos_i(t) = center + polar(r_game_i, theta_i0 + omega_i * t)
# ship travels at eased speed with mean cruise speed v (game units / s)

t = distance(ship_pos, pos_target(0)) / v          # seed guess
repeat 3x:                                          # fixed-point iteration
    aim = pos_target(t)
    t   = distance(ship_pos, aim) / v
arrival_pos = pos_target(t);  t_arr = t
```

Three iterations converge for our compressed radii and gameplay speeds. `omega_i` comes from the
existing per-body `period` (visual orbit seconds) already in `SolarData`. The path itself:

- **v1 (recommended):** a gentle **quadratic Bézier** from `ship_pos` to `arrival_pos`, control
  point pulled outward from the Sun, so courses arc like real transfer orbits and never cut
  through the Sun. Sample it into a `Curve3D` / `Path3D`.
- **later:** a proper Hohmann-ish arc for older kids / a "hard mode."

The overhead board draws this curve, plus the moving target and its arrival ghost, so the *lead* is
visible. The cockpit flight follows the same `Path3D` via `PathFollow3D` with eased `progress`.

---

## 5. Overhead plotting board (Beat B)

Evolves `OrreryBodies.gd` from decoration into an instrument:

- Top-down orthographic look at the compressed system (§3.1 radii), Sun centered.
- **Live orbits**: bodies move at a readable time-scale; a "fast-forward" preview shows the target
  drifting to its intercept.
- **Course line**: the §4 curve, animated drawing on (charting), ending at a translucent
  destination **ghost** at `arrival_pos`; a small ship icon runs the line once.
- **Callouts**: origin dot, destination name, a simple ETA as pips (no numbers to read).
- **Commit**: big thumb button **GO** (or auto-advance after the run-through + narration).

Reuse the belt rendering already written for the 2D orrery. This board is also the **destination
picker** — tap a world to plot to it.

---

## 6. Cockpit generation (Beat C interior)

"A generated form of the interior looking out." **The cockpit frame is an agent-generated image
asset** — the same pipeline that produced the astronaut girl and the ship marker: *generate → key
the window to transparent → import → composite over the live 3D scene.* Procedural drawing is only a
fallback so the scene never hard-depends on the asset (mirrors the "missing clip → coming-soon card"
resilience rule).

### 6.1 The asset
- **What:** a first-person view of a kid-friendly spaceship cockpit interior — a rounded canopy
  frame, a dashboard lip with a few big glowing buttons and a small steering yoke, maybe the ship's
  nose tips — with the **entire window opening transparent** so the live 3D scene shows through.
- **Format:** PNG, landscape **16:9** (matches the 1280×600 design and the kiosk panel), true alpha
  in the window region. Stored at `game/images/cockpit.png` alongside `astronaut_girl.png` /
  `spaceship.png`.
- **Generation brief (prompt seed):** *"First-person view from inside a cute cartoon kid's spaceship
  cockpit. A large rounded window/canopy frame fills the center; along the bottom a friendly
  dashboard with a few big glowing round buttons and a small steering yoke; simple flat-vector
  storybook style, thick clean outlines, bright cheerful colors. The window opening is a single flat
  solid magenta (#FF00FF) fill for easy keying — nothing drawn inside it (no stars, no planets)."*
  Generate 16:9.
- **Keying:** reuse the Pillow color-key/flood-fill step already used for the ship (add a small
  `tools/key_cockpit.py` or extend the existing helper): replace the magenta window with alpha=0,
  keep the full frame (no crop), then verify the window is fully transparent by compositing over a
  dark test background (exactly as we validated the ship).
- **Variants (optional):** generate 2–3 dashboard color variants and pick one per flight for gentle
  variety.

### 6.2 Integration
- **v1 (default):** a `CanvasLayer` → `TextureRect` overlay above the 3D `SubViewport`. The PNG
  frames the live scene; taps land in the transparent window and pass through to body selection.
  One texture, one draw.
- **v2 (parallax):** the same art on a camera-parented quad just inside the near plane, so small
  head-bob / roll gives real depth. Still a single texture.
- **HUD** is drawn in-engine *on top of* the asset so it can animate: icon-only — target thumbnail,
  a distance bar that empties as you close, a heading arrow to the destination. No numbers to read.
- The **view out** is the 3D scene (planets, Sun glare, streaking stars); a subtle inner vignette on
  the frame sells "inside a canopy."

### 6.3 Why an asset (not procedural)
A generated cockpit reads as a *place* — a real ship you're sitting in — far better than vector
rectangles, and it matches the warmth of the astronaut tile. It is a one-time cost with **zero**
runtime expense (a single texture), so it is the right default; procedural stays only as the safety
net. Keep it one calm frame — everything a child needs is spoken or shown as a shrinking bar.

---

## 7. Flight model & camera

- **Autopilot on rails (default).** Six-year-old-first: the ship flies the plotted `Path3D`
  itself. The child watches the dots stream by and the destination bloom. Optional single **BOOST**
  tap briefly speeds time (fun, harmless).
- **Speed curve**: reuse the shipped feel — `TRANS_CUBIC`, `EASE_IN_OUT` (accelerate off the origin,
  coast, decelerate onto the target). Duration scales with path length, clamped to ~15–40 s.
- **Camera**: `Camera3D` in the cockpit, looking down `+path.forward`, with a slight lead toward the
  destination so it stays framed as it blooms. Gentle roll into the Bézier's curvature for life.
- **Stars**: a big inverted sphere with a starfield texture or a GPU-particle star streak field for
  the sense of speed; cheap, no lights.
- **Later / "big-kid" mode**: optional manual steer (tilt or on-screen stick) with soft guardrails
  that keep her roughly on the corridor so she can't get lost in the black.

---

## 8. Godot architecture (4.3, mobile renderer)

Target device is the kiosk Moto G Play 2024 (Snapdragon 680, 4 GB) — **3D must stay modest.**

```
Main (Node)                         ── flow controller (mirrors current Main.gd states)
├── TitleView / AstronautIntro      ── reused as-is
├── PlotBoard (Node2D or SubViewport) ── overhead instrument (§5), evolves OrreryBodies
├── FlyScene (Node3D)               ── the 3D system + cockpit
│   ├── WorldEnvironment            ── dark space, mild bloom/glare, no global GI
│   ├── SunLight (OmniLight3D)      ── single light from the Sun; shadows OFF
│   ├── Bodies (Node3D)             ── per body: SphereMesh (low subdiv) + Sprite3D LOD dot
│   ├── Belt (GPUParticles3D)       ── asteroid field between Mars & Jupiter radii
│   ├── Stars (MeshInstance3D sky / GPUParticles3D)
│   ├── ShipPath (Path3D) + PathFollow3D → Camera3D
│   └── Cockpit (CanvasLayer/Control or mesh) ── generated interior (§6)
└── VideoPanel (CanvasLayer)        ── reused; plays res://videos/<id>.ogv on arrival
```

Performance rules:
- **One light** (the Sun), **shadows off**, unshaded/simple materials, `SphereMesh` at low radial/
  rings segments; distant bodies are billboards (§3.3), not meshes.
- No realtime reflections/SSAO/SDFGI. Bloom/glare only.
- Reuse the mobile renderer already set in `project.godot`; keep target ~30–60 fps on-device.
- Procedural planet materials: gradient + cheap noise in a shader keyed off `SolarData.color`
  (bands for the gas giants, ice tint for Uranus/Neptune, red for Mars). No texture downloads.

---

## 9. Data model evolution

Extend the single source of truth (`SolarData.gd`) rather than forking it. Add per body:

| Field | Meaning | Source |
|-------|---------|--------|
| `a_au` | real semi-major axis (AU) | almanac constant |
| `orbit_r` | compressed game radius | computed via §3.1 |
| `theta0` | starting orbital angle | seeded (spread out) |
| `omega` | angular speed (rad/s) | from existing `period` |
| `hero_r` | 3D hero sphere radius | computed via §3.2 |
| `spin` | axial spin (visual) | small constant |

Keep existing fields (`id`, `name`, `color`, `blurb`, `facts`, `belt`, `dwarf`). The 2D `orrery_rx`/
`draw_radius` can stay for the plotting board or be derived from the new fields. **All new geometry
must remain headless-unit-testable** (positions, intercept solve, path sampling) exactly like the
current `scroll_layout()` / `tour_sequence()` tests — no 3D node needed to verify the math.

---

## 10. Kid-first constraints (unchanged contract)

- **One thumb, big targets** (≥ 96 px), landscape only.
- **No reading required** — every prompt spoken; ETAs and distances are bars/pips, not numbers.
- **Calm, never fail** — autopilot can't crash; you always arrive; back/home always available.
- **Short** — a hop is 15–40 s; the documentary is the payoff, the flight is the seasoning.
- **PREVIEW** badge stays until this is production-blessed.

---

## 11. Phasing

1. **Math core (headless).** ✅ `SolarData.flyer_bodies`, `OrbitMath`, `SolarFlyerConfig.tres`;
   unit tests for intercept, Sun clearance, hop band, apparent-size monotonicity.
2. **Plotting board.** ✅ `OrreryBodies` PLOT mode + `PlotBoard` choreography — live orbits,
   charted course, arrival ghost, fast-forward *aim-ahead* lead, ship preview, ETA pips, GO
   (auto-advances after a short beat).
3. **3D flight, autopilot.** ✅ `FlyScene.gd` — cubic ease progress driver (BOOST-safe),
   LOD hysteresis, destination look-blend + bloom, banded gas-giant shader, MultiMesh belt;
   headless coverage in `_test_flight()` (path endpoints, clock, LOD, boost, belt seed).
4. **Scale tuning pass.** ✅ Calibrated `solar_flyer_config.tres` (`cruise_speed=8`,
   `focus_dist=22`, LOD band 30–48); `ScaleTune.evaluate` happy-medium tests; optional JSON
   overlay at `/sdcard/AntPhone/solar_flyer.json` (see `tools/solar_flyer.json`).
5. **Cockpit asset + HUD.** ✅ `CockpitHud` over keyed `cockpit.png` (Pillow verify composite);
   icon HUD — planet thumb, emptying distance bar, heading arrow, arrival vignette; BOOST + home;
   procedural fallback frame; headless `_test_cockpit_hud()`.
6. **Wire the bookends.** ✅ `Main.gd` `USE_3D_FLYER` — title/orrery/astronaut → board → fly →
   `VideoPanel` → board; 2D strip kept behind the flag.
7. **UX cruise loop.** ✅ Original horizontal `ScrollView` (rotating skinned discs) → true top-down
   course plot (duration scales with hop) → skinned spheres + approach bloom → cockpit course
   console → enter orbit → arrival TTS (AU/miles) → optional Learn more / Chart new course.
8. **Polish / optional big-kid manual mode.** ☐ next.

Each phase is shippable-in-preview and independently testable; keep the 2D strip available behind a
flag until the 3D loop clears the "calm + clear on-device" bar.

---

## 12. Open decisions (call these early)

- **Autopilot vs. steer:** recommend autopilot v1, manual as an unlockable later. (Decision drives
  §7 and controls.)
- **Compression curve exponent** and **focus-bubble** values — the whole feel lives here (§3.4).
- **Belt as obstacle or scenery:** fly *through* a sparse particle belt (fun) vs. skirt it (safe).
- **How many hops per session / free-roam vs. menu:** start from the plotting board each time, or
  allow "look out the window and tap a world you see"? (Both are nice; board-first is simpler.)
- **Cockpit art (decided):** an **agent-generated image asset** with a chroma-keyed transparent
  window (§6); procedural is only the fallback. Open sub-question: overlay (v1) vs. camera-parented
  quad parallax (v2).
- **Coplanar forever?** v1 yes; revisit inclination only if it adds wonder without confusion.

---

## 13. What we explicitly reuse

- `res://videos/<id>.ogv` documentary clips (Sun → Pluto + asteroid belt) and the `VideoPanel`
  one-decoder contract.
- OS TTS narration + the astronaut briefing + Title/START.
- The **image-asset pipeline** proven on the astronaut girl and ship marker (generate → color-key
  to transparent with Pillow → import) — reused to make the **cockpit frame** (§6).
- `SolarData` ids and colors; the asteroid-belt concept.
- The kiosk catalog entry, `tile_solar` (astronaut) tile, and the **preview** badge/label — no
  launcher changes needed; this stays one Godot APK (`com.dylan.solar_system_explorer`).

---

## 14. Coordinate system, units & the depth-precision trap

- **Frame:** right-handed, **Sun at the origin**, the ecliptic is the **XZ plane** with **Y up**.
  Coplanar v1 → every body lives on XZ (`y = 0`); the ship path may bow slightly in Y for drama.
- **Units:** 1 game unit is arbitrary; pick so the *whole* compressed system fits a few hundred
  units. Suggested: Neptune's `orbit_r ≈ 260`, inner planets 15–90, hero radii **1–12**, cruise
  speed **~25–60 u/s**. Then a hop is a few hundred units → 15–40 s at those speeds.
- **The trap:** real-scale space games blow the depth buffer (near 0.1 m, far 10¹² m → z-fighting).
  We dodge it *for free* by **never using real distances** — compressed radii keep the scene inside
  a small range, so `Camera3D.near ≈ 0.1`, `far ≈ 2000` gives clean depth with no logarithmic-depth
  tricks. Keep `near` as large as the cockpit allows (≥ 0.1) to maximize precision.

## 15. Concrete orbital constants (starting numbers)

Almanac values to seed the data (compress distance per §3.1, size per §3.2):

| Body | a (AU) | Period (yr) | Real radius (km) | Notes |
|------|-------:|------------:|-----------------:|-------|
| Mercury | 0.39 | 0.24 | 2,440 | fast inner |
| Venus | 0.72 | 0.62 | 6,052 | |
| Earth | 1.00 | 1.00 | 6,371 | start body |
| Mars | 1.52 | 1.88 | 3,390 | |
| Asteroid belt | ~2.7 | ~4.6 | — | ring/field, not a disc |
| Jupiter | 5.20 | 11.86 | 69,911 | biggest hero |
| Saturn | 9.58 | 29.5 | 58,232 | + ring mesh |
| Uranus | 19.2 | 84.0 | 25,362 | ice tint |
| Neptune | 30.05 | 165 | 24,622 | outermost planet |
| Pluto | 39.5 | 248 | 1,188 | dwarf, farthest |

**Angular speed:** `omega_i = TAU / (period_yr_i * GAME_YEAR_SECONDS)`. Choose `GAME_YEAR_SECONDS`
so the inner system visibly moves without being dizzying — e.g. **Earth-year = 30 s** on the board.
Then Mercury sweeps quickly (7.2 s/orbit) and Neptune barely creeps (~82 min/orbit) — which is
truthful *and* makes the "aim ahead" lesson land on the inner planets where it's visible.

**Compression sanity check** with `r_game = 12 + 250 * pow(a/39.5, 0.45)`:
Earth ≈ 12 + 250·0.176 ≈ **56**, Jupiter ≈ 12 + 250·0.404 ≈ **113**, Neptune ≈ 12 + 250·0.885 ≈
**233**. Ordering preserved, whole board ≈ 260 units. (Final constants are a tuning-pass call.)

## 16. Reference implementation sketches (GDScript)

Keep all of this **headless-testable** — no 3D node required to verify the math.

```gdscript
# Orbit position on the XZ plane at time t (seconds since epoch).
static func body_pos(b: Dictionary, t: float) -> Vector3:
    var ang: float = b["theta0"] + b["omega"] * t
    var r: float = b["orbit_r"]
    return Vector3(cos(ang) * r, 0.0, sin(ang) * r)   # Sun at origin

# Intercept: where to aim so we arrive as the target arrives (fixed point).
static func solve_intercept(ship_pos: Vector3, target: Dictionary,
        t0: float, cruise: float, iters: int = 4) -> Dictionary:
    var t: float = ship_pos.distance_to(body_pos(target, t0)) / cruise
    for _i in iters:
        var aim := body_pos(target, t0 + t)
        t = ship_pos.distance_to(aim) / cruise
    return {"arrival_pos": body_pos(target, t0 + t), "t_arr": t}

# Course: quadratic Bézier bowed away from the Sun, sampled into a Curve3D.
static func build_course(ship_pos: Vector3, arrival_pos: Vector3, samples: int = 48) -> Curve3D:
    var mid := (ship_pos + arrival_pos) * 0.5
    var out_dir := mid.normalized() if mid.length() > 0.001 else Vector3.FORWARD
    var ctrl := mid + out_dir * (ship_pos.distance_to(arrival_pos) * 0.35)  # bow outward
    var curve := Curve3D.new()
    for i in samples + 1:
        var u := float(i) / float(samples)
        var p := ship_pos.lerp(ctrl, u).lerp(ctrl.lerp(arrival_pos, u), u)  # de Casteljau
        curve.add_point(p)
    return curve
```

```gdscript
# Apparent-size LOD with hysteresis so a body doesn't flicker mesh<->billboard at the edge.
func update_lod(body: Node3D, dist: float, hero_r: float) -> void:
    var apparent: float = clampf(hero_r * FOCUS_DIST / maxf(dist, 0.001), MIN_DOT, hero_r)
    var want_mesh: bool = dist < (body.get_meta("mesh_on") if body.has_meta("mesh_on") else MESH_IN)
    # hysteresis band: turn mesh ON inside MESH_IN, OFF only past MESH_OUT (> MESH_IN)
    if dist < MESH_IN: want_mesh = true
    elif dist > MESH_OUT: want_mesh = false
    body.get_node("Sphere").visible = want_mesh
    body.get_node("Dot").visible = not want_mesh          # billboard Sprite3D
    body.scale = Vector3.ONE * (apparent / hero_r if want_mesh else 1.0)
```

Speed/eased progress reuses the shipped feel: drive `PathFollow3D.progress_ratio` with a
`create_tween().set_trans(TRANS_CUBIC).set_ease(EASE_IN_OUT)` over `clamp(len/cruise, 15, 40)` s.

## 17. Procedural planet & Sun materials

No texture downloads; a small shader (or `StandardMaterial3D`) keyed off `SolarData.color`:

- **Rocky (Mercury/Mars/Pluto):** base color + cheap value-noise mottling; Mars biased red.
- **Gas giants (Jupiter/Saturn):** latitude **bands** via `sin(uv.y * N)` mixing two tints; Jupiter
  gets a Great-Red-Spot decal (a soft ellipse in the fragment shader).
- **Ice (Uranus/Neptune):** flat-ish cyan/blue with a faint fresnel rim.
- **Saturn ring:** a thin flat `TorusMesh`/quad ring with an alpha gradient, unshaded.
- **Sun:** emissive sphere (no lighting needed on it) + a single `OmniLight3D` at the origin +
  screen **bloom**; optional additive billboard glow/flare. This is the scene's only light.

## 18. Asteroid belt

A **`MultiMeshInstance3D`** of ~200–400 tiny low-poly rocks scattered on the belt radius (random
angle, small radial + Y jitter, random spin) — one draw call, static buffer, cheap. Fly *through* a
deliberately **sparse** field (no collision; purely visual). `GPUParticles3D` is the alternative if
we want drift, but MultiMesh is cheaper and deterministic (testable seed).

## 19. Camera, FOV & framing the bloom

- FOV ≈ **65°**; `Camera3D` rides `PathFollow3D`. `look_at` blends from *path-forward* early to the
  *destination* as `progress_ratio → 1`, so the target slides to center and blooms as you arrive.
- Gentle roll proportional to path curvature; tiny idle bob for life. Near/far per §14.

## 20. Transitions & choreography

- **Board → cockpit:** on GO, quick fade + zoom from the top-down board into first-person (reuse the
  astronaut-intro fade pattern). 
- **Arrival → video:** when `progress_ratio == 1` (or apparent size crosses a threshold), call the
  existing `VideoPanel.play_body(id)`. Same one-decoder contract.
- **Video close → next hop:** return to the cockpit idle (destination filling the glass) or straight
  back to the plotting board to pick again. Home/back always available.

## 21. Audio

- Low engine **hum** loop (ducked under narration), a soft **whoosh** on boost, a bright **arrival
  chime** as the world blooms. All offline; TTS narration reused. Respect the existing Narrator
  (stop hum while a line or clip plays).

## 22. Performance budget (Moto G Play 2024)

- **Draw calls:** bodies ≈ ≤ 10 (near meshes + far billboards), belt MultiMesh = 1, Sun = 1–2,
  starfield = 1, cockpit = 1, HUD = a few. Comfortably under budget.
- **Geometry:** `SphereMesh` at ~16×16 segments for near bodies only; far bodies are billboards.
- **No** shadows, SSAO, SSR, SDFGI; bloom/glare only; MSAA off or 2×. Mobile renderer (already set).
- **Target:** 30–60 fps. Profile the belt and bloom first (usual suspects).

## 23. Testing & tuning harness

- **Headless unit tests** (mirror the existing `run_tests.gd` style): `body_pos` determinism;
  `solve_intercept` converges within tolerance in ≤ 4 iters for every body incl. fast Mercury;
  every `build_course` stays outside the Sun radius; apparent size is **monotonic** decreasing in
  distance; `t_arr` within the 15–40 s design band at the chosen cruise speed.
- **Tuning Resource:** a `SolarFlyerConfig.tres` (exported `Resource`) holding `distance_span`,
  `compression_exp`, `focus_dist`, `min_dot`, `mesh_in`, `mesh_out`, `cruise_speed`,
  `game_year_seconds` — so the §3.4 "happy medium" is tuned on-device with **no recompile**.

## 24. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Depth z-fighting | compressed scale + tuned `near/far` (§14); never real distances |
| LOD popping | hysteresis band + distance-blended apparent size (§16) |
| Motion sickness / too fast | cap cruise, ease in/out, gentle roll, no snap camera |
| Intercept won't converge (fast body) | clamp iterations; fall back to current position |
| Cockpit window mis-keyed | flat chroma fill + Pillow key + composite-verify; procedural fallback |
| 3D perf on device | draw-call budget, billboards, MultiMesh belt, no shadows (§22) |
| Empty black between hops | dots stream by, Sun glare, starfield motion — never truly empty |

---

*Bottom line: the game becomes "aim at a moving world, watch the line draw the lead, sit in the
glass, and fly there as it blooms out of the dark" — rigorous orbits underneath, one calm thumb on
top, and the ruler bent just enough to fit a six-year-old's attention.*
