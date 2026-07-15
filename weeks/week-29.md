# 第29周：模型API、结构化输出、流式响应与工具调用

## 本周定位

本周先直接使用模型官方SDK理解基础能力，不引入LangChain/LangGraph。目标是知道模型API究竟提供什么、应用负责什么，并完成可替换、可测试、可控成本的分诊与报告草稿。

## 前置条件

- Python服务、类型、测试、日志和内部认证通过；
- 准备一个可用模型提供商和受限开发密钥；
- 配置费用上限与用量监控；
- 模型不可用时Java核心业务仍能运行。
- Week 18的`ai-integration`端口、服务身份、超时/降级契约和只读工具回调约束已存在。

## 本周目标

- 理解消息、指令、token、上下文窗口和生成参数；
- 设计模型提供商adapter，避免业务代码绑定SDK；
- 使用schema约束结构化输出并做二次验证；
- 实现可靠流式输出、取消和错误终止；
- 理解tool calling是模型请求、应用执行的循环；
- 记录模型、prompt、延迟、token、成本和结果版本；
- 用fake模型完成确定性测试。

## 必须理解的概念

- model、provider、endpoint和兼容API不是同一层；
- system/developer/user/tool消息或等价角色；
- token、context window、input/output上限和截断策略；
- prompt template、变量、版本和注入边界；
- temperature/top-p等采样参数的作用与不确定性；
- structured output、JSON schema、解析失败和业务校验；
- streaming chunk、首token延迟、完整响应和取消；
- tool definition、input schema、tool call、tool result和循环；
- 模型不能直接访问数据库/API，执行权在应用；
- timeout、429、5xx、有限重试、退避和fallback；
- 重试非幂等模型/工具步骤的风险；
- token/cost预算、并发限制和审计；
- prompt不是安全边界，权限必须在工具和服务端；
- mock/fake适合代码测试，固定评估集适合质量测试。

## 时间与任务（15—18小时）

下方120分钟无AI训练计入任务3的结构化分诊，不在总时长之外重复增加。

### 任务1：最小API实验（2小时）

- 完成一次同步和一次流式调用；
- 记录原始请求、响应元数据、token和延迟；
- 测试超长输入、取消、429/假错误和模型拒绝；
- 不把密钥或完整敏感内容写入日志。

### 任务2：模型adapter（3小时）

- 定义`ModelClient` Protocol和内部请求/响应；
- 封装provider SDK、超时和错误映射；
- 配置模型别名而不是在业务代码散落具体模型名；
- 实现fake client；
- 对provider特有能力允许显式下沉，不假装所有模型完全可替换。

### 任务3：结构化分诊（3小时）

- 定义category、priority、faultCode、confidence、evidence和questions schema；
- 模型输出经过Pydantic和业务枚举二次校验；
- 低置信度、高风险、未知枚举转人工；
- 不允许模型自动派单、改SLA或写状态；
- 用至少15条样例验证schema valid rate和明显错误。
- 实现`POST /internal/v1/report-drafts`：只根据结构化解决记录生成报告/知识草稿，不补造工时、备件或操作，并用fake覆盖非法输出。

### 任务4：流式报告/回答骨架（3小时）

- Python输出稳定的流事件协议；
- Java代理给客户端并保留traceId；
- 处理开始、文本、元数据、错误和结束事件；
- 客户端取消向下传播；
- 中途失败不能留下“成功完成”状态；
- 测试慢客户端、断开和重复结束事件。
- 复用Week 22的流状态模式，在Vue管理端增加最小诊断/报告面板：经Java代理连接、可取消、显示traceId和明确失败，不直连Python。

### 任务5：只读工具调用（3小时）

- 定义`get_asset_summary`和`get_work_order_history`等只读工具schema；
- 模型只能请求工具；Python使用短时服务身份和原始用户/租户上下文回调Java的`/internal/v1/ai-tools/*:invoke`允许列表，Java逐次重新授权后决定是否执行；
- Python不得直读`core` schema，Java不得提供通用SQL、任意URL或写操作工具；
- 限制工具数、循环步数、参数和返回大小；
- 记录tool call与结果摘要；
- 构造越权ID、无效参数和工具超时。

### 任务6：Spring AI对照和复盘（2小时）

- 用Spring AI 2.0做一个独立最小structured output或tool实验；
- 比较Java内集成与Python服务的开发、部署、类型、生态和边界；
- 不把同一功能在主项目保留两份生产实现。

## FactoryCare项目增量

- provider adapter和fake model；
- 工单分诊建议接口；
- `knowledge`幂等消费`WorkOrderClosed.v1`，经`ai-integration`调用报告草稿接口并保存待审核草稿；失败只记录重试/人工补写，不回滚关单；
- 流事件协议与Java代理骨架；
- Vue AI流式面板及取消、失败与会话过期测试；
- `ai-integration`真实Python客户端、身份、超时、熔断/降级和审计；
- 两个Python→Java只读工具回调与重新授权测试；
- prompt/model版本和调用元数据；
- 小型质量样例集。

## AI协作边界

可以让AI帮助设计schema、生成测试案例和审查prompt，但不能让正在被开发的模型自行证明其输出正确。任何工具权限、数据范围、预算和人工审批由代码控制。

## 无AI训练（120分钟）

为分诊接口增加一个新故障类别：更新schema、业务校验、fake和测试；再处理一次模型返回合法JSON但业务枚举非法的情况。不得通过“重试直到成功”掩盖错误。

## 求职动作

- 开始更新AI应用简历，但只写已完成的模型API、结构化输出和工具调用；
- 模拟回答：Function Calling和普通JSON输出区别；模型为什么不能直接获得数据库权限；流式输出如何取消；模型切换为什么不能只改URL。

## 交付物

- [ ] 模型adapter和fake；
- [ ] 结构化分诊schema与至少15条样例；
- [ ] `WorkOrderClosed.v1 → report-drafts → knowledge draft`幂等链路和失败降级测试；
- [ ] 流事件协议、取消和错误测试；
- [ ] Vue流式面板与Java代理联调；
- [ ] 只读工具与权限失败测试；
- [ ] Java/Python双向身份、上下文过期和超时测试；
- [ ] 调用成本/延迟记录；
- [ ] Spring AI对照笔记；
- [ ] 无AI任务和周复盘。

## 验收标准

- 模型输出不能绕过Pydantic和Java业务规则；
- 流式取消和失败有明确状态；
- 工具调用有服务端权限、超时和步数限制；
- Python不能直读核心库，工具回调在Java重新验证服务、用户、租户、资源和scope；
- 测试默认使用fake，不消耗真实费用；
- 能解释provider adapter的价值和局限；
- 密钥、token和敏感输入不进入仓库/普通日志。

## 本周明确不做

- RAG、向量数据库和LangGraph；
- 多Agent；
- 高风险写工具；
- 大量Prompt技巧收藏；
- 自动fallback后不做质量评估。

## 官方资料

- 使用所选模型提供商当期官方API、structured output、streaming和tool calling文档；
- [Spring AI Model API](https://docs.spring.io/spring-ai/reference/api/chatmodel.html)
- [Spring AI Tool Calling](https://docs.spring.io/spring-ai/reference/api/tools.html)
- [Pydantic models](https://docs.pydantic.dev/latest/concepts/models/)
