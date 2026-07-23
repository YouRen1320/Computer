---
schema_version: 2
edition: 2026.2-draft
id: ch.ir.hybrid-rerank
title: 稀疏/稠密混合检索、候选融合与重排
responsibility: 融合词法与向量候选并用可解释规则或重排模型排序，在冻结评估集上证明增益和代价，不直接生成答案。
volume: '14'
order: 11
level: L3
status: drafting
path: book/volume-14-llm-rag-agents/chapters/ch.ir.hybrid-rerank.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ir.evaluation
- ch.ir.dense-pgvector
version_surfaces:
- python-3.14
- postgresql-18
- pgvector
- pandas
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
  text: 在 120 秒内解释“稀疏/稠密混合检索、候选融合与重排”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - ir-hybrid-fusion
  - ir-reranking
  covers_topics:
  - ir.reciprocal-rank-fusion
  - ir.score-normalization
  - ir.candidate-union
  - ir.deduplication
  - ir.reranker-contract
  - ir.rerank-depth
  - ir.rerank-latency
  - ir.hybrid-ablation
  uses_capabilities:
  - ai.rag-ingestion-retrieval
  - ai.llm-model-api
  - data.numpy-pandas
  - math.linear-calculus
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“稀疏/稠密混合检索、候选融合与重排”构建可运行程序与测试：实现 BM25 + pgvector 候选的 RRF 融合与可替换重排器，完成稀疏、稠密、混合、重排四组消融；独立保存可复现工件与判断结果
  covers_topic_groups:
  - ir-hybrid-fusion
  - ir-reranking
  covers_topics:
  - ir.reciprocal-rank-fusion
  - ir.score-normalization
  - ir.candidate-union
  - ir.deduplication
  - ir.reranker-contract
  - ir.rerank-depth
  - ir.rerank-latency
  - ir.hybrid-ablation
  uses_capabilities:
  - ai.rag-ingestion-retrieval
  - ai.llm-model-api
  - data.numpy-pandas
  - math.linear-calculus
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: frozen-query-benchmark-ablation-study-latency-budget
- id: diagnose
  kind: fault-diagnosis
  text: 面对“直接相加不可比得分、候选去重丢权限、只报告最好查询或重排深度导致延迟失控”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - ir-hybrid-fusion
  - ir-reranking
  covers_topics:
  - ir.reciprocal-rank-fusion
  - ir.score-normalization
  - ir.candidate-union
  - ir.deduplication
  - ir.reranker-contract
  - ir.rerank-depth
  - ir.rerank-latency
  - ir.hybrid-ablation
  uses_capabilities:
  - ai.rag-ingestion-retrieval
  - ai.llm-model-api
  - data.numpy-pandas
  - math.linear-calculus
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 稀疏/稠密混合检索、候选融合与重排

> 稀疏检索擅长型号、故障码和精确术语；稠密检索擅长没有共享词面的语义表达。混合检索不是把两个浮点数随手相加，而是先保持两路证据，再按明确合同融合、去重、过滤和重排。本章只输出候选顺序，不生成答案；所有增益必须在同一冻结查询集和延迟预算中证明。

## 1. 为什么两路候选会互补

查询 `E37 inverter fault` 含精确故障码，BM25 往往直接命中；向量模型可能弱化短代码。查询“设备转动时发出尖锐声”，知识文档写“轴承异响”，稠密模型可能在没有相同词面的情况下找回，而纯词法可能失败。

这两类能力没有谁永久优越。数据、语言、型号格式和模型都会改变结果。正确问题不是“BM25 还是向量”，而是：

- 两路各自在哪些预定义切片成功或失败？
- 合并候选是否提高 Recall/nDCG？
- 重排是否把更相关文档推到前面？
- 额外延迟、成本、失败模式和安全风险是多少？

只有四组消融使用同一查询、标签、ACL、语料和 `k`，才能回答这些问题。

## 2. 混合检索的完整数据流

```text
查询 + 当前授权边界
  ├─ 词法规范化 -> sparse top-N + rank/score/explanation
  └─ embedding -> dense top-N + rank/distance/space
             ↓
       ACL 强制、候选并集、稳定去重
             ↓
          融合排序（如 RRF）
             ↓
       top-M 可选重排 + 延迟/失败策略
             ↓
      候选 ID、分数、来源与版本证据
```

