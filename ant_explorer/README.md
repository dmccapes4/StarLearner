# Ant Explorer

> *A birthday present for my daughter whose fascination with ants inspires me.*

**Ant Explorer** is a calm, exploratory leaf-cutter ant colony simulator for a six-year-old.
You control one worker ant in a living nest: tap the ground to walk, follow glowing pheromone
trails to join colony jobs, and stop beside golden **knowledge stars** to watch short offline
ant documentaries. Exploration is the loop; learning is the reward.

Ant Explorer is **Game #1 in the [Star Learner](../README.md) catalog** — the homemade educational
game console. This README covers the game and its developer workflow; the catalog README has the
product overview and how a Star Learner unit is built. See also [`../NAMING.md`](../NAMING.md).

- **Engine:** Godot **4.3** (Mobile renderer), landscape, offline-first.
- **Assets:** Sprout Lands tileset · Kenney UI/fonts · baked ElevenLabs narration · Theora (`.ogv`)
  documentary clips.
- **Target hardware:** Moto G Play 2024 (1600×720, Snapdragon 680, 4 GB) — hard cap ~90–100 ants.

## The game

- **Move:** tap a spot; the ant walks there, routing room → tunnel → room along the nest graph.
- **Join a job:** tap a glowing pheromone trail to take on that role (forage, garden, nurse,
  defend, …) alongside the NPC ants.
- **Learn:** walk up to one of the **12 golden stars** hidden in the nest. Stopping beside it
  plays a short (1–4 min) documentary, then that star lights up on the side shelf. Collect all 12.
- **No reading required:** every prompt is spoken; targets are large and thumb-first.

## Screenshots

**Nest doorway — star shelves under the soil.** The default look: both side shelves are tucked under bright brown soil (with a faint star hint). Touch a side — or watch the intro narration — to reveal them.

![Star shelves tucked under the soil, ant at the nest doorway](docs/screenshots/01_rails_soil.png)

**Nest doorway — star shelves revealed.** Collected stars glow in full colour; still-locked ones stay dim until you find their golden star in the nest.

![Star shelves revealed with a mix of collected and locked stars](docs/screenshots/02_rails_revealed.png)

**Fungus garden.** A cultivated chamber where gardener ants tend the fungal crop.

![Fungal garden chamber with tending ants](docs/screenshots/03_garden.png)

**Outdoor foraging surface.** The sunny world above the nest where foragers cut and carry leaves.

![Outdoor foraging surface swarming with foragers](docs/screenshots/04_surface.png)

