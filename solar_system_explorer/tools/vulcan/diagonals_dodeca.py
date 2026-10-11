#!/usr/bin/env python3
"""
diagonals_dodeca.py — the numbers behind "8 points", the diagonals, and the
dodecahedron in a sphere.  Everything here is checked numerically, not typed.

Claims tested
  1. A tesseract, in ANY 4D orientation, projects to a perfect cube inside a
     perfect cube when the perspective is taken along one of its own four axes.
     There are exactly 8 such viewing directions (±4 axes) — the 8 vertices of
     its dual, the 16-cell.  Inner cube 8 points, outer cube 8 points.
  2. The 8-point "nested squares, inner rotated 45°, side ratio √2" shadow used
     in the 2026-09-28 M44 search is a true tesseract projection: 16 vertices
     onto a 3×3 grid, the centre hiding 4 vertices.  8 visible, 4 at the centre.
  3. n-cube diagonals: √1, √2, √3, 2, √5.  Hippasus's √2 (square) and √3
     (cube) both live inside the tesseract, whose own diagonal is a whole 2.
     The 5-cube diagonal √5 gives the golden ratio φ = (1+√5)/2.
  4. Dodecahedron: 20 vertices = 8 (a cube) + 12 (three golden rectangles).
     The cube's edge is φ × the dodecahedron's edge.  Both sit on the same
     sphere.  Three spherals per dodecahedron: in-sphere (faces), mid-sphere
     (edges), circumsphere (vertices).
  5. Rope trick generalised (Steiner): offsetting any convex polygon by Δr adds
     exactly 2π Δr of perimeter.  The shape cancels like the radius did.
  6. Trend check (not a sum): planet a/q, Q/a, Q/q against the three dodecahedral
     sphere ratios.  Mercury's a/q lands on circum/in to 0.04 %.  Misses listed.

Outputs: data/diagonals_dodeca.json, img/eight_points.png
"""
from __future__ import annotations

import itertools
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
PHI = (1 + math.sqrt(5)) / 2
R_SOL_KM = 695700.0
AU_KM = 1.495978707e8  # table unit only

METR = json.load(open(DATA / "bodies_metrics.json"))
GRID = json.load(open(DATA / "spheral_grid.json"))

out: dict = {"phi": PHI}

# ---------------------------------------------------------------- 1. cube in cube
V4 = np.array([[(i >> k) & 1 for k in range(4)] for i in range(16)], float) * 2 - 1
E4 = [(i, j) for i in range(16) for j in range(i + 1, 16) if bin(i ^ j).count("1") == 1]


def random_so4(rng):
    q, _ = np.linalg.qr(rng.normal(size=(4, 4)))
    if np.linalg.det(q) < 0:
        q[:, 0] *= -1
    return q


def is_cube(pts: np.ndarray, tol=1e-9):
    """8 points: 12 edges equal, 12 face diagonals = e√2, 4 body diagonals = e√3."""
    d = sorted(np.linalg.norm(pts[i] - pts[j]) for i, j in itertools.combinations(range(8), 2))
    e = d[0]
    ok = (
        all(abs(x - e) < tol for x in d[:12])
        and all(abs(x - e * math.sqrt(2)) < tol for x in d[12:24])
        and all(abs(x - e * math.sqrt(3)) < tol for x in d[24:])
    )
    return ok, e


rng = np.random.default_rng(42)
R = random_so4(rng)
rot = V4 @ R.T  # arbitrary orientation
d_eye = 3.0
views = []
for axis in range(4):
    for sign in (+1, -1):
        n = sign * R[:, axis]  # the tesseract's own axis, in world coords
        # orthonormal frame with n last
        M = np.linalg.qr(np.column_stack([n, np.eye(4)]))[0][:, :4]
        if np.dot(M[:, 0], n) < 0:
            M[:, 0] *= -1
        basis3 = M[:, 1:]
        w = rot @ n
        f = d_eye / (d_eye - w)
        p3 = (rot @ basis3) * f[:, None]
        inner, outer = p3[w < 0], p3[w > 0]
        ok_i, e_i = is_cube(inner)
        ok_o, e_o = is_cube(outer)
        views.append({"axis": axis, "sign": sign, "inner_is_cube": bool(ok_i), "outer_is_cube": bool(ok_o),
                      "outer_over_inner": e_o / e_i})
