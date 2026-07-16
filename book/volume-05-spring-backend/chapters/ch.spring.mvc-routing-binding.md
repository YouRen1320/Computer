---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.mvc-routing-binding
title: Controller、路由、参数绑定与状态码
responsibility: 教授 Spring MVC 入站路由和 HTTP 结果契约，不在本章处理 JSON 兼容、Bean Validation 或全局异常映射
volume: '05'
order: 6
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.mvc-routing-binding.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.servlet-request-lifecycle
- ch.spring.boot-autoconfiguration
version_surfaces:
- spring-boot-4.1
- spring-framework-7
- jakarta-ee
- jdk-25
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释Controller、路由、参数绑定与状态码的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - spring-mvc-routing
  - spring-mvc-binding
  covers_topics:
  - spring.mvc-controller
  - spring.request-mapping
  - spring.route-ambiguity
  - spring.path-query-header-binding
  - spring.response-entity
  - spring.http-status-contract
  uses_capabilities:
  - backend.servlet-request
  - backend.spring-di-config
  - foundation.http-message
  - backend.spring-mvc-contract
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现 GET /work-orders/{id} 与分页列表 Controller，绑定 path/query/header 并返回 200/400/404 的 ResponseEntity，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - spring-mvc-routing
  - spring-mvc-binding
  covers_topics:
  - spring.mvc-controller
  - spring.request-mapping
  - spring.route-ambiguity
  - spring.path-query-header-binding
  - spring.response-entity
  - spring.http-status-contract
  uses_capabilities:
  - backend.servlet-request
  - backend.spring-di-config
  - foundation.http-message
  - backend.spring-mvc-contract
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入路由歧义、参数名/类型绑定失败和错误状态一律200，使用 MockMvc/curl 响应修复
  covers_topic_groups:
  - spring-mvc-routing
  - spring-mvc-binding
  covers_topics:
  - spring.mvc-controller
  - spring.request-mapping
  - spring.route-ambiguity
  - spring.path-query-header-binding
  - spring.response-entity
  - spring.http-status-contract
  uses_capabilities:
  - backend.servlet-request
  - backend.spring-di-config
  - foundation.http-message
  - backend.spring-mvc-contract
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# Controller、路由、参数绑定与状态码

> 本章状态为 drafting。正文和工件只提供教材证据，不自动更新 `PROGRESS.md`，也不表示学习者已完成 Week 10。

HTTP 请求进入 Servlet 容器后，Spring MVC 需要选择唯一 handler，把 path、query 和 header 转换为 Java 参数，再把处理结果变成明确的 HTTP status、header 与 body。Controller 是入站适配器，不是业务规则和持久化细节的集合。

本章工件固定 Spring Boot 4.1.0、其 BOM 管理的 Spring Framework 7.0.8、Jakarta Servlet 6.1、JDK 25 与 Maven 3.9.16。官方资料复核日期为 2026-07-17；本章不展开 JSON 兼容、Bean Validation 或全局异常映射。

## 1. 本章完成证据

完成者要能从 method、path、query、header 预测唯一 handler 与 Java 入参，并说明成功、参数错误、资源不存在和路由不存在分别采用什么状态。所有判断必须由可重放 MockMvc 断言证明。

配套工件：

- [Controller 路由与绑定观察台](../../../examples/encyclopedia/ch.spring.mvc-routing-binding/README.md)
- [FactoryCare 入站契约实验](../../../labs/encyclopedia/ch.spring.mvc-routing-binding/README.md)
- [错误状态码练习](../../../exercises/encyclopedia/ch.spring.mvc-routing-binding/README.md)

## 2. 从 Servlet 到 MVC

Servlet 容器负责连接、请求响应对象和 Filter 链；MVC 在 Servlet 栈上提供 handler 映射、参数解析、类型转换和返回值处理。上一章的请求线程与生命周期边界仍成立。

MVC 不是另一个 HTTP 协议。最终客户端仍只看到状态行、header 和 body；注解只是把协议合同映射到 Java 方法。

## 3. DispatcherServlet 是前端控制器

