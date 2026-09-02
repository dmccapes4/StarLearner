# MATH — Mission Control: course calculation & rendering

*Mathematical design for Solar System Explorer **Mission Flight** (PlotBoard → FlyScene).
Free Flight (`PlaygroundScene`) is out of scope: arcade seek, collision capture, and the
zodiac shell live there. Mission Flight must remain **chart-first**: geometry and Δv are
computed at plot time; the cockpit only plays them back.*

**Status:** Design + scope (2026-08-31). Implementation of Phase 1+ not started.  
**Audience:** Dylan + agents; companion to
[`STRATEGY_COURSE_IS_TRUTH.md`](STRATEGY_COURSE_IS_TRUTH.md),
[`STRATEGY_REAL_ROCKET_SCIENCE.md`](STRATEGY_REAL_ROCKET_SCIENCE.md),
[`STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY.md`](STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY.md).  
**Code anchors today:** `OrbitMath.gd` (plot / burn / encounters), `RealismBudget.gd`
(Hohmann ledger), `FlyScene.gd` (playback + MARKERS / SIM_VIEW).

---

## 0. Verdict (read this first)

1. **Hohmann is the right backbone for single-target Mission Flight** under circular,
   coplanar, Sun-dominated assumptions. It *does* solve the two-body transfer problem
   (minimum-Δv ellipse between two circular orbits). It does **not** solve the three-body
   problem, and it does **not** by itself give Jupiter gravity assists.
2. **Gravity assists are patched-conic splices**, not “run `scipy` and hope.” You stitch
   Kepler arcs (heliocentric) to a planet-centered hyperbola (planet + ship), matching
   velocity at sphere-of-influence boundaries. That is approximate, standard, and teachable.
3. **Full n-body / three-body chaos is the wrong default** for a charted kid mission.
   It is continuous-time ODE integration with no closed-form course line. Chart = flight
   becomes “sample a trajectory,” not “draw the orbit we promised.” Use it only as an
   optional high-fidelity *audit*, never as the playable chart solver.
4. **Today’s Mission Flight is not Hohmann geometry.** `RealismBudget` already computes
   Hohmann Δv and windows; `OrbitMath.plot_route` still builds an **Archimedean spiral
   transfer** timed by a **constant-thrust burn profile**. Ledger honesty and path honesty
   are disconnected. Closing that gap is the core of this program.
5. **Rendering never invents physics.** Pins, discs, and late destination loom are
   presentation of the charted timeline (`STRATEGY_COURSE_IS_TRUTH`).

---

## 1. Scope of Mission Control

### 1.1 In scope

| Concern | Meaning |
|---------|---------|
| Ephemeris | Where planets are at absolute time \(t\) |
| Window | When a departure phase exists for a transfer class |
| Transfer design | Ship path \( \mathbf{r}_s(t) \) from origin park → dest park |
| Δv ledger | Impulsive (or finite-burn stub) costs + propellant fraction |
| Encounter truth | Closest approaches along the *charted* path |
| Assist design | Optional patched-conic Jupiter/Saturn skims that reshape path + speed |
| Playback | FlyScene timeline: positions, headings, burn phases, orbit entry |
| Rendering | MARKERS / SIM_VIEW as views of the same sim |

### 1.2 Out of scope (explicit)

| Concern | Why |
|---------|-----|
| Free Flight collision / bounce | Different product; `PlaygroundScene` only |
| Mid-flight autopilot dodge | Would make the plot board a lie |
| Atmospheric launch, fallout, pulse politics | Museum VO only (`STRATEGY_REAL_ROCKET_SCIENCE`) |
| Decade / 175-year Grand Tour as gate to Saturn | Synodic single-target windows are ~1 yr |
| Treating “three-body” as a library call that replaces design | See §4 |

### 1.3 Invariant (non-negotiable)

\[
\text{PlotBoard curve} \equiv \text{FlyScene timeline path} \equiv \text{spoken geometry claims}
\]

Every VO claim (Sun flyby, pass Jupiter, slingshot boost) must be a predicate on the
**final** charted geometry. Tests already enforce this for Sun-flyby and ban unbacked
“slingshot” lines until assists exist.

