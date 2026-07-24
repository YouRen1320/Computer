---
schema_version: 2
edition: 2026.2-draft
id: ch.rag.chunking-embeddings
title: 分块、Embedding、批处理与语料管线
responsibility: 根据文档结构和检索目标生成可追溯 chunk，批量计算 Embedding 并处理维度、重试和版本，不选择检索索引。
volume: '14'
order: 7
level: L3
status: drafting
path: book/volume-14-llm-rag-agents/chapters/ch.rag.chunking-embeddings.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.rag.ingestion-metadata
version_surfaces:
- python-3.14
- model-api
- numpy
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
  text: 在 120 秒内解释“分块、Embedding、批处理与语料管线”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - rag-chunking
  - rag-embedding-pipeline
  covers_topics:
  - rag.chunk-boundary
  - rag.chunk-overlap
  - rag.chunk-parent-link
  - rag.chunk-version
  - rag.embedding-model-id
  - rag.embedding-dimension
  - rag.embedding-batch
  - rag.embedding-retry-resume
  uses_capabilities:
  - ai.llm-model-api
  - math.linear-calculus
  - data.numpy-pandas
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 对结构化维修手册生成可配置 chunk，批量嵌入并保存模型 ID、维度、父文档、ACL、成本和断点续跑状态；独立保存可复现工件与判断结果
  covers_topic_groups:
  - rag-chunking
  - rag-embedding-pipeline
  covers_topics:
  - rag.chunk-boundary
  - rag.chunk-overlap
  - rag.chunk-parent-link
  - rag.chunk-version
  - rag.embedding-model-id
  - rag.embedding-dimension
  - rag.embedding-batch
  - rag.embedding-retry-resume
  uses_capabilities:
  - ai.llm-model-api
  - math.linear-calculus
  - data.numpy-pandas
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: chunk-golden-tests-embedding-mock-resume-idempotency-test
- id: diagnose
  kind: fault-diagnosis
  text: 面对“按固定字符截断标题语义、chunk 丢失 ACL、混用不同维度模型或重试重复计费无断点”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - rag-chunking
  - rag-embedding-pipeline
  covers_topics:
  - rag.chunk-boundary
  - rag.chunk-overlap
  - rag.chunk-parent-link
  - rag.chunk-version
  - rag.embedding-model-id
  - rag.embedding-dimension
  - rag.embedding-batch
  - rag.embedding-retry-resume
  uses_capabilities:
  - ai.llm-model-api
  - math.linear-calculus
  - data.numpy-pandas
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 分块、Embedding、批处理与语料管线

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《文档解析、清洗、权限元数据与可追溯性》](ch.rag.ingestion-metadata.md)：chunk 必须继承已验证的来源、版本、哈希和权限元数据。
<!-- END GENERATED LEARNING PREREQUISITES -->

规范文档通常太长，无法把整本手册作为每次检索的最小单位。分块把文档转成可检索chunk；Embedding把chunk映射为向量；批处理管线以可恢复、幂等方式完成大量转换。困难不在调用一个API，而在保持语义边界、父文档、ACL、模型版本、维度和处理状态始终一致。

本章不选择全文/向量索引，不评价召回效果。Embedding调用使用Mock或当前官方模型API时必须明确区分；本地模拟向量不能冒充供应商语义质量。

## 1. chunk是什么

chunk是规范文档的一个有边界、可追溯片段。最小字段包括chunk_id、parent_document_id、parent_hash、chunk_version、ordinal、text、位置范围、标题路径、ACL、source URI/version和内容hash。它不是一段失去上下文的裸字符串。

### 1.1 为什么分块

整篇检索粒度太粗、上下文昂贵；逐句太细则丢上下文。chunk在“可独立回答”与“足够精确检索”之间折中。没有全局最佳长度，需结合文档结构、问题类型、Embedding与生成上下文评估。

### 1.2 父子关系

每个chunk必须能回到规范父文档和位置。父撤回/ACL变化能找到全部子项；回答引用能打开原文；解析器升级能判断哪些chunk失效。父hash防止chunk挂到已变化内容。

## 2. 边界策略

优先使用语义结构：文档→章节→小节→段落→句子，再在过长单元内按token预算细分。Markdown标题、PDF页/块、表格和代码块提供边界。不要先按固定字符数从任意位置切。

### 2.1 标题路径

chunk正文可带短标题路径，如“泵站手册 > 告警 > E42”，或存独立metadata并在嵌入文本中按策略加入。标题改善脱离父文档后的语义，但重复过长标题增加token和相似度偏置。

### 2.2 句子/段落

