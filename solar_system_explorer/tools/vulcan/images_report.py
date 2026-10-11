#!/usr/bin/env python3
"""
images_report.py — a picture report on the elimination pass.

Seven data-driven figures (orreries, histograms, a heat map, a timeline) built
from the JSON the audit already produced, four conceptual images (generated),
each with meta commentary, assembled into one PDF + a companion Markdown file.

Frame: solar equator (Zecliptic) for every orbital drawing. Earth appears only
as a direction arrow, labelled, because the observer is there.

Outputs: img/rep_*.png, img/concept_*.jpg, IMAGES_REPORT_20261010.{pdf,md}
"""
import os, json, math, runpy, random, shutil, textwrap, datetime as dt
import numpy as np
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.patches import Circle, Ellipse, Wedge
from PIL import Image
plt.rcParams.update({"figure.facecolor":"#0b0d17","axes.facecolor":"#0b0d17","axes.edgecolor":"#667","axes.labelcolor":"#dde",
    "xtick.color":"#bbc","ytick.color":"#bbc","text.color":"#eef","grid.color":"#223","legend.facecolor":"#141829","legend.edgecolor":"#445"})
HERE = os.path.dirname(os.path.abspath(__file__))
DOC  = os.path.abspath(os.path.join(HERE, "..", "..", "docs", "MERCURY_VULCAN_LADDER_20261010"))
DATA = os.path.join(DOC, "data"); IMG = os.path.join(DOC, "img")
J = lambda n: json.load(open(os.path.join(DATA, n)))
V4 = J("v4_annulus.json"); PN = J("perihelion_newtonian.json"); OO = J("ladder_oos.json"); LA = J("ladder_analysis.json"); VD = J("vulcan_derivation.json")
ASSETS = os.path.expanduser("~/.cursor/projects/home-dylanmccapes-dev/assets")
R_M = 2439.7; AU = 1.495978707e8

# solar-equator frame
I_SE = math.radians(7.25); OM_SE = math.radians(75.76)
def Rz(t): c, s = math.cos(t), math.sin(t); return np.array([[c,-s,0],[s,c,0],[0,0,1]])
def Rx(t): c, s = math.cos(t), math.sin(t); return np.array([[1,0,0],[0,c,-s],[0,s,c]])
ECL_TO_SE = Rx(-I_SE) @ Rz(-OM_SE)
from skyfield.api import Loader
load = Loader("/tmp/skyfield-data"); eph = load("de421.bsp"); ts = load.timescale()
sun, mer, ven, ear, moon = eph["sun"], eph["mercury"], eph["venus"], eph["earth"], eph["moon"]
def helio_se(body, t): return ECL_TO_SE @ (body.at(t).ecliptic_xyz().au - sun.at(t).ecliptic_xyz().au)

PAGES = []   # (image path, title, commentary)
def page(path, title, text): PAGES.append((path, title, textwrap.dedent(text).strip()))

# ---------------------------------------------------------------------------
# D1. Orrery — Mercury's neighbourhood to scale, solar-equator frame, at BepiColombo MOI
# ---------------------------------------------------------------------------
t_moi = ts.utc(2026, 11, 21, 12)
rm = helio_se(mer, t_moi); re_ = helio_se(ear, t_moi)
sun_dir = -rm[:2]/np.linalg.norm(rm[:2]); earth_dir = (re_-rm)[:2]/np.linalg.norm((re_-rm)[:2])
tf = V4["tidal_floor"]; hc = V4["hill_ceiling"]["summary"]; an = V4["annulus"]
fig, ax = plt.subplots(figsize=(10, 10))
ax.set_aspect("equal")
RH = V4["constants"]["R_hill_perihelion_km"]
ax.add_patch(Circle((0,0), RH, fill=False, ec="#9dff6a", ls=":", lw=1, label=f"Hill radius at perihelion {RH:,.0f} km"))
ax.add_patch(Wedge((0,0), hc["retrograde"]["largest_stable_km"], 0, 360, width=hc["retrograde"]["largest_stable_km"]-hc["prograde"]["largest_stable_km"], color="#4fd1ff", alpha=0.10, label="retrograde-only survival band"))
ax.add_patch(Wedge((0,0), hc["prograde"]["largest_stable_km"], 0, 360, width=hc["prograde"]["largest_stable_km"]-tf["a_min_10km_Q100_km"], color="#4fd1ff", alpha=0.22, label=f"annulus for a 10 km body: {tf['a_min_10km_Q100_km']:,.0f}–{hc['prograde']['largest_stable_km']:,.0f} km"))
ax.add_patch(Wedge((0,0), tf["a_min_10km_Q100_km"], 0, 360, width=tf["a_min_10km_Q100_km"]-tf["a_min_1km_Q100_km"], color="#ffd166", alpha=0.18, label=f"1 km body survives in to {tf['a_min_1km_Q100_km']:,.0f} km"))
ax.add_patch(Wedge((0,0), tf["a_min_1km_Q100_km"], 0, 360, width=tf["a_min_1km_Q100_km"]-R_M, color="#ff5c7a", alpha=0.25, label="tidal death zone for anything ≥ 1 km"))
ax.add_patch(Circle((0,0), R_M, color="#c9b9a6", label="Mercury"))
# spacecraft orbits (projected into the orbital plane; MESSENGER and MPO/Mio are polar, so these are their long axes)
for (peri, apo, col, lab) in ((200+R_M, 15193+R_M, "#ffffff", "MESSENGER 2011 (200 × 15,193 km alt, polar)"), (480+R_M, 1500+R_M, "#ffa94d", "BepiColombo MPO (480 × 1,500 km)"), (590+R_M, 11640+R_M, "#ff7ab6", "BepiColombo Mio (590 × 11,640 km)")):
    a = (peri+apo)/2; c = a-peri; b = math.sqrt(a*a-c*c)
    ax.add_patch(Ellipse((c*0, -c), 2*b, 2*a, fill=False, ec=col, lw=1.2, label=lab))
