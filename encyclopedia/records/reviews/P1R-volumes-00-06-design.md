# P1R 卷 00—06 零基础目录重构设计

## 1. 目标、范围与决策

- 审查依据：当前 curriculum/catalog.yml 与 P1-semantic-prerequisite-audit.md。
- 范围：卷 00—06 的目录、硬前置、教学角色、旧 ID 迁移与治理规则。
- 目标：让真正零基础读者严格按顺序学习时，不会被要求独立使用尚未教授的语法、测试方法、数据结构、框架或运行模型。
- 非目标：本设计不写正文、不修改路线/门禁/进度、不验证软件版本，也不授予任何学习完成状态。

采用语义稳定 ID：ch.<domain>.<slug>。volume、order、path 与 ID 解耦；不保留 legacy alias 或运行时 redirect，只保存审计用迁移账本。

未采用的方案：

1. 继续使用 vXX.cNN.slug 并在中间插号：迁移成本较低，但后续插章会再次全量重编号，长期维护风险最高。
2. 使用 UUID：顺序稳定，但人工审阅、引用和故障诊断成本过高。
3. 采用 ch.<domain>.<slug>：本次破坏性迁移成本较高，但当前 170 章均为 planned，回滚只需恢复 P1 目录；长期维护性最好，因此推荐。

教学角色：

- F：first-teach，首次教授。
- L：language-practice，语言实现或练习。
- P：framework/platform-practice，框架或平台实践。
- D：production-deepening，生产深化。

前置引用约定：目录表为便于阅读，通常省略 ch.<domain>. 前缀；无前缀的 kebab-case 名称必须唯一解析为本设计中同尾段的完整 ID。以下别名在实施时必须展开为精确 ID，不能把别名写入 catalog：

- Maven = ch.java-engineering.maven-reproducible-builds；Maven smoke = ch.java.maven-junit-smoke。
- exceptions = ch.java-oop.exceptions-failure-contracts；interfaces = ch.java-oop.interfaces-polymorphism。
- HTTP = ch.foundations.http-curl；API basics = ch.foundations.api-contract-basics。
- SELECT = ch.data.select-rowsets；DML = ch.data.dml；database-transactions 或 DB transaction = ch.data.transactions-locking。
- IoC = ch.spring.ioc-di；beans = ch.spring.beans-lifecycle-scopes；configuration = ch.spring.configuration-profiles；Boot = ch.spring.boot-autoconfiguration。
- MVC = ch.spring.mvc-routing-binding；DTO = ch.spring.dto-json-content-negotiation；Problem Details = ch.spring.problem-details-errors。
- datasource = ch.spring.datasource-pooling；repositories 或 Spring repositories = ch.spring.mybatis-repositories；service = ch.spring.service-use-cases；AOP = ch.spring.aop-proxy-model。
- Spring testing = ch.spring.testing-testcontainers；Spring transactions = ch.spring.transactions；Java testing = ch.java-engineering.testing-test-doubles；Java logging = ch.java-engineering.logging-jvm-diagnostics。
- threat-model = ch.security.threat-model-trust-boundaries；identity = ch.security.identity-password-lifecycle；session-model = ch.security.cookie-session-model。
- origin/CSRF = ch.security.origin-cors-csrf；untrusted-input = ch.security.untrusted-input-xss-ssrf；security-architecture = ch.security.spring-security-architecture。
- authorization = ch.security.authorization-rbac-abac；multitenancy = ch.security.multitenancy-data-isolation；audit-events = ch.security.audit-events-privacy。
- idempotency = ch.architecture.idempotency-concurrency；outbox = ch.architecture.domain-events-outbox；Actuator = ch.spring.actuator-health-metrics。
- “Spring validation/errors”表示 ch.spring.validation 与 ch.spring.problem-details-errors 两条边；“DB/Spring transactions”表示 ch.data.transactions-locking 与 ch.spring.transactions 两条边。

## 2. 规模

| 卷 | 当前 | 建议 | 增量 |
|---|---:|---:|---:|
| 00 计算机基础 | 12 | 15 | +3 |
| 01 Java 语言 | 10 | 11 | +1 |
| 02 Java 对象 | 10 | 12 | +2 |
| 03 Java 工程 | 13 | 18 | +5 |
| 04 数据与 PostgreSQL | 11 | 17 | +6 |
| 05 Spring 后端 | 10 | 18 | +8 |
| 06 安全与企业架构 | 10 | 19 | +9 |
| 合计 | 76 | 110 | +34 |

完成本批迁移后，全书会先由 170 章增至 204 章；卷 07—15 后续再根据同一语义审计扩充，使全书最终落在 230—260 章。

