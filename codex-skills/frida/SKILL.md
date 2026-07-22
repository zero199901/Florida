---
name: frida
description: "Use this skill for the local Frida/Florida Android 16.7.19 workflow including patching default Frida ports, renaming Android frida-server and agent-visible artifacts, building codex-16.7.19 frida-server, deploying to the 192.168.3.158 Android phone, running Frida client regression tests, updating zero199901/Florida branches and releases, and checking Frida/Gum detection surfaces from strings, procfs, dlopen, call_constructors, and pthread_create probes."
---

# Frida

## Workspace defaults

```text
Version: 16.7.19
Phone: 192.168.3.158:5555
Top repo: /Users/tbs/Documents/Codex/2026-07-21/frida-16.7.19-florida
Core: /Users/tbs/Documents/Codex/2026-07-21/frida-16.7.19-florida/subprojects/frida-core
Gum: /Users/tbs/Documents/Codex/2026-07-21/frida-16.7.19-florida/subprojects/frida-gum
Branch: codex-16.7.19
Core remote branch: frida-core-codex-16.7.19
Gum remote branch: frida-gum-codex-16.7.19
Top remote branch: codex-16.7.19
Local server: /tmp/fs-16.7.19-codex
Phone server: /data/local/tmp/app_process64
Control port: 28191
Cluster port: 28192
Client: $HOME/.local/bin/frida and $HOME/.local/bin/frida-ps
Detection dir: /Users/tbs/Documents/Codex/2026-07-21/https-mp-weixin-qq-com-s/outputs/codex-16.7.19-hardening
Release: https://github.com/zero199901/Florida/releases/tag/v16.7.19-codex
```

Use `-H 127.0.0.1:28191` after `adb forward`. Default phone-side binary name is `/data/local/tmp/app_process64` so `/proc/<pid>/cmdline` and `ps` show a system-style process name.

## Fast path

```bash
# Build or rebuild Android arm64 server
/Users/tbs/.codex/skills/frida/scripts/build_16719_android_arm64.sh

# Deploy and run on 192.168.3.158
/Users/tbs/.codex/skills/frida/scripts/deploy_run_16719_phone.sh

# Check runtime surfaces and client connectivity
/Users/tbs/.codex/skills/frida/scripts/check_16719_phone.sh

# Full deploy + check bundle
/Users/tbs/.codex/skills/frida/scripts/test_16719_phone.sh
```

USB/device serial override:

```bash
SERIAL=<usb_serial> /Users/tbs/.codex/skills/frida/scripts/deploy_run_16719_phone.sh
SERIAL=<usb_serial> /Users/tbs/.codex/skills/frida/scripts/check_16719_phone.sh
```

## Script resources

- `scripts/common_16719.sh`: shared defaults, ADB timeout, NDK autodetect, path helpers.
- `scripts/patch_16719_ports.sh`: set `DEFAULT_CONTROL_PORT=28191` and `DEFAULT_CLUSTER_PORT=28192` in `frida-core/lib/base/socket.vala`.
- `scripts/build_16719_android_arm64.sh`: configure/build Android arm64 `frida-server`, copy to `/tmp/fs-16.7.19-codex`, auto-use local NDK r25c when present.
- `scripts/deploy_run_16719_phone.sh`: connect ADB, push `/tmp/fs-16.7.19-codex` to `/data/local/tmp/app_process64`, start it on `127.0.0.1:28191`, and forward the port.
- `scripts/check_16719_phone.sh`: run `/proc` runtime scan and `$HOME/.local/bin/frida-ps -H 127.0.0.1:28191`.
- `scripts/static_scan_16719.sh`: run static string scan plus embedded Android asset-name check.
- `scripts/test_16719_phone.sh`: deploy + check, with optional app regression via `RUN_APP_TEST=1`.
- `scripts/chunqiu_native_check_monitor.js`: Spring-and-Autumn Native Check (`com.chunqiunativecheck`) native monitor for libc/libdl/procfs/ptrace/JNI detection tracing.

All scripts accept environment overrides: `TOP_DIR`, `CORE_DIR`, `DEVICE_IP`, `ADB_PORT`, `SERIAL`, `ADB_BIN`, `FRIDA_PORT`, `FRIDA_CLUSTER_PORT`, `LOCAL_BIN`, `REMOTE_BIN`, `LOCAL_FORWARD_PORT`, `FRIDA_BIN`, `FRIDA_PS_BIN`, `JOBS`.

## Known local source state

Current hardened commits:

```text
frida-core: 266adb1e Gate Android system agents for stability
frida-gum:  540bad22 Stabilize Android 16 Java bridge gating
top repo:   e9f5f4c Document Android 16 stability profile
```

Earlier hardening includes:

```text
frida-core 814401aa: post-link Android agent marker patching + libbase fallback
frida-core 88b475ad: non-default control/cluster ports 28191/28192
frida-gum  9c57403b: g_set_prgname("ggbond") / pool-frida work
```

Embedded Android resources should show `libbase-*.so`, not `frida-agent-*.so`:

```bash
strings -a /tmp/fs-16.7.19-codex | grep -E 'frida-agent-(32|64|arm|arm64)\.so|libbase-(32|64|arm|arm64)\.so'
```


## Default system-style process name

The skill defaults now deploy the modified server as:

```text
REMOTE_BIN=/data/local/tmp/app_process64
REMOTE_LOG=/data/local/tmp/app_process64.log
REMOTE_NAME=app_process64
```

This matches the source-level `g_set_prgname("app_process64")` patch and makes the outer process name line up with Android system-style naming. The deploy script also stops the legacy `/data/local/tmp/fs` process when the default disguised binary is used, so old and new servers do not compete for the same port.

Quick verification:

```bash
SERIAL=5c8093e4 /Users/tbs/.codex/skills/frida/scripts/deploy_run_16719_phone.sh
adb -s 5c8093e4 shell 'pidof app_process64; ps -A | grep app_process64'
SERIAL=5c8093e4 /Users/tbs/.codex/skills/frida/scripts/check_16719_phone.sh
```

Legacy name override remains available when needed:

```bash
SERIAL=5c8093e4 \
REMOTE_BIN=/data/local/tmp/fs \
REMOTE_LOG=/data/local/tmp/fs.log \
REMOTE_NAME=fs \
/Users/tbs/.codex/skills/frida/scripts/deploy_run_16719_phone.sh
```

## Build notes

Use NDK r25c. The build script auto-detects:

```text
/Users/tbs/.homebrew/share/android-commandlinetools/ndk/25.2.9519653
$HOME/Library/Android/sdk/ndk/25.2.9519653
$ANDROID_HOME/ndk/25.2.9519653
$ANDROID_SDK_ROOT/ndk/25.2.9519653
```

The script deletes a local `v16.7.19-codex` tag before configure by default because Frida's local version parser expects numeric tag text. Disable this with:

```bash
AUTO_DELETE_CODEX_LOCAL_TAG=0 /Users/tbs/.codex/skills/frida/scripts/build_16719_android_arm64.sh
```

## Detection workflow

Static check:

```bash
/Users/tbs/.codex/skills/frida/scripts/static_scan_16719.sh /tmp/fs-16.7.19-codex
```

Runtime check:

```bash
/Users/tbs/.codex/skills/frida/scripts/check_16719_phone.sh
```

Regression against Settings:

```bash
RUN_APP_TEST=1 TEST_APP=com.android.settings /Users/tbs/.codex/skills/frida/scripts/test_16719_phone.sh
```

Manual probes:

```bash
$HOME/.local/bin/frida -H 127.0.0.1:28191 -f com.android.settings \
  -l /Users/tbs/Documents/Codex/2026-07-21/https-mp-weixin-qq-com-s/outputs/codex-16.7.19-hardening/frida_codex_regression_test.js \
  --no-pause

$HOME/.local/bin/frida -H 127.0.0.1:28191 -f com.android.settings \
  -l /Users/tbs/Documents/Codex/2026-07-21/https-mp-weixin-qq-com-s/outputs/codex-16.7.19-hardening/article_chain_probe.js \
  --no-pause
```

Inspect `references/detection-map.md` and `references/ports-and-filenames.md` before expanding source-level marker changes.


## Spring-and-Autumn Native Check example

Use this workflow for `com.chunqiunativecheck` / “春秋 Native Check-Eros 3.7fix” on the Android 16 USB phone. This is a concrete native-only regression example for the modified Frida build.

Observed app facts from the local test device:

```text
Package: com.chunqiunativecheck
Launch activity: com.chunqiunativecheck/.SplashActivity
Main activity: com.chunqiunativecheck/.MainActivity
Version: 3.7fix
ABI: arm64-v8a
Native library: libchunqiunative.so
JNI exports: JNI_OnLoad, Java_com_chunqiunativecheck_Z_a, Java_com_chunqiunativecheck_Z_b
Imported native API of interest: ptrace@LIBC
```

Launch and capture UI text:

```bash
SERIAL=5c8093e4
PKG=com.chunqiunativecheck
adb -s "$SERIAL" shell am force-stop "$PKG"
adb -s "$SERIAL" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
sleep 2
adb -s "$SERIAL" shell pidof "$PKG"
adb -s "$SERIAL" shell uiautomator dump /sdcard/window.xml
adb -s "$SERIAL" pull /sdcard/window.xml /tmp/chunqiu-window.xml
```

Attach with the reusable monitor:

```bash
SERIAL=5c8093e4
HOST=127.0.0.1:28191
PKG=com.chunqiunativecheck
PID=$(adb -s "$SERIAL" shell pidof "$PKG" | tr -d '\r' | awk '{print $1}')

$HOME/.local/bin/frida \
  -H "$HOST" \
  -p "$PID" \
  -l /Users/tbs/.codex/skills/frida/scripts/chunqiu_native_check_monitor.js \
  -q \
  --runtime=qjs \
  --timeout 20
```

Expected stable attach banner:

```text
[monitor] start pid=<PID> arch=arm64 java=false
[app-module] base.odex .../com.chunqiunativecheck.../oat/arm64/base.odex
[app-module] libchunqiunative.so .../base.apk!/lib/arm64-v8a/libchunqiunative.so
[hook] libc.so!open
[hook] libc.so!openat
[hook] libc.so!readlink
[hook] libc.so!ptrace
[hook] libdl.so!android_dlopen_ext
[hook] libc.so!strstr
[hook] libc.so!pthread_create
[hook] libchunqiunative.so exports Z.a/Z.b
```

The monitor traces these native detection surfaces:

- `/proc` reads through `open`, `openat`, `readlink`, `stat`, `lstat`, and `access`.
- fd/maps/task/status/tracerpid keyword checks.
- `ptrace` anti-debug calls.
- `dlopen` / `android_dlopen_ext` library loads.
- `strstr` / `strcasestr` keyword comparisons for Frida/Gum/Xposed/Zygisk/Magisk/KSU markers.
- `pthread_create` detection-thread creation.
- `Java_com_chunqiunativecheck_Z_a` and `Java_com_chunqiunativecheck_Z_b` return values.

Android 16 stability profile note: `Java.available=false` is expected unless the phone contains `/data/local/tmp/frida-enable-java-bridge`. For this example prefer native hooks first.

Post-run state check:

```bash
adb -s 5c8093e4 shell 'echo boot=$(getprop sys.boot_completed); echo fs=$(pidof fs); echo app=$(pidof com.chunqiunativecheck); echo tombstones=$(ls /data/tombstones/tombstone_* 2>/dev/null | wc -l)'
```

Recent local test output:

```text
[monitor] start pid=31536 arch=arm64 java=false
[app-module] libchunqiunative.so base=0x723b807000 size=8224768 path=/data/app/.../base.apk!/lib/arm64-v8a/libchunqiunative.so
[hook] libc.so!ptrace @ 0x7594b2b3d0
[hook] libchunqiunative.so exports Z.a/Z.b
boot=1
fs=11522
app=31536
```

## Git/release workflow

Commit submodule first, then top repo:

```bash
git -C /Users/tbs/Documents/Codex/2026-07-21/frida-16.7.19-florida/subprojects/frida-core diff --check
git -C /Users/tbs/Documents/Codex/2026-07-21/frida-16.7.19-florida/subprojects/frida-core add FILES
git -C /Users/tbs/Documents/Codex/2026-07-21/frida-16.7.19-florida/subprojects/frida-core commit -m "..."
git -C /Users/tbs/Documents/Codex/2026-07-21/frida-16.7.19-florida add subprojects/frida-core
git -C /Users/tbs/Documents/Codex/2026-07-21/frida-16.7.19-florida commit -m "..."
```

Push mapping:

```bash
git -C /Users/tbs/Documents/Codex/2026-07-21/frida-16.7.19-florida/subprojects/frida-core push florida codex-16.7.19:refs/heads/frida-core-codex-16.7.19
git -C /Users/tbs/Documents/Codex/2026-07-21/frida-16.7.19-florida/subprojects/frida-gum push florida codex-16.7.19:refs/heads/frida-gum-codex-16.7.19
git -C /Users/tbs/Documents/Codex/2026-07-21/frida-16.7.19-florida push florida codex-16.7.19:refs/heads/codex-16.7.19
```

Update release asset:

```bash
gh release upload v16.7.19-codex /tmp/fs-16.7.19-codex --repo zero199901/Florida --clobber
gh release edit v16.7.19-codex --repo zero199901/Florida --target codex-16.7.19
```