ax.scatter([5411*math.cos(0.6)], [5411*math.sin(0.6)], marker="x", color="#ff5c7a", s=90, zorder=6, label="chain-interpolated V4 (5,411 km) — dead by tides in 7–42 Myr")
L = RH*1.15
for d, col, lab in ((sun_dir, "#ffd166", "to Sol"), (earth_dir, "#4fd1ff", "to Earth (observer; direction only)")):
    ax.annotate("", xy=(d[0]*L, d[1]*L), xytext=(d[0]*RH*0.98, d[1]*RH*0.98), arrowprops=dict(arrowstyle="->", color=col, lw=2))
    ax.text(d[0]*L*1.04, d[1]*L*1.04, lab, color=col, ha="center", va="center", fontsize=9)
ax.plot([-L, -L+50000], [-L, -L], color="#eee", lw=3); ax.text(-L+25000, -L+6000, "50,000 km", ha="center", fontsize=8)
ax.set_xlim(-L*1.12, L*1.12); ax.set_ylim(-L*1.12, L*1.12); ax.set_xticks([]); ax.set_yticks([])
ax.set_title("Mercury's neighbourhood to scale — solar-equator (Zecliptic) frame, top-down from Sol's north, 2026-11-21 (BepiColombo orbit insertion)", fontsize=10)
ax.legend(loc="lower right", fontsize=7.5)
# inset: the inner 20,000 km, same scale rules
ix = fig.add_axes([0.08, 0.60, 0.30, 0.30]); ix.set_aspect("equal"); ix.set_facecolor("#10131f")
ix.add_patch(Wedge((0,0), 20000, 0, 360, width=20000-tf["a_min_10km_Q100_km"], color="#4fd1ff", alpha=0.22))
ix.add_patch(Wedge((0,0), tf["a_min_10km_Q100_km"], 0, 360, width=tf["a_min_10km_Q100_km"]-tf["a_min_1km_Q100_km"], color="#ffd166", alpha=0.18))
ix.add_patch(Wedge((0,0), tf["a_min_1km_Q100_km"], 0, 360, width=tf["a_min_1km_Q100_km"]-R_M, color="#ff5c7a", alpha=0.25))
ix.add_patch(Circle((0,0), R_M, color="#c9b9a6"))
for (peri, apo, col) in ((200+R_M, 15193+R_M, "#ffffff"), (480+R_M, 1500+R_M, "#ffa94d"), (590+R_M, 11640+R_M, "#ff7ab6")):
    a = (peri+apo)/2; c = a-peri; b = math.sqrt(a*a-c*c); ix.add_patch(Ellipse((0, -c), 2*b, 2*a, fill=False, ec=col, lw=1.2))
ix.scatter([5411*math.cos(0.6)], [5411*math.sin(0.6)], marker="x", color="#ff5c7a", s=80, zorder=6)
ix.set_xlim(-20000, 20000); ix.set_ylim(-20000, 20000); ix.set_xticks([]); ix.set_yticks([])
ix.set_title("inner 20,000 km — MESSENGER's apoapsis (17,633 km) grazes the annulus edge", fontsize=7.5, color="#dde")
for s in ix.spines.values(): s.set_edgecolor("#889")
p1 = os.path.join(IMG, "rep_01_orrery_mercury_neighbourhood.png"); fig.tight_layout(); fig.savefig(p1, dpi=130); plt.close(fig)
page(p1, "D1 — Orrery: where a moon of Mercury could still be", f"""
Everything in this picture is to one scale, which is the point of drawing it: the whole argument of row 6 fits in a single frame.
The red core is where tides kill anything of a kilometre or more inside 4.5 Gyr; the yellow ring is where a 1 km body survives but a
10 km body does not; the blue annulus is the only place a 10 km body (the chain's V4) could have been since formation; the paler outer
band is open to retrograde orbits only. The red × is where the ladder put V4 — inside the death zone. The white ellipse (inset) is the long axis
of MESSENGER's 2011 orbit: its apoapsis at 17,633 km only grazed the inner edge of the 10-km annulus, so MESSENGER's imaging null, not its
orbit, is what constrains the band. The BepiColombo ellipses are smaller still, which is the honest part: the orbiters live close to the
planet and will have to look *outward* to search the band.

What the picture hides: the spacecraft orbits are polar, so in this top-down view they are really lines, not ellipses — I have drawn
their long axes in the plane to show their reach, and said so. The Earth arrow is a direction only; Earth is 0.9 AU away, 500 times
the frame width. And the annulus edges are from a 100-Mercury-year integration — the true million-year edges sit a little inside them.
""")

