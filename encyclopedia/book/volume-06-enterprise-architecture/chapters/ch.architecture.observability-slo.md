---
schema_version: 2
edition: 2026.2-draft
id: ch.architecture.observability-slo
title: 日志、指标、追踪、SLO 与告警闭环
responsibility: 教授从健康信号到用户目标的可观测闭环，不把日志数量、单一指标或告警存在等同于可靠性
volume: '06'
order: 19
level: L2+
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.architecture.observability-slo.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.actuator-health-metrics
- ch.architecture.modular-monolith
- ch.security.audit-events-privacy
version_surfaces:
- opentelemetry-specification
- opentelemetry-semantic-conventions
- spring-boot-4.1
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释日志、指标、追踪、SLO 与告警闭环的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - observability-signals
  - observability-slo-alert
  covers_topics:
  - observability.structured-log
  - observability.metric
  - observability.trace
  - observability.health-readiness
  - observability.sli-slo-error-budget
  - observability.alert-rule
  - observability.incident-feedback
  uses_capabilities:
  - backend.spring-mvc-contract
  - foundation.verification-debug-test
  - architecture.events-outbox
  - security.multitenancy-isolation
  - architecture.observability
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为创建工单链路关联结构化日志、请求/错误/延迟指标、trace 与 health，并定义可用性 SLI/SLO、错误预算和告警
  covers_topic_groups:
  - observability-signals
  - observability-slo-alert
  covers_topics:
  - observability.structured-log
  - observability.metric
  - observability.trace
  - observability.health-readiness
  - observability.sli-slo-error-budget
  - observability.alert-rule
  - observability.incident-feedback
  uses_capabilities:
  - backend.spring-mvc-contract
  - foundation.verification-debug-test
  - architecture.events-outbox
  - security.multitenancy-isolation
  - architecture.observability
  evidence_kind: system-artifact-and-negative-tests
  verification_mode: system-security-resilience-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入日志无 trace、metric 高基数、跨模块 trace 断裂和对瞬时尖峰告警，使用一次故障演练校准
  covers_topic_groups:
  - observability-signals
  - observability-slo-alert
  covers_topics:
  - observability.structured-log
  - observability.metric
  - observability.trace
  - observability.health-readiness
  - observability.sli-slo-error-budget
  - observability.alert-rule
  - observability.incident-feedback
  uses_capabilities:
  - backend.spring-mvc-contract
  - foundation.verification-debug-test
  - architecture.events-outbox
  - security.multitenancy-isolation
  - architecture.observability
  evidence_kind: fault-injection-fix-rerun
  verification_mode: fault-injection-rerun
---
# 日志、指标、追踪、SLO 与告警闭环

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Actuator、健康、就绪、指标与安全暴露》](../../volume-05-spring-backend/chapters/ch.spring.actuator-health-metrics.md)：独立完成日志、指标、追踪与健康、SLO 与告警前，必须先具备「Actuator、健康、就绪、指标与安全暴露」已经验证的知识与失败边界
- [《模块化单体、结构测试与拆分信号》](ch.architecture.modular-monolith.md)：独立完成日志、指标、追踪与健康、SLO 与告警前，必须先具备「模块化单体、结构测试与拆分信号」已经验证的知识与失败边界
- [《审计事件、敏感字段、追踪责任与隐私最小化》](ch.security.audit-events-privacy.md)：独立完成日志、指标、追踪与健康、SLO 与告警前，必须先具备「审计事件、敏感字段、追踪责任与隐私最小化」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套资产使用合成 JSON 和 Ruby 标准库离线验证相关性、标签基数、health、SLI、错误预算与持续告警，不启动 Spring Boot、OpenTelemetry Collector、Prometheus、日志平台、追踪后端或真实依赖。局部绿灯只能证明这里声明的规则能够重放，不能证明生产部署已经达到 SLO。

系统“有日志”“有监控页面”并不等于可观测，更不等于可靠。可观测性是借助系统向外暴露的信号，回答内部发生了什么；可靠性是用户在约定时间内得到正确服务的程度。前者帮助测量和诊断，后者必须用面向用户的目标定义。日志数量、CPU 曲线、绿色 health、trace 数量和告警条数都只是证据，不是可靠性的替身。

FactoryCare 的目标不是收集尽可能多的数据，而是建立一条可检验的闭环：用户创建工单时，结构化日志说明离散事件，指标说明总体趋势，trace 说明一次请求走过的路径，health 告诉流量入口当前能否送入请求；SLI 把用户体验变成计算式，SLO 给出目标，错误预算把目标转成可消费额度；告警只在持续威胁目标且有人能采取行动时通知；事故复盘再修正埋点、阈值、运行手册和架构。

## 1. 完成定义与证据入口

完成本章，应能独立做到：

