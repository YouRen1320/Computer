---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.transactions
title: "@Transactional、传播、回滚、隔离与提交后行为"
responsibility: 教授 Spring 声明式事务在真实 Repository/Service/代理边界上的语义，不扩展到分布式事务
volume: '05'
order: 16
level: L2+
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.transactions.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.service-use-cases
- ch.spring.aop-proxy-model
- ch.spring.testing-testcontainers
version_surfaces:
- spring-boot-4.1
- spring-framework-7
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
  text: 在 120 秒内解释@Transactional、传播、回滚、隔离与提交后行为的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - spring-transaction-boundary
  - spring-transaction-result
  covers_topics:
  - spring.transactional-proxy
  - spring.transaction-propagation
  - spring.transaction-self-invocation
  - spring.rollback-rule
  - spring.isolation-setting
  - spring.after-commit-behavior
  uses_capabilities:
  - backend.spring-di-config
  - data.persistence-access
  - data.transactions-locks
  - architecture.domain-invariants
  - backend.spring-persistence-tx
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 在 Service 上实现创建工单+写审计记录的 @Transactional 用例，验证 REQUIRED/REQUIRES_NEW、回滚规则和 after-commit 动作
  covers_topic_groups:
  - spring-transaction-boundary
  - spring-transaction-result
  covers_topics:
  - spring.transactional-proxy
  - spring.transaction-propagation
  - spring.transaction-self-invocation
  - spring.rollback-rule
  - spring.isolation-setting
  - spring.after-commit-behavior
  uses_capabilities:
  - backend.spring-di-config
  - data.persistence-access
  - data.transactions-locks
  - architecture.domain-invariants
  - backend.spring-persistence-tx
  evidence_kind: integration-artifact-and-tests
  verification_mode: framework-or-container-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入 self-invocation 失效、受检异常不回滚、内部新事务意外提交和提交前发消息，逐项制造失败并修复
  covers_topic_groups:
  - spring-transaction-boundary
  - spring-transaction-result
  covers_topics:
  - spring.transactional-proxy
  - spring.transaction-propagation
  - spring.transaction-self-invocation
  - spring.rollback-rule
  - spring.isolation-setting
  - spring.after-commit-behavior
  uses_capabilities:
  - backend.spring-di-config
  - data.persistence-access
  - data.transactions-locks
  - architecture.domain-invariants
  - backend.spring-persistence-tx
  evidence_kind: integration-failure-fix-rerun
  verification_mode: integration-fault-rerun
---
# @Transactional、传播、回滚、隔离与提交后行为

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《应用服务、用例编排与领域边界》](ch.spring.service-use-cases.md)：独立完成事务边界与传播、回滚与提交前，必须先具备「应用服务、用例编排与领域边界」已经验证的知识与失败边界
- [《切点、通知、代理边界与自调用陷阱》](ch.spring.aop-proxy-model.md)：独立完成事务边界与传播、回滚与提交前，必须先具备「切点、通知、代理边界与自调用陷阱」已经验证的知识与失败边界
- [《Spring 测试切片、上下文测试与 Testcontainers》](ch.spring.testing-testcontainers.md)：独立完成事务边界与传播、回滚与提交前，必须先具备「Spring 测试切片、上下文测试与 Testcontainers」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 drafting。教材和工件是学习证据，不自动更新 `PROGRESS.md`，也不代表 PostgreSQL 生产事务已验证。

事务不是“方法失败就撤销一切”的魔法。Spring 通过代理在方法边界向 transaction manager 请求事务，数据访问组件必须使用同一绑定资源；传播决定加入还是新建，异常规则决定是否回滚，提交后回调发生时数据库已不能再撤回。

本章基线为 Spring Boot 4.1.0、Spring Framework 7.0.8、MyBatis-Spring 4.0、Testcontainers 2.0.5、PostgreSQL 18、JDK 25 与 Maven 3.9.16。官方资料复核日期为 2026-07-17。

## 1. 本章完成证据

完成者要在 Service 上实现“创建工单+核心审计”事务：成功两表提交，任一步异常两表回滚；能预测 REQUIRED/REQUIRES_NEW、checked rollback、自调用和 after-commit 的可观察结果。

配套工件：

- [事务代理与提交结果观察台](../../../examples/encyclopedia/ch.spring.transactions/README.md)
- [传播、回滚与提交后实验](../../../labs/encyclopedia/ch.spring.transactions/README.md)
- [修复提交前消息练习](../../../exercises/encyclopedia/ch.spring.transactions/README.md)

