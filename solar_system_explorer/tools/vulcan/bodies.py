#!/usr/bin/env python3
"""
bodies.py — measured metrics for every body in the Mercury/Vulcan ladder.

Every number here is a MEASUREMENT or a value derived from measurements by
Newtonian mechanics only (Kepler III, Hill sphere, Roche limit, barycenter,
escape speed, angular momentum). No relativity is used anywhere in this
module. Sources: NASA Planetary Fact Sheets (Williams, GSFC), JPL SSD
Horizons/Standish J2000 elements, IAU WG on Cartographic Coordinates,
Iess et al. 2019 (Saturn ring mass), MESSENGER gravity (Mazarico 2014),
Voyager/IBEX for the heliobarrier.

Derived quantities (computed in `derive()`):
  * inclination to the SOLAR EQUATOR (the user's Zecliptic in this report)
  * inclination to the invariable (Laplace) plane
  * Hill radius, Roche limit (fluid), escape speed, synodic period vs Earth
  * orbital / spin angular momentum
  * secondary/primary mass ratio, separation in primary radii, barycenter
    offset (for binaries / ring systems / moon systems)

Run:  python3 bodies.py  -> writes bodies_metrics.{json,csv,md} to OUT_DIR
"""
import json, math, csv, os, sys

G       = 6.67430e-11          # m^3 kg^-1 s^-2
AU_KM   = 1.495978707e8
DAY_S   = 86400.0
YEAR_D  = 365.25
M_SUN   = 1.98892e30
M_EARTH = 5.9722e24

# Solar equator (J2000): inclination to ecliptic 7.25 deg, ascending node 75.76 deg
SOL_EQ_I   = 7.25
SOL_EQ_OM  = 75.76
# Invariable plane (Souami & Souchay 2012): i=1.5787 deg, Omega=107.5822 deg
INV_I  = 1.5787
INV_OM = 107.5822

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "..", "docs", "MERCURY_VULCAN_LADDER_20261010", "data")

