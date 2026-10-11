#!/usr/bin/env python
"""Fetch captions (free) for the latest K clips of each show playlist.

For each video: metadata (upload_date, duration, view_count, title) + English captions as json3
(manual subs preferred, auto-captions otherwise). Nothing is downloaded twice, nothing is deleted.

    python 01_fetch.py [K=6]
Writes data/<show>/<upload_date>_<id>.json3 and data/<show>/meta.jsonl (append-only, deduped by id).
"""
import json, os, subprocess, sys, glob
HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")
MAN = json.load(open(os.path.join(HERE, "manifest.json")))
K = int(sys.argv[1]) if len(sys.argv) > 1 else 6

def run(args):
    return subprocess.run(["yt-dlp", *args], capture_output=True, text=True, timeout=600)

def list_ids(playlist_id, k):
    r = run(["--flat-playlist", "--playlist-end", str(k), "--print", "%(id)s", f"https://www.youtube.com/playlist?list={playlist_id}"])
    return [l.strip() for l in r.stdout.splitlines() if l.strip()]

def fetch(show_dir, vid):
    meta_path = os.path.join(show_dir, "meta.jsonl")
    seen = {}
    if os.path.exists(meta_path):
        for l in open(meta_path):
            if l.strip():
                rec = json.loads(l); seen[rec["id"]] = rec   # last record per id wins (append-only file)
    if vid in seen and seen[vid].get("caption_file"):
        return "seen"
    tmpl = os.path.join(show_dir, "%(upload_date)s_%(id)s")
    # --print implies simulate; --no-simulate is required for the caption files to be written
    r = run(["--skip-download", "--no-simulate", "--write-subs", "--write-auto-subs", "--sub-langs", "en.*,en", "--sub-format", "json3",
             "--print", "%(upload_date)s|%(duration)s|%(view_count)s|%(title)s|%(channel)s",
             "--no-warnings", "-o", tmpl, f"https://www.youtube.com/watch?v={vid}"])
    line = next((l for l in r.stdout.splitlines() if "|" in l), None)
    if line is None:
        return f"fail: {r.stderr.strip()[-200:]}"
    up, dur, views, title, channel = line.split("|", 4)
    subs = sorted(glob.glob(os.path.join(show_dir, f"{up}_{vid}*.json3")))
    rec = {"id": vid, "upload_date": up, "duration": float(dur) if dur not in ("NA", "") else None,
           "view_count": int(views) if views not in ("NA", "") else None, "title": title, "channel": channel,
           "caption_file": os.path.basename(subs[0]) if subs else None}
    with open(meta_path, "a") as f:
        f.write(json.dumps(rec) + "\n")
    return "ok" if subs else "ok-nocaptions"

if __name__ == "__main__":
    for s in MAN["shows"]:
        d = os.path.join(DATA, s["show"]); os.makedirs(d, exist_ok=True)
        for pl in s["playlists"]:
            ids = list_ids(pl["id"], K)
            print(f"[{s['show']}] {pl['name']}: {len(ids)} ids")
            for v in ids:
                print("   ", v, fetch(d, v))
