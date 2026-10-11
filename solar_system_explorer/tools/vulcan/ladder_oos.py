#!/usr/bin/env python3
"""
ladder_oos.py — Game plan §4. Out-of-sample test of the id/iv ladder.

A proportion that is a LAW must hold in systems it was not written on. A
proportion that is a COINCIDENCE holds only where it was found.

Method
  1. Keep only the ladder lines that contain no Sol-system-specific construct
     (no AB/HB belts, no Luna, no rings, no Mercury/Vulcan pair, no Planet X).
     Three lines survive: 1, 3, 5.  (Lines 3 and 5 are permutations of each other.)
  2. Map each Sol-system role to a body in another hierarchical system by a
     rule fixed BEFORE looking at the numbers:
        ordinal  — k-th body by distance from the primary ↔ k-th planet from Sol
                   (Mercury=1 … Neptune=8, Pluto=9); Sol ↔ primary
        massrank — k-th most massive ↔ k-th most massive planet
                   (Jupiter=1, Saturn=2, Neptune=3, Uranus=4, Earth=5, Venus=6,
                    Mars=7, Mercury=8, Pluto=9); size rank where masses unknown
  3. Compute the same four hypotheses (H1_id, H1_iv, H2_mirror_eq, H3_mirror_inv)
     over the same metrics with the same 0.30-dex 'hold' threshold.
  4. Null: random bijection of roles → bodies (primary fixed), 4000 trials per
     system per mapping.  p = fraction of random mappings with hold-rate ≥ the
     rule-based mapping.
  5. Recurrence: for every (line, metric, hypothesis) that HOLDS in the Sol
     system, count the out-of-sample systems in which it also holds.

Systems: Saturn (9 moons incl. Phoebe), Jupiter (9 moons incl. Himalia),
TRAPPIST-1 (7, Agol+2021), Kepler-90 (8 incl. i), HD 10180 (6, m sin i).
Outputs: data/ladder_oos.json, img/ladder_oos_01_recurrence.png, img/ladder_oos_02_null.png
"""
import os, json, math, random
import numpy as np
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
plt.rcParams.update({"figure.facecolor":"#0b0d17","axes.facecolor":"#0b0d17","axes.edgecolor":"#667","axes.labelcolor":"#dde",
    "xtick.color":"#bbc","ytick.color":"#bbc","text.color":"#eef","grid.color":"#223","legend.facecolor":"#141829","legend.edgecolor":"#445"})
HERE = os.path.dirname(os.path.abspath(__file__))
DOC  = os.path.abspath(os.path.join(HERE, "..", "..", "docs", "MERCURY_VULCAN_LADDER_20261010"))
DATA = os.path.join(DOC, "data"); IMG = os.path.join(DOC, "img")
random.seed(20261010)
M_E = 5.9722e24; R_E = 6371.0; M_SUN = 1.98892e30; R_SUN = 695700.0; AU_KM = 1.495978707e8
METRICS = ["mass", "radius", "a", "period", "rot", "density"]
HYP = ("H1_id", "H1_iv", "H2_mirror_eq", "H3_mirror_inv")

def body(mass=None, radius=None, a=None, period=None, rot=None, density=None):
    if density is None and mass and radius: density = mass/(4/3*math.pi*(radius*1e3)**3)
    return dict(mass=mass, radius=radius, a=a, period=period, rot=rot, density=density)

