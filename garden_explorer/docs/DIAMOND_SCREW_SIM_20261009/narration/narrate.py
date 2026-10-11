#!/usr/bin/env python3
"""Single-voice ElevenLabs narration of FABLE_CIRCLE_OF_DIAMONDS_AND_TESSERACTS_20261009.md, as written.

Voice: Matilda (XrExE9yKIg1WjnnlVkGX) — the narrator used across star_learning
(solar_system_explorer/tools/gen_solar_vo.py, journey.py, ant_explorer gen_vo.py).
Model eleven_multilingual_v2, stability 0.55, speed 0.92.

Everything in the markdown is read: title, subtitle, header block, section headings,
narrative paragraphs, stage directions, speaker labels ("Feynman:") followed by the
quoted line, McClane's written scores ("McClane writes: ..."), both score tables row by
row, and the closing italic line. Markdown emphasis is stripped; a few glyphs are made
audible (½, −∞, §, 20261009). Nothing is paraphrased.

Usage:
  PY=/home/dylanmccapes/dev/BeginningToNoww/.venv/bin/python3   # any python3 works; stdlib only
  $PY narrate.py text          # print the spoken script (no API calls)
  $PY narrate.py tts           # synthesize paragraphs -> parts/*.wav (cached by hash)
  $PY narrate.py join          # concat with pauses -> fable_circle_narration.wav + .mp3
  $PY narrate.py all           # tts + join
"""
import concurrent.futures as cf, hashlib, json, os, random, re, subprocess, sys, time, urllib.error, urllib.request, wave

HERE = os.path.dirname(os.path.abspath(__file__))
FABLE = os.path.join(HERE, "..", "FABLE_CIRCLE_OF_DIAMONDS_AND_TESSERACTS_20261009.md")
ENV = "/home/dylanmccapes/dev/star_learning/ant_explorer/tools/secrets/elevenlabs.env"
PARTS = os.path.join(HERE, "parts"); os.makedirs(PARTS, exist_ok=True)
OUT_WAV = os.path.join(HERE, "fable_circle_narration.wav"); OUT_MP3 = OUT_WAV[:-4] + ".mp3"
SCRIPT_TXT = os.path.join(HERE, "spoken.txt")

VOICE_ID, STABILITY, SPEED, MODEL = "XrExE9yKIg1WjnnlVkGX", 0.55, 0.92, "eleven_multilingual_v2"
RATE = 24000

# ───────────────────────── parse ─────────────────────────
def strip_md(t):
    t = re.sub(r"\*\*(.+?)\*\*", r"\1", t); t = re.sub(r"\*(.+?)\*", r"\1", t)
    return re.sub(r"  +", " ", t).strip()

def audible(t):
    t = t.replace("20261009", "2026-10-09").replace("§", "section ")
    t = t.replace("2½", "two and a half").replace("½", "one half").replace("−∞", "minus infinity")
    t = re.sub(r"−(\d+)", r"minus \1", t)
    t = t.replace("1 + ?", "one, plus a question mark").replace("1?", "one, question mark")
    t = t.replace(" · ", ", ").replace(" km ", " kilometres ")
    t = t.replace("FEYNMAN'S COLUMN", "Feynman's column").replace("McCLANE'S COLUMN", "McClane's column")
    return t

def display_name(name):
    n = name.strip().rstrip(":").strip()
    special = {"MCCLANE": "McClane", "HERON OF ALEXANDRIA": "Heron of Alexandria", "BENJAMIN FRANKLIN": "Benjamin Franklin",
               "A VOICE FROM THE HORDE": "A voice from the horde", "ANOTHER": "Another", "THE HORDE": "The horde"}
    return special.get(n.upper(), n.title() if n.isupper() else n)

def paragraphs():
    """Yield (kind, text) in document order. kind: head | meta | nar | table_row | tail."""
    lines = open(FABLE, encoding="utf-8").read().split("\n"); i = 0
    while i < len(lines):
        ln = lines[i].rstrip(); i += 1
        if not ln.strip() or ln.strip() == "---": continue
        if ln.startswith("# "): yield "head", ln[2:].strip(); continue
        if ln.startswith("### "): yield "head", ln[4:].strip(); continue
        if ln.startswith("## "):
            m = re.match(r"## (\d+)\. (.*)", ln)
            yield "head", (("Zero. " if m.group(1) == "0" else m.group(1) + ". ") + m.group(2)) if m else ln[3:].strip(); continue
        if ln.startswith("|"):
            rows = []
            while i <= len(lines) and ln.startswith("|"):
                cells = [c.strip() for c in ln.strip("|").split("|")]
                if not set("".join(cells)) <= set("-: "): rows.append(cells)
                ln = lines[i].rstrip() if i < len(lines) else ""; i += 1
            i -= 1
            for r in rows[1:]:
                who, pts, why = (r + ["", ""])[:3]
                pts = {"—": "no points"}.get(pts, pts)
                yield "table_row", f"{who}: {pts}. {why.rstrip('.')}."
            continue
        m = re.match(r"^\*\*([^*]+?)\*\*(.*)$", ln)
        if m and m.group(1).strip().rstrip(":").replace("Mc", "MC").isupper():
            name = display_name(m.group(1)); rest = m.group(2).strip()
            if rest.startswith(":"): rest = rest[1:].strip()
            rest = strip_md(rest)
            rest = re.sub(r'(?<=")\s*\(writes\)\s*', " — writes: ", rest)          # "I'm barefoot." (writes) Archimedes: 1. …
            mw = re.match(r"^\((writes[^)]*)\)\s*(.*)$", rest)
            if mw:                                   # (writes) Imhotep: 1. It's standing.   /  (writes nothing)
                body = mw.group(2).strip()
                yield "nar", f"{name} {mw.group(1)}{': ' + body if body else '.'}"; continue
            md = re.match(r"^\(([^)]*)\)\s*:?\s*(.*)$", rest)
            if md:                                   # (tapping the left column): "..."
                yield "nar", f"{name}, {md.group(1)}: {md.group(2)}"; continue
            if rest.startswith('"'): yield "nar", f"{name}: {rest}"; continue
            yield "nar", f"{name} {rest}"; continue  # **ARCHIMEDES** stands up. ...
        if m:                                        # **Date:** ... header block
            yield "meta", strip_md(ln); continue
        if ln.startswith("*") and ln.endswith("*"): yield "tail", strip_md(ln); continue
        yield "nar", strip_md(ln)

