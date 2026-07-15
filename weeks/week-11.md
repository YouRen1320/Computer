# 第 11 周：JUnit、Mockito、MockMvc、Testcontainers 与 OpenAPI

## 定位

本周为 FactoryCare 建立分层、可信、能在 CI 中重复运行的测试体系，并把 HTTP 契约沉淀为 OpenAPI。测试目标是降低变更风险，不是追逐覆盖率数字或为每个类机械创建 Mock。

时间预算：15—18 小时。Spring Boot 4.1 管理的测试依赖版本优先于手工追最新版本；第三方工具必须通过组合验证。

## 前置

- FactoryCare Spring Boot 4.1 Web API 可启动。
- 已有领域和应用层 JUnit 测试，理解 AAA 与行为测试。
- 本机有可用 Docker 兼容运行时；若没有，先记录阻塞，不用 mock 数据库冒充 Testcontainers。
- 能使用 curl 复现成功与错误响应。

## 目标

- 按单元、切片、集成、契约和端到端边界选择测试。
- 使用 JUnit 6 生命周期、参数化测试、嵌套测试和断言。
- 正确使用 Mockito 代替慢或不可控协作者，不 mock 值对象和被测逻辑。
- 使用 MockMvc 验证完整 Spring MVC 请求处理而不启动真实服务器。
- 理解 Testcontainers 2 的生命周期、镜像固定和 Spring Boot service connection。
- 建立 OpenAPI 契约，并对 `/v3/api-docs` 或静态契约做回归验证。
- 形成一条可在 CI 执行的 `mvn verify` 质量门。

## 完整概念清单

### 测试策略

- 单元测试：快、隔离、验证领域/应用行为。
- Web slice：验证映射、绑定、Validation、JSON 和错误处理。
- 集成测试：真实 Spring Context 与真实外部组件组合。
- 契约测试：固定消费者可依赖的 HTTP 结构。
- 端到端测试只了解边界，本周不引入浏览器。
- 测试金字塔/测试蜂巢只是启发，按风险选层级。
- 同一规则不在所有层复制同样断言；每层验证独有风险。
- 测试必须独立、确定、可读，不能依赖执行顺序和真实当前时间。

### JUnit 6

- Boot 4.1 BOM 管理的 JUnit 版本优先；不手工覆盖到独立最新版本。
- `@Test`、生命周期回调、per-method 默认实例。
- `@Nested` 组织业务场景，避免多层嵌套制造噪声。
- 参数化测试、方法源、枚举源和 CSV 源。
- `assertThrows`、`assertAll`、超时断言的边界。
- tag 与 test filtering 的用途。
- 动态测试只了解存在，普通参数化测试足够时不用。
- 测试 fixture builder/object mother 适量使用，避免隐藏关键输入。

### Mockito

- dummy、stub、fake、mock、spy 的区别。
- `mock`、stubbing、argument matcher、verification、captor。
- 行为验证只用于重要协作，例如必须发送一次通知；不验证每次 getter 调用。
- 严格 stubbing 帮助发现无用设置。
- 不 mock record/Value Object/List/String/被测类。
- 能写内存 fake 时优先 fake，避免脆弱交互测试。
- static/final 深度 mock 通常提示设计或边界问题。
- JDK 新版本出现动态 agent 提示时按 Mockito 官方 javaagent 指南处理，不永久忽略。

### Spring Test 与 MockMvc

- Spring TestContext 缓存 ApplicationContext 的高层行为。
- `@SpringBootTest` 与 Web slice 的成本差异。
- Boot 4 模块化 test starter 与主 starter 要匹配。
- MockMvc 调用 DispatcherServlet、绑定、转换、校验和异常处理，但不启动网络服务器。
- 验证状态、header、content type、JSON path 和 Problem Detail。
- `@MockBean`/当前 Boot 测试替换机制应跟随 4.1 官方 API，不复制旧博客废弃用法。
- Controller 直接单测不能替代映射和序列化测试。

