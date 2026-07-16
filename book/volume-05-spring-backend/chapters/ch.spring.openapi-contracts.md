---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.openapi-contracts
title: OpenAPI、契约示例与兼容性检查
responsibility: 教授从运行 API 契约生成并检查机器可读描述，不把文档存在等同于实现兼容
volume: '05'
order: 17
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.openapi-contracts.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.problem-details-errors
version_surfaces:
- spring-boot-4.1
- openapi
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释OpenAPI、契约示例与兼容性检查的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - openapi-description
  - openapi-compatibility
  covers_topics:
  - openapi.operation-schema
  - openapi.example
  - openapi.error-response
  - openapi.generated-vs-declared
  - openapi.breaking-change
  - openapi.consumer-check
  uses_capabilities:
  - backend.spring-mvc-contract
  - foundation.http-message
  - java.io-json
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为工单 API 生成 OpenAPI，补齐请求/响应/Problem 示例并运行一次基线兼容 diff
  covers_topic_groups:
  - openapi-description
  - openapi-compatibility
  covers_topics:
  - openapi.operation-schema
  - openapi.example
  - openapi.error-response
  - openapi.generated-vs-declared
  - openapi.breaking-change
  - openapi.consumer-check
  uses_capabilities:
  - backend.spring-mvc-contract
  - foundation.http-message
  - java.io-json
  evidence_kind: integration-artifact-and-tests
  verification_mode: framework-or-container-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入删除必填响应字段、扩大输入约束和实现状态码与文档不一致，使用契约/集成检查修复
  covers_topic_groups:
  - openapi-description
  - openapi-compatibility
  covers_topics:
  - openapi.operation-schema
  - openapi.example
  - openapi.error-response
  - openapi.generated-vs-declared
  - openapi.breaking-change
  - openapi.consumer-check
  uses_capabilities:
  - backend.spring-mvc-contract
  - foundation.http-message
  - java.io-json
  evidence_kind: integration-failure-fix-rerun
  verification_mode: integration-fault-rerun
---
# OpenAPI、契约示例与兼容性检查

> 本章状态为 drafting。存在 `/v3/api-docs` 或 Swagger UI 只证明描述能够输出，不自动证明运行响应符合描述，也不自动证明新版本对旧消费者兼容。

本章基线为 Spring Boot 4.1.0、Spring Framework 7.0.8、springdoc-openapi 3.0.3、OpenAPI Specification（OAS）3.2.0、JDK 25 与 Maven 3.9.16。版本事实复核于 2026-07-17：OAS 3.2.0 是最新已发布规范；FactoryCare 设计契约仍明确写 `openapi: 3.1.0`，不能因为规范出了新版本就静默改写。springdoc 3.x 面向 Spring Boot 4，当前稳定版为 3.0.3。

## 1. 本章完成证据

学习者需要让运行中的工单 API 生成可解析 OpenAPI，补齐成功与 Problem 响应及示例，分别验证“示例符合 schema”“真实响应符合声明”“基线兼容 diff 阻断破坏性变化”。删除必填响应字段必须红，新增可选字段必须绿。

配套工件：

- [契约三角最小示例](../../../examples/encyclopedia/ch.spring.openapi-contracts/README.md)
- [Boot 4.1 运行契约实验](../../../labs/encyclopedia/ch.spring.openapi-contracts/README.md)
- [修复漏报破坏性变化练习](../../../exercises/encyclopedia/ch.spring.openapi-contracts/README.md)

这些工件不更新 `PROGRESS.md`，也不声称 FactoryCare 完整公共契约已经实现。

## 2. API 契约是什么

API 契约是提供者与消费者共同依赖的可观察约定：方法、路径、参数、认证方式、请求/响应媒体类型、状态码、字段、约束和错误语义。它不是 Controller 源码的目录，也不是给人看的宣传页。

