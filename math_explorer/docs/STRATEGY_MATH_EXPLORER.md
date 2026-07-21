# Math Explorer — Strategy

*A Star Learner title. Make math **visible**: every number is a set of things you
can count, group, share, and drag. Every answer is narrated and animated. Wrong
answers are never just "wrong" — they're re-shown, slower.*

> Audience: a six-year-old who is learning math and finding it hard. The whole
> design is built around that one child. Big touch targets, one idea on screen at
> a time, warm narration, no reading required to play (spoken + shown), and a
> "show me again" that always exists.

---

## 0. North star

The core insight the parent asked for: **numbers should be things, not symbols.**
`7` is *seven red squares you can point at*. `+` is *sliding two piles together
and counting on*. `×` is *equal groups*. `÷` is *sharing into buckets until they
run out*. The symbolic equation is built **on top of** the concrete picture, in
sync with the voice, so the abstract notation attaches to a physical memory.

**Everything is procedurally generated.** No question is a one-off. Each template
is parameterised over its *numbers* (and often its *actors* and *subjects*), so one
small art set yields effectively unlimited problems, and the child meets the same
idea in many outfits — which is exactly how understanding forms. `7 + 4` today,
`6 + 5` tomorrow; the same chicken sprite powers every egg problem forever. See §5
and `MathProblemGen.gd` (10 templates, every answer re-derived from params in the
tests).

Three modes, one content spine:

| Mode | What it is | Status |
|---|---|---|
| **Tutorials** | Guided, fully narrated + animated walkthroughs (the "aha" moments). | Addition built; rest specced below. |
| **Practice** | The same manipulatives, but *she* enters the answer. Wrong → explained. | Specced. |
| **Word problems** | Sprite-driven story problems (chickens, coins, dolls, painters). Drag-to-solve. | Specced. |

---

## 1. Shell & navigation

- **Four rounded-square tabs across the bottom** — `+` Addition, `−` Subtraction,
  `×` Multiplication, `÷` Division. Each tab has its own colour (red / blue /
  green / gold). The active tab gets a gold ring + glow. *(Built — `TabBar.gd`.)*
- Above the tabs, an **operation card**: a big coloured symbol tile, the name, a
  worked example (`e.g. 7 + 4 = 11`), and a gold **Watch the tutorial ▶** button.
  A second **Practice** button and a **Story problems** button sit alongside as
  those modes come online.
- **Landscape**, 1280×600, matching the Star Learner console. One-hand reachable.
- **`PREVIEW` badge** top-right (this ships as a preview tile, like Solar).

---

## 2. The counting-cube language (shared visual grammar)

`CubeGroup.gd` is the atom. A group is N rounded cubes with a **base colour** and,
per cube, a **highlight ring** used while counting:

- **CURRENT** — bright, thick ring + soft glow: the cube being counted *right now*.
- **DONE** — dull, medium ring: already counted.
- **NONE** — faint ring: not yet counted.

Ring **hue** carries meaning:
- **GOLD** = the group we're actively counting / the running total.
- **GREY** = the "other" group waiting its turn (the second addend, the amount
  being taken away, etc.).

This tiny grammar (bright=now, dull=done, gold=total, grey=waiting) is reused by
**every** tutorial and every practice problem, so the child learns to read the
screen once and it pays off everywhere.

Colours: red, blue, green (groups), grey (undistributed / neutral), gold (result).

---

## 3. Tutorial catalog

All tutorials share: equation builds up **as it is spoken**; manipulatives appear
**below the numerals**; counting uses the ring grammar; the answer lands and the
cubes **turn gold**. Each ends with a one-line recap and a **Replay** button. Tap
anywhere to skip to the finished frame.

### 3.1 Addition — `7 + 4 =` *(BUILT — `AdditionTutorial.gd`)*
1. "Let's add seven plus four." → `7` appears.
2. **7 red cubes** appear under the 7; narrator counts *one…seven*, current cube
   bright gold, counted cubes dull gold.
3. `+` appears; "plus"; then `4`; **4 blue cubes** appear under the 4, counted
   *one…four* with the **grey** ring.
4. `=` appears. "We already have seven, so we **count on**." The red cubes go DONE;
   we count the blue cubes as **8, 9, 10, 11** with the **gold** ring — the key
   idea: addition is counting on from the first number.
5. `7 + 4 = 11`. Every cube turns **gold**, the two piles **slide together** into
   one group of eleven. "Seven plus four equals eleven! Great counting."

