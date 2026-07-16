---
schema_version: 2
edition: 2026.2-draft
id: ch.architecture.workflow-state-sla
title: 状态机、状态转换、SLA 与超时语义
responsibility: 教授显式状态转换和业务时间承诺，不把状态字符串任意更新或把 SLO 监控混入领域状态机
volume: '06'
order: 13
level: L2
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.architecture.workflow-state-sla.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.architecture.domain-modeling
- ch.data.transactions-locking
version_surfaces: []
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释状态机、状态转换、SLA 与超时语义的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - architecture-state-machine
  - architecture-sla-time
  covers_topics:
  - architecture.state-transition
  - architecture.transition-guard
  - architecture.invalid-transition
  - architecture.sla-deadline
  - architecture.business-clock
  - architecture.timeout-transition
  uses_capabilities:
  - architecture.domain-invariants
  - data.transactions-locks
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：为 NEW→ASSIGNED→IN_PROGRESS→CLOSED/CANCELLED 工单定义转换表、guard、事件和基于业务时钟的 SLA deadline
  covers_topic_groups:
  - architecture-state-machine
  - architecture-sla-time
  covers_topics:
  - architecture.state-transition
  - architecture.transition-guard
  - architecture.invalid-transition
  - architecture.sla-deadline
  - architecture.business-clock
  - architecture.timeout-transition
  uses_capabilities:
  - architecture.domain-invariants
  - data.transactions-locks
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入跳跃状态、终态复活和夏令/系统时钟导致 deadline 漂移，使用固定 Clock 的转换测试修复
  covers_topic_groups:
  - architecture-state-machine
  - architecture-sla-time
  covers_topics:
  - architecture.state-transition
  - architecture.transition-guard
  - architecture.invalid-transition
  - architecture.sla-deadline
  - architecture.business-clock
  - architecture.timeout-transition
  uses_capabilities:
  - architecture.domain-invariants
  - data.transactions-locks
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# 状态机、状态转换、SLA 与超时语义

> 本章状态为 `drafting`。配套资产只用 JDK 25、固定时间和内存合成工单验证语言级不变量，不启动 Spring、数据库、调度器或消息系统。局部绿灯能证明状态表、guard 和时间计算的预言，不能证明生产事务、锁、任务抢占、集群时钟或报表链路已经正确。

工单不是一行可以随意改写的字符串。它是一段受规则约束、能说明“如何走到这里”的业务历史。SLA 也不是页面上的红色倒计时，而是某个版本的业务承诺、开始事实、暂停事实和截止事实共同计算出的结果。本章把两者放在一起，是因为每次状态转换都可能启动、暂停、恢复或完成计时；如果状态和时间各自更新，系统会出现“工单已关闭但 SLA 仍计时”或“状态回滚但 deadline 已延长”等矛盾。

## 1. 完成定义与证据入口

完成本章后，应能独立做到：

1. 用状态、命令、转换、guard、不变量、终态和迁移历史解释状态机；
2. 为有限状态集合列出允许边，并证明未列出的边默认禁止；
3. 让非法转换在任何字段、历史、SLA 或事件写入前失败；
4. 区分结构合法与业务 guard 合法，例如“允许派单”不等于“没有技师也能派单”；
5. 区分 SLA、SLO、超时、deadline、已耗业务时间与墙上时间；
6. 用 `Instant` 保存事实，用 `ZoneId` 解释业务日历，用注入的 `Clock` 获取“现在”；
7. 对开始、暂停、恢复、完成和超时建立可重算记录，不靠页面倒计时充当事实；
8. 使用固定 Clock 重放跳跃、终态复活、重复暂停、边界等于和夏令时漂移。

配套入口：

- [状态与 SLA 示例](../../../examples/encyclopedia/ch.architecture.workflow-state-sla/README.md)
- [状态/时间故障注入实验](../../../labs/encyclopedia/ch.architecture.workflow-state-sla/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.architecture.workflow-state-sla/README.md)

## 2. 从“字段”升级为“状态机”

### 2.1 状态描述已经发生的业务事实

