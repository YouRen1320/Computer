---
schema_version: 2
edition: 2026.2-draft
id: ch.distributed.messaging-delivery
title: RabbitMQ、投递语义、重试、死信与幂等消费
responsibility: 教授至少一次投递下的确认、重试和重复消费边界，不宣称端到端恰好一次
volume: '06'
order: 17
level: L2+
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.distributed.messaging-delivery.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.architecture.domain-events-outbox
version_surfaces:
- rabbitmq
- docker
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释RabbitMQ、投递语义、重试、死信与幂等消费的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - messaging-delivery
  - messaging-failure
  covers_topics:
  - messaging.exchange-queue-routing
  - messaging.ack-nack
  - messaging.at-least-once
  - messaging.retry-backoff
  - messaging.dead-letter
  - messaging.idempotent-consumer
  uses_capabilities:
  - architecture.idempotency-consistency
  - backend.spring-persistence-tx
  - foundation.network-transport
  - architecture.events-outbox
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 从领域状态变更同事务写Outbox，经relay发布RabbitMQ，消费者手动ack并以eventId幂等，配置有限重试/退避/DLQ
  covers_topic_groups:
  - messaging-delivery
  - messaging-failure
  covers_topics:
  - messaging.exchange-queue-routing
  - messaging.ack-nack
  - messaging.at-least-once
  - messaging.retry-backoff
  - messaging.dead-letter
  - messaging.idempotent-consumer
  uses_capabilities:
  - architecture.idempotency-consistency
  - backend.spring-persistence-tx
  - foundation.network-transport
  - architecture.events-outbox
  evidence_kind: system-artifact-and-negative-tests
  verification_mode: system-security-resilience-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入业务提交未写outbox、发送后未标记、处理前ack、消费成功后ack前崩溃和无限requeue，逐段修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - messaging-delivery
  - messaging-failure
  covers_topics:
  - messaging.exchange-queue-routing
  - messaging.ack-nack
  - messaging.at-least-once
  - messaging.retry-backoff
  - messaging.dead-letter
  - messaging.idempotent-consumer
  uses_capabilities:
  - architecture.idempotency-consistency
  - backend.spring-persistence-tx
  - foundation.network-transport
  - architecture.events-outbox
  evidence_kind: fault-injection-fix-rerun
  verification_mode: fault-injection-rerun
---
# RabbitMQ、投递语义、重试、死信与幂等消费

> 本章状态为 `drafting`。配套资产用 JDK 25 的离线 broker/consumer 状态机合成路由、确认、重投、有限退避、DLQ 与幂等消费，可以证明协议预言；它不启动 RabbitMQ、Docker、Spring AMQP、PostgreSQL 或真实网络，不能证明 publisher confirm、channel、quorum queue、DLX 安全性和进程崩溃窗口已经在生产组合中关闭。

RabbitMQ 能把生产者与消费者在时间、进程和部署上解耦，却不能把分布式故障变成“每条消息恰好执行一次”。发布者可能不知道 broker 是否已经接受，消费者可能在业务提交后、ack 前崩溃，broker 可能把未确认 delivery 重新交给另一个实例。可靠设计的目标不是消灭这些不确定性，而是用 outbox、publisher confirm、手动 ack、有限重试、死信与消费者幂等，把不确定性变成可观察、可重放、不会重复业务副作用的合同。

## 1. 完成定义、证据入口与非目标

完成本章后，应能：

1. 从零解释 producer、exchange、binding、queue、consumer 和 routing key；
2. 为 direct/topic/fanout 选择明确用途，并验证 unroutable 消息；
3. 区分 publisher confirm 与 consumer acknowledgement 的两个独立方向；
4. 解释 auto-ack、manual ack、nack/reject、requeue 和 prefetch 的边界；
5. 从业务事务同库 outbox 开始，经 confirm 后更新发布状态；
6. 画出每个崩溃点，证明至少一次会重复但不静默丢失；
7. 让消费者以 `consumerName + eventId` 原子去重，业务副作用与消费记录同事务；
8. 把临时、永久、未知版本和毒消息分类，采用有限次数、指数退避与抖动；
9. 让永久失败进入可追踪 DLQ/隔离区，并提供授权恢复而非无限 requeue；
10. 用队列深度、unacked、redelivery、confirm latency、retry/DLQ age 和消费延迟诊断。

