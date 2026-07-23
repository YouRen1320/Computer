---
schema_version: 2
edition: 2026.2-draft
id: ch.agent.langgraph
title: LangGraph 状态、检查点、恢复与人工审批
responsibility: 用显式状态图建模多步 Agent 的节点、边、检查点、恢复和人工审批，使重试可恢复且副作用不重复。
volume: '14'
order: 15
level: L3
status: drafting
path: book/volume-14-llm-rag-agents/chapters/ch.agent.langgraph.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.llm.tool-calling
- ch.agent.langchain
version_surfaces:
- python-3.14
- langchain
- langgraph
- pytest
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“LangGraph 状态、检查点、恢复与人工审批”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - agent-graph-state
  - agent-checkpoint-approval
  covers_topics:
  - agent.graph-state-schema
  - agent.node-contract
  - agent.conditional-edge
  - agent.termination-condition
  - agent.checkpoint
  - agent.resume
  - agent.interrupt-approval
  - agent.replay-idempotency
  uses_capabilities:
  - ai.structured-tool-calling
  - ai.llm-model-api
  - python.asyncio-cancellation
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现工单诊断图：检索、分析、拟议操作、人工审批、执行和总结；在每节点后注入崩溃并恢复；独立保存可复现工件与判断结果
  covers_topic_groups:
  - agent-graph-state
  - agent-checkpoint-approval
  covers_topics:
  - agent.graph-state-schema
  - agent.node-contract
  - agent.conditional-edge
  - agent.termination-condition
  - agent.checkpoint
  - agent.resume
  - agent.interrupt-approval
  - agent.replay-idempotency
  uses_capabilities:
  - ai.structured-tool-calling
  - ai.llm-model-api
  - python.asyncio-cancellation
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: node-fault-injection-checkpoint-resume-approval-path-matrix
- id: diagnose
  kind: fault-diagnosis
  text: 面对“状态字段无版本、恢复后重复副作用、无终止条件循环或人工拒绝仍沿成功边执行”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - agent-graph-state
  - agent-checkpoint-approval
  covers_topics:
  - agent.graph-state-schema
  - agent.node-contract
  - agent.conditional-edge
  - agent.termination-condition
  - agent.checkpoint
  - agent.resume
  - agent.interrupt-approval
  - agent.replay-idempotency
  uses_capabilities:
  - ai.structured-tool-calling
  - ai.llm-model-api
  - python.asyncio-cancellation
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# LangGraph 状态、检查点、恢复与人工审批

当流程只有固定三步普通函数时，不需要状态图。LangGraph 的价值在于长时间、有状态、可中断、可恢复的编排：每个节点有明确输入输出，边决定下一步，checkpointer 保存线程状态，人工审批能暂停后继续。它不能自动保证业务副作用恰好一次，也不能替代 Java 的状态机和事务。

本章实际使用 LangGraph 1.2.9 的 StateGraph、InMemorySaver、`interrupt()` 和 `Command(resume=...)`。本地 Java authority 是内存幂等替身；它证明同一进程中的 replay 合同，不是持久数据库、分布式事务或生产恢复证据。

## 1. 先问是否真的需要图

确定性工作流若能用普通函数、队列或状态机清楚表达，优先使用它们。引入图的合理信号包括：需要在进程重启后继续；人工可能数小时后审批；多步调用必须观察和重放；存在条件分支和失败恢复；需要持久状态历史。只因为“Agent 流行”就把 CRUD 包成图，会增加版本、持久化和调试成本。

### 1.1 图不是模型思考图

StateGraph 是应用控制流。节点可以调用模型，也可以是纯代码、检索或 Java API。边由代码和结构化状态决定。把所有逻辑塞进一个“让模型决定下一步”的节点，虽然画出图，却失去显式状态与终止保证。

### 1.2 编排状态与业务状态

图状态表示某次运行进展，如 evidence、proposal、approval、receipt；工单状态由 Java 持有，如 ASSIGNED/CLOSED。图 checkpoint 里写 `status="executed"` 不能替代 Java transaction。二者通过 ticket_id、resource_version、idempotency_key 和 Java receipt 关联。

## 2. 状态 schema

状态是节点之间的合同，不是随意字典。定义字段名、类型、可选性、所有者、生命周期、敏感级别和合并规则。至少有 `schema_version`、`run_id`、业务引用、步骤预算、证据引用、提议、审批结果、权威 receipt 和终止状态。

### 2.1 状态版本

