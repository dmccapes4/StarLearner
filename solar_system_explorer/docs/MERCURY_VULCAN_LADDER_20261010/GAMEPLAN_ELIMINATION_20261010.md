# Mercury / Vulcan — Elimination Game Plan

**Filed:** 2026-10-10  
**Mode:** Eliminate, do not force. A hypothesis leaves the board only when a measurement removes it, or when it is confined to a region no existing instrument reaches — in which case the instrument that could reach it is named and dated.  
**Rules carried forward:** Zecliptic (solar-equator) frame unless Earth/ecliptic is set with a reason. Newtonian mechanics and measurement only. No relativity, no `E=mc²` as fable, no myth. Every claim carries its instrument and its refutation path.  
**Companion:** `REPORT_MERCURY_VULCAN_LADDER_20261010.md` (§1–18), `REFLECTION_ELIMINATION_META_20261010.md`.

---

## 0. What "fully eliminated" means

The board is closed when every row is in one of two states:

1. **Eliminated** — a named measurement contradicts it, with the number and the margin.
2. **Confined** — it survives only inside a region (mass, distance, time) that is stated exactly, with the instrument that can reach that region named and its date given.

A row may not be closed by argument, elegance, consensus, or by the author's or my preference. A row may not be closed by a theory the rules exclude. If the rules exclude the only thing that would close a row, the row stays open and says so.

---

## 1. The board as it stands

| # | Hypothesis | Status | Instrument that did it | Number / margin |
|---|---|---|---|---|
| 1 | Vulcan locked anti-Earth behind Mercury, any mass | **Eliminated** | Kinematics of the Earth→Mercury line (DE421, hourly) | Required tangential acceleration up to 1.9e-5 m/s² cannot be supplied by any central force; free-fall radius ≥ 2.75 × Hill at all times |
| 2 | V1 Charon-scaled companion (free orbit, a = 40,223 km) | **Eliminated** four ways | Spin period; ranging; telescopes; photometry | Mercury's 58.646 d spin ≠ 3.73 d; reflex 4,365 km vs ~10 m ranging; 38–100″ separation at V ≈ 1.5 visible since 1610; 0.25-mag mutual events vs 0.01–0.02 mag photometry |
| 3 | V2 spin-locked (a = 252,366 km) | **Eliminated** | Hill sphere; naked eye | a = 1.44 × Hill; 4–10′ separation |
| 4 | V3 Earth-synchronous (a = 854,287 km) | **Eliminated** | Hill sphere; naked eye | a = 4.87 × Hill; 14–35′ separation |
| 5 | V4 chain-interpolated (~10 km, a = 5,411 km) | **Eliminated as primordial** (new, this document) | Tidal decay | Phobos-mass body at 5,411 km spirals into Mercury in ~10 Myr (k₂ = 0.45 measured; Q 50–300); cannot be 4.5 Gyr old there |
| 6 | V4 class generally: a ~10 km free moon of Mercury | **Confined** | Tidal survival + Hill stability | Must lie in 13,000 km ≲ a ≲ 87,000 km (5.3–36 R_M), period 0.7–12.6 d, V ≈ 12 from Earth at 20–133″. Reaching it: MESSENGER archive (2011–15), BepiColombo (orbit insertion Nov 2026) |
| 7 | Config B silhouette (Vulcan in front of Mercury at lunar occultation) | **Dated, open** | Imaging at occultation | Next geocentric event 2028-02-23 00:05 UTC; tests only V1-class silhouettes (≥ 25 % disc area); says nothing about V4 (1.6e-5) |
| 8 | 43″/century from solar J₂ | **Eliminated** | Helioseismic J₂ vs Venus/Earth/Mars perihelia | Needs J₂ = 3.4e-4; measured 2.2e-7; the a^-3.5 scaling fails 3 of 5 bodies |
| 9 | 43″/century from an inner planet or ring | **Eliminated** | SOHO/LASCO 1996–, STEREO | Nothing > a few hundred km inside Mercury's orbit |
| 10 | 43″/century from any other Newtonian cause | **Open** — see §3 | — | Candidates remaining: Hall's exponent; zodiacal mass; planetary-mass error |
| 11 | id/iv ladder beats chance | **Not supported** | Permutation null (4,000 ladders) | 8.6 % holds vs 10.7 % random, p = 0.73 |
| 12 | Planet X as the ladder defines it (H2) | **Eliminated as a body; real as a deficit** | Belt mass from ephemerides | 0.032 M⊕ required at 2.79 AU; 0.0004 M⊕ present |
| 13 | Luna far-side camera reveals Vulcan | **Moot** | Parallax computation | Would show V3 always, V2 ~40–60 %, V1/V4 never; V2/V3 already eliminated by naked eye |

