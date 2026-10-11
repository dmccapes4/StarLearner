#!/usr/bin/env python3
"""
luna_from_mercury.py — three follow-ups to the Vulcan audit.

1. LUNA SEEN FROM MERCURY.  Does the Moon move "retrograde" from Mercury's
   vantage? Computed two ways from DE421 (2026-2028, hourly):
     (a) the Moon's motion relative to the STARS in Mercury's sky
         (dominated by Earth's own apparent motion, which retrogrades around
         every inferior conjunction);
     (b) the Moon's motion relative to EARTH in Mercury's sky — the sense in
         which it circles Earth's disc. Prediction from geometry: the half of
         the lunar orbit nearer Mercury moves WEST (opposite to how Earth sees
         it), the far half moves east.
   Plus the mirror of the 2028-02-23 lunar occultation: from Mercury, the
   Moon transits Earth's disc — direction and duration.

2. "BESIDE IS INVISIBLE" — tested.  For each Vulcan variant on a FREE Kepler
   orbit: maximum angular separation from Mercury as seen from Earth,
   brightness relative to Mercury, and the eclipse/occultation depth of the
   "slightest occlusion" (the Pluto/Charon mutual-event test).

3. 42/π — the user's mnemonic for lunar months per year, checked.

Outputs: data/luna_from_mercury.json, img/luna_01..03.png, data/ephem_luna_from_mercury.json
"""
import os, json, math, sys
import numpy as np
from skyfield.api import Loader
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bodies import derive, AU_KM, G
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
plt.rcParams.update({"figure.facecolor":"#0b0d17","axes.facecolor":"#0b0d17","axes.edgecolor":"#667","axes.labelcolor":"#dde",
    "xtick.color":"#bbc","ytick.color":"#bbc","text.color":"#eef","grid.color":"#223","legend.facecolor":"#141829","legend.edgecolor":"#445"})
HERE = os.path.dirname(os.path.abspath(__file__))
DOC  = os.path.abspath(os.path.join(HERE, "..", "..", "docs", "MERCURY_VULCAN_LADDER_20261010"))
DATA = os.path.join(DOC, "data"); IMG = os.path.join(DOC, "img")
B = derive(); V = json.load(open(os.path.join(DATA, "vulcan_derivation.json")))
load = Loader("/tmp/skyfield-data"); eph = load("de421.bsp"); ts = load.timescale()
sun, mercury, earth, moon = eph["sun"], eph["mercury"], eph["earth"], eph["moon"]
R_M = 2439.7; R_E = 6371.0; R_L = 1737.4

# ---------------------------------------------------------------------------
# FRAME: the Zecliptic (solar equator). North = Sol's rotation pole, east = Sol's
# rotation sense (increasing solar-equatorial longitude). Ecliptic J2000 → solar
# equator: rotate about z by −Ω (node to +x), then about x by −i.  i = 7.25°,
# Ω = 75.76° (Carrington). Earth/ecliptic frames appear ONLY where stated, with
# a reason (the instruments and the photometric record are on Earth).
# ---------------------------------------------------------------------------
I_SE = math.radians(7.25); OM_SE = math.radians(75.76)
def Rz(th): c, s_ = math.cos(th), math.sin(th); return np.array([[c, -s_, 0], [s_, c, 0], [0, 0, 1]])
def Rx(th): c, s_ = math.cos(th), math.sin(th); return np.array([[1, 0, 0], [0, c, -s_], [0, s_, c]])
ECL_TO_SE = Rx(-I_SE) @ Rz(-OM_SE)
def to_se(xyz): return ECL_TO_SE @ xyz                                  # xyz shape (3, N) in ecliptic J2000
def se_lonlat(xyz):
    x, y, z = to_se(xyz); r = np.sqrt(x*x + y*y + z*z)
    return np.degrees(np.arctan2(y, x)) % 360.0, np.degrees(np.arcsin(z / r)), r
# sanity: Sol's north pole (ecliptic λ = Ω − 90°, β = 90° − i) must map to +z
_pole = np.array([math.cos(OM_SE - math.pi/2) * math.cos(math.pi/2 - I_SE), math.sin(OM_SE - math.pi/2) * math.cos(math.pi/2 - I_SE), math.sin(math.pi/2 - I_SE)])
assert abs(to_se(_pole)[2] - 1.0) < 1e-9, "frame rotation check failed"

