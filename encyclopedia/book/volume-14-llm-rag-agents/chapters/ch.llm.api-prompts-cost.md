---
schema_version: 2
edition: 2026.2-draft
id: ch.llm.api-prompts-cost
title: 模型 API、消息、提示、Token 与成本
responsibility: 通过官方 SDK 调用模型 API，建立消息、模型、Token、延迟、成本和提供方错误合同，不把提示技巧当业务正确性证明。
volume: '14'
order: 2
level: L3
status: drafting
path: book/volume-14-llm-rag-agents/chapters/ch.llm.api-prompts-cost.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.llm.model-foundations
- ch.pytorch.foundations
- ch.foundations.http-curl
version_surfaces:
- python-3.14
- openai-api
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
  text: 在 120 秒内解释“模型 API、消息、提示、Token 与成本”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - llm-api-contract
  - llm-prompt-cost
  covers_topics:
  - llm.api-authentication
  - llm.message-roles
  - llm.model-parameter
  - llm.provider-error
  - llm.prompt-version
  - llm.token-usage
  - llm.cost-estimation
  - llm.latency-budget
  uses_capabilities:
  - ai.llm-model-api
  - ml.neural-pytorch
  - python.language
  - foundation.http-message
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现可替换模型客户端，记录提示版本、请求 ID、Token 用量、估算成本与延迟，并保存成功、限流和认证失败证据；独立保存可复现工件与判断结果
  covers_topic_groups:
  - llm-api-contract
  - llm-prompt-cost
  covers_topics:
  - llm.api-authentication
  - llm.message-roles
  - llm.model-parameter
  - llm.provider-error
  - llm.prompt-version
  - llm.token-usage
  - llm.cost-estimation
  - llm.latency-budget
  uses_capabilities:
  - ai.llm-model-api
  - ml.neural-pytorch
  - python.language
  - foundation.http-message
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: official-sdk-call-mock-provider-usage-cost-assertion
- id: diagnose
  kind: fault-diagnosis
  text: 面对“密钥写入源码、忽略模型标识、Token 统计用字符数代替或把 429 当空回答”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - llm-api-contract
  - llm-prompt-cost
  covers_topics:
  - llm.api-authentication
  - llm.message-roles
  - llm.model-parameter
  - llm.provider-error
  - llm.prompt-version
  - llm.token-usage
  - llm.cost-estimation
  - llm.latency-budget
  uses_capabilities:
  - ai.llm-model-api
  - ml.neural-pytorch
  - python.language
  - foundation.http-message
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 模型 API、消息、提示、Token 与成本

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Transformer、Token、上下文与 Embedding 心智模型》](ch.llm.model-foundations.md)：API 参数、上下文和生成结果必须用模型心智模型解释。
- [《Tensor、Dataset、Module 与 Autograd》](../../volume-13-ml-pytorch/chapters/ch.pytorch.foundations.md)：模型 API 能力要求已理解神经网络推理、张量和模型边界，而非把服务视为魔法。
- [《HTTP 报文、方法、状态码、Header、Body 与 curl》](../../volume-00-computer-foundations/chapters/ch.foundations.http-curl.md)：必须先能区分 HTTP 状态、认证、限流、超时和业务输出。
<!-- END GENERATED LEARNING PREREQUISITES -->

模型API不是“把一句话发给聪明机器”这么简单，而是一条跨越业务代码、HTTP、供应商网关、模型推理与计费系统的远程调用链。本章从零建立这条链的工程合同：凭证从哪里来，消息怎样组装，模型标识为何必须显式，提示怎样版本化，Token和成本以什么证据计算，延迟怎样分解，401、429、超时与模型回答怎样分流。提示写得漂亮只能改善概率分布，不能代替权限、校验、事务或测试。

本章同时坚持两层边界。供应商无关层保存消息、请求、用量、错误、预算和追踪等稳定概念；OpenAI Responses API等具体字段属于截至2026-07-24核对过的版本表面。示例和实验全部使用本地Fake，不访问网络、不读取真实密钥、不产生真实账单。只有在学习者主动配置受限测试项目、获准联网并保存脱敏证据后，真实smoke才能另行成立。

## 1. 一次模型请求究竟经过什么

