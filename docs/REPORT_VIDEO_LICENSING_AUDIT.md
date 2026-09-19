# Video licensing audit — Star Learner fleet

**Date:** 2026-08-07  
**Purpose:** Exhaustive inventory of gameplay video materials that need licensing clearance before Horizon 2 (Play Store / monetization). Private gift fleet (H1) may keep current footage; distribution requires zero BLOCKERs.  
**Method:** Four Composer explore agents audited Ant, Garden, Solar, and Math/Language against manifests, bibliographies, and build pipelines; results merged into fleet ledgers.

---

## Verdict

| Game | Shipped video rows | Redistribution BLOCKERs | H2 video readiness |
|------|-------------------:|------------------------:|--------------------|
| **Ant Explorer** | 12 clips | **12** (all YouTube) | Not ready — full replace |
| **Solar System Explorer** | 14 `.ogv` / 24 segments | **15** segments (11 VectorGlobe + 3 third-party openers + Vesta/DLR) | Partial — NASA openers re-sourceable; explainer remake |
| **Garden Explorer** | 63 clips | **1** (`coop_eggs`) | Nearly ready — clear one clip; fix 8 poor-fit harvests (mostly licensed but wrong imagery) |
| **Math Explorer** | 0 gameplay | 0 | Video-clean |
| **Language Explorer** | 0 gameplay (paths in JSON unused) | 0 | Video-clean |

**Bottom line for monetization:** **28 shipped video rows** lack redistribution rights. Ant is the hardest; Solar is mostly one channel plus three bad openers; Garden is one undocumented clip. Math and Language can lead on video-clean packaging once VO/art/fonts are verified.

---

## Deliverables (this audit)

| File | Contents |
|------|----------|
| [`docs/asset_licenses_videos_unlicensed.tsv`](asset_licenses_videos_unlicensed.tsv) | Every unlicensed shipped video/segment with owner, times, place, fit notes |
| [`docs/asset_licenses_videos_all_shipped.tsv`](asset_licenses_videos_all_shipped.tsv) | All 99 shipped video rows (licensed + unlicensed) |
| [`tools/asset_licenses.tsv`](../tools/asset_licenses.tsv) | Living H2 checklist (videos + stub rows for VO/tiles/music/fonts/ASR) |
| [`docs/data/video_licensing_fleet.json`](data/video_licensing_fleet.json) | Machine-readable fleet dump |
| [`garden_explorer/docs/VIDEO_LICENSING_AUDIT.json`](../garden_explorer/docs/VIDEO_LICENSING_AUDIT.json) | Prior Garden deep audit (63 shipped + 57 bibliography-only YouTube plans) |

---

## What “unlicensed” means here

A row is a **redistribution BLOCKER** if the APK embeds footage under **YouTube Standard License**, an **undocumented local file**, or a **non-U.S. agency copyright** (DLR) without a cleared commercial grant.  

Not listed as unlicensed (but still need process care):

- **NASA-PD-LIKELY** Solar openers — U.S. government work is generally PD; re-pull from NASA/JPL direct assets and strip any non-NASA music.
- **CC-BY / CC-BY-SA / CC0 / PD / OWN** Garden clips — clear for commercial use with attribution where required; some are educationally weak (poor fit), not illegal.
- **ElevenLabs VO, Sprout Lands, Kenney, fonts, music, ASR** — non-video; stubbed in `tools/asset_licenses.tsv` as VERIFY.

H1 private gift use (no monetization off the footage) remains consistent with prior strategy docs.

---

## 1. Ant Explorer — 12 / 12 BLOCKER

**Place in game:** Knowledge-star discovery + star-rail re-watch (`game/stars/<id>.ogv`). Built from `tools/stars.tsv` via `build_stars.sh`.  
**Audio:** Original documentary audio kept (no strip). No in-game source attribution UI.  
**Sources:** BBC *Planet Ant* mirror, Deep Look/KQED/PBS, AntsCanada — all YouTube Standard.

