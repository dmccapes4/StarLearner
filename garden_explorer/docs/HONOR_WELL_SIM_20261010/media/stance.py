#!/usr/bin/env python
"""Stance scalars on the seven axes (axes.json), horseshoe-weighted distance.

    s_k = tanh(beta * (cos(e, u+_k) - cos(e, u-_k)))      stance, [-1, 1]
    a_k = max(0, cos(e, u_k) - tau)                         salience (raw), then normalised to the simplex
    d_m(y) = sum_k a_mk |s_mk - y_k|                         horseshoe distance from molecule m to point y

beta is calibrated once so the pole statements themselves score +-0.9 on their own axis.
Run as a script: self-check (poles score their own axis), then the operator's seven statements.
"""
import json, os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
AXES = json.load(open(os.path.join(HERE, "axes.json")))
MODEL_NAME = "all-MiniLM-L6-v2"

class Stance:
    def __init__(self, model=None, tau=0.15):
        from sentence_transformers import SentenceTransformer
        self.m = model or SentenceTransformer(MODEL_NAME)
        self.ids = [a["id"] for a in AXES["axes"]]
        neg = [self._emb(a["neg"]).mean(0) for a in AXES["axes"]]
        pos = [self._emb(a["pos"]).mean(0) for a in AXES["axes"]]
        self.Un = self._unit(np.stack(neg)); self.Up = self._unit(np.stack(pos))
        self.U = self._unit(self.Un + self.Up)
        self.tau = tau
        # calibrate beta so pole statements hit +-0.9 on their own axis
        raw = []
        for k, a in enumerate(AXES["axes"]):
            for sign, bank in ((-1, a["neg"]), (+1, a["pos"])):
                e = self._emb(bank)
                raw += list(sign * (e @ self.Up[k] - e @ self.Un[k]))
        self.beta = np.arctanh(0.9) / np.median(raw)

    def _emb(self, texts):
        return self._unit(self.m.encode(list(texts), normalize_embeddings=True, convert_to_numpy=True))

    @staticmethod
    def _unit(x):
        return x / np.linalg.norm(x, axis=-1, keepdims=True)

    def score(self, texts):
        e = self._emb(texts)                              # (M, 384)
        s = np.tanh(self.beta * (e @ self.Up.T - e @ self.Un.T))   # (M, K)
        a = np.maximum(0.0, e @ self.U.T - self.tau)      # (M, K)
        return s, a

    def aggregate(self, s, a):
        """Night-level: salience-weighted stance p_k, per-axis radius r_k, attention vector a (simplex)."""
        w = a.sum(0) + 1e-9
        p = (a * s).sum(0) / w
        r = np.sqrt((a * (s - p) ** 2).sum(0) / w)
        att = a.sum(0); att = att / att.sum() if att.sum() > 0 else np.full(len(w), 1 / len(w))
        return p, r, att

class StanceNLI:
    """Zero-shot NLI backend: s_k = mean P(entail | text, pos_k) - mean P(entail | text, neg_k);
    salience a_k = max entailment over both banks minus tau. Same interface as Stance."""
    def __init__(self, model_name="cross-encoder/nli-deberta-v3-base", tau=0.2, device=None):
        from sentence_transformers import CrossEncoder
        self.ce = CrossEncoder(model_name, device=device)
        self.ids = [a["id"] for a in AXES["axes"]]
        self.tau = tau
        # label order for this family: contradiction, entailment, neutral
        self.ent = 1

    def _ec(self, texts, hyps):
        """Return (entail - contradict) in [-1,1] and max(entail, contradict) in [0,1], shape (M, H).
        Contradiction carries as much stance signal as entailment: 'safe, legal, rare' is neutral to the
        pro-choice pole and contradicts the restrict pole, which is how it is read as left-of-centre."""
        pairs = [(t, h) for t in texts for h in hyps]
        logits = self.ce.predict(pairs, convert_to_numpy=True, show_progress_bar=False, batch_size=64)
        probs = np.exp(logits - logits.max(1, keepdims=True)); probs /= probs.sum(1, keepdims=True)
        e = probs[:, 1].reshape(len(texts), len(hyps)); c = probs[:, 0].reshape(len(texts), len(hyps))
        return e - c, np.maximum(e, c)

    @staticmethod
    def _decisive(ec):
        """Signed value of the most decisive hypothesis in a bank (largest |entail - contradict|)."""
        idx = np.abs(ec).argmax(1)
        return ec[np.arange(len(ec)), idx]

    def score(self, texts):
        S, A = [], []
        for a in AXES["axes"]:
            ecn, mn = self._ec(texts, a["neg"]); ecp, mp = self._ec(texts, a["pos"])
            S.append(0.5 * (self._decisive(ecp) - self._decisive(ecn)))
            A.append(np.maximum(0.0, np.maximum(mn.max(1), mp.max(1)) - self.tau))
        return np.stack(S, 1), np.stack(A, 1)


