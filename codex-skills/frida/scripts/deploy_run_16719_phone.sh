#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common_16719.sh"

need_file "$LOCAL_BIN"
adb_connect_maybe
adb_require_ready

log "stopping existing $REMOTE_BIN and legacy /data/local/tmp/fs"
adb_root_shell "pkill -f '$REMOTE_BIN' || true" >/dev/null || true
if [[ "$REMOTE_BIN" != "/data/local/tmp/fs" ]]; then
  adb_root_shell "pkill -f '/data/local/tmp/fs' || true" >/dev/null || true
fi

log "pushing $LOCAL_BIN -> $REMOTE_BIN"
"$ADB_BIN" -s "$SERIAL" push "$LOCAL_BIN" "$REMOTE_BIN" >/dev/null
"$ADB_BIN" -s "$SERIAL" shell chmod 755 "$REMOTE_BIN"

log "starting $REMOTE_BIN on $LISTEN_HOST:$FRIDA_PORT"
adb_root_shell "'$REMOTE_BIN' -l '$LISTEN_HOST:$FRIDA_PORT' >'$REMOTE_LOG' 2>&1 &" >/dev/null
sleep 1

log "forwarding 127.0.0.1:$LOCAL_FORWARD_PORT -> device:$FRIDA_PORT"
"$ADB_BIN" -s "$SERIAL" forward "tcp:$LOCAL_FORWARD_PORT" "tcp:$FRIDA_PORT" >/dev/null

cat <<MSG
Frida 16.7.19 server started
serial: $SERIAL
remote: $REMOTE_BIN
listen: $LISTEN_HOST:$FRIDA_PORT
forward: 127.0.0.1:$LOCAL_FORWARD_PORT -> device:$FRIDA_PORT
log: $REMOTE_LOG

Test:
  $FRIDA_PS_BIN -H 127.0.0.1:$LOCAL_FORWARD_PORT
MSG