段落常是自然最小单元。过长段落再按句子聚合到预算。中文句号、代码、缩写和列表使正则句切并不完美；使用黄金文档审查。

### 2.3 代码和表格

代码块不在任意行截断，保留语言和函数/类边界；表格保留表头与行关系，必要时按行组切并重复表头。只保留单元格值会失去列语义。

## 3. 长度用什么单位

字符数便于离线粗分，不等于Embedding模型token数。模型API有输入上限，应使用对应Tokenizer或实际usage验证。管线可设软目标和硬上限：先按结构组装，超硬限再细分。

### 3.1 最小/目标/最大

过短相邻片段可合并到目标；达到目标后在自然边界结束；任何chunk不超最大。不要为满足最小长度跨越权限或文档边界。空标题/空段落过滤但保留位置映射。

### 3.2 预算包含元数据

若Embedding文本拼入标题、来源或字段名，这些也计token。保存最终送入Embedding的canonical input hash，才能复算/去重。

## 4. overlap

重叠在相邻chunk重复一部分上下文，减少答案跨边界被割裂。固定token overlap简单，但增加存储、调用成本和重复召回。结构分块可按标题/上一句提供上下文，未必需要大重叠。

### 4.1 overlap副作用

同一句在多个chunk出现，检索top-k可能全是重复内容，浪费上下文。需要去重/父文档多样性。指标中区分独立证据覆盖与重复命中。

### 4.2 不能跨边界

绝不跨文档、租户或ACL做重叠。若同文档内部段落ACL不同，也不能复制受限文字到低权限chunk。权限边界高于语义连续。

## 5. chunk ID与版本

chunk ID应对相同父版本和同一分块配置稳定。可由父document ID、parent hash、chunker version、ordinal/位置生成。仅用文本hash会让相同句子跨来源合并、丢授权和引用。

### 5.1 位置型与内容型

位置型ID在前文插入后大量变化；内容型更稳定但重复文本冲突。可用父ID+结构路径+内容hash组合，并保持ordinal。选择写入合同。

### 5.2 chunker升级

改变大小、overlap、Tokenizer或标题策略都产生新chunk_version。新旧索引版本隔离，验证后原子切换；不要混用而无字段区分。

## 6. ACL继承

每个chunk继承父ACL、tenant、classification和acl_version。若片段有更严格规则，取交集/更严格策略，绝不放宽。ACL应是结构化metadata，不靠正文提示。

测试遍历所有chunk：父ID存在；tenant相同；ACL等于或更严格；无空ACL；父撤回能定位。查询过滤在内容进入模型前执行。

## 7. Embedding

Embedding模型把文本映射为固定维向量。向量维度由模型/配置决定；同模型版本下所有记录应一致。向量用于相似度检索，不包含可读引用和权限，metadata必须另存且原子关联。

### 7.1 model ID

保存供应商、模型精确ID/快照、维度、输入预处理、API/SDK版本和时间。模糊写`embedding-latest`无法重建。别把不同模型空间向量混在同一索引比较。

### 7.2 维度

调用第一批后验证shape `[batch,dimension]`、行数与输入一致、所有值有限。索引模式锁定维度。若API允许选择输出维度，该配置也属于版本。

### 7.3 归一化

有些向量已归一化，有些没有。余弦、点积与欧氏距离关系依赖范数。记录是否归一化，不要重复/漏做而不知。用小向量手算验证检索阶段。

## 8. canonical embedding input

明确送模型的文本格式，例如：

```text
title_path: 泵站手册 > E42
content: ...
```

字段顺序、分隔符、Unicode和空白固定，计算embedding_input_hash。改变模板即新embedding pipeline version，即使chunk text未变也要重嵌入。

不要把ACL成员、内部路径或秘密拼进文本向量；它们是过滤metadata。必要的公开标题可加入，但来源/权限仍独立保存。

## 9. 批处理

API常支持多输入batch。批量减少请求开销，但受单请求token、条数、字节和服务限制。组批既控制item count也控制总token。超长单项先在chunk阶段拒绝/细分。

### 9.1 顺序映射

响应向量必须按稳定索引映射回chunk ID。即使API声明保序，也验证返回count和index；异步并发更不能按完成顺序拼。每个request保存chunk IDs和input hashes。

### 9.2 大小权衡

太小吞吐低，太大失败重试成本高、内存大。通过目标环境测量，不凭经验。限流按token/请求/并发可能不同；读取响应headers/官方策略。

## 10. 重试

网络超时、429和部分5xx可能重试；4xx模式/超长通常永久失败。重试使用指数退避、抖动、上限和供应商建议。不要无限快速重试扩大故障。

