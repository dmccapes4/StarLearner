"""
Winter Circle → Gemini → Cancer → Leo : the extension
Dylan McCapes — October 9, 2026

Takes WINTER_CIRCLE_PIPE_REPORT + dance_projection.py further:
  * full Gemini (15 stars), Cancer (7 incl. M44/M67), Leo (15 stars) + reference bodies
  * Zecliptic (ecliptic) frame for everything; the floor drawn explicitly
  * star_pipe (same definition as WINTER_CIRCLE_PIPE_REPORT §II) over the extended set
  * the 2-1-2 slide dance continued from M44 into Leo — honest about what reaches and what misses
  * Mars 2008 / 2025 (prior) + Mars 2027 opposition (computed, ephem) + Jupiter 2026/2027 (computed)
  * six PNG views, a PDF, JSON + JSONL, and a plain stats text

Outputs are written next to this script with prefix ext_.
Epoch J2000.0; obliquity ε = 23.4393°. Planet positions via PyEphem (VSOP87; arcmin-level).
"""
import os, sys, json, math
from itertools import combinations
from collections import Counter, defaultdict
from math import radians, degrees, sin, cos, asin, atan2, acos

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import ephem

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else HERE
os.makedirs(OUT, exist_ok=True)
EPS = radians(23.4393)

# ─────────────────────────────────────────────────────────────────────────────
# Catalog  (name, bayer, RA_h, Dec_deg, mag, dist_ly, constellation, role)
# ─────────────────────────────────────────────────────────────────────────────
CAT = [
 # Winter Circle / cat (from prior report)
 ("Sirius",      "α CMa", 6.75248, -16.7161, -1.46,    8.6, "CMa", "prey"),
 ("Rigel",       "β Ori", 5.24230,  -8.2017,  0.13,  860,   "Ori", "front_paw"),
 ("Aldebaran",   "α Tau", 4.59868,  16.5093,  0.87,   65.3, "Tau", "rear_hip"),
 ("Capella",     "α Aur", 5.27816,  45.9980,  0.08,   42.9, "Aur", "spine_apex"),
 ("Procyon",     "α CMi", 7.65503,   5.2250,  0.34,   11.46,"CMi", "right_eye"),
 ("Gomeisa",     "β CMi", 7.45251,   8.2893,  2.89,  170,   "CMi", "left_eye"),
 ("Betelgeuse",  "α Ori", 5.91953,   7.4071,  0.50,  700,   "Ori", "chest"),
 ("Bellatrix",   "γ Ori", 5.41885,   6.3497,  1.64,  250,   "Ori", "shoulder"),
 ("Alnilam",     "ε Ori", 5.60356,  -1.2019,  1.69, 1340,   "Ori", "belt_C"),
 ("Alnitak",     "ζ Ori", 5.67931,  -1.9429,  1.74,  800,   "Ori", "belt_E"),
 ("Mintaka",     "δ Ori", 5.53344,  -0.2991,  2.23,  900,   "Ori", "belt_W"),
 # Gemini — full figure
 ("Castor",      "α Gem", 7.57663,  31.8883,  1.58,   51.5, "Gem", "head_W / haunch_W"),
 ("Pollux",      "β Gem", 7.75526,  28.0262,  1.14,   33.8, "Gem", "head_E / haunch_E"),
 ("Alhena",      "γ Gem", 6.62853,  16.3993,  1.93,  109,   "Gem", "Pollux_foot"),
 ("Wasat",       "δ Gem", 7.33538,  21.9823,  3.53,   60,   "Gem", "Pollux_waist (on Zecliptic)"),
 ("Mebsuta",     "ε Gem", 6.73220,  25.1311,  3.06,  840,   "Gem", "Castor_waist"),
 ("Mekbuda",     "ζ Gem", 7.06848,  20.5703,  3.9,  1200,   "Gem", "Pollux_knee (Cepheid)"),
 ("Propus",      "η Gem", 6.24796,  22.5068,  3.3,   380,   "Gem", "Castor_foot"),
 ("Tejat",       "μ Gem", 6.38268,  22.5136,  2.87,  230,   "Gem", "Castor_foot"),
 ("Alzirr",      "ξ Gem", 6.75483,  12.8956,  3.35,   59,   "Gem", "Pollux_foot_S"),
 ("κ Gem",       "κ Gem", 7.74079,  24.3980,  3.57,  141,   "Gem", "Pollux_shoulder"),
 ("λ Gem",       "λ Gem", 7.30155,  16.5404,  3.58,  101,   "Gem", "Pollux_hand"),
 ("θ Gem",       "θ Gem", 6.87982,  33.9613,  3.60,  190,   "Gem", "Castor_arm"),
 ("ι Gem",       "ι Gem", 7.42878,  27.7981,  3.79,  120,   "Gem", "between_heads"),
 ("υ Gem",       "υ Gem", 7.59871,  26.8958,  4.06,  240,   "Gem", "Pollux_neck"),
 ("τ Gem",       "τ Gem", 7.18566,  30.2452,  4.41,  320,   "Gem", "Castor_shoulder"),
 # Cancer — the Dancer (kʞ)
 ("M44",         "Praesepe", 8.6733, 19.6830, 3.7,   577,   "Cnc", "hive"),
 ("Asellus Bor.","γ Cnc", 8.72143,  21.4685,  4.66,  181,   "Cnc", "donkey_N"),
 ("Asellus Aus.","δ Cnc", 8.74475,  18.1543,  3.94,  131,   "Cnc", "donkey_S (on Zecliptic)"),
 ("Al Tarf",     "β Cnc", 8.27526,   9.1855,  3.52,  290,   "Cnc", "claw_S"),
 ("Acubens",     "α Cnc", 8.97478,  11.8577,  4.25,  174,   "Cnc", "claw_E"),
 ("ι Cnc",       "ι Cnc", 8.77828,  28.7599,  4.02,  330,   "Cnc", "claw_N"),
 ("M67",         "NGC 2682", 8.8550, 11.8170, 6.1,  2700,   "Cnc", "old_cluster"),
 # Leo — the Lion
 ("Regulus",     "α Leo", 10.13953, 11.9672,  1.40,   79,   "Leo", "heart (ON Zecliptic)"),
 ("Denebola",    "β Leo", 11.81766, 14.5720,  2.14,   36,   "Leo", "tail"),
 ("Algieba",     "γ Leo", 10.33288, 19.8415,  2.08,  130,   "Leo", "mane / sickle"),
 ("Zosma",       "δ Leo", 11.23513, 20.5237,  2.56,   58,   "Leo", "hip"),
 ("Ras Elased",  "ε Leo", 9.76419,  23.7743,  2.98,  247,   "Leo", "head / sickle_tip"),
 ("Adhafera",    "ζ Leo", 10.27817, 23.4173,  3.44,  274,   "Leo", "mane / sickle"),
 ("Rasalas",     "μ Leo", 9.87940,  26.0070,  3.88,  124,   "Leo", "head / sickle"),
 ("Chertan",     "θ Leo", 11.23734, 15.4296,  3.33,  165,   "Leo", "haunch"),
 ("η Leo",       "η Leo", 10.12221, 16.7627,  3.49, 1270,   "Leo", "neck / sickle"),
 ("Subra",       "ο Leo", 9.68586,   9.8923,  3.52,  135,   "Leo", "front_paw"),
 ("ρ Leo",       "ρ Leo", 10.54685,  9.3066,  3.84, 5000,   "Leo", "chest"),
 ("ι Leo",       "ι Leo", 11.39874, 10.5294,  3.94,   79,   "Leo", "rear_leg"),
 ("σ Leo",       "σ Leo", 11.35228,  6.0293,  4.05,  210,   "Leo", "rear_paw"),
 ("Alterf",      "λ Leo", 9.52868,  22.9680,  4.31,  330,   "Leo", "mouth"),
 ("Al Minliar",  "κ Leo", 9.41090,  26.1823,  4.46,  210,   "Leo", "muzzle"),
 # Reference — below the floor
 ("Alphard",     "α Hya", 9.45979,  -8.6586,  1.98,  177,   "Hya", "below_floor_reference"),
]
CONST_COL = {"CMa":"#ffffff","Ori":"#aaaacc","Tau":"#cc99ff","Aur":"#cc99ff","CMi":"#00ffff",
             "Gem":"#ffdd44","Cnc":"#ff9944","Leo":"#ff6666","Hya":"#777799"}

