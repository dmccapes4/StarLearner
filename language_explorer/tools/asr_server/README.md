# ASR server — run / deploy notes

## Desktop (Language Explorer editor / Linux)

```bash
# Default binds 0.0.0.0:8765 (phone on LAN can reach it).
# If 8765 is taken locally, pick another port and mirror it in hub_client.json:
ASR_PORT=8770 ./tools/asr_server/run.sh
# → http://10.0.0.82:8770/health
```

`res://data/hub_client.json` lists LAN ASR first, then the hub HTTPS path.
Desktop Godot also prepends `http://127.0.0.1:<same-port>` when editing.

## Hub 245 (deployed 2026-07-26)

| Piece | Location |
|-------|----------|
| ASR service | `C:\Users\dylan\antphone\asr\` (WSL venv + `server.py`) |
| Keepalive | `asr/keepalive.sh` + Startup `antphone_hub.bat` |
| Port relay | `asr/ensure_relay.bat` → `127.0.0.1:8765` → WSL |
| Caddy | `handle_path /api/asr/*` → `localhost:8765` |
| Smoke (on 245) | `curl -sk -H "Authorization: Bearer …" https://127.0.0.1:8443/api/asr/health` |

## Logs / debug

| Where | What |
|-------|------|
| `/tmp/lang_asr_8770.log` | ASR request log + whisper/cleanup text |
| `/tmp/lang_asr_debug/` | Kept WAVs when transcription is empty |
| `adb logcat \| grep VoiceToWrite` | Phone-side enroll/phrase results |

No product telemetry — only local ASR logs + Godot `print` to logcat.

```bash
adb shell pm grant com.dylan.antexplorer.language android.permission.RECORD_AUDIO
```
