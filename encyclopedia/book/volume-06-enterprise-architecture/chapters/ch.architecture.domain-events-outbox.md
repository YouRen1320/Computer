---
schema_version: 2
edition: 2026.2-draft
id: ch.architecture.domain-events-outbox
title: 领域事件、Outbox 与提交一致性
responsibility: 教授在同一数据库事务记录待投递事实，不把 Outbox 当作消息必达或全局顺序保证
volume: '06'
order: 16
level: L2+
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.architecture.domain-events-outbox.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.architecture.idempotency-concurrency
version_surfaces:
- spring-boot-4.1
- postgresql-18
- mybatis
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
  text: 在 120 秒内解释领域事件、Outbox 与提交一致性的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - architecture-domain-event
  - architecture-outbox
  covers_topics:
  - architecture.domain-event
  - architecture.event-payload-version
  - architecture.event-after-state-change
  - architecture.outbox-table
  - architecture.atomic-state-event
  - architecture.outbox-relay
  uses_capabilities:
  - architecture.domain-invariants
  - architecture.idempotency-consistency
  - backend.spring-persistence-tx
  - data.transactions-locks
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：在关闭工单事务中同时更新聚合并插入版本化 OutboxEvent，relay 领取未发送行并记录投递尝试
  covers_topic_groups:
  - architecture-domain-event
  - architecture-outbox
  covers_topics:
  - architecture.domain-event
  - architecture.event-payload-version
  - architecture.event-after-state-change
  - architecture.outbox-table
  - architecture.atomic-state-event
  - architecture.outbox-relay
  uses_capabilities:
  - architecture.domain-invariants
  - architecture.idempotency-consistency
  - backend.spring-persistence-tx
  - data.transactions-locks
  evidence_kind: system-artifact-and-negative-tests
  verification_mode: system-security-resilience-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入先提交业务后插事件、relay 发送后崩溃和 payload 无版本，模拟故障证明丢失/重复后修复
  covers_topic_groups:
  - architecture-domain-event
  - architecture-outbox
  covers_topics:
  - architecture.domain-event
  - architecture.event-payload-version
  - architecture.event-after-state-change
  - architecture.outbox-table
  - architecture.atomic-state-event
  - architecture.outbox-relay
  uses_capabilities:
  - architecture.domain-invariants
  - architecture.idempotency-consistency
  - backend.spring-persistence-tx
  - data.transactions-locks
  evidence_kind: fault-injection-fix-rerun
  verification_mode: fault-injection-rerun
---
# 领域事件、Outbox 与提交一致性

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《幂等键、乐观并发、重复提交与重放》](ch.architecture.idempotency-concurrency.md)：独立完成领域事件、Outbox 一致性前，必须先具备「幂等键、乐观并发、重复提交与重放」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套资产以 JDK 25 的离线事务快照、队列领取和幂等消费模型证明“业务与 outbox 同提交/同回滚、崩溃可重复但不静默丢失、eventId 稳定、版本可解析”的协议预言；它不启动 Spring Boot、MyBatis、PostgreSQL、Testcontainers 或消息代理，因此不证明真实 JDBC 连接、事务代理、行锁、隔离级别、进程崩溃和网络确认窗口已经关闭。

FactoryCare 的工单从 `RESOLVED` 变成 `CLOSED` 后，报表要更新，知识模块可以生成待审核草稿，通知可以提醒相关人员。最直接的实现是先提交工单，再调用这些组件；然而进程可能在提交后、调用前崩溃。反过来，若先发消息再提交，消费者可能看见最终回滚的“幽灵关闭”。Outbox 的核心思想很朴素：把“稍后需要投递的已发生事实”先作为一行数据，与业务状态写进同一个 PostgreSQL 本地事务。事务成功，两行都在；事务失败，两行都不在。随后独立 relay 反复投递，接受重复并靠消费者幂等吸收。

## 1. 完成定义、证据入口与非目标

完成本章后，应能：

1. 区分命令、领域事件、集成事件、审计记录和通知任务；
2. 只在领域状态变化通过 guard 后构造“已发生事实”，不发布愿望或未提交结果；
3. 为事件定义稳定 envelope、最小 payload、`eventId`、`eventType`、版本和发生时间；
4. 判断加字段何时可保持 v1，删除、改义、改单位或改必填性何时必须 v2；
5. 在一个 Spring/PostgreSQL 事务内同时执行聚合条件更新、transition、核心审计和 outbox insert；
6. 让任一必要写失败时整体回滚，并用数据库事实而非日志证明；
7. 设计可并发领取、有限重试、退避、隔离和恢复的 relay；
8. 解释发送成功后进程崩溃为何必然可能产生重复，为什么稳定 `eventId` 与消费者幂等是合同；
9. 拒绝 Exactly Once、全局顺序、即时到达和“Outbox 等于消息代理”的过度承诺；
10. 使用最老未发布年龄、失败次数、隔离量和消费延迟诊断积压。

