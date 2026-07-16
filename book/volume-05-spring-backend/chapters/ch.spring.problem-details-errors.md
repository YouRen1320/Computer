---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.problem-details-errors
title: 异常映射、Problem Details 与稳定错误契约
responsibility: 教授把内部失败转换为稳定且不泄密的 HTTP 错误，不把堆栈或数据库细节暴露给客户端
volume: '05'
order: 9
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.problem-details-errors.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.validation
version_surfaces:
- spring-boot-4.1
- spring-framework-7
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
  text: 在 120 秒内解释异常映射、Problem Details 与稳定错误契约的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - spring-exception-mapping
  - spring-problem-details
  covers_topics:
  - spring.controller-advice
  - spring.exception-to-status
  - spring.error-cause-log
  - spring.problem-detail
  - spring.validation-problem
  - spring.error-information-disclosure
  uses_capabilities:
  - backend.spring-mvc-contract
  - java.exceptions-resources
  - foundation.http-message
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：用 ControllerAdvice 将校验、未找到、冲突和未知异常映射为 ProblemDetail，统一 type/title/status/detail/instance，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - spring-exception-mapping
  - spring-problem-details
  covers_topics:
  - spring.controller-advice
  - spring.exception-to-status
  - spring.error-cause-log
  - spring.problem-detail
  - spring.validation-problem
  - spring.error-information-disclosure
  uses_capabilities:
  - backend.spring-mvc-contract
  - java.exceptions-resources
  - foundation.http-message
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入异常被200包装、内部堆栈泄露和 cause 被吞，检查 HTTP 与服务端日志后修复
  covers_topic_groups:
  - spring-exception-mapping
  - spring-problem-details
  covers_topics:
  - spring.controller-advice
  - spring.exception-to-status
  - spring.error-cause-log
  - spring.problem-detail
  - spring.validation-problem
  - spring.error-information-disclosure
  uses_capabilities:
  - backend.spring-mvc-contract
  - java.exceptions-resources
  - foundation.http-message
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# 异常映射、Problem Details 与稳定错误契约

> 本章状态为 drafting。正文与工件提供教材证据，不自动更新 `PROGRESS.md`，也不代表学习者已经通过 Week 10。

程序内部需要足够详细的失败证据，HTTP 客户端却只应得到稳定、可行动且不泄密的错误合同。异常映射层负责把这两种需求分开：选择正确状态码，构造 RFC 9457 Problem Details，并把 trace 与完整 cause 留在服务端。

本章工件固定 Spring Boot 4.1.0、其 BOM 管理的 Spring Framework 7.0.8、Jackson 3、JDK 25 与 Maven 3.9.16。Spring 与 RFC 行为于 2026-07-17 复核；稳定原则与补丁相关事实会分开说明。

## 1. 本章完成证据

完成者要能预测并验证 FactoryCare 四类失败：请求校验失败为 400、工单不存在为 404、状态冲突为 409、未知内部失败为 500。五个标准成员、扩展字段和媒体类型要稳定；响应不得包含异常类名、SQL、堆栈或秘密；服务端证据必须保留 traceId 与原始 cause。

配套工件：

- [ProblemDetail 基线观察台](../../../examples/encyclopedia/ch.spring.problem-details-errors/README.md)
- [四类失败矩阵实验](../../../labs/encyclopedia/ch.spring.problem-details-errors/README.md)
- [修复异常被 200 包装练习](../../../exercises/encyclopedia/ch.spring.problem-details-errors/README.md)

## 2. 失败不是一种 Java 类型

失败可能来自 JSON 读取、Bean Validation、路由、领域规则、并发版本、数据库或程序缺陷。它们都可能以 Exception 出现，却不具有同一 HTTP 语义。

映射不能只问“异常叫什么”，还要问失败发生在哪个边界、客户端能否修正、资源是否存在、请求与当前状态是否冲突，以及是否属于服务端未知缺陷。

## 3. 异常是内部控制与诊断机制

Java 异常包含类型、消息、堆栈与 cause 链。它适合在内部传播失败上下文，不是可直接序列化的 API DTO。

同一异常类在不同入口甚至可能映射不同合同。反过来，多个内部异常也可归一成一个公开问题类型，从而允许内部重构而不迫使客户端跟随类名变化。

## 4. HTTP 状态是第一层合同

