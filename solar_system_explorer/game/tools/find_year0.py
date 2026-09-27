#!/usr/bin/env python3
"""
find_year0.py
=============
Find Year 0 by geometry alone.

Year 0 = the moment when the cat's eye aperture (perpendicular from the
Procyon-Gomeisa midpoint) points EXACTLY at M44 (the flower).

No calendar. No assumed date. Time is used only as the parameter driving
proper motion — the real question is WHICH DIRECTION, not when.

Also finds: when M44 lies ON the great circle through Procyon and Gomeisa
(all three collinear on the sky sphere).

North/South pole constraint: the alignment counts when the cat's eye
aperture, the celestial poles, and M44 share a meridian.

Outputs:
  - Minimum face-aperture to M44 separation over time (the alignment)
  - The calendar year corresponding to that minimum
  - The Sol-equatorial coordinates at that moment
"""

import math, json

# ── Star data ────────────────────────────────────────────────────────────────
# Procyon α CMi (HIP 37279) — J2000
PRO_RA  = 114.82550   # degrees
PRO_DEC =   5.22499
PRO_MU_RA  = -714.590  # mas/yr  (μα·cosδ)
PRO_MU_DEC =-1036.800

# Gomeisa β CMi (HIP 36188) — J2000
GOM_RA  = 111.78768
GOM_DEC =   8.28930
GOM_MU_RA  =   0.85
GOM_MU_DEC = -46.39

# M44 "the flower" brightness-weighted aperture — J2000
M44_RA  = 129.8673
M44_DEC =  19.7373
M44_MU_RA  = -36.0
M44_MU_DEC = -12.9

# Sol's equatorial north pole (IAU 2009)
SOL_POLE_RA  = 286.13
SOL_POLE_DEC =  63.87

J2000_YR = 2000.0
DAYS_PER_YEAR = 365.25

# ── Math helpers ─────────────────────────────────────────────────────────────
def xyz(ra, dec, d=1.0):
    r, d_r = math.radians(ra), math.radians(dec)
    return (d*math.cos(d_r)*math.cos(r),
            d*math.cos(d_r)*math.sin(r),
            d*math.sin(d_r))

def rd(x, y, z):
    r = math.sqrt(x*x+y*y+z*z)
    if r < 1e-15: return 0.0, 0.0
    dec = math.degrees(math.asin(max(-1.0,min(1.0,z/r))))
    ra  = math.degrees(math.atan2(y, x)) % 360.0
    return ra, dec

def norm(v):
    m = math.sqrt(sum(x*x for x in v))
    return tuple(x/m for x in v) if m > 1e-15 else v

