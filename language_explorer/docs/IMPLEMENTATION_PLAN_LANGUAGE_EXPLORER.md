# IMPLEMENTATION PLAN — Language Explorer

*Phased, agent-executable build plan for **Language Explorer**, Game #5 in Star Learner.
Mirrors the structure of `garden_explorer/docs/IMPLEMENTATION_PLAN_GARDEN_EXPLORER.md`
and the learning-console patterns of `math_explorer/`.
Target: **Godot 4.3+, GDScript, 2D landscape console**, Android export to the Star Learner
kiosk (Moto G Play 2024). Player: one ~6-year-old, one finger. Languages: **English and Spanish**.*

---

## 0. How to use this document

- **Authoritative scope:** this plan + `game/data/*.json` + `tools/*.tsv`. Where strategy notes
  and this plan conflict, **this plan wins for build order**.
- **Definition of done per phase:** each phase has an **Acceptance test** — do not advance until
  it passes in the editor (or on-device where noted).
- **Non-negotiables (thread through every phase):**
  1. **Learning console aesthetic** — match Math Explorer: dark navy BG, gold CTAs, rounded tiles,
     large targets (≥84–96 px), spoken + shown.
  2. **Clear Back (top-left) on every screen** deeper than the home tile picker.
  3. **Wrong never scolds** — nice coaching VO, then teach (spell / re-show), then retry.
  4. **Letter-by-letter gold/bold** is the shared literacy grammar (like Math’s counting rings).
  5. **Offline-first** — baked ElevenLabs WAVs, local images/videos/books; no runtime cloud calls
     in v1.
  6. **Bilingual from day one** — every practice item and book has `lang: "en" | "es"` (and often
     paired twins). Language toggle lives in the hamburger.
  7. **Kiosk save** — page bookmarks, seen tutorials, language preference; honour
     `user://.antphone_wipe` / `EXTRA_WIPE_SAVE` like Math.

---

## 1. Vision & loop

Language Explorer teaches **reading and writing** as two big console tiles.

| Mode | What she does | Feel |
|------|---------------|------|
| **Read** | Match sprites to words in practice sentences, or open public-domain children’s books | See → hear letters → match → green |
| **Write** | Trace grey letter outlines for a word cued by image (v1) or narration (v1) | Trace → hear letter → celebrate |

**Core literacy grammar (reuse everywhere):**
- **Red + larger** = target / unmatched word
- **Gold + bold + slightly larger** = letter (or word) being narrated *right now*
- **Green + normal size** = matched / complete
- **Gold outline on sprite** = selected
- **Small sprite above word** = successfully matched

**Entry:**
1. Launch → short narrated tour (Read tile, Write tile, ☰ tutorials) once.
2. Home shows **two large tiles** with clear icons: Read (open book / eye) and Write (pencil).
3. ☰ hamburger (top-left on home; Back elsewhere) opens tutorials + language (EN/ES) + credits.

---

## 2. Tech stack & folder layout

- **Engine:** Godot **4.3+**, Mobile renderer, landscape, canvas **1280×600** (match Math Explorer).
- **Aesthetic source of truth:** `math_explorer/game/scripts/MathTheme.gd` → fork as `LangTheme.gd`.
- **Audio:** ElevenLabs bake via `tools/gen_language_vo.py` (same Matilda / multilingual_v2 knobs
  as Math; secrets at `ant_explorer/tools/secrets/elevenlabs.env`).
- **Video:** short sentence-play clips as Theora `.ogv` (one decoder at a time, Garden/Solar pattern).
- **Books:** curated public-domain children’s texts + cover images; packaged under `game/books/`.
- **Package:** `com.dylan.antexplorer.language` · catalog id `language` · tile `tile_language` ·
  label e.g. `words` or `letters`.

