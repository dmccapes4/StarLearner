#!/usr/bin/env python3
"""Vision review of flight_video_suite captures (Grok / OpenAI).

Reads each trip folder's route.json + sampled frames + matching sim.jsonl
rows, asks the model to compare rendered canopy vs simulation ground truth,
and writes review.json + REVIEW.md under the stamp folder.

  python3 qa/review_flight_videos.py qa/out/flight_video/<stamp>
  REVIEW_PROVIDER=openai python3 qa/review_flight_videos.py …

Env (from star_learning/.env):
  XAI_API_KEY      preferred (Grok vision)
  OPENAI_API_KEY   fallback
  REVIEW_MODEL     optional override
  REVIEW_MAX_FRAMES  default 13  (≈1 image per movie second + endpoints)
  REVIEW_SECOND_TICKS default 1   (sample at integer movie_t seconds)
  REVIEW_CODE_CONTEXT default 1  (attach FlyScene/OrbitMath excerpts)
  REVIEW_CONCURRENCY default 3  (trips in flight at once)
  REVIEW_STAGGER_S   default 2.0 (seconds between starting each trip)
  REVIEW_MAX_RETRIES default 5  (429 / transient backoff)
"""
from __future__ import annotations

import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STAR_ENV = ROOT.parent / ".env"

SYSTEM = """You are a senior QA engineer for Solar System Explorer (Godot kid game).
You compare cockpit RENDERINGS (images) against SIMULATION ground truth (JSON)
and the charted COURSE (route.json). Frames are usually one per movie second.

SOURCE OF TRUTH (critical):
- The charted course / plot-time timeline is the ONLY flight truth.
- The ship MUST NOT alter heading for collisions, bounce, or deflect.
- Rendered 3D meshes / discs are PRESENTATION only — never geometry that steers.
- route.course_clearance.min_hero_x > 1 means the path never enters that body.
  If the glass LOOKS like a hit/bounce while clearance is clear → render bug
  (severity major/blocker), not a real collision.

For EVERY second-tick frame:
- movie_t / path_u / clock from sim
- bodies[]: bearing_from_fwd_deg, ang_radius_px, in_fov, expect_visible,
  render_icon, render_mesh, mismatch, is_dest, dist_hero_x

Rules:
- Camera should face flight direction (forward), NOT track the destination unless
  the destination happens to lie ahead on the path.
- Bodies with expect_visible=true and in_fov=true should appear as disc/mesh/pin.
- Bodies with ang_radius_px << 1 and not dest may honestly be invisible (AU sky).
- Close flybys (dist_hero_x < 6) should LOOK large when in FOV — flag if missing.
- Charted encounters off-glass need not be highlighted; a normal pin on-glass is OK.
- Destination during cruise may loom but should NOT fill the canopy like an impact
  when course_clearance says the park is still outside the planet.
- Hard cut into orbit park is OK; a bounce/deflection of the flight path is NOT.
- Do not invent planets. Prefer structured severity: blocker / major / minor / ok.

Return ONLY valid JSON matching the schema in the user message."""

# Compact excerpts — keep under token budget; reviewer needs invariants, not whole files.
CODE_CONTEXT_FILES = (
    (
        "game/scripts/OrbitMath.gd",
        (
            "NO collision detection",
            "NO collision dodging",
            "FLYBY_HANDOFF_MAX_X",
            "FLYBY_CLEARANCE",
            "static func plot_route",
            "static func simulate_route",
            "static func flyby_mesh_scale",
            "static func course_encounters",
        ),
    ),
    (
        "game/scripts/FlyScene.gd",
        (
            "SIM_DEST_CRUISE_MAX_PX",
            "SIM_PEER_MAX_PX",
            "func _place_ship_at_path",
            "func _enter_orbit_from_timeline",
            "func _update_sim_view",
            "func _update_markers",
            "meshes are not course truth",
            "never aim at the destination",
        ),
    ),
)


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


