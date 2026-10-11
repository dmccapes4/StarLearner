#!/usr/bin/env python3
"""Export game/data/zecliptic_bodies.json for the Zecliptic Flight mode.

Sources (all read, not typed):
  docs/MERCURY_VULCAN_LADDER_20261010/data/bodies_metrics.json   radii, masses, periods, moons, belt, heliobarrier
  docs/MERCURY_VULCAN_LADDER_20261010/data/v4_annulus.json       Mercury survival annulus
  docs/MERCURY_VULCAN_LADDER_20261010/data/tilt_curve.json       IAU poles (right-hand rule), spin tilts to the Zecliptic
  docs/MERCURY_VULCAN_LADDER_20261010/data/pis.json              Pis per Earth year
  docs/MERCURY_VULCAN_LADDER_20261010/data/sbdb/*.json           JPL SBDB elements for the big belt bodies (fetched 2026-10-11)
  game/scripts/Ephemeris.gd                                      Standish elements Mercury..Jupiter (parsed from the GDScript)
Literals typed here: Standish 1800-2050 elements for Saturn, Uranus, Neptune, Pluto (checked against bodies_metrics a/e/i/node),
the two reference planes, and the dated events list. All literals are echoed into the JSON under "literals".
"""
import json, math, os, re, random

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
DATA = os.path.join(ROOT, "docs", "MERCURY_VULCAN_LADDER_20261010", "data")
OUT = os.path.join(ROOT, "game", "data", "zecliptic_bodies.json")
B = json.load(open(os.path.join(DATA, "bodies_metrics.json")))
A = json.load(open(os.path.join(DATA, "v4_annulus.json")))
T = json.load(open(os.path.join(DATA, "tilt_curve.json")))
P = json.load(open(os.path.join(DATA, "pis.json")))

# ---------------------------------------------------------------- Standish elements
# Mercury..Jupiter: parse Ephemeris.gd so the game and this file cannot disagree.
gd = open(os.path.join(ROOT, "game", "scripts", "Ephemeris.gd")).read()
standish = {}
for name in ("MERCURY", "VENUS", "EARTH", "MARS", "JUPITER"):
    m = re.search(name + r":\s*\{(.*?)\},", gd, re.S)
    block = m.group(1)
    vals = dict(re.findall(r'"(\w+)":\s*(-?[\d.]+)', block))
    standish[name.lower()] = {k: float(v) for k, v in vals.items()}
# Saturn..Pluto: Standish, "Keplerian Elements for Approximate Positions of the Major Planets", Table 1 (1800 AD - 2050 AD)
standish.update({
    "saturn":  {"a": 9.53667594, "a_dot": -0.00125060, "e": 0.05386179, "e_dot": -0.00050991, "i": 2.48599187, "i_dot": 0.00193609,
                "l": 49.95424423, "l_dot": 1222.49362201, "peri": 92.59887831, "peri_dot": -0.41897216, "node": 113.66242448, "node_dot": -0.28867794},
    "uranus":  {"a": 19.18916464, "a_dot": -0.00196176, "e": 0.04725744, "e_dot": -0.00004397, "i": 0.77263783, "i_dot": -0.00242939,
                "l": 313.23810451, "l_dot": 428.48202785, "peri": 170.95427630, "peri_dot": 0.40805281, "node": 74.01692503, "node_dot": 0.04240589},
    "neptune": {"a": 30.06992276, "a_dot": 0.00026291, "e": 0.00859048, "e_dot": 0.00005105, "i": 1.77004347, "i_dot": 0.00035372,
                "l": -55.12002969, "l_dot": 218.45945325, "peri": 44.96476227, "peri_dot": -0.32241464, "node": 131.78422574, "node_dot": -0.00508664},
    "pluto":   {"a": 39.48211675, "a_dot": -0.00031596, "e": 0.24882730, "e_dot": 0.00005170, "i": 17.14001206, "i_dot": 0.00004818,
                "l": 238.92903833, "l_dot": 145.20780515, "peri": 224.06891629, "peri_dot": -0.04062942, "node": 110.30393684, "node_dot": -0.01183482},
})
# cross-check the typed four against bodies_metrics (independent source)
for k in ("saturn", "uranus", "neptune", "pluto"):
    s, b = standish[k], B[k]
    assert abs(s["a"] - b["a_au"]) < 2e-3 * b["a_au"], (k, "a")
    assert abs(s["e"] - b["e"]) < 2e-3, (k, "e")
    assert abs(s["i"] - b["i_ecl_deg"]) < 0.05, (k, "i")
    assert abs(s["node"] - b["omega_node_deg"]) < 0.05, (k, "node")

