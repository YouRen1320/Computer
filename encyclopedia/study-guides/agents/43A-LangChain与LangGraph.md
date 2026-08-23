# LangChain 与 LangGraph

## 1. 先用模型官方 SDK 跑通最小流程

在引入框架前，先理解原始请求、响应、工具调用、流事件和错误。否则框架出问题时，很难判断是供应商、网络、提示还是框架默认值。

保留一个直接 SDK 的黄金路径，作为框架行为的对照和逃生口。

## 2. 比较的是有效请求与结果，不是代码行数

框架版本可能自动加入消息、重试、回调或参数。对同一黄金输入记录最终模型、提示、工具 Schema、输出、token、延迟和错误分类，再与直接 SDK 比较。

“框架代码更短”不是兼容性证据。

## 3. LangChain 的价值是组合常见模型应用组件

它提供模型适配、Prompt 模板、结构化输出、Retriever、Runnable、工具和回调等统一抽象。适合需要组合、替换和观测多步模型流程的应用。

一个只有单次模型请求的小功能可能不需要框架；引入依赖应带来明确收益。

## 4. Runnable 是“输入经过一个步骤得到输出”的统一接口

可以把提示、模型、解析器和自定义转换视作可组合步骤。常见调用概念包括：

```text
invoke：单个同步输入
ainvoke：单个异步输入
batch/abatch：多个输入
stream/astream：逐步输出
```

具体方法和事件随 LangChain 版本变化，以锁定版本官方文档为准。

## 5. 链式语法隐藏不了真实边界

```text
prompt → model → parser
```

写成一条链很简洁，但每一步仍可能超时、失败、记录敏感数据或改变类型。关键边界要有明确命名、错误转换和可观察 span。

不要把授权检查埋在看不见的 Lambda 中。

## 6. PromptTemplate 分离模板与变量

模板定义稳定指令，变量提供本次输入。变量仍是不可信数据，不应通过字符串拼接变成系统规则。

模板、变量 Schema、示例和版本一起发布；实际渲染结果的日志默认只记录哈希和长度。

## 7. 聊天消息模板与纯文本模板不同

消息模板保留 developer/user/tool 等角色结构，纯文本模板把全部内容合成字符串。对支持消息的模型，保留角色通常更清晰。

迁移模型或供应商时，检查框架最终如何映射角色和多模态内容。

## 8. Output Parser 负责框架输出到应用对象的转换

它可把文本或结构化模型输出转成 Pydantic 等类型。解析成功只证明结构满足规则，不证明内容事实正确或业务允许。

模型 Schema 校验与领域模型校验保持两层。

## 9. 解析失败要保留原始错误类别

区分模型拒绝、不完整、非 JSON、Schema 失败和领域失败。不要让一个自动修复 parser 无限再次调用模型，掩盖原始错误并增加成本。

修复策略有次数、预算和适用范围，安全拒绝不修复。

## 10. Retriever 是查询到 Document 列表的端口

LangChain Document 常包含文本与 metadata。自己的检索结果应通过适配器映射，保留 chunk ID、来源版本、分数、路径和 ACL 审计信息。

不要把领域对象完全替换成框架 Document，避免框架类型扩散到 Java API、数据库和 UI。

## 11. Retriever Adapter 必须维持授权边界

认证主体和租户范围在调用前由应用确定，并传给受控检索服务。框架回调和模型不能扩大范围。

返回 Document 已是合法候选，仍在最终引用访问时重新授权。

## 12. RunnableConfig 可传播运行元数据

tags、metadata、callbacks 和 configurable 等机制能让一条运行带上功能版本和 trace 上下文。

不要放 PII、Token 或完整正文；也不要让用户可控 metadata 改变安全配置。

## 13. 回调适合可观测，不等于业务审计

回调可记录步骤、模型开始结束、token 和错误。业务审计仍由领域服务记录经过认证的主体、动作、资源版本、审批和结果。

第三方 tracing 平台也是数据外发边界，需要脱敏、权限和保留策略。

## 14. 框架不得抹平错误语义

应用层至少需要认出：输入错误、权限、限流、超时、取消、供应商临时失败、解析、检索和领域冲突。

若框架统一包装异常，适配器在最接近来源处解析并映射到自己的错误模型，同时保留 cause。

## 15. 重试放在知道操作语义的一层

