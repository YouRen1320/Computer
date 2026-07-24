---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.actuator-health-metrics
title: Actuator、健康、就绪、指标与安全暴露
responsibility: 教授应用健康和基础指标的可观测端点，不提前建立分布式追踪或完整 SLO 告警体系
volume: '05'
order: 18
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.actuator-health-metrics.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.testing-testcontainers
version_surfaces:
- spring-boot-4.1
- opentelemetry-specification
- opentelemetry-semantic-conventions
- opentelemetry-java
- testcontainers
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释Actuator、健康、就绪、指标与安全暴露的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - spring-health-readiness
  - spring-metrics-exposure
  covers_topics:
  - spring.actuator-health
  - spring.liveness-readiness
  - spring.health-dependency
  - spring.actuator-metrics
  - spring.endpoint-exposure
  - spring.management-security
  uses_capabilities:
  - backend.spring-di-config
  - foundation.verification-debug-test
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 配置 liveness/readiness、数据库健康和工单计数指标，限制 management endpoint 暴露并保存正常/降级响应
  covers_topic_groups:
  - spring-health-readiness
  - spring-metrics-exposure
  covers_topics:
  - spring.actuator-health
  - spring.liveness-readiness
  - spring.health-dependency
  - spring.actuator-metrics
  - spring.endpoint-exposure
  - spring.management-security
  uses_capabilities:
  - backend.spring-di-config
  - foundation.verification-debug-test
  evidence_kind: integration-artifact-and-tests
  verification_mode: framework-or-container-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入 readiness 把外部依赖故障当存活失败、公开 env 端点和高基数 metric 标签，检查端点/指标修复
  covers_topic_groups:
  - spring-health-readiness
  - spring-metrics-exposure
  covers_topics:
  - spring.actuator-health
  - spring.liveness-readiness
  - spring.health-dependency
  - spring.actuator-metrics
  - spring.endpoint-exposure
  - spring.management-security
  uses_capabilities:
  - backend.spring-di-config
  - foundation.verification-debug-test
  evidence_kind: integration-failure-fix-rerun
  verification_mode: integration-fault-rerun
---
# Actuator、健康、就绪、指标与安全暴露

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Spring 测试切片、上下文测试与 Testcontainers》](ch.spring.testing-testcontainers.md)：独立完成健康与就绪、指标与暴露前，必须先具备「Spring 测试切片、上下文测试与 Testcontainers」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 drafting。健康端点返回 UP 不等于业务正确、所有依赖正常或用户请求必然成功；指标存在也不等于已经建立 SLO 与告警。

本章基线为 Spring Boot 4.1.0、Spring Framework 7.0.8、Micrometer 1.17.0、Testcontainers 2.0.5、PostgreSQL 18、JDK 25 与 Maven 3.9.16。版本事实复核于 2026-07-17；Boot 4.1.0 依赖管理固定 Micrometer 1.17.0 与 Testcontainers 2.0.5。

## 1. 本章完成证据

学习者要配置并分别验证 liveness、readiness、数据库健康与一个有界工单计数器；数据库故障只能改变预期信号；匿名访问只能得到允许公开的健康面；`env` 等敏感端点不可匿名获取；meter tag 值集合必须有界。

配套工件：

- [探针与指标边界示例](../../../examples/encyclopedia/ch.spring.actuator-health-metrics/README.md)
- [Boot 4.1 Actuator HTTP 实验](../../../labs/encyclopedia/ch.spring.actuator-health-metrics/README.md)
- [修复错误存活策略练习](../../../exercises/encyclopedia/ch.spring.actuator-health-metrics/README.md)

工件是课程证据，不自动推进 `PROGRESS.md`。本章不提前建立分布式追踪、生产 SLO 或完整告警平台。

## 2. Actuator 是什么

Spring Boot Actuator 提供技术无关的管理端点和自动配置，例如 health、metrics、info、loggers。端点可通过 HTTP/JMX 暴露，并受“是否允许访问”和“是否通过某技术暴露”两层控制。

它不是一个独立监控平台。Actuator 提供观察入口；采集、保存、查询、告警、值班与复盘属于更大的运维系统。

## 3. 三个容易混淆的问题

存活（liveness）问“这个进程自身是否已经坏到需要重启”；就绪（readiness）问“当前是否应该接收新流量”；健康总览问“已配置组件当前是什么状态”。

三者若都绑定同一个“所有依赖 UP”布尔值，短暂数据库故障可能触发所有实例重启，形成级联故障。

## 4. liveness 的边界

