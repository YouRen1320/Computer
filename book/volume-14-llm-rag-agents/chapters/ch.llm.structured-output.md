---
schema_version: 2
edition: 2026.2-draft
id: ch.llm.structured-output
title: 结构化输出、Schema 与运行时校验
responsibility: 把模型文本约束为版本化 Schema 并用运行时校验拒绝缺失、越界和额外字段，不允许校验失败结果进入业务层。
volume: '14'
order: 3
level: L3
status: drafting
path: book/volume-14-llm-rag-agents/chapters/ch.llm.structured-output.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.llm.api-prompts-cost
- ch.python.pydantic-validation
version_surfaces:
- python-3.14
- model-api
- pydantic-2
- pytest
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“结构化输出、Schema 与运行时校验”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - llm-structured-schema
  - llm-runtime-validation
  covers_topics:
  - llm.json-schema-output
  - llm.field-description
  - llm.enum-constraint
  - llm.schema-version
  - llm.pydantic-validation
  - llm.parse-failure
  - llm.repair-boundary
  - llm.unknown-field-policy
  uses_capabilities:
  - ai.llm-model-api
  - python.io-errors
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“结构化输出、Schema 与运行时校验”构建可运行程序与测试：定义工单分类输出的版本化 Pydantic Schema，验证合法、缺字段、非法枚举、额外字段和非
    JSON 响应；独立保存可复现工件与判断结果
  covers_topic_groups:
  - llm-structured-schema
  - llm-runtime-validation
  covers_topics:
  - llm.json-schema-output
  - llm.field-description
  - llm.enum-constraint
  - llm.schema-version
  - llm.pydantic-validation
  - llm.parse-failure
  - llm.repair-boundary
  - llm.unknown-field-policy
  uses_capabilities:
  - ai.llm-model-api
  - python.io-errors
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: schema-contract-tests-malformed-output-fixtures-provider-mock
- id: diagnose
  kind: fault-diagnosis
  text: 面对“直接信任反序列化字典、把解析失败修成默认高优先级、Schema 演进无版本或允许任意额外字段”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - llm-structured-schema
  - llm-runtime-validation
  covers_topics:
  - llm.json-schema-output
  - llm.field-description
  - llm.enum-constraint
  - llm.schema-version
  - llm.pydantic-validation
  - llm.parse-failure
  - llm.repair-boundary
  - llm.unknown-field-policy
  uses_capabilities:
  - ai.llm-model-api
  - python.io-errors
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 结构化输出、Schema 与运行时校验

模型生成的是概率性输出，业务程序需要的是有字段、类型、范围和版本的值。结构化输出的任务不是让JSON“看起来整齐”，而是建立从供应商响应到可信业务输入的门：先判断响应是否完成、是否拒绝，再解析JSON，再按版本化Schema校验，只有全部通过的对象才进入业务函数。解析失败不是一个默认高优先级工单，缺字段也不是“让程序猜一下”。

本章先讲供应商无关的Schema合同，再标注截至2026-07-24的OpenAI Structured Outputs具体表面。示例使用Pydantic 2和本地fixture，不调用真实模型。供应商宣称的Schema遵循能力能够减少格式失败，却不会替应用完成响应状态判断、版本迁移、业务授权、敏感数据处理和领域不变量校验。

## 1. 从自由文本到有类型边界

若模型回答“可能是机械故障，优先级较高”，人能理解，程序却不知道category有哪些合法值、HIGH是否大小写固定、理由能否为空、结构版本是什么。直接用字符串查找会把表达变化变成Bug。JSON只解决语法容器，JSON Schema与运行时模型才定义结构合同。

完整管线是：请求声明期望Schema；供应商返回响应封套；适配器检查refusal、status和完成原因；提取结构化文本或SDK解析值；运行时模型验证字段、枚举、额外字段和约束；转换为领域命令；Java业务服务再次检查资源权限与状态机。每道门回答不同问题。

Schema验证通过只说明“形状与局部约束正确”。它不能证明分类事实正确，不能证明用户有权访问工单，也不能证明理由来自可靠资料。质量需要评估集，授权需要可信服务，事实需要数据库或可引用来源。

## 2. JSON、JSON Mode与Structured Outputs

合法JSON可以是空对象、错误字段或非法业务枚举。JSON mode主要承诺生成有效JSON，不等于满足某个Schema。Structured Outputs向模型提供JSON Schema并在支持条件下约束输出遵循该Schema。二者不能混为“都是JSON所以一样安全”。

