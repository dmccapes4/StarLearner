#!/usr/bin/env python3
"""
sim_diamond_hello_world.py
──────────────────────────────────────────────────────────────────────────────
DIAMOND FORMATION — ARCHIMEDES SCREW MODEL
"The screw does not insist on completing its spin."
    — POEM_SATISFIED_SCREW_DAEMON_20260218.md

Theoretical basis:
  HOW_TO_FLY.md  →  V_mod_field = ∫∫ ρv²κ dA  (lift by curvature)
                     The diamond is the aerodynamic lift of Earth's interior.
                     Same integral, ẑ pointing DOWN.
  Maitter        →  screw_step = κ/(1+R)  (step size → 0 as R → ∞)
                     Diamond = where the screw stopped insisting.
  Suits chain    →  ♠ FALL → ♣ LIFT → ♥ ORBIT → ♦ GROUNDED at max receipt density

Physics:
  Geothermal     →  T(z) = 288 + 8·z_km  [K]       (craton gradient ≈8°C/km)
  Lithostatic    →  P(z) = 0.265·z_km    [kbar]
  Stability      →  Berman-Simon curve for T > 1200K:
                       P_eq(T) = 25 + 0.030·(T-1273)  [kbar]
                    Kinetically frozen for T < 1200K:
                       P_eq = 70 kbar (HPHT or catalyst required)
  Nucleation     →  sigmoid(overstep / k_trans) when in stability field
  Crystal growth →  seed grows each step that P > P_eq AND T in [900K, 3000K]
  Carbon input   →  exponential decay with depth (surface plant drives signal)
  Maitter step   →  weight = κ / (1 + R)  where R = P / P_threshold

N = 10,000,000 seeds, fully vectorized (no Python for-loops over seeds).
GPU: cupy if available, else numpy (CPU vectorized).

Output: scripts/diamond_screw/results/
──────────────────────────────────────────────────────────────────────────────
"""

import numpy as np
import json, os, time

# ── Try GPU backend ─────────────────────────────────────────────────────────
try:
    import cupy as xp
    GPU = True
    print("Backend: CuPy (GPU)")
except ImportError:
    xp = np
    GPU = False
    print("Backend: NumPy (CPU vectorized — no GPU found)")

# ── Simulation parameters ───────────────────────────────────────────────────
N_SEEDS         = 10_000_000       # parallel seeds
N_TURNS         = 120              # screw turns (one turn = one plant-cycle season)
STEPS_PER_TURN  = 12               # 12 months/year, 12 signs, 12 steps/turn
D_THETA         = 2 * np.pi / STEPS_PER_TURN

# Helix geometry (Archimedes Screw)
HELIX_RADIUS    = 0.01             # meters (root-tip lateral offset)
HELIX_PITCH     = 2_000.0          # meters/turn (2 km per full rotation)
_p2pi           = HELIX_PITCH / (2 * np.pi)
KAPPA           = HELIX_RADIUS / (HELIX_RADIUS**2 + _p2pi**2)  # helix curvature [1/m]

# Geothermal gradient — craton, 8°C/km average (realistic for diamond country)
GAMMA_K_PER_M   = 0.008            # K/m  (8°C/km)
T_SURFACE       = 288.15           # K (15°C surface)

# Lithostatic pressure
RHO_ROCK        = 2700.0           # kg/m³
G_ACC           = 9.8              # m/s²
KBAR_PER_M      = RHO_ROCK * G_ACC * 1e-8   # kbar/m = 2.646e-4 kbar/m

# Diamond stability (Berman-Simon equilibrium curve — calibrated)
# Applies for T > T_KIN_FREEZE (kinetics enable nucleation)
T_KIN_FREEZE    = 1200.0           # K — below this, P_eq = P_KINETIC_LOCK
P_KINETIC_LOCK  = 70.0             # kbar — frozen without catalyst at low T
P_BS_ANCHOR     = 25.0             # kbar — Berman-Simon anchor pressure
T_BS_ANCHOR     = 1273.0           # K   — Berman-Simon anchor temperature
SLOPE_BS        = 0.030            # kbar/K — dP_eq/dT (Berman-Simon slope)
# P_eq(T) = P_BS_ANCHOR + SLOPE_BS*(T - T_BS_ANCHOR) for T >= T_KIN_FREEZE

