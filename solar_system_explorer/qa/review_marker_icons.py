#!/usr/bin/env python3
"""Pointed Grok Vision review of chunky pixel AR marker icons (LOD suite).

Asks whether markers read as augmented-reality pins (pixelated, corners) vs
photoreal 3D planet discs, and how to refine the art/strategy.

  ./qa/run_marker_lod_suite.sh
  python3 qa/review_marker_icons.py qa/out/marker_lod/<stamp>
"""
from __future__ import annotations

import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STAR_ENV = ROOT.parent / ".env"

SYSTEM = """You are a senior UI/art QA engineer for a kid Godot space game.

Mission Flight MARKERS are chunky PIXELATED AR pins (PlanetSkins / images/markers).
They must clearly show WHERE a body is without looking like a 3D planet render.
Look for: visible corners/pixels, readable silhouette, not a smooth photoreal sphere.

Review the provided marker LOD screenshots (far / handoff / near) and code notes.
Return ONLY valid JSON."""


def load_dotenv(path: Path) -> None:
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        k, v = k.strip(), v.strip().strip('"').strip("'")
        if k and k not in os.environ:
            os.environ[k] = v


def b64_png(path: Path) -> str:
    return base64.standard_b64encode(path.read_bytes()).decode("ascii")


def excerpt(path: Path, start: int, end: int) -> str:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    start = max(1, start)
    end = min(len(lines), end)
    out = [f"### {path.relative_to(ROOT)} L{start}-{end}\n```gdscript\n"]
    for i in range(start - 1, end):
        out.append(f"{i + 1:4d}| {lines[i]}\n")
    out.append("```\n")
    return "".join(out)


def pick_images(stamp: Path, max_n: int = 16) -> list[Path]:
    """Prefer Jupiter/Mars/Vesta/Saturn + a few others; far+near when present."""
    pngs = sorted(stamp.glob("*.png"))
    if not pngs:
        pngs = sorted((stamp / "frames").glob("*.png")) if (stamp / "frames").is_dir() else []
    prefer_ids = ("jupiter", "mars", "vesta", "saturn", "earth", "ceres", "venus")
    scored: list[tuple[int, Path]] = []
    for p in pngs:
        name = p.name.lower()
        score = 0
        for i, bid in enumerate(prefer_ids):
            if bid in name:
                score += 100 - i
        if "far" in name:
            score += 5
        if "near" in name or "handoff" in name:
            score += 3
        scored.append((score, p))
    scored.sort(key=lambda t: (-t[0], t[1].name))
    chosen = [p for s, p in scored if s > 0][:max_n]
    if len(chosen) < 8:
        # fill with highest remaining
        for s, p in scored:
            if p not in chosen:
                chosen.append(p)
            if len(chosen) >= max_n:
                break
    return chosen[:max_n]


def post_xai(model: str, text: str, images: list[Path]) -> str:
    key = os.environ["XAI_API_KEY"].strip()
    content: list[dict] = [{"type": "text", "text": text}]
    for p in images:
        content.append({
            "type": "image_url",
            "image_url": {
                "url": f"data:image/png;base64,{b64_png(p)}",
                "detail": "high",
            },
        })
    body = {
        "model": model,
        "temperature": 0.2,
        "messages": [
            {"role": "system", "content": SYSTEM},
            {"role": "user", "content": content},
        ],
    }
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        "https://api.x.ai/v1/chat/completions",
        data=data,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=360) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
    return payload["choices"][0]["message"]["content"]


def parse_json_loose(text: str) -> dict:
    text = text.strip()
    if text.startswith("```"):
        text = text.strip("`")
        if text.startswith("json"):
            text = text[4:].lstrip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        a, b = text.find("{"), text.rfind("}")
        if a >= 0 and b > a:
            return json.loads(text[a : b + 1])
        raise