1. 用自己的话区分 log、metric、trace、liveness、readiness、SLI、SLO、SLA、error budget 与 alert；
2. 让一次创建工单从 HTTP 入口、领域模块、事务/outbox、异步消费者到 Python 建议链路具有可关联证据；
3. 为日志定义字段允许列表和敏感字段禁区，为指标定义稳定名称与有界标签；
4. 让 liveness 只回答进程是否应被重启，让 readiness 反映是否应接收新流量，并显式处理必需与可选依赖；
5. 从 eligible event、good event、时间窗口和数据来源写出可计算的 SLI；
6. 用 SLO 计算错误预算，并解释为什么 100% 目标通常会消灭决策空间；
7. 让 page/ticket 告警面向用户症状、跨持续窗口判断、带 owner 与 runbook，避免瞬时尖峰直接叫醒值班人；
8. 注入日志无 trace、metric 高基数、异步 trace 断裂、health 依赖错误和瞬时尖峰告警，得到可解释红灯，修复后用同一预言重跑。

配套证据入口：

- [完整相关链示例](../../../examples/encyclopedia/ch.architecture.observability-slo/README.md)
- [六类故障实验](../../../labs/encyclopedia/ch.architecture.observability-slo/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.architecture.observability-slo/README.md)

本章的验收句是：**单次请求可跨日志/trace 定位；指标标签有界；health 反映依赖；SLI 可计算；持续违反 SLO 才触发可行动告警；上述条件均有可重放断言。** “看起来合理”不算完成，截图也不能替代断言。

## 2. 从零认识四类运行信号

### 2.1 Log：某个时刻发生了什么

日志是一条离散事件记录。例如“创建工单命令已接受”“outbox 记录已提交”“Python 建议超时”。它擅长保留上下文和错误细节，适合回答谁、何时、在哪个组件、以什么结果执行了什么。但日志搜索依赖字段稳定性，海量字符串的聚合成本高；日志也可能被采样、延迟或丢失，不能默认当作业务真相和不可抵赖审计账本。

### 2.2 Metric：一段时间总体怎样

指标是按时间聚合的数值，如请求总数、错误总数、延迟分布、队列积压和 JVM 内存。它适合做趋势、容量、SLO 和告警，存储与查询通常比逐条事件便宜。它不擅长解释某个工单为何失败；把工单 ID 放进标签虽然能“查到某一单”，却会制造几乎无限的时间序列。

### 2.3 Trace：一次工作经过哪里

trace 描述一次请求或后台任务的执行路径。一个 trace 由多个 span 组成；span 是一个有开始/结束时间、名称、属性、状态和父子/链接关系的工作片段。它适合回答慢在数据库、outbox relay、消息消费还是 Python 调用，以及错误在哪个边界产生。采样意味着并非每个请求都一定保存完整 trace，因此 SLI 通常不能只用采样后的 trace 计算。

### 2.4 Health：现在能否活着、能否接流量

health 是当前状态信号。liveness 回答“进程是否陷入不可恢复状态、是否值得重启”；readiness 回答“这个实例现在是否应接收新流量”。它们是调度和路由输入，不是长期可靠性成绩。某一瞬间 readiness 为 `UP`，不能证明过去 30 天满足 99.9%；某可选依赖降级，也不一定应该摘除仍可处理核心工单的实例。

### 2.5 四者如何互补

一次“创建工单变慢”的排查可以这样展开：指标先显示创建接口的延迟 SLI 正在恶化；告警链接到对应 dashboard；值班人从指标的 exemplar 或时间窗口进入一个慢 trace；trace 指向 outbox/数据库 span；相关结构化日志给出受控错误码和重试次数；readiness 说明实例是否仍可接流量。只有日志时看不到总体影响，只有指标时看不到单次因果，只有 trace 时难以知道影响比例，只有 health 时更无法回答用户体验。

## 3. 结构化日志：先定 schema，再写文案

结构化日志不是把一段自然语言包进 JSON，而是让关键事实有固定字段、固定类型和受控取值。建议为 FactoryCare 应用日志保留以下最小字段：

```json
{
  "timestamp": "2026-07-17T02:00:00.123Z",
  "severity": "INFO",
  "service": "factorycare-api",
  "environment": "production",
  "event": "work_order.create.completed",
  "outcome": "success",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "request_id": "req_7f21",
  "duration_ms": 84,
  "reason_code": null
}
```

`event` 和 `reason_code` 是机器稳定码；面向人的 `message` 可以存在，但不能成为唯一检索条件。`trace_id`/`span_id` 负责把日志接到 trace，`request_id` 可用于客服入口或未采样时的局部关联，但两者不能代替业务 ID、身份或权限。时间统一写带时区的 UTC；duration 用数值和明确单位，不能一处写毫秒、一处写字符串 `0.2s`。

日志级别表达处理优先级而非开发者情绪。可恢复的业务拒绝通常不是 `ERROR`；同一个异常不能在每层重复打印五次堆栈。入口/边界记录一次受控错误摘要，内部通过 trace status 和 span event 保留上下文。错误日志至少能区分：业务规则拒绝、权限拒绝、乐观锁/版本冲突、依赖超时和系统错误。若把所有非 2xx 都记为同一种 `failed`，SLO 与排障都会误判。

### 3.1 隐私与安全边界

不得直接记录密码、Cookie、Authorization header、Access/Refresh/ID Token、客户端密钥、数据库连接串、对象存储签名 URL、完整 Prompt、附件内容、知识正文、联系人/身份证件和异常请求体。脱敏不是“先序列化整个 DTO，再靠正则补救”，而是先定义字段允许列表。异常对象和第三方响应也要通过受控映射，不能 `logger.error("payload={}", payload)`。