```
language_explorer/
├── README.md
├── docs/
│   ├── IMPLEMENTATION_PLAN_LANGUAGE_EXPLORER.md   ← this file
│   ├── STRATEGY_LANGUAGE_EXPLORER.md              ← intent / UX detail (Phase 0)
│   ├── ASSETS.md                                  ← packs, PD books, licenses
│   └── BIBLIOGRAPHY.md                            ← book + media provenance
├── tools/
│   ├── books.tsv                  # id | lang | title | source_url | license | notes
│   ├── sentences.tsv              # id | lang | text | sprite_ids | video_id
│   ├── words.tsv                  # id | lang | word | image_id | letters[]
│   ├── media.tsv                  # id | kind | url_or_path | start | end
│   ├── build_sentence_videos.sh   # optional yt/ffmpeg → game/videos/sentences/
│   ├── ingest_books.py            # download/clean PD books → game/books/<id>/
│   ├── gen_language_vo.py         # ElevenLabs bake from VO manifest
│   ├── dump helpers via game/tools/dump_vo_lines.gd
│   ├── build_language_apk.sh      # clone math/garden APK script
│   └── make_demo_videos.sh
└── game/                          # Godot project root
    ├── project.godot
    ├── icon.svg
    ├── scenes/Main.tscn
    ├── data/
    │   ├── sentences.json
    │   ├── books.json
    │   ├── words.json
    │   ├── tutorials.json
    │   └── language_vo_manifest.json
    ├── books/<book_id>/
    │   ├── meta.json              # title, description, lang, cover, pages[]
    │   ├── cover.png
    │   └── pages/*.json           # word-tokenized page text
    ├── images/
    │   ├── ui/                    # read/write icons, hamburger, back
    │   ├── sprites/               # sentence sprites
    │   ├── words/                 # write-mode cue images
    │   └── covers/                # optional shared covers
    ├── videos/
    │   └── sentences/<id>.ogv     # sprite sentence play-outs
    ├── audio/vo/<md5>.wav
    ├── scripts/
    │   ├── Main.gd                # shell: home tiles, routing, hamburger, back
    │   ├── LangTheme.gd           # palette + style helpers (fork MathTheme)
    │   ├── LangData.gd            # catalogs
    │   ├── Save.gd                # autoload
    │   ├── Narrator.gd            # fork Math (warmup gate + baked clips)
    │   ├── NarratorVoice.gd
    │   ├── VoStream.gd
    │   ├── WordLabel.gd           # letter-by-letter gold/bold narration widget
    │   ├── ClearButton.gd         # shared “read page / next” clear control
    │   ├── SpriteChip.gd          # tappable/draggable sprite with gold outline
    │   ├── TraceCanvas.gd         # grey letter outlines + stroke hit testing (sketch mode)
    │   ├── AlphabetBoard.gd       # ordered A–Z / A–Z+Ñ letter tiles + A|a case toggle
    │   ├── LetterSlots.gd         # grey underlines for the target word above the board
    │   ├── read/
    │   │   ├── ReadHome.gd        # Sentences vs Books tiles
    │   │   ├── SentenceMatch.gd   # video → spread sentence → match sprites
    │   │   ├── BookShelf.gd       # cover tiles + double-tap open
    │   │   └── BookReader.gd      # page view + word tap + clear read/next
    │   ├── write/
    │   │   ├── WriteHome.gd       # Images vs Narration (+ Record soon); letter-input picker
    │   │   ├── WriteFromImage.gd
    │   │   ├── WriteFromNarration.gd
    │   │   └── WriteSession.gd    # shared letter-index / hint / celebrate logic
    │   └── ui/
    │       ├── HamburgerMenu.gd   # tutorials + language + credits
    │       └── TutorialPlayer.gd
    ├── android_src/com/godot/game/GodotApp.java
    ├── tests/run_tests.gd
    └── tools/
        ├── dump_vo_lines.gd
        └── capture_shots.gd
```

**Scaffold note:** copy narration/save/APK contracts from Math; copy hamburger + video panel habits
from Garden. Do **not** invent a shared addon yet — fork `Narrator` / `VoStream` / `Save` like the
other titles.

---

## 3. Art, UX & content sources

### 3.1 Console aesthetic (from Math Explorer)

| Token | Value |
|-------|--------|
| BG | `Color(0.10, 0.12, 0.20)` |
| Panel | `Color(0.16, 0.19, 0.30)` |
| Gold | `Color(1.00, 0.82, 0.30)` — CTAs, active letter, selection rings |
| Red | unmatched target words |
| Green | completed words |
| Text | near-white; black outline on floating labels |
| Tiles | rounded ~20–28 radius; active = gold border + soft glow |
| Buttons | primary gold + dark text; secondary panel + light border |
| Layout | hard-coded around 1280×600 / x=640 center (same as Math) |

### 3.2 Public-domain books (v1 candidates — verify license per title)