### Testcontainers 2

- 测试期间启动真实依赖服务，适合 PostgreSQL 等集成边界。
- Docker/兼容运行时是前置条件；容器不是内存数据库。
- 先完成求职所需Linux/Docker基线：用户/权限、进程/信号、端口、环境变量、stdout日志，以及Docker client/daemon、image、container、network、volume的关系；Week 46再学习安全镜像和生产部署。
- 固定镜像到 PostgreSQL 18.4 或明确 18.x，不使用 `latest`。
- JUnit extension、静态/实例容器生命周期的差异。
- Spring Boot `@ServiceConnection` 与容器 Bean 的连接详情。
- TestContext 缓存与容器关闭顺序风险；优先采用 Boot 官方建议的托管方式。
- Testcontainers 2 相对 1.x 有模块名/包名迁移，必须看当前文档。
- 本周只验证容器启动和连接；真实 SQL 模型第 13 周，MyBatis 集成第 15 周。

### OpenAPI

- OpenAPI 描述 paths、operations、parameters、request bodies、responses、schemas 和 security。
- 规范版本与工具支持版本不同；最新规范不等于生成器全部兼容。
- 契约优先关注真实 API 行为，不把注解当文档完成度。
- operationId、schema 名称、必填/可空、格式、示例和错误响应。
- springdoc 是社区项目，不是 Spring 官方组件。
- springdoc 3.x 面向 Boot 4，但 Boot 4.1 组合必须通过启动和 `/v3/api-docs` 测试确认。
- 若当前 springdoc 与 Boot 4.1 不兼容，保留手写 OpenAPI YAML，不降级核心栈或强行覆盖传递依赖。

### CI 质量门

- 单元测试失败、编译失败、契约失败必须阻止合并。
- 集成测试可在 verify 阶段运行，命名和插件边界明确。
- 失败时保留可读日志，不上传密钥或生产数据。
- 测试重试不能掩盖不稳定测试。

## 任务分配

| 模块 | 时间 | 任务 |
| --- | ---: | --- |
| 测试设计/JUnit | 3h | 分层矩阵、参数化和业务 fixture |
| Mockito | 2h | 外部通知端口协作测试与反模式修复 |
| MockMvc | 3h | 成功、校验、404、409、未知错误 Web tests |
| Testcontainers与Linux/Docker基线 | 2.5h | 运行时排查、PostgreSQL 18.4容器和连接smoke test |
| OpenAPI | 2h | 契约生成/手写、schema 与错误响应回归 |
| FactoryCare | 2h | 整理全套测试与`mvn verify` |
| 无 AI训练 | 2h | 限时补测与口述 |
| 求职动作 | 1h | 测试/Linux/Docker关键词与投递 |

## FactoryCare项目增量

建立测试矩阵：

- 领域单元：优先级、Value Object、状态候选规则。
- 应用单元：创建工单、重复 ID、仓储失败；使用内存 fake。
- 协作测试：通知端口仅在必须验证调用时使用 Mockito。
- Web slice：创建成功 201+Location、Validation 400、损坏 JSON、404、409、统一 Problem Detail。
- Context smoke：应用和关键配置能启动。
- Testcontainers smoke：启动 PostgreSQL 18.4，获取连接并执行 `SELECT 1`；不提前写业务持久化。
- Linux/Docker基线：能查看容器进程、端口、日志、环境和卷，制造一次端口占用或权限错误并用证据定位。
- OpenAPI：描述创建/查询/列表和所有稳定错误 schema；若使用 springdoc，增加 `/v3/api-docs` 可解析测试。

建立测试命名和目录约定，并让 `mvn verify` 一次执行需要的检查。

## AI协作边界

可以让 AI：

- 根据 API 契约生成测试候选和 MockMvc 样板。
- 审查哪些测试属于重复、实现细节或缺少失败路径。
- 从失败日志提出假设，但不能直接用放宽断言“修复”。
- 根据已确认 schema 生成 OpenAPI 初稿。

