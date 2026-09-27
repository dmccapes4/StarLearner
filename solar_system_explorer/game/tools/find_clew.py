#!/usr/bin/env python3
"""
find_clew.py
============
The Clew: Sirius, Procyon, Polaris as aperture for M44 (the flower).

Finds the historical moment when Sirius and Procyon are EQUIDISTANT from
M44 — the "two dogs hunt the flower" event. This is Ariadne's clew:
the thread that marks the 4/5 point of the Procyon-Gomeisa cycle.

Full alignment chain:
  120,170 BCE — Procyon + Gomeisa → M44   (historical Year Zero)
   96,227 BCE — Sirius  + Procyon → M44   (the Clew)
    2,887 CE  — Procyon + Gomeisa → M44   (the Chrysalis)

Key fractions:
  Clew / Historical YZ = 4/5  (to 0.08%)
  Clew / Chrysalis     = 100/3 (to 0.03%)

Mythology:
  Polaris = the immutable Cyclops (fixed reference, not a target)
  Sirius+Procyon = the two dogs (Canis Major + Canis Minor)
  M44 = the flower (the labyrinth's center)
  The Clew = the thread that guides through, not into, the labyrinth
"""

import math, json

# ── Star data ────────────────────────────────────────────────────────────────
SIR = dict(ra=101.2872, dec=-16.7161, mua=-546.01, mud=-1223.07, d_ly=8.601,  name="Sirius")
PRO = dict(ra=114.8255, dec=5.2250,   mua=-714.59, mud=-1036.80, d_ly=11.46,  name="Procyon")
POL = dict(ra=37.9546,  dec=89.2641,  mua=44.22,   mud=-11.74,   d_ly=433.0,  name="Polaris")
GOM = dict(ra=111.7877, dec=8.2893,   mua=0.85,    mud=-46.39,   d_ly=162.0,  name="Gomeisa")
M44 = dict(ra=129.8673, dec=19.7373,  mua=-36.0,   mud=-12.9,    d_ly=1683.,  name="M44")

# ── Math ─────────────────────────────────────────────────────────────────────
def xyz(ra,dec):
    r,d=math.radians(ra),math.radians(dec)
    return math.cos(d)*math.cos(r),math.cos(d)*math.sin(r),math.sin(d)
