#!/usr/bin/env python3
"""Language Explorer ASR + llama cleanup service.

Endpoints:
  GET  /health
  POST /v1/transcribe     multipart: audio → {text, lang}
  POST /v1/voice_write    multipart: audio [,lang] → {raw, text, letters}
  POST /v1/command        multipart: audio → {command: next|back|none, text}

Dev:
  ./tools/asr_server/run.sh
  # listens on 127.0.0.1:8765

Env:
  ASR_HOST=127.0.0.1
  ASR_PORT=8765
  ASR_MODEL=tiny.en          # or base.en
  OLLAMA_URL=http://127.0.0.1:11434
  OLLAMA_MODEL=llama3.2:3b
  ASR_DELETE_UPLOADS=1
"""
from __future__ import annotations

import json
import os
import re
import tempfile
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

# --- config -------------------------------------------------------------------

HOST = os.environ.get("ASR_HOST", "127.0.0.1")
PORT = int(os.environ.get("ASR_PORT", "8765"))
ASR_MODEL = os.environ.get("ASR_MODEL", "tiny.en")
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434").rstrip("/")
# qwen3:8b judges whether a transcription makes sense in context; llama3.2:3b
# accepted nonsense like "My Bonnie is so cute". Thinking stays off for latency.
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "qwen3:8b")
OLLAMA_THINK = os.environ.get("OLLAMA_THINK", "0") == "1"
DELETE_UPLOADS = os.environ.get("ASR_DELETE_UPLOADS", "1") != "0"

_whisper = None

# Bias Whisper toward kid vocabulary (names like Bonnie beat bunny without this).
VOICE_WRITE_PROMPT = (
    "A young child said a short everyday sentence. "
    "Prefer common kid words — bunny, puppy, kitty, mommy, daddy, grandma, "
    "friend, school, park, zoo, candy, cookie — over similar-sounding adult "
    "names or proper nouns (Bonnie, Carrie, etc.). "
    "Do not invent people's names unless the child clearly said a name."
)

CLEANUP_SYSTEM = """You fix speech-to-text of a ~6-year-old child for a writing game.

The child speaks one short everyday sentence. Speech-to-text is unreliable on
kid voices: it swaps in similar-sounding adult words and names, and it takes
kid mispronunciations literally.

STEP 1 — Ask two questions about the sentence:
  (a) Does it make sense as something a young child would say about her own
      life? Judge each word IN CONTEXT, not in isolation. Every word can be a
      real English word and the sentence can still be wrong.
        "My Bonnie is so cute." → does NOT make sense (Bonnie is a stranger's
                                  name in "my ___"); she means her bunny.
        "I love my Bonnie."     → she means bunny.
        "My mommy is so cute."  → makes sense, leave it.
  (b) Is every word spelled the way a teacher would accept in writing? She is
      learning to WRITE, so baby-talk spellings must become the real word even
      when they are cute and the sentence reads fine:
        "The wabbit is fast."   → wabbit is not a word → "The rabbit is fast."
        "I saw a aminal."       → aminal is not a word → "I saw an animal."
        "I like pasghetti."     → "I like spaghetti."

STEP 2 — If both answers are yes, reply with exactly:
NO_CHANGE

Otherwise output the corrected sentence. Fix these kinds of errors:

1. Name-for-noun swaps. A child talking about "my ___" almost always means a
   pet, family member, or thing — not a proper name she never introduced.
   Bonnie/Bonny→bunny, Kitty (as a name)→kitty, Patty→potty, Molly→mommy.
   Prefer bunny, puppy, kitty, mommy, daddy, grandma, teacher, friend.
   Keep a real name only when she clearly marks it: "my friend Sam",
   "Mrs. Lee", "my dog is named Max".
2. Kid mispronunciation heard literally. Map to the word she meant:
   pasghetti/basketti→spaghetti, libary→library, aminal→animal,
   breffast→breakfast, wa-wa/wawa→water, nana→banana, brover→brother,
   sissy→sister, wed→red, wabbit→rabbit, thumthing→something,
   fank you→thank you, gimme→give me, member→remember.
3. Dropped or garbled sounds: cout→scout, oup→soup, tar→star (only when the
   token is not a real word, or the sentence is nonsense without the fix).
4. Missing tiny words (a, the, is, my) when the sentence cannot stand alone.

Rules:
- Change as few words as possible. Keep her meaning, her subject, her feeling.
- After a fix, repair only the grammar it broke (a → an, is → are).
- Never invent new details, people, or events she did not say.
- Do NOT change already-sensible real words: zoo, park, to, the, I, want, go.
- Output ONLY the one short sentence (max 8 words), no quotes, no explanation.
- Keep English unless the input is clearly Spanish.
- Kid-safe only.
- Capitalize the first word and titles (Dr., Mrs., Mr., Ms.). Do NOT capitalize
  ordinary nouns as if they were names (bunny, not Bonnie). End with . ! or ?
"""