# ---------------------------------------------------------------------------
# D2. Orrery — inner system, solar-equator frame, two dated receipts, perihelion advance exaggerated
# ---------------------------------------------------------------------------
fig, axs = plt.subplots(1, 2, figsize=(14, 7))
for ax, (y, m, d, h, title) in zip(axs, ((2026, 11, 21, 12, "2026-11-21 — BepiColombo orbit insertion"), (2028, 2, 23, 0, "2028-02-23 00:05 UTC — Luna occults Mercury (Config B test)"))):
    t = ts.utc(y, m, d, h)
    ax.set_aspect("equal")
    for body, col, lab in ((mer, "#c9b9a6", "Mercury"), (ven, "#ffd166", "Venus"), (ear, "#4fd1ff", "Earth")):
        T = {mer: 88, ven: 225, ear: 366}[body]
        tt = ts.utc(y, m, d, h + np.arange(0, 24*T, 24))
        xyz = np.array([helio_se(body, ti) for ti in tt])
        ax.plot(xyz[:,0], xyz[:,1], color=col, lw=0.8, alpha=0.6)
        p = helio_se(body, t); ax.scatter([p[0]], [p[1]], color=col, s=60, zorder=5, label=f"{lab}  (B = {math.degrees(math.atan2(p[2], math.hypot(p[0],p[1]))):+.2f}° solar lat.)")
    ax.scatter([0],[0], color="#fff", s=120, marker="*", zorder=6, label="Sol")
    # Mercury's perihelion direction (from DE421: point of minimum distance over one orbit) and its advance, exaggerated ×500
    tt = ts.utc(y, m, d, h + np.arange(0, 24*90, 6)); xyz = np.array([helio_se(mer, ti) for ti in tt]); r = np.linalg.norm(xyz, axis=1)
    peri = xyz[np.argmin(r)]; ang = math.atan2(peri[1], peri[0])
    for k, (adv, col, lab) in enumerate(((574.1, "#eee", "total advance 574″/cy ×500 (→ 80° per century, drawn)"), (42.98, "#ff5c7a", "anomalous 43″/cy ×500 (→ 6.0° per century, drawn)"))):
        a2 = ang + math.radians(adv/3600*500)
        ax.annotate("", xy=(0.46*math.cos(a2), 0.46*math.sin(a2)), xytext=(0,0), arrowprops=dict(arrowstyle="->", color=col, lw=1.5, ls="--" if k else "-"))
        ax.plot([], [], color=col, ls="--" if k else "-", label=lab)
    ax.annotate("", xy=(0.46*math.cos(ang), 0.46*math.sin(ang)), xytext=(0,0), arrowprops=dict(arrowstyle="->", color="#c9b9a6", lw=2)); ax.plot([], [], color="#c9b9a6", lw=2, label="Mercury perihelion direction now")
    ax.set_xlim(-1.15, 1.15); ax.set_ylim(-1.15, 1.15); ax.set_xlabel("AU (solar-equator x)"); ax.set_ylabel("AU (solar-equator y)")
    ax.set_title(title, fontsize=10); ax.grid(True, alpha=0.3); ax.legend(fontsize=7, loc="lower left")
fig.suptitle("Inner system, solar-equator (Zecliptic) frame, top-down from Sol's north — two dated receipts; Mercury's apsidal advance exaggerated ×500", fontsize=11)
p2 = os.path.join(IMG, "rep_02_orrery_inner_system_receipts.png"); fig.tight_layout(); fig.savefig(p2, dpi=130); plt.close(fig)
page(p2, "D2 — Orrery: the two dated receipts, and how small 43″ is", """
Two dates that the audit cannot move: the day BepiColombo arrives, and the night Luna passes in front of Mercury. Each planet carries
its solar latitude B, because in this frame that number is physical (height above Sol's equator) rather than conventional. The three arrows
from the Sun are Mercury's perihelion direction now, where it will point in a century from all causes, and where the anomalous 43″ alone
would move it — the last two exaggerated five hundred times so that they can be seen at all. Undrawn, the 43″ arrow would sit under the
line width of the first.

That is my commentary on the whole row-10 business: the quantity that produced a planet (Vulcan), a modified force law (Hall), a fictitious
ring, and finally a new theory, is a rotation of the orbit's long axis by one-hundredth of a degree per century. It is real; it was measured
by people with brass instruments; and it is tiny. The exaggeration factor is printed on the figure so no reader mistakes the drawing for
the sky.
""")

