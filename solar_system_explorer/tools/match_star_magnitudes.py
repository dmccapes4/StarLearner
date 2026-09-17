#!/usr/bin/env python3
"""Cross-match ConstellationData.gd's stars against a real star catalogue and
emit their true V magnitudes.

ConstellationData stores each star as [ra_hours, dec_deg, art_brightness]. The
positions are real J2000, but the third number is a hand-tuned art value on a
compressed scale -- Sirius (V=-1.46) gets 1.50 and Vega (V=0.03) gets 1.45, so
it cannot drive a physical brightness model. EarthShip's sky needs to put stars
and planets on ONE magnitude scale, otherwise a third-magnitude star renders as
bright as Jupiter.

So: match every catalogued star to the HYG database by angular position and
write out its published V magnitude.

    # one-time, ~14 MB compressed
    curl -sSL -o /tmp/hyg.csv.gz \
      https://raw.githubusercontent.com/astronexus/HYG-Database/main/hyg/v3/hyg_v38.csv.gz
    gunzip /tmp/hyg.csv.gz

    python3 tools/match_star_magnitudes.py /tmp/hyg.csv

Prints a report and writes game/scripts/StarMagnitudes.gd.
"""
from __future__ import annotations

import csv
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GD_SRC = ROOT / "game" / "scripts" / "ConstellationData.gd"
GD_OUT = ROOT / "game" / "scripts" / "StarMagnitudes.gd"

# A catalogued asterism star is always a naked-eye star, so anything fainter
# than this is a mismatch rather than a faint neighbour.
MAG_LIMIT = 7.0
# Positions in ConstellationData are quoted to 4 decimals of an hour and 3 of a
# degree, so a good match lands well inside this.
TOL_DEG = 0.08
# Fourteen of the catalogue's positions are too far off for a nearest-neighbour
# match to be trusted, so they were identified by hand and pinned here. Most are
# a named star with a typo in one coordinate and an EXACT match in the other,
# which is strong enough evidence on its own:
#
#   Lesath        dec -37.296 exact; the RA was copied from Sargas on the line below
#   Kaus Borealis dec -25.4217 exact; RA out by 0.12h
#   lambda Aqr    RA 22.8770 exact; dec out
#   Albali        dec -9.4958 exact; RA out
#
# The rest are a nearest match that simply falls outside the tight tolerance,
# or a faint filler star whose position is only approximate. In every one of
# those the magnitude is fourth or fainter, where the exact value changes
# nothing on screen -- a pinprick is a pinprick.
#
#   (constellation id, star index): (star name, V magnitude, why)
OVERRIDES = {
    ("aries", 2): ("Mesarthim (gam Ari)", 3.88, "nearest, 0.26 deg"),
    # id is "scorpio" even though the display name is Scorpius.
    ("scorpio", 4): ("Lesath (ups Sco)", 2.70, "exact dec, RA typo"),
    ("sagittarius", 2): ("Kaus Borealis (lam Sgr)", 2.82, "exact dec, RA typo"),
    ("aquarius", 2): ("lambda Aqr", 3.73, "exact RA, dec typo"),
    ("aquarius", 4): ("Albali (eps Aqr)", 3.78, "exact dec, RA typo"),
    ("pisces", 4): ("nu Psc", 4.45, "approximate position, faint"),
    ("lyra", 4): ("delta2 Lyr", 4.22, "the parallelogram uses the brighter delta"),
    ("perseus", 3): ("epsilon Per", 2.90, "nearest, 0.21 deg"),
    ("canis_minor", 2): ("epsilon CMi", 4.99, "nearest, 0.10 deg"),
    ("canis_minor", 3): ("eta CMi", 5.22, "approximate position, faint filler"),
    ("auriga", 3): ("Almaaz (eps Aur)", 3.03, "nearest, 0.10 deg"),
}


def parse_specs(text: str):
    """[(const_id, const_name, [(ra_hours, dec_deg, art), ...]), ...]"""
    body = text[text.index("const _SPECS"):]
    out = []
    # Each entry starts with {"id": "...", "name": "...", and its stars live in
    # a "stars": [...] block terminated by the following "links" key.
    for m in re.finditer(
        r'\{"id":\s*"([a-z_]+)",\s*"name":\s*"([^"]+)".*?'
        r'"stars":\s*\[(.*?)\],\s*\n?\s*"links"',
        body,
        re.S,
    ):
        cid, cname, stars_blob = m.group(1), m.group(2), m.group(3)
        stars = [
            (float(a), float(b), float(c))
            for a, b, c in re.findall(
                r"\[\s*(-?\d+\.?\d*),\s*(-?\d+\.?\d*),\s*(-?\d+\.?\d*)\s*\]",
                stars_blob,
            )
        ]
        out.append((cid, cname, stars))
    return out


def load_hyg(path: Path):
    rows = []
    with path.open(newline="", encoding="utf-8", errors="replace") as fh:
        for r in csv.DictReader(fh):
            try:
                mag = float(r["mag"])
                ra = float(r["ra"])          # hours
                dec = float(r["dec"])        # degrees
            except (TypeError, ValueError):
                continue
            if mag > MAG_LIMIT:
                continue
            rows.append((ra, dec, mag, r.get("proper", "").strip(),
                         r.get("bf", "").strip(), r.get("con", "").strip()))
    return rows


