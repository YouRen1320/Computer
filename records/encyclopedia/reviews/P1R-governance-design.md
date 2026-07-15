# P1R 跨全书自动化治理与生成设计

- 设计日期：2026-07-16
- 设计范围：扩充后全书的规范输入、目录生成、能力治理、路线生成、稳定 ID 与一次性迁移
- 设计状态：方案，不代表已经实施
- 推荐结论：采用“模块化规范输入 + 确定性编译器 + 语义稳定 ID + 一次性破坏迁移”

## 1. 当前状态与问题

当前实现已经具备 DAG、能力首用、四条路线、G0—G8、placeholder 和发布构建校验，但仍有三个根本问题：

1. ID `vXX.cNN.slug` 同时携带卷号和顺序，插章、重排或移卷必然改变 ID。
2. 关键语义大量硬编码在 `curriculum/validate_catalog.rb`，包括固定章节数范围、五条特殊依赖、固定卷门禁和特定章节 ID。
3. `sources/mappings.csv` 有 9,174 行，其中 8,361 行含章节 ID，不能靠人工搜索替换安全迁移。

当前 30 项左右的 capability 分布也不均衡：工具和框架有能力编号，Java、JavaScript、Python 等基础语法却大量没有。这使 capability 图可以静态通过，却无法识别“输入校验先于变量和条件”“Set/Map 契约先于集合”等真实教学前置。

章节数目标不应继续硬编码在 Ruby 中。无论最终版本选择 190—220 还是后续调整到 230—260，都应由 edition policy 配置，验证器只执行配置。

## 2. 架构选择

| 方案 | 实施成本 | 迁移成本 | 风险 | 回滚难度 | 长期维护 | 建议 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| 继续手工维护单一 `catalog.yml`、routes、README | 低 | 低 | 高 | 低 | 差 | 不推荐 |
| 分卷规范输入，统一生成 catalog/routes/README/placeholders | 中 | 中 | 低 | 中 | 好 | **推荐** |
| 数据库或自定义课程 DSL | 高 | 高 | 中 | 高 | 中 | 当前过度设计 |

推荐方案把文件分成规范输入和确定性生成物两类。

### 2.1 规范输入

```text
curriculum/
  edition.yml
  volumes.yml
  capabilities.yml
  topics.yml
  chapters/
    volume-00.yml
    ...
    volume-15.yml
  route-plans/
    accelerated-48.yml
    factorycare-project.yml
    gates.yml
  migrations/
    2026.1-to-2026.2.yml
  id-registry.yml
```

### 2.2 确定性生成物

```text
curriculum/catalog.yml
curriculum/routes/zero-base.yml
curriculum/routes/accelerated-48.yml
curriculum/routes/factorycare-project.yml
curriculum/routes/reference.yml
curriculum/gates.yml
curriculum/concept-graph.md
book/volume-*/README.md
planned chapter placeholders
site/generated/*
```

`catalog.yml` 保留为工具消费接口，但加入 `generated: true`，不再手工编辑。四条路线、gates、concept graph、卷 README 和 planned placeholders 均从同一规范输入派生。

## 3. 语义稳定 ID

### 3.1 ID 形式

采用：

```text
ch.<domain>.<semantic-slug>
```

示例：

```text
ch.foundation.http-messages
ch.java.values-types
ch.java.console-input-validation
ch.vue.template-directives
ch.flutter.widget-foundations
ch.math.algebra-functions
ch.ai.rag-evaluation
```

建议 schema regex：

```regex
^ch\.[a-z0-9]+(?:-[a-z0-9]+)*\.[a-z0-9]+(?:-[a-z0-9]+)*$
```

### 3.2 ID 治理规则

- ID 不含卷号、章序、软件版本或发布时间。
- `volume`、`order`、`path` 是独立属性。
- 标题改名、卷内重排、跨卷移动都不改 ID。
- 语义拆分、合并或实质改写必须创建新 ID。
- 已退休 ID 永不复用。
- `id-registry.yml` 记录 `introduced_in`、`status: active|retired`、退休迁移项。
- 迁移完成后不提供旧 ID alias、redirect、shadow placeholder 或双写路线。
- 历史 ID 只允许出现在 migration ledger 和冻结历史审计记录中。

所有 schema、artifact 路径正则、route 外键、front matter、source mappings 和构建脚本都必须统一改用新格式。

## 4. Capability 与 Topic 的职责边界

