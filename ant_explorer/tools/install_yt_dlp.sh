#!/usr/bin/env bash
# Install yt-dlp into ~/.local/bin (no sudo). Run in your Terminal:
#   ~/dev/star_learning/ant_explorer/tools/install_yt_dlp.sh
set -euo pipefail
BIN="${HOME}/.local/bin"
mkdir -p "$BIN"
curl -fsSL -o "$BIN/yt-dlp" \
  https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp
chmod +x "$BIN/yt-dlp"
# Ensure PATH for this shell and hint for future sessions
export PATH="$BIN:$PATH"
if ! grep -q '\.local/bin' "${HOME}/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc"
  echo "Appended ~/.local/bin to PATH in ~/.bashrc"
fi
yt-dlp --version
echo "OK — yt-dlp at $BIN/yt-dlp"