配套入口：

- [领域事件与 Outbox 示例](../../../examples/encyclopedia/ch.architecture.domain-events-outbox/README.md)
- [提交/投递窗口故障实验](../../../labs/encyclopedia/ch.architecture.domain-events-outbox/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.architecture.domain-events-outbox/README.md)

本章不引入 Kafka/RabbitMQ，不设计跨多个数据库的原子提交，不用 outbox 替代业务审计，不保证全局顺序或端到端 Exactly Once，也不把 reporting、notification、AI 索引纳入关闭工单的核心事务。这些是刻意边界，不是遗漏。

## 2. 从零区分五种“东西”

**命令**表达希望系统做什么，例如 `CloseWorkOrder`。它可被拒绝，名称通常用祈使语义，携带 actor、expectedVersion、idempotency key 和输入。命令不是事实，不能因为收到命令就广播 `WorkOrderClosed`。

**领域事件**表达领域模型内已经发生的事实，例如工单通过验证并从 `RESOLVED` 进入 `CLOSED`。它在领域语言中有意义，可以帮助同一模块解耦后续规则。领域对象可在内存中记录候选事件，但只有事务提交后，外界才能把它当持久事实。

**集成事件**是跨模块或跨进程的受治理合同。它通常由领域事实映射而来，具有版本、最小 payload、兼容规则和长期消费者。FactoryCare 的 `WorkOrderClosed.v1` 就是事件目录中的集成事件。不要把内部 Java 类序列化后直接当公共合同，否则一次重构 getter 或包名就会破坏消费者。

**审计记录**回答谁在何时以什么权限执行了什么核心动作、结果如何，是受保护证据。FactoryCare 的核心状态审计与业务状态同事务追加，不能等待 outbox 消费者“以后补”。事件可为外部 Provider 回执或派生证据提供线索，但不能填补核心审计空洞。

**通知/任务**是对事实的反应，例如发送邮件或生成知识草稿。通知可能失败、重试、取消，措辞也会变化；不要把 `EmailSent` 混成关闭工单事实。一个事实可以触发多个任务，一个任务失败不应倒转已经合法关闭的工单。

## 3. “事件在状态变化之后”是什么意思

正确顺序首先发生在领域模型内部：加载工单，验证 tenant、角色、当前状态、验证记录和 expectedVersion；执行 `close()`，让 guard 通过并改变状态/version；然后根据新状态构造 `WorkOrderClosed.v1` 候选。若 guard 失败，根本没有 Closed 事件。

“之后”不是说必须等数据库 COMMIT 完再生成 eventId/插 outbox。若在提交后才插，就重新打开丢失窗口。候选事件在内存中由成功状态变化产生，outbox 行在同一个数据库事务内写入；只有整个事务提交，外部 relay 才能看见。于是领域因果顺序与数据库原子性同时满足。

也不能先创建并发布事件，再尝试状态更新。乐观锁影响行数为 0 时，当前命令并未关闭工单；若事件已进入外部系统，就产生幽灵事实。事件创建可以提前生成不可变 ID，但持久/可见必须受同事务成功约束，失败后不能单独投递。

## 4. FactoryCare 的事件治理边界

当前唯一允许的六个核心事件是：`WorkOrderCreated.v1`、`WorkOrderAssigned.v1`、`WorkOrderResolved.v1`、`WorkOrderClosed.v1`、`KnowledgeDocumentPublished.v1`、`KnowledgeDocumentRevoked.v1`。新增 `SlaBreached.v1` 或 `NotificationSent.v1` 不能因为代码方便临时发出，必须先进入项目规范、事件目录、schema、消费者与验收设计。

事件名使用过去式并包含版本后缀。`WorkOrderCloseRequested` 与 `WorkOrderClosed` 不同：前者最多表示请求被受理，后者表示领域事实已提交。消费者不能根据一个模糊 `WorkOrderChanged` 猜字段差异和状态迁移；明确事件减少耦合和错误推断。

