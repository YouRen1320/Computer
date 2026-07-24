---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.datasource-pooling
title: 数据源、连接池、事务资源与迁移启动顺序
responsibility: 教授 Spring 管理数据库连接资源与启动依赖，不在本章实现 Repository 或声明式事务
volume: '05'
order: 11
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.datasource-pooling.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.boot-autoconfiguration
- ch.data.jdbc
- ch.data.schema-migrations
version_surfaces:
- spring-boot-4.1
- spring-framework-7
- jdbc
- flyway
- postgresql-18
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释数据源、连接池、事务资源与迁移启动顺序的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - spring-datasource-pool
  - spring-db-startup
  covers_topics:
  - spring.datasource-config
  - spring.connection-pool
  - spring.pool-exhaustion
  - spring.transaction-resource
  - spring.migration-startup-order
  - spring.database-readiness
  uses_capabilities:
  - backend.spring-di-config
  - data.persistence-access
  - data.schema-migration
  - data.transactions-locks
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 配置 Boot DataSource/连接池与 Flyway 启动顺序，记录池大小、借还连接、数据库 readiness 和耗尽超时
  covers_topic_groups:
  - spring-datasource-pool
  - spring-db-startup
  covers_topics:
  - spring.datasource-config
  - spring.connection-pool
  - spring.pool-exhaustion
  - spring.transaction-resource
  - spring.migration-startup-order
  - spring.database-readiness
  uses_capabilities:
  - backend.spring-di-config
  - data.persistence-access
  - data.schema-migration
  - data.transactions-locks
  evidence_kind: integration-artifact-and-tests
  verification_mode: framework-or-container-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入连接未归还导致池耗尽、应用先查表后迁移和健康检查误报，依据池指标/启动日志修复
  covers_topic_groups:
  - spring-datasource-pool
  - spring-db-startup
  covers_topics:
  - spring.datasource-config
  - spring.connection-pool
  - spring.pool-exhaustion
  - spring.transaction-resource
  - spring.migration-startup-order
  - spring.database-readiness
  uses_capabilities:
  - backend.spring-di-config
  - data.persistence-access
  - data.schema-migration
  - data.transactions-locks
  evidence_kind: integration-failure-fix-rerun
  verification_mode: integration-fault-rerun
---
# 数据源、连接池、事务资源与迁移启动顺序

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Spring Boot、Starter、自动配置与应用启动》](ch.spring.boot-autoconfiguration.md)：独立完成DataSource 与连接池、事务资源与启动前，必须先具备「Spring Boot、Starter、自动配置与应用启动」已经验证的知识与失败边界
- [《DataSource、PreparedStatement、ResultSet 与 JDBC 事务边界》](../../volume-04-data-postgresql/chapters/ch.data.jdbc.md)：独立完成DataSource 与连接池、事务资源与启动前，必须先具备「DataSource、PreparedStatement、ResultSet 与 JDBC 事务边界」已经验证的知识与失败边界
- [《Flyway、版本迁移、向前修复与数据演进》](../../volume-04-data-postgresql/chapters/ch.data.schema-migrations.md)：独立完成DataSource 与连接池、事务资源与启动前，必须先具备「Flyway、版本迁移、向前修复与数据演进」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 drafting。正文和工件是教材证据，不自动更新 `PROGRESS.md`，也不代表 PostgreSQL 生产环境已经就绪。

数据库连接是昂贵且有上限的外部资源。Spring Boot 可以配置 DataSource 并选择连接池，Spring JDBC 可以把连接绑定到事务上下文，Flyway 可以在启动阶段迁移 schema；但这些能力只有在借还、容量、顺序和健康语义明确时才组成可靠边界。

本章基线为 Spring Boot 4.1.0、Spring Framework 7.0.8、JDBC、Flyway 当前 Boot 管理线、PostgreSQL 18、JDK 25 与 Maven 3.9.16。官方资料复核日期为 2026-07-17。

## 1. 本章完成证据

完成者要能解释 DataSource、物理连接、池中代理连接与事务绑定的关系，配置有限池和明确超时，并用实验证明并发借还后 active 回零、池耗尽在上限内失败、迁移先于查询、数据库不可用时 readiness 为 false。

配套工件：

- [连接池与启动门观察台](../../../examples/encyclopedia/ch.spring.datasource-pooling/README.md)
- [耗尽、迁移与 readiness 实验](../../../labs/encyclopedia/ch.spring.datasource-pooling/README.md)
- [修复连接未归还练习](../../../exercises/encyclopedia/ch.spring.datasource-pooling/README.md)

