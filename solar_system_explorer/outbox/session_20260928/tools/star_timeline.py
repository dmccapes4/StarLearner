#!/usr/bin/env python3
"""
star_timeline.py
================
±500,000-year position ledger for each arc star.

Motion model: PLEFR Rung 1 — 3D Cartesian linear propagation.
  Each star has a 3D position and a 3D velocity derived from:
    - Hipparcos proper motion (μα*, μδ)  → transverse velocity components
    - Radial velocity (RV, km/s)         → radial velocity component
  p(t) = p(J2000) + v × t

  This is not flat angular extrapolation. It is 3D propagation that correctly
  handles changing distance (and thus changing perspective angular rate).
  It is still linear in Cartesian space — galactic orbit curvature is not
  integrated (Rung 2 would use a galactic potential model).

  Validity: ~±20 kyr for fast movers (Sirius, Procyon), ~±200 kyr for
  slow movers. Beyond that, galactic orbital curvature accumulates.
  Each state record carries the model tier so the decay is documented.

PLEFR principle (HOW_TO_FLY, 2026-02-19):
  Stars follow the path of lowest entropic field resistance through the
  galactic gravitational field. Proper motion is the tangential snapshot
  of a curved galactic orbit. Stasis = stable galactic orbit equilibrium.
  This script propagates the tangential snapshot forward/backward linearly.
  The field curves back; this model does not. That divergence IS the receipt.

Output: game/docs/video/star_timelines/<name>_timeline.jsonl
  One JSONL per star. Each line = one JSON = one state (one epoch).

Stars:
  Category 1 — Arc Observers:
    Procyon, Pollux, Castor, Capella, Aldebaran, Rigel, Sirius
  Category 2 — Aperture + Target:
    Gomeisa, M44
  (Procyon appears in both; one file covers both roles)
"""

import math, json, os

# ── Output directory ──────────────────────────────────────────────────────────
OUT_DIR = "game/docs/video/star_timelines"

# ── Constants ─────────────────────────────────────────────────────────────────
MAS_TO_RAD   = math.pi / (180.0 * 3600.0 * 1000.0)   # 1 mas in radians
KM_S_TO_PC_YR = 1.0 / 977792.0                         # 1 km/s in pc/yr
                                                          # (= 1 km/s × 3.15576e7 s/yr
                                                          #         / 3.085677581e13 km/pc)
LY_PER_PC    = 3.26156

# ── Sol equatorial rotation (IAU 2009) ────────────────────────────────────────
SOL_POLE_RA  = 286.13
SOL_POLE_DEC =  63.87

def _xyz(ra_deg, dec_deg, d=1.0):
    ra = math.radians(ra_deg); dc = math.radians(dec_deg)
    return (d * math.cos(dc) * math.cos(ra),
            d * math.cos(dc) * math.sin(ra),
            d * math.sin(dc))

def _norm(v):
    m = math.sqrt(sum(x*x for x in v))
    return tuple(x/m for x in v)

def _dot(a, b): return a[0]*b[0] + a[1]*b[1] + a[2]*b[2]

def _cross(a, b):
    return (a[1]*b[2]-a[2]*b[1],
            a[2]*b[0]-a[0]*b[2],
            a[0]*b[1]-a[1]*b[0])

def _sol_rot():
    z0   = (0., 0., 1.)
    pole = _norm(_xyz(SOL_POLE_RA, SOL_POLE_DEC))
    ax   = _cross(z0, pole)
    sa   = math.sqrt(_dot(ax, ax)); ca = _dot(z0, pole)
    if sa < 1e-12: return ((1,0,0),(0,1,0),(0,0,1))
    ax   = _norm(ax); c,s,t = ca,sa,1.-ca; x,y,z = ax
    return ((t*x*x+c,   t*x*y-s*z, t*x*z+s*y),
            (t*x*y+s*z, t*y*y+c,   t*y*z-s*x),
            (t*x*z-s*y, t*y*z+s*x, t*z*z+c))

_R = _sol_rot()

def _rot(v):
    R = _R
    return (R[0][0]*v[0]+R[0][1]*v[1]+R[0][2]*v[2],
            R[1][0]*v[0]+R[1][1]*v[1]+R[1][2]*v[2],
            R[2][0]*v[0]+R[2][1]*v[1]+R[2][2]*v[2])

def _ra_dec(x, y, z):
    r = math.sqrt(x*x + y*y + z*z)
    if r < 1e-15: return 0.0, 0.0
    dec = math.degrees(math.asin(max(-1., min(1., z/r))))
    ra  = math.degrees(math.atan2(y, x)) % 360.0
    return ra, dec

