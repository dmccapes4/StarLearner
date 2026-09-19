#!/usr/bin/env bash
# Shared adb helpers for WSL + Windows adb.exe.
local_path_for_adb() {
  local p="$1"
  local adb_bin="${ADB:-${ADB_BIN:-adb}}"
  if [[ "$adb_bin" == *.exe ]] && command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$p"
  else
    printf '%s\n' "$p"
  fi
}
