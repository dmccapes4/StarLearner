#!/usr/bin/env python3
"""Generate calm narration WAVs for Star Learner using ElevenLabs.

Reads:
  game/data/role_vo.json     -> assets/audio/vo/roles/<key>.wav
  game/data/chamber_vo.json  -> assets/audio/vo/<zone>.wav
  game/data/intro_vo.json    -> assets/audio/vo/intro.wav
  game/data/star_vo.json     -> assets/audio/vo/stars/<id>.wav
  game/data/trail_vo.json    -> assets/audio/vo/trails/<role>.wav
  game/data/tunnel_vo.json   -> assets/audio/vo/tunnel.wav

Output: 16-bit PCM mono WAV (what VoStream.gd parses) + optional .ogg.
Only uses the Python stdlib + ffmpeg (no pip installs).

Auth: ELEVENLABS_API_KEY in env, or tools/secrets/elevenlabs.env
      (KEY=VALUE lines; gitignored).

Voice (warm female, override via env):
  ELEVEN_VOICE_ID   default Matilda (XrExE9yKIg1WjnnlVkGX) — warm narrator
    alternates: Sarah EXAVITQu4vr4xnSDxMaL (soft), Rachel 21m00Tcm4TlvDq8ikWAM,
                Alice Xb7hH8MSUJpSbSDYk0k2, Charlotte XB0fDUnXU5powFXDhCwa
  ELEVEN_MODEL      default eleven_multilingual_v2 (stable). Use eleven_v3 for max realism.
  ELEVEN_SPEED      default 0.92 (slightly slow = calmer)
  ELEVEN_STABILITY  default 0.55
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
DATA = GAME / "data"
VO_DIR = GAME / "assets" / "audio" / "vo"
ROLES_DIR = VO_DIR / "roles"
STARS_DIR = VO_DIR / "stars"
TRAILS_DIR = VO_DIR / "trails"
INTRO_DIR = VO_DIR / "intro"
SECRETS = ROOT / "tools" / "secrets" / "elevenlabs.env"

API_BASE = "https://api.elevenlabs.io/v1/text-to-speech"


def load_secrets() -> None:
    if SECRETS.exists():
        for line in SECRETS.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def api_key() -> str:
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not key:
        sys.exit(
            "ERROR: ELEVENLABS_API_KEY not set.\n"
            f"  Put it in {SECRETS} as:  ELEVENLABS_API_KEY=sk_...\n"
            "  (that folder is gitignored) — or export it in your shell."
        )
    return key


def synth_mp3(text: str, out_mp3: Path) -> None:
    voice = os.environ.get("ELEVEN_VOICE_ID", "XrExE9yKIg1WjnnlVkGX")
    model = os.environ.get("ELEVEN_MODEL", "eleven_multilingual_v2")
    speed = float(os.environ.get("ELEVEN_SPEED", "0.92"))
    stability = float(os.environ.get("ELEVEN_STABILITY", "0.55"))
    payload = {
        "text": text,
        "model_id": model,
        "voice_settings": {
            "stability": stability,
            "similarity_boost": 0.75,
            "style": 0.0,
            "use_speaker_boost": True,
            "speed": speed,
        },
    }
    url = f"{API_BASE}/{voice}?output_format=mp3_44100_128"
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "xi-api-key": api_key(),
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            out_mp3.write_bytes(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:400]
        sys.exit(f"ERROR: ElevenLabs {e.code} for '{text[:40]}...': {body}")


def to_wav_ogg(mp3: Path, wav: Path, make_ogg: bool) -> None:
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
         "-i", str(mp3), "-ac", "1", "-ar", "22050",
         "-c:a", "pcm_s16le", str(wav)],
        check=True,
    )
    if make_ogg:
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
             "-i", str(mp3), "-ac", "1", "-ar", "22050",
             "-c:a", "libvorbis", "-q:a", "4", str(wav.with_suffix(".ogg"))],
            check=True,
        )


def gen(entries: dict[str, str], out_dir: Path, make_ogg: bool) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    n = 0
    with tempfile.TemporaryDirectory() as td:
        for key, text in entries.items():
            text = text.strip()
            if not text:
                print(f"  skip {key}: empty")
                continue
            mp3 = Path(td) / f"{key}.mp3"
            wav = out_dir / f"{key}.wav"
            print(f"  synth {key} -> {wav.name}")
            synth_mp3(text, mp3)
            to_wav_ogg(mp3, wav, make_ogg)
            n += 1
    return n


def gen_single(key: str, text: str, wav_path: Path, make_ogg: bool) -> int:
    text = text.strip()
    if not text:
        print(f"  skip {key}: empty")
        return 0
    wav_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        mp3 = Path(td) / f"{key}.mp3"
        print(f"  synth {key} -> {wav_path.name}")
        synth_mp3(text, mp3)
        to_wav_ogg(mp3, wav_path, make_ogg)
    return 1


def role_entries() -> dict[str, str]:
    data = json.loads((DATA / "role_vo.json").read_text(encoding="utf-8"))
    out = {}
    for key, e in data.get("roles", {}).items():
        out[key] = " ".join(
            str(e.get(k, "")).strip() for k in ("line1", "line2", "line3")
        ).strip()
    return out


def chamber_entries() -> dict[str, str]:
    data = json.loads((DATA / "chamber_vo.json").read_text(encoding="utf-8"))
    out = {}
    for zone, e in data.get("chambers", {}).items():
        out[zone] = " ".join(
            str(e.get(k, "")).strip() for k in ("line1", "line2")
        ).strip()
    return out


def trail_entries() -> dict[str, str]:
    data = json.loads((DATA / "trail_vo.json").read_text(encoding="utf-8"))
    return {str(k): str(v).strip() for k, v in data.get("trails", {}).items()}


def tunnel_entries() -> dict[str, str]:
    data = json.loads((DATA / "tunnel_vo.json").read_text(encoding="utf-8"))
    text = str(data.get("tunnel", {}).get("text", "")).strip()
    return {"tunnel": text} if text else {}


def intro_entries() -> dict[str, str]:
    """One clip per intro line (key -> text). Falls back to the legacy
    line1/line2/line3 single-clip shape if `lines` is absent."""
    data = json.loads((DATA / "intro_vo.json").read_text(encoding="utf-8"))
    intro = data.get("intro", {})
    out: dict[str, str] = {}
    lines = intro.get("lines")
    if isinstance(lines, list):
        for ln in lines:
            key = str(ln.get("key", "")).strip()
            text = str(ln.get("text", "")).strip()
            if key and text:
                out[key] = text
        return out
    combined = " ".join(
        str(intro.get(k, "")).strip() for k in ("line1", "line2", "line3")
    ).strip()
    if combined:
        out["intro"] = combined
    return out


def star_entries() -> dict[str, str]:
    vo = json.loads((DATA / "star_vo.json").read_text(encoding="utf-8"))
    stars_data = json.loads((DATA / "stars.json").read_text(encoding="utf-8"))
    line1 = str(vo.get("line1", "You found a knowledge star!")).strip()
    topics: dict[str, str] = {}
    for entry in stars_data.get("stars", []):
        sid = str(entry.get("id", ""))
        topic = str(entry.get("topic", "")).strip()
        if sid and topic:
            topics[sid] = topic
    custom: dict[str, str] = vo.get("stars", {})
    out: dict[str, str] = {}
    for sid, line2 in custom.items():
        topic = topics.get(sid, "")
        if topic and topic.lower() not in line2.lower():
            text = f"{line1} {line2}"
        else:
            text = f"{line1} {line2}"
        out[sid] = text.strip()
    for sid, topic in topics.items():
        if sid not in out:
            out[sid] = f"{line1} This star is about {topic}."
    return out


def main() -> None:
    load_secrets()
    args = set(sys.argv[1:])
    make_ogg = "--ogg" in args
    explicit = args & {"--roles", "--chambers", "--intro", "--stars", "--trails", "--tunnels"}
    do_all = "--all" in args or not explicit
    do_roles = do_all or "--roles" in args
    do_chambers = do_all or "--chambers" in args
    do_intro = do_all or "--intro" in args
    do_stars = do_all or "--stars" in args
    do_trails = do_all or "--trails" in args
    do_tunnels = do_all or "--tunnels" in args

    total = 0
    if do_roles:
        print("Roles:")
        total += gen(role_entries(), ROLES_DIR, make_ogg)
    if do_trails:
        print("Trails:")
        total += gen(trail_entries(), TRAILS_DIR, make_ogg)
    if do_chambers:
        print("Chambers:")
        total += gen(chamber_entries(), VO_DIR, make_ogg)
    if do_intro:
        print("Intro:")
        total += gen(intro_entries(), INTRO_DIR, make_ogg)
    if do_stars:
        print("Stars:")
        total += gen(star_entries(), STARS_DIR, make_ogg)
    if do_tunnels:
        print("Tunnels:")
        total += gen(tunnel_entries(), VO_DIR, make_ogg)
    print(f"\nDone. {total} clips → {VO_DIR}")
    print("VoStream loads these WAVs at runtime (no godot --import needed).")


if __name__ == "__main__":
    main()
