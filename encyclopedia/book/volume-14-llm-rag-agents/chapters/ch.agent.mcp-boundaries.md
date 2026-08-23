---
schema_version: 2
edition: 2026.2-draft
id: ch.agent.mcp-boundaries
title: MCP、Agent 模式/反模式与 Java/Python 职责边界
responsibility: 以 MCP 协议定义受控工具与资源边界，比较 Agent/确定性工作流及 Java/Python 职责，只有无法用普通代码表达时才引入自主循环。
volume: '14'
order: 16
level: L3
status: drafting
path: book/volume-14-llm-rag-agents/chapters/ch.agent.mcp-boundaries.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.agent.langgraph
- ch.rag.security-observability
- ch.python.testing-logging-debug
version_surfaces:
- python-3.14
- mcp
- langgraph
- langchain
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
  text: 在 120 秒内解释“MCP、Agent 模式/反模式与 Java/Python 职责边界”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - agent-mcp-protocol
  - agent-system-boundary
  covers_topics:
  - agent.mcp-server-client
  - agent.mcp-tool-resource
  - agent.mcp-capability-negotiation
  - agent.mcp-error-boundary
  - agent.agent-vs-workflow
  - agent.loop-budget
  - agent.java-python-contract
  - agent.eval-kill-switch
  uses_capabilities:
  - ai.agent-graph-mcp
  - ai.structured-tool-calling
  - ai.rag-evaluation-security
  - python.asyncio-cancellation
  - python.testing-debugging
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现本地 MCP 工单只读服务器与 LangGraph 客户端，定义 Java 权威业务 API、Python 编排边界、预算和总开关；独立保存可复现工件与判断结果
  covers_topic_groups:
  - agent-mcp-protocol
  - agent-system-boundary
  covers_topics:
  - agent.mcp-server-client
  - agent.mcp-tool-resource
  - agent.mcp-capability-negotiation
  - agent.mcp-error-boundary
  - agent.agent-vs-workflow
  - agent.loop-budget
  - agent.java-python-contract
  - agent.eval-kill-switch
  uses_capabilities:
  - ai.agent-graph-mcp
  - ai.structured-tool-calling
  - ai.rag-evaluation-security
  - python.asyncio-cancellation
  - python.testing-debugging
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: protocol-contract-test-cross-service-authorization-test-budget-kill-switch-test
- id: diagnose
  kind: fault-diagnosis
  text: 面对“MCP 服务直接连库绕过 Java 授权、无限 Agent 循环、协议错误当模型文本或关闭开关后仍有后台任务”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - agent-mcp-protocol
  - agent-system-boundary
  covers_topics:
  - agent.mcp-server-client
  - agent.mcp-tool-resource
  - agent.mcp-capability-negotiation
  - agent.mcp-error-boundary
  - agent.agent-vs-workflow
  - agent.loop-budget
  - agent.java-python-contract
  - agent.eval-kill-switch
  uses_capabilities:
  - ai.agent-graph-mcp
  - ai.structured-tool-calling
  - ai.rag-evaluation-security
  - python.asyncio-cancellation
  - python.testing-debugging
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# MCP、Agent 模式/反模式与 Java/Python 职责边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《LangGraph 状态、检查点、恢复与人工审批》](ch.agent.langgraph.md)：有状态 Agent 的检查点、审批和恢复是 MCP 编排的执行基础。
- [《提示注入、ACL、PII、日志与可观测性》](ch.rag.security-observability.md)：Agent 必须在 RAG 安全、租户隔离和可观测回归通过后接入知识与工具。
- [《pytest、fixture、Mock、日志与调试证据》](../../volume-12-python-data/chapters/ch.python.testing-logging-debug.md)：跨进程协议、工具替身和失败分类需要成熟 Python 测试与诊断能力。
<!-- END GENERATED LEARNING PREREQUISITES -->