def sample_indices(n: int, max_frames: int) -> list[int]:
    if n <= 0:
        return []
    if n <= max_frames:
        return list(range(n))
    out = [int(round(i * (n - 1) / (max_frames - 1))) for i in range(max_frames)]
    return sorted(set(out))


def second_tick_indices(
    rows: list[dict], frame_count: int, max_frames: int, fps: float
) -> list[int]:
    """Prefer one frame per integer movie second (game-state tick), plus ends."""
    if frame_count <= 0:
        return []
    best: dict[int, tuple[float, int]] = {}
    for r in rows:
        fi = int(r.get("frame", -1))
        if fi < 0 or fi >= frame_count:
            continue
        mt = r.get("movie_t")
        if mt is None:
            mt = fi / max(fps, 1.0)
        mt = float(mt)
        sec = int(round(mt))
        err = abs(mt - sec)
        prev = best.get(sec)
        if prev is None or err < prev[0]:
            best[sec] = (err, fi)
    idxs = sorted(v[1] for v in best.values())
    if not idxs:
        return sample_indices(frame_count, max_frames)
    for edge in (0, frame_count - 1):
        if edge not in idxs:
            idxs.append(edge)
    idxs = sorted(set(idxs))
    if len(idxs) <= max_frames:
        return idxs
    mid = idxs[1:-1]
    keep_mid = max_frames - 2
    if keep_mid <= 0:
        return [idxs[0], idxs[-1]]
    step = max(len(mid) / keep_mid, 1.0)
    chosen = [mid[min(int(round(i * step)), len(mid) - 1)] for i in range(keep_mid)]
    return sorted(set([idxs[0], *chosen, idxs[-1]]))


def load_sim_rows(path: Path) -> list[dict]:
    rows = []
    if not path.is_file():
        return rows
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            rows.append(json.loads(line))
    return rows


def compact_body(b: dict) -> dict:
    keys = (
        "id", "name", "is_dest", "bearing_from_fwd_deg", "ang_radius_px",
        "in_fov", "expect_visible", "render_icon", "render_mesh", "mismatch",
        "dist_hero_x", "dist_sim", "spotlight", "charted_on_glass",
    )
    return {k: b.get(k) for k in keys}


def _excerpt_matching_lines(path: Path, needles: tuple[str, ...], pad: int = 2) -> str:
    if not path.is_file():
        return f"# missing {path}\n"
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    keep: set[int] = set()
    for i, line in enumerate(lines):
        if any(n in line for n in needles):
            for j in range(max(0, i - pad), min(len(lines), i + pad + 1)):
                keep.add(j)
    if not keep:
        return f"# no matches in {path.name}\n"
    out = [f"### {path.relative_to(ROOT)}\n```gdscript\n"]
    prev = -99
    for i in sorted(keep):
        if i > prev + 1:
            out.append("// …\n")
        out.append(f"{i + 1:4d}| {lines[i]}\n")
        prev = i
    out.append("```\n")
    return "".join(out)


def load_code_context(max_chars: int = 14000) -> str:
    chunks = ["## CODE CONTEXT (presentation vs charted course)\n"]
    for rel, needles in CODE_CONTEXT_FILES:
        chunks.append(_excerpt_matching_lines(ROOT / rel, needles))
    text = "".join(chunks)
    if len(text) > max_chars:
        return text[: max_chars - 20] + "\n…[truncated]…\n"
    return text