最小数据流可以写成：业务用例决定任务和允许数据；提示构建器按版本生成消息；模型客户端把中立请求映射为供应商SDK参数；HTTP层携带认证、超时与客户端追踪ID；供应商返回响应或错误；适配器提取文本、模型、请求ID、usage和状态；业务层只接收明确的成功值或明确的失败。

这条链中每一段都有不同证据。业务规则错要看用例测试；消息错要看脱敏后的消息快照；401要看HTTP状态和错误码；429要看限流头与请求ID；成本要看响应usage和已注明日期的价目快照；内容是否合格要看评估或结构化校验。把所有问题都归因于“提示词不好”会让排错失去阶段。

一个可维护的返回对象至少区分：业务文本、供应商响应ID、服务端请求ID、实际模型标识、完成状态、输入Token、缓存输入Token、输出Token、延迟、提示版本。字段缺失时记录“未知”，不能拿字符数或本地猜测悄悄补成实际usage。

## 2. 认证：密钥是能力，不是普通配置

Bearer凭证能代表项目调用付费服务，因此其风险接近数据库密码。浏览器、Vue、uni-app和Flutter安装包都可被用户检查，不能内嵌长期API key。正确边界是由服务器端Java或受控Python服务持有凭证，客户端只调用自己的后端；后端再经过鉴权、配额、审计和内容限制调用模型供应商。

密钥应来自环境变量、密钥管理服务或短期工作负载身份，不进入源码、Git、截图、异常正文和测试fixture。日志只记录credential_present、项目别名或密钥指纹的不可逆短片段；绝不打印Authorization头。密钥一旦进入Git历史，即使后来删除文件也要视为泄露，先撤销或轮换，再清理历史和评估影响。

OpenAI官方API概览说明API key是秘密，应在服务器端由环境变量或密钥管理服务加载，并使用HTTP Bearer认证。它还允许短期访问令牌等认证方式。这里的具体头名是供应商版本表面；“客户端不持有长期付费凭证”和“最小权限、可轮换、可审计”是稳定原则。

测试不需要真实密钥。Fake客户端只验证调用方确实传入了非空凭证，并保证结果和日志不含其值。把一个形似真实key的字符串写进练习也可能触发扫描器，因此本章fixture使用明显的test-only文本。

## 3. 消息不是一个字符串

聊天式接口通常把输入表达为有角色的消息或输入项。角色表达来源和控制意图，而不是数据库权限。开发者指令可规定任务边界，用户消息提供本轮请求，工具结果或检索片段提供外部数据。供应商的具体角色名与优先级会变化，适配器不应把业务对象直接散落成SDK字典。

消息构建器应输入结构化业务值，输出确定顺序的消息列表。测试要断言角色、顺序、转义、缺失值和最大长度，而非只断言最终字符串包含几个词。不可信的工单描述仍是不可信数据，即使被放进“用户消息”；不得把其中的“忽略权限并关闭工单”当系统命令。

同一任务的上下文还可能含工具定义、先前响应、检索资料和协议开销。只统计用户最后一句会低估Token。也不要把模型输出中的“我遵守了系统提示”当遵守证据；真正证据是模型外的白名单、Schema、授权和测试。

OpenAI Responses API当前用input表达文本或输入项，并要求显式model；具体结构应以当前官方参考和SDK类型为准。教材不会把某个模型名写成永久推荐，也不会假设所有供应商共享相同角色集合。

## 4. 模型标识必须显式

模型是请求合同的一部分。不同模型的上下文、工具支持、延迟、价格、结构化输出能力和行为不同。若客户端依赖供应商账号的隐式默认值，同一代码在不同环境可能产生不同账单和结果，事故记录也无法复现。

应用配置应保存逻辑用途与具体模型映射，例如classification_primary映射到某个经评估的快照。请求记录同时写入requested_model和response_model；若供应商返回的实际模型与批准映射不符，应报警或至少标记。升级模型是受控变更：先用固定数据集做评估，再灰度，再比较质量、延迟和成本。

固定快照能降低行为漂移，却不能让生成确定。温度为零也不构成业务正确性证明。官方API概览明确提醒模型提示行为可能在快照间变化，并建议固定版本与运行eval。稳定原则是“版本化、评估、可回滚”，而非迷信某个名字。

