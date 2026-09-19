# Star Learner portal brief (for page authors)

**Public site:** `https://starlearner.dylanmccapes.systems` — **no auth** on `/` and `/games/*`.
(`/ops/` and `/logs/` stay basic-auth; `/api/asr` stays bearer.)

**Source tree:** `/home/dylanmccapes/dev/star_learning/site/`
**Shared CSS:** `/css/site.css` (already written)
**Fonts:** load Google Fonts Fraunces + Source Sans 3 in each page `<head>`.

## Nav (include on every page)

Links (absolute from site root):
- `/` — Star Learner (home)
- `/games/ant/` — Ant Explorer
- `/games/garden/` — Garden Explorer
- `/games/solar/` — Solar System Explorer
- `/games/math/` — Math Explorer
- `/games/language/` — Language Explorer

Use `aria-current="page"` on the active link. Class structure matches `site.css` (`.site-header`, `.nav`, `.nav-brand`, `.nav-links`).

Brand: `Star <span>Learner</span>`

## Media paths (from game pages at `/games/<slug>/`)

Prefix: `../../media/...`
From landing `/`: `media/...`

### Demos
- ant: `demos/ant_explainer.mp4`, `demos/ant_walkthrough.mp4`
- garden: `demos/garden_explainer.mp4`, `demos/garden_walkthrough.mp4`
- solar: `demos/solar_explainer.mp4`, `demos/solar_walkthrough.mp4`
- math: `demos/math_explainer.mp4`, `demos/math_walkthrough.mp4`
- language: `demos/language_explainer.mp4`, `demos/language_walkthrough.mp4`

### Educational clip samples (Ant, Garden, Solar only)
- ant: `clips/ant/01_queen.mp4`, `04_fungus.mp4`, `05_forage.mp4`
- garden: `clips/garden/01_seeds.mp4`, `bug_butterfly.mp4`, `animal_chicken.mp4`
- solar: `clips/solar/sun.mp4`, `earth.mp4`, `saturn.mp4`
Math & Language: **no** clip catalog section.

### Kiosk
- `kiosk/moto_farm.png` (preferred hero — current Garden Explorer farm layout; source `garden_explorer/.../ux/01_farm_boot.png`)
- `kiosk/moto_welcome.png`, `kiosk/moto_g_play_2024.png`, `kiosk/device_kiosk_language.png`

### Tiles
- `tiles/ants.png`, `garden.png`, `solar.png`, `math.png`, `language.png`

## Page recipe (each game)

1. Shared nav
2. Eyebrow + H1 game title + 1–2 sentence lede
3. **Informational / explainer video** (under intro, before long prose)
4. Full explanation (prose from README/STRATEGY — kid-parent friendly, accurate)
5. Screenshot grid (3–6 strong shots with captions)
6. **Walkthrough / playthrough video**
7. Educational clip catalog (Ant/Garden/Solar only) — 3 samples with titles + short captions
8. Footer with link home + dylanmccapes.systems

Videos: `controls playsinline preload="metadata"`.

## Tone

Warm, concrete, for parents / curious adults. Not marketing fluff. Mention one-finger landscape kiosk, narrated VO, offline stars format where relevant.
