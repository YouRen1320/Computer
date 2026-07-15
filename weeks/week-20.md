# 第 20 周：异步任务、领域事件、Outbox 与 RabbitMQ 概念

> 建议投入：16 小时（可在 15—18 小时内调整）

## 1. 本周定位

本周解决“主事务已经成功，但通知、统计或外部调用失败怎么办”。目标是掌握异步边界和可靠交付，而不是为了简历把单体强行拆成微服务。

FactoryCare 实现 **数据库 Outbox + 可重试投递器 + 幂等消费者** 的最小可靠闭环；RabbitMQ 只完成概念、管理界面与可选适配实验。工单状态变更仍由数据库事务同步保证，通知等次要副作用才异步化。

## 2. 前置条件

- 工单状态机、事务、审计、幂等与 Redis 故障策略已验收。
- 能解释“事务提交前/后”与 `@TransactionalEventListener` 的差异。
- Docker Compose、结构化日志、关联 ID 和数据库迁移可用。
- 已列出工单流程中的核心事实与可延迟副作用，不把二者混在一起。

## 3. 学习目标

- 能判断任务应同步、线程池异步、定时调度还是消息驱动。
- 能区分领域事件、集成事件和普通方法调用。
- 能解释数据库与消息代理“双写”为什么会丢消息或产生幽灵消息。
- 能实现 Outbox 的同事务写入、领取、发送、重试、失败和清理。
- 能实现至少一次投递下的幂等消费者，并接受“重复可能发生”。
- 能说明 RabbitMQ 的 exchange、queue、binding、ack、confirm、prefetch 与 dead letter。

## 4. 完整概念清单

### 4.1 异步任务边界

- 同步调用、`@Async`、调度任务、数据库队列和消息代理的成本。
- 延迟、吞吐、顺序、可靠性、一致性、可观察性和运维复杂度。
- 有界线程池、队列容量、拒绝策略、背压和上下文传播。
- 超时、重试、指数退避、抖动、最大次数与不可重试错误。
- 重试放大、副作用重复、超时后实际成功等常见问题。
- 关联 ID、租户、操作者等上下文必须显式进入任务载荷，不能依赖原请求线程。

### 4.2 领域事件与事务

- 领域事件是已发生的业务事实，名称使用过去式，如 `WorkOrderAssigned`。
- 事件应包含稳定 ID、聚合 ID、租户、发生时间、Schema 版本和必要快照。
- 事件不携带密码、Token、完整实体或不必要隐私数据。
- Spring `ApplicationEventPublisher` 默认同步；`@Async` 不自动提供可靠性。
- `@TransactionalEventListener(AFTER_COMMIT)` 的使用场景与进程崩溃丢失窗口。
- 核心状态与 Outbox 记录必须处于同一数据库事务。

### 4.3 Transactional Outbox

- Outbox 表：事件 ID、类型、聚合 ID、租户、载荷、版本、状态、尝试次数、下次时间、创建/完成时间。
- 发布事务只写业务数据与 Outbox；投递器在事务外读取和发送。
- 多实例领取：`FOR UPDATE SKIP LOCKED`、租约/状态更新或等价策略。
- 至少一次交付意味着消费者必须幂等；“exactly once”通常只在限定边界成立。
- 失败重试、死信状态、人工重放、载荷版本兼容和保留/清理策略。
- 消费幂等表或业务唯一约束；先记录还是先执行要结合本地事务。

### 4.4 RabbitMQ 核心概念

- Producer、Exchange、Binding、Queue、Consumer、Virtual Host。
- Direct、Topic、Fanout、Headers Exchange 的路由语义。
- 持久队列、持久消息与真正可靠交付的前提。
- Publisher Confirms 与 Mandatory Return；Consumer Ack/Nack、重入队和死循环。
- Prefetch、消费者并发、消息顺序和公平分发。
- Dead Letter Exchange、TTL、重试队列；失败不是无限 `requeue=true`。
- Outbox 解决数据库—消息双写，RabbitMQ 解决跨进程传输；两者不是互相替代。

## 5. 任务分配

| 任务 | 时间 | 结果 |
| --- | ---: | --- |
| 异步边界与事件设计 | 2.5h | 事件目录和决策表 |
| Outbox 写入与投递器 | 4.5h | 可靠投递最小闭环 |
| 幂等消费者与失败恢复 | 3h | 重复/崩溃测试 |
| RabbitMQ 概念和可选实验 | 2h | 路由、确认与 ACK 笔记 |
| 无 AI 训练 | 2h | 双写故障分析 |
| 求职与项目表达 | 2h | 可靠性面试材料 |

总计 16 小时。若 RabbitMQ 环境占用过多时间，只保留官方教程实验；不得删减 Outbox 失败恢复测试。

## 6. FactoryCare 项目增量