def script():
    return [(k, audible(t)) for k, t in paragraphs() if t.strip()]

# ───────────────────────── tts ─────────────────────────
def api_key():
    for line in open(ENV, encoding="utf-8"):
        if line.strip().startswith("ELEVENLABS_API_KEY="): return line.split("=", 1)[1].strip().strip('"').strip("'")
    sys.exit("no ELEVENLABS_API_KEY in " + ENV)

def part_path(text):
    return os.path.join(PARTS, hashlib.md5((VOICE_ID + MODEL + text).encode()).hexdigest()[:16] + ".wav")

def tts(text, out_wav, prev, nxt):
    if os.path.exists(out_wav): return False
    payload = {"text": text, "model_id": MODEL, "previous_text": prev or None, "next_text": nxt or None,
               "voice_settings": {"stability": STABILITY, "similarity_boost": 0.75, "style": 0.0, "use_speaker_boost": True, "speed": SPEED}}
    payload = {k: v for k, v in payload.items() if v is not None}
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}?output_format=mp3_44100_128"
    for attempt in range(6):
        req = urllib.request.Request(url, data=json.dumps(payload).encode(), method="POST",
                                     headers={"xi-api-key": api_key(), "Content-Type": "application/json", "Accept": "audio/mpeg"})
        try:
            with urllib.request.urlopen(req, timeout=120) as resp: mp3 = resp.read()
            tmp = out_wav + ".mp3"; open(tmp, "wb").write(mp3)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-ac", "1", "-ar", str(RATE), "-c:a", "pcm_s16le", out_wav], check=True)
            os.remove(tmp); return True
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")[:200]
            if e.code in (401, 402) or "quota" in body.lower(): raise RuntimeError(f"HTTP {e.code} {body}")
            w = min(90, 6 * 2 ** attempt) + random.uniform(0, 2); print(f"HTTP {e.code} {body}; sleep {w:.0f}s", flush=True); time.sleep(w)
        except Exception as e:
            w = min(90, 6 * 2 ** attempt); print(f"{type(e).__name__}; sleep {w}s", flush=True); time.sleep(w)
    raise RuntimeError("tts failed: " + text[:60])

def stage_tts():
    S = script(); texts = [t for _, t in S]
    print(f"{len(S)} paragraphs, {sum(map(len, texts))} chars", flush=True)
    def one(k):
        t = texts[k]; made = tts(t, part_path(t), texts[k - 1] if k else "", texts[k + 1] if k + 1 < len(texts) else "")
        print(("tts " if made else "cached ") + f"{k:03d} {t[:70]}", flush=True)
    with cf.ThreadPoolExecutor(3) as ex: list(ex.map(one, range(len(S))))

# ───────────────────────── join ─────────────────────────
def pcm_of(p):
    with wave.open(p, "rb") as w: return w.readframes(w.getnframes())

def sil(sec): return b"\x00" * (int(RATE * sec) * 2)

PAUSE = {"head": (1.4, 0.9), "meta": (0.0, 0.45), "nar": (0.0, 0.6), "table_row": (0.0, 0.35), "tail": (1.2, 1.5)}

def stage_join():
    S = script(); out = sil(0.8); missing = []
    for k, (kind, t) in enumerate(S):
        p = part_path(t)
        if not os.path.exists(p): missing.append(k); continue
        lead, tail = PAUSE[kind]
        if k and S[k - 1][0] == "head": lead = 0.0
        out += sil(lead) + pcm_of(p) + sil(tail)
    if missing: sys.exit(f"missing parts: {missing}")
    with wave.open(OUT_WAV, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(out)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", OUT_WAV, "-c:a", "libmp3lame", "-b:a", "128k", OUT_MP3], check=True)
    open(SCRIPT_TXT, "w", encoding="utf-8").write("\n\n".join(t for _, t in S) + "\n")
    print(f"{OUT_WAV}  {len(out) / (RATE * 2) / 60:.1f} min\n{OUT_MP3}\n{SCRIPT_TXT}")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "text"
    if cmd == "text":
        S = script(); print("\n\n".join(f"[{k}] {t}" for k, t in S)); print(f"\n{len(S)} paragraphs, {sum(len(t) for _, t in S)} chars", file=sys.stderr)
    elif cmd == "tts": stage_tts()
    elif cmd == "join": stage_join()
    elif cmd == "all": stage_tts(); stage_join()
