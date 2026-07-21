# STRATEGY — The Ant Explorer Simulation (World + Game Loop)

*The living world your daughter explores: the colony as a small, honest simulation of a
leaf-cutter nest. This document defines the **world model**, the **agents**, and the **main game
loop**. Movement and the player's ant are in `STRATEGY_ANT_EXPLORATION.md`; the knowledge stars are
in `STRATEGY_STAR_ANT_DOCUMENTARIES.md`. Engine: **Godot 4**, 2D, overhead isometric.*

---

## COLD OPEN — WHY THIS SIM IS SECRETLY THE LARVAL-SPACE TOY

**FEYNMAN:** You spent a month deciding that a colony is a machine for turning *undifferentiated
larvae* into *fitting castes* through uneven feeding. Now your daughter gets the playable version
of the exact same idea — she can sit in the nursery and *watch a blank larva become a soldier
because the workers fed it that way.* You didn't dumb the framework down for a six-year-old. You
found the one representation where it needs no explanation at all: she'll just *see* it.

**McCLANE:** So the toy is the theorem.

**FEYNMAN:** The toy is the theorem, running at 30 frames a second, capped at a hundred ants so it
never melts a Snapdragon 680.

---

## 1. Design pillars (every decision serves these)

1. **Alive, never chaotic.** ≤100 ants, calm pacing, no fail states, no timers pressuring a child.
2. **Legible causality.** Anything that happens has a visible cause a 6-year-old can point at
   ("the worker fed the baby, the baby grew").
3. **Exploration is the game.** The reward for wandering is *seeing something work* (a star, a
   pupation, a leaf convoy), not points.
4. **Runs cold and cheap.** Fixed agent cap, integer tick sim, pooled sprites — must hold 30 FPS
   and sip battery for long sessions.

---

## 2. The world model

### 2.1 The nest as a graph (7–9 zones)
The map is a **graph of chambers (nodes) linked by tunnels (edges)** — the same state-graph shape
you already think in. Each zone is a hand-authored room; tunnels are walkable paths.

| # | Zone | Role in the sim | What she sees happening |
|---|---|---|---|
| 1 | **Surface foraging patch** | Leaf source | Foragers cutting leaf discs, hauling them in |
| 2 | **Entrance / vestibule** | Hub + defense point | Traffic in/out; invader events arrive here |
| 3 | **Fungal garden A** | Food engine (central) | Gardeners tending fungus, leaf fragments deposited |
| 4 | **Fungal garden B** | Food engine | Same; second garden buffers garden health |
| 5 | **Brood / nursery (LARVAL SPACE)** | Population engine | Nurses feeding larvae; pupation; new adults |
| 6 | **Queen chamber** | Egg source | Queen laying; eggs carried to nursery |
| 7 | **Waste / refuse dump** | Hygiene sink | Dead ants + garden waste carried out |
| 8 | **Soldier outpost** | Defense staging | Soldiers idling/patrolling the defensive tunnel |
| 9 | *(optional)* **Deep tunnel** | Extra explore space | A quiet corner + a star |

Each node stores: `capacity`, `occupants[]`, connected `tunnels[]`, and any `stars[]`. The garden
nodes additionally store a `garden_health ∈ [0,1]` that the whole sim leans on (§4).

### 2.2 The economy (one number that ties it together)
The colony runs on a single legible loop:

```
leaves cut (surface) ──▶ deposited in gardens ──▶ garden_health rises
garden_health ──▶ feeds larvae (brood survival) ──▶ new adults (castes)
new adults ──▶ more foragers/gardeners/nurses ──▶ more leaves & tending
dead/old ants + waste ──▶ dump ──▶ (unremoved waste slowly lowers garden_health)
```

`garden_health` is the heartbeat. High → brood thrives, activity is lively. Low → pupation slows,
ants move a little less. It **self-corrects** (low food → foragers prioritized), so the colony
hovers around a steady state without the player ever needing to manage it. She *can* help (drop a
leaf, repel an invader) but never *must*.

