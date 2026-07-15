# 第 15 周：MyBatis Core 3.5 + Boot Starter 4、Flyway 与持久化垂直切片

## 定位

本周将 Week 10—11 的 HTTP/测试垂直切片与 Week 12—14 的 SQL、PostgreSQL 模型、索引和事务实验连接起来：空数据库通过 Flyway 建立 schema，MyBatis 适配器实现仓储，Spring 事务维护业务一致性，Testcontainers 验证真实组合。

这里的“MyBatis 4”准确指 **MyBatis-Spring-Boot-Starter 4.0.0 / MyBatis-Spring 4.x**；MyBatis Core 当前仍是 3.5.19。时间预算：15—18 小时。

## 前置

- Spring Boot 4.1 API、分层测试和 OpenAPI 已通过。
- PostgreSQL 18.4 schema、SQL、索引与并发实验已完成。
- Testcontainers 2 可以启动 PostgreSQL 18.4。
- 能解释事务边界、约束、乐观/悲观方案，不依赖 ORM 自动猜测。

## 目标

- 理解 DataSource、连接池、JDBC、MyBatis、Mapper、SqlSession 的高层关系。
- 使用 Boot 4 对应的 MyBatis Spring Boot Starter 4.x，并验证 Boot 4.1 组合。
- 正确使用参数绑定、结果映射、动态 SQL 和 TypeHandler 边界。
- 使用 Flyway 管理 PostgreSQL schema，保持迁移不可变、可追溯。
- 使用 Spring 事务完成创建/查询/列表工单持久化切片。
- 通过 Testcontainers 集成测试验证真实 SQL、约束、回滚和 API。
- 保持应用/领域接口稳定，使内存仓储和 MyBatis 仓储可替换。
- 通过一个隔离的MySQL 8.4 LTS对照实验，理解本地Java岗位常问的InnoDB差异，而不维护双数据库项目。

## 完整概念清单

### 版本与组件关系

- MyBatis Core 负责 SQL 映射，当前主线为 3.5.19，不存在 MyBatis Core 4。
- MyBatis-Spring 4.x 负责与 Spring Framework 7 集成。
- MyBatis-Spring-Boot-Starter 4.x 面向 Spring Boot 4.0+、Java 17+。
- Starter 自动发现 DataSource、创建 SqlSessionFactory/SqlSessionTemplate 并扫描 Mapper 的高层过程。
- Starter 4.0.0 与 Boot 4.1 的组合必须通过启动和数据库集成测试，不凭“4.x”假定完全兼容。
- 不顺带假定 MyBatis-Plus 有同等支持；本项目不引入。

### DataSource、连接池与事务资源

- JDBC Driver、DataSource、Connection、connection pool 的职责。
- 连接是有限资源；虚拟线程不会增加数据库连接上限。
- URL、用户、密码、schema、超时来自外部配置，密钥不提交仓库。
- 连接借出/归还、事务绑定和泄漏的高层概念。
- 本周使用 Boot 管理的稳定连接池默认，不做参数调优。

### MyBatis Mapper

- Mapper interface、mapped statement、parameter、result mapping。
- XML mapper 与 annotation SQL 的取舍：简单固定 SQL 可注解，复杂/动态 SQL 优先可读 XML；团队保持一致。
- `#{}` 生成绑定参数，`${}` 是文本替换，有 SQL 注入风险。
- 客户端排序字段不得直接进入 `${}`；使用白名单映射到固定 SQL 片段。
- 单参数、多参数、参数对象和明确命名。
- 自动映射与显式 `resultMap`；列名/属性名不一致时显式映射。
- constructor/record 映射需要组合验证，不因编译通过假定正确。
- enum/value object 通过显式转换或 TypeHandler；TypeHandler 只负责表示转换，不承载业务校验。
- generated keys 与应用生成 UUID 的取舍；本项目使用业务 UUID。

### 动态 SQL

- `<if>`、`<choose>`、`<where>`、`<set>`、`<foreach>` 的适用场景。
- 动态过滤条件缺失时防止意外全表 UPDATE/DELETE。
- 批量 IN 需处理空集合和参数规模。
- SQL 片段复用要可追踪，不创建难调试宏系统。
- 分页和排序稳定；limit/offset 的大页局限只记录，暂不实现 keyset 全套。
- N+1 查询识别；集合关系优先显式 join/批量查询，不用嵌套 select 隐藏成本。

### MyBatis-Spring 事务

- SqlSessionTemplate 参与 Spring 管理的事务和线程绑定。
- `@Transactional` 放应用服务公开用例边界，不放 Controller/Mapper 到处散落。
- 默认 runtime exception 回滚；checked exception 策略必须理解后明确配置。
- self-invocation、非公开方法和代理边界的高层风险。
- 一个事务维护一个业务不变量；不在事务内执行长时间外部网络调用。
- SQL 约束异常转换为稳定业务冲突，保留内部 cause 和日志。
- 条件 UPDATE 返回受影响行数，用于乐观冲突判断。

