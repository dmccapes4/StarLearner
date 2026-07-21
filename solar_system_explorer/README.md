# Solar System Explorer

**Game #2 in the [Star Learner](../README.md) catalog** — a calm, guided tour of the Sun and its
planets for a young child, with a full 3D flyer loop (plot → fly → orbit).

- **Engine:** Godot **4.3** (Mobile renderer), landscape 1280×600, offline-first.
- **Assets:** bodies + orbits drawn procedurally; narration is the same warm baked ElevenLabs
  voice as Ant Explorer (`tools/gen_solar_vo.py` → `game/audio/vo/`). Image assets in
  `game/images/` — astronaut girl, ship marker, keyed cockpit (`cockpit.png`), and procedural
  planet skins under `images/planets/` (see [`docs/STRATEGY_3D_FLYER.md`](docs/STRATEGY_3D_FLYER.md)
  and [`docs/STRATEGY_SOLAR_SYSTEM_NAVIGATION_EXPERIENCE.md`](docs/STRATEGY_SOLAR_SYSTEM_NAVIGATION_EXPERIENCE.md)).
  Each body has a **real 1–2 minute `.ogv` clip** in `game/videos/` (see below).
- **Package:** `com.dylan.antexplorer.solar` · tile `tile_solar` · label **planets**.

## The flow

1. **Title → START.** A star-field title screen with one big START button.
2. **Orrery (top-down).** The Sun with the eight planets tracing flattened ellipses, plus the
   **asteroid belt** as a scattered ring between Mars and Jupiter. A voice walks the tour
   (Mercury → Mars → asteroid belt → Jupiter → Neptune) naming a couple of facts, highlighting the
   one it's on. A **Skip ▶** jumps ahead; **◀** returns home.
3. **Astronaut briefing.** A cartoon astronaut girl (helmet under one arm, waving) in front of her
   spaceship, with a spoken *"you are an astronaut…"* briefing. The overlay fades out to reveal the
   fly screen underneath. **Tap to skip.**
4. **3D flyer (default).** The original **horizontal ScrollView** strip (now with rotating planet
   skins) — swipe, tap a world, watch the ship glide over. Then a **top-down** board charts the
   intercept course. Cockpit flight with skinned spheres, course console, callouts, and **orbit**
   on arrival. **Learn more** (optional video) or **Chart a new course** back to the strip.
   Design: [`docs/STRATEGY_3D_FLYER.md`](docs/STRATEGY_3D_FLYER.md).
5. **Body video (optional).** From orbit, **Learn more** plays `res://videos/<id>.ogv`. Big **◀**
   Back; the clip auto-closes when it finishes. Missing clips fall back to a spoken **"video coming
   soon"** facts card. You can skip videos and keep cruising.

![Title](game/docs/screenshots/01_title.png)
![Orrery tour with asteroid belt](game/docs/screenshots/02_orrery.png)
![Astronaut briefing](game/docs/screenshots/03_astronaut.png)
![Piloting strip with ship marker](game/docs/screenshots/04_scroll.png)
![Body video clip](game/docs/screenshots/05_video.png)

## Run & test

```bash
cd game
godot --path .                                            # play (needs a display)
godot --headless --path . -s res://tests/run_tests.gd     # logic tests (data + layout + compile)
DISPLAY=:1 godot --path . -s res://tools/capture_preview_shots.gd   # regenerate screenshots
DISPLAY=:1 godot --path . -s res://tools/make_tile.gd              # regenerate the launcher tile
```

