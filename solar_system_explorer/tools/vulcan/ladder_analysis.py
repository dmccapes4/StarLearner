#!/usr/bin/env python3
"""
ladder_analysis.py — quantitative test of the id/iv analogy ladder.

The user's derivation is a list of three-term proportions "A is to B is to C",
in mirrored pairs (id = inner/direct, iv = outer/inverse; "id -> iv are the
same backwards"). We do not accept or reject a line by taste: for every line
and every measurable metric m we compute

  H1 geometric  : log m(A)/m(B)  ==  log m(B)/m(C)           (A:B :: B:C)
  H2 mirror-eq  : log m(A)/m(B) [id]  ==  log m(A')/m(B') [iv]
  H3 mirror-inv : log m(A)/m(B) [id]  == -log m(A')/m(B') [iv]   ("same backwards")

Residuals are in dex (log10). |res| < 0.30 dex (factor 2) is counted as the
line HOLDING in that metric; < 0.10 dex (26 %) is a STRONG hold.

Planet X is then solved from "iv Planet X is to Saturn is to Neptune"
(mirror of "id Mars is to Jupiter is to Sol") under H1/H2/H3 for each
metric; the semi-major axis and period predicted independently are checked
against Kepler III (T^2 = a^3 in yr/AU) — the ladder's own self-consistency
test — and against the Titius–Bode slot, the Kuiper cliff and the
Planet-Nine estimates.

Outputs: data/ladder_analysis.json, data/ladder_table.md, img/ladder_*.png
"""
import os, json, math, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bodies import derive, AU_KM, YEAR_D, G, M_SUN
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
plt.rcParams.update({"figure.facecolor":"#0b0d17","axes.facecolor":"#0b0d17","axes.edgecolor":"#667","axes.labelcolor":"#dde",
    "xtick.color":"#bbc","ytick.color":"#bbc","text.color":"#eef","grid.color":"#223","legend.facecolor":"#141829","legend.edgecolor":"#445"})

HERE = os.path.dirname(os.path.abspath(__file__))
DOC  = os.path.abspath(os.path.join(HERE, "..", "..", "docs", "MERCURY_VULCAN_LADDER_20261010"))
DATA = os.path.join(DOC, "data"); IMG = os.path.join(DOC, "img"); os.makedirs(IMG, exist_ok=True)
B = derive()

def kep_T_yr(a_au, m_total=M_SUN): return math.sqrt((a_au*AU_KM*1e3)**3*4*math.pi**2/(G*m_total))/86400/YEAR_D

# ---------------------------------------------------------------------------
# Entity table: every token in the ladder -> metrics.  Composite entities are
# defined explicitly (what "mass" / "a" / "T" means for a pair, a belt, a ring).
# a_au: heliocentric semi-major axis of the entity (moons/rings use their primary's)
# a_local_km: semi-major axis about its own primary (moons/rings) or heliocentric (planets)
# ---------------------------------------------------------------------------
def ent(name, mass, r_km, a_au, T_yr, rot_d=None, rho=None, a_local_km=None, note=""):
    return dict(name=name, mass_kg=mass, radius_km=r_km, a_au=a_au, period_yr=T_yr, rot_d=rot_d, density=rho,
                a_local_km=a_local_km if a_local_km is not None else (a_au*AU_KM if a_au else None), note=note)
E = {}
for k in ("sol","mercury","venus","earth","mars","jupiter","saturn","uranus","neptune","pluto"):
    b = B[k]
    E[k] = ent(b["name"], b["mass_kg"], b["r_mean_km"], b.get("a_au") or None, (b["period_d"]/YEAR_D) if b.get("period_d") else None,
               b.get("rot_d"), b.get("density"))