状态是系统对聚合当前阶段的受控概括。例如 `ASSIGNED` 表示派单命令已经满足权限与数据条件，assignment 已持久化，相关事务已提交；它不只是界面显示“已派单”。如果只写 `workOrder.status = request.status`，客户端便能跳过接单、处理、验证等规则，把一张刚创建的工单直接改成关闭。

枚举只能限制拼写集合，不能限制转换关系。`enum Status { NEW, ASSIGNED, IN_PROGRESS, CLOSED, CANCELLED }` 能防止 `"clsoed"`，却不能阻止 `NEW -> CLOSED`。真正的状态机还要回答：

- 哪个当前状态可以接收哪个命令；
- 命令成功后进入哪个目标状态；
- 需要哪些 guard；
- 失败时哪些内容必须保持不变；
- 成功时追加什么历史、审计和事件；
- SLA 时钟随转换如何变化。

### 2.2 命令、事件和状态不是同一个词

命令表达意图，例如 `AssignWorkOrder`、`StartWork`、`CloseWorkOrder`。它可能被拒绝。事件表达已经发生且提交的事实，例如 `WorkOrderAssigned`。状态是许多已提交事实折叠后的当前视图。不能收到 `Close` 请求就先发 `WorkOrderClosed`，然后才检查能不能关闭；那会把愿望伪装成事实。

一个命令也不一定对应一个新状态。FactoryCare 的转派命令结束旧 assignment、创建新 assignment、增加 version 并写核心审计，但不改工单 status，也不写 transition。这说明“重要业务动作”与“状态边”不是一一对应；为了记录动作而发明 `REASSIGNED` 状态会污染唯一状态机。

### 2.3 转换表是可审查的合同

本章独立构建采用一个刻意缩小的教学模型：

| 当前状态 | 命令 | 目标状态 | 关键 guard |
| --- | --- | --- | --- |
| `NEW` | `ASSIGN` | `ASSIGNED` | assignee 存在且可接单 |
| `NEW` | `CANCEL` | `CANCELLED` | 原因非空 |
| `ASSIGNED` | `START` | `IN_PROGRESS` | 当前操作者就是有效 assignee |
| `ASSIGNED` | `CANCEL` | `CANCELLED` | 有权限且原因非空 |
| `IN_PROGRESS` | `CLOSE` | `CLOSED` | 解决摘要与检查项齐全 |

在这个教学模型中，`CLOSED` 与 `CANCELLED` 是终态，所有未列边都拒绝。它只服务于 canonical outcome 的 `NEW→ASSIGNED→IN_PROGRESS→CLOSED/CANCELLED` 练习，不是 FactoryCare 产品合同。FactoryCare 使用 `CREATED` 而非 `NEW`，并允许 `CLOSED -> REOPENED`，所以绝不能把教学模型的“CLOSED 不可逆”复制到项目代码。

转换表应当能生成参数化测试：表中的每条允许边至少有一个成功用例，状态集合的笛卡尔积减去允许边形成禁止边用例。这样新增状态时测试会主动暴露未决定的关系，而不是等线上请求碰到某个 `default` 分支。

## 3. 转换 guard：允许走，不代表现在能走

转换表回答结构问题，guard 回答当前业务事实是否满足。以 `ASSIGNED -> IN_PROGRESS` 为例，边存在只是第一层；还可能要求：

- 当前 assignment 未结束；
- actor 是分配的技师或有明确接管权限；
- assignment 与工单属于同一租户、组织和 team；
- 预期 version 未过期；
- 工单未被并发取消或转派；
- 必要的安全确认已经完成。

把 guard 分散在 Controller、前端按钮和 SQL 之前的若干 `if` 中，会让另一入口绕过规则。应用服务负责鉴权与事务编排，聚合/领域策略负责与状态相关的不变量，Repository 负责持久化条件；三者职责不同，但必须对同一命令给出一致结果。

建议让转换返回显式结果，而不是任意 setter：

```text
transition(command, actor, now)
  1. 校验当前状态允许该命令
  2. 校验 guard 与 expectedVersion
  3. 计算目标状态和 SLA 动作
  4. 形成新的聚合快照与 transition fact
  5. 由同一事务持久化
```

