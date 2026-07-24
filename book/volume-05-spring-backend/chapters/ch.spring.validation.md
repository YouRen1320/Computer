---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.validation
title: Bean Validation、字段规则与跨字段规则
responsibility: 教授在 API 边界声明并组合输入不变量，不把校验代替授权、事务或数据库约束
volume: '05'
order: 8
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.validation.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.dto-json-content-negotiation
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
  text: 在 120 秒内解释Bean Validation、字段规则与跨字段规则的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - spring-field-validation
  - spring-cross-field-validation
  covers_topics:
  - spring.bean-validation
  - spring.validation-groups-boundary
  - spring.validation-message
  - spring.cross-field-constraint
  - spring.validation-error-path
  - spring.fail-fast-vs-all
  uses_capabilities:
  - backend.spring-mvc-contract
  - java.io-json
  - java.encapsulation-immutability
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为创建工单 DTO 添加字段与“截止时间晚于创建时间”跨字段约束，输出每个字段的稳定错误路径
  covers_topic_groups:
  - spring-field-validation
  - spring-cross-field-validation
  covers_topics:
  - spring.bean-validation
  - spring.validation-groups-boundary
  - spring.validation-message
  - spring.cross-field-constraint
  - spring.validation-error-path
  - spring.fail-fast-vs-all
  uses_capabilities:
  - backend.spring-mvc-contract
  - java.io-json
  - java.encapsulation-immutability
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入 Controller 忘记触发校验、跨字段校验 null 崩溃和校验组误用，使用非法请求矩阵修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - spring-field-validation
  - spring-cross-field-validation
  covers_topics:
  - spring.bean-validation
  - spring.validation-groups-boundary
  - spring.validation-message
  - spring.cross-field-constraint
  - spring.validation-error-path
  - spring.fail-fast-vs-all
  uses_capabilities:
  - backend.spring-mvc-contract
  - java.io-json
  - java.encapsulation-immutability
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# Bean Validation、字段规则与跨字段规则

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《DTO、JSON、内容协商与兼容边界》](ch.spring.dto-json-content-negotiation.md)：独立完成字段校验、对象级校验前，必须先具备「DTO、JSON、内容协商与兼容边界」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 drafting。正文和工件只提供教材证据，不自动更新 `PROGRESS.md`，也不代表学习者已通过 Week 10。

JSON 能成功转换成 DTO，只说明表示可读，不说明输入符合应用契约。Bean Validation 用声明式约束检查字段和对象关系；Spring MVC 在 `@Valid @RequestBody` 边界触发它，并在调用用例前把非法请求变为 400。

本章工件固定 Spring Boot 4.1.0、其 BOM 管理的 Spring Framework 7.0.8、Jakarta Validation 3.1.1、Hibernate Validator 9.1.0.Final、JDK 25 与 Maven 3.9.16。官方资料复核日期为 2026-07-17。

## 1. 本章完成证据

完成者要能为创建工单 DTO 声明空值、长度、枚举外的数值范围与嵌套约束，并实现“dueAt 晚于 createdAt”的对象级约束。非法请求必须 400、错误路径稳定、用例调用次数为零。

配套工件：

- [字段与对象约束观察台](../../../examples/encyclopedia/ch.spring.validation/README.md)
- [非法请求矩阵实验](../../../labs/encyclopedia/ch.spring.validation/README.md)
- [忘记触发校验练习](../../../exercises/encyclopedia/ch.spring.validation/README.md)

## 2. 什么是 Validation

Validation 检查一个对象是否满足声明的约束集合，并返回零个或多个 `ConstraintViolation`。它不修改对象，也不自动保存数据。

同一 DTO 可能成功反序列化，却因 description 空白、priority 越界或时间关系冲突而无效。绑定和校验是两个阶段。

## 3. 绑定、校验、业务规则分层

绑定回答“这些字节能否构造目标类型”；校验回答“这个输入对象满足 API 形状规则吗”；业务规则回答“当前用户和工单状态下是否允许操作”。

把三者混为一谈会得到错误状态和错误路径。例如 JSON 时间格式错误属于读取失败，截止时间早于创建时间属于对象校验，当前工单不可修改属于领域拒绝。

## 4. Jakarta Validation 是标准 API

Jakarta Validation 3.1 定义约束元数据、`Validator`、`ConstraintViolation`、级联、组和自定义约束接口。包名是 `jakarta.validation.*`，不是旧的 `javax.validation.*`。