# ---------------------------------------------------------------------------
# 1. Luna from Mercury
# ---------------------------------------------------------------------------
N = int(2*365.25*24); t = ts.utc(2026, 1, 1, np.arange(N)); dt_h = 1.0
mE = mercury.at(t).observe(earth).apparent(); mL = mercury.at(t).observe(moon).apparent()
raE, decE, dEkm = se_lonlat(mE.ecliptic_xyz().km); raL, decL, dLkm = se_lonlat(mL.ecliptic_xyz().km)   # solar-equator lon/lat (deg), named ra/dec for brevity
class _D:  # tiny distance holder with .km (keeps the plotting code below unchanged)
    def __init__(self, km): self.km = km
dE = _D(dEkm); dL = _D(dLkm)
def unwrap_deg(a): return np.degrees(np.unwrap(np.radians(a)))
# (a) Moon vs stars: eastward = RA increasing
rate_L_stars = np.gradient(unwrap_deg(raL), dt_h) * np.cos(np.radians(decL)) * 24.0   # deg/day eastward
rate_E_stars = np.gradient(unwrap_deg(raE), dt_h) * np.cos(np.radians(decE)) * 24.0
# (b) Moon relative to Earth in Mercury's sky
dra = (raL - raE + 540.0) % 360.0 - 180.0                                             # deg, +east of Earth
ddec = decL - decE
x_rel = dra * np.cos(np.radians(decE)) * 3600.0; y_rel = ddec * 3600.0                 # arcsec
rate_rel = np.gradient(x_rel, dt_h) * 24.0                                             # arcsec/day eastward relative to Earth
# geometry check: which half of the lunar orbit is nearer Mercury?
rM = mercury.at(t).position.km; rEa = earth.at(t).position.km; rLu = moon.at(t).position.km
near_half = np.linalg.norm(rLu - rM, axis=0) < np.linalg.norm(rEa - rM, axis=0)
frac_west_rel = float((rate_rel < 0).mean())
frac_west_rel_near = float((rate_rel[near_half] < 0).mean()); frac_west_rel_far = float((rate_rel[~near_half] < 0).mean())
frac_retro_stars_L = float((rate_L_stars < 0).mean()); frac_retro_stars_E = float((rate_E_stars < 0).mean())
# Earth's angular radius from Mercury, and Moon transits of Earth's disc (mirror of lunar occultations of Mercury)
angR_E = np.degrees(np.arctan(R_E / dE.km)) * 3600.0
sepLE = np.hypot(x_rel, y_rel)
in_transit = (sepLE < angR_E) & near_half
idx = np.where(in_transit)[0]
TRANSITS = []
if len(idx):
    for g in np.split(idx, np.where(np.diff(idx) > 1)[0] + 1):
        i0, i1 = g[0], g[-1]
        TRANSITS.append(dict(start_utc=t[i0].utc_strftime("%Y-%m-%d %H:%M"), end_utc=t[i1].utc_strftime("%Y-%m-%d %H:%M"),
            duration_h=float(i1 - i0 + 1), moon_motion_across_earth=("WEST (retrograde to Earth's sense)" if rate_rel[g].mean() < 0 else "EAST"),
            moon_rate_arcsec_per_day=float(rate_rel[g].mean()), earth_angular_radius_arcsec=float(angR_E[g].mean()),
            moon_angular_radius_arcsec=float(np.degrees(np.arctan(R_L / dL.km[g])).mean() * 3600)))