### Flyway

- schema migration 是版本化数据库代码，不靠手工点 GUI。
- Boot 4 使用对应 Flyway starter；PostgreSQL 还需数据库支持模块。
- 优先接受 Boot 4.1 BOM 管理的 Flyway 版本，不手工追独立最新版。
- versioned migration 与 repeatable migration；本项目核心 schema 使用 versioned。
- 命名如 `V1__create_core_tables.sql`，版本顺序和 checksum。
- 已在共享环境执行的 migration 不修改；修复通过新 migration。
- `validate`、`migrate`、`info`、`repair` 的用途；repair 不是跳过失败的常规按钮。
- baseline 只用于接管既有数据库的明确场景，新项目不需要。
- 不同时使用 Flyway 与 `schema.sql/data.sql` 管同一 schema。
- DDL 迁移需考虑锁、数据回填和回滚；本周只做可控小表。

### 持久化边界

- Domain model、persistence row/record、API DTO 分离。
- Repository 接口属于应用/领域需要，MyBatis mapper 属于基础设施。
- 显式 persistence mapper 处理数据库行与领域对象转换。
- 数据库约束是最后防线，Java 校验仍提供更早错误。
- 创建、按 ID 查询、筛选分页是本周完整垂直切片。
- updated_at/version 由哪一层更新必须一致，不双重猜测。

### 集成测试

- 空 PostgreSQL 18.4 容器启动后 Flyway 自动迁移。
- 测试真实 mapper SQL，不 mock Mapper 验证 SQL 正确性。
- 每个测试数据隔离：事务回滚、清理或独立 schema 的明确策略。
- 测试约束冲突、映射、时区、enum、动态条件、分页和回滚。
- Context 启动与 `/v3/api-docs` 回归同时守护第三方组合兼容性。

### MySQL 8.4 LTS求职桥接

- InnoDB是MySQL 8.4默认引擎，支持事务、行锁和MVCC；
- 聚簇主键索引与二级索引回表的高层结构；
- PostgreSQL heap table/MVCC与InnoDB实现不能用同一套口诀描述；
- `AUTO_INCREMENT`与UUID、字符集/collation、布尔/时间/JSON类型差异；
- `EXPLAIN`输出、分页、upsert和隔离默认值差异；
- 使用一个隔离容器运行三条等价SQL和一次事务/锁实验；
- 不要求FactoryCare Mapper兼容两种数据库，不引入方言判断。

## 任务分配

| 模块 | 时间 | 任务 |
| --- | ---: | --- |
| 组件/配置 | 1.5h | Starter 4.x、DataSource、SqlSession与版本兼容验证 |
| Flyway | 2h | V1/V2迁移、validate、失败修复实验 |
| MyBatis | 3h | Mapper、XML/注解、结果映射、动态SQL、TypeHandler |
| Spring 事务 | 2h | 用例边界、回滚、约束冲突和条件更新 |
| FactoryCare | 3h | PostgreSQL 仓储替换和API垂直切片 |
| 集成/无 AI | 2.5h | Testcontainers、故障定位和限时变体 |
| MySQL桥接 | 2h | MySQL 8.4小实验、差异表和面试口述 |
| 算法/求职 | 2h | 45—60分钟回溯题，以及5次定向投递/跟进 |

## FactoryCare项目增量

完成持久化垂直切片：

1. Flyway
   - `V1__create_core_tables.sql`：第 13 周核心表和约束。
   - `V2__add_work_order_indexes.sql`：只加入第 14 周有证据保留的索引。
   - 不再由手工 schema 脚本或 Hibernate 自动建表。
2. MyBatis
   - `WorkOrderPersistenceMapper`：插入、按 ID 查询、条件列表、条件更新版本。
   - `MyBatisWorkOrderRepository`：实现已有 `WorkOrderRepository`，转换 row 与 domain。
   - 设备存在/组织范围通过 SQL 与数据库约束共同保证。
3. Spring transaction
   - 创建工单在一个事务内完成必要检查和插入。
   - 制造插入后异常，验证事务回滚没有半条数据。
   - 约束冲突转换为稳定 409/422，而不是向客户端暴露 SQL。
4. API
   - 原有 POST/GET/list 契约不因持久化替换而变化。
   - 使用 Testcontainers 从 HTTP 到 PostgreSQL 验证成功和失败链路。

## AI协作边界

可以让 AI：

- 根据已确认 SQL 生成 Mapper/XML/row mapper 样板。
- 审查 `#{}`/`${}`、动态 SQL、空集合和 N+1 风险。
- 根据 Flyway 错误、SQLState 和堆栈提出排查假设。
- 生成集成测试候选，但不能用 mock 替代真实 SQL。

必须由你完成：