MCP（Model Context Protocol）定义应用怎样发现和调用外部工具、读取资源、使用提示等能力。它是协议边界，不是权限系统、Agent 智能、业务事务或服务部署方案。一个工具能被模型发现，不代表模型有权调用；一次 tools/call 返回文本，也不代表业务写入成功。

本章根据 2026-07-24 官方当前协议版本 2025-11-25，实际使用 MCP Python SDK 1.28.1 的 FastMCP、ClientSession 与内存传输，再由 LangGraph 1.2.9 运行一个有预算的只读流程。没有开 socket、没有 OAuth、没有模型、没有真实 Java/数据库，所以网络安全和生产授权未验证。

## 1. MCP 解决什么

没有协议时，每个 Agent host 都为文件、数据库、SaaS 和内部 API写专用适配器。MCP 提供统一的初始化、能力声明、工具/资源发现、调用与错误结构，使 client/server 可以独立演进。但领域 schema、认证、授权、配额和审计仍由实现负责。

### 1.1 host、client、server

Host 是承载用户体验和模型编排的应用；client 管理与某个 server 的协议会话；server 暴露一组能力。一个 host 可连接多个 server，每个连接独立初始化和协商。不要把 MCP client 等同模型，也不要让 server 信任模型生成的身份声明。

```text
user -> host policy / approval
          -> MCP client session
               -> MCP server adapter
                    -> authoritative Java API
```

### 1.2 JSON-RPC 与 schema

协议消息基于 JSON-RPC，完整规范以 TypeScript schema 为事实来源，并生成 JSON Schema。2025-11-25 基本规范说明，无 `$schema` 时默认 JSON Schema 2020-12。应用仍需验证 schema 和业务语义，不能把类型正确当作获权。

### 1.3 版本日期

MCP 用 `YYYY-MM-DD` 标识发生不兼容变化的协议 revision。当前官方版本为 2025-11-25；旧版本可为 final，draft 不用于稳定生产合同。SDK 包版本 1.28.1 与协议日期是两个维度，不能混写成“MCP 1.28 协议”。

## 2. 初始化与能力协商

连接开始由 client 发送 initialize，包含其 protocolVersion、capabilities 和 clientInfo；server 返回选定 protocolVersion、server capabilities 等，然后会话进入正常操作。双方必须对一个版本达成一致；能力未声明就不能假定存在。

### 2.1 协商不是猜测

client 看到 tools capability 才列工具；resources 的 subscribe/listChanged 是可选子能力。某 SDK 类有方法不等于对端 server 支持。把协商结果保存到 trace，可诊断版本/能力不匹配。

### 2.2 降级策略

若 server 不支持资源订阅，可选择轮询、禁用实时刷新或拒绝启动，但策略要显式。不能静默假装实时。协议版本无交集时终止连接并报告兼容错误，不把它交给模型“想办法”。

### 2.3 身份不在 capability 中

capability 表示协议功能，不授予业务资源权限。server 仍从可信传输/认证上下文获得 principal，在每次工具/资源请求上授权。模型或 client 参数里的 `tenant_id` 只是输入，不能直接成为身份。

## 3. tools、resources 与 prompts

2025-11-25 server overview 将三类 primitive 区分：prompts 偏用户控制的模板，resources 是应用管理的上下文，tools 是模型可提出调用的函数。这里的“模型控制”描述交互方式，不取消 host 的确认和策略。

### 3.1 Tool

Tool 有 name、description、inputSchema，可选 outputSchema、annotations 和 metadata。`tools/list`发现，`tools/call`执行。description 会进入模型选择语境，必须准确说明边界和副作用；输入/输出用窄 schema，拒绝额外字段、非法枚举和超限值。

### 3.2 Tool annotations 是 hint

readOnlyHint、destructiveHint、idempotentHint、openWorldHint 帮助 client/UI，但官方 schema 明确它们是提示，不能信任未知 server 的声明。真正副作用控制来自受信 server、权限和用户确认。把删除工具标成 readOnly 不会让它安全。

