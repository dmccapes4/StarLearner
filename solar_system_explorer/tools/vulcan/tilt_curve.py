#!/usr/bin/env python3
"""The tilt curve: spin-axis tilt to the Zecliptic against the companion's Pis.

Operator (2026-10-11 02:36): "0 is Sol center. 42 is Earth/Luna 23.5 then Zecliptic. 180 is Pluto/Charon
then angle to Zecliptic."  Also: re-measure distances with 1 AU := Sol's radius ("centre of Sol to the
bubbling surface"); the badminton-birdie question (which way do the axes lean); and the Zecliptic's
displacement from the solar system's normal (the invariable plane).

Spin poles are the IAU 2015 J2000 values (Archinal et al. 2018) — a literal table, sourced below, because
bodies_metrics.json only carries obliquity-to-own-orbit.  Everything else is pulled from data/*.json.
Writes data/tilt_curve.json, img/tilt_curve.png, img/pole_azimuths.png and TILT_CURVE_20261011.md.
"""
import json, math, os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
DOC = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "MERCURY_VULCAN_LADDER_20261010"))
B = json.load(open(os.path.join(DOC, "data", "bodies_metrics.json")))
PI = json.load(open(os.path.join(DOC, "data", "pis.json")))
V = json.load(open(os.path.join(DOC, "data", "vulcan_derivation.json")))
A = json.load(open(os.path.join(DOC, "data", "v4_annulus.json")))

d2r, r2d = math.radians, math.degrees
OBLIQ = 23.439291                                  # J2000 obliquity, equatorial -> ecliptic
# IAU WG on Cartographic Coordinates and Rotational Elements, 2015 report (Archinal et al. 2018), J2000 north poles (RA, Dec), deg
IAU_POLE = {
    "sol": (286.13, 63.87), "mercury": (281.0097, 61.4143), "venus": (272.76, 67.16), "earth": (0.0, 90.0),
    "mars": (317.68143, 52.88650), "jupiter": (268.056595, 64.495303), "saturn": (40.589, 83.537),
    "uranus": (257.311, -15.175), "neptune": (299.36, 43.46), "pluto": (132.993, -6.163),
}
# invariable plane (total angular momentum normal), J2000 ecliptic: Souami & Souchay 2012, A&A 543 A133
INV_I, INV_NODE = 1.5787, 107.5822
SE_I, SE_NODE = B["sol"]["obliquity_deg"], 75.76  # solar equator (Carrington), node from bodies_metrics 'sol' note
AU_KM = 1.495978707e8
R_SOL = B["sol"]["r_eq_km"]
LIT = {"iau_poles": "IAU WG 2015 report (Archinal et al. 2018), J2000 RA/Dec of north poles",
       "invariable_plane": f"i {INV_I}°, node {INV_NODE}° (Souami & Souchay 2012)",
       "obliquity_j2000": OBLIQ, "au_km": AU_KM, "solar_node_deg": SE_NODE}


def radec_to_ecl(ra, dec):
    ra, dec = d2r(ra), d2r(dec)
    eq = np.array([math.cos(dec) * math.cos(ra), math.cos(dec) * math.sin(ra), math.sin(dec)])
    e = d2r(OBLIQ)
    R = np.array([[1, 0, 0], [0, math.cos(e), math.sin(e)], [0, -math.sin(e), math.cos(e)]])
    return R @ eq


def pole_from_elements(i_deg, node_deg):
    i, O = d2r(i_deg), d2r(node_deg)
    return np.array([math.sin(i) * math.sin(O), -math.sin(i) * math.cos(O), math.cos(i)])


def ang(u, v):
    return r2d(math.acos(np.clip(np.dot(u, v) / np.linalg.norm(u) / np.linalg.norm(v), -1, 1)))


SOL_POLE_EL = pole_from_elements(SE_I, SE_NODE)
SOL_POLE_IAU = radec_to_ecl(*IAU_POLE["sol"])
ZX = np.array([math.cos(d2r(SE_NODE)), math.sin(d2r(SE_NODE)), 0.0])   # Zecliptic x: solar equator's ascending node
ZZ = SOL_POLE_EL
ZY = np.cross(ZZ, ZX)
INV_POLE = pole_from_elements(INV_I, INV_NODE)


