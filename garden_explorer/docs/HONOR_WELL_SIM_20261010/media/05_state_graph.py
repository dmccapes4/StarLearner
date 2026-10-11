#!/usr/bin/env python
"""Segments → per show-night state-graph lines (v1 spec, PHASE5_AXES §8.4) + edges.

state/<show>.jsonl  (append-only; one line per show-date per run, tagged with run id)
  {run, date, show, network, camp, p7, a7, r7, pillar, h, n_segments, minutes, w, w_source, sources, scorer}
state/edges.jsonl   one line per show pair per shared date: horseshoe distances both ways + euclidean.
Also writes state/segment_scores/<show>.jsonl with per-segment s7/a7 (derived, rebuilt).
    python 05_state_graph.py [backend=hybrid]
"""
import json, os, sys, time, itertools
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); DATA = os.path.join(HERE, "data"); STATE = os.path.join(HERE, "state")
sys.path.insert(0, HERE)
from stance import Stance, StanceNLI, StanceHybrid, horseshoe_distance, concentration
MAN = json.load(open(os.path.join(HERE, "manifest.json")))
BACKEND = sys.argv[1] if len(sys.argv) > 1 else "hybrid"
RUN = time.strftime("%Y%m%dT%H%M%S")

if __name__ == "__main__":
    os.makedirs(os.path.join(STATE, "segment_scores"), exist_ok=True)
    st = {"nli": StanceNLI, "hybrid": StanceHybrid}.get(BACKEND, Stance)()
    ids = st.ids
    nights = {}   # (show, date) -> record
    for s in MAN["shows"]:
        path = os.path.join(DATA, "segments", f"{s['show']}.jsonl")
        if not os.path.exists(path): continue
        segs = [json.loads(l) for l in open(path) if l.strip()]
        if not segs: continue
        S, A = st.score([x["text"] for x in segs])
        with open(os.path.join(STATE, "segment_scores", f"{s['show']}.jsonl"), "w") as f:
            for x, sv, av in zip(segs, S, A):
                f.write(json.dumps({**{k: x[k] for k in ("date", "video_id", "t0", "t1")}, "s7": np.round(sv, 3).tolist(), "a7": np.round(av, 3).tolist()}) + "\n")
        meta = {}
        for l in open(os.path.join(DATA, s["show"], "meta.jsonl")):
            if l.strip(): r = json.loads(l); meta[r["id"]] = r
        for date in sorted({x["date"] for x in segs}):
            idx = [i for i, x in enumerate(segs) if x["date"] == date]
            p, r, att = st.aggregate(S[idx], A[idx])
            vids = sorted({segs[i]["video_id"] for i in idx})
            views = [meta[v].get("view_count") for v in vids if meta.get(v, {}).get("view_count") is not None]
            rec = {"run": RUN, "date": date, "show": s["show"], "network": s["network"], "camp": s["camp"],
                   "p7": np.round(p, 3).tolist(), "a7": np.round(att, 3).tolist(), "r7": np.round(r, 3).tolist(),
                   "pillar": ids[int(att.argmax())], "h": round(concentration(att), 3),
                   "n_segments": len(idx), "minutes": round(sum(segs[i]["t1"] - segs[i]["t0"] for i in idx) / 60, 1),
                   "w": int(sum(views)) if views else None, "w_source": "youtube_view_count_sum",
                   "sources": [{"id": v, "title": meta[v]["title"][:80], "transcript": segs[[i for i in idx if segs[i]["video_id"] == v][0]]["source"]} for v in vids],
                   "scorer": BACKEND, "axes": ids}
            nights[(s["show"], date)] = rec
            with open(os.path.join(STATE, f"{s['show']}.jsonl"), "a") as f:
                f.write(json.dumps(rec) + "\n")
            print(f"{s['show']} {date}: n={len(idx):3d} p7={np.round(p,2).tolist()} pillar={rec['pillar']} h={rec['h']} w={rec['w']}")
    # edges on shared dates
    with open(os.path.join(STATE, "edges.jsonl"), "a") as f:
        for (sa, da), (sb, db) in itertools.combinations(sorted(nights), 2):
            if da != db or sa == sb: continue
            A_, B_ = nights[(sa, da)], nights[(sb, db)]
            pa, pb = np.array(A_["p7"]), np.array(B_["p7"])
            e = {"run": RUN, "date": da, "a": sa, "b": sb, "d_euclid": round(float(np.linalg.norm(pa - pb)), 3),
                 "d_a_sees_b": round(horseshoe_distance(np.array(A_["a7"]), pa, pb), 3),
                 "d_b_sees_a": round(horseshoe_distance(np.array(B_["a7"]), pb, pa), 3), "same_camp": A_["camp"] == B_["camp"]}
            f.write(json.dumps(e) + "\n"); print("edge", e["date"], sa, "↔", sb, "euclid", e["d_euclid"], "a→b", e["d_a_sees_b"], "b→a", e["d_b_sees_a"])
