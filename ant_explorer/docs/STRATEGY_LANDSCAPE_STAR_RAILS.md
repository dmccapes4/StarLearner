# STRATEGY — Landscape Shell & Star Rails (UX for Fable)

*Implementable UX brief for the Star Learner / Ant Explorer landscape shell. Written for the agent
currently owning UX (`Fable`). Product names: device + home app = **Star Learner**; this game =
**Ant Explorer** under `star_learning/ant_explorer/`. Prefer implementing here over inventing a
parallel layout.*

---

## COLD OPEN — WHY THE SHELL MATTERS

**McCLANE:** The phone is wide and short. Stretch the colony across the whole screen and the ants
look like they're on a highway. Stick tiny stars in the corner and a six-year-old never finds them
again.

**FEYNMAN:** So give her a **centered playfield** that stays true, and put the twelve knowledge
stars as **always-visible rails** on the left and right — grey until she earns them, bright when
she does. A **silver border** is the contract: *inside = world, outside = collection*. Double-tap
hides the rails into soil when she wants more dirt to walk on. One verb still rules the world
(tap-to-go). The rails are a second, equally thumbable verb: *tap a square*.

---

## 1. Device & display context (do not ignore)

| Fact | Value | Consequence |
|------|-------|-------------|
| Hardware | Moto G Play 2024 (`fogona`), landscape kiosk | Always landscape; orientation locked |
| Panel | **1600×720** (~20:9), ~6.5″ | Very wide; side gutters are real estate, not waste |
| Current Godot setup | `project.godot`: viewport **1280×600**, `stretch/mode=canvas_items`, `stretch/aspect=expand` | **Today the game fills/stretches the whole screen** — no fixed playfield, no rails |
| Target shell | Centered playfield + left/right rails | Change stretch / root layout so the **world never owns the side gutters** |

**Rule:** On this wide panel, letterboxing a centered playfield and filling the sides with star
rails (or soil when hidden) is the intended composition. Do **not** leave `aspect=expand` as the
sole layout if it causes the world to bleed into the rail columns.

Suggested approach (pick one, keep it kid-simple):

1. **Preferred:** Root `HBoxContainer` (or custom `Control`) —
   `StarRailLeft | SilverBorder | PlayfieldHost | SilverBorder | StarRailRight`.
   PlayfieldHost holds a `SubViewport` / `SubViewportContainer` (or clipped `Node2D` world) with a
   fixed design aspect (see §2). Stretch mode may stay `canvas_items` with `keep` **or** the shell
   does its own letterboxing inside PlayfieldHost.
2. **Acceptable:** `aspect=keep` on the window plus overlays for rails — only if rails stay outside
   the scaled world and never receive world taps by accident.

Touch targets on rails: **≥ 96 px** (existing kid rule from the implementation plan).

---

## 2. Composition — always-on landscape chrome

```
┌──────────┬─┬─────────────────────┬─┬──────────┐
│ StarRail │S│                     │S│ StarRail │
│  LEFT    │I│   PLAYFIELD         │I│  RIGHT   │
│  6 tiles │L│   (centered world)  │L│  6 tiles │
│          │V│                     │V│          │
└──────────┴─┴─────────────────────┴─┴──────────┘
                 ↑ silver border always present
```

### 2.1 Playfield
- Holds the living colony (`World.tscn` / camera / ants). Same tap-to-go rules as today.
- **Aspect:** prefer a stable play rectangle (e.g. design size near **960×600** or **square-ish**
  within the center). Exact numbers are Fable’s call; what matters is **no horizontal stretch into
  the rails** and a calm, centered feel on 1600×720.
- Camera continues soft-follow inside the playfield only.
- Debug HUD / intro / video fullscreen may overlay the whole screen; when `VideoPanel` is open it
  covers rails + playfield (already “one decoder” Phase 5 rule).