## 2. Connection 是会耗尽的资源

JDBC Connection 代表客户端与数据库会话，可能占用服务器进程、内存、socket 和事务状态。它不是普通轻量 Java 对象。

打开后必须在所有成功与失败路径归还。长期持有连接会压缩全局容量；“查询结束”不等于连接已自动归还。

## 3. DataSource 是连接工厂接口

`javax.sql.DataSource` 提供 `getConnection()`，把调用者从 DriverManager 的全局 URL 细节中分离。它可以代表简单直连、应用服务器 JNDI 资源或连接池。

DataSource 本身不保证池化，也不自动决定事务。运行时类型、配置和调用方式共同决定行为。

## 4. Driver、URL 与 DataSource

JDBC Driver 理解特定数据库协议；JDBC URL 指定服务器、数据库和参数；DataSource 保存或接收这些配置并创建连接。

URL 正确但驱动类不在 classpath，Boot 无法创建池。驱动存在但凭据、TLS 或网络错误，DataSource Bean 可能创建，第一次连接仍失败。

## 5. Boot 自动配置条件

Boot 检测 JDBC API、可用驱动、DataSource 实现和用户是否已提供自己的 Bean，再决定是否自动配置。自定义 DataSource Bean 通常会使默认自动配置退让。

诊断时查看 condition evaluation report，而不是只问“starter 加了吗”。classpath 与 Bean 条件都是事实。

## 6. spring.datasource 外部配置

标准属性位于 `spring.datasource.*`，常用项包括 url、username、password 和 driver-class-name。多数驱动可从 URL 推断，不必重复指定类名。

池专用项放在 `spring.datasource.hikari.*` 等实现前缀。把 Hikari 属性误写到通用前缀可能被忽略且不报你期待的错误。

## 7. 凭据不是源码常量

数据库密码不应提交到 application.yml、测试快照或异常 body。生产通过受控 secret 注入，最小权限账号分别服务运行、迁移和只读需求。

日志也不要打印完整 JDBC URL 参数，因为 URL 可能包含凭据、主机拓扑或 TLS 细节。

## 8. 无 URL 时的嵌入式回退

Boot 在没有显式 URL 时会尝试发现嵌入式 H2/HSQL/Derby。开发机因为偶然依赖而启动成功，部署环境却失败，是典型 classpath 漂移。

生产配置应明确 PostgreSQL URL，并让测试明确选择替代数据库。不能把“自动找到 H2”当作 PostgreSQL 兼容证据。

## 9. Boot 4.1 的池选择

Boot 的算法优先 HikariCP；若不可用，再考虑 Tomcat pool、DBCP2、Oracle UCP。starter-jdbc 会带来 HikariCP 依赖。

这只是默认选择，不是永恒兼容承诺。使用 `spring.datasource.type` 或自定义 Bean 会改变结果，启动日志和实际 Bean 类型才是证据。

## 10. 连接池解决什么

池预先或按需建立有限物理连接。调用者借到代理，`close()` 通常把连接重置并归还，而不是立即关闭底层 socket。

它降低每次握手成本并限制并发数据库会话，但不会修复慢 SQL、长事务、死锁或容量不足。

## 11. 借用与归还

`dataSource.getConnection()` 是借用；在 try-with-resources 结束调用 close 是归还。调用者不得缓存 Connection 到字段或跨请求共享。

正确代码让异常路径也归还。手写 finally 容易漏分支，优先使用语言级资源管理。

## 12. 代理 close 的语义

池代理的 close 通知池回收，并可能回滚未提交事务、清理 warning、恢复 readOnly、isolation 和 autoCommit。实现如何重置由池负责。

归还后继续使用旧引用是编程错误。不要依赖代理对象 identity 或将其暴露到异步回调。

## 13. try-with-resources 是第一道防线

把 Connection、PreparedStatement、ResultSet 都放入嵌套 try-with-resources，关闭顺序由语言保证。即使 execute 抛 SQLException，连接仍可回池。

框架模板通常代管这些资源；混用模板与手工 close 前要理解所有权，避免重复或绕过事务绑定。

## 14. maximumPoolSize

Hikari `maximumPoolSize` 是池中总连接上限，包括 idle 和 in-use。达到上限且没有 idle 时，新借用会等待 connectionTimeout。

默认值不是生产容量结论。要结合数据库 max_connections、保留连接、应用副本数、查询时延和并发目标测量。

