# STRATEGY — Star Documentaries (Knowledge Stars + Offline Video Pipeline)

*The reward layer: 12–15 glowing **stars** placed around the nest. Tapping one walks the player
ant over and plays a short, tightly-cut, **offline** real-ant clip. This doc defines the **star
mechanics**, the **clip spec**, and a **repeatable download-and-cut pipeline** so every clip is
short, on-point, and legal-ish for private family use. Source list lives in `BIBLIOGRAPHY.md`.*

---

## COLD OPEN — WHY WE CUT THE TAPE

**McCLANE:** Why not just play the whole YouTube video? Kid loves ants.

**FEYNMAN:** Because a three-minute clip with two minutes of intro, a sponsor read, and a
"smash that subscribe" is *noise wrapped around ten seconds of the queen laying an egg.* She's
six. Her attention is the scarcest resource in this whole project. So we do what you did with the
colony: keep only the part that carries signal. Download the source, cut it to the ten to sixty
seconds that are *exactly* the thing the star is about, store it on the phone, and never depend on
a network or a child's patience. On-point, offline, hers.

---

## 1. Star mechanics (in the game)

- **Placement:** 12–15 stars, one or two per zone, each sitting at the spot where that topic
  literally happens (queen star in the queen chamber, foraging star on the surface trail, garden
  star in the fungal garden, brood star in the nursery, etc.). See the mapping in `BIBLIOGRAPHY.md`.
- **Idle look:** a soft pulsing star sprite with a little sparkle loop. Visible from across a
  chamber so it *invites*.
- **Tap → travel → play:**
  1. Tap a star → her ant paths to it (never blocked).
  2. On arrival, the world **gently dims** and a **framed video panel** eases in (landscape,
     large, centered).
  3. The trimmed clip plays (**10–60 s**, see §2), with a big friendly **✕ / back-leaf** to exit
     any time.
  4. On finish or exit, the star gets a **"collected" sparkle** and the world fades back.
- **Re-watchable forever.** Collection is a gentle completionist goal (see them all → the map
  "blooms"), never a gate. No score, no timer.