OpenAI官方指南当前推荐在可用时优先使用Structured Outputs，并区分两种用途：模型给用户返回结构化内容时使用Responses的text.format；模型要连接应用函数时使用function calling。具体请求字段会随API演进，适配器和官方SDK应隔离这些变化。

即使使用严格结构化输出，也要处理两个不遵循业务Schema的合法分支：安全拒绝和输出不完整。官方指南明确说明拒绝会以可检测字段表示，达到最大Token等情况可能使响应不完整。应用若只拿text做JSON解析，会把协议状态误报成格式错误。

## 3. Schema是可发布的接口

Schema应有名称、版本、所有者、用途、示例、兼容策略和测试。FactoryCare分类结果可以命名work-order-classification/1，并在载荷中包含schema_version常量。版本不是装饰，它让消费者知道用哪个解析器，也让日志与评估结果可关联。

字段名称要表达业务含义；description说明生成目标与限制，但description不是安全规则。category使用封闭枚举，priority使用封闭枚举，rationale设置非空和最大长度。不要用任意str然后在下游到处比较拼写。

Schema演进先判断兼容性。增加可选字段对宽松消费者可能兼容，但严格additionalProperties=false的旧消费者会拒绝；改变枚举、语义或必填性通常需要新版本。模型输出与消费者必须同版本部署或通过显式适配器迁移。

版本迁移函数只做确定、可审计的结构转换。它不能在缺少priority时凭空填HIGH，也不能把未知枚举悄悄归为OTHER，除非业务产品明确批准该语义并有指标。无法无损迁移时应拒绝并重新生成或转人工。

## 4. 字段描述、枚举和边界

清楚的字段名和描述能帮助模型产生合适内容，也帮助维护者理解Schema。描述应说明字段语义、单位和示例，不要塞入整套提示或秘密规则。例如priority描述“根据已提供的影响与紧急度给出LOW/MEDIUM/HIGH建议”，而不是“只有管理员可设置HIGH”。

枚举把开放字符串缩成封闭集合。它能阻止CRITICAL、high或紧急等未约定值进入业务层，但不能判断模型选择HIGH是否正确。枚举变更要考虑所有消费者和历史数据。

数值字段要声明整数/小数、最小最大值和单位。时间字段要说明时区与格式。ID字段要限制类型、长度和模式，但资源存在性仍由仓库检查。理由字段要限制长度，避免模型把大量原文或敏感信息复制进结果。

数组应限制项类型与数量；嵌套对象逐层设置额外字段策略。无限数组、无限字符串和任意递归结构会扩大成本、解析与存储风险。

## 5. additionalProperties与未知字段

未知字段策略必须显式。对模型到业务的命令边界，默认推荐拒绝额外字段：它能暴露模型/Schema漂移、拼写错误和攻击者插入的隐藏参数。Pydantic 2使用ConfigDict(extra="forbid")可实现这一点。

忽略额外字段看似兼容，实际可能掩盖priorityy拼写；保存额外字段则把未审查数据带入日志、数据库或工具。若确有扩展需求，应设计专门的metadata子对象并限制键值，而非让整个对象开放。

OpenAI function calling严格模式当前要求对象的additionalProperties为false，并要求properties中的字段列入required；可选值可通过包含null表达。这是具体供应商的支持子集，不代表所有JSON Schema实现都相同。生成Schema后应做快照测试，确认SDK输出符合目标API限制。

## 6. Pydantic 2运行时模型

Pydantic BaseModel把Python类型注解、字段约束和错误位置组合成运行时验证器。ConfigDict(extra="forbid", strict=True)建立严格基础；Literal固定schema_version和类别；StrEnum表达优先级；Field定义长度、范围和模式。

model_validate_json直接从JSON字节/字符串解析并校验，减少先json.loads得到任意dict再忘记验证的机会。成功返回有类型对象；失败抛ValidationError，errors()提供字段位置与错误类型。对外错误应转换成稳定代码，例如invalid_json或schema_validation。

strict=True并不等于所有来源都采用完全相同强制规则；JSON解析与Python对象验证对某些类型有合理差异。测试必须覆盖实际入口：若生产从JSON进入，就用model_validate_json测试；若从SDK对象进入，就用相应入口测试。

不要catch Exception后返回默认对象。捕获范围应只覆盖预期解析/验证异常，保留cause用于受限诊断；调用方得到失败Result或领域异常。数据库、网络与编程错误不能被伪装成schema失败。

## 7. 先检查响应封套

解析前先检查供应商级状态。推荐决策顺序：是否有传输/HTTP错误；是否安全拒绝；是否completed；是否存在期望输出项；然后才解析内容。顺序让错误归因准确，也避免把拒绝文本暴露为JSON错误。

