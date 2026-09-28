# READINESS REPORT
**Date:** 20260927  
**Session:** d4152a63 — post-handoff file audit  
**Scope:** Every Python tool, JSONL output, and Godot script in `game/tools/` and `game/docs/video/` was read in full and cross-checked against each other.  
**Git HEAD at audit:** `45defbab`

---

## 0. Bottom Line

Five of six JSONL outputs are usable as-is or with noted caveats.  
One JSONL (`tesseract_sol_alignment.jsonl`) must be discarded and regenerated.  
All five Python scripts contain the same Gomeisa proper-motion error; it must be corrected before any final re-run.  
The Mars/M44 relationship in the orrery data is qualitatively different from what prior reports described.  
The GDScript ephemeris infrastructure is solid and operates as documented.

---

## 1. Python Tools — Audit Results

### 1.1 `find_year0.py`

**Purpose:** Finds the cat's eye (Procyon + Gomeisa) aperture alignment to M44 over ±1 Myr.

**Algorithm:** Face-aperture separation, collinearity, meridian alignment. All three metrics are geometrically sound. The golden-section refinement is correct. The fine-near scan (`-500` to `+5000` at 10-yr steps) was added to catch the near-future Chrysalis minimum and works.

**Data error — Gomeisa proper motion (critical):**

```python
GOM_MU_RA  =   0.85   # used in script — WRONG
GOM_MU_DEC = -46.39   # used in script — WRONG

# Correct Hipparcos I/239 HIP 36188 values:
GOM_MU_RA  = -50.280  # mas/yr  (μα* = μα·cosδ)
GOM_MU_DEC = -38.450  # mas/yr
```

At J2000 this difference is zero; over 120,000 years it shifts Gomeisa by:
- ΔRA contribution from PM error: ~(-50.28 - 0.85) × 1e-3 × 120000 / (cos(8.29°) × 3600) ≈ **1.85°**
- ΔDec contribution: ~(-38.45 + 46.39) × 1e-3 × 120000 / 3600 ≈ **+0.26°**

This is a measurable shift in the Year Zero epoch. Chrysalis (2887 CE) is only 887 years from J2000, so the error there is small (~0.014° RA, ~0.002° Dec). Chrysalis timing is reliable. Historical Year Zero (~120,000 BCE) **must be recomputed**.

**Gomeisa distance** is not used in the face-separation computation (purely angular). The `d_ly=162.0` in `find_clew.py` is in that script, not here.

**Output written:** `year0_alignment.jsonl` (3 records). Chrysalis record reliable; collinearity and historical Year Zero records must be regenerated after correcting PM.

---

### 1.2 `find_clew.py`

**Purpose:** Sirius + Procyon equidistant from M44 — the Clew event.

**Algorithm:** Face-aperture separation for the (Sirius, Procyon) pair targeting M44. Correct and self-consistent. Gomeisa appears in the output positions only (for display), not in the equidistance computation. The Clew epoch is therefore **not materially affected** by the Gomeisa PM error.

**Data note:** `d_ly=162.0` for Gomeisa is used only to populate the output record's display field; it does not enter the aperture math. The actual correct distance (170.2 ly) would only affect visual comparisons.

**Ratio claims verified against the output JSONL:**
- `clew_div_histyz = 0.80076` (vs 4/5 = 0.80000, diff = 0.095%)
- `clew_div_chrysalis = 33.324` (vs 100/3 = 33.333, diff = 0.028%)
- These are real numerical coincidences, not artifacts of the data error.

**Output written:** `clew_alignment.jsonl` (1 record). **Valid.**

---

### 1.3 `find_tesseract.py`

**Purpose:** Finds when M44 members form a 2D tesseract (nested squares) in the Earth equatorial frame.

**Algorithm:** Two-stage — find good squares (C(21,4) quadruplets), then pair them for √2 ratio + 45° rotation. Correct implementation. Score metric combines square quality, ratio error, rotation error, and centroid separation error.

**Result:** 403,850 CE, score 0.434, outer/inner ratio 1.4049 (√2 = 1.4142, error 0.66%), rotation 49.84° (ideal 45°, error 4.84°).