“可观察”很重要。服务内部把 `WorkOrderEntity` 改为 record，只要 HTTP 行为没变，就未必改契约；把成功码从 201 改为 200，即使业务结果相同，也可能破坏消费者。

## 3. OpenAPI 的职责

OpenAPI 用机器可读结构描述 HTTP API。工具可以据此渲染文档、生成客户端、构造测试、进行静态检查和比较版本。

它不能证明数据库事务正确、权限实现正确、示例真的运行过或线上一定返回所写字段。规范是证据的一部分，不是全部事实。

## 4. 文档的顶层结构

常见顶层字段包括 `openapi`、`info`、`servers`、`paths`、`components`、`security` 与 `tags`。`paths` 描述公开操作；`components` 保存可复用 schema、参数、响应与安全方案。

先能回答“一个请求从 path 如何引用到 schema”，再使用 UI。只会点 Swagger UI 的 Try it out，无法诊断 `$ref`、required 或兼容 diff。

## 5. 规范版本不是应用版本

`openapi: 3.1.0` 表示文档遵循的 OAS 方言；`info.version: 0.1.0-design` 表示 API 自身版本。两者互不替代。

OAS 3.2.0 已发布，不代表所有生成器、diff 工具和客户端都立即支持。升级规范版本应列出工具矩阵、迁移结果与回滚，不做顺手升级。

## 6. FactoryCare 的设计基线

`factorycare-design/contracts/public-api.yaml` 是设计阶段来源，公共前缀为 `/api/v1`，错误包含稳定 `code/message/fieldErrors/traceId`，写命令使用幂等键，更新使用 version/ETag 语义。

该文件明确声明“design baseline, not proof of implementation”。本章资产只取一个缩小的工单切片教学，不修改或假装实现整个设计契约。

## 7. 生成式与设计优先并非二选一口号

code-first 可从运行 Controller/DTO/注解生成描述，减少路径与 Java 类型的重复。design-first 可在实现前让多端协商契约。成熟流程通常保留一个权威基线，同时从运行应用导出候选并比较。

最危险的是同时手改 YAML、注解和客户端类型，却没有自动漂移检查；这会形成三份互相矛盾的“真相”。

## 8. springdoc 与 Boot 4

springdoc-openapi 扫描 Spring MVC/WebFlux 配置、Controller、校验注解和 Swagger annotations，生成 JSON/YAML 与可选 UI。3.x 是 Spring Boot 4 的兼容系列。

Boot 4 模块化后不要照抄旧教程的依赖/import；以 springdoc 3.0.3 官方 starter 与实际解析树为准。配套 lab 使用 `springdoc-openapi-starter-webmvc-api`，不引入 UI 来缩小攻击面与依赖。

## 9. 运行描述端点

springdoc 默认常用 JSON 路径为 `/v3/api-docs`，配置可以改变。测试应读取实际文档并解析 JSON，而不是只断言 HTTP 200。

文档端点是否在生产暴露是安全/运维决定。内部可由 CI 启动应用抓取快照；不能因为开发方便就匿名公开全部内部操作和模型。

## 10. operationId 是消费者接口名

`operationId` 应稳定、唯一并表达动作，例如 `getWorkOrder`。生成 TypeScript/Dart 客户端时，它常成为方法名。

随意把它改成 `findOne`，HTTP 路径没变也会造成生成客户端编译失败。兼容检查不能只看 URL。

## 11. Path 与 HTTP 方法

`/api/v1/work-orders/{workOrderId}` 下的 `get` 是一个 operation。path parameter 必须声明 `in: path` 且 required；query/header/cookie 参数的来源也必须明确。

把租户 ID 写成客户端可控 header 并不因为文档完整就安全。FactoryCare 的租户与操作者上下文来自认证后的服务端上下文，而不是信任普通输入。

## 12. parameters 与 requestBody

path/query/header/cookie 使用 `parameters`；JSON body 使用 `requestBody.content`。`requestBody.required: true` 只表示 body 不能缺失，不表示对象里的每个 property 都必填。