这里的顺序很重要。若第 1 步前就改内存对象，随后 guard 抛错，而调用方继续使用该对象，便出现“数据库没改，内存已经改”的幽灵状态。更稳妥的模型是先验证并计算不可变结果，提交成功后才对外返回新快照。

## 4. 非法转换必须保持原状

拒绝不是“最后抛了异常”就够。可靠 oracle 至少比较：

- status 未变；
- version 未增；
- `work_order_transition` 未追加；
- assignment/approval/resolution 未写；
- SLA clock 未开始、暂停或延长；
- 核心审计与 outbox 未新增；
- 返回稳定错误而非一半成功。

如果状态先更新、历史写入失败后仍提交，当前状态便无法由历史解释。FactoryCare 合同要求状态、version、transition、必要审计和 outbox 在同一 PostgreSQL 事务中提交，任一失败整体回滚。通知发送、reporting 读模型和 AI 草稿在事务后处理，失败不能反向改变已提交工单事实。

并发使“先读再写”不充分。两个请求都读到 `ASSIGNED`，都通过 guard，并不代表都能提交。最终写入仍需 `WHERE id=? AND version=?` 或等价锁策略；影响零行是冲突，不是成功。下一章会系统处理这一边界。

## 5. 转换历史为何只追加

当前 status 适合快速读取，transition 历史用于解释过程。每条历史至少包含 `from_status`、`to_status`、命令/原因、actor、`occurred_at` 和提交后的 version。旧历史不应随当前字段覆盖，否则无法回答“谁在什么时候把工单从哪里推进到哪里”。

历史记录必须来自成功转换，不从普通日志反推。日志可能丢失、采样、改格式或重复；transition 是业务事实。反过来，transition 也不是包含所有隐私的调试日志，只保存解释转换所需的最小字段。

重建时需要验证连续性：后一条 `from` 应等于前一条 `to`，version 单调递增，时间不倒退，首条从合法初始状态开始。种子数据也必须走领域命令或受控导入端口，不能直接插一行 `CLOSED` 后伪造“完整演示”。

## 6. SLA、SLO、timeout 与 deadline

### 6.1 SLA 是业务承诺，不是监控目标

SLA（Service Level Agreement）在本章指适用于具体工单的业务服务承诺，例如“高优先级工单在 4 个业务小时内响应”。SLO 是团队用来管理系统可靠性的服务目标，例如 API 99.9% 可用。两者可能互相影响，但不应把 API 延迟监控状态塞进工单领域状态机。

Timeout 通常是一次操作允许等待多久，例如数据库查询 2 秒、外部 AI 调用 10 秒。Deadline 是一个绝对截止事实，例如 `2026-07-17T12:00:00Z`。一个请求可用“剩余 deadline”派生各下游 timeout，但工单 SLA 不等于某个 HTTP 请求 timeout。

### 6.2 保存组成事实，而非只保存倒计时

一个可解释的 SLA clock 通常需要：

- 适用的策略 ID 与策略版本快照；
- 开始时刻；
- 预算或业务时长规则；
- 当前计时状态：未开始、运行、暂停、完成、超时等；
- 每段暂停开始/结束事实；
- 已耗业务时长或可由区间重算的数据；
- 计算出的 deadline 与最后重算依据；
- 完成/超时时刻。

仅存 `remainingSeconds` 会随进程停机失去依据；仅存 deadline 又无法解释暂停为何延长。策略后来修改时，既有工单通常继续使用创建/分诊时快照，否则同一历史在今天重算会得到不同结论。是否允许迁移旧策略是显式业务决定，需要迁移报告，不是后台静默更新。

### 6.3 墙上经过时间与业务时间

“四小时”至少有三种含义：连续四个真实小时、某时区内四个营业小时、排除暂停区间后的四小时。必须在策略中命名。连续时长适合用 `Duration` 在 `Instant` 时间线上计算；营业时间需要版本化的业务日历、时区、工作日、班次和节假日。

业务时钟不是 `System.currentTimeMillis()` 的别名。它是“哪些时间段计入承诺”的领域规则。例如进入 `PENDING_PARTS` 后暂停，恢复到 `IN_PROGRESS` 时把完整暂停区间排除；重复收到 pause 不能再次开始一段，重复 resume 不能重复延长 deadline。

