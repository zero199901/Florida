# Florida vs rusda 17.6.2 对比

## 1. 对比范围

- 本地项目：`Florida`
  - 仓库路径：`D:\code\saomiao\faka\Florida`
  - 当前主干构建版本：`17.9.10`
  - 证据：`D:\code\saomiao\faka\Florida\.github\workflows\build.yml`
- 对比对象：`taisuii/rusda`
  - 对比版本：`17.6.2`
  - 发布时间：`2026-04-04 14:35:24 UTC`
  - 参考：
    - <https://github.com/taisuii/rusda/releases/tag/17.6.2>
    - <https://github.com/taisuii/rusda/tree/17.6.2/17.6.2>

> 说明：两边 Frida 基线不一致。Florida 当前仓库主干跟到 `17.9.10`，rusda 发布包固定在 `17.6.2`。因此这里做的是“修改思路 / 覆盖范围 / 文件级改动”的对比，不是逐行 patch 可直接互套。

---

## 2. 总结

| 维度 | Florida | rusda 17.6.2 | 结论 |
|---|---|---|---|
| Frida 基线 | `17.9.10` | `17.6.2` | 基线不同 |
| 补丁组织 | 多个小 patch，按目录 `git am` | 聚合交付 patch | Florida 更利于持续跟 upstream |
| 外部产物命名 | release 文件名改为 `florida-*` | 内外统一改为 `rusda-*` | rusda 改名更彻底 |
| 内部目标名 / 安装路径 | 多数保持官方命名 | `server/inject/gadget/agent/libdir` 全链路改名 | rusda 更彻底 |
| RPC 字面量隐藏 | Base64 双重解码 | XOR 运行时解码 | 两边都隐藏静态特征 |
| agent 入口 | `frida_agent_main -> main` | 同样 | 一致 |
| agent 文件名 | Linux 下随机 UUID 前缀 | 固定 `rusda-agent-*` | Florida 随机化更强 |
| 二进制后处理 | `embed-agent.py` 调 `anti-anti-frida.py` | `post-process.py` 调 `topatch.py` | rusda 覆盖产物更全 |
| 二进制字符串 patch | 符号替换 + `.rodata` 反转 + sed 替换线程名 | 同样，但固定替换为 `rusda/russell*` | 核心策略一致 |
| 线程名混淆 | 随机替换 `gum-js-loop/gmain/gdbus` | 固定 `russellloop/rmain/rubus`，并在更多源码点混淆 | rusda 覆盖更广 |
| `prgname` | `ggbond` | `russell` | 都修改了进程名 |
| memfd 名称 | `jit-cache` | `jit-cache` | 一致 |
| 协议异常容忍 | 放宽 `Unexpected command` | 同样放宽 | 一致 |
| Android helper 标识 | 未做全链路品牌替换 | 改成 `re.rusda.helper` / `--nice-name=re.rusda.helper` | rusda 更彻底 |
| 源码级混淆框架 | 无通用模块 | 新增 `obfuscate.vala` | rusda 更系统 |
| 自检工具 | 无独立校验脚本 | `verify-patch.py` / `scan-frida-signatures.py` / `ensure-submodules.py` | rusda 工具链更完整 |
| CI / 自动发布 | GitHub Actions 自动拉上游、编译、发 release | 以本地脚本串行构建为主 | Florida 自动化更强 |

### 一句话判断

- **Florida**：偏“少改官方结构 + 随机化 + 便于持续跟新版 Frida”
- **rusda 17.6.2**：偏“全链路品牌替换 + 固定特征 + 工具化交付”

---

## 3. 文件级总览

### 3.1 两边都修改到的文件

