#!/usr/bin/env python
"""Phases 1–4 experiments. Writes figures/p1..p4_*.png, results_1_4.json, appends session.jsonl.

    /tmp/bts/venv/bin/python run_phases_1_4.py
"""
import os, json, math, time
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.special import k0
from honor_well import Medium, Field, Ball, BallPhysics, MoleculeParams, Molecules, World, KINDS

HERE = os.path.dirname(os.path.abspath(__file__))
FIG = os.path.join(HERE, "figures"); os.makedirs(FIG, exist_ok=True)
SESSION = os.path.join(HERE, "session.jsonl")
RES = {}
T0 = time.time()

def log(event, **kw):
    with open(SESSION, "a") as fh:
        fh.write(json.dumps({"t": time.time(), "event": event, **kw}) + "\n")

def mk_world(N=128, L=24.0, med=None, balls=None, mp=None, seed=1, dt=0.02, physics=None, settle=300, molecules=True):
    rng = np.random.default_rng(seed)
    f = Field(N=N, L=L, medium=med or Medium())
    balls = balls or [Ball(np.zeros(2), np.zeros(2), 0.8, 6.0, name="gov")]
    mols = Molecules(f, mp or MoleculeParams(), rng) if molecules else None
    phys = physics or BallPhysics(rng=rng)
    w = World(f, balls, mols, phys, dt=dt, session=SESSION)
    w.settle(settle)
    return w

def series(w, key, kind=None):
    h = w.mols.history
    if kind: return np.array([x[key][kind] for x in h])
    return np.array([x[key] for x in h])

def frozen_physics(rng=None):
    return BallPhysics(crowd_gain=0.0, drag=5.0, repel=0.0, gov_rate=0.0, inf_rate=0.0, inf_jump_rate=0.0, inf_retarget_rate=0.0, rng=rng)

log("phases_1_4_start")

# =============================================================================== PHASE 1
print("P1.1 K0 check")
med = Medium(T=3.0, kappa=1.0, gamma=2.0)
f = Field(N=256, L=48.0, medium=med)
p = f.footprint(1.0, 0.25, 0, 0)
f.relax(p, dt=0.02, steps=4000, tol=1e-7)
rho, prof = f.radial_profile(nb=200, rmax=20)
lam = med.lam
theory = -1.0 / (2 * math.pi * med.T) * k0(np.maximum(rho, 1e-6) / lam)
m = (rho > 2 * lam) & (rho < 6 * lam)
rel = np.abs((prof[m] - theory[m]) / theory[m])
RES["p1_k0_max_rel_err"] = float(np.nanmax(rel)); RES["p1_k0_mean_rel_err"] = float(np.nanmean(rel))
fig, ax = plt.subplots(figsize=(7, 4))
ax.semilogy(rho, -prof, label="simulated (relaxed wave eq., Dirichlet rim)")
ax.semilogy(rho, -theory, "--", label=r"theory $\frac{w}{2\pi T}K_0(\rho/\lambda)$")
ax.axvspan(2 * lam, 6 * lam, color="#eee", label="checked window 2λ–6λ")
ax.set_xlabel("ρ"); ax.set_ylabel("depth"); ax.set_title(f"P1.1 point load vs K0: max rel. err {RES['p1_k0_max_rel_err']*100:.1f}% in window", fontsize=10)
ax.legend(fontsize=8); ax.grid(alpha=.3); fig.tight_layout(); fig.savefig(os.path.join(FIG, "p1_k0_check.png"), dpi=140); plt.close(fig)
log("p1_k0", max_rel_err=RES["p1_k0_max_rel_err"], mean_rel_err=RES["p1_k0_mean_rel_err"])

