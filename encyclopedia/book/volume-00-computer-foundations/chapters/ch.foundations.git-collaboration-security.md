---
schema_version: 2
edition: 2026.2-draft
id: ch.foundations.git-collaboration-security
title: Git 状态模型、远程协作、冲突与凭据处置
responsibility: 教授可回滚的版本协作与泄露凭据处置，不把忽略文件误当成删除历史或撤销泄露
volume: '00'
order: 8
level: L1
status: drafting
path: book/volume-00-computer-foundations/chapters/ch.foundations.git-collaboration-security.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.cli-streams-exit-codes
version_surfaces:
- git
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释Git 状态模型、远程协作、冲突与凭据处置的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - git-state
  - git-security
  covers_topics:
  - git.working-index-commit
  - git.branch-remote
  - git.merge-conflict
  - git.ignore-tracking
  - git.secret-rotation
  - git.history-rewrite-risk
  uses_capabilities:
  - foundation.files-path-encoding
  - foundation.shell-command-stream
  - foundation.git-security
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 在一次性仓库演示 working tree→index→commit→branch→merge，并模拟先跟踪后忽略配置文件及假 Token 轮换处置
  covers_topic_groups:
  - git-state
  - git-security
  covers_topics:
  - git.working-index-commit
  - git.branch-remote
  - git.merge-conflict
  - git.ignore-tracking
  - git.secret-rotation
  - git.history-rewrite-risk
  uses_capabilities:
  - foundation.files-path-encoding
  - foundation.shell-command-stream
  - foundation.git-security
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入 .gitignore 不能取消已跟踪文件和合并冲突误覆盖两类故障，分别用状态/历史证据恢复
  covers_topic_groups:
  - git-state
  - git-security
  covers_topics:
  - git.working-index-commit
  - git.branch-remote
  - git.merge-conflict
  - git.ignore-tracking
  - git.secret-rotation
  - git.history-rewrite-risk
  uses_capabilities:
  - foundation.files-path-encoding
  - foundation.shell-command-stream
  - foundation.git-security
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# Git 状态模型、远程协作、冲突与凭据处置

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《stdin、stdout、stderr、管道与退出码》](ch.foundations.cli-streams-exit-codes.md)：独立完成Git 状态与协作、历史与凭据安全前，必须先具备「stdin、stdout、stderr、管道与退出码」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

Git 最容易被误学成一串咒语：改完执行 `add`、`commit`、`push`，出错就复制网络答案。这样在单人小练习里可能暂时工作，一旦多人同时修改、`.gitignore` 加晚了、合并发生冲突或 Token 被提交，命令记忆就无法回答最关键的问题：文件现在在哪个状态？下一次提交会包含什么？删除工作区文件会不会删除历史？本地成功是否已经影响远端？秘密已经暴露时为什么必须先轮换？

本章用状态模型代替命令背诵。你将区分工作树、暂存区、当前提交与对象历史，观察文件如何在这些边界间变化；理解分支是可移动引用，合并是整合两条历史而不是“把文件夹覆盖过去”；认识远端名称、远端跟踪引用和发布动作的边界；用 `.gitignore` 与 `git rm --cached` 的对照证明“未来忽略”不等于“取消既有跟踪”；最后建立凭据泄露的正确处置顺序：先撤销或轮换，再控制传播、清理当前版本，必要时协调历史重写。

所有配套 Git 命令只在验证器新建的一次性临时仓库中运行，固定作者、时间、配置和无效教学占位符，不访问网络、不添加远端、不读取个人全局 Git 配置，也绝不要求真实 Token。请不要把正文命令直接套到当前教材仓库。Git 可以恢复很多版本错误，却不能撤销已经被他人读取的秘密，也不能替你决定冲突双方的业务含义。

本章只讲日常基础协作。不会展开交互式 rebase、复杂 cherry-pick、子模块、签名提交、大规模历史过滤或强制推送策略。历史重写属于高风险协调任务，本章只解释风险、响应边界和何时升级处理。

## 学完后你必须能做什么

完成正文与实验后，你应当能够：

