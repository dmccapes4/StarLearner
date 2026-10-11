#!/usr/bin/env python
"""Honor Well — simulation core for Phases 1–4.

Field:     tensioned membrane on a fluid foundation, damped wave equation,
           regional tension T(x,y), optional strain-stiffening, real edges
           (Dirichlet rim + sponge damping).
Balls:     honor codes with inertia ~ w, drag ~ r, pushed by the crowd,
           radius as a process (slow "government" / fast "influencer"),
           pairwise repel (rival) or merge (aligned), jumps produce splashes.
Molecules: surface / planner / deep / foam, with belief anchors, allostatic
           set-points, a ratcheting demand delta, belief loss on the floor,
           relapse bookkeeping, foam buoyancy, rafts, dissolution and refloat.

Everything is numpy. See REPORT_HONOR_WELL_DERIVATION_20261010.md for the
equations and PHASES_1_4_RESULTS_20261011.md for what the runs showed.
"""
from __future__ import annotations
import json, math, time
from dataclasses import dataclass, field
import numpy as np


# ----------------------------------------------------------------------------- medium / field
@dataclass
class Medium:
    T: float = 3.0          # cohesion (membrane tension)
    kappa: float = 1.0      # restoring stiffness
    gamma: float = 1.2      # damping
    stiffen: float = 0.0    # strain-stiffening: T_eff = T (1 + stiffen |grad z|^2)
    T_map: np.ndarray | None = None   # regional cohesion, same shape as the grid

    @property
    def lam(self):
        return math.sqrt(self.T / self.kappa)


class Field:
    def __init__(self, N=160, L=24.0, medium: Medium = None, edge="dirichlet", sponge=6):
        self.N, self.L, self.dx = N, L, L / N
        xs = (np.arange(N) - N / 2 + 0.5) * self.dx
        self.X, self.Y = np.meshgrid(xs, xs, indexing="xy")
        self.med = medium or Medium()
        self.z = np.zeros((N, N)); self.zprev = np.zeros((N, N))
        self.edge = edge
        # sponge: damping ramps up over the outer `sponge` cells so waves do not reflect hard
        ramp = np.ones((N, N))
        if sponge > 0:
            i = np.arange(N)
            d = np.minimum.outer(np.minimum(i, N - 1 - i), np.minimum(i, N - 1 - i))
            ramp = 1.0 + 6.0 * np.clip((sponge - d) / sponge, 0, 1) ** 2
        self.damp_map = ramp
        self.Tmap = self.med.T_map if self.med.T_map is not None else np.full((N, N), self.med.T)
        self.static_load = np.zeros((N, N))

    # --- operators
    def lap(self, a):
        return (np.roll(a, 1, 0) + np.roll(a, -1, 0) + np.roll(a, 1, 1) + np.roll(a, -1, 1) - 4 * a) / self.dx ** 2

    def div_T_grad(self, a):
        """div( T grad a ) with face-averaged T, so regional cohesion is handled conservatively."""
        dx = self.dx; T = self.Tmap
        if self.med.stiffen:
            gy, gx = np.gradient(a, dx)
            T = T * (1.0 + self.med.stiffen * (gx ** 2 + gy ** 2))
        Tx = 0.5 * (T + np.roll(T, -1, 1)); Ty = 0.5 * (T + np.roll(T, -1, 0))
        fx = Tx * (np.roll(a, -1, 1) - a) / dx
        fy = Ty * (np.roll(a, -1, 0) - a) / dx
        return (fx - np.roll(fx, 1, 1)) / dx + (fy - np.roll(fy, 1, 0)) / dx

    def apply_edge(self, a):
        if self.edge == "dirichlet":
            a[0, :] = a[-1, :] = a[:, 0] = a[:, -1] = 0.0
        return a

    def footprint(self, w, r, cx, cy):
        disc = (np.hypot(self.X - cx, self.Y - cy) <= r).astype(float)
        n = disc.sum()
        return w * disc / (n * self.dx ** 2) if n else disc

    def step(self, p, dt):
        acc = self.div_T_grad(self.z) - self.med.kappa * self.z - self.med.gamma * self.damp_map * (self.z - self.zprev) / dt - p
        znew = 2 * self.z - self.zprev + acc * dt * dt
        self.zprev, self.z = self.z, self.apply_edge(znew)

    def relax(self, p, dt=0.02, steps=1500, tol=1e-6):
        """Time-step to the static solution (works with regional T, stiffening, real edges)."""
        for s in range(steps):
            zo = self.z.copy(); self.step(p, dt)
            if s > 50 and np.abs(self.z - zo).max() < tol:
                break
        self.zprev = self.z.copy()
        return self.z

    def sample(self, a, px, py):
        i = np.clip(((py + self.L / 2) / self.dx).astype(int), 0, self.N - 1)
        j = np.clip(((px + self.L / 2) / self.dx).astype(int), 0, self.N - 1)
        return a[i, j]

    def grad_at(self, px, py):
        gy, gx = np.gradient(self.z, self.dx)
        return self.sample(gx, px, py), self.sample(gy, px, py)

    def radial_profile(self, cx=0.0, cy=0.0, nb=100, rmax=None):
        rho = np.hypot(self.X - cx, self.Y - cy); rmax = rmax or self.L / 2
        edges = np.linspace(0, rmax, nb + 1); idx = np.digitize(rho.ravel(), edges) - 1
        prof = np.array([self.z.ravel()[idx == i].mean() if np.any(idx == i) else np.nan for i in range(nb)])
        return 0.5 * (edges[1:] + edges[:-1]), prof