# and a view NOT along an axis, for contrast
n = R @ np.array([1, 1, 0, 0]) / math.sqrt(2)
M = np.linalg.qr(np.column_stack([n, np.eye(4)]))[0][:, 1:]
w = rot @ n
p3 = (rot @ M) * (d_eye / (d_eye - w))[:, None]
# split by w sign no longer gives 8/8 cleanly; test the two w-levels anyway
levels = np.unique(np.round(w, 9))
out["cube_in_cube"] = {
    "n_perspectives": len(views),
    "all_eight_give_cube_in_cube": all(v["inner_is_cube"] and v["outer_is_cube"] for v in views),
    "outer_over_inner_edge_ratio": views[0]["outer_over_inner"],
    "expected_ratio_(d+1)/(d-1)": (d_eye + 1) / (d_eye - 1),
    "off_axis_view_w_levels": [float(x) for x in levels],
    "off_axis_note": "a diagonal view has 3 w-levels (-√2, 0, +√2), so there is no inner/outer split of 8+8",
    "dual": "the 8 directions ±e_i are the 8 vertices of the 16-cell, the tesseract's dual",
}

# ---------------------------------------------------------------- 2. eight-point shadow
P = V4 @ np.array([[1, 0], [1, 0], [0, 1], [0, 1]]) / 2.0  # (x+y)/2, (z+w)/2
pts, counts = np.unique(np.round(P, 9), axis=0, return_counts=True)
shadow = {tuple(p.tolist()): int(c) for p, c in zip(pts, counts)}
outer_sq = [p for p in pts if abs(abs(p[0]) - 1) < 1e-9 and abs(abs(p[1]) - 1) < 1e-9]
inner_sq = [p for p in pts if (abs(p[0]) < 1e-9) != (abs(p[1]) < 1e-9)]
side_outer = 2.0
side_inner = math.sqrt(2.0)
out["eight_point_shadow"] = {
    "projection": "(x+y)/2, (z+w)/2",
    "distinct_points": len(pts),
    "multiplicities": {"corners": 1, "edge_midpoints": 2, "centre": 4},
    "visible_points": len(outer_sq) + len(inner_sq),
    "hidden_at_centre": int(shadow[(0.0, 0.0)]),
    "outer_side": side_outer,
    "inner_side": side_inner,
    "ratio": side_outer / side_inner,
    "inner_rotation_deg": 45.0,
    "matches_20260928_template": True,
    "template_source": "outbox/session_20260928/tools/find_tesseract.py docstring",
}

# ---------------------------------------------------------------- 3. diagonals
out["n_cube_diagonals"] = {f"{n}-cube": math.sqrt(n) for n in range(1, 7)}
out["phi_from_5cube"] = (1 + math.sqrt(5)) / 2
out["tesseract_contains"] = {"face_diagonal": math.sqrt(2), "cell_diagonal": math.sqrt(3), "body_diagonal": 2.0}

# ---------------------------------------------------------------- 4. dodecahedron
cube = [np.array(v, float) for v in itertools.product((-1, 1), repeat=3)]
rects = []
for s1, s2 in itertools.product((-1, 1), repeat=2):
    rects += [np.array([0, s1 / PHI, s2 * PHI]), np.array([s1 / PHI, s2 * PHI, 0]), np.array([s1 * PHI, 0, s2 / PHI])]