# Prior Mars events (from WINTER_CIRCLE_PIPE_REPORT) — kept as given there
MARS_PRIOR = [("Mars_2008", "2008/01/02", 5.955203, 26.9513, -1.38, 0.610),
              ("Mars_2025", "2025/01/16", 7.929,    25.15,   -1.25, 0.643)]

# ─────────────────────────────────────────────────────────────────────────────
# Geometry
# ─────────────────────────────────────────────────────────────────────────────
def xyz(ra_h, dec_d):
    r, d = radians(ra_h * 15), radians(dec_d)
    return np.array([cos(d)*cos(r), cos(d)*sin(r), sin(d)])

def radec(v):
    v = v / np.linalg.norm(v)
    return (degrees(atan2(v[1], v[0])) % 360) / 15, degrees(asin(np.clip(v[2], -1, 1)))

def sep(a, b):
    return degrees(acos(float(np.clip(np.dot(xyz(*a), xyz(*b)), -1, 1))))

def to_ecl(ra_h, dec_d):
    r, d = radians(ra_h*15), radians(dec_d)
    beta = asin(np.clip(sin(d)*cos(EPS) - cos(d)*sin(EPS)*sin(r), -1, 1))
    lam = atan2(sin(d)*sin(EPS) + cos(d)*cos(EPS)*sin(r), cos(d)*cos(r))
    return degrees(lam) % 360, degrees(beta)

def from_ecl(lam_d, beta_d):
    l, b = radians(lam_d), radians(beta_d)
    dec = asin(np.clip(sin(b)*cos(EPS) + cos(b)*sin(EPS)*sin(l), -1, 1))
    ra = atan2(cos(b)*cos(EPS)*sin(l) - sin(b)*sin(EPS), cos(b)*cos(l))
    return (degrees(ra) % 360) / 15, degrees(dec)

def dsum(n):  return sum(int(c) for c in str(abs(int(n))))

def star_pipe(lam, beta):
    """Identical to WINTER_CIRCLE_PIPE_REPORT §II."""
    L = dsum(round(lam)) % 10
    B = dsum(round(abs(beta))) % 10
    E = abs(L - B)
    F = L + E + B                     # == 2*max(L,B)  (see T1 below)
    G = int(str(round(lam))[0])
    return dict(L=L, B=B, E=E, F=F, G=G, self_pipe=(L == B))

# ─────────────────────────────────────────────────────────────────────────────
# Planets (ephem)
# ─────────────────────────────────────────────────────────────────────────────
def planet_at(body, date):
    body.compute(ephem.Date(date))
    ra_h = float(body.a_ra) * 12 / math.pi
    dec = float(body.a_dec) * 180 / math.pi
    return ra_h, dec, float(body.mag), float(body.earth_distance)

def mars_2027():
    m = ephem.Mars()
    # opposition ≈ minimum Earth distance
    d, best = ephem.Date("2027/01/01"), None
    while d < ephem.Date("2027/05/01"):
        ra, dec, mag, dist = planet_at(m, d)
        if best is None or dist < best["dist_au"]:
            best = dict(date=str(ephem.Date(d)).split()[0].replace("/", "-"), ra_h=ra, dec_d=dec, mag=mag, dist_au=dist)
        d = ephem.Date(d + 1)
    # path, 5-day cadence Nov 2026 → Jun 2027
    path, d = [], ephem.Date("2026/11/01")
    while d <= ephem.Date("2027/06/30"):
        ra, dec, mag, dist = planet_at(m, d)
        lam, beta = to_ecl(ra, dec)
        path.append(dict(date=str(ephem.Date(d)).split()[0], ra_h=ra, dec_d=dec, mag=mag, lam=lam, beta=beta))
        d = ephem.Date(d + 5)
    # stationary points = local RA extrema around opposition (east station before, west station after)
    ras = np.array([p["ra_h"] for p in path])
    i_opp = min(range(len(path)), key=lambda i: abs(ephem.Date(path[i]["date"]) - ephem.Date(best["date"].replace("-", "/"))))
    i_e = int(np.argmax(ras[:i_opp]))
    i_w = i_opp + int(np.argmin(ras[i_opp:i_opp + 24]))
    stations = [path[i_e], path[i_w]]
    # Regulus passes (sign changes of ΔRA)
    reg = next(s for s in CAT if s[0] == "Regulus")
    passes = []
    for a, b in zip(path, path[1:]):
        if (a["ra_h"] - reg[2]) * (b["ra_h"] - reg[2]) < 0:
            passes.append(dict(date=b["date"], sep_deg=sep((b["ra_h"], b["dec_d"]), (reg[2], reg[3]))))
    return best, path, stations, passes

def jupiter_events():
    j = ephem.Jupiter()
    out = []
    for lab, date in [("Jupiter_2026-01-10 (opposition, Gemini)", "2026/01/10"),
                      ("Jupiter_2026-10-09 (today)", "2026/10/09"),
                      ("Jupiter_2027-02-19 (Mars opposition day)", "2027/02/19")]:
        ra, dec, mag, dist = planet_at(j, date)
        out.append(dict(label=lab, ra_h=ra, dec_d=dec, mag=mag))
    return out

