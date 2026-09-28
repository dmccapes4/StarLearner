#!/usr/bin/env python3
"""
star_travel.py  —  CapricornusSortedae applied to stochastic galactic star travel
PORTAL_VISION_V0.1 / star_learning / solar_system_explorer

Author: D. McCapes  
Algorithm: CapricornusSortedae (BeginningToNoww/scripts/04_capricornus_sort.py)  
Date: 2026-09-28

AUTHORSHIP
----------
Operator-authored (D. McCapes):
  Galactic variant of CapricornusSortedae applied to 4D star positions.
  4D state = (x_pc, y_pc, z_pc, field)
  field = normalized velocity magnitude (v_total_km_s / max_v) ∈ [0,1]
  "We don't move by what is most similar. We move by what displaces."
  "That is normalized by what appears closest."

ALGORITHM (corrected)
---------------------
  C   current 4D state vector (normalized)
  S   top-20 candidates sorted by cosine similarity to C (descending)
  I   S[-1] — lowest cosine in top-20 = most novel in neighborhood
              (lowest cosine → highest sin → maximum displacement potential)
  r   random choice from S[0:20]
  For each s in S:
      n(s) = sin(I, s) - cos(r, s)
             sin(I,s) = displacement of s from I
             cos(r,s) = alignment of s with r
             n(s) = escape from both the novel and the random
  c   = argmax_s n(s) — the maximally displacing state
  u   = C projected onto c → the new position

OPERATION COUNT (4D vectors, K=20 pre-stored candidates):
  load C + candidates    :  84 ops
  cosine C vs 20         : 140 ops  (7 ops each: 4 mul + 3 add)
  sort 20                :  86 ops
  n(s) for 20 candidates : 340 ops  (per s: dot=7, sqrt=2, dot=7, sub=1 = 17)
  find argmax, project   :  40 ops
  TOTAL                  : 690 ops per star
  (User estimate: ~400. Actual ~690 at primitive level; ~30 in GDScript vector ops)

JSONL SCHEMA
------------
Per-star: star_positions/{star_name}.jsonl  — one state per line
  {"star": str, "step": int, "epoch_yr": float,
   "x_pc": float, "y_pc": float, "z_pc": float, "field": float,
   "state_4d": [x,y,z,f] normalized,
   "source": "plefr_ledger"|"capricornus_generated",
   "n_score": float, "c_cos_to_C": float}

Global: galactic_field.json
  {"step": int, "player_xyz_pc": [x,y,z],
   "stars": {name: {"xyz_pc":[x,y,z], "field": float, "step": int}},
   "andromeda_active": bool, "andromeda_flip_state": "none"|"vertical"|"both"}

ANDROMEDA
---------
Trigger: player x-coordinate crosses ANDROMEDA_THRESHOLD_PC (≈700,000 pc)
  1. All star x,z positions negated (moving backwards in the heliospheric frame)
  2. View flip state: "vertical" → "both" (game engine applies in two phases)
  3. When star JSONL ledger exhausted: algorithm continues forward,
     positions generated with same CapricornusSortedae but mirrored trailing.
  4. The flipped positions TRAIL the current position in time — echoes.
     (same positions as pre-Andromeda, red-shifted, receding)
  No reflection back. Things continue forward. As we observe them that is.
"""

import json, math, random, os
import numpy as np

# ── Configuration ──────────────────────────────────────────────────────────────
STAR_POSITIONS_DIR = "game/data/star_positions"
GALACTIC_FIELD_FILE = "game/data/galactic_field.json"
PLEFR_TIMELINES_DIR = "game/docs/video/star_timelines"

CANDIDATES_PER_STAR = 20          # S.length == 20
SANDBOX_RADIUS_PC   = 500.0       # beyond this = background echo, not active
ANDROMEDA_THRESHOLD_PC = 700_000  # Milky Way–Andromeda gap ≈ 765 kpc

# Stars with PLEFR JSONL ledgers (from star_timeline.py)
ARC_STARS = ["procyon", "gomeisa", "pollux", "castor", "capella",
             "aldebaran", "rigel", "sirius", "m44"]

os.makedirs(STAR_POSITIONS_DIR, exist_ok=True)
os.makedirs(os.path.dirname(GALACTIC_FIELD_FILE), exist_ok=True)


