# Scoresheet — what we know for sure: Sol vs Luna — started 2026-10-11

Rule of the sheet: every row is tagged with its **kind**. The user's rows stay in the user's
words. The agent's rows are the agent's and carry a source. A row can move kinds when someone
shows why. Nothing on this sheet is settled by being on it.

Kinds:

| tag | meaning |
|---|---|
| **D** | direct observation — a sense or an instrument registered it, no model between |
| **R** | instrument record — registered, but through a calibration or a chain (telescope, seismometer, spectrograph) |
| **I** | inference — derived from D/R through a model; the model is named |
| **E** | effect observed — we felt or saw a consequence and named a cause |
| **O** | open — claimed, no record found yet, or disputed in the literature |

Frame: Zecliptic where a frame matters. Lengths in R☉ or km. Papers: `HELIOSEISMOLOGY_PAPERS.md`.

---

## Sol

| # | row | kind | who | source / note |
|---|---|---|---|---|
| S1 | "When the Sun shines directly on my skin I experience a warmth on that locale. But wait. That is an effect observed rather than an actual observation." | **E** | user | — |
| S2 | "Half the time I see the Sun it is not remotely where it appears in the sky." | **E** → sized | user; agent sizing | Atmospheric refraction lifts the apparent Sun by 0.57° at the horizon (more than one solar diameter; at apparent sunset the geometric Sun is already below the horizon) and by ~0 overhead. Light-time 499 s and aberration 20.5″ add ~20″. So: one diameter near the horizon, nothing at noon. |
| S3 | The photosphere shows a line-of-sight velocity field oscillating with ~5-minute period, imaged across the disk, continuously since 1995 by two independent networks. | **R** | agent | Leighton 1962; GONG; SOHO/MDI; SDO/HMI |
| S4 | The oscillation power lies on discrete ridges in the k–ω plane; thousands of mode frequencies measured to 1 part in 10⁴–10⁵. | **R** | agent | Deubner 1975; Duvall 1982 |
| S5 | Those ridges are trapped acoustic (pressure) waves. | **I** (theory predicted before confirmation) | agent | Ulrich 1970; Leibacher & Stein 1971 |
| S6 | Sound speed as a function of depth, from the surface to ~0.05 R☉, to a few 0.1 %. | **I** (inversion against a reference model) | agent | Christensen-Dalsgaard 2002; Basu 2016 |
| S7 | Below the convection zone the models miss the inverted sound speed by up to ~1 %; convection-zone depth and surface helium also mismatch since the 2009 abundance revision. **Unresolved.** | **O** (a known crack) | agent | Basu & Antia 2008; Vinyoles 2017 |
| S8 | Near-surface frequencies miss the models by ~10 μHz and are corrected empirically. | **I**, fudge named | agent | Kjeldsen 2008 |
| S9 | Convection zone rotates differentially, radiative zone rigidly, shear layer at 0.7 R☉ (tachocline). Not predicted; found by two instruments independently. | **I** → corroborated | agent | Schou 1998; Thompson 2003 |
| S10 | The core rotates 3.8× faster than the envelope (g-mode claim). | **O** (disputed; not reproduced) | agent | Fossat 2017 vs Schunker 2018, Scherrer & Gough 2019 |
| S11 | Active regions on the far side can be predicted from near-side oscillations and are seen when they rotate into view / by STEREO. | **I** → out-of-sample test passed | agent | Lindsey & Braun 2000 |
| S12 | Neutrinos from pp, ⁷Be, ⁸B, pep and CNO reactions arrive from the core at the fluxes the models give; ⁸B ∝ T²⁵ pins core temperature to <1 %. Independent of acoustics. | **R** → **I** | agent | Borexino 2018, 2020; SNO 2002 |
| S13 | The visible layer (photosphere) is mostly neutral hydrogen, ionization fraction ~10⁻⁴; full ionization begins ~2,000 km down. | **I** (spectroscopy + Saha) | agent | standard; the "it is plasma" statement is true below the skin, not at it |
| S14 | Sound speed ≈ 7–8 km/s at the photosphere, ≈ 500 km/s in the core; centre-to-surface acoustic travel time ≈ 62 min (from Δν ≈ 135 μHz). | **I** | agent | derived from S6; c = √(γkT/μm_p) |
| S15 | Sol's spin axis points to RA 286.13°, Dec +63.87°; equator tilted 7.25° to the Zecliptic. | **R** | agent | Carrington; `tilt_curve.json` |
| S16 | Sol's position relative to the Sol–Jupiter barycentre: the barycentre is 1.07 R☉ from Sol's centre — outside the photosphere; for every other planet it is inside. | **I** (masses + distances) | agent | computed 2026-10-11 from `bodies_metrics.json` |

