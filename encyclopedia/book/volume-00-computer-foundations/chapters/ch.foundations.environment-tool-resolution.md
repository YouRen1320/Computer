---
schema_version: 2
edition: 2026.2-draft
id: ch.foundations.environment-tool-resolution
title: 环境变量、PATH 与工具版本解析
responsibility: 解释进程如何继承环境并解析同名工具，聚焦可观察的版本选择，不进入具体语言构建系统
volume: '00'
order: 6
level: L1
status: drafting
path: book/volume-00-computer-foundations/chapters/ch.foundations.environment-tool-resolution.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.cli-streams-exit-codes
version_surfaces:
- zsh-5.9
- macos-26
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释环境变量、PATH 与工具版本解析的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - environment
  - tool-resolution
  covers_topics:
  - env.variable
  - env.process-inheritance
  - env.session-scope
  - env.path-order
  - env.command-resolution
  - env.version-provenance
  uses_capabilities:
  - foundation.shell-command-stream
  - foundation.os-process-memory
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 生成一份当前 shell 与子 shell 的环境快照，比较 PATH 顺序、type -a、实际可执行路径和工具版本来源，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - environment
  - tool-resolution
  covers_topics:
  - env.variable
  - env.process-inheritance
  - env.session-scope
  - env.path-order
  - env.command-resolution
  - env.version-provenance
  uses_capabilities:
  - foundation.shell-command-stream
  - foundation.os-process-memory
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入 PATH 与 JAVA_HOME 指向不同 JDK 的冲突，解释为何 java 与 Maven 可选中不同运行时并给出会话内修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - environment
  - tool-resolution
  covers_topics:
  - env.variable
  - env.process-inheritance
  - env.session-scope
  - env.path-order
  - env.command-resolution
  - env.version-provenance
  uses_capabilities:
  - foundation.shell-command-stream
  - foundation.os-process-memory
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 环境变量、PATH 与工具版本解析

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《stdin、stdout、stderr、管道与退出码》](ch.foundations.cli-streams-exit-codes.md)：独立完成环境与继承、工具解析前，必须先具备「stdin、stdout、stderr、管道与退出码」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

同一台电脑上，终端运行 `java -version` 显示一个版本，Maven 的 `mvn -v` 却显示另一个运行时；IDE 项目又使用第三个 JDK。临时设置了 `JAVA_HOME`，直接执行 `java` 仍没有变化；重新打开终端以后，刚才“修好”的配置又消失。这些现象看似随机，其实都可以用进程环境、Shell 命令解析和工具自身启动规则解释。

本章建立一套不靠重装、不靠猜测的诊断方法。环境变量是进程启动上下文中的名字—值映射；父进程在创建子进程时传递一份环境，子进程的修改不会反向改写已经存在的父进程。`PATH` 是其中一个有顺序的目录列表，Shell 用它查找不含斜杠的外部命令名。`JAVA_HOME` 通常只是“某个 JDK 根目录”的信息，它不会自动重写 `PATH`；某些启动器会主动读取它，另一些命令仍由 Shell 按 `PATH` 解析。因此，只看一个变量或一个版本输出不能证明完整来源。

这里不会教你安装和切换所有版本管理器，也不会修改真实 `.zshrc`、系统默认 JDK、Homebrew 链接或 IDE 配置。示例在新临时目录创建两个假的工具根，用固定脚本模拟“直接 java 走 PATH、Maven 启动器走 JAVA_HOME”的冲突。你将学会观察、解释和做会话内修复，然后在具体 Java、Node、Python 和 Flutter 章节把同一模型迁移到真实工具。

## 学完后你必须能做什么

读完并完成实验后，你应当能够：