### 2.2 Silver border (non-negotiable)
- A **silver / light-metal** strip **always** separates playfield from each rail column.
- Visible in **both** rails-visible and rails-hidden modes.
- When rails are hidden, the border still sits between playfield and the **soil replacement
  columns** (so the playfield edge never dissolves into full-bleed dirt).
- Visual: thin bright strip (e.g. `#C0C0C8`–`#E8E8F0` with a soft darker edge). Not gold (gold =
  in-world stars). Not brown.

### 2.3 Star rails (default = visible)
- **Left: 6 tiles. Right: 6 tiles.** Fixed order for the whole product life.
- Suggested assignment (matches `game/data/stars.json` ids — adjust only with a comment in code):

| Side | Slots (top → bottom) |
|------|----------------------|
| **Left** | `01_queen`, `02_larvae`, `03_pupae`, `04_fungus`, `05_forage`, `06_pheromone` |
| **Right** | `07_soldiers`, `08_waste`, `09_labor`, `10_bacteria`, `11_architecture`, `12_invaders` |

- Rails are **UI (`CanvasLayer` / `Control`)**, not world sprites. They must not steal world taps
  except on their own buttons.
- Replace or demote the current tiny `StarProgress` corner counter once rails show collection
  state (optional: keep a tiny `n/12` somewhere non-conflicting).

---

## 3. Star tile states

Each rail slot is always present.

| State | Look | Tap behavior |
|-------|------|----------------|
| **Undiscovered** | Grey, **slightly smaller** (~85–90% scale), muted icon or empty well | Speak guidance VO (§5). Do **not** open video. |
| **Collected** | Full size, color topic icon “pops” in (short scale punch OK) | **Arm** watch prompt (§4). Second tap plays video. |
| **In-world star** | Golden marker in chamber (existing `StarMarker`) | On collect: **shrivel** animation → marker inactive forever for that save. Rail tile flips to Collected. |

Persistence: use existing `Save` star collection (`Save.has_star` / collect APIs already used by
`StarProgress` / Phase 5). Rails must refresh on `Events.star_collected` and on load.

**Art (v1): DONE.** All 12 topic icons are generated (Sprout Lands–adjacent cozy pixel style,
soft pastel palette, rounded soil-tile frame) and live at `game/assets/ui/star_tiles/<id>.png`
(256×256 PNGs; downscale in-scene as needed). Filenames match star ids exactly
(`01_queen.png` … `12_invaders.png`). Missing art → solid soft color well + tiny star glyph,
never a crash.

---

## 4. Double-tap to watch (collected tiles only)

Interaction model for a **collected** rail tile:

1. **First tap** (within a fresh window): play short narration, e.g.  
   *“Tap again to watch the queen video.”*  
   (Topic name from `stars.json` `topic` field, kid-shortened if needed.)
2. **Second tap within 1.0 second** of the first: open existing **`VideoPanel`** fullscreen for
   that star’s `.ogv` (`res://stars/<id>.ogv` / `StarDB` paths). Clear the armed state.
3. If **> 1.0 s** elapses with no second tap: clear armed state (next tap is a new first tap).
4. Only **one** tile armed at a time. Arming another cancels the previous.

Do **not** require a literal OS double-click event — implement as **arm + 1.0 s timeout** so it
works for kid thumbs on a touch panel.

Undiscovered tiles never arm video.

---

## 5. Undiscovered guidance VO

On tap of an undiscovered tile, speak (ElevenLabs-baked WAV preferred; fallback OK):

> “Explore the **{place}** and look for the golden star!”

Where `{place}` is a kid-friendly chamber name from the star’s `zone` (map to friendly labels:
nursery, queen’s room, fungal garden, sunny outside, doorway, soldier outpost, dump, deep tunnel,
invasion clearing, etc.). Keep lines short; store under something like
`game/data/star_rail_vo.json` + WAVs in `assets/audio/vo/star_rail/` so `VoStream` can load them
the same way as chamber/role VO.

Optional softer variant is fine if it stays one sentence and non-scolding.

---