## Luna

| # | row | kind | who | source / note |
|---|---|---|---|---|
| L1 | "It rings like a bell." | **E** → sized | user | Apollo 12 LM ascent-stage impact, 20 Nov 1969 22:17 UTC: strong signal >30 min, signal to ~1 h. Apollo 13 S-IVB: >3 h. No record of a day. |
| L2 | "The craters flatten at the same depth." | **E** → sized | user | True: depth stops growing with diameter above the simple→complex transition (~15–20 km on Luna), large basins bottom out at a few km. The transition diameter scales as 1/g across Luna, Mercury, Mars, Earth (Pike 1974, 1980) — a gravity-collapse signature, the same on bodies with no shell in common. |
| L3 | "There were tremors on Earth… Thailand and/or Korea… announcement at a sporting event." | **O** | user | Searched 2026-10-11 (two queries, Apollo 12 + 20 Nov 1969 + Thailand/Korea/Bangkok/Seoul): no record found. Energy budget: LM 2,383 kg at ~1.7 km/s ≈ 3.4 GJ ≈ 1 t TNT (NASA's own figure), lunar magnitude ~2; no medium to Earth. Row stays open pending the source. |
| L4 | Four Apollo seismometers ran 1969–1977 and recorded ~12,000 events; deep moonquakes cluster at 700–1,200 km and recur monthly near perigee. | **R** | agent | Nakamura 1982 |
| L5 | Lunar signals are long, emergent, incoherent codas; "high Q and intense scattering, mutually exclusive on Earth". | **R** → **I** | agent | Latham 1970a,b. Scattering spreads the energy, low intrinsic loss keeps it — foam does not impede a lossless wave, it stirs it. |
| L6 | Moment of inertia I/MR² = 0.3931 ± 0.0002; mean density 3,344 kg/m³. Uniform sphere 0.400; thin hollow shell 0.667. | **R** → **I** | agent | Williams 2014 (GRAIL + LLR). Hollow is excluded by this number unless the word means something other than a cavity. |
| L7 | A small core, ~330 km, with a partially molten layer above it. | **I** (re-analysis of L4) | agent | Weber 2011 |
| L8 | Crust porosity ~12 % on average (the "sourdough"). | **I** (gravity inversion) | agent | Wieczorek 2013 |
| L9 | Luna is 42 Pis. | **R** → **I** | agent | `pis.json`; 41.999 |
| L10 | Earth–Luna barycentre is 4,671 km from Earth's centre, inside Earth (0.73 R⊕). | **I** | agent | computed 2026-10-11 |
| L11 | Laser pulses sent from Earth return from the Apollo 11, 14, 15 retroreflectors; round trip ~2.5 s. | **D/R** | agent | LLR, since 1969 — the only Earth–Luna "echo" on record |

---

## Open questions carried on the sheet

1. L3 — bring the source for the Thailand/Korea tremors; the row moves to **R** or closes.
2. S7 — the abundance problem is the live crack in the Sol column; watch opacities (Bailey et al.
   2015 iron opacity experiment) and the next abundance revision.
3. S10 — core rotation is unknown; any new g-mode claim must survive the Scherrer & Gough test
   (reproduce across GOLF, MDI, HMI, LOI, GONG, BiSON).
4. L1 — "like a bell implies inner matter": a bell rings because bronze has low intrinsic loss,
   not because it is hollow (a solid bar rings too — glockenspiel, tuning fork). The Moon's long
   coda is the dry-rock version of low loss. What *would* say hollow is L6, and L6 says no.
