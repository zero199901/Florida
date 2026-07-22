# 魔改 Frida Codex Skill 安装命令

这个目录是 `frida` Codex skill 的仓库版副本，内容与本机当前调试使用的 `/Users/tbs/.codex/skills/frida` 同步。

## 从 Git 仓库安装或更新

```bash
# 1) 拉取包含 skill 的 Florida 分支
rm -rf /tmp/Florida-codex-16.7.19
git clone -b codex-16.7.19 git@github.com:zero199901/Florida.git /tmp/Florida-codex-16.7.19

# 2) 安装到 Codex skill 目录
mkdir -p "$HOME/.codex/skills"
rsync -a --delete /tmp/Florida-codex-16.7.19/codex-skills/frida/ "$HOME/.codex/skills/frida/"

# 3) 校验脚本语法与默认伪装名
grep -n 'REMOTE_BIN=.*app_process64' "$HOME/.codex/skills/frida/scripts/common_16719.sh"
bash -n \
  "$HOME/.codex/skills/frida/scripts/common_16719.sh" \
  "$HOME/.codex/skills/frida/scripts/deploy_run_16719_phone.sh" \
  "$HOME/.codex/skills/frida/scripts/check_16719_phone.sh" \
  "$HOME/.codex/skills/frida/scripts/test_16719_phone.sh"
node --check "$HOME/.codex/skills/frida/scripts/chunqiu_native_check_monitor.js"
```

## 从本机现有仓库安装或更新

```bash
TOP=/Users/tbs/Documents/Codex/2026-07-21/frida-16.7.19-florida
mkdir -p "$HOME/.codex/skills"
rsync -a --delete "$TOP/codex-skills/frida/" "$HOME/.codex/skills/frida/"
```

## 部署当前魔改 frida-server

默认会推送到手机 `/data/local/tmp/app_process64`，日志为 `/data/local/tmp/app_process64.log`，进程名与 `cmdline` 显示为 `app_process64`。

```bash
SERIAL=5c8093e4 "$HOME/.codex/skills/frida/scripts/deploy_run_16719_phone.sh"
SERIAL=5c8093e4 "$HOME/.codex/skills/frida/scripts/check_16719_phone.sh"
```

## 春秋 Native Check 调试例子

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
  --runtime=qjs \
  --timeout 20
```
