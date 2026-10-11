# The Circle of Diamonds and Tesseracts — educational video (v2)

Source text: `../FABLE_CIRCLE_OF_DIAMONDS_AND_TESSERACTS_20261009.md` (Part One, §0–§11).
Output: `fable_circle_of_diamonds_and_tesseracts.mp4` (1920×1080, 24 fps, H.264 + AAC).
The first build (ink-and-ember style, paraphrased narration, 82 shots) is kept in `v1/`.

## What is read aloud

The fable text, exactly. `build_video.py parse` segments the markdown into shots
of one or two sentences, never splitting a sentence: title, subtitle, header
block, section headings, every narrative paragraph, every stage direction in
parentheses, every quoted line, McClane's written scores, both score tables,
the closing italic line. Only the bold speaker labels (`**FEYNMAN:**`) are not
spoken — the change of voice carries them, and the caption bar names the speaker.
Two audibility substitutions for the TTS only: `20261009` → `2026-10-09`, `§9` →
"section nine"; the caption still shows the exact text.

222 shots: 215 generated images, 7 score-card shots (§10 tables, rows read four at
a time while the card holds), and two silent closing shots.

## Voices (ElevenLabs, `eleven_multilingual_v2`)

| role | voice |
|---|---|
| narrator (everything not in quotes) | Matilda `XrExE9yKIg1WjnnlVkGX` — the voice used across star_learning |
| Feynman | Chris-Law Professor (New York) |
| McClane | Adam |
| Imhotep | Bill |
| Pythagoras | Brian |
| Plato | George |
| Archimedes | Roger |
| Heron | Liam |
| Marconi | Eric |
| Tesla | Callum |
| Copernicus | Chris |
| Franklin | Will |
| Kant | Daniel |
| the horde | Harry |

Key: `star_learning/ant_explorer/tools/secrets/elevenlabs.env` (same file the
other star_learning narration tools use). ~19.2k characters per full build.

## Flavor

Fluid watercolour-and-ink cartoon. Palette strictly the three primaries — red,
yellow, blue, the colours that make brown — laid as wet washes that bleed into
orange, green and violet where they meet. Every face scratched out (characters
identifiable by silhouette, hair, clothing, props). No text inside images.

Scene descriptions are written per shot by gpt-4.1 from the section text
(`scenes.json`, cached; placeholders like `{FEYNMAN}` are expanded from `CHAR`).

## The chronicler

High on the back wall, in a small arched alcove at the top centre of every
picture, a small motionless figure sits at a lectern writing in a large book.
He is a flat silhouette of a single pure colour, and that colour switches shot
by shot through the rainbow (red → orange → yellow → green → blue → indigo →
violet, repeating). He is never named or mentioned in the narration. The
right-hand panel of each frame is his record: the actual statements, verbatim,
as they are made (speaker, then the words), newest at the bottom and darkest.
The small colour swatch at the top of the panel matches his colour in the shot.

After the last line of the fable there are two silent shots: he signs the record
(`— Widukind` appears under the last entry) and closes the book.

## Frame layout

`1920×1080`: image 1380×920 top-left · record panel 540 px right (parchment,
Caveat handwriting) · caption bar 160 px bottom (IM Fell English; speaker name
in red for quoted lines; headings in italic). Fonts in `fonts/` (Google Fonts, OFL).

## Build

```
PY=BeginningToNoww/.venv/bin/python3          # from /home/dylanmccapes/dev
$PY build_video.py parse          # print the segmentation, no API calls
$PY build_video.py scenes         # gpt-4.1 → scenes.json
$PY build_video.py images         # gpt-image-1 1536×1024 medium, 4 threads → images/
$PY build_video.py fixloop 3      # gpt-5 audit (faces / text / chronicler high at back) → regenerate → re-audit
$PY build_video.py tts            # ElevenLabs → audio/
$PY build_video.py frames         # frames/
$PY build_video.py video          # clips/ → mp4
$PY build_video.py story          # storyboard_NN.png, STORYBOARD.md, shots.json
--only S012,S160                  # restrict any stage
```

All stages are idempotent and cached; delete a file to force regeneration.
Rejected images are kept in `images/rejected/`.

## Part Two

Not produced. Outline and checked hooks in `PART_TWO_NOTES.md`.