1. 解释环境变量属于进程启动上下文，不是全电脑唯一、实时同步的全局字典；
2. 区分 Shell 普通变量与已导出环境变量，说明子进程为什么可能看不到前者；
3. 证明父进程会把环境传给子进程，而子进程不能反向修改父进程现有环境；
4. 区分当前命令临时赋值、当前 Shell 会话赋值和新终端启动配置三个范围；
5. 把 `PATH` 拆成有顺序的目录，预测同名外部工具首先命中哪一个；
6. 使用 `type`、`type -a`、`command -v` 观察别名、函数、内建与外部路径，不只依赖 `which`；
7. 说明绝对可执行路径绕过 `PATH` 选择，但不自动保证文件可信、版本正确或依赖一致；
8. 为工具记录“解析路径、版本输出、运行时来源、启动入口”四类证据；
9. 解释 `JAVA_HOME` 与 `PATH` 不一致时，为什么直接 `java` 与 Maven 可能选择不同 JDK；
10. 在不卸载、不改系统配置的前提下，用临时子进程复现和修复一次版本冲突；
11. 识别把当前目录放进 `PATH`、泄露环境秘密、加载未知初始化脚本等安全风险；
12. 审查 AI 给出的环境修复，拒绝“删掉全部 JDK再重装”这种无证据、难回滚的做法。

掌握标准不是能背出 `export PATH=...`，而是能够画出父子进程、环境快照、命令解析和工具启动器的关系，对固定场景先预测，再用路径与版本证据证明。

## 零基础补救：变量、字符串和进程快照

### 环境是一组名字—值

可以把一个进程的环境想成启动时携带的一张配置卡：

```text
LANG=zh_CN.UTF-8
PATH=/opt/tools/bin:/usr/bin:/bin
JAVA_HOME=/opt/jdks/jdk-25
```

左边是名字，右边是字符串值。环境本身通常不提供布尔、整数或路径类型；目标程序按自己的合同解释字符串。`PATH` 看起来像多个目录，是因为 Shell 约定按分隔符拆解；`JAVA_HOME` 看起来像目录，是因为 Java 生态工具约定这样使用。一个变量存在不代表值有效，路径字符串也不证明目标真实存在。

变量名区分大小写，`Path`、`PATH` 与 `path` 不应随意混用。空字符串、未设置和指向空目录也可能产生不同结果。诊断报告应区分“未设置”“已设置为空”“已设置但目标不存在”，不能都写成“没有环境”。

### Shell 变量不一定进入子进程环境

在 zsh 中给变量赋值：

```text
DEMO_MODE=training
```

这会建立或修改当前 Shell 的参数，但新启动的普通子进程未必能在环境中看到。导出后：

```text
export DEMO_MODE
```

zsh 在启动后续子进程时把它放入环境。也可以一步完成：

```text
export DEMO_MODE=training
```

“Shell 自己能 `echo` 出值”与“子进程能通过环境读取值”是两项不同证据。实验用 Ruby 探针只查询明确允许的名字，不打印整个环境，避免把令牌、代理凭据或个人路径混入学习日志。

### 环境不是共享可变对象

父 Shell 启动子进程时，子进程得到可用的环境副本。子进程可以修改自己的环境，并将修改继续传给它创建的孙进程；它不能穿越进程边界，把已经存在的父 Shell 环境直接改掉。

```text
父 zsh：DEMO_MODE=parent
   └─ 子 zsh：看到 parent，临时改成 child
          └─ 孙进程：看到 child

子 zsh 结束后
父 zsh：仍是 parent
```

这就是“子会继承父，父不会继承子”的精确版本。它不是说父子永远完全相同：父可以选择只传部分环境，也能为单个子命令覆盖值；程序还可能清理或重写环境。要证明具体行为，必须观察目标进程，而不是只看父 Shell。

## 三种常见作用范围

### 只作用于一个命令

```text
DEMO_MODE=training ruby env_probe.rb
```

这个前置赋值为该命令准备环境，命令结束后当前 Shell 原值通常不因此被永久改写。它适合安全实验与单次覆盖：范围小、回滚自然、容易记录。若需要完全控制输入，可以使用 `env` 启动固定环境，但不要随意清空真实工具必需的变量。

### 作用于当前 Shell 会话

```text
export DEMO_MODE=training
```

后续由该 Shell 启动的子进程通常继承此值，直到你修改、取消或结束这个 Shell。另一个已经打开的终端标签有自己的 Shell 进程，不会被同步更新。关闭标签后重新打开，新 Shell 的初始值取决于启动入口和配置，不由刚才已结束的 Shell 保存。

### 作用于未来新 Shell 的启动配置

把命令写入 zsh 启动文件可能影响未来会话，但到底读取哪个文件与 Shell 是否 login、interactive、被什么应用启动有关。修改配置是持久变更，需要备份、注释、重复加载保护和新终端验证。本章只阅读模型，不要求改配置；练习全部用 `/bin/zsh -f` 跳过个人启动文件。

