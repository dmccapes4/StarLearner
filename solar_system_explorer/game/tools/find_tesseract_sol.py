#!/usr/bin/env python3
"""
find_tesseract_sol.py
=====================
Tesseract search using the Sol-Procyon-Gomeisa aperture as the coordinate frame.

PROBLEM WITH EARTH-FRAME VERSION (find_tesseract.py):
  - Used J2000 equatorial coordinates (Earth's equatorial plane)
  - Earth's equator is tilted 23.44° to ecliptic, 7.25° to Sol's plane
  - Precession rotates the frame ~360° per 26,000 years
  - Over 400,000 years, the Earth-frame has spun ~15 full revolutions
  - The RA/Dec projection collapses the 3D cluster to a flat sky — depth lost

THE APERTURE FRAME (Sol-Procyon-Gomeisa):
  - Sol at origin (0,0,0) — same as Hipparcos parallax reference
  - Convert all stars to 3D Cartesian using parallax distances
  - At each epoch, propagate Procyon and Gomeisa positions in 3D
  - Define instantaneous aperture axes from the P-G chord
  - Project M44 member 3D positions onto this aperture plane
  - Search for tesseract in these (x,y) aperture-plane coordinates

KEY DIFFERENCE:
  - 3D: M44 members span 152–238 pc depth (parallax 4.2–6.6 mas)
    This depth is INVISIBLE in the flat sky projection
    In the aperture frame, depth becomes a spread along the chord axis
  - The P-G aperture rotates in 3D as Procyon moves (715 mas/yr)
    The "natural frame" sees a completely different configuration than RA/Dec

This calculation does NOT delete or replace the Earth-frame result.
It runs alongside it. The user requested both.
"""

import math, itertools, json