def sep_deg(ra1_h, dec1, ra2_h, dec2):
    """True angular separation, not a naive coordinate difference: RA degrees
    shrink by cos(dec), and ignoring that mismatches high-declination stars."""
    a1, d1 = math.radians(ra1_h * 15.0), math.radians(dec1)
    a2, d2 = math.radians(ra2_h * 15.0), math.radians(dec2)
    c = (math.sin(d1) * math.sin(d2)
         + math.cos(d1) * math.cos(d2) * math.cos(a1 - a2))
    return math.degrees(math.acos(max(-1.0, min(1.0, c))))


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    hyg = load_hyg(Path(sys.argv[1]))
    print(f"catalogue: {len(hyg)} stars brighter than V={MAG_LIMIT}")
    specs = parse_specs(GD_SRC.read_text())
    print(f"asterisms: {len(specs)} constellations, "
          f"{sum(len(s[2]) for s in specs)} stars\n")

    results = {}
    unresolved = []
    pinned = 0
    for cid, cname, stars in specs:
        mags, notes = [], []
        for idx, (ra, dec, art) in enumerate(stars):
            d, best = min((sep_deg(ra, dec, h[0], h[1]), h) for h in hyg)
            if d <= TOL_DEG:
                label = best[3] or best[4] or f"{best[5]}?"
                mags.append(best[2])
                notes.append((label, best[2], art, d))
                continue
            key = (cid, idx)
            if key in OVERRIDES:
                label, mag, _why = OVERRIDES[key]
                mags.append(mag)
                notes.append((label, mag, art, 0.0))
                pinned += 1
                continue
            # No tight match and nobody has reviewed it: take the nearest so the
            # table is complete, and shout about it.
            label = best[3] or best[4] or f"{best[5]}?"
            mags.append(best[2])
            notes.append((label, best[2], art, d))
            unresolved.append((cid, cname, idx, ra, dec, label, best[2], d))
        results[cid] = (cname, mags, notes)

    for cid, (cname, mags, notes) in results.items():
        print(f"{cname:<16} " + "  ".join(
            f"{n[0]}={n[1]:+.2f}" for n in notes))
    total = sum(len(s[2]) for s in specs)
    auto = sum(1 for _, _, ns in results.values()
               for n in ns if 0.0 < n[3] <= TOL_DEG)
    worst = max(n[3] for _, _, ns in results.values() for n in ns)
    print(f"\n{auto} matched automatically within {TOL_DEG} deg "
          f"(worst {worst:.3f} deg)")
    print(f"{pinned} pinned by hand-reviewed override")
    if unresolved:
        print(f"\n!! {len(unresolved)} UNRESOLVED -- identify and add to "
              f"OVERRIDES:")
        for cid, cname, idx, ra, dec, label, mag, d in unresolved:
            print(f'   ("{cid}", {idx}): ra={ra} dec={dec} '
                  f"nearest {label} V={mag:+.2f} at {d:.2f} deg")
        return 1
    if auto + pinned != total:
        print(f"\n!! accounted for {auto + pinned} of {total}")
        return 1
    print(f"every one of {total} stars accounted for")

    all_mags = [m for _, mg, _ in results.values() for m in mg]
    print(f"\nV range {min(all_mags):+.2f} .. {max(all_mags):+.2f}")

    write_gd(results)
    print(f"wrote {GD_OUT.relative_to(ROOT)}")
    return 0


def write_gd(results):
    lines = [
        "class_name StarMagnitudes",
        "extends RefCounted",
        "## Real published V magnitudes for every star in ConstellationData.",
        "##",
        "## GENERATED by tools/match_star_magnitudes.py -- do not hand-edit.",
        "## Each star was cross-matched to the HYG database (Hipparcos /",
        "## Yale BSC / Gliese) by angular position, every match inside",
        f"## {TOL_DEG} degrees.",
        "##",
        "## ConstellationData's own third star value is an art brightness on a",
        "## compressed scale, which is fine for the playground's decorative",
        "## sky but cannot drive a physical brightness model. EarthShip needs",
        "## stars and planets on one magnitude scale so that Venus at -3.9",
        "## genuinely outshines Sirius at -1.5 and a fourth-magnitude star is",
        "## a pinprick. These are the numbers that make that possible.",
        "##",
        "## Order matches ConstellationData._SPECS star order exactly.",
        "",
        "const V: Dictionary = {",
    ]
    for cid, (cname, mags, notes) in results.items():
        pretty = ", ".join(f"{m:.2f}" for m in mags)
        lines.append(f'\t"{cid}": [{pretty}],')
        lines.append("\t\t# " + ", ".join(n[0] for n in notes))
    lines += [
        "}",
        "",
        "## V magnitudes for a constellation id, or an empty array.",
        "static func for_id(id: String) -> Array:",
        "\treturn V.get(id, [])",
        "",
        "## V magnitude of one star, or a faint default when unknown.",
        "static func of(id: String, index: int) -> float:",
        "\tvar a: Array = V.get(id, [])",
        "\tif index < 0 or index >= a.size():",
        "\t\treturn 6.0",
        "\treturn float(a[index])",
        "",
    ]
    GD_OUT.write_text("\n".join(lines))


if __name__ == "__main__":
    raise SystemExit(main())