配套入口：

- [RabbitMQ 投递语义示例](../../../examples/encyclopedia/ch.distributed.messaging-delivery/README.md)
- [确认、重试与死信故障实验](../../../labs/encyclopedia/ch.distributed.messaging-delivery/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.distributed.messaging-delivery/README.md)

本章不承诺 Exactly Once、全局顺序、消息永不丢、发布成功等于消费成功或 DLQ 自动修复错误。FactoryCare 当前 ADR 的生产基线仍是同库 outbox 加进程内/数据库轮询 relay；本章 RabbitMQ 是跨进程外发能力的可验证实验，不自动变更项目架构决定。

## 2. 从一封信建立 AMQP 心智模型

生产者不是通常意义上“把消息直接塞进某个队列”，而是向 exchange 发布。exchange 根据类型、routing key 与 binding 把消息路由到零个、一个或多个 queue。queue 保存待交付消息；consumer 从 queue 获得 delivery，并在处理后确认。

可以把 exchange 看成分拣中心，routing key 是信封上的分类信息，binding 是分拣规则，queue 是某类收件人的待办箱。类比的限制也重要：RabbitMQ delivery 有 channel 内 delivery tag、确认、重投、prefetch 和 topology 状态，不能把它理解成普通 Java 方法调用。

一条逻辑事件路由到 reporting queue 和 knowledge queue，会形成两个独立副本；每个 queue 都有自己的积压、确认和死信。若两个 consumer 实例共同消费同一个 knowledge queue，它们竞争分担消息，不会每个实例都收到一份。需要广播给两个业务消费者时创建两个受治理 queue，而不是让两个实例竞争同一 queue 后期待都执行。

## 3. Exchange、binding 与 routing key

direct exchange 以 routing key 精确匹配 binding，适合 `factorycare.event.WorkOrderClosed.v1` 这类明确路由。topic exchange 以点分词和 `*`/`#` 模式匹配，适合受控事件族；模式过宽会让消费者收到不应处理的事实。fanout 忽略 routing key，把副本发送到所有绑定 queue，适合真正广播。headers exchange 按 header 匹配，灵活但更难审查，不能成为弥补事件命名混乱的默认方案。

binding 是拓扑合同，不是业务过滤的临时实现。若 reporting 只需工单事件，可绑定受控 routing key；消费者仍要校验 envelope 的 `eventType/version`，不能因为 queue 名正确就信任 payload。队列、exchange、binding 的 durable/auto-delete/exclusive 参数也属于部署合同，声明不一致会造成 channel 错误。

RabbitMQ 官方 AMQP 模型说明：消息没有路由到任何 queue 时，可能被丢弃或在发布者设置相应属性时返回。可靠 publisher 应使用受控 topology、`mandatory`/return 处理与 publisher confirm；confirm 只说明 broker 对 publish 的责任，不会告诉你某个消费者最终完成了业务。

## 4. 一个事件要有两套身份

AMQP delivery tag 是 channel 内 broker 分配的交付序号，用于 ack/nack，只在收到该 delivery 的同一 channel 有意义。FactoryCare `eventId` 是生产事务持久化的逻辑事件身份，跨连接、重试、queue 和消费者仍保持不变。二者不能互换。

relay 第一次发布 `evt-42`，confirm 丢失后重发，第二次 AMQP delivery tag 可能不同，但 eventId 必须仍为 `evt-42`。消费者幂等按 eventId，而不是 delivery tag 或 redelivered flag。`redelivered=false` 也不证明以前从未处理：生产者可能重复 publish 两份，broker 会把每份视为初次 delivery。

correlation/trace ID 用于追踪请求、outbox、publish 和 consume，不应替代 eventId。一个 trace 可包含多个事件；一个逻辑事件重试可能跨多个 transport trace span。

## 5. Publisher confirm：broker 接管责任的证据

publisher confirm 是 RabbitMQ 从 broker 到 publisher 的确认方向。进入 confirm mode 后，broker 对 publish 发送 ack 或极少情况下 nack；publisher 维护 outstanding publish 与 outbox eventId 的对应。confirm ack 后才可把该 outbox 投递尝试记为 broker accepted；nack、timeout 或连接中断则保持可重试。