def build_user_payload(
    trip_dir: Path,
    max_frames: int,
    *,
    second_ticks: bool = True,
    code_context: bool = True,
) -> tuple[str, list[Path], list[dict]]:
    route = json.loads((trip_dir / "route.json").read_text(encoding="utf-8"))
    meta = json.loads((trip_dir / "meta.json").read_text(encoding="utf-8"))
    rows = load_sim_rows(trip_dir / "sim.jsonl")
    frame_paths = sorted((trip_dir / "frames").glob("f_*.png"))
    fps = float(meta.get("capture_fps") or 12)
    if second_ticks:
        idxs = second_tick_indices(rows, len(frame_paths), max_frames, fps)
    else:
        idxs = sample_indices(len(frame_paths), max_frames)
    by_frame = {int(r.get("frame", -1)): r for r in rows}
    samples = []
    paths = []
    for i in idxs:
        p = frame_paths[i]
        paths.append(p)
        row = by_frame.get(i) or (rows[i] if i < len(rows) else {})
        bodies_raw = row.get("bodies", [])
        bodies = []
        for b in bodies_raw:
            if (
                b.get("is_dest")
                or b.get("spotlight", 0)
                or b.get("charted_on_glass")
                or b.get("mismatch")
                or b.get("expect_visible")
                or (b.get("dist_hero_x") or 999) < 20
                or (b.get("ang_radius_px") or 0) >= 0.8
            ):
                bodies.append(compact_body(b))
        samples.append({
            "frame": i,
            "file": p.name,
            "movie_t": row.get("movie_t"),
            "path_u": row.get("path_u"),
            "clock": row.get("clock"),
            "in_orbit": row.get("in_orbit"),
            "burn_phase": row.get("burn_phase"),
            "fwd": row.get("fwd"),
            "bodies": bodies,
            "sim_mismatches": [
                compact_body(b) for b in bodies_raw if b.get("mismatch")
            ],
        })

    schema = {
        "trip_id": "string",
        "summary": "2-4 sentence overall verdict",
        "camera": {
            "faces_travel_direction": "bool|null",
            "appears_locked_on_destination": "bool|null",
            "notes": "string",
        },
        "course_honesty": {
            "path_follows_chart": "bool|null",
            "ship_appears_to_bounce_or_deflect": "bool|null",
            "fake_collision_with_mesh": "bool|null",
            "clearance_vs_render_notes": "string",
        },
        "timeline": [
            {
                "frame": "int",
                "movie_t": "float",
                "path_u": "float",
                "visible_in_image": ["body names/ids seen"],
                "expected_from_sim": ["ids with expect_visible"],
                "missing_expected": ["ids"],
                "unexpected_or_wrong_scale": ["ids + note"],
                "camera_vs_forward_notes": "string",
                "fake_collision": "bool|null",
                "severity": "ok|minor|major|blocker",
                "detail": "string",
            }
        ],
        "encounters": {
            "charted": "from route.encounters",
            "seen_in_video": ["ids"],
            "missed_close_passes": ["ids"],
            "notes": "string",
        },
        "destination_loom": {
            "grows_over_time": "bool|null",
            "orbit_looms": "bool|null",
            "fills_glass_like_impact_before_orbit": "bool|null",
            "notes": "string",
        },
        "top_issues": [
            {"severity": "blocker|major|minor", "title": "string", "evidence": "string"}
        ],
        "debug_hints": [
            "actionable code/area hints (FlyScene, OrbitMath, NavModes, PlotBoard)"
        ],
    }

    parts = [
        f"TRIP: {meta.get('id')}\n",
        f"NOTE: {meta.get('note')}\n",
        "INVARIANT: Charted course is flight truth; meshes are presentation only. "
        "If course_clearance says clear but the canopy looks like a hit/bounce, "
        "flag a render bug.\n",
        f"ROUTE: {json.dumps(route, indent=2)[:7000]}\n",
        f"META: {json.dumps(meta, indent=2)}\n",
        f"SECOND_TICK_SIM ({len(samples)} frames ≈ 1 Hz):\n"
        f"{json.dumps(samples, indent=2)}\n\n",
    ]
    if code_context:
        parts.append(load_code_context())
        parts.append("\n")
    parts.append(f"Return JSON only, schema:\n{json.dumps(schema, indent=2)}\n")
    parts.append(
        "Fill timeline one entry per image (each movie second), in order. "
        "Be specific and debugging-oriented."
    )
    return "".join(parts), paths, samples


def _retry_after_seconds(err: urllib.error.HTTPError, attempt: int) -> float:
    """Backoff for 429 / 5xx. Honors Retry-After when present."""
    ra = err.headers.get("Retry-After") if err.headers else None
    if ra:
        try:
            return max(float(ra), 1.0)
        except ValueError:
            pass
    # 2, 4, 8, 16, 32… capped
    return min(2.0 ** attempt, 45.0)