## 15. 每实例池与全局预算

若每个实例池 20、部署 10 个副本，理论需求可达 200，再加迁移、管理、报表和故障切换连接。数据库容量必须按总和预算。

水平扩容应用却不调整池，会把压力直接放大到 PostgreSQL。扩容计划要同时检查 connection budget。

## 16. 池不是越大越好

过多连接会增加数据库调度、内存和锁竞争，使每个查询更慢。连接池大小应从小而可测开始，不用前端并发数直接等比换算。

等待线程上升可能源于慢查询或长事务，盲目增大池会延后而非消除故障。

## 17. minimumIdle 与固定大小

Hikari 默认 minimumIdle 与 maximumPoolSize 相同，行为接近固定大小池；官方建议在许多场景不单独设置 minimumIdle。

若确需弹性池，必须测量连接建立成本、突发恢复和数据库限制。不要复制另一项目参数。

## 18. connectionTimeout

connectionTimeout 限制调用者等待池连接的最长时间。耗尽后应在有界时间抛 SQLException，而不是无限挂起请求线程。

该超时只覆盖借连接等待，不覆盖 DNS、TCP、SQL 执行或事务总时长。端到端预算要分别设计。

## 19. 池耗尽的可观察现象

active 达到 max、idle 为零、pending/waiting 增加，随后 getConnection 超时。HTTP 层可能表现为延迟尖峰和 5xx。

首个可信证据是池指标与线程堆栈，再关联慢查询和事务；仅看最终 SQLException message 难以区分泄漏与容量不足。

## 20. 连接泄漏

泄漏指借出的连接没有及时归还。随着请求累积，active 不降，最终池耗尽。

最小复现是 max=1：借出且不 close，第二次借用在 connectionTimeout 后失败。修复后同一请求序列应可重复成功且 active 回零。

## 21. leakDetectionThreshold

Hikari 可在连接借出超过阈值时记录疑似泄漏堆栈。它是诊断工具，不会替你回收正在使用的连接。

阈值过低会把合法长查询误报，过高又延迟发现。以正常事务分位数和事故需求选择，并保护日志中的 SQL/参数。

## 22. active、idle、total、pending

active 是已借出，idle 是可借，total 是物理连接总量，pending 是等待者。四者组合比单一“数据库 down”告警更有解释力。

借还测试结束应 active=0；这不要求 total=0，因为空闲物理连接仍留在池中等待复用。

## 23. idleTimeout

idleTimeout 控制超过 minimumIdle 的空闲连接何时退休。它不终止正在使用的连接，且只在配置允许缩容时有意义。

不要把它当查询超时或事务超时。名称相近不代表作用层相同。

## 24. maxLifetime

maxLifetime 限制池中物理连接寿命；Hikari 只在连接不再使用后退休。通常应略短于数据库、代理或网络基础设施的强制连接寿命。

值不匹配可能造成成批断连或陈旧连接。需要与 PostgreSQL、负载均衡和云网络设置联合验证。

## 25. keepaliveTime

keepalive 仅对 idle 连接做存活检查，并且必须小于 maxLifetime。它用于防止网络设备静默清理长期空闲连接。

它不能让数据库宕机时请求成功，也不能替代 TCP keepalive、重连策略和 readiness。

## 26. validationTimeout 与 isValid

JDBC4 驱动通常支持 `Connection.isValid`，Hikari 建议不额外设置 legacy test query。validationTimeout 要小于 connectionTimeout。

手写 `SELECT 1` 可能引入事务、权限或方言差异。除非驱动不支持，先使用标准验证。

## 27. autoCommit

Hikari 默认 autoCommit=true；事务管理器在事务边界调整连接并在归还前恢复。全局关闭 autoCommit 会改变框架外调用行为。

本章不配置声明式事务，但必须理解 pool 默认与上层 transaction manager 的所有权不能冲突。

## 28. Connection 不应跨线程共享

JDBC Connection 通常带会话和事务状态，不应由多个请求线程并发使用。Spring 的事务资源通常绑定当前执行上下文。

把连接放入 singleton 字段会破坏隔离、关闭顺序和池统计；DataSource 才是适合共享注入的线程安全入口。

## 29. Spring 事务资源绑定

`DataSourceUtils` 能获取与 Spring 当前事务关联的 Connection，并在 release 时识别线程绑定资源。JdbcTemplate 和 JDBC transaction manager 内部使用此机制。

直接调用 DataSource 获得的新连接可能绕开当前事务。使用 Spring 管理的模板/适配器可保持一致资源语义。

