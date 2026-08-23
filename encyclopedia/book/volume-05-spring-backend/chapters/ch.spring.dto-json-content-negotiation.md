---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.dto-json-content-negotiation
title: DTO、JSON、内容协商与兼容边界
responsibility: 教授 API DTO 与领域对象分离及媒体类型协商，不在本章定义校验规则或数据库实体映射
volume: '05'
order: 7
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.dto-json-content-negotiation.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.mvc-routing-binding
- ch.java-engineering.json-mapping
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
  text: 在 120 秒内解释DTO、JSON、内容协商与兼容边界的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - spring-dto-json
  - spring-content-negotiation
  covers_topics:
  - spring.request-response-dto
  - spring.domain-dto-boundary
  - spring.json-field-contract
  - spring.media-type
  - spring.content-negotiation
  - spring.dto-compatible-change
  uses_capabilities:
  - backend.spring-mvc-contract
  - java.io-json
  - java.encapsulation-immutability
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：定义 CreateWorkOrderRequest 与 WorkOrderResponse DTO，验证 JSON 字段、枚举、缺失/null 及 Accept/Content-Type 协商，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - spring-dto-json
  - spring-content-negotiation
  covers_topics:
  - spring.request-response-dto
  - spring.domain-dto-boundary
  - spring.json-field-contract
  - spring.media-type
  - spring.content-negotiation
  - spring.dto-compatible-change
  uses_capabilities:
  - backend.spring-mvc-contract
  - java.io-json
  - java.encapsulation-immutability
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入直接序列化领域对象、字段改名破坏兼容和不支持媒体类型仍200，比较 wire JSON 后修复
  covers_topic_groups:
  - spring-dto-json
  - spring-content-negotiation
  covers_topics:
  - spring.request-response-dto
  - spring.domain-dto-boundary
  - spring.json-field-contract
  - spring.media-type
  - spring.content-negotiation
  - spring.dto-compatible-change
  uses_capabilities:
  - backend.spring-mvc-contract
  - java.io-json
  - java.encapsulation-immutability
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# DTO、JSON、内容协商与兼容边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Controller、路由、参数绑定与状态码》](ch.spring.mvc-routing-binding.md)：独立完成DTO 与 JSON、内容协商与兼容前，必须先具备「Controller、路由、参数绑定与状态码」已经验证的知识与失败边界
- [《JSON 数据边界、对象映射与未知字段处理》](../../volume-03-java-engineering/chapters/ch.java-engineering.json-mapping.md)：独立完成DTO 与 JSON、内容协商与兼容前，必须先具备「JSON 数据边界、对象映射与未知字段处理」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 drafting。正文和工件是教材证据，不自动更新 `PROGRESS.md`，也不代表学习者已通过 Week 10。

Controller 不应把领域对象直接暴露到网络。API 需要独立 DTO 来固定允许输入、输出字段和媒体类型；Spring MVC 再根据 `Content-Type` 与 `Accept` 选择消息转换器，把 JSON 字节和 Java DTO 相互转换。

本章工件固定 Spring Boot 4.1.0、其 BOM 管理的 Spring Framework 7.0.8、Jackson 3.1.2、JDK 25 与 Maven 3.9.16。Framework 7 当前 JSON converter 使用 `tools.jackson` 的 Jackson 3 API。官方资料复核日期为 2026-07-17。

## 1. 本章完成证据

完成者要能写出 `CreateWorkOrderRequest` 与 `WorkOrderResponse` 的 wire JSON，预测缺失、显式 null、枚举值和未知字段如何进入 Java，并用 MockMvc 证明 `application/json` 成功、错误 `Content-Type` 为 415、不可接受的 `Accept` 为 406。

配套工件：

- [DTO 与内容协商观察台](../../../examples/encyclopedia/ch.spring.dto-json-content-negotiation/README.md)
- [JSON 合同与泄露边界实验](../../../labs/encyclopedia/ch.spring.dto-json-content-negotiation/README.md)
- [领域字段泄露练习](../../../exercises/encyclopedia/ch.spring.dto-json-content-negotiation/README.md)