# ---------------------------------------------------------------------------
# Systems. a in km (moons) or AU (planets) — only ratios are used. period in days.
# ---------------------------------------------------------------------------
SOL = {  # the in-sample system, same numbers as ladder_analysis (a in AU, period d)
 "primary": body(M_SUN, R_SUN, rot=25.05),
 "mercury": body(3.3011e23, 2439.7, 0.387098, 87.969, 58.646), "venus": body(4.8675e24, 6051.8, 0.723332, 224.701, 243.025),
 "earth": body(5.9722e24, 6371.0, 1.0, 365.256, 0.99727), "mars": body(6.4171e23, 3389.5, 1.523679, 686.98, 1.02596),
 "jupiter": body(1.8982e27, 69911, 5.2044, 4332.59, 0.41354), "saturn": body(5.6834e26, 58232, 9.5826, 10759.22, 0.44401),
 "uranus": body(8.6810e25, 25362, 19.2184, 30688.5, 0.71833), "neptune": body(1.02413e26, 24622, 30.11, 60182, 0.6713),
 "pluto": body(1.303e22, 1188.3, 39.482, 90560, 6.3872),
}
SATURN = {
 "primary": body(5.6834e26, 58232, rot=0.44401),
 "Mimas": body(3.75e19, 198.2, 185539, 0.942, 0.942), "Enceladus": body(1.080e20, 252.1, 237948, 1.370, 1.370),
 "Tethys": body(6.175e20, 531.1, 294619, 1.888, 1.888), "Dione": body(1.095e21, 561.4, 377396, 2.737, 2.737),
 "Rhea": body(2.307e21, 763.8, 527108, 4.518, 4.518), "Titan": body(1.3452e23, 2574.7, 1221870, 15.945, 15.945),
 "Hyperion": body(5.6e18, 135.0, 1481010, 21.28, None), "Iapetus": body(1.806e21, 734.5, 3560820, 79.32, 79.32),
 "Phoebe": body(8.29e18, 106.5, 12947780, 550.56, 0.386),
}
JUPITER = {
 "primary": body(1.8982e27, 69911, rot=0.41354),
 "Metis": body(3.6e16, 21.5, 128000, 0.295, 0.295), "Adrastea": body(2.0e15, 8.2, 129000, 0.298, 0.298),
 "Amalthea": body(2.08e18, 83.5, 181400, 0.498, 0.498), "Thebe": body(4.3e17, 49.3, 221900, 0.675, 0.675),
 "Io": body(8.93e22, 1821.6, 421700, 1.769, 1.769), "Europa": body(4.80e22, 1560.8, 671034, 3.551, 3.551),
 "Ganymede": body(1.4819e23, 2634.1, 1070412, 7.155, 7.155), "Callisto": body(1.0759e23, 2410.3, 1882709, 16.689, 16.689),
 "Himalia": body(4.2e18, 85.0, 11461000, 250.56, 0.323),
}
TRAPPIST1 = {  # Agol et al. 2021 PSJ 2, 1
 "primary": body(0.0898*M_SUN, 0.1192*R_SUN, rot=3.3),
 "b": body(1.374*M_E, 1.116*R_E, 0.01154, 1.5109), "c": body(1.308*M_E, 1.097*R_E, 0.01580, 2.4218),
 "d": body(0.388*M_E, 0.788*R_E, 0.02227, 4.0496), "e": body(0.692*M_E, 0.920*R_E, 0.02925, 6.1010),
 "f": body(1.039*M_E, 1.045*R_E, 0.03849, 9.2076), "g": body(1.321*M_E, 1.129*R_E, 0.04683, 12.352),
 "h": body(0.326*M_E, 0.755*R_E, 0.06189, 18.773),
}
KEPLER90 = {  # radii from Kepler; masses unknown except weak TTV limits → left None
 "primary": body(1.2*M_SUN, 1.2*R_SUN),
 "b": body(None, 1.31*R_E, 0.074, 7.008), "c": body(None, 1.18*R_E, 0.089, 8.719), "i": body(None, 1.32*R_E, 0.107, 14.449),
 "d": body(None, 2.87*R_E, 0.32, 59.737), "e": body(None, 2.66*R_E, 0.42, 91.939), "f": body(None, 2.88*R_E, 0.48, 124.914),
 "g": body(None, 8.13*R_E, 0.71, 210.483), "h": body(None, 11.32*R_E, 1.01, 331.6),
}
HD10180 = {  # m sin i; six confirmed planets (b, i, j unconfirmed — excluded)
 "primary": body(1.06*M_SUN, 1.2*R_SUN, rot=24.0),
 "c": body(13.2*M_E, None, 0.0641, 5.7597), "d": body(11.9*M_E, None, 0.1286, 16.354), "e": body(25.4*M_E, None, 0.2699, 49.75),
 "f": body(23.6*M_E, None, 0.4929, 122.7), "g": body(21.4*M_E, None, 1.422, 602.0), "h": body(65.7*M_E, None, 3.40, 2222.0),
}
SYSTEMS = {"Sol (in-sample)": SOL, "Saturn moons": SATURN, "Jupiter moons": JUPITER, "TRAPPIST-1": TRAPPIST1, "Kepler-90": KEPLER90, "HD 10180": HD10180}

