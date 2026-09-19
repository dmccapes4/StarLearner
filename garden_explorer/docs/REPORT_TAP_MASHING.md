# Report: Tap mashing in Garden Explorer

*2026-08-05 · Garden Explorer APK 1.55 (mash accommodations implemented)*

Kids (including this playtester) mash the screen and expect **every tap to be heard**.
Solar System Explorer already bent controls toward that. Garden’s current tap → walk →
face → act path is much healthier than before, but several places still **drop**,
**freeze**, or **override** taps under mash. This report maps what happens today and
what we should change.

---

## Kid contract (target)

1. **Every world tap is acknowledged** (ripple always shows — already true).
2. **The latest intentional tap wins** — retarget bed / shed / ground / animal without
   waiting for the previous walk to finish.
3. **VO never traps the kid.** A mash during narration either cancels the line or
   queues the walk for when VO ends — never “tap died.”
4. **Arrive still means face + act.** Retargeting replaces the pending interact; it
   does not leave a zombie pending that never fires.
5. **Fullscreen media (harvest video, star clip, shed UI) is a different mode.**
   Mash there should dismiss / skip when safe, not invent garden walks under the panel.

---

## How a tap flows today

```
Camera / input → Events.world_tapped
  → World._on_world_tapped
      → ripple (always)
      → maybe Narrator.stop() if tap_cancellable
      → maybe close ActionPrompt
      → early return if ShedUI / BugGrid / PlantGrid / SeasonCard open
      → bed/shed → _queue_interact (always, even while walking)
      → else if pending interact + player.moving → IGNORE (return)
      → else bug / animal / coop / ground / fence → queue or navigate
  → _queue_interact sets _pending, emits player_path_requested
      (or deferred_path if Narrator.blocks_movement)
  → Player walks (holds still during VO; _held_goal if path requested mid-VO)
  → player_arrived → face → apply tool / open prompt
```

---

## Mash scenarios — what happens now

### A. Mash beds while walking (gardening) — mostly OK

Bed/shed taps are handled **before** the “ignore while moving” guard
(`World.gd` ~397–408). Retapping bed_2 while walking to bed_0 **replaces** `_pending`
and re-emits a new path. This is the good “latest bed wins” behavior.

**Risk:** rapid bed→bed→bed can restart walks every frame of contact. Feels responsive
but can thrash pathfinding and skip mid-walk VO that just started on arrive if she
taps away in the same instant the water applies.

### B. Mash ground / Buddy / bugs while walking to a bed — IGNORED

```gdscript
if _interact_pending_active() and player.moving:
    return  # distraction taps dropped
```

Ground spam, dog taps, and bug taps while walking to a bed/shed/animal/coop **do
nothing** (except the ripple). For a kid who meant “go there instead,” the tap feels
dead. For accidental mash on grass mid-walk, this is protective.

**Kid expectation mismatch:** she often mashes the *next* thing she sees, including
path/ground near the target bed. Those can miss `zone_at` bed detection and get
dropped as “distraction.”

### C. Mash during movement-locking VO — deferred or held, not always cancelable

| VO type | `lock_movement` | `tap_cancellable` | Mash during VO |
|---------|-----------------|-------------------|----------------|
| Shed tool pickup (“You picked up the watering can…”) | yes | **yes** | Tap stops VO; walk proceeds |
| “You watered the bed.” / plant / harvest lines | yes | **no** | Walk freezes; new bed/shed tap sets `deferred_path` or Player `_held_goal`; ground/dog taps may still be ignored if moving was false |
| Soft tips (`Speak.soft`) | no | no | Walk continues |

So after watering, a mash on the *next* bed while “You watered…” plays is deferred —
good — but mash on ground is confusing (player frozen, tap may clear nothing useful
until lock ends). Non-cancellable success VO is the main mash trap.

### D. Mash while ActionPrompt is open — cancels chip, then navigates

Tap elsewhere closes the prompt and cancels pending, then continues into zone logic.
Good for “I didn’t want that chip.” Mash on the *same* bed immediately after can
re-queue correctly.

### E. Mash while ShedUI / grids / season card open — world taps swallowed

`_on_world_tapped` returns early. Ripple still shows (feels listened-to) but nothing
garden-side happens. Shed has its own buttons; mashing empty shed chrome does nothing.

### F. Mash during MediaPanel / VideoPanel (harvest, stars) — tree paused

`get_tree().paused = true`. World input may not run depending on process modes.
Back button / ceremony `no_exit` on first harvest/seed blocks easy dismiss. Mash
here is the worst “game isn’t listening” feeling after a successful harvest.

### G. Mash same bed on arrive (double water)

Water applies once → thirst cleared → second tap while VO plays may deferred-walk
back to the same pane → soft “not thirsty” (guarded if lock still held). Feels like
a dead second tap or a confusing tip. Not a nav bug; a mash-on-success UX issue.

### H. Pane / arrive path under mash

Recent fixes help:

- Latest bed/shed retarget recalculates path-lip pane from **current** feet.
- Player no longer teleports via `nearest_walkable` on soft-block.
- `_tick_pending_walk` + repaths try to finish face→act if arrive is missed.

Still fragile under mash:

- Retarget mid-walk from a new position can flip N↔S lip every few taps.
- If mash lands just outside bed poly (path dirt), tap is ignored while moving
  (scenario B) even though she meant that bed.
- After 4 stall nudges, we force act from afar (`_on_player_arrived` soft path) —
  OK for “don’t abandon,” weird if she already meant a different bed that was
  ignored as distraction.

---

## Summary table

