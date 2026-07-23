---
schema_version: 2
edition: 2026.2-draft
id: ch.ir.dense-pgvector
title: 向量检索、pgvector、索引与距离
responsibility: 在 PostgreSQL/pgvector 中持久化版本化向量并比较精确与近似检索、距离度量和索引计划，不混合不同 Embedding 空间。
volume: '14'
order: 10
level: L3
status: drafting
path: book/volume-14-llm-rag-agents/chapters/ch.ir.dense-pgvector.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.rag.chunking-embeddings
- ch.data.indexes-explain
version_surfaces:
- python-3.14
- postgresql-18
- pgvector
- docker
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
  text: 在 120 秒内解释“向量检索、pgvector、索引与距离”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - ir-vector-distance
  - ir-pgvector-index
  covers_topics:
  - ir.cosine-distance
  - ir.inner-product
  - ir.euclidean-distance
  - ir.distance-normalization
  - ir.pgvector-column
  - ir.vector-index
  - ir.approximate-recall
  - ir.explain-vector-plan
  uses_capabilities:
  - ai.llm-model-api
  - math.linear-calculus
  - data.relational-schema
  - data.index-plan
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“向量检索、pgvector、索引与距离”构建可运行程序与测试：在 PostgreSQL 18 + pgvector 建立带模型/维度约束的 chunk 向量表，比较精确扫描与近似索引的延迟和召回；独立保存可复现工件与判断结果
  covers_topic_groups:
  - ir-vector-distance
  - ir-pgvector-index
  covers_topics:
  - ir.cosine-distance
  - ir.inner-product
  - ir.euclidean-distance
  - ir.distance-normalization
  - ir.pgvector-column
  - ir.vector-index
  - ir.approximate-recall
  - ir.explain-vector-plan
  uses_capabilities:
  - ai.llm-model-api
  - math.linear-calculus
  - data.relational-schema
  - data.index-plan
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: postgres-container-exact-vs-ann-benchmark-explain-plan
- id: diagnose
  kind: fault-diagnosis
  text: 面对“混入不同维度/模型向量、距离操作符选错、只看延迟不测召回或查询计划未使用预期索引”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - ir-vector-distance
  - ir-pgvector-index
  covers_topics:
  - ir.cosine-distance
  - ir.inner-product
  - ir.euclidean-distance
  - ir.distance-normalization
  - ir.pgvector-column
  - ir.vector-index
  - ir.approximate-recall
  - ir.explain-vector-plan
  uses_capabilities:
  - ai.llm-model-api
  - math.linear-calculus
  - data.relational-schema
  - data.index-plan
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 向量检索、pgvector、索引与距离

> 向量检索把“查询与文档的接近程度”转换为距离排序，但距离只有在同一个 Embedding 空间内才有意义。本章建立 PostgreSQL/pgvector 的数据与验证合同：先用手算证明距离，再用精确搜索做 oracle，最后才评估近似索引。没有真实服务、真实 `EXPLAIN` 和逐查询 recall/延迟证据时，不能声称 pgvector 已验证。

## 1. 向量检索解决什么、不解决什么

词法检索要求共享词项；向量检索希望把语义相近的文本映射到相近向量，从而找回没有共享字面的候选。例如“轴承发出尖锐声”和“设备异响”可能被一个合适模型放得较近。

但向量不是事实数据库。它不能拥有：

- 工单当前状态和允许的状态迁移；
- 用户、租户、角色和 ACL 的最终判断；
- 设备主数据与维修事务；
- 审计记录的唯一来源。

FactoryCare 中这些仍由 Java 业务后端拥有。Embedding、chunk 和向量索引是可删除重建的派生投影。检索返回文档 ID 和证据，任何业务动作都必须回到 Java API 重新读取与鉴权。

向量检索也不自动证明相关。模型可能把表面相似但结论相反的文本放近；否定、时间、型号和权限仍需显式合同与评估。

## 2. Embedding 空间是一个版本化元组

“都是 1536 维”不代表可比较。一个空间至少由这些元数据定义：

```text
provider / model_id / model_revision
input preprocessing / tokenizer contract
dimensions / numeric type
normalization policy
task or instruction prefix
```