“打开新终端”不是神秘修复。它创建新进程并重新走一遍启动路径，所以可能加载刚保存的配置，也可能暴露配置只对另一类 Shell 生效。诊断时记录旧会话与新会话各自的环境和解析结果，不能只说“重启后好了”。

## PATH：有顺序的外部工具候选目录

### 它不是一个工具仓库，也不是版本号

`PATH` 通常是由冒号分隔的目录列表：

```text
/opt/factorycare/tool-a/bin:/usr/bin:/bin
```

当你输入不含斜杠的外部命令名，例如 `demo-tool`，Shell 会按规则寻找。简化模型是从左到右检查目录，先命中的可执行候选被采用。因此交换前两项就可能改变版本，即使两个文件都没有变化。

目录项顺序是合同。仅报告“PATH 里有 JDK 25”不够；若 JDK 21 的 `bin` 位于前面，直接 `java` 可能先命中 21。反过来，目录排在前面也不保证文件真实可执行、架构兼容或没有被别名覆盖。

### 空目录项与当前目录风险

某些 Shell 或工具会把空 `PATH` 项解释为当前目录。显式加入 `.` 也会让当前工作目录中的同名文件参与命令解析。进入一个不可信项目后，输入常见命令名可能启动项目内恶意文件。基础安全策略是使用明确、受信目录，不把当前目录放在系统工具之前；对敏感诊断使用已知绝对路径。

这并不表示绝对路径永远安全。文件本身可能被替换、是符号链接或属于错误发行版。绝对路径只解决“绕过 PATH 选择哪一个入口”这一个问题。

### PATH 修改只是当前进程状态

```text
export PATH='/opt/tool-a/bin:/usr/bin:/bin'
```

这改变当前 Shell 参数，并影响后续子进程。它不会自动改写另一个已打开终端，也不会删除原工具。若写入启动文件，才可能影响未来新 Shell。调试时优先使用单命令覆盖：

```text
PATH='/opt/tool-a/bin:/usr/bin:/bin' demo-tool --version
```

这样能证明候选顺序与结果的因果关系，又不污染当前会话其余操作。

## Shell 到底如何解析命令名

### 外部文件不是唯一候选

Shell 能执行的“命令”还可能是别名、函数、保留语法、内建命令或哈希缓存中的外部路径。只运行文件查找工具可能漏掉这些层。对 zsh 的零基础诊断，应先用：

```text
type demo-tool
type -a demo-tool
command -v demo-tool
```

- `type` 描述当前名称会被解释成什么；
- `type -a` 尽量列出同名的多个候选，包括命令类型与外部路径；
- `command -v` 给出可用于调用的当前解析信息，适合脚本化存在性检查；
- 运行 `demo-tool --version` 再证明被启动程序自报的版本。

不要把具体输出格式跨 Shell 硬编码。Bash、zsh 和其他 Shell 的描述文字可能不同。固定实验明确运行 `/bin/zsh -f`，验证器将临时绝对路径归一化后再比较。

### 为什么不把 `which` 当唯一证据

`which` 的实现、别名处理与跨 Shell 行为可能不同，有时只搜索 `PATH` 外部文件，无法完整说明函数和内建。它可以作为辅助观察，不能替代 Shell 自身的 `type`/`command -v` 与实际版本输出。面试或故障报告中说“which 显示了路径，所以一定运行它”证据不足。

### 缓存与旧会话

为了性能，Shell 可能缓存外部命令位置。修改 `PATH` 后，实际行为还可能受 Shell 状态影响。zsh 提供重新哈希等机制，但初学诊断不应先背清缓存命令；更稳妥的实验是使用新的 `/bin/zsh -f`、明确传入固定 `PATH`，再比较 `type -a`、`command -v` 和实际输出。若旧会话与新会话不同，把“会话状态或启动配置”列为待验证假设。

## 绝对路径、符号链接与真实来源

输入：

```text
/opt/tool-b/bin/demo-tool --version
```

命令名含斜杠，Shell 不再从 `PATH` 目录逐项寻找这个入口。这是诊断同名冲突的好方法：若绝对 A 与绝对 B 各自输出稳定，而裸命令随 `PATH` 顺序变化，冲突位于解析层。

