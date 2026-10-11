#!/usr/bin/env python
"""Generate the figures for BLOOD_TYPE_SUGARS report.

Run with a venv that has rdkit, matplotlib, numpy, pillow:
    python make_figures.py

2-D structures: RDKit depictions from PubChem isomeric SMILES (pubchem.json).
3-D structures: RDKit ETKDG conformer, MMFF-minimised, drawn as ball-and-stick
                with matplotlib (no external viewer needed).
Protein:        C-alpha trace of PDB 1LZ0 (human glycosyltransferase A,
                Patenaude et al. 2002), coloured N->C.
Everything else is plain matplotlib.
"""
import json, os, sys, math
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, FancyBboxPatch, FancyArrowPatch
from rdkit import Chem
from rdkit.Chem import AllChem, Draw
from rdkit.Chem.Draw import rdMolDraw2D

HERE = os.path.dirname(os.path.abspath(__file__))
FIG = os.path.join(HERE, "figures")
os.makedirs(FIG, exist_ok=True)
PUB = json.load(open(os.path.join(HERE, "pubchem.json")))

def smi(key):
    d = PUB[key]
    return d.get("IsomericSMILES") or d.get("ConnectivitySMILES") or d.get("SMILES")

# ---------------------------------------------------------------- 2-D grids
def grid(keys, labels, fname, per_row=4, size=(330, 280)):
    mols = [Chem.MolFromSmiles(smi(k)) for k in keys]
    for m in mols:
        AllChem.Compute2DCoords(m)
    img = Draw.MolsToGridImage(mols, molsPerRow=per_row, subImgSize=size,
                               legends=labels, useSVG=False)
    img.save(os.path.join(FIG, fname))
    print("wrote", fname)

grid(["glucose", "galactose", "fructose", "GlcNAc", "GalNAc", "fucose", "NeuAc", "glutamate"],
     ["β-D-glucose (Glc)", "β-D-galactose (Gal)", "β-D-fructose (Fru, furanose)",
      "N-acetyl-glucosamine (GlcNAc)", "N-acetyl-galactosamine (GalNAc)",
      "α-L-fucose (Fuc)", "N-acetylneuraminic acid (NeuAc, sialic)", "L-glutamate (the user's glucenate)"],
     "fig_monosaccharides_2d.png")

grid(["H_tri", "A_tri", "B_tri"],
     ["H antigen core: Fucα1-2Galβ1-4GlcNAc", "A antigen: GalNAcα1-3(Fucα1-2)Gal", "B antigen: Galα1-3(Fucα1-2)Gal"],
     "fig_abo_trisaccharides_2d.png", per_row=3, size=(420, 330))

grid(["sucrose", "lactose", "2FL", "glutamine", "aKG"],
     ["sucrose: Glc α1-2 Fru (table sugar, cane, beet)", "lactose: Gal β1-4 Glc (milk)",
      "2'-fucosyllactose (human milk; made by FUT2, the secretor enzyme)",
      "L-glutamine", "α-ketoglutarate (2-oxoglutarate)"],
     "fig_disaccharides_2d.png", per_row=3, size=(420, 330))

# ---------------------------------------------------------------- 3-D ball & stick
CPK = {"C": "#303030", "O": "#e03030", "N": "#3050e0", "H": "#e8e8e8", "S": "#e0c030"}
RAD = {"C": 0.36, "O": 0.34, "N": 0.34, "H": 0.20}

