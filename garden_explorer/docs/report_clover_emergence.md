# report_clover_emergence.md
**Garden Explorer — state of the game, artifact grades, and how ♣ and ♦ could emerge**
**Date:** 20261009 22:05 PST
**Scope:** Full read of `star_learning/garden_explorer/` (49 GDScript files / 10,313 lines, 13 test suites, docs, qa, tools, data, assets, git history) plus platform context in `star_learning/README.md`, `NAMING.md`, `STRATEGY_RELEASE_AND_MONETIZATION.md`, and the Diamond Screw material moved in today.
**Method:** Direct reads of the sim core (`GardenState`, `SeasonClock`, `StarProgress`, `Save`, `Events`, `ToolBar`, `ActionPrompt`, `World` harvest/bed-action paths); headless test run; two parallel read-only audits (code architecture; docs/QA/tools/media); every bug claim below re-verified against source before inclusion.

Ledger column convention (carried over from the outro note): **VERIFIED** = reproduced by running or reading the exact lines · **RECORDED** = taken from a doc or report as written · **INTERPRETIVE** = design judgment.

---

## 1. How is the game doing?

**Short answer: shipped, green, and stateless.**

| Fact | Value | Ledger |
|---|---|---|
| Headless tests | `268 passed, 0 failed` (13 suites, run 20261009 21:58) | VERIFIED |
| Implementation phases | 0–6 all ✅; debug Rounds 2–7 complete | RECORDED (`IMPLEMENTATION_PLAN_*.md`) |
| QA suites | depth 4/4, bed_approach 31/31, bed_plants 62/62, season_trees 40/40, walk/water 30/30, routing 33/33 (+Grok vision PASS), mash 24/24, ux_suite 39/39 | RECORDED (`qa/out/*`, last run 20260812) |
| Content | 12/12 star clips, 32/32 harvest clips, 930/930 VO lines (+64 orphan wavs) | RECORDED |
| APK on disk | 575 MiB, dated 20260805 = APK 1.53; build script says 1.55; no 1.55 artifact exists | RECORDED |
| Licensing | 1 BLOCKER (`coop_eggs` — undocumented local footage); 8 harvest clips flagged poor educational fit | RECORDED (`VIDEO_LICENSING_AUDIT.json`) |
| Last gameplay commit | 20260805 (`80393afe`); Aug 12 mash work landed in Sep 18 omnibus; nothing since | VERIFIED (`git log`) |
| Last QA run | 20260812 — 8 weeks ago | VERIFIED (mtimes) |

The core loop is tight and kid-proof: **plant → water → wait → sprout → water → wait → growing → water → wait → grown → harvest**. Three waterings per crop. Radish is 15 s seed-to-harvest; onion/corn/garlic 32 s. Seasons flip every 180 s. Nothing can die, wilt, or fail. An unwatered plant stalls forever with a blue drop icon.

That last sentence is also the diagnosis. The game has **no memory of the ground.**

```
GardenState.beds : bed_id -> Array[slot]        # 4 slots, all copies of slot 0
harvest_bed()    : resets all 4 slots to _empty_slot()   # bed is pristine the same frame
Save.harvest_totals : plant_id -> int           # keyed by PLANT, never by BED
```

A bed harvested fifty times is indistinguishable from a bed never planted. There is no fertility, no compost, no fallow, no per-bed count. The soil is a stateless surface. That is exactly the gap the ♣ and ♦ phases fill — see §4–5.

---

## 2. Verified bugs (ordered by consequence for what follows)