生产模块拥有事实语义，shared-infrastructure 拥有 outbox 技术表与 relay。业务模块只调用 `OutboxPort`，不依赖 outbox repository、数据库实体或发布器实现。这样将来从数据库轮询换为 CDC/消息代理适配器时，业务用例不需要知道 transport 细节。

## 5. Envelope：让每次投递可识别、可追踪、可解析

FactoryCare 事件 envelope 至少包含：

| 字段 | 含义与约束 |
| --- | --- |
| `eventId` | 每个逻辑事件的全局稳定 UUID；重投不能换 |
| `eventType` | 唯一类型字段，如 `WorkOrderClosed.v1` |
| `version` | 数值 schema 版本，与类型/文件一致 |
| `occurredAt` | 业务事实发生时间，不是 relay 发送时间 |
| `tenantId` | 可信生产上下文中的租户边界 |
| `aggregateId` | 工单等聚合身份，不代替 tenant 条件 |
| `traceId` | 关联命令、日志与投递，不作幂等键 |
| `payload` | 消费者完成已批准用途所需的最小事实 |

`eventId` 与 command idempotency key 不是同一概念。一个命令可能产生零个或多个事件；同一命令重放应返回首次结果并不再生成第二个逻辑事件。relay 每次尝试必须复用 outbox 中的 eventId。若每次发送都新建 UUID，消费者无法识别重复，所谓幂等合同失效。

`occurredAt` 由生产事实决定，重试时不更新；`publishedAt` 或 attempt 时间属于 outbox 传输元数据。把发送时间写回 occurredAt 会让报表因重试看见事实“晚发生”，也会打乱聚合内顺序判断。

## 6. Payload 最小化与版本化

`WorkOrderClosed.v1` payload 包含 asset/equipment model、验证人和关闭人 membership ID、resolution summary、work log/part usage ID、aggregateVersion 与 closedAt。它没有复制完整工单、成员资料、权限表或附件内容。消费者若需更多敏感数据，应通过受授权 API/读模型获取，而不是让事件成为绕过授权的数据副本。

最小化不等于只发 aggregateId。若消费者必须立即识别撤销目标或按版本幂等，必要 ID/version 应随事件提供。设计时列出每个批准消费者实际需要的字段，再取稳定交集；不要为“将来可能有用”复制整表。

事件 schema 允许未知可选字段，消费者只读已知字段并忽略未知字段。新增可选字段只有在现存消费者实验证明能忽略时才可保持 v1。删除字段、改变含义、把秒改毫秒、可选改必填、字符串改对象，都应创建 v2。`eventType` 中版本与 `version` 数值必须一致，避免一个说 v1、另一个说 2。

JSON Schema Draft 2020-12 可以验证形状、必填、const、格式与大小边界，但“JSON 能解析”不证明语义正确、生产事务原子或消费者已经实现。FactoryCare schema 使用 `additionalProperties: true` 支持兼容扩展，消费者测试必须验证未知字段不会被当作权限/命令或导致拒绝。

## 7. Outbox 表保存什么

一个可治理的 `outbox_event` 至少需要 tenant、event_id、event_type、aggregate_id、occurred_at、payload、status 和 attempts。生产所需 envelope 字段要么成为列，要么完整保存在不可变 payload/envelope；relay 不应在发送时重新查询当前工单并重建事实，因为当前状态可能已经再次变化。

可扩展字段包括 aggregate_type、aggregate_version/sequence、next_attempt_at、claimed_by、claimed_until、last_error_code、published_at、created_at。`event_id` 必须唯一。payload 可用 PostgreSQL `jsonb`，但仍须在应用边界用 schema/类型验证；jsonb 不会自动保证事件版本合同。

状态机可取 `PENDING -> IN_FLIGHT -> PUBLISHED`，失败后回 `PENDING` 并设置 nextAttempt，超过有限阈值进入 `ISOLATED`。也可不持久 IN_FLIGHT 而用事务行锁领取；选择取决于一次 relay 事务是否跨网络。关键是状态迁移有 guard、有租约恢复、有 attempt 证据，不能让 `PROCESSING` 永久卡住。

不要在成功发送后立刻物理删除。保留期、归档和清理由治理策略决定；删除未确认行会造成不可恢复丢失。长期保留又会无限增长，所以应按 published/occurred 时间分区或批量归档，并确认审计、重放和隐私要求。

## 8. 同库同事务：Outbox 唯一能提供的核心保证

在 FactoryCare 关闭工单应用服务中，一个 Spring 事务应依次完成：