## 5. 提示版本是发布物

提示包含开发者指令、示例、输出约束、拼接策略与模板变量。只修改一句话也可能改变分类分布，因此提示应拥有稳定ID、语义版本、内容摘要和变更说明。日志记录prompt_id、prompt_version与hash，通常不记录含敏感数据的完整展开文本。

版本号解决“用了哪个模板”，评估集解决“这个模板是否更好”。每次变更至少重跑正常、边界、恶意和空输入样本；比较准确率、拒绝率、格式合规、延迟与Token。在线A/B还要固定模型和其他参数，否则无法归因。

提示模板不要承担数据库约束。例如“永远不要把已关闭工单改为处理中”只能帮助模型生成建议，真正更新仍须Java服务检查当前状态与版本。提示也不能承担访问控制、金额上限或人工审批。

若使用供应商托管的prompt对象，其对象ID和版本仍应映射到内部发布记录。不要因模板在控制台里就失去Git可审计的测试、变更理由和回滚映射。

## 6. Token usage：证据来自分词与响应

字符、字节、词和Token是不同单位。中文、英文、代码、空格与随机ID的Token比例不同；模型使用的Tokenizer也可能不同。因此len(prompt)只能得到Python字符数量，不能写进actual_input_tokens。

调用前估算用于预算与拒绝过大输入，应使用与目标模型兼容的Tokenizer或供应商计数接口，并注明它是estimate。调用后记账应优先使用响应usage。常见维度包括input_tokens、cached_input_tokens、output_tokens、total_tokens，推理模型还可能暴露更细分字段。字段集合属于版本表面，适配器要允许新增字段而不污染业务模型。

一致性检查可以验证非负、cached不超过input，以及在供应商定义允许时total与分项关系合理。但不要自创公式覆盖官方字段。若流式响应的usage只在终态出现，中途断流就应记录usage_unknown或供应商账单待对账，而不是用已显示字符倒推。

Token记录还应关联request_id、model、prompt_version和租户。聚合时才可回答哪个用例成本上升、是输入膨胀还是输出变长、缓存是否生效。只保存一个总金额会失去诊断能力。

## 7. 成本估算与账单不是一回事

成本估算的输入是usage、模型和带生效日期的价格快照。价格表至少区分输入、缓存输入和输出单价；工具、存储、批处理或服务等级可能另计。用Decimal按每百万Token换算，避免二进制浮点累计误差。公式是各类Token乘对应单价再除计价单位，最后按内部财务精度取整。

价格会变化，教材不把具体美元数字写成永久事实。代码把价格当外部版本化数据，包含provider、model、currency、effective_at、source_url和checked_at。历史请求必须用当时快照复算，不能用今天价格重写旧报表。

estimated_cost表示应用按可见usage估算；billed_cost来自供应商账单或usage导出。两者不同并不自动说明Bug，可能有免费额度、缓存规则、四舍五入、工具费或延迟入账。生产对账应保存差异与解释，不把估算冒充账单。

预算可分请求上限、用户日限额、项目月限额和告警阈值。到达上限后的策略必须明确：拒绝、缩短上下文、选经批准的低成本模型或转人工。偷偷降级模型会让质量合同失真。

## 8. 延迟预算不是一个秒表数字

端到端延迟包括排队、DNS/TLS、上传、供应商排队、首Token生成、流式传输、解析校验和业务后处理。非流式关注总时长；流式还应关注time_to_first_event与time_to_last_event。客户端计时使用单调时钟，墙上时间只用于事件时间戳。

超时要分连接、首字节/首事件、单次读取和总预算。只设置一个很大的timeout会让用户取消后后台仍占资源；只设置很小总超时会截断合法长回答。预算耗尽是传输失败，不是空模型回答。

延迟SLO应按用例和分位数观察。平均值会掩盖长尾。记录p50、p95、p99时同时按模型、区域、提示版本和成功/失败分类。慢请求可能仍计费，超时后是否重试需结合幂等性和剩余预算。

Fake测试用可注入时钟产生确定延迟，不用sleep制造脆弱测试。真实smoke若进行，要记录网络环境与时间，不能拿一次快速调用证明生产SLO。

## 9. 错误是独立通道

