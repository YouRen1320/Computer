---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.mybatis-repositories
title: Repository 边界与 Spring MyBatis 适配
responsibility: 教授持久化端口和 Spring MyBatis 实现的职责，不把 SQL 映射泄露到应用用例层
volume: '05'
order: 12
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.mybatis-repositories.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.datasource-pooling
- ch.data.mybatis-core
- ch.architecture.domain-modeling
version_surfaces:
- spring-boot-4.1
- spring-framework-7
- mybatis
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
  text: 在 120 秒内解释Repository 边界与 Spring MyBatis 适配的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - spring-repository-boundary
  - spring-mybatis-adapter
  covers_topics:
  - spring.repository-port
  - spring.aggregate-persistence
  - spring.not-found-contract
  - spring.mybatis-mapper-scan
  - spring.mybatis-result-boundary
  - spring.persistence-exception
  uses_capabilities:
  - backend.spring-di-config
  - data.persistence-access
  - architecture.domain-invariants
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 定义 WorkOrderRepository 端口与 MyBatis 适配器，实现按租户/ID 查询、保存和版本条件更新并映射领域对象
  covers_topic_groups:
  - spring-repository-boundary
  - spring-mybatis-adapter
  covers_topics:
  - spring.repository-port
  - spring.aggregate-persistence
  - spring.not-found-contract
  - spring.mybatis-mapper-scan
  - spring.mybatis-result-boundary
  - spring.persistence-exception
  uses_capabilities:
  - backend.spring-di-config
  - data.persistence-access
  - architecture.domain-invariants
  evidence_kind: integration-artifact-and-tests
  verification_mode: framework-or-container-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入 mapper 返回 DTO 泄露、查询漏必要条件和数据库异常穿透到领域层，使用集成测试修复
  covers_topic_groups:
  - spring-repository-boundary
  - spring-mybatis-adapter
  covers_topics:
  - spring.repository-port
  - spring.aggregate-persistence
  - spring.not-found-contract
  - spring.mybatis-mapper-scan
  - spring.mybatis-result-boundary
  - spring.persistence-exception
  uses_capabilities:
  - backend.spring-di-config
  - data.persistence-access
  - architecture.domain-invariants
  evidence_kind: integration-failure-fix-rerun
  verification_mode: integration-fault-rerun
---
# Repository 边界与 Spring MyBatis 适配

> 本章状态为 drafting。正文和工件是教材证据，不自动更新 `PROGRESS.md`，也不代表 PostgreSQL 生产环境已经验证。

Repository 不是 SQL 文件的别名，而是应用层使用的持久化端口。MyBatis Mapper 是数据库适配器内部的映射机制。把两者分开，应用用例只看“工单是否存在、保存是否成功、版本是否冲突”，不会看到表名、行 DTO、`SqlSession` 或数据库异常。

本章基线为 Spring Boot 4.1.0、Spring Framework 7、MyBatis Spring Boot Starter 4.0.0、MyBatis、PostgreSQL 18、JDK 25 与 Maven 3.9.16。官方资料复核日期为 2026-07-17。

## 1. 本章完成证据

完成者要能定义 `WorkOrderRepository`，实现租户与 ID 联合查询、保存、带版本条件更新，并把数据库行重建为领域对象。测试必须明确区分存在、不存在、并发 0 行更新，证明 SQL 只在适配器、领域层不依赖 MyBatis、事务连接由上层控制。

配套工件：

- [Repository 边界观察台](../../../examples/encyclopedia/ch.spring.mybatis-repositories/README.md)
- [MyBatis 真实适配实验](../../../labs/encyclopedia/ch.spring.mybatis-repositories/README.md)
- [修复漏租户条件练习](../../../exercises/encyclopedia/ch.spring.mybatis-repositories/README.md)

## 2. 先画依赖方向

领域模型不依赖 Repository；应用用例依赖 Repository 端口；MyBatis 适配器实现端口并依赖 Mapper；Mapper 再依赖 SQL 与 DataSource。编译依赖从外层技术指向内层策略，而不是让业务对象导入框架。

