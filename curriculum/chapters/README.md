# 分卷章节规范输入（Schema v2）

本目录保存 16 个分卷章节清单，是章节语义的规范输入。`catalog.yml`、路线、阶段门、概念图、卷 README 和章节元数据都必须由生成器派生，不能在多个文件中重复手工维护。

## 文件与排序

- 文件名固定为 `volume-00.yml` 至 `volume-15.yml`。
- 每个文件的顶层 `volume` 必须与文件名一致。
- `chapters` 的列表顺序就是卷内顺序；生成器据此产生连续的 `order: 1..N`。
- 章节移动或重排只修改所在文件和列表位置，不修改语义 ID。
- 每个文件使用 UTF-8、单一 YAML document，并由严格加载器拒绝重复 key、alias 和 merge key。

顶层格式：

```yaml
---
schema_version: 2
edition: 2026.2-draft
volume: "01"
chapters: []
```

## 章节字段

下列字段是每章的最终规范输入。除明确标为可选的字段外均为必填。

| 字段 | 类型 | 规则 |
| --- | --- | --- |
| `id` | string | 语义稳定 ID，匹配 `ch.<domain>.<semantic-slug>`；不得包含卷号、章序或软件版本。 |
| `title` | string | 准确描述本章职责；标题所声明的一级主题必须能由 `topic_groups` 和 outcomes 追踪。 |
| `role` | enum | `foundation\|concept\|practice\|synthesis\|review\|project\|reference`。 |
| `responsibility` | string | 一句话说明本章唯一职责和明确边界，不能只复述标题。 |
| `level` | enum | `L1\|L2\|L2+\|L3\|L1-L2`。 |
| `status` | enum | `planned\|drafting\|review\|verified`。当前正文均为 `drafting`；只有具备对应人工、独立复审和运行证据后，才可晋升为 `review` 或 `verified`。 |
| `stable_core` | boolean | 稳定原理为 `true`；以具体版本 API 为主则为 `false`。 |
| `topic_groups` | array<object> | 普通章最多 2 组；`synthesis/review/project` 最多 4 组。每组含 `id`、`title`、`topics`。 |
| `topics_taught` | array<string> | 本章正式教授、允许读者随后独立解释/修改/测试/诊断的 topic ID。 |
| `topics_used` | array<string> | 本章要求独立使用的 topic ID；必须已由硬前置教授、本章先教后用，或具有合法 borrowed scaffold。 |
| `prerequisites` | array<string> | 硬前置语义 ID；只放没有其已验证结果就无法安全完成本章的章节。 |
| `prerequisite_rationales` | map | key 必须与 `prerequisites` 完全一致；每项说明 `reason`、支撑的 capabilities/topics/outcome IDs。 |
| `capabilities` | object | 含唯一列表 `teaches` 与 `uses`；教师章最多正式教授 2 项新 capability。 |
| `borrowed_scaffolds` | array<object> | 临时借用尚未教授的样板；只允许 `copy-run-only`，不得进入解释、修改、测试或诊断 outcome。 |
| `lab_requirements` | object | 含 `required`、`artifact_paths`、`acceptance`；路径必须位于本章稳定 ID 对应的 lab 目录。 |
| `gate_requirements` | object | 含 `gate_ids`、`evidence_paths`、`critical_failure_modes`；没有阶段门要求时使用空数组。 |
| `verification_mode` | object | 含 `test_level`（`T0..T4`）、`methods` 和可复现的 `oracle`。 |
| `version_surfaces` | array<string> | 引用 `versions/registry.yml` 的版本面 ID；稳定概念章可为空。 |
| `outcomes` | array<object> | 恰好 3 项且固定为 `explain`、`build`、`diagnose`，格式见下文。 |
| `scope_exception` | object | 可选。超出主题数限制时必须给出 `reason`、`reviewer`、`expires_in_edition`。 |

生成器派生并禁止写入分卷 spec 的字段：`volume`（章级）、`order`、`path`、`route_tags`、`recommended_after`、`generated`、`spec_digest`。其中 `recommended_after` 只表示同卷上一阅读章，不授予任何能力。

### `topic_groups`