每一步都应保留输入版本和来源。最终候选不能只剩一个神秘 `score=0.72`；至少要知道它来自 sparse、dense 还是两者，原始名次、空间/索引版本、融合参数和是否经过重排。

## 3. 原始分值为什么不能直接相加

BM25 分数不是概率，尺度随语料、查询词数量、IDF 和实现变化。余弦相似度常落在较窄区间，但也不是校准概率。假设：

```text
sparse: A=10, B=9
dense:  A=0.1, B=0.9
```

直接相加得到 `A=10.1, B=9.9`，A 第一。若仅把 dense 分值乘 100——内部排序完全没变——结果变成 `A=20, B=99`，B 第一。系统对单位缩放敏感，说明相加没有稳定语义。

公开练习保存了这个错误：同一名次证据只因数值尺度变化而翻转，`verify.sh` 稳定红。

可以训练校准或学习融合模型，但需要独立数据、特征版本和漂移监控。没有这些证据时，基于名次的融合通常是更透明的基线。

## 4. 常见分数归一化及陷阱

### 4.1 Min-max

```text
normalized = (score - min) / (max - min)
```

它依赖当前候选集合；加入一个极端值会改变所有归一化分数。若 `max=min` 还需边界政策。不同查询的值不可直接比较。

### 4.2 z-score

```text
z = (score - mean) / std
```

候选少、分布偏斜或标准差为零时不稳定。它仍不把分数变成相关概率。

### 4.3 全局校准

可用标注数据拟合 logistic/等距等校准，但分布变化、模型升级和 query 切片会让校准失效。必须在未参与训练的数据上验证，并保存版本。

这些方法不是禁用，而是不能因为输出都在 `[0,1]` 就宣称可比较。RRF 直接绕开原始尺度，使用每路相对名次。

## 5. Reciprocal Rank Fusion

对文档 `d`、多路排名 `r`：

```text
RRF(d) = Σ_r 1 / (k_rrf + rank_r(d))
```

文档未出现在某一路，就没有该路贡献。`k_rrf` 是平滑常数，本章固定 60。它降低第一名与后续名次的差距，使多路都靠前的文档容易胜出。

RRF 的优点：

- 对每路正比例分值缩放不敏感；
- 不需要先把 BM25 和余弦校准到同一单位；
- 每个贡献能按来源与名次解释；
- 实现简单，适合作为混合基线。

局限：只看名次，忽略同一路中第一名领先第二名多少；参数与候选深度仍需评估；差质量来源也会贡献。它不是“最佳算法”的证明。

## 6. 四文档手算 RRF

两路：

```text
sparse = [A, B, C]
dense  = [B, D, A]
k_rrf = 60
```

分数：

```text
A = 1/61 + 1/63
B = 1/62 + 1/61
C = 1/63
D = 1/62
```

因此 `B > A > D > C`。注意 D 只在 dense 出现，因第一名次之后的 rank2 贡献仍高于 C 的 sparse rank3。

并列时本章使用 `doc_id ASC`。每个融合结果保存来源名次，例如 B 的 provenance 是 `{sparse:2,dense:1}`。只保存总分会丢失解释与诊断能力。

## 7. 候选并集与去重

候选并集是所有允许候选的文档 ID 集合；同一文档出现在两路只保留一个结果，但累加两路证据。

去重键必须稳定。用标题或 chunk 文本去重会误合并不同版本/不同权限文档，也可能因轻微格式变化不去重。通常使用版本化 `chunk_id`，并保留来源文档 ID、chunk 位置与内容哈希。

近似重复是另一个问题：同一来源重叠 chunk 可能占满 top-k。可做 parent-level 去重或多样性约束，但会改变召回和引用粒度，应作为单独消融，不要混在“修一个 bug”的提交里。

去重不能合并权限。若两个内容相同的 chunk 分属不同租户，不能因为文本哈希相同就把一个租户的可见性赋给另一个。安全身份与内容身份是不同维度。

## 8. ACL 必须早于融合与重排

FactoryCare 的授权由 Java 根据当前用户、租户和业务规则决定。检索层接收当前请求允许的文档/chunk 范围，并在每路候选可见前强制执行。

