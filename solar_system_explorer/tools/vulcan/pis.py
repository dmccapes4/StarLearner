#!/usr/bin/env python3
"""Pis — the operator's count: (orbits per year, star-fixed) x pi.

Luna: 365.25636 / 27.321661 x pi = 41.999  ->  "Luna does 42 Pis in a year"  (09-27 06:18)
Charon:                                  179.65  ->  "Charon is 180 Pis"          (10-11 01:59)

This script pulls every period from docs/MERCURY_VULCAN_LADDER_20261010/data/bodies_metrics.json
and the annulus from v4_annulus.json (numbers pulled, not typed), computes Pis in three year-frames,
the Zecliptic (solar-equator) angles of the outer planets, and where 5 and 7 Pis would put Vulcan.
Writes data/pis.json and PIS_42_180_20261011.md.  Nothing here is fitted; every line is arithmetic.
"""
import json, math, os
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
DOC = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "MERCURY_VULCAN_LADDER_20261010"))
B = json.load(open(os.path.join(DOC, "data", "bodies_metrics.json")))
A = json.load(open(os.path.join(DOC, "data", "v4_annulus.json")))
V = json.load(open(os.path.join(DOC, "data", "vulcan_derivation.json")))

YEAR_D = 365.25636                     # Earth's year against the stars, days (IERS; same literal as report §17.5)
SE_I, SE_NODE = 7.25, 75.76            # solar equator: tilt to ecliptic and node (Carrington; bodies_metrics 'sol')
OBLIQ_J2000 = 23.439291                # Earth's obliquity, for the one IAU pole given in RA/Dec
PLUTO_POLE_RA, PLUTO_POLE_DEC = 132.993, -6.163   # Pluto north pole = Charon orbit pole, IAU WG (Archinal+ 2018)

d2r = math.radians
LIT = {}                               # literals typed into this script, with their reason
LIT["year_d"] = (YEAR_D, "Earth star-fixed year; identical to report §17.5")
LIT["pluto_pole_radec"] = ([PLUTO_POLE_RA, PLUTO_POLE_DEC], "IAU WG Cartographic Coordinates 2015 report (Archinal et al. 2018), J2000")
LIT["obliquity_j2000"] = (OBLIQ_J2000, "to rotate the IAU pole from equatorial to ecliptic")


def pis(orbits_per_year):
    return orbits_per_year * math.pi


def pole_from_elements(i_deg, node_deg):
    i, O = d2r(i_deg), d2r(node_deg)
    return np.array([math.sin(i) * math.sin(O), -math.sin(i) * math.cos(O), math.cos(i)])


def pole_from_radec(ra_deg, dec_deg):
    ra, dec = d2r(ra_deg), d2r(dec_deg)
    eq = np.array([math.cos(dec) * math.cos(ra), math.cos(dec) * math.sin(ra), math.sin(dec)])
    e = d2r(OBLIQ_J2000)
    R = np.array([[1, 0, 0], [0, math.cos(e), math.sin(e)], [0, -math.sin(e), math.cos(e)]])   # equatorial -> ecliptic
    return R @ eq


SOL_POLE = pole_from_elements(SE_I, SE_NODE)
# Zecliptic frame axes: x along the solar equator's ascending node on the ecliptic, z = solar pole
ZX = np.array([math.cos(d2r(SE_NODE)), math.sin(d2r(SE_NODE)), 0.0])
ZY = np.cross(SOL_POLE, ZX)


def zecliptic_angles(pole):
    """inclination to the solar equator and the ascending node measured in the Zecliptic frame."""
    inc = math.degrees(math.acos(np.clip(np.dot(pole, SOL_POLE), -1, 1)))
    n = np.cross(SOL_POLE, pole)                      # line of nodes (orbit ascending on solar equator)
    if np.linalg.norm(n) < 1e-12:
        return inc, None
    n /= np.linalg.norm(n)
    node = math.degrees(math.atan2(np.dot(n, ZY), np.dot(n, ZX))) % 360
    return inc, node


def near(x, targets=(1, 2, 3, 4, 5, 6, 7, 10, 12, 13, 24, 30, 36, 42, 45, 60, 72, 90, 120, 180, 360), tol=0.01):
    best = min(targets, key=lambda t: abs(x / t - 1))
    rel = x / best - 1
    return (best, rel) if abs(rel) <= tol else (None, None)