- 按[PROJECT_SPEC.md](../PROJECT_SPEC.md)的唯一目录，为`WorkOrderCreated.v1`、`WorkOrderAssigned.v1`、`WorkOrderResolved.v1`、`WorkOrderClosed.v1`建立版本化事件契约并写入可靠事件链；本轮不另造`SlaBreached.v1`。
- 工单事务在成功变更状态/负责人时同时写入 `outbox_event`，两者任一失败则整体回滚。
- 编写有界批量投递器：领取待处理事件、增加尝试次数、调用通知端口、记录成功或下次重试。
- `engagement`模块先用本地通知适配器/测试替身，确保项目不依赖RabbitMQ也可启动。
- `WorkOrderClosed.v1`先可靠发布并保留幂等消费契约；Week 40由`knowledge`通过`ai-integration`生成知识草稿，失败不得回滚已关闭工单。
- 消费端按事件 ID 去重；同一事件重复投递不会创建两条通知或重复修改业务事实。
- 增加人工重放命令或受限管理接口，只允许重放失败事件并留下审计。
- 可选：Docker Compose 启动 RabbitMQ，将通知端口替换为 AMQP 适配器，验证 confirm、ack 和重复投递；不把它设为本周硬依赖。
- 制造四种故障：业务回滚、提交后进程退出、消费者处理后未确认、永久失败；记录恢复结果。
- 编写 `ADR-017-reliable-events.md`，比较直接异步、事务监听、Outbox、RabbitMQ 的成本与适用边界。

## 7. AI 协作边界

AI 可以：

- 根据业务事实审查事件命名、最小载荷和版本字段。
- 生成 Outbox 状态机、故障注入和重复消费测试清单。
- 比较 RabbitMQ 路由与确认机制，帮助解释日志。
- 审查重试策略是否可能无限循环或放大流量。

AI 不可以：

- 把任意 Service 调用自动改成事件，或擅自扩大最终一致范围。
- 承诺“绝对不丢、不重、Exactly Once”而不给出限定条件和证据。
- 决定哪些业务允许最终一致、失败后是否人工重放。
- 访问真实 RabbitMQ 凭据或生产消息载荷。

对 AI 生成的重试/确认代码，必须逐一验证崩溃发生在“提交前、提交后、发送前、发送后、确认前”时的结果。

## 8. 无 AI 训练

本周从求职/复盘时段预留45—60分钟完成并记录：一维动态规划变体；比较递归、记忆化和迭代。

关闭 AI 120 分钟，分析并修复“工单已分配但通知永久丢失”的双写代码：

- 画出数据库提交和消息发送的两个失败顺序。
- 将业务更新和 Outbox 写入同一事务。
- 编写最小投递器和幂等消费者。
- 通过故障注入证明提交后崩溃仍可恢复，重复投递不产生重复通知。
- 口述为什么 `@Async`、`@TransactionalEventListener(AFTER_COMMIT)` 和 RabbitMQ 持久消息单独都不能解决数据库双写。

## 9. 求职动作（恢复求职后启用）

- 采样 8 个南昌 Java/企业应用/制造业岗位，记录 MQ、RabbitMQ、Kafka、异步任务、定时任务和最终一致要求；不要把“出现 MQ”自动理解为必须做微服务。
- 准备 6 分钟故障故事：数据库已提交、进程崩溃、Outbox 如何恢复、为何消费者仍需幂等。
- 简历写为：`以 Transactional Outbox 同事务记录工单事件，构建可重试投递与幂等消费，并通过崩溃/重复投递实验验证恢复`。
- 对要求 MQ 但实际偏业务开发的岗位继续投递；坦诚 RabbitMQ 是项目实验，不伪造生产运维经验。

## 10. 本周交付物

- 事件目录、事件 Schema 和异步边界决策表。
- Outbox 表、投递器、幂等消费者及受控重放。
- `ADR-017-reliable-events.md`。
- 四类故障实验与自动化测试报告。
- RabbitMQ 核心概念图和一段面试讲解。

## 11. 验收标准

- 业务事务回滚时没有可投递事件；业务提交后即使进程退出，事件仍能恢复投递。
- 同一事件投递两次，业务副作用至多发生一次，重复行为可观察。
- 永久失败不会无限热循环，有最大次数、退避、失败状态和审计重放入口。
- 能解释 `@Async`、事务事件、Outbox、RabbitMQ 各自解决的问题和新增成本。
- 能画出 publisher confirm 与 consumer ack 的不同方向。
- 关键状态变更仍保持同步事务一致，未为了技术展示扩大最终一致范围。
- 无 AI 训练和故障实验结果可复现。

## 12. 明确不做

- 不拆微服务，不同时引入 RabbitMQ、Kafka、Pulsar。
- 不让消息队列成为 FactoryCare 本地启动的硬依赖。
- 不承诺无条件 Exactly Once，不使用无限重试。
- 不把核心权限校验、工单状态变更或扣减类操作随意异步化。
- 不实现复杂 Schema Registry、跨地域复制和大规模消息压测。

## 13. 官方资料

- [Spring Framework Application Events](https://docs.spring.io/spring-framework/reference/core/beans/context-introduction.html#context-functionality-events)
- [Spring Framework Transaction-bound Events](https://docs.spring.io/spring-framework/reference/data-access/transaction/event.html)
- [Spring Modulith 事件发布注册表](https://docs.spring.io/spring-modulith/reference/events.html)
- [RabbitMQ Tutorials](https://www.rabbitmq.com/tutorials)
- [RabbitMQ Publisher Confirms 与 Consumer Acknowledgements](https://www.rabbitmq.com/docs/confirms)
- [RabbitMQ Dead Letter Exchanges](https://www.rabbitmq.com/docs/dlx)
- [RabbitMQ Consumer Prefetch](https://www.rabbitmq.com/docs/consumer-prefetch)
- [PostgreSQL SKIP LOCKED](https://www.postgresql.org/docs/current/sql-select.html#SQL-FOR-UPDATE-SHARE)