但路径文字仍可能经过符号链接。`/usr/local/bin/tool` 可以链接到应用目录，包管理器路径也可能再链接到版本目录。证据报告至少区分：

1. Shell 当前解析出的入口路径；
2. 若需要，入口最终指向的真实文件；
3. 程序自报版本与发行方；
4. 程序内部又启动了什么运行时。

不要把个人绝对路径放进公开教材或错误截图。报告可以用 `<JDK_A>`、`<JDK_B>`、`<TOOL_ROOT>` 等占位符，同时保留顺序关系和版本事实。

## 版本来源：路径和 `--version` 必须配对

一个工具名可能来自系统、包管理器、版本管理器、IDE 内置运行时或项目包装器。只有版本号没有来源，无法复现；只有路径没有版本，也无法证明内容。最低限度记录：

```text
shell: /bin/zsh -f
command: demo-tool
resolved entry: <TOOL_A>/bin/demo-tool
reported version: demo-tool A
PATH order: <TOOL_A>/bin before <TOOL_B>/bin
```

对于 Java 工具链，还要分别记录 `java -version`、`javac -version`、`mvn -v` 与 IDE 项目 SDK。它们是不同进程或启动入口，不能用其中一个替其他作证。版本号相同也不必然来自同一个发行版；路径相似也不保证启动器内部选择同一运行时。

## JAVA_HOME 与 PATH：两个独立输入

### JAVA_HOME 不会自动改写 PATH

`JAVA_HOME` 通常指向 JDK 根，例如一个根下含 `bin/java`。它是环境变量字符串。给子进程临时设置：

```text
JAVA_HOME='<JDK_B>' zsh -f -c '...'
```

不会自动把 `<JDK_B>/bin` 插到继承 `PATH` 最前面。若 `PATH` 仍先列 `<JDK_A>/bin`，子 Shell 直接解析裸命令 `java` 时仍可能启动 A。这里不是“临时变量优先级失效”，而是两个不同选择机制分别使用不同输入。

如果希望裸 `java` 也明确来自 B，需要在同一受控子进程同时构造一致输入：

```text
JAVA_HOME='<JDK_B>' PATH='<JDK_B>/bin:/usr/bin:/bin' zsh -f -c '...'
```

这只用于会话内验证，不应原样抄入永久配置。`<JDK_B>` 是占位符，真实目录必须由本机受信工具或已审查安装记录确认。

### Maven 为什么可能使用另一个 JDK

在 macOS/Unix 环境中，`mvn` 通常先是一个 Shell 能解析到的启动脚本或包装器。启动器可以读取 `JAVA_HOME`，构造具体 Java 启动命令；具体行为应检查当前 Maven 发行版脚本与 `mvn -v`。因此可能出现：

```text
JAVA_HOME 指向 JDK B
PATH 首个 java 来自 JDK A
裸 java -version  → A
mvn -v 的 Java runtime → B
```

这不是 Maven “覆盖全局 Java”，也不是 `java -version` 撒谎。裸 `java` 由当前 Shell 对命令名解析；Maven 启动器可能主动读取另一个环境输入。IDE Maven Runner 又可能由 IDE 设置专用 JDK，形成第三条入口。

最可靠诊断顺序是：

1. `type -a java javac mvn`：列候选与当前类型；
2. `command -v java`、`command -v mvn`：记录当前入口；
3. `echo "$JAVA_HOME"`：只证明变量文本；
4. `java -version`、`javac -version`：证明裸命令实际版本；
5. `mvn -v`：证明 Maven 本身与其当前 Java runtime；
6. 检查 IDE 项目 SDK 与 Maven Runner 设置：证明 GUI 入口；
7. 只在子进程中同时修正 `JAVA_HOME` 与 `PATH`，复跑原观察。

不能把第 3 步单独当结论。`JAVA_HOME` 指向 21 不代表裸 `java` 必为 21；`java -version` 为 25 也不能证明 Maven 一定用 25。

## 父子继承的精确实验

设父 Shell 环境中 `DEMO_MARKER=parent`。运行固定子 Shell：

```text
DEMO_MARKER=child /bin/zsh -f -c 'ruby env_probe.rb'
```

子进程应看到 `child`。命令结束后，父 Shell 原值不变。若在子 Shell 内再次启动孙进程，孙进程会继承子 Shell 导出的值。这里要分别记录父运行前、子内部、父运行后三次观察，不能仅凭最后一次推断整个过程。

