#!/usr/bin/env python3
"""Stage 1 — per-corpus reflection check (sort invariants) + Stage 2 — the meaning sphere M.

Stage 1 invariants (from CapricornusSix/REPORT_CompareFuture_20261010): only the seed capricornus is a ^
(apex at 0.5); the rest ramp (apex ≈ 1.0); coupling rate; letter-size table.
Stage 2: PCA-3 of all embeddings → unit sphere (pooled), plus per-corpus explained variance.
"""
import os, json, collections
import numpy as np
from sklearn.decomposition import PCA
from common import log, RESULTS
from lib import (CORPORA, SPHERE, load_concepts, load_emb, load_sort, receipt_weights, save_json)


def apex_positions(cap):
    by = collections.defaultdict(list)
    for r in sorted(cap, key=lambda r: r["sort_position"]):
        if r.get("capricornus_letter"):
            by[r["capricornus_letter"]].append(r)
    out = {}
    for L, rs in by.items():
        sc = [len(r["concept_name"]) + 2 * r["concept_name"].count(" ") for r in rs]
        out[L] = round(int(np.argmax(sc)) / max(1, len(rs) - 1), 2)
    return out


def main():
    concepts = load_concepts()
    emb = load_emb()
    log(f"concepts {len(concepts)}  emb {emb.shape}")

    # ---------------- Stage 1
    inv = {}
    for corpus in CORPORA:
        cap, rec = load_sort(corpus, concepts)
        seed = next(r for r in cap if r.get("is_seed_concept"))
        ap = apex_positions(cap)
        ev = collections.Counter(r["event"] for r in rec)
        sizes = collections.Counter(r["capricornus_letter"] for r in cap if r.get("capricornus_letter"))
        w, occ, n = receipt_weights(cap, rec)
        n_c = len(cap)
        # ^ = apex in the middle of a letter with enough members to have a shape (≥5)
        caret = [L for L, a in ap.items() if 0.4 <= a <= 0.6 and sizes.get(L, 0) >= 5]
        ramp = [L for L, a in ap.items() if a >= 0.9 and sizes.get(L, 0) >= 5]
        inv[corpus] = {
            "n_concepts": n_c, "n_letters": len(sizes), "seed_letter": seed["capricornus_letter"],
            "seed_concept": seed["concept_name"], "seed_cidx": seed["cidx"],
            "seed_bucket_size": sum(1 for r in cap if r.get("in_seed_capricornus")),
            "apex_positions": ap, "letters_with_caret": caret, "letters_ramp": ramp,
            "letters_ge5": sum(1 for L in sizes if sizes[L] >= 5),
            "only_seed_is_caret": caret == [seed["capricornus_letter"]],
            "events": dict(ev),
            "coupling_rate_pct": round(100 * ev["coupling"] / max(1, ev["coupling"] + ev["mechanical_stop"]), 1),
            "coupling_share_of_receipts_pct": round(100 * ev["coupling"] / max(1, sum(ev.values())), 1),
            "receipts_per_concept": round(sum(ev.values()) / n_c, 3),
            "occluded_fraction": round(len(occ) / n_c, 3),
            "concepts_with_any_receipt_pct": round(100 * len(n) / n_c, 1),
            "letter_sizes": dict(sorted(sizes.items())),
            "flag": [],
        }
        if not inv[corpus]["only_seed_is_caret"]:
            inv[corpus]["flag"].append(f"caret letters {caret} ≠ seed only")
        if not (15 <= inv[corpus]["coupling_rate_pct"] <= 85):
            inv[corpus]["flag"].append(f"coupling rate {inv[corpus]['coupling_rate_pct']}% outside 15–85")
        log(f"{corpus:13s} n={n_c:6d} seed={seed['capricornus_letter']} caret={caret} coup={inv[corpus]['coupling_rate_pct']}% occl={inv[corpus]['occluded_fraction']} flags={inv[corpus]['flag']}")
    save_json("stage1_invariants.json", inv)

    # ---------------- Stage 2
    pca = PCA(n_components=3, random_state=0).fit(emb)
    P = pca.transform(emb)
    xyz = P / np.linalg.norm(P, axis=1, keepdims=True)
    np.save(os.path.join(SPHERE, "pooled_xyz.npy"), xyz.astype(np.float32))
    np.save(os.path.join(SPHERE, "pooled_pca3.npy"), P.astype(np.float32))
    meta = {"pooled_explained_variance": [round(float(v), 4) for v in pca.explained_variance_ratio_],
            "pooled_explained_total": round(float(pca.explained_variance_ratio_.sum()), 4),
            "radius_median": round(float(np.median(np.linalg.norm(P, axis=1))), 4),
            "per_corpus": {}}
    corp = np.array([c["corpus"] for c in concepts])
    for corpus in CORPORA:
        m = corp == corpus
        pc = PCA(n_components=3, random_state=0).fit(emb[m])
        meta["per_corpus"][corpus] = {"n": int(m.sum()),
                                      "explained_total": round(float(pc.explained_variance_ratio_.sum()), 4),
                                      "pooled_centroid": [round(float(v), 4) for v in xyz[m].mean(0)],
                                      "pooled_spread_deg": round(float(np.degrees(np.arccos(np.clip(np.linalg.norm(xyz[m].mean(0)), 0, 1)))), 2)}
    with open(os.path.join(SPHERE, "sphere.json"), "w") as f:
        json.dump(meta, f, indent=1)
    log(f"sphere: explained {meta['pooled_explained_variance']} total {meta['pooled_explained_total']}")


if __name__ == "__main__":
    main()