# the 2028-02-23 event from Mercury's side (1-min cadence, ±6 h)
tc = ts.utc(2028, 2, 23, 0, 5 + np.arange(-360, 361))
cE = mercury.at(tc).observe(earth).apparent(); cL = mercury.at(tc).observe(moon).apparent()
cr_E, cd_E, cdist_E_km = se_lonlat(cE.ecliptic_xyz().km); cr_L, cd_L, cdist_L_km = se_lonlat(cL.ecliptic_xyz().km)
cx = ((cr_L - cr_E + 540) % 360 - 180) * np.cos(np.radians(cd_E)) * 3600
cy = (cd_L - cd_E) * 3600
cRE = np.degrees(np.arctan(R_E / cdist_E_km)) * 3600; cRL = np.degrees(np.arctan(R_L / cdist_L_km)) * 3600
EVENT_2028 = dict(mid_utc="2028-02-23 00:05", moon_x_arcsec_rel_earth=[round(float(v), 2) for v in cx], moon_y_arcsec_rel_earth=[round(float(v), 2) for v in cy],
    earth_radius_arcsec=[round(float(v), 3) for v in cRE], moon_radius_arcsec=[round(float(v), 3) for v in cRL],
    moon_motion_sense=("WEST" if (cx[-1] - cx[0]) < 0 else "EAST"), x_start=float(cx[0]), x_end=float(cx[-1]),
    min_sep_arcsec=float(np.hypot(cx, cy).min()), transits_earth_disc=bool((np.hypot(cx, cy) < cRE).any()),
    earth_mercury_dist_au=float(cdist_E_km[360] / AU_KM), frame="solar equator (Zecliptic): north = Sol's rotation pole, east = Sol's rotation sense",
    helio_mercury_au=np.round(to_se(mercury.at(tc).ecliptic_position().au).T, 5).tolist(),
    helio_earth_au=np.round(to_se(earth.at(tc).ecliptic_position().au).T, 5).tolist(),
    moon_geo_km=np.round(to_se(moon.at(tc).ecliptic_position().km - earth.at(tc).ecliptic_position().km).T, 1).tolist(),
    earth_B0_deg=float(se_lonlat(earth.at(tc).ecliptic_position().km)[1][360]), mercury_B_deg=float(se_lonlat(mercury.at(tc).ecliptic_position().km)[1][360]),
    n=len(cx))
# a full lunation seen from Mercury (Feb 2028): Moon's track relative to Earth, with the near/far halves coloured
t_m = ts.utc(2028, 2, 1 + np.arange(0, 30 * 24, 1) / 24.0)
lE = mercury.at(t_m).observe(earth).apparent(); lL = mercury.at(t_m).observe(moon).apparent()
lr_E, ld_E, ldist_E = se_lonlat(lE.ecliptic_xyz().km); lr_L, ld_L, _ = se_lonlat(lL.ecliptic_xyz().km)
lx = ((lr_L - lr_E + 540) % 360 - 180) * np.cos(np.radians(ld_E)) * 3600
ly = (ld_L - ld_E) * 3600
lnear = np.linalg.norm(moon.at(t_m).position.km - mercury.at(t_m).position.km, axis=0) < np.linalg.norm(earth.at(t_m).position.km - mercury.at(t_m).position.km, axis=0)

# ---------------------------------------------------------------------------
# 1b. SOLAR EQUINOXES — when a body crosses Sol's equatorial plane (its solar
#     latitude B passes through 0). For Earth this is when B0 = 0 (early June and
#     early December); Earth's own March/September equinoxes are when |B0| is
#     LARGEST (7.03°) — the tilt is then fully visible. Both are tabulated.
# ---------------------------------------------------------------------------
def crossings(name, body, t0=(2026, 1, 1), days=3 * 365):
    tt = ts.utc(t0[0], t0[1], t0[2] + np.arange(0, days, 1 / 24.0))
    lon, lat, _ = se_lonlat(body.at(tt).ecliptic_position().km)
    out = []
    for i in np.where(np.sign(lat[:-1]) != np.sign(lat[1:]))[0]:
        f = lat[i] / (lat[i] - lat[i + 1]); jd = tt.tt[i] + f * (tt.tt[i + 1] - tt.tt[i])
        out.append(dict(body=name, utc=ts.tt_jd(jd).utc_strftime("%Y-%m-%d %H:%M"), direction=("ascending (south→north of Sol's equator)" if lat[i + 1] > lat[i] else "descending"),
                        solar_equatorial_longitude_deg=float(lon[i])))
    return out
