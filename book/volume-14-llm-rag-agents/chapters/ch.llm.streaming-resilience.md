---
schema_version: 2
edition: 2026.2-draft
id: ch.llm.streaming-resilience
title: 流式输出、重试、超时、取消与降级
responsibility: 为模型流式响应实现有界超时、取消、可重试分类和降级，区分部分输出与完整承诺，不重复提交副作用。
volume: '14'
order: 4
level: L3
status: drafting
path: book/volume-14-llm-rag-agents/chapters/ch.llm.streaming-resilience.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.llm.api-prompts-cost
- ch.python.asyncio-cancellation
version_surfaces:
- python-3.14
- model-api
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
  text: 在 120 秒内解释“流式输出、重试、超时、取消与降级”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - llm-stream-state
  - llm-resilience-policy
  covers_topics:
  - llm.stream-event
  - llm.partial-output
  - llm.completion-marker
  - llm.client-backpressure
  - llm.timeout-budget
  - llm.retry-classification
  - llm.cancellation
  - llm.fallback-policy
  uses_capabilities:
  - ai.llm-model-api
  - python.asyncio-cancellation
  - foundation.http-message
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“流式输出、重试、超时、取消与降级”构建可运行程序与测试：实现可取消的流式聊天适配器，模拟首字节超时、中途断流、429 重试、用户取消和非流式降级；独立保存可复现工件与判断结果
  covers_topic_groups:
  - llm-stream-state
  - llm-resilience-policy
  covers_topics:
  - llm.stream-event
  - llm.partial-output
  - llm.completion-marker
  - llm.client-backpressure
  - llm.timeout-budget
  - llm.retry-classification
  - llm.cancellation
  - llm.fallback-policy
  uses_capabilities:
  - ai.llm-model-api
  - python.asyncio-cancellation
  - foundation.http-message
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: scripted-stream-server-cancellation-test-retry-budget-test
- id: diagnose
  kind: fault-diagnosis
  text: 面对“取消后后台继续消费、对所有错误重试、把半截文本标成完成或重试重复执行工具副作用”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - llm-stream-state
  - llm-resilience-policy
  covers_topics:
  - llm.stream-event
  - llm.partial-output
  - llm.completion-marker
  - llm.client-backpressure
  - llm.timeout-budget
  - llm.retry-classification
  - llm.cancellation
  - llm.fallback-policy
  uses_capabilities:
  - ai.llm-model-api
  - python.asyncio-cancellation
  - foundation.http-message
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 流式输出、重试、超时、取消与降级

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《模型 API、消息、提示、Token 与成本》](ch.llm.api-prompts-cost.md)：流式传输仍需沿用模型 API 的认证、usage 和提供方错误分类。
- [《asyncio、Task、超时、取消与结构化并发边界》](../../volume-12-python-data/chapters/ch.python.asyncio-cancellation.md)：流迭代、超时与取消必须基于结构化异步任务和清理合同。
<!-- END GENERATED LEARNING PREREQUISITES -->

流式响应让用户更早看到内容，却把一次“返回字符串”的调用变成事件协议和状态机。第一段文字出现只表示收到部分输出；连接关闭不自动表示完成；取消界面不自动停止后台任务；重试读取可能重复模型费用，重试工具调用更可能重复副作用。本章把这些隐含风险变成显式合同。

稳定核心是：按事件类型处理、部分与完成分离、超时有总预算、重试只覆盖可重试且安全的阶段、取消向下传播、降级是可观测策略、所有副作用拥有幂等边界。OpenAI Responses API当前的SSE事件名作为版本表面单独说明。实验使用本地异步生成器，不访问网络，也不声称验证真实首Token延迟或服务端取消。

## 1. 为什么流式不是“边到边print”

非流式函数通常在全部响应可用后返回成功或异常。流式函数会连续产生created、delta、完成、失败等事件。调用方必须维护状态：pending、streaming、completed、partial、failed、cancelled。文本只是状态中的一个字段。

若代码对每个event都执行text += delta，迭代结束就返回completed，它假设“正常结束等于服务承诺完成”。中途代理断开、SDK异常被吞或测试生成器提前结束时，这个假设会把半句话标成完整答案。正确完成需要显式终态事件或等价协议字段。

流式还改变UI语义。partial可展示为临时草稿，但不能入库为最终分类、不能触发工具、不能生成“已完成”审计。终态到达并通过结构校验后，才可提交最终值。