标准允许替换 provider。不要依赖 provider 扩展的额外类型支持，除非明确记录并测试可移植性边界。

## 5. Hibernate Validator 是实现

Boot 4.1 的 validation starter 提供 Jakarta API 与 Hibernate Validator 9.1 provider，并准备表达式语言等运行依赖。API 与实现版本不能混为一谈。

没有 provider 时注解仍能编译，却无法实际执行校验。依赖树和一次真实 `Validator.validate` 是必要证据。

## 6. Validator 合同

`Validator` 的实现要求线程安全，可作为共享 Bean 注入。`validate(object)` 返回 Set，空集合表示本次组下无违反项。

不要每个请求重新构建 ValidatorFactory；Boot/Spring 的 `LocalValidatorFactoryBean` 负责 provider 启动、Spring 适配和生命周期。

## 7. 字段约束是局部规则

`@NotNull`、`@NotBlank`、`@Size`、`@Min`、`@Max`、`@Positive`、`@Pattern` 等适合单个值可判断的规则。约束应放在 API DTO 的公开契约位置。

“资产必须存在于数据库”不是字段约束；它需要外部查询、授权和事务一致性，不应塞入普通 validator。

## 8. NotNull、NotEmpty、NotBlank

`@NotNull` 只拒绝 null；`@NotEmpty` 还拒绝长度为零；`@NotBlank` 针对字符序列，拒绝 null、空串和只有空白。

FactoryCare description 使用 `@NotBlank`，因为空白文本没有业务意义。不要用 `@NotNull` 后假定空串已被拒绝。

## 9. Size 不默认拒绝 null

多数尺寸、范围类约束把 null 视为有效，让 `@NotNull` 单独决定是否必填。因此 `@Size(min=5)` 可能不拒绝 null。

组合约束时要测试缺失、null、空、边界内和边界外。只测一个短字符串不足以证明 required 语义。

## 10. primitive 不能表达缺失

请求 DTO 用 primitive `int` 时，缺失可能被映射为 0，`@NotNull` 无法作用。需要区分缺失与零时使用 `Integer`，然后组合 `@NotNull` 与范围约束。

类型选择是合同的一部分，不是为了多写或少写注解。默认值应在明确阶段应用，而非由 primitive 悄悄补齐。

## 11. 边界值要成对验证

`@Size(min=5,max=500)` 至少测 4、5、500、501；`@Min(1) @Max(5)` 测 0、1、5、6。边界测试能抓住 inclusive/exclusive 误解。

错误消息不是唯一 oracle。约束类型、字段路径和是否触达用例更稳定。

## 12. @Valid 触发级联

`@Valid` 表示级联验证对象、参数或返回值。MVC 请求体参数写成 `@Valid @RequestBody CreateWorkOrderRequest request`，才会在解析后执行 DTO 约束。

DTO 内嵌对象也需要在属性上加 `@Valid`；只在嵌套类型定义约束但不级联，内部错误不会被发现。

## 13. @Validated 的角色

Spring 的 `@Validated` 支持声明 Validation groups，并可标记需要方法校验的类型。它与 Jakarta `@Valid` 有重叠但不完全相同。

普通 MVC request DTO 先使用 `@Valid` 和 Default 组，减少意外组过滤。需要组时必须用测试说明选择原因。

## 14. MVC 请求体校验时点

MVC 先用 HttpMessageConverter 构造 DTO，再校验，最后才调用 Controller 方法。DTO 无法解析时不是 ConstraintViolation，而是 message not readable。

校验失败默认产生 `MethodArgumentNotValidException` 并映射为 400。测试可从 resolved exception 的 `BindingResult` 读取字段错误路径。

## 15. 方法校验异常可能不同

当 handler 方法的其他参数本身带 `@Constraint`，Framework 7 的内置方法校验可能产生 `HandlerMethodValidationException`。它与单个 `@Valid @RequestBody` 的异常形态不同。

错误映射层要覆盖项目实际使用的两种路径；本章资产聚焦 request DTO，下一章再统一 Problem Details。

## 16. ConstraintViolation 的证据

每个 violation 含 root bean、invalid value、constraint descriptor、property path 和 message。不要把整个对象或敏感 invalid value直接写日志。

诊断先看约束注解类型与 property path，再看消息模板。默认消息可能本地化，不能作为唯一机器合同。