普通 Shell 变量与导出变量也应对照：先只赋值并启动探针，预言子进程看不到；再 `export` 后启动，预言能看到。这个实验解释了为什么 `.zshrc` 中一行 `JAVA_HOME=...` 可能让当前 Shell 能展开变量，却没有按预期传给外部启动器。

## 一条工具启动链的执行顺序

诊断裸命令时按以下顺序推理：

1. 终端或 IDE 启动一个 Shell/Runner 进程；
2. 新进程从父进程获得环境，并可能加载自己的启动配置；
3. zsh 解析命令名，先判断 Shell 层候选，再对外部名按 `PATH` 查找；
4. 解析出的文件启动，收到环境、argv、cwd 与标准流；
5. 启动器可能再次读取 `JAVA_HOME`、项目配置或专用设置，选择内部运行时；
6. 工具输出版本和诊断，并返回状态；
7. 调用者把入口路径、版本、内部运行时和状态组合成证据。

若第 2 步新终端没有加载期望配置，继续重装 JDK不会修复启动文件边界。若第 3 步命中旧路径，修改 `JAVA_HOME` 单项不一定改变裸命令。若第 5 步 Maven 使用自己的 Runner 设置，`command -v java` 又不能证明它内部运行时。总是定位第一处分叉。

## 故障诊断：从“随机版本”还原因果链

### 故障一：改 JAVA_HOME 后 java 仍是旧版本

先验证 `JAVA_HOME` 新值，再执行 `type -a java` 和 `command -v java`。若裸命令仍命中旧 JDK 的 `bin/java`，第一处分叉是 `PATH` 顺序，不是 JVM 缓存。会话内修复应同时设置一致的 `PATH` 与 `JAVA_HOME`，再复跑路径和版本；不要先卸载所有版本。

### 故障二：java 为 25，mvn -v 显示 21

分别记录 `command -v mvn`、启动器内容来源、`JAVA_HOME`、`java -version` 与 `mvn -v`。若 Maven 启动器使用 `JAVA_HOME` 的 21，而裸 `java` 走 `PATH` 的 25，两个结果都符合各自输入。修复目标是让项目合同要求的运行时一致，而不是争论哪个命令“更全局”。

### 故障三：当前终端正常，新终端失败

旧 Shell 可能有手工 `export`，新 Shell 没有；也可能启动模式不同、配置文件没有加载或配置顺序覆盖。对两个会话运行相同最小快照，比较环境值、`PATH` 顺序、`type -a` 和版本。第一处差异才是调查入口。不要复制完整 `env` 到聊天工具，先筛选允许字段并脱敏。

### 故障四：IDE 正常，终端失败

IDE 项目 SDK 或 Runner 可以使用明确路径，终端则由 zsh 与 `PATH` 解析。分别记录两个启动入口，不能用 IDE 绿色运行按钮证明终端环境正确，也不能用终端版本证明构建插件的 Runner。修复后从原失败入口复跑。

### 故障五：`which` 和实际行为不同

命令名可能被别名或函数覆盖，Shell 也可能保存命令位置状态。使用 `type -a` 判断类型，`command -v` 获取当前解析，再运行带版本的无副作用命令。必要时在全新 `/bin/zsh -f` 中给出固定 `PATH`。不要把删除缓存目录当第一步。

## 安全：环境和 PATH 都是信任边界

### 环境可能含秘密

访问令牌、代理认证、云凭据和数据库密码常通过环境传递。运行 `env` 并把完整结果粘贴给 AI、工单或公开仓库会泄密。教材探针只读取白名单名称；报告中对用户目录、公司主机、令牌和值做脱敏。若秘密已经提交，删除文件不等于秘密失效，应按安全流程轮换。

### PATH 顺序可以劫持命令

把不可信项目目录或可被他人写入的目录放在系统工具之前，可能使同名恶意文件被启动。敏感操作优先使用已核验绝对入口，并检查文件所有权、链接目标和来源。不要从网络下载未知“修复脚本”后仅因文件名为 `java` 就加入 `PATH`。

### 启动文件是代码

