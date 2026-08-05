# STRATEGY — Real Rocket Science (uber-realistic Mission Flight discovery)

*Discovery brief for a future “uber-realistic” layer on Solar System Explorer Mission Flight:
honest Δv, propellant mass, propulsion classes (chemical → nuclear thermal → nuclear electric →
nuclear pulse), and planetary windows — without turning a six-year-old’s session into a
multi-year loading bar. Companion to [`STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY.md`](STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY.md)
(today’s kid-paced burn→coast→brake) and [`STRATEGY_3D_FLYER.md`](STRATEGY_3D_FLYER.md).*

**Status:** Phase A + Phase B implemented. Phase C not started.  
- Phase A: `RealismBudget.gd` + `./tools/run_realism_budget.sh`  
- Phase B: `AstrogatorPanel.gd` on PlotBoard (Kid pace ↔ Astrogator, Chemical / NTP / Nuclear pulse, fuel bar + window/coast ledger); FlyScene calendar coast wipe; QA `./qa/run_astrogator_suite.sh`  
**Audience:** agents + Dylan; kid copy comes later from these numbers.

---

## 0. Verdict (read this first)

1. **Single-planet launch windows are ~1 year for outer planets**, not 10+ years. Decade-scale waits belong to **multi-planet gravity-assist Grand Tours**, not Earth→Jupiter Hohmanns.
2. **True chemical Hohmann wall-clock** (Mars ~9 months, Jupiter ~2.7 years) is educational as a *museum mode*, unplayable as default Free-time play.
3. **Uber-realism should mean fidelity of tradeoffs** (Δv ledger, Isp, rocket-equation mass fraction, synodic windows) — **not** fidelity of calendar duration.
4. **Best playable “future tech” flagship:** Orion-class **nuclear pulse** (high thrust *and* high Isp). Mid-tier: **NTP (~900 s)**. Slow/cargo: **NEP / sails**. Lore: fusion / antimatter / laser sails.

---

## 1. The rocket equation (fuel economy core)

