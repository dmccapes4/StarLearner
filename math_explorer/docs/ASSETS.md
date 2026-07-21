# Math Explorer — Asset plan

**Principle:** the *math* manipulatives (cubes, buckets, coins, clock) are drawn
**procedurally** — no external files, tiny APK, no texture-load spikes. Story
characters/props come from **CC0 packs** (extracted below) or are **agent-generated**
flat art with keyed transparency. And because every question is **procedurally
generated** (`MathProblemGen.gd`), a small art set covers unlimited problems.

## On disk: `math_explorer/assets/` (source library, ~15 MB)

Extracted from the maintainer's downloads. This is the **source** library; curate
individual sprites into `game/images/story/` (recolour/crop) as each problem is
built — keep the Godot `game/` tree lean.

| Folder | What's useful | License |
|---|---|---|
| `chickens/` (+ `gifs/`) | Chicken sprite sheets — white, light-brown, dark-brown, black + Feed/Rest/Run/Strut gifs. **The egg-problem chickens.** | check pack (pixelplant) |
| `eggs_onocentaur/` | 350+ eggs: Brown, Colorful, Blue/Green/Red/Yellow, grayscale, alphanumeric. **The eggs.** | see `ABOUT.txt` |
| `eggs_onocentaur_backgrounds/` | Nest/incubator backgrounds for eggs. | see pack |
| `solaria_farm_animals/` | Higher-fidelity farm animals incl. white/blue chickens (Idle/Peck/Walk/Sleep). Aseprite + PNG. | see pack (demo/full) |
| `kenney_board-game-icons/` | 250+ icons: dice, **tokens**, timers, hands, resources. | **CC0** |
| `kenney_boardgame-pack/` | Board pieces / tokens. | **CC0** |
| `kenney_farm-expansion/` | Crops, crates, greenhouse tiles (barnyard dressing). | **CC0** |
| `kenney_rolling-ball/` | **Number sprites 0–9**, juice particles, buttons. | **CC0** |
| `kenney_platformer-blocks/` | Blocks in 4 recolourable colours (alt cube art). | **CC0** |
| `lpc-food/` | Fruit/veg/eggs that fit crates & baskets. | **CC-BY / CC0 mix — attribution for some** |

> ⚠️ Kenney = reliably CC0 (no attribution needed). The itch.io / OpenGameArt
> packs (chickens, eggs, Solaria, LPC) **vary** — verify per pack before shipping
> and keep a `CREDITS.md` for any that require attribution (LPC does for some tiles).

## Draw procedurally (no art needed)

| Thing | Why procedural |
|---|---|
| Counting cubes | `CubeGroup.gd` — done. |
| Buckets (×, ÷) | rounded `StyleBoxFlat` containers. |
| **Coins** (penny/nickel/dime) | no denomination art in the packs (only generic tokens); circles + value labels are clearer and recolourable. |
| **Clock face** | **no clock art** — a circle + ticks + two tweenable hands is crisper and animatable. |
| `+ − × ÷ =` | font labels (done). |

## Generated story set — `game/images/story/` ✅

A cohesive **flat-vector storybook** set (matching the astronaut/tile look),
generated then magenta-keyed + autocropped by `tools/key_sprite.py`. These are the
ones the game actually loads (via `StorySprites.gd`); tags are verified against
generators in the tests. Contact sheet: `docs/screenshots/story_contact.png`.

| File | Used by |
|---|---|
| `chicken_white.png`, `chicken_yellow.png` | `eggs_rate` |
| `egg.png`, `carton_open.png`, `carton_closed.png` | `eggs_rate` (carton snaps shut) |
| `doll.png`, `basket.png` | `share_dolls` |
| `piggy_bank.png` | `coins_make` (source purse) |
| `stone.png` | `paint_rate` (painted = same art, tinted at runtime) |
| `painter_kid.png` | `paint_rate` |
| `train_a.png` (red steam), `train_b.png` (blue bullet), `station.png` | `trains_gap` |

**To regenerate/add:** produce the art on a flat `#FF00FF` background, then
`python3 tools/key_sprite.py SRC.png game/images/story/NAME.png`.

## Still procedural (no file, on purpose)

Drawn in-engine, mapped to `""` in `StorySprites.gd`: **coins** (penny/nickel/dime),
**counting cubes**, the **clock face**, the **rail track**. The kiosk tile
`game/images/tile_math.png` (four coloured `+ − × ÷` cubes) is also done.

## Optional video cutaways

If a concept wants a real-world moment (real chickens, a real steam train, a real
clock), ingest a short YouTube clip to `.ogv` like Solar/Ant (`yt-dlp` + `ffmpeg`,
Theora), 1–2 min, into `game/videos/`. Not required for the core loop.