- 确认 MyBatis 4 指 Spring 集成/Starter 代际，不传播 Core 4 的错误说法。
- 决定事务边界、约束、冲突语义和数据库/领域映射。
- 逐条阅读 AI 生成 SQL，特别检查组织范围、WHERE、排序白名单和注入。
- 能修改一列/迁移并同步 SQL、映射、领域转换、API 测试。

## 无AI训练

本周从求职/复盘时段预留45—60分钟完成并记录：回溯基础题；说明选择、撤销、剪枝和搜索空间。

关闭 AI，限时 120 分钟：

1. 新增“按设备和状态查询工单”的 Mapper 方法。
2. 自己完成接口、XML/注解 SQL、repository adapter 和真实数据库测试。
3. 故意制造一个列名映射错误并从日志/结果定位。
4. 新增 V3 迁移为工单增加可空来源字段；不得修改已执行 V1。
5. 让应用服务插入后抛出异常，验证事务回滚。
6. 口述请求到 Controller、应用服务、事务代理、repository、mapper、连接和 PostgreSQL 的全链路。

## 求职动作（恢复求职后启用）

- 准备 JDBC/DataSource/连接池、MyBatis 与 JPA 区别、`#{}/${}`、resultMap、动态 SQL、Spring 事务、Flyway 的回答。
- 明确告诉面试官项目使用 Starter 4.x、Core 3.5.x，体现版本核验能力。
- 整理一次“从内存仓储无契约变化切换 PostgreSQL”的 5 分钟项目故事。
- 定向投递或跟进至少5个Java/Vue全栈或Java应用岗位，记录MyBatis/MyBatis-Plus/JPA出现频率。

## 交付物

- Boot 4.1 + MyBatis Spring Boot Starter 4.x 兼容性验证记录。
- 不可变的 Flyway V1/V2（以及训练 V3）迁移。
- MyBatis mapper、数据库 row 映射和 repository adapter。
- 创建/查询/列表的真实 PostgreSQL 垂直切片。
- Testcontainers 集成、约束冲突和事务回滚测试。
- PostgreSQL/MySQL差异表和MySQL 8.4隔离实验；不进入FactoryCare生产路径。
- 无 AI 持久化变体和故障排查记录。

## 验收标准

- 能准确解释 MyBatis Core、MyBatis-Spring、Boot Starter 的版本关系。
- 全新 PostgreSQL 18.4 容器可由 Flyway 自动建立 schema；二次启动无重复建表。
- 已执行 migration 不被修改，新增变化使用新版本文件。
- Mapper 全部使用安全参数绑定；任何动态排序来自固定白名单。
- API 契约保持稳定，内存和 PostgreSQL 实现可通过配置替换。
- 创建/查询/筛选分页、约束冲突、时区/enum 映射和回滚有真实数据库测试。
- 事务失败不留下部分数据；SQL 异常不直接暴露给客户端。
- `mvn verify` 从空环境通过，并守护 Boot/MyBatis/springdoc 组合启动。
- 无 AI 完成新查询、迁移、映射和回滚验证。
- 能说明InnoDB聚簇索引、MVCC/锁和PostgreSQL对应概念的主要差异，不混用执行计划术语。

## 明确不做

- 不引入 MyBatis-Plus、代码生成器、通用 BaseMapper、分页插件或二级缓存。
- 不学习 MyBatis executor/cache/代理源码，不手写连接池。
- 不混用 Flyway、schema.sql、Hibernate ddl-auto 和手工 GUI 改表。
- 不实现复杂批处理、读写分离、多数据源、分库分表或数据库路由。
- 不为FactoryCare增加PostgreSQL/MySQL双方言兼容层。
- 不在事务中调用外部 AI、邮件或长耗时 HTTP 服务。
- 不提前实现 Security、RBAC、审计或 Redis；保持本周持久化范围。

## 官方资料

- [MyBatis Core 3 Documentation](https://mybatis.org/mybatis-3/)
- [MyBatis-Spring 4 Documentation](https://mybatis.org/spring/)
- [MyBatis Spring Boot Starter 4](https://mybatis.org/spring-boot-starter/mybatis-spring-boot-autoconfigure/)
- [Spring Transaction Management](https://docs.spring.io/spring-framework/reference/data-access/transaction.html)
- [Spring Boot Data Initialization and Flyway](https://docs.spring.io/spring-boot/how-to/data-initialization.html)
- [Flyway Documentation](https://documentation.red-gate.com/flyway/)
- [Flyway PostgreSQL Support](https://documentation.red-gate.com/fd/postgresql-database-277579325.html)
- [Spring Boot Testcontainers](https://docs.spring.io/spring-boot/reference/testing/testcontainers.html)
- [MySQL 8.4 LTS与Innovation说明](https://dev.mysql.com/doc/refman/8.4/en/mysql-releases.html)
- [MySQL 8.4 InnoDB](https://dev.mysql.com/doc/refman/8.4/en/innodb-introduction.html)