Every chemical, nuclear-thermal, and nuclear-pulse ship in this brief obeys the
[Tsiolkovsky rocket equation](https://en.wikipedia.org/wiki/Tsiolkovsky_rocket_equation):

\[
\Delta v = I_{sp}\, g_0\, \ln\!\left(\frac{m_0}{m_f}\right)
\quad\Rightarrow\quad
\text{propellant fraction} = 1 - e^{-\Delta v / (I_{sp} g_0)}
\]

with \(g_0 = 9.80665\,\mathrm{m/s^2}\). **Higher Isp → less propellant for the same Δv.**
That single fact is the kid-readable spine of uber-realism: “better engines carry more ship, less fuel.”

Worked examples (departure inject Δv from LEO-class numbers in the Hohmann table below):

| Maneuver (approx.) | Isp | Propellant mass fraction |
|--------------------|-----|--------------------------|
| LEO→Mars inject **3.6 km/s**, chemical **450 s** | 450 s | **~56%** |
| Same, NTP **900 s** | 900 s | **~34%** |
| Same, Orion **4,000 s** | 4,000 s | **~9%** |
| LEO→Jupiter inject **6.3 km/s**, chemical **450 s** | 450 s | **~76%** |
| Same, NTP **900 s** | 900 s | **~51%** |
| Same, Orion **4,000 s** | 4,000 s | **~15%** |

*Derived from the rocket equation + published Isp/Δv bands cited in §2–3. Capture burns, plane changes, and gravity losses add more Δv in a full ledger.*

**Game UI sketch:** before commit, show a fuel bar split *ship / propellant* that grows ugly on chemical Jupiter and shrinks on nuclear pulse — narration: “Most of this rocket is fuel.”

---

## 2. Propulsion classes

### 2.1 Chemical (today’s baseline realism)

- Vacuum LOX/LH₂ class Isp roughly **~440–465 s** (e.g. RL10-family engines).
  Sources: [L3Harris RL10](https://www.l3harris.com/all-capabilities/rl10-engine); class discussion via [Hohmann / Δv literature](https://en.wikipedia.org/wiki/Hohmann_transfer_orbit).
- High thrust → short burns; poor economy at outer-planet Δv (table above).

### 2.2 Nuclear thermal (NTP / NERVA)

- Heats hydrogen with a reactor; Isp about **~850–1,000 s**, NASA modern target often cited **≥900 s** — roughly **2×** best chemical.
  Sources: [Nuclear thermal rocket (overview)](https://en.wikipedia.org/wiki/Nuclear_thermal_rocket); [National Academies — Space Nuclear Propulsion (2021), NTP chapter](https://www.nationalacademies.org/read/25977/chapter/4); [NERVA program history](https://en.wikipedia.org/wiki/NERVA); [DOE: Nuclear thermal propulsion overview](https://www.energy.gov/ne/articles/6-things-you-should-know-about-nuclear-thermal-propulsion).
- High thrust (chemical-like) + better Isp → studied crewed Mars transit on the order of **~3–4 months** vs chemical **~6–9 months** ([nuclear thermal rocket overview](https://en.wikipedia.org/wiki/Nuclear_thermal_rocket)).
- Ground-tested historically; **never flown**. Natural mid-tier “NASA roadmap” unlock.

### 2.3 Nuclear electric (NEP) / VASIMR / ion

- Very high Isp (ion/Hall thousands of seconds; VASIMR concepts often quoted around **~3,000–5,000 s** at high power) but **tiny thrust** unless reactor power is huge (crewed-Mars NEP studies talk **≥1 MWe** class).
  Sources: [National Academies NEP chapter](https://www.nationalacademies.org/read/25977/chapter/5); [VASIMR](https://en.wikipedia.org/wiki/Variable_Specific_Impulse_Magnetoplasma_Rocket); [IAA nuclear space power/propulsion study PDF](https://iaaspace.org/wp-content/uploads/iaa/Studies/nuclearpropulsion.pdf).
- Kid-game role: **cargo / robot / spiral cruise** — continuous gentle push, not a cinematic burn.

### 2.4 Nuclear pulse (Project Orion) — “nuclear impulse”

This is the cutting-edge *high-thrust + high-Isp* outlier kids can still feel as “fast.”

| Parameter | Indicative value | Source |
|-----------|------------------|--------|
| Classic design Isp | **~2,000 s** (original); Air Force concepts **~4,000–6,000 s** | [Project Orion (nuclear propulsion)](https://en.wikipedia.org/wiki/Project_Orion_(nuclear_propulsion)) |
| Exhaust velocity (interplanetary studies) | **~19–31 km/s** class | Same |
| Thrust | **Meganewton** class (pulse units) | Same |
| Example mission study | Mars surface round trip **~125 days**, large payload fractions discussed historically | Same |
| Status | Studied late 1950s–60s; ended mid-1960s; blocked in practice by nuclear test treaties / politics | Same; [Nuclear pulse propulsion](https://en.wikipedia.org/wiki/Nuclear_pulse_propulsion) |
| Related (Medusa) | Isp concepts **~50,000–100,000 s** | [Nuclear pulse propulsion](https://en.wikipedia.org/wiki/Nuclear_pulse_propulsion) |

**Kid-game read:** unlockable *future* ship that still spends propellant (pulse units) and still obeys Δv — but can cross the system without chemical despair. Keep treaty/history as museum VO, not playable nukes-in-atmosphere.

NASA-adjacent pulse discussion also appears in historical NTRS surveys (e.g. Schmidt et al. on nuclear pulse concepts — [NTRS 20000096503](https://ntrs.nasa.gov/api/citations/20000096503/downloads/20000096503.pdf)).

### 2.5 Other cutting-edge (lore / late unlocks)

| Concept | Notes | Source |
|---------|-------|--------|
| Solar sails | No onboard propellant; tiny continuous thrust (~μN/m² class at 1 AU) | [Solar sail](https://en.wikipedia.org/wiki/Solar_sail) |
| Laser / beamed sails (Starshot) | Interstellar gram-sails; not a solar-system hauler | [Breakthrough Starshot](https://breakthroughinitiatives.org/initiative/3) |
| Fusion pulse (Daedalus) | Exhaust thousands of km/s; interstellar study ship | [Project Daedalus](https://en.wikipedia.org/wiki/Project_Daedalus) |
| Antimatter | Extreme Isp concepts; production/storage fantasy for now | [Antimatter rocket](https://en.wikipedia.org/wiki/Antimatter_rocket) |

---

## 3. Transfers, Δv, and waiting for alignment

### 3.1 Hohmann numbers (circular coplanar ideal)

From the [Hohmann transfer orbit](https://en.wikipedia.org/wiki/Hohmann_transfer_orbit) reference table (departure inject):

| Destination | Δv from LEO (km/s) | Δv from Earth heliocentric (km/s) | One-way coast (order) |
|-------------|--------------------|-----------------------------------|------------------------|
| Mars | **~3.59** | **~2.93** | **~9 months** |
| Jupiter | **~6.30** | **~8.79** | **~2.7 years** |
| Saturn | **~7.29** | **~10.3** | longer |
| Neptune | **~8.25** | **~11.7** | multi-year |

Earth→Jupiter Hohmann duration derivation: half-period of \(a \approx 3.1\) AU ellipse → **~2.73 years**
([Astronomy Stack Exchange worked example](https://astronomy.stackexchange.com/questions/33747/hohmann-transfer-orbit-earth-jupiter-system)).

Mars windows and ~9-month coasts are standard classroom figures ([NASA GSFC Stargaze — Flight to Mars](https://pwg.gsfc.nasa.gov/stargaze/Smars3.htm); [Hohmann wiki](https://en.wikipedia.org/wiki/Hohmann_transfer_orbit)).

### 3.2 Synodic periods — when can you leave?

| Pair | Synodic period (window cadence) | Source |
|------|----------------------------------|--------|
| Earth–Mars | **~26 months (~2.1 yr)** | [Hohmann wiki](https://en.wikipedia.org/wiki/Hohmann_transfer_orbit); synodic tables e.g. [1728.org](https://www.1728.org/synodicb.htm) |
| Earth–Jupiter | **~399 days (~1.09 yr)** | [1728.org](https://www.1728.org/synodicb.htm) |
| Earth–Neptune | **~367 days (~1.01 yr)** | Same |
| Outer planets generally | Synodic period → **~1 year** | [cseligman synodic periods](https://cseligman.com/text/sky/synodicperiods.htm) |

### 3.3 Where do 10+ year waits actually come from?

**Not** from “wait for Jupiter.” They come from **rare multi-planet geometries**:

- Jupiter gravity-assist opportunities toward Uranus/Neptune can sit on **~10–14 year** cadences in historical mission studies.
- Full **Earth–Jupiter–Saturn–Uranus–Neptune Grand Tour** alignments are on the order of **~175 years** (Voyager-era; discussed e.g. on [Space Stack Exchange — Grand Tour interval](https://space.stackexchange.com/questions/48393/why-is-the-gas-giant-grand-tour-interval-175-years-when-the-synodic-period-of-ur)).

**Design rule:** single-target Mission Flight uses **~1-year** (outer) or **~26-month** (Mars) windows. Reserve decade+/century events for an optional **Grand Tour** card — never as the gate to “visit Saturn.”

---

## 4. Comparison table (for product + QA)

| Propulsion | Isp (s) | Thrust | Fuel economy | Kid / Mission Flight role |
|------------|---------|--------|--------------|---------------------------|
| Chemical LOX/LH₂ | ~450 | High | Poor at outer Δv | Default *museum realism*; teaches windows + “mostly fuel” |
| NTP / NERVA | ~850–1,000 | High | ~2× chemical | Mid-tier unlock; shorter Mars |
| NEP / ion / VASIMR | ~2e3–5e3 | Very low | Excellent if powered | Cargo / spiral mode |
| Orion nuclear pulse | ~2e3–6e3 | Very high | Excellent | **Playable uber-tech flagship** |
| Solar sail | ∞ propellant | Tiny | N/A | Patience / science mode |
| Fusion / antimatter / Starshot | Extreme | Concept | Extreme | Lore / endgame museum |

---

## 5. What to build (phased)

### Phase A — Discovery math (no new kid UI yet) ✅

- `game/scripts/RealismBudget.gd` — Hohmann Δv, LEO inject + capture stubs, rocket-equation fractions, synodic + next-window wait.
- Headless probe: `./tools/run_realism_budget.sh` → `qa/out/realism_budget/<stamp>/report.json`
- Asserts Mars window ~2.1 yr and Jupiter ~1.1 yr (±tolerance) — **fails if someone codes a 12-year Jupiter lock by mistake.**
- Also covered by `game/tests/run_tests.gd` → `_test_realism_budget()`.

### Phase B — Pre-chart Rocket Science choosers ✅

- After destination pick: **CourseModeChooser** tiles — Quick Course vs Rocket Science (narrated).
- Rocket Science → **PropulsionChooser** tiles — Chemical · Nuclear thermal · Nuclear pulse (narrated) *before* PlotBoard charts.
- PlotBoard shows a read-only fuel/window ledger (Astrogator); Quick Course hides it.
- FlyScene: Astrogator coast calendar wipe; route stamps `pace_mode`, `propulsion_id`, `realism`.
- Marker LOD: flyby handoff capped (`FLYBY_HANDOFF_MAX_X`) so Earth→Saturn peers stay AR pins.
- QA: `./qa/run_astrogator_suite.sh` + marker LOD Saturn-cruise peer pins.

### Phase C — Uber-realistic default for older modes

- Only if playtests ask for it. Free Flight stays phone-tilt fantasy; Mission Flight gains the ledger.

### Explicit non-goals

- Do **not** simulate fallout, pulse-unit politics, or atmospheric nuclear launch as gameplay.
- Do **not** make Neptune require a 175-year wait.
- Do **not** replace today’s honest *geometry* narration with fake “warp” — time compression must still match the charted path.

---

## 6. Relationship to the current flyer

Today’s Mission Flight already teaches **accelerate → coast → flip-and-brake** and intercept geometry
([`STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY.md`](STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY.md)). That remains the
six-year-old default.

This STRATEGY adds the *next* honesty layer: **why** engines matter, **how much** of the ship is fuel,
and **when** the planets will let you go — with nuclear pulse as the exciting, still-physical answer to
“but I don’t want to wait three years to reach Jupiter.”

---

## 7. Sources

- [Tsiolkovsky rocket equation – Wikipedia](https://en.wikipedia.org/wiki/Tsiolkovsky_rocket_equation)
- [Hohmann transfer orbit – Wikipedia](https://en.wikipedia.org/wiki/Hohmann_transfer_orbit)
- [NASA GSFC Stargaze — Flight to Mars / Hohmann](https://pwg.gsfc.nasa.gov/stargaze/Smars3.htm)
- [Astronomy SE — Earth–Jupiter Hohmann duration](https://astronomy.stackexchange.com/questions/33747/hohmann-transfer-orbit-earth-jupiter-system)
- [Synodic periods – cseligman.com](https://cseligman.com/text/sky/synodicperiods.htm)
- [Synodic period examples – 1728.org](https://www.1728.org/synodicb.htm)
- [Space SE — Grand Tour ~175 years](https://space.stackexchange.com/questions/48393/why-is-the-gas-giant-grand-tour-interval-175-years-when-the-synodic-period-of-ur)
- [Project Orion (nuclear propulsion) – Wikipedia](https://en.wikipedia.org/wiki/Project_Orion_(nuclear_propulsion))
- [Nuclear pulse propulsion – Wikipedia](https://en.wikipedia.org/wiki/Nuclear_pulse_propulsion)
- [NASA NTRS — Nuclear Pulse Propulsion: Orion and Beyond (Schmidt et al.)](https://ntrs.nasa.gov/api/citations/20000096503/downloads/20000096503.pdf)
- [NERVA – Wikipedia](https://en.wikipedia.org/wiki/NERVA)
- [Nuclear thermal rocket – Wikipedia](https://en.wikipedia.org/wiki/Nuclear_thermal_rocket)
- [DOE — 6 Things You Should Know About Nuclear Thermal Propulsion](https://www.energy.gov/ne/articles/6-things-you-should-know-about-nuclear-thermal-propulsion)
- [National Academies — Space Nuclear Propulsion for Human Mars Exploration (2021), NTP](https://www.nationalacademies.org/read/25977/chapter/4)
- [National Academies — NEP chapter](https://www.nationalacademies.org/read/25977/chapter/5)
- [VASIMR – Wikipedia](https://en.wikipedia.org/wiki/Variable_Specific_Impulse_Magnetoplasma_Rocket)
- [IAA — Nuclear Space Power and Propulsion (PDF)](https://iaaspace.org/wp-content/uploads/iaa/Studies/nuclearpropulsion.pdf)
- [L3Harris RL10 Engine](https://www.l3harris.com/all-capabilities/rl10-engine)
- [Solar sail – Wikipedia](https://en.wikipedia.org/wiki/Solar_sail)
- [Breakthrough Starshot](https://breakthroughinitiatives.org/initiative/3)
- [Project Daedalus – Wikipedia](https://en.wikipedia.org/wiki/Project_Daedalus)
- [Antimatter rocket – Wikipedia](https://en.wikipedia.org/wiki/Antimatter_rocket)
- Internal: [`STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY.md`](STRATEGY_FLIGHT_DYNAMICS_AND_PROXIMITY.md), [`STRATEGY_3D_FLYER.md`](STRATEGY_3D_FLYER.md)
