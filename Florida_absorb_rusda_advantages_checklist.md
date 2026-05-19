# Florida 吸收 rusda 优点实施清单

## 1. 目标

在保持 Florida 现有优势的前提下，吸收 rusda 17.6.2 的以下长处：

1. 统一的二进制后处理链路
2. 更系统的源码级字符串/线程名混淆
3. 更完整的构建后验收工具
4. 更清晰的本地构建脚本

同时保留 Florida 现有优势：

1. 跟进新版 Frida 的能力
2. agent 文件名随机化
3. 线程名随机化
4. 当前 CI 自动发布流程

---

## 2. 实施原则

### 必保留

- 保留 `D:\code\saomiao\faka\Florida\.github\workflows\build.yml` 当前自动构建能力
- 保留 `src/linux/linux-host-session.vala` 中 UUID 随机 agent 命名思路
- 保留 `src/anti-anti-frida.py` 中随机线程名替换思路
- 不把 Florida 全量改造成固定品牌命名的 `rusda-*`

### 建议吸收

- 吸收 rusda 的 `tools/post-process.py -> topatch.py` 自动 patch 思路
- 吸收 rusda 的 `lib/base/obfuscate.vala` 通用解码模块思路
- 吸收 rusda 的 `tools/verify-patch.py` / `scan-frida-signatures.py` 验收思路

### 不建议直接照搬

- 不建议把所有内部目标名强行改为 `rusda-*`
- 不建议固定线程名为 `russellloop/rmain/rubus`
- 不建议固定 `prgname`/helper 名称为 rusda 品牌

---

## 3. 分阶段实施

## Phase 1：补齐验收工具

### 目标

先把“构建后是否 patch 成功”这件事标准化，避免产物看起来能用但部分特征未处理。

### 待做项

- [ ] 新增 `tools/verify-patch.py`
- [ ] 新增 `tools/scan-frida-signatures.py`
- [ ] 在脚本中适配 Florida 当前产物命名：
  - `florida-server-*`
  - `florida-inject-*`
  - `florida-gadget-*`
  - `florida-gumjs-*`（如需要单独检查）
- [ ] 规则中区分：
  - 必须不存在的原始特征串
  - 必须存在的替换结果
  - 允许保留但需标记的兼容性字串
- [ ] 增加 `--strict` 模式
- [ ] 在 CI 中增加“构建后验收”步骤

### 重点检查项

- 不应出现：
  - `FridaScriptEngine`
  - `GLib-GIO`
  - `GDBusProxy`
  - `GumScript`
  - `gum-js-loop`
  - `gmain`
  - `gdbus`
- 视策略决定是否严格检查：
  - `frida:rpc`
  - `re.frida.*`
  - `frida-helper`
  - `frida-gadget-tcp`

### 建议落点

- 新文件：
  - `D:\code\saomiao\faka\Florida\tools\verify-patch.py`
  - `D:\code\saomiao\faka\Florida\tools\scan-frida-signatures.py`

### 验收标准

- 本地能对 release-assets 目录跑检查
- CI 构建完成后自动检查
- 失败时输出命中字符串、文件名、偏移或 strings 片段

---

## Phase 2：统一二进制后处理入口

### 目标

把 Florida 现在偏“agent embed 时触发”的 patch 方式，升级成“最终 ELF / so / executable 都能统一处理”。

### 当前问题

- 现在 Florida 主要依赖 `src/embed-agent.py` 调 `src/anti-anti-frida.py`
- 覆盖面偏向 agent
- server / inject / gadget / 其他最终产物的处理链路不够统一

### 待做项

- [ ] 将 `src/anti-anti-frida.py` 重构为可复用主 patch 脚本
- [ ] 新增统一入口脚本，例如：
  - `tools/post-process-florida.py`
- [ ] 在构建后处理阶段自动调用主 patch 脚本，而不是只在 embed-agent 阶段调用
- [ ] 覆盖以下产物：
  - server
  - inject
  - gadget
  - agent
  - 必要时覆盖 gumjs 相关静态库或共享库

### 建议实现方式

参考 rusda 的思路，但保持 Florida 自己的随机化逻辑：

1. 保留 `anti-anti-frida.py` 作为核心 patch 逻辑
2. 新增构建后统一调度器
3. 调度器按 `kind` / `host_os` / `artifact path` 决定是否执行 patch
4. 所有 patch 输出统一日志格式，便于 CI grep

### 建议文件

- 新增：
  - `D:\code\saomiao\faka\Florida\tools\post-process-florida.py`
- 可能要改：
  - Frida 对应版本中的 `tools/post-process.py`
  - `src/embed-agent.py`

### 验收标准

- 构建出的 server/inject/gadget/agent 都经过统一 patch
- 日志中能看到每个产物已处理
- `verify-patch.py` 全通过

---

## Phase 3：引入源码级通用混淆模块

### 目标

不只改二进制；对源码中容易形成静态字符串特征的点，统一改为运行时解码。

### 待做项

- [ ] 新增 `lib/base/obfuscate.vala`
- [ ] 在 `lib/base/meson.build` 中引入该文件
- [ ] 提供至少一种轻量可维护的解码方式：
  - XOR + hex
  - 或 Base64
- [ ] 把现有 `lib/base/rpc.vala` 的字面量处理统一到该模块

### 第一批建议迁移目标

- [ ] `lib/base/rpc.vala`
- [ ] `lib/base/p2p.vala`
- [ ] `lib/base/xpc.vala`
- [ ] `lib/gadget/gadget.vala`
- [ ] `lib/agent/agent.vala`

### 迁移原则

- 优先迁移“特征明显、命中率高、兼容性风险低”的字面量
- 不要一次性全量改所有字面量
- 每改一个文件，单独验证能否通过构建和运行

