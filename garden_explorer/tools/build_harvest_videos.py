#!/usr/bin/env python3
"""Build REAL harvest videos for every plant — same pipeline as bug/animal clips.

Priority per plant:
  1. tools/harvest_picks.json override (hand-curated Commons title)
  2. Best scored video from harvest_candidates.json (junk-filtered)
  3. Best scored photo(s) → Ken-Burns montage
  4. Skip (leave seeds.json on slides)

Downloads into tools/media_src/footage/harvest_<id>.*
Writes game/assets/plants/<id>_harvest.ogv
Patches seeds.json media.harvest → type video.

Usage:
  ./tools/build_harvest_videos.py                 # all plants
  ./tools/build_harvest_videos.py melon carrot    # only these
  ./tools/build_harvest_videos.py --dry-run
"""
from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CANDIDATES = ROOT / "tools" / "harvest_candidates.json"
PICKS = ROOT / "tools" / "harvest_picks.json"
MANIFEST = ROOT / "tools" / "media_manifest.json"
SEEDS_JSON = ROOT / "game" / "data" / "seeds.json"
FOOTAGE = ROOT / "tools" / "media_src" / "footage"
VO_CACHE = ROOT / "tools" / "media_src" / "vo_cache"
OUT_DIR = ROOT / "game" / "assets" / "plants"
SIZE_W, SIZE_H = 960, 540
UA = {"User-Agent": "GardenExplorer/1.0 (family education project)"}
REQUEST_GAP_S = 2.0
_last_req = 0.0

sys.path.insert(0, str(ROOT / "tools"))
import gen_garden_vo as vo  # noqa: E402

JUNK = (
    "painting", "segantini", "aerogarden", "space tomato", "missing space",
    "food demo", "farmers market-food", "pronunciation", "weedy oats",
    "un-ripe", "unripe", "giganteum", "bread company", "coin", "stamp",
    "coat of arms", "cartoon", "diagram", "recipe", "cooking", "salad bowl",
)


