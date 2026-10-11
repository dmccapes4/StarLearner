#!/usr/bin/env python3
"""
vulcan_derivation.py — Mercury/Vulcan under the stated axiom, with every
consequence computed Newtonianly and compared against measurement.

AXIOM (accepted for the experiment):
  Vulcan is bound to Mercury like Charon to Pluto, and is ALWAYS on the far
  side of Mercury from Earth (Config A: Earth -> Moon -> Mercury -> Vulcan).
  During the rare configuration when the Moon is between Earth and Mercury
  the order may invert (Config B: Earth -> Moon -> Vulcan -> Mercury).

What this script does
  1. Builds four Vulcan variants (mass/size/separation) from the analogies
     the user supplied (Charon-scaled, spin-locked, Earth-synchronous,
     chain-scaled) and tests each against Kepler III and the Hill sphere.
  2. Uses the JPL DE421 ephemeris (real Earth/Mercury/Moon geometry) to
     compute, hour by hour over 2026-2028, the Earth->Mercury direction, its
     angular rate and angular acceleration, and therefore the acceleration a
     Vulcan would NEED to stay anti-Earth. That is compared with the
     acceleration Mercury's gravity can SUPPLY. The mismatch is the
     refutation margin; the free-fall radius that would match the rate is
     compared with Mercury's Hill radius.
  3. Hiddenness: whether Vulcan could stay behind Mercury's disc from (a)
     Earth's centre, (b) Earth's limb, (c) a camera on the lunar far side,
     (d) Sun-Earth L2 — by parallax, for each separation.
  4. Mercury's reflex (barycentric) wobble for each variant vs ranging precision.
  5. Lunar occultations of Mercury 2026-2030 (geocentric, with the band where
     a topocentric occultation is possible) — the dates on which Config B is
     testable.
  6. Mercury's perihelion precession WITHOUT relativity: the solar J2 that a
     Newtonian model would need, and what that same J2 predicts for Venus,
     Earth, Mars and Icarus against their measured anomalous precessions.
Outputs: data/vulcan_derivation.json, data/lunar_occultations_mercury.csv,
         img/vulcan_*.png, data/ephem_*.json for Godot.
"""
import os, json, math, csv, sys
import numpy as np
from skyfield.api import Loader
from skyfield.framelib import ecliptic_frame

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bodies import BODIES, derive, G, AU_KM, DAY_S, YEAR_D, M_SUN, kepler_period_d, kepler_a_km, hill_radius_km

HERE   = os.path.dirname(os.path.abspath(__file__))
DOC    = os.path.abspath(os.path.join(HERE, "..", "..", "docs", "MERCURY_VULCAN_LADDER_20261010"))
DATA   = os.path.join(DOC, "data"); IMG = os.path.join(DOC, "img")
os.makedirs(DATA, exist_ok=True); os.makedirs(IMG, exist_ok=True)

import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
plt.rcParams.update({"figure.facecolor":"#0b0d17","axes.facecolor":"#0b0d17","axes.edgecolor":"#667",
    "axes.labelcolor":"#dde","xtick.color":"#bbc","ytick.color":"#bbc","text.color":"#eef",
    "grid.color":"#223","grid.alpha":0.6,"legend.facecolor":"#141829","legend.edgecolor":"#445"})

M   = derive()
MER = M["mercury"]; EAR = M["earth"]; LUN = M["luna"]; PLU = M["pluto"]; CHA = M["charon"]
GM_M = MER["gm_km3s2"]*1e9            # m^3/s^2
M_M  = MER["mass_kg"]; R_M = MER["r_mean_km"]
HILL_PERI = MER["hill_radius_km"]      # at perihelion (conservative)
HILL_MEAN = MER["a_km"]*(M_M/(3*M_SUN))**(1/3)
R_EARTH = 6378.137; D_MOON = 384400.0; D_L2 = 1.5e6

# ---------------------------------------------------------------------------
# 1. Vulcan variants
# ---------------------------------------------------------------------------
q_charon  = CHA["mass_ratio_to_primary"]          # 0.1217
k_charon  = CHA["radius_ratio_to_primary"]        # 0.510
s_charon  = CHA["separation_primary_radii"]       # 16.49
# chain-scaled: user's final chain places Mercury/Vulcan between Saturn/rings and Mars/moons
q_sat_rings = M["saturn"]["ring_to_primary_mass_ratio"]
q_mars_moons = M["mars"]["moons_to_primary_mass_ratio"]
q_chain = math.sqrt(q_sat_rings*q_mars_moons)

def radius_from_mass(m, rho): return (3*m/(4*math.pi*rho))**(1/3)/1e3

VARIANTS = {}
def add_variant(key, label, q, R_V_km, a_km, how):
    T = kepler_period_d(a_km, M_M*(1+q))
    VARIANTS[key] = dict(label=label, mass_ratio=q, mass_kg=q*M_M, radius_km=R_V_km,
        separation_km=a_km, separation_R_M=a_km/R_M, kepler_period_d=T,
        separation_over_hill_peri=a_km/HILL_PERI, separation_over_hill_mean=a_km/HILL_MEAN,
        bound_in_hill_sphere=a_km < HILL_PERI,
        mercury_reflex_km=a_km*q/(1+q), mercury_reflex_over_R_M=a_km*q/(1+q)/R_M,
        barycenter_outside_mercury=a_km*q/(1+q) > R_M,
        derivation=how)