典型 Servlet 应用把请求交给 `DispatcherServlet`。它不直接包含所有业务逻辑，而是协调 HandlerMapping、HandlerAdapter、参数解析器、返回值处理器等组件。

把它想成总调度台：先找谁处理，再用合适方式调用，最后写响应。Controller 方法只是这条流水线中的一个 handler。

## 4. HandlerMapping 选择候选

`RequestMappingHandlerMapping` 在启动时读取 Controller 的映射元数据，形成请求条件到方法的登记。请求到达时，它按 path、HTTP method、params、headers、consumes、produces 等条件筛选。

映射是多维条件，不是只比较字符串路径。两个方法 path 相同但 HTTP method 不同，可以是两个明确端点；所有条件都相同则通常在启动时产生歧义。

## 5. HandlerAdapter 调用方法

找到 handler 后，HandlerAdapter 负责解析方法参数并处理返回值。`@PathVariable long id` 需要先从 URI 提取文本，再转换为 `long`；`ResponseEntity` 则提供 status、headers 和 body。

因此“已经命中路由”不代表 Controller 一定执行。参数转换可能在方法调用前失败，断点未进入方法是正常证据。

## 6. Controller 的职责

Controller 负责翻译入站协议：读取允许的 HTTP 输入、构造用例调用、把用例结果映射成 HTTP 输出。它应保持薄而明确。

工单状态流转、授权、事务和 SQL 不应堆进 Controller。业务逻辑若只在一个路由里可见，就无法被其他入口复用，也难以独立测试。

## 7. Controller 与 RestController

`@Controller` 标识 Web 组件；方法通常参与视图解析，除非加 `@ResponseBody`。`@RestController` 组合了 `@Controller` 与类级 `@ResponseBody`，方法返回值直接写入响应体。

“RestController 自动返回正确 REST”是误解。状态码、资源路径、幂等语义与错误合同仍要设计，本章用 `ResponseEntity` 显式表达结果。

## 8. 类型级与方法级映射

类型级 `@RequestMapping("/work-orders")` 声明共享前缀，方法级 `@GetMapping("/{id}")` 进一步限定。最终条件是两层组合。

共享前缀降低重复，但不要把不同资源硬塞进一个巨型 Controller。按资源或清晰用例边界组织，能让路由表易读。

## 9. 使用 HTTP 方法快捷注解

`@GetMapping`、`@PostMapping`、`@PutMapping`、`@DeleteMapping`、`@PatchMapping` 是方法限定的组合注解。多数 handler 应声明具体 HTTP method，而非用默认匹配所有方法的裸 `@RequestMapping`。

GET 查询不应偷偷修改工单；POST 创建与 GET 读取的缓存、重试和幂等语义不同。注解选择必须服从 HTTP 合同。

## 10. 映射条件不只有 path

映射还可限定特定 query 参数、header、请求媒体类型和可产生媒体类型。这些条件会参与候选筛选，而普通 `@RequestParam` 只在命中后解析参数。

例如 `params="view=summary"` 可以区分表示，但过度按 query 拆 handler 会难以发现冲突。优先保持资源路径和方法清晰，只有合同真正不同才增加映射条件。

## 11. Framework 7 使用 PathPattern

Spring MVC 当前使用预解析的 `PathPattern` 来匹配请求路径，能更稳健处理编码和路径变量。旧 `AntPathMatcher` 方案在 Framework 7 文档中已弃用，不应作为新教材主线。

`*` 只跨一个路径段内字符，`**` 跨多个段；`{name}` 捕获一个段，`{*path}` 捕获剩余路径。不要用模糊通配符掩盖资源层次。

## 12. 精确模式优先

多个模式都匹配时，MVC 比较特异性。静态段通常比变量和通配符更具体，例如 `/work-orders/search` 应优先于 `/work-orders/{id}` 的变量候选。

但若 `{id}` 声明为任意字符串，`search` 仍可能先成为候选并在转换时失败。可以用明确静态路由、类型正则或更清晰层级消除意外重叠。

## 13. 路由歧义有两种时点