# Deterministic fixes for clear non-words (llama is conservative by design).
# Do NOT map real words like park/zoo/top/un here.
S_DROP_FIXES = {
    "cout": "scout",
    "oup": "soup",
}

# ASR often prefers lookalike names over kid nouns (Bonny/Bonnie vs bunny).
# Prefer the everyday kid word unless we later add an explicit "name mode".
KID_NOUN_FIXES = {
    "bonny": "bunny",
    "bonnie": "bunny",
}

# Baby-talk spellings that are not English words. She is learning to write, so
# these always become the real word; qwen3 covers the rest in context.
KID_SPEECH_FIXES = {
    "aminal": "animal",
    "aminals": "animals",
    "pasghetti": "spaghetti",
    "basketti": "spaghetti",
    "libary": "library",
    "brover": "brother",
    "breffast": "breakfast",
    "wabbit": "rabbit",
    "thumthing": "something",
    "hostipal": "hospital",
    "elephent": "elephant",
    "buhsketball": "basketball",
}


def apply_known_speech_fixes(text: str) -> str:
    parts = re.findall(r"[A-Za-z']+|[^A-Za-z']+", text or "")
    out: list[str] = []
    for p in parts:
        key = p.lower()
        fixed = (
            S_DROP_FIXES.get(key)
            or KID_NOUN_FIXES.get(key)
            or KID_SPEECH_FIXES.get(key)
        )
        if fixed is not None:
            if p.isupper():
                out.append(fixed.upper())
            elif p[:1].isupper():
                # Mid-sentence names → lowercase kid noun; sentence start
                # capitalization is re-applied in apply_proper_capitalization.
                out.append(fixed)
            else:
                out.append(fixed)
        else:
            out.append(p)
    return "".join(out)


def apply_proper_capitalization(text: str) -> str:
    """Sentence case + common honorifics after ASR/cleanup."""
    t = re.sub(r"\s+", " ", (text or "").strip())
    if not t:
        return t
    honorifics = [
        (r"\bmr\b\.?", "Mr."),
        (r"\bmrs\b\.?", "Mrs."),
        (r"\bms\b\.?", "Ms."),
        (r"\bdr\b\.?", "Dr."),
        (r"\bprof\b\.?", "Prof."),
        (r"\bsr\b\.?", "Sr."),
        (r"\bjr\b\.?", "Jr."),
    ]
    for pat, repl in honorifics:
        t = re.sub(pat, repl, t, flags=re.IGNORECASE)

    def _cap_start(m: re.Match[str]) -> str:
        return m.group(1) + m.group(2).upper()

    t = re.sub(r"(^|[.!?]\s+)([a-z])", _cap_start, t)
    t = re.sub(r"\bi\b", "I", t)
    t = re.sub(r"\bi'm\b", "I'm", t, flags=re.IGNORECASE)
    t = re.sub(r"\bi've\b", "I've", t, flags=re.IGNORECASE)
    t = re.sub(r"\bi'll\b", "I'll", t, flags=re.IGNORECASE)
    return t


