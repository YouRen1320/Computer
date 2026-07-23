---
schema_version: 2
edition: 2026.2-draft
id: ch.agent.langchain
title: LangChain 组件、直接 SDK 对照与边界
responsibility: 在先掌握官方 SDK 后，用 LangChain 组合模型、提示、解析器和 Retriever，并通过直接 SDK 对照识别抽象收益与泄漏。
volume: '14'
order: 14
level: L3
status: drafting
path: book/volume-14-llm-rag-agents/chapters/ch.agent.langchain.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.llm.streaming-resilience
- ch.rag.citations-evaluation
version_surfaces:
- python-3.14
- model-api
- langchain
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
  text: 在 120 秒内解释“LangChain 组件、直接 SDK 对照与边界”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - agent-langchain-components
  - agent-abstraction-boundary
  covers_topics:
  - agent.langchain-runnable
  - agent.prompt-template
  - agent.output-parser
  - agent.retriever-adapter
  - agent.sdk-parity
  - agent.callback-observability
  - agent.config-propagation
  - agent.framework-escape-hatch
  uses_capabilities:
  - ai.llm-model-api
  - ai.rag-ingestion-retrieval
  - python.asyncio-cancellation
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 分别用官方 SDK 和 LangChain 实现同一结构化 RAG 流程，对照请求、取消、trace、错误和测试替身；独立保存可复现工件与判断结果
  covers_topic_groups:
  - agent-langchain-components
  - agent-abstraction-boundary
  covers_topics:
  - agent.langchain-runnable
  - agent.prompt-template
  - agent.output-parser
  - agent.retriever-adapter
  - agent.sdk-parity
  - agent.callback-observability
  - agent.config-propagation
  - agent.framework-escape-hatch
  uses_capabilities:
  - ai.llm-model-api
  - ai.rag-ingestion-retrieval
  - python.asyncio-cancellation
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: sdk-parity-test-fake-runnable-trace-comparison
- id: diagnose
  kind: fault-diagnosis
  text: 面对“框架默认值悄悄改请求、异常被包装丢失分类、取消未传播或为了链式语法隐藏业务授权”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - agent-langchain-components
  - agent-abstraction-boundary
  covers_topics:
  - agent.langchain-runnable
  - agent.prompt-template
  - agent.output-parser
  - agent.retriever-adapter
  - agent.sdk-parity
  - agent.callback-observability
  - agent.config-propagation
  - agent.framework-escape-hatch
  uses_capabilities:
  - ai.llm-model-api
  - ai.rag-ingestion-retrieval
  - python.asyncio-cancellation
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# LangChain 组件、直接 SDK 对照与边界

LangChain 解决的是组件组合和统一调用接口，不替你定义业务合同。最稳妥的学习顺序是先用模型提供商官方 SDK 完成一个最小请求：明确模型、参数、超时、结构化输出、错误和取消；然后用 LangChain 实现完全相同的流程，比较“有效请求”和可观察行为。只有对照相等，框架抽象才是可审查的便利，而不是隐藏变化。

本章实际使用 LangChain 1.3.14 与 langchain-core 1.5.0 的 Runnable、PromptTemplate、JsonOutputParser 和 callback 接口，但模型 SDK、Retriever 和授权服务均是本地受控替身，没有在线 API。版本号是 2026-07-24 隔离安装事实，不代表仓库锁文件或未来安装会得到相同 patch。

## 1. 为什么直接 SDK 必须先跑通

如果从框架开始，遇到错误时无法判断来自提供商、网络、提示、解析器还是框架适配器。直接 SDK 基线应保存实际发送的请求对象、模型/端点、超时、重试、输入消息、响应 schema、usage、request ID 和异常分类。它是对照 oracle，不是要求生产永远不用框架。

最小直接流程：

```text
authorized retrieval
  -> explicit prompt/message construction
  -> explicit provider request(model, temperature, timeout)
  -> response schema validation
  -> citation/evaluation
```

换成 LangChain 后，各步骤仍应可定位。若链式语法让你说不出哪里授权、哪里设置 timeout、哪里验证输出，就还没有建立边界。

### 1.1 比较有效请求而非源代码长相

直接 SDK 可能用字典，LangChain 可能用 PromptValue；形式不同没关系。要比较最终提供商收到的模型 ID、消息角色/顺序、工具 schema、temperature、max tokens、timeout、metadata 和重试次数。框架默认省略字段可能触发提供商默认，仍然是行为变化。