## 2. 事务解决什么

本地数据库事务把多条读写形成一个提交决定：全部可见或全部不见，并按隔离规则处理并发。它不自动包含 HTTP、消息 Provider、文件系统或另一个数据库。

FactoryCare 创建工单、核心审计与 outbox 属于同一 PostgreSQL 事务；实际通知发送不属于。

## 3. ACID 是约束不是口号

Atomicity 决定同一事务写入一起提交/回滚；Consistency 依赖应用不变量与数据库约束；Isolation 约束并发可见性；Durability 表示提交后的持久承诺。

Spring 管理边界，PostgreSQL/driver 实现物理事务；代码仍要定义正确的不变量。

## 4. PlatformTransactionManager

Spring 通过 `PlatformTransactionManager` 统一 begin/commit/rollback。JDBC 常用 DataSourceTransactionManager/JdbcTransactionManager，资源绑定到当前线程。

存在多个 DataSource 时，要明确选择 manager；注解不指定可能用错资源。

## 5. 声明式与编程式

`@Transactional` 通过元数据和 AOP 代理声明边界；TransactionTemplate 在代码中显式执行 callback。两者使用同一 transaction abstraction。

应用服务常优先声明式；需要动态分段或精细测试夹具时编程式更清楚。

## 6. 代理调用链

客户端调用代理，TransactionInterceptor 读取属性、向 manager 获取事务、调用目标，然后按返回/异常提交或回滚。直接 target 调用没有这条链。

因此“方法上有注解”只是条件之一，不是运行证据。

## 7. @Transactional 放在哪里

通常放具体应用服务 public 用例方法，因为它看见完整原子意图。Repository 方法可以参与，但不应各自决定跨端口提交。

Controller 事务过宽会把序列化/远程调用纳入连接占用；领域对象又不应依赖 Spring。

## 8. Spring Bean 前提

只有通过 Spring 管理的代理引用调用才有声明式事务。`new CreateWorkOrderService(...)` 直接调用不会自动开启事务。

集成测试用 AopUtils 和 transaction active 状态证明代理存在，不能只反射注解。

## 9. public 方法边界

代理模式最清晰的支持面是可从外部调用的 public 方法。private/final/不可覆盖方法受代理类型限制。

Framework 7 虽扩展某些方法可见性支持，项目仍应选择明确可导航的 public service 边界。

## 10. self-invocation

同类 `this.inner()` 不经过代理，inner 上的 `@Transactional` 不产生新的传播语义。外部 proxy.inner() 与内部 direct inner() 结果不同。

把独立事务协作者拆成另一个 Bean，通过注入的代理调用；不要靠 AopContext 作为默认方案。

## 11. 同一个 DataSource

transaction manager、JdbcTemplate、MyBatis SqlSessionFactory 必须引用同一个 DataSource，才能共享绑定 Connection。

两个配置相同但不同实例的池仍是两个物理资源，无法组成一个本地事务。

## 12. MyBatis-Spring 参与事务

SqlSessionTemplate 从当前 Spring 事务获得 session/connection；Spring 管理 commit、rollback、close。Mapper 不能手工提交。

事务外多个 Mapper 调用不会自动组成一个业务原子单元。

## 13. 传播回答什么

Propagation 规定一个事务化方法在调用时已有事务该怎么办：加入、挂起并新建、禁止、使用 savepoint 等。

传播不是线程/远程上下文复制；默认 thread-bound 事务不会跨任意新线程或 HTTP 调用。

## 14. REQUIRED 默认

REQUIRED 在无事务时新建，有事务时加入；应用 service 调多个 repository 是常见使用。多个逻辑范围常共享一个物理事务。

内层不能独立提前提交；外层最终提交或回滚共同资源。

## 15. REQUIRED 的 rollback-only

内层 REQUIRED 捕获错误并把事务标记 rollback-only，即使外层继续正常返回，最终 commit 会发现无法提交并抛 UnexpectedRollbackException。

这是防止外层误以为成功的明确信号，不应被全局 catch 后继续返回 200。

## 16. REQUIRES_NEW

REQUIRES_NEW 总使用独立物理事务：挂起外层资源、获取新连接、独立提交/回滚。内层锁可在内层结束时释放。

它不是“更强 REQUIRED”，会改变原子边界。核心审计若 REQUIRES_NEW 提前提交而工单回滚，会留下不存在操作的审计事实。

## 17. REQUIRES_NEW 的连接成本

