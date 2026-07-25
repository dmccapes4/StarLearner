#!/usr/bin/env python3
"""Build educational .ogv clips: real footage + warm ElevenLabs narration.

Footage priority per manifest item:
  1. tools/media_src/footage/<id>.(mp4|webm|mov|ogv|mkv)  — user drop-ins
     (e.g. downloaded from Pexels/Pixabay, license-free)
  2. commons_title                                        — auto-downloaded
     from Wikimedia Commons (CC/PD)
  3. Ken-Burns pan over the game portrait                 — always works

Also builds harvest videos for any footage at
tools/media_src/footage/harvest_<plant>.(...) using manifest harvest_scripts,
writing to game/assets/plants/<plant>_harvest.ogv and patching seeds.json
media entries.

Usage: ./tools/build_edu_videos.py [--only id1,id2]
"""
from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "tools" / "media_manifest.json"
FOOTAGE = ROOT / "tools" / "media_src" / "footage"
VO_CACHE = ROOT / "tools" / "media_src" / "vo_cache"
SEEDS_JSON = ROOT / "game" / "data" / "seeds.json"
FOOT_EXTS = [".mp4", ".webm", ".mov", ".ogv", ".mkv"]
SIZE_W, SIZE_H = 960, 540
SIZE = f"{SIZE_W}x{SIZE_H}"
UA = {"User-Agent": "GardenExplorer/1.0 (family education project)"}

sys.path.insert(0, str(ROOT / "tools"))
import gen_garden_vo as vo  # noqa: E402  (reuse ElevenLabs synth + secrets)


def sh(*cmd: str) -> None:
    subprocess.run(cmd, check=True, capture_output=True)


def narration_wav(text: str) -> Path:
    """Synthesize (once) and cache narration audio for a script."""
    VO_CACHE.mkdir(parents=True, exist_ok=True)
    key = hashlib.md5(text.encode()).hexdigest()
    wav = VO_CACHE / f"{key}.wav"
    if wav.exists():
        return wav
    mp3 = VO_CACHE / f"{key}.mp3"
    vo.load_secrets()
    vo.synth_mp3(text, mp3)
    sh("ffmpeg", "-y", "-i", str(mp3), "-ar", "44100", "-ac", "1", str(wav))
    mp3.unlink(missing_ok=True)
    return wav


def audio_seconds(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "quiet", "-show_entries", "format=duration",
         "-of", "csv=p=0", str(path)],
        check=True, capture_output=True, text=True)
    return float(out.stdout.strip())


def find_local_footage(vid_id: str) -> Path | None:
    for ext in FOOT_EXTS:
        p = FOOTAGE / f"{vid_id}{ext}"
        if p.exists():
            return p
    return None


def download_commons(title: str, vid_id: str) -> Path | None:
    """Resolve a Commons File: title to its direct URL and download it."""
    api = ("https://commons.wikimedia.org/w/api.php?action=query&format=json"
           "&prop=imageinfo&iiprop=url&titles=" + urllib.parse.quote(title))
    url = None
    for attempt in range(4):
        try:
            req = urllib.request.Request(api, headers=UA)
            data = json.loads(urllib.request.urlopen(req, timeout=30).read())
            pages = data["query"]["pages"]
            url = next(iter(pages.values()))["imageinfo"][0]["url"]
            break
        except Exception as e:  # noqa: BLE001
            if attempt == 3:
                print(f"  commons lookup failed for {title}: {e}")
                return None
            time.sleep(3.0 * (attempt + 1))
    ext = Path(urllib.parse.urlparse(url).path).suffix or ".webm"
    dest = FOOTAGE / f"{vid_id}{ext}"
    FOOTAGE.mkdir(parents=True, exist_ok=True)
    try:
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=180) as r, open(dest, "wb") as f:
            shutil.copyfileobj(r, f)
        print(f"  downloaded {title} → {dest.name} ({dest.stat().st_size // 1024} KB)")
        return dest
    except Exception as e:  # noqa: BLE001
        print(f"  commons download failed: {e}")
        dest.unlink(missing_ok=True)
        return None