print("P1.2 edges")
fig, axes = plt.subplots(1, 3, figsize=(13, 4))
edge_res = {}
for ax, (name, cx) in zip(axes, [("centre", 0.0), ("near edge", 9.0), ("at edge", 10.6)]):
    f = Field(N=160, L=24.0, medium=Medium(T=3.0)); f.relax(f.footprint(6.0, 0.8, cx, 0.0), steps=1500)
    rho, prof = f.radial_profile(cx=cx, nb=60, rmax=6)
    ax.imshow(f.z, extent=[-12, 12, -12, 12], origin="lower", cmap="viridis", vmin=-0.7, vmax=0.02)
    ax.set_title(f"{name}: peak {-f.z.min():.2f}, area(depth>0.25) {((-f.z) > 0.25).sum() * f.dx**2:.2f}", fontsize=9); ax.set_xticks([]); ax.set_yticks([])
    edge_res[name] = {"peak": float(-f.z.min()), "capture_area": float(((-f.z) > 0.25).sum() * f.dx ** 2)}
fig.suptitle("P1.2 a real edge: the rim is pinned (z=0), so a well against the edge is shallower on that side and holds fewer", fontsize=10)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p1_edges.png"), dpi=140); plt.close(fig)
RES["p1_edges"] = edge_res; log("p1_edges", **edge_res)

print("P1.3 T sweep")
Ts = [0.5, 1.0, 2.0, 3.0, 5.0, 8.0, 12.0]
sw = []
for T in Ts:
    w = mk_world(med=Medium(T=T), physics=frozen_physics(), seed=3)
    w.run(700)
    out = series(w, "outcast"); ins = series(w, "inside")
    cap = float(((-w.f.z) > w.mols.delta).sum() * w.f.dx ** 2)
    sw.append((T, math.sqrt(T), float(out[-100:].mean() / (w.mols.P.n * 0.8)), float(ins[-100:].mean()), cap, float(-w.f.z.min())))
RES["p1_T_sweep"] = sw
fig, axes = plt.subplots(1, 3, figsize=(13, 3.8))
axes[0].plot([s[0] for s in sw], [s[2] for s in sw], "o-"); axes[0].set_title("outcast fraction (non-foam) vs cohesion T", fontsize=10)
axes[1].plot([s[0] for s in sw], [s[4] for s in sw], "o-"); axes[1].set_title("capture area (depth > δ) vs T", fontsize=10)
axes[2].plot([s[0] for s in sw], [s[5] for s in sw], "o-"); axes[2].set_title("peak depth vs T", fontsize=10)
for ax in axes: ax.set_xlabel("T (cohesion)"); ax.grid(alpha=.3)
fig.suptitle("P1.3 raising cohesion widens the well (λ=√(T/κ)) and lowers the peak; outcasts fall, then the shallow well stops capturing", fontsize=10)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p1_T_sweep.png"), dpi=140); plt.close(fig)
log("p1_T_sweep", rows=sw)

print("P1.4 regional T")
N, L = 160, 24.0
f = Field(N=N, L=L, medium=Medium(T=3.0))
Tmap = np.full((N, N), 0.6)
left = (np.hypot(f.X + 5, f.Y) < 3.5); right = (np.hypot(f.X - 5, f.Y) < 3.5)
corridor = (np.abs(f.Y - 0) < 0.8) & (f.X > -5) & (f.X < 5)
Tmap[left | right | corridor] = 6.0
f.med.T_map = Tmap; f.Tmap = Tmap
f.relax(f.footprint(6.0, 0.8, -5.0, 0.0), steps=2500)
on = -f.sample(f.z, np.array([0.0]), np.array([0.0]))[0]          # in corridor, 5 from the ball
off = -f.sample(f.z, np.array([-5.0]), np.array([5.0]))[0]        # off corridor, 5 from the ball
far_patch = -f.sample(f.z, np.array([5.0]), np.array([0.0]))[0]   # centre of the other patch, 10 away
RES["p1_regional"] = {"corridor_depth_5": float(on), "offcorridor_depth_5": float(off), "other_patch_depth_10": float(far_patch), "ratio": float(on / max(off, 1e-9))}
fig, axes = plt.subplots(1, 2, figsize=(10, 4.2))
axes[0].imshow(Tmap, extent=[-12, 12, -12, 12], origin="lower", cmap="Greys"); axes[0].set_title("cohesion map T(x,y): two clans + a corridor, low-T background", fontsize=9)
im = axes[1].imshow(f.z, extent=[-12, 12, -12, 12], origin="lower", cmap="viridis"); axes[1].set_title(f"depth: corridor pt {on:.3f} vs off-corridor pt {off:.3f} at equal distance (×{on/max(off,1e-9):.1f})", fontsize=9)
for ax in axes: ax.set_xticks([]); ax.set_yticks([])
fig.colorbar(im, ax=axes[1], shrink=0.8); fig.tight_layout(); fig.savefig(os.path.join(FIG, "p1_regional_T.png"), dpi=140); plt.close(fig)
log("p1_regional", **RES["p1_regional"])