class StanceHybrid:
    """Salience (topic routing) from MiniLM cosine; stance from NLI decisive entail/contradict."""
    def __init__(self):
        self.mini = Stance(); self.nli = StanceNLI(); self.ids = self.mini.ids
    def score(self, texts):
        _, a = self.mini.score(texts); s, _ = self.nli.score(texts)
        return s, a
    aggregate = Stance.aggregate

    aggregate = Stance.aggregate


def horseshoe_distance(a_m, s_m, y):
    return float(np.sum(a_m * np.abs(s_m - y)))

def concentration(a):
    return float(a.max() - 1.0 / len(a))

OPERATOR = {
    "abortion":    "safe, legal, rare",
    "immigration": "secure border is necessary for immigration reform; CalFire to citizenship: hard work protecting the state and you can sit beside me in the EBT line",
    "guns":        "safer when legal and regulated (basic FFL and safety requirements); mental health policies that don't discourage mental health reporting",
    "education":   "more charter schools and home school options increase parent choice; dissolution of predatory unions; allocation of taxes equally rather than by property taxes; no bonds for education",
    "foreign_war": "not my country; CIA overthrew gov in 2014 with operatives literally on HUD with ukrainian soldiers; donbas and luhansk are effectively russian; refer to Kant on whether we should lend for war (we should not); Trump's mineral deal seemed oddly sensible",
    "economy":     "I believe in hard work and have conservative values on right and wrong. I am for social programs like disability, welfare, EBT when needed.",
    "trade(ext)":  "against tariffs on principle; recognize that certain necessary commodities may require tariff hedging to avoid market collapse; still disagree on principle",
}
PROPOSED = {"abortion": -0.4, "immigration": 0.1, "guns": -0.2, "education": 0.5, "foreign_war": 0.6, "economy": -0.3}

if __name__ == "__main__":
    backend = sys.argv[1] if len(sys.argv) > 1 else "minilm"
    st = {"nli": StanceNLI, "hybrid": StanceHybrid}.get(backend, Stance)()
    print(f"backend = {backend}; axes = {st.ids}" + (f"; beta = {st.beta:.2f}" if hasattr(st, "beta") else ""))
    # self-check: each pole bank on its own axis
    ok = 0; tot = 0
    for k, a in enumerate(AXES["axes"]):
        s, _ = st.score(a["neg"] + a["pos"])
        own = s[:, k]; signs = np.r_[-np.ones(len(a["neg"])), np.ones(len(a["pos"]))]
        hit = int(((own * signs) > 0.3).sum()); ok += hit; tot += len(own)
        off = np.delete(np.abs(s), k, axis=1).mean()
        print(f"  {a['id']:<12} own-axis correct sign & |s|>0.3: {hit}/{len(own)}   mean |s| on other axes: {off:.2f}")
    print(f"self-check: {ok}/{tot}")
    # operator statements
    texts = list(OPERATOR.values()); keys = list(OPERATOR.keys())
    s, a = st.score(texts)
    print("\noperator statements → stance on the seven axes (row = statement, col = axis); proposed placement in brackets")
    print(" " * 14 + "".join(f"{i[:9]:>10}" for i in st.ids) + "   top-salience axis")
    for i, key in enumerate(keys):
        row = "".join(f"{v:>+10.2f}" for v in s[i])
        tgt = PROPOSED.get(key); tag = f"  [{tgt:+.1f}]" if tgt is not None else "  [ext]"
        print(f"{key:<14}{row}   {st.ids[int(a[i].argmax())]}{tag}")
    p, r, att = st.aggregate(s, a)
    print(f"\noperator molecule (aggregate of the seven statements): p = {np.round(p,2).tolist()}")
    print(f"attention a = {np.round(att,2).tolist()}  pillar = {st.ids[int(att.argmax())]}  concentration h = {concentration(att):.2f}")
    out = {"backend": backend, "beta": float(getattr(st, "beta", float("nan"))), "axes": st.ids, "operator_rows": {k: np.round(s[i],3).tolist() for i,k in enumerate(keys)},
           "operator_p": np.round(p,3).tolist(), "operator_attention": np.round(att,3).tolist(), "proposed": PROPOSED}
    json.dump(out, open(os.path.join(HERE, f"stance_selfcheck_{backend}.json"), "w"), indent=1)
