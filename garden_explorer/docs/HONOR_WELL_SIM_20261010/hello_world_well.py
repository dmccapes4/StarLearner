#!/usr/bin/env python
"""Honor Well — hello world.

Phase 0 of GAMEPLAN_HONOR_WELL_SIM_20261010.md.

A square field ("the fluid mattress") with "hello world?" engraved on its
surface. One ball (the honor code) is placed at the centre. We solve the
static deflection of a tensioned membrane on a fluid foundation under the
ball's footprint load, compare a lawn bowl (small radius) against a bowling
ball (large radius) at the SAME weight, then run a short dynamic episode with
three kinds of molecules (surface conformists, planners, deep swimmers) and
foam, with the allostatic reward bookkeeping from the report.

Pure numpy + matplotlib + pillow. No external physics engine.

    python hello_world_well.py            # writes figures/ and session.jsonl
"""
import os, json, math, time
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FIG = os.path.join(HERE, "figures"); os.makedirs(FIG, exist_ok=True)
SESSION = os.path.join(HERE, "session.jsonl")
rng = np.random.default_rng(7)

# ----------------------------------------------------------------- field
N = 256                 # grid points per side
L = 24.0                # field side length (arbitrary social units)
dx = L / N
xs = (np.arange(N) - N / 2) * dx
X, Y = np.meshgrid(xs, xs, indexing="xy")
RHO = np.hypot(X, Y)

T_TENSION = 3.0         # membrane tension: coupling between neighbours (cohesion)
KAPPA = 1.0             # foundation stiffness: pull back to own level (restoring)
LAMBDA = math.sqrt(T_TENSION / KAPPA)   # decay length of the medium, set by the MEDIUM not the ball

kx = np.fft.fftfreq(N, d=dx) * 2 * np.pi
KX, KY = np.meshgrid(kx, kx, indexing="xy")
K2 = KX ** 2 + KY ** 2

def log(event, **kw):
    rec = {"t": time.time(), "event": event, **kw}
    with open(SESSION, "a") as f:
        f.write(json.dumps(rec) + "\n")

def footprint(w, r, cx=0.0, cy=0.0):
    """Pressure field of a ball of weight w resting on a disc of radius r."""
    disc = (np.hypot(X - cx, Y - cy) <= r).astype(float)
    area = disc.sum() * dx * dx
    return w * disc / max(area, 1e-9)

def static_deflection(p):
    """Solve  T lap(z) - kappa z = p   (z negative = depressed)."""
    p_hat = np.fft.fft2(p)
    z_hat = -p_hat / (T_TENSION * K2 + KAPPA)
    return np.real(np.fft.ifft2(z_hat))

def radial_profile(z, nb=120):
    edges = np.linspace(0, L / 2, nb + 1)
    idx = np.digitize(RHO.ravel(), edges) - 1
    prof = np.array([z.ravel()[idx == i].mean() if np.any(idx == i) else np.nan for i in range(nb)])
    mids = 0.5 * (edges[1:] + edges[:-1])
    return mids, prof

def logistic_fit(rho, depth):
    """Fit depth(rho) = D / (1 + exp(k (rho - R))) by coarse grid search (no scipy needed)."""
    D = depth[0]
    best = (np.inf, None)
    for k in np.linspace(0.3, 8, 60):
        for R in np.linspace(0.05, 6, 80):
            model = D / (1 + np.exp(k * (rho - R)))
            err = np.nanmean((model - depth) ** 2)
            if err < best[0]:
                best = (err, (D, k, R))
    return best[1]

def engrave_text(text="hello world?", depth=0.12):
    """Rasterise text into a shallow engraving on the surface."""
    img = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 34)
    except Exception:
        font = ImageFont.load_default()
    bbox = d.textbbox((0, 0), text, font=font)
    d.text(((N - (bbox[2] - bbox[0])) / 2, (N - (bbox[3] - bbox[1])) / 2 - 10), text, fill=255, font=font)
    return np.flipud(-depth * (np.asarray(img, dtype=float) / 255.0))   # flipud: imshow(origin="lower")

