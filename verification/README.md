# 章级可复现验证合同

本目录实现 P9 D5 的自动化部分。当前覆盖四个 Java 黄金样章，共 12 个独立 recipe；它不是 255 章已经完成验证的声明。

## 合同边界

- `manifests/<chapter-id>.yml` 逐文件声明公共输入、SHA-256、模式、工具版本、固定命令、精确退出码、可观察预言和完整输出增量。
- evidence 同时锁定 schema、固定 CLI 与 Runner/路径/原子写入实现的完整本地加载闭包，避免只锁教材输入却遗漏验证器版本。公开 Runner 固定 11 项控制面文件；内部 Runner 因额外锁定公开输入闭包 schema 与清单而固定 13 项。
- 每个 recipe 都复制到独立系统临时目录。Runner 不从 manifest 接受任意解释器、绝对路径或 shell 命令字符串。
- 每个工具探针和 recipe 都有单命令超时。命令在独立进程组中运行；超时后先向整个进程组发送 `TERM`，宽限期后仍存活则发送 `KILL`，并回收主进程。超时是合同失败，不会写入新 evidence。
- evidence 的 `environment.runner_runtime` 记录实际 Ruby engine、version、patchlevel、platform 与 description；`execution_policy` 记录此次 Runner 真正采用的 `timeout_seconds` 和 `termination_grace_seconds`。因此“同机固定工具环境可重复”包含执行验证器自身，而不是只记录被测工具。
- Maven、pnpm、uv 只要被合同声明，就必须配置各自的固定缓存目录；私有答案清单还会把入口中的 `dart pub` 识别为 `dart-pub` 缓存需求。Runner 不回退到用户默认缓存；执行环境清空未声明的父进程变量，并给包管理器设置离线参数。缓存路径必须是仓库外、真实存在、可读写、无符号链接且不含空白字符的绝对路径。
- `solutions-private/`、`sources/private/`、符号链接、路径穿越、大小写冲突、输入漂移、输入修改和未声明输出都会失败。
- 命令的 stdout/stderr 原文不会写入 evidence；临时 sandbox 前缀、其中随机命名的 `tmp` 子项以及携带临时时间戳的绝对 diff 头先统一替换为占位符，证据再保存规范化摘要、大小、通过的观察数量和公共相对路径。该规则支持同机固定工具环境的重复证据字节，不等同跨平台可复现。
- 只有全部 recipe 通过后，`verification/evidence/last-run/evidence.json` 才会通过 staging 与 rename 原子替换。失败保留上一份成功证据。
- 这是干净副本和 fail-closed 清单，不是容器或 OS 沙箱。网络策略与仓库外文件系统并未由操作系统强制隔离，因此不能把结果称为供应链安全、跨平台可复现、无障碍合规或人工教学审查通过。

## 使用

只校验 schema、语义、文件模式和输入摘要，不执行教学代码：

```bash
ruby scripts/run-verification.rb --check
```

真实执行所有已有 manifest 并原子写入最后一次成功证据：

```bash
export FACTORYCARE_MAVEN_REPO="$HOME/.m2/repository"
export FACTORYCARE_PNPM_STORE_DIR="$HOME/Library/pnpm/store"
export FACTORYCARE_DART_PUB_CACHE="$HOME/.cache/factorycare/p9/dart-pub-cache"
export FACTORYCARE_UV_CACHE_DIR="$HOME/.cache/uv"
ruby scripts/run-verification.rb --timeout 300
```

只需配置实际 manifest 声明的包管理器缓存；例如当前四份正式合同使用 Maven，因此至少需要 `FACTORYCARE_MAVEN_REPO`。目录不存在、位于仓库内、经符号链接到达或没有读写权限都会在执行命令前失败。也可用 `--maven-repo`、`--pnpm-store`、`--dart-pub-cache`、`--uv-cache` 临时覆盖环境变量；CLI 覆盖优先。`--timeout` 的默认值为 300 秒，也可用 `FACTORYCARE_VERIFICATION_TIMEOUT` 设置。

机器可读摘要可追加 `--json`。公开 evidence 的通用缓存摘要只记录缓存位置的 SHA-256 标识，不保存缓存绝对路径，也不把位置标识冒充缓存内容冻结；需要声称 pnpm 或 Dart Pub 内容稳定的调用方必须另行记录运行前后有界内容清单。命令原始输出和本机临时路径也不会写入。

要求 255 章全部具备最终 manifest 时使用硬门；当前会按设计返回非零：

```bash
ruby scripts/run-verification.rb --check --require-complete
ruby scripts/generate-verification-manifests.rb --coverage --json
```

第二条命令会给出每个缺口 ID、已有最终合同数、bootstrap candidate 数、候选入口总数与静态工具提示统计。生成逐章候选清单但不写成最终合同，必须先提供同次 clean-copy 全端点观察：