def ball_and_stick(key, title, fname, seed=7, show_h=True, elev=20, azim=35):
    m = Chem.AddHs(Chem.MolFromSmiles(smi(key)))
    ps = AllChem.ETKDGv3(); ps.randomSeed = seed
    if AllChem.EmbedMolecule(m, ps) != 0:
        AllChem.EmbedMolecule(m, randomSeed=seed, useRandomCoords=True)
    try:
        AllChem.MMFFOptimizeMolecule(m, maxIters=2000)
    except Exception:
        pass
    conf = m.GetConformer()
    xyz = np.array([list(conf.GetAtomPosition(i)) for i in range(m.GetNumAtoms())])
    xyz -= xyz.mean(0)
    fig = plt.figure(figsize=(6.2, 5.2))
    ax = fig.add_subplot(111, projection="3d")
    for b in m.GetBonds():
        i, j = b.GetBeginAtomIdx(), b.GetEndAtomIdx()
        ai, aj = m.GetAtomWithIdx(i).GetSymbol(), m.GetAtomWithIdx(j).GetSymbol()
        if not show_h and ("H" in (ai, aj)):
            continue
        p, q = xyz[i], xyz[j]; mid = (p + q) / 2
        ax.plot(*zip(p, mid), color=CPK.get(ai, "#808080"), lw=3.2, solid_capstyle="round")
        ax.plot(*zip(mid, q), color=CPK.get(aj, "#808080"), lw=3.2, solid_capstyle="round")
    # draw atoms back-to-front for a passable depth cue
    view = np.array([math.cos(math.radians(azim)) * math.cos(math.radians(elev)),
                     math.sin(math.radians(azim)) * math.cos(math.radians(elev)),
                     math.sin(math.radians(elev))])
    order = np.argsort(xyz @ view)
    for i in order:
        s = m.GetAtomWithIdx(int(i)).GetSymbol()
        if not show_h and s == "H":
            continue
        ax.scatter(*xyz[i], s=(RAD.get(s, 0.3) * 900), c=CPK.get(s, "#808080"),
                   edgecolors="black", linewidths=0.5, depthshade=False)
    keep = np.array([show_h or m.GetAtomWithIdx(i).GetSymbol() != "H" for i in range(m.GetNumAtoms())])
    r = np.abs(xyz[keep]).max() * 0.80
    ax.set_xlim(-r, r); ax.set_ylim(-r, r); ax.set_zlim(-r, r)
    ax.set_box_aspect((1, 1, 1)); ax.view_init(elev=elev, azim=azim); ax.set_axis_off()
    ax.set_title(title, fontsize=11)
    fig.text(0.5, 0.02, "C black · O red · N blue · H white — ETKDG conformer, MMFF-minimised (one low-energy shape, not the only one)",
             ha="center", fontsize=7.5, color="#444")
    fig.tight_layout()
    fig.savefig(os.path.join(FIG, fname), dpi=170)
    plt.close(fig)
    print("wrote", fname)

ball_and_stick("glucose", "β-D-glucopyranose — the chair", "fig_3d_glucose.png")
ball_and_stick("fructose", "β-D-fructofuranose — the five-ring", "fig_3d_fructose.png")
ball_and_stick("sucrose", "sucrose — glucose and fructose bonded α1→2", "fig_3d_sucrose.png", azim=60)
ball_and_stick("glutamate", "L-glutamate (glucenate) — not a sugar, made from one", "fig_3d_glutamate.png")
ball_and_stick("A_tri", "Blood group A trisaccharide: GalNAcα1-3(Fucα1-2)Gal", "fig_3d_A_trisaccharide.png", show_h=False, azim=50)
ball_and_stick("B_tri", "Blood group B trisaccharide: Galα1-3(Fucα1-2)Gal", "fig_3d_B_trisaccharide.png", show_h=False, azim=50)
ball_and_stick("H_tri", "H antigen (type 2): Fucα1-2Galβ1-4GlcNAc", "fig_3d_H_trisaccharide.png", show_h=False, azim=50)

# ---------------------------------------------------------------- protein CA trace
def ca_trace(pdb, title, fname):
    ca = []
    for line in open(pdb):
        if line.startswith("ATOM") and line[12:16].strip() == "CA" and line[21] == "A":
            alt = line[16]
            if alt not in (" ", "A"):
                continue
            ca.append([float(line[30:38]), float(line[38:46]), float(line[46:54])])
    ca = np.array(ca); ca -= ca.mean(0)
    het = []
    for line in open(pdb):
        if line.startswith("HETATM") and line[17:20].strip() not in ("HOH",):
            het.append([float(line[30:38]), float(line[38:46]), float(line[46:54]), line[17:20].strip()])
    fig = plt.figure(figsize=(7, 6))
    ax = fig.add_subplot(111, projection="3d")
    n = len(ca)
    for i in range(n - 1):
        ax.plot(*zip(ca[i], ca[i + 1]), color=plt.cm.viridis(i / n), lw=2.2)
    if het:
        hx = np.array([[h[0], h[1], h[2]] for h in het]) - 0  # already in same frame before centering
        # recentre hetero atoms with the same shift as CA
        shift = np.array([[float(l[30:38]), float(l[38:46]), float(l[46:54])] for l in open(pdb)
                          if l.startswith("ATOM") and l[12:16].strip() == "CA" and l[21] == "A" and l[16] in (" ", "A")]).mean(0)
        hx = hx - shift
        ax.scatter(hx[:, 0], hx[:, 1], hx[:, 2], s=14, c="#e03030", depthshade=False, label="bound ligands / ions (HETATM)")
        ax.legend(loc="lower left", fontsize=8)
    r = np.abs(ca).max() * 1.02
    ax.set_xlim(-r, r); ax.set_ylim(-r, r); ax.set_zlim(-r, r); ax.set_box_aspect((1, 1, 1)); ax.set_axis_off()
    ax.set_title(title, fontsize=11)
    fig.text(0.5, 0.02, f"Cα trace, {n} residues, coloured N-terminus (purple) → C-terminus (yellow). Coordinates: RCSB PDB.",
             ha="center", fontsize=8, color="#444")
    fig.tight_layout(); fig.savefig(os.path.join(FIG, fname), dpi=170); plt.close(fig)
    print("wrote", fname, n, "CA")