---

## 2. Frames, units, and the two-body problem

### 2.1 Frames

| Frame | Origin | Use |
|-------|--------|-----|
| **HCI** (heliocentric inertial, ecliptic) | Sun | Planet ephemerides, Hohmann / Lambert arcs |
| **Game / compressed HCI** | Sun | Playable radii \(r_{\mathrm{game}}\) via compression map |
| **Planet-centered** | Assist body | Hyperbolic flyby (patched conics) |
| **Ship / camera** | Ship | Rendering bearings and angular sizes |

Game coordinates today: right-handed, Sun at origin, ecliptic = \(XZ\), \(Y\) up
(`STRATEGY_3D_FLYER` §14). Mission math should be written in **physical AU + seconds**, then
mapped to game units for display and playback.

### 2.2 The restricted two-body problem

One massive primary (Sun) with gravitational parameter \(\mu_\odot\), point-mass spacecraft
of negligible mass. Equations:

\[
\ddot{\mathbf{r}} = -\mu_\odot\,\frac{\mathbf{r}}{|\mathbf{r}|^3}.
\]

Solutions are **conic sections** with focus at the Sun (Kepler orbits): ellipse, parabola,
hyperbola. Conserved: specific energy \(\varepsilon\), specific angular momentum \(\mathbf{h}\).

Circular orbit of radius \(r\):

\[
v_{\mathrm{circ}} = \sqrt{\frac{\mu_\odot}{r}}, \qquad
T = 2\pi\sqrt{\frac{r^3}{\mu_\odot}}.
\]

Code constants (`RealismBudget.gd`):

\[
\mu_\odot = 1.32712440018\times 10^{11}\,\mathrm{km}^3/\mathrm{s}^2, \quad
1\,\mathrm{AU} = 1.495978707\times 10^8\,\mathrm{km}.
\]

### 2.3 What “solved” means here

Two-body **is** closed-form. Given \(\mathbf{r},\mathbf{v}\) you get orbital elements; given
elements and time you get position (Kepler’s equation). Hohmann is a **special design** inside
this theory: pick the unique transfer ellipse tangent to two circular orbits and compute the
two impulsive Δv’s.

---

## 3. Hohmann transfer — what it solves

### 3.1 Geometry

Assume coplanar circular orbits of radii \(r_1 < r_2\) (Earth → outer planet; swap for inward).

Transfer semi-major axis:

\[
a_t = \frac{r_1 + r_2}{2}.
\]

Vis-viva on the transfer ellipse:

\[
v = \sqrt{\mu\left(\frac{2}{r} - \frac{1}{a_t}\right)}.
\]

At periapsis (\(r = r_1\)) and apoapsis (\(r = r_2\)):

\[
v_{t,1} = \sqrt{\mu\left(\frac{2}{r_1} - \frac{1}{a_t}\right)}, \quad
v_{t,2} = \sqrt{\mu\left(\frac{2}{r_2} - \frac{1}{a_t}\right)}.
\]

Impulsive heliocentric burns:

\[
\Delta v_1 = \bigl|v_{t,1} - v_{\mathrm{circ}}(r_1)\bigr|, \quad
\Delta v_2 = \bigl|v_{\mathrm{circ}}(r_2) - v_{t,2}\bigr|.
\]

Coast duration = half the transfer period:

\[
t_{\mathrm{coast}} = \pi\sqrt{\frac{a_t^3}{\mu}}.
\]

Implemented exactly in `RealismBudget.hohmann()` (km/s and years).

### 3.2 Phase / launch window

During the coast the destination must advance so that it arrives at apoapsis when the ship does.
Required heliocentric phase of dest relative to origin at departure (circular, coplanar):

\[
\phi_{\mathrm{req}} = \pi - n_2\, t_{\mathrm{coast}}, \qquad
n_2 = \frac{2\pi}{P_2},
\]

with \(P_2\) the destination sidereal period (`hohmann_phase_required_rad`).

Synodic period (how often relative geometry repeats):

