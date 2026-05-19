# Florida 开发任务拆分 Checklist

> 目标：在不破坏 Florida 当前“跟新版 Frida + 随机化”的前提下，吸收 rusda 的三类优点：统一后处理、源码级混淆、产物验收。

---

## A. Phase 1：先补验收工具

## A1. 新增 `tools/verify-patch.py`

- [ ] 新建文件：`D:\code\saomiao\faka\Florida\tools\verify-patch.py`
- [ ] 支持扫描目录参数，默认扫描 `release-assets/`
- [ ] 支持识别以下文件：
  - [ ] `florida-server-*-android-*.gz`
  - [ ] `florida-inject-*-android-*.gz`
  - [ ] `florida-gadget-*-android-*.so.gz`
  - [ ] `florida-gumjs-*-android-*.a.gz`（先可选）
- [ ] 支持解压 `.gz` 后跑 `strings`
- [ ] 默认检查以下“坏特征串”：
  - [ ] `FridaScriptEngine`
  - [ ] `GLib-GIO`
  - [ ] `GDBusProxy`
  - [ ] `GumScript`
  - [ ] `gum-js-loop`
  - [ ] `gmain`
  - [ ] `gdbus`
- [ ] 默认检查以下“好特征结果”：
  - [ ] 已被反转后的 `.rodata` 字符串
  - [ ] 随机线程名替换结果至少命中一部分
- [ ] 增加 `--strict` 模式
- [ ] `--strict` 模式额外检查：
  - [ ] `frida:rpc`
  - [ ] `re.frida`
  - [ ] `frida-helper`
- [ ] 输出格式统一：
  - [ ] 文件名
  - [ ] PASS / FAIL
  - [ ] 命中的坏特征串
  - [ ] 命中的已 patch 特征
- [ ] 失败时返回非 0 exit code

### 完成标准

- [ ] 本地执行 `python tools/verify-patch.py` 能正常跑
- [ ] 对空目录、损坏文件、无匹配文件能正确报错
- [ ] 对至少一个 `.gz` 产物能正常解压检查

---

## A2. 新增 `tools/scan-frida-signatures.py`

- [ ] 新建文件：`D:\code\saomiao\faka\Florida\tools\scan-frida-signatures.py`
- [ ] 支持扫描单文件或目录
- [ ] 支持输出命中的：
  - [ ] 字符串
  - [ ] 所属文件
  - [ ] 上下文片段
- [ ] 提供内置规则组：
  - [ ] `core`
  - [ ] `strict`
  - [ ] `custom`
- [ ] 支持命令行传额外关键字
- [ ] 输出 JSON 或纯文本（二选一先做）

### 完成标准

- [ ] 能作为 `verify-patch.py` 的辅助排查工具使用
- [ ] 能单独扫描 release-assets 目录

---

## A3. 把验收工具接入 CI

目标文件：

- `D:\code\saomiao\faka\Florida\.github\workflows\build.yml`

待改项：

- [ ] 在打包完成后新增 “verify release assets” 步骤
- [ ] 安装脚本依赖时确认 Python 环境可用
- [ ] 运行：

```bash
python3 tools/verify-patch.py release-assets
```

- [ ] verify 失败时终止 workflow
- [ ] 在日志中打印简洁结果摘要

### 完成标准

- [ ] GitHub Actions 成功时能看到 verify 通过
- [ ] 人为制造未 patch 产物时 verify 能拦截

---

## B. Phase 2：统一后处理入口

## B1. 重构 `src/anti-anti-frida.py`

目标文件：

- `D:\code\saomiao\faka\Florida\patches\frida-core\0007-Florida-update-python-script.patch`
- `D:\code\saomiao\faka\Florida\patches\frida-core\0010-exec-anti-anti-frida.py.patch`

待改项：

- [ ] 将脚本逻辑拆成函数：
  - [ ] `patch_symbols(...)`
  - [ ] `patch_rodata_strings(...)`
  - [ ] `patch_thread_names(...)`
  - [ ] `main(...)`
- [ ] 把坏字符串列表集中定义
- [ ] 把线程名 patch 逻辑集中定义
- [ ] 保留 Florida 的随机化策略：
  - [ ] `frida/FRIDA` 替换继续随机
  - [ ] `gum-js-loop` 替换继续随机
  - [ ] `gmain` 替换继续随机
  - [ ] `gdbus` 替换继续随机