Private family / educational use on the kiosk. Prefer **US public domain** sources and record
provenance in `BIBLIOGRAPHY.md`. Candidate pools to vet in Phase 0:

| Pool | Use |
|------|-----|
| **Project Gutenberg** children’s / juvenile shelf | Full text for classic stories (EN); Spanish PD shelf for ES |
| **Library of Congress** “free to use and reuse” | Cover / illustration candidates where PD |
| **Standard Ebooks** (where PD) | Cleaner text formatting for some classics |
| **Internet Archive / Google Books** PD scans | Fallback illustrations when Gutenberg text has no art |

**v1 shortlist intent (finalize in `books.tsv` after license check):**
- English: short, famous children’s classics with clear page breaks (e.g. Beatrix Potter–era PD
  titles, early Oz / Wonderland excerpts sized for a child session — **not** full adult novels).
- Spanish: PD *cuentos infantiles* / fables with simple sentences; prefer short chapter or single
  story packs.
- Prefer books where we can ship **cover image + paginated plain text**. Illustrated PD plates are
  a plus; otherwise use a simple storybook frame + Kenney/CC0 decoration.

**Hard rule:** every shipped book row needs `license`, `source_url`, and `retrieved_on` in
`BIBLIOGRAPHY.md`. If unclear → do not ship.

### 3.3 Other assets

| Need | Source |
|------|--------|
| UI icons / frames | Kenney UI Pack (CC0) |
| Sentence sprites | Flat storybook sprites (reuse Math `StorySprites` style / agent-generated + magenta key) |
| Write-mode images | CC0 object packs (Kenney) + custom set for bilingual nouns |
| Sentence videos | Short game-generated sprite play-outs (preferred) or trimmed clips via `media.tsv` |
| Narration | ElevenLabs multilingual (EN + ES lines baked) |

### 3.4 UX chrome

- **Home:** two tiles (Read / Write). No bottom op strip like Math — this title’s “tabs” *are* the
  two modes.
- **Back:** top-left on every nested screen; returns one level (Book page → shelf → Read home →
  app home).
- **Hamburger:** only on home (and optionally Read/Write homes). Contents: tutorials, EN/ES
  toggle, credits / sources VO.
- **Clear button:** shared control used for “read all slowly” and “next” (label/icon changes by
  context; always large and gold-outline friendly).
- **Double-tap open (books):** first tap narrates title + one-sentence description + saved place
  + “tap again”; second tap within **5 seconds** opens. (Ant shelves used ~1–3 s; books get 5 s
  as specified.)

---

## 4. Data model (Phase 0)

### 4.1 Sentences (`sentences.json`)

```json
{
  "id": "en_apple_red",
  "lang": "en",
  "text": "The apple is red.",
  "tokens": ["The", "apple", "is", "red."],
  "matchable": ["apple", "red"],
  "sprites": [
    {"id": "apple", "token": "apple", "image": "res://images/sprites/apple.png"},
    {"id": "red", "token": "red", "image": "res://images/sprites/swatch_red.png"}
  ],
  "video": "res://videos/sentences/en_apple_red.ogv",
  "pair_id": "es_manzana_roja"
}
```

Punctuation stays on tokens for display; matching normalizes (`red.` → `red`).

### 4.2 Books (`books.json` + per-book `meta.json`)

```json
{
  "id": "peter_rabbit",
  "lang": "en",
  "title": "The Tale of Peter Rabbit",
  "description": "A little rabbit goes into Mr. McGregor's garden.",
  "cover": "res://books/peter_rabbit/cover.png",
  "pages": ["res://books/peter_rabbit/pages/000.json", "..."],
  "license": "US public domain",
  "source_url": "https://www.gutenberg.org/ebooks/…"
}
```

Page JSON: ordered word tokens with optional sprite hints later. Save stores
`bookmarks[book_id] = page_index`.

### 4.3 Words (`words.json`) — Write mode

```json
{
  "id": "en_apple",
  "lang": "en",
  "word": "Apple",
  "letters": ["A", "P", "P", "L", "E"],
  "image": "res://images/words/apple.png",
  "narration_word": "Apple",
  "pair_id": "es_manzana"
}
```

Spanish entries use Spanish letter narration (including `ñ`, accented vowels as their own spoken
letters where appropriate).

### 4.4 Save (`user://language_explorer_save.json`)