## 30. 同一个 DataSource

MyBatis SqlSessionFactory、JdbcTemplate 和事务管理器必须指向预期的同一 DataSource，才能共享事务连接。两个外观相似但不同的池会形成两个事务资源。

多 DataSource 项目要显式命名、qualifier 与 transaction manager，不依赖 `@Primary` 猜测关键写路径。

## 31. 事务结束与归还

在 Spring 事务中，单次 mapper 调用结束不一定立即归还连接；事务完成才 commit/rollback 并释放绑定资源。

因此 active 持续一段时间未必泄漏。结合事务时长、线程和 pending 判断，不能只用瞬时 active>0 告警。

## 32. Flyway 的角色

Flyway 按版本迁移 schema，记录历史并在不一致时失败。Boot 在 classpath 有对应模块时启动执行 `migrate()`。

PostgreSQL 需要 flyway-core 和当前数据库专用模块。版本脚本默认位于 `classpath:db/migration`。

## 33. 一个 schema 初始化机制

Boot 官方建议 Flyway/Liquibase 等高级工具与 schema.sql/data.sql 不混用。多个所有者会造成顺序、重复 DDL 与环境差异。

FactoryCare 选择 Flyway 后，生产 schema 演进只走版本迁移；测试数据可有受控的 test-only migration。

## 34. 启动依赖图

DataSource 可先创建，但查询业务表的组件必须等迁移完成。正确顺序是连接可用 → Flyway migrate → 依赖 schema 的启动查询 → readiness 接流量。

“Spring Bean 已实例化”不等于数据库结构已就绪。启动依赖要成为容器图或显式 gate。

## 35. Boot 初始化检测

Boot 能识别 Flyway、FlywayMigrationInitializer 等 initializer，并让部分 JdbcOperations 等依赖它们。第三方启动组件可能需要 detector 或 `@DependsOnDatabaseInitialization`。

不要靠 `@Order` 期待普通 Bean 初始化顺序；`@DependsOn` 语义才表达依赖。

## 36. 先查表后迁移

ApplicationRunner 或构造器若立即查询 `work_order`，却没有依赖迁移，冷启动可能报 relation does not exist。热启动因表已存在而掩盖问题。

测试要从空数据库启动并记录事件顺序，不能只在开发库反复重启。

## 37. 迁移失败应阻止接流量

checksum 冲突、权限不足或不兼容 DDL 都应让迁移失败。默认安全策略是启动失败或 readiness 保持 false。

`continue-on-error` 不是生产修复捷径。半迁移 schema 接受写流量会产生更难回滚的数据状态。

## 38. Readiness 与 liveness

liveness 回答进程是否需要重启；readiness 回答当前实例是否应接收流量。数据库暂时不可达通常使依赖数据库的实例 not ready，但不一定应该立刻重启。

错误地把数据库短故障作为 liveness failure 可能形成全体重启风暴。

## 39. DataSource 健康检查

Boot Actuator 可自动配置 DataSource health indicator，实际借连接并验证数据库。它提供数据库可达性证据，但不自动证明迁移版本和业务关键表正确。

FactoryCare readiness 应同时要求迁移 gate 完成和连接探测成功。

## 40. 健康检查误报

只返回常量 UP 会在数据库断开时继续接流量；只看 DataSource Bean 存在也没有建立连接。相反，使用长超时探测会拖慢 health endpoint。

探测要轻量、有超时、使用最小权限，并固定失败时 readiness=false。

## 41. 池耗尽时的 readiness 决策

探测也需要连接。若池被业务泄漏耗尽，health 请求可能超时，正确暴露 not ready；但它也会与业务争抢最后连接。

是否使用独立连接或专用探测需结合成本。任何设计都要防止“健康检查放大故障”。

## 42. 数据库恢复

数据库重启后，池需要淘汰坏连接并建立新连接。恢复速度受 driver、TCP、keepalive、maxLifetime 与探测配置影响。

不要假设 pool 自动恢复即等于事务可重试。失败中的业务操作仍需幂等和上层决定。

## 43. PostgreSQL 18 边界

服务端版本、JDBC driver 版本和 SQL 方言是不同表面。使用 PostgreSQL 18 不要求坐标版本也叫 18，需查 pgJDBC 兼容声明。

测试替代数据库只能证明通用 JDBC/pool 行为；扩展类型、隔离、锁、DDL 与错误码必须在真实 PostgreSQL 18 验证。