def _post_chat(url: str, key: str, body: dict, max_retries: int) -> str:
    data = json.dumps(body).encode("utf-8")
    last_err: Exception | None = None
    for attempt in range(max_retries + 1):
        req = urllib.request.Request(
            url,
            data=data,
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                payload = json.loads(resp.read().decode("utf-8"))
            return payload["choices"][0]["message"]["content"]
        except urllib.error.HTTPError as e:
            last_err = e
            body_txt = e.read().decode("utf-8", "replace")[:400]
            if e.code in (429, 500, 502, 503, 504) and attempt < max_retries:
                wait = _retry_after_seconds(e, attempt + 1)
                print(
                    f"    HTTP {e.code} — retry in {wait:.1f}s "
                    f"(attempt {attempt + 1}/{max_retries}): {body_txt[:120]}",
                    flush=True,
                )
                time.sleep(wait)
                continue
            raise urllib.error.HTTPError(
                e.url, e.code, f"{e.reason}: {body_txt}", e.headers, None
            ) from e
        except (TimeoutError, urllib.error.URLError) as e:
            last_err = e
            if attempt < max_retries:
                wait = min(2.0 ** (attempt + 1), 30.0)
                print(f"    network error — retry in {wait:.1f}s: {e}", flush=True)
                time.sleep(wait)
                continue
            raise
    raise RuntimeError(f"chat failed after retries: {last_err}")


def chat_xai(model: str, text: str, images: list[Path], max_retries: int) -> str:
    key = os.environ.get("XAI_API_KEY", "").strip()
    if not key:
        raise RuntimeError("XAI_API_KEY missing")
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
    return _post_chat(
        "https://api.x.ai/v1/chat/completions", key, body, max_retries
    )


def chat_openai(model: str, text: str, images: list[Path], max_retries: int) -> str:
    key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not key:
        raise RuntimeError("OPENAI_API_KEY missing")
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
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": SYSTEM},
            {"role": "user", "content": content},
        ],
    }
    return _post_chat(
        "https://api.openai.com/v1/chat/completions", key, body, max_retries
    )


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


def review_trip(
    trip_dir: Path,
    provider: str,
    model: str,
    max_frames: int,
    max_retries: int,
    *,
    second_ticks: bool = True,
    code_context: bool = True,
) -> dict:
    text, images, _samples = build_user_payload(
        trip_dir,
        max_frames,
        second_ticks=second_ticks,
        code_context=code_context,
    )
    if not images:
        return {"error": "no frames", "trip_id": trip_dir.name}
    print(
        f"  review {trip_dir.name}: {len(images)} frames via {provider}/{model}",
        flush=True,
    )
    t0 = time.monotonic()
    if provider == "xai":
        raw = chat_xai(model, text, images, max_retries)
    else:
        raw = chat_openai(model, text, images, max_retries)
    elapsed = time.monotonic() - t0
    print(f"  done {trip_dir.name} in {elapsed:.1f}s", flush=True)
    try:
        parsed = parse_json_loose(raw)
    except Exception as e:
        parsed = {"parse_error": str(e), "raw": raw[:8000]}
    parsed["_meta"] = {
        "provider": provider,
        "model": model,
        "frames_sent": [p.name for p in images],
        "trip_dir": str(trip_dir),
        "elapsed_s": round(elapsed, 2),
    }
    if "trip_id" not in parsed:
        parsed["trip_id"] = trip_dir.name
    return parsed