- **Autosave** the collected-star set (already in the sim save; §7 of the simulation doc).
- **Performance rule:** **one video decoder at a time** — instantiate on open, **free on close**
  (the simulation doc's RAM budget depends on this). Preload only the *next-nearest* star's
  thumbnail, never multiple video streams.

### 1.1 Star ↔ trail synergy
A star often sits **on the pheromone trail of the matching role**, so the flow is: *tap blue nurse
trail → become a nurse → see the brood → notice the brood star → tap it → watch the real nursery.*
Doing the job and seeing the real thing reinforce each other.

---

## 2. Clip spec (what "on-point" means, concretely)

| Property | Target | Why |
|---|---|---|
| **Length** | **10–60 s** (aim 20–35 s) | A 6-year-old's attention; matches one idea per star |
| **Content** | *Only* the on-topic action (the egg, the cut, the trail, the fungus) | The star is about one thing; show that thing |
| **Resolution** | 720p (device is 1600×720) | No benefit to 4K on this panel; saves space/heat |
| **Codec** | H.264 MP4, AAC audio, `+faststart` | Universally hardware-decoded on the Snapdragon 680 |
| **Audio** | Low narration; nat-sound preferred; safe volume | Visual-first; she isn't reading subtitles |
| **File size** | ~2–10 MB each | Whole set fits easily on the microSD, loads instantly |
| **Framing** | Landscape, action centered | Fills the kiosk screen cleanly |

**Content safety pass (do this by eye for each clip):** no predator gore, no jump-scares, no
distressing narration. "Death/waste" topics: choose calm, matter-of-fact footage.

---

## 3. The offline pipeline (download → trim → transcode → deploy)

**Host tooling status (checked on your Pop!_OS box):** `ffmpeg` ✅ present (6.1.1); **`yt-dlp`
❌ missing** — install it first. `adb` ✅ present for deploying to the phone.

### 3.1 Install `yt-dlp` (one time)
```bash
# Best: pipx (isolated); or a user-local binary.
sudo apt install -y pipx && pipx ensurepath && pipx install yt-dlp
#   — or, no-pipx fallback (self-updating single binary):
mkdir -p ~/.local/bin
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o ~/.local/bin/yt-dlp
chmod +x ~/.local/bin/yt-dlp        # ensure ~/.local/bin is on PATH
yt-dlp --version
```

### 3.2 The build script
Create `ant_explorer/tools/build_stars.sh`. It reads a simple manifest (`stars.tsv`: one row per
star = `id  start  end  url`), downloads each source once, cuts the exact window, transcodes to the
kid-friendly MP4 spec, and writes `stars/<id>.mp4`.

```bash
#!/usr/bin/env bash
set -euo pipefail
# Usage: build_stars.sh stars.tsv
# stars.tsv columns (TAB-separated):  id   start(HH:MM:SS)   end(HH:MM:SS)   url
#   Lines starting with # are ignored.
MANIFEST="${1:-stars.tsv}"
SRC_DIR="build/sources"; OUT_DIR="stars"; mkdir -p "$SRC_DIR" "$OUT_DIR"

while IFS=$'\t' read -r id start end url; do
  [[ -z "${id:-}" || "$id" == \#* ]] && continue
  echo ">> star $id  [$start -> $end]  $url"

  # 1) Download the source ONCE (best <=720p mp4-friendly), cached by video id.
  src="$SRC_DIR/$id.mp4"
  if [[ ! -f "$src" ]]; then
    yt-dlp -f "bv*[height<=720]+ba/b[height<=720]" \
           --merge-output-format mp4 \
           -o "$src" "$url"
  fi

  # 2) Cut the exact window + transcode to the clip spec (accurate seek via -ss after -i).
  ffmpeg -y -i "$src" -ss "$start" -to "$end" \
         -vf "scale=-2:720" \
         -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 23 -preset veryfast \
         -c:a aac -b:a 96k -movflags +faststart \
         "$OUT_DIR/$id.mp4"

  echo "   wrote $OUT_DIR/$id.mp4  ($(du -h "$OUT_DIR/$id.mp4" | cut -f1))"
done < "$MANIFEST"

echo "All stars built in ./$OUT_DIR"
```

Make it executable: `chmod +x ant_explorer/tools/build_stars.sh`.

> **Accuracy note:** putting `-ss`/`-to` *after* `-i` does a precise (frame-accurate) cut at the
> cost of decoding from the start — fine for short sources. For very long sources, pre-seek with
> `-ss` *before* `-i` for speed, then fine-trim. For these short docs, accuracy wins.

### 3.3 Deploy to the phone
```bash
# Whole set to the app's offline media dir (adjust package/path to your APK).
adb push stars/  /sdcard/Android/data/com.you.antexplorer/files/stars/
# Or to the microSD for the video assets (per the kiosk plan):
# adb push stars/  /storage/<SD-UUID>/AntExplorer/stars/
```
The app loads `stars/<id>.mp4` by the same `id` used in the star placement table.

### 3.4 Iterate
Tweak a `start/end` in `stars.tsv`, re-run `build_stars.sh` (sources are cached, so only the cut
re-runs), re-push. Trimming to "exactly on point" is a 30-second edit loop.

---

## 4. The 12 stars (topic → placement → source)

The canonical topic list is the overview's 12 knowledge stars. Each maps to a zone and a source
row in `BIBLIOGRAPHY.md`:

| ★ | Topic | Zone placement |
|---|---|---|
| 1 | Queen & egg-laying | Queen chamber |
| 2 | Larvae & nursing | Nursery (on blue nurse trail) |
| 3 | Pupae & caste determination | Nursery |
| 4 | Fungal garden cultivation | Fungal garden A |
| 5 | Leaf cutting & foraging | Surface patch (on green forager trail) |
| 6 | Pheromone communication | Entrance / main tunnel |
| 7 | Soldier caste & defense | Soldier outpost (on red trail) |
| 8 | Waste management | Refuse dump (on grey trail) |
| 9 | Division of labor | Entrance hub |
| 10 | Symbiotic bacteria / hygiene | Fungal garden B |
| 11 | Colony architecture / tunnels | Deep tunnel |
| 12 | Invaders & resilience | Entrance (near defense) |

Expansion stars (13–15: nuptial flight, founding a colony, species comparison) slot in later
without code changes — just new rows.

---

## 5. Legality / etiquette (the honest footnote)

These clips are for a **single private family device**, not redistribution — the reasonable
"personal/educational use" corner. Keep it clean anyway: **credit every source** (a tiny
"Footage: Deep Look / KQED" line is nice and models good behavior for her), prefer channels that
welcome educational reuse, keep clips short, and never repackage or publish the compiled app with
the footage embedded for others. If you ever want to *distribute* Ant Explorer, swap the clips for
originals (your own macro footage, AntsCanada with permission, or CC-licensed material). The
pipeline is source-agnostic — only `stars.tsv` changes.