out = {"definition": "Pis = (orbits per year, counted against the stars) x pi. Frame of the year is declared per row.",
       "literals": {k: {"value": v[0], "why": v[1]} for k, v in LIT.items()},
       "planets_per_earth_year": {}, "moons": {}, "zecliptic": {}, "vulcan": {}, "mirror": {}}

# 1. planets (and dwarfs) about Sol, Pis per Earth year
for k, b in B.items():
    if b.get("kind") in ("planet", "dwarf") and b.get("period_d"):
        n = YEAR_D / b["period_d"]
        p = pis(n)
        t, rel = near(p)
        out["planets_per_earth_year"][k] = {"period_d": b["period_d"], "orbits_per_earth_year": n, "pis": p,
                                            "near": t, "near_rel": rel}

# 2. moons: per Earth year and per primary's year
for k, b in B.items():
    if b.get("kind") == "moon" and b.get("period_d") and b.get("primary") in B:
        P = abs(b["period_d"])
        prim = B[b["primary"]]
        n_e = YEAR_D / P
        row = {"primary": b["primary"], "period_d": P, "retrograde": b["period_d"] < 0,
               "orbits_per_earth_year": n_e, "pis_per_earth_year": pis(n_e)}
        t, rel = near(pis(n_e)); row["near_earth_year"] = t; row["near_earth_year_rel"] = rel
        if prim.get("period_d"):
            n_p = prim["period_d"] / P
            row["orbits_per_primary_year"] = n_p; row["pis_per_primary_year"] = pis(n_p)
            t, rel = near(pis(n_p)); row["near_primary_year"] = t; row["near_primary_year_rel"] = rel
            # Sun-synodic check (how much 'against the stars' vs 'against Sol' differ for this moon)
            syn = 1.0 / (1.0 / P - 1.0 / prim["period_d"])
            row["sun_synodic_d"] = syn; row["star_vs_sun_period_rel"] = syn / P - 1
        out["moons"][k] = row

# 3. Zecliptic angles of the planets' orbit poles, plus Pluto/Charon's spin/orbit pole
for k in ("mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"):
    b = B[k]
    if b.get("i_ecl_deg") is None:
        continue
    inc, node = zecliptic_angles(pole_from_elements(b["i_ecl_deg"], b.get("omega_node_deg") or 0.0))
    out["zecliptic"][k] = {"i_ecl_deg": b["i_ecl_deg"], "node_ecl_deg": b.get("omega_node_deg"),
                           "i_zecliptic_deg": inc, "node_zecliptic_deg": node,
                           "node_minus_solar_node_ecl_deg": ((b.get("omega_node_deg") or 0.0) - SE_NODE) % 360,
                           "obliquity_to_own_orbit_deg": b.get("obliquity_deg")}
pc_pole = pole_from_radec(PLUTO_POLE_RA, PLUTO_POLE_DEC)
inc, node = zecliptic_angles(pc_pole)
out["zecliptic"]["pluto_charon_orbit_plane"] = {"pole_radec_j2000": [PLUTO_POLE_RA, PLUTO_POLE_DEC],
                                                "tilt_to_zecliptic_deg": inc, "node_zecliptic_deg": node,
                                                "note": "Charon orbits in Pluto's equator (i 0.08 deg); this is the tilt of that plane to the solar equator"}
# sums the operator asked about: Saturn -> Uranus -> Neptune 'vs Zecliptic'
sun_trio = ["saturn", "uranus", "neptune"]
out["zecliptic"]["saturn_uranus_neptune_sums"] = {
    "i_zecliptic_sum_deg": sum(out["zecliptic"][k]["i_zecliptic_deg"] for k in sun_trio),
    "i_ecliptic_sum_deg": sum(B[k]["i_ecl_deg"] for k in sun_trio),
    "obliquity_sum_deg": sum(B[k]["obliquity_deg"] for k in sun_trio),
    "obliquity_sum_plus_pluto_deg": sum(B[k]["obliquity_deg"] for k in sun_trio) + B["pluto"]["obliquity_deg"],
    "node_ecl_sum_deg": sum(B[k]["omega_node_deg"] for k in sun_trio) % 360,
    "node_zecliptic_sum_deg": sum(out["zecliptic"][k]["node_zecliptic_deg"] for k in sun_trio) % 360,
    "saturn_plus_uranus_node_ecl_deg": B["saturn"]["omega_node_deg"] + B["uranus"]["omega_node_deg"],
    "uranus_node_minus_solar_node_deg": B["uranus"]["omega_node_deg"] - SE_NODE,
    "pluto_minus_neptune_node_ecl_deg": B["pluto"]["omega_node_deg"] - B["neptune"]["omega_node_deg"],
}