## 17. property path

字段约束通常产生 `description`、`priority` 等路径；嵌套对象可能是 `asset.location.code`；集合元素可带索引或 key 节点。

稳定错误响应应公开 API 字段路径，不暴露 Java 内部类名。字段改名时，错误路径也是兼容合同的一部分。

## 18. 错误消息与错误码

人类消息应可本地化，机器客户端更适合稳定 code、path 和约束参数。默认英文或中文文本会随 provider、Locale 和版本变化。

本章测试断言路径和 constraint annotation，不锁定完整默认句子。下一章定义统一错误 DTO。

## 19. 消息插值

约束 `message` 可以是模板键，例如 `{factorycare.description.required}`，由 MessageSource/ValidationMessages 解析。模板参数可引用 min/max 等注解属性。

不要把数据库内容或秘密拼入消息。用户可见值需要转义，日志与响应的详细程度也不同。

## 20. 多错误策略

默认 Bean Validation 通常收集所有可发现 violation，让客户端一次修多处。fail-fast 在首个错误停止，延迟更低但客户端需多轮提交。

策略必须固定并测试。本章选择 collect-all，并按 path 与 code 排序后用于报告，避免 Set 遍历顺序成为 API。

## 21. 违反项顺序不保证

`Validator.validate` 返回 Set，约束执行顺序不是稳定合同。同一对象的多个错误在升级 provider 后可能换序。

若响应是数组，应用映射层应按稳定键排序。测试比较集合或规范化列表，不比较偶然迭代顺序。

## 22. fail-fast 的边界

Hibernate Validator 可配置 fail-fast，但这是 provider 特性和全局策略，不应由单个 Controller 随意切换。

安全检查不能依赖“哪个约束先执行”。任何错误都应阻止用例，授权仍在业务入口独立执行。

## 23. 嵌套对象级联

若创建请求含 `AssetReference asset`，外层组件必须标 `@Valid @NotNull`。`@NotNull` 拒绝整个对象缺失，`@Valid` 才检查内部 `assetId`。

两者解决不同问题。测试需要外层 null 和内部字段无效两个 case。

## 24. 容器元素约束

可对 `List<@NotBlank String> tags` 的元素施加约束，并对集合本身加 `@Size(max=10)`。路径应指出元素位置。

限制集合长度不仅是业务体验，也是资源消耗防护。仍需在服务器/解析层限制原始 body 大小，避免在校验前耗尽资源。

## 25. 跨字段规则需要对象级约束

“dueAt 必须晚于 createdAt”同时依赖两个字段，不适合把一个字段 validator 偷偷读取另一个字段。类级约束显式说明对象关系。

注解放在 DTO 类型上，validator 接收整个 DTO。错误路径仍应尽量落到调用者可修改的字段，如 `dueAt`。

## 26. 自定义约束的两部分

自定义约束由 `@Constraint(validatedBy=...)` 注解与 `ConstraintValidator<A,T>` 实现组成。注解还需标准的 `message`、`groups`、`payload` 成员。

Target、Retention 和 Documented 设置错误会让约束无法应用或运行期不可见。工件通过真实 Validator 验证元数据。

## 27. null-safe validator

跨字段 validator 应先处理对象或参与字段为 null。字段 required 约束负责缺失；对象级 validator在前置值不全时通常返回 true，避免 NPE 和重复噪声。

不要假设字段约束必先执行。规范不承诺这种顺序，null-safe 是独立正确性要求。

## 28. 截止时间示例

规则是两个时间都非 null 时 `dueAt.isAfter(createdAt)`。等于也无效，早于无效，晚于有效。

时间解析失败发生在 JSON 读取阶段；解析成功但关系错误才进入对象级 validator。测试分开两类。

## 29. 把类级错误放到字段路径

默认类级 violation 路径为空或对象级，客户端不知道改哪个字段。validator 可禁用默认 violation，再通过 context 添加 `dueAt` property node。

这样跨字段错误仍由类级逻辑计算，却向 API 暴露稳定可操作路径。

## 30. 不要在 validator 访问数据库

查资产是否存在、用户名是否唯一会引入网络、事务和竞态。即使校验时存在，保存前也可能变化；失败还难以区分 400 与服务故障。

外部事实在应用服务/领域层检查，并由数据库约束最终保护。validator 保持纯、快速、确定。

## 31. Validation groups