### 1.2 黄金输入

选一组确定性输入：可回答、拒答、提供商超时、解析失败、取消和未授权。直接与框架版本分别运行，断言结构化结果、请求和错误类别相等。真实模型可能非确定，至少固定参数并对 schema/关键状态而非逐字文本比较。

## 2. LangChain v1 的位置

官方 v1 资料把 `create_agent` 作为标准高层 Agent 入口，并说明核心 namespace 被精简，旧功能移到 `langchain-classic`。本章不从 Agent 自主循环开始，而使用 `langchain-core` 的可组合基础件，因为它更适合看清每个边界。高层 agent 也建立在类似模型、工具和中间件合同上。

LangChain 是框架；provider integration 常在独立包；LangGraph 是更低层的状态与持久化运行时。安装 `langchain` 不等于已经安装所有模型提供商适配器，也不等于启用了 LangSmith 追踪或生产部署。

## 3. Runnable 心智模型

Runnable 可以理解为带统一入口的可组合变换。常见入口包括同步 `invoke`、异步 `ainvoke`、批处理和流式接口；具体组件是否真正异步、是否原生流式、如何并发，取决于实现。统一方法名不是性能保证。

```text
Input
  | RunnableLambda(retrieve + authorization boundary)
  | PromptTemplate
  | RunnableLambda(provider adapter)
  | JsonOutputParser
  | RunnableLambda(domain schema validation)
  -> Domain Answer
```

管道操作符 `|` 让数据流紧凑，但类型和副作用容易隐藏。每个节点应有窄输入输出、名字、单元测试和 trace；不要在匿名 lambda 中同时授权、检索、写库和格式化。

### 3.1 invoke 与 ainvoke

异步入口只有在底层实现正确等待异步 I/O 时才带来并发价值。把同步阻塞 SDK 包进 `ainvoke` 可能使用线程池或继续阻塞，需查适配器和实测。调用方取消 task 时，取消应传到底层请求；若适配器捕获 `CancelledError` 当普通异常，后台工作可能继续。

### 3.2 batch 与 stream

`batch` 的并发、顺序和错误聚合要看当前实现，不应假设等于提供商原生 batch。`stream` 也可能只是组件最终一次输出。对业务重要的首 token、取消和 backpressure，需用目标 provider 的真实集成测试。

### 3.3 RunnableLambda 的边界

RunnableLambda 适合把已定义的纯函数或适配器接入管道。它不会自动让函数安全、可取消、幂等或有 schema。函数接收 `config` 时可读取 `configurable`，但安全身份不能由不可信调用者任意伪造，应该由服务端上下文注入并校验。

## 4. PromptTemplate

PromptTemplate 把变量插入模板，并能作为 Runnable 参与组合。模板变量是数据，不等于可信指令。输入必须先过 schema 和长度限制；对外部文档使用清晰边界；敏感值不应因为模板方便而进入 prompt。

### 4.1 模板版本

提示应有不可变版本或哈希，与模型、数据集和评估结果绑定。直接在控制台改 prompt 而不记录，会破坏回归可解释性。模板升级是行为变更，需要直接/框架对照和冻结集重跑。

### 4.2 消息与纯文本

聊天模型通常接收有角色的 messages，而普通 PromptTemplate 产生文本。把 system/user/tool 消息拍平成字符串可能改变提供商行为。真实适配器应在消息层做 parity；教材为了不连接 provider，使用相同纯文本模板验证管道。

### 4.3 注入边界

转义花括号只解决模板语法，不解决 prompt injection。ACL、工具授权、预算和确认在模板之外执行。模型看到“授权通过”字符串不能替代 principal/策略结果。

## 5. OutputParser 与领域 schema

输出解析器把模型文本转换为 Python 结构。JsonOutputParser 可以读取 JSON，但业务仍应使用 Pydantic/领域模型验证 allowed status、source_id、长度和额外字段。解析成功不代表回答正确、引用可信或工具调用获权。

### 5.1 两层验证

第一层是传输/语法：是不是 JSON、字段类型是否基本正确；第二层是业务不变量：answered 必须有 citation、source 必须在上下文、拒答不能携带执行动作。框架 parser 可替换，业务 schema 不应依赖其内部对象。

### 5.2 解析错误

不要把所有异常重试成模型请求。网络超时、rate limit、非法 JSON、schema 失败、授权拒绝属于不同类别。只有明确可恢复错误才按预算重试；解析失败时保存脱敏响应摘要和 parser 版本，不能把原始敏感全文随意日志化。