启动装配负责把实现注入端口。替换存储技术时，用例签名与领域规则不应随之改变。

## 3. Repository 是面向聚合的端口

Repository 用领域语言表达持久化需求，例如“按租户和工单 ID 查找”“保存新工单”“在期望版本下变更状态”。它不是把任意 SQL 操作逐条复制成接口。

端口粒度围绕聚合一致性边界。通用 `findByMap`、`executeSql` 或裸 `update(Object)` 会把数据库结构重新暴露给调用者。

## 4. 端口放在哪里

端口应放在应用或领域允许的内层模块，具体取决于项目分层约定；关键是它不能导入 MyBatis、Spring JDBC、表行 DTO 或数据库异常。

FactoryCare 的 `workorder` 模块拥有工单端口。其他模块通过公开用例或事件协作，不能跨模块直接查询其内部表。

## 5. 接口使用领域类型

参数使用 `TenantId`、`WorkOrderId`、`WorkOrderStatus`、`ExpectedVersion` 等有语义类型，返回 `WorkOrder`、`Optional<WorkOrder>` 或明确结果类型。

若端口接受 `Map<String,Object>`、返回 `WorkOrderRow`，调用者就必须知道列名、null 规则和存储表示，边界已经泄漏。

## 6. 为什么租户必须进入端口

租户是 FactoryCare 数据隔离条件，不是可选筛选器。`findById(id)` 无法迫使实现应用租户条件，正确端口至少是 `find(tenantId, workOrderId)`。

数据库会话中的租户上下文或 RLS 可以提供纵深防御，但不能替代接口和 SQL 中可审查的必要条件。

## 7. 查询存在与不存在

按标识查找时，不存在是预期业务分支，不等于基础设施故障。Java 端口可返回 `Optional.empty()`，或者使用项目统一的 sealed result。

不要让 MyBatis 的 `null` 穿到用例，再由每个调用者猜含义。适配器在边界统一把 null 转成端口契约。

## 8. 不存在不等于异常

`selectOne` 没有行通常返回 null；连接中断、SQL 语法错误和权限错误会抛异常。把两者都转成“没找到”会掩盖事故并产生错误的业务响应。

测试必须分别制造零行与数据库失败，断言它们走不同出口。

## 9. 保存语义要明确

`save` 可能指插入新聚合、upsert 或插入/更新二合一。模糊命名会让重复 ID、版本和审计行为不可预测。

FactoryCare 可把“新建”定义为 insert，重复键由适配器翻译为稳定的冲突结果；已有聚合的状态变更使用带版本条件的 update。

## 10. 聚合持久化不是对象序列化

领域对象包含行为、不变量和封装；数据库行包含列、null、外键与技术时间戳。二者生命周期不同，不能简单假设字段一一镜像。

适配器显式拆解聚合写入参数并从行重建领域对象。这份映射是架构边界的一部分，应有测试。

## 11. Row DTO 的职责

`WorkOrderRow` 只服务 MyBatis 结果映射，可使用可写属性、数据库友好类型和列名。它位于适配器包，不是 API DTO，也不是领域实体。

Row 可以包含 `tenantId`、`statusCode`、`version`、`createdAt` 等存储表示；适配器负责转换和校验。

## 12. Row DTO 不能越界

若 Repository 返回 Row，用例会开始读取字符串状态、修改版本字段或依赖新列。数据库重构便成为跨层破坏性改动。

架构测试可扫描领域与应用包，禁止依赖 adapter、MyBatis 注解和 Row 后缀类型。

## 13. 从行重建领域对象

映射过程解析强类型 ID、状态枚举、时间与版本，再调用受控重建工厂。重建工厂验证结构不变量，但不重复触发“创建工单”的新事件。

未知状态码、负版本或缺少非空列说明持久化数据不符合当前模型，应产生明确映射失败，不应悄悄填默认值。

## 14. 写入映射