SOLAR_EQUINOXES = crossings("Earth", earth) + crossings("Mercury", mercury, days=400)
# Earth's equinoxes: B0 and Mercury's solar latitude on those dates
EARTH_EQX = []
for (y, m, d) in [(2026, 3, 20), (2026, 9, 22), (2027, 3, 20), (2027, 9, 23), (2028, 3, 20), (2028, 9, 22)]:
    te = ts.utc(y, m, d, 12)
    EARTH_EQX.append(dict(utc=f"{y}-{m:02d}-{d:02d}", earth_B0_deg=float(se_lonlat(earth.at(te).ecliptic_position().km)[1]), mercury_B_deg=float(se_lonlat(mercury.at(te).ecliptic_position().km)[1]),
                          moon_B_deg=float(se_lonlat(moon.at(te).ecliptic_position().km)[1])))

# ---------------------------------------------------------------------------
# 2. "Beside is invisible" — free-orbit Vulcan vs the telescope record
# ---------------------------------------------------------------------------
dEM = np.linalg.norm(rM - rEa, axis=0)                      # Earth–Mercury km
BESIDE = {"_frame_note": "Earth frame used here BY REASON: the telescopes, the eyes and the photometric record are on Earth; angular separations are as seen from Earth."}
for k, v in V["variants"].items():
    a = v["separation_km"]; Rv = v["radius_km"]
    sep_max = np.degrees(np.arctan(a / dEM)) * 3600          # arcsec, orbit seen face-on or at elongation
    dmag = 5 * math.log10(R_M / Rv)                           # same albedo: brightness ratio = area ratio
    depth_occ = (Rv / R_M) ** 2 if Rv < R_M else 1.0          # Vulcan fully behind Mercury: loss of Vulcan's light / total
    frac_loss_occultation = depth_occ / (1 + depth_occ)       # fraction of combined light lost when Vulcan hides
    frac_loss_transit = depth_occ / (1 + depth_occ)           # Vulcan in front: blocks the same area (dark disc on Mercury)
    # fraction of a free orbit (edge-on) during which Vulcan is within 1 arcsec of Mercury's centre (i.e. "beside = merged")
    merged = np.degrees(np.arctan(1000.0 / dEM)) * 3600       # 1000 km projected ≈ "inside the seeing disc"
    BESIDE[k] = dict(label=v["label"], free_period_d=v["kepler_period_d"],
        max_separation_arcsec_min=float(sep_max.min()), max_separation_arcsec_max=float(sep_max.max()), max_separation_arcmin_mean=float(sep_max.mean() / 60),
        magnitude_fainter_than_mercury=dmag, combined_light_lost_in_mutual_event=frac_loss_occultation, mutual_event_depth_mag=-2.5 * math.log10(1 - frac_loss_occultation),
        fraction_of_edge_on_orbit_merged_with_mercury=float((2 * np.arcsin(np.clip(1000.0 / a, 0, 1)) / math.pi)),
        resolvable_by=("naked eye (>60 arcsec)" if sep_max.mean() > 60 else ("small telescope (>2 arcsec)" if sep_max.mean() > 2 else "space telescope / spacecraft only")),
        verdict=("A mag %.1f companion up to %.1f arcmin from Mercury would appear in every telescopic record since 1610 (Galileo, Hevelius, Schroeter, Schiaparelli 1881-89, Antoniadi 1920s). "
                 "Mutual events would dim Mercury by %.2f mag every %.2f d in edge-on seasons; Mercury's photometry is good to ~0.01-0.02 mag (Mallama 2002, 2017)."
                 % (dmag, sep_max.mean() / 60, -2.5 * math.log10(1 - frac_loss_occultation), v["kepler_period_d"] / 2)) if Rv > 100 else
                ("A ~10 km body at up to %.1f arcmin is V~%.0f beside V~0 Mercury: below naked-eye and most visual records; mutual-event depth %.0f micro-mag, undetectable. Bounded only by spacecraft imaging."
                 % (sep_max.mean() / 60, dmag, 1e6 * 1.0857 * frac_loss_occultation)))