### 3.3 Resource

Resource 用 URI 唯一标识，含 name、mimeType、size 等，可为文本或二进制。Resource template 用 URI 参数暴露集合。读取仍需逐资源授权；URI 不应嵌入秘密。server 可声明订阅/列表变化能力，client 不能因此跳过刷新权限。

### 3.4 Prompt

Prompt 是可发现模板，不是 system policy。它可能来自 server 或用户选择，内容仍不可信。安全授权永远不依赖 prompt 是否说“只读”。本章 server 不暴露 prompt，避免把业务指令与只读资源混淆。

## 4. 工具 schema

inputSchema 至少是 object root，properties 定义参数，required 标出必需字段。outputSchema 可定义 structuredContent。server 返回结构化结果时应符合 schema，client 也应验证；兼容需要时还可在 content 中给序列化文本，但领域逻辑优先读取受验证结构。

### 4.1 schema 不是权限

`ticket_id` 符合字符串规则，只说明格式可解析。server 用 session principal 调 Java `getWorkOrder`，Java 判断租户/资源可见性。不要把 allowed tenant 列表发给模型后让它自觉选择。

### 4.2 输出最小化

只返回 Agent 需要的字段，如 ticket_id、status、version，不把用户手机号、内部备注或数据库行全部暴露。资源与工具分别定义目的；若 resource 包含长文本，client 在加入模型前仍做 ACL 和 PII 最小化。

### 4.3 schema 演进

增加 required 字段、改变枚举或含义是兼容风险。工具名/版本、schema 快照和 contract tests 一起发布。client 不能依据 Python SDK 内部类作为长期业务合同。

## 5. 协议错误与执行错误

官方 tools 规范区分两类。未知工具、畸形请求等 protocol error 用 JSON-RPC error；API failure、输入范围和业务错误等 tool execution error 通常在 result 中 `isError:true`，让模型有机会在允许预算内修正。

### 5.1 为什么必须分开

协议错误多半需要开发者或连接修复，继续让模型改参数没有意义；执行错误可能是可恢复业务反馈。把所有错误拼成普通模型上下文，会出现模型把“permission denied”改写为“已成功”。

### 5.2 控制流

client 先看 transport/JSON-RPC 异常，再看 result.isError，最后验证 structuredContent。任何错误都进入显式状态和审计，不直接当 answer。权限拒绝不重试；not found 是否可重试由业务决定；server 5xx 按总 deadline 有限重试。

### 5.3 信息泄露

错误消息不暴露其他租户是否存在、数据库路径、SQL、令牌或堆栈。对模型提供可行动但最小的 category；详细诊断进受控脱敏日志。

## 6. transport 边界

常见本地 transport 是 stdio，远程可用 Streamable HTTP。transport 决定进程、网络、认证和取消语义。内存传输仅用于测试；它绕过操作系统和网络，不能证明 stdio 环境变量、HTTP header、代理、TLS、重连或负载均衡行为。

### 6.1 stdio

Host 启动子进程，通过 stdin/stdout 交换消息。stdout 必须只输出协议，普通日志走 stderr；子进程继承哪些环境变量要白名单，尤其 API key。可执行文件路径、包来源和更新是供应链边界。

### 6.2 Streamable HTTP

远程 server 需要 TLS、认证、授权、Origin/host 防护、限流、超时和连接生命周期。MCP 提供 authorization 框架不等于应用自动安全；要按当前规范实现 resource indicator、token audience 等。

### 6.3 取消与后台任务

client 停止等待不一定终止 server 任务。server 工具要接受取消/deadline，并避免脱离结构化 task group 的后台写。kill switch 关闭后应拒绝新调用、取消可取消任务并等待/标记不可取消任务。

## 7. 授权与安全

官方基本规范说明 HTTP transport 应遵循 MCP authorization 框架，stdio 不采用同一 HTTP 流程而通常从环境获得凭据。实际部署还需组织身份、scope、用户同意和下游 API策略。

