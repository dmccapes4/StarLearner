# Winter Circle → Gemini → Cancer → Leo — The Extension
*Dylan McCapes — October 9, 2026*
*Continues `WINTER_CIRCLE_PIPE_REPORT_20261009.md` and `dance_projection.py`*
*Epoch J2000.0 ICRS · Zecliptic obliquity ε = 23.4393° · planets via PyEphem (VSOP87, ±1′)*

Artefacts (same directory): `gemini_leo_extension.py` · `ext_view1_field.png` … `ext_view6_mars_2027_leo.png` · `gemini_leo_extension.pdf` (10 pp: cover, 6 views, 3 stats pages) · `gemini_leo_extension.json/.jsonl` · `ext_stats.txt`

---

## I. What was added

The prior work had 12 fixed stars (the Circle, the cat's eyes, Orion's belt) plus two Mars events, and five dance strategies that end at M44. This extension adds:

| Group | Added | Why |
|---|---|---|
| Gemini | 13 more stars (Alhena, Wasat, Mebsuta, Mekbuda, Propus, Tejat, Alzirr, κ, λ, θ, ι, υ, τ Gem) | Castor and Pollux were only the heads; the bodies stand on the Zecliptic |
| Cancer | Asellus Borealis/Australis, Al Tarf, Acubens, ι Cnc, M67 (+ M44 already) | The Dancer (kʞ) in full — the landing of the slide |
| Leo | 15 stars (Regulus, Denebola, Algieba, Zosma, Ras Elased, Adhafera, Rasalas, Chertan, η, Subra, ρ, ι, σ, Alterf, Al Minliar) | Where the dance goes next |
| Reference | Bellatrix; Alphard (Hydra, β = −22°) | Shoulder of Orion; the "below the floor" marker south of Leo |
| Planets | **Mars 2027 opposition** (computed), Jupiter Jan 2026 / today / Feb 2027 (computed) | The next intruder events |

Total: 49 fixed bodies, 3 Mars oppositions, 3 Jupiter marks. Sector span in Zecliptic longitude: **69.8° → 171.6° = 101.8°** (the Circle alone was 46.0°).

---

## II. The floor

The single strongest geometric fact in the extended set: **ten of the 49 bodies lie within 2.5° of the Zecliptic**, and four within half a degree.

| Body | β | λ | Constellation |
|---|---|---|---|
| Asellus Australis | +0.08° | 128.7° | Cnc |
| ρ Leo | +0.15° | 156.4° | Leo |
| Wasat | −0.18° | 108.5° | Gem |
| **Regulus** | **+0.46°** | 149.8° | Leo |
| Tejat | −0.82° | 95.3° | Gem |
| Propus | −0.89° | 93.4° | Gem |
| M44 | +1.29° | 127.3° | Cnc |
| σ Leo | +1.70° | 168.7° | Leo |
| Mekbuda | −2.04° | 105.0° | Gem |
| Mebsuta | +2.07° | 99.9° | Gem |

Regulus is the brightest star in the whole sky within half a degree of the Zecliptic. The Moon occults it; Venus, Mars and Jupiter pass within a degree of it regularly. In the cat/dancer/lion reading it is the one bright star that *stands on the floor* — the heart of the lion is on the plane of the planets.

The four floor-sitters with |β| ≤ 0.5° are spaced **20.2°, 21.1°, 6.6°** apart in λ (Wasat → Asellus Australis → Regulus → ρ Leo). The first two gaps are close to equal; that is a coincidence of real coordinates, reported as such.

In the prior report the Circle was read as a cat crouched *over* the Zecliptic — back arched above, face and paws below. Extending east, the picture changes character: **Gemini stands on the floor, Cancer sits on it, and Leo lies along it.** The Winter Circle is the one part of this sector that is mostly *off* the plane; everything east of Procyon is *on* it. (View 4 is this picture; the β histogram in its inset shows the pile-up at 0.)

---

## III. Gemini in full (View 2)

Castor (β = +10.1°) and Pollux (β = +6.7°) are the heads and, in the cat reading, the haunches. The bodies hang south from them:

- **Castor's side**: Castor → τ → Mebsuta (β +2.1°) → Tejat (β −0.8°) → Propus (β −0.9°). The feet stand on the floor **3.5° and 5.4° from the June-solstice point** (λ = 90°, RA 6h) and 9–11° from the galactic anticenter.
- **Pollux's side**: Pollux → υ → κ; Pollux → Wasat (β −0.2°, *on* the floor) → Mekbuda (β −2.0°, a Cepheid) → Alhena (β −6.7°). Wasat → λ Gem → Alzirr.

Six Gemini stars sit within ±5° of the Zecliptic: Wasat, Mebsuta, Mekbuda, Propus, Tejat, κ Gem.

**Jupiter at opposition, 10 Jan 2026** sat at λ = 109.8°, β = +0.26° — **1.3° from Wasat**, in the waist of Pollux's figure, on the floor. **Mars, 16 Jan 2025** sat 2.7° from κ Gem (the prior report's "3.7° from Pollux" is the same event measured to a different star; κ Gem was not in the earlier catalog).

Twin pairs — pairs 2.5°–5.5° apart, the "two" unit of the dance — are everywhere in Gemini: κ–υ 3.2°, Wasat–Mekbuda 4.0°, ι–τ 4.0°, Pollux–ι 4.3°, **Castor–Pollux 4.5°**, Castor–ι 4.5°, Castor–υ 5.0°. Across the whole set there are 28 such pairs; Castor–Pollux (4.51°) and Procyon–Gomeisa (4.30°) are within 0.2° of each other, which is why the eyes and the heads read as the same gesture.

---

## IV. The dance continued (View 3)

Prior result (dance_projection.py, Strategy 2): the Gomeisa → Procyon step (ΔRA = +0.2025 h, ΔDec = −3.064°), Dec-reflected at Procyon, reaches M44 at step 5 within 1°. The question was: what happens after the hive?

Three continuations were computed honestly.

**A. Keep stepping (steps 6–12).** Passes Asellus Borealis (3.0°) at step 6, then climbs through ι Cnc and Al Minliar into Lynx / Leo Minor. Step 12 is at Dec +42°, 16° from the nearest Leo star. **Misses Leo entirely.**