# ─────────────────────────────────────────────────────────────────────────────
# Build rows
# ─────────────────────────────────────────────────────────────────────────────
def build():
    rows = []
    for (name, bayer, ra, dec, mag, dist, con, role) in CAT:
        lam, beta = to_ecl(ra, dec)
        rows.append(dict(name=name, bayer=bayer, ra_h=ra, dec_d=dec, mag=mag, dist_ly=dist,
                         con=con, role=role, lam=lam, beta=beta, kind="star", **{"pipe": star_pipe(lam, beta)}))
    for (name, date, ra, dec, mag, au) in MARS_PRIOR:
        lam, beta = to_ecl(ra, dec)
        rows.append(dict(name=name, bayer=date, ra_h=ra, dec_d=dec, mag=mag, dist_ly=au, con="Mars",
                         role="intruder", lam=lam, beta=beta, kind="planet", pipe=star_pipe(lam, beta)))
    best, path, stations, passes = mars_2027()
    lam, beta = to_ecl(best["ra_h"], best["dec_d"])
    rows.append(dict(name="Mars_2027", bayer=best["date"], ra_h=best["ra_h"], dec_d=best["dec_d"], mag=best["mag"],
                     dist_ly=best["dist_au"], con="Mars", role="intruder", lam=lam, beta=beta, kind="planet",
                     pipe=star_pipe(lam, beta)))
    jup = jupiter_events()
    for jv in jup:
        lam, beta = to_ecl(jv["ra_h"], jv["dec_d"])
        jv.update(lam=lam, beta=beta, pipe=star_pipe(lam, beta))
    return rows, dict(best=best, path=path, stations=stations, regulus_passes=passes), jup

# ─────────────────────────────────────────────────────────────────────────────
# Dance
# ─────────────────────────────────────────────────────────────────────────────
def dance(rows):
    R = {r["name"]: r for r in rows}
    G_, P_, Po, M44 = R["Gomeisa"], R["Procyon"], R["Pollux"], R["M44"]
    step = np.array([P_["ra_h"] - G_["ra_h"], P_["dec_d"] - G_["dec_d"]])       # (+0.2025h, −3.064°)
    refl = step * np.array([1, -1])
    P0 = np.array([P_["ra_h"], P_["dec_d"]])
    slide = [P0 + k*refl for k in range(0, 13)]                                   # reflected path from Procyon
    M = slide[5]                                                                 # ≈ M44
    # Option A: keep going (steps 6..12)
    # Option B: second slide at step 5 (flip Dec again)
    second = [M + k*step for k in range(0, 10)]
    leo_targets = ["Regulus", "Algieba", "Adhafera", "η Leo", "Ras Elased", "Denebola", "Zosma", "Subra", "Alphard"]
    def nearest(pt):
        best = min(((sep(tuple(pt), (R[n]["ra_h"], R[n]["dec_d"])), n) for n in R if R[n]["kind"] == "star"))
        return best
    optA = [(k, slide[k], nearest(slide[k])) for k in range(6, 13)]
    optB = [(k, second[k], nearest(second[k])) for k in range(1, 10)]
    # Option C: Zecliptic Δλ stepping, β pinned to the floor (Leo lies on it)
    lg, bg = to_ecl(G_["ra_h"], G_["dec_d"]); lp, bp = to_ecl(P_["ra_h"], P_["dec_d"])
    dlam = lp - lg
    lm, bm = to_ecl(M44["ra_h"], M44["dec_d"])
    lam_steps = {n: (to_ecl(R[n]["ra_h"], R[n]["dec_d"])[0] - lm) / dlam for n in leo_targets if n != "Alphard"}
    # Option D: 2-1-2-1-2-1 phrase lengths
    phrase = [("2 eyes", "Gomeisa", "Procyon"), ("→1", "Procyon", "Pollux"), ("→2 donkeys", "Pollux", "M44"),
              ("→1 heart", "M44", "Regulus"), ("→2 mane", "Regulus", "Algieba"), ("→1 tail", "Algieba", "Denebola")]
    phrase_len = [(lab, a, b, sep((R[a]["ra_h"], R[a]["dec_d"]), (R[b]["ra_h"], R[b]["dec_d"]))) for lab, a, b in phrase]
    # Twin pairs: every pair 2.5°–5.5° apart (the "two" unit of the dance)
    twins = []
    for a, b in combinations([r for r in rows if r["kind"] == "star"], 2):
        s = sep((a["ra_h"], a["dec_d"]), (b["ra_h"], b["dec_d"]))
        if 2.5 <= s <= 5.5:
            twins.append((s, a["name"], b["name"]))
    twins.sort()
    return dict(step=step, refl=refl, slide=slide, second=second, optA=optA, optB=optB, dlam=dlam,
                lam_steps=lam_steps, phrase=phrase_len, twins=twins, M44_lam=lm, M44_beta=bm)

# ─────────────────────────────────────────────────────────────────────────────
# Plot helpers
# ─────────────────────────────────────────────────────────────────────────────
BG, FG, DIM = "#0a0a15", "#ccddff", "#8888aa"
def fig_ax(w=15, h=9.5, title="", sub=""):
    fig, ax = plt.subplots(figsize=(w, h), facecolor=BG); ax.set_facecolor(BG)
    ax.tick_params(colors="#666699", labelsize=8)
    for s in ax.spines.values(): s.set_color("#222244")
    ax.grid(color="#111133", lw=0.4, ls="--", alpha=0.6)
    fig.suptitle(title, color=FG, fontsize=14, y=0.985)
    if sub: ax.set_title(sub, color=DIM, fontsize=9, pad=6)
    return fig, ax

def draw_zecliptic(ax, lam0=50, lam1=190, label=True):
    pts = [from_ecl(l, 0) for l in np.linspace(lam0, lam1, 300)]
    ax.plot(*zip(*pts), color="#2d6b8f", lw=1.6, alpha=0.9)
    for b, ls in [(5, ":"), (-5, ":")]:
        pts = [from_ecl(l, b) for l in np.linspace(lam0, lam1, 300)]
        ax.plot(*zip(*pts), color="#2d6b8f", lw=0.6, ls=ls, alpha=0.6)
    if label:
        ra, dec = from_ecl(lam1 - 4, 0)
        ax.text(ra, dec + 1.2, "Zecliptic (β=0)  ±5° dotted", color="#4d8bb0", fontsize=8, clip_on=True)
    for l, t in [(90, "solstice λ=90°"), (120, "λ=120°"), (150, "λ=150°"), (180, "λ=180°")]:
        if not (lam0 <= l <= lam1): continue
        ra, dec = from_ecl(l, 0); ax.plot(ra, dec, marker="|", color="#4d8bb0", ms=12, clip_on=True)
        ax.text(ra, dec - 2.4, t, color="#4d8bb0", fontsize=7, ha="center", clip_on=True)

def draw_stars(ax, rows, label=True, fs=7, dim_mag=4.0):
    for r in rows:
        if r["kind"] != "star": continue
        s = max(8, 110 - r["mag"]*28)
        col = CONST_COL.get(r["con"], "#999")
        mk = "*" if r["name"] in ("M44", "M67") else "o"
        ax.scatter(r["ra_h"], r["dec_d"], s=s if mk == "o" else 140, c=col, marker=mk, zorder=5,
                   alpha=0.95 if r["mag"] < dim_mag else 0.55, edgecolors="k", linewidths=0.3)
        if label:
            ax.annotate(r["name"], (r["ra_h"], r["dec_d"]), xytext=(3, 4), textcoords="offset points",
                        color=col if r["mag"] < 3.6 else DIM, fontsize=fs if r["mag"] < 3.6 else fs-1)

def planet_marker(ax, ra, dec, label, col="#ff4444", mk="D", s=90, off=(5, -11)):
    ax.scatter(ra, dec, s=s, c=col, marker=mk, zorder=9, edgecolors="white", linewidths=0.8)
    ax.annotate(label, (ra, dec), xytext=off, textcoords="offset points", color=col, fontsize=7.5, fontweight="bold", clip_on=True)