tenant、user、work order 等标识即使不是秘密，也会带来隐私与越权风险。日志需要定位租户时，只在权限受控、确有目的且有保留策略的后端记录内部引用或不可逆/轮换策略明确的摘要；指标标签禁止放原始 tenant/user/workOrder；trace 属性也遵循最小化。`trace_id` 本身不是访问令牌，拿到它的人仍必须通过日志/trace 后端授权。

### 3.2 日志不是审计、也不是业务事实

“创建工单成功”必须以数据库事务和领域历史为事实源。日志写入失败不应使所有业务失败，日志先写成功而事务回滚也会说谎。核心审计事件另有稳定 schema、写入与完整性要求。本章只要求应用日志能诊断和关联，绝不把它升级成不可抵赖账本。

## 4. 指标：名称稳定，标签有界，分布可计算

### 4.1 Counter、Gauge 与 Histogram

- Counter 表示累计发生次数，只增不减，例如请求数、超时数、outbox 发布失败数。观察时间段内用 rate/increase 求变化。
- Gauge 表示可上可下的当前值，例如队列积压、活跃线程、当前就绪实例数。它适合状态，不适合累计事件。
- Histogram 将观察值放入桶并保留 count/sum，适合请求延迟和负载大小，能按服务端聚合计算分位近似或阈值比例。

不要把“成功率 99.92”周期性写成 Gauge 再平均。比例应从同一语义、同一窗口的 good/eligible Counter 计算；延迟 SLI 应从 histogram bucket 或等价的事件计数计算。名称带稳定语义，单位使用秒、字节、比例等基础单位；避免把单位藏在不一致的值里。

FactoryCare 可从以下少量指标开始：

```text
factorycare_http_server_requests_total{route,method,outcome,status_class}
factorycare_http_server_request_duration_seconds_bucket{route,method,le}
factorycare_dependency_requests_total{dependency,outcome}
factorycare_dependency_request_duration_seconds_bucket{dependency,le}
factorycare_outbox_backlog
factorycare_outbox_oldest_seconds
factorycare_ai_draft_requests_total{outcome}
factorycare_work_order_commands_total{command,outcome}
```

`route` 必须是模板，如 `/api/work-orders/{id}`，不能是原始 `/api/work-orders/981273`；`outcome` 使用受控集合，如 `success`、`business_rejected`、`permission_denied`、`version_conflict`、`dependency_timeout`、`system_error`。这样既能区分用户结果，也不会把异常 message 变成标签。

### 4.2 什么叫“高基数”

指标系统通常为每个唯一标签组合建立时间序列。假设一个指标有 5 个 route、4 个 method、6 个 outcome、10 个 instance，理论组合已是 `5×4×6×10=1200`。再加 50 万个 workOrderId，序列数会失控。高基数会增加内存、存储、查询时间和费用，严重时监控系统本身先故障。

禁止作为通用 metric label 的典型值包括：`trace_id`、`span_id`、`request_id`、`user_id`、`work_order_id`、原始 tenant、邮箱、IP、完整 URL、查询参数、异常 message、SQL 和任意 Prompt。可用 route template、状态码类别、依赖名、命令类型、受控 outcome 代替。需要从指标跳到具体请求时，用 exemplar 关联 trace，或按时间/稳定标签缩小范围后查询 trace/log，而不是把 trace ID 变成标签。

标签允许值也要版本化测试。即使字段名叫 `error_type`，若值来自异常全文仍然无界。添加标签前要回答：值集合上限是多少、谁维护、多久保留、最坏序列数多少、删除后如何迁移 dashboard/alert。

### 4.3 指标本身也会说谎

只在 controller 成功返回时递增请求 Counter，会漏掉异常；客户端重试会让“调用次数”多于“用户操作数”；应用崩溃前缓冲未导出会丢尾部数据；多实例时重复注册或标签变化会破坏查询。每个 SLI 必须写清测量点、去重语义、延迟/丢失假设和缺数据行为。仪表盘上的零可能是“没有错误”，也可能是“采集断了”。

## 5. Trace 与跨信号相关

### 5.1 Trace、Span、上下文

入口收到请求时创建或继续 server span，调用数据库/HTTP/消息系统时创建子 span。trace context 携带 trace ID、当前 span ID、采样标志等，使下游知道自己属于哪次工作。HTTP 边界采用标准传播格式；内部不得发明只在某语言有效的 header。外部传入的上下文是不可信元数据：校验格式、限制 baggage、禁止把身份/权限决定放进传播字段。

相关不是“每条日志都有随机 traceId”。正确关联至少满足：

1. 同一执行上下文中的日志取当前 span 的真实 `trace_id`/`span_id`；
2. 日志中的 span ID 在导出的 trace 中存在，或明确说明该 trace 未采样/未导出；
3. 跨线程、异步 executor、消息/outbox 和远程调用传播上下文；
4. 资源属性能说明 service、environment、version/instance 等来源；
5. 指标到 trace 用 exemplar 或时间+低基数属性跳转，不把 trace ID 当标签。

### 5.2 FactoryCare 的同步与异步边界