## Kid-friendly VO for every crop — mirrors harvest_scripts style.
HARVEST_SCRIPTS: dict[str, str] = {
    "carrot": "Crunchy carrots grow under the ground. Farmers hold the green leafy tops and pull gently until the carrot pops out. Carrots are full of vitamin A, which helps your eyes see well. Rabbits agree — carrots are delicious!",
    "tomato": "Tomatoes turn from green to bright red as they ripen in the sun. Farmers twist them gently off the vine so the plant keeps growing more. Tomatoes are full of vitamins that keep your heart strong. We eat them in salads, sauces, and soups!",
    "lettuce": "Lettuce grows in leafy green bundles. Farmers cut the whole head close to the soil with a small knife. Lettuce is mostly water, so it is extra crunchy and fresh. It is the start of almost every salad!",
    "strawberry": "Strawberries are ready when they turn ruby red all over. Farmers pinch the stem so the soft berry does not get squished. Strawberries have more vitamin C than oranges! They are the only fruit with seeds on the outside.",
    "pumpkin": "Pumpkins grow on long vines that crawl across the ground. Farmers cut the thick stem and leave a little handle on top. Pumpkins can grow bigger than you! We eat them in pies and soups, and carve them for fun.",
    "corn": "Corn grows taller than a grown-up! Each ear is wrapped in a leafy husk with silky threads on top. Farmers snap the ear down and twist to pick it. Every silk thread is connected to one kernel of corn!",
    "pea": "Peas grow in little green pods that hang from climbing vines. Farmers pick the pods when they feel plump and full. Pop one open — the peas sit in a row like beads! Peas give you energy to run and play.",
    "radish": "Radishes are one of the fastest vegetables to grow — about one month! Farmers pull them up by their leaves, just like carrots. They are crunchy with a tiny spicy zing. Radishes come in red, pink, purple, and even white!",
    "melon": "Melons grow on vines that sprawl across the warm soil. Farmers know a melon is ready when it smells sweet and the stem slips off easily. Inside is juicy fruit that cools you down on a hot day. Melons are mostly water — and kids love them!",
    "spinach": "Spinach has soft dark-green leaves packed with iron. Farmers cut the outer leaves so the plant keeps growing in the middle. Spinach helps your muscles stay strong. Popeye was right — spinach is a power food!",
    "onion": "Onions grow underground in layers, like a tiny ball. Farmers wait until the green tops flop over, then dig them up carefully. Onions make soups and sauces taste amazing. They can also make your eyes water!",
    "cabbage": "A cabbage is a big round ball of tightly packed leaves. Farmers cut the thick stem at the bottom and lift the whole head. Cabbage stays fresh a long time. We eat it in salads, soups, and even sauerkraut!",
    "cucumber": "Cucumbers hang from vines like little green boats. Farmers snip them off while they are still firm and crunchy. Cucumbers are cool and refreshing — almost all water. They are perfect for a summer snack!",
    "bean": "Beans grow in long pods on climbing vines or bushy plants. Farmers pick the pods when they are bright green and snap easily. Inside are soft beans that help you grow strong. Some beans we dry and keep for winter!",
    "bell_pepper": "Bell peppers start green and can turn yellow, orange, or red in the sun. Farmers clip the stem so the plant keeps making more. Peppers are crunchy and sweet, and full of vitamin C. They look like little colorful bells!",
    "zucchini": "Zucchini is a summer squash that grows fast on a bushy plant. Farmers pick them when they are still small and tender. Leave one too long and it becomes a giant! Zucchini is delicious grilled, baked, or in bread.",
    "eggplant": "Eggplants are shiny purple fruits that hang from a sturdy plant. Farmers cut them with a little stem still attached. Inside the purple skin is soft pale flesh. Eggplant soaks up flavors in stews and sauces!",
    "potato": "Potatoes grow underground on the roots of the plant. Farmers dig carefully so they do not poke the tubers. One plant can hide a whole handful of potatoes! They become mashed potatoes, fries, and baked potatoes.",
    "broccoli": "Broccoli is a tight cluster of tiny green flower buds. Farmers cut the thick stem before the buds open into yellow flowers. Broccoli is packed with vitamins. Those little green trees on your plate are flower buds!",
    "cauliflower": "Cauliflower grows a big white head protected by green leaves. Farmers fold the leaves over the head to keep it pale, then cut it when it is firm. Cauliflower can be mashed, roasted, or eaten raw with dip!",
    "grape": "Grapes grow in bunches on woody vines. Farmers snip whole clusters when the berries are sweet and plump. Some grapes become juice, and some become raisins. Grapes come in green, red, and purple!",
    "raspberry": "Raspberries grow on canes with soft thorns. Farmers pick the berries when they slip off the core easily and leave a little hollow. Raspberries are fragile and sweet. They stain your fingers bright pink!",
    "turnip": "Turnips are round roots that grow under leafy green tops. Farmers pull them up by the greens when the roots feel firm. Both the root and the leaves can be eaten! Turnips have a mild, earthy taste.",
    "celery": "Celery grows tall crisp stalks from a bunch in the soil. Farmers cut the whole plant at the base. The crunchy stalks are mostly water and make a great snack. Celery leaves are tasty in soups too!",
    "garlic": "Garlic grows as a bulb of little cloves under the ground. Farmers dig the bulbs when the tops turn brown and dry them in the sun. One clove planted in fall becomes a whole new bulb! Garlic makes almost every savory dish better.",
    "leek": "Leeks look like giant green onions with long white stems. Farmers mound soil around them so the stems stay white and sweet, then dig them carefully. Leeks are mild and delicious in soups and pies!",
    "kale": "Kale has curly or flat dark-green leaves full of vitamins. Farmers pick the outer leaves so the plant keeps growing. Kale is tough when raw but soft when cooked. It is one of the strongest greens in the garden!",
    "artichoke": "An artichoke is a big flower bud that never opens. Farmers cut the bud with a short stem before it blooms into a purple thistle. We eat the soft base of each leaf and the heart in the middle!",
    "wheat": "Wheat grows in golden fields that wave in the wind. Farmers harvest the tall stalks with a big machine called a combine. The tiny grains inside become flour for bread. Almost every loaf starts as a wheat plant!",
    "chili": "Chili peppers grow upright on bushy plants and can be mild or fiery hot. Farmers pick them when they turn bright red, orange, or yellow. Capsaicin is the chemical that makes chilies spicy. Handle them carefully — and wash your hands!",
    "blueberry": "Blueberries grow on woody bushes in clusters of little blue orbs. Farmers roll them gently into their hands when they are deep blue and sweet. Blueberries are packed with antioxidants. They are perfect in muffins, pancakes, and by the handful!",
    "oats": "Oats grow in soft grassy fields with dangling grain heads. Farmers cut and dry the stalks, then separate the oat grains. Those grains become oatmeal for breakfast! Oats give you long-lasting energy to play.",
}