# ---------------------------------------------------------------------------
# Primary bodies.  Keys:
#  mass_kg, gm_km3s2, r_mean_km, r_eq_km, density, a_au, e, i_ecl_deg,
#  omega_node_deg (Ω, J2000 ecliptic), period_d (sidereal), rot_d (sidereal,
#  negative = retrograde), obliquity_deg (to own orbit), j2, dipole_Am2,
#  albedo_geom, albedo_bond, g_ms2, irradiance_Wm2, n_moons, rings (bool),
#  ring_mass_kg, ring_inner_km, ring_outer_km, moons_total_mass_kg, notes
# ---------------------------------------------------------------------------
BODIES = {
 "sol": dict(name="Sol", kind="star",
   mass_kg=1.98892e30, gm_km3s2=1.32712440018e11, r_mean_km=695700.0, r_eq_km=695700.0,
   density=1408.0, a_au=0.0, e=0.0, i_ecl_deg=None, omega_node_deg=None, period_d=0.0,
   rot_d=25.05, rot_note="sidereal, equator; 25.38 d Carrington; ~34 d near poles (differential)",
   obliquity_deg=7.25, obliquity_note="rotation axis to ecliptic; node 75.76 deg",
   j2=2.2e-7, dipole_Am2=3.4e29, albedo_geom=None, albedo_bond=None, g_ms2=274.0,
   irradiance_Wm2=None, n_moons=8, rings=False, ring_mass_kg=0.0,
   luminosity_W=3.828e26, t_eff_K=5772.0, v_esc_kms=617.7,
   spin_L_kgm2s=1.9e41,
   notes="Holds 99.86% of system mass but only ~0.5% of its angular momentum."),

 "mercury": dict(name="Mercury", kind="planet",
   mass_kg=3.3011e23, gm_km3s2=22031.87, r_mean_km=2439.7, r_eq_km=2440.5,
   density=5427.0, a_au=0.387098, e=0.205630, i_ecl_deg=7.005, omega_node_deg=48.331,
   period_d=87.969, rot_d=58.646, obliquity_deg=0.034, j2=5.03e-5, dipole_Am2=2.8e19,
   albedo_geom=0.142, albedo_bond=0.088, g_ms2=3.70, irradiance_Wm2=9082.7,
   n_moons=0, rings=False, ring_mass_kg=0.0, moons_total_mass_kg=0.0,
   perihelion_precession_obs_arcsec_cy=574.10, perihelion_precession_newtonian_planets_arcsec_cy=531.63,
   notes="Spin:orbit = 3:2 exactly (58.646 d x 1.5 = 87.969 d). GM known to 1e-6 from MESSENGER. "
         "Mariner 10 'moon' (1974) was the star 31 Crateris. No satellite found by MESSENGER 2011-15."),

 "venus": dict(name="Venus", kind="planet",
   mass_kg=4.8675e24, gm_km3s2=324858.6, r_mean_km=6051.8, r_eq_km=6051.8,
   density=5243.0, a_au=0.723332, e=0.006772, i_ecl_deg=3.395, omega_node_deg=76.680,
   period_d=224.701, rot_d=-243.025, obliquity_deg=177.36, j2=4.458e-6, dipole_Am2=0.0,
   albedo_geom=0.689, albedo_bond=0.760, g_ms2=8.87, irradiance_Wm2=2601.3,
   n_moons=0, rings=False, ring_mass_kg=0.0, moons_total_mass_kg=0.0,
   notes="Retrograde spin; solar day 116.75 d. Node 76.68 deg is within 1 deg of the solar equator node 75.76 deg."),

 "earth": dict(name="Earth", kind="planet",
   mass_kg=5.9722e24, gm_km3s2=398600.435, r_mean_km=6371.0, r_eq_km=6378.137,
   density=5514.0, a_au=1.000000, e=0.016710, i_ecl_deg=0.0, omega_node_deg=-11.26,
   period_d=365.256, rot_d=0.997270, obliquity_deg=23.44, j2=1.08263e-3, dipole_Am2=7.94e22,
   albedo_geom=0.434, albedo_bond=0.306, g_ms2=9.80, irradiance_Wm2=1361.0,
   n_moons=1, rings=False, ring_mass_kg=0.0, moons_total_mass_kg=7.346e22,
   notes="Defines the ecliptic. Earth-Luna barycenter 4671 km from Earth center (0.733 R_E, inside)."),

 "luna": dict(name="Luna", kind="moon", primary="earth",
   mass_kg=7.346e22, gm_km3s2=4902.80, r_mean_km=1737.4, r_eq_km=1738.1,
   density=3344.0, a_km=384400.0, e=0.0549, i_deg=5.145, i_note="to ecliptic",
   period_d=27.3217, synodic_d=29.5306, rot_d=27.3217, obliquity_deg=6.68,
   j2=2.027e-4, dipole_Am2=0.0, albedo_geom=0.12, albedo_bond=0.11, g_ms2=1.62,
   notes="Synchronous rotation. Recession 3.8 cm/yr (LLR). Mass ratio to Earth 0.01230."),

 "mars": dict(name="Mars", kind="planet",
   mass_kg=6.4171e23, gm_km3s2=42828.37, r_mean_km=3389.5, r_eq_km=3396.2,
   density=3934.0, a_au=1.523679, e=0.093394, i_ecl_deg=1.850, omega_node_deg=49.558,
   period_d=686.980, rot_d=1.025957, obliquity_deg=25.19, j2=1.9605e-3, dipole_Am2=0.0,
   albedo_geom=0.170, albedo_bond=0.250, g_ms2=3.71, irradiance_Wm2=586.2,
   n_moons=2, rings=False, ring_mass_kg=0.0, moons_total_mass_kg=1.214e16,
   sync_orbit_km=20428.0,
   notes="Crustal remanent field only. Phobos inside synchronous orbit (decaying ~1.8 m/cy); Deimos outside."),

 "phobos": dict(name="Phobos", kind="moon", primary="mars",
   mass_kg=1.0659e16, r_mean_km=11.08, density=1876.0, a_km=9376.0, e=0.0151,
   i_deg=1.08, i_note="to Mars equator", period_d=0.31891, rot_d=0.31891, albedo_geom=0.071,
   notes="Orbits faster than Mars rotates: rises in the west."),
 "deimos": dict(name="Deimos", kind="moon", primary="mars",
   mass_kg=1.4762e15, r_mean_km=6.2, density=1471.0, a_km=23463.2, e=0.00033,
   i_deg=1.79, i_note="to Mars equator", period_d=1.26244, rot_d=1.26244, albedo_geom=0.068),

 "asteroid_belt": dict(name="Asteroid Belt (AB)", kind="belt",
   mass_kg=2.39e21, a_au=2.70, a_inner_au=2.06, a_outer_au=3.27, period_d=4.60*YEAR_D,
   i_ecl_deg=None, i_mean_deg=7.5, e_mean=0.15,
   kirkwood_gaps_au=[2.502, 2.825, 2.958, 3.279],
   kirkwood_resonances=["3:1", "5:2", "7:3", "2:1"],
   notes="Mass ~3% of Luna; Ceres 39%, Ceres+Vesta+Pallas+Hygiea 62%. Inner edge = 4:1 Jupiter "
         "resonance (2.06 AU), outer = 2:1 (3.27 AU). A two-dimensional annulus of mean thickness ~0.4 AU."),

 "ceres": dict(name="Ceres", kind="dwarf", primary="sol",
   mass_kg=9.3835e20, r_mean_km=469.7, density=2162.0, a_au=2.7658, e=0.0785, i_ecl_deg=10.59,
   omega_node_deg=80.3, period_d=4.60*YEAR_D, rot_d=9.074/24.0, obliquity_deg=4.0, albedo_geom=0.090),
 "vesta": dict(name="Vesta", kind="asteroid", primary="sol",
   mass_kg=2.590e20, r_mean_km=262.7, density=3456.0, a_au=2.3615, e=0.0894, i_ecl_deg=7.14,
   omega_node_deg=103.8, period_d=3.63*YEAR_D, rot_d=5.342/24.0, albedo_geom=0.42),
 "pallas": dict(name="Pallas", kind="asteroid", primary="sol",
   mass_kg=2.04e20, r_mean_km=256.0, density=2890.0, a_au=2.7716, e=0.2302, i_ecl_deg=34.84,
   omega_node_deg=173.0, period_d=4.61*YEAR_D, rot_d=7.813/24.0, albedo_geom=0.155),
 "hygiea": dict(name="Hygiea", kind="asteroid", primary="sol",
   mass_kg=8.74e19, r_mean_km=217.0, density=1940.0, a_au=3.1415, e=0.1125, i_ecl_deg=3.83,
   omega_node_deg=283.2, period_d=5.57*YEAR_D, rot_d=13.83/24.0, albedo_geom=0.072),

 "jupiter": dict(name="Jupiter", kind="planet",
   mass_kg=1.89819e27, gm_km3s2=126686531.9, r_mean_km=69911.0, r_eq_km=71492.0,
   density=1326.0, a_au=5.20289, e=0.048386, i_ecl_deg=1.304, omega_node_deg=100.464,
   period_d=4332.59, rot_d=0.41354, obliquity_deg=3.13, j2=1.4697e-2, dipole_Am2=1.55e27,
   albedo_geom=0.538, albedo_bond=0.343, g_ms2=24.79, irradiance_Wm2=50.26,
   n_moons=95, rings=True, ring_mass_kg=1.0e13, ring_inner_km=92000.0, ring_outer_km=226000.0,
   ring_note="halo 92,000-122,500; main 122,500-129,000; gossamer to 226,000 km; mass very poorly known",
   moons_total_mass_kg=3.93e23, internal_heat_ratio=1.67,
   notes="Radiates 1.67x the sunlight it receives. System III rotation 9h 55m 29.7s. "
         "Galilean moons 1:2:4 Laplace resonance (Io:Europa:Ganymede)."),
 "io": dict(name="Io", kind="moon", primary="jupiter", mass_kg=8.9319e22, r_mean_km=1821.6,
   density=3528.0, a_km=421800.0, e=0.0041, i_deg=0.05, period_d=1.769138, rot_d=1.769138),
 "europa": dict(name="Europa", kind="moon", primary="jupiter", mass_kg=4.7998e22, r_mean_km=1560.8,
   density=3013.0, a_km=671100.0, e=0.0094, i_deg=0.47, period_d=3.551181, rot_d=3.551181),
 "ganymede": dict(name="Ganymede", kind="moon", primary="jupiter", mass_kg=1.4819e23, r_mean_km=2634.1,
   density=1936.0, a_km=1070400.0, e=0.0013, i_deg=0.20, period_d=7.154553, rot_d=7.154553,
   dipole_Am2=1.3e20, notes="Only moon with intrinsic dipole field."),
 "callisto": dict(name="Callisto", kind="moon", primary="jupiter", mass_kg=1.0759e23, r_mean_km=2410.3,
   density=1834.0, a_km=1882700.0, e=0.0074, i_deg=0.19, period_d=16.689018, rot_d=16.689018),

 "saturn": dict(name="Saturn", kind="planet",
   mass_kg=5.6834e26, gm_km3s2=37931206.2, r_mean_km=58232.0, r_eq_km=60268.0,
   density=687.0, a_au=9.53667, e=0.053862, i_ecl_deg=2.485, omega_node_deg=113.666,
   period_d=10759.22, rot_d=0.44401, rot_note="10h 39m 24s; interior 10h 33m 38s (Cassini ring seismology)",
   obliquity_deg=26.73, j2=1.6298e-2, dipole_Am2=4.6e25,
   albedo_geom=0.499, albedo_bond=0.342, g_ms2=10.44, irradiance_Wm2=14.82,
   n_moons=274, n_moons_note="274 confirmed (IAU/MPC Mar 2025); 146 in 2023",
   rings=True, ring_mass_kg=1.54e19, ring_mass_err_kg=0.49e19, ring_inner_km=66900.0, ring_outer_km=140180.0,
   ring_note="D 66,900-74,510; C 74,658-92,000; B 92,000-117,580; Cassini Div to 122,170; A to 136,775; F 140,180; "
             "G 166,000-175,000; E 180,000-480,000 km. Mass = 0.41 Mimas (Iess+2019, Grand Finale).",
   moons_total_mass_kg=1.405e23, internal_heat_ratio=1.78,
   notes="Rings lie in the equatorial plane, tilted 26.73 deg to the orbit; ring-plane crossings every ~15 yr (next 2025 Mar 23, 2038-39). "
         "Ring mass / Saturn mass = 2.7e-8."),
 "titan": dict(name="Titan", kind="moon", primary="saturn", mass_kg=1.3452e23, r_mean_km=2574.7,
   density=1882.0, a_km=1221870.0, e=0.0288, i_deg=0.35, period_d=15.945, rot_d=15.945),
 "rhea": dict(name="Rhea", kind="moon", primary="saturn", mass_kg=2.306e21, r_mean_km=763.8,
   density=1236.0, a_km=527108.0, e=0.0013, i_deg=0.35, period_d=4.518, rot_d=4.518),
 "iapetus": dict(name="Iapetus", kind="moon", primary="saturn", mass_kg=1.805e21, r_mean_km=734.5,
   density=1088.0, a_km=3560820.0, e=0.0283, i_deg=15.47, period_d=79.32, rot_d=79.32),
 "dione": dict(name="Dione", kind="moon", primary="saturn", mass_kg=1.095e21, r_mean_km=561.4,
   density=1478.0, a_km=377396.0, e=0.0022, i_deg=0.02, period_d=2.737, rot_d=2.737),
 "tethys": dict(name="Tethys", kind="moon", primary="saturn", mass_kg=6.17e20, r_mean_km=531.1,
   density=984.0, a_km=294619.0, e=0.0001, i_deg=1.09, period_d=1.888, rot_d=1.888),
 "enceladus": dict(name="Enceladus", kind="moon", primary="saturn", mass_kg=1.080e20, r_mean_km=252.1,
   density=1609.0, a_km=237948.0, e=0.0047, i_deg=0.02, period_d=1.370, rot_d=1.370),
 "mimas": dict(name="Mimas", kind="moon", primary="saturn", mass_kg=3.75e19, r_mean_km=198.2,
   density=1150.0, a_km=185539.0, e=0.0196, i_deg=1.57, period_d=0.942, rot_d=0.942),

 "uranus": dict(name="Uranus", kind="planet",
   mass_kg=8.6813e25, gm_km3s2=5793951.3, r_mean_km=25362.0, r_eq_km=25559.0,
   density=1270.0, a_au=19.18916, e=0.047257, i_ecl_deg=0.772, omega_node_deg=74.006,
   period_d=30688.5, rot_d=-0.71833, obliquity_deg=97.77, j2=3.3434e-3, dipole_Am2=3.9e24,
   dipole_note="offset 0.31 R, tilted 58.6 deg from spin axis",
   albedo_geom=0.488, albedo_bond=0.300, g_ms2=8.87, irradiance_Wm2=3.69,
   n_moons=28, rings=True, ring_mass_kg=1.0e16, ring_inner_km=38000.0, ring_outer_km=98000.0,
   ring_note="13 rings: 6,5,4,alpha,beta,eta,gamma,delta,lambda,epsilon (51,149 km, w 20-100 km), nu, mu (97,700 km). Mass est. only.",
   moons_total_mass_kg=9.1e21, internal_heat_ratio=1.06,
   notes="Node 74.006 deg is 1.75 deg from the solar-equator node (75.76 deg). Rolls on its side; "
         "ring plane = equatorial plane at 97.77 deg. Equinox 2007 Dec 7; next 2049."),
 "titania": dict(name="Titania", kind="moon", primary="uranus", mass_kg=3.40e21, r_mean_km=788.9,
   density=1711.0, a_km=435910.0, e=0.0011, i_deg=0.08, period_d=8.706, rot_d=8.706),
 "oberon": dict(name="Oberon", kind="moon", primary="uranus", mass_kg=3.08e21, r_mean_km=761.4,
   density=1630.0, a_km=583520.0, e=0.0014, i_deg=0.07, period_d=13.463, rot_d=13.463),
 "umbriel": dict(name="Umbriel", kind="moon", primary="uranus", mass_kg=1.28e21, r_mean_km=584.7,
   density=1390.0, a_km=266000.0, e=0.0039, i_deg=0.13, period_d=4.144, rot_d=4.144),
 "ariel": dict(name="Ariel", kind="moon", primary="uranus", mass_kg=1.25e21, r_mean_km=578.9,
   density=1592.0, a_km=190900.0, e=0.0012, i_deg=0.04, period_d=2.520, rot_d=2.520),
 "miranda": dict(name="Miranda", kind="moon", primary="uranus", mass_kg=6.4e19, r_mean_km=235.8,
   density=1200.0, a_km=129900.0, e=0.0013, i_deg=4.34, period_d=1.413, rot_d=1.413),

 "neptune": dict(name="Neptune", kind="planet",
   mass_kg=1.02409e26, gm_km3s2=6835099.5, r_mean_km=24622.0, r_eq_km=24764.0,
   density=1638.0, a_au=30.06992, e=0.008590, i_ecl_deg=1.770, omega_node_deg=131.784,
   period_d=60182.0, rot_d=0.67125, obliquity_deg=28.32, j2=3.411e-3, dipole_Am2=2.2e24,
   dipole_note="offset 0.55 R, tilted 46.9 deg",
   albedo_geom=0.442, albedo_bond=0.290, g_ms2=11.15, irradiance_Wm2=1.51,
   n_moons=16, rings=True, ring_mass_kg=1.0e15, ring_inner_km=40900.0, ring_outer_km=62932.0,
   ring_note="Galle 40,900-42,900; Le Verrier 53,200; Lassell 53,200-57,200; Arago 57,200; Adams 62,932 (arcs Fraternite, Egalite, Liberte, Courage)",
   moons_total_mass_kg=2.147e22, internal_heat_ratio=2.61,
   notes="Radiates 2.61x received sunlight. Triton retrograde (i=157 deg) = captured KBO; Triton is 99.5% of Neptune's moon mass."),
 "triton": dict(name="Triton", kind="moon", primary="neptune", mass_kg=2.1390e22, r_mean_km=1353.4,
   density=2061.0, a_km=354759.0, e=0.000016, i_deg=156.9, i_note="retrograde, to Neptune equator",
   period_d=-5.876854, rot_d=-5.876854, albedo_geom=0.76, notes="Captured; spiralling inward; Roche disruption in ~3.6 Gyr."),
 "proteus": dict(name="Proteus", kind="moon", primary="neptune", mass_kg=4.4e19, r_mean_km=210.0,
   density=1300.0, a_km=117647.0, e=0.0005, i_deg=0.08, period_d=1.12231, rot_d=1.12231),
 "nereid": dict(name="Nereid", kind="moon", primary="neptune", mass_kg=3.1e19, r_mean_km=178.5,
   density=1500.0, a_km=5513800.0, e=0.7507, i_deg=7.09, period_d=360.14, rot_d=0.48,
   notes="e = 0.75, the most eccentric known moon."),

 "pluto": dict(name="Pluto", kind="dwarf",
   mass_kg=1.3030e22, gm_km3s2=869.6, r_mean_km=1188.3, r_eq_km=1188.3,
   density=1854.0, a_au=39.482, e=0.2488, i_ecl_deg=17.16, omega_node_deg=110.299,
   period_d=90560.0, rot_d=-6.3872, obliquity_deg=122.53, j2=None, dipole_Am2=0.0,
   albedo_geom=0.52, albedo_bond=0.72, g_ms2=0.62, irradiance_Wm2=0.873,
   n_moons=5, rings=False, ring_mass_kg=0.0, moons_total_mass_kg=1.586e21+7.5e15+2.6e16+1.65e16+4.8e16,
   notes="Pluto and Charon are mutually tidally locked (both 6.3872 d). Barycenter 2,126 km from Pluto center = 1.79 R_P, OUTSIDE Pluto. "
         "3:2 resonance with Neptune (2 Pluto orbits = 3 Neptune orbits)."),
 "charon": dict(name="Charon", kind="moon", primary="pluto", mass_kg=1.586e21, gm_km3s2=105.88,
   r_mean_km=606.0, density=1702.0, a_km=19591.4, e=0.0002, i_deg=0.080, i_note="to Pluto equator",
   period_d=6.387221, rot_d=6.387221, albedo_geom=0.41,
   notes="Mass ratio 0.1217; radius ratio 0.510; separation 16.49 R_P."),
 "styx": dict(name="Styx", kind="moon", primary="pluto", mass_kg=7.5e15, r_mean_km=8.0, a_km=42656.0, period_d=20.16, rot_d=3.24),
 "nix": dict(name="Nix", kind="moon", primary="pluto", mass_kg=2.6e16, r_mean_km=24.5, a_km=48694.0, period_d=24.85, rot_d=1.83),
 "kerberos": dict(name="Kerberos", kind="moon", primary="pluto", mass_kg=1.65e16, r_mean_km=9.5, a_km=57783.0, period_d=32.17, rot_d=5.33),
 "hydra": dict(name="Hydra", kind="moon", primary="pluto", mass_kg=4.8e16, r_mean_km=25.5, a_km=64738.0, period_d=38.20, rot_d=0.43),

 "heliobarrier": dict(name="Heliobarrier (HB)", kind="boundary",
   termination_shock_au={"voyager1_2004_12": 94.0, "voyager2_2007_08": 84.0},
   heliopause_au={"voyager1_2012_08_25": 121.6, "voyager2_2018_11_05": 119.0},
   bow_wave_au=230.0, nose_ecl_lon_deg=255.7, nose_ecl_lat_deg=5.1,
   nose_ra_deg=259.2, nose_dec_deg=-16.6,  # approx equatorial of (255.7, +5.1)
   ism_flow_speed_kms=25.4, ism_B_nT=0.5, solar_wind_1au_kms=400.0,
   plasma_density_inside_cm3=0.002, plasma_density_outside_cm3=0.08,
   ibex_ribbon_center_ecl=[221.0, 39.0], ibex_ribbon_radius_deg=75.0, ibex_ribbon_width_deg=20.0,
   shape_models=["comet-tail (classical)", "croissant (Opher+2020)", "bubble (Dialynas+2017)"],
   notes="Not a sphere: a blunt nose toward (lambda 255.7, beta +5.1) with a tail downwind. "
         "The IBEX ribbon is a ~20 deg wide band of ENA emission, a 3-D structure on the HB."),
}

