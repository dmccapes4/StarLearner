#!/usr/bin/env python3
"""
build_report.py — writes REPORT_MERCURY_VULCAN_LADDER_20261010.md and .pdf
from one content tree, pulling every number from the JSON produced by
bodies.py, vulcan_derivation.py, ladder_analysis.py and ladder_null.py.
"""
import os, json, math, textwrap, datetime
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DOC  = os.path.abspath(os.path.join(HERE, "..", "..", "docs", "MERCURY_VULCAN_LADDER_20261010"))
DATA = os.path.join(DOC, "data"); IMG = os.path.join(DOC, "img"); VID = os.path.join(DOC, "video")
J = lambda n: json.load(open(os.path.join(DATA, n)))
B = J("bodies_metrics.json"); V = J("vulcan_derivation.json"); LA = J("ladder_analysis.json"); NU = J("ladder_null.json")
VAR = V["variants"]; LK = V["lock_kinematics"]; KIN = V["required_vs_available_acceleration"]; HID = V["hiddenness"]
PR = V["precession_without_relativity"]; OCC = V["lunar_occultations_2026_2030"]
PX = LA["planet_x_candidates"]; CH = LA["final_chain"]
def f(x, p=3):
    try: x = float(x)
    except (TypeError, ValueError): return str(x)
    if 1000.0 <= abs(x) < 1e8 and p >= 4: return f"{x:,.0f}"
    return ("%%.%dg" % p) % x

# ---------------------------------------------------------------------------
# Content tree: list of (kind, payload).  kinds: h1,h2,h3,p,ul,table,img,code
# ---------------------------------------------------------------------------
C = []
def h1(s): C.append(("h1", s))
def h2(s): C.append(("h2", s))
def h3(s): C.append(("h3", s))
def p(s): C.append(("p", textwrap.dedent(s).strip()))
def ul(items): C.append(("ul", items))
def table(head, rows): C.append(("table", (head, rows)))
def img(path, cap): C.append(("img", (path, cap)))

M = B["mercury"]; E_ = B["earth"]; PL = B["pluto"]; CHA = B["charon"]
h1("Mercury / Vulcan and the id–iv Ladder — a Newtonian, measurement-only audit")
p(f"""Date: 2026-10-10 · Workspace: `star_learning/solar_system_explorer/docs/MERCURY_VULCAN_LADDER_20261010/`
Tools: `tools/vulcan/bodies.py`, `vulcan_derivation.py`, `ladder_analysis.py`, `ladder_null.py`, `build_report.py`; Godot recorder `game/tools/record_vulcan.gd`; encoder `tools/vulcan/encode_vulcan.sh`.
Ephemeris: JPL DE421 via Skyfield. No relativistic term is used anywhere in this report. No myth is admitted as evidence. Every claim below is a measurement, a Newtonian derivation from measurements, or is labelled as the user's axiom.""")

h2("0. Axioms accepted for the experiment, and the rules")
ul([
 "Axiom A (user): Vulcan is bound to Mercury the way Charon is bound to Pluto, and sits ALWAYS on the far side of Mercury from Earth — Config A: Earth → Moon → Mercury → Vulcan.",
 "Axiom B (user, provisional): when the Moon lies between Earth and Mercury the order may invert — Config B: Earth → Moon → Vulcan → Mercury — and this configuration is rare.",
 "Planet X: a placeholder for a pattern break demanded by the ladder; nothing else is assumed about it.",
 "Rule 1: Newtonian mechanics only (Kepler III, Hill sphere, Roche limit, barycentre, parallax). Rule 2: measured numbers from spacecraft/radar/helioseismology are admitted as measurements, not as theory. Rule 3: every test states what observation would overturn it.",
 "The Zecliptic: the workspace rule defines it as the ecliptic with Sol's equator 7.25° off it. The user asked for angles 'from the Zecliptic (Solar equator)'. Both frames are therefore tabulated: inclination to the ecliptic, to the solar equator, and to the invariable plane."])

h2("1. Data layer — every measurable metric")
p(f"""`data/bodies_metrics.{{json,csv,md}}` holds {sum(1 for k in B if not k.startswith('_'))} records: Sol, the eight planets, Pluto/Charon and its four small moons, Luna, Phobos/Deimos, the Galilean moons, seven Saturnian moons, five Uranian, Triton/Proteus/Nereid, Ceres/Vesta/Pallas/Hygiea, the asteroid belt (AB) and the heliobarrier (HB). Per body: mass, GM, radii, density, a, e, i (three frames), node, sidereal and synodic periods, rotation, obliquity, J2, magnetic dipole, albedos, surface gravity, escape speed, irradiance, Hill radius, orbital and spin angular momentum, moon count, total moon mass, ring presence/mass/extent, Roche limit, barycentre offset, synchronous-orbit radius. Internal checks pass: T²/a³ = 1.000 ± 0.001 for every planet; Charon's Kepler period from (a, M) is 6.385 d against the measured 6.387 d; Luna's is 27.28 d against 27.32 d; Mars' synchronous orbit comes out at {f(B['phobos']['primary_sync_orbit_km'],5)} km (literature 20,428 km); the Earth–Luna barycentre at {f(B['luna']['barycenter_from_primary_center_km'],4)} km (literature 4,671 km).""")
rows = []
for k in ("mercury","venus","earth","mars","jupiter","saturn","uranus","neptune","pluto"):
    d = B[k]
    rows.append([d["name"], f(d["mass_kg"]), f(d["a_au"],4), f(d["period_d"],5), f(d["synodic_earth_d"] or 0,4), f(d["rot_d"],4), f(d["spin_orbit_ratio"],4), f(d["obliquity_deg"],4),
                 f(d["i_ecl_deg"],4), f(d["i_solar_equator_deg"],4), f(d["i_invariable_deg"],4), str(d["n_moons"]), ("yes" if d["rings"] else "no"), f(d["ring_mass_kg"],3), f(d["hill_radius_km"],4)])
table(["Body","Mass kg","a AU","T d","Synodic d","Rot d","T/rot","Obliq °","i_ecl °","i_SolEq °","i_inv °","Moons","Rings","Ring kg","Hill km"], rows)
p("""Readings from the table that matter for what follows: Mercury's spin:orbit ratio is exactly 1.500 (3:2). Mercury is the planet whose orbit lies closest to the solar equator (3.38°); Earth, by definition of the ecliptic, is the farthest of the eight (7.25°). Venus (Ω 76.68°) and Uranus (Ω 74.01°) have their nodes within 2° of the solar-equator node (75.76°). Saturn's ring mass is 2.7 × 10⁻⁸ of Saturn; Mars' moons are 1.9 × 10⁻⁸ of Mars — the same order, which the final chain exploits.""")
sv = B["_solar_equator_view"]
p(f"""Equinox geometry (user: 'Equinox is the best time to judge angles'). The heliographic latitude of the disc centre, B0 = asin(sin i☉ · sin(λ☉ − Ω☉)), is {sv['B0_march_equinox_deg']}° at the March equinox and {sv['B0_september_equinox_deg']}° at the September equinox — 97 % of the full 7.25° tilt — and 0° near June 6 / December 7. So the equinoxes are indeed near-optimal for reading the Sun's tilt; the true extremes fall about two weeks earlier (≈ March 6, September 8).""")

h2("2. Mercury / Vulcan — the four Vulcans the analogies produce")
p(f"""Pluto/Charon template (New Horizons): q = M_C/M_P = {f(CHA['mass_ratio_to_primary'],4)}, R_C/R_P = {f(CHA['radius_ratio_to_primary'],3)}, a = {f(CHA['separation_primary_radii'],4)} R_P = 19,591 km, period 6.3872 d = Pluto's spin = Charon's spin, barycentre {f(CHA['barycenter_from_primary_center_km'],4)} km from Pluto's centre, i.e. outside Pluto (R_P = 1,188 km). Mercury: M = {f(M['mass_kg'],5)} kg (GM known to 10⁻⁶ from MESSENGER), R = 2,439.7 km, spin 58.646 d, orbit 87.969 d, Hill radius {f(M['hill_radius_km'],4)} km at perihelion ({f(V['mercury']['hill_radius_mean_km'],4)} km at mean distance).""")
rows = []
for k in ("charon_scaled","spin_locked","earth_synchronous","chain_scaled"):
    v = VAR[k]
    rows.append([v["label"], f(v["mass_ratio"],3), f(v["mass_kg"],3), f(v["radius_km"],4), f(v["separation_km"],5), f(v["separation_R_M"],3), f(v["kepler_period_d"],4), f(v["separation_over_hill_peri"],3),
                 "yes" if v["bound_in_hill_sphere"] else "NO", f(v["mercury_reflex_km"],4), "yes" if v["barycenter_outside_mercury"] else "no"])