### 5.3 自动修复解析

让另一次模型调用“修复 JSON”会增加成本和新的非确定性，也可能改变语义。若使用，必须计入请求预算并重新验证来源/授权；不能把修复后可解析当作原回答正确。

## 6. Retriever adapter

官方资料把 Retriever 描述为接受非结构化 query、返回 Document 列表的接口，且比 vector store 更一般。适配器的价值是让不同检索后端组合一致；风险是把重要的 tenant/ACL、索引版本、分数语义压进不透明 metadata。

### 6.1 授权在 adapter 外还是内

身份从服务端上下文进入，adapter 构造授权查询并只返回允许候选。链的调用者不能通过 `configurable.authorization="admin"` 自行升级；示例将预期授权与配置值对照只是教学 oracle，真实系统应使用不可伪造 principal 对象。

### 6.2 Document 映射

统一 Document 至少保留 source_id、父版本、文本偏移、ACL/tenant 投影、retrieval score 和 index version。字段缺失应在 adapter 边界失败，而不是让后续 parser 猜。框架对象不应穿过 Java API成为长期业务合同。

### 6.3 逃生口

若目标检索后端需要框架接口无法表达的 hybrid query、ACL filter 或取消，直接调用官方/数据库 SDK 并用一个薄 RunnableLambda 适配是合理的。不要为了“全链式”牺牲可观察合同。

## 7. RunnableConfig 传播

RunnableConfig 可携带 callbacks、tags、metadata、configurable 等运行配置。官方 reference 说明 callbacks 可传播到子调用，tags/metadata 用于 callback。它适合 trace 关联、组件名字和非敏感运行参数；不适合秘密或由用户随意指定的权限。

### 7.1 tags 与 metadata

tag 使用低基数稳定枚举，如 `rag-parity`、`production`; metadata 可含数据集/提示版本和脱敏 request correlation。不要记录完整 prompt、token 或 PII。确认每个子 Runnable 是否继承，不能只看根 span。

### 7.2 configurable

configurable 让同一图在运行时选择模型或参数，但也会扩大状态空间。允许值应白名单和版本化。安全策略、tenant 和用户身份来自认证中间件，不因该字典便利就变成客户端可控字段。

### 7.3 递归与并发限制

某些运行配置能影响并发/递归，但具体键与语义是版本表面。业务预算要在应用层明确计数，不能只依赖框架默认。升级前查当前 reference 并运行故障测试。

## 8. callback 与可观察性

callback 可以观察 chain/model/tool/retriever 生命周期。示例用 `BaseCallbackHandler` 记录 start/end/error，并验证有效 config 到达 provider adapter。真实系统需要为异步 handler、异常、采样和脱敏设计，不让 callback 故障破坏主请求或泄漏数据。

### 8.1 trace 对照

直接 SDK 路径和 LangChain 路径应有相同业务阶段：authorize、retrieve、model、parse、evaluate。框架可能产生更多内部 span，但关键属性和错误分类必须可映射。只展示一个漂亮 trace 截图不是测试。

### 8.2 callback 不是审计

callback 常由进程内代码控制，可被禁用或丢失；业务写审计由 Java 权威服务持久化。模型 trace 只能说明编排发生过，不能证明工单状态已写入。

### 8.3 内容采集

许多可观测工具允许记录输入输出，这会包含 PII、文档或密钥。默认关闭全文，使用字段白名单、长度/哈希/计数和受控采样。供应商平台的数据保留与地区必须单独确认。

## 9. 错误分类保持

adapter 可以增加上下文，但不应把 `TimeoutError`、rate limit、authentication、schema、permission 全包成 `RuntimeError("chain failed")`。上层需要决定重试、拒答、告警或返回 4xx/5xx。Python 可用 exception chaining 或 note 保留原因。

### 9.1 首个可信证据

先看有效 provider request 和底层异常，再看框架包装栈。若 provider 根本未调用，问题在前置授权/检索/模板；若请求字段变化，问题在 adapter/default；若底层收到取消但连接继续，则看 SDK 传输语义。

### 9.2 重试位置

Provider SDK、LangChain wrapper、HTTP client 和服务网关可能都重试，叠加后请求数指数增加。选一个明确负责层，记录 attempt 与总 deadline。写工具重试还需 Java 幂等键。

## 10. asyncio 取消