ca_trace(os.path.join(HERE, "pdb", "1LZ0.pdb"), "Human glycosyltransferase A (GTA), PDB 1LZ0 — the enzyme that makes type A", "fig_gta_1LZ0.png")
ca_trace(os.path.join(HERE, "pdb", "1LZI.pdb"), "Human glycosyltransferase B (GTB), PDB 1LZI — four residues different from GTA", "fig_gtb_1LZI.png")

# ---------------------------------------------------------------- compatibility matrices
types = ["O−", "O+", "A−", "A+", "B−", "B+", "AB−", "AB+"]
def parse(t):
    abo = t.rstrip("+−"); rh = t[-1] == "+"
    return set(abo) - {"O"}, rh
def rbc_ok(donor, recip):
    da, dr = parse(donor); ra, rr = parse(recip)
    return da.issubset(ra) and (rr or not dr)
def plasma_ok(donor, recip):
    da, _ = parse(donor); ra, _ = parse(recip)
    # donor plasma carries antibodies against antigens donor lacks; recipient cells must not carry those
    donor_abs = {"A", "B"} - da
    return ra.isdisjoint(donor_abs)

fig, axes = plt.subplots(1, 2, figsize=(11, 5.2))
for ax, fn, title in ((axes[0], rbc_ok, "RED CELLS — donor (rows) → recipient (columns)"),
                      (axes[1], plasma_ok, "PLASMA — donor (rows) → recipient (columns)")):
    M = np.array([[1 if fn(d, r) else 0 for r in types] for d in types])
    ax.imshow(M, cmap=matplotlib.colors.ListedColormap(["#f2d7d5", "#b7e1b1"]), vmin=0, vmax=1)
    for i in range(8):
        for j in range(8):
            ax.text(j, i, "✓" if M[i, j] else "✗", ha="center", va="center", fontsize=12,
                    color="#1b5e20" if M[i, j] else "#8b1a1a")
    ax.set_xticks(range(8)); ax.set_xticklabels(types); ax.set_yticks(range(8)); ax.set_yticklabels(types)
    ax.set_xlabel("recipient"); ax.set_ylabel("donor"); ax.set_title(title, fontsize=10)
    ax.set_xticks(np.arange(-.5, 8, 1), minor=True); ax.set_yticks(np.arange(-.5, 8, 1), minor=True)
    ax.grid(which="minor", color="white", lw=1.5); ax.tick_params(which="minor", length=0)
fig.suptitle("Who can receive what. Red cells: O− gives to all, AB+ takes from all. Plasma inverts: AB gives to all, O takes only O.", fontsize=10)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "fig_compatibility.png"), dpi=170); plt.close(fig)
print("wrote fig_compatibility.png")