### 3.2 Subtraction — `7 − 4 =` *(specced)*
Same opening (7 red counted gold). Then the twist the parent described: at the end
the **blue cubes are moved over the red cubes one at a time while counting** — i.e.
take-away. Start with 7 red; show `− 4`; then **4 red cubes are "covered"/removed**
one by one (grey ring on the one leaving, it fades/greys and slides off), narrator
counts the removals, and the **remaining** red cubes are re-counted gold: *one,
two, three* → `7 − 4 = 3`. Reuses `CubeGroup` + a "remove-and-slide" tween.

### 3.3 Multiplication — `3 × 4 =` *(specced)*
"Multiplication is **equal groups**."
- **3 rows on the left** (three groups). Count **4 red** in the first, **4 blue**
  in the second, **4 green** in the third (ring grammar per group).
- The groups slide to centre stacked with `+` between them:
  `4 red` / `+` / `4 blue` / `+` / `4 green` / `—`.
- **Sequential addition, cubes combining as we go:** `4 + 4 = 8` (red+blue merge
  into an 8-block) shown as worked side-work to the right; then `8 + 4 = 12`
  (merge in green). The right column keeps the tidy `4 + 4 + 4 = 12` form while the
  cubes physically combine on the left.
- `3 × 4 = 12`, all gold. "Three groups of four is twelve."

### 3.4 Division — `9 ÷ 3 =` *(specced)*
"Division is **sharing** into equal groups."
- Start with **9 grey cubes**; count all 9 (brighter-grey ring).
- Three buckets appear below: **red, blue, green**.
- Deal grey cubes **round-robin** into buckets — red, blue, green, red, blue,
  green… — each cube **changing to its bucket colour** as it lands (duller shade).
- When all are dealt: `9 ÷ 3 = 3` (each bucket has 3). The originals **reorganise**
  into 3 red / 3 blue / 3 green.
- Verify two ways, brightening each section as it's named: count *1,2,3 red;
  1,2,3 blue; 1,2,3 green = 9*, then `3 + 3 + 3 = 9`.

### 3.5 Division with a remainder — `10 ÷ 3 =` *(specced, quick follow-up)*
Same dealing; now **red gets a 4th** cube. "Everyone got three, but there's one
left over, and there are three buckets, so the answer is **3 and one-third**
(`3 ⅓`)." Introduces remainder → fraction gently, exactly as the parent framed it.