def zecliptic_tilt_and_azimuth(pole):
    """tilt from Sol's pole, and the Zecliptic longitude toward which the pole leans (0 = solar node direction)."""
    tilt = ang(pole, ZZ)
    horiz = pole - np.dot(pole, ZZ) * ZZ
    az = r2d(math.atan2(np.dot(horiz, ZY), np.dot(horiz, ZX))) % 360 if np.linalg.norm(horiz) > 1e-9 else None
    return tilt, az


out = {"literals": LIT, "frame_check": {}, "bodies": {}, "curve": {}, "distances_in_solar_radii": {}, "normal": {}}
out["frame_check"]["solar_pole_elements_vs_iau_deg"] = ang(SOL_POLE_EL, SOL_POLE_IAU)

# ------------------------------------------------------------------ tilts
PAIRS = {  # planet -> principal companion for the x-axis (Pis per Earth year, from pis.json)
    "mercury": None, "venus": None, "earth": "luna", "mars": "phobos", "jupiter": "ganymede",
    "saturn": "titan", "uranus": "titania", "neptune": "triton", "pluto": "charon"}
# IAU lists planets' poles on the north side of the invariable plane regardless of spin sense; dwarf planets by the
# right-hand rule. For an *axial tilt* the spin sense must count, so Venus and Uranus (retrograde spinners) are flipped
# to their right-hand-rule poles here. Pluto's IAU pole is already right-hand-rule.
RIGHT_HAND_FLIP = ("venus", "uranus")
for k, (ra, dec) in IAU_POLE.items():
    p = radec_to_ecl(ra, dec)
    if k in RIGHT_HAND_FLIP:
        p = -p
    tilt, az = zecliptic_tilt_and_azimuth(p)
    if k == "sol":
        az = None
    row = {"pole_radec": [ra, dec], "right_hand_rule_flipped": k in RIGHT_HAND_FLIP,
           "spin_tilt_to_zecliptic_deg": tilt, "lean_azimuth_zecliptic_deg": az,
           "obliquity_to_own_orbit_deg": B[k].get("obliquity_deg") if k != "sol" else None,
           "tilt_to_ecliptic_pole_deg": ang(p, np.array([0, 0, 1.0])),
           "tilt_to_invariable_pole_deg": ang(p, INV_POLE)}
    if k != "sol":
        inc_z = PI["zecliptic"].get(k, {}).get("i_zecliptic_deg")
        row["orbit_i_to_zecliptic_deg"] = inc_z
        comp = PAIRS[k]
        if comp:
            row["companion"] = comp
            row["companion_pis_per_earth_year"] = PI["moons"][comp]["pis_per_earth_year"]
            row["all_moons_pis"] = {m: PI["moons"][m]["pis_per_earth_year"] for m in PI["moons"] if PI["moons"][m]["primary"] == k}
        # perihelion direction in the Zecliptic frame, to compare lean with where the planet is closest to Sol
        if B[k].get("omega_node_deg") is not None and B[k].get("i_ecl_deg") is not None:
            row["node_ecl_deg"] = B[k]["omega_node_deg"]
    out["bodies"][k] = row

# ------------------------------------------------------------------ the curve
# anchors the operator named: Sol (0, 0), Earth/Luna (42, tilt), Pluto/Charon (180, tilt)
xE, yE = PI["moons"]["luna"]["pis_per_earth_year"], out["bodies"]["earth"]["spin_tilt_to_zecliptic_deg"]
xP, yP = PI["moons"]["charon"]["pis_per_earth_year"], out["bodies"]["pluto"]["spin_tilt_to_zecliptic_deg"]
yM = out["bodies"]["mercury"]["spin_tilt_to_zecliptic_deg"]
# fit 1: power law through the origin, y = a x^b, exact through the two anchors
b_pow = math.log(yP / yE) / math.log(xP / xE); a_pow = yE / xE ** b_pow
# fit 2: linear through the origin, least squares on the two anchors
k_lin = (xE * yE + xP * yP) / (xE ** 2 + xP ** 2)
# fit 3: quadratic through the origin, exact through both anchors
M = np.array([[xE, xE ** 2], [xP, xP ** 2]]); c1, c2 = np.linalg.solve(M, [yE, yP])