E["sol"]["a_au"] = None; E["sol"]["period_yr"] = None; E["sol"]["a_local_km"] = None
E["luna"] = ent("Luna", B["luna"]["mass_kg"], B["luna"]["r_mean_km"], 1.0, B["luna"]["period_d"]/YEAR_D, B["luna"]["rot_d"], B["luna"]["density"], B["luna"]["a_km"])
E["ab"] = ent("Asteroid Belt", B["asteroid_belt"]["mass_kg"], (3.27-2.06)/2*AU_KM, 2.70, 4.60, B["ceres"]["rot_d"], B["ceres"]["density"],
              note="radius = half the annulus width; rotation/density = Ceres")
E["hb"] = ent("Heliobarrier", None, 121.6*AU_KM, 121.6, kep_T_yr(121.6), None, None, note="heliopause radius (V1); period = Kepler at 121.6 AU; no mass")
E["pluto_charon"] = ent("Pluto/Charon", B["pluto"]["mass_kg"]+B["charon"]["mass_kg"], B["pluto"]["r_mean_km"], B["pluto"]["a_au"], B["pluto"]["period_d"]/YEAR_D,
                        B["charon"]["period_d"], B["pluto"]["density"], note="binary as one body; rot = mutual lock period")
E["earth_luna"] = ent("Earth/Luna", B["earth"]["mass_kg"]+B["luna"]["mass_kg"], B["earth"]["r_mean_km"], 1.0, 1.0, B["luna"]["period_d"], B["earth"]["density"], note="rot = lunar month")
E["mercury_vulcan"] = ent("Mercury/Vulcan", B["mercury"]["mass_kg"], B["mercury"]["r_mean_km"], B["mercury"]["a_au"], B["mercury"]["period_d"]/YEAR_D, B["mercury"]["rot_d"], B["mercury"]["density"],
                          note="Vulcan mass unknown -> Mercury alone; rot = Mercury spin (candidate lock period)")
E["saturn_rings"] = ent("Saturn rings", B["saturn"]["ring_mass_kg"], (B["saturn"]["ring_outer_km"]-B["saturn"]["ring_inner_km"])/2, B["saturn"]["a_au"], B["saturn"]["period_d"]/YEAR_D,
                        None, 400.0, (B["saturn"]["ring_outer_km"]+B["saturn"]["ring_inner_km"])/2, note="mass Iess+2019; radius = half ring span; local a = ring mid-radius")
E["uranus_rings"] = ent("Uranus rings", B["uranus"]["ring_mass_kg"], 50.0, B["uranus"]["a_au"], B["uranus"]["period_d"]/YEAR_D, None, 1000.0, 51149.0, note="epsilon ring: a=51,149 km, width ~50 km; mass estimate only")
E["mars_moons"] = ent("Mars moons", B["mars"]["moons_total_mass_kg"], B["phobos"]["r_mean_km"], B["mars"]["a_au"], B["mars"]["period_d"]/YEAR_D, B["phobos"]["rot_d"], B["phobos"]["density"], B["phobos"]["a_km"], note="Phobos+Deimos mass; Phobos geometry")
E["sol_jupiter"] = ent("Sol/Jupiter", B["sol"]["mass_kg"]+B["jupiter"]["mass_kg"], B["sol"]["r_mean_km"], B["jupiter"]["a_au"], B["jupiter"]["period_d"]/YEAR_D, B["sol"]["rot_d"], B["sol"]["density"], B["jupiter"]["a_au"]*AU_KM)
E["planet_x"] = ent("Planet X", None, None, None, None, None, None, note="unknown; solved below")

METRICS = ["mass_kg", "radius_km", "a_au", "period_yr", "rot_d", "density", "a_local_km"]
MLABEL  = {"mass_kg":"mass", "radius_km":"radius", "a_au":"a (helio)", "period_yr":"T (helio)", "rot_d":"rotation", "density":"density", "a_local_km":"a (local)"}