1. 读取并锁定/以 expectedVersion 验证工单；
2. 执行领域 close guard，得到新状态与 aggregateVersion；
3. MyBatis 条件更新 `WHERE tenant_id=? AND id=? AND version=?`；
4. 检查影响行数恰为 1，否则抛出并发冲突；
5. 插入 work_order_transition；
6. 经 AuditAppendPort 追加必要核心审计；
7. 构造版本化 `WorkOrderClosed.v1`；
8. 经 OutboxPort 插入同一 DataSource 的 outbox_event；
9. 保存幂等响应；
10. 统一提交。

“同一 `@Transactional` 方法”本身不是证据。必须确认所有 mapper 使用同一个事务管理器/DataSource，调用经过 Spring proxy，不是 self-invocation 或手动新线程；没有 `REQUIRES_NEW` 把 outbox 提前提交；异常没有被 catch 后吞掉；rollback 规则覆盖实际异常。真实集成测试要在失败后从新连接查询业务与 outbox 均不存在。

MyBatis insert 成功不代表前面的业务 update 一定成功。每一步影响行数必须验证。若 outbox insert 因 event_id 唯一约束、payload 大小或数据库故障失败，应抛出让整个关闭命令回滚。不能记录一条 warn 然后返回 200，否则状态存在而待投递事实缺失。

## 9. 为什么“提交后直接发送”会丢

考虑时间线：事务 COMMIT 已返回，进程准备调用 broker/HTTP，机器掉电。数据库有 CLOSED，外部没有事件，重启后没有持久线索知道该发什么。即使窗口只有微秒，只要存在且业务要求可靠，就不能称“不会丢”。重试 HTTP 请求也不保证修复：客户端可能不重试，或幂等层只重放成功响应而不重新执行副作用。

Spring `@TransactionalEventListener` 默认绑定 `AFTER_COMMIT`，适合只在成功提交后执行非原子后续，但它本身没有把后续动作变成持久、可恢复工作。若监听器在进程崩溃时没运行，事件仍丢。官方文档还说明没有事务时默认不调用，除非开启 fallback。不要把注解名称误读为可靠消息机制。

`BEFORE_COMMIT` 监听器可以参与当前事务，但隐式监听顺序和异常边界较难审查。FactoryCare 更适合由关闭用例显式调用 OutboxPort，让代码审查清楚看见必要写。无论使用哪种机制，验收都看同事务数据库事实，而不是看注解存在。

## 10. 为什么“先发送再提交”会有幽灵事件

如果先把 `WorkOrderClosed` 发给知识模块，随后数据库因乐观锁、审计失败或连接中断回滚，消费者已经生成草稿，而权威工单仍是 RESOLVED。外部消息无法被数据库 rollback 撤回；再发补偿消息也可能丢、乱序或再次失败。

两阶段提交理论上协调多个支持者，但外部 HTTP、邮件、AI Provider 往往不参与，运维和可用性成本也不符合当前项目。Transactional Outbox 选择更小的承诺：只保证业务事实和“待投递记录”同库原子；跨出数据库后至少一次，消费者显式幂等。

不要在数据库事务里等待 Provider，以为异常就 rollback 一切。Provider 可能已经接受请求但响应丢失，数据库回滚后外部副作用仍存在；长事务还持有锁、耗尽连接并放大故障。核心事务只记录事实与待投递意图，外部工作异步处理。

## 11. Relay 的职责与批次生命周期

relay 周期性寻找 `PENDING` 且 `next_attempt_at <= now` 的行，领取有界批次，转换为传输格式，发送，最后记录成功或失败。它不是业务模块，不修改工单事实，不临时改 payload，不为每次尝试生成新 eventId。

一个典型批次流程：

```text
短事务 A：SELECT eligible ORDER BY occurred_at,event_id
          FOR UPDATE SKIP LOCKED LIMIT N
          -> 标记 claimed_by/claimed_until，attempts + 1
          -> COMMIT

事务外：逐条发送，得到成功/可重试/永久不兼容结果

短事务 B：按 event_id + claim owner 条件记录 PUBLISHED、nextAttempt 或 ISOLATED
```

不能在持有数据库行锁时进行无界网络调用，否则慢 broker 会让锁和连接长期占用。若选择在同一短事务内把行标记 IN_FLIGHT，必须有 lease 到期回收；进程崩溃后另一个实例才可重新领取。`attempts` 在何时增加要一致，避免监控与退避错一位。

## 12. PostgreSQL `SKIP LOCKED` 的准确边界