# ---------------------------------------------------------------------------
def incl_between(i1, om1, i2, om2):
    """Angle between two orbit planes given (i, Omega) in degrees."""
    i1, om1, i2, om2 = map(math.radians, (i1, om1, i2, om2))
    c = math.cos(i1)*math.cos(i2) + math.sin(i1)*math.sin(i2)*math.cos(om1-om2)
    return math.degrees(math.acos(max(-1.0, min(1.0, c))))

def hill_radius_km(a_km, e, m, M):
    return a_km*(1.0-e)*(m/(3.0*M))**(1.0/3.0)

def roche_fluid_km(R_primary_km, rho_primary, rho_sat):
    return 2.456*R_primary_km*(rho_primary/rho_sat)**(1.0/3.0)

def v_esc_kms(mass, r_km):
    return math.sqrt(2*G*mass/(r_km*1e3))/1e3

def synodic_days(T1, T2):
    if T1 <= 0 or T2 <= 0 or T1 == T2: return None
    return abs(1.0/(1.0/T1 - 1.0/T2))

def kepler_period_d(a_km, M_total):
    return 2*math.pi*math.sqrt((a_km*1e3)**3/(G*M_total))/DAY_S

def kepler_a_km(T_d, M_total):
    return (G*M_total*(T_d*DAY_S)**2/(4*math.pi**2))**(1.0/3.0)/1e3