## 3. 卷 00：计算机、工具与验证基础（15 章）

| 顺序 | ID | 角色 | 标题 | 关键硬前置 |
|---:|---|---|---|---|
| 1 | ch.foundations.learning-evidence | F | 学习证据、掌握标准与间隔复习 | 无 |
| 2 | ch.foundations.files-paths-encoding | F | 文件、路径、字符与编码 | 无；独立 outcome 不要求命令读写 |
| 3 | ch.foundations.terminal-shell | F | 终端、Shell、命令与引用规则 | files-paths-encoding |
| 4 | ch.foundations.computer-process-model | F | CPU、内存、磁盘、程序与进程 | terminal-shell |
| 5 | ch.foundations.cli-streams-exit-codes | F | stdin、stdout、stderr、管道与退出码 | terminal-shell、computer-process-model |
| 6 | ch.foundations.environment-tool-resolution | F | 环境变量、PATH 与工具版本解析 | terminal-shell |
| 7 | ch.foundations.editor-project-navigation | F | 编辑器、IDE、项目导航与源码定位 | files-paths-encoding；不要求断点调试 |
| 8 | ch.foundations.git-collaboration-security | F | Git 状态模型、远程协作、冲突与凭据处置 | files-paths-encoding、terminal-shell |
| 9 | ch.foundations.network-layers | F | IP、DNS、端口、TCP 与 TLS 分层 | terminal-shell、computer-process-model |
| 10 | ch.foundations.http-curl | F | HTTP 报文、方法、状态码、Header、Body 与 curl | cli-streams-exit-codes、network-layers |
| 11 | ch.foundations.api-contract-basics | F | API 资源、错误、版本、分页、缓存与幂等语义 | http-curl |
| 12 | ch.foundations.testing-oracles | F | 预期值、测试预言、断言、AAA 与测试层级 | cli-streams-exit-codes |
| 13 | ch.foundations.dependencies-build-packages | F | 依赖、包管理、构建生命周期与可重复性 | environment-tool-resolution、testing-oracles |
| 14 | ch.foundations.docker-basics | P | 镜像、容器、卷、端口与容器网络 | files-paths-encoding、terminal-shell、network-layers；构建工具只作推荐前置 |
| 15 | ch.foundations.ai-assisted-verification | D | AI 协作、隐私、补丁审查与可证伪验证 | git-collaboration-security、testing-oracles、dependencies-build-packages |

整改结果：

- 进程诊断移到终端之后。
- IDE 章只教导航；断点、步入、调用栈移到 Java 调试章。
- 网络分层与 HTTP/curl 拆开，http 能力有真实首次教授来源。
- AI 补丁验证前先教授测试预言、断言和测试层级。
- Docker 基础不再硬依赖完整构建工具。

## 4. 卷 01：Java 语言基础（11 章）

| 顺序 | ID | 角色 | 标题 | 关键硬前置 |
|---:|---|---|---|---|
| 1 | ch.java.platform-toolchain | F | JDK、JVM、源码、class 文件、编译与运行 | terminal-shell、environment-tool-resolution |
| 2 | ch.java.program-structure | F | 注释、标识符、字面量、语句、代码块、class、main 与 package | platform-toolchain |
| 3 | ch.java.values-variables-types | F | 值、变量、基本类型、String、作用域与基本输出 | program-structure |
| 4 | ch.java.expressions-conversions | F | 运算符、表达式、类型转换、溢出与整数分金额 | values-variables-types |
| 5 | ch.java.branching | F | 布尔逻辑、if/else 与 switch | expressions-conversions |
| 6 | ch.java.loops | F | for、while、计数、累积与哨兵循环 | branching |
| 7 | ch.java.arrays-command-args | F | 数组、二维数组、查找与命令行参数 | values-variables-types、loops |
| 8 | ch.java.methods | F | 方法、参数传递、返回值、重载与递归边界 | branching、loops、arrays-command-args |
| 9 | ch.java.console-input-validation | L | 控制台输入、缺参数、EOF、合法性校验与退出码 | methods、branching、loops、arrays-command-args、cli-streams-exit-codes |
| 10 | ch.java.maven-junit-smoke | P | Maven 最小项目、JUnit、断言与失败日志 | methods、testing-oracles、dependencies-build-packages |
| 11 | ch.java.debugging-failures | L | 编译错误、运行异常、断言失败、逻辑错误与断点调试 | editor-project-navigation、branching、methods、maven-junit-smoke |

特殊合同：