def inv_pow(y): return (y / a_pow) ** (1 / b_pow)
def inv_lin(y): return y / k_lin
def inv_quad(y):
    r = np.roots([c2, c1, -y]); r = r[np.isreal(r)].real; r = r[r > 0]; return float(r.min()) if len(r) else None


GM = V["mercury"]["GM_m3s2"]; R_HILL = A["constants"]["R_hill_perihelion_km"]; ann = A["annulus"]
YEAR_D = 365.25636


def a_km_from_pis(pis, year_d=YEAR_D):
    P = year_d / (pis / math.pi) * 86400
    return (GM * P ** 2 / (4 * math.pi ** 2)) ** (1 / 3) / 1e3


pred = {}
for name, f in (("power", inv_pow), ("linear", inv_lin), ("quadratic", inv_quad)):
    x = f(yM)
    pred[name] = {"vulcan_pis_per_earth_year": x, "a_km_earth_year_frame": a_km_from_pis(x),
                  "a_over_R_hill": a_km_from_pis(x) / R_HILL,
                  "a_km_mercury_year_frame": a_km_from_pis(x, V["mercury"]["orbit_d"]),
                  "a_over_R_hill_mercury_year_frame": a_km_from_pis(x, V["mercury"]["orbit_d"]) / R_HILL}
out["curve"] = {"anchors": {"sol": [0, 0], "earth_luna": [xE, yE], "pluto_charon": [xP, yP]},
                "mercury_tilt_deg": yM,
                "fits": {"power": {"a": a_pow, "b": b_pow, "form": "tilt = a * Pis^b"},
                         "linear": {"k": k_lin, "form": "tilt = k * Pis"},
                         "quadratic": {"c1": c1, "c2": c2, "form": "tilt = c1*Pis + c2*Pis^2"}},
                "vulcan_prediction": pred,
                "other_pairs_residuals": {k: {"pis": r["companion_pis_per_earth_year"], "tilt": r["spin_tilt_to_zecliptic_deg"],
                                              "power_fit_tilt": a_pow * r["companion_pis_per_earth_year"] ** b_pow,
                                              "residual_deg": r["spin_tilt_to_zecliptic_deg"] - a_pow * r["companion_pis_per_earth_year"] ** b_pow}
                                          for k, r in out["bodies"].items() if r.get("companion") and k not in ("earth", "pluto")}}

# ------------------------------------------------------------------ distances with 1 AU := R_sol
for k in ("mercury", "venus", "earth", "mars", "ceres", "jupiter", "saturn", "uranus", "neptune", "pluto"):
    b = B[k]
    if not b.get("a_au"):
        continue
    a = b["a_au"] * AU_KM / R_SOL; e = b.get("e") or 0.0
    out["distances_in_solar_radii"][k] = {"a": a, "perihelion": a * (1 - e), "aphelion": a * (1 + e), "a_au_classical": b["a_au"]}
out["distances_in_solar_radii"]["_conversion"] = {"R_sol_km": R_SOL, "classical_AU_in_R_sol": AU_KM / R_SOL,
                                                  "luna_a": B["luna"]["a_km"] / R_SOL, "charon_a": B["charon"]["a_km"] / R_SOL,
                                                  "mercury_hill_perihelion": R_HILL / R_SOL}

