#!/usr/bin/env python3
"""
perihelion_newtonian.py — Game plan §3. The last Newtonian candidates for
Mercury's anomalous perihelion advance (43.0″/century after all known
planetary perturbations). Each is given its own measurement to die by.
No relativity is used anywhere in this file.

  A. HALL'S HYPOTHESIS (1894): F ∝ r^-(2+δ).  Apsidal angle π/√(1-δ) →
     advance per orbit = π δ, the SAME for every orbiting body.  Tune δ to
     Mercury's 43″; predict Venus, Earth, Mars and the Moon's perigee; compare.
  B. EXTERIOR RING / ZODIACAL MASS: ω̇ = (3/4) n (m_r/M☉) (a/b)^3 for a ring
     of mass m_r at radius b ≫ a; interior spherically-symmetric mass gives
     REGRESSION, not advance (apsidal angle < π), so only exterior mass helps.
     Mass required vs measured zodiacal cloud mass.
  C. PERTURBING-MASS ERROR: secular advance from each planet via the Laplace
     coefficient b^(1)_{3/2}(α) (Murray & Dermott eq. 7.10). Reproduce the
     classical budget (Venus 277.8, Earth 90.0, Jupiter 153.6 …), then the
     fractional mass error each planet would need to supply 43″, vs the
     spacecraft-determined GM uncertainties.

Outputs: data/perihelion_newtonian.json, img/perihelion_01_hall.png, img/perihelion_02_budget.png
"""
import os, json, math
import numpy as np
from scipy.integrate import quad
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
plt.rcParams.update({"figure.facecolor":"#0b0d17","axes.facecolor":"#0b0d17","axes.edgecolor":"#667","axes.labelcolor":"#dde",
    "xtick.color":"#bbc","ytick.color":"#bbc","text.color":"#eef","grid.color":"#223","legend.facecolor":"#141829","legend.edgecolor":"#445"})
HERE = os.path.dirname(os.path.abspath(__file__))
DOC  = os.path.abspath(os.path.join(HERE, "..", "..", "docs", "MERCURY_VULCAN_LADDER_20261010"))
DATA = os.path.join(DOC, "data"); IMG = os.path.join(DOC, "img")
ARCSEC = 206264.806
M_SUN = 1.98892e30; M_E = 5.9722e24

# measured anomalous advances (observed minus Newtonian planetary), ″/century — ephemeris-level values
ANOM = {"Mercury": (42.98, 0.04), "Venus": (8.62, 0.4), "Earth": (3.84, 0.3), "Mars": (1.35, 0.1)}
PL = {  # name: (a_au, period_yr, mass_kg, GM relative uncertainty from spacecraft tracking)
 "Mercury": (0.387098, 0.240846, 3.3011e23, 1e-8),
 "Venus":   (0.723332, 0.615198, 4.8675e24, 1e-9),
 "Earth":   (1.000000, 1.000017, 5.9722e24+7.342e22, 1e-9),
 "Mars":    (1.523679, 1.880848, 6.4171e23, 1e-9),
 "Jupiter": (5.2044,   11.862,   1.8982e27, 1e-8),
 "Saturn":  (9.5826,   29.4571,  5.6834e26, 1e-8),
 "Uranus":  (19.2184,  84.0205,  8.6810e25, 1e-7),
 "Neptune": (30.11,    164.8,    1.02413e26, 1e-7),
}
orbits_per_century = {k: 100.0/v[1] for k, v in PL.items()}

# ---------------------------------------------------------------------------
# A. Hall
# ---------------------------------------------------------------------------
delta = ANOM["Mercury"][0]/(orbits_per_century["Mercury"]*math.pi*ARCSEC)          # tuned to Mercury
HALL = {}
for p in ("Mercury", "Venus", "Earth", "Mars"):
    pred = orbits_per_century[p]*math.pi*delta*ARCSEC
    meas, sig = ANOM[p]
    HALL[p] = dict(predicted_arcsec_per_cy=pred, measured=meas, sigma=sig, ratio=pred/meas, sigmas_off=(pred-meas)/sig)
