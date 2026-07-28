# IMPLEMENTATION PLAN — Ant Explorer

*A single, self-contained build plan that fuses the four strategy docs
(`STRATEGY_ANT_EXPLORER_SIMULATION.md`, `STRATEGY_ANT_EXPLORATION.md`,
`STRATEGY_STAR_ANT_DOCUMENTARIES.md`, `STRATEGY_MOTO_BOOTLOAD_LINUX.md`) into phased,
agent-executable steps. Written so an autonomous coding agent (Auto / Grok / Composer) can build it
with minimal clarification. Target: **Godot 4.x, GDScript, 2D slight-isometric**, Android export to
a rooted Moto G Play 2024 (Snapdragon 680 / 4 GB). Player: one 6-year-old, one finger.*

---

## 0. How to use this document

- **Authoritative scope:** the four strategy docs are the source of truth for *intent*; this doc is
  the source of truth for *sequence, structure, and acceptance criteria*. Where they conflict, this
  doc wins for build order.
- **Definition of done per phase:** each phase has an **Acceptance test** — do not advance until it
  passes on-device (or in the editor where noted).
- **Non-negotiables (thread these through every phase):**
  1. **One verb:** tap-to-go, deepening to tap-a-trail (become a role) and tap-a-star (watch video).
  2. **No text-reliant UI, no fail states, no timers.** Icons + animation only.
  3. **Tick ≠ frame:** deterministic sim at tunable Hz (`Config.sim_hz`, currently 2.5 for kid pacing), render/interpolate at 30 Hz.
  4. **Hard cap 100 agents**, pooled; locked 30 FPS; cool over 30-minute sessions.
  5. **The nursery (larval space) is the emotional core** — build its vertical slice early and make
     growth visible in **under ~2 minutes**.

---

## 1. Tech stack and project setup