# ---------------------------------------------------------------------------
# 3. 42/π
# ---------------------------------------------------------------------------
sid_months = 365.25636 / 27.321661; syn_months = 365.25636 / 29.530589
FORTYTWO = dict(sidereal_months_per_year=sid_months, synodic_months_per_year=syn_months, forty_two_over_pi=42 / math.pi,
    match_sidereal_percent=100 * (42 / math.pi - sid_months) / sid_months, sidereal_months_times_pi=sid_months * math.pi, synodic_months_times_pi=syn_months * math.pi,
    reading="Luna's sidereal months per year × π = 42.00 (13.3687 × 3.14159 = 41.999). So 42/π = 13.369 reproduces the sidereal month count to 0.002 %. "
            "The synodic count gives 38.9, so the mnemonic is for the SIDEREAL month (Luna against the stars, which is also the view from Mercury).",
    caution="A numerical coincidence of four significant figures; no mechanism is proposed. It is a mnemonic, and a good one.")

# ---------------------------------------------------------------------------
# PLOTS
# ---------------------------------------------------------------------------
days = np.arange(N) / 24.0
fig, axs = plt.subplots(3, 1, figsize=(12, 10), sharex=True)
axs[0].plot(days, rate_E_stars, color="#4fd1ff", lw=1, label="Earth vs stars (from Mercury)")
axs[0].plot(days, rate_L_stars, color="#ddd", lw=0.5, alpha=0.7, label="Luna vs stars (from Mercury)")
axs[0].axhline(0, color="#9dff6a", lw=0.8, ls="--"); axs[0].set_ylabel("deg/day east\n(Sol's rotation sense)"); axs[0].legend(fontsize=8); axs[0].grid(True)
axs[0].set_title("Luna from Mercury, 2026–27 (DE421, solar-equator frame): Earth retrogrades at every inferior conjunction; Luna rides along")
axs[1].plot(days, rate_rel, color="#ffb347", lw=0.6); axs[1].axhline(0, color="#9dff6a", lw=0.8, ls="--")
axs[1].fill_between(days, rate_rel, 0, where=near_half, color="#ff5c7a", alpha=0.25, label="Luna on the Mercury-facing half of its orbit")
axs[1].set_ylabel("Luna relative to Earth\n(arcsec/day, +east)"); axs[1].legend(fontsize=8); axs[1].grid(True)
axs[2].plot(days, sepLE, color="#c9a7ff", lw=0.6, label="Luna–Earth separation (arcsec)"); axs[2].plot(days, angR_E, color="#4fd1ff", lw=1, label="Earth's angular radius")
axs[2].set_yscale("log"); axs[2].set_ylabel("arcsec"); axs[2].legend(fontsize=8); axs[2].grid(True, which="both")
axs[2].set_xticks([0, 182.6, 365.25, 547.9, 730.5]); axs[2].set_xticklabels(["2026-01", "2026-07", "2027-01", "2027-07", "2028-01"])
fig.tight_layout(); fig.savefig(os.path.join(IMG, "luna_01_from_mercury_rates.png"), dpi=130); plt.close(fig)

fig, ax = plt.subplots(figsize=(10, 7))
sc = ax.scatter(lx, ly, c=np.where(lnear, 1, 0), cmap="coolwarm", s=6, vmin=0, vmax=1)
for i in range(0, len(lx), 48):
    ax.annotate("", xy=(lx[min(i + 6, len(lx) - 1)], ly[min(i + 6, len(ly) - 1)]), xytext=(lx[i], ly[i]), arrowprops=dict(arrowstyle="->", color="#ffd166", lw=1.0))
    ax.text(lx[i], ly[i] + 15, t_m[i].utc_strftime("%d"), fontsize=7, color="#ffd166")
rE_mid = float(np.degrees(np.arctan(R_E / ldist_E)).mean() * 3600)
ax.add_patch(plt.Circle((0, 0), rE_mid, color="#4fd1ff", alpha=0.35)); ax.text(0, -rE_mid - 25, "Earth's disc", ha="center", fontsize=9, color="#4fd1ff")
ax.set_aspect("equal"); ax.invert_xaxis(); ax.set_xlabel("← east     arcsec from Earth     west →"); ax.set_ylabel("arcsec north (Sol's pole)")
ax.set_title("Lunation from Mercury, Feb 2028 — red: Mercury-facing half (WEST), blue: far half (EAST)"); ax.grid(True)
fig.tight_layout(); fig.savefig(os.path.join(IMG, "luna_02_lunation_from_mercury.png"), dpi=130); plt.close(fig)