liveness 应聚焦应用内部不可恢复状态：主事件循环永久卡死、关键内部状态被判定 broken 等。失败通常让编排器重启容器。

外部 PostgreSQL、Redis、第三方 API 不应默认加入 liveness。重启应用不能修好外部系统，反而清空本地缓存、放大连接风暴。

## 5. readiness 的边界

readiness 表示实例当前是否可以安全接新请求。启动尚未完成、正在优雅停机、关键接流依赖不可用时可以 OUT_OF_SERVICE/DOWN，让负载均衡停止导流。

是否把数据库放进 readiness 是业务与部署决策。核心写 API 无数据库就不能工作时通常合理；仍可提供只读降级时则可能需要更细路由，而不是一刀切。

## 6. startup probe

启动很慢的应用若 liveness 检查太早，会被反复杀死。Kubernetes startup probe 可在启动阶段保护 liveness；readiness 则在未就绪期间阻止流量。

不要为了通过探针把 liveness 初始延迟无限加大。启动时间应可测，探针预算与最坏正常启动时间匹配。

## 7. ApplicationAvailability

Spring Boot 用 `ApplicationAvailability` 表示 LivenessState 与 ReadinessState，并在生命周期事件中更新。Actuator 将状态转成专用 health indicators/groups。

业务代码通常不应到处读取 availability 决定逻辑；它是运行状态信号，不是工单状态机。

## 8. 默认探针路径

Boot 在 Kubernetes 环境中通过 health group 暴露 `/actuator/health/liveness` 与 `/actuator/health/readiness`。也可用 `management.endpoint.health.probes.enabled` 显式控制。

测试要断言路径、HTTP 状态与 JSON status，不只断言主 `/actuator/health`。

## 9. 主端口附加路径

若管理端口与业务端口分离，管理 context 可能健康但主 web 线程/连接不可用。Boot 提供 `management.endpoint.health.probes.add-additional-paths=true`，把 `/livez`、`/readyz` 放到主端口。

这减少“探针端口活着但业务端口死了”的假阳性；仍不能证明每条业务路由成功。

## 10. HealthIndicator

自定义 `HealthIndicator` 返回 UP/DOWN/OUT_OF_SERVICE/UNKNOWN 以及有限 details。检查要有超时、成本低且不会改变外部状态。

不要在每次 probe 扫全表、触发修复、发送消息或调用昂贵 AI Provider。探针高频运行，副作用会放大。

## 11. 数据库健康

Boot 可根据 DataSource 自动配置数据库 health indicator，通常执行轻量验证查询。它证明在该时刻能获得连接/执行检查，不证明每个 schema、迁移、权限与业务 SQL 都正确。

Repository/PostgreSQL 集成测试仍不可被 `/health` 替代。

## 12. 健康组

health group 可以包含指定 indicators，并配置自己的 status 顺序、HTTP 映射和 details 策略。liveness/readiness 就是特殊组。

组的 include/exclude 是运维合同，变更需与部署 probe 同步；拼错 indicator 名可能让关键检查悄悄缺席。

## 13. 外部依赖故障矩阵

对每个依赖先写“它坏了，重启本进程能否修好？实例还能服务哪些请求？”再决定 liveness/readiness/普通 health/metric。

PostgreSQL：通常 liveness 仍 UP，核心写 readiness DOWN；邮件 Provider：核心 readiness 可保持 UP，失败进入 outbox 重试并计数。

## 14. Health 与 HTTP 状态

health status 会通过映射变成 HTTP 状态，DOWN/OUT_OF_SERVICE 通常映射 503，UP 为 200。自定义 Status 若没有映射，可能意外返回 200。

编排器通常先看 HTTP；监控也读取 JSON status。两者都要测试。

## 15. details 暴露

`management.endpoint.health.show-details` 与 show-components 控制细节，常见值为 never、when-authorized、always。默认 details 不应匿名公开。

数据库错误、磁盘路径、broker 地址可能帮助攻击者。公开 probe 只需最小状态；诊断细节给受控运维身份/内部网络。

## 16. 可用、允许、暴露

Boot 4 的 endpoint 是否可请求，取决于 endpoint access 与 web/JMX exposure。不可访问 endpoint 甚至可能不创建 Bean；未暴露 endpoint 不能通过该技术远程访问。

两层都要检查。只配置 `exposure.include` 不代表授权安全；只加 Spring Security 也不代表 endpoint 必须存在。

## 17. 默认暴露

Boot 默认只通过 HTTP/JMX 暴露 health。metrics、env、beans、configprops 等不是默认公开。

不要从旧教程复制 `include: "*"`。若确需多个端点，显式白名单并逐个确定身份、网络、数据敏感性和用途。

