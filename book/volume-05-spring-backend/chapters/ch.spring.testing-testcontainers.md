---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.testing-testcontainers
title: Spring 测试切片、上下文测试与 Testcontainers
responsibility: 教授分层验证 Spring 装配与真实数据库适配，不用全上下文测试替代更小的单元测试
volume: '05'
order: 15
level: L2+
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.testing-testcontainers.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.mvc-routing-binding
- ch.spring.mybatis-repositories
- ch.java-engineering.testing-test-doubles
- ch.foundations.docker-basics
version_surfaces:
- spring-boot-4.1
- spring-framework-7
- testcontainers
- docker
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
  text: 在 120 秒内解释Spring 测试切片、上下文测试与 Testcontainers的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - spring-test-slices
  - spring-testcontainers
  covers_topics:
  - spring.test-slice
  - spring.context-test
  - spring.test-context-cache
  - testcontainers.database
  - testcontainers.lifecycle
  - testcontainers.integration-boundary
  uses_capabilities:
  - backend.spring-di-config
  - backend.spring-mvc-contract
  - data.persistence-access
  - java.build-testing
  - foundation.docker-runtime
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：为 Controller、Repository 和完整上下文分别写 slice/context/Testcontainers 测试，并共享一次 PostgreSQL 容器生命周期
  covers_topic_groups:
  - spring-test-slices
  - spring-testcontainers
  covers_topics:
  - spring.test-slice
  - spring.context-test
  - spring.test-context-cache
  - testcontainers.database
  - testcontainers.lifecycle
  - testcontainers.integration-boundary
  uses_capabilities:
  - backend.spring-di-config
  - backend.spring-mvc-contract
  - data.persistence-access
  - java.build-testing
  - foundation.docker-runtime
  evidence_kind: integration-artifact-and-tests
  verification_mode: framework-or-container-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入错误测试切片缺 Bean、每用例新容器变慢和测试依赖本机数据库，依据上下文/容器日志修复
  covers_topic_groups:
  - spring-test-slices
  - spring-testcontainers
  covers_topics:
  - spring.test-slice
  - spring.context-test
  - spring.test-context-cache
  - testcontainers.database
  - testcontainers.lifecycle
  - testcontainers.integration-boundary
  uses_capabilities:
  - backend.spring-di-config
  - backend.spring-mvc-contract
  - data.persistence-access
  - java.build-testing
  - foundation.docker-runtime
  evidence_kind: integration-failure-fix-rerun
  verification_mode: integration-fault-rerun
---
# Spring 测试切片、上下文测试与 Testcontainers

> 本章状态为 drafting。教材和工件是学习证据，不自动更新 `PROGRESS.md`；Docker/PostgreSQL 未实际运行时必须明确标记未验证。

测试的目标不是“启动越多越真实”，而是用最小、稳定的边界回答一个具体问题。Controller 测试回答 HTTP 映射是否正确；Repository 集成回答映射和 SQL 是否适用于真实 PostgreSQL；完整上下文回答关键 Bean 能否一起装配。三者不能互相冒充。

本章基线为 Spring Boot 4.1.0、Spring Framework 7.0.8、Testcontainers 2.0.5、Docker、PostgreSQL 18、JDK 25 与 Maven 3.9.16。官方资料复核日期为 2026-07-17；Boot 4.1.0 的依赖管理也固定 Testcontainers 2.0.5。

## 1. 本章完成证据

完成者要分别建立 Controller slice、Repository+PostgreSQL integration、完整 context smoke，并让 PostgreSQL 容器在测试类间共享一次生命周期。真实迁移和 SQL 必须执行，故意破坏列映射时集成测试要红。

配套工件：

- [三层测试职责观察台](../../../examples/encyclopedia/ch.spring.testing-testcontainers/README.md)
- [PostgreSQL 18 容器集成实验](../../../labs/encyclopedia/ch.spring.testing-testcontainers/README.md)
- [修复假集成测试练习](../../../exercises/encyclopedia/ch.spring.testing-testcontainers/README.md)

## 2. 先写测试问题

每个测试先写一句：它要证明什么、使用哪种 oracle、失败时首个可信层在哪里。没有问题的 `contextLoads()` 只能证明非常有限的启动事实。

选择测试层来自风险，不来自团队习惯或注解流行度。

## 3. 单元测试

