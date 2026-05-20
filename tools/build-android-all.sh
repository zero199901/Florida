#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -z "${ANDROID_NDK_ROOT:-}" ]]; then
  echo "ANDROID_NDK_ROOT is not set" >&2
  exit 1
fi

if [[ ! -d "${ANDROID_NDK_ROOT}" ]]; then
  echo "ANDROID_NDK_ROOT does not exist: ${ANDROID_NDK_ROOT}" >&2
  exit 1
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing command: $1" >&2
    exit 1
  fi
}

for cmd in git python3 gzip tee; do
  require_cmd "$cmd"
done

FRIDA_VERSION="${FRIDA_VERSION:-17.9.10}"
WORK_ROOT="${WORK_ROOT:-${REPO_ROOT}/.work-local}"
FRIDA_DIR="${WORK_ROOT}/frida-${FRIDA_VERSION}"
RELEASE_DIR="${REPO_ROOT}/release-assets-local"
LOG_DIR="${REPO_ROOT}/logs"
ARCHES=(android-arm android-arm64 android-x86 android-x86_64)

mkdir -p "${WORK_ROOT}" "${RELEASE_DIR}" "${LOG_DIR}"

if [[ -e "${FRIDA_DIR}" ]]; then
  echo "Working tree already exists: ${FRIDA_DIR}" >&2
  echo "Please remove it manually or set a different WORK_ROOT" >&2
  exit 1
fi

log() {
  printf '[*] %s\n' "$*"
}

run_logged() {
  local logfile="$1"
  shift
  "$@" 2>&1 | tee -a "${logfile}"
}

clone_frida() {
  log "Clone Frida ${FRIDA_VERSION}"
  git clone --recurse-submodules https://github.com/frida/frida "${FRIDA_DIR}"
  (
    cd "${FRIDA_DIR}"
    git checkout "${FRIDA_VERSION}"
    git submodule update --init --recursive
  )
}