```json
{
  "version": 1,
  "intro_done": false,
  "lang": "en",
  "letter_input": "alphabet",
  "seen": {"tut_read": true, "tut_write": true, "tut_alphabet": true},
  "bookmarks": {"peter_rabbit": 3},
  "stats": {"sentences_completed": {}, "words_traced": {}, "books_opened": {}}
}
```

- `letter_input`: `"sketch"` | `"alphabet"` (default **`alphabet`** for clearer first success on a
  finger-only kiosk; sketch remains fully supported).
- Wipe via `.antphone_wipe` exactly like Math Explorer.

### 4.5 Shared widget: `WordLabel`

One Control that:
1. Renders a word (or sentence of word Controls).
2. On `spell()`: iterates letters, sets **bold + gold + slightly larger**, speaks letter clip,
   then speaks full word, then restores style (or turns green if matched).
3. States: `normal | target_red | spelling_gold | done_green`.

This is the literacy equivalent of Math’s `CubeGroup` ring grammar.

---

## 5. Gameplay specs (lock for v1)

### 5.1 ENTRY

- Two tiles with icons + spoken labels on first highlight.
- Selecting Read or Write opens that mode’s home (Sentences/Books or Images/Narration).

### 5.2 READ → SENTENCES

1. Play sentence video (sprites act out the sentence). Missing video → still frame + VO of sentence.
2. Show full sentence + sprite chips from the video.
3. Sentence **spreads**; matchable words become **red + larger**.
4. Tap word → letter-by-letter gold/bold narration (`A-P-P-L-E`), then full word optional on
   complete spell.
5. Tap sprite → enlarges + gold outline.
6. Tap or drag sprite onto a red word:
   - **Correct:** VO “Correct!” → spell letters → speak word → word turns **green**, normal size;
     sprite shrinks and sits **above** the word.
   - **Incorrect:** kind VO (“Almost — let’s listen again.”) → spell the *target* word’s letters
     gold/bold → sprite returns home.
7. When all matchable words are green: Clear button offers **Read all slowly** (each word gold/bold
   bigger while narrated) **or** **Next sentence**. Word taps still spell on demand.

### 5.3 READ → BOOKS

1. Grid/list of cover tiles.
2. Tap → VO: title, one-sentence description, saved place if any, “tap again to open.”
3. Second tap within **5 s** opens to bookmark or page 0.
4. In reader: tap word → spell letters gold/bold; Clear → read page word-by-word slowly; Clear/next
   advances page and saves bookmark.
5. Back returns to shelf (saving place).

### 5.4 WRITE → PRACTICE WORDS

**Content modes:** Images (v1), Narration (v1), Record audio (**roadmap only** — §8).

**Letter-input modes** (option on Write home / hamburger; persisted in `Save`):

| Id | Name | Input |
|----|------|--------|
| `sketch` | Grey outline sketch | Finger (or passive capacitive stylus — see §5.4.4) traces light-grey letter outlines |
| `alphabet` | Alphabet tiles | Ordered A–Z rows (ES: include `Ñ`); **not** QWERTY by default (QWERTY optional later) |

**Case chrome (alphabet mode):** clear **`A | a`** buttons. **Default case follows the target
word/sentence** — e.g. `Apple` → first slot expects `A`, then `p p l e` (board auto-switches to
lowercase after a correct uppercase pick, and flips again if a later letter is uppercase). Manual
`A|a` still lets her browse the other case without changing the expected letter.

Shared finish beat (both letter-input modes): when the word is complete, spell
letter-by-letter **gold + bold + slightly larger**, then speak the full word.

#### 5.4.1 Images + sketch

1. Grid of word images → select → image centered high; writing area below.
2. Large light-grey letter outlines for the word.
3. Tracing a letter triggers that letter’s narration; fill progress per letter.
4. On complete → shared finish beat.

#### 5.4.2 Images + alphabet tiles

Layout (top → bottom):
1. Cue image (center-high).
2. **Letter slots** — one grey underline per letter of the target word (filled slots show the chosen
   glyph; current slot may pulse faintly).
3. **Alphabet board** — large letter tiles in ordered rows + `A | a` case buttons.

Flow:
1. **Intro VO:** speak the full word; tell her she can **tap the image** to hear the **next** letter.
2. She taps a letter tile matching the current slot (case-sensitive to the word’s expected case).
3. **Incorrect:** kind VO (“Nice try — listen again.” / ES equivalent) → that tile turns **red +
   greyed** and becomes **untappable** for the rest of this letter attempt. Wrong-count += 1.