# ── 4D state helpers ───────────────────────────────────────────────────────────
def load_plefr_states(star_name):
    """Load PLEFR timeline as list of 4D states: (x,y,z,field)."""
    path = os.path.join(PLEFR_TIMELINES_DIR, f"{star_name}_timeline.jsonl")
    states = []
    if not os.path.exists(path):
        return states
    max_v = 1.0  # will normalize field
    raw = []
    with open(path) as f:
        for line in f:
            r = json.loads(line.strip())
            xyz = r.get("xyz_pc", [0, 0, 0])
            v = r.get("v_total_km_s", 0.0)
            raw.append((xyz[0], xyz[1], xyz[2], v, r.get("epoch_yr", 0)))
    if raw:
        max_v = max(r[3] for r in raw) or 1.0
        for x, y, z, v, epoch in raw:
            states.append({
                "xyz": [x, y, z],
                "field": v / max_v,
                "epoch_yr": epoch,
                "source": "plefr_ledger"
            })
    return states


def state_to_vec4(state):
    """
    4D vector: (unit_direction, field). Normalize to unit 4-sphere.

    v0.0.3 FIX — mirror not oracle:
    Previous: v = (x_pc, y_pc, z_pc, v_vel/max_v) — distant stars (Rigel 237pc,
    M44 184pc) had field≈0 AND the raw parsec magnitudes dominated the norm,
    collapsing the 4th dimension entirely. All candidates had cosine≈1.0000.
    n(s) = sin(I,s) - cos(r,s) ≈ -1 for all s. Algorithm had nothing to displace.

    Fix: normalize the spatial part to unit direction FIRST, then attach field.
    field = 1 / sqrt(1 + dist_pc/10)  — galactic field mirror:
       Sirius  2.6pc  → 0.891   Procyon  3.5pc  → 0.859
       Pollux 10.0pc  → 0.707   Capella 13.0pc  → 0.660
       Aldebaran 20pc → 0.577   Castor  52.0pc  → 0.400
       Gomeisa 168pc  → 0.237   M44    184pc   → 0.227
       Rigel   237pc  → 0.203

    The 4D vector is now well-conditioned for all distances.
    The field reflects actual galactic topology: nearer = stronger influence.
    "ALGORITHM = mirror, not oracle."  — BUENAS_DIA_VOLARE
    """
    xyz = np.array(state["xyz"], dtype=float)
    dist_pc = float(np.linalg.norm(xyz))
    # spatial part: unit direction (prevents far-star collapse)
    xyz_dir = xyz / (dist_pc + 1e-10)
    # field: inverse-sqrt of distance — galactic field mirror
    field = 1.0 / math.sqrt(1.0 + dist_pc / 10.0)
    v = np.array([xyz_dir[0], xyz_dir[1], xyz_dir[2], field])
    norm = np.linalg.norm(v)
    if norm < 1e-10:
        return np.array([1.0, 0.0, 0.0, 0.0])
    return v / norm


def vec4_to_state(vec, step, star_name, source="capricornus_generated",
                  n_score=0.0, c_cos=0.0, epoch_yr=0.0):
    """Convert unit 4D vector back to a state dict."""
    return {
        "star": star_name,
        "step": step,
        "epoch_yr": epoch_yr,
        "x_pc": float(vec[0]),
        "y_pc": float(vec[1]),
        "z_pc": float(vec[2]),
        "field": float(vec[3]),
        "state_4d": [float(x) for x in vec],
        "source": source,
        "n_score": n_score,
        "c_cos_to_C": c_cos,
    }