def legend_const(ax, cons):
    for c in cons:
        ax.scatter([], [], c=CONST_COL[c], s=40, label=c)
    ax.legend(loc="lower left", fontsize=8, facecolor="#111122", edgecolor="#333355", labelcolor="#aaaacc")

# ─────────────────────────────────────────────────────────────────────────────
# Views
# ─────────────────────────────────────────────────────────────────────────────
def view1_field(rows, mars, jup, out):
    fig, ax = fig_ax(16, 10, "View 1 — The whole sector: Winter Circle · Gemini · Cancer · Leo",
                     "RA 4h→12.5h (east to the left), Dec −22°→+50°. Zecliptic drawn. Planets: Mars 2008 / 2025 / 2027, Jupiter 2026.")
    ax.set_xlim(12.6, 4.1); ax.set_ylim(-22, 50); ax.set_xlabel("RA (h)", color=DIM); ax.set_ylabel("Dec (°)", color=DIM)
    draw_zecliptic(ax)
    draw_stars(ax, rows)
    # figure lines
    R = {r["name"]: r for r in rows}
    def line(names, col, lw=1.0, ls="-"):
        ax.plot([R[n]["ra_h"] for n in names], [R[n]["dec_d"] for n in names], color=col, lw=lw, ls=ls, alpha=0.55, zorder=3)
    line(["Pollux", "Castor", "Capella"], "#00ffff", 1.2, "--")                       # cat spine
    line(["Gomeisa", "Procyon"], "#00ffff", 1.2)
    line(["Castor", "τ Gem", "Mebsuta", "Tejat", "Propus"], CONST_COL["Gem"])
    line(["Pollux", "υ Gem", "κ Gem"], CONST_COL["Gem"]); line(["Pollux", "Wasat", "Mekbuda", "Alhena"], CONST_COL["Gem"])
    line(["Wasat", "λ Gem", "Alzirr"], CONST_COL["Gem"]); line(["Mebsuta", "θ Gem"], CONST_COL["Gem"])
    line(["Asellus Bor.", "Asellus Aus.", "Acubens"], CONST_COL["Cnc"]); line(["Asellus Aus.", "Al Tarf"], CONST_COL["Cnc"])
    line(["Asellus Bor.", "ι Cnc"], CONST_COL["Cnc"])
    line(["Regulus", "η Leo", "Algieba", "Adhafera", "Rasalas", "Ras Elased", "Alterf", "Al Minliar"], CONST_COL["Leo"])  # sickle
    line(["Regulus", "Chertan", "Denebola", "Zosma", "Algieba"], CONST_COL["Leo"])
    line(["Regulus", "ρ Leo", "ι Leo", "σ Leo"], CONST_COL["Leo"], 0.7)
    line(["Regulus", "Subra"], CONST_COL["Leo"], 0.7)
    # planets
    for n, col in [("Mars_2008", "#ff4444"), ("Mars_2025", "#ff7744"), ("Mars_2027", "#ffaa44")]:
        planet_marker(ax, R[n]["ra_h"], R[n]["dec_d"], f"{n} ({R[n]['bayer']})", col)
    px, py = zip(*[(p["ra_h"], p["dec_d"]) for p in mars["path"]])
    ax.plot(px, py, color="#ffaa44", lw=1.0, alpha=0.7, zorder=8)
    for i, jv in enumerate(jup):
        planet_marker(ax, jv["ra_h"], jv["dec_d"], jv["label"].split(" (")[0].replace("_", " "), "#ffe9a0", "h", 110,
                      off=(5, 8 + 9*i) if i else (5, -11))
    # anticenter & solstice markers
    ax.scatter(5.76, 28.94, marker="+", s=160, c="#9effa0", zorder=6)
    ax.text(5.76, 30.2, "galactic anticenter", color="#9effa0", fontsize=7.5, ha="center")
    legend_const(ax, ["CMi", "Ori", "Tau", "Gem", "Cnc", "Leo", "Hya"])
    fig.savefig(out, dpi=130, facecolor=BG, bbox_inches="tight"); plt.close(fig)

def view2_gemini(rows, jup, out):
    R = {r["name"]: r for r in rows}
    gem = [r for r in rows if r["con"] in ("Gem", "CMi") or r["name"] in ("Mars_2025",)]
    fig, ax = fig_ax(13, 10, "View 2 — Gemini in full: two bodies standing on the Zecliptic",
                     "Feet (Tejat, Propus, Alhena) straddle the floor near the solstice point λ=90°; heads (Castor, Pollux) are the cat's haunches. Jupiter sat in the chest Jan 2026.")
    ax.set_xlim(8.1, 5.9); ax.set_ylim(3, 37); ax.set_xlabel("RA (h)", color=DIM); ax.set_ylabel("Dec (°)", color=DIM)
    draw_zecliptic(ax, 80, 125)
    draw_stars(ax, [r for r in rows if r["kind"] == "star" and 5.9 <= r["ra_h"] <= 8.1 and 3 <= r["dec_d"] <= 37], fs=8)
    def line(names, col, lw=1.3):
        ax.plot([R[n]["ra_h"] for n in names], [R[n]["dec_d"] for n in names], color=col, lw=lw, alpha=0.7, zorder=3)
    line(["Castor", "τ Gem", "Mebsuta", "Tejat", "Propus"], "#ffdd44"); line(["Mebsuta", "θ Gem"], "#ffdd44")
    line(["Pollux", "υ Gem", "κ Gem"], "#ffdd44"); line(["Pollux", "Wasat", "Mekbuda", "Alhena"], "#ffdd44")
    line(["Wasat", "λ Gem", "Alzirr"], "#ffdd44"); line(["Castor", "ι Gem", "Pollux"], "#ffdd44", 0.8)
    line(["Gomeisa", "Procyon"], "#00ffff")
    planet_marker(ax, R["Mars_2025"]["ra_h"], R["Mars_2025"]["dec_d"], "Mars 2025-01-16", "#ff7744")
    j = jup[0]; planet_marker(ax, j["ra_h"], j["dec_d"], "Jupiter 2026-01-10", "#ffe9a0", "h", 130)
    # β annotations for the feet & waist
    for n in ["Tejat", "Propus", "Alhena", "Wasat", "Mekbuda", "Pollux", "Castor", "κ Gem", "λ Gem"]:
        r = R[n]; ax.text(r["ra_h"], r["dec_d"] - 1.4, f"β={r['beta']:+.1f}°", color="#4d8bb0", fontsize=6.5, ha="center")
    ax.text(0.02, 0.03, "Castor–Pollux 4.5° | Procyon–Gomeisa 4.3° | Tejat–Propus 1.9°\n"
            "Gemini stars within ±5° of the Zecliptic: " +
            ", ".join(r["name"] for r in gem if r["con"] == "Gem" and abs(r["beta"]) <= 5),
            transform=ax.transAxes, color="#aaaacc", fontsize=8, family="monospace", va="bottom",
            bbox=dict(boxstyle="round", facecolor="#111133", edgecolor="#333355"))
    fig.savefig(out, dpi=130, facecolor=BG, bbox_inches="tight"); plt.close(fig)

