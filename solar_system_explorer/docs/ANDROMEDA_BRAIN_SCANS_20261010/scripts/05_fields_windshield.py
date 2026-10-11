#!/usr/bin/env python3
"""Stage 3 — fields A (direct line) and B (reflection) on the meaning sphere M.
Stage 3b — the windshield transform:  B ≈ T(A) = g · K_σ∗R(A) · (1 − O),   E = B − T(A).

A: every concept weight 1 (narrator order is the sampling; no time weighting in v0.0.1).
B: every concept weighted by the receipts the sort stamped on it (coupling 1.0, echo 0.5, stop 0.1, base 0.05).
O: cells where occluded concepts (seed capricornus + stop-only) carry > 50% of the local A mass.
Fit: rotation R (ZYZ Euler) and blur κ_B by Nelder–Mead on a 4° grid maximising corr(B, T) off the mask; g closed-form.
"""
import os, json, time
import numpy as np
from scipy.optimize import minimize
from common import log, RESULTS
from lib import (CORPORA, FIELDS, KAPPA_A, grid, vmf_density, normalise, load_concepts, load_sphere, load_sort,
                 receipt_weights, rotmat, save_json)

rng = np.random.default_rng(20261010)


def fields_for(P, wA, wB, occ_mask_pts, gxyz, area, kappa=KAPPA_A):
    A_raw = vmf_density(P, wA, gxyz, kappa)
    B_raw = vmf_density(P, wB, gxyz, kappa)
    O_raw = vmf_density(P[occ_mask_pts], np.ones(occ_mask_pts.sum()), gxyz, kappa) if occ_mask_pts.any() else np.zeros_like(A_raw)
    O = (O_raw / np.maximum(A_raw, 1e-12)) > 0.5
    return normalise(A_raw, area), normalise(B_raw, area), O


def fit_windshield(P, wA, B_c, O_c, gxyz_c, area_c, kappa_a):
    """Return best (euler, kappa_b, g, corr) on the coarse grid."""
    m = ~O_c
    Bm = B_c[m]
    Bm_c = Bm - Bm.mean()

    def T_of(params):
        a, b, c, lk = params
        R = rotmat(a, b, c)
        T = normalise(vmf_density(P @ R.T, wA, gxyz_c, float(np.exp(lk))), area_c)
        return T

    def obj(params):
        T = T_of(params)
        Tm = T[m]; Tm_c = Tm - Tm.mean()
        den = np.sqrt((Tm_c ** 2).sum() * (Bm_c ** 2).sum())
        return 1.0 - (Tm_c * Bm_c).sum() / den if den > 0 else 1.0

    starts = [np.array([0, 0, 0, np.log(kappa_a / 2)])]
    for _ in range(2):
        starts.append(np.array([rng.uniform(-np.pi, np.pi), rng.uniform(0, np.pi), rng.uniform(-np.pi, np.pi), np.log(kappa_a / 2)]))
    best = None
    for s in starts:
        r = minimize(obj, s, method="Nelder-Mead", options={"maxiter": 150, "xatol": 1e-3, "fatol": 1e-5})
        if best is None or r.fun < best.fun:
            best = r
    a, b, c, lk = best.x
    T = T_of(best.x)
    g = float((T[m] * Bm).sum() / max((T[m] ** 2).sum(), 1e-12))
    return (float(a), float(b), float(c)), float(np.exp(lk)), g, float(1 - best.fun)


def main():
    concepts = load_concepts()
    xyz, meta = load_sphere()
    corp = np.array([c["corpus"] for c in concepts])
    lat, lon, gxyz, area = grid()
    latc, lonc, gxyz_c, area_c = grid(45, 90)
    out = {}
    for corpus in CORPORA:
        t0 = time.time()
        idx = np.where(corp == corpus)[0]
        P = xyz[idx].astype(np.float64)
        cap, rec = load_sort(corpus, concepts)
        w, occ, n = receipt_weights(cap, rec)
        cidx = np.array([concepts[i]["cidx"] for i in idx])
        wA = np.ones(len(idx))
        wB = np.array([0.05 + w.get(c, 0.0) for c in cidx])
        occ_pts = np.array([c in occ for c in cidx])
        A, B, O = fields_for(P, wA, wB, occ_pts, gxyz, area)
        A_c, B_c, O_c = fields_for(P, wA, wB, occ_pts, gxyz_c, area_c)
        euler, kappa_b, g, corr = fit_windshield(P, wA, B_c, O_c, gxyz_c, area_c, KAPPA_A)
        R = rotmat(*euler)
        T = normalise(vmf_density(P @ R.T, wA, gxyz, kappa_b), area) * (~O)
        T = g * T
        E = B - T
        l2 = lambda f: float(np.sqrt((f ** 2 * area).sum()))
        rot_deg = float(np.degrees(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1))))
        p = lambda f: np.percentile(f[~O], [5, 95])
        cA, cB = p(A), p(B)
        res = {
            "n_concepts": int(len(idx)), "occluded_concepts": int(occ_pts.sum()),
            "occlusion_fraction_concepts": round(float(occ_pts.mean()), 3),
            "occlusion_fraction_sphere": round(float((O * area).sum() / area.sum()), 3),
            "occluded_A_mass": round(float((A * O * area).sum()), 3),
            "rotation_deg": round(rot_deg, 2), "euler_zyz_deg": [round(float(np.degrees(e)), 2) for e in euler],
            "kappa_A": KAPPA_A, "kappa_B": round(kappa_b, 1),
            "sigma_A_deg": round(float(np.degrees(1 / np.sqrt(KAPPA_A))), 2),
            "sigma_B_deg": round(float(np.degrees(1 / np.sqrt(kappa_b))), 2),
            "big": bool(kappa_b < KAPPA_A),
            "gain_g": round(g, 3),
            "contrast_A_p95_p5": round(float(cA[1] - cA[0]), 4), "contrast_B_p95_p5": round(float(cB[1] - cB[0]), 4),
            "dull_ratio_B_over_A": round(float((cB[1] - cB[0]) / max(cA[1] - cA[0], 1e-12)), 3),
            "corr_B_T_offmask": round(corr, 4),
            "corr_B_A_offmask": round(float(np.corrcoef(A[~O], B[~O])[0, 1]), 4),
            "residual_E_over_B": round(l2(E) / max(l2(B), 1e-12), 4),
            "wB_mean": round(float(wB.mean()), 3), "wB_max": round(float(wB.max()), 3),
            "seconds": round(time.time() - t0, 1),
        }
        out[corpus] = res
        np.savez_compressed(os.path.join(FIELDS, f"{corpus}.npz"), A=A.astype(np.float32), B=B.astype(np.float32),
                            O=O, T=T.astype(np.float32), E=E.astype(np.float32), P=P.astype(np.float32),
                            wB=wB.astype(np.float32), occ=occ_pts, cidx=cidx)
        log(f"{corpus:13s} rot={res['rotation_deg']:6.2f}° κB={res['kappa_B']:7.1f} g={g:.3f} dull={res['dull_ratio_B_over_A']:.3f} "
            f"corr(B,T)={corr:.3f} corr(B,A)={res['corr_B_A_offmask']:.3f} E/B={res['residual_E_over_B']:.3f} occl={res['occlusion_fraction_sphere']:.3f}  {res['seconds']}s")
    np.save(os.path.join(FIELDS, "grid_lat.npy"), lat); np.save(os.path.join(FIELDS, "grid_lon.npy"), lon)
    np.save(os.path.join(FIELDS, "grid_area.npy"), area)
    save_json("stage3_fields_windshield.json", out)


if __name__ == "__main__":
    main()