外层连接保持绑定，内层还要借一个连接。官方警告并发线程都持外层连接并等待内层时，池可能耗尽甚至死锁。

除非明确需要独立提交且池预算足够，不要随手用于“确保日志落库”。

## 18. NESTED

NESTED 通常在同一 JDBC 物理事务中使用 savepoint，内层可回滚到保存点而外层继续。它依赖 manager/driver 的 savepoint 支持。

它与 REQUIRES_NEW 的独立提交完全不同；PostgreSQL 最终仍由外层 commit 决定。

## 19. SUPPORTS

SUPPORTS 有事务就加入，没有就非事务执行。只读辅助查询可能使用，但调用者不同会产生不同一致性语义。

关键写操作不应用 SUPPORTS 让“有时事务、有时无事务”成为隐藏条件。

## 20. MANDATORY 与 NEVER

MANDATORY 要求调用者已开启事务，否则失败；NEVER 要求没有事务。它们可用来断言架构边界。

端口若必须在业务事务内写 outbox，可在适配层用 MANDATORY 及测试固定前置。

## 21. NOT_SUPPORTED

NOT_SUPPORTED 挂起当前事务并非事务执行，适合明确不能占用业务事务的某些操作。但挂起后的失败仍不能撤销先前数据库变化。

更常见做法是让远程副作用在事务提交后由 outbox 消费。

## 22. 默认 rollback 规则

Spring 默认在 RuntimeException 或 Error 未处理地离开代理方法时回滚；checked Exception 默认不回滚。

Java 的 checked/unchecked 分类不是业务严重度。每个用例要定义失败类型与提交语义。

## 23. rollbackFor

需要 checked 失败回滚时用 `@Transactional(rollbackFor=SpecificCheckedException.class)`。类型规则安全地匹配子类。

不要默认 `rollbackFor=Throwable` 掩盖取消、系统终止或明确无需回滚的业务结果。

## 24. noRollbackFor

某些异常代表“业务已提交但上层需要特殊响应”时可声明 noRollbackFor，但这种契约要极少且清晰。

随意不回滚会让调用者看到异常同时数据库变化已提交，必须有测试和文档。

## 25. 模式字符串规则风险

`rollbackForClassName` 按类名子串匹配，没有 wildcard，可能误匹配 `CustomExceptionV2` 或嵌套类。官方建议优先类型安全规则。

宽泛字符串 `Exception` 几乎匹配所有异常，会覆盖更精确意图。

## 26. strongest rule wins

同时存在 rollback/no-rollback 规则时，最强匹配决定结果。继承层次和 pattern 宽度会影响选择。

不要靠猜；对每类失败写 commit/rollback 集成断言。

## 27. 吞异常会提交

方法内 catch RuntimeException 后返回成功，代理只看见正常返回，默认会 commit。记录日志不等于 rollback。

需要回滚就重新抛出合适异常或显式 setRollbackOnly；优先声明式类型规则。

## 28. setRollbackOnly

`TransactionAspectSupport.currentTransactionStatus().setRollbackOnly()` 可侵入式标记回滚。它适合极少无法通过异常表达的流程。

业务对象直接调用会耦合 Spring，通常应让异常跨应用 service 边界决定。

## 29. 返回 Result 的注意

若用 sealed result 表达失败而不抛异常，transaction interceptor 默认不知道哪个 result 表示回滚。应用服务必须在返回前不做写入、显式标记或用异常穿越边界。

“不用异常”不是免费，它要求定义事务 oracle。

## 30. Future 特例

Framework 对返回时已经 exceptionally completed 的 Future 有特别回滚处理；稍后异步失败通常发生在原事务边界结束后。

不要把同步数据库事务跨异步线程，异步副作用使用明确消息/任务边界。

## 31. Isolation 是什么

隔离级别定义并发事务之间读写可见性和异常现象，不是“越高越正确”。更强隔离可能增加冲突、重试和锁等待。

业务不变量仍需唯一约束、版本条件与正确 SQL。

## 32. DEFAULT

Spring Isolation.DEFAULT 使用底层数据库默认。PostgreSQL 默认通常是 READ COMMITTED，但生产配置可能改变，需运行时确认。

写 DEFAULT 比省略更长，不增加证据；测试记录实际 isolation。

## 33. READ_COMMITTED

每条 statement 看到开始时已提交快照，同一事务重复查询可能看到其他事务后来提交的行。它阻止脏读但不等于可重复读。