1. 用自己的话区分工作树、暂存区、HEAD 提交、对象数据库和分支引用；
2. 在执行前预测 `git status`、`git diff`、`git diff --cached` 分别会显示什么；
3. 解释 `git add` 是把当前内容写入暂存区，不是“通知 Git 我改完了”；
4. 用小而完整的提交保存一个可解释快照，提交前核对暂存差异；
5. 使用 `status`、`diff`、`log`、`show` 回答“现在变了什么、将提交什么、历史做了什么”；
6. 解释分支是指向提交的引用，切换分支会改变 HEAD 与工作树视图；
7. 区分快进与三方合并，读懂冲突标记，并在解决前保留双方业务意图；
8. 使用 `git status` 识别未合并路径，解决后以 `add` 标记冲突已处理并验证合并结果；
9. 区分 remote、远端跟踪引用与本地分支，说明 fetch、merge、pull、push 的边界；
10. 说明 `.gitignore` 只影响未跟踪候选，不能自动取消已经跟踪的文件；
11. 在确认路径和差异后，使用 `git rm --cached -- <path>` 让下一次提交停止跟踪、同时保留工作树文件；
12. 解释取消跟踪或删除提交为何不能抹掉旧历史，更不能使已泄露凭据重新安全；
13. 遇到真实 Token、密码或私钥泄露时，第一动作是按提供方流程撤销或轮换，并记录受影响系统；
14. 在 FactoryCare 场景中安全解决一次状态规则冲突，证明没有静默丢失任一方需求；
15. 审查 AI 给出的 Git 命令，拒绝未经范围确认的强制推送、历史改写和秘密输出；
16. 在无 AI 条件下，从一段 `status`/`diff`/冲突日志定位状态并给出可回滚下一步。

掌握不是得到 `working tree clean`。干净只说明工作树和暂存区相对当前提交没有 Git 可见差异，不说明测试通过、提交内容正确、远端同步或秘密安全。每次结论都必须绑定具体状态与证据。

## 零基础模型：四层状态与一组引用

### 工作树：你当前能编辑的文件

工作树是从某个提交检出后呈现在目录里的文件，加上你尚未跟踪的新文件和修改。编辑器保存通常只改变工作树。文件能在磁盘中看到，不等于 Git 已跟踪，也不等于会进入下一次提交。

工作树还可能包含被忽略文件，例如本地缓存、构建输出或个人配置。它们存在于文件系统，但普通 `git status` 通常不会把匹配忽略规则的未跟踪文件列为候选。忽略不是加密，也不是权限控制。

### 暂存区：下一次提交的候选快照

暂存区也称 index。它记录下一次提交准备采用的文件内容和路径状态。执行 `git add path` 时，Git 把该时刻的内容放入暂存区；之后若继续编辑同一文件，暂存区仍保留较早版本，于是一个路径可以同时存在“已暂存修改”和“未暂存修改”。

这解释了为什么提交前必须看 `git diff --cached`。只看编辑器当前内容或普通 `git diff`，都可能误判下一次提交实际包含什么。

### HEAD 与当前提交：当前历史基准

提交是一个不可变快照对象，记录目录树、父提交、作者/提交者信息和消息等。HEAD 通常指向当前分支，当前分支再指向一个提交。提交后，分支引用向新提交移动，HEAD 仍通过分支指向新位置。

提交不是“把文件上传服务器”，也不是普通压缩包。它首先存在于本地仓库对象数据库。是否发布给远端是后续动作。

### 对象历史：旧内容仍可能可达

文件从新提交删除，并不意味着旧提交里的内容消失。只要历史仍可达或对象尚未清理，旧内容可能通过提交 ID、分支、标签、远端副本、fork、缓存和日志被找到。因此，秘密一旦进入提交，不能靠“再提交一个删除”恢复安全。

### 最小状态图

```text
编辑/创建
   ↓
工作树 ── git add ──> 暂存区 ── git commit ──> 新提交
   ↑                      │                         │
   └──── 恢复/切换视图 ───┴──── HEAD/分支引用 ──────┘
```

图中箭头是概念方向，不是所有命令的完整语义。删除、重命名和冲突也会表现为路径状态。操作前永远先查看当前状态与差异，不凭图猜破坏性命令。