- platform-toolchain 中的 public static void main(String[] args) 是 borrowed_scaffold，只验证源码到 JVM 的运行链。
- program-structure 不再要求跨包调用；访问控制后移到封装章。
- Scanner 构造与 JUnit 注解同样登记为暂借样板，outcome 不提前考察对象模型或注解实现。
- 控制台输入严格位于变量、条件、循环、数组和方法之后。
- 调试与 JUnit 必须有真实 outcome，不再只出现在标题。

## 5. 卷 02：Java 对象模型（12 章）

| 顺序 | ID | 角色 | 标题 | 关键硬前置 |
|---:|---|---|---|---|
| 1 | ch.java-oop.references-null-identity | F | 引用、对象身份、null 与内存心智模型 | values-variables-types、methods |
| 2 | ch.java-oop.classes-objects | F | 类、实例、字段与实例方法 | references-null-identity |
| 3 | ch.java-oop.constructors-invariants | F | 构造器、初始化顺序与对象不变量 | classes-objects |
| 4 | ch.java-oop.encapsulation-packages | F | 封装、访问控制与包边界 | constructors-invariants、program-structure |
| 5 | ch.java-oop.static-class-state | F | static、类成员与共享状态 | classes-objects、encapsulation-packages |
| 6 | ch.java-oop.final-immutability | F | final、常量与不可变对象 | constructors-invariants、encapsulation-packages |
| 7 | ch.java-oop.inheritance-composition | F | 继承、重写、super、组合与复用选择 | classes-objects、encapsulation-packages |
| 8 | ch.java-oop.interfaces-polymorphism | F | 接口、抽象类、多态与动态分派 | inheritance-composition |
| 9 | ch.java-oop.enum-record-sealed | F | enum、record、sealed 与受限类型建模 | final-immutability、interfaces-polymorphism、branching |
| 10 | ch.java-oop.object-contracts | F | equals、hashCode 与 toString 直接契约 | classes-objects、final-immutability |
| 11 | ch.java-oop.business-value-types | L | 正则、BigDecimal、日期时间、UUID 与业务值 | values-variables-types、expressions-conversions、final-immutability |
| 12 | ch.java-oop.exceptions-failure-contracts | F | 异常分类、传播、捕获、转换与失败契约 | methods、interfaces-polymorphism |

整改结果：

- 不可变章不再提前使用集合防御性复制。
- Object 契约只直接验证 equals/hashCode；Set/Map 行为后移。
- 资源关闭移到有具体 IO 类型的章节。
- BigDecimal 与时间 API 必须进入 outcome。

## 6. 卷 03：Java 工程能力（18 章）

| 顺序 | ID | 角色 | 标题 | 关键硬前置 |
|---:|---|---|---|---|
| 1 | ch.java-engineering.maven-reproducible-builds | D | Maven 生命周期、依赖范围、插件与可重复构建 | maven-junit-smoke、dependencies-build-packages |
| 2 | ch.java-engineering.generics-type-safety | F | 泛型、类型参数、边界与通配符 | interfaces-polymorphism、methods |
| 3 | ch.java-engineering.sequential-collections | F | List、Queue、Deque 与迭代 | generics-type-safety、arrays-command-args |
| 4 | ch.java-engineering.associative-collections | F | Set、Map、键相等性与哈希契约 | generics-type-safety、object-contracts |
| 5 | ch.java-engineering.sorting-comparators | F | Comparable、Comparator 与稳定排序 | sequential-collections、generics-type-safety |
| 6 | ch.java-engineering.complexity-algorithms | F | 复杂度、搜索、排序与基础数据结构选择 | sequential-collections、associative-collections、sorting-comparators |
| 7 | ch.java-engineering.lambdas-functional-interfaces | F | Lambda、函数式接口与方法引用 | interfaces-polymorphism、methods |
| 8 | ch.java-engineering.functional-pipelines | L | Stream、Collector 与 Optional 边界 | sequential-collections、associative-collections、lambdas-functional-interfaces |
| 9 | ch.java-engineering.io-resource-lifecycle | F | 字节流、字符流、资源所有权与 try-with-resources | exceptions-failure-contracts、files-paths-encoding |
| 10 | ch.java-engineering.nio-files-charsets | L | Path、Files、缓冲、字符集与原子文件操作 | io-resource-lifecycle、files-paths-encoding |
| 11 | ch.java-engineering.json-mapping | P | JSON 数据边界、对象映射与未知字段处理 | nio-files-charsets、enum-record-sealed、exceptions、Maven |
| 12 | ch.java-engineering.threads-jmm | F | 线程、Java 内存模型、同步与锁 | static-class-state、final-immutability、exceptions |
| 13 | ch.java-engineering.executors-virtual-threads | L | Executor、Future、取消与虚拟线程 | threads-jmm |
| 14 | ch.java-engineering.annotations-metadata | F | 注解声明、目标、保留策略与元数据 | program-structure、classes-objects |
| 15 | ch.java-engineering.reflection-classloading-proxies | L | 反射、类加载边界与动态代理 | annotations-metadata、interfaces-polymorphism、exceptions |
| 16 | ch.java-engineering.network-programming | L | Socket、Datagram、URL/HttpClient 与超时 | network-layers、http-curl、io-resource-lifecycle、exceptions |
| 17 | ch.java-engineering.testing-test-doubles | D | JUnit 参数化、测试设计、测试替身与 Mockito | Maven、maven-junit-smoke、interfaces、exceptions |
| 18 | ch.java-engineering.logging-jvm-diagnostics | D | 结构化日志、线程转储、JFR 与 JVM 故障诊断 | Maven、threads-jmm、exceptions |

