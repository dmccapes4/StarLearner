#!/usr/bin/env python3
"""Vision review of movement_video_suite captures (Grok / OpenAI).

Reads each clip folder's route.json + sampled frames + matching state.jsonl
rows, asks the model to compare rendered nest walks vs game-state ground truth,
and writes review.json + REVIEW.md under the stamp folder.

  python3 qa/review_movement_videos.py qa/out/movement_video/<stamp>
  REVIEW_PROVIDER=openai python3 qa/review_movement_videos.py …

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

SYSTEM = """You are a senior QA / UX engineer for Ant Explorer (Godot kid kiosk game).
You compare RENDERED nest walk frames (images) against GAME STATE ground truth (JSON).

Ant Explorer is a top-down ant colony: kids tap to walk through nest chambers and
tunnels, approach glowing knowledge stars, and join pheromone trail icons. Camera
soft-follows the player (or pans during a locked-rail "reveal tour").

For EVERY frame you receive, use the sidecar:
- movie_t / path_progress_u / arrived / chamber
- player: cell, facing, walking, expect_visible, on_screen_estimate, mismatch
- camera: x/y/zoom, mode follow|pan
- goal: kind, dist, in_fov, expect_visible
- nearest_star / nearest_trail visibility flags
- discovery_active / reveal_phase / trail_entry_active

Your job is to call out ALL clear UX issues and anything that looks off or unnatural:
- Player ant missing / off-screen when expect_visible / mismatch
- Camera jerks, lag, or leaves the player behind (follow mode)
- Reveal tour pan that overshoots, stalls, or never shows the star
- Pathing that looks looped, zig-zaggy, or walks through walls / wrong room
- Stars or trail icons that should be visible but are missing, clipped, or unreadable
- Depth / overlap wrong (ant under floor, star buried, tunnels unreadable)
- Unnatural motion: teleport pops, skating without facing change, sudden spin
- Chrome that obscures the walk (rails, HUD) when it hurts comprehension
- Outdoor/nest transition that looks broken (blank void, wrong layer)

Rules:
- Compare image vs sidecar; do NOT invent objects that state does not claim.
- Prefer structured severity: blocker / major / minor / ok.
- Be specific and debugging-oriented (what looks wrong + which systems likely).
- Kid kiosk bar: if a 5–8 year old would be confused or frustrated, raise severity.

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


def compact_player(p: dict) -> dict:
    keys = (
        "cell_x", "cell_y", "view_x", "view_y", "facing_x", "facing_y",
        "walking", "path_remaining", "path_len", "dist_goal",
        "expect_visible", "on_screen_estimate", "mismatch", "state", "role",
    )
    return {k: p.get(k) for k in keys}