本章 RRF 实现先过滤每路排名，再重新编号授权候选名次。无权限文档不会进入融合字典、重排器、日志或缓存。

仅在最终 UI 隐藏无权限结果有多个问题：

- 中间日志与 trace 已经泄漏 ID/标题；
- 无权限候选占据 top-N，过滤后召回不足；
- 重排模型可能接触敏感正文；
- 缓存若未包含身份/权限版本，结果可能跨用户复用。

检索缓存键至少考虑 query 规范化、索引版本、space、融合/重排版本和授权边界版本。高基数 ACL 使缓存策略更复杂，不能省略安全维度来提高命中率。

## 9. 候选深度不是越大越好

设 sparse 取 `N_s`、dense 取 `N_d`、重排前融合取 `M`。更深候选可能提高召回，却增加：

- 数据库扫描与网络传输；
- 融合和去重成本；
- 重排模型输入与延迟；
- 敏感数据暴露面；
- 上下文构建成本。

太浅则相关文档根本进不了融合池，重排器无法“救回”不存在的候选。重排只能重排输入集合，不能创造未检索文档。

候选深度应在冻结查询集上画质量—延迟曲线，按预算选择。不要只在一个成功查询把 N 调到 1000 后宣布召回解决。

## 10. 重排器的合同

重排器接收：查询、有限且已授权的候选、候选文本/元数据、模型或规则版本；输出：每个输入候选的新分数或排列。

不变量：

- 输出 ID 必须是输入候选子集，不能凭空新增；
- 不得恢复已过滤的无权限候选；
- 重复/缺失 ID、NaN、超时和部分失败有明确处理；
- 输入顺序和批次策略固定；
- 模型、提示、截断、最大长度和分数方向版本化；
- 原始融合顺序保留，便于失败降级。

重排可以是透明规则、cross-encoder 或模型 API。规则易解释但表达力有限；模型能联合阅读查询与候选文本，但带来成本、截断、非确定性和供应商错误。选择必须用消融证据。

## 11. 只重排头部并保留尾部

常见策略是只重排融合前 `M` 条，尾部保持原顺序：

```text
reranked = sort_by_model(fused[:M]) + fused[M:]
```

这使成本有上限，但产生边界效应：第 `M+1` 条即使高度相关也没有机会进入头部。实验应比较不同 M 的质量和延迟。

若模型返回部分候选，可选择整个重排失败并回退融合序，或只接受完整前缀。不能把半截输出静默标为完整。重试还要遵守请求预算，尤其模型 API 重排可能超时或限流。

## 12. 延迟预算与降级

端到端检索预算可拆为：

```text
embedding + sparse + dense + fusion + fetch_text + rerank + serialization
```

sparse 与 dense 可并发，但必须有共同 deadline 和取消。某一路失败时的政策可能是：

- 关键安全/ACL 错误：整体失败；
- dense 超时：返回明确标记的 sparse 降级结果；
- rerank 超时：回退融合顺序；
- 两路都空：返回无候选，不让生成模型编造。

降级状态应进入响应元数据与监控。把 dense 失败当空列表后仍标记“hybrid success”，会污染评估和 SLO。

本章 lab 的延迟值只是固定预算夹具，字段明确为 `controlled_budget_fixture_not_wall_clock`。它验证预算逻辑，不证明真实 p95。

## 13. 四组消融必须在同一输入上

至少比较：

1. `sparse`：BM25 基线；
2. `dense`：精确或已记录 ANN 参数的向量基线；
3. `hybrid`：候选并集 + RRF；
4. `rerank`：hybrid 头部 + 指定重排器。

必须相同：查询集/qrels 哈希、语料快照、ACL、top-k、未判断政策和失败查询集合。每组保存逐查询排名、P/R/MRR/nDCG、耗时和错误。

通过条件应预先定义，例如：hybrid 在平均 nDCG 上超过两路基线，关键切片无不可接受退化，rerank 进一步提升且 p95 在预算内，ACL 泄漏为零。阈值要由产品风险决定，本章不伪造生产数字。

如果只展示 Q1 的提升，不报告 Q2/Q3 退化，就是 cherry-picking。查看平均值后才发明“成功切片”也不能作为确认性结论。

