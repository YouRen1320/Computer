# Spring：测试、Testcontainers 与 OpenAPI

## 1. 测试的核心是可信的判定标准

测试不是“把方法调用一遍”，而是在可控条件下执行行为，然后用可信标准判定结果是否正确。

例如计算价格时，不能用被测方法自己再算一次期望值：

```java
long actual = calculator.total(1999, 3);
long expected = calculator.total(1999, 3); // 没有独立判定力
```

如果方法把乘法错写成加法，`actual` 和 `expected` 仍然相等。真正的期望值应来自需求、规则、已知例子或独立模型：

```java
assertEquals(5997L, calculator.total(1999, 3));
```

这个“怎样知道对不对”的依据叫**测试预言（test oracle）**。这是测试中比框架 API 更根本的概念。

## 2. AAA：让测试表达一个清晰事实

一个常见测试结构是：

1. **Arrange**：准备数据和依赖；
2. **Act**：执行一次目标行为；
3. **Assert**：断言可观测结果。

```java
@Test
void assignsOpenWorkOrder() {
    // Arrange
    WorkOrder workOrder = WorkOrder.open("WO-1");

    // Act
    workOrder.assignTo("TECH-7");

    // Assert
    assertEquals("TECH-7", workOrder.assigneeId());
    assertEquals(WorkOrderStatus.ASSIGNED, workOrder.status());
}
```

AAA 不是强制每段都写注释。它的价值是让读者看到：条件是什么、发生了什么、根据哪些外部可观测结果判断。

测试名应表达业务行为，例如 `completedWorkOrderCannotBeReassigned`，而不是 `testMethod1`。测试失败时，名称应能直接告诉你哪条承诺被破坏。

## 3. 测试层级由“真实程度”决定

同一系统需要不同层级的测试：

| 层级 | 主要范围 | 优点 | 主要局限 |
| --- | --- | --- | --- |
| 纯单元测试 | 一个类或少量对象 | 快、定位清楚 | 不能证明框架和外部系统集成正确 |
| 切片测试 | Spring 的某一层 | 验证该层框架配置，比全上下文轻 | 不包含完整 Bean 图 |
| 集成测试 | 多层+真实基础设施 | 能发现边界错配 | 较慢，需要环境管理 |
| 端到端测试 | 从外部入口经过整个系统 | 最接近用户路径 | 定位慢、易受环境影响 |

层级不由测试类的名字决定。如果一个所谓“单元测试”启动 Spring、PostgreSQL、消息队列和远程服务，它的真实范围就已经是集成测试。

也不要用“底层测试数量越多越好”取代风险判断。简单 getter 写十个测试，不如把关键事务边界和数据库约束验证清楚。

## 4. 单元测试应尽量不启动 Spring

构造器注入让 Service 可以当作普通 Java 类测试：

```java
@Test
void savesAssignedWorkOrder() {
    WorkOrderRepository repository = new InMemoryWorkOrderRepository();
    NotificationPort notification = new RecordingNotificationPort();
    WorkOrderService service = new WorkOrderService(repository, notification);

    service.assign("WO-1", "TECH-7");

    assertEquals("TECH-7", repository.findById("WO-1").assigneeId());
}
```

这类测试的重点是业务分支和对象协作，不是证明 Spring 能启动。每个单元测试都用 `@SpringBootTest`，会使反馈变慢，也让失败同时受大量配置影响。

只要测试目标是 Java 对象规则，就优先直接构造它。

## 5. Test Double：在测试中代替协作者

测试替身统称 **test double**，其中常见类型包括：

- **stub**：为调用提供预设返回值；
- **fake**：有一套可用但简化的实现，如内存 Repository；
- **spy**：记录发生过的调用；
- **mock**：通常由工具生成，预设行为并验证交互。

这些词在实际团队中偶尔会被混用，但更重要的是知道替身为什么存在：它让测试控制依赖的输入，并观察目标对象如何使用该依赖。

### 5.1 不要模拟自己要验证的东西

如果目标是验证 MyBatis SQL 映射，把 Mapper mock 掉后无法证明 SQL 正确。如果目标是验证 Controller 的 JSON 契约，直接调用 Controller Java 方法也无法证明路由、绑定和序列化正确。

测试要保留目标行为的真实性，只替换与本次问题无关、太慢或不可控的边界。

### 5.2 过度验证调用细节会让测试脆弱

一个方法内部从两次查询重构成一次批量查询，只要外部行为不变，大量测试不应因此失败。交互验证最适合真正重要的协作承诺，如“事务成功后只发一次通知”，而不是把每个私有步骤都锁死。

