# STRATEGY — Sprite Package Upgrade & 32-Crop Seasonal Catalog

> Decision doc for replacing Sprout Lands crop art with the Seliel (Mana Seed) Farming Crops
> packs and expanding the catalog from 11 → 32 crops, 8 per season.

- **Date:** 2026-07-25
- **Budget:** ~$20 (Farming Crops #1 $8.99 + Farming Crops #2 $8.99 ≈ $17.98)
- **Links:** [Farming Crops #1](https://seliel-the-shaper.itch.io/farming-crops) ·
  [Farming Crops #2](https://seliel-the-shaper.itch.io/farming-crops-2)

---

## 1. Is isometric a requirement? **No.**

Two different things get drawn, and only one of them is isometric:

1. **The map** (beds, shed, fence, roofs) is *code-drawn* isometric polygons in
   `FarmMap.gd` — no sprite pack involved. It stays exactly as it is.
2. **The crops** are upright "billboard" sprites parented at `slot_plant_world()`
   (`PlantLayer.gd`, 5× scale, y-sorted z-index). They already come from a
   *top-down* pack (Sprout Lands) and read fine standing on the iso beds —
   the same trick Stardew-likes use everywhere.

What iso crop art would add: nothing visible at our camera angle and sprite
size. What it costs: the only decent iso crop pack found (Penusbmic STRANDED)
has **fewer crops (15), fewer stages (4), and a darker sci-fi style** that
clashes with the cozy kid aesthetic.

**Conclusion:** buy for *stage clarity + variety + charm*, not perspective.
Seliel wins on every axis that matters.

---

## 2. Why the Seliel packs

| Criterion | Seliel #1 + #2 | Notes |
|---|---|---|
| Crop count | **16 + 16 = 32** | Exactly matches the 8×4 season plan |
| Stage granularity | **Seed-on-ground + 5 growth stages** | Best "seed → sprout → grown" storytelling of any pack reviewed |
| Distinctive mature plants | Yes — every crop has a unique ripe silhouette | Key for a 6-year-old naming plants |
| Seed art | Labeled **seed bag** + loose **seeds on ground** per crop | Perfect for shed UI + freshly-planted slot |
| Extras | Harvest inventory icons, signposts, **dead/dry crops**, tilled/watered soil, giant veggies | Dead-crop sprites map onto our thirst/stall mechanic |
| Format | 16×16 base (mature often 16×32), per-crop sheets since update 3.1 | Same cell size we already atlas |
| License | Mana Seed User License — commercial use OK, no redistribution of raw assets | Fine for a private family APK; **don't commit raw sheets to any public repo** |
| Quality signals | 4.8★ (17 ratings), 100% human-made, actively updated since 2020 | |

Runner-ups (documented for the record): Frenchpixelle 26 Farm Crops (great dry
variants, fewer stages), Pixel Gnome (cleanest naming, only 12 crops),
BLEEDx (16×5 stages, $1, but tiny and less distinctive), Penusbmic STRANDED
(the iso option — rejected above), JaggaJatt 25+ (7 stages but mixed fruit
trees, weaker readability).

### ⚠ Verify on purchase — **DONE 2026-07-25**

Packs extracted to `game/assets/tiles/mana_seed_crops/` (gitignored).
Per-crop sheets are **160×32** (10 × 16×32 cells). Catalog reconciled to **32 real
sheet names** (e.g. `peasgreen`, `cornyellow`, `bellpeppergreen`). See `seeds.json` v3.

---

## 3. What changes in the game

### 3.1 Current state (for contrast)

- 11 crops in `game/data/seeds.json` v2, mapped to **rows of one Sprout Lands
  atlas** via `FarmSprites.PLANT_ROWS` (5 stage columns × 15 rows).
- Seasons already exist (`seasons.json`: spring/summer/fall/winter, 180 s
  cycle, per-season `seed_ids`) and already *only* gate the shed inventory —
  the exact mechanic requested. Current lists **overlap** (tomato is in both
  spring and summer); v3 makes them **disjoint**: 8 unique seeds per season,
  so each season change reveals a genuinely new shelf.
- Growth sim (waters + time + thirst) and per-crop media/VO pipelines are new
  as of this week and are catalog-driven — they scale to 32 with data, not code.

### 3.2 Stage mapping (Seliel 6 → sim 4 + dry)

| Sim state | Seliel sprite |
|---|---|
| `seed` (just planted) | Seeds-on-ground |
| `sprout` | Growth stage 1 (or 2 for tall crops) |
| `growing` | Growth stage 3 |
| `grown` | Growth stage 5 (ripe, with crop) |
| *(stalled/dry — optional polish)* | Universal dead-crop sprite, tinted |
| Shed icon | Labeled seed bag |
| Harvest icon above plot / basket UI | Ripe inventory icon |

Multi-harvest crops (stage 4 = picked, stage 5 = with fruit) enable a later
"re-picking" mechanic for free — out of scope now, noted for the backlog.

---

## 4. The 32-crop seasonal catalog (8 × 4)

Seasons stay **spring / summer / fall / winter** — real names have the most
educational value, and the pack contents support honest assignments. Framing
for each season is spoken in the intro VO of that season's first shed visit:

- **Spring** — "cool-season crops we *plant* when the ground wakes up"
- **Summer** — "heat-lovers that need lots of sun and water"
- **Fall** — "the big harvest — and cool-weather crops we plant again"
- **Winter** — "hardy crops, overwinterers, and windowsill gardening"

| Season | Crop | Sprite source | Educational hook |
|---|---|---|---|
| Spring | Lettuce | #1 (likely) | Cool weather, fast, shallow roots |
| Spring | Pea | #1 (confirmed) | Climbs; plant as soon as soil thaws |
| Spring | Radish | #2 (likely) | Fastest seed-to-harvest — great first crop |
| Spring | Carrot | #1 (likely) | Root grows hidden underground |
| Spring | Spinach | #2 (likely) | Loves cool days, bolts in heat |
| Spring | Onion | #1 (likely) | Sets planted early, bulbs by summer |
| Spring | Cabbage | #1 (confirmed via giant) | Big leafy head, frost-tolerant |
| Spring | Strawberry | #1 (confirmed) | Flowers in spring → June berries |
| Summer | Tomato | #1 (confirmed) | Needs warmth; most-watered crop |
| Summer | Corn | #1 (confirmed) | Tall; "knee-high by the 4th of July" |
| Summer | Cucumber | #1 (confirmed) | Vines; thirstiest in the heat |
| Summer | Green bean | #1 (confirmed) | Fast, repeat harvests |
| Summer | Bell pepper | #2 (confirmed) | Green → yellow → red ripening (pack has all recolors!) |
| Summer | Zucchini | #2 (confirmed) | Famous overproducer |
| Summer | Melon | #1 (likely) | Long hot season, big fruit on a vine |
| Summer | Eggplant | #2 (confirmed) | Heat-lover, glossy purple fruit |
| Fall | Pumpkin | #1 (confirmed via giant) | THE fall harvest icon |
| Fall | Potato | #1 (likely) | Dug up in fall like buried treasure |
| Fall | Broccoli | #2 (likely) | We eat the flower buds |
| Fall | Cauliflower | #1 (moved from #2, likely) | Cousin of broccoli |
| Fall | Grape | #1 (confirmed) | Autumn vineyard harvest |
| Fall | Raspberry | #2 (confirmed) | Fall-bearing canes |
| Fall | Turnip | #2 (likely) | Old-fashioned storage root |
| Fall | Celery | #2 (likely) | Long cool season, harvested late |
| Winter | Garlic | #2 (likely) | Planted in fall, sleeps under snow, ready in summer — the overwintering story |
| Winter | Leek | #2 (likely) | Stands in the snow, sweetens with frost |
| Winter | Kale | #2 (likely) | Frost makes it sweeter |
| Winter | Bok choy | #2 (likely) | Hardy green for cold frames |
| Winter | Wheat (winter wheat) | #1 (likely) | Farmers plant wheat before winter! |
| Winter | Chili pepper | #2 (confirmed) | Windowsill pot gardening indoors |
| Winter | Blueberry | #2 (confirmed) | Winter is for pruning + dormancy — plants sleep |
| Winter | Rice *or* Peanut *(swap-in)* | #2 (likely) | If present in the sheets, swap for the weakest winter entry and re-theme ("crops from around the world") |

Rules for reconciliation after purchase: keep the 8/4 split fixed; prefer
educational-accurate placement; any pack crop not in the table replaces the
nearest "likely" guess; recolors (14 added to #2) may stand in for missing
varieties.

---

## 5. Implementation plan

### Phase A — Purchase & import (blocked on buying)

1. Buy both packs; drop zips under
   `game/assets/tiles/mana_seed_crops/` (git-ignored — license forbids
   redistribution; mirror the Sprout Lands `.gitignore` treatment).
2. Since update 3.1 each crop ships as its own sheet with the crop name in
   the filename — write `FarmSprites` v2 that resolves
   `crop/<name>.png` + a small per-crop `Rect2` table (stage columns), replacing
   the single-atlas `PLANT_ROWS` scheme. Keep Sprout Lands fallback so the
   game still boots without the pack (tests, CI).
3. Mature crops are 16×32 — `PlantLayer` gets per-stage cell height and the
   billboard offset moves up half a cell at stages ≥ `growing`.

### Phase B — Catalog data (can start before purchase)

1. Generate `seeds.json` v3: 32 entries with growth tuning
   (waters/seconds/thirst per stage — reuse the v2 generator profile: fast
   radish → slow pumpkin), `seasons`, `blurb`, slides text.
2. `seasons.json`: 8 `seed_ids` per season per §4; season intro line updated
   with the framing sentences above.
3. Shed UI: grid is 4 columns (`ShedUI.gd`), so 8 seeds = two clean rows —
   no paging needed, verify sizing only.
4. Hamburger seed catalog: 32 rows × 3 stage-tiles needs a `ScrollContainer`
   (currently a flat grid sized for 11).

### Phase C — Voice & media scale-out

1. `dump_vo_lines.gd`: add the 21 new names + plurals + count lines + blurbs
   (~350 new sentences) → `./tools/gen_vo.sh` (one ElevenLabs bake, same key).
2. Per-crop media: slides (name/season/blurb + pack art) ship for all 32 on
   day one; trimmed YouTube videos stay curated in `tools/plant_media.tsv`
   and grow over time — the MediaPanel already falls back slides→video
   seamlessly.
3. LLM tile art for the 21 new catalog tiles (same style prompt as lettuce).

### Phase D — Verification

- Unit: catalog integrity test (32 crops, 8×4 seasons, no dupes, all growth
  fields present); FarmSprites v2 stage-resolution test.
- UX suite: seasonal shed shows exactly 8; plant/water/harvest one crop per
  season; catalog scroll screenshot.
- Fresh playthrough recording (all four seasons via `advance_season`).

**Effort estimate:** A ≈ half a day (mostly sheet-rect bookkeeping),
B ≈ 2–3 h, C ≈ 2 h + bake time, D ≈ 2 h.

---

## 6. Risks & notes

- **Sheet layout unknowns** until purchase — 3.1's per-crop sheets and cell
  reference guide should make mapping mechanical, but budget slack in Phase A.
- **VO cost:** ~350 new short sentences ≈ 8–10k chars on the shared
  ElevenLabs key — trivial vs. quota, but bake once, not per-iteration.
- **Winter honesty:** blueberry/chili are "indoor & dormancy" teaching angles
  rather than true winter *growing*; the intro line frames winter as
  "hardy crops, overwinterers, and windowsill gardening" so it stays truthful.
- **Do not commit** raw Mana Seed sheets anywhere public; the game repo is
  private/family but keep the ignore rule anyway.
- Multi-harvest sprites open a future "pick again" mechanic — backlog, not now.