| Mash pattern | Heard? | Outcome today |
|--------------|--------|---------------|
| Bed → other bed while walking | Yes | Retarget (good) |
| Bed → ground/Buddy while walking | Ripple only | **Dropped** |
| Bed → bed during success VO | Deferred | Walks after VO (OK if she waits) |
| Bed → bed during shed pickup VO | Cancels VO | Immediate retarget (good) |
| Mash ActionPrompt away | Yes | Cancel + new navigate |
| Mash during shed/grid UI | Ripple only | **No garden action** |
| Mash during harvest video | Weak | Paused tree / hard to exit ceremony |
| Double-tap same thirsty bed | Partial | Water once; second tap tip/deferred |

---

## What “listen to every tap” should mean here

Not a FIFO queue of ten walks (that would feel broken). The right kid model is
**latest-wins with sticky intent**:

1. Every tap updates a single **intent** (`_pending` or a short-lived `_tap_intent`).
2. Bed/shed/coop/animal/bug/ground all replace intent — **no ignore-while-moving**
   for intentional targets (including ground navigate).
3. Optional: expand bed hit tests slightly while an interact is pending so near-miss
   path taps still count as that bed.
4. Success VO should be **tap-cancellable** (or non-locking like `Speak.soft`) so mash
   during “You watered…” immediately starts the next walk.
5. Fullscreen media: tap-to-skip / tap-to-close after a short arming delay (except
   maybe the first 0.5s so she doesn’t skip by accident).
6. Visual ack beyond ripple when a tap **replaces** intent (tiny “→” toward new goal
   or path preview) so she sees the game switched targets.

---

## Recommended accommodations (priority)

### P0 — Stop dropping taps she meant

1. **Remove or narrow the ignore-while-moving guard.**  
   Keep ignore only for *accidental* ultra-near Buddy bubble if needed; never ignore
   ground navigate or a second bed. Latest `_queue_interact` / path emit always wins.

2. **Make success / ceremony short lines tap-cancellable**  
   (`Speak.line(..., true)` for water/plant/uproot/harvest one-liners), matching shed
   tool pickup. Long educational clips stay in MediaPanel with explicit skip.

3. **Bed near-miss forgiveness** while pending or while tool held: if tap is within
   ~40px of a bed poly / center and not clearly another zone, treat as that bed.

### P1 — Latest-wins clarity

4. **Single intent record** with `seq` / timestamp; arrive handlers no-op if
   `pending.seq != current_intent.seq` so a late `player_arrived` from an old walk
   cannot water the wrong bed after retarget.

5. **Cancel-and-replace path** on every new intent (already mostly true for bed/shed);
   apply the same to animal/bug/coop/ground.

6. **Ripple + intent flash** when replacing a pending walk (audio click optional).

### P2 — Panels and mash

7. **MediaPanel / VideoPanel:** first tap after 0.4s skips VO slide / closes video
   (ceremony can require the back control but should still accept a world-sized skip
   hit zone). Don’t leave `no_exit` with no way out under mash.

8. **Shed open:** tap outside dim closes shed (already wired). That tap does **not**
   fall through as a world navigate — next tap is the garden action (documented).

### P3 — QA for mash

9. **Headless unit suite** — `game/tests/test_tap_mash.gd` (cancellable VO + near-miss + seq).

10. **Walk video mash set** — `./qa/run_mash_video_suite.sh` (`WALK_CLIP_SET=mash`):
    - `mash_bed_retarget` — ~8 taps/s alternating bed_0 / bed_1; final pending == last tap  
    - `mash_ground_while_bed_walk` — ground navigate replaces bed intent  
    - `mash_cancel_water_vo` — tap-cancellable success VO → retarget bed_0  
    - `mash_bed_near_miss` — path dirt → bed_1  
    - no teleport (`max_frame_step_px` ≤ 22)  
    - Vision: last bed / pending in `state.jsonl` must match last mash tap

---

## What we should *not* do

- Queue every tap as a sequential walk list (kid will hate the backlog).
- Soften pane rules under mash (path-lip facing stays; retarget from new feet is enough).
- Let mash skip *into* harvest ceremony discovery flags without playing media once —
  first harvest can stay special, but it must be dismissible.

---

## Concrete code touchpoints

| Area | File | Today | Change |
|------|------|-------|--------|
| Ignore while moving | `World._on_world_tapped` ~405–408, ~430–431 | Drops ground/animal/bug | Delete or only filter Buddy &lt; 16px |
| Retarget bed/shed | same ~397–404 | Already replaces pending | Keep; add intent seq |
| VO lock | `Speak.line` / ShedUI / `_do_water_bed` | Success lines lock, not cancellable | `tap_cancellable=true` on short lines |
| Deferred path | `_queue_interact` + `_process` | Good for bed during VO | Keep; ensure ground also defers |
| Player hold | `Player._held_goal` | Holds path during VO | Keep |
| Stall / force act | `_tick_pending_walk` | Force act after nudges | Gate on intent seq so old walks don’t act |
| Media skip | `MediaPanel` / `VideoPanel` | Paused, hard exit on ceremony | Tap-to-skip |

---

## Bottom line

Under mash today, **bed↔bed retargets work**, but **ground/Buddy/bug taps while walking
are silent**, **success VO freezes the avatar without being cancellable**, and
**fullscreen media** is the worst “not listening” surface. Accommodating her means
**latest-wins intent**, **cancellable short VO**, **no ignore-while-moving for real
targets**, and **skip-able media** — not a deeper queue and not more spaghetti
heuristics on panes.
