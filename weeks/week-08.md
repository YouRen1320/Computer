# 第 8 周：Spring Boot 4.1 Web、REST、DTO、校验与统一错误

## 定位

本周把 FactoryCare 变成可通过 HTTP 使用的 Spring Boot 4.1 应用。重点是清晰 API 契约、边界校验和统一错误，而不是堆 Controller 注解。使用稳定的 Spring Boot 4.1.x、Spring Framework 7.0.x、Servlet MVC 和 Jackson 3 组合。

时间预算：15—18 小时。业务数据仍在内存中，避免同时学习 Web 和数据库导致问题混杂。

## 前置

- JDK 25、Maven 3.9.16、Spring Core 装配和 `mvn verify` 正常。
- FactoryCare 领域、应用服务和内存仓储有自动化测试。
- 理解构造器注入、Bean、Profile 和配置边界。
- 会用 curl 或 API 客户端发送 HTTP 请求并查看状态码、header、body。

## 目标

- 理解 Spring Boot starter、自动配置、条件配置和应用启动过程的高层机制。
- 使用 Boot 4 模块化的 MVC starter 建立 REST API。
- 按资源和 HTTP 语义设计 URI、方法、状态码与幂等性。
- 将 Web DTO、领域对象和持久化对象分离。
- 使用 Jakarta Validation 做结构校验，业务规则仍由应用/领域层负责。
- 使用 RFC 9457 Problem Details 和稳定错误码形成统一错误契约。
- 完成创建、查询和列表工单的第一条 HTTP 垂直切片。

## 完整概念清单

### Spring Boot 4.1 基线

- Boot 4.1.0 是当前稳定代际；项目跟随 4.1.x 维护版本，不使用 snapshot/milestone。
- Boot 4 的 starter 模块化与 Boot 3 教程差异；MVC 使用当前对应 starter，并配置匹配的测试 starter。
- 通过 Spring Initializr 生成后检查 POM，不盲抄旧教程依赖坐标。
- `@SpringBootApplication` 组合配置、自动配置和扫描的高层作用。
- 自动配置基于 classpath、Bean 和 properties 条件；不是“猜测代码”。
- embedded server、可执行 jar、`SpringApplication` 和 ApplicationContext。
- Boot 管理依赖版本；第三方兼容性必须由启动/集成测试确认。

### 外部化配置

- `application.yaml/properties`、环境变量、命令行参数和 Profile 的优先级概念。
- 使用类型安全配置属性承载成组配置并做启动校验。
- 配置名称、单位和默认值明确，例如 `Duration` 而非裸毫秒数字。
- 密钥不提交仓库；示例配置只包含占位和说明。
- local/test/prod 差异不复制业务代码。

### HTTP 与 REST

- request/response、method、URI、query、header、body、media type。
- GET、POST、PUT、PATCH、DELETE 的语义及 safe/idempotent 概念。
- 以资源名词设计 URI，避免 `/doCreateWorkOrder` 风格。
- 200、201、204、400、404、409、422、500 等状态码的业务边界。
- 创建成功的 Location header；不存在与无权访问不要混淆。
- Content-Type 与 Accept；JSON 不是唯一 HTTP 表示，但本项目先用 JSON。
- API 版本策略只了解选择维度，不提前发布多版本。

### Spring MVC 请求链

- DispatcherServlet、handler mapping、controller、argument resolution、message conversion 的高层流程。
- `@RestController`、`@RequestMapping`、各 HTTP method mapping。
- `@PathVariable`、`@RequestParam`、`@RequestBody`。
- `ResponseEntity` 只在需要控制状态/header 时使用，不包裹所有响应。
- Controller 负责协议转换与调用用例，不承载领域规则。
- Spring Boot 自动配置 MVC 时不随意添加 `@EnableWebMvc` 覆盖默认能力。

### DTO 与 JSON

- request DTO、response DTO、领域对象职责分离。
- record 可用于不可变 DTO，但需确认校验和 Jackson 3 行为。
- 显式 mapper 将 DTO 转成领域输入，避免 Controller 直接修改实体。
- 不把内部异常、数据库字段或敏感字段自动暴露为 JSON。
- enum、时间和 null 的稳定 JSON 表示。
- 请求兼容和响应兼容不同；新增必填字段会产生破坏。

### Validation

- Jakarta Validation 的对象约束、嵌套 `@Valid` 和集合元素校验。
- `@NotNull`、`@NotBlank`、`@Size`、`@Min/@Max`、`@Pattern` 的合理边界。
- 结构/格式校验放边界，跨实体和状态业务规则放应用/领域层。
- 校验消息供人阅读，机器处理依赖稳定 error code/path。
- 不相信前端校验，后端始终独立验证。

### 统一错误

- RFC 9457 Problem Details：type、title、status、detail、instance 及扩展字段。
- Spring `ProblemDetail` 与全局异常处理器。
- `@RestControllerAdvice/@ExceptionHandler` 的职责。
- 业务异常到 404/409/422 的明确映射。
- 参数绑定、JSON 解析、Bean Validation 和未知异常的不同响应。
- 对外 detail 不泄漏堆栈、SQL、路径和密钥；内部日志保留关联信息。
- 错误响应包含稳定业务 code、字段错误列表和 request/correlation ID。

### 列表查询

- filter、sort、page/size 的输入约束。
- 稳定排序避免翻页漂移；本周使用内存实现但先固定 API 语义。
- 空列表返回空数组和分页元数据，不返回 null。
- 不允许客户端传任意字段名直接反射排序。