# ---------------------------------------------------------------------------
# D3. Histograms — permutation nulls, in-sample and out-of-sample
# ---------------------------------------------------------------------------
ns_null = runpy.run_path(os.path.join(HERE, "ladder_null.py"))
null_in = np.array(ns_null["null"]); rate_in = ns_null["rate_user"]
ns_oos = runpy.run_path(os.path.join(HERE, "ladder_oos.py"))
random.seed(99)
def oos_null(system_name, rule, n=4000):
    S = ns_oos["SYSTEMS"][system_name]; bodies = [k for k in S if k != "primary"]; ROLES = ns_oos["ROLES"]
    out = []
    for _ in range(n):
        perm = random.sample(bodies, min(len(bodies), len(ROLES)))
        rm = {"primary": "primary", **{r: (perm[i] if i < len(perm) else None) for i, r in enumerate(ROLES)}}
        nn, tt = ns_oos["rate"](ns_oos["evaluate"](S, rm)); out.append(nn/tt if tt else np.nan)
    return np.array([x for x in out if not np.isnan(x)])
fig, axs = plt.subplots(1, 3, figsize=(15, 4.8))
axs[0].hist(null_in, bins=30, color="#4fd1ff", alpha=0.8); axs[0].axvline(rate_in, color="#ffd166", lw=2.5, label=f"the ladder as written: {rate_in:.3f}  (p = {ns_null['p_ge']:.2f})")
axs[0].set_title("In-sample: 4,000 random ladders of random triplets\n(7 lines, same metrics, same 0.30-dex hold)", fontsize=9); axs[0].legend(fontsize=8)
for ax, (s, ru) in zip(axs[1:], (("Jupiter moons", "massrank"), ("Saturn moons", "ordinal"))):
    nl = oos_null(s, ru); d = OO["systems"][s][ru]
    ax.hist(nl, bins=25, color="#4fd1ff", alpha=0.8); ax.axvline(d["rate"], color="#ffd166", lw=2.5, label=f"pre-declared {ru} mapping: {d['rate']:.3f}  (p = {d['p_value']:.3f})")
    ax.set_title(f"Out-of-sample: {s}, {ru}\n4,000 random role assignments", fontsize=9); ax.legend(fontsize=8)
for ax in axs: ax.set_xlabel("fraction of tests that 'hold' (|residual| < 0.30 dex)"); ax.set_ylabel("random trials"); ax.grid(True, alpha=0.3)
fig.suptitle("Does the ladder beat a shuffled ladder? Left: no (p = 0.73). Middle: the one of ten out-of-sample tests that did (p = 0.025). Right: a typical one that did not.", fontsize=10)
p3 = os.path.join(IMG, "rep_03_hist_permutation_nulls.png"); fig.tight_layout(); fig.savefig(p3, dpi=130); plt.close(fig)
page(p3, "D3 — Histograms: the ladder against its own shuffle", """
A histogram is the right picture for a null test because it shows the whole crowd the claim has to beat, not a single number. Left:
the ladder as written lands slightly *below* the middle of the crowd of random ladders — it holds less often than nonsense does. Middle:
the single out-of-sample test that did beat random (Jupiter's moons by mass rank), landing in the right tail at p = 0.025. Right: a typical
one that did not.

My commentary: the middle panel is the one a motivated reader would print alone, and that is exactly why it must be shown beside the other
two. One result in ten at the 5 % level is the base rate of coincidence, not a discovery. I also want to be fair to the ladder in the other
direction: the null distributions are wide because the 0.30-dex threshold is generous and the number of tests per system is small (15–54), so
a *real* weak law could hide in these histograms. The out-of-sample design can refute; it cannot confirm. That asymmetry is what elimination
means.
""")

# ---------------------------------------------------------------------------
# D4. Histogram — the residuals themselves, in-sample vs out-of-sample, density separated
# ---------------------------------------------------------------------------
res_in = []; res_in_density = []
for row in LA["ladder_results"]:
    if "planet_x" in row["iv"]: continue
    for m, d in row["metrics"].items():
        for h in ("H1_id", "H1_iv", "H2_mirror_eq", "H3_mirror_inv"):
            if d[h] is not None: (res_in_density if m == "density" else res_in).append(abs(d[h]))
res_oos = []; res_oos_density = []
for s in OO["systems"]:
    for ru in OO["systems"][s]:
        for k, v in OO["systems"][s][ru]["residuals"].items():
            (res_oos_density if "|density|" in k else res_oos).append(abs(v))
