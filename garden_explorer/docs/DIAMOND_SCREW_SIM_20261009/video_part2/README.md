# Hume v. Spock — Part Two video (pygame build)

Source text: `../FABLE_HUME_V_SPOCK_20261010.md` (narrated verbatim; every shot's caption is the exact spoken text).
Output: `fable_hume_v_spock_pg.mp4` — 1920×1080, 30 fps, ~79 min.

## How it is made

| Stage | Script | What |
|---|---|---|
| parse | `build_video.py parse` | fable → 519 shots (sentence-bounded ≤230 chars; quoted text = the speaker, the rest = narrator; tables → cards; `types:` → ledger) |
| tts | `build_video.py tts` | ElevenLabs `eleven_multilingual_v2`; Matilda narrates, one distinct voice per speaker (see `VOICE` in `build_video.py`); → `audio/S###.wav` |
| plates | `plates.py` | 12 backdrop paintings (gpt-image-1, places only — no people, no text): bench wall, witness wall, gallery, alcove, passage, yard, lab bench, space, sand circle, Hume's desk, the glove bag, the mountain |
| render | `pg_video.py render --jobs 4` | pygame, headless, every frame piped raw into ffmpeg; 4 parallel chunks → `parts/`, concat + narration mux |

Palette: dark greens, magentas, crimsons, plum, ember orange on near-black.

### What is on screen

- **Stage (1440×900)** — either a plate with a slow push-in and geometry puppets (scribbled faces, arms rotated in animation while that character speaks), or an animated **contrivance demo** keyed to the line being spoken:
  the balance and two lumps · Torricelli's tube filling, flipping, dropping to 76 cm · Périer climbing the Puy de Dôme with the column falling 8 cm · Fahrenheit's sealed thermometer over a flame · Celsius's hundred-step stair and its inversion · Goldmann applanation on an eye (3.06 mm → mmHg) · Hg/Au/Pb in tubes with heat · the gold brick landing hard and deforming beside mercury splashing · a circuit with a gold contact · X-rays stopped by a lead plate · gold on the planet Mercury (open row, BepiColombo) · the oscilloscope: the reading vs. the plaintiff's noise · the rope trick thrown at Mercury · Mercury's precessing perihelion, Vulcan proposed and crossed out · Lescarbault's transit · the 2.4 % Luna bar · Einstein's three refutations (43″, 1.75″ at the limb, +38 µs/day clocks) · Newton's apple and Luna on the same rope · Bessel's parallax · Kant's glove turned through the fourth direction · time as the count of marks (hourglass, C‑14 stair, tally) · Grimm's sound shift · Marconi's S off the sky · the verdict ledger · the kids going out to play.
  Triggers live in `TRIG` (section, regex, demo, hold) in `pg_video.py`.
- **Ledger column (480 px)** — Widukind at his typewriter in the alcove, colour cycling per shot (never mentioned, never moves except to type); below him the receipts type themselves in as they are spoken (`RECEIPTS`, plus every `Widukind types:` line).
- **Caption band** — speaker name and the exact text.
- Ending: Widukind types the last line, signs `— Widukind of Corvey`, pulls the sheet, and the room goes dark.

### Commands

```bash
PY=/home/dylanmccapes/dev/BeginningToNoww/.venv/bin/python3     # has openai, PIL, pygame
$PY build_video.py parse            # shot list / coverage
$PY build_video.py tts              # ElevenLabs (skips existing wavs)
$PY plates.py                       # backdrops (skips existing)
$PY pg_video.py demos               # one still per demo → preview/demos/
$PY pg_video.py preview S054,S118   # composed frames → preview/
$PY pg_video.py plan                # which shot gets which demo / receipt
$PY pg_video.py render --jobs 4     # the film
```

`build_video.py` also still carries the earlier one-painting-per-shot pipeline (`scenes`, `images`, `audit`, `frames`, `video`); it is not used by this build. `scenes.json` from that path is kept for reference.
