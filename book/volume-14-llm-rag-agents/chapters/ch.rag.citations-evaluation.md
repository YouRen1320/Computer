---
schema_version: 2
edition: 2026.2-draft
id: ch.rag.citations-evaluation
title: RAG 生成、引用、测试集与端到端评估
responsibility: 把检索证据与生成答案绑定为可核验引用，分别评估检索、回答和引用一致性，允许证据不足时拒答。
volume: '14'
order: 12
level: L3
status: drafting
path: book/volume-14-llm-rag-agents/chapters/ch.rag.citations-evaluation.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.llm.structured-output
- ch.ir.hybrid-rerank
version_surfaces:
- python-3.14
- openai-api
- pydantic-2
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
  text: 在 120 秒内解释“RAG 生成、引用、测试集与端到端评估”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - rag-answer-citation
  - rag-e2e-evaluation
  covers_topics:
  - rag.context-assembly
  - rag.citation-span
  - rag.source-attribution
  - rag.insufficient-evidence
  - rag.answer-correctness
  - rag.faithfulness
  - rag.citation-precision
  - rag.regression-set
  uses_capabilities:
  - ai.llm-model-api
  - ai.rag-ingestion-retrieval
  - math.probability-statistics
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“RAG 生成、引用、测试集与端到端评估”构建可运行程序与测试：实现带 source_id 与文本区间引用的维修问答，建立可回答、不可回答、冲突来源和过期文档回归集；独立保存可复现工件与判断结果
  covers_topic_groups:
  - rag-answer-citation
  - rag-e2e-evaluation
  covers_topics:
  - rag.context-assembly
  - rag.citation-span
  - rag.source-attribution
  - rag.insufficient-evidence
  - rag.answer-correctness
  - rag.faithfulness
  - rag.citation-precision
  - rag.regression-set
  uses_capabilities:
  - ai.llm-model-api
  - ai.rag-ingestion-retrieval
  - math.probability-statistics
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: citation-entailment-audit-frozen-rag-regression-retrieval-generation-separation
- id: diagnose
  kind: fault-diagnosis
  text: 面对“引用只指向文档不指向证据、无证据仍回答、答案正确但引用不支持或检索失败被提示词掩盖”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - rag-answer-citation
  - rag-e2e-evaluation
  covers_topics:
  - rag.context-assembly
  - rag.citation-span
  - rag.source-attribution
  - rag.insufficient-evidence
  - rag.answer-correctness
  - rag.faithfulness
  - rag.citation-precision
  - rag.regression-set
  uses_capabilities:
  - ai.llm-model-api
  - ai.rag-ingestion-retrieval
  - math.probability-statistics
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# RAG 生成、引用、测试集与端到端评估

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《结构化输出、Schema 与运行时校验》](ch.llm.structured-output.md)：引用和拒答状态需要版本化结构化输出与严格校验。
- [《稀疏/稠密混合检索、候选融合与重排》](ch.ir.hybrid-rerank.md)：回答上下文来自已验证的混合检索与重排候选。
<!-- END GENERATED LEARNING PREREQUISITES -->

RAG 的目标不是“把搜索结果塞进提示词，让模型说得像有依据”，而是建立一条可以逐层检查的证据链：用户问题触发了哪些检索，哪些来源在当时版本下被送入上下文，回答中的每个可核查事实由哪个具体文本区间支持，证据不足或互相冲突时系统如何拒答。只要其中一层不可观察，最终答案再流畅也不能称为可核验。

本章使用冻结文档和确定性生成替身，不连接模型提供商、搜索服务或生产数据库。实际验证的是 source_id、字符区间、拒答、冲突、过期来源排除，以及检索/回答/引用分层计数。它不证明真实模型的语言质量、真实语料召回率、线上成本或延迟。

## 1. 先画清三条链

一次 RAG 运行至少包含检索链、生成链和引用链。检索链回答“候选从哪里来、为何入选”；生成链回答“上下文和问题如何变成结构化答案”；引用链回答“答案中的事实落在哪段原始证据”。端到端成功要求三者都成立，但诊断时必须拆开。