创建工单的同步路径可以是：HTTP server span → `workorders.create` internal span → database span → `outbox.append` span。事务提交后 relay 读取 outbox，发布消息，消费者触发 Python 建议。为了保持因果，outbox event envelope 保存标准 trace context 和一个独立业务 event ID；relay 注入消息 header，consumer 提取并创建 consumer span，再调用 Python client span。

长时间排队或跨组织消息有两种合理策略：继续原 trace，或创建新 trace 并用 span link 指向生产者。两者要按采样、保留和后端能力统一决定，不能某消费者复制 trace ID、另一个凭空把 producer span 当本地 parent。本章的离线示例为满足单次创建链定位，选择在受控内部 outbox 链继续同一 trace；如果生产实现改用 link，验收应相应检查可导航 link 和 business event ID，而不是强迫相同 trace ID。

线程池也是边界。只在 controller 放 MDC 并不够：任务切到 executor 后 MDC/Observation context 可能消失。Spring Boot 4.1 的自动配置执行器可配置 context propagation；自定义 executor 仍需显式 decorator/包装并用测试证明。无论框架提供什么自动化，都必须注入一次异步任务验证日志与 span，而不是凭配置名宣称成功。

### 5.3 Span 应记录什么

span name 使用低基数操作名，如 `POST /api/work-orders`、`workorders.create`、`outbox.publish`，不要嵌入工单号。属性可包含受控 route、method、outcome、dependency、messaging operation 和 schema version；错误记录受控 type/status，避免完整正文和秘密。span event 可表达一次重试或状态转换，但数据库每行、循环每次迭代都建 span 会制造噪声和成本。

采样策略必须承认盲点。head sampling 早期决定，可能漏掉后来的错误；tail sampling 能按结果选择但需要 collector 状态和容量。无论采用哪种方式，关键 SLI Counter 不能依赖“被采样 trace 的比例”。

## 6. Liveness、Readiness 与依赖健康

### 6.1 Liveness：重启能否修复

liveness 只应检查进程内部是否还能向前推进，例如事件循环永久卡死、关键线程死锁或不可恢复内部状态。不要让 liveness 依赖 PostgreSQL、Redis、Python、身份提供方或互联网。若数据库短暂故障让所有实例 liveness 失败，编排器会不断重启健康应用，扩大连接风暴和冷启动，形成级联故障。

### 6.2 Readiness：现在是否应接收新流量

readiness 根据当前实例处理其核心流量所需的条件判断。FactoryCare 核心创建/查询工单依赖主数据库，因此数据库不可用可使 API 实例 not ready；但具体要结合连接池、故障转移和入口行为演练。Redis 若只是可绕过缓存，Python 只提供可选 AI 草稿，则它们降级不应让核心 API readiness 失败。应分别暴露 dependency health、降级指标和面向对应功能的 SLI。

“依赖 health 反映真实依赖”不等于“所有依赖都塞入 readiness”。每个依赖标注：核心还是可选、失败时功能怎样、重试/超时怎样、是否摘流、谁负责。可选 Python `DEGRADED` 时，创建工单仍返回成功并说明建议稍后生成；AI 功能自身的 SLI 记录失败。把所有功能压成一个红绿灯会丢失信息。

### 6.3 探针的安全与真实性

探针最好走应用实际服务端口/基础设施，避免管理端口健康而主 connector 已坏。对外只暴露必要状态，详细 component、主机名、连接信息和异常只对授权运维面开放。探针要有短超时和成本上限，不执行写业务或重型全表查询。health 缺失/超时应按明确 fail policy 处理，不能把 `UNKNOWN` 偷换成 `UP`。

## 7. SLI、SLO、SLA 与错误预算

### 7.1 四个词的关系

- SLI（Service Level Indicator）是服务水平的量化测量，例如“30 天内，在 2 秒内返回约定响应的 eligible 创建请求比例”。
- SLO（Service Level Objective）是 SLI 的目标，例如上述比例至少 99.9%。
- SLA（Service Level Agreement）是对外协议，违约通常有业务/合同后果；它不是内部告警阈值的同义词。
- Error budget 是 SLO 允许未达标的空间。可用性 SLO 为 99.9%，允许坏事件比例是 `1 - 0.999 = 0.001`，即 0.1%。

SLI 是测量，SLO 是承诺/目标，告警是根据风险触发的动作。CPU 80% 可以是诊断信号，但通常不是用户 SLI；`/health=UP` 是瞬时路由信号，也不是 30 天目标。

### 7.2 先定义 eligible，再定义 good

一个可计算 SLI 必须写全：用户/旅程、eligible event、good event、坏事件、测量点、窗口、聚合、缺失数据、排除项和目标。只写“接口成功率 99.9%”无法重放。

本章给 FactoryCare “创建工单 API 可用性”一个**教学示例，尚非生产承诺**：

- 用户旅程：已到达 API 网关并调用 `POST /api/work-orders` 的客户端获得约定响应；
- eligible：非探针、路由模板匹配且到达服务测量点的请求；
- good：2 秒内得到契约允许的 201，或得到正确且及时的 4xx 业务/权限/版本结果；
- bad：5xx、服务端超时、连接被服务端中断、响应不符合契约，或超过 2 秒；
- 窗口：滚动 30 天；
- 目标：good / eligible ≥ 99.9%；
- 数据源：入口请求 Counter/histogram，独立核对采集连续性；
- 排除：明确标识的探针和预先批准的合成流量；不能临时排除故障时段。

