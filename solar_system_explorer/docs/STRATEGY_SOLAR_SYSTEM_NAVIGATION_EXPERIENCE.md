# STRATEGY — Solar System Navigation Experience

Design + verification strategy for the trip loop: **pick a world → watch the course
plot → fly the course → arrive in orbit**. Companion to `STRATEGY_3D_FLYER.md`
(which covers the 3D engine plumbing); this document covers what the *player
experiences* during navigation and how we keep it honest.

---

## 1. The core promise: never lie to the kid

The single most important rule of this experience, learned the hard way:

> **Every spoken or written claim about the trip must be derived from the actual
> course geometry. If we can't prove a claim from the math, we don't say it.**

Earlier builds guessed at narration from heuristics ("hops longer than 2.5 AU go
around the Sun") and the narrator confidently described a Sun flyby on an
Earth → Jupiter trip that plainly flew *away* from the Sun. A wrong fact spoken
with authority is worse than silence — this is an educational toy.

### 1.1 What the narrator may claim, and its proof

| Claim | Proof source (`OrbitMath.trip_narration`) |
|---|---|
| "heading **away from** the Sun, out to X" | destination `orbit_r` > origin `orbit_r` |
| "heading **in toward** the Sun, to X" | destination `orbit_r` < origin `orbit_r` |
| "swings us **close to the Sun**" | sampled curve's `min_sun_dist` < 0.55 × the *inner* endpoint's orbit radius |
| "we'll **cross the orbit of** Mars" | Mars's `orbit_r` lies strictly between origin and destination radii — geometrically guaranteed for any radial hop |
| "X is moving, so we **aim ahead** of it" | always true: `solve_intercept` aims at the arrival-time position |

Notes on the phrasing choices:

- We say "cross **the orbit of** Mars", never "fly **past** Mars" — the planet
  itself is usually elsewhere on its orbit. Crossing the orbit ring is always
  true and is itself a nice orbital-mechanics lesson.
- "Close to the Sun" genuinely happens: when the destination sits on the far
  side of the system (e.g. an Earth → Neptune intercept whose aim point is
  across the origin), the bowed Bézier still dips inside the inner system.
  The claim is only made when the *measured* `min_sun_dist` proves it.
- There is deliberately **no** "around the Sun" phrasing anymore. Our courses
  are single Bézier arcs; they never orbit the Sun, so the phrase can never
  be honest.

### 1.2 The voice itself

Narration is a warm baked **ElevenLabs** voice (same Matilda narrator as Ant
Explorer), not live robo-TTS. Because trip and arrival lines are dynamic, the
pipeline enumerates *every sentence the game can ever speak* — all ordered
origin → destination pairs, all opener variants, all AU/mile figures — hashes
each normalized sentence (md5), and bakes one clip per sentence:

```
godot --headless --path game -s res://tools/dump_vo_lines.gd   # → data/solar_vo_manifest.json
./tools/gen_solar_vo.py                                        # → game/audio/vo/<md5>.wav
```

`Narrator.speak` splits a line into sentences, plays the matching clips back
to back (`NarratorVoice` queue), and falls back to OS TTS only for a sentence
with no clip. A unit test rebuilds every runtime line and fails if any
sentence lacks a baked clip, so the fallback should never fire in practice.

### 1.3 Silence beats filler

The in-flight "Look — that's Venus on our left!" callouts were removed: at
cruise speed the ship covers the claim's geometry faster than TTS can speak
it, so the words were often stale or wrong by the time they landed. If a
future callout system returns it must follow the same rule — pause the ship
first, then speak about a frozen scene (see §6, Future).

---

## 2. Trip anatomy (beats and what guarantees each one)

```
ScrollView pick → PlotBoard (chart → lead → preview → GO) → FlyScene cruise → orbit arrival
```

### Beat A — Plot (top-down board, `PlotBoard.gd` + `OrreryBodies.gd`)
- True top-down (`FLATTEN_PLOT = 1.0`), board auto-zooms so origin, destination,
  and the whole course bow fit (`_refit_board_scale`, floor 0.72×, budget
  `BOARD_FIT_PX = 246 px` half-width).
- Beat lengths scale with hop duration (`plot_beat_seconds`): a Mars hop charts
  in ~1.7 s, a Neptune hop takes ~5 s to draw so the intercept lesson reads.
- Narration speaks the `trip_narration` line — the same one validated in §1.

### Beat A′ — The Sun is a destination (with a caveat)

Tapping the Sun plots a course like any other world. The hop ends at
`sun_approach_standoff` (outside the glowing hero sphere) — never the star's
center. Plot and arrival narration are explicit about the physics:

- Plot: *"We're flying in toward the Sun… We can't land on a star — we'll park
  at a safe distance and look!"*
- Arrival: *"We've come as close as we safely can… Stars are far too hot to
  land on."*

Re-tapping the Sun once you're already parked there opens the documentary
(same as re-tapping any other world). Leaving the Sun uses `park_pos` so the
ship starts on the safe radial, not at the origin.

### Beat B — Departure (`OrbitMath.build_course` + `plot_route`)
- **The course no longer starts at the origin planet's center.** `plot_route`
  takes a `depart_standoff` (the origin's orbit-parking distance,
  `orbit_standoff(hero_r)`), and `build_course` trims the launch point that far
  along the line to the arrival, capped at 30 % of the hop span so short hops
  keep a real cruise.
- This is what fixed the "I backed out of a planet, then went forward" feel:
  previously the camera started inside the origin's rendered sphere, and the
  slow eased start showed its surface receding behind the canopy.

### Beat C — Cruise (`FlyScene.gd`)
- PathFollow3D on the Bézier with cubic ease-in/out; camera blends from
  path-forward to destination-stare over the back half
  (`look_blend_weight`).
- Space is deliberately **big and mostly empty** (§3): planets are small far
  away, so motion reads from the starfield/belt parallax and the console map,
  and the destination's late bloom is the reward.
- Console map (above the wheel) shows the full course, live ship dot, and
  destination — the "am I actually going where the narrator said?" instrument.

### Beat D — Arrival (`_try_enter_orbit_from_approach`)
- The ship peels into orbit when it reaches `orbit_standoff(hero_r)` =
  max(4.2 × hero radius, 9 u) — *before* the path dives into the planet — so
  there is no clip-through-then-correct.
- The parking spot is biased 85 % toward the **sunlit side** (`lerp_angle`
  toward the Sun direction), so arrival never opens on a black night
  hemisphere.
- Arrival narration states measured facts only: destination name, AU traveled,
  and the miles conversion (`format_travel_miles`).

---

## 3. Scale model: a larger space with smaller planets in the distance

Rendering both distance *and* planet size truthfully is impossible in one
scene (real planets would be sub-pixel). Our compromise, tuned in this pass:

- **Orbits**: `orbit_r = 12 + 340 · (a/39.5)^0.45` — compressed but wide.
  Neptune sits ~313 u out; the whole system spans ~650 u.
- **Planets stay small when far**: `focus_dist = 26` means a world only reaches
  half its hero size around 26 u away; during most of a cruise even Jupiter is
  a modest disc or a dot. `apparent_size` uses a 0.72-power ramp so growth
  accelerates dramatically in the last stretch (the "bloom").
- **Cruise speed 11 u/s** keeps hop durations in the same 12–40 s design band
  as the old smaller space (span grew ~36 %, speed grew ~37 %).
- **Sunlight has no falloff** (`omni_attenuation = 0`, energy 2.0). With real
  attenuation across 650 units, everything past Venus rendered nearly black.
  Zero falloff is physically wrong but perceptually right — and the honesty
  rule (§1) applies to *claims*, not lighting exposure.

Why this feels better than the old cramped model: less mid-flight occlusion,
a clearer "space is mostly empty" lesson, and a stronger arrival payoff since
the destination spends longer as a growing point of light.

All knobs live in `data/solar_flyer_config.tres` and can be overridden on
device without a rebuild via `/sdcard/AntPhone/solar_flyer.json`
(`tools/solar_flyer.json` is the push-ready copy).

---

## 4. Verification: screenshots + geometry checks per trip

Narration bugs are integration bugs — unit tests alone missed them. The
standing harness is:

```
DISPLAY=:1 godot --path game -s res://tools/capture_trips.gd
```

For each trip in its list (currently Earth→Jupiter, Earth→Mercury,
Earth→Neptune, Jupiter→Mars) it:

1. prints the narration line next to the **measured** geometry
   (`min_sun_dist`, endpoint radii, launch gap), and OK/FAIL-checks every
   claim against it (exit code 1 on any FAIL);
2. screenshots the plot board, seven cruise frames (u = 0…0.97), and the
   arrival orbit into `game/docs/screenshots/trips/`.

Reviewing a trip = read the printed checks, then eyeball the frames:
- `*_0_plot.png` — does the drawn course match the narration?
- `*_1_fly_u000/u003.png` — departure clear of the origin planet (no
  backing-out)?
- `*_1_fly_u040.png` — mid-cruise: distant worlds small, no occlusion?
- `*_2_orbit.png` — sunlit, readable planet with thin gold rim?

Headless unit tests (`game/tests/run_tests.gd`, 378 checks) additionally pin
the honesty contract: outward hops never claim a Sun flyby, any "close to the
Sun" line must be backed by `min_sun_dist`, launch points respect the
standoff, and `ScaleTune.evaluate` guards the duration band / bloom timing /
board fit for the shipped knobs.

`tools/probe_orbit_shots.gd` is the lighting probe used to pick the arrival
exposure (it measures average planet-pixel brightness across light setups).

---

## 5. Current shipped knobs (July 2026 tune)

| Knob | Value | Why |
|---|---|---|
| `distance_span` | 340 | larger space; Neptune ~313 u out |
| `compression_exp` | 0.45 | keeps inner planets distinguishable |
| `focus_dist` | 26 | planets stay small until genuinely close |
| `cruise_speed` | 11 | preserves 12–40 s hop band at the new scale |
| `mesh_in / mesh_out` | 60 / 170 | sphere LOD engages a bit earlier in the bigger space |
| `min_dot` | 0.55 | far worlds remain visible dots |
| sun light | energy 2.0, attenuation 0 | outer system readable; arrival never black |
| orbit standoff | max(4.2 × hero, 9) | no clipping; planet fills ~⅔ of frame |
| orbit parking | 85 % sun-biased | arrive over the day side |

---

## 6. Future work

- **Paused callouts**: stop the ship near a true close approach (measured
  distance threshold), gold-outline the world, speak, resume. Only honest
  because the scene is frozen while the claim is made.
- **Course shapes**: multi-arc or gravity-assist style routes would make
  "swings close to the Sun" hops more visually explicit on the console map.
- **Moons at arrival**: the orbit beat has room for a moon or two circling the
  destination while narration runs.
- **Speed ramp option**: a "hurry up" hold-to-fast-forward instead of the small
  BOOST nudge, for kids who replay hops often.
