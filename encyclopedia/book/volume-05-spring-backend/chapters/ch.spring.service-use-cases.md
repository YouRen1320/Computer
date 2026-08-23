---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.service-use-cases
title: 应用服务、用例编排与领域边界
responsibility: 教授应用服务协调领域和持久化端口，不把 Controller、SQL 或跨系统细节写入领域对象
volume: '05'
order: 13
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.service-use-cases.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.mybatis-repositories
version_surfaces:
- spring-boot-4.1
- spring-framework-7
- mybatis
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释应用服务、用例编排与领域边界的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - application-service
  - layer-boundary
  covers_topics:
  - architecture.application-service
  - architecture.use-case-input-output
  - architecture.transaction-intent
  - architecture.controller-service-repository
  - architecture.domain-purity
  - architecture.dependency-direction
  uses_capabilities:
  - architecture.domain-invariants
  - data.persistence-access
  - backend.spring-di-config
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现 AssignWorkOrderService：加载聚合、执行领域行为、保存并返回用例结果，Controller 只做协议转换
  covers_topic_groups:
  - application-service
  - layer-boundary
  covers_topics:
  - architecture.application-service
  - architecture.use-case-input-output
  - architecture.transaction-intent
  - architecture.controller-service-repository
  - architecture.domain-purity
  - architecture.dependency-direction
  uses_capabilities:
  - architecture.domain-invariants
  - data.persistence-access
  - backend.spring-di-config
  evidence_kind: integration-artifact-and-tests
  verification_mode: framework-or-container-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入 Controller 直接调用 Mapper、Service 只转发 CRUD 和领域对象依赖 HTTP，检查依赖图后重构
  covers_topic_groups:
  - application-service
  - layer-boundary
  covers_topics:
  - architecture.application-service
  - architecture.use-case-input-output
  - architecture.transaction-intent
  - architecture.controller-service-repository
  - architecture.domain-purity
  - architecture.dependency-direction
  uses_capabilities:
  - architecture.domain-invariants
  - data.persistence-access
  - backend.spring-di-config
  evidence_kind: integration-failure-fix-rerun
  verification_mode: integration-fault-rerun
---
# 应用服务、用例编排与领域边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Repository 边界与 Spring MyBatis 适配》](ch.spring.mybatis-repositories.md)：独立完成应用服务、分层边界前，必须先具备「Repository 边界与 Spring MyBatis 适配」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 drafting。教材和工件是学习证据，不自动更新 `PROGRESS.md`，也不代表 FactoryCare 生产事务已经验证。

一次“派单”不是 Controller 改一列：它要识别可信租户与操作者，加载工单，调用聚合规则，保存版本变化，追加核心审计与 outbox，并返回稳定结果。应用服务负责让这些参与者按一个用例意图协作；领域对象负责决定派单是否合法；Repository 负责持久化；Controller 只翻译 HTTP。

本章基线为 Spring Boot 4.1.0、Spring Framework 7.0.8、MyBatis Spring 4.0 线、JDK 25 与 Maven 3.9.16。官方资料复核日期为 2026-07-17。

## 1. 本章完成证据

完成者要实现 `AssignWorkOrderService`：按租户和 ID 加载聚合，调用 `assign`，保存并返回用例结果；测试证明顺序可观察、规则只在聚合、Repository 可替换、Controller 与 SQL/协议不会越层。

配套工件：

- [应用服务边界观察台](../../../examples/encyclopedia/ch.spring.service-use-cases/README.md)
- [派单事务与分层实验](../../../labs/encyclopedia/ch.spring.service-use-cases/README.md)
- [修复 CRUD 转发服务练习](../../../exercises/encyclopedia/ch.spring.service-use-cases/README.md)

## 2. 什么是一个用例

用例是某个参与者为达成业务目标发起的一次系统动作，例如“调度员把待派工单分配给班组和技师”。它有输入、授权上下文、成功结果、预期拒绝和基础设施失败。

用例不是某张表的 CRUD 名称。`updateWorkOrder` 没有表达谁能改什么、哪些规则必须同时成立，也没有稳定结果语义。

## 3. 应用服务的职责

应用服务实现用例编排：解析内层 command，调用授权/查询端口，加载聚合，执行领域行为，调用持久化与事件端口，形成 output。它协调而不拥有工单状态机规则。

“先加载、再行为、再保存”看似简单，却给事务、失败分类、幂等与测试提供了明确骨架。