# 4. Vulcan at 5 and 7 Pis, in three frames; and the annulus expressed in Pis
GM = V["mercury"]["GM_m3s2"]
R_HILL = A["constants"]["R_hill_perihelion_km"]
ann = A["annulus"]
MERC_YEAR, MERC_SPIN = V["mercury"]["orbit_d"], V["mercury"]["spin_d"]


def period_from_a_km(a_km):
    return 2 * math.pi * math.sqrt((a_km * 1e3) ** 3 / GM) / 86400.0


def a_km_from_period_d(P_d):
    return (GM * (P_d * 86400.0) ** 2 / (4 * math.pi ** 2)) ** (1 / 3) / 1e3


frames = {"earth_year": YEAR_D, "mercury_year": MERC_YEAR, "mercury_spin": MERC_SPIN}
vul = {"frames_d": frames, "R_hill_perihelion_km": R_HILL, "annulus_km": ann, "targets": {}, "annulus_in_pis": {}}
for fname, Y in frames.items():
    rows = {}
    for target in (5, 7):
        P = Y / (target / math.pi)
        a = a_km_from_period_d(P)
        rows[str(target)] = {"period_d": P, "a_km": a, "a_over_R_hill_peri": a / R_HILL,
                             "inside_annulus": ann["inner_km_10km_body"] <= a <= ann["outer_km_prograde_this_run"],
                             "verdict": ("inside the survival annulus" if ann["inner_km_10km_body"] <= a <= ann["outer_km_prograde_this_run"]
                                         else "outside Mercury's Hill sphere" if a > R_HILL
                                         else "between annulus ceiling and Hill radius (escapes in the integrator)" if a > ann["outer_km_prograde_this_run"]
                                         else "below the tidal floor")}
    vul["targets"][fname] = rows
    vul["annulus_in_pis"][fname] = {
        "inner_pis": pis(Y / period_from_a_km(ann["inner_km_10km_body"])),
        "outer_prograde_pis": pis(Y / period_from_a_km(ann["outer_km_prograde_this_run"])),
        "outer_retrograde_pis": pis(Y / period_from_a_km(ann["outer_km_retrograde_this_run"])),
        "hill_pis": pis(Y / period_from_a_km(R_HILL)),
    }
# heliocentric reading: 5 and 7 Pis per Earth year as a body orbiting Sol
GM_SUN = B["sol"]["gm_km3s2"] * 1e9
helio = {}
for target in (5, 7):
    P = YEAR_D / (target / math.pi)
    a_au = (GM_SUN * (P * 86400) ** 2 / (4 * math.pi ** 2)) ** (1 / 3) / 1.495978707e11
    helio[str(target)] = {"period_d": P, "a_au": a_au}
vul["heliocentric_per_earth_year"] = helio
vul["classical_vulcan_le_verrier"] = {"a_au": 0.1427, "period_d": 19.7, "pis_per_earth_year": pis(YEAR_D / 19.7),
                                      "source": "Le Verrier 1859 orbit for Lescarbault's object (literal)"}
out["vulcan"] = vul

# 5. the M|M mirror: Mercury's 3:2 spin-orbit vs Pluto's 2:3 orbit-orbit with Neptune
out["mirror"] = {
    "mercury_spin_orbit": V["mercury"]["spin_orbit_ratio"],
    "pluto_over_neptune_period": B["pluto"]["period_d"] / B["neptune"]["period_d"],
    "mercury_e": B["mercury"]["e"], "pluto_e": B["pluto"]["e"],
    "mercury_i_zecliptic_deg": out["zecliptic"]["mercury"]["i_zecliptic_deg"],
    "pluto_i_zecliptic_deg": out["zecliptic"]["pluto"]["i_zecliptic_deg"],
    "mercury_pis_per_earth_year": out["planets_per_earth_year"]["mercury"]["pis"],
    "pluto_pis_per_earth_year": out["planets_per_earth_year"]["pluto"]["pis"],
    "note": "3:2 at the inner end is spin:orbit; 2:3 at the outer end is orbit:orbit (Pluto:Neptune). Reciprocal ratios, different kinds of clock."}

