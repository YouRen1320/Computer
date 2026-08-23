---
schema_version: 2
edition: 2026.2-draft
id: ch.ops.metrics-traces-slo
title: 指标、链路、SLI/SLO、告警与噪声
responsibility: 从用户可感知目标定义 SLI/SLO，使用低基数指标和分布式 trace 诊断错误与延迟，以燃尽率告警控制噪声。
volume: '15'
order: 10
level: L3
status: drafting
path: book/volume-15-production-factorycare/chapters/ch.ops.metrics-traces-slo.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ops.logs-health
version_surfaces:
- opentelemetry-specification
- opentelemetry-semantic-conventions
- opentelemetry-collector
- docker
- docker-compose
- ubuntu-server-26.04
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“指标、链路、SLI/SLO、告警与噪声”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - ops-metrics-traces
  - ops-slo-alert
  covers_topics:
  - ops.metric-type
  - ops.label-cardinality
  - ops.trace-span
  - ops.context-propagation
  - ops.sli
  - ops.slo-error-budget
  - ops.burn-rate-alert
  - ops.alert-runbook
  uses_capabilities:
  - architecture.observability
  - foundation.http-message
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为工单创建链路定义可用性/延迟 SLI、SLO 和多窗口燃尽率告警，注入慢查询与上游 5xx 并用 trace 定位；独立保存可复现工件与判断结果
  covers_topic_groups:
  - ops-metrics-traces
  - ops-slo-alert
  covers_topics:
  - ops.metric-type
  - ops.label-cardinality
  - ops.trace-span
  - ops.context-propagation
  - ops.sli
  - ops.slo-error-budget
  - ops.burn-rate-alert
  - ops.alert-runbook
  uses_capabilities:
  - architecture.observability
  - foundation.http-message
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: load-and-fault-injection-trace-continuity-burn-rate-simulation
- id: diagnose
  kind: fault-diagnosis
  text: 面对“用户 ID 作为指标标签、平均延迟掩盖尾部、对 CPU 告警却无用户影响或 trace 上下文在异步边界丢失”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - ops-metrics-traces
  - ops-slo-alert
  covers_topics:
  - ops.metric-type
  - ops.label-cardinality
  - ops.trace-span
  - ops.context-propagation
  - ops.sli
  - ops.slo-error-budget
  - ops.burn-rate-alert
  - ops.alert-runbook
  uses_capabilities:
  - architecture.observability
  - foundation.http-message
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 指标、链路、SLI/SLO、告警与噪声

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《结构化日志、关联 ID 与健康检查》](ch.ops.logs-health.md)：指标与 trace 必须与已验证日志、关联 ID 和健康状态对齐。
<!-- END GENERATED LEARNING PREREQUISITES -->

## 1. 从“机器忙不忙”转向“用户是否得到正确结果”

CPU 90%、内存 70%、线程池 80% 都可能重要，但它们不能直接回答用户能否创建工单、请求是否在可接受时间内完成、可靠性承诺是否正在被消耗。生产可观测性的第一视角应是用户结果：哪些事件算成功，哪些算失败，在多长窗口内允许多少失败，当前消耗速度是否需要行动。

本章把日志、健康、指标和 trace 连接起来：

- 健康检查决定实例是否重启或接流量；
- 指标把大量事件聚合为可计算的时间序列；
- SLI 把指标解释为用户可感知的好事件比例；
- SLO 给 SLI 一个目标和时间窗口；
- 错误预算表达允许的坏事件；
- 燃尽率表达预算消耗速度；
- 告警在用户目标受威胁时通知人；
- trace 保留单次请求的因果结构，用来定位哪个 span 最慢或最先失败；
- 日志提供事件细节和审计上下文。

完成标准不是搭出一张漂亮大盘，而是能对一次“工单创建变慢/失败”给出完整证据链：用户 SLI 变化、错误预算消耗、多窗口告警触发、同一 trace 保持连续、首个异常叶子 span 指向慢查询或上游 5xx，恢复后噪声消失。