两个方法注册完全相同的映射时，context 常在启动期以 ambiguous mapping 失败；这是好事，因为服务没有带着随机路由上线。

另一些模式只有在特定请求上同样具体，可能到请求选择时才出现歧义。测试既要覆盖启动登记，也要用代表性 URI 验证唯一命中。

## 14. PathVariable

`@PathVariable` 读取 URI 模板变量，通常标识目标资源：

```java
@GetMapping("/{id}")
ResponseEntity<String> detail(@PathVariable long id) { ... }
```

路径 `/work-orders/42` 的 `42` 先是文本，再通过转换服务变成 `long`。变量名和模板名必须一致，或在注解中显式写名。

## 15. 路径变量转换失败

请求 `/work-orders/not-a-number` 命中了形状 `/{id}`，但不能转换为 `long`，因此方法不会执行，MVC 产生 4xx。它不是“资源 not-a-number 不存在”的 404。

这个区别很重要：400 表示请求不能满足声明的输入类型；404 表示输入格式有效，但目标资源或路由不存在。

## 16. 编译参数名与显式名称

若省略 `@PathVariable("id")` 的名字，框架需要读取 Java 参数名；项目应使用 `-parameters` 编译。构建配置丢失可能让同一源码在不同环境绑定失败。

对教学和公共合同，显式写名字能降低隐式依赖；同时仍开启 `-parameters`，让诊断、反射和其他框架行为一致。

## 17. RequestParam

`@RequestParam` 读取 Servlet 请求参数，常用于分页、排序和筛选。简单类型会自动转换；默认 `required=true`，缺失时在调用前产生 4xx。

可选参数应通过 `required=false`、`Optional<T>` 或明确默认值表达。不要把 `null`、空串和“未提供”混成一种业务含义。

## 18. 默认值要属于 HTTP 合同

分页可声明 `@RequestParam(defaultValue="0") int page` 与 `defaultValue="20" int size`。默认让简单客户端可用，但必须公开并测试。

默认值只能解决缺失，不能替代范围规则。`size=-1` 可以成功转换成整数，却仍是不合理输入；本章用显式边界检查返回 400，下一章再系统引入 Bean Validation。

## 19. 多值参数

同名 query 可能出现多次，例如 `status=OPEN&status=ASSIGNED`。绑定到 `List<String>` 能保留多个值，绑定到单值可能丢失调用者意图。

是否允许重复、顺序是否重要、空集合如何解释，都应在 API 合同中说明。不要让容器默认行为替代业务选择。

## 20. RequestHeader

`@RequestHeader` 读取 header 并支持类型转换。FactoryCare 示例要求 `X-Tenant-Id`，用来把调用上下文传给应用用例。

header 名不区分大小写，但合同应使用稳定规范拼写。缺少 required header 是 4xx；header 值格式正确并不代表调用者已获授权。

## 21. Header 不是可信身份

来自网络的 header 都是不可信输入。Controller 可以绑定 tenant 或 correlation id，却不能仅因客户端声称 `X-Role: ADMIN` 就授予权限。

真实身份应由安全过滤链验证，并把可信 principal/context 传入后续层。本章只证明绑定和缺失行为，不冒充完整认证授权。

## 22. path、query、header 的分工

path 标识资源或层次，query 调整列表、筛选或表现，header 承载跨资源的请求元数据。把工单 id 放 header、把租户放任意 query 都会降低可见性和缓存语义。

这不是绝对语法限制，而是主流合同设计。每个输入位置都要能回答：它是否参与资源身份、是否可选、是否应出现在链接中。

## 23. ModelAttribute 与 RequestBody 的边界

复杂未注解对象可能按 `@ModelAttribute` 绑定，请求体则通过 `@RequestBody` 与消息转换器处理。隐式规则过多时，读者难以判断输入来自哪里。

本章只显式使用 path/query/header。DTO、JSON 字段兼容、内容协商和消息转换在下一章展开，避免把路由证据与序列化证据混在一起。

## 24. ResponseEntity