### 10.1 不确定结果

请求超时可能服务端已计算。Embedding本身无外部业务副作用，但会重复计费。用input hash缓存/检查点避免再次调用；写入用chunk+model+input hash幂等键。

### 10.2 批次拆分

批次有一项坏输入时，先记录原失败，再二分/逐项定位，而非丢整批。隔离坏chunk，其他继续。拆分策略防指数重复调用。

## 11. 检查点与续跑

manifest每行记录chunk ID、input hash、model ID、dimension、status、attempt、request ID、vector hash/位置、error和timestamps。启动时跳过同版本success，重试retryable，隔离permanent/conflict。

检查点写入与向量存储要有一致性协议。先写向量后标success，中断可能孤儿；先标success后写向量会缺失。可用事务、暂存+提交或对账修复。

### 11.1 状态机

`pending -> in_flight -> succeeded | retryable | quarantined`。恢复时过期in_flight回到可核查状态。非法反向状态被拒绝。状态事实属于派生管线，不修改Java工单状态。

## 12. 成本记录

保存每批输入token/条数、请求次数、重试和供应商usage/费用版本。预算预测用真实样本分布。重复命中缓存不应计新API调用，检查点能证明。

价格会变，不能在稳定教材硬编码永久数字。引用官方当前价格和日期，实际账单为最终证据。Mock实验只统计“模拟调用次数”。

## 13. 删除与更新

父文档新版本产生新chunk/Embedding版本；发布新索引后旧派生物按保留策略删除。ACL单独变化至少更新chunk metadata和查询过滤，即使向量无需重算。

父撤回沿parent ID删除/墓碑所有chunk和向量。仅按文本hash删除可能误伤其他授权来源。删除完成运行反查。

## 14. 质量验证

### 14.1 黄金边界

选手册含标题、长段、列表、表格、代码和跨边界答案。断言chunk顺序、文本、标题路径、位置、parent、ACL和hash。策略改变需审查diff。

### 14.2 覆盖

除明确过滤空白外，父规范文本的语义单元都被一个或多个chunk覆盖；无凭空文字；重叠只发生声明区域。可用位置区间检查空洞/非法跨越。

### 14.3 Embedding Mock

Mock按input hash稳定返回固定维向量，支持指定批次失败和调用计数。验证组批、映射、dimension、重试、续跑和幂等，不声称语义效果。

### 14.4 真实smoke

若获授权，少量非敏感夹具调用真实API，记录模型快照、维度、usage和响应。无凭据/网络则标未验证，不能用Mock绿替代。

## 15. 失败诊断

### 15.1 标题被切断

固定字符切使标题在chunk尾、正文在下一块。首证据是黄金边界diff和下一块无title_path。修复结构优先分块，再对过长节点token细分。

### 15.2 ACL丢失

chunk表acl为空或默认公开。阻断发布，从父记录原子继承，扫描现存记录，下游索引重建。不能只在生成后过滤。

### 15.3 维度混用

索引写入报维度或检索异常。比较每条model ID/dimension/pipeline version，隔离混合批。新模型建新命名空间并全量重嵌入验证。

### 15.4 重试重复计费

任务中断后从头调用。检查manifest success未被读取或input hash不稳定。修复canonical input、幂等键和原子检查点；故障注入中断，第二次只调用未完成项。

### 15.5 返回顺序错

并发批次按完成顺序zip原清单，向量挂错chunk。以request item ID/index关联并断言count，黄金向量能发现。挂错的已发布索引全部不可相信，需重建。

## 16. FactoryCare示例

规范文档`manual:pump:v7`按H2/H3和段落组装，目标约400真实模型token，最大600，overlap一条边界句。每chunk保存parent hash、标题路径、页/段位置、tenant/role ACL、chunker v2。

Embedding输入只含标题路径和正文。manifest键为chunk ID+embedding model snapshot+input hash。Mock本地验证维度8；真实接入后必须以官方模型实际维度重跑，不把8写成生产值。失败批可续跑，父撤回能删除全部。

## 17. 管线清单

1. 冻结published规范文档版本；
2. 验证ACL/父hash；
3. 结构分块和硬token上限；
4. 生成稳定ID、位置和canonical input；
5. 写pending manifest；
6. 按条数+token组批；
7. 调用Mock/授权API；
8. 验证count/index/dimension/finite；
9. 幂等写向量并标success；
10. 对账、隔离、发布版本；
11. 保存成本/未验证边界；
12. 演练中断续跑和删除。

## 18. 用问题集选择分块策略