4. **Image tap:** narrates the current target letter; image-hint-count += 1.
5. **Reveal gate:** after **three incorrect letter taps** *or* **three image taps** for letter
   narration — whichever comes first — the **correct** letter tile turns **gold + bold + slightly
   larger**; all other still-enabled tiles go **grey + untappable** (no new red). Already-wrong red
   tiles stay red/grey/untappable.
6. **Correct** (before or after reveal): VO celebrate lightly → slot fills → alphabet **clears /
   resets** for the next letter → case auto-adjusts to the next expected case → wrong-count and
   image-hint-count reset to 0.
7. Repeat until all slots filled → shared finish beat.

#### 5.4.3 Narration + alphabet tiles

Same slot + board layout as Images, but **no cue image**. Instead:

1. **Intro VO:** spell the word letter-by-letter, then speak the full word; point out the **clear
   icon tile** that re-plays the **current** letter.
2. Grey underlines above the alphabet board for the target word.
3. **Clear icon tile** (large, distinct from `A|a`): tap → narrate current letter only.
4. Incorrect / reveal / correct / case-advance / finish — **same rules as §5.4.2**, except the hint
   counter for the reveal gate uses **clear-icon taps** (not image taps). Three wrong letter picks
   **or** three clear-icon taps → reveal gold correct tile.

#### 5.4.4 Narration + sketch

1. Enter → hear letters then full word.
2. Same grey outline tracing as Images + sketch.
3. Optional: a small clear/replay control re-speaks the current letter while tracing.

#### 5.4.5 Stylus note (Moto G Play 2024)