# ----------------------------------------------------------------- phase 0a: lawn bowl vs bowling ball
open(SESSION, "w").close()
log("start", N=N, L=L, T=T_TENSION, kappa=KAPPA, lambda_medium=LAMBDA)

W = 6.0
cases = [("lawn bowl", 0.35), ("croquet", 0.8), ("bowling ball", 2.0)]
engraving = engrave_text()
fig, axes = plt.subplots(1, 3, figsize=(13, 4.3))
profiles = {}
for ax, (name, r) in zip(axes, cases):
    z = static_deflection(footprint(W, r)) + engraving
    rho, prof = radial_profile(z)
    D, k, R = logistic_fit(rho, prof)
    profiles[name] = (r, rho, prof, D, k, R)
    im = ax.imshow(z, extent=[-L/2, L/2, -L/2, L/2], origin="lower", cmap="viridis", vmin=-1.2, vmax=0.02)
    ax.add_patch(plt.Circle((0, 0), r, fill=False, ec="white", lw=1.2, ls="--"))
    ax.set_title(f"{name}: w={W}, r={r}\npeak depth {-z.min():.2f}, logistic k={k:.2f}, R={R:.2f}", fontsize=9)
    ax.set_xticks([]); ax.set_yticks([])
    log("static_case", name=name, w=W, r=r, peak_depth=float(-z.min()), k=float(k), R=float(R), w_over_r=W / r)
fig.colorbar(im, ax=axes, shrink=0.8, label="surface height z (negative = depressed)")
fig.suptitle('Phase 0a — same weight, three radii, on a field with "hello world?" engraved', fontsize=11)
fig.savefig(os.path.join(FIG, "p0a_three_balls.png"), dpi=150, bbox_inches="tight"); plt.close(fig)

# radial profiles + threshold radius (conformity requires depth)
DELTA = 0.25   # capture depth: a molecule inside |z| > DELTA is "in the well"
fig, ax = plt.subplots(figsize=(8, 4.4))
for name, (r, rho, prof, D, k, R) in profiles.items():
    ax.plot(rho, -prof, label=f"{name} (r={r}): k={k:.2f}, R={R:.2f}, w/r={W/r:.1f}")
    inside = rho[-prof > DELTA]
    rc = inside.max() if inside.size else 0.0
    ax.axvline(rc, color=ax.lines[-1].get_color(), ls=":", lw=1)
    log("capture_radius", name=name, delta=DELTA, capture_radius=float(rc), capture_area=float(math.pi * rc * rc))
ax.axhline(DELTA, color="k", lw=0.8, ls="--"); ax.text(L / 2 - 0.2, DELTA + 0.02, "capture depth δ", ha="right", fontsize=8)
ax.set_xlabel("distance from ball centre ρ"); ax.set_ylabel("depth (−z)"); ax.set_xlim(0, 8)
ax.set_title("Radial depth profiles. Far field is identical (set by the medium's λ); the captured region (depth > δ) shrinks with radius.", fontsize=9)
ax.legend(fontsize=8); ax.grid(alpha=.3)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p0a_profiles.png"), dpi=150); plt.close(fig)

# k and capture radius as a function of w/r, holding w fixed and sweeping r, and holding r fixed sweeping w
rows = []
for r in np.linspace(0.3, 3.0, 12):
    z = static_deflection(footprint(W, r)); rho, prof = radial_profile(z); D, k, R = logistic_fit(rho, prof)
    inside = rho[-prof > DELTA]; rows.append(("sweep r", W, r, W / r, -z.min(), k, R, inside.max() if inside.size else 0))
for w in np.linspace(1.5, 12, 12):
    z = static_deflection(footprint(w, 0.8)); rho, prof = radial_profile(z); D, k, R = logistic_fit(rho, prof)
    inside = rho[-prof > DELTA]; rows.append(("sweep w", w, 0.8, w / 0.8, -z.min(), k, R, inside.max() if inside.size else 0))