## 2. 事件是带类型的协议

事件消费者先按type分派，再读取该类型允许的字段。未知事件应记录并忽略或按兼容策略处理，不能假设都含delta。created可携带响应标识；output_text.delta追加显示文本；completed确认终态；error进入失败路径。

截至2026-07-24，OpenAI迁移指南说明Responses流式使用有类型的Server-Sent Events，文本常见事件包括response.created、response.output_text.delta、response.completed和error。函数参数流还可能有response.function_call_arguments.delta与done。名称和字段属于当前API版本表面。

SSE是单向事件传输格式，不等于业务状态机。HTTP连接、SDK迭代器和业务响应各有生命周期。应用适配器把供应商事件翻译成少量中立事件，UI不应直接依赖所有供应商类型。

事件序号、output item索引与call_id若存在，应保存用于去重和关联。不要把网络分片当语义事件；一个UTF-8字符或JSON字段可能跨分片，解析由成熟SDK或SSE解析器负责。

## 3. 部分输出与完整承诺

部分文本可带status=streaming或partial，并在UI显示光标。它必须带清晰视觉状态，屏幕阅读器更新也应节制。若失败，UI可以保留灰色“未完成草稿”供用户参考，也可以清除；产品策略应明确。

完整承诺至少要求收到completed终态、内容项完整、结构化输出通过Schema、未发生取消，必要时usage到达。任何一项缺失都不能把complete=true写入记录。

半截JSON最危险。它可能暂时能解析成另一个合法值，或在断点前已包含高风险字段。绝不能在每个delta后尝试解析并执行业务。工具调用参数也要等明确done事件，再完整解析、授权、确认与幂等执行。

若供应商返回incomplete终态，应保存原因并进入独立分支。输出长度上限导致的不完整与网络断流不同，但二者都不是成功。

## 4. 状态机设计

推荐转换：pending收到created转streaming；streaming收到delta保持streaming并追加；收到completed转completed；收到error转failed；本地取消转cancelled；迭代无终态结束转partial。终态之后的事件应拒绝或记录协议异常。

状态机应是纯reduce函数，输入旧状态与事件，输出新状态。测试覆盖合法转换、重复终态、未知事件、终态后delta和无终态结束。这样UI与网络读取分离，排错能指出是解析、状态还是展示问题。

状态对象可含response_id、provider_request_id、chunks、status、finish_reason、usage、started_at和completed_at。不要只存一个StringBuilder，否则取消与失败信息无处表达。

最终持久化使用不可变快照，流式中的可变buffer只在请求范围内。并发读写要在单一任务或明确同步边界中发生。

## 5. 背压：生产者比消费者快

模型事件可能比前端渲染、数据库写入或WebSocket发送快。若每个Token触发Vue重渲染、Flutter setState或数据库insert，CPU与网络开销会放大。若无界队列积压，内存会随慢客户端增长。

常见策略是合并短时间窗口内的delta、限制队列容量、丢弃非关键展示更新但保留最终文本，或在下游断开时取消上游。不能丢失completed、error、usage和工具参数done等控制事件。

背压策略需要上限与指标：queue_depth、coalesced_events、dropped_display_updates、client_disconnects。最终文本应从可靠buffer构建，而非依赖可能丢帧的UI更新。

SSE到浏览器后还可能经过反向代理缓冲。真实首事件测试要检查代理配置；本地async生成器只能证明消费者逻辑，不能证明生产网络即时刷新。

## 6. 超时是一组预算

至少考虑连接超时、首事件超时、事件间空闲超时与总超时。连接超时限制建立通道；首事件超时保护用户长时间无反馈；空闲超时发现卡住；总超时限制整次资源占用。具体值由用例SLO决定。

所有局部等待共享总deadline。每次重试不能重新获得完整60秒，否则两次重试变成180秒。计算remaining=deadline-monotonic_now，若不够下一次尝试就停止。使用单调时钟避免系统时间调整。

首事件超时前没有可见输出时，可以选择同模型非流式降级；已有部分输出后再降级可能让用户看到两份不同回答，默认不做。降级不是catch-all，它只对批准的故障和剩余预算生效。

超时后必须关闭响应体/异步迭代器并取消子任务。只向UI返回“超时”而后台继续消费仍会占连接、Token处理和内存。

## 7. 重试分类

