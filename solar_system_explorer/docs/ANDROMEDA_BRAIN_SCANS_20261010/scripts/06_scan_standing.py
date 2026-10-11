#!/usr/bin/env python3
"""Stage 4 — contrast field C = log A − log B, ovaloid level sets, the scan (three slice families).
Stage 4b — standing wave: spherical-harmonic spectrum of C, nodal lines vs the C = 0 interface, icosahedral test.

Scan construction (agent-authored): a solid ball V(x) = C(x/|x|) · w(|x|) with a radial shell w centred at r = 0.8,
sliced at 9 offsets along each of three orthogonal axes and rendered grey-scale. The ball is a rendering device:
the data live on the sphere; the slices make the ovaloid interfaces (C = 0 and C = ±λ) visible as closed curves,
which is the fMRI look the operator described.
"""
import os, json
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
try:
    from scipy.special import sph_harm_y as _shy      # scipy ≥ 1.15: (n, m, theta=polar, phi=azimuth)
    def sph_harm(m, l, phi, theta):
        return _shy(l, m, theta, phi)
except ImportError:
    from scipy.special import sph_harm                 # legacy: (m, n, theta=azimuth, phi=polar)
from scipy.interpolate import RegularGridInterpolator
from common import log, RESULTS
from lib import CORPORA, FIELDS, grid, mollweide, save_json, rotmat, geodesic_deg

SCAN = os.path.join(RESULTS, "scan"); os.makedirs(SCAN, exist_ok=True)
EPS = 1e-4
LMAX = 8
rng = np.random.default_rng(20261010)


def contrast(A, B):
    return np.log(A + EPS) - np.log(B + EPS)


def lam_for(C, area, frac=0.05):
    """λ such that |C| ≥ λ encloses `frac` of the sphere (s = ±1 ovaloids)."""
    order = np.argsort(np.abs(C).ravel())[::-1]
    cum = np.cumsum(area.ravel()[order]) / area.sum()
    k = np.searchsorted(cum, frac)
    return float(np.abs(C).ravel()[order][min(k, len(order) - 1)])


def interp(lat, lon, F):
    # periodic in lon: pad one column each side
    lon_p = np.concatenate([[lon[0] - (lon[1] - lon[0])], lon, [lon[-1] + (lon[1] - lon[0])]])
    F_p = np.concatenate([F[:, -1:], F, F[:, :1]], 1)
    return RegularGridInterpolator((lat, lon_p), F_p, bounds_error=False, fill_value=None)


def ball_slices(lat, lon, C, n=96, clip=None):
    # clip extreme hotspots so a single point does not render as a radial wedge (display only; stats use raw C)
    if clip is not None:
        C = np.clip(C, -clip, clip)
    f = interp(lat, lon, C)
    g = np.linspace(-1, 1, n)
    X, Y, Z = np.meshgrid(g, g, g, indexing="ij")
    r = np.sqrt(X ** 2 + Y ** 2 + Z ** 2) + 1e-9
    la = np.degrees(np.arcsin(np.clip(Z / r, -1, 1))); lo = np.degrees(np.arctan2(Y, X))
    V = f(np.stack([la.ravel(), lo.ravel()], -1)).reshape(X.shape)
    w = np.exp(-((r - 0.8) / 0.18) ** 2) * (r <= 1.0)
    return V * w, g, w


def render_scan(corpus, lat, lon, A, B, C, O, lam):
    # maps
    fig, axs = plt.subplots(2, 2, figsize=(12, 6.4), subplot_kw={"projection": "mollweide"})
    mollweide(axs[0, 0], lat, lon, np.log10(A + EPS), "magma", f"{corpus} — A (direct line), log10")
    mollweide(axs[0, 1], lat, lon, np.log10(B + EPS), "magma", f"{corpus} — B (reflection), log10")
    vm = float(np.percentile(np.abs(C), 98))
    mollweide(axs[1, 0], lat, lon, C, "RdBu_r", f"C = log A − log B   (red: A>B, blue: B>A; white: C=0, grey: ±λ)", -vm, vm,
              contour=[-lam, 0, lam], ccolor=["0.4", "w", "0.4"])
    Cm = np.ma.array(C, mask=O)
    mollweide(axs[1, 1], lat, lon, Cm, "RdBu_r", f"C with occlusion mask O (hatched = seed capricornus / stop-only)", -vm, vm, contour=[0], ccolor="w")
    LON, LAT = np.meshgrid(np.radians(lon), np.radians(lat))
    axs[1, 1].contourf(LON, LAT, O.astype(float), levels=[0.5, 1.5], colors="none", hatches=["////"])
    fig.tight_layout(); fig.savefig(os.path.join(SCAN, f"{corpus}_maps.png"), dpi=130); plt.close(fig)
    # scan
    V, g, w = ball_slices(lat, lon, C, clip=1.5 * lam)
    shell = w > 0.5
    vm = float(np.percentile(np.abs(V[shell]), 97)) if shell.any() else 1.0
    offs = np.linspace(-0.8, 0.8, 9)
    fig, axs = plt.subplots(3, 9, figsize=(18, 6.3))
    for row, (name, take) in enumerate([("axial (z)", lambda k: V[:, :, k]), ("coronal (y)", lambda k: V[:, k, :]), ("sagittal (x)", lambda k: V[k, :, :])]):
        for j, o in enumerate(offs):
            k = int(np.argmin(np.abs(g - o)))
            ax = axs[row, j]
            ax.imshow(take(k).T, cmap="gray", vmin=-vm, vmax=vm, origin="lower")
            ax.contour(take(k).T, levels=[-lam * 0.7, 0, lam * 0.7], colors=["#4aa3ff", "#ffffff", "#ff6a4a"], linewidths=0.5)
            ax.set_xticks([]); ax.set_yticks([])
            if j == 0:
                ax.set_ylabel(name, fontsize=9)
            if row == 0:
                ax.set_title(f"{o:+.1f}", fontsize=8)
    fig.suptitle(f"{corpus} — scan of C (white: C=0 interface; blue: B-dominant ovaloid; red: A-dominant ovaloid)", fontsize=10)
    fig.tight_layout(); fig.savefig(os.path.join(SCAN, f"{corpus}_scan.png"), dpi=110); plt.close(fig)