把正确 4xx 计为“可用性 good”，表示服务正确执行了契约，不表示业务创建成功。另建 `work_order_commands_total{outcome}` 区分 `business_rejected`、`permission_denied`、`version_conflict`，用业务漏斗/安全指标观察异常。如果某授权 bug 错误地产生 403，仅靠 HTTP 类别会误判，因此还需要契约测试、权限场景与业务 SLI。这展示了一个 SLI 只回答一个问题，不能包办“业务成功”。

也可将 latency 和 correctness 分开：例如“eligible 响应中 95% 小于 500 ms”和“已返回 201 的工单在事务中同时具备历史、审计与 outbox 的比例为 100%”。具体目标由产品价值、历史基线、架构能力和成本共同审批，教材数字不能直接复制到生产。

### 7.3 算一遍错误预算

假设教学窗口内 eligible 为 10,000，bad 为 8：

```text
good                 = 10,000 - 8 = 9,992
availability SLI     = 9,992 / 10,000 = 0.9992 = 99.92%
allowed bad fraction = 1 - 0.999 = 0.001
total error budget   = 10,000 × 0.001 = 10 个坏请求
consumed             = 8
remaining            = 10 - 8 = 2
budget consumed rate = 8 / 10 = 80%
```

这个窗口仍满足 99.9%，但只剩 2 个坏请求空间。团队可以据此降低变更风险、优先修复可靠性或增加保护。预算是共同决策工具，不是给个人记过，也不能因为预算尚有剩余就故意制造故障。

100% SLO 通常意味着任何正常变更、依赖抖动和测量误差都“违规”，团队没有可用预算，且成本趋近无限。真正不能容忍的安全/数据不变量应用事务、约束、权限和恢复设计保护，不要仅靠 100% 可用性数字。

低流量服务有离散性问题：一天仅 20 个请求，一个错误就是 5%。应考虑更长窗口、合成检查、事件数门槛和 ticket 而非立即 page；绝不能为了平滑而把坏请求删掉。

## 8. 从错误预算到可行动告警

### 8.1 Burn rate

burn rate 表示错误预算消耗速度：

```text
burn rate = observed bad fraction / allowed bad fraction
```

99.9% SLO 的 allowed bad fraction 为 0.001。某窗口 bad fraction 为 0.0144（1.44%），burn rate 为 14.4。burn rate=1 表示若持续整个 SLO 窗口，恰好耗尽全部预算；14.4 表示按当前速度会快得多地耗尽。

告警不应只看一个 5 分钟点。多窗口、多 burn-rate 的思路是：长窗口证明问题持续且确实威胁预算，短窗口证明问题仍在发生；两者用 AND。Google SRE Workbook 给 30 天窗口提供过 14.4× 的 1 小时+5 分钟 page、6× 的 6 小时+30 分钟 page 等起点，但这些不是可复制的宇宙常数。FactoryCare 必须根据流量、检测/恢复时间、采集延迟和轮值容量用历史回放与演练校准。

例如：短窗口 burn=20、长窗口 burn=0.5，说明刚才有尖峰但长期影响不足，不 page；可以记事件/看 dashboard。短窗口 burn=18、长窗口 burn=15，且超出数据完整性与最小事件数条件，才满足 14.4× 双窗口 page。慢速消耗可创建工作时段 ticket，避免所有风险都叫醒人。

### 8.2 一条可行动告警必须带什么

告警至少包含：

- 用户症状和受影响 SLO，而非只有“CPU 高”；
- 当前值、阈值、长短窗口、最小流量/缺数据状态；
- service、environment、severity、owner；
- dashboard、日志查询、trace/exemplar 与 runbook 链接；
- 第一项安全动作、升级路径、静默/去重键；
- 恢复条件和验证查询。

Page 只用于需要立即人工动作且等待会显著增加用户影响的情况。Ticket 用于慢燃、容量趋势和改进工作。Dashboard 用于探索，不等于告警。某告警若没有 owner、runbook 或任何可做动作，应先修设计，不要靠“多提醒几个人”。

### 8.3 症状优先，原因辅助

用户可见的错误/延迟和预算消耗是高层症状；数据库连接池、CPU、GC、outbox backlog 是诊断/原因信号。原因告警在能提前阻止灾难且动作明确时有价值，例如 oldest outbox 超过用户承诺前的安全阈值；否则应在症状告警的 dashboard 展示。为每个下游依赖各 page 一次会在一次事故中制造告警风暴。

监控系统自己也要被监控：采集停止、规则评估失败、通知投递失败、时间漂移和 dashboard 数据断层都必须可见。`No data` 不是自动健康；按信号决定 fail-open、ticket 或 page。

## 9. FactoryCare：创建工单到 Python 建议的完整链

一次请求可按以下路径产生证据：

```text
客户端
  → API：POST /api/work-orders（server span）
  → workorders 模块：create command（internal span）
  → PostgreSQL：work order + history + audit + outbox 同事务
  → outbox relay：publish event
  → consumer：handle WorkOrderCreated
  → Python AI：生成建议草稿
  → tool callback/metadata：记录可批准的结果，不自动冒充人类决定
```