# ------------------------------------------------------------------ the normal
out["normal"] = {
    "solar_equator_to_ecliptic_deg": SE_I,
    "invariable_plane_to_ecliptic_deg": INV_I,
    "solar_equator_to_invariable_plane_deg": ang(ZZ, INV_POLE),
    "solar_pole_lean_azimuth_from_invariable_node": None,
    "how_we_tell": ["Invariable plane: sum of the planets' orbital angular momenta (Jupiter ~61 %, Saturn ~25 %, Neptune ~8 %, Uranus ~5 %) from the ephemeris; its pole is fixed to ~0.01°.",
                    "Solar equator: sunspot tracking (Carrington 1863, refined by Doppler and helioseismology) gives i = 7.25° to the ecliptic, node 75.76° (J2000).",
                    "Angle between the two poles is the number above. It is ~6°, not ~1°. The ~1.6° figure is the ecliptic's tilt to the invariable plane — Earth's orbit, not Sol's spin.",
                    "Sol carries ~0.5 % of the system's angular momentum in its spin; the planets' orbits carry the rest. So the 'normal' of the system is set by Jupiter and Saturn, and Sol is the body that is tipped."]}

json.dump(out, open(os.path.join(DOC, "data", "tilt_curve.json"), "w"), indent=1)

# ------------------------------------------------------------------ figures
os.makedirs(os.path.join(DOC, "img"), exist_ok=True)
fig, ax = plt.subplots(figsize=(10, 6))
xs = np.linspace(0, 200, 400)
ax.plot(xs, a_pow * xs ** b_pow, color="#c8a24a", lw=2, label=f"power through origin: tilt = {a_pow:.3f}·Pis^{b_pow:.3f}")
ax.plot(xs, k_lin * xs, color="#888", lw=1, ls="--", label=f"linear through origin: {k_lin:.3f}°/Pi")
ax.plot(xs, c1 * xs + c2 * xs ** 2, color="#888", lw=1, ls=":", label="quadratic through origin")
for k, r in out["bodies"].items():
    if r.get("companion"):
        x, y = r["companion_pis_per_earth_year"], r["spin_tilt_to_zecliptic_deg"]
        anchor = k in ("earth", "pluto")
        ax.scatter([x], [y], s=90 if anchor else 40, color="#e8e0c8" if anchor else "#5a7fa8", zorder=5, edgecolor="k")
        ax.annotate(f"{B[k]['name']}/{B[r['companion']]['name']}  ({x:.0f}, {y:.1f}°)", (x, y), xytext=(6, 6), textcoords="offset points", fontsize=8)
ax.scatter([0], [0], s=120, color="#f5d36b", edgecolor="k", zorder=6); ax.annotate("Sol (0, 0)", (0, 0), xytext=(6, 6), textcoords="offset points", fontsize=8)
ax.axhline(yM, color="#d35", lw=1); ax.annotate(f"Mercury's spin tilt to the Zecliptic: {yM:.2f}°", (120, yM), xytext=(0, 4), textcoords="offset points", fontsize=8, color="#d35")
for name, c in (("power", "#c8a24a"), ("linear", "#888")):
    x = pred[name]["vulcan_pis_per_earth_year"]
    ax.axvline(x, color=c, lw=0.8, ls="--"); ax.annotate(f"{x:.1f} Pis", (x, yM + 3), fontsize=8, color=c, ha="center")
ax.set_xlim(-3, 200); ax.set_ylim(-3, 130)
ax.set_xlabel("companion's Pis (orbits per Earth year × π)"); ax.set_ylabel("primary's spin-axis tilt to the Zecliptic (deg)")
ax.set_title("The tilt curve — anchors Sol, Earth/Luna (42), Pluto/Charon (180); Mercury's tilt read back to a Pis for Vulcan")
ax.grid(alpha=.3); ax.legend(fontsize=8, loc="upper left")
fig.tight_layout(); fig.savefig(os.path.join(DOC, "img", "tilt_curve.png"), dpi=150); plt.close(fig)