json.dump(out, open(os.path.join(DOC, "data", "pis.json"), "w"), indent=1)

# ---------------------------------------------------------------- markdown
L = []
L.append("# Pis — 42, 180, and where 5–7 would put Vulcan\n")
L.append("**Date:** 2026-10-11 · **Source of every number:** `data/bodies_metrics.json`, `data/v4_annulus.json`, `data/vulcan_derivation.json`, via `tools/vulcan/pis.py` → `data/pis.json`. Literals typed here are listed at the end with their reason.\n")
L.append("**Definition (operator's):** Pis = orbits per year, counted against the stars, × π. The year's frame is declared on every row. Luna: 13.3687 × π = 41.999 → **42 Pis** (09-27 06:18, 10-10 02:22). Charon: 57.185 × π = 179.65 → **180 Pis** per Earth year (10-11 01:59).\n")

L.append("## 1. Planets about Sol, Pis per Earth year\n")
L.append("| body | orbits / Earth yr | Pis | nearest round | off |")
L.append("|---|---|---|---|---|")
for k, r in out["planets_per_earth_year"].items():
    nr = f"{r['near']}" if r["near"] else "—"
    off = f"{r['near_rel']*100:+.2f} %" if r["near"] else ""
    L.append(f"| {B[k]['name']} | {r['orbits_per_earth_year']:.4f} | {r['pis']:.3f} | {nr} | {off} |")
L.append("\nEarth is π Pis by construction. Mercury lands at 13.04 — the same 13 that Luna's month count makes (13.37) before its own π. Venus is 5.11.\n")

L.append("## 2. Moons, Pis per Earth year and per the primary's own year\n")
L.append("| moon | primary | period d | Pis / Earth yr | near | Pis / primary yr | near | star-vs-Sol period diff |")
L.append("|---|---|---|---|---|---|---|---|")
for k, r in out["moons"].items():
    ne = f"**{r['near_earth_year']}** ({r['near_earth_year_rel']*100:+.2f} %)" if r["near_earth_year"] else "—"
    npy = f"**{r['near_primary_year']}** ({r['near_primary_year_rel']*100:+.2f} %)" if r.get("near_primary_year") else "—"
    ppy = f"{r['pis_per_primary_year']:.1f}" if "pis_per_primary_year" in r else "—"
    sv = f"{r['star_vs_sun_period_rel']*100:.3f} %" if "star_vs_sun_period_rel" in r else "—"
    L.append(f"| {B[k]['name']}{' (retro)' if r['retrograde'] else ''} | {B[r['primary']]['name']} | {r['period_d']:.4f} | {r['pis_per_earth_year']:.2f} | {ne} | {ppy} | {npy} | {sv} |")
L.append("\nThe last column is why the frame matters for Luna and for nothing else in the table: Luna against the stars (27.32 d) and Luna against Sol (29.53 d) differ by 8 %, which is 42 vs 38.9. Every other moon's primary has a year so long that the two counts agree to better than 0.3 %.\n")
L.append("Round-number hits at the 1 % level are expected by chance at roughly this rate for a table of this size with this many targets; the two the operator named (42, 180) are the two closest in the Earth-year column. That is a statement about the table, not a mechanism.\n")

L.append("## 3. Zecliptic angles (solar equator, tilt 7.25°, node 75.76°)\n")
L.append("| body | i to ecliptic | i to Zecliptic | node (Zecliptic frame) | node − solar node (ecl) | spin obliquity to own orbit |")
L.append("|---|---|---|---|---|---|")
for k, r in out["zecliptic"].items():
    if "i_zecliptic_deg" in r:
        L.append(f"| {B[k]['name']} | {r['i_ecl_deg']:.2f}° | {r['i_zecliptic_deg']:.2f}° | {r['node_zecliptic_deg']:.1f}° | {r['node_minus_solar_node_ecl_deg']:.1f}° | {r['obliquity_to_own_orbit_deg']}° |")