fig, axs = plt.subplots(1, 2, figsize=(14, 5), sharey=False)
bins = np.linspace(0, 6, 31)
axs[0].hist([res_in, res_in_density], bins=bins, stacked=True, color=["#ffd166", "#ff5c7a"], label=[f"other metrics (n={len(res_in)})", f"density (n={len(res_in_density)})"])
axs[0].set_title(f"In-sample ladder residuals — {sum(r<0.3 for r in res_in+res_in_density)}/{len(res_in)+len(res_in_density)} inside 0.30 dex", fontsize=10)
axs[1].hist([res_oos, res_oos_density], bins=bins, stacked=True, color=["#4fd1ff", "#ff5c7a"], label=[f"other metrics (n={len(res_oos)})", f"density (n={len(res_oos_density)})"])
axs[1].set_title(f"Out-of-sample residuals, all systems and mappings — {sum(r<0.3 for r in res_oos+res_oos_density)}/{len(res_oos)+len(res_oos_density)} inside 0.30 dex", fontsize=10)
for ax in axs:
    ax.axvline(0.30, color="#eee", ls="--", lw=1.5, label="hold threshold 0.30 dex (factor 2)"); ax.set_xlabel("|residual| (dex) — 1 dex = a factor of ten"); ax.set_ylabel("tests"); ax.legend(fontsize=8); ax.grid(True, alpha=0.3)
p4 = os.path.join(IMG, "rep_04_hist_residuals.png"); fig.tight_layout(); fig.savefig(p4, dpi=130); plt.close(fig)
page(p4, "D4 — Histograms: what the proportions actually miss by", """
This is the distribution of the misses themselves, in decades. A residual of 1 dex means the proportion is off by a factor of ten; 3 dex,
a thousand. Most of the ladder's tests miss by one to three orders of magnitude, in both systems-of-origin and the five others. The red
stack is density, pulled out on purpose: densities of rocky and icy bodies cluster between 1 and 3 g/cm³, so any ratio of two of them lands
near zero dex regardless of how they are paired. The red bars near zero are the metric agreeing with itself, not the ladder agreeing with
nature.

Meta-commentary: a heat-map of cells (Figure 7 of the main report) invites the eye to find the bold cells and ignore the rest. This histogram
is the antidote — it weighs every cell equally and lets the bulk speak. If I had to keep one picture from the ladder work, it would be this
one, because it is the hardest to read selectively.
""")

# ---------------------------------------------------------------------------
# D5. Bar — kill factors: by how much each eliminated candidate fails
# ---------------------------------------------------------------------------
hl = PN["hall"]; rg = PN["exterior_ring"]; bd = PN["planetary_budget"]; pw = VD["precession_without_relativity"]
life = float(V4["tidal_floor"]["chain_V4_lifetime_yr"]["100"])   # Q = 100, the central case
items = [
 ("V2 spin-locked Vulcan\n(a / Hill radius)", VD["variants"]["spin_locked"]["separation_over_hill_peri"], "outside the Hill sphere by this factor"),
 ("V1 Charon-scaled Vulcan\n(reflex / ranging precision)", VD["variants"]["charon_scaled"]["reflex_over_ranging_precision"], "Mercury's wobble vs 10 m ranging"),
 ("chain V4 at 5,411 km\n(4.5 Gyr / tidal lifetime)", 4.5e9/life, "cannot be primordial"),
 ("solar J₂ for 43″\n(needed / measured)", pw["ratio_needed_over_measured"], "helioseismic J₂"),
 ("Hall exponent\n(Moon perigee / LLR limit)", hl["Moon"]["sigmas_off"], "lunar laser ranging"),
 ("exterior ring at 1 AU\n(mass needed / zodiacal)", rg[1]["deficit_factor"], "IRAS/COBE dust mass"),
 ("Jupiter mass error for 43″\n(needed / GM uncertainty)", bd["Jupiter"]["factor_over_uncertainty"], "spacecraft tracking"),
 ("Venus mass error for 43″\n(needed / GM uncertainty)", bd["Venus"]["factor_over_uncertainty"], "spacecraft tracking"),
]
fig, ax = plt.subplots(figsize=(12, 6))
y = np.arange(len(items)); vals = [v for _, v, _ in items]
cols = ["#ffd166" if v < 10 else "#ff9f6a" if v < 1e3 else "#ff5c7a" for v in vals]
ax.barh(y, vals, color=cols); ax.set_xscale("log"); ax.set_yticks(y); ax.set_yticklabels([n for n, _, _ in items], fontsize=8.5)
for yi, (n, v, w) in zip(y, items): ax.text(v*1.3, yi, (f"×{v:.2f}" if v < 10 else f"×{v:,.0f}" if v < 1e4 else f"×{v:.1e}") + f"  —  {w}", va="center", fontsize=8)
ax.axvline(1, color="#eee", lw=1); ax.axvline(10, color="#eee", lw=0.8, ls=":"); ax.set_xlim(0.5, 1e11)
ax.set_xlabel("factor by which the candidate fails its measurement (log scale; ×1 = survives)"); ax.grid(True, axis="x", alpha=0.3)
ax.set_title("Kill factors — every eliminated candidate, and the measurement that killed it", fontsize=11)
p5 = os.path.join(IMG, "rep_05_bar_kill_factors.png"); fig.tight_layout(); fig.savefig(p5, dpi=130); plt.close(fig)
page(p5, "D5 — Bar chart: by how much each candidate dies", """
Elimination is only honest if it says *by how much*. A candidate excluded by a factor of 1.4 is excluded by one assumption; a candidate
excluded by a factor of a hundred million is excluded by arithmetic. This chart puts them on one logarithmic axis. The weakest kill is the
spin-locked Vulcan, outside the Hill sphere by ×1.44 — enough, but worth saying it is the softest. The chain's V4 fails by ×320 on lifetime,
which depends on an assumed Q; it would take Q ≈ 30,000 (no rock has it) to rescue. Everything to the right of 10³ is dead under any
reasonable change of assumptions.

What I like about this picture is that it also ranks my own confidence. What I distrust about it is the same thing: a single number per
row hides that the rows are different *kinds* of kill — geometric (Hill), dynamical (tides), metrological (ranging, LLR, GM). I have put the
instrument in each label so the kind is at least named.
""")