groups 允许同一类型在不同场景启用不同约束。调用 `validate(obj, Create.class)` 时，未包含该组的约束不会执行。

它很强也很危险：忘记 Default 或选错组会让 required 规则静默消失。组不是继承业务工作流的通用状态机。

## 32. 优先用不同 DTO 表达不同用例

创建与更新若字段语义明显不同，独立 `CreateWorkOrderRequest` 和 `UpdateWorkOrderRequest` 通常比复杂 groups 更易读、更安全。

groups 适合形状高度一致且差异有限的场景。不要为了减少类数量制造难以推断的条件约束网。

## 33. GroupSequence

组序列可要求一组成功后再验证下一组，适合昂贵规则延后。但它使执行模型更复杂，并可能改变报告的错误集合。

本章不把序列作为默认。若使用，必须有阶段、错误数量和失败停止点测试。

## 34. 组转换

级联属性可以把外层组转换为嵌套对象组。它解决复用模型的特定场景，却让约束启用路径更隐蔽。

API DTO 优先保持简单 Default 组和独立类型。组转换需要架构说明，不应随手加在字段上。

## 35. Spring 方法校验

服务方法参数/返回值可通过方法校验检查，在普通 Spring Bean 上通常依赖 `@Validated` 与代理。MVC 在 Framework 7 对 handler 有内置方法校验支持。

DTO 边界校验与服务方法校验不是自动重复保险；应决定哪个入口负责什么，避免同一错误以不同异常出现。

## 36. 代理与 self-invocation

传统 Spring 方法校验若依赖 AOP 代理，同类内部调用可能绕过代理。对象直接 `new` 出来也不受 Spring 后处理。

因此不能用一次外部调用测试推断所有路径。关键领域不变量应由对象自身维护，不仅靠代理校验。

## 37. 非法请求不得触达用例

FactoryCare fake use case 用计数器记录调用。合法请求计数加一；任意字段或跨字段违反时保持零。

这是比“返回 400”更强的 oracle，证明没有数据库写入、事件发布或审计副作用发生。

## 38. Validation 不等于授权

`@NotBlank tenantId` 只证明字符串非空，不能证明租户存在或调用者属于该租户。角色、资源所有权和数据范围必须由安全与应用层检查。

把 `@Pattern("ADMIN")` 当授权是严重错误，攻击者可以发送匹配文本。

## 39. Validation 不替代领域不变量

Controller 之外的消息消费者、批处理和测试也能调用应用服务。若“关闭工单必须已解决”只写 DTO validator，其他入口可绕过。

DTO validation 拒绝明显无效入站数据；领域对象仍要在所有入口维护核心状态规则。

## 40. Validation 不替代数据库约束

非空、唯一、外键和检查约束在并发写入时仍需数据库保护。API 校验提供友好早失败，数据库保护最终事实。

两层规则应语义一致，但错误映射不同。数据库失败不能伪装为 DTO validation 证据。

## 41. 事务与竞态

“名称当前唯一”的预检查后，另一个事务可能插入同名值。只有事务内写入与唯一约束能解决竞态。

不要让远程 validator 持有长事务。边界检查、领域决策和持久化约束各在合适层工作。

## 42. FactoryCare 创建 DTO

示例字段：`assetId @NotBlank`、`description @NotBlank @Size(max=500)`、`priority @NotNull`、`createdAt @NotNull`、`dueAt @NotNull`，类型上加 `@ChronologicalDeadline`。

DTO 不含服务端 id、status、internalCost。校验规则不做数据库实体映射。

## 43. MVC Controller 触发校验

端点声明 `@Valid @RequestBody`，合法请求调用 `CreateWorkOrderUseCase` 并返回 201。忘记 `@Valid` 时 JSON 仍能构造 DTO，非法值会进入用例。

练习用哨兵 `EXPECTED_VALIDATION_BEFORE_USE_CASE` 证明这类静默故障，而非只看 response body。

## 44. 在测试中读取错误路径

MockMvc 返回 400 后，从 `MvcResult.getResolvedException()` 取得 `MethodArgumentNotValidException`，读取 BindingResult 的 FieldError。

这样本章能验证 `description` 和 `dueAt` 路径，却不提前实现下一章的全局 Problem Details 响应。

## 45. 直接 Validator 测试

自定义约束应先用 `Validator.validate` 快速测试：晚于有效、等于/早于产生 dueAt violation、任一时间 null 不抛异常且由字段约束报告。