## 7. 开始、暂停、恢复、完成和超时

### 7.1 开始

SLA 从哪个状态开始必须由策略决定：创建、分诊还是派单。不能因为页面第一次打开才开始。开始命令必须幂等：已经运行的时钟再次 start 不应把 startAt 推迟到现在。

### 7.2 暂停

pause 记录 `pauseStartedAt`，但不立即把未来未知时长加到 deadline。已经暂停再次 pause 应拒绝或返回相同事实，不能创建重叠区间。暂停理由需要受控枚举/原因，例如等待备件；“系统繁忙”是否可暂停是另一规则。

### 7.3 恢复

resume 要求当前确实暂停，并满足对应状态转换。新 deadline 可以按原 deadline 加上 `resumeAt - pauseStartedAt`，或从历史重新计算。无论采用哪种实现，同一暂停区间只能计算一次。把“从开始到恢复的总时长”都加上会重复豁免已计费时间。

### 7.4 完成

达到业务完成点时冻结结果，例如 `met` 或 `breached`，保存完成时刻与所用策略。后续报表按事实计算分子/分母，不能因为展示时已过 deadline 就把按时完成的工单改为超时。

### 7.5 超时转换

超时不是定时器“叫醒了”才成立。判断应是纯规则：若时钟处于运行、当前事实时间达到或超过 deadline 且尚未完成，则可执行 `MarkBreached`。扫描任务只是发现候选并提交命令；任务重复、延迟或多个实例同时扫描时，领域 guard 与 version 仍保证最多一个有效转换。

必须提前决定边界：`now == deadline` 算按时还是超时。本章采用常见的半开区间语义——完成必须发生在 deadline 之前，`now >= deadline` 即超时。若业务合同定义“含截止瞬间”，测试与文案都要改，不能依赖 `isAfter` 的偶然选择。

## 8. Java 时间模型：事实、显示和测试

### 8.1 `Instant` 保存已经发生的点

`Instant` 位于 UTC 时间线，适合 persisted `occurredAt`、startAt、deadline。相同 instant 在上海和纽约显示不同当地时间，但事实不变。数据库应保存带时区语义的时间，API 使用明确 offset/UTC；不要把服务器默认时区写入事实。

`LocalDateTime` 没有 zone/offset，单独无法确定唯一 instant。`2026-11-01 01:30` 在采用夏令时回拨的地区可能出现两次；春季跳时还可能根本不存在。它适合表达“当地营业日周一 09:00”这类规则输入，不适合作为跨系统截止事实。

### 8.2 `ZoneId` 与 DST

地区 `ZoneId` 代表会变化的规则，不只是固定 `+08:00`。把 `LocalDateTime.plusHours(4)` 后再套 zone，和在 `Instant` 上加四个真实小时，跨 DST 时可能不同。营业时长计算必须明确在本地日历上迭代可计费区间，再转换成 instant；连续时长直接在 instant 时间线上计算。

Java 25 的 `ZonedDateTime` 官方文档明确区分 gap（没有合法 offset）与 overlap（两个合法 offset）。因此“所有一天都是 24 小时”“当地 02:30 总存在”都不是可靠不变量。测试至少覆盖一次向前跳和一次回拨，且断言最终 instant，不只断言格式化字符串。

### 8.3 注入 `Clock`

业务代码直接调用 `Instant.now()` 或 `System.currentTimeMillis()`，测试只能追赶真实时间，边界易抖动。让应用服务/领域服务接收 `Clock`，生产注入 `Clock.systemUTC()`，测试注入 `Clock.fixed(...)`。同一命令所有“现在”应从一次采样得到，避免校验时和写历史时跨过 deadline。

`System.nanoTime()` 适合测量单进程内经过时长，不代表 UTC 时间点，不能持久化成 deadline。机器时钟校准、NTP 回拨和多节点偏差属于运行边界；领域记录仍使用权威数据库/应用时刻与顺序控制，不能宣称注入 Clock 已解决分布式时钟一致性。

## 9. FactoryCare 的唯一 12 状态合同