纯单元测试直接 new 领域对象/应用服务，使用 fake/mock 端口，不启动 Spring、不连数据库。它最适合状态机、值对象、映射函数和编排分支。

它不能证明 Bean 装配、MyBatis statement、迁移、数据库约束或 PostgreSQL 方言。

## 4. Slice 测试

测试切片只装入某类基础设施所需 Bean 和自动配置，缩小上下文与失败范围。Controller slice 隔离 web mapping；JDBC/MyBatis slice 隔离持久化。

slice 不等于“半个生产系统”。被排除的安全、过滤器、服务或转换器需要明确 mock/import。

## 5. 完整上下文测试

`@SpringBootTest` 发现主配置并创建较完整 ApplicationContext，可验证自动配置、Bean 图、属性与代理共同工作。默认不一定启动真实网络服务器。

它仍不自动证明每个 HTTP 路由、每条 SQL 或生产部署；只运行 `contextLoads` 更不能覆盖行为。

## 6. 真实依赖集成

Testcontainers 启动与生产技术同类的临时服务，例如 PostgreSQL。Repository 测试面对真实协议、方言、约束、事务与驱动，而不是模拟接口。

容器是真数据库，不等于生产拓扑：数据量、TLS、网络、备份、复制和云代理仍未验证。

## 7. 测试组合而非金字塔口号

FactoryCare 用大量快速单元测试覆盖 12 状态边，少量 slice 验证适配器，关键数据库场景用 PostgreSQL 容器，少量全上下文/E2E 验证装配。

不设“每层固定百分比”；P0 租户隔离和并发风险必须有真实数据库证据。

## 8. Controller slice 的边界

Controller slice 验证 path/query/header/body 绑定、校验、状态码、JSON 与异常映射。应用用例使用 mock/fake 输入端口。

它不加载 Mapper、数据库迁移或完整安全配置，除非该 slice 明确导入相关 Bean。

## 9. Boot 4.1 的 @WebMvcTest

Boot 4.1 将 `@WebMvcTest` 放在 `spring-boot-webmvc-test` 模块/对应包表面；它聚焦 MVC Controller 并可自动配置 MockMvc。

升级时不要照抄旧 import。以 4.1 官方参考与实际依赖解析为准。

## 10. MockMvc 的职责

MockMvc 通过 DispatcherServlet 测试 MVC 请求处理，不需要真实监听端口。它能暴露路由、转换器、校验和 advice 组合问题。

standaloneSetup 更小，但不等价于 Boot slice 自动配置；两者要在证据描述中区分。

## 11. Controller 的协作者

若 Controller 构造器需要 AssignWorkOrderUseCase，slice 必须提供 mock Bean 或测试配置。缺 Bean 是切片边界事实，不应通过启动整个应用掩盖。

看到 `NoSuchBeanDefinition` 先检查 slice 过滤和显式 import，而不是随手加 `@SpringBootTest`。

## 12. Repository slice

Repository slice 应装 DataSource、transaction manager、MyBatis mapper/adapter 与必要配置，运行真实 statement。Web Controller 不应进入上下文。

Boot 的 `@JdbcTest` 适合 DataSource/JdbcTemplate；MyBatis starter 的测试支持可提供相应 slice，但要看其当前兼容矩阵。

## 13. 嵌入式数据库替换

许多 Boot data slice 默认尝试嵌入式数据库。若目标是 PostgreSQL 证据，要关闭替换或通过 service connection 提供容器连接。

H2 通过不能证明 PostgreSQL UUID、JSONB、timestamptz、锁、错误码或 SQL 方言。

## 14. Full context 的合理问题

关键用例的 Service、Repository adapter、transaction proxy、Flyway 与异常映射能否一起创建？生产 profile 缺少必要配置是否启动失败？

这些是装配问题；算法分支仍留给更小测试，避免每次等待全上下文。

## 15. WebEnvironment 选择

`MOCK` 使用 mock servlet 环境；`RANDOM_PORT` 启动真实 server 并分配端口；`NONE` 创建非 web context。选择要匹配测试问题。

仅验证 Bean 图时启动端口浪费时间；验证真实 HTTP filter/server 行为时 MockMvc 又不够。

## 16. Spring TestContext

Framework TestContext 管理测试实例依赖注入、上下文加载、事务测试与缓存。JUnit Jupiter 通过扩展与之集成。

它缓存的是 ApplicationContext，不是你的业务断言或容器数据清理。

## 17. 上下文缓存键