## 4. 三类边界角色

输入适配器是 Controller、消息消费者或 CLI；应用层是用例服务；输出适配器是 MyBatis Repository、审计、outbox 或远程客户端。内层只依赖端口。

同一 AssignWorkOrder 用例可被 HTTP 和后台命令调用，而不用复制业务规则。

## 5. Controller 只做协议转换

Controller 读取 path、header、认证主体和 JSON，完成协议级校验，把它们转为 `AssignWorkOrderCommand`，调用用例，再把 result/exception 转为 HTTP response。

它不写 SQL、不调用 Mapper、不修改聚合字段、不开启跨多个 Controller 的业务流程。

## 6. 协议校验与业务校验

“字段缺失、JSON 不是 UUID、字符串超过长度”属于请求协议校验；“当前状态不能派单、技师不在班组、版本已过期”属于业务/授权规则。

前者可由 Bean Validation/Controller 处理，后者必须在应用与领域边界重复建立可信事实，不能相信客户端说“已校验”。

## 7. Command 是用例输入

Command 使用业务语义字段：可信 `tenantId`、`actorMembershipId`、`workOrderId`、`teamId`、可选技师和 `expectedVersion`。它不是 HttpServletRequest，也不是 MyBatis Row。

命名表达意图：`AssignWorkOrderCommand` 比 `UpdateRequest` 更能稳定承载规则和审计语义。

## 8. 可信上下文不能来自 JSON

租户、主体与权限范围来自认证和服务端成员上下文。Controller 可组合它们与请求字段，但不能接受客户端任意覆盖 tenantId。

应用服务仍经端口验证 actor、team、technician 属于同租户/组织/范围，防止适配器遗漏导致越权。

## 9. Result 是用例输出

Result 返回调用者真正需要的稳定事实，例如工单 ID、新状态、新版本与 assignment 摘要。它不返回数据库 Row、Mapper 行数或 Spring ResponseEntity。

HTTP 201/200/409 属于外层选择；同一结果可由消息或 CLI 适配器以不同协议表达。

## 10. 领域聚合拥有规则

`WorkOrder.assign(...)` 判断当前状态是否 TRIAGED、版本是否命中、团队/技师信息是否有效，并产生状态、版本和领域事实变化。应用服务不能用 setter 绕过它。

规则下沉后，Controller、定时任务与消息入口共享同一行为，而不是各自复制 if。

## 11. 应用服务不应只是 CRUD 转发

若 service 只有 `mapper.updateStatus(id,"ASSIGNED")`，它既没加载聚合，也没执行状态机、版本、授权、审计或事件规则，只增加一层文件。

判断方法不是看类名含 Service，而是看它是否表达完整用例和清晰边界。

## 12. 领域对象不依赖 HTTP

聚合不能导入 `ResponseEntity`、`HttpStatus`、Jackson request DTO 或 Servlet API。否则它无法在消息、批处理和纯单元测试中独立使用。

领域拒绝使用业务异常/结果，例如 `InvalidTransition`、`VersionConflict`；Controller 再映射到稳定 HTTP 错误。

## 13. 领域对象不依赖 SQL

聚合不知道表名、列名、MyBatis 注解或受影响行数。它维护状态与不变量，Repository adapter 负责映射和乐观条件更新。

把 `@Select` 或 `@Table` 放入聚合会让持久化结构反向控制领域模型。

## 14. Repository 是应用服务的输出端口

应用服务依赖 `WorkOrderRepository` 接口，不依赖 `WorkOrderMapper`。端口提供按租户/ID加载、保存/版本更新等聚合语义。

测试可以用内存 Repository 记录调用顺序；生产装配注入 MyBatis 适配器，用例代码不变。

## 15. 加载聚合

第一步通常是 `repository.find(tenant,id)`。不存在转成用例层 `WorkOrderNotFound`，数据库不可用则保留为基础设施失败，二者不能混淆。

端口必须要求租户条件；只按裸 ID 加载会在应用层之前就破坏隔离。

## 16. 执行领域行为

应用服务把已验证或待验证的参与者信息交给 `workOrder.assign(...)`。聚合根据自身状态和 expectedVersion 决定接受或拒绝。

应用服务不预先复制聚合所有判断；它只收集完成判断所需的外部事实。

## 17. 保存结果