confirm 与 consumer ack 完全无关。官方文档明确说明 publisher confirm 不知道消费者，consumer acknowledgement 也不知道 publisher。得到 confirm 不能把 outbox 标记为“业务已处理”，最多是“本次 broker publish 已确认”。端到端完成若需要，应由消费者结果事件或可查询状态表达，但那又是另一条至少一次链路。

confirm timeout 是“不知道”，不是“肯定没到”。relay 重发可能产生两份相同 eventId，所以消费者仍须幂等。若 publisher 每次重试生成新 eventId，confirm 机制反而把一次逻辑事实变成多个合法身份，去重无法工作。

## 6. 持久消息、durable queue 与高可用不是一个开关

delivery mode persistent、durable exchange/queue、publisher confirm 和复制队列各解决不同窗口。persistent 消息发布到 durable queue 是重启恢复的必要组成，但不保证写盘瞬间、集群多数可用、拓扑正确或消费者幂等。confirm 的具体时点还取决于 queue 类型和持久化策略。

quorum queue 用复制共识提高数据安全与 leader 恢复能力，仍会有网络分区、容量、确认和消费重复。它还具有 delivery limit 等毒消息治理能力；官方文档指出 RabbitMQ 4.0 起 quorum queue 默认 delivery limit 为 20，但版本面在本项目仍为 provisional，不能把该默认值当永恒合同。应通过 policy 显式声明并在实际版本验证。

“消息在 broker”也不是备份。需要容量、监控、磁盘告警、拓扑声明、升级与恢复演练。队列不可无限堆积；超过保留/长度策略会产生删除或 dead-letter 行为。

## 7. Consumer acknowledgement：何时允许 broker 删除

auto-ack 在 delivery 发出时即把责任交给消费者，进程随即崩溃可能丢失未处理业务。对 FactoryCare 的报告、知识草稿等受保护副作用，主线采用 manual ack：先验证、去重并提交业务结果，再在同一 channel ack delivery tag。

`basic.ack` 表示已成功处理；`basic.reject`/`basic.nack` 可选择 requeue true 或 false。requeue true 让消息回队列，可能马上再次交给同一失败实例；false 可触发 DLX（若配置）或被丢弃。`nack` 可批量处理，但错误使用 `multiple` 会确认/拒绝额外 delivery。

RabbitMQ 要求在收到 delivery 的同一 channel 上 ack 对应 tag；重复 ack 或未知 tag 会触发 channel 错误。异步处理代码不能随意跨线程/channel 保存 tag 后在另一个 channel 确认。Spring AMQP 的容器隐藏部分细节，但合同仍存在，必须用真实 broker 测试。

## 8. Prefetch 是背压，不是可靠性证明

prefetch 限制 consumer 同时持有的 unacked 数，防止一个实例吞入远超处理能力的消息。过大可造成内存/数据库连接压力和故障时大批重投；过小降低吞吐。官方文档明确把最佳值视为需要实测的权衡，而不是固定魔法数字。

设置 prefetch 10 不代表最多并发 10 个业务事务，listener 容器并发数、每实例数和异步执行器都影响总量。容量公式至少考虑 `prefetch × channels/consumers × instances`。下游数据库/Provider 的并发上限应通过舱壁和连接池共同保护。

调整 prefetch 前先看 consumer capacity、unacked、处理时长、连接池等待和 redelivery；只把队列清空得更快而压垮数据库不是优化。

## 9. 至少一次的四个关键窗口

**业务提交但没 outbox。** 若生产用例先提交状态、后插 outbox，进程中断会永久无事件。修复是同库同事务。

**publish 已被 broker 接受但 confirm 未到。** relay 不知道，重发同 eventId；queue 可能有两份。消费者幂等吸收。

**消费者业务提交但 ack 未到。** channel/进程关闭时，manual-ack delivery 自动 requeue；另一消费者重收同 eventId。消费记录与副作用同事务使第二次无效果，然后 ack。

**处理前先 ack。** ack 后进程崩溃，broker 可删除消息且业务没提交，形成静默丢失。不能用“通常很快”缩小掉这个逻辑窗口。

这四段说明端到端 Exactly Once 不能由 confirm + ack 拼出来。可靠链路选择至少一次交付、稳定身份和幂等副作用，并明确哪些外部 Provider 仍有未知执行状态。

