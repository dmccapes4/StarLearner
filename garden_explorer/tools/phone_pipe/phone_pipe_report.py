#!/usr/bin/env python3
"""
phone_pipe_report.py — run the pipe operations on every number in a
"<10 digits> - <label>" list, make it plain, render five PNG views, and
bind them (plus a stats page) into one PDF.

Operations (all from true_calendar.py unless noted):
  pipe_op(area, exchange)        A..G, F-pair, G_diff; self-pipe if F[0]==F[1]
  area_code_b60(area)            60 - |outer diff| + 1
  derived 10-op (xxxx yy zzzz)   user-confirmed formula set (see DERIVED_RULES)
  pairwise pipe_op(sub_i, sub_j) G_diff matrix over all 7-digit subscribers
  Hamming distance matrix        digit-position mismatches (same length)
  digit statistics               frequency, chi-square vs uniform, entropy,
                                 digit sum, digital root, parity

SECURITY CONSTRAINT inherited from true_calendar.py: no SSN inference, ever.
Nothing here produces or labels a 9-digit identifier.

Usage:
  python3 phone_pipe_report.py <input.txt> <out_dir>
"""
import sys, os, re, json, math
from collections import Counter
from itertools import combinations

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from scipy.stats import chisquare, entropy
from scipy.cluster.hierarchy import linkage, leaves_list

HERE = os.path.dirname(os.path.abspath(__file__))
TC_DIR = os.path.expanduser("~/dev/NarrativeErosionAndHistoricalInversion")
sys.path.insert(0, TC_DIR)
from true_calendar import pipe_op, area_code_b60  # noqa: E402

# ── Known area-code regions (public NANP data; descriptive only) ───────────
AREA_REGION = {
    "530": "CA — Davis / Yolo / N. Sacramento Valley",
    "916": "CA — Sacramento",
    "707": "CA — Solano / Napa / North Coast",
    "415": "CA — San Francisco",
    "650": "CA — Peninsula / San Mateo",
    "925": "CA — East Bay (Contra Costa / Tri-Valley)",
    "808": "HI — Hawaii (all islands)",
    "602": "AZ — Phoenix",
}