`ResponseEntity<T>` 同时携带状态、headers 和 body，适合结果随用例分支变化的 handler。例如存在返回 200 和实体，不存在返回 404 无 body。

它不是要求每个方法都写复杂 builder。固定创建成功可用 `@ResponseStatus`；本章选择 ResponseEntity，是为了让 200/400/404 映射在代码和测试中可见。

## 25. 状态码是机器合同

客户端通常先按 status 分类，再解析 body。2xx 表示请求被成功处理，4xx 表示客户端请求或权限问题，5xx 表示服务端未完成合同。

状态不是装饰文本。监控、代理、重试、缓存和 SDK 都依赖它；错误地一律返回 200 会破坏整个 HTTP 生态。

## 26. 详情查询的 200 与 404

`GET /work-orders/42` 若存在，应返回 200 和表示；合法 id 不存在，应返回 404。404 不说明调用者拼写格式错误，而是目标在当前可见范围内不存在。

为了避免枚举泄露，授权系统有时也把不可见资源映射为 404；那属于安全合同，本章不展开，但不能随意暴露存在性。

## 27. 列表查询通常返回 200

合法分页查询没有结果时，一般返回 200 和空集合/空页，而不是 404。请求的“集合资源”存在，只是成员数为零。

工件用简化文本页验证 page、size 和 tenant 已绑定，不定义最终 JSON 分页格式。分页元数据与兼容性留给 DTO 章节。

## 28. 参数非法使用 400

无法转成声明类型、缺少 required 参数/header、或通过显式边界检查失败，都属于客户端无法满足当前输入合同，返回 400。

不要用 500 包装这些可预期输入错误，也不要在 Controller 内 catch 所有 Exception 后返回 200。状态应对应失败类别。

## 29. 不存在路由是 404

请求 `/unknown` 没有任何 handler 时，MVC 返回 404。它与“命中 `/work-orders/{id}` 但资源不存在”共享状态，却来自不同阶段。

测试需要两种 404：一个证明资源分支映射，一个证明路由表没有误接管未知路径。日志和指标可进一步区分来源。

## 30. 方法不允许是 405

path 存在 GET handler，但客户端发送 POST，通常应得到 405 Method Not Allowed，而非 404 或 200。Allow header 可以告诉客户端允许的方法。

本章核心验收要求 200/400/404，但实验额外保留 405 断言，防止裸 `@RequestMapping` 意外接受所有方法。

## 31. 媒体类型留给下一章

`consumes`、`produces` 和 Accept 会参与路由与结果选择，错误可能产生 415 或 406。然而要正确解释它们必须同时讲消息转换和内容协商。

本章只说明它们属于映射维度，不把一次默认 JSON 输出当成完整兼容证据。资产断言以状态、header 和简单 body 为主。

## 32. HTTP 状态不应藏在 body

`200 {"success":false,"code":404}` 让代理和通用客户端以为请求成功。业务错误码可以补充细节，但不能替代 HTTP status。

FactoryCare Controller 先选择 200/400/404，再生成最小响应。下一章会定义稳定 DTO，而不是把状态修正推迟给前端。

## 33. 避免“一律 200”

一律 200 常源于前端旧约定或 Controller 为图省事。短期减少分支，长期会破坏缓存、告警、SDK 生成和故障统计。

迁移时应列出调用方、逐端点定义状态映射并增加契约测试；兼容旧 body 若确有必要，也应是明确期限的迁移选项，而非默认永久保留。

## 34. 用例端口与内存实现

Controller 依赖 `WorkOrderQuery` 接口，而非直接访问 Map 或数据库。示例内存实现只为确定性数据，返回 Optional 或页结果。

这样路由测试聚焦 HTTP 映射，Repository 和数据库行为可在后续层独立验证。内存假实现不是生产持久化证明。

## 35. 构造器注入保持依赖显式

Controller 通过构造器接收 query service。缺 Bean 会在 context 启动时明确失败，测试也能传入小型 fake。

字段注入让依赖隐藏并迫使反射测试。入站适配器仍遵守前面章节的 DI 原则，不因注解框架而例外。

## 36. FactoryCare 详情路由

