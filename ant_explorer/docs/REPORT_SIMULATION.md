# REPORT — Ant Explorer Simulation

*Where the colony lives in code, how a tick advances, and what “larval space” means here.*

**Code root:** `star_learning/ant_explorer/game/`  
**Engine:** Godot 4 (GDScript)  
**Status:** Phase 2 logic largely implemented and covered by headless tests under `game/tests/`. Presentation (art, video stars, full pheromone UX) still catching up to the sim.

---

## 1. Where the simulation logic lives

| Concern | Path | Role |
|---------|------|------|
| **Orchestrator** | `scripts/sim/Colony.gd` | Agent pool, spawn, per-tick caste FSMs, player intents |
| **Larval space** | `scripts/sim/Brood.gd` | Eggs → larvae → pupae → eclosion + caste destiny |
| **Food economy** | `scripts/sim/Garden.gd` | Leaf deposits, tend, waste, health decay |
| **Colony pressure** | `scripts/sim/Homeostasis.gd` | Demand signals (food / care / defense / waste) |
| **Defense vignettes** | `scripts/sim/Invaders.gd` | Spawn → soldiers swarm → shake → flee (no deaths) |
| **Agent record** | `scripts/sim/AntState.gd` | Pooled fields: path, carry, nutrition, JH, etc. |
| **Enums** | `scripts/sim/AntEnums.gd` | Caste, Role, Carry, State |
| **Clock** | `scripts/sim/SimClock.gd` (autoload) | Fixed ~5 Hz ticks; frames only interpolate |
| **Tuning** | `data/config.tres` + `scripts/content/GameConfig.gd` | Caps, rates, thresholds |
| **Map / pathing** | `scripts/nav/NavGraph.gd`, `Pathing.gd`, `world/MapBuilder.gd` | Chambers + A* walk paths |
| **Wire-up** | `scripts/world/World.gd` | Builds map, spawns colony, connects taps → intents |
| **Views** | `scripts/sim/AntView.gd` | Sprites bound to `AntState` (render only) |

**Not sim logic:** kiosk launcher (`kiosk_placeholder/`), star video pipeline (`tools/build_stars.sh`), fleet update scripts. Those deliver the game; they do not step the colony.

**Tick path:**

```
SimClock (~5 Hz) ──sim_tick──▶ World._on_sim_tick
                                    └─▶ Colony.on_sim_tick
                                          ├─ Homeostasis.tick
                                          ├─ per-ant FSM step (by caste)
                                          ├─ Brood.tick (pupae + egg demand)
                                          ├─ Garden.tick_decay (every 5 ticks)
                                          └─ Invaders.tick
Frames ──▶ Colony.interpolate_views(SimClock.tick_alpha)
```

Logic advances only on sim ticks. Rendering lerps between `prev_cell` and `cell`.

---

## 2. What the simulation is (plain English)

You control one **player ant** in a leaf-cutter-style nest. The nest is a **graph of chambers** (nursery, gardens, queen, surface forage, dump, outpost, entrance, …) linked by walkable paths. Up to **100** agents live in a pre-allocated pool.

NPCs run simple job loops by caste:

| Caste | Loop (simplified) |
|-------|-------------------|
| **Forager** | Go to leaf spot → cut → haul leaf → deposit in garden |
| **Gardener** | Tend fungus / sometimes carry waste to dump |
| **Nurse** | Feed larva, dose JH, move larva, or carry egg from queen to nest |
| **Soldier** | Patrol outpost / entrance; respond when invaders appear |
| **Queen** | Signals egg-laying when brood is below target |
| **Larva / Pupa** | Stationary (or carried); grown by `Brood` |

**Player loop:** tap the world → walk there. Tap the **blue nurse trail** in the nursery → become a nurse. Tap a **larva** → path to it and feed (stronger nutrition/JH than NPC feeds). Leave the trail area → drop nurse role.

**Garden health** is the food battery: leaf deposits raise it; neglect/waste/decay lowers it. Feeding larvae is **scaled by garden health** (sick garden → weak feeds). Eggs only get laid when garden health is decent (≥ ~0.35) and brood is under target.

**Invaders** are theatrical, not lethal: a few enemies spawn, soldiers engage, everyone shakes, invaders flee. No colony deaths.

**Stars** (documentary markers) sit on the map; video playback is a later phase. They are content hooks, not sim agents.