FactoryCare 乐观锁依靠 version 条件，不依赖“我刚查过所以仍没变”。

## 34. REPEATABLE_READ

PostgreSQL 的 REPEATABLE READ 使用事务快照并可能在并发更新时产生 serialization failure。应用要准备整事务重试，而不是只重试最后一条 SQL。

它仍不是任意业务谓词的万能锁。

## 35. SERIALIZABLE

PostgreSQL Serializable 尝试提供可串行化效果，可能主动中止冲突事务。正确使用要求捕获特定失败并从用例边界重试。

不能 catch 后只重放部分非幂等副作用。

## 36. READ_UNCOMMITTED

PostgreSQL 把 READ UNCOMMITTED 按 READ COMMITTED 处理；不同数据库可能不同。跨数据库教材不能从枚举名字推断实现。

真实依赖测试要锁定数据库产品和版本。

## 37. isolation 声明参与现有事务

内层 REQUIRED 加入外层时通常继承外层物理事务特征，局部 isolation/timeout/readOnly 可能被忽略。可启用 validateExistingTransaction 拒绝不兼容声明。

把高隔离写在内部 helper 不保证生效。

## 38. readOnly 提示

readOnly 是事务属性/优化提示，并非所有数据库上的强制禁止写。不能把它作为安全控制。

授权和数据库权限仍要独立建立；测试当前 manager/driver 行为。

## 39. timeout

事务 timeout 限制事务总执行预算或向资源传播，不等同连接池超时、HTTP 超时或 statement timeout。

远程调用拖长事务会同时占连接和锁；优先缩短边界。

## 40. 提交阶段仍可能失败

方法体正常返回后，commit 可能因 deferred constraint、连接中断或序列化冲突失败。调用者只有代理成功返回后才能认为本地提交成功。

不要在目标方法 return 前发送“成功通知”。

## 41. TransactionSynchronization

事务活跃时可注册 synchronization，接收 beforeCommit、afterCommit、afterCompletion。回调顺序可通过 Ordered 控制。

它是低层机制；业务事件可用事务绑定事件或 outbox 表达。

## 42. beforeCommit 不是已提交

beforeCommit 发生在提交尝试前，之后仍可回滚。这里发送外部消息仍有“消息已发、数据库回滚”窗口。

它适合 flush/验证，不适合作为成功通知时点。

## 43. afterCommit

afterCommit 仅在主事务成功提交后调用，适合进程内轻量跟随动作。此时数据库已提交，回调失败不能撤销主事务。

Framework 警告资源可能仍可访问；若回调需新事务，显式 REQUIRES_NEW。

## 44. afterCompletion

afterCompletion 带 COMMITTED/ROLLED_BACK/UNKNOWN 状态，无论结果都调用，适合清理与指标。

不要在 UNKNOWN 时假设成功，也不要把清理异常覆盖主要失败。

## 45. @TransactionalEventListener

事务绑定 listener 可选择 BEFORE_COMMIT、AFTER_COMMIT、AFTER_ROLLBACK、AFTER_COMPLETION；默认 AFTER_COMMIT。无事务事件默认不执行，除非 fallbackExecution。

它仍是进程内回调，不提供崩溃后可靠重放。

## 46. 提交后直接发消息的窗口

afterCommit 避免回滚前发送，但进程可能在 commit 后、发送前崩溃；发送成功、记录失败也会重复。对可靠跨系统事件仍使用事务 outbox。

afterCommit 可唤醒本地 publisher，可靠事实是已提交 outbox 行。

## 47. 外部副作用

邮件、短信、Python AI、对象存储与 broker 不参与单库事务。不要因调用写在 `@Transactional` 方法里就宣称原子。

设计可重试、幂等、补偿与可观察状态，而不是伪装分布式事务。

## 48. FactoryCare 创建工单事务

Service 验证命令后写 work_order、必要 transition、AuditAppendPort 与 OutboxPort；任何一项数据库写失败，全部回滚。

通知 Provider、reporting 读模型和 AI 分诊/草稿在提交后异步处理。

## 49. 核心审计不能 REQUIRES_NEW

若 audit 独立提交后主工单失败，会留下“已创建工单”的核心审计但工单不存在。FactoryCare 核心审计必须加入 REQUIRED 主事务。

Provider 回执等派生审计可在异步消费者独立记录，但不能替代核心证据。

## 50. Outbox 不是直接 publish

OutboxPort 在业务事务内插入事件行；publisher 在提交后扫描并发送，消费者幂等。它解决 commit/send 崩溃窗口，不承诺 Exactly Once。