本章使用 Python 标准库和静态 JSON 做确定性模拟，没有运行 Prometheus、Alertmanager、OpenTelemetry SDK/Collector、trace backend 或真实负载。Java API 仍是 FactoryCare 业务事实和真实遥测埋点的拥有者。

## 2. 四种信号不要相互替代

### 2.1 Metrics：聚合趋势

指标适合回答“过去五分钟有多少请求、错误率多少、尾延迟分布怎样”。它们通常不保存每次请求正文，成本可控，适合告警。但标签组合会生成时间序列，设计失误会造成高基数和存储爆炸。

### 2.2 Traces：单次因果路径

trace 由多个 span 组成，记录一次请求跨入口、Java、数据库和上游服务的父子关系、时序、状态和属性。它能回答“慢在什么位置”和“错误从哪个下游传播”，但采样意味着并非每次请求都保留，不能仅靠 trace 计算完整月度 SLO，除非采样与估算经过专门设计。

### 2.3 Logs：离散事件细节

日志适合记录状态转换、错误类别、发布事件和审计线索。日志可与 trace_id/span_id 关联。不要从 ERROR 文本数量直接推导可用性，因为一次失败可能写多条日志。

### 2.4 Health：编排控制信号

健康检查是即时、低成本、有限范围的控制信号。实例 health=UP 不保证业务 SLO 达标；SLO 下降也不一定意味着应重启实例。上一章的 readiness 处理流量，当前章的 SLO 处理用户承诺。

四者的关系可以简化为：

~~~text
用户请求
   |
   +--> 指标：大量请求是否满足目标？ ------> SLO/燃尽率告警
   |
   +--> trace：这一条请求慢/错在哪里？ ---> span 因果链
   |
   +--> 日志：发生了什么事件？ ----------> 细节与审计
   |
   +--> health：实例能否继续接流量？ -----> 编排动作
~~~

## 3. 指标类型：先理解行为，再选名字