## `git status`：状态入口而不是错误提示

官方文档把状态分成三类核心差异：index 相对 HEAD、工作树相对 index、未跟踪且未忽略的路径。长格式适合人读；`--porcelain=v1` 为脚本提供跨配置较稳定的格式。

短格式有两列状态：第一列表示 index 相对 HEAD，第二列表示工作树相对 index。常见示意：

| 输出 | 含义 |
| --- | --- |
| `?? note.txt` | 工作树有未跟踪文件 |
| ` M app.java` | 已跟踪文件在工作树修改，尚未暂存 |
| `M  app.java` | 修改已经进入暂存区，工作树与暂存区一致 |
| `MM app.java` | 暂存了一版，随后工作树又继续修改 |
| `A  app.java` | 新文件已暂存 |
| `D  app.java` | 删除已暂存 |
| `UU app.java` | 合并双方都修改，尚未解决 |

空输出通常表示相对当前 HEAD 没有可报告差异，但 ignored 文件仍可能存在。脚本不要解析面向人的彩色长格式；学习报告可以同时保留人读解释与固定 porcelain 输出。

状态观察顺序建议固定：当前分支/HEAD、短状态、未暂存差异、已暂存差异、最近提交。这样能避免“看到 modified 就直接 add 全部”。

## 三种差异：不要只说“看 diff”

### `git diff`：工作树对暂存区

普通 `git diff` 默认显示尚未暂存的变化。若你刚 `git add` 且之后没有继续编辑，它可能为空。空 diff 不代表没有改动；变化可能已经在 index。

### `git diff --cached`：暂存区对 HEAD

这才是下一次提交内容的核心预览。提交前逐项检查：路径是否正确、是否混入生成物、调试输出、个人配置或秘密、删除是否预期、编码/换行是否意外全文件变化。

### 提交后：`git show` 与 `git log`

`git log` 展示提交关系和元数据，`git show <commit>` 展示某个提交及其差异。它们回答历史发生了什么，不替代当前工作树状态。限制日志数量与格式可以减少噪声，但不要让过短输出隐藏合并父关系或目标提交。

### 一个路径的双重修改

顺序如下：

1. 把 `priority.txt` 从 `normal` 改为 `high`；
2. `git add priority.txt`；
3. 又把它改为 `urgent`。

此时 `git diff --cached` 显示 `normal→high`，普通 `git diff` 显示 `high→urgent`，状态可能是 `MM`。若直接 commit，只提交暂存区的 `high`。这个案例能验证你是否真正理解 index。

## `git add` 与提交边界

### add 记录当前内容，不会持续同步

`git add` 之后的再次编辑不会自动进入 index。提交前要重复观察，不要把 `git add .` 当作仪式。`.` 的范围取决于当前目录和路径规则，可能包含本轮无关文件。零基础阶段优先显式路径，并使用 `--` 分隔选项与路径，防止以连字符开头的路径被解释成选项。

### 提交应表达一个完整意图

一个良好基础提交应当：

- 只包含同一可解释变更；
- 不混入构建产物、临时日志和秘密；
- 在项目允许范围内通过相应验证；
- 消息说明为什么改变，而非只写“update”；
- 提交前后都有状态与差异证据。

小提交不是把每行拆开，而是让审查、回滚与冲突定位有清晰边界。是否提交由任务授权决定；在教学仓库中，不要因为练习说明出现 commit 就自动提交主仓。

### 撤销不是一个万能命令

工作树、index、提交历史处于不同层，因此撤销也必须先说明目标：放弃未暂存修改、取消暂存但保留工作树、创建反向提交，还是协调修改公开历史。本章不提供一条“全部恢复”命令，因为错误层级会丢数据。先 `status` 和 diff，备份重要未提交内容，再选具体动作。

## 分支：可移动引用，不是第二份完整目录

分支通常是指向提交的轻量引用。创建分支时不会复制整套项目；在该分支提交会让引用向新提交移动。切换分支时，Git 调整 HEAD 并更新工作树以匹配目标提交，同时会保护可能被覆盖的未提交修改，或要求先处理。

