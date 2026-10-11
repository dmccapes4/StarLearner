#!/usr/bin/env python
"""Mesh-free Honor Well field in n dimensions, in PyTorch.

The grid solver in honor_well.py cannot leave 2–3 dimensions (N^n cells). The
static field of the same equation,  T lap z - kappa z = p,  has an analytic
Green's function in any dimension n (screened Poisson / Yukawa):

    G_n(rho) = (1/T) (2 pi)^(-n/2) lambda^(2-n) (rho/lambda)^(1-n/2) K_{n/2-1}(rho/lambda)

    n=2 -> K_0(rho/lambda) / (2 pi T)          (what the grid reproduced to 1.9%)
    n=3 -> exp(-rho/lambda) / (4 pi T rho)

so z(x) = - sum_b w_b G_n(|x - p_b|)  for point balls, and a ball with footprint
radius r is approximated by softening:  rho -> sqrt(rho^2 + r^2)  (finite depth
at the centre, same far field).  Gradients come from autograd, which is the
reason to use torch: molecules descend grad z in 8 or 32 dimensions without a
grid, on the GPU, and later the parameters (lambda, kappa, eta, chi) can be fit
to data by the same autograd.

Even n only (K of integer order via the K0/K1 upward recurrence); odd n is a
small extension (half-integer K has a closed form).

    python kernel_field.py      # self-test: recurrence vs scipy, n=2 vs grid, timing in 8-D and 32-D
"""
import math, time
import torch

def bessel_k_int(order: int, x: torch.Tensor) -> torch.Tensor:
    """K_order(x) for integer order >= 0 via upward recurrence from torch's K0, K1."""
    k0 = torch.special.modified_bessel_k0(x)
    if order == 0:
        return k0
    k1 = torch.special.modified_bessel_k1(x)
    if order == 1:
        return k1
    km, k = k0, k1
    for nu in range(1, order):
        km, k = k, km + (2 * nu / x) * k
    return k

def green_n(rho: torch.Tensor, n: int, T: float, lam: float) -> torch.Tensor:
    assert n % 2 == 0, "even n in this version"
    order = n // 2 - 1
    x = rho / lam
    return (1.0 / T) * (2 * math.pi) ** (-n / 2) * lam ** (2 - n) * x ** (1 - n / 2) * bessel_k_int(order, x)

class KernelField:
    """z(x) = - sum_b w_b G_n(sqrt(|x-p_b|^2 + r_b^2))."""
    def __init__(self, n: int, T=3.0, kappa=1.0, device=None):
        self.n, self.T, self.kappa = n, T, kappa
        self.lam = math.sqrt(T / kappa)
        self.device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        self.P = torch.zeros(0, n, device=self.device); self.W = torch.zeros(0, device=self.device); self.R = torch.zeros(0, device=self.device)

    def set_balls(self, P, W, R):
        t = lambda a: torch.as_tensor(a, dtype=torch.float64, device=self.device)
        self.P, self.W, self.R = t(P).reshape(-1, self.n), t(W).reshape(-1), t(R).reshape(-1)

    def z(self, X: torch.Tensor) -> torch.Tensor:
        d2 = ((X[:, None, :] - self.P[None, :, :]) ** 2).sum(-1)              # (M, B)
        rho = torch.sqrt(d2 + self.R[None, :] ** 2 + 1e-9)
        return -(self.W[None, :] * green_n(rho, self.n, self.T, self.lam)).sum(-1)

    def z_and_grad(self, X: torch.Tensor):
        X = X.detach().requires_grad_(True)
        z = self.z(X)
        g, = torch.autograd.grad(z.sum(), X)
        return z.detach(), g

    def descend(self, X, steps=100, alpha=10.0, dt=0.02):
        for _ in range(steps):
            _, g = self.z_and_grad(X)
            X = X - alpha * g * dt
        return X


if __name__ == "__main__":
    import numpy as np
    from scipy.special import kv
    dev = "cuda" if torch.cuda.is_available() else "cpu"
    print("device:", dev, torch.cuda.get_device_name(0) if dev == "cuda" else "")
    # 1. recurrence vs scipy
    x = torch.linspace(0.2, 12, 200, dtype=torch.float64)
    for order in (0, 1, 3, 7, 15):
        ours = bessel_k_int(order, x).numpy(); ref = kv(order, x.numpy())
        rel = np.abs(ours - ref) / np.abs(ref)
        print(f"K_{order}: max rel err {rel.max():.2e} (float64, x in [0.2,12])")
    # 2. n=2 kernel vs the grid solution from honor_well (point-ish load)
    try:
        import os, sys
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from honor_well import Field, Medium
        f = Field(N=256, L=48.0, medium=Medium(T=3.0, kappa=1.0, gamma=2.0))
        f.relax(f.footprint(1.0, 0.25, 0, 0), dt=0.02, steps=4000, tol=1e-7)
        rho, prof = f.radial_profile(nb=200, rmax=20)
        kf = KernelField(2, T=3.0, kappa=1.0, device="cpu"); kf.set_balls([[0.0, 0.0]], [1.0], [0.25])
        X = torch.tensor(np.stack([rho, np.zeros_like(rho)], 1), dtype=torch.float64)
        zk = kf.z(X).numpy()
        m = (rho > 2 * kf.lam) & (rho < 6 * kf.lam)
        print(f"n=2 kernel vs grid, 2λ–6λ: max rel err {np.nanmax(np.abs((zk[m]-prof[m])/prof[m])):.3f}")
    except Exception as e:
        print("grid comparison skipped:", e)
    # 3. timing: 8-D and 32-D, 10k molecules, 8 balls, 100 descent steps
    # Scale lesson: the kernel's range is lambda in every n, but a random cloud's
    # typical distance grows like sqrt(n).  Positions are therefore rescaled so the
    # median molecule–nearest-ball distance is ~2 lambda; without this the wells are
    # spikes nobody feels (mean z ~ 0).  Same math, different ruler per dimension.
    for n in (8, 32):
        kf = KernelField(n, device=dev)
        g = torch.Generator(device="cpu").manual_seed(0)
        P = torch.randn(8, n, generator=g, dtype=torch.float64); X = torch.randn(10000, n, generator=g, dtype=torch.float64)
        dmed = torch.cdist(X, P).min(1).values.median()
        s = (2 * kf.lam) / dmed
        kf.set_balls(P * s, torch.rand(8, generator=g) * 6 + 2, torch.full((8,), 0.3))
        X = (X * s).to(dev)
        if dev == "cuda": torch.cuda.synchronize()
        t0 = time.time(); z0 = kf.z(X); X2 = kf.descend(X, steps=100); z1 = kf.z(X2)
        if dev == "cuda": torch.cuda.synchronize()
        cen = kf.z(kf.P)[0].item()
        print(f"n={n}: scale {s:.3f} (median dist→2λ); centre depth ball0 {cen:.3f}; "
              f"mean z {z0.mean().item():.4f} → {z1.mean().item():.4f}; captured(z<-0.25) {(z0<-0.25).float().mean():.2f} → {(z1<-0.25).float().mean():.2f}; "
              f"10k×8×100 steps {time.time()-t0:.2f}s")