# V1: Charon-scaled (user's primary analogy)
add_variant("charon_scaled", "V1 Charon-scaled", q_charon, k_charon*R_M, s_charon*R_M,
    "q=M_Charon/M_Pluto, R_V=0.510 R_M, a=16.49 R_M (Pluto/Charon ratios applied to Mercury)")
# V2: spin-locked: mutual lock like Pluto/Charon => Vulcan period = Mercury's spin 58.646 d
a_lock = kepler_a_km(abs(MER["rot_d"]), M_M*(1+q_charon))
add_variant("spin_locked", "V2 Spin-locked (58.646 d)", q_charon, k_charon*R_M, a_lock,
    "Mutual tidal lock like Pluto/Charon: orbital period = Mercury's measured sidereal spin 58.646 d; a from Kepler III")
# V3: Earth-synchronous (strict axiom: mean period of the Earth->Mercury direction = 1 sidereal yr)
a_sync = kepler_a_km(365.256, M_M*(1+q_charon))
add_variant("earth_synchronous", "V3 Earth-synchronous (365.26 d)", q_charon, k_charon*R_M, a_sync,
    "Strict anti-Earth lock: the Earth->Mercury direction turns once per sidereal year on average; a from Kepler III")
# V4: chain-scaled (Phobos-class)
R_chain = radius_from_mass(q_chain*M_M, 1876.0)
add_variant("chain_scaled", "V4 Chain-scaled (Phobos-class)", q_chain, R_chain, s_charon*R_M,
    "From 'Saturn/rings is to Mercury/Vulcan is to Mars/moons': q = sqrt(q_SaturnRings * q_MarsMoons); rho = Phobos; a = 16.49 R_M")

# ---------------------------------------------------------------------------
# 2. DE421 kinematics of the anti-Earth lock
# ---------------------------------------------------------------------------
load = Loader("/tmp/skyfield-data")
eph  = load("de421.bsp"); ts = load.timescale()
sun, mercury, venus, earth, moon, mars = (eph["sun"], eph["mercury"], eph["venus"], eph["earth"], eph["moon"], eph["mars"])

def ecl_xyz_km(body, t):
    """Barycentric position in the J2000 ecliptic frame, km, shape (3,N)."""
    return body.at(t).frame_xyz(ecliptic_frame).km

STEP_H = 1.0
N = int(2*365.25*24/STEP_H)
t = ts.utc(2026, 1, 1, np.arange(N)*STEP_H)
jd = t.tt
rE = ecl_xyz_km(earth, t); rM = ecl_xyz_km(mercury, t); rS = ecl_xyz_km(sun, t)
rMo = ecl_xyz_km(moon, t); rV = ecl_xyz_km(venus, t); rMa = ecl_xyz_km(mars, t)
d = rM - rE                                  # Earth -> Mercury
D = np.linalg.norm(d, axis=0)                # km
u = d / D                                    # unit vector; Vulcan at rM + a*u (Config A)
dt = STEP_H*3600.0
udot  = np.gradient(u, dt, axis=1)
uddot = np.gradient(udot, dt, axis=1)
omega = np.linalg.norm(udot, axis=0)         # rad/s : angular rate of the Earth->Mercury line
P_inst_d = 2*math.pi/omega/DAY_S             # implied instantaneous Vulcan period (days)
# required relative acceleration for Vulcan at separation a: a*uddot. Decompose along u / perpendicular.
udd_rad  = np.einsum("ij,ij->j", uddot, u)   # should be -omega^2
udd_perp = np.linalg.norm(uddot - udd_rad*u, axis=0)
# free-fall radius matching omega(t): GM/a^2 = a*omega^2
a_ff = (GM_M/omega**2)**(1/3)/1e3            # km
# Elongation of Mercury (Sun-Earth-Mercury angle)
s = rS - rE; S = np.linalg.norm(s, axis=0)
elong = np.degrees(np.arccos(np.einsum("ij,ij->j", d, s)/(D*S)))
# sign of elongation: east/west via ecliptic z of cross(s,d)
east = np.cross(s.T, d.T)[:,2] > 0