capability 表示“读者已经能独立使用、修改、测试和诊断的一组稳定能力”，不是标题关键词。更细的术语由 `topics.yml` 管理。

- capability：跨章节复用的可验证能力；初稿估计约 80 项，语义拆分审计后由 `capabilities.yml` 冻结为 94 项，后续不得在验证器中硬编码。
- topic：标题和正文中的细粒度知识点，例如 `while`、`EOF`、`BigDecimal`、`watchEffect`，数量可以明显多于 capability。
- capability 负责跨章先教后用。
- topic 负责标题/outcome 覆盖、单一职责和章节内先后关系。

## 5. Capability taxonomy：当前 edition 冻结为 94 项

### 5.1 基础能力 10 项

1. `foundation.learning-evidence`
2. `foundation.os-process-memory`
3. `foundation.files-path-encoding`
4. `foundation.shell-command-stream`
5. `foundation.toolchain-env-build`
6. `foundation.verification-debug-test`
7. `foundation.git-security`
8. `foundation.network-transport`
9. `foundation.http-message`
10. `foundation.docker-runtime`

### 5.2 Java 13 项

11. `java.platform-entry`
12. `java.values-types-string`
13. `java.control-flow`
14. `java.arrays`
15. `java.methods`
16. `java.references-objects`
17. `java.encapsulation-immutability`
18. `java.inheritance-polymorphism`
19. `java.exceptions-resources`
20. `java.collections-generics`
21. `java.io-json`
22. `java.concurrency-runtime`
23. `java.build-testing`

反射、Lambda、Stream、JFR 等先保留为 topic；只有确实被多个后续章节独立复用时再提升为 capability。

### 5.3 数据、后端、安全与架构 18 项

24. `data.relational-schema`
25. `data.sql-query`
26. `data.sql-aggregate-join`
27. `data.transactions-locks`
28. `data.index-plan`
29. `data.persistence-access`
30. `data.schema-migration`
31. `backend.servlet-request`
32. `backend.spring-di-config`
33. `backend.spring-mvc-contract`
34. `backend.spring-persistence-tx`
35. `security.authentication`
36. `security.web-threat`
37. `security.authorization-tenancy`
38. `architecture.domain-invariants`
39. `architecture.idempotency-consistency`
40. `architecture.events-outbox`
41. `architecture.observability`

### 5.4 Web 前端 13 项

42. `web.browser-origin-render`
43. `web.html-semantic-form`
44. `web.accessibility`
45. `web.css-layout-system`
46. `web.javascript-language`
47. `web.javascript-objects`
48. `web.javascript-dom`
49. `web.javascript-async-network`
50. `web.typescript-types`
51. `web.vue-template`
52. `web.vue-reactivity-lifecycle`
53. `web.vue-components-state-router`
54. `web.frontend-testing`

### 5.5 移动端 7 项

55. `mobile.miniprogram-runtime`
56. `mobile.uniapp-platform`
57. `mobile.permissions-offline`
58. `mobile.dart-language`
59. `mobile.dart-async`
60. `mobile.flutter-tooling-widget`
61. `mobile.flutter-layout-lifecycle`

Flutter 网络和测试复用通用 HTTP、异步、权限和测试能力，不另建含义重复的顶层 capability。

### 5.6 Python、数学与机器学习 11 项

62. `python.language`
63. `python.io-errors`
64. `python.typing-oop`
65. `python.async-testing`
66. `data.numpy-pandas`
67. `math.algebra-functions`
68. `math.linear-calculus`
69. `math.probability-statistics`
70. `ml.problem-classical-evaluation`
71. `ml.neural-pytorch`
72. `ml.training-inference`

FastAPI 是框架 topic。除非后续多个章节确实依赖其独立能力，否则不应成为调用模型 API 的硬前置。

### 5.7 AI 5 项

73. `ai.llm-model-api`
74. `ai.structured-tool-calling`
75. `ai.rag-ingestion-retrieval`
76. `ai.rag-evaluation-security`
77. `ai.agent-graph-mcp`

### 5.8 生产化 3 项

78. `ops.linux-service-network`
79. `ops.container-proxy-delivery`
80. `ops.recovery-deployment`

供应链复用 Git、安全、构建和容器能力；可观测性复用 `architecture.observability`。

## 6. 教师章与使用规则

每项 capability 在 `capabilities.yml` 中必须有：