### 7.1 禁止 token passthrough

官方 Security Best Practices 将把未验证的上游 token 直接传下游列为反模式。server 必须验证 token 是发给自己的，不能用一个不透明 token 绕过 audience、限流和审计。代理场景还要防 confused deputy，并按 client/user 取得同意。

### 7.2 每次请求授权

连接初始化成功不表示永久有权读所有资源。角色/资源状态可能变化，工具每次调用查询权威 Java API。cache key 包含 principal/权限版本，拒绝结果也短期处理，避免撤权后继续返回旧内容。

### 7.3 用户确认

写工具调用前 host 展示具体参数、资源版本、影响和 server 身份。批准记录不能由模型伪造。高风险环境可完全不向 Agent 暴露写工具，只允许生成 proposal 交 Java 普通工作流。

## 8. MCP server 不直接连业务库

在 FactoryCare，MCP server 是受控适配器，不是新的权威后端。它调用 Java API，让 Java 执行认证、tenant ACL、状态机、乐观锁和审计。若 Python server 直接查 PostgreSQL，容易绕过 Java 规则、形成第二套授权并造成状态不一致。

### 8.1 只读教学 server

工件只暴露 `get_work_order` tool 和同类 resource template，annotation 标记只读；真正保证来自代码没有写入口，以及 Java fixture 仅有 read。返回字段最小，跨租户读取由 Java fixture 拒绝并成为 tool execution error。

### 8.2 写入路径

若将来需要写，推荐 MCP 工具只创建 proposal，或调用 Java command API并强制批准、expected version、idempotency key。Java receipt 是成功证据。MCP `content` 文本“done”不是证据。

### 8.3 资源 URI

`factorycare://work-orders/{id}` 是协议标识，不让 client 绕过 Java。server 解析 id 后仍按 principal 调 Java。不要把数据库主键、tenant secret 或 bearer token编码进 URI。

## 9. Agent 还是确定性工作流

工作流的步骤和分支可预先写出；Agent 由模型在允许动作中动态选择。需要文本理解不代表需要自主循环：分类、抽取或一次工具选择仍可放进确定性流程。

### 9.1 适合工作流

固定审批、状态机、财务/安全规则、可枚举集成和有严格 SLA 的操作优先普通代码或 LangGraph 明确 DAG。优势是覆盖路径、预算和错误容易证明。

### 9.2 可能适合 Agent

开放式调查、工具组合路径很多、失败需根据语义调整且风险可控时，有限 Agent 循环可能有价值。仍然限制工具、只读优先、每轮预算、人工门和 kill switch。

### 9.3 反模式

用 Agent 替代 SQL/规则；给万能 shell/SQL；让模型管理权限；无限反思；把长期记忆当事实库；模型直接写业务 DB；以演示成功代替回归；无法说明何时终止。这些会扩大非确定性与攻击面。

## 10. 循环预算

预算至少含最大步骤、模型调用、工具调用、token/cost 和总 deadline。每次恢复继续同一预算，不重新归零。预算耗尽进入明确 `budget_exhausted`，输出已完成步骤和未执行动作，不偷偷降级继续。

### 10.1 多维预算

单纯 steps 不能限制一次超大模型调用或长工具。工具有自己的 timeout/响应大小；model 有 token limit；并发有 semaphore。所有维度形成硬上限，soft warning 用于接近阈值。

### 10.2 无进展检测

相同工具+参数重复、state hash 不变或同错误反复出现应提前终止。若允许模型修正，限制每类错误的尝试次数。把工具错误全文反复喂回会浪费上下文并可能包含敏感数据。

### 10.3 本章实际图

实际 LangGraph client 是固定两节点 `read -> propose -> END`。read 前检查 kill switch 和 remaining steps，再调用 MCP；proposal 只是字符串建议，不写业务。这不是自主 Agent，却更符合当前任务。

## 11. kill switch

