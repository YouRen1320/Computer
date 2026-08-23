---
schema_version: 2
edition: 2026.2-draft
id: ch.ops.logs-health
title: 结构化日志、关联 ID 与健康检查
responsibility: 用结构化日志、关联 ID 和分层健康检查暴露系统状态，区分存活、就绪和依赖退化，不记录敏感业务正文。
volume: '15'
order: 9
level: L3
status: drafting
path: book/volume-15-production-factorycare/chapters/ch.ops.logs-health.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ops.compose-services
- ch.architecture.observability-slo
version_surfaces:
- opentelemetry-specification
- opentelemetry-semantic-conventions
- opentelemetry-collector
- docker
- docker-compose
- nginx
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
  text: 在 120 秒内解释“结构化日志、关联 ID 与健康检查”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - ops-structured-logging
  - ops-health-check
  covers_topics:
  - ops.structured-log
  - ops.correlation-id
  - ops.log-level
  - ops.log-redaction
  - ops.liveness
  - ops.readiness
  - ops.dependency-health
  - ops.health-degradation
  uses_capabilities:
  - architecture.observability
  - foundation.docker-runtime
  - foundation.http-message
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为一次跨 Nginx、Java API 和 PostgreSQL 请求传播关联 ID，输出脱敏 JSON 日志并实现存活/就绪/降级健康矩阵；独立保存可复现工件与判断结果
  covers_topic_groups:
  - ops-structured-logging
  - ops-health-check
  covers_topics:
  - ops.structured-log
  - ops.correlation-id
  - ops.log-level
  - ops.log-redaction
  - ops.liveness
  - ops.readiness
  - ops.dependency-health
  - ops.health-degradation
  uses_capabilities:
  - architecture.observability
  - foundation.docker-runtime
  - foundation.http-message
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: correlation-trace-test-health-state-matrix-log-schema-audit
- id: diagnose
  kind: fault-diagnosis
  text: 面对“健康端点始终 200、关联 ID 每层重建、日志记录 Token/PII 或依赖短暂失败导致进程重启风暴”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - ops-structured-logging
  - ops-health-check
  covers_topics:
  - ops.structured-log
  - ops.correlation-id
  - ops.log-level
  - ops.log-redaction
  - ops.liveness
  - ops.readiness
  - ops.dependency-health
  - ops.health-degradation
  uses_capabilities:
  - architecture.observability
  - foundation.docker-runtime
  - foundation.http-message
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 结构化日志、关联 ID 与健康检查

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Compose 多服务、配置、健康检查与依赖》](ch.ops.compose-services.md)：健康检查必须作用于真实多服务依赖和启动/重启行为。
- [《日志、指标、追踪、SLO 与告警闭环》](../../volume-06-enterprise-architecture/chapters/ch.architecture.observability-slo.md)：日志、健康、指标和链路必须共享既有可观测性语义。
<!-- END GENERATED LEARNING PREREQUISITES -->

## 1. 为什么“能看到日志”和“接口返回 200”都不等于可观测

生产故障最令人无助的状态不是完全没有日志，而是日志很多却无法回答三个问题：哪一次请求出了问题、它经过了哪些服务、系统当时是否应该接流量。普通文本日志、随手生成的 request ID 和永远返回 200 的 health 接口，往往制造一种虚假的可观测性。

本章建立两个相互配合的契约。日志契约让机器和人都能稳定查询事件，并用同一个关联上下文串起 Nginx、Java API 和 PostgreSQL。健康契约把“进程是否需要重启”“实例是否可以接收流量”“非关键依赖是否退化”分开表达。二者都只暴露必要状态，不记录 Token、个人信息、请求正文或数据库内容。

完成本章后，你应能面对“健康端点始终 200、每层重建关联 ID、日志出现认证头、短暂数据库抖动导致容器重启风暴”时，指出失败层和首个可信证据，而不是先重启所有服务。

本章实验只审计本地 JSON 夹具和确定性健康矩阵。它没有启动 Nginx、Java、PostgreSQL、Docker Compose 或 OpenTelemetry 后端。FactoryCare 的实际业务与状态事实仍由 Java API 拥有；Python 只负责演示日志模式和探针判定。