可重试通常是瞬态限流、部分5xx、连接建立失败等；不可重试通常是无效认证、请求Schema错误、权限拒绝与用户取消。实际分类要结合供应商错误码和HTTP语义，不只看message字符串。

OpenAI限流指南当前建议随机指数退避，并设置最大重试次数；失败请求也可能消耗每分钟配额，因此快速重复只会恶化429。抖动避免多个实例同一时刻再次冲击。

重试还要看“是否已有可见输出”和“是否含副作用”。首事件前的纯生成可在预算内重试；收到delta后重试会产生不同续写，若直接拼接会混合两次回答。默认把中途断流标partial并让用户显式重试。

SDK可能自动重试，应用重试前确认配置。三次SDK尝试外层再三次会最多九次。记录attempt、delay、error_class和remaining_budget。

## 8. 幂等性与副作用

纯文本生成重复调用主要增加成本和产生不同结果；工具副作用重复调用可能关闭两次工单、发两封邮件或重复扣款。流式传输重试不能包住“读取事件并立即执行工具”的整个循环。

正确流程先完整收集工具调用参数并验证；为业务动作生成幂等键；在Java事实服务执行原子去重；保存结果封套；若模型回合重放，相同键返回原收据。call_id可用于关联，但是否适合作业务幂等键要结合供应商重放语义，通常使用内部动作键更稳。

幂等不等于永远忽略重复。相同键不同参数必须冲突报警；键有作用域和保留期；数据库唯一约束或幂等表是最终证据。内存set只适合测试。

读工具也需授权，但通常无副作用；高风险写工具还要人工确认。下一章展开工具信任边界，本章只确保重试层不会未经意重复执行。

## 9. 取消的传播方向

用户点击停止、页面离开、客户端断连或上层deadline到达，都应触发取消。Python asyncio中取消通过CancelledError传播；捕获Exception的具体继承行为会随版本语义影响，但最佳做法是显式保留取消，清理后重新抛出。

取消链为UI/HTTP请求→编排任务→SDK流迭代器/响应体→子任务。每层使用try/finally关闭资源。结构化并发让父任务能找到全部子任务；随手create_task而不持有引用容易成为孤儿。

取消后不能自动fallback，因为这会违背用户“停止”的意图。也不应重试。日志状态是cancelled而非failed，指标与告警分开。

mounted、组件销毁或布尔标记只能防止UI更新，不能自动取消网络请求。Vue的AbortController、Flutter HTTP客户端取消机制或服务端上下文都必须显式接线。

## 10. 降级策略

降级选项可能是非流式同模型、经评估的备用模型、缓存答案、只读搜索结果或人工处理。每个选项改变质量、延迟、成本和功能，必须配置化、可观测和可关闭。

非流式降级适合首事件超时且尚无输出；备用模型需要独立Schema与评估；缓存只适合键和时效明确的任务；人工处理要给出队列和用户预期。返回空串不是降级。

结果记录fallback_used、from_mode、to_mode、reason和attempts。UI可适度说明“已切换到完整响应模式”，避免把体验变化误认为故障。

降级不能绕过安全策略。若严格结构化模型不可用，不应改用不支持Schema的模型再直接执行业务；最多返回建议文本或转人工。

## 11. 错误与终态

状态至少有completed、partial、failed、cancelled和incomplete。failed可带transport、provider、timeout或protocol分类。partial表示有文本但无完成承诺；incomplete可保留供应商明确给出的不完整原因。

连接自然EOF不是completed；error事件不是delta；HTTP 200开始流也不保证最终成功。usage可能只在终态可用，中途失败时标unknown并后续与账单对账。

对外API可返回事件封套：type、request_id、sequence、data。错误事件不含敏感原文，完成事件包含最终hash/usage。断线重连若支持resume，需要明确序号与存储策略，不能凭客户端最后文本猜接点。

监控分别统计completion_rate、partial_rate、cancel_rate、first_event_timeout_rate和fallback_rate。把所有非完成合成“500”会失去治理信息。

## 12. 本地可复现异步测试

真实sleep让测试慢且抖动。优先使用ScriptedProvider、asyncio.Event、可注入时钟和极短受控timeout。脚本事件可模拟delta、completed、error、延迟与提前EOF。

测试429→成功时，第一尝试必须在任何delta前失败，并断言stream_calls=2。测试401时断言只调用一次且fallback_calls=0。测试首事件超时断言关闭迭代器并使用显式fallback。