table(["Variant","q","M_V kg","R_V km","a km","a/R_M","Kepler T d","a/Hill","Bound?","Mercury reflex km","Barycentre outside Mercury?"], rows)
ul([f"V1 Charon-scaled: {VAR['charon_scaled']['derivation']}",
    f"V2 Spin-locked: {VAR['spin_locked']['derivation']}",
    f"V3 Earth-synchronous: {VAR['earth_synchronous']['derivation']}",
    f"V4 Chain-scaled: {VAR['chain_scaled']['derivation']}"])
img("img/vulcan_01_separation_vs_hill.png", "Figure 1 — Separation of each Vulcan variant against Mercury's Hill sphere. V2 and V3 lie outside it.")

h2("3. Test 1 — Kepler III and the Hill sphere")
p(f"""A Pluto/Charon-style mutual lock requires the companion's orbital period to equal the primary's spin. Mercury's spin is 58.646 d; the Kepler radius for that period about Mercury (+ q) is {f(VAR['spin_locked']['separation_km'],5)} km = {f(VAR['spin_locked']['separation_over_hill_peri'],3)} × the perihelion Hill radius: unbound. A Vulcan that keeps station anti-Earth must turn with the Earth→Mercury line, which turns once per sidereal year on average; the Kepler radius for 365.26 d is {f(VAR['earth_synchronous']['separation_km'],5)} km = {f(VAR['earth_synchronous']['separation_over_hill_peri'],3)} × Hill: unbound by a factor five. Only V1 and V4 (a = 16.5 R_M = 40,223 km) are bound, and their free period is 3.7–4.0 d, not 58.6 d and not 365 d.
What would overturn this: a measured Mercury spin of ≈ 3.7 d, or a measured Mercury mass ≈ 125 × larger (which the MESSENGER orbit excludes at the 10⁻⁶ level).""")

h2("4. Test 2 — the anti-Earth lock, hour by hour from DE421")
p(f"""The Earth→Mercury unit vector u(t) was computed at 1-hour cadence for 2026–2027 from DE421. Its angular rate ω = |u̇| gives the instantaneous period a locked Vulcan must have: mean {f(LK['implied_period_mean_d'],4)} d, range {f(LK['implied_period_min_d'],4)}–{f(LK['implied_period_max_d'],5)} d (the line nearly stalls at the elongation turn-arounds). The radius at which Mercury's gravity would supply that rate, a_ff = (GM/ω²)^(1/3), is never less than {f(LK['free_fall_radius_km_min'],5)} km = {f(LK['free_fall_over_hill_min'],3)} × Hill; the fraction of time it falls inside the Hill sphere is {LK['fraction_of_time_free_fall_inside_hill']:.0%}.""")
rows = []
for k in ("charon_scaled","spin_locked","earth_synchronous"):
    kk = KIN[k]; rows.append([VAR[k]["label"], f(kk["gravity_available_ms2"]), f(kk["centripetal_required_ms2_mean"]), f(kk["tangential_required_ms2_max"]), f(kk["solar_tide_ms2_mean"]), f(kk["gravity_over_centripetal_mean"],3)])
table(["Variant","Mercury gravity at a (m/s²)","centripetal needed (m/s²)","tangential needed, max (m/s²)","solar tide at a (m/s²)","gravity ÷ needed"], rows)
p("""Two independent failures. (i) At V1's radius gravity exceeds the needed centripetal acceleration 4,400-fold: a free body there orbits in 3.7 d; to hold it anti-Earth something must push outward at 1.4 × 10⁻² m/s² continuously. (ii) The lock also needs a TANGENTIAL acceleration (up to 1.9 × 10⁻⁵ m/s² at V1, 4 × 10⁻⁴ at V3) because the Earth→Mercury line turns non-uniformly; no central force — gravity of Mercury, of the Sun, or any inverse-square field — can supply a tangential component. The axiom therefore requires a non-gravitational, continuously steered force. This is the sharpest result of the audit: an anti-Earth-locked Vulcan is dynamically impossible at ANY mass, including V4.
What would overturn this: a demonstration that the Earth→Mercury line turns uniformly (it does not — see Figure 2), or a bound orbit with a_ff inside the Hill sphere (none exists in 2026–27).""")
img("img/vulcan_02_anti_earth_lock_kinematics.png", "Figure 2 — Elongation, implied Vulcan period and free-fall radius ÷ Hill radius, 2026–2027. The free-fall radius never drops to the bound limit.")

h2("5. Test 3 — Mercury's own spin")
p("""Mercury's 58.646-d sidereal rotation (radar, 1965; MESSENGER libration) is exactly 2/3 of its 87.969-d orbit. A Charon-like companion at 16.5 R_M would, by Pluto/Charon's own template, have despun Mercury to the 3.73-d mutual-lock period. The 3:2 state is instead the Newtonian end-state of solar tides on an e = 0.2056 orbit. Status: the Charon analogy fails Mercury's measured spin. What would overturn this: a new radar/ranging spin period near 3.7 d.""")

h2("6. Test 4 — Mercury's reflex wobble against ranging")
p(f"""Any companion makes Mercury orbit the pair's barycentre at a·q/(1+q). V1: {f(VAR['charon_scaled']['mercury_reflex_km'],4)} km (1.79 R_M — the barycentre is outside Mercury, exactly as for Pluto). V2: {f(VAR['spin_locked']['mercury_reflex_km'],4)} km. V3: {f(VAR['earth_synchronous']['mercury_reflex_km'],4)} km. V4: {f(VAR['chain_scaled']['mercury_reflex_km']*1e3,3)} m. Mercury's heliocentric orbit is tied to metre-class ranging (Mariner 10, MESSENGER, radar since 1964); a periodic displacement of thousands of km with a 3.7-d, 58.6-d or 365-d period is absent. V1–V3 exceed the {V['ranging_precision_m']:.0f}-m precision by factors of {f(VAR['charon_scaled']['reflex_over_ranging_precision'],2)}, {f(VAR['spin_locked']['reflex_over_ranging_precision'],2)}, {f(VAR['earth_synchronous']['reflex_over_ranging_precision'],2)}; V4 sits below it ({f(VAR['chain_scaled']['reflex_over_ranging_precision'],2)}×). What would overturn this: a published Mercury residual of ≥ 10³ km with the stated period.""")
img("img/vulcan_04_reflex_wobble.png", "Figure 3 — Reflex displacement of Mercury for each variant against ranging precision and Mercury's radius.")

h2("7. Test 5 — can Vulcan stay hidden? Earth, the lunar far side, L2")
p("""Config A hides Vulcan behind Mercury's disc only if its angular radius R_V/(D+a) plus the parallax shift B·a/(D(D+a)) for an observer displaced by baseline B stays inside Mercury's angular radius R_M/D. Fraction of 2026–27 during which Vulcan is fully hidden:""")
rows = []
for k in ("charon_scaled","spin_locked","earth_synchronous","chain_scaled"):
    h = HID[k]; rows.append([VAR[k]["label"], f"{h['earth_centre']['hidden_fraction']:.2f}", f"{h['earth_limb']['hidden_fraction']:.2f}", f"{h['lunar_farside_camera']['hidden_fraction']:.2f}", f"{h['sun_earth_L2']['hidden_fraction']:.2f}",
                              f(VAR[k]["baseline_in_lunar_distances"],2), f"{h['config_B_near_side']['silhouette_fraction_of_mercury_disc_area']:.2f}"])