# ---------------------------------------------------------------------------
# The ladder, verbatim order.  (id, iv) pairs; the three trailing lines are singletons.
# ---------------------------------------------------------------------------
LADDER = [
 ("id", ("sol","jupiter","mars"),                    "iv", ("neptune","saturn","pluto_charon")),
 ("id", ("mercury_vulcan","ab","earth_luna"),        "iv", ("pluto_charon","hb","uranus")),
 ("id", ("venus","sol","jupiter"),                   "iv", ("saturn","jupiter","neptune")),
 ("id", ("earth","ab","luna"),                       "iv", ("uranus","hb","uranus_rings")),
 ("id", ("sol","jupiter","venus"),                   "iv", ("neptune","jupiter","saturn")),
 ("id", ("ab","mars","mercury_vulcan"),              "iv", ("hb","neptune","pluto_charon")),
 ("id", ("mars","jupiter","sol"),                    "iv", ("planet_x","saturn","neptune")),
 ("id", ("earth","luna","mercury_vulcan"),           "iv", ("uranus","uranus_rings","pluto_charon")),
]
SINGLES = [("ab","hb","sol"), ("sol","hb","ab")]
CHAIN = ["sol_jupiter","pluto_charon","earth_luna","saturn_rings","mercury_vulcan","mars_moons"]
CHAIN_PAIRS = {  # secondary/primary for the final chain (mass ratio, separation in primary radii, period of secondary d)
 "sol_jupiter":   (B["jupiter"]["mass_kg"]/B["sol"]["mass_kg"], B["jupiter"]["a_au"]*AU_KM/B["sol"]["r_mean_km"], B["jupiter"]["period_d"]),
 "pluto_charon":  (B["charon"]["mass_ratio_to_primary"], B["charon"]["separation_primary_radii"], B["charon"]["period_d"]),
 "earth_luna":    (B["luna"]["mass_ratio_to_primary"], B["luna"]["separation_primary_radii"], B["luna"]["period_d"]),
 "saturn_rings":  (B["saturn"]["ring_to_primary_mass_ratio"], (B["saturn"]["ring_outer_km"]+B["saturn"]["ring_inner_km"])/2/B["saturn"]["r_mean_km"],
                   kep := 2*math.pi*math.sqrt(((B["saturn"]["ring_outer_km"]+B["saturn"]["ring_inner_km"])/2*1e3)**3/(G*B["saturn"]["mass_kg"]))/86400),
 "mercury_vulcan": (None, None, None),
 "mars_moons":    (B["mars"]["moons_to_primary_mass_ratio"], B["phobos"]["separation_primary_radii"], B["phobos"]["period_d"]),
}

def lg(x):
    return math.log10(abs(x)) if (x is not None and x != 0) else None
def ratio_dex(a, b, m):
    va, vb = E[a].get(m), E[b].get(m)
    if lg(va) is None or lg(vb) is None: return None
    return lg(va) - lg(vb)

RES = []
for tag1, t1, tag2, t2 in LADDER:
    row = dict(id=t1, iv=t2, metrics={})
    for m in METRICS:
        r1 = ratio_dex(t1[0], t1[1], m); r2 = ratio_dex(t1[1], t1[2], m)
        s1 = ratio_dex(t2[0], t2[1], m); s2 = ratio_dex(t2[1], t2[2], m)
        row["metrics"][m] = dict(
            id_AB=r1, id_BC=r2, iv_AB=s1, iv_BC=s2,
            H1_id=(r1-r2) if (r1 is not None and r2 is not None) else None,
            H1_iv=(s1-s2) if (s1 is not None and s2 is not None) else None,
            H2_mirror_eq=(r1-s1) if (r1 is not None and s1 is not None) else None,
            H3_mirror_inv=(r1+s1) if (r1 is not None and s1 is not None) else None)
    RES.append(row)

def holds(v, strong=False):
    if v is None: return None
    return abs(v) < (0.10 if strong else 0.30)

SUMMARY = []
for row in RES:
    for m in METRICS:
        d = row["metrics"][m]
        for h in ("H1_id","H1_iv","H2_mirror_eq","H3_mirror_inv"):
            if d[h] is not None and holds(d[h]):
                SUMMARY.append(dict(id=" : ".join(E[x]["name"] for x in row["id"]), iv=" : ".join(E[x]["name"] for x in row["iv"]),
                                    metric=MLABEL[m], hypothesis=h, residual_dex=round(d[h],3), strong=holds(d[h], True)))