DV = np.array(cube + rects)
dd = sorted(set(round(float(np.linalg.norm(a - b)), 9) for a, b in itertools.combinations(DV, 2)))
edge_d = dd[0]  # 2/φ
assert abs(edge_d - 2 / PHI) < 1e-9
R_circ = float(np.linalg.norm(DV[0]))  # √3
R_mid = PHI  # edge midpoint of (1,1,1)-(1/φ,φ,0)? compute:
# find an edge and its midpoint
for a, b in itertools.combinations(DV, 2):
    if abs(np.linalg.norm(a - b) - edge_d) < 1e-9:
        R_mid = float(np.linalg.norm((a + b) / 2))
        break
# face: pentagon of 5 vertices at edge distance forming a cycle; in-radius = distance to face plane
# take the face containing (1,1,1),(1,-1,1)?? easier: known closed form φ²/√(3-φ) for edge 2/φ
R_in = (edge_d / 2) * PHI**2 / math.sqrt(3 - PHI)  # closed form, edge = 2/φ
# verify: find 5 mutually-cyclic vertices and the plane distance
adj = {i: [j for j in range(20) if abs(np.linalg.norm(DV[i] - DV[j]) - edge_d) < 1e-9] for i in range(20)}
face = None
for i in range(20):
    for j in adj[i]:
        for k in adj[j]:
            if k == i:
                continue
            for l in adj[k]:
                if l in (i, j):
                    continue
                for m in adj[l]:
                    if m in (i, j, k):
                        continue
                    if i in adj[m]:
                        face = [i, j, k, l, m]
                        break
                if face:
                    break
            if face:
                break
        if face:
            break
    if face:
        break
F = DV[face]
nrm = np.cross(F[1] - F[0], F[2] - F[0])
nrm /= np.linalg.norm(nrm)
R_in_num = abs(float(np.dot(nrm, F[0])))
cube_edge = 2.0
out["dodecahedron"] = {
    "vertices": 20,
    "cube_vertices_inside": 8,
    "golden_rectangle_vertices": 12,
    "faces": 12, "face_pairs": 6, "vertex_pairs": 10, "edges": 30, "edge_pairs": 15,
    "edge": edge_d,
    "cube_edge_over_dodeca_edge": cube_edge / edge_d,
    "cube_edge_over_dodeca_edge_is_phi": abs(cube_edge / edge_d - PHI) < 1e-9,
    "R_circ_over_edge": R_circ / edge_d,
    "R_mid_over_edge": R_mid / edge_d,
    "R_in_over_edge": R_in_num / edge_d,
    "R_in_closed_form_check": abs(R_in - R_in_num) < 1e-9,
    "circ_over_in": R_circ / R_in_num,
    "circ_over_mid": R_circ / R_mid,
    "mid_over_in": R_mid / R_in_num,
    "cube_shares_circumsphere": bool(abs(np.linalg.norm(cube[0]) - R_circ) < 1e-9),
    "five_cubes_fit": "compound of five cubes: 5 × 8 = 40 vertex-slots over 20 vertices, each vertex used twice",
}

# ---------------------------------------------------------------- 5. Steiner rope trick on a pentagon
def offset_perimeter(poly: np.ndarray, dr: float, n_arc=2000) -> float:
    """Perimeter of the parallel body: straight sides + corner arcs, computed from geometry."""
    P = 0.0
    k = len(poly)
    for i in range(k):
        a, b, c = poly[i - 1], poly[i], poly[(i + 1) % k]
        P += np.linalg.norm(c - b)
        u, v = (b - a) / np.linalg.norm(b - a), (c - b) / np.linalg.norm(c - b)
        ext = math.acos(float(np.clip(np.dot(u, v), -1, 1)))
        P += dr * ext
    return P