最小合同：`GET /work-orders/{id}`，required header `X-Tenant-Id`，id 为正整数。合法且存在返回 200；合法但不存在返回 404；不能转换或非正数返回 400。

tenant 只传给用例端口，Controller 不自行判断数据权限。示例响应使用简单文本，避免提前承诺 JSON 兼容。

## 37. FactoryCare 列表路由

`GET /work-orders?page=0&size=20` 同样要求 tenant header。缺 page/size 时使用文档化默认；page 小于零、size 不在 1..100 返回 400。

列表与详情共享 base path，但一个是精确空后缀，一个是 `/{id}`，不会让相同 URI 命中两个 handler。

## 38. 不要用 catch-all Controller

`/**` 或 `{*path}` handler 可能吞掉应由静态资源、错误处理或其他模块接收的请求。除网关等明确场景外，业务 Controller 应声明窄路由。

通配符越宽，新增端点时越容易出现特异性和安全审计问题。未知路径保持 404 是有价值的边界。

## 39. MockMvc 的定位

MockMvc 在不启动真实服务器的情况下，通过 MVC 调度基础设施执行请求，能验证映射、参数解析、转换、返回值与响应。它比直接调用 Java 方法更接近 HTTP 边界。

它不证明真实 socket、代理、TLS、Servlet 容器线程池或部署 header 行为。需要时再增加启动端口测试和 curl 证据，而不是让所有测试都变重。

## 40. standalone 与 context 测试

standalone MockMvc 只注册指定 Controller 和显式组件，快速且适合本章映射。Web context 或 Boot 测试能验证自动配置、扫描和全局组件，但更慢、故障范围更大。

示例使用 standalone 固定 MVC oracle，实验增加 context 启动测试来捕获歧义映射。选择测试层级要与主张一致。

## 41. 请求构造与结果断言

测试构造 method、URI、query 与 header，然后断言 status、header、body，以及 fake query 收到的参数。只断言 200 可能掩盖绑定错字段。

每个 case 使用独立输入，避免上个请求状态泄漏。验证报告输出测试数和契约分类，不输出 tenant、token 等真实值。

## 42. 参数转换的稳定 oracle

本地化错误消息可能随环境变化，测试不匹配整段异常文本。稳定 oracle 是响应类别与 Controller 未被调用，必要时再断言 resolved exception 的类型。

例如 id 非数字应是 400、query 调用次数为零。这样测试既证明转换边界，又不绑死实现消息。

## 43. 路由唯一性 oracle

一个请求只应选择一个 handler。可以查询 `RequestMappingHandlerMapping` 的登记，过滤 FactoryCare path 并确认每个条件唯一；也可以构造冲突配置，断言 context 启动失败。

不能用“两个 handler 恰好返回相同 body”掩盖冲突。唯一性是部署前合同，不是响应内容偶然一致。

## 44. Controller 输入都是不可信的

path、query、header 都可被伪造、重复、超长或使用异常编码。类型转换只解决表示到 Java 类型，不解决授权、注入、资源消耗和业务合法性。

本章实施最小数字范围与 required 输入，后续用 Bean Validation、安全过滤和数据层参数化继续收紧。不要宣称“绑定成功即安全”。

## 45. FactoryCare 请求矩阵

详情矩阵包括：存在 200、不存在 404、非数字 400、非正数 400、缺 tenant 400。列表矩阵包括默认分页 200、自定义分页 200、非法 page/size 400。

路由矩阵再加未知 path 404、错误 method 405、映射冲突启动失败。每一行只有一个主要变量，便于定位因果。

## 46. 详情请求的执行序列

`GET /work-orders/42` 到达后：按 GET 与 path 找候选，提取 id，转换 long，解析 required header，调用 query port，再根据 Optional 选择 200 或 404。

若转换失败，序列停在调用前；若资源缺失，方法已调用但结果为空。MockMvc 与 fake 调用记录能区分两者。

## 47. 列表请求的执行序列

列表先命中精确 `/work-orders`，解析默认或显式 page/size，执行范围检查，再把 tenant 与分页交给 query port。空结果仍是成功集合响应。