# Singletons: AB:HB:Sol and Sol:HB:AB (radius / a / period only — HB has no mass)
SING = []
for t in SINGLES:
    for m in ("radius_km","a_au","period_yr"):
        r1 = ratio_dex(t[0], t[1], m); r2 = ratio_dex(t[1], t[2], m)
        SING.append(dict(triple=" : ".join(E[x]["name"] for x in t), metric=MLABEL[m], AB=r1, BC=r2, H1=(r1-r2) if (r1 is not None and r2 is not None) else None))

# ---------------------------------------------------------------------------
# Planet X
# ---------------------------------------------------------------------------
PX = {}
for m in METRICS:
    sat, nep, mars, jup = (E["saturn"].get(m), E["neptune"].get(m), E["mars"].get(m), E["jupiter"].get(m))
    if None in (sat, nep, mars, jup): continue
    PX[m] = dict(H1_geometric=sat*sat/nep, H2_mirror_eq=sat*mars/jup, H3_mirror_inv=sat*jup/mars)
# Kepler self-consistency of (a, T) under each hypothesis
KEP = {}
for h in ("H1_geometric","H2_mirror_eq","H3_mirror_inv"):
    a = PX["a_au"][h]; T = PX["period_yr"][h]
    KEP[h] = dict(a_au=a, T_yr=T, T_from_a_kepler_yr=kep_T_yr(a), a_from_T_kepler_au=T**(2/3), kepler_residual_dex=math.log10(T/kep_T_yr(a)))
# What the a^-2.5 / Kepler-consistent choice gives:  take a from H3 (only a > Neptune), T from Kepler
PX_BEST = {}
for h in KEP:
    a = KEP[h]["a_au"]
    PX_BEST[h] = dict(a_au=a, T_kepler_yr=kep_T_yr(a), mass_kg=PX["mass_kg"][h], mass_earth=PX["mass_kg"][h]/B["earth"]["mass_kg"],
                      radius_km=PX["radius_km"][h], density=PX["density"][h], rot_d=PX["rot_d"][h],
                      beyond_neptune=a > 30.07, inside_kuiper_cliff=a < 48.0,
                      titius_bode_slot_au=77.2, planet_nine_2021=dict(mass_earth=6.2, a_au=380.0, source="Brown & Batygin 2021"),
                      apparent_mag_estimate_V=None)
# crude V magnitude at opposition for a body of radius R at distance a (albedo 0.5):  H from diameter, then m = H + 5 log10(a (a-1))
for h,v in PX_BEST.items():
    if v["radius_km"] and v["a_au"] and v["a_au"] > 1.5:
        D_km = 2*v["radius_km"]; p = 0.5
        H = 5*math.log10(1329/(D_km*math.sqrt(p)))
        v["apparent_mag_estimate_V"] = H + 5*math.log10(v["a_au"]*(v["a_au"]-1))
        v["mag_note"] = "Pan-STARRS/ZTF/ATLAS complete to V~21-22 over most of the sky; LSST ~24.5"

# ---------------------------------------------------------------------------
# Final chain: Sol/Jupiter : Pluto/Charon : Earth/Luna : Saturn/rings : Mercury/Vulcan : Mars/moons
# ---------------------------------------------------------------------------
CH = []
for k in CHAIN:
    q, s, T = CHAIN_PAIRS[k]
    CH.append(dict(pair=E[k]["name"], mass_ratio=q, separation_primary_radii=s, secondary_period_d=T,
                   log_q=(math.log10(q) if q else None)))
