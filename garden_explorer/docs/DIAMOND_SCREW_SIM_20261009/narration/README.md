# The Circle of Diamonds and Tesseracts — single-voice narration

Source: `../FABLE_CIRCLE_OF_DIAMONDS_AND_TESSERACTS_20261009.md`, read as written (§0–§12, both score tables, the closing line).

Output: `fable_circle_narration.mp3` (and `.wav`, 24 kHz mono). `spoken.txt` is the exact text that was sent, paragraph by paragraph.

## Voice

Matilda `XrExE9yKIg1WjnnlVkGX` — the narrator used across star_learning (`solar_system_explorer/tools/gen_solar_vo.py`,
`tools/journey/journey.py`, `ant_explorer/tools/gen_vo.py`). `eleven_multilingual_v2`, stability 0.55, similarity 0.75, speed 0.92.
One voice for everything; speaker labels are spoken ("Feynman: …") because there is no voice change to carry them.

## What is read

- Title, subtitle, header block, section headings ("Zero. The Room", "1. Who Begins", …).
- Every narrative paragraph and stage direction. `**FEYNMAN** (tapping the left column):` → "Feynman, tapping the left column: …".
- `**McCLANE:** (writes) *Imhotep: 1. It's standing.*` → "McClane writes: Imhotep: 1. It's standing."
- Score tables row by row: "Kant: 3. Incongruent counterparts; …", "Einstein: no points. Not invited."
- Audibility only: `20261009` → 2026-10-09, `§` → section, `½` → one half, `−∞` → minus infinity, `1 + ?` → one, plus a question mark.

Pauses: 1.4 s before a heading, 0.6 s between paragraphs, 0.35 s between table rows, 1.2 s before the closing line.
Each paragraph is sent with `previous_text` / `next_text` so the prosody carries across the cut.

## Commands

```
python3 narrate.py text    # print the spoken script, no API calls
python3 narrate.py tts     # synthesize -> parts/<hash>.wav (cached; re-running only does changed paragraphs)
python3 narrate.py join    # concat with pauses -> fable_circle_narration.wav / .mp3, spoken.txt
python3 narrate.py all
```

Key: `star_learning/ant_explorer/tools/secrets/elevenlabs.env`. ~26.6k characters per full build.
Edit the fable and re-run `all`: only the paragraphs whose text changed are re-synthesized.