- [ ] 明确脚本输入输出：
  - [ ] 输入文件路径
  - [ ] 输出 patch 日志
  - [ ] 错误返回码

### 完成标准

- [ ] 脚本本身结构清晰
- [ ] 单独执行时行为不变
- [ ] 仍可直接 patch 单个 ELF / so 文件

---

## B2. 新增统一调度脚本 `tools/post-process-florida.py`

- [ ] 新建文件：`D:\code\saomiao\faka\Florida\tools\post-process-florida.py`
- [ ] 输入参数至少支持：
  - [ ] `kind`
  - [ ] `host_os`
  - [ ] `artifact_path`
- [ ] 调度规则：
  - [ ] `shared-library` 执行 patch
  - [ ] `executable` 执行 patch
  - [ ] `static-library` 先默认跳过
- [ ] Linux / Android 默认启用
- [ ] 失败时返回非 0
- [ ] 成功时打印：
  - [ ] 正在处理哪个文件
  - [ ] 是否执行 patch
  - [ ] patch 是否成功

### 完成标准

- [ ] 能单独对一个产物手工执行
- [ ] 输出清晰日志

---

## B3. 将构建链路切换到统一后处理

目标文件：

- Frida 对应版本的 `tools/post-process.py` patch
- `src/embed-agent.py` patch

待改项：

- [ ] 不再只依赖 `embed-agent.py` 触发 patch
- [ ] 改为在最终产物 post-process 阶段统一调用
- [ ] `embed-agent.py` 中如仍需保留逻辑，避免重复 patch
- [ ] 覆盖以下最终产物：
  - [ ] server
  - [ ] inject
  - [ ] gadget
  - [ ] agent

### 完成标准

- [ ] 所有最终产物的 patch 都由统一链路触发
- [ ] 不出现重复 patch
- [ ] `verify-patch.py` 全通过

---

## C. Phase 3：引入源码级混淆模块

## C1. 新增 `obfuscate.vala`

- [ ] 新建 patch，最终落地文件：
  - `subprojects/frida-core/lib/base/obfuscate.vala`
- [ ] 提供通用 API：
  - [ ] `decode_hex_xor(...)`
  - [ ] 或保留 `decode_base64(...)`
- [ ] 逻辑尽量轻量
- [ ] 不引入额外复杂依赖

### 完成标准

- [ ] 编译通过
- [ ] 可被 `rpc.vala` 等文件调用

---

## C2. 修改 `lib/base/meson.build`

- [ ] 把 `obfuscate.vala` 加入 `base_sources`

### 完成标准

- [ ] 编译时包含新文件

---

## C3. 优先迁移 `lib/base/rpc.vala`

当前状态：

- Florida 已做 Base64 隐藏

待改项：

- [ ] 从“文件内私有实现”切到 `Obfuscate` 通用模块
- [ ] 保持现有兼容行为不变
- [ ] 只改实现，不改协议结果

### 完成标准

- [ ] 仍能构建通过
- [ ] 行为与当前版本一致

---

## C4. 第二批迁移目标

依次处理以下文件：

- [ ] `lib/agent/agent.vala`
- [ ] `lib/base/p2p.vala`
- [ ] `lib/base/xpc.vala`
- [ ] `lib/gadget/gadget.vala`

每个文件都按下面步骤走：

- [ ] 先定位字面量
- [ ] 判断是否影响兼容
- [ ] 能源码混淆的先源码混淆
- [ ] 编译
- [ ] 跑 verify / scan

### 完成标准

- [ ] strings 中直白特征串减少
- [ ] 功能不受影响

---

## D. Phase 4：扩大线程名覆盖

## D1. 先做全局扫描

执行：

```powershell
rg -n "Thread<|set_thread_name|g_thread_new|frida-" D:\code\saomiao\faka\Florida
```

待做项：

- [ ] 整理扫描结果
- [ ] 标记高优先级文件
- [ ] 标记只适合二进制 patch 的点

### 优先级排序

- [ ] `lib/gadget/gadget.vala`
- [ ] `lib/agent/agent.vala`
- [ ] `src/frida-glue.c`
- [ ] `gum/gum.c`
- [ ] `lib/base/p2p.vala`

---

## D2. 逐点处理线程名

每个命中点按这个顺序处理：