写入时从领域对象读取稳定快照，映射为 Mapper 参数。不要把整个实体交给 MyBatis 通过反射任意取字段，否则私有结构变化会隐式改变 SQL 合约。

参数对象可以是适配器内部 command record；端口仍只见领域类型。

## 15. MyBatis Mapper 的位置

Mapper 接口位于基础设施适配器内部，声明 SQL statement 的参数和结果类型。它可以使用 `@Mapper`、`@Select`、`@Insert`、`@Update` 或 XML namespace。

Mapper 不是 Repository 端口。应用服务不应直接注入它，否则会绕过结果翻译、领域重建和异常边界。

## 16. 注解 SQL 与 XML

短而稳定的 SQL 可用注解，复杂 result map、动态查询或多行映射通常更适合 XML。二者都必须留在适配器范围。

选择是可维护性决策，不影响端口。不要把 SQL 字符串搬到应用层以追求“少一个文件”。

## 17. Mapper 扫描

MyBatis Spring Boot Starter 默认扫描带 `@Mapper` 的接口；也可在配置类使用 `@MapperScan` 指定包。只有未自定义 MapperFactoryBean 时自动扫描才按预期工作。

包路径重命名后扫描范围未更新，会出现 Bean 缺失。诊断先核对启动日志、配置类 package 与实际接口，不要盲目添加 `@Component`。

## 18. Starter 4.0.0 边界

官方兼容矩阵显示 MyBatis Spring Boot Starter 4.0 线面向 Spring Boot 4.0+ 与 Java 17+。本教材在 Boot 4.1/JDK 25 线上验证。

版本兼容必须看官方矩阵与依赖解析结果，不能仅因旧 starter 能编译就推断事务、自动配置和测试切片仍兼容。

## 19. 自动配置链

Starter 检测 DataSource，创建 `SqlSessionFactory` 与 `SqlSessionTemplate`，再扫描 Mapper 并注入模板代理。Repository 适配器依赖生成的 Mapper Bean。

因此 Mapper Bean 缺失可能源自 DataSource、factory、扫描或 statement 注册，需按链逐层定位。

## 20. SqlSessionFactory

`SqlSessionFactory` 持有 MyBatis Configuration、environment、mapped statements、type handler 与 datasource 选择。XML mapper location 或 configuration customization 在这里生效。

创建成功不证明每条 SQL 正确；statement 可在首次调用才暴露参数或数据库错误。

## 21. SqlSessionTemplate

MyBatis-Spring 的 `SqlSessionTemplate` 是线程安全、事务感知的 SqlSession 实现，可以作为 Mapper 代理背后的执行入口。它把调用关联到当前 Spring 事务。

模板管理 session 生命周期并参与异常翻译。业务代码不应缓存默认 `SqlSession` 或手工 openSession。

## 22. 不要手工 commit、rollback、close

使用 MyBatis-Spring 时，Spring 管理 SqlSession。手工调用 commit、rollback、close 会抛不支持异常或破坏上层事务所有权。

Mapper 方法只表达一次持久化动作；事务是否提交由应用用例边界决定。

## 23. 事务属于上层用例

“变更工单、写审计、写 outbox”必须在一个用例事务中提交。若每个 Repository 方法自行提交，上层无法保持原子性。

适配器参与已有事务但不创建业务事务。本章只解释所有权；声明式事务注解的完整设计属于后续章节。

## 24. 同一个 DataSource 与事务管理器

`SqlSessionFactory` 与 Spring transaction manager 必须使用同一个 DataSource，Mapper 才能复用事务绑定连接。配置出两个相似 Hikari 池会形成两个物理事务。

多数据源时显式限定 factory、template、mapper package 与 transaction manager，禁止靠 primary 猜测关键写路径。

## 25. 事务外 Mapper 调用

若 Mapper 在 Spring 事务外调用，MyBatis-Spring 会执行并按配置自动提交 session；这不是“自动有业务事务”。多个调用之间仍不原子。