字段必填由对象 schema 的 `required` 数组决定。初学者常把 property 下的 `required: true` 当成 OAS 规则，导致工具忽略。

## 13. Schema 是可验证结构

object schema 描述 properties、required、additionalProperties 与组合规则；array 描述 items；string/integer 描述格式与边界。schema 应表达跨端需要知道的约束，不复制数据库全部列。

DTO 应与数据库实体分离。暴露实体会把懒加载、内部字段和迁移细节变成无意的公共契约。

## 14. “缺失”与 null

字段没出现和字段值为 null 是两种 JSON 状态。OAS 3.1 可用 `type: [string, 'null']` 表达可为 null；它仍可能同时是 required，表示键必须存在但值可以为 null。

消费者生成器对 nullable 支持不完全一致。设计时必须用实际目标工具编译，而不是凭规范理论判断。

## 15. required 的兼容方向

响应从 required 删除字段意味着提供者不再保证该字段存在，旧消费者可能崩溃，通常是破坏性变化。请求新增 required 字段意味着旧客户端发出的 body 不再被接受，也通常破坏。

相反，响应新增可选字段通常向后兼容，前提是消费者忽略未知字段；请求取消 required 通常放宽提供者要求，但仍要评估业务含义。

## 16. 约束既是校验也是合同

`minLength/maxLength`、`minimum/maximum`、`pattern`、`format` 和 enum 会影响可接受输入或承诺输出。把请求 `description.maxLength` 从 5000 缩到 1000 是收紧输入，旧消费者可能失败。

生成器能从 Bean Validation 推断部分约束，但复杂跨字段规则仍需显式描述与行为测试。

## 17. additionalProperties

`additionalProperties: false` 拒绝未声明字段，能发现拼写错误，却使增量演进更严格。若提供者实际 Jackson 配置会忽略未知字段，而 schema 声明拒绝，两者已经漂移。

是否允许扩展必须是明确契约决策，不能由某个序列化器默认值偶然决定。

## 18. 响应状态矩阵

每个 operation 应声明实际可能出现的重要状态：成功、校验、未认证、无权、不存在、冲突、限流和依赖故障。只写 200 会让客户端在 409/503 时退化为“未知错误”。

声明并不自动让 Controller 返回正确状态。集成测试要触发路径，比较真实 status/content-type/body。

## 19. 媒体类型

`application/json`、`application/problem+json`、文件与事件流具有不同语义。客户端会依据 content type 选择解析器。

错误体是 Problem 却仍返回 `text/plain`，或者文档写 JSON 而运行返回空 body，都是实现—契约漂移。

## 20. Problem Details

FactoryCare 的 Problem schema 至少稳定 `type/title/status/code/message/traceId`，校验失败可附 `fieldErrors`。客户端应分支稳定 `code`，不要解析自然语言 message。

每个稳定错误码至少有一个契约测试。错误 schema 复用不能替代状态码、header 与无副作用断言。

## 21. 示例的三种价值

示例帮助人理解、供 mock server 返回、也可作为可执行 fixture。请求示例应表现边界输入，成功与 Problem 示例要覆盖稳定字段。

示例不是随便粘贴日志。不得含真实 tenant、token、人员、设备序列号或内部堆栈。

## 22. 示例必须过 schema

一个漂亮示例若缺 required `version`，会教会消费者错误用法。CI 应把每个 example 当 JSON 实例，解析其引用后的 schema 并验证。

schema validation 仍不证明业务行为；它只回答结构与局部约束是否一致。

## 23. `$ref` 与复用

`$ref` 让多个 operation 引用同一 WorkOrder/Problem。修改共享 schema 会影响所有引用点，diff 报告应展示影响面。

不要复制十份相似 Problem；也不要建立一个几百字段的“万能 DTO”，使每个操作都含大量无关可选字段。

## 24. allOf、oneOf 与判别