print("P1.5 convergence")
curves = {}
for label, N_, dt_ in (("N=96, dt=0.02", 96, 0.02), ("N=192, dt=0.01", 192, 0.01)):
    w = mk_world(N=N_, dt=dt_, physics=frozen_physics(), seed=5)
    w.run(int(12 / dt_))
    t = np.arange(len(w.mols.history)) * dt_
    curves[label] = (t, series(w, "outcast") / (w.mols.P.n * 0.8), series(w, "depth", "surface"))
ta, oa, da = curves["N=96, dt=0.02"]; tb, ob, db = curves["N=192, dt=0.01"]
ob_i = np.interp(ta, tb, ob); db_i = np.interp(ta, tb, db)
RES["p1_convergence"] = {"outcast_mean_abs_diff": float(np.abs(oa - ob_i).mean()), "surface_depth_mean_abs_diff": float(np.abs(da - db_i).mean())}
fig, axes = plt.subplots(1, 2, figsize=(10, 3.6))
for lab, (t, o, d) in curves.items():
    axes[0].plot(t, o, label=lab); axes[1].plot(t, d, label=lab)
axes[0].set_title("outcast fraction"); axes[1].set_title("mean surface-molecule depth")
for ax in axes: ax.legend(fontsize=8); ax.grid(alpha=.3); ax.set_xlabel("t")
fig.suptitle(f"P1.5 resolution/timestep halved: mean |Δ| outcast {RES['p1_convergence']['outcast_mean_abs_diff']:.3f}, depth {RES['p1_convergence']['surface_depth_mean_abs_diff']:.3f}", fontsize=10)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p1_convergence.png"), dpi=140); plt.close(fig)
log("p1_convergence", **RES["p1_convergence"])
print(f"phase 1 done {time.time()-T0:.0f}s")

# =============================================================================== PHASE 2
print("P2.1 crowd pushes the ball")
rng = np.random.default_rng(11)
w = mk_world(physics=BallPhysics(crowd_gain=0.6, drag=0.8, gov_rate=0.0, rng=rng), seed=11)
# pile the crowd on one side
w.mols.pos[:] = rng.normal([4.0, 2.0], [1.5, 1.5], size=w.mols.pos.shape); w.mols.pos = np.clip(w.mols.pos, -11, 11)
traj = []
for _ in range(60):
    w.run(10); traj.append(w.balls[0].p.copy())
traj = np.array(traj)
RES["p2_crowd_push"] = {"final_ball_pos": traj[-1].tolist(), "displacement": float(np.linalg.norm(traj[-1]))}
fig, ax = plt.subplots(figsize=(5.5, 5))
ax.imshow(w.f.z, extent=[-12, 12, -12, 12], origin="lower", cmap="viridis")
ax.scatter(w.mols.pos[:, 0], w.mols.pos[:, 1], s=6, c="white", edgecolors="k", linewidths=.2)
ax.plot(traj[:, 0], traj[:, 1], "r.-", ms=3, label="ball path"); ax.plot(0, 0, "rx", ms=10, label="start")
ax.set_title(f"P2.1 the code follows the mass: ball rolled {RES['p2_crowd_push']['displacement']:.2f} toward the crowd", fontsize=9); ax.legend(fontsize=8)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p2_crowd_push.png"), dpi=140); plt.close(fig)
log("p2_crowd_push", **RES["p2_crowd_push"])