`.zshrc` 等初始化文件会在特定 Shell 启动时执行命令。把 AI 输出整段追加进去可能造成重复 PATH、秘密泄露、每次启动下载或无法打开 Shell。持久修改前要逐行理解、备份、保证重复加载不无限增长，并保留不加载配置的救援入口。本章不执行任何持久写入。

### 绝对路径不是完整信任证明

绝对路径绕过 `PATH`，但目标可能是符号链接、已被替换、架构不符或来自过期发行版。继续核对真实目标、版本输出、签名或包来源。不要把“路径写死”当作供应链安全方案。

## FactoryCare 场景：构建机与开发终端不一致

FactoryCare 教学项目规定 Java 主线运行时为 JDK 25。某位开发者的旧终端手工把 JDK 25 放到 `PATH` 前面，所以 `java -version` 正常；`JAVA_HOME` 仍指向 JDK 21，Maven 启动器据此使用 21。IDE 项目 SDK 又明确配置 25。因此出现“IDE 能运行、裸 Java 是 25、Maven 却是 21”。

先写证据表：

| 入口 | 解析依据 | 当前证据 | 结论边界 |
| --- | --- | --- | --- |
| 终端裸 `java` | zsh + PATH | `type -a`、`command -v`、`java -version` | 仅证明此 Shell 入口 |
| Maven | zsh 找到 mvn；启动器再选 Java | `command -v mvn`、`mvn -v` | 证明此 Maven 进程运行时 |
| IDE Run | IDE 项目/Runner 配置 | 设置页与实际启动行 | 仅证明该运行配置 |

会话内修复在一个新子 Shell 中把 `JAVA_HOME` 与 `PATH` 同时指向受信 JDK 25，运行相同四项观察；父 Shell 不被修改。证据一致后，才讨论持久配置应该由团队脚本、IDE 项目设置还是版本管理器负责。那是后续工程决策，本章不替团队写配置。

如果需求改为同时维护 21 与 25，不应删除其中一个来“消除冲突”。应明确每个项目的版本合同、入口与切换证据。工具并存不是故障，来源不明确且无法复现才是故障。

## 配套示例、实验与答案隔离

可运行示例位于 [`examples/encyclopedia/ch.foundations.environment-tool-resolution`](../../../examples/encyclopedia/ch.foundations.environment-tool-resolution/README.md)。验证器在新临时目录创建 `<TOOL_A>` 与 `<TOOL_B>`，核对环境导出、父子继承、PATH 顺序、`type -a`、`command -v`、绝对路径以及模拟 Maven/JAVA_HOME 分叉。执行：

```text
ruby verify.rb
```

最后一行应为 `environment-tool-resolution verification: PASS`。所有路径在报告中归一化，模拟工具不会调用真实 Java 或 Maven。

实验位于 [`labs/encyclopedia/ch.foundations.environment-tool-resolution`](../../../labs/encyclopedia/ch.foundations.environment-tool-resolution/README.md)。先填写 `worksheet.md`，再运行固定探针。自动检查只证明安全夹具与固定预言，不会修改或验证你的真实 `.zshrc`。

公开练习位于 [`exercises/encyclopedia/ch.foundations.environment-tool-resolution`](../../../exercises/encyclopedia/ch.foundations.environment-tool-resolution/README.md)。隔离解析保存在 `solutions-private/encyclopedia/ch.foundations.environment-tool-resolution/`，不进入公开教材。必须先保存独立诊断，避免把“看过正确命令”误当成掌握。

## 预测—构建—诊断—变更训练

### 预测

给定父环境、子进程覆盖、两个工具目录与 PATH 顺序，先写父、子、孙各自能看到的值，裸命令入口、绝对路径入口和模拟 Maven 运行时。不要运行后再补预测。

### 构建

在实验临时环境生成最小快照：Shell、白名单环境、PATH 逐项顺序、`type -a`、`command -v`、工具自报版本。用 `<TMP>` 等占位符脱敏绝对路径，同时保留 A/B 顺序。

### 诊断

注入三个独立故障：普通变量未导出；PATH 的 B 排在 A 前；JAVA_HOME 为 B 而 PATH 首个 java 为 A。每次指出第一处分叉，只做会话内单项修复，复跑原快照。不要删除工具、编辑启动文件或重启电脑掩盖原因。

### 需求变更

把项目主线从工具 A 改为工具 B。更新环境合同、PATH 顺序预言、绝对入口、版本输出和 Maven 模拟预言；保留 A 仍可通过绝对路径调用的边界。说明哪些旧证据因版本合同变化而过期。

