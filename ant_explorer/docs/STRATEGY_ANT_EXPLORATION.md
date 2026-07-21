# STRATEGY — Ant Exploration (How She Moves Through the World)

*Everything the player (your daughter, age 6) actually does with her thumb: move her ant, follow
glowing trails, become a worker for a while, and sit in the nursery watching babies grow. Controls
are designed for a six-year-old — **one finger, no menus, no reading required.** Depends on the
world in `STRATEGY_ANT_EXPLORER_SIMULATION.md`.*

---

## COLD OPEN — THE ONE-FINGER RULE

**McCLANE:** She's six. She can't read a tutorial, she won't find a pause menu, and she'll rage if
a control fights her.

**FEYNMAN:** Then give her *one verb* — **tap where you want to go** — and make everything else a
richer version of that same verb. Tap the ground: walk there. Tap a glowing trail: *become* that
worker. Tap a star: go watch the real ants do it. She never learns a second control; she just
discovers that the one she has does more than she thought. That's how you teach a kid a deep game —
one verb, deepening.

---

## 1. The camera

- **Overhead isometric, always.** Fixed slight-iso angle (matches the overview). Never rotates —
  rotation disorients young kids and invites "I'm lost."
- **Gently follows the player ant**, centered, with a soft lag so motion feels calm.
- **No manual camera control** in v1. (Optional later: two-finger pinch zoom, clamped. Not needed
  for launch.)
- **Edge-of-zone framing:** when she reaches a tunnel mouth, the camera eases toward the next
  chamber so travel feels continuous, not teleporty.

---

## 2. Core control: click / tap to move

- **Tap anywhere walkable** → her ant paths there (A* over the walkable mesh / tunnel graph) and
  walks at a calm speed. A soft **ripple + footstep dust** marks the tap so she gets instant
  feedback.
- **Tap in another chamber** → she auto-paths through the connecting tunnels (no need to tap each
  segment). Big, forgiving hit areas.
- **Tap an obstacle / wall** → the ant goes to the nearest reachable point instead of refusing
  (never a dead "can't do that").
- **Re-tap** while walking → redirects immediately. No queueing, no "are you sure."
- **No fail states, no fall damage, no getting stuck.** Worst case she wanders; the world is safe.

---

## 3. Pheromone trails — the second layer of the one verb

Trails are **glowing, animated paths** that NPC workers already follow. They are the game's
"become someone" mechanic.

### 3.1 One trail per colony role (except the Queen)
There is a distinct, **color-coded** pheromone trail for each working role. The Queen has **no**
trail (you can't "become the queen" — she's the one fixed, singular ant, which is also true to
biology and keeps her special):

| Trail color | Role | What she does when she joins it |
|---|---|---|
| 🟢 Green | **Forager** | Walk to surface, cut a leaf disc, haul it back to a garden |
| 🟡 Amber | **Gardener** | Take leaf bits to the fungus, tend/pat the garden |
| 🔵 Blue | **Nurse** | Carry food/eggs in the nursery, feed a larva, dose JH, move a larva |
| 🔴 Red | **Soldier** | March to the entrance, help push back an invader, patrol |
| ⚪ Grey | **Waste/undertaker** | Carry a bit of waste (or an old ant) to the dump |
| 🟣 Violet *(optional)* | **Deep-tunnel scout** | Wander the quiet tunnels, uncover a star |

Trails **pulse in the direction of travel** (so she can see which way the work flows) and are
brighter where activity is higher — the salience gradient, made literal and pretty.

### 3.2 Tapping a trail = entering the simulation as that role
This is the key interaction and exactly what you described:

1. She **taps a glowing trail** (anywhere along it).
2. Her ant **walks to that point** and **enters the simulation with that role, at that location.**
   Her sprite adopts the role's look cue (e.g. picks up a leaf, or a "carer" glow).
3. She then **watches her ant do the job** — it runs the role's FSM (forage loop, nurse loop,
   etc.), and she can either **let it run** (watch) or **tap to steer** where the next sub-action
   happens (e.g. tap which larva to feed, which leaf to cut).
4. **Leaving the role:** tap open ground away from the trail → she drops the role and is just
   "exploring" again. (Optional big friendly "done" leaf-button in a corner for extra clarity.)