## 10. Outbox relay 到 RabbitMQ 的安全骨架

业务事务将版本化 envelope 写入 `outbox_event`。relay 领取一批未发布行，按稳定 eventId 发布到受控 exchange/routing key，记录 publish sequence/correlation；收到 confirm ack 后记录 broker-confirmed，收到 return/nack/timeout 则分类并重试。

outbox 行不能在 publish 调用返回时立即删除。网络库返回只说明客户端调用完成，confirm/return 仍可能随后到达。应建立 channel 关闭时 outstanding publish 的恢复规则；事件每次重投 payload/hash 不变。

如果 mandatory return 表示没有 queue 路由，它通常是 topology/config 永久错误，不应每毫秒无限重试。把 exchange、routing key、eventType、return code 和 eventId 安全记录并告警，修复 binding 后按授权流程重发。

FactoryCare 的 outbox 仍是提交一致性来源，RabbitMQ 是 transport 适配器。切回 DB polling/进程内消费者时不删除未确认 outbox；核心审计始终在业务事务同步追加，不等待消息消费者。

## 11. 幂等消费者的数据库事务

消费端先校验 content type、大小、eventType、version、tenant 和 schema，再尝试插入 `(consumer_name,event_id,payload_hash)` 唯一记录。新记录执行副作用并标记完成；同 ID 同 hash 已完成则不重复；同 ID 不同 hash 是污染，立即隔离告警。

消费记录和数据库副作用尽量位于同一事务。例如 knowledge consumer 创建待审核草稿，并写 `knowledge-draft|eventId` 唯一消费记录；任何失败都回滚，不 ack。提交成功后 ack。ack 前崩溃会重投，但唯一约束只允许一份草稿。

“先 SELECT 是否消费过，再做副作用”不是并发安全：两个 consumer 可同时查不到。使用唯一约束/原子 insert 竞争；若副作用调用外部 Provider，还需把 eventId 传为 Provider 幂等键或建立可恢复状态机。本地表无法自动使外部调用 Exactly Once。

## 12. 失败分类决定 retry 还是 DLQ

临时错误包括数据库短时不可用、网络 timeout、依赖 503；可有限重试。永久合同错误包括不支持版本、schema 违规、必填业务引用永远不存在；应隔离而不是重试。权限/撤销类业务结果可能是合法 no-op，需由消费者合同定义，不能一概抛异常。

错误分类必须基于最早可信证据。JSON 解析都未通过时不要诊断为“数据库故障”；数据库事务 rollback 后不要打印“已成功消费”。保留稳定 error code 与安全摘要，不把完整敏感 payload 打日志。

未知异常先进入很小次数的保守重试，仍失败后隔离并人工分类。把 `Exception` 全部 requeue true 会让毒消息占据 consumer 和日志，正常消息饥饿。

## 13. 有限重试、指数退避与抖动

重试策略包含最大次数、基准延迟、倍数、最大延迟、抖动和可重试错误集合。例如 5 秒、30 秒、2 分钟、10 分钟后隔离。延迟应给下游恢复时间，不能原队列立即 requeue 形成热循环。

实现可选：应用将失败消息发布到分级 retry queue，使用 message/queue TTL 到期后经 DLX 路由回工作 queue；或由数据库 retry scheduler 在 nextAttempt 到期重新 publish。前者依赖 broker topology/TTL/DLX 语义，后者状态更易查询但多一张表/扫描。两者都必须保持 eventId、记录 attempt，并防循环。

RabbitMQ TTL 是消息在某 queue 的保留时间，不是精确任务调度器；消息可能在到队头时才清理资源。每次重试的原始 occurredAt 不变，attempt time 属于 transport 元数据。抖动避免大面积恢复时同刻重试。

## 14. DLX 与 DLQ：隔离区，不是垃圾桶

消息因 reject/nack requeue=false、TTL、queue length 或 quorum delivery limit 等原因可被 dead-letter 到普通 exchange，再路由到 DLQ。DLQ 必须有消费者/管理流程、保留期、权限、指标和重放工具；没有这些，死信只是把故障藏到另一个积压。