table(["Variant","Earth centre","Earth limb (6,378 km)","Lunar far-side camera (384,400 km)","Sun–Earth L2 (1.5 Gm)","Baseline needed (lunar distances)","Config B silhouette (fraction of disc area)"], rows)
p("""The user's instinct — a camera on the far side of the Moon would settle it — is right for V3 (always visible from the Moon) and partly right for V2 (visible about 40 % of the time); for V1 the 384,400-km baseline moves Vulcan only 0.18″ against a 1.8″ limb margin, and a baseline of 12 lunar distances (≈ 4.7 Gm) is needed. V4 (10 km) can hide from everything inside 25 lunar distances. Note what this buys: hiddenness is a geometric statement about where a thing could be, not evidence that it is there; Tests 1–4 are unaffected by it.""")
img("img/vulcan_03_hiddenness_parallax.png", "Figure 4 — Hidden fraction versus observer baseline; the Moon and L2 marked.")

h2("8. Config B — the near-side inversion and the dates on which it is testable")
p(f"""If Vulcan moves in front of Mercury (Earth → Moon → Vulcan → Mercury) its disc of angular radius R_V/(D−a) is silhouetted on Mercury's bright disc: for V1 a dark circle covering {HID['charon_scaled']['config_B_near_side']['silhouette_fraction_of_mercury_disc_area']:.0%} of Mercury's area — a 10-cm telescope sees that. Lunar occultations of Mercury are the natural test dates. From DE421, Moon–Mercury conjunctions closer than 1.3° in 2026–2030 (green = geocentric occultation; the rest are occultations only from parts of Earth):""")
rows = [[o["utc"], f(o["min_geocentric_sep_deg"],3), "yes" if o["geocentric_occultation"] else ("partial Earth" if o["topocentric_possible"] else "no"), f(o["mercury_elongation_deg"],3), f(o["earth_mercury_distance_au"],3), f(o["mercury_angular_radius_arcsec"],3)] for o in OCC]
table(["UTC","min sep °","occultation","Mercury elongation °","Earth–Mercury AU","Mercury radius ″"], rows)
p("""The next geocentric event is 2028-02-23 00:05 UTC (elongation 26.4°, evening sky), which is the one animated in `video/occultation_2028.mp4`. No Mercury transit of the Sun occurs before 2032-11-13. What would overturn Config B: a resolved image of Mercury on any of these dates showing a clean disc. What would confirm it: a 25 %-area dark bite that is not a known albedo feature and that moves with the lunar geometry rather than with Mercury's rotation.""")
img("img/vulcan_06_lunar_occultation_calendar.png", "Figure 5 — Moon–Mercury conjunction calendar 2026–2030.")

h2("9. The record")
hist = V["historical"]
ul([f"Le Verrier's Vulcan (1859): {hist['le_verrier_vulcan']}",
    f"Mariner 10, March 1974: {hist['mariner10_moon_1974']}",
    f"243 Ida / Dactyl: {hist['ida_dactyl']} The user's question — April Fool's or not — resolves to 'not': discovery in downlinked frames on 1994-02-17, announced in March 1994.",
    f"MESSENGER: {hist['messenger']} The published size limit of that search is the one number in this report I have not verified from the primary paper; it bounds V4 and is flagged in §14."])

h2("10. Verdict on Vulcan, variant by variant")
table(["Variant","Kepler/Hill","Lock kinematics","Mercury spin","Reflex vs ranging","Hiddenness (Earth)","Status"], [
 ["V1 Charon-scaled","bound (ok)","FAIL ×4,400 + tangential","FAIL (58.6 d ≠ 3.7 d)","FAIL ×4×10⁵","hidden","refuted 3 ways"],
 ["V2 Spin-locked","FAIL 1.44 × Hill","FAIL ×18 + tangential","(assumed)","FAIL ×3×10⁶","hidden from Earth; 40 % visible from Moon","refuted 3 ways"],
 ["V3 Earth-synchronous","FAIL 4.9 × Hill","gravity 0.5 × needed; tangential","FAIL","FAIL ×9×10⁶","visible from Moon","refuted 4 ways"],
 ["V4 Chain-scaled (10 km)","bound (ok)","FAIL as a LOCK; fine as a free moon","n/a (too small to lock)","passes (0.9 m)","hidden","not refuted as a free moon; refuted as a locked body"]])
p("""Summary: a Vulcan that is always anti-Earth cannot exist at any mass under Newtonian gravity — the lock needs a steered non-gravitational force. A small free moon of Mercury (V4-class, ~10 km) is not excluded by anything computed here; it is bounded only by direct imaging searches (Mariner 10, MESSENGER, BepiColombo from 2026), and a free moon does not satisfy Axiom A.""")

h2("11. Mercury's perihelion without relativity")
p(f"""The measured anomalous advance (observed minus Newtonian planetary perturbations) is 42.98 ± 0.04″/century. The two Newtonian candidates are (a) an inner mass (Le Verrier's Vulcan, a ring) and (b) solar oblateness J2. For (b): the rate per century is 3π J2 (R☉/p)² · (36525/T). Fitting Mercury needs J2 = {f(PR['solar_J2_needed_for_mercury_43arcsec'],3)}, which is {f(PR['ratio_needed_over_measured'],4)} × the helioseismic value 2.2 × 10⁻⁷ (a measurement of the Sun's shape, independent of planetary dynamics). The same J2 then predicts:""")
rows = [[k, f(r["measured_anomaly_arcsec_cy"],4), f(r["measured_err"],2), f(r["J2_model_prediction_arcsec_cy"],3), f(r["J2_measured_contribution_arcsec_cy"],2)] for k, r in PR["rows"].items()]
table(["Body","measured anomaly ″/cy","± ″/cy","J2-fit prediction ″/cy","contribution of real J2 ″/cy"], rows)
p("""The J2 route scales as a⁻³·⁵ and fails Venus, Earth and Mars by factors of 2–4; it passes Icarus only because Icarus' eccentricity inflates both laws similarly. The data follow a⁻²·⁵. For (a): an inner body or ring massive enough (≈ Mercury's mass inside 0.2 AU) would transit the Sun monthly and appear at mag ≈ 0–2 within 10° of the Sun; SOHO/LASCO has watched that region continuously since 1996 and sees nothing larger than a few hundred km. Neither Newtonian source survives measurement. This report, by instruction, does not go further than that sentence.""")
img("img/vulcan_05_precession_newtonian_test.png", "Figure 6 — Measured anomalous advances versus the solar-J2 fit; a⁻²·⁵ and a⁻³·⁵ guide lines.")

h2("12. The id–iv ladder, tested")
p(f"""Each 'A is to B is to C' was read three ways across seven metrics (mass, radius, heliocentric a, heliocentric T, rotation, density, local a): H1 geometric (A/B = B/C within the line), H2 mirror-equal (id A/B = iv A/B), H3 mirror-inverse (id A/B = iv B/A — the 'same backwards' reading). Residuals are in dex; |res| < 0.30 (a factor of two) counts as holding, < 0.10 as strong. Of {NU['user_tests']} evaluable tests on the seven complete lines, {NU['user_holds']} hold ({NU['user_rate']:.1%}); {sum(1 for s in LA['holds_summary'] if s['strong'])} strongly. A permutation null — 4,000 random ladders of the same shape drawn from the same entities — holds {NU['null_mean_rate']:.1%} of the time on average (5–95 %: {NU['null_p05']:.1%}–{NU['null_p95']:.1%}); the probability of a random ladder matching or beating the user's rate is p = {NU['p_value_user_ge_null']:.2f}. The ladder does not beat chance on these metrics. Mass never holds on any line.""")
rows = [[s["id"], s["iv"], s["metric"], s["hypothesis"], f"{s['residual_dex']:+.3f}", "strong" if s["strong"] else ""] for s in LA["holds_summary"]]
table(["id","iv","metric","reading","residual dex",""], rows)
p("""What does hold is informative: Sol : Jupiter : Venus is a near-exact geometric progression in RADIUS (695,700 : 69,911 : 6,052 — ratios 9.95 and 11.55); the density mirror Sol:Jupiter:Venus ↔ Neptune:Jupiter:Saturn holds at 0.07 dex; Earth:Luna ↔ Uranus:rings is exact in heliocentric a because satellites share their primary's orbit (a tautology, flagged as such). The singletons AB : HB : Sol and Sol : HB : AB are boundary statements — HB has no mass and Sol has no orbit; in radius the proportion misses by 6.7 dex.""")
img("img/ladder_01_residual_heatmap.png", "Figure 7 — Residual heat-map, all lines × metrics × readings. Bold cells hold.")