```yaml
id: java.control-flow
title: Java 控制流
teacher_chapter_id: ch.java.control-flow
requires:
  - java.values-types-string
threshold: 能独立实现、测试和解释分支与循环边界
evidence_kinds:
  - prediction
  - runnable-code
  - failure-diagnosis
required_topic_ids:
  - java.if
  - java.switch
  - java.for
  - java.while
```

教师和使用规则：

1. 每项 capability 恰好一个教师章。
2. 教师章最多正式教授 2 项新 capability。
3. `capabilities.uses` 中每项能力的教师章必须在硬前置闭包内。
4. 教师章可以在本章内使用自己刚教授的能力。
5. 仅提及术语不需要能力；要求独立修改、解释、测试或诊断时必须登记使用。
6. 教师章之前允许暂借样板，但必须显式声明 `borrowed_scaffolds`。
7. 暂借内容只能 copy/run，不能进入解释、修改、测试或诊断 outcome。
8. 能力豁免只豁免教学时间，不豁免证据。
9. final/leaf capability 暂时没有后续使用可以 warning；被使用却无教师章必须 error。

暂借样板示例：

```yaml
borrowed_scaffolds:
  - topic: java.main-signature
    later_teacher_chapter_id: ch.java.program-structure
    allowed_action: copy-run-only
```

能力之外，每章维护：

```yaml
topic_groups:
  - id: java-loop-control
    topics: [for, while, break, continue]
topics_taught: [...]
topics_used: [...]
```

这样把 capability 总量控制在当前 edition 的 94 项，同时避免“一个大能力包住十个尚未教授概念”。数量由注册表声明并与实际条目交叉校验，而不是作为跨 edition 常量。

## 7. Chapter schema v2

建议把纯字符串 outcomes 改成结构化对象：

```yaml
id: ch.java.console-input-validation
title: 控制台输入、EOF 与合法性校验
volume: "01"
order: 9
role: concept
topic_groups:
  - input-validation
prerequisites:
  - ch.java.control-flow
  - ch.java.arrays-arguments
prerequisite_rationales:
  ch.java.control-flow:
    capabilities: [java.control-flow]
    outcome_ids: [build, diagnose]
capabilities:
  teaches: []
  uses:
    - java.control-flow
    - java.arrays
outcomes:
  - id: explain
    kind: concept
    text: ...
    covers_topics: [...]
  - id: build
    kind: independent-build
    text: ...
    uses_capabilities: [...]
    evidence_kind: runnable-code
  - id: diagnose
    kind: fault-diagnosis
    text: ...
    uses_capabilities: [...]
    evidence_kind: failing-and-passing-test
```

新增字段：

- `role`: `foundation|concept|practice|synthesis|review|project|reference`
- `topic_groups`
- `topics_taught`
- `topics_used`
- `prerequisite_rationales`
- `borrowed_scaffolds`
- 结构化 `outcomes`

`path`、`route_tags` 和连续 `order` 应由生成器派生，不作为重复手工事实源。分卷章节文件中的列表顺序可以成为卷内 order 的规范来源。

## 8. Validator 新增的语义断言

### 8.1 零基础先教后用

- 零基础路线每次独立使用 capability 前，教师章必须已经出现。
- topic 的独立使用也必须有此前教师章或合法 `borrowed_scaffold`。
- `borrowed_scaffold` 只能 copy/run，不能解释、修改、测试或诊断。
- 零基础路线不允许隐式 waiver。
- 教师章顺序必须满足 capability 自身的 `requires`。
- 同章教学只允许 outcome 顺序为先解释/建模，再独立使用和诊断。

### 8.2 标题与 outcome 覆盖

- 标题中的规范 topic 必须出现在 `topic_groups`。
- 每个 `topic_group` 至少由一个 outcome 覆盖。
- `capabilities.teaches` 必须同时由独立 build 与 diagnose outcome 证明。
- ID/标题声称的主题不能只存在于 slug。
- “标题含 JUnit，outcomes 只写数组”必须报错。
- 术语别名来自 `topics.yml`，不靠临时字符串特判。

### 8.3 测试术语层级

定义五个验证层级：

- T0：手算、观察输出、命令退出码。
- T1：测试预言、断言、成功/失败用例。
- T2：语言单元测试框架。
- T3：Mock、集成测试、Testcontainers、浏览器/设备测试。
- T4：系统、性能、安全、恢复测试。