入口日志记录 route、受控 outcome、trace/span 和 duration；领域模块记录 `work_order.create.committed`，不打印 DTO；outbox 记录 event type/schema、publish outcome、attempt 和 trace context；consumer/Python 客户端记录 dependency outcome、timeout/retry，但不记录 Prompt/Token/知识正文。所有日志的 trace ID 能关联到实际 span。

指标在入口统计请求与延迟，在命令边界区分业务拒绝、权限拒绝、version conflict、dependency timeout 和 system error，在 outbox 记录 backlog/oldest age，在 Python 边界记录 `success/timeout/invalid_response/system_error`。标签只有 route template、operation、outcome、dependency 等有界值，工单/用户/tenant/trace ID 不进入标签。

trace 显示同步事务和异步传播。事务内 database/outbox span 的状态与日志一致；consumer 从 event envelope 提取上下文。若 Python 超时，核心创建工单已成功：核心 availability 可保持 good，AI draft SLI 计 bad，dependency health 显示 degraded，用户界面说明草稿稍后生成。不能把可选 AI 故障变成整个 API liveness failure。

readiness 需要 PostgreSQL 等核心依赖，liveness 不需要外部依赖；Python 作为可选依赖单独显示。SLO 面向用户旅程，告警从持续预算消耗触发，并链接这条链的 dashboard/trace/runbook。事故结束后，把发现的 trace 断点、无界标签、错误分类或 runbook 缺口带回代码和验收目录。

### 9.1 一次排障的最短路径

1. 告警显示创建工单 availability SLO 的 1h/5m burn 均超过 page 阈值，流量与采集完整性正常；
2. dashboard 将 bad 按 outcome 分解，发现 `dependency_timeout` 上升，而业务拒绝稳定；
3. exemplar 打开慢 trace，HTTP → workorders → database 正常，outbox consumer → Python client span 超时；
4. 相关日志以同 trace 查询，看到受控 `PYTHON_TIMEOUT` 和 retry 次数，没有 Prompt/Token；
5. 若创建 API 本不应同步依赖 Python，却也变慢，说明边界实现错误；按 runbook 关闭同步 AI 路径/启用异步降级；
6. 观察 SLI burn 回落、readiness 稳定、outbox backlog 可控，再验证用户操作；
7. 复盘补上“Python 超时不阻断核心创建”的架构测试和故障演练。

## 10. 六类常见失败与证据链

### 10.1 日志没有真实 trace

- **症状：** 每个组件都有日志，但无法从一条请求跨边界搜索；或日志里的 trace ID 不存在于 trace 后端。
- **原因：** 手工生成 correlation ID、线程池丢上下文、logger 未接 Observation context、trace 未导出却没有采样标志。
- **修复：** 从当前 span 自动注入日志字段；为 executor/outbox/HTTP 明确传播；用一条合成请求断言 log span 存在于 trace。
- **不能证明：** 仅看到 JSON 中有 `trace_id` 字段。

### 10.2 Metric 高基数

- **症状：** 时间序列暴涨、查询/规则变慢、监控费用上升。
- **原因：** `trace_id`、workOrderId、tenant、原始 URL 或 exception message 进入标签。
- **修复：** 标签允许列表；route 模板化；错误映射到受控 outcome/type；具体请求通过 exemplar/log/trace 查。
- **回归：** 静态检查 schema，运行时统计每个 label 的 distinct 值和总 series 上限。

### 10.3 跨模块/异步 Trace 断裂

- **症状：** API trace 到事务提交结束，consumer/Python 是无关新 root；日志只能靠工单号拼接。
- **原因：** outbox 未保存传播上下文、relay 丢 header、consumer 未 extract、格式不兼容。
- **修复：** event envelope 保存标准上下文；relay inject、consumer extract；继续 trace 或显式 span link；保留独立 event ID 处理重放。
- **回归：** 暂停/恢复 consumer、重复投递和跨进程测试均能从入口导航到处理结果。

### 10.4 Liveness 依赖数据库

- **症状：** 数据库短暂抖动时所有应用反复重启，恢复更慢。
- **原因：** 把“当前不能完成核心请求”误当“进程必须重启”。
- **修复：** liveness 仅内部；数据库按核心性进入 readiness；设置超时、失败阈值和连接风暴保护。
- **回归：** 断开数据库，验证实例不因 liveness 重启、readiness 摘流、恢复后重新就绪。

### 10.5 SLI 分母/分类错误

- **症状：** 生产大量 5xx，dashboard 仍 100%；或所有正确 403 被当系统宕机。
- **原因：** 只在成功代码路径递增 total、排除故障时段、把业务结果与系统可用性混成一个比率。
- **修复：** 在统一边界统计 eligible/good/bad，明确分类与排除；另建业务和安全指标；独立检查采集连续性。
- **回归：** 回放 201、400、403、409、500、timeout、超过阈值与 no-data 场景，手算结果和查询一致。

### 10.6 瞬时尖峰直接 Page

- **症状：** 一次 30 秒部署抖动叫醒值班人，打开时已恢复；久而久之所有人忽略通知。
- **原因：** 单点阈值、无 `for`/持续窗口、没有长短窗口 AND、没有最低流量和行动说明。
- **修复：** 面向 SLO burn 的多窗口条件；部署/维护上下文；page/ticket 分级；owner/runbook/dedupe。
- **回归：** 用短窗高/长窗低的瞬时样本断言不 page，再用长短窗都高的持续样本断言 page。