## 2. DTO 是边界对象

DTO（Data Transfer Object）描述一次跨边界传输的数据形状。API DTO 的字段名、类型、是否可缺失和媒体类型属于客户端合同，不等于数据库列或领域对象全部状态。

DTO 可以是 record，因为它天然表达构造后不可变的数据载体。但“用了 record”不会自动获得兼容性；record 组件仍是 wire 字段候选，需要明确审查。

## 3. wire contract 才是客户端看到的事实

Java 类名、getter 和注解只是实现手段，客户端看到的是字节、`Content-Type` 和 JSON 字段。判断兼容性时要比较真实 wire JSON，而不是只比较 Java diff。

例如把 `description` getter 重命名为 `problemDescription` 可能悄悄改掉 JSON 字段。测试必须断言字段集合与值，不能只断言反序列化后的对象“看起来对”。

## 4. 请求 DTO 与响应 DTO 分开

创建请求表达调用者允许提交的内容；响应表达服务承诺公开的结果。二者即使当前字段相似，也有不同演进方向。

客户端不能在创建时指定服务端生成 id、审计时间或内部状态。复用一个 `WorkOrderDto` 会逐渐让只读字段变成可写输入，形成 mass assignment 风险。

## 5. DTO 与领域对象分开

领域对象维护业务不变量和行为，可能包含内部 owner、成本、审计标记和延迟加载关系。DTO 只承载本端点批准的表示。

Controller 或 mapper 显式执行 `request -> command/domain` 与 `domain -> response`。这段映射不是无意义样板，它是安全与兼容审查点。

## 6. 不直接序列化领域对象

直接返回领域对象会让新增 getter 自动变成 API 字段，也可能遍历双向关系、触发懒加载或泄露内部秘密。一次领域重构会无意成为破坏性 API 变更。

稳定做法是响应 DTO 白名单。领域新增字段默认不可见，只有修改 mapper 和契约测试后才能公开。

## 7. FactoryCare 的最小 DTO

创建请求可含 `assetId`、`description`、`priority`；响应含 `id`、上述公开字段和 `status`。内部字段 `internalCost`、`assigneeToken` 不应出现在任何 API JSON。

请求和响应使用不同 record，即使名字相似也不互相继承。API DTO 不映射数据库实体注解，本章也不定义校验规则。

## 8. JSON 的值模型

JSON 只有 object、array、string、number、boolean 和 null。Java 的 record、enum、`Instant`、`BigDecimal` 都需要定义如何映射到这些值。

JSON 没有 Java `long` 与 `double` 类型标签，也没有日期类型。不要把 JVM 类型细节误当 wire 自描述能力。

## 9. Boot 4.1 与 Jackson 3

Spring Framework 7 的 `JacksonJsonHttpMessageConverter` 使用 Jackson 3 `JsonMapper`，依赖坐标在 `tools.jackson` 命名空间。旧 Jackson 2 常见的 `com.fasterxml.jackson.databind.ObjectMapper` 示例不能直接当 Boot 4.1 主线代码。

Boot 仍可能为迁移生态管理部分 Jackson 2 坐标，但本章 MVC JSON 路径明确使用 Jackson 3。升级时先检查实际 converter 和依赖树，不混用两代注解/mapper。

## 10. HttpMessageConverter

`HttpMessageConverter` 负责从请求输入流读取目标 Java 类型，或把返回值写入响应输出流。转换器按 Java 类型和媒体类型声明 `canRead`、`canWrite`。

JSON、String、byte array 和 form 各有不同 converter。存在 Jackson jar 只表示 JSON converter 有机会注册，不代表任何媒体类型都能被当 JSON。

## 11. 请求读取流水线

请求先命中带 `consumes` 的 handler，再根据 `Content-Type` 找能读取目标 DTO 的 converter，解析 JSON 并构造对象。语法错误、类型不匹配或缺 converter 都发生在 Controller 调用前。

因此断点没进入方法时，要先看 status、resolved exception、媒体类型和原始 body，不要立刻怀疑业务服务。