# ---------------------------------------------------------------------------
# Clean ladder lines (roles in Sol vocabulary). pluto_charon → pluto (the body).
# ---------------------------------------------------------------------------
LINES = [
 (("primary", "jupiter", "mars"),  ("neptune", "saturn", "pluto")),   # line 1
 (("venus", "primary", "jupiter"), ("saturn", "jupiter", "neptune")), # line 3
 (("primary", "jupiter", "venus"), ("neptune", "jupiter", "saturn")), # line 5
]
ROLES = sorted({r for l in LINES for t in l for r in t if r != "primary"})
SOL_DIST_RANK = {"mercury":1, "venus":2, "earth":3, "mars":4, "jupiter":5, "saturn":6, "uranus":7, "neptune":8, "pluto":9}
SOL_MASS_RANK = {"jupiter":1, "saturn":2, "neptune":3, "uranus":4, "earth":5, "venus":6, "mars":7, "mercury":8, "pluto":9}

def mapping(system, rule):
    bodies = [k for k in system if k != "primary"]
    if rule == "ordinal":
        order = sorted(bodies, key=lambda k: system[k]["a"])
        ranks = SOL_DIST_RANK
    else:
        key = "mass" if all(system[k]["mass"] for k in bodies) else "radius"
        order = sorted(bodies, key=lambda k: -system[k][key])
        ranks = SOL_MASS_RANK
    m = {"primary": "primary"}
    for role in ROLES:
        k = ranks[role] - 1
        m[role] = order[k] if k < len(order) else None
    return m

def lg(x): return math.log10(abs(x)) if (x is not None and x != 0) else None
def rdex(system, m, a, b):
    if a is None or b is None: return None
    va, vb = lg(system[a][m]), lg(system[b][m])
    return None if (va is None or vb is None) else va - vb

def evaluate(system, mp):
    """Return dict[(line_idx, metric, hyp)] = residual_dex (or None if not evaluable)."""
    out = {}
    for li, (t1, t2) in enumerate(LINES):
        A = [mp.get(r) for r in t1]; B = [mp.get(r) for r in t2]
        for m in METRICS:
            r1, r2 = rdex(system, m, A[0], A[1]), rdex(system, m, A[1], A[2])
            s1, s2 = rdex(system, m, B[0], B[1]), rdex(system, m, B[1], B[2])
            out[(li, m, "H1_id")] = (r1 - r2) if (r1 is not None and r2 is not None) else None
            out[(li, m, "H1_iv")] = (s1 - s2) if (s1 is not None and s2 is not None) else None
            out[(li, m, "H2_mirror_eq")] = (r1 - s1) if (r1 is not None and s1 is not None) else None
            out[(li, m, "H3_mirror_inv")] = (r1 + s1) if (r1 is not None and s1 is not None) else None
    return out
def rate(ev):
    vals = [v for v in ev.values() if v is not None]
    return (sum(abs(v) < 0.30 for v in vals), len(vals))

# ---------------------------------------------------------------------------
# In-sample reference: Sol on the clean lines (identity mapping)
# ---------------------------------------------------------------------------
sol_map = {"primary": "primary", **{r: r for r in ROLES}}
sol_ev = evaluate(SOL, sol_map)
sol_holds = {k for k, v in sol_ev.items() if v is not None and abs(v) < 0.30}
n_sol, tot_sol = rate(sol_ev)