print("P2.2 radius process + P2.3 two balls")
rng = np.random.default_rng(12)
balls = [Ball(np.array([-4.0, 0.0]), np.zeros(2), 0.8, 6.0, kind="government", camp=0, name="gov"),
         Ball(np.array([4.0, 0.0]), np.zeros(2), 0.8, 6.0, kind="influencer", camp=1, name="inf")]
phys = BallPhysics(crowd_gain=0.3, drag=0.8, repel=4.0, gov_rate=0.05, inf_rate=0.6, inf_jump_rate=0.0, inf_retarget_rate=0.25, rng=rng)
balls[0].r_target = 1.6
w = mk_world(balls=balls, physics=phys, seed=12)
rr, dd = [], []
for _ in range(120):
    w.run(10); rr.append((w.balls[0].r, w.balls[1].r)); dd.append(np.linalg.norm(w.balls[0].p - w.balls[1].p))
rr = np.array(rr); t = np.arange(len(rr)) * 10 * w.dt
fig, axes = plt.subplots(1, 2, figsize=(11, 3.6))
axes[0].plot(t, rr[:, 0], label="government (slow, target 1.6)"); axes[0].plot(t, rr[:, 1], label="influencer (fast, retargets)"); axes[0].set_title("P2.2 radius as a process", fontsize=10); axes[0].legend(fontsize=8)
axes[1].plot(t, dd); axes[1].set_title("P2.3a rival balls (different camps): separation over time", fontsize=10)
for ax in axes: ax.grid(alpha=.3); ax.set_xlabel("t")
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p2_radius_rivals.png"), dpi=140); plt.close(fig)
RES["p2_rivals"] = {"initial_sep": 8.0, "final_sep": float(dd[-1]), "gov_r_final": float(rr[-1, 0]), "inf_r_range": [float(rr[:, 1].min()), float(rr[:, 1].max())]}
log("p2_rivals", **RES["p2_rivals"])

rng = np.random.default_rng(13)
balls = [Ball(np.array([-1.5, 0.0]), np.array([0.3, 0.0]), 0.8, 6.0, camp=0, name="A"),
         Ball(np.array([1.5, 0.0]), np.array([-0.3, 0.0]), 0.8, 4.0, camp=0, name="B")]
w = mk_world(balls=balls, physics=BallPhysics(crowd_gain=0.0, drag=0.3, gov_rate=0.0, rng=rng), seed=13)
w.run(600)
merged = [e for e in w.events if e[1][0] == "merge"]
A = w.balls[0]
RES["p2_merge"] = {"merged": bool(merged), "step": merged[0][0] if merged else None, "w_after": float(A.w), "r_after": float(A.r)}
log("p2_merge", **RES["p2_merge"])

print("P2.4 static-ness")
stat = []
for wgt in (2.0, 6.0, 12.0):
    for r in (0.5, 2.0):
        rng = np.random.default_rng(14)
        w = mk_world(balls=[Ball(np.zeros(2), np.zeros(2), r, wgt, name="b")], physics=BallPhysics(crowd_gain=0.6, drag=0.8, gov_rate=0.0, rng=rng), seed=14, settle=200)
        w.mols.pos[:] = rng.normal([4.0, 2.0], [1.5, 1.5], size=w.mols.pos.shape)
        w.run(400)
        stat.append((wgt, r, float(np.linalg.norm(w.balls[0].p))))
RES["p2_static"] = stat
fig, ax = plt.subplots(figsize=(6, 3.6))
for r in (0.5, 2.0):
    ax.plot([s[0] for s in stat if s[1] == r], [s[2] for s in stat if s[1] == r], "o-", label=f"r={r}")