`allOf` 合并约束，常用于 detail 扩展 summary；`oneOf` 表示恰好一个候选。多态契约最好给 discriminator 和稳定映射。

组合 schema 的兼容性比平面对象复杂，必须用目标 validator/generator 实测。不要把工具不支持误认为规范无效。

## 25. 安全方案也是契约

OpenAPI 可声明 cookie session、bearer/OAuth2 和 operation 的 security requirements。它描述消费者如何携带凭据，不实现授权。

FactoryCare 同一公共操作可支持 browserSession 与 mobileBearer，但服务仍要依据 membership、角色、数据范围和 tenant 做授权。

## 26. 创建报修案例

`POST /api/v1/reports` 需要 Idempotency-Key 与 CreateReportRequest，成功为 201、Location header 和 ReportDetail；400/401/403/409 使用稳定 Problem。

客户端可由此生成类型与状态分支；但“同键只创建一次”的幂等事实仍需数据库/集成测试，OpenAPI 本身表达不了全部副作用。

## 27. 工单读取案例

`GET /api/v1/work-orders/{workOrderId}` 成功返回 WorkOrderDetail，关键字段包括 id、number、assetId、status、priority、version、createdAt；无权与不存在必须区分契约行为而不泄漏跨租户存在性。

教学 lab 缩成 id/status/version，明确不是完整 FactoryCare DTO。

## 28. 运行文档与真实响应的双向检查

第一方向：从运行 `/v3/api-docs` 找到 operation/status/schema，再验证真实响应满足 required、类型和媒体类型。第二方向：枚举真实测试触发的状态，确认文档已声明。

只做第一方向会漏掉实现新增但未声明的 422；只做第二方向会漏掉文档承诺但实现永远不返回的字段。

## 29. 三角真相模型

对每次变更比较三个角：权威基线、运行生成候选、消费者证据。基线表达已发布承诺；候选表达当前实现可推导描述；客户端编译/契约测试表达实际依赖。

任何两角一致都不等于第三角安全。生成文档与实现同源仍可能一起漏写业务错误响应。

## 30. 基线快照

基线应来自已经发布/批准的 contract artifact，并有明确版本。不要在同一 PR 里先覆盖 baseline 再做 diff，那只会永远比较相同文件。

快照可存完整 OpenAPI，也可生成规范化摘要；必须保留 operation、状态、required、约束和安全等兼容信号。

## 31. 规范化再 diff

排序、无意义 description 变化或生成器顺序会制造噪声。先解析、解析引用、按稳定键规范化，再比较语义。

不要用纯文本 diff 判断兼容；它看不懂 required 的方向，也会把格式化当重大变化。

## 32. 常见破坏：删除/重命名

删除 path、operation、旧响应状态、响应 required 字段或 security scheme 通常破坏。字段重命名在 JSON 上是删除旧字段再新增新字段，而不是“只改名字”。

迁移方案通常是先新增、双写或兼容读取，消费者迁移后再在新 API 版本删除。

## 33. 常见破坏：收紧请求

新增 request required、缩小最大长度、抬高 minimum、缩窄 pattern 或取消旧 content type 会拒绝旧请求。diff 要从消费者视角判断方向。

“扩大输入约束”一词容易歧义：扩大约束的严格程度就是缩小可接受集合，必须红。

## 34. 新增可选响应字段

宽容读者通常会忽略未知响应字段，因此新增 optional property 常可兼容。仍应编译 TypeScript/Dart 客户端，确认反序列化配置允许未知字段。

若消费者启用严格 additionalProperties 拒绝，团队应先迁移消费者策略，而不是把“通常兼容”当绝对定理。

## 35. enum 演进

响应 enum 新增值可能让穷举 switch 崩溃；请求 enum 新增通常只是服务器多接受输入。很多通用 diff 工具对 enum 方向处理不同。

客户端应用未知值策略或显式版本化；关键状态如 FactoryCare 12 个工单状态不能静默加值。

## 36. 状态码变化

