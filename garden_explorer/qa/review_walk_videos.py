#!/usr/bin/env python3
"""Vision review of walk_video_suite captures (Grok / OpenAI).

Reads each clip folder's route.json + sampled frames + matching state.jsonl
rows, asks the model to compare rendered yard vs game-state ground truth and
flag clear UX / unnatural issues, then writes review.json + REVIEW.md.

  python3 qa/review_walk_videos.py qa/out/walk_video/<stamp>
  REVIEW_PROVIDER=openai python3 qa/review_walk_videos.py …

Env (from star_learning/.env):
  XAI_API_KEY      preferred (Grok vision)
  OPENAI_API_KEY   fallback
  REVIEW_MODEL     optional override
  REVIEW_MAX_FRAMES  default 12
  REVIEW_CONCURRENCY default 3  (clips in flight at once)
  REVIEW_STAGGER_S   default 2.0 (seconds between starting each clip)
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

SYSTEM = """You are a senior kid-UX QA engineer for Garden Explorer (Godot 4
isometric farm game for a young child).

PRIMARY INPUT: SECOND_TICKS — one ground-truth JSON object per whole second
(t=0,1,2,…) plus the matching PNG for that second. Each tick includes:
  direct_checks[]  — yes/no questions with state_* values
  contracts[]      — what the engine claims must be true in the image
  nav / path_quality / player / beds / animals / anchors / biases
  path_quality: detour_ratio, crow_flies, looks_like_south_fence_loop,
    east_overshoot, expect_corridor, waypoints

Your job: for EACH second tick, answer every direct_check with a direct
verdict using the image + that tick's state. Format:
  At t=Ns: state says X; image shows Y → PASS|FAIL (severity).

Also flag any clear UX / unnatural issues not covered by checks.

Hard rules:
- ROUTING (critical for routing clip_set): taps to the shed from beside the
  westernmost south bed (bed_3) must take a SHORT path (path strip or west
  aisle). FAIL path_sensible as blocker if the gardener walks EAST around the
  middle beds then BETWEEN the south beds and the southern fence. Prefer
  path_quality.looks_like_south_fence_loop / detour_ratio vs max_detour_ratio
  as state evidence, but the IMAGE is ground truth for where feet go.
- WATER / BED APPROACH (critical for water clip_set): beds have four face panes
  (N/E/S/W). Avatar should walk to the pane facing them (vector outward). From
  shed/path/south, north beds (bed_0/1/2) stand on PATH/SOUTH lip — FAIL as
  blocker if they loop to the far NORTH face. Only intentional detour: around an
  adjacent blocking bed on its closest side, then same face pane on the target.
  Read mechanics/REVIEW_BED_APPROACH_AND_WATER.md when present.
- WATER STATE: thirsty + water tool + arrived near approach → thirst clears.
  FAIL if water UX fires but primary tip is "not thirsty" right after success.
- Iso depth: south of a bed/plant → gardener IN FRONT (not under soil/wood/pack).
  If contracts say expect_player_in_front and z_index_says_in_front but the
  image shows under-paint → depth_sort_bug (blocker), not "state wrong".
- Seeds: four plot-centered clusters on soil when expect_seeds_visible.
- Buddy: texture_path should contain dog_idle or dog_walk; art = tan + red collar.
- Gate/shed: player must not be buried under posts or bed wood at goals.
- Motion: facing follows travel while moving; no teleport; no long unnatural loops.
- Do NOT invent objects. Severity: blocker / major / minor / ok.
- debug_hints MUST name concrete systems (FarmMap.bed_approach_world,
  bed_face_panes, find_path, World._queue_interact, World._on_player_arrived,
  _apply_bed_tool, Player._on_path_requested) when approach/water fails.