总开关用于紧急停止某版本、租户、工具或全部 Agent。检查点至少在接收请求、每次模型/工具前、长任务安全点和副作用前。开关状态来自可靠控制面并有默认策略；读取失败时高风险动作 fail closed。

### 11.1 停止证据

关闭后断言新任务拒绝、队列不再取任务、后台 task 结束或进入已知状态、Java 无新 receipt、审计产生 killed 事件。UI 显示关闭不等于进程停止。

### 11.2 竞态

开关可能在工具返回后、proposal 前或写入中改变。每个危险边界复查；已提交不可撤销动作按 receipt 和补偿处理。kill switch 不是数据库回滚。

### 11.3 恢复

重新开启前固定故障、回归通过、清理/检查 checkpoint 和队列，决定旧任务恢复还是废弃。不能一键开启后让积压动作突然执行。

## 12. LangGraph 与 MCP 组合

LangGraph 管状态、审批、恢复和终止；MCP client 管工具/资源协议会话；Java 管业务事实和写入。节点调用 session 时把 `isError` 转成显式 error state，不把它当模型答案。tool output 先按 outputSchema/领域 schema 验证再入 state。

### 12.1 生命周期

server session 可能短于 graph thread。checkpoint 不保存活 ClientSession；恢复时重新建立/初始化连接、重新协商 capability，并确认目标 server identity/version。旧 checkpoint 不能假设工具集合未变。

### 12.2 工具版本漂移

保存 tool name、schema hash 和 server implementation version。恢复若不兼容就暂停迁移或人工处理，不用模型猜新参数。工具 list 变化是配置事件。

### 12.3 trace 关联

graph run_id、MCP JSON-RPC request ID、Java request ID 和 receipt 通过脱敏 correlation 关联。不要把协议 request ID 当业务幂等键；生命周期和唯一性不同。

## 13. 四类故障定位

### 13.1 server 直连数据库

失败阶段是架构依赖检查，首证据为 Python MCP 包导入数据库 driver/SQL 或持有 DSN，而不是 Java API client。修复移除直连、定义 Java read/command contract，并做跨服务授权测试。

### 13.2 无限 Agent 循环

首证据为 steps/tool_calls 持续增长、remaining 不下降或同 state 重复。修复硬预算、无进展检测和终止状态；只在 prompt 写“最多三次”不够。

### 13.3 协议错误当模型文本

unknown tool JSON-RPC error 被拼入 context，模型随后声称修复。首证据是 protocol error 未进入异常/控制分支。修复分开 transport/protocol/tool execution/domain validation，只有允许的执行错误摘要可在有限预算内反馈。

### 13.4 关闭开关仍有后台任务

UI 显示 disabled，但 Java read/write 计数继续。首证据是 task registry、queue 和 receipt 时间。修复结构化并发、多个安全点检查、取消/等待策略；记录无法抢占的残余任务。

## 14. 测试矩阵

协议合同测 initialize、版本、能力、tools/resources list、input/output schema、未知方法和执行错误；授权测同租户允许、跨租户拒绝且下游无泄露；预算测 0/1/耗尽；kill switch 测调用前与返回后；恢复测 server 重连和工具 schema 漂移；安全测 token、PII、恶意 server metadata。

stdio 和 HTTP 分开测试。内存 transport 快而确定，只覆盖 SDK 协议对象；真实 transport 还需子进程退出、stderr、TLS、OAuth、代理、断线、backpressure 和取消。

## 15. 实际验证与未验证

2026-07-24 隔离环境：Python 3.14.3、MCP SDK 1.28.1、SDK `LATEST_PROTOCOL_VERSION=2025-11-25`、LangGraph 1.2.9、LangChain 1.3.14、pytest 9.1.1。实际通过内存 transport 完成 initialize、list_tools、list_resource_templates、structured tool call、跨租户执行错误、预算 0 和 kill switch 阻断。