# ── CapricornusSortedae galactic step ─────────────────────────────────────────
def capricornus_galactic_step(C_vec, candidates):
    """
    Single CapricornusSortedae step for one star.

    C_vec    : current 4D unit vector
    candidates: list of 4D unit vectors (pre-loaded top-20 from JSONL)

    Returns (u_vec, chosen_c, n_score)

    Algorithm:
      S   = candidates sorted by cosine(C, s) descending
      I   = S[-1]  — lowest cosine in S = highest sin = max displacement
      r   = random(S)
      n(s) = sin(I, s) - cos(r, s)   for each s in S
      c   = argmax n(s)
      u   = C projected onto c
    """
    if not candidates:
        return C_vec, C_vec, 0.0

    # Step 1: sort by cosine similarity to C (descending)
    sims = [(float(np.dot(C_vec, s)), s) for s in candidates]
    sims.sort(key=lambda t: -t[0])
    S = [s for _, s in sims]

    # Step 2: I = lowest cosine in top-20 (S[-1])
    I = S[-1]

    # Step 3: r = random from S
    r = random.choice(S)

    # Step 4: n(s) = sin(I,s) - cos(r,s) for each s
    # sin(I, s) = sqrt(1 - cos(I,s)^2)
    # cos(r, s) = dot(r, s)
    best_n, best_s = -float("inf"), S[0]
    for s in S:
        cos_Is = float(np.dot(I, s))
        sin_Is = math.sqrt(max(0.0, 1.0 - cos_Is * cos_Is))
        cos_rs = float(np.dot(r, s))
        n_s = sin_Is - cos_rs
        if n_s > best_n:
            best_n, best_s = n_s, s

    c = best_s

    # Step 5: u = C projected onto c
    proj_scalar = float(np.dot(C_vec, c))
    u = proj_scalar * c
    u_norm = np.linalg.norm(u)
    if u_norm > 1e-10:
        u = u / u_norm  # re-normalize to unit sphere

    return u, c, best_n