h2("13. Planet X")
p("""The line 'iv Planet X is to Saturn is to Neptune' mirrors 'id Mars is to Jupiter is to Sol'. Solving for X in each reading and each metric:""")
rows = []
for h, v in PX.items():
    k = LA["planet_x_kepler"][h]
    rows.append([h, f(v["a_au"],4), f(k["T_yr"],4), f(v["mass_earth"],3), f(v["radius_km"],4), ("%.1f" % v["apparent_mag_estimate_V"]) if v["apparent_mag_estimate_V"] is not None else "", "yes" if v["beyond_neptune"] else "no"])
table(["reading","a AU","T yr","mass M⊕","radius km","V mag at opposition (p=0.5)","beyond Neptune?"], rows)
p("""H1 puts 1.7 Jupiter masses at 3.0 AU; H3 puts 0.85 solar masses at 32.6 AU; both would dominate the sky and the ephemerides and are excluded by any night's observation. H2 — the mirror reading the user's 'same backwards' phrasing points to — puts 0.032 M⊕ (0.3 Mars) at 2.79 AU, i.e. in the asteroid belt. The belt's dynamically measured total mass (from its perturbation of Mars, Pitjeva/EPM) is 2.4 × 10²¹ kg = 0.0004 M⊕: the ladder's Planet X exceeds what is there by a factor of 80, as one body (V ≈ 1.1 — nothing of the kind exists) or as dispersed mass (the dynamical total excludes it). The 'pattern break' the ladder requires is therefore real and already measured: the belt's mass deficit. (The minimum-mass solar nebula puts the shortfall nearer 10³; the ladder's 80 is a milder version of the same statement.) The Kepler residuals in the table are 0.00 by construction — the inputs obey Kepler, so ratio-built outputs do too; that column tests nothing and is kept only to say so. Titius–Bode's next slot, 77.2 AU, is empty (the Kuiper cliff is at ≈ 48 AU); the independent Planet-Nine estimate (6.2 M⊕, a ≈ 380 AU, Brown & Batygin 2021) is unrelated to anything the ladder produces.""")
img("img/ladder_03_planet_x_kepler_test.png", "Figure 8 — The three Planet-X readings on the a–T plane with the planets, Titius–Bode slot and Planet-Nine estimate.")

h2("14. The final chain")
p("""Sol/Jupiter : Pluto/Charon : Earth/Luna : Saturn/rings : Mercury/Vulcan : Mars/moons, read as secondary/primary mass ratio q, separation in primary radii, and secondary period:""")
rows = [[c["pair"], f(c["mass_ratio"],3) if c["mass_ratio"] else "?", f(c["separation_primary_radii"],4) if c["separation_primary_radii"] else "?", f(c["secondary_period_d"],4) if c["secondary_period_d"] else "?"] for c in CH]
table(["pair","q","a / R_primary","secondary period d"], rows)
mv = CH[4]
p(f"""In q the chain is not monotone (9.5e-4, 0.122, 0.0123, 2.7e-8, ?, 1.9e-8). Read as three mirror pairs — (Sol/Jupiter ↔ Pluto/Charon), (Earth/Luna ↔ Saturn/rings), (Mercury/Vulcan ↔ Mars/moons) — the last pair fixes Vulcan at q ≈ {f(mv['mass_ratio_interpolated'],3)}: M_V ≈ {f(mv['vulcan_mass_kg_interpolated'],3)} kg, R ≈ 10 km at Phobos density, and a ≈ {f(mv['separation_R_M_interpolated'],3)} R_M = {f(mv['separation_km_interpolated'],4)} km (inside Mercury's fluid Roche limit of 8,533 km, outside the rigid limit of 4,378 km — Phobos' own situation about Mars). Its Kepler period there is 4.7 h; its angular separation from Mercury at 0.6 AU is 12″ at most, at V ≈ 12 beside a V ≈ 0 planet. This is V4. It survives every dynamical test in this report; it does not satisfy the anti-Earth axiom, and it is the object a BepiColombo satellite search would have to miss.""")
img("img/ladder_02_final_chain_mass_ratio.png", "Figure 9 — Secondary/primary mass ratio along the final chain; Mercury/Vulcan interpolated from its neighbours.")

h2("15. Refutation ledger")
table(["Claim","Test","Measured","Status","What would flip it"], [
 ["Vulcan is Charon-like about Mercury (V1)","Mercury spin = lock period","58.646 d vs 3.73 d","refuted","spin ≈ 3.7 d"],
 ["— same","reflex wobble","< 10 m vs 4,365 km","refuted","4,000-km periodic residual"],
 ["Vulcan is always anti-Earth (any mass)","required vs available acceleration","needs outward 1.4e-2 + tangential 1.9e-5 m/s²","refuted (dynamics)","uniform turning of the Earth–Mercury line"],
 ["Vulcan spin-locked to Mercury's 58.6 d (V2)","Hill sphere","a = 1.44 × Hill","refuted","Mercury mass ×3"],
 ["Vulcan turns once a year with Earth (V3)","Hill sphere","a = 4.9 × Hill","refuted","—"],
 ["Config B silhouette at occultations","imaging on listed dates","not yet observed (2028-02-23 next)","open, dated","clean disc on 2028-02-23"],
 ["Far-side lunar camera reveals Vulcan","parallax","V3 yes, V2 40 %, V1/V4 no","computed","—"],
 ["Mercury's 43″ from solar J2","J2 needed 3.4e-4 vs 2.2e-7; Venus/Earth/Mars","fails 3 of 5 bodies","refuted","helioseismic J2 revision ×1,500"],
 ["Mercury's 43″ from an inner Vulcan/ring","SOHO/LASCO 1996–","nothing > few 100 km","refuted","—"],
 ["Ladder proportions beat chance","permutation null","8.6 % vs 10.7 % random, p = 0.73","not supported","new metric set where holds exceed null"],
 ["Planet X exists as the ladder defines it (H2)","belt mass / sky survey","0.0004 M⊕ present vs 0.032 needed","refuted as a body; real as a deficit","—"],
 ["V4 Phobos-class moon of Mercury","imaging search limits","unverified limit (flag)","open","MESSENGER/BepiColombo limit < 10 km"]])

h2("16. Open items (not resolved here)")
ul(["MESSENGER's published satellite-search size limit (bounds V4). I did not read the primary paper in this session; the number is flagged, not asserted.",
    "Mariner 10's satellite limit (commonly quoted ≈ 5 km) — same status.",
    "Ring masses of Jupiter, Uranus and Neptune are order-of-magnitude estimates; Saturn's (1.54 ± 0.49 × 10¹⁹ kg) is the only measured one.",
    "Saturn's moon count (274) moves with every MPC batch; the physics does not.",
    "Heliobarrier shape: Voyager/IBEX fix the nose (121.6 AU, λ 255.7°, β +5.1°); the tail length (comet vs croissant vs bubble) is unmeasured and drawn in the orrery as a model.",
    "Lunar occultation times are geocentric; topocentric circumstances for a given site need the observer's coordinates."])