| 文件 | Florida | rusda 17.6.2 | 备注 |
|---|---|---|---|
| `gum/gum.c` | `g_set_prgname("ggbond")` | `g_set_prgname("russell")` | 都改进程名 |
| `lib/base/linux.vala` | `memfd_create(..., "jit-cache", ...)` | 同样 | 一致 |
| `lib/base/rpc.vala` | Base64 隐藏 `frida:rpc` | XOR 隐藏 `frida:rpc` | 运行时协议仍兼容 |
| `src/agent-container.vala` | `frida_agent_main -> main` | 同样 | 一致 |
| `src/darwin/darwin-host-session.vala` | 注入入口改 `main` | 同样 | 一致 |
| `src/droidy/droidy-client.vala` | 放宽 `Unexpected command` | 同样 | 一致 |
| `src/embed-agent.py` | 显式调用 `anti-anti-frida.py` | 注释掉二次 patch，交给 `post-process.py` | patch 触发点不同 |
| `src/freebsd/freebsd-host-session.vala` | 注入入口改 `main` | 同样 | 一致 |
| `src/frida-glue.c` | `prgname=ggbond` | `prgname=russell`，主线程名也改 | rusda 多改一层 |
| `src/linux/linux-host-session.vala` | agent 文件名随机前缀；入口改 `main` | 固定 `rusda-agent-*`；入口改 `main`；helper nice-name 改名 | rusda 改得更深 |
| `src/qnx/qnx-host-session.vala` | 注入入口改 `main` | 同样 | 一致 |
| `src/windows/windows-host-session.vala` | 注入入口改 `main` | 同样 | 一致 |

### 3.2 Florida 独有修改

| 文件 | 修改内容 | 说明 |
|---|---|---|
| `src/anti-anti-frida.py` | LIEF 改符号名；反转 `.rodata` 字符串；随机替换线程名 | Florida 的核心后处理脚本 |
| `tests/test-agent.vala` | `frida_agent_main -> main` | 为入口变更补测试 |
| `tests/test-injector.vala` | `frida_agent_main -> main` | 为入口变更补测试 |

### 3.3 rusda 17.6.2 独有修改

| 文件 | 修改内容 | 说明 |
|---|---|---|
| `.gitignore` | 增加构建产物忽略 | 构建辅助 |
| `compat/build.py` | helper/agent/gadget/server 全部改成 `rusda-*` | 品牌替换核心之一 |
| `inject/meson.build` | 输出名改 `rusda-inject`，bundle id 改 `re.rusda.Inject` | 产物改名 |
| `lib/agent/agent.vala` | 多个线程名改为运行时解码字符串 | 扩大混淆面 |
| `lib/base/meson.build` | 引入 `obfuscate.vala` | 支撑运行时解码 |
| `lib/base/obfuscate.vala` | 新增 XOR 解码模块 | 通用混淆基础设施 |
| `lib/base/p2p.vala` | 线程名运行时解码 | 减少静态特征 |
| `lib/base/xpc.vala` | `frida-error-quark` 改为运行时解码 | 减少静态特征 |
| `lib/gadget/gadget.vala` | gadget 线程名运行时解码 | 减少静态特征 |
| `meson.build` | `helper/agent/gadget/libdir` 改为 `rusda` | 全链路改名 |
| `releng` | submodule 指针变化 | 构建依赖同步 |
| `server/meson.build` | 输出名改 `rusda-server`，bundle id 改 `re.rusda.Server` | 产物改名 |
| `server/server.vala` | 默认目录改 `re.rusda.server` | 品牌替换 |
| `src/droidy/droidy-host-session.vala` | `re.frida.helper -> re.rusda.helper` | Android helper 改名 |
| `src/topatch.py` | 统一做 LIEF + strings patch | rusda 的核心后处理脚本 |
| `tests/core/mapper.c` | `frida_agent_main -> main` | 补测试 |
| `tools/build-android-all.sh` | 四架构串行编译 + 打包 `.xz` | 构建主脚本 |
| `tools/post-process.py` | 对 shared-library / executable 自动调用 `topatch.py` | 统一 patch 入口 |
| `tools/verify-patch.py` | 校验产物是否 patch 成功 | 自检工具 |
| `tools/scan-frida-signatures.py` | 扫描特征串 | 自检工具 |
| `tools/ensure-submodules.py` | 辅助子模块处理 | 构建辅助 |

---

## 4. 按功能点逐项对比

### 4.1 RPC 特征隐藏

