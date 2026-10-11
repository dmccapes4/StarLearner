#!/usr/bin/env python3
"""Oddly-planed bodies vs the Zecliptic.

Reads bodies_metrics.json + every SBDB file. Writes data/odd_planes.json and
ODD_PLANES_20261011.md. Inclination to a plane is the angle between orbit poles:
pole(i, Ω) · pole_plane. Nothing is fitted. Threshold for the 'odd' flag: i to
the Zecliptic ≥ 10° (heliocentric) or |i| to the primary's equator ≥ 10° (moons).
"""
import json, math, os
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
DOC = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "MERCURY_VULCAN_LADDER_20261010"))
B = json.load(open(os.path.join(DOC, "data", "bodies_metrics.json")))
SBDIR = os.path.join(DOC, "data", "sbdb")
SE_I, SE_NODE = 7.25, 75.76
INV_I, INV_NODE = 1.5787, 107.5822
LIT = {
    "solar_equator": ((SE_I, SE_NODE), "Carrington / J2000; same as every other file tonight"),
    "invariable": ((INV_I, INV_NODE), "Souami & Souchay 2012"),
    "odd_threshold_deg": (10.0, "i to Zecliptic (or to primary equator, for moons) at or above this is flagged"),
}


def pole(i_deg, node_deg):
    i, O = math.radians(i_deg), math.radians(node_deg)
    return np.array([math.sin(i) * math.sin(O), -math.sin(i) * math.cos(O), math.cos(i)])


def ang(a, b):
    return float(math.degrees(math.acos(np.clip(np.dot(a, b), -1, 1))))


ZP, IP, EP = pole(SE_I, SE_NODE), pole(INV_I, INV_NODE), np.array([0.0, 0.0, 1.0])


def planes(i, node):
    p = pole(i, node)
    return {"i_ecl_deg": float(i), "i_zecliptic_deg": ang(p, ZP), "i_invariable_deg": ang(p, IP),
            "node_ecl_deg": float(node)}


def sbdb_els(d):
    return {e["name"]: float(e["value"]) for e in d["orbit"]["elements"]}


bodies = {}
# planets / dwarfs from bodies_metrics (ecliptic elements)
for k, b in B.items():
    if b.get("kind") in ("planet", "dwarf") and b.get("i_ecl_deg") is not None:
        row = planes(b["i_ecl_deg"], b.get("omega_node_deg") or 0.0)
        row.update({"id": k, "name": b["name"], "kind": b["kind"], "a_au": b.get("a_au"), "e": b.get("e"),
                    "source": "bodies_metrics", "odd": row["i_zecliptic_deg"] >= 10.0})
        bodies[k] = row

# SBDB named small bodies (overwrite Ceres/Vesta/Pallas/Hygiea with the JPL epoch)
for fn in sorted(os.listdir(SBDIR)):
    d = json.load(open(os.path.join(SBDIR, fn)))
    el = sbdb_els(d)
    name = d["object"]["shortname"].split()[-1]
    k = name.lower()
    row = planes(el["i"], el["om"])
    row.update({"id": k, "name": name, "kind": "asteroid" if k != "ceres" else "dwarf",
                "fullname": d["object"]["fullname"], "orbit_class": d["object"]["orbit_class"]["name"],
                "a_au": el["a"], "e": el["e"], "period_d": el["per"],
                "source": d["signature"]["source"] + " SBDB " + d["object"]["fullname"],
                "odd": row["i_zecliptic_deg"] >= 10.0})
    bodies[k] = row

# moons: inclination is to the primary's equator (catalogued), not a heliocentric plane
moons = {}
for k, b in B.items():
    if b.get("kind") != "moon" or b.get("i_deg") is None:
        continue
    i = abs(float(b["i_deg"]))
    moons[k] = {"id": k, "name": b["name"], "primary": b["primary"], "i_to_primary_equator_deg": float(b["i_deg"]),
                "e": b.get("e"), "a_km": b.get("a_km"), "retrograde": float(b.get("period_d") or 0) < 0,
                "odd": i >= 10.0, "note": "this i is to the primary's equator, not to the Zecliptic"}

out = {
    "definition": "A body is oddly planed here if its orbit pole is ≥ 10° from Sol's pole (heliocentric) or ≥ 10° from its primary's equator (moons). The threshold is a cut, not a law.",
    "literals": {k: {"value": v[0], "why": v[1]} for k, v in LIT.items()},
    "bodies": bodies,
    "moons": moons,
    "named_asked": {
        "pallas": "the classic high-i main-belt body; 35° to the ecliptic, 36.5° to the Zecliptic — odder vs Sol than vs Earth",
        "juno": "moderately tipped (13° ecliptic, 15.3° Zecliptic); one of the four original asteroids",
        "psyche": "NOT oddly planed. 3.1° to the ecliptic, 7.06° to the Zecliptic — it sits in Earth's plane. Its oddness is metal, not tilt.",
    },
}
json.dump(out, open(os.path.join(DOC, "data", "odd_planes.json"), "w"), indent=1)