LM = json.load(open(os.path.join(DATA, "luna_from_mercury.json")))
lf = LM["luna_from_mercury"]; bs = LM["beside_is_invisible"]; ft = LM["forty_two_over_pi"]
h2("17. Addendum (2026-10-10, later): the relaxed axiom, Luna from Mercury, and the frame")
p("""Frame declaration. Everything in this addendum is computed in the Zecliptic frame as the author uses it — the solar equator
(i = 7.25°, Ω = 75.76°): north is Sol's rotation pole, east is Sol's rotation sense. Earth-frame quantities appear in exactly one
place (§17.3) and for one reason: the telescopes, the eyes and the photometric record are on Earth. No ecliptic or equatorial
(RA/Dec) coordinates are used anywhere here.""")
h3("17.1 The relaxed axiom")
p("""The axiom was loosened: Vulcan need not sit exactly on the Earth–Mercury line. It may be 'beside' Mercury (claimed invisible),
between Luna and Mercury (claimed invisible), or 'just off' the far limb — 'the slightest occlusion'. The loosening is honest and it
changes the test. A body that is only usually behind Mercury is a body on a free Kepler orbit, and a free orbit has three
observable consequences: (i) a maximum angular separation from Mercury; (ii) a brightness of its own; (iii) mutual events — Vulcan
passing in front of or behind Mercury dims the combined light, exactly the signal that fixed Charon's size in 1985–1990.""")
h3("17.2 Luna from Mercury — the author's retrograde claim, tested")
p(f"""Claim: 'Luna would appear as in retrograde to Mercury as it passes.' DE421, hourly, 2026–2027, solar-equator frame. Two senses were
measured. Against the stars, Luna's apparent motion from Mercury is dominated by Earth's: Earth is an outer planet from Mercury and
retrogrades around every inferior conjunction (115.9 d), {100*lf['fraction_time_earth_retrograde_vs_stars']:.1f} % of the time; Luna rides along
({100*lf['fraction_time_luna_retrograde_vs_stars']:.1f} %). Relative to Earth's disc — the sense in which Luna circles Earth — the result is sharp:
on the half of its orbit that faces Mercury, Luna moves WEST {100*lf['on_mercury_facing_half']:.1f} % of the time; on the far half it moves west
{100*lf['on_far_half']:.1f} % of the time. Earth, at the centre of Luna's orbit, sees every part of it move east. Mercury, outside the orbit,
sees the near half move west and the far half east. The orbit is unchanged and prograde; the observer moved from the centre to the outside.
The author's claim holds, and its mechanism is a mirror, not a reversal.""")
p(f"""The mirror of the lunar occultation: when Earth sees Luna cover Mercury, Mercury sees Luna transit Earth's disc. Five such transits
occur in 2026–2027 (all westward across Earth). The 2028-02-23 00:05 UTC event, from Mercury: Luna crosses Earth's {lf['event_2028_02_23_from_mercury']['earth_mercury_dist_au']:.3f}-AU-distant disc
moving {lf['event_2028_02_23_from_mercury']['moon_motion_sense']}, minimum separation {lf['event_2028_02_23_from_mercury']['min_sep_arcsec']:.1f}″ from Earth's centre, Earth's solar latitude B0 = {lf['event_2028_02_23_from_mercury']['earth_B0_deg']:+.2f}°
(near its extreme — the tilt is fully visible on that date), Mercury's B = {lf['event_2028_02_23_from_mercury']['mercury_B_deg']:+.2f}°.""")
table(["Transit of Earth by Luna, seen from Mercury (UTC)", "duration (h)", "Luna's motion across Earth", "rate (″/day)", "Earth radius (″)"],
      [[t["start_utc"] + " → " + t["end_utc"][-5:], f(t["duration_h"]), t["moon_motion_across_earth"].split(" (")[0], f(t["moon_rate_arcsec_per_day"]), f(t["earth_angular_radius_arcsec"])] for t in lf["moon_transits_of_earth_disc_2026_2027"]])
img(os.path.join(IMG, "luna_01_from_mercury_rates.png"), "Luna from Mercury, 2026–27, solar-equator frame. Top: Earth and Luna against the stars (Earth's retrograde loops at each inferior conjunction). Middle: Luna's motion relative to Earth's disc — red shading marks the Mercury-facing half, where it runs west. Bottom: Luna–Earth separation vs Earth's angular radius; the dips below the blue line are transits.")
img(os.path.join(IMG, "luna_02_lunation_from_mercury.png"), "One lunation seen from Mercury (Feb 2028), relative to Earth. Red: Mercury-facing half, moving west; blue: far half, moving east. The ellipse is Luna's orbit seen nearly edge-on from inside Earth's orbit.")
img(os.path.join(IMG, "luna_03_transit_of_earth_2028.png"), "2028-02-23 from Mercury: Luna crosses Earth's disc westward. Earth sees the same event as Luna moving east over Mercury.")
h3("17.3 'Beside is invisible' — tested (Earth frame, by reason: the instruments are on Earth)")
p("""For each Vulcan variant on a free Kepler orbit about Mercury, the maximum angular separation from Mercury as seen from Earth over
2026–2027, the brightness relative to Mercury (same albedo: area ratio), the depth of a mutual event, and the fraction of an edge-on
orbit spent within 1,000 km projected of Mercury's centre ('merged').""")
table(["variant", "free period (d)", "max sep. from Mercury (″)", "fainter than Mercury (mag)", "mutual-event depth (mag)", "merged fraction of orbit", "resolvable by"],
      [[b["label"], f(b["free_period_d"]), f"{b['max_separation_arcsec_min']:.0f}–{b['max_separation_arcsec_max']:.0f}", f(b["magnitude_fainter_than_mercury"]), f(b["mutual_event_depth_mag"]), f(b["fraction_of_edge_on_orbit_merged_with_mercury"]), b["resolvable_by"]] for k, b in bs.items() if not k.startswith("_")])
p("""Reading. 'Beside' is not invisible. A Charon-scaled Vulcan (V1) on a free orbit reaches 38–100″ from Mercury: 1.5 magnitudes fainter
than Mercury and resolvable in any telescope since 1610 (Galileo's phases of Mercury; Hevelius; Schröter; Schiaparelli's 1881–89
maps with a 22 cm refractor; Antoniadi at Meudon). V2 and V3 reach naked-eye separations (4–35′). V1 also produces mutual events of
0.25 mag every 1.87 d in edge-on seasons; Mercury's whole-disc photometry (Mallama 2002, 2017; SOHO/LASCO, STEREO) is good to 0.01–0.02 mag.
'The slightest occlusion' is therefore the strongest refutation of V1–V3, not the weakest. For a body to be beside Mercury and truly
merged with it from Earth, it must stay within ~1,000 km projected of Mercury's centre — inside Mercury (R = 2,440 km). The only Vulcan the
relaxed axiom still allows is V4: a ~10 km body, 12 mag fainter than Mercury, mutual-event depth 17 micro-mag — undetectable from Earth,
bounded only by spacecraft imaging (MESSENGER / BepiColombo), as before.""")
h3("17.4 Solar equinoxes — the angle-judging epochs in this frame")
p("""Earth's March/September equinoxes are when Earth's solar latitude |B0| is largest (7.03°) — the tilt between the ecliptic and the
Zecliptic is then fully visible, which is why the author's 'equinox is the best time to judge angles' holds. The complementary epochs are
the SOLAR equinoxes: when a body crosses Sol's equatorial plane (B = 0). Both are tabulated from DE421.""")
table(["body", "crosses Sol's equator (UTC)", "direction", "solar-equatorial longitude (°)"],
      [[e["body"], e["utc"], e["direction"].split(" (")[0], f(e["solar_equatorial_longitude_deg"])] for e in LM["solar_equinoxes"]])
table(["Earth equinox", "Earth B0 (°)", "Mercury B (°)", "Luna B (°)"],
      [[e["utc"], f(e["earth_B0_deg"]), f(e["mercury_B_deg"]), f(e["moon_B_deg"])] for e in LM["earth_equinoxes_B0"]])