| 项目 | Florida | rusda 17.6.2 |
|---|---|---|
| 文件 | `lib/base/rpc.vala` | `lib/base/rpc.vala` |
| 方式 | 双层 Base64 解码得到 `frida:rpc` | XOR + hex 运行时解码得到 `frida:rpc` |
| 效果 | 避免静态字符串直接出现在二进制 | 同样 |
| 兼容性 | 保持原协议 | 保持原协议 |

结论：这块两者本质相同，都是“隐藏静态字面量，不改协议”。

### 4.2 agent 入口点去特征

| 项目 | Florida | rusda 17.6.2 |
|---|---|---|
| 入口符号 | `frida_agent_main -> main` | `frida_agent_main -> main` |
| 涉及平台 | container / darwin / freebsd / linux / qnx / windows | 同样 |
| 测试覆盖 | `tests/test-agent.vala`、`tests/test-injector.vala` | `tests/core/mapper.c` |

结论：目标一致，测试补法不同。

### 4.3 agent 文件命名策略

| 项目 | Florida | rusda 17.6.2 |
|---|---|---|
| Linux 临时 agent 名 | UUID 随机前缀 | 固定 `rusda-agent-*` |
| Android emulated arm/arm64 资源名 | 随机前缀对应生成 | 固定 `rusda-agent-arm*.so` |
| 风格 | 随机化、每次构建不稳定 | 品牌化、一致性强 |

结论：Florida 更偏规避基于固定文件名的检测，rusda 更偏统一品牌命名。

### 4.4 二进制后处理

| 项目 | Florida | rusda 17.6.2 |
|---|---|---|
| 核心脚本 | `src/anti-anti-frida.py` | `src/topatch.py` |
| 触发位置 | `src/embed-agent.py` | `tools/post-process.py` |
| 覆盖对象 | 主要围绕 agent embed 阶段 | shared-library / executable 均可自动处理 |
| 字符串 patch | 有 | 有 |
| 符号 patch | 有 | 有 |
| 日志输出 | 有 | 有 |

结论：rusda 的 patch 触发链路更完整，Florida 更轻量。

### 4.5 字符串 / 线程 / 进程名特征

| 维度 | Florida | rusda 17.6.2 |
|---|---|---|
| `.rodata` 反转字符串 | `FridaScriptEngine` / `GLib-GIO` / `GDBusProxy` / `GumScript` | 同样 |
| 线程名：`gum-js-loop` | 随机 11 字符 | `russellloop` |
| 线程名：`gmain` | 随机 5 字符 | `rmain` |
| 线程名：`gdbus` | 随机 5 字符 | `rubus` |
| `prgname` | `ggbond` | `russell` |
| 源码层额外线程混淆 | 少 | 多，覆盖 `agent/p2p/gadget/xpc` |

结论：Florida 偏随机；rusda 偏固定且覆盖更深。

### 4.6 Android helper / 安装路径 / 品牌替换

| 项目 | Florida | rusda 17.6.2 |
|---|---|---|
| helper 名称 | 基本保持官方 | 改为 `rusda-helper` |
| server/inject/gadget 名 | 外部 release 文件名改 `florida-*` | 内部构建产物也改 `rusda-*` |
| 默认目录 / bundle id | 基本保持官方 | `re.rusda.server` / `re.rusda.Inject` / `re.rusda.Server` |
| asset path | 官方 `lib/frida/...` | `lib/rusda/...` |

结论：rusda 是彻底品牌替换；Florida 主要改发布包名。

### 4.7 memfd / 协议兼容分支

| 项目 | Florida | rusda 17.6.2 | 结论 |
|---|---|---|---|
| `memfd_create` 名称 | `jit-cache` | `jit-cache` | 一致 |
| `Unexpected command` | 不抛错，改 `break` | 同样 | 一致 |

---

## 5. 构建与交付方式对比