def view3_dance(rows, D, out):
    R = {r["name"]: r for r in rows}
    fig, ax = fig_ax(16, 10, "View 3 — The dance continued: from the hive into the Lion",
                     "Slide (Dec-reflected step) from Procyon reaches M44 at step 5 (prior result). What happens next, three ways.")
    ax.set_xlim(12.3, 6.8); ax.set_ylim(-14, 42); ax.set_xlabel("RA (h)", color=DIM); ax.set_ylabel("Dec (°)", color=DIM)
    draw_zecliptic(ax, 95, 185)
    draw_stars(ax, [r for r in rows if r["kind"] == "star" and r["ra_h"] >= 6.8], fs=7)
    sl = np.array(D["slide"]); ax.plot(sl[:6, 0], sl[:6, 1], color="#ff6688", lw=2.4, marker="o", ms=4, label="slide steps 0–5 (prior)")
    ax.plot(sl[5:, 0], sl[5:, 1], color="#ff6688", lw=1.2, ls="--", marker="o", ms=3, alpha=0.6, label="A: keep stepping (6–12) → Lynx / Leo Minor — misses Leo")
    sc = np.array(D["second"]); ax.plot(sc[:, 0], sc[:, 1], color="#44ff88", lw=1.4, ls="--", marker="o", ms=3, alpha=0.8,
                                       label="B: second slide at M44 (flip Dec back) → runs south of Regulus toward Hydra")
    for k, pt, (s, n) in D["optA"][::2] + D["optB"][1::2]:
        ax.annotate(f"{k}: {n} {s:.1f}°", pt, xytext=(4, 4), textcoords="offset points", color=DIM, fontsize=6.5)
    # Option C: Zecliptic walk along the floor from M44 to Denebola, Δλ per step
    lm, bm = D["M44_lam"], D["M44_beta"]
    walk = [from_ecl(lm + k*D["dlam"], 0.0) for k in range(0, 14)]
    wx, wy = zip(*walk); ax.plot(wx, wy, color="#ffdd44", lw=2.2, marker="s", ms=4, label=f"C: walk the floor — Δλ={D['dlam']:.2f}°/step, β pinned to 0")
    for k, (x, y) in enumerate(walk):
        if k in (6, 12): ax.annotate(f"step {k}", (x, y), xytext=(0, -12), textcoords="offset points", color="#ffdd44", fontsize=8, ha="center", fontweight="bold")
    # phrase arcs
    for lab, a, b, L in D["phrase"]:
        pa, pb = (R[a]["ra_h"], R[a]["dec_d"]), (R[b]["ra_h"], R[b]["dec_d"])
        ax.annotate("", xy=pb, xytext=pa, arrowprops=dict(arrowstyle="->", color="#ffffff", lw=1.0, alpha=0.5))
        ax.text((pa[0]+pb[0])/2, (pa[1]+pb[1])/2 + 1.0, f"{lab} {L:.1f}°", color="#ffffff", fontsize=7, ha="center", alpha=0.8)
    txt = "Zecliptic steps from M44 (Δλ units):\n" + "\n".join(f"  {n:<11}{v:5.2f}" for n, v in D["lam_steps"].items())
    ax.text(0.985, 0.03, txt, transform=ax.transAxes, color="#aaaacc", fontsize=8, family="monospace", va="bottom", ha="right",
            bbox=dict(boxstyle="round", facecolor="#111133", edgecolor="#333355"))
    ax.legend(loc="upper left", bbox_to_anchor=(0.0, 0.90), fontsize=7.5, facecolor="#111122", edgecolor="#333355", labelcolor="#aaaacc")
    fig.savefig(out, dpi=130, facecolor=BG, bbox_inches="tight"); plt.close(fig)

def view4_strip(rows, mars, jup, out):
    fig, ax = fig_ax(17, 8, "View 4 — The Zecliptic strip: every body by ecliptic longitude λ and latitude β",
                     "The floor is the line β=0. Gemini's feet, Cancer's southern donkey and Regulus sit on it. All three Mars oppositions peak at β≈+3.5…+4.5°.")
    ax.set_xlim(62, 180); ax.set_ylim(-45, 30); ax.set_xlabel("Zecliptic longitude λ (°)", color=DIM); ax.set_ylabel("Zecliptic latitude β (°)", color=DIM)
    ax.axhline(0, color="#2d6b8f", lw=2); ax.axhspan(-5, 5, color="#2d6b8f", alpha=0.10)
    ax.axhline(-7.25, color="#8f6b2d", lw=0.8, ls=":"); ax.text(63, -8.9, "Sol equator offset −7.25° (Zecliptic rule)", color="#8f6b2d", fontsize=7)
    for r in rows:
        if r["kind"] != "star": continue
        col = CONST_COL.get(r["con"], "#999"); s = max(8, 110 - r["mag"]*28)
        ax.scatter(r["lam"], r["beta"], s=s, c=col, zorder=5, edgecolors="k", linewidths=0.3, alpha=0.95 if r["mag"] < 4 else 0.55)
        if r["mag"] < 3.6 or abs(r["beta"]) < 2.5:
            ax.annotate(r["name"], (r["lam"], r["beta"]), xytext=(3, 3), textcoords="offset points", color=col, fontsize=6.8)
    for n, col in [("Mars_2008", "#ff4444"), ("Mars_2025", "#ff7744"), ("Mars_2027", "#ffaa44")]:
        r = next(x for x in rows if x["name"] == n)
        ax.scatter(r["lam"], r["beta"], s=110, c=col, marker="D", zorder=9, edgecolors="white")
        ax.annotate(f"{n}\nβ={r['beta']:+.2f}°", (r["lam"], r["beta"]), xytext=(4, 6), textcoords="offset points", color=col, fontsize=7.5, fontweight="bold")
    px, py = zip(*[(p["lam"], p["beta"]) for p in mars["path"]]); ax.plot(px, py, color="#ffaa44", lw=1, alpha=0.7)
    for jv in jup:
        ax.scatter(jv["lam"], jv["beta"], s=120, c="#ffe9a0", marker="h", zorder=9, edgecolors="white")
        ax.annotate(jv["label"].split(" (")[0].replace("Jupiter_", "J "), (jv["lam"], jv["beta"]), xytext=(4, -10), textcoords="offset points", color="#ffe9a0", fontsize=7)
    # β histogram inset
    ins = ax.inset_axes([0.70, 0.08, 0.28, 0.28]); ins.set_facecolor("#0e0e20")
    betas = [r["beta"] for r in rows if r["kind"] == "star"]
    ins.hist(betas, bins=np.arange(-45, 31, 5), color="#2d6b8f", edgecolor="k")
    ins.axvline(0, color="#4d8bb0"); ins.tick_params(colors="#666699", labelsize=6)
    ins.set_title(f"β of {len(betas)} stars — {sum(abs(b) <= 5 for b in betas)} within ±5° of floor", color=DIM, fontsize=7)
    legend_const(ax, ["CMi", "Ori", "Tau", "Gem", "Cnc", "Leo", "Hya"])
    fig.savefig(out, dpi=130, facecolor=BG, bbox_inches="tight"); plt.close(fig)

