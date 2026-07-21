#!/usr/bin/env bash
# Calm narration for Star Learner via ElevenLabs (baked to WAV at build time).
#
# One-time:
#   mkdir -p tools/secrets
#   echo 'ELEVENLABS_API_KEY=sk_your_key' > tools/secrets/elevenlabs.env
#
# Run:
#   ./gen_vo.sh                 # roles + chambers + intro + stars + trails + tunnels
#   ./gen_vo.sh --all           # same as default
#   ./gen_vo.sh --roles         # roles only
#   ./gen_vo.sh --chambers      # chambers only
#   ./gen_vo.sh --intro         # intro only
#   ./gen_vo.sh --stars         # star-found clips only
#   ./gen_vo.sh --trails        # trail-entry clips only
#   ./gen_vo.sh --tunnels       # first-tunnel teach clip only
#   ./gen_vo.sh --ogg           # also emit .ogg alongside .wav
#
# Voice (warm female) overrides:
#   ELEVEN_VOICE_ID=XrExE9yKIg1WjnnlVkGX ./gen_vo.sh   # Matilda (warm, default)
#   ELEVEN_VOICE_ID=EXAVITQu4vr4xnSDxMaL ./gen_vo.sh    # Sarah (soft)
#   ELEVEN_MODEL=eleven_v3 ./gen_vo.sh                  # most realistic
set -euo pipefail
cd "$(dirname "$0")"
command -v ffmpeg >/dev/null || { echo "ERROR: ffmpeg not found"; exit 1; }
if [[ -f secrets/elevenlabs.env ]]; then
  # shellcheck disable=SC1091
  set -a
  source secrets/elevenlabs.env
  set +a
fi
exec python3 gen_vo.py "$@"