## 18. include 与 exclude

`management.endpoints.web.exposure.include` 列出端点，exclude 优先。YAML 的 `*` 必须加引号，但最佳实践仍是最小白名单。

配置测试应从 HTTP 观察：允许的 health/metrics 可达，env 不可达。只读取 Environment property 不能证明实际暴露结果。

## 19. endpoint access

Boot 4.1 可用 endpoint access 设置限制无访问、只读或不限制，并可用 application-wide max-permitted 设上限。access 比 exposure 更接近端点能力许可。

对于可写端点尤其重要。即使网络层已有防护，也不要无理由允许修改运行状态。

## 20. Spring Security 自动配置边界

当 Spring Security 在 classpath 且没有自定义 `SecurityFilterChain` 时，Boot 会保护 health 之外的 actuator。若应用自己声明 filter chain，Boot 后退，全部规则由应用负责。

这是常见失败：业务 API security 配置 `anyRequest().permitAll()`，意外把新暴露 metrics/env 一起公开。

## 21. management matcher

安全规则应使用 Actuator 的 endpoint request matchers 或独立 management chain，明确允许匿名 probe，要求运维角色访问 metrics，拒绝未列端点。

不能只按 `/actuator/**` 粗略 permitAll，也不要让业务 JWT scope 自动等同运维权限。

## 22. 独立管理端口

`management.server.port` 可把管理端点放到另一个端口，便于网络隔离。代价是多一个监听面、TLS/firewall 配置与前述 probe 假阳性风险。

是否分端口需显式选择；本章 lab 使用同一随机端口以便验证，不能推断生产拓扑。

## 23. Actuator endpoint 不是业务 API

管理端点的消费者是编排器、采集器和运维人员，稳定性与安全策略不同于 `/api/v1`。不要把工单查询实现为自定义 actuator endpoint。

业务指标可以经 MeterRegistry 发布，但业务命令仍留在授权/事务明确的 API。

## 24. 指标是什么

metric 是随时间采集的数值序列，由名字、类型、tag 集合和值组成。它适合回答“多少、多久、当前多少”，不保存每次事件的完整事实。

审计日志、数据库工单与 outbox 不能用 counter 替代；进程重启/采集丢失后 metric 不一定是业务权威。

## 25. Micrometer 的职责

Micrometer 为 JVM 提供 vendor-neutral meter API，Boot 自动配置 MeterRegistry 与大量 binder。应用用统一名字/tags，registry 导出为目标后端格式。

Boot 4.1 管理 Micrometer 1.17.0。不要手动混入不兼容 micrometer 子模块版本。

## 26. Counter

Counter 只累计非负事件，例如成功创建工单次数。查询每秒速率通常比绝对累计值更有意义。

不要同时把“当前打开工单数”记为 counter；它会上升不下降，应使用 gauge 或从业务读模型计算。

## 27. Timer

Timer 记录操作次数与耗时分布，可用于工单命令 latency。需要配置合适 histogram/percentile，避免每个 meter 都产生昂贵桶。

客户端、服务端、数据库各层耗时语义不同，名字和 tag 要说明边界。

## 28. Gauge

Gauge 观察当前值，如未发布 outbox backlog。被观察对象需保持强引用/稳定生命周期；短命对象可能消失。

Gauge 是采样，不保证看到所有中间状态。不能用它做精确计费或审计。

## 29. DistributionSummary 与 LongTaskTimer

DistributionSummary 记录无时间单位的分布，如附件大小；LongTaskTimer 观察仍在运行的长任务。按问题选择类型，不把一切都做 Counter。

本章只构建基础 counter，不展开完整性能/SLO 设计。

## 30. meter 名称

代码使用点分规范名，如 `factorycare.workorders.created`；Prometheus 可能规范化为下划线。访问 `/actuator/metrics` 时仍使用代码名。

名称表达被测量事实，不嵌入 tenant/workOrderId 等动态值。

## 31. tag 是维度

tag 允许按固定类别聚合，例如 `result=success|rejected|error`、`priority=P1|P2|P3|P4`。所有 tag key 组合形成时间序列。

tag 不是日志字段。把 traceId、userId、workOrderId 放入 tag 会产生近乎每请求一条序列。

## 32. 高基数风险

高基数消耗应用内存、采集带宽和时序库索引，最终可能让观测系统先于业务崩溃。tenantId 即使数量“目前不多”也可能增长，不应默认作为全局 tag。

具体 ID 放结构化日志/trace，metric 保留有界分类。需要租户报表时从授权业务数据生成，不把技术 metrics 当多租户报表。