两个模型输出维度相同，也可能使用完全不同的坐标系。把它们放进同一索引计算余弦距离，就像把摄氏温度与华氏温度的裸数字直接平均：程序可以算，结果没有约定意义。

因此数据库和应用层都要使用明确 `space_id`。写入时验证模型、修订、维度与归一化；查询时只选一个空间。迁移模型的安全方式是建立新空间、重新嵌入、双读评估、切换版本，再按保留策略删除旧投影，而不是原地混写。

## 3. 先手算三种距离

令向量 `x=(x1,...,xn)`、`y=(y1,...,yn)`。

### 3.1 欧氏距离（L2）

```text
d_l2(x,y) = sqrt(Σ(x_i-y_i)^2)
```

`(1,0)` 与 `(0,1)` 的 L2 距离是 `sqrt(2)`。越小越近。缩放向量会改变距离，因此向量模长参与结果。

### 3.2 内积

```text
ip(x,y) = Σ x_i*y_i
```

通常越大越相似，但模长也会放大内积。pgvector 为了让 PostgreSQL 使用默认升序索引扫描，用 `<#>` 返回**负内积**；查询相似度时常写 `ORDER BY embedding <#> query ASC`，需要原始内积可再乘 `-1`。把 `<#>` 当正距离解释会把方向弄反。

### 3.3 余弦距离

```text
cosine_similarity = (x·y) / (||x|| ||y||)
cosine_distance = 1 - cosine_similarity
```

余弦关注方向，距离越小越近。零向量的范数为零，余弦无定义；应用应在写入或查询前拒绝，而不是让 NaN 混入排名。

对 `(1,0)` 与 `(1,1)`：内积为 1，范数为 `1` 与 `sqrt(2)`，余弦距离为 `1-1/sqrt(2)`。

## 4. 归一化改变指标关系

若所有向量都做 L2 单位归一化，即 `||x||=1`，则：

```text
||x-y||^2 = 2 - 2(x·y)
cosine_distance = 1 - x·y
```

在理想数学下，这三种排序存在单调关系。但浮点误差、模型实际归一化政策和零向量仍需验证。不能只因为模型文档“通常归一化”就在代码里假设。

归一化应属于 `space_id` 元数据。写入前归一化与查询时归一化必须一致。模型升级后若政策变化，就创建新空间。

选择指标应来自模型提供方说明和冻结评估，而不是“余弦最流行”。即使两种指标排名相同，索引 operator class 也必须与查询操作符匹配。

## 5. pgvector 的列与操作符

pgvector 为 PostgreSQL 提供 `vector`、`halfvec`、`bit`、`sparsevec` 等类型，并支持精确与近似最近邻。对本章固定三维夹具，列可声明：

```sql
embedding vector(3) NOT NULL
```

常用操作符按官方 README：

| 操作符 | 含义 | 排序方向 |
| --- | --- | --- |
| `<->` | L2 距离 | 小到大 |
| `<#>` | 负内积 | 小到大 |
| `<=>` | 余弦距离 | 小到大 |
| `<+>` | L1 距离 | 小到大 |

操作符不是可互换语法糖。索引用 `vector_cosine_ops`，查询却用 `<->`，规划器不能把它当作同一个距离合同；即使得到结果，含义也变了。

不要把相似度表达式包成任意算术后直接 `ORDER BY` 并期待索引。例如 `ORDER BY 1-(embedding <=> query) DESC` 与距离升序数学等价，但官方 pgvector README 明确说明要使用距离操作符结果、升序并带 `LIMIT`，规划器才有可用的索引排序形态。先按可索引形式取候选，再在外层展示相似度。

## 6. 一张不越权的检索投影表

实验 `schema.sql` 使用两个表。`embedding_space` 保存模型、修订、维度和归一化；`retrieval_chunk_embedding` 保存 chunk、空间、来源版本、ACL 投影版本与向量。

关键约束：

```sql
PRIMARY KEY (chunk_id, space_id)
embedding vector(3) NOT NULL
space_id REFERENCES embedding_space(space_id)
```

这是课程三维夹具，不是建议真实模型也用 3 维。真实维度变更通常意味着新表/分区/迁移方案或适当的数据模型。把可变维度全塞进无约束列会让错误更晚在查询时暴露。