refusal应成为单独状态，UI可显示安全说明或转人工，不应“修复”为业务分类。incomplete应保存原因，例如达到输出上限，并决定是否在预算内重试。没有完成标记的流式半截JSON不能送进解析器碰运气。

响应可能含多个输出项或工具调用。适配器应根据明确类型选择目标项，不能取第一个字符串。若合同要求恰好一个分类对象，零个或多个都应失败并记录数量。

供应商新增字段时，外层适配器可容忍并映射已知字段；业务载荷仍严格。把“协议前向兼容”和“业务命令拒绝未知字段”分层，避免一刀切。

## 8. 错误分类与安全日志

建议错误码至少有transport_error、provider_refusal、provider_incomplete、missing_output、invalid_json、schema_validation、unsupported_schema_version和domain_rejection。每个码都有是否可重试、用户文案、指标标签和审计策略。

ValidationError日志记录schema_name、schema_version、错误类型和字段loc，不记录完整raw。原始模型输出可能含个人信息、提示注入内容或巨大文本。若调试必须保存，放入受限加密证据区并设置保留期限。

错误消息要稳定。测试不应依赖Pydantic整段英文文案，因为版本升级可能改变措辞；应断言错误类别、loc和type。对外接口也不应泄露内部Schema或提示细节。

成功记录包含schema_version、解析器版本、模型与提示版本、供应商请求ID。这样某一Schema错误率上升时能按维度定位。

## 9. “修复”输出的危险边界

自动修复可以指语法层的确定转换，例如供应商SDK已保证对象但传输包装需要解码；也可以指再次请求模型重写。后者是新的模型调用，必须有独立request_id、usage、预算和失败路径，不能当作本地无损修复。

禁止把缺少优先级修为HIGH，因为这会把格式错误提升为最高业务动作；禁止把非法枚举一律改OTHER，因为会掩盖模型漂移；禁止删除未知字段后继续，因为未知字段可能正是危险参数。默认是拒绝，必要时有限重试或人工确认。

若产品批准修复规则，规则必须确定、窄小、版本化并有before/after审计。例如只去除UTF-8 BOM可以是传输规范化；从自然语言猜枚举不是。修复后仍要完整校验。

重试提示可包含结构错误摘要，但不要回显敏感原文；重试次数有上限，并计入总延迟和成本预算。若同一错误重复，停止并报警，而不是无限循环。

## 10. Schema与领域模型不是同一个东西

模型输出DTO属于不可信边界，字段应最少。领域模型包含业务不变量、身份和持久化关系。不要让Pydantic输出对象直接成为JPA实体或更新命令。

分类结果进入Java前，Java重新验证API DTO，加载真实工单，检查租户、状态、并发版本与允许转换。模型给出的order_id甚至不应被信任，最好由可信请求上下文绑定，不让模型自由选择资源。

Python编排层可以负责调用模型和验证结构，但工单事实仍由Java服务拥有。Python不能因为Schema通过就直接更新数据库。这个边界避免AI服务成为第二套事实源。

领域拒绝与Schema拒绝分开统计。priority=HIGH在Schema上合法，若业务规则要求特定证据才允许自动升级，它仍可能被domain_rejection拒绝。

## 11. 生成JSON Schema与供应商子集

Pydantic可生成JSON Schema，用于文档、SDK请求和快照测试。生成后检查根type、required、additionalProperties、enum、长度与版本常量。不要假设Python注解自动映射成供应商支持的全部关键字。

JSON Schema是一大套标准，不同模型API只支持子集。递归、复杂组合、默认值或格式关键字可能不支持或只作注释。供应商拒绝Schema属于请求构建阶段，不是模型输出失败。兼容性测试应在升级SDK或Schema时运行。

同一Schema不要每次动态改变字段顺序或描述，以免供应商首次处理和缓存产生额外延迟，也让快照难比较。Schema内容hash可以成为发布证据。

供应商严格输出降低格式不确定性，不取消本地Pydantic。后者承担类型转换边界、版本确认、领域映射和纵深防御，也让Fake/其他供应商共享合同。

## 12. 五类必测非法输入

第一类是非JSON：普通句子、截断花括号、无效编码。应得到invalid_json，业务调用次数为零。第二类缺字段：缺category或schema_version，得到schema_validation和准确loc。

第三类非法枚举或越界：priority=CRITICAL、理由过长、负数。第四类额外字段：debug、sql、approved=true；必须拒绝。第五类版本不符：载荷是/2但解析器只接受/1；不能当普通数据继续。