def derive():
    out = {}
    for key, b in BODIES.items():
        d = dict(b); d["id"] = key
        kind = b["kind"]
        m = b.get("mass_kg")
        R = b.get("r_mean_km")
        if m and R:
            d["v_esc_kms"] = round(v_esc_kms(m, R), 3)
            d["mass_earth"] = m/M_EARTH
        # heliocentric orbit
        if kind in ("planet","dwarf","asteroid","belt") and b.get("a_au"):
            a_km = b["a_au"]*AU_KM
            d["a_km"] = a_km
            if b.get("i_ecl_deg") is not None and b.get("omega_node_deg") is not None:
                d["i_solar_equator_deg"] = round(incl_between(b["i_ecl_deg"], b["omega_node_deg"], SOL_EQ_I, SOL_EQ_OM), 3)
                d["i_invariable_deg"]    = round(incl_between(b["i_ecl_deg"], b["omega_node_deg"], INV_I, INV_OM), 3)
            if b.get("period_d"):
                d["period_yr"] = b["period_d"]/YEAR_D
                d["synodic_earth_d"] = synodic_days(b["period_d"], 365.256) if key != "earth" else None
                d["mean_orbital_speed_kms"] = 2*math.pi*a_km/(b["period_d"]*DAY_S)
                # Kepler III check: T^2/a^3 in yr^2/AU^3 (should be 1 + m/M)
                d["kepler_T2_over_a3"] = (b["period_d"]/YEAR_D)**2 / b["a_au"]**3
            if m:
                d["hill_radius_km"] = hill_radius_km(a_km, b.get("e",0.0), m, M_SUN)
                d["hill_radius_primary_radii"] = d["hill_radius_km"]/R if R else None
                d["orbital_L_kgm2s"] = m*math.sqrt(G*M_SUN*a_km*1e3*(1-b.get("e",0.0)**2))
            if b.get("rot_d") and R and m:
                # uniform-sphere upper bound for spin L: 0.4 m R^2 omega  (true I/mR^2 is smaller)
                w = 2*math.pi/(abs(b["rot_d"])*DAY_S)
                d["spin_L_uniform_sphere_kgm2s"] = 0.4*m*(R*1e3)**2*w
                if b.get("period_d"):
                    d["spin_orbit_ratio"] = b["period_d"]/abs(b["rot_d"])
            if b.get("perihelion_precession_obs_arcsec_cy"):
                d["perihelion_precession_anomaly_arcsec_cy"] = (b["perihelion_precession_obs_arcsec_cy"]
                    - b["perihelion_precession_newtonian_planets_arcsec_cy"])
            # secondary systems
            if b.get("moons_total_mass_kg") is not None and m:
                d["moons_to_primary_mass_ratio"] = b["moons_total_mass_kg"]/m
            if b.get("rings") and m:
                d["ring_to_primary_mass_ratio"] = b["ring_mass_kg"]/m
                d["ring_outer_primary_radii"] = b["ring_outer_km"]/R
                d["roche_fluid_km_ice"] = roche_fluid_km(R, b["density"], 920.0)
        # moons
        if kind == "moon":
            p = BODIES[b["primary"]]
            Mp = p["mass_kg"]; Rp = p["r_mean_km"]
            a = b["a_km"]
            d["mass_ratio_to_primary"] = m/Mp if m else None
            d["radius_ratio_to_primary"] = R/p["r_mean_km"] if R else None
            d["separation_primary_radii"] = a/Rp
            if m:
                d["barycenter_from_primary_center_km"] = a*m/(Mp+m)
                d["barycenter_outside_primary"] = d["barycenter_from_primary_center_km"] > Rp
                d["kepler_period_check_d"] = kepler_period_d(a, Mp+m)
                d["hill_radius_in_primary_km"] = hill_radius_km(a, b.get("e",0.0), m, Mp)
                d["orbital_L_kgm2s"] = m*math.sqrt(G*(Mp+m)*a*1e3)
            if p.get("a_au") and p.get("e") is not None:
                hp = hill_radius_km(p["a_au"]*AU_KM, p["e"], Mp, M_SUN)
                d["separation_over_primary_hill"] = a/hp
            if p.get("rot_d") and m:
                d["primary_sync_orbit_km"] = kepler_a_km(abs(p["rot_d"]), Mp)
                d["inside_primary_sync_orbit"] = a < d["primary_sync_orbit_km"]
            d["roche_fluid_km"] = roche_fluid_km(Rp, p["density"], b.get("density", 1500.0)) if b.get("density") else None
        out[key] = d
    # Solar B0 at the equinoxes (heliographic latitude of disc centre): sin B0 = sin(lambda_sun - Omega) sin i
    def B0(lam_deg):
        return math.degrees(math.asin(math.sin(math.radians(lam_deg - SOL_EQ_OM))*math.sin(math.radians(SOL_EQ_I))))
    out["_solar_equator_view"] = {
        "B0_march_equinox_deg": round(B0(0.0), 3), "B0_june_solstice_deg": round(B0(90.0), 3),
        "B0_september_equinox_deg": round(B0(180.0), 3), "B0_december_solstice_deg": round(B0(270.0), 3),
        "B0_zero_dates": "~June 6 and ~December 7 (Earth crosses the solar-equator node line)",
        "B0_extreme_dates": "~March 6 (-7.25) and ~September 8 (+7.25)",
        "note": "At the equinoxes Earth sits ~5 deg from the extreme-B0 longitudes, so the solar equator shows ~97% of its full 7.25 deg tilt. "
                "Equinox is a near-optimal time to judge inclinations against the solar equator (Zecliptic as used in this report)."}
    return out