断言：

- T1 教师章前，outcome 不得要求断言、单元测试或失败测试。
- JUnit 必须依赖 `java.build-testing`。
- Vitest/Playwright 必须依赖 `web.frontend-testing`。
- pytest/fixture 必须依赖 `python.async-testing`。
- Mock、集成、容器测试不得出现在只有 T1 的章节。
- 每个 outcome 显式声明 `test_level` 或 `verification_mode`，避免“测试”一词含义漂移。

### 8.4 单一职责和最大主题数

普通章节：

- `topic_groups` 最多 2 个。
- 新授 capability 最多 2 项。
- 标题识别出的一级主题最多 3 个。
- 独立使用 capability 建议最多 8 项。
- 每个 outcome 必须映射到 topic group。

`synthesis|review|project`：

- 最多 4 个 topic group。
- 可以作为集成 capability 的唯一教师章，但仍受“每章最多 2 项新 capability”和唯一教师约束；这避免为跨域综合能力制造永久例外。
- 必须声明为何属于综合章节。

合法例外必须有：

```yaml
scope_exception:
  reason: ...
  reviewer: ...
  expires_in_edition: ...
```

禁止无期限 blanket exception。

### 8.5 硬依赖充分性和最小性

- 每条硬边必须在 `prerequisite_rationales` 中说明支撑哪个 capability、topic 或 outcome。
- 如果一条直接边的全部能力已由另一前置的祖先提供，报 redundant-edge warning。
- 如果 outcome 使用的能力没有任何硬边提供，报 missing-semantic-prerequisite error。
- 不再维护 `critical_edges` Ruby 哈希。
- 卷内上一章不能自动等于硬前置。
- `recommended_after` 不得被当成能力授权。
- 依赖图无环只是最低要求，不能替代语义充分性。

### 8.6 稳定 ID 与迁移

- ID 必须匹配新 regex，且不得含 `vXX`、`cNN` 或版本号。
- active ID 必须存在于 `id-registry.yml`。
- retired ID 不得重新出现。
- 删除或新增 ID 必须有本版 migration entry。
- ID 语义指纹发生实质变化时要求 `replace` 或人工确认。
- volume/order 改变不得要求 ID 改变。

### 8.7 生成物一致性

- `catalog.yml`、四条 routes、gates、concept graph、README 必须与生成结果字节一致。
- planned placeholder 与 catalog 一一对应。
- generator 只可创建 planned placeholder，不能覆盖 drafting/review/verified 正文。
- 非 planned 章节不得保留 placeholder 声明。
- front matter 必须与生成 catalog 一致。
- reference index 必须精确覆盖 active chapter IDs。

### 8.8 Source mappings

- 所有已有 `chapter_ids` 必须指向 active 新 ID。
- 一对一迁移可以自动替换。
- split 不能把旧映射盲目复制到所有子章；必须提供 section override，或降级为 `manual-review-required`。
- merge 可以自动去重，但必须保留来源 section provenance。
- broad-volume、heuristic-low 映射可以依据新卷内容重新生成候选，但不能自动升级 review 状态。
- 旧 ID 只允许出现在 migration ledger 和冻结历史评审中。

### 8.9 验证器自身

每条新断言至少有：

- 一个正 fixture。
- 一个精确触发该断言的负 fixture。
- 一个合法例外 fixture。

验证器不得只有“真实 catalog 当前通过”的自证测试。

## 9. 确定性生成流程

建议命令：

```text
ruby scripts/generate-curriculum.rb --plan
ruby scripts/generate-curriculum.rb --check
ruby scripts/generate-curriculum.rb --write
```

生成过程：

1. 严格读取 YAML，拒绝重复 key。
2. 校验 edition、volume、capability、topic、chapter 和 migration schema。
3. 校验 ID registry 与迁移账本。
4. 建立章节 DAG、capability DAG、topic 首用图。
5. 生成连续 volume/order 和路径。
6. 编译 catalog。
7. 生成零基础路线。
8. 展开 48 模块和 FactoryCare 支撑闭包。
9. 生成 gates、reference index、concept graph 和 README。
10. 为新 planned 章节生成 placeholder。
11. 在临时目录生成全部产物。
12. `--check` 做字节比较；`--write` 原子替换。
13. 运行 strict validator 和全部正反 fixtures。

