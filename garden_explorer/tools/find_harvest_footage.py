#!/usr/bin/env python3
"""Find REAL Wikimedia Commons media of each crop being harvested / ripe on the plant.

Harvest clips must match the bug / animal clips: real footage + our narration.
Commons video coverage is thin for crops, so this collects both:

  videos[]  — real motion footage (preferred)
  photos[]  — real photographs of the ripe crop on the plant / just picked,
              used as a slow Ken-Burns montage when no video exists

Writes tools/harvest_candidates.json for review and for build_harvest_videos.py.

Usage:
  ./tools/find_harvest_footage.py                # every plant in seeds.json
  ./tools/find_harvest_footage.py melon carrot   # only these
"""
from __future__ import annotations

import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEEDS_JSON = ROOT / "game" / "data" / "seeds.json"
OUT_JSON = ROOT / "tools" / "harvest_candidates.json"
API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "GardenExplorer/1.0 (family education project)"}
## Commons soft rate-limit: stay well under ~1 req/s, back off hard on 429.
REQUEST_GAP_S = 2.5
PLANT_GAP_S = 8.0
_last_req = 0.0

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fetch_plant_photos import LATIN  # noqa: E402  (shared botanical names)

VIDEO_FORMS = [
    "{name} harvest", "harvesting {name}", "{name} harvesting",
    "{latin} harvest", "{name} picking fruit",
]
PHOTO_FORMS = [
    "{name} harvest", "ripe {name} plant", "{latin} fruit",
    "{name} fruit on plant", "harvested {name}", "{latin} plant",
]

## Commons phrasing that means "not a crop growing / being picked".
REJECT_WORDS = [
    "logo", "map", "coat of arms", "flag", "cartoon", "drawing", "painting",
    "illustration", "diagram", "chart", "interview", "speech", "conference",
    "pronunciation", "recipe", "cooking", "kitchen", "salad", "soup", "juice",
    "supermarket", "packaging", "canned", "bottle", "coin", "stamp", "banknote",
    "sculpture", "festival parade", "protest",
]
GOOD_HARVEST = ["harvest", "harvesting", "picking", "picked", "pulling", "reaping"]
GOOD_ONPLANT = ["ripe", "ripening", "fruit", "field", "garden", "plant", "vine",
                "bush", "crop", "row", "plantation"]


def _pace() -> None:
    global _last_req
    wait = REQUEST_GAP_S - (time.monotonic() - _last_req)
    if wait > 0:
        time.sleep(wait)


def api_json(params: dict) -> dict:
    global _last_req
    url = API + "?" + urllib.parse.urlencode(params)
    last: Exception | None = None
    for attempt in range(5):
        _pace()
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=40) as resp:
                _last_req = time.monotonic()
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            last = e
            _last_req = time.monotonic()
            ## 429 / 503 → exponential cool-down (15s, 30s, 60s, …).
            cool = 15.0 * (2 ** attempt) if e.code in (429, 503) else 2.0 * (attempt + 1)
            print(f"    HTTP {e.code} — cooling {cool:.0f}s", flush=True)
            time.sleep(cool)
        except Exception as e:  # noqa: BLE001
            last = e
            _last_req = time.monotonic()
            time.sleep(2.0 * (attempt + 1))
    print(f"    api error: {last}", flush=True)
    return {}


def search(term: str, limit: int, video: bool) -> list[str]:
    q = f"{term} filetype:video" if video else f"{term} filetype:bitmap"
    data = api_json({
        "action": "query", "format": "json", "list": "search",
        "srsearch": q, "srnamespace": "6", "srlimit": str(limit),
    })
    return [h["title"] for h in data.get("query", {}).get("search", [])]


def info_for(titles: list[str], width: int = 1280) -> dict:
    out: dict = {}
    for i in range(0, len(titles), 20):
        data = api_json({
            "action": "query", "format": "json", "prop": "imageinfo",
            "iiprop": "url|size|mime|extmetadata", "iiurlwidth": str(width),
            "titles": "|".join(titles[i:i + 20]),
        })
        for page in data.get("query", {}).get("pages", {}).values():
            ii = (page.get("imageinfo") or [{}])[0]
            meta = ii.get("extmetadata", {})
            out[page.get("title", "")] = {
                "url": ii.get("url", ""),
                "thumb": ii.get("thumburl", ""),
                "mime": ii.get("mime", ""),
                "bytes": ii.get("size", 0),
                "duration": round(float(ii.get("duration", 0) or 0), 1),
                "width": ii.get("width", 0),
                "height": ii.get("height", 0),
                "license": meta.get("LicenseShortName", {}).get("value", ""),
                "artist": _text(meta.get("Artist", {}).get("value", ""))[:120],
                "description": _text(
                    meta.get("ImageDescription", {}).get("value", ""))[:240],
            }
    return out