201 改 200、404 改 403、409 改 400 都可能破坏消费者控制流。即使 body 相同，也要作为兼容决策审查。

测试应同时断言 status、Content-Type、Location/ETag/Retry-After 等关键 header 与 body schema。

## 37. 消费者检查

最强的实际证据之一是用候选 OpenAPI 重新生成/更新客户端，然后编译现有 Vue/uni-app/Flutter 调用。编译通过仍不证明运行语义，但能暴露方法/类型漂移。

FactoryCare 策略要求 TypeScript 与 Dart 生成客户端在 CI 编译；本章不提前生成整个多端 SDK。

## 38. 兼容工具的边界

openapi-diff 等工具可报告 3.x operation/parameter/response/schema 差异，但分类规则与工具版本有关。团队要固定版本，并为业务敏感规则补自定义测试。

工具说 compatible 不代表语义兼容，例如字段含义或单位从分钟改成秒，schema 仍是 integer。

## 39. CI 质量门

推荐顺序：启动候选应用 → 抓取/解析生成文档 → 校验 examples → 运行真实响应契约测试 → 与发布基线做语义 diff → 生成客户端并编译。

任何一步失败都保留候选、基线、报告和首个失败路径，便于诊断，不只输出“contract failed”。

## 40. 破坏性变更的处理

若确需破坏，先列消费者、迁移窗口、新版本路径、双轨期限与回滚。公共 `/api/v1` 内不直接删除；创建 `/api/v2` 或完成明确迁移。

兼容不是永远保留旧字段。长期维护优先，完成迁移后应按计划删除旧契约而非无限双写。

## 41. deprecation 不是删除许可

deprecated 标记通知消费者迁移，但不会自动统计使用或阻止调用。需要调用遥测、所有者与截止日。

删除前以消费者证据确认迁移，不以“文档写了三个月”推断无人使用。

## 42. 版本与缓存

OpenAPI artifact 应可按构建版本追溯，避免 CDN/UI 缓存展示旧规范。运行响应的 API version 与 artifact version 要能关联。

不要在文档中写无法重现的当前时间或随机示例，避免每次生成产生无意义 diff。

## 43. 文档端点安全

规范可能暴露内部路径、字段名、认证流程和错误细节。生产暴露策略与业务 API 授权分开配置；内部 API 不应自动混入公共 group。

UI 自身也不是认证边界。即便 UI 被隐藏，原始 `/v3/api-docs` 仍可能公开。

## 44. Controller 注解的适度使用

类型和 Bean Validation 可推导的约束让代码保持单一；operationId、业务描述、错误响应和高价值示例通常需显式补充。

注解堆满重复 schema 会降低可维护性。复用组件/customizer，并用生成快照测试结果而非测试注解存在。

## 45. 失败：文档缺 Bean/路径

若 `/v3/api-docs` 404，依次检查 starter、MVC/WebFlux 技术栈、扫描包、端点配置和安全规则。不要先复制随机配置。

若某 Controller 缺失，检查其是否在运行 context、是否被隐藏、group 匹配和 path mapping，而不是手写假路径补到 baseline。

## 46. 失败：状态码与文档不一致

症状是 Controller 返回 200，但规范/消费者期待 201。先以真实 HTTP 测试确认实现，再决定修实现或做显式破坏迁移。

只改 `@ApiResponse` 会让 UI 变绿却不改变运行行为，是典型假修复。

## 47. 失败：示例漂移

schema 新增 required `version` 后，旧 example 缺字段。validator 应指出 JSON Pointer；修复示例并添加真实序列化测试。

不要把该字段从 required 删除只为让示例通过，除非业务承诺真的改变并经过兼容评估。

## 48. 失败：基线被覆盖

若 diff 永远为空，检查流水线是否在比较前把候选复制到了 baseline 路径。基线必须来自目标环境/已发布 tag 的只读 artifact。

输出两个文件的摘要和版本，防止“old/new 参数传反”让收紧输入被误分类。