FactoryCare 项目权威状态为：

```text
CREATED → TRIAGED → ASSIGNED → ACCEPTED → IN_PROGRESS
IN_PROGRESS → RESOLVED → VERIFIED → CLOSED
```

合法分支：

- `IN_PROGRESS ↔ PENDING_PARTS`；
- `IN_PROGRESS ↔ PENDING_APPROVAL`；
- `RESOLVED → IN_PROGRESS` 表示验证驳回；
- `CLOSED → REOPENED → IN_PROGRESS` 表示受控重开；
- `CREATED/TRIAGED → CANCELLED` 表示合法取消。

所有未列边禁止，不提供通用 `PATCH status`。`PENDING_APPROVAL` 的两个决定命令是 `APPROVE|REQUEST_CHANGES`，持久审批状态分别为 `APPROVED|CHANGES_REQUESTED`，但两者都把工单返回 `IN_PROGRESS`，不会直接跳到解决或关闭。

这里有两个容易写错的点。第一，FactoryCare 的 `CLOSED` 不是绝对终态，因为合同存在合法重开；只有具体策略判定不可再迁移时才能称终止。第二，转派不属于状态迁移：它替换有效 assignment、version 加一并审计，但 status 与 transition 行数不变。

SLA 由 `sla_policy` 与 `sla_clock` 建模。等待备件的暂停/恢复必须无双计，待审批是否暂停也由版本化策略明确并测试，不能靠状态名猜。所有时间事实存 UTC，同一事件换展示时区不改变 SLA 结果。Reporting 只统计适用同一策略快照的样本，并保留 eligible/met/breached 分子分母；读模型不是状态机事实源。

## 10. 一次正确转换的事务切片

以“开始处理”为例，应用服务应在一个受控事务中：

1. 从可信 tenant/actor 范围读取工单与有效 assignment；
2. 校验 permission、data scope、当前状态和 expectedVersion；
3. 采样一次 `now = clock.instant()`；
4. 执行 `ACCEPTED -> IN_PROGRESS` 的结构与 guard 校验；
5. 计算新 status、version 和 SLA 动作；
6. 条件更新工单；
7. 追加 transition；
8. 经 audit 公开端口追加最小核心审计；
9. 写入受治理的 outbox 事件（若合同定义该事件）；
10. 任一步失败则回滚，成功后返回新 version。

不要在提交前发送短信，外部 provider 无法与本地数据库原子回滚。也不要让 AI 服务决定目标状态；Python 分诊只是建议，Java 的唯一状态机保留业务权威。

## 11. 测试矩阵与可重放 oracle

### 11.1 允许边

对每条允许边验证目标状态、version、历史、SLA 动作和领域结果。成功测试不能只断言“没有抛异常”。若转换需要附件、reason、assignment 或 approval，应对最小满足条件与缺一项条件分别测试。

### 11.2 禁止边

生成全部 `from × to` 组合，排除合同允许边，逐个断言拒绝和完整不变快照。这样可抓住 switch 的 `default -> true`、通用 setter 和跳跃边。

### 11.3 终止与合法重开

教学模型断言 `CLOSED/CANCELLED` 不可复活；FactoryCare 测试则断言 `CLOSED -> REOPENED` 唯一合法，`CLOSED -> IN_PROGRESS` 仍禁止。测试必须选择正确合同，不能把两者混用。

### 11.4 时间边界

至少覆盖 deadline 前一纳秒、恰好等于、后一纳秒；暂停开始/重复暂停/恢复/重复恢复；跨 UTC 日界和展示时区；DST gap/overlap；策略快照变化。每个测试显式给 `Clock.fixed` 与 `ZoneId`，不能依赖开发机默认值。

### 11.5 事务与并发边界

本章 T2 资产只验证语言级规则。项目还需数据库测试：transition 写失败是否回滚 status，两个扫描器是否只有一个超时转换，过期 version 是否 409，outbox/核心审计失败是否整体回滚。这些不能用 mock 的“调用过一次”替代。

## 12. 三条典型失败链

### 12.1 跳跃状态