# pole azimuths — the birdie question
fig = plt.figure(figsize=(7, 7)); ax = fig.add_subplot(111, projection="polar")
ax.set_theta_zero_location("E"); ax.set_theta_direction(1)
for k, r in out["bodies"].items():
    if r["lean_azimuth_zecliptic_deg"] is None:
        continue
    t = r["spin_tilt_to_zecliptic_deg"]; az = d2r(r["lean_azimuth_zecliptic_deg"])
    ax.scatter([az], [min(t, 90)], s=60, edgecolor="k", color="#5a7fa8" if t <= 90 else "#d35", zorder=5)
    ax.annotate(f"{B[k]['name']} {t:.0f}°", (az, min(t, 90)), xytext=(5, 5), textcoords="offset points", fontsize=8)
# where each planet's perihelion lies, as a reference ring of ticks (Zecliptic-frame longitude of perihelion ~ node + arg of peri; only node is in the data)
ax.set_rmax(92); ax.set_rticks([7.25, 30, 60, 90]); ax.set_rlabel_position(135)
ax.set_title("Which way the axes lean, from above Sol's pole\nradius = tilt from Sol's pole (capped 90°), red = tilt > 90°\nangle = Zecliptic longitude of the lean, 0° = solar node", fontsize=9)
fig.tight_layout(); fig.savefig(os.path.join(DOC, "img", "pole_azimuths.png"), dpi=150); plt.close(fig)

# ------------------------------------------------------------------ markdown
L = [f"# The tilt curve — Sol 0, Earth/Luna 42, Pluto/Charon 180\n",
     "**Date:** 2026-10-11 · **Numbers:** `data/bodies_metrics.json`, `data/pis.json`, `data/v4_annulus.json`, `data/vulcan_derivation.json` via `tools/vulcan/tilt_curve.py` → `data/tilt_curve.json`. Literals: the IAU 2015 pole table (Archinal et al. 2018), the invariable plane (Souami & Souchay 2012), J2000 obliquity, the classical AU in km.\n",
     f"Frame check: Sol's pole from (i 7.25°, Ω 75.76°) and from the IAU RA/Dec (286.13°, 63.87°) differ by {out['frame_check']['solar_pole_elements_vs_iau_deg']:.2f}°. Same pole, two sources.\n",
     "## 1. Spin-axis tilts to the Zecliptic\n",
     "The tilt that matters here is the angle between the body's spin pole and **Sol's** spin pole — not the familiar obliquity (which is measured to the body's own orbit) and not the tilt to the ecliptic (which is Earth's orbit). Poles are right-hand-rule (spin sense counts): the IAU table lists Venus's and Uranus's poles on the north side regardless of spin, so those two are flipped here; Pluto's IAU pole is already right-hand-rule.\n",
     "| body | pole RA, Dec (J2000) | tilt to Zecliptic (Sol's pole) | obliquity to own orbit | tilt to ecliptic pole | tilt to invariable pole | lean azimuth (Zecliptic lon) | companion | companion Pis / Earth yr |",
     "|---|---|---|---|---|---|---|---|---|"]
for k, r in out["bodies"].items():
    comp = B[r["companion"]]["name"] if r.get("companion") else ("Vulcan (none on the board)" if k == "mercury" else "—")
    cp = f"{r['companion_pis_per_earth_year']:.1f}" if r.get("companion") else "—"
    az = f"{r['lean_azimuth_zecliptic_deg']:.0f}°" if r["lean_azimuth_zecliptic_deg"] is not None else "—"
    ob = f"{r['obliquity_to_own_orbit_deg']}°" if r["obliquity_to_own_orbit_deg"] is not None else "—"
    L.append(f"| {B[k]['name']} | {r['pole_radec'][0]:.2f}°, {r['pole_radec'][1]:+.2f}° | **{r['spin_tilt_to_zecliptic_deg']:.2f}°** | {ob} | {r['tilt_to_ecliptic_pole_deg']:.2f}° | {r['tilt_to_invariable_pole_deg']:.2f}° | {az} | {comp} | {cp} |")
L.append(f"\nThe three the operator asked for: **Pluto/Charon {yP:.1f}°**, **Earth/Luna {yE:.1f}°** (23.44° to its own orbit, then the orbit's 7.25° to the Zecliptic, combined at the angle between the two lean directions — not a simple sum), **Mercury {yM:.2f}°** (its spin is locked to its orbit within 0.03°, so its tilt to the Zecliptic is its orbit's 3.38°).\n")