领域行为成功后 Repository 持久化聚合变化，SQL 用 tenant+id+expectedVersion 条件更新。0 行分类为缺失或版本冲突，由 Repository 契约处理。

服务不能忽略保存结果再宣称成功；它应把冲突转为稳定用例失败。

## 18. 编排顺序是可测试契约

对派单可记录 `load -> aggregate.assign -> save -> audit -> outbox`。若 load 失败，后续均不发生；领域拒绝时不得 save；审计失败时事务整体回滚。

顺序测试不是把实现细节全部冻结，而是保护有业务后果的依赖关系。

## 19. 事务意图放在应用服务

事务回答“哪些变化必须一起提交”。应用服务看见完整用例，因此是声明事务意图的自然位置。

Repository 只看单一持久化动作，Controller 只看协议，都不足以定义跨端口原子边界。

## 20. @Transactional 是元数据

Spring 的 `@Transactional` 描述传播、隔离、只读、超时与回滚规则；代理在外部方法调用时创建或加入事务。注解本身不会让任意对象调用自动事务化。

通常把它放在具体应用服务的公开方法，并通过 Spring Bean 引用调用；下一章详细解释代理边界。

## 21. 默认事务语义

Framework 7 文档中默认传播是 REQUIRED、隔离为 DEFAULT、读写事务、使用底层默认超时；RuntimeException 和 Error 默认触发回滚，checked Exception 默认不触发。

这些默认值是起点，不是所有业务的正确答案。checked 业务失败、超时与只读查询要显式设计。

## 22. REQUIRED 的含义

外层没有事务时 REQUIRED 创建一个物理事务；已有事务时加入它。服务 facade 调多个 Repository 时，常用这个默认让它们共享资源。

加入外层后，内层标记 rollback-only 会影响最终提交，调用者可能在边界收到 UnexpectedRollbackException。

## 23. 物理事务与逻辑范围

每个带事务语义的方法可形成逻辑范围，但 REQUIRED 常映射到同一个物理数据库事务。不能仅数注解个数推断连接或提交次数。

诊断要观察 transaction manager、资源绑定与实际 commit/rollback，而不是只看日志中的方法进入。

## 24. 回滚规则要匹配失败分类

基础设施异常通常是 RuntimeException，会默认回滚；若用例用 checked exception 表达必须回滚的业务失败，应配置 `rollbackFor` 或改用明确运行时类型。

不要为了“省事”捕获所有异常并返回 false，这会让事务代理看见正常返回而提交部分写入。

## 25. 捕获异常的风险

应用服务可捕获异常做翻译，但若事务必须回滚，就要重新抛出合适异常或显式标记 rollback-only。吞掉异常再返回成功是数据事故。

测试要注入 audit/outbox 保存失败，证明工单与所有附属记录都不存在。

## 26. checked Exception 反例

方法先保存工单，再抛一个 checked `AuditRejectedException`；若未配置回滚，默认可能提交工单。编译器要求处理异常并不等于事务会回滚。

修复依赖业务语义：让异常属于回滚体系或显式 rollbackFor，而不是把所有 Exception 无差别回滚。

## 27. 事务不能跨远程系统

Spring 本地声明式事务不会把上下文传播到 HTTP、邮件 Provider 或 Python 服务。把远程调用放进数据库事务还会长时间占连接并引入不可能的原子承诺。

FactoryCare 核心事实先在数据库内提交 outbox；通知、reporting 和 AI 在事务后消费并重试。

## 28. 核心审计与派生审计

工单状态、assignment、必要核心审计和 outbox 必须同事务。`AuditAppendPort` 是 audit 模块公开的仅追加端口，失败时核心命令整体回滚。

事件消费者只能补 Provider 回执等派生证据，不能成为核心操作审计的唯一来源。

## 29. Outbox 属于同一原子边界

应用服务调用 `OutboxPort.append(WorkOrderAssigned)`，适配器写同一 PostgreSQL 事务。事务提交后发布器再发送，传输失败不回滚已完成派单。

领域对象可产生领域事件事实，但不认识 outbox 表、JSON broker 或发布线程。

## 30. 幂等边界

来自网络重试的 command 携带幂等键。应用服务经 `IdempotencyPort` 检查主体、路由和请求摘要，重复同请求返回原结果，异请求复用键拒绝。

幂等记录与业务副作用需要可靠原子关系；Redis 临时键不能成为唯一事实。

## 31. 授权放在哪里