ax.set_xlabel("ball weight w"); ax.set_ylabel("displacement after the same crowd push"); ax.set_title("P2.4 bowling balls become more static: inertia ∝ w, drag ∝ r", fontsize=10); ax.legend(); ax.grid(alpha=.3)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p2_static.png"), dpi=140); plt.close(fig)
log("p2_static", rows=stat)
print(f"phase 2 done {time.time()-T0:.0f}s")

# =============================================================================== PHASE 3
print("P3.1 delta ratchet")
fig, axes = plt.subplots(1, 3, figsize=(14, 3.8))
ratchet = {}
for chi, col in ((0.0, "#555"), (0.5, "#c9a000"), (1.0, "#d03050")):
    rng = np.random.default_rng(21)
    b = Ball(np.zeros(2), np.zeros(2), 1.6, 6.0, name="gov"); b.r_target = 0.5           # slowly narrowing code: more depth on offer
    w = mk_world(balls=[b], physics=BallPhysics(crowd_gain=0.0, drag=5.0, gov_rate=0.08, rng=rng), mp=MoleculeParams(chi=chi), seed=21)
    w.run(1400)
    t = np.arange(len(w.mols.history)) * w.dt
    dep = np.array([x["depth"]["surface"] for x in w.mols.history]); R = np.array([x["R"]["surface"] for x in w.mols.history])
    dl = series(w, "delta"); ins = series(w, "inside")
    axes[0].plot(t, dep, color=col, label=f"χ={chi}"); axes[1].plot(t, R, color=col, label=f"χ={chi}"); axes[2].plot(t, dl, color=col, label=f"δ(t), χ={chi}"); axes[2].plot(t, ins / w.mols.P.n, color=col, ls=":", label=f"inside frac, χ={chi}")
    # crude shape test: ratio of late slope to early slope of the depth curve
    e = np.polyfit(t[50:300], dep[50:300], 1)[0]; l = np.polyfit(t[-300:], dep[-300:], 1)[0]
    ratchet[chi] = {"early_slope": float(e), "late_slope": float(l), "final_delta": float(dl[-1]), "final_inside_frac": float(ins[-50:].mean() / w.mols.P.n), "min_R": float(R.min())}
axes[0].set_title("mean surface depth (dose)", fontsize=10); axes[1].set_title("mean reward depth − set-point", fontsize=10); axes[1].axhline(0, color="k", lw=.6); axes[2].set_title("demand δ(t) and inside fraction", fontsize=10)
for ax in axes: ax.grid(alpha=.3); ax.legend(fontsize=7); ax.set_xlabel("t")
fig.suptitle("P3.1 the demand ratchets with the insiders' own depth (χ): the code narrows, depth escalates, reward decays, and the inside shrinks", fontsize=10)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p3_ratchet.png"), dpi=140); plt.close(fig)
RES["p3_ratchet"] = ratchet; log("p3_ratchet", **{str(k): v for k, v in ratchet.items()})

print("P3.2 tolerance distribution → ejection order")
rng = np.random.default_rng(22)
b = Ball(np.zeros(2), np.zeros(2), 1.4, 6.0, name="gov"); b.r_target = 0.5
w = mk_world(balls=[b], physics=BallPhysics(crowd_gain=0.0, drag=5.0, gov_rate=0.08, rng=rng), mp=MoleculeParams(eta_sigma=0.8, chi=0.5), seed=22)
first_trap = np.full(w.mols.P.n, -1)
for s in range(140):
    w.run(10)
    hit = (w.mols.trapped_since >= 0) & (first_trap < 0); first_trap[hit] = w.step_idx
