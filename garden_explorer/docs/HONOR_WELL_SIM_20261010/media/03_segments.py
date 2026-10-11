#!/usr/bin/env python
"""Captions (json3) or whisper output → 45-second text segments.

Writes data/segments/<show>.jsonl, one line per segment:
  {show, date, video_id, title, t0, t1, text, source}
Caption file priority per video: en-orig > en > en-US > any other en-* (dubbed/variant tracks last). Rebuilt each run (derived data).
"""
import json, os, glob, re
HERE = os.path.dirname(os.path.abspath(__file__)); DATA = os.path.join(HERE, "data")
MAN = json.load(open(os.path.join(HERE, "manifest.json")))
SEG = MAN.get("segment_seconds", 45)

def pick_caption(show_dir, up, vid):
    files = glob.glob(os.path.join(show_dir, f"{up}_{vid}.*.json3"))
    def rank(f):
        tag = os.path.basename(f).split(f"{vid}.", 1)[1].rsplit(".json3", 1)[0]
        return {"en-orig": 0, "en": 1, "en-US": 2}.get(tag, 3 if not tag.startswith("en-en") else 4)
    return sorted(files, key=rank)[0] if files else None

def words_from_json3(path):
    ev = json.load(open(path)).get("events", [])
    out = []
    for e in ev:
        t = e.get("tStartMs", 0)
        for s in e.get("segs", []) or []:
            w = s.get("utf8", "")
            if w.strip() and w != "\n":
                out.append(((t + s.get("tOffsetMs", 0)) / 1000.0, w))
    return out

def words_from_whisper(path):
    out = []
    for s in json.load(open(path))["segments"]:
        ws = s["text"].split()
        if not ws: continue
        dt = (s["end"] - s["start"]) / len(ws)
        out += [(s["start"] + i * dt, w) for i, w in enumerate(ws)]
    return out

def segments(words):
    if not words: return []
    segs, cur, t0 = [], [], words[0][0]
    for t, w in words:
        if t - t0 >= SEG and cur:
            segs.append((t0, t, " ".join(cur))); cur, t0 = [], t
        cur.append(w)
    if cur: segs.append((t0, words[-1][0], " ".join(cur)))
    return [(a, b, re.sub(r"\s+", " ", x).strip()) for a, b, x in segs if len(x.split()) >= 8]

if __name__ == "__main__":
    os.makedirs(os.path.join(DATA, "segments"), exist_ok=True)
    for s in MAN["shows"]:
        d = os.path.join(DATA, s["show"]); mp = os.path.join(d, "meta.jsonl")
        if not os.path.exists(mp): continue
        recs = {}
        for l in open(mp):
            if l.strip(): r = json.loads(l); recs[r["id"]] = r
        n = 0
        with open(os.path.join(DATA, "segments", f"{s['show']}.jsonl"), "w") as out:
            for vid, r in recs.items():
                cap = pick_caption(d, r["upload_date"], vid)
                if cap: words, src = words_from_json3(cap), "youtube-captions"
                elif r.get("whisper_file"): words, src = words_from_whisper(os.path.join(d, r["whisper_file"])), "whisper-" + json.load(open(os.path.join(d, r["whisper_file"])))["model"]
                else: continue
                for t0, t1, text in segments(words):
                    out.write(json.dumps({"show": s["show"], "date": r["upload_date"], "video_id": vid, "title": r["title"], "t0": round(t0, 1), "t1": round(t1, 1), "text": text, "source": src}) + "\n"); n += 1
        print(f"{s['show']}: {n} segments from {len(recs)} videos")
