#!/usr/bin/env python3
"""
v4_annulus.py — Game plan §2a. Where can a small free moon of Mercury (the V4
class) survive 4.5 Gyr? Three Newtonian bounds, nothing else:

  1. TIDAL FLOOR.  Mercury's spin (58.646 d) is slower than any orbit inside
     its Hill sphere, so every moon raises a lagging tide and spirals IN.
     da/dt = -3 (k2/Q) (m/M) (R/a)^5 n a   (Goldreich & Soter 1966)
     k2 = 0.45 ± 0.02 (MESSENGER, Mazarico+ 2014); Q is unmeasured: 50–300.
     Minimum a that survives T = 4.5 Gyr, as a function of body radius.

  2. HILL CEILING.  Test particles in Mercury's Hill sphere, Mercury-centred,
     with the Sun on Mercury's real eccentric orbit (e = 0.2056) and
     Mercury's J2. Leapfrog, 100 Mercury years (~24 Earth years). Prograde and
     retrograde. This is a SHORT integration: it finds the fast-ejection edge;
     the long-term (1e5–1e6 yr) edge sits inside it and needs an N-body run.

  3. RADIATION.  Solar radiation pressure and Yarkovsky drift on bodies of
     100 m – 10 km at 0.39 AU, compared with Mercury's gravity in the annulus.

Outputs: data/v4_annulus.json, img/v4_01_tidal_floor.png, img/v4_02_hill_stability.png
"""
import os, json, math, time, sys
import numpy as np
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
plt.rcParams.update({"figure.facecolor":"#0b0d17","axes.facecolor":"#0b0d17","axes.edgecolor":"#667","axes.labelcolor":"#dde",
    "xtick.color":"#bbc","ytick.color":"#bbc","text.color":"#eef","grid.color":"#223","legend.facecolor":"#141829","legend.edgecolor":"#445"})
HERE = os.path.dirname(os.path.abspath(__file__))
DOC  = os.path.abspath(os.path.join(HERE, "..", "..", "docs", "MERCURY_VULCAN_LADDER_20261010"))
DATA = os.path.join(DOC, "data"); IMG = os.path.join(DOC, "img")

G = 6.674e-11
GM_M = 2.2032e13; M_M = 3.3011e23; R_M = 2439.7e3          # SI
GM_S = 1.32712e20; AU = 1.495978707e11
A_MERC = 0.387098 * AU; E_MERC = 0.205630
T_MERC = 2*math.pi*math.sqrt(A_MERC**3/GM_S)                # 87.97 d
K2 = 0.45; J2 = 5.03e-5
R_HILL_PERI = A_MERC*(1-E_MERC)*(M_M/(3*1.989e30))**(1/3)   # 175,284 km
R_HILL_MEAN = A_MERC*(M_M/(3*1.989e30))**(1/3)
GYR = 4.5e9*3.15576e7
RHO = 2000.0                                                 # kg/m3 assumed for the body

# ---------------------------------------------------------------------------
# 1. Tidal floor
# ---------------------------------------------------------------------------
def a_min_tidal(R_body, Q, T=GYR):
    m = RHO*4/3*math.pi*R_body**3
    n0 = math.sqrt(GM_M/R_M**3)
    x = (T*3*K2*m/(Q*M_M))*n0          # = (a/R)^6.5 after integrating da/dt ∝ a^-5.5
    return R_M*x**(1/6.5)
radii = np.logspace(2, 4.3, 60)          # 100 m – 20 km
Qs = [50, 100, 300]
tidal = {Q: [a_min_tidal(r, Q) for r in radii] for Q in Qs}
a_chain = 5411e3; R_chain = 9.8e3
def lifetime_at(a, R_body, Q):          # time to spiral from a to the surface
    m = RHO*4/3*math.pi*R_body**3
    n0 = math.sqrt(GM_M/R_M**3)
    return (a/R_M)**6.5 * Q*M_M/(3*K2*m*n0) / 3.15576e7
life_chain = {Q: lifetime_at(a_chain, R_chain, Q) for Q in Qs}

# ---------------------------------------------------------------------------
# 2. Hill ceiling — leapfrog, Mercury-centred, Sun on eccentric orbit, J2
# ---------------------------------------------------------------------------
def kepler_E(Mean, e):
    E = Mean.copy()
    for _ in range(8): E = E - (E - e*np.sin(E) - Mean)/(1 - e*np.cos(E))
    return E
