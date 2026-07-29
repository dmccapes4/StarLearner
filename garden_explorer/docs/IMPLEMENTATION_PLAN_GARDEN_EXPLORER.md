# IMPLEMENTATION PLAN — Garden Explorer

*Phased, agent-executable build plan for **Garden Explorer**, Game #4 in Star Learner.
Mirrors the structure of `ant_explorer/docs/IMPLEMENTATION_PLAN_ANT_EXPLORER.md`.
Target: **Godot 4.3+, GDScript, 2D isometric (Sprout Lands / Stardew-like)**, Android export to
the Star Learner kiosk (Moto G Play 2024). Player: one ~6-year-old, one finger.*

---

## 0. How to use this document

- **Authoritative scope:** this plan + `game/data/seeds.json` + `game/data/stars.json` +
  `tools/stars.tsv` / `tools/plant_media.tsv`. Where strategy notes and this plan conflict, **this
  plan wins for build order**.
- **Definition of done per phase:** each phase has an **Acceptance test** — do not advance until it
  passes in the editor (or on-device where noted).
- **Non-negotiables (thread through every phase):**
  1. **One verb:** tap-to-act (walk, open shed, plant, water, uproot, harvest, talk to animals,
     open star menu).
  2. **No text-reliant UI** — ElevenLabs VO + icons + gold outlines. Large targets (≥96 px).
  3. **Wide landscape stage** — playfield is a wide rectangular farm; star tiles live in a
     **hamburger menu (top-left)**, not side rails (unlike Ant Explorer).
  4. **Offline-first** — baked `.ogv` / `.mp4` clips + WAV VO; one video decoder at a time.
  5. **Kiosk save** — persist beds, inventory, season, harvested totals, star unlocks; restart like
     Ant Explorer.

---

## 1. Vision & loop

The child is a gardener on a cozy isometric farm:

| Zone | Layout | Role |
|------|--------|------|
| **Left** | Shed / seed store | Pick seeds; deposit harvests; see narrated plant totals |
| **Middle** | **2×3** rectangular beds (**6 beds × 4 plant slots**) | Plant, water, grow, uproot, harvest |
| **Right** | Fence + animals | Tap animals for VO + optional star guidance |

**Core loop (indefinite):** get seed → plant → water → watch grow → harvest → store in shed →
season advances → new seasonal seed subset → repeat.

**Knowledge stars (12):** short offline gardening documentaries. Some are **always revealed** in the
star menu (dim until collected); others **reveal when gameplay criteria are met**. Tapping a locked
star: VO + camera pan to the action location + gold outline guidance.

**Educational media on actions (per plant):**

| Moment | Media |
|--------|-------|
| Select seed in shed | Seed close-up video (image fallback) |
| Plant into a bed slot | How-to-grow that plant (season, conditions, growth) |
| Sprout stage reached | Sprout / seedling video (image fallback) |
| Fully grown | Grown plant / harvest-ready video |
| Star / intro | Trimmed documentary clips |

---

## 2. Tech stack & folder layout

- **Engine:** Godot **4.3+**, Mobile renderer, landscape, canvas `1280×600` (or match Ant Explorer).
- **Art:** Sprout Lands (or equivalent Stardew-like 2D farm pack) — see §3.
- **Audio:** ElevenLabs baked via `tools/gen_vo.sh` (same pattern as Ant Explorer).
- **Video:** `tools/build_stars.sh` + `tools/build_plant_media.sh` from TSV manifests →
  `game/stars/`, `game/assets/plants/<id>/`.

```
garden_explorer/
├── docs/
│   ├── IMPLEMENTATION_PLAN_GARDEN_EXPLORER.md   ← this file
│   └── BIBLIOGRAPHY.md
├── tools/
│   ├── stars.tsv
│   ├── plant_media.tsv
│   ├── build_stars.sh          # copy/adapt from ant_explorer
│   ├── build_plant_media.sh
│   └── gen_vo.sh
└── game/                       # Godot project root
    ├── project.godot
    ├── data/
    │   ├── seeds.json          # plant catalogue + growth params
    │   ├── stars.json          # 12 knowledge stars
    │   ├── map.json            # shed / beds / fence zones
    │   ├── seasons.json        # season length + seed subsets
    │   └── *_vo.json
    ├── assets/
    │   ├── tiles/              # Sprout Lands farm tiles
    │   ├── plants/             # per-plant sprites + media
    │   ├── ui/                 # hamburger, gold outlines
    │   └── audio/vo/
    ├── stars/                  # trimmed star .ogv
    ├── scenes/
    └── scripts/
        ├── sim/                # beds, growth, seasons, water
        ├── world/              # map, shed, animals, player
        ├── ui/                 # StarMenu (hamburger), VideoPanel, ShedUI
        ├── content/            # StarDB, SeedDB, SaveGame
        └── autoload/           # Config, Events, Save, Narrator
```