## 2. 结构化日志是一份数据契约

### 2.1 从句子变成事件

文本日志常写成：

~~~text
user 42 loaded order 991 successfully
~~~

这句话同时混合事件类型、个人标识、对象标识和结果，字段顺序不稳定，也可能泄漏业务数据。结构化日志应先定义“发生了什么”，再附上可控属性：

~~~json
{
  "timestamp": "2026-07-24T08:00:00Z",
  "severity": "INFO",
  "service": "java-api",
  "event": "work-order.loaded",
  "correlation_id": "request-demo-0001",
  "trace_id": "11111111111111111111111111111111",
  "span_id": "2222222222222222",
  "attributes": {
    "route": "/work-orders/{id}",
    "status": 200
  }
}
~~~

这里没有用户姓名、手机号、认证头、工单正文或真实工单 ID。route 使用模板而不是原始路径，避免每个 ID 形成一个新查询维度。结构化的关键不是 JSON 外观，而是稳定字段语义、类型、基数、敏感分级、所有者和版本。

### 2.2 最小字段集合

一个适合 FactoryCare 的基础日志模式可以包含：

| 字段 | 目的 | 约束 |
| --- | --- | --- |
| timestamp | 事件发生时间 | UTC、明确格式；采集时间另列 |
| severity | 过滤紧急程度 | 固定枚举，不用随意字符串 |
| service | 事件来源 | 稳定低基数服务名 |
| event | 事件类型 | 稳定的领域/技术事件名 |
| correlation_id | 单次交互检索 | 不含业务含义，不信任外部值 |
| trace_id/span_id | 与分布式链路关联 | 遵循遥测上下文 |
| attributes | 可查询属性 | 允许清单、类型稳定、禁止正文 |
| error.type | 错误类别 | 类名或稳定代码，不复制敏感消息 |
| deployment | 制品/环境关联 | 发布摘要或安全短标识 |