可画成：

```text
A---B  main
     \
      C---D  feature/status-label
```

main 指向 B，feature 指向 D。两者共享 A、B 历史。分支名称不是提交内容，删除分支引用也不等于立刻擦除所有对象。

### 分支前后的安全检查

切换或合并前：

1. 确认当前分支与目标分支；
2. 查看工作树和 index 是否干净，若不干净说明如何保护；
3. 查看双方最近提交与差异范围；
4. 确认没有真实秘密或本地配置待提交；
5. 说明失败时采用 abort、恢复分支还是重新尝试。

不要在不理解状态时为了“让 switch 成功”随手丢弃修改。

## 合并：整合历史，不是文件覆盖

### 快进与三方合并

如果当前分支没有新提交，目标分支直接在其后，Git 可以把当前引用快进到目标，无需新合并提交。如果双方从共同祖先后都产生提交，Git 需要比较共同祖先、当前分支和目标分支，进行三方合并。

无冲突不等于业务正确。两边修改不同文件可以自动合并，却可能在业务上不兼容；仍需测试和审查。

### 冲突表示 Git 无法安全替你决定

双方修改同一片段时，工作树中可能出现：

```text
  <<<<<<< HEAD
priority=urgent
  =======
priority=high
  >>>>>>> feature/rule
```

这些标记展示当前侧与合入侧候选，不是最终答案。解决冲突不能机械选择“ours”或“theirs”，要读取双方提交意图、需求与测试，编辑成业务上正确的最终内容，删除标记，然后 `git add` 表示该路径已解决。最后再次检查 `status`、暂存 diff 和测试。

### 安全解决流程

1. 保存合并前的分支与提交 ID；
2. 执行合并并保留原始非零状态和诊断；
3. 用 `git status` 列出所有未合并路径；
4. 对每个文件查看共同上下文与双方意图；
5. 编辑最终结果，不静默丢掉任一有效规则；
6. 搜索残留冲突标记；
7. `git add -- <path>` 标记已解决；
8. 查看 `git diff --cached`；
9. 运行与两侧需求有关的验证；
10. 完成合并提交，或在无法决定时中止并升级需求决策。

`git merge --abort` 可在合并失败后尝试恢复合并前状态，但官方文档也提醒：若开始合并时已有复杂未提交修改，恢复可能不完美。最可靠的预防是合并前明确并保护工作状态。

## 远端协作：本章只建立边界

### remote 是本地保存的远端别名与配置

`origin` 只是常见名称，不是 Git 的特殊云端。remote 配置包含获取与发布地址；地址可能含敏感信息，报告时应脱敏。远端本身可以是托管服务、服务器或另一个仓库。

### 远端跟踪引用不是实时网络状态

`origin/main` 是本地记录的远端分支观察值，通常由 fetch 更新。它不会在别人推送时自动实时变化。看到本地 `origin/main` 只能说明上一次成功获取后的认知。

### fetch、merge、pull 与 push

- `fetch` 获取远端对象并更新远端跟踪引用，通常不直接整合到当前分支；
- `merge` 把指定历史整合进当前分支；
- `pull` 是获取再整合的组合操作，具体整合策略受配置影响；
- `push` 尝试把本地引用更新发布到远端，可能因权限或非快进被拒绝。

因此，“pull 失败”要拆成获取失败还是整合失败；“commit 成功”不代表 push 成功；“push 成功”也不证明 CI、审查或部署成功。本章实验完全不执行这些远端动作，只用概念图和本地分支模拟整合。实际发布需在后续项目协作流程中按授权进行。

### 协作边界

多人工作时应先确认仓库政策：默认分支保护、Pull Request、审查、CI、合并策略、谁可处理冲突、是否允许 force push。未经明确授权，不修改远端历史，不把临时教学分支推到真实仓库，不把个人凭据放入 remote URL。

## `.gitignore`：只影响未跟踪候选

### 忽略不是删除，也不是取消跟踪

