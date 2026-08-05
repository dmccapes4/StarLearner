#!/usr/bin/env python3
"""Targeted Grok Vision review: Jupiter on Earth→Saturn (SIM_VIEW).

Packs every second-tick frame + Jupiter honesty fields (true AU ang vs rendered)
+ the full code regions that size/place peers so the model can name file:line.

  FLIGHT_TRIPS=earth_saturn_astro REVIEW=0 ./qa/run_flight_video_suite.sh
  python3 qa/review_jupiter_flyby_earth_saturn.py qa/out/flight_video/<stamp>
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

SYSTEM = """You are a senior Godot graphics / orbital QA engineer for Solar System Explorer.

PRODUCT INVARIANT (non-negotiable):
- Charted course / plot-time timeline is the ONLY flight truth.
- Jupiter (and every peer) must NEVER appear larger than its TRUE angular size
  from the cockpit camera (pure AU distance + real radius) as a 3D disc/mesh.
- When true AU size is sub-pixel (Earth→Saturn Jupiter ~0.2 px), Jupiter must
  appear as a CHUNKY PIXEL AR MARKER ICON (PlanetSkins marker — pixelated,
  visible corners, clearly NOT a 3D planet render). Readable ~SIM_MARKER_PX.
- Markers are augmented-reality labels: they show WHERE the body is on the glass
  without pretending to be the planet's true angular size.
- On Earth→Saturn the charted Jupiter pass is typically on the RIGHT at a HIGH
  bearing (near abeam / ~60–90°+), then slides aft. It should NOT sit as a huge
  3D disc dead-ahead then "bounce" off.

You receive second-tick frames + Jupiter dossier (true_au_ang_px, render_as,
render_icon/mesh, charted_on_glass, bearing) + code excerpts.

Diagnose: (1) size honesty, (2) marker vs mesh presentation, (3) exact file:line.
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


def load_rows(path: Path) -> list[dict]:
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            rows.append(json.loads(line))
    return rows


def jupiter_row(bodies: list) -> dict | None:
    for b in bodies:
        if b.get("id") == "jupiter":
            return b
    return None


def second_ticks(rows: list[dict], n_frames: int, fps: float) -> list[int]:
    best: dict[int, tuple[float, int]] = {}
    for r in rows:
        fi = int(r.get("frame", -1))
        if fi < 0 or fi >= n_frames:
            continue
        mt = float(r.get("movie_t", fi / max(fps, 1.0)))
        sec = int(round(mt))
        err = abs(mt - sec)
        prev = best.get(sec)
        if prev is None or err < prev[0]:
            best[sec] = (err, fi)
    idxs = sorted(v[1] for v in best.values())
    for e in (0, n_frames - 1):
        if e not in idxs:
            idxs.append(e)
    return sorted(set(idxs))


def code_pack() -> str:
    fly = ROOT / "game/scripts/FlyScene.gd"
    orb = ROOT / "game/scripts/OrbitMath.gd"
    parts = [
        "## CODE THAT AFFECTS PEER / JUPITER RENDERING\n",
        "Suspect #1: peer local blend in `_update_sim_view` / `debug_angular_honesty` "
        "inflates Jupiter far beyond true AU size when dist_hero_x < SIM_PEER_LOCAL_X.\n",
        excerpt(fly, 50, 75),
        excerpt(fly, 870, 990),
        excerpt(fly, 1070, 1165),
        excerpt(orb, 290, 360),
        excerpt(orb, 490, 640),
        excerpt(orb, 830, 910),
        excerpt(ROOT / "game/scripts/PlanetSkins.gd", 1, 90),
    ]
    return "".join(parts)