def view5_pipe(rows, jup, out):
    stars = [r for r in rows]
    Fs = Counter(r["pipe"]["F"] for r in stars); Gs = Counter(r["pipe"]["G"] for r in stars)
    fig = plt.figure(figsize=(17, 11), facecolor=BG)
    gs = fig.add_gridspec(2, 3, height_ratios=[1.0, 1.6], width_ratios=[1, 1, 1.3], hspace=0.35, wspace=0.25)
    fig.suptitle("View 5 — Star pipe over the extended set (same definition as WINTER_CIRCLE_PIPE_REPORT §II)", color=FG, fontsize=14, y=0.985)
    axF = fig.add_subplot(gs[0, 0]); axF.set_facecolor(BG)
    ks = sorted(Fs); axF.bar(ks, [Fs[k] for k in ks], color="#B8862B", edgecolor="k")
    axF.set_title("F-value distribution  (F = 2·max(L,B), always even)", color=DIM, fontsize=9); axF.set_xticks(ks)
    axG = fig.add_subplot(gs[0, 1]); axG.set_facecolor(BG)
    kg = sorted(Gs); axG.bar(kg, [Gs[k] for k in kg], color="#2d6b8f", edgecolor="k")
    axG.set_title("G (leading digit of round λ) — degenerate: every λ in 100–199 → G=1", color=DIM, fontsize=9); axG.set_xticks(kg)
    axS = fig.add_subplot(gs[0, 2]); axS.set_facecolor(BG)
    selfs = [r for r in stars if r["pipe"]["self_pipe"]]
    axS.axis("off"); axS.set_title(f"Self-pipes (L = B): {len(selfs)} of {len(stars)}", color=DIM, fontsize=9)
    axS.text(0, 0.95, "\n".join(f"{r['name']:<13} λ={r['lam']:6.1f} β={r['beta']:+6.1f}  L=B={r['pipe']['L']}  F={r['pipe']['F']}" for r in selfs),
             transform=axS.transAxes, color="#aaaacc", fontsize=7.5, family="monospace", va="top")
    for a in (axF, axG):
        a.tick_params(colors="#666699", labelsize=8); [s.set_color("#222244") for s in a.spines.values()]
    # Bottom: F-group membership matrix (F rows × constellation columns)
    axM = fig.add_subplot(gs[1, :]); axM.set_facecolor(BG); axM.axis("off")
    cons = ["Tau", "Aur", "Ori", "CMa", "CMi", "Gem", "Cnc", "Leo", "Hya", "Mars"]
    groups = defaultdict(lambda: defaultdict(list))
    for r in stars: groups[r["pipe"]["F"]][r["con"]].append(r["name"])
    Frows = sorted(groups)
    axM.set_xlim(-0.6, len(cons)); axM.set_ylim(len(Frows), -1.0)
    axM.text(-0.6, -0.75, "F-group membership by constellation.  A shared F means shared max(L,B) — the bonds are digit-sum coincidences on rounded λ/β, read as such.",
             color=DIM, fontsize=9, ha="left", va="center")
    for j, c in enumerate(cons):
        axM.text(j + 0.5, -0.2, c, color=CONST_COL.get(c, "#ff8844"), ha="center", fontsize=10, fontweight="bold")
    for i, F in enumerate(Frows):
        axM.text(-0.1, i + 0.5, f"F={F}", color="#B8862B", ha="right", va="center", fontsize=10, fontweight="bold")
        for j, c in enumerate(cons):
            names = groups[F].get(c, [])
            if names:
                axM.add_patch(plt.Rectangle((j, i), 1, 1, facecolor="#1a1a33", edgecolor="#333355"))
                fs = 6.3 if len(names) <= 3 else (5.2 if len(names) <= 5 else 4.4)
                axM.text(j + 0.5, i + 0.5, "\n".join(names), color=CONST_COL.get(c, "#ff8844"), ha="center", va="center", fontsize=fs, linespacing=0.95)
    fig.savefig(out, dpi=130, facecolor=BG, bbox_inches="tight"); plt.close(fig)

def view6_mars_leo(rows, mars, jup, out):
    R = {r["name"]: r for r in rows}
    fig, ax = fig_ax(14, 10, "View 6 — Mars 2027: the Leo landing (computed, PyEphem)",
                     f"Opposition {mars['best']['date']}, mag {mars['best']['mag']:.2f}, {mars['best']['dist_au']:.3f} AU — inside the Sickle. Path Nov 2026 → Jun 2027, 5-day cadence.")
    ax.set_xlim(11.6, 8.6); ax.set_ylim(2, 30); ax.set_xlabel("RA (h)", color=DIM); ax.set_ylabel("Dec (°)", color=DIM)
    draw_zecliptic(ax, 125, 178)
    draw_stars(ax, [r for r in rows if r["kind"] == "star" and 8.6 <= r["ra_h"] <= 11.6 and 2 <= r["dec_d"] <= 30], fs=8)
    def line(names, col, lw=1.3):
        ax.plot([R[n]["ra_h"] for n in names], [R[n]["dec_d"] for n in names], color=col, lw=lw, alpha=0.7, zorder=3)
    line(["Regulus", "η Leo", "Algieba", "Adhafera", "Rasalas", "Ras Elased", "Alterf", "Al Minliar"], CONST_COL["Leo"])
    line(["Regulus", "Chertan", "Denebola", "Zosma", "Algieba"], CONST_COL["Leo"])
    path = mars["path"]
    px, py = zip(*[(p["ra_h"], p["dec_d"]) for p in path])
    ax.plot(px, py, color="#ffaa44", lw=1.8, zorder=8)
    for p in path:
        if p["date"].endswith("/1"):
            ax.scatter(p["ra_h"], p["dec_d"], s=26, c="#ffaa44", zorder=9)
            ax.annotate(p["date"][:7].replace("/", "-"), (p["ra_h"], p["dec_d"]), xytext=(0, 7), textcoords="offset points", color="#ffaa44", fontsize=6.5, ha="center")
    b = mars["best"]; planet_marker(ax, b["ra_h"], b["dec_d"], f"opposition {b['date']}  β={R['Mars_2027']['beta']:+.2f}°", "#ff4444", "D", 130)
    for s_, lab in zip(mars["stations"], ["stationary (retro begins)", "stationary (direct resumes)"]):
        ax.scatter(s_["ra_h"], s_["dec_d"], s=120, facecolors="none", edgecolors="#ffffff", lw=1.2, zorder=10)
        ax.annotate(f"{lab}\n{s_['date']}", (s_["ra_h"], s_["dec_d"]), xytext=(6, -16), textcoords="offset points", color="#ffffff", fontsize=7)
    for jv in jup[1:]:
        planet_marker(ax, jv["ra_h"], jv["dec_d"], jv["label"].split(" (")[0].replace("_", " "), "#ffe9a0", "h", 130)
    near = sorted((sep((b["ra_h"], b["dec_d"]), (r["ra_h"], r["dec_d"])), r["name"]) for r in rows if r["con"] == "Leo")[:5]
    txt = "Mars at opposition — nearest Leo stars:\n" + "\n".join(f"  {n:<11}{s:5.2f}°" for s, n in near)
    txt += "\n\nRegulus passes (Mars RA crosses Regulus RA):\n" + "\n".join(f"  {p['date']}  sep {p['sep_deg']:.2f}°" for p in mars["regulus_passes"])
    p27 = R["Mars_2027"]["pipe"]; txt += f"\n\nstar_pipe(Mars_2027): L={p27['L']} B={p27['B']} F={p27['F']} G={p27['G']}"
    ax.text(0.02, 0.03, txt, transform=ax.transAxes, color="#aaaacc", fontsize=8, family="monospace", va="bottom",
            bbox=dict(boxstyle="round", facecolor="#111133", edgecolor="#333355"))
    fig.savefig(out, dpi=130, facecolor=BG, bbox_inches="tight"); plt.close(fig)