现有 `scripts/build-book.rb` 继续负责发布产物；其 manifest 输入需加入 edition、capabilities、topics、分卷章节、route plans 和 migration ledger。

## 10. README、placeholder 与路径

### 10.1 README

- 卷标题来自 `volumes.yml`。
- 章节列表、顺序、状态和链接完全生成。
- 不允许手工插入章节列表。
- 当前 edition 不读取或嵌入 `INTRO.md`；需要卷导言时，必须先把它加入 canonical input 快照、严格校验和确定性渲染契约。

### 10.2 Placeholder

- 只对 `status: planned` 且文件不存在的章节创建。
- 文件带生成标记和规范输入 digest。
- 文件存在且无生成标记时，generator 不覆盖并报冲突。
- 章节转为 drafting 时必须先移除 placeholder 声明。
- generator 必须使用 staging 和原子替换，失败时不留下半套目录。

### 10.3 路径

```text
book/volume-01-java-language/chapters/ch.java.values-types.md
examples/encyclopedia/ch.java.values-types/
labs/encyclopedia/ch.java.values-types/
exercises/encyclopedia/ch.java.values-types/
solutions-private/encyclopedia/ch.java.values-types/
```

移动卷时正文路径可能变化，但所有语义引用依靠 ID，不依靠路径。

## 11. Source mappings 迁移和生成

`sources/mappings.csv` 的 section 决策是规范来源，不能重新从标题猜测后覆盖人工结果。建议区分两层：

- `sources/mappings.csv`：保留 section、来源 hash、review 状态和语义处置决定。
- 生成的 resolved mapping：将稳定 topic/capability 映射解析为当前 active chapter IDs。

迁移规则：

1. `preserve|replace` 一对一项可以自动替换 chapter ID。
2. `split|repartition` 必须有 section-level override；没有时标为 `manual-review-required` 并阻断最终迁移。
3. `merge` 自动去重目标 ID，但保留所有原 section provenance。
4. broad-volume、heuristic-low 项可以重新生成候选全集，但 review 状态仍为 unreviewed。
5. source inventory 中基于标题 selector 的规则应改为先映射稳定 topic，再由 topic registry 解析教师/实践章节，避免标题改名导致漂移。
6. 生成器必须报告每种迁移动作影响的 mapping 行数。

## 12. 48 模块生成规则

48 模块不能按章节数机械均分。route plan 手工定义模块能力目标，生成器展开章节。

模块规范输入：

```yaml
id: m07
required_capabilities:
  - java.control-flow
  - java.arrays
anchor_chapter_ids:
  - ch.java.control-flow
  - ch.java.arrays
diagnostic_policy: ...
waiver_policy: evidence-only
```

生成规则：

1. anchor 章节是模块 primary ownership。
2. 每个 active 章节在 accelerated route 中恰好有一个 owning module。
3. prerequisite closure 自动加入 `support`，support 可以跨模块重复。
4. 按零基础拓扑序排列模块内章节。
5. 章节角色只能是 `teach|practice|diagnose|refresh|support`。
6. capability 尚未被前序模块授予时，其教师章必须是 `teach`。
7. 只有诊断证据覆盖 explain/build/debug 三类证据时，教师章才能转为 `diagnose`。
8. waiver 只跳过教学，不授予未经验证的能力。
9. 每模块至少包含一个 build、一个故障诊断和一个 teach-back。
10. 建议每模块 3—7 个 primary 章节；支撑闭包不用于凑数。
11. 48 是能力模块数，不绑定日历周。
12. stage gate 依据 capability 集合和 artifacts 生成，不再依据固定卷号展开。
13. 模块拆分或章节扩充不改变 `m01`—`m48` 的业务/能力身份，只重新生成其 chapter ownership。

## 13. FactoryCare 路线生成规则

保留八个业务阶段：

1. foundation
2. users
3. devices
4. work-orders
5. SLA/events
6. multi-client
7. AI
8. deploy

每阶段规范输入只维护：

- 业务交付物。
- required capability IDs。
- primary anchor chapter IDs。
- 必须通过的负向场景。
- artifact 和 gate 合同。

生成器负责：

- 加入全部硬前置作为 supporting chapters。
- 检查 supporting closure 在当前或此前阶段可用。
- primary chapter 在八阶段中最多归属一次。
- supporting chapter 可以复用。
- 阶段内教师章必须排在使用章之前。
- route 保持 selective，不能退化为复制全书。
- 用户、设备、工单、状态、事件、租户、客户端、AI 和部署合同必须各有运行证据。
- 认证、越权、幂等、重复消息、离线重放、跨端字段漂移和恢复失败必须有负向测试。
- `route_tags` 从路线所有权反向派生，不再手工维护。