L.append("## 2. The curve\n")
L.append(f"Anchors: Sol (0, 0) — Sol's tilt to its own equator is zero by definition; Earth/Luna ({xE:.1f}, {yE:.1f}°); Pluto/Charon ({xP:.1f}, {yP:.1f}°).\n")
L.append("![tilt curve](img/tilt_curve.png)\n")
L.append("| fit through the origin | form | Vulcan's Pis from Mercury's tilt | a (Earth-yr frame) | a / R_Hill | a (Mercury-yr frame) | a / R_Hill |")
L.append("|---|---|---|---|---|---|---|")
for name, r in pred.items():
    f = out["curve"]["fits"][name]
    form = {"power": f"{f.get('a',0):.3f}·Pis^{f.get('b',0):.3f}", "linear": f"{f.get('k',0):.3f}·Pis", "quadratic": f"{f.get('c1',0):.4f}·Pis + {f.get('c2',0):.2e}·Pis²"}[name]
    L.append(f"| {name} | {form} | **{r['vulcan_pis_per_earth_year']:.1f}** | {r['a_km_earth_year_frame']:,.0f} km | {r['a_over_R_hill']:.2f} | {r['a_km_mercury_year_frame']:,.0f} km | {r['a_over_R_hill_mercury_year_frame']:.2f} |")
res = out["curve"]["other_pairs_residuals"]
L.append(f"\nReading Mercury's {yM:.2f}° back through the curve gives **5–6 Pis** — the operator's '5 or so, maybe 7' falls out of the two anchors he named. That is the content of the curve.\n")
L.append("The pairs that were *not* used to draw it, against the power fit:\n")
L.append("| pair | Pis | tilt | curve says | residual |")
L.append("|---|---|---|---|---|")
for k in ("saturn", "uranus", "jupiter", "neptune", "mars"):
    r = res[k]
    L.append(f"| {B[k]['name']}/{B[PAIRS[k]]['name']} | {r['pis']:.0f} | {r['tilt']:.1f}° | {r['power_fit_tilt']:.1f}° | {r['tilt']-r['power_fit_tilt']:+.1f}° |")
L.append(f"\nUranus/Titania and Saturn/Titan sit within 12–17° of a curve drawn without them; Jupiter (8° tilt at 160 Pis) and Neptune/Triton (Triton is a captured, backward-orbiting moon, so its Pis is not the same kind of number) are far off; Mars/Phobos (3,598 Pis, 19.5°) is off the right edge of the plot and off the curve. Four of seven pairs near one line through the origin is a trend worth keeping on the board; it is not a law, and it is on the board labelled as what it is: a relation drawn through the three bodies the operator chose, which two others happen to respect.\n")
L.append(f"**Where 5–6 Pis puts the body.** Per Earth year: a ≈ {pred['power']['a_km_earth_year_frame']:,.0f} km = {pred['power']['a_over_R_hill']:.1f} Hill radii — outside Mercury's sphere; per Mercury year: {pred['power']['a_km_mercury_year_frame']:,.0f} km = {pred['power']['a_over_R_hill_mercury_year_frame']:.2f} Hill radii — still outside. The survival annulus (§19 of the report) is 13,254–81,473 km. So the curve's Vulcan and the integrator's Vulcan disagree, and the disagreement is the finding: either the Pis frame for Vulcan is not a year we have tried, or the curve's number is a clock (May–Dec 2028) rather than a place, or the body the curve points at is not bound to Mercury. All three are written down; none is chosen.\n")

L.append("## 3. Distances re-measured with 1 AU := Sol's radius\n")
c = out["distances_in_solar_radii"]["_conversion"]
L.append(f"Centre of Sol to the photosphere: R☉ = {R_SOL:,.0f} km. One classical AU is **{c['classical_AU_in_R_sol']:.2f} R☉**.\n")
L.append("| body | a (R☉) | perihelion (R☉) | aphelion (R☉) | classical a (AU) |")
L.append("|---|---|---|---|---|")
for k, r in out["distances_in_solar_radii"].items():
    if k.startswith("_"): continue
    L.append(f"| {B[k]['name']} | {r['a']:,.1f} | {r['perihelion']:,.1f} | {r['aphelion']:,.1f} | {r['a_au_classical']} |")
