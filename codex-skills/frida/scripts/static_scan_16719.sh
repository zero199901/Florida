#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common_16719.sh"

BIN="${1:-$LOCAL_BIN}"
need_file "$BIN"

if [[ -x "$OUT_DIR/static_scan.sh" ]]; then
  "$OUT_DIR/static_scan.sh" "$BIN"
else
  strings -a "$BIN" | grep -Eai 'frida-agent|frida:rpc|gum-js-loop|gmain|gdbus|pool-frida|re\.frida|frida_agent_main|linjector' || true
fi

echo
echo '===== embedded Android asset names ====='
strings -a "$BIN" | grep -E 'frida-agent-(32|64|arm|arm64)\.so|libbase-(32|64|arm|arm64)\.so' | sort -u || true