def write_markdown(stamp_dir: Path, reviews: list[dict]) -> None:
    lines = ["# Flight video review\n", f"Stamp: `{stamp_dir.name}`\n"]
    for r in reviews:
        tid = r.get("trip_id") or r.get("_meta", {}).get("trip_dir", "?")
        lines.append(f"\n## {tid}\n")
        if r.get("error"):
            lines.append(f"**Error:** {r['error']}\n")
            continue
        lines.append(f"**Summary:** {r.get('summary', '')}\n")
        cam = r.get("camera") or {}
        lines.append(
            f"- Camera faces travel: `{cam.get('faces_travel_direction')}` · "
            f"locked on dest: `{cam.get('appears_locked_on_destination')}`\n"
        )
        if cam.get("notes"):
            lines.append(f"  - {cam['notes']}\n")
        ch = r.get("course_honesty") or {}
        if ch:
            lines.append(
                f"- Course honesty: follows_chart=`{ch.get('path_follows_chart')}` · "
                f"bounce=`{ch.get('ship_appears_to_bounce_or_deflect')}` · "
                f"fake_mesh_hit=`{ch.get('fake_collision_with_mesh')}`\n"
            )
            if ch.get("clearance_vs_render_notes"):
                lines.append(f"  - {ch['clearance_vs_render_notes']}\n")
        enc = r.get("encounters") or {}
        lines.append(
            f"- Encounters seen: {enc.get('seen_in_video')} · "
            f"missed: {enc.get('missed_close_passes')}\n"
        )
        loom = r.get("destination_loom") or {}
        lines.append(
            f"- Dest grows: `{loom.get('grows_over_time')}` · "
            f"orbit looms: `{loom.get('orbit_looms')}`\n"
        )
        lines.append("\n### Top issues\n")
        for issue in r.get("top_issues") or []:
            lines.append(
                f"- **{issue.get('severity', '?')}** — {issue.get('title')}: "
                f"{issue.get('evidence')}\n"
            )
        lines.append("\n### Debug hints\n")
        for h in r.get("debug_hints") or []:
            lines.append(f"- {h}\n")
        lines.append("\n### Per-frame\n")
        for fr in r.get("timeline") or []:
            lines.append(
                f"- t={fr.get('movie_t')} u={fr.get('path_u')} "
                f"**{fr.get('severity')}**: {fr.get('detail')}\n"
                f"  visible={fr.get('visible_in_image')} "
                f"missing={fr.get('missing_expected')}\n"
            )
    (stamp_dir / "REVIEW.md").write_text("".join(lines), encoding="utf-8")


def _review_one(
    trip_dir: Path,
    provider: str,
    model: str,
    max_frames: int,
    max_retries: int,
    second_ticks: bool,
    code_context: bool,
) -> dict:
    try:
        return review_trip(
            trip_dir,
            provider,
            model,
            max_frames,
            max_retries,
            second_ticks=second_ticks,
            code_context=code_context,
        )
    except urllib.error.HTTPError as e:
        body = str(e.reason)[:800]
        print(f"  HTTP {e.code} on {trip_dir.name}: {body}", file=sys.stderr)
        if provider == "xai" and os.environ.get("OPENAI_API_KEY"):
            print("  falling back to OpenAI…", flush=True)
            try:
                return review_trip(
                    trip_dir,
                    "openai",
                    os.environ.get("REVIEW_MODEL", "gpt-4o"),
                    max_frames,
                    max_retries,
                    second_ticks=second_ticks,
                    code_context=code_context,
                )
            except Exception as e2:
                return {"error": str(e2), "trip_id": trip_dir.name}
        return {"error": f"HTTP {e.code}", "body": body, "trip_id": trip_dir.name}
    except Exception as e:
        return {"error": str(e), "trip_id": trip_dir.name}