## 12. 响应写出流水线

Controller 返回响应 DTO 后，MVC 根据 handler 的 `produces`、请求 `Accept` 和可写 converter 选择表示，并设置 `Content-Type`。找不到共同媒体类型时不是“返回空 body”，而是协商失败。

序列化错误可能在 Controller 已执行后发生。需要区分用例成功与响应写出失败，避免把半成功当完整 2xx。

## 13. Content-Type 描述请求实体

请求 `Content-Type: application/json` 声明 body 的表示格式。它不描述客户端想收到什么，也不因 body 长得像 JSON 就可以省略所有合同。

端点声明 `consumes=application/json` 时，发送 `text/plain` 应得 415 Unsupported Media Type。服务不应猜测并继续 200。

## 14. Accept 描述可接受响应

`Accept` 是客户端对响应媒体类型的偏好和约束。`Accept: application/json` 与 JSON `produces` 相交可成功；只接受 `application/xml` 而服务不产出 XML，应得 406 Not Acceptable。

缺少 Accept 通常等同允许广泛类型，但具体选择仍由 handler 与 converter 决定。测试要固定本项目依赖的行为。

## 15. consumes 是入站映射条件

`@PostMapping(consumes=MediaType.APPLICATION_JSON_VALUE)` 在选择 handler 时限制请求媒体类型。它使合同在路由元数据可见，并让 415 在业务调用前出现。

不要把所有类型接进 Controller 再手写字符串判断。那会绕开 converter、错误分类和文档生成能力。

## 16. produces 是出站映射条件

`produces=application/json` 声明 handler 能提供 JSON，并参与 Accept 匹配。它不是单纯强制写一个 header；还要求存在能序列化返回类型的 converter。

若返回 String，String converter 与 JSON converter 的选择可能不同。API 应返回明确 DTO，并通过真实 response header 与 body 证明结果。

## 17. 415 的含义

415 表示服务知道目标资源与 method，但请求实体的媒体类型不受支持。它与 JSON 语法错误不同：后者 Content-Type 可接受，但内容不可读，通常是 400。

测试至少分别发送 `text/plain` 和畸形 `application/json`，证明两种失败没有被统一成 200 或错误业务调用。

## 18. 406 的含义

406 表示请求路由可处理，但无法生成客户端 Accept 接受的表示。它不是资源不存在，也不是服务端一定崩溃。

若业务已执行后才发现不可写表示，可能产生不必要副作用。MVC 会尽量在 handler 选择阶段用 `produces` 过滤，因此声明媒体类型是重要合同。

## 19. 默认只看 Accept header

Framework 7 的 MVC 内容协商默认只检查 Accept header。通过 `.json` 路径扩展猜媒体类型不是当前默认主线，也会增加 RFD 等安全风险。

若业务确实需要 URL 参数策略，应显式配置并测试；优先 query 参数而非路径扩展。不要依赖旧教程的隐式 suffix matching。

## 20. MediaType 不只是字符串

媒体类型由 type/subtype 与参数组成，例如 `application/json`、`application/problem+json`、`text/plain;charset=UTF-8`。匹配还涉及通配符和质量因子。

不要用 `header.equals("application/json")` 实现协商。Spring 的 `MediaType` 解析和比较已处理标准语义。

## 21. JSON 字段是公开名字

字段采用稳定、文档化命名，例如 `assetId`。Java 重构可以保留 wire 名；wire 改名则需要兼容和迁移决策。

大小写、连字符与下划线不是自动等价。客户端按实际字段解析，服务端宽松读取也不能证明响应兼容。

## 22. 显式字段映射

Jackson 注解可把 Java 组件映射到指定 JSON 名，但应谨慎使用：

```java
record WorkOrderResponse(
        @JsonProperty("id") long id,
        @JsonProperty("assetId") String assetId,
        @JsonProperty("status") Status status) {}
```

显式注解保护 wire 名，但大量注解会把 DTO 与特定库绑定。对 API 边界这通常可接受，对领域对象则不应扩散。

## 23. 缺失与显式 null 不相同