fig, axes = plt.subplots(1, 3, figsize=(13, 3.9))
for kind, mk in (("sweep r", "o"), ("sweep w", "s")):
    sub = [x for x in rows if x[0] == kind]
    wr = [x[3] for x in sub]
    axes[0].plot(wr, [x[4] for x in sub], mk + "-", label=kind)
    axes[1].plot(wr, [x[5] for x in sub], mk + "-", label=kind)
    axes[2].plot(wr, [x[7] for x in sub], mk + "-", label=kind)
for ax, t in zip(axes, ("peak depth", "logistic steepness k", f"capture radius (δ={DELTA})")):
    ax.set_xlabel("w / r"); ax.set_title(t, fontsize=10); ax.grid(alpha=.3); ax.legend(fontsize=8)
fig.suptitle("The user's k → w/r, tested. Depth and capture radius rise with w/r along both sweeps; steepness k is governed by the medium's λ and the footprint, so it is flat-ish in w and falls as r grows.", fontsize=9)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p0a_k_vs_w_over_r.png"), dpi=150); plt.close(fig)
with open(os.path.join(HERE, "p0a_sweep.csv"), "w") as f:
    f.write("kind,w,r,w_over_r,peak_depth,k,R,capture_radius\n")
    for x in rows:
        f.write(",".join(f"{v:.4f}" if isinstance(v, float) else str(v) for v in x) + "\n")

# capture radius as a function of the capture depth delta, for the three balls
fig, ax = plt.subplots(figsize=(7.5, 4))
deltas = np.linspace(0.05, 1.2, 60)
for name, (r, rho, prof, D, k, R) in profiles.items():
    rc = [ (rho[-prof > d].max() if np.any(-prof > d) else 0.0) for d in deltas ]
    ax.plot(deltas, rc, label=f"{name} (r={r})")
ax.set_xlabel("capture depth δ (how much conformity the code demands)"); ax.set_ylabel("capture radius")
ax.set_title("Which ball holds more people depends on how deep 'in' has to be.\nShallow demand: the broad ball holds more. Deep demand: only the narrow ball holds anyone.", fontsize=9)
ax.legend(fontsize=8); ax.grid(alpha=.3)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p0a_capture_vs_delta.png"), dpi=150); plt.close(fig)
for name, (r, rho, prof, D, k, R) in profiles.items():
    for d in (0.1, 0.25, 0.5, 0.8):
        rc = rho[-prof > d].max() if np.any(-prof > d) else 0.0
        log("capture_vs_delta", name=name, delta=d, capture_radius=float(rc))

# ----------------------------------------------------------------- phase 0b: dynamics with molecules and foam
# Field dynamics: damped wave on the foundation,  z_tt = c^2 lap z - kappa z - gamma z_t - p(t)
C2, GAMMA, DT = T_TENSION, 1.2, 0.02   # C2 = T so the static solution is the wave equation's rest state
STEPS = 900
z = static_deflection(footprint(W, 0.8)) + engraving
zprev = z.copy()

def laplacian(a):
    return (np.roll(a, 1, 0) + np.roll(a, -1, 0) + np.roll(a, 1, 1) + np.roll(a, -1, 1) - 4 * a) / (dx * dx)

P_ENGRAVE = C2 * laplacian(engraving) - KAPPA * engraving   # the load that holds the lettering still

def sample(field, px, py):
    i = np.clip(((py + L / 2) / dx).astype(int), 0, N - 1); j = np.clip(((px + L / 2) / dx).astype(int), 0, N - 1)
    return field[i, j]