# ---------------------------------------------------------------------------
# D6. Heat map — tidal lifetime over (body radius, orbital radius)
# ---------------------------------------------------------------------------
GM_M = 2.2032e13; K2 = 0.45; RHO = 2000.0; M_M = 3.3011e23; Q = 100
Rb = np.logspace(1, 4.5, 200); A = np.logspace(math.log10(2500), math.log10(180000), 200)
RR, AA = np.meshgrid(Rb, A)
m = RHO*4/3*math.pi*(RR)**3; n0 = math.sqrt(GM_M/(R_M*1e3)**3)
life_yr = (AA*1e3/(R_M*1e3))**6.5 * Q*M_M/(3*K2*m*n0) / 3.15576e7
fig, ax = plt.subplots(figsize=(11, 7))
im = ax.pcolormesh(Rb/1e3, A, np.log10(life_yr), cmap="magma", vmin=4, vmax=14, shading="auto")
cs = ax.contour(Rb/1e3, A, np.log10(life_yr), levels=[math.log10(4.5e9)], colors=["#4fd1ff"], linewidths=2); ax.clabel(cs, fmt={math.log10(4.5e9): "4.5 Gyr"}, fontsize=9)
ax.axhline(V4["hill_ceiling"]["summary"]["prograde"]["largest_stable_km"], color="#9dff6a", ls="--", label="prograde Hill ceiling")
ax.axhline(V4["hill_ceiling"]["summary"]["retrograde"]["largest_stable_km"], color="#9dff6a", ls=":", label="retrograde Hill ceiling")
ax.axhline(R_M, color="#aaa", label="Mercury's surface")
ax.scatter([9.8], [5411], color="#fff", marker="x", s=100, zorder=6, label="chain V4 (9.8 km, 5,411 km)")
ax.set_xscale("log"); ax.set_yscale("log"); ax.set_xlabel("body radius (km)"); ax.set_ylabel("orbital radius about Mercury (km)")
plt.colorbar(im, ax=ax).set_label("log₁₀ tidal lifetime (years), Q = 100, k₂ = 0.45, ρ = 2 g/cm³")
ax.set_title("How long a moon of Mercury lasts before tides bring it down — the blue line is the age of the solar system", fontsize=11)
ax.legend(fontsize=8, loc="upper left"); ax.grid(True, which="both", alpha=0.25)
p6 = os.path.join(IMG, "rep_06_heatmap_tidal_lifetime.png"); fig.tight_layout(); fig.savefig(p6, dpi=130); plt.close(fig)
page(p6, "D6 — Heat map: the lifetime surface", """
The tidal-floor curve in the main report is one contour of this surface. Showing the whole surface says something the contour cannot: how
steep it is. Lifetime goes as a^6.5 and as R^-3, so a factor of two in orbital radius buys a factor of ninety in years. That steepness is why
the floor is a hard edge and not a gradient — and why the chain's V4 (white ×), sitting two to three decades below the blue line, cannot be
rescued by any plausible change of Q or density. It is also why a *small* body (left side) can live close in: a 100 m pebble at 2,000 km
is fine for the age of the solar system.

Meta-commentary: this is a Newtonian picture using a measured k₂ and an assumed Q. Q is the honest unknown — 50 to 300 for rock — and it
moves the blue line by about 0.15 dex either way. I chose a colour map that runs dark-to-bright with lifetime so that the dead region reads
as dark. That is a rhetorical choice and I am naming it.
""")