## 14. 旧 170 ID 迁移账本

建议账本结构：

```yaml
migration_id: catalog-2026.1-to-semantic-id-v2
compatibility: none
entries:
  - from:
      - v01.c03.console-io
    action: split
    to:
      - ch.java.console-output-arguments
      - ch.java.console-input-validation
    reason: 原章节提前使用变量、条件、数组和异常
    source_mapping_policy: manual-section-override

  - from:
      - v05.c08.services-transactions-aop
      - v05.c09.mybatis-integration
    action: repartition
    to:
      - ch.spring.mybatis-integration
      - ch.spring.service-transactions
    source_mapping_policy: manual-section-override

  - from:
      - v15.c03.docker-compose
    action: replace
    to:
      - ch.ops.compose-production
    source_mapping_policy: automatic-one-to-one
```

允许动作：

- `preserve`：语义相同，一对一换稳定 ID。
- `replace`：语义重写，一对一新 ID。
- `split`：一个旧章拆成多个新章。
- `merge`：多个旧章合并为一个新章。
- `repartition`：多个旧章重新分配为多个新章。
- `remove`：删除且无替代。
- `new`：全新章节，无旧来源。

账本断言：

- 170 个旧 ID 每个恰好出现一次。
- 每个新 ID要么由迁移项产生，要么有 `action: new`。
- split/repartition 必须使用真实逐 section 人工 override，或引用冻结来源全量重建证据；章节级迁移边不能冒充 section 已复核。
- merge target 不得被其他非 merge 项占用。
- 无环、无孤儿、无 ID 复用。
- active canonical 文件中不能残留旧 ID。
- 历史 records 可以保留旧 ID，但不得被运行时解析为有效章节。

## 15. 无兼容迁移执行顺序

1. 创建迁移前 tag 和完整生成快照。
2. 冻结新章节清单和 edition 声明的 94 项 capability registry。
3. 完成全部 170 ID 的迁移账本。
4. `--plan` 输出新增、删除、移动、split/merge 和 source mapping 影响。
5. 先验证账本覆盖，不写文件。
6. 在 staging 中生成新 catalog、routes、gates、README 和 placeholders。
7. 对 9,174 行 source mappings 执行规则化迁移；split/repartition 未决项必须阻断。
8. 删除旧 active placeholders 和旧 artifact 目录，不创建 redirect。
9. 原子替换生成物。
10. 运行 schema、语义 validator、route validator、source FK、build check 和负 fixtures。
11. 输出迁移报告、新输入摘要和所有未决人工映射。

回滚只通过迁移前 tag/分支恢复整个版本，不维护双 ID 运行时。

兼容性结论：**不保留任何运行时向后兼容折中**。旧 ID 只保留在迁移账本与冻结历史审计记录中。

## 16. 完成标准

治理改造只有同时满足以下条件才算完成：

1. 所有 active 章节使用语义稳定 ID。
2. edition 声明的 94 项 capability 均有唯一教师章和证据阈值。
3. 零基础路线不存在教师章之前的独立使用。
4. 标题、topic groups、outcomes 和 capability 之间完全可追溯。
5. 普通章节通过单一职责和最大主题数断言。
6. 48 模块与 FactoryCare 路线由策略和依赖闭包确定性生成。
7. 170 个旧 ID 的迁移账本覆盖率为 100%。
8. 所有 source mapping 外键均指向 active 新 ID，split/repartition 无未决自动扩散。
9. catalog、routes、gates、README、placeholders 和站点输出通过 `--check`。
10. 每项新验证规则都有正、负和合法例外 fixture。
11. 迁移后运行时不存在 legacy alias、redirect 或旧 placeholder。

## 17. 明确非目标

- 本方案不决定最终每卷精确章节数。
- 本方案不替代卷级教学设计和人工语义评审。
- capability 编号不作为正文质量或学习掌握的自动证明。
- generator 不自动改写 drafting/review/verified 正文。
- source mapping 的 split/repartition 不允许由模型或字符串替换静默决定。
- 本阶段不修改 catalog、routes、book、source mappings 或 `PROGRESS.md`。
