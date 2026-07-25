# Garden Explorer

> *A calm gardening game for Star Learner — plant, water, grow, harvest, and collect knowledge stars.*

**Garden Explorer** is a wide-landscape **2D isometric** garden for a six-year-old. The child picks
seeds at the shed, tends six beds, visits animals at the fence, and unlocks **12 knowledge stars**
(hamburger menu, top-left) with short offline gardening videos.

Part of [Star Learner](../README.md) / [`../NAMING.md`](../NAMING.md).

- **Engine (planned):** Godot **4.3**, Mobile renderer, landscape, offline-first.
- **Aesthetic:** Sprout Lands / Stardew-like sprite pack.
- **Assets:** sprites · YouTube-trimmed clips · ElevenLabs narration.
- **Status:** Growth = water + time with thirst/harvest icons; ElevenLabs VO; two-tab Garden Library; SciShow Kids concept clips + lettuce plant media.

## Layout

| Left | Middle | Right |
|------|--------|-------|
| Shed (seeds + harvest storage) | 2×3 beds, 4 plants each | Fence + animals |

## Docs

| Doc | Purpose |
|-----|---------|
| [`docs/IMPLEMENTATION_PLAN_GARDEN_EXPLORER.md`](docs/IMPLEMENTATION_PLAN_GARDEN_EXPLORER.md) | Phased build plan |
| [`docs/BIBLIOGRAPHY.md`](docs/BIBLIOGRAPHY.md) | Video sources |
| [`game/data/seeds.json`](game/data/seeds.json) | Plant catalogue |
| [`game/data/stars.json`](game/data/stars.json) | 12 stars + intro |
| [`game/data/seasons.json`](game/data/seasons.json) | Seasonal seed subsets |
| [`tools/stars.tsv`](tools/stars.tsv) | Star / intro trim manifest |
| [`tools/plant_media.tsv`](tools/plant_media.tsv) | Per-plant media trim manifest |

## Run

```bash
cd garden_explorer/game
godot --path .                    # play
godot --headless --path . -s res://tests/run_tests.gd
```

## Play loop (Phase 5)

1. First launch: **START** intro (plays once).
2. Tap the **shed** → pick a seasonal seed; plant / water / harvest / uproot.
3. Seasons advance ~every 3 minutes; tap fence **animals** for VO.
4. **☰ Stars** — dim stars are revealed; tap → camera pans + gold outline; tap again → video + collect.
5. Gameplay unlocks more stars (plant, water, sprout, harvest, season, …).

### Bake star videos

```bash
cd garden_explorer/tools
./build_stars.sh              # → game/stars/<id>.ogv
./build_plant_media.sh        # → game/assets/plants/...
```

## Tests

```bash
cd ~/dev/star_learning/garden_explorer/game
godot --headless --path . -s res://tests/run_tests.gd

# Screenshots + event checks (uses $DISPLAY when set)
cd ~/dev/star_learning/garden_explorer
./tools/run_ux_suite.sh
# shots → game/docs/screenshots/ux/
```

## VO / APK / demo

```bash
./tools/gen_vo.sh                          # ElevenLabs → game/audio/vo/
./tools/build_garden_apk.sh                # → tools/build/com.dylan.antexplorer.garden.apk
./tools/make_demo_videos.sh                # → docs/demo/garden_explorer_playthrough.mp4
```

## Next

Ship APK to the second Moto when USB debugging is authorized.

```bash
python3 tools/make_tile.py   # → ant_explorer/.../drawable/tile_garden.png
```