### 推荐优先混淆的内容

- 线程名
- 错误 quark 名
- 内部 service / tag / label 字符串
- 明显的 `frida-*` 前缀字面量

### 不建议先动的内容

- 直接影响协议兼容的公开字面量
- 可能被上层客户端强依赖的路径 / 类名 / bundle id

### 验收标准

- 编译通过
- 不影响现有 attach / inject / gadget 加载
- strings 结果中显著减少直白特征串

---

## Phase 4：扩大线程名 / 运行时特征处理覆盖面

### 目标

把当前只在二进制 patch 阶段随机替换的线程名处理，扩展到更多源码级创建线程的位置。

### 待做项

- [ ] 梳理所有 `new Thread<...>(...)`
- [ ] 梳理所有 `Environment.set_thread_name(...)`
- [ ] 梳理所有 `g_thread_new(...)`
- [ ] 梳理所有可能暴露 `frida-` 字样的线程/loop/service 名

### 建议扫描命令

```powershell
rg -n "Thread<|set_thread_name|g_thread_new|frida-" D:\code\saomiao\faka\Florida
```

### 优先级

1. gadget
2. agent
3. p2p / rpc / xpc
4. server 主循环

### 方案建议

- 源码层能改的优先源码改
- 必须保留兼容性的，再交给二进制 patch
- 保持 Florida 的“随机化优先”，不要固定成单一命名

### 验收标准

- strings / 运行时线程名中显著减少 `frida-*`
- 不影响程序启动与功能

---

## Phase 5：补一套本地串行构建脚本

### 目标

保留现有 GitHub Actions 的同时，提供一套适合本地复现和排错的构建脚本。

### 待做项

- [ ] 新增本地构建脚本：
  - `tools/build-android-all.sh`
  - 或 Windows 环境下对应的 `.ps1`
- [ ] 支持四架构串行构建：
  - `android-arm`
  - `android-arm64`
  - `android-x86`
  - `android-x86_64`
- [ ] 构建结束后自动：
  - 打包
  - 跑 patch 验证
  - 生成汇总日志

### 建议输出

- `release-assets/`
- `logs/build-android-*.log`
- `logs/verify-patch.log`

### 验收标准

- 本地单命令可完成：
  - 构建
  - patch
  - 打包
  - 校验

---

## 4. 具体落地顺序

建议严格按下面顺序做，避免一次改太大：

### 第 1 周：先做验收，不动核心逻辑

- [ ] 落 `verify-patch.py`
- [ ] 落 `scan-frida-signatures.py`
- [ ] CI 接入检查

### 第 2 周：统一 patch 入口

- [ ] 把 `anti-anti-frida.py` 改成可复用核心逻辑
- [ ] 新增 `post-process-florida.py`
- [ ] 让 server/inject/gadget/agent 都走统一处理

### 第 3 周：引入 `obfuscate.vala`

- [ ] 先改 `rpc.vala`
- [ ] 再改 `gadget.vala`
- [ ] 再改 `p2p/xpc/agent`

### 第 4 周：扫尾

- [ ] 扩大线程名覆盖
- [ ] 增加本地构建脚本
- [ ] 补 README / 使用说明

---

## 5. 风险点

### 高风险

| 项目 | 风险 |
|---|---|
| 改 bundle id / 目标名 / 安装路径 | 可能影响上层工具、脚本、加载逻辑 |
| 改公开协议字面量 | 可能破坏客户端兼容 |
| 全量替换 `frida-*` | 可能误伤功能判断或内部匹配 |

### 中风险

| 项目 | 风险 |
|---|---|
| 在更多产物上自动执行 patch | 可能出现某些 ELF/平台格式不兼容 |
| 源码层统一解码模块 | 若实现不当，可能引入运行时错误 |

### 低风险

| 项目 | 风险 |
|---|---|
| 增加验收脚本 | 基本无运行时风险 |
| 增加本地构建脚本 | 基本无运行时风险 |

---

## 6. 推荐最终形态

### Florida 最佳吸收方案

保留：

- 新版 Frida 跟进能力
- UUID agent 命名
- 随机线程名 patch
- 现有 CI workflow

增加：

- `tools/verify-patch.py`
- `tools/scan-frida-signatures.py`
- `tools/post-process-florida.py`
- `lib/base/obfuscate.vala`
- 本地串行构建脚本

改造：

- 让 `anti-anti-frida.py` 从“单点脚本”升级为“统一后处理核心模块”
- 让源码层字符串混淆从单点 patch 升级为可复用框架

不做：

- 不全量改成 `rusda-*`
- 不固定线程名
- 不直接照搬 rusda 的品牌替换策略

---

## 7. 最小可行版本（MVP）

如果只做最有价值、最不容易出事故的一版，建议只做以下 4 项：

- [ ] 增加 `tools/verify-patch.py`
- [ ] 增加 `tools/scan-frida-signatures.py`
- [ ] 增加统一后处理入口 `tools/post-process-florida.py`
- [ ] 增加 `lib/base/obfuscate.vala`，先只迁移 `rpc.vala`

这样能在低风险下拿到 rusda 最有价值的三点：

1. 自动验收
2. 统一 patch 入口
3. 源码级混淆基础设施

---

## 8. 建议下一步

建议直接按下面顺序开始：

1. 先补 `verify-patch.py`
2. 再补 `scan-frida-signatures.py`
3. 然后重构 `anti-anti-frida.py` 为统一后处理核心
4. 最后引入 `obfuscate.vala`

如果需要，我下一步可以继续直接输出：

1. **可执行的任务拆分表**
2. **逐文件修改建议**
3. **第一版 `verify-patch.py` 草案**