## 6. 参数化测试表达一组同类规则

当多组输入共享同一执行和断言逻辑时，可用参数化测试：

```java
@ParameterizedTest
@ValueSource(strings = {"", " ", "\t"})
void rejectsBlankDescription(String description) {
    assertThrows(
            IllegalArgumentException.class,
            () -> WorkOrder.open("DEV-1", description)
    );
}
```

它不是为了把无关场景压进一个巨大测试。如果不同输入有不同准备和断言，分开写往往更清楚。

## 7. Spring 测试上下文的价值与代价

Spring TestContext 可以为测试创建 ApplicationContext，也会尽量缓存已创建的上下文。它能验证：

- Bean 是否正确注册和注入；
- 配置属性是否绑定；
- AOP、事务等代理是否生效；
- Web、数据访问等框架组件是否协作。

但上下文越大，启动越慢，失败时涉及的可能原因也越多。测试中频繁使用不同 Profile、属性和 mock Bean，还可能让上下文缓存无法复用。

`@DirtiesContext` 会标记上下文不再可复用，应用于测试真的污染了全局上下文的情况，不要把它当成隔离不清的通用补丁。

## 8. 切片测试：只启动当前边界

Spring Boot 提供面向特定技术层的测试切片。概念上：

```text
Web 切片：Controller + MVC 路由/绑定/序列化
数据切片：Mapper/Repository + 数据访问配置
JSON 切片：JSON 映射和自定义配置
```

切片测试没有启动整个应用，所以不在该切片中的协作者通常需要显式提供或替换。这不是缺点，而是它帮你把问题限定在一个技术边界的方式。

### 8.1 Web 测试要经过 MVC 管道

MockMvc 可在不真正监听 TCP 端口的情况下，让请求经过 Spring MVC 路由、绑定、校验、异常映射和 JSON 转换。

```java
mockMvc.perform(get("/api/work-orders/{id}", "WO-1")
        .accept(MediaType.APPLICATION_JSON))
    .andExpect(status().isOk())
    .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
    .andExpect(jsonPath("$.id").value("WO-1"));
```

直接调用 `controller.findById("WO-1")` 只能测试 Java 方法，不能证明 `/api/work-orders/WO-1` 会被正确映射和序列化。

## 9. 为什么数据库测试要使用真实 PostgreSQL

内存数据库启动快，但它与 PostgreSQL 在类型、SQL 语法、索引、锁、隔离和 JSONB 等方面不完全相同。如果生产用 PostgreSQL，只在 H2 上通过不能充分证明 SQL 和迁移真的可用。

Testcontainers 允许测试启动一个临时 PostgreSQL 容器：

```text
测试开始
  ↓
启动指定镜像的 PostgreSQL 容器
  ↓
获取本次的 JDBC URL、用户名和密码
  ↓
Spring 连接该数据库，执行迁移和测试
  ↓
测试结束后回收容器
```

这不是用 mock 模拟 PostgreSQL，而是真正运行 PostgreSQL，只是它的生命周由测试管理。

## 10. Testcontainers 的动态连接信息

容器可以将内部端口映射到本机随机可用端口。因此不应在测试配置中硬编码 `localhost:5432`。应在容器启动后，将其实际连接信息交给 Spring。

Spring Boot 可通过服务连接机制或动态属性注册连接容器。无论使用哪种 API，心智模型都是：

```text
容器生成本次运行的连接参数
             ↓
Spring 测试上下文使用这些参数创建 DataSource
```

如果在容器还没启动时就读取映射端口，或在 Spring 已创建 DataSource 后才覆盖属性，时序就错了。

## 11. 容器测试仍需要隔离和可重复数据

真实数据库不会自动让测试正确。还要处理：

- 每个测试的数据初始状态；
- 测试顺序是否会影响结果；
- 事务回滚是否真的覆盖了异步或多连接操作；
- 迁移能否从空库完整执行；
- 容器和数据是每测试、每类还是每个测试会话共享。

为了性能复用一个容器很常见，但每个测试仍应以可预期方式准备或清理自己的数据。不要让“在我这里单独跑通过”掩盖顺序依赖。

## 12. 测试事务可能会隐藏真实提交问题

某些 Spring 集成测试在测试方法结束时自动回滚。这对数据清理很方便，但也可能隐藏只在提交时才发生的事情：

- 延迟到提交时检查的约束；
- transaction synchronization 的 after-commit 回调；
- 真正多请求或多事务之间的可见性；
- 应用服务自己划定的事务边界。

因此关键事务场景中，需要有真正提交并从新事务查看结果的测试。