```yaml
topic_groups:
  - id: java-branching
    title: 条件分支
    topics: [java.if, java.else, java.switch]
```

- group ID 在本章内唯一。
- 当 `curriculum/topics.yml` 的 `require_explicit_registration: true` 时，每个 `topics` 成员、`topics_taught`、`topics_used` 和 outcome 覆盖项都必须已登记。架构起草阶段允许先由分卷 spec 声明 topic，但这不取消首教与先用验证。
- 每个 group 至少被一个 outcome 的 `covers_topic_groups` 引用。

### 硬前置及理由

```yaml
prerequisites:
  - ch.java.values-types
prerequisite_rationales:
  ch.java.values-types:
    reason: 分支条件和分支结果需要已验证的值、类型与表达式能力
    capabilities: [java.values-types-string]
    topics: [java.boolean-expression]
    outcome_ids: [build, diagnose]
```

- rationale key 与 `prerequisites` 必须一一对应，不能缺少或多出。
- `capabilities`、`topics`、`outcome_ids` 至少有一项非空。
- 不允许把“上一章”作为理由；如果另一前置的祖先已经完整提供同一语义，验证器会报告冗余边。
- 正文 H1 后的“学习前检查”是 catalog 的可点击派生视图，不要手改生成标记内的标题、链接或理由。修改规范输入并重新生成 catalog 后，运行 `ruby scripts/sync-chapter-prerequisites.rb --write`；提交前运行同一脚本的 `--check` 模式。根章节会明确显示“无编程先修”。

### Capability 与借用样板

```yaml
capabilities:
  teaches: [java.control-flow]
  uses: [java.values-types-string]
borrowed_scaffolds:
  - topic: java.main-signature
    later_teacher_chapter_id: ch.java.program-structure
    allowed_action: copy-run-only
    rationale: 在正式讲解入口方法前仅复制并运行固定外壳
```

- 每项 capability 的唯一教师章由 `capabilities.yml` 交叉验证。
- capability 的 `required_topic_ids` 必须已在 `curriculum/topics.yml` 注册，并由教师章或其硬前置闭包正式教授；教师章的 `build` 和 `diagnose` outcome 都必须显式使用该 capability。
- `uses` 的教师章必须位于硬前置闭包，或是本章先教后用的同一 capability。
- borrowed scaffold 只为 topic 解锁复制/运行，不解锁 capability，也不能出现在 `build`/`diagnose` 的独立要求中。

### Lab、阶段门与验证层级

```yaml
lab_requirements:
  required: true
  artifact_paths:
    - labs/encyclopedia/ch.java.control-flow/
  acceptance:
    - 运行固定命令后退出码为 0，并有断言分别覆盖成功、边界和非法输入
gate_requirements:
  gate_ids: [G1]
  evidence_paths:
    - evidence/gates/g1/java-control-flow/
  critical_failure_modes: []
verification_mode:
  test_level: T1
  methods: [prediction, assertions, command-exit]
  oracle: 给定输入的分支结果与错误路径均可由断言复核
```

验证层级：

- `T0`：手算、观察输出、命令退出码。
- `T1`：测试预言、断言、成功/失败用例。
- `T2`：语言单元测试框架。
- `T3`：Mock、集成、容器、浏览器或设备测试。
- `T4`：系统、性能、安全或恢复测试。

### 三个结构化 outcomes

固定顺序和职责：

1. `explain` / `concept`：在 120 秒内解释职责、边界和反例。
2. `build` / `independent-build`：独立产出可运行工件并保存复现证据。
3. `diagnose` / `fault-diagnosis`：面对注入故障，指出失败阶段和首个可信证据，修复后重跑原验证。

每项格式：

```yaml
- id: explain
  kind: concept
  text: 在 120 秒内区分条件选择与循环重复的职责边界，并给出一个反例
  covers_topic_groups: [java-branching]
  covers_topics: [java.if, java.switch]
  uses_capabilities: [java.values-types-string]
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
```

`covers_topic_groups` 不得为空；`covers_topics` 必须属于这些 group。`build` 和 `diagnose` 使用的 capability 必须出现在章级 `capabilities.uses` 或 `capabilities.teaches` 中。