fig, ax = plt.subplots(figsize=(10, 5.5))
ax.add_patch(plt.Circle((0, 0), float(cRE[360]), color="#4fd1ff", alpha=0.4)); ax.text(0, 0, "Earth", ha="center", va="center", fontsize=11, color="#fff")
ax.plot(cx, cy, color="#ddd", lw=1.5)
for i in range(0, len(cx), 60):
    ax.add_patch(plt.Circle((cx[i], cy[i]), float(cRL[i]), color="#aaa", alpha=0.5)); ax.text(cx[i], cy[i] + 4, f"{(i-360)//60:+d}h", fontsize=8, ha="center", color="#ffd166")
ax.annotate("", xy=(cx[-1], cy[-1]), xytext=(cx[-61], cy[-61]), arrowprops=dict(arrowstyle="->", color="#ff5c7a", lw=2))
ax.set_aspect("equal"); ax.invert_xaxis(); ax.set_xlabel("← east     arcsec from Earth's centre     west →"); ax.set_ylabel("arcsec north (Sol's pole)")
ax.set_title(f"2028-02-23 00:05 UTC from Mercury: Luna crosses Earth moving {EVENT_2028["moon_motion_sense"]} (Earth sees it move EAST over Mercury)")
ax.grid(True); fig.tight_layout(); fig.savefig(os.path.join(IMG, "luna_03_transit_of_earth_2028.png"), dpi=130); plt.close(fig)

OUT = dict(luna_from_mercury=dict(fraction_time_luna_retrograde_vs_stars=frac_retro_stars_L, fraction_time_earth_retrograde_vs_stars=frac_retro_stars_E,
        fraction_time_luna_moves_west_relative_to_earth=frac_west_rel, on_mercury_facing_half=frac_west_rel_near, on_far_half=frac_west_rel_far,
        moon_transits_of_earth_disc_2026_2027=TRANSITS, event_2028_02_23_from_mercury={k: v for k, v in EVENT_2028.items() if not isinstance(v, list)},
        statement="From Mercury, Luna circles Earth in the opposite sense to what Earth sees for exactly the half of its orbit that faces Mercury — "
                  "a mirror, not a physical reversal: the observer is outside the orbit instead of at its centre. Against the stars, Luna's apparent motion "
                  "is dominated by Earth's, which retrogrades around every inferior conjunction (every 115.9 d)."),
    beside_is_invisible=BESIDE, forty_two_over_pi=FORTYTWO,
    frame="Zecliptic (solar equator, i=7.25°, Ω=75.76°): north = Sol's rotation pole, east = Sol's rotation sense. Earth-frame quantities are marked with a reason.",
    solar_equinoxes=SOLAR_EQUINOXES, earth_equinoxes_B0=EARTH_EQX)
json.dump(OUT, open(os.path.join(DATA, "luna_from_mercury.json"), "w"), indent=1, default=str)
json.dump(EVENT_2028, open(os.path.join(DATA, "ephem_luna_from_mercury.json"), "w"))
print("retro vs stars: Luna %.3f Earth %.3f | Luna west rel Earth: all %.3f near %.3f far %.3f" % (frac_retro_stars_L, frac_retro_stars_E, frac_west_rel, frac_west_rel_near, frac_west_rel_far))
print("transits of Earth by Luna (from Mercury) 2026-27:", len(TRANSITS)); [print("  ", tr) for tr in TRANSITS]
print("2028 event from Mercury:", {k: v for k, v in EVENT_2028.items() if not isinstance(v, list)})
for k, b in BESIDE.items():
    if k.startswith("_"): continue
    print(k, "sep %.0f-%.0f arcsec  dmag %.1f  depth %.3f mag  merged-frac %.3f  %s" % (b["max_separation_arcsec_min"], b["max_separation_arcsec_max"], b["magnitude_fainter_than_mercury"], b["mutual_event_depth_mag"], b["fraction_of_edge_on_orbit_merged_with_mercury"], b["resolvable_by"]))
print("solar equinoxes:"); [print("  ", e) for e in SOLAR_EQUINOXES]
print("Earth equinoxes B0:"); [print("  ", e) for e in EARTH_EQX]
print("42/pi:", {k: (round(v, 4) if isinstance(v, float) else v) for k, v in FORTYTWO.items() if k not in ("reading", "caution")})