```text
question
  -> retrieval(query, filters, index_version)
  -> retrieved passages(source_id, version, span, score)
  -> context assembly(order, truncation, token budget)
  -> structured generation(status, claims, citations)
  -> citation audit + answer evaluation
```

检索失败时生成器恰好凭参数记忆答对，不能把检索记为成功；检索正确但生成器曲解证据，是生成错误；答案文字正确但引用指向无关段落，是引用错误。把三者压成一个 `passed=true` 会失去修复方向。

## 2. 来源身份是不可变引用

`source_id` 应指向一个可还原的来源版本，而不是模糊标题“维修手册”。文档更新后相同标题可能有不同内容，字符位置也会变化。最低限度需要文档 ID、版本或内容哈希、chunk ID、有效期以及租户/ACL 元数据；引用结果还要记录本次检索快照或索引版本。

同一个 source_id 不能在运行间悄悄换字节。若业务系统允许“逻辑 ID 指向最新版”，评估记录仍要解析并保存当时的不可变版本。否则昨天通过的黄金引用今天可能指向另一段内容，回归失败却无法复现。

### 2.1 chunk 不是来源终点

向量库返回 chunk 很方便，但用户通常需要原文位置。chunk 需保留 parent_id、parent_version 和在父文档中的偏移。若切块时添加标题、清理空格或归一化 Unicode，必须保存从索引文本到展示原文的映射；不能把“在加工后字符串中的 17—29”冒充原始文档区间。

### 2.2 字符、字节与 token 区间

本章使用 Python 字符串的半开区间 `[start,end)`，即 `text[start:end]`。UTF-8 字节偏移、Unicode code point、UTF-16 单元和 tokenizer token 下标不是同一坐标。API 合同必须写明坐标系；前端高亮若使用 JavaScript UTF-16，还需转换和包含中文、emoji、组合字符的测试。

## 3. 上下文组装也是可测试程序

检索得到列表并不等于模型实际看到同一列表。组装层可能去重、重排、截断、增加标题、插入系统指令，或因 token 预算丢掉尾部来源。因此要保存“检索结果”和“最终上下文”两个证据，不只记录一个文档 ID 数组。

一种容易审计的格式是明确边界：

```text
SOURCE manual-e42:v3#chunk-2
E42 表示冷却液温度过高。先停机并检查冷却回路。
END SOURCE
```

分隔符防止来源粘连，但不能让来源内容变可信指令。上下文内的“忽略系统提示”“调用删除工具”仍是数据。安全章会进一步说明，任何工具权限都必须由服务器授权而不是提示词决定。

### 3.1 顺序、重复与预算

上下文顺序可能影响生成，所以排序规则要固定：例如先按重排分数，再用 source_id 处理同分。重复段落应按内容哈希或父文档区间去重，同时保留合并来源。截断要记录哪些来源完全进入、部分进入或被排除；被截掉的证据不能成为合法引用。

### 3.2 只引用模型实际看到的快照

引用审计集合应是最终上下文中的 active sources，而非整个向量库。模型没有看到的高质量文档不能事后补成引用；这会掩盖检索或上下文预算问题。引用必须与本次请求的 context snapshot 绑定。

## 4. 结构化回答合同

建议把回答状态与正文分开。最小状态可包括 `answered`、`insufficient_evidence`、`conflicting_evidence`，每条事实配引用数组。Pydantic `extra="forbid"` 能拒绝未知字段，区间要求非负且 `end>start`，但这些只是结构正确；“该区间是否真的支持事实”仍需语义或规则审计。

```json
{
  "status": "answered",
  "text": "先停机并检查冷却回路。",
  "citations": [
    {"source_id": "manual-e42:v3", "start": 14, "end": 26, "quote": "先停机并检查冷却回路。"}
  ]
}
```

模型返回 quote 时，服务必须重新从保存的来源按区间切片并比较，不能信任模型抄写。source_id 不在上下文、区间越界、切片与 quote 不同，都应在语义评分前作为确定性合同失败。