状态码首先服务于浏览器、代理、监控、重试器和通用客户端。它不能被 body 中的 `success:false` 替代。

把冲突放进 `200 OK` 会让缓存、告警和 SDK 把失败当成功；把所有客户端错误写成 500 又会诱发无效重试并掩盖责任边界。

## 5. 一条错误响应的流水线

典型 MVC 流程是：请求被读取和校验，Controller 或下层抛出异常，ExceptionHandler 解析最具体的映射，构造 ProblemDetail，HttpMessageConverter 协商表示并写出响应。

Controller 已执行不代表响应一定成功。序列化阶段仍可能失败；响应已经 committed 时，错误处理器也可能无法再安全改写状态和 body。

## 6. RFC 9457 解决什么

RFC 9457 定义通用的 machine-readable 问题模型，避免每个 API 发明互不兼容的 `error/message/result` 结构。它取代 RFC 7807，并注册 `application/problem+json` 与 `application/problem+xml`。

Problem Details 描述 HTTP 接口中的问题，不是远程调试器。规范明确提醒设计者审查信息披露风险。

## 7. 五个标准成员

标准模型包含 `type`、`title`、`status`、`detail`、`instance`。这些字段职责不同，不应把所有语义塞进可变 message。

字段可以省略，但稳定 API 通常明确给出五项，并通过契约测试保证 HTTP 状态与 body.status 一致。

## 8. type 是机器的主要标识

`type` 是 URI reference，标识问题类别。客户端应以它而非 title 或 detail 做机器分支。

FactoryCare 可使用 `https://factorycare.example/problems/work-order-conflict`。URI 的价值是全局稳定标识；它是否立即可访问不是判定类型的前提，但长期最好能解析为文档。

## 9. about:blank 的含义

缺少 type 时默认是 `about:blank`，表示没有超出 HTTP 状态码的额外语义。此时 title 应与该状态的推荐短语一致。

业务客户端需要区分 validation、not-found 与 conflict 时，不应把它们全部留成 `about:blank`；应定义受控、版本稳定的问题类型。

## 10. title 描述问题类型

`title` 是简短的人类可读摘要，同一 type 的不同发生实例通常保持不变，只有本地化可以改变。

“工单状态冲突”是 title；“工单 42 当前为 CLOSED，不能 start”是某次 occurrence 的 detail。客户端仍不应解析这两个文本做控制流。

## 11. status 必须与 HTTP 一致

ProblemDetail 的 `status` 是给消费者保存或脱离 HTTP 上下文使用的提示；真正控制通用 HTTP 软件的是响应状态行。

生成者必须让两者一致。`HTTP 200` 配 `body.status=409` 是自相矛盾的合同，本章红灯练习专门捕获这一缺陷。

## 12. detail 面向本次修正

`detail` 说明这次请求为何失败，重点是帮助调用者修正输入或决策。它不应包含 Java 类名、源码位置、连接串、SQL 或完整异常消息。

对于未知 500，安全 detail 可固定为“服务暂时无法完成请求，请携带 traceId 联系支持”，而不是把 `exception.getMessage()` 透传。

## 13. instance 标识一次发生

`instance` 是标识具体问题 occurrence 的 URI reference。Spring 在未设置时可从当前请求路径填入；应用也可以明确使用请求路径或受控的错误实例 URI。

不要从不可信 header 任意拼接绝对 URL。若系统处于反向代理后，应先建立可信 forwarded-header 策略再生成外部地址。

## 14. 扩展成员

RFC 9457 允许问题类型定义额外成员。Spring 的 `ProblemDetail.setProperty` 会把属性存入 properties map；Jackson mixin 在 JSON 中把它们展开到顶层。

FactoryCare 使用 `code`、`traceId` 和 validation 的 `errors`。扩展名、类型、是否必填同样是合同，不能把任意异常对象塞进去。

## 15. application/problem+json

JSON Problem Details 使用 `application/problem+json`。这比笼统的 `application/json` 更清楚地告诉消费者 body 是错误问题表示。

Spring MVC 的 Jackson converter 会把 ProblemDetail 的 JSON/XML problem 媒体类型列为可产出类型，并在协商中优先使用。测试应断言兼容的媒体类型，而非只看 body 字段。

## 16. Spring 的 ProblemDetail

Spring Framework 7 的 `org.springframework.http.ProblemDetail` 是 RFC 9457 表示。常见入口是 `forStatus` 和 `forStatusAndDetail`，随后设置 type、title、instance 与扩展属性。