必须由你完成：

- 先写风险矩阵：什么失败会影响用户、应该在哪层验证。
- 逐条判断 mock/fake/真实组件，不默认全部 Mockito。
- 检查容器镜像、生命周期、测试数据隔离和清理。
- 对照运行中的 API 验证 OpenAPI，而不是只让 YAML 语法通过。

## 无AI训练

本周从求职/复盘时段预留45—60分钟完成并记录：DFS/BFS基础题；说明访问集合、终止条件和复杂度。

关闭 AI，限时120分钟：

1. 给列表接口增加一个非法排序字段场景。
2. 自行选择单元还是 Web slice，并写出理由和测试。
3. 修复一个“Mockito 返回值让测试通过，但真实业务会失败”的过度 mock。
4. 运行全部测试，定位一个 Context 加载失败或 JSON 断言不匹配。
5. 口述 MockMvc 与真实服务器、Testcontainers 与 mock 数据库的边界。

## 求职动作（恢复求职后启用）

- 准备 JUnit、Mockito、MockMvc、`@SpringBootTest`、测试切片、Testcontainers、OpenAPI/Swagger 的回答。
- 用一张测试矩阵向面试官解释为何不是只追覆盖率。
- 统计目标岗位是否要求 Swagger、单元测试、CI；将已完成内容诚实加入项目描述。
- 定向投递至少 6 个岗位，记录测试相关追问和不会的问题。

## 交付物

- FactoryCare 测试风险矩阵和分层测试套件。
- JUnit、Mockito、MockMvc 和 Context 测试。
- PostgreSQL 18.4 Testcontainers smoke test。
- Linux/Docker基础排查记录：进程、端口、日志、权限和容器生命周期。
- OpenAPI 契约及生成/兼容性决策记录。
- 可重复执行的 `mvn verify` 和失败排查记录。

## 验收标准

- 能解释每类测试独有价值，核心规则不依赖 Spring 启动。
- Mockito 只替代真实协作边界，无 mock 值对象/集合/被测类和无意义 verify。
- MockMvc 覆盖请求映射、JSON、Validation、状态码、header 和统一错误。
- Testcontainers 使用固定 PostgreSQL 18.4 镜像，生命周期明确，Docker 缺失会给出清晰失败。
- 能解释client/daemon、image/container、port/volume，并定位一次端口或权限故障；不把这当成生产部署能力。
- OpenAPI 与真实端点/错误 schema 一致；第三方兼容风险有自动测试或手写契约回退。
- `mvn verify` 可重复通过，无执行顺序依赖和真实时间依赖。
- 无 AI 能为新错误路径选择正确测试层并定位一次失败。

## 明确不做

- 不追求 100% 行覆盖率，不测试 getter/setter 和私有方法。
- 不用 H2 冒充 PostgreSQL，也不在本周实现业务 SQL。
- 不引入浏览器 E2E、性能测试、契约测试平台或 mutation testing。
- 不因 springdoc 兼容问题随机降级 Boot、覆盖大量依赖或关闭启动测试。
- 不把 Swagger UI 能打开视为 API 契约正确。

## 官方资料

- [Spring Boot 4.1 Testing](https://docs.spring.io/spring-boot/reference/testing/)
- [JUnit User Guide](https://docs.junit.org/current/user-guide/)
- [Mockito Official Repository](https://github.com/mockito/mockito)
- [Spring MockMvc](https://docs.spring.io/spring-framework/reference/testing/mockmvc.html)
- [Testcontainers for Java](https://java.testcontainers.org/)
- [Spring Boot Testcontainers](https://docs.spring.io/spring-boot/reference/testing/testcontainers.html)
- [OpenAPI Specification 3.2](https://spec.openapis.org/oas/v3.2.0.html)
- [springdoc Boot 4 Documentation](https://springdoc.org/v4/index.html)