def build_user_payload(clip_dir: Path, max_frames: int) -> tuple[str, list[Path], list[dict]]:
    route = json.loads((clip_dir / "route.json").read_text(encoding="utf-8"))
    meta = json.loads((clip_dir / "meta.json").read_text(encoding="utf-8"))
    rows = load_state_rows(clip_dir / "state.jsonl")
    frame_paths = sorted((clip_dir / "frames").glob("f_*.png"))
    idxs = sample_indices(len(frame_paths), max_frames)
    by_frame = {int(r.get("frame", -1)): r for r in rows}
    samples = []
    paths = []
    for i in idxs:
        p = frame_paths[i]
        paths.append(p)
        row = by_frame.get(i) or (rows[i] if i < len(rows) else {})
        samples.append({
            "frame": i,
            "file": p.name,
            "movie_t": row.get("movie_t"),
            "path_progress_u": row.get("path_progress_u"),
            "arrived": row.get("arrived"),
            "chamber": row.get("chamber"),
            "player": compact_player(row.get("player") or {}),
            "camera": row.get("camera"),
            "goal": row.get("goal"),
            "nearest_star": row.get("nearest_star"),
            "nearest_trail": row.get("nearest_trail"),
            "discovery_active": row.get("discovery_active"),
            "reveal_phase": row.get("reveal_phase"),
            "trail_entry_active": row.get("trail_entry_active"),
            "mismatches": [
                k for k, v in {
                    "player_off_screen": (row.get("player") or {}).get("mismatch"),
                    "goal_expected_not_in_fov": bool((row.get("goal") or {}).get("expect_visible"))
                    and not bool((row.get("goal") or {}).get("in_fov")),
                }.items() if v
            ],
        })

    schema = {
        "clip_id": "string",
        "summary": "2-4 sentence overall verdict covering motion + UX",
        "motion": {
            "path_looks_natural": "bool|null",
            "facing_matches_travel": "bool|null",
            "teleports_or_pops": "bool|null",
            "notes": "string",
        },
        "camera": {
            "follows_player": "bool|null",
            "jerky_or_laggy": "bool|null",
            "reveal_pan_ok": "bool|null",
            "notes": "string",
        },
        "readability": {
            "player_ant_clear": "bool|null",
            "star_readable_when_expected": "bool|null",
            "trail_readable_when_expected": "bool|null",
            "tunnels_chambers_readable": "bool|null",
            "notes": "string",
        },
        "timeline": [
            {
                "frame": "int",
                "movie_t": "float",
                "visible_in_image": ["player / star / trail / chamber cues seen"],
                "expected_from_state": ["flags that should be visible"],
                "missing_expected": ["items"],
                "unnatural_or_ux": "string",
                "severity": "ok|minor|major|blocker",
                "detail": "string",
            }
        ],
        "top_issues": [
            {"severity": "blocker|major|minor", "title": "string", "evidence": "string"}
        ],
        "debug_hints": [
            "actionable code/area hints (World, Colony, Pathing, CameraFollow, StarTrigger, LandscapeShell)"
        ],
    }

    text = (
        f"CLIP: {meta.get('id')}\n"
        f"NOTE: {meta.get('note')}\n"
        f"ROUTE: {json.dumps(route, indent=2)[:6000]}\n"
        f"META: {json.dumps(meta, indent=2)}\n"
        f"SAMPLED_FRAMES_STATE ({len(samples)}):\n{json.dumps(samples, indent=2)}\n\n"
        f"Return JSON only, schema:\n{json.dumps(schema, indent=2)}\n"
        "Fill timeline one entry per image, in order. Point out every clear UX issue "
        "and anything that looks off/unnatural — do not soft-pedal kid-facing bugs."
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
    lines = ["# Movement video review\n", f"Stamp: `{stamp_dir.name}`\n"]
    for r in reviews:
        cid = r.get("clip_id") or r.get("_meta", {}).get("clip_dir", "?")
        lines.append(f"\n## {cid}\n")
        if r.get("error"):
            lines.append(f"**Error:** {r['error']}\n")
            continue
        lines.append(f"**Summary:** {r.get('summary', '')}\n")
        motion = r.get("motion") or {}
        lines.append(
            f"- Motion natural: `{motion.get('path_looks_natural')}` · "
            f"facing ok: `{motion.get('facing_matches_travel')}` · "
            f"teleports: `{motion.get('teleports_or_pops')}`\n"
        )
        if motion.get("notes"):
            lines.append(f"  - {motion['notes']}\n")
        cam = r.get("camera") or {}
        lines.append(
            f"- Camera follows: `{cam.get('follows_player')}` · "
            f"jerky: `{cam.get('jerky_or_laggy')}` · "
            f"reveal pan: `{cam.get('reveal_pan_ok')}`\n"
        )
        if cam.get("notes"):
            lines.append(f"  - {cam['notes']}\n")
        read = r.get("readability") or {}
        lines.append(
            f"- Player clear: `{read.get('player_ant_clear')}` · "
            f"star: `{read.get('star_readable_when_expected')}` · "
            f"trail: `{read.get('trail_readable_when_expected')}` · "
            f"tunnels: `{read.get('tunnels_chambers_readable')}`\n"
        )
        if read.get("notes"):
            lines.append(f"  - {read['notes']}\n")
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
                f"- t={fr.get('movie_t')} **{fr.get('severity')}**: {fr.get('detail')}\n"
                f"  visible={fr.get('visible_in_image')} "
                f"missing={fr.get('missing_expected')} "
                f"ux={fr.get('unnatural_or_ux')}\n"
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
        print("usage: review_movement_videos.py <stamp_dir>", file=sys.stderr)
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
        for issue in r.get("top_issues") or []:
            if issue.get("severity") in ("blocker", "major"):
                bad += 1
                break
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
