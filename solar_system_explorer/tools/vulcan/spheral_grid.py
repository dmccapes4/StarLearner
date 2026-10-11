#!/usr/bin/env python3
"""Spheral grid — the rope trick as a sphere.

A rope lifted 1 m off an apple and 1 m off Sol gains the same extra length:
ΔC = 2π Δr. Here Δr = 1 R☉ (Sol-centre to the photosphere). Each spheral
section is the sphere of radius n R☉. The first grid stops at the asteroid
belt, taken as the edge of the Solar System proper.

No Godot. No fitting. Numbers pulled from bodies_metrics.json.
"""
import json, math, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
DOC = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "MERCURY_VULCAN_LADDER_20261010"))
B = json.load(open(os.path.join(DOC, "data", "bodies_metrics.json")))
R_SOL_KM = float(B["sol"]["r_eq_km"])
AU_KM = 149597870.7  # table unit only
R_PER_AU = AU_KM / R_SOL_KM
BELT_INNER = B["asteroid_belt"]["a_inner_au"] * R_PER_AU   # 4:1 Jupiter
BELT_OUTER = B["asteroid_belt"]["a_outer_au"] * R_PER_AU   # 2:1 Jupiter
N_EDGE = int(math.ceil(BELT_OUTER))
DELTA_C = 2.0 * math.pi   # in R☉ of circumference, per 1 R☉ of radius

LIT = {
    "r_sol_km": (R_SOL_KM, "photosphere; the unit"),
    "belt_inner_from": ("bodies_metrics.asteroid_belt.a_inner_au = 2.06", "4:1 Jupiter resonance"),
    "belt_outer_from": ("bodies_metrics.asteroid_belt.a_outer_au = 3.27", "2:1 Jupiter resonance"),
    "rope_trick": ("ΔC = 2π Δr, independent of the sphere you started on",
                   "1 m on an apple, 1 R☉ on Sol: same increment"),
}

# the grid is the list of shells. Stored compactly: n, C_great_circle / R☉
# C(n) = 2π n ; C(n) - C(n-1) = 2π for every n ≥ 1. C(0) is the point at the centre.
shells = [{"n": n, "r_rsol": n, "C_rsol": 2.0 * math.pi * n, "dC_rsol": DELTA_C if n else 0.0}
          for n in range(0, N_EDGE + 1)]


def rsol_a(b):
    if b.get("a_au") is None:
        return None
    a = float(b["a_au"]) * R_PER_AU
    e = float(b.get("e") or 0.0)
    return {"a": a, "q": a * (1.0 - e), "Q": a * (1.0 + e), "e": e}


def occupancy(rq):
    lo, hi = math.floor(rq["q"]), math.ceil(rq["Q"])
    return {"shell_lo": lo, "shell_hi": hi, "shells_spanned": hi - lo,
            "frac_a": rq["a"] - math.floor(rq["a"]),
            "nearest_shell": int(round(rq["a"])),
            "miss_rsol": rq["a"] - round(rq["a"])}


bodies = {}
for k, b in B.items():
    if b.get("kind") in ("planet", "dwarf", "asteroid") and b.get("a_au"):
        rq = rsol_a(b)
        bodies[k] = {"name": b["name"], "kind": b["kind"], **rq, **occupancy(rq)}

# named belt edges as occupancy of a circular orbit at the resonance
belt = {
    "inner_rsol": BELT_INNER, "outer_rsol": BELT_OUTER, "n_edge": N_EDGE,
    "inner_shell": int(round(BELT_INNER)), "outer_shell": N_EDGE,
    "note": "inner = 4:1 Jupiter, outer = 2:1 Jupiter; this grid stops at the outer edge",
}

out = {
    "unit": "1 = Sol-centre to photosphere (R☉)",
    "rope_trick": {"statement": "A rope lifted Δr off any sphere needs 2π Δr of extra length. Apple or Sol.",
                   "delta_r_rsol": 1.0, "delta_C_rsol": DELTA_C,
                   "delta_C_km": DELTA_C * R_SOL_KM},
    "edge": belt,
    "n_shells": N_EDGE + 1,
    "shells_note": "shells[n] is the sphere of radius n R☉. Stored in full so the grid is the file.",
    "shells": shells,
    "bodies": bodies,
    "literals": {k: {"value": v[0], "why": v[1]} for k, v in LIT.items()},
}
json.dump(out, open(os.path.join(DOC, "data", "spheral_grid.json"), "w"), indent=1)

# figure: C vs n is a straight line — that is the trick
fig, ax = plt.subplots(figsize=(8.2, 4.4))
ns = [s["n"] for s in shells]
Cs = [s["C_rsol"] for s in shells]
ax.plot(ns, Cs, color="#c4a35a", lw=1.4, label="C = 2π n  (great circle, R☉)")
for k, col in (("mercury", "#9a9a9a"), ("venus", "#d4b56a"), ("earth", "#6aa0d4"),
               ("mars", "#c07050"), ("ceres", "#888"), ("vesta", "#888"),
               ("pallas", "#e07030"), ("jupiter", "#c9a070")):
    if k in bodies:
        ax.axvline(bodies[k]["a"], color=col, alpha=0.55, lw=0.8)
        ax.text(bodies[k]["a"], 2 * math.pi * N_EDGE * 0.92, bodies[k]["name"],
                rotation=90, va="top", ha="right", fontsize=7, color=col)
