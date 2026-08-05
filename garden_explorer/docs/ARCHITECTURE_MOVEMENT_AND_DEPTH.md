# Movement & depth architecture — Garden Explorer

*Status: conventions implemented via `scripts/render/IsoUtil.gd (BIAS_* / apply_depth)` (bias table + feet helpers).
Collision is largely working; this document remains the rationale for keeping the iso stack.*

---

## 1. Verdict (short)

**No full architectural rewrite is justified right now.** The game’s movement model is appropriate
for a kid kiosk title on a fixed landscape farm. What hurt us was not “fake 3D on 2D,” but
**ad-hoc depth biases and incomplete solids** on a few tall props.

A **targeted hardening** of conventions (one depth rule, one solid rule, one approach-point rule)
would buy most of the reliability of a redesign at a fraction of the cost. A **larger redesign**
only pays off if the farm grows (multi-level buildings, roofs you walk under, many overlapping
tall props, or free camera zoom that breaks the current sort).

---

## 2. What we actually have

Garden Explorer is a classic **2:1 dimetric (isometric) 2D** game:

| Concern | Current mechanism | Where it lives |
|--------|-------------------|----------------|
| Tile ↔ screen | `IsoUtil.tile_to_world` / `world_to_tile` | `scripts/render/IsoUtil.gd` |
| Walk routing | `AStar2D` on integer tile centers; 8-connected; pen gate special-case | `FarmMap._rebuild_nav`, `find_path` |
| Solids | Polygon footprints (`shed_poly`, `coop_poly`, beds, inset `walk_yard_poly`) | `FarmMap.is_blocked` |
| Mid-step collision | Soft block in `Player._process` + `crossing_allowed` for pen fence | `Player.gd`, `FarmMap.gd` |
| Draw order | Manual `z_index = depth_from_y(world_y) + bias` with `z_as_relative = false` | Player, props, fence pieces |
| Interact approach | Snap goals with `nearest_walkable` / dedicated door points | shed door, coop door, beds |

Nothing here is a physics simulation. The “3D” is **painter’s algorithm + footprints**: tall sprites
are flat billboards; we pretend they have volume by (1) blocking a diamond on the ground and
(2) sorting draw order by a Y-like depth.

That is the same family of tricks Stardew / Sprout Lands–style games use. It is not a bug in the
genre choice; it is the genre.

---

## 3. Where the pain really came from

Playtest issues clustered in a few patterns:

1. **Missing solids** — The coop had art and a tap target but no footprint, so A\* sometimes
   routed “through” the sprite. Collision felt broken; routing was obeying an incomplete map.
2. **Depth bias escalation** — Props got `+120` / `+150` so they would sit above fence posts.
   The player stays at `+50`. Once a building’s bias dwarfs the player’s, the gardener is painted
   *under* the building even when standing in front of it. That reads as “walking through” even
   when nav is correct.
3. **Sort point ≠ visual feet** — Sorting a tall coop from its roof/tile center while the stilts
   and ramp sit further “south” on screen makes behind/front flicker around the base.
4. **Nav grain** — A\* samples tile *centers*. Thin gaps between centers and a solid diamond let
   paths slip until we added sub-samples for shed/coop.
5. **Perimeter vs meadow** — Visual fence on the yard diamond vs walkable area needed an **inset**
   walk polygon so the far side of the rails is not playable.

None of these require abandoning isometric 2D. They require **consistent contracts**.

---

## 4. Would a redesign help?

### 4.1 Options that look attractive

| Approach | What it buys | Cost / risk for this project |
|----------|--------------|------------------------------|
| **Godot `YSort` / `y_sort_enabled` on a single world layer** | Engine sorts siblings by Y; fewer hand biases | Still need a consistent “feet” origin on every sprite; tall buildings still need occlusion tricks or split sprites |
| **CharacterBody2D + StaticBody2D collision shapes** | Continuous collision; less soft mid-step logic | Does not replace A\* for tap-to-walk; dual systems (physics + nav) to keep in sync; kid taps want pathfinding, not shoving into walls |
| **Nav mesh / NavigationServer2D** | Smoother paths, non-grid obstacles | Heavier authoring; overkill for a small fixed farm; pen gate logic still custom |
| **True 3D or 2.5D** | Real occlusion and collision | Wrong cost class for Star Learner Game #4; art pipeline and kiosk perf change |
| **Layered sprites (base + roof)** | Player can walk “behind” base and under roof layer correctly | Art + placement work per building; good *if* we add many tall walkable props |

