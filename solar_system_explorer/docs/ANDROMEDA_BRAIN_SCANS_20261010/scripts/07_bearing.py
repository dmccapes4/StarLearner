#!/usr/bin/env python3
"""Stage 5 — bearing, as an interval.

seed        = the sort's position-0 concept (the corpus's centre; M44's analogue)
bearing_A   = azimuth at the seed toward centroid(A)      (direct line)
bearing_B   = azimuth at the seed toward centroid(B)      (reflection)
refraction  = |bearing_A − bearing_B|
interval    = refraction ± half-width, where half-width² = bootstrap² + blur², blur = sqrt(σ_B² − σ_A²) (deg),
              widened by 1/(1 − occlusion_fraction)
combined    = geodesic midpoint of the two centroids weighted by concentration (1/σ²) → bearing from seed
"""
import os, json
import numpy as np
from common import log
from lib import CORPORA, FIELDS, load_concepts, load_sphere, azimuth_deg, ang_diff, save_json, geodesic_deg

rng = np.random.default_rng(20261010)
PRIORS = {"90_measured": 90.0, "60_suspected": 60.0, "30_d20_hemisphere": 30.0}


def centroid(P, w):
    v = (P * w[:, None]).sum(0)
    n = np.linalg.norm(v)
    return v / n, float(n / w.sum())   # unit vector, resultant length (concentration proxy)


def main():
    concepts = load_concepts()
    inv = json.load(open(os.path.join("results", "stage1_invariants.json")))
    ws = json.load(open(os.path.join("results", "stage3_fields_windshield.json")))
    xyz, _ = load_sphere()
    out = {}
    for corpus in CORPORA:
        p = os.path.join(FIELDS, f"{corpus}.npz")
        if not os.path.exists(p):
            continue
        z = np.load(p)
        P, wB, cidx = z["P"].astype(float), z["wB"].astype(float), z["cidx"]
        wA = np.ones(len(P))
        seed_c = inv[corpus]["seed_cidx"]
        seed = xyz[seed_c].astype(float)
        cA, rA = centroid(P, wA); cB, rB = centroid(P, wB)
        bA, bB = azimuth_deg(seed, cA), azimuth_deg(seed, cB)
        refr = ang_diff(bA, bB)
        # bootstrap
        boots = []
        for _ in range(300):
            i = rng.integers(0, len(P), len(P))
            ca, _ = centroid(P[i], wA[i]); cb, _ = centroid(P[i], wB[i])
            boots.append(ang_diff(azimuth_deg(seed, ca), azimuth_deg(seed, cb)))
        boots = np.array(boots)
        sdA, sdB = ws[corpus]["sigma_A_deg"], ws[corpus]["sigma_B_deg"]
        blur = float(np.sqrt(max(sdB ** 2 - sdA ** 2, 0.0)))
        occ = ws[corpus]["occlusion_fraction_sphere"]
        half = float(np.sqrt(boots.std() ** 2 + blur ** 2) / max(1 - occ, 0.05))
        lo, hi = max(0.0, refr - half), min(180.0, refr + half)
        # combined bearing: concentration-weighted geodesic midpoint of the centroids
        kA, kB = 1 / max(1 - rA, 1e-6), 1 / max(1 - rB, 1e-6)
        mid = (kA * cA + kB * cB); mid /= np.linalg.norm(mid)
        out[corpus] = {
            "seed_concept": inv[corpus]["seed_concept"], "seed_letter": inv[corpus]["seed_letter"],
            "bearing_A_deg": round(bA, 2), "bearing_B_deg": round(bB, 2),
            "refraction_deg": round(refr, 2),
            "bootstrap_sd_deg": round(float(boots.std()), 2), "bootstrap_p5_p95": [round(float(np.percentile(boots, 5)), 2), round(float(np.percentile(boots, 95)), 2)],
            "blur_deg": round(blur, 2), "occlusion_fraction": occ,
            "interval_deg": [round(lo, 2), round(hi, 2)], "interval_width_deg": round(hi - lo, 2),
            "centroid_sep_deg": round(float(geodesic_deg(cA, cB)), 2),
            "seed_to_centroid_A_deg": round(float(geodesic_deg(seed, cA)), 2),
            "seed_to_centroid_B_deg": round(float(geodesic_deg(seed, cB)), 2),
            "resultant_A": round(rA, 4), "resultant_B": round(rB, 4),
            "combined_bearing_deg": round(azimuth_deg(seed, mid), 2),
            "priors_in_interval": {k: bool(lo <= v <= hi) for k, v in PRIORS.items()},
            "direction_recoverable": bool(hi - lo < 90),
        }
        log(f"{corpus:13s} A→{bA:6.1f}° B→{bB:6.1f}° refr={refr:6.1f}° ±{half:5.1f} [{lo:.0f},{hi:.0f}] sep={out[corpus]['centroid_sep_deg']:.1f}° priors={[k for k,v in out[corpus]['priors_in_interval'].items() if v]}")
    save_json("stage5_bearing.json", out)


if __name__ == "__main__":
    main()