取消是控制流，不是普通失败。父 task 被取消时，Runnable 的 `ainvoke`、adapter 和 provider await 都应观察取消并停止或进入明确的不可取消阶段。不要捕获 `BaseException` 后返回空答案，这会吞掉 `CancelledError`。

### 10.1 测试方法

使用阻塞替身：底层协程先设置 `started` event，再等待永不完成的 event。测试创建 `ainvoke` task、等待 started、调用 cancel，然后断言调用方得到 CancelledError 且底层设置 cancelled 标志。这比 sleep 猜时序稳定。

### 10.2 取消不等于远端停止

即使 Python 协程收到取消，HTTP 请求可能已经到提供商并计费。目标 SDK 是否发送取消、连接如何复用要实测。日志将“调用方停止等待”和“远端确认终止”分开；本章只证明本地受控协程传播。

## 11. 测试替身

好的 fake 记录 effective request、返回严格 JSON、能触发 timeout/invalid JSON/cancel，并且没有网络。不要 mock 掉整个业务函数后只断言调用一次；那无法发现模板或默认参数变化。框架升级回归应运行实际 Runnable 与 parser，加 fake provider。

### 11.1 parity matrix

对每个案例同时记录 direct outcome、framework outcome、request diff、error class、trace stage 和 provider call count。输出文字非确定时比较结构和业务 predicate。任何差异都要有明确接受理由，不能因为“框架可能这样”忽略。

### 11.2 真实集成层

少量真实 API测试用于发现 fake 未覆盖的 SDK 行为，使用测试账号、非敏感数据、固定预算和显式跳过策略。它与离线 CI 分开标记；没有凭据时应报告 skipped/unverified，而不是替身通过就写“OpenAI 调用成功”。

## 12. 四种故障定位

### 12.1 默认值改变请求

直接请求 temperature=0，框架路径变 0.7。失败阶段是 provider adapter，首证据为 effective request diff。修复显式配置并锁测试；残余风险是 provider 未指定字段仍可能有服务端默认变化。

### 12.2 异常分类丢失

底层 ProviderTimeout 变普通字符串或统一 RuntimeError。首证据是 direct/framework exception type 不同。修复保留异常链与可机读 category，重跑 timeout、rate limit、auth、schema 矩阵。

### 12.3 取消未传播

调用方已 cancel，fake provider 的 cancelled 标志仍 false，或 background task 未结束。首证据在协程边界。修复不要吞 CancelledError，并将 deadline 传到底层；真实远端停止仍需集成验证。

### 12.4 链式语法隐藏授权

Retriever 在检查 principal 前被调用，或客户端可通过 config 改角色。首证据是拒绝案例仍产生 retrieval/model call。修复把授权变成显式前置节点和不可伪造服务上下文，断言未授权 call count=0。

## 13. 何时使用 LangChain

当需要统一多种 provider、组合可复用 Runnable、标准化 callback 或接入现有 Retriever 生态时，它能降低胶水成本。当流程只有一个稳定 SDK 调用，直接 SDK 往往更清楚。选择依据是可维护性与测试，不是简历关键词。

如果抽象泄漏，保留 escape hatch：领域接口由自己定义，LangChain 实现在 adapter 内；调用方只看到 `Answer`、`Citation` 等稳定对象。这样可替换框架，避免内部 `Document`、Message 或 RunnableConfig 渗透 Java API。

### 13.1 依赖与升级策略

`langchain`、`langchain-core`、provider integration、LangGraph 和观测 SDK 是不同发布单元。锁文件记录精确版本，升级候选在独立分支重跑 direct parity、解析错误、callback、取消和 Retriever schema。只看顶层 `langchain` major 不足以解释行为。

先阅读 v1 release/migration 和目标 integration changelog，再检查 import、弃用、默认参数与返回对象。若 provider package 需要更高 core 版本，把整个兼容组合一起验证。回滚保留旧锁文件和制品，而不是在线临时降一个包造成不可解依赖。

### 13.2 领域端口隔离

定义自己的 `ModelPort.complete(ModelRequest)->ModelResponse` 与 `RetrieverPort.search(AuthorizedQuery)->Evidence`。直接 SDK和 LangChain 分别实现端口；领域服务不 import Runnable。这样 parity 测试可同时运行两实现，也能在框架故障时回退经过验证的直接 adapter。

隔离不是重复包装每个类，而是保护会长期存在的业务 schema、错误和权限边界。框架内部 trace ID 可留在诊断 metadata，不进入 Java/前端公开合同。

