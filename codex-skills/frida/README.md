# Frida 17.16.4 Android 16 Spawn Skill Add-on

This directory tracks the project-specific Frida 17.16.4 helper for the Android
16 arm64 build. It complements the installed skill at `$HOME/.codex/skills/frida`
and documents the supported `-f` spawn workflow.

## Supported spawn path

The custom server includes Frida Core commit `d01a259b` (`Android: resume
spawned process after RoboLauncher`). It completes the RoboLauncher resume and
ptrace detach sequence after a spawn, so `frida -f` no longer leaves the app
main thread in `ptrace_stop`.

Use the patched 17.16.4 arm64 server (validated device name:
`fs64d_17910_exec`) with Android system agents disabled. With the matching
17.16.4 client, forward the service port and run:

```powershell
& 'D:\code\android\autoandroid\.venv-frida-17.16.4\Scripts\frida.exe' `
  -H 127.0.0.1:28191 `
  -f com.larus.nova `
  -l "$PWD\codex-skills\frida\scripts\doubao_ssl_hook_17164.js"
```

`-f` / `--file` spawns the package and resumes it automatically after the
script has loaded. `--pause` is only for an intentional manual pause;
`--no-pause` is not a Frida 17.16.4 option.

## Preconditions and checks

- The device server and host client must both be 17.16.4.
- Start the server with `FRIDA_DISABLE_ANDROID_SYSTEM_AGENTS=1`.
- Use `-H 127.0.0.1:28191` after port forwarding, so the root server is selected.
- Keep the interactive Frida process alive for live hooks. For a short probe, add `-q --timeout 20`.

After spawning, leave the app running for roughly 20 seconds. Its `TracerPid`
should return to `0`, the process must not remain in `ptrace_stop`, and no new
ANR should be generated. If it still white-screens, redeploy the fixed 17.16.4
server; do not enable Android system agents as a workaround.

## Doubao TLS hook

`scripts/doubao_ssl_hook_17164.js` monitors selected BoringSSL and Cronet
certificate-verification routines for `com.larus.nova`. Using `-f` installs
the module-load hooks before Cronet/BoringSSL loads.