def build_payload(trip_dir: Path) -> tuple[str, list[Path]]:
    route = json.loads((trip_dir / "route.json").read_text(encoding="utf-8"))
    meta = json.loads((trip_dir / "meta.json").read_text(encoding="utf-8"))
    rows = load_rows(trip_dir / "sim.jsonl")
    frames = sorted((trip_dir / "frames").glob("f_*.png"))
    fps = float(meta.get("capture_fps") or 12)
    idxs = second_ticks(rows, len(frames), fps)
    by_f = {int(r["frame"]): r for r in rows if "frame" in r}

    jup_timeline = []
    images: list[Path] = []
    for i in idxs:
        r = by_f.get(i) or {}
        j = jupiter_row(r.get("bodies") or []) or {}
        images.append(frames[i])
        jup_timeline.append({
            "frame": i,
            "file": frames[i].name,
            "movie_t": r.get("movie_t"),
            "path_u": r.get("path_u"),
            "in_orbit": r.get("in_orbit"),
            "jupiter": {
                "bearing_from_fwd_deg": j.get("bearing_from_fwd_deg"),
                "dist_hero_x": j.get("dist_hero_x"),
                "true_au_ang_px": j.get("true_au_ang_px"),
                "ang_radius_px_rendered": j.get("ang_radius_px"),
                "inflation_x": j.get("inflation_x"),
                "peer_local_blend_w": j.get("peer_local_blend_w"),
                "use_local": j.get("use_local"),
                "d_au": j.get("d_au"),
                "d_blend_au": j.get("d_blend_au"),
                "in_fov": j.get("in_fov"),
                "render_as": j.get("render_as"),
                "render_mesh": j.get("render_mesh"),
                "render_icon": j.get("render_icon"),
                "marker_screen_px": j.get("marker_screen_px"),
                "spotlight": j.get("spotlight"),
                "charted_peer": j.get("charted_peer"),
                "charted_on_glass": j.get("charted_on_glass"),
                "expect_visible": j.get("expect_visible"),
            },
        })

    # Pre-compute smoking-gun stats for the model
    inflated = [
        t for t in jup_timeline
        if (t["jupiter"].get("inflation_x") or 1) > 10
        or (t["jupiter"].get("peer_local_blend_w") or 0) > 0.2
    ]
    max_inf = max((t["jupiter"].get("inflation_x") or 1) for t in jup_timeline) if jup_timeline else 1

    schema = {
        "trip_id": "earth_saturn_astro",
        "summary": "2-4 sentences",
        "root_cause": {
            "architecture": "string — what system invents the wrong size/position",
            "file": "e.g. game/scripts/FlyScene.gd",
            "function": "e.g. _update_sim_view",
            "constants_or_lines": ["SIM_PEER_LOCAL_X", "…"],
            "why_it_looks_like_bounce": "string",
        },
        "recommended_fix": {
            "primary_change": "one sentence",
            "exact_edits": [
                {"file": "path", "where": "function/const", "do": "what to change"}
            ],
            "applies_to_all_flybys": "how to generalize",
            "what_NOT_to_do": "e.g. do not steer the ship / add collision",
        },
        "honest_jupiter_expectation": {
            "max_true_au_ang_px_on_this_hop": "float",
            "should_render_as": "marker|tiny_dot|invisible|disc_mesh",
            "marker_looks_pixel_ar_not_3d": "bool|null",
            "bearing_behavior": "string",
        },
        "marker_strategy": {
            "jupiter_uses_ar_marker_when_on_glass": "bool|null",
            "looks_like_chunky_pixel_pin": "bool|null",
            "mistaken_for_3d_planet": "bool|null",
            "notes": "string",
            "refine_suggestions": ["string — how to improve marker presentation"],
        },
        "timeline": [
            {
                "movie_t": "float",
                "path_u": "float",
                "visible_jupiter_in_image": "bool|null",
                "appears_as": "marker|mesh|absent|unclear",
                "looks_oversized_vs_true_au": "bool|null",
                "looks_ahead_then_bounce": "bool|null",
                "severity": "ok|minor|major|blocker",
                "detail": "string",
            }
        ],
        "confidence": "high|medium|low",
    }

    text = (
        f"TRIP: {meta.get('id')} — {meta.get('note')}\n"
        f"FOCUS BODY: Jupiter (peer flyby on Earth→Saturn Rocket Science / SIM_VIEW)\n\n"
        "PRODUCT RULE: Jupiter must never appear larger than true cockpit angular size. "
        "Charted pass should read as a right-side / high-bearing body, not a fake "
        "collision disc in front of the ship.\n\n"
        f"ROUTE (encounters + clearance):\n{json.dumps(route, indent=2)[:8000]}\n\n"
        f"PRECOMPUTED: ticks_with_peer_blend_or_big_inflation={len(inflated)} "
        f"max_inflation_x≈{max_inf:.1f}\n"
        "If inflation_x >> 1 while true_au_ang_px << 1, the renderer is lying.\n\n"
        f"JUPITER_SECOND_TICKS ({len(jup_timeline)}):\n"
        f"{json.dumps(jup_timeline, indent=2)}\n\n"
        f"{code_pack()}\n"
        f"Return JSON only:\n{json.dumps(schema, indent=2)}\n"
        "Fill timeline one entry per image. Be ruthless about naming the edit site."
    )
    return text, images


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
        "temperature": 0.1,
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