# ----------------------------------------------------------------------------- 4b
def sh_basis(lat, lon, lmax=LMAX):
    LON, LAT = np.meshgrid(np.radians(lon), np.radians(lat))
    theta = np.pi / 2 - LAT      # colatitude
    phi = LON + np.pi            # 0..2π
    cols, labels = [], []
    for l in range(lmax + 1):
        for m in range(-l, l + 1):
            Y = sph_harm(abs(m), l, phi, theta)
            if m < 0:
                real = np.sqrt(2) * Y.imag
            elif m == 0:
                real = Y.real
            else:
                real = np.sqrt(2) * Y.real
            cols.append(real.ravel()); labels.append((l, m))
    return np.stack(cols, 1), labels


def sh_fit(C, basis, labels, area):
    w = np.sqrt(area.ravel())
    coef, *_ = np.linalg.lstsq(basis * w[:, None], C.ravel() * w, rcond=None)
    P = {}
    for (l, m), c in zip(labels, coef):
        P[l] = P.get(l, 0.0) + float(c ** 2)
    return coef, P


def nodal_distance(C, recon, lat, lon):
    """Mean geodesic distance (deg) from C=0 cells to nearest recon=0 cell (sign-change cells)."""
    def zero_cells(F):
        s = np.sign(F)
        z = np.zeros_like(F, bool)
        z[:, :-1] |= s[:, :-1] != s[:, 1:]
        z[:-1, :] |= s[:-1, :] != s[1:, :]
        return z
    LON, LAT = np.meshgrid(np.radians(lon), np.radians(lat))
    xyz = np.stack([np.cos(LAT) * np.cos(LON), np.cos(LAT) * np.sin(LON), np.sin(LAT)], -1)
    zc = xyz[zero_cells(C)]; zr = xyz[zero_cells(recon)]
    if len(zc) == 0 or len(zr) == 0:
        return float("nan")
    if len(zc) > 3000:
        zc = zc[rng.choice(len(zc), 3000, replace=False)]
    d = np.degrees(np.arccos(np.clip(zc @ zr.T, -1, 1))).min(1)
    return float(d.mean())