Rows 1–5, 8, 9, 12 are closed. Rows 6, 7, 10, 11 are the work.

---

## 2. Row 6 — the V4 annulus: how to close it

The one survivor is a small free moon. Earth cannot see it: Hubble and JWST cannot point within 50° / 85° of the Sun and Mercury never exceeds 28° elongation; LASCO and STEREO pixels are 1′. Only a spacecraft at Mercury can. Two have been or will be there.

### 2a. Confine it tighter (computation; can be done now)
- **Tidal floor as a function of size.** Decay time ∝ 1/m: a 10 km body needs a > 13,000 km to survive 4.5 Gyr; 1 km needs > 4,500 km; 100 m needs > 1,500 km. Produce the survival curve a_min(R, Q) for Q = 50–300. Output: `v4_annulus.png`.
- **Hill ceiling.** Integrate test particles (prograde and retrograde) in Mercury's Hill sphere with the Sun, Mercury's e = 0.2056, and Mercury's measured J₂, C₂₂, over 10⁵–10⁶ yr. Mercury's Hill radius swings 175,000–264,000 km each 88 days; the stable prograde zone is expected near 0.5 R_H(perihelion) ≈ 87,000 km, retrograde further out. Output: stability map, `v4_hill_stability.png`.
- **Radiation and Yarkovsky.** For R ≤ 1 km at 0.39 AU, compute the Yarkovsky semi-major-axis drift and radiation-pressure eccentricity forcing over 4.5 Gyr; this may raise the small-body floor. Output: table.
- **Result:** an annulus in (R, a) that is the complete surviving region. Everything outside it is eliminated by Newtonian mechanics alone.

### 2b. Search the annulus with what exists (literature pull; external)
- **MESSENGER (orbit 2011–2015).** Orbit radii 2,640–17,600 km in 2011 — the spacecraft repeatedly crossed the inner third of the annulus for a year, and sat inside it for four. Three independent handles:
  - *MDIS imaging:* obtain the published satellite-search paper and its limiting size; the report flags this as unverified. A 10 km body at 13,000 km is ~0.1° across from the spacecraft and brighter than any star in the frame; the question is coverage, not depth.
  - *Radio tracking:* a Phobos-mass body pulls the spacecraft at 5e-8 m/s² from 3,000 km and 5e-9 from 10,000 km; solar radiation pressure on MESSENGER's sunshade is ~1e-7 and is modelled to percent level. A periodic unmodelled acceleration at the moon's period (0.7–12.6 d) would be in the gravity-field residuals. Pull the residual spectra from the gravity solutions (HgM005 and later) and set an upper mass limit per orbital radius.
  - *Mariner 10 (1974):* its famous "moon of Mercury" was a UV detection later identified as the star 31 Crateris. A false alarm is a receipt for the search having been made; find the published limit (commonly quoted ≈ 5 km).
- **BepiColombo.** Orbit insertion November 2026; MPO periapsis ~480 km, apoapsis ~1,500 km; Mio to ~11,600 km. Mio's orbit reaches the annulus floor. MCAM / SIMBIO-SYS imaging and MORE radio science give the same two handles as MESSENGER with better tracking. **This is the dated instrument.** Write the observation request: a satellite survey of 13,000–90,000 km at V_sc-relative < 15, cadence every orbit for one Mercury year.

### 2c. Closure condition
Row 6 closes as **eliminated** if MESSENGER's imaging and tracking limits, combined, exclude every (R, a) inside the annulus; or as **confined-with-date** to the sub-region they do not reach, handed to BepiColombo. Either is a legitimate end state. Forcing it closed by taste is not.

---

## 3. Row 10 — the 43″: the last Newtonian candidates

The rule forbids the explanation that fits. Elimination does not forbid finishing the list. Three candidates remain; each has a measurement that can kill it.

