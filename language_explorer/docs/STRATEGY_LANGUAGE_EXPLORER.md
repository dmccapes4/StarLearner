# Language Explorer — Strategy

*Intent and UX. Build order lives in `IMPLEMENTATION_PLAN_LANGUAGE_EXPLORER.md`
(plan wins on conflicts). Updated 2026-07-26 after playtest simplification.*

## North star

A **reading companion** and a **spelling-from-pictures** practice — not a maze of
sub-modes. Letters and words are things you hear and touch. English and Spanish
share one console. Icons + speech lead; reading is never a gate on chrome.

## Audience

One ~6-year-old on a Star Learner kiosk. One finger. Warm narration. No scolding.

## Launch shell — three tiles

| Tile | Activity |
|------|----------|
| **Read** | Books companion. |
| **Write** | Picture + narration + alphabet tiles. |
| **Voice** | Say an idea → cleaned sentence → pencil letter walk with spoken next/back. |

Home art: generated cinematic tiles. Voice needs Wi‑Fi to the ASR host; otherwise the
tile explains and other modes still work.

### Read (books companion)

- Ingest free/public-domain children’s books; bake page VO with ElevenLabs.
- A **page** is a list of **sentences**. Show one sentence at a time.
- Auto-narrate the sentence; the spoken word is **bold + gold**, then the next
  word. A **next sentence** tile advances anytime (rough page-turn when the page
  changes).
- Tap a word → spell letter-by-letter (bold/gold) → speak the whole word bold/gold
  → restore.
- Long-press a word → kid-friendly definition VO when present in
  `data/definitions.json` (built from book vocabulary). If a word has no gloss,
  ignore the long-press. Prefer a tiny offline glossary over live dictionary APIs.
- If a page has an image: show it on page entry (tap to continue) and keep a small
  replay tile (corner) to reopen it.

### Write (picture spelling)

- Sizable library of recognizable icons (`words.json` + art).
- On entry: narrate letter-by-letter, then the word; show the picture.
- Player taps letters on the alphabetic board (case follows the word).
- Tap the picture → repeat letter-by-letter then word.
- On completion: spaced word, affirmative VO, then letter-by-letter gold/bold
  celebration. **Next word** tile always available.

Sketch / freehand letter shapes are **not** part of Write launch — see Letters &
Numbers roadmap.

## Roadmap (not fully on every kiosk yet)

| Activity | Doc |
|----------|-----|
| Letters & Numbers (trace shapes) | [`STRATEGY_LETTERS_AND_NUMBERS.md`](STRATEGY_LETTERS_AND_NUMBERS.md) |
| Voice to Writing (ASR + pencil) | [`STRATEGY_VOICE_TO_WRITING.md`](STRATEGY_VOICE_TO_WRITING.md) — **home tile shipped**; hub ASR deploy for phone |

## Device note — stylus

Kiosk is **moto g play (2024)** — capacitive LCD. Finger-first. No active pen.

## Related

- Aesthetic: `../math_explorer/docs/STRATEGY_MATH_EXPLORER.md`
- Plan: `IMPLEMENTATION_PLAN_LANGUAGE_EXPLORER.md`