**B. Second slide at M44 (flip Dec back).** Step 1 is 1.9° from Asellus Australis; step 2 is 2.9° from Acubens; step 4 is 3.5° from Subra (Leo's front paw) — then it runs south under Regulus toward Hydra. Alphard is the nearest star from step 7 onward, 12°+ away. **Grazes Leo's paw, never enters the Sickle.**

**Why both miss.** The slide step is Dec-dominant (3° of Dec per 0.2 h of RA). Leo is reached by moving *along* the Zecliptic at β ≈ 0 — an RA-dominant, floor-hugging move. A step vector that was right for "two eyes → hive" is the wrong gesture for "hive → heart". The dance has to change phrase.

**C. Walk the floor.** From M44, step in Zecliptic longitude by the Gomeisa→Procyon Δλ (3.59°) with β pinned to 0. Then:

| Target | steps from M44 | β of target |
|---|---|---|
| Ras Elased (sickle tip) | 3.72 | +9.7° |
| Subra (paw) | 4.70 | −3.8° |
| Adhafera | 5.63 | +11.9° |
| η Leo | 5.72 | +4.9° |
| Algieba | 6.20 | +8.8° |
| **Regulus** | **6.26** | **+0.5°** |
| Zosma | 9.45 | +14.3° |
| **Denebola** | **12.32** | +12.3° |

**M44 → Regulus is 6¼ steps; Regulus → Denebola is 6 more** (12.32 − 6.26 = 6.06). In degrees: Regulus sits 22.5° past M44 and 21.8° before Denebola in λ — **the heart is the λ-midpoint of hive and tail to within 1°.** That is a fact about the real sky, not about the step size; the step size only makes it countable.

**D. The phrase, 2-1-2-1-2-1.**

| | from → to | arc |
|---|---|---|
| 2 (eyes) | Gomeisa → Procyon | 4.3° |
| →1 | Procyon → Pollux | **22.8°** |
| →2 (donkeys) | Pollux → M44 | 15.1° |
| →1 (heart) | M44 → Regulus | **22.5°** |
| →2 (mane) | Regulus → Algieba | 8.4° |
| →1 (tail) | Algieba → Denebola | **21.9°** |

The three long "1" legs are 22.8°, 22.5°, 21.9° — a spread of 0.9°. The targets were chosen by name (the obvious bright anchor at each stage), not searched for, so this is a curiosity and not a test; but it is the same ~22° three times, and that is what makes the phrase feel like one phrase rather than three.

---

## V. Mars 2027 — the Leo landing (View 6)

Computed with PyEphem; cross-check the date against any almanac.

| | Mars 2008 | Mars 2025 | **Mars 2027** |
|---|---|---|---|
| Opposition / peak | 2 Jan 2008 | 16 Jan 2025 | **19–20 Feb 2027** |
| Mag | −1.38 | −1.25 | −1.12 |
| Distance | 0.610 AU | 0.643 AU | 0.678 AU |
| λ | 89.4° | 116.1° | **150.2°** |
| β | +3.51° | +4.29° | **+4.46°** |
| Where | Gemini — chest/belt (F=14) | Gemini — haunch (F=16) | **Leo — inside the Sickle** |
| Nearest star | Propus 6.0° | κ Gem 2.7° | **η Leo 2.4°** (Regulus 4.0°, Algieba 4.4°) |
| star_pipe F | 14 | 16 | **12 — same F as Regulus** |

The retrograde loop (stationary 10 Jan 2027 → 5 Apr 2027) is drawn entirely inside the Sickle, between Regulus and Algieba. Mars crosses Regulus's RA **three times**: 26 Nov 2026 (1.7° from Regulus), 1 Mar 2027 (4.9°, during retrograde), 15 May 2027 (1.2°). The triple pass of the heart.

**β at opposition climbs 3.51 → 4.29 → 4.46.** The prior report noticed the first two and called the Zecliptic "the floor Mars barely peaks above." The third confirms the pattern — and the explanation is plain geometry: Mars's orbit is inclined 1.85° to the ecliptic, and apparent β is magnified at opposition because Earth is closest. Mars is near its ascending-node side of the orbit for these winter/spring oppositions, so β is positive and a few degrees. Not an omen; a known trigonometric effect. The pattern is real and the cause is ordinary.

**Jupiter** will be at RA 9.56 h, Dec +15.6° on the day of Mars's opposition — λ = 140.6°, β = +1.1°, between Cancer and Leo, 6° from Subra. Two bright planets on the floor within 10° of λ, one in the paw and one in the heart.

---

## VI. The star pipe over 52 bodies (View 5)

Same definition as the prior report §II: L = digit-sum(round λ) mod 10, B = digit-sum(round |β|) mod 10, E = |L−B|, F = L+E+B, G = leading digit of round λ, self-pipe ⟺ L = B.

**F distribution** (52 bodies): F=12 ×12 (dominant), F=4 ×7, F=14 ×7, F=16 ×7, F=18 ×5, F=8 ×4, F=10 ×4, F=6 ×3, F=2 ×2, F=0 ×1.

**Self-pipes**: 7 of 52 — Rigel, Gomeisa, Betelgeuse (the prior three), plus **Wasat** (L=B=0, F=0 — the only F=0 in the set, and it is the Gemini star that sits exactly on the floor), θ Gem, M67, Adhafera. Expected rate under independence ≈ 1/10; observed 7/52 ≈ 0.13.

**Mars 2027 bonds with Regulus** (F=12), along with Ras Elased, Rasalas, ι Leo, σ Leo, M67, Mintaka, and four Gemini stars (Mekbuda, κ, λ, ι Gem). The narrative sequence is now: Mars 2008 → chest (F=14), Mars 2025 → eye (F=16), Mars 2027 → heart (F=12).

### Structural facts about the instrument (hold for every input)

These are stated the way T1–T5 were stated in the phone-pipe work: facts about the lens, separated from facts about the sky.

- **T1. F = 2·max(L, B). Always even.** An F-group is "same max digit-sum." F=14 means max(L,B)=7; F=12 means max(L,B)=6. The prior report's "self-pipe stars have even F" is true but weaker than the truth: *every* F is even.
- **T2. G is degenerate above λ = 100°.** Every body with λ in 100–199 has G=1. That is all of Gemini, Cancer, and Leo, and Sirius, and Procyon. "G_diff = 0" between any two of them carries no information. G only discriminates west of Betelgeuse.
- **T3. L and B are digit sums of *rounded* degrees.** A body 0.5° away can change L by up to 9. The pipe is a coarse hash of position, not a geometric property; bonds and self-pipes are coincidences on the rounding, and should be read with that in mind.
- **T4. Self-pipe rate.** Expected ≈ 1/10 under independence of the two digit sums. Observed 7/52. Consistent with chance.

None of this says the pipe is useless. It says what the pipe is: a way of grouping bodies by a two-digit hash of their Zecliptic position. Used that way — as a labelling, not a mechanism — the F=12 bond of Mars 2027 with Regulus is a fine mnemonic for "Mars lands on the heart." It is not evidence of anything beyond the coordinates.

---

## VII. What is real geometry, independent of any pipe

All computed; nothing eyeballed.

- Propus is 3.5° and Tejat 5.4° from the June-solstice point (λ = 90°); 9.2° and 10.6° from the galactic anticenter. **The twins' feet stand where the Sun turns.**
- Regulus β = +0.46°. Brightest floor-sitter in the sky.
- Aldebaran (λ 69.8°) and Regulus (λ 149.8°) — two of the four "royal stars" of the Persian tradition — bracket this sector **exactly 80.0° apart**.
- In λ, Regulus is 22.5° past M44 and 21.8° before Denebola: the heart is the midpoint of hive and tail.
- The three long legs of the dance phrase are 22.8°, 22.5°, 21.9°.
- Castor–Pollux 4.51°, Procyon–Gomeisa 4.30°: the two "pairs" of the cat reading are the same size to 0.2°.
- Mars oppositions recur in this sector every 15–17 years: 2008 Gem → 2025 Gem → 2027 Leo → ~2042 Gem/Cnc (estimated). The 2027 event is the one still ahead.

---

## VIII. Next events worth watching

| When | What | Where |
|---|---|---|
| 26 Nov 2026 | Mars passes Regulus (1.7°), direct motion | Leo — heart |
| 10 Jan 2027 | Mars stationary, retrograde begins | Leo — under Zosma/Chertan |
| **19–20 Feb 2027** | **Mars opposition, mag −1.1** | **Leo — inside the Sickle, 2.4° from η Leo** |
| 1 Mar 2027 | Mars passes Regulus (4.9°), retrograde | Leo |
| 5 Apr 2027 | Mars stationary, direct resumes | Leo/Cancer border near ε Leo |
| 15 May 2027 | Mars passes Regulus (1.2°), direct | Leo — heart, closest pass |
| through 2027 | Jupiter in Cancer → Leo, on the floor | β ≈ +1° |

---

## IX. Ledger

- Fixed-star coordinates: J2000 catalogue values (Hipparcos/SIMBAD level, ±0.01°), entered by hand into `CAT` in the script; verify any single value against SIMBAD before citing it externally.
- Planet positions: PyEphem (VSOP87), astrometric J2000; good to about an arcminute. Opposition date from minimum Earth distance at 1-day cadence; stationary points from 5-day cadence (±3 days).
- Ecliptic transform: exact rotation, ε = 23.4393°, no precession or nutation applied (J2000 throughout).
- Dance A/B: linear RA/Dec stepping, as in `dance_projection.py`, for continuity with the prior figures. Dance C: exact ecliptic stepping.
- Pipe: digit arithmetic, deterministic, re-runnable. Structural limits stated in §VI.
- No value in this document was adjusted to fit a story. Where the sky happened to be tidy (the 22° legs, the 20° floor gaps, the 80° royal bracket), it is reported with the caveat that the targets were chosen by name.

*Connected: `WINTER_CIRCLE_CATS_EYES_COORDS_20261009.md`, `WINTER_CIRCLE_PIPE_REPORT_20261009.md`, `dance_projection.py`, `../NOTE_ZODIAC_RETROGRADE.md` (the Mars retrograde loop in View 6 is exactly the "weird sky trick" that note wants to teach).*