官方建议通过 policy 配置 DLX，而非难更新的硬编码 x-arguments。缺失 DLX、权限或目标 queue 会导致 dead-letter 失败/丢失窗口；默认 clustered dead-letter republish 并不总有 publisher confirms，quorum queue 的 at-least-once dead-lettering需明确配置和验证。因此“进 DLQ 就绝不会丢”是不准确承诺。

DLX 可形成循环。RabbitMQ 会检测某些无 rejection 的 cycle 并丢弃，应用不能依赖它代替 retry 上限。重放 DLQ 时保留原 eventId、原 payload/hash、死亡原因与操作审计；禁止操作员直接改 payload 后用同 ID 重发。

## 15. 顺序、并发与公平性

单 queue 也不等于全局严格业务顺序。多个 consumer、prefetch、处理时长和 requeue 会让完成顺序变化；不同 queue 的副本更无全局顺序。若同一工单事件要求防旧覆盖，使用 aggregateId + aggregateVersion，消费者检测重复、过旧和缺口。

给每个 aggregate 单独建 queue 会造成动态拓扑和资源爆炸。可以用一致路由分片、单活消费者或版本条件应用，但都要以真实吞吐/顺序要求为依据。FactoryCare reporting 是可重建派生读模型，可在缺口时回源重建；核心工单状态不由消息倒推。

优先级队列也不保证低优先级不饿死。不同 SLA 可用独立 queue/consumer pool，并观察 oldest age。公平性和隔离属于容量设计，而非 exchange 类型自动提供。

## 16. FactoryCare：关单事件到知识草稿

`workorder` 在关闭事务内写 `WorkOrderClosed.v1` outbox 与核心审计。relay 发布到 `factorycare.domain-events` topic exchange，routing key 可为受控的 `workorder.closed.v1`；knowledge queue 和 reporting queue 分别绑定。拓扑名称仅示例，真实合同必须版本化并由基础设施声明。

knowledge consumer 校验事件目录 schema 与 tenant，按 `knowledge-draft + eventId` 唯一创建“待审核”草稿，绝不直接发布知识。成功提交后 manual ack；重复 delivery 只命中消费记录。未知 v2 不猜字段，nack requeue=false 进入 schema DLQ并告警。

reporting consumer 可按 eventId/aggregateVersion 更新读模型；积压不回滚已经关闭的工单。audit 的核心关单证据早已同事务存在，事件 consumer 只补派生传输/Provider 回执。AI 不可用也不影响工单主链。

## 17. FactoryCare：通知 Provider 的额外窗口

engagement consumer 收到事件后调用邮件/短信 Provider。若 Provider 已接受但响应丢失，consumer 无法仅从本地判断。把 eventId + channel + recipient purpose 作为 Provider 支持的幂等键；若 Provider 无幂等能力，保存 `UNKNOWN` 状态并通过查询/人工核对，不能盲重试造成重复通知。

通知失败是派生失败，不应改工单状态。永久无效地址进入受控失败记录；临时 503 有限退避；敏感 payload 最小化。DLQ 重放要重新检查当前授权/撤销策略：一条积压很久的通知可能已经没有发送意义。

消费者成功的定义应是“受保护的本地意图/Provider 结果已持久化”，不是“listener 没抛异常”。ack 时点围绕该定义设计。

## 18. 故障注入矩阵

| 注入 | 可观察错误 | 安全预言 | 修复 |
| --- | --- | --- | --- |
| 业务提交未写 outbox | CLOSED 无事件 | 回滚时两者都无，提交时两者都有 | 同库同事务 |
| publish 后不等 confirm 就标记 | broker 未接收却不重试 | 只有 confirm ack 才 accepted | outstanding confirm 状态 |
| confirm 丢失后换 eventId | 消费副作用两次 | 重投身份/payload 不变 | 持久 eventId |
| consumer 处理前 ack | 崩溃后消息消失 | 事务提交后才 ack | manual ack |
| 提交后 ack 前崩溃 | 同 delivery 重现 | 消费副作用仍一份 | 唯一消费记录 |
| 所有异常 requeue=true | 同消息热循环 | 有限 retry 后 DLQ | 分类、退避、上限 |
| 未知版本当 v1 | 错字段/错语义 | 无副作用并隔离 | handler registry/schema |
| routing key 错 | confirm 可能有但无目标 queue | mandatory return 可见 | topology 合同 |
| DLQ 无消费者/保留 | 死信无限增长 | oldest age 有告警/恢复 | 治理 runbook |

