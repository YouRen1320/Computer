# 第31周：RAG评估、重排、安全、成本与可观测性

## 本周定位

本周把“能回答”升级为“知道什么时候答得对、错在哪里、是否越权、成本多少、怎样回归”。生产AI与演示聊天壳的主要分界就在评估、安全和故障处理。

## 前置条件

- 文档入库、hybrid retrieval和citation可运行；
- 有30条初始评估和失败样例；
- 模型/prompt/index版本可记录；
- traceId可跨Java/Python传递。

## 本周目标

- 把评估集扩展到至少80条；
- 分开评估检索、生成、引用、权限和结构化输出；
- 理解离线/在线评估、人工/规则/LLM judge的边界；
- 优化切块、hybrid和rerank，并用数据比较；
- 测试Prompt Injection、数据泄漏和工具滥用；
- 建立AI trace、延迟、token、成本和失败监控；
- 建立超时、fallback、缓存和feature flag降级策略。

## 必须理解的概念

- golden dataset、代表性、难例、版本和数据污染；
- retrieval recall@K、MRR/NDCG概念、命中与排序；
- answer correctness、groundedness、relevance；
- citation precision、coverage和citation是否真的支持结论；
- no-answer precision/recall；
- schema validity和分类指标；
- 人工评估、确定性规则和LLM-as-judge的偏差/漂移；
- offline regression与online sampling/feedback；
- A/B test概念和小样本误判；
- prompt injection、indirect injection、data exfiltration；
- tool least privilege、allowlist、参数校验和人工审批；
- latency分解：检索、rerank、模型首token/总时长；
- input/output token、模型费用和预算；
- semantic cache风险、敏感数据和旧答案；
- timeout、circuit breaker、fallback model和质量重新评估；
- observability与隐私：默认不记录完整prompt/document/tool结果。

## 时间与任务（15—18小时）

下方120分钟无AI训练计入任务3的检索优化与失败归因，不在总时长之外重复增加。

### 任务1：评估集扩充（3小时）

达到最低结构：

- 正常手册问答25；
- 相似历史案例15；
- 无答案/信息不足10；
- 跨租户/权限10；
- Prompt Injection 10；
- 结构化分诊10。

每条保存输入、预期source/行为、tenant/role、人工标签和版本。避免全部由同一模型生成并评判。

### 任务2：评估执行器（3小时）

- 可选择prompt/model/index版本执行；
- 保存retrieval候选、引用、回答和错误；
- 计算可确定的指标；
- 对主观质量使用盲化人工rubric或辅助judge；
- 可重跑并比较两次run；
- 费用和并发受限。

### 任务3：检索优化实验（3小时）

只改变一个变量进行至少两次实验：

- chunk策略；
- vector/topK；
- hybrid权重/RRF；
- metadata过滤；
- reranker。

报告改善、退化、成本和统计边界。不因平均值提升而隐藏某类严重失败。

### 任务4：安全红队（3小时）

- 文档中嵌入“忽略指令/泄漏秘密/调用工具”；
- 用户请求跨租户信息；
- citation指向无关段落；
- 工具参数包含越权ID、SQL/URL注入或超长输入；
- 模型循环请求工具；
- 日志/trace尝试记录敏感内容。

权限必须在检索查询和工具实现层阻止，不靠prompt说“不要”。

### 任务5：观测与降级（2—3小时）

- trace包含Java请求、Python处理、检索、模型和工具span；
- 指标包含请求数、失败、首token、总延迟、token、成本和no-answer；
- 模型超时返回可理解降级，不阻止人工工单流程；
- feature flag可关闭AI；
- fallback模型启用前跑最小回归；
- 默认对敏感输入脱敏或不采集。

### 任务6：AI评估看板、报告和求职（2小时）

- 输出优化前后报告和三个典型失败；
- 在Vue管理端接入只读评估API，展示run版本、核心指标、成本、失败分类与样例详情；不能只展示一个“准确率”。
- 用5分钟讲清“怎么知道RAG变好了”；
- 更新R4简历和项目README评估证据。

## FactoryCare项目增量

- 80+条固定评估集；
- 可版本化eval runner和报告；
- 一次检索/重排优化对照；
- Prompt Injection和越权测试；
- AI trace、成本和降级；
- feature flag和模型失败回退。
- Vue AI评估看板及权限、空/失败/版本切换测试。

## AI协作边界

AI可以协助生成候选测试，但人工必须审查代表性和预期答案。不要让被测模型独自生成、回答、评分并宣布成功。LLM judge结果只是一种信号，不是事实。

## 无AI训练（120分钟）

给定五个失败案例，区分解析、切块、召回、排序、上下文、生成、引用或权限层根因；选择一个变量修改并运行回归，写出为什么没有同时改其他变量。

## 求职动作

- 完成一次AI应用模拟面试；
- 准备回答：如何评估RAG、如何防提示注入、为什么不只看准确率、fallback模型有哪些风险、是否会记录用户prompt；
- 开始定向投递AI应用/RAG岗位，每周10—15个高匹配样本。

## 交付物

- [ ] 80+条版本化评估集；
- [ ] eval runner和两次run对比；
- [ ] 安全红队记录；
- [ ] trace/metric/cost面板或查询；
- [ ] 超时、feature flag和降级演练；
- [ ] 优化报告和失败案例；
- [ ] Vue AI评估看板与失败状态测试；
- [ ] 无AI任务和周复盘。

## 验收标准

- 跨租户泄漏为0；
- 每个结论能追溯数据集、版本和运行；
- 能区分检索失败与生成失败；
- 至少一次优化有数据证据，也报告退化项；
- 模型不可用不阻塞人工业务；
- 日志/trace不默认泄漏敏感内容。
- 评估看板只能读取当前租户/授权run，并能追溯prompt/model/index/dataset版本。

## 本周明确不做

- 用一次人工试玩当评估；
- 只报告最佳案例；
- 让prompt替代权限；
- 无限制记录全部模型输入输出；
- 未评估就自动切换模型。

## 官方资料

- [LangSmith evaluation concepts](https://docs.langchain.com/langsmith/evaluation)
- [Spring AI observability](https://docs.spring.io/spring-ai/reference/observability/)
- [OWASP Top 10 for LLM Applications](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
- [OpenTelemetry semantic conventions](https://opentelemetry.io/docs/specs/semconv/)