# ── Vector math ──────────────────────────────────────────────────────────────
def vdot(a,b):   return sum(x*y for x,y in zip(a,b))
def vlen(v):     return math.sqrt(vdot(v,v))
def vnorm(v):    L=vlen(v); return tuple(x/L for x in v)
def vcross(a,b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def vsub(a,b):   return tuple(x-y for x,y in zip(a,b))
def rad(x):      return math.radians(x)

def xyz_from_equatorial(ra_deg, dec_deg, dist_pc):
    """3D Cartesian position in pc, Sol at origin, x toward RA=0/Dec=0."""
    ra, dec = rad(ra_deg), rad(dec_deg)
    return (dist_pc * math.cos(dec) * math.cos(ra),
            dist_pc * math.cos(dec) * math.sin(ra),
            dist_pc * math.sin(dec))

def apm_sky(ra0, dec0, mua_mas, mud_mas, dt_yr):
    """Propagate (ra,dec) with proper motions (mas/yr) over dt years.
       mua_mas = μα* = μα·cos(δ) [mas/yr] (already cos-corrected)."""
    cd = math.cos(rad(dec0))
    ra  = (ra0  + mua_mas * 1e-3 * dt_yr / (cd * 3600)) % 360
    dec =  dec0 + mud_mas * 1e-3 * dt_yr / 3600
    return ra, dec

def star_3d_at(ra0, dec0, plx_mas, mua_mas, mud_mas, dt_yr):
    """3D position of a star at epoch J2000+dt_yr, in parsecs from Sol."""
    ra, dec = apm_sky(ra0, dec0, mua_mas, mud_mas, dt_yr)
    dist_pc = 1000.0 / plx_mas  # distance from parallax
    return xyz_from_equatorial(ra, dec, dist_pc)

# ── Star catalogue ────────────────────────────────────────────────────────────
# (RA°, Dec°, parallax mas, μα* mas/yr, μδ mas/yr, distance pc)
# Parallaxes from Hipparcos van Leeuwen 2007

PRO = dict(name="Procyon", ra=114.8255, dec=5.2250,
           plx=285.93, mua=-714.59, mud=-1036.80)   # 3.498 pc
GOM = dict(name="Gomeisa", ra=111.7877, dec=8.2893,
           plx=164.28, mua=0.85,    mud=-46.39)      # 6.087 pc

# M44 members — from SIMBAD cone search (RA=130.054°, Dec=19.621°, r=2°)
# pm selection: μα*∈[-45,-25], μδ∈[-20,-5], plx∈[4,7] mas (confirmed members)
MEMBERS = [
    # name                        RA°          Dec°        μα*     μδ    plx(mas)
    ("HD 73081",                 129.25846, 19.60478,  -35.339, -12.583, 5.456),
    ("HD 73430",                 129.04127, 19.28796,  -35.108, -14.010, 5.276),
    ("HD 73710",                 129.91429, 19.86398,  -35.800, -12.800, 5.400),
    ("HD 73731",                 129.52374, 19.74100,  -35.781, -13.265, 5.439),
    ("HD 73872",                 130.24020, 19.58474,  -36.028, -13.140, 5.421),
    ("HD 73974",                 130.53262, 19.73765,  -37.040, -12.724, 5.464),
    ("* 38 Cnc",                 129.92773, 19.77845,  -36.757, -12.929, 5.488),
    ("V* AX Cnc",                129.79108, 19.78305,  -34.399, -14.632, 5.442),
    ("AG+19 872",                130.00260, 19.80655,  -35.841, -12.209, 5.428),
    ("Cl* NGC 2632 S 12",        129.29787, 19.80368,  -35.881, -12.109, 5.409),
    ("Cl* NGC 2632 S 13",        129.32622, 19.69900,  -36.132, -13.774, 5.423),
    ("Cl* NGC 2632 S 118",       130.09465, 19.46477,  -35.371, -12.809, 5.412),
    ("Cl* NGC 2632 S 209",       130.79486, 19.52629,  -36.007, -12.439, 5.356),
    ("Cl* NGC 2632 JC 63",       129.11302, 19.86519,  -35.383, -14.128, 5.410),
    ("Cl* NGC 2632 JS 719",      130.06334, 20.08721,  -36.020, -13.362, 5.525),
    ("Cl* NGC 2632 JS 738",      130.68852, 18.86007,  -36.301, -12.506, 5.331),
    ("Cl* NGC 2632 HSHJ 272A",   129.89445, 19.80009,  -35.158, -12.119, 5.243),
    ("Cl* NGC 2632 HSHJ 300",    130.04773, 20.06758,  -34.752, -12.901, 4.941),
    ("Cl* NGC 2632 WRS 4",       129.80301, 19.50468,  -36.299, -13.309, 5.183),
    ("2MASS J08421149+1952499",   130.54790, 19.88064,  -38.048, -13.064, 6.649),
    ("2MASS J08405774+2101172",   130.24048, 21.02148,  -36.662, -13.362, 4.661),
]

N = len(MEMBERS)
print("═══ SOL-APERTURE TESSERACT SEARCH ═══")
print(f"M44 members: {N}")
print(f"Procyon:  {PRO['plx']:.2f} mas → {1000/PRO['plx']:.3f} pc = {1000/PRO['plx']*3.2616:.2f} ly")
print(f"Gomeisa:  {GOM['plx']:.2f} mas → {1000/GOM['plx']:.3f} pc = {1000/GOM['plx']*3.2616:.2f} ly")
print(f"M44 mean: 5.371 mas → 186.2 pc = 607 ly")
print()

# Print current 3D geometry
P0 = star_3d_at(PRO['ra'], PRO['dec'], PRO['plx'], PRO['mua'], PRO['mud'], 0)
G0 = star_3d_at(GOM['ra'], GOM['dec'], GOM['plx'], GOM['mua'], GOM['mud'], 0)
print(f"J2000 Procyon 3D: ({P0[0]:.4f}, {P0[1]:.4f}, {P0[2]:.4f}) pc")
print(f"J2000 Gomeisa 3D: ({G0[0]:.4f}, {G0[1]:.4f}, {G0[2]:.4f}) pc")
chord_J0 = vsub(G0, P0)
print(f"J2000 P-G chord: {vlen(chord_J0):.4f} pc = {vlen(chord_J0)*3.2616:.4f} ly")
print()

# ── Aperture frame axes at a given epoch ─────────────────────────────────────
def aperture_axes(dt_yr):
    """
    Compute the Sol-Procyon-Gomeisa aperture plane axes at epoch J2000+dt_yr.

    Returns (e1, e2, e3) where:
      e1 = along the Procyon-Gomeisa chord (normalized)
      e3 = normal to the Sol-P-G plane (= normalize(P × G))
      e2 = e3 × e1 (perpendicular to chord, in the aperture plane)
    """
    P = star_3d_at(PRO['ra'], PRO['dec'], PRO['plx'], PRO['mua'], PRO['mud'], dt_yr)
    G = star_3d_at(GOM['ra'], GOM['dec'], GOM['plx'], GOM['mua'], GOM['mud'], dt_yr)

    chord = vsub(G, P)
    if vlen(chord) < 1e-10:
        return None, None, None

    e1 = vnorm(chord)            # along chord P→G
    e3 = vnorm(vcross(P, G))     # normal to Sol-P-G plane
    e2 = vcross(e3, e1)          # perpendicular to chord, in the plane

    return e1, e2, e3

def project_m44_through_aperture(dt_yr):
    """
    Project all M44 members onto the Sol-P-G aperture plane.
    Returns list of (x, y) in parsecs.
    Each (x,y) = (component along chord e1, component along e2).
    """
    e1, e2, e3 = aperture_axes(dt_yr)
    if e1 is None: return None

    pts = []
    for m in MEMBERS:
        name, ra0, dec0, mua, mud, plx = m
        pos = star_3d_at(ra0, dec0, plx, mua, mud, dt_yr)
        x = vdot(pos, e1)
        y = vdot(pos, e2)
        pts.append((x, y))
    return pts

# ── Tesseract scoring ─────────────────────────────────────────────────────────
def dist2d(a, b): return math.hypot(a[0]-b[0], a[1]-b[1])

def square_score_and_size(pts4):
    dists = sorted([dist2d(pts4[i],pts4[j]) for i in range(4) for j in range(i+1,4)])
    if dists[0] < 1e-9: return 0.0, 1e9
    sides = dists[:4]; diags = dists[4:]
    s = sum(sides)/4; d = sum(diags)/2
    sq2 = math.sqrt(2)
    score = (sum((x-s)**2 for x in sides)/(4*s*s) +
             sum((x-s*sq2)**2 for x in diags)/(2*s*s))
    return s, math.sqrt(score)

def centroid4(pts4): return (sum(p[0] for p in pts4)/4, sum(p[1] for p in pts4)/4)

def rotation_offset(pts4a, pts4b):
    def ang(p): return math.degrees(math.atan2(p[1],p[0])) % 360
    aa = sorted([ang(p) for p in pts4a])
    ba = sorted([ang(p) for p in pts4b])
    diffs = [(b-a) % 360 for a,b in zip(aa,ba)]
    diffs = [d-360 if d>180 else d for d in diffs]
    return sum(diffs)/4

def find_best_tesseract(xy_pts, sq_threshold=0.35):
    """Two-stage tesseract search on projected (x,y) coordinates."""
    # Stage 1: good squares
    good_sq = []
    for combo in itertools.combinations(range(N), 4):
        pts4 = [xy_pts[i] for i in combo]
        side, sq_sc = square_score_and_size(pts4)
        if sq_sc < sq_threshold:
            cx, cy = centroid4(pts4)
            pts4c = [(p[0]-cx, p[1]-cy) for p in pts4]
            good_sq.append((sq_sc, side, (cx,cy), combo, pts4c))

    if len(good_sq) < 2:
        return 1e9, None, None

    best_score = 1e9
    best_combo = None
    best_detail = None

    for i in range(len(good_sq)):
        for j in range(i+1, len(good_sq)):
            s1, sz1, cen1, idx1, pts1c = good_sq[i]
            s2, sz2, cen2, idx2, pts2c = good_sq[j]
            if set(idx1) & set(idx2): continue

            cent_sep = dist2d(cen1, cen2)
            big_side = max(sz1, sz2)
            if cent_sep > big_side * 0.5: continue

            ratio = max(sz1,sz2)/min(sz1,sz2) if min(sz1,sz2)>0 else 99
            ratio_err = abs(ratio - math.sqrt(2)) / math.sqrt(2)
            rot = rotation_offset(pts1c, pts2c)
            rot45 = min(abs((rot % 90)-45), abs(((rot % 90)-45+90)%90))
            rot_err = rot45 / 45.0
            cent_err = cent_sep / big_side

            total = s1 + s2 + ratio_err + rot_err + cent_err
            if total < best_score:
                best_score = total
                best_combo = tuple(sorted(idx1+idx2))
                best_detail = {
                    'score': total,
                    'sq1': s1, 'sq2': s2,
                    'ratio': ratio, 'rot_deg': rot,
                    'centroid_sep_pc': cent_sep,
                    'outer_side_pc': max(sz1,sz2),
                    'inner_side_pc': min(sz1,sz2),
                    'outer_idx': idx1 if sz1>=sz2 else idx2,
                    'inner_idx': idx2 if sz1>=sz2 else idx1,
                }

    return best_score, best_combo, best_detail

# ── Report aperture geometry at J2000 ─────────────────────────────────────────
e1_0, e2_0, e3_0 = aperture_axes(0)
print("J2000 aperture axes:")
print(f"  ê₁ (chord P→G): {e1_0}")
print(f"  ê₂ (in-plane ⊥ chord): {e2_0}")
print(f"  ê₃ (plane normal):     {e3_0}")
print()

pts0 = project_m44_through_aperture(0)
if pts0:
    xs = [p[0] for p in pts0]; ys = [p[1] for p in pts0]
    print(f"M44 member projections at J2000:")
    print(f"  x (along chord) range: {min(xs):.3f} to {max(xs):.3f} pc  (span {max(xs)-min(xs):.3f} pc)")
    print(f"  y (perp chord)  range: {min(ys):.3f} to {max(ys):.3f} pc  (span {max(ys)-min(ys):.3f} pc)")
    print(f"  → cluster appears {(max(xs)-min(xs))/(max(ys)-min(ys)):.2f}× wider than tall in aperture frame")
    print()

# ── Coarse scan ─────────────────────────────────────────────────────────────
print("=== COARSE SCAN: ±500,000 yr at 5,000-yr steps ===")
coarse_best = 1e9; coarse_t = 0
coarse_trace = []
for t in range(-500000, 500001, 5000):
    xy = project_m44_through_aperture(t)
    if xy is None: continue
    score, _, _ = find_best_tesseract(xy)
    coarse_trace.append((t, score))
    if score < coarse_best: coarse_best = score; coarse_t = t

print(f"Coarse minimum: t={coarse_t:+d} ({2000+coarse_t:.0f} CE), score={coarse_best:.5f}")
top3 = sorted(coarse_trace, key=lambda x: x[1])[:5]
print("Top 5 coarse epochs:")
for t, sc in top3:
    yr = 2000+t
    era = f"{abs(yr):.0f} {'BCE' if yr<0 else 'CE'}"
    print(f"  t={t:+8d}  ({era:>14s})  score={sc:.5f}")
print()

# ── Fine scan ────────────────────────────────────────────────────────────────
print(f"=== FINE SCAN: {coarse_t-15000} to {coarse_t+15000} at 500-yr steps ===")
fine_best = coarse_best; fine_t = coarse_t
for t in range(coarse_t-15000, coarse_t+15001, 500):
    xy = project_m44_through_aperture(t)
    if xy is None: continue
    score, _, _ = find_best_tesseract(xy)
    if score < fine_best: fine_best = score; fine_t = t
print(f"Fine minimum: t={fine_t:+d} ({2000+fine_t:.0f} CE), score={fine_best:.5f}")

# ── Ultra-fine scan ───────────────────────────────────────────────────────────
print(f"=== ULTRA-FINE SCAN: {fine_t-1500} to {fine_t+1500} at 50-yr steps ===")
uf_best = fine_best; uf_t = fine_t; uf_combo = None; uf_detail = None
for t in range(fine_t-1500, fine_t+1501, 50):
    xy = project_m44_through_aperture(t)
    if xy is None: continue
    score, combo, detail = find_best_tesseract(xy)
    if score < uf_best:
        uf_best = score; uf_t = t; uf_combo = combo; uf_detail = detail

# Final retrieval at the best epoch
xy_final = project_m44_through_aperture(uf_t)
_, uf_combo, uf_detail = find_best_tesseract(xy_final)

yr = 2000 + uf_t
era = f"{abs(yr):.0f} {'BCE' if yr<0 else 'CE'}"

print()
print("══════════════════════════════════════════════")
print("  M44 SOL-APERTURE TESSERACT EVENT")
print("══════════════════════════════════════════════")
print(f"  Epoch  : {yr:+.0f}  ({era})")
print(f"  Score  : {uf_best:.6f}  (0 = perfect tesseract)")
print()

if uf_detail:
    d = uf_detail
    print(f"  Outer square side  : {d['outer_side_pc']:.4f} pc  ({d['outer_side_pc']*3.2616:.3f} ly)")
    print(f"  Inner square side  : {d['inner_side_pc']:.4f} pc  ({d['inner_side_pc']*3.2616:.3f} ly)")
    print(f"  Ratio outer/inner  : {d['ratio']:.6f}  (ideal √2 = {math.sqrt(2):.6f})")
    print(f"  Rotation angle     : {d['rot_deg']:.4f}°  (ideal ±45°)")
    print(f"  Centroid sep       : {d['centroid_sep_pc']:.4f} pc")
    print()
    print("  Outer square (physical, parsecs):")
    e1, e2, e3 = aperture_axes(uf_t)
    for i in d['outer_idx']:
        m = MEMBERS[i]
        x, y = xy_final[i]
        print(f"    {m[0]:35s}  x={x:.3f}pc  y={y:.3f}pc  depth={1000/m[5]:.1f}pc")
    print("  Inner square:")
    for i in d['inner_idx']:
        m = MEMBERS[i]
        x, y = xy_final[i]
        print(f"    {m[0]:35s}  x={x:.3f}pc  y={y:.3f}pc  depth={1000/m[5]:.1f}pc")
    print()

# ── Compare to Earth-frame result ────────────────────────────────────────────
print("═══ COMPARISON: EARTH-FRAME vs SOL-APERTURE ═══")
print(f"  Earth-frame tesseract : 403,850 CE  (score 0.434)")
print(f"  Sol-aperture tesseract: {era}  (score {uf_best:.4f})")
print(f"  Difference            : {abs(yr-403850):.0f} years")
print()

# ── Chain relationships ───────────────────────────────────────────────────────
print("═══ SOL-APERTURE CHAIN RELATIONSHIPS ═══")
YZ_hist = 120170.0  # BCE
clew    = 96227.0   # BCE
chry    = 2887.6    # CE
print(f"  Historical YZ: {YZ_hist:.0f} BCE")
print(f"  The Clew:      {clew:.0f} BCE")
print(f"  Chrysalis:     {chry:.0f} CE")
print(f"  Sol-Tesseract: {era}")
if yr > 0:
    print(f"  Tesseract/Chrysalis  = {yr/chry:.5f}  (Earth-frame was 139.89)")
    print(f"  Tesseract/Clew×10   = {yr/clew*10:.5f}  (= 42/10 × 10 = 42 if ~ 42)")
    print(f"  Tesseract/YZ×10     = {yr/YZ_hist*10:.5f}")
elif yr < 0:
    print(f"  |Sol-Tesseract|/Clew = {abs(yr)/clew:.5f}")
    print(f"  |Sol-Tesseract|/YZ   = {abs(yr)/YZ_hist:.5f}")
print()

# ── Aperture scale at the tesseract epoch ────────────────────────────────────
print("═══ APERTURE GEOMETRY AT TESSERACT EPOCH ═══")
P_t = star_3d_at(PRO['ra'], PRO['dec'], PRO['plx'], PRO['mua'], PRO['mud'], uf_t)
G_t = star_3d_at(GOM['ra'], GOM['dec'], GOM['plx'], GOM['mua'], GOM['mud'], uf_t)
chord_t = vsub(G_t, P_t)
chord_len = vlen(chord_t)
e1_t, e2_t, e3_t = aperture_axes(uf_t)
print(f"  Procyon 3D at epoch: {P_t[0]:.3f}, {P_t[1]:.3f}, {P_t[2]:.3f} pc")
print(f"  Gomeisa 3D at epoch: {G_t[0]:.3f}, {G_t[1]:.3f}, {G_t[2]:.3f} pc")
print(f"  Chord P→G length:    {chord_len:.4f} pc = {chord_len*3.2616:.4f} ly")
pro_sky_t = apm_sky(PRO['ra'], PRO['dec'], PRO['mua'], PRO['mud'], uf_t)
gom_sky_t = apm_sky(GOM['ra'], GOM['dec'], GOM['mua'], GOM['mud'], uf_t)
print(f"  Procyon sky at epoch: RA={pro_sky_t[0]/15:.4f}h  Dec={pro_sky_t[1]:+.4f}°")
print(f"  Gomeisa sky at epoch: RA={gom_sky_t[0]/15:.4f}h  Dec={gom_sky_t[1]:+.4f}°")
print()

# ── JSONL output ─────────────────────────────────────────────────────────────
if uf_detail:
    d = uf_detail
    record = {
        "event": "tesseract_sol_aperture",
        "year_ce": yr,
        "era": era,
        "tesseract_score": uf_best,
        "frame": "Sol-Procyon-Gomeisa aperture plane (3D, parsecs)",
        "outer_side_pc": d['outer_side_pc'],
        "inner_side_pc": d['inner_side_pc'],
        "ratio_outer_inner": d['ratio'],
        "rotation_deg": d['rot_deg'],
        "centroid_sep_pc": d['centroid_sep_pc'],
        "outer_stars": [MEMBERS[i][0] for i in d['outer_idx']],
        "inner_stars": [MEMBERS[i][0] for i in d['inner_idx']],
        "procyon_sky_at_epoch": {"ra_h": round(pro_sky_t[0]/15,4), "dec": round(pro_sky_t[1],4)},
        "gomeisa_sky_at_epoch": {"ra_h": round(gom_sky_t[0]/15,4), "dec": round(gom_sky_t[1],4)},
        "chord_pc": round(chord_len,4),
        "earth_frame_epoch_ce": 403850,
        "note": (
            "Tesseract found in Sol-Procyon-Gomeisa aperture frame (3D, not Earth RA/Dec). "
            "Each M44 star's 3D position (from parallax) projected onto the P-G chord plane. "
            "Depth variation across M44 (±43 pc) is now expressed as physical x-spread."
        )
    }
    with open("game/docs/video/tesseract_sol_alignment.jsonl","w") as f:
        f.write(json.dumps(record)+"\n")
    print("tesseract_sol_alignment.jsonl written.")