`tests/run_tests.gd` also force-loads every view script, so a compile error anywhere fails the run
(headless can't render the scenes themselves).

### 3D flyer scale knobs (phase 4)

Defaults live in [`game/data/solar_flyer_config.tres`](game/data/solar_flyer_config.tres)
(`cruise_speed`, `focus_dist`, LOD band, hop duration band). `ScaleTune` asserts the happy-medium
contracts in tests. To tweak on the phone without rebuilding the APK, push a JSON overlay:

```bash
adb push tools/solar_flyer.json /sdcard/AntPhone/solar_flyer.json
# also accepted: /data/local/tmp/solar_flyer.json  or  user://solar_flyer.json
```

The next hop reloads knobs (`PlotBoard.begin` / `FlyScene.begin_flight`).

## The 1–2 minute videos (ingested)

Built with the same shape as Ant Explorer's `build_stars.sh`: a TSV manifest
([`tools/solar_bodies.tsv`](tools/solar_bodies.tsv), columns `id / start / end / url`) fed to
[`tools/build_clips.sh`](tools/build_clips.sh), which `yt-dlp`-downloads the source once (cached
under `tools/build/sources/`) and `ffmpeg`-cuts one Theora `.ogv` per body into `game/videos/<id>.ogv`.
IDs match [`game/scripts/SolarData.gd`](game/scripts/SolarData.gd) (`sun` … `asteroid_belt` … `pluto`).

```bash
tools/build_clips.sh                 # all bodies → game/videos/<id>.ogv
tools/build_clips.sh --id saturn     # re-cut one (source stays cached)
tools/build_clips.sh --force         # rebuild everything
```

**Source:** each body is two segments concatenated by `build_clips.sh` (same `id` on consecutive
TSV rows): a short (~10–12 s) real / NASA “alive” opener, then the VectorGlobe explainer beat from
*"The Solar System Explained (2026)"* (`youtube.com/watch?v=1wyr5rWonbE`). Openers are mission
footage (SDO, MESSENGER, Magellan, DSCOVR, Perseverance, Dawn/Ceres, Juno, Cassini, Voyager, New
Horizons). Credit VectorGlobe for the explainers; private family device posture. Explainer lengths
track the source beats (~55–77 s planets; short asteroid-belt / Pluto tails).

**Note:** the eleven clips bake into the game APK (~190 MB APK with video). To shrink, lower
`libtheora -q:v` in `build_clips.sh`, or push `game/videos/` to the device out-of-band
(`adb push`) instead of embedding.

**Ingest prerequisite:** modern YouTube needs a JS runtime for `yt-dlp`'s challenge solver. Install
[Deno](https://deno.land) user-local (`curl -fsSL https://deno.land/install.sh | sh`) and ensure
`~/.deno/bin` is on `PATH`; the `.ogv` cutting itself only needs `ffmpeg` (with `libtheora` +
`libvorbis`).

## Shipping it to the Star Learner unit

The device work mirrors Ant Explorer (see `../ant_explorer/docs/STRATEGY_ANT_PHONE_UPDATES.md`):

1. Install the Godot **Android build template** into `game/` once (editor: *Project → Install
   Android Build Template*), then build/sign with [`tools/build_solar_apk.sh`](tools/build_solar_apk.sh)
   (produces `com.dylan.antexplorer.solar.apk`).
2. The launcher is already wired: a **planets** tile (`tile_solar`) and a catalog entry were added to
   `ant_explorer/kiosk_placeholder` (baked `assets/catalog.json`) and to the deploy staging copy
   `ant_explorer/tools/catalog.json`. Rebuilding the launcher APK shows two tiles; until the game
   APK lands, the tile toasts *"not installed yet"* (kid-safe).
3. `adb install -r com.dylan.antexplorer.solar.apk` + push the updated `catalog.json` — done.

## Status / honesty

Honesty notes:

- Narration is the same warm baked ElevenLabs voice the ants use (`tools/gen_solar_vo.py`
  bakes every possible sentence — including dynamic trip/arrival lines — to
  `game/audio/vo/`; OS TTS remains only as a fallback for unbaked text).
- Sizes and orbits are **not to scale** — chosen to read for a six-year-old, not for accuracy.
- The Sun is a hop destination, but arrival parks at a safe standoff — narration says you can't
  land on a star.
- The clips are third-party YouTube footage cut for the private family device; re-source from
  public-domain NASA before any wider distribution.

What it proves: a second, different-subject title boots into the same landscape shell, uses
the same video mechanic (real cut-and-transcoded `.ogv` clips, Sun through Pluto plus the asteroid
belt), and appears as its own tile on the console — the multi-game claim, made concrete.