apply_patches() {
  log "Apply Florida patches"
  local path
  for path in "${REPO_ROOT}"/patches/*; do
    local name
    name="$(basename "${path}")"
    (
      cd "${FRIDA_DIR}/subprojects/${name}"
      git am "${path}"/*.patch
    )
  done
}

build_one() {
  local arch="$1"
  local build_dir="${WORK_ROOT}/build-${arch}"
  local logfile="${LOG_DIR}/build-${arch}.log"

  mkdir -p "${build_dir}"
  : > "${logfile}"
  (
    cd "${build_dir}"
    run_logged "${logfile}" "${FRIDA_DIR}/configure" --host="${arch}"
    run_logged "${logfile}" make -j"$(nproc)"
  )
}

package_artifacts() {
  local version="$1"
  local llvm_strip="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
  local post_process="${FRIDA_DIR}/subprojects/frida-core/src/anti-anti-frida.py"

  if [[ ! -x "${llvm_strip}" ]]; then
    echo "llvm-strip not found: ${llvm_strip}" >&2
    exit 1
  fi

  if [[ ! -f "${post_process}" ]]; then
    echo "post-process script not found: ${post_process}" >&2
    exit 1
  fi

  rm -f "${RELEASE_DIR}"/florida-*.gz

  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-arm/subprojects/frida-core/server/frida-server"
  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-arm64/subprojects/frida-core/server/frida-server"
  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-x86/subprojects/frida-core/server/frida-server"
  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-x86_64/subprojects/frida-core/server/frida-server"

  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-arm/subprojects/frida-core/inject/frida-inject"
  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-arm64/subprojects/frida-core/inject/frida-inject"
  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-x86/subprojects/frida-core/inject/frida-inject"
  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-x86_64/subprojects/frida-core/inject/frida-inject"

  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-arm/subprojects/frida-core/lib/gadget/frida-gadget.so"
  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-arm64/subprojects/frida-core/lib/gadget/frida-gadget.so"
  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-x86/subprojects/frida-core/lib/gadget/frida-gadget.so"
  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-x86_64/subprojects/frida-core/lib/gadget/frida-gadget.so"

  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-arm/subprojects/frida-gum/bindings/gumjs/libfrida-gumjs-1.0.a"
  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-arm64/subprojects/frida-gum/bindings/gumjs/libfrida-gumjs-1.0.a"
  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-x86/subprojects/frida-gum/bindings/gumjs/libfrida-gumjs-1.0.a"
  "${llvm_strip}" --strip-debug "${WORK_ROOT}/build-android-x86_64/subprojects/frida-gum/bindings/gumjs/libfrida-gumjs-1.0.a"

  python3 "${post_process}" "${WORK_ROOT}/build-android-arm/subprojects/frida-gum/bindings/gumjs/libfrida-gumjs-1.0.a"
  python3 "${post_process}" "${WORK_ROOT}/build-android-arm64/subprojects/frida-gum/bindings/gumjs/libfrida-gumjs-1.0.a"
  python3 "${post_process}" "${WORK_ROOT}/build-android-x86/subprojects/frida-gum/bindings/gumjs/libfrida-gumjs-1.0.a"
  python3 "${post_process}" "${WORK_ROOT}/build-android-x86_64/subprojects/frida-gum/bindings/gumjs/libfrida-gumjs-1.0.a"

  gzip -c "${WORK_ROOT}/build-android-arm/subprojects/frida-core/server/frida-server" > \
    "${RELEASE_DIR}/florida-server-${version}-android-arm.gz"
  gzip -c "${WORK_ROOT}/build-android-arm64/subprojects/frida-core/server/frida-server" > \
    "${RELEASE_DIR}/florida-server-${version}-android-arm64.gz"
  gzip -c "${WORK_ROOT}/build-android-x86/subprojects/frida-core/server/frida-server" > \
    "${RELEASE_DIR}/florida-server-${version}-android-x86.gz"
  gzip -c "${WORK_ROOT}/build-android-x86_64/subprojects/frida-core/server/frida-server" > \
    "${RELEASE_DIR}/florida-server-${version}-android-x86_64.gz"

  gzip -c "${WORK_ROOT}/build-android-arm/subprojects/frida-core/inject/frida-inject" > \
    "${RELEASE_DIR}/florida-inject-${version}-android-arm.gz"
  gzip -c "${WORK_ROOT}/build-android-arm64/subprojects/frida-core/inject/frida-inject" > \
    "${RELEASE_DIR}/florida-inject-${version}-android-arm64.gz"
  gzip -c "${WORK_ROOT}/build-android-x86/subprojects/frida-core/inject/frida-inject" > \
    "${RELEASE_DIR}/florida-inject-${version}-android-x86.gz"
  gzip -c "${WORK_ROOT}/build-android-x86_64/subprojects/frida-core/inject/frida-inject" > \
    "${RELEASE_DIR}/florida-inject-${version}-android-x86_64.gz"

  gzip -c "${WORK_ROOT}/build-android-arm/subprojects/frida-core/lib/gadget/frida-gadget.so" > \
    "${RELEASE_DIR}/florida-gadget-${version}-android-arm.so.gz"
  gzip -c "${WORK_ROOT}/build-android-arm64/subprojects/frida-core/lib/gadget/frida-gadget.so" > \
    "${RELEASE_DIR}/florida-gadget-${version}-android-arm64.so.gz"
  gzip -c "${WORK_ROOT}/build-android-x86/subprojects/frida-core/lib/gadget/frida-gadget.so" > \
    "${RELEASE_DIR}/florida-gadget-${version}-android-x86.so.gz"
  gzip -c "${WORK_ROOT}/build-android-x86_64/subprojects/frida-core/lib/gadget/frida-gadget.so" > \
    "${RELEASE_DIR}/florida-gadget-${version}-android-x86_64.so.gz"

  gzip -c "${WORK_ROOT}/build-android-arm/subprojects/frida-gum/bindings/gumjs/libfrida-gumjs-1.0.a" > \
    "${RELEASE_DIR}/florida-gumjs-${version}-android-arm.a.gz"
  gzip -c "${WORK_ROOT}/build-android-arm64/subprojects/frida-gum/bindings/gumjs/libfrida-gumjs-1.0.a" > \
    "${RELEASE_DIR}/florida-gumjs-${version}-android-arm64.a.gz"
  gzip -c "${WORK_ROOT}/build-android-x86/subprojects/frida-gum/bindings/gumjs/libfrida-gumjs-1.0.a" > \
    "${RELEASE_DIR}/florida-gumjs-${version}-android-x86.a.gz"
  gzip -c "${WORK_ROOT}/build-android-x86_64/subprojects/frida-gum/bindings/gumjs/libfrida-gumjs-1.0.a" > \
    "${RELEASE_DIR}/florida-gumjs-${version}-android-x86_64.a.gz"
}

verify_artifacts() {
  local logfile="${LOG_DIR}/verify-patch.log"
  run_logged "${logfile}" python3 "${REPO_ROOT}/tools/verify-patch.py" "${RELEASE_DIR}"
  run_logged "${logfile}" python3 "${REPO_ROOT}/tools/verify-patch.py" "${RELEASE_DIR}" --strict
  run_logged "${logfile}" python3 "${REPO_ROOT}/tools/scan-frida-signatures.py" \
    "${RELEASE_DIR}"/florida-server-*-android-*.gz \
    "${RELEASE_DIR}"/florida-inject-*-android-*.gz \
    "${RELEASE_DIR}"/florida-gadget-*-android-*.so.gz \
    --rules deep \
    --limit 5
}

main() {
  clone_frida
  apply_patches

  local arch
  for arch in "${ARCHES[@]}"; do
    log "Build ${arch}"
    build_one "${arch}"
  done

  log "Package artifacts"
  package_artifacts "${FRIDA_VERSION}"

  log "Verify artifacts"
  verify_artifacts

  log "Done"
  log "Release dir: ${RELEASE_DIR}"
  log "Log dir: ${LOG_DIR}"
}

main "$@"