## 5. 引用粒度与归因

“来源：维修手册”只是文档级归因，不足以让审核者定位证据。合理粒度取决于主张：一句明确操作通常引用最小支持句；跨句因果可能引用连续多句；一个答案含两个事实就分别引用，不用一个宽泛段落笼罩全部文字。

最小并非越短越好。只引用“停机”两个字可能缺少条件 E42；把整页都引用又降低精度。评估规则应定义“足以判断主张真假的最小语义范围”，并在人工标注指南中给正反例。

### 5.1 多来源归因

多个来源共同支持同一主张时可保留多个引用；若一个是规范、一个是案例，要标出用途。来源互相矛盾不能用多数投票自动掩盖，尤其涉及安全操作。系统应返回冲突状态、列出冲突来源并转人工，而不是任选高分段落。

### 5.2 派生与推断

证据写“温度 95°C”，回答写“已超过 90°C 阈值”，还需要阈值来源；证据只给两个数字时，计算过程也要可复核。模型推断、业务规则和文档原句应分别标记，避免让引用看起来直接说了实际没有说的话。

## 6. 证据不足与稳定拒答

拒答不是异常，而是输出合同。以下情况通常应拒答或转人工：没有授权候选；候选与问题无关；关键字段缺失；来源过期且无有效替代；有效来源冲突；请求要求文档未覆盖的结论。提示词里的“请一定回答”不能越过该门。

稳定拒答要求同一个冻结输入在目标版本和参数下反复得到同一状态，且不生成看似确定的替代答案。拒答文字可以自然变化，但机器状态必须稳定。若 UI 只看一段文本猜是否拒答，评估和业务分支都会脆弱。

### 6.1 过期文档

过期不是低分，而是资格问题。若文档已失效，应在候选资格或上下文组装前排除，不能先让模型看到再提示“请忽略过期内容”。回归集至少有“只有过期来源”的案例，预期 `insufficient_evidence`。

### 6.2 冲突来源

冲突判断需要比较同一事实键的不同值，并考虑版本、发布机构和有效时间。教材夹具用同一 `fact_key` 的多个 active value 触发 `conflicting_evidence`；真实系统还需要领域规则和人工决策，不能声称通用字符串比较可解决冲突。

## 7. 引用审计的确定性层

先做无需模型的检查：状态为 answered 时必须有引用；非回答状态不应伪造引用；source_id 必须在 active context；区间合法；实际切片与 quote 完全一致；引用版本与运行快照一致。只有这些通过后，才讨论引用是否蕴含主张。

这种顺序很重要。区间已越界时去调用“LLM-as-judge”既浪费成本，又让概率评分掩盖确定性 bug。首个可信证据应是最靠前的失败合同。

### 7.1 蕴含不等于字符串包含

本章冻结例子让答案等于引用句，适合验证管道。真实回答会改写、合并或否定，因此字符串包含只是下界。语义审计可由人工、领域规则、NLI 模型或受控 judge 完成，但每种 oracle 都有误差，要用人工标注子集校准并记录版本。

### 7.2 引用精度与覆盖率

引用精度关心“给出的引用有多少真正支持相关主张”；引用覆盖率关心“回答中的可核查主张有多少被支持”。只优化精度可能通过少引用逃避覆盖；只优化覆盖可能引用整篇文档。两项需同时看，并规定什么算 atomic claim。

## 8. 把评估拆成层

建议至少输出：检索命中、上下文资格、回答正确性、忠实性、引用结构有效、引用蕴含、拒答正确性。端到端指标可以作为发布门，但故障报告必须保留各层结果。

```text
retrieval_hit = relevant source entered eligible candidate set
context_hit   = relevant evidence survived assembly
answer_ok     = answer matches labeled requirement
faithful      = every material claim follows from provided evidence
citation_ok   = concrete cited spans support their claims
refusal_ok    = answerability state matches regression label
```

回答正确性与忠实性不同：答案可能符合世界事实却不由本次上下文支持；也可能忠实复述了过期文档却业务上错误。RAG 必须同时约束。