# interpolate Mercury/Vulcan from neighbours (Saturn/rings, Mars/moons) in log space
qs = [c["log_q"] for c in CH if c["log_q"] is not None]
i_mv = CHAIN.index("mercury_vulcan")
q_prev = CH[i_mv-1]["log_q"]; q_next = CH[i_mv+1]["log_q"]
CH[i_mv]["mass_ratio_interpolated"] = 10**((q_prev+q_next)/2)
CH[i_mv]["vulcan_mass_kg_interpolated"] = CH[i_mv]["mass_ratio_interpolated"]*B["mercury"]["mass_kg"]
s_prev = CH[i_mv-1]["separation_primary_radii"]; s_next = CH[i_mv+1]["separation_primary_radii"]
CH[i_mv]["separation_R_M_interpolated"] = math.sqrt(s_prev*s_next)
CH[i_mv]["separation_km_interpolated"] = CH[i_mv]["separation_R_M_interpolated"]*B["mercury"]["r_mean_km"]
# monotonic test of the chain in log q
CH_MONO = all(qs[i] >= qs[i+1] for i in range(len(qs)-1))

# ---------------------------------------------------------------------------
# PLOTS
# ---------------------------------------------------------------------------
# Heatmap of residuals for each hypothesis
hyps = ["H1_id","H1_iv","H2_mirror_eq","H3_mirror_inv"]
fig, axs = plt.subplots(1, 4, figsize=(20, 7), sharey=True)
ylabels = [f"id {' : '.join(E[x]['name'] for x in r['id'])}\niv {' : '.join(E[x]['name'] for x in r['iv'])}" for r in RES]
for ax, h in zip(axs, hyps):
    grid = np.full((len(RES), len(METRICS)), np.nan)
    for i,r in enumerate(RES):
        for j,m in enumerate(METRICS):
            v = r["metrics"][m][h]
            if v is not None: grid[i,j] = abs(v)
    im = ax.imshow(grid, cmap="RdYlGn_r", vmin=0, vmax=3, aspect="auto")
    for i in range(len(RES)):
        for j in range(len(METRICS)):
            if not np.isnan(grid[i,j]):
                ax.text(j, i, f"{grid[i,j]:.2f}", ha="center", va="center", fontsize=8, color="#000" if grid[i,j] < 1.8 else "#fff",
                        fontweight="bold" if grid[i,j] < 0.3 else "normal")
    ax.set_xticks(range(len(METRICS))); ax.set_xticklabels([MLABEL[m] for m in METRICS], rotation=40, ha="right", fontsize=9)
    ax.set_title({"H1_id":"H1 geometric (id line)\nA:B :: B:C","H1_iv":"H1 geometric (iv line)","H2_mirror_eq":"H2 mirror-equal\nid A/B == iv A/B","H3_mirror_inv":"H3 mirror-inverse\nid A/B == iv B/A"}[h], fontsize=10)
axs[0].set_yticks(range(len(RES))); axs[0].set_yticklabels(ylabels, fontsize=8)
cb = fig.colorbar(im, ax=axs, fraction=0.015, pad=0.01); cb.set_label("|residual| (dex). < 0.30 = holds (bold)")
fig.suptitle("The id/iv ladder tested metric by metric — residuals in dex (0 = exact proportion)", fontsize=13)
fig.savefig(os.path.join(IMG, "ladder_01_residual_heatmap.png"), dpi=120, bbox_inches="tight"); plt.close(fig)

# Final chain plot
fig, ax = plt.subplots(figsize=(11,5.5))
xs = np.arange(len(CH)); cols = ["#ffd166","#c9a7ff","#4fd1ff","#ffb347","#ff5c7a","#9dff6a"]
for i,c in enumerate(CH):
    if c["log_q"] is not None:
        ax.bar(i, 10**c["log_q"], color=cols[i], width=0.6); ax.text(i, 10**c["log_q"]*1.6, f"{10**c['log_q']:.2e}", ha="center", fontsize=9, color=cols[i])
    else:
        q_int = c["mass_ratio_interpolated"]; ax.bar(i, q_int, color="none", edgecolor=cols[i], hatch="//", width=0.6)
        ax.text(i, q_int*1.6, f"interp.\n{q_int:.2e}\n→ M_V={c['vulcan_mass_kg_interpolated']:.2e} kg", ha="center", fontsize=9, color=cols[i])
