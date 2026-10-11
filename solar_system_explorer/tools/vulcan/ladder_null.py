#!/usr/bin/env python3
"""
ladder_null.py — permutation null for the ladder test.

How many (line, metric, hypothesis) holds (< 0.30 dex) would a RANDOM
ladder of the same shape produce, drawing entities at random from the same
pool? If the user's ladder does not beat this, the proportions it asserts
carry no information beyond the spread of the metrics themselves.
"""
import os, json, math, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib.util
HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.abspath(os.path.join(HERE, "..", "..", "docs", "MERCURY_VULCAN_LADDER_20261010", "data"))
LA = json.load(open(os.path.join(DATA, "ladder_analysis.json")))
E = LA["entities"]
METRICS = ["mass_kg", "radius_km", "a_au", "period_yr", "rot_d", "density", "a_local_km"]
pool = [k for k in E if k != "planet_x"]

def lg(x):
    try:
        x = float(x)
    except (TypeError, ValueError):
        return None
    return math.log10(abs(x)) if x not in (0.0,) else None
def rd(a, b, m):
    va, vb = lg(E[a].get(m)), lg(E[b].get(m))
    return None if (va is None or vb is None) else va - vb
def count_holds(ladder):
    n = 0; tot = 0
    for t1, t2 in ladder:
        for m in METRICS:
            r1, r2, s1, s2 = rd(t1[0], t1[1], m), rd(t1[1], t1[2], m), rd(t2[0], t2[1], m), rd(t2[1], t2[2], m)
            for v in ((r1 - r2) if None not in (r1, r2) else None, (s1 - s2) if None not in (s1, s2) else None,
                      (r1 - s1) if None not in (r1, s1) else None, (r1 + s1) if None not in (r1, s1) else None):
                if v is not None:
                    tot += 1
                    if abs(v) < 0.30: n += 1
    return n, tot

user_ladder = [(r["id"], r["iv"]) for r in LA["ladder_results"] if "planet_x" not in r["iv"]]
n_user, tot_user = count_holds(user_ladder)
random.seed(7)
null = []
for _ in range(4000):
    lad = []
    for _l in range(len(user_ladder)):
        a = random.sample(pool, 3); b = random.sample(pool, 3)
        lad.append((a, b))
    n, tot = count_holds(lad)
    null.append(n / max(tot, 1))
rate_user = n_user / tot_user
null.sort()
p_ge = sum(1 for x in null if x >= rate_user) / len(null)
mean_null = sum(null) / len(null)
out = dict(user_holds=n_user, user_tests=tot_user, user_rate=rate_user, null_mean_rate=mean_null,
           null_p05=null[int(0.05 * len(null))], null_p95=null[int(0.95 * len(null))], p_value_user_ge_null=p_ge,
           note="Rate of |residual| < 0.30 dex among all evaluable (line, metric, hypothesis) tests, 7 lines excluding the Planet X line. "
                "p = fraction of 4000 random ladders with a hold rate >= the user's.")
json.dump(out, open(os.path.join(DATA, "ladder_null.json"), "w"), indent=1)
print(out)