表中只复制检索所需的来源标识与版本。它没有 Java 状态机方法，也没有“允许关闭工单”字段。ACL 投影版本用于检测新鲜度，最终授权仍由 Java 当前请求路径给出的允许 chunk 集合约束。

## 7. 安全查询形态

受控 SQL 合同：

```sql
SELECT chunk_id, embedding <=> $3::vector AS cosine_distance
FROM retrieval_chunk_embedding
WHERE space_id = $1
  AND chunk_id = ANY($2)
ORDER BY embedding <=> $3::vector ASC
LIMIT $4;
```

参数含义：`$1` 是唯一 Embedding 空间，`$2` 是 Java 授权路径产生的允许 chunk ID，`$3` 是同空间查询向量，`$4` 是上限。

真实大规模系统不一定适合传巨大 ID 数组，可能采用带租户/可见性字段的可信过滤、临时表、连接或分区策略。但原则不变：权限必须在候选可见之前生效，且由当前权威数据决定。

“先 ANN 取全库 top-100，再在 Python 去掉无权限项”不仅可能返回不足，还让未授权对象进入中间结果、日志或缓存。安全与召回要一起设计。

## 8. 精确搜索是近似搜索的 oracle

没有近似索引时，数据库可计算每个合格向量的距离并排序，得到精确 top-k。它可能慢，但在冻结小数据上提供基准。

近似最近邻（ANN）用速度、内存和构建代价换取可能的候选遗漏。因此任何“ANN 更快”报告必须同时回答：相对精确 top-k，它找回了多少？

定义：

```text
recall@k = |exact_top_k ∩ ann_top_k| / k
```

这里衡量 ANN 对精确距离排名的近似召回，不是上一章对人工相关标签的语义 Recall。两个概念都叫 recall，分母不同，报告中应命名为 `ann_recall_at_k` 或明确说明。

每条查询都要保存 exact 与 ANN 文档 ID；只保存平均 recall 无法诊断特定查询。若精确路径与近似路径使用不同 ACL、空间、距离或数据快照，比较没有意义。

## 9. HNSW 与 IVFFlat 的工程差异

pgvector 官方文档提供 HNSW 和 IVFFlat 两类近似索引。

HNSW 构建多层图，通常提供较好的查询性能/召回权衡，但构建更慢、内存占用更高。查询参数如 `hnsw.ef_search` 控制动态候选规模；提高通常增加召回和代价。

IVFFlat 把向量分到多个列表，查询访问部分列表。它构建更快、内存更少，但需要在已有足够数据后选择 `lists`，并用 `ivfflat.probes` 调整速度/召回。提高 probes 通常提高 recall 并增加代价。

这些是算法与当前官方实现的方向性合同，不是本项目真实测量。最佳参数依赖数据量、分布、过滤、硬件和延迟目标，必须用冻结查询与真实服务实验。

一个余弦 HNSW 索引例：

```sql
CREATE INDEX ... USING hnsw (embedding vector_cosine_ops);
```

若要同时支持 L2，需要相应 operator class 的另一个索引。索引占用写入、磁盘和维护成本，不能“全部都建”而不评估。

## 10. `EXPLAIN` 证明的是计划，不是意图