def finalize_sentence(text: str) -> str:
    t = apply_known_speech_fixes(strip_vo_echo(text or ""))
    t = re.sub(r"\s+", " ", t.strip())
    words = t.split(" ")
    if len(words) > 8:
        t = " ".join(words[:8])
    if t and t[-1] not in ".!?":
        t += "."
    return apply_proper_capitalization(t)


def looks_coherent(raw: str) -> bool:
    """True when ASR already looks like a fine kid sentence."""
    t = re.sub(r"\s+", " ", (raw or "").strip())
    if not t:
        return False
    core = re.sub(r"[.!?]+$", "", t).strip()
    words = core.split(" ")
    if not words or len(words) > 10:
        return False
    for w in words:
        w_clean = re.sub(r"[^A-Za-z']", "", w)
        if not w_clean:
            return False
        if len(w_clean) > 14:
            return False
        if re.search(r"[0-9]", w):
            return False
        # Known broken / baby-talk / name→noun tokens → let fixes + llama handle.
        if w_clean.lower() in S_DROP_FIXES or w_clean.lower() in KID_NOUN_FIXES:
            return False
        if w_clean.lower() in KID_SPEECH_FIXES:
            return False
    return any(re.search(r"[A-Za-z]", w) for w in words)


def _log(msg: str) -> None:
    print(f"[asr] {msg}", flush=True)


def get_whisper():
    global _whisper
    if _whisper is None:
        from faster_whisper import WhisperModel

        _log(f"loading Whisper model {ASR_MODEL} (cpu int8)…")
        t0 = time.time()
        # Prefer local HF cache — sandbox / proxy may block hub downloads.
        local = os.environ.get("ASR_MODEL_PATH", "").strip()
        if not local:
            # Common faster-whisper cache layout.
            hub = Path.home() / ".cache/huggingface/hub"
            cand = hub / f"models--Systran--faster-whisper-{ASR_MODEL}" / "snapshots"
            if cand.is_dir():
                snaps = sorted(cand.iterdir())
                if snaps:
                    local = str(snaps[-1])
        try:
            if local:
                _whisper = WhisperModel(local, device="cpu", compute_type="int8", local_files_only=True)
            else:
                _whisper = WhisperModel(ASR_MODEL, device="cpu", compute_type="int8")
        except Exception as e:
            _log(f"local load failed ({e}); trying hub name")
            _whisper = WhisperModel(ASR_MODEL, device="cpu", compute_type="int8")
        _log(f"Whisper ready in {time.time() - t0:.1f}s")
    return _whisper


def _audio_stats(path: str) -> str:
    try:
        size = Path(path).stat().st_size
    except OSError:
        return "missing"
    # Parse wav header lightly for duration.
    try:
        import wave

        with wave.open(path, "rb") as w:
            frames = w.getnframes()
            rate = w.getframerate() or 1
            ch = w.getnchannels()
            sw = w.getsampwidth()
            dur = frames / float(rate)
            return f"{size}B {dur:.2f}s {rate}Hz {ch}ch {sw * 8}bit"
    except Exception:
        return f"{size}B"


def _keep_debug_copy(path: str | None, tag: str) -> None:
    if not path:
        return
    dbg = Path(os.environ.get("ASR_DEBUG_DIR", "/tmp/lang_asr_debug"))
    try:
        dbg.mkdir(parents=True, exist_ok=True)
        dest = dbg / f"{int(time.time() * 1000)}_{tag}{Path(path).suffix or '.wav'}"
        dest.write_bytes(Path(path).read_bytes())
        _log(f"kept {dest}")
    except OSError as e:
        _log(f"debug keep failed: {e}")