测试单个 update 成功不能证明完整用例一致性，必须在应用服务测试回滚或联动失败。

## 26. 参数绑定使用 #{}

`#{value}` 使用 prepared statement 参数绑定，保留类型处理并抵抗注入。`${value}` 是字符串替换，只适合经过严格白名单的标识符等少数场景。

租户、ID、状态和版本一律作为参数绑定。任何来自请求的文本都不能直接拼进 SQL。

## 27. 参数名必须稳定

多参数 Mapper 使用 `@Param("tenantId")` 等明确名称，SQL 与接口共同形成可审查合约。依赖编译器是否保留参数名会产生环境差异。

错误名称通常在运行时报 BindingException。测试应实际调用 statement，而不是只启动上下文。

## 28. 查询必须包含必要条件

FactoryCare 的标识查询形如 `WHERE tenant_id = #{tenantId} AND id = #{id}`。顺序不是安全关键，两个条件及绑定才是。

只按 id 查可能在 ID 非全局唯一时返回其他租户数据；即使当前 UUID 看似全局唯一，也不能把概率当授权。

## 29. 更新也必须租户隔离

写 SQL 同样包含 tenant、id 与 expectedVersion。若更新只按 id，攻击者或错误调用可能修改其他租户记录。

读路径有租户条件而写路径遗漏，是常见审查盲点。测试要对 Select、Update、Delete 分别断言。

## 30. 乐观并发条件

状态更新应使用 `WHERE tenant_id=? AND id=? AND version=?`，成功时同时 `version=version+1`。受影响行数 1 表示期望版本命中。

版本比较与递增必须在同一 SQL 中完成。先 select 再无条件 update 存在检查后修改竞态。

## 31. 0 行不是一个完整含义

条件更新返回 0，可能是工单不存在、租户不匹配或版本冲突。端口若需要区分，就必须定义分类策略；不能把所有 0 都说成冲突。

最小策略是在同一上层事务内按租户/ID 再查：不存在返回 NOT_FOUND，存在返回 VERSION_CONFLICT。

## 32. 二次查询仍有竞态边界

更新 0 行后的查询可能与并发删除竞态，隔离级别会影响观察结果。若产品必须严格区分，应使用数据库能力、锁、返回子句或接受更粗契约。

本章工件定义可重复的端口分类，不声称解决所有 PostgreSQL 并发历史；真实隔离行为需在 PostgreSQL 18 测试。

## 33. 更新结果类型

可用 `UpdateOutcome.UPDATED`、`NOT_FOUND`、`VERSION_CONFLICT`，比 boolean 更可解释。boolean false 会迫使上层重新猜原因。

结果类型属于端口语言，不导入数据库行数或 MyBatis 异常。HTTP 409/404 的选择由更外层映射。

## 34. 插入结果

Mapper insert 返回受影响行数或生成键。Repository 校验预期行数；0 或大于 1 都是违反约定的异常，不应当作成功。

数据库生成 ID 与应用生成 ID 各有取舍。FactoryCare 若使用应用生成 WorkOrderId，应在进入适配器前已存在。

## 35. ResultMap 与别名

列名与 Java 属性不一致时，使用显式别名或 resultMap。`mapUnderscoreToCamelCase` 可减少样板，但不能表达枚举、嵌套对象和构造器语义。

显式映射更容易审查必填列。新增列不应自动流入领域，新增必填领域字段则必须更新重建映射和测试。

## 36. 构造器与属性映射

不可变 Row 可用 constructor mapping；JavaBean Row 可由 setter 映射。选择要与 MyBatis 当前对象工厂和参数名行为匹配。

不要为了方便让领域实体增加无参构造器和公共 setter。技术映射需求由适配器 DTO 承担。

## 37. null 的边界

SQL NULL 必须映射为端口允许的缺省语义。数据库 nullable 列与 Java primitive 不匹配时，null 可能静默变成默认 0/false，掩盖脏数据。

