#!/usr/bin/env python3
"""
OurMercilessJourney — build pipeline.

  journey.py script   [--audit]            -> docs/OUR_MERCILESS_JOURNEY/script.jsonl (+ NUMBERS_AUDIT.md)
  journey.py tts      [--only CH05,CH06]   -> audio/<shot>_<hash>.mp3 (ElevenLabs, cached), timing.json
  journey.py render   [--only ..] [--silent] [--force]
                                           -> clips/CHxx.mp4 (pygame frames piped to ffmpeg, chapter audio muxed)
  journey.py assemble [--version 0.0.1]    -> OurMercilessJourney_v<ver>.mp4, CHAPTERS.md
  journey.py storyboard                    -> storyboard/CHxx.png, STORYBOARD.md
  journey.py all      [--version ..]

Timing is audio-driven: a shot lasts its narration plus a pad; the sim clock
advances at the shot's declared rate (or fits a declared span into the shot).
Frames are never dropped or duplicated to fit — the sim rate is what bends.
"""
from __future__ import annotations
import sys, os, json, hashlib, subprocess, argparse, wave, time, datetime as dt, inspect
from pathlib import Path
import numpy as np
from common import *   # noqa
import chapters as CHM

SCRIPT = OUT / "script.jsonl"
TIMING = OUT / "timing.json"
ELEVEN_MODEL = "eleven_multilingual_v2"
VOICE = {   # voice_id, stability, speed — same cast file as DIAMOND_SCREW video
    "NARRATOR":   ("XrExE9yKIg1WjnnlVkGX", 0.55, 0.92),   # Matilda
    "OPERATOR":   ("pNInz6obpgDQGcFmaJgB", 0.60, 0.95),   # Adam
    "CHRONICLER": ("onwK4e9ZLuTAKqWW03F9", 0.70, 0.95),   # Daniel
}
SR = 44100

# ───────────────────────── chapters & script ─────────────────────────
def build_chapters(only=None):
    out = []
    for cls in CHM.CHAPTER_CLASSES:
        if only and cls.ID not in only:
            continue
        t0 = time.time(); ch = cls(); ch._shots = []
        for j, s in enumerate(ch.SHOTS):
            s = dict(s); s["id"] = f"{cls.ID}_S{j:02d}"; s["chapter"] = cls.ID; ch._shots.append(s)
        out.append(ch)
        print(f"  {cls.ID} built ({time.time() - t0:.1f} s, {len(ch._shots)} shots)")
    return out

def all_shots_for_states():
    """Shots of every chapter (for replaying board states), cheap enough: builds every chapter."""
    return [s for ch in build_chapters() for s in ch._shots]

def cmd_script(args):
    D.used.clear()
    chs = build_chapters()
    n = 0; chars = 0
    with open(SCRIPT, "w") as f:
        for ch in chs:
            for s in ch._shots:
                f.write(json.dumps(s, ensure_ascii=False) + "\n"); n += 1; chars += len(s["spoken"])
    print(f"script.jsonl: {n} shots, {chars:,} characters to speak")
    if args.audit:
        seen = {}
        for path, val in D.used:
            seen.setdefault(path, val)
        with open(OUT / "NUMBERS_AUDIT.md", "w") as f:
            f.write("# Numbers audit — every value pulled into the narration/HUD, with its source path\n\n")
            f.write(f"Generated {dt.datetime.now():%Y-%m-%d %H:%M}. `LIT:` entries are literals with a stated source (not in a JSON).\n\n| source | value |\n|---|---|\n")
            for path, val in sorted(seen.items()):
                f.write(f"| `{path}` | {val} |\n")
        print(f"NUMBERS_AUDIT.md: {len(seen)} distinct sources")

def load_script():
    shots = [json.loads(l) for l in open(SCRIPT)]
    for s in shots:
        s["board"] = {int(k): v for k, v in s["board"].items()}      # JSON turned the row numbers into strings
    return shots