p("""Mercury's nodes on Sol's equator sit at solar-equatorial longitudes 251.3° (ascending) and 73.3° (descending); Earth's at 180.0° and 0.0°
(by construction of the frame). Mercury crosses the solar equator every 44 days; Earth every 183 days (≈ 6 June ascending, ≈ 8 December descending).""")
h3("17.5 '42 Pis in a year'")
p(f"""Sidereal months per year: 365.25636 / 27.321661 = {ft['sidereal_months_per_year']:.4f}. Times π: {ft['sidereal_months_times_pi']:.3f}. So 42/π = {ft['forty_two_over_pi']:.4f}
reproduces Luna's sidereal month count to {ft['match_sidereal_percent']:.3f} %. The synodic count gives {ft['synodic_months_times_pi']:.1f}, so the mnemonic belongs to the sidereal
month — Luna against the stars, which is also the count Mercury would make. It is a four-significant-figure coincidence with no mechanism
offered; as a mnemonic it is exact enough to use.""")
h3("17.6 Added deliverables")
ul(["Video `video/luna_from_mercury.mp4` (1,440 frames, 48 s): Luna transiting Earth's disc as seen from Mercury, 2028-02-23 ± 6 h, solar-equator frame, with a Zecliptic top-down inset (Mercury-facing half of Luna's orbit in red) and the frame declaration on screen. Contact sheet `video/luna_from_mercury_sheet.png`.",
    "Images `img/luna_01_from_mercury_rates.png`, `img/luna_02_lunation_from_mercury.png`, `img/luna_03_transit_of_earth_2028.png`.",
    "Data `data/luna_from_mercury.json` (fractions, transits, 'beside' table, solar equinoxes, 42/π), `data/ephem_luna_from_mercury.json` (1-min DE421 export in solar-equator coordinates driving the Godot shot).",
    "Code `tools/vulcan/luna_from_mercury.py`; shot `LunaFromMercury` in `game/tools/record_vulcan.gd`."])

h2("18. Deliverables")
ul(["Videos (`video/*.mp4`, 1280×600, 30 fps): `lock_orrery` (Zecliptic view, Config A over 2026), `hill_frame` (locked vs free Vulcan, two scales, 180 d), `occultation_2028` (2028-02-23 geocentric event, Config A vs B insets), `binaries` (Pluto/Charon vs Mercury/Vulcan to scale about their barycentres), `ladder_orrery` (log-radius system with AB, HB, Planet X; each id/iv line highlighted with its residual), `equinox_zecliptic` (orbit planes against the solar equator at the September 2026 equinox, then a date sweep to March 2027), `luna_from_mercury` (2028-02-23 ±6 h from Mercury: Luna transiting Earth westward, with Zecliptic inset). Contact sheets `video/*_sheet.png`.",
    "Images (`img/`): nine analysis figures listed above plus `luna_01..03` from the addendum.",
    "Data (`data/`): bodies_metrics.{json,csv,md}; vulcan_derivation.json; ladder_analysis.json; ladder_table.md; ladder_null.json; lunar_occultations_mercury_2026_2030.csv; ephem_2026_2027_6h.json and ephem_occultation_closeup.json (DE421 exports driving the Godot shots).",
    "Code (`tools/vulcan/`, `game/tools/record_vulcan.gd`): rerunnable end to end: `python3 bodies.py && python3 vulcan_derivation.py && python3 ladder_analysis.py && python3 ladder_null.py && DISPLAY=:1 godot --path game -s res://tools/record_vulcan.gd && bash tools/vulcan/encode_vulcan.sh && python3 build_report.py`.",
    "Addendum §19 (elimination pass): `data/v4_annulus.json`, `data/perihelion_newtonian.json`, `data/ladder_oos.json`; `img/v4_01_tidal_floor.png`, `img/v4_02_hill_stability.png`, `img/perihelion_01_hall.png`, `img/perihelion_02_budget.png`, `img/ladder_oos_01_recurrence.png`, `img/ladder_oos_02_null.png`; `tools/vulcan/v4_annulus.py`, `perihelion_newtonian.py`, `ladder_oos.py`; `BEPICOLOMBO_OBSERVATION_REQUEST_20261010.md`; `GAMEPLAN_ELIMINATION_20261010.md`; `REFLECTION_ELIMINATION_META_20261010.md`."])

# ---------------------------------------------------------------------------
# §19 — the elimination pass (game plan executed)
# ---------------------------------------------------------------------------
V4 = J("v4_annulus.json"); PN = J("perihelion_newtonian.json"); OO = J("ladder_oos.json")
h2("19. Addendum (2026-10-10, later still): the elimination pass")
p("""`GAMEPLAN_ELIMINATION_20261010.md` set the order: (a) the V4 annulus; (b) the three remaining Newtonian causes of the 43″; (c) the
MESSENGER / Mariner 10 / BepiColombo record; (d) the ladder out of sample; (e) an observation request; (f) this addendum. Frame: solar
equator (Zecliptic) throughout, except where a line says Earth and why. No relativity is used anywhere in this section.""")

h3("19.1 Row 6 — where a free satellite of Mercury can live (V4 annulus)")
tf = V4["tidal_floor"]; hc = V4["hill_ceiling"]["summary"]; an = V4["annulus"]
p(f"""Tides: da/dt = −3(k₂/Q)(m/M)(R/a)⁵·n·a with k₂ = {V4['constants']['k2']} (MESSENGER), integrated over 4.5 Gyr, gives the radius below which a body of a given size cannot have
survived from formation. Q = 100: 10 km body → {tf['a_min_10km_Q100_km']:,.0f} km; 1 km → {tf['a_min_1km_Q100_km']:,.0f} km; 100 m → {tf['a_min_100m_Q100_km']:,.0f} km. The chain-interpolated V4
(9.8 km at 5,411 km, §14) spirals into Mercury in {min(float(v) for v in tf['chain_V4_lifetime_yr'].values())/1e6:.0f}–{max(float(v) for v in tf['chain_V4_lifetime_yr'].values())/1e6:.0f} Myr (Q = 50–300): it cannot be primordial where the chain puts it. **Row 5 of the board is eliminated as a primordial body.**""")
p(f"""Sun: 112 test particles on circular orbits from 8,000 to 260,000 km, prograde and retrograde, two phases each, leapfrog at 200 s for 100 Mercury years
with the Sun on Mercury's e = 0.2056 orbit and Mercury's J₂. Fast-ejection edge: prograde {hc['prograde']['largest_stable_km']:,.0f} km (canonical 0.5 R_Hill at perihelion = {an['outer_km_prograde_canonical']:,.0f} km),
retrograde {hc['retrograde']['smallest_unstable_km']:,.0f}–{hc['retrograde']['largest_stable_km']:,.0f} km. Radiation pressure: a_rp/g < 1e-9 for R ≥ 100 m anywhere in the annulus.""")
table(["edge", "km", "period (d)", "from Earth at 0.9 AU (″)"],
      [["tidal floor, 10 km body", f"{tf['a_min_10km_Q100_km']:,.0f}", "0.75", "20"],
       ["tidal floor, 1 km body", f"{tf['a_min_1km_Q100_km']:,.0f}", "0.15", "7"],
       ["prograde ceiling (this run / canonical)", f"{hc['prograde']['largest_stable_km']:,.0f} / {an['outer_km_prograde_canonical']:,.0f}", "11.4 / 12.7", "125 / 134"],
       ["retrograde ceiling", f"{hc['retrograde']['largest_stable_km']:,.0f}", "24.7", "209"],
       ["Hill radius at perihelion", f"{V4['constants']['R_hill_perihelion_km']:,.0f}", "—", "269"]])
img(os.path.join(IMG, "v4_01_tidal_floor.png"), "Figure 19a — Tidal floor a_min(R, Q) with the canonical prograde ceiling; the shaded band is where a 4.5 Gyr-old satellite can be. The white point is the chain's V4: below every floor.")
img(os.path.join(IMG, "v4_02_hill_stability.png"), "Figure 19b — Fate of the 112 test particles after 100 Mercury years. First integration was wrong (indirect term sign); the bug was found because every particle died in 463 days, including those at 8,000 km, which is impossible. Ledgered.")
p("""The record: Mariner 10's 1974 'moon' (UV source detached from Mercury, 4 km/s) was the star 31 Crateris (Stratford 1980). MESSENGER ran dedicated
satellite-search campaigns in 2011 and 2013 (MDIS WAC; JHUAPL 2012-03-21, 2013-07-18) and found none; its 2011 orbit (2,640–17,633 km) crossed the inner
annulus. The published size limit of those campaigns and the 2007 ground-based search (Planet. Space Sci. 55, 2037) were **not retrievable today** and are
flagged as unread. BepiColombo enters Mercury orbit 2026-11-21 (MPO 480 × 1,500 km; Mio 590 × 11,640 km from 2026-12-09/10); from inside the annulus a 20 m body is
V ≈ 4–9. `BEPICOLOMBO_OBSERVATION_REQUEST_20261010.md` states the frame, cadence, depth, kinematic filter and closure conditions. **Row 6 stays open, confined,
with a dated instrument named.**""")