def _fmt(v):
    if v is None: return ""
    if isinstance(v, float):
        if v == 0: return "0"
        if abs(v) >= 1e5 or abs(v) < 1e-3: return f"{v:.4g}"
        return f"{v:.4f}".rstrip("0").rstrip(".")
    return str(v)

def write_all():
    os.makedirs(OUT_DIR, exist_ok=True)
    data = derive()
    with open(os.path.join(OUT_DIR, "bodies_metrics.json"), "w") as f:
        json.dump(data, f, indent=1, default=str)
    cols = ["id","name","kind","mass_kg","mass_earth","r_mean_km","density","a_au","a_km","e","i_ecl_deg",
            "i_solar_equator_deg","i_invariable_deg","omega_node_deg","period_d","period_yr","synodic_earth_d",
            "rot_d","spin_orbit_ratio","obliquity_deg","j2","dipole_Am2","albedo_geom","albedo_bond","g_ms2",
            "v_esc_kms","irradiance_Wm2","hill_radius_km","hill_radius_primary_radii","orbital_L_kgm2s",
            "spin_L_uniform_sphere_kgm2s","n_moons","moons_total_mass_kg","moons_to_primary_mass_ratio",
            "rings","ring_mass_kg","ring_inner_km","ring_outer_km","ring_to_primary_mass_ratio","roche_fluid_km_ice",
            "mass_ratio_to_primary","radius_ratio_to_primary","separation_primary_radii",
            "barycenter_from_primary_center_km","barycenter_outside_primary","separation_over_primary_hill",
            "primary_sync_orbit_km","inside_primary_sync_orbit","roche_fluid_km","internal_heat_ratio"]
    rows = [d for k,d in data.items() if not k.startswith("_")]
    with open(os.path.join(OUT_DIR, "bodies_metrics.csv"), "w", newline="") as f:
        w = csv.writer(f); w.writerow(cols)
        for d in rows: w.writerow([_fmt(d.get(c)) for c in cols])
    # Markdown: planets table + moons table
    md = ["# Bodies — measured and Newtonian-derived metrics\n",
          "Sources: NASA GSFC planetary fact sheets, JPL SSD, IAU WGCCRE, MESSENGER (Mercury GM/J2), "
          "Cassini Grand Finale (Saturn ring mass, Iess+2019), Voyager 1/2 + IBEX (heliobarrier). "
          "Derived columns use Newtonian mechanics only.\n",
          "\n## Heliocentric bodies\n",
          "| Body | Mass (kg) | R (km) | ρ (kg/m³) | a (AU) | e | i_ecl ° | i_SolEq ° | i_inv ° | T (d) | T (yr) | Synodic (d) | Rot (d) | T/rot | Obliq ° | J2 | Dipole (A·m²) | Hill (km) | Moons | Rings | Ring mass (kg) | Moons/Primary | Ring/Primary |",
          "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for d in rows:
        if d["kind"] in ("star","planet","dwarf","belt") and d.get("primary") in (None,"sol"):
            md.append("| " + " | ".join(_fmt(d.get(c)) for c in
                ["name","mass_kg","r_mean_km","density","a_au","e","i_ecl_deg","i_solar_equator_deg","i_invariable_deg",
                 "period_d","period_yr","synodic_earth_d","rot_d","spin_orbit_ratio","obliquity_deg","j2","dipole_Am2",
                 "hill_radius_km","n_moons","rings","ring_mass_kg","moons_to_primary_mass_ratio","ring_to_primary_mass_ratio"]) + " |")
    md += ["\n## Satellites and binaries\n",
           "| Moon | Primary | Mass (kg) | R (km) | ρ | a (km) | e | i ° | T (d) | Rot (d) | m/M | R/R_p | a/R_p | Barycenter from primary (km) | Barycenter outside primary? | a / Hill_p | Sync orbit of primary (km) | Inside sync? | Roche (km) |",
           "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for d in rows:
        if d["kind"] == "moon":
            md.append("| " + " | ".join(_fmt(d.get(c)) for c in
                ["name","primary","mass_kg","r_mean_km","density","a_km","e","i_deg","period_d","rot_d",
                 "mass_ratio_to_primary","radius_ratio_to_primary","separation_primary_radii",
                 "barycenter_from_primary_center_km","barycenter_outside_primary","separation_over_primary_hill",
                 "primary_sync_orbit_km","inside_primary_sync_orbit","roche_fluid_km"]) + " |")
    md += ["\n## Asteroid belt (AB)\n", "```json", json.dumps(data["asteroid_belt"], indent=1, default=str), "```",
           "\n## Heliobarrier (HB)\n", "```json", json.dumps(data["heliobarrier"], indent=1, default=str), "```",
           "\n## Solar equator as seen from Earth\n", "```json", json.dumps(data["_solar_equator_view"], indent=1), "```"]
    with open(os.path.join(OUT_DIR, "bodies_metrics.md"), "w") as f:
        f.write("\n".join(md) + "\n")
    return data

if __name__ == "__main__":
    data = write_all()
    print(f"wrote {len(data)} records to {os.path.abspath(OUT_DIR)}")
    for k in ("mercury","venus","earth","mars","jupiter","saturn","uranus","neptune","pluto"):
        d = data[k]
        print(f"{d['name']:8s} i_ecl={d['i_ecl_deg']:6.3f}  i_SolEq={d['i_solar_equator_deg']:6.3f}  i_inv={d['i_invariable_deg']:6.3f}  "
              f"Hill={d['hill_radius_km']:.4g} km  T^2/a^3={d['kepler_T2_over_a3']:.5f}")
    c = data["charon"]
    print("Charon: bary", round(c["barycenter_from_primary_center_km"]), "km outside:", c["barycenter_outside_primary"],
          " Kepler T check:", round(c["kepler_period_check_d"],4), "d")
    print("Solar B0 at equinoxes:", data["_solar_equator_view"])