缺失表示客户端没有发送键；null 表示发送了键但值为空。Java reference 组件若都变成 null，会丢失二者差异。

创建语义必须决定是否区分。需要三态时使用专门 patch 类型或读取树模型，不要假设 Optional 自动保留缺失/null。

## 24. primitive 会吞掉缺失信息

请求 DTO 使用 `int retryCount` 时，缺失字段可能得到 0，与客户端显式发送 0 无法区分。若缺失需要独立处理，应使用 `Integer` 或专用表示。

这不是要求所有字段都用 wrapper；应根据合同选择。下一章的 `@NotNull` 也只能作用于能表达 null 的类型。

## 25. enum 是封闭 wire 集合

把 `Priority` 作为 JSON 字符串可读，但新枚举值对旧客户端可能是破坏性变更。客户端若反序列化成封闭 enum，看到未知值会失败。

输出新增 enum 值前要检查消费者容错。内部枚举可以比外部更丰富，由 mapper 映射为稳定 API 枚举。

## 26. enum 大小写与拼写

默认 mapper 通常按精确名称解析。`HIGH`、`high` 和 `High` 不应靠猜测混为一谈，除非合同明确启用大小写不敏感并有测试。

错误枚举值是可读 JSON，但不能构造目标 DTO，通常返回 400。它不同于 Bean Validation 字段规则失败。

## 27. 未知字段策略

忽略未知请求字段有利于服务端增加客户端先行字段或滚动部署，但也可能掩盖拼写错误；严格拒绝更早暴露错误，却降低前向兼容。

必须按端点和演进策略明确选择。本章实验使用严格 mapper，让 `descriptin` 立即红灯，并在兼容章节说明何时可选择宽松读取。

## 28. 重复键与解析器差异

JSON object 出现重复键时，不同解析器可能保留首个、末个或拒绝。安全敏感字段若重复，会造成网关与应用理解不一致。

边界应拒绝含糊输入或在统一解析链固定策略。不要用 Map 手工解析后再让 Jackson 解析一次。

## 29. 日期时间使用标准文本

时间没有原生 JSON 类型。API 应采用明确 ISO-8601 表示并说明是否含时区/offset，例如 `2026-07-17T10:30:00Z`。

不要把本地时区默认或 epoch 单位藏在 mapper 全局配置。`Instant`、`OffsetDateTime` 与 `LocalDateTime` 语义不同。

## 30. 金额避免二进制浮点

维修成本等十进制值应使用 `BigDecimal` 并明确 scale/货币语义，而非 double。JSON number 本身不保证消费者使用相同精度。

金额合同往往使用字符串或 number 加 currency 字段；选择需跨语言验证。本章不公开内部成本字段。

## 31. 标识符的 JSON 类型

数据库 long id 可作为 JSON number，但 JavaScript 对超大整数有精度边界。公开标识若可能超过安全范围，可使用字符串表示。

一旦发布 number 改 string 属于 wire 类型变更。FactoryCare 教学 id 规模固定为 long 范围示例，不推断生产策略。

## 32. 响应 null 策略

输出 null 字段与省略字段对客户端可能不同。省略可减少体积，却会让“未知”“不适用”“未加载”难以区分。

不要全局开启 `NON_NULL` 后假定兼容。每个字段的可选语义、默认和消费者行为需要契约测试。

## 33. Mapper 是共享基础设施

Boot 提供统一 JSON mapper 与 converter。Controller 不应每次 `new JsonMapper()`，否则日期模块、未知字段和命名策略会在端点间漂移。

自定义应集中、最小且可测试。替换整个 mapper 会丢失 Boot 注册模块，优先使用当前 Boot 提供的定制机制或明确 converter。

## 34. Jackson 3 API 边界

Jackson 3 的 mapper 主要位于 `tools.jackson.databind`，许多注解仍需根据实际版本确认包。不要把 Jackson 2 复制代码在编译前当成事实。

工件直接编译并运行 `JsonMapper` round-trip，以依赖树和测试证明使用的 API。版本升级时先修编译，再比较 wire 快照。