# ── Candidate generation ───────────────────────────────────────────────────────
def sample_candidates_from_ledger(plefr_states, current_step, n=20):
    """
    v0.0.2: Sample N candidates SPREAD across the full ledger — not sequential.

    Sequential sampling (v0.0.1) produced a tight cluster (cosine≈1.0000):
    all 20 candidates were adjacent time steps, essentially identical vectors.
    The CapricornusSortedae algorithm had zero displacement range → n_score→-1.

    Spread sampling: step = ledger_size // n, offset by current_step.
    Each candidate is one full screw-pitch apart in the PLEFR timeline.
    Like the outer planets: same orbital body, different axial position per turn.
    The pitch (interval) is the ρ — drift coupling, entropy, sideways movement.
    """
    total = len(plefr_states)
    if total < n:
        return [state_to_vec4(s) for s in plefr_states]
    step = max(1, total // n)                      # ρ — the pitch of the thread
    indices = [(current_step + 1 + i * step) % total for i in range(n)]
    return [state_to_vec4(plefr_states[j]) for j in indices]


# ── Andromeda mechanic ─────────────────────────────────────────────────────────
def apply_andromeda_flip(state_dict, flip_state="both"):
    """
    When entering Andromeda:
      vertical flip: negate y (view flip phase 1)
      both:          also negate x,z (positions move backwards, phase 2)

    The JSONL ledger when exhausted continues forward with same positions
    trailing — mirrored, red-shifted. Echoes recede. Things don't reflect back.
    """
    if flip_state == "vertical":
        state_dict["y_pc"] = -state_dict["y_pc"]
        state_dict["state_4d"][1] = -state_dict["state_4d"][1]
    elif flip_state == "both":
        state_dict["x_pc"] = -state_dict["x_pc"]
        state_dict["z_pc"] = -state_dict["z_pc"]
        state_dict["y_pc"] = -state_dict["y_pc"]
        state_dict["state_4d"][0] = -state_dict["state_4d"][0]
        state_dict["state_4d"][1] = -state_dict["state_4d"][1]
        state_dict["state_4d"][2] = -state_dict["state_4d"][2]
    return state_dict


# ── Per-star ledger I/O ────────────────────────────────────────────────────────
def read_star_ledger(star_name):
    path = os.path.join(STAR_POSITIONS_DIR, f"{star_name}.jsonl")
    states = []
    if os.path.exists(path):
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line:
                    states.append(json.loads(line))
    return states

def append_star_ledger(star_name, state_dict):
    path = os.path.join(STAR_POSITIONS_DIR, f"{star_name}.jsonl")
    with open(path, "a") as f:
        f.write(json.dumps(state_dict) + "\n")


# ── Galactic field ─────────────────────────────────────────────────────────────
def load_galactic_field():
    if os.path.exists(GALACTIC_FIELD_FILE):
        with open(GALACTIC_FIELD_FILE) as f:
            return json.load(f)
    return {
        "step": 0,
        "player_xyz_pc": [0.0, 0.0, 0.0],
        "stars": {},
        "andromeda_active": False,
        "andromeda_flip_state": "none",
    }

def save_galactic_field(field):
    with open(GALACTIC_FIELD_FILE, "w") as f:
        json.dump(field, f, indent=2)


# ── Main update step ───────────────────────────────────────────────────────────
def player_step(player_xyz, decision_vector=None):
    """
    Called once per player decision.
    player_xyz      : [x, y, z] in parsecs (player's new position)
    decision_vector : optional 4D hint from player action (if None, use current)

    Each star runs one CapricornusSortedae step.
    Returns updated galactic_field dict.

    ~690 primitive operations per star (or ~30 GDScript Vector4 ops).
    With 9 arc stars: ~6,200 primitive ops total per player decision.
    """
    field = load_galactic_field()
    field["step"] += 1
    field["player_xyz_pc"] = list(player_xyz)

    # Check Andromeda threshold
    dist_from_origin = math.sqrt(sum(x*x for x in player_xyz))
    if dist_from_origin > ANDROMEDA_THRESHOLD_PC and not field["andromeda_active"]:
        field["andromeda_active"] = True
        field["andromeda_flip_state"] = "vertical"
        print(f"[Andromeda] Threshold crossed at dist={dist_from_origin:.0f} pc — vertical flip")
    elif field["andromeda_active"] and field["andromeda_flip_state"] == "vertical":
        field["andromeda_flip_state"] = "both"
        print("[Andromeda] Full flip engaged — stars moving backwards")

    for star_name in ARC_STARS:
        plefr = load_plefr_states(star_name)
        if not plefr:
            continue

        ledger = read_star_ledger(star_name)
        current_step = len(ledger)

        # Current state: from ledger or initial PLEFR position
        if ledger:
            last = ledger[-1]
            C_vec = np.array(last["state_4d"], dtype=float)
            if np.linalg.norm(C_vec) < 1e-10:
                C_vec = state_to_vec4(plefr[0])
        else:
            C_vec = state_to_vec4(plefr[0])

        # Candidates from PLEFR ledger (or generated if exhausted)
        candidates = sample_candidates_from_ledger(plefr, current_step, CANDIDATES_PER_STAR)

        # Run CapricornusSortedae step
        u_vec, c_vec, n_score = capricornus_galactic_step(C_vec, candidates)

        # Build new state
        # Unproject u from unit sphere to actual parsec coordinates
        # u_vec is a unit direction; scale by distance of c in parsec space
        c_state = plefr[(current_step + CANDIDATES_PER_STAR) % len(plefr)]
        scale = math.sqrt(c_state["xyz"][0]**2 + c_state["xyz"][1]**2 + c_state["xyz"][2]**2)
        new_state = {
            "star": star_name,
            "step": current_step,
            "epoch_yr": c_state.get("epoch_yr", 0.0),
            "x_pc": float(u_vec[0] * scale),
            "y_pc": float(u_vec[1] * scale),
            "z_pc": float(u_vec[2] * scale),
            "field": float(abs(u_vec[3])),
            "state_4d": [float(x) for x in u_vec],
            "source": "capricornus_generated" if current_step >= len(plefr) else "plefr_ledger",
            "n_score": n_score,
            "c_cos_to_C": float(np.dot(c_vec, C_vec)),
        }

        # Apply Andromeda flip
        if field["andromeda_active"] and field["andromeda_flip_state"] != "none":
            new_state = apply_andromeda_flip(new_state, field["andromeda_flip_state"])

        # Filter sandbox: beyond radius = background echo, don't process
        dist = math.sqrt(new_state["x_pc"]**2 + new_state["y_pc"]**2 + new_state["z_pc"]**2)
        if dist > SANDBOX_RADIUS_PC and not field["andromeda_active"]:
            pass  # background star — skip ledger update, keep as echo
        else:
            append_star_ledger(star_name, new_state)
            field["stars"][star_name] = {
                "xyz_pc": [new_state["x_pc"], new_state["y_pc"], new_state["z_pc"]],
                "field": new_state["field"],
                "n_score": new_state["n_score"],   ## v0.0.3: propagate for HUD mirror
                "step": current_step,
            }

    save_galactic_field(field)
    return field


# ── Operation count report ─────────────────────────────────────────────────────
def report_ops(k=20):
    ops = {
        "load_C":              4,
        "load_candidates":     k * 4,
        "cosine_C_vs_S":       k * 7,    # 4 mul + 3 add per dot product
        "sort_S":              int(k * math.log2(k)),
        "n(s)_per_candidate":  k * 17,   # dot(I,s)=7, sqrt=2, dot(r,s)=7, sub=1
        "find_argmax":         k,
        "normalize_u":         12,
        "project_C_onto_c":    7,
        "write_state":         4,
    }
    total = sum(ops.values())
    print(f"\nCapricornusSortedae operation count (K={k} candidates, 4D vectors):")
    for name, count in ops.items():
        print(f"  {name:30s}: {count:4d}")
    print(f"  {'TOTAL':30s}: {total:4d}  (user estimate: ~400)")
    print(f"\n  9 arc stars × {total} ops = {9*total:,d} primitive ops per player decision")
    print(f"  In GDScript (Vector4 ops as atomic): ~{k*2 + 15} ops per star")
    return total


if __name__ == "__main__":
    import sys
    report_ops()

    if "--generate" in sys.argv:
        # ── Generate galactic_journey.jsonl ─────────────────────────────────
        # v0.0.3: 150 steps, distance-based field, honest 4D vectors
        N_STEPS = 150
        JOURNEY_OUT = "game/data/galactic_journey.jsonl"
        SEED = 97718  # same seed as BeginningToNoww run 1

        print(f"\n[v0.0.3] Generating {N_STEPS}-step galactic journey (seed {SEED})...")
        random.seed(SEED)

        # Reset per-star ledgers
        import shutil
        if os.path.exists(STAR_POSITIONS_DIR):
            shutil.rmtree(STAR_POSITIONS_DIR)
        os.makedirs(STAR_POSITIONS_DIR, exist_ok=True)

        # Reset galactic field
        if os.path.exists(GALACTIC_FIELD_FILE):
            os.remove(GALACTIC_FIELD_FILE)

        steps_written = 0
        with open(JOURNEY_OUT, "w") as jf:
            for step_i in range(N_STEPS):
                # Player drifts slowly from origin — Sol steering through cosmos
                t = step_i / max(1, N_STEPS - 1)
                px = 0.001 + t * 0.5   # drift 0.5 pc over journey
                py = math.sin(t * math.pi * 0.5) * 0.05   # small y excursion
                pz = math.cos(t * math.pi * 0.3) * 0.03   # small z excursion
                player_xyz = [px, py, pz]

                field = player_step(player_xyz)
                field["step"] = step_i + 1

                line = json.dumps(field)
                jf.write(line + "\n")
                steps_written += 1

                # Print progress every 10 steps
                if (step_i + 1) % 10 == 0:
                    # Sample n_score from one active star
                    sample_star = None
                    for sn in ARC_STARS:
                        ledger = read_star_ledger(sn)
                        if ledger:
                            ns = ledger[-1].get("n_score", 0)
                            sample_star = f"{sn} n={ns:.3f}"
                            break
                    print(f"  Step {step_i+1:3d}/{N_STEPS}  {sample_star or ''}")

        print(f"\n[Done] {steps_written} steps → {JOURNEY_OUT}")
        # Quick field stats
        field_final = load_galactic_field()
        for sn in ARC_STARS:
            ledger = read_star_ledger(sn)
            if ledger and len(ledger) >= 3:
                scores = [s.get("n_score", 0) for s in ledger[-5:]]
                print(f"  {sn:12s}  last-5 n_score: {[f'{x:.3f}' for x in scores]}")

    else:
        print("\nSelf-test: one step for procyon...")
        field = player_step([0.001, 0.0, 0.0])
        if "procyon" in field["stars"]:
            s = field["stars"]["procyon"]
            print(f"  procyon new xyz_pc: {s['xyz_pc']}")
            print(f"  field: {s['field']:.4f}  step: {s['step']}")
        print("Done.\n")
        print("To regenerate galactic_journey.jsonl (150 steps, v0.0.3):")
        print("  python3 game/tools/star_travel.py --generate")