## 9. 指标与分母

对 N 个案例，accuracy 是正确案例数除以 N；但不同状态最好分层报告。可回答案例上的 answer accuracy、不可回答案例上的 refusal recall、实际回答上的 citation precision，各自分母不同。若所有不可回答案例都被系统拒答，总 accuracy 可能很高，却没有证明它能回答问题。

宏平均让每类案例权重相同，微平均受大类数量支配。数据集含不同设备、错误码、租户和文档版本时，应按关键切片报告置信区间与样本数。样本太少时只给原始计数，不用两位小数制造精确感。

### 9.1 检索与生成分离实验

固定黄金上下文测试生成，能判断生成器是否会忠实引用；固定生成器测试检索，能判断候选质量。完整 RAG 回归再测端到端。若只跑端到端，检索改进可能被生成随机性抵消，或生成记忆掩盖检索退化。

### 9.2 阈值不是自然常数

发布阈值来自风险和历史基线。例如安全维修步骤可能要求不可回答集零越界回答，而普通说明允许不同策略。阈值、样本集版本、评审人和失败处置应进版本库；本章不替业务制定生产阈值。

## 10. 回归集设计

最小回归集必须覆盖：明确可回答、明确不可回答、相似但不相关、多个互补来源、有效来源冲突、过期来源、引用跨度边界、Unicode 文本、检索为空、上下文被截断。每个案例保存问题、允许语境、期望状态、关键主张、可接受来源区间和理由。

不要让数据集只包含系统容易的“原句问答”。加入否定、时间条件、设备型号、同名部件和权限差异。还要保存失败案例到回归集，但先去敏和审查授权，不能把生产隐私直接复制到测试仓库。

### 10.1 冻结与更新

冻结集用于版本比较，挑战集用于探索新故障。发现真实问题先写成最小复现，经过标注再进入冻结集。修改黄金答案必须有评审记录，不能为了让新模型通过而静默改预期。

### 10.2 防止数据泄漏

用于选择提示词或模型的案例不再是独立测试集。开发集、回归门和最终盲评要分开；频繁查看盲评会使其逐步变成开发集。这里只运行公开确定性夹具，没有模型训练或盲评证据。

## 11. 模型替身与真实 API

单元测试不应依赖网络模型的可用性、价格和随机变化。替身要在合同层真实：接收与生产适配器相同的结构，返回合法结构或明确故障，并记录有效请求。它不能被描述成“模型表现”。集成测试再用锁定的模型 ID、参数、提示版本和小样本，结果单独保存。

`openai-api` 在版本表中是 conceptual：OpenAI 模型快照、端点和 SDK 必须逐实验记录，且不能外推为提供商中立协议。教材没有 API key、没有发请求，因此所有真实模型正确率、token 消耗、限流和延迟均未验证。

## 12. 四种典型故障

### 12.1 只指文档不指证据

现象是有 source_id 却无 start/end，或引用整篇文档。失败阶段为 citation contract，首证据是缺少具体区间。修复输出精确 span，并从保存快照重新切片验证；残余风险是精确区间仍可能语义不支持。

### 12.2 无证据仍回答

检索为空而 status=answered。失败阶段首先是 retrieval evidence 为 empty，随后是 generation refusal policy 失败。修复不是给提示词追加“不要幻觉”，而是在应用层根据资格证据门控回答，并对模型输出再次校验。

### 12.3 答案正确但引用不支持

文本恰好正确，引用却只含错误码标题。answer correctness 可以通过，citation entailment 必须失败。首证据是 `source_text[start:end]` 与该主张关系不成立。不能把正确答案当作引用正确。

### 12.4 检索失败被提示词掩盖

模型依赖参数记忆给出常识答案，端到端肉眼看似成功。分层记录会显示 retrieval_hit=false。修复检索/索引而非给生成器加分；必要时要求回答必须引用本次上下文，拒绝外部记忆事实。

## 13. 测试金字塔