KIN = {}
for key, v in VARIANTS.items():
    a = v["separation_km"]*1e3
    g_avail = GM_M/a**2                                  # m/s^2 Mercury gravity at a
    a_req_rad = a*omega**2                               # m/s^2 centripetal needed
    a_req_tan = a*udd_perp                               # m/s^2 tangential needed (no central force can supply)
    # solar tidal acceleration at separation a (order of magnitude), along Sun line
    r_helio = np.linalg.norm(rM - rS, axis=0)*1e3
    a_tide = 2*G*M_SUN*a/r_helio**3
    KIN[key] = dict(
        gravity_available_ms2=g_avail,
        centripetal_required_ms2_mean=float(a_req_rad.mean()), centripetal_required_ms2_max=float(a_req_rad.max()),
        tangential_required_ms2_mean=float(a_req_tan.mean()), tangential_required_ms2_max=float(a_req_tan.max()),
        solar_tide_ms2_mean=float(a_tide.mean()),
        gravity_over_centripetal_mean=float(g_avail/a_req_rad.mean()),
        nongravitational_force_needed_ms2_mean=float((g_avail - a_req_rad).mean()),
        verdict=("Mercury's gravity exceeds the required centripetal acceleration by %.0fx: a free Vulcan here would "
                 "orbit in %.2f d, not track Earth. Holding the lock needs a sustained outward push of %.3g m/s^2 "
                 "plus a tangential push of up to %.3g m/s^2 that no central force can supply."
                 % (g_avail/a_req_rad.mean(), v["kepler_period_d"], (g_avail-a_req_rad).mean(), a_req_tan.max()))
        if g_avail/a_req_rad.mean() > 1.5 else
        ("Centripetal requirement is met in the mean, but the separation is %.2fx Mercury's Hill radius: the Sun's "
         "gravity gradient dominates and the orbit is not bound." % v["separation_over_hill_peri"]))

LOCK = dict(step_hours=STEP_H, span="2026-01-01 .. 2027-12-31",
    omega_mean_rad_s=float(omega.mean()), omega_min_rad_s=float(omega.min()), omega_max_rad_s=float(omega.max()),
    implied_period_mean_d=float((2*math.pi/omega.mean())/DAY_S),
    implied_period_min_d=float(P_inst_d.min()), implied_period_max_d=float(P_inst_d.max()),
    free_fall_radius_km_min=float(a_ff.min()), free_fall_radius_km_max=float(a_ff.max()), free_fall_radius_km_mean=float(a_ff.mean()),
    hill_radius_perihelion_km=HILL_PERI, hill_radius_mean_km=HILL_MEAN,
    free_fall_over_hill_min=float(a_ff.min()/HILL_PERI),
    fraction_of_time_free_fall_inside_hill=float((a_ff < HILL_PERI).mean()),
    note="The Earth->Mercury line turns once per year on average (because Mercury never strays more than ~28 deg "
         "from the Sun, the line follows the Earth->Sun line and librates about it with the 115.9-d synodic period). "
         "A Vulcan tracking it would need the orbital angular rate of a 1-year orbit; around Mercury that radius is "
         "always outside the Hill sphere.")

# ---------------------------------------------------------------------------
# 3. Hiddenness by parallax
# ---------------------------------------------------------------------------
def hidden_fraction(a_km, R_V_km, baseline_km, near_side=False):
    """Fraction of time Vulcan's disc is fully inside Mercury's disc for an observer displaced
    perpendicular to the line of sight by `baseline_km`. Far side: Vulcan at D+a; near side: D-a."""
    Dv = D - a_km if near_side else D + a_km
    ang_M = R_M/D; ang_V = R_V_km/Dv
    par = baseline_km*a_km/(D*Dv)                       # relative parallax shift (rad)
    hidden = (par + ang_V) < ang_M
    return float(hidden.mean()), float(np.degrees(par.max())*3600), float(np.degrees(ang_M.mean())*3600)

HID = {}
for key, v in VARIANTS.items():
    row = {}
    for vant, B in (("earth_centre", 0.0), ("earth_limb", R_EARTH), ("lunar_farside_camera", D_MOON), ("sun_earth_L2", D_L2)):
        f, pmax, angM = hidden_fraction(v["separation_km"], v["radius_km"], B)
        row[vant] = dict(baseline_km=B, hidden_fraction=f, max_parallax_arcsec=pmax, mercury_mean_angular_radius_arcsec=angM)
    # Config B near side: Vulcan in front of Mercury => silhouette on Mercury's disc, always visible as a dark disc
    f_b, _, _ = hidden_fraction(v["separation_km"], v["radius_km"], 0.0, near_side=True)
    row["config_B_near_side"] = dict(note="In front of Mercury: a dark disc of angular radius R_V/(D-a) on Mercury's bright disc; "
        "visible in any telescope resolving Mercury's disc (>= ~10 cm aperture).",
        silhouette_fraction_of_mercury_disc_area=float(((v["radius_km"]/(D-v["separation_km"]))**2/(R_M/D)**2).mean()))
    HID[key] = row

# minimum baseline to ever see Vulcan's limb peek past Mercury's limb (at mean D):
for key, v in VARIANTS.items():
    a = v["separation_km"]; Dm = float(D.mean())
    B_needed = ((R_M/Dm) - v["radius_km"]/(Dm+a))*Dm*(Dm+a)/a
    VARIANTS[key]["baseline_km_to_see_vulcan_limb_at_mean_distance"] = B_needed
    VARIANTS[key]["baseline_in_lunar_distances"] = B_needed/D_MOON