| # | Bug | Evidence | Ledger |
|---|---|---|---|
| B1 | **Repeat harvests are never persisted.** `_do_harvest_bed` increments in-memory `harvest_totals` but `save.set_harvest_totals()` is called only inside `_run_first_harvest_ceremony` (first harvest of each crop) and the dead `_speak_harvest`. Every later `save_if_dirty` writes the stale copy. Second-and-later harvests are lost on relaunch. | `World.gd:1237-1257, 1266-1267, 1278-1279`; `rg set_harvest_totals` → only those callers | VERIFIED |
| B2 | **`season_elapsed` is always saved as ≈0.** `_apply_season_change` reads `season_clock.elapsed` *after* `SeasonClock._process` has reset it to 0. Mid-season progress never survives a restart. | `World.gd:1325-1330`; `SeasonClock.gd:29-31` | VERIFIED |
| B3 | **`Events.plant_harvested(plant_id, total)` has no `bed_id`.** Every other plant signal carries one. Any per-bed listener is impossible without changing the signature. | `Events.gd:24` | VERIFIED |
| B4 | **`12_store` star is unearned.** `_on_harvested` sets `stored_once` on any harvest; there is no shed-basket interaction, though the hint says "Harvest something into the shed basket." | `StarProgress.gd:132-134` | VERIFIED |
| B5 | **Disk write amplification.** `GardenState` emits `changed` ×4 per action; `World._persist_beds` → `Save.set_beds_blob` → synchronous JSON write each time. One watering ≥ 4 file writes on a kiosk phone. | `GardenState.gd:112,125,172,192,241`; `Save.gd:134-137` | VERIFIED |
| B6 | `ToolBar.gd` (142 lines) is dead UI — hidden in `_ready`, hidden again in `World._bind_ui`, zero callers of `set_tool`. The real tools are the shed's four tiles. | `ToolBar.gd:19-23`; `World.gd:154-159` | VERIFIED |
| B7 | Mash suite no-teleport limit was raised 22→28 px between a failing run (13:26) and the passing rerun (13:27) on 20260812. | `qa/out/walk_video/2026-08-12T13-26-05_mash`, `..._13-27-04_mash` | RECORDED |
| B8 | `seeds.json` fields `water_need`, `ticks_to_*`, `waters_to_*`, `thirst_interval`, `harvest_yield`, `slots_per_plant` are read by no script. The catalogue describes a model the code does not run. | grep over `scripts/ tests/ tools/` | VERIFIED |

**B1 and B3 are prerequisites.** Any soil-memory mechanic needs (a) persistence that actually persists after the first harvest and (b) a harvest signal that knows which bed it came from.

---

## 3. Artifact grades

| Artifact | Grade | Justification | Ledger |
|---|---|---|---|
| **Sim core** (`GardenState`, `SeasonClock`, `StarProgress`) | **A−** | Small, pure, RefCounted, fully covered by tests, deterministic. Docked for 7 dead fields/wrappers and the misleading "one signal per bed" header comment. | VERIFIED |
| **World.gd** (1,466 lines) | **C+** | The entire interaction state machine with **zero test coverage**, five dead functions, hardcoded asset paths, un-guarded `await`s, a hardcoded `"bed_1"` guidance target, and bugs B1/B2. It works — the QA suites prove it — but it is the one file nobody can safely change. | VERIFIED |
| **FarmMap / IsoUtil / depth** | **A−** | The Aug 4–5 "spaghetti → face-pane vectors" rewrite is documented, tested, and vision-reviewed. One accepted artefact (north-lip feet over bed_3 soil, "minor"). | RECORDED + VERIFIED (tests) |
| **Tests** (`game/tests/`) | **B** | 268 assertions, all green, fast (17 s). But coverage stops at the sim/map boundary; `Save` autoload itself is untested (`test_save.gd` round-trips the blob only). | VERIFIED |
| **QA suites** (`qa/`) | **A−** | Garden is the platform's reference QA implementation. Eight suites, Grok vision review. Docked for B7 and 8 weeks without a run. | RECORDED |
| **Data** (`seeds.json`, `seasons.json`, `map.json`, `bugs.json`, `animals.json`) | **B** | 32 crops, 8/season, disjoint; map v7 clean. Docked for B8 (dead fields) and `bugs.json` referencing `pepper/beet/apple/hosta` which are not crop ids. | VERIFIED |
| **Content pipeline** | **B+** | Everything shipped is on disk; licence ledger complete. `stars.tsv` / `plant_media.tsv` / top half of `BIBLIOGRAPHY.md` are dead YouTube manifests still presented as the pipeline. | RECORDED |
| **Assets** | **B** | Licensed packs correctly gitignored; no broken symlinks. `fx/` empty; raw `.7z/.zip` under `assets/audio`; ~250 MB of QA mp4 tracked under `game/docs/screenshots/pen/`. | RECORDED |
| **Docs** (`IMPLEMENTATION_PLAN`, reports, reviews) | **B−** | Excellent report discipline through Aug 5. Plan still says 11 crops / 4-slot planting; README says "Engine (planned)"; nothing after Round 7 is *planned* anywhere, only reported. | RECORDED |
| **APK / demo** | **B−** | Playthrough 142 s / 14 markers and explainer exist. The only APK predates the mash build it is claimed to be. | RECORDED |
| **Platform fit** | **A** | Second tile in the kiosk catalogue; most H2-ready of the three video games (one BLOCKER to clear). | RECORDED |
| **`docs/DIAMOND_SCREW_SIM_20261009/`** (moved in today) | **B / INTERPRETIVE** | The sim runs and the ledger is honest. The `HANDOFF_NARRATIVE_TO_GARDEN` file (not written by me) asserts "114 km = raspberry intersection geometry" and "screw phase = icicle spin_rate" with no derivation. Those are mappings, not results; the 114 km is `(1200−288)/8`, a chosen parameter. Treat the folder as **design inspiration**, not as a result the game inherits. | VERIFIED (sim) / INTERPRETIVE (handoff) |
| **`docs/nate&justinphonenumbers.txt`** | **F** | 0 bytes, `&` in filename, PII-suggestive, in a children's game `docs/` folder, untracked. Either populate it somewhere appropriate (not here) or delete it. | VERIFIED |