## 14. FactoryCare 边界

Java 负责认证、工单事实、状态机、权限和最终写入。Python LangChain 流程接收 Java 提供的授权 principal/只读投影，完成检索、模型调用与建议。它不能因 RunnableConfig 或模型文本改变权限，也不直接写工单数据库。

所有写提议回到 Java API，携带资源版本、参数、批准和幂等键。callback trace 不能替代 Java audit receipt。前端只调用 Java 对外合同，不依赖 LangChain 内部类。

## 15. 实际验证与未验证

2026-07-24 隔离环境为 Python 3.14.3、LangChain 1.3.14、langchain-core 1.5.0、Pydantic 2.13.4、pytest 9.1.1。实际运行了 RunnableLambda、PromptTemplate、JsonOutputParser、callback 与 `ainvoke` 取消传播；直接和框架路径的冻结请求/输出相等，ProviderTimeout 类型保留。

没有安装 provider integration、没有 API key、没有访问模型、LangSmith、远程 Retriever 或 Java 服务。因而模型质量、真实 token/成本、远端取消、线上 trace 和框架性能均未验证。

## 16. 可运行工件

- `examples/encyclopedia/ch.agent.langchain/`：直接 SDK fake 与实际 LangChain Runnable parity、配置、错误和取消。
- `labs/encyclopedia/ch.agent.langchain/`：默认漂移、异常分类和授权隐藏审计。
- `exercises/encyclopedia/ch.agent.langchain/`：故意让框架 temperature 与直接请求不一致。
- `solutions-private/encyclopedia/ch.agent.langchain/`：显式相同请求。

## 17. 120 秒复述模板

“先用官方 SDK 定义有效请求、输出、错误、超时和取消，再用 LangChain 实现同一流程做 parity。Runnable 统一 invoke/ainvoke 和组合，PromptTemplate 管格式，parser 只管解析，Retriever adapter 保留 source/ACL 元数据；它们都不自动提供授权或正确性。RunnableConfig 的 callback、tag、metadata 可传播可观测信息，但安全身份由服务端注入。越界反例是链能跑通就声称与直接 SDK 等价，或把 framework Document 暴露成业务 API。Java 仍掌握事实、授权、状态机和写入，LangChain 只是 Python 内部可替换编排层。”

## 18. 自测题

1. 为什么比较 effective request 而不是代码行数？
2. Runnable 统一入口能否保证原生异步/流式？
3. parser 通过还缺哪些验证？
4. Retriever metadata 为什么不能随意丢？
5. RunnableConfig 可否直接承载客户端声明的管理员身份？
6. callback trace 为什么不是业务审计？
7. 怎样稳定测试取消传播？
8. 为什么重试只能有明确负责层？
9. 何时使用 escape hatch？
10. 本章 fake provider 证明了什么？

## 19. 答案要点

1. 最终模型、消息、参数和超时才决定行为。
2. 不能，底层适配器实现和 provider 能力决定。
3. 业务状态、授权、引用、事实和副作用规则。
4. source/version/ACL/score 是追溯与安全合同。
5. 不可；身份必须来自认证服务端上下文并校验。
6. 它可丢失/禁用，Java receipt 才证明业务写。
7. 用 event 协调阻塞 fake，cancel task 并断言底层收到取消。
8. 多层叠加会放大调用和成本，写操作还会重复。
9. 框架接口无法表达关键 provider/检索/取消合同的时候。
10. 实际 Runnable 的本地合同和 parity，不证明在线模型表现。

## 20. 官方资料

- [LangChain v1 发布说明](https://docs.langchain.com/oss/python/releases/langchain-v1)：v1 的 `create_agent` 与 namespace 变化。
- [LangChain Retrieval](https://docs.langchain.com/oss/python/langchain/retrieval)：Retriever 和 RAG 构件的官方概览。
- [RunnableConfig callbacks reference](https://reference.langchain.com/python/langchain-core/runnables/config/RunnableConfig/callbacks)：callback、tags、metadata 传播说明。
- [LangChain Python reference](https://reference.langchain.com/python/)：目标版本 API 表面。

核验日期 2026-07-24。仓库 registry 约束 LangChain 1.x；实际隔离版本为 1.3.14/core 1.5.0。Runnable、明确领域合同与 SDK parity 是本章稳定方法，具体 import、默认值、callback 事件和异步实现属于版本表面，升级必须重跑工件。
