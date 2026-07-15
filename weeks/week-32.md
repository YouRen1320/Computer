# 第32周：LangChain、LangGraph、Agent/Workflow、HITL与MCP

## 本周定位

本周最后才引入Agent框架。目标是理解什么时候普通代码、显式工作流、单Agent工具循环或状态图最合适，并实现一个有必要、可恢复、可人工介入的有限流程。禁止为了展示而创建多Agent团队。

## 前置条件

- 模型、工具、RAG、评估、安全和观测已经可用；
- 至少80条评估回归；
- 工具默认只读，Java保留业务写权限；
- Python服务具备持久化和内部身份。

## 本周目标

- 理解框架、runtime、agent harness和workflow区别；
- 使用LangChain 1.x建立模型/工具/中间件的高层抽象；
- 使用LangGraph 1.x定义state、node、edge和checkpoint；
- 实现interrupt/human-in-the-loop和恢复；
- 限制步数、工具、预算、超时和副作用；
- 理解MCP是上下文/工具协议，不是Agent或业务API替代；
- 固定Java/Python边界并通过阶段考核。

## 必须理解的概念

- deterministic workflow与agentic loop；
- 顺序、并行、条件路由、循环和人工审批；
- model、tool、middleware、memory和state；
- thread、checkpoint、persistence和durable execution；
- idempotency与恢复后重复副作用；
- interrupt、审批、修改state和resume；
- short-term state与长期业务记忆/用户画像的区别；
- context engineering、工具结果压缩和上下文预算；
- 最大step、递归限制、timeout、budget和dead end；
- 多Agent的通信/成本/调试代价；
- MCP host/client/server、tool/resource/prompt和transport；
- MCP远程认证、最小scope和工具信任；
- MCP不是消息队列、workflow engine或业务权限系统；
- Spring AI与LangGraph的能力重叠和生态差异。

## 时间与任务（15—18小时）

下方120分钟无AI训练计入任务3—4的图分支与恢复实现，不在总时长之外重复增加。

### 任务1：复杂度阶梯实验（2小时）

用同一“查手册+查历史+生成检查项”问题分别画出：普通函数、显式条件workflow、工具循环和LangGraph。比较确定性、状态、恢复、调试、成本和必要性。

### 任务2：LangChain最小Agent（2—3小时）

- 使用现有模型adapter或框架集成；
- 注册两个只读工具；
- 添加工具allowlist、最大步数和错误处理；
- 观察trajectory和token；
- 用fake/recording模型测试，不将其直接作为最终实现。

### 任务3：受控LangGraph（4小时）

实现：

1. 接收问题与asset/work order上下文；
2. 检索手册；
3. 检索相似关闭工单；
4. 判断证据是否充分；
5. 不足则生成一个补充问题并interrupt；
6. 用户补充后resume；
7. 输出带引用检查单；
8. 高风险步骤标记需人工确认。

定义明确state schema、node输入输出和终止条件。

### 任务4：持久化与副作用（3小时）

- 将checkpoint持久化到受控存储；
- 在节点失败后恢复；
- 确保恢复不会重复外部副作用；
- 线程绑定tenant/user并在resume重新授权；
- 设置过期、删除和隐私策略；
- 测试模型超时、工具失败、循环和用户取消。

### 任务5：MCP最小实验（2小时）

- 阅读MCP架构，运行或实现一个本地只读server/client；
- 只暴露非敏感演示工具；
- 对比本地函数tool、内部REST和MCP的使用场景；
- 说明远程MCP的OAuth/HTTPS/audience/scope要求；
- 不把FactoryCare核心业务API全部包装成MCP。

### 任务6：阶段答辩与求职（2小时）

- 跑完整AI评估和安全回归；
- 进行20分钟AI架构答辩；
- 进行一次AI应用岗位模拟面试；
- 更新README、ADR和简历。

## FactoryCare项目增量

- 一个bounded LangGraph诊断流程；
- checkpoint、interrupt、resume和失败恢复；
- 只读工具、最大步数、超时和预算；
- 一个隔离MCP概念实验；
- Spring AI vs LangGraph选择ADR；
- G6阶段评估证据。

## AI协作边界

AI可以帮助画图、生成state类型和失败场景，但流程边界、工具权限、持久化、恢复和人工审批必须由人决定。不得让Agent修改Java工单状态或动态发现无限工具。

## 无AI训练（120分钟）

为图增加“检索证据不足→追问→恢复”分支：定义state变化、checkpoint键、重新授权和两个测试；解释为什么普通while循环在当前持久恢复要求下不够。

## 求职动作

- 准备白板画出Agent loop和FactoryCare状态图；
- 模拟回答：Agent与Workflow、memory与数据库、MCP与REST、HITL与普通确认框、LangChain与LangGraph区别；
- 定向投递AI应用/Agent岗位，不投纯算法训练岗位作为主线。

## 交付物

- [ ] 四种复杂度方案比较；
- [ ] bounded LangGraph源码和图；
- [ ] checkpoint/interrupt/resume测试；
- [ ] 工具权限、步数、预算和失败测试；
- [ ] MCP最小实验与安全说明；
- [ ] 完整AI评估回归；
- [ ] ADR、模拟面试和周复盘。

## 验收标准

- 能用一句话说明为什么当前流程需要LangGraph；
- 节点失败可恢复，恢复不重复副作用；
- resume重新验证用户/租户权限；
- 工具只读或需要明确人工批准；
- 最大步数、超时和预算生效；
- MCP不被当成Agent框架或权限系统；
- G6全部要求通过。

## 本周明确不做

- 多Agent组织和自主协商；
- Agent直接操作生产写权限；
- 长期保存全部用户对话而无删除策略；
- 把所有函数包装成MCP；
- 同时学习AutoGen、CrewAI等多个框架；
- 用框架替代确定性Java业务流程。

## 官方资料

- [LangChain agents](https://docs.langchain.com/oss/python/langchain/agents)
- [LangGraph overview](https://docs.langchain.com/oss/python/langgraph/overview)
- [LangGraph persistence](https://docs.langchain.com/oss/python/langgraph/persistence)
- [Model Context Protocol introduction](https://modelcontextprotocol.io/docs/getting-started/intro)
- [Spring AI MCP](https://docs.spring.io/spring-ai/reference/api/mcp/mcp-overview.html)