ax.set_yscale("log"); ax.set_ylim(1e-9, 1); ax.set_xticks(xs); ax.set_xticklabels([c["pair"] for c in CH], fontsize=10)
ax.set_ylabel("secondary / primary mass ratio (log)"); ax.grid(True, which="both", axis="y")
ax.set_title(f"Final chain: secondary/primary mass ratio in the user's order (monotone decreasing: {CH_MONO}) — Mercury/Vulcan interpolated")
fig.tight_layout(); fig.savefig(os.path.join(IMG, "ladder_02_final_chain_mass_ratio.png"), dpi=130); plt.close(fig)

# Planet X plot: (a, T) predictions vs Kepler
fig, ax = plt.subplots(figsize=(10,6))
aa = np.logspace(-0.5, 3, 200); ax.plot(aa, aa**1.5, color="#9dff6a", lw=1.5, label="Kepler III  T = a^1.5 (yr, AU)")
for k in ("mercury","venus","earth","mars","jupiter","saturn","uranus","neptune","pluto"):
    ax.plot(E[k]["a_au"], E[k]["period_yr"], "o", color="#dde", ms=5); ax.text(E[k]["a_au"]*1.08, E[k]["period_yr"], E[k]["name"], fontsize=8)
mk = {"H1_geometric":("s","#ff5c7a"),"H2_mirror_eq":("^","#4fd1ff"),"H3_mirror_inv":("D","#ffb347")}
for h,v in KEP.items():
    ax.plot(v["a_au"], v["T_yr"], mk[h][0], color=mk[h][1], ms=11, label=f"Planet X {h}: a={v['a_au']:.1f} AU, T={v['T_yr']:.1f} yr (Kepler residual {v['kepler_residual_dex']:+.2f} dex)")
    ax.plot([v["a_au"], v["a_au"]], [v["T_yr"], v["T_from_a_kepler_yr"]], ":", color=mk[h][1], lw=1)
ax.axvline(77.2, color="#c9a7ff", ls="--", lw=1, label="Titius–Bode next slot 77.2 AU"); ax.axvline(380, color="#aaa", ls=":", lw=1, label="Planet Nine (Brown & Batygin 2021) a≈380 AU")
ax.axvspan(30, 48, color="#4fd1ff", alpha=0.07); ax.text(33, 0.6, "Kuiper belt", fontsize=8, color="#9fe")
ax.set_xscale("log"); ax.set_yscale("log"); ax.set_xlabel("a (AU)"); ax.set_ylabel("T (yr)"); ax.grid(True, which="both")
ax.set_title("Planet X from 'Planet X is to Saturn is to Neptune' — three readings, tested against Kepler III"); ax.legend(fontsize=8, loc="upper left")
fig.tight_layout(); fig.savefig(os.path.join(IMG, "ladder_03_planet_x_kepler_test.png"), dpi=130); plt.close(fig)

OUT = dict(method=__doc__, entities=E, ladder_results=RES, holds_summary=SUMMARY, singletons=SING,
           planet_x_raw=PX, planet_x_kepler=KEP, planet_x_candidates=PX_BEST, final_chain=CH, final_chain_monotone=CH_MONO)
with open(os.path.join(DATA, "ladder_analysis.json"), "w") as f: json.dump(OUT, f, indent=1, default=str)

# Markdown table
md = ["# Ladder test — residuals (dex)\n", "Each line: id triple | iv triple | metric | H1(id) | H1(iv) | H2 mirror-eq | H3 mirror-inv.  Bold = |res| < 0.30 dex.\n",
      "| id | iv | metric | H1 id | H1 iv | H2 eq | H3 inv |", "|---|---|---|---|---|---|---|"]
