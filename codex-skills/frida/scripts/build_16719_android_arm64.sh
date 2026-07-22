#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common_16719.sh"

need_dir "$TOP_DIR"
NDK_ROOT="$(resolve_ndk_root)" || die "Android NDK r25c not found; set ANDROID_NDK_ROOT=/path/to/android-ndk-r25c"
export ANDROID_NDK_ROOT="$NDK_ROOT"

AUTO_DELETE_CODEX_LOCAL_TAG="${AUTO_DELETE_CODEX_LOCAL_TAG:-1}"
if [[ "$AUTO_DELETE_CODEX_LOCAL_TAG" == "1" ]] && git -C "$TOP_DIR" tag --list 'v16.7.19-codex' | grep -q .; then
  log "deleting local v16.7.19-codex tag before configure to keep Frida version parser numeric"
  git -C "$TOP_DIR" tag -d v16.7.19-codex >/dev/null
fi

log "building with ANDROID_NDK_ROOT=$ANDROID_NDK_ROOT"
cd "$TOP_DIR"
./configure --host=android-arm64
./releng/meson/meson.py compile -C build frida-server -j "$JOBS"

candidates=(
  "$TOP_DIR/build/subprojects/frida-core/server/frida-server"
  "$TOP_DIR/build/frida-server"
)
for f in "${candidates[@]}"; do
  if [[ -f "$f" ]]; then
    cp "$f" "$LOCAL_BIN"
    chmod 755 "$LOCAL_BIN"
    log "built: $LOCAL_BIN"
    file "$LOCAL_BIN" || true
    ls -lh "$LOCAL_BIN"
    exit 0
  fi
done

die "frida-server artifact not found under $TOP_DIR/build"
