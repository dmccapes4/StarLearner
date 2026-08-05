# REPORT — Remaining spaghetti competing with face-pane bed approach

*Date: 2026-08-05 · Garden Explorer · APK 1.50 baseline*  
*Authors: Composer audits ([bed approach](b2cbee7a-36e8-4f0a-b916-9e3eef126a31), [path/arrive](e5b6bdb8-2bd3-4b1d-a747-4bf0ac6fb19a)) + parent pass*  
*Playtest: avatar still often walks to the **other side** of the bed*

## Status (cleanup landed)

**Removed from production (2026-08-05):** S1 path-length face scoring, S2/S3 soft tap bias (far-lip only if `dot < -0.5`), S5/S6/S19 blocker + pen virtual-from, S7 emit double-snap, S10 rim arrive, S12 100px abort, shed candidate soup → `shed_door_pane` / `coop_door_pane`. Face pick = `_pick_facing_pane` (reject `outward·from_dir < 0`). Arrive = near pane + bed same-hemisphere. See `REVIEW_BED_APPROACH_AND_WATER.md`. Below remains the pre-cleanup audit trail.

## Intended model (must stay one sentence)

Each bed has four face panes with outward vectors. Pick the pane facing the avatar. Opposite direction ⇒ opposite face (hard reject unless the kid clearly taps that far lip). Only special case: adjacent blocking bed → go around its closest side, same face on the target. Arrive = near that pane only.

Anything that reintroduces “shortest A\* / soft score / wide arrive” as a face referee is spaghetti.

---

## Executive verdict

The face-pane API exists (`bed_face_panes` / `bed_approach_world`), but **`_best_direct_face` is not pure vector selection**. Path-length penalties, tap soft scores, blocker overrides, and multi-layer `nearest_walkable` snaps still compete. Arrive no longer uses half-planes, but **84px / 100px radii** can accept **side** faces.

Measured pane distances (`bed_1` geometry, all beds match):

| Pair | Distance |
|------|----------|
| S ↔ N | **110.5 px** (exact opposite N is *outside* the 100px soft abort) |
| S ↔ W | **54.4 px** (passes both 84px arrive and 100px abort — **worst case**) |
| S ↔ E | **107.5 px** |
| Stand ↔ center | **55.2 px** |

Headless probes (2026-08-05):

| Case | Pure `outward·from_dir` | Chosen face | Notes |
|------|-------------------------|-------------|--------|
| path → bed_0 | S | S | OK |
| path → bed_1 | **E** | **S** | Heuristic overrode vector |
| north of bed_1 → bed_2 | W | **N** | Blocker closest-face forced N |
| shed → bed_0 | S | S | OK in this probe |
| Composer grid sample | — | ≠ vector in **35/864** cells | S1 path scoring |

**S1 nuance ([path/arrive](e5b6bdb8-2bd3-4b1d-a747-4bf0ac6fb19a)):** when S≈+100 and N≈−100, path penalty needs **>571 px** excess length to flip — rare for same-bed walks. Path terms matter when alignment is **close** (iso S≈E), or when S5/S6 bypasses vector pick entirely. Post-return, wrong face is frozen in `_pending.approach` until retap.

**Primary fix direction:** score faces by vector only; hard-reject `outward · from_dir < 0` (opposite hemisphere) unless intentional far-lip tap; strip path-length from face pick; shrink arrive to the chosen pane; stop emitting a second `nearest_walkable` that can drift the goal.

---

## Competing conditions inventory

### Face selection (`FarmMap.gd`)