## 35. request 到 command 的映射

Controller 收到 DTO 后构造应用命令，只传允许字段。例如客户端 `priority` 映射到领域策略接受的枚举，服务端生成 id 和初始状态。

mapper 不执行数据库写入，也不静默补授权。转换失败应在进入用例前成为 4xx。

## 36. domain 到 response 的映射

响应 mapper 从领域对象白名单选择 `id`、`assetId`、公开描述、priority、status。内部成本和 token 没有输出路径，因此领域新增 getter 不会泄露。

映射可手写或生成，但契约测试必须验证最终 JSON。代码生成器不会替你决定哪些字段应公开。

## 37. Round-trip 的意义

DTO 序列化再反序列化应在定义范围内保持值，能发现字段名、enum 和模块配置漂移。它是 mapper 层快速 oracle。

Round-trip 不能证明媒体协商，也可能让同一个错误读写配置互相抵消。因此还需要固定 wire JSON 和 MockMvc 请求响应测试。

## 38. 固定 wire JSON 测试

测试应解析 JSON tree 后断言字段集合和值，避免仅靠字符串字段顺序。JSON object 顺序通常不是合同，空格更不是。

若确需黄金文件，要规范化后比较并审查每次变更。不要把测试更新当作自动批准兼容破坏。

## 39. MockMvc 的协商证据

MockMvc 能通过真实 MVC converter 链发送 JSON，断言 status、response `Content-Type` 和 body。它比直接调用 JsonMapper 多证明了 handler 的 consumes/produces 配置。

它仍不证明真实代理重写 Accept 或生产容器字节限制。测试主张应保持在进程内 MVC 边界。

## 40. 415 测试必须确认用例未调用

发送 `text/plain` 到只 consumes JSON 的创建端点，断言 415，并确认 fake service 调用次数为零。否则可能是 Controller 手工返回 415，副作用已经发生。

同样，畸形 JSON 应 400 且不触达用例。输入解析是副作用之前的门。

## 41. 406 测试必须检查 Accept

请求只接受 XML，而端点只 produces JSON，应得到 406。测试不要只断言 body 为空；status 和用例调用时点都要记录。

GET 查询无副作用时业务可能已执行，但协议仍失败。写操作应通过 produces 条件尽早排除不可响应请求。

## 42. 领域字段泄露测试

构造含 `internalCost` 和 `assigneeToken` 的领域对象，经 response mapper 和 MVC 输出后，解析 JSON 字段集合，明确断言二者不存在。

负向断言很重要：只检查公开字段存在，无法发现额外敏感字段。字段白名单应成为安全回归测试。

## 43. 兼容新增响应字段

对能忽略未知字段的客户端，新增可选响应字段通常向后兼容；对严格 schema 或封闭 DTO 客户端则未必。兼容性是消费者与合同共同属性。

发布前应用真实客户端或契约样本验证，不用“JSON 天生可扩展”替代证据。

## 44. 改名、删除和改类型

删除字段、把 number 改 string、改变 null/缺失语义或重命名通常是破坏性变更。即便 Java 编译通过，旧客户端仍可能失败。

迁移可短期同时输出旧新字段、记录旧字段使用、给出截止日期再删除。双字段是有成本的兼容选项，不应永久默认。

## 45. 请求新增字段的兼容性

新增可选请求字段对旧客户端通常安全；改为 required 会让旧请求失败。服务端从忽略未知改为严格也可能破坏先行客户端。

每次演进要分别分析旧客户端到新服务、新客户端到旧服务两条方向，而不是只说“向后兼容”。

## 46. 宽松读取、严格写出

常见策略是读取兼容别名或忽略未知，写出单一规范形状。这样迁移期接受旧输入，却不继续扩散旧表示。

宽松不能无限期吞拼写错误。别名应有监控、弃用日期与移除测试；关键字段重复或冲突必须拒绝。

## 47. API 版本不是第一反应

小型兼容新增无需复制整个 `/v2`。版本适合无法在同一合同下安全演进的重大变化，并需要并行维护与迁移计划。