# ───────────────────────── ElevenLabs ─────────────────────────
def eleven_key():
    k = os.environ.get("ELEVENLABS_API_KEY")
    if k: return k
    for line in open(ELEVEN_ENV):
        if line.startswith("ELEVENLABS_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit("no ElevenLabs key")

def shot_audio_path(s):
    vid, stab, speed = VOICE[s["voice"]]
    h = hashlib.sha1(f"{vid}|{stab}|{speed}|{ELEVEN_MODEL}|{s['spoken']}".encode()).hexdigest()[:10]
    return OUT / "audio" / f"{s['id']}_{h}.mp3"

def eleven_tts(s, out: Path):
    import urllib.request
    vid, stab, speed = VOICE[s["voice"]]
    payload = {"text": s["spoken"], "model_id": ELEVEN_MODEL,
               "voice_settings": {"stability": stab, "similarity_boost": 0.75, "style": 0.15, "use_speaker_boost": True, "speed": speed}}
    req = urllib.request.Request(f"https://api.elevenlabs.io/v1/text-to-speech/{vid}?output_format=mp3_44100_128",
                                 data=json.dumps(payload).encode(), method="POST",
                                 headers={"xi-api-key": eleven_key(), "Content-Type": "application/json", "Accept": "audio/mpeg"})
    with urllib.request.urlopen(req, timeout=120) as r:
        out.write_bytes(r.read())

def ffprobe_dur(path):
    o = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)], capture_output=True, text=True).stdout.strip()
    return float(o)

def cmd_tts(args):
    shots = load_script(); only = set(args.only.split(",")) if args.only else None
    timing = json.load(open(TIMING)) if TIMING.exists() else {}
    n_new = chars_new = 0
    for s in shots:
        if only and s["chapter"] not in only: continue
        p = shot_audio_path(s)
        if not p.exists():
            print(f"  TTS {s['id']} [{s['voice']}] {len(s['spoken'])} ch"); eleven_tts(s, p); n_new += 1; chars_new += len(s["spoken"])
        timing[s["id"]] = {"audio": p.name, "dur": ffprobe_dur(p)}
    json.dump(timing, open(TIMING, "w"), indent=1)
    total = sum(v["dur"] for v in timing.values())
    with open(OUT / "COST.md", "a") as f:
        f.write(f"- {dt.datetime.now():%Y-%m-%d %H:%M} tts: {n_new} new shots, {chars_new:,} new characters, model {ELEVEN_MODEL}; library total {len(timing)} shots, {total / 60:.1f} min of speech\n")
    print(f"timing.json: {len(timing)} shots, {total / 60:.1f} min of speech ({n_new} new, {chars_new:,} chars)")

# ───────────────────────── timing / states ─────────────────────────
def resolve_shots(shots, timing, silent=False):
    """Attach duration and rate to each shot (in place)."""
    for s in shots:
        if (not silent) and s["id"] in timing:
            dur = timing[s["id"]]["dur"]; s["audio"] = str(OUT / "audio" / timing[s["id"]]["audio"])
        else:
            dur = max(2.0, 0.062 * len(s["spoken"])); s["audio"] = None     # silent preview estimate
        s["dur"] = dur + s["pad"]
        s["rate_eff"] = (s["fit"] / s["dur"]) if s.get("fit") else s["rate"]
    return shots

def states_before(chapter_id, shots):
    st = {}
    for s in shots:
        if s["chapter"] == chapter_id: break
        st.update(s["board"])
    return st

class Ctx: pass