def main():
    lat = np.load(os.path.join(FIELDS, "grid_lat.npy")); lon = np.load(os.path.join(FIELDS, "grid_lon.npy"))
    area = np.load(os.path.join(FIELDS, "grid_area.npy"))
    lat_d, lon_d = np.degrees(lat), np.degrees(lon)
    basis, labels = sh_basis(lat_d, lon_d)
    out = {}
    for corpus in CORPORA:
        p = os.path.join(FIELDS, f"{corpus}.npz")
        if not os.path.exists(p):
            log(f"{corpus}: no fields yet, skipped"); continue
        z = np.load(p)
        A, B, O, P, wB = z["A"].astype(float), z["B"].astype(float), z["O"], z["P"].astype(float), z["wB"].astype(float)
        C = contrast(A, B)
        lam = lam_for(C, area)
        render_scan(corpus, lat_d, lon_d, A, B, C, O, lam)
        # ovaloid areas
        s_levels = {}
        for s in (0.25, 0.5, 0.75, 1.0):
            s_levels[str(s)] = {"A_dom_frac": round(float((area * (C >= lam * s)).sum() / area.sum()), 4),
                                "B_dom_frac": round(float((area * (C <= -lam * s)).sum() / area.sum()), 4)}
        # 4b spectrum
        coef, Pl = sh_fit(C, basis, labels, area)
        tot = sum(Pl.values()); frac = {l: Pl[l] / tot for l in Pl}
        dom = max((l for l in Pl if l > 0), key=lambda l: Pl[l])
        mask_dom = np.array([l == dom for (l, m) in labels])
        recon = (basis[:, mask_dom] @ coef[mask_dom]).reshape(C.shape)
        nd = nodal_distance(C, recon, lat_d, lon_d)
        # null: random rotations of the reconstruction (nodal geometry preserved, orientation randomised)
        nulls = []
        from lib import grid as _grid
        _, _, gxyz, _ = _grid()
        from scipy.interpolate import RegularGridInterpolator as RGI
        f = interp(lat_d, lon_d, recon)
        for _ in range(30):
            R = rotmat(rng.uniform(-np.pi, np.pi), rng.uniform(0, np.pi), rng.uniform(-np.pi, np.pi))
            q = gxyz.reshape(-1, 3) @ R.T
            la = np.degrees(np.arcsin(np.clip(q[:, 2], -1, 1))); lo = np.degrees(np.arctan2(q[:, 1], q[:, 0]))
            rr = f(np.stack([la, lo], -1)).reshape(C.shape)
            nulls.append(nodal_distance(C, rr, lat_d, lon_d))
        nulls = np.array(nulls)
        # icosahedral test: null spectrum from B-weights permuted among concepts (A fixed)
        from lib import vmf_density, normalise, KAPPA_A
        _, _, gxyz_f, _ = _grid()
        f6, f10 = [], []
        for _ in range(12):
            wp = rng.permutation(wB)
            Bp = normalise(vmf_density(P, wp, gxyz_f, KAPPA_A), area)
            Cp = contrast(A, Bp)
            _, Pp = sh_fit(Cp, basis, labels, area)
            tp = sum(Pp.values()); f6.append(Pp[6] / tp); f10.append(Pp.get(10, 0) / tp if 10 in Pp else 0)
        f6 = np.array(f6)
        # damping fit: log P_l vs l for l>=1
        ls = np.array([l for l in range(1, LMAX + 1)]); lp = np.log(np.array([Pl[l] for l in ls]) + 1e-18)
        slope = float(np.polyfit(ls, lp, 1)[0]); rho_fit = float(np.exp(slope))
        out[corpus] = {
            "lambda": round(lam, 4), "C_abs_p98": round(float(np.percentile(np.abs(C), 98)), 4),
            "C_mean": round(float((C * area).sum() / area.sum()), 4),
            "A_dominant_frac": round(float((area * (C > 0)).sum() / area.sum()), 4),
            "ovaloids": s_levels,
            "spectrum_P_l": {str(l): round(Pl[l], 6) for l in sorted(Pl)},
            "spectrum_frac": {str(l): round(frac[l], 4) for l in sorted(frac)},
            "dominant_l_nonzero": dom,
            "nodal_distance_deg": round(nd, 2), "nodal_null_mean_deg": round(float(nulls.mean()), 2),
            "nodal_null_p5_deg": round(float(np.percentile(nulls, 5)), 2),
            "nodal_closer_than_null": bool(nd < np.percentile(nulls, 5)),
            "P6_frac": round(frac[6], 4), "P6_frac_null_mean": round(float(f6.mean()), 4), "P6_frac_null_sd": round(float(f6.std()), 4),
            "P6_z": round(float((frac[6] - f6.mean()) / max(f6.std(), 1e-9)), 2),
            "rho_fit_per_l": round(rho_fit, 3), "rho_reference": 0.88,
        }
        log(f"{corpus:13s} λ={lam:.3f} A>B {out[corpus]['A_dominant_frac']:.3f} dom ℓ={dom} nodal {nd:.1f}° vs null {nulls.mean():.1f}° (p5 {np.percentile(nulls,5):.1f}) P6 {frac[6]:.3f} z={out[corpus]['P6_z']:+.2f} ρ={rho_fit:.3f}")
        # spectrum figure
        fig, ax = plt.subplots(figsize=(5, 3))
        ax.bar(list(Pl.keys()), [frac[l] for l in Pl], color=["#888" if l != 6 else "#c33" for l in Pl])
        ax.set_xlabel("ℓ"); ax.set_ylabel("fraction of power"); ax.set_title(f"{corpus} — spectrum of C (ℓ=6 red); ρ_fit={rho_fit:.2f}", fontsize=9)
        fig.tight_layout(); fig.savefig(os.path.join(SCAN, f"{corpus}_spectrum.png"), dpi=130); plt.close(fig)
        np.save(os.path.join(FIELDS, f"{corpus}_C.npy"), C.astype(np.float32))
    save_json("stage4_scan_standing.json", out)


if __name__ == "__main__":
    main()
