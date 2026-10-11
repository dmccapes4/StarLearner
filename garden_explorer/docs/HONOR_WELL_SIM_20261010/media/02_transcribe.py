#!/usr/bin/env python
"""Whisper (GPU) for videos that have no YouTube captions (CNN disables auto-captions).

Downloads best audio with yt-dlp to data/<show>/audio/<id>.m4a (kept), transcribes with openai-whisper,
writes data/<show>/<upload_date>_<id>.whisper.json  {segments:[{start,end,text}]}, appends a meta record.
    python 02_transcribe.py [model=medium]
"""
import json, os, subprocess, sys, glob
HERE = os.path.dirname(os.path.abspath(__file__)); DATA = os.path.join(HERE, "data")
MAN = json.load(open(os.path.join(HERE, "manifest.json")))
MODEL = sys.argv[1] if len(sys.argv) > 1 else "medium"

def last_records(meta_path):
    recs = {}
    for l in open(meta_path):
        if l.strip():
            r = json.loads(l); recs[r["id"]] = r
    return recs

if __name__ == "__main__":
    import whisper, torch
    dev = "cuda" if torch.cuda.is_available() else "cpu"
    model = None
    for s in MAN["shows"]:
        d = os.path.join(DATA, s["show"]); mp = os.path.join(d, "meta.jsonl")
        if not os.path.exists(mp):
            continue
        for vid, rec in last_records(mp).items():
            if rec.get("caption_file") or rec.get("whisper_file"):
                continue
            adir = os.path.join(d, "audio"); os.makedirs(adir, exist_ok=True)
            audio = glob.glob(os.path.join(adir, f"{vid}.*"))
            if not audio:
                subprocess.run(["yt-dlp", "-f", "bestaudio[ext=m4a]/bestaudio", "--no-warnings", "-o", os.path.join(adir, f"{vid}.%(ext)s"),
                                f"https://www.youtube.com/watch?v={vid}"], check=False, capture_output=True, text=True, timeout=1200)
                audio = glob.glob(os.path.join(adir, f"{vid}.*"))
            if not audio:
                print(f"[{s['show']}] {vid}: audio download failed"); continue
            if model is None:
                model = whisper.load_model(MODEL, device=dev); print("whisper", MODEL, "on", dev)
            res = model.transcribe(audio[0], language="en", fp16=(dev == "cuda"), verbose=False)
            out = f"{rec['upload_date']}_{vid}.whisper.json"
            json.dump({"model": MODEL, "segments": [{"start": x["start"], "end": x["end"], "text": x["text"].strip()} for x in res["segments"]]},
                      open(os.path.join(d, out), "w"))
            rec = dict(rec, whisper_file=out)
            with open(mp, "a") as f:
                f.write(json.dumps(rec) + "\n")
            print(f"[{s['show']}] {vid}: {len(res['segments'])} whisper segments ({rec['duration']/60:.0f} min)")