def dot(a, b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def vsub(a, b): return (a[0]-b[0], a[1]-b[1], a[2]-b[2])
def vadd(a, b): return (a[0]+b[0], a[1]+b[1], a[2]+b[2])
def vscale(v, s): return (v[0]*s, v[1]*s, v[2]*s)

def sep_deg(r1,d1,r2,d2):
    return math.degrees(math.acos(max(-1.0,min(1.0,dot(norm(xyz(r1,d1)),norm(xyz(r2,d2)))))))

def apply_pm(ra0, dec0, mu_ra_star, mu_dec, dt_yr):
    cos_d = math.cos(math.radians(dec0))
    if abs(cos_d) < 1e-10: cos_d = 1e-10
    dra  = (mu_ra_star * 1e-3 * dt_yr) / (cos_d * 3600.0)
    ddec = (mu_dec     * 1e-3 * dt_yr) / 3600.0
    return (ra0 + dra) % 360.0, dec0 + ddec

# ── Sol rotation (J2000 equatorial → Sol equatorial) ─────────────────────────
def sol_rotation():
    z0   = (0.0, 0.0, 1.0)
    pole = norm(xyz(SOL_POLE_RA, SOL_POLE_DEC))
    ax   = cross(z0, pole)
    sa   = math.sqrt(dot(ax, ax))
    ca   = dot(z0, pole)
    if sa < 1e-12: return [[1,0,0],[0,1,0],[0,0,1]]
    ax   = norm(ax)
    c, s, t = ca, sa, 1.0-ca
    x, y, z = ax
    return [
        [t*x*x+c,   t*x*y-s*z, t*x*z+s*y],
        [t*x*y+s*z, t*y*y+c,   t*y*z-s*x],
        [t*x*z-s*y, t*y*z+s*x, t*z*z+c  ]
    ]

def rot(R, v):
    return (R[0][0]*v[0]+R[0][1]*v[1]+R[0][2]*v[2],
            R[1][0]*v[0]+R[1][1]*v[1]+R[1][2]*v[2],
            R[2][0]*v[0]+R[2][1]*v[1]+R[2][2]*v[2])

# ── State at a given year offset from J2000 ───────────────────────────────────
def state(dt_yr):
    """
    Returns Procyon, Gomeisa, M44 unit vectors plus derived geometry at dt_yr
    years from J2000. (Negative = past.)
    """
    p_ra, p_dec = apply_pm(PRO_RA, PRO_DEC, PRO_MU_RA, PRO_MU_DEC, dt_yr)
    g_ra, g_dec = apply_pm(GOM_RA, GOM_DEC, GOM_MU_RA, GOM_MU_DEC, dt_yr)
    m_ra, m_dec = apply_pm(M44_RA, M44_DEC, M44_MU_RA, M44_MU_DEC, dt_yr)

    pv = norm(xyz(p_ra, p_dec))
    gv = norm(xyz(g_ra, g_dec))
    mv = norm(xyz(m_ra, m_dec))

    # Cat's eye aperture: component of M44 perpendicular to P-G chord
    chord = norm(vsub(gv, pv))
    m_along = dot(mv, chord)
    m_perp  = norm(vsub(mv, vscale(chord, m_along)))
    face_ra, face_dec = rd(*m_perp)

    # Angular separation: face aperture → M44
    face_to_m44 = math.degrees(math.acos(max(-1.0, min(1.0, dot(m_perp, mv)))))

    # Collinearity: is M44 on the great circle through P and G?
    pg_normal = norm(cross(pv, gv))
    colinearity_offset = abs(dot(mv, pg_normal))  # 0 = perfectly collinear

    # Meridian alignment: does the face aperture share M44's RA (meridian)?
    # This checks if they're on the same great circle through the poles.
    # The great circle through poles and M44 = meridian at RA = m_ra
    # Face is on this meridian if face_ra == m_ra (mod 180)
    meridian_sep = min(
        abs(face_ra - m_ra),
        abs(face_ra - m_ra + 360),
        abs(face_ra - m_ra - 360)
    )

    # P-G separation
    pg_sep = math.degrees(math.acos(max(-1.0, min(1.0, dot(pv, gv)))))

    return dict(
        year=J2000_YR + dt_yr,
        dt_yr=dt_yr,
        p_ra=p_ra, p_dec=p_dec,
        g_ra=g_ra, g_dec=g_dec,
        m_ra=m_ra, m_dec=m_dec,
        face_ra=face_ra, face_dec=face_dec,
        face_to_m44_deg=face_to_m44,
        colinearity_offset=colinearity_offset,
        pg_sep_deg=pg_sep,
        meridian_sep_deg=meridian_sep,
    )

# ── Scan ──────────────────────────────────────────────────────────────────────
def scan(t_start, t_end, step):
    """Scan dt_yr in [t_start, t_end] by step. Returns list of state dicts."""
    results = []
    t = t_start
    while t <= t_end:
        results.append(state(t))
        t += step
    return results

def find_minimum(results, key):
    return min(results, key=lambda r: r[key])

def refine(t_best, key, step=1.0, iterations=30):
    """Binary-search refine around t_best for minimum of key."""
    lo, hi = t_best - abs(step)*5, t_best + abs(step)*5
    for _ in range(iterations):
        mid = (lo + hi) / 2.0
        # Find minimum in [lo, hi] by golden section
        phi = (math.sqrt(5)-1)/2
        a, b = lo, hi
        c, d = b - phi*(b-a), a + phi*(b-a)
        for __ in range(50):
            sc, sd = state(c)[key], state(d)[key]
            if sc < sd:
                b = d
            else:
                a = c
            c = b - phi*(b-a)
            d = a + phi*(b-a)
            if abs(b-a) < 0.001: break
        return (a+b)/2.0
    return (lo+hi)/2.0

R_SOL = sol_rotation()

print("=== Scanning for cat's eye alignment with M44 (the flower) ===\n")
print("Scanning t = -1,000,000 to +200,000 years from J2000...")

# Coarse scan
coarse = scan(-1_000_000, 200_000, 1000)

# Find best candidates
best_face   = find_minimum(coarse, "face_to_m44_deg")
best_coline = find_minimum(coarse, "colinearity_offset")
best_merid  = find_minimum(coarse, "meridian_sep_deg")

print(f"Coarse minimum face→M44 sep : {best_face['face_to_m44_deg']:.4f}°  at year {best_face['year']:.0f}")
print(f"Coarse minimum collinearity  : {best_coline['colinearity_offset']:.6f}  at year {best_coline['year']:.0f}")
print(f"Coarse minimum meridian sep  : {best_merid['meridian_sep_deg']:.4f}°  at year {best_merid['year']:.0f}")
print()

# Refine each
t_face   = refine(best_face['dt_yr'],   "face_to_m44_deg",   step=1000)
t_coline = refine(best_coline['dt_yr'], "colinearity_offset", step=1000)
t_merid  = refine(best_merid['dt_yr'],  "meridian_sep_deg",   step=1000)

s_face   = state(t_face)
s_coline = state(t_coline)
s_merid  = state(t_merid)

R = R_SOL
def to_sol_str(ra, dec):
    v  = rot(R, norm(xyz(ra, dec)))
    sr, sd = rd(*v)
    return f"Sol RA {sr:.4f}°  Dec {sd:.4f}°"

print("═" * 70)
print("1. CAT'S EYE FACE → M44 MINIMUM SEPARATION (aperture alignment)")
print("═" * 70)
print(f"   Year (CE/BCE)         : {s_face['year']:.1f}")
print(f"   dt from J2000         : {s_face['dt_yr']:.0f} yr")
print(f"   Face aperture→M44 sep : {s_face['face_to_m44_deg']:.6f}°")
print(f"   Procyon at epoch      : RA {s_face['p_ra']:.4f}° ({s_face['p_ra']/15:.4f}h)  Dec {s_face['p_dec']:.4f}°")
print(f"   Gomeisa at epoch      : RA {s_face['g_ra']:.4f}° ({s_face['g_ra']/15:.4f}h)  Dec {s_face['g_dec']:.4f}°")
print(f"   M44 at epoch          : RA {s_face['m_ra']:.4f}° ({s_face['m_ra']/15:.4f}h)  Dec {s_face['m_dec']:.4f}°")
print(f"   Face aperture         : RA {s_face['face_ra']:.4f}° ({s_face['face_ra']/15:.4f}h)  Dec {s_face['face_dec']:.4f}°")
print(f"   Sol equatorial face   : {to_sol_str(s_face['face_ra'], s_face['face_dec'])}")
print(f"   P-G separation        : {s_face['pg_sep_deg']:.4f}°")
print()

print("═" * 70)
print("2. COLLINEARITY: P, G, M44 all on the same great circle")
print("═" * 70)
print(f"   Year (CE/BCE)         : {s_coline['year']:.1f}")
print(f"   dt from J2000         : {s_coline['dt_yr']:.0f} yr")
print(f"   Collinearity offset   : {s_coline['colinearity_offset']:.8f}  (0 = perfect)")
print(f"   Procyon at epoch      : RA {s_coline['p_ra']:.4f}° ({s_coline['p_ra']/15:.4f}h)  Dec {s_coline['p_dec']:.4f}°")
print(f"   Gomeisa at epoch      : RA {s_coline['g_ra']:.4f}° ({s_coline['g_ra']/15:.4f}h)  Dec {s_coline['g_dec']:.4f}°")
print(f"   M44 at epoch          : RA {s_coline['m_ra']:.4f}° ({s_coline['m_ra']/15:.4f}h)  Dec {s_coline['m_dec']:.4f}°")
print(f"   Sol equatorial M44    : {to_sol_str(s_coline['m_ra'], s_coline['m_dec'])}")
print()

print("═" * 70)
print("3. MERIDIAN ALIGNMENT: face aperture shares M44's meridian (poles)")
print("═" * 70)
print(f"   Year (CE/BCE)         : {s_merid['year']:.1f}")
print(f"   dt from J2000         : {s_merid['dt_yr']:.0f} yr")
print(f"   Face RA – M44 RA      : {s_merid['meridian_sep_deg']:.6f}° (0 = same meridian)")
print(f"   Face aperture RA      : {s_merid['face_ra']:.4f}° ({s_merid['face_ra']/15:.4f}h)")
print(f"   M44 RA at epoch       : {s_merid['m_ra']:.4f}° ({s_merid['m_ra']/15:.4f}h)")
print(f"   M44 Dec at epoch      : {s_merid['m_dec']:.4f}°")
print(f"   Face Dec at epoch     : {s_merid['face_dec']:.4f}°")
print(f"   Sol equatorial M44    : {to_sol_str(s_merid['m_ra'], s_merid['m_dec'])}")
print()

# Write JSONL
out = []
for s in [s_face, s_coline, s_merid]:
    v_m  = rot(R, norm(xyz(s['m_ra'], s['m_dec'])))
    v_f  = rot(R, norm(xyz(s['face_ra'], s['face_dec'])))
    sm_r, sm_d = rd(*v_m)
    sf_r, sf_d = rd(*v_f)
    out.append({**s,
        "m44_sol_eq":  {"ra_deg": round(sm_r,6), "dec_deg": round(sm_d,6)},
        "face_sol_eq": {"ra_deg": round(sf_r,6), "dec_deg": round(sf_d,6)},
    })

with open("game/docs/video/year0_alignment.jsonl","w") as f:
    for r in out:
        f.write(json.dumps(r)+"\n")
print("year0_alignment.jsonl written.")

# ── Dense scan near each minimum for context ──────────────────────────────────
print("\n=== Dense scan ±5000 yr around each alignment ===\n")
for label, t_best, key in [
    ("Face aperture min",  t_face,   "face_to_m44_deg"),
    ("Collinearity min",   t_coline, "colinearity_offset"),
    ("Meridian alignment", t_merid,  "meridian_sep_deg"),
]:
    dense = scan(t_best-5000, t_best+5000, 100)
    bst   = min(dense, key=lambda r: r[key])
    cal_year = int(round(bst['year']))
    era = "CE" if cal_year >= 1 else f"{abs(cal_year)} BCE"
    print(f"  {label:25s} : {bst[key]:.6f}  at {cal_year:+d} = {abs(cal_year)} {era}")