长期运行可能跨代码发布。旧 checkpoint 恢复到新代码时，字段含义可能变化。没有 schema_version，只能在 KeyError 后猜。支持策略可选：拒绝旧版、离线迁移、兼容读取；每种都要测试和回滚。本章严格接受 version 1。

### 2.2 原始数据还是格式化字符串

官方思维指南建议状态保存原始数据而非专用于某提示的格式化文本。这样检索证据可被审批 UI、模型和审计分别使用。状态仍要最小化：不要把整个敏感文档和令牌放进 checkpoint，优先保存授权 source reference 与必要摘要。

### 2.3 reducer

多个节点或并行分支更新同一字段时，需要 reducer 定义覆盖、追加或合并。默认覆盖不一定符合消息列表，简单 `list +` 又可能在 replay 重复。reducer 是版本表面和业务合同，必须用重复更新、并发顺序和恢复测试验证。

### 2.4 可序列化

checkpointer 要序列化状态。文件句柄、协程、数据库连接和任意闭包不属于状态；保存稳定 ID，在节点运行时从受控依赖获取资源。人工 interrupt payload 也应使用简单 JSON 可序列化值。

## 3. 节点合同

官方资料将节点描述为读取当前 state 并返回 updates 的 Python 函数。一个节点只承担一个可观察责任：validate、retrieve、analyze、propose、approval、execute、summarize。输入前置条件和返回字段必须测试。

### 3.1 纯节点与副作用节点

纯节点相同输入产生相同更新，最容易 replay。外部模型、时间和检索不是严格纯函数，至少记录版本/request ID。副作用节点调用 Java 写 API，要有幂等键、权威 receipt 和失败分类；不要在同一节点先写三套系统再 checkpoint。

### 3.2 节点大小

太大导致崩溃后重做大量工作，难以定位；太小导致 checkpoint 数和序列化开销上升。合理边界通常围绕一个可重试/可审计动作。尤其把“拟议操作”和“执行操作”拆开，中间才能审批。

### 3.3 返回更新而非原地修改

显式返回 `{field: value}` 更容易让运行时合并、trace 和测试。原地修改嵌套对象可能绕过 reducer 或产生共享引用。节点单测输入一个冻结 state，断言精确 update 和异常。

## 4. 边与条件路由

普通边表达确定顺序，conditional edge 根据结构化状态选路径。路由函数应短小、确定、全覆盖，返回已注册的目标。不要解析模型自然语言“看起来批准”来决定写操作；先把审批变成严格枚举。

```text
approval == approve -> execute
approval in reject|timeout|cancel -> terminate
anything else -> error
```

### 4.1 完备路径矩阵

为每个条件列输入、目标、终止状态和允许副作用。批准、拒绝、超时、取消、非法输入至少五条。测试不仅断言目标，还断言拒绝路径 Java call count=0。

### 4.2 决策与更新

节点可返回状态更新，路由再读取；某些 API 可用 Command 同时 update/goto。具体写法按当前版本文档，原则是业务决策能被 checkpoint 和审计，不藏在局部变量或提示文本。

## 5. 终止条件

每个环必须有可机读预算：最大步骤、总 deadline、模型调用数、工具调用数、成本或重复状态检测。达到限制进入 `budget_exhausted`，产生审计事件并停止；不能继续“再试一次”。DAG 也要覆盖异常与取消的终止路径。

### 5.1 最大步骤不是唯一保证

一个节点内部可能无限等待或自行循环，图级递归限制救不了它。每个外部调用还要 timeout/cancel；动态子任务有并发上限；后台 task 必须被结构化管理。

### 5.2 进展函数

能定义单调进展量更可靠，例如未处理任务数下降、remaining_steps 递减、状态集合不重复。若循环状态没有变化，应停止并报告 stalled，而不是烧 token。

### 5.3 结束状态

`completed`、`rejected`、`cancelled`、`timed_out`、`budget_exhausted`、`failed` 是不同结果。前端和 Java 不应把“图停止”统一显示成功。

## 6. checkpoint 与 thread

官方文档说明，编译图时提供 checkpointer 后，每一步可保存 state snapshot，并按 thread 组织。thread_id 是恢复指针；复用同一 ID 会继续该线程，新 ID 开始新状态。它不是租户授权凭证，也不能直接使用可猜用户输入而不做命名空间和访问控制。

### 6.1 checkpoint 内容