Git 官方文档明确指出：已经被 Git 跟踪的文件不受 `.gitignore` 规则影响。原因很直接：ignore 用于决定未跟踪文件是否应被视为候选；一个路径已经存在于 index/提交后，它不再是“尚未决定要不要跟踪”的对象。

于是以下顺序会产生常见预期失败：

1. `local.env` 已被 add 并提交；
2. 在 `.gitignore` 增加 `local.env`；
3. 修改 `local.env`；
4. `git status` 仍报告修改。

这不是缓存故障。规则没有追溯取消既有状态。

### 停止未来跟踪但保留本地文件

若团队确认该路径应改为每人本地维护，一般步骤是：

1. 先备份并确认文件用途，检查是否含秘密；
2. 添加精确 ignore 规则；
3. 使用 `git rm --cached -- local.env` 从 index 安排删除，但保留工作树文件；
4. 查看状态与 `git diff --cached`，确认下一提交是停止跟踪而非磁盘删除；
5. 提交该政策变化，并提供无秘密模板如 `local.env.example`；
6. 让协作者按迁移说明处理自己的环境。

`git rm --cached` 影响 index，不会清除旧提交。路径范围错误仍可能批量取消跟踪，所以不应在陌生仓库直接运行递归变体。先对单个固定路径演练。

### 多层 ignore 来源

规则可能来自仓库 `.gitignore`、子目录 `.gitignore`、仓库局部 exclude 和用户全局 excludes。团队必须提交的规则应放在仓库可见位置；个人工具噪声可放个人配置。诊断“为什么文件被忽略”时可用 `git check-ignore -v` 查看匹配来源，但它对已跟踪文件的普通观察需要理解选项边界。

## 凭据泄露：删除文字不是处置完成

### 什么属于秘密

个人访问令牌、云访问密钥、数据库密码、私钥、会话凭据、签名密钥和可换取访问权限的连接字符串都可能是秘密。用户名、普通公开 URL 或教学占位符不一定是秘密，但仍应按隐私和项目合同处理。

永远不要为了练习创建看起来可用的真实格式 Token。配套实验使用明确的 `TRAINING_REVOKED_PLACEHOLDER`，只存在临时仓库，不能访问任何系统。

### 处置优先级：先让秘密失效

一旦真实凭据可能离开受控边界，应假设它可能被复制。首要动作是通过凭据提供方撤销、删除或轮换，让旧值不能继续授权。之后才能安全地清理当前文件、历史、日志和缓存。若先花数小时改历史，攻击者仍可能使用旧凭据。

基础响应顺序：

1. **停止传播**：不要继续粘贴、截图、推送或把值发给 AI；
2. **撤销/轮换**：在提供方控制台或组织流程使旧凭据失效；
3. **评估范围**：仓库、分支、远端、fork、CI 日志、制品、聊天和机器缓存是否出现；
4. **更新依赖方**：用安全渠道配置新凭据，验证服务恢复；
5. **清理当前版本**：移除硬编码，改用项目认可的秘密管理方式和模板；
6. **协调历史清理**：若政策要求，交由仓库管理员按官方流程重写并通知所有协作者重新同步；
7. **审计与复盘**：查看旧凭据使用记录、启用扫描/保护、记录事件而不记录秘密值。

撤销或轮换可能让自动化暂时中断，这是安全处置的预期影响，需要同步更新 CI 和服务。不要因为担心构建失败而延迟失效旧凭据。

### 为什么新提交删除不够

当前分支最新文件不再含值，只证明新快照改变了。旧提交、其他分支、标签、远端缓存、fork 和日志可能仍保留。`.gitignore` 更不负责历史。教学验证器会精确证明：从最新提交停止跟踪 `local.env` 后，上一提交仍能显示占位符。这是受控预期失败，用来反驳“删了就安全”的直觉。

### 历史重写的风险边界

历史重写会生成新的提交 ID，影响分支、标签、签名、PR、fork 和所有已有克隆。协作者若按旧历史继续推送，可能把秘密重新带回。它也无法控制已经被下载的副本。因此本章不教你直接复制过滤命令；只有在凭据已失效、范围确认、备份与沟通完成、仓库管理员授权后，才按托管平台与 Git 官方流程执行。

