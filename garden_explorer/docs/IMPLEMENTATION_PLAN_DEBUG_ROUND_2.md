# Garden Explorer — Debug Round 2 Implementation Plan

User debug list (2026-07-25) organized into phases. Item numbers reference the
original list.

## Phase 0 — Assets (user)
- Pixel Gnome: Bugs Pack (itch.io) → roaming bug sprites (item 6)
- Sprout Lands UI Pack premium (itch.io) → animal happy emotes (item 8)
- Agent-sourced: Pexels/Pixabay footage, Wikimedia/USDA seed + sprout photos,
  owned Sprout Lands premium house tilesets for shed rebuild.

## Phase 1 — Reveal tile timing + freeze (items 1, 2, 3)
- RevealTile: narration-first. Countdown starts when narration ends.
- During narration: dim-tap does NOT close; player frozen (Narrator lock already
  freezes walk; also freeze TapRouter world taps by swallowing on RevealTile).
- Window after narration: 5s (was 3s). All reveal timers = 5s (Config value).

## Phase 2 — Navigation fixes (items 7, 18)
- Follow-nav: no continuous repath. On tap: narrate "Walking to {name}." and
  path once to the animal's position; on arrive, if animal moved > eps, repath
  once more (max 2 legs), then open interaction where the animal now is
  (animal pauses at interaction anyway per item 8).
- Pen routing: pen interior nav cells connect to outside ONLY through the gate
  cell. Tap inside pen → route goes to gate, through it, then to target.
  Implemented in FarmMap._rebuild_nav edge wiring (fence line blocks
  neighbor links except at the gate gap).

## Phase 3 — Interaction character (items 4-intro, 8, 9)
- Upbeat intro: "This is {name}! {He/She} is a {kind}. Tap to learn more about
  {kind}s on farms." (animals.json gains "gender"; bugs keep species line.)
- Animal pauses during whole interaction, faces player, happy hop + heart
  emote (UI pack, fallback: generated heart) while reveal is open.
- Bug pauses during interaction; disappears after (caught).

## Phase 4 — Roaming catchable bugs + collection (item 6)
- BugSpawner: every 20–45 s, up to 2 concurrent bugs, weighted by habitat
  (bed_x → bed-weighted bugs, pen/coop → soil bugs, shed → spiders/pillbugs,
  grass → grasshopper/butterfly/bee/ant). Bug walks a small wander for ~60 s
  then despawns.
- Tap roaming bug → walk to it → bug reveal (same flow) → after interaction
  "You caught a {bug}!" → BugGrid panel (12-slot grid, grey silhouettes until
  caught, bright + gold outline when caught) → save caught set in Save.
- Sprites: Pixel Gnome pack when dropped in; interim = downscaled portraits.

## Phase 5 — UI / map polish (items 12, 13, 14, 15)
- 12: remove grey slot polygons; replace with darker-brown iso diamond inset
  per slot, no overlap, inside bed rim. UI validation test asserts slot
  markers project inside the bed top polygon.
- 13: shed rebuilt from Sprout Lands premium wooden house wall+roof tilesets,
  door centered on the south-east face, animated door sprites, path leads to
  door; approach point = door center.
- 14: generated "Seeds" tile image for shed action tile.
- 15: seed grid tiles: big sprite, label pinned bottom; silver outline =
  collected, gold outline = harvested-before; one-time narration explaining
  outlines on first seed collection.

## Phase 6 — Real media pipeline (items 4, 5, 10, 11, 16, 19)
- tools/fetch_stock_footage.sh: download curated Pexels/Pixabay clips
  (animals, bugs, harvest, coop eggs).
- tools/build_edu_videos.sh: trim/concat footage → overlay baked ElevenLabs
  narration (structure: what it is → fun fact → role in garden/farm →
  gentle outro) → .ogv into res://stars/.