事务 service 不等待 broker ACK 或 Python 处理。

## 51. 传播测试矩阵

外层 REQUIRED + 内层 REQUIRED：共同回滚；外层 REQUIRED + 外部 Bean REQUIRES_NEW：内层可独立提交；同类自调用 REQUIRES_NEW：不会新建。

再覆盖 inner rollback-only 导致 UnexpectedRollback、池连接预算与 NESTED savepoint 支持。

## 52. 回滚测试矩阵

RuntimeException 默认两表回滚；checked 默认提交；checked+rollbackFor 两表回滚；catch/swallow 默认提交；noRollbackFor 明确提交。

测试从新连接观察数据库，避免测试方法自身事务掩盖真实结果。

## 53. after-commit 测试矩阵

成功 commit 后 action 恰好发生一次；rollback 时 action 零次；beforeCommit 不得触发外部 action；afterCommit action失败不能改写数据库已提交事实。

若需要可靠发送，断言 outbox 行而不是 mock publisher 立即调用。

## 54. self-invocation 诊断

外部调用 private/newTx 方法有效还是无效？先确认 bean 是否代理、调用引用、method visibility、proxy type 与 advisor。开启 transaction debug 日志观察 begin/suspend/resume。

最小复现同时比较 proxy.inner() 与 target.outer→this.inner()。

## 55. checked 异常不回滚诊断

日志显示方法抛出 checked，但 SQL 已提交，先查注解 rollbackFor 与异常是否穿出代理。不要怪数据库“没有事务”。

练习应在修复前保留提交事实，修复后原测试变为回滚。

## 56. 意外独立提交诊断

主事务回滚但 audit 行存在，检查是否由另一个 Bean 的 REQUIRES_NEW 提交、是否多 DataSource/manager，或调用发生在 afterCommit。

先画物理事务/连接时间线，再改传播。

## 57. 提交前发消息诊断

测试注入后续数据库失败，却观察 publisher 已收到消息，说明发送发生在 commit 前。把可靠事件改为同事务 outbox；publisher 只处理已提交行。

仅换成 afterCommit 仍需记录崩溃窗口边界。

## 58. 真实数据库证据

H2 可稳定验证 Spring proxy/rollback 基础，但 PostgreSQL isolation、savepoint、constraint、SQLState 与锁必须在 PostgreSQL 18 Testcontainers 重放。

测试环境 Docker 不可用时明确标记，而不是静默把 H2 结果升级为 PostgreSQL 结论。

## 59. 红灯练习

starter 在事务方法中先调用外部 publisher，再写审计失败；消息已发送而数据库回滚。`EXPECTED_AFTER_COMMIT_ONLY` 唯一红灯定位时序。

答案注册 afterCommit callback；同一 verifier 证明成功后一次、回滚后零次。可靠生产事件仍使用 outbox。

## 60. 120 秒口述模板

先说事务代理、manager、同一 DataSource；再比较 REQUIRED 加入和 REQUIRES_NEW 独立连接/提交。说明 runtime 默认回滚、checked 默认不回滚、isolation 属于数据库并发。

最后说 self-invocation 绕代理，beforeCommit 不是提交，afterCommit 不可回滚且不可靠重放，所以 FactoryCare 用同库 outbox。

## 61. 本章边界

本章不实现分布式事务、XA、Saga、消息 Exactly Once、生产重试框架、锁/死锁全课程或多数据库一致性。

工件聚焦 Spring 本地 JDBC 事务代理、传播、回滚和提交后时序。

## 62. 官方主来源

- [Spring Framework 7.0.8：Transaction Management](https://docs.spring.io/spring-framework/reference/data-access/transaction.html)
- [Spring Framework 7.0.8：Declarative Transaction Management](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative.html)
- [Spring Framework 7：Using @Transactional](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/annotations.html)
- [Spring Framework 7：Transaction Propagation](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/tx-propagation.html)
- [Spring Framework 7：Rolling Back](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/rolling-back.html)
- [Spring Framework 7.0.8：TransactionSynchronization](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/transaction/support/TransactionSynchronization.html)
- [Spring Framework 7：Transaction-bound Events](https://docs.spring.io/spring-framework/reference/data-access/transaction/event.html)
- [MyBatis-Spring：Transactions](https://mybatis.org/spring/transactions.html)
- [PostgreSQL 18：Transaction Isolation](https://www.postgresql.org/docs/18/transaction-iso.html)