## 正例、边界与预期失败

### 正例：提交前核对三层差异

修改 `work-order.txt` 后先看 `status` 与普通 diff，显式 add，再看 cached diff。若 staged 内容只包含预期状态规则，运行固定验证并提交。提交后用 show 证明快照，再确认工作树清洁。每一步回答一个具体问题。

### 边界：自动合并仍可能业务冲突

前端把状态 `ASSIGNED` 显示为“已分配”，后端把同一状态改为 `DISPATCHED`。文件不同，Git 自动合并，但 API 契约已经不一致。Git 无冲突仅表示文本合并算法无需人工选择，不表示跨文件业务一致。

### 预期失败一：ignore 已跟踪文件

添加 ignore 后，已提交的 `local.env` 修改仍出现在 status。正确诊断是 index 已跟踪，而不是规则拼写必然错误。若文件含真实秘密，先撤销/轮换，再讨论停止跟踪和历史清理。

### 预期失败二：合并双方修改同一规则

main 把 `priority=normal` 改为 `priority=urgent`，feature 改为 `priority=high`。merge 返回非零并留下 `UU`。不能用输出重定向隐藏诊断，也不能删掉一边就声称完成。需求若规定“urgent 优先且保留 high 作为回退”，最终文件应明确表达两条规则并有测试。

### 预期失败三：删除最新文件后旧历史仍可读

停止跟踪并提交以后，`git show HEAD~1:local.env` 仍能读到教学占位符。这正是历史快照的定义。对真实秘密的修复标准不是让这个命令失败，而是旧凭据已失效、范围已评估、政策要求的清理已协调完成。

## FactoryCare 场景：工单优先级冲突与配置泄露

两名开发者从共同提交开始工作：A 在 main 把紧急阈值改为 4，B 在 feature 增加“安全告警一律紧急”。两人恰好修改同一规则文件。合并冲突时，选择 A 会丢掉安全告警，选择 B 会丢掉阈值变化。正确结果需要阅读两边提交和需求，组合为：安全告警直接紧急；其他工单按阈值 4 判断，并为两条规则各保留测试。

同一仓库曾把 `factorycare-local.env` 提交，后来加入 `.gitignore`。开发者发现状态仍报告修改，说明它已被跟踪。若内容只是假教学配置，可以在临时演练中 `git rm --cached -- factorycare-local.env`、提交模板并证明旧历史仍存在。若内容是真实数据库密码或 Token，则立即停止复制并按提供方撤销/轮换；取消跟踪只是后续仓库修复的一部分。

一个完整、脱敏的事件记录可以写：

```text
credential_kind=personal-access-token
value_recorded=no
provider_revocation=completed
affected_surfaces=repository-history,ci-log
current_tree_cleanup=completed
history_cleanup=administrator-coordinating
replacement_distribution=approved-secret-store
```

不要记录原值、末尾字符、可复原哈希或含凭据的 remote URL。事件证据证明动作，不重新传播秘密。

## 预测—构建—诊断—变更训练

### 预测

给定工作树修改、add 后再次修改的顺序，先写 `status` 两列、普通 diff 与 cached diff 各包含什么。再给定双方分支图，预测快进还是三方合并；给定已提交的 `local.env`，预测加入 ignore 后的状态。

### 构建

在配套一次性仓库验证器中观察：未跟踪→暂存→提交；工作树与 index 双重修改；创建分支；合并冲突；解决并提交；已跟踪文件加入 ignore；从 index 取消跟踪且工作树保留。每轮保存命令、退出状态和精确预言。

### 注入故障并诊断

实验的 `git-evidence.txt` 初始是占位符，验证器完成临时 Git 场景后会因证据不匹配返回非零。这是预期失败。不要改验证器或追加 `|| true`，应根据 status/diff/history 填写字段。

第二个故障是冲突解决时只保留 main。验证器会检查 feature 规则丢失。恢复双方业务意图后重新 add、检查 cached diff、验证并提交。

### 需求变更

团队决定本地配置不再跟踪，并新增无秘密模板。列出 `.gitignore`、index、工作树、模板、迁移说明与旧历史各自状态；再说明若配置曾含真实凭据，还必须执行哪些 Git 之外的动作。

