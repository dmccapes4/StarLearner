#!/usr/bin/env python3
"""Build the fresh-launch explainer video: friendly narration (ElevenLabs
Matilda) over curated gameplay footage (plants + seasons first).

Outputs:
  game/stars/intro.ogv                         — played on first launch (Back ◀)
  docs/demo/garden_explorer_explainer.mp4      — shareable deliverable

Run after tools/make_demo_videos.sh so the playthrough footage + markers exist.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLAYTHROUGH = ROOT / "docs" / "demo" / "garden_explorer_playthrough.mp4"
MARKERS = ROOT / "docs" / "demo" / "playthrough_markers.json"
INTRO_OGV = ROOT / "game" / "stars" / "intro.ogv"
EXPLAIN_MP4 = ROOT / "docs" / "demo" / "garden_explorer_explainer.mp4"
WORK = Path("/tmp/garden_intro_work")
SIZE_W, SIZE_H = 960, 540

sys.path.insert(0, str(ROOT / "tools"))
import gen_garden_vo as vo  # noqa: E402

SCRIPT = [
    "Welcome to Garden Explorer! This is your very own garden to grow and explore.",
    "Tap the shed to get your supplies — seeds, a watering can, or a spade.",
    "Pick a seed, then tap an empty garden bed. Four little plots fill at once.",
    "When you see a blue water drop, water the bed, and watch sprouts grow into big plants.",
    "When a golden star floats above a bed, those plants are ready to harvest!",
    "Fill all six beds and grow a big, beautiful garden of your very own.",
    "As the seasons change, the trees and weather change too — spring flowers, summer sun, fall leaves, and winter rain.",
    "Say hello to the farm animals in the pen, and meet Buddy, the friendly puppy in the yard!",
    "Keep an eye out for garden bugs. Tap one to catch it and add it to your bug collection.",
    "Open the star menu any time to watch fun videos about plants, bugs, and animals.",
    "Have fun, little gardener. Let's grow something wonderful together!",
]

## Prefer these playthrough beats in the explainer (in order).
HIGHLIGHT_IDS = [
    "intro",
    "plant_seed",
    "plant_sprout",
    "plant_growing",
    "plant_grown",
    "garden_full",
    "season_summer",
    "season_fall",
    "season_winter",
    "harvest",
    "animals",
    "bugs",
    "library",
]


def sh(*cmd: str) -> None:
    subprocess.run(cmd, check=True, capture_output=True)


def dur(path: Path) -> float:
    out = subprocess.run(
        [
            "ffprobe",
            "-v",
            "quiet",
            "-show_entries",
            "format=duration",
            "-of",
            "csv=p=0",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return float(out.stdout.strip())


def build_narration() -> Path:
    WORK.mkdir(parents=True, exist_ok=True)
    vo.load_secrets()
    wavs: list[Path] = []
    for i, line in enumerate(SCRIPT):
        mp3 = WORK / f"n{i:02d}.mp3"
        wav = WORK / f"n{i:02d}.wav"
        ## Reuse cached line wav only when text matches sidecar.
        side = WORK / f"n{i:02d}.txt"
        if wav.exists() and side.exists() and side.read_text().strip() == line:
            wavs.append(wav)
            continue
        vo.synth_mp3(line, mp3)
        sh(
            "ffmpeg",
            "-y",
            "-i",
            str(mp3),
            "-af",
            "apad=pad_dur=0.45",
            "-ar",
            "44100",
            "-ac",
            "1",
            str(wav),
        )
        side.write_text(line + "\n")
        mp3.unlink(missing_ok=True)
        wavs.append(wav)
    listing = WORK / "list.txt"
    listing.write_text("".join(f"file '{w}'\n" for w in wavs))
    narration = WORK / "narration.wav"
    sh(
        "ffmpeg",
        "-y",
        "-f",
        "concat",
        "-safe",
        "0",
        "-i",
        str(listing),
        "-c",
        "copy",
        str(narration),
    )
    return narration


def _marker_map() -> dict[str, float]:
    if not MARKERS.exists():
        return {}
    data = json.loads(MARKERS.read_text())
    out: dict[str, float] = {}
    for m in data.get("markers", []):
        out[str(m.get("id", ""))] = float(m.get("t", 0.0))
    return out


def build_highlight_reel(footage: Path, total_needed: float) -> Path:
    """Cut plant + season beats from the playthrough so the intro shows them."""
    marks = _marker_map()
    reel = WORK / "highlight_reel.mp4"
    if not marks:
        print("warn: no playthrough_markers.json — looping full playthrough")
        return footage

    ## Each beat: from mark t until next mark (or +hold).
    ids = [i for i in HIGHLIGHT_IDS if i in marks]
    if len(ids) < 4:
        print("warn: too few markers — looping full playthrough")
        return footage

    clips: list[Path] = []
    src_dur = dur(footage)
    for i, mid in enumerate(ids):
        start = max(0.0, marks[mid] - 0.15)
        if i + 1 < len(ids):
            end = marks[ids[i + 1]]
        else:
            end = min(src_dur, start + 4.0)
        ## Cap / floor clip length for pacing.
        length = max(1.4, min(5.5, end - start))
        clip = WORK / f"hl_{i:02d}_{mid}.mp4"
        sh(
            "ffmpeg",
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-ss",
            f"{start:.2f}",
            "-i",
            str(footage),
            "-t",
            f"{length:.2f}",
            "-vf",
            f"scale={SIZE_W}:{SIZE_H}:force_original_aspect_ratio=increase,crop={SIZE_W}:{SIZE_H},fps=24",
            "-an",
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-preset",
            "fast",
            "-crf",
            "20",
            str(clip),
        )
        clips.append(clip)

    listing = WORK / "hl_list.txt"
    listing.write_text("".join(f"file '{c}'\n" for c in clips))
    sh(
        "ffmpeg",
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-f",
        "concat",
        "-safe",
        "0",
        "-i",
        str(listing),
        "-c",
        "copy",
        str(reel),
    )
    ## If reel shorter than narration, loop it when muxing (stream_loop).
    print(f"highlight reel {dur(reel):.1f}s from {len(clips)} beats (need ~{total_needed:.1f}s)")
    return reel


def build(footage: Path, narration: Path, out: Path, mp4: bool) -> None:
    total = dur(narration) + 0.8
    vf = (
        f"scale={SIZE_W}:{SIZE_H}:force_original_aspect_ratio=increase,"
        f"crop={SIZE_W}:{SIZE_H},fps=24"
    )
    common = [
        "ffmpeg",
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-stream_loop",
        "-1",
        "-i",
        str(footage),
        "-i",
        str(narration),
        "-t",
        f"{total:.2f}",
        "-vf",
        vf,
        "-map",
        "0:v:0",
        "-map",
        "1:a:0",
    ]
    if mp4:
        common += [
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-preset",
            "fast",
            "-crf",
            "20",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
        ]
    else:
        common += ["-c:v", "libtheora", "-q:v", "6", "-c:a", "libvorbis", "-q:a", "4"]
    sh(*common, str(out))


def main() -> None:
    if not PLAYTHROUGH.exists():
        sys.exit(f"missing {PLAYTHROUGH} — run tools/make_demo_videos.sh first")
    narration = build_narration()
    need = dur(narration) + 0.8
    footage = build_highlight_reel(PLAYTHROUGH, need)
    INTRO_OGV.parent.mkdir(parents=True, exist_ok=True)
    EXPLAIN_MP4.parent.mkdir(parents=True, exist_ok=True)
    build(footage, narration, INTRO_OGV, mp4=False)
    print(f"intro → {INTRO_OGV} ({INTRO_OGV.stat().st_size // 1024} KB)")
    build(footage, narration, EXPLAIN_MP4, mp4=True)
    print(f"explainer → {EXPLAIN_MP4} ({EXPLAIN_MP4.stat().st_size // 1024} KB)")
    print("done")


if __name__ == "__main__":
    main()