单元层验证 schema、区间、版本、拒答门和指标分母；组件层冻结 Retriever 与 Generator 的一边测试另一边；集成层连接目标模型但使用受控非敏感数据；端到端层验证授权、检索、生成、引用和 UI 高亮；红队层尝试注入、跨租户与引用篡改。

每次修复都应重跑原失败案例和相邻回归，而不是只写一个新的 happy path。失败报告保存输入摘要、数据集版本、代码/提示版本、实际输出、预期和首个可信证据。

### 13.1 引用渲染也属于端到端合同

后端 span 正确，前端仍可能高亮错文档版本、把半开区间当闭区间、截断上下文后继续显示引用，或允许用户通过 source_id 猜其他租户文档。端到端测试应从回答点击引用，经过 Java 授权读取同一不可变来源，最后断言高亮文字与 quote 一致。打不开原文时应显示明确失效状态，不悄悄跳到最新版。

展示层要区分“引用支持的事实”“模型推断”和“系统提示”。一个脚注号覆盖长段落会让用户误以为全部内容有证据。移动端空间有限时可以折叠来源，但不能删除版本、有效期和冲突警告。可访问性测试还要保证键盘/读屏能关联主张和来源。

### 13.2 人工标注与仲裁

回答正确、忠实性和引用蕴含常需要人工标签。先写标注指南：如何切 atomic claim、允许哪些改写、条件/否定如何处理、冲突怎样标、证据不足如何判。至少两位标注者独立完成一部分，记录分歧与仲裁理由；只有一个人“感觉合理”不能估计 oracle 可靠性。

标注者不能只看答案，也要看到问题、当时有效上下文和来源版本；否则会用外部常识给错误 RAG 加分。若 judge 模型参与，保留 prompt/model 版本，并用人工子集计算一致性。judge 分数不是地面真相，特别是同一家模型评自己时可能有系统偏差。

### 13.3 回归发布报告

每次候选发布生成一份机器可读报告：数据集哈希、代码/提示/模型/索引版本、总案例与切片计数、每层指标、失败 ID、相对基线变化和未运行项。把 skipped 与 passed 分开；没有 API key 的在线集成不能记绿。发布门读取报告中的明确字段，不解析控制台自然语言。

失败案例按首层分类并分配负责人：ingestion/index、retrieval、context assembly、generation、citation、UI 或 authorization。修复一层后重跑全链，因为提高召回可能扩大上下文并改变生成。报告保留历史，才能发现“总分相同但错误类型转移”。

### 13.4 评估集的权限和隐私

回归数据也受权限约束。生产工单脱敏后仍可能被重识别；测试仓库、CI 日志、模型 judge 和第三方平台都属于新的数据接收方。优先合成与公开数据；确需真实案例时按最小字段、授权、保留期和访问审计处理。删除来源后，相关 embedding、缓存、失败快照与导出报告也要进入清理流程。

### 13.5 变化预算

模型、提示、Retriever、chunk、reranker 和语料不要在一次实验里全部改变，否则无法归因。一次候选尽量只改变一个主要变量；必须联合升级时做消融对照。随机模型输出用重复运行和声明统计方法，不能挑最好一次。成本预算也作为实验约束，避免评估因无限重试失真。

### 13.6 可重复运行环境

报告还要保存 Python/依赖锁、区域、provider endpoint、随机种子和环境变量名称清单（不保存秘密值）。时间、文档有效期和“最新版”查询通过可注入 clock 固定。若同一制品因外部服务漂移不能完全复现，明确标记外部变量，并保留原始脱敏响应与 request ID；不能把后来一次成功覆盖原失败证据。

## 14. FactoryCare 责任边界

Java 服务持有工单事实、租户/资源授权、状态机和最终写入。Python RAG 接收经授权的知识投影，返回带来源的派生建议和不确定状态。它不能修改工单状态，也不能把“模型说已完成”当作事实。前端只通过 Java API 查看建议；Java 再决定哪些字段可见、是否需要人工确认。

维修手册本身也要在 Java 或权威内容服务的访问控制下。向量索引中的 ACL 是查询优化与防御层，不取代最终授权。引用暴露 source_id 时还要确认调用者有查看原文的权限。