def write_md(path: Path, review: dict) -> None:
    lines = ["# Jupiter flyby review — Earth→Saturn\n\n"]
    lines.append(f"**Summary:** {review.get('summary', '')}\n\n")
    rc = review.get("root_cause") or {}
    lines.append("## Root cause\n")
    lines.append(f"- **File:** `{rc.get('file')}` · **Function:** `{rc.get('function')}`\n")
    lines.append(f"- **Architecture:** {rc.get('architecture')}\n")
    lines.append(f"- **Constants/lines:** {rc.get('constants_or_lines')}\n")
    lines.append(f"- **Why bounce:** {rc.get('why_it_looks_like_bounce')}\n\n")
    fx = review.get("recommended_fix") or {}
    lines.append("## Recommended fix\n")
    lines.append(f"{fx.get('primary_change')}\n\n")
    for e in fx.get("exact_edits") or []:
        lines.append(f"- `{e.get('file')}` / `{e.get('where')}`: {e.get('do')}\n")
    lines.append(f"\nGeneralize: {fx.get('applies_to_all_flybys')}\n")
    lines.append(f"\nDo not: {fx.get('what_NOT_to_do')}\n\n")
    exp = review.get("honest_jupiter_expectation") or {}
    lines.append("## Honest expectation\n")
    lines.append(json.dumps(exp, indent=2) + "\n\n")
    ms = review.get("marker_strategy") or {}
    if ms:
        lines.append("## Marker strategy\n")
        lines.append(json.dumps(ms, indent=2) + "\n\n")
    lines.append("## Per-second\n")
    for fr in review.get("timeline") or []:
        lines.append(
            f"- t={fr.get('movie_t')} u={fr.get('path_u')} "
            f"**{fr.get('severity')}** appears_as={fr.get('appears_as')}: "
            f"{fr.get('detail')}\n"
        )
    path.write_text("".join(lines), encoding="utf-8")


def main() -> int:
    load_dotenv(STAR_ENV)
    if len(sys.argv) < 2:
        print("usage: review_jupiter_flyby_earth_saturn.py <stamp_dir>", file=sys.stderr)
        return 2
    stamp = Path(sys.argv[1]).resolve()
    trip = stamp / "earth_saturn_astro"
    if not trip.is_dir():
        # allow passing trip dir directly
        if (stamp / "frames").is_dir() and stamp.name == "earth_saturn_astro":
            trip = stamp
            stamp = stamp.parent
        else:
            print(f"missing {trip}", file=sys.stderr)
            return 1
    if not os.environ.get("XAI_API_KEY"):
        print("XAI_API_KEY missing", file=sys.stderr)
        return 1

    text, images = build_payload(trip)
    model = os.environ.get("REVIEW_MODEL", "grok-4.5")
    print(f">> Jupiter flyby review: {len(images)} frames, model={model}", flush=True)
    # Save the text brief for agents
    (trip / "jupiter_brief.txt").write_text(text, encoding="utf-8")
    t0 = time.monotonic()
    raw = post_xai(model, text, images)
    print(f">> done in {time.monotonic() - t0:.1f}s", flush=True)
    try:
        parsed = parse_json_loose(raw)
    except Exception as e:
        parsed = {"parse_error": str(e), "raw": raw[:12000]}
    parsed["_meta"] = {
        "model": model,
        "frames": [p.name for p in images],
        "brief": "jupiter_brief.txt",
    }
    (trip / "jupiter_review.json").write_text(json.dumps(parsed, indent=2), encoding="utf-8")
    write_md(trip / "JUPITER_REVIEW.md", parsed)
    write_md(stamp / "JUPITER_REVIEW.md", parsed)
    print(f"Wrote {trip / 'JUPITER_REVIEW.md'}")
    print(json.dumps({
        "root_cause": parsed.get("root_cause"),
        "recommended_fix": parsed.get("recommended_fix"),
        "confidence": parsed.get("confidence"),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
