# Language Explorer

**Game #5 in the [Star Learner](../README.md) catalog** — a bilingual (English / Spanish)
reading and writing console for a six-year-old.

- **Engine:** Godot **4.3** (Mobile renderer), landscape 1280×600, offline-first.
- **Aesthetic:** learning console (same dark navy / gold language as
  [`math_explorer`](../math_explorer/)).
- **Package:** `com.dylan.antexplorer.language` · tile `tile_language`.

> Full build sequence:
> [`docs/IMPLEMENTATION_PLAN_LANGUAGE_EXPLORER.md`](docs/IMPLEMENTATION_PLAN_LANGUAGE_EXPLORER.md).

## The flow

1. **Home** — two big tiles: **Read** and **Write**, plus ☰ tutorials / language.
2. **Read → Sentences** — watch a short sprite video of the sentence, then match sprites to
   the red words. Letters spell gold and bold; correct matches turn green.
3. **Read → Books** — pick a cover, double-tap to open a public-domain children’s book, tap
   words to hear them letter-by-letter, or clear-read the page slowly.
4. **Write → Images / Narration** — pick a letter-input mode:
   - **Alphabet tiles** (default): ABC rows + `A|a`, grey underlines for the word, hints via image
     tap or clear-icon; wrongs go red; three strikes reveal the gold letter.
   - **Sketch:** trace large grey letter outlines; tracing speaks each letter, then celebrates.

Every nested screen has a clear **◀ Back** (top-left).

## Status

| Area | State |
|------|--------|
| Project dir + implementation plan | ✅ |
| Godot shell (Phase 1) | ✅ Read/Write tiles, ☰, Back, intro, Save, Narrator |
| WordLabel / VO bake (Phase 2) | ✅ Spell demo, 135 ElevenLabs clips, ClearButton |
| Sentence match (Phase 3) | ✅ Read → Sentences: intro hop, drag/tap match, Clear |
| Books (Phase 4) | ✅ Shelf double-tap, reader, bookmarks, 1 EN + 1 ES |
| Write practice (Phase 5) | ✅ Images/Narration × alphabet/sketch, case follow, reveal |
| Tutorials / APK / kiosk ship (Phase 6) | ✅ Installed and tile-launched on kiosk |
| Record-audio → 245 inference helper | 🗺️ Roadmap only (see plan §8) |

## Run & test

From `star_learning/` (this repo root):

```bash
godot --path language_explorer/game
```

Or:

```bash
cd language_explorer/game
godot --path .
```

```bash
godot --headless --path language_explorer/game -s res://tests/run_tests.gd   # 253+ checks
# Regenerate narration (needs ElevenLabs key):
#   language_explorer/tools/gen_vo.sh
# Build signed Android APK:
#   language_explorer/tools/build_language_apk.sh
# Regenerate screenshots / explainer:
#   godot --path language_explorer/game -s res://tools/capture_shots.gd
#   language_explorer/tools/make_demo_videos.sh
```

In-game: ☰ → **Spell demo (Apple / Manzana)**.

## Sibling titles

| Game | Why it matters here |
|------|---------------------|
| Math Explorer | Console shell, theme, Narrator/VO bake, Save wipe, wrong→teach |
| Garden Explorer | Hamburger menu, video panel, phased plan format, APK/catalog wiring |
| Ant / Solar | Kiosk catalog, offline `.ogv`, device deploy |
