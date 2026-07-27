# Free Flight voice — status report (2026-07-26)

## Goal

Always-on offline voice speed control in Free Flight (`faster` / `slower` / `stop`), with a visible mic indicator, without fighting Language Explorer for the mic (orchestrator owns cross-title handoff).

## What works

- **Tilt steering** — calibrated well on this Moto G (`sx=1 sy=-1`).
- **Voice enroll** — can capture all three templates when the mic delivers real audio (`peak` thousands, `ready=1`).
- **Always-on listen UI** — green **MIC ON** badge; continuous listen loop (not push-to-talk).
- **Narrator echo guard** — listen pauses while baked VO plays (avoids rematching “Holding…” as a speed word).
- **In-memory listen windows** — `take_pcm_window()` avoids WAV I/O every second (hitch mitigation).
- **Echo / ghost-peak rejection** (latest build) — fingerprints + recent-hit peak blacklist so a stuck buffer is *dropped* instead of firing a delayed false command.
- **Mode intros** (code ready, VO baked) — astronaut-girl briefing for Mission (simulated courses) and Free Flight (tilt + voice). Ship with next APK if not already on device.

## What is broken (observed tonight)

### 1. Mic stream goes dead / stuck mid-flight

Telemetry pattern (repeated across sessions):

1. Launch → `voice listen start` → `mic start ok=1 player=1 effect=1` → `voice mic hot`.
2. First window(s) sometimes real (`peak` 3k–10k, changing `n`).
3. Then either:
   - **Silent cold** — `reason=silent peak=0|~40|~165` with `player=1` (player claims hot, no audio), or
   - **Stuck peak** — same peak forever (e.g. `3457` = enroll peak, or `10930` after a real utterance) while `n` flickers (`176128` ↔ `278528`).
4. Remount loops: `stale` / `echo … — drop` / `mic hot` / same peak again.

Latest session after good enroll: flight listen locked on **peak=3457** (identical to enroll clip peaks) — strongly suggests Android/`AudioEffectRecord` is replaying a prior buffer, not live input.

### 2. Delayed / wrong command perception

User report (confirmed in logs):

- Saying **stop** → heard **“Let’s stay where the planets are”** (band warning `LINE_BAND`), not stop.
- **“Faster!”** VO arrived later while saying other words.

Root causes (orthogonal):

| Symptom | Cause |
|--------|--------|
| Band line on “stop” | **Stop never matched** (ambiguous / silent / stuck). Ship kept flying → left planet Y-band → `LINE_BAND` spoken. Not a misparse of “stop” into band text. |
| Late “Faster!” | **Stuck buffer rematched** after size changed (old stale check required peak *and* `n`). Same audio later scored as `faster` and fired. Echo fingerprint fix targets this; not fully proven on a healthy mic yet. |

### 3. Matcher ambiguity

Even with hot audio, envelopes for `faster` / `slower` / `stop` often score within ~0.02–0.05 of each other → `voice ambig` rejects. Real speech can clear `MATCH_MIN` (0.62) but still lose on margin. Offline energy envelopes are a weak discriminator for these three short words.

### 4. Focus thrash (orchestrator)

Earlier: `voice blur` / `voice focus` flipping within milliseconds; enroll peaks of `49` then blur. User believes mic orchestration owns cross-title sharing — logs support external pause/focus interference. Solar still releases mic on true app pause; brief focus blips were previously over-cancelled (partially dialed back).

## Architecture snapshot

| Piece | Role |
|-------|------|
| `VoiceCommands.gd` | Enroll UI, continuous `_listen_loop`, match, telemetry |
| `MicCapture.gd` | `AudioStreamMicrophone` + `AudioEffectRecord`; `start` / `take_pcm_window` / `stop_to_file` |
| `PlaygroundScene.gd` | Free Flight; applies speed; band warning; periodic `PGTEL` includes `mic=` snapshot |
| `Narrator` / `NarratorVoice` | Baked VO; `is_playing()` gates listen |
| Deploy / launcher | Intended mic exclusivity between titles |

Persistence: `user://playground_controls.json` + `user://voice/{faster,slower,stop}.wav`.

## Telemetry cheatsheet

```bash
adb logcat -s godot:I | grep 'PGTEL EV'
```

Useful tags:

- `voice listen start|stop|mic hot|cold|echo|stale|hit|miss|ambig`
- `mic win peak=… reason=hot|silent|empty|player_dead`
- `voice blur|focus`
- `band y=…` (not a voice command)
- Periodic flight line: `… spd=… mic=hot|cold|vo|cd …`

## Options for tomorrow

### A. Stabilize the capture path (highest leverage)

Without fresh PCM, matching cannot work.

1. **Prove who holds the mic** — while Free Flight listens, log orchestrator / other packages; confirm LE and launcher are not opening `RECORD_AUDIO`.
2. **Hard remount strategy** — on `echo` / stuck peak N times: destroy `AudioStreamPlayer`, rebuild bus effect, brief backoff (e.g. 1–2 s) instead of tight remount loop.
3. **Don’t listen during enroll-adjacent peaks** — if flight peak equals any enroll template peak within epsilon *and* fingerprint matches a known clip, treat as dead and force full rebuild (tonight’s `3457` case).
4. **Optional: push-to-talk fallback** — hold-to-talk only when continuous stream is proven dead (user previously wanted always-on; keep as escape hatch).

### B. Improve matching (once capture is healthy)

1. **Re-enroll with distinct cadence** — louder, spaced words; clear templates if tonight’s trio are too similar.
2. **Richer features** — zero-crossing / duration / simple spectral bands, not envelope-only; or DTW on short MFCC-lite.
3. **Stop bias** — short energy burst → prefer `stop` when scores are close.
4. **Tune `AMBIG_MARGIN` / `MATCH_MIN`** from a labeled set of on-device clips (log `best`/`second` on every miss).

### C. Product / UX clarity

1. **Don’t compete with band VO** — if speed command VO and band VO queue, prioritize command confirmation; or delay band line while `_cmd_cd` active.
2. **On-screen feedback** — flash command name on hit; show “mic cold” on badge when `reason=silent` streak.
3. **Ship astronaut intros** — Mission vs Free Flight briefings already written + baked; verify on device.

### D. Orchestrator contract (with deploy owner)

Document expected behavior:

- Only one Star Learner title may hold the mic.
- No focus thrash / permission UI while Solar Free Flight is resumed.
- Cold start Solar after leaving LE (or equivalent) so Godot’s mic graph is clean.

## Suggested tomorrow plan (order)

1. Reproduce with telem: enroll → launch → say **stop** once → grep `hit|echo|cold|band`.
2. If stuck peak / echo loop → **A2/A3** remount + enroll-peak guard; redeploy; retest.
3. If peaks change but ambig/miss → **B** (re-enroll + margin / features).
4. If blur/focus spam → **D** with orchestrator, not more Solar guesswork.
5. Smoke-test Mission + Free Flight astronaut intros.

## Key files

- `game/scripts/voice/VoiceCommands.gd`
- `game/scripts/voice/MicCapture.gd`
- `game/scripts/PlaygroundScene.gd`
- `game/scripts/AstronautIntro.gd` / `Main.gd` (intros)
- Build: `./tools/build_solar_apk.sh`

## Bottom line

**Controls and enroll can work.** Continuous listen fails when Android hands back a **dead or replayed buffer**; matching then either rejects (ambig/low score) or formerly **fired late on ghost audio**. Echo rejection stops the late false **faster**; it does **not** restore live capture. Tomorrow’s priority is **fresh PCM every window**, then tighten matching — not more band/VO copy changes.
