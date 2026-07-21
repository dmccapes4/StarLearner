# Math Explorer

A Star Learner title that makes math **visible**. Every number is a set of things
you can count; every answer is narrated and animated; wrong answers are re-shown,
slower — never just marked wrong. Built for a six-year-old who's learning math and
finding it hard.

> The full design is in [`docs/STRATEGY_MATH_EXPLORER.md`](docs/STRATEGY_MATH_EXPLORER.md).
> A review of the working set (with fresh screenshots) is in
> [`docs/REVIEW_BASIC_MATH_SET.md`](docs/REVIEW_BASIC_MATH_SET.md).

![Card](game/docs/screenshots/00_card.png)

## The flow

1. **Seven tabs across the bottom** — the four operations (`+` `−` `×` `÷`) as
   rounded coloured squares, plus three **game tabs** with their sprites:
   **chickens** (egg-packing), **trains** (the race), **coins** (make the
   amount). The active tab glows gold.
2. **Operation card** — a big symbol tile, the name, a worked example, and two
   buttons: **Practice ▶** (endless generated equations with counting cubes) and
   **Watch the tutorial ▶**. The **first** Practice tap on a tab plays its block
   tutorial first (tracked in `user://seen.cfg`), so she is never dropped in cold.
3. **Block tutorials for every operation** — the same cube language throughout
   (gold ring = counting now, dull = counted): addition counts on `7 + 4`;
   subtraction takes 4 from 7 and counts what's left; multiplication counts 3
   groups of 4; division deals 9 cubes into 3 buckets. All narrated. **Tap to
   skip.**
4. **☰ Math Concepts Library** (top-left) — the four block tutorials on top,
   then the games, then concept videos (the animated chickens & trains runs).

![Counting](game/docs/screenshots/01_tutorial.png)

## Run it

From `game/` (Godot 4.3):

```bash
# Play it on the desktop
godot --path .

# Headless tests (data integrity + every script compiles)
godot --headless --path . -s res://tests/run_tests.gd

# Regenerate the screenshots above
DISPLAY=:0 godot --path . -s res://tools/capture_shots.gd
```

## Procedural problems

Every question is **generated**, never hand-written (`MathProblemGen.gd`). A
template takes a seed and emits `{prompt, steps, answer, params, subjects}` with
fresh numbers — so a *small* art set covers *unlimited* problems, and your daughter
meets each idea in many outfits. Ten generators today: `count_add`, `take_sub`,
`groups_mul`, `share_div`, `eggs_rate`, `coins_make`, `share_dolls`, `paint_rate`,
`trains_gap`, `clock_elapsed`. Every generated answer is re-derived from `params`
in the tests, so a bad formula fails CI (1300+ checks).

One of the harder, prettier ones — **two trains**:

> Train A leaves 1 hour early at 30 mph; Train B leaves later at 50 mph. After
> 4 hours, how far ahead is Train B? → `A: (4+1)×30 = 150`, `B: 4×50 = 200`,
> **ahead = 50 miles** (and B *catches* A after 1.5 h). Animated on parallel
> tracks so you literally watch the faster train eat the gap and pull ahead.

## The games (their own tabs)

**Chickens & eggs** (chicken tab). **Play ▶** is the interactive version
(`EggsDragScene`) — drag each hen's eggs into her nest (the nest goes gold when
it holds the right number), then drag the day's eggs into cartons that snap shut
when full. **Watch how it works ▶** plays the animated walkthrough
(`EggsScene`); the first Play also shows it once so the game explains itself.
Hens lay 1 or 2 eggs a day (like real hens), and the two colours always lay
*different* amounts.

![Chickens and eggs](docs/screenshots/06_eggs_cartons.png)
![Drag the eggs](game/docs/screenshots/07_eggs_drag.png)

**Two trains** (train tab). A red steam engine leaves first (slower); a blue
bullet leaves later (faster), visibly eats the head start, flashes **★ Caught
up!** as it passes, and pulls ahead. The run ends on a **question** — three mile
buttons, "How many miles ahead is Blue?" — before the reveal, so it's a game,
not just a movie.

![Two trains](docs/screenshots/04_trains_done.png)