L.append(f"\nLuna orbits Earth at {c['luna_a']:.3f} R☉; Charon orbits Pluto at {c['charon_a']:.4f} R☉; Mercury's Hill radius at perihelion is {c['mercury_hill_perihelion']:.3f} R☉. **Earth is 215 solar radii out; Pluto is 8,490 (6,380 at perihelion, 10,600 at aphelion).** Mercury at perihelion sits at 66 R☉ — the inner end of the barrier is 66 Sol-widths from the bubbling surface.\n")

L.append("## 4. The birdie — which way do the axes lean?\n")
L.append("![pole azimuths](img/pole_azimuths.png)\n")
L.append("A spin axis points at a fixed place on the sky; 'inward' or 'outward' toward Sol is a *season*, not a property — every planet's pole leans toward Sol at one solstice and away at the other. What *is* a property is the direction of the lean in the Zecliptic frame (the longitude toward which the pole tips), and whether those directions cluster.\n")
L.append("| body | tilt | lean toward Zecliptic longitude |")
L.append("|---|---|---|")
for k, r in out["bodies"].items():
    if r["lean_azimuth_zecliptic_deg"] is not None:
        L.append(f"| {B[k]['name']} | {r['spin_tilt_to_zecliptic_deg']:.1f}° | {r['lean_azimuth_zecliptic_deg']:.0f}° |")
leans = [r["lean_azimuth_zecliptic_deg"] for k, r in out["bodies"].items() if r["lean_azimuth_zecliptic_deg"] is not None and k not in ("sol",)]
Rbar = abs(np.mean(np.exp(1j * np.radians(leans))))
L.append(f"\nMean resultant length of the nine lean directions: **{Rbar:.2f}** (1 = all leaning the same way, 0 = uniform). The feathers of the birdie are not combed: the leans are spread around the dial, with Earth and Saturn leaning roughly together (their poles are {ang(radec_to_ecl(*IAU_POLE['earth']), radec_to_ecl(*IAU_POLE['saturn'])):.1f}° apart on the sky), the small-tilt planets (Mercury, Jupiter) sitting near the centre where azimuth barely means anything, and the three that have gone past 90° (Venus upside-down, Uranus on its side, Pluto/Charon on its side) tipped toward three unrelated longitudes. The honest answer to 'inward or outward' is: neither, as a set; the edges that turn hardest turn in different directions.\n")

L.append("## 5. The Zecliptic's displacement from the solar system's normal\n")
n = out["normal"]
L.append("| plane pair | angle |")
L.append("|---|---|")
L.append(f"| Sol's equator (Zecliptic) to the ecliptic | {n['solar_equator_to_ecliptic_deg']:.2f}° |")
L.append(f"| invariable plane (total angular momentum) to the ecliptic | {n['invariable_plane_to_ecliptic_deg']:.2f}° |")
L.append(f"| **Sol's equator to the invariable plane** | **{n['solar_equator_to_invariable_plane_deg']:.2f}°** |")
L.append("\n" + "\n".join(f"- {s}" for s in n["how_we_tell"]) + "\n")
L.append("So: not 1°. The 1.6° is Earth's orbit against the system's normal. Sol's spin is ~6° off that normal, and since Sol holds half a percent of the angular momentum, the system did not tip to Sol — Sol is tipped relative to the system. Why is an open question in the literature (an early stellar flyby, a lost companion, torque from a tilted primordial disc, an undiscovered outer planet have all been proposed); none is adopted here.\n")
L.append("## Literals\n" + "\n".join(f"- `{k}`: {v}" for k, v in LIT.items()) + "\n")
open(os.path.join(DOC, "TILT_CURVE_20261011.md"), "w").write("\n".join(L))
print("\n".join(L))