PostgreSQL 为每条 SQL 选择计划。使用：

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) SELECT ...;
```

可以看到实际执行、缓冲区和计划节点。JSON 便于保存与机器检查。但 `EXPLAIN ANALYZE` 会真正执行语句；对写操作或高成本查询必须谨慎。本章只讨论 SELECT。

不要只搜索输出中是否含 `Index Scan`。需要同时核对：

- 使用哪个索引与 operator class；
- 过滤条件在哪里执行，过滤掉多少行；
- 估计行数与实际行数差距；
- 排序、LIMIT 和扫描方向；
- planning/execution 时间与缓存状态；
- 相同查询多次运行的分布，而非单次最好值。

小表选择顺序扫描可能是规划器的合理决定，不自动代表索引坏了。PostgreSQL 官方文档建议先 `ANALYZE` 并用真实工作负载检查索引使用。为了截图强制关闭 seqscan，只能作为诊断，不应冒充正常计划。

## 11. 真实基准的最小协议

一次可复现 T4 实验至少需要：

1. 固定 PostgreSQL、pgvector 和容器镜像摘要；
2. 保存 `SELECT version()` 与扩展 `extversion`；
3. 固定数据快照、空间、查询向量、ACL 集和 `k`；
4. 建表、加载数据、`ANALYZE`，记录索引构建时间与大小；
5. 对每条查询执行精确路径并保存 top-k；
6. 对每组 ANN 参数执行近似路径，保存 top-k 与真实计划；
7. 同时报 `ann_recall@k` 与延迟分布；
8. 区分冷/热缓存、并发度和硬件；
9. 保存失败、超时与返回不足，不删除坏样本；
10. 在相同权限和空间过滤下比较。

pgvector 官方 README 展示可在事务内 `SET LOCAL enable_indexscan = off` 获得精确比较路径，以及用 ANN 参数调节召回。具体做法需在目标版本验证，不能从教程截图推断当前服务。

## 12. 为什么单次延迟没有意义

第一次查询可能加载页面和索引，后续命中缓存；后台 VACUUM、并发、容器 CPU 限制和网络都影响时间。至少报告 p50/p95 等分布、样本数、预热政策与失败率。

更快但 `ann_recall@10` 从 0.98 降到 0.55，不是无条件优化。反过来，recall=1 但延迟超过请求预算，也不能上线。通过阈值应在实验前定义，例如质量下限、p95 上限、内存上限和安全零泄漏。

课程受控夹具故意让 ANN 候选漏掉一个精确 top-3，得到 `2/3`。它只验证 recall 算式和报告字段，**不是 HNSW 的实测 recall**。

## 13. 过滤与 ANN 的交互

向量索引先产生候选后再应用普通过滤时，可能因为很多候选被过滤而返回不足。pgvector 的当前官方文档讨论 iterative index scans 等机制来扩大搜索，HNSW/IVFFlat 也有各自参数。

处理方式可能包括：

- 提高搜索候选参数；
- 使用迭代扫描；
- 部分索引或分区；
- 先按高选择性业务维度缩小空间；
- 过取候选后重排，但仍要保证权限不会泄漏；
- 对不同过滤切片单独测 recall 与延迟。

没有一个参数能自动解决所有过滤。租户大小和 ACL 选择性应成为基准切片。

## 14. 写入、更新与删除的一致性

Embedding 生成是异步派生流程，常见状态：来源已更新、旧向量仍在；来源已删除、索引残留；模型新旧空间并存；部分 batch 失败。

安全流程应保存：

- 来源版本与内容哈希；
- space ID 与生成时间；
- 幂等写入键；
- 摄取水位、失败队列和重试次数；
- 删除墓碑或可靠变更事件；
- 切换前后的数量与冻结查询回归。

不要用向量表的存在判断业务对象还有效。返回候选后，Java 仍可拒绝已删除、无权限或状态不允许的对象。

## 15. 故障诊断

### 15.1 不同模型同维混入

症状可能只是排名怪异，SQL 不一定报错。首个证据是同一查询结果中出现多个 `space_id`，或写入合同没有检查空间。修复后重建污染索引，不能只阻止未来写入。

### 15.2 维度不一致

固定 `vector(n)` 通常能在数据库边界尽早拒绝。若使用动态维度，必须在空间元数据和写入代码中验证，并为索引设计表达式/过滤。首个证据是 schema 与输入元数据，而不是模型回答。

### 15.3 操作符选错

检查模型预期指标、SQL 操作符、索引 operator class 和排序方向四者。构造正交、相同方向不同模长的手算向量，可快速区分指标行为。

### 15.4 ANN 很快但结果差

查看逐查询 exact/ANN 集合与 recall，而不是平均延迟。调大候选参数并记录曲线；若只剩“更快”日志，证据不完整。

### 15.5 计划没有用索引

先确认 `ORDER BY distance_operator ASC LIMIT`、operator class、数据量、`ANALYZE` 和过滤选择性。小表 seq scan 可能合理。保存真实 JSON 计划，不凭 IDE 中存在索引定义推断执行。

### 15.6 返回了无权限候选

这是安全失败，不是把分数调低能修复。定位授权集合从 Java 到 SQL 的传递、缓存键和过滤阶段；增加“最高相似候选恰好无权限”的回归例，并轮换/清理可能泄漏的日志与缓存。

## 15A. 数值、存储与数据质量

Embedding 常以浮点数组返回。进入数据库前应验证：长度、所有元素有限、没有 NaN/Infinity、零向量政策、数值类型和空间元数据。只验证 JSON 是数组不够；一个 NaN 可以让距离与排序行为不可依赖。

`vector` 使用单精度元素，`halfvec` 使用半精度以降低存储和索引占用，`bit` 可用于量化路线。精度/容量选择会改变 recall 和重排需求，必须用 exact oracle 做消融，不能只按磁盘更小决定。

容量估算至少包含：行数、维度、每元素字节、行/索引开销、HNSW/IVFFlat 索引、WAL、备份、旧空间双写和副本。模型迁移期间常同时保留两套向量，容量峰值可能接近平时两倍以上；发布计划必须留余量。

来源文本也要有最大长度和截断证据。Embedding API 成功不代表完整文档被编码；chunk 版本应记录截断/切块配置和内容哈希。

## 15B. 并发摄取与幂等写入

摄取任务可能重复、乱序和部分失败。推荐以 `(chunk_id, space_id)` 作为幂等键，并比较 `source_version`：相同版本重复事件不产生多行；更旧事件不得覆盖新向量；删除事件要能清理所有空间的派生行。

批量生成时，先把 API 结果与输入 chunk ID 对齐。模型 API 若少返回一项，按数组位置盲写会把后续向量错配给错误文档，这是比维度错误更隐蔽的事故。每项应携带稳定关联 ID，批次结束核对输入/成功/失败数量。

数据库事务只保证事务内 SQL 原子性，不能自动把外部 Embedding API 与 PostgreSQL 变成分布式事务。常见做法是 outbox/任务状态 + 幂等 upsert + 可重试失败队列。重试必须区分永久输入错误和临时提供方错误。

## 15C. 模型空间迁移状态机

一次可回滚迁移可定义：

```text
REGISTERED -> BACKFILLING -> VALIDATING -> READY -> ACTIVE -> RETIRED
```

`REGISTERED` 只登记元数据；`BACKFILLING` 写新空间；`VALIDATING` 做数量、维度、抽样距离与冻结查询；`READY` 表示可灰度；`ACTIVE` 才进入默认查询；`RETIRED` 停止读但暂留回滚。

状态机属于检索运维元数据，不取代 Java 工单状态机。切换指针应原子化并记录操作者、版本和时间。验证失败保持旧 ACTIVE，清理新空间；不能在半数 backfill 时让查询随机混用两空间。

## 15D. 计划与性能回归的可信比较

真实 `EXPLAIN ANALYZE` 比较要控制数据、参数和缓存。至少保存：SQL 文本哈希、绑定参数类别、`ANALYZE` 时间、计划 JSON、返回行数、索引大小和服务器设置。查询向量本身可敏感，证据中可保存不可逆哈希与受控 fixture ID。

计划变化不必然是退化，执行时间变化也不必然来自计划。先区分：数据分布/统计变化、PostgreSQL/pgvector 升级、参数变化、缓存与硬件噪声。用多次测量和逐查询对比，不用一次截图归因。

升级扩展前在影子/预发布环境重建或复用索引要遵循官方升级说明。保存 `ALTER EXTENSION vector UPDATE` 前后版本和回滚/备份策略；不要假设扩展降级总是可逆。

## 15E. 真实 T4 的失败注入

除了成功查询，还应主动验证：写入错误维度/空间；查询操作符与索引不匹配；ANN 参数过低；过滤后结果不足；删除来源后索引残留；扩展不可用；数据库超时/取消；Java 授权集合为空；无权限向量最接近查询。

每个故障记录失败阶段与首个证据。例如错误维度应在写入 schema 失败，而不是等到检索；空授权集合应在执行向量检索前快速返回空，不允许省略 `ANY($2)` 变成全库查询。

只有这些真实失败路径跑过，才能把受控 SQL 合同升级为服务验证。当前资产没有跑，因此明确列入未验证，而不是留给读者从 PASS 猜测。

## 16. 资产中的受控夹具

`examples/encyclopedia/ch.ir.dense-pgvector/` 用标准库手算三种距离和精确余弦排名。`labs/encyclopedia/ch.ir.dense-pgvector/` 包含参考 `schema.sql`、固定向量和一个故意漏候选的 ANN 夹具。

实验的 `service_evidence.json` 明确：

```json
"real_service_verified": false
```

验证脚本检查 SQL 合同文字、空间与 ACL 过滤、精确排名和 `ann_recall@3`。它没有启动 Docker、执行 SQL、创建扩展或采集真实计划。输出特意写 `CONTROLLED FIXTURE ONLY`，防止绿色被误读为 T4 完成。

公开练习保留“只比维度、不比模型空间”的错误，应稳定红；私有解答在内存合同中同时拒绝空间和维度不兼容。即便私有解答通过，也不等同于数据库约束已运行。

## 17. 真正启动服务时应补什么

后续有数据库环境后，建议新建独立实验目录而不是覆盖受控证据：

```text
evidence/
  environment.txt
  image-digest.txt
  schema-run.log
  extension-version.txt
  exact-rankings.jsonl
  ann-rankings.jsonl
  recall-report.csv
  plans/*.json
  latency-summary.json
```

环境文件记录 CPU、内存、磁盘、容器限制和时间。命令必须可重跑；密钥不能进入日志。若实际版本与目标不符，标记未验证并停止比较，不要手改报告标题。

## 18. 当前官方版本面

核对日期：**2026-07-24**。

- PostgreSQL 官方 current 文档显示稳定主线为 **18**，当前文档标题为 **PostgreSQL 18.4**；19 仍是开发版本，不作为本章生产基线。
- pgvector 官方仓库 `CHANGELOG.md` 与 README 显示当前版本为 **0.8.2**，并列出 PostgreSQL 18 的官方镜像标签。
- 官方 pgvector README 说明精确/近似搜索、HNSW/IVFFlat、距离操作符、索引查询形态和用精确结果监控 recall。

一手资料：

- [PostgreSQL 18.4 官方文档](https://www.postgresql.org/docs/18/)
- [PostgreSQL 官方 EXPLAIN](https://www.postgresql.org/docs/18/sql-explain.html)
- [PostgreSQL 官方检查索引使用](https://www.postgresql.org/docs/18/indexes-examine.html)
- [pgvector 0.8.2 官方 README](https://github.com/pgvector/pgvector/blob/v0.8.2/README.md)
- [pgvector 官方 CHANGELOG](https://github.com/pgvector/pgvector/blob/master/CHANGELOG.md)

实验目标写 PostgreSQL 18.4/pgvector 0.8.2，但本轮没有拉取镜像或运行服务，所以这些只是**官方版本基线**，不是本机安装验证。即使使用 `0.8.2-pg18` 标签，也应记录镜像摘要和容器内 `SELECT version()`，因为标签不是不可变证据。

## 19. 学习实验顺序

1. 先手算 `(1,0)`、`(0,1)`、`(1,1)` 的三种距离；
2. 预测归一化后 L2、内积与余弦排序关系；
3. 运行 example，故意加入零向量并解释失败；
4. 在内存 store 混入同维不同模型，观察为什么维度检查不够；
5. 阅读 `schema.sql`，逐项指出空间、来源、ACL 和距离合同；
6. 用精确 top-3 与漏一项候选手算 `ann_recall@3`；
7. 写出真实服务尚缺的七类证据；
8. 用 120 秒解释为什么“EXPLAIN 有 Index Scan”仍不等于生产检索合格。

## 20. 章末检查

你应能回答：

- 同维向量为什么仍可能不可比较？
- `<#>` 为什么表示负内积，排序方向是什么？
- 精确搜索与人工相关性标签分别充当什么 oracle？
- `ann_recall@k` 与语义 `Recall@k` 的分母有何不同？
- 小表使用 seq scan 是否必然是错误？
- 只报告 ANN 延迟为什么不完整？
- 为什么 ACL 必须在候选可见前强制执行？
- 哪些资产已实际运行，哪些必须等真实 PostgreSQL 服务？

合格证据不是一张“向量数据库已连接”截图，而是空间合同、距离手算、schema 约束、精确排名、近似逐查询排名、recall/延迟权衡、真实计划、版本记录和明确未验证项。下一章会在相同冻结评估集上融合稀疏与稠密候选。