## 14. lab 的三查询消融

受控夹具有三条查询：

- Q1 的 sparse 排名接近理想，dense 第一条无关；
- Q2 的 dense 理想，sparse 把次相关放第一；
- Q3 两路都能找到唯一相关文档，但位置不同。

RRF 让多路都出现的候选上升；scripted reranker 对头三条按固定分数排序。逐查询 nDCG 聚合后，夹具满足：

```text
hybrid mean nDCG > sparse mean
hybrid mean nDCG > dense mean
rerank mean nDCG > hybrid mean
```

这组数据是为了证明管线和断言有鉴别力，重排分数是人工脚本，不能当成真实模型质量。实验额外加入高分无权限 X，验证四组结果都不能让 X 重现。

## 15. 质量增益还要问代价

即使重排 nDCG 增加，也要同时记录：

- sparse/dense 数据库耗时和候选量；
- query embedding API 成本与缓存命中；
- 重排调用次数、token/字符、批次数和失败率；
- p50/p95/p99 与超时；
- 索引构建和存储；
- 数据新鲜度；
- 安全与隐私影响。

收益很小但延迟翻倍，可能不值得；也可能对高价值故障诊断切片非常值得。权衡必须按场景和预设目标说明。

不要把预算夹具的 `17ms` 写入简历当生产性能。真实证据需要目标机器、固定镜像、真实服务和重复测量。

## 16. 可观测性

每次检索可记录结构化摘要：

```text
request_id, query_hash, corpus/index/space versions
authorized candidate scope version
sparse_count, dense_count, union_count, rerank_depth
per-stage latency, degradation state, error class
top-k ids or privacy-safe hashes, source ranks
```

完整查询和文档可能含 PII，不应默认进入日志。日志脱敏、访问控制和保留期必须由安全政策决定。

监控还应按 query 切片跟踪零候选、单路失败、融合候选不足、重排超时、NaN 分数、ACL 拒绝和索引新鲜度。线上点击不能直接替代相关性标签。

### 16.1 provenance 数据结构

每个最终候选可带一份机器可读解释：

```json
{
  "chunk_id": "C42",
  "sources": {
    "sparse": {"rank": 2, "score": 7.31, "index": "bm25-v4"},
    "dense": {"rank": 1, "distance": 0.18, "space": "embed-v3"}
  },
  "fusion": {"method": "rrf", "k": 60, "score": 0.0325},
  "rerank": {"applied": true, "rank": 1, "version": "rr-v2"}
}
```

这不是给最终用户展示全部内部数字，而是调试/评估证据。生产响应可裁剪敏感字段，但 trace 中仍需受访问控制。若重排失败回退，`applied=false` 并带错误分类，不能保留旧 rerank 分数造成误导。

### 16.2 候选身份与来源版本

同一 `chunk_id` 在索引重建后文本可能变化，因此 provenance 还应绑定内容哈希或 chunk 版本。评估排名只存 ID 而语料后来覆盖，会使历史指标不可复核。

候选合并时若 sparse 和 dense 指向同一来源的不同 chunk 版本，应拒绝或按迁移政策选择，而不是当同一文档累加两份证据。混合系统必须先保证两路读取同一语料水位，才谈融合增益。

### 16.3 并行请求的 deadline 传播

sparse 与 dense 并行时，父请求设置一个绝对 deadline；各子任务获得剩余预算。父请求取消后，数据库查询、HTTP Embedding 与重排任务都应尽快取消并释放连接。

常见错误是 `gather` 等待所有任务，即使 sparse 已成功、dense 已超过降级预算；或超时后后台任务继续写缓存。测试应使用可控延迟夹具证明：deadline 到达、任务结束、不会晚到覆盖结果、不会重复计费调用。

### 16.4 幂等与重试边界

纯检索通常无业务副作用，但外部模型调用会计费，日志/缓存也有写入。重试只能针对明确临时错误，并服从总 deadline、次数和退避。认证失败、schema 错误、ACL 错误不应重试。

重排超时后若回退融合，后台重排结果不能随后更新同一响应或缓存为正常结果。缓存值要带完成状态、系统版本和降级标志。

