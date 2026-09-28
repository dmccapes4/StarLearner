#!/usr/bin/env python3
"""
find_tesseract.py
=================
When do the stars of M44 form a literal tesseract (4D hypercube projection)?

A 2D tesseract = two concentric nested squares:
  Outer 4 stars at distance R, angles 45°,135°,225°,315°
  Inner 4 stars at distance R/√2, angles 0°,90°,180°,270°
  (equivalently inner rotated by exactly 45° from outer; side ratio √2)

Algorithm (fast, two-stage):
  1. For all C(N,4) quadruplets, compute "square score" — how close to a perfect square
  2. Keep the K best squares (low score = good squares)
  3. For all pairs of good squares, check if they form a tesseract
     (concentric, √2 ratio, 45° relative rotation)
  4. Scan over time epochs, tracking the minimum tesseract score
"""

import math, itertools, json

# ── Helpers ──────────────────────────────────────────────────────────────────
def rad(x): return math.radians(x)

def apm_sky(ra0, dec0, mua, mud, dt_yr):
    cd = math.cos(rad(dec0))
    ra  = (ra0  + mua * 1e-3 * dt_yr / (cd * 3600)) % 360
    dec =  dec0 + mud * 1e-3 * dt_yr / 3600
    return ra, dec

def sky_to_xy(pts, center_ra, center_dec):
    """Convert list of (ra,dec) to (x",y") offsets from center (arcseconds)."""
    cd = math.cos(rad(center_dec))
    return [((p[0]-center_ra)*cd*3600, (p[1]-center_dec)*3600) for p in pts]

def dist(a, b): return math.hypot(a[0]-b[0], a[1]-b[1])

def square_score_and_size(xy4):
    """
    Returns (side_len, score) for 4 points.
    score=0 is perfect square; 1 is awful.
    We check: 4 sides equal, 2 diagonals equal, ratio diag/side = √2
    """
    dists = sorted([dist(xy4[i],xy4[j]) for i in range(4) for j in range(i+1,4)])
    # 6 pairwise: 4 sides, 2 diagonals in a square
    if dists[0] < 1e-9: return 0.0, 1e9
    # sides are dists[0..3], diagonals are dists[4..5]
    sides = dists[:4]; diags = dists[4:]
    s = sum(sides)/4; d = sum(diags)/2
    sq2 = math.sqrt(2)
    # Residuals normalized by side
    score = (
        sum((x-s)**2 for x in sides)/(4*s*s) +
        sum((x-s*sq2)**2 for x in diags)/(2*s*s)
    )
    return s, math.sqrt(score)

def centroid(xy4):
    return (sum(p[0] for p in xy4)/4, sum(p[1] for p in xy4)/4)

def rotation_offset(xy4a, xy4b):
    """Mean angle of b-points relative to a-points (both centered). Returns degrees."""
    def angle(p): return math.degrees(math.atan2(p[1],p[0])) % 360
    aa = sorted([angle(p) for p in xy4a])
    ba = sorted([angle(p) for p in xy4b])
    diffs = [(b-a) % 360 for a,b in zip(aa,ba)]
    diffs = [d-360 if d>180 else d for d in diffs]
    return sum(diffs)/4

def tesseract_score_pair(pts1c, size1, pts2c, size2):
    """
    Given two centered 4-point groups and their side lengths, score as a tesseract.
    Returns (total_score, rotation_deg).  Lower score = better tesseract.
    """
    ratio = max(size1,size2)/min(size1,size2) if min(size1,size2)>0 else 99
    ratio_err = abs(ratio - math.sqrt(2)) / math.sqrt(2)
    rot = rotation_offset(pts1c, pts2c)
    rot45 = min(abs((rot % 90) - 45), abs(((rot % 90) - 45 + 90) % 90))
    rot_err = rot45 / 45.0
    return ratio_err + rot_err, rot

# ── M44 member catalog ────────────────────────────────────────────────────────
# From SIMBAD TAP cone search (RA=130.054°, Dec=19.621°, r=2°)
# with pmra∈[-45,-25], pmdec∈[-20,-5], parallax∈[4,7] mas
# J2000 coordinates; pmra = μα* = μα·cosδ [mas/yr]