- **Engine:** Godot **4.3+** (stable). 2D renderer: **Mobile** (`rendering/renderer/rendering_method = "mobile"`) — best fit for the Adreno 610/Snapdragon 680.
- **Language:** GDScript (no C# — keeps Android export simple and light).
- **Orientation:** landscape, sensor-landscape locked.
- **Resolution / stretch:** design canvas **1280×600** (≈ device 1600×720, 20:9-ish). Stretch mode
  `canvas_items`, aspect `expand`.
- **Version control:** git repo at `ant_explorer/game/`.
- **Export:** Android APK, `.gdignore` the raw asset sources; ship only imported assets + trimmed
  MP4s (or read MP4s from external storage — see Phase 6).

### 1.1 Repository / folder layout (create this exactly)

```
ant_explorer/
├── docs/                      # (existing strategy docs + this plan)
├── tools/                     # (existing) build_stars.sh, stars.tsv
├── game/                      # Godot project root  (project.godot lives here)
│   ├── project.godot
│   ├── assets/
│   │   ├── ants/              # ant sprites (see §2 — you will purchase/download here)
│   │   │   └── SOURCE.md       # provenance + license notes for what you dropped in
│   │   ├── tiles/             # chamber/tunnel tilesets
│   │   ├── fx/                # pheromone trails, star sparkle, dust
│   │   ├── ui/                # buttons, icons, role glyphs
│   │   ├── fonts/
│   │   └── audio/             # taps, ambient, eclosion chime
│   ├── stars/                 # trimmed MP4s (from tools/build_stars.sh), by id
│   ├── scenes/
│   │   ├── Main.tscn
│   │   ├── World.tscn
│   │   ├── Ant.tscn
│   │   ├── Chamber.tscn
│   │   ├── PheromoneTrail.tscn
│   │   ├── Star.tscn
│   │   ├── Larva.tscn
│   │   └── ui/ VideoPanel.tscn, RoleHUD.tscn, StarProgress.tscn
│   ├── scripts/
│   │   ├── sim/               # SimClock, Colony, Ant, Brood, Garden, Homeostasis, Markers
│   │   ├── nav/               # NavGraph, Pathing
│   │   ├── input/             # TapRouter
│   │   ├── render/            # IsoUtil, TrailRenderer, CameraFollow
│   │   ├── content/           # StarDB, SaveGame
│   │   └── Autoload singletons: Config.gd, Events.gd, Save.gd
│   └── data/
│       ├── config.tres        # tunable constants (see §4.7)
│       ├── map.tres           # chamber graph + star/trail placement
│       └── stars.json          # id -> {topic, zone, file} (mirror of tools/stars.tsv)
```

---

## 2. Art & UX plan (assets to purchase/download)

**Art direction:** "cute but recognizably leaf-cutter." Slight-isometric (2:1 dimetric) overhead.
Warm, high-contrast, low-text. Big, obvious glowing affordances (trails, stars). Everything reads
at a glance to a pre-reader.

### 2.1 Recommended asset packs (buy/download into the folders below)

| Need | Pack | Price | License | Put it in |
|---|---|---|---|---|
| **Ant sprites (primary)** | **Top-Down Ants Mega Pack** — Robert Brooks (gamedeveloperstudio) on itch.io | **~£19 / ~$24** | Commercial-use asset license | `game/assets/ants/` |
| Ant sprite (budget fallback) | **Top-Down Ant** — Robert Brooks (2 colors) | ~£1.25 | Commercial-use | `game/assets/ants/` |
| **Chambers/tunnels (primary)** | **Kenney — Isometric Dungeon Tiles** (70+ iso+top-down tiles) | **Free (CC0)** | CC0 (no attribution required) | `game/assets/tiles/` |
| Chambers (cute alt) | **PixyMoon — Caves Cute RPG 16×16** | ~$4.99 | Commercial, credit required | `game/assets/tiles/` |
| **UI (buttons/frames)** | **Kenney — UI Pack** (400+ sprites) | **Free (CC0)** | CC0 | `game/assets/ui/` |
| Fonts | **Kenney — Kenney Fonts** or a rounded free font | Free | CC0 | `game/assets/fonts/` |
| SFX | **Kenney — Interface/UI Audio** + **Impact/soft** | Free | CC0 | `game/assets/audio/` |

**Why this mix:** the Robert Brooks ant pack is the one paid item that matters — it ships
**17 ant species/types (workers, queens, eggs, larvae) with Idle / Walk-Run / attack / look /
die animations as PNG keyframes**, which maps directly onto our castes and FSM states (§3). Kenney
packs are CC0, so the *environment and UI are free and license-clean* for a gift app. Total spend:
**~$24** (just the ant pack), optionally +$5 for the cute cave tiles.

> **Agent note:** Do **not** attempt to purchase. The user buys and drops files in the folders
> above. On first run, if `game/assets/ants/` is empty, **fall back to placeholder colored
> capsules/circles** (generated in-code) so the game is always runnable. Gate real-art loading on
> file existence.

### 2.2 Sprite → caste/animation mapping (when the mega pack is present)

| Caste (sim) | Use pack species/size | Required anims | Placeholder if missing |
|---|---|---|---|
| Queen | largest species, "queen" variant | idle, (lay = idle+egg fx) | big amber circle |
| Soldier | large worker | idle, walk, "attack"→defend | red circle (large) |
| Media/forager | medium worker | idle, walk, carry (reuse walk + leaf fx) | green circle |
| Minor/gardener/nurse | small worker | idle, walk, carry | blue circle (small) |
| Larva | "larva" asset | stage0/1/2 = scale+tint of larva idle | tiny pale ovals |
| Pupa | "larva"/cocoon still | single still frame | white rounded rect |

Carry states are **walk anim + an overlay sprite** (leaf disc / food dot / egg / waste / larva) —
avoids needing dedicated carry animations. Direction: pick nearest of the pack's available facings
(mega pack keyframes) to the movement vector; if only one facing exists, **flip-H** for left/right
and rely on iso foreshortening.

### 2.3 UX system spec (implement in Phase 1, refine through Phase 6)

- **Camera:** fixed slight-iso, no rotation, soft-follow player ant (lerp, ~6% per frame). Optional
  clamped pinch-zoom deferred to post-v1.
- **Tap feedback (mandatory, every tap):** ripple + dust puff + soft click SFX within 1 frame.
- **Role HUD (`RoleHUD.tscn`):** a single small glyph near the player ant showing current role
  (green leaf / amber fungus / blue droplet / red shield / grey bundle). No text.
- **Trails:** glowing polylines, color per role (§ Exploration doc), animated flow in the work
  direction; dim when idle, brighten with activity. Implement as a shader on a `Line2D` or a scrolling
  texture; **pooled**, not per-ant particles.
- **Stars:** pulsing sparkle; on tap → walk over → dim world → `VideoPanel` eases in.
- **VideoPanel (`VideoPanel.tscn`):** big centered `VideoStreamPlayer`, one giant leaf-shaped
  ✕/back button (bottom corner, reachable), no scrubber. One decoder instance; free on close.
- **Star progress (`StarProgress.tscn`):** a row of tiny star pips that fill in; purely ambient,
  never blocks.
- **Touch targets:** ≥ 96 px at design scale (~1 cm on device). No double-tap / long-press / drag in
  v1.
- **Onboarding (wordless):** one star pulses near spawn on first run; trails glow invitingly. Use a
  pointing-paw sparkle cue if needed — never a sentence.
- **Accessibility/kid-proofing:** no lose state, gentle "death = carried home," invaders "pushed
  back" (no gore). Landscape locked; nothing critical in exact screen corners.

---

## 3. Core data model (implement in Phase 0–2)

### 3.1 Isometric utilities (`scripts/render/IsoUtil.gd`)
- `tile_to_world(cell: Vector2i) -> Vector2` and inverse, for 2:1 dimetric.
- `depth_sort`: y-sort via `YSort`/`Node2D.y_sort_enabled` on the world; per-ant `z` from world y.

### 3.2 Navigation (`scripts/nav/NavGraph.gd`, `Pathing.gd`)
- **Chamber graph:** nodes = chambers (id, world rect, walkable polygon, connected tunnel ids,
  star ids, trail ids). Edges = tunnels (polyline paths).
- **Intra-chamber:** A* over a coarse grid or Godot `NavigationRegion2D` per chamber.
- **Inter-chamber:** graph BFS/A* over chambers → concatenated tunnel polylines → smooth path.
- `find_path(from_pos, to_pos) -> PackedVector2Array` handles both, transparently.

### 3.3 Agent (`scripts/sim/Ant.gd`) — state vector
```gdscript
class_name AntState
var id: int
var caste: int            # enum Queen/Soldier/Forager/Gardener/Nurse/Larva/Pupa
var node_id: int          # current chamber
var cell: Vector2         # world pos (sim-space)
var facing: Vector2
var state: int            # FSM enum (per caste)
var target                # Variant: pos / node_id / ant id
var carry: int            # enum none/leaf/egg/food/waste/larva
var age_ticks: int
# brood-only:
var larva_stage: int      # 0,1,2
var nutrition: float
var jh_dose: float
var caste_destiny: int    # decided at pupation from nutrition+jh
```
- **Pooling:** pre-allocate 100 `AntState` in an array; brood reuse slots on eclosion/death. No
  per-frame allocation.
- **Rendering:** a lightweight `Ant.tscn` (Sprite2D + overlay) bound to an `AntState` by id;
  interpolate sprite pos between sim ticks.

### 3.4 Brood / larval space (`scripts/sim/Brood.gd`) — the heart
- `target_larvae = clamp(round(k * living_adults), 15, 25)` with `k≈0.2`.
- Nurse actions (readable): **feed** (`nutrition += n`), **dose JH** (`jh_dose += j`, tints larva),
  **move/re-tuck** (reposition).
- Stage advance on `nutrition` thresholds, **gated by `garden_health`**.
- **Caste determination at pupation** from `(nutrition, jh_dose)`: high both → soldier/media;
  modest → minor/nurse. Fix `caste_destiny`.
- `LARVA(2) → PUPA → (pupa_ticks) → eclose` into a new adult of `caste_destiny` that walks off.
- Tune thresholds so **one full feed→pupa→eclose is visible in ~30–90 s** of watching.

### 3.5 Garden economy (`scripts/sim/Garden.gd`)
- `garden_health ∈ [0,1]`; rises on leaf deposits + gardener tending, falls with unremoved
  waste/decay. Drives brood growth rate and ambient activity. Self-correcting via homeostasis.

### 3.6 Markers/salience (light in v1) (`scripts/sim/Markers.gd`)
- For v1, trails are **visual + role-join affordances**; full marker accumulation (`‖M‖≥θ_fire`) is
  simplified to "worker demand per role" driving homeostasis and trail brightness. (The richer
  marker algebra from the substrate work is out of scope for the kid game.)

### 3.7 Save (`scripts/content/SaveGame.gd`, autoload `Save.gd`)
```
Save := { tick, rng_seed, garden_health, ants[<compact>], stars_collected[], player{node,pos} }
```
- Debounced autosave (dirty flag, ≤ every few seconds / on pause / on app-pause). Godot binary or
  JSON via `FileAccess`. Restore exactly (mid-pupation larvae included).

---

## 4. Phased build

### PHASE 0 — Project skeleton + one chamber + tap-to-move *(editor-testable)*
**Goal:** prove the loop shell and frame budget.
- Create the Godot project, folders (§1.1), autoloads (`Config`, `Events`, `Save`).
- `IsoUtil`, a single `Chamber.tscn` with a walkable polygon, `CameraFollow`.
- Player `Ant` with **tap-to-move** (`TapRouter` → `Pathing.find_path` → walk).
- **Placeholder art**: colored capsules (no assets needed yet).
- 20 pooled NPC ants wandering on stub FSMs (idle/walk).
- `SimClock` autoload: fixed 5 Hz `sim_tick` signal; render interpolates.

**Acceptance:** editor runs at 60 FPS with 21 ants; tapping moves the player ant along a smooth
path; sim tick and render are decoupled (verify sim runs at 5 Hz via a counter).

---

### PHASE 1 — Nursery vertical slice (larval space) *(the soul — do this before the full map)*
**Goal:** the delightful core: watch a larva grow → pupate → eclose.
- `Brood.gd`, `Larva.tscn`, nurse FSM (feed / dose JH / move).
- Nursery chamber with a larva cluster sized by `target_larvae`.
- Blue **nurse trail**; tapping it makes the player ant a nurse; tapping a larva feeds *that* one.
- Larva visual states (scale + JH tint); pupa still; eclosion → adult walks off; queen egg carried
  in to restart cycle.
- Eclosion chime + sparkle (juice).

**Acceptance (critical):** sitting in the nursery, a full **feed → pupate → eclose** is visibly
completed in **≤ ~2 minutes**; caste of the new adult tracks how it was fed (verify: force high vs
low nutrition/JH → soldier vs minor). Feels good to watch.

---

### PHASE 2 — Full map, economy, population dynamics
**Goal:** a living colony that self-manages.
- Build the **7–9 chamber graph** + tunnels from `data/map.tres` (Surface, Entrance, Garden A/B,
  Nursery, Queen, Dump, Soldier outpost, optional Deep tunnel).
- Caste FSMs: forager (surface→cut→haul→deposit), gardener (tend), nurse (Phase 1), + carriers.
- `Garden.gd` economy + `Homeostasis.gd` controller (nudge task allocation to current shortage).
- Aging/death → body carried to Dump. Queen egg cadence gated by cap + garden health.
- All castes rendered with real ant sprites **if present**, else placeholders.

**Acceptance:** colony runs 10+ min unattended, population orbits ~90–100, garden health stable,
convoys/nursery/dump all visibly active; 30 FPS on-device with 100 ants.

---

### PHASE 2.5 — Sprite / audio / space backfill *(exploration feel)*
**Goal:** purchased assets in play; chambers feel large; first-visit narration.
- `SpriteCatalog` + `AntView` mega_pack mapping (leaf cutter / queen / soldier / black ant /
  fire ant / larva props); capsules remain fallback.
- Enlarge `data/map.json` chamber halves + spacing; pull camera zoom back (~0.48); **click-to-move
  only** (no zoom dial).
- `ChamberVO` + `data/chamber_vo.json`: on first access per session, soft enter cue + two spoken
  sentences (`{what the area is}. {what ants do here}.`) via OS TTS when available.

**Acceptance:** ants show real sprites when assets present; nursery/surface feel roomy to walk;
entering a new chamber once per run plays cue + VO; re-entry silent until new session.

---

### PHASE 3 — Trails, roles, and full exploration UX
**Goal:** the "become any worker" interaction + camera/UX polish.
- One **color-coded trail per role** (except Queen): forager/gardener/nurse/soldier/waste
  (+ optional deep-tunnel scout).
- Tap-trail → walk to it → adopt role at that location → run role FSM; tap-open-ground → drop role.
- `RoleHUD`, tap feedback, trail flow shaders, soft-follow camera finalize.

**Acceptance:** a tester (ideally the daughter) can, with no instruction, tap a trail and end up
"being" that worker doing its job; dropping the role works; only one role active at a time; reads
clearly.

---

### PHASE 4 — Invaders & soldiers (gentle stakes)
**Goal:** occasional, non-scary events.
- Rare invader event spawns small enemy group at Entrance; soldiers flip to `RESPOND_INVADER`.
- Player can join via red trail; invaders are "pushed back" (retreat animation, no gore).

**Acceptance:** event fires occasionally, resolves on its own if ignored, never creates a fail
state or distressing imagery; player can optionally participate.

---

### PHASE 5 — Documentary stars (offline video)
**Goal:** the reward/learning layer.
- Place 12 star markers at mapped zones; load `data/stars.json` (`StarDB` + `StarMarker`).
- **In-world collect:** player ant approaches within `star_approach_radius` → mark collected, play
  shrivel on the world star (no longer actionable). Optional: auto-play once on first collect;
  **rewatch is via the landscape star rails**, not by re-entering the radius forever.
- **Landscape shell (Fable):** **`docs/STRATEGY_LANDSCAPE_STAR_RAILS.md`** — centered playfield on
  wide 1600×720 kiosk, permanent **silver borders**, **6+6 side star rails** (grey/smaller until
  collected; color tile pop on collect), double-tap **1.0 s** on a collected rail tile to watch
  video, double-tap **1.0 s** chrome to hide rails into **bright brown soil** columns. Revisit
  `project.godot` stretch/`aspect=expand` so the world does not bleed into rail gutters.
- **Clip build (host):** `tools/build_stars.sh` → `game/stars/<id>.ogv` (see §6).
- `VideoPanel`: one decoder at a time; free on close. `Save` + `Events.star_collected` drive rails.

**Acceptance:** shell checklist in `STRATEGY_LANDSCAPE_STAR_RAILS.md` §9; offline play works; RAM
flat across several videos (decoder freed).

---

### PHASE 6 — Android export, performance pass, kiosk integration
**Goal:** ship the APK and lock the device.
- Android export preset; landscape lock; package name e.g. `com.dylan.star_learner`.
- **Performance pass:** confirm locked 30 FPS + thermals over 30 min on-device; pooled sprites,
  `MultiMeshInstance2D` if needed for ants, texture atlases, mip off for pixel art, audio bus small.
- **Video assets on device:** ship `.ogv` in the APK if small enough, else place on microSD/app
  external dir and read at runtime (see `STRATEGY_STAR_ANT_DOCUMENTARIES.md` §3.3 deploy path).
- **Kiosk:** install APK, set as Home/pinned app per `STRATEGY_MOTO_BOOTLOAD_LINUX.md` §5
  (screen pinning + landscape + immersive). Verify a 6-year-old can't escape to Android.

**Acceptance:** APK installs on the rooted fogona device, boots to landscape, runs locked at
30 FPS, stays cool, and is escape-proof in kiosk/pinned mode.

---

## 5. Constants to expose in `data/config.tres` (§4.7)

Single tunables resource so balancing needs no code edits:
- `SIM_HZ = 5`, `AGENT_CAP = 100`, caste target counts.
- Brood: `k=0.2`, larva-stage nutrition thresholds, `jh` step, `pupa_ticks`, caste-destiny cutoffs.
- Garden: deposit gain, waste decay, health→growth curve.
- Camera lerp, tap-target size, trail brightness ranges.
- `egg_interval`, `max_age` (with jitter).

---

## 6. Video pipeline notes for the agent

### 6.1 Add `.ogv` transcode (engine playback)
`tools/build_stars.sh` currently outputs kid-spec **MP4** (good for general use / phones). For Godot
`VideoStreamPlayer`, also emit **Ogg Theora**. Add a sibling step or a `--ogv` flag:

```bash
# after producing stars/<id>.mp4:
ffmpeg -y -i "stars/$id.mp4" -c:v libtheora -q:v 7 -c:a libvorbis -q:a 4 "stars/$id.ogv"
```
Ship `.ogv` to `game/stars/`. Keep MP4s as the archival/trim-preview format.

### 6.2 Sources & trimming
Sources, suggested trim windows, and the `stars.tsv` manifest are in
`STRATEGY_STAR_ANT_DOCUMENTARIES.md` and `BIBLIOGRAPHY.md`. BBC Planet Ant timestamps are
placeholders to verify. Private family/educational use; keep credits in-app.

---

## 7. Risk / watch-items (carry forward)
- **Frame budget on Snapdragon 680:** verify the tick≠frame split and pooling early (Phase 0/2), not
  at the end.
- **Nursery delight is make-or-break:** if the ~2-minute growth loop isn't satisfying, re-tune before
  building breadth.
- **Video codec on Android:** default to `.ogv` to avoid H.264 plugin pain; test on-device in Phase 5.
- **Asset absence must never block a build:** placeholder fallback is mandatory (§2.1 agent note).
- **Kid-proofing:** every interaction must be reversible, wordless, and non-scary.

---

## 8. One-paragraph brief for the implementing agent

Build a Godot 4.3 GDScript 2D slight-isometric game where a six-year-old controls one ant in a
living, ≤100-agent leaf-cutter colony. The only control is tap-to-go, deepening into tapping a
color-coded pheromone trail to *become* that worker and tapping glowing stars to watch short offline
ant documentaries. Run the simulation deterministically at 5 Hz and render/interpolate at 30 Hz with
pooled sprites so it holds frame rate and stays cool on a Snapdragon 680. Build the nursery
("larval space") first and make a larva's feed→pupate→eclose visibly complete in under two minutes,
with caste decided by how nurses feed it — that scene is the soul of the app. Use the Robert Brooks
Top-Down Ants Mega Pack for ants (fall back to colored shapes if absent) and CC0 Kenney tiles/UI for
everything else. There are no menus, no text, no timers, and no fail states. Ship an Android APK and
lock it in kiosk mode on the dedicated device. Acceptance tests per phase are above; do not advance a
phase until its test passes on-device.