\[
\frac{1}{P_{\mathrm{syn}}} = \left|\frac{1}{P_1} - \frac{1}{P_2}\right|.
\]

Earth–Mars \(P_{\mathrm{syn}}\approx 2.1\,\mathrm{yr}\); Earth–Jupiter \(\approx 1.09\,\mathrm{yr}\).
**Single-target waits are not decade-scale.** Decade waits belong to multi-planet assist
geometries (§5).

### 3.3 LEO inject / capture stubs (Phase A honesty)

Heliocentric \(\Delta v_1\) is not “leave Earth’s surface.” From circular LEO, hyperbolic
excess \(v_\infty \approx \Delta v_1\) (heliocentric) gives an Oberth inject stub:

\[
\Delta v_{\mathrm{LEO}} = \sqrt{v_\infty^2 + v_{\mathrm{esc,LEO}}^2} - v_{\mathrm{LEO}}.
\]

Capture at destination is stubbed as \(\approx \Delta v_2\) heliocentric for Phase A
(`leo_inject_km_s`, `capture_stub_km_s`). Full patched departure/arrival hyperbolas are Phase 2+.

### 3.4 What Hohmann does *not* do

| Gap | Consequence |
|-----|-------------|
| Inclined / eccentric planets | Real Mars has eccentricity and inclination; true Δv and windows shift |
| Finite burn arcs | Real engines burn for minutes–hours; Hohmann assumes impulses |
| Third body gravity | Jupiter does not pull the ship during an Earth→Saturn Hohmann |
| Gravity assist | Requires a *different* path that enters Jupiter’s SOI |
| Continuously thrusting low-\(T/W\) ships | NEP is a spiral, not a Hohmann ellipse |
| Compressed game space | Physical AU path must be mapped; see §7 |

**Conclusion:** Hohmann *is* the mathematical answer for “minimum-Δv transfer between two
circular heliocentric orbits.” It is **not** a three-body solver, and it is **not** yet the
path that Mission Flight *flies*.

---

## 4. The three-body problem — without hand-waving

### 4.1 Statement

Three point masses with mutual Newtonian gravity. The general problem has **no closed-form
solution** in elementary functions (Bruns–Poincaré). Special cases (restricted circular
three-body, Lagrange points, periodic orbits) are their own research fields.

The **circular restricted three-body problem (CRTBP)** freezes two primaries on circular
orbits and integrates a massless third body in their rotating frame. Useful for Earth–Moon
and Sun–planet libration-point work. **Not** the right first model for “Earth→Saturn with a
Jupiter kick” in a charted kid game.

### 4.2 Why “just integrate n-body in Python” is lazy for Mission Control

You *can* integrate \(\ddot{\mathbf{r}}_i = -\sum_j \mu_j(\mathbf{r}_i-\mathbf{r}_j)/|\cdot|^3\)
with `scipy.integrate` or REBOUND. That gives a **trajectory sample**, not a **mission design**:

1. **No unique “the course.”** Tiny state errors diverge near close approaches (sensitive
   dependence). Charted GO requires a reproducible curve.
2. **No closed Δv ledger.** Impulsive burns become optimization variables (trajectory
   optimization / Lambert / primer vector), not two Hohmann numbers.
3. **Chart = flight breaks** unless you freeze the integrated polyline as truth — at which
   point you have reinvented “plot a curve and play it back,” with opaque physics.
4. **Kid narration needs predicates.** “We slingshot Jupiter” needs a defined SOI entry,
   periapsis radius, and \(\Delta v_\infty\) rotation — patched-conic language — not “the
   integrator got near Jupiter.”

### 4.3 When n-body *is* appropriate here

| Use | Role |
|-----|------|
| Offline audit | Compare patched-conic chart vs full ephemeris integration; report error bars |
| Museum mode | Optional “how wrong is the cartoon?” panel |
| Never | Live plot-time solver for Mission Flight GO |

### 4.4 Design choice

Mission Control uses **Kepler two-body arcs + patched conics for assists**. That is the
industry teaching stack (Hohmann → Lambert → patched flyby → full force-model only in ops).
We keep the same ladder.

