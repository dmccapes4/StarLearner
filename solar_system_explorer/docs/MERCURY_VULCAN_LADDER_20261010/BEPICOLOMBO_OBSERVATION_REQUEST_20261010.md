# Observation request — a search for a free satellite of Mercury in the surviving annulus

**Dated:** 2026-10-10
**Instrument requested:** BepiColombo MPO (SIMBIO-SYS HRIC/STC) and Mio (MSASI/other wide-field sensors), post-separation science orbits (MPO 480 × 1,500 km polar, 2.3 h; Mio 590 × 11,640 km, 9.3 h). Mercury orbit insertion 2026-11-21; MPO/Mio separation 2026-12-09/10; science operations from ~March 2027 (ESA factsheet; CNES; EPSC2026-343).
**Author's status of the question:** the only unclosed branch (row 6, class V4) of the Mercury/Vulcan audit (`REPORT_MERCURY_VULCAN_LADDER.md`, `GAMEPLAN_ELIMINATION_20261010.md`). Every other class of the hypothesis is eliminated by measurements already on record. This request exists so that the last class is closed by a dated instrument and not by an argument.

---

## 1. What is being searched for

A body in bound orbit about Mercury, of any size from ~20 m to ~20 km, in the annulus where Newtonian tides and the Sun's tidal field together permit a 4.5 Gyr residence (`tools/vulcan/v4_annulus.py`, `data/v4_annulus.json`):