---

## 3. Larval space — yes, it is included

In this project, **“larval space” means the nursery lifecycle engine**, not the separate Loam/control-plane metaphor in `reports/REPORT_LARVAL_AGENT_SUBSTRATE.md`.

It lives in **`scripts/sim/Brood.gd`** (file header: *“Larval-space engine”*) and is exercised by nurse FSMs in `Colony.gd` plus tests (`test_brood.gd`, `test_nurse_fsm.gd`, `test_lifecycle.gd`).

### Dynamics that exist today

1. **Target brood size** — roughly `brood_k × living_adults`, clamped to `brood_min`…`brood_max` (config: 15–25).
2. **Egg demand** — when under target (and garden OK), queen gets `LAY_EGG`; a nurse carries the egg and `spawn_larva` at a nest spot.
3. **Nutrition stages** — feeds raise `nutrition`; thresholds `[6, 12, 18]` advance `larva_stage` 0→1→2, then **pupate**.
4. **JH dosing** — nurses / player can add `jh_dose` (visual tint on the larva). Used in caste scoring.
5. **Caste destiny at pupation** — score = `nutrition + jh_dose × 2`:
   - high → **soldier**
   - mid → **forager**
   - low → **nurse**
6. **Pupa timer** — `pupa_ticks` (~30 ticks ≈ 6 s at 5 Hz), then **eclose** into the destined adult and walk toward a nest-edge job spot.
7. **Move larva** — nurses can pick up and reposition larvae inside the nest cluster.

### What larval space is *not* (yet)

- No deep “substrate metaphor” UI beyond nursery play.
- No true pheromone diffusion field — role trails are mostly **authored markers** (e.g. `NurseTrail.gd`); full trail chemistry is aspirational in the strategy docs.
- `Homeostasis` computes care/food/defense demand each tick, but caste pick-jobs are only lightly biased by it today (signals exist; not a full market of task reassignment).
- Documentary **stars** are placed; playback pipeline is separate from brood math.

So: **yes — larval space dynamics are in the running sim**, as brood nutrition / JH / pupation / eclosion. That is the intentional emotional core from `IMPLEMENTATION_PLAN_ANT_EXPLORER.md` Phase 1.

---

## 4. Numbers that matter (`config.tres`)

| Knob | Default | Meaning |
|------|---------|---------|
| `sim_hz` | 5 | Sim ticks per second |
| `agent_cap` | 100 | Hard pool size |
| `phase2_*` | 30 / 12 / 14 / 14 | Foragers / gardeners / nurses / soldiers at spawn |
| `brood_min` / `max` | 15 / 25 | Living larvae+pupae band |
| `larva_nutrition_stage` | 6, 12, 18 | Stage / pupate thresholds |
| `pupa_ticks` | 30 | Time as pupa |
| `caste_destiny_high` / `mid` | 22 / 19 | Soldier vs forager vs nurse cutoffs |
| `garden_health` | 0.75 | Starting fungus health |
| `egg_interval` | 50 | Ticks between egg opportunities |

---

## 5. Mental model (one diagram)

```
                 surface: foragers cut leaves
                           |
                           v haul
 dump <-- waste -- gardeners --> fungal garden (health)
                                      |
                                      v scales feed
 queen --egg--> nurses --> LARVAL SPACE (nursery)
                  feed / JH / move
                           |
                      pupa -> eclose
                           |
              soldier / forager / nurse adults

 invaders (entrance) <-> soldiers (theater only)
```

---

## 6. How to verify without the phone

From `star_learning/ant_explorer/game/`:

```bash
godot --headless --path . -s res://tests/run_tests.gd
```

Brood / nurse / garden / invader coverage is listed in `game/tests/README.md`.

---

## 7. Bottom line

- **Simulation logic** = Godot scripts under `game/scripts/sim/`, driven by `SimClock`, owned by `Colony`, configured by `data/config.tres`.
- **It is a closed colony loop:** forage → garden health → nurse care → brood → new workers, plus soft invader theater and player click-to-walk / nurse role.
- **Larval space is included** — implemented as `Brood.gd` (nutrition, JH, stages, pupation, caste destiny, eclosion), with nurses and the player as the caregivers.

*Generated for Star Learner / Ant Explorer — 2026-07-20.*