RESULTS = {}; RECUR = {k: [] for k in sol_holds}
for sname, system in SYSTEMS.items():
    if sname.startswith("Sol"): continue
    bodies = [k for k in system if k != "primary"]
    RESULTS[sname] = {}
    for rule in ("ordinal", "massrank"):
        mp = mapping(system, rule)
        ev = evaluate(system, mp)
        n, tot = rate(ev)
        # permutation null
        null = []
        for _ in range(4000):
            perm = random.sample(bodies, min(len(bodies), len(ROLES)))
            rm = {"primary": "primary", **{r: (perm[i] if i < len(perm) else None) for i, r in enumerate(ROLES)}}
            nn, tt = rate(evaluate(system, rm))
            null.append(nn/tt if tt else float("nan"))
        null = np.array([x for x in null if not np.isnan(x)])
        obs = n/tot if tot else None
        p = float((null >= obs).mean()) if obs is not None and len(null) else None
        for k in sol_holds:
            v = ev.get(k)
            RECUR[k].append(dict(system=sname, rule=rule, residual=v, holds=(None if v is None else abs(v) < 0.30)))
        RESULTS[sname][rule] = dict(mapping={r: mp[r] for r in ROLES}, holds=n, tests=tot, rate=obs, null_mean=float(null.mean()) if len(null) else None,
                                    null_p95=float(np.percentile(null, 95)) if len(null) else None, p_value=p,
                                    residuals={f"L{li+1}|{m}|{h}": (None if v is None else round(v, 3)) for (li, m, h), v in ev.items() if v is not None})

# recurrence summary
REC_ROWS = []
for k in sorted(sol_holds):
    li, m, h = k
    ev_list = [r for r in RECUR[k] if r["holds"] is not None]
    REC_ROWS.append(dict(line=li+1, metric=m, hypothesis=h, sol_residual=round(sol_ev[k], 3), oos_evaluable=len(ev_list),
                         oos_holds=sum(r["holds"] for r in ev_list), detail=RECUR[k]))
tot_eval = sum(r["oos_evaluable"] for r in REC_ROWS); tot_hold = sum(r["oos_holds"] for r in REC_ROWS)
nd = [r for r in REC_ROWS if r["metric"] != "density"]
tot_eval_nd = sum(r["oos_evaluable"] for r in nd); tot_hold_nd = sum(r["oos_holds"] for r in nd)

# Metric degeneracy: fraction of ALL pairwise ratios within a system that are already < 0.30 dex.
# A metric with a high value here will 'hold' for almost any triplet — the hold says nothing about the ladder.
DEGEN = {}
for sname, system in SYSTEMS.items():
    DEGEN[sname] = {}
    for m in METRICS:
        vals = [lg(system[k][m]) for k in system if k != "primary" and lg(system[k][m]) is not None]
        pairs = [(abs(a - b) < 0.30) for i, a in enumerate(vals) for b in vals[i+1:]]
        DEGEN[sname][m] = (round(sum(pairs)/len(pairs), 3) if pairs else None)

# ---------------------------------------------------------------------------
# Figures
# ---------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(11, 0.5*len(REC_ROWS)+2.5))
labels = [f"L{r['line']} {r['metric']} {r['hypothesis']}" for r in REC_ROWS]
sysrule = [(s, ru) for s in RESULTS for ru in ("ordinal", "massrank")]
grid = np.full((len(REC_ROWS), len(sysrule)), np.nan)
for i, r in enumerate(REC_ROWS):
    for d in r["detail"]:
        j = sysrule.index((d["system"], d["rule"]))
        if d["residual"] is not None: grid[i, j] = abs(d["residual"])
im = ax.imshow(grid, cmap="RdYlGn_r", vmin=0, vmax=1.5, aspect="auto")
for i in range(grid.shape[0]):
    for j in range(grid.shape[1]):
        v = grid[i, j]
        ax.text(j, i, "—" if np.isnan(v) else f"{v:.2f}", ha="center", va="center", fontsize=8, color="#000" if (not np.isnan(v) and v < 0.3) else "#eee", fontweight="bold" if (not np.isnan(v) and v < 0.3) else "normal")
ax.set_xticks(range(len(sysrule))); ax.set_xticklabels([f"{s}\n{ru}" for s, ru in sysrule], fontsize=8)
ax.set_yticks(range(len(REC_ROWS))); ax.set_yticklabels(labels, fontsize=8)
ax.set_title(f"Every proportion that HOLDS in the Sol system ({len(REC_ROWS)}), re-tested out of sample: {tot_hold}/{tot_eval} recur (|residual| dex; bold < 0.30)")
plt.colorbar(im, ax=ax, fraction=0.02, pad=0.01).set_label("|residual| (dex)")
fig.tight_layout(); fig.savefig(os.path.join(IMG, "ladder_oos_01_recurrence.png"), dpi=130); plt.close(fig)

