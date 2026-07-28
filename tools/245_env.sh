#!/usr/bin/env bash
# WSL environment on 245 (DESKTOP-KOMPK5V). Sourced by full_deploy_245.sh.
export GODOT="${GODOT:-$HOME/.local/bin/godot}"
export JAVA_HOME="${JAVA_HOME:-$HOME/.local/opt/jdk-17}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$HOME/.local/bin:$ANDROID_HOME/platform-tools:$PATH"