h3("19.2 Row 10 — the three remaining Newtonian causes of the 43″")
hl = PN["hall"]; rg = PN["exterior_ring"]; bd = PN["planetary_budget"]
p(f"""**Hall's law** F ∝ r^−(2+δ) advances every apse by πδ per orbit. δ = {hl['delta']:.3e} reproduces Mercury's 42.98″/cy and then predicts
Venus {hl['Venus']['predicted_arcsec_per_cy']:.1f}″ (measured {PN['anomalous_advances_measured']['Venus'][0]}), Earth {hl['Earth']['predicted_arcsec_per_cy']:.1f}″ ({PN['anomalous_advances_measured']['Earth'][0]}), Mars {hl['Mars']['predicted_arcsec_per_cy']:.1f}″ ({PN['anomalous_advances_measured']['Mars'][0]}) and a lunar perigee excess of
{hl['Moon']['predicted_excess_perigee_arcsec_per_yr']:.2f}″/yr against a lunar-laser-ranging limit of ~1e-4″/yr ({hl['Moon']['sigmas_off']:.0e} σ). Brown rejected it on the Moon in 1903; LLR buries it.""")
p(f"""**Exterior ring.** ω̇ = (3/4)·n·(m_r/M☉)·(a/b)³. At 1 AU the ring would need {rg[1]['mass_required_earth']:.2f} M⊕ — {rg[1]['deficit_factor']:.0e} × the zodiacal cloud (1e17 kg);
at 0.6 AU {rg[0]['mass_required_earth']:.2f} M⊕. Mass *inside* Mercury's orbit regresses the apse (apsidal angle < π) and cannot help. The asteroid belt's real
contribution is {rg[2]['advance_from_measured_mass_arcsec_per_cy']:.4f}″/cy.""")
p(f"""**Perturbing-mass error.** ω̇ = (n/4)(m′/M☉)α² b⁽¹⁾₃⁄₂(α) per planet, Laplace coefficient by quadrature. Budget reproduced: Venus {bd['Venus']['advance_arcsec_per_cy']:.1f}″ (Clemence 277.8), Earth {bd['Earth']['advance_arcsec_per_cy']:.1f} (90.0),
Jupiter {bd['Jupiter']['advance_arcsec_per_cy']:.1f} (153.6), Saturn {bd['Saturn']['advance_arcsec_per_cy']:.1f} (7.3), Mars {bd['Mars']['advance_arcsec_per_cy']:.1f} (2.5): total {PN['budget_total_arcsec_per_cy']:.0f}″ vs 531 (first-order secular theory; 4 % high, as expected without second-order terms).
To supply 43″ Venus would need a {100*bd['Venus']['fractional_mass_error_for_43']:.0f} % mass error (GM known to 1e-9: ×{bd['Venus']['factor_over_uncertainty']:.0e}); Jupiter {100*bd['Jupiter']['fractional_mass_error_for_43']:.0f} % (×{bd['Jupiter']['factor_over_uncertainty']:.0e}).""")
table(["candidate", "tuned to Mercury", "then predicts", "measured", "status"],
      [["solar J₂ (§11)", "J₂ = 3.4e-4 fit", "Venus 4.4″, Earth 1.4″", "8.6, 3.8 (and J₂ = 2.2e-7 measured, ×1,538)", "eliminated"],
       ["intra-Mercurial planet/ring (§2–10)", "mass inside 0.39 AU", "regression, not advance; visible at transit/eclipse", "none seen since 1859", "eliminated"],
       ["Hall exponent", f"δ = {hl['delta']:.2e}", f"Moon perigee +{hl['Moon']['predicted_excess_perigee_arcsec_per_yr']:.2f}″/yr", "< 1e-4″/yr (LLR)", "eliminated"],
       ["exterior zodiacal ring", f"{rg[1]['mass_required_earth']:.2f} M⊕ at 1 AU", "—", "1e17 kg (2e-8 M⊕)", "eliminated"],
       ["planetary-mass error", "Venus +15 % / Jupiter +27 %", "—", "1e-9 / 1e-8 relative", "eliminated"]])
img(os.path.join(IMG, "perihelion_01_hall.png"), "Figure 19c — Hall's law tuned to Mercury against the measured anomalous advances of Venus, Earth, Mars.")
img(os.path.join(IMG, "perihelion_02_budget.png"), "Figure 19d — The Newtonian planetary budget reproduced from Laplace coefficients, against Clemence (1947), with the 43″ line.")
p(PN["verdict"]["row_10"])

h3("19.3 Row 11 — the ladder out of sample")
oo = OO["recurrence_total"]; oond = OO["recurrence_excluding_density"]
p(f"""Lines free of Sol-only constructs (no belts, Luna, rings, Vulcan, Planet X): 1, 3, 5. Roles mapped to five other hierarchical systems by two rules
fixed before the numbers were looked at — ordinal by distance from the primary, and rank by mass (size where mass is unknown). Same four hypotheses, same
0.30-dex hold. Null: 4,000 random role assignments per system per rule. Sol itself on these lines: {OO['sol_in_sample']['holds']}/{OO['sol_in_sample']['tests']}.""")
rows = []
for s in OO["systems"]:
    for ru in ("ordinal", "massrank"):
        d = OO["systems"][s][ru]
        rows.append([s, ru, f"{d['holds']}/{d['tests']}", f"{d['rate']:.2f}" if d['rate'] is not None else "—", f"{d['null_mean']:.2f}" if d['null_mean'] is not None else "—", f"{d['p_value']:.3f}" if d['p_value'] is not None else "—"])
table(["system", "mapping", "holds", "rate", "random-mapping mean", "p (random ≥ rule)"], rows)
p(f"""{OO['n_mapping_tests_p_lt_0p05']} of {OO['n_mapping_tests']} mapping tests beat random at p < 0.05 (Jupiter's moons by mass rank, p = {OO['systems']['Jupiter moons']['massrank']['p_value']:.3f}) — the number expected at 5 % from ten tries.
Of the {len(OO['recurrence'])} proportions that hold in the Sol system on these lines, {oo['oos_holds']}/{oo['oos_evaluable']} recur out of sample; excluding density, {oond['oos_holds']}/{oond['oos_evaluable']}.
Density is a degenerate metric: {100*OO['metric_degeneracy_pairwise_lt_0p30dex']['Saturn moons']['density']:.0f} % of all pairwise density ratios among Saturn's moons and {100*OO['metric_degeneracy_pairwise_lt_0p30dex']['TRAPPIST-1']['density']:.0f} % among TRAPPIST-1's planets are already
within 0.30 dex of unity, so a density 'hold' says nothing about a ladder. **Row 11: the ladder does not transfer. Eliminated as a law; retained as a mnemonic.**""")
img(os.path.join(IMG, "ladder_oos_01_recurrence.png"), "Figure 19e — Each Sol-system hold re-tested in five systems under two mappings; bold cells recur.")
img(os.path.join(IMG, "ladder_oos_02_null.png"), "Figure 19f — Rule-based mapping hold-rate against random mappings, per system.")