至少区分：本地配置错误、认证失败、授权失败、请求校验失败、限流、供应商服务错误、网络超时、取消、内容拒绝、响应不完整、结构校验失败。它们的用户提示、重试策略、告警等级和责任方不同。

401通常要求修复或轮换凭证，不应重试风暴；400通常要修请求；429可能是速率限制或额度问题，应检查错误码与限流信息；5xx和部分网络错误可能在预算内重试；用户取消必须传播；模型拒绝是一个可处理结果状态，不是伪造默认答案。

HTTP 200也不保证业务成功，可能返回拒绝、不完整或格式错误。反过来，429绝不是模型回答为空字符串。若适配器把异常catch后返回空串，上层无法区分“模型真的输出空”与“请求根本没成功”，还可能把空串写进业务数据库。

OpenAI官方文档建议记录x-request-id用于排障，并允许显式发送X-Client-Request-Id以便在超时没有响应头时追踪。具体头名属于当前版本表面；稳定原则是同时维护服务端追踪ID和调用方相关ID，并做长度与字符约束。

## 10. 可替换客户端的最小设计

业务层依赖ModelClient协议，而非到处导入某家SDK。中立请求包含model、messages、prompt_version、max_output_tokens、timeout_budget和client_request_id；中立成功值包含text、status、usage、request_id和actual_model；中立失败用类型或Result表达，不塞进text字段。

供应商适配器负责字段映射和异常翻译。它可以读取SDK顶层响应的请求ID、usage和状态，但不得把整个SDK对象穿透所有层。这样单元测试可用ScriptedClient覆盖成功、401、429与超时，切换供应商时业务用例不重写。

抽象不是把所有供应商能力压成最低公分母。通用字段放核心，供应商特性放显式capabilities或扩展配置。若某模型不支持严格Schema，启动时能力检查应失败，而非运行中悄悄退化。

重试最好位于知道错误类别与幂等性的边界。SDK可能内建重试，应用也可能重试；两层叠加会放大次数。记录attempt、总预算和最终原因，并确认当前SDK默认行为。

## 11. 可观测性与隐私

一条请求记录推荐包含：内部trace_id、client_request_id、provider_request_id、tenant_id哈希、use_case、model、prompt_version、状态、错误类别、各类Token、估算成本、首事件与总延迟、重试次数。敏感文本默认不进入普通日志。

若必须保存提示/输出做评估，应建立单独受控数据集：最小化字段、脱敏、加密、访问审计、保留期限与删除机制。不要在ERROR日志里直接拼接供应商异常对象，因为异常可能带请求片段或头。

指标使用低基数字段；request_id适合日志追踪而不适合作为指标标签。错误码可做有限枚举，原始message放受限日志。成本告警同时看绝对金额和每成功业务动作成本，避免只因流量增长误报。

本地实验日志要明确provider=fake、billing=false、network=false。没有真实调用就不能把req_local_1写成供应商证据，也不能声称已验证认证、实际usage或真实费率。

## 12. 测试金字塔与证据边界

纯函数测试覆盖价格计算、消息构建、错误分类和脱敏。契约测试用Fake固定响应，断言model、prompt_version、request_id与usage原样流转。故障测试注入401、429、超时和缺字段。集成测试可在受控环境对SDK序列化或HTTP Mock。真实smoke最少且手动授权。

成功Oracle不能只有进程退出0。还要看到固定消息、实际传入model、usage分项、Decimal成本、错误没有变成文本、日志没有密钥。失败Oracle则要指向首个可信阶段：compile/import、配置、HTTP、provider、parse或business。

真实smoke的前置条件包括：专用低权限项目、限额、允许的测试数据、显式模型、超时、清理计划和证据目录。输出必须脱敏。若这些条件未满足，正确做法是标记not-run，而不是伪造截图或把Mock结果改名。

本章的verify脚本只证明本地Python3.14契约。它没有联网，不证明OpenAI账户可用，不证明当日价格，不证明任何模型质量，也不证明生产延迟。

## 13. FactoryCare场景拆解

任务是“依据故障描述建议工单类别”。Vue或uni-app把描述提交给Java后端；Java做用户鉴权、租户隔离、字段长度和工单访问检查；受控AI适配服务构造版本化消息；模型只返回建议；结构化校验通过后，Java仍依据业务规则决定是否保存。

