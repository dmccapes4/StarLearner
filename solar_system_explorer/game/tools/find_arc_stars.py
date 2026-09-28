#!/usr/bin/env python3
"""
find_arc_stars.py
=================
Compute Sol-equatorial positions for each star in the aperture system.

Two categories:

  Category 1 — ARC OBSERVERS
    The continuous arc: Procyon, Pollux, Castor, Capella, Aldebaran, Rigel, Sirius
    Each star computed individually in Sol's equatorial frame.

  Category 2 — APERTURE + TARGET
    Sol (origin), Procyon, Gomeisa  →  the Sol-Procyon-Gomeisa aperture
    M44 (the Flower, the Tesseract) →  the target

Coordinate frame: Sol's equatorial (IAU 2009 north pole RA 286.13°, Dec +63.87°)
Observation point: Earth (Arya) — poles define the meridian condition separately.

One JSONL record per star. No rendering. No ratios. No labyrinth.
"""

import math, json

# ── Sol equatorial frame (IAU 2009) ──────────────────────────────────────────
SOL_POLE_RA  = 286.13   # J2000 degrees
SOL_POLE_DEC =  63.87

def xyz(ra, dec, d=1.0):
    r, d_r = math.radians(ra), math.radians(dec)
    return (d*math.cos(d_r)*math.cos(r),
            d*math.cos(d_r)*math.sin(r),
            d*math.sin(d_r))