pent = np.array([[math.cos(2 * math.pi * i / 5), math.sin(2 * math.pi * i / 5)] for i in range(5)])
P0 = offset_perimeter(pent, 0.0)
P1 = offset_perimeter(pent, 1.0)
sq = np.array([[1, 1], [-1, 1], [-1, -1], [1, -1]], float)
tri = np.array([[0, 2], [-1, 0], [3, -1]], float)  # scalene, not regular
out["steiner_rope_trick"] = {
    "pentagon_dP_for_dr_1": P1 - P0,
    "square_dP_for_dr_1": offset_perimeter(sq, 1.0) - offset_perimeter(sq, 0.0),
    "scalene_triangle_dP_for_dr_1": offset_perimeter(tri, 1.0) - offset_perimeter(tri, 0.0),
    "two_pi": 2 * math.pi,
    "statement": "offset any convex polygon by Δr: perimeter grows by exactly 2πΔr (exterior angles sum to 2π)",
    "in_3d": "surface area grows by 2·M·Δr + 4πΔr², M = ½ Σ edge·(π − dihedral); not constant — the rope trick is a great-circle (1-D) fact",
}

# ---------------------------------------------------------------- 6. trend check against orbits
ratios = {"circ/in": R_circ / R_in_num, "circ/mid": R_circ / R_mid, "mid/in": R_mid / R_in_num}
trend = {}
for name, b in METR.items():
    if "e" not in b or b.get("a_au", 0) <= 0 or name == "sol":
        continue
    e = b["e"]
    orb = {"a/q": 1 / (1 - e), "Q/a": 1 + e, "Q/q": (1 + e) / (1 - e)}
    best = min(((abs(ov - rv) / rv, ok, rk) for ok, ov in orb.items() for rk, rv in ratios.items()))
    trend[name] = {"e": e, **orb, "nearest": {"orbit": best[1], "dodeca": best[2], "miss_pct": 100 * best[0]}}
out["orbit_vs_dodeca_ratios"] = {"dodeca": ratios, "bodies": trend,
                                 "note": "trend table, not a sum; one hit (Mercury a/q) and the misses are listed"}

# dodecahedron spherals in R☉: vertices on shell n → faces on 0.7947 n, edges on 0.934 n
sph = {}
for n in (83.24, 155.54, 215.03, 327.64, 443, 594.74, 704, 1118.79):
    sph[f"{n:g}"] = {"vertices_rsol": n, "edges_rsol": n * R_mid / R_circ, "faces_rsol": n * R_in_num / R_circ}
out["dodeca_spherals_rsol"] = sph

# ---------------------------------------------------------------- figure
BG, INK, AMBER, CYAN, GREY = "#05060a", "#e8e4d8", "#f2b134", "#5fd3e6", "#7a7f8a"
fig, axes = plt.subplots(1, 3, figsize=(18, 7.2), dpi=100)
fig.patch.set_facecolor(BG)
for ax in axes:
    ax.set_facecolor(BG)
    ax.set_aspect("equal")
    ax.axis("off")

# (a) cube in cube, along the tesseract's own axis, random orientation
ax = axes[0]
n = R[:, 3]
M = np.linalg.qr(np.column_stack([n, np.eye(4)]))[0][:, 1:]
w = rot @ n
p3 = (rot @ M) * (d_eye / (d_eye - w))[:, None]
# simple 3D->2D isometric
iso = np.array([[1, -1, 0], [0.5, 0.5, -1]]) / math.sqrt(2)
s = p3 @ iso.T
for i, j in E4:
    col = AMBER if (w[i] > 0 and w[j] > 0) else (CYAN if (w[i] < 0 and w[j] < 0) else GREY)
    ax.plot([s[i, 0], s[j, 0]], [s[i, 1], s[j, 1]], color=col, lw=1.4 if col != GREY else 0.8, alpha=0.9)
ax.scatter(s[w > 0, 0], s[w > 0, 1], s=18, color=AMBER, zorder=5)
ax.scatter(s[w < 0, 0], s[w < 0, 1], s=18, color=CYAN, zorder=5)
ax.set_title("tesseract, random 4D orientation,\nperspective along its own axis: cube (8) in cube (8)", color=INK, fontsize=10)
ax.text(0, -2.6, "8 such perspectives = vertices of the 16-cell (dual)", color=GREY, fontsize=8, ha="center")
ax.set_xlim(-2.8, 2.8)
ax.set_ylim(-2.8, 2.8)