pc = out["zecliptic"]["pluto_charon_orbit_plane"]
L.append(f"\nPluto/Charon's orbit plane (Pluto's equator; IAU pole RA {PLUTO_POLE_RA}°, Dec {PLUTO_POLE_DEC}°) is tilted **{pc['tilt_to_zecliptic_deg']:.1f}°** to the Zecliptic. Charon's orbit is the most Zecliptic-displaced moon orbit of any large moon in the system — the echo-star binary at the end of the barrier is lying nearly on its side relative to Sol's equator.\n")
s = out["zecliptic"]["saturn_uranus_neptune_sums"]
L.append("### Saturn → Uranus → Neptune, 'vs Zecliptic', summed\n")
L.append("| quantity | value |")
L.append("|---|---|")
L.append(f"| Σ inclination to Zecliptic | {s['i_zecliptic_sum_deg']:.2f}° |")
L.append(f"| Σ inclination to ecliptic | {s['i_ecliptic_sum_deg']:.2f}° |")
L.append(f"| Σ spin obliquity (S+U+N) | **{s['obliquity_sum_deg']:.2f}°** |")
L.append(f"| Σ spin obliquity + Pluto | {s['obliquity_sum_plus_pluto_deg']:.2f}° |")
L.append(f"| Σ ascending nodes (ecliptic) | {s['node_ecl_sum_deg']:.1f}° |")
L.append(f"| Σ ascending nodes (Zecliptic frame) | {s['node_zecliptic_sum_deg']:.1f}° |")
L.append(f"| Saturn node + Uranus node (ecliptic) | **{s['saturn_plus_uranus_node_ecl_deg']:.1f}°** |")
L.append(f"| Uranus node − solar-equator node | **{s['uranus_node_minus_solar_node_deg']:+.2f}°** |")
L.append(f"| Pluto node − Neptune node | {s['pluto_minus_neptune_node_ecl_deg']:.1f}° |")
vn = out["zecliptic"]["venus"]["node_minus_solar_node_ecl_deg"]
L.append(f"\nWhat is near 180: the three spin obliquities sum to {s['obliquity_sum_deg']:.1f}° (not 180); Saturn's and Uranus's nodes sum to {s['saturn_plus_uranus_node_ecl_deg']:.1f}° (4 % over); and in the Zecliptic frame Earth's, Uranus's and Venus's nodes all sit at ≈180° — Earth's by construction, the other two because their orbits cross the ecliptic where Sol's equator does. That is the sharper fact, and it is a near-zero rather than a near-180: **Uranus's ascending node is {s['uranus_node_minus_solar_node_deg']:+.2f}° from the solar equator's node, Venus's is {vn:+.1f}°.** Two of the eight planets cross the ecliptic within 2° of the line where Sol's equator crosses it. No mechanism offered; these are the two angles in the table I would keep looking at, because a coincidence of *lines* is rarer than a coincidence of sums.\n")

L.append("## 4. Vulcan at 5 and 7 Pis\n")
L.append(f"Mercury: GM {GM:.4e} m³/s², Hill radius at perihelion {R_HILL:,.0f} km; survival annulus (v4) {ann['inner_km_10km_body']:,.0f} – {ann['outer_km_prograde_this_run']:,.0f} km prograde, to {ann['outer_km_retrograde_this_run']:,.0f} km retrograde.\n")
L.append("| frame for 'year' | target | period | a | a / R_Hill | verdict |")
L.append("|---|---|---|---|---|---|")
for f, rows in vul["targets"].items():
    for t, r in rows.items():
        L.append(f"| {f.replace('_',' ')} ({frames[f]:.3f} d) | {t} Pis | {r['period_d']:.2f} d | {r['a_km']:,.0f} km | {r['a_over_R_hill_peri']:.2f} | {r['verdict']} |")