- [ ] 判断能否源码改
- [ ] 若能源码改，改为运行时解码
- [ ] 若不能源码改，保留给 `anti-anti-frida.py` 随机 patch
- [ ] 记录该点属于：
  - [ ] 源码层处理
  - [ ] 二进制层处理
  - [ ] 暂不处理

### 完成标准

- [ ] 明确每个线程名点的处理策略
- [ ] 避免重复 patch / 冲突 patch

---

## E. Phase 5：补本地构建脚本

## E1. 新增本地构建脚本

可选文件：

- `D:\code\saomiao\faka\Florida\tools\build-android-all.sh`
- 或 `D:\code\saomiao\faka\Florida\tools\build-android-all.ps1`

待做项：

- [ ] 支持四架构串行构建
- [ ] 支持：
  - [ ] clone / checkout Frida
  - [ ] apply Florida patches
  - [ ] build
  - [ ] package
  - [ ] verify
- [ ] 输出目录统一
- [ ] 生成日志文件

### 完成标准

- [ ] 本地单命令可完成完整流程
- [ ] 出错时能快速定位在哪个阶段失败

---

## E2. 本地构建结果目录规范

- [ ] 统一输出目录：
  - [ ] `release-assets/`
  - [ ] `logs/`
  - [ ] `work/` 或 `build-*`
- [ ] verify 日志单独保存
- [ ] 构建日志按架构区分

---

## F. Patch 结构整理

## F1. 现有 patch 文件整理

目标目录：

- `D:\code\saomiao\faka\Florida\patches\frida-core`
- `D:\code\saomiao\faka\Florida\patches\frida-gum`

待做项：

- [ ] 检查是否需要新增 patch：
  - [ ] `post-process` 相关 patch
  - [ ] `obfuscate.vala` 相关 patch
  - [ ] `meson.build` 相关 patch
- [ ] 确认 patch 顺序
- [ ] patch 名称与内容对应
- [ ] 保持一个 patch 只做一类事

### 推荐 patch 分组

- [ ] 协议 / 字面量类
- [ ] agent / entrypoint 类
- [ ] 二进制 patch 脚本类
- [ ] post-process 调度类
- [ ] 线程名 / prgname 类
- [ ] 验证工具类（仓库侧，不进入 Frida patch 也可以）

---

## G. 文档补充

## G1. README 补充最少说明

目标文件：

- `D:\code\saomiao\faka\Florida\README.md`

待做项：

- [ ] 增加本地构建简要说明
- [ ] 增加 verify 使用说明
- [ ] 增加 scan 使用说明
- [ ] 增加“哪些特征由源码层处理，哪些由二进制层处理”的说明

---

## H. 建议开发顺序

严格按这个顺序做：

### 第一步

- [ ] A1 `verify-patch.py`
- [ ] A2 `scan-frida-signatures.py`
- [ ] A3 CI 接入 verify

### 第二步

- [ ] B1 重构 `anti-anti-frida.py`
- [ ] B2 新增 `post-process-florida.py`
- [ ] B3 接入统一后处理

### 第三步

- [ ] C1 新增 `obfuscate.vala`
- [ ] C2 接入 `meson.build`
- [ ] C3 先迁 `rpc.vala`

### 第四步

- [ ] C4 迁 `agent/p2p/xpc/gadget`
- [ ] D1 扫线程名
- [ ] D2 扩大线程名处理

### 第五步

- [ ] E1 本地构建脚本
- [ ] E2 输出目录规范
- [ ] G1 文档补充

---

## I. 最小可上线版本

如果时间有限，先只做下面这些：

- [ ] `tools/verify-patch.py`
- [ ] `tools/scan-frida-signatures.py`
- [ ] `tools/post-process-florida.py`
- [ ] `obfuscate.vala + rpc.vala`

这四项完成后，就已经拿到 rusda 最有价值的核心能力：

- [ ] 构建后能自动验收
- [ ] patch 入口统一
- [ ] 源码级混淆有基础设施

---

## J. 开发完成判定

全部完成后，至少满足：

- [ ] CI 构建后自动执行 verify
- [ ] server / inject / gadget / agent 全部走统一 patch 流程
- [ ] `rpc.vala` 已接入通用混淆模块
- [ ] 本地可单命令完成 build + package + verify
- [ ] strings 结果中关键 Frida 特征明显减少
- [ ] 不破坏现有 Florida 的随机化策略