### 4.2 Recommendation

**Keep the current stack** (iso math + A\* grid + polygon solids + manual depth), and treat these as
hard rules:

1. **One depth function** — `z = depth_from_y(feet_y) + role_bias` with a small fixed table  
   (ground ≪ rails ≪ posts ≈ buildings ≪ player-in-front ≈ animals ≪ UI).  
   Never “win” an overlap by adding +100 to one prop.
2. **Feet define sort** — Building sprites sort from **ground contact** (south of footprint), not
   from visual center or roof.
3. **Art implies solid** — Every tall prop that should block gets a `*_poly` (or shared helper)
   before it ships; interact goals use a **door/apron** point outside that poly.
4. **Nav matches solids** — Rebuild A\* from `is_blocked` + small samples around tall solids;
   inset the walk yard from the perimeter fence.
5. **Player bias stays in the same band as buildings** — so front/behind flips with a few pixels of
   Y, not half a farm.

Optional **small upgrades** (worth doing if we keep polishing):

- ~~Extract `DepthSort` / `SolidFootprint` helpers~~ → done in `IsoUtil` (`BIAS_*`, `apply_depth`, `solid_diamond`).
- Split coop (or shed) into **base + roof** sprites only if we still see feet/head sorting fights.
- Enable `y_sort_enabled` on a dedicated `WorldSort` node *after* feet origins are consistent —
  as a migration, not a big-bang rewrite.

**Defer** physics bodies, nav meshes, and 3D unless the farm scope expands sharply.

---

## 4b. Seasonal weather + meadow trees

- **Ground decals** (fall leaves, spring flowers) live on `FarmMap/SeasonDecor` at a low absolute
  z so they sit under props.
- **Falling weather** (winter rain, fall leaf drift) is world-space `FarmMap/SeasonWeather`
  (`Node2D`). Landings are a precomputed yard/bed-top loop — rain splashes, leaves rest 1–2s.
  Depth: `BIAS_WEATHER_FALL` in air, `BIAS_WEATHER_LAND` on ground (above `BIAS_SEED`, under
  `BIAS_PLANT`). FX atlases: `tools/gen_weather_fx.py`.
- **Near-side fence** uses `BIAS_RAIL`/`BIAS_POST` plus a south-side sort-Y boost so bed decks
  cannot paint over rails/posts.
- **Meadow trees** sit outside `farm_yard_poly`, depth-sorted with `BIAS_TREE`, and swap atlas rows
  per season (`game/assets/trees/seasonal_trees.png`, regen via `tools/gen_seasonal_trees.py`).
  Horizontal canopy / side branches (Sprout Lands large-tree silhouette).

---

## 5. When to reconsider a redesign

Reopen this decision if any of the following become true:

- Multiple buildings you must walk *under* or onto (decks, bridges, multi-story).
- Camera zoom/pan that makes hand-tuned biases fail across the map.
- Dozens of tall props with overlapping footprints (crowded market, forest).
- Movement bugs return faster than we can patch footprints/biases.

Until then, the faux-3D isometric approach is not a liability — it is the product look — and
movement should stay **simple, explicit, and convention-driven**.

---

## 6. Related code (quick map)

- `game/scripts/render/IsoUtil.gd` — tile/world/depth primitives  
- `game/scripts/world/FarmMap.gd` — solids, nav, fence, shed/coop footprints, walk yard inset, seasons  
- `game/scripts/world/SeasonWeather.gd` — screen-space rain / falling leaves overlay  
- `game/scripts/world/Player.gd` — tap-to-walk along A\* waypoints, soft collision  
- `game/scripts/world/World.gd` — tap → interact goals (shed/coop approach points)  
- `game/data/map.json` — layout (beds, path, pen, coop tile)
- `game/assets/trees/` — seasonal meadow tree atlas + particle textures

---

## 7. Bottom line for kids / kiosk

The child cares that taps feel fair: walk around the shed, stand at the coop door, stay inside the
fence, appear in front of a building when standing in front of it. That is solvable with the
current architecture plus discipline. A redesign would mostly rearrange the same problems unless
the content goals change.