---

## 5. Gravity assists — patched conics (the real “Jupiter kick”)

### 5.1 Sphere of influence (SOI)

Planet \(p\) with \(\mu_p\), heliocentric distance \(R_p\):

\[
r_{\mathrm{SOI}} \approx R_p\left(\frac{\mu_p}{\mu_\odot}\right)^{2/5}.
\]

Outside SOI: ship on a **heliocentric** Kepler arc. Inside: ship on a **planet-centered**
Kepler arc (usually a hyperbola for flybys).

### 5.2 Hyperbolic flyby (planet frame)

Incoming hyperbolic excess \(\mathbf{v}_\infty^-\), periapsis radius \(r_p\), gravitational
parameter \(\mu_p\). Turning angle:

\[
\delta = 2\arcsin\left(\frac{1}{1 + r_p v_\infty^2 / \mu_p}\right).
\]

The planet rotates \(\mathbf{v}_\infty\) by \(\delta\) in the B-plane; energy **in the planet
frame** is unchanged, but heliocentric velocity changes because the planet is moving:

\[
\mathbf{v}_{\odot}^{+} = \mathbf{v}_p + \mathbf{v}_\infty^{+}, \quad
\mathbf{v}_\infty^{+} = \mathcal{R}(\delta)\,\mathbf{v}_\infty^{-}.
\]

Net heliocentric \(\Delta\mathbf{v}\) can raise or lower heliocentric energy — the assist.

### 5.3 Mission design splice (Earth → Saturn via Jupiter, schematic)

1. **Depart Earth** on a heliocentric ellipse (Hohmann-like or Lambert) aimed so the path
   reaches Jupiter’s orbit at the right time with relative \(v_\infty\) that admits a safe
   \(r_p\) (above atmosphere / rings).
2. **Match** heliocentric state to Jupiter-centered hyperbola at SOI entry.
3. **Propagate** hyperbola to SOI exit; convert back to heliocentric \(\mathbf{v}^+\).
4. **Continue** on a new heliocentric ellipse/hyperbola to Saturn intercept.
5. **Capture** stub at Saturn.

Each piece is two-body. Continuity of position (and patched velocity) at boundaries is the
“mechanical” glue. **No third body is integrated simultaneously.**

### 5.4 What we designed earlier (and did not ship)

`STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY` §3.3–3.4 proposed:

- Plot-time CPA sweep vs moving planets  
- Lateral deflection so the curve never intersects a body  
- For large worlds: **skim clearance + post-CPA \(v_{\max}\) boost** with geometry-gated VO  

That was a **game-space cartoon** of an assist (deflect path + speed bump), not patched conics.
Useful as Phase 1 *presentation*, insufficient as Phase 2 *physics*. Tests currently **forbid**
unbacked slingshot narration.

### 5.5 Cadence honesty

Single Earth→Jupiter Hohmann windows ~yearly. **Grand Tour** multi-assist alignments are rare
(~175 yr class historically). Mission Control must never gate “visit Saturn” on Grand Tour
geometry. Optional later: a rare “Grand Tour card.” Assists on common hops (Earth→Saturn near
Jupiter) should use **synodic-feasible** Jupiter encounters, or clearly labeled “quick course
geometric skim” vs “Rocket Science patched assist.”

---

## 6. Today’s Mission Flight mathematics (as implemented)

### 6.1 Ephemeris (game)

\[
\mathbf{r}_b(t) = r_b\bigl(\cos(\theta_{0,b}+\omega_b t),\,0,\,\sin(\theta_{0,b}+\omega_b t)\bigr)
\]

with compressed \(r_b = \texttt{compress_orbit_r}(a_{\mathrm{AU}})\) and
\(\omega_b = 2\pi / (P_b\cdot T_{\mathrm{game\,year}})\). Circular, coplanar, kinematic —
**not** integrated gravity.

### 6.2 Course geometry — Archimedean spiral segment

Between ship position and intercept arrival, `build_course` samples:

\[
r(u) = (1-u)\,r_0 + u\,r_1, \quad
\theta(u) = \theta_0 + u\,\Delta\theta, \quad
\mathbf{r}(u) = r(u)\,(\cos\theta(u),\,0,\,\sin\theta(u)).
\]

This **looks** like a transfer and cannot dive inside \(\min(r_0,r_1)\) (Sun-safe by
construction). It is **not** a Kepler ellipse: specific energy and angular momentum are not
those of a Hohmann transfer.

### 6.3 Intercept timing

Solve for flight time \(T\) such that burn-profile travel time along the course of length
\(L(T)\) equals \(T\), while the destination reaches the parking point at \(t_0+T\):

\[
f(T) = t_{\mathrm{burn}}(L(T)) - T = 0
\]

via scan + bisection (`plot_route` / `_hop_err`). Parking endpoint sits on the destination
standoff sphere (`_hop_entry`).

### 6.4 Burn profile (playback pacing)

Trapezoidal / triangular constant-thrust cartoon along path length \(d\):

\[
T =
\begin{cases}
2\sqrt{d/a} & d \le v_{\max}^2 / a \\
d/v_{\max} + v_{\max}/a & \text{otherwise.}
\end{cases}
\]

Closed-form \(s(t)\). This is **ship-relative fiction** for kid pacing, orthogonal to Hohmann
coast years (Astrogator calendar wipe compresses real coast days into wall seconds).

### 6.5 Encounters

`course_encounters`: sample ship on curve vs `body_pos` at the same \(u\); keep peers with
\(\min|\mathbf{r}_s-\mathbf{r}_b| / R_{\mathrm{hero}} \le 7\) in mid-path canopy. Used for
pins and VO — **detection**, not dynamics.

### 6.6 Ledger vs path (the gap)

| Module | Computes | Flown? |
|--------|----------|--------|
| `RealismBudget.hop_budget` | Hohmann \(\Delta v\), coast years, windows, fuel fractions | No |
| `OrbitMath.plot_route` | Spiral + burn \(T\) + encounters | **Yes** |

Rocket Science UI speaks Hohmann truth while the ship flies spiral truth. **Phase 1 of this
program closes that.**

---

## 7. Target course calculation (full Mission Control pipeline)

### 7.1 Physical design space (AU, seconds)

**Inputs:** origin body, destination body, epoch \(t_0\), mode ∈ {Quick Course, Rocket Science},
propulsion id, assist policy ∈ {none, auto-skim if favorable, force via body}.

**Outputs (chart package):**

```
route = {
  path_au: Curve3D or samples in HCI,           # physical truth
  path_game: Curve3D,                           # compressed for board + FlyScene
  t0, t_arr,                                    # absolute times
  timeline_game: {dt, pos, fwd, events, entry}, # playback
  burns: [{t, dv_vec, frame, kind}, ...],       # ledger
  coast_yr, window_wait_yr,
  encounters: [...],                            # CPA truth on final path
  assist: null | {body, r_p, delta, dv_helio},
  realism: hop_budget fields,
  path_class: "hohmann" | "lambert" | "patched_assist" | "quick_spiral"
}
```

### 7.2 Phase ladder (implementation)

#### Phase 0 — Document + contracts (this file) ✅ in docs

Freeze vocabulary: HCI vs game, Hohmann vs spiral, assist = patched, n-body = audit only.

#### Phase 1 — Hohmann path = flown path (single target, no assist)

1. Compute Hohmann \(a_t\), \(t_{\mathrm{coast}}\), \(\phi_{\mathrm{req}}\) in AU (`RealismBudget`).
2. If Rocket Science: optionally wait / label window (`next_window_wait_yr`); Quick Course may
   still depart off-window with an honest “not ideal alignment” line.
3. Build the **transfer ellipse** in HCI:
   - Focus at Sun; peri/apo at \(r_1,r_2\); true anomaly from \(0\to\pi\) (outer) or
     \(\pi\to 2\pi\) conventions for inward.
4. Map \(\mathbf{r}_{\mathrm{AU}}(t)\) → \(\mathbf{r}_{\mathrm{game}}(t)\) with the **same
   compression used for planets** (angle preserved, radius decompressed/compressed —
   `decompress_radius_au` already exists for SIM_VIEW).