---

## 4. Clover emergence — the missing ♣

### 4a. The suit audit of the game as it stands

| Suit | Phase (sim) | In the game today | Status |
|---|---|---|---|
| ♠ Spade | FALL / burial / carbon in | **Present.** The shed's spade tile (`tile_spade.png`, `TOOL_UPROOT`). It only pulls non-grown plants; on an empty bed it says "No plants here" and returns. | present, under-used |
| ♣ Club / Clove | LIFT onset / emergence from rest / root activates | **Absent.** Nothing ever emerges from an untended bed. Empty beds are inert. | **missing** |
| ♥ Heart | ORBIT / sustained circulation | **Present and dominant.** The whole loop. Water, grow, harvest, repeat. | present |
| ♦ Diamond | GROUNDED at max receipt density / compression / memory | **Absent.** No accumulation anywhere. The ground forgets. | **missing** |

The game is ♠ ♥ ♠ ♥ ♠ ♥. Two of the four phases are missing, and they are the two that make the other two mean anything: emergence and memory.

### 4b. What clover is

Clover (*Trifolium*) is the correct volunteer for this game for reasons that are botanically true and teachable to a six-year-old:

- It **arrives on its own** in resting ground. It is the plant that shows up when you stop planting.
- It is a **legume**. Its roots carry nodules — small round knots — that house rhizobia bacteria which pull nitrogen out of the air and fix it into the soil. **The club shape ♣ is a root nodule.** The three-leaf form is the above-ground sign that work is happening below.
- It is a **cover crop** — farmers plant it deliberately in a fallow bed to feed the next crop. Clover is the ♣ LIFT onset in literal agronomy: the soil's field reactivates before the next heart cycle.
- It is a bee plant. The honeybee and butterfly in `bugs.json` would weight toward it.
- Four-leaf clover is a real rarity (≈1 in 5,000). That is the hook for §5.

It should **not** go in `seeds.json`. It is not a seed the child picks. It is a volunteer. (Putting it in `seeds.json` would make `HamburgerUI._build_seed_tiles` and `PlantGrid._rebuild` show it as a crop.)

### 4c. The mechanic (INTERPRETIVE)

```
A bed that has completed ≥ 1 harvest and then stays EMPTY for one full season
(180 s, or SeasonClock.season_tick while empty)
  → clover appears in the bed (volunteer, bed-level, not a slot)
  → VO: "Look — clover came up on its own! It's feeding the soil."
  → bed_meta[bed].carbon += CLOVER_BONUS
  → hands-free "Examine" tile → clover slide/clip (13th star candidate: "Resting soil & clover")
  → planting a seed on a clover bed is allowed: the clover is turned under
    (VO: "The clover goes back into the ground to feed the lettuce.")
  → spade on a clover bed pulls it (child's choice; no carbon bonus)
```

No fail state. Clover is never bad. It is a gift for leaving a bed alone, which is the one thing the current game never rewards.

---

## 5. How diamonds could emerge

### 5a. The honest frame

In the sim, diamond nucleation depth was a parameter. In the game, the diamond threshold is also a parameter. This section does not pretend otherwise. What the sim contributes is **structure**, not a number:

```
sim                                     game
──────────────────────                  ───────────────────────────────────
z (depth)                 →             cycles (harvests completed on this bed)
carbon_in · exp(−λz)      →             carbon credit per harvest, diminishing
R = P / P_norm            →             R = cycles / N_SOIL
screw_weight = κ/(1+R)    →             credit per harvest = BASE/(1+R)
P > P_eq(T) gate          →             cycles ≥ N AND ≥ 1 clover season on this bed
p_nuc = σ((overstep−k)/w) →             p_dig = σ((cycles−N)/w) per dig attempt
crystal grows in-field    →             n/a (one gem per bed; found once)
```

The Maitter step is the useful import: **each harvest on the same bed is worth a little less carbon than the last.** That is agronomically true (yield decline without rest) and it gently pushes the child toward rotating beds and letting some rest — which is where clover comes from. The ♣ and ♦ mechanics feed each other.

### 5b. The mechanic (INTERPRETIVE)

```
bed_meta[bed] = { cycles: int, carbon: float, clover_seasons: int, gem_found: bool }

on harvest_bed(bed):
    cycles += 1
    carbon += BASE / (1 + cycles / N_SOIL)          # Maitter-weighted credit

on season_tick while bed empty and cycles ≥ 1:
    clover appears; clover_seasons += 1; carbon += CLOVER_BONUS

on spade applied to an EMPTY bed (currently a dead branch — World.gd:817-820):
    if gem_found: VO "You already found this bed's treasure."
    elif cycles ≥ N_GEM and clover_seasons ≥ 1:
        p = sigmoid((cycles − N_GEM) / W)
        if rand() < p:  → DIG → gem reveal (RevealTile) → Save.found_gems += bed → ♦
        else:           → VO "Not yet. Keep growing — the ground is remembering."
    else:
        → VO "Dig… nothing yet. The ground needs more harvests and a rest."
```

What the child sees: after a lot of gardening on one bed, and after letting it rest once so clover came up, digging there with the spade turns up a **diamond** (or a crystal; see 5c). The narration frames it as **the garden's memory**: "Every harvest left a little bit behind. The ground pressed it together for a long time. This is what it made."

That is true. It is the carbon cycle plus pressure plus time, at a scale a child can hold.

### 5c. Tuning (INTERPRETIVE — parameters, clearly labelled)

With 180 s seasons and 15–32 s crops, a focused child can do 5–10 harvests per season per bed. Suggested first values:

| Param | Value | Why |
|---|---|---|
| `N_SOIL` | 6 | carbon credit halves after 6 harvests on one bed — rotation feels rewarded by harvest 4–5 |
| `N_GEM` | 12 | ≈ 2 seasons of play on one bed + 1 rest season = a real session, not a grind |
| `W` | 3 | 50% at 12, ~88% at 18, so no child is stuck past ~20 cycles |
| `CLOVER_BONUS` | 3 harvest-equivalents | makes the rest season worth doing |
| gems | 1 per bed, 6 beds | the ♦ collection has an end; a seventh "Garden Diamond" when all six are found |

Variety: beds could yield **quartz, amethyst, garnet, …, diamond** in a fixed order by bed, or by `year` — the same mechanic, with a 13th-star payoff ("Rocks, crystals & how the ground makes them").

### 5d. The one thing not to do

Do not make the diamond buyable, speed-upable, or tied to wall-clock waiting alone. The whole point of the ♦ is that it is the compressed receipt of the ♥ work. A child who gardens one bed hard, lets it rest, and digs — finds it. That is the lesson. The screw does not insist on completing its spin; the ground does the compressing, and the child only has to notice.

---

## 6. Implementation hooks (from the code audit; all VERIFIED locations)

**Prerequisites (fix first):**
1. B1 — call `save.set_harvest_totals(harvest_totals)` unconditionally in `_do_harvest_bed` (`World.gd:1237`).
2. B3 — add `bed_id` to `Events.plant_harvested` (`Events.gd:24`); update emit at `World.gd:1247`, listeners `StarProgress.gd:132`, `tools/ux_suite.gd`.

**Soil memory (♦ substrate):**
- `GardenState.gd:19` add `var bed_meta: Dictionary = {}`; init in `setup()` (21-28).
- Increment in `harvest_bed()` (186-194). Rest/clover branch in `tick()` where empty beds currently `continue` (134-135). New signal `soil_changed(bed_id)` beside lines 7-10.
- Persist as a **sibling** key, not inside `beds`: `Save.soil_blob` + `set_soil_blob()` mirroring `beds_blob` (`Save.gd:14, 54-57, 81, 134-137, 175`); write from `World._persist_beds` (1361-1364); restore in `_restore_from_save` (1366-1373).