## 无 AI 独立训练

关闭 AI，限时 60 分钟完成：

1. 根据固定短状态解释工作树/index/HEAD；
2. 演示 add 后再编辑产生的双层差异；
3. 创建本地分支并画提交图；
4. 触发一次固定冲突，保留双方规则并验证；
5. 证明 `.gitignore` 不影响已跟踪文件；
6. 停止跟踪假配置但保留工作树副本；
7. 证明旧提交仍含教学占位符；
8. 口述真实 Token 泄露的第一动作与完整升级路径。

允许查 Git 官方命令手册，不允许打开私有解析，不允许联网添加 remote，不允许在当前教材仓库练习。验证器通过不等于会处理生产事故；你还要解释哪些动作是自动证明、哪些依赖提供方或管理员人工证据。

## 复述题与间隔复习

### 当天复述

不看正文回答：

1. 工作树、index、HEAD 和分支各是什么？
2. 为什么普通 diff 为空仍可能有待提交内容？
3. `MM` 为什么能同时出现？
4. 自动合并成功为何仍需测试？
5. `.gitignore` 为什么不能取消跟踪？
6. 秘密泄露为何先轮换再清历史？

### 第 2 天检索

画出四层状态图，并为创建、修改、暂存、再修改、提交分别标出变化。再解释 `git rm --cached` 对 index、工作树和旧提交的不同影响。

### 第 7 天迁移

阅读一个陌生但无秘密的状态输出，先不执行命令，写最小观察步骤。给出远端获取失败与本地合并失败的区别，说明 pull 为什么是组合动作。

### 第 21 天故障回放

在配套临时实验重现冲突与 ignore 失败。如果你只能记住命令，却不能预测 status/diff 与历史结果，需要回到模型重练。

## 速查表

| 要回答的问题 | 首选证据 | 不能证明 |
| --- | --- | --- |
| 当前有哪些状态 | `git status --short` | 业务正确、远端同步 |
| 工作树尚未暂存什么 | `git diff` | index 中将提交内容 |
| 下一提交包含什么 | `git diff --cached` | 测试通过 |
| 某提交做了什么 | `git show` | 当前工作树状态 |
| 最近历史关系 | `git log --graph` | 远端实时状态 |
| 文件为何忽略 | ignore 规则与 `check-ignore` | 已跟踪文件会自动取消 |
| 合并是否未解决 | status 的 unmerged 路径 | 最终业务语义正确 |
| 最新树是否删秘密 | 最新文件与 diff | 旧凭据安全、旧历史消失 |
| 凭据是否失效 | 提供方撤销/轮换证据 | 所有副本已清理 |

## 常见误区与纠正

| 误区 | 为什么错 | 可复用规则 |
| --- | --- | --- |
| add 后会持续同步 | index 是 add 当时快照 | 提交前再看 cached diff |
| commit 等于上传 | 提交先写本地历史 | push 是独立发布动作 |
| clean 表示代码正确 | 只表示 Git 差异状态 | 还需测试和审查 |
| 无文本冲突就安全 | 跨文件业务可能不兼容 | 合并后验证双方需求 |
| 冲突选一边最快 | 可能静默丢需求 | 阅读双方意图并组合 |
| ignore 会取消跟踪 | 规则针对未跟踪候选 | 需显式调整 index |
| 删除文件就删历史 | 旧提交仍是快照 | 秘密先撤销/轮换 |
| 改写历史即可收回秘密 | 副本可能已被读取 | 失效凭据并协调清理 |
| pull 是安全刷新 | 它还会整合历史 | 区分 fetch 与 merge |
| AI 给的 Git 命令可直接跑 | 范围和仓库状态未知 | 先解释影响、迁移、回滚 |

## 术语表

