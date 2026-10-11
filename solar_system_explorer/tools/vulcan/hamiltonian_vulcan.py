#!/usr/bin/env python3
"""
hamiltonian_vulcan.py — looking for Vulcan with Hamiltonians.

Three Hamiltonians, each one honest about what it is:

  A. Classical test particle around Sol, H = p²/2 − GM/r, written as the
     effective potential U_eff(r) = −GM/r + L²/(2r²) on the spheral grid.
     Mercury's interior mean-motion resonances and the published vulcanoid
     stability zone are laid on top.  This is the real physics.

  B. A tight-binding (hopping) Hamiltonian on the spheral chain, shells
     n = 1..N, diagonal U_eff(n), nearest-shell hopping t, plus Mercury as a
     scatterer on the shells it sweeps (66–100), weighted by the time it spends
     in each.  Ground-state leakage into Mercury's shells vs the circular-orbit
     radius gives a "where can a body sit without touching Mercury" curve.
     This is a TOY: t is a knob and sets the width of the wavefunction.

  C. The hydrogen ladder a_n = a₁ n² (the spectrum of the 1/r Hamiltonian),
     fitted to the planets with integer n free.  A null test with random a₁
     says how often such a fit succeeds by chance.  This is numerology until
     the null says otherwise, and the file reports what the null says.

Frame: Zecliptic; distances in R☉ (Sol centre to photosphere).  AU appears
only to convert table values and literature zones.

Outputs: data/hamiltonian_vulcan.json, img/hamiltonian_vulcan.png
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

HERE = Path(__file__).resolve().parent
DOCS = HERE.parent.parent / "docs" / "MERCURY_VULCAN_LADDER_20261010"
DATA, IMG = DOCS / "data", DOCS / "img"

METR = json.load(open(DATA / "bodies_metrics.json"))
GRID = json.load(open(DATA / "spheral_grid.json"))

R_SOL_KM = 695700.0  # IAU 2015
AU_KM = 1.495978707e8  # table unit only
AU_RSOL = AU_KM / R_SOL_KM
GM_SUN = 1.32712440018e11  # km^3/s^2, IAU
YEAR_D = 365.25636

LITERALS = {
    "vulcanoid_zone_au": ([0.09, 0.21], "Evans & Tabachnik 1999, Nature 399, 41 — long-lived low-i orbits"),
    "le_verrier_vulcan_au": (0.1427, "Le Verrier 1859, from Lescarbault's transit; P = 19.7 d"),
    "sublimation_rock_au": (0.06, "rough silicate sublimation radius (~1,500 K) — nothing solid survives inside"),
    "GM_sun_km3s2": (GM_SUN, "IAU 2015 nominal"),
    "R_sol_km": (R_SOL_KM, "IAU 2015 nominal"),
}

merc = METR["mercury"]
a_M = merc["a_au"] * AU_RSOL
e_M = merc["e"]
q_M, Q_M = a_M * (1 - e_M), a_M * (1 + e_M)
P_M_yr = merc["period_d"] / YEAR_D


def period_yr(a_rsol: float) -> float:
    a_km = a_rsol * R_SOL_KM
    return 2 * math.pi * math.sqrt(a_km**3 / GM_SUN) / 86400.0 / YEAR_D


def pis(a_rsol: float) -> float:
    return math.pi / period_yr(a_rsol)


out: dict = {"literals": LITERALS, "mercury_rsol": {"q": q_M, "a": a_M, "Q": Q_M, "period_yr": P_M_yr}}

# ------------------------------------------------------------------ A. classical
res = {}
for p, q in ((2, 1), (3, 1), (4, 1), (5, 2), (3, 2), (5, 3), (7, 4)):
    a = a_M * (q / p) ** (2 / 3)  # interior: body makes p orbits per q of Mercury
    res[f"{p}:{q}"] = {"a_rsol": a, "a_au_table": a / AU_RSOL, "pis": pis(a), "shell": round(a)}
vz = [x * AU_RSOL for x in LITERALS["vulcanoid_zone_au"][0]]
lv = LITERALS["le_verrier_vulcan_au"][0] * AU_RSOL
subl = LITERALS["sublimation_rock_au"][0] * AU_RSOL
out["classical"] = {
    "interior_resonances_with_mercury": res,
    "vulcanoid_zone_rsol": vz,
    "vulcanoid_zone_shells": [math.ceil(vz[0]), math.floor(vz[1])],
    "vulcanoid_zone_pis": [pis(vz[1]), pis(vz[0])],
    "le_verrier_rsol": lv,
    "le_verrier_pis": pis(lv),
    "le_verrier_period_d": period_yr(lv) * YEAR_D,
    "sublimation_rsol": subl,
    "note": "5–7 Pis would be a ≈ %.0f–%.0f R☉ — outside Mercury (a=%.0f): no heliocentric Vulcan is that slow"
    % ((math.pi / 7) ** (2 / 3) * AU_RSOL, (math.pi / 5) ** (2 / 3) * AU_RSOL, a_M),
}
# where is 5–7 Pis heliocentrically?  P = π/Pis yr → a = P^(2/3) AU
out["classical"]["five_to_seven_pis_rsol"] = [(math.pi / 7) ** (2 / 3) * AU_RSOL, (math.pi / 5) ** (2 / 3) * AU_RSOL]

# ------------------------------------------------------------------ B. tight-binding on the spheral chain
N = 130
n = np.arange(1, N + 1, dtype=float)  # shell index = radius in R☉
r_km = n * R_SOL_KM

# Mercury dwell time per shell: fraction of its orbit with r in [n-0.5, n+0.5]
E = np.linspace(0, 2 * math.pi, 200001)
M_anom = E - e_M * np.sin(E)  # mean anomaly ∝ time
r_merc = a_M * (1 - e_M * np.cos(E))
dwell = np.zeros(N)
dt = np.gradient(M_anom)
for k in range(N):
    mask = (r_merc >= n[k] - 0.5) & (r_merc < n[k] + 0.5)
    dwell[k] = dt[mask].sum() / (2 * math.pi)
dwell /= dwell.max()


def u_eff(rc_rsol: float) -> np.ndarray:
    """Effective potential (per unit mass, km²/s²) for the L of a circular orbit at rc."""
    L2 = GM_SUN * rc_rsol * R_SOL_KM
    return -GM_SUN / r_km + L2 / (2 * r_km**2)


def ground_state(rc_rsol: float, t_frac: float, merc_strength: float):
    U = u_eff(rc_rsol)
    U = U - U.min()
    scale = abs(u_eff(rc_rsol).min())  # depth of the well, sets the energy unit
    t = t_frac * scale
    H = np.diag(U + merc_strength * scale * dwell) - t * (np.eye(N, k=1) + np.eye(N, k=-1))
    H[0, 0] += 50 * scale  # photosphere: hard wall at shell 1
    w, v = np.linalg.eigh(H)
    psi = v[:, 0] ** 2
    return w[0] / scale, psi


T_FRAC, MERC = 0.02, 1.0  # knobs — stated as such
rcs = np.arange(5, 120, 1.0)
leak, peak = [], []
for rc in rcs:
    _, psi = ground_state(rc, T_FRAC, MERC)
    leak.append(float(psi[(n >= math.floor(q_M)) & (n <= math.ceil(Q_M))].sum()))
    peak.append(float(n[np.argmax(psi)]))
leak, peak = np.array(leak), np.array(peak)
inside = rcs[(leak < 0.01) & (rcs < q_M)]
out["tight_binding"] = {
    "knobs": {"N_shells": N, "hopping_t_over_well_depth": T_FRAC, "mercury_scatterer_over_well_depth": MERC},
    "leak_lt_1pct_max_rc_rsol": float(inside.max()) if len(inside) else None,
    "leak_at": {str(int(rc)): float(l) for rc, l in zip(rcs, leak) if int(rc) in (20, 30, 37, 40, 45, 50, 55, 60, 63, 66)},
    "peak_follows_rc": bool(np.all(np.abs(peak[(rcs > 10) & (rcs < 60)] - rcs[(rcs > 10) & (rcs < 60)]) <= 1)),
    "reading": "the ground state sits at the circular radius (shell = rc) until the well's tail reaches Mercury's dwell shells; "
    "leakage rises from ~shell %d.  With t a knob, the EDGE is a knob; the SHAPE (flat then rising) is not." % (int(inside.max()) if len(inside) else -1),
}

# ------------------------------------------------------------------ C. hydrogen ladder
bodies = {k: METR[k]["a_au"] * AU_RSOL for k in ("mercury", "venus", "earth", "mars", "ceres", "vesta", "pallas", "hygiea", "jupiter", "saturn", "uranus", "neptune", "pluto")}
belt_edges = {"belt_4:1": GRID["edge"]["inner_rsol"], "belt_2:1": GRID["edge"]["outer_rsol"]}


def ladder_fit(a1: float, targets: dict, nmax=40):
    hits = {}
    for name, a in targets.items():
        nn = max(1, round(math.sqrt(a / a1)))
        pred = a1 * nn**2
        hits[name] = {"n": nn, "pred_rsol": pred, "miss_pct": 100 * abs(pred - a) / a}
    return hits


# Mercury as n = 3 (so that n = 1, 2 are inside it)
a1 = a_M / 9
fit = ladder_fit(a1, {**bodies, **belt_edges})
n_hit2 = sum(1 for v in fit.values() if v["miss_pct"] < 2.0)
# null: random a1 over a decade, same assignment freedom
rng = np.random.default_rng(7)
null = []
for _ in range(5000):
    a1r = float(10 ** rng.uniform(math.log10(3), math.log10(30)))
    f = ladder_fit(a1r, {**bodies, **belt_edges})
    null.append(sum(1 for v in f.values() if v["miss_pct"] < 2.0))
null = np.array(null)
out["hydrogen_ladder"] = {
    "a1_rsol": a1,
    "assignment": "Mercury = n 3; a_n = a1 n²",
    "fit": fit,
    "hits_under_2pct": n_hit2,
    "null_random_a1_hits_under_2pct": {"mean": float(null.mean()), "p_ge_observed": float((null >= n_hit2).mean())},
    "predicted_inner_states": {
        "n1": {"a_rsol": a1, "pis": pis(a1), "inside_sublimation": a1 < subl},
        "n2": {"a_rsol": 4 * a1, "pis": pis(4 * a1), "in_vulcanoid_zone": vz[0] <= 4 * a1 <= vz[1], "period_d": period_yr(4 * a1) * YEAR_D},
    },
    "verdict": "see p_ge_observed: if it is not small, the ladder is chance and n2 is not a prediction",
}

# ------------------------------------------------------------------ figure
BG, INK, AMBER, CYAN, GREY, RED = "#05060a", "#e8e4d8", "#f2b134", "#5fd3e6", "#7a7f8a", "#e05a4e"
fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(12, 13), dpi=100, gridspec_kw={"height_ratios": [1.2, 1, 1]})
fig.patch.set_facecolor(BG)
for ax in (ax1, ax2, ax3):
    ax.set_facecolor(BG)
    ax.tick_params(colors=INK)
    for s in ax.spines.values():
        s.set_color(GREY)

# A: effective potential wells for a few L, Mercury band, resonances, vulcanoid zone
rr = np.linspace(2, 130, 2000)
for rc, col in ((20, CYAN), (37, AMBER), (52, INK)):
    L2 = GM_SUN * rc * R_SOL_KM
    U = (-GM_SUN / (rr * R_SOL_KM) + L2 / (2 * (rr * R_SOL_KM) ** 2)) / 1e3
    ax1.plot(rr, U, color=col, lw=1.4, label=f"U_eff, circular at {rc} R☉")
ax1.axvspan(q_M, Q_M, color=RED, alpha=0.18, label=f"Mercury sweeps shells {q_M:.0f}–{Q_M:.0f}")
ax1.axvspan(vz[0], vz[1], color=CYAN, alpha=0.10, label="vulcanoid zone (Evans & Tabachnik 1999)")
ax1.axvspan(0, subl, color=GREY, alpha=0.25, label="rock sublimates")
for k, v in res.items():
    ax1.axvline(v["a_rsol"], color=GREY, lw=0.6, ls=":")
    ax1.text(v["a_rsol"], -4.9, k, color=GREY, fontsize=7, rotation=90, va="bottom", ha="center")
ax1.axvline(lv, color=AMBER, lw=0.8, ls="--")
ax1.text(lv + 0.5, -0.4, "Le Verrier 1859", color=AMBER, fontsize=7)
ax1.set_xlim(0, 130)
ax1.set_ylim(-5.0, 0)
ax1.set_ylabel("U_eff  (10³ km²/s²)", color=INK)
ax1.set_title("A · classical Hamiltonian H = p²/2 − GM/r : wells inside Mercury, resonances p:q, published stable zone", color=INK, fontsize=10)
ax1.legend(loc="upper right", fontsize=7, facecolor=BG, edgecolor=GREY, labelcolor=INK)

# B: leakage curve + a ground state
ax2.plot(rcs, leak, color=AMBER, lw=1.6)
ax2.axvspan(q_M, Q_M, color=RED, alpha=0.18)
ax2.axhline(0.01, color=GREY, lw=0.6, ls=":")
ax2.set_yscale("log")
ax2.set_ylim(1e-6, 1.2)
ax2.set_xlim(0, 130)
ax2.set_ylabel("|ψ₀|² inside Mercury's shells", color=INK)
ax2.set_title(f"B · tight-binding on the spheral chain (t = {T_FRAC} × well depth, Mercury scatterer × dwell time) — leakage vs circular radius", color=INK, fontsize=10)
_, psi = ground_state(37, T_FRAC, MERC)
ax2b = ax2.twinx()
ax2b.plot(n, psi, color=CYAN, lw=1.0)
ax2b.set_ylim(0, psi.max() * 4)
ax2b.set_yticks([])
ax2b.text(37, psi.max() * 1.1, "ψ₀² for circular at 37", color=CYAN, fontsize=7, ha="center")

# C: ladder
names = list(fit.keys())
xs = [fit[k]["n"] for k in names]
ys = [{**bodies, **belt_edges}[k] for k in names]
nn = np.arange(1, 32)
ax3.plot(nn, a1 * nn**2, color=GREY, lw=0.8, ls="--", label=f"a₁ n², a₁ = {a1:.2f} R☉ (Mercury = n 3)")
ax3.scatter(xs, ys, color=AMBER, s=22, zorder=5)
for i, (k, x, y) in enumerate(zip(names, xs, ys)):
    ax3.text(x + 0.3, y * (1.25 if i % 2 else 0.8), f"{k} ({fit[k]['miss_pct']:.1f}%)", color=INK, fontsize=7, va="center")
ax3.scatter([1, 2], [a1, 4 * a1], color=CYAN, s=30, marker="x", zorder=6)
ax3.text(2.4, 4 * a1, f"n 2 → {4 * a1:.0f} R☉ (in the vulcanoid zone)", color=CYAN, fontsize=7, va="center")
ax3.set_yscale("log")
ax3.set_xlim(0.5, 31.5)
ax3.set_xlabel("n", color=INK)
ax3.set_ylabel("a (R☉)", color=INK)
ax3.set_title(f"C · hydrogen ladder a_n = a₁n² — {n_hit2} hits <2 %; random a₁ gets {null.mean():.1f} on average, P(≥{n_hit2}) = {(null >= n_hit2).mean():.2f}", color=INK, fontsize=10)
ax3.legend(loc="upper left", fontsize=7, facecolor=BG, edgecolor=GREY, labelcolor=INK)
fig.subplots_adjust(left=0.08, right=0.97, top=0.96, bottom=0.05, hspace=0.35)
fig.savefig(IMG / "hamiltonian_vulcan.png", facecolor=BG)
plt.close(fig)

(DATA / "hamiltonian_vulcan.json").write_text(json.dumps(out, indent=2, default=float))
print(json.dumps({k: out[k] for k in ("mercury_rsol", "classical", "tight_binding")}, indent=1, default=float))
print(json.dumps({k: out["hydrogen_ladder"][k] for k in ("a1_rsol", "hits_under_2pct", "null_random_a1_hits_under_2pct", "predicted_inner_states")}, indent=1, default=float))
print({k: (v["n"], round(v["miss_pct"], 2)) for k, v in fit.items()})