还要测供应商封套：refusal、incomplete、无输出、多输出与错误项。测试Spy记录业务函数调用数，所有非法案例都必须为零，这比只断言抛异常更能证明边界。

合法fixture至少覆盖每个枚举、Unicode、边界长度和可空规则。属性测试可生成大量组合，但固定回归样本仍要保留首个事故证据。

## 13. FactoryCare分类合同

一个最小V1对象含schema_version、category、priority、rationale。category只允许MECHANICAL、ELECTRICAL、OTHER；priority只允许LOW、MEDIUM、HIGH；rationale为1到160字符；根对象不允许额外字段。

模型不返回assignee_id、closed或approved等可执行字段。即便用户要求“顺便关闭”，Schema没有这些能力。高风险动作由工具调用章节的独立白名单、授权和确认合同处理。

业务流程先保存“AI建议”及其证据，不直接覆盖人工分类。Java服务可根据产品规则把建议交给用户确认；记录模型、提示、Schema和请求ID，以便复盘误分类。

评估集比较结构合规率与分类质量。Structured Outputs可能让合规率很高，但质量仍需标注真值。两项指标不能合并成一个“成功率”。

## 14. 逐步阅读实验代码

example展示StrEnum、Literal、Field和extra forbid，并检查生成Schema的additionalProperties。lab的validate_provider_envelope先看refusal与status，再调用model_validate_json，并把原始异常映射为稳定错误。

参数化测试分别删除字段、加入非法枚举、加入extra和修改版本。另一个参数表覆盖非JSON、incomplete与refusal。测试的核心Oracle是只有合法ClassificationV1进入calls列表。

public exercise故意直接json.loads、允许任意str、没有版本且失败默认HIGH。verify返回41并打印EXPECTED_RED。private solution证明严格解析可恢复绿色；它不是让学习者直接复制的捷径。

所有fixture都是本地字符串。req、refusal和status是模拟值，不代表真实OpenAI请求。没有真实密钥、账单、模型或线上Schema处理证据。

## 15. 诊断矩阵

|现象|阶段|首个可信证据|风险|修复|
|---|---|---|---|---|
|not-json|JSON解析|invalid_json错误码|下游KeyError或默认值|拒绝、有限重试或人工|
|缺category|Schema验证|loc=category,type=missing|错误分类被猜测|补正提示/Schema并重试|
|priority=CRITICAL|枚举验证|enum错误与实际值摘要|未知动作语义|拒绝并评估漂移|
|出现approved=true|额外字段|extra_forbidden|模型尝试越权参数|严格拒绝且记录安全指标|
|版本为/2|版本路由|Literal不匹配|新旧消费者错配|显式迁移或部署对应解析器|
|refusal|供应商封套|refusal字段|被误报成格式Bug|独立状态与用户路径|
|incomplete|供应商封套|status与原因|半截对象被使用|按预算重试或失败|
|Schema请求被400拒绝|请求构建|供应商错误详情|不支持关键字|缩小到支持子集并做契约测试|
|验证失败却业务被调用|控制流|Spy调用次数|不可信数据进入事实层|让解析返回Result并强制分支|

## 16. 概念卡：每一层到底保证什么

### 16.1 JSON语法

保证文本可解析成JSON值，不保证根是对象、字段存在或业务合法。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.2 JSON Schema

声明结构与约束；具体验证能力取决于实现和供应商支持子集。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.3 Structured Outputs

在支持模型与正常完成条件下约束模型生成遵循Schema，同时仍需处理拒绝和不完整。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.4 Pydantic模型

在Python运行时把输入验证为有类型对象，并提供可定位错误；不判断现实事实真伪。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.5 Literal版本

确保解析器只接收声明版本；不会自动完成新旧迁移。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.6 枚举

拒绝集合外字符串；不会证明模型选中的集合内值正确。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.7 extra forbid

阻止未知字段静默穿透；可能使新增字段成为显式破坏性变化，因此需要版本策略。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.8 strict模式

减少隐式强制转换；仍应针对实际JSON入口测试具体行为。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.9 字段description

帮助生成质量和维护理解；不是授权、防注入或数据库约束。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.10 refusal

表示供应商/模型拒绝完成请求的可检测状态；不应伪造业务对象。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.11 incomplete

表示未得到完整承诺；已有前缀也不能按完整对象使用。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.12 parse failure

表示语法无法解释；它不是LOW、HIGH或OTHER。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.13 schema failure

表示JSON存在但不满足合同；修复前业务调用必须为零。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.14 domain failure

表示结构合法但违反真实业务规则；由领域服务处理。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.15 迁移器

