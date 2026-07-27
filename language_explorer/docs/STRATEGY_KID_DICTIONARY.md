# Kid dictionary — feasibility note

*Shipped with the 2026-07-26 Read companion pivot.*

## Verdict

**Feasible offline** for the current book set. No Merriam-Webster scrape required.

| Approach | Status |
|----------|--------|
| Live Merriam-Webster API | Skipped (licensing + network) |
| Full kid dictionary dump | Not needed yet (~54 unique book tokens) |
| Custom glosses for shipped books | **Done** — `game/data/definitions.json` |

## How it works

- Long-press a word in `BookReader` → `LangData.definition_for(word, lang)`.
- If a gloss exists, Narrator speaks it (baked ElevenLabs clips in the VO manifest).
- If missing, long-press is a no-op (no error VO).

## Growing the glossary

When ingesting new books, extract unique tokens and add short kid-friendly lines under
`en` / `es` in `definitions.json`, then re-run `tools/gen_vo.sh`.