---

## 3. Art & UX

**Direction:** warm Stardew-like 2D isometric / slight top-down; high contrast; big glowing
affordances (water can, gold outlines, pulsing stars in menu).

| Need | Pack | Notes |
|------|------|-------|
| Farm tiles / beds / fence / shed | **Sprout Lands** (Cup Nooble) — already used in Ant Explorer | Prefer reusing family license; do not redistribute raw art |
| Player gardener | Sprout Lands character or similar kid-readable avatar | Idle / walk 4-dir |
| Plant growth stages | Pack crops + custom stage sprites per seed id | empty → planted → sprout → growing → grown |
| UI | Kenney UI Pack (CC0) | Hamburger, buttons |
| Animals | Sprout Lands animals or Kenney | Chicken, rabbit, goat (or similar) behind fence |

**UX:**
- Hamburger (top-left) → star grid (12 tiles). Locked dim / unlocked full color.
- Locked star tap → VO (“Let’s find where…”) → camera lerp to zone → gold outline on target.
- Intro: short offline video of avatar doing plant / water / harvest / shed / animals.
- No fail states; uproot always allowed; watering is clear and satisfying.

---

## 4. Data model (Phase 0)

### 4.1 Plants (`seeds.json`)

Each plant: `id`, display name (VO only), seasons, growth ticks with water, media paths, shed icon.

Growth stages: `seed` → `sprout` → `growing` → `grown` → (harvest clears slot).

### 4.2 Beds

6 beds × 4 slots. Slot: `{ plant_id|null, stage, water, progress }`.

### 4.3 Stars (`stars.json`)

12 entries: `id`, `topic`, `zone`, `reveal` (`always` | `gameplay:<criterion>`), `file`.

### 4.4 Seasons

Cycle after wall/sim time. Each season exposes a **subset** of the seed catalogue in the shed.
Play continues indefinitely.

### 4.5 Save

Beds, inventory counts, season index/time, unlocked/collected stars, first-run intro flag.
Restart clears like Ant Explorer.

---

## 5. Phases

### Phase 0 — Scaffold & content manifests ✅ (this drop)

- [x] Folder layout
- [x] `seeds.json`, `stars.json`, `seasons.json`
- [x] `tools/stars.tsv`, `tools/plant_media.tsv`, `docs/BIBLIOGRAPHY.md`
- [x] This implementation plan

**Acceptance:** manifests valid JSON/TSV; every media row has a YouTube URL or explicit `image`
fallback noted in BIBLIOGRAPHY.

### Phase 1 — Godot shell & wide map ✅

- [x] `project.godot`, Main / World scenes, isometric farm map: shed | 2×3 beds | fence
- [x] Player tap-to-walk; camera soft-follow; hamburger star-menu placeholder
- [x] Placeholder Polygon2D art (Sprout Lands drop-in later)
- [x] Headless tests: `godot --headless --path game -s res://tests/run_tests.gd`

**Acceptance:** walk left→middle→right; beds and shed tappable zones visible. ✅ (26/26 tests)

### Phase 2 — Shed, seeds, plant/uproot ✅

- [x] Sprout Lands pack symlinked from `ant_explorer` (`game/assets/tiles/`)
- [x] Shed UI: seasonal seed picker + seed media preview (video if built, else pack icon)
- [x] Plant into empty slot; uproot any stage; `GardenState` + `PlantLayer`
- [x] Tests: SeedDB, FarmSprites, GardenPlant (54 total)

**Acceptance:** plant 4 plants in one bed; uproot one; seed media plays/shows. ✅

### Phase 3 — Water, growth, harvest, shed totals ✅

- [x] Tool bar: Water · Harvest · Uproot
- [x] Water advances growth stages (seed → sprout → growing → grown)
- [x] Stage media toast on sprout / grown
- [x] Harvest → shed basket totals + spoken count (OS TTS fallback)
- [x] UX suite: `tools/run_ux_suite.sh` (screenshots + event log checks)
- [x] Unit tests: GrowthHarvest (68 total logic tests)

**Acceptance:** seed→grown→harvest in <~3 minutes with water; VO speaks total. ✅