fig, ax = plt.subplots(figsize=(10, 5))
xs, obs_r, nul_r, p95 = [], [], [], []
for s in RESULTS:
    for ru in ("ordinal", "massrank"):
        d = RESULTS[s][ru]
        if d["rate"] is None: continue
        xs.append(f"{s}\n{ru}"); obs_r.append(d["rate"]); nul_r.append(d["null_mean"]); p95.append(d["null_p95"])
x = np.arange(len(xs))
ax.bar(x-0.2, obs_r, 0.4, color="#ffd166", label="rule-based mapping hold-rate")
ax.bar(x+0.2, nul_r, 0.4, color="#4fd1ff", label="random-mapping mean hold-rate")
ax.plot(x+0.2, p95, "v", color="#ff5c7a", label="random 95th percentile")
ax.axhline(n_sol/tot_sol, color="#eee", ls="--", label=f"Sol in-sample on the same lines ({n_sol}/{tot_sol})")
ax.set_xticks(x); ax.set_xticklabels(xs, fontsize=7); ax.set_ylabel("fraction of tests with |residual| < 0.30 dex"); ax.legend(fontsize=8); ax.grid(True, axis="y", alpha=0.4)
ax.set_title("Out-of-sample ladder: does a pre-declared role mapping beat a random one?")
fig.tight_layout(); fig.savefig(os.path.join(IMG, "ladder_oos_02_null.png"), dpi=130); plt.close(fig)

OUT = dict(method=__doc__, roles=ROLES, lines=[dict(id=list(a), iv=list(b)) for a, b in LINES],
           sol_in_sample=dict(holds=n_sol, tests=tot_sol, rate=n_sol/tot_sol, holding_tests=[f"L{k[0]+1}|{k[1]}|{k[2]}" for k in sorted(sol_holds)]),
           systems=RESULTS, recurrence=REC_ROWS, recurrence_total=dict(oos_evaluable=tot_eval, oos_holds=tot_hold, rate=(tot_hold/tot_eval if tot_eval else None)),
           recurrence_excluding_density=dict(oos_evaluable=tot_eval_nd, oos_holds=tot_hold_nd, rate=(tot_hold_nd/tot_eval_nd if tot_eval_nd else None)),
           metric_degeneracy_pairwise_lt_0p30dex=DEGEN,
           chance_rate_at_threshold="≈ 0.10–0.16 (ladder_null.json: random-triplet hold rate 0.107 mean, 0.164 p95)",
           n_mapping_tests=sum(1 for s in RESULTS for ru in RESULTS[s] if RESULTS[s][ru]["rate"] is not None),
           n_mapping_tests_p_lt_0p05=sum(1 for s in RESULTS for ru in RESULTS[s] if RESULTS[s][ru]["p_value"] is not None and RESULTS[s][ru]["p_value"] < 0.05))
json.dump(OUT, open(os.path.join(DATA, "ladder_oos.json"), "w"), indent=1, default=str)

print(f"Sol in-sample on clean lines: {n_sol}/{tot_sol} hold")
for s in RESULTS:
    for ru in ("ordinal", "massrank"):
        d = RESULTS[s][ru]; print(f"{s:14s} {ru:9s} {d['holds']:2d}/{d['tests']:2d}  rate={d['rate']}  null={d['null_mean']:.3f} p95={d['null_p95']:.3f}  p={d['p_value']}  map={d['mapping']}")
print(f"recurrence of Sol holds out of sample: {tot_hold}/{tot_eval}")
for r in REC_ROWS: print(f"  L{r['line']} {r['metric']:8s} {r['hypothesis']:14s} sol={r['sol_residual']:+.3f}  oos {r['oos_holds']}/{r['oos_evaluable']}")
print(f"excluding density: {tot_hold_nd}/{tot_eval_nd}")
print("metric degeneracy (fraction of pairwise ratios already < 0.30 dex):")
for s in DEGEN: print(f"  {s:14s}", DEGEN[s])