# ----------------------------------------------------------------------------- balls
@dataclass
class Ball:
    p: np.ndarray
    v: np.ndarray
    r: float
    w: float
    kind: str = "government"       # government: slow radius process; influencer: fast + jumps
    camp: int = 0                   # balls with the same camp merge; different camps repel
    r_target: float = None
    alive: bool = True
    name: str = ""

    def __post_init__(self):
        if self.r_target is None:
            self.r_target = self.r


class BallPhysics:
    def __init__(self, crowd_gain=0.6, drag=0.8, repel=4.0, merge_dist=0.6,
                 gov_rate=0.05, inf_rate=0.6, inf_jump_rate=0.03, inf_retarget_rate=0.15, rng=None):
        self.crowd_gain, self.drag, self.repel, self.merge_dist = crowd_gain, drag, repel, merge_dist
        self.gov_rate, self.inf_rate = gov_rate, inf_rate
        self.inf_jump_rate, self.inf_retarget_rate = inf_jump_rate, inf_retarget_rate
        self.rng = rng or np.random.default_rng(0)

    def step(self, balls, mol_pos, dt, L, log=None, t=0.0):
        events = []
        live = [b for b in balls if b.alive]
        for b in live:
            f = np.zeros(2)
            # crowd pushes the ball: mass near the ball pulls its centre toward the crowd's centre of mass
            if mol_pos is not None and len(mol_pos):
                d = mol_pos - b.p; dist = np.linalg.norm(d, axis=1)
                near = dist < 2.5 * b.r + 1.0
                if near.any():
                    f += self.crowd_gain * d[near].sum(0) / max(1, len(mol_pos)) * 10.0
            # rival / aligned balls
            for o in live:
                if o is b: continue
                d = b.p - o.p; dist = np.linalg.norm(d) + 1e-9
                if o.camp != b.camp:
                    f += self.repel * b.w * o.w * d / dist ** 3 / 10.0
                elif dist < (b.r + o.r) * self.merge_dist + 0.2 and b.w >= o.w:
                    # merge: footprint areas add, weights add, momentum conserved
                    b.v = (b.w * b.v + o.w * o.v) / (b.w + o.w); b.p = (b.w * b.p + o.w * o.p) / (b.w + o.w)
                    b.w += o.w; b.r = math.sqrt(b.r ** 2 + o.r ** 2); b.r_target = b.r; o.alive = False
                    events.append(("merge", b.name, o.name))
            # inertia ~ w, drag ~ r
            a = (f - self.drag * b.r * b.v) / b.w
            b.v = b.v + a * dt
            old = b.p.copy(); b.p = b.p + b.v * dt
            # radius as a process
            rate = self.gov_rate if b.kind == "government" else self.inf_rate
            b.r += rate * (b.r_target - b.r) * dt
            if b.kind == "influencer":
                if self.rng.random() < self.inf_retarget_rate * dt:
                    b.r_target = float(np.clip(self.rng.normal(b.r, 0.5), 0.25, 3.0))
                if self.rng.random() < self.inf_jump_rate * dt:
                    b.p = self.rng.uniform(-L / 2 + 3, L / 2 - 3, 2); b.v[:] = 0
                    events.append(("jump", b.name, old.tolist(), b.p.tolist()))
            b.p = np.clip(b.p, -L / 2 + b.r + 0.5, L / 2 - b.r - 0.5)
            b.r = float(np.clip(b.r, 0.2, 4.0))
        return events