取消测试创建任务，允许它进入等待，再cancel并断言CancelledError传播、任务done、fallback为零。若有子任务，检查集合为空。中途断流测试断言text保留但status=partial。

本章lab使用本地异步生成器，事件名是fixture。它不验证SSE解析、代理缓冲、真实服务重试头、真实账单或服务端是否立即停止推理。

## 13. FactoryCare端到端边界

用户在Vue页面发起“解释工单”，Java建立经过鉴权的流式端点并调用AI适配器。前端AbortController在路由离开和停止按钮触发；Java感知客户端断开后取消上游；Python适配器关闭SDK流。

UI把delta放临时区域，只有completed且结构验证通过才启用“采纳建议”。partial显示未完成标签，不能保存为最终分类。若用户取消，不显示fallback。

若流中出现关闭工单工具意图，编排器只收集参数；完整done后才进入白名单、Schema、资源授权、人工确认和幂等执行。任何流重试都不直接包围Java写操作。

监控按tenant、use_case和模型聚合，但request_id只进日志。压测慢客户端和断连，验证队列上限、上游取消与无孤儿任务。

## 14. 故障注入矩阵

|注入|期望状态|是否重试|是否降级|关键断言|
|---|---|---|---|---|
|首事件前429|pending/failed暂态|预算内是|可配置|无delta、尝试有上限|
|首事件前401|failed|否|否|只尝试一次|
|首事件超时|failed或fallback|通常不重试相同流|可非流式|原迭代器关闭|
|收到文本后断流|partial|默认否|默认否|不标completed|
|显式error事件|failed|按错误类|按策略|错误不进入text|
|用户取消|cancelled|否|否|CancelledError传播|
|客户端断连|cancelled|否|否|上游任务终止|
|无终态EOF|partial|否|否|保留草稿但禁止提交|
|completed后又delta|protocol_error|否|否|状态机拒绝非法转换|
|工具执行后网络断|动作状态未知/查收据|不盲重放|否|幂等键查询|

## 15. 常见错误代码审查

错误写法一是while True加except Exception，它无限重试认证、Schema和取消。错误写法二是async for结束即completed，它混淆EOF。错误写法三是每个delta执行工具，它将不完整参数和重放引入副作用。

错误写法四是取消只设置isCancelled变量，却不cancel任务或关闭响应。错误写法五是队列无界。错误写法六是已有部分文本后切备用模型并拼在一起。错误写法七是超时每次重试重置。

审查时沿资源所有权问：谁创建任务，谁关闭流，谁消费终态，谁持有deadline，谁决定重试，谁保证动作幂等。任何答案是“SDK应该会处理”都要用当前文档和测试确认。

## 16. 概念卡：异步与韧性边界

### 16.1 网络分片与语义事件

分片是传输单位，事件是协议单位。不要自行按字符串换行猜完整JSON。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.2 delta与最终文本

delta用于增量展示，最终文本要由可靠buffer和终态共同确定。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.3 EOF与completed

EOF只说明迭代结束；completed是协议承诺。缺少后者应标partial。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.4 partial与failed

partial包含可展示前缀但不可提交；failed可能没有任何文本。产品可分别呈现。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.5 incomplete与断流

incomplete是供应商明确终态，断流是传输异常；两者原因不同但都非完成。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.6 首事件超时与总超时

前者保护感知响应，后者限制整个资源预算。二者共享deadline。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.7 超时与取消

超时由预算触发，取消由上层意图触发；清理相似但重试/降级策略不同。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.8 取消与隐藏UI

隐藏组件只阻止显示，取消必须传播到实际网络与子任务。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.9 重试与循环

重试是分类、有上限、有预算的状态转换，不是catch-all while True。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.10 退避与抖动

退避逐次拉长间隔，抖动打散并发客户端；两者都不能替代容量治理。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.11 SDK重试与应用重试

两层次数会相乘，必须核对默认值并统一总attempt记录。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.12 降级与吞错

降级返回明确替代能力并记录原因；吞错返回看似正常的空值。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.13 背压与限流

背压处理单条流中消费速度；限流控制请求/Token速率。二者不相同。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.14 合并UI更新与丢文本

可以减少渲染次数，但最终buffer不能依赖被丢弃的显示事件。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.15 幂等与去重

幂等保证重复请求同效果；简单去重可能没有原结果或参数冲突处理。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.16 call_id与幂等键