## 6. Occlude-by-default, touch-to-reveal (SHIPPED model)

*Revised after playtest: a hidden double-tap gesture was undiscoverable for a six-year-old. The
rails now **default to occluded** (soil) and **reveal on touch**, then tuck themselves back after a
few seconds. This keeps the wide dirt stage most of the time and makes the collection appear with a
single deliberate touch — no gesture to learn.*

| Gesture | Effect |
|---------|--------|
| **Default** | Both side columns show **bright brown soil** (occluded). Silver borders remain. A faint stacked-star glyph hints the soil is tap-able. Star tiles hidden; taps here do not move the ant. |
| **Touch a side column** | Rails **brighten / fade in** (~0.2 s). Tiles become clickable, keeping the grey-smaller (undiscovered) vs full-colour (collected) variation. |
| **No interaction for `REVEAL_SECONDS` (5 s)** | Rails fade back **under the soil** (~0.3 s). Any side touch or tile tap resets the 5 s timer. |
| **First touch never triggers a tile** | While occluded the tiles are non-interactive, so the revealing touch only brightens; the child then taps a tile deliberately. |

**Implementer notes (as built in `LandscapeShell.gd`):**
- One transient `revealed` flag + a `_reveal_until` deadline bumped on every interaction; `tick(now)`
  re-occludes once the deadline passes (frozen while a video is open). **Not** persisted — always
  starts occluded so the dirt stage is the calm default.
- Tiles toggle `mouse_filter` (STOP when revealed, IGNORE when occluded) so occluded taps fall
  through to the soil column for the reveal.
- Launching a video occludes the rails immediately (the video covers the screen); they return
  occluded when the child taps **Back**.

### 6.1 Intro narration choreography

The reveal/occlude mechanic is **taught in the launch narration** so a six-year-old meets it once,
guided, before ever touching a side.

- `data/intro_vo.json` is an ordered `intro.lines[]` list (one baked clip per line in
  `assets/audio/vo/intro/<key>.wav`, generated by `tools/gen_vo.py --intro`). Each line may carry a
  `cue`.
- `IntroPanel.gd` plays the lines in order (falling back to OS TTS per line if a clip is missing)
  and fires cues at the matching moment:
  - **`reveal_rails`** → `LandscapeShell.begin_intro_hold()` — the soil recedes and the shelves
    brighten in as the narrator says “your star shelves are hiding under the soil… here they come!”
    The tiles show their **dim/locked** look (undiscovered), so the child sees they light up only by
    finding stars.
  - **`hide_rails`** (last line) → `LandscapeShell.end_intro_hold()` — shelves tuck back under the
    soil, reinforcing “touch a side any time to peek.”
- `begin_intro_hold()` sets `_intro_hold`, which suspends the 5 s auto-occlude so the rails stay up
  for the whole explanation; `end_intro_hold()` clears it and re-occludes. Reveal/occlude tweens use
  `TWEEN_PAUSE_PROCESS` because the intro pauses the tree.
- `IntroPanel._finish()` also calls `end_intro_hold()` defensively, so the shelves always end tucked
  away (soil default) even if the intro is skipped for capture.

---

## 7. In-world collection feedback

When the player ant collects a star (existing dwell / tap-star flow):

1. Play **shrivel** on the world marker (scale down + desaturate + disable input).
2. Emit / handle `star_collected`.
3. Corresponding rail tile **pops** from Undiscovered → Collected (scale punch + color).
4. Soft SFX (Kenney UI click is fine). No blocking modal.

Collected in-world stars must **not** be actionable again (save-backed).

---

## 8. Files & hooks (current codebase)