# ───────────────────────── render ─────────────────────────
def chapter_wav(ch_shots, out_wav):
    total = sum(s["dur"] for s in ch_shots)
    buf = np.zeros(int(total * SR) + SR, np.int16)
    t = 0.0
    for s in ch_shots:
        if s["audio"]:
            raw = subprocess.run(["ffmpeg", "-v", "error", "-i", s["audio"], "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"], capture_output=True).stdout
            a = np.frombuffer(raw, np.int16); i0 = int(t * SR); buf[i0:i0 + len(a)] = a[:len(buf) - i0]
        t += s["dur"]
    with wave.open(str(out_wav), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(buf[:int(total * SR)].tobytes())
    return total

def chapter_hash(ch, ch_shots):
    src = inspect.getsource(type(ch)) + inspect.getsource(CHM.OrbitCache) + open(HERE / "common.py").read()
    key = json.dumps([(s["text"], s["audio"], s["dur"], s["rate_eff"]) for s in ch_shots]) + src
    return hashlib.sha1(key.encode()).hexdigest()[:12]

def render_chapter(ch, ch_shots, states0, force=False, silent=False):
    clip = OUT / "clips" / f"{ch.ID}.mp4"; meta = clip.with_suffix(".json")
    h = chapter_hash(ch, ch_shots)
    if clip.exists() and meta.exists() and not force and json.load(open(meta)).get("hash") == h:
        print(f"  {ch.ID}: cached"); return json.load(open(meta))
    wav = OUT / "clips" / f"{ch.ID}.wav"; total = chapter_wav(ch_shots, wav)
    n_frames = int(round(total * FPS))
    cmd = ["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
           "-i", str(wav), "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-shortest", str(clip)]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    surf = pygame.Surface((W, H)); clock = pygame.time.Clock()
    states = dict(states0); applied = set()
    bounds = []; t = 0.0
    for s in ch_shots: bounds.append((t, t + s["dur"])); t += s["dur"]
    sim_base = 0.0; cur = -1
    t0 = time.time()
    for f in range(n_frames):
        clock.tick()                         # pygame clock: the frame counter is the sim clock's master
        tt = f / FPS
        i = next((k for k, (a, b) in enumerate(bounds) if a <= tt < b), len(ch_shots) - 1)
        if i != cur:
            if cur >= 0: sim_base += ch_shots[cur]["rate_eff"] * ch_shots[cur]["dur"]
            cur = i
        s = ch_shots[i]; ts = tt - bounds[i][0]; p = ts / s["dur"]
        if p >= s["board_at"] and s["board"] and s["id"] not in applied:
            states.update(s["board"]); applied.add(s["id"])
        ctx = Ctx(); ctx.i, ctx.p, ctx.ts, ctx.t = i, p, ts, tt
        ctx.sim = sim_base + s["rate_eff"] * ts; ctx.states = states; ctx.shot = s
        ctx.flash = CHM.kill_flash(ctx, list(s["board"].keys())) if s["board"] else {}
        surf.fill(BG)
        ch.draw(surf, ctx)
        if states or ch.ID >= "CH04":
            board_strip(surf, states, ctx.flash)
        if silent:
            text(surf, "SILENT PREVIEW — durations estimated", (W // 2, 70 + 14), "mono", 16, RED, "center")
        proc.stdin.write(pygame.image.tobytes(surf, "RGB"))
        if abs(ts - s["dur"] / 2) < 0.5 / FPS or (f == 0):
            pygame.image.save(surf, str(OUT / "frames_sample" / f"{s['id']}.png"))
    proc.stdin.close(); proc.wait()
    wav.unlink(missing_ok=True)
    info = {"hash": h, "duration": total, "frames": n_frames, "shots": [(s["id"], s["dur"]) for s in ch_shots], "render_s": round(time.time() - t0, 1), "silent": silent}
    json.dump(info, open(meta, "w"), indent=1)
    print(f"  {ch.ID}: {n_frames} frames, {total:.1f} s, rendered in {info['render_s']} s")
    return info

def cmd_render(args):
    pygame.init()
    shots = load_script(); timing = json.load(open(TIMING)) if TIMING.exists() else {}
    resolve_shots(shots, timing, silent=args.silent)
    only = set(args.only.split(",")) if args.only else None
    chs = build_chapters(only)
    for ch in chs:
        ch_shots = [s for s in shots if s["chapter"] == ch.ID]
        for s, t in zip(ch_shots, ch._shots): t.update(s)      # carry dur/rate/audio into the built chapter's shots
        render_chapter(ch, ch_shots, states_before(ch.ID, shots), force=args.force, silent=args.silent)

# ───────────────────────── assemble / storyboard ─────────────────────────
def cmd_assemble(args):
    ids = [c.ID for c in CHM.CHAPTER_CLASSES]
    clips = [OUT / "clips" / f"{i}.mp4" for i in ids if (OUT / "clips" / f"{i}.mp4").exists()]
    lst = OUT / "clips" / "concat.txt"
    lst.write_text("".join(f"file '{c.name}'\n" for c in clips))
    final = OUT / f"OurMercilessJourney_v{args.version}.mp4"
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(final)], check=True)
    t = 0.0; rows = []
    for c in clips:
        meta = json.load(open(c.with_suffix(".json"))); cls = next(k for k in CHM.CHAPTER_CLASSES if k.ID == c.stem)
        rows.append((c.stem, cls.TITLE, t, meta["duration"], meta.get("silent", False))); t += meta["duration"]
    with open(OUT / "CHAPTERS.md", "w") as f:
        f.write(f"# OurMercilessJourney v{args.version} — chapters\n\n`{final.name}` · {t / 60:.1f} min · {len(clips)} chapters · assembled {dt.datetime.now():%Y-%m-%d %H:%M}\n\n| start | chapter | title | length |\n|---|---|---|---|\n")
        for cid, title, st, du, sil in rows:
            f.write(f"| {int(st // 60):02d}:{int(st % 60):02d} | {cid} | {title}{' (SILENT PREVIEW)' if sil else ''} | {du:.0f} s |\n")
    print(f"{final.name}: {t / 60:.1f} min, {len(clips)} chapters")

def cmd_storyboard(args):
    pygame.init()
    shots = load_script()
    lines = ["# OurMercilessJourney — storyboard\n", f"Generated {dt.datetime.now():%Y-%m-%d %H:%M}. One frame per shot (mid-shot), with the narration under it.\n"]
    for cls in CHM.CHAPTER_CLASSES:
        ch_shots = [s for s in shots if s["chapter"] == cls.ID]
        frames = [OUT / "frames_sample" / f"{s['id']}.png" for s in ch_shots]
        frames = [f for f in frames if f.exists()]
        if not frames: continue
        cols = 3; rows = (len(frames) + cols - 1) // cols; tw, th = 620, 349
        sheet = pygame.Surface((cols * (tw + 10) + 10, rows * (th + 10) + 10)); sheet.fill(BG)
        for k, fp in enumerate(frames):
            im = pygame.transform.smoothscale(pygame.image.load(str(fp)), (tw, th))
            sheet.blit(im, (10 + (k % cols) * (tw + 10), 10 + (k // cols) * (th + 10)))
        outp = OUT / "storyboard" / f"{cls.ID}.png"; pygame.image.save(sheet, str(outp))
        lines.append(f"\n## {cls.ID} — {cls.TITLE}\n\n![{cls.ID}](storyboard/{cls.ID}.png)\n")
        for s in ch_shots:
            lines.append(f"- **{s['id']}** [{s['voice']}{' · ' + s['when'] if s.get('when') else ''}] {s['text']}")
    (OUT / "STORYBOARD.md").write_text("\n".join(lines) + "\n")
    print("STORYBOARD.md written")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["script", "tts", "render", "assemble", "storyboard", "all"])
    ap.add_argument("--only"); ap.add_argument("--audit", action="store_true"); ap.add_argument("--silent", action="store_true")
    ap.add_argument("--force", action="store_true"); ap.add_argument("--version", default="0.0.1")
    args = ap.parse_args()
    if args.cmd in ("script", "all"): args.audit = True; cmd_script(args)
    if args.cmd in ("tts", "all"): cmd_tts(args)
    if args.cmd in ("render", "all"): cmd_render(args)
    if args.cmd in ("assemble", "all"): cmd_assemble(args)
    if args.cmd in ("storyboard", "all"): cmd_storyboard(args)

if __name__ == "__main__":
    main()