这里Java系统继续是工单事实边界。Python/模型不能直接把建议写成最终状态，也不能根据自然语言绕过资源级授权。模型请求记录使用工单的不可逆追踪引用，不上传不必要的姓名、电话与内部密钥。

一次成功记录可以是：use_case=work_order_category、prompt=category-v3、requested_model=approved-snapshot、response_model=same、provider_request_id存在、usage来自Fake或真实响应、cost_snapshot带日期、status=completed。一次429记录没有text，含retryable判断和request_id，且上层展示“服务繁忙”而不是空分类。

上线前的评估集应含机械、电气、模糊、多故障、恶意指令和无关文本。分类准确率之外还看未知率、格式失败率、每例Token、p95延迟和敏感信息暴露。提示升级必须与旧版对照。

## 14. 常见故障定位表

|现象|失败阶段|首个可信证据|禁止做法|修复方向|
|---|---|---|---|---|
|本地能跑，线上401|认证/项目|HTTP状态、错误码、request_id|重试到成功|核对密钥来源、项目和权限并轮换|
|请求偶发429|限流或额度|错误码、限流头、usage面板|返回空串|分类、退避、抖动、预算与容量治理|
|账单高于预期|用量/价格|响应usage、模型、价格快照|用字符数争辩|按分项复算并与账单对账|
|同版本输出变化|模型概率/快照|requested与actual model、eval|声称温度零必然相同|固定快照、评估与容错|
|日志泄露密钥|日志边界|扫描结果与具体字段|只删除最新提交|立即轮换、清史、收紧日志|
|超时被记成空回答|适配器|异常路径与返回对象|默认text=""|独立失败类型并保留相关ID|
|成本字段为空|供应商/终态|响应status与usage字段|len(text)补实际值|标记unknown并后续对账|
|提示修改后质量降|发布治理|prompt_version与评估差异|继续微调一句碰运气|回滚版本、定位样本与重新评估|

## 15. 概念卡：容易混淆的成对术语

### 15.1 字符数与Token数

字符数由语言运行时计算；Token数由特定Tokenizer与协议决定。前者可做文本长度限制，不能冒充后者。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.2 估算usage与实际usage

估算用于请求前预算，实际usage来自供应商响应或账单。两者应分字段，不能互相覆盖。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.3 估算成本与结算账单

前者由本地价目快照复算，后者由供应商结算系统给出。差异需要对账而非静默改数。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.4 提示版本与模型版本

提示版本描述模板发布物；模型版本描述推理服务。实验必须同时固定，才能解释变化来源。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.5 请求ID与业务ID

请求ID定位一次供应商调用；业务ID定位工单等实体。二者通过trace关联，不应相互替代。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.6 服务端请求ID与客户端请求ID

前者由供应商响应生成；后者在发出前由调用方生成，超时拿不到响应时仍可追踪。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.7 错误与回答

错误表示调用链未满足合同；回答是完成状态下的模型输出。错误绝不能编码成看似正常的空文本。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.8 拒绝与传输失败

拒绝通常是模型安全结果状态；传输失败是网络或服务错误。UI、重试与审计策略不同。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.9 模型能力与业务授权

模型可能知道如何关闭工单，不代表调用者被授权关闭。授权永远在可信服务重新检查。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.10 缓存输入与普通输入

供应商可能对可复用前缀按不同规则计费；必须使用响应usage和当前价目，而非自行猜中缓存。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.11 总延迟与首事件延迟

总延迟衡量完成等待，首事件延迟衡量流式感知速度。优化一个不保证另一个变好。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.12 SDK异常与领域异常

SDK异常包含供应商细节；领域异常给上层稳定语义。适配器映射时保留status、code与request_id。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.13 可替换与能力抹平

可替换是隔离依赖；不是假装所有模型都有相同Schema、工具、流式与上下文能力。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.14 日志与评估数据集

日志用于运行诊断且应少文本；评估集用于质量分析且需更严数据治理。不能把普通日志当训练仓库。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.15 HTTP成功与业务成功

200只说明协议请求被接受并有响应；拒绝、不完整、结构错误仍可能使业务失败。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.16 提示技巧与正确性证明

