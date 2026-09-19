#!/usr/bin/env bash
export ANDROID_HOME="$HOME/Android/Sdk"
ls "$ANDROID_HOME/build-tools/" 2>/dev/null | tail -3
ls "$HOME/moto_fogona_backup/ants-debug.keystore" 2>/dev/null && echo KEYSTORE_OK