# ---------------------------------------------------------------------------
# D7. Timeline — dated receipts, 1859 → 2028
# ---------------------------------------------------------------------------
EV = [
 (1859.9, "Le Verrier: 38″/cy unexplained (later 43″)", "#ffd166", 1),
 (1860.0, "Lescarbault's 'Vulcan' transit — never confirmed", "#ff5c7a", -1),
 (1894.0, "Hall: F ∝ r^-(2+δ)", "#ffd166", 1.6),
 (1903.0, "Brown rejects Hall on the Moon", "#4fd1ff", -1.6),
 (1974.24, "Mariner 10: UV 'moon' = 31 Crateris", "#ff5c7a", 1),
 (1980.8, "Stratford: 31 Crateris reexamined", "#4fd1ff", -1),
 (2007.5, "Ground search for satellites (P&SS 55) — limit unread", "#aaa", 1.6),
 (2011.2, "MESSENGER satellite search #1 — none", "#4fd1ff", -1.6),
 (2013.55, "MESSENGER satellite search #2 — none", "#4fd1ff", 1),
 (2019.0, "HgM008 gravity field (Genova+)", "#4fd1ff", -1),
 (2026.78, "this audit (2026-10-10)", "#fff", 1.6),
 (2026.89, "BepiColombo orbit insertion 2026-11-21", "#9dff6a", -1.6),
 (2027.2, "BepiColombo science ops begin", "#9dff6a", 1),
 (2028.15, "Luna occults Mercury 2028-02-23 — Config B test", "#9dff6a", -1),
]
fig, ax = plt.subplots(figsize=(15, 5))
ax.axhline(0, color="#eee", lw=1.5)
for x, lab, col, lvl in EV:
    ax.plot([x, x], [0, lvl], color=col, lw=1); ax.scatter([x], [0], color=col, s=40, zorder=5)
    ax.text(x, lvl*1.08, f"{lab}\n{x:.0f}" if x < 2026 else lab, ha="center", va="bottom" if lvl > 0 else "top", fontsize=7.5, color=col)
ax.axvspan(2026.78, 2028.3, color="#9dff6a", alpha=0.08); ax.text(2027.5, -2.6, "instruments named, not yet reported", ha="center", fontsize=8, color="#9dff6a")
ax.set_ylim(-3, 3); ax.set_yticks([]); ax.set_xlim(1850, 2032); ax.set_xlabel("year")
ax.set_title("Dated receipts — claims (red), tests (blue), the hypothesis' own moves (yellow), and what is still to come (green)", fontsize=11)
ax.grid(True, axis="x", alpha=0.3)
p7 = os.path.join(IMG, "rep_07_timeline_receipts.png"); fig.tight_layout(); fig.savefig(p7, dpi=130); plt.close(fig)
page(p7, "D7 — Timeline: receipts, not narrative", """
The user's rule for history in this project is 'receipts': a thing happened on a date or it is a story. This is the Mercury question told
only in dated marks. Red marks are claims that turned out to be false (Lescarbault's Vulcan; Mariner 10's moon); blue marks are the tests
that killed them or searched and found nothing; yellow are the hypothesis changing shape to survive (Hall's exponent); green is what has a
date but no result yet. The grey mark is a receipt I could not read today — a published limit I know exists and have not seen — and it is
on the line as grey rather than left off.

Meta-commentary: the gap between 1903 and 1974 is where the story usually puts its hero, and this timeline leaves it empty on purpose; under
this audit's rules that part of the record is not admissible, and the emptiness is the correct shape of the rule. A timeline cannot show
*why* a thing was believed, only *when* it was tested. That is a weakness as history and a strength as audit.
""")

# ---------------------------------------------------------------------------
# Conceptual images — copy into img/ and comment
# ---------------------------------------------------------------------------
CONCEPT = [
 ("concept_01_annulus_of_survival.jpg", "C1 — The annulus of survival (generated)", """
 Prompted as an engraving: scorched inner zone, a calm teal band, torn void beyond, one pebble-moon in the band, no text. The generator put the
 pebble at about the right place and gave the outer edge the ragged quality I asked for; it also made the inner red zone wider than the data
 do, which is the usual failure of a conceptual image — it dramatises the gradient. I keep it because it says in one glance what D1 says in
 twelve labels: there is a place the thing could be, and it is a thin ring, not a planet's worth of room.

 Meta-commentary: this image contains no information that D1 does not. Its job is to be remembered. Conceptual images in a technical report are
 mnemonics, and the test for including one is whether it would mislead a reader who saw it *without* the data figure. This one would make
 the death zone look too large; otherwise it is faithful.
 """),
 ("concept_02_arrow_not_followed.jpg", "C2 — The arrow not followed (generated)", """
 A fork: the worn path to the observatory, the clean path toward a sliver of light, the surveyor's chain set down. The generator added a
 'V' on the signpost arm that I did not ask for — I had asked for a small angle mark — and I have left it, because V for Vulcan is a better
 accident than my intention, and because the record of what a tool did on its own belongs in the ledger as much as what I did.

 This is the image for row 10. No Newtonian cause of the 43″ survives; that sentence is a receipt and it is also a direction. The project's
 rule is that the direction is not walked here. The painting is about putting the chain down deliberately — not losing it. I think that is
 the most honest single image in the set, and it is the one with the least data in it.
 """),
 ("concept_03_eliminating_not_forcing.jpg", "C3 — Eliminating, not forcing (generated)", """
 A block that nothing has been added to; a figure appearing only by removal; thirteen fragments on the floor, tallied in chalk, eleven set
 aside finished, two still near the block. The generator gave me more than thirteen fragments and arranged them in rows rather than a fan.
 I count that as a miss on the brief and a hit on the idea: the point is the floor, not the statue. The board had thirteen rows; this pass
 closed or emptied most of them and left two near the block (row 6 confined, row 7 dated).

 Meta-commentary: 'we are eliminating, not forcing' is the user's sentence and this is my attempt to draw it. A sculptor who forces is one
 who glues on marble. The plumb line hanging still is the frame — solar equator — that nothing in the room is allowed to move.
 """),
 ("concept_04_false_moon_1974.jpg", "C4 — The false moon of 1974 (generated)", """
 A 1974 control room: the strip chart with the ultraviolet spike, the teletype, the chalkboard with a crescent half-erased and a star drawn
 beside it as the correction, one brighter star in the window. The generator did not half-erase the crescent — both symbols stand clean —
 which accidentally makes the picture better history: in March 1974 the moon and the star were both on the board at once, and it took six
 years (Stratford 1980) to erase one of them.

 This is the image for the kinematic filter in the BepiColombo request. The 1974 'moon' was detached from Mercury, moved at 4 km/s, and was a
 binary star 400 light-years away. Everything in item 3.4 of the request exists to make that specific mistake impossible to repeat. I include
 the picture because an audit that only drew its own successes would be an advertisement.
 """),
]
for fn, title, text in CONCEPT:
    src = os.path.join(ASSETS, fn); dst = os.path.join(IMG, fn)
    if os.path.exists(src) and not os.path.exists(dst): shutil.copy(src, dst)
    page(dst, title, text)