关键顺序：

- 泛型先于所有正式泛型集合。
- Set/Map 依赖 Object 契约。
- 异常先于 IO，具体 IO 与资源所有权同章验证。
- JSON 有独立 outcome。
- 注解与反射/代理拆开。
- JUnit 基础、Java 测试深化、Spring 测试形成三层。

## 7. 卷 04：关系数据、SQL 与持久化基础（17 章）

| 顺序 | ID | 角色 | 标题 | 关键硬前置 |
|---:|---|---|---|---|
| 1 | ch.data.relational-model | F | 数据库、schema、表、行、键与关系模型 | 无；只观察预建 schema |
| 2 | ch.data.postgresql-psql | P | PostgreSQL 服务、连接、psql 与脚本执行 | relational-model、terminal-shell；Docker 仅为实验前置 |
| 3 | ch.data.select-rowsets | F | SELECT、投影、过滤、NULL、排序与分页 | relational-model、postgresql-psql |
| 4 | ch.data.scalar-functions | F | 数值、文本、日期函数与 CASE | select-rowsets |
| 5 | ch.data.aggregates | F | 聚合、GROUP BY 与 HAVING | select-rowsets |
| 6 | ch.data.joins | F | INNER/OUTER JOIN、关系基数与重复行 | relational-model、select-rowsets |
| 7 | ch.data.subqueries-cte | F | 子查询、CTE 与集合拆解 | select-rowsets、aggregates |
| 8 | ch.data.window-functions | F | 窗口、分区、排序与分析函数 | aggregates、joins、subqueries-cte |
| 9 | ch.data.dml | F | INSERT、UPDATE、DELETE、UPSERT 与 RETURNING | relational-model、select-rowsets |
| 10 | ch.data.ddl-constraints | F | CREATE/ALTER、主外键、唯一、检查与非空约束 | relational-model、postgresql-psql |
| 11 | ch.data.normalization-modeling | F | 函数依赖、规范化与关系模式设计 | ddl-constraints |
| 12 | ch.data.postgresql-types | P | UUID、JSONB、数组与 PostgreSQL 类型选择 | ddl-constraints |
| 13 | ch.data.indexes-explain | D | 索引、查询计划、EXPLAIN 与性能证据 | select-rowsets、ddl-constraints |
| 14 | ch.data.transactions-locking | F | ACID、隔离级别、锁、死锁与重试边界 | dml、ddl-constraints |
| 15 | ch.data.schema-migrations | D | Flyway、版本迁移、向前修复与数据演进 | ddl-constraints、transactions-locking、dependencies-build-packages |
| 16 | ch.data.jdbc | P | DataSource、PreparedStatement、ResultSet 与 JDBC 事务边界 | Maven、exceptions、SELECT、DML、transactions；不硬依赖迁移 |
| 17 | ch.data.mybatis-core | P | MyBatis 映射、参数绑定、结果映射与动态 SQL | jdbc、generics、SELECT、DML |

整改结果：

- 关系模型章只观察预建 schema，不修复未来才教授的约束。
- JOIN、子查询/CTE、窗口函数拆开。
- DML、DDL、规范化拆开。
- 窗口函数有聚合、Join、CTE 的真实祖先。
- Flyway、JDBC、MyBatis 是三个独立层次。
- JDBC 概念不硬依赖完整迁移章。

## 8. 卷 05：Spring Web、数据与事务（18 章）