随后再用 MockMvc 证明 MVC 触发点。两层测试分别定位约束逻辑与 Web 集成。

## 46. 合法请求矩阵

使用固定 UTC 时间，description 在长度范围，priority 为已知 enum，dueAt 晚于 createdAt。断言 201、用例一次、接收值与输入一致。

不要依赖当前时钟，否则午夜、时区或运行延迟会让测试不稳定。

## 47. 字段非法矩阵

至少包含 assetId 空白、description null/空白/过长、priority null、时间缺失。每个 case 断言 400、准确 path、用例零调用。

一次只改变一个字段便于定位；另有一个多错误 case 验证 collect-all 策略。

## 48. 跨字段非法矩阵

dueAt 等于 createdAt 与早于 createdAt 都应 400，path 为 dueAt。任一字段 null 时 validator 不崩溃，字段 `@NotNull` 独立报告。

这个矩阵防止常见的 NPE 和“相等被误认为晚于”边界错误。

## 49. 多错误排序

创建多个违反后，收集 path 与约束 code，按 path/code 排序再比较。不要依赖 provider Set 顺序。

如果产品选择 fail-fast，oracle 应明确只有一个错误且不承诺是哪一个，或用 group sequence 明确顺序；不能含糊。

## 50. 故障：忘记 @Valid

症状是非法 DTO 仍返回 201、用例计数增加，而直接 Validator 测试却能找到错误。第一处可信证据是 Controller 参数缺少触发注解。

修复后重跑合法和非法请求，确认不是把所有请求都挡住。不要在用例里临时手工调用 Validator来掩盖 Web 边界遗漏。

## 51. 故障：跨字段 null 崩溃

validator 直接调用 `request.dueAt().isAfter(...)`，任一字段 null 就 NPE，响应可能变成 500。字段约束执行顺序不能保护它。

修复为前置值不全时跳过关系判断，让 `@NotNull` 产生准确字段错误，再重跑 null 与正常关系 case。

## 52. 故障：组误用

约束只属于 Default，但 Controller 写 `@Validated(Create.class)`，或反之，可能让必填规则不执行。先打印/检查 constraint descriptor groups 和实际验证组。

优先回到独立 DTO + Default；若确需组，所有入口必须显式测试组矩阵。

## 53. 独立构建任务

实现 DTO、标准字段约束、`@ChronologicalDeadline` 与 validator，并写直接 Validator/MockMvc 两层矩阵。错误报告至少包含稳定 path 和 constraint code。

先预测每个非法输入在哪个阶段失败、用例是否被调用，再运行测试。

## 54. 修改任务

把 description 最大长度从 500 改为 300，并增加 `tags` 最多十个且元素非空白。先列出 299/300/301、空集合、十一项、空白元素路径，再修改。

不引入数据库存在性校验或最终错误 DTO；它们属于后续层。

## 55. 诊断顺序

确认 JSON 是否成功绑定；确认 Controller 参数有 `@Valid`/正确组；直接运行 Validator；检查约束 null 语义和 Target；读取 violation path/type；确认跨字段是否添加 dueAt node；查看用例计数；最后核对 400。

修复后重跑原失败、合法 case、null case和多错误 case，避免局部修复制造新漏网。

## 56. 有意不做与兼容边界

本章不实现授权、数据库查询/约束、事务、领域状态机或全局 Problem Details。采用 collect-all 与 Default 组作为教学合同，不为复杂旧 groups 保留兼容层。

若真实 API 改约束强度，旧请求可能变得无效，必须评估消费者、灰度、指标与回滚；增加注解不天然兼容。

## 57. 一手资料

- [Jakarta Validation 3.1 Specification](https://jakarta.ee/specifications/bean-validation/3.1/)
- [Jakarta Validation 3.1 Validator API](https://jakarta.ee/specifications/bean-validation/3.1/apidocs/jakarta/validation/validator)
- [Spring Framework 7：Java Bean Validation](https://docs.spring.io/spring-framework/reference/core/validation/beanvalidation.html)
- [Spring Framework 7：MVC Validation](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller/ann-validation.html)
- [Spring Framework 7：RequestBody](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller/ann-methods/requestbody.html)
- [Hibernate Validator 9.1 Reference](https://docs.jboss.org/hibernate/validator/9.1/reference/en-US/html_single/)