5. Park spheres: start at origin standoff, end at dest standoff, tangent blend into parking
   circle (existing orbit-entry story).
6. **Playback timing:** keep kid burn/coast/brake *along arc length* OR map wall-time to
   true anomaly with Astrogator calendar wipe on the long coast — but **geometry** must be
   the Hohmann ellipse, not the spiral.
7. Update narration predicates to use ellipse `min_sun_dist` and true anomaly.
8. QA: Earth→Mars / Earth→Jupiter path radii match \(r(u)\) of Hohmann within tolerance;
   ledger \(\Delta v\) matches `RealismBudget`; no spiral-only asserts remain.

#### Phase 2 — Plot-time clearance (game honesty without playground collision)

Revisit §3.3 of flight-dynamics strategy **on the Hohmann (or Lambert) polyline**:

- CPA sweep in game units against compressed ephemerides  
- If conflict with a body: (a) refuse / retime window, or (b) small out-of-plane / lateral
  bump **re-baked into the chart**, or (c) promote to Phase 3 assist if body is Jupiter/Saturn  

Still no mid-flight bounce. Board draws the bump.

#### Phase 3 — Patched-conic assists

1. Detect candidate assist bodies on radial hops with favorable geometry.  
2. Solve for SOI entry state on a heliocentric arc with target \(v_\infty\) and \(r_p\).  
3. Apply turn \(\delta\); continue to destination.  
4. Stamp `assist` on route; enable slingshot VO **only** when stamped.  
5. Optional: compare to n-body audit trajectory offline.

#### Phase 4 — Lambert / off-window transfers

For Quick Course departures that are not at \(\phi_{\mathrm{req}}\), replace pure Hohmann with
a **Lambert** two-point boundary value problem (fixed \(t_0\), fixed \(t_f\), free \(\Delta v\)).
Hohmann remains the fuel-optimal reference on the ledger (“ideal window would cost X”).

#### Phase 5 — Finite burns / NEP (optional)

Chemical/NTP/Orion stay impulsive stubs. NEP = continuous low thrust (different ODE). Only if
product asks for spiral-cruise cargo mode.

---

## 8. Rendering — presentation of charted truth

Rendering is not a second physics engine. Both modes share the same timeline.

### 8.1 Shared sim

At playback time \(t = t_0 + u\cdot t_{\mathrm{arr}}\) (or burn-progress mapped \(u\)):

- Ship pose from `timeline.pos/fwd`  
- Body positions from ephemeris at \(t\) (or compressed equivalent)  
- Encounters from route stamp  

### 8.2 MARKERS mode

- Constant screen-size AR pins (tiered recognition)  
- Destination may grow late; mesh handoff only when apparent size policy says so  
- **Charted peers never mesh-loom** (reads as collision) — pins only (`STRATEGY_COURSE_IS_TRUTH`)

### 8.3 SIM_VIEW mode

- Bearing from sim direction  
- Angular size / brightness from **decompressed AU** + real radii (`apparent_radius_rad`,
  `apparent_brightness`)  
- Peers stay pure-AU sized; destination late local loom only  

### 8.4 Orbit cut

Hard cut to orbit cinematic; system clock → `orbit_time_scale`; chart complete.

### 8.5 Board

PlotBoard draws `path_game` and ghost destination at intercept. If Phase 2/3 alters the path,
the board must show the **final** curve before GO.

---

## 9. Mathematical objects checklist (for implementers)

| Symbol | Meaning | Source of truth |
|--------|---------|-----------------|
| \(\mu_\odot, \mu_p\) | Gravitational parameters | Constants / body table |
| \(a, e, i, \Omega, \omega, \nu\) | Classical elements | Phase 1+ Kepler path |
| \(a_t, \Delta v_1, \Delta v_2, t_{\mathrm{coast}}\) | Hohmann set | `RealismBudget` |
| \(\phi_{\mathrm{req}}, P_{\mathrm{syn}}\) | Window | `RealismBudget` |
| \(r_{\mathrm{SOI}}, v_\infty, \delta, r_p\) | Assist | Phase 3 |
| \(r_{\mathrm{game}}(a_{\mathrm{AU}})\) | Compression | `OrbitMath.compress_orbit_r` |
| \(s(t), T, a_{\mathrm{burn}}, v_{\max}\) | Kid burn along path | `OrbitMath` burn_* |
| \(L(T), f(T)=0\) | Intercept residual | `plot_route` (retarget to ellipse length) |
| encounters[] | CPA stamps | `course_encounters` |

