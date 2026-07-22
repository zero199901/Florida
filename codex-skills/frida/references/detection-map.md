# Detection map

Use this map when checking whether codex-16.7.19 covers the article-style Frida checks.

## Covered by the current 16.7.19 workflow

1. Phone binary path/name:
   - Default to `/data/local/tmp/app_process64` and `/data/local/tmp/app_process64.log`.
   - This matches the source-level `g_set_prgname("app_process64")` patch.
   - The deploy script also stops legacy `/data/local/tmp/fs` before starting the default server.
   - Keep `frida`, `gum`, `gmain`, `gdbus`, `linjector`, and `agent` out of process/file/thread-visible names.
2. TCP defaults:
   - Source default ports are `28191` and `28192` instead of `27042`/`27043`.
   - Use `$HOME/.local/bin/frida-ps -H 127.0.0.1:28191` after `adb forward`.
3. Embedded Android agent asset names:
   - Expected `strings`: `libbase-32.so`, `libbase-64.so`, `libbase-arm.so`, `libbase-arm64.so`.
   - Expected absence: fixed `frida-agent-*.so` asset names.
4. High-signal thread markers:
   - Current agent post-link patch targets `gum-js-loop`, `pool-frida`, `gmain`, `gdbus`, `frida_agent_main`, and common Gum/GIO labels.
5. Runtime scan:
   - Check `ps -A`, `/proc/$PID/task/*/comm`, `/proc/$PID/maps`, `/proc/$PID/fd` using `scripts/check_16719_phone.sh`.
6. Android 16 stability gates:
   - System agents are opt-in through `FRIDA_ENABLE_ANDROID_SYSTEM_AGENTS=1`.
   - Java bridge is gated on API 36+ unless `/data/local/tmp/frida-enable-java-bridge` exists.

## Intentionally preserved for client compatibility

- `re.frida.*` DBus interface names.
- `frida:rpc` JavaScript bridge strings.

Only change these when building a matching custom client stack.

## Article chain probes

Use the scripts in:

```text
/Users/tbs/Documents/Codex/2026-07-21/https-mp-weixin-qq-com-s/outputs/codex-16.7.19-hardening
```

Primary scripts:

```text
article_chain_probe.js
frida_codex_regression_test.js
runtime_proc_scan.sh
static_scan.sh
```

Article-style checkpoints:

1. Hook/observe `dlopen` and `android_dlopen_ext` for obvious agent filenames.
2. Observe linker `call_constructors` timing for module/thread changes.
3. Hook/observe `pthread_create` and map thread entry addresses to modules.
4. Enumerate loaded `.so` modules and `/proc` surfaces after injection.