保存 state、下一节点、配置/元数据和待处理写入等运行信息。具体 schema 由版本/checkpointer 实现决定，不要让业务代码直接依赖内部表。长期审计仍使用领域事件和 Java receipt。

### 6.2 InMemorySaver

InMemorySaver 适合教程和测试，进程结束即丢失，也没有生产隔离/备份。官方 persistence 文档列出可安装的 SQLite/Postgres 等 checkpointer；选择后还要配置迁移、加密、租户权限、保留、容量和灾备。本章没有验证这些实现。

### 6.3 保存频率与大小

每一步全量状态可能增长，特别是追加消息。要测 checkpoint 大小、写延迟和清理；不要在未验证版本上假定增量功能稳定。敏感 state 加密和访问审计比压缩更优先。

## 7. 恢复语义

恢复不是从 Python 抛异常的精确机器指令继续，而是从最近成功 checkpoint 重放未完成工作。节点设计必须允许再次运行。区分“节点尚未执行”“外部副作用已提交但节点结果未 checkpoint”“节点结果已 checkpoint”。第二种最危险。

### 7.1 pending writes

官方 persistence 文档说明，同一 super-step 其他节点的成功 pending writes 可被保存，以免恢复时全部重跑。具体并行语义仍需目标图验证。业务副作用不应依赖内部 pending write 提供 exactly-once。

### 7.2 故障注入

在每个节点前、外部调用前、外部调用后、返回 update 前和 checkpoint 后注入崩溃。恢复后比较最终 state、调用次数和 Java committed_writes。只测试“模型调用前崩溃”覆盖不了最关键窗口。

### 7.3 相同输入不等于相同世界

恢复时外部文档或工单可能变化。读取节点记录 resource_version；写节点把 expected version 交给 Java 乐观锁。不能用旧提议覆盖新业务状态。

## 8. interrupt 与人工审批

官方 interrupts 文档说明，`interrupt()` 暂停图，把 payload 暴露给调用者，配合 checkpointer 和 thread_id 后通过 `Command(resume=...)` 恢复。payload 应包含具体资源、版本、动作、风险和过期时间，不只问“是否同意？”。

### 8.1 节点会从头重启

重要版本事实：恢复 interrupt 时，包含 interrupt 的节点从开头重新执行，不是从那一行继续。因此 interrupt 前的副作用会再次发生。官方明确建议前置副作用保持幂等，并警告不要随意改变 interrupt 调用顺序。

### 8.2 不要捕获 interrupt 控制异常

interrupt 通过运行时控制流暂停。用宽泛 try/except 包住并转普通错误可能破坏暂停。业务异常在 interrupt 外处理；具体异常类型是内部实现，不要依赖。

### 8.3 审批身份

resume 值来自应用输入，必须由 Java/认证服务确认审批者身份与权限。知道 thread_id 不代表可以批准。审批记录绑定 principal、proposal hash、resource version 和时间，拒绝/超时明确终止。

### 8.4 编辑提议

人工修改参数应生成新 proposal version 并重新校验，不要直接修改隐藏 state 后执行。UI 显示的内容与最终 Java 请求做 hash/字段对照，防止批准 A、执行 B。

## 9. replay 与幂等

分布式系统里 checkpointer 和 Java 数据库难以形成一个本地原子事务。正确模式是 Java 权威 API接受稳定 idempotency key：第一次提交保存结果，重复请求返回同一 receipt，不再次执行副作用。

### 9.1 键设计

键可由 run_id、节点语义、proposal version/action 组成，不能每次重试生成随机 UUID。不同业务动作不能误用同一键。Java 端持久保存请求摘要和结果，并检测相同 key 不同参数的冲突。

### 9.2 本章崩溃窗口

示例在 Java fixture committed 后、execute 节点返回前抛异常。checkpoint 仍停在 execute 前；恢复再次调用。attempts=2，但 committed_writes=1，并获得同一 receipt。这证明本地协议，不证明真实数据库/网络实现。

### 9.3 exactly-once 语言陷阱

更诚实的描述是 at-least-once 调用加幂等效果，而不是笼统“恰好一次”。外部邮件、设备控制等若无幂等 API，需要 outbox、去重或人工补偿，并单独建模。

## 10. 错误分类和重试

把错误分成 transient、LLM-recoverable、user-fixable、permission/business rejection、unexpected。网络短暂失败可按 deadline 重试；工具参数可让模型在有限预算内修正；用户输入缺失用 interrupt；权限拒绝不重试；未知异常终止并告警。

