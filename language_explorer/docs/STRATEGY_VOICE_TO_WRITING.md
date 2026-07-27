# Strategy — Voice to Writing

*Shipped path (2026-07-26). Audience: ~6yo · Needs Wi‑Fi to hub / local ASR for inference.*

## Parent need

She wants to write something she can *say*. Dad used to spell letters aloud while she
writes with a pencil. Voice-to-Writing is that helper: she speaks an idea, the console
hears it, then walks her through each letter **without taking her pencil off the paper**.

## North star (locked)

1. **Enroll commands** — at session start, record her saying **“next”** and **“back”**
   (teaches the ritual; samples kept for the session).
2. **Record idea** — ~10 seconds of speech → upload to ASR.
3. **Cleanup** — `llama3.2:3b` rewrites the transcript into one short coherent kid sentence,
   with special care for her leading-**S** pattern (`scout`→`cout`, `spark`→`park`, etc.)
   and other malformed ASR.
4. **Narrate** the cleaned sentence; show it on screen.
5. **Pencil practice** — **no alphabet board**. Current letter is large (correct case).
   She writes on paper. Console **listens** for her enrolled commands:
   - **“next”** → advance letter + speak the new letter name
   - **“back”** → previous letter + speak it
6. Tiny on-screen next/back icons remain as a silent fallback if the mic misses a word.

## Architecture

```
Kiosk (Godot)                         ASR host (82 dev / 245 hub)
─────────────                         ──────────────────────────
Enroll next.wav / back.wav (local)
Record phrase.wav  ──POST /v1/voice_write──►  faster-whisper → llama3.2:3b
                   ◄──── { raw, text, letters[] }
Listen windows     ──POST /v1/command──────►  whisper (biased)
                   ◄──── { command: next|back|none }
```

- **Dev / desktop:** `http://127.0.0.1:8765` (tools/asr_server).
- **Kiosk:** `https://hub.starlearner.app:8443/api/asr/*` (Caddy → localhost ASR relay),
  Bearer token same as updater. Offline → Voice tile greys + “needs Wi‑Fi” VO.

## Letter sequencing

Flatten the cleaned sentence to spellable letters (`LangLetters.spell_letters` per word,
spaces skipped as targets but shown in the sentence strip). Current index is gold/large;
others dim. Affirmative VO only on advance, not on every listen miss.

## Leading-S cleanup (llama prompt contract)

System instruction must:
- Output **one** short English (or Spanish) sentence, ≤8 words / ≤40 letters of content.
- Prefer restoring a missing initial **s/S** when the word is a common kid word
  (`cout`→`scout`, `park`→`spark`, `un`→`sun`, `tar`→`star`, …) given context.
- Fix obvious ASR garbage into a coherent kid sentence; never invent scary/adult content.
- Return **only** the sentence text (no quotes, no preamble).

## Privacy

- Audio deleted on server after the response.
- On-device WAVs under `user://voice/` cleared when the session stops.
- No long-term storage of kid voice without an explicit later parent feature.

## Home tile

Third tile: mic + pencil, generated cinematic art (`home_voice`). Soft-disable when hub
unreachable.

## Acceptance

- [x] Strategy matches pencil + voice next/back (no alphabet board).
- [ ] Enroll → record → cleaned sentence → letter walk works on desktop against local ASR.
- [ ] Continuous listen advances/backs on “next”/“back”.
- [ ] Offline: tile disabled, other modes fine.
- [ ] Failure returns to a safe screen; never crashes Godot.

## Related

- Service: `tools/asr_server/`
- Client: `game/scripts/voice/VoiceToWrite.gd`, `HubClient.gd`, `MicCapture.gd`
- Hub template: `ant_explorer/tools/hub245/Caddyfile.template` (`/api/asr/*`)