分块不能只看平均长度。先建立代表性问题集，并标注回答所需的原文证据范围。对每个问题检查：证据是否完整落在至少一个chunk；是否混入大量无关段；引用能否回到原位置；跨边界问题是否需要父/邻居扩展；ACL是否允许所有组成证据。

例如问题“E42告警的原因和复位步骤”需要标题下两个相邻段。按句子切可能把原因/步骤分开；按整个大章节又混入E43/E44。结构分块可把E42小节整体保留，若超限再在列表边界细分并共享标题。

### 18.1 边界召回率

可以定义“标注证据是否被某个chunk完整覆盖”的比例，配合chunk token分布、重复率、文档数和ACL违规数。它不是最终检索指标，但能在Embedding之前发现结构失败。只优化chunk数量/平均长度会忽略语义。

### 18.2 多粒度

可同时建立小chunk用于精确召回、大父段用于生成扩展，但两者要有类型和父关系，检索/去重清楚。不能把不同粒度无标识混在top-k，导致结果全是同内容。父扩展仍重新做ACL与token预算。

### 18.3 邻居扩展

命中chunk后取前后邻居可恢复上下文。邻居必须同父版本、连续位置且ACL允许；不能只按全局ordinal取到另一文档。扩展结果去重并记录哪些是直接命中、哪些是邻居。

## 19. Embedding批次的完整数据合同

一个request manifest至少含request_id、pipeline_version、model_snapshot、dimension、canonical template version、每项chunk_id/input_hash/token_count、创建时间和attempt。响应记录provider request ID、item index、vector dimension、finite检查、usage和状态。

### 19.1 先核对数量再映射

请求10项响应9项，不能zip后静默少一条。先验证响应索引集合恰好等于请求；再逐项关联；重复索引、越界和缺失全部隔离整批或按合同恢复。保存原请求顺序，不依赖字典遍历偶然顺序。

### 19.2 有限值和范数

每个向量所有元素应为有限数，维度一致。统计零向量、范数异常和重复向量，可能暴露Mock、空文本或服务错误。范数阈值需按模型/归一化合同，不应跨模型复用。

### 19.3 空文本

规范/分块层应阻止空白chunk。若模型API接受空串并返回向量，也不代表有检索意义。记录过滤原因和父覆盖，不能静默减少chunk总数。

## 20. 幂等写与一致性对账

向量记录的自然唯一键可由`chunk_id + embedding_pipeline_version + input_hash`组成。相同键再次写返回已有结果；同chunk/version但input hash不同是冲突，说明canonical输入或版本管理错误，不能覆盖。

### 20.1 两阶段提交思路

先把向量写暂存并校验hash/维度，再在manifest标succeeded并发布索引引用。若中断，对账扫描：manifest success但向量缺失→回到retryable；向量存在但manifest in_flight→校验后补状态或清理；索引指向非success→阻断。

### 20.2 向量hash

序列化浮点后可计算完整性hash，但要固定dtype、字节序和格式。hash用于检测传输/存储变化，不证明向量语义。不同硬件/API若返回微小差异，是否视为同一由供应商确定性合同决定；通常应保存原响应而非重算比较逐位。

### 20.3 对账指标

预期chunk数、manifest各状态数、向量数、索引条目数按pipeline version相等；孤儿/缺失为零；维度集合只有一个；ACL/父链接完整。发布前自动对账，日常也巡检。

## 21. 限流、退避与背压

摄取速度可能远高于模型API配额。队列需要背压，限制并发和未确认批次，避免内存无限增长。按官方返回/文档识别请求和token限额；遇429尊重retry-after并加入抖动，多个worker不要同步重试。

### 21.1 动态批次不破坏复现

可以按token预算动态装箱，但manifest保存每个批次实际成员。批次大小改变不应改变每项canonical输入/向量（若服务确定性），只是性能。错误拆批后仍按chunk幂等键写。

### 21.2 熔断和暂停

持续认证失败、模式错误或维度变化不是继续重试的问题。达到阈值暂停pipeline、告警并保留队列。恢复前用单个canary非敏感输入验证模型ID/维度/权限，再逐步放量。

### 21.3 成本护栏

run开始按实际token样本估算上限，设置最大调用token/费用/重试数。超过则停止并等待审批。成本护栏不能通过截断正文静默满足；若改变chunk策略，生成新版本重新评估质量。

## 22. 模型升级迁移

新Embedding模型可能改变Tokenizer、输入上限、维度、相似度分布和费用。创建新embedding_pipeline_version和独立索引命名空间，全量或受控重嵌入，不把新向量写进旧空间。

### 22.1 双写/离线回放