它是响应模型，不是领域异常。领域层不应依赖 Spring HTTP 类型，否则同一规则很难在批处理、消息消费或纯单元测试中复用。

## 17. 安全构造顺序

推荐先从受控映射表确定 status、type、title、code，再从经过审查的数据生成 detail 和 instance，最后附加 traceId。

反例是先把整个异常转换成 Map，再删除看似敏感的键。黑名单会漏掉未来新增字段；错误响应应使用白名单构造。

## 18. ErrorResponse 是完整错误抽象

Spring 的 `ErrorResponse` 表示完整 RFC 9457 响应，包括 status、headers 和 ProblemDetail body。许多 MVC 内置异常已经实现它。

这意味着框架失败不必全部重新发明映射。先理解内置语义，再只覆盖项目需要稳定化或脱敏的部分。

## 19. ErrorResponseException

`ErrorResponseException` 是可携带完整错误响应的基础实现。它适合适配层需要以框架抽象表达 HTTP 失败的场景。

不要让领域聚合抛它。领域异常应该表达 `WorkOrderNotFound`、`InvalidTransition` 等业务语言，由入站适配层决定 404 或 409。

## 20. MVC 内置异常

媒体类型不支持、消息不可读、方法不允许、参数缺失和校验失败等 MVC 异常已有状态语义。Spring 7 的 ErrorResponse 支持让它们可形成 Problem Details。

但默认 detail、消息代码和 extension 未必等于你的公开合同。升级前要用真实请求回归，而不是根据异常继承图猜测 JSON。

## 21. @ExceptionHandler

`@ExceptionHandler` 方法按异常类型处理失败，可返回 ProblemDetail、ErrorResponse 或 ResponseEntity。最具体映射应处理可预测业务失败，兜底映射只处理未知异常。

签名应只接收需要的 request/context，不把 Controller 业务逻辑复制进 advice。映射层的职责是翻译，不是重新执行业务决定。

## 22. @ControllerAdvice

`@ControllerAdvice` 把处理器应用到多个 Controller；`@RestControllerAdvice` 等价于 advice 加响应 body 语义。它适合集中维护统一错误合同。

范围可以按 package、注解或 assignable type 限定。全局 advice 要特别小心和 UI Controller、第三方端点的交互，避免无意改写不属于该 API 的响应。

## 23. ResponseEntityExceptionHandler

Spring 提供 `ResponseEntityExceptionHandler` 作为 ControllerAdvice 基类，能处理 MVC 异常和 ErrorResponseException，并返回 RFC 9457 body。

可以覆盖某类专用方法，也可在 `createResponseEntity` 统一补充 traceId。覆盖越底层影响越广，必须用成功、内置失败和自定义失败同时回归。

## 24. Boot 4.1 的启用方式

Boot 4.1 可通过 `spring.mvc.problemdetails.enabled=true` 自动配置处理内置异常的 ResponseEntityExceptionHandler。Boot 同时保留 servlet 容器 `/error` 机制。

这两条路径解决的时点不同：ControllerAdvice 处理 MVC 调用链异常，`/error` 还承接容器 error dispatch。不要以为一个 advice 覆盖所有启动、filter 或已提交响应失败。

## 25. 明确错误合同的所有者

可选策略包括完全采用 Boot 内置 Problem Details、继承 ResponseEntityExceptionHandler 统一定制，或为业务异常增加更高优先级 advice。项目必须选定一个主要所有者。

多个同优先级 advice 都声明 `Exception.class` 会造成不可预测或启动期歧义。用窄异常类型与明确 `@Order`，并对最终注册顺序做测试。

## 26. FactoryCare 四类公开失败

本章固定最小分类：validation 400、work-order-not-found 404、work-order-conflict 409、internal-error 500。每类都有独立 type、固定 title 与 code。

它们不是系统所有错误。401/403、429、415、406、幂等冲突等在相应安全与协议章节定义，不能随意挤进这四类。

## 27. 领域异常不要携带 HTTP

`WorkOrderNotFoundException` 表示按标识未找到工单；`InvalidTransitionException` 表示命令与当前状态不兼容。它们可以保留必要领域上下文，但不构造 ProblemDetail。

同一个领域用例若从消息消费者调用，失败可能进入 dead-letter 或业务拒绝记录，而非 HTTP。分离后适配器才能各自正确翻译。