| 顺序 | ID | 角色 | 标题 | 关键硬前置 |
|---:|---|---|---|---|
| 1 | ch.spring.servlet-request-lifecycle | P | HTTP 请求生命周期、Servlet 与线程边界 | http-curl、api-contract-basics、Maven |
| 2 | ch.spring.ioc-di | P | IoC、构造器注入与依赖反转 | constructors-invariants、interfaces-polymorphism；反射仅推荐 |
| 3 | ch.spring.beans-lifecycle-scopes | P | Bean 注册、生命周期、作用域与销毁 | ioc-di |
| 4 | ch.spring.configuration-profiles | P | 配置属性、Profile、环境覆盖与敏感配置 | beans、environment-tool-resolution |
| 5 | ch.spring.boot-autoconfiguration | P | Spring Boot、Starter、自动配置与应用启动 | IoC、beans、configuration、Maven |
| 6 | ch.spring.mvc-routing-binding | P | Controller、路由、参数绑定与状态码 | servlet、boot、api-contract-basics |
| 7 | ch.spring.dto-json-content-negotiation | P | DTO、JSON、内容协商与兼容边界 | MVC、json-mapping、enum-record-sealed |
| 8 | ch.spring.validation | P | Bean Validation、字段规则与跨字段规则 | MVC、DTO |
| 9 | ch.spring.problem-details-errors | P | 异常映射、Problem Details 与稳定错误契约 | validation、exceptions、api-contract-basics |
| 10 | ch.architecture.domain-modeling | F | 实体、值对象、聚合、不变量与边界 | inheritance-composition、interfaces、business-value-types |
| 11 | ch.spring.datasource-pooling | P | 数据源、连接池、事务资源与迁移启动顺序 | Boot、JDBC、schema-migrations、database-transactions |
| 12 | ch.spring.mybatis-repositories | P | Repository 边界与 Spring MyBatis 适配 | datasource、mybatis-core、domain-modeling |
| 13 | ch.spring.service-use-cases | P | 应用服务、用例编排与领域边界 | repositories、domain-modeling |
| 14 | ch.spring.aop-proxy-model | P | 切点、通知、代理边界与自调用陷阱 | IoC、beans、reflection-classloading-proxies |
| 15 | ch.spring.testing-testcontainers | P | Spring 测试切片、上下文测试与 Testcontainers | Boot、MVC、repositories、Java testing；Docker 为实验前置 |
| 16 | ch.spring.transactions | D | @Transactional、传播、回滚、隔离与提交后行为 | database-transactions、service、AOP、Spring testing、repositories |
| 17 | ch.spring.openapi-contracts | P | OpenAPI、契约示例与兼容性检查 | MVC、DTO、validation、Problem Details、API basics |
| 18 | ch.spring.actuator-health-metrics | D | Actuator、健康、就绪、指标与安全暴露 | Boot、configuration、Spring testing |

事务主线固定为：

JDBC/MyBatis Core → Spring DataSource → Repository/MyBatis → Service → AOP + Spring Test → Spring Transaction。

事务不再先于真实持久化层，也不再依赖未来测试章。领域建模前移到 Service 之前。

## 9. 卷 06：安全、可靠性与企业架构（19 章）

| 顺序 | ID | 角色 | 标题 | 关键硬前置 |
|---:|---|---|---|---|
| 1 | ch.security.threat-model-trust-boundaries | F | 安全目标、资产、信任边界与威胁建模 | http-curl、api-contract-basics |
| 2 | ch.security.identity-password-lifecycle | F | 身份、密码哈希、凭据生命周期与恢复边界 | business-value-types、testing-oracles |
| 3 | ch.security.cookie-session-model | F | Cookie、Session、认证状态与固定攻击模型 | http-curl、identity-password-lifecycle |
| 4 | ch.security.origin-cors-csrf | F | Origin、SameSite、CORS 与 CSRF | HTTP、session-model、threat-model |
| 5 | ch.security.untrusted-input-xss-ssrf | F | 不可信输入、输出编码、XSS 与 SSRF | threat-model、origin-cors-csrf、Spring validation/errors |
| 6 | ch.security.spring-security-architecture | P | FilterChain、SecurityContext、默认拒绝与异常链 | Boot、threat-model、origin/CSRF、untrusted-input |
| 7 | ch.security.session-authentication | P | Spring Security 登录、退出、密码编码与 Session 防护 | identity、session-model、security-architecture、Spring testing |
| 8 | ch.security.jwt-resource-server | P | JWT 验证、Bearer Token 与 Resource Server | security-architecture、API basics、Spring testing |
| 9 | ch.security.oauth2-oidc | P | OAuth 2.0 授权流程、OIDC 登录与客户端边界 | session-model、JWT、security-architecture |
| 10 | ch.security.authorization-rbac-abac | P | URL/方法授权、RBAC、ABAC 与默认拒绝 | security-architecture、session-authentication、JWT |
| 11 | ch.security.multitenancy-data-isolation | D | 租户上下文、数据权限与跨租户隔离测试 | authorization、Spring repositories、Spring transactions/testing |
| 12 | ch.security.audit-events-privacy | D | 审计事件、敏感字段、追踪责任与隐私最小化 | authorization、multitenancy、Java logging |
| 13 | ch.architecture.workflow-state-sla | F | 状态机、状态转换、SLA 与超时语义 | domain-modeling、database-transactions |
| 14 | ch.architecture.idempotency-concurrency | D | 幂等键、乐观并发、重复提交与重放 | workflow-state-sla、DB/Spring transactions、threads-jmm |
| 15 | ch.distributed.redis-cache-rate-limit | P | Redis 缓存、TTL、失效、配额与限流 | idempotency-concurrency、network-layers；Docker 为实验前置 |
| 16 | ch.architecture.domain-events-outbox | D | 领域事件、Outbox 与提交一致性 | domain-modeling、idempotency、Spring transactions |
| 17 | ch.distributed.messaging-delivery | D | RabbitMQ、投递语义、重试、死信与幂等消费 | outbox、idempotency、network-layers；Docker 为实验前置 |
| 18 | ch.architecture.modular-monolith | D | 模块化单体、结构测试与拆分信号 | domain-modeling、service-use-cases、outbox、Spring testing |
| 19 | ch.architecture.observability-slo | D | 日志、指标、追踪、SLO 与告警闭环 | Actuator、Java logging、modular-monolith、audit-events |