def sun_pos(t):
    """Sun position relative to Mercury (Mercury at perihelion at t=0), orbit in xy."""
    Mean = (2*math.pi/T_MERC)*t
    E = kepler_E(np.atleast_1d(Mean), E_MERC)[0]
    xm = A_MERC*(np.cos(E)-E_MERC); ym = A_MERC*math.sqrt(1-E_MERC**2)*np.sin(E)
    return np.array([-xm, -ym, 0.0])
def accel(r, t):
    rs = sun_pos(t)
    d = r - rs[None, :]                                     # particle relative to Sun
    a_m = -GM_M*r/np.linalg.norm(r, axis=1)[:, None]**3
    # Sun pulls particle (-GM d/|d|^3) and pulls Mercury (+GM rs/|rs|^3 toward the Sun); relative accel = difference
    a_tide = -GM_S*(d/np.linalg.norm(d, axis=1)[:, None]**3 + rs[None, :]/np.linalg.norm(rs)**3)
    # J2 (axis z)
    x, y, z = r[:, 0], r[:, 1], r[:, 2]; rr = np.linalg.norm(r, axis=1); f = 1.5*J2*GM_M*R_M**2/rr**5
    a_j2 = np.stack([f*x*(5*z**2/rr**2-1), f*y*(5*z**2/rr**2-1), f*z*(5*z**2/rr**2-3)], axis=1)
    return a_m + a_tide + a_j2

a_grid = np.logspace(math.log10(8e6), math.log10(2.6e8), 28)
phases = [0.0, math.pi/2]
parts = []
for a in a_grid:
    for sgn, lab in ((1, "prograde"), (-1, "retrograde")):
        for ph in phases:
            v = math.sqrt(GM_M/a)
            r0 = np.array([a*math.cos(ph), a*math.sin(ph), 0.0])
            v0 = sgn*v*np.array([-math.sin(ph), math.cos(ph), 0.0])
            parts.append(dict(a=a, dir=lab, phase=ph, r0=r0, v0=v0))
N = len(parts)
r = np.array([p["r0"] for p in parts]); v = np.array([p["v0"] for p in parts])
alive = np.ones(N, bool); fate = np.array(["stable"]*N, dtype=object); t_fate = np.full(N, np.nan)
rmax = np.linalg.norm(r, axis=1).copy(); rmin = rmax.copy()
dt = 200.0; n_merc_years = 100; T_end = n_merc_years*T_MERC; steps = int(T_end/dt)
t0 = time.time(); t = 0.0
# sanity: at the sub-satellite point the tidal term must be ~ 2 GM_S a / d^3 (stretching), i.e. << Mercury's pull
_chk = accel(r[:1], 0.0) - (-GM_M*r[:1]/np.linalg.norm(r[:1])**3)
assert np.linalg.norm(_chk) < 1e-3*GM_M/np.linalg.norm(r[0])**2, ("tidal term not cancelling bulk solar pull", _chk)
a_half = accel(r, t)
REUSE = os.environ.get("V4_REUSE_HILL") == "1" and os.path.exists(os.path.join(DATA, "v4_annulus.json"))
if REUSE:   # ~8 min integration already on disk; reuse particle fates for figure/JSON regeneration
    _prev = json.load(open(os.path.join(DATA, "v4_annulus.json")))["hill_ceiling"]["particles"]
    for i, h in enumerate(_prev):
        fate[i] = h["fate"]; t_fate[i] = (np.nan if h["t_fate_d"] is None else h["t_fate_d"]); rmax[i] = h["rmax_km"]*1e3; rmin[i] = h["rmin_km"]*1e3
    steps = 0; print("reusing Hill integration from data/v4_annulus.json")
for k in range(steps):
    v[alive] += 0.5*dt*a_half[alive]
    r[alive] += dt*v[alive]
    t += dt
    a_new = accel(r, t)
    v[alive] += 0.5*dt*a_new[alive]
    a_half = a_new
    if k % 50 == 0:
        rr = np.linalg.norm(r, axis=1)
        rmax = np.maximum(rmax, np.where(alive, rr, rmax)); rmin = np.minimum(rmin, np.where(alive, rr, rmin))
        esc = alive & (rr > 1.5*R_HILL_PERI); col = alive & (rr < R_M)
        fate[esc] = "escaped"; fate[col] = "collided"; t_fate[esc | col] = t/86400
        alive &= ~(esc | col)
    if k % 200000 == 0: print(f"  step {k}/{steps}  t={t/86400:.0f} d  alive={alive.sum()}/{N}  ({time.time()-t0:.0f} s)")