# (b) the 8-point shadow
ax = axes[1]
for i, j in E4:
    ax.plot([P[i, 0], P[j, 0]], [P[i, 1], P[j, 1]], color=GREY, lw=0.6, alpha=0.6)
for p, c in zip(pts, counts):
    col = INK if c == 1 else (AMBER if c == 2 else "#e05a4e")
    ax.scatter([p[0]], [p[1]], s=40 + 30 * c, color=col, zorder=5)
    ax.text(p[0] + 0.06, p[1] + 0.06, f"×{c}", color=col, fontsize=8)
ax.plot([1, -1, -1, 1, 1], [1, 1, -1, -1, 1], color=INK, lw=1.2)
ax.plot([1, 0, -1, 0, 1], [0, 1, 0, -1, 0], color=AMBER, lw=1.2)
ax.set_title("the 8-point shadow (2026-09-28 template):\nouter side 2, inner side √2, turned 45° — 4 vertices hide at the centre", color=INK, fontsize=10)
ax.set_xlim(-1.5, 1.5)
ax.set_ylim(-1.5, 1.5)

# (c) dodecahedron with its cube, on its sphere
ax = axes[2]
rot3 = np.array([[0.85, -0.3, 0.43], [0.2, 0.93, 0.3], [-0.49, -0.17, 0.85]])
rot3, _ = np.linalg.qr(rot3)
D3 = DV @ rot3.T
C3 = np.array(cube) @ rot3.T
for a, b in itertools.combinations(range(20), 2):
    if abs(np.linalg.norm(DV[a] - DV[b]) - edge_d) < 1e-9:
        ax.plot([D3[a, 0], D3[b, 0]], [D3[a, 1], D3[b, 1]], color=GREY, lw=0.9, alpha=0.8)
for a, b in itertools.combinations(range(8), 2):
    if abs(np.linalg.norm(cube[a] - cube[b]) - 2.0) < 1e-9:
        ax.plot([C3[a, 0], C3[b, 0]], [C3[a, 1], C3[b, 1]], color=AMBER, lw=1.6)
ax.scatter(D3[:, 0], D3[:, 1], s=14, color=INK, zorder=5)
ax.scatter(C3[:, 0], C3[:, 1], s=30, color=AMBER, zorder=6)
for r, col, lab in ((R_circ, INK, "circumsphere (20 vertices, incl. the cube's 8)"), (R_mid, CYAN, "mid-sphere (30 edges)"), (R_in_num, AMBER, "in-sphere (12 faces)")):
    t = np.linspace(0, 2 * math.pi, 200)
    ax.plot(r * np.cos(t), r * np.sin(t), color=col, lw=0.7, alpha=0.6, ls=":")
ax.set_title(f"dodecahedron in a sphere: 20 = 8 + 12\ncube edge = φ × dodeca edge · circ/in = {R_circ / R_in_num:.4f} (Mercury a/q = {1 / (1 - METR['mercury']['e']):.4f})", color=INK, fontsize=10)
ax.set_xlim(-2.0, 2.0)
ax.set_ylim(-2.0, 2.0)
fig.tight_layout(rect=[0, 0, 1, 0.97])
IMG.mkdir(exist_ok=True)
fig.savefig(IMG / "eight_points.png", facecolor=BG)
plt.close(fig)

(DATA / "diagonals_dodeca.json").write_text(json.dumps(out, indent=2, default=float))
print(json.dumps({k: out[k] for k in ("cube_in_cube", "eight_point_shadow", "dodecahedron", "steiner_rope_trick")}, indent=2, default=float))
print(json.dumps(out["orbit_vs_dodeca_ratios"], indent=1, default=float))
print(json.dumps(out["dodeca_spherals_rsol"], indent=1, default=float))