# ----------------------------------------------------------------------------- molecules
KINDS = ("surface", "planner", "deep", "foam")

@dataclass
class MoleculeParams:
    n: int = 240
    mix: tuple = (0.45, 0.2, 0.15, 0.2)
    alpha: float = 10.0        # gradient gain (surface, deep)
    beta: float = 1.4          # planner drive toward predicted ball position
    horizon: int = 60          # planner look-ahead (steps)
    c_b: float = 0.35          # anchor drag per belief
    body: float = 0.5          # repulsion radius
    push: float = 4.0          # crowd propulsion gain
    delta0: float = 0.25       # base demand
    chi: float = 0.0           # demand ratchet: delta = delta0 + chi * mean insider depth
    eta_mu: float = 0.02       # tolerance rate (lognormal median)
    eta_sigma: float = 0.0     # lognormal spread of tolerance rates (0 = identical)
    R_star: float = 0.08       # reward deficit that counts as "trapped"
    relapse_tau: int = 150     # steps within which re-entering a well counts as relapse
    belief_loss_tau: int = 250 # floor dwell steps before dropping one anchor
    foam_speed: float = 0.35   # foam mobility
    foam_out: float = 0.08     # foam outward drift
    v_star: float = 0.35       # wave speed that pushes foam under
    buoyancy: float = 0.15     # foam submersion recovery rate
    u_dissolve: float = 1.0    # submersion level that dissolves foam
    dissolve_tau: int = 40     # steps held under before dissolution
    foam_mass: float = 0.0     # weight each foam molecule adds to the field (user decision)
    raft_range: float = 1.2    # foam-foam attraction range
    raft_gain: float = 0.6
    refloat_tau: int = 300     # steps of unmet set-point with zero anchors before re-floating as foam


