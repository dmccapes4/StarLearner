# Code review: bed approach + watering (Garden Explorer)

*Date: 2026-08-04 · Updated: face-pane refactor · Audience: agents + Grok Vision QA*  
*Scope: tap bed → approach pane → walk → arrive → water/plant after shed watering-can pickup*

## Playtest symptoms (pre-fix)

1. After watering can from shed, first tap nearest bed: walk up, **no water**.
2. Second tap: water UX/SFX but VO **“isn’t thirsty”**.
3. NW / north-middle beds: long loop to the **north** face instead of path/south lip.

## Architecture decision (current)

**Keep it simple.** Do not accumulate half-plane filters, south-preference scores, or opposite-face arrive spaghetti.

### Bed approach model (`FarmMap.bed_approach_world`)

1. **Face panes** — Each bed is four objects `{face, stand, outward}` for N/E/S/W (`bed_face_panes`). Outward points away from the bed center.
2. **Direct travel (default)** — Pick the pane whose outward best aligns with `(player − center)`. That is the side the avatar already faces. Walk there via A\*.
3. **Only special case** — Player is standing at an **adjacent** bed that blocks the line to the target. Choose the **closest face** of that blocker, then use the **same face pane** on the target (go around on that side). Varieties: in-row neighbors and across-path pairs in the 2×3 layout.
4. **Pen → garden** — Face selection uses a virtual origin **just inside the gate** (garden side). `find_path` still concatenates pen → gate → garden → pane. Vector math then picks the path-facing pane naturally.
5. **Far-side tap** — If the kid clearly taps the opposite lip, honor that face; otherwise ignore center pokes.

### Arrive (`World._on_player_arrived`)

Arrive = near the **chosen approach stand** (or its `nearest_walkable`). Soft-collision abort only if still within ~100px of that pane. No path_ty / half-plane checks.

### Water VO

`Speak.soft("…not thirsty…")` is skipped while `Narrator.blocks_movement()` so success line is not stomped on double-tap (same guard as seed).

---

## End-to-end flow

```
TapRouter → Events.world_tapped
  → World._queue_interact("bed", id, tap)
       approach = FarmMap.bed_approach_world(id, player, tap)
         panes = bed_face_panes(id)
         if pen→garden: from = garden_just_inside_gate()
         if adjacent blocker: face = closest face of blocker
         else: face = best outward · (from − center)
       emit player_path_requested(approach)
  → Player → FarmMap.find_path (gate splice if needed)
  → World._on_player_arrived → near approach? → _apply_bed_tool
```

---

## Historical spaghetti (removed / do not reintroduce)

| Anti-pattern | Why it hurt |
|--------------|-------------|
| Empty filter → fallback **all faces** + shortest A\* | North lip won from shed/SW |
| Soft south score ±40 drowned by path length | Same |
| Arrive accept `center+40` / any rim | Wrong face self-validated |
| Soft “not thirsty” during success VO lock | Double-tap lie |
| Dual `nearest_walkable` + dual thirst VO | State confusion |

---

## Contracts for Grok Vision (water / approach clips)

1. **`approach_face`:** From shed / path / south beds → stand on the pane facing the avatar (usually path/south for north beds). Not a farm-scale loop to the far north lip.
2. **`detour_ratio`:** Bed approach &lt; ~2.2 crow; no east-then-south fence loop.
3. **`water_applied`:** tool=water + thirsty at arrive → thirst cleared; success VO.
4. **`no_false_not_thirsty`:** Soft tip must not replace success VO on double-tap.
5. **`arrived_means_tool`:** `nav.arrived` near chosen pane with water+thirsty → water applied.

---

## Files

| File | Role |
|------|------|
| `FarmMap.gd` | `bed_face_panes`, `bed_approach_world`, blocker/neighbor helpers, `find_path` |
| `World.gd` | `_queue_interact`, simple arrive, `_apply_bed_tool` / `_do_water_bed` VO guards |
| `Player.gd` | Path follow + narrator freeze |
| `GardenState.gd` | Thirst |
| `Narrator.gd` / `Speak.gd` | VO lock |
| `ShedUI.gd` | Watering-can tool |

## QA

```bash
./qa/run_bed_approach_suite.sh
WALK_CLIP_SET=water REVIEW=1 ./qa/run_walk_video_suite.sh
# or: ./qa/run_water_video_suite.sh
```

Stamp `mechanics/` includes this review + sources for Grok.

## Grok Vision (2026-08-04T19-23-55_water)

| Clip | Verdict |
|------|---------|
| `water_bed0_from_shed` | PASS — south lip, thirst cleared, short corridor |
| `water_bed1_from_south_path` | PASS — south lip, no north loop |
| `water_bed0_from_bed3` | PASS — west aisle / path, south lip |
| `water_bed3_from_shed` | PASS approach/water (north = path face for south-row); Buddy art flake unrelated |
| `water_double_tap_bed3` | Water OK; suite spawn was south of bed (fixed → `path_bed3`) |

Full write-up: `qa/out/walk_video/2026-08-04T19-23-55_water/REVIEW.md`