症状：`NEW -> CLOSED` 或 `CREATED -> CLOSED` 被接受。先保存请求、当前状态、目标命令、version 和最终行；不要只看 Controller 返回。常见根因是 DTO 暴露 status、枚举校验被当作转换校验，或 switch 默认允许。修复是命令化 API、显式允许表和全禁止边测试。回归必须证明状态、历史与 SLA 均未改变。

### 12.2 “终态复活”或错误禁止重开

症状可能相反：简化模型的 CLOSED 被随意恢复；或 FactoryCare 合法 `CLOSED -> REOPENED` 被“所有 CLOSED 都终态”的通用规则误杀。根因是脱离上下文复用一个 `isTerminal()`。修复时先确认状态机版本与聚合合同，再让允许边成为权威，终态只是派生结论。

### 12.3 deadline 漂移

症状：同一 fixture 在不同时区/季节/机器偶发差一小时，暂停后又多延长一段。收集 start instant、policy version、zone、pause intervals、Clock 来源和计算步骤。把系统 now 替换为固定 Clock，分别用 instant 连续时长与当地日历算法重算。若两者混用，先确定合同，不要用“加减一小时”补丁掩盖 DST。

## 13. 120 秒讲述模板

可以这样组织：

> 状态机把命令限制在显式允许边，并用 guard 校验当下业务事实；未列边默认拒绝，拒绝时状态、版本、历史、SLA 和事件都不能变化。SLA 是版本化业务承诺，deadline 来自开始、预算、业务日历和暂停区间，不等于 SLO 或单次请求 timeout。事实时间存 Instant，展示/营业规则使用 ZoneId，所有“现在”经注入 Clock，测试用 fixed Clock 覆盖 deadline、暂停和 DST。反例是直接 PATCH status 并用 LocalDateTime 加四小时：它既能跳过业务步骤，又会在夏令时边界得到错误截止点。FactoryCare 使用唯一 12 状态，CLOSED 可经 REOPENED 合法重开，转派则根本不改状态。

若无法解释“为什么非法转换后 deadline 也必须不变”，说明状态与时间还没有被理解为同一事务内的不变量。

## 14. 练习与验收

独立练习要求修复七个 TODO，起始代码稳定命中 `JUMP_STATE_ACCEPTED`。私有答案必须证明：允许表生效、guard 生效、非法转换保持原状、教学终态不可逆、deadline 可重算、暂停只延长一次、固定 Clock 在边界给出确定超时结论。

实验验收对应 canonical：所有允许/禁止边有表和测试；非法转换不改状态；deadline 可在时区/DST 边界重算；教学模型终态不可逆；故障修复后重跑原断言。把代码跑绿只是证据之一，最终还要能解释为什么 FactoryCare 的 CLOSED 例外不违反这些原则。

## 15. 官方来源、项目合同与证据边界

官方主来源（核对日期：2026-07-17）：

- [Java SE 25 `Clock`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/time/Clock.html)：可插拔当前时间与 `fixed` 测试时钟；
- [Java SE 25 `ZonedDateTime`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/time/ZonedDateTime.html)：local time 映射到 instant 时的 gap/overlap 规则；
- [Java SE 25 `System.nanoTime`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/System.html#nanoTime())：只用于测量经过时间，不代表墙上时间；
- [PostgreSQL 18 事务隔离](https://www.postgresql.org/docs/18/transaction-iso.html)：真实并发下可见性与冲突仍需数据库验证。

FactoryCare 项目权威来自 [PROJECT_SPEC](../../../PROJECT_SPEC.md)、[data-model](../../../factorycare-design/data/data-model.md)、[acceptance catalog](../../../factorycare-design/testing/acceptance-catalog.md) 与 [test strategy](../../../factorycare-design/testing/test-strategy.md)。本章的状态/SLA通则属于稳定核心；具体状态名、允许边、暂停策略、deadline 边界和报表口径属于业务合同，改变时需要影响、迁移和回滚计划。

有意不在本章证明：分布式全局时钟、真实 PostgreSQL 锁/事务、Spring 调度器、集群任务抢占、节假日日历供应、SLA 法律解释、通知投递和 reporting 最终一致性。它们需要后续 T4 集成与运行证据，不能由内存示例外推。