# ball trajectory: sits, then drifts, then shrinks radius (influencer change), then jumps
def ball_state(step):
    t = step * DT
    if t < 4:   return 0.0, 0.0, 0.8, W
    if t < 10:  return 0.6 * (t - 4), 0.3 * (t - 4), 0.8, W           # drifting honor code
    if t < 14:  return 3.6, 1.8, 0.8 - 0.1 * (t - 10), W              # radius shrinks: deeper, narrower, fewer chairs
    return -4.0, -3.0, 1.6, W                                          # new ball, elsewhere, broad (jump = splash)

# molecules
M = 240
kinds = rng.choice(["surface", "planner", "deep", "foam"], size=M, p=[0.45, 0.2, 0.15, 0.2])
pos = rng.uniform(-L / 2 + 1, L / 2 - 1, size=(M, 2))
nbeliefs = np.where(kinds == "deep", rng.integers(0, 2, M), rng.integers(2, 7, M))   # deep swimmers carry few anchors
speed = {"surface": 1.0, "planner": 1.1, "deep": 1.0, "foam": 0.35}
drag = 1.0 / (1.0 + 0.35 * nbeliefs)        # beliefs are anchors: more of them, slower through the fluid
baseline = np.zeros(M)                      # allostatic set-point of each molecule
reward_hist = np.zeros((STEPS, M)); depth_hist = np.zeros((STEPS, M)); outcast_hist = np.zeros(STEPS); foam_under = np.zeros(STEPS)
ETA = 0.02                                  # tolerance rate (set-point chases depth)
sunk = np.zeros(M, dtype=bool)
snap_at = {int(3.5 / DT): "settled", int(8 / DT): "drifting", int(13.5 / DT): "shrunk", int(STEPS - 1): "after the splash"}
snaps = []
prev_ball = ball_state(0)
for s in range(STEPS):
    cx, cy, r, w = ball_state(s)
    p = footprint(w, r, cx, cy) + P_ENGRAVE
    # splash: a sudden ball jump injects a velocity impulse under the old and new footprints
    if (abs(cx - prev_ball[0]) + abs(cy - prev_ball[1])) > 1.0:
        zprev = z + 1.2 * (np.hypot(X - prev_ball[0], Y - prev_ball[1]) <= prev_ball[2] * 2.5) * dx  # old site rebounds: the splash
        log("splash", step=s, from_=(prev_ball[0], prev_ball[1]), to=(cx, cy))
    prev_ball = (cx, cy, r, w)
    acc = C2 * laplacian(z) - KAPPA * z - GAMMA * (z - zprev) / DT - p
    znew = 2 * z - zprev + acc * DT * DT
    zprev, z = z, znew
    # gradients
    gy, gx = np.gradient(z, dx)
    gxm, gym = sample(gx, pos[:, 0], pos[:, 1]), sample(gy, pos[:, 0], pos[:, 1])
    vel = np.zeros_like(pos)
    for kname in ("surface", "deep"):
        m = kinds == kname
        vel[m] = -np.stack([gxm[m], gym[m]], 1) * 10.0
    m = kinds == "planner"                                   # move toward where the ball is heading
    nx, ny, _, _ = ball_state(min(s + 60, STEPS - 1))
    d = np.stack([nx - pos[m, 0], ny - pos[m, 1]], 1); d /= (np.linalg.norm(d, axis=1, keepdims=True) + 1e-9)
    vel[m] = d * 1.4 - np.stack([gxm[m], gym[m]], 1) * 3.0
    m = kinds == "foam"                                      # foam rides the surface flow outward, away from the slope
    vel[m] = np.stack([gxm[m], gym[m]], 1) * 1.5 + 0.08 * pos[m] / (np.linalg.norm(pos[m], axis=1, keepdims=True) + 1e-9)
    # crowd propulsion: soft repulsion between neighbours (pushes molecules out of a crowded well floor)
    diff = pos[:, None, :] - pos[None, :, :]; dist = np.linalg.norm(diff, axis=2) + np.eye(M)
    push = (diff / dist[..., None] * np.clip(0.5 - dist, 0, None)[..., None]).sum(1)
    vel += push * 4.0
    vel *= (np.array([speed[k] for k in kinds]) * drag)[:, None]
    pos += vel * DT
    pos = np.clip(pos, -L / 2 + 0.5, L / 2 - 0.5)
    # bookkeeping: depth, allostatic reward, outcasts, foam sucked under by local wave speed
    depth = -sample(z, pos[:, 0], pos[:, 1])
    reward = depth - baseline; baseline += ETA * (depth - baseline)
    zt = np.abs(sample(z - zprev, pos[:, 0], pos[:, 1]) / DT)
    newly = (kinds == "foam") & (zt > 0.35) & (~sunk)
    if newly.any():
        sunk |= newly; kinds[newly] = "surface"; log("foam_sucked_under", step=s, n=int(newly.sum()))
    reward_hist[s] = reward; depth_hist[s] = depth
    outcast_hist[s] = int(((depth < DELTA) & (kinds != "foam")).sum()); foam_under[s] = int(sunk.sum())
    if s in snap_at:
        snaps.append((snap_at[s], z.copy(), pos.copy(), kinds.copy(), (cx, cy, r)))

