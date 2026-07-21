#!/usr/bin/env bash
# Regenerate role VO wavs from game/data/role_vo.json using Piper.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
JSON="$GAME/data/role_vo.json"
OUT="$GAME/assets/audio/vo/roles"
TOOLS="$ROOT/tools/piper"

PIPER_BIN="${PIPER_BIN:-$TOOLS/piper/piper}"
VOICE="${PIPER_VOICE:-$TOOLS/voices/en_US-lessac-medium.onnx}"

if [[ ! -x "$PIPER_BIN" ]]; then
  echo "Missing Piper binary at $PIPER_BIN" >&2
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
roles = data.get("roles", {})
for key, entry in roles.items():
    line1 = str(entry.get("line1", "")).strip()
    line2 = str(entry.get("line2", "")).strip()
    line3 = str(entry.get("line3", "")).strip()
    text = f"{line1} {line2} {line3}".strip()
    if not text:
        print(f"skip {key}: empty text")
        continue
    out_wav = os.path.join(out_dir, f"{key}.wav")
    print(f"synth {key} -> {out_wav}")
    subprocess.run(
        [piper_bin, "--model", voice, "--output_file", out_wav],
        input=text,
        text=True,
        check=True,
    )
print(f"done: {len(roles)} roles")
PY

echo "Role VO files written to $OUT"
echo "VoStream raw-loads WAV files at runtime; godot --import is optional."