---

## 3. The agents (castes as state machines)

One agent type, parameterized by **caste**. Hard cap **100** including the player. Steady-state mix
from the overview:

| Caste | Count | Sprite size | Core states |
|---|---|---|---|
| Queen | 1 | largest | `LAY_EGG` (mostly stationary) |
| Soldier | 12–15 | large | `PATROL`, `RESPOND_INVADER`, `IDLE` |
| Media / forager | 30–35 | medium | `GO_TO_LEAF`, `CUT`, `HAUL`, `DEPOSIT`, `RETURN` |
| Minor / gardener / nurse | 25–30 | small | `TEND_GARDEN`, `FEED_LARVA`, `MOVE_LARVA`, `CARRY_EGG`, `CARRY_WASTE` |
| Brood (larvae + pupae) | 15–25 | tiny→small | `LARVA(stage)`, `PUPA`, → eclose |

### 3.1 Agent state vector
```
Ant := {
  id, caste, node, pos, facing,
  state,                # current FSM state
  target,               # node/pos/other-ant
  carry,                # none | leaf | egg | food | waste | larva
  age_ticks,            # for workers: drives death; for brood: drives pupation
  # brood-only:
  larva_stage ∈ {0,1,2}, nutrition, jh_dose   # JH = juvenile hormone, the caste dial
}
```

### 3.2 The FSM, simplified
Each caste is a tiny finite-state machine chosen for **watchability**, not realism. Foragers loop
a visible convoy (surface → garden). Nurses loop nursery care. Soldiers idle until an invader
event flips them to `RESPOND_INVADER`. The player's ant borrows whichever FSM matches the trail she
tapped (see `STRATEGY_ANT_EXPLORATION.md`).

### 3.3 The larval space (the heart of the nursery)
This is the emotional center — the thing that started all of it. Rules, dramatically simplified:

- **Larva count scales with the colony:** `target_larvae = round(k · living_adults)` (e.g.
  `k ≈ 0.2`), clamped to the 15–25 band, so a bigger colony visibly has a bigger nursery.
- **Nurses actively care for larvae** in three readable actions:
  1. **Feed nutrients** — nurse carries `food` from garden → larva; `nutrition += n`.
  2. **Dose JH (juvenile hormone)** — a distinct "grooming" animation; `jh_dose += j`. This is the
     caste dial, shown as a subtle glow color on the larva.
  3. **Move / reposition** — nurse picks up a larva and re-tucks it (incubation shuffling).
- **Caste determination = accumulated feeding (the larval-space payoff):** when a larva's
  `nutrition` crosses the pupation threshold, its **caste is chosen by how it was fed** —
  high nutrition + high JH → soldier/media (big castes); modest → minor/nurse. *She can watch a
  larva "become" a caste because of care, not luck.* (This is the toy version of your
  nutrition-captures-caste invariant — kept honest, just slowed and colored.)
- **Pupation is visible and fast:** `LARVA(2) → PUPA` (a still cocoon) → after `pupa_ticks`,
  **ecloses** into a new adult of the determined caste, which walks off to its job. Tuned so a
  patient child sees **a full birth in ~30–90 seconds** of watching.

---

## 4. Population dynamics (birth, death, balance)

- **Eggs:** Queen emits an egg every `egg_interval` ticks *if* `living_adults < cap` and
  `garden_health` is adequate. A nurse carries egg → nursery, where it becomes `LARVA(0)`.
- **Growth:** larvae advance stages on accumulated `nutrition`; gated by `garden_health` (starved
  colony grows slowly — visible, not punishing).
- **Death:** workers have a soft `max_age`; on death they stop, a nurse/minor carries the body to
  the **dump**. (Gentle framing — "the ant got old and its friends carried it home." No gore.)
