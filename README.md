# Florida / Frida 16.7.19 魔改版

这是 `zero199901/Florida` 仓库中的 `codex-16.7.19` 分支，用于本地 Android 16 Frida/Florida 测试工作流。

本分支已经集成以下内容：

- Frida 16.7.19 Android arm64 server 构建流程
- 默认控制端口改为 `28191`
- 默认 cluster 端口改为 `28192`
- Android 端 server 默认部署为 `/data/local/tmp/app_process64`
- server 进程名默认显示为 `app_process64`
- embedded Android agent 资源名调整为 `libbase-*.so`
- Android 16 system agents 稳定性 gating
- Android 16 Java bridge 默认 gated
- Android 16 Java bridge 按进程开关控制
- 春秋 Native Check native-only 调试例子
- Codex `frida` skill 安装包：`codex-skills/frida/`

## 当前分支

```text
Top branch: codex-16.7.19
Core branch: frida-core-codex-16.7.19
Gum branch: frida-gum-codex-16.7.19
Release: v16.7.19-codex
```

## 主要改动

### 1. 端口改名

默认 Frida 控制端口：

```text
28191
```

默认 cluster 端口：

```text
28192
```

客户端连接方式：

```bash
frida-ps -H 127.0.0.1:28191
frida -H 127.0.0.1:28191 -p <PID>
```

### 2. Android server 进程名

默认部署路径：

```text
/data/local/tmp/app_process64
```

运行后 `/proc/<pid>/cmdline`、`ps`、`comm` 中显示为：

```text
app_process64
```

### 3. Android 16 稳定性配置

Android 16 上默认保持 native attach、模块枚举、进程枚举、`Interceptor` 等能力。

以下路径改为显式开关：

```text
Android system agents
Android Java bridge
```

相关说明见：

```text
docs/android-16-stability-profile.md
```

### 4. Java bridge 按进程控制

Android API 36+ 下支持按进程控制 Java bridge。

Native Check 默认走 native-only：

```text
com.chunqiunativecheck
```

稳定模式命令：

```bash
adb -s 5c8093e4 shell su -c 'unlink /data/local/tmp/frida-enable-java-bridge 2>/dev/null; unlink /data/local/tmp/.frida-enable-java-bridge 2>/dev/null; mkdir -p /data/local/tmp/frida-java-bridge-deny.d; touch /data/local/tmp/frida-java-bridge-deny.d/com.chunqiunativecheck; true'
```

给其它 app 单独开启 Java bridge：

```bash
PKG=com.example.target
adb -s 5c8093e4 shell su -c "mkdir -p /data/local/tmp/frida-java-bridge-allow.d; touch /data/local/tmp/frida-java-bridge-allow.d/$PKG"
```

强制测试某个进程的 Java bridge：

```bash
PKG=com.chunqiunativecheck
adb -s 5c8093e4 shell su -c "mkdir -p /data/local/tmp/frida-java-bridge-force.d; touch /data/local/tmp/frida-java-bridge-force.d/$PKG"
```

## Release 下载

当前预编译 server：

```text
https://github.com/zero199901/Florida/releases/tag/v16.7.19-codex
```

文件：

```text
fs-16.7.19-codex
```

SHA256：

```text
8e36db3e050460c7dbd08c202f56ba2e52b4ecda4db033e2256435e027bf4652
```

## 构建

推荐使用 Android NDK r25c。

```bash
cd /Users/tbs/Documents/Codex/2026-07-21/frida-16.7.19-florida
./configure --host=android-arm64
./releng/meson/meson.py compile -C build frida-server -j 8
```

本机 skill 脚本构建：

```bash
/Users/tbs/.codex/skills/frida/scripts/build_16719_android_arm64.sh
```

构建产物：

```text
/tmp/fs-16.7.19-codex
```

## 部署到 USB 手机

默认设备序列号：

```text
5c8093e4
```

部署并启动：

```bash
SERIAL=5c8093e4 /Users/tbs/.codex/skills/frida/scripts/deploy_run_16719_phone.sh
```

检查运行状态：

```bash
SERIAL=5c8093e4 /Users/tbs/.codex/skills/frida/scripts/check_16719_phone.sh
```

预期结果：

```text
remote: /data/local/tmp/app_process64
listen: 127.0.0.1:28191
process: app_process64
Java.available: false on Android API 36 by default
native Interceptor: available
```

## 春秋 Native Check 调试

包名：

```text
com.chunqiunativecheck
```

启动并 attach：

```bash
SERIAL=5c8093e4
PKG=com.chunqiunativecheck
HOST=127.0.0.1:28191

adb -s "$SERIAL" shell am force-stop "$PKG"
adb -s "$SERIAL" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
sleep 2

PID=$(adb -s "$SERIAL" shell pidof "$PKG" | tr -d '\r' | awk '{print $1}')

$HOME/.local/bin/frida \
  -H "$HOST" \
  -p "$PID" \
  -l "$HOME/.codex/skills/frida/scripts/chunqiu_native_check_monitor.js" \
  -q \
  --runtime=qjs
```

已验证能力：

```text
frida-ps 正常
USB 28191 正常
app_process64 server 正常
native attach 正常
libchunqiunative.so hook 正常
runKeyAttestationFull direct hook 命中
retval=0x10 可抓取
```

## Codex frida skill 安装

仓库内 skill 路径：

```text
codex-skills/frida/
```

从 GitHub 安装或更新：

```bash
rm -rf /tmp/Florida-codex-skill
git clone -b main git@github.com:zero199901/Florida.git /tmp/Florida-codex-skill

mkdir -p "$HOME/.codex/skills"
rsync -a --delete /tmp/Florida-codex-skill/codex-skills/frida/ "$HOME/.codex/skills/frida/"
```

从 `codex-16.7.19` 分支安装：

```bash
rm -rf /tmp/Florida-codex-16.7.19
git clone -b codex-16.7.19 git@github.com:zero199901/Florida.git /tmp/Florida-codex-16.7.19

mkdir -p "$HOME/.codex/skills"
rsync -a --delete /tmp/Florida-codex-16.7.19/codex-skills/frida/ "$HOME/.codex/skills/frida/"
```

校验：

```bash
grep -n 'REMOTE_BIN=.*app_process64' "$HOME/.codex/skills/frida/scripts/common_16719.sh"

bash -n \
  "$HOME/.codex/skills/frida/scripts/common_16719.sh" \
  "$HOME/.codex/skills/frida/scripts/deploy_run_16719_phone.sh" \
  "$HOME/.codex/skills/frida/scripts/check_16719_phone.sh" \
  "$HOME/.codex/skills/frida/scripts/test_16719_phone.sh"

node --check "$HOME/.codex/skills/frida/scripts/chunqiu_native_check_monitor.js"
```

## 相关文档

```text
docs/android-16-stability-profile.md
docs/frida-skill-install.md
codex-skills/frida/INSTALL.md
codex-skills/frida/SKILL.md
codex-skills/frida/references/detection-map.md
codex-skills/frida/references/ports-and-filenames.md
```

## 上游 Frida

Frida 是面向开发、逆向和安全研究的动态插桩工具。上游项目地址：

```text
https://frida.re/
https://github.com/frida/frida
```
