# Bed / door approach — simple pane vectors

*Updated 2026-08-05 · Garden Explorer*

## Model

Small farm. Solids you cannot walk through: **beds, shed, coop, fence**. The **gate** is walkable both ways (`find_path` splices pen ↔ garden).

Everything you walk *to* for an interact is a **pane** with an outward vector:

| Target | Panes |
|--------|--------|
| Bed | N / E / S / W |
| Shed | One door pane (apron, outward from shed body) |
| Coop | One door pane (apron, outward from coop body) |
| Gate | Not a face pick — path goes through `gate_world` either way |

**Pick:** `argmax outward · (player − center)` among panes with `outward · from_dir ≥ 0`.  
Opposite direction ⇒ opposite side (rejected). Clear far-lip tap (`dot < -0.5` and far enough) may honor the far pane. **No** A\* length, tap soft scores, or adjacent-blocker face copy.

**Ties (iso only has diagonals):** standing straight below a bed in screen space scores
S and E *identically* (0.447 each), so the pick used to fall out of `Dictionary` key
order and walk the kid around to the side. Within `FACE_TIE_EPS` the nearer stand wins,
and faces are scanned in a fixed order (`S, W, E, N`).

**Walk:** `find_path` around solids only.  
**Arrive:** near `_pending.approach` (pane stand); beds also require same hemisphere as the pane.

## Tap → navigate → arrive → face → act

The pending interact is not abandoned mid-route:

- **Narration no longer cancels the walk.** `Player._process` holds position while
  `Narrator.blocks_movement()` and keeps `moving` + waypoints, so the route resumes
  when VO ends. A tap taken *during* VO is held in `Player._held_goal` instead of dropped.
- **`World._tick_pending_walk`** resumes the walk if it dies anyway (soft collision,
  dropped route): pending interact + player idle + farther than `interact_arrive_eps`
  ⇒ re-emit the pane stand (max 3 nudges, then drop the pending).
- Arrival always runs `_prepare_interact_pose()` (face the target) **before** applying
  the tool, so "avatar not facing the bed" cannot coexist with an applied action.

Regression this fixed: the avatar walked to the bed, stopped short un-facing, and the
water only landed on a second tap.

## Doors have a doorstep

`shed_door_pane` anchors at the **facade base** (`shed_door_base_world`), not the
44px-south door marker, and rejects stands that sit under a bed's *drawn* top
(`_point_in_bed_top` = footprint shifted by `BED_HEIGHT`). The shed solid pad was
shifted north (same world x) so it stops at the facade instead of swallowing 54px of
yard in front of the door — previously the only walkable ground at the door was under
`bed_3`'s raised soil, so the avatar appeared to stand in the bed.

Bed panes keep the plain outward push: with ~29px between rows, a north-face stand
always overlaps the next bed's raised top graphically, and feet stay outside the
footprint (depth suite rule).

## Water VO

Soft “not thirsty” skipped while `Narrator.blocks_movement()` so success VO is not stomped.

## History

Earlier layers of path-length face scoring, blocker overrides, triple `nearest_walkable`, and 84/100px arrive disks are documented in `REPORT_SPAGHETTI_NAVIGATION.md` (removed from production).