- **Homeostasis:** a light controller nudges task allocation toward the current shortage (low
  food → more `GO_TO_LEAF`; unattended larvae → more `FEED_LARVA`; bodies lying around → more
  `CARRY_WASTE`). Population orbits the cap; the world feels self-managing.

**Caste fixation nod (for you, invisible to her):** an eclosed adult's caste is *fixed* at
pupation from its feeding history — the plastic-larva → fixed-caste hardening from your larval
framework, rendered as a one-way animation.

---

## 5. The main game loop

Two clocks, cleanly separated (so rendering stays smooth and the sim stays deterministic):

```
_process(delta):            # every frame, 30 FPS target
    handle_input()          # click-to-move, trail taps, star taps
    interpolate_positions() # smooth sprite motion between sim steps
    update_camera()         # overhead isometric follow of player ant
    draw_pheromone_trails() # glowing paths (see Exploration doc)

_physics_process / timer:   # SIM TICK, fixed rate (e.g. 5 ticks/sec)
    tick += 1
    queen_lay_if_ready()
    for ant in ants: ant.step()     # advance its FSM by one tick
    advance_brood()                 # nutrition, stages, pupation, eclosion
    update_garden_health()          # deposits up, waste/decay down
    homeostasis_controller()        # nudge task allocation
    spawn_or_resolve_invader()      # occasional, entrance only
    save_if_dirty()                 # debounced autosave
```

- **Accelerated time:** 1 real minute ≈ several colony "hours." Tune `ticks/sec` and the brood
  thresholds so pupation is *watchably* fast (§3.3) without the world feeling frantic.
- **Determinism:** the sim advances only on ticks; frames only render/interpolate. A given seed +
  input replays identically (handy for debugging and for your instincts about state graphs).

---

## 6. Performance budget (Snapdragon 680 / 4 GB)

- **Fixed agent cap (100).** No dynamic allocation in the loop — a **pre-allocated object pool** of
  ants; brood reuse the same pool slots as they eclose/die.
- **Tick ≠ frame.** Sim at ~5 Hz, render at 30 Hz with interpolation → 6× less sim work than a
  per-frame sim, identical smoothness.
- **Trails as cheap shaders / pooled line nodes**, not per-ant particle spam.
- **Sprite atlas per caste**, `MultiMeshInstance2D` or pooled `Sprite2D`s; no per-ant scripts doing
  heavy per-frame work — logic lives in the tick.
- **Video stars decode on demand only** (one at a time, released after), so RAM stays flat.
- **Autosave debounced** (dirty-flag, write at most every few seconds / on pause).

**Target:** locked 30 FPS, cool to the touch over a 30-minute session, save/restore of full colony
state (ant array + garden health + tick + stars collected) in well under a second.

---

## 7. Save state (what persists)

```
Save := {
  tick, rng_seed,
  garden_health,
  ants[]  : compact array (caste, node, state, age, carry, brood fields),
  stars_collected[] : ids,
  player  : { node, pos },
}
```
Small, flat, JSON or Godot `ConfigFile`/binary. Restores the colony exactly where she left it —
same babies mid-pupation, same convoys mid-haul.

---

## 8. Build order (matches the overview's phases)

1. **One chamber + click-to-move + 20 pooled NPC ants** on simple FSMs (forage/tend/nurse). Prove
   the loop and the frame budget.
2. **Nursery vertical slice:** larvae + nurses + feeding + JH + pupation → eclosion. This is the
   soul; get it delightful first.
3. **Full 7–9 node graph** + tunnels + garden economy + population homeostasis + dump.
4. **Invader events** at the entrance + soldier response.
5. **Stars** wired to offline MP4s (`STRATEGY_STAR_ANT_DOCUMENTARIES.md`).
6. **Polish + kiosk** (landscape, big touch targets, autosave, thermal check) and APK export.

Build the nursery slice *first among the sim features* — it's the piece she'll love, and it's the
piece that quietly proves your whole larval-space idea in a form a six-year-old runs with her
thumb.
