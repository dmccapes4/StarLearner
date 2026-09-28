#!/usr/bin/env python3
"""
m44_cats_eyes.py
================
Find what Procyon and Gomeisa (the cat's eyes) look at.
Compute every body in Sol's equatorial frame, from Moon's equatorial POV.
JSONL for each body. No assumptions.

Reference plane : Sol's equatorial plane (IAU 2009 north pole RA 286.13°, Dec +63.87°)
POV             : Moon equatorial surface, sub-M44 point (always facing the flower)
Proper motion   : applied per epoch (Year 0 and 555 CE)
"""

import math, json, sys

# ── Constants ─────────────────────────────────────────────────────────────────
J2000_JD       = 2451545.0
DAYS_PER_YEAR  = 365.25

# Sol's north pole, IAU 2009 (J2000 equatorial)
SOL_POLE_RA    = 286.13   # degrees
SOL_POLE_DEC   =  63.87   # degrees

# M44 "the flower" brightness-weighted aperture (dissertation)
M44_APT_RA     = 129.8673  # degrees J2000
M44_APT_DEC    =  19.7373  # degrees J2000
M44_DIST_LY    = 520.0

# Cluster mean proper motion (Hipparcos)
M44_MU_RA      = -36.0    # mas/yr  (μα* = μα × cosδ)
M44_MU_DEC     = -12.9    # mas/yr

# ── Vector math ───────────────────────────────────────────────────────────────
def xyz(ra_deg, dec_deg, d=1.0):
    r, d_rad = math.radians(ra_deg), math.radians(dec_deg)
    return (d*math.cos(d_rad)*math.cos(r),
            d*math.cos(d_rad)*math.sin(r),
            d*math.sin(d_rad))

def rd(vx, vy, vz):
    r = math.sqrt(vx*vx + vy*vy + vz*vz)
    if r < 1e-15: return 0.0, 0.0
    dec = math.degrees(math.asin(max(-1.0, min(1.0, vz/r))))
    ra  = math.degrees(math.atan2(vy, vx)) % 360.0
    return ra, dec

def norm(v):
    m = math.sqrt(sum(x*x for x in v))
    return tuple(x/m for x in v) if m > 1e-15 else v

def dot3(a, b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]

def cross3(a, b):
    return (a[1]*b[2]-a[2]*b[1],
            a[2]*b[0]-a[0]*b[2],
            a[0]*b[1]-a[1]*b[0])

def vadd(a, b): return (a[0]+b[0], a[1]+b[1], a[2]+b[2])
def vsub(a, b): return (a[0]-b[0], a[1]-b[1], a[2]-b[2])
def vscale(a, s): return (a[0]*s, a[1]*s, a[2]*s)

def sep_deg(ra1, dec1, ra2, dec2):
    d = dot3(norm(xyz(ra1,dec1)), norm(xyz(ra2,dec2)))
    return math.degrees(math.acos(max(-1.0, min(1.0, d))))

# ── Sol equatorial rotation matrix (J2000 equatorial → Sol equatorial) ────────
def sol_rotation():
    """
    Rodrigues rotation: rotates J2000 equatorial frame so that
    Sol's north pole becomes the new +Z axis.
    Reference: IAU WGCCRE 2009, α0=286.13°, δ0=+63.87°.
    """
    z_j2000 = (0.0, 0.0, 1.0)
    sol_pole = norm(xyz(SOL_POLE_RA, SOL_POLE_DEC))
    axis     = cross3(z_j2000, sol_pole)
    sin_a    = math.sqrt(dot3(axis, axis))
    cos_a    = dot3(z_j2000, sol_pole)
    if sin_a < 1e-12:
        return [[1,0,0],[0,1,0],[0,0,1]]
    ax, ay, az = norm(axis)
    c, s, t = cos_a, sin_a, 1.0 - cos_a
    return [
        [t*ax*ax+c,    t*ax*ay-s*az, t*ax*az+s*ay],
        [t*ax*ay+s*az, t*ay*ay+c,    t*ay*az-s*ax],
        [t*ax*az-s*ay, t*ay*az+s*ax, t*az*az+c   ]
    ]