## 44. max_connections 预算

PostgreSQL `max_connections` 是服务器上限，不应全部分给应用。预留管理、迁移、监控、故障切换和其他服务连接。

池总预算必须小于可用额度，并在发布副本数变化时重新计算。

## 45. search_path 与 schema

FactoryCare core 与 ai 使用不同 schema/角色。依赖默认 search_path 容易让同名表落错 schema或查询越界。

迁移与运行账号的目标 schema 要明确；Repository SQL仍需遵守模块和租户条件，连接级 schema 不是授权替代。

## 46. TLS、时区与网络参数

生产 URL 还涉及 TLS 验证、applicationName、时区与 TCP keepalive。它们受部署环境影响，不应在教材示例中硬编码万能值。

上线前通过实际网络、证书轮换和数据库重启演练，而不是仅以本地连接成功作为证据。

## 47. 多 DataSource 与 Flyway

默认 Flyway 使用 primary DataSource。若迁移源不同，可使用 `@FlywayDataSource` 或独立 Flyway URL/user/password。

多个池意味着独立容量、健康和事务边界。配置必须说明哪个 schema、账号和 migration history 属于哪个源。

## 48. 常见配置失败

URL 拼写错、驱动缺失、密码过期、pool property 前缀错、超时单位误解、最大池乘副本超预算，都会表现为启动或运行失败。

诊断先打印脱敏后的实际属性来源和 Bean 类型，再看连接异常 cause；不要在日志中输出密码。

## 49. 常见代码失败

忘记 close、在 singleton 缓存 Connection、在事务内启动长阻塞 I/O、手动 commit Spring 管理连接、吞掉 SQLException，都会破坏资源边界。

代码审查从所有权问起：谁借、谁归还、谁定义事务结束、超时属于哪一层。

## 50. 池指标诊断表

active=max、idle=0、pending升高常指向耗尽；active低但连接失败可能是数据库/网络；active长期不降且请求结束常指向泄漏；total反复抖动需看 lifetime/网络。

指标只形成假设。结合线程栈、慢查询、事务时长与 PostgreSQL activity 验证。

## 51. 启动日志诊断表

记录 DataSource 创建、Flyway validate/migrate、schema-dependent bean、readiness 切换的顺序与耗时。relation not found 的第一证据通常在迁移前查询日志。

不要只保留最终“Application failed”摘要；嵌套 cause 和事件时间线才能定位配置、连接还是 DDL。

## 52. 实验的替代数据库边界

配套资产使用 Boot 管理的 Hikari 与嵌入式数据库来稳定重放借还、耗尽和启动 gate。SQL 只做最小表存在性，不声称等价 PostgreSQL 18。

这种替代适合快速反馈；真实 PostgreSQL 的兼容性明确列为未验证，而不是用 `MODE=PostgreSQL` 偷换概念。

## 53. 红灯练习

starter 借连接后不 close，max=1 的池 active 留在 1。测试以 `EXPECTED_CONNECTION_RETURNED` 唯一红灯证明泄漏。

答案使用 try-with-resources。修复后同一工作执行两次、active 回零且池可继续借用。

## 54. 120 秒口述模板

先说 DataSource 是连接工厂、Hikari 是有限复用池；再解释 get/close 的借还和事务资源绑定。然后给 max/timeout/active 指标。

最后说明 Flyway 必须先于业务查询，readiness 同时依赖迁移与连接，并用“连接泄漏导致池耗尽”反例收尾。

## 55. 本章边界

本章不实现 Repository、MyBatis SQL、声明式 `@Transactional`、数据库备份、复制、高可用或生产容量结论。

工件不启动 PostgreSQL 18 容器、不测试网络分区。它只证明当前章节的资源、超时、启动顺序和 readiness 模型。

## 56. 官方主来源

- [Spring Boot 4.1：SQL Databases](https://docs.spring.io/spring-boot/reference/data/sql.html)
- [Spring Boot 4.1：Database Initialization](https://docs.spring.io/spring-boot/how-to/data-initialization.html)
- [Spring Framework 7.0.8：DataSourceUtils](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/jdbc/datasource/DataSourceUtils.html)
- [Spring Framework 7：Transaction Resource Synchronization](https://docs.spring.io/spring-framework/reference/data-access/transaction/tx-resource-synchronization.html)
- [HikariCP 官方配置说明](https://github.com/brettwooldridge/HikariCP)
- [PostgreSQL 18 文档](https://www.postgresql.org/docs/18/)