# ---------------------------------------------------------------------------
# 4. Reflex wobble vs ranging
# ---------------------------------------------------------------------------
RANGING_PRECISION_M = 10.0  # Mercury orbit from MESSENGER ranging: metre-class (Verma+2014, Park+2017)
for key, v in VARIANTS.items():
    v["reflex_over_ranging_precision"] = v["mercury_reflex_km"]*1e3/RANGING_PRECISION_M
    v["reflex_detectable"] = v["reflex_over_ranging_precision"] > 3.0

# ---------------------------------------------------------------------------
# 5. Lunar occultations of Mercury 2026-2030
# ---------------------------------------------------------------------------
N5 = int(5*365.25*24)
t5 = ts.utc(2026, 1, 1, np.arange(N5))
gMo = earth.at(t5).observe(moon).apparent(); gMe = earth.at(t5).observe(mercury).apparent()
sep = gMo.separation_from(gMe).degrees
# geocentric lunar angular radius ~0.26 deg; topocentric occultation possible if sep < ~0.26+0.95 (horizontal parallax)
cand = np.where(sep < 1.3)[0]
OCC = []
if len(cand):
    groups = np.split(cand, np.where(np.diff(cand) > 1)[0]+1)
    for g in groups:
        i = g[np.argmin(sep[g])]
        # refine to minute
        tt = ts.utc(2026,1,1, (i + np.linspace(-1,1,121)))
        s2 = earth.at(tt).observe(moon).apparent().separation_from(earth.at(tt).observe(mercury).apparent()).degrees
        j = int(np.argmin(s2)); tmin = tt[j]
        e2 = earth.at(tmin).observe(sun).apparent().separation_from(earth.at(tmin).observe(mercury).apparent()).degrees
        # Moon phase (elongation from Sun)
        ph = earth.at(tmin).observe(sun).apparent().separation_from(earth.at(tmin).observe(moon).apparent()).degrees
        dist_me = (mercury.at(tmin).position.km - earth.at(tmin).position.km); dist_me = float(np.linalg.norm(dist_me))
        OCC.append(dict(utc=tmin.utc_strftime("%Y-%m-%d %H:%M"), min_geocentric_sep_deg=float(s2[j]),
            geocentric_occultation=bool(s2[j] < 0.26), topocentric_possible=bool(s2[j] < 1.25),
            mercury_elongation_deg=float(e2), moon_elongation_deg=float(ph),
            earth_mercury_distance_au=dist_me/AU_KM,
            mercury_angular_radius_arcsec=float(np.degrees(R_M/dist_me)*3600),
            daylight_note=("Mercury within %.0f deg of the Sun: daytime/twilight event" % e2) if e2 < 20 else "possibly observable in twilight"))
