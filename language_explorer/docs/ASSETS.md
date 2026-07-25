# Language Explorer — Assets

Provenance and packing notes for art, books, video, and VO.

## UI / console

| Need | Source | License |
|------|--------|---------|
| Buttons, frames, icons | Kenney UI Pack | CC0 |
| Read / Write tile icons | Agent-generated flat icons or Kenney | CC0 / original |
| Theme colors | Fork of Math Explorer `MathTheme` | original |

## Sprites & word images

| Need | Source | Notes |
|------|--------|-------|
| Sentence sprites | Flat storybook set (Math-style) | Magenta-key via `tools/key_sprite.py` when added |
| Write cue images | Kenney / CC0 object packs | One image per `words.json` entry |

## Books

Tracked in `tools/books.tsv` and credited in `BIBLIOGRAPHY.md`.
**Ship only after license verification** (US public domain preferred).

Candidate pools:
- Project Gutenberg (children’s / juvenile; Spanish PD shelf)
- Library of Congress free-to-use plates (illustrations)
- Standard Ebooks where public domain

## Video

Short sentence play-outs under `game/videos/sentences/`. Prefer game-generated sprite
animations; optional trimmed clips via `tools/media.tsv` + ffmpeg (Theora `.ogv`).

## Narration

ElevenLabs bake (`tools/gen_language_vo.py`), shared family key at
`../ant_explorer/tools/secrets/elevenlabs.env`. Model: multilingual v2 for EN+ES.