把已知旧版本确定映射到新版本；不能猜缺失事实。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.16 重试

发起新的有成本、有request_id的尝试；不是抹去第一次失败。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.17 结果封套

携带ok/code/data/trace等协议信息；业务payload保持最小和严格。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.18 未知字段策略

决定拒绝、忽略或收集扩展。对可执行AI输出默认拒绝最安全。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.19 Schema hash

标识发布内容，便于缓存、日志与回归；不能代替语义版本和变更说明。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.20 质量评估

判断结构合法值是否正确有用；Schema合规率不能代替准确率。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.21 资源授权

检查当前主体能否操作具体工单；模型输出和Pydantic都不能完成。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.22 人工确认

对高风险动作提供人的明确意图；分类结构通过不等于同意执行。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.23 原始输出

可能含敏感数据和攻击内容；默认不写普通日志。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

### 16.24 错误位置

loc/type帮助定位字段；对外不必暴露完整内部Schema。审查时再问：它没有保证什么？把后一部分写入测试或相邻边界。

## 17. 实操路线

先运行example，查看model_json_schema输出，指出required、additionalProperties和enum所在位置。然后给合法对象增加debug字段，预测ValidationError。不要先运行，先写失败阶段与错误位置。

运行lab后逐一阅读参数化用例。为rationale增加最大长度边界样本；再添加一个status=completed但text缺失的封套样本。每次确认业务Spy没有收到非法对象。

运行public exercise应稳定得到退出码41。按顺序修复：定义版本Literal；枚举化字段；extra forbid；使用model_validate_json；删除默认HIGH修复；建立独立错误。每修一步只让对应测试变绿，保留其余红灯作为学习证据。

最后画出“供应商封套→JSON→Schema→领域→持久化”五道门，在每条箭头写允许的类型和失败码。若任何箭头仍传dict[str, Any]而没有验证责任人，边界尚未完成。

## 18. 自测题

1. 为什么“能json.loads”不能证明可安全进入业务？
2. JSON mode与Structured Outputs最关键差别是什么？
3. 拒绝为什么可能不符合业务Schema？检查顺序应怎样？
4. extra="ignore"会掩盖哪两类问题？
5. 为什么schema_version应出现在载荷中而不只写日志？
6. 缺priority时默认HIGH有什么现实风险？
7. Pydantic验证通过后，Java服务还要检查什么？
8. strict=True为什么仍需要按实际入口写测试？
9. 自动修复与重新生成的成本、追踪证据有何不同？
10. 如何证明非法输出没有进入业务函数？
11. 新增可选字段为什么对严格旧消费者仍可能破坏兼容？
12. 结构合规率达到100%为什么不等于分类准确率100%？

## 19. 120秒复述模板

结构化输出把概率文本转换为受约束数据，但要分层。先检查HTTP和供应商封套，拒绝与不完整走独立状态；然后用版本化JSON Schema和Pydantic 2验证必填、枚举、范围与额外字段；只有成功的有类型对象才进入领域。JSON合法不等于Schema合法，Schema合法不等于事实正确或授权通过。解析失败不能修成默认高优先级，Schema演进必须显式版本和迁移。Python负责AI边界，Java仍负责工单事实、资源授权和状态机。本地fixture只证明合同分支，不证明真实模型遵循、账号能力或线上质量。

## 20. 官方版本表面与复核入口

截至2026-07-24，OpenAI Structured Outputs指南说明：Structured Outputs相较JSON mode还保证Schema遵循；Responses结构化用户响应使用text.format；函数连接应用时使用function calling；拒绝可程序化检测；达到最大输出Token等会导致不完整。指南也说明首次使用新Schema可能有额外处理延迟。

function calling严格模式指南当前要求每个对象additionalProperties=false、所有properties列入required，可选字段以包含null表达；部分JSON Schema特性不支持。这些都是当前供应商事实，使用前应重新核对。

- Structured Outputs：https://developers.openai.com/api/docs/guides/structured-outputs
- Function calling strict mode：https://developers.openai.com/api/docs/guides/function-calling#strict-mode
- Responses create：https://developers.openai.com/api/reference/resources/responses/methods/create
- Pydantic models：https://docs.pydantic.dev/latest/concepts/models/
- Pydantic strict mode：https://docs.pydantic.dev/latest/concepts/strict_mode/

教材选择在供应商保证之外继续运行时验证，是边界与版本治理的纵深防御，不暗示供应商功能无效。若官方API字段变化，更新适配器、Schema快照与集成测试，不削弱业务层拒绝非法对象的原则。