| ID | Severity | Location | What competes |
|----|----------|----------|---------------|
| **S1** | **blocker** | `_best_direct_face` ~560–565 | **A\* `path_world_length` penalty** `(plen−crow)*0.35` when `plen > crow*2.2`, plus `crow*0.02`. Reintroduces “shortest path picks face.” Far lip with short A\* can beat near lip with longer corridor. |
| **S2** | major | ~545–549 | **Opposite-lip tap** if `tap_clear` and `tap_dir·from_dir < -0.15` → honor tap face. Threshold loose for iso soil taps → accidental far side. |
| **S3** | major | ~545–559 | **Tap soft bias** `outward·tap_dir * 35` whenever `|tap−center|² ≥ 120` (~11px). Pulls face toward tap hemisphere vs player-facing pane. |
| **S4** | minor | ~528, 550, 572 | Default `best := "S"` on ties / init. |
| **S5** | **blocker** | ~431–437, 478–536 | **Adjacent-blocker** sets face = closest stand of *blocker*, same letter on target — **skips** `_best_direct_face`. North of bed_1 → bed_2 gets **N** (back) instead of path **S**. Between-test uses raw `to_b · to_t̂ ≥ 8.0` (px, not cosine). |
| **S6** | major | ~428–429, 469–476 | **Pen→garden** replaces `from` with gate garden-side point. Face aims from virtual origin, not avatar (can pick E/W vs path lip). |
| **S8** | major | `_stand_clear_of_bed` ~582–595 | Blocked ideal → push outward; fallback `nearest_walkable(..., 6)` can jump toward another face corner. |
| **S9** | minor | `bed_face_panes` ~458–466 | `outward` from nudged stand, not nominal tile cardinal — rotates normals. |
| **S18** | minor | ~541–542 | `from ≈ center` → force `from_dir = (0,1)` (south). |
| **S19** | major | `_adjacent_blocker_at` ~492–500 | `1.35×min_stand` ring + fuzzy between-test → false blocker / miss. |
| **S23** | minor | `_beds_are_neighbors` ~512–515 | Unknown IDs: neighbor if centers `< 220` → extra S5. |
| **S25** | major | `path_world_length` ~604–607 | Empty A\* returns `crow * 12` → huge S1 penalty → can wipe correct face. |

**Missing hard rule (root of “other side”):** there is **no** reject of faces with `outward · from_dir < 0`. Opposite hemisphere can still win via S1/S2/S3/S5.

### Goal drift after pane chosen

| ID | Severity | Location | What competes |
|----|----------|----------|---------------|
| **S7** | **blocker** | `World` ~532; `find_path` ~1620–1621; `Player` ~196–280 | **Triple `nearest_walkable`**: emit snap → path end snap → soft-collision snap. Goal can leave the pane. |
| **S15** | major | `Player` ~256–280, 294–305 | Soft-collision / fence / animal: skip waypoints or snap + **early `player_arrived`**. |
| **S16** | major | `Player` ~244–248 | End pose blocked → `nearest_walkable` (not face-aware). |
| **S20** | major (indirect) | `_nav_point_blocked`, path-strip carve | Shapes which faces have short A\* → feeds S1. |
| **S21** | minor | `find_path` gate splice | Long pen paths → more soft-collision early arrive. |
| **S24** | major (chain) | `shed_approach_world` | Apron snap skews next bed’s `from_dir`. |

### Arrive / apply (validates wrong stand)

| ID | Severity | Location | What competes |
|----|----------|----------|---------------|
| **S10** | major | `World._on_player_arrived` ~603–606 | Accept `nearest_walkable(approach)` rim as arrive. |
| **S11** | minor | ~608–612 | Up to 2 repaths to snapped approach (no face recompute). |
| **S12** | **blocker** | ~613–617 | Soft abort: bed tool if within **100px** of approach. **S↔W ≈ 54px** passes; exact **N (110px)** fails abort but mid S→N band (~77–88px) still passes **84px** close_enough. |
| **S13** | major | `Config` `interact_arrive_eps=42` → arrive **84px** | Wide disk; no opposite-hemisphere check. Dual vs Player `arrive_eps=14` (S31). |
| **S14** | minor | `World` ~524–526 | Already within 42px of approach → skip walk (stale wrong face). |

### Side channels

| ID | Severity | What |
|----|----------|------|
| **S17** | minor–major | Narrator freeze + deferred path; mid-walk VO can stall without re-emit (“walked up, no water”). Unlock re-emits snapped approach (does not re-run `bed_approach_world`). |
| **S22** | minor | `nearest_slot` stored but unused for approach. |
| **S26** | major | `walk_video_suite` taps **bed center** — never exercises S2/S3 lip paths. |
| **S27** | **blocker** (QA) | Suite `approach_face` is Y-only; **W/E become `"side"`** and PASS `expect_face=south`. Masks west-stand bugs. |
| **S28** | major | `bed_approach_suite` hard-codes world-Y “south” asserts, not pane letter / outward dot. |
| **S30** | major | Suite `_path_stand` / named offsets ≠ live Player `from_dir`. |
| **S31** | major | Player arrives at waypoint @14px; World accepts bed @84px — inconsistent “arrived.” |

**Post-return note:** `_pending.approach` is **not** mutated mid-walk. Drift and wrong-side acceptance are downstream of the stored stand (snaps, soft-collision, arrive radii), or a full retap that re-runs `bed_approach_world`.

---

## Why opposite side still happens (failure chains)

**Tightest production chain** (wrong *side lip*, not always true N):