Row 使用 wrapper 接收 nullable，再由重建逻辑决定 Optional、拒绝还是迁移修复。

## 38. 类型处理器

UUID、JSON、枚举和自定义值可能需要 type handler。handler 属于适配器配置，不能让领域对象实现 MyBatis TypeHandler。

自定义 handler 要测试 null、非法值、读写对称和 PostgreSQL JDBC 类型；H2 的通过结果不是 PostgreSQL 扩展类型证据。

## 39. 枚举存储

使用字符串 code 比 ordinal 更耐重排，但重命名仍是数据迁移。Mapper/转换器显式维护数据库 code 与领域 enum 的关系。

遇到未知 code 应报告数据兼容错误，并携带脱敏上下文；自动映射到 UNKNOWN 只有在领域明确允许时才正确。

## 40. 时间与时区

PostgreSQL `timestamptz` 表示时间点，Java 通常映射 `Instant` 或 `OffsetDateTime`。会话时区与 JDBC 驱动转换要在真实数据库验证。

不要在 Row 到领域映射中使用系统默认时区补洞。时间语义应在 schema 和领域类型中都明确。

## 41. 数据库异常翻译

MyBatis-Spring 可通过持久化异常翻译器把 MyBatis 异常映射到 Spring DataAccessException 层次。Repository 适配器再按端口契约决定哪些异常可稳定翻译。

例如暂时不可达可转成 `RepositoryUnavailableException`；重复键若对应明确业务冲突，可转为专用结果。未知异常保留 cause 并向上失败。

## 42. 领域层不能看 DataAccessException

若领域或用例导入 DataAccessException，它便依赖 Spring 基础设施。数据库供应商、SQLState 和驱动 message 更不应成为领域分支条件。

异常翻译发生在 adapter 边界，外层日志可记录受控诊断信息，响应层不得泄露 SQL、表名或凭据。

## 43. 不要吞异常

`catch (Exception) { return Optional.empty(); }` 会把数据库宕机伪装为“工单不存在”。这会触发错误的创建、404 或补偿动作。

测试让 Mapper 抛 DataAccessResourceFailureException，并断言端口返回基础设施失败而不是 empty。

## 44. Mapper Bean 缺失诊断

症状是 Repository 构造器找不到 Mapper。依次检查 starter 是否解析、DataSource 是否存在、接口是否带 `@Mapper` 或位于 `@MapperScan`、包是否被应用扫描。

不要把接口同时标成多个 stereotype 掩盖根因。Bean 定义存在还需确认它引用正确 factory。

## 45. statement not found

`Invalid bound statement` 常见原因是 XML 未进 classpath、namespace 与接口全名不一致、方法名与 id 不一致或 mapper-locations 配错。

查看构建产物中的 XML 和 Configuration mappedStatementNames，定位注册层；修改 SQL 本身通常无助于 statement 缺失。

## 46. TooManyResults

按 ID 的 `selectOne` 返回多行，说明唯一约束、租户条件或 SQL join 有问题。不要随手加 LIMIT 1 把数据一致性问题藏起来。

Schema 应有与身份语义一致的唯一约束，测试制造两个租户同 ID，证明联合条件只返回目标行。

## 47. 结果映射失败

常见症状包括属性为 null、枚举转换异常、构造器找不到、类型 handler 缺失。先对比实际 ResultSet 列标签、JDBC 类型和 Row 定义。

只看 SQL 客户端返回值不够；MyBatis 使用列 label 和映射规则，别名拼写是可执行合约。

## 48. SQL 日志边界

开发日志可显示 statement 与耗时，但生产不得输出密码、令牌、敏感工单内容或完整参数。租户 ID 也要按数据治理要求处理。

诊断用 trace/correlation ID、statement ID、分类异常、耗时与行数，比永久开启全参数 SQL 日志更安全。

## 49. N+1 与聚合装载

逐个子项懒查询可能制造 N+1，并在事务外访问时失败。聚合装载策略应明确：join、批量查询或分步查询后在适配器组装。