多个 relay 实例同时轮询时，`FOR UPDATE SKIP LOCKED` 可跳过已被另一事务锁住的候选行，减少队列式表的竞争。PostgreSQL 18 官方文档明确警告它给出不一致视图，不适合一般查询，但可用于多个消费者访问 queue-like table。这里正是受控队列领取用途。

`SKIP LOCKED` 不保证公平，也不自动防饿死。查询必须有确定 `ORDER BY`（例如 next_attempt_at、occurred_at、event_id），批次有上限，并观察最老未发布年龄。高频新事件若总抢先，旧失败行可能永久留后。锁只覆盖选中行且仍需普通表级锁；schema 变更和长事务也会影响 relay。

如果网络发送放在锁事务外，领取标记必须防两个实例同时处理；如果放在锁内，必须严格限制调用并评估锁时长。没有一种 SQL 片段自动解决所有窗口，设计必须画出 BEGIN/COMMIT、发送和崩溃点。

## 13. 至少一次：重复不是异常边缘，而是正常合同

最关键窗口是：relay 把事件发送成功，消费者已提交副作用；relay 在更新 outbox 为 PUBLISHED 前崩溃。重启后该行仍可领取，事件再次发送。若为避免重复而在发送前标记 PUBLISHED，则进程在标记后、发送前崩溃会永久丢失。只靠本地状态无法同时消除这两个窗口。

Outbox 选择“不静默丢失，允许重复”。重投必须保持 eventId、eventType、version、occurredAt 和 payload 不变；attempt 元数据可以变化。消费者以 eventId 原子声明处理，业务副作用与 consume record 尽量同一事务。同 eventId 第二次到达时返回已处理结果或安全忽略，不能再次创建知识草稿、再次发送 Provider 请求或重复计数。

若消费者调用外部 Provider，还应把 eventId 作为 Provider 支持的幂等键，或在本地建立“准备—调用—结果”恢复协议。单独在消费表插一行后再调 Provider也有崩溃窗口；Exactly Once 不能靠一个 `Set<UUID>` 口号获得。

## 14. 消费者幂等与稳定事件身份

最小消费表可按 `(consumer_name,event_id)` 唯一，记录 payload hash/schema version、状态、首次/最后尝试和结果引用。为什么带 consumer_name：同一事件可被 reporting 与 knowledge 各处理一次，不能因前者消费就阻止后者。为什么校验 hash：同 eventId 若出现不同 payload 是生产/传输污染，应隔离告警，不能当普通重复吞掉。

消费流程先验证 eventType/version/schema，再尝试原子声明；已完成同 hash 则安全跳过；不同 hash 则隔离；新事件执行受保护副作用并一起完成记录。若版本不支持，`FC-EVT-003` 要求安全隔离与告警，不能猜字段或默认为 v1。

幂等不仅是数据库去重。报表可用 eventId 唯一或 aggregateVersion 条件更新；知识草稿可用 sourceEventId 唯一；计数器可保存 contribution identity。选择与副作用同一事务的业务唯一约束，比“先查 consume_record 再执行”更可靠，因为两个线程可能同时未查到。

## 15. 顺序：没有全局顺序，聚合内也要显式

数据库自增 outbox ID、occurredAt 和 broker offset 都不能自然成为全系统业务顺序。两个事务并发提交时，ID 分配、事实时间、提交顺序和发送顺序可能不同；relay 重试又会让旧事件晚到。FactoryCare 明确不保证全局顺序。

若消费者必须按同一工单变化应用读模型，事件 payload 提供 `aggregateVersion`，消费者维护 lastAppliedVersion。收到相同/更旧版本可幂等跳过；收到未来 version 10 而本地只有 8，应等待/重试/回源重建，而不是直接覆盖。不同工单之间通常无需排序。

版本也不万能：消费者可能只关心 Closed 一类事件，不会收到所有中间 version；合同必须说明 aggregateVersion 是去旧、检测缺口还是严格连续序号。不要先写 `ORDER BY created_at` 再宣称业务有序。

## 16. 重试、退避、隔离与人工恢复

错误至少分三类：临时传输失败（超时、503）可指数退避并加抖动；确定不兼容（未知版本、schema 违规）应立即隔离；业务永久拒绝（目标已撤销、非法合同）按受治理策略隔离或标记无需动作。把所有异常无限每秒重试会形成 poison event 热循环，拖垮正常事件。

有限重试不是到次数就删除。`ISOLATED` 行保留 eventId、版本、安全错误摘要和恢复入口；修复消费者或数据后，授权操作员可以重置 nextAttempt 并重放同一事件。人工界面不能允许任意改 payload 后继续用同 eventId；若事实合同确需更正，应通过治理流程发布新事件/版本和关联关系。