模型只读生成可能有限重试；有工具副作用的整个 Agent 循环不能无脑重跑。框架、SDK、HTTP 和应用的重试配置应统一审计。

所有尝试服从同一 deadline 和预算。

## 16. 异步调用必须传播取消

`ainvoke` 不表示整个内部链天然可取消。下游模型、Retriever、回调和自定义函数都需接收取消/截止时间，并在 finally 清理。

测试用 Event 控制任务阶段，确认用户取消后不再触发后续工具或旧状态更新。

## 17. Fake 组件验证自己的编排

为模型、Retriever 和工具提供脚本化 Fake，稳定产生成功、拒绝、超时和错误。这样能精确检查调用顺序、预算、取消和降级。

少量真实集成再验证供应商与框架版本兼容。

## 18. 直接 SDK 与 LangChain 要有 Parity Matrix

同一黄金输入比较：模型参数、消息顺序、Schema、工具选择、流事件、错误、取消、token 和最终结果。

升级 LangChain 或模型适配包后重跑，发现默认行为漂移。

## 19. 用领域端口把框架隔离在基础设施层

```text
Application use case
  → KnowledgeAnswerer / PrioritySuggester 接口
  → LangChain adapter
  → Model / Retriever / Parser
```

业务层不知道 Runnable、Document 或 callback 类型。移除框架时主要替换 adapter。

## 20. LangGraph 适合有状态、可分支、可恢复的流程

当流程有多步工具、条件路由、循环、人工审批和中断恢复时，图能明确状态与下一步。普通直线请求或少量固定步骤用普通函数更简单。

图不是“模型内部思考图”，而是应用编排图。

## 21. 图状态是跨节点传递的可序列化事实

```text
request_id
authenticated_principal_ref
question
retrieval_result_ids
proposed_action
approval_status
step_count
error_state
schema_version
```

保存原始结构化数据和 ID，不要只保存适合显示的拼接字符串。

## 22. 编排状态与业务事实必须分开

Graph state 记录“流程走到哪里”，Java 领域服务/数据库记录“工单真实状态是什么”。恢复时重新读取权威事实和版本，不能把旧 checkpoint 当当前业务真相。

这能避免长时间审批期间现实已经变化。

## 23. 状态 Schema 需要版本

图代码发布后，旧 checkpoint 可能缺字段或字段含义已变。每个状态保存 schema/code version，并定义兼容读取、迁移或明确拒绝恢复。

不能默认新代码能加载所有旧状态。

## 24. 节点读取状态并返回状态更新

一个节点完成一个清晰职责，如检索、生成建议、等待审批或执行命令。优先返回更新，而非到处原地修改共享字典。

纯计算节点容易重放；副作用节点需要幂等、事务和审计。

## 25. 节点不要大到变成新的单体函数

拆分依据是不同失败、重试、审批、观测和恢复边界，不是每三行一个节点。两个永远一起成功失败的微步骤不必强拆。

每个节点写清输入字段、输出更新、错误和副作用。

## 26. 边表示固定下一步或条件路由

```text
retrieve
  → enough_evidence ? generate : refuse
generate
  → has_write_action ? approval : finish
approval
  → approved ? execute : rejected
```

为每个决策列出所有合法结果，未知状态进入安全失败而非默认成功边。

## 27. 路由决策和状态更新要清楚分工

若路由函数一边判断一边隐藏修改状态，重放和测试会困难。节点先返回明确状态，路由只读取并选择下一条边通常更清晰。

具体框架支持的 Command/路由 API 以当前版本为准。

## 28. 所有循环必须有终止条件

最大步数是最后保险，还需进展函数：是否获得新证据、错误是否变化、工具结果是否新增、剩余预算是否足够。

结束状态明确区分 completed、refused、failed、cancelled、budget_exhausted 和 awaiting_human。

## 29. Checkpointer 保存每一步的图状态

LangGraph 持久化层将状态快照按 thread 组织，可支持恢复、人工介入和调试。thread ID 是图执行游标，不应直接复用用户可猜测 ID，也不等于聊天业务 ID。

生产 checkpointer 需要租户隔离、加密、保留、清理和备份。

## 30. 内存 Checkpointer 只适合本地和测试

进程结束就丢失，也不支持多实例共享。生产选择应考虑事务、并发、容量、故障恢复和数据合规。

检查点可能含用户内容和工具结果，不能默认全文长期保存。