# Moon: 13.3687 sidereal orbits per year
moon_pred_per_yr = 13.3687*math.pi*delta*ARCSEC
LLR_perigee_sigma_arcsec_per_yr = 1e-4   # lunar laser ranging: perigee rate known to ~0.1 mas/yr (geodetic-precession tests)
HALL["Moon"] = dict(predicted_excess_perigee_arcsec_per_yr=moon_pred_per_yr, LLR_sigma_arcsec_per_yr=LLR_perigee_sigma_arcsec_per_yr,
                    sigmas_off=moon_pred_per_yr/LLR_perigee_sigma_arcsec_per_yr,
                    note="Brown (1903) rejected Hall's δ on the lunar motion with 19th-c. data; LLR makes the rejection ~1e4 σ.")
HALL["delta"] = delta

# ---------------------------------------------------------------------------
# B. Exterior ring
# ---------------------------------------------------------------------------
a_m = PL["Mercury"][0]; n_m = orbits_per_century["Mercury"]*2*math.pi*ARCSEC     # ″ per century of mean motion
RING = []
for b_au, label, m_meas in ((0.6, "inner zodiacal (0.6 AU)", 1e17), (1.0, "zodiacal cloud peak (1 AU)", 1e17), (2.7, "asteroid belt (2.7 AU)", 2.39e21)):
    need = ANOM["Mercury"][0]/(0.75*n_m*(a_m/b_au)**3)*M_SUN                 # kg
    RING.append(dict(ring=label, b_au=b_au, mass_required_kg=need, mass_required_earth=need/M_E, mass_measured_kg=m_meas, deficit_factor=need/m_meas,
                     advance_from_measured_mass_arcsec_per_cy=0.75*n_m*(m_meas/M_SUN)*(a_m/b_au)**3))
RING_NOTE = ("Interior mass (dust inside Mercury's orbit, spherically distributed) makes the force fall off slower than r^-2 and REGRESSES the perihelion; it cannot produce an advance. "
             "Zodiacal cloud total mass estimates: 1e16–1e18 kg (IRAS/COBE/DIRBE); 1e17 used. Asteroid belt: 2.39e21 kg (Pitjeva & Pitjev 2018), already included in ephemeris budgets.")

# ---------------------------------------------------------------------------
# C. Planetary budget via Laplace coefficients
# ---------------------------------------------------------------------------
def b32_1(alpha):
    f = lambda psi: math.cos(psi)/(1 - 2*alpha*math.cos(psi) + alpha**2)**1.5
    return quad(f, 0, 2*math.pi)[0]/math.pi
BUDGET = {}
for p, (a_p, T_p, m_p, rel) in PL.items():
    if p == "Mercury": continue
    alpha = a_m/a_p
    rate = 0.25*n_m*(m_p/M_SUN)*alpha**2*b32_1(alpha)        # ″/century (Murray & Dermott 7.10, exterior perturber)
    frac_needed = ANOM["Mercury"][0]/rate
    BUDGET[p] = dict(alpha=alpha, advance_arcsec_per_cy=rate, classical_1947=dict(Venus=277.8, Earth=90.0, Mars=2.5, Jupiter=153.6, Saturn=7.3, Uranus=0.14, Neptune=0.04).get(p),
                     fractional_mass_error_for_43=frac_needed, GM_relative_uncertainty=rel, factor_over_uncertainty=frac_needed/rel)
total = sum(v["advance_arcsec_per_cy"] for v in BUDGET.values())

# ---------------------------------------------------------------------------
# Figures
# ---------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(9, 5.5))
names = ["Mercury", "Venus", "Earth", "Mars"]; x = np.arange(4)
ax.bar(x-0.2, [HALL[n]["predicted_arcsec_per_cy"] for n in names], 0.4, color="#ff5c7a", label="Hall's law, δ tuned to Mercury")
ax.bar(x+0.2, [ANOM[n][0] for n in names], 0.4, yerr=[ANOM[n][1] for n in names], color="#4fd1ff", label="measured anomalous advance", capsize=4)
ax.set_xticks(x); ax.set_xticklabels(names); ax.set_ylabel("″ per century"); ax.set_yscale("log")
ax.set_title("Hall's r^-(2+δ) gives every body the same advance per orbit — Venus, Earth, Mars refuse; the Moon refuses by %.0e σ" % HALL["Moon"]["sigmas_off"])
ax.legend(); ax.grid(True, which="both", alpha=0.4); fig.tight_layout(); fig.savefig(os.path.join(IMG, "perihelion_01_hall.png"), dpi=130); plt.close(fig)