## 49. 失败：运行 JSON 与 schema 类型不同

例如 version 文档为 integer，Jackson custom serializer 却输出字符串。生成式推断看 Java 类型，无法看到所有运行定制。

真实响应 schema validation 会在 `/version` 定位；修序列化或显式 schema，但两者必须统一。

## 50. 失败：隐藏错误契约

全局 ControllerAdvice 返回 Problem，但 springdoc 不一定自动为每个 operation 列出全部错误。需要复用 response component 或 customizer，并用状态矩阵测试。

不要给每个 endpoint 声明实际上永远不可能的所有错误；合同应准确而非数量多。

## 51. 测试分层

纯 schema 测试快，验证解析、引用、example 与 diff；运行 context 测试验证生成描述；HTTP 集成验证实现；消费者编译验证使用方。每层回答不同问题。

不使用浏览器 E2E 重复所有 schema 分支，也不使用一个 `contextLoads` 冒充合同验证。

## 52. 最小运行 oracle

对 `getWorkOrder` 至少检查：文档可解析、operationId 稳定、200/404 声明、成功 JSON 含 id/status/version、404 为 Problem、运行状态/字段匹配。

然后对候选快照删除 version，compatibility gate 必须拒绝；只新增 optional `slaDueAt` 应通过。

## 53. 诊断顺序

先判断失败层：JSON 无法解析、引用无法解析、schema/example 不符、运行行为不符、基线 diff、客户端编译。取第一个可信失败，不被后续级联错误淹没。

保存 path、method、status、JSON Pointer、old/new 值和工具版本，才能复现。

## 54. 反例：有 UI 就算完成

团队能打开 Swagger UI，但 404 实际返回 HTML、示例缺 version、候选删除 required 字段而没有 baseline。此时 UI 只是更好看的错误说明。

完成定义必须同时包含机器解析、运行响应、兼容 diff 与消费者证据范围说明。

## 55. 红灯练习

练习 starter 的 compatibility gate 错把“任何字段集合变化”都允许，删除 response required `version` 时仍绿。第二个测试以 `EXPECTED_BREAKING_CHANGE_BLOCKED` 稳定失败。

参考解按方向比较：旧 required 必须是新 required 的子集；新增 optional property 不影响该承诺。

## 56. 120 秒复述模板

先说职责：OpenAPI 机器描述 HTTP 合同。再说边界：描述不证明实现或兼容。再说三角：发布基线、运行候选、消费者证据。最后举反例：删 required 字段但只打开 Swagger UI。

若不能解释请求/响应 required 的相反兼容方向，尚未达到独立诊断。

## 57. 构建检查表

- operationId 唯一稳定；
- path/parameter/requestBody 来源正确；
- 成功与 Problem 状态、header、媒体类型完整；
- schema required/null/约束准确；
- examples 可执行且脱敏；
- 运行响应与生成文档互验；
- 只读发布基线完成语义 diff；
- 破坏变化有迁移与回滚；
- 消费者检查范围被明确记录。

## 58. 有意非目标

本章不实现整个 FactoryCare 公共 API、不生成完整 TypeScript/Dart SDK、不修改设计 contract、不教授 GraphQL/AsyncAPI，也不把 OpenAPI 当授权、幂等或事务证明。

## 59. 官方资料

- [OpenAPI Specification 3.2.0](https://spec.openapis.org/oas/v3.2.0.html)
- [OpenAPI 已发布版本索引](https://spec.openapis.org/oas/)
- [springdoc-openapi 3.0.3 / Spring Boot 4 文档](https://springdoc.org/v4/index.html)
- [OpenAPITools openapi-diff](https://github.com/OpenAPITools/openapi-diff)
- [Spring Boot 4.1 reference](https://docs.spring.io/spring-boot/reference/)

版本敏感命令以配套 `pom.xml` 解析结果为准；概念性的兼容方向不依赖某个 UI 或生成器品牌。