def _text(s: str) -> str:
    out, skip = [], False
    for ch in s:
        if ch == "<":
            skip = True
        elif ch == ">":
            skip = False
        elif not skip:
            out.append(ch)
    return " ".join("".join(out).split())


def score(title: str, info: dict, pid: str, name: str, video: bool) -> float:
    hay = (title + " " + info.get("description", "")).lower()
    words = [w for w in (name.lower().split() + pid.split("_")) if len(w) > 2]
    if not any(w in hay for w in words):
        return -1.0
    if video and info.get("duration", 0) <= 0:
        return -1.0
    s = 0.0
    if any(w in hay for w in GOOD_HARVEST):
        s += 3.0
    s += sum(1.0 for w in GOOD_ONPLANT if w in hay)
    s -= sum(4.0 for w in REJECT_WORDS if w in hay)
    if video:
        dur = info["duration"]
        s += 2.0 if 6 <= dur <= 120 else (0.5 if dur < 6 else -1.0)
        if info.get("bytes", 0) > 250_000_000:
            s -= 3.0
    else:
        if info.get("width", 0) < 700:
            s -= 2.0
        if not info.get("thumb"):
            s -= 3.0
    if info.get("width", 0) >= 1280:
        s += 0.5
    return s


def collect(pid: str, name: str, latin: str) -> dict:
    found: dict[str, dict] = {"videos": [], "photos": []}
    ## Fewer queries per plant — less rate-limit pressure.
    for kind, forms, limit in (("videos", VIDEO_FORMS[:3], 6),
                               ("photos", PHOTO_FORMS[:4], 6)):
        titles: dict[str, None] = {}
        for form in forms:
            for t in search(form.format(name=name, latin=latin), limit,
                            kind == "videos"):
                titles.setdefault(t, None)
            time.sleep(0.3)
        ranked = []
        for title, info in info_for(list(titles)).items():
            sc = score(title, info, pid, name, kind == "videos")
            if sc <= 0:
                continue
            ranked.append({"title": title, "score": round(sc, 2), **info})
        ranked.sort(key=lambda r: -r["score"])
        found[kind] = ranked[:8]
    return found


def _has_candidates(entry: dict) -> bool:
    return bool(entry.get("videos") or entry.get("photos"))


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    resume = "--resume" in sys.argv[1:] or "--skip-done" in sys.argv[1:]
    seeds = json.loads(SEEDS_JSON.read_text())
    plants = {p["id"]: p.get("name", p["id"].capitalize())
              for p in seeds.get("plants", []) if isinstance(p, dict)}
    wanted = args or list(plants)
    out = json.loads(OUT_JSON.read_text()) if OUT_JSON.exists() else {}
    print(f"pace={REQUEST_GAP_S}s/req plant_gap={PLANT_GAP_S}s resume={resume}",
          flush=True)
    for i, pid in enumerate(wanted):
        if resume and _has_candidates(out.get(pid, {})):
            n_v = len(out[pid].get("videos", []))
            n_p = len(out[pid].get("photos", []))
            print(f"{pid:12s} SKIP (already vid={n_v} pho={n_p})", flush=True)
            continue
        name = plants.get(pid, pid.replace("_", " "))
        print(f"{pid:12s} searching…", flush=True)
        got = collect(pid, name, LATIN.get(pid, name))
        out[pid] = got
        vtop = got["videos"][0]["title"][5:45] if got["videos"] else "-"
        ptop = got["photos"][0]["title"][5:45] if got["photos"] else "-"
        print(f"{pid:12s} vid={len(got['videos']):2d} [{vtop:42s}] "
              f"pho={len(got['photos']):2d} [{ptop}]", flush=True)
        OUT_JSON.write_text(json.dumps(out, indent=2) + "\n")
        if i + 1 < len(wanted):
            time.sleep(PLANT_GAP_S)
    print(f"wrote {OUT_JSON.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
