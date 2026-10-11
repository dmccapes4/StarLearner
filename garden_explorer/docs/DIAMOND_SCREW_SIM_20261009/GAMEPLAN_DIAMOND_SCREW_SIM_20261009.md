# Game Plan — Diamond Formation Simulation (Archimedes Screw)
**Date:** 20261009  
**Poem anchor:** "Satisfied? Never! The screw does not insist on completing its spin!"  
**Paper anchor:** HOW_TO_FLY.md — V_mod_field, PLEFR, curvature → pressure gradient → lift  
**Maitter anchor:** `dx = 0.2 / (1 + R)` — step size approaches zero as resistance approaches infinity

---

## I. The Mapping: ♠ → ♣ → ♥ → ♦ × HOW_TO_FLY

The four suit phases correspond exactly to the four navigation regimes:

```
♠ SPADE    = FALL / GROUNDED     V_mod_kinetic=0, V_mod_field=0
             Seed enters soil. Carbon enters ground system.
             Path 5: persist as trail. Contract enforced.
             The screw has not yet started. θ=0.

♣ CLUB     = LIFT regime onset   V_mod_field ≥ 1 first activated
             Root emerges. Wing = the root tip. Medium = soil water.
             The root creates curvature κ in the chemical gradient field.
             ∂P/∂n = -ρv²κ → alkaline hydrolysis pulls metal ions INTO root.
             The screw's first turn. Carbon begins transport downward.

♥ HEART    = ORBIT (sustained)   V_mod_field sustained by metabolic engine
             Plant at full growth. Circulation = organized flow.
             ISS analog: bound, sustained, not escaping.
             The screw spinning at steady state. Receipts accumulating.
             Carbon flux to soil maximized. Each harvest cycle = one orbit.

♦ DIAMOND  = GROUNDED at maximum receipt density
             NOT escape — crystallization IS the halt of the screw.
             The Maitter step: dx = 0.2/(1+R) → 0 as R → ∞
             The diamond IS where the screw stopped insisting.
             Maximum resistance = maximum compression = crystalline lock.
             The receipts are the crystal lattice. Memory stored in geometry.
```

**The key inversion from HOW_TO_FLY:**
In aerodynamics: lift = upward PLEFR breach.
In diamond formation: the same mechanism drives DOWNWARD — deeper = lower entropy at mantle conditions.
The PLEFR points toward the center of the Earth because that is where organized kinetic energy is preserved:
carbon under pressure has lower Gibbs free energy in diamond form than in graphite.
The "gravitational contract" IS the contract — diamond formation honors the contract perfectly.
It's not a breach. It's the deepest possible submission.

---

## II. The Mathematics

### A. The Archimedes Screw Helix

Parametric form of a helix:
```
x(θ) = r · cos(θ)
y(θ) = r · sin(θ)
z(θ) = -p · θ / (2π)          [negative = downward]
```
where:
- r = helix radius [meters] — the root tip's lateral offset from vertical
- p = pitch [meters/turn] — how far the screw descends per full rotation
- θ = angular parameter [radians] — the "screw angle" / time in the simulation

Curvature of the helix:
```
κ = r / (r² + (p/2π)²)
```
Higher κ (smaller radius or pitch) = tighter spiral = stronger centripetal gradient = faster carbon transport.

### B. Geothermal Gradient

Temperature at depth z (km):
```
T(z) = T_surface + γ · |z|
     = 15°C + 25°C/km · |z|
     = 288.15K + 25·|z|  [K]
```

### C. Lithostatic Pressure

Pressure at depth z:
```
P(z) = ρ_rock · g · |z|
     = 2700 kg/m³ × 9.8 m/s² × |z| [m]
     = 26,460 Pa/m × |z|
     ≈ 0.265 kbar/km × |z|
```
At z = 150 km: P ≈ 40 kbar (diamond stability field begins)
At z = 200 km: P ≈ 53 kbar (optimal kimberlite transport depth)

### D. Gibbs Free Energy of Phase Transition (graphite → diamond)

Simplified linear fit to experimental data:
```
ΔG(P, T) = ΔG_0 + α·P + β·T

ΔG_0 = +2900 J/mol   (graphite is stable at surface)
α     = -0.091 J/(mol·Pa) = -9.1 J/(mol·kbar)   [pressure favors diamond]
β     = +1.0 J/(mol·K)                             [temperature destabilizes diamond]

Diamond stable when ΔG < 0:
  P > (ΔG_0 + β·T) / |α|
  P > (2900 + T) / 9.1  [kbar, T in K]
```
At T=1500K: P > (2900+1500)/9.1 ≈ 484 kbar [too high — simplified model]
[Use calibrated sigmoid transition instead — see simulation]