退避的基数、上限、抖动和最大尝试应配置化并记录 policy version。批次中一个 poison event 不应阻断其余行；但若整体传输不可用，熔断/暂停可避免无意义重试。恢复时限速，避免积压洪峰击穿消费者。

## 17. FactoryCare 关闭工单完整案例

命令携带 tenant、workOrderId、expectedVersion、verificationId、actor membership 与 idempotency key。应用服务在可信 TenantContext 下加载工单，验证当前为 RESOLVED、验证已通过、actor 有关闭权限。领域 `close()` 返回新状态、closedAt、aggregateVersion，并登记一个不可变候选事实。

同一事务执行：条件更新 work_order；插入 transition；追加核心 audit；把候选映射为符合 `work-order-closed.v1.schema.json` 的 envelope；插入 outbox_event；保存首次幂等响应。任何 mapper 返回异常或影响行数不符都抛出。提交后 HTTP 返回 CLOSED 与新 version；通知、reporting、知识草稿不阻塞响应。

relay 领取该行，发送 `WorkOrderClosed.v1`。知识消费者按 `(consumer=knowledge-draft,eventId)` 唯一，创建一个待审核草稿，绝不直接发布知识。reporting 消费者更新派生指标。重复投递只看到相同 eventId，各自副作用一次。消费者延迟不会使工单回到 RESOLVED，但积压超过 SLO 会告警并提供人工恢复。

`FC-WO-008` 的“一条事件”指一次成功关闭命令产生一个逻辑 eventId/outbox 行，不代表 transport 只送一次。测试应分别断言 outbox 中 event_id 唯一、relay 重发 eventId 不变、消费者最终副作用一份。

## 18. 同提交/同回滚的验证方法

只用 Mockito 验证 `outboxPort.append()` 被调用，不能证明事务。T4 集成测试至少使用 Testcontainers PostgreSQL 18 当前 minor、真实 schema/MyBatis mapper 和 Spring 事务代理。测试从新连接观察提交结果，避免同一 persistence context/连接给出未提交幻象。

正向：执行关闭，断言 work_order CLOSED/version+1、transition 一行、核心 audit 一行、outbox 一行且 envelope schema 通过。幂等重放相同命令，断言这些副作用数量不增加并返回首次响应。

负向 `FC-EVT-001`：在 outbox insert 前或 insert 时注入确定异常，断言业务状态、transition、audit、outbox 与完成幂等记录均未提交。`FC-AUD-001`：让 audit append 失败，同样全部回滚。另一个连接应看到旧 version。

并发：两个关闭请求同 expectedVersion 同时释放，只有一个条件更新影响 1 行并产生一个 eventId；另一请求冲突，无幽灵事件。不要断言具体线程赢家。若同一幂等 key 重放，则返回首次 event/result，不生成第二事件。

## 19. 三个必做崩溃窗口

**业务提交后、若无 outbox 插入前崩溃。** 错误实现会留下 CLOSED 无事件。修复为同事务 insert；故障在事务中发生时两者回滚，提交后 outbox 已持久存在。

**relay 发送成功后、记录 PUBLISHED 前崩溃。** 修复不能消灭重复，而是证明行重新领取、eventId 不变、消费者副作用仍一份。测试可用 fake transport 在“接受”后抛出模拟进程失联；下一轮重发。

**payload 无版本或消费者不支持版本。** 错误实现可能按当前 Java 类猜测，产生错字段/错单位。修复为 envelope/type/version 校验，不支持时进入隔离，告警包含 eventId/type/version 和安全错误码，不执行业务副作用。

还应覆盖发送前标记成功、每次重试重建 eventId、无限重试 poison、claim 永不超时、清理未发布行、同 eventId 不同 payload、跨租户聚合查询漏 tenant。故障测试应输出稳定预言，不依赖线程名称、真实时间或随机赢家。

## 20. 常见失败诊断剧本

**工单 CLOSED，但 outbox 没行。** 先核对是否同一 DataSource/事务管理器、OutboxPort 是否在代理边界内、异常是否被吞、是否用了 AFTER_COMMIT 内存监听、条件 update 是否验证行数。用事务 ID/trace 关联但最终以数据库查询为准。补发前先确认事实和事件 schema，不能凭日志随意造 eventId。

**outbox 持续增长。** 查看 oldest unpublished age、nextAttempt、status 分布、claim lease、relay 心跳、transport latency 和 poison version。总行数增长可能只是清理未运行；最老未发布增长才更直接反映交付积压。不要先扩批次而忽略消费者 400/schema 错误。