Return ONLY valid JSON matching the schema in the user message."""


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


def load_state_rows(path: Path) -> list[dict]:
    rows = []
    if not path.is_file():
        return rows
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            rows.append(json.loads(line))
    return rows


def compact_bed(b: dict) -> dict:
    keys = (
        "id", "stage", "plant_id", "empty", "sprite_count", "sort_y",
        "bed_z", "plant_z", "bed_z_computed", "plant_z_computed",
        "dist_player", "expect_seeds_visible", "expect_pack_visible",
        "player_south_of_bed", "player_south_of_sort", "near_footprint",
        "expect_player_in_front", "z_index_says_in_front", "depth_contract",
        "harvestable", "thirsty",
    )
    return {k: b.get(k) for k in keys if k in b}


def compact_actor(a: dict) -> dict:
    keys = (
        "id", "kind", "x", "y", "z_index", "dist_player", "is_dog",
        "texture_path", "has_walk_sheet", "sprite_frame", "expect_dog_art",
    )
    return {k: a.get(k) for k in keys if k in a}


def load_ticks(clip_dir: Path) -> list[dict]:
    path = clip_dir / "ticks.jsonl"
    if path.is_file():
        return load_state_rows(path)
    ## Fallback: synthesize second marks from state.jsonl
    rows = load_state_rows(clip_dir / "state.jsonl")
    by_s: dict[int, dict] = {}
    for r in rows:
        s = int(float(r.get("movie_t", 0.0)) + 0.001)
        if s not in by_s:
            by_s[s] = r
    return [by_s[s] for s in sorted(by_s)]


def build_user_payload(clip_dir: Path, max_frames: int) -> tuple[str, list[Path], list[dict]]:
    route = json.loads((clip_dir / "route.json").read_text(encoding="utf-8"))
    meta = json.loads((clip_dir / "meta.json").read_text(encoding="utf-8"))
    ticks = load_ticks(clip_dir)
    frame_paths = sorted((clip_dir / "frames").glob("f_*.png"))
    fps = int(meta.get("capture_fps", 12))

    ## One image per second tick (primary). Cap via REVIEW_MAX_FRAMES.
    tick_limit = min(len(ticks), max_frames)
    ticks = ticks[:tick_limit]
    paths: list[Path] = []
    samples: list[dict] = []
    for t in ticks:
        fi = int(t.get("frame", int(float(t.get("movie_t", 0)) * fps)))
        if fi < 0 or fi >= len(frame_paths):
            ## nearest frame by movie_t
            fi = min(len(frame_paths) - 1, max(0, int(round(float(t.get("movie_t", 0)) * fps))))
        p = frame_paths[fi]
        paths.append(p)
        samples.append({
            "tick_s": t.get("tick_s", int(float(t.get("movie_t", 0)))),
            "frame": fi,
            "file": p.name,
            "movie_t": t.get("movie_t"),
            "progress_est": t.get("progress_est"),
            "season": t.get("season"),
            "nav": t.get("nav"),
            "path_quality": t.get("path_quality") or route.get("path_quality"),
            "anchors": t.get("anchors"),
            "player": t.get("player"),
            "camera": t.get("camera"),
            "beds": [compact_bed(b) for b in t.get("beds", [])],
            "animals": [compact_actor(a) for a in t.get("animals", [])],
            "bugs": [compact_actor(a) for a in t.get("bugs", [])],
            "contracts": t.get("contracts", []),
            "direct_checks": t.get("direct_checks", []),
            "depth_mismatches_z": t.get("depth_mismatches_z", []),
            "biases": t.get("biases"),
            "expect": t.get("expect") or route.get("expect", {}),
        })

    schema = {
        "clip_id": "string",
        "summary": "2-4 sentence overall verdict",
        "second_answers": [
            {
                "tick_s": "int",
                "movie_t": "float",
                "answers": [
                    {
                        "check_id": "string from direct_checks.id",
                        "verdict": "PASS|FAIL",
                        "severity": "ok|minor|major|blocker",
                        "state_said": "brief",
                        "image_shows": "brief",
                        "one_liner": "At t=Ns: state says X; image shows Y → PASS|FAIL",
                    }
                ],
                "extra_issues": ["any UX issue not in direct_checks"],
            }
        ],
        "movement": {
            "looks_natural": "bool|null",
            "faces_travel_direction": "bool|null",
            "path_sensible": "bool|null",
            "notes": "string",
        },
        "depth_and_occlusion": {
            "player_under_beds_or_plants": "bool|null",
            "beds_or_fence_wrongly_on_top": "bool|null",
            "z_index_lied": "bool|null — true if z said in-front but image under",
            "notes": "string",
        },
        "plants_and_seeds": {
            "seeds_visible_when_expected": "bool|null",
            "packs_look_planted_in_plots": "bool|null",
            "notes": "string",
        },
        "animals_and_buddy": {
            "buddy_sprite_ok": "bool|null",
            "facing_glitch_toward_dog": "bool|null",
            "pen_animals_ok": "bool|null",
            "notes": "string",
        },
        "ux_issues": [
            {
                "severity": "blocker|major|minor",
                "title": "string",
                "evidence": "tick_s + what looks wrong",
            }
        ],
        "top_issues": [
            {"severity": "blocker|major|minor", "title": "string", "evidence": "string"}
        ],
        "debug_hints": [
            "actionable code/area hints (PlantLayer, FarmMap, Player, World, IsoUtil, RoamingAnimal, PenGate)"
        ],
    }

    mech_readme = ""
    mech_path = clip_dir.parent / "mechanics" / "README.md"
    if mech_path.is_file():
        mech_readme = mech_path.read_text(encoding="utf-8")[:2500]
    code_review = ""
    review_path = clip_dir.parent / "mechanics" / "REVIEW_BED_APPROACH_AND_WATER.md"
    if review_path.is_file():
        code_review = review_path.read_text(encoding="utf-8")[:5000]
    nav_diag = ""
    nav_path = clip_dir.parent / "nav_diagnostics.json"
    if nav_path.is_file():
        try:
            nav_diag = json.dumps(json.loads(nav_path.read_text(encoding="utf-8")), indent=2)[:6000]
        except json.JSONDecodeError:
            nav_diag = nav_path.read_text(encoding="utf-8")[:4000]

    text = (
        f"CLIP: {meta.get('id')}\n"
        f"CLIP_SET: {meta.get('clip_set', route.get('clip_set', ''))}\n"
        f"NOTE: {meta.get('note')}\n"
        f"ROUTE: {json.dumps(route, indent=2)[:8000]}\n"
        f"META: {json.dumps(meta, indent=2)}\n\n"
        f"CODE_REVIEW (authoritative approach model — obey this):\n{code_review}\n\n"
        f"MECHANICS_README (code dump lives in stamp/mechanics/):\n{mech_readme}\n\n"
        f"NAV_DIAGNOSTICS (probe paths for this farm):\n{nav_diag}\n\n"
        f"SECOND_TICKS ({len(samples)} — ONE IMAGE FOLLOWS PER TICK, IN ORDER):\n"
        f"{json.dumps(samples, indent=2)}\n\n"
        f"Return JSON only, schema:\n{json.dumps(schema, indent=2)}\n"
        "For every tick, answer EVERY direct_checks[] item with a one_liner of the form "
        "'At t=Ns: state says X; image shows Y → PASS|FAIL'. "
        "Prefer these tick answers over vague summaries. "
        "For path_sensible / approach_face, weigh path_quality + image corridor."
    )
    return text, paths, samples


def _retry_after_seconds(err: urllib.error.HTTPError, attempt: int) -> float:
    ra = err.headers.get("Retry-After") if err.headers else None
    if ra:
        try:
            return max(float(ra), 1.0)
        except ValueError:
            pass
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


def review_clip(
    clip_dir: Path,
    provider: str,
    model: str,
    max_frames: int,
    max_retries: int,
) -> dict:
    text, images, _samples = build_user_payload(clip_dir, max_frames)
    if not images:
        return {"error": "no frames", "clip_id": clip_dir.name}
    print(
        f"  review {clip_dir.name}: {len(images)} frames via {provider}/{model}",
        flush=True,
    )
    t0 = time.monotonic()
    if provider == "xai":
        raw = chat_xai(model, text, images, max_retries)
    else:
        raw = chat_openai(model, text, images, max_retries)
    elapsed = time.monotonic() - t0
    print(f"  done {clip_dir.name} in {elapsed:.1f}s", flush=True)
    try:
        parsed = parse_json_loose(raw)
    except Exception as e:
        parsed = {"parse_error": str(e), "raw": raw[:8000]}
    parsed["_meta"] = {
        "provider": provider,
        "model": model,
        "frames_sent": [p.name for p in images],
        "clip_dir": str(clip_dir),
        "elapsed_s": round(elapsed, 2),
    }
    if "clip_id" not in parsed:
        parsed["clip_id"] = clip_dir.name
    return parsed


def write_markdown(stamp_dir: Path, reviews: list[dict]) -> None:
    lines = ["# Garden walk video review\n", f"Stamp: `{stamp_dir.name}`\n"]
    for r in reviews:
        cid = r.get("clip_id") or r.get("_meta", {}).get("clip_dir", "?")
        lines.append(f"\n## {cid}\n")
        if r.get("error"):
            lines.append(f"**Error:** {r['error']}\n")
            continue
        lines.append(f"**Summary:** {r.get('summary', '')}\n")
        mov = r.get("movement") or {}
        lines.append(
            f"- Movement natural: `{mov.get('looks_natural')}` · "
            f"faces travel: `{mov.get('faces_travel_direction')}` · "
            f"path OK: `{mov.get('path_sensible')}`\n"
        )
        if mov.get("notes"):
            lines.append(f"  - {mov['notes']}\n")
        depth = r.get("depth_and_occlusion") or {}
        lines.append(
            f"- Under beds/plants: `{depth.get('player_under_beds_or_plants')}` · "
            f"wrong top layer: `{depth.get('beds_or_fence_wrongly_on_top')}` · "
            f"z_index lied: `{depth.get('z_index_lied')}`\n"
        )
        if depth.get("notes"):
            lines.append(f"  - {depth['notes']}\n")
        plants = r.get("plants_and_seeds") or {}
        lines.append(
            f"- Seeds visible: `{plants.get('seeds_visible_when_expected')}` · "
            f"packs in plots: `{plants.get('packs_look_planted_in_plots')}`\n"
        )
        animals = r.get("animals_and_buddy") or {}
        lines.append(
            f"- Buddy OK: `{animals.get('buddy_sprite_ok')}` · "
            f"face-dog glitch: `{animals.get('facing_glitch_toward_dog')}`\n"
        )
        lines.append("\n### Second-tick answers\n")
        for tick in r.get("second_answers") or []:
            lines.append(f"\n**t={tick.get('tick_s')}s**\n")
            for ans in tick.get("answers") or []:
                lines.append(
                    f"- `{ans.get('verdict')}` **{ans.get('severity')}** "
                    f"`{ans.get('check_id')}` — {ans.get('one_liner') or ans.get('image_shows')}\n"
                )
            for extra in tick.get("extra_issues") or []:
                lines.append(f"- extra: {extra}\n")
        lines.append("\n### UX issues\n")
        for issue in (r.get("ux_issues") or r.get("top_issues") or []):
            lines.append(
                f"- **{issue.get('severity', '?')}** — {issue.get('title')}: "
                f"{issue.get('evidence')}\n"
            )
        lines.append("\n### Debug hints\n")
        for h in r.get("debug_hints") or []:
            lines.append(f"- {h}\n")
        ## Legacy timeline if model still emits it
        if r.get("timeline"):
            lines.append("\n### Per-frame (legacy)\n")
            for fr in r.get("timeline") or []:
                lines.append(
                    f"- t={fr.get('movie_t')} **{fr.get('severity')}**: {fr.get('detail')}\n"
                )
    (stamp_dir / "REVIEW.md").write_text("".join(lines), encoding="utf-8")


def _review_one(
    clip_dir: Path,
    provider: str,
    model: str,
    max_frames: int,
    max_retries: int,
) -> dict:
    try:
        return review_clip(clip_dir, provider, model, max_frames, max_retries)
    except urllib.error.HTTPError as e:
        body = str(e.reason)[:800]
        print(f"  HTTP {e.code} on {clip_dir.name}: {body}", file=sys.stderr)
        if provider == "xai" and os.environ.get("OPENAI_API_KEY"):
            print("  falling back to OpenAI…", flush=True)
            try:
                return review_clip(
                    clip_dir,
                    "openai",
                    os.environ.get("REVIEW_MODEL", "gpt-4o"),
                    max_frames,
                    max_retries,
                )
            except Exception as e2:
                return {"error": str(e2), "clip_id": clip_dir.name}
        return {"error": f"HTTP {e.code}", "body": body, "clip_id": clip_dir.name}
    except Exception as e:
        return {"error": str(e), "clip_id": clip_dir.name}


def run_reviews_parallel(
    clip_dirs: list[Path],
    provider: str,
    model: str,
    max_frames: int,
    concurrency: int,
    stagger_s: float,
    max_retries: int,
) -> list[dict]:
    concurrency = max(1, concurrency)
    stagger_s = max(0.0, stagger_s)
    results: dict[str, dict] = {}

    def _submit(pool: ThreadPoolExecutor, clip_dir: Path):
        return pool.submit(
            _review_one, clip_dir, provider, model, max_frames, max_retries
        )

    with ThreadPoolExecutor(max_workers=concurrency) as pool:
        futures = {}
        for i, clip_dir in enumerate(clip_dirs):
            if i > 0 and stagger_s > 0:
                time.sleep(stagger_s)
            print(
                f">> queue {clip_dir.name} "
                f"({i + 1}/{len(clip_dirs)}, concurrency={concurrency})",
                flush=True,
            )
            fut = _submit(pool, clip_dir)
            futures[fut] = clip_dir.name

        for fut in as_completed(futures):
            name = futures[fut]
            results[name] = fut.result()

    ordered = []
    for clip_dir in clip_dirs:
        rev = results[clip_dir.name]
        (clip_dir / "review.json").write_text(
            json.dumps(rev, indent=2), encoding="utf-8"
        )
        ordered.append(rev)
    return ordered


def main() -> int:
    load_dotenv(STAR_ENV)
    if len(sys.argv) < 2:
        print("usage: review_walk_videos.py <stamp_dir>", file=sys.stderr)
        return 2
    stamp_dir = Path(sys.argv[1]).resolve()
    if not stamp_dir.is_dir():
        print(f"missing dir {stamp_dir}", file=sys.stderr)
        return 2

    max_frames = int(os.environ.get("REVIEW_MAX_FRAMES", "12"))
    concurrency = int(os.environ.get("REVIEW_CONCURRENCY", "3"))
    stagger_s = float(os.environ.get("REVIEW_STAGGER_S", "2.0"))
    max_retries = int(os.environ.get("REVIEW_MAX_RETRIES", "5"))
    provider = os.environ.get("REVIEW_PROVIDER", "").strip().lower()
    if not provider:
        provider = "xai" if os.environ.get("XAI_API_KEY") else "openai"
    if provider == "xai":
        model = os.environ.get("REVIEW_MODEL", "grok-4.5")
    else:
        model = os.environ.get("REVIEW_MODEL", "gpt-4o")

    clip_dirs = sorted(
        [p for p in stamp_dir.iterdir() if p.is_dir() and (p / "frames").is_dir()]
    )
    if not clip_dirs:
        print("no clip folders with frames/", file=sys.stderr)
        return 1

    print(
        f">> vision review: {len(clip_dirs)} clips, "
        f"concurrency={concurrency}, stagger={stagger_s}s, "
        f"provider={provider}/{model}",
        flush=True,
    )
    t0 = time.monotonic()
    reviews = run_reviews_parallel(
        clip_dirs, provider, model, max_frames, concurrency, stagger_s, max_retries
    )
    print(f">> all reviews finished in {time.monotonic() - t0:.1f}s", flush=True)

    out = {
        "stamp": stamp_dir.name,
        "provider": provider,
        "model": model,
        "concurrency": concurrency,
        "stagger_s": stagger_s,
        "clips": reviews,
    }
    (stamp_dir / "reviews.json").write_text(json.dumps(out, indent=2), encoding="utf-8")
    write_markdown(stamp_dir, reviews)
    print(f"Wrote {stamp_dir / 'reviews.json'} and REVIEW.md")

    bad = 0
    for r in reviews:
        if r.get("error"):
            bad += 1
            continue
        issues = list(r.get("top_issues") or []) + list(r.get("ux_issues") or [])
        hit = any(i.get("severity") in ("blocker", "major") for i in issues)
        if not hit:
            for tick in r.get("second_answers") or []:
                for ans in tick.get("answers") or []:
                    if ans.get("verdict") == "FAIL" and ans.get("severity") in (
                        "blocker",
                        "major",
                    ):
                        hit = True
                        break
                if hit:
                    break
        if hit:
            bad += 1
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