m = (first_trap > 0) & (w.mols.kind != "foam")
corr = float(np.corrcoef(np.log(w.mols.eta[m]), first_trap[m])[0, 1]) if m.sum() > 5 else float("nan")
RES["p3_eta"] = {"n_trapped": int(m.sum()), "corr_logeta_vs_first_trap_step": corr}
fig, ax = plt.subplots(figsize=(6, 3.8)); ax.scatter(w.mols.eta[m], first_trap[m] * w.dt, s=10)
ax.set_xscale("log"); ax.set_xlabel("tolerance rate η (fast tolerance = right)"); ax.set_ylabel("time of first trap (R < −R*)")
ax.set_title(f"P3.2 fast-tolerance molecules are trapped first (corr log η vs time = {corr:.2f})", fontsize=9); ax.grid(alpha=.3)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p3_eta.png"), dpi=140); plt.close(fig)
log("p3_eta", **RES["p3_eta"])

print("P3.3 relapse + P3.4 belief loss")
rng = np.random.default_rng(23)
balls = [Ball(np.zeros(2), np.zeros(2), 1.0, 7.0, kind="influencer", name="inf")]
phys = BallPhysics(crowd_gain=0.0, drag=5.0, inf_rate=0.0, inf_jump_rate=0.12, inf_retarget_rate=0.0, rng=rng)
mp = MoleculeParams(belief_loss_tau=120)
w = mk_world(balls=balls, physics=phys, mp=mp, seed=23)
kinds0 = w.mols.kind.copy(); b0 = w.mols.b.copy()
snaps = []
w.run(2400, snapshot_every=600, snapshots=snaps)
jumps = [e for e in w.events if e[1][0] == "jump"]
RES["p3_relapse"] = {"jumps": len(jumps), "relapse_by_kind": w.mols.counts["relapse"], "beliefs_lost": w.mols.counts["beliefs_lost"],
                     "planners_to_deep": int(((kinds0 == "planner") & (w.mols.kind == "deep")).sum()), "n_planner0": int((kinds0 == "planner").sum())}
# relocation speed after the last jump: time for molecules with b==0 vs b>0 to get inside
if jumps:
    js = jumps[-1][0]
    hist = w.mols.history
    def t_inside_after(mask):
        ts = []
        for i in np.where(mask)[0]:
            pass
        return ts
    # simpler: compare mean depth gain over the 150 steps after the last jump
    d_after = np.array([h["depth"] for h in hist[js:js + 150]])
RES["p3_relapse"]["mean_depth_zero_anchor_vs_anchored_after_last_jump"] = None
kinds_final = {k: int((w.mols.kind == k).sum()) for k in KINDS}
RES["p3_relapse"]["kinds_final"] = kinds_final
fig, axes = plt.subplots(1, 4, figsize=(17, 4.2)); cols = {"surface": "#fff", "planner": "#ffd166", "deep": "#06d6a0", "foam": "#ef476f"}
for ax, (si, zz, pp, kk, bb) in zip(axes, snaps):
    ax.imshow(zz, extent=[-12, 12, -12, 12], origin="lower", cmap="viridis", vmin=-1.2, vmax=0.1)
    for k, c in cols.items():
        mm = kk == k; ax.scatter(pp[mm, 0], pp[mm, 1], s=8, c=c, edgecolors="k", linewidths=.3, label=k)
    for (bp, br) in bb: ax.add_patch(plt.Circle(bp, br, fill=False, ec="w", ls="--"))
    ax.set_title(f"step {si}", fontsize=9); ax.set_xticks([]); ax.set_yticks([])
axes[0].legend(fontsize=7, loc="lower left")
fig.suptitle(f"P3.3/3.4 jumping influencer: {len(jumps)} jumps, relapses {w.mols.counts['relapse']}, anchors lost {w.mols.counts['beliefs_lost']}, planners→deep {RES['p3_relapse']['planners_to_deep']}/{RES['p3_relapse']['n_planner0']}", fontsize=9)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p3_relapse_snapshots.png"), dpi=140); plt.close(fig)
log("p3_relapse", **{k: v for k, v in RES["p3_relapse"].items()})
print(f"phase 3 done {time.time()-T0:.0f}s")

