#!/usr/bin/env python3
"""Stage 7 — test–retest (six_a vs six_b) and cross-corpus C-field correlation matrix."""
import os, json
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from common import log, RESULTS
from lib import CORPORA, FIELDS, save_json

SCAN = os.path.join(RESULTS, "scan")


def wcorr(a, b, w):
    a = a - (a * w).sum() / w.sum(); b = b - (b * w).sum() / w.sum()
    return float((a * b * w).sum() / np.sqrt((a * a * w).sum() * (b * b * w).sum()))


def dice(x, y, w):
    return float(2 * (w * (x & y)).sum() / max((w * x).sum() + (w * y).sum(), 1e-12))


def main():
    area = np.load(os.path.join(FIELDS, "grid_area.npy"))
    s4 = json.load(open(os.path.join("results", "stage4_scan_standing.json")))
    s5 = json.load(open(os.path.join("results", "stage5_bearing.json")))
    Cs = {c: np.load(os.path.join(FIELDS, f"{c}_C.npy")).astype(float) for c in CORPORA if os.path.exists(os.path.join(FIELDS, f"{c}_C.npy"))}
    Fs = {c: np.load(os.path.join(FIELDS, f"{c}.npz")) for c in Cs}
    a, b = Cs["six_a"], Cs["six_b"]; la, lb = s4["six_a"]["lambda"], s4["six_b"]["lambda"]
    rt = {
        "corr_C": round(wcorr(a, b, area), 4),
        "corr_A": round(wcorr(np.log(Fs["six_a"]["A"] + 1e-4), np.log(Fs["six_b"]["A"] + 1e-4), area), 4),
        "corr_B": round(wcorr(np.log(Fs["six_a"]["B"] + 1e-4), np.log(Fs["six_b"]["B"] + 1e-4), area), 4),
        "dice_A_dominant": round(dice(a > 0, b > 0, area), 4),
        "dice_ovaloid_A_s1": round(dice(a >= la, b >= lb, area), 4),
        "dice_ovaloid_B_s1": round(dice(a <= -la, b <= -lb, area), 4),
        "dice_occlusion": round(dice(Fs["six_a"]["O"], Fs["six_b"]["O"], area), 4),
        "refraction_a_deg": s5["six_a"]["refraction_deg"], "refraction_b_deg": s5["six_b"]["refraction_deg"],
        "refraction_abs_diff_deg": round(abs(s5["six_a"]["refraction_deg"] - s5["six_b"]["refraction_deg"]), 2),
        "intervals_overlap": bool(max(s5["six_a"]["interval_deg"][0], s5["six_b"]["interval_deg"][0]) <= min(s5["six_a"]["interval_deg"][1], s5["six_b"]["interval_deg"][1])),
        "dominant_l": [s4["six_a"]["dominant_l_nonzero"], s4["six_b"]["dominant_l_nonzero"]],
        "interpretable": None,
    }
    rt["interpretable"] = bool(rt["corr_C"] >= 0.5)
    log(f"retest corr(C)={rt['corr_C']} corr(A)={rt['corr_A']} corr(B)={rt['corr_B']} dice(A>B)={rt['dice_A_dominant']} refr {rt['refraction_a_deg']} vs {rt['refraction_b_deg']}")
    names = list(Cs)
    M = np.array([[wcorr(Cs[x], Cs[y], area) for y in names] for x in names])
    MA = np.array([[wcorr(np.log(Fs[x]["A"] + 1e-4), np.log(Fs[y]["A"] + 1e-4), area) for y in names] for x in names])
    fig, axs = plt.subplots(1, 2, figsize=(13, 5.6))
    for ax, mat, t in ((axs[0], MA, "corr of log A (where the corpora talk)"), (axs[1], M, "corr of C = log A − log B (where the reflection disagrees)")):
        im = ax.imshow(mat, cmap="RdBu_r", vmin=-1, vmax=1)
        ax.set_xticks(range(len(names))); ax.set_xticklabels(names, rotation=60, ha="right", fontsize=8)
        ax.set_yticks(range(len(names))); ax.set_yticklabels(names, fontsize=8); ax.set_title(t, fontsize=10)
        for i in range(len(names)):
            for j in range(len(names)):
                ax.text(j, i, f"{mat[i,j]:.2f}", ha="center", va="center", fontsize=6, color="k" if abs(mat[i, j]) < 0.6 else "w")
    fig.colorbar(im, ax=axs, shrink=0.8); fig.savefig(os.path.join(SCAN, "cross_corpus_corr.png"), dpi=130, bbox_inches="tight"); plt.close(fig)
    # six_a vs six_b side-by-side
    lat = np.degrees(np.load(os.path.join(FIELDS, "grid_lat.npy"))); lon = np.degrees(np.load(os.path.join(FIELDS, "grid_lon.npy")))
    from lib import mollweide
    vm = float(np.percentile(np.abs(np.concatenate([a.ravel(), b.ravel()])), 98))
    fig, axs = plt.subplots(1, 2, figsize=(12, 3.4), subplot_kw={"projection": "mollweide"})
    mollweide(axs[0], lat, lon, a, "RdBu_r", f"six_a — C (run A)", -vm, vm, contour=[0], ccolor="w")
    mollweide(axs[1], lat, lon, b, "RdBu_r", f"six_b — C (run B, replicate)   corr={rt['corr_C']:.2f}", -vm, vm, contour=[0], ccolor="w")
    fig.tight_layout(); fig.savefig(os.path.join(SCAN, "retest_six_a_six_b.png"), dpi=130); plt.close(fig)
    off = [(names[i], names[j], round(float(M[i, j]), 3)) for i in range(len(names)) for j in range(i + 1, len(names))]
    off.sort(key=lambda t: -t[2])
    save_json("stage7_retest.json", {"six_a_vs_six_b": rt, "corpora": names,
                                      "corr_C_matrix": [[round(float(v), 3) for v in row] for row in M],
                                      "corr_logA_matrix": [[round(float(v), 3) for v in row] for row in MA],
                                      "most_similar_C": off[:8], "least_similar_C": off[-8:]})


if __name__ == "__main__":
    main()