## 任务分配

| 模块 | 时间 | 任务 |
| --- | ---: | --- |
| Boot 基线 | 2h | Initializr、POM、starter 模块化、启动与配置 |
| HTTP/REST | 2.5h | 资源、方法、状态码、幂等与 curl 实验 |
| MVC/DTO | 3h | Controller、映射、JSON 和 DTO mapper |
| Validation/错误 | 3h | 边界校验、ProblemDetail、业务错误码 |
| FactoryCare | 3—4h | 创建/查询/列表工单 API |
| 无 AI 训练 | 2h | 新端点与错误定位 |
| 求职动作 | 1h | Spring Boot/REST 口述与投递 |

## FactoryCare项目增量

使用`/api/v1/work-orders`建立以下契约：

- `POST /api/v1/work-orders`：创建工单，成功返回201和Location。
- `GET /api/v1/work-orders/{id}`：查询详情，不存在返回统一404 Problem Detail。
- `GET /api/v1/work-orders`：按状态、优先级、设备筛选并稳定分页。

需要的 DTO：

- `CreateWorkOrderRequest`：设备 ID、故障描述、严重度、停机/安全等输入。
- `WorkOrderResponse`：稳定业务 ID、状态、优先级、创建时间等允许公开字段。
- 分页响应与字段错误结构。

要求：Controller 不直接访问 repository；DTO 不进入领域层；业务异常映射稳定；输入 JSON 损坏、字段缺失、非法 enum、工单不存在和重复业务请求都有明确响应。

## AI协作边界

可以让 AI：

- 根据已确认 API 契约生成 Controller/DTO/mapper 样板。
- 列出 HTTP 状态码、校验和错误边界候选。
- 审查 Controller 是否泄漏领域/持久化细节。
- 根据 curl 输出帮助定位请求映射或 JSON 问题。

必须由你完成：

- 先写 API 契约、示例、状态码和错误码。
- 决定结构校验与业务校验的边界。
- 检查 Boot 4/Jackson 3 导入和 starter 是否来自当前官方文档。
- 能修改一个请求字段并同步 mapper、验证、响应与测试。

## 无AI训练

本周从求职/复盘时段预留45—60分钟完成并记录：堆/Top K基础题；说明为什么选择堆及其复杂度。

关闭 AI，限时120分钟：

1. 新增`GET /api/v1/equipment/{equipmentId}/work-orders`只读端点。
2. 自己定义空结果、设备不存在、非法 ID 和分页越界行为。
3. 写 curl 样例并补 Web 层测试草稿；完整测试体系第 9 周完成。
4. 人为制造一个 DTO/JSON 字段不匹配和一个缺失 Bean，依据日志定位。
5. 口述一次请求从 DispatcherServlet 到应用服务再到 JSON 响应的链路。

## 求职动作

- 准备 Spring 与 Spring Boot 区别、自动配置、starter、REST、状态码、DTO、Validation、统一异常的口述。
- 从 10 个南昌 Java 岗位记录 Boot 版本、Spring MVC、Swagger/OpenAPI 要求。
- 完成至少 5 次定向投递；简历项目描述注明“Spring Boot 4.1 项目实践”，不写商业 Spring 经验。
- 录制一次 3 分钟 API 演示并复盘表达是否只在讲注解。

## 交付物

- Spring Boot 4.1.x 可执行应用和受控依赖 POM。
- 创建、详情、筛选分页三类工单 API。
- 请求/响应 DTO、显式 mapper 和字段约束。
- RFC 9457 风格统一错误响应及错误码表。
- curl/API 示例、配置说明和无 AI 故障记录。

## 验收标准

- `mvn verify` 通过，应用由 JDK 25 启动且使用稳定 Boot 4.1.x。
- 能解释 Boot 自动配置的条件思想和 Spring Core 的关系。
- API URI、method、状态码、Location、幂等语义一致。
- Controller 无业务规则和仓储直连；DTO、领域对象明确分离。
- 无效 JSON、字段校验、业务冲突、不存在和未知错误响应可区分。
- Problem Detail 不泄漏堆栈/SQL/本地路径，包含稳定 code 与关联 ID。
- 无 AI 完成新只读端点并定位 DTO/Bean 故障。

## 明确不做

- 不接 PostgreSQL、MyBatis、Flyway、Security 或 Redis。
- 不学习 WebFlux、Reactor、Servlet 容器源码或自定义消息转换器源码。
- 不添加 `@EnableWebMvc` 重建 Boot 默认配置。
- 不实现文件上传、SSE、WebSocket、API 多版本或复杂 PATCH。
- 不把实体直接作为请求/响应，也不返回统一 HTTP 200 包装所有错误。

## 官方资料

- [Spring Boot 4.1 Documentation](https://docs.spring.io/spring-boot/)
- [Spring Boot 4.1 Release Announcement](https://spring.io/blog/2026/06/10/spring-boot-4/)
- [Spring Boot 4 Modularization](https://spring.io/blog/2025/10/28/modularizing-spring-boot/)
- [Spring Boot Servlet Web Applications](https://docs.spring.io/spring-boot/reference/web/servlet.html)
- [Spring Web MVC](https://docs.spring.io/spring-framework/reference/web/webmvc.html)
- [Spring MVC Validation](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-config/validation.html)
- [Spring Error Responses](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-ann-rest-exceptions.html)
- [RFC 9457 Problem Details](https://www.rfc-editor.org/rfc/rfc9457)