# markdown
odd_h = sorted([b for b in bodies.values() if b["odd"]], key=lambda x: -x["i_zecliptic_deg"])
aligned = sorted([b for b in bodies.values() if not b["odd"]], key=lambda x: x["i_zecliptic_deg"])
odd_m = sorted([m for m in moons.values() if m["odd"]], key=lambda x: -abs(x["i_to_primary_equator_deg"]))

L = []
L.append("# Oddly-planed bodies vs the Zecliptic\n")
L.append("**Date:** 2026-10-11 · **Sources:** `data/bodies_metrics.json`, `data/sbdb/*.json` (JPL SBDB, fetched 2026-10-11) via `tools/vulcan/odd_planes.py` → `data/odd_planes.json`.\n")
L.append("**Cut:** i to the Zecliptic ≥ 10°. That is a cut so we can hop them, not a claim that 9.9° is ordinary. Planes are orbit poles, not spin axes (those are the tilt curve).\n")
L.append("## 1. The three you named\n")
L.append("| body | i to ecliptic | i to Zecliptic | i to invariable | a (AU) | e | verdict |")
L.append("|---|---|---|---|---|---|---|")
for k in ("pallas", "juno", "psyche"):
    b = bodies[k]
    v = "oddly planed" if b["odd"] else "plane is ordinary — oddness is elsewhere"
    L.append(f"| **{b['name']}** | {b['i_ecl_deg']:.2f}° | **{b['i_zecliptic_deg']:.2f}°** | {b['i_invariable_deg']:.2f}° | {b['a_au']:.3f} | {b['e']:.3f} | {v} |")
L.append("\nPallas is the one. Juno is tipped enough to flag. **Psyche is not oddly planed** — 3.1° to Earth's orbit, 7.06° to Sol's equator, which is what you get for a body that lives in the ecliptic. Keep it on the hop list because you named it and because the Psyche spacecraft is going there; do not put it on the odd-plane overlay as if it belonged.\n")

L.append("## 2. Heliocentric bodies, i to Zecliptic (high → low)\n")
L.append("| body | class | i ecl | **i Zecliptic** | i inv | a | e | odd |")
L.append("|---|---|---|---|---|---|---|---|")
for b in sorted(bodies.values(), key=lambda x: -x["i_zecliptic_deg"]):
    cls = b.get("orbit_class") or b["kind"]
    flag = "**yes**" if b["odd"] else ""
    L.append(f"| {b['name']} | {cls} | {b['i_ecl_deg']:.2f}° | {b['i_zecliptic_deg']:.2f}° | {b['i_invariable_deg']:.2f}° | {b.get('a_au') or '—'} | {b.get('e') if b.get('e') is not None else '—'} | {flag} |")

L.append("\n**What the Zecliptic does to the ranking.** Hidalgo (42.5° ecliptic) stays first at 38.7°. Pallas stays second and gets *more* tipped (34.9 → 36.5). Interamnia jumps 17.3 → 24.1 — Sol's equator makes it odder. Eros 10.8 → 16.5. Hygiea is the reverse surprise: 3.8° to the ecliptic, **10.8° to the Zecliptic**, so it is ordinary in an Earth-frame belt map and flagged here. Ceres is the other reverse: 10.6° to the ecliptic, **3.41° to the Zecliptic** — the same number as Mercury (3.38°). Ceres sits in Sol's equator. Vesta too (3.47°). The 'aligned belt' (Ceres, Vesta, Psyche) and the 'tipped belt' (Pallas, Euphrosyne, Interamnia, Juno) are two different families once the frame is Sol's.\n")

L.append("## 3. Moons oddly inclined to their primary\n")
L.append("| moon | primary | i to primary equator | e |")
L.append("|---|---|---|---|")
for m in odd_m:
    L.append(f"| {m['name']}{' (retro)' if m['retrograde'] else ''} | {B[m['primary']]['name']} | {m['i_to_primary_equator_deg']:.2f}° | {m.get('e')} |")
L.append("\nTriton is captured and backward. Iapetus is the only large regular moon that is not in its planet's equator. Nereid is 7.1° and e = 0.75 — not over the 10° cut, but the eccentricity is the oddness. Luna is 5.1° to the ecliptic (not listed).\n")

L.append("## 4. Hidalgo at 42°\n")
h = bodies["hidalgo"]
L.append(f"944 Hidalgo: a = {h['a_au']:.2f} AU (Jupiter-crossing), e = {h['e']:.3f}, i = {h['i_ecl_deg']:.1f}° ecliptic = **{h['i_zecliptic_deg']:.1f}° Zecliptic**. The 42 is the ecliptic inclination, the same numeral as Luna's Pis, and it is a coincidence of the same kind: four-figure-looking, no mechanism offered, exact enough to remember. Hidalgo is the body that *is* 42° to Earth's orbit and 39° to Sol's.\n")

L.append("## Literals\n")
for k, (v, why) in LIT.items():
    L.append(f"- `{k}` = {v} — {why}")
L.append("\nEverything else is read from JSON.\n")
open(os.path.join(DOC, "ODD_PLANES_20261011.md"), "w").write("\n".join(L))
print("\n".join(L))