## 31. Checkpoint 不是 Exactly-once 承诺

进程可能在工具副作用成功后、checkpoint 写入前崩溃。恢复后节点重跑，就可能重复执行。

副作用通过稳定幂等键、领域事务和状态查询保护，不能依赖“图会记住”。

## 32. Replay 会重新执行后续世界交互

从旧 checkpoint 重放时，模型、API 和数据库状态可能已变化。Replay 适合调试和分支，但要清楚哪些步骤使用保存结果、哪些会重新调用外部系统。

生产重放写节点前必须有权限、幂等和明确操作模式。

## 33. Interrupt 用来暂停并等待外部输入

人工审批可在节点中产生可序列化的待审 payload，图保存状态并返回等待。之后由带身份的应用用 Command 等恢复机制提交决定。

聊天文本本身不是审批通道，恢复请求要验证审批记录和操作者。

## 34. Interrupt 恢复时节点可能从头执行

当前 LangGraph 官方文档明确：恢复后会从包含 interrupt 的节点开头重新运行，而不是从那一行之后继续。

因此 interrupt 前的副作用必须幂等，或更好地拆到批准后的独立节点。不要把 interrupt 包进普通 `try/except`，它依赖特殊控制异常暂停。

## 35. 审批内容必须与执行内容绑定

保存规范化动作哈希、资源版本、审批人、时间和决定。若人工编辑建议，生成新的待执行动作并重新校验。

执行时发现状态变化就冲突，不自动套用旧批准。

## 36. Reducer 决定并发状态更新如何合并

多个并行节点同时更新一个列表或字段时，覆盖、追加和去重要显式定义。错误 reducer 会丢数据或重复消息。

需要顺序的业务动作不要靠 reducer 猜顺序，而应在图结构中表达依赖。

## 37. 错误重试要按节点语义配置

临时检索失败可有限重试；非法输入和权限失败不重试；写节点依赖幂等和状态查询；interrupt 不是错误重试。

错误状态保留原类别和 attempt，防止图反复在同一节点循环。

## 38. 图测试先测试节点，再测试路径

- 节点：给固定状态，检查更新和副作用请求。
- 路由：每个枚举状态走正确边。
- 图：成功、拒绝、失败、取消、预算、审批路径。
- 恢复：在每个副作用窗口注入崩溃。
- 安全：thread/检查点跨租户不可见。

真实模型不是大多数编排测试的必要条件。

## 39. 生产图需要版本化发布和迁移策略

记录 graph version、state schema、node/tool registry、提示和模型版本。新代码处理旧 thread 前做兼容判断。

重大图变化可让旧执行继续走旧版本，新请求进入新版本；或显式迁移后再切换。不要在运行中无标识替换节点含义。

## 40. LangChain/LangGraph 不是安全层

框架帮助编排、状态和观测，不自动完成认证、ACL、提示注入防护、审批、幂等和领域规则。这些仍由应用和业务服务负责。

## 41. 何时值得使用，何时保持普通代码

```text
单次调用/固定两三步 → 官方 SDK + 普通函数
多供应商组件组合/统一 tracing → 可考虑 LangChain
长流程、分支、循环、恢复、人工介入 → 可考虑 LangGraph
高确定性业务事务 → 仍由普通领域工作流掌控
```

框架选择以复杂度收益和可运维性为准，不以流行程度为准。

## 42. 这一阶段应形成的整体地图

```text
直接 SDK 黄金路径
  ↔ LangChain Runnable/Prompt/Model/Parser/Retriever adapter
       → 领域端口隔离

LangGraph：versioned state
  → small nodes → complete routing → bounded loop
  → checkpoint/thread → interrupt/approval → idempotent side effect
```

必须掌握：先懂直接 SDK；框架最终请求才是事实；Parser 不保证业务正确；Retriever 不扩大 ACL；回调不是审计；图状态不是业务真相；每个循环必须结束；checkpoint 不提供 exactly-once；interrupt 恢复可能重跑节点；副作用必须幂等；框架版本变化不能直接穿进领域层。

LangChain/LangGraph API 更新较快，实际代码以锁定版本的 [LangChain 官方文档](https://docs.langchain.com/) 为准，尤其核对 [LangGraph Persistence](https://docs.langchain.com/oss/python/langgraph/persistence) 与 [Interrupts](https://docs.langchain.com/oss/python/langgraph/interrupts) 的当前语义。