用同一已授权chunk快照生成新旧向量，在固定查询集比较召回和延迟。双写若涉及真实API要计成本、权限和数据合同。验证通过后原子切查询版本，保留回滚期；撤权/删除同时作用两套。

### 22.2 不能只看维度

两个模型即使维度相同也不在同一语义空间；同模型名但供应商快照更新也可能改变。model snapshot和input template均属于空间身份。混合会产生无意义相似度。

### 22.3 旧索引退役

切换后确认无查询流量、删除事件已同步、审计与回滚期满足，再删除旧向量/索引。保留最小manifest和评估报告，不无限保存敏感派生数据。

## 23. 端到端故障演练

准备5个chunk，第二批调用后进程中断。第一次调用记录c1/c2 success、c3 in_flight；重启对账发现c3向量已存在则校验补success，随后只调用c4/c5。Mock调用计数证明已完成项不重复。再注入c5返回错误维度，管线隔离c5且不发布整版。

修复模型配置后，不能把旧错误维度向量强行填充；删除/隔离失败记录，保持相同canonical input并以正确模型版本重算。发布前对账5个success、一个维度、ACL完整。此演练验证控制流，不代表真实API的超时计费语义，后者需授权smoke。

## 24. 设计评审问题

1. chunk边界怎样由真实问题集证明，而非拍长度？
2. token硬限使用哪个Tokenizer/版本？
3. overlap是否跨权限/文档，重复率是多少？
4. ID如何绑定父hash、位置和chunker版本？
5. canonical embedding input包含什么，是否泄露ACL/秘密？
6. model snapshot、dimension和归一化如何锁定？
7. 响应怎样按index/ID映射而非完成顺序？
8. 超时/429/永久错误的重试与成本护栏？
9. 检查点中断后如何证明不重复调用/写入？
10. 升级、撤权、删除和回滚如何跨两套索引？

## 25. 常见误区

- 固定字符任意切标题/代码/表格；
- overlap跨文档/ACL；
- chunk只有文本无父/来源/位置；
- 用文本hash当全局授权ID；
- 混用模型/维度；
- 响应按完成顺序zip；
- 失败从头重跑重复调用；
- 只保存向量不保存input hash/model ID；
- ACL只在父表，下游松散连接；
- Mock向量绿就宣称真实语义检索有效。

## 26. 自测与参考答案

1. **chunk最少追溯什么？** 父文档/版本/hash、来源位置和ACL。
2. **最佳chunk长度固定吗？** 不，需结构、任务、模型和评估决定。
3. **overlap越大越好吗？** 不，增加重复/成本/检索挤占。
4. **字符数等于token吗？** 不。
5. **不同Embedding模型向量能混吗？** 不能假设同空间。
6. **为什么保存dimension？** 验证模型/索引shape合同并防混用。
7. **超时能无脑重试吗？** 不，可能重复计费，需幂等/检查点。
8. **ACL正文不变时会变吗？** 会，需独立同步过滤。
9. **Mock证明什么？** 管线控制流/shape/幂等，不证明语义质量。
10. **越界反例？** 选择BM25、pgvector和reranker，属于检索章节。

## 27. 验收清单

- [ ] 能按结构和真实token硬限分块。
- [ ] 能解释overlap收益/成本和权限边界。
- [ ] 能生成稳定chunk ID、版本、位置和父链接。
- [ ] 能保证ACL随每个chunk传播。
- [ ] 能保存canonical input hash、模型ID和维度。
- [ ] 能按条数+token组批并正确映射响应。
- [ ] 能分类重试且避免重复写/调用。
- [ ] 能用manifest从中断恢复。
- [ ] 能运行黄金边界、Mock失败和删除测试。
- [ ] 能区分本地Mock与真实API未验证。

## 28. 版本与验证边界

父子血缘、ACL继承、版本隔离、维度合同、幂等/检查点是稳定原则；具体Tokenizer、Embedding模型、维度、限制和价格会变。本章资产只用确定性Mock，不调用真实模型API、不评估语义相似度、索引或生产成本。

真实接入还必须验证供应商当前模型快照、输入上限、批量排序、限流、超时后计费、数据保留和实际向量维度，并在授权环境保存响应证据。任何本地固定维度或调用次数都只是控制流夹具，不能写进生产容量结论。上线前还需在真实查询集上评估召回、重复证据、ACL过滤和模型升级迁移；这些分别由后续检索与安全章节承担。

若上述证据缺失，正确结论是“管线局部逻辑已验证、外部模型语义与运营边界未验证”，而不是用一次Mock成功补齐空白。

这种证据分级必须保留到最终验收报告。
