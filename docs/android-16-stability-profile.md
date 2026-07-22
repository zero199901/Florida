# Android 16 稳定运行配置：Frida/Florida 16.7.19

本文记录 `codex-16.7.19` 分支的 Android 16 稳定性修复、构建部署方式和 USB 回归结果。目标机通过 USB 连接，序列号为 `5c8093e4`；服务端默认监听本机转发端口 `127.0.0.1:28191`。

## 背景

此前魔改版 `frida-server` 在 Android 16 手机上运行时触发过整机重启。排查结果显示主要高风险点集中在两个位置：

1. 服务启动阶段默认预加载 `system_server` agent 和 zygote launcher。Android 16 上该路径可能卡在 ActivityManager 线程的 syscall 等待流程，造成系统级不稳定。
2. 对 Android 16 目标进程执行 `Java.perform()` 时，`frida-java-bridge` 初始化路径可导致目标进程崩溃。历史 tombstone 的 fault addr 为 `0x11`，位于匿名 RX 映射附近。

本次配置以稳定优先为原则：默认保留 native attach、模块枚举、进程枚举等基础能力，同时把 Android 16 上容易触发重启或崩溃的路径改成显式 opt-in。

## 修改摘要

### 1. Android system agents 默认关闭

文件：`subprojects/frida-core/src/linux/linux-host-session.vala`

新增环境变量开关：

```bash
FRIDA_ENABLE_ANDROID_SYSTEM_AGENTS=1
```

默认行为：

- `preload()` 跳过 `system_server_agent.preload()` 与 `robo_launcher.preload()`。
- `enumerate_applications()` 返回空应用列表，并打印提示。
- `enumerate_processes()` 仅返回 `/proc` 进程枚举结果，跳过 system_server 元数据增强。
- package name 形式的 spawn 仅在启用 system agents 后走 `robo_launcher.spawn()`。
- `kill()` 中基于 system_server 的按 PID 停包逻辑仅在启用 system agents 后执行。

启用命令示例：

```bash
adb -s 5c8093e4 shell 'su -c "FRIDA_ENABLE_ANDROID_SYSTEM_AGENTS=1 /data/local/tmp/fs -l 127.0.0.1:28191"'
```

默认部署脚本保持稳定配置，未注入该环境变量。

### 2. Android 16 Java bridge 默认 gated

文件：`subprojects/frida-gum/bindings/gumjs/runtime/java.js`

运行时逻辑：

- 非 Linux 平台：照常加载 `frida-java-bridge`。
- Linux 且读取 `ro.build.version.sdk` 小于 36：照常加载 `frida-java-bridge`。
- Android API 36 及以上：默认使用 `Frida._java` stub，`Java.available === false`。
- 如需打开 Java bridge，可在手机上创建 opt-in 文件：

```bash
adb -s 5c8093e4 shell 'touch /data/local/tmp/frida-enable-java-bridge'
# 或
adb -s 5c8093e4 shell 'touch /data/local/tmp/.frida-enable-java-bridge'
```

恢复稳定默认值：

```bash
adb -s 5c8093e4 shell 'rm /data/local/tmp/frida-enable-java-bridge /data/local/tmp/.frida-enable-java-bridge 2>/dev/null || true'
```

默认 gated 时，调用 `Java.perform()` 会打印明确错误；目标 app、`frida-server` 和手机系统保持运行。

### 3. embedded agent 二进制内容保持原样

文件：`subprojects/frida-core/src/anti-anti-frida.py`

原有构建后处理会对 embedded agent 执行较激进的字符串改写。当前稳定配置把该脚本收敛为 no-op：

- server 端资源名、端口和进程名仍由其它补丁处理。
- Gum/Java bridge 相关二进制内容保持构建产物原样。
- 降低构建期误改 runtime blob 后引发启动、attach 或 Java bridge 异常的概率。

### 4. 进程名调整

文件：

- `subprojects/frida-core/src/frida-glue.c`
- `subprojects/frida-gum/gum/gum.c`

`g_set_prgname()` 设置为 `app_process64`，避免使用旧的自定义名称。

### 5. QuickJS FFI 稳定性回补

文件：

- `subprojects/frida-gum/bindings/gumjs/gumffi.c`
- `subprojects/frida-gum/bindings/gumjs/gumffi.h`
- `subprojects/frida-gum/bindings/gumjs/gumquickcore.c`

回补 upstream `gumjs: Fix handling of FFI arguments for QuickJS` 相关改动，并在 `gumffi.h` 中添加兼容别名：