### Phase 4 — Seasons & animals ✅

- [x] `SeasonClock` wall-clock timer (`seasons.json` duration; `Config.season_duration_sec` override)
- [x] Season advance refreshes shed seed subset; clears out-of-season held seed; VO + `SeasonHUD`
- [x] Soft ground tint per season
- [x] Fence animals: tap → VO (OS TTS fallback); `Events.animal_tapped`
- [x] Unit tests: SeasonsAnimals; UX suite season flip + animal tap

**Acceptance:** season flips; seed list changes; animals respond. ✅

### Phase 5 — Stars, guidance, intro, video pipeline ✅

- [x] Hamburger star menu — always vs gameplay reveal; dim / collected chrome
- [x] Locked tap → VO + camera pan + `GoldOutline` on zone
- [x] Confirm tap → `VideoPanel` (one decoder; topic fallback if `.ogv` missing) + collect
- [x] `StarProgress` reveal flags from gameplay events; lean `Save` (stars + intro + flags)
- [x] `IntroPanel` first-launch START → intro clip/VO once
- [x] `tools/build_stars.sh` / `build_plant_media.sh` (trim pipeline ready)
- [x] Unit + UX coverage for guidance / collect / intro skip

**Acceptance:** all 12 stars collectable; locked-star guidance works; intro plays once. ✅

### Phase 6 — VO bake, save/restart, kiosk polish ✅

- [x] ElevenLabs VO bake (`tools/gen_vo.sh` → `game/audio/vo/<md5>.wav`) via shared `ant_explorer/tools/secrets/elevenlabs.env`
- [x] `Narrator` / `VoStream` / `Speak` — baked clips first, OS TTS fallback
- [x] Full `Save` — beds, season, harvest, stars, intro + `.antphone_wipe` / `EXTRA_WIPE_SAVE`
- [x] `IdleGuard` autoload
- [x] APK: `tools/build_garden_apk.sh` → `com.dylan.antexplorer.garden`; catalog tile `garden`
- [x] Playthrough: `tools/make_demo_videos.sh` → `docs/demo/garden_explorer_playthrough.mp4`

**Acceptance:** kill app → reopen restores beds/stars/season; Restart clears; APK boots offline. ✅ (APK build script ready; install when device on ADB)

---

## 6. Star list (12)

| # | id | Topic | Zone | Reveal |
|---|-----|-------|------|--------|
| 1 | `01_seeds` | What is a seed? | shed | `always` |
| 2 | `02_soil` | Soil & garden beds | beds | `always` |
| 3 | `03_planting` | How to plant | beds | `gameplay:planted_once` |
| 4 | `04_watering` | Watering plants | beds | `gameplay:watered_once` |
| 5 | `05_sprouting` | Germination | beds | `gameplay:sprout_seen` |
| 6 | `06_sunlight` | Sun & growing | beds | `always` |
| 7 | `07_growing` | Watching plants grow | beds | `gameplay:growing_seen` |
| 8 | `08_weeding` | Uprooting / clearing | beds | `gameplay:uprooted_once` |
| 9 | `09_harvest` | Harvesting | beds | `gameplay:harvested_once` |
| 10 | `10_seasons` | Seasons in the garden | map | `gameplay:season_changed` |
| 11 | `11_animals` | Garden animals | fence | `always` |
| 12 | `12_store` | Storing the harvest | shed | `gameplay:stored_once` |

---

## 7. Seed catalogue (v1)

Tomato, carrot, lettuce, sunflower, pumpkin, strawberry, pea, radish, corn, cucumber, bean.
Season subsets in `seasons.json`. Growth is **fairly quick** with water (kid pacing).

---

## 8. Content pipeline

```bash
cd garden_explorer/tools
./build_stars.sh              # → game/stars/<id>.ogv
./build_plant_media.sh        # → game/assets/plants/<plant_id>/<kind>.ogv
# Windows in TSVs are FIRST GUESSES — scrub and tighten before ship.
```

Private family / educational use; credit sources in BIBLIOGRAPHY and in-app credits VO.

---

## 9. Open decisions (locked for v1)

| Topic | Decision |
|-------|----------|
| Shed vs store | **Shed** (left) — seed select + harvest storage |
| Star UI | **Hamburger top-left** (wide screen) |
| Bed count | **6 beds × 4 slots** |
| Growth speed | Tunable; target first harvest **under ~3 minutes** with regular watering |
| Animals | Chickens + rabbit (goat optional) behind right fence |