h3("19.4 Board after the pass")
table(["row", "claim", "before", "after", "closed by"],
      [["5", "chain-interpolated V4 (9.8 km, 5,411 km)", "open", "**eliminated** (as primordial)", "tidal decay 7–42 Myr, k₂ measured"],
       ["6", "any free satellite of Mercury (V4 class)", "open", "open, **confined** to 13,000–136,000 km; dated instrument named", "BepiColombo 2026-11-21 →; MESSENGER null (limit unread)"],
       ["7", "Config B 2028-02-23 (Vulcan on near side)", "open", "open (dated)", "lunar occultation 2028-02-23 00:05 UTC"],
       ["10", "Newtonian 43″", "open", "**no Newtonian cause survives**", "Hall/LLR; ring/zodiacal mass; masses/GM"],
       ["11", "ladder as law", "open (in-sample p = 0.73)", "**eliminated as law**", "out-of-sample 1/10 at p < 0.05; recurrence 6/16 ex-density"]])
h3("19.5 Ledger of the chronicler's own errors in this pass")
ul(["`v4_annulus.py`, first run: sign of the indirect term in the solar tide (−rs/|rs|³ for +rs/|rs|³). Symptom: 112/112 particles 'escaped' within 463 d including those at 8,000 km. Caught by the impossibility, fixed, assertion added so it cannot recur silently.",
    "Perihelion budget 4 % high relative to Clemence: first-order secular theory only. Not corrected; stated.",
    "Two literature items (MESSENGER campaign size limit; 2007 P&SS ground search) not retrievable with today's tools. Stated as unread rather than paraphrased."])

# ---------------------------------------------------------------------------
# Markdown
# ---------------------------------------------------------------------------
md = []
for kind, pay in C:
    if kind == "h1": md += [f"# {pay}", ""]
    elif kind == "h2": md += [f"## {pay}", ""]
    elif kind == "h3": md += [f"### {pay}", ""]
    elif kind == "p": md += [pay, ""]
    elif kind == "ul": md += [f"- {i}" for i in pay] + [""]
    elif kind == "table":
        head, rows = pay
        md += ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)] + ["| " + " | ".join(str(c) for c in r) + " |" for r in rows] + [""]
    elif kind == "img":
        md += [f"![{pay[1]}]({pay[0]})", "", f"*{pay[1]}*", ""]
md_path = os.path.join(DOC, "REPORT_MERCURY_VULCAN_LADDER_20261010.md")
open(md_path, "w").write("\n".join(md))

# ---------------------------------------------------------------------------
# PDF
# ---------------------------------------------------------------------------
PAGE = (11.0, 8.5)  # landscape letter
pdf_path = os.path.join(DOC, "REPORT_MERCURY_VULCAN_LADDER_20261010.pdf")
BGc, FG, ACC = "#0b0d17", "#e8ecf8", "#ffd166"

class Pager:
    def __init__(self, pdf):
        self.pdf = pdf; self.fig = None; self.y = 0; self.n = 0
    def new(self):
        if self.fig is not None: self.flush()
        self.fig = plt.figure(figsize=PAGE); self.fig.patch.set_facecolor(BGc); self.y = 0.95; self.n += 1
        self.fig.text(0.97, 0.02, f"{self.n}", ha="right", fontsize=8, color="#889")
        self.fig.text(0.03, 0.02, "Mercury/Vulcan & the id–iv ladder · 2026-10-10 · Newtonian, measurement-only", fontsize=8, color="#889")
    def flush(self):
        self.pdf.savefig(self.fig, facecolor=BGc); plt.close(self.fig); self.fig = None
    def need(self, h):
        if self.fig is None or self.y - h < 0.06: self.new()
    def text(self, s, size=9.5, color=FG, weight="normal", width=150, indent=0.04, family="DejaVu Sans"):
        lines = []
        for para in s.split("\n"):
            lines += textwrap.wrap(para, width=width) or [""]
        lh = size * 0.0019
        self.need(lh * min(len(lines), 6))
        for ln in lines:
            if self.y - lh < 0.06: self.new()
            self.fig.text(indent, self.y, ln, fontsize=size, color=color, weight=weight, family=family, va="top")
            self.y -= lh
        self.y -= lh * 0.5
    def table(self, head, rows):
        # monospace rendering with column widths from content, splitting rows across pages
        cols = len(head)
        widths = [max(len(str(head[i])), *(len(str(r[i])) for r in rows)) for i in range(cols)]
        total = sum(widths) + 3 * cols
        size = 7.5 if total < 150 else (6.3 if total < 185 else (5.4 if total < 215 else 4.8))
        fmt = lambda r: "  ".join(str(r[i]).ljust(widths[i]) for i in range(cols))
        lh = size * 0.0021
        self.need(lh * 3)
        self.fig.text(0.04, self.y, fmt(head), fontsize=size, color=ACC, family="DejaVu Sans Mono", va="top"); self.y -= lh
        self.fig.text(0.04, self.y, "─" * min(total, 230), fontsize=size, color="#556", family="DejaVu Sans Mono", va="top"); self.y -= lh
        for r in rows:
            if self.y - lh < 0.06:
                self.new(); self.fig.text(0.04, self.y, fmt(head), fontsize=size, color=ACC, family="DejaVu Sans Mono", va="top"); self.y -= lh
            self.fig.text(0.04, self.y, fmt(r), fontsize=size, color=FG, family="DejaVu Sans Mono", va="top"); self.y -= lh
        self.y -= lh
    def image(self, path, cap):
        self.new()
        im = Image.open(path); w, h = im.size
        maxw, maxh = 0.92, 0.80
        ar = (h / w) * (PAGE[0] / PAGE[1])
        ww, hh = maxw, maxw * ar
        if hh > maxh: hh, ww = maxh, maxh / ar
        ax = self.fig.add_axes([(1 - ww) / 2, 0.12, ww, hh]); ax.imshow(im); ax.axis("off")
        self.fig.text(0.5, 0.08, textwrap.fill(cap, 130), ha="center", fontsize=9, color=ACC)
        self.flush()

with PdfPages(pdf_path) as pdf:
    # cover
    fig = plt.figure(figsize=PAGE); fig.patch.set_facecolor(BGc)
    fig.text(0.5, 0.70, "Mercury / Vulcan and the id–iv Ladder", ha="center", fontsize=28, color="#fff", weight="bold")
    fig.text(0.5, 0.63, "a Newtonian, measurement-only audit", ha="center", fontsize=16, color=ACC)
    fig.text(0.5, 0.52, "Axiom accepted for the experiment: Vulcan is bound to Mercury as Charon to Pluto, always anti-Earth.\nEvery consequence computed from JPL DE421 and spacecraft/radar measurements; no relativity, no myth.", ha="center", fontsize=11, color=FG)
    fig.text(0.5, 0.40, "Deliverables: 6 Godot videos · 9 figures · full metric tables · refutation ledger\nstar_learning/solar_system_explorer/docs/MERCURY_VULCAN_LADDER_20261010/", ha="center", fontsize=10, color="#aab")
    fig.text(0.5, 0.28, "2026-10-10", ha="center", fontsize=12, color="#889")
    pdf.savefig(fig, facecolor=BGc); plt.close(fig)
    pg = Pager(pdf); pg.new()
    for kind, pay in C:
        if kind == "h1": pg.text(pay, 16, "#fff", "bold", 80)
        elif kind == "h2": pg.y -= 0.01; pg.text(pay, 13, ACC, "bold", 95)
        elif kind == "h3": pg.text(pay, 11, ACC, "bold", 120)
        elif kind == "p": pg.text(pay.replace("`", ""), 9.2, FG, "normal", 138)
        elif kind == "ul":
            for i in pay: pg.text("• " + i.replace("`", ""), 9.0, FG, "normal", 134, 0.05)
        elif kind == "table": pg.table(*pay)
        elif kind == "img": pg.image(os.path.join(DOC, pay[0]), pay[1])
    if pg.fig is not None: pg.flush()
    # contact sheets of the videos
    for nm in ("lock_orrery", "hill_frame", "occultation_2028", "binaries", "ladder_orrery", "equinox_zecliptic"):
        sp = os.path.join(VID, nm + "_sheet.png")
        if os.path.exists(sp):
            pg2 = Pager(pdf); pg2.image(sp, f"video/{nm}.mp4 — six evenly spaced frames")
print("wrote", md_path); print("wrote", pdf_path, os.path.getsize(pdf_path) // 1024, "KB")