OpenTelemetry 官方日志概念页列出的 Log Record 顶层字段包括 Timestamp、ObservedTimestamp、TraceId、SpanId、TraceFlags、SeverityText、SeverityNumber、Body、Resource、InstrumentationScope、Attributes 和 EventName。参见 [OpenTelemetry Logs](https://opentelemetry.io/docs/concepts/signals/logs/)。本章夹具不是 OTLP 记录，但字段选择与“日志可和 trace 关联”的方向一致。

字段变化属于数据契约变化。把 status 从整数改成字符串、把 event 改名或把 service 从固定名改为实例名，都会影响查询、告警和留存成本。应像 API 一样评审和测试。

## 3. 日志级别：描述行动，不描述情绪

### 3.1 一套可执行的语义

可采用以下约定：

- DEBUG：短期诊断所需的内部步骤，默认不在生产长期启用；仍不能记录敏感值。
- INFO：预期业务/系统生命周期事件，例如启动完成、配置模式版本、工单创建成功的匿名统计事件。
- WARN：请求仍完成或系统仍可服务，但发生了需要关注的退化、重试或接近限制。
- ERROR：当前操作失败，需要错误预算或人工处置；不等于进程必须退出。

日志级别应与事件结果一致。客户端提交非法参数通常是预期的 4xx，不应该每次都打 ERROR；数据库连接失败导致当前创建工单失败，则是 ERROR；一次自动重试成功可以是 WARN，并记录 retry_count 和稳定错误类别。

级别不能替代状态码、指标或 trace。ERROR 日志数量不一定等于用户错误数：一次失败可能写多条日志，一个批处理错误也可能影响大量用户。用户影响由 SLI 衡量，日志用于解释上下文。

### 3.2 避免异常风暴

在循环或重试中每次写完整堆栈，会扩大故障影响并增加成本。可采用第一次详细、后续聚合、恢复时写一条状态转换的策略。必须保留总次数、时间窗口、依赖名和最终结果。限流不能把唯一证据吞掉，所以应配合指标计数。

Java 异常日志应在边界层记录一次。底层组件添加上下文并抛出，上层统一决定 HTTP 响应和日志事件；不要每层 catch、打印、再抛，造成同一失败多份 ERROR。

## 4. 关联 ID、trace ID 与信任边界

### 4.1 关联 ID 的职责

关联 ID 是为了让操作者用一个键找到同一次用户交互的相关日志。它可以是应用自定义的短期随机标识，但应满足：

- 不编码用户、租户、手机号、工单号或时间敏感信息；
- 长度与字符集有限，避免日志注入和存储滥用；
- 入口验证，不合格则生成新值；
- 下游传播同一个值，不在每层重建；
- 返回给调用方时使用明确响应头；
- 进入异步消息时作为元数据，而不是业务正文；
- 不用它作为鉴权或幂等键。

外部传入的 ID 是不可信输入。应限制格式、长度和可见字符；拒绝换行等日志注入字符。即便格式合法，也不能据此相信调用者身份。

### 4.2 trace context 的职责

trace ID 用于把多个 span 组织为一条分布式因果链；span ID 表示一次操作，parent span 表示父子关系。关联 ID 可以与 trace ID 相同，也可以分开，但团队必须规定映射，避免三个不同的“request-id”相互冲突。

[W3C Trace Context](https://www.w3.org/TR/trace-context/) 定义 traceparent 和 tracestate 的 HTTP 传播格式。[OpenTelemetry Context propagation](https://opentelemetry.io/docs/concepts/context-propagation/) 说明发送方把上下文注入 carrier，接收方提取；默认 propagator 使用 W3C Trace Context。官方文档还明确提醒：来自外部服务的上下文可能被伪造，向外发送内部上下文也可能暴露信息；baggage 中不要放凭据、API key 或 PII。

因此“复用同一个 trace ID”不是复制任意 header。入口需要用标准解析器验证 traceparent，决定接受、丢弃或新建根 span；下游使用 SDK 注入。不要手写字符串切片作为生产解析器。

### 4.3 Nginx → Java → PostgreSQL

理想路径如下：

1. Nginx 接收请求，验证/生成 correlation ID，并把它转发给 Java。
2. Nginx access log 使用路由模板、状态码、耗时和关联 ID，不记录认证头或正文。
3. Java 提取 correlation ID 与 trace context，创建 server span，把二者放入受控日志上下文。
4. Java 调用数据库时创建 client span；SQL 只记录操作类型和安全的语句模板属性，不记录绑定参数。
5. 数据库驱动/遥测把 span 与 Java 父 span 关联。
6. Java 响应携带 correlation ID；Nginx 完成日志仍使用同一值。
7. 日志平台可按 correlation_id 查询，trace 后端按 trace_id 显示因果关系。

PostgreSQL 本身未必理解应用关联 ID。通常由驱动 span、连接标签或安全注释关联，具体实现需评估性能与敏感风险。本章夹具把 PostgreSQL 当成可见的第三层事件，只验证 ID 一致，不声称真实数据库日志已完成该能力。

### 4.4 异步边界

线程池、消息队列和定时任务可能丢失当前上下文。提交任务时捕获上下文，消费时显式恢复并创建子 span；若异步工作有独立生命周期，可使用 span link 表达因果关联。不要依赖线程本地变量自动跨线程。

OpenTelemetry 的 traces 概念页说明，共享 trace_id 和 parent_id 能组成 trace；上下文传播使不同位置生成的 span 得以关联。参见 [OpenTelemetry Traces](https://opentelemetry.io/docs/concepts/signals/traces/)。真正的 Java 异步传播必须由所选 SDK/agent 和框架集成测试，本章没有验证。

## 5. 脱敏：从采集前阻断

### 5.1 禁止字段优于事后擦除

FactoryCare 日志至少禁止：

- Authorization、Cookie、Set-Cookie；
- token、password、secret、private key；
- 完整请求与响应正文；
- 手机、邮箱、地址、身份证等 PII；
- 数据库连接串和查询参数；
- 上传文件内容；
- AI prompt、模型原始输出中可能含有的业务正文。

优先使用字段允许清单。日志调用者只能提交 route、method、status_class、duration bucket、error code 等安全字段；类型系统和测试拒绝敏感字段名。出口脱敏是第二道防线，不是第一道。

“把值改成 REDACTED 后保留字段”也可能泄漏事实，例如日志出现 password 字段就说明程序曾接触并尝试记录它。实验因此只要看到禁止键，即使值是 null，也判失败。

### 5.2 错误消息与堆栈

异常消息可能包含 URL、SQL、文件路径、用户输入或第三方响应。对外 HTTP 返回稳定 error code 和关联 ID；内部日志记录错误类别、受控上下文和经过审查的堆栈。不要把外部服务完整响应写入日志。必要的原始证据应进入权限更严、保留更短的事件附件流程，并经过安全审查。

### 5.3 数据生命周期

日志安全不止“写什么”，还包括谁能看、保存多久、能否删除、跨境与备份。开发、测试、生产应分离索引和权限。调试级别必须有自动到期。日志平台访问也要审计。教材只验证字段，不验证真实日志存储、访问控制、保留或删除，这些必须列入未验证边界。

## 6. 健康检查的三个问题

### 6.1 Liveness：这个进程是否无法自愈

存活探针回答“是否应重启容器/进程”。它应聚焦进程内部不可恢复状态，例如事件循环死锁、主线程无法推进或关键内部不变量破坏。不要把短暂数据库或第三方服务失败放进 liveness，否则依赖抖动会让所有实例同时重启，加重连接风暴和冷启动。

[Kubernetes Liveness, Readiness, and Startup Probes](https://kubernetes.io/docs/concepts/workloads/pods/probes/) 说明 liveness 失败会触发容器重启，并警告错误实现可能造成级联失败。即使当前用 Docker Compose 而非 Kubernetes，这个语义边界仍适用。

### 6.2 Readiness：这个实例现在能否接流量

就绪探针回答“是否应该把新请求路由到实例”。启动尚未完成、数据库这一关键依赖不可用、迁移不兼容或实例正在排空时，readiness 应失败。失败通常从负载均衡目标中移除实例，而不是立即重启。

就绪检查要快、有超时、开销低，避免每秒执行重型查询。数据库可执行一个受控轻量探测或检查连接池状态，但必须证明它与业务关键路径有足够相关性。只检查 TCP 端口打开可能过于浅，只执行完整业务写入又可能过重。

### 6.3 Startup：慢启动的保护窗口

启动探针回答“应用是否完成启动”。Kubernetes 官方文档说明，配置 startup probe 后，在它成功前不会执行 liveness/readiness，从而给慢启动应用留出初始化时间。Compose 的机制和语法不同，不能把 Kubernetes 行为原样假设到 Compose；需要根据实际编排器验证 start period、interval、timeout、retries 和依赖启动行为。

### 6.4 退化不是死亡

可选 AI 建议服务不可用时，核心工单创建仍能运行，系统可以报告 DEGRADED，但 readiness 保持通过；Java 业务层应关闭可选功能、返回明确降级结果并产生指标。PostgreSQL 不可用时，如果核心功能无法正确服务，则 readiness 失败但 liveness 保持通过。进程死锁时，两者都失败。

健康矩阵比一个布尔值更准确：

| 场景 | 状态 | Liveness | Readiness | 动作 |
| --- | --- | --- | --- | --- |
| 启动中 | STARTING | 200 | 503 | 等待，不接流量 |
| 正常 | UP | 200 | 200 | 接流量 |
| PostgreSQL 不可用 | NOT_READY | 200 | 503 | 摘流，不重启风暴 |
| 可选 AI 不可用 | DEGRADED | 200 | 200 | 核心服务继续，告警/指标 |
| 进程死锁 | DOWN | 503 | 503 | 允许编排器重启 |

这是本章夹具的教学契约，不是所有系统的唯一答案。关键依赖由业务能力决定：只读页面可能在数据库短暂不可写时仍能部分服务，健康端点也可按能力暴露详细矩阵。

## 7. 健康端点的 HTTP 与安全契约

### 7.1 状态码必须有语义

/health/live 成功返回 200，失败返回非 2xx；/health/ready 同理。不能永远 200 再把 DOWN 写进 JSON，因为许多探针只读状态码。响应体应短小、稳定，并禁止暴露主机、端口、连接串、依赖错误正文、版本漏洞或凭据信息。

面向公网的健康端点只给出最低必要信息。详细依赖状态可放到内部管理端口，配合网络限制和认证。即便是内部端点，也不要返回秘密。

### 7.2 超时与缓存

探针自身必须有明确超时，且小于编排器 timeout。健康请求不应被 CDN 或代理缓存；否则实例已经失败，代理仍可能返回旧 200。Nginx 要正确转发探针状态码，不应把上游 503 重写为 200 的品牌错误页。

每个依赖检查应有独立超时，避免一个慢依赖拖死健康线程池。健康端点也需要并发和频率保护，防止探针成为压力源。

### 7.3 状态转换要可观测

状态从 UP 变为 DEGRADED 或 NOT_READY 时写一次结构化事件并增加指标；持续处于同一状态时不要每次探针都写 WARN。恢复时写对应事件。这样能看到转换而不产生每秒日志噪声。

健康检查不替代业务 SLI。一个服务可以 health=UP 但所有用户请求都因错误业务配置返回 500；也可以 health=DEGRADED 但核心 SLO 完全满足。下一章用指标、trace 和 SLO补齐用户视角。

## 8. Spring Boot 与 Compose 的实现边界

Java 服务可以通过 Spring Boot Actuator 暴露 liveness/readiness 组，但你仍要定义哪些组件属于哪一组、端点暴露范围和状态映射。框架默认值不是业务决策。可查阅 [Spring Boot Actuator endpoints](https://docs.spring.io/spring-boot/reference/actuator/endpoints.html) 的当前版本文档，再针对项目版本验证。

Docker Compose healthcheck 可用 test、interval、timeout、retries、start_period 等字段；depends_on 的健康条件影响启动顺序，但不会替你设计运行时故障恢复。Nginx upstream 是否自动摘除、Compose 是否重启、应用是否降级，必须在真实拓扑中分别验证。

本章不启动这些组件，所以只给出目标状态，不宣称某个配置已经生产可用。

## 9. 运行基础示例

进入 examples/encyclopedia/ch.ops.logs-health：

~~~bash
./verify.sh
~~~

observability.py 验证三件事：

1. 格式合法的 incoming correlation ID 被原样保留，不在 Java 层重建。
2. JSON 日志只能使用允许级别，并在提交禁止字段时立即失败。
3. 健康矩阵区分 STARTING、UP、NOT_READY、DEGRADED 和 DOWN。

请先预测再实验。把属性加入 authorization=null，仍应失败，因为字段本身越界。把 optional_provider_ok 改为 false，readiness 仍为 200，但状态为 DEGRADED。把 postgres_ok 改为 false，liveness 为 200、readiness 为 503。

测试绿灯只证明纯函数行为，不证明真实日志框架 MDC、异步 executor、Nginx header 或探针部署正确。

## 10. 运行综合实验

进入 labs/encyclopedia/ch.ops.logs-health：

~~~bash
./verify.sh
python3 log_health_lab.py
~~~

telemetry-fixture.json 包含一次跨 nginx、java-api、postgresql 的受控请求。三层共享 correlation_id 和 trace_id，span_id 不同；attributes 只有 route 模板、HTTP 方法、状态、SQL 操作类型与耗时桶。夹具不含敏感业务正文。

Oracle 同时要求：

- 每条日志键集合完全等于约定 schema；
- 任意嵌套位置都没有禁止字段；
- 三层 correlation ID 与入口相同；
- 三层 trace ID 与入口相同；
- 三个服务都出现；
- 五种健康场景与预期矩阵完全一致。

故障注入建议：

1. 把 Java 记录的 correlation_id 改为 request-rebuilt-0002，确认 correlation_continuity 失败。
2. 在 Nginx attributes 加 authorization=null，确认 log_redaction 失败。
3. 把 critical-dependency-down 的 readiness_http 期望改为 200，确认 health_matrix 失败。
4. 删除 postgresql 记录，确认 all_layers_visible 失败。
5. 改完恢复，再用原 verify.sh 重跑，不换验证标准。

输出里的 unverified_external_boundaries 是验收的一部分。报告如果只写“全部通过”而不写这些边界，就会夸大证据。

## 11. 公开练习为什么应当红

`exercises/encyclopedia/ch.ops.logs-health` 故意在每层重建 ID、声明记录了敏感字段，并让探针始终 200。未改 starter 运行 `verify.sh` 会看到测试失败并返回 41/`EXPECTED_RED`。你的任务不是修改测试期望，而是让三个服务复用入口 ID、移除敏感字段，并根据 process/database 状态区分 liveness 与 readiness；完成后原验证器返回 0/`EXERCISE_GREEN`，partial/unknown/基础设施失败返回 43。

solutions-private 是参考策略，绿灯只能证明这个小模型。真实 Java 应由 Controller/filter、日志上下文、HTTP client、数据库 instrumentation 和健康组件共同实现，并增加并发、超时与异步传播测试。

## 12. 从现象定位首个可信证据

### 12.1 健康端点始终 200

失败阶段：健康状态映射或代理转发。首证据：在已知数据库不可用场景直接请求实例的 readiness，记录 HTTP 状态和简化响应；再比较通过 Nginx 的状态。如果实例返回 503、代理返回 200，问题在代理重写；如果实例也返回 200，问题在 Java 健康组或状态映射。

不要先看容器是否 Running。Running 只说明主进程尚未退出，不证明可接流量。

### 12.2 每层 ID 不同

失败阶段：上下文提取/注入。首证据：同一受控请求的 Nginx access log、Java ingress log、Java outbound span 与数据库 client span。找到第一个变化边界：入口就不同，是解析/生成规则；Java 入站相同但出站不同，是 client instrumentation；线程池后不同，是异步上下文丢失。

不要通过搜索时间相近的日志猜测关联，这会在并发下产生错误结论。

### 12.3 日志含 Token 或 PII

失败阶段：日志采集前。首证据：规则编号、事件类型、字段路径和日志记录位置，不复制值。立即限制日志访问与传播，评估是否属于凭据泄漏并执行轮换。修复日志调用、序列化策略和字段允许清单，再清理/缩短已有数据生命周期。

只加一个正则替换不算完整修复。

### 12.4 依赖抖动引发重启风暴

失败阶段：liveness 依赖设计。首证据：数据库失败时间、liveness 失败、容器 restart count 和实例连接重建的时间线。如果依赖失败直接使 liveness 503，应将其移到 readiness 或退化状态，并用 startup/threshold 防止瞬时故障放大。

修复后要重新注入依赖抖动，证明实例被摘流但不发生全体重启。

## 13. 测试分层

### 13.1 单元测试

- 日志 schema 与字段类型；
- 敏感字段拒绝；
- correlation ID 格式验证；
- 健康状态纯函数矩阵；
- 日志级别映射。

### 13.2 组件测试

- Java filter 提取/生成并返回 correlation ID；
- 日志框架将 trace/span context 写入记录；
- HTTP client 注入 traceparent；
- 异步 executor 保留或显式传播上下文；
- Actuator 状态与 HTTP 状态码；
- 数据库故障只影响 readiness。

### 13.3 拓扑测试

- Nginx 转发和记录同一 ID；
- Compose 中 start period、retries 和 restart 行为；
- PostgreSQL 延迟、断连和恢复；
- Nginx 不缓存健康响应、不重写 503；
- 日志采集器保持 JSON 字段类型；
- 多实例并发下关联不串线。

### 13.4 生产演练

使用合成请求和非敏感测试租户，验证入口到日志/trace 后端的关联、依赖退化、告警与恢复。生产演练需变更审批、停止条件和回滚计划，本章不执行。

## 14. 常见误区

### 14.1 “JSON 就是结构化日志”

如果所有信息仍塞在 message 字符串里，或者同一字段时而数字时而字符串，JSON 只是包装。结构化意味着字段可预测、有类型和所有者。

### 14.2 “关联 ID 可以代替 trace”

关联 ID 适合检索，trace 有 span、父子关系、时间和状态。一个 ID 列表无法显示哪个下游最慢。两者可以关联，但职责不同。

### 14.3 “随机 UUID 一定安全”

随机值不会自动验证外部输入，也不能阻止换行、超长值和伪造关联。入口仍需限制，且 ID 不能用于授权。

### 14.4 “Liveness 检查所有依赖最严格”

这会把外部故障转成重启风暴。Liveness 判断进程是否无法自愈；关键依赖通常影响 readiness。

### 14.5 “健康检查通过就说明业务正常”

探针覆盖有限。错误配置、权限、数据一致性或某个关键业务路径仍可能失败。健康是流量控制信号，SLO 是用户结果证据。

### 14.6 “DEBUG 时可以记录正文”

日志级别不改变数据分类。敏感信息在 DEBUG 中仍是敏感信息，而且事故期间最容易临时开启 DEBUG。

## 15. 口述与独立构建验收

120 秒口述参考：

“结构化日志是稳定的数据契约，至少有时间、级别、服务、事件、关联和安全属性；敏感字段在采集前由允许清单阻断。关联 ID 用于检索，trace ID/span ID 表达跨服务因果关系，入口要验证外部上下文，下游和异步边界要提取/注入而非重建。Liveness 决定是否重启，readiness 决定是否接流量，startup 保护慢启动，可选依赖失败可 DEGRADED。数据库短暂失败应让 readiness 失败，不应自动让 liveness 失败。”

越界反例：把完整工单正文写入日志以便调试。即使日志平台有权限，它仍扩大敏感数据副本、访问面和保留范围。

独立构建题：在真实 FactoryCare 分支中由 Java 实现日志 filter、允许字段 schema、correlation/trace 传播和健康矩阵；Nginx 转发；PostgreSQL 调用产生 client span。保存一次正常、启动中、数据库不可用、可选依赖不可用和进程不可恢复的证据。没有真实环境时，只能提交设计和受控夹具，不能标记生产通过。

诊断题：给出一组同一时间附近但 ID 不同的日志，以及 readiness 仍 200 的输出。必须找到 ID 第一次变化和健康映射的最早失败层，修复后重放原请求与原故障。

## 16. 官方资料与当前边界

本章在 2026-07-24 核对：

- [OpenTelemetry Logs](https://opentelemetry.io/docs/concepts/signals/logs/)：Log Record 顶层字段与 trace/log 关联。
- [OpenTelemetry Context propagation](https://opentelemetry.io/docs/concepts/context-propagation/)：context 的注入、提取、W3C 默认传播和安全提醒。
- [OpenTelemetry Traces](https://opentelemetry.io/docs/concepts/signals/traces/)：span、父子关系、状态和上下文传播。
- [W3C Trace Context Recommendation](https://www.w3.org/TR/trace-context/)：traceparent/tracestate 标准。
- [Kubernetes probes](https://kubernetes.io/docs/concepts/workloads/pods/probes/)：startup、liveness、readiness 的不同动作及错误 liveness 的级联风险。
- [Spring Boot Actuator endpoints](https://docs.spring.io/spring-boot/reference/actuator/endpoints.html)：实际实现前须按项目 Spring Boot 版本复核。

本地夹具由 Python 标准库执行。未验证项包括真实 Nginx 配置、Java 日志框架与 OpenTelemetry SDK/agent、PostgreSQL driver、Docker Compose 与编排器探针、遥测后端、采样、访问控制、保留和删除。正文描述这些目标时属于设计要求，不是已完成事实。

## 17. 章节验收清单

- [ ] 我能区分 event、message、attribute、severity 和 error type。
- [ ] 我能给日志字段定义类型、基数、敏感级别与所有者。
- [ ] 我不会记录认证头、Cookie、Token、PII 或业务正文。
- [ ] 我知道值被改成 null 仍不应允许敏感字段进入 schema。
- [ ] 我能区分 correlation ID 与 trace/span context。
- [ ] 我会验证不可信入口 ID，并在下游/异步边界传播。
- [ ] 我能解释 liveness、readiness、startup 和 degraded。
- [ ] 我不会让短暂外部依赖失败直接造成重启风暴。
- [ ] 我能设计五种健康场景的 HTTP 状态矩阵。
- [ ] 我能运行 examples、lab、private solution 的绿灯。
- [ ] 我知道 public exercise 的精确 starter 是 41、完成态是 0、其他失败形状是 43。
- [ ] 我能明确列出尚未验证的真实拓扑与遥测边界。
