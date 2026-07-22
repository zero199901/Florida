# 魔改 Frida Codex Skill 仓库安装

仓库路径：`codex-skills/frida/`

## 一键安装/更新

```bash
rm -rf /tmp/Florida-codex-16.7.19
git clone -b codex-16.7.19 git@github.com:zero199901/Florida.git /tmp/Florida-codex-16.7.19
mkdir -p "$HOME/.codex/skills"
rsync -a --delete /tmp/Florida-codex-16.7.19/codex-skills/frida/ "$HOME/.codex/skills/frida/"
```

## 校验

```bash
grep -n 'REMOTE_BIN=.*app_process64' "$HOME/.codex/skills/frida/scripts/common_16719.sh"
bash -n \
  "$HOME/.codex/skills/frida/scripts/common_16719.sh" \
  "$HOME/.codex/skills/frida/scripts/deploy_run_16719_phone.sh" \
  "$HOME/.codex/skills/frida/scripts/check_16719_phone.sh" \
  "$HOME/.codex/skills/frida/scripts/test_16719_phone.sh"
node --check "$HOME/.codex/skills/frida/scripts/chunqiu_native_check_monitor.js"
```

## 默认运行效果

安装后的 skill 默认使用系统风格进程名：

```text
REMOTE_BIN=/data/local/tmp/app_process64
REMOTE_LOG=/data/local/tmp/app_process64.log
REMOTE_NAME=app_process64
FRIDA_PORT=28191
FRIDA_CLUSTER_PORT=28192
```

部署与检测：

```bash
SERIAL=5c8093e4 "$HOME/.codex/skills/frida/scripts/deploy_run_16719_phone.sh"
SERIAL=5c8093e4 "$HOME/.codex/skills/frida/scripts/check_16719_phone.sh"
```