```bash
RUNTIME_ROOT="$HOME/.cache/factorycare/p9/pnpm-runtime"
JAVA25="$(/usr/libexec/java_home -v 25)"
NODE24="$HOME/.nvm/versions/node/v24.18.0/bin"
env \
  PATH="$RUNTIME_ROOT/bin:$JAVA25/bin:$NODE24:$HOME/Library/pnpm:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/Applications/ChatGPT.app/Contents/Resources:/usr/bin:/bin:/usr/sbin:/sbin" \
  COREPACK_HOME="$RUNTIME_ROOT/corepack" \
  COREPACK_ENABLE_NETWORK=0 \
  JAVA_HOME="$JAVA25" \
  ruby scripts/generate-verification-manifests.rb \
  --bootstrap-candidates \
  --endpoint-report records/encyclopedia/evidence/machine/endpoint-audit-2026-07-24.json \
  --output records/encyclopedia/evidence/machine/observed-candidates-v2-2026-07-24.json
```

candidate v2 会列出三个公开端点各自的完整静态输入闭包、固定命令、双 fresh-copy
精确退出码与规范化观察、输出闭包和工具版本探针。工具探针是在 candidate 生成时
按候选静态工具提示另行执行的，不是 endpoint 审计执行时采集的观察。它仍是
`observed-unreviewed` 机器观察，而不是 `verification/manifests/` 中的 final 合同。
上例的版本路径是 2026-07-24 这次本机观察的固定输入；重放时应保持同一工具补丁版和
同一预置 Corepack 根，不要把“可执行文件同名”当成版本相同。

输入文件经过有意修改后，先人工复核 recipe 合同，再刷新已有 manifest 的模式和摘要：

```bash
ruby scripts/generate-verification-manifests.rb --write
ruby scripts/generate-verification-manifests.rb --check
```

生成器刻意不推断命令、退出码、观察或输出集合。自动猜测这些字段会把未知行为误写成已验证合同。扩展到剩余 251 章时，应先逐章确认唯一 `verify.sh` 入口、公开练习的稳定 expected-red、工具版本及真实文件系统增量，再运行摘要刷新和统一 Runner。

## 私有答案验证（internal-only）

私有答案使用独立合同和 Runner，不进入公共 manifest，也不写入 `verification/evidence/`。先验证 255 章目录、唯一可执行 `verify.sh`、普通文件与无符号链接约束，不执行答案：

```bash
ruby scripts/run-private-verification.rb --check
```

每个私有 recipe 都必须在 `verification/private-public-input-closures.yml` 中有且仅有
一条按 chapter ID 排序的记录；不需要公开依赖时显式使用空 `inputs`。非空记录只能
声明同章 `examples/encyclopedia`、`labs/encyclopedia` 或
`exercises/encyclopedia` 下的普通文件，并逐项锁定相对路径、SHA-256 与 mode。
schema 拒绝未知字段和任意仓库路径；加载器还会拒绝跨章所有权、缺失、摘要/mode
漂移、symlink、特殊文件及任何私有标记。

执行时 Runner 为每章建立最小临时 repository：只复制该章私有 recipe 输入和该条
记录明确声明的公开输入，不复制整个仓库，也不改写现有私有脚本。执行前后的快照覆盖
这两类输入；任何修改或删除都会失败，未声明的仓库文件在临时副本中不可见。

执行全部私有答案时使用同一套超时和固定缓存策略：

```bash
export FACTORYCARE_MAVEN_REPO="$HOME/.m2/repository"
export FACTORYCARE_PNPM_STORE_DIR="$HOME/Library/pnpm/store"
export FACTORYCARE_DART_PUB_CACHE="$HOME/.cache/factorycare/p9/dart-pub-cache"
export FACTORYCARE_UV_CACHE_DIR="$HOME/.cache/uv"
ruby scripts/run-private-verification.rb --timeout 300
```

内部证据只写入被 Git 忽略的 `verification/private-evidence/last-run/evidence.json`。它只包含公开 chapter ID、退出码、私有/公开输入计数及集合摘要；不会列出闭包路径，也不包含 `solutions-private/` 路径、私有文件名、输入内容、stdout/stderr 原文或本机绝对路径。答案在上述最小干净副本中运行；新增构建输出只记录不透明集合摘要。该内部合同证明“当前私有入口在本机固定环境下返回 0”，不等同于 255 章公共 D5 manifest，也不声明教学质量或跨平台通过。

全端点审计把三个公开端点各运行两份独立 fresh copy，私有解析运行一份：

```bash
export FACTORYCARE_MAVEN_REPO="$HOME/.m2/repository"
export FACTORYCARE_PNPM_STORE_DIR="$HOME/.cache/factorycare/p9/pnpm-runtime/store"
export FACTORYCARE_UV_CACHE_DIR="$HOME/.cache/uv"
export FACTORYCARE_DART_PUB_CACHE="$HOME/.cache/factorycare/p9/dart-pub-cache"
export FACTORYCARE_PNPM_RUNTIME_ROOT="$HOME/.cache/factorycare/p9/pnpm-runtime"
export FACTORYCARE_DOCKER_COMPOSE_PLUGIN="/Applications/Docker.app/Contents/Resources/cli-plugins/docker-compose"
ruby scripts/audit-encyclopedia-endpoints.rb \
  --output records/encyclopedia/evidence/machine/endpoint-audit-2026-07-24.json &&
ruby scripts/audit-exercise-contracts.rb \
  --endpoint-report records/encyclopedia/evidence/machine/endpoint-audit-2026-07-24.json \
  --output records/encyclopedia/evidence/machine/exercise-contracts-2026-07-24.json
```