def run_reviews_parallel(
    trip_dirs: list[Path],
    provider: str,
    model: str,
    max_frames: int,
    concurrency: int,
    stagger_s: float,
    max_retries: int,
    second_ticks: bool,
    code_context: bool,
) -> list[dict]:
    """Start trips with a stagger; keep up to `concurrency` in flight.

    Stagger avoids a thundering herd / 429; overlap still cuts wall time vs
    fully sequential waits for each long vision call.
    """
    concurrency = max(1, concurrency)
    stagger_s = max(0.0, stagger_s)
    results: dict[str, dict] = {}

    def _submit(pool: ThreadPoolExecutor, trip_dir: Path):
        return pool.submit(
            _review_one,
            trip_dir,
            provider,
            model,
            max_frames,
            max_retries,
            second_ticks,
            code_context,
        )

    with ThreadPoolExecutor(max_workers=concurrency) as pool:
        futures = {}
        for i, trip_dir in enumerate(trip_dirs):
            if i > 0 and stagger_s > 0:
                time.sleep(stagger_s)
            print(
                f">> queue {trip_dir.name} "
                f"({i + 1}/{len(trip_dirs)}, concurrency={concurrency})",
                flush=True,
            )
            fut = _submit(pool, trip_dir)
            futures[fut] = trip_dir.name

        for fut in as_completed(futures):
            name = futures[fut]
            results[name] = fut.result()

    # Preserve input order in aggregate output
    ordered = []
    for trip_dir in trip_dirs:
        rev = results[trip_dir.name]
        (trip_dir / "review.json").write_text(
            json.dumps(rev, indent=2), encoding="utf-8"
        )
        ordered.append(rev)
    return ordered


def main() -> int:
    load_dotenv(STAR_ENV)
    if len(sys.argv) < 2:
        print("usage: review_flight_videos.py <stamp_dir>", file=sys.stderr)
        return 2
    stamp_dir = Path(sys.argv[1]).resolve()
    if not stamp_dir.is_dir():
        print(f"missing dir {stamp_dir}", file=sys.stderr)
        return 2

    max_frames = int(os.environ.get("REVIEW_MAX_FRAMES", "13"))
    concurrency = int(os.environ.get("REVIEW_CONCURRENCY", "3"))
    stagger_s = float(os.environ.get("REVIEW_STAGGER_S", "2.0"))
    max_retries = int(os.environ.get("REVIEW_MAX_RETRIES", "5"))
    second_ticks = os.environ.get("REVIEW_SECOND_TICKS", "1").strip() not in (
        "0", "false", "no",
    )
    code_context = os.environ.get("REVIEW_CODE_CONTEXT", "1").strip() not in (
        "0", "false", "no",
    )
    provider = os.environ.get("REVIEW_PROVIDER", "").strip().lower()
    if not provider:
        provider = "xai" if os.environ.get("XAI_API_KEY") else "openai"
    if provider == "xai":
        # grok-4.5 accepts image_url parts on chat/completions (verified 2026-08).
        model = os.environ.get("REVIEW_MODEL", "grok-4.5")
    else:
        model = os.environ.get("REVIEW_MODEL", "gpt-4o")

    trip_dirs = sorted(
        [p for p in stamp_dir.iterdir() if p.is_dir() and (p / "frames").is_dir()]
    )
    if not trip_dirs:
        print("no trip folders with frames/", file=sys.stderr)
        return 1

    print(
        f">> vision review: {len(trip_dirs)} trips, "
        f"concurrency={concurrency}, stagger={stagger_s}s, "
        f"second_ticks={second_ticks}, code_context={code_context}, "
        f"provider={provider}/{model}",
        flush=True,
    )
    t0 = time.monotonic()
    reviews = run_reviews_parallel(
        trip_dirs,
        provider,
        model,
        max_frames,
        concurrency,
        stagger_s,
        max_retries,
        second_ticks,
        code_context,
    )
    print(f">> all reviews finished in {time.monotonic() - t0:.1f}s", flush=True)

    out = {
        "stamp": stamp_dir.name,
        "provider": provider,
        "model": model,
        "concurrency": concurrency,
        "stagger_s": stagger_s,
        "trips": reviews,
    }
    (stamp_dir / "reviews.json").write_text(json.dumps(out, indent=2), encoding="utf-8")
    write_markdown(stamp_dir, reviews)
    print(f"Wrote {stamp_dir / 'reviews.json'} and REVIEW.md")

    bad = 0
    for r in reviews:
        if r.get("error"):
            bad += 1
            continue
        for issue in r.get("top_issues") or []:
            if issue.get("severity") in ("blocker", "major"):
                bad += 1
                break
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