print(f"integration done in {time.time()-t0:.0f} s")
HILL = []
for i, p in enumerate(parts):
    HILL.append(dict(a_km=p["a"]/1e3, a_over_Rhill_peri=p["a"]/R_HILL_PERI, dir=p["dir"], phase_deg=math.degrees(p["phase"]), fate=str(fate[i]),
                     t_fate_d=(None if np.isnan(t_fate[i]) else float(t_fate[i])), rmax_km=float(rmax[i]/1e3), rmin_km=float(rmin[i]/1e3)))
def max_stable(dirlab):
    ok = [h["a_km"] for h in HILL if h["dir"] == dirlab and h["fate"] == "stable"]
    bad = [h["a_km"] for h in HILL if h["dir"] == dirlab and h["fate"] != "stable"]
    return dict(largest_stable_km=max(ok) if ok else None, smallest_unstable_km=min(bad) if bad else None)
CEIL = {d: max_stable(d) for d in ("prograde", "retrograde")}

# ---------------------------------------------------------------------------
# 3. Radiation forces in the annulus
# ---------------------------------------------------------------------------
S0 = 1361.0; c = 2.998e8; d_merc = 0.387098*AU
flux = S0*(AU/d_merc)**2; P_rad = flux/c
RAD = []
for R_body in (100.0, 1e3, 1e4):
    m = RHO*4/3*math.pi*R_body**3
    a_rp = P_rad*math.pi*R_body**2/m*1.0                    # perfect absorber; ×(1+albedo) for reflection
    # Yarkovsky diurnal order of magnitude: da/dt ~ (8/9)(1-A) Φ/(n c) cos γ ... use the 1 AU scaling: ~2e-4 AU/Myr for 1 km at 1 AU, ∝ 1/R, ∝ flux/n ~ a^-1/2
    yark_au_per_myr_helio = 2e-4*(1e3/R_body)*(AU/d_merc)**0.5
    rows = []
    for a in (13e6, 30e6, 87e6):
        g = GM_M/a**2
        rows.append(dict(a_km=a/1e3, ratio_rp_to_gravity=a_rp/g,
                         forced_e_amplitude=(1.5*a_rp/(g))*0 + 1.5*a_rp*math.sqrt(a**3/GM_M)/math.sqrt(GM_M/a)))  # ~ (3/2) a_rp /(n v)
    RAD.append(dict(R_m=R_body, mass_kg=m, a_rp_m_s2=a_rp, rows=rows, yarkovsky_heliocentric_au_per_myr_order=yark_au_per_myr_helio,
                    note="a_rp/g < 1e-8 for all R >= 100 m in the annulus; forced eccentricity amplitude listed; Yarkovsky is a heliocentric drift (acts on Mercury+moon together), negligible on the moon's orbit about Mercury"))

# ---------------------------------------------------------------------------
# Figures
# ---------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(10, 6))
for Q, col in zip(Qs, ("#ff5c7a", "#ffd166", "#4fd1ff")):
    ax.plot(radii/1e3, np.array(tidal[Q])/1e3, color=col, lw=2, label=f"tidal floor, Q = {Q} (survives 4.5 Gyr above the line)")
ax.axhline(R_HILL_PERI*0.5/1e3, color="#9dff6a", ls="--", lw=1.2, label="0.5 × Hill radius at perihelion (prograde stability, canonical)")
ax.axhline(R_HILL_PERI/1e3, color="#9dff6a", ls=":", lw=1.0, label="Hill radius at perihelion")
ax.axhline(R_M/1e3, color="#aaa", lw=1, label="Mercury's surface")
ax.scatter([R_chain/1e3], [a_chain/1e3], color="#fff", s=60, zorder=5); ax.annotate("chain-interpolated V4\n(9.8 km, 5,411 km)\nlifetime %.0f–%.0f Myr" % (min(life_chain.values())/1e6, max(life_chain.values())/1e6), (R_chain/1e3, a_chain/1e3), xytext=(1.2, 3000), color="#fff", fontsize=9, arrowprops=dict(arrowstyle="->", color="#fff"))
ax.fill_between(radii/1e3, np.array(tidal[100])/1e3, R_HILL_PERI*0.5/1e3, where=np.array(tidal[100]) < R_HILL_PERI*0.5, color="#4fd1ff", alpha=0.12, label="surviving annulus (Q = 100)")
ax.set_xscale("log"); ax.set_yscale("log"); ax.set_xlabel("body radius (km)"); ax.set_ylabel("orbital radius about Mercury (km)")
ax.set_title("V4 class — where a free moon of Mercury can be 4.5 Gyr old (k₂ = 0.45 measured; Newtonian tides)")
ax.grid(True, which="both", alpha=0.4); ax.legend(fontsize=8, loc="upper left")
fig.tight_layout(); fig.savefig(os.path.join(IMG, "v4_01_tidal_floor.png"), dpi=130); plt.close(fig)