# ---------------------------------------------------------------- ABO schematic (own drawing)
fig, axes = plt.subplots(1, 4, figsize=(12, 3.8))
spec = {"O": ([], ["anti-A", "anti-B"]), "A": (["A"], ["anti-B"]), "B": (["B"], ["anti-A"]), "AB": (["A", "B"], [])}
col = {"A": "#d9534f", "B": "#428bca", "H": "#999999"}
for ax, (t, (ags, abs_)) in zip(axes, spec.items()):
    ax.set_xlim(-2, 2); ax.set_ylim(-2, 2); ax.set_aspect("equal"); ax.set_axis_off()
    ax.add_patch(Circle((0, 0), 1.0, facecolor="#f6c1c1", edgecolor="#a33", lw=1.5))
    for k, ang in enumerate(np.linspace(0, 2 * np.pi, 12, endpoint=False)):
        x, y = 1.0 * np.cos(ang), 1.0 * np.sin(ang)
        # H stem on every cell
        ax.plot([x, 1.25 * np.cos(ang)], [y, 1.25 * np.sin(ang)], color=col["H"], lw=2)
        if ags:
            a = ags[k % len(ags)]
            ax.add_patch(Circle((1.38 * np.cos(ang), 1.38 * np.sin(ang)), 0.12, color=col[a]))
    for k, a in enumerate(abs_):
        x = -1.75 + 3.5 * (k + 0.5) / max(1, len(abs_)) if len(abs_) > 1 else 0
        ax.text(x, -1.85, "Y " + a, ha="center", fontsize=9, color=col[a[-1]], fontweight="bold")
    ax.set_title(f"Type {t}\nantigen: {'+'.join(ags) if ags else 'H only'} · plasma: {', '.join(abs_) if abs_ else 'no anti-A/B'}", fontsize=9)
fig.suptitle("Grey stems = H antigen (the base chain, on every cell). Red bead = A sugar (GalNAc). Blue bead = B sugar (Gal). 'Y' = antibodies in the plasma.", fontsize=9)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "fig_abo_schematic.png"), dpi=170); plt.close(fig)
print("wrote fig_abo_schematic.png")

# ---------------------------------------------------------------- sugar fractions in sweeteners
labels = ["Sucrose\n(cane/beet,\nbonded)", "Invert sugar\n(sucrose split\nby acid/enzyme)", "HFCS-42\n(baked goods)",
          "HFCS-55\n(US soft drinks,\nnominal)", "US Coke, lab\n(Ventura 2011,\ndisputed)", "Mexican Coke, lab\n(Ventura 2011:\nmostly inverted)"]
fru = [50, 50, 42, 55, 65, 52]
glc = [50, 50, 53, 42, 35, 48]
oth = [0, 0, 5, 3, 0, 0]
bonded = [True, False, False, False, False, False]
fig, ax = plt.subplots(figsize=(10, 4.6))
x = np.arange(len(labels))
ax.bar(x, fru, color="#f0a030", label="fructose", hatch=["//" if b else "" for b in bonded][0] if False else None)
ax.bar(x, glc, bottom=fru, color="#5090d0", label="glucose")
ax.bar(x, oth, bottom=np.array(fru) + np.array(glc), color="#bbbbbb", label="higher saccharides")
for i, b in enumerate(bonded):
    if b:
        ax.text(i, 50, "bonded\n(one molecule)", ha="center", va="center", fontsize=8, color="white", fontweight="bold")
    else:
        ax.text(i, 25, "free", ha="center", va="center", fontsize=8, color="white")
ax.set_xticks(x); ax.set_xticklabels(labels, fontsize=8); ax.set_ylabel("% of sugar mass"); ax.set_ylim(0, 105)
ax.legend(loc="upper right", fontsize=8, ncol=3)
ax.set_title("What is actually in the sweetener. In an acidic soda (pH ≈ 2.5) sucrose hydrolyses on the shelf into free glucose + fructose,\nso the Mexican bottle converges on the US can; the remaining difference is the fructose fraction (≈50 vs ≈55, or higher if Ventura's numbers hold).", fontsize=9)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "fig_sweetener_fractions.png"), dpi=170); plt.close(fig)
print("wrote fig_sweetener_fractions.png")

# ---------------------------------------------------------------- glucenate pathway
fig, ax = plt.subplots(figsize=(11, 5.4)); ax.set_xlim(0, 11); ax.set_ylim(0, 5.4); ax.set_axis_off()
def box(x, y, w, h, text, fc="#eef3ff", ec="#4466aa", fs=9):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.08", fc=fc, ec=ec, lw=1.4))
    ax.text(x + w / 2, y + h / 2, text, ha="center", va="center", fontsize=fs)
def arrow(x1, y1, x2, y2, text="", col="#333"):
    ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2), arrowstyle="-|>", mutation_scale=14, color=col, lw=1.4))
    if text:
        ax.text((x1 + x2) / 2, (y1 + y2) / 2 + 0.17, text, ha="center", fontsize=7.5, color="#333")