def sh(*cmd: str) -> None:
    subprocess.run(cmd, check=True, capture_output=True)


def _pace() -> None:
    global _last_req
    wait = REQUEST_GAP_S - (time.monotonic() - _last_req)
    if wait > 0:
        time.sleep(wait)


def download_url(url: str, dest: Path) -> bool:
    global _last_req
    dest.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(4):
        _pace()
        try:
            req = urllib.request.Request(url.split("?")[0], headers=UA)
            with urllib.request.urlopen(req, timeout=180) as r, open(dest, "wb") as f:
                shutil.copyfileobj(r, f)
            _last_req = time.monotonic()
            if dest.stat().st_size < 8_000:
                dest.unlink(missing_ok=True)
                return False
            return True
        except urllib.error.HTTPError as e:
            _last_req = time.monotonic()
            cool = 20.0 * (2 ** attempt) if e.code in (429, 503) else 3.0 * (attempt + 1)
            print(f"    HTTP {e.code} — cool {cool:.0f}s", flush=True)
            time.sleep(cool)
        except Exception as e:  # noqa: BLE001
            _last_req = time.monotonic()
            print(f"    download err: {e}", flush=True)
            time.sleep(3.0 * (attempt + 1))
    dest.unlink(missing_ok=True)
    return False


def resolve_commons(title: str) -> dict | None:
    """Resolve a Commons File: title to direct URL + mime."""
    if not title.startswith("File:"):
        title = "File:" + title
    api = ("https://commons.wikimedia.org/w/api.php?action=query&format=json"
           "&prop=imageinfo&iiprop=url|size|mime&iiurlwidth=1280&titles="
           + urllib.parse.quote(title))
    global _last_req
    for attempt in range(4):
        _pace()
        try:
            req = urllib.request.Request(api, headers=UA)
            data = json.loads(urllib.request.urlopen(req, timeout=40).read())
            _last_req = time.monotonic()
            page = next(iter(data["query"]["pages"].values()))
            info = (page.get("imageinfo") or [None])[0]
            return info
        except urllib.error.HTTPError as e:
            _last_req = time.monotonic()
            cool = 20.0 * (2 ** attempt) if e.code in (429, 503) else 3.0
            print(f"    resolve HTTP {e.code} — cool {cool:.0f}s", flush=True)
            time.sleep(cool)
        except Exception as e:  # noqa: BLE001
            _last_req = time.monotonic()
            print(f"    resolve err: {e}", flush=True)
            time.sleep(3.0)
    return None


def narration_wav(text: str) -> Path:
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


def build_from_footage(footage: Path, wav: Path, out: Path, dur: float) -> None:
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


def build_ken_burns(photo: Path, wav: Path, out: Path, dur: float) -> None:
    frames = int(dur * 24) + 1
    vf = (f"scale=1920:1080:force_original_aspect_ratio=decrease,"
          f"pad=1920:1080:(ow-iw)/2:(oh-ih)/2:0x1a2e1a,"
          f"zoompan=z='1.02+0.08*on/{frames}':d={frames}"
          f":x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s={SIZE_W}x{SIZE_H}:fps=24")
    sh("ffmpeg", "-y",
       "-loop", "1", "-i", str(photo),
       "-i", str(wav),
       "-t", f"{dur:.2f}",
       "-vf", vf,
       "-map", "0:v:0", "-map", "1:a:0",
       "-c:v", "libtheora", "-q:v", "6",
       "-c:a", "libvorbis", "-q:a", "4",
       str(out))


def _clean(title: str, desc: str = "") -> bool:
    hay = (title + " " + desc).lower()
    return not any(j in hay for j in JUNK)


def pick_source(pid: str, candidates: dict, picks: dict) -> dict | None:
    """Return {kind: video|photo, title, url?, thumb?}."""
    override = picks.get(pid)
    if isinstance(override, dict) and override.get("title"):
        return {"kind": override.get("kind", "video"), "title": override["title"],
                "url": override.get("url", ""), "thumb": override.get("thumb", "")}
    entry = candidates.get(pid, {})
    for v in entry.get("videos") or []:
        if _clean(v.get("title", ""), v.get("description", "")):
            return {"kind": "video", "title": v["title"],
                    "url": v.get("url", ""), "thumb": v.get("thumb", "")}
    for p in entry.get("photos") or []:
        if _clean(p.get("title", ""), p.get("description", "")):
            return {"kind": "photo", "title": p["title"],
                    "url": p.get("url", ""), "thumb": p.get("thumb", "")}
    return None