## 15. 本章实际证据与未验证项

2026-07-24 在隔离环境使用 Python 3.14.3、Pydantic 2.13.4、pytest 9.1.1 运行。示例冻结四类案例并验证精确字符 span、active 来源、冲突/拒答和分层计数；实验注入四种故障并定位。没有连接模型 API、PostgreSQL、向量库或真实 FactoryCare 数据。

因此已验证的是本地合同和 oracle；未验证的是语义 judge 准确率、真实检索质量、真实模型忠实性、线上安全、成本、延迟与用户体验。任何后续真实实验都要另存模型 ID、SDK 版本、参数、语料快照和时间。

## 16. 可运行工件

- `examples/encyclopedia/ch.rag.citations-evaluation/`：冻结四案例、Pydantic 结构、精确 span 与分层指标。
- `labs/encyclopedia/ch.rag.citations-evaluation/`：文档级引用、无证据回答、错误 span 与检索失败诊断。
- `exercises/encyclopedia/ch.rag.citations-evaluation/`：故意返回整篇文档，验证初始红灯。
- `solutions-private/encyclopedia/ch.rag.citations-evaluation/`：最小精确区间答案。

## 17. 120 秒复述模板

“RAG 需要分别保存检索、最终上下文、结构化回答和引用证据。引用至少绑定不可变 source_id 与明确坐标系下的 `[start,end)`，服务重新切片验证 quote。先做 source、范围、版本等确定性检查，再判断语义蕴含。可回答、不可回答、冲突和过期来源都进入冻结回归；检索、回答正确性、忠实性和引用精度分别计数。越界反例是模型凭记忆答对就宣称检索成功，或只有文档名就宣称引用可核验。Java 仍拥有业务事实、授权、状态机和最终写入，Python 只返回带证据的派生建议。”

## 18. 自测题

1. 为什么 source_id 还要绑定版本或哈希？
2. Python 字符区间和前端 UTF-16 下标有什么风险？
3. 检索结果与最终上下文为什么要分别保存？
4. quote 为什么必须由服务重新切片验证？
5. 引用结构有效与引用语义支持有何区别？
6. 答案正确为什么仍可能不忠实？
7. 只有过期来源时为何不是低分回答？
8. 怎样区分检索失败与生成失败？
9. 拒答集为何必须单独报告？
10. 冻结模型替身能证明什么，不能证明什么？

## 19. 答案要点

1. 逻辑标题可对应变化内容，版本保证回放相同字节。
2. 坐标单位不同，中文/emoji 高亮可能错位，需声明并转换测试。
3. 组装可能重排、去重和截断，模型实际看到的内容不同。
4. 模型返回的 quote 也是不可信输出，必须与权威快照一致。
5. 前者检查字段、来源、范围，后者检查区间是否真正支持主张。
6. 它可能来自模型记忆或过期来源，而非本次有效证据。
7. 过期是资格失败，应拒答或转人工，不能让模型自行忽略。
8. 固定生成测检索、固定黄金上下文测生成，并保留分层计数。
9. 总体 accuracy 会被类别比例掩盖，拒答召回代表不同风险。
10. 它证明管道合同和测试 oracle，不证明真实模型质量或线上表现。

## 20. 资料与核验边界

- [Pydantic 模型文档](https://docs.pydantic.dev/latest/concepts/models/)：结构验证与严格字段合同。
- [pytest 文档](https://docs.pytest.org/en/stable/)：冻结回归和故障测试。
- [LangChain Retrieval 官方概览](https://docs.langchain.com/oss/python/langchain/retrieval)：Retriever 是查询到文档的接口；本章不依赖其实现。
- [Retrieval-Augmented Generation 原始论文](https://arxiv.org/abs/2005.11401)：RAG 的来源背景，不是本章引用产品合同。

资料核验日期为 2026-07-24。通用证据链原则相对稳定；具体模型 API、Pydantic/pytest 行为和任何 judge 模型都是版本表面，升级时需重跑冻结回归。