## 33. FactoryCare 有界指标

教学指标 `factorycare.workorders.created` 使用固定 result 与 priority；status 也最多为设计规定的 12 个值。错误 code 必须使用稳定小集合。

禁止 tag：workOrderId、reportId、traceId、description、exception message、任意 URL、用户名。

## 34. MeterFilter 防线

Micrometer MeterFilter 可拒绝、重命名或限制 tag cardinality。它是最后防线，不替代正确的 instrumentation 设计。

达到上限后应产生可见诊断并修代码；不能静默把新 tenantId 映射为错误业务类别。

## 35. metrics endpoint

`/actuator/metrics` 用于诊断应用已收集的 meter 名称，`/actuator/metrics/{name}` 查看具体 measurement 与 availableTags。它默认不暴露。

该 JSON 端点不是生产时序存储，也不是 Prometheus scrape 格式。

## 36. Prometheus 不是自动出现

要用 Prometheus 需相应 registry 与 prometheus endpoint/exposure。仅引入 actuator 不会完成采集、保存和 Grafana dashboard。

本章刻意不增加 Prometheus 依赖；先证明 MeterRegistry 内事实与安全暴露边界。

## 37. 自定义业务计数器

在业务成功提交之后递增 created counter；若在事务前递增，回滚也被计为成功。可以对 rejected/error 使用不同 result，但必须定义口径。

FactoryCare 的权威工单数来自数据库/读模型；counter 用于趋势与告警，不负责精确重建。

## 38. 指标口径

每个 meter 记录：名称、类型、单位、事件时点、tag key/值域、失败/重试处理、所有者。没有口径的数字会在事故中产生争论。

重试可能让 attempts 与 completed 不同，应使用两个清晰指标而非一个模糊 `requests`。

## 39. 健康与指标互补

health 是当前粗粒度状态；metric 给出趋势。例如数据库此刻 UP，但连接获取耗时持续升高；health 尚绿，timer 已显示风险。

反之，counter 不增长可能是没有流量，不等于服务故障。需要结合请求量、错误率与部署事件。

## 40. 日志、指标、追踪边界

日志保存离散诊断事件，指标适合聚合，trace 串联一次请求路径。三者用 trace/correlation 关联，但不要把完整 ID 放 metric tag。

本章不实现分布式 tracing；只说明为何 metric 高基数字段应去日志/trace。

## 41. 测试健康端点

测试应读取真实 HTTP：默认健康可达、details 隐藏、liveness/readiness 区分；模拟数据库状态改变时只影响配置的 group。

直接调用 `HealthIndicator.health()` 只能验证 indicator，不验证 endpoint、group、HTTP mapping、exposure 或 security。

## 42. 测试指标

执行一次业务动作，再从 MeterRegistry 或 `/actuator/metrics/{name}` 断言 counter 和 tags；失败动作不应误计 success。

还要枚举实际 meter IDs，证明没有 workOrderId/tenantId 等高基数 tag key/value。

## 43. Testcontainers 的角色

真实数据库健康需要 PostgreSQL 容器才能证明连接/协议边界；fake indicator 适合确定性演示状态组合，但不是数据库集成证据。

本章 lab 保持无 Docker 的 HTTP/安全/metric 验证；PostgreSQL 健康的生产等价集成应复用前章容器基础，未运行时明确未验证。

## 44. 正常响应证据

保存 `/actuator/health/liveness`、`/readiness` 与 meter JSON 的规范化字段，不保存随机端口/时间噪声。响应至少含 status 或 name/measurements/availableTags。

不要提交凭据、完整 env 或敏感 details。

## 45. 降级响应证据

将受控 dependency indicator 切到 DOWN 后，readiness 返回 503/DOWN，liveness 仍 200/UP；恢复后 readiness 重新 UP。

若所有探针一起 DOWN，先检查 group include，而不是用更长重启延迟掩盖策略错误。

## 46. 失败：数据库进入 liveness

现象是数据库维护时所有 Pod 被重启。根因是 liveness group 包含 db 或统一 health endpoint 被错误用作 liveness。

修复为 liveness 只含 livenessState/进程内部检查，数据库按业务需求进入 readiness/普通 health；验证 DB down 时不重启信号。

## 47. 失败：env 匿名公开

现象是 `/actuator/env` 返回配置键、路径或脱敏不充分的值。根因常是 `include: "*"` 加宽泛 permitAll。

立即收紧 exposure 白名单与 security，轮换可能泄露的 secret，检查访问日志；不能只依赖 value sanitization。

## 48. 失败：metrics 404