# ── 3D velocity from astrometry ───────────────────────────────────────────────
def star_velocity_pc_yr(ra_deg, dec_deg, dist_pc, mua_mas_yr, mud_mas_yr, rv_km_s):
    """
    Return 3D velocity vector (pc/yr) in J2000 Cartesian frame.

    Basis vectors at star position:
      r_hat : radial (toward star)
      a_hat : east (RA direction, = −sin(RA), cos(RA), 0)
      d_hat : north (Dec direction)
    """
    ra  = math.radians(ra_deg)
    dec = math.radians(dec_deg)

    r_hat = ( math.cos(dec)*math.cos(ra),
              math.cos(dec)*math.sin(ra),
              math.sin(dec) )
    a_hat = (-math.sin(ra),
              math.cos(ra),
              0.0)
    d_hat = (-math.sin(dec)*math.cos(ra),
             -math.sin(dec)*math.sin(ra),
              math.cos(dec))

    # Transverse velocities (pc/yr)
    # μα* (mas/yr) × (rad/mas) × dist (pc)  →  pc/yr in RA direction
    v_a = mua_mas_yr * MAS_TO_RAD * dist_pc
    v_d = mud_mas_yr * MAS_TO_RAD * dist_pc

    # Radial velocity (km/s → pc/yr)
    v_r = rv_km_s * KM_S_TO_PC_YR

    vx = v_r*r_hat[0] + v_a*a_hat[0] + v_d*d_hat[0]
    vy = v_r*r_hat[1] + v_a*a_hat[1] + v_d*d_hat[1]
    vz = v_r*r_hat[2] + v_a*a_hat[2] + v_d*d_hat[2]
    return (vx, vy, vz)

# ── Epoch grid ────────────────────────────────────────────────────────────────
# 1001 epochs: -500,000 to +500,000 in steps of 1,000 yr
EPOCHS = list(range(-500_000, 500_001, 1_000))

# ── Star catalog ─────────────────────────────────────────────────────────────
# All radial velocities from SIMBAD / literature
# plx_mas → dist_pc = 1000/plx_mas (parallax in mas)
STARS = [
    # ── Category 1: Arc Observers ─────────────────────────────────────────
    {
        "name": "Procyon",   "bayer": "α CMi",  "hip": 37279,
        "category": ["arc_observer", "aperture_eye_east"],
        "j2000_ra": 114.82550, "j2000_dec":   5.22499,
        "plx_mas":  285.930,
        "mua": -714.590, "mud": -1036.800,
        "rv_km_s": -0.7,          # SIMBAD: spectroscopic
        "vmag": 0.34,
    },
    {
        "name": "Pollux",    "bayer": "β Gem",  "hip": 37826,
        "category": ["arc_observer"],
        "j2000_ra": 116.32896, "j2000_dec":  28.02620,
        "plx_mas":   96.740,
        "mua": -626.550, "mud":  -45.950,
        "rv_km_s": +3.23,         # SIMBAD
        "vmag": 1.14,
    },
    {
        "name": "Castor",    "bayer": "α Gem",  "hip": 36850,
        "category": ["arc_observer"],
        "j2000_ra": 113.64940, "j2000_dec":  31.88830,
        "plx_mas":   63.270,
        "mua": -206.330, "mud": -148.180,
        "rv_km_s": +6.0,          # approximate; system mean
        "vmag": 1.58,
    },
    {
        "name": "Capella",   "bayer": "α Aur",  "hip": 24608,
        "category": ["arc_observer"],
        "j2000_ra":  79.17230, "j2000_dec":  45.99799,
        "plx_mas":   77.290,
        "mua":  75.520, "mud": -427.130,
        "rv_km_s": +30.2,         # SIMBAD
        "vmag": 0.08,
    },
    {
        "name": "Aldebaran", "bayer": "α Tau",  "hip": 21421,
        "category": ["arc_observer"],
        "j2000_ra":  68.98016, "j2000_dec":  16.50930,
        "plx_mas":   50.090,
        "mua":  62.780, "mud": -189.359,
        "rv_km_s": +54.26,        # SIMBAD
        "vmag": 0.85,
    },
    {
        "name": "Rigel",     "bayer": "β Ori",  "hip": 24436,
        "category": ["arc_observer"],
        "j2000_ra":  78.63447, "j2000_dec":  -8.20164,
        "plx_mas":    3.780,
        "mua":   1.870, "mud":  -0.560,
        "rv_km_s": +17.8,         # SIMBAD
        "vmag": 0.13,
    },
    {
        "name": "Sirius",    "bayer": "α CMa",  "hip": 32349,
        "category": ["arc_observer"],
        "j2000_ra": 101.28715, "j2000_dec": -16.71612,
        "plx_mas":  379.210,
        "mua": -546.010, "mud": -1223.070,
        "rv_km_s": -5.5,          # SIMBAD
        "vmag": -1.46,
    },
    # ── Category 2: Aperture + Target ─────────────────────────────────────
    {
        "name": "Gomeisa",   "bayer": "β CMi",  "hip": 36188,
        "category": ["aperture_eye_west"],
        "j2000_ra": 111.78780, "j2000_dec":   8.28941,
        "plx_mas":   19.160,     # Hipparcos I/239 corrected
        "mua":  -50.280, "mud":  -38.450,   # Hipparcos I/239 direct
        "rv_km_s": +22.0,         # SIMBAD
        "vmag": 2.90,
    },
    {
        "name": "M44",       "bayer": "NGC 2632 / Beehive", "hip": None,
        "category": ["target_tesseract"],
        "j2000_ra": 129.86730, "j2000_dec":  19.73730,
        "plx_mas":    5.370,     # cluster mean parallax → ~186 pc
        "mua":  -36.0, "mud":  -12.9,   # Hipparcos cluster mean
        "rv_km_s": +35.3,         # SIMBAD cluster mean
        "vmag": 3.7,
    },
]