Controller 验证已认证，应用服务验证 actor 是否能执行这个用例及资源范围，领域聚合验证不依赖外部目录的状态规则。三者不是重复，而是不同信任边界。

权限端口返回领域可理解的授权事实，不把 SecurityContext 传入聚合。

## 32. 外部事实的收集

“技师是否启用且属于该 team”来自 organization 公开端口。应用服务查询并把受控的 AssignmentCandidate 交给聚合。

聚合不能自己发 HTTP 或跨模块查表；这样会隐藏 I/O、事务和测试边界。

## 33. 不要把所有逻辑塞进 Service

应用服务负责流程，不意味着所有规则都写成 service if。与工单状态有关的不变量属于 WorkOrder；跨聚合策略可由 domain service；协议与持久化各回到适配器。

“贫血领域 + 巨型 Service”会产生重复状态判断和无法复用的业务规则。

## 34. 也不要制造无价值层

并非每个简单只读查询都要完整聚合重建；可有明确查询用例与投影端口。关键是命名、授权和输出契约仍由应用层控制。

不要机械地为每个 Mapper 方法建立只转发的 service/repository/controller 四层。

## 35. Command Handler 与 Service 命名

`AssignWorkOrderService`、`AssignWorkOrderHandler` 或 `AssignWorkOrderUseCase` 都可，只要项目一致且职责明确。类名不替代依赖规则。

FactoryCare 教材使用 Service 表达应用层入口，端口和 adapter 包名进一步固定方向。

## 36. 构造器注入

应用服务通过构造器接收 Repository、AuditAppendPort、OutboxPort、AuthorizationPort。依赖在创建时完整、可替换，测试不需要 Spring field injection。

不要通过 service locator 或静态 ApplicationContext 隐藏依赖，它们会让调用图和测试失真。

## 37. Spring 装配位置

可用 `@Service` 标记具体应用服务，或在配置类用 `@Bean` 装配。领域对象通常由业务创建/重建，不作为全局 singleton Bean。

装配选择不改变内层接口。若追求框架纯净，可让 application 类无 stereotype，在外层配置注册。

## 38. Controller 到 Service 的异常边界

应用层抛 `WorkOrderNotFound`、`AssignmentConflict`、`ForbiddenAssignment` 等稳定失败；全局 exception handler 统一映射 ProblemDetail。

不要让 Controller 解析 SQLException message 或 MyBatis PersistenceException 决定 404/409。

## 39. 返回聚合还是 Result

直接返回可变聚合容易让适配器触发额外行为或序列化内部字段。用例 result 只暴露必要、稳定、已提交事实。

若事务尚未提交，不应先向外发布“成功”副作用；事务后事件由 outbox 保证时序。

## 40. 日志与可观察性

应用边界适合记录 useCase、traceId、tenant/actor 的脱敏标识、结果分类和耗时。不要把完整 command、附件或 SQL 参数写日志。

日志不是业务审计；可删日志不能替代同事务核心审计记录。

## 41. FactoryCare 派单顺序

可信上下文 → 幂等检查 → 权限/班组事实 → 按租户加载 WorkOrder → `assign` → 保存 assignment 与版本/transition → 核心 audit → outbox → 幂等结果。

对于 TRIAGED→ASSIGNED，状态迁移、assignment、version、审计和事件必须形成同一数据库提交。

## 42. 并发派单

两个调度员持同 expectedVersion 发起派单，都可能在内存通过领域规则，但数据库条件更新只能一个成功。失败方得到 VERSION_CONFLICT 并刷新。

应用服务不能用 JVM synchronized 代替数据库版本，因为多实例与重启会绕过进程锁。

## 43. 转派不是状态变更

FactoryCare 转派结束旧有效 assignment、创建新 assignment、version+1 并写核心审计；status 与 transition 行数不变。应用服务应调用专用 `reassign` 行为。

通用 updateStatus 无法表达这个差异，会污染唯一 12 状态机。

## 44. AI 不拥有派单决策

Python 可提供分诊建议，但 Java 应用服务验证租户、权限和业务规则；AI 不自动派单或修改 SLA。

将 AI response 直接交给 Mapper 写工单，会绕过聚合和 Java 权威边界。

## 45. 常见失败：Controller 直调 Mapper

症状是 Controller 含 `@Select` 参数、数据库 Row 或行数判断。协议层开始决定租户条件、版本和异常映射，其他入口无法复用。