| Candidate | Test | Expected outcome (to be computed, not asserted) |
|---|---|---|
| **Hall's hypothesis** (1894): gravity ∝ 1/r^(2+δ), δ = 1.6e-7, tuned to give Mercury 43″ | The same δ must act on the Moon. Compute the lunar perigee advance it predicts and compare with the lunar laser ranging value (known to ~1e-4″/yr). Brown (1903) found Hall's δ incompatible with the lunar motion; redo it with LLR numbers. | Eliminated if the lunar residual exceeds LLR error by > 10× |
| **Zodiacal / inner dust mass** | Mass inside Mercury's orbit needed for 43″ by a uniform ring: compute (order 1e-9 M☉?). Bound the actual mass from F-corona brightness and from the Venus–Mercury ranging ephemeris (INPOP/DE residuals). | Eliminated if required mass exceeds bound by > 100× |
| **Error in perturbing masses** (Venus, Earth, Jupiter) | Sensitivity ∂(perihelion rate)/∂M for each planet; compare with spacecraft-determined GM uncertainties (Venus to 1e-9 relative from Magellan/Venus Express). | Eliminated if the mass error needed exceeds uncertainty by > 1,000× |

After these three the Newtonian list is exhausted. The end state of row 10 under the rules is then one of:

- a surviving Newtonian cause (none is expected, but the computation decides); or
- the statement, entered as a receipt: *"No Newtonian cause of Mercury's 43″/century survives measurement. The residual stands as an unexplained measurement under the rules of this audit."*

That statement is the strongest thing the method can say without the excluded theory. It is also, read honestly, an arrow. The game plan records the arrow and does not follow it, because the rule is about method, not about protecting a conclusion from where the method points. (See the reflection.)

---

## 4. Row 11 — the ladder: out-of-sample or nothing

The ladder did not beat its own permutation null on this system. Pattern claims are eliminated or confirmed by systems they were not fitted on.

- **Pre-register** the metric set and the hold thresholds (< 0.30 dex hold, < 0.10 strong) before looking.
- **Apply unchanged** to: the Galilean system (as a mini-Sol), the Saturnian system, TRAPPIST-1 (seven planets, masses and radii measured), Kepler-90 (eight), HD 10180.
- **Permutation null for each.** If the user's ladder structure (geometric / mirror-equal / mirror-inverse) holds above null in systems it never saw, it is physics and row 11 reopens. If it holds in none, row 11 closes as eliminated with the numbers.
- The three strong holds found here (Sol:Jupiter:Venus radius; density mirrors; Earth:Luna ↔ Uranus:rings heliocentric a) are tested the same way; the last is a tautology and is retired regardless.

---

## 5. Dated receipts calendar (solar-equator frame unless noted)