# ---------------------------------------------------------------- bodies
def planet(k):
    b = B[k]; tc = T["bodies"].get(k, {})
    return {"id": k, "name": b["name"], "kind": b["kind"], "parent": "sol",
            "radius_km": b.get("r_mean_km") or b.get("r_eq_km"), "r_eq_km": b.get("r_eq_km"),
            "mass_kg": b.get("mass_kg"), "gm_km3s2": b.get("gm_km3s2"),
            "elements": standish[k], "elements_source": "Standish 1800-2050 table (Ephemeris.gd for Mercury..Jupiter)",
            "period_d": b["period_d"], "rot_d": b.get("rot_d"), "obliquity_deg": b.get("obliquity_deg"),
            "pole_radec_j2000": tc.get("pole_radec"), "pole_right_hand_flipped": tc.get("right_hand_rule_flipped", False),
            "spin_tilt_to_zecliptic_deg": tc.get("spin_tilt_to_zecliptic_deg"),
            "i_solar_equator_deg": b.get("i_solar_equator_deg"), "i_invariable_deg": b.get("i_invariable_deg"),
            "hill_radius_km": b.get("hill_radius_km"), "rings": b.get("rings", False), "n_moons": b.get("n_moons"),
            "albedo_geom": b.get("albedo_geom"), "notes": b.get("notes", "")}

bodies = {"sol": {"id": "sol", "name": "Sol", "kind": "star", "parent": None, "radius_km": B["sol"]["r_eq_km"], "r_eq_km": B["sol"]["r_eq_km"],
                  "mass_kg": B["sol"]["mass_kg"], "gm_km3s2": B["sol"]["gm_km3s2"], "rot_d": B["sol"]["rot_d"], "rot_note": B["sol"]["rot_note"],
                  "pole_radec_j2000": T["bodies"]["sol"]["pole_radec"], "obliquity_deg": B["sol"]["obliquity_deg"],
                  "luminosity_W": B["sol"]["luminosity_W"], "notes": B["sol"]["notes"]}}
for k in ("mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"):
    bodies[k] = planet(k)

# moons: circular at catalogued a and period, inclined i_deg to the primary's equator (Luna: to the ecliptic, handled in-game by Meeus)
for k, b in B.items():
    if b.get("kind") != "moon":
        continue
    bodies[k] = {"id": k, "name": b["name"], "kind": "moon", "parent": b["primary"],
                 "radius_km": b.get("r_mean_km") or b.get("r_eq_km") or 1.0, "mass_kg": b.get("mass_kg"), "gm_km3s2": b.get("gm_km3s2"),
                 "a_km": b["a_km"], "e": b.get("e", 0.0), "period_d": b["period_d"], "retrograde": b["period_d"] < 0,
                 "i_deg": b.get("i_deg", 0.0), "i_note": b.get("i_note", "to primary equator (assumed)"),
                 "rot_d": b.get("rot_d"), "synchronous": abs((b.get("rot_d") or 0) - b["period_d"]) < 1e-3 * abs(b["period_d"]),
                 "phase_note": "Luna: Meeus series (real). Others: circular, period-exact, epoch-arbitrary phase.",
                 "pis_per_earth_year": P["moons"].get(k, {}).get("pis_per_earth_year"),
                 "hill_radius_km": b.get("hill_radius_in_primary_km"), "notes": b.get("notes", "")}

# big belt bodies from SBDB
SB = {}
for f in sorted(os.listdir(os.path.join(DATA, "sbdb"))):
    d = json.load(open(os.path.join(DATA, "sbdb", f)))
    o = d["orbit"]; el = {e["name"]: float(e["value"]) for e in o["elements"]}
    pp = {p["name"]: p["value"] for p in d.get("phys_par", [])}
    name = d["object"]["shortname"].split(" ", 1)[1]
    k = name.lower()
    diam = float(pp["diameter"]) if pp.get("diameter") else None
    bodies[k] = {"id": k, "name": name, "kind": "asteroid" if o.get("moid") else "asteroid", "parent": "sol",
                 "radius_km": diam / 2 if diam else 1.0, "rot_d": float(pp["rot_per"]) / 24.0 if pp.get("rot_per") else None,
                 "sbdb": {"epoch_jd": float(o["epoch"]), "a": el["a"], "e": el["e"], "i": el["i"], "node": el["om"], "w": el["w"], "ma": el["ma"], "period_d": el["per"],
                          "source": d["signature"]["source"], "fullname": d["object"]["fullname"], "orbit_class": d["object"]["orbit_class"]["name"]},
                 "period_d": el["per"], "H_mag": float(pp["H"]) if pp.get("H") else None}
    SB[k] = bodies[k]

