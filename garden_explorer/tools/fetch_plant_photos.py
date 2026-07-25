#!/usr/bin/env python3
"""Fetch real seed + sprout photos for every plant from Wikimedia Commons.

Outputs 800px JPEGs:
  game/assets/photos/seeds/<plant_id>.jpg    ("This is a {plant} seed.")
  game/assets/photos/sprouts/<plant_id>.jpg  ("Look — a real {plant} sprout!")

Skips files that already exist, so hand-curated replacements are kept.
"""
from __future__ import annotations

import json
import shutil
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEEDS = ROOT / "game" / "data" / "seeds.json"
OUT_SEEDS = ROOT / "game" / "assets" / "photos" / "seeds"
OUT_SPROUTS = ROOT / "game" / "assets" / "photos" / "sprouts"
UA = {"User-Agent": "GardenExplorer/1.0 (family education project)"}
API = "https://commons.wikimedia.org/w/api.php"

## Botanical names sharpen Commons search relevance considerably.
LATIN = {
    "lettuce": "Lactuca sativa", "pea": "Pisum sativum", "radish": "Raphanus sativus",
    "carrot": "Daucus carota", "spinach": "Spinacia oleracea", "onion": "Allium cepa",
    "cabbage": "Brassica oleracea capitata", "strawberry": "Fragaria ananassa",
    "tomato": "Solanum lycopersicum", "corn": "Zea mays", "cucumber": "Cucumis sativus",
    "bean": "Phaseolus vulgaris", "bell_pepper": "Capsicum annuum",
    "zucchini": "Cucurbita pepo", "melon": "Cucumis melo", "eggplant": "Solanum melongena",
    "pumpkin": "Cucurbita pepo pumpkin", "potato": "Solanum tuberosum",
    "broccoli": "Brassica oleracea italica", "cauliflower": "Brassica oleracea botrytis",
    "grape": "Vitis vinifera", "raspberry": "Rubus idaeus", "turnip": "Brassica rapa",
    "celery": "Apium graveolens", "garlic": "Allium sativum", "leek": "Allium porrum",
    "kale": "Brassica oleracea acephala", "artichoke": "Cynara cardunculus",
    "wheat": "Triticum aestivum", "chili": "Capsicum chili", "blueberry": "Vaccinium",
    "oats": "Avena sativa",
}


def api_json(params: dict) -> dict:
    url = API + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers=UA)
    last: Exception | None = None
    for attempt in range(4):
        try:
            return json.loads(urllib.request.urlopen(req, timeout=30).read())
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(1.5 * (attempt + 1))
    print(f"  api error: {last}")
    raise last  # type: ignore[misc]


def mhnt_titles(latin: str) -> list[str]:
    """MHNT.BOT files are named 'File:<Latin name> MHNT.BOT.<acc>.jpg' —
    a prefix listing is far more reliable than fulltext search."""
    try:
        d = api_json({
            "action": "query", "format": "json", "list": "allimages",
            "aiprefix": latin.split()[0] + " " + latin.split()[1] if len(latin.split()) > 1 else latin,
            "ailimit": 50,
        })
    except Exception:
        return []
    return [
        i["name"].replace("_", " ")
        for i in d.get("query", {}).get("allimages", [])
        if "MHNT.BOT" in i.get("name", "")
    ]


def search_titles(query: str, limit: int = 8) -> list[str]:
    try:
        d = api_json({
            "action": "query", "format": "json", "list": "search",
            "srsearch": query, "srnamespace": 6, "srlimit": limit,
        })
    except Exception:
        return []
    out = []
    for r in d.get("query", {}).get("search", []):
        t = r.get("title", "")
        if t.lower().endswith((".jpg", ".jpeg", ".png")):
            out.append(t)
    return out


def thumb_url(title: str, width: int = 800) -> str | None:
    if not title.startswith("File:"):
        title = "File:" + title
    try:
        d = api_json({
            "action": "query", "format": "json", "prop": "imageinfo",
            "iiprop": "url|size", "iiurlwidth": width, "titles": title,
        })
        info = next(iter(d["query"]["pages"].values()))["imageinfo"][0]
        if info.get("width", 0) < 400:
            return None
        return info.get("thumburl") or info.get("url")
    except Exception as e:  # noqa: BLE001
        print(f"  thumb error [{title}]: {e}")
        return None


def search_image(queries: list[str], mhnt_latin: str = "") -> str | None:
    """Seed photos: try the MHNT museum's uniform seed-collection series by
    filename prefix first, then fall back to fulltext search queries."""
    if mhnt_latin:
        for t in mhnt_titles(mhnt_latin)[:3]:
            url = thumb_url(t)
            if url:
                return url
        time.sleep(0.4)
    for q in queries:
        for t in search_titles(q):
            url = thumb_url(t)
            if url:
                return url
        time.sleep(0.4)
    return None


def fetch(url: str, dest: Path) -> bool:
    try:
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=60) as r, open(dest, "wb") as f:
            shutil.copyfileobj(r, f)
        return True
    except Exception as e:  # noqa: BLE001
        print(f"  fetch failed: {e}")
        dest.unlink(missing_ok=True)
        return False


def main() -> None:
    OUT_SEEDS.mkdir(parents=True, exist_ok=True)
    OUT_SPROUTS.mkdir(parents=True, exist_ok=True)
    plants = json.loads(SEEDS.read_text())["plants"]
    for p in plants:
        pid = p["id"]
        name = p.get("name", pid.capitalize())
        latin = LATIN.get(pid, name)
        jobs = [
            ## MHNT botany series = uniform seed photography across species.
            (OUT_SEEDS / f"{pid}.jpg",
             [f"{latin} seeds", f"{name} seeds"], latin),
            (OUT_SPROUTS / f"{pid}.jpg",
             [f"{latin} seedling", f"{name} seedlings", f"{name} sprout",
              f"{latin} young plant"], ""),
        ]
        for dest, queries, mhnt in jobs:
            if dest.exists():
                continue
            url = search_image(queries, mhnt)
            if url is None:
                print(f"[{pid}] no photo ({queries[0]})")
                continue
            if fetch(url, dest):
                print(f"[{pid}] {dest.parent.name}/{dest.name}")
            time.sleep(0.4)
    print("done")


if __name__ == "__main__":
    main()