def main() -> int:
    load_dotenv(STAR_ENV)
    if len(sys.argv) < 2:
        print("usage: review_marker_icons.py <marker_lod_stamp_dir>", file=sys.stderr)
        return 2
    stamp = Path(sys.argv[1]).resolve()
    if not stamp.is_dir():
        print(f"missing {stamp}", file=sys.stderr)
        return 1
    if not os.environ.get("XAI_API_KEY"):
        print("XAI_API_KEY missing", file=sys.stderr)
        return 1

    images = pick_images(stamp)
    if not images:
        print("no PNGs in stamp", file=sys.stderr)
        return 1

    report = {}
    rp = stamp / "report.json"
    if rp.is_file():
        report = json.loads(rp.read_text(encoding="utf-8"))

    schema = {
        "summary": "2-4 sentences",
        "marker_reads_as_ar_pixel_pin": "bool|null",
        "mistaken_for_3d_planet": "bool|null",
        "per_body": [
            {
                "id": "string",
                "file": "string",
                "pixelated_corners_visible": "bool|null",
                "readable": "bool|null",
                "looks_photoreal": "bool|null",
                "severity": "ok|minor|major|blocker",
                "notes": "string",
            }
        ],
        "handoff_notes": "far pin → mesh: does mesh arrive too early / too late?",
        "refine_suggestions": [
            {"area": "art|sizing|handoff|sim_view_pin", "do": "string"}
        ],
        "code_touchpoints": [
            {"file": "path", "where": "symbol", "why": "string"}
        ],
        "confidence": "high|medium|low",
    }

    text = (
        "TASK: Critique Mission Flight AR marker icon strategy.\n"
        "Markers must look like pixel AR pins (corners), not 3D planets.\n"
        "SIM_VIEW charted flybys (Jupiter on Earth→Saturn) should use the same "
        "chunky pin language at ~SIM_MARKER_PX, never a fake AU-inflated mesh.\n\n"
        f"REPORT excerpt:\n{json.dumps(report, indent=2)[:4000]}\n\n"
        "## CODE\n"
        + excerpt(ROOT / "game/scripts/PlanetSkins.gd", 1, 120)
        + excerpt(ROOT / "game/scripts/FlyScene.gd", 35, 70)
        + excerpt(ROOT / "game/scripts/FlyScene.gd", 800, 870)
        + excerpt(ROOT / "game/scripts/OrbitMath.gd", 278, 360)
        + f"\nIMAGES ({len(images)}): {[p.name for p in images]}\n"
        f"Return JSON:\n{json.dumps(schema, indent=2)}\n"
    )

    model = os.environ.get("REVIEW_MODEL", "grok-4.5")
    print(f">> marker icon review: {len(images)} frames via {model}", flush=True)
    (stamp / "marker_brief.txt").write_text(text, encoding="utf-8")
    t0 = time.monotonic()
    raw = post_xai(model, text, images)
    print(f">> done in {time.monotonic() - t0:.1f}s", flush=True)
    try:
        parsed = parse_json_loose(raw)
    except Exception as e:
        parsed = {"parse_error": str(e), "raw": raw[:8000]}
    parsed["_meta"] = {"model": model, "frames": [p.name for p in images]}
    (stamp / "marker_review.json").write_text(json.dumps(parsed, indent=2), encoding="utf-8")
    md = ["# Marker icon Grok review\n\n", f"**Summary:** {parsed.get('summary')}\n\n"]
    md.append(f"- AR pixel pin: `{parsed.get('marker_reads_as_ar_pixel_pin')}`\n")
    md.append(f"- Mistaken for 3D: `{parsed.get('mistaken_for_3d_planet')}`\n")
    md.append(f"- Handoff: {parsed.get('handoff_notes')}\n\n### Per body\n")
    for b in parsed.get("per_body") or []:
        md.append(
            f"- **{b.get('id')}** ({b.get('file')}): {b.get('severity')} — {b.get('notes')}\n"
        )
    md.append("\n### Refine\n")
    for s in parsed.get("refine_suggestions") or []:
        md.append(f"- [{s.get('area')}] {s.get('do')}\n")
    md.append("\n### Code touchpoints\n")
    for c in parsed.get("code_touchpoints") or []:
        md.append(f"- `{c.get('file')}` / `{c.get('where')}`: {c.get('why')}\n")
    (stamp / "MARKER_REVIEW.md").write_text("".join(md), encoding="utf-8")
    print(f"Wrote {stamp / 'MARKER_REVIEW.md'}")
    print(json.dumps({
        "marker_reads_as_ar_pixel_pin": parsed.get("marker_reads_as_ar_pixel_pin"),
        "mistaken_for_3d_planet": parsed.get("mistaken_for_3d_planet"),
        "refine_suggestions": parsed.get("refine_suggestions"),
        "confidence": parsed.get("confidence"),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
