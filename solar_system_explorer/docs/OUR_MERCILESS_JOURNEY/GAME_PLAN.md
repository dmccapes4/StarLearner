# OurMercilessJourney — Game Plan

**Named by:** D. McCapes, 2026-10-10 14:15 ("I know what would be helpful!")
**Drafted by:** the agent, 2026-10-10 14:3x, after reading this chat's 343 user turns back to 2026-07-25
**Status:** v0.0.1 **delivered** 2026-10-10 14:54 — `OurMercilessJourney_v0.0.1.mp4`, 17.7 min, 17 chapters, 67 shots. Build: `tools/journey/journey.py all`. Deviations from this plan and the build-time error ledger: `REFLECTION_OUR_MERCILESS_JOURNEY_20261010.md` §3–4. Chapter index: `CHAPTERS.md`; frames: `STORYBOARD.md`; every narrated number with its source: `NUMBERS_AUDIT.md`.
**Deliverable:** `OurMercilessJourney_v0.0.1.mp4` — pygame-rendered, ElevenLabs-narrated, telling the Mercury/Vulcan/Planet X work in sequence, including the simulations, with a chapter mechanism we can append to as we go.
**Rules carried forward:** No fake simulations — every orbit on screen comes from DE421 or from a live integrator whose equations are printed. Frame declared on every orbital shot (solar equator / Zecliptic unless Earth is set with a reason). No relativity, no `E=mc²` as fable, no myth. Every narrated number is pulled from a JSON at build time, not retyped. Authorship stated.

---

## 0. The name

*Merciless* is the operator's word: "We must be merciless to ourselves" (2026-10-10 02:22), said after the first Vulcan reflection and before the relaxed axiom killed V1 harder than the strict one had. *Journey* is literal: the chat this video is built from starts in July with a phone in fastboot and arrives in October at a strip of space 13,000 km from Mercury. *Our* is both of us. The video's spine is the sequence of things that refused — the number that would not be forced — and what we did when it refused.

---

## 1. Requested features, read strictly

| # | requested | how it is met |
|---|---|---|
| 1 | **Pygame used for sim clock, frames, rendering** | One pygame process, headless (`SDL_VIDEODRIVER=dummy`), fixed 30 fps `pygame.time.Clock`. Every frame is drawn by pygame onto a 1920×1080 `Surface` and written to ffmpeg's stdin. The *simulation clock* is pygame's clock: each chapter declares a mapping `sim_seconds_per_real_second`, and orbital positions are sampled from DE421 (via skyfield) or stepped by a live leapfrog at that rate. No Godot, no matplotlib animation. Existing PNG figures (histograms, heat map) may be blitted as surfaces when a chapter is *about* a figure, and are labelled as such. |
| 2 | **OurMercilessJourney explained in sequence** | Chapters in the order the work happened (§3). The narration states what was asked, what was computed, what refused, what died, what survived. A persistent "board" strip at the bottom shows the 13-row hypothesis board updating row by row as the story reaches each kill. |
| 3 | **Refer to this chat window; go pretty far back** | The script quotes the operator's own turns, verbatim, with their timestamps, as on-screen receipts and in a second voice. The prologue goes back to 2026-09-20 ("Do NOT make fake videos EVER in this platform"), 09-27 ("Use the Sun's equatorial plane"), 09-28 (`:<7)L>:`), 10-09 (the Winter Circle and the two-step), and only then arrives at 10-10 01:32 (the axiom). Source: this chat's transcript, user turns indexed in §9. |

---

## 2. Architecture