# ── Per-star timeline ─────────────────────────────────────────────────────────
def compute_timeline(star):
    ra0  = star["j2000_ra"]
    dec0 = star["j2000_dec"]
    d0   = 1000.0 / star["plx_mas"]   # pc at J2000
    mua  = star["mua"]
    mud  = star["mud"]
    rv   = star["rv_km_s"]

    # J2000 Cartesian position (pc)
    x0, y0, z0 = _xyz(ra0, dec0, d0)

    # 3D velocity (pc/yr)
    vx, vy, vz = star_velocity_pc_yr(ra0, dec0, d0, mua, mud, rv)

    # Velocity magnitude (km/s, for annotation)
    v_total_km_s = math.sqrt(vx**2 + vy**2 + vz**2) / KM_S_TO_PC_YR

    records = []
    for t in EPOCHS:
        xt = x0 + vx * t
        yt = y0 + vy * t
        zt = z0 + vz * t

        dist_pc = math.sqrt(xt*xt + yt*yt + zt*zt)
        dist_ly = dist_pc * LY_PER_PC

        # J2000 equatorial from propagated Cartesian
        ra_t, dec_t = _ra_dec(xt, yt, zt)

        # Sol equatorial
        v_sol = _rot((xt/dist_pc, yt/dist_pc, zt/dist_pc))
        sol_ra, sol_dec = _ra_dec(*v_sol)

        rec = {
            "star":       star["name"],
            "hip":        star["hip"],
            "epoch_yr":   2000 + t,          # calendar year (J2000 = 2000 CE)
            "dt_yr":      t,                  # offset from J2000
            "xyz_pc":     [round(xt, 6), round(yt, 6), round(zt, 6)],
            "dist_pc":    round(dist_pc, 6),
            "dist_ly":    round(dist_ly, 4),
            "j2000": {
                "ra_deg":  round(ra_t, 6),
                "dec_deg": round(dec_t, 6),
                "ra_h":    round(ra_t / 15.0, 6),
            },
            "sol_eq": {
                "ra_deg":  round(sol_ra, 6),
                "dec_deg": round(sol_dec, 6),
                "ra_h":    round(sol_ra / 15.0, 6),
            },
            "motion_model": "3d_linear_plefr_rung1",
            "v_total_km_s": round(v_total_km_s, 3),
        }
        records.append(rec)
    return records

# ── Write ─────────────────────────────────────────────────────────────────────
os.makedirs(OUT_DIR, exist_ok=True)

total_states = 0
for star in STARS:
    name  = star["name"].lower()
    fpath = os.path.join(OUT_DIR, f"{name}_timeline.jsonl")

    d0_pc = 1000.0 / star["plx_mas"]
    vx, vy, vz = star_velocity_pc_yr(
        star["j2000_ra"], star["j2000_dec"], d0_pc,
        star["mua"], star["mud"], star["rv_km_s"])
    v_total = math.sqrt(vx**2+vy**2+vz**2) / KM_S_TO_PC_YR

    print(f"Computing {star['name']:12s}  d₀={d0_pc:.2f} pc  "
          f"|v|={v_total:.1f} km/s  → {fpath}")

    records = compute_timeline(star)

    with open(fpath, "w") as f:
        for rec in records:
            f.write(json.dumps(rec) + "\n")

    total_states += len(records)
    print(f"  ✓  {len(records)} states written")

print(f"\n{'─'*60}")
print(f"  {len(STARS)} stars  ×  {len(EPOCHS)} epochs  =  {total_states} total states")
print(f"  Output: {OUT_DIR}/")
print(f"{'─'*60}")