def norm(v): m=math.sqrt(sum(x*x for x in v)); return tuple(x/m for x in v)
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def cross(a,b): return(a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def vsub(a,b): return tuple(x-y for x,y in zip(a,b))
def vscale(v,s): return tuple(x*s for x in v)
def sep_deg(a,b): return math.degrees(math.acos(max(-1,min(1,dot(norm(a),norm(b))))))
def rd(x,y,z):
    m=math.sqrt(x*x+y*y+z*z)
    return math.degrees(math.atan2(y,x))%360, math.degrees(math.asin(max(-1,min(1,z/m))))

def apm(s,dt):
    ra0,dec0,mua,mud=s['ra'],s['dec'],s['mua'],s['mud']
    cd=math.cos(math.radians(dec0))
    return (ra0+mua*1e-3*dt/(cd*3600))%360, dec0+mud*1e-3*dt/3600

def face_sep_pair(s1,s2,target,dt=0):
    pv=norm(xyz(*apm(s1,dt))); gv=norm(xyz(*apm(s2,dt))); mv=norm(xyz(*apm(target,dt)))
    chord=norm(vsub(gv,pv)); m_along=dot(mv,chord)
    m_perp=norm(vsub(mv,vscale(chord,m_along)))
    return math.degrees(math.acos(max(-1,min(1,dot(m_perp,mv)))))

J2000=2000.0

# ── Scan for Sirius-Procyon → M44 alignment ──────────────────────────────────
best_t, best_f = 0, 999
for t in range(-200000, 200001, 200):
    f = face_sep_pair(SIR,PRO,M44,t)
    if f < best_f: best_f=f; best_t=t
for t in range(best_t-500, best_t+501, 5):
    f = face_sep_pair(SIR,PRO,M44,t)
    if f < best_f: best_f=f; best_t=t
lo,hi=best_t-50,best_t+50
phi=(math.sqrt(5)-1)/2
for _ in range(80):
    c=hi-phi*(hi-lo); d=lo+phi*(hi-lo)
    if face_sep_pair(SIR,PRO,M44,c) < face_sep_pair(SIR,PRO,M44,d): hi=d
    else: lo=c
    if abs(hi-lo)<0.001: break
t_clew=(lo+hi)/2
yr_clew = J2000+t_clew
f_clew = face_sep_pair(SIR,PRO,M44,t_clew)

sir_ra,sir_dec=apm(SIR,t_clew)
pro_ra,pro_dec=apm(PRO,t_clew)
m_ra, m_dec  =apm(M44,t_clew)
pol_ra,pol_dec=apm(POL,t_clew)
gom_ra,gom_dec=apm(GOM,t_clew)

d_sir_m44 = sep_deg(xyz(sir_ra,sir_dec), xyz(m_ra,m_dec))
d_pro_m44 = sep_deg(xyz(pro_ra,pro_dec), xyz(m_ra,m_dec))
d_sir_pro = sep_deg(xyz(sir_ra,sir_dec), xyz(pro_ra,pro_dec))

print("═══ THE CLEW EVENT ═══")
print(f"Year           : {yr_clew:+.1f}  ({abs(yr_clew):.0f} BCE)")
print(f"Face→M44       : {f_clew:.2e}°")
print(f"Sirius-M44 sep : {d_sir_m44:.6f}°")
print(f"Procyon-M44 sep: {d_pro_m44:.6f}°  (equidistant: {abs(d_sir_m44-d_pro_m44)<0.001})")
print(f"Sirius-Proc sep: {d_sir_pro:.4f}°")
print()
print("Positions at Clew epoch:")
for (name,ra,dec) in [("Sirius",sir_ra,sir_dec),("M44",m_ra,m_dec),
                      ("Procyon",pro_ra,pro_dec),("Gomeisa",gom_ra,gom_dec),
                      ("Polaris",pol_ra,pol_dec)]:
    print(f"  {name:10s}: RA {ra/15:.4f}h  Dec {dec:+.4f}°")
print()

# ── Fractional structure ──────────────────────────────────────────────────────
YZ_hist = 120170.0  # BCE
YZ_chry = 2887.6    # CE

print("═══ FRACTIONAL STRUCTURE ═══")
print(f"Historical YZ: {YZ_hist:.0f} BCE")
print(f"Clew event   : {abs(yr_clew):.1f} BCE")
print(f"Chrysalis    : {YZ_chry:.1f} CE")
print()
print(f"Clew / Historical YZ = {abs(yr_clew)/YZ_hist:.5f}  (vs 4/5 = {4/5:.5f}, diff={abs(abs(yr_clew)/YZ_hist - 4/5)*100:.3f}%)")
print(f"Clew / Chrysalis     = {abs(yr_clew)/YZ_chry:.5f}  (vs 100/3 = {100/3:.5f}, diff={abs(abs(yr_clew)/YZ_chry - 100/3)*100:.3f}%)")
print(f"Historical YZ / Clew = {YZ_hist/abs(yr_clew):.5f}  (vs 5/4 = {5/4:.5f})")
print()

gap1 = YZ_hist - abs(yr_clew)
gap2 = abs(yr_clew) + YZ_chry
print(f"Gap: Historical YZ → Clew   = {gap1:.0f} yr  ({gap1/25772:.3f} precession cycles)")
print(f"Gap: Clew → Chrysalis        = {gap2:.0f} yr  ({gap2/25772:.3f} precession cycles)")
print(f"Ratio: Clew→Chrysalis / YZ→Clew = {gap2/gap1:.4f}  (vs 4 = 4.000)")
print()

# ── JSONL output ──────────────────────────────────────────────────────────────
records = [
    {"event": "clew", "year_bce": abs(yr_clew), "year_ce": yr_clew,
     "face_sep_deg": f_clew,
     "sirius_ra_h": round(sir_ra/15,6), "sirius_dec": round(sir_dec,6),
     "procyon_ra_h": round(pro_ra/15,6), "procyon_dec": round(pro_dec,6),
     "m44_ra_h": round(m_ra/15,6), "m44_dec": round(m_dec,6),
     "polaris_ra_h": round(pol_ra/15,6), "polaris_dec": round(pol_dec,6),
     "sirius_m44_sep": round(d_sir_m44,6),
     "procyon_m44_sep": round(d_pro_m44,6),
     "sirius_procyon_sep": round(d_sir_pro,4),
     "clew_div_histyz": round(abs(yr_clew)/YZ_hist,6),
     "clew_div_chrysalis": round(abs(yr_clew)/YZ_chry,6),
     "note": "Sirius-Procyon equidistant from M44. Clew = 4/5 × 120170 BCE = 100/3 × 2887 CE"},
]
with open("game/docs/video/clew_alignment.jsonl","w") as f:
    for r in records:
        f.write(json.dumps(r)+"\n")
print("clew_alignment.jsonl written.")
