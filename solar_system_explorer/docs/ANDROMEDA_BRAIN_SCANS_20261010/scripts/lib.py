#!/usr/bin/env python3
"""AndromedaBrainScans — shared loaders and sphere maths for Stages 1–9.

Everything here is agent-authored machinery; the operator's terms it implements are in GAME_PLAN.md §0.
"""
import json, os, collections
import numpy as np
from common import ROOT, CORPUS, SORTS, RESULTS, REGISTRY, read_jsonl, log

SPHERE = os.path.join(RESULTS, "sphere")
FIELDS = os.path.join(RESULTS, "fields")
for d in (SPHERE, FIELDS):
    os.makedirs(d, exist_ok=True)

CORPORA = list(REGISTRY.keys())
KAPPA_A = 200.0          # vMF concentration for field A  (~4° half-width)
NLAT, NLON = 90, 180     # 2° grid
RHO_ECHO = 0.5           # echo weight (red-shift decayed coupling)
W_COUPLING, W_ECHO, W_STOP, W_BASE = 1.0, RHO_ECHO, 0.1, 0.05


# ----------------------------------------------------------------------------- corpus
def load_concepts():
    return read_jsonl(os.path.join(CORPUS, "concepts.jsonl"))


def load_emb():
    return np.load(os.path.join(CORPUS, "embeddings.npy"))


def sort_dir(corpus):
    r = REGISTRY[corpus]
    return r.get("sort_dir") or os.path.join(SORTS, corpus)


def load_sort(corpus, concepts):
    """Return cap rows + receipts with every local idx mapped to the global cidx.

    New sorts (03_sort_corpus.py) carry cidx directly. The three pre-existing sorts are mapped by
    (segment_id, lower(concept_name)) — verified 1:1 for all three (3765 / 12768 / 12447)."""
    d = sort_dir(corpus)
    cap = read_jsonl(os.path.join(d, "capricornus.jsonl"))
    rec = read_jsonl(os.path.join(d, "receipts.jsonl"))
    idx = read_jsonl(os.path.join(d, "concept_index.jsonl"))
    if idx and "cidx" in idx[0]:
        local2c = {r["idx"]: r["cidx"] for r in idx}
    else:
        ours = collections.defaultdict(list)
        for c in concepts:
            if c["corpus"] == corpus:
                ours[(c["uid"].split(":", 1)[1], c["concept_name"].strip().lower())].append(c["cidx"])
        local2c = {}
        for r in idx:
            k = (r["segment_id"], r["concept_name"].strip().lower())
            if ours.get(k):
                local2c[r["idx"]] = ours[k].pop(0)
    # echo rows (seed references re-emitted inside other letters) are receipts, not concepts: drop from cap
    cap = [r for r in cap if not r.get("seed_reference")]
    for r in cap:
        r["cidx"] = local2c.get(r["idx"], r.get("cidx"))
    for r in rec:
        for k in ("seed_idx", "bonding_idx", "antibonding_idx"):
            if k in r:
                r[k + "_c"] = local2c.get(r[k])
    return cap, rec


def receipt_weights(cap, rec):
    """Field-B weight per cidx: receipts stamped on the concept. Seed capricornus = occluded (baseline only).
    Returns (weights dict, occluded set, receipt-count dict)."""
    w = collections.Counter()
    n = collections.Counter()
    for r in rec:
        ev = r["event"]
        s, b = r.get("seed_idx_c"), r.get("bonding_idx_c")
        if ev == "coupling":
            for c in (s, b):
                if c is not None:
                    w[c] += W_COUPLING; n[c] += 1
        elif ev == "echo":
            for c in (s, b):
                if c is not None:
                    w[c] += W_ECHO; n[c] += 1
        else:  # mechanical_stop
            if b is not None:
                w[b] += W_STOP; n[b] += 1
    seed_bucket = {r["cidx"] for r in cap if r.get("in_seed_capricornus")}
    stop_only = {c for c in n if w[c] <= W_STOP * n[c] + 1e-9}
    occluded = seed_bucket | stop_only
    return w, occluded, n


def corpus_cidx(concepts, corpus):
    return np.array([c["cidx"] for c in concepts if c["corpus"] == corpus])