def rot(R, v):
    return (R[0][0]*v[0]+R[0][1]*v[1]+R[0][2]*v[2],
            R[1][0]*v[0]+R[1][1]*v[1]+R[1][2]*v[2],
            R[2][0]*v[0]+R[2][1]*v[1]+R[2][2]*v[2])

def to_sol(ra, dec, R):
    v = rot(R, norm(xyz(ra, dec)))
    return rd(*v)

# ── Proper motion ─────────────────────────────────────────────────────────────
def jd(year, month, day):
    """Meeus ch.7 proleptic Gregorian JD."""
    y, m = year, month
    if m <= 2: y -= 1; m += 12
    a = int(y // 100)
    b = 2 - a + int(a // 4)
    return int(365.25*(y+4716)) + int(30.6001*(m+1)) + day + b - 1524.5

def apply_pm(ra0, dec0, mu_ra_star, mu_dec, epoch_jd):
    """
    Apply proper motion from J2000.0 to epoch_jd.
    mu_ra_star = μα·cosδ  [mas/yr]
    mu_dec     = μδ        [mas/yr]
    """
    dt = (epoch_jd - J2000_JD) / DAYS_PER_YEAR
    cos_d = math.cos(math.radians(dec0))
    if abs(cos_d) < 1e-10: cos_d = 1e-10
    # RA: mu_ra_star already carries the cos(δ) factor
    d_ra  = (mu_ra_star * 1e-3 * dt) / (cos_d * 3600.0)
    d_dec = (mu_dec     * 1e-3 * dt) / 3600.0
    return (ra0 + d_ra) % 360.0, dec0 + d_dec

# ── Epochs ────────────────────────────────────────────────────────────────────
EPOCHS = {
    "year_0_dec25":           jd(  0, 12, 25.0),
    "555_ad_dec25":           jd(555, 12, 25.0),
    "557_oct18_mars_at_flower": jd(557, 10, 18.0),
}

# ── Star catalogue ────────────────────────────────────────────────────────────

# Procyon α CMi — HIP 37279  (HUGE proper motion)
PROCYON = dict(
    hip=37279, name="Procyon", bayer="α CMi",
    ra_j2000=114.82550, dec_j2000=5.22499,   # J2000 degrees
    dist_pc=3.5096,   # parallax 285.93 mas
    vmag=0.34,
    mu_ra_star=-714.590, mu_dec=-1036.80,     # mas/yr
    role="cats_eye",
    note="Eastern cat's eye. Largest proper motion of any bright star. "
         "Position shifts >0.5° over 1500 yr — NOT STATIC."
)

# Gomeisa β CMi — HIP 36188
GOMEISA = dict(
    hip=36188, name="Gomeisa", bayer="β CMi",
    ra_j2000=111.78780, dec_j2000=8.28941,
    dist_pc=52.192,   # Hipparcos I/239 HIP 36188: plx=19.160 mas → 52.192 pc = 170.2 ly
    vmag=2.90,
    mu_ra_star=-50.280, mu_dec=-38.450,   # Hipparcos I/239 direct
    role="cats_eye",
    note="Western cat's eye. Corrected from Hipparcos I/239 HIP 36188: plx=19.160 mas, pmRA*=-50.280, pmDE=-38.450."
)

# M44 'the flower' — Hipparcos-confirmed members
# Outer hull positions: from dissertation (Hipparcos query r=1.5°, plx 5-7.5 mas)
# Inner positions: estimated from cluster center + r_arcmin; marked as estimated.
# Cluster PM applied uniformly; individual deviations < 5 mas/yr.
M44 = [
  # ─── Outer hull (5 stars) — positions from Hipparcos via dissertation ─────
  dict(hip=42993, name="42993",   role="hull_SE",
       ra_j2000=131.444, dec_j2000=19.049,
       vmag=8.03, plx_mas=5.74, pos_src="hipparcos_dissertation"),
  dict(hip=42628, name="42628",   role="hull_NE",
       ra_j2000=130.314, dec_j2000=20.477,
       vmag=6.72, plx_mas=5.38, pos_src="hipparcos_dissertation"),
  dict(hip=42201, name="42201",   role="hull_NW",
       ra_j2000=129.073, dec_j2000=20.342,
       vmag=7.47, plx_mas=5.24, pos_src="hipparcos_dissertation"),
  dict(hip=42133, name="42133",   role="hull_W",
       ra_j2000=128.831, dec_j2000=19.590,
       vmag=6.55, plx_mas=5.56, pos_src="hipparcos_dissertation"),
  dict(hip=42327, name="42327",   role="hull_SW",
       ra_j2000=129.445, dec_j2000=19.267,
       vmag=6.72, plx_mas=5.93, pos_src="hipparcos_dissertation"),
  # ─── Inner core (9 stars) — estimated from cluster center + r ────────────
  # HIP 42485 is the innermost (4.2' from aperture center).
  dict(hip=42485, name="42485",   role="inner_nearest_aperture",
       ra_j2000=129.937, dec_j2000=19.741,
       vmag=6.65, plx_mas=5.87, pos_src="estimated_4.2arcmin_E_of_aperture",
       note="NEAREST TO FLOWER APERTURE"),
  dict(hip=42556, name="42556",   role="inner",
       ra_j2000=130.077, dec_j2000=19.830,
       vmag=6.29, plx_mas=5.76, pos_src="estimated_17.3arcmin"),
  dict(hip=42516, name="42516",   role="inner",
       ra_j2000=130.000, dec_j2000=20.060,
       vmag=6.39, plx_mas=5.51, pos_src="estimated_18.6arcmin"),
  dict(hip=42523, name="42523",   role="inner",
       ra_j2000=129.780, dec_j2000=20.050,
       vmag=6.61, plx_mas=5.99, pos_src="estimated_17.3arcmin"),
  dict(hip=42542, name="42542",   role="inner",
       ra_j2000=130.237, dec_j2000=19.970,
       vmag=6.76, plx_mas=5.68, pos_src="estimated_22.6arcmin"),
  dict(hip=42600, name="42600",   role="inner",
       ra_j2000=130.240, dec_j2000=19.620,
       vmag=6.77, plx_mas=5.49, pos_src="estimated_22.0arcmin"),
  dict(hip=42578, name="42578",   role="inner",
       ra_j2000=130.160, dec_j2000=19.505,
       vmag=6.83, plx_mas=5.61, pos_src="estimated_18.2arcmin"),
  dict(hip=42164, name="42164",   role="inner_far",
       ra_j2000=129.060, dec_j2000=19.960,
       vmag=7.48, plx_mas=5.34, pos_src="estimated_52.5arcmin"),
  dict(hip=42319, name="42319",   role="inner",
       ra_j2000=129.615, dec_j2000=19.288,
       vmag=8.24, plx_mas=5.88, pos_src="estimated_28.5arcmin"),
]

# ── Aperture geometry ─────────────────────────────────────────────────────────

def cats_eye_aperture(p_ra, p_dec, g_ra, g_dec, target_ra, target_dec):
    """
    Compute the 'face direction' the cat looks at.

    Given:
      P = Procyon unit vector
      G = Gomeisa unit vector
      T = target (M44 aperture) unit vector

    The cat's face is perpendicular to the P-G axis.
    The 'face aperture' is the point on the great circle
    perpendicular to PG (through the PG midpoint) that is
    closest to T.

    This is T projected onto the plane perpendicular to the
    P-G chord — the component of T that lies in the 'looking plane'.

    Returns:
      face_ra, face_dec   : aperture direction (degrees J2000 equatorial)
      midpoint_ra, midpoint_dec
      pg_sep_deg
    """
    pv = norm(xyz(p_ra, p_dec))
    gv = norm(xyz(g_ra, g_dec))
    tv = norm(xyz(target_ra, target_dec))

    # PG chord direction (from P toward G)
    chord = norm(vsub(gv, pv))

    # Project T onto the plane perpendicular to chord
    # (remove component along chord from T)
    t_along_chord = dot3(tv, chord)
    t_perp = vsub(tv, vscale(chord, t_along_chord))
    face_v = norm(t_perp)

    face_ra, face_dec = rd(*face_v)
    mid_v = norm(vadd(pv, gv))
    mid_ra, mid_dec = rd(*mid_v)
    pg_sep = math.degrees(math.acos(max(-1.0, min(1.0, dot3(pv, gv)))))

    # Angular distance from face_v to T (how far face is from M44 aperture)
    face_to_target = math.degrees(math.acos(max(-1.0, min(1.0, dot3(face_v, tv)))))

    return dict(
        face_ra=face_ra, face_dec=face_dec,
        mid_ra=mid_ra, mid_dec=mid_dec,
        pg_sep_deg=pg_sep,
        face_to_m44_aperture_deg=face_to_target,
    )

# ── Main ──────────────────────────────────────────────────────────────────────
def run():
    R = sol_rotation()

    # Obliquity: angle between J2000 north pole and Sol's north pole
    j2k_pole = (0.0, 0.0, 1.0)
    sol_pole = norm(xyz(SOL_POLE_RA, SOL_POLE_DEC))
    obliquity = math.degrees(math.acos(dot3(j2k_pole, sol_pole)))

    records = []

    # ── Metadata ──────────────────────────────────────────────────────────────
    records.append({
        "type": "metadata",
        "frame_input":  "ICRS / J2000 equatorial",
        "frame_output": "Sol equatorial (IAU 2009)",
        "sol_pole_j2000": {"ra_deg": SOL_POLE_RA, "dec_deg": SOL_POLE_DEC},
        "j2000_to_sol_obliquity_deg": round(obliquity, 4),
        "ecliptic_to_sol_equatorial_deg": 7.25,
        "pov": "Moon equatorial surface, sub-M44 point. "
               "Stellar parallax from Moon vs Earth: < 0.001\" for all M44 stars. Negligible.",
        "m44_flower_aperture_j2000": {"ra_deg": M44_APT_RA, "dec_deg": M44_APT_DEC},
        "m44_dist_ly": M44_DIST_LY,
        "cats_eyes": ["Procyon α CMi HIP 37279", "Gomeisa β CMi HIP 36188"],
    })

    for epoch_label, epoch_jd_val in EPOCHS.items():
        dt_yr = (epoch_jd_val - J2000_JD) / DAYS_PER_YEAR

        # ── Procyon at epoch ───────────────────────────────────────────────────
        p_ra, p_dec = apply_pm(PROCYON["ra_j2000"], PROCYON["dec_j2000"],
                                PROCYON["mu_ra_star"], PROCYON["mu_dec"], epoch_jd_val)
        p_sol_ra, p_sol_dec = to_sol(p_ra, p_dec, R)
        p_shift_ra  = (p_ra  - PROCYON["ra_j2000"]) * 60  # arcmin in RA angle
        p_shift_dec = (p_dec - PROCYON["dec_j2000"]) * 60  # arcmin

        records.append({
            "type": "star", "body": "procyon", "epoch": epoch_label,
            "jd": epoch_jd_val, "dt_yr_from_j2000": round(dt_yr, 2),
            "hip": 37279, "bayer": "α CMi", "vmag": PROCYON["vmag"],
            "dist_pc": PROCYON["dist_pc"],
            "j2000_eq": {"ra_deg": PROCYON["ra_j2000"], "dec_deg": PROCYON["dec_j2000"]},
            "at_epoch_j2000eq": {"ra_deg": round(p_ra,6), "dec_deg": round(p_dec,6)},
            "at_epoch_sol_eq":  {"ra_deg": round(p_sol_ra,6), "dec_deg": round(p_sol_dec,6)},
            "proper_motion_shift_arcmin": {"ra_ang": round(p_shift_ra,3), "dec": round(p_shift_dec,3)},
            "note": PROCYON["note"],
        })

        # ── Gomeisa at epoch ───────────────────────────────────────────────────
        g_ra, g_dec = apply_pm(GOMEISA["ra_j2000"], GOMEISA["dec_j2000"],
                                GOMEISA["mu_ra_star"], GOMEISA["mu_dec"], epoch_jd_val)
        g_sol_ra, g_sol_dec = to_sol(g_ra, g_dec, R)

        records.append({
            "type": "star", "body": "gomeisa", "epoch": epoch_label,
            "jd": epoch_jd_val, "dt_yr_from_j2000": round(dt_yr, 2),
            "hip": 36188, "bayer": "β CMi", "vmag": GOMEISA["vmag"],
            "dist_pc": GOMEISA["dist_pc"],
            "j2000_eq": {"ra_deg": GOMEISA["ra_j2000"], "dec_deg": GOMEISA["dec_j2000"]},
            "at_epoch_j2000eq": {"ra_deg": round(g_ra,6), "dec_deg": round(g_dec,6)},
            "at_epoch_sol_eq":  {"ra_deg": round(g_sol_ra,6), "dec_deg": round(g_sol_dec,6)},
            "note": GOMEISA["note"],
        })

        # ── Cat's eye aperture ─────────────────────────────────────────────────
        # M44 aperture at epoch (proper motion applied)
        ap_ra, ap_dec = apply_pm(M44_APT_RA, M44_APT_DEC,
                                  M44_MU_RA, M44_MU_DEC, epoch_jd_val)
        ap_sol_ra, ap_sol_dec = to_sol(ap_ra, ap_dec, R)

        geo = cats_eye_aperture(p_ra, p_dec, g_ra, g_dec, ap_ra, ap_dec)
        face_sol_ra, face_sol_dec = to_sol(geo["face_ra"], geo["face_dec"], R)

        # Sep from each cat's eye to the face aperture
        sep_p_face = sep_deg(p_ra, p_dec, geo["face_ra"], geo["face_dec"])
        sep_g_face = sep_deg(g_ra, g_dec, geo["face_ra"], geo["face_dec"])

        records.append({
            "type": "cats_eye_aperture", "epoch": epoch_label,
            "jd": epoch_jd_val, "dt_yr_from_j2000": round(dt_yr, 2),
            "pg_sep_deg": round(geo["pg_sep_deg"], 6),
            "midpoint_j2000eq": {
                "ra_deg": round(geo["mid_ra"],6), "dec_deg": round(geo["mid_dec"],6),
                "ra_h": round(geo["mid_ra"]/15,5)
            },
            "face_aperture_j2000eq": {
                "ra_deg": round(geo["face_ra"],6), "dec_deg": round(geo["face_dec"],6),
                "ra_h": round(geo["face_ra"]/15,5),
            },
            "face_aperture_sol_eq": {
                "ra_deg": round(face_sol_ra,6), "dec_deg": round(face_sol_dec,6)
            },
            "face_to_m44_aperture_center_deg": round(geo["face_to_m44_aperture_deg"],6),
            "sep_procyon_to_face_deg": round(sep_p_face,6),
            "sep_gomeisa_to_face_deg": round(sep_g_face,6),
            "m44_aperture_at_epoch": {
                "ra_deg": round(ap_ra,6), "dec_deg": round(ap_dec,6),
                "ra_h": round(ap_ra/15,5),
                "sol_eq": {"ra_deg": round(ap_sol_ra,6), "dec_deg": round(ap_sol_dec,6)},
            },
            "interpretation": "face_aperture is where the cat looks: perpendicular to the "
                              "P-G baseline from their midpoint, in the plane of the sky "
                              "that contains M44. This is NOT assumed to be M44's center — "
                              "it is computed from geometry alone."
        })

        # ── Each M44 star ──────────────────────────────────────────────────────
        for s in M44:
            s_ra, s_dec = apply_pm(s["ra_j2000"], s["dec_j2000"],
                                    M44_MU_RA, M44_MU_DEC, epoch_jd_val)
            s_sol_ra, s_sol_dec = to_sol(s_ra, s_dec, R)
            dist_pc = 1000.0 / s["plx_mas"]

            sep_face     = sep_deg(geo["face_ra"], geo["face_dec"], s_ra, s_dec)
            sep_procyon  = sep_deg(p_ra, p_dec, s_ra, s_dec)
            sep_gomeisa  = sep_deg(g_ra, g_dec, s_ra, s_dec)
            sep_aperture = sep_deg(ap_ra, ap_dec, s_ra, s_dec) * 60  # arcmin

            rec = {
                "type": "flower_star", "epoch": epoch_label,
                "jd": epoch_jd_val, "dt_yr_from_j2000": round(dt_yr, 2),
                "hip": s["hip"], "name": s["name"], "role": s["role"],
                "vmag": s["vmag"], "dist_pc": round(dist_pc, 2),
                "pos_source": s["pos_src"],
                "j2000_eq": {"ra_deg": s["ra_j2000"], "dec_deg": s["dec_j2000"]},
                "at_epoch_j2000eq": {"ra_deg": round(s_ra,6), "dec_deg": round(s_dec,6),
                                      "ra_h": round(s_ra/15,5)},
                "at_epoch_sol_eq":  {"ra_deg": round(s_sol_ra,6), "dec_deg": round(s_sol_dec,6)},
                "sep_from_cats_eye_face_deg": round(sep_face, 6),
                "sep_from_procyon_deg":       round(sep_procyon, 6),
                "sep_from_gomeisa_deg":       round(sep_gomeisa, 6),
                "sep_from_flower_aperture_arcmin": round(sep_aperture, 3),
            }
            if "note" in s:
                rec["note"] = s["note"]
            records.append(rec)

    return records

# ── Output ────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    records = run()

    out_path = "game/docs/video/m44_cats_eyes.jsonl"
    with open(out_path, "w") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")
    print(f"wrote {len(records)} records → {out_path}")

    # ── Summary ──────────────────────────────────────────────────────────────
    print("\n=== Sol equatorial obliquity to J2000 equatorial ===")
    meta = next(r for r in records if r["type"]=="metadata")
    print(f"  {meta['j2000_to_sol_obliquity_deg']}° (not 7.25° — 7.25° is ecliptic-to-Sol)")

    print("\n=== Procyon proper motion — it is NOT static ===")
    for r in records:
        if r["type"]=="star" and r["body"]=="procyon":
            s = r["proper_motion_shift_arcmin"]
            print(f"  {r['epoch']:36s}  shift RA {s['ra_ang']:+7.2f}'  Dec {s['dec']:+7.2f}'")

    print("\n=== Cat's eye aperture (what the cat looks at) ===")
    for r in records:
        if r["type"]=="cats_eye_aperture":
            f = r["face_aperture_j2000eq"]
            fs = r["face_aperture_sol_eq"]
            print(f"  {r['epoch']}")
            print(f"    P-G separation      : {r['pg_sep_deg']:.4f}°")
            print(f"    Face aperture J2000 : RA {f['ra_h']:.4f}h  Dec {f['dec_deg']:.4f}°")
            print(f"    Face aperture Sol   : RA {fs['ra_deg']:.4f}°  Dec {fs['dec_deg']:.4f}°")
            print(f"    Face → M44 aperture : {r['face_to_m44_aperture_center_deg']:.4f}°")
            print()

    print("=== Closest flower stars to cat's eye aperture ===")
    for epoch in EPOCHS:
        stars = [r for r in records if r["type"]=="flower_star" and r["epoch"]==epoch]
        stars.sort(key=lambda s: s["sep_from_cats_eye_face_deg"])
        print(f"  {epoch}")
        for s in stars[:6]:
            print(f"    HIP {s['hip']}  {s['role']:25s}  face_sep={s['sep_from_cats_eye_face_deg']:.4f}°  "
                  f"vmag={s['vmag']}  ra={s['at_epoch_j2000eq']['ra_h']:.4f}h  dec={s['at_epoch_j2000eq']['dec_deg']:.3f}°")
        print()