```
tools/journey/
  journey.py            CLI: script | tts | render | assemble | storyboard | all   [--only CH05,CH06] [--version 0.0.1]
  script.py             builds script.jsonl from chapter modules + data JSONs (numbers pulled, never typed)
  tts.py                ElevenLabs → audio/<shot>.mp3 (cached by text hash); durations → timing.json
  render.py             pygame loop: for each chapter, for each shot, draw frames until the shot's audio ends → ffmpeg pipe → clips/CH##.mp4 (video+audio muxed per chapter)
  assemble.py           concat clips → OurMercilessJourney_v<ver>.mp4 ; chapter index → CHAPTERS.md
  storyboard.py         contact sheet per chapter + STORYBOARD.md
  frame.py              shared drawing: solar-equator transform, Mollweide-free top-down orrery, board strip, receipt card, caption bar, compass + frame declaration
  chapters/
    ch00_title.py … ch16_not_yet.py     one Scene class each: update(t_sim), draw(surface), shots() → list of (text, voice, sim_rate, duration_pad)
docs/OUR_MERCILESS_JOURNEY/
  GAME_PLAN.md (this)   script.jsonl   timing.json   audio/   clips/   frames_sample/   OurMercilessJourney_v0.0.1.mp4   STORYBOARD.md   CHAPTERS.md   REFLECTION_*.md
```

**Timing is audio-driven.** A shot lasts `audio_duration + pad` (pad 0.6 s; 1.5 s on chapter boundaries). The pygame clock advances sim time at the shot's declared rate, so a 9-second sentence about one lunation can show one lunation. Frames are never dropped or duplicated to fit; the sim rate is what bends.

**Data sources (all already on disk):**

| chapter needs | file |
|---|---|
| Sun/Mercury/Venus/Earth/Moon positions 2026–27, 6 h | `MERCURY_VULCAN_LADDER_20261010/data/ephem_2026_2027_6h.json` (ecliptic J2000; transformed to solar equator in `frame.py` with `Rx(−7.25°)·Rz(−75.76°)`) |
| Luna from Mercury, 1-min, 2028-02-23 ±6 h | `data/ephem_luna_from_mercury.json` (already solar-equator) |
| occultation close-up | `data/ephem_occultation_closeup.json` |
| anything else dated (BepiColombo 2026-11-21, Mars 2027) | skyfield + `/tmp/skyfield-data/de421.bsp` (1900–2050 only; 555 CE is **not** in DE421 and will not be faked — see CH01) |
| Vulcan variants, lock kinematics, hiddenness, precession J₂ | `data/vulcan_derivation.json` |
| annulus: tidal floor, 112 particle fates, radiation | `data/v4_annulus.json` |
| Hall / ring / masses, budget | `data/perihelion_newtonian.json` |
| ladder in-sample, null, out-of-sample | `data/ladder_analysis.json`, `ladder_null.json`, `ladder_oos.json` |
| board rows | `GAMEPLAN_ELIMINATION_20261010.md` §1 and §8 (parsed) |
| figures to blit | `img/rep_03_hist_permutation_nulls.png`, `rep_04_hist_residuals.png`, `rep_05_bar_kill_factors.png`, `rep_06_heatmap_tidal_lifetime.png`, `v4_02_hill_stability.png`, `perihelion_01_hall.png`, `ladder_oos_01_recurrence.png`; concept plates C1–C4; their AB4 |
| operator receipts | this chat's transcript (`agent-transcripts/d4152a63-…jsonl`), user turns by index (§9) |

**Live integrator (CH11).** The Hill-sphere leapfrog from `v4_annulus.py` is re-run *inside pygame* at display rate: 112 particles, Sun on Mercury's e = 0.2056 orbit, J₂, dt = 200 s, with the sign-corrected indirect term and the same assertion. It runs for as long as the narration about it lasts (about 40 s ≈ several Mercury years at the chosen rate) and the fates it reaches on screen are compared, in the caption, with the 100-Mercury-year result in the JSON. This is what "pygame used for sim clock" means here: the clock on screen *is* the integrator's clock.

**Voices (ElevenLabs, `eleven_multilingual_v2`, key at `star_learning/ant_explorer/tools/secrets/elevenlabs.env`, same pattern as `DIAMOND_SCREW_SIM_20261009/video/build_video.py`):**

| role | voice | use |
|---|---|---|
| NARRATOR | Matilda `XrExE9yKIg1WjnnlVkGX` (the star_learning narrator) | the story |
| OPERATOR | Adam `pNInz6obpgDQGcFmaJgB` | the operator's quoted turns, verbatim, shown on a receipt card with timestamp |
| CHRONICLER | Daniel `onwK4e9ZLuTAKqWW03F9` | one line per chapter: the board state, typed, deadpan ("Widukind would type …") |