# ─────────────────────────────────────────────────────────────────────────────
# Stats text
# ─────────────────────────────────────────────────────────────────────────────
def stats_text(rows, D, mars, jup):
    R = {r["name"]: r for r in rows}
    stars = [r for r in rows if r["kind"] == "star"]
    L = []
    L.append(f"GEMINI · LEO EXTENSION — {len(stars)} stars/clusters + {len(rows)-len(stars)} Mars events + {len(jup)} Jupiter marks")
    L.append("")
    L.append("ZECLIPTIC LONGITUDE SEQUENCE (bright stars, mag < 2.6, plus floor-sitters)")
    seq = sorted([r for r in stars if r["mag"] < 2.6 or abs(r["beta"]) < 2.5], key=lambda r: r["lam"])
    prev = None
    for r in seq:
        gap = f"Δλ={r['lam']-prev:5.1f}" if prev is not None else "          "
        L.append(f"  λ={r['lam']:6.1f}  β={r['beta']:+6.1f}  {gap}  {r['name']:<13} {r['con']}  {r['role']}")
        prev = r["lam"]
    span = max(r["lam"] for r in stars) - min(r["lam"] for r in stars)
    L.append(f"  sector span: {min(r['lam'] for r in stars):.1f}° → {max(r['lam'] for r in stars):.1f}°  = {span:.1f}° of Zecliptic (prior report: 46.0° for the Circle alone)")
    L.append("")
    floor = sorted([r for r in stars if abs(r["beta"]) <= 2.5], key=lambda r: abs(r["beta"]))
    L.append(f"ON THE FLOOR (|β| ≤ 2.5°): {len(floor)}")
    for r in floor: L.append(f"  {r['name']:<13} β={r['beta']:+.2f}°  λ={r['lam']:.1f}°  {r['con']}")
    L.append(f"  Regulus is the brightest star in the sky within 0.5° of the Zecliptic (β={R['Regulus']['beta']:+.2f}°). The Moon occults it; Mars passes it ~every 2 years.")
    L.append("")
    L.append("MARS OPPOSITIONS IN THIS SECTOR")
    for n in ("Mars_2008", "Mars_2025", "Mars_2027"):
        r = R[n]; near = min((sep((r["ra_h"], r["dec_d"]), (s["ra_h"], s["dec_d"])), s["name"]) for s in stars)
        L.append(f"  {n}  {r['bayer']}  λ={r['lam']:6.2f} β={r['beta']:+.2f}  mag {r['mag']:.2f}  nearest {near[1]} {near[0]:.1f}°  F={r['pipe']['F']} G={r['pipe']['G']}")
    L.append(f"  Mars 2027 stations: {mars['stations'][0]['date']} (RA max) → {mars['stations'][1]['date']} (RA min); retrograde loop inside the Sickle")
    L.append("  Regulus passes: " + "; ".join(f"{p['date']} ({p['sep_deg']:.1f}°)" for p in mars["regulus_passes"]))
    L.append("  β at opposition: +3.51 (2008, Gemini/chest) · +4.29 (2025, Gemini/haunch) · "
             f"{R['Mars_2027']['beta']:+.2f} (2027, Leo/Sickle). Mars orbits 1.85° off the ecliptic; near opposition its β is largest because Earth is closest — geometry, not omen.")
    L.append("")
    L.append("JUPITER")
    for jv in jup:
        near = min((sep((jv["ra_h"], jv["dec_d"]), (s["ra_h"], s["dec_d"])), s["name"]) for s in stars)
        L.append(f"  {jv['label']:<42} RA {jv['ra_h']:.2f}h Dec {jv['dec_d']:+.1f}  λ={jv['lam']:.1f} β={jv['beta']:+.2f}  nearest {near[1]} {near[0]:.1f}°")
    L.append("")
    L.append("DANCE — continuation from M44")
    L.append(f"  step vector (Gomeisa→Procyon): ΔRA={D['step'][0]:+.4f}h  ΔDec={D['step'][1]:+.3f}°;  Zecliptic Δλ={D['dlam']:.2f}°")
    L.append("  A. keep the reflected step past M44:")
    for k, pt, (s, n) in D["optA"]: L.append(f"     step {k:2d}  RA {pt[0]:.2f}h Dec {pt[1]:+.1f}  nearest {n} {s:.1f}°")
    L.append("  B. second slide at M44 (Dec flipped back):")
    for k, pt, (s, n) in D["optB"]: L.append(f"     step {k:2d}  RA {pt[0]:.2f}h Dec {pt[1]:+.1f}  nearest {n} {s:.1f}°")
    L.append("  → Neither A nor B enters Leo. The slide is a Dec-dominant move; Leo lies along λ at β≈0. The phrase changes: from stepping to walking the floor.")
    L.append("  C. walk the floor from M44 in Δλ units (β pinned to 0):")
    for n, v in D["lam_steps"].items(): L.append(f"     {n:<11} {v:5.2f} steps   (β of star {R[n]['beta']:+.2f}°)")
    L.append("  D. phrase lengths 2-1-2-1-2-1:")
    for lab, a, b, Ln in D["phrase"]: L.append(f"     {lab:<12} {a:>10} → {b:<10} {Ln:5.1f}°")
    L.append(f"  twin pairs 2.5°–5.5° apart in the set: {len(D['twins'])}")
    for s, a, b in D["twins"]: L.append(f"     {s:4.2f}°  {a} — {b}")
    L.append("")
    L.append("STRUCTURAL FACTS ABOUT star_pipe (hold for every input)")
    L.append("  T1  F = L + |L−B| + B = 2·max(L,B).  F is always even; an F-group is 'same max digit-sum'. F=14 <=> max(L,B)=7.")
    L.append("      (prior report's 'self-pipe stars have even F' is true but weaker: ALL F are even.)")
    L.append("  T2  G = leading digit of round(λ). For λ in 100–199, G=1 regardless. Gemini/Cancer/Leo all collapse to G=1; G_diff=0 there carries no information.")
    L.append("  T3  L and B are digit sums of ROUNDED degrees; a star 0.5° off changes L by up to 9. The pipe is a coarse hash of position, not a geometric property.")
    L.append("  T4  Self-pipe <=> digit-sum(round λ) ≡ digit-sum(round |β|) (mod 10). Expected rate ≈ 1/10 under independence; "
             f"observed {sum(r['pipe']['self_pipe'] for r in stars)}/{len(stars)}.")
    L.append("")
    L.append("WHAT IS REAL GEOMETRY (independent of any pipe; all numbers computed)")
    sol = from_ecl(90, 0); antic = (5.76, 28.94)
    for n in ("Propus", "Tejat"):
        r = R[n]; L.append(f"  • {n}: {sep((r['ra_h'], r['dec_d']), sol):.1f}° from the June-solstice point (λ=90°), "
                           f"{sep((r['ra_h'], r['dec_d']), antic):.1f}° from the galactic anticenter.")
    fl = sorted([r for r in stars if abs(r["beta"]) <= 0.5], key=lambda r: r["lam"])
    L.append("  • Floor-sitters |β| ≤ 0.5°: " + " → ".join(f"{r['name']} (λ {r['lam']:.1f})" for r in fl)
             + ";  Δλ: " + ", ".join(f"{b['lam']-a['lam']:.1f}°" for a, b in zip(fl, fl[1:])))
    L.append(f"  • Aldebaran (λ {R['Aldebaran']['lam']:.1f}°) and Regulus (λ {R['Regulus']['lam']:.1f}°) — two of the four 'royal stars' — "
             f"bracket this sector {R['Regulus']['lam']-R['Aldebaran']['lam']:.1f}° apart.")
    L.append(f"  • In λ, Regulus sits {R['Regulus']['lam']-R['M44']['lam']:.1f}° past M44 and {R['Denebola']['lam']-R['Regulus']['lam']:.1f}° before Denebola — "
             "the heart is the λ-midpoint of hive and tail to within 1°.")
    ones = [Ln for lab, a, b, Ln in D["phrase"] if lab.startswith("→1")]
    L.append(f"  • The three long legs of the phrase (Procyon→Pollux, M44→Regulus, Algieba→Denebola) are {', '.join(f'{x:.1f}°' for x in ones)} — "
             f"spread {max(ones)-min(ones):.1f}°. Targets were chosen by name, so treat this as a curiosity, not a test.")
    L.append("  • Mars oppositions recur in the same sector every ~15–17 years (2008 Gem → 2025 Gem → 2027 Leo → ~2042 Gem/Cnc est.).")
    L.append("")
    L.append("LEDGER  coordinates: J2000 catalogue values (Hipparcos/SIMBAD-level, ±0.01°). Planets: PyEphem VSOP87 (±1′). Ecliptic transform: exact rotation, ε=23.4393°.")
    L.append("        Dance geometry: linear RA/Dec stepping (as in dance_projection.py) for A/B; exact ecliptic for C. Pipe: digit arithmetic, deterministic.")
    return "\n".join(L)