- 10: first-seed video: real seed photo ("This is a real image of a/an {plant}
  seed.") → in-game growth art ("This is what the plant looks like as it grows
  in the game.") → when/where to plant + facts. No tap-exit.
- 11: first-harvest flow: freeze + no tap → "You harvested your first
  {plant}!" → PlantGrid panel (gold outline lights up) → real harvest video
  with narration → unfreeze.
- 16: sprout-stage Look shows real sprout photo card before/instead of clipart.
- 19: coop Look interaction → egg-collecting video with narration.
- Cleanup: delete placeholder animal_*.ogv / bug_*.ogv once replaced.

## Phase 7 — Seasons (item 17)
- Summer bright/clear; Fall dimmer + scattered leaf decals; Winter dimmest +
  occasional rain particles; Spring lively + flowers in grass.
- Season change: generated season card centered 5 s, no tap-close, player
  frozen; narration includes year; "Year X" caption under tile.
- Save tracks year (increments each Spring).

## Round 3 follow-ups (2026-07-25 pm)
- Concept videos: replaced the stage-progression series with real Commons
  footage (germination, heliotropism, harvest, timelapse growth) + baked
  ElevenLabs narration, parity with bug/animal clips. Concepts grid now
  tri-state: grey (locked) → silver (unlocked, unwatched) → gold (watched).
- Seasonal background music (Kevin MacLeod, CC-BY): spring=Wholesome,
  summer=Carefree, fall=Heartwarming, winter=Silver Blue Light. New autoload
  `Music.gd` crossfades on season change, pauses during full-screen/freeze
  panels (video, media, season card, grids, intro, reveal narration) and ducks
  low during short narration ("Walking to {animal}."). Credits in
  game/audio/music/CREDITS.txt.
- Dog sprite enlarged (scale 2.4 → 3.3, grounded offset) so it reads as a pet,
  not a rat, under the iso projection.
- Intro: removed the studio-presenter clip. `tools/build_intro_explainer.py`
  builds a friendly narrated explainer over real gameplay footage →
  game/stars/intro.ogv (played first launch, VideoPanel Back ◀) and
  docs/demo/garden_explorer_explainer.mp4. Removed the double-spoken welcome
  line so it no longer talks over the clip.
- Cleanup: deleted replaced game/stars/*.mp4 (old studio intro + concept
  series) and the obsolete make_animal_bug_videos.sh; added android/build
  .gdignore so gradle export copies no longer shadow global classes on import.

## Round 4 follow-ups (2026-07-25 eve)
- Planting UX: seed stays in hand; each tap on a plot square plants that plot
  (sequential, one per action) — no whole-bed autofill, no shed round-trips.
- Bed visuals: removed the grey EmptySlot overlays (PlantLayer) and the old
  grey slot diamonds. Beds are now a lighter wooden frame with a dark
  fresh-soil interior and two perpendicular furrow lines splitting the soil
  into four iso plot squares (tap targets).
- Dog: root cause of the "rat" — the dog spawns via RoamingAnimal with
  animals.json scale 1.25; the old 3.3 fix sat in never-instantiated
  RoamingDog.gd (deleted). Replaced the unreadable grey sheet with a hand-drawn
  golden puppy (4 dirs × 4 frames, floppy ears, red collar, wagging tail),
  scale → 1.5. Roaming verified: all 4 directions, 12 distinct frames sampled.
  Portrait regenerated to match (red collar).
- Demos: playthrough now plants all four bed_0 plots by tapping plot squares,
  then fills and grows all six beds ("beautiful garden" overview shot).
  Explainer narration updated (hold-a-seed planting, Buddy the puppy, fill all
  six beds); intro.ogv + explainer.mp4 rebuilt.

## Round 5 mechanics (2026-07-25 night)
- Game clock: garden growth + season timer freeze whenever the player is
  frozen — narration movement-locks and full-screen panels (videos, media,
  season card, celebration grids, intro). Routine actions (planting, shed
  browsing) keep time running. Shared logic in scripts/sim/GameFreeze.gd
  (World pauses the clock, Music pauses the track). Verified by
  tools/probe_time_freeze.gd.
- Watering: one Water action per bed — soaks every thirsty plot at once
  (sim showed per-plot watering made a full garden impossible at kid pace).
- Planting: no plot choice. Tap the bed → Plant fills the next empty plot in
  fixed order (back-left → back-right → front-left → front-right); tap again
  for the next plot.
- Bug fix: taps made during a narration lock used to die silently (Player
  dropped the path request). World now defers the walk until the lock
  releases.
- VO: baked the action-prompt confirm lines (Plant/Harvest/Pull out/Look ×
  32 plants, "Water the bed?", "What do you want to do?", "Not thirsty
  yet.") — 132 new ElevenLabs clips; these previously fell back to OS TTS.
- ux_suite: 38/38 green (was 26/36 — pre-existing failures from short waits
  racing the new narration locks + first-seed media). Suite now drains
  freeze panels, waits for logs instead of fixed settles, retries taps a
  roaming animal stole, and asserts per-bed watering.

## Round 6 — zone targeting (2026-07-26)
- Animal/bug interact is same-zone only: dog + garden bugs from the garden;
  pen animals + pen bugs only once the player is already inside the pen.
- Gate routing is separate: FarmMap.find_path concatenates garden→gate→pen
  (and the reverse) for cross-boundary walks. Same-side walks never visit
  the gate.

## Round 6b — remove tap-to-target chase (2026-07-26)
- Removed animal/bug follow repathing and "Walking to {name}." chase.
  Tap walks once to the critter's position at tap time, then opens the
  reveal on arrive. If they wander off, tap again.

## Round 7 — shed tools + per-bed growth (2026-07-26)
- Shed: supplies tile → four-tool modal (seeds / water / spade / return) with
  first-open gold-outline narration. Player carries the chosen tool sprite.
- Bed actions decided by tool: plant/water/uproot auto-apply; hands-free shows
  Bugs + Examine. Uproot is tile-gated confirm (game keeps running).
- Per-bed crop: one plant fills all four plots; water-then-wait stage advances;
  one water / harvest-ready icon above the bed. Harvest any tap when ready.
- Pen: brown sliding gate bar; stricter gate-only fence crossing; animal first
  meet → reveal, later SFX + double-tap within 2s for tile.
- Bug world sprites: generated PNGs under assets/bugs/; concept narration no
  longer stacks overlapping lines.

## Always
- Headless unit tests + ux_suite after each phase; rebuild APK & install last.