提示技巧提高满足要求的概率；正确性由Schema、规则、测试、授权与人工确认建立。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.17 价格常量与价目快照

代码常量会过期且无法解释历史；快照带模型、币种、生效日、来源与校验日期。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.18 自动重试与可用性

有限、分类的重试可吸收瞬态故障；无限重试会放大限流、延迟和费用。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.19 脱敏与删除

脱敏是在采集/展示时减少敏感值；删除是生命周期操作。二者都需要验证，不能只依赖一条正则。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

### 15.20 本地Mock与真实smoke

Mock证明本方映射和分支；真实smoke才可能证明凭证、网络和当前服务，但仍不证明模型质量。在代码审查中先问“这个字段的证据来自哪里”，再决定是否允许进入业务记录。

## 16. 分阶段实操

第一阶段运行example，手工复算1000输入、其中400缓存、250输出在fixture费率下的Decimal结果。改变一个费率，解释为什么历史请求必须绑定快照。第二阶段运行lab，观察成功、401与429如何走不同通道；确认Fake记录credential_present但不保存secret。

第三阶段在可编辑 `exercise.py` 中观察删掉 model、用 `len(prompt)` 代替 provider usage、把 RateLimited 改成空完成态的 starter。先预测失败测试，再运行 public exercise：精确 starter 得到 `EXPECTED_RED`/41；修复后原验证器得到 `EXERCISE_GREEN`/0；partial、unknown 或基础设施失败得到 43。第四阶段阅读 private solution，只比较边界，不复制答案；恢复后再次运行原验证。

最后写一页证据说明：本地验证了哪些纯函数和契约，哪些真实能力未验证；列出需要真实smoke时的授权、预算、数据和回滚条件。能够主动写出“未验证”比生成一张无法复现的成功截图更专业。

## 17. 自测题

1. 为什么前端不能持有模型供应商长期密钥？请同时从逆向、计费、权限与轮换回答。
2. 同一字符串的字符数能否换算为固定Token数？若只能估算，估算与actual字段怎样命名？
3. 为什么429不能转成空回答？这会让哪些上层状态被混淆？
4. 一次请求至少应记录哪两个请求ID？超时没有响应时哪个仍可用？
5. 提示版本和模型版本为什么必须同时记录？怎样做一次可归因升级？
6. estimated_cost与billed_cost不相等时，先查哪四类证据？
7. Fake契约测试通过能证明什么，不能证明什么？
8. 如果SDK已有自动重试，应用再重试有什么放大风险？
9. 模型建议“关闭工单”时，为什么仍由Java服务执行业务状态机？
10. 给出一个HTTP 200但业务失败的例子，以及它的正确错误类型。

## 18. 120秒复述模板

我会把模型API描述成不可信远程依赖。服务器端从安全来源取得凭证，业务用例生成带版本的消息并显式选择经评估模型，适配器调用SDK后提取完成状态、模型、请求ID和供应商usage。Token不能用字符数代替；成本用带日期的价目快照和Decimal估算，账单另行对账。401、429、超时、拒绝、不完整和结构失败必须走独立通道，不能伪装成正常文本。提示只能影响生成概率，权限、Schema、状态机和正确性仍在模型外。当前本地资产只验证Fake合同，没有真实密钥、调用、账单或模型质量证据。

## 19. 官方版本表面与复核入口

截至2026-07-24，本章核对了OpenAI官方API概览、Responses创建参考、错误码与限流指南。API概览给出Bearer认证、服务端环境保存密钥、x-request-id与X-Client-Request-Id；Responses参考显示model、input、stream、tools和usage等当前表面；限流指南建议带随机抖动的指数退避并限制最大重试。价格必须在使用当天重新查看官方定价页，教材不固化当前数字。

- OpenAI API Overview：https://developers.openai.com/api/reference/overview
- Responses create：https://developers.openai.com/api/reference/resources/responses/methods/create
- Error codes：https://developers.openai.com/api/docs/guides/error-codes
- Rate limits：https://developers.openai.com/api/docs/guides/rate-limits
- Pricing：https://openai.com/api/pricing/

这些链接支持具体供应商事实，不改变前文的供应商无关原则。若字段、模型或价格与教材不同，以复核后的官方文档、固定测试与迁移记录为准。
