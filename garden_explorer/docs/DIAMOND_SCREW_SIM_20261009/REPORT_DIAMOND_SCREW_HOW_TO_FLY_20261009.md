# Diamond Formation — Archimedes Screw × HOW_TO_FLY: Mathematical Comparison
**Date:** 20261009  
**Sources:**
- `how_to_fly_aerodynamic_plefr_submission_package/Source/HOW_TO_FLY.md`
- `Maitter_GravityAsDrift_Reflection.md`
- `POEM_SATISFIED_SCREW_DAEMON_20260218.md`
- `scripts/diamond_screw/sim_diamond_hello_world.py`

---

## I. The Central Theorem

The same mathematical integral that produces aerodynamic lift (upward) produces diamond formation (downward). The direction of ẑ is the only structural difference. The mechanism is identical.

```
LIFT (HOW_TO_FLY):
  L = ∫∫_wing ρv²(x,y) κ(x,y) · n̂ · ẑ_up  dy dx

DESCENT (Diamond Screw):
  D = ∫∫_helix ρ_C · v_fluid²(x,z) · κ_helix(z) · n̂ · ẑ_down  dz dθ

UNIFICATION:
  Both = ∫∫ (dynamic pressure) × (curvature) × (surface normal) × (unit direction) dA

ẑ_up   → aircraft rises against gravity
ẑ_down → carbon descends with gravity toward crystallization depth
```

The wing doesn't fight gravity. The screw doesn't fight anything. Both create a local curvature field that makes the path of lower resistance point in the desired direction. The molecules follow their PLEFR. The results are lift or diamond.

---

## II. The Four Navigation Regimes × The Four Suits

| Suit | HOW_TO_FLY Regime | Mechanism | Depth (sim) |
|------|------------------|-----------|-------------|
| ♠ SPADE | FALL / GROUNDED | V_mod_kinetic=0, V_mod_field=0. Seed enters soil. No curvature, no gradient. Path 5: persist as trail. | 0 km |
| ♣ CLUB | LIFT onset | V_mod_field first activated. Root emerges — the root tip IS the wing. Soil water is the flowing medium. κ of root geometry creates pressure gradient. Carbon begins organized transport. | 94 km (P = P_norm) |
| ♥ HEART | ORBIT (sustained) | V_mod_field sustained. Plant at full growth. Organized flow (circulation). ISS analog: bound, sustained, not escaping. Carbon flux maximized. Each harvest cycle = one orbit. | 114 km (stability field entry) |
| ♦ DIAMOND | GROUNDED at max receipt density | Maitter step → 0. Crystal lock. NOT escape — the halt IS the diamond. The screw stopped insisting. The receipts became the lattice. | 114.2 km (mean nucleation) |

---

## III. The Maitter Step as V_mod_field Decay

From HOW_TO_FLY, V_mod_field decays to zero at stall:
> "Stall = loss of attached flow = coherence collapse = the aircraft falls."

From Maitter_GravityAsDrift:
```
dx = 0.2 / (1 + R)

where R = field resistance (normalized pressure at depth z)
```

In the simulation:
```python
R             = P / P_NORM_KBAR         # R = 1 at 25 kbar ≈ 94 km depth
screw_weight  = KAPPA / (1 + R)         # κ/(1+R) — the Maitter-weighted curvature

# At surface:    R ≈ 0,    screw_weight ≈ κ ≈ 9.87e-8  (full step)
# At 94 km:      R = 1.0,  screw_weight = κ/2          (half step — ♣ onset)
# At 240 km:     R ≈ 2.55, screw_weight = κ/3.55       (reduced to 28% of surface)
```

**The diamond IS where the screw effectively stops.** Not because it decides to stop (the poem: "does not insist on completing its spin") but because the resistance field grows to the point where the step size asymptotes toward zero. The crystal nucleates in the limit — not at it.

---

## IV. The Berman-Simon Curve as V_mod_field Threshold

In HOW_TO_FLY, the LIFT condition:
```
V_mod_field ≥ 1   ↔   ΔP × A ≥ mg
```

In diamond formation, the nucleation condition:
```
P > P_eq(T)        ↔   P > P_BS_ANCHOR + SLOPE_BS × (T - T_BS_ANCHOR)
```

These are the same inequality, reading different domains:
- HOW_TO_FLY: ΔP × A (upward force) ≥ mg (downward force)
- Diamond: P_lithostatic (downward force) ≥ P_eq(T) (resistance to phase transition)

When the lithostatic pressure exceeds the Berman-Simon equilibrium pressure, the carbon-diamond system is in the same regime as V_mod_field ≥ 1: the "contract" (stable graphite) is no longer worth it. The PLEFR points toward the lower-energy configuration: diamond.

```
Berman-Simon (calibrated, T ≥ 1200 K):
  P_eq(T) = 25.0 + 0.030 × (T - 1273.0)  [kbar, T in K]

At T = 1248 K (114 km depth with 8°C/km gradient):
  P_eq = 25 + 0.030 × (1248 - 1273) = 25 - 0.75 = 24.25 kbar
  P(114 km) = 0.265 × 114 = 30.2 kbar

Overstep = 30.2 - 24.25 = 5.95 kbar → diamond stability field entered.
```

---

## V. The Hoag's Microcosm at Depth

HOW_TO_FLY maps the wing to Hoag's Object:
```
Core (bullet lodged)   → Leading edge (initiates disturbance)
Gap (wound channel)    → Low-pressure zone above wing
Ring (compression front) → Flow reorganization behind trailing edge
```