## 13. OpenAPI 是机器可读的 HTTP 契约描述

OpenAPI 文档可以描述：

- 有哪些 path 和 HTTP method；
- 路径、查询、header 参数是什么；
- 请求 body 和响应 body 的 schema；
- 可能的状态码和错误结构；
- 认证方式；
- 示例、字段说明和废弃信息。

它的价值不只是生成一个好看的 Swagger UI。OpenAPI 可用来：

- 与前端和移动端评审契约；
- 生成或辅助生成客户端；
- 比较版本并发现破坏性变更；
- 产生模拟服务、文档和契约测试；
- 作为开发者之间的统一语言。

### 13.1 “从代码生成”和“从契约生成”

两种常见流程：

```text
代码优先：Controller/DTO → 生成 OpenAPI
契约优先：评审 OpenAPI → 生成骨架/客户端 → 实现
```

代码优先起步快，但容易把 Java 实现细节直接变成外部契约。契约优先适合多团队并行和严格 API 治理，但需要更明确的设计流程。

不论选哪个，都要防止“实现已改，文档未改”或“文档很完整，但线上行为不同”。将契约生成、差异检查和请求测试进入构建流程，才能减少漂移。

### 13.2 示例不等于 schema

一份 JSON 示例只能说明某个输入可能长什么样，不能完整表达必填字段、值范围、枚举、null 语义和所有错误分支。Schema 负责结构约束，example 负责帮助人理解。

## 14. 契约兼容不只是字段名

常见破坏性变更包括：

- 删除或改名已发布字段；
- 将可选字段变为必填；
- 收紧字符串格式或数值范围；
- 改变枚举值，而客户端对未知值处理不当；
- 将成功状态码、错误类型或分页语义改掉；
- 将字段单位从分改成元，但名称和类型不变。

“JSON 还能解析”并不等于业务兼容。契约测试需要关注语义，不只是语法。

## 15. Actuator：给运行中的应用提供观测入口

Spring Boot Actuator 可以暴露健康、指标、配置等管理信息。最常见的区分是：

- **liveness**：进程是否处于可继续运行的状态，失败时平台可考虑重启；
- **readiness**：当前实例是否已准备好接收流量，失败时可暂时从流量中移除。

不要在 liveness 检查中严格依赖所有外部服务。如果数据库短暂故障导致所有应用实例被不断重启，会把下游问题放大成本服务的重启风暴。

### 15.1 管理端点不是天然安全的

环境属性、Bean 情况、日志级别和线程信息可以帮助诊断，也可能泄露内部结构或敏感数据。只应暴露实际需要的端点，并用网络、认证和授权保护它们。

## 16. 测试失败时怎样定位

先判断失败类型：

```text
测试无法编译
  → 测试代码/API/依赖问题

Spring 上下文无法启动
  → Bean、配置、Profile、容器或迁移问题

请求得到非预期 HTTP 响应
  → 路由、绑定、校验、业务或异常映射

断言值不相等
  → 先核对预言，再查实际行为

只在整套或 CI 失败
  → 共享状态、时序、端口、时区、随机性或资源不足
```

异常堆栈从最外层说明“测试失败”，原因链中更靠内的第一条具体错误才往往是起点。例如最外层是 `Failed to load ApplicationContext`，内层可能是迁移 SQL 第 18 行语法错误。

## 17. 如何组合一套有价值的测试

可以从风险而不是从文件数量出发：

1. 领域对象的关键不变条件，用快速单元测试覆盖；
2. Application Service 的用例分支和重要协作，用 fake/stub 控制；
3. Controller 的路由、JSON、校验和 Problem Details，用 Web 切片测试；
4. Mapper、迁移、约束和事务，用真实 PostgreSQL 容器验证；
5. 少量关键用户路径，用全链路测试证明系统可运行；
6. OpenAPI 差异检查契约兼容，Actuator 信号证明部署后可观测。

一套健康测试的目标是：大多数反馈快且定位明确，少量更真实的测试又能防止各层在集成处脱节。

## 18. 这篇的概念地图

```text
需求和契约
  └── 提供测试预言
          ↓
按风险选测试层级
  ├── 单元：对象规则
  ├── 切片：Spring 的某个边界
  ├── 集成：真实数据库和框架协作
  └── 端到端：关键用户路径
          ↓
OpenAPI 稳定外部契约
Actuator 提供运行期信号
```

以后不需要为了证明自己“会测试”而给每行简单代码配一个测试。先问它要阻止什么风险，预期结果根据什么，以及哪个层级最能以低成本验证这份承诺。