# Nucleation sigmoid: prob = sigmoid((overstep - k_shift) / k_trans)
# k_shift: overstep needed for 50% probability per step [kbar]
# k_trans: transition width [kbar]
K_TRANS         = 2.0              # kbar — width of nucleation sigmoid
K_SHIFT         = 8.0              # kbar — need 8 kbar overstep for 50% nucleation
T_MAX_STABLE    = 3000.0           # K — above this, melt → no diamond

# Carbon model (♥ Heart = living plant drives surface signal downward)
C_BASE          = 1.0              # normalized carbon input per step at surface
LAMBDA_M        = 1.0 / 100_000.0  # 1/m — exponential decay length (100 km scale depth)
C_MIN_NUCLEATE  = 0.10             # minimum carbon concentration for nucleation

# Maitter resistance normalizer — R = 1 at diamond threshold depth
P_NORM_KBAR     = P_BS_ANCHOR      # 25 kbar as the normalization reference


def run_simulation(n_seeds=N_SEEDS, n_turns=N_TURNS, seed=42):
    rng = xp.random.default_rng(seed)
    t0  = time.time()

    max_depth_km = n_turns * HELIX_PITCH / 1000.0
    dz_step      = HELIX_PITCH / STEPS_PER_TURN   # meters per step

    # Temperature at which we first enter diamond stability (P(z) = P_eq(T(z)))
    # P(z)  = KBAR_PER_M * z
    # P_eq  = P_BS_ANCHOR + SLOPE_BS*(T_SURFACE + GAMMA_K_PER_M*z - T_BS_ANCHOR)
    # Solve: KBAR_PER_M * z = P_BS_ANCHOR + SLOPE_BS*(T_SURFACE + GAMMA_K_PER_M*z - T_BS_ANCHOR)
    # z*(KBAR_PER_M - SLOPE_BS*GAMMA_K_PER_M) = P_BS_ANCHOR + SLOPE_BS*(T_SURFACE - T_BS_ANCHOR)
    rhs = P_BS_ANCHOR + SLOPE_BS * (T_SURFACE - T_BS_ANCHOR)
    lhs_coeff = KBAR_PER_M - SLOPE_BS * GAMMA_K_PER_M
    z_stability_km = (rhs / lhs_coeff) / 1000.0  # km
    # Also kinetics require T >= T_KIN_FREEZE
    z_kinetics_km  = (T_KIN_FREEZE - T_SURFACE) / (GAMMA_K_PER_M * 1000.0)  # km
    z_nucleate_km  = max(z_stability_km, z_kinetics_km)

    print(f"\n{'─'*64}")
    print(f"DIAMOND SCREW SIMULATION — Hello World")
    print(f"{'─'*64}")
    print(f"Seeds:              {n_seeds:>12,}")
    print(f"Turns:              {n_turns:>12}")
    print(f"Steps/turn:         {STEPS_PER_TURN:>12}")
    print(f"Total steps:        {n_turns*STEPS_PER_TURN:>12,}")
    print(f"Helix κ:            {KAPPA:>12.4e} m⁻¹")
    print(f"Pitch:              {HELIX_PITCH/1000:>12.1f} km/turn")
    print(f"Max depth:          {max_depth_km:>12.1f} km")
    print(f"dz/step:            {dz_step:>12.1f} m")
    print(f"")
    print(f"── Geothermal / Stability Crossover ──")
    print(f"  T at {z_kinetics_km:.0f} km = {T_SURFACE + GAMMA_K_PER_M*z_kinetics_km*1000:.0f} K (kinetics unfrozen)")
    print(f"  P eq at T_freeze  = {P_BS_ANCHOR + SLOPE_BS*(T_KIN_FREEZE - T_BS_ANCHOR):.1f} kbar")
    print(f"  P at {z_kinetics_km:.0f} km     = {KBAR_PER_M * z_kinetics_km * 1000:.1f} kbar")
    print(f"  Nucleation active at z ≥ {z_nucleate_km:.1f} km")
    print(f"  (turn ≥ {z_nucleate_km/HELIX_PITCH*1000:.1f})")
    print(f"{'─'*64}")

    # ── State arrays ─────────────────────────────────────────────────────
    z        = xp.zeros(n_seeds, dtype=xp.float32)   # depth [m]
    carbon   = xp.full(n_seeds, C_BASE, dtype=xp.float32)
    crystal  = xp.zeros(n_seeds, dtype=xp.float32)   # crystal size [a.u.]
    nucleated = xp.zeros(n_seeds, dtype=xp.bool_)
    nuc_step  = xp.full(n_seeds, -1, dtype=xp.int32)
    nuc_depth = xp.zeros(n_seeds, dtype=xp.float32)

    step_log = []

    for turn in range(n_turns):
        t_turn = time.time()

        for s in range(STEPS_PER_TURN):
            global_step = turn * STEPS_PER_TURN + s

            # 1. Archimedes Screw descends
            z += dz_step

            # 2. Temperature [K] and pressure [kbar] at depth z
            T = xp.float32(T_SURFACE) + xp.float32(GAMMA_K_PER_M) * z
            P = z * xp.float32(KBAR_PER_M)

            # 3. Diamond stability: Berman-Simon equilibrium pressure
            #    For T >= T_KIN_FREEZE: P_eq = anchor + slope*(T - T_anchor)
            #    For T < T_KIN_FREEZE: P_eq = P_KINETIC_LOCK (frozen)
            P_eq = xp.where(
                T >= xp.float32(T_KIN_FREEZE),
                xp.float32(P_BS_ANCHOR) + xp.float32(SLOPE_BS) * (T - xp.float32(T_BS_ANCHOR)),
                xp.float32(P_KINETIC_LOCK)
            )

            # 4. In stability field?
            in_stability = (P > P_eq) & (T < xp.float32(T_MAX_STABLE))

            # 5. Maitter step weight: κ/(1+R), R = P/P_norm
            R             = P / xp.float32(P_NORM_KBAR)
            screw_weight  = xp.float32(KAPPA) / (1.0 + R)

            # 6. Carbon input: surface plant drives exponential signal
            c_in  = xp.float32(C_BASE) * xp.exp(-xp.float32(LAMBDA_M) * z)
            carbon = carbon + c_in * screw_weight

            # 7. Nucleation probability (sigmoid over overstep into stability field)
            overstep = xp.maximum(xp.float32(0.0), P - P_eq)
            sig_arg  = (overstep - xp.float32(K_SHIFT)) / xp.float32(K_TRANS)
            p_nuc    = xp.where(
                in_stability & (carbon >= xp.float32(C_MIN_NUCLEATE)),
                1.0 / (1.0 + xp.exp(xp.clip(-sig_arg, -30, 30))),
                xp.float32(0.0)
            )

            # 8. Stochastic nucleation event
            rand_draw    = rng.random(n_seeds, dtype=xp.float32)
            new_nuclei   = (~nucleated) & (rand_draw < p_nuc)
            nucleated    = nucleated | new_nuclei
            nuc_step     = xp.where(new_nuclei, xp.int32(global_step), nuc_step)
            nuc_depth    = xp.where(new_nuclei, z, nuc_depth)

            # 9. Crystal growth: nucleated seeds in stability field grow
            crystal = xp.where(
                nucleated & in_stability,
                crystal + screw_weight,
                crystal
            )

        elapsed  = time.time() - t_turn
        n_nuc    = int(xp.sum(nucleated))
        max_z_km = float(xp.max(z)) / 1000.0
        mean_c   = float(xp.mean(crystal[nucleated])) if n_nuc > 0 else 0.0
        rate     = (n_seeds * STEPS_PER_TURN) / elapsed
        step_log.append({
            "turn": turn + 1,
            "depth_km": max_z_km,
            "n_nucleated": n_nuc,
            "mean_crystal": mean_c,
        })

        if (turn + 1) % 10 == 0 or turn == 0 or turn < 3:
            T_cur = T_SURFACE + GAMMA_K_PER_M * max_z_km * 1000
            P_cur = KBAR_PER_M * max_z_km * 1000
            pct   = 100 * n_nuc / n_seeds
            print(f"  Turn {turn+1:3d}/{n_turns}  "
                  f"z={max_z_km:6.1f}km  T={T_cur:6.0f}K  P={P_cur:5.1f}kbar  "
                  f"nuc={n_nuc:>9,} ({pct:.3f}%)  "
                  f"crys={mean_c:.4f}  {rate/1e6:.1f}M/s")

    total_time = time.time() - t0

    # ── Convert to numpy for analysis ─────────────────────────────────────
    to_np = lambda a: xp.asnumpy(a) if GPU else a
    z_np         = to_np(z)
    crystal_np   = to_np(crystal)
    nuc_np       = to_np(nucleated)
    nuc_depth_np = to_np(nuc_depth)
    nuc_step_np  = to_np(nuc_step)

    n_nuc = int(nuc_np.sum())
    d_arr = nuc_depth_np[nuc_np] if n_nuc > 0 else np.array([])
    c_arr = crystal_np[nuc_np]   if n_nuc > 0 else np.array([])
    t_arr = nuc_step_np[nuc_np]  if n_nuc > 0 else np.array([])

    print(f"\n{'═'*64}")
    print(f"RESULTS — {n_seeds:,} seeds × {n_turns} turns")
    print(f"{'═'*64}")
    print(f"Runtime:             {total_time:.1f}s  ({total_time/60:.1f} min)")
    print(f"Throughput:          {n_seeds*n_turns*STEPS_PER_TURN/total_time/1e9:.2f}B steps/s")
    print(f"Final depth (max):   {np.max(z_np)/1000:.1f} km")
    print(f"")
    print(f"── ♦ Diamond Yield ──")
    print(f"  Nucleated:         {n_nuc:,} / {n_seeds:,}")
    print(f"  Yield:             {100*n_nuc/n_seeds:.4f}%")
    if n_nuc > 0:
        print(f"  Depth mean:        {np.mean(d_arr)/1000:.2f} km")
        print(f"  Depth median:      {np.median(d_arr)/1000:.2f} km")
        print(f"  Depth std:         {np.std(d_arr)/1000:.2f} km")
        print(f"  Depth range:       {np.min(d_arr)/1000:.2f} – {np.max(d_arr)/1000:.2f} km")
        print(f"  Crystal mean:      {np.mean(c_arr):.6f}")
        print(f"  Crystal max:       {np.max(c_arr):.6f}")
        print(f"  Nuc step mean:     {np.mean(t_arr):.1f}")
        print(f"  Nuc step median:   {np.median(t_arr):.1f}")
    print(f"{'═'*64}")

    # ── Suits summary ─────────────────────────────────────────────────────
    z_spade_km   = 0.0
    z_club_km    = z_kinetics_km
    z_heart_km   = z_nucleate_km
    z_diamond_km = float(np.mean(d_arr) / 1000.0) if n_nuc > 0 else None

    print(f"\n── ♠ → ♣ → ♥ → ♦ Transition Depths ──")
    print(f"  ♠ SPADE  (FALL/seed entry):    {z_spade_km:.1f} km")
    print(f"  ♣ CLUB   (LIFT onset/κ active): {z_club_km:.1f} km  (T≥{T_KIN_FREEZE:.0f}K)")
    print(f"  ♥ HEART  (ORBIT/stability):    {z_heart_km:.1f} km  (P≥P_eq, organized flow)")
    print(f"  ♦ DIAMOND (GROUNDED/crystal):  "
          f"{f'{z_diamond_km:.1f} km  (mean nucleation)' if z_diamond_km else 'none nucleated'}")
    print(f"")
    print(f"  HOW_TO_FLY connection:")
    print(f"    LIFT  = ∫∫ ρv²κ · ẑ_up  dA  (wing creates upward gradient)")
    print(f"    DEPTH = ∫∫ ρv²κ · ẑ_dn  dA  (screw creates downward gradient)")
    print(f"    Same integral. ẑ reversed. Diamond = lift pointing down.")

    # ── Depth histogram ───────────────────────────────────────────────────
    hist_lines = ["# depth_km_center  n_nucleated  bar"]
    if n_nuc > 0:
        bins = np.linspace(0, np.max(z_np) / 1000.0, 51)
        counts, edges = np.histogram(d_arr / 1000.0, bins=bins)
        mx = max(counts) if max(counts) > 0 else 1
        for cnt, left, right in zip(counts, edges[:-1], edges[1:]):
            center = (left + right) / 2.0
            bar    = '█' * int(50 * cnt / mx)
            hist_lines.append(f"{center:10.2f}  {cnt:10d}  {bar}")

    # ── Save ──────────────────────────────────────────────────────────────
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'results')
    os.makedirs(out_dir, exist_ok=True)

    summary = {
        "sim": "diamond_hello_world_v2",
        "backend": "cupy_gpu" if GPU else "numpy_cpu",
        "date": "20261009",
        "poem": "The screw does not insist on completing its spin.",
        "n_seeds": n_seeds,
        "n_turns": n_turns,
        "steps_per_turn": STEPS_PER_TURN,
        "total_steps": n_turns * STEPS_PER_TURN,
        "runtime_s": round(total_time, 2),
        "throughput_Bsteps_per_s": round(n_seeds * n_turns * STEPS_PER_TURN / total_time / 1e9, 4),
        "helix": {
            "radius_m": HELIX_RADIUS,
            "pitch_km": HELIX_PITCH / 1000,
            "kappa_per_m": float(KAPPA),
            "dz_per_step_m": dz_step,
            "max_depth_km": max_depth_km,
        },
        "physics": {
            "gamma_K_per_km": GAMMA_K_PER_M * 1000,
            "T_surface_K": T_SURFACE,
            "P_BS_anchor_kbar": P_BS_ANCHOR,
            "T_BS_anchor_K": T_BS_ANCHOR,
            "slope_BS_kbar_per_K": SLOPE_BS,
            "T_kinetic_freeze_K": T_KIN_FREEZE,
            "P_kinetic_lock_kbar": P_KINETIC_LOCK,
            "K_shift_kbar": K_SHIFT,
            "K_trans_kbar": K_TRANS,
            "lambda_decay_per_km": LAMBDA_M * 1000,
            "C_min_nucleate": C_MIN_NUCLEATE,
        },
        "diamonds": {
            "n_nucleated": n_nuc,
            "yield_pct": round(100 * n_nuc / n_seeds, 6),
            "depth_mean_km": round(float(np.mean(d_arr)) / 1000, 3) if n_nuc > 0 else None,
            "depth_median_km": round(float(np.median(d_arr)) / 1000, 3) if n_nuc > 0 else None,
            "depth_std_km": round(float(np.std(d_arr)) / 1000, 3) if n_nuc > 0 else None,
            "depth_min_km": round(float(np.min(d_arr)) / 1000, 3) if n_nuc > 0 else None,
            "depth_max_km": round(float(np.max(d_arr)) / 1000, 3) if n_nuc > 0 else None,
            "crystal_mean": round(float(np.mean(c_arr)), 8) if n_nuc > 0 else None,
            "crystal_max": round(float(np.max(c_arr)), 8) if n_nuc > 0 else None,
            "mean_formation_step": round(float(np.mean(t_arr)), 1) if n_nuc > 0 else None,
        },
        "suit_transitions_km": {
            "spade_fall": z_spade_km,
            "club_lift_onset": round(z_club_km, 2),
            "heart_orbit_stability": round(z_heart_km, 2),
            "diamond_crystal_mean": round(z_diamond_km, 2) if z_diamond_km else None,
        },
        "HOW_TO_FLY_connection": {
            "lift_integral":   "LIFT  = ∫∫ ρv²κ · ẑ_up  dA  (wing → upward gradient)",
            "depth_integral":  "DEPTH = ∫∫ ρv²κ · ẑ_dn  dA  (screw → downward gradient)",
            "unification":     "Same integral, ẑ reversed. Diamond = lift pointing into Earth.",
            "stall_analog":    "Stall = screw step → 0 = crystal lock = diamond formed.",
            "V_mod_field":     "V_mod_field(down) ≥ 1 → diamond. < 1 → humus (graphite-equivalent).",
        },
        "per_turn_log": step_log,
    }

    json_path = os.path.join(out_dir, 'diamond_sim_results.json')
    hist_path = os.path.join(out_dir, 'diamond_depth_hist.txt')

    with open(json_path, 'w') as f:
        json.dump(summary, f, indent=2)
    with open(hist_path, 'w') as f:
        f.write('\n'.join(hist_lines))

    print(f"\nSaved:")
    print(f"  {json_path}")
    print(f"  {hist_path}")

    return summary


if __name__ == '__main__':
    import sys
    n = int(sys.argv[1]) if len(sys.argv) > 1 else N_SEEDS
    t = int(sys.argv[2]) if len(sys.argv) > 2 else N_TURNS
    run_simulation(n_seeds=n, n_turns=t)
