# Strategy — Letters & Numbers (shape practice)

*Roadmap only. Not in the v1 launch shell (Read + Write only).*
*Date: 2026-07-26 · Audience: ~6yo on Star Learner kiosk · Engine: Godot 4.3*

## Why this is deferred

The player is already strong at letter/number shape recognition. Launch focus is a
**reading companion** (books) and **spelling from pictures** (write). This activity
stays planned so the console can grow without bloating the home screen.

## North star

Practice the *shape* of letters and numbers with finger tracing. Hear the name,
see a grey outline, fill it until it locks gold, then move on.

## Home tile (when shipped)

One generated cinematic tile: chalk slate / finger drawing a glowing capital letter
and a numeral, same nest-star lighting language as other kiosk tiles. Label under
tile: `shapes` (or `trace`).

## Flow (locked intent)

1. Enter → narrate: “Choose letters or numbers.”
2. Two large icon tiles: **Letters** | **Numbers**.
3. Either mode:
   - Present one glyph (letter: upper or lower; number: 0–9).
   - Narrate: “upper case A” / “lower case t” / “seven”.
   - Drawing pad with a **grey outline** of that glyph.
   - Finger stroke paints over the outline (need not be contiguous).
   - When coverage is “close enough,” outline thickens to black, then turns **gold**.
   - Affirmation VO → wait ~2s after VO ends → next glyph.
4. Always-visible **next** tile skips to the next glyph anytime.

## Coverage scoring (proposed)

Reuse / evolve `TraceCanvas` from Language Explorer write-sketch:

| Approach | Pros | Cons |
|----------|------|------|
| A. Zone ink length (current sketch) | Already shipped | Weak for closed shapes (O, 8) |
| B. Distance-field / template mask | Robust | More code |
| C. Sample points along outline | Simple, tunable | Needs good templates |

**Recommendation:** B for letters/numbers — one bitmap mask per glyph; score =
fraction of mask cells with ink within N px. Threshold ~55–70%, tunable per glyph.

## Content inventory

- Letters: A–Z and a–z (EN); add Ñ/ñ for ES when lang is Spanish.
- Numbers: 0–9.
- Order: random without immediate repeat, or A→Z then shuffle.

## Narration

Bake short lines via existing ElevenLabs pipeline:

- “Choose letters or numbers.”
- “Upper case {letter}.” / “Lower case {letter}.”
- “{number}.” (zero…nine)
- “Great!” / “You got it!” (reuse LangVo)

## Out of scope for this activity

- Spelling words (that is Write).
- Reading books (that is Read).
- Voice dictation (see Voice-to-Writing strategy).

## Acceptance (when built)

- [ ] Home has a fourth tile only after Read/Write are solid.
- [ ] Letters and numbers modes share one pad + next tile.
- [ ] Grey → black → gold is obvious without reading UI chrome.
- [ ] Next tile never blocked by busy VO for more than the current utterance.
- [ ] Works offline with baked VO.

## Related

- Current sketch prototype: `game/scripts/write/TraceCanvas.gd`
- Console two-mode north star: `STRATEGY_LANGUAGE_EXPLORER.md`