### 3.6 Rate & time tutorials *(specced)*
Common, concrete examples with sprites/animation:
- **Rate:** "Bobby paints 4 stones an hour, Sally paints 6. Together **10 an
  hour**." Animate an hour clock ticking; 10 stones get painted per tick; `20 ÷ 10
  = 2 hours`; then split the credit: Bobby `4 × 2 = 8`, Sally `6 × 2 = 12`.
- **Elapsed time:** a clock face with a sweeping hand; "It's 3:00. Soccer is in 2
  hours. What time?" Hand sweeps two hours → `3:00 + 2:00 = 5:00`. Also "how long
  until…?" as subtraction on the clock. *(We have no clock **art** — the clock face
  is a procedural widget; see §8.)*
- **Two trains (relative speed / distance)** — *BUILT (`TrainsScene.gd`)*. A harder,
  wonderful one the parent proposed. *"Train A leaves 1 hour early at 30 mph; Train B leaves later at 50 mph.
  After 4 hours, how far ahead is B?"* It looks hard, but the **animation makes it
  obvious**: two trains on parallel tracks leave a station; A gets a head start, but
  B is visibly faster — it eats the gap and pulls ahead. Choreography:
  - A departs; a **distance bar / mile counter** grows under its track.
  - B departs a head-start later, faster; its bar grows quicker and you *see* it
    **close the gap** and cross A (the "catch-up" moment is highlighted).
  - Freeze at the asked hour; show both distances stacked and the difference:
    `A: (4+1)×30 = 150`, `B: 4×50 = 200`, **ahead = 200 − 150 = 50 miles**.
  - Bonus beat: *when* B catches A → `head-start×slow ÷ (fast−slow)` hours.
  - Great for teaching that **rate compounds over time** and that a later, faster
    start can win. Generated with random speeds/head-start/hours (`trains_gap`),
    always arranged so B genuinely ends ahead.
- Optional: short YouTube clips (ingested to `.ogv` like Solar/Ant) for a "real
  world" cutaway when a concept needs it.

---

## 4. Practice mode (she enters the answer)

- Same manipulatives as the matching tutorial, but **not** auto-counted — she taps
  each cube to count (it rings gold), then types the answer on a **big number
  pad**.
- **Correct** → cubes turn gold, a little cheer, next problem.
- **Incorrect → always explained, never scolded.** The engine knows the *kind* of
  mistake and replays the relevant tutorial beat:
  - off-by-one / miscount → re-count slowly together, highlighting the missed cube.
  - added instead of counted-on → show the "count on from 7" beat.
  - multiplication as addition of wrong groups → re-show equal groups.
  - division leftover confusion → re-deal and name the remainder.
- Difficulty ramps within a tab (sums to 10 → to 20 → crossing ten; tables ×2, ×5,
  ×10 first; division as the inverse of a known table).

---

## 5. Word-problem engine (make it *alive*)

A word problem = **story text (narrated) → interactive sprite scene → drag-to-solve
→ worked equation.** Templates are data (`MathData.problem_types()` +
`sample_problems()`), each bound to a sprite scene. Shared mechanics: **drag from a
source into targets; a correct count/placement gets a gold outline; a running total
tracker; close-out animation; final equation reveal, narrated.**

**Procedural generation (`MathProblemGen.gd`).** Every template is a *generator*,
not a fixed question: it takes a seed and emits `{ prompt, steps[], answer,
params, subjects[] }` with fresh numbers (and often fresh actor names / subjects).
`params` is returned so Practice's mistake-coach — and the test suite — can
re-derive the answer with no hidden constants. This is why a handful of sprites
gives *big* coverage: the art is fixed, the arithmetic is infinite. Current
generators: `count_add`, `take_sub`, `groups_mul`, `share_div`, `eggs_rate`,
`coins_make`, `share_dolls`, `paint_rate`, `trains_gap`, `clock_elapsed`.

### 5.1 Use cases (the parent's list, specced as templates)
- **`coins_count`** — pennies/nickels/dimes with a **live total-value tracker**;
  individual value shown under each coin, `+` between them.
- **`make_change`** — *"2 dimes, 3 nickels, 7 pennies; make 12¢."* Coins listed
  **horizontally in sequence** in named **buckets** ("Ways to make 12¢"), a total
  tracker per bucket, `+` between coins, value under each. Count **how many ways**.
  (Bucket rename suggestion: call them **"Coin Purses"** — friendlier than
  "bucket".)
- **`eggs_rate`** — *the flagship word problem* (see 5.2).
- **`share_resources`** — *"Basket has 4 dolls; a kid adds 1, another adds 2; 4
  kids want dolls; how many each?"* → pool `4+1+2=7`, then **share** `7 ÷ 4 = 1
  each, 3 left over`. Uses the division dealing animation.
- **`rate_time`** — *painting stones* (Bobby 4/hr, Sally 6/hr, 20 stones): combined
  rate, hours, and per-person totals, animated with a ticking clock.
- **`rate_distance`** — *two trains* (§3.6): head start vs. faster speed, the gap,
  and the catch-up moment, animated on parallel tracks.
- **`clock_time`** — reading a clock, elapsed time, "how long until".

### 5.2 Flagship: chickens & eggs *(BUILT — `EggsScene.gd`; the parent's detailed example)*
> "4 white chickens lay 2 eggs/day, 4 yellow lay 1 egg/day. How many eggs in 3
> days? Then pack them into 6-egg cartons — how many cartons?"

Choreography:
1. **Chickens on screen** (4 white, 4 yellow) each with a **laying hatch** below.
2. **Drag eggs** to each chicken's hatch — the *right* number per chicken. Correct
   count → **gold outline** on the hatch + eggs.
3. Scale to **3 days** (repeat / ×3 animation).
4. **Cartons that hold 6.** Drag eggs into cartons; a **full carton animates
   closed** (lid snaps down) with a satisfying pop. Count cartons used.
5. **Worked equations, narrated:**
   `(4 × 2) + (4 × 1) = 8 + 4 = 12` eggs/day → `× 3 = 36` → `36 ÷ 6 = 6 cartons`.

This one problem exercises **×, +, and ÷ together** — a great "everything connects"
capstone.

---

## 6. Time math (first-class)

Time deserves its own thread because it's how a kid *feels* math daily:
- **Reading the clock** (o'clock, half-past, quarter).
- **Elapsed time** (addition/subtraction on a clock face with a sweeping hand).
- **Rates over time** (the painters; "how many by bedtime?").
- **Sequencing / durations** ("brush teeth 2 min, story 10 min — how long till
  lights out?").
Sprites: an analog **clock face** widget (procedural — a circle, ticks, two hands
we can tween) plus small daily-life icons. Optional real-world video cutaways.

---

## 7. Narration & accessibility

- OS **text-to-speech** via `Narrator.gd`, which carries the **hard-won Solar
  crash fix**: the Android TTS engine binds asynchronously, and touching it too
  early (`tts_get_voices()` returning null, or `tts_speak()` pre-bind) **crashes
  the process**. So `Narrator` stays silent behind a **warmup gate** (3.5 s after
  launch) and uses `has_feature(FEATURE_TEXT_TO_SPEECH)` rather than probing
  voices. Any auto-narration on the first screen must wait out the gate.
- Everything is **shown and spoken** — no reading required. Text is a bonus, not a
  gate.
- Counting uses **fixed beats** (~0.7 s) so the visual leads; each number is a
  short TTS utterance that cancels the previous, giving a clean staccato count.

---

## 8. Assets (see `docs/ASSETS.md`)

- **Core manipulatives are procedural** — cubes, buckets, coins, the clock face are
  drawn with `StyleBoxFlat` / `_draw()`. Zero external dependencies, tiny APK, no
  large-texture load spikes (another Solar lesson). This is deliberate.
- **Character/story sprites** (chickens, eggs, cartons, dolls, piggy bank, painter
  kids, stones) come from **CC0 packs** (Kenney) or are **agent-generated** flat
  storybook art with keyed transparency — the same pipeline that made the Solar
  astronaut/ship. Candidates are catalogued in `docs/ASSETS.md`.

---

## 9. Architecture

```
game/
  scenes/Main.tscn            # entry
  scripts/
    Main.gd                   # shell: header, op card, tab routing, tutorial overlay
    TabBar.gd    (MathTabBar) # four rounded bottom tabs
    MathTheme.gd              # palette, OP metadata, style helpers
    MathData.gd               # tutorial catalog, problem-type registry, samples
    MathProblemGen.gd         # BUILT: 10 procedural generators (seeded, testable)
    Narrator.gd               # crash-safe OS TTS (warmup gate)
    CubeGroup.gd              # the counting-cube atom (ring grammar)
    StorySprites.gd           # BUILT: subject tag -> res://images/story art (or "" = procedural)
    AdditionTutorial.gd       # BUILT vertical slice
    TrainsScene.gd            # BUILT: two-trains word problem (sim-animated)
    EggsScene.gd              # BUILT: chickens & eggs word problem (cartons snap shut)
    # planned: SubtractionTutorial.gd, MultiplicationTutorial.gd,
    #          DivisionTutorial.gd, NumberPad.gd, ClockFace.gd,
    #          problems/MakeChange.gd, problems/ShareDolls.gd,
    #          problems/PaintStones.gd, MistakeCoach.gd (explains wrong answers)
  tests/run_tests.gd          # headless: data integrity + all scripts compile
  tools/capture_shots.gd      # dev screenshots
```

Every script is force-loaded by the test runner so a compile error anywhere fails
CI. Data (tutorials, problem types, samples) lives in `MathData` so tutorials,
practice, and tests read one source of truth.

---

## 10. Phasing

1. **Preview (this):** shell + four tabs + fully animated **Addition** tutorial +
   crash-safe narrator + data spine + tests + kiosk tile. ✅
2. Subtraction, Multiplication, Division tutorials (reuse `CubeGroup` + bucket
   widget + the merge/deal tweens).
3. **Practice** mode + `NumberPad` + `MistakeCoach` (explained wrong answers).
4. **Word problems:** `EggsRate` first (capstone), then `MakeChange`, `ShareDolls`,
   `PaintStones`.
5. **Time** thread: `ClockFace` widget + elapsed-time + rate-over-time.
6. Progress/rewards, parent settings (which tables, number range), optional video
   cutaways.

---

## 11. Open decisions (for the parent)

- **"Bucket" naming** for the change game → proposing **"Coin Purse"**.
- **Number entry:** on-screen number pad (chosen) vs. tapping to count up.
- **Reward feel:** stars? a growing sticker book? kept minimal for now.
- **Voice:** OS default vs. a warmer recorded VO for the flagship tutorials.