**Design intent:** joining a trail should feel like *slipping into being that ant*, not opening a
job menu. The trail is the invitation; the tap is acceptance; the watching is the reward.

### 3.3 Readability guarantees (so a 6-year-old is never confused)
- Only **one role active at a time.** Her current role shows as a small icon by her ant.
- Trails are **always visible** (dim when idle, bright when workers are on them) so the world's
  "circulatory system" is legible at a glance.
- The **role she's on pulses stronger** than the rest, so she remembers what she is.

---

## 4. The nursery / larval space (the moment this whole project was born)

When she follows the **blue nurse trail** into the **brood chamber**, this is the payoff scene —
the ant documentary she watched with you, now something she *operates*:

- **A cluster of larvae**, sized **relative to the colony** (more adults ⇒ visibly more babies;
  see the sim doc's `target_larvae`). They're cute, plump, faintly glowing by feeding state.
- **Nurses actively incubate**, in three readable, repeating actions she can watch or trigger:
  1. **Feed nutrients** — bring food to a larva; the larva plumps a little.
  2. **Dose JH (juvenile hormone)** — a gentle grooming animation; the larva's glow shifts color
     toward its future caste (a quiet visual "it's becoming a soldier").
  3. **Move / re-tuck a larva** — pick up and reposition, like real incubation shuffling.
- **She can just WAIT and watch growth happen:** because sim time is accelerated, if she sits in
  the nursery she'll see, over ~30–90 seconds each:
  - a larva **fatten** as it's fed,
  - **spin into a pupa** (a still cocoon),
  - **eclose** into a brand-new adult that **walks off to its job**,
  - and the Queen's fresh **egg** get carried in to start the cycle again.
- **Optional agency:** she can tap a specific larva to have her (nurse) ant go feed *that* one —
  giving her the feeling of raising a favorite. No pressure, no failure if she doesn't.

This chamber is deliberately the calmest, most rewarding place to *linger*. Growth being **visible
in under two minutes** is the single most important tuning target in the game — verify it early.

---

## 5. Stars while exploring (hook to the documentaries)

Glowing **star nodes** sit at key spots (queen chamber, garden, foraging trail, etc.). Tapping a
star walks her ant there and plays a short real-ant video clip (full mechanics in
`STRATEGY_STAR_ANT_DOCUMENTARIES.md`). Stars she's seen get a soft "collected" sparkle; the gentle
goal is to see them all. Stars never block movement and can be re-watched forever.

---

## 6. Onboarding without words (she can't read yet)

- **First 20 seconds:** one obvious star near spawn gently pulses; tapping it plays a short, happy
  clip → she learns *tap = good things happen.*
- **Trails glow invitingly** near the start so the second discovery ("tap a trail → become a
  worker") happens naturally.
- **No text tutorial.** Icons and animation only. If any hint is needed, use a **pointing-paw /
  sparkle** cue, never a sentence.
- **Everything is re-explorable.** Nothing is missable; nothing is timed. The whole design says
  *wander, and good things happen.*

---

## 7. Accessibility / kid-proofing checklist

- Hit targets **≥ 1cm** on the 6.5" screen; generous tap tolerance.
- **No double-tap, no long-press, no drag** required in v1 (all optional at most).
- **No lose condition, no scary imagery** (death is "carried home by friends," invaders are gently
  "pushed back," no blood).
- **Landscape locked**, controls reachable for small hands (nothing critical in exact corners).
- **Instant, satisfying feedback** on every tap (sound + little animation) so she always knows the
  game heard her.

---

## 8. Input → behavior summary

| She taps… | Her ant… | Feels like |
|---|---|---|
| open ground / another chamber | walks/paths there | "go here" |
| a pheromone **trail** | enters the sim in that **role** at that spot, does the job | "become this worker" |
| a **larva** (while nursing) | goes and feeds/tends *that* larva | "take care of this baby" |
| a **star** | walks over, plays the real-ant clip | "show me the real ants" |
| ground away from a trail | drops the role, back to exploring | "I'm done, let's wander" |

One verb — *tap where you want to go* — deepening into *tap what you want to be, and what you want
to see.* That's the whole control scheme, and it's enough for years of a six-year-old's curiosity.