```
1. bed_approach_world picks S → _pending.approach = S stand
2. nearest_walkable / find_path → walk cell on path or W aisle     [S7]
3. soft collision stops on W lip (~54px from S stand)              [S15]
4. player_arrived: dist ≈ 54 < 84 → close_enough                   [S13]
5. _apply_bed_tool(bed_id) — no face / outward check
6. face_toward(center) still looks “at the bed”
```

**Face-pick-wrong chain:**

```
tap bed
  → bed_approach_world
       from may be virtual (pen) or already nearest_walkable-skewed
       blocker? → closest blocker face (may be far lip)          [S5]
       else _best_direct_face:
            vector score
          + tap bias / opposite-tap override                      [S2,S3]
          + A* detour / crow terms when scores are close          [S1,S25]
       (no hard reject of outward·from_dir < 0)
  → emit nearest_walkable(approach) → soft-collision / arrive     [S7+]
```

**Iso note:** tile-space N/E/S/W map to diamond diagonals in world space. For a player due “south” in world-Y, **S and E can have nearly equal** `outward·from_dir` (probe: both ≈ 0.45). Crow/path terms then break the tie — another reason path heuristics must not own face pick. Opposite of S is still N (`align ≈ −0.45`); that hemisphere must be hard-rejected unless far-lip tap.

---

## Key code (current)

```gdscript
# FarmMap._best_direct_face — vector + competing heuristics
var score := outward.dot(from_dir) * 100.0
if tap_clear:
    score += outward.dot(tap_dir) * 35.0
var crow := from.distance_to(stand)
var plen := path_world_length(from, stand)
if crow > 1.0 and plen > crow * 2.2:
    score -= (plen - crow) * 0.35   # ← spaghetti return
score -= crow * 0.02
```

```gdscript
# World — double snap on emit
Events.player_path_requested.emit(farm_map.nearest_walkable(approach))
```

```gdscript
# World arrive — wide acceptance
eps := Config.get_interact_arrive_eps() * 2.0  # 84
# … rim nearest_walkable …
# soft abort bed @ 100px from approach
```

---

## Recommended cleanup (ordered)

1. **`_best_direct_face` = vectors only**  
   - Pick `argmax outward · from_dir`.  
   - **Hard reject** `outward · from_dir < 0` (opposite side) unless far-lip tap (tighten threshold, e.g. `dot < -0.5` and `|tap−center|` large).  
   - **Delete** path-length / crow terms from face scoring (S1, S25).  
   - Keep A\* only for *walking* after the pane is chosen.

2. **Blocker path (S5)**  
   - Closest *pass side* of blocker for routing waypoints only; target face should still be player-facing pane of target (or same *corridor* side: path lip), not blindly copy blocker’s closest face letter when that letter is the far meadow lip.

3. **Single goal**  
   - Store pane stand; emit that point; `find_path` may snap internally but `_pending.approach` remains the pane; Player must not early-arrive on a snap across the bed (reject snap if it crosses to opposite hemisphere).

4. **Arrive**  
   - Distance to `_pending.approach` only (drop rim fallback or keep ≤ ~24px).  
   - Soft abort ≤ ~40px of pane, and require `outward · (feet−center) > 0` for beds.  
   - Remove 100px opposite-face-capable ring.

5. **Pen→garden (S6)**  
   - Keep gate splice in `find_path`; prefer computing face from real player after gate, or constrain virtual-from to path-facing candidates only for garden beds.

6. **QA suites (S26–S28, S30)**  
   - Assert pane letter / `outward · from_dir ≥ 0`, not Y-only `"side"`.  
   - Exercise lip taps (S2/S3), not only bed-center taps.  
   - Align suite starts with live `nearest_walkable` behavior.

7. **Regression probe**  
   - Grid of `from` around each bed: `chosen_face == argmax outward·from_dir` except explicit far-lip taps; assert chosen face not opposite hemisphere.

---

## Files to touch

| File | Role |
|------|------|
| `game/scripts/world/FarmMap.gd` | S1–S6, S8–S9, S18–S20, S25 |
| `game/scripts/world/World.gd` | S7, S10–S14, S17 |
| `game/scripts/world/Player.gd` | S15–S16 |
| `game/scripts/autoload/Config.gd` | S13 / S31 eps |
| `docs/REVIEW_BED_APPROACH_AND_WATER.md` | Update once cleanup lands |
| `game/tools/walk_video_suite.gd` / `bed_approach_suite.gd` | S26–S28, S30 |

---

## Appendix — probe one-liner

```bash
cd garden_explorer/game && godot --headless --path . -s /tmp/face_probe.gd
# Compare align= vs chosen= ; OPPOSITE=true / align≠chosen = residual spaghetti
```