### 16.5 RRF 参数和深度的联合实验

`k_rrf`、`N_s`、`N_d`、`M` 会互相影响。一次只看一个参数能解释局部效果，但最终要对可行组合做受控搜索。参数选择必须在开发集完成，测试集只做最终复核。

报告不应只列最佳组合；同时保存搜索空间、每组质量/延迟、失败组合和选择规则。否则下一次数据漂移后无法判断当初为何选择 `k=60`。

### 16.6 单路权重的扩展

若业务证据表明某路更可靠，可用加权 RRF：

```text
score(d) = Σ weight_r / (k + rank_r(d))
```

权重仍基于名次而非原始尺度，但会增加调参自由度。权重必须非负、有版本、在冻结开发集选择，并与无权重基线消融。按单条查询动态手调权重会过拟合。

### 16.7 多样性与父文档聚合

top-k 可能全是同一手册相邻 chunk。可以限制每个父文档数量、采用最大边际相关性或先按父文档聚合。但多样性可能把最相关的第二个 chunk 推后。

引用需要精确 chunk，展示可能需要父文档；数据结构应同时保留 parent ID 与 chunk ID。ACL 按最严格实体执行，不能因父级聚合扩大子 chunk 可见性。

### 16.8 灰度、影子与回滚

上线前可让新 hybrid 在影子路径读取相同请求但不影响用户，比较排名与资源。影子仍会处理真实数据和调用模型，必须经过隐私、容量和成本审批。

灰度路由记录系统版本，避免同一用户请求跨版本造成不可解释波动。回滚指针应能恢复 sparse 基线或旧 hybrid；索引和模型旧版本保留到回滚窗口结束。若发现 ACL 泄漏，立即停用受影响路径并清理缓存/日志，不能只把流量比例降到 1%。

### 16.9 质量与可靠性的双门禁

候选系统可同时满足：离线质量门禁、延迟/错误率门禁、安全门禁和新鲜度门禁。任何一项失败都不能被另一项平均抵消。

例如 nDCG 提升但 dense 5% 超时，若降级结果仍可接受，可定义总体 SLO；若超时导致无证据生成，则直接失败。门禁要在实验前定义，不能看完结果再降低标准。

## 17. 常见故障诊断

### 17.1 直接相加不可比分数

首个证据是对任一路做正比例缩放后排名变化，而来源内部名次没变。修复可从 RRF 基线开始；若用学习融合，必须补校准与独立验证。

### 17.2 去重后权限扩大

症状：同内容不同租户合并后，一个用户看到另一租户 ID。检查去重键和 ACL 合并逻辑。权限集合通常取当前请求明确允许的实体，不做“内容相同所以权限并集”。这是安全事故路径。

### 17.3 重排新增候选

检查输出 ID 是否为输入子集。模型返回文本而非 ID 时，解析/映射可能错配；应用应使用版本化 schema 并拒绝未知 ID。

### 17.4 只报告最好查询

核对冻结 query ID 数和逐查询文件。缺失、超时或空结果必须保留为失败，不能在 DataFrame 聚合前被 `dropna` 删除。

### 17.5 重排深度导致超时

按 M 分组查看质量—延迟曲线和截断。先回退到安全融合序，再调整深度/批次；不要无上限重试模型调用。

### 17.6 dense 降级被标成 hybrid 成功

查看 per-source status 和响应模式。降级结果要有明确状态，评估时不能混入正常 hybrid 组。

### 17.7 缓存跨权限复用

检查 cache key 是否包含租户/授权版本和索引版本，缓存值是否带可见性。发现泄漏时先停用/清理缓存与相关日志，再修复并回归。

## 18. Python 检索层与 Java 业务层

Python 可以拥有：Embedding 调用适配、索引摄取、BM25/向量候选、RRF、重排、离线评估和派生指标。它们都可从 Java 事件/快照与文档来源重建。

Java 必须继续拥有：身份、租户、设备/工单事实、12 状态状态机、业务事务、ACL 最终决策和审计。Python 不能因为重排器判断“应紧急关闭”就改变工单，也不能把索引里过期的状态当当前授权。

一个安全接口可让 Java 返回已授权来源范围或在检索后对候选重新鉴权，但必须避免未授权正文已进入 Python/模型。具体拓扑要根据数据规模选，边界不变。

