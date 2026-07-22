#!/usr/bin/env bash
# Shared defaults/helpers for the local Frida 16.7.19 Florida workflow.

FRIDA_SKILL_DIR="${FRIDA_SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TOP_DIR="${TOP_DIR:-/Users/tbs/Documents/Codex/2026-07-21/frida-16.7.19-florida}"
CORE_DIR="${CORE_DIR:-$TOP_DIR/subprojects/frida-core}"
GUM_DIR="${GUM_DIR:-$TOP_DIR/subprojects/frida-gum}"
OUT_DIR="${OUT_DIR:-/Users/tbs/Documents/Codex/2026-07-21/https-mp-weixin-qq-com-s/outputs/codex-16.7.19-hardening}"

DEVICE_IP="${DEVICE_IP:-192.168.3.158}"
ADB_PORT="${ADB_PORT:-5555}"
SERIAL="${SERIAL:-$DEVICE_IP:$ADB_PORT}"
ADB_CONNECT_TIMEOUT="${ADB_CONNECT_TIMEOUT:-8}"
ADB_BIN="${ADB_BIN:-$(command -v adb 2>/dev/null || true)}"

FRIDA_PORT="${FRIDA_PORT:-28191}"
FRIDA_CLUSTER_PORT="${FRIDA_CLUSTER_PORT:-28192}"
LOCAL_BIN="${LOCAL_BIN:-/tmp/fs-16.7.19-codex}"
REMOTE_BIN="${REMOTE_BIN:-/data/local/tmp/app_process64}"
REMOTE_LOG="${REMOTE_LOG:-/data/local/tmp/app_process64.log}"
REMOTE_NAME="${REMOTE_NAME:-$(basename "$REMOTE_BIN")}"
LISTEN_HOST="${LISTEN_HOST:-127.0.0.1}"
LOCAL_FORWARD_PORT="${LOCAL_FORWARD_PORT:-$FRIDA_PORT}"

FRIDA_BIN="${FRIDA_BIN:-$HOME/.local/bin/frida}"
FRIDA_PS_BIN="${FRIDA_PS_BIN:-$HOME/.local/bin/frida-ps}"
JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)}"

log() { printf '[frida-16.7.19] %s\n' "$*"; }
die() { printf '[frida-16.7.19] %s\n' "$*" >&2; exit 1; }
need_file() { [[ -f "$1" ]] || die "file missing: $1"; }
need_dir() { [[ -d "$1" ]] || die "directory missing: $1"; }
need_adb() { [[ -n "$ADB_BIN" && -x "$ADB_BIN" ]] || die "adb not found in PATH; set ADB_BIN=/path/to/adb"; }

is_tcp_serial() { [[ "$SERIAL" == *:* ]]; }

adb_connect_maybe() {
  need_adb
  if ! is_tcp_serial; then
    log "using USB/device serial: $SERIAL"
    return 0
  fi

  log "connecting ADB: $SERIAL"
  "$ADB_BIN" connect "$SERIAL" &
  local pid=$!
  local elapsed=0
  while kill -0 "$pid" 2>/dev/null; do
    if (( elapsed >= ADB_CONNECT_TIMEOUT )); then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      die "adb connect timed out after ${ADB_CONNECT_TIMEOUT}s: $SERIAL"
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  wait "$pid" || die "adb connect failed: $SERIAL"
}

adb_device_shell() {
  need_adb
  "$ADB_BIN" -s "$SERIAL" shell "$@" | tr -d '\r'
}

adb_root_shell() {
  need_adb
  local cmd="$1"
  "$ADB_BIN" -s "$SERIAL" shell su -c "$cmd" 2>/dev/null | tr -d '\r' || \
    "$ADB_BIN" -s "$SERIAL" shell sh -c "$cmd" 2>/dev/null | tr -d '\r'
}

adb_require_ready() {
  adb_device_shell 'echo adb-ok' >/dev/null || die "adb device not ready: $SERIAL"
}

resolve_ndk_root() {
  if [[ -n "${ANDROID_NDK_ROOT:-}" && -d "$ANDROID_NDK_ROOT" ]]; then
    printf '%s\n' "$ANDROID_NDK_ROOT"
    return 0
  fi

  local candidates=(
    "/Users/tbs/.homebrew/share/android-commandlinetools/ndk/25.2.9519653"
    "$HOME/Library/Android/sdk/ndk/25.2.9519653"
    "${ANDROID_HOME:-}/ndk/25.2.9519653"
    "${ANDROID_SDK_ROOT:-}/ndk/25.2.9519653"
  )
  local c
  for c in "${candidates[@]}"; do
    [[ -n "$c" && -d "$c" ]] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}

print_summary() {
  cat <<MSG
version: 16.7.19
top: $TOP_DIR
core: $CORE_DIR
phone: $SERIAL
local_bin: $LOCAL_BIN
remote_bin: $REMOTE_BIN
port: $FRIDA_PORT
client: $FRIDA_PS_BIN / $FRIDA_BIN
MSG
}