## 28. validation 映射

`@Valid @RequestBody` 常见失败是 `MethodArgumentNotValidException`。响应 detail 应是稳定摘要，例如“一个或多个字段不合法”，具体项放入结构化 errors。

不要公开 BindingResult 的 `toString()`；它可能含 rejected value、对象名、内部代码层级和随版本变化的格式。

## 29. errors 扩展模型

一个最小项可定义 `{path, code, detail}`。path 对应 API 字段，code 是稳定机器码，detail 是可本地化人类文本。

例如 `{path:"description",code:"required",detail:"description must not be blank"}`。机器客户端依据 code/path，绝不解析 provider 的完整默认消息。

## 30. 多错误排序

Bean Validation violation 与 BindingResult 的原始顺序不是可靠 API。映射后按 path、code 排序，才能获得稳定快照和客户端显示。

若同一路径有多个约束，应明确全部返回还是选最相关项。本章实验选择 collect-all，并对规范化后的集合断言。

## 31. 404 的安全 detail

未找到可说明公开资源标识，但不能借此泄露租户边界。多租户系统常把“资源不存在”和“调用者不可见”统一为相同外部形态。

是否采用这种安全等价由授权合同决定。本章只用无敏感性的演示 id，不把 404 当作授权实现。

## 32. 409 表示当前状态冲突

状态机非法转换、乐观锁版本过期或幂等键与不同载荷复用，通常比 400 更接近 409：请求语法正确，但与资源当前状态冲突。

detail 可指示刷新资源或重做决定；不能把数据库 vendor 的 constraint 名、version SQL 或栈帧发给客户端。

## 33. 未知异常映射 500

未知异常说明服务端没有受控公开语义。对外使用固定 type/title/detail/code，避免把缺陷种类变成兼容承诺。

对内必须保存同一个 Throwable 和 cause 链。只记录 `ex.getMessage()` 会丢失类型、堆栈与嵌套原因，令 500 无法定位。

## 34. traceId 是关联键

traceId 让客户端报告与服务器日志、分布式追踪和告警关联。它不是秘密，也不是异常 detail 的替代品。

应由可信入口生成或校验；不可信客户端提供的任意长 header 不能原样进入结构化日志。测试使用固定短值以形成确定性 oracle。

## 35. 服务端保留 cause

包装异常时使用 `new ServiceException("safe context", cause)`，不要只创建新异常消息。日志记录 Throwable 对象，而非字符串拼接。

本章工件用 RecordingFailureReporter 证明 advice 收到原始异常引用及 traceId；真实系统则接入结构化日志和 tracing。

## 36. response 与 log 是两种产品

响应面向不可信远程消费者，采用最少公开信息；日志面向受控运维人员，可含异常类型、堆栈、内部操作和 cause，但仍需脱敏与访问控制。

“不把 SQL 发给客户端”不等于“删除服务器诊断”。正确设计是分层保存，而不是两端都详细或两端都贫血。

## 37. 常见泄露来源

危险内容包括异常全限定类名、stackTrace 数组、SQL 与列名、文件路径、主机名、连接串、token、cookie、Authorization header、个人数据和整段请求体。

使用通用 JSON 序列化 Throwable 尤其危险。即使当前输出看似有限，库升级也可能增加 getter，从而改变公开形状。

## 38. rejected value 也可能敏感

validation 错误常携 rejectedValue。密码、令牌、身份证号或长文本不能直接进入 response/log；普通字段也需长度限制。

错误路径与约束 code 通常足以帮助修正。若必须回显，使用字段允许列表、掩码、截断和上下文安全编码。

## 39. 日志级别按责任选择

预期的 4xx 通常无需 ERROR 堆栈，否则用户输入错误会淹没缺陷告警。未知 500、不可恢复依赖失败和违反内部不变量才需要高等级证据。

但安全拒绝可能需要独立审计。应用错误日志、业务审计和安全审计目的不同，不能用一个 logger 事件替代全部。

## 40. 避免重复记录同一异常

若 repository、service、controller 和 advice 都打印同一堆栈，一次故障会产生四条噪声并增加敏感信息暴露面。

约定由边界层记录一次完整失败；下层仅在真正增加不可恢复上下文时包装 cause。traceId 负责跨层关联。

## 41. 反例：所有结果都返回 200