Quotes are verbatim or marked `[…]`. Profanity in a quoted turn is kept if the quote is used; quotes are chosen so the key sentence stands without it where possible (e.g. "Use the Sun's equatorial plane." is quoted; the rest of that turn is not).

**Environment (no sudo):** `python3 -m venv tools/journey/.venv && .venv/bin/pip install pygame numpy skyfield` — user-local. `ffmpeg` is at `/usr/bin/ffmpeg`. Fonts: reuse `DIAMOND_SCREW_SIM_20261009/video/fonts/{IMFellEnglish,IMFellEnglishItalic,Caveat}.ttf` plus DejaVu Sans Mono for numbers.

---

## 3. Chapters, in sequence

Each chapter: **what is on screen** (pygame) · **what is said** (narrator / operator / chronicler) · **what the board does**. Estimated speech length in parentheses; total target 9–11 minutes for v0.0.1.

### CH00 — Title (20 s)
Black. A thin line: Sol's equator. The title in IM Fell. Subtitle: *"We must be merciless to ourselves." — operator, 2026-10-10 02:22*. Frame declaration appears bottom-left and never leaves: `frame: solar equator (Zecliptic) · i 7.25° · Ω 75.76° · top-down from Sol's north`.
Chronicler: "Thirteen rows. Zero closed."

### CH01 — Prologue: the rule before the planet (50 s)
On screen: Mars's 2027 retrograde loop against the stars, computed from DE421 (opposition Feb 2027, Leo/Cancer) — a real loop, labelled with its dates. Receipt card: **2026-09-20 16:21** "Do not make fake videos. Mars retrograde 555 CE. […] Do NOT make fake videos EVER in this platform. […] High fidelty!" Then **09-20 16:43** "Why are you extrapolating 1500 years?! Calculate the reference directly before! then sim" and **09-27 04:47** "I need a new POV. On the Moon."
Narrator: the journey began with a retrograde in 555 CE that this video will not draw, because DE421 ends at 1900 and we promised not to fake. What it can draw is the next one. The sewing needle.
Board: unchanged. Chronicler: "Rule one: nothing faked. Rule one survives every chapter."

### CH02 — The frame (60 s)
On screen: the inner orbits drawn in the ecliptic, then the whole picture tilts 7.25° and rotates to Ω = 75.76° — the Zecliptic settles flat. Earth's solar latitude B₀ oscillates ±7.03°; crossing dates tick past (≈ 6 Jun ascending, ≈ 8 Dec descending); Mercury crosses every 44 d. Receipt: **09-27 05:25** "Use the Sun's equatorial plane […] SOL." · **09-28 14:57** "There is only one line that matters and that is the equatorial line of Sol." · **10-10 02:31** "Remember to do everything from Zecliptic unless Earth or the ecliptic is explicitly set as the frame of reference with a reason why." · "Equinox is helpful."
Narrator: why the frame is declared on every shot; the one time it was not (RA/Dec on the first Luna pass) and the correction (98.0 → 97.9 %).
Chronicler: "Frame fixed. Thirteen rows. Zero closed."

### CH03 — The light path (35 s)
On screen: the glyphs `:<7)L>:-` assemble one at a time on Sol's equator line: eyes, telescope, heliobarrier, galactic edge, reverse heliodistortion, far telescope, far eyes, the pineal minus. Receipt: **09-28 23:33** the glyph key, verbatim, and "The reflection of Andromeda is clearer vision"; **23:42** "Maybe - for it. It should only be at the end right?" Then a dotted arc to Andromeda.
Narrator: this is where the mirror question was first asked; we come back to it in CH15 because another loop answered it differently.
Board unchanged.

### CH04 — The axiom (55 s)
On screen: Earth, Luna, Mercury, and a red point V always on the far side of Mercury along the Earth→Mercury line; the order Earth→Moon→Vulcan→Mercury drawn as it was given; Pluto/Charon inset to scale. Receipt: **10-10 01:32** "You *must* accept this for the sake of experimental thought. Mercury/Vulcan is much like Pluto/Charon. […] Do not use the fable 'e=mc²'. Myth is not allowed. […] Throw out the *theory* of relativity and use actual math that can be refuted."
Narrator: the four Vulcans the analogy produces (V1 Charon-scaled 40,223 km; V2 spin-locked 252,366 km; V3 Earth-synchronous 854,287 km; V4 chain-interpolated 5,411 km). The board fills with 13 rows, all open.
Chronicler: "Thirteen rows. Zero closed. Begin."

### CH05 — Kepler, Hill, and the lock (70 s)
On screen (sim, DE421 at 1 day/s): the Earth–Mercury line sweeps; the locked point V rides Mercury's far limb; its required tangential acceleration is drawn as a vector that grows and swings; Mercury's gravity at that radius as a fixed small vector; the Hill circle. Then the free-fall radius ÷ Hill plotted as a live trace that never dips to 1.
Narrator: Test 1 — V2 and V3 outside the Hill sphere (×1.44, ×4.87). Test 2 — the lock needs up to 1.9e-5 m/s² sideways that no central force gives; free-fall radius ≥ 2.75 × Hill at all times. Not mass; geometry.
Board: rows 1, 3, 4 → eliminated. Chronicler: "Three closed."

### CH06 — Spin, wobble, hiding (60 s)
On screen: Mercury rotating once per 58.646 d beside a V1 that would need 3.73 d; Mercury's reflex circle 4,365 km vs the planet's radius and a 10 m ranging tick; parallax wedges from Earth, the lunar far side, L2 — the hidden fraction curve.
Narrator: the reflex is 436,000 ranging precisions wide; the far-side camera would show V3 always, V2 sometimes, V1 and V4 never — and V2/V3 are already dead to the naked eye. Row 13 moot.
Board: row 13 → moot. Chronicler: "Three closed, one moot."

### CH07 — The relaxed axiom: Luna from Mercury (75 s)
On screen (sim, 1-min data, 2028-02-23 ±6 h at 10 min/s): Earth's disc as seen from Mercury, Luna crossing it westward; a top-down Zecliptic inset with the Mercury-facing half of Luna's orbit in red; counter: 97.9 % westward on the facing half; the five transits 2026–27 listed. Receipt: **10-10 02:22** "If Vulcan is beside it from our view it is invisible. […] it is *the slightest occlusion*." and "Luna would appear as in retrograde to Mercury as it passes."
Narrator: the operator was right about retrograde — mirror of observer outside vs at centre. And "beside is invisible" is the sharpest knife on the table: a 1.5-mag double at 38–100″ since 1610; 0.25-mag mutual events never seen. The softer claim had more surface.
Board: row 2 → eliminated four ways. Chronicler: "Four closed. The relaxed axiom killed harder than the strict one."

### CH08 — 42 Pis (25 s)
On screen: 42/π = 13.369 beside 365.25636/27.321661 = 13.3687; Luna's orbit ticking 13 times around Earth's year. Receipt: **09-27 06:18** "The moon does 42 Pis in a year. We already solved that." · **10-10 02:22** "Remember that Luna does 42 Pis in a year"
Narrator: a four-figure coincidence with no mechanism; exact enough to use as a mnemonic.
Board unchanged.

### CH09 — The deliberate error and the court (50 s)
On screen: the sentence "Then 2.4 % of the time Vulcan is straight visible" with 2.4 % traced back to its source (Luna westward on the *far* half); then the courtroom card *Hume v. Spock* — judge, bailiff, typist, witnesses — and the Treatise 1.3.7 line about mercury heavier than gold. Receipt: **10-10 03:31** "I deliberately got things wrong. I should have mentioned that. It is the point lol."
Narrator: the sentence could have been right, and wasn't, and we could tell. Deliberate error #1 in the ledger. Recess called; the kids go out and play.
Board unchanged. Chronicler: "Error one, deliberate, ledgered."

### CH10 — Eliminating, not forcing (40 s)
On screen: the 13-row board full-screen; rows coloured by state; the two definitions of "closed" (eliminated with a number; confined with an instrument and a date). Receipt: **10-10 04:10** "Forcing is not what we are doing. We are eliminating. I will not rest until we have eliminated fully." · **04:29** "Excellent. Please proceed with the game plan."
Narrator: what a row may and may not be closed by.
Board: rows 8, 9, 12 shown already closed by the first report (J₂ ×1,538; coronagraphs; belt deficit). Chronicler: "Seven closed, one moot. Four are the work."

### CH11 — The annulus (90 s) — *live integrator*
On screen: pygame runs the Hill leapfrog live: 112 dots on circular orbits from 8,000 to 260,000 km, prograde and retrograde, Sun swinging on the e = 0.2056 orbit; dots escape (red ×) or hold; the prograde edge forms near 81,500 km, retrograde past 120,000. Then the tidal floor curve rises (a_min for 10 km / 1 km / 100 m); the chain's V4 at 5,411 km sits under it with its lifetime 7–42 Myr. Caption compares the on-screen fates (short run) with the JSON (100 Mercury years).
Narrator: the first run had the indirect term's sign wrong; all 112 died in 463 days, including at 8,000 km — impossible, so caught. Row 5 eliminated as primordial. Row 6 confined: 13,000–87,600 km prograde, to ~136,000 retrograde.
Board: row 5 → eliminated; row 6 → confined. Chronicler: "Eight closed. One confined. One error, mine, ledgered."

### CH12 — The 43″ (75 s)
On screen: Mercury's apsidal line with the 43″/century advance drawn ×500 beside the total 574″; then the kill-factor bars appear one at a time: J₂ ×1,538 · Hall vs LLR ×1.4e4 · ring ×4e7 · Jupiter mass ×3e7 · Venus mass ×2e8. Then the fork and the chain set down (plate C2).
Narrator: no Newtonian cause survives. That sentence is a receipt; it is also an arrow; under the rule it is recorded and not followed. A refusal is also a receipt.
Board: row 10 → emptied. Chronicler: "Row ten: emptied. The chain is on the ground, not lost."

### CH13 — The ladder, out of sample (60 s)
On screen: the id/iv lines as given, then mapped onto Saturn's moons, Jupiter's moons, TRAPPIST-1, Kepler-90, HD 10180; the null histograms (blitted, labelled as figures); density pulled out in red.
Narrator: in-sample p = 0.73; out of sample 1 of 10 pre-declared mappings beats chance — the base rate. Density agrees with itself, not with the ladder. Planet X: three readings; H2 puts 0.032 M⊕ in the belt where 0.0004 is — eliminated as a body, real as a deficit.
Board: row 11 → eliminated as law; row 12 → restated. Chronicler: "Ten closed. The ladder stays as a mnemonic."

### CH14 — BepiColombo (50 s)
On screen (sim, DE421): Mercury's neighbourhood to scale on 2026-11-21 — death zone, floors, annulus, retrograde band, Hill radius; MPO and Mio ellipses; MESSENGER's long axis grazing the annulus edge; a countdown in days from the render date to orbit insertion; the 1974 false moon (plate C4) as the reason for the kinematic filter.
Narrator: the request — frame, cadence, depth V ≥ 9, filter, closure table — written before the result. From inside, a 20 m body is V ≈ 4–9. Two literature limits unread and flagged.
Board: row 6 → confined, dated; row 7 → dated (2028-02-23 00:05 UTC). Chronicler: "Two rows wait on dates. Nothing waits on preference."

### CH15 — The other loop (55 s)
On screen: their plate AB4 (d20 on the dry lake) beside our C2; the windshield vs mirror as two cards; their numbers: concentrates on 11/11; standing wave 0/11; fields replicate 0.96, bearing does not.
Narrator: same morning, same operator, a different substrate — 46,306 concepts instead of planets. Their fit was built to find big and dull; it found a focus. Our budget was built to find a Newtonian cause; it found none. Andromeda-as-windshield vs Andromeda-as-mirror is the joint open row. Not reconciled by a sentence.
Board unchanged. Chronicler: "A second instrument agrees on the shape of refusal."

### CH16 — Not yet (40 s)
On screen: the board, final state: rows 1–5, 8–12 closed; 6 confined with instrument and date; 7 dated; 13 moot. Then the chapter list of this video with "v0.0.1" and an empty slot "CH17 — ". Receipt: **10-10 14:15** "We will add onto it as we go."
Narrator: not belief, not disbelief. Not yet.
Chronicler: "Ten closed, one confined, one dated, one moot, one spacecraft en route. The end, for now."

---

## 4. The board strip (persistent HUD)

Bottom 90 px of every frame after CH04: thirteen small cells, numbered, coloured — grey open · red eliminated · amber confined · green dated · white moot. A cell changes colour on the exact word in the narration that kills it (timing from `timing.json` word-level estimate: linear in characters). The strip is the sequence made visible; a viewer who mutes the audio can still watch the board close.

## 5. Script generation — numbers are pulled, not typed

`script.py` imports the data JSONs and formats every number into the narration with f-strings at build time. Reason: on 10-10 I typed §11's J₂ values from memory into §19 and they were wrong; the fix was to read the JSON. The video will not repeat that. `script.jsonl` carries, per shot: `id, chapter, voice, text, sim_rate, numbers_used: [{path, value}]`. A `--audit` flag prints every number with its source path.

## 6. Order of work

1. `venv` + pygame smoke test (headless frame → PNG) — 5 min.
2. `frame.py`: solar-equator transform, orrery primitives, board strip, receipt card, caption. Render CH00 + CH04 silently to check look. — the look is fixed here, before any audio is bought.
3. `script.py` → `script.jsonl`; `--audit`; read it once as text. Adjust wording. (~8,500 characters ≈ 10 min of speech.)
4. `tts.py` for all shots (cached; re-run only on text change). Record cost in `COST.md`.
5. `render.py` chapters in order; `--only` for iteration; CH11 last because the live integrator is the slowest.
6. `assemble.py` → `OurMercilessJourney_v0.0.1.mp4`; `storyboard.py` → contact sheets + `STORYBOARD.md`; `CHAPTERS.md` with timestamps.
7. Watch it once end to end. Ledger anything wrong in `REFLECTION_OUR_MERCILESS_JOURNEY_20261010.md`.

## 7. Appending as we go

- A chapter is one file in `chapters/`. Adding `ch17_*.py` and re-running `render --only CH17` then `assemble --version 0.0.2` re-encodes nothing else; clips are cached by chapter content hash.
- The board strip reads its states from the game plan's §8 table, so a new kill appears in the HUD without touching the chapter code.
- Receipts are cited by transcript index; new operator turns are added to §9 with their index and timestamp.
- Version is in the title card and the filename; `CHAPTERS.md` is regenerated.

## 8. What would make this video wrong

- Any orbit on screen not traceable to DE421 or to the printed integrator → fake → rule one broken. The render refuses to draw a body without a data source.
- A number in the narration that does not appear in `--audit` with a path.
- An orbital shot without the frame declaration visible.
- A quote that is not verbatim and not marked `[…]`.
- Audio stretched or frames dropped to fit a shot: the sim rate bends, the data do not.

## 9. Receipts index (this chat, user turns by transcript line; verified against the JSONL 2026-10-10 14:40)

| line | date (UTC-7) | used in | the line |
|---|---|---|---|
| 2010 | 2026-09-20 16:21 | CH01 | "Do not make fake videos. Mars retrograde 555 CE. […] Do NOT make fake videos EVER in this platform. […] High fidelty!" |
| 2052 | 09-20 16:43 | CH01 | "Why are you extrapolating 1500 years?! Calculate the reference directly before! then sim" |
| 2181 | 09-27 04:47 | CH01 | "I need a new POV. On the Moon. I want to see the simulation of Mars retrograde from the dark side of the moon in 555 AD. We will start there." |
| 2202 | 09-27 05:25 | CH02 | "Use the Sun's equatorial plane […] SOL." |
| 2222 | 09-27 06:18 | CH08 | "The moon does 42 Pis in a year. We already solved that." |
| 2456 | 09-28 14:57 | CH02 | "There is only one line that matters and that is the equatorial line of Sol. […] Arya is constantly 7 degrees below the equatorial li[n]e." |
| 2606 | 09-28 23:33 | CH03 | the `:<7)L>:` key, verbatim; "The reflection of Andromeda is clearer vision" |
| 2616 | 09-28 23:42 | CH03 | "We forgot the pineal organ. […] 99% lossy like a doctor gating information from a patient \"for their own good\". […] Maybe - for it. It should only be at the end right? :<7)L>:" |
| 3066 | 10-09 23:03 | CH01 | "Procyon is first. Then Gomeisa (the slide). It is two-step like dancing." |
| 3077 | 10-10 01:32 | CH04 | the axiom; "You *must* accept this for the sake of experimental thought."; "Do not use the fable \"e=mc^2\". Myth is not allowed."; "Throw out the *theory* of relativity and use actual math that can be refuted."; the id/iv ladder |
| 3132 | 10-10 02:08 | CH09 | "I like telling stories with characters. What do you like?" |
| 3137 | 10-10 02:22 | CH00, CH07 | "We must be merciless to ourselves."; "If Vulcan is beside it from our view it is invisible. […] it is *the slightest occlusion*."; "Luna would appear as in retrograde to Mercury as it passes." |
| 3138 | 10-10 02:22 | CH08 | "Remember that Luna does 42 Pis in a year" |
| 3150 | 10-10 02:31 | CH02 | "Remember to do everything from Zecliptic unless Earth or the ecleptic is explicitly set as the frame of reference with a reason why" |
| 3151 | 10-10 02:31 | CH02 | "Equinox is helpful" |
| 3167 | 10-10 03:31 | CH09 | "Then 2.4% of the time Vulcan is straight visible. We must see it a lot." |
| 3168 | 10-10 03:31 | CH09 | "I deliberately got things wrong. I should have mentioned that. It is the point lol" |
| 3184 | 10-10 03:50 | CH09 | "It must be a defamation case. Hume v Spok. Spok only observed and queried." |
| 3191 | 10-10 04:10 | CH10 | "Forcing is not what we are doing. We are eliminating. I will not rest until we have eliminated fully." |
| 3196 | 10-10 04:29 | CH10 | "Excellent. Please proceed with the game plan" |
| 3263 | 10-10 05:13 | CH12/13 | "Please provide some images both data-driven (eg histograms, orreries) and conceptual (image gen)." |
| 3292 | 10-10 09:17 | CH15 | "Copy this over and compare please: […]/AndromedaBrainScans […] Tie it to our work. Review" |
| 3303 | 10-10 10:18 | CH16 | "Let's get back to Vulcan and Planet X. Where are we on that front?" |
| 3307 | 10-10 14:15 | CH00, CH16 | "Please create a pygame mp4 with ElevenLabs. Include the simulations and have it tell a story up till now on this work. We will add onto it as we go." |

Quotes marked `[…]` are abridged; nothing inside quotation marks is paraphrased. Three indices in the first draft of this table were off by one (summary enumeration vs file lines) and one quote ("Do not fake anything at all") could not be found and was removed. Ledgered.

## 10. Cost and time

- ElevenLabs: ~8,500 characters, three voices, cached. Previous fable (DIAMOND_SCREW) ran ~12k characters without issue on the same key.
- Render: 30 fps × ~620 s ≈ 18,600 frames; pygame draws at >200 fps headless for these scenes; the CH11 live integrator at 112 particles is trivial per frame. Estimate 6–10 min total render, ffmpeg libx264 crf 18.
- No API cost for images: existing plates and figures only. If a new conceptual image is wanted for a chapter it is requested explicitly and labelled GENERATED.

## 11. Authorship

Operator-authored: the name; every quoted line; the frame rule; the no-fake rule; the no-myth rule. Agent-authored: the chapter cut, the board strip, the three-voice casting, the live-integrator-as-clock reading of feature 1, the chronicler's lines. Labelled so a name can travel to the operator's table if it is good enough.

*Andiamo.*