**同一知识草稿生成两份。** 对比 sourceEventId。若 eventId 相同，消费者缺唯一约束/原子声明；若不同但 payload 表示同一次关闭，生产幂等或 relay 错误重建 ID；若确为两次合法事实，检查工单状态机为何允许重复关闭。分层定位比在 UI 合并重复更可靠。

**relay 行永久 IN_FLIGHT。** 进程可能在领取后崩溃而没有 lease 回收。检查 claimedUntil、owner fencing 和恢复任务。不能简单把所有 IN_FLIGHT 改 PENDING 而让仍活跃实例同时发送；需过期条件与 owner compare-and-set。

**事件“乱序”。** 先问是否真的有顺序合同。比较 tenant/aggregateId/aggregateVersion，而不是只看 occurredAt。若同聚合 version 缺口，隔离或回源重建；若不同聚合，通常无需全局排序。增加全局锁会牺牲吞吐且不能修复语义不清。

**未知 v2 被当 v1 处理。** 检查反序列化是否忽略 `eventType/version`、默认值是否掩盖缺字段、catch 是否把 schema 异常当临时重试。修复为显式 handler registry 和 quarantine，补兼容测试后再启用 v2。

## 21. 观测与运行手册

生产端至少记录 outbox created rate、pending/isolated count、oldest unpublished age、attempt distribution、publish latency、claim expired count、schema rejection 和 cleanup rate。消费者记录 receive-to-apply delay、duplicate count、payload mismatch、unsupported version、processing failure 和 last applied aggregate version。

指标标签使用受控 eventType、consumer、status/error category，不能直接把 eventId、aggregateId 或 tenantId 作为高基数标签。单事件排障通过结构化日志/trace 查询，日志最小化 payload，敏感 resolutionSummary 不应完整输出。

运行手册定义：如何暂停/恢复 relay，如何查看并隔离 poison，如何验证消费者幂等，如何在修复后安全重放，如何切换 transport 适配器，如何归档 published 行，如何处理 schema v2 双读/有限双写。回滚传输层时可退回数据库轮询，但绝不删除未确认行或回滚核心审计端口。

SLO 应分别描述“业务提交成功率”和“事件最终可用时间”。核心事务成功不等于派生系统立即一致；oldest age 超阈值需告警。对知识撤销这类安全敏感派生，积压可能要求同步安全闸门或查询时回源，不能仅等待一般事件延迟。

## 22. Spring、MyBatis 与事务边界检查

Spring 声明式事务通常依靠代理拦截 public bean 调用。类内 `this.close()` 可能绕过代理；新建线程、`CompletableFuture` 或 Reactor 上下文也不会自动继承传统线程绑定事务。测试必须通过真实 bean 入口调用，并确认实际 transaction manager。

`@TransactionalEventListener(AFTER_COMMIT)` 只说明监听时机，不提供持久队列；监听器中的数据库写还涉及事务资源状态和传播设置。Outbox 的主线实现应显式在核心事务内插入。可以在提交后发一个“唤醒 relay”的非可靠提示以降低延迟，但即使提示丢失，轮询仍能找到 outbox 行。

MyBatis mapper 要保留 tenant 条件、expectedVersion 和影响行数。批量 relay SQL 是 PostgreSQL 方言，应在 mapper/测试中明确。避免把 JSON payload 拼进 SQL；使用参数绑定、大小限制和受控序列化。数据库默认时间、应用 occurredAt 和 trace 时间分别有清楚来源。

事务超时、连接池、隔离级别和异常翻译是集成证据一部分。离线模型无法证明它们，真实 Testcontainers 运行要记录 Spring Boot 4.1.x、其管理的 Spring Framework/MyBatis 组合、PostgreSQL 18 当前 minor、Testcontainers 版本与镜像 digest。

## 23. 独立构建任务与验收

构建一个关闭工单用例、`OutboxPort`、PostgreSQL 表/mapper、轮询 relay 和幂等 fake consumer。生产事务插入 `WorkOrderClosed.v1`；relay 用有界批次领取，记录 attempts/published/isolated；消费者按 consumer + eventId 去重并校验 hash/version。

验收必须同时覆盖：业务与 outbox 正向同提交；outbox/audit 失败同回滚；乐观并发只有一个关闭事件；发送后崩溃允许重投且 eventId 不变；同 eventId 重放只有一个消费者副作用；不支持 version 安全隔离；payload 可用 Draft 2020-12 schema 解析；两个 relay 不重复领取同一 claim；过期 claim 可恢复；没有全局顺序/Exactly Once 的虚假断言。

