#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common_16719.sh"

SOCKET_FILE="$CORE_DIR/lib/base/socket.vala"
need_file "$SOCKET_FILE"

python3 - <<PY
from pathlib import Path
import re
p = Path("$SOCKET_FILE")
s = p.read_text()
s = re.sub(r"public const uint16 DEFAULT_CONTROL_PORT = \d+;", "public const uint16 DEFAULT_CONTROL_PORT = $FRIDA_PORT;", s)
s = re.sub(r"public const uint16 DEFAULT_CLUSTER_PORT = \d+;", "public const uint16 DEFAULT_CLUSTER_PORT = $FRIDA_CLUSTER_PORT;", s)
p.write_text(s)
PY

git -C "$CORE_DIR" diff -- lib/base/socket.vala