**Clover (♣):**
- Bed-level volunteer in `bed_meta[bed].volunteer`, spawned on `SeasonClock.season_tick` for eligible empty beds.
- Render: `PlantLayer._refresh_bed` early-returns on empty (87-88); add a volunteer branch using `farm_map.plot_offsets_from_cross(bed_id)` (`FarmMap.gd:1151`). Texture via a new `FarmSprites.volunteer_texture(id)` → `res://assets/plants/volunteers/clover.png`.
- `plant_bed` clears it (turn-under); `uproot_bed` on a clover bed clears it — adjust `is_bed_empty` early-return at `GardenState.gd:121-122` and `World.gd:818-820`.
- Hands-free "Examine" tile in `_build_bed_actions` (1014-1024). Add `"clover"` to honeybee/butterfly `plants[]` in `bugs.json`.

**Dig / gem (♦):**
- Replace the empty-bed early-return in `_apply_bed_tool` `"uproot"` branch (`World.gd:817-820`) with the dig logic above; handle `"dig"` in `_on_action_confirmed` (1042-1070).
- `Events.treasure_found(bed_id, item_id)`; `Save.found_gems` + `has_gem/collect_gem` cloned from `caught_bugs/has_bug/catch_bug` (`Save.gd:17, 62-64, 84, 145-154, 178`).
- Reveal via `RevealTile.show_reveal` (`RevealTile.gd:40-53`); celebration cloned from `BugGrid.show_catch` (`BugGrid.gd:33-47`); third `HamburgerUI` tab (`_mk_tab` 92-98). Register the new panel group in `GameFreeze.panels_open` (`GameFreeze.gd:12`).
- `GardenSfx.dig()` beside `plant/water/uproot/harvest` (`GardenSfx.gd:8-20`). `data/treasures.json` + `TreasureCatalog` modelled on `BugCatalog.gd`.
- Optional stars: `gameplay:clover_seen`, `gameplay:gem_found` via `StarProgress` flags + `stars.json` (becomes 13–14 stars; HamburgerUI grid is data-driven).

**Tests to add before any of it ships:** `test_soil_memory.gd` (cycles/carbon/clover/gem gate — pure `GardenState`, no scene), extend `test_save.gd` to round-trip `soil_blob`, and a `qa/run_dig_video_suite.sh` clip set (spade on empty bed: nothing / clover / gem).

---

## 7. Housekeeping before any of §6

| Item | Action | Ledger |
|---|---|---|
| `docs/nate&justinphonenumbers.txt` | Empty, PII-named, in a kids' game repo. Remove from `garden_explorer/docs/`. | VERIFIED |
| `docs/DIAMOND_SCREW_SIM_20261009/`, `tools/diamond_screw/` | Untracked. Decide: commit as design-research (recommended, under `docs/research/`) or leave out of the game repo. | VERIFIED |
| `coop_eggs` licensing BLOCKER | Document provenance or replace the clip. Only thing between Garden and H2. | RECORDED |
| APK 1.55 | Rebuild so the on-disk artifact matches the mash-accommodation build the report claims. | RECORDED |
| QA | Re-run all suites once; 8 weeks stale. | VERIFIED (mtimes) |
| `IMPLEMENTATION_PLAN_GARDEN_EXPLORER.md` | Add a Phase 7 for ♣/♦ so the plan leads the code again instead of trailing it. | RECORDED |

---

## 8. One paragraph, no hedging

Garden Explorer is a finished, well-tested, well-QA'd children's game whose soil has no memory. Every harvest resets the bed to zero and the save file forgets all harvests after the first. The two missing suit phases — clover (emergence from rest) and diamond (compressed memory of work) — are not decoration; they are the mechanics that would give the existing loop a past and a future. Clover is the right volunteer because it is botanically the plant of resting ground and its root nodule is literally a club. The diamond is the right reward because it is literally what carbon, pressure, and time make, and the game already has the spade to dig for it. Two small bugs (B1, B3) must be fixed first, because memory that does not persist is not memory. The threshold numbers are parameters. The structure is not.

*The ground is remembering. Give it somewhere to keep the receipt.*