真实 T4 保存建表 migration、Spring/MyBatis 配置、SQL、容器版本、故障开关、命令、退出码、测试报告和数据库断言。G3 证据路径由 canonical 指向 `evidence/gates/g3/architecture-domain-events-outbox/`，但本章 drafting 与离线资产本身不宣称门禁完成；只有门禁流程按要求采集、审阅和登记后才可升级状态。

## 24. 120 秒口述模板

可以这样讲：领域事件是通过领域 guard 后已发生的事实，集成事件用稳定 envelope 和版本化最小 payload 跨边界传播。FactoryCare 关闭工单时，在同一个 PostgreSQL/Spring 事务里更新聚合、写 transition/核心审计并插入 `WorkOrderClosed.v1` outbox；任一失败全部回滚。提交后 relay 用有界批次领取并发送。发送成功后若在标记前崩溃，事件会重复，所以每次重试保持 eventId，消费者按 eventId 幂等。未知版本隔离，不猜字段。Outbox 保证的是业务事实与待投递记录的本地提交一致性，不保证外部必达、即时到达、全局顺序或 Exactly Once。反例是业务先提交再插事件，进程在两步之间崩溃，留下永远无法发现的 CLOSED 无事件。

口述必须包含领域事件、payload/version、状态变化后的因果、outbox 表、同事务、relay 和至少一个崩溃窗口。只说“把消息先放数据库，定时任务再发”没有提重复、幂等和非目标，不能通过。

## 25. 版本边界与权威来源

本章登记 Spring Boot `4.1.x` GA、PostgreSQL `18.x current minor`、MyBatis Core `3.5.x` 与 Boot Starter `4.x` 兼容线、Testcontainers 的 Boot BOM-compatible release。前三者中实际组合仍要由 Boot BOM 和启动/集成测试确认；Testcontainers 登记为 provisional。严禁把 MyBatis Core 4 当作当前稳定主线，镜像与 patch 必须在证据中记录。

- [Spring Framework：事务管理](https://docs.spring.io/spring-framework/reference/data-access/transaction.html)
- [Spring Framework：transaction-bound events](https://docs.spring.io/spring-framework/reference/data-access/transaction/event.html)
- [PostgreSQL 18：SELECT、行锁与 SKIP LOCKED](https://www.postgresql.org/docs/18/sql-select.html)
- [JSON Schema Draft 2020-12](https://json-schema.org/draft/2020-12)
- [Testcontainers for Java 官方文档](https://java.testcontainers.org/)
- [FactoryCare ADR-0004：事务 Outbox](../../../factorycare-design/adrs/0004-transactional-outbox.md)
- [FactoryCare 事件目录与演进规则](../../../factorycare-design/events/README.md)
- [WorkOrderClosed.v1 Schema](../../../factorycare-design/events/work-order-closed.v1.schema.json)
- [FactoryCare 数据模型](../../../factorycare-design/data/data-model.md)
- [FactoryCare 验收目录](../../../factorycare-design/testing/acceptance-catalog.md)

## 26. 复盘清单

- 我能否区分命令、领域事件、集成事件、审计和通知任务？
- 事件是否只在领域 guard 成功改变状态后产生？
- eventId 在业务重放和 relay 重试中是否稳定？
- eventType、version、schema 文件和 handler 是否一致？
- payload 是否最小、受限、可扩展且不泄露完整敏感记录？
- 业务 update、transition、核心 audit、outbox 和幂等结果是否同 DataSource 同事务？
- 任一 mapper 失败或 update=0 是否让整个命令回滚？
- relay 领取是否有确定排序、有界批次、lease、退避与隔离？
- 发送后崩溃是否重投同 eventId，消费者是否只产生一次受保护副作用？
- 未知版本和同 ID 不同 payload 是否安全隔离而不是猜测？
- 是否只声明明确聚合内顺序，而拒绝全局顺序幻想？
- 是否能用最老未发布年龄和失败分类定位积压？
- 真实 T4 是否使用 Spring/MyBatis/PostgreSQL/Testcontainers，而不是 mock 调用次数？

当这些问题都能指向代码、数据库断言、故障注入和重跑证据时，才算掌握提交一致性。Outbox 的价值不在于把“消息”包装成神奇表，而在于把不可避免的故障窗口移动到可观察、可重试、可幂等处理的位置，并诚实地缩小承诺。