class Molecules:
    def __init__(self, field: Field, params: MoleculeParams, rng):
        self.f, self.P, self.rng = field, params, rng
        n = params.n; L = field.L
        self.kind = rng.choice(KINDS, size=n, p=params.mix)
        self.pos = rng.uniform(-L / 2 + 1.5, L / 2 - 1.5, size=(n, 2))
        self.b = np.where(self.kind == "deep", rng.integers(0, 2, n), rng.integers(2, 7, n))
        self.eta = np.exp(rng.normal(math.log(params.eta_mu), params.eta_sigma, n))
        self.s = np.zeros(n)                   # allostatic set-point
        self.depth = np.zeros(n); self.R = np.zeros(n)
        self.floor_dwell = np.zeros(n, int); self.unmet = np.zeros(n, int)
        self.u = np.zeros(n)                   # foam submersion
        self.under = np.zeros(n, int)
        self.trapped_since = np.full(n, -1)    # step at which R fell below -R_star
        self.delta = params.delta0
        self.counts = {"foam_dissolved": 0, "refloated": 0, "beliefs_lost": 0, "relapse": {k: 0 for k in KINDS}, "ejected": 0}
        self.history = []

    def inside(self):
        return (self.depth >= self.delta) & (self.kind != "foam")

    def step(self, balls, predict, dt, step_idx):
        P, f = self.P, self.f; n = len(self.pos)
        gx, gy = f.grad_at(self.pos[:, 0], self.pos[:, 1]); g = np.stack([gx, gy], 1)
        vel = np.zeros_like(self.pos)
        m = np.isin(self.kind, ["surface", "deep"]); vel[m] = -P.alpha * g[m]
        m = self.kind == "planner"
        if m.any() and balls:
            tgt = predict(step_idx + P.horizon)      # predicted position of the heaviest live ball
            d = tgt - self.pos[m]; d /= (np.linalg.norm(d, axis=1, keepdims=True) + 1e-9)
            vel[m] = P.beta * d - 0.3 * P.alpha * g[m]
        m = self.kind == "foam"
        if m.any():
            out = self.pos[m] / (np.linalg.norm(self.pos[m], axis=1, keepdims=True) + 1e-9)
            vel[m] = 1.5 * g[m] + P.foam_out * out
        # crowd propulsion (+ foam rafts)
        diff = self.pos[:, None, :] - self.pos[None, :, :]; dist = np.linalg.norm(diff, axis=2) + np.eye(n)
        push = (diff / dist[..., None] * np.clip(P.body - dist, 0, None)[..., None]).sum(1)
        vel += P.push * push
        if m.any() and P.raft_gain:
            fm = np.outer(m, m); attract = fm & (dist < P.raft_range) & (dist > P.body)
            vel -= P.raft_gain * (diff / dist[..., None] * attract[..., None]).sum(1) * 0.1
        mob = 1.0 / (1.0 + P.c_b * self.b); mob = np.where(m, P.foam_speed, mob)
        self.pos += vel * mob[:, None] * dt
        lim = f.L / 2 - 0.6; self.pos = np.clip(self.pos, -lim, lim)
        # bookkeeping
        self.depth = -f.sample(f.z, self.pos[:, 0], self.pos[:, 1])
        ins = self.inside()
        if P.chi and ins.any():
            self.delta = P.delta0 + P.chi * self.depth[ins].mean()
        self.R = self.depth - self.s; self.s += self.eta * (self.depth - self.s)
        # trapped / relapse
        trapped = self.R < -P.R_star
        newly = trapped & (self.trapped_since < 0); self.trapped_since[newly] = step_idx
        re = (~trapped) & (self.trapped_since >= 0) & ins
        for k in KINDS:
            self.counts["relapse"][k] += int((re & (self.kind == k) & (step_idx - self.trapped_since <= P.relapse_tau)).sum())
        self.trapped_since[re | ((self.trapped_since >= 0) & (step_idx - self.trapped_since > P.relapse_tau))] = -1
        # belief loss on the floor: long conformity drops anchors
        self.floor_dwell = np.where(ins, self.floor_dwell + 1, 0)
        drop = (self.floor_dwell >= P.belief_loss_tau) & (self.b > 0)
        if drop.any():
            self.b[drop] -= 1; self.floor_dwell[drop] = 0; self.counts["beliefs_lost"] += int(drop.sum())
            became = drop & (self.b == 0) & (self.kind == "planner"); self.kind[became] = "deep"
        # foam: waves push it under; buoyancy brings it back; held under long enough -> dissolution
        zt = np.abs(f.sample(f.z - f.zprev, self.pos[:, 0], self.pos[:, 1]) / dt)
        fm = self.kind == "foam"
        self.u[fm] += np.clip(zt[fm] - P.v_star, 0, None) * dt * 4.0
        self.u[fm] -= P.buoyancy * self.u[fm] * dt * 4.0
        self.under = np.where(fm & (self.u > P.u_dissolve), self.under + 1, 0)
        dis = fm & (self.under >= P.dissolve_tau)
        if dis.any():
            self.kind[dis] = "surface"; self.b[dis] = 0; self.s[dis] = self.depth[dis]; self.u[dis] = 0
            self.counts["foam_dissolved"] += int(dis.sum())
        # refloat: a sunk molecule with no anchors whose set-point stays unmet becomes foam with one new conviction
        self.unmet = np.where((self.kind != "foam") & (self.R < 0) & (self.b == 0), self.unmet + 1, 0)
        rf = self.unmet >= P.refloat_tau
        if rf.any():
            self.kind[rf] = "foam"; self.unmet[rf] = 0; self.s[rf] = 0; self.counts["refloated"] += int(rf.sum())
        self.history.append({"step": step_idx, "delta": float(self.delta),
                             "depth": {k: float(self.depth[self.kind == k].mean()) if (self.kind == k).any() else 0.0 for k in KINDS},
                             "R": {k: float(self.R[self.kind == k].mean()) if (self.kind == k).any() else 0.0 for k in KINDS},
                             "inside": int(ins.sum()), "outcast": int(((~ins) & (self.kind != "foam")).sum()),
                             "nfoam": int(fm.sum()), "kinds": {k: int((self.kind == k).sum()) for k in KINDS}})

    def foam_load(self):
        """Optional weight of foam on the field (foam_mass > 0)."""
        if not self.P.foam_mass:
            return None
        fm = self.kind == "foam"
        if not fm.any():
            return None
        p = np.zeros((self.f.N, self.f.N))
        for x, y in self.pos[fm]:
            p += self.f.footprint(self.P.foam_mass, 0.3, x, y)
        return p