可能是 endpoint access 禁止、未 exposure、Actuator 未引入、security 返回伪装状态或 management base path/port 不同。按 availability→exposure→security→path 顺序检查。

不要直接把所有 endpoint 公开来“排错”。

## 49. 失败：健康 details 看不到

这可能是正确默认，不是 bug。确认调用者是否认证、是否有 health roles、show-details 策略和使用的 media type。

若编排器只需 status，就不应为它打开 details。

## 50. 失败：counter 值翻倍

检查 instrumentation 是否同时在 Controller/Service 递增、重试是否重复、测试 context 是否共享 registry，以及业务动作是否真正只提交一次。

在事务后选择一个所有者递增；幂等重放应按口径决定计 attempts 还是 unique completion。

## 51. 失败：每个工单一个 meter

症状是 meter registry 数量随请求线性增长，metrics 响应越来越大。根因是把 ID 拼入名字或 tag。

改为一个固定 meter + 有界 tag；具体工单诊断用日志/trace。测试给 1000 个不同 ID 后 meter 数仍保持常数。

## 52. 失败：分离端口假阳性

management 端口返回 UP，但主端口线程池/连接已无法接请求。增加主端口 `/livez` `/readyz`、真实业务冒烟，并在架构上评估是否仍需分端口。

health endpoint 不能证明整个服务路径，尤其不能替代外部黑盒合成检查。

## 53. 失败：慢 HealthIndicator

一个外部 API 检查无超时，导致 `/health` 本身卡住，kubelet 超时并重启。健康检查必须有严格超时、并行/缓存策略与成本预算。

记录 slow-indicator 日志阈值，但根本修复是缩短/隔离检查。

## 54. 安全测试矩阵

匿名：仅最小 health/probe；运维身份：按需 metrics/details；普通业务身份：不能因为已登录就读取 management；env/beans/configprops：本章完全不暴露。

同时测同端口与配置的真实 matcher，不能仅审查 YAML。

## 55. FactoryCare 故障案例

PostgreSQL 暂停：liveness UP、readiness DOWN、核心写流量移除；notification Provider 暂停：readiness 可 UP，outbox backlog/error metric 上升；AI 服务暂停：核心工单仍可用，AI 路径降级并计数。

这些策略来自“核心业务能否安全服务”，不是所有依赖统一套模板。

## 56. 红灯练习

starter 的 `ProbePolicy` 错把 databaseUp 同时用于 liveness/readiness。数据库 DOWN 时第二个测试以 `EXPECTED_LIVENESS_INDEPENDENT_FROM_DATABASE` 稳定失败。

参考解让 liveness 只取 processHealthy，readiness 再组合 processHealthy 与 databaseUp。

## 57. 120 秒复述模板

先区分 liveness“是否重启”和 readiness“是否接流”；说明外部依赖不应默认进入 liveness；再说 exposure 与 security 是两层；最后解释指标 tag 必须有界。

失败反例：公开 `*`、把 database 放 liveness、把 workOrderId 做 tag，分别造成泄露、重启风暴和基数爆炸。

## 58. 完成检查表

- liveness/readiness 问题与依赖矩阵已写清；
- DB down 只改变预期信号并可恢复；
- health details 最小；
- endpoint access/exposure/security 分别验证；
- env 等敏感端点匿名不可得；
- 业务 counter 的时点/口径明确；
- meter 名和 tag 值域固定；
- 正常/降级响应已保存并脱敏；
- H2/fake 与真实 PostgreSQL 证据边界明确。

## 59. 有意非目标

本章不搭建 Prometheus/Grafana、不定义生产 SLO/告警阈值、不实现分布式 tracing、不修改部署清单，也不把 Actuator 端点当业务 API 或权限证明。

## 60. 官方资料

- [Spring Boot 4.1 Actuator endpoints、health groups 与安全](https://docs.spring.io/spring-boot/reference/actuator/endpoints.html)
- [Spring Boot 4.1 Metrics](https://docs.spring.io/spring-boot/reference/actuator/metrics.html)
- [Spring Boot Actuator HTTP monitoring](https://docs.spring.io/spring-boot/reference/actuator/monitoring.html)
- [Spring Boot Actuator REST API](https://docs.spring.io/spring-boot/api/rest/actuator/)
- [Micrometer concepts](https://docs.micrometer.io/micrometer/reference/concepts.html)
- [Testcontainers 2.0 documentation](https://java.testcontainers.org/)

官方参考给出框架行为；FactoryCare 的 probe 依赖矩阵和 metric 口径仍需团队依据业务降级能力决定并测试。