```c
#if defined (HAVE_V8)
typedef union _GumFFIArg GumFFIValue;
#endif
```

该改动保证 16.7.19 当前 V8/QuickJS 混合构建通过，同时保留 upstream FFI 参数处理修复。

## 构建与部署

在顶层仓库执行：

```bash
TOP=/Users/tbs/Documents/Codex/2026-07-21/frida-16.7.19-florida
ninja -C "$TOP/build" subprojects/frida-core/server/frida-server
cp "$TOP/build/subprojects/frida-core/server/frida-server" /tmp/fs-16.7.19-codex
chmod 755 /tmp/fs-16.7.19-codex
```

部署并启动：

```bash
SERIAL=5c8093e4 /Users/tbs/.codex/skills/frida/scripts/deploy_run_16719_phone.sh
```

检查：

```bash
SERIAL=5c8093e4 /Users/tbs/.codex/skills/frida/scripts/check_16719_phone.sh
```

常用客户端：

```bash
$HOME/.local/bin/frida-ps -H 127.0.0.1:28191
$HOME/.local/bin/frida -H 127.0.0.1:28191 -p <PID> -l <SCRIPT.js>
```

## USB 回归结果

测试时间：2026-07-22

| 项目 | 命令 / 场景 | 结果 |
| --- | --- | --- |
| 构建 | `ninja -C ... frida-server` | 通过 |
| server 体积 | `/tmp/fs-16.7.19-codex` | 53,702,368 bytes |
| 部署 | `deploy_run_16719_phone.sh` | `fs` 启动，PID `3956` |
| 端口 | adb forward 到 `127.0.0.1:28191` | 通过 |
| 基础检查 | `check_16719_phone.sh` | rc=0 |
| 进程列表 | `frida-ps -H 127.0.0.1:28191` | 返回进程列表 |
| procfs 扫描 | thread comm / maps / fd | 未见脚本标记的命中 |
| Native attach | attach `com.miui.calculator` PID `27768` | 输出模块列表，目标 app 保持运行 |
| Java.available | Android 16 默认 gated | `java=false`，目标 app 保持运行 |
| Java.perform | Android 16 默认 gated | 输出 gate 错误，目标 app / server / 手机保持运行 |
| tombstone | Java gate 回归后检查 | 未新增 tombstone |
| 系统状态 | `getprop sys.boot_completed` | `1` |

Native attach 输出：

```text
[native-final] pid=27768 arch=arm64 platform=linux
[native-final] modules=app_process64,linker64,libandroid_runtime.so
```

Java gate 输出摘要：

```text
[java-available-only] pid=27768 java=false arch=arm64
[java-perform-empty] pid=27768 java=false arch=arm64
Error: Android API 36 Java bridge is gated by this stability build; create /data/local/tmp/frida-enable-java-bridge to opt in
```

## 操作策略

推荐默认运行方式：

1. 使用部署脚本启动稳定配置的 `/data/local/tmp/fs`。
2. 优先使用 native attach、Interceptor、Module、Memory 等能力验证目标。
3. Android 16 上涉及 Java bridge 的脚本先检查 `Java.available`。
4. 需要集中测试 Java bridge 时，临时创建 opt-in 文件；测试完成后删除 opt-in 文件并重启 `fs`。
5. 需要 app 列表、package spawn 或 system_server 元数据时，单独用 `FRIDA_ENABLE_ANDROID_SYSTEM_AGENTS=1` 启动服务端。

示例脚本模板：

```javascript
console.log('[probe] pid=' + Process.id + ' arch=' + Process.arch + ' java=' + Java.available);

if (Java.available) {
  Java.perform(function () {
    console.log('[probe] Java bridge ready');
  });
} else {
  console.log('[probe] Java bridge gated on this Android build');
}
```

## 变更文件清单

Core：

- `subprojects/frida-core/src/linux/linux-host-session.vala`
- `subprojects/frida-core/src/anti-anti-frida.py`
- `subprojects/frida-core/src/frida-glue.c`

Gum：

- `subprojects/frida-gum/bindings/gumjs/runtime/java.js`
- `subprojects/frida-gum/gum/gum.c`
- `subprojects/frida-gum/bindings/gumjs/gumffi.c`
- `subprojects/frida-gum/bindings/gumjs/gumffi.h`
- `subprojects/frida-gum/bindings/gumjs/gumquickcore.c`

Top：

- `docs/android-16-stability-profile.md`
- `subprojects/frida-core` submodule pointer
- `subprojects/frida-gum` submodule pointer
