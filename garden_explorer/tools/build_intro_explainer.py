#!/usr/bin/env python3
"""Build the fresh-launch explainer video: friendly narration (ElevenLabs
Matilda) over real gameplay footage from the recorded playthrough.

Outputs:
  game/stars/intro.ogv                         — played on first launch (Back ◀)
  docs/demo/garden_explorer_explainer.mp4      — shareable deliverable

Replaces the old studio-presenter intro clip.
Run after tools/make_demo_videos.sh so the playthrough footage exists.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLAYTHROUGH = ROOT / "docs" / "demo" / "garden_explorer_playthrough.mp4"
INTRO_OGV = ROOT / "game" / "stars" / "intro.ogv"
EXPLAIN_MP4 = ROOT / "docs" / "demo" / "garden_explorer_explainer.mp4"
WORK = Path("/tmp/garden_intro_work")
SIZE_W, SIZE_H = 960, 540

sys.path.insert(0, str(ROOT / "tools"))
import gen_garden_vo as vo  # noqa: E402

SCRIPT = [
    "Welcome to Garden Explorer! This is your very own garden to grow and explore.",
    "Tap the shed to pick out a seed. Keep it in your hand and plant every square you like — tap a plot in a garden bed, and your seed goes right in.",
    "Give your little seeds a drink of water, and watch them sprout and grow big and strong.",
    "Fill all six beds and grow a big, beautiful garden of your very own.",
    "When your plants are ripe, harvest them, and learn what makes each one special.",
    "Say hello to the farm animals in the pen, and meet Buddy, the friendly puppy in the yard!",
    "Keep an eye out for garden bugs. Tap one to catch it and add it to your bug collection.",
    "As the seasons change from spring to winter, your whole garden changes too.",
    "Open the star menu any time to watch fun videos about plants, bugs, and animals.",
    "Have fun, little gardener. Let's grow something wonderful together!",
]


def sh(*cmd: str) -> None:
    subprocess.run(cmd, check=True, capture_output=True)


def dur(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "quiet", "-show_entries", "format=duration",
         "-of", "csv=p=0", str(path)], check=True, capture_output=True, text=True)
    return float(out.stdout.strip())


def build_narration() -> Path:
    WORK.mkdir(parents=True, exist_ok=True)
    vo.load_secrets()
    wavs: list[Path] = []
    for i, line in enumerate(SCRIPT):
        mp3 = WORK / f"n{i:02d}.mp3"
        wav = WORK / f"n{i:02d}.wav"
        vo.synth_mp3(line, mp3)
        ## small trailing pad so lines breathe
        sh("ffmpeg", "-y", "-i", str(mp3), "-af",
           "apad=pad_dur=0.45", "-ar", "44100", "-ac", "1", str(wav))
        mp3.unlink(missing_ok=True)
        wavs.append(wav)
    listing = WORK / "list.txt"
    listing.write_text("".join(f"file '{w}'\n" for w in wavs))
    narration = WORK / "narration.wav"
    sh("ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(listing),
       "-c", "copy", str(narration))
    return narration


def build(footage: Path, narration: Path, out: Path, mp4: bool) -> None:
    total = dur(narration) + 0.8
    vf = (f"scale={SIZE_W}:{SIZE_H}:force_original_aspect_ratio=increase,"
          f"crop={SIZE_W}:{SIZE_H},fps=24")
    common = [
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-stream_loop", "-1", "-i", str(footage),
        "-i", str(narration),
        "-t", f"{total:.2f}",
        "-vf", vf,
        "-map", "0:v:0", "-map", "1:a:0",
    ]
    if mp4:
        common += ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-preset", "fast",
                   "-crf", "20", "-c:a", "aac", "-b:a", "192k"]
    else:
        common += ["-c:v", "libtheora", "-q:v", "6",
                   "-c:a", "libvorbis", "-q:a", "4"]
    sh(*common, str(out))


def main() -> None:
    if not PLAYTHROUGH.exists():
        sys.exit(f"missing {PLAYTHROUGH} — run tools/make_demo_videos.sh first")
    narration = build_narration()
    INTRO_OGV.parent.mkdir(parents=True, exist_ok=True)
    EXPLAIN_MP4.parent.mkdir(parents=True, exist_ok=True)
    build(PLAYTHROUGH, narration, INTRO_OGV, mp4=False)
    print(f"intro → {INTRO_OGV} ({INTRO_OGV.stat().st_size // 1024} KB)")
    build(PLAYTHROUGH, narration, EXPLAIN_MP4, mp4=True)
    print(f"explainer → {EXPLAIN_MP4} ({EXPLAIN_MP4.stat().st_size // 1024} KB)")
    print("done")


if __name__ == "__main__":
    main()