- **repository / 仓库**：保存 Git 对象、引用和配置的版本数据库及其工作上下文。
- **working tree / 工作树**：当前检出后可编辑的目录视图。
- **index / staging area / 暂存区**：下一次提交候选快照。
- **commit / 提交**：包含目录树、父关系和元数据的不可变历史对象。
- **HEAD**：当前检出位置，通常符号指向当前分支。
- **branch / 分支**：通常指向某个提交、随新提交移动的引用。
- **untracked / 未跟踪**：工作树存在但尚未进入 index/历史的路径。
- **ignored / 已忽略**：未跟踪候选被规则排除出普通状态提示；不是加密或删除。
- **staged / 已暂存**：路径当前内容已写入 index，准备进入下一提交。
- **diff**：两个状态或对象之间的内容差异。
- **fast-forward / 快进**：当前引用可直接向后移动到目标，无需三方合并提交。
- **merge / 合并**：整合两条历史与文件状态的操作。
- **conflict / 冲突**：Git 无法自动决定最终内容，需要人依据业务意图解决。
- **remote / 远端**：本地保存的其他仓库别名与访问配置。
- **remote-tracking reference / 远端跟踪引用**：本地对上次获取到的远端分支位置的记录。
- **fetch / 获取**：下载远端对象并更新远端跟踪引用。
- **push / 推送**：尝试将本地引用更新发布到远端。
- **credential / 凭据**：可证明身份或授予访问的秘密材料。
- **rotation / 轮换**：使旧凭据失效并安全配置新凭据。
- **history rewrite / 历史重写**：创建替代提交历史，改变提交 ID 的高风险协调操作。

## 一手资料与版本边界

本章版本面为 `git`。工作树/index/提交、引用、ignore 对已跟踪文件无效、三方合并与凭据失效优先级属于稳定核心；具体命令选项、托管平台界面和组织政策会变化。资料链接复核日期：**2026-07-16**。

- [Git `git status` 官方手册](https://git-scm.com/docs/git-status)：工作树、index、HEAD 差异与 porcelain 格式。
- [Git `git diff` 官方手册](https://git-scm.com/docs/git-diff)：不同状态和对象间的差异边界。
- [Git `git add` 官方手册](https://git-scm.com/docs/git-add)：把工作树内容加入 index 的语义。
- [Git `git commit` 官方手册](https://git-scm.com/docs/git-commit)：从 index 创建提交。
- [Git `git branch` 官方手册](https://git-scm.com/docs/git-branch)：分支引用的创建、列举与管理。
- [Git `git merge` 官方手册](https://git-scm.com/docs/git-merge)：合并、冲突与 abort 边界。
- [Git `gitignore` 官方手册](https://git-scm.com/docs/gitignore)：忽略来源、匹配规则与已跟踪文件不受影响的官方说明。
- [Git `git rm` 官方手册](https://git-scm.com/docs/git-rm)：`--cached` 对 index 与工作树的边界。
- [Git `git fetch` 官方手册](https://git-scm.com/docs/git-fetch)：远端对象与远端跟踪引用更新。
- [GitHub Docs：Revoking your credentials](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/revoking-your-credentials)：撤销、删除凭据及自动化中断影响。
- [GitHub Docs：Removing sensitive data from a repository](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)：先撤销/轮换、再协调历史清理与协作者同步的托管平台流程。

实验固定调用本机 `/usr/bin/git`，但正文不依赖 Apple Git 的特定补丁版本。实际团队必须记录 `git --version`、托管平台和分支政策；不要从本文推断组织允许历史重写或强制推送。

## 本章小结

Git 的可控性来自状态模型。工作树保存当前编辑，index 保存下一次提交候选，提交形成本地不可变快照，分支是移动引用；`status`、普通 diff、cached diff 与 show 分别回答不同问题。合并冲突是 Git 拒绝替人决定业务含义，解决后仍要证明双方需求没有丢失。`.gitignore` 只影响未跟踪候选，已跟踪文件需显式调整 index；无论取消跟踪还是新提交删除，都不会抹去旧历史。真实凭据泄露时，第一动作永远是让旧凭据失效，随后才是范围评估、当前版本清理和经过授权的历史协调。

请在配套一次性仓库完成预测、构建、受控冲突、ignore 失败与修复复跑。不要在当前教材仓库演练，不要添加远端，不要使用真实身份或凭据，也不要把验证器的预期失败改成假成功。