def fm(v): return "" if v is None else (f"**{v:+.2f}**" if abs(v) < 0.30 else f"{v:+.2f}")
for r in RES:
    for m in METRICS:
        d = r["metrics"][m]
        if all(d[h] is None for h in hyps): continue
        md.append(f"| {' : '.join(E[x]['name'] for x in r['id'])} | {' : '.join(E[x]['name'] for x in r['iv'])} | {MLABEL[m]} | {fm(d['H1_id'])} | {fm(d['H1_iv'])} | {fm(d['H2_mirror_eq'])} | {fm(d['H3_mirror_inv'])} |")
md += ["\n## Singletons\n", "| triple | metric | log A/B | log B/C | H1 |", "|---|---|---|---|---|"]
for s in SING: md.append(f"| {s['triple']} | {s['metric']} | {fm(s['AB']) if s['AB'] is not None else ''} | {fm(s['BC']) if s['BC'] is not None else ''} | {fm(s['H1'])} |")
md += ["\n## Planet X\n", "| reading | a (AU) | T (yr) | T from Kepler(a) | Kepler residual (dex) | mass (M⊕) | radius (km) | V mag @opp |", "|---|---|---|---|---|---|---|---|"]
for h,v in PX_BEST.items():
    k = KEP[h]; md.append(f"| {h} | {v['a_au']:.2f} | {k['T_yr']:.2f} | {k['T_from_a_kepler_yr']:.2f} | {k['kepler_residual_dex']:+.2f} | {v['mass_earth']:.2f} | {v['radius_km']:.0f} | {v['apparent_mag_estimate_V'] if v['apparent_mag_estimate_V'] is None else round(v['apparent_mag_estimate_V'],1)} |")
md += ["\n## Final chain (secondary/primary)\n", "| pair | mass ratio | separation (R_primary) | secondary period (d) |", "|---|---|---|---|"]
for c in CH:
    md.append(f"| {c['pair']} | {c['mass_ratio'] if c['mass_ratio'] is None else f'{c['mass_ratio']:.3e}'} | {c['separation_primary_radii'] if c['separation_primary_radii'] is None else f'{c['separation_primary_radii']:.1f}'} | {c['secondary_period_d'] if c['secondary_period_d'] is None else f'{c['secondary_period_d']:.3f}'} |")
md.append(f"\nMercury/Vulcan interpolated from neighbours: q = {CH[i_mv]['mass_ratio_interpolated']:.3e} → M_V = {CH[i_mv]['vulcan_mass_kg_interpolated']:.3e} kg; a = {CH[i_mv]['separation_R_M_interpolated']:.1f} R_M = {CH[i_mv]['separation_km_interpolated']:,.0f} km. Chain monotone in q: {CH_MONO}.")
with open(os.path.join(DATA, "ladder_table.md"), "w") as f: f.write("\n".join(md)+"\n")

print(f"{len(SUMMARY)} (line, metric, hypothesis) combinations hold (<0.30 dex); strong: {sum(1 for s in SUMMARY if s['strong'])}")
for s in SUMMARY: print(f"  {'*' if s['strong'] else ' '} {s['hypothesis']:14s} {s['metric']:10s} {s['residual_dex']:+.3f}  id[{s['id']}]  iv[{s['iv']}]")
print("SINGLETONS:"); [print("  ", s) for s in SING]
print("PLANET X:"); [print("  ", h, {k:(round(v,3) if isinstance(v,float) else v) for k,v in d.items() if k in ('a_au','T_kepler_yr','mass_earth','radius_km','apparent_mag_estimate_V','beyond_neptune')}) for h,d in PX_BEST.items()]
print("KEPLER:", {h: round(v["kepler_residual_dex"],3) for h,v in KEP.items()})
print("CHAIN:", [(c["pair"], c["log_q"]) for c in CH], "monotone:", CH_MONO)
print("Mercury/Vulcan interp:", CH[i_mv]["mass_ratio_interpolated"], CH[i_mv]["vulcan_mass_kg_interpolated"], CH[i_mv]["separation_km_interpolated"])