安全实现顺序固定为：

威胁模型 → 身份/Session/浏览器安全模型 → Spring Security 架构 → 具体认证实现 → JWT/OAuth → 授权 → 租户隔离 → 审计。

前三层只教模型与威胁，不再要求在 Spring Security 之前实现安全登录或 Session fixation 测试。

## 10. 76 个旧 ID 的迁移账本

所有条目都更换为语义 ID。下列“保留”仅表示知识职责保留，不表示旧 ID 继续有效。

### 10.1 卷 00

- v00.c01.learning-evidence → ch.foundations.learning-evidence。
- v00.c02.computer-model → ch.foundations.computer-process-model，后移。
- v00.c03.files-paths-encoding → ch.foundations.files-paths-encoding，缩小独立 outcome。
- v00.c04.terminal-shell → ch.foundations.terminal-shell。
- v00.c05.pipes-exit-codes → ch.foundations.cli-streams-exit-codes。
- v00.c06.environment-path → ch.foundations.environment-tool-resolution。
- v00.c07.editor-ide-debugger → ch.foundations.editor-project-navigation + ch.java.debugging-failures。
- v00.c08.git-security → ch.foundations.git-collaboration-security。
- v00.c09.network-http-curl → ch.foundations.network-layers + ch.foundations.http-curl。
- v00.c10.dependencies-build-ai → ch.foundations.dependencies-build-packages。
- v00.c11.docker-foundations → ch.foundations.docker-basics。
- v00.c12.ai-collaboration-verification → ch.foundations.ai-assisted-verification。
- 新增：ch.foundations.api-contract-basics、ch.foundations.testing-oracles。

### 10.2 卷 01

- v01.c01.java-platform → ch.java.platform-toolchain。
- v01.c02.program-structure → ch.java.program-structure；跨包访问片段迁入 ch.java-oop.encapsulation-packages。
- v01.c03.console-io → ch.java.console-input-validation；基本输出片段迁入 values 章。
- v01.c04.variables-scope + v01.c05.primitive-types → ch.java.values-variables-types。
- v01.c06.operators-conversion → ch.java.expressions-conversions。
- v01.c07.conditionals-switch → ch.java.branching。
- v01.c08.loops-control → ch.java.loops；查找练习迁入 arrays 章。
- v01.c09.methods → ch.java.methods。
- v01.c10.arrays-debug-test → ch.java.arrays-command-args + ch.java.maven-junit-smoke + ch.java.debugging-failures。

### 10.3 卷 02

- v02.c01.references-null-memory → ch.java-oop.references-null-identity。
- v02.c02.classes-fields-methods → ch.java-oop.classes-objects。
- v02.c03.constructors-encapsulation → constructors-invariants + encapsulation-packages。
- v02.c04.static-final-immutability → static-class-state + final-immutability；集合防御性复制迁入集合实践。
- v02.c05.inheritance-composition → ch.java-oop.inheritance-composition。
- v02.c06.polymorphism-interfaces → ch.java-oop.interfaces-polymorphism。
- v02.c07.enum-record-sealed → ch.java-oop.enum-record-sealed。
- v02.c08.object-contract → ch.java-oop.object-contracts；Set/Map 证明迁入 associative-collections。
- v02.c09.core-value-types → ch.java-oop.business-value-types；String 基础前移卷 01。
- v02.c10.exceptions-resources → exceptions-failure-contracts + io-resource-lifecycle。