# representative belt sample (deterministic), carved at the Kirkwood gaps from bodies_metrics
ab = B["asteroid_belt"]
rng = random.Random(20261011)
belt = []
gaps = ab["kirkwood_gaps_au"]
while len(belt) < 600:
    a = rng.uniform(ab["a_inner_au"], ab["a_outer_au"])
    if any(abs(a - g) < 0.025 for g in gaps):
        continue
    e = min(0.35, rng.gauss(0, 1) and abs(rng.gauss(0, ab["e_mean"] * 0.8)))
    inc = min(30.0, abs(rng.gauss(0, ab["i_mean_deg"] * 0.9)))
    belt.append({"a": round(a, 5), "e": round(e, 4), "i": round(inc, 3), "node": round(rng.uniform(0, 360), 2),
                 "w": round(rng.uniform(0, 360), 2), "ma": round(rng.uniform(0, 360), 2)})

out = {
    "schema": "ZECLIPTIC_BODIES_v1", "generated": "2026-10-11", "epoch_jd": 2451545.0,
    "frames": {
        "zecliptic": {"i_deg": B["sol"]["obliquity_deg"], "node_deg": 75.76, "why": "Sol's equator. The rule: everything from the Zecliptic unless a frame is named with a reason."},
        "ecliptic": {"i_deg": 0.0, "node_deg": 0.0, "why": "Earth's orbit plane. Named here only because the ephemeris is tabulated in it."},
        "invariable": {"i_deg": 1.5787, "node_deg": 107.5822, "why": "The system's total angular-momentum plane (Souami & Souchay 2012). Set by Jupiter and Saturn."},
    },
    "bodies": bodies,
    "belt": {"sample_note": "600 representative main-belt orbits, seeded, Kirkwood gaps carved; NOT real objects", "a_inner_au": ab["a_inner_au"], "a_outer_au": ab["a_outer_au"],
             "kirkwood_gaps_au": gaps, "resonances": ab.get("kirkwood_resonances"), "sample": belt},
    "heliobarrier": B["heliobarrier"],
    "mercury_annulus_km": A["annulus"], "mercury_hill_perihelion_km": A["constants"]["R_hill_perihelion_km"],
    "pis": {"luna_per_earth_year": P["moons"]["luna"]["pis_per_earth_year"], "charon_per_earth_year": P["moons"]["charon"]["pis_per_earth_year"],
            "definition": P["definition"]},
    "events": [
        {"label": "Now-ish: BepiColombo Mercury orbit insertion", "date": "2026-11-21"},
        {"label": "Luna occults Mercury (geocentric), 2028-02-23", "date": "2028-02-23"},
        {"label": "Solar equinox, B0 = 0 (Earth on Sol's equator node line)", "date": "2026-06-06"},
        {"label": "Solar equinox, B0 = 0", "date": "2026-12-07"},
        {"label": "B0 most negative (-7.25)", "date": "2026-03-06"},
        {"label": "B0 most positive (+7.25)", "date": "2026-09-08"},
        {"label": "New Horizons at Pluto", "date": "2015-07-14"},
        {"label": "Pluto perihelion", "date": "1989-09-05"},
        {"label": "Voyager 1 crosses the heliopause", "date": "2012-08-25"},
        {"label": "Voyager 2 crosses the heliopause", "date": "2018-11-05"},
        {"label": "J2000 epoch", "date": "2000-01-01"},
    ],
    "literals": {
        "standish_saturn_to_pluto": "typed from Standish Table 1 (1800-2050); asserted against bodies_metrics a/e/i/node",
        "frames": "solar equator node 75.76 (Carrington, J2000); invariable plane Souami & Souchay 2012",
        "events": "dates typed; B0 dates from bodies_metrics _solar_equator_view; heliopause dates from bodies_metrics heliobarrier",
        "belt_sample": "random seed 20261011; distributions e~|N(0,0.12)|, i~|N(0,6.75 deg)| from belt means in bodies_metrics",
    },
}
os.makedirs(os.path.dirname(OUT), exist_ok=True)
json.dump(out, open(OUT, "w"), indent=0)
print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB;", len(bodies), "bodies;", len(belt), "belt sample;", list(SB))