## 11. Spring Boot 4.1 落地边界

Spring Boot 将 observability 视为 logging、metrics、traces 三个支柱，并通过 Micrometer Observation 支撑 metrics/traces。Observation 的低基数 key-values 可进入 metrics 和 traces，高基数 key-values 只适合 traces；这不是允许把 PII 填进 trace，而是提醒 metric cardinality 边界更严格。

Actuator 可提供 liveness/readiness 端点。配置只是一部分：必须验证探针是否走真实服务端口、外部暴露范围、关键/可选依赖的分组以及故障时编排器行为。官方文档明确警告 liveness 不应依赖外部系统，以免级联重启；readiness 是否纳入某依赖要结合实例能否处理流量判断。

OpenTelemetry 与 Spring Boot/Micrometer 的桥接、exporter 和 context propagation 会随版本变化。本章锁定 `spring-boot-4.1` version surface，但不承诺某个 starter 自动导出所有 log/metric/trace。特别是 OpenTelemetry 原生 metrics/logs 的自动导出能力与 Micrometer tracing 路径不同：以项目锁定依赖、官方对应版本文档和集成测试为准。升级时至少验证：字段/semantic conventions、采样、executor context、HTTP/message propagation、export retry/backpressure 和 collector 不可用时应用是否仍安全运行。

以下是设计轮廓，不是可直接复制的完整生产配置：

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,prometheus
  endpoint:
    health:
      probes:
        enabled: true
      show-details: when-authorized