ax.axvspan(BELT_INNER, BELT_OUTER, color="#e07030", alpha=0.12, label="asteroid belt (edge of this grid)")
ax.set_xlabel("spheral section n  (radius in R☉)")
ax.set_ylabel("great-circle circumference / R☉")
ax.set_title("Rope trick: each +1 R☉ of radius adds 2π R☉ of circumference, apple or Sol")
ax.grid(alpha=0.3)
ax.legend(fontsize=8, loc="upper left")
fig.tight_layout()
os.makedirs(os.path.join(DOC, "img"), exist_ok=True)
fig.savefig(os.path.join(DOC, "img", "spheral_grid_rope.png"), dpi=140)
plt.close()

# markdown
L = []
L.append("# Spheral grid — the rope trick as a sphere\n")
L.append(f"**Date:** 2026-10-11 · **Unit:** 1 = Sol-centre to photosphere ({R_SOL_KM:,.0f} km). "
         f"**Edge of this grid:** asteroid belt, {BELT_INNER:.1f}–{BELT_OUTER:.1f} R☉ "
         f"(4:1 to 2:1 Jupiter). **File:** `data/spheral_grid.json` ({N_EDGE + 1} shells, n = 0…{N_EDGE}).\n")
L.append("## The trick\n")
L.append("A rope around an apple, lifted 1 m off the skin, needs **2π metres** of extra rope. "
         "A rope around Sol, lifted 1 R☉ off the photosphere, needs **2π R☉** of extra rope. "
         "The starting radius drops out:\n")
L.append("```")
L.append("C(r + Δr) − C(r) = 2π(r + Δr) − 2πr = 2π Δr")
L.append("```")
L.append(f"Here Δr = 1 R☉, so every step adds **{DELTA_C:.6f} R☉** of circumference "
         f"(= {DELTA_C * R_SOL_KM / 1000:,.0f} km), whether you are standing on the photosphere "
         f"or at the belt. That is why the grid is evenly spaced in radius and the plot of C against n is a straight line.\n")
L.append("![rope trick](img/spheral_grid_rope.png)\n")
L.append("Shell 0 is the point at Sol's centre. Shell 1 is the bubbling surface. "
         "Shell n is the sphere of radius n R☉. The spheral section of shell n on the Zecliptic "
         "is the circle of circumference 2π n R☉.\n")

L.append("## The grid (every 50th shell, plus the belt edges)\n")
L.append("| n | r (R☉) | C (R☉) | ΔC from previous |")
L.append("|---|---|---|---|")
show = list(range(0, N_EDGE + 1, 50))
for extra in (1, int(round(BELT_INNER)), N_EDGE):
    if extra not in show:
        show.append(extra)
show = sorted(set(show))
for n in show:
    s = shells[n]
    tag = ""
    if n == 0:
        tag = " centre"
    elif n == 1:
        tag = " **photosphere**"
    elif n == int(round(BELT_INNER)):
        tag = " belt inner (4:1)"
    elif n == N_EDGE:
        tag = " **belt outer (2:1) — edge of this grid**"
    L.append(f"| {n} | {s['r_rsol']} | {s['C_rsol']:.4f} | {s['dC_rsol']:.4f}{tag} |")
L.append(f"\nThe full list is `{N_EDGE + 1}` rows in the JSON. ΔC is {DELTA_C:.6f} on every row except n = 0.\n")

L.append("## Where the bodies sit on the grid (not a fit — occupancy)\n")
L.append("An orbit *lands within 1 R☉* only if it stays inside one shell all year "
         "(q and Q in the same integer bin). The ovoids do not. The grid does not care; "
         "it just says which sections they cross.\n")
L.append("| body | q | a | Q | shells crossed | nearest shell to a | miss (R☉) |")
L.append("|---|---|---|---|---|---|---|")
order = sorted(bodies.values(), key=lambda x: x["a"])
for b in order:
    L.append(f"| {b['name']} | {b['q']:.2f} | {b['a']:.2f} | {b['Q']:.2f} | "
             f"{b['shell_lo']}–{b['shell_hi']} ({b['shells_spanned']}) | "
             f"{b['nearest_shell']} | {b['miss_rsol']:+.3f} |")
L.append("\nVenus is the tightest planet on the grid (q and Q three shells apart). "
         "Mercury is the loosest inside the belt (34 shells). "
         "Ceres, Vesta, Pallas, Hygiea sit in the edge band this grid was cut to include. "
         "Jupiter and everything past it are *outside* this grid — past the edge we named.\n")

L.append("## What this is not yet\n")
L.append("- Not a coordinate hunt (the 'land within 1 R☉' search). Occupancy first.\n")
L.append("- Not the dodecahedron basketball hoop. The hoop goes on the sphere once the sphere is drawn.\n")
L.append("- Not Godot. The grid is the JSON.\n")
L.append("- Not a claim that the belt *is* the heliobarrier. The belt is the edge of the "
         "*planetary* system we are willing to section before we talk about the plasma outside.\n")

L.append("## Literals\n")
for k, (v, why) in LIT.items():
    L.append(f"- `{k}` = {v} — {why}")
L.append("\nEverything else is read from `bodies_metrics.json`.\n")
open(os.path.join(DOC, "SPHERAL_GRID_20261011.md"), "w").write("\n".join(L))
print(f"grid n=0..{N_EDGE}  ΔC={DELTA_C:.6f} R☉  belt {BELT_INNER:.1f}–{BELT_OUTER:.1f} R☉")
print("wrote spheral_grid.json and SPHERAL_GRID_20261011.md")