配置类、active profiles、property sources、context customizers 等共同影响缓存键。两个看似相同的测试若属性不同，可能创建两个上下文。

CI 日志中大量 context start 往往来自配置碎片化，而不是 Spring “随机很慢”。

## 18. @DirtiesContext

`@DirtiesContext` 把 context 标记为脏并从缓存移除，适合真的修改了 Bean/context 状态的测试。滥用会让每个测试重启上下文。

数据库数据变化通常应清理数据库，不必销毁整个 Spring context。

## 19. 测试隔离

每个测试不能依赖执行顺序、上一次遗留行或固定共享 ID。可用事务回滚、truncate、唯一 fixture ID 或重建 schema。

容器共享生命周期与数据共享是不同问题：可以共享进程，但每个测试仍独立数据。

## 20. Testcontainers 是什么

Testcontainers 是 Java 库，通过 Docker API 创建、等待、暴露并清理临时容器。JUnit 扩展可绑定测试生命周期。

它不是内存模拟器；Docker daemon、镜像、网络/缓存和足够资源都是运行前提。

## 21. Testcontainers 2.0.5 版本表面

2.0 起模块 artifact 采用 `testcontainers-*` 前缀，例如 PostgreSQL 是 `org.testcontainers:testcontainers-postgresql`；容器类迁到 `org.testcontainers.postgresql`。

JUnit 4 支持已移除。本教材用 `testcontainers-junit-jupiter:2.0.5` 与 JUnit 6/Jupiter。

## 22. PostgreSQLContainer

`new PostgreSQLContainer("postgres:18")` 创建定义；`start()` 后才有动态 JDBC URL、映射端口、用户名和密码。不能在启动前假设宿主端口 5432。

测试必须使用 `getJdbcUrl()` 等运行值，不读取本机固定 localhost 配置。

## 23. 镜像版本

至少固定 PostgreSQL 大版本 18，生产级重现最好再固定 patch 与 digest，并通过显式升级 PR 更新。`latest` 会让历史测试漂移。

镜像 tag 与 Testcontainers Java 版本是两个独立版本面。

## 24. JUnit @Testcontainers

类上 `@Testcontainers` 启用扩展，字段 `@Container` 声明生命周期。static 字段在一个测试类的方法间共享；实例字段通常每个 test 启停。

把昂贵数据库容器写成实例字段会导致每用例重启并显著变慢。

## 25. static 容器生命周期

static `@Container` 在该测试类前启动、类后停止，适合一组 repository tests。不同测试类各自 static 字段仍可能各启动一次。

“static”不自动等于整套 Maven suite 单例。

## 26. Singleton container pattern

多个测试类可继承一个基类，由 static initializer 手动 start 一个容器；进程结束由 Ryuk 清理。官方说明 JUnit extension 没有专门的 suite singleton 支持。

不要把手动 singleton 与 `@Testcontainers/@Container` 生命周期混用，否则扩展可能在第一类后停止共享容器。

## 27. 容器复用选项

开发期 experimental reuse 可减少启动，但会保留状态且 CI 不应默认依赖。测试证据必须明确是否启用。

课程工件使用 suite 内静态生命周期和显式清理，不要求全局 reuse 配置。

## 28. Ryuk 清理

Testcontainers 通常启动 Ryuk sidecar，按 label 清理测试留下的资源。禁用 Ryuk 需要有受控环境理由和替代清理。

容器泄漏会耗磁盘、端口和 CI runner；检查 `docker ps` 与 Testcontainers 日志。

## 29. 等待就绪

容器进程“running”不代表 PostgreSQL 已接受连接。数据库 container 已有默认等待策略，也可添加日志/端口/health wait strategy。

不要用固定 sleep；它在快机器浪费，在慢机器偶发失败。

## 30. 启动超时

镜像拉取、daemon 资源、架构仿真和数据库恢复都会影响启动。超时应有边界并保留容器日志，而不是无限等待。

CI 首次无镜像与本机热缓存时间不同，性能比较要注明缓存状态。

## 31. @ServiceConnection

Boot 的 `@ServiceConnection` 从 typed container 创建 ConnectionDetails，并优先于普通连接 properties。PostgreSQLContainer 可产生 JDBC/Flyway 等连接信息。

需要 test scope 的 `spring-boot-testcontainers` 模块。typed container 比 GenericContainer 更容易推断连接类型。

## 32. GenericContainer 的名字提示

