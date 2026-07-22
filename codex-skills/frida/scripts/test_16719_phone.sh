#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common_16719.sh"

RUN_APP_TEST="${RUN_APP_TEST:-0}"
TEST_APP="${TEST_APP:-com.android.settings}"

"$SCRIPT_DIR/deploy_run_16719_phone.sh"
"$SCRIPT_DIR/check_16719_phone.sh"

if [[ "$RUN_APP_TEST" == "1" ]]; then
  log "running Java/native regression against $TEST_APP"
  "$FRIDA_BIN" -H "127.0.0.1:$LOCAL_FORWARD_PORT" -f "$TEST_APP" \
    -l "$OUT_DIR/frida_codex_regression_test.js" \
    --no-pause
else
  cat <<MSG
App regression skipped by default. To run it:
  RUN_APP_TEST=1 TEST_APP=$TEST_APP $SCRIPT_DIR/test_16719_phone.sh
MSG
fi