实验必须先跑安全基线，再逐个打开 fault 并比较唯一 oracle；修复后重跑原断言。若注入“处理前 ack”仍显示通过，测试并未覆盖真正的崩溃窗口。

## 19. 诊断剧本：定位第一处可信证据

**outbox pending 增长。** 先查 relay 是否领取、publish 是否 return/nack/timeout、confirm outstanding 是否泄漏，再查 broker。不要直接怪消费者，因为消息可能尚未进入任何 queue。

**exchange publish rate 有、queue ingress 为零。** 核对 exchange、vhost、binding、routing key、mandatory return 和权限。confirm ack 不能单独证明路由到了目标 queue；return 是更近的 topology 证据。

**queue ready 增长、unacked 很低。** consumer 可能没连接、被 flow control、权限错误或 crash loop。**unacked 很高**则可能 listener 慢、prefetch 过大、数据库池耗尽或 ack 路径错误。

**redelivery 飙升。** 查 consumer 日志的 eventId、错误分类、channel 关闭、ack timeout 和实例重启。redelivered flag 是线索，不是幂等身份。若副作用重复，先检查消费唯一约束和事务边界。

**DLQ 反复回工作队列。** 看 x-death/attempt、重放工具是否重置次数、DLX routing 是否形成 cycle、错误是否已修。停止自动重放 poison，保留样本并让正常事件恢复。

**客户端报 unknown delivery tag。** 检查重复 ack、跨 channel ack、`multiple` 范围和并发 listener。修复 channel 所有权，不要 catch channel exception 后继续假装成功。

## 20. 安全与租户边界

RabbitMQ vhost、user、exchange/queue 权限采用最小权限：relay 只写指定 exchange/读取必要 confirm；consumer 只读/ack 指定 queue，配置 topology 的身份与运行身份可分离。管理 UI/metrics 不公开互联网，TLS、凭据轮换和 secret 管理属于部署证据。

消息中的 tenantId 来自生产事务可信上下文，但 consumer 仍以自己的数据访问策略绑定 tenant 条件；不能让 payload 指定任意 schema/表/URL。事件 payload 最小化，不传 token、密码或完整敏感对象。DLQ 也包含生产数据，权限与保留不能更松。

反序列化只允许受控类型/schema，不启用任意类名。消息大小、header 数、重试次数和并发有上限，防止资源耗尽。错误日志记录 eventId/type/version、安全错误码，不完整打印 resolutionSummary。

## 21. 观测与容量合同

publisher 观察 outbox oldest age、publish/return/nack/timeout、confirm latency、outstanding count、channel reconnect。broker 观察每 queue ready/unacked、ingress/ack/redelivery rate、consumer count/capacity、memory/disk alarm、connection/channel churn。consumer 观察处理 latency、成功/重复、分类失败、retry/DLQ、unsupported version 和副作用 commit。

消息积压用数量与年龄共同判断。十万条小而快速消息可能几分钟清空；一百条毒消息可永久卡住。估算恢复时间要用实测消费速率、实例上限和下游容量，不能只把 consumer 数翻倍。

指标标签使用受控 queue/eventType/error class，不把 eventId/tenantId 当高基数标签。事件级排障靠结构化日志/trace。告警要链接 runbook：暂停哪条 consumer、如何隔离、如何验证修复、如何限速重放、如何回滚 transport。

## 22. 独立构建任务与 T4 验收

构建从 FactoryCare 关单事务到 RabbitMQ 再到 knowledge consumer 的链路：同事务 outbox；relay 使用 mandatory + publisher confirm；手动 ack；消费记录与草稿同事务；临时错误进入有限退避；永久/未知版本进入可追踪 DLQ。

正向断言：合法关闭只有一个 outbox eventId；正确 routing 到两个独立 queue；confirm 后 outbox 状态可解释；consumer 提交后 ack；重复 eventId 只有一份草稿；暂时错误在指定时间/次数恢复；永久错误 DLQ 可查。

负向断言：业务 rollback 无 outbox；unroutable 被 return；confirm timeout 重发同 ID；处理前 ack 会在故障模型中丢失；提交后 ack 前崩溃会 redeliver但不重复副作用；无限 requeue 被上限阻止；未知版本不执行；DLQ 重放有审计。