`return ResponseEntity.ok(problem409)` 让 body 与协议矛盾。前端也许暂时通过读取 code 工作，但监控、重试、缓存和其他消费者都会误判。

修复必须改变 HTTP status，而非只修改 body 文本。测试同时断言 status line 和 body.status，防止一边回归。

## 42. 反例：直接使用 exception.message

异常消息写给开发者，不是稳定公开文案。数据库驱动、JDK 或依赖升级都可能改变它，也可能包含运行数据。

已知异常从受控字段构造安全 detail；未知异常永远使用固定 detail。内部 message 只留在受保护诊断通道。

## 43. 反例：返回 stack trace

堆栈暴露包结构、框架版本、源码位置和调用路径，为攻击者提供侦察信息，也会让错误 body 巨大且不稳定。

即使开发环境想快速查看，也应通过服务器日志、IDE 或 observability 查询；不要让生产 API 合同依赖 profile 才决定是否泄露。

## 44. 反例：吞掉 cause

`catch (SQLException e) { throw new RuntimeException("save failed"); }` 抹掉根因。最终 advice 只能看到模糊包装，数据库错误无法区分。

正确包装保留 cause，并添加稳定内部上下文。客户端仍只得到通用 500，服务端则能沿 cause 链定位第一处可信证据。

## 45. HTTP 与 body 状态一致性

测试读取 `MvcResult.getResponse().getStatus()` 和 JSON `status`，二者必须相等。只对 body 做 snapshot 会漏掉最重要的协议层错误。

代理可能改变状态，因此 RFC 称 body.status 为 advisory；生成端仍有义务先输出一致结果。

## 46. 内容协商边界

ProblemDetail 的默认 JSON 表示是 `application/problem+json`。若客户端只接受不支持的媒体类型，最终仍可能出现 406，而不是原业务问题 body。

错误处理器不应硬写任意 Content-Type 后交给不匹配 converter。真实 API 要对成功和错误表示一起做 Accept 矩阵。

## 47. 正常响应不能被 Advice 改写

ControllerAdvice 只在匹配异常时介入。成功 WorkOrderResponse 应保持原状态、媒体类型和字段，不被包成 `{data,error}` 之类统一外壳。

实验专门发送正常请求，证明全局 advice 的存在没有改变 200 JSON 合同。

## 48. 已提交响应的限制

流式下载、SSE 或已经 flush 的响应若中途失败，服务器不能可靠地重写为完整 ProblemDetail。此时只能关闭流、记录 trace 并由客户端协议处理不完整结果。

不要声称 ControllerAdvice 能捕获所有网络失败。响应提交时点必须在流式接口章节单独设计和测试。

## 49. Filter 与安全链异常

认证、CSRF 或 filter 中发生的异常可能在进入 DispatcherServlet 前处理。Spring Security 有自己的 entry point 和 access-denied handler。

若要统一 Problem Details，应让安全层显式实现相同公开 schema，而不是期待 MVC advice 自动接管。401 与 403 语义也不能互换。

## 50. 校验异常不止一种

单个 `@Valid @RequestBody` 常见 MethodArgumentNotValidException；方法参数约束可能产生 HandlerMethodValidationException。两者携带的访问 API 不同。

项目启用哪条路径就为哪条写映射测试。捕获 `Exception` 后从 message 猜字段不是可维护方案。

## 51. 国际化边界

Spring ErrorResponse 暴露 type、title、detail 的 message code，并可通过 MessageSource 解析。title/detail 可本地化，type/code 不应随 Locale 改变。

若支持 `Accept-Language`，契约测试要区分机器字段稳定与人类文本变化。错误数组的排序也不能依赖翻译后的 detail。

## 52. 兼容性策略

新增可选 extension 通常较温和，但严格客户端可能仍拒绝未知字段；删除或改 type/code、改变字段类型、把 409 改 400 都是潜在破坏。

长期维护应发布问题类型文档与迁移说明。不要为了兼容旧客户端无限返回两套互相矛盾的 code；需要兼容窗口时明确期限、监测和回滚。

## 53. RFC 7807 到 9457

RFC 9457 取代 7807，核心五字段模型保持熟悉，但规范解释与安全建议有更新。新文档和注释应引用 9457。

若既有客户端声称“RFC7807”，先用 wire contract 证明是否真的不兼容；不要仅因编号变化复制一套新 JSON 格式。

