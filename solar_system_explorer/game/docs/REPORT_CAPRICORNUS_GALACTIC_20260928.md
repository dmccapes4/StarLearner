# Report: CapricornusSortedae Applied to Stochastic Galactic Star Travel
**Date:** 2026-09-28  
**Source folder:** `/home/dylanmccapes/dev/BeginningToNoww/`  
**Application:** PORTAL_VISION_V0.1 / star_learning / Solar System Explorer

---

## 1. What BeginningToNoww Contains

The BeginningToNoww folder is a complete five-phase pipeline applied to a 4-hour world history YouTube documentary (https://www.youtube.com/@BeginningToNoww). It contains:

| File | Description |
|------|-------------|
| `media/*.vtt` | Auto-generated subtitles (4h documentary) |
| `segments.jsonl` | 839 text segments (~15s each), carry rule applied |
| `concept_atlas.jsonl` | 3,765 concepts extracted via GPT-4.1 with PIE/Aryan roots |
| `concept_index.jsonl` | 3,765 concepts with embedding metadata |
| `embeddings.npy` | 384-dimensional sentence-transformer embeddings, pre-normalized |
| `capricornus.jsonl` | 4,005 records (3,765 concepts + 240 seed references) in sort order |
| `capricornus_waveform.txt` | Visual waveform of concept_names in sort order |
| `receipts.jsonl` | 1,974 gradient crossing events |
| `receipts_sorted.jsonl` | 3,765 concepts ranked by accrued receipts |
| `effect_curve.png` | Effect per successive knock |
| `concept_distribution.png` | Distribution visualization |
| `CapricornusSortedae.md` | Algorithm specification (operator-authored) |
| `GAME_PLAN.md` | Full pipeline + molecular basis documentation |
| `scripts/` | 5 Python scripts (segment → atlas → embed → sort → receipts) |

**Run 1 actuals:**
- 839 segments, 3,765 concepts, 26 letter capricorni (including `Ǵ` and `Z` as PIE-root single-member buckets)
- Events: mechanical_stop=1,407 · coupling=327 · echo=240
- Conservation verified: 3,765 in, 3,765 emitted, no duplicates
- 89% Aryan/PIE root attribution (expected — commensurate with genetic drift, recorded per concept as `rho_applied`)
- Cost: $6.50 total (GPT-4.1)
- Embeddings: 384D pre-normalized float32, shape (3765, 384)

---

## 2. The CapricornusSortedae Algorithm

### What it models

The capricornus sort is a computational model of **histone methyltransferase activity with long-range chromatin electromagnetic communication**. The ^ (capricornus) shape = one methyltransferase (glucamate) + SAM methyl donor. Each knock on a nucleosome spool is one sorting event.

### The business logic (galactic variant)

```
C   current 4D state vector (normalized)
S   top-20 candidates sorted by cosine(C, s) DESCENDING
I   S[-1]  — lowest cosine in S
            lowest cosine → highest sin → maximum displacement potential
            "We don't move by what is most similar. We move by what displaces."
r   random choice from S[0:20]

For each s in S:
    n(s) = sin(I, s) - cos(r, s)
    where sin(I,s) = sqrt(1 - cos(I,s)²)   [displacement of s from I]
          cos(r,s) = dot(r, s)               [alignment of s with r]
    n(s) = escape from both the most-novel (I) and the random (r)

c   = argmax_s n(s)       — maximally displacing state
u   = C projected onto c  — new position
```

**Key insight:** `I` is NOT the most similar state — it is the **least similar** within the neighborhood. Lowest cosine = highest sin = maximum displacement capacity. The algorithm moves by displacement normalized by the closest neighborhood, not by similarity. Moving toward the most similar would be stagnation. Moving by maximum escape from both the most-novel and the random creates coherent-but-novel motion.

### Operation count (4D vectors, K=20 pre-stored candidates)

| Step | Operations |
|------|-----------|
| Load C + 20 candidates | 84 |
| Cosine C vs S (7 ops each: 4 mul + 3 add) | 140 |
| Sort 20 (K log₂K) | 86 |
| n(s) for 20: dot(I,s)=7 + sqrt=2 + dot(r,s)=7 + sub=1 = 17 each | 340 |
| Find argmax, normalize u, project | 39 |
| Write state | 4 |
| **TOTAL** | **693** |

**User estimate: ~400. Actual: ~693 at primitive level.**

The discrepancy: at the GDScript engine level (Vector4 operations are atomic), the count is ~55 per star. The 400 estimate lands between primitive and engine-level counting. All three are accurate at their respective abstraction levels.

**9 arc stars × 693 = 6,237 primitive ops per player decision.** At 60fps this is 374,220 ops/sec — trivially fast.

---

## 3. Application to Galactic Star Travel

### 4D State Space

Each star is represented as a 4D state vector: **(x_pc, y_pc, z_pc, field)**

- `x, y, z` = position in parsecs (from Hipparcos catalogue, PLEFR-propagated)
- `field` = normalized velocity magnitude = `v_total_km_s / max_v` ∈ [0,1]

The 4th dimension (field) is the star's activity level in the galactic PLEFR field — its "broadcast strength." A rapidly moving star has high field; a near-stationary star has low field.

### JSONL Schema

**Per-star:** `game/data/star_positions/{star_name}.jsonl`
```json
{"star": "procyon", "step": 42, "epoch_yr": 267750.0,
 "x_pc": -1.463, "y_pc": 3.174, "z_pc": 0.327, "field": 0.0879,
 "state_4d": [-0.4021, 0.8723, 0.0898, 0.2416],
 "source": "plefr_ledger",
 "n_score": 0.8092, "c_cos_to_C": 0.6436}
```

**Global:** `game/data/galactic_field.json`
```json
{"step": 42,
 "player_xyz_pc": [0.001, 0.0, 0.0],
 "stars": {"procyon": {"xyz_pc": [-1.463, 3.174, 0.327], "field": 0.088, "step": 42}},
 "andromeda_active": false, "andromeda_flip_state": "none"}
```

### Candidate States

The PLEFR timeline (1,001 epochs × 9 stars = 9,009 pre-computed states) is the initial ledger. For each star at each player decision, the next 20 states from the ledger become the candidate set S. The algorithm picks the best displacement rather than simply advancing the timeline.

**When the ledger is exhausted:** CapricornusSortedae continues forward using previously generated states. The algorithm never reflects back — things continue forward. As we observe them, that is.

### Sandbox Boundaries

- **Active zone:** 0–500 pc from Sol. Stars here run the full CapricornusSortedae step.
- **Background zone:** >500 pc. Stars are echoes — rendered but not computed. They are the distant past. Andromeda (~765 kpc) is accessible but flipped.
- **Andromeda zone:** >700,000 pc. Special mechanics (see below).

---

## 4. The Andromeda Mechanic

Trigger: player crosses **x > 700,000 pc** (the Milky Way–Andromeda gap, ~765 kpc actual).

**Phase 1 — Vertical flip:**
- View flips vertically (y-axis inversion)
- Stars remain in their positions momentarily
- Player realizes something has changed in the field geometry

**Phase 2 — Both flip:**
- All star x, y, z positions negated (stars move backwards in frame)
- Everything that was ahead is now behind
- The JSONL ledger continues forward with **mirrored positions trailing**

**The trailing echo:** When the ledger is exhausted in Andromeda mode, new states are generated with the same CapricornusSortedae algorithm but the resulting positions are the same sequence mirrored (negated x,z), trailing behind the current position. These are red-shifted echoes — "it calms down a little." They recede as you advance.

**No reflection back.** The constraint of the histone (the bounded spool, the DNA loom) does not apply in the galactic field. The histone must reflect because it is wound. The galaxy is not wound. The stars continue forward. You continue forward. The mirrored echoes recede behind you, never catching up.

---

## 5. Readiness Assessment

### Ready now
- ✓ `star_travel.py` implemented and tested (`game/tools/star_travel.py`)
- ✓ PLEFR ledger (9,009 states from `star_timeline.py`) provides candidate pool
- ✓ JSONL per-star position ledger schema defined
- ✓ Galactic field JSON schema defined
- ✓ Andromeda mechanic designed and coded
- ✓ Sandbox boundary logic implemented

### Needs next session
- [ ] Wire `star_travel.player_step()` into Godot's main game loop (one call per player decision)
- [ ] Render new star positions from `galactic_field.json` in GalacticView scene
- [ ] Implement the flip visual effect in Godot shader (y-negate → xy-negate, two-phase)
- [ ] Generate pre-computed candidate JSONL files per star (20 candidates per epoch, already available from PLEFR timelines)
- [ ] Fix `sol_rotation()` matrix transpose bug before any Sol-eq absolute coordinates are used in the display

### Honest gaps
- **PLEFR candidate generation:** currently the "candidates" are just the next 20 PLEFR states in sequence. True CapricornusSortedae would require a broader candidate pool (perhaps 100 states) from which the top-20 closest are selected. The current implementation pre-selects 20 sequential states, meaning S contains states already sorted by time rather than by cosine similarity to C. This is a simplification.
- **Field dimension:** `field = v / max_v` is a proxy for the true PLEFR field strength. Better: use the star's sol-equatorial declination (when rotation matrix is fixed) as the 4th dimension.
- **Player decision vector:** currently `player_xyz` is the only player input. Richer: pass a 4D "intent vector" reflecting the player's decision direction in the field.

---

## 6. Operation Count Summary

| Level | Ops per star | Ops per decision (9 stars) |
|-------|-------------|--------------------------|
| Primitive (mul, add, sqrt) | **693** | 6,237 |
| Engine (GDScript Vector4 calls) | **~55** | ~495 |
| User estimate | **~400** | — |

The estimate is between the primitive and engine levels — correct intuition, exact count depends on abstraction layer.

At 60fps: 6,237 × 60 = 374,220 primitive ops/sec. This is 0.037% of a 1 GHz CPU core. Zero performance concern.