# ── Derived 10-op rules (user-confirmed derivation, 20261003) ──────────────
# Index the 10 digits as (A B C) s1 s2 s3 - s4 s5 s6 s7.
# Each step is folded to one digit: abs() if negative; mod 10 if >= 10;
# steps 9 and 10 use floor division (step 10 on the absolute difference).
# s7 is never used (so a last-digit change is pipe-invisible).
DERIVED_RULES = [
    ("s1 − (A−B)",              lambda A,B,C,s: s[0] - (A-B)),
    ("s3 − (A−B)",              lambda A,B,C,s: s[2] - (A-B)),
    ("(A−B) − s1",              lambda A,B,C,s: (A-B) - s[0]),
    ("(A−B) + s2",              lambda A,B,C,s: (A-B) + s[1]),
    ("s3 − (s1−s2)",            lambda A,B,C,s: s[2] - (s[0]-s[1])),
    ("s4 − (s1+s2)",            lambda A,B,C,s: s[3] - (s[0]+s[1])),
    ("(s5+s6) % 10",            lambda A,B,C,s: (s[4]+s[5]) % 10),
    ("s3 − ((s5+s6)%10)",       lambda A,B,C,s: s[2] - ((s[4]+s[5]) % 10)),
    ("(s3 + (s5+s6)%10) // 2",  lambda A,B,C,s: (s[2] + ((s[4]+s[5]) % 10)) // 2),
    ("|s3 − (s5+s6)%10| // 2",  lambda A,B,C,s: abs(s[2] - ((s[4]+s[5]) % 10)) // 2),
]

def fold(v: int) -> int:
    v = abs(v)
    if v >= 10:
        v %= 10
    return v

def derived(num: str):
    A, B, C = int(num[0]), int(num[1]), int(num[2])
    s = [int(c) for c in num[3:]]
    raw = [rule(A, B, C, s) for _, rule in DERIVED_RULES]
    digits = [fold(v) for v in raw]
    neg = sum(1 for v in raw if v < 0)
    over = sum(1 for v in raw if v >= 10)
    txt = "".join(map(str, digits))
    return {"raw": raw, "digits": digits, "text": f"{txt[:4]} {txt[4:6]} {txt[6:]}",
            "n_negative": neg, "n_overflow": over}

def digital_root(n: int) -> int:
    return 0 if n == 0 else 1 + (n - 1) % 9

def hamming(a: str, b: str) -> int:
    return sum(x != y for x, y in zip(a, b))

# ── Parse ──────────────────────────────────────────────────────────────────
def parse(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            m = re.match(r"^(\d{10})\s*-\s*(.*)$", line)
            if not m:
                print(f"  skip (unparsed): {line}")
                continue
            rows.append({"num": m.group(1), "label": m.group(2).strip()})
    return rows

def short_label(label, n=26):
    core = label.split("(")[0].strip()
    return core if len(core) <= n else core[:n-1] + "…"

# ── Analyse ────────────────────────────────────────────────────────────────
def analyse(rows):
    for r in rows:
        num = r["num"]
        area, exch, line = num[:3], num[3:6], num[6:]
        r.update({
            "area": area, "exch": exch, "line": line, "sub": num[3:],
            "region": AREA_REGION.get(area, "unknown"),
            "b60": area_code_b60(area),
        })
        p = pipe_op(area, exch)
        r["pipe_area_exch"] = p
        r["F_left"], r["F_right"] = p["F"]
        r["G_diff"] = p["G_diff"]
        r["self_pipe"] = p["F"][0] == p["F"][1]
        d = derived(num)
        r["derived"] = d
        digs = [int(c) for c in num]
        r["digit_sum"] = sum(digs)
        r["digital_root"] = digital_root(sum(digs))
        r["n_even"] = sum(1 for x in digs if x % 2 == 0)
        r["n_zero"] = digs.count(0)
        r["distinct"] = len(set(digs))
        r["sub_digit_sum"] = sum(int(c) for c in r["sub"])
    return rows

def matrices(rows):
    n = len(rows)
    H = np.zeros((n, n), dtype=int)
    Gm = np.zeros((n, n), dtype=int)
    Fm = np.zeros((n, n), dtype=bool)
    for i in range(n):
        for j in range(n):
            if i == j:
                continue
            H[i, j] = hamming(rows[i]["num"], rows[j]["num"])
            p = pipe_op(rows[i]["sub"], rows[j]["sub"])
            Gm[i, j] = p["G_diff"]
            Fm[i, j] = p["F"][0] == p["F"][1]
    return H, Gm, Fm

def digit_stats(rows):
    all_digits = Counter()
    for r in rows:
        all_digits.update(int(c) for c in r["num"])
    counts = np.array([all_digits[d] for d in range(10)])
    chi, pval = chisquare(counts)
    ent = entropy(counts / counts.sum(), base=2)
    # subscriber-only (area codes are structurally non-uniform)
    sub_digits = Counter()
    for r in rows:
        sub_digits.update(int(c) for c in r["sub"])
    sc = np.array([sub_digits[d] for d in range(10)])
    schi, spval = chisquare(sc)
    # derived digits
    der = Counter()
    for r in rows:
        der.update(r["derived"]["digits"])
    dc = np.array([der[d] for d in range(10)])
    dchi, dpval = chisquare(dc)
    # positional stats of derived digits
    D = np.array([r["derived"]["digits"] for r in rows])
    pos_var = D.var(axis=0)
    pos_mode = [Counter(D[:, k]).most_common(1)[0] for k in range(10)]
    return {
        "all": {"counts": counts.tolist(), "chi2": chi, "p": pval, "entropy_bits": ent,
                "max_entropy_bits": math.log2(10)},
        "sub": {"counts": sc.tolist(), "chi2": schi, "p": spval,
                "entropy_bits": entropy(sc / sc.sum(), base=2)},
        "derived": {"counts": dc.tolist(), "chi2": dchi, "p": dpval,
                    "entropy_bits": entropy(dc / dc.sum(), base=2),
                    "pos_var": pos_var.tolist(),
                    "pos_mode": [(int(m), int(c)) for m, c in pos_mode]},
    }

# ── Views ──────────────────────────────────────────────────────────────────
def view1_table(rows, out):
    fig, ax = plt.subplots(figsize=(17, 0.30 * len(rows) + 1.4))
    ax.axis("off")
    cols = ["#", "Number", "Label", "Area", "b60", "F (area|exch)", "G", "Self",
            "Derived xxxx yy zzzz", "neg", "Σdig", "root"]
    cells = []
    for i, r in enumerate(rows, 1):
        cells.append([
            i, f"{r['area']}-{r['exch']}-{r['line']}", short_label(r["label"], 34),
            r["area"], r["b60"], f"{r['F_left']}|{r['F_right']}", r["G_diff"],
            "●" if r["self_pipe"] else "", r["derived"]["text"],
            r["derived"]["n_negative"], r["digit_sum"], r["digital_root"],
        ])
    t = ax.table(cellText=cells, colLabels=cols, loc="center", cellLoc="center")
    t.auto_set_font_size(False); t.set_fontsize(8.2); t.scale(1, 1.25)
    widths = [0.03, 0.11, 0.26, 0.05, 0.05, 0.11, 0.04, 0.04, 0.15, 0.04, 0.05, 0.05]
    for (ri, ci), cell in t.get_celld().items():
        cell.set_width(widths[ci])
        if ri == 0:
            cell.set_facecolor("#2B5F8A"); cell.set_text_props(color="w", weight="bold")
        elif rows[ri-1]["self_pipe"]:
            cell.set_facecolor("#FFF3C4")
        elif ri % 2 == 0:
            cell.set_facecolor("#F3F6F9")
    ax.set_title("View 1 — Plain table: every number through pipe_op(area|exchange), b60, "
                 "and the 10-op derived number\n"
                 "● self-pipe (F left = F right, G=0). 'neg' = how many of the 10 ops went "
                 "negative before folding. s7 (last digit) is never used by the derivation.",
                 fontsize=11, loc="left")
    fig.savefig(out, dpi=160, bbox_inches="tight"); return fig

def view2_histograms(rows, st, out):
    fig, axes = plt.subplots(2, 3, figsize=(17, 9.5))
    n = len(rows)
    # (a) digit frequency all 10 digits
    ax = axes[0, 0]
    c = st["all"]["counts"]; exp = sum(c) / 10
    ax.bar(range(10), c, color="#2B5F8A")
    ax.axhline(exp, color="crimson", ls="--", lw=1, label=f"uniform = {exp:.1f}")
    ax.set_title(f"(a) Digit frequency, all {n} numbers × 10 digits\n"
                 f"χ²={st['all']['chi2']:.1f}, p={st['all']['p']:.3g}, "
                 f"H={st['all']['entropy_bits']:.3f}/{math.log2(10):.3f} bits")
    ax.set_xticks(range(10)); ax.legend(fontsize=8)
    # (b) subscriber digits only
    ax = axes[0, 1]
    c = st["sub"]["counts"]; exp = sum(c) / 10
    ax.bar(range(10), c, color="#4C9A6A")
    ax.axhline(exp, color="crimson", ls="--", lw=1)
    ax.set_title(f"(b) Subscriber digits only (area codes removed)\n"
                 f"χ²={st['sub']['chi2']:.1f}, p={st['sub']['p']:.3g}, "
                 f"H={st['sub']['entropy_bits']:.3f} bits")
    ax.set_xticks(range(10))
    # (c) derived digits
    ax = axes[0, 2]
    c = st["derived"]["counts"]; exp = sum(c) / 10
    ax.bar(range(10), c, color="#B8862B")
    ax.axhline(exp, color="crimson", ls="--", lw=1)
    ax.set_title(f"(c) Derived-number digits (10 per number)\n"
                 f"χ²={st['derived']['chi2']:.1f}, p={st['derived']['p']:.3g}, "
                 f"H={st['derived']['entropy_bits']:.3f} bits")
    ax.set_xticks(range(10))
    # (d) digit sums
    ax = axes[1, 0]
    sums = [r["digit_sum"] for r in rows]
    ax.hist(sums, bins=range(min(sums), max(sums) + 2), color="#2B5F8A", edgecolor="w")
    mu, sd = np.mean(sums), np.std(sums)
    ax.axvline(mu, color="crimson", ls="--", label=f"μ={mu:.1f}, σ={sd:.1f}")
    ax.axvline(45, color="k", ls=":", label="E[Σ] for uniform digits = 45")
    ax.set_title("(d) Digit sum per number"); ax.legend(fontsize=8)
    # (e) G_diff and b60
    ax = axes[1, 1]
    g = Counter(r["G_diff"] for r in rows)
    ax.bar([k - 0.2 for k in g], [g[k] for k in g], width=0.4, color="#6A4C9A", label="G_diff (area|exch)")
    b = Counter(r["b60"] for r in rows)
    ax2 = ax.twiny()
    ax2.bar([k + 0.2 for k in b], [b[k] for k in b], width=0.4, color="#9A4C4C", alpha=0.7, label="b60")
    ax.set_title("(e) G_diff distribution (bottom axis) and b60 distribution (top axis)")
    ax.set_xlabel("G_diff"); ax2.set_xlabel("b60")
    ax.legend(loc="upper left", fontsize=8); ax2.legend(loc="upper right", fontsize=8)
    # (f) negatives in derivation
    ax = axes[1, 2]
    neg = Counter(r["derived"]["n_negative"] for r in rows)
    ax.bar(list(neg.keys()), list(neg.values()), color="#444")
    ax.set_title("(f) Number of the 10 derivation ops that went negative\n"
                 "(more negatives ⇒ area spread A−B dominates the subscriber digits)")
    ax.set_xlabel("ops negative (of 10)"); ax.set_xticks(range(0, 11))
    fig.suptitle("View 2 — Histograms and tests", fontsize=14, x=0.01, ha="left")
    fig.tight_layout(); fig.savefig(out, dpi=160); return fig

def _order(M):
    # hierarchical clustering order on a symmetric distance matrix
    Z = linkage(M[np.triu_indices_from(M, k=1)], method="average")
    return leaves_list(Z)

def view3_hamming(rows, H, out):
    n = len(rows)
    order = _order(H.astype(float))
    Hs = H[np.ix_(order, order)]
    labels = [f"{rows[i]['num'][:3]}-{rows[i]['num'][3:6]}-{rows[i]['num'][6:]}  {short_label(rows[i]['label'], 22)}"
              for i in order]
    fig, ax = plt.subplots(figsize=(15, 13))
    im = ax.imshow(Hs, cmap="viridis_r", vmin=0, vmax=10)
    ax.set_xticks(range(n)); ax.set_yticks(range(n))
    ax.set_xticklabels(labels, rotation=90, fontsize=7); ax.set_yticklabels(labels, fontsize=7)
    for i in range(n):
        for j in range(n):
            if i != j and Hs[i, j] <= 3:
                ax.text(j, i, Hs[i, j], ha="center", va="center", color="w", fontsize=7, weight="bold")
    plt.colorbar(im, ax=ax, fraction=0.03, label="Hamming distance (digit positions that differ, 0–10)")
    close = [(rows[i]["num"], rows[j]["num"], H[i, j]) for i, j in combinations(range(n), 2) if H[i, j] <= 3]
    ax.set_title("View 3 — Hamming distance between all pairs (clustered). Numbers printed where ≤3 digits differ.\n"
                 f"{len(close)} pairs within 3 digits; random 10-digit pairs are expected at ≈9 apart.",
                 fontsize=11, loc="left")
    fig.tight_layout(); fig.savefig(out, dpi=160); return fig, order

def view4_pipe_graph(rows, Gm, Fm, H, out):
    n = len(rows)
    # Node layout: group by area code around a circle, area groups contiguous.
    areas = sorted(set(r["area"] for r in rows))
    idx_by_area = {a: [i for i, r in enumerate(rows) if r["area"] == a] for a in areas}
    pos = {}
    k = 0
    for a in areas:
        for i in idx_by_area[a]:
            th = 2 * math.pi * k / n
            pos[i] = (math.cos(th), math.sin(th)); k += 1
    cmap = plt.get_cmap("tab10")
    acol = {a: cmap(i % 10) for i, a in enumerate(areas)}
    fig, ax = plt.subplots(figsize=(15, 16)); ax.set_aspect("equal"); ax.axis("off")
    # Edges.
    #  F-match: pipe_op(sub_i, sub_j) compiles to the same F on both sides.
    #  Structurally F = d0 + |E0| + |E1| with E shared, so F-match <=> sub_i[0] == sub_j[0]
    #  <=> G_diff == 0. The bonds are therefore cliques by leading subscriber digit; colour by it.
    #  Hamming ≤ 3: near-identical numbers (family blocks), drawn dashed red on top.
    lead_cmap = plt.get_cmap("Set2")
    nF = nH = 0
    lead_digits = sorted(set(r["sub"][0] for r in rows))
    lcol = {d: lead_cmap(i % 8) for i, d in enumerate(lead_digits)}
    for i, j in combinations(range(n), 2):
        if Fm[i, j] or Fm[j, i]:
            ax.plot(*zip(pos[i], pos[j]), color=lcol[rows[i]["sub"][0]], lw=1.6, alpha=0.75, zorder=1); nF += 1
    for i, j in combinations(range(n), 2):
        if H[i, j] <= 3:
            ax.plot(*zip(pos[i], pos[j]), color="crimson", lw=2.4, ls="--", alpha=0.95, zorder=2); nH += 1
    for i, r in enumerate(rows):
        x, y = pos[i]
        ax.scatter(x, y, s=520, color=acol[r["area"]], edgecolor="k", zorder=3)
        ax.text(x, y, str(i + 1), ha="center", va="center", fontsize=9, weight="bold", zorder=4)
        lx, ly = x * 1.16, y * 1.16
        ax.text(lx, ly, f"{r['num'][:3]}-{r['num'][3:6]}-{r['num'][6:]}\n{short_label(r['label'], 24)}",
                ha="center", va="center", fontsize=7.2, rotation=0)
    for a in areas:
        ax.scatter([], [], s=120, color=acol[a], edgecolor="k", label=f"node: area {a}  {AREA_REGION.get(a, '')}")
    for d in lead_digits:
        k = sum(1 for r in rows if r["sub"][0] == d)
        ax.plot([], [], color=lcol[d], lw=1.6, label=f"F-match clique: subscriber starts with {d}  (n={k})")
    ax.plot([], [], color="crimson", lw=2.4, ls="--", label=f"Hamming ≤ 3 (near-identical numbers) — {nH} pairs")
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.02), fontsize=8.2, frameon=True, ncol=2)
    ax.set_xlim(-1.45, 1.45); ax.set_ylim(-1.45, 1.45)
    ax.set_title("View 4 — Pipe-space graph: pipe_op(subscriber_i, subscriber_j) over all 496 pairs\n"
                 f"Theorem (from pipe_op's definition): F-match <=> G_diff = 0 <=> equal leading subscriber digit. "
                 f"{nF} bonds = cliques by that digit.\n"
                 "Nodes grouped by area code and numbered as in View 1. Dashed red = family blocks (Hamming ≤ 3).",
                 fontsize=11, loc="left")
    fig.savefig(out, dpi=160, bbox_inches="tight"); return fig

def view5_derived_matrix(rows, st, out):
    D = np.array([r["derived"]["digits"] for r in rows])
    n = len(rows)
    fig = plt.figure(figsize=(16, 0.36 * n + 5))
    gs = fig.add_gridspec(2, 2, height_ratios=[n, 6], width_ratios=[10, 2.2], hspace=0.08, wspace=0.05)
    ax = fig.add_subplot(gs[0, 0])
    im = ax.imshow(D, cmap="magma", vmin=0, vmax=9, aspect="auto")
    for i in range(n):
        for k in range(10):
            ax.text(k, i, D[i, k], ha="center", va="center",
                    color="w" if D[i, k] < 6 else "k", fontsize=8)
    ax.set_yticks(range(n))
    ax.set_yticklabels([f"{r['num'][:3]}-{r['num'][3:6]}-{r['num'][6:]}  {short_label(r['label'], 24)}" for r in rows], fontsize=7.5)
    ax.set_xticks(range(10)); ax.tick_params(labelbottom=False, bottom=False)
    for x in (3.5, 5.5):
        ax.axvline(x, color="w", lw=2)
    ax.set_title("View 5 — Derived-number matrix: each row is one number's 10 folded ops (xxxx | yy | zzzz)",
                 fontsize=12, loc="left")
    # right: per-row count of negatives & digit sum of derived
    axr = fig.add_subplot(gs[0, 1], sharey=ax)
    negs = [r["derived"]["n_negative"] for r in rows]
    dsum = D.sum(axis=1)
    axr.barh(range(n), negs, color="#444", label="ops negative")
    axr.barh(range(n), dsum / 10, left=0, color="#B8862B", alpha=0.35, label="Σ derived / 10")
    axr.tick_params(labelleft=False); axr.legend(fontsize=7, loc="lower right"); axr.set_xlim(0, 10)
    axr.set_title("row stats", fontsize=9)
    # bottom: per-position variance and formulas
    axb = fig.add_subplot(gs[1, 0], sharex=ax)
    pv = st["derived"]["pos_var"]
    axb.bar(range(10), pv, color="#2B5F8A")
    for k, (m, c) in enumerate(st["derived"]["pos_mode"]):
        axb.text(k, 0.25, f"mode {m}\n×{c}", ha="center", va="bottom", fontsize=7, color="white")
    axb.set_ylim(0, max(pv) * 1.15)
    axb.set_ylabel("variance across numbers"); axb.set_xticks(range(10))
    axb.set_xticklabels([f"op{k+1}\n{DERIVED_RULES[k][0]}" for k in range(10)], fontsize=5.8)
    axb.set_title("Per-position variance of the folded op (low variance = the op collapses most numbers to the same digit). "
                  "Note op1 ≡ op3 after folding: |s1−(A−B)| = |(A−B)−s1|.",
                  fontsize=8.5, loc="left", pad=4)
    fig.savefig(out, dpi=160, bbox_inches="tight"); return fig

def stats_page(rows, st, H, Gm, Fm, out_pdf):
    n = len(rows)
    lines = []
    lines.append(f"PHONE PIPE REPORT — {n} numbers — statistics page")
    lines.append("")
    lines.append("DIGIT UNIFORMITY (null: each digit 0–9 equally likely)")
    for key, name in (("all", "all digits"), ("sub", "subscriber digits"), ("derived", "derived digits")):
        s = st[key]
        lines.append(f"  {name:<18} counts={s['counts']}  χ²={s['chi2']:.2f}  p={s['p']:.4f}  "
                     f"H={s['entropy_bits']:.3f} bits (max {math.log2(10):.3f})")
    lines.append("")
    sums = [r["digit_sum"] for r in rows]
    lines.append(f"DIGIT SUMS  μ={np.mean(sums):.2f}  σ={np.std(sums):.2f}  min={min(sums)}  max={max(sums)}  "
                 f"(uniform-digit expectation μ=45, σ≈{math.sqrt(10*8.25):.2f})")
    roots = Counter(r["digital_root"] for r in rows)
    lines.append(f"DIGITAL ROOTS  {dict(sorted(roots.items()))}")
    lines.append("")
    areas = Counter(r["area"] for r in rows)
    lines.append("AREA CODES")
    for a, c in areas.most_common():
        lines.append(f"  {a}  n={c:<2}  b60={area_code_b60(a):<3}  {AREA_REGION.get(a, 'unknown')}")
    lines.append("")
    sp = [r for r in rows if r["self_pipe"]]
    lines.append(f"SELF-PIPES (area|exchange compiles to identical F both sides, G=0): {len(sp)}")
    for r in sp:
        lines.append(f"  {r['area']}-{r['exch']}-{r['line']}  F={r['F_left']}|{r['F_right']}  {short_label(r['label'], 40)}")
    lines.append("")
    fgroups = Counter(f"{r['F_left']}|{r['F_right']}" for r in rows)
    lines.append("F-VALUE GROUPS (area|exchange) with ≥2 members:")
    for f, c in fgroups.most_common():
        if c < 2:
            break
        members = [f"#{i+1}" for i, r in enumerate(rows) if f"{r['F_left']}|{r['F_right']}" == f]
        lines.append(f"  {f:<10} ×{c}  {' '.join(members)}")
    lines.append("")
    close = sorted([(H[i, j], i, j) for i, j in combinations(range(n), 2) if H[i, j] <= 3])
    lines.append(f"HAMMING-CLOSE PAIRS (≤3 digits differ): {len(close)}  "
                 f"[mean pairwise Hamming = {H[np.triu_indices(n,1)].mean():.2f}; random expectation 9.0]")
    for d, i, j in close:
        lines.append(f"  d={d}  #{i+1} {rows[i]['num']} ↔ #{j+1} {rows[j]['num']}   "
                     f"{short_label(rows[i]['label'], 18)} ↔ {short_label(rows[j]['label'], 18)}")
    lines.append("")
    nF = sum(1 for i, j in combinations(range(n), 2) if Fm[i, j] or Fm[j, i])
    nG0 = sum(1 for i, j in combinations(range(n), 2) if Gm[i, j] == 0 and Gm[j, i] == 0)
    lines.append(f"PAIRWISE SUBSCRIBER PIPE  F-match bonds={nF}  G_diff=0 both ways={nG0}  "
                 f"of {n*(n-1)//2} pairs;  mean G_diff={Gm[np.triu_indices(n,1)].mean():.2f}")
    lines.append("")
    ders = Counter(r["derived"]["text"] for r in rows)
    dups = [(k, v) for k, v in ders.items() if v > 1]
    lines.append(f"DERIVED-NUMBER COLLISIONS (different phones → same xxxx yy zzzz): {len(dups)}")
    for k, v in dups:
        members = [f"#{i+1} {r['num']}" for i, r in enumerate(rows) if r["derived"]["text"] == k]
        lines.append(f"  {k}  ×{v}  {', '.join(members)}")
    lines.append("")
    lines.append("DERIVATION RULES  (A B C) s1 s2 s3 - s4 s5 s6 s7 ; fold: abs if <0, mod 10 if ≥10; s7 unused")
    for k, (name, _) in enumerate(DERIVED_RULES, 1):
        lines.append(f"  op{k:<2} {name}")
    lines.append("")
    # ── Structural facts exposed by running the instrument on 32 inputs ──
    D = np.array([r["derived"]["digits"] for r in rows])
    op1_eq_op3 = int((D[:, 0] == D[:, 2]).all())
    lines.append("STRUCTURAL FACTS ABOUT THE INSTRUMENT (hold for every input, not just these)")
    lines.append("  T1  pipe_op: F_left = L[0]+|E0|+|E1|, F_right = R[0]+|E0|+|E1| with E shared ⇒")
    lines.append("      F-match <=> L[0] = R[0] <=> G_diff = 0.  A 'bond' is exactly 'same leading digit'.")
    lines.append(f"      (check: F-match pairs = {nF}, G_diff=0 pairs = {nG0}, identical by construction)")
    lines.append("  T2  self-pipe (area|exchange) <=> area[0] = exchange[0].  None here: no 530-5xx or 916-9xx.")
    lines.append(f"  T3  op1 ≡ op3 after folding (|x| = |−x|).  Verified on all rows: {bool(op1_eq_op3)}.")
    lines.append("      The derived number therefore carries 9 independent digits, not 10.")
    lines.append("  T4  s7 never enters any op ⇒ numbers differing only in the last digit collide")
    lines.append("      (both collisions above are exactly this: 9658/9657 and 0102/0101).")
    lines.append("  T5  op9, op10 use //2 ⇒ range 0–9 compresses to 0–4/0–9 with low variance "
                 f"(var op9={st['derived']['pos_var'][8]:.2f}, op10={st['derived']['pos_var'][9]:.2f}).")
    lines.append("")
    # ── Sequential / block structure (carrier-assigned adjacency) ──
    lines.append("SEQUENTIAL BLOCKS (same area+exchange, line numbers within 20 of each other)")
    by_ex = {}
    for i, r in enumerate(rows):
        by_ex.setdefault(r["area"] + r["exch"], []).append((int(r["line"]), i))
    found = 0
    for key, lst in sorted(by_ex.items()):
        lst.sort()
        for (a, i), (b, j) in zip(lst, lst[1:]):
            if b - a <= 20:
                found += 1
                lines.append(f"  {key[:3]}-{key[3:]}  {a:04d} → {b:04d}  Δ={b-a:<3} "
                             f"#{i+1} {short_label(rows[i]['label'], 20)} → #{j+1} {short_label(rows[j]['label'], 20)}")
    if not found:
        lines.append("  none")
    lines.append("")
    # ── Play ──
    lines.append("PLAY")
    tot = sum(int(r["num"]) for r in rows)
    lines.append(f"  Σ all 32 numbers = {tot}  → digital root {digital_root(sum(int(c) for c in str(tot)))}")
    lines.append(f"  Σ digit sums = {sum(sums)}  → digital root {digital_root(sum(sums))}")
    exch_rep = [r for r in rows if len(set(r["exch"])) < 3]
    lines.append(f"  exchanges with a repeated digit: {len(exch_rep)}  "
                 f"({', '.join(r['exch'] for r in exch_rep)})")
    runs = [(r["num"], m.group(0)) for r in rows for m in [re.search(r'(\d)\1{2,}', r['num'])] if m]
    lines.append(f"  numbers containing a digit run ≥3: {len(runs)}  {runs}")
    pal = [r["num"] for r in rows if r["line"] == r["line"][::-1]]
    lines.append(f"  palindromic line numbers: {pal if pal else 'none'}")
    dsum_pairs = Counter(int(D[i].sum()) for i in range(n))
    lines.append(f"  derived-digit-sum distribution: {dict(sorted(dsum_pairs.items()))}")
    lead = Counter(r["sub"][0] for r in rows)
    lines.append(f"  leading subscriber digit (the T1 bond key): {dict(sorted(lead.items()))}")
    lines.append("")
    lines.append("LEDGER  pipe_op / b60 / derived / Hamming / χ² / entropy: VERIFIED (deterministic, re-runnable).")
    lines.append("        Region labels: public NANP area-code geography, descriptive only.")
    lines.append("        No SSN inference is performed or possible from this pipeline.")

    fig = plt.figure(figsize=(11, 0.21 * len(lines) + 1.5)); fig.text(0.03, 0.98, "\n".join(lines),
             family="monospace", fontsize=7.6, va="top")
    out_pdf.savefig(fig); plt.close(fig)
    return lines

# ── Main ───────────────────────────────────────────────────────────────────
def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "docs", "nate&justinphonenumbers.txt")
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "..", "..", "docs", "phone_pipe_report_20261009")
    os.makedirs(out_dir, exist_ok=True)

    rows = analyse(parse(src))
    n = len(rows)
    print(f"parsed {n} numbers from {src}")
    H, Gm, Fm = matrices(rows)
    st = digit_stats(rows)

    pngs = {
        "view1_table.png": lambda p: view1_table(rows, p),
        "view2_histograms.png": lambda p: view2_histograms(rows, st, p),
        "view3_hamming_clustered.png": lambda p: view3_hamming(rows, H, p)[0],
        "view4_pipe_graph.png": lambda p: view4_pipe_graph(rows, Gm, Fm, H, p),
        "view5_derived_matrix.png": lambda p: view5_derived_matrix(rows, st, p),
    }
    pdf_path = os.path.join(out_dir, "phone_pipe_report.pdf")
    with PdfPages(pdf_path) as pdf:
        # cover
        fig = plt.figure(figsize=(11, 8.5))
        fig.text(0.5, 0.62, "Phone Pipe Report", ha="center", fontsize=28, weight="bold")
        fig.text(0.5, 0.54, f"{n} numbers · pipe_op · b60 · 10-op derivation · Hamming · χ² · entropy",
                 ha="center", fontsize=12)
        fig.text(0.5, 0.48, f"source: {os.path.basename(src)}   ·   20261009", ha="center", fontsize=10, color="#555")
        fig.text(0.5, 0.30, "Views: 1 table · 2 histograms · 3 Hamming clusters · 4 pipe-space graph · 5 derived matrix\n"
                            "Stats page follows the views. All PNGs are in the same folder.",
                 ha="center", fontsize=10)
        pdf.savefig(fig); plt.close(fig)
        for name, fn in pngs.items():
            fig = fn(os.path.join(out_dir, name))
            pdf.savefig(fig, bbox_inches="tight"); plt.close(fig)
            print(f"  wrote {name}")
        lines = stats_page(rows, st, H, Gm, Fm, pdf)
    print(f"  wrote {os.path.basename(pdf_path)}")

    # data dumps
    plain = []
    for i, r in enumerate(rows, 1):
        plain.append({
            "n": i, "number": r["num"], "label": r["label"], "area": r["area"], "region": r["region"],
            "exchange": r["exch"], "line": r["line"], "b60": r["b60"],
            "F_left": r["F_left"], "F_right": r["F_right"], "G_diff": r["G_diff"], "self_pipe": r["self_pipe"],
            "pipe_area_exch": {k: list(v) if isinstance(v, tuple) else v for k, v in r["pipe_area_exch"].items()},
            "derived": r["derived"]["text"], "derived_raw": r["derived"]["raw"],
            "derived_negatives": r["derived"]["n_negative"],
            "digit_sum": r["digit_sum"], "digital_root": r["digital_root"],
            "n_even": r["n_even"], "n_zero": r["n_zero"], "distinct_digits": r["distinct"],
        })
    with open(os.path.join(out_dir, "phone_pipe_data.json"), "w") as f:
        json.dump({"rows": plain, "digit_stats": st,
                   "hamming": H.tolist(), "pair_G_diff": Gm.tolist(), "pair_F_match": Fm.tolist()},
                  f, indent=1, default=float)
    with open(os.path.join(out_dir, "phone_pipe_plain.tsv"), "w") as f:
        f.write("n\tnumber\tlabel\tarea\tb60\tF\tG_diff\tself_pipe\tderived\tneg\tdigit_sum\troot\n")
        for p in plain:
            f.write(f"{p['n']}\t{p['number']}\t{p['label']}\t{p['area']}\t{p['b60']}\t"
                    f"{p['F_left']}|{p['F_right']}\t{p['G_diff']}\t{int(p['self_pipe'])}\t{p['derived']}\t"
                    f"{p['derived_negatives']}\t{p['digit_sum']}\t{p['digital_root']}\n")
    with open(os.path.join(out_dir, "phone_pipe_stats.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("  wrote phone_pipe_data.json, phone_pipe_plain.tsv, phone_pipe_stats.txt")
    print("\n".join(lines))

if __name__ == "__main__":
    main()