call_id关联模型工具事件；业务幂等键由可信系统定义作用域和一致性。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.17 本地任务结束与服务端停止

关闭客户端任务不自动证明供应商已停止推理或计费，真实行为需官方合同和证据。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.18 请求状态与UI状态

网络流可能streaming，UI也可能background；不要用一个loading布尔表达所有状态。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.19 错误事件与异常

SDK可能把协议error转成异常或事件；适配器归一化但保留原始类别与request_id。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.20 可见草稿与业务记录

草稿可以帮助用户，但必须标记未完成且禁止驱动自动动作。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.21 响应usage与中断估算

终态usage是证据；中断时标unknown，不能按已收字符伪造。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.22 真实延迟与Fake延迟

Fake证明控制流；真实SLO还受网络、代理、区域、模型负载影响。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.23 结构化并发与孤儿任务

父作用域拥有子任务并统一取消；裸create_task若失去引用会在请求后继续运行。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

### 16.24 恢复与重放

恢复需要协议支持的序号/状态；重新请求是新的生成，不能伪装成原流续传。写测试时同时断言状态、调用次数和资源清理，避免只比较最终字符串。

## 17. 实操路线

先运行example，把最后一个completed删掉，预测state为何仍是streaming而不是completed；然后为reduce_event增加终态后delta的拒绝测试。理解状态机后再看异步网络。

运行lab的五组场景，画attempt时间线。将429改为401，预测stream_calls、fallback_calls；将中途EOF放在一个delta后，确认得到partial。为取消测试增加已完成任务基线，避免把自然完成误判为取消成功。

运行public exercise取得EXPECTED_RED与41。按顺序修复有界尝试、错误分类、显式终态、CancelledError传播和副作用移出重放区。每一步都重跑原测试，保留最先失败证据。

最后设计FactoryCare慢客户端实验：队列容量、合并窗口、断连动作、上游取消和指标。没有真实环境时只写计划并标not-run，不编造代理或供应商结果。

## 18. 自测题

1. 为什么async for自然结束不能标completed？
2. 收到半截文本后为什么默认不自动从头重试并拼接？
3. 401与429的重试策略有何不同？
4. 总deadline怎样防止每次重试重置预算？
5. 用户取消后为什么不能fallback？
6. mounted或组件销毁能否取消网络？还需要什么？
7. 哪些事件可以合并显示，哪些控制事件不能丢？
8. SDK三次重试加应用三次为什么可能产生九次？
9. 工具副作用为什么不能放在流读取重试循环里？
10. 如何用测试证明没有孤儿任务？
11. 中途失败没有usage时应该记录什么？
12. Fake通过为什么不证明真实SSE首事件性能？

## 19. 120秒复述模板

流式API是有类型事件和显式终态组成的状态机，不是边收边拼字符串。delta只能形成可见草稿，只有completed加完整校验才能提交；EOF或断流标partial。连接、首事件、空闲和总超时共享deadline。重试只覆盖瞬态且安全的阶段，有限次数、指数退避和抖动，并核对SDK内建重试。取消从用户一路传播到迭代器和子任务，清理后重新抛出，不能降级。慢消费者需要有界队列与合并更新。工具副作用在完整参数、授权、确认和幂等之后执行，不能被流重试重放。本地测试不代表真实网络和计费证据。

## 20. 官方版本表面与复核入口

截至2026-07-24，OpenAI迁移指南明确Responses流采用typed SSE，文本常见response.created、response.output_text.delta、response.completed和error；函数参数有对应delta/done事件。流式指南还提醒生产中对部分输出做内容审核更困难。限流指南建议随机指数退避和最大重试次数，并提醒失败请求仍计入每分钟限额。

- Streaming Responses：https://developers.openai.com/api/docs/guides/streaming-responses
- Responses streaming events：https://developers.openai.com/api/docs/api-reference/responses-streaming
- Migrate streaming consumers：https://developers.openai.com/api/docs/guides/migrate-to-responses#7-update-streaming-consumers
- Rate limits：https://developers.openai.com/api/docs/guides/rate-limits#retrying-with-exponential-backoff
- Python asyncio cancellation：https://docs.python.org/3/library/asyncio-task.html#task-cancellation

事件集合、SDK异常映射和服务端取消行为属于版本表面，使用时重新查官方SDK与API参考。部分/完成分离、有界预算、取消传播、背压和副作用幂等是跨供应商稳定原则。