未验证 stdio、Streamable HTTP、OAuth、token audience、TLS、进程终止、网络重试、真实 Java、数据库、模型或生产 LangGraph checkpointer。FastMCP annotation 和本地 fixture 不构成授权证明。

## 16. 可运行工件

- `examples/encyclopedia/ch.agent.mcp-boundaries/`：真实 SDK 内存 client/server、只读工具/资源、LangGraph 客户端、预算和 kill switch。
- `labs/encyclopedia/ch.agent.mcp-boundaries/`：Java 后端依赖、错误分类和有界计划审计。
- `exercises/encyclopedia/ch.agent.mcp-boundaries/`：故意允许 server 直连 PostgreSQL。
- `solutions-private/encyclopedia/ch.agent.mcp-boundaries/`：只允许 Java authoritative API。

## 17. 120 秒复述模板

“MCP 是 host/client/server 之间发现工具、资源和提示的 JSON-RPC 协议。initialize 协商协议日期和 capability；tool 用 input/output schema，protocol error 与 `isError` 执行错误必须分开。annotation 只是 hint，认证、ACL、确认和写入仍由受信服务执行。FactoryCare 的 MCP server 只适配 Java 权威 API，不直连业务库；Python/LangGraph 管有预算的编排，Java 管事实、状态机和最终写。只有开放路径确有需要才用 Agent，否则用确定性工作流。越界反例是内存 client/server 通过就宣称 HTTP/OAuth 安全，或模型调用了工具就宣称业务成功。”

## 18. 自测题

1. SDK 1.28.1 和协议 2025-11-25 有什么区别？
2. capability negotiation 能否授予工单权限？
3. Tool annotation 为什么不是安全控制？
4. protocol error 与 tool execution error 如何处理？
5. stdio 与 HTTP 认证边界有何不同？
6. 为什么 MCP server 不直连业务数据库？
7. 什么时候普通工作流优于 Agent？
8. loop budget 至少有哪些维度？
9. kill switch 关闭后要验证哪些证据？
10. checkpoint 是否应保存 ClientSession？

## 19. 答案要点

1. 前者是 Python 包发布，后者是不兼容协议 revision。
2. 不能，它只说明协议功能，业务权限逐请求校验。
3. 未知 server 可错误声明，真正行为由代码/授权决定。
4. 前者终止/修连接，后者按 category 有限恢复，均不冒充答案。
5. HTTP 有协议 authorization 框架；stdio 通常由启动环境提供凭据。
6. 否则绕过 Java ACL/状态机并形成第二真相。
7. 路径可枚举、风险高、规则严格且无需自主探索时。
8. steps、工具/模型调用、token/cost、deadline、并发/响应大小。
9. 新任务、队列、后台 task、Java receipt 和 kill audit。
10. 不应；保存稳定标识，恢复后重连并重新协商。

## 20. 官方资料

- [MCP Versioning](https://modelcontextprotocol.io/docs/learn/versioning)：当前协议版本和日期版本语义。
- [2025-11-25 Server Overview](https://modelcontextprotocol.io/specification/2025-11-25/server/index)：prompts、resources、tools 及控制层级。
- [2025-11-25 Schema Reference](https://modelcontextprotocol.io/specification/2025-11-25/schema)：initialize、Tool、structuredContent 与协议类型。
- [2025-11-25 Resources](https://modelcontextprotocol.io/specification/2025-11-25/server/resources)：resource、template、annotation 和订阅能力。
- [MCP Security Best Practices](https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices)：confused deputy 与禁止 token passthrough。
- [2025-11-25 Authorization](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization)：HTTP authorization 当前合同。

核验日期 2026-07-24。仓库 registry 对 MCP 保持 provisional，因为协议按日期演进；本章 actual SDK 1.28.1 支持当前 revision。协议 primitive、逐请求授权、错误分层和 Java/Python 权威边界是稳定原则；draft feature、Tasks、transport/authorization 细节和 SDK helper 都需按目标 revision 复核。