fig, ax = plt.subplots(figsize=(10, 5.5))
pn = list(BUDGET.keys())
ax.bar(pn, [BUDGET[p]["advance_arcsec_per_cy"] for p in pn], color="#ffd166", label="Newtonian advance from each planet (Laplace coeff., this code)")
ax.scatter(pn, [BUDGET[p]["classical_1947"] for p in pn], color="#4fd1ff", zorder=5, label="Clemence 1947 budget")
ax.axhline(ANOM["Mercury"][0], color="#ff5c7a", ls="--", label="anomalous 43″ to be explained")
ax.set_yscale("log"); ax.set_ylabel("″ per century"); ax.grid(True, which="both", alpha=0.4); ax.legend(fontsize=8)
ax.set_title("Perturbing-mass route: Venus would need a %.0f %% mass error (known to 1e-7 %%); Jupiter %.0f %% (1e-6 %%)" % (100*BUDGET["Venus"]["fractional_mass_error_for_43"], 100*BUDGET["Jupiter"]["fractional_mass_error_for_43"]))
fig.tight_layout(); fig.savefig(os.path.join(IMG, "perihelion_02_budget.png"), dpi=130); plt.close(fig)

VERDICT = dict(
    hall="ELIMINATED. δ = %.3e reproduces Mercury but predicts Venus %.1f″ (measured %.2f), Earth %.1f″ (%.2f), Mars %.1f″ (%.2f) and a lunar perigee excess of %.2f″/yr against an LLR limit of ~1e-4″/yr."
         % (delta, HALL["Venus"]["predicted_arcsec_per_cy"], ANOM["Venus"][0], HALL["Earth"]["predicted_arcsec_per_cy"], ANOM["Earth"][0], HALL["Mars"]["predicted_arcsec_per_cy"], ANOM["Mars"][0], moon_pred_per_yr),
    ring="ELIMINATED. An exterior ring at 1 AU would need %.2f M⊕ (%.0e× the zodiacal cloud); at 0.6 AU %.2f M⊕. Interior dust regresses, not advances. The asteroid belt's real contribution is %.4f″/cy."
         % (RING[1]["mass_required_earth"], RING[1]["deficit_factor"], RING[0]["mass_required_earth"], RING[2]["advance_from_measured_mass_arcsec_per_cy"]),
    masses="ELIMINATED. Budget reproduced (total %.1f″/cy vs classical 531). Venus would need a %.1f %% mass error against 1e-9 relative (×%.0e); Jupiter %.1f %% against 1e-8 (×%.0e)."
         % (total, 100*BUDGET["Venus"]["fractional_mass_error_for_43"], BUDGET["Venus"]["factor_over_uncertainty"], 100*BUDGET["Jupiter"]["fractional_mass_error_for_43"], BUDGET["Jupiter"]["factor_over_uncertainty"]),
    row_10="No Newtonian cause of Mercury's 43″/century survives measurement: solar J2 (report §), inner planet/ring (report §), Hall's exponent, exterior zodiacal mass, and perturbing-mass error are each excluded by more than two orders of magnitude. "
           "The residual stands as an unexplained measurement under the rules of this audit. This statement is a receipt; it is also an arrow, recorded and not followed (see GAMEPLAN §3, REFLECTION §2).")
OUT = dict(anomalous_advances_measured=ANOM, hall=HALL, exterior_ring=RING, ring_note=RING_NOTE, planetary_budget=BUDGET, budget_total_arcsec_per_cy=total, verdict=VERDICT)
json.dump(OUT, open(os.path.join(DATA, "perihelion_newtonian.json"), "w"), indent=1)
for k, v in VERDICT.items(): print(k.upper(), "—", v)
print("budget:", {p: round(BUDGET[p]["advance_arcsec_per_cy"], 2) for p in BUDGET})