| 项目 | Florida | rusda 17.6.2 |
|---|---|---|
| 构建入口 | GitHub Actions | 本地 shell 脚本 |
| 上游拉取 | workflow 中 `git clone frida` + `git checkout $FRIDA_VERSION` | README/交付说明要求手动 checkout 固定 commit |
| patch 应用 | `git am` 每个 patch 文件 | `git apply` 聚合 patch |
| Android 构建 | workflow 循环 `android-arm/arm64/x86/x86_64` | `tools/build-android-all.sh` 串行四架构 |
| 打包格式 | `.gz` | `.xz` |
| 额外产物 | 还打包 `gumjs` 静态库 | 主要是 `server/inject/gadget` |
| 自检 | 无专门 verify 脚本 | `verify-patch.py` |

结论：

- **Florida 更适合无人值守持续产出 release**
- **rusda 更适合固定版本、固定流程、先 patch 再验收**

---

## 6. 关键差异清单

### Florida 相比 rusda 的特点

1. 更偏向持续跟 Frida 新版。
2. patch 拆分细，便于单点维护。
3. Linux agent 文件名用 UUID，随机化更强。
4. 线程名替换也是随机值，不是固定品牌字串。
5. 侵入面相对小，对官方构建骨架改动少。

### rusda 17.6.2 相比 Florida 的特点

1. 全链路品牌替换更彻底。
2. 通过 `obfuscate.vala` 建立了源码级通用混淆基础设施。
3. `post-process.py -> topatch.py` 让 patch 自动作用到更多最终产物。
4. 自带 `verify-patch.py` 等验收工具，交付更完整。
5. 构建脚本、补丁说明、扫描脚本都更齐全。

---

## 7. 结论

如果目标是：

- **长期跟随 Frida 上游新版本**：Florida 路线更合适。
- **在 17.6.2 上做一套彻底改名、方便交付与验收的版本**：rusda 更完整。

如果要把两边优点合并，最值得把 rusda 的以下内容迁回 Florida：

1. `tools/post-process.py` 统一调用 patch 脚本的机制
2. `lib/base/obfuscate.vala` 这类源码级运行时解码框架
3. `tools/verify-patch.py` / `scan-frida-signatures.py` 这类验收工具

同时保留 Florida 的：

1. 新版本 Frida 适配能力
2. agent 文件名随机化
3. 线程名随机化

---

## 8. 本次比对使用的本地证据

- Florida:
  - `D:\code\saomiao\faka\Florida\.github\workflows\build.yml`
  - `D:\code\saomiao\faka\Florida\patches\frida-core\0001-Florida-string_frida_rpc.patch`
  - `D:\code\saomiao\faka\Florida\patches\frida-core\0002-Florida-frida_agent_so.patch`
  - `D:\code\saomiao\faka\Florida\patches\frida-core\0003-Florida-symbol_frida_agent_main.patch`
  - `D:\code\saomiao\faka\Florida\patches\frida-core\0004-Florida-thread_gum_js_loop.patch`
  - `D:\code\saomiao\faka\Florida\patches\frida-core\0005-Florida-thread_gmain.patch`
  - `D:\code\saomiao\faka\Florida\patches\frida-core\0006-Florida-protocol_unexpected_command.patch`
  - `D:\code\saomiao\faka\Florida\patches\frida-core\0007-Florida-update-python-script.patch`
  - `D:\code\saomiao\faka\Florida\patches\frida-core\0008-Florida-pool-frida.patch`
  - `D:\code\saomiao\faka\Florida\patches\frida-core\0009-Florida-memfd-name-jit-cache.patch`
  - `D:\code\saomiao\faka\Florida\patches\frida-core\0010-exec-anti-anti-frida.py.patch`
  - `D:\code\saomiao\faka\Florida\patches\frida-gum\0001-Florida-pool-frida.patch`
- rusda:
  - `D:\code\saomiao\faka\_cmp\rusda\17.6.2\patches\deliver\frida-core.patch`
  - `D:\code\saomiao\faka\_cmp\rusda\17.6.2\patches\deliver\frida-gum.patch`
  - `D:\code\saomiao\faka\_cmp\rusda\17.6.2\patches\deliver\superrepo.patch`
  - `D:\code\saomiao\faka\_cmp\rusda\17.6.2\tools\verify-patch.py`

