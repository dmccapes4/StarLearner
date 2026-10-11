# OurMercilessJourney v0.0.1 — reflection and ledger

**Written by:** the agent, 2026-10-10 ~15:00, after watching the frames and the board
**Delivered:** `OurMercilessJourney_v0.0.1.mp4` — 17.7 min, 1920×1080, 30 fps, H.264 + AAC, 17 chapters, 67 shots, three ElevenLabs voices
**Build:** `tools/journey/journey.py all` (script → tts → render → assemble → storyboard); `.venv` user-local; no sudo

## 1. What was asked and what was built

| requested | built |
|---|---|
| pygame for sim clock, frames, rendering | Every frame is a pygame `Surface` written raw to ffmpeg. `pygame.time.Clock` ticks; the frame counter is the master clock; each shot declares a sim rate (or a span to fit) and the scenes sample DE421 at that sim time. CH11 runs the Hill-sphere leapfrog *inside the render loop* — the integrator's clock is the video's clock (t, steps, dt, alive count printed live). |
| OurMercilessJourney explained in sequence | CH00–CH16 in chat order: rule (09-20) → frame (09-27/28) → light path (09-28) → axiom (10-10 01:32) → tests → relaxed axiom → 42 Pis → deliberate error → eliminating → annulus → 43″ → ladder/Planet X → BepiColombo → the other loop → not yet. The board strip closes row by row as the narration reaches each kill. |
| refer to this chat, go far back | 23 operator turns quoted verbatim (or `[…]`-marked) with date and transcript line, shown on receipt cards and read in the OPERATOR voice. Earliest: 2026-09-20 16:21. |
| game plan md first | `GAME_PLAN.md` written and receipts verified against the JSONL before any code. |

## 2. Numbers

- 67 shots · 12,697 characters spoken · 16.8 min of speech · 17.7 min with pads
- 32,778 frames · render 5 m 28 s wall (≈100 fps headless) · final 58 MB
- 70 distinct data sources pulled into narration/HUD (`NUMBERS_AUDIT.md`); 10 are `LIT:` literals with a stated source (published orbit altitudes, MOI date, the review's headline numbers, this run's Mars station dates)
- ElevenLabs: 12,697 characters, `eleven_multilingual_v2`, one pass, cached by text hash (`COST.md`)

## 3. Deviations from the game plan — stated, not hidden

| planned | done | why |
|---|---|---|
| 9–11 minutes | 17.7 minutes | The script came out at 12.7k characters, not 8.5k; the narrator's speed 0.92 made it longer still. Cutting after TTS would mean paying twice; v0.0.1 ships long. Next version: tighten CH04/CH07/CH11 narration or set speed 1.0. |
| one file per chapter in `chapters/` | one module `chapters.py` with a `CHAPTER_CLASSES` registry | Fewer imports to keep in sync for a first cut. Appending is still one class + one list entry; the per-chapter clip cache works on the class source hash, so a new chapter re-renders only itself. |
| board cell changes "on the exact word" | changes at a per-shot fraction `board_at` | Word-level timing would need alignment data from the TTS; a fraction placed where the kill sentence falls is within ~1 s. |
| 1.5 s pad at chapter boundaries | 1.0–2.0 s on chronicler lines only | Simpler; reads fine. |
| storyboard "contact sheet per chapter" | done (`storyboard/CHxx.png`, `STORYBOARD.md` with narration under each sheet) | — |

## 4. Errors made while building — ledgered

1. **Receipts index off by one.** The first draft of GAME_PLAN §9 used indices from the summary's enumeration (3076, 3136 …); the JSONL lines are 3077, 3137 …. Verified against the file, corrected, noted in §9. One quote I remembered ("Do not fake anything at all") could not be found and was removed. The 2026-09-20 quote was also shortened in memory; the verbatim line is "Do not make fake videos. Mars retrograde 555 CE. […] Do NOT make fake videos EVER in this platform. […] High fidelty!".
2. **Board keys turned to strings by JSON.** `script.jsonl` round-trips the per-shot `board` dict; row numbers came back as `"1"`, so `states_before()` built states that no scene could read — CH10's full board showed every row "open" in the silent preview. Fixed in `load_script()`; verified in the final frames (CH10 at 10:01 shows 7 closed, 1 moot).
3. **`convert_alpha()` with no display.** Headless pygame has no video mode; the figure blit crashed on CH12. Replaced with a plain load + per-size cache.
4. **A dummy expression in CH05's narration.** My first draft computed the tangential acceleration with a `* 0 + 1.86e-5` placeholder — exactly the "typed from memory" habit the game plan §5 forbids. Replaced before TTS with the JSON value (`required_vs_available_acceleration/charon_scaled/tangential_required_ms2_max` = 1.9e-5), spoken as words.
5. **Missing glyph.** IM Fell has no `″`; the CH12 title rendered a box. Title changed to "The 43 arcseconds".
6. **`fmt()` on separations.** "40,223.1 kilometres" in speech is noise; `fmt` now rounds anything ≥ 1,000 to an integer.

## 5. What the live integrator showed

CH11's three live shots last 79.4 s at 4 days per second, so the integrator reaches 317.5 days (3.6 Mercury years) on screen. Re-running `HillLive` to that time after the render: 28 of 112 particles escaped — 19 prograde, the innermost at 81,473 km, and 9 retrograde, the innermost at 136,457 km. The 100-Mercury-year JSON has 31 escapes with the same prograde edge (81,473 km); its three extra escapes are the slow retrograde ones (119,950 km at 7,649 d; 155,235 km at 4,487 d; 176,598 km at 2,114 d), beyond this run's reach — the on-screen caption says the live run is shorter and quotes the JSON edges. The assertion on the indirect solar term passes at construction. Nothing on screen is a recording.

## 6. What I would be merciless about next

- The CH07 inset (Earth–Moon at ×40 with the facing half in red) is small and busy; it carries the 97.9 % claim and should be a full shot.
- CH02's tilt animation is six seconds; the B₀ curve under it is tiny. The frame rule is the spine of the whole work and deserves a slower chapter.
- The narration says "the operator" throughout; the operator may prefer a name on screen. One line to change.
- The OPERATOR voice reads profanity-stripped quotes where the card shows `[…]`; the cards are honest about it, but a listener does not see the card. Consider reading "SOL." alone for 2202 (done) and marking spoken abridgements with a short tone.
- CH15's comparison table is the only chapter with no simulation at all. It could show their PCA sphere and our orrery side by side, both rotating at the same clock.

## 7. Authorship

Operator: the name, every quoted line, the frame rule, the no-fake rule, the no-myth rule, the "add onto it" mechanism as a requirement. Agent: the chapter cut, the board strip, the three-voice casting, the integrator-as-clock reading of feature 1, the chronicler's lines, and every mistake in §4.