# ---------------------------------------------------------------------------
# PDF + MD
# ---------------------------------------------------------------------------
pdf_path = os.path.join(DOC, "IMAGES_REPORT_20261010.pdf"); md_path = os.path.join(DOC, "IMAGES_REPORT_20261010.md")
INTRO = """Eleven images on the Mercury / Vulcan elimination pass: seven built from the audit's own data (two orreries, three histogram/bar
figures, a heat map, a timeline) and four conceptual images generated from written briefs. Each carries the chronicler's commentary on what
it shows, what it hides, and where it could mislead. Frame for every orbital drawing: solar equator (Zecliptic), top-down from Sol's north.
Earth appears only as a labelled direction, because the observer is there. No relativity is used or drawn anywhere in this document."""
with PdfPages(pdf_path) as pdf:
    fig = plt.figure(figsize=(11, 8.5));     fig.text(0.5, 0.86, "Mercury / Vulcan — the elimination pass in pictures", ha="center", fontsize=22, weight="bold")
    fig.text(0.5, 0.80, "data-driven and conceptual images, with meta commentary", ha="center", fontsize=13, color="#bbc")
    fig.text(0.5, 0.75, "2026-10-10 · solar-equator (Zecliptic) frame · Newtonian throughout", ha="center", fontsize=11, color="#9dff6a")
    fig.text(0.08, 0.66, textwrap.fill(INTRO, 120), fontsize=9.5, va="top", linespacing=1.5)
    fig.text(0.08, 0.47, "Contents\n" + "\n".join(f"  {i+1:2d}. {t}" for i, (_, t, _) in enumerate(PAGES)), fontsize=8.5, va="top", linespacing=1.4, color="#dde")
    pdf.savefig(fig); plt.close(fig)
    for i, (path, title, text) in enumerate(PAGES):
        fig = plt.figure(figsize=(11, 8.5))
        im = Image.open(path); w, h = im.size; ar = w/h
        box_w, box_h = 0.86, 0.50
        if ar > box_w*11/(box_h*8.5): ww, hh = box_w, box_w*11/ar/8.5
        else: hh, ww = box_h, box_h*8.5*ar/11
        ax = fig.add_axes([(1-ww)/2, 0.93-hh, ww, hh]); ax.imshow(im); ax.axis("off")
        fig.text(0.5, 0.955, title, ha="center", fontsize=13, weight="bold")
        fig.text(0.07, 0.93-hh-0.03, textwrap.fill(text.replace("\n", " "), 150), fontsize=8.3, va="top", linespacing=1.45)
        fig.text(0.5, 0.02, f"{i+1} / {len(PAGES)}   ·   {os.path.relpath(path, DOC)}", ha="center", fontsize=7.5, color="#889")
        pdf.savefig(fig); plt.close(fig)
md = ["# Mercury / Vulcan — the elimination pass in pictures", "", INTRO, ""]
for path, title, text in PAGES:
    md += [f"## {title}", "", f"![{title}]({os.path.relpath(path, DOC)})", "", text, ""]
open(md_path, "w").write("\n".join(md))
print("wrote", pdf_path, os.path.getsize(pdf_path)//1024, "KB;", md_path, ";", len(PAGES), "images")