log("dynamics_done", steps=STEPS, molecules=M, foam_sunk=int(sunk.sum()), outcasts_final=int(outcast_hist[-1]))

colors = {"surface": "#ffffff", "planner": "#ffd166", "deep": "#06d6a0", "foam": "#ef476f"}
fig, axes = plt.subplots(1, 4, figsize=(17, 4.4))
for ax, (title, zz, pp, kk, (cx, cy, r)) in zip(axes, snaps):
    ax.imshow(zz, extent=[-L/2, L/2, -L/2, L/2], origin="lower", cmap="viridis", vmin=-1.4, vmax=0.1)
    for kname, c in colors.items():
        m = kk == kname; ax.scatter(pp[m, 0], pp[m, 1], s=9, c=c, edgecolors="k", linewidths=0.3, label=kname)
    ax.add_patch(plt.Circle((cx, cy), r, fill=False, ec="white", lw=1.2, ls="--"))
    ax.set_title(title, fontsize=10); ax.set_xticks([]); ax.set_yticks([])
axes[0].legend(fontsize=7, loc="lower left", markerscale=1.5)
fig.suptitle("Phase 0b — the ball settles, drifts, shrinks (fewer chairs), then jumps (splash). White: surface conformists · yellow: planners · green: deep swimmers · red: foam", fontsize=10)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p0b_snapshots.png"), dpi=150); plt.close(fig)

fig, axes = plt.subplots(1, 3, figsize=(14, 3.8))
t = np.arange(STEPS) * DT
for kname, c in (("surface", "#555"), ("planner", "#c9a000"), ("deep", "#06a080"), ("foam", "#d03050")):
    m = kinds == kname
    if m.any():
        axes[0].plot(t, depth_hist[:, m].mean(1), color=c, label=kname)
        axes[1].plot(t, reward_hist[:, m].mean(1), color=c, label=kname)
axes[0].set_title("mean depth by kind (conformity)", fontsize=10); axes[1].set_title("mean allostatic reward = depth − set-point", fontsize=10)
axes[1].axhline(0, color="k", lw=.7)
axes[2].plot(t, outcast_hist, color="#333", label="outcasts (depth < δ, non-foam)"); axes[2].plot(t, foam_under, color="#d03050", label="foam sucked under (cumulative)")
axes[2].set_title("outcasts and dissolved foam", fontsize=10)
for ax in axes:
    for tt, lab in ((4, "drift"), (10, "shrink"), (14, "jump")):
        ax.axvline(tt, color="#999", lw=.8, ls="--"); ax.text(tt + .1, ax.get_ylim()[1] * .9, lab, fontsize=7, color="#666")
    ax.set_xlabel("t"); ax.legend(fontsize=7); ax.grid(alpha=.3)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p0b_timeseries.png"), dpi=150); plt.close(fig)
print("done; see figures/ and session.jsonl")