| Date (UTC) | Event | What it can eliminate |
|---|---|---|
| 2026-10-20 04:09 | Mercury crosses Sol's equator (ascending) | Frame-anchoring epoch for any angle measurement |
| Nov 2026 | BepiColombo orbit insertion | Opens the V4 annulus to imaging and tracking |
| 2026-12-08 06:30 | Earth crosses Sol's equator (descending); B₀ = 0 | Solar-equinox epoch |
| 2027-01-08, 02-08, 08-01 | Near-miss lunar passages of Mercury | Rehearsal for 2028 imaging; Mercury disc timing |
| 2028-02-23 00:05 | Lunar occultation of Mercury (geocentric; topocentric circumstances per site) | V1-class Config B silhouette; Mercury's diameter from limb timing. (Earth frame, by reason: the Moon and the telescopes are here.) |
| 2028-09-22 | Earth equinox with Mercury at B = −0.08° (on Sol's equator) | Cleanest date for angle judgment in this frame: Earth at extreme B₀, Mercury in the plane |

---

## 6. Protocol for every further step

1. State the frame. Default Zecliptic (solar equator, i 7.25°, Ω 75.76°). Any Earth/ecliptic use carries its reason in the same sentence.
2. State the instrument and the number before the interpretation.
3. State the refutation path: what measurement would make this row wrong.
4. Ledger every deliberate error (the author's method) and every accidental one (mine) in the same table; both are receipts. This session's: 2.4 % misread (author, deliberate, caught); RA/Dec frame in first pass (mine, accidental, caught); Bloukrans 541 → 532 and 11 → ~10 km/day (mine, caught).
5. No row closes by preference. If it cannot be closed by measurement, it is confined and dated.
6. Stop when the board is closed under §0, or when every open row names an instrument that does not yet exist. Then rest.

---

## 7. Order of work

1. §2a — the annulus (computation; one script, two figures). Closes row 5 formally and bounds row 6.
2. §3 — the three Newtonian candidates for 43″ (computation; one script). Closes or empties row 10.
3. §2b — MESSENGER literature pull (satellite search limit; gravity residual spectra). Needs network; results are external receipts, flagged until read.
4. §4 — out-of-sample ladder (computation; reuse `ladder_analysis.py` on new entity tables).
5. §2b — BepiColombo observation request, written and dated.
6. Report addendum §19 and PDF rebuild; ledger updated.

Nothing here is forced. Each step either removes a row or shrinks the region a row may hide in, and says which.

---

## 8. Execution record (2026-10-10, same day, later)

All six steps of §7 run. Receipts in `REPORT_MERCURY_VULCAN_LADDER_20261010.md` §19 (PDF pp. 35–43) and the files named below.

| step | artefact | result |
|---|---|---|
| 1 §2a | `tools/vulcan/v4_annulus.py` → `data/v4_annulus.json`, `img/v4_01_tidal_floor.png`, `img/v4_02_hill_stability.png` | Tidal floor Q=100: 10 km → 13,254 km; 1 km → 4,580 km; 100 m → 1,582 km. Chain V4 lifetime 7–42 Myr. Hill edge (100 Mercury yr, Sun e=0.2056 + J₂): prograde 81,500 km (canonical 87,600), retrograde 120,000–136,000 km. Radiation a_rp/g < 1e-9. |
| 2 §3 | `tools/vulcan/perihelion_newtonian.py` → `data/perihelion_newtonian.json`, `img/perihelion_01_hall.png`, `img/perihelion_02_budget.png` | Hall: Moon perigee +1.38″/yr vs LLR 1e-4 (10⁴ σ); Venus/Earth/Mars ×2–4 wrong. Ring: 0.61 M⊕ at 1 AU needed, 4e7 × zodiacal. Masses: Venus +15 % / Jupiter +27 % needed vs 1e-9 / 1e-8. Budget reproduced 553″ vs 531 (first order). **No Newtonian cause survives.** |
| 3 §2b | this record; report §19.1 | Mariner 10 1974 = 31 Crateris (Stratford 1980). MESSENGER searched 2011 & 2013, none found (JHUAPL 2012-03-21, 2013-07-18). BepiColombo MOI 2026-11-21; separation 2026-12-09/10; MPO 480×1,500 km, Mio 590×11,640 km. **Unread, flagged:** MESSENGER campaign size limit; P&SS 55 (2007) 2037 ground search. |
| 4 §4 | `tools/vulcan/ladder_oos.py` → `data/ladder_oos.json`, `img/ladder_oos_01_recurrence.png`, `img/ladder_oos_02_null.png` | 5 systems × 2 pre-declared mappings: 1/10 beats random at p<0.05 (chance expectation 0.5). Sol holds recur 19/42 overall, 6/16 excluding density (density degenerate: 81 % of Saturn-moon pairs already within 0.30 dex). **Ladder does not transfer.** |
| 5 §2b | `BEPICOLOMBO_OBSERVATION_REQUEST_20261010.md` | Frame (solar equator), annulus, cadence (2 campaigns / Mercury year, 3-day sequences from Mio apoapsis), depth V ≥ 9 (20 m class), kinematic filter, MORE/ISA residual request, closure table. Fixed before result. |
| 6 | report §19, PDF 43 pp.; this section | — |

### Board after the pass

| row | before | after |
|---|---|---|
| 5 | eliminated as primordial (argued) | **eliminated as primordial** (computed; figure; lifetime 7–42 Myr) |
| 6 | confined 13,000–87,000 km | **confined 13,000–136,000 km (retrograde allowed); dated instrument named; two literature limits unread** |
| 7 | dated, open | dated, open (2028-02-23 00:05 UTC) |
| 10 | open | **emptied — no Newtonian cause survives; recorded as receipt and as an arrow not followed** |
| 11 | not supported in sample (p = 0.73) | **eliminated as a law out of sample; retained as mnemonic** |

### Errors of the chronicler, this pass

1. `v4_annulus.py` first run: sign of the indirect solar term. All 112 particles "escaped" in 463 d, including at 8,000 km — impossible, so caught. Fixed; assertion added.
2. `ladder_oos.py` first JSON: parenthesis nesting put three summary keys inside `recurrence_total`. Caught by the report builder's KeyError. Fixed.
3. Report §19.2 candidate table, first draft: solar-J₂ fit values typed from memory (1.1e-5; 7.4″/2.6″) instead of from `vulcan_derivation.json` (3.4e-4; 4.4″/1.4″). Caught by checking before build. Fixed.

Under §0: rows 1–5, 8, 9, 10, 11, 12 closed; row 6 confined with a dated instrument; row 7 dated. Not yet "fully eliminated" — row 6 waits on BepiColombo (first science ~March 2027) or on the two unread limits.