**Coin counter** (coin tab). Pennies, nickels and dimes in a purse; she drags
coins into the tray to *make the amount*, with the running total spoken. Going
over bounces the coin back with a hint; exact is a win and a fresh target.

The animated scenes auto-play with narration and **tap-to-skip**; numbers come
from the generators (trains clamp to stay on-screen; eggs clamp to stay
countable).

## Big Kid Ideas (planned)

An unlockable track that plants **calculus / differential-equation intuitions**
(rates, accumulation, bottlenecks, equilibrium) as one-knob toys — no symbols,
just pictures that move. Includes a simplified take on the ice-cream-shop
staffing problem. Full plan and verdict in
[`docs/ADVANCED_CONCEPTS.md`](docs/ADVANCED_CONCEPTS.md).

## Assets

A cohesive **flat-vector story-sprite set** lives in `game/images/story/` — the
chickens, egg + cartons, doll + basket, piggy bank, stone, painter kid, and the
two trains + station — generated to match the console's storybook look and
magenta-keyed to transparency (`tools/key_sprite.py`). The game resolves them via
`StorySprites.gd`; math manipulatives (cubes, coins, clock, track) stay
**procedural**. A larger source library of CC0 / licensed packs sits in `assets/`
as alternates. See [`docs/ASSETS.md`](docs/ASSETS.md).

![Story sprites](docs/screenshots/story_contact.png)

## What's built vs. planned

- **Built:** seven-tab shell (4 ops + 3 games), block tutorials for **all four
  operations** (`AdditionTutorial`, `BlockTutorial`), **Practice mode**
  (`PracticeScene`: endless generated equations, wrong answers re-counted
  slowly), first-time-tutorial gating, the ☰ Math Concepts Library, the
  procedural problem generator (`MathProblemGen`, 10 templates), the
  story-sprite set (`StorySprites`), the **chickens & eggs** game (animated
  `EggsScene` + draggable `EggsDragScene`), the **two trains** race with its
  end-of-run question (`TrainsScene`), the **coin counter** (`CoinsScene`),
  baked ElevenLabs narration, headless tests, demo videos, the Android APK, and
  the kiosk tile with its ▶ explainer chip.
- **Planned (specced in the strategy doc):** the remaining scenes (sharing
  dolls, painting stones), a time-math thread (clock face, elapsed time,
  rates), and the **Big Kid Ideas** track
  ([`docs/ADVANCED_CONCEPTS.md`](docs/ADVANCED_CONCEPTS.md)).

## Design notes

- **Manipulatives are procedural** (drawn, not imported): tiny APK, no texture
  spikes. Story-character art comes from CC0 packs or agent-generated flat art —
  see [`docs/ASSETS.md`](docs/ASSETS.md).
- **Narration is a baked ElevenLabs voice** (warm Matilda, same as the other
  Star Learner titles). Each sentence is a WAV in `game/audio/vo/` keyed by md5
  of its text; dynamic lines stay covered because scenes draw numbers from a
  fixed `SEED_POOL` and `tools/dump_vo_lines.gd` enumerates every possible
  sentence for `tools/gen_math_vo.py` to bake. A CI test fails if any narrated
  sentence lacks a clip. OS TTS is only a fallback, still behind the Solar
  crash fix (3.5 s warmup gate; never probe `tts_get_voices()`, which returns
  null and crashes the process on Godot 4.3).

## Layout

```
docs/                          strategy + asset plan + reviews
tools/                         gen_math_vo.py (ElevenLabs bake) / key_sprite.py
game/
  project.godot  icon.svg
  scenes/Main.tscn
  scripts/  Main / TabBar / MathTheme / MathData / Narrator / VoStream / NarratorVoice
            CubeGroup / AdditionTutorial / BlockTutorial / PracticeScene
            MathProblemGen / StorySprites
            TrainsScene / EggsScene / EggsDragScene / CoinsScene
  audio/vo/                    baked ElevenLabs clips (md5 per sentence)
  data/math_vo_manifest.json   every sentence the narrator can speak
  tests/run_tests.gd
  tools/  capture_shots.gd / dump_vo_lines.gd
  docs/screenshots/
```
