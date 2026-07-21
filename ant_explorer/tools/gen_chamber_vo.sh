#!/usr/bin/env bash
# Regenerate chamber VO wavs from game/data/chamber_vo.json using Piper.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
JSON="$GAME/data/chamber_vo.json"
OUT="$GAME/assets/audio/vo"
TOOLS="$ROOT/tools/piper"

PIPER_BIN="${PIPER_BIN:-$TOOLS/piper/piper}"
VOICE="${PIPER_VOICE:-$TOOLS/voices/en_US-lessac-medium.onnx}"

if [[ ! -x "$PIPER_BIN" ]]; then
  echo "Missing Piper binary at $PIPER_BIN" >&2
  echo "Run from repo root after downloading tools/piper (see tools/piper/README or install script)." >&2
  exit 1
fi
if [[ ! -f "$VOICE" ]]; then
  echo "Missing voice model at $VOICE" >&2
  exit 1
fi
if [[ ! -f "$JSON" ]]; then
  echo "Missing $JSON" >&2
  exit 1
fi

mkdir -p "$OUT"

python3 - "$JSON" "$OUT" "$PIPER_BIN" "$VOICE" <<'PY'
import json, subprocess, sys, os

json_path, out_dir, piper_bin, voice = sys.argv[1:5]
with open(json_path, encoding="utf-8") as f:
    data = json.load(f)
chambers = data.get("chambers", {})
for zone, entry in chambers.items():
    line1 = str(entry.get("line1", "")).strip()
    line2 = str(entry.get("line2", "")).strip()
    text = f"{line1} {line2}".strip()
    if not text:
        print(f"skip {zone}: empty text")
        continue
    out_wav = os.path.join(out_dir, f"{zone}.wav")
    print(f"synth {zone} -> {out_wav}")
    subprocess.run(
        [piper_bin, "--model", voice, "--output_file", out_wav],
        input=text,
        text=True,
        check=True,
    )
print(f"done: {len(chambers)} chambers")
PY

echo "VO files written to $OUT"
echo "VoStream raw-loads WAV files at runtime; godot --import is optional."