### 10.4 卷 03

- v03.c01.collections → sequential-collections + associative-collections。
- v03.c02.generics-comparator → generics-type-safety + sorting-comparators。
- v03.c03.complexity-data-structures → complexity-algorithms。
- v03.c04.lambdas-functions → lambdas-functional-interfaces。
- v03.c05.streams-optional → functional-pipelines。
- v03.c06.io-nio-json → io-resource-lifecycle + nio-files-charsets + json-mapping。
- v03.c07.threads-jmm → threads-jmm。
- v03.c08.executors-virtual-threads → executors-virtual-threads。
- v03.c09.annotations-reflection-proxy → annotations-metadata + reflection-classloading-proxies。
- v03.c10.maven-testing-jvm → maven-reproducible-builds；最小 Maven/JUnit 片段前移卷 01。
- v03.c11.java-networking → network-programming。
- v03.c12.java-testing-mocking → testing-test-doubles；JUnit 入门前移卷 01。
- v03.c13.logging-jvm-diagnostics → logging-jvm-diagnostics。

### 10.5 卷 04

- v04.c01.relational-model → relational-model + postgresql-psql；主外键修复迁入 DDL。
- v04.c02.sql-query-basics → select-rowsets。
- v04.c03.sql-functions → scalar-functions。
- v04.c04.aggregate-group-having → aggregates。
- v04.c05.joins-subquery-cte → joins + subqueries-cte + window-functions。
- v04.c06.dml-ddl-normalization → DML + DDL/constraints + normalization/modeling。
- v04.c07.postgres-types-psql → postgresql-types；psql 基础前移。
- v04.c08.indexes-explain → indexes-explain。
- v04.c09.transactions-locks → transactions-locking。
- v04.c10.migration-jdbc-mybatis → schema-migrations；删除标题中不存在的 JDBC/MyBatis 声明。
- v04.c11.jdbc-pool-mybatis → JDBC + MyBatis Core。

### 10.6 卷 05

- v05.c01.web-jakarta-lifecycle → servlet-request-lifecycle。
- v05.c02.ioc-di-beans → ioc-di + beans-lifecycle-scopes。
- v05.c03.configuration-profiles → configuration-profiles。
- v05.c04.boot-autoconfiguration → boot-autoconfiguration。
- v05.c05.mvc-controllers → mvc-routing-binding。
- v05.c06.dto-serialization → dto-json-content-negotiation。
- v05.c07.validation-errors-files → validation + problem-details-errors；分页归入 MVC，文件输入规则归入 validation。
- v05.c08.services-transactions-aop → service-use-cases + aop-proxy-model + transactions，并移到 Repository/Test 之后。
- v05.c09.mybatis-integration → datasource-pooling + mybatis-repositories。
- v05.c10.testing-openapi-actuator → testing-testcontainers + openapi-contracts + actuator-health-metrics。
- ch.architecture.domain-modeling 从旧 v06.c06 前移到本卷 Service 之前。

### 10.7 卷 06

- v06.c01.auth-session-password → identity-password-lifecycle + cookie-session-model + session-authentication。
- v06.c02.web-security-threats → threat-model-trust-boundaries + origin-cors-csrf + untrusted-input-xss-ssrf。
- v06.c03.jwt-oauth-oidc → jwt-resource-server + oauth2-oidc。
- v06.c04.spring-security → spring-security-architecture + session-authentication + authorization-rbac-abac。
- v06.c05.rbac-multitenancy-audit → authorization-rbac-abac + multitenancy-data-isolation + audit-events-privacy。
- v06.c06.domain-modeling → ch.architecture.domain-modeling，前移卷 05。
- v06.c07.state-sla-idempotency → workflow-state-sla + idempotency-concurrency；SLO 深化迁入 observability。
- v06.c08.redis-cache-rate-limit → redis-cache-rate-limit。
- v06.c09.events-outbox-messaging → domain-events-outbox + messaging-delivery。
- v06.c10.modular-monolith-observability → modular-monolith + observability-slo。

## 11. 必须新增的机器验证规则