# ----------------------------------------------------------------------------- sphere
def load_sphere():
    xyz = np.load(os.path.join(SPHERE, "pooled_xyz.npy"))
    meta = json.load(open(os.path.join(SPHERE, "sphere.json")))
    return xyz, meta


def grid(nlat=NLAT, nlon=NLON):
    lat = (np.arange(nlat) + 0.5) / nlat * np.pi - np.pi / 2          # -90..90
    lon = (np.arange(nlon) + 0.5) / nlon * 2 * np.pi - np.pi          # -180..180
    LON, LAT = np.meshgrid(lon, lat)
    xyz = np.stack([np.cos(LAT) * np.cos(LON), np.cos(LAT) * np.sin(LON), np.sin(LAT)], -1)
    area = np.cos(LAT) * (np.pi / nlat) * (2 * np.pi / nlon)
    return lat, lon, xyz, area


def vmf_density(points, weights, gxyz, kappa, chunk=2000):
    """Σ_i w_i · exp(κ (g·p_i)) normalised to unit mass over the sphere (by cell area)."""
    G = gxyz.reshape(-1, 3)
    out = np.zeros(len(G))
    w = np.asarray(weights, float)
    for i in range(0, len(points), chunk):
        P = points[i:i + chunk]
        out += (np.exp(kappa * (G @ P.T - 1.0)) * w[i:i + chunk]).sum(1)
    out = out.reshape(gxyz.shape[:2])
    return out


def normalise(field, area):
    m = (field * area).sum()
    return field / m if m > 0 else field


def to_latlon(xyz):
    lat = np.degrees(np.arcsin(np.clip(xyz[..., 2], -1, 1)))
    lon = np.degrees(np.arctan2(xyz[..., 1], xyz[..., 0]))
    return lat, lon


def rotmat(a, b, c):
    """ZYZ Euler rotation (radians)."""
    ca, sa, cb, sb, cc, sc = np.cos(a), np.sin(a), np.cos(b), np.sin(b), np.cos(c), np.sin(c)
    Rz1 = np.array([[ca, -sa, 0], [sa, ca, 0], [0, 0, 1]])
    Ry = np.array([[cb, 0, sb], [0, 1, 0], [-sb, 0, cb]])
    Rz2 = np.array([[cc, -sc, 0], [sc, cc, 0], [0, 0, 1]])
    return Rz1 @ Ry @ Rz2


def geodesic_deg(u, v):
    return np.degrees(np.arccos(np.clip((u * v).sum(-1), -1, 1)))


def azimuth_deg(at, toward):
    """Bearing at point `at` toward point `toward`, measured from local north (z) eastward, degrees."""
    at = at / np.linalg.norm(at); toward = toward / np.linalg.norm(toward)
    z = np.array([0, 0, 1.0])
    north = z - (z @ at) * at
    if np.linalg.norm(north) < 1e-9:
        north = np.array([1.0, 0, 0])
    north /= np.linalg.norm(north)
    east = np.cross(at, north)
    d = toward - (toward @ at) * at
    if np.linalg.norm(d) < 1e-12:
        return 0.0
    return float(np.degrees(np.arctan2(d @ east, d @ north)) % 360)


def ang_diff(a, b):
    d = (a - b + 180) % 360 - 180
    return abs(d)


# ----------------------------------------------------------------------------- plotting
def mollweide(ax, lat, lon, field, cmap="magma", title=None, vmin=None, vmax=None, contour=None, ccolor="w"):
    LON, LAT = np.meshgrid(np.radians(lon), np.radians(lat))
    im = ax.pcolormesh(LON, LAT, field, cmap=cmap, vmin=vmin, vmax=vmax, shading="auto", rasterized=True)
    if contour is not None:
        ax.contour(LON, LAT, field, levels=contour, colors=ccolor, linewidths=0.6)
    ax.set_xticks([]); ax.set_yticks([])
    ax.grid(alpha=0.15)
    if title:
        ax.set_title(title, fontsize=9)
    return im


def save_json(name, obj):
    p = os.path.join(RESULTS, name)
    with open(p, "w") as f:
        json.dump(obj, f, indent=1, default=lambda o: o.item() if hasattr(o, "item") else str(o))
    log(f"wrote {os.path.relpath(p, ROOT)}")