def norm(v): m=math.sqrt(sum(x*x for x in v)); return tuple(x/m for x in v)
def dot(a,b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
def cross(a,b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def vsub(a,b): return tuple(x-y for x,y in zip(a,b))
def vscale(v,s): return tuple(x*s for x in v)

def rd(x, y, z):
    r = math.sqrt(x*x+y*y+z*z)
    if r < 1e-15: return 0.0, 0.0
    dec = math.degrees(math.asin(max(-1.,min(1.,z/r))))
    ra  = math.degrees(math.atan2(y,x)) % 360.0
    return ra, dec

def sol_rotation():
    z0   = (0.,0.,1.)
    pole = norm(xyz(SOL_POLE_RA, SOL_POLE_DEC))
    ax   = cross(z0, pole)
    sa   = math.sqrt(dot(ax,ax)); ca = dot(z0, pole)
    if sa < 1e-12: return [[1,0,0],[0,1,0],[0,0,1]]
    ax   = norm(ax); c,s,t = ca,sa,1.-ca; x,y,z = ax
    return [[t*x*x+c,   t*x*y-s*z, t*x*z+s*y],
            [t*x*y+s*z, t*y*y+c,   t*y*z-s*x],
            [t*x*z-s*y, t*y*z+s*x, t*z*z+c  ]]

def rot(R, v):
    return (R[0][0]*v[0]+R[0][1]*v[1]+R[0][2]*v[2],
            R[1][0]*v[0]+R[1][1]*v[1]+R[1][2]*v[2],
            R[2][0]*v[0]+R[2][1]*v[1]+R[2][2]*v[2])

def sep_deg(ra1,dec1,ra2,dec2):
    return math.degrees(math.acos(max(-1.,min(1.,dot(norm(xyz(ra1,dec1)),norm(xyz(ra2,dec2)))))))

R = sol_rotation()

def sol_eq(ra_j2000, dec_j2000):
    """Convert J2000 RA/Dec to Sol-equatorial RA/Dec."""
    v = rot(R, norm(xyz(ra_j2000, dec_j2000)))
    return rd(*v)

# ── CATEGORY 1 — ARC OBSERVERS ───────────────────────────────────────────────
# J2000: RA (deg), Dec (deg), parallax (mas), μα* (mas/yr), μδ (mas/yr), dist (ly)
# Sources: Hipparcos van Leeuwen 2007 + SIMBAD
arc_stars = [
    {
        "name": "Procyon", "bayer": "α CMi", "hip": 37279,
        "j2000_ra": 114.82550, "j2000_dec":   5.22499,
        "plx_mas": 285.930, "dist_ly": 11.46,
        "mua": -714.590, "mud": -1036.800,
        "vmag": 0.34,
    },
    {
        "name": "Pollux", "bayer": "β Gem", "hip": 37826,
        "j2000_ra": 116.32896, "j2000_dec":  28.02620,
        "plx_mas": 96.740, "dist_ly": 33.72,
        "mua": -626.550, "mud": -45.950,
        "vmag": 1.14,
    },
    {
        "name": "Castor", "bayer": "α Gem", "hip": 36850,
        "j2000_ra": 113.64940, "j2000_dec":  31.88830,
        "plx_mas": 63.270, "dist_ly": 51.55,
        "mua": -206.330, "mud": -148.180,
        "vmag": 1.58,
    },
    {
        "name": "Capella", "bayer": "α Aur", "hip": 24608,
        "j2000_ra":  79.17230, "j2000_dec":  45.99799,
        "plx_mas": 77.290, "dist_ly": 42.19,
        "mua":  75.520, "mud": -427.130,
        "vmag": 0.08,
    },
    {
        "name": "Aldebaran", "bayer": "α Tau", "hip": 21421,
        "j2000_ra":  68.98016, "j2000_dec":  16.50930,
        "plx_mas": 50.090, "dist_ly": 65.13,
        "mua":  62.780, "mud": -189.359,
        "vmag": 0.85,
    },
    {
        "name": "Rigel", "bayer": "β Ori", "hip": 24436,
        "j2000_ra":  78.63447, "j2000_dec":  -8.20164,
        "plx_mas":  3.780, "dist_ly": 863.0,
        "mua":   1.870, "mud":  -0.560,
        "vmag": 0.13,
    },
    {
        "name": "Sirius", "bayer": "α CMa", "hip": 32349,
        "j2000_ra": 101.28715, "j2000_dec": -16.71612,
        "plx_mas": 379.210, "dist_ly":  8.60,
        "mua": -546.010, "mud": -1223.070,
        "vmag": -1.46,
    },
]

# ── CATEGORY 2 — APERTURE + TARGET ───────────────────────────────────────────
aperture_stars = [
    {
        "name": "Procyon", "bayer": "α CMi", "hip": 37279,
        "role": "aperture_eye_east",
        "j2000_ra": 114.82550, "j2000_dec":   5.22499,
        "plx_mas": 285.930, "dist_ly": 11.46,
        "mua": -714.590, "mud": -1036.800,
        "vmag": 0.34,
    },
    {
        "name": "Gomeisa", "bayer": "β CMi", "hip": 36188,
        "role": "aperture_eye_west",
        "j2000_ra": 111.78780, "j2000_dec":   8.28941,
        "plx_mas":  19.160, "dist_ly": 170.2,
        "mua": -50.280, "mud": -38.450,           # Hipparcos I/239 direct
        "vmag": 2.90,
    },
    {
        "name": "M44", "bayer": "NGC 2632 / Beehive / The Flower", "hip": None,
        "role": "target_tesseract",
        "j2000_ra": 129.86730, "j2000_dec":  19.73730,
        "plx_mas":   5.370, "dist_ly": 607.0,
        "mua": -36.0, "mud": -12.9,
        "vmag": 3.7,
    },
]

# ── Compute and write ─────────────────────────────────────────────────────────
records = []

def make_record(star, category):
    ra_j = star["j2000_ra"]; dec_j = star["j2000_dec"]
    sol_ra, sol_dec = sol_eq(ra_j, dec_j)
    rec = {
        "category": category,
        "name": star["name"],
        "bayer": star.get("bayer", ""),
        "hip": star.get("hip"),
        "vmag": star.get("vmag"),
        "dist_ly": star.get("dist_ly"),
        "plx_mas": star.get("plx_mas"),
        "j2000": {
            "ra_deg": round(ra_j, 5),
            "dec_deg": round(dec_j, 5),
            "ra_h": round(ra_j/15, 5),
        },
        "sol_eq": {
            "ra_deg": round(sol_ra, 5),
            "dec_deg": round(sol_dec, 5),
            "ra_h": round(sol_ra/15, 5),
        },
        "proper_motion": {
            "mua_mas_yr": star.get("mua"),
            "mud_mas_yr": star.get("mud"),
        },
    }
    if "role" in star:
        rec["role"] = star["role"]
    return rec

print("═══ CATEGORY 1 — ARC OBSERVERS (Sol equatorial) ═══\n")
for star in arc_stars:
    rec = make_record(star, "arc_observer")
    records.append(rec)
    print(f"{rec['name']:12s}  J2000 RA {rec['j2000']['ra_h']:7.4f}h  Dec {rec['j2000']['dec_deg']:+7.4f}°"
          f"   →   Sol-eq RA {rec['sol_eq']['ra_h']:7.4f}h  Dec {rec['sol_eq']['dec_deg']:+7.4f}°"
          f"   dist {rec['dist_ly']:6.1f} ly")

print()
print("═══ CATEGORY 2 — APERTURE + TARGET (Sol equatorial) ═══\n")
for star in aperture_stars:
    rec = make_record(star, "aperture_or_target")
    records.append(rec)
    print(f"{rec['name']:12s}  J2000 RA {rec['j2000']['ra_h']:7.4f}h  Dec {rec['j2000']['dec_deg']:+7.4f}°"
          f"   →   Sol-eq RA {rec['sol_eq']['ra_h']:7.4f}h  Dec {rec['sol_eq']['dec_deg']:+7.4f}°"
          f"   dist {rec['dist_ly']:6.1f} ly")

# ── Angular separations from M44 in Sol frame ─────────────────────────────────
m44_rec = next(r for r in records if r["name"]=="M44")
m44_sol_ra  = m44_rec["sol_eq"]["ra_deg"]
m44_sol_dec = m44_rec["sol_eq"]["dec_deg"]

print()
print("═══ ANGULAR SEPARATION FROM M44 (Sol equatorial frame) ═══\n")
for rec in records:
    if rec["name"]=="M44": continue
    sep = sep_deg(rec["sol_eq"]["ra_deg"], rec["sol_eq"]["dec_deg"],
                  m44_sol_ra, m44_sol_dec)
    rec["sep_from_m44_sol_eq_deg"] = round(sep, 5)
    print(f"  {rec['name']:12s}: {sep:.4f}°")

# ── Write JSONL ───────────────────────────────────────────────────────────────
out_path = "game/docs/video/arc_stars.jsonl"
with open(out_path, "w") as f:
    for r in records:
        f.write(json.dumps(r) + "\n")
print(f"\narc_stars.jsonl written — {len(records)} records.")