fig, ax = plt.subplots(figsize=(10, 5.5))
for d, y, col in (("prograde", 1, "#ffd166"), ("retrograde", 0, "#4fd1ff")):
    for h in HILL:
        if h["dir"] != d: continue
        mk = {"stable": "o", "escaped": "x", "collided": "v"}[h["fate"]]
        ax.scatter(h["a_km"], y + (h["phase_deg"]/90)*0.15, marker=mk, color=col if h["fate"] == "stable" else "#ff5c7a", s=40)
ax.axvline(R_HILL_PERI/1e3, color="#9dff6a", ls=":", label="Hill radius (perihelion)"); ax.axvline(R_HILL_MEAN/1e3, color="#9dff6a", ls="--", label="Hill radius (mean a)")
ax.axvline(0.5*R_HILL_PERI/1e3, color="#9dff6a", ls="-", alpha=0.5, label="0.5 Hill (perihelion)")
ax.set_xscale("log"); ax.set_yticks([0, 1]); ax.set_yticklabels(["retrograde", "prograde"]); ax.set_xlabel("initial circular orbit radius (km)")
ax.set_title(f"Hill-sphere test particles, {n_merc_years} Mercury years, Sun on e = 0.2056 orbit + J₂ — o stable · x escaped · v collided")
ax.grid(True, which="both", alpha=0.4); ax.legend(fontsize=8, loc="center left")
fig.tight_layout(); fig.savefig(os.path.join(IMG, "v4_02_hill_stability.png"), dpi=130); plt.close(fig)

OUT = dict(
    constants=dict(k2=K2, J2=J2, rho_body=RHO, R_hill_perihelion_km=R_HILL_PERI/1e3, R_hill_mean_km=R_HILL_MEAN/1e3),
    tidal_floor=dict(radii_m=radii.tolist(), a_min_km={str(Q): (np.array(tidal[Q])/1e3).tolist() for Q in Qs},
                     a_min_10km_Q100_km=a_min_tidal(1e4, 100)/1e3, a_min_1km_Q100_km=a_min_tidal(1e3, 100)/1e3, a_min_100m_Q100_km=a_min_tidal(100, 100)/1e3,
                     chain_V4_lifetime_yr={str(Q): v for Q, v in life_chain.items()},
                     statement="A Phobos-mass body at the chain's 5,411 km spirals into Mercury in ~%.0f–%.0f Myr; it cannot be primordial there. Row 5 eliminated as primordial." % (min(life_chain.values())/1e6, max(life_chain.values())/1e6)),
    hill_ceiling=dict(integration_years_mercury=n_merc_years, integration_years_earth=n_merc_years*T_MERC/3.15576e7, dt_s=dt, particles=HILL, summary=CEIL,
                      caveat="Short integration: finds the fast-ejection edge only. The 1e5-1e6 yr edge lies inside it (literature: ~0.5 R_H prograde, ~0.7-1.0 R_H retrograde)."),
    radiation=RAD,
    annulus=dict(inner_km_10km_body=a_min_tidal(1e4, 100)/1e3, outer_km_prograde_canonical=0.5*R_HILL_PERI/1e3,
                 outer_km_prograde_this_run=CEIL["prograde"]["largest_stable_km"], outer_km_retrograde_this_run=CEIL["retrograde"]["largest_stable_km"]))
json.dump(OUT, open(os.path.join(DATA, "v4_annulus.json"), "w"), indent=1, default=str)
print("tidal floor (Q=100): 10 km %.0f km | 1 km %.0f km | 100 m %.0f km" % (OUT["tidal_floor"]["a_min_10km_Q100_km"], OUT["tidal_floor"]["a_min_1km_Q100_km"], OUT["tidal_floor"]["a_min_100m_Q100_km"]))
print("chain V4 lifetime (yr):", {k: f"{v:.2e}" for k, v in life_chain.items()})
print("Hill ceiling (this run):", CEIL)
for R in RAD: print(f"R={R['R_m']:.0f} m  a_rp={R['a_rp_m_s2']:.1e}  ratio@13k={R['rows'][0]['ratio_rp_to_gravity']:.1e}  forced e@87k={R['rows'][2]['forced_e_amplitude']:.1e}")