# ─────────────────────────────────────────────────────────────────────────────
def main():
    rows, mars, jup = build()
    D = dance(rows)
    views = [("ext_view1_field.png", lambda p: view1_field(rows, mars, jup, p)),
             ("ext_view2_gemini.png", lambda p: view2_gemini(rows, jup, p)),
             ("ext_view3_dance_to_leo.png", lambda p: view3_dance(rows, D, p)),
             ("ext_view4_zecliptic_strip.png", lambda p: view4_strip(rows, mars, jup, p)),
             ("ext_view5_pipe.png", lambda p: view5_pipe(rows, jup, p)),
             ("ext_view6_mars_2027_leo.png", lambda p: view6_mars_leo(rows, mars, jup, p))]
    for fn, f in views:
        f(os.path.join(OUT, fn)); print("  wrote", fn)
    txt = stats_text(rows, D, mars, jup)
    with open(os.path.join(OUT, "ext_stats.txt"), "w") as fh: fh.write(txt + "\n")
    # PDF
    from PIL import Image
    with PdfPages(os.path.join(OUT, "gemini_leo_extension.pdf")) as pdf:
        fig, ax = plt.subplots(figsize=(13, 9), facecolor=BG); ax.axis("off")
        ax.text(0.5, 0.80, "Winter Circle → Gemini → Cancer → Leo", ha="center", transform=ax.transAxes, color=FG, fontsize=22, fontweight="bold")
        ax.text(0.5, 0.71, "The extension: other stars, the floor, the Lion, and Mars 2027", ha="center", transform=ax.transAxes, color="#8899bb", fontsize=14)
        ax.text(0.5, 0.63, "Dylan McCapes — October 9, 2026", ha="center", transform=ax.transAxes, color="#556688", fontsize=11)
        cover = ("\n".join(txt.splitlines()[:1]) + "\n\n"
                 "1  The whole sector, RA 4h–12.5h, with the Zecliptic drawn\n"
                 "2  Gemini in full — two bodies standing on the floor\n"
                 "3  The dance continued from M44: what reaches Leo and what does not\n"
                 "4  The Zecliptic strip — λ vs β for every body\n"
                 "5  star_pipe over the extended set, with its structural limits stated\n"
                 "6  Mars 2027 — the Leo landing, computed\n"
                 "7  Statistics and ledger")
        ax.text(0.5, 0.33, cover, ha="center", va="center", transform=ax.transAxes, color="#9999bb", fontsize=10.5, family="monospace",
                bbox=dict(boxstyle="round,pad=0.8", facecolor="#111133", edgecolor="#334455"))
        pdf.savefig(fig, facecolor=BG); plt.close(fig)
        for fn, _ in views:
            img = Image.open(os.path.join(OUT, fn)); w, h = img.size
            fig = plt.figure(figsize=(13, 13*h/w), facecolor=BG); ax = fig.add_axes([0, 0, 1, 1]); ax.axis("off"); ax.imshow(img)
            pdf.savefig(fig, facecolor=BG); plt.close(fig)
        # stats pages (split)
        lines = txt.splitlines(); per = 62
        for i in range(0, len(lines), per):
            fig = plt.figure(figsize=(13, 16.5), facecolor=BG); ax = fig.add_axes([0.03, 0.02, 0.94, 0.96]); ax.axis("off")
            ax.text(0, 1, "\n".join(lines[i:i+per]), transform=ax.transAxes, color="#aaaacc", fontsize=7.6, family="monospace", va="top")
            pdf.savefig(fig, facecolor=BG); plt.close(fig)
    # JSON / JSONL
    data = dict(meta=dict(title="Gemini-Leo extension", date="20261009", epsilon_deg=23.4393, n_rows=len(rows)),
                rows=rows, mars_2027=mars, jupiter=jup,
                dance=dict(step=D["step"].tolist(), dlam=D["dlam"], lam_steps=D["lam_steps"],
                           optA=[(k, list(map(float, pt)), s, n) for k, pt, (s, n) in D["optA"]],
                           optB=[(k, list(map(float, pt)), s, n) for k, pt, (s, n) in D["optB"]],
                           phrase=D["phrase"], twins=D["twins"]))
    with open(os.path.join(OUT, "gemini_leo_extension.json"), "w") as fh: json.dump(data, fh, indent=1, default=float)
    with open(os.path.join(OUT, "gemini_leo_extension.jsonl"), "w") as fh:
        for r in rows: fh.write(json.dumps(r, default=float) + "\n")
    print(txt)

if __name__ == "__main__":
    main()