错误进入 state 时保存可机读 category 与安全摘要，不把完整堆栈喂给模型。重试次数也是 state，恢复后继续总预算而非重新归零。

## 11. 并发与 reducer 风险

平行节点可提升速度，但共享字段更新、外部调用顺序和 checkpoint 语义更复杂。若两个节点都追加 messages，reducer 必须确定；若都写同一工单，应在 Java 状态机串行/乐观锁。先验证串行图，再为有证据的瓶颈并行化。

取消父图时，节点内 asyncio、HTTP 和后台任务要传播取消。checkpointer 是否记录 cancelled 状态、何时可恢复是应用协议；本章没有创建脱离 task group 的后台工作。

## 12. 四类故障定位

### 12.1 状态字段无版本

旧 checkpoint 缺字段，新节点 KeyError。失败阶段是入口 state validation，首证据是 schema_version 缺失/不支持。修复定义迁移或拒绝策略并重跑旧快照，不靠默认值猜业务语义。

### 12.2 恢复后重复副作用

Java 出现两个写 receipt，或相同提议执行两次。首证据是相同 run/node 的 committed count>1。修复稳定 idempotency key 和权威去重；只在 Python state 写 `executed=true` 无法覆盖崩溃窗口。

### 12.3 无终止循环

相同状态/工具错误不断出现，steps/token 增长。首证据是 remaining budget 不下降或 state hash 重复。修复每轮扣预算、识别无进展并进入明确终态。

### 12.4 拒绝沿成功边

approval=reject 却调用 Java。首证据是 route matrix 或 Java call spy。修复严格枚举 conditional edge，拒绝/超时/取消到 terminal，并断言 call count=0。

## 13. 测试策略

节点单测断言前置条件与 update；路由表测所有枚举；图集成测试测批准/拒绝/超时/取消；checkpointer 测线程隔离；故障注入覆盖每节点和副作用窗口；升级测试用保存的旧 checkpoint；安全测试确保 state/trace 无 PII 与跨租户访问。

可视化图有助审查，但不是行为证明。CI 应运行图，不只比较图片。生产 checkpointer 还要真实容器/数据库测试、迁移和灾备演练。

### 13.1 checkpoint 隐私与租户隔离

checkpoint 可能保存问题、证据、模型输出、工具参数和审批内容，往往比普通日志更敏感。持久层按 tenant/thread 授权、静态/传输加密、最小运行角色、保留期和删除流程。thread_id 只用于定位，不是 bearer secret；服务在读取历史和 resume 前重新认证。

跨租户测试创建相同 run_id 或可猜 thread_id，确认 A 无法 list/get/resume B 的状态。备份、调试 UI、时间旅行和导出也执行同一政策。InMemorySaver 没有实现这些要求，本章只把它们列为生产门。

### 13.2 checkpoint 与代码发布

部署前统计运行中各 schema/version 和等待审批数量。若新代码不兼容，选择让旧 worker 排空、提供迁移器或明确取消；不能直接让新节点读取未知 state。迁移器对原快照不可变，生成新版本并保存审计，失败可回滚到旧 worker。

工具 schema、提示和模型也可能改变。state 保存其版本，resume 时做兼容检查。旧提议等待审批期间若业务政策变化，要求重新生成/审批，而不是按旧规则执行。

### 13.3 生产验收清单

生产前至少验证：持久 checkpointer 进程重启；多个 worker 抢同 thread；数据库断线与恢复；checkpoint schema migration；每个节点故障注入；副作用提交窗口；批准/拒绝/超时/取消矩阵；总预算与 kill switch；PII/tenant 审计；指标与告警；备份恢复；旧版本回滚。

每一项保存命令、版本和实际输出。某项未运行写 `unverified`，不能用本地 happy path 代替。只有 Java receipt 数与期望相同，才说明业务副作用门通过。

### 13.4 人工操作台

审批 UI 从 Java 获得经授权的 proposal projection，展示来源、风险、资源版本、到期时间和差异；批准/拒绝都要求防 CSRF、重新认证或高风险二次验证。多个审批者同时操作时，Java 使用 proposal version 保证只有一个决定生效。

操作台允许查看图状态不代表可任意编辑 checkpoint。修复运行应走受审计管理命令，记录原/新值和操作者；直接改数据库会破坏 replay 证据。

## 14. FactoryCare 边界