Prometheus 官方概念页列出四种核心指标类型。参见 [Prometheus metric types](https://prometheus.io/docs/concepts/metric_types/)。

### 3.1 Counter

Counter 是单调递增累计值，进程重启时可归零。例如：

- http_requests_total；
- work_order_create_errors_total；
- dependency_timeouts_total。

它不适合当前并发数，因为并发会下降。查询请求速率时使用时间窗口上的 rate，而不是比较两个未经重启处理的裸值。

### 3.2 Gauge

Gauge 可以上升或下降。例如：

- inflight_requests；
- queue_depth；
- active_database_connections；
- last_successful_sync_timestamp_seconds。

Gauge 适合“当前状态”，但不应直接成为用户 SLO。队列深可能是原因信号，用户延迟才是结果信号。

### 3.3 Histogram

Histogram 记录观测值分布，例如请求耗时或响应大小。经典 histogram 使用累计 bucket、sum 和 count；原生 histogram 是另一种复合样本模型。官方文档说明 histogram 常用于请求持续时间，并可计算分位数或某阈值内请求比例。

SLO 若要求“95% 工单创建在 300ms 内”，最直接的 SLI 是不超过 300ms 的好事件比例，而不是平均耗时。平均值可能被大量很快请求稀释，掩盖一小批极慢请求。

### 3.4 Summary

Summary 也记录观测并可在客户端计算分位数，但跨实例聚合预计算 quantile 通常没有统计意义。Prometheus 的 [Histograms and summaries](https://prometheus.io/docs/practices/histograms/) 明确展示了不能简单平均实例 quantile，并说明 histogram 可在服务端聚合。选择 histogram/summary 要根据聚合需求、bucket、精度和客户端支持验证，不能只看 API 名字。

### 3.5 FactoryCare 最小指标契约

| 指标 | 类型 | 允许标签 | 用途 |
| --- | --- | --- | --- |
| factorycare_http_requests_total | counter | service、route、method、status_class | 可用性事件 |
| factorycare_http_request_duration_seconds | histogram | service、route、method | 延迟 SLI |
| factorycare_inflight_requests | gauge | service | 饱和度诊断 |
| factorycare_dependency_requests_total | counter | service、dependency、result | 原因诊断 |
| factorycare_work_order_create_total | counter | result、reason_class | 业务路径 SLI 候选 |

route 必须是模板，例如 /work-orders/{id}，而不是原始路径。status_class 用 2xx/4xx/5xx 等有限枚举，避免每个错误正文成为标签。

## 4. 标签基数：每个组合都是成本

### 4.1 基数如何增长

假设一个指标有：

- 5 个 service；
- 30 个 route；
- 5 个 status_class；
- 3 个 environment。

理论上最多 5 × 30 × 5 × 3 = 2250 个标签组合。如果再加入 100000 个 user_id，可能膨胀到 2.25 亿组合。实际并非所有组合都出现，但风险已经从“多一个字段”变为资源耗尽。

禁止作为指标标签的常见值包括 user_id、order_id、request_id、trace_id、邮箱、URL 原始路径、错误消息和任意自由文本。这些值可以在经过安全审查的 trace/log 中出现短标识，但也不能包含 PII。

### 4.2 判断一个标签是否合适

提问：

1. 值集合是否有明确、较小的上界？
2. 值是否由系统控制，而不是用户自由输入？
3. 操作人员是否会稳定地按它聚合或筛选？
4. 删除这个标签后，诊断能否通过 trace/log 完成？
5. 每个服务、实例、租户、区域组合后会产生多少序列？
6. 新 route、异常消息或第三方代码会不会无限扩张？

若无法回答上界，就先不要加。高基数不是“Prometheus 性能优化细节”，而是遥测数据模型错误。

[Prometheus metric and label naming](https://prometheus.io/docs/practices/naming/) 建议指标名有一致语义和单位，并警惕同一指标所有标签维度组合的 cardinality。具体命名还需结合项目客户端库和当前 Prometheus 版本验证。

### 4.3 Exemplars 与关联

如果平台支持 exemplar，可以把少量指标样本关联到 trace，而不是把 trace_id 变成每个样本的普通标签。是否支持、如何存储和采样取决于实际栈，本章没有验证。原则仍是：聚合维度保持低基数，单请求身份留在 trace/log。

## 5. 从事件定义 SLI

### 5.1 SLI 的分子与分母

可用性 SLI 通常表示：

~~~text
good events / valid events
~~~

但“valid events”必须定义清楚。以工单创建为例：

- 2xx 且持久化成功：好事件；
- Java 5xx、数据库超时、上游导致的 5xx：坏事件；
- 用户提交非法数据的 4xx：通常不计入服务端坏事件，但要防止服务错误地把自身故障伪装成 4xx；
- 健康探针、内部压测、机器人请求：是否计入必须声明；
- 客户端取消：要定义服务是否已经超时或完成；
- 重试：按用户操作还是每次 HTTP 尝试计数，需要和产品体验一致。

没有分母定义的“99.9% 可用”没有意义。事件计数还必须共用同一组不变量：`total >= 0`、`0 <= bad <= total`。`total == 0` 是“零流量”，遥测序列缺失是“无数据”；两者都不应被偶发的除零异常或 `0.0` 伪装成业务比率。先返回显式状态，再由告警策略决定零流量保持 pending/不 page，而遥测中断触发 telemetry alert。

### 5.2 延迟 SLI

延迟目标可以定义为“低于阈值的请求比例”：

~~~text
requests completed within 300ms / valid requests
~~~

这比平均耗时更接近用户承诺。平均 100ms 可能由 99 个 10ms 与 1 个 9010ms 组成，那个用户经历了九秒。尾部分布、阈值好事件比例或分位数能揭示这种问题。

阈值必须来自用户体验和业务需求，而不是看当前系统通常多快再随意加 10%。不同操作可有不同阈值：列表查询与创建工单的成本和期望不同。

### 5.3 正确性与新鲜度

可用性和延迟不是唯一 SLI。返回 200 但写错 assignee_id 是错误结果；缓存返回一小时前状态可能违反新鲜度。可增加：

- 正确性：业务不变量满足的事件比例；
- 新鲜度：数据在允许延迟内可见的比例；
- 完整性：应处理事件中未丢失的比例；
- 持久性：确认成功后数据仍可恢复的比例。

这些 SLI 的采集比 HTTP 状态复杂，应由 Java 领域事件和数据验证提供，不能在 Nginx 猜测业务事实。

## 6. SLO 与错误预算

### 6.1 目标与窗口

SLO 是 SLI 在一个明确窗口内的目标，例如“滚动 30 天内，99.9% 的有效工单创建请求成功”。窗口可以滚动或日历周期，二者对预算恢复和报告语义不同。必须写出：

- 服务/功能范围；
- SLI 分子和分母；
- 数据来源；
- 目标百分比；
- 评估窗口；
- 排除规则；
- 数据缺失处理；
- 责任团队和复核周期。

SLO 不是对外合同本身，SLA 可能包含商业承诺和赔偿。不要混用术语。

### 6.2 错误预算

若目标为 99%，允许坏事件比例是 1%。在 100000 个有效事件中，预算是 1000 个坏事件。若目标为 99.9%，预算是 100 个。公式：

~~~text
allowed bad fraction = 1 - objective
remaining budget = allowed bad events - observed bad events
~~~

错误预算把可靠性和发布速度放在同一尺度。预算充足时可承担受控变更；预算快速消耗时应减少风险、优先修复。它不是“允许故意制造错误”，也不是月底清零的免责额度。

### 6.3 边界条件

如果窗口内没有有效请求，SLI 不能简单设为 100%。应定义为无数据、继承上次状态或不评估，并让监控显示数据缺失。丢失遥测也不能默认为好，否则采集故障会让 SLO 变绿。

低流量服务用事件比例可能过于离散，需要更长窗口、合成请求或按时间的可用性信号。选择必须基于业务量。

## 7. 燃尽率：预算消耗有多快

### 7.1 公式

燃尽率定义为实际坏事件比例除以允许坏事件比例：

~~~text
burn rate = observed bad fraction / (1 - objective)
~~~

若 SLO 是 99%，允许 1% 失败：

- 实际 1%：燃尽率 1，按窗口均匀耗尽预算；
- 实际 5%：燃尽率 5；
- 实际 0.2%：燃尽率 0.2。

燃尽率把不同 SLO 目标归一化，便于表达“预算正在多快消耗”。

### 7.2 为什么需要多窗口

短窗口能快速发现严重故障，但一次小尖峰会产生噪声；长窗口稳定，却可能通知太迟。多窗口告警要求短窗口和长窗口同时超过相应阈值：短窗口确认当前故障仍在发生，长窗口确认它已对预算造成足够影响。

本章夹具为了教学采用：

- SLO 99%；
- 短窗口阈值 4；
- 长窗口阈值 2；
- 正常：短窗 0/100，长窗 2/1000，不通知；
- 故障：短窗 8/100，长窗 30/1000，两窗同时超过，通知。

这些数值不是生产推荐阈值。真实阈值应根据窗口长度、目标、通知严重级别、预算消耗百分比和团队响应时间设计，并用历史数据/合成序列验证。

Google SRE Workbook 的 [Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/) 讨论了基于错误预算的告警、多窗口多燃尽率方案、检测时间与 reset time 的权衡。它是设计参考，不能替代你对 FactoryCare 流量和轮值能力的验证。

### 7.3 告警应指向用户症状

CPU 高可以放在诊断面板或容量告警，但如果没有用户影响，不应冒充可用性 SLO 告警。页面通知优先来自错误预算受威胁；CPU、连接池、队列、数据库延迟用于解释原因。

例外是“即将导致不可逆损失”的预测性条件，例如磁盘即将耗尽。这可以有独立容量告警，但要明确它不是 SLO 告警，并给出行动。

## 8. 告警噪声与行动契约

### 8.1 一个可执行告警至少包含

- 用户影响：哪个 SLI、当前值、目标和窗口；
- 燃尽：短/长窗口燃尽率与剩余预算；
- 范围：服务、route、环境、区域；
- 开始时间和持续时间；
- 发布关联：当前制品摘要与最近变更；
- trace 示例链接或安全标识；
- dashboard 和 runbook；
- owner、severity 和升级路径；
- 恢复条件。

“CPU > 80%”没有告诉值班者该做什么。一个真正可 page 的告警必须有立即行动，且延迟处理会增加用户影响。

### 8.2 去重、分组和抑制

同一数据库故障可能让十个 API 实例告警。应按用户症状和根因范围分组，避免每实例一页。全局依赖故障时，可抑制下游重复症状，但不能隐藏用户 SLO 告警。维护窗口和发布期静默必须有审批与自动到期，不能无限期 mute。

### 8.3 恢复与抖动

告警恢复阈值和持续时间要避免在边界附近反复打开/关闭。多窗口本身提供一定稳定性，也可要求连续若干评估满足恢复条件。恢复通知要保留事故关联，方便计算检测、确认、缓解和恢复时间。

### 8.4 Runbook 是代码旁的操作契约

runbook 至少写：

1. 告警含义与非含义；
2. 第一批只读查询；
3. 如何确认用户影响；
4. 最近发布与配置核对；
5. trace/log 的安全查询方式；
6. 常见原因和区分证据；
7. 缓解动作、权限、风险和停止条件；
8. 回滚步骤；
9. 升级联系人；
10. 恢复验证与事后证据。

告警链接不存在的 runbook，应在发布门禁失败。本章夹具只检查路径非空，真实仓库还要检查文件存在、链接可访问和步骤可执行。

## 9. Trace 与 span：保留因果结构

### 9.1 Span 最小语义

一个 span 通常包含 trace ID、span ID、parent span ID、名称、开始/结束时间、状态、属性和事件。span 名应使用稳定操作名，例如 POST /work-orders 或 postgresql.query，不使用原始 URL、SQL 参数或用户 ID。

[OpenTelemetry Traces](https://opentelemetry.io/docs/concepts/signals/traces/) 说明共享 trace_id 与 parent_id 构成层次，span 状态可以是 Unset、Error、Ok。成功并不强制显式标记 Ok；错误状态应与语义约定一致。

### 9.2 上下文传播

同步 HTTP 通过 W3C traceparent 等 carrier 注入/提取。异步线程池和消息队列必须捕获并传播 context；仅复制 trace ID 字符串还不够，父 span、采样标志与 baggage 策略也需一致。

[OpenTelemetry Context propagation](https://opentelemetry.io/docs/concepts/context-propagation/) 说明 Service A 传递 trace ID/span ID，Service B 使用它创建同一 trace 的子 span。来自外部的上下文不可信，baggage 不能携带凭据或 PII。

本章实验的“异步上下文破坏”只是把一个 span 的 trace_id 改掉，用来验证连续性检查。真实 Java CompletableFuture、虚拟线程、消息消费者或调度器需要各自集成测试。

### 9.3 找“首个可信原因”

根 span 慢，只说明端到端慢；父 span Error，可能只是传播下游错误。诊断应沿树向下：

- 找状态为 Error 的最深相关 span；
- 如果无 Error，找耗时占比最大的叶子或关键子 span；
- 对比同 route 的正常 trace；
- 查看 span 事件、错误类型和部署版本；
- 用指标确认不是单样本偶然；
- 用日志补充状态转换或受控错误详情。

本章夹具的慢查询 trace 中，根 POST /work-orders 1320ms、Java 1280ms、postgresql.query 1210ms，因此叶子数据库 span 是首个慢点。上游 5xx trace 中，inventory.http 是错误叶子。真实系统还需考虑并行 span、排队时间、自耗时和采样偏差，不能永远取最长叶子。

### 9.4 Sampling 的边界

全量 trace 成本可能很高。头部采样在请求开始时决定，无法提前知道结果；尾部采样可优先保留错误/慢请求，但需要 Collector 缓冲和资源。采样策略必须保留代表性正常流量和关键错误，并监控丢弃。SLO 指标应来自完整或可校正的事件流，不应直接用偏向错误的尾采样 trace 计算错误率。

本章没有验证任何采样器。

## 10. FactoryCare 工单创建观测设计

### 10.1 用户事件

有效事件：通过认证、请求模式合法并进入创建流程的 POST /work-orders。好事件：在目标时间内持久化成功并返回正确 2xx。坏事件：Java 5xx、数据库超时、上游 5xx 导致创建失败、超过延迟阈值。业务拒绝（例如非法状态）是否进入分母，由产品语义明确。

### 10.2 Java 埋点

Java 负责：

- 在 HTTP 边界记录 route 模板、method、status_class 和 duration；
- 以领域结果记录 create success/failure reason class；
- 创建 server span；
- 数据库调用创建 client span；
- 外部库存服务调用创建 client span；
- 在异步边界传播 context；
- 错误状态与异常事件使用稳定规则；
- 不把工单正文、人员信息或 SQL 参数放入属性；
- 将 release digest 作为低基数资源属性，而非每次日志自由文本。

Nginx 可提供入口请求指标与 trace context 转发，但不能决定工单业务成功。PostgreSQL 指标解释连接、查询和锁，但业务 SLI 仍由 Java 用户路径定义。

### 10.3 Dashboard 的阅读顺序

1. SLO 状态、剩余预算和当前燃尽。
2. 按 route/status_class 的错误和延迟分布。
3. 最近发布和配置变更。
4. 依赖结果、数据库延迟、连接池和队列。
5. 代表性 trace。
6. 关联日志。

把 CPU 图放在最上方会诱导“机器指标先入为主”。它适合原因区，不适合替代用户结果。

## 11. 运行基础示例

进入 examples/encyclopedia/ch.ops.metrics-traces-slo：

~~~bash
./verify.sh
~~~

reliability.py 验证：

- user_id 等标签被拒绝；
- 可用性 SLI、延迟阈值好事件比例和燃尽率公式；
- 多窗口必须同时超过阈值；
- 异步子 span 保持 trace ID 并指向存在的父 span。

先预测 1000 次中 20 个坏事件、目标 99% 的燃尽率。坏事件比例 2%，允许 1%，结果为 2。若目标改为 99.9%，允许 0.1%，相同错误率的燃尽率为 20。目标越高，同样故障消耗越快。

基础代码不执行 PromQL，也不模拟 counter reset；它只验证数学与契约。

## 12. 运行综合实验

进入 labs/encyclopedia/ch.ops.metrics-traces-slo：

~~~bash
./verify.sh
python3 slo_trace_lab.py
~~~

reliability-fixture.json 声明为受控模型。正常窗口和故障窗口分别提供事件计数与延迟样本；metric_contract 提供类型与标签；两条 trace 注入慢查询和上游 5xx。

Oracle 要求：

1. 所有标签在低基数允许集合中。
2. 正常短/长窗口不 page。
3. 故障短/长窗口同时越阈并 page。
4. 故障使可用性 SLI 下降。
5. 故障使 300ms 内的延迟好事件比例下降。
6. 每条 trace 只有一个根、同一 trace ID、父 span 均存在。
7. 慢查询定位 postgresql.query，上游错误定位 inventory.http。
8. 告警链接 runbook。

输出显示 burn rate、SLI 和 trace cause，使判断可复现。

### 12.1 注入高基数

向第一个指标 labels 加 user_id。预期 low_cardinality_labels=false，首证据是指标名与违规标签。修复是删除标签，用日志/trace 安全查单次请求，而不是提高 Prometheus 限额。

### 12.2 注入平均值误导

手工计算 fault durations 的平均数，再和 300ms 阈值比较；然后比较 latency_good_fraction。你会看到一个平均值无法表达“多少用户达标”。实际系统使用 histogram bucket 或原生 histogram，不能把本地数组算法直接复制到生产。

### 12.3 注入异步断链

把数据库 span 的 trace_id 改成另一值。预期 trace_continuity=false。首证据是第一个不同 trace ID 的 span。修复真实系统时，应检查提交任务处是否捕获 context、worker 是否恢复，而不是把日志中的 ID 后处理成一样。

### 12.4 注入单窗口尖峰

让 fault short 保持 8/100，但 long 改为正常 2/1000。预期 fault_pages=false，因为长窗未越阈。短尖峰仍可出现在 dashboard 或 ticket 级告警，但不必立即 page。生产是否如此需要根据真实风险决定。

## 13. 公开练习与私有参考

exercises 下的 design 故意：

- 把 user_id 作为标签；
- 只看 average；
- 用 cpu_percent 作为用户告警；
- 在 worker 创建新 trace ID。

未改 starter 的 `verify.sh` 应返回 41/`EXPECTED_RED`。你要修改自己的练习副本，使其使用低基数标签、阈值好事件比例、SLO burn rate 和连续上下文；完成后原验证器返回 0/`EXERCISE_GREEN`，partial/unknown/基础设施失败返回 43。不要改测试来迎合错误设计。

solutions-private 提供最小绿灯参考，不包含真实 SDK、并发或后端查询，因此不能作为生产实现。

## 14. 故障诊断矩阵

| 现象 | 失败阶段 | 首个可信证据 | 常见错误动作 | 正确方向 |
| --- | --- | --- | --- | --- |
| user_id 进入标签 | instrumentation/schema | metric 名与标签集合 | 扩容监控 | 删除高基数标签，迁移到 trace/log |
| 平均延迟正常但用户投诉 | SLI 定义 | histogram 分布或阈值好事件比例 | 调高平均告警 | 定义尾部/阈值 SLI |
| CPU 告警无用户影响 | alert policy | SLI 与错误预算仍正常 | 立即回滚 | 降为诊断/容量信号 |
| 异步 span 新 trace | context propagation | 第一个断裂 span | 后处理改 ID | 在提交/消费边界传播 context |
| 故障不触发告警 | SLO query/data | 分子、分母、窗口与缺失数据 | 降阈直到响 | 修正事件定义和查询 |
| 正常波动持续 page | alert policy | 短/长燃尽时间序列 | 永久 mute | 多窗口、分组、恢复条件 |
| trace 指向根 span 慢 | diagnosis | 子 span 自耗时/状态 | 责怪入口服务 | 沿父子关系找首个慢/错 span |
| runbook 链接失效 | release gate | 404 或权限拒绝 | 在告警备注“找某人” | 版本化 runbook 并门禁验证 |

日志里的 ERROR 和 trace 的 Error 仍要与 HTTP/业务结果核对。异常可能被正确降级而不影响 SLI；也可能返回 200 却写入错误数据。Java 业务事实是最终边界。

## 15. 如何验证 PromQL 而不是“看起来合理”

真实实现时，至少用合成时间序列测试：

- counter 重启归零；
- 某个实例短暂缺数据；
- 只有短窗尖峰；
- 长时间低速燃烧；
- 大规模持续故障；
- route 标签新增；
- 4xx 排除规则；
- 部分区域故障；
- 零流量；
- 遥测采集停止；
- 发布前后分组。

每个场景写预期 SLI、burn rate、是否 page 和何时恢复。Google SRE Workbook 也强调评估检测时间和 reset time。不要等生产第一次告警才验证表达式。

本章 fixture 是这类测试的最小模型，但没有 PromQL 语法、Prometheus staleness 和 Alertmanager 行为。真实测试必须使用与生产相同版本的规则评估器或受支持测试工具。

## 16. 常见误区

### 16.1 “标签越多，诊断越方便”

指标不是明细数据库。高基数会增加存储和查询风险，甚至让真正的事故期间监控不可用。单请求维度放 trace/log。

### 16.2 “P95 是 200ms，所以 95% 一定在 200ms 内”

分位数是估算，精度取决于 histogram bucket/原生 histogram/summary 算法与聚合。必须理解误差边界。若 SLO 就是 300ms 阈值，直接计算不超过该阈值的比例通常更清晰。

### 16.3 “目标 99.9% 就是每月允许固定分钟数”

按请求事件和按时间计算会得出不同预算；窗口长度和流量变化也影响。必须从 SLI 定义推导，不能只背分钟表。

### 16.4 “所有故障都要 page”

page 只用于必须立即人工行动的高紧迫事件。低速预算消耗、容量趋势和已自动恢复尖峰可以进入 ticket 或 dashboard。否则值班者会对噪声麻木。

### 16.5 “Trace 采样后仍能直接算准确错误率”

偏向保留错误的尾采样会改变样本分布。SLO 用完整指标事件流；trace 用于解释代表性请求。

### 16.6 “加 OpenTelemetry agent 就自动完成观测设计”

agent 可自动创建通用 span/指标，但无法替你定义 FactoryCare 的好事件、业务错误类别、敏感属性、SLO 和 runbook。自动 instrumentation 也需检查版本、重复 span、性能和上下文边界。

## 17. 面试与口述验收

120 秒参考：

“Counter 单调累计，Gauge 可上下变化，Histogram 记录分布；指标标签必须低基数，user_id/request_id 属于 trace 或日志。SLI 是好事件与有效事件比例，SLO 是目标加窗口，错误预算是允许坏事件，燃尽率等于实际坏比例除以允许坏比例。多窗口让短窗负责速度、长窗控制噪声。告警优先由用户 SLI/预算触发，CPU 是原因信号。Trace 由同一 trace ID 和父子 span 组成，异步边界必须传播 context；诊断沿树找到首个慢或 Error 的相关叶子 span。”

越界反例：让 Nginx 根据 HTTP 200 判断“工单业务创建正确”。Nginx不知道持久化和领域不变量，业务事实必须由 Java 提供。

独立构建题：为 POST /work-orders 定义可用性和 300ms 延迟 SLI、99% 教学 SLO、多窗口燃尽告警、低基数指标、trace span 树和 runbook。注入数据库慢查询、上游 5xx、单窗尖峰、异步断链，保存正常/失败/修复后证据。

诊断题：看到 CPU 95%、平均延迟 180ms、用户投诉超时，先检查阈值好事件比例和尾部分布，再按 trace 找慢 span；不能因 CPU 高就直接宣告根因。

## 18. 官方资料、版本与未验证边界

本章在 2026-07-24 核对：

- [Prometheus metric types](https://prometheus.io/docs/concepts/metric_types/)：Counter、Gauge、Histogram、Summary 的官方语义。
- [Prometheus histograms and summaries](https://prometheus.io/docs/practices/histograms/)：count/sum、bucket、quantile 与跨实例聚合边界。
- [Prometheus metric and label naming](https://prometheus.io/docs/practices/naming/)：名称、单位与标签维度设计。
- [OpenTelemetry Traces](https://opentelemetry.io/docs/concepts/signals/traces/)：span、父子关系、status 与 link。
- [OpenTelemetry Context propagation](https://opentelemetry.io/docs/concepts/context-propagation/)：跨服务注入/提取和安全边界。
- [W3C Trace Context](https://www.w3.org/TR/trace-context/)：traceparent 与 tracestate。
- [Google SRE Workbook: Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)：错误预算告警、多窗口/燃尽率与噪声权衡。

本地实际验证只需要 Python 标准库。没有验证 Prometheus/PromQL、Alertmanager、OpenTelemetry Java SDK 或 agent、Collector、OTLP exporter、trace backend、exemplar、sampling、生产流量、真实故障注入、通知渠道和人工 runbook。Docker/Compose 是否安装也不影响这个夹具。任何生产结论必须在实际版本和拓扑中重跑。

## 19. 章节验收清单

- [ ] 我能区分 metrics、traces、logs 和 health 的职责。
- [ ] 我能正确选择 Counter、Gauge、Histogram，并说明 Summary 聚合限制。
- [ ] 我能估算标签组合，并拒绝 user_id/order_id/request_id。
- [ ] 我能写出可用性与延迟 SLI 的分子、分母和排除规则。
- [ ] 我能从目标计算错误预算和燃尽率。
- [ ] 我能解释短窗口与长窗口为什么要同时使用。
- [ ] 我能区分 SLO page、容量告警和诊断指标。
- [ ] 我能写出含用户影响、燃尽、runbook 和恢复条件的告警。
- [ ] 我能验证 trace ID、父 span、唯一根和异步连续性。
- [ ] 我能沿 trace 找到慢查询或上游 5xx 的首个可信 span。
- [ ] 我能运行 examples、lab 和 private solution 的绿灯。
- [ ] 我知道 public exercise 的精确 starter 返回 41、完成态返回 0、其他失败返回 43。
- [ ] 我能明确说出本地 fixture 没有验证哪些生产能力。