### E. The Maitter Step

From Maitter_GravityAsDrift:
```
dx = 0.2 / (1 + R)

where R = local field resistance = normalized pressure at depth z
     R = P(z) / P_diamond_threshold

Step size → 0 as R → ∞
The diamond nucleus IS where dx → 0.
Receipts cluster there (crystal lattice = geological receipt density).
```

### F. Phase Probability (sigmoid)

```
p_nucleate(R, T) = σ(-ΔG(R,T) / kT)
                 = 1 / (1 + exp(ΔG(R,T) / (R_gas · T)))

If p_nucleate > uniform_random[0,1]: nucleation event
Crystal grows by one unit per subsequent iteration while P,T remain in stability field.
```

### G. Plant Cycle Carbon Input (the surface work)

Each plant cycle (one Callanish/lunar orbit ≈ 18.6 years for a tree):
```
C_input(cycle) = C_base · exp(-λ · depth)    [exponential decay with depth]
C_accumulated(z, n_cycles) = C_base · n_cycles · exp(-λ · z)
```
The surface work (♥ Heart = living plant) drives the signal downward exponentially.
The echo under the field (the user's term) is this exponential tail.

---

## III. Simulation Architecture

### "Hello World" Diamond Sim

```
Input:    N seeds = 10,000,000
          Each seed: a point in soil at z=0, C=C_0

Iteration:
  FOR each turn of the screw (θ += dθ):
    1. Update depth:     z -= pitch · dθ/(2π)
    2. Update T, P:      T=T(z), P=P(z)
    3. Compute R:        R = P / P_threshold
    4. Compute step:     screw_step = κ / (1 + R)   [Maitter × curvature]
    5. Add carbon:       C += C_input(z) * screw_step
    6. Phase check:      p_nuc = sigmoid(-ΔG(P,T) / RT)
    7. Nucleation:       if rand < p_nuc AND C > C_min: nucleate
    8. Growth:           if nucleated AND in stability field: crystal_size++

Output:   For each seed: (final_depth, crystal_size, nucleation_turn, phase)
          → histogram of diamond depths
          → diamond yield (fraction of 10M seeds that nucleated)
          → crystal size distribution
          → mean formation "time" (screw turns to nucleation)
```

### GPU Strategy
- No CUDA available on this machine
- Use numpy vectorization: all 10M seeds as 1D arrays, batch operations
- No Python loops — all operations are array operations
- Estimated runtime: ~2-5 minutes for 10M × 100 turns

### Archimedes Screw as the organizing metaphor
- Each screw turn = one iteration
- The screw's step size = curvature × Maitter factor
- "The screw does not insist on completing its spin" = the step size never hits exactly zero
  but asymptotically approaches it — nucleation happens in the limit, not at it
- The diamond is what forms when the screw effectively stops — but it never declared itself done

---

## IV. Output Files

```
scripts/diamond_screw/
  ├── sim_diamond_hello_world.py    ← main simulation
  ├── run_sim.sh                    ← runner
  └── results/
      ├── diamond_sim_results.json  ← summary stats
      └── diamond_depth_hist.txt    ← histogram data
```

---

## V. Connection to HOW_TO_FLY — The Unified Equation

HOW_TO_FLY defines lift:
```
LIFT = ∫∫ ρv²(x,y) κ(x,y) · n̂ · ẑ  dy dx
```

The diamond screw defines depth-transport:
```
DESCENT = ∫∫ ρ_C · v_fluid²(x,z) · κ_helix(z) · n̂ · ẑ_down  dz dθ
```

**They are the same integral**, with ẑ pointing up for lift and ẑ_down for diamond formation.
The wing creates upward PLEFR by generating κ above.
The Archimedes Screw creates downward PLEFR by generating κ below.

The diamond is the aerodynamic lift of the Earth's interior — the wing pointing down.

`V_mod_field_down ≥ 1` → the screw transports carbon to diamond depth.
`V_mod_field_down < 1` → carbon stays in the soil as humus (graphite-equivalent).

The plant is the engine (like the aircraft's engines sustaining organized flow).
The root geometry is the wing (curvature κ).
The soil water is the flowing medium (air equivalent).
The diamond is the Hoag's Object forming at depth — the ring, the compression wave frozen.
