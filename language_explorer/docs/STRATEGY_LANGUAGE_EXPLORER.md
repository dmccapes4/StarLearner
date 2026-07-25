# Language Explorer — Strategy

*Intent and UX detail. Build order and acceptance criteria live in
`IMPLEMENTATION_PLAN_LANGUAGE_EXPLORER.md` — that plan wins on conflicts.*

## North star

Letters and words should be **things you can hear and touch**, not silent symbols.
English and Spanish share one console and one visual grammar (red target → gold spelling →
green done).

## Audience

One ~6-year-old on a Star Learner kiosk. One finger. Warm narration. No scolding.
Reading is the *subject*, not a gate on the controls — icons + speech lead.

## Modes (summary)

See the implementation plan §5 for the locked choreography of Read Sentences, Read Books,
Write Images / Narration (with **sketch** or **alphabet-tile** letter input), and the Record
roadmap.

### Write letter-input (locked intent)

1. **Sketch** — grey letter outlines; finger (optional passive capacitive stylus).
2. **Alphabet tiles** (default) — ABC-ordered large tiles (not QWERTY); `A | a` buttons; case
   follows the word (`Apple` → upper then lowers). Grey underlines = slots above the board.
   Wrong tiles go red/locked; after three wrongs or three hints the correct tile goes gold and
   everything else greys out.

## Device note — stylus

Kiosk is **moto g play (2024)** — capacitive LCD, no stylus digitizer in Motorola’s specs.
Finger-first; a cheap capacitive stylus may help sketch mode but is not required. Do not plan for
active pens (those belong on the separate *moto g stylus* line).

## Open copy to fill in Phase 0

- Exact intro-tour lines (EN + ES).
- Letter-name inventory for Spanish (`A`, `B`, … `Ñ`, accented vowels).
- Kind incorrect lines (3–5 variants, both languages).
- Write alphabet intro lines (image-tap hint vs clear-icon hint).
- Tutorial scripts for hamburger entries.

## Related

- Aesthetic reference: `../math_explorer/docs/STRATEGY_MATH_EXPLORER.md`
- Fleet inference roadmap host: system **245** (see plan §8)