这里的 `&&` 是有意的 fail-fast 边界。即使绕过命令链直接运行派生工具，exercise 与
candidate v2 CLI 也会拒绝并返回非零，除非来源报告是 `status: passed`、
`1020/1020`、四类端点各 `255/255`，且 `infrastructure_failures` 为空。两份派生报告都
保存来源 endpoint JSON **原始文件字节**的 SHA-256；candidate 另保留只覆盖其三个公开
角色稳定投影的 `endpoint_observation_set_sha256`，两者语义不同，不能互换。

`FACTORYCARE_PNPM_RUNTIME_ROOT` 必须同时包含可执行的 `bin/pnpm` 与预置的
`corepack/v1/pnpm/<version>`。这是因为 Corepack 的 CLI 切换发生在 pnpm 自身的
`--offline` 生效之前；只固定 store 仍可能触发 CLI 下载。端点报告分别保存运行时根和
pnpm store 的脱敏位置摘要，并保存入口脚本及预置版本集合摘要。依赖和 CLI 的预热属于
审计前准备；正式执行显式设置 `COREPACK_ENABLE_NETWORK=0`、pnpm offline 与 silent
reporter，并清空未声明的父进程环境，不会静默联网补 CLI 或依赖。store 报告额外保存
content-addressed 路径/大小与 index 字节的清单摘要；它排除 pnpm 的可变 projects 状态，
且缓存位置摘要不应被误称为完整缓存字节冻结。

`FACTORYCARE_DART_PUB_CACHE` 指向仓库外、真实且无符号链接组件的专用离线缓存。
审计器只把 `hosted`、`hosted-hashes` 与存在时的 `git/cache` 纳入包内容清单，显式排除
`_temp`、`active_roots` 和 `log`；运行前后清单不一致会按基础设施失败关闭。Dart 工具在
fresh HOME 根部产生的 `.dartServer` 仅进入独立 runtime-scratch 通道：每次仍记录原始条目数、
精确路径/类型集合摘要及路径/字节摘要，但不把 PID 等工具瞬态状态混入教材语义输出比较。
相邻名称、嵌套位置、TMP 下同名目录以及任何符号链接或特殊文件仍按普通输出或非法输出处理。

`FACTORYCARE_DOCKER_COMPOSE_PLUGIN` 指向 Docker Desktop 内真实、非符号链接的 Compose
可执行文件。审计开始时冻结其字节摘要与大小，只把这一个已冻结插件复制进 fresh HOME 的
专用 `.docker/cli-plugins/`；用户 `~/.docker`、credential 配置和其他插件不会进入执行环境。

审计复制时排除已知生成目录/日志，执行后验证原输入没有被修改或删除；新增输出只能留在临时资产树中，逃逸 symlink、悬空 symlink、循环 symlink和特殊文件都会失败。两份公开运行以退出码、规范化诊断行集合和生成路径/类型集合判断一致性，同时保留每次生成输出的精确字节摘要，避免把 Maven 测试时间戳等合法非确定字节误写为闭包漂移。练习报告只列出 `EXPECTED_RED`、精确退出码和可安全标准化候选，不会机械改写 255 个练习。它仍不是 OS 级文件系统沙箱，因此报告会保留这一限制，不能据此声称进程绝无可能写入任意仓库外绝对路径。

## 当前未验证

- 其余 251 章还没有 D5 final manifest；覆盖硬门会逐章报告而不是静默放行；
- 私有答案的独立 internal-only 合同已完成 255/255 一次全量 clean-copy 执行；最后一次成功 evidence 仅留在 Git 忽略的 `verification/private-evidence/last-run/`，不可分发，也不计入公共 D5 覆盖或人工教学批准；
- Linux、Windows、其他 JDK/工具 patch 与网络断开环境未执行；
- HTML、EPUB、PDF 的人工版式、键盘、读屏和零基础读者任务不属于本 Runner。

## 255 章完成定义盘点

`scripts/audit-encyclopedia-definition-of-done.rb` 为 255 章生成独立的结构化完成定义报告。
每章固定检查目录条目、正文、三类 outcome、四类验证入口、final manifest，以及七类人工门和
最终语义批准。状态只允许 `present`、`missing`、`human-review-required` 与
`not-applicable`；最后一种必须附具体理由。报告把章节按 catalog 顺序稳定分成 42 个
6–7 章人工复核批次，符合每批 5–8 章的审查边界。

```bash
ruby scripts/audit-encyclopedia-definition-of-done.rb \
  --output records/encyclopedia/evidence/machine/definition-of-done-2026-07-24.json
```

该命令在任何章节仍缺结构项或人工批准时有意返回非零，即使报告已成功写出。结构项全绿只表示
声明的文件和机器合同存在；它不等于技术正确、教学有效、无障碍合规、学习者掌握或正式发布批准。
报告也不会修改章节状态、final manifest 或学习进度。