| Piece | Where |
|-------|--------|
| Main shell | `game/scenes/Main.tscn`, `scripts/world/Main.gd` |
| World / camera | `game/scenes/World.tscn`, `scripts/world/World.gd` |
| Star data | `game/data/stars.json`, `scripts/content/StarDB.gd` |
| World markers | `scripts/world/StarMarker.gd`, `scenes/Star.tscn` |
| Video playback | `scenes/ui/VideoPanel.tscn`, `scripts/ui/VideoPanel.gd` |
| Collection save | `scripts/autoload/Save.gd`, `Events.star_collected` |
| Old corner UI | `scenes/ui/StarProgress.tscn` — replace or slim once rails land |
| Display settings | `game/project.godot` `[display]` — revisit stretch/aspect for shell |
| VO loader | `scripts/content/VoStream.gd` (raw WAV OK) |

New scenes/scripts (suggested names — Fable may rename):

- `scenes/ui/LandscapeShell.tscn` + `scripts/ui/LandscapeShell.gd`
- `scenes/ui/StarRail.tscn` + `StarRailTile.gd`
- `assets/ui/star_tiles/` (placeholders)
- `data/star_rail_vo.json` (+ optional gen via `tools/gen_vo.py` pattern)

---

## 9. Acceptance checklist (done when…)

*Implemented in `scripts/ui/LandscapeShell.gd` + `StarRailTile.gd`, driven by pure helpers
`StarRailLayout` / `StarRailModel` / `DoubleTapArm` (all unit-tested headless:
`tests/test_star_rail_layout.gd`, `test_star_rail_model.gd`, `test_double_tap_arm.gd`,
`test_landscape_shell.gd`; 566 logic tests green). Boxes marked `[x]` are code-complete and
test-covered; ⧗ = needs a on-device / windowed **visual** pass (headless can't render here).*

- [x] ⧗ On fogona landscape, playfield is **centered**; world does not own the side gutters
      (`project.godot` stretch `aspect=keep`; opaque rail/soil columns cover the gutters; center
      Control is `MOUSE_FILTER_IGNORE` so world taps still pass through).
- [x] ⧗ **Silver border** always present between playfield and left/right columns (rails **or** soil).
- [x] **6 left + 6 right** star slots always exist when rails shown; grey + ~86 % scale until collected.
- [x] Collecting an in-world star pops the matching rail tile (listens `Events.star_collected`);
      in-world **shrivel** stays with the existing `StarMarker` flow (Phase 5).
- [x] Undiscovered rail tap → guidance VO only (no video).
- [x] Collected rail: first tap → “Tap again to watch…”; second tap within **1.0 s** → fullscreen
      video; timeout re-arms (`DoubleTapArm`).
- [x] Rails **occluded by bright brown soil by default**; touching a side reveals/brightens them
      (discovered vs undiscovered variation kept); auto re-occlude after 5 s (§6, revised model).
- [x] Reveal mechanic **explained in the intro narration**: sides start as soil, brighten in on the
      `reveal_rails` cue while the narrator explains stars unlock by discovery, then tuck back under
      the soil (§6.1; `IntroPanel.gd` + `begin/end_intro_hold`).
- [x] VideoPanel still one-decoder-at-a-time; rails sit on layer 12 (below VideoPanel’s 20) and
      ignore taps while a video is open (`_video_is_open()` guard); big high-contrast **Back** button.
- [x] Touch targets ≥ 96 px (tiles `custom_minimum_size = 96×96`); no reading required beyond spoken VO.

---

## 10. Out of scope for this UX pass

- Buying/wiring Sprout Lands terrain autotiling (separate track; soil columns can be simple
  tiled brown placeholders).
- Regenerating documentary trims (`build_stars.sh`).
- Changing colony sim tick logic.
- DALL·E / cloud image APIs (unless Dylan asks); placeholders first.

---

## 11. One-sentence brief for the implementing agent

**Build a landscape shell with a centered playfield, permanent silver borders, and 6+6 star rails
that grey→color on collect; double-tap (1 s) a collected tile to play its video; double-tap (1 s)
chrome to hide rails into bright brown soil; keep the wide 1600×720 kiosk composition calm and
thumb-first.**

*Owner: Fable (UX). Product: Star Learner / Ant Explorer. Path: `star_learning/ant_explorer/`.*