Python 图编排检索、分析、拟议操作、审批等待和总结。Java 认证审批人、读取当前工单版本、执行状态机和最终写入。Python 不直接连接业务数据库；checkpoint 不成为第二份工单真相。

图执行写节点只调用 Java command API，携带 expected version、proposal hash 和 idempotency key；只有 Java receipt 才进入 state。前端审批经 Java API，Java 再安全地恢复对应 thread。

## 15. 实际验证与未验证

2026-07-24 实际环境为 Python 3.14.3、LangGraph 1.2.9、LangChain 1.3.14、pytest 9.1.1。工件真实构建 StateGraph，用 InMemorySaver 暂停 interrupt，分别 resume approve/reject；在权威提交后注入崩溃，恢复 attempts=2、committed_writes=1；旧 state version 在首节点拒绝。

未验证 Postgres/SQLite checkpointer、进程重启、跨机器并发、加密、生产 human identity、真实 Java API、模型调用、远端取消和部署。InMemorySaver 结果不能外推为耐久恢复。

## 16. 可运行工件

- `examples/encyclopedia/ch.agent.langgraph/`：实际图、interrupt/Command、内存 checkpoint、审批矩阵与崩溃后幂等恢复。
- `labs/encyclopedia/ch.agent.langgraph/`：state version、replay、审批路由和循环预算不变量。
- `exercises/encyclopedia/ch.agent.langgraph/`：故意让所有审批状态进入 execute。
- `solutions-private/encyclopedia/ch.agent.langgraph/`：批准执行，拒绝/超时/取消终止。

## 17. 120 秒复述模板

“LangGraph 用 state schema、节点和边显式建模长流程；每个循环有预算和终态。checkpointer 按 thread 保存步骤，interrupt 暂停后用同一 thread 和 Command resume。恢复时节点可能重跑，interrupt 所在节点也从开头执行，所以外部副作用必须由 Java API用稳定 idempotency key 去重，checkpoint 不能充当业务事务。拒绝、超时和取消必须确定终止。越界反例是 InMemorySaver 测试通过就宣称生产可恢复，或图 state 写 completed 就当工单已更新。Java 保持事实、审批身份、状态机和最终写入。”

## 18. 自测题

1. 普通三步函数何时不需要 LangGraph？
2. graph state 与 Java business state 有何区别？
3. 为什么 state 要有 schema_version？
4. interrupt resume 后代码从哪里执行？
5. 为什么 checkpoint 不能提供外部写 exactly-once？
6. idempotency key 为什么不能每次随机？
7. 拒绝路径必须断言什么？
8. InMemorySaver 能证明什么？
9. 循环预算为何要进入 state？
10. 怎样测试提交后崩溃窗口？

## 19. 答案要点

1. 无持久/审批/恢复需求且固定流程用普通代码更简单。
2. 前者是编排进展，后者才是权威工单事实。
3. 代码升级后才能迁移或明确拒绝旧 checkpoint。
4. interrupt 所在节点从头重启，而非精确行继续。
5. 外部系统提交与 checkpoint 之间存在非原子窗口。
6. 重试必须命中同一去重记录。
7. 终态正确且 Java/工具调用次数为零。
8. 单进程 API 和 replay 合同，不证明耐久/分布式恢复。
9. 恢复后继续总预算，避免重新归零无限循环。
10. 写 fixture 后立刻抛异常，恢复并断言 attempts 增但 committed 不增。

## 20. 官方资料

- [LangGraph overview](https://docs.langchain.com/oss/python/langgraph/overview)：LangGraph 作为 durable execution、streaming、human-in-the-loop、persistence 运行时的位置。
- [Persistence](https://docs.langchain.com/oss/python/langgraph/persistence)：checkpoint、thread、pending writes 和 checkpointer 选择。
- [Interrupts](https://docs.langchain.com/oss/python/langgraph/interrupts)：interrupt、Command resume、节点重启和幂等规则。
- [Graph API](https://docs.langchain.com/oss/python/langgraph/use-graph-api)：state、node、edge 与持久层的官方用法。
- [Functional API](https://docs.langchain.com/oss/python/langgraph/functional-api)：任务 replay 与 idempotency 原则，供比较两种 API。

核验日期 2026-07-24。registry 约束 LangGraph 1.x；实际隔离为 1.2.9。显式状态、终止、审批与外部幂等是稳定原则；stream output 版本、checkpoint 内部结构、import 和 beta 功能属于版本表面，升级前查官方文档并重跑故障矩阵。