# =============================================================================== PHASE 4
print("P4.1 buoyancy / dissolution vs splash size")
diss = []
for amp in (0.0, 0.6, 1.2, 2.4):
    rng = np.random.default_rng(31)
    b = Ball(np.zeros(2), np.zeros(2), 0.8, 6.0, kind="government", name="gov")
    w = mk_world(balls=[b], physics=frozen_physics(rng), mp=MoleculeParams(mix=(0.3, 0.1, 0.1, 0.5)), seed=31)
    w.run(200)
    # manual splash of chosen amplitude: ball jumps to (5,3)
    w.f.zprev = w.f.z + amp * (np.hypot(w.f.X, w.f.Y) <= 2.0) * w.f.dx
    w.balls[0].p = np.array([5.0, 3.0])
    w.run(600)
    diss.append((amp, w.mols.counts["foam_dissolved"], int((w.mols.kind == "foam").sum())))
RES["p4_dissolution"] = diss
fig, ax = plt.subplots(figsize=(6, 3.6)); ax.plot([d[0] for d in diss], [d[1] for d in diss], "o-")
ax.set_xlabel("splash amplitude"); ax.set_ylabel("foam dissolved"); ax.set_title("P4.1 foam survives drift; dissolution rises with splash size", fontsize=10); ax.grid(alpha=.3)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p4_dissolution.png"), dpi=140); plt.close(fig)
log("p4_dissolution", rows=diss)

print("P4.2 foam mass")
fm_res = {}
fig, axes = plt.subplots(1, 2, figsize=(10, 4.2))
for ax, fmass in zip(axes, (0.0, 0.08)):
    rng = np.random.default_rng(32)
    w = mk_world(balls=[Ball(np.zeros(2), np.zeros(2), 0.8, 6.0, name="gov")], physics=frozen_physics(rng), mp=MoleculeParams(mix=(0.3, 0.1, 0.1, 0.5), foam_mass=fmass), seed=32)
    w.run(900)
    rho, prof = w.f.radial_profile(nb=48, rmax=12)
    rim = float(np.nanmax(-prof[rho > 6])) if np.any(rho > 6) else 0.0
    out = series(w, "outcast")[-100:].mean() / (w.mols.P.n * 0.5)
    fm_res[str(fmass)] = {"rim_depth_beyond_6": rim, "outcast_frac": float(out), "peak": float(-w.f.z.min())}
    ax.imshow(w.f.z, extent=[-12, 12, -12, 12], origin="lower", cmap="viridis", vmin=-0.6, vmax=0.05)
    fm = w.mols.kind == "foam"; ax.scatter(w.mols.pos[fm, 0], w.mols.pos[fm, 1], s=8, c="#ef476f", edgecolors="k", linewidths=.3)
    ax.set_title(f"foam mass {fmass}: outer depression {rim:.3f}, outcast frac {out:.2f}", fontsize=9); ax.set_xticks([]); ax.set_yticks([])
fig.suptitle("P4.2 user decision pending: weightless foam leaves the field alone; foam with slight mass presses the edges down and shallows the gradient out of the well", fontsize=9)
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p4_foam_mass.png"), dpi=140); plt.close(fig)
RES["p4_foam_mass"] = fm_res; log("p4_foam_mass", **fm_res)

print("P4.3 rafts + P4.4 refloat")
def clusters(pos, rng_=1.2):
    n = len(pos); seen = np.zeros(n, bool); sizes = []
    for i in range(n):
        if seen[i]: continue
        stack = [i]; seen[i] = True; size = 0
        while stack:
            k = stack.pop(); size += 1
            d = np.linalg.norm(pos - pos[k], axis=1); nb = np.where((d < rng_) & (~seen))[0]
            seen[nb] = True; stack.extend(nb.tolist())
        sizes.append(size)
    return sizes