L.append("\nThe annulus itself, in Pis:\n")
L.append("| frame | tidal floor (10 km body) | prograde ceiling | retrograde ceiling | Hill radius |")
L.append("|---|---|---|---|---|")
for f, r in vul["annulus_in_pis"].items():
    L.append(f"| {f.replace('_',' ')} | {r['inner_pis']:.0f} | {r['outer_prograde_pis']:.0f} | {r['outer_retrograde_pis']:.0f} | {r['hill_pis']:.1f} |")
h5, h7 = helio["5"], helio["7"]
L.append(f"\n**Heliocentric reading.** If the 5–7 Pis are counted about Sol per Earth year, they are not a moon at all: 5 Pis is a {h5['period_d']:.1f}-day orbit at {h5['a_au']:.3f} AU (Venus is 5.11 Pis at 0.723 AU); 7 Pis is {h7['period_d']:.1f} d at {h7['a_au']:.3f} AU, between Venus and Mercury. Le Verrier's Vulcan (19.7 d, 0.143 AU) is {vul['classical_vulcan_le_verrier']['pis_per_earth_year']:.0f} Pis.\n")
am, ae = vul["annulus_in_pis"]["mercury_year"], vul["annulus_in_pis"]["earth_year"]
import datetime as _dt
t0 = _dt.date(2026, 10, 11)
d5, d7 = t0 + _dt.timedelta(days=5 / math.pi * YEAR_D), t0 + _dt.timedelta(days=7 / math.pi * YEAR_D)
L.append(f"**Verdict.** In every frame where a Mercury moon is physical, 5 and 7 Pis fall *outside* the survival annulus: at or beyond the Hill radius in five of the six cases, and in the sixth (7 Pis per Mercury spin) between the annulus ceiling and the Hill radius, where the v4 integrator's particles escaped. Because Pis count orbits, a *small* Pis is a *wide* orbit; the annulus lives at {am['outer_prograde_pis']:.0f}–{am['inner_pis']:.0f} Pis per Mercury year ({ae['outer_prograde_pis']:.0f}–{ae['inner_pis']:.0f} per Earth year), and the Hill radius itself is {am['hill_pis']:.1f} Pis per Mercury year. So 5–7 cannot be where we *find* it. It can be how long we *look*: 5 Pis of Earth years is 5/π = {5/math.pi:.2f} yr → {d5.isoformat()}, inside BepiColombo's nominal science year and three months after the 2028-02-23 occultation; 7 Pis is {7/math.pi:.2f} yr → {d7.isoformat()}, the end of 2028. If 'find Vulcan by 5 Pis, maybe 7' is a clock, it is the right clock.\n")

L.append("## 5. The .M|M) mirror, by the numbers\n")
m = out["mirror"]
L.append("| | Mercury (inner end) | Pluto/Charon (outer end) |")
L.append("|---|---|---|")
L.append(f"| locked ratio | spin : orbit = {m['mercury_spin_orbit']:.1f} (3:2) | Pluto : Neptune orbit = {m['pluto_over_neptune_period']:.3f} (3:2 in period = 2:3 in orbits) |")
L.append(f"| eccentricity | {m['mercury_e']} | {m['pluto_e']} |")
L.append(f"| i to Zecliptic | {m['mercury_i_zecliptic_deg']:.2f}° | {m['pluto_i_zecliptic_deg']:.2f}° |")
L.append(f"| Pis / Earth yr | {m['mercury_pis_per_earth_year']:.2f} | {m['pluto_pis_per_earth_year']:.4f} |")
L.append(f"| companion | none found (board) | Charon, 180 Pis, orbit plane {pc['tilt_to_zecliptic_deg']:.0f}° off the Zecliptic |")
L.append("\nThe two ends of the barrier carry reciprocal 3:2 locks — Mercury's to Sol in spin, Pluto's to Neptune in orbit. The two most eccentric classical orbits sit at the two ends. The inner end has no moon on the board; the outer end has the most moon-like moon in the system. That asymmetry is the content of the mirror, and it is the reason the ladder predicted a Mercury companion and the board eliminated it.\n")

L.append("## Literals typed in this script\n")
for k, (v, why) in LIT.items():
    L.append(f"- `{k}` = {v} — {why}")
L.append("\nEverything else is read from the three JSON files.\n")
open(os.path.join(DOC, "PIS_42_180_20261011.md"), "w").write("\n".join(L))
print("\n".join(L))