生成器还会运行 spec 质量 lint，避免 255 章只是替换标题的模板：

- `build` 必须命名具体 action 和 artifact；`最小可运行工件`等已知占位文案会报 `E_OUTCOME_GENERIC`。
- `diagnose` 至少命名一种本章特有 failure mode；只写“面对注入的…故障，指出失败阶段…”不足以通过。
- lab `acceptance` 至少给出一个可判定 oracle，例如确切退出码、状态码、断言、计数、digest 或恢复结果；通用的“成功、边界与故障场景均保存”会报 `E_ACCEPTANCE_GENERIC`。

## 完整示例

```yaml
- id: ch.java.loops
  title: 条件分支与循环控制
  role: concept
  responsibility: 教会读者用互斥分支和有界循环表达控制流程，不在本章引入集合或异常处理
  level: L1
  status: drafting
  stable_core: true
  topic_groups:
    - id: java-branching
      title: 条件分支
      topics: [java.boolean-expression, java.if, java.switch]
    - id: java-loops
      title: 循环与退出
      topics: [java.for, java.while, java.break-continue]
  topics_taught:
    - java.if
    - java.switch
    - java.for
    - java.while
    - java.break-continue
  topics_used:
    - java.boolean-expression
    - java.if
    - java.switch
    - java.for
    - java.while
    - java.break-continue
  prerequisites:
    - ch.java.branching
  prerequisite_rationales:
    ch.java.branching:
      reason: 条件表达式和循环计数需要已验证的值、类型、运算与转换能力
      capabilities: [java.values-types-string]
      topics: [java.boolean-expression]
      outcome_ids: [explain, build, diagnose]
  capabilities:
    teaches: [java.control-flow]
    uses: [java.values-types-string]
  borrowed_scaffolds: []
  lab_requirements:
    required: true
    artifact_paths:
      - labs/encyclopedia/ch.java.loops/
    acceptance:
      - 固定输入下断言分别证明零次循环、多次循环与非法边界的返回值
  gate_requirements:
    gate_ids: [G1]
    evidence_paths:
      - evidence/gates/g1/java-loops/
    critical_failure_modes: []
  verification_mode:
    test_level: T1
    methods: [prediction, assertions, command-exit]
    oracle: 固定输入对应固定输出和退出条件，错误边界会产生可定位的失败断言
  version_surfaces: [java]
  outcomes:
    - id: explain
      kind: concept
      text: 在 120 秒内区分条件选择与循环重复的职责边界，并给出一个循环无法替代分支的反例
      covers_topic_groups: [java-branching, java-loops]
      covers_topics: [java.if, java.switch, java.for, java.while]
      uses_capabilities: [java.values-types-string]
      evidence_kind: timed-teach-back
      verification_mode: oral-explanation
    - id: build
      kind: independent-build
      text: 独立实现含边界校验、分支和有界循环的命令行规则；保存源码、命令和可重复验证输出
      covers_topic_groups: [java-branching, java-loops]
      covers_topics: [java.boolean-expression, java.if, java.for, java.break-continue]
      uses_capabilities: [java.values-types-string, java.control-flow]
      evidence_kind: runnable-code-and-assertions
      verification_mode: failing-and-passing-cases
    - id: diagnose
      kind: fault-diagnosis
      text: 面对注入的分支遗漏或循环边界故障，指出失败阶段和首个可信证据，修复后重跑原验证
      covers_topic_groups: [java-branching, java-loops]
      covers_topics: [java.if, java.while, java.break-continue]
      uses_capabilities: [java.values-types-string, java.control-flow]
      evidence_kind: failure-log-fix-rerun
      verification_mode: injected-fault-rerun
```

## 禁止事项

- 不得使用旧 `vNN.cNN.slug` ID，也不得在 ID 中编码顺序或版本。
- 不得手写 `path`、`route_tags`、章级 `volume/order` 或生成 digest。
- 不得以 `recommended_after` 替代硬前置。
- 不得用 borrowed scaffold 绕过独立解释、修改、测试和诊断所需的正式教学。
- 不得把 `BUILD SUCCESS`、文件存在或 AI 生成当成掌握证据。
- 不得为通过验证而添加无期限的范围例外。