# blood side
ax.add_patch(FancyBboxPatch((0.2, 0.3), 2.3, 4.8, boxstyle="round,pad=0.05", fc="#fff5f5", ec="#cc8888", lw=1, ls="--"))
ax.text(1.35, 4.85, "BLOOD", ha="center", fontsize=10, fontweight="bold", color="#aa4444")
box(0.5, 3.4, 1.7, 0.8, "glucose", fc="#ffe9c9", ec="#d08a20")
box(0.5, 1.4, 1.7, 0.8, "glutamate\n(dietary, MSG)", fc="#e9e9e9", ec="#888")
ax.text(1.35, 0.95, "does not cross\n(blocked at BBB)", ha="center", fontsize=7.5, color="#885")
# barrier
ax.add_patch(FancyBboxPatch((2.75, 0.3), 0.35, 4.8, boxstyle="square,pad=0", fc="#cfd8dc", ec="#607d8b"))
ax.text(2.925, 2.7, "BLOOD–BRAIN BARRIER", rotation=90, ha="center", va="center", fontsize=8, fontweight="bold")
arrow(2.2, 3.8, 3.6, 3.8, "GLUT1")
ax.plot([2.2, 2.75], [1.8, 1.8], color="#888", lw=1.4); ax.text(2.5, 1.9, "✗", ha="center", fontsize=12, color="#a33")
# brain side
ax.add_patch(FancyBboxPatch((3.3, 0.3), 7.5, 4.8, boxstyle="round,pad=0.05", fc="#f3f8ff", ec="#88a", lw=1, ls="--"))
ax.text(7.05, 4.85, "BRAIN (astrocyte → neuron)", ha="center", fontsize=10, fontweight="bold", color="#334488")
box(3.6, 3.4, 1.5, 0.8, "glucose", fc="#ffe9c9", ec="#d08a20")
box(5.5, 3.4, 1.5, 0.8, "pyruvate")
box(7.4, 3.4, 1.6, 0.8, "TCA cycle\n(oxaloacetate ↔ citrate…)")
box(7.4, 1.9, 1.6, 0.8, "α-ketoglutarate\n(α-KG)")
box(5.3, 1.9, 1.7, 0.8, "GLUTAMATE\n(glucenate)", fc="#dff5df", ec="#2e7d32", fs=10)
box(5.3, 0.5, 1.7, 0.8, "glutamine\n(shuttle form)")
box(9.3, 1.9, 1.3, 0.8, "GABA", fc="#f4e1ff", ec="#7b1fa2")
arrow(5.1, 3.8, 5.5, 3.8, "glycolysis")
arrow(7.0, 3.8, 7.4, 3.8, "PDH / PC")
arrow(8.2, 3.4, 8.2, 2.7, "")
arrow(7.4, 2.3, 7.0, 2.3, "transamination (AST/ALT)\nor GDH + NH₄⁺")
arrow(6.15, 1.9, 6.15, 1.3, "glutamine synthetase\n(astrocyte)")
arrow(5.6, 1.3, 5.6, 1.9, "glutaminase\n(neuron)")
arrow(7.0, 2.1, 9.3, 2.1, "GAD")
ax.text(7.05, 0.15, "Glucose crosses; glutamate is built on the brain side from glucose carbon (TCA → α-KG → amination). Repo lexicon: glutamate = glucenate.",
        ha="center", fontsize=8.5, color="#333")
fig.tight_layout(); fig.savefig(os.path.join(FIG, "fig_glucenate_pathway.png"), dpi=170); plt.close(fig)
print("wrote fig_glucenate_pathway.png")

# ---------------------------------------------------------------- frequencies
fig, ax = plt.subplots(figsize=(8, 3.6))
t = ["O+", "A+", "B+", "AB+", "O−", "A−", "B−", "AB−"]; f = [37.4, 35.7, 8.5, 3.4, 6.6, 6.3, 1.5, 0.6]
ax.bar(t, f, color=["#999", "#d9534f", "#428bca", "#8e44ad"] * 2, alpha=[1, 1, 1, 1, .55, .55, .55, .55][0])
for i, v in enumerate(f):
    ax.text(i, v + 0.6, f"{v}%", ha="center", fontsize=8)
ax.set_ylabel("% of US population (approx.)"); ax.set_title("Approximate US frequencies (Stanford Blood Center / AABB figures; varies by ancestry)", fontsize=9)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "fig_frequencies.png"), dpi=170); plt.close(fig)
print("wrote fig_frequencies.png")
print("done")