先定义消费者、变更类型和兼容窗口，再选择字段迁移、媒体类型版本或路径版本。不要用版本号掩盖无管理的 DTO 漂移。

## 48. 反序列化安全

不要对不可信 JSON 开启任意多态类型信息，让客户端选择类名。DTO 应是封闭白名单，限制 body 大小、嵌套和集合数量。

JSON parser 防止语法错误，不负责授权。客户端提交 `assigneeId` 即使能绑定，也必须由用例层检查权限或根本不放进创建 DTO。

## 49. Mass assignment

直接把请求绑定到实体会让新增可写属性意外暴露，例如 `status=CLOSED` 或 `internalCost=0`。攻击者不需要字段出现在前端表单，只需构造 JSON。

独立请求 DTO 的字段白名单是第一层防护；业务授权和不变量仍需后续层执行。

## 50. FactoryCare 创建案例

端点 `POST /work-orders` consumes/produces `application/json`。请求只含 assetId、description、priority；fake use case 返回带服务端 id 和 CREATED 状态的领域结果；response mapper输出公开字段。

实验分别验证正常 201 JSON、text/plain 415、Accept XML 406、畸形 JSON 400、内部字段不泄露与未知字段策略。

## 51. 可重放 oracle

固定 oracle 包括：DTO round-trip 值相同；wire 字段集合精确；请求/响应类型不同；合法 JSON 进入用例一次；415/400 不进入；不支持 Accept 为406；响应不含 internalCost/token。

验证器输出版本、测试数和媒体类型，不输出真实工单或凭据。

## 52. 独立构建任务

从空目录定义两个 DTO、领域对象和双向 mapper，再建 JSON 创建 Controller。先写请求矩阵和预期 wire JSON，最后用 JsonMapper 与 MockMvc 两层验证。

提交前能指出每个字段由谁生成、是否可缺失、哪个 mapper 公开它，以及一个破坏兼容的修改。

## 53. 修改任务

给响应增加可选 `slaDueAt`，使用带 offset 的 ISO 文本；请求保持不变。先预测旧客户端行为，再更新 mapper、wire 字段测试和内容协商测试。

不得顺便把 internalCost 暴露，也不得把校验规则混入本章。校验留给下一章。

## 54. 诊断顺序

先记录 method、Content-Type、Accept 和原始字节；确认 handler consumes/produces；检查 converter 与实际 Jackson 版本；分辨 415、406、不可读400和不可写5xx；比较 wire JSON 字段；最后检查 DTO-domain mapper。

每次只改变一个媒体类型或字段，修复后重跑原失败和相邻兼容 case。

## 55. 120 秒复述提纲

先解释 DTO 是 wire 白名单并与领域分离；再说 HttpMessageConverter 根据 Content-Type 读请求、根据 Accept/produces 写响应；然后说明 415/406；最后举直接序列化领域对象或字段改名的兼容失败。

能使用 Jackson 注解但不能写出真实 wire JSON，不算掌握。

## 56. 有意不做与兼容边界

本章不定义 Bean Validation、数据库实体映射、全局异常 DTO、认证、OpenAPI 或生产 API 版本治理。未知字段采用严格教学策略，不宣称适合所有公共 API。

不保留 Jackson 2 代码路径；真实迁移需要依赖矩阵、wire 回归和回滚计划。也不为领域对象直出保留默认兼容。

## 57. 一手资料

- [Spring Framework 7.0.8：HTTP Message Conversion](https://docs.spring.io/spring-framework/reference/web/webmvc/message-converters.html)
- [Spring Framework 7.0.8：Message Converters Configuration](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-config/message-converters.html)
- [Spring Framework 7.0.8：Content Types](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-config/content-negotiation.html)
- [Spring Framework 7.0.8：RequestBody](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller/ann-methods/requestbody.html)
- [Spring Boot 4.1：Managed Dependency Coordinates](https://docs.spring.io/spring-boot/appendix/dependency-versions/coordinates.html)
- [Jackson 3 Documentation](https://github.com/FasterXML/jackson-docs)