## 无 AI 训练

关闭 AI，限时 50 分钟：

1. 画父、子、孙三层环境继承图；
2. 解释普通变量、`export` 与单命令前置赋值；
3. 给定 A/B 两个目录，预测两种 PATH 顺序的裸命令；
4. 用 `type -a`、`command -v`、版本输出组成证据链；
5. 复现 JAVA_HOME 为 B、裸 java 为 A、模拟 Maven 为 B；
6. 只在临时子进程中把两者统一到 B；
7. 用 120 秒复述“设置 JAVA_HOME 为什么不自动改变 PATH”。

允许查看速查表和官方手册，不允许查看私有解析。验证器通过不能证明你会诊断真实 IDE；真实工具截图也不能替代固定因果实验。

## 复述题与间隔复习

### 当天复述

- 环境变量属于谁？值是什么类型？
- 普通 Shell 变量与已导出变量有什么不同？
- 为什么子进程改值不会反向修改父进程？
- PATH 顺序如何决定同名外部命令？
- `type -a` 与 `command -v` 各提供什么证据？
- JAVA_HOME 与 PATH 为什么可能指向不同 JDK？

### 第 1 天检索

不看正文画父子继承和 PATH 查找图。给出“父=25、子临时=21、孙继承子”的三处值。若把环境说成全局共享，重做实验。

### 第 3 天诊断

给出 `JAVA_HOME=21`、`command -v java=<JDK25>/bin/java`、`java=25`、`mvn runtime=21` 四条记录。写出无需重装的解释、下一条观察和会话内修复。

### 第 7 天迁移

把模型迁移到 `python3`、`node` 或 `flutter`：只比较路径、版本和入口，不安装新版本。指出该工具是否还有项目包装器或 IDE Runner。

### 第 14 天教回

用 120 秒向零基础同学解释“环境是父进程给子进程的启动快照，PATH 是有顺序的候选目录，启动器还可能读取其他变量”。必须包含一个安全风险与一个失败反例。

## 速查表

| 概念 | 最小定义 | 首个观察 | 常见误解 |
| --- | --- | --- | --- |
| environment | 进程启动上下文中的名字—字符串映射 | 白名单变量探针 | 全电脑实时共享字典 |
| shell variable | 当前 Shell 的参数 | Shell 内展开 | 子进程必然看得到 |
| export | 标记后续子进程环境包含变量 | 子进程白名单探针 | 会改已存在父进程 |
| session | 一个 Shell 进程及其当前状态 | 进程入口与新旧终端 | 所有标签同一会话 |
| PATH | 有顺序的外部命令目录列表 | 分项顺序、`type -a` | 只要包含目标就会命中 |
| `type -a` | 列出名称的多个 Shell 候选 | 类型与所有候选 | 等同单一文件路径 |
| `command -v` | 报告当前可调用解析 | 当前入口 | 能证明内部运行时 |
| absolute path | 明确文件入口，绕过 PATH 搜索 | 路径、链接、版本 | 自动可信且依赖一致 |
| JAVA_HOME | 通常指向 JDK 根的环境变量 | 值、目录与启动器规则 | 自动改写 PATH |
| provenance | 工具的来源证据 | 入口、真实目标、版本、运行时 | 只保存版本号即可 |

基础观察模板：

```text
echo "JAVA_HOME=${JAVA_HOME:-<unset>}"
type -a java javac mvn
command -v java
command -v mvn
java -version
javac -version
mvn -v
```

输出可能包含用户名和私人路径，分享前脱敏。不要把模板当修复命令；它只是收集证据。

## 术语表

- **environment / 环境**：进程启动和运行时可读取的一组名字—字符串值。
- **environment variable / 环境变量**：环境映射中的一个名字和值。
- **shell parameter / Shell 参数**：Shell 自己维护的变量；只有满足导出规则才进入普通子进程环境。
- **export / 导出**：让变量参与后续子进程环境构造的 Shell 操作。
- **inheritance / 继承**：父进程创建子进程时传递启动环境的关系。
- **session / 会话**：这里指一个具体 Shell 进程及其当前状态与后代，不是全电脑共享状态。
- **PATH**：Shell 查找外部命令时使用的有序目录列表。
- **command resolution / 命令解析**：Shell 把命令名映射到别名、函数、内建或外部文件的过程。
- **absolute executable path / 绝对可执行路径**：含完整根起点、可直接指定入口的路径。
- **provenance / 来源**：工具入口、真实文件、发行方、版本与内部运行时等可追溯信息。
- **launcher / 启动器**：为目标工具选择运行时、组装参数并启动进程的入口程序或脚本。
- **JAVA_HOME**：Java 生态常用的 JDK 根路径变量；具体消费规则由工具决定。
- **version conflict / 版本冲突**：不同入口或选择规则获得不符合项目合同的工具/运行时组合。

