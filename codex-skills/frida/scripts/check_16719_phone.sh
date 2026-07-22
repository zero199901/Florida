#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common_16719.sh"

adb_connect_maybe
adb_require_ready
"$ADB_BIN" -s "$SERIAL" forward "tcp:$LOCAL_FORWARD_PORT" "tcp:$FRIDA_PORT" >/dev/null || true

log "runtime /proc scan: $REMOTE_NAME"
ANDROID_SERIAL="$SERIAL" "$OUT_DIR/runtime_proc_scan.sh" "$REMOTE_NAME"

log "client process listing"
"$FRIDA_PS_BIN" -H "127.0.0.1:$LOCAL_FORWARD_PORT"