def build_from_footage(footage: Path, wav: Path, out: Path, dur: float) -> None:
    """Loop/trim footage to narration length; replace audio with narration."""
    sh("ffmpeg", "-y",
       "-stream_loop", "-1", "-i", str(footage),
       "-i", str(wav),
       "-t", f"{dur:.2f}",
       "-vf", f"scale={SIZE_W}:{SIZE_H}:force_original_aspect_ratio=increase,"
              f"crop={SIZE_W}:{SIZE_H},fps=24",
       "-map", "0:v:0", "-map", "1:a:0",
       "-c:v", "libtheora", "-q:v", "6",
       "-c:a", "libvorbis", "-q:a", "4",
       str(out))


def build_ken_burns(portrait: Path, wav: Path, out: Path, dur: float) -> None:
    """Gentle zoom over the portrait on a soft garden-green backdrop."""
    frames = int(dur * 24) + 1
    ## Single input frame → zoompan generates all output frames (d=frames).
    vf = (f"scale=1920:1080:force_original_aspect_ratio=decrease,"
          f"pad=1920:1080:(ow-iw)/2:(oh-ih)/2:0x2E4A2E,"
          f"zoompan=z='1.02+0.10*on/{frames}':d={frames}"
          f":x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s={SIZE}:fps=24")
    sh("ffmpeg", "-y",
       "-i", str(portrait),
       "-i", str(wav),
       "-t", f"{dur:.2f}",
       "-vf", vf,
       "-map", "0:v:0", "-map", "1:a:0",
       "-c:v", "libtheora", "-q:v", "6",
       "-c:a", "libvorbis", "-q:a", "4",
       str(out))


def build_item(item: dict) -> None:
    vid_id = item["id"]
    out = ROOT / item["out"]
    out.parent.mkdir(parents=True, exist_ok=True)
    print(f"[{vid_id}]")
    wav = narration_wav(item["script"])
    dur = audio_seconds(wav) + 1.6
    footage = find_local_footage(vid_id)
    if footage is None and item.get("commons_title"):
        footage = download_commons(item["commons_title"], vid_id)
    if footage is not None:
        build_from_footage(footage, wav, out, dur)
        print(f"  footage → {out.name}")
    else:
        portrait = ROOT / item["portrait"]
        build_ken_burns(portrait, wav, out, dur)
        print(f"  ken-burns portrait → {out.name}")


def build_harvests(scripts: dict) -> None:
    """Build harvest clips for whichever plants have drop-in footage."""
    changed = False
    seeds = json.loads(SEEDS_JSON.read_text())
    plants = seeds.get("plants", [])
    by_id = {p.get("id"): p for p in plants if isinstance(p, dict)}
    for pid, script in scripts.items():
        footage = find_local_footage(f"harvest_{pid}")
        if footage is None:
            continue
        out = ROOT / "game" / "assets" / "plants" / f"{pid}_harvest.ogv"
        wav = narration_wav(script)
        dur = audio_seconds(wav) + 1.6
        build_from_footage(footage, wav, out, dur)
        print(f"[harvest_{pid}] footage → {out.name}")
        plant = by_id.get(pid)
        if isinstance(plant, dict):
            media = plant.setdefault("media", {})
            media["harvest"] = {"file": f"{pid}_harvest.ogv", "type": "video"}
            changed = True
    if changed:
        SEEDS_JSON.write_text(json.dumps(seeds, indent=2) + "\n")
        print("patched seeds.json media entries")


def main() -> None:
    only = None
    if len(sys.argv) > 2 and sys.argv[1] == "--only":
        only = set(sys.argv[2].split(","))
    manifest = json.loads(MANIFEST.read_text())
    for item in manifest["items"]:
        if only and item["id"] not in only:
            continue
        try:
            build_item(item)
        except subprocess.CalledProcessError as e:
            print(f"  FAILED {item['id']}: {e.stderr.decode()[-400:] if e.stderr else e}")
    build_harvests(manifest.get("harvest_scripts", {}))
    print("done")


if __name__ == "__main__":
    main()