## 一手资料与复核边界

本章版本面为 `zsh-5.9` 与 `macos-26`；稳定核心是父子进程环境、PATH 有序查找和来源取证。资料链接复核日期：**2026-07-24**。上游 zsh 资料只支持语言与手册基线，不能证明 macOS 实际捆绑的 shell 版本；本机结论仍须由命令输出证明。

- [Apple《Use environment variables in Terminal on Mac》](https://support.apple.com/guide/terminal/use-environment-variables-apd382cc5fa/mac)：macOS Terminal 环境变量的用户级入口。
- [Apple《Change the default shell in Terminal on Mac》](https://support.apple.com/guide/terminal/change-the-default-shell-trml113/mac)：Terminal 启动 Shell 与默认 Shell 配置边界。
- [The Open Group Shell Command Language：Variables and Parameters](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html)：变量赋值、导出、命令环境和 PATH 相关的可移植语义。
- [The Open Group `command`](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/command.html)：`command -v/-V` 的规范语义。
- [The Open Group `env`](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/env.html)：以修改后的环境调用工具的规范语义。
- [zsh Parameters](https://zsh.sourceforge.io/Doc/Release/Parameters.html)：zsh 参数、环境与特殊参数的实现说明。
- [zsh Shell Builtin Commands](https://zsh.sourceforge.io/Doc/Release/Shell-Builtin-Commands.html)：`export`、`typeset`、`type`、`whence` 等内建行为。
- [zsh Command Execution](https://zsh.sourceforge.io/Doc/Release/Command-Execution.html)：zsh 命令查找与执行顺序。
- [Oracle JDK 25 `java` Command](https://docs.oracle.com/en/java/javase/25/docs/specs/man/java.html)：Java 启动器、选项与运行入口的官方说明。
- [Oracle《Installation of the JDK on macOS》](https://docs.oracle.com/en/java/javase/25/install/installation-jdk-macos.html)：macOS JDK 安装与目录的官方说明。
- [Apache Maven《Installing Apache Maven》](https://maven.apache.org/install.html)：Maven 的 Java 前置条件、安装和 `mvn -v` 验证入口。
- [Apache Maven 3.9.16 Reference](https://maven.apache.org/ref/3.9.16/)：本课程固定 Maven 版本的启动脚本与参考文档入口。

Apple 文档描述 Terminal 用户界面与 macOS 环境，POSIX 描述可移植语义，zsh 文档描述本章实际 Shell，Oracle 与 Maven 文档只支持各自工具事实。具体 Homebrew、NVM、SDKMAN、pyenv、IDE 和企业包装器规则没有在本章验证，必须查各自一手文档与实际启动入口。

## 本章明确不做

- 不安装、卸载、升级或迁移 JDK、Maven、Node、Python、Flutter 与任何版本管理器；
- 不修改 `.zshrc`、`.zprofile`、系统默认 Shell、全局 PATH、Homebrew 链接或 IDE 设置；
- 不把某个 Maven 启动脚本行为外推为所有平台、包装器和 IDE Runner 的统一规则；
- 不教授 Maven 生命周期、依赖解析、Toolchains、Java 编译和项目构建；
- 不打印或上传完整环境，不把令牌、代理凭据、用户名和私人路径写入教材证据；
- 不把绝对路径、版本号或一次命令成功单独当作完整来源证明；
- 不把固定模拟器 PASS、重启终端或 AI 给出的配置当作独立掌握。

后续编辑器与项目导航章节会把“启动入口和工作目录”落到 IDE；依赖、构建与包管理章节会继续解释 Maven、pnpm 与 uv 如何消费环境和项目配置。本章只负责最底层的进程环境与工具解析模型。