def ensure_local(pid: str, src: dict) -> Path | None:
    """Download Commons media into FOOTAGE/harvest_<pid>.* if needed."""
    FOOTAGE.mkdir(parents=True, exist_ok=True)
    existing = list(FOOTAGE.glob(f"harvest_{pid}.*"))
    if existing:
        return existing[0]
    info = resolve_commons(src["title"])
    if not info:
        return None
    url = info.get("url") or src.get("url") or ""
    if src["kind"] == "photo":
        url = info.get("thumburl") or info.get("url") or src.get("thumb") or url
    if not url:
        return None
    ext = Path(urllib.parse.urlparse(url.split("?")[0]).path).suffix.lower() or ".bin"
    if src["kind"] == "photo" and ext not in (".jpg", ".jpeg", ".png", ".webp", ".tif", ".tiff"):
        ext = ".jpg"
    dest = FOOTAGE / f"harvest_{pid}{ext}"
    print(f"  downloading {src['title'][5:60]}…", flush=True)
    if not download_url(url, dest):
        return None
    print(f"  → {dest.name} ({dest.stat().st_size // 1024} KB)", flush=True)
    return dest


def patch_seeds(built: list[str]) -> None:
    seeds = json.loads(SEEDS_JSON.read_text())
    by_id = {p["id"]: p for p in seeds.get("plants", [])}
    changed = False
    for pid in built:
        plant = by_id.get(pid)
        if not plant:
            continue
        media = plant.setdefault("media", {})
        media["harvest"] = {"file": f"{pid}_harvest.ogv", "type": "video"}
        changed = True
    if changed:
        SEEDS_JSON.write_text(json.dumps(seeds, indent=2) + "\n")
        print("patched seeds.json media.harvest entries")


def sync_manifest_scripts() -> None:
    """Keep media_manifest.json harvest_scripts in sync with full set."""
    man = json.loads(MANIFEST.read_text())
    man["harvest_scripts"] = dict(HARVEST_SCRIPTS)
    MANIFEST.write_text(json.dumps(man, indent=2, ensure_ascii=False) + "\n")


def main() -> None:
    dry = "--dry-run" in sys.argv
    wanted = [a for a in sys.argv[1:] if not a.startswith("--")]
    candidates = json.loads(CANDIDATES.read_text()) if CANDIDATES.exists() else {}
    picks = json.loads(PICKS.read_text()) if PICKS.exists() else {}
    seeds = json.loads(SEEDS_JSON.read_text())
    plant_ids = [p["id"] for p in seeds["plants"]]
    if not wanted:
        wanted = plant_ids
    sync_manifest_scripts()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    built: list[str] = []
    for pid in wanted:
        script = HARVEST_SCRIPTS.get(pid)
        if not script:
            print(f"[{pid}] no script — skip", flush=True)
            continue
        src = pick_source(pid, candidates, picks)
        if not src:
            print(f"[{pid}] no candidate — skip", flush=True)
            continue
        print(f"[{pid}] {src['kind']} ← {src['title'][5:70]}", flush=True)
        if dry:
            continue
        local = ensure_local(pid, src)
        if local is None:
            print(f"  FAILED download", flush=True)
            continue
        wav = narration_wav(script)
        dur = audio_seconds(wav) + 1.6
        out = OUT_DIR / f"{pid}_harvest.ogv"
        try:
            if src["kind"] == "video" and local.suffix.lower() in (
                    ".mp4", ".webm", ".mov", ".ogv", ".mkv", ".ogg"):
                build_from_footage(local, wav, out, dur)
            else:
                build_ken_burns(local, wav, out, dur)
            print(f"  → {out.relative_to(ROOT)} ({out.stat().st_size // 1024} KB)",
                  flush=True)
            built.append(pid)
        except subprocess.CalledProcessError as e:
            err = (e.stderr or b"").decode()[-300:]
            print(f"  FAILED ffmpeg: {err}", flush=True)
        time.sleep(1.0)

    if built and not dry:
        patch_seeds(built)
    print(f"done — built {len(built)} harvest clips")


if __name__ == "__main__":
    main()