**Whole-colony overview.** The full nest — chambers (queen's room, nursery, gardens, dump, deep tunnels…) linked by uniform dark-brown soil tunnels. Rail UI hidden and the empty sides trimmed for a clean colony map.

![Colony-wide overview of all nest chambers linked by tunnels](docs/screenshots/05_nest_overview.png)

## The colony simulation

A dramatically simplified but living leaf-cutter nest, driven by a fixed-rate `SimClock`
(separate from rendering) so behaviour is deterministic and testable.

- **Chambers:** queen's room, nursery, pupa room, two fungal gardens, dump, soldier outpost,
  deep tunnels, entrance, and an outdoor surface — a graph of nodes joined by tunnels.
- **Castes & roles:** one queen, soldiers, foragers/media, minor gardeners/nurses, plus **brood**
  (larvae + pupae). Ants run small finite-state machines (idle → walk trail → do job).
- **Larval space / brood dynamics:** eggs → larvae → pupae → eclosion into the appropriate caste;
  older workers age, die, and are carried to the dump. Population self-stabilises around the
  fungal garden's health.
- **Fungal garden economy:** foragers deposit leaf fragments, gardeners tend the fungus, brood is
  fed on it; garden health feeds back into brood survival and overall activity.
- **Invaders:** occasional enemy incursions at the entrance; soldiers respond, and the player can
  join the defense trail.

Full write-up: [`docs/REPORT_SIMULATION.md`](docs/REPORT_SIMULATION.md).

## Knowledge stars & the side shelves

The twelve documentaries are surfaced through a **landscape shell**: a centered playfield framed by
permanent silver borders, with **6 star shelves on the left and 6 on the right** (order frozen for
the product's life).

- **Occluded by default.** The shelves sit hidden under bright brown soil (with a faint star hint),
  so the calm dirt stage is what a child sees first.
- **Touch to reveal.** Touching a side brightens/fades the shelves in and makes the tiles tappable;
  they keep the **dim (locked) vs. full-colour (collected)** distinction. With no interaction they
  tuck back under the soil after 5 seconds.
- **Tap to watch.** On a collected tile, the first tap says "Tap again to watch the … video"; a
  second tap within ~1 s plays it fullscreen. Tapping a still-locked tile says "Tap again to reveal
  star location"; a second tap within 3 s sends the camera to that star so she can tap it and walk
  there (or the camera returns if she waits).
- **Taught in the intro.** The launch narration explains all of this: the sides start as soil,
  brighten in while the narrator says the shelves are hiding there, and the child hears that stars
  light up only by finding them in the nest — then the shelves settle back under the soil.

Design + acceptance detail: [`docs/STRATEGY_LANDSCAPE_STAR_RAILS.md`](docs/STRATEGY_LANDSCAPE_STAR_RAILS.md).

## Narration & audio

All narration is **baked offline** (no runtime cloud calls) and loaded raw at runtime by
`VoStream`, so fresh WAVs work without a Godot import pass. If a clip is ever missing, the game
falls back to the OS text-to-speech voice.

- **Intro:** one clip per line in `game/assets/audio/vo/intro/`, played in order with visual cues
  (`reveal_rails` / `hide_rails`) that choreograph the shelves.
- **In-world:** per-role, per-chamber, per-star, and per-trail lines under `game/assets/audio/vo/`.
- **Voice:** a warm, calm female narrator (ElevenLabs; slightly slowed for a soothing cadence).

Regenerate audio with the pipeline below.

## Content pipeline

Two build scripts turn source material into offline assets. Both write into the Godot project and
avoid host `sudo` (see [`../../.cursor/rules/no-host-sudo.mdc`](../../.cursor/rules/no-host-sudo.mdc));
`yt-dlp` can be installed user-locally via `tools/install_yt_dlp.sh`.

**Documentary clips** — `tools/build_stars.sh`
Reads the `tools/stars.tsv` manifest (id, YouTube id, in/out timestamps), downloads with `yt-dlp`,
trims and transcodes with `ffmpeg` to Theora `.ogv` (+ `.mp4`), and writes to `game/stars/<id>.ogv`.
The game reads `game/data/stars.json`, which points at `res://stars/<id>.ogv`.

```bash
cd tools
./build_stars.sh            # all 12 stars
./build_stars.sh --force    # rebuild even if a clip exists
```

**Narration** — `tools/gen_vo.sh` (ElevenLabs; key in `tools/secrets/elevenlabs.env`, gitignored)

```bash
cd tools
./gen_vo.sh                 # roles + chambers + intro + stars + trails
./gen_vo.sh --intro         # just the intro sequence
./gen_vo.sh --ogg           # also emit .ogg alongside .wav
```

## Run & test

```bash
godot --path game                                        # play
godot --headless --path game -s res://tests/run_tests.gd # 560+ headless logic tests
```

## Recapture screenshots

Needs a real display (not `--headless`). The capture script boots `Main.tscn`, grabs the soil and
revealed shelf states (with a mix of collected/locked stars) plus world and colony-overview views,
and auto-trims the empty background sides of the overview.

```bash
cp tools/capture_readme_shots.gd game/capture_readme_shots.gd
DISPLAY=:1 godot --path game -s res://capture_readme_shots.gd
rm game/capture_readme_shots.gd
```

Frames land in `docs/screenshots/`.

## Running on a Star Learner unit

The game ships as an Android APK on a rooted, kiosk-locked device (Magisk root, forced landscape,
a minimal launcher showing the **ants** tile, status bar / gestures disabled). Documentary and
audio assets live in on-device storage. How a Star Learner console is built and locked down lives
in the catalog README and the kiosk doc:

- Console overview & catalog: [`../README.md`](../README.md)
- Appliance & kiosk setup: [`docs/KIOSK_APPLIANCE.md`](docs/KIOSK_APPLIANCE.md)
- Launcher stub sources: [`kiosk_placeholder/`](kiosk_placeholder/)

## Repository layout

| Path | What |
|------|------|
| `game/` | Godot project (scripts, scenes, data, tiles, audio, star videos, tests) |
| `docs/` | Design notes, strategies, simulation report, screenshots |
| `tools/` | Video + VO generation, screenshot capture, kiosk / device helpers |
| `kiosk_placeholder/` | Android launcher stub for the appliance |

## Documentation index

- [`docs/OVERVIEW_ANT_EXPLORER.md`](docs/OVERVIEW_ANT_EXPLORER.md) — concept, design numbers, phases
- [`docs/REPORT_SIMULATION.md`](docs/REPORT_SIMULATION.md) — how the colony simulation works
- [`docs/STRATEGY_LANDSCAPE_STAR_RAILS.md`](docs/STRATEGY_LANDSCAPE_STAR_RAILS.md) — shelf/rail UX
- [`docs/STRATEGY_STAR_ANT_DOCUMENTARIES.md`](docs/STRATEGY_STAR_ANT_DOCUMENTARIES.md) — the 12 clips
- [`docs/BIBLIOGRAPHY.md`](docs/BIBLIOGRAPHY.md) — sources
- [`docs/IMPLEMENTATION_PLAN_ANT_EXPLORER.md`](docs/IMPLEMENTATION_PLAN_ANT_EXPLORER.md) — build plan
- [`docs/KIOSK_APPLIANCE.md`](docs/KIOSK_APPLIANCE.md) — device / kiosk setup