不要为消除 N+1 把巨大对象图全部 eager。以用例需要和可测查询数量设计。

## 50. 跨模块查询边界

FactoryCare 工单 Repository 只能访问其拥有的表/视图。直接 join 其他模块内部表会把独立演进、权限和事务边界绑死。

跨模块读模型应通过公开 API、事件投影或明确集成契约构建，不把方便 SQL 当成架构授权。

## 51. 测试分层

纯单元测试验证 Row 到领域映射和异常分类；MyBatis 集成测试验证 statement、参数、行数与 template；真实 PostgreSQL 测试验证方言、锁、隔离和类型。

每层声明自己的证据边界。Mock Mapper 通过不能证明 XML 被加载，H2 通过不能证明 PostgreSQL 语义。

## 52. 最小集成测试矩阵

按租户/ID 查询存在返回领域对象；不存在返回 empty；同 ID 不同租户不越界；插入保存一行；正确版本更新一行并递增；旧版本返回冲突；缺失 ID 返回不存在。

再断言领域包没有 MyBatis 类型、SQL 只在 adapter、异常被翻译、上层事务能统一回滚。每项都能独立定位首个失败层。

## 53. 本章工件的数据库替代边界

配套资产使用内存数据库与真实 MyBatis-Spring 组件，稳定验证 Mapper 注册、参数绑定、Row 映射、租户条件、行数与异常边界。

它不验证 PostgreSQL 18 的并发隔离、错误码、UUID/JSON/timestamptz 或执行计划。上线前必须补真实数据库测试。

## 54. 红灯练习

starter 的查询声明接受 tenantId，却只写 `WHERE id = #{id}`。契约测试以 `EXPECTED_TENANT_PREDICATE` 唯一失败明确指出缺失条件。

答案把 `tenant_id = #{tenantId}` 与 id 联合绑定。修复后同一离线 verifier 全绿，不要求学习者改测试。

## 55. 120 秒口述模板

先说 Repository 是内层领域端口，MyBatis Mapper 是外层 SQL 机制；再说端口用领域类型、适配器用 Row DTO 并重建聚合。然后解释租户/ID、版本条件和 0 行分类。

最后说明 SqlSessionTemplate 参与上层 Spring 事务，适配器翻译异常；用“用例直接注入 Mapper 导致 DTO、SQL 和异常穿透”作为失败反例。

## 56. 完成检查表

端口没有框架类型；Mapper 只在 adapter；每条身份读写都有 tenant+id；版本更新包含 expectedVersion；0 行契约明确；Row 不越界；异常不伪装为 not found；事务由用例层拥有。

证据还要包含真实 Mapper 调用、失败注入、架构断言与可重放命令。仅凭代码审查不能宣称集成完成。

## 57. 本章边界

本章不设计 HTTP 错误映射、不实现完整声明式事务、不教授 MyBatis 动态 SQL 基础、不做分页/搜索、不决定 PostgreSQL 索引与执行计划，也不提供生产部署结论。

工件不启动 PostgreSQL 18 容器，不验证网络故障与多实例并发。本章只完成 Repository 与 Spring MyBatis 适配职责。

## 58. 官方主来源

- [MyBatis-Spring-Boot-Starter 官方文档](https://mybatis.org/spring-boot-starter/mybatis-spring-boot-autoconfigure/)
- [MyBatis-Spring：SqlSessionTemplate](https://mybatis.org/spring/sqlsession.html)
- [MyBatis-Spring：Transactions](https://mybatis.org/spring/transactions.html)
- [MyBatis 3：Mapper XML](https://mybatis.org/mybatis-3/sqlmap-xml.html)
- [Spring Framework 7：DAO Support](https://docs.spring.io/spring-framework/reference/data-access/dao.html)
- [Spring Framework 7：Transaction Resource Synchronization](https://docs.spring.io/spring-framework/reference/data-access/transaction/tx-resource-synchronization.html)
- [PostgreSQL 18 文档](https://www.postgresql.org/docs/18/)