| Clip | Source | Owner | Start–end (s) | Dur | What happens | Why / fit |
|------|--------|-------|---------------|-----|--------------|-----------|
| `01_queen` | Planet Ant | BBC | 2442–2478 | 36 | Queen / egg-laying close-up | Queen chamber — good fit |
| `02_larvae` | Planet Ant | BBC | 2648–2656 ∪ 2673–2680 ∪ 2713–2722 | 24 | Larva B-roll (3 segs) | Nursery — good fit |
| `03_pupae` | Deep Look | KQED/PBS | 98–113 ∪ 141–150 | 24 | Pupae / caste sizes | Pupa room — good fit |
| `04_fungus` | Deep Look | KQED/PBS | 48–78 | 30 | Fungus garden | Excellent fit |
| `05_forage` | Deep Look | KQED/PBS | 20–50 | 30 | Leaf cutting / trails | Outdoor forage — good fit |
| `06_pheromone` | Planet Ant | BBC | 3360–3400 | 40 | Scent Y-trail experiment | Entrance — good fit |
| `07_soldiers` | Planet Ant | BBC | 500–522 | 22 | Soldier bites presenter | Outpost — good fit; child-safety review |
| `08_waste` | Planet Ant | BBC | 3120–3150 | 30 | Refuse / waste | **POOR FIT** — dump zone vs fungus-topic VO |
| `09_labor` | Deep Look | KQED/PBS | 160–190 | 30 | Workers carry leaf pieces | Garden B — good fit |
| `10_bacteria` | Deep Look | KQED/PBS | 75–100 | 25 | Garden tending | Hygiene — bacteria mostly implicit |
| `11_architecture` | AntsCanada | Frank Mortimer | 120–155 | 35 | Clear-chamber nest exhibit | **MODERATE FIT** — Insectarium Atta vs desert VO |
| `12_invaders` | Planet Ant | BBC | 4490–4520 | 30 | Nest defense combat | Invasion clearing — good fit; content-safety review |

**Other factors:** Hardest H2 game — reward layer is almost entirely third-party documentary. Prefer own macro / CC insect footage; rebuild `stars.tsv` and re-cut. Strip or replace source audio with licensed VO for consistency with Garden.

---

## 2. Solar System Explorer — 15 BLOCKER segments (of 24)

**Place in game:** Per-body “Learn more” → MediaPanel plays concat `.ogv` (opener + explainer for planets; mission-only + chained belt for Ceres/Vesta/Psyche). Manifest: `tools/solar_bodies.tsv`, builder `tools/build_clips.sh`.  
**Audio:** Source audio retained on segments.

### BLOCKER — VectorGlobe explainer (11 segments)

One YouTube video, **The Solar System Explained (2026)** (`1wyr5rWonbE`, VectorGlobe / @KnowtheWorld), supplies the educational beat for Sun, Mercury, Venus, Earth, Mars, asteroid belt, Jupiter, Saturn, Uranus, Neptune, Pluto.

| Body | Start–end (s) | Dur | Notes |
|------|---------------|-----|-------|
| Sun | 8–62 | 54 | Shared channel; BLOCKER |
| Mercury | 89–145 | 56 | |
| Venus | 145–199 | 54 | |
| Earth | 199–276 | 77 | Longest beat |
| Mars | 276–337 | 61 | |
| Asteroid belt | 337–351 | 14 | No opener; chained after dwarfs |
| Jupiter | 351–419 | 68 | |
| Saturn | 419–487 | 68 | |
| Uranus | 487–558 | 71 | |
| Neptune | 558–630 | 72 | |
| Pluto | 630–657 | 27 | Abrupt short tail |

**Remediation:** Remake one owned explainer track (ElevenLabs + PD/own animation) and remux; keep body openers where cleared.

### BLOCKER — third-party openers (3)

| Body | Title | Owner | Start–end | Fit |
|------|-------|-------|-----------|-----|
| Mars | Mars in 4K… | ElderFox Documentaries | 5–17 | **POOR FIT** — aggregator, not NASA Perseverance channel |
| Uranus | Voyager II… Encounter with Uranus | atwaterpub | 50–62 | **POOR FIT** — third-party repost |
| Neptune | Voyager II \| Neptune Approach | Space9 | 0–10 | **POOR FIT** — entire 10s upload consumed |

