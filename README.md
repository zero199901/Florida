# Frida 17.16.4（Android 16 spawn 恢复修复）

本仓库基于 Frida 17.16.4，包含针对 Android 16 上 `frida -f` / spawn 注入流程的修复。它适用于已取得调试权限的 Android arm64 设备，解决部分应用在 `spawn → attach → resume` 后主线程停在 `ptrace_stop`、继而触发启动 ANR 或显示白屏的问题。

> 这是一个面向 Android arm64 的定制构建分支，不是官方发布包的替代品。请仅在你拥有或获授权测试的设备和应用上使用。

## 修复内容

Android 的 RoboLauncher fallback 成功恢复目标进程后，旧流程会直接返回，未继续结束 Frida helper 的注入会话。在 Android 16 上，这可能导致被注入进程的主线程保留在 `ptrace_stop` 状态。

修复后的逻辑为：

```text
spawn → attach → resume
                ├─ RoboLauncher 发送 SIGCONT
                └─ helper.resume() 结束注入会话并执行 PTRACE_DETACH
```

当 helper 没有对应的待恢复进程时，`helper.resume()` 返回的 `INVALID_ARGUMENT` 属于预期情况，会被忽略；其他错误仍会正常向上抛出。

实际功能改动位于：

- `subprojects/frida-core/src/linux/linux-host-session.vala`

当前子模块提交：`d01a259b`（`Android: resume spawned process after RoboLauncher`）。

## 已验证环境与结果

以下是该修复在实际 Android 16 arm64 设备上的回归结果：

| 项目 | 结果 |
| --- | --- |
| Frida 服务端版本 | 17.16.4 |
| 目标架构 | Android arm64（64 位 ELF） |
| 服务端正式名称 | `fs64d_17910_exec` |
| 启动环境 | `FRIDA_DISABLE_ANDROID_SYSTEM_AGENTS=1` |
| 注入流程 | `spawn → attach → resume` |
| 进程状态 | `S (sleeping)`，不再是 `ptrace_stop` |
| `TracerPid` | `0` |
| 启动 ANR | 本次回归未发现 |

该次验证使用的构建产物为 arm64-only，因此只支持 64 位应用进程；它**不包含**对 32 位应用的兼容注入支持。

## 构建

### 安装预编译包

如果不需要本仓库的补丁，官方预编译包通常是最简便的选择：

```powershell
pip install frida-tools
pip install frida
npm install frida
```

### 构建本仓库

构建前需要准备与 Frida 17.16.4 匹配的构建依赖、Android NDK 和 Android arm64 工具链。基础构建入口为：

```powershell
.\make.bat
```

或在类 Unix 环境中：

```sh
make
```

若只需要当前设备使用的精简服务端，可在 Frida 的构建配置中禁用 compat 组件；生成的产物会是 arm64-only。若要覆盖 32 位应用，请保留并完成相应的兼容组件构建。

### Docker 与 CI 复用

当前机器上的 Docker 镜像仅用于保证本地工具链一致。只修改 Frida Core 逻辑时，可以直接复用现有镜像做增量构建；无需每次重新构建或发布 Docker 镜像。

当需要在另一台机器或 CI 中复用相同的构建环境时，应同时维护以下两类产物：

1. **环境定义**：将 Dockerfile、构建脚本及基础镜像、Android NDK、Node.js、Python、Meson/Ninja 等版本提交到仓库。
2. **可拉取镜像**：将镜像推送到容器仓库，供 CI 和其他机器直接拉取。

建议为共享镜像使用固定、可追溯的标签：

```text
ghcr.io/2802615124/frida-17164-build-env:17.16.4-node20
ghcr.io/2802615124/frida-17164-build-env:17.16.4-node20-<git-sha>
```

`latest` 可以作为便捷标签，但不可作为可复现构建的唯一依据；CI 应固定使用版本标签或镜像 digest。

需要重建并发布镜像的情形：

- Dockerfile、基础系统镜像或构建依赖版本发生变化；
- Android NDK、Node.js、Python、Meson/Ninja 等工具链发生变化；
- 需要在新机器或 CI 中首次复用该环境。


仅修改 Frida 源码时，无需重建镜像：拉取或复用固定版本的构建镜像后，重新编译受影响的 Android arm64 服务端并完成设备回归即可。Docker 镜像保存的是工具链；`frida-server` 二进制应作为独立构建产物或 Release 附件保存。
## 部署与回退

下面示例假定设备通过 ADB 可访问，且服务端安装目录为 `/data/adb/ksu/bin`。请按自己的设备路径调整。

先验证新二进制，不要立即覆盖正在工作的服务端：

```sh
adb push frida-server-17.16.4-android-arm64 /data/local/tmp/frida-server-test
adb shell chmod 755 /data/local/tmp/frida-server-test
adb shell /data/local/tmp/frida-server-test --version
```

确认版本输出为 `17.16.4` 后，保留旧文件备份再替换：

```sh
adb shell su -c 'cp /data/adb/ksu/bin/fs64d_17910_exec \
  /data/adb/ksu/bin/fs64d_17910_exec.backup'
adb push frida-server-17.16.4-android-arm64 /data/local/tmp/fs64d_17910_exec
adb shell su -c 'install -m 755 /data/local/tmp/fs64d_17910_exec \
  /data/adb/ksu/bin/fs64d_17910_exec'
```

按设备原有的服务管理方式重启服务端，并继续使用：

```sh
FRIDA_DISABLE_ANDROID_SYSTEM_AGENTS=1
```

如果服务端无法启动，停止新进程后将 `.backup` 文件恢复为正式名称即可回退。

## 回归测试清单

在替换服务端后，至少完成以下检查：

1. `frida-ps -U` 能列出目标设备的进程。
2. 对测试应用执行 `spawn → attach → resume`。
3. 等待至少 20 秒，确认目标进程未退出且没有新的启动 ANR。
4. 检查 `/proc/<pid>/status`：`TracerPid` 应为 `0`，进程不应卡在 `ptrace_stop`。
5. 用 `dumpsys window` 或 `dumpsys activity` 确认测试应用已处于预期前台 Activity。

## 常用 CLI 工具

Frida CLI 包括 `frida`、`frida-ls-devices`、`frida-ps`、`frida-kill`、`frida-trace` 与 `frida-discover` 等。若缺少 CLI 运行依赖，可安装：

```powershell
pip install colorama prompt-toolkit pygments websockets
```

## 参考

- 官方文档：[frida.re/docs/home](https://frida.re/docs/home/)
- 官方发行页：[github.com/frida/frida/releases](https://github.com/frida/frida/releases)