## 19. 可执行资产的证据边界

`examples/encyclopedia/ch.ir.hybrid-rerank/` 手算两路 RRF、provenance、并列和 ACL。`labs/...` 用 pandas 输出四组逐查询消融与受控预算标签。公开练习展示 raw score 相加的尺度错误；私有解答改用 RRF。

三类应绿脚本证明：

- RRF 算式和名次来源可复算；
- 分值正比例缩放不改变结果；
- 候选并集与稳定去重；
- 未授权候选不会在融合或重排重现；
- 四组使用同一夹具，聚合改善断言成立；
- 延迟字段不会冒充墙钟测量。

它们没有验证：真实 BM25、PostgreSQL/pgvector、Embedding、重排模型、并发、生产延迟、真实质量或真实权限服务。完成 T4 仍需真实服务证据。

## 20. 真实上线前的验证矩阵

| 层次 | 成功 | 边界 | 失败 |
| --- | --- | --- | --- |
| sparse | 型号/术语命中 | 零词项/长查询 | 索引陈旧 |
| dense | 同义表达命中 | 零向量/过滤后不足 | API/空间错误 |
| fusion | 双路互补 | 单路为空/并列 | 重复 ID/NaN |
| rerank | top-M 改善 | 部分候选/截断 | 超时/未知 ID |
| security | 当前租户可见 | 权限刚变更 | 无权限最高分 |
| evaluation | 冻结集可复现 | 未判断候选 | query 哈希漂移 |
| operations | 预算内 | 单路降级 | 双路失败/取消 |

每一格都要有输入、命令、日志和 oracle。成功路径绿而失败路径未测，不能称为完整验证。

## 21. 版本与当前资料

核对日期：**2026-07-24**。本章真实服务目标沿用 PostgreSQL **18.4** 与 pgvector **0.8.2**，数据报告资产使用 CPython 3.14 与 pandas **3.0.5**。本轮没有启动 PostgreSQL 或真实重排服务，所以目标版本不等于已运行版本。

官方一手资料：

- [PostgreSQL 18.4 官方文档](https://www.postgresql.org/docs/18/)
- [pgvector 0.8.2 官方 README](https://github.com/pgvector/pgvector/blob/v0.8.2/README.md)
- [pgvector 官方 CHANGELOG](https://github.com/pgvector/pgvector/blob/master/CHANGELOG.md)
- [pandas 3.0.5（PyPI）](https://pypi.org/project/pandas/3.0.5/)

RRF 公式是稳定核心；服务安装、索引参数和 planner 行为是版本面。使用某个框架自带 hybrid retriever 时，也要查该版本官方文档，确认去重、分值方向、并列、ACL 和失败策略，而不是只看类名含 `Hybrid`。

## 22. 学习实验顺序

1. 手算 A/B/C/D 的 RRF 并预测排序；
2. 将 dense 原始分值乘 100，预测 raw-sum 与 RRF 各自变化；
3. 在最高排名放入无权限 X，确认它在哪一步被排除；
4. 把 rerank depth 从 3 改成 1，解释质量可能怎样变化；
5. 故意让重排器返回未知 ID，写出失败合同；
6. 为四组结果保存逐查询排名，不只保存均值；
7. 列出受控夹具与真实服务之间缺少的证据；
8. 用 120 秒解释为什么混合提升不能靠一条成功查询证明。

## 23. 章末检查

你应能回答：

- BM25 与余弦分值为什么不能直接相加？
- RRF 对什么变换不敏感，又丢失了什么信息？
- 候选深度和重排深度如何影响召回与延迟？
- 重排器输出必须满足哪几个集合不变量？
- 去重为什么可能演变成权限漏洞？
- 四组消融必须固定哪些输入？
- 预算夹具为什么不能称为生产 p95？
- Python 与 Java 在 FactoryCare 中各自拥有什么？

本章完成的不是“接一个 rerank API”，而是一份可证明的候选合同：两路来源、授权范围、并集/去重、RRF 分量、重排输入输出、逐查询消融、延迟/失败政策和真实未验证项。只有这层稳定，后续生成与引用评估才有可信上下文。