## 54. Boot 自动配置与手写 Advice 的兼容

启用 `spring.mvc.problemdetails.enabled` 后，Boot 配置的处理器 order 为 0。自定义 advice 若要接管某些内置异常，需要明确更高优先级且避免重复兜底。

本章工件用 standalone MockMvc 显式注册 advice，证明映射逻辑；它不证明 Boot 完整自动配置顺序，真实应用仍需 slice/integration test。

## 55. 诊断顺序

第一步记录请求方法、路径、Accept、HTTP status、Content-Type 和 traceId；第二步检查 body 的 type/code/status/instance；第三步定位哪个 handler/advice 命中。

只有之后才沿服务器日志的 cause 链向下追。先根据用户看到的 detail 猜数据库问题，容易被脱敏文案误导。

## 56. 找第一处可信证据

若期望 409 却得到 200，先看 MockMvc status 断言和返回 ResponseEntity 的位置；若得到 HTML，先看请求是否落到 `/error` 或内容协商；若得到 500，检查 reporter 中实际 Throwable。

“前端弹窗不对”是症状，不是根因。HTTP 交换、resolved exception 与服务器 cause 才是可复现证据。

## 57. 四类失败矩阵

测试表至少记录：输入、抛出失败、HTTP status、type、title、code、instance、是否含 errors、是否调用业务、是否记录 cause。每行都要有 expected 与 actual。

矩阵外还需一行正常 200，防止 advice 过宽。每种响应扫描禁止字符串，如 `SQLException`、`select`、包名和 `stackTrace`。

## 58. 单元、MVC 与集成测试分工

纯单元测试可验证异常分类和 ProblemDetail factory；standalone MockMvc 验证 advice、converter 和 status/body；Boot 集成测试才证明自动配置、filter、`/error` 与真实 Bean 顺序。

本章使用前两层获得快速证据，并诚实标记未验证的容器路径。不要用一层测试声称覆盖全部生产行为。

## 59. FactoryCare 实验策略

先预测四个请求，再运行 lab。验证错误结构稳定后，注入含 SQL 与内部 token 的 unknown exception，确认响应无泄露而 RecordingFailureReporter 保存原 Throwable。

最后重放正常查询，确认 advice 没有修改成功合同。只有同时满足协议、安全和诊断三类 oracle 才算完成。

## 60. 红灯练习策略

starter 故意把 Conflict ProblemDetail 放进 `ResponseEntity.ok`。两个测试中，安全 body 测试应绿，HTTP/body 一致性测试应以 `EXPECTED_NON_2XX_PROBLEM` 唯一红灯。

修复只应把响应 status 改成 ProblemDetail status，不删除断言、不把 body.status 改成 200，也不在 Controller 中吞异常。

## 61. 120 秒口述模板

先说职责：异常映射把内部失败翻译为 HTTP Problem Details。再说五字段和机器稳定键，然后说明 400/404/409/500 的分类。

最后给反例：将 SQLException message 和 stack 以 200 返回；解释它同时破坏协议、泄密与诊断，并说明 response 白名单与 server cause 日志如何修复。

## 62. 自检问题

为什么 type 比 detail 更适合机器分支？为什么 500 响应不能使用原异常 message？为什么 status line 与 body.status 都要断言？为什么 ControllerAdvice 无法保证处理 filter 或 committed response 的异常？

如果不能用自己的话回答并定位工件中的对应断言，应回到失败矩阵，而不是背诵注解名称。

## 63. 本章边界

本章不实现认证授权、数据库事务、完整日志平台、SSE 中途失败、OpenAPI、国际化资源包或代理可信链。它也不规定领域状态机本身，只翻译已经发生的失败。

这些非目标防止 error advice 变成万能层。授权、业务不变量和持久化仍由各自边界负责。

## 64. 官方主来源

- [Spring Framework 7：MVC Error Responses](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-ann-rest-exceptions.html)
- [Spring Framework 7.0.8：ResponseEntityExceptionHandler Javadoc](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/servlet/mvc/method/annotation/ResponseEntityExceptionHandler.html)
- [Spring Framework 7.0.8：ErrorResponse Javadoc](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/ErrorResponse.html)
- [Spring Boot 4.1：Servlet Error Handling](https://docs.spring.io/spring-boot/reference/web/servlet.html#error-handling)
- [RFC 9457：Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457.html)