1. ID 格式改为 ^ch\.[a-z0-9-]+\.[a-z0-9-]+$；ID 不包含卷号或顺序，发布后不可变。
2. volume、order 单独校验；每卷 order 必须从 1 连续递增。
3. 增加 instruction_role：first-teach、language-practice、framework-practice、platform-practice、production-deepening、integration-review。
4. 增加 concepts_taught、concepts_practiced、concepts_assumed；assumed/practiced 必须由本章或硬祖先教授。
5. 每个概念只能有一个 canonical first-teach 章；后续 HTTP、Docker、MyBatis、测试、可观测性必须标实践或深化。
6. 分离 prerequisites、lab_prerequisites、route_gate_requirements；Docker/Testcontainers 等实验环境不能污染知识硬图。
7. recommended_after 不得满足 outcome 必需知识。
8. 每章默认最多两个主要认知簇；超过时必须是 integration-review，且不得首次教授新概念。
9. 增加 borrowed_scaffolds；暂借语法只允许用于运行，outcome 不得要求解释其内部机制。
10. 首次出现“测试、断言、expected/actual”前，必须有 testing-oracles 硬祖先。
11. Java 自动化测试必须有 maven-junit-smoke；Mockito 必须有 Java 测试深化；Spring 集成测试必须有 Spring testing。
12. 泛型必须是所有泛型集合的硬祖先；Set/Map 必须有 Object 契约祖先。
13. Java 资源关闭必须同时有 exceptions、files-paths 和具体 IO 教学来源。
14. JOIN 统计 outcome 必须有 aggregate；窗口函数必须有聚合、Join、CTE 的真实祖先。
15. JDBC 必须有 SQL、异常和 DB 事务祖先，但不得强制完整 Flyway。
16. MyBatis Core 必须依赖 JDBC；Spring Repository 必须依赖 MyBatis Core；Spring transaction 必须依赖 Repository、Service、AOP、Spring Test 和 DB transaction。
17. 安全实现必须依赖相应模型：Session 实现不能早于 Session/威胁模型；JWT/OIDC 与授权分层；多租户必须依赖真实持久化与事务测试。
18. 每个旧 ID 必须在 migration ledger 中恰好出现一次；一对多 target 全部存在，新章必须有 new_reason。
19. 不创建运行时 alias/redirect；routes、gates、README、front matter、来源映射和测试 fixture 必须一次迁移。
20. 零基础路线按新 order 完整覆盖；任一章节的硬祖先必须位于其前面；DAG、未知外键、循环继续 fail-closed。
21. outcome 增加 verification_mode，例如 manual-calculation、command-output、embedded-assert、junit、maven-test、spring-test，禁止用模糊“测试”提前消费未来工具。
22. 标题与 outcomes 的语义覆盖进入人工 P1R rubric，不能再允许标题声称 JSON/JUnit/MyBatis，outcome 完全不验证。

## 12. 可合并但非阻断的候选

若版面必须压缩，可从 110 章降至约 106—107 章，但不建议默认合并：

- ch.data.scalar-functions 可并入 select-rowsets，前提是 outcome 仍只覆盖标量表达式。
- ch.java-oop.static-class-state 与 final-immutability 可合并为“类级状态、常量与不可变性”，但不得重新加入集合防御性复制。
- ch.spring.ioc-di 与 beans-lifecycle-scopes 可合并为两个认知簇的章节。
- ch.java-engineering.io-resource-lifecycle 与 nio-files-charsets 可合并，但零基础认知负荷会明显增加。

不得重新合并：

- 网络与 HTTP。
- 通用测试与 JUnit。
- 注解与反射/代理。
- JOIN、CTE 与窗口函数。
- Flyway、JDBC 与 MyBatis。
- Validation、Problem Details 与文件输入。
- Spring Testing、OpenAPI 与 Actuator。
- Service、AOP 与 Transaction。
- JWT 与 OAuth/OIDC。
- 授权、多租户与审计。
- Outbox 与消息投递。
- 模块化单体与可观测性。

## 13. 实施完成标准

1. 110 个卷 00—06 章节进入 canonical catalog，状态全部仍为 planned。
2. 上述 76 个 legacy ID 全量进入迁移账本；无遗漏、无未知 target。
3. Spring 事务循环、HTTP 假教学、测试提前使用、集合/IO 顺序、SQL 与安全实现顺序均有自动负向测试。
4. 四条路线、G0—G8、卷 README、chapter front matter、来源映射和站点生成物一次性迁移并重建。
5. 新 ID 不提供兼容 alias；回滚方式是整体恢复 P1 catalog、routes、gates、book 与生成物。
6. PROGRESS.md 保持零差异；目录迁移、占位文件和测试通过都不计为学习完成。

## 14. 有意未做

- 未编写或伪造任何章节正文。
- 未修改 curriculum/catalog.yml、routes、gates、book、schemas 或生成物。
- 未验证具体软件版本；版本准确性由独立版本审查处理。
- 未修改 PROGRESS.md。
- 未把本设计当作已实施、已出版或已掌握的证据。