不要把数据库 offset 算法写进 Controller。分页输入是入站合同，查询实现负责如何高效执行。

## 48. 相关性 header

响应可回显服务端生成或已验证的 correlation id，帮助跨日志关联；不要回显任意敏感 header。测试 header 时使用明显假的固定值。

correlation id 不改变业务状态码。观察能力不能把失败包装成成功，也不能在 body 泄露内部堆栈。

## 49. 故障：参数名不匹配

模板是 `/{id}`，注解却写 `@PathVariable("workOrderId")`，启动可能成功，但请求解析失败。先比较映射模板和参数注解，再检查 `-parameters`。

修复后要重跑合法与非法 id；只修快乐路径可能改变 400 分支。显式命名是最直接的防漂移方式。

## 50. 故障：类型选择错误

把 id 声明为 int 可能在大值时溢出绑定失败；声明为 String 又把数值规则推迟到业务层。类型应对应 API 合同与领域标识范围。

若标识未来改为 UUID，这是 API 合同变更，需要调用方、路由测试和序列化一起迁移，而不是只替换 Java 类型。

## 51. 故障：资源缺失仍返回 200

starter 练习故意对 Optional.empty 返回 `ResponseEntity.ok("NOT_FOUND")`。响应文本像错误，HTTP 协议却宣告成功，测试以 `EXPECTED_HTTP_404` 稳定红灯。

修复是选择 `ResponseEntity.notFound().build()`，并保留存在资源 200。不要把测试期望改成错误现状。

## 52. 独立构建任务

从空 Controller 实现详情和分页列表，构造器注入 fake query，显式绑定 path/query/header，并为请求矩阵写 MockMvc 测试。生成一份只含输入类别、操作和结果的脱敏报告。

先写预测表，再运行；至少亲手解释一个方法调用前失败和一个方法调用后返回 404 的区别。

## 53. 修改任务

把最大 page size 从 100 改为 50，并增加可选 `status` 多值筛选。先列出受影响的默认、边界和重复参数 case，再修改代码与测试。

不得顺便引入最终 JSON DTO 或全局异常处理。范围外优化记录为后续章节事项。

## 54. 诊断顺序

固定顺序：确认 method 与原始 URI；列出登记映射；检查最具体候选；检查 path/query/header 注解名和 required/default；检查转换异常；确认 Controller 是否被调用；最后核对 ResponseEntity 的 status/header/body。

context 启动失败先找 ambiguous mapping；请求期失败用 MockMvc resolved exception 与 fake 调用记录。修复后重跑原 case 和相邻反例。

## 55. 120 秒复述提纲

先说 DispatcherServlet 协调映射和调用；再说 mapping 按 method/path 等条件选唯一 handler；然后解释 path、query、header 如何转成参数；最后说明 ResponseEntity 映射 200/400/404，并举一律 200 或歧义路由反例。

如果只能背 `@GetMapping`，却不能预测方法是否执行与状态来源，就还没有掌握入站边界。

## 56. 有意不做与兼容边界

本章不定义 JSON DTO 兼容、内容协商细节、Bean Validation、全局异常映射、鉴权、数据库分页或 OpenAPI。资产使用简单响应表示，只证明 MVC 路由和 HTTP 结果。

不为“一律 200”的旧客户端默认保留兼容层。真实迁移若必须兼容，应明确调用方、期限、双读/双写或网关转换、监控与回滚计划。

## 57. 一手资料

- [Spring Framework 7.0.8：Annotated Controllers](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller.html)
- [Spring Framework 7.0.8：Controller Declaration](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller/ann.html)
- [Spring Framework 7.0.8：Mapping Requests](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller/ann-requestmapping.html)
- [Spring Framework 7.0.8：Method Arguments](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller/ann-methods/arguments.html)
- [Spring Framework 7.0.8：ResponseEntity](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller/ann-methods/responseentity.html)
- [Spring Boot 4.1：Servlet Web Applications](https://docs.spring.io/spring-boot/reference/web/servlet.html)