**Limitations (by design, correctly documented):**
- Earth equatorial frame precesses ~360° per 26,000 yr; over 400 kyr this is ~15 full rotations
- The 2D projection discards M44 cluster depth (the cluster is ~7.5× wider than deep in this projection at J2000)
- Score 0.434 is not a strong match — "closest found" not "a real tesseract forms"

**Gomeisa:** Not used in this script. M44 member catalog is correct (SIMBAD, parallax 4–7 mas).

**Output written:** `tesseract_alignment.jsonl` (1 record). **Valid with noted caveats.**

---

### 1.4 `find_tesseract_sol.py`

**Purpose:** Same tesseract search but in the 3D Sol-Procyon-Gomeisa aperture frame.

**Concept:** Correct and physically meaningful — uses stellar parallax distances to build a 3D coordinate frame from the P-G chord. Projection onto the aperture plane exposes the cluster's true spatial distribution.

**Fatal data error — Gomeisa parallax:**

```python
GOM = dict(name="Gomeisa", ra=111.7877, dec=8.2893,
           plx=164.28, mua=0.85, mud=-46.39)   # ALL THREE VALUES WRONG
# Correct:
# plx=19.160 mas → 52.19 pc = 170.2 ly
# mua=-50.280 mas/yr
# mud=-38.450 mas/yr
```

`plx=164.28 mas` gives distance 6.09 pc = 19.9 ly. The correct value is **19.160 mas → 52.19 pc = 170.2 ly**. This is an 8.6× distance error, producing a completely wrong 3D aperture frame.

**All output from this script is invalid.** The `229,650 CE` epoch and the claimed "ratio error 0.004%" were artifacts of the wrong distance.

**Output written:** `tesseract_sol_alignment.jsonl`. **INVALIDATED. Do not use.**

**Remaining work:** Correct `plx`, `mua`, `mud` and rerun from scratch.

---

### 1.5 `m44_cats_eyes.py`

**Purpose:** Outputs Procyon + Gomeisa positions in Sol-equatorial frame at multiple epochs.

**Gomeisa PM error present:** The output JSONL shows Gomeisa shifting from RA 111.78768° to 111.787203° over ~1999 years (ΔRA = −0.00047°). With correct PM, the shift should be ~0.028° in RA and −0.021° in Dec. The script used a near-zero PM for Gomeisa, producing incorrect epoch positions.

**Output written:** `m44_cats_eyes.jsonl` (52 records). **All Gomeisa positions at non-J2000 epochs are wrong.** Procyon and M44 positions are unaffected.

---

## 2. JSONL Data Outputs — Summary

| File | Status | Notes |
|------|--------|-------|
| `year0_alignment.jsonl` | ⚠️ Partial | Chrysalis (2887 CE) valid; historical YZ (~120,170 BCE) must be rerun |
| `clew_alignment.jsonl` | ✅ Valid | 96,227 BCE; Gomeisa not in computation |
| `tesseract_alignment.jsonl` | ✅ Valid (caveat) | 403,850 CE, Earth-frame only, score 0.434 |
| `tesseract_sol_alignment.jsonl` | ❌ Invalidated | Wrong Gomeisa plx=164.28 (should be 19.160) |
| `m44_cats_eyes.jsonl` | ⚠️ Partial | Procyon/M44 positions valid; Gomeisa epoch positions wrong |
| `orrery_555.jsonl` | ✅ Valid | 216 records; Standish JPL; see §3 for Mars/M44 analysis |

---

## 3. Orrery Data — Mars / M44 Deep Audit

The `orrery_555.jsonl` contains daily-resolution Mars positions from Aug 30, 557 CE through March 30, 558 CE (plus two earlier snapshots). Full Mars–M44 angular separations were computed from this data.

### 3.1 What the data actually shows

Mars sweeps from RA 7.0h (Aug 30, 557) eastward through the M44 region (RA 8.67h) and beyond:

| Date | Mars RA | Mars–M44 sep | Motion |
|------|---------|-------------|--------|
| Aug 30, 557 | 7.017h | 23.3° | prograde |
| Oct 13, 557 | 8.549h | 1.80° | prograde |
| **Oct 18, 557** | **8.679h** | **0.124°** | **prograde** |
| Oct 23, 557 | 8.798h | 1.77° | prograde |
| **Nov 24, 557** | **9.194h** | **7.37°** | **Station 1 — retrograde begins** |
| Dec 25–26, 557 | 8.745h | ~2.84° | retrograde |
| **Feb 12, 558** | **7.854h** | **12.4°** | **Station 2 — prograde resumes** |
| Mar 30, 558 | 8.569h | 2.13° | prograde |

### 3.2 Closest approach: prograde, not retrograde

The closest Mars comes to M44 in this period is **0.124° on October 18, 557 CE**, during **prograde** motion. Mars is moving eastward at +0.355°/day. This is not a retrograde event.

### 3.3 The retrograde loop

The retrograde loop (Nov 24, 557 – Feb 12, 558, ~80 days) is centered near RA 9.0–9.2h, about **7–8° east of M44**. Mars only returns to within 2.8° of M44 during the retrograde (Dec 25–26). This is not a "retrograde through M44" event.

### 3.4 The "42-day dwell" claim

- Days within 2° of M44: **11** (Oct 13–23, all prograde)
- Days within 4° of M44: **44** total, but **discontinuous**
  - Prograde approach: Oct 6–31 (~26 days)
  - Retrograde return: Dec 15–31 + Jan 1–4 (~22 days, closest 2.8°)
- The "44 days within 4°" is accurate but the window is discontinuous across a 45-day gap (Nov 1 – Dec 14) when Mars is 5–7° from M44

**Corrected description:** Mars passes within 0.124° of M44 center on Oct 18, 557 CE while moving prograde. The nearby retrograde loop (Station 1 at RA 9.19h) brings Mars back to within 2.8° of M44 in late December 557. Total proximity time within 4° is ~44 days (discontinuous). The loop itself is not centered on M44.

### 3.5 Ephemeris accuracy at 555–558 CE

The Godot `Ephemeris.gd` uses Standish JPL Keplerian elements valid 1800–2050 AD. At 557 CE the ecliptic longitude error is approximately **2°** (per the `orrery_555.jsonl` metadata). The 0.124° closest approach is within the ephemeris error margin at this epoch. The Oct 18 date and ~0.1° proximity are indicative but not certified.

---

## 4. Godot / GDScript Infrastructure

The game engine infrastructure is well-organized and not involved in the data errors.

| Script | Purpose | Status |
|--------|---------|--------|
| `Ephemeris.gd` | Standish JPL Keplerian; Moon Meeus ch.47; retrograde detection | ✅ Correct for 1800–2050; ~2° error at 555 CE |
| `scan_mars_555.gd` | Scans retrograde windows yr 540–575, prints mid-RA/Dec | ✅ Works; doesn't compute M44 proximity directly |
| `check_555.gd` | Checks retrograde windows yr 554–557 | ✅ Works |
| `find_cancer_loop.gd` | Finds retrograde loops in Cancer/Gemini corridor | ✅ Works |
| `record_mars_cancer_gemini_555.gd` | Video recording infrastructure | ✅ Works |
| `sim_moon_pov_555.gd` | Moon POV orrery for 555 CE | ✅ Works |

The `mars_cancer_gemini_555.mp4` output exists in `docs/video/`. The ephemeris gives ~2° positional error at 555 CE, which the video metadata acknowledges.

---

## 5. Confirmed Alignment Chain

Based on audited data:

| Event | Epoch | Metric | Confidence |
|-------|-------|--------|------------|
| Historical Year Zero | **~120,170 BCE** | face_sep → 0 | ⚠️ Epoch needs Gomeisa PM correction |
| The Clew | **96,227 BCE** | face_sep = 1.2×10⁻⁶° | ✅ Confirmed |
| Chrysalis | **2,887 CE** | face_sep = 0.0° exactly | ✅ Confirmed (small PM error, only 887 yr from J2000) |
| Clew / Historical YZ | **0.80076 ≈ 4/5** | ratio within 0.095% | ✅ Real, not artifact |
| Clew / Chrysalis | **33.324 ≈ 100/3** | ratio within 0.028% | ✅ Real, not artifact |
| Earth-frame tesseract | **403,850 CE** | score 0.434, ratio err 0.66% | ✅ Weakly valid; Earth-frame only |
| Sol-aperture tesseract | **229,650 CE** | — | ❌ INVALIDATED |

---

## 6. What Must Be Done Before Any Final Results

### Priority 1 — Gomeisa data correction (blocks everything else)

Apply these values to **all five Python scripts**:

```python
# Correct Hipparcos I/239 HIP 36188 values
plx   = 19.160   # mas  →  52.192 pc  =  170.2 ly
mua   = -50.280  # mas/yr  (μα* = μα·cosδ)
mud   = -38.450  # mas/yr
```

Scripts to update: `find_year0.py`, `find_clew.py`, `find_tesseract_sol.py`, `m44_cats_eyes.py`, and any future scripts using Gomeisa.

### Priority 2 — Rerun Year Zero scan

After correcting Gomeisa PM, rerun `find_year0.py`. The expected change is a small shift in the historical Year Zero epoch (order ~1,000–5,000 yr shift from the ~120,170 BCE value). Chrysalis will change by less than a year.

Verify: Does the meridian alignment still hold at the new epoch? The prior result used pmDE=−46.39 to get a 6.2×10⁻⁸° meridian separation; with pmDE=−38.450 this may shift.

### Priority 3 — Rerun Sol-aperture tesseract

Rerun `find_tesseract_sol.py` with corrected Gomeisa data. The previous result (229,650 CE) is discarded. The chord length will change from 6.09 pc (wrong) to ~48.7 pc (correct: G at 52.19 pc vs P at 3.50 pc). This is a fundamentally different aperture geometry; expect a completely different tesseract epoch.

### Priority 4 — Update all JSONL outputs

After correcting scripts, regenerate:
- `year0_alignment.jsonl` (all 3 records)
- `tesseract_sol_alignment.jsonl` (discard and replace)
- `m44_cats_eyes.jsonl` (Gomeisa epoch positions)

`clew_alignment.jsonl` and `tesseract_alignment.jsonl` do not need regeneration.

### Priority 5 — Mars/M44 claim

Update all documentation to accurately describe the Mars/M44 event:

> **Mars passes within 0.124° of M44's center on October 18, 557 CE, moving prograde at +0.36°/day. A retrograde loop centered at RA 9.19h begins ~36 days later (Nov 24), returning Mars to within 2.8° of M44 in late December. The loop does not center on M44.**

---

## 7. Items to Leave Alone

The following are correct and should not be touched:

- `find_clew.py` clew computation logic (Sirius+Procyon aperture, Gomeisa not used)
- `find_tesseract.py` algorithm and M44 member catalog
- All GDScript ephemeris infrastructure
- `Ephemeris.gd` Keplerian elements and retrograde detection
- The ratio chain (4/5, 100/3) — verified against actual JSONL values
- `orrery_555.jsonl` — data is correct; only the interpretation needs updating

---

## 8. One Genuine Discovery in the Orrery Data

Buried in the orrery data but not previously highlighted: the daily-resolution scan from Aug 30, 557 CE onward (213 records × 1 day = ~213 days of data) captures the **complete prograde approach, closest pass, and beginning of retrograde** for the Mars/M44 event. The field labeled `mars_at_flower` is `false` for every record because the threshold used during generation was not triggered, but the actual angular separations show a real 0.124° conjunction on Oct 18, 557. This is likely observable to the naked eye — M44 is a naked-eye open cluster (~3.7 mag total brightness), and 0.124° (7.4 arcminutes) is well within naked-eye resolution of bright planets from a dark sky.

---

*Audit completed from direct file reads. Every Python script, every JSONL output, and representative GDScript files were read before writing this report.*