# ----------------------------------------------------------------------------- world
class World:
    def __init__(self, field: Field, balls, mols: Molecules, physics: BallPhysics, dt=0.02, session=None, engraving=None):
        self.f, self.balls, self.mols, self.phys, self.dt = field, balls, mols, physics, dt
        self.session = session; self.t = 0.0; self.step_idx = 0
        self.engrave_load = None
        if engraving is not None:
            self.engrave_load = field.div_T_grad(engraving) - field.med.kappa * engraving
            field.z = field.z + engraving; field.zprev = field.z.copy()
        self.events = []

    def log(self, event, **kw):
        if self.session:
            with open(self.session, "a") as fh:
                fh.write(json.dumps({"t": time.time(), "sim_t": self.t, "event": event, **kw}) + "\n")

    def load(self):
        p = np.zeros((self.f.N, self.f.N))
        for b in self.balls:
            if b.alive:
                p += self.f.footprint(b.w, b.r, b.p[0], b.p[1])
        if self.engrave_load is not None: p += self.engrave_load
        fl = self.mols.foam_load() if self.mols else None
        if fl is not None: p += fl
        return p

    def predict(self, step):
        """Planner forecast: heaviest live ball, linear extrapolation of its velocity."""
        live = [b for b in self.balls if b.alive]
        b = max(live, key=lambda x: x.w)
        return b.p + b.v * (step - self.step_idx) * self.dt

    def settle(self, steps=400):
        self.f.relax(self.load(), dt=self.dt, steps=steps)

    def run(self, steps, snapshot_every=None, snapshots=None):
        for _ in range(steps):
            old = {b.name: b.p.copy() for b in self.balls if b.alive}
            ev = self.phys.step(self.balls, self.mols.pos if self.mols else None, self.dt, self.f.L, t=self.t)
            for e in ev:
                self.events.append((self.step_idx, e)); self.log(e[0], detail=e[1:])
                if e[0] == "jump":                      # splash: rebound at the vacated site
                    b = next(x for x in self.balls if x.name == e[1])
                    ox, oy = e[2]
                    self.f.zprev = self.f.z + 1.2 * (np.hypot(self.f.X - ox, self.f.Y - oy) <= b.r * 2.5) * self.f.dx
            self.f.step(self.load(), self.dt)
            if self.mols: self.mols.step(self.balls, self.predict, self.dt, self.step_idx)
            if snapshot_every and snapshots is not None and self.step_idx % snapshot_every == 0:
                snapshots.append((self.step_idx, self.f.z.copy(), self.mols.pos.copy(), self.mols.kind.copy(),
                                  [(b.p.copy(), b.r) for b in self.balls if b.alive]))
            self.t += self.dt; self.step_idx += 1