修复是定义 command/result 和 use case，再把 MyBatis 收回 Repository adapter；架构测试禁止 web 包依赖 mapper 包。

## 46. 常见失败：Service 只转发 CRUD

症状是 Service 与 Mapper 方法一一对应，没有聚合行为、事务或失败契约。新增消息入口时同样的规则被复制。

用序列测试故障注入：若只有 `updateStatus` 而没有 load/assign/save，`EXPECTED_USE_CASE_ORCHESTRATION` 应直接红灯。

## 47. 常见失败：领域依赖 HTTP

症状是 WorkOrder 返回 ResponseEntity、抛 HttpClientErrorException 或读取 SecurityContext。纯领域测试需要启动 Web/Security。

依赖图应改为 adapter → application → domain；内层只使用业务类型和端口。

## 48. 常见失败：事务标在 private helper

默认代理模式只拦截通过代理进入的外部调用。同类方法直接调用带 `@Transactional` 的 helper，可能没有新事务语义。

事务入口放在清晰的公开用例方法，复杂边界拆成协作 Bean；不要依赖 self invocation 魔法。

## 49. 常见失败：事务里等待远程调用

派单事务打开后同步等待通知或 AI，会占用连接、扩大锁时间，并在超时后产生“数据库已提交还是远端已执行”的歧义。

把非原子副作用移到 outbox 消费者；必须同步的校验要设置预算并明确无法纳入本地事务。

## 50. 单元测试策略

使用 in-memory/fake ports 验证用例顺序、领域拒绝时无保存、不存在分类、返回结果和 Repository 可替换。它不证明 SQL 或事务资源。

聚合测试独立覆盖所有状态边，避免每个 service 测试重复完整矩阵。

## 51. Spring 事务集成测试

用真实 Spring 代理、transaction manager 与数据库适配器，注入 audit 写失败，断言工单、assignment、audit、outbox 全部回滚。

还要断言成功提交和外部调用未被纳入数据库原子承诺。只检查 `@Transactional` 注解存在不够。

## 52. 架构测试

检查 domain/application 包不依赖 web、MyBatis、SQL；web 只依赖 use case 输入端口；adapter 实现输出端口；Mapper 不被 Controller 引用。

简单项目可先用反射/源码路径断言，成熟项目再使用 ArchUnit 或模块测试。

## 53. 工件的替代边界

example 用可观察 fake port 证明编排与纯净边界；lab 用 Spring Framework 7 事务代理和 H2 证明 commit/rollback。两者证据互补。

H2 不证明 PostgreSQL 18 隔离、锁、错误码或执行计划；FactoryCare 生产原子性仍需 Testcontainers PostgreSQL 验证。

## 54. 红灯练习

starter 让 Service 直接调用 `updateStatus("ASSIGNED")`，没有加载聚合或执行领域行为。测试只产生一个 `EXPECTED_USE_CASE_ORCHESTRATION` 失败。

答案按 load→assign→save 重构，同一 verifier 全绿；不通过修改断言隐藏缺口。

## 55. 120 秒口述模板

先说应用服务实现一个用例并拥有事务意图，Controller 只做协议转换，聚合拥有规则，Repository 是输出端口。再按 load→behavior→save→audit/outbox 讲派单。

最后给出 Controller 直调 Mapper 或 Service 只转发 CRUD 的反例，并说明异常吞掉可能导致部分提交。

## 56. 本章边界

本章不展开 Spring AOP 实现、完整状态机、授权矩阵、MyBatis SQL、HTTP ProblemDetail、分布式事务、Saga 或生产容量。

不创建 FactoryCare 正式业务模块；配套工件只证明应用服务、依赖方向和本地事务模型。

## 57. 官方主来源

- [Spring Framework 7.0.8：Declarative Transaction Management](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative.html)
- [Spring Framework 7：Using @Transactional](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/annotations.html)
- [Spring Framework 7：Transaction Propagation](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/tx-propagation.html)
- [Spring Framework 7：Transaction Resource Synchronization](https://docs.spring.io/spring-framework/reference/data-access/transaction/tx-resource-synchronization.html)
- [Spring Boot 4.1：TransactionAutoConfiguration API](https://docs.spring.io/spring-boot/4.1/api/java/org/springframework/boot/transaction/autoconfigure/TransactionAutoConfiguration.html)
- [MyBatis-Spring：Transactions](https://mybatis.org/spring/transactions.html)