Boot 无法仅从 GenericContainer Bean 返回类型判断服务；可用 `@ServiceConnection(name="...")` 提示 repository 名。

容器字段/Bean 的泛型或方法签名会影响连接详情工厂发现，诊断时检查实际类型。

## 33. @DynamicPropertySource

无法/不想使用 service connection 时，静态 `@DynamicPropertySource` 可注册容器的 JDBC URL、username/password。它更显式也更灵活。

属性 supplier 应延迟读取启动后的值；不要在容器 start 前求值。

## 34. 选择连接注入方式

Boot 原生支持的服务优先 `@ServiceConnection`，自定义端口/属性可用 DynamicPropertySource。不要同一 DataSource 同时配置两套互相覆盖而不知来源。

启动日志和 Environment property origin 是诊断依据。

## 35. 真实迁移

容器从空数据库启动，先运行与生产相同的 Flyway migrations，再调用 Repository。这样证明 schema 从零可建和 SQL 与当前版本一致。

测试手写 CREATE TABLE 只能证明测试 schema，可能掩盖迁移漏列、顺序或 checksum 问题。

## 36. 数据 seed

迁移创建结构；测试 fixture 插入场景数据。不要把测试期随机业务数据塞进生产 migration。

fixture 要显式 tenant、version、状态，失败时可读；生产敏感数据不得复制进仓库。

## 37. 真实 SQL 证据

调用真实 mapper/adapter，断言存在、不存在、租户隔离、乐观更新与数据库异常。Mock Mapper 不能发现列别名或参数条件错误。

故意把 `tenant_id` 映射成错误列，原集成测试必须在 SQL/结果映射层红。

## 38. 约束证据

重复租户业务键、null tenant、非法外键应由真实 PostgreSQL 约束拒绝。H2 的语法/约束时机可能不同。

断言错误类别/SQLState 时要锁定 pgJDBC 与 PostgreSQL 版本表面。

## 39. 事务测试的回滚误区

Spring 测试方法若默认事务回滚，可能让你误以为 service 事务正确。另写非测试事务包裹的 commit/rollback场景，从新连接观察结果。

测试框架回滚是数据清理工具，不是生产事务证据。

## 40. 数据清理策略

可在每例前 truncate、为 fixture 使用唯一 tenant、或让测试事务回滚。并发/提交后测试不能依赖外层测试事务，应显式清理。

清理脚本也要遵守外键顺序，失败不能静默忽略。

## 41. 测试依赖本机数据库的坏味道

硬编码 `jdbc:postgresql://localhost:5432/factorycare` 会依赖开发者账号、旧 schema 和残留数据，CI 空机失败。

Testcontainers 提供独立动态端口和凭据；若 Docker 不可用，应明确基础设施前置失败，而不是回退连接本机库。

## 42. “空机可运行”的准确含义

具备受支持 Docker runtime、可获得锁定镜像和 Maven 依赖的干净 runner 可以运行；完全无 Docker/镜像/网络的机器不可能凭 Java 库产生 PostgreSQL。

离线重放还要求镜像和 Maven artifacts 已预热。验证器要区分 dependency cache、image cache 与 daemon 可用性。

## 43. CI 镜像策略

CI 可预拉/缓存受信镜像，设置 registry mirror 与拉取超时；不能让测试偷偷使用长期共享数据库。

镜像供应链要扫描并固定来源，凭据不写入测试输出。

## 44. 并行测试

共享容器可并发，但共享 schema/固定 ID 会互相污染。使用独立 schema/database/tenant 或串行化有状态集。

不要用“偶尔重跑就过”接受竞态；随机端口只解决网络冲突，不解决数据冲突。

## 45. 容器日志诊断

Testcontainers 日志看 Docker discovery、image pull、create/start、wait strategy；PostgreSQL logs 看认证、启动与 SQL server 错误。

先定位是 Docker、容器 readiness、迁移、Spring context 还是 Repository statement，避免只读最终 assertion。

## 46. Docker discovery 失败

常见症状是找不到有效 Docker environment、socket 权限不足或 daemon 未启动。先用 `docker info` 验证相同用户上下文。

在受限 CI 不能随意挂宿主 socket；选择受支持 runner，不通过关闭安全隔离“修复”。

## 47. 镜像拉取失败

区分 tag 不存在、registry DNS/TLS、限流、代理和磁盘不足。离线 runner 必须提前缓存精确 image。