```

真正验收必须从外部请求 `/actuator/health/liveness`、`/actuator/health/readiness`，再注入 PostgreSQL/Python 故障观察返回、路由、重启与核心业务。不要因为 endpoint 存在就写“health 完成”。

## 12. 告警后的事故反馈闭环

可观测闭环不在“告警恢复”时结束。一次事故至少留下：

1. **Detect：** 哪个 SLI/告警先发现，是否早于用户报告，是否误报/漏报；
2. **Triage：** 从告警到 dashboard、trace、log 是否顺畅，跨 tenant/敏感信息权限是否正确；
3. **Mitigate：** 执行了什么降级、回滚、限流、切换，动作是否在 runbook 中且可撤销；
4. **Recover：** 用哪个用户级 SLI 与合成流程确认恢复，不只看 CPU 或 health 变绿；
5. **Learn：** 根因、促成条件、检测缺口、决策时间线和无责改进项；
6. **Verify：** 新增故障注入、负面测试和同一 verifier 重跑，给行动设 owner/期限。

复盘不能为了“更可观测”无限加日志。若问题是分类错误，就修 outcome schema；若 trace 断在 outbox，就修传播测试；若告警无动作，就删/降级并改 runbook；若 SLO 与用户价值不符，就经过产品/工程共同评审调整。每个新增信号同时评估成本、隐私、基数、保留和访问权。

## 13. 独立构建任务

不看私有答案，为 FactoryCare 创建工单链完成一份离线或真实实现，至少提交：

1. 一条从 API、workorders、outbox、consumer 到 Python 的 trace/spans，父子或 link 关系可导航；
2. 每个关键边界一条结构化日志，使用同一真实 trace context，无秘密/完整 PII；
3. 请求、错误分类、延迟、dependency 和 outbox 指标 schema，附标签集合上限说明；
4. liveness/readiness/依赖健康矩阵，说明 PostgreSQL 与可选 Python 故障的不同结果；
5. 创建 API availability SLI 的 eligible/good/bad/窗口/数据源/排除项；
6. 教学窗口 10,000 eligible、8 bad、99.9% SLO 的手算和机器断言；
7. 瞬时与持续两组 burn-rate 数据，只有持续组 page，告警带 owner/runbook；
8. 一次事故反馈记录：检测、定位、缓解、恢复查询和新增回归。

公开练习 starter 故意缺少正确相关字段，因此第一次运行必须红灯；修改后用原命令转绿。私有目录给出参考绿灯，但不要复制字段后就声称完成真实系统：真正 T4 还需进程/依赖故障、跨边界采集和恢复行为。

## 14. 两分钟口述模板

可以在 120 秒内这样解释：

> 日志记录离散事件，指标统计总体数量和分布，trace 展示一次请求跨组件的路径，health 只决定进程是否活着和实例是否接流量。它们通过真实 trace context、稳定资源属性和 exemplar 相关，但 metric label 必须有界，trace/log 不得记录秘密。SLI 把用户体验写成 good/eligible 的计算，SLO 给目标，error budget 是允许的坏事件空间。告警关注持续预算消耗并带 owner/runbook，瞬时尖峰不直接 page。FactoryCare 创建工单从 API、事务/outbox 到 consumer/Python 保持因果；PostgreSQL 可影响 readiness，Python 降级不影响 liveness。事故后用同一故障和预言重跑，把缺口反馈到埋点、规则和架构。

一个会失败的反例是：把 `trace_id` 和 workOrderId 当 Prometheus 标签、把数据库放进 liveness，并在 5 分钟错误率一超阈值就 page。结果是监控高基数、数据库抖动触发重启风暴、值班告警疲劳；即使 dashboard 很多，用户目标仍不可计算。

## 15. 自检清单

### 信号与相关

- [ ] 日志字段稳定且有真实 trace/span context，不靠自然语言搜索；
- [ ] span name/attributes 低基数，HTTP、executor、outbox、consumer、Python 边界可导航；
- [ ] metric name/单位稳定，标签有允许列表和最坏基数估算；
- [ ] 具体请求通过 trace/log/exemplar 定位，不用 ID 标签；
- [ ] 成功、业务拒绝、权限拒绝、version conflict、dependency timeout、system error 可区分；
- [ ] 日志/trace/metric 不含 Token、密码、Prompt、正文或完整 PII。

### Health 与目标

- [ ] liveness 不依赖外部系统，失败表示重启可能修复；
- [ ] readiness 只纳入接核心流量必需条件，可选依赖单独降级；
- [ ] SLI 明确 eligible/good/bad/窗口/数据源/排除/no-data；
- [ ] SLO 数字是经审批目标，不是从教材复制；
- [ ] error budget 可由原始计数重算，取整/低流量规则明确。

### 告警与反馈

- [ ] page 面向用户症状或明确可行动的先导风险；
- [ ] 长短窗口共同证明持续消耗，瞬时样本有负面测试；
- [ ] 告警含 owner、severity、runbook、dashboard、恢复条件和去重键；
- [ ] no-data、采集/规则/通知故障可发现；
- [ ] 事故后新增故障注入并重跑原验证，而非只写复盘文档。

## 16. 常见误解速查

| 误解 | 为什么错 | 正确边界 |
|---|---|---|
| 日志越多越可观测 | 噪声、成本、泄密和不稳定字段会降低可用性 | 围绕问题设计稳定事件与保留策略 |
| traceId 放 metric label 最好查 | 每次请求几乎生成新序列 | 用 exemplar 或日志/trace 查询 |
| health 是绿的就满足 SLO | health 是瞬时路由/重启信号 | 用窗口内 good/eligible 计算 SLI |
| 所有依赖都放 liveness | 外部故障会触发重启风暴 | liveness 仅内部，readiness 按核心性 |
| 4xx 全是系统错误 | 业务/权限/冲突可为正确契约结果 | 分类指标，分别看系统与业务目标 |
| 一个尖峰就应 page | 短暂噪声导致告警疲劳 | 长短窗口、持续 burn、可行动性 |
| 采样 trace 可直接算准确成功率 | 样本可能有偏、尾部会丢 | SLI 使用完整边界计数并监控采集 |
| 100% SLO 最专业 | 无预算且对正常变化/测量误差脆弱 | 按用户价值与成本设现实目标 |
| 告警恢复就结束 | 相同缺口会复发 | 复盘、修复、故障注入、原预言重跑 |

## 17. 官方主来源与版本边界

以下资料于 **2026-07-17** 核对；版本相关配置应在升级时重新核对，而概念和本章验收仍需以项目锁定版本与故障测试为准。

- [OpenTelemetry：Signals](https://opentelemetry.io/docs/concepts/signals/)：logs、metrics、traces 等信号的职责入口；
- [OpenTelemetry Logs Specification](https://opentelemetry.io/docs/specs/otel/logs/)：日志通过时间、TraceId/SpanId 与 Resource context 相关；
- [OpenTelemetry：Context propagation](https://opentelemetry.io/docs/concepts/context-propagation/)：跨执行单元传播上下文并关联信号；
- [OpenTelemetry：Metrics](https://opentelemetry.io/docs/concepts/signals/metrics/) 与 [Metrics data model](https://opentelemetry.io/docs/specs/otel/metrics/data-model/)：histogram、cardinality 与 exemplar；
- [OpenTelemetry HTTP Metrics Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/http/http-metrics/)：`http.route` 使用低基数 route template，`error.type` 使用可预测值；
- [OpenTelemetry Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/)：跨实现统一 span、metric 与 attribute 的名称和语义；
- [Prometheus：Instrumentation](https://prometheus.io/docs/practices/instrumentation/) 与 [Metric and label naming](https://prometheus.io/docs/practices/naming/)：在线服务的请求/错误/延迟信号及标签基数边界；
- [Prometheus：Alerting practices](https://prometheus.io/docs/practices/alerting/)：症状优先、可行动告警、为瞬时抖动保留余量；
- [Google SRE Book：Service Level Objectives](https://sre.google/sre-book/service-level-objectives/) 与 [Error Budgets](https://sre.google/sre-book/service-best-practices/)：SLI/SLO/SLA、用户相关目标和错误预算；
- [Google SRE Workbook：Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)：burn rate、多窗口多速率告警与校准方法；
- [Spring Boot 4.1：Observability](https://docs.spring.io/spring-boot/reference/actuator/observability.html) 与 [Endpoints/Health Probes](https://docs.spring.io/spring-boot/reference/actuator/endpoints.html)：Micrometer Observation、context propagation、liveness/readiness 及外部依赖边界。

最终原则只有一句：**先把用户承诺写成可计算目标，再用有界、可关联、安全的信号发现和解释偏差；告警驱动行动，事故反馈驱动下一次可重放验证。**
