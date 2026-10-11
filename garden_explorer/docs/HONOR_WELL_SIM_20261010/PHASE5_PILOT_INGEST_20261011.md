# Phase 5 — pilot ingest, n = 3 legacy primetime shows (2026-10-11, 01:30–02:00)

Operator: "Let's start ingesting some legacy media prime time shows. Free is needed, but YouTube likely has what we need. we can start as low as n=3."

## 1. What exists now (`media/`)

| step | script | what it does | pilot result |
|---|---|---|---|
| 00 | `00_manifest.py` | shows → YouTube playlists (probed with `yt-dlp --flat-playlist` on each channel's /playlists tab) | MS NOW (ex-MSNBC, rebranded late 2025) 9 pm = Maddow (Mon) + The Briefing with Jen Psaki (Tue–Fri); CNN = Anderson Cooper 360 (8 pm; The Source has no public playlist, hour difference recorded); FOX 9 pm = Hannity |
| 01 | `01_fetch.py` | metadata + English captions as json3 for the latest K clips per playlist; append-only `meta.jsonl`, nothing deleted | K = 6: 17 videos with captions (MS NOW 11, FOX 6); CNN 0 — CNN disables auto-captions on its uploads |
| 02 | `02_transcribe.py` | whisper (GPU) for caption-less videos; audio kept under `data/<show>/audio/` | running on the CNN items (two weekly compilations, one full-episode audio) and one MS NOW clip |
| 03 | `03_segments.py` | captions / whisper → 45-s segments | MS NOW 205 segments (4 nights), FOX 36 (2 nights) |
| 05 | `05_state_graph.py` | hybrid scorer → one line per show-night (`p7, a7, r7, pillar, h, w`), edges on shared dates | first 6 lines and 2 edges written |

Free throughout: YouTube captions, yt-dlp, whisper on the local 3060, the two Hugging Face models. One infrastructure fix: yt-dlp 2026.07.04 got HTTP 403 on media downloads; upgrading user-locally to 2026.08.19 (`pip install --user --break-system-packages -U yt-dlp`) fixed it. No sudo.

## 2. First state-graph lines (hybrid scorer, not yet validated)

| show | date | n | pillar | h | p7 [econ, immig, health, educ, war, abort, guns] | w (views) |
|---|---|---|---|---|---|---|
| msnow_9pm | 2026-10-06 | 72 | immigration | 0.16 | −0.07, −0.18, −0.11, −0.21, −0.06, −0.11, **+0.09** | 497,802 |
| msnow_9pm | 2026-10-09 | 107 | economy | 0.12 | −0.01, −0.04, −0.29, −0.28, −0.02, −0.02, **+0.33** | 735,829 |
| msnow_9pm | 2026-10-10 | 16 | foreign_war | 0.32 | 0.00, +0.04, −0.02, −0.06, −0.06, +0.25, **+0.31** | 428,455 |
| fox_9pm | 2026-10-09 | 20 | economy | 0.07 | +0.01, +0.03, +0.02, −0.14, +0.01, −0.13, +0.03 | 370,301 |
| fox_9pm | 2026-10-10 | 16 | immigration | 0.17 | **−0.18, −0.24, −0.20, −0.47, −0.27**, −0.12, +0.19 | 340,563 |

| cnn_8pm | 2026-10-08 | 58 | foreign_war | 0.23 | +0.02, +0.05, −0.03, −0.08, +0.05, −0.08, +0.05 | 19,482 |
| cnn_8pm | 2026-10-09 | 58 | economy | 0.12 | +0.08, +0.05, −0.05, −0.10, +0.04, +0.01, +0.05 | 25,626 |
| cnn_8pm | 2026-10-10 | 57 | guns | 0.34 | +0.08, +0.01, −0.01, 0, 0, 0, 0 | 15,098 |

CNN rows came from whisper-medium on the GPU (43–44 min of audio each in roughly 3 minutes; 1,950 whisper segments → 173 45-s segments). CNN's view counts are an order of magnitude below the other two because the three items are a full-episode audio upload and two weekly compilations, not clips; \(w\) is not comparable across networks yet.

Edges (Euclid / a-sees-b / b-sees-a): 10-09 FOX↔MS NOW 0.48 / 0.14 / 0.10; CNN↔FOX 0.18 / 0.05 / 0.05; CNN↔MS NOW 0.44 / 0.11 / 0.12. 10-10 FOX↔MS NOW 0.68 / 0.20 / 0.19; CNN↔FOX 0.71 / 0.21 / 0.24; CNN↔MS NOW 0.29 / 0.11 / 0.08. CNN sits near zero on every axis with the lowest stance magnitudes of the three, which is what a straight-news hour should look like under any scorer. The asymmetric distances are below the Euclidean on every edge, as they must be (attention sums to 1), and the two directions differ, which is the horseshoe weighting doing something.

## 3. Read honestly

The ingest half works end to end; the scorer half is not yet trustworthy, and the table shows it:

- **Hannity scoring left of MS NOW on education (−0.47) and immigration (−0.24) on 10-10 is wrong on its face.** The clips that night were about a Democratic Senate candidate and a Democratic mayor; the NLI "most decisive hypothesis" fires on *reported* positions ("Mamdani points finger at ICE") as if the speaker held them. Stance from quoted speech is the known hard case and the hybrid has no speaker model.
- **MS NOW's consistent +0.3 on guns** is almost certainly the ICE-shooting coverage being read as pro-gun language. Same failure, other direction.
- Fox's 10-09 row is near zero everywhere: low concentration, little decisive language, which is plausible for a night of storm coverage and campaign gossip.

So the pilot confirms the pre-registered rule in `PHASE5_AXES_20261011.md` §8.5: **the scorer is frozen only after ≥ 80% sign agreement on 100 hand-labelled segments.** Nothing in §2 is a result. It is the first reading of a working pipeline.

## 4. Next steps (agent's proposal)

1. **Hand-label 100 segments** (stratified across the three shows and the seven axes) with sign and salience; the operator labels 30 and the agent 70, disagreements adjudicated by the operator. This is the ground truth the scorer is scored against.
2. **Speaker framing.** Rewrite the NLI hypotheses as "The speaker argues that …" and add a quoted-speech gate: segments whose decisive hypothesis is attributed to a named opponent ("Democrats say", "Mamdani said") have the stance sign dropped and salience kept. Cheap, and it targets exactly the failure in §3.
3. **Longer segments for stance, short for salience.** 45 s is right for salience routing; stance needs the argument, so score stance on 3-minute windows and salience on 45-s windows, then aggregate. The schema does not change.
4. **Grow K.** K = 6 per playlist gives a week; K = 60 gives the autumn. Captions are free and fast (17 videos in 60 s); whisper is the only slow step and only CNN needs it.
5. Add Shapiro, Walsh, Owens once the scorer passes (full episodes on their channels; the Fort Huachuca episode `ewBzjVe3LNQ`).

Reproducibility: `python 00_manifest.py && python 01_fetch.py 6 && .venv-stone/bin/python 02_transcribe.py medium && python 03_segments.py && .venv-stone/bin/python 05_state_graph.py hybrid`, run outside the Cursor sandbox for GPU and YouTube.