| boundary | value | source |
|---|---|---|
| inner edge (tidal floor), 10 km body, Q = 100, k₂ = 0.45 | 13,254 km | Goldreich–Soter decay integrated over 4.5 Gyr; k₂ from MESSENGER |
| inner edge, 1 km body | 4,580 km | same |
| inner edge, 100 m body | 1,582 km | same (below ~1 km the floor is near the surface; the inner constraint is then Mercury's own gravity-field residuals, not tides) |
| outer edge, prograde | 81,500 km (this integration, 100 Mercury years) / 87,600 km (0.5 R_Hill at perihelion, canonical) | leapfrog, Sun on e = 0.2056 orbit + J₂; 112 particles |
| outer edge, retrograde | 120,000–136,000 km | same |
| Hill radius at perihelion | 175,300 km | — |

Orbital periods across the annulus: 0.75 d (13,254 km) to 12.7 d (87,600 km) to 24.7 d (136,000 km).

Radiation pressure is irrelevant for R ≥ 100 m (a_rp/g < 1e-9 across the annulus; forced eccentricity < 1e-7).

## 2. Why the orbiters and not Earth

| from | 200 m body | 2 km body | 20 km body | remark |
|---|---|---|---|---|
| MPO/Mio, target at 13,000 km, full phase | V ≈ −0.8 | −5.8 | −10.8 | trivially bright |
| MPO/Mio, target at 87,000 km | +3.4 | −1.6 | −6.6 | |
| MPO/Mio, target at 136,000 km | +4.3 | −0.7 | −5.7 | |
| Earth, Δ = 0.9 AU, phase ~60° | 20.8 | 15.8 | 10.8 | 20–210″ from a V ≈ 0 planet, ≤ 28° from the Sun, in twilight |

(H = 5 log₁₀(1329/(D√p)), p = 0.10, r = 0.387 AU.) A 20 m body is V ≈ 4–9 from inside the annulus. Nothing on Earth can reach that; HST/JWST solar-avoidance (50°/85°) excludes Mercury entirely. The question is therefore operational, not photometric: can the orbiters spend any frames looking *away* from Mercury, across the annulus, with the Sun behind the spacecraft?

## 3. What is asked for

1. **Frame declaration.** Report any detection in the **solar-equatorial (Zecliptic) frame**: inclination i to Sol's equator (Mercury's orbit is at 3.38°; Mercury's spin axis is within 2′ of its orbit normal), node Ω measured from the ascending node of the solar equator on the ecliptic (Ω☉ = 75.76°). Earth-frame RA/Dec only as a secondary column with the reason stated. This is the frame in which the whole audit is written and the frame in which the moon's orbit (if any) is physically referenced to the Sun's spin and to Mercury's orbit at once.
2. **Cadence.** Two campaigns per Mercury year (88 d), each a 3-day sequence (≥ 4 periods of a 13,000 km orbit; a quarter period of an 87,000 km orbit) of wide-field frames spaced ≤ 2 h, pointed anti-sunward across the Hill sphere from the Mio apoapsis arc (11,640 km altitude; the arc gives the longest baseline and the smallest Mercury-limb stray light). MESSENGER's 2011 and 2013 MDIS WAC campaigns (H. Nair, JHUAPL release 2013-07-18) are the template.
3. **Depth.** Limiting V ≥ 9 per frame (20 m class at the retrograde edge; 200 m class anywhere in the annulus at the detection limit of even a navigation camera).
4. **Kinematic filter.** Candidate = source with Mercury-centric angular motion consistent with a bound Kepler orbit of a between 1,500 and 140,000 km (0.1–5°/h as seen from Mio apoapsis), not with a background star (parallax from spacecraft motion over the 9.3 h orbit ≫ 1′ for any bound object) and not with a heliocentric interloper (velocity relative to Mercury > escape at that radius).
5. **Gravity residuals (zero-cost).** Request that the MPO radio-science team (MORE) publish the post-fit Doppler residual spectrum at the orbital periods 0.75–25 d of a hypothetical companion; a 10 km body at 13,000 km pulls MPO at ≈ 4e-9 m/s² (MESSENGER SRP ≈ 1e-7; MORE's accelerometer ISA is specified to 1e-8 m/s² at these frequencies). The chain-interpolated V4 (9.8 km, 5,411 km) would have appeared in MESSENGER's HgM008 solution as an unmodelled periodic term at 0.2 d; it did not. State that explicitly as a published null.
6. **Dating.** Record the date of the first and last frame of each campaign. The audit treats a null here as a receipt only if dated.

## 4. What closes row 6

| outcome | consequence |
|---|---|
| Detection, bound orbit, any size | Row 6 **open → found**. V4 exists; measure a, e, i, mass (from MPO Doppler if ≥ km). The ladder's Mercury/Vulcan line is then tested on the *measured* mass ratio and separation, not on the chain interpolation (which is already dead by tides). |
| Null to V ≥ 9 over ≥ 2 campaigns across the full Hill sphere | Row 6 **closed**: no satellite ≥ 20 m anywhere a satellite could survive. The Mercury/Vulcan pair is eliminated in every class V1–V4. |
| Null to V ≥ 5 only (navigation-camera depth) | Row 6 **confined**: no satellite ≥ 200 m; 20–200 m bodies unexcluded. Record the confinement with its date. |

## 5. Prior art the request builds on (what was found, what was not)

- **Mariner 10, 1974-03-27.** UV excess "detached from Mercury", speed computed at 4 km/s "matching a moon" — identified as the background star 31 Crateris (HD 104337, spectroscopic binary P = 2.9 d; Stratford 1980, *Observatory* 100, 168). A false positive produced by exactly the kinematic ambiguity item 3.4 is designed to remove. Its by-product was the discovery that far-UV propagates through the ISM.
- **MESSENGER, 2011 and 2013.** Dedicated satellite-search campaigns with MDIS WAC; the 2013 campaign incidentally imaged Earth and Moon (2013-07-19/20). Result: no moon (JHUAPL releases 2012-03-21, 2013-07-18; NASA 2015). **Published size limit not located** by this audit — the campaign's limiting magnitude and search annulus are needed to state row 6 as confined-with-a-number rather than confined-by-press-release. Flagged.
- **Ground-based.** "A search for natural satellites of Mercury", *Planet. Space Sci.* 55 (2007) 2037–2041 (Bibcode 2007P&SS...55.2037W). **Abstract not retrievable through the tools available today (paywall/robot block).** Flagged; its limit presumably supersedes the Earth-based numbers in §2.
- **Gravity.** HgM008 (Genova et al. 2019, PGDA product 71) — degree-and-order 100 field with pole and libration estimates; no companion term reported. Not a published null for a companion; item 3.5 asks for one.

## 6. Protocol note

This request will not be modified after a result. A detection does not rescue the chain-interpolated V4 (dead by tides at 7–42 Myr), does not touch the ladder's null-test failure (`ladder_null.json`, p = 0.73; `ladder_oos.json`, 1 of 10 mapping tests at p < 0.05), and does not touch the 43″ (`perihelion_newtonian.json`: no Newtonian cause survives). A null does not touch them either. Row 6 is its own row.