def _rms_peak(path: str) -> tuple[float, int]:
    try:
        import struct
        import wave

        with wave.open(path, "rb") as w:
            sw = w.getsampwidth()
            raw = w.readframes(w.getnframes())
        if sw != 2 or not raw:
            return 0.0, 0
        samples = struct.unpack("<" + "h" * (len(raw) // 2), raw)
        peak = max(abs(s) for s in samples) if samples else 0
        rms = (sum(s * s for s in samples) / max(1, len(samples))) ** 0.5
        return float(rms), int(peak)
    except Exception:
        return 0.0, 0


COMMAND_MIN_PEAK = int(os.environ.get("ASR_COMMAND_MIN_PEAK", "280"))
COMMAND_TARGET_PEAK = int(os.environ.get("ASR_COMMAND_TARGET_PEAK", "10000"))


def _amplify_wav(path: str, target_peak: int = COMMAND_TARGET_PEAK) -> str:
    """Boost quiet phone clips so Whisper hears soft 'next' without shouting."""
    try:
        import struct
        import wave
    except ImportError:
        return path
    try:
        with wave.open(path, "rb") as w:
            params = w.getparams()
            raw = w.readframes(w.getnframes())
    except Exception:
        return path
    if params.sampwidth != 2 or not raw:
        return path
    samples = list(struct.unpack("<" + "h" * (len(raw) // 2), raw))
    peak = max((abs(s) for s in samples), default=0)
    if peak < 1:
        return path
    gain = min(target_peak / peak, 32767 / peak)
    if gain <= 1.05:
        return path
    boosted = [max(-32767, min(32767, int(s * gain))) for s in samples]
    fd, out = tempfile.mkstemp(prefix="asr_boost_", suffix=".wav")
    os.close(fd)
    with wave.open(out, "wb") as w:
        w.setparams(params)
        w.writeframes(struct.pack("<" + "h" * len(boosted), *boosted))
    _log(f"amplified peak {peak} → ~{int(peak * gain)} ({gain:.1f}x)")
    return out


def transcribe_file(
    path: str,
    *,
    initial_prompt: str | None = None,
    min_peak: int | None = None,
    beam_size: int = 1,
    no_speech_threshold: float | None = None,
) -> str:
    model = get_whisper()
    # VAD off by default: phone kid mics often look "quiet" and VAD wiped the zoo
    # phrase to empty (HTTP 200 + ok:false). Opt in with ASR_VAD=1.
    use_vad = os.environ.get("ASR_VAD", "0") == "1"
    kwargs: dict[str, Any] = {
        "beam_size": beam_size,
        "vad_filter": use_vad,
        "language": "en",
    }
    if no_speech_threshold is not None:
        kwargs["no_speech_threshold"] = no_speech_threshold
    if initial_prompt:
        kwargs["initial_prompt"] = initial_prompt
    _log(f"transcribe {_audio_stats(path)} vad={int(use_vad)}")
    rms, peak = _rms_peak(path)
    _log(f"audio level rms={rms:.1f} peak={peak}")
    floor = COMMAND_MIN_PEAK if min_peak is None else min_peak
    if peak < floor:
        _log(f"audio too quiet (peak {peak} < {floor})")
        return ""
    segments, _info = model.transcribe(path, **kwargs)
    parts = [s.text.strip() for s in segments if s.text and s.text.strip()]
    text = " ".join(parts).strip()
    _log(f"whisper → {text!r}" if text else "whisper → (empty)")
    return text


def transcribe_command(path: str) -> str:
    """Transcribe a short next/back utterance; boost gain before Whisper."""
    _orig_rms, orig_peak = _rms_peak(path)
    boosted = _amplify_wav(path)
    _boost_rms, boost_peak = _rms_peak(boosted)
    _log(
        f"CMD audio orig_peak={orig_peak} boost_peak={boost_peak} "
        f"floor={COMMAND_MIN_PEAK}"
    )
    try:
        text = transcribe_file(
            boosted,
            initial_prompt="The child said next or back.",
            min_peak=COMMAND_MIN_PEAK,
            beam_size=3,
            no_speech_threshold=0.35,
        )
        _log(f"CMD whisper={text!r}")
        return text
    finally:
        if boosted != path:
            try:
                Path(boosted).unlink(missing_ok=True)
            except OSError:
                pass


def ollama_cleanup(raw: str, lang: str = "en") -> str:
    raw = (raw or "").strip()
    if not raw:
        return ""
    user = (
        f"Language hint: {lang}\n"
        f"Child's speech-to-text:\n{raw}\n\n"
        "Does this make sense as something a young child would say? "
        "If yes, reply exactly NO_CHANGE. If not, reply with the corrected "
        "sentence only:"
    )
    body = {
        "model": OLLAMA_MODEL,
        "stream": False,
        "think": OLLAMA_THINK,
        "keep_alive": "30m",
        "messages": [
            {"role": "system", "content": CLEANUP_SYSTEM},
            {"role": "user", "content": user},
        ],
        "options": {"temperature": 0.0, "num_predict": 64},
    }
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/chat",
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as resp:
            data = json.loads(resp.read().decode("utf-8", errors="replace"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
        _log(f"ollama cleanup failed: {e}; using raw")
        return finalize_sentence(raw)
    msg = (data.get("message") or {}).get("content") or ""
    cleaned = _normalize_sentence(msg)
    compact = re.sub(r"[^A-Za-z]", "", cleaned).upper()
    if compact in ("NOCHANGE", "NOCHANGES", "UNCHANGED", "SAME", "OK"):
        kept = finalize_sentence(raw)
        _log(f"cleanup NO_CHANGE → {kept!r}")
        return kept
    if not cleaned:
        return finalize_sentence(raw)
    # Targeted swaps (Bonnie→bunny) are the point; only block wholesale rewrites.
    if not _is_minimal_edit(raw, cleaned):
        _log(f"cleanup rejected wholesale rewrite {raw!r} → {cleaned!r}; keeping raw")
        return finalize_sentence(raw)
    return finalize_sentence(cleaned)


def _is_minimal_edit(raw: str, cleaned: str, max_changed: int = 2) -> bool:
    """True when cleaned looks like a few word fixes, not a new sentence."""
    raw_words = re.findall(r"[a-z']+", finalize_sentence(raw).lower())
    new_words = re.findall(r"[a-z']+", cleaned.lower())
    if not raw_words or not new_words:
        return bool(new_words)
    if abs(len(new_words) - len(raw_words)) > max_changed:
        return False
    kept = len(set(raw_words) & set(new_words))
    changed = max(len(raw_words), len(new_words)) - kept
    return changed <= max_changed


def _normalize_sentence(text: str) -> str:
    t = (text or "").strip()
    # Reasoning models may still emit a think block even with think disabled.
    t = re.sub(r"<think>.*?</think>", " ", t, flags=re.DOTALL | re.IGNORECASE).strip()
    t = re.sub(r"^<think>.*$", "", t, flags=re.DOTALL | re.IGNORECASE).strip()
    t = t.strip('"').strip("'").strip()
    low = t.lower().strip()
    if low in ("no_change", "no change", "nochange", "unchanged", "same"):
        return "NO_CHANGE"
    for prefix in ("rewritten kid sentence:", "sentence:", "here:", "output:"):
        if low.startswith(prefix):
            t = t[len(prefix) :].strip()
            low = t.lower().strip()
            break
    if low in ("no_change", "no change", "nochange"):
        return "NO_CHANGE"
    t = re.sub(r"\s+", " ", t)
    words = t.split(" ")
    if len(words) > 8:
        t = " ".join(words[:8])
    if t and t[-1] not in ".!?":
        t += "."
    return t


def strip_vo_echo(text: str) -> str:
    """Remove leaked coaching VO the phone speakers often bleed into the mic."""
    t = re.sub(r"\s+", " ", (text or "").strip())
    if not t:
        return ""
    # Leading fragments from "Tap the microphone…", "Got it!", "One moment.", etc.
    prefixes = (
        r"^tap the microphone(?: and say[^.!]*)?[.!,]?\s*",
        r"^tap(?: the mic(?:rophone)?)?[.!,]?\s*",
        r"^got it[.!,]?\s*",
        r"^one moment[.!,]?\s*",
        r"^i'?m listening[.!,]?\s*",
        r"^te escucho[.!,]?\s*",
        r"^un momento[.!,]?\s*",
        r"^listo[.!,]?\s*",
        r"^primera letra[.!,]?\s*",
        r"^first letter[.!,]?\s*",
    )
    changed = True
    while changed and t:
        changed = False
        for pat in prefixes:
            new = re.sub(pat, "", t, flags=re.IGNORECASE).strip()
            if new != t:
                t = new
                changed = True
                break
    # Drop a lone leading "Tap." sentence before the real idea.
    t = re.sub(r"^tap\s*[.!]+\s*", "", t, flags=re.IGNORECASE).strip()
    return t


def _fallback_sentence(raw: str) -> str:
    return finalize_sentence(raw)


def letters_for_sentence(text: str) -> list[str]:
    """Spellable letters with case preserved; skip spaces/punct."""
    out: list[str] = []
    for ch in text:
        if ch.isalpha():
            out.append(ch)
    return out[:40]


def classify_command(text: str) -> str:
    t = re.sub(r"[^a-z\s]", "", (text or "").lower()).strip()
    if not t:
        return "none"
    # Prefer whole-word hits.
    tokens = t.split()
    for tok in tokens:
        if tok in (
            "next", "nex", "net", "neks", "nekst", "nxt", "nest", "necks", "neckst",
            "text", "nexx", "nextt",
        ):
            return "next"
        if tok in ("back", "bak", "beck", "beckk", "beckwards"):
            return "back"
    if "next" in t:
        return "next"
    if "back" in t:
        return "back"
    return "none"


# --- multipart (stdlib, no flask) ---------------------------------------------

def _parse_multipart(handler: BaseHTTPRequestHandler) -> dict[str, Any]:
    ctype = handler.headers.get("Content-Type", "")
    length = int(handler.headers.get("Content-Length", "0") or 0)
    body = handler.rfile.read(length) if length > 0 else b""
    if "multipart/form-data" not in ctype:
        return {"_raw": body, "_fields": {}}
    m = re.search(r"boundary=(.+)", ctype)
    if not m:
        return {"_raw": body, "_fields": {}}
    boundary = m.group(1).strip().encode("utf-8")
    if boundary.startswith(b'"') and boundary.endswith(b'"'):
        boundary = boundary[1:-1]
    fields: dict[str, Any] = {}
    for part in body.split(b"--" + boundary):
        if not part or part in (b"--\r\n", b"--"):
            continue
        if part.startswith(b"\r\n"):
            part = part[2:]
        if part.endswith(b"\r\n"):
            part = part[:-2]
        if b"\r\n\r\n" not in part:
            continue
        header_blob, data = part.split(b"\r\n\r\n", 1)
        if data.endswith(b"\r\n"):
            data = data[:-2]
        headers = header_blob.decode("utf-8", errors="replace")
        name_m = re.search(r'name="([^"]+)"', headers)
        if not name_m:
            continue
        name = name_m.group(1)
        filename_m = re.search(r'filename="([^"]*)"', headers)
        if filename_m is not None:
            fields[name] = {"filename": filename_m.group(1), "data": data}
        else:
            fields[name] = data.decode("utf-8", errors="replace")
    return {"_raw": body, "_fields": fields}


def _save_audio_field(fields: dict[str, Any], key: str = "audio") -> str | None:
    item = fields.get(key)
    if not isinstance(item, dict) or not item.get("data"):
        return None
    data: bytes = item["data"]
    filename = str(item.get("filename") or "audio.wav")
    suffix = Path(filename).suffix or ".wav"
    fd, path = tempfile.mkstemp(prefix="asr_", suffix=suffix)
    os.close(fd)
    Path(path).write_bytes(data)
    return path


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args) -> None:
        _log("%s - %s" % (self.address_string(), fmt % args))

    def _send_json(self, code: int, payload: dict) -> None:
        raw = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(raw)

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()

    def do_GET(self) -> None:
        if self.path.rstrip("/") in ("/health", "/v1/health"):
            self._send_json(
                200,
                {
                    "ok": True,
                    "model": ASR_MODEL,
                    "ollama": OLLAMA_MODEL,
                    "ollama_url": OLLAMA_URL,
                },
            )
            return
        self._send_json(404, {"error": "not found"})

    def do_POST(self) -> None:
        path = self.path.split("?", 1)[0].rstrip("/")
        parsed = _parse_multipart(self)
        fields = parsed.get("_fields") or {}
        audio_path = _save_audio_field(fields, "audio")
        try:
            if path.endswith("/v1/transcribe"):
                self._handle_transcribe(audio_path, fields)
            elif path.endswith("/v1/voice_write"):
                self._handle_voice_write(audio_path, fields)
            elif path.endswith("/v1/command"):
                self._handle_command(audio_path, fields)
            else:
                self._send_json(404, {"error": "not found"})
        finally:
            if audio_path and DELETE_UPLOADS:
                try:
                    os.unlink(audio_path)
                except OSError:
                    pass

    def _handle_transcribe(self, audio_path: str | None, fields: dict) -> None:
        if not audio_path:
            self._send_json(400, {"error": "missing audio"})
            return
        text = transcribe_file(audio_path)
        lang = str(fields.get("lang") or "en")
        self._send_json(200, {"text": text, "lang": lang, "raw": text})

    def _handle_voice_write(self, audio_path: str | None, fields: dict) -> None:
        if not audio_path:
            self._send_json(400, {"error": "missing audio"})
            return
        lang = str(fields.get("lang") or "en")
        raw = strip_vo_echo(
            transcribe_file(
                audio_path,
                initial_prompt=VOICE_WRITE_PROMPT,
                beam_size=3,
            )
        )
        text = ollama_cleanup(raw, lang=lang) if raw else ""
        if raw and text:
            _log(f"cleanup → {text!r}")
        letters = letters_for_sentence(text)
        if not letters:
            _keep_debug_copy(audio_path, "empty_voice_write")
            self._send_json(
                200,
                {
                    "ok": False,
                    "raw": raw,
                    "text": "",
                    "letters": [],
                    "error": "empty",
                },
            )
            return
        self._send_json(
            200,
            {
                "ok": True,
                "raw": raw,
                "text": text,
                "letters": letters,
                "lang": lang,
            },
        )

    def _handle_command(self, audio_path: str | None, fields: dict) -> None:
        if not audio_path:
            self._send_json(400, {"error": "missing audio", "command": "none"})
            return
        text = transcribe_command(audio_path)
        cmd = classify_command(text)
        _log(f"CMD → {cmd!r}")
        if cmd == "none":
            _keep_debug_copy(audio_path, "cmd_none")
        self._send_json(200, {"command": cmd, "text": text})

def main() -> None:
    # Warm models so the first kid tap is not a cold start.
    get_whisper()
    try:
        ollama_cleanup("I want a cout badge.", "en")
        _log("ollama cleanup warm ok")
    except Exception as e:
        _log(f"ollama warm skipped: {e}")

    server = ThreadingHTTPServer((HOST, PORT), Handler)
    _log(f"listening on http://{HOST}:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        _log("bye")


if __name__ == "__main__":
    main()