### BLOCKER — Vesta (DLR)

| Body | Title | Owner | Start–end | Notes |
|------|-------|-------|-----------|-------|
| Vesta | Virtual flight over asteroid Vesta (HD) | DLR | 78–93 | German Aerospace copyright — not U.S. PD; clear or replace with NASA Dawn PD |

### NASA-PD-LIKELY openers (9) — verify, re-pull direct

Sun (NASA Goddard SDO), Mercury (MESSENGER), Venus (Magellan SVS), Earth (DSCOVR), Ceres (Dawn), Psyche (JPL direct MP4), Jupiter (Juno), Saturn (Cassini), Pluto (New Horizons). Treat as **VERIFY** until pulled from official NASA assets and soundtrack-checked.

---

## 3. Garden Explorer — 1 BLOCKER; 62 otherwise clearable

**Shipped:** 63 `.ogv` (knowledge stars/intro Ken-Burns, animals/coop, bugs, 32 harvest). Pipeline strips source audio and overlays ElevenLabs VO.  
**Deep record:** `garden_explorer/docs/VIDEO_LICENSING_AUDIT.json`.

### BLOCKER

| Clip | Place | Source | Owner | Times | What / why | Audio |
|------|-------|--------|-------|-------|------------|-------|
| `coop_eggs` | Coop look (`World.gd`) | `tools/media_src/footage/coop_eggs.mp4` | Undocumented local | 0–19.8 s | Egg collection lesson over unknown footage | Yes (VO) |

**Action:** Replace with own coop footage, Wikimedia CC photo Ken-Burns, or delete look-trigger until cleared.

### Licensed but poor educational fit (8 harvests)

Clear for license; weak for product quality — note for content pass, not legal BLOCKER:

`pea_harvest` (black-eyed pea vs pea), `bean_harvest` (same reuse), `cucumber_harvest` (machinery press), `eggplant_harvest` (food demo not harvest), `broccoli_harvest` (holiday still-life), `raspberry_harvest` (static plant), `leek_harvest` (ornamental allium), `oats_harvest` (weedy oats).

### Bibliography-only YouTube (57) — not in APK

Prior plans under YouTube Standard remain in bibliography tooling; **do not ship**. Listed in fleet JSON under `garden_bibliography_only_youtube`.

---

## 4. Math & Language — no gameplay video

- **Math:** No `.ogv` in gameplay. Kenney-sourced art/libs and ElevenLabs VO need VERIFY rows only.
- **Language:** `sentences.json` may reference six `.ogv` paths; no files and no loader in current build — treat as unused. Hub ASR model license is separate (VERIFY).

---

## 5. Cross-cutting non-video (stubs in ledger)

These are not video clips but block H2 if uncleared: ElevenLabs commercial VO tier, Sprout Lands commercial grant, Kenney pack confirmation (CC0), fonts (OFL), Garden music tracks, ASR model weights. See `tools/asset_licenses.tsv`.

---

## Recommended H2 sequence (unchanged, now quantified)

1. **Math + Language** — video-clean; finish VERIFY stubs.  
2. **Solar** — re-pull 9 NASA openers from official PD; replace Mars/Uranus/Neptune openers; remake VectorGlobe explainer; clear or replace Vesta.  
3. **Garden** — replace `coop_eggs`; optionally fix 8 poor-fit harvests.  
4. **Ant** — replace all 12 stars (longest pole).

A game is distribution-eligible for video when its rows in `tools/asset_licenses.tsv` show **zero `h2_status=BLOCKER`**.

---

## Field dictionary (unlicensed TSV)

`game`, `clip_id`, `filename`, `segment_role`, `place_in_game`, `source_title`, `source_url`, `video_id`, `owner_or_channel`, `licensing_status`, `start_time_sec`, `end_time_sec`, `duration_sec`, `what_happens`, `why_used`, `has_audio`, `other_factors`, `unlicensed_reason`.

---

*Generated from Composer subagent audits + Garden `VIDEO_LICENSING_AUDIT.json`. Update ledgers when manifests change.*