不要在失败时自动改为 `latest` 或替换成 H2并仍宣称 PostgreSQL 已验证。

## 48. 切片缺 Bean

`@WebMvcTest` 只发现 Controller/MVC 相关组件，应用服务要 mock/import；`@JdbcTest` 不会装 Web bean。缺 Bean 常是正确隔离反馈。

把整个 Application class import 进 slice 可能使切片退化为全上下文。

## 49. 每用例新容器变慢

实例 `@Container`、测试类碎片化或手动 start/stop 都会放大启动。先合并同一数据库边界测试并使用 static/suite lifecycle，再测量。

不能通过删除真实集成测试换速度；把高价值容器集放合适 PR/CI阶段。

## 50. 上下文缓存失效变慢

不同 `@MockBean` 集合、动态属性、profile 与 `@DirtiesContext` 会生成不同 cache key。日志统计 cache hit/miss 并统一公共配置。

容器 URL若每类不同，也会导致新的 context 和 DataSource。

## 51. FactoryCare Controller 测试

派单 Controller slice 断言认证上下文提供 tenant、body 不可覆盖；非法 expectedVersion 返回400；用例冲突映射409。用例端口为 mock。

它不重复跑 12×12 状态矩阵，也不连 PostgreSQL。

## 52. FactoryCare Repository 测试

PostgreSQL 18 容器执行真实 migration，证明 `(tenant_id,id,version)` 条件、同 ID 不同租户隔离、0行冲突和 Row→领域映射。

这里不启动浏览器，也不 mock 数据库行为。

## 53. FactoryCare full context 测试

启动关键 workorder module，注入容器 ConnectionDetails，验证 Controller→Service→MyBatis/Flyway→事务代理可装配并完成一个最小命令。

状态机排列仍由快速测试承担；full context 只选主链与关键失败。

## 54. 三层职责不重叠

Controller 层 oracle 是 HTTP；Repository 层 oracle 是 SQL/行/约束；full context oracle 是跨 Bean 装配/代理。三者有意只在最小主链交叠。

若同一状态规则在三层复制所有断言，维护成本高且失败定位差。

## 55. 红灯练习

starter 把“Repository integration”写成 mock repository，错误列映射永远不会执行。测试以 `EXPECTED_REAL_SQL_BOUNDARY` 唯一红灯要求实际 DataSource statement 被调用。

答案使用真实 JDBC adapter 与嵌入式 fixture 证明 oracle；PostgreSQL 特有结论仍只由 lab container 提供。

## 56. 120 秒口述模板

先说 unit、slice、container integration、full context 各回答不同问题；再说 static PostgreSQLContainer 动态连接、迁移、fixture、清理和上下文缓存。

最后给“mock Mapper 伪装集成”或“每例新容器”反例，并用 Docker→容器→迁移→context→SQL 的层次诊断。

## 57. 本章边界

本章不教授完整 JUnit/Mockito、Docker 安装、Compose、生产数据库运维、浏览器 E2E、性能压测或云 CI 供应链实现。

工件若 Docker daemon 或 `postgres:18` 镜像不可用，会明确报告未验证，不会用 H2 偷换 PostgreSQL 证据。

## 58. 官方主来源

- [Spring Boot 4.1：Testing Spring Boot Applications](https://docs.spring.io/spring-boot/reference/testing/spring-boot-applications.html)
- [Spring Boot 4.1：Testcontainers](https://docs.spring.io/spring-boot/reference/testing/testcontainers.html)
- [Spring Boot 4.1：Testing How-to](https://docs.spring.io/spring-boot/how-to/testing.html)
- [Spring Framework 7.0.8：TestContext Framework](https://docs.spring.io/spring-framework/reference/testing/testcontext-framework.html)
- [Testcontainers 2.0.5：JUnit Jupiter](https://java.testcontainers.org/test_framework_integration/junit_5/)
- [Testcontainers 2.0.5：Manual/Singleton Lifecycle](https://java.testcontainers.org/test_framework_integration/manual_lifecycle_control/)
- [Testcontainers 2.0.5：PostgreSQL Module](https://java.testcontainers.org/modules/databases/postgres/)
- [Testcontainers Java 2.0.5 Release](https://github.com/testcontainers/testcontainers-java/releases/tag/2.0.5)
- [PostgreSQL 18 Documentation](https://www.postgresql.org/docs/18/)