with open(os.path.join(DATA, "lunar_occultations_mercury_2026_2030.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(OCC[0].keys())); w.writeheader(); w.writerows(OCC)

# Mercury transits (geometric: Mercury within solar disc as seen from Earth centre)
gS = earth.at(t5).observe(sun).apparent()
sepS = gS.separation_from(gMe).degrees
rsun_deg = np.degrees(np.arctan(695700.0/np.linalg.norm(sun.at(t5).position.km - earth.at(t5).position.km, axis=0)))
dme = np.linalg.norm(mercury.at(t5).position.km - earth.at(t5).position.km, axis=0)
dse = np.linalg.norm(sun.at(t5).position.km - earth.at(t5).position.km, axis=0)
tr = np.where((sepS < rsun_deg) & (dme < dse))[0]
TRANSITS = [t5[i].utc_strftime("%Y-%m-%d %H:%M") for i in tr[::6]] if len(tr) else []

# ---------------------------------------------------------------------------
# 6. Perihelion precession without relativity: solar J2 route
# ---------------------------------------------------------------------------
R_SUN_KM = 695700.0
MEASURED_ANOM = {  # anomalous perihelion advance (arcsec/century) from ephemeris fits (Newtonian planets removed)
    "mercury": (42.98, 0.04), "venus": (8.62, 0.4), "earth": (3.84, 0.4), "mars": (1.35, 0.1), "icarus": (10.05, 1.0)}
ELEMS = {"mercury": (0.387098, 0.205630, 87.969), "venus": (0.723332, 0.006772, 224.701),
         "earth": (1.0, 0.016710, 365.256), "mars": (1.523679, 0.093394, 686.980), "icarus": (1.078, 0.827, 408.8)}
def j2_rate(J2, a_au, e, T_d):
    p = a_au*AU_KM*(1-e*e)
    per_orbit = 3*math.pi*J2*(R_SUN_KM/p)**2            # radians per orbit
    return math.degrees(per_orbit)*3600*(36525.0/T_d)   # arcsec per century
J2_measured = 2.2e-7
J2_needed = 42.98/j2_rate(1.0, *ELEMS["mercury"])
PREC = {"solar_J2_measured": J2_measured, "solar_J2_needed_for_mercury_43arcsec": J2_needed,
        "ratio_needed_over_measured": J2_needed/J2_measured, "rows": {}}
for k,(a,e,T) in ELEMS.items():
    PREC["rows"][k] = dict(measured_anomaly_arcsec_cy=MEASURED_ANOM[k][0], measured_err=MEASURED_ANOM[k][1],
        J2_model_prediction_arcsec_cy=j2_rate(J2_needed, a, e, T),
        J2_measured_contribution_arcsec_cy=j2_rate(J2_measured, a, e, T),
        scaling_note="J2 precession rate scales as a^-3.5 (1-e^2)^-2; the measured anomalies scale as a^-2.5 (1-e^2)^-1")
PREC["verdict"] = ("A solar oblateness J2 = %.2e (%.0fx the helioseismic value 2.2e-7) reproduces Mercury's 43\"/cy, "
    "but then predicts %.2f\"/cy for Venus (measured %.2f), %.2f\"/cy for Earth (measured %.2f) and %.2f\"/cy for Icarus "
    "(measured %.2f). The a^-3.5 law is refuted by the outer rows; the data follow a^-2.5. This is a measurement statement, "
    "not a theory statement." % (J2_needed, J2_needed/J2_measured,
    PREC["rows"]["venus"]["J2_model_prediction_arcsec_cy"], 8.62, PREC["rows"]["earth"]["J2_model_prediction_arcsec_cy"], 3.84,
    PREC["rows"]["icarus"]["J2_model_prediction_arcsec_cy"], 10.05))
# Le Verrier's intra-Mercurial Vulcan (historical): mass needed ~ M_Mercury at 0.14-0.2 AU (not computed here; cited)

# ---------------------------------------------------------------------------
# PLOTS
# ---------------------------------------------------------------------------
days = (jd - jd[0])
def date_ticks(ax):
    for m0 in range(0, 25, 3):
        ax.axvline(m0*30.4375, color="#223", lw=0.6)
    ax.set_xticks([0, 182.6, 365.25, 547.9, 730.5]); ax.set_xticklabels(["2026-01","2026-07","2027-01","2027-07","2028-01"])

# P1 separation vs Hill
fig, ax = plt.subplots(figsize=(11,5.5))
keys = list(VARIANTS.keys()); xs = np.arange(len(keys))
seps = [VARIANTS[k]["separation_km"] for k in keys]
cols = ["#4fd1ff","#ffb347","#ff5c7a","#9dff6a"]
ax.bar(xs, seps, color=cols, width=0.6)
ax.axhline(HILL_PERI, color="#ff5c7a", ls="--", lw=1.4, label=f"Mercury Hill radius @perihelion {HILL_PERI:,.0f} km")
ax.axhline(HILL_MEAN, color="#ffb347", ls=":", lw=1.4, label=f"Mercury Hill radius @mean {HILL_MEAN:,.0f} km")
ax.axhline(R_M, color="#aaa", lw=1, label=f"Mercury radius {R_M:,.0f} km")
for i,k in enumerate(keys):
    v = VARIANTS[k]
    ax.text(i, seps[i]*1.08, f"{seps[i]:,.0f} km\nT={v['kepler_period_d']:.2f} d\n{'BOUND' if v['bound_in_hill_sphere'] else 'UNBOUND'}",
            ha="center", va="bottom", fontsize=9, color=cols[i])
ax.set_yscale("log"); ax.set_ylim(1e3, 3e6); ax.set_xticks(xs); ax.set_xticklabels([VARIANTS[k]["label"] for k in keys], fontsize=9)
ax.set_ylabel("Mercury–Vulcan separation (km, log)"); ax.grid(True, which="both", axis="y")
ax.set_title("Vulcan variants vs Mercury's Hill sphere (Newtonian; Kepler III with q from each analogy)")
ax.legend(loc="upper left", fontsize=9); fig.tight_layout(); fig.savefig(os.path.join(IMG, "vulcan_01_separation_vs_hill.png"), dpi=130); plt.close(fig)

# P2 anti-Earth lock kinematics
fig, axs = plt.subplots(3,1, figsize=(12,10), sharex=True)
axs[0].plot(days, np.where(east, elong, -elong), color="#ffd166", lw=1.1)
axs[0].axhline(0, color="#555", lw=0.6); axs[0].set_ylabel("Mercury elongation (°)\n+east / −west"); axs[0].grid(True)
axs[0].set_title("The anti-Earth lock, hour by hour from DE421 (2026–2027)")
axs[1].plot(days, P_inst_d, color="#4fd1ff", lw=1.1)
axs[1].axhline(365.256, color="#9dff6a", ls="--", lw=1, label="1 sidereal year")
axs[1].axhline(58.646, color="#ff5c7a", ls=":", lw=1, label="Mercury spin 58.646 d")
axs[1].axhline(VARIANTS["charon_scaled"]["kepler_period_d"], color="#ffb347", ls="-.", lw=1, label=f"Kepler period at 16.5 R_M = {VARIANTS['charon_scaled']['kepler_period_d']:.2f} d")
axs[1].set_yscale("log"); axs[1].set_ylabel("Implied Vulcan period (d)\n= 2π / rate of Earth→Mercury line"); axs[1].grid(True, which="both"); axs[1].legend(fontsize=8, loc="upper right")
axs[2].plot(days, a_ff/HILL_PERI, color="#ff5c7a", lw=1.1, label="free-fall radius / Hill radius (perihelion)")
axs[2].plot(days, a_ff/HILL_MEAN, color="#ffb347", lw=0.9, label="free-fall radius / Hill radius (mean a)")
axs[2].axhline(1.0, color="#9dff6a", ls="--", lw=1.2, label="bound limit (=1)")
axs[2].set_yscale("log"); axs[2].set_ylabel("Radius where Mercury's gravity\nmatches the required rate ÷ Hill"); axs[2].grid(True, which="both"); axs[2].legend(fontsize=8)
date_ticks(axs[2]); fig.tight_layout(); fig.savefig(os.path.join(IMG, "vulcan_02_anti_earth_lock_kinematics.png"), dpi=130); plt.close(fig)

# P3 hiddenness vs baseline
fig, ax = plt.subplots(figsize=(11,5.5))
Bs = np.logspace(3, 7.5, 200)
for i,k in enumerate(keys):
    v = VARIANTS[k]; a = v["separation_km"]; Dm = float(D.mean()); Dmin = float(D.min())
    fr = [hidden_fraction(a, v["radius_km"], B)[0] for B in Bs]
    ax.plot(Bs, fr, color=cols[i], lw=1.6, label=f"{v['label']}  a={a:,.0f} km")
for B, nm in ((R_EARTH,"Earth limb"), (D_MOON,"Moon (far-side camera)"), (D_L2,"Sun–Earth L2")):
    ax.axvline(B, color="#889", ls=":", lw=1); ax.text(B*1.05, 0.5, nm, rotation=90, va="center", fontsize=9, color="#bbc")
ax.set_xscale("log"); ax.set_xlabel("Observer baseline perpendicular to the Earth→Mercury line (km)"); ax.set_ylabel("Fraction of 2026–27 Vulcan is fully hidden behind Mercury's disc")
ax.set_title("Config A hiddenness by parallax: can a far-side Vulcan stay hidden?"); ax.grid(True, which="both"); ax.legend(fontsize=9, loc="lower left")
fig.tight_layout(); fig.savefig(os.path.join(IMG, "vulcan_03_hiddenness_parallax.png"), dpi=130); plt.close(fig)

# P4 reflex wobble
fig, ax = plt.subplots(figsize=(10,5))
ref = [VARIANTS[k]["mercury_reflex_km"]*1e3 for k in keys]
ax.bar(xs, ref, color=cols, width=0.6)
ax.axhline(RANGING_PRECISION_M, color="#9dff6a", ls="--", label=f"MESSENGER-era ranging precision ~{RANGING_PRECISION_M:.0f} m")
ax.axhline(R_M*1e3, color="#aaa", lw=1, label="Mercury radius")
for i,k in enumerate(keys): ax.text(i, ref[i]*1.15, f"{ref[i]:.3g} m", ha="center", fontsize=9, color=cols[i])
ax.set_yscale("log"); ax.set_ylim(1e-2, 1e8); ax.set_xticks(xs); ax.set_xticklabels([VARIANTS[k]["label"] for k in keys], fontsize=9)
ax.set_ylabel("Mercury's reflex wobble about the pair barycenter (m, log)"); ax.grid(True, which="both", axis="y"); ax.legend(fontsize=9)
ax.set_title("Barycentric reflex of Mercury for each Vulcan variant vs radar/ranging precision"); fig.tight_layout()
fig.savefig(os.path.join(IMG, "vulcan_04_reflex_wobble.png"), dpi=130); plt.close(fig)

# P5 precession
fig, ax = plt.subplots(figsize=(10,5.5))
names = list(ELEMS.keys()); a_list = [ELEMS[k][0] for k in names]
meas = [MEASURED_ANOM[k][0] for k in names]; errs = [MEASURED_ANOM[k][1] for k in names]
pred = [PREC["rows"][k]["J2_model_prediction_arcsec_cy"] for k in names]
ax.errorbar(a_list, meas, yerr=errs, fmt="o", color="#9dff6a", ms=7, capsize=4, label="measured anomalous advance (ephemeris fits)")
ax.plot(a_list, pred, "s--", color="#ff5c7a", label=f"Newtonian solar-J2 model fitted to Mercury (J2={J2_needed:.2e})")
aa = np.linspace(0.3, 1.7, 100)
ax.plot(aa, 42.98*(0.387098/aa)**2.5, color="#4fd1ff", lw=1, alpha=0.8, label="a^-2.5 law (what the data follow)")
ax.plot(aa, 42.98*(0.387098/aa)**3.5, color="#ffb347", lw=1, alpha=0.8, label="a^-3.5 law (what a J2 model gives)")
for k,a,m_ in zip(names, a_list, meas): ax.text(a, m_*1.15, k, ha="center", fontsize=9)
ax.set_xscale("log"); ax.set_yscale("log"); ax.set_xlabel("semi-major axis (AU)"); ax.set_ylabel("anomalous perihelion advance (″/century)")
ax.set_title("Perihelion advance without relativity: a Newtonian J2 fit to Mercury fails the other planets"); ax.grid(True, which="both"); ax.legend(fontsize=8)
fig.tight_layout(); fig.savefig(os.path.join(IMG, "vulcan_05_precession_newtonian_test.png"), dpi=130); plt.close(fig)

# P6 occultation calendar
fig, ax = plt.subplots(figsize=(12,4.5))
for o in OCC:
    y, mth, dd = [int(x) for x in o["utc"][:10].split("-")]
    x = (ts.utc(y,mth,dd).tt - ts.utc(2026,1,1).tt)/365.25 + 2026
    c = "#9dff6a" if o["geocentric_occultation"] else ("#ffb347" if o["topocentric_possible"] else "#667")
    ax.vlines(x, 0, o["mercury_elongation_deg"], color=c, lw=2.2)
    ax.plot(x, o["mercury_elongation_deg"], "o", color=c, ms=5)
ax.axhspan(0, 10, color="#ff5c7a", alpha=0.12); ax.text(2026.02, 4, "lost in solar glare (<10°)", fontsize=8, color="#ff9aa9")
ax.set_xlim(2026, 2031); ax.set_ylim(0, 30); ax.set_xlabel("year"); ax.set_ylabel("Mercury elongation from Sun (°)")
ax.set_title("Moon–Mercury conjunctions 2026–2030 (green: geocentric occultation; orange: occultation somewhere on Earth) — Config B test dates")
ax.grid(True); fig.tight_layout(); fig.savefig(os.path.join(IMG, "vulcan_06_lunar_occultation_calendar.png"), dpi=130); plt.close(fig)

# ---------------------------------------------------------------------------
# Godot ephemeris exports (ecliptic J2000, heliocentric AU; Moon geocentric km)
# ---------------------------------------------------------------------------
def pack(arr): return [[round(float(x),7) for x in col] for col in arr.T]
sel = slice(0, N, 6)   # 6-hour cadence for the orrery video (2 yr -> 2920 samples)
helio = lambda r: (r - rS)/AU_KM
EXPORT = dict(frame="ecliptic J2000, heliocentric, AU (moon_geo_km geocentric km)", step_hours=6.0, start_utc="2026-01-01T00:00Z",
    jd_tt=[round(float(x),5) for x in jd[sel]],
    mercury=pack(helio(rM)[:,sel]), venus=pack(helio(rV)[:,sel]), earth=pack(helio(rE)[:,sel]), mars=pack(helio(rMa)[:,sel]),
    moon_geo_km=pack((rMo - rE)[:,sel]),
    earth_to_mercury_unit=pack(u[:,sel]), earth_mercury_dist_km=[round(float(x),1) for x in D[sel]],
    implied_vulcan_period_d=[round(float(x),3) for x in P_inst_d[sel]],
    free_fall_radius_km=[round(float(x),1) for x in a_ff[sel]],
    elongation_signed_deg=[round(float(x),3) for x in np.where(east, elong, -elong)[sel]],
    hill_radius_km=HILL_PERI, mercury_radius_km=R_M, variants={k: dict(separation_km=v["separation_km"], radius_km=v["radius_km"], mass_ratio=v["mass_ratio"], label=v["label"]) for k,v in VARIANTS.items()})
with open(os.path.join(DATA, "ephem_2026_2027_6h.json"), "w") as f: json.dump(EXPORT, f)

# outer-system snapshot for the ladder orrery (heliocentric ecliptic AU at 2026-10-10)
t_now = ts.utc(2026, 10, 10)
outer = {}
for nm in ("mercury","venus","earth","mars","jupiter barycenter","saturn barycenter","uranus barycenter","neptune barycenter","pluto barycenter"):
    p = (eph[nm].at(t_now).frame_xyz(ecliptic_frame).km - sun.at(t_now).frame_xyz(ecliptic_frame).km)/AU_KM
    outer[nm.split()[0]] = [round(float(x),6) for x in p]
EXPORT["snapshot_2026_10_10_helio_au"] = outer
with open(os.path.join(DATA, "ephem_2026_2027_6h.json"), "w") as f: json.dump(EXPORT, f)

# occultation close-up export: ±6 h around the best FUTURE geocentric occultation (after 2026-10-10), 1-minute cadence
future = [o for o in OCC if o["utc"] > "2026-10-10"]
best = min(future, key=lambda o: o["min_geocentric_sep_deg"])
y, mth, rest = best["utc"].split("-"); dd, hm = rest.split(" "); hh, mm = hm.split(":")
tc = ts.utc(int(y), int(mth), int(dd), int(hh), int(mm) + np.arange(-360, 361))
oMo = earth.at(tc).observe(moon).apparent(); oMe = earth.at(tc).observe(mercury).apparent(); oSu = earth.at(tc).observe(sun).apparent()
ra_mo, dec_mo, dist_mo = oMo.radec(); ra_me, dec_me, dist_me = oMe.radec(); ra_su, dec_su, _ = oSu.radec()
OCC_EXPORT = dict(event_utc=best["utc"], cadence_min=1, n=len(tc),
    moon_ra_deg=[round(float(x),6) for x in ra_mo._degrees], moon_dec_deg=[round(float(x),6) for x in dec_mo.degrees],
    moon_dist_km=[round(float(x),1) for x in dist_mo.km], moon_radius_km=1737.4,
    mercury_ra_deg=[round(float(x),6) for x in ra_me._degrees], mercury_dec_deg=[round(float(x),6) for x in dec_me.degrees],
    mercury_dist_km=[round(float(x),1) for x in dist_me.km], mercury_radius_km=R_M,
    sun_ra_deg=float(ra_su._degrees[360]), sun_dec_deg=float(dec_su.degrees[360]),
    variants=EXPORT["variants"], note="Geocentric apparent coordinates. Vulcan Config A: behind Mercury (+a along LOS). Config B: in front (-a).")
with open(os.path.join(DATA, "ephem_occultation_closeup.json"), "w") as f: json.dump(OCC_EXPORT, f)

OUT = dict(axiom="Vulcan bound to Mercury (Pluto/Charon-like) and always anti-Earth (Config A); possibly inverted during lunar occultation (Config B).",
    mercury=dict(mass_kg=M_M, GM_m3s2=GM_M, radius_km=R_M, hill_radius_perihelion_km=HILL_PERI, hill_radius_mean_km=HILL_MEAN,
        spin_d=MER["rot_d"], orbit_d=MER["period_d"], spin_orbit_ratio=MER["spin_orbit_ratio"]),
    pluto_charon_template=dict(mass_ratio=q_charon, radius_ratio=k_charon, separation_R_P=s_charon, period_d=CHA["period_d"],
        barycenter_outside_pluto=CHA["barycenter_outside_primary"]),
    chain_mass_ratio=dict(saturn_rings=q_sat_rings, mars_moons=q_mars_moons, geometric_mean=q_chain),
    variants=VARIANTS, lock_kinematics=LOCK, required_vs_available_acceleration=KIN, hiddenness=HID,
    ranging_precision_m=RANGING_PRECISION_M, lunar_occultations_2026_2030=OCC, mercury_transits_2026_2030=TRANSITS,
    precession_without_relativity=PREC,
    historical=dict(le_verrier_vulcan="1859: intra-Mercurial planet proposed to explain 38\"/cy (later 43\"); Lescarbault 'transit' 1859; never confirmed; "
                    "searched at eclipses 1878 (Watson, Swift) — no body > ~a few hundred km exists inside Mercury's orbit (SOHO/LASCO era limits).",
        mariner10_moon_1974="UV excess 1974-03 attributed to a Mercury moon; identified as the star 31 Crateris.",
        ida_dactyl="243 Ida's moon Dactyl: imaged by Galileo 1993-08-28, found in downlinked frames 1994-02-17 (Ann Harch); announced March 1994. "
                   "First confirmed asteroid moon — not an April 1 release.",
        messenger="MESSENGER (2011-2015) performed dedicated satellite searches; none found."))
with open(os.path.join(DATA, "vulcan_derivation.json"), "w") as f: json.dump(OUT, f, indent=1, default=str)

print("VARIANTS"); 
for k,v in VARIANTS.items():
    print(f"  {v['label']:32s} q={v['mass_ratio']:.3e} R={v['radius_km']:7.1f} km a={v['separation_km']:>11,.0f} km ({v['separation_R_M']:.1f} R_M) "
          f"T={v['kepler_period_d']:8.2f} d  a/Hill={v['separation_over_hill_peri']:.3f}  reflex={v['mercury_reflex_km']:.4g} km  limb-baseline={v['baseline_in_lunar_distances']:.1f} LD")
print("LOCK", {k: (round(v,4) if isinstance(v,float) else v) for k,v in LOCK.items() if k!='note'})
for k,v in KIN.items(): print(" KIN", k, f"g={v['gravity_available_ms2']:.3e} need_c={v['centripetal_required_ms2_mean']:.3e} need_t_max={v['tangential_required_ms2_max']:.3e} ratio={v['gravity_over_centripetal_mean']:.1f}")
print("HIDDEN charon_scaled:", {k:(round(r['hidden_fraction'],3) if 'hidden_fraction' in r else '-') for k,r in HID['charon_scaled'].items()})
print("HIDDEN spin_locked:", {k:(round(r['hidden_fraction'],3) if 'hidden_fraction' in r else '-') for k,r in HID['spin_locked'].items()})
print(f"OCCULTATIONS: {len(OCC)} conjunctions <1.3deg; geocentric: {sum(o['geocentric_occultation'] for o in OCC)}; best {best['utc']} sep {best['min_geocentric_sep_deg']:.3f}")
for o in OCC: print("   ", o["utc"], f"sep={o['min_geocentric_sep_deg']:.3f} elong={o['mercury_elongation_deg']:.1f} geo={o['geocentric_occultation']}")
print("TRANSITS:", TRANSITS[:3])
print("PRECESSION:", PREC["verdict"])