The kiosk device is a **moto g play (2024)** with a standard capacitive LCD touchscreen — Motorola’s
own specs list no stylus digitizer or bundled pen
([Specifications — moto g play (2024)](https://en-us.support.motorola.com/app/answers/detail/a_id/177738/~/specifications---moto-g-play-%282024%29)).
The **moto g stylus** line is a different SKU.

- **Active / protocol styluses** (S Pen–class, AES/MPP) will **not** give pressure/palm features here.
- **Passive capacitive styluses** (disc-tip / rubber-tip “finger substitutes”) work on ordinary
  Android capacitive screens in general
  ([Android pen compatibility overview](https://electronics.alibaba.com/question/best-pens-for-android-phones-active-vs-passive-explained)).
- **Product default:** design sketch mode for **finger first**; treat a cheap capacitive stylus as
  an optional comfort accessory, not a requirement. No Godot stylus API work in v1.

#### 5.4.6 Alphabet board details

- **EN rows:** `A–Z` in ABC order (suggest ~7 per row on 1280×600; tune in Phase 5).
- **ES rows:** `A–Z` plus **`Ñ`** (and only add accented standalone tiles if STRATEGY locks
  letter-name teaching for accents; default v1: base letters + `Ñ`, accents taught inside words via
  expected glyph on the slot).
- Tile size ≥ ~72–84 px; `FOCUS_NONE`; case toggle always visible.
- QWERTY layout = optional hamburger/advanced toggle later — **off by default**.

### 5.5 Tutorials (hamburger)

Short narrated overlays (gold highlights) for: Read home, Sentence match, Book double-tap, Write
sketch, Write alphabet tiles, case `A|a`. First entry into Read/Write can auto-play the matching
tutorial once (`Save.seen`).
---

## 6. Phases

### Phase 0 — Scaffold & manifests ✅ (this drop)

- [x] Create `language_explorer/` project dir
- [x] This implementation plan
- [x] `README.md` stub
- [x] `docs/STRATEGY_LANGUAGE_EXPLORER.md`, `ASSETS.md`, `BIBLIOGRAPHY.md`
- [x] Folder tree under `game/` + `tools/`
- [x] Seed TSV/JSON stubs: `sentences`, `words`, `books` (3 EN + 3 ES sentences; 8 words; 1–2
      book placeholders marked `ship: false` / `TODO_LICENSE`)
- [x] License pass for first book candidates → fill BIBLIOGRAPHY (blocks Phase 4 ingest)

**Acceptance:** tree exists; JSON/TSV validate; every media/book row has a license note or
`TODO_LICENSE` flag that blocks shipping. ✅ (license vetting still open)

### Phase 1 — Godot shell (learning console) ✅

- [x] `project.godot` (4.3 Mobile, 1280×600, TTS enabled, Save autoload)
- [x] `LangTheme`, `Main` home with Read/Write tiles, hamburger, intro tour, Back plumbing
- [x] Fork `Narrator` / `VoStream` / `NarratorVoice` / `Save` from Math
- [x] Headless `tests/run_tests.gd` (theme + compile + save wipe)
- [x] Stub `ReadHome` / `WriteHome` (letter-input picker on Write)

**Acceptance:** editor boots to two tiles; intro plays once; Back/hamburger work; tests green.
✅ (66/66 headless tests)

### Phase 2 — WordLabel + ClearButton + VO bake loop ✅

- [x] `WordLabel` letter-by-letter gold/bold + full word
- [x] `ClearButton` contexts: read-all / next-sentence / next-page
- [x] `dump_vo_lines.gd` + `gen_language_vo.py` + VO coverage test
- [x] EN + ES alphabet letter clips + shared coaching lines (“Correct!”, kind incorrect lines)
- [x] `SpellDemo` (☰ → Spell demo) for Apple / Manzana acceptance
- [x] `LangLetters` + `LangVo` inventories; `tools/gen_vo.sh` wrapper

**Acceptance:** demo scene spells `APPLE` / `MANZANA`; every enumerated VO line has a WAV or test
fails. ✅ (90/90 tests; 135 baked clips)

### Phase 3 — READ Sentences (match loop) ✅

- [x] `ReadHome` (Sentences / Books tiles)
- [x] `SentenceMatch` with video stub (sprite hop + VO), spread, sprite select, tap/drag match
- [x] Correct / incorrect choreography per §5.2
- [x] Completion: read-all + next sentence
- [x] Seed content: ≥6 sentences (3 EN, 3 ES) with sprites (procedural placeholders OK)
- [x] `SentenceLogic` + `SpriteChip` + `SpriteArt`; layered Back (`sentences` → `read` → `home`)

**Acceptance:** complete one EN and one ES sentence end-to-end with VO; wrong match is kind and
resets sprite. ✅ (headless tests + playable editor path)

### Phase 4 — READ Books ✅

- [x] Ingest pipeline (`ingest_books.py`) for 1 EN + 1 ES short book
- [x] `BookShelf` cover tiles + 5 s double-tap arm
- [x] `BookReader` word tap spell + clear read-all + next page + bookmark save
- [x] Missing-cover / missing-page fallbacks (`CoverArt` + empty-page VO)
- [x] BIBLIOGRAPHY + `books.tsv` license rows; layered Back (`reader` → `books` → `read` → `home`)

**Acceptance:** open book from shelf (double-tap), leave mid-book, reopen at saved page; page
read-all works offline. ✅

### Phase 5 — WRITE Images + Narration (sketch + alphabet) ✅

- [x] `WriteHome`: Images / Narration tiles + letter-input picker (`sketch` | `alphabet`)
- [x] `TraceCanvas` grey outlines (sketch path)
- [x] `AlphabetBoard` + `LetterSlots` + `A|a` case chrome (alphabet path)
- [x] `WriteSession` shared state: current index, wrong-count, hint-count, reveal, case follow
- [x] `WriteFromImage`: image-tap = next-letter hint; reveal after 3 wrong **or** 3 image taps
- [x] `WriteFromNarration`: clear icon = current-letter replay; reveal after 3 wrong **or** 3 clears
- [x] Incorrect tile → red/grey/untappable; reveal → gold correct + grey others; correct → reset board
- [x] ≥8 words (4 EN / 4 ES), paired where possible; ES board includes `Ñ`

**Acceptance:** finish `Apple` via alphabet (auto case A→p…); finish `SOL` via narration+alphabet;
finish one word via sketch; three wrongs reveal gold hint; incomplete never false-completes. ✅

### Phase 6 — Tutorials, polish, kiosk ship ✅

- [x] Hamburger tutorials + EN/ES toggle persistence
- [x] APK script `build_language_apk.sh` → `com.dylan.antexplorer.language`
- [x] Catalog entries in `ant_explorer/tools/catalog.json` **and** kiosk `assets/catalog.json`
- [x] Tile art `tile_language` + `language_explorer_explainer.mp4`
- [x] Root `star_learning/README.md` catalog row
- [x] UX screenshots + demo capture scripts
- [x] Compact 9-column alphabet layout (all three rows visible at 1280×600)
- [x] Five-title kiosk layout compacted so no catalog tile is clipped

**Acceptance:** signed 36 MiB APK installed on the connected kiosk; the `words` tile launched
`com.dylan.antexplorer.language/com.godot.game.GodotApp`; wipe-intent and cold restart both
launched successfully; all shipped content remains offline. ✅ (2026-07-25)

---

## 7. Narration contracts

- Baked clips keyed by md5 of normalized sentence (Math pattern).
- Letter clips: speak `"A"`, `"P"`, … and Spanish letters as their own strings (`"ene"` vs `"n"` —
  decide in STRATEGY; default: speak the letter **name** in the active language).
- Dynamic book titles still baked: manifest enumerates every shipped title/description/page VO
  needed for UI chrome; long page read-aloud may concatenate per-word clips.
- OS TTS only as fallback; keep Math’s **3.5 s warmup** and **never call `tts_get_voices()`**.
- Prefer `eleven_multilingual_v2` for ES quality (already Math’s default model).

---

## 8. Roadmap — Record audio → 245 inference (NOT v1)

**Intent:** later, Write mode gains **Record**: she records a sentence she wants to write; the game
helps turn that into practice words/sentences.

**Why 245:** MSI `DESKTOP-KOMPK5V` / WSL `hilarious_marcupial` hosts the fleet GPU + StarLearner
hub (`:8443`). Sources: `reports/system/SYSTEM_ECOSYSTEM_PROFILES.md` (§ hilarious_marcupial /
ants-phone), `reports/system/AAR_2026-07-25_230_OUTAGE_AND_245_DEGRADED_RECOVERY.md`,
`ant_explorer/docs/STRATEGY_ANT_PHONE_UPDATES.md` §12, `ant_explorer/tools/hub245/Caddyfile.template`.

**Greenfield facts (as of plan authoring):**
- Star Learner has **no** `MediaRecorder` / Whisper / `/api/asr` precedent — all existing audio is
  **one-way baked TTS playback** (`Narrator` / `VoStream` / ElevenLabs generators).
- The only game→model gateway today is Caddy `handle_path /api/llm/*` → Ollama `:11434`.
  **Ollama does not serve transcription** → Record needs a **new** route (e.g. `/api/asr/*`) and a
  new WSL service, not a reuse of `/api/llm`.
- Phone cannot do serious on-device ASR (Moto G Play ~4 GB RAM, ~1.3 GiB free typical) →
  **record locally, upload to 245** is the realistic split.
- Package / tile still follow existing convention when Phase 6 ships:
  `com.dylan.antexplorer.language`, catalog id `language`, tile `tile_language`.

### 8.1 Hard constraints

1. **Offline-first.** Recording help is best-effort. Game must tolerate missing hub / ASR exactly
   as phone strategy already prescribes for LLM: strict timeout, fallback to baked VO / local Write
   modes (`STRATEGY_ANT_PHONE_UPDATES.md` §12.5).
2. **Reach 245 via the `:8443` hub**, never via the 230 jump host. AAR proved WAN `:8443` stayed up
   while 230 was dead; don’t reintroduce that SPOF for kid-facing inference.
3. **Keepalive-managed WSL service.** Never launch ASR from an interactive SSH→WSL session (AAR:
   session teardown kills the tree). Mirror `LG_1D_KEEPALIVE` / `antphone_hub.bat` Startup patterns.
4. **WSL NAT relay.** 245 WSL is NAT, not mirrored (`eth0` like `192.168.78.x`). Caddy on Windows
   must reach ASR the same way it relays Ollama on localhost — plan an explicit localhost relay.
5. **VRAM headroom.** During T1 extract AAR recorded ~21 / 24 GiB GPU @ ~86% util (~3 GiB free).
   ASR must be small / int8 / CPU, or **yield while T1 owns the card**. Do not land new GPU load on
   245 while AAR §11 is still OPEN and grading catch-up is gated.
6. **Model install flake.** `ollama create` `chtimes` blob permissions can fail — ASR install needs a
   fallback-to-already-present path (even if ASR isn’t Ollama).
7. **WAN IP is load-bearing.** Hub hairpin / SPKI / updater depend on current public IP; phone
   strategy’s “IP-watch / DDNS on 245” is still unchecked — treat that as a prerequisite for
   always-on kid-facing inference.
8. **No second broad WAN forward.** Don’t add another `From: Any` UniFi rule; reuse bearer-authed
   `:8443` (narrow `temp-245` separately per AAR hygiene).
9. **Privacy.** Child voice on-device first; upload only with explicit parent/ops flow; delete after
   inference; state the mic decision in STRATEGY before coding capture.
10. **`RECORD_AUDIO`.** Kiosk has no permission UI — grant via deploy script
    (`adb shell pm grant … RECORD_AUDIO`), consistent with lockdown posture.
11. **Embedding trap.** Fleet `embedding_bge` is **bge-m3 / 1024-d, non-negotiable**. If Record
    scoring ever touches fleet vectors, pin bge-m3; if it builds its own space, isolate the
    namespace so it can never be confused with `embedding_bge`. Prefer **not** mixing with T1
    vectors in v1 of Record.

### 8.2 Suggested future phases (after Language Explorer v1 ships + AAR §11 closed)

| Step | Work |
|------|------|
| R0 | Decide product meaning of “sentence inference” (transcribe only vs. suggest practice set) + privacy copy |
| R1 | On-device capture UI (waveform, re-record) → `user://recordings/*.wav`; `pm grant RECORD_AUDIO` in deploy |
| R2 | Godot HTTP autoload (token from device config, strict timeout) — same contract as planned `/api/llm` client |
| R3 | Hub: new Caddy `/api/asr/*` → localhost-relayed WSL ASR service + keepalive unit/task |
| R4 | 245: Whisper/faster-whisper (or equiv.) sized for residual VRAM / CPU; queue if T1 busy |
| R5 | Optional light LLM cleanup via existing `/api/llm` → tokenized practice sentence + word list |
| R6 | Parent approval gate (82/portal or on-hub review) before import into Write practice set |
| R7 | Device pull of approved manifest (sha256 via existing hub `make_manifest.sh` cadence) |

**v1 placeholder:** Write home may show a dim **Record (soon)** tile that VO-explains “coming soon”
without implementing capture.

---

## 9. Testing strategy

Headless runner (Math style) must cover:
1. `LangTheme` / catalog integrity (every sentence sprite path exists or is flagged procedural).
2. Sentence match pure logic: normalize tokens, correct/incorrect pairing.
3. Book bookmark save/restore + wipe flag.
4. Trace progress: letter hit order / completion detection.
5. **Alphabet session logic:** case follow (`Apple` → A then p…); wrong→red lock; reveal after 3
   wrongs or 3 hints; correct clears board and advances; ES includes `Ñ`.
6. **VO coverage** for all `vo_lines` + intro + letter inventory EN/ES.
7. Force-`load()` every script (compile gate).

Optional later: Garden-style UX screenshot suite for sentence match + book open.

---

## 10. Open decisions (defaults locked for v1)

| Topic | Decision |
|-------|----------|
| Shell | **Two home tiles** (Read / Write), not Math’s bottom op strip |
| Star documentaries | **Not required for v1**; hamburger tutorials instead. Optional literacy “stars” later |
| Letter speech | Letter **names** in active language |
| Book open window | **5 seconds** |
| Drag | Tap-or-drag sprites (Math eggs pattern; 12 px drag threshold) |
| Letter input | **`alphabet` default**; `sketch` optional; QWERTY off by default |
| Case | Follow word (`Apple` → A then p…); manual `A\|a` toggle always available |
| Reveal gate | 3 wrong letter taps **or** 3 hint taps (image / clear-icon) |
| Stylus | Finger-first; optional **passive capacitive** pen only on G Play 2024 |
| Record audio | **Roadmap only** (§8), dim tile OK |
| Shared code | **Fork**, don’t extract a common addon yet |
| Catalog label | Prefer short tile label **`words`** (finalize with art) |

---

## 11. Immediate next actions (after this plan)

1. Fill `STRATEGY_LANGUAGE_EXPLORER.md` with screen-by-screen VO copy lists.
2. License-vet first 2 books (1 EN, 1 ES) into `books.tsv` + BIBLIOGRAPHY.
3. Phase 1 Godot shell against Math theme tokens.
4. Implement `WordLabel` early — every later scene depends on it.

---

*End of plan. Status: Phase 2 complete (90/90 tests, 135 VO clips). Next: Phase 3 sentence match.*