MEMBERS = [
    # name                        RA°          Dec°        μα*     μδ    plx
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
print(f"M44 catalog: {N} members")
print(f"Cluster center: RA≈130.1°, Dec≈19.7°  |  mean PM: -36.0, -13.0 mas/yr")
print(f"Distance: 186 pc (plx≈5.37 mas)")
print()

# Cluster center (mean)
CEN_RA  = sum(m[1] for m in MEMBERS)/N
CEN_DEC = sum(m[2] for m in MEMBERS)/N

print(f"C({N},4) = {math.comb(N,4):,} quadruplets to evaluate per epoch")
print(f"C({N},8) = {math.comb(N,8):,} octets total (not needed with 2-stage algorithm)")
print()

# ── Two-stage tesseract search ─────────────────────────────────────────────────

SQUARE_THRESHOLD = 0.35   # max square_score to consider "good square"
TESS_THRESHOLD   = 0.80   # max combined tesseract score to save

def get_positions(dt_yr):
    pts = [(apm_sky(m[1],m[2],m[3],m[4],dt_yr)) for m in MEMBERS]
    return sky_to_xy(pts, CEN_RA, CEN_DEC)

def find_best_tesseract_at(dt_yr, verbose=False):
    """Returns (best_score, best_combo, best_detail) at the given epoch."""
    xy = get_positions(dt_yr)

    # Stage 1: find all good squares
    good_squares = []  # (score, side_len, center_xy, indices, xy4_centered)
    for combo in itertools.combinations(range(N), 4):
        pts4 = [xy[i] for i in combo]
        side, sq_score = square_score_and_size(pts4)
        if sq_score < SQUARE_THRESHOLD:
            cx, cy = centroid(pts4)
            pts4c = [(p[0]-cx, p[1]-cy) for p in pts4]
            good_squares.append((sq_score, side, (cx,cy), combo, pts4c))

    if verbose:
        print(f"  Good squares at this epoch: {len(good_squares)}")

    if len(good_squares) < 2:
        return 1e9, None, None

    # Stage 2: pair good squares into tesseracts
    best_score = 1e9
    best_combo = None
    best_detail = None

    for i in range(len(good_squares)):
        for j in range(i+1, len(good_squares)):
            s1, size1, cen1, idx1, pts1 = good_squares[i]
            s2, size2, cen2, idx2, pts2 = good_squares[j]

            # No shared stars
            if set(idx1) & set(idx2): continue

            # Centroids should be close
            cent_sep = dist(cen1, cen2)
            big_side = max(size1, size2)
            if cent_sep > big_side * 0.5: continue  # too far apart

            # Tesseract score
            ts, rot_angle = tesseract_score_pair(pts1, size1, pts2, size2)
            ratio = max(size1,size2)/min(size1,size2) if min(size1,size2)>0 else 99
            cent_err = cent_sep / big_side
            total_score = s1 + s2 + ts + cent_err

            if total_score < best_score:
                best_score = total_score
                best_detail = {
                    'score': total_score,
                    'sq_score_outer': s1, 'sq_score_inner': s2,
                    'ratio': ratio, 'rot_deg': rot_angle,
                    'centroid_sep_arcsec': cent_sep,
                    'outer_side_arcsec': max(size1,size2),
                    'inner_side_arcsec': min(size1,size2),
                    'outer_idx': idx1 if size1>=size2 else idx2,
                    'inner_idx': idx2 if size1>=size2 else idx1,
                }
                best_combo = tuple(sorted(idx1+idx2))

    return best_score, best_combo, best_detail

# ── Coarse scan: every 10,000 years over ±1,000,000 years ─────────────────────
print("=== COARSE SCAN: ±1,000,000 yr at 10,000-yr steps ===")
coarse_best = 1e9; coarse_t = 0
coarse_trace = []
step = 10000
for t in range(-1000000, 1000001, step):
    score, _, _ = find_best_tesseract_at(t)
    coarse_trace.append((t, score))
    if score < coarse_best:
        coarse_best = score; coarse_t = t

print(f"Coarse minimum: t={coarse_t:+d} ({2000+coarse_t:.0f} CE), score={coarse_best:.5f}")

# Find the top 3 coarse minima for context
top3 = sorted(coarse_trace, key=lambda x: x[1])[:3]
print("Top 3 coarse epochs:")
for t, sc in top3:
    yr = 2000+t
    era = f"{abs(yr):.0f} {'BCE' if yr<0 else 'CE'}"
    print(f"  t={t:+8d}  ({era:>15s})  score={sc:.5f}")
print()

# ── Fine scan around the best coarse minimum ──────────────────────────────────
print(f"=== FINE SCAN: {coarse_t-25000} to {coarse_t+25000} at 500-yr steps ===")
fine_best = coarse_best; fine_t = coarse_t
for t in range(coarse_t-25000, coarse_t+25001, 500):
    score, _, _ = find_best_tesseract_at(t)
    if score < fine_best: fine_best = score; fine_t = t
print(f"Fine minimum: t={fine_t:+d} ({2000+fine_t:.0f} CE), score={fine_best:.5f}")

# ── Ultra-fine + full report ─────────────────────────────────────────────────
print(f"=== ULTRA-FINE SCAN: {fine_t-2000} to {fine_t+2000} at 50-yr steps ===")
uf_best = fine_best; uf_t = fine_t; uf_combo = None; uf_detail = None
for t in range(fine_t-2000, fine_t+2001, 50):
    score, combo, detail = find_best_tesseract_at(t, verbose=False)
    if score < uf_best:
        uf_best = score; uf_t = t; uf_combo = combo; uf_detail = detail
print(f"Ultra-fine minimum: t={uf_t:+d}, score={uf_best:.6f}")

# Get final positions
_, uf_combo, uf_detail = find_best_tesseract_at(uf_t, verbose=True)

yr = 2000 + uf_t
era = f"{abs(yr):.0f} {'BCE' if yr<0 else 'CE'}"

print()
print("══════════════════════════════════════════════")
print("  M44 TESSERACT EVENT")
print("══════════════════════════════════════════════")
print(f"  Epoch  : {yr:+.0f} ({era})")
print(f"  Score  : {uf_best:.6f}  (0 = perfect tesseract)")
print()
if uf_detail:
    d = uf_detail
    print(f"  Outer square side  : {d['outer_side_arcsec']:.1f}\"")
    print(f"  Inner square side  : {d['inner_side_arcsec']:.1f}\"")
    print(f"  Ratio outer/inner  : {d['ratio']:.4f}  (ideal √2 = {math.sqrt(2):.4f})")
    print(f"  Rotation angle     : {d['rot_deg']:.2f}°  (ideal ±45°)")
    print(f"  Centroid separation: {d['centroid_sep_arcsec']:.2f}\"")
    print()
    print("  Outer square stars:")
    for i in d['outer_idx']:
        print(f"    {MEMBERS[i][0]}")
    print("  Inner square stars:")
    for i in d['inner_idx']:
        print(f"    {MEMBERS[i][0]}")
    print()

print("═══ ALIGNMENT CHAIN RELATIONSHIPS ═══")
chain = [("Historical Year Zero",116117,False),("The Clew",96227,False),
         ("Chrysalis",2915,True),("Tesseract",abs(yr),yr>0)]
for name,val,is_ce in chain:
    print(f"  {name:25s}: {val:.0f} {'CE' if is_ce else 'BCE'}")
print()
if yr < 0:
    print(f"  Tesseract / Historical YZ = {abs(yr)/116117:.5f}")
    print(f"  Tesseract / Clew          = {abs(yr)/96227:.5f}")
    print(f"  Tesseract / Chrysalis     = {abs(yr)/2915:.5f}")
else:
    print(f"  Tesseract / Chrysalis     = {yr/2915:.5f}")
    print(f"  Chrysalis / Tesseract     = {2915/yr:.5f}")
print()

# JSONL
if uf_detail:
    d = uf_detail
    record = {
        "event": "tesseract", "year_ce": yr, "era": era,
        "tesseract_score": uf_best,
        "outer_side_arcsec": d['outer_side_arcsec'],
        "inner_side_arcsec": d['inner_side_arcsec'],
        "ratio_outer_inner": d['ratio'],
        "rotation_deg": d['rot_deg'],
        "centroid_sep_arcsec": d['centroid_sep_arcsec'],
        "outer_stars": [MEMBERS[i][0] for i in d['outer_idx']],
        "inner_stars": [MEMBERS[i][0] for i in d['inner_idx']],
        "note": "8 M44 members form closest 2D tesseract projection (nested squares, 45° rotation, √2 side ratio)"
    }
    with open("game/docs/video/tesseract_alignment.jsonl","w") as f:
        f.write(json.dumps(record)+"\n")
    print("tesseract_alignment.jsonl written.")