---

## 10. Worked numbers (sanity anchors)

Already asserted in `RealismBudget.phase_a_checks` / STRATEGY_REAL_ROCKET_SCIENCE:

| Hop | Synodic | Coast (Hohmann order) | Notes |
|-----|---------|------------------------|-------|
| Earth→Mars | ~2.14 yr | ~0.7 yr (~9 mo) | Classroom Hohmann |
| Earth→Jupiter | ~1.09 yr | ~2.7 yr | Not a 12-year lock |
| Earth→Neptune | ~1.01 yr | multi-year coast | Calendar wipe in UI |

Earth→Saturn with Jupiter assist: **not** a Hohmann \(a_t = (1+9.58)/2\). It is a
**broken-plane / multi-arc** design; Δv ledger must show Earth depart + optional deep-space
maneuver + Saturn capture, with assist contributing \(\Delta\mathbf{v}\) not chemical burn.

---

## 11. Relationship to Free Flight (boundary)

| | Mission Flight | Free Flight |
|--|----------------|-------------|
| Solver | Chart package (§7) | None (pilot) |
| Worlds | Ephemeris points; no bounce | Hero meshes; collision → orbit |
| Jupiter | Encounter / assist on chart | Optional sky / seek target |
| Truth | Course is law | Player input is law |

Do not reintroduce playground collision into FlyScene to “make assists feel real.” Assists are
**path design**, not contact events.

---

## 12. Suggested first implementation slice (start here)

1. Add `OrbitMath.hohmann_transfer_path_au(origin, dest, t_depart) -> samples` using the same
   formulas as `RealismBudget.hohmann`, with true anomaly parameterization.  
2. Map samples through compression; replace `build_course` spiral in `plot_route` when
   `path_class=hohmann` (Rocket Science default; Quick Course may keep spiral until Phase 4).  
3. Keep burn-profile playback along the new arc length; keep Astrogator coast wipe.  
4. Extend QA: path \(r(\nu)\) matches Hohmann ellipse; Earth→Mars apoapsis ≈ 1.52 AU in
   decompressed space.  
5. Leave assists as stamped `null` until Phase 3; keep slingshot VO banned.

---

## 13. Sources (math & mission design)

- Vallado, *Fundamentals of Astrodynamics and Applications* — two-body, Hohmann, Lambert, patched conics  
- Prussing & Conway, *Orbital Mechanics* — transfers and flybys  
- [Hohmann transfer orbit – Wikipedia](https://en.wikipedia.org/wiki/Hohmann_transfer_orbit)  
- [Patched conic approximation – Wikipedia](https://en.wikipedia.org/wiki/Patched_conic_approximation)  
- [Sphere of influence – Wikipedia](https://en.wikipedia.org/wiki/Sphere_of_influence_(astrodynamics))  
- [Circular restricted three-body problem – Wikipedia](https://en.wikipedia.org/wiki/Circular_restricted_three-body_problem)  
- Existing project sources listed in `STRATEGY_REAL_ROCKET_SCIENCE.md` §7  

---

## 14. Doc map

| Doc | Role |
|-----|------|
| **This file** | Math + Mission Control scope |
| `STRATEGY_COURSE_IS_TRUTH.md` | Rendering invariant |
| `STRATEGY_REAL_ROCKET_SCIENCE.md` | Δv, Isp, windows product layer |
| `STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY.md` | Burn feel, encounters, belt (partially historical) |
| `STRATEGY_3D_FLYER.md` | Engine / scale / cockpit |
| Free Flight research / playground | Kid arcade — not Mission Control |