T4 必须使用当前支持 RabbitMQ 镜像、真实 Spring client/连接、PostgreSQL/Testcontainers 或等价容器环境，至少两个 consumer，杀进程/断连接/错误 binding/poison 注入。保存 RabbitMQ/Docker/client patch、queue type/policy、拓扑、命令、退出码和断言。离线 asset、mock template 或 management 截图不构成 T4。

G3 evidence path 为 `evidence/gates/g3/distributed-messaging-delivery/`，本章 drafting 不自动创建或宣称门禁完成。

## 23. 120 秒口述模板

可以这样组织：生产者向 exchange 发布，binding 用 routing key 把消息送到 queue，consumer 从 queue 收 delivery。FactoryCare 先在业务事务同库写 outbox；relay 发布并等 publisher confirm，timeout 时重发相同 eventId。consumer 手动 ack，先校验版本，再让消费记录和副作用同事务提交；若提交后 ack 前崩溃，broker 会 redeliver，同 eventId 幂等避免第二份副作用。临时错误有限指数退避，永久/未知版本进入受治理 DLQ，禁止无限 requeue。confirm 与 ack 分属两个方向，整个链路只承诺至少一次，不是 Exactly Once。反例是处理前 ack，进程在业务提交前崩溃，消息已被 broker 删除而副作用不存在。

口述必须覆盖 exchange/queue/routing、ack/nack、至少一次、retry/backoff、dead-letter、idempotent consumer 与一个崩溃点。只说“RabbitMQ 异步削峰，失败就重试”不能通过。

## 24. 版本边界与权威来源

版本登记只写 RabbitMQ `current supported stable`，状态 provisional；截至 2026-07-17 官方在线文档默认展示 4.3，但实际课程容器仍须根据 release information/客户端兼容性锁定精确 patch 和 digest。Docker 也为 provisional。正文不依赖 4.3 独有默认值；queue type、delivery limit、DLX policy 与 confirm 行为必须在选定版本重验。

- [RabbitMQ：AMQP 0-9-1 模型、exchange 与 routing](https://www.rabbitmq.com/tutorials/amqp-concepts)
- [RabbitMQ：Consumer Acknowledgements 与 Publisher Confirms](https://www.rabbitmq.com/docs/confirms)
- [RabbitMQ：Reliability Guide](https://www.rabbitmq.com/docs/reliability)
- [RabbitMQ：Dead Letter Exchanges](https://www.rabbitmq.com/docs/dlx)
- [RabbitMQ：TTL 与 expiration](https://www.rabbitmq.com/docs/ttl)
- [RabbitMQ：Quorum Queues 与 poison message](https://www.rabbitmq.com/docs/quorum-queues)
- [FactoryCare ADR-0004：事务 Outbox 与至少一次](../../../factorycare-design/adrs/0004-transactional-outbox.md)
- [FactoryCare 事件目录](../../../factorycare-design/events/README.md)
- [FactoryCare 威胁模型 TM-18](../../../factorycare-design/security/threat-model.md)
- [FactoryCare 验收目录](../../../factorycare-design/testing/acceptance-catalog.md)

## 25. 复盘清单

- publish 是发给 exchange 还是 queue，零路由如何可见？
- publisher confirm 与 consumer ack 分别证明什么、绝不证明什么？
- eventId、delivery tag、traceId 是否正确分工？
- outbox 何时标记、confirm timeout 如何保持同一身份？
- consumer 是否在业务事务提交后才 ack？
- 重复 delivery 是否由唯一约束/同事务消费记录吸收？
- retry 是否分类、有限、退避、有抖动，而非原地热循环？
- DLQ 是否有权限、保留、告警、修复和审计重放流程？
- 未知版本、同 ID 不同 payload 是否隔离？
- prefetch/并发是否匹配数据库与 Provider 容量？
- 顺序合同是否只在确有需要的 aggregate/version 范围？
- 我保存的是崩溃注入与跨边界断言，还是只有 queue 变空截图？

能为每项指出实现位置、负向测试与失败恢复，才算掌握。本章的可靠不是“RabbitMQ 帮我保存了”，而是每一方何时接管责任都有证据，任何不确定窗口都能以同一逻辑身份重放且不复制受保护副作用。