rng = np.random.default_rng(33)
b = Ball(np.zeros(2), np.zeros(2), 0.8, 6.0, kind="influencer", name="inf")
phys = BallPhysics(crowd_gain=0.0, drag=5.0, inf_rate=0.0, inf_jump_rate=0.06, inf_retarget_rate=0.0, rng=rng)
w = mk_world(balls=[b], physics=phys, mp=MoleculeParams(mix=(0.35, 0.1, 0.1, 0.45), refloat_tau=200, belief_loss_tau=150), seed=33)
w.run(800)
fm = w.mols.kind == "foam"; pf = w.mols.pos[fm]; rad = np.linalg.norm(pf, axis=1)
edge_sizes = clusters(pf[rad > 7]); centre_sizes = clusters(pf[rad <= 7])
before = {"edge_mean_raft": float(np.mean(edge_sizes)) if edge_sizes else 0, "centre_mean_raft": float(np.mean(centre_sizes)) if centre_sizes else 0, "n_edge_foam": int((rad > 7).sum()), "n_centre_foam": int((rad <= 7).sum())}
w.run(2200)
fm = w.mols.kind == "foam"; pf = w.mols.pos[fm]; rad = np.linalg.norm(pf, axis=1)
edge_sizes = clusters(pf[rad > 7]); centre_sizes = clusters(pf[rad <= 7])
after = {"edge_mean_raft": float(np.mean(edge_sizes)) if edge_sizes else 0, "centre_mean_raft": float(np.mean(centre_sizes)) if centre_sizes else 0, "n_edge_foam": int((rad > 7).sum()), "n_centre_foam": int((rad <= 7).sum())}
RES["p4_rafts"] = {"before_jumps": before, "after_jumps": after, "jumps": len([e for e in w.events if e[1][0] == "jump"]),
                   "foam_dissolved": w.mols.counts["foam_dissolved"], "refloated": w.mols.counts["refloated"], "beliefs_lost": w.mols.counts["beliefs_lost"]}
nf = np.array([h["nfoam"] for h in w.mols.history]); t = np.arange(len(nf)) * w.dt
fig, axes = plt.subplots(1, 2, figsize=(11, 4))
axes[0].imshow(w.f.z, extent=[-12, 12, -12, 12], origin="lower", cmap="viridis")
cols = {"surface": "#fff", "planner": "#ffd166", "deep": "#06d6a0", "foam": "#ef476f"}
for k, c in cols.items():
    mm = w.mols.kind == k; axes[0].scatter(w.mols.pos[mm, 0], w.mols.pos[mm, 1], s=8, c=c, edgecolors="k", linewidths=.3, label=k)
axes[0].add_patch(plt.Circle((0, 0), 7, fill=False, ec="w", ls=":")); axes[0].legend(fontsize=7, loc="lower left"); axes[0].set_xticks([]); axes[0].set_yticks([])
axes[0].set_title(f"P4.3 rafts after {RES['p4_rafts']['jumps']} jumps: edge mean raft {after['edge_mean_raft']:.1f} ({after['n_edge_foam']} foam) · centre {after['centre_mean_raft']:.1f} ({after['n_centre_foam']})", fontsize=8)
axes[1].plot(t, nf); axes[1].set_title(f"P4.4 foam count: dissolved {w.mols.counts['foam_dissolved']}, refloated {w.mols.counts['refloated']}", fontsize=9); axes[1].set_xlabel("t"); axes[1].grid(alpha=.3)
for e in w.events:
    if e[1][0] == "jump": axes[1].axvline(e[0] * w.dt, color="#999", lw=.6, ls="--")
fig.tight_layout(); fig.savefig(os.path.join(FIG, "p4_rafts_refloat.png"), dpi=140); plt.close(fig)
log("p4_rafts", **RES["p4_rafts"])

json.dump(RES, open(os.path.join(HERE, "results_1_4.json"), "w"), indent=1, default=str)
log("phases_1_4_done", seconds=time.time() - T0)
print(f"all done {time.time()-T0:.0f}s")