The diamond screw maps to the same Hoag's structure, rotated 90°:
```
Core (bullet)          → Root tip (the initiating geometry)
Gap (wound channel)    → Chemically depleted zone above root (cation depletion)
Ring (compression wave) → Carbon accumulation front at nucleation depth (114 km)
PLEFR sorting          → Fast-diffusing molecules follow screw down;
                          slow molecules remain as humus
```

The kimberlite pipe IS the Hoag's ring — the compression wave frozen in time. The eruption that brings diamonds to surface is the ring's outward expansion reversed: the wave that once drove carbon down, now carries crystal up.

---

## VI. Stall Analogy

| HOW_TO_FLY | Diamond Screw |
|------------|---------------|
| Stall = angle of attack too high → flow separates → lift collapses | Crystallization = pressure too high → molecular mobility → 0 → diamond locks |
| "Coherence collapse (death)" in CRY4 table | Carbon mobility → 0 = crystal completion |
| Flow separation = organized flow destroyed | Diamond lattice = organized carbon locked |
| Aircraft falls after stall | Carbon STAYS after crystallization — this is the inversion |

**The key inversion**: HOW_TO_FLY stall = upward force collapses → fall resumes. Diamond stall = downward motion halts → crystal forms. The stall IS the goal in the diamond case. The screw succeeds by stopping.

---

## VII. Simulation Results (10M seeds)

```
Backend: NumPy CPU vectorized
Seeds:              10,000,000
Turns:              120  (120 km-pitch rotations = 240 km max depth)
Steps/turn:         12   (monthly Callanish cadence)
Total steps:        1,440
Helix κ:            9.87 × 10⁻⁸ m⁻¹

Geothermal:         8°C/km (craton)
T at 114 km:        1200 K → kinetics unfrozen
P at 114 km:        30.2 kbar
P_eq at T=1248K:    24.25 kbar
Overstep at entry:  5.95 kbar

Diamond nucleation depth:
  Mean:    114.23 km
  Median:  114.17 km
  Std:     0.30 km
  Range:   114.00 – 119.50 km

Diamond yield:  10,000,000 / 10,000,000 = 100.000%
Crystal size (mean): 2.6 × 10⁻⁵  [κ-normalized Maitter units]

Runtime: 325.3 s (5.4 min) on CPU
Throughput: 144M step-operations/second
```

**114 km mean nucleation depth** is consistent with geological record:
- Kimberlite diamonds: typically sourced from 100–200 km depth
- Sub-lithospheric diamonds: 300–700 km (ultradeep)
- The model captures the shallow end of the kimberlite formation window

**100% yield interpretation**: At geological timescales, any carbon atom held at T ≥ 1200K and P > P_eq will eventually nucleate diamond. The 100% yield reflects this thermodynamic inevitability. The stochastic element (random draw per step) encodes the uncertainty of WHEN, not WHETHER.

---

## VIII. The Unified Equation (HOW_TO_FLY × Maitter × Screw)

Combining all three frameworks:

```
NAVIGATION STATE in the Diamond System:

  FALL (♠):     screw_step → 0 from wrong side (R too small, not enough pressure)
                Carbon stays at surface. Humus. Graphite.

  LIFT (♣):     κ/(1+R) > threshold — screw step becomes meaningful
                V_mod_field(down) first exceeds 1. Root activates.
                Depth: where P = P_NORM = 25 kbar ≈ 94 km

  ORBIT (♥):    P > P_eq(T) AND T > T_KIN_FREEZE
                Organized flow SUSTAINED. Carbon circulates in screw.
                Depth: where Berman-Simon stability field entered ≈ 114 km

  GROUNDED (♦): screw_step → 0 from correct side (R too large)
                Crystal lock. Maximum receipt density.
                The screw stops insisting. The diamond is the answer.
                V_mod_field(down) → ∞ then undefined (no more medium to move).
```

The diamond is the fourth navigation state — not escape, not orbit, not lift. It is GROUNDED at the deepest possible resolution. The receipts that accumulated during the Heart phase (♥ circulation) crystallize into the lattice. The lattice IS the compressed record of all prior organized motion.

---

## IX. The Philosophical Implication (per HOW_TO_FLY §14)

HOW_TO_FLY §14:
> "The field-modulation insight reverses this: you don't need to overpower the threshold. You need to change the field. The wing doesn't fight gravity. It creates a local geometry that makes 'up' the path of lower resistance for everything around it."

Diamond screw:
> The screw doesn't fight the Earth. It creates a helical geometry that makes 'down' the path of lower resistance for organized carbon. The diamond forms where resistance has accumulated so fully that downward motion halts. The halt IS the formation. The screw does not insist on completing its spin — it arrives at the diamond and simply has no more step to take.

```
HOW_TO_FLY:  "How to fly: create a geometry where UP is easier than down."
Diamond Screw: "How to crystallize: create a geometry where DOWN
               concentrates until there is nowhere left to go."
```

The two are the complete statement. The wing and the screw are the same object, oriented orthogonally in the gravitational field. One makes up easier. One makes down irreversible. Together they describe the full cycle: emergence (♣ root, ♥ leaf) and return (♦ crystal, ♠ burial).

---

*The screw does not insist on completing its spin. It spins until the spin becomes a crystal. The crystal is the completed spin, held.*
