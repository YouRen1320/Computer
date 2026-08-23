---
schema_version: 2
edition: 2026.2-draft
id: ch.rag.ingestion-metadata
title: 文档解析、清洗、权限元数据与可追溯性
responsibility: 把异构文档转换为可追溯规范文本与权限元数据，保存来源、版本、哈希和解析错误，不在本章切块或向量化。
volume: '14'
order: 6
level: L3
status: drafting
path: book/volume-14-llm-rag-agents/chapters/ch.rag.ingestion-metadata.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.exceptions-context
- ch.llm.api-prompts-cost
version_surfaces:
- python-3.14
- pytest
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“文档解析、清洗、权限元数据与可追溯性”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - rag-document-normalization
  - rag-source-metadata
  covers_topics:
  - rag.document-loader-boundary
  - rag.text-normalization
  - rag.parse-error-quarantine
  - rag.content-hash
  - rag.source-uri
  - rag.document-version
  - rag.acl-metadata
  - rag.ingestion-lineage
  uses_capabilities:
  - python.io-errors
  - ai.llm-model-api
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 摄取 Markdown、PDF 抽取文本夹具和 CSV 元数据，生成带来源、版本、哈希、ACL 和错误隔离清单的规范语料；独立保存可复现工件与判断结果
  covers_topic_groups:
  - rag-document-normalization
  - rag-source-metadata
  covers_topics:
  - rag.document-loader-boundary
  - rag.text-normalization
  - rag.parse-error-quarantine
  - rag.content-hash
  - rag.source-uri
  - rag.document-version
  - rag.acl-metadata
  - rag.ingestion-lineage
  uses_capabilities:
  - python.io-errors
  - ai.llm-model-api
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: fixture-ingestion-lineage-audit-hash-reingestion-test
- id: diagnose
  kind: fault-diagnosis
  text: 面对“解析失败静默丢弃、来源 URI 丢失、权限元数据与正文分离或同版本内容哈希漂移”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - rag-document-normalization
  - rag-source-metadata
  covers_topics:
  - rag.document-loader-boundary
  - rag.text-normalization
  - rag.parse-error-quarantine
  - rag.content-hash
  - rag.source-uri
  - rag.document-version
  - rag.acl-metadata
  - rag.ingestion-lineage
  uses_capabilities:
  - python.io-errors
  - ai.llm-model-api
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 文档解析、清洗、权限元数据与可追溯性

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《异常、上下文管理器与资源清理》](../../volume-12-python-data/chapters/ch.python.exceptions-context.md)：解析失败隔离、清理和可追溯错误必须建立在 Python 异常链与上下文管理能力上。
- [《模型 API、消息、提示、Token 与成本》](ch.llm.api-prompts-cost.md)：后续 RAG 语料合同需要理解模型上下文、成本和数据发送边界。
<!-- END GENERATED LEARNING PREREQUISITES -->

RAG的第一步不是向量化，而是把文档变成可信、可追溯、带权限的规范语料。解析器可能漏页，OCR可能错字，CSV可能编码异常，权限可能在复制正文时丢失。若摄取层把这些问题静默吞掉，后续检索和生成再高级也只是在错误语料上工作。

本章止于“规范文档”。不切块、不计算Embedding、不建索引。输出必须让任何一段未来chunk都能继承来源、版本、哈希和ACL，并能定位解析错误。原文和权限系统仍是事实源；规范语料是可重建派生物。

## 1. 摄取边界

摄取把外部来源快照转换为内部规范记录。输入可能是Markdown、HTML、PDF、Word、CSV或知识库API。Loader负责获取字节和源元数据；Parser把格式转为结构/文本；Normalizer做确定性规范化；Validator检查合同；Writer幂等保存有效记录；Quarantine保存失败证据。

不要让一个函数同时下载、OCR、清洗、切块、嵌入和写向量库。阶段分开才能知道失败在哪、重跑哪一步、哪个版本改变了结果。

### 1.1 来源快照

来源会变化。摄取时记录source URI、外部ID、revision/etag/updated_at、抓取时间和原始字节哈希。只存文件名`manual.pdf`无法区分目录、租户和版本。

### 1.2 信任边界

文档内容是不可信数据，可能含恶意指令、脚本、巨大压缩包或敏感信息。解析运行在受限环境，限制大小、类型、页数、超时和资源；不执行宏/脚本；文件扩展名不能替代实际类型检查。

## 2. 规范文档模式

建议字段：`document_id`、`source_uri`、`source_system`、`source_version`、`fetched_at`、`media_type`、`raw_hash`、`normalized_text`、`normalized_hash`、`title`、`language`、`acl`、`parser_id`、`normalizer_id`、`lineage`、`status`、`error`。

document_id应稳定地标识逻辑文档；source_version标识来源版本；normalized_hash标识规范内容。三者职责不同。内容相同的两个权限不同文档不能因为hash相同就合并成一个无权限记录。

### 2.1 必需与可选

source URI、版本、正文hash、ACL和处理版本通常必需。标题/语言检测可失败并有明确unknown。不能因可选元数据缺失丢整篇，也不能把必需ACL缺失降级为公开。

### 2.2 不可变记录

同一document_id+source_version一旦发布，规范内容和ACL摘要应不可静默变化。若解析器升级产生不同文本，创建新ingestion revision并可对比，而不是覆盖旧证据。

## 3. 文档Loader

Loader只取得允许范围内的字节/结构与来源元数据。文件Loader防路径穿越和符号链接越界；HTTP Loader限制域名、重定向、大小与超时，防SSRF；API Loader使用最小权限并分页保存游标。

### 3.1 媒体类型

扩展名、Content-Type和魔数可能冲突。记录观察值并按安全策略决定解析器。伪装成PDF的可执行文件应隔离。压缩格式限制嵌套和解压后大小，防zip bomb。

### 3.2 幂等获取

若etag/revision未变，可以跳过重新解析，但仍需确认ACL是否独立变化。内容版本和权限版本可分开；只比较正文hash可能漏掉权限撤销。

## 4. Markdown与纯文本解析

Markdown既有可见正文，也有标题、列表、代码块、链接和frontmatter。规范层应尽量保留结构标记或结构树，而不是把所有换行压成一行。未来切块需要标题层级和代码边界。

链接显示文字与目标URI都可能重要；图片alt与附件关系需保留。HTML脚本/样式通常不作为知识正文，但移除策略要版本化。代码块中的`#`不是标题，解析器不能只用正则按行猜全部语法。

### 4.1 文本编码

字节必须按明确编码解码。优先来源声明/BOM和合同，失败进入隔离或受控探测；不要`errors=ignore`静默丢字节。记录原编码、替换字符数和解码错误位置。

## 5. PDF解析

PDF是页面绘制指令容器，不保证有正确阅读顺序。文本PDF可抽取字符，扫描PDF需OCR；多栏、页眉页脚、表格和连字符会破坏顺序。提取成功退出不等于正文正确。

### 5.1 页面证据

规范输出保留页码和块来源，使未来引用能回到页。记录页数、每页字符数、空白页、异常字符率和OCR状态。若原PDF更新，source_version和raw_hash改变。

### 5.2 OCR边界

OCR有语言包、分辨率、旋转和版面参数。保存引擎/版本/配置和置信摘要；低质量页进入人工审查或隔离。不能把OCR文字当无误原文。真实PDF还需渲染抽检；本章资产只使用“已抽取文本夹具”，不冒充验证PDF引擎。

### 5.3 表格

表格扁平文本容易错列。重要表格保留行列结构、表头和单元格坐标；跨页表头需处理。若无法可靠解析，标记而非拼成看似流畅的错误句子。

## 6. CSV与结构化元数据

CSV可能承载文档清单、ACL和标题。显式指定编码、分隔符、引号、列模式和空值。每行宽度一致不证明语义正确；document_id/source_uri唯一性和引用完整性要验证。

### 6.1 防公式注入

若CSV将来被表格软件打开，以`= + - @`开头的字段可能执行公式。存储原值与导出安全策略分开；不要在解析时随意损坏合法文本，但导出给办公软件要防护。

### 6.2 连接正文与元数据

按稳定document_id连接，验证一对一/一对多期望。ACL行缺失不得默认公开；正文缺失的元数据也要报告。连接后做anti-join清单，避免静默丢弃。

## 7. 文本规范化

规范化目标是让等价输入产生稳定表示，同时保留语义和证据。典型步骤：统一换行到LF；去除明确的BOM；按策略处理Unicode规范；修剪行尾空白；限制连续空行；保留标题、列表、代码和段落边界。

### 7.1 不要过度清洗

全转小写可能损坏代码/标识；删除标点损坏版本号和否定；压缩全部空白破坏表格/代码；去掉页码使引用困难。每个变换写目的、输入输出例子和不可逆风险。

### 7.2 Unicode

视觉相同字符可能有不同编码。NFC等规范化可改善hash稳定，但对签名、源码和某些语言有影响。保存raw_hash与normalized_hash，能区分原字节变化和规范结果相同。

### 7.3 页眉页脚

重复页眉可通过跨页统计识别，但误删正文风险高。保留删除规则、命中页和原位置；先用黄金PDF测试。不要因为某行重复就一定删除。

## 8. 哈希

密码学hash把字节映射为固定摘要，用于内容寻址、幂等和完整性比较，不证明内容正确或来源可信。raw_hash对原始字节；normalized_hash对规范文本的明确编码字节。

### 8.1 hash输入合同

必须固定算法、编码、换行和规范化版本。同一可见文本若编码不同，raw_hash不同；规范后可能相同。hash字段带算法前缀或独立算法列，便于迁移。

### 8.2 版本冲突

同一source_version出现不同raw_hash说明来源违反不可变假设、抓取不稳定或标识错误。不要自动覆盖；隔离并告警。不同版本相同hash可能是元数据/ACL更新，也需保存版本关系。

### 8.3 hash不是去重全部

hash相同只说明字节相同。租户、ACL、来源和保留策略不同的文档仍是不同授权对象。可共享受控内容blob，但授权元数据不能被去重抹平。

## 9. 来源URI

source URI应能唯一、稳定地指回授权来源，不一定对最终用户直接可点击。记录来源系统和外部ID，避免本地临时路径成为唯一证据。URI规范化要谨慎：大小写、查询参数和片段在不同系统意义不同。

公开回答引用应转换为用户有权访问的链接或文档ID。内部存储路径、签名URL和凭证不能暴露。引用服务再次做权限检查。

## 10. 文档版本

版本可以是外部revision、Git提交、etag或内容版本组合。时间戳 alone可能碰撞或受时钟影响。定义版本排序与删除语义：更新新版本、撤回旧版本、ACL变化是否触发重建。

### 10.1 有效时间

政策文档可能有`valid_from/valid_to`，与摄取时间不同。检索“当时政策”需要时间版本；当前问答应排除已撤回内容。来源系统拥有有效性事实，RAG元数据继承。

### 10.2 解析版本

同一原文用parser v1/v2得到不同规范文本。记录parser/normalizer版本与配置hash。升级时并行重跑黄金集，比较差异和引用位置，再决定迁移。

## 11. ACL元数据

ACL决定谁能发现和读取文档。可包含tenant_id、允许主体/角色/组、拒绝规则、分类等级和策略版本。最小安全原则是ACL缺失则隔离/拒绝，不是公开。

### 11.1 ACL必须随正文流动

规范文档、未来chunk、Embedding记录和索引条目都继承ACL与来源ID。不能把正文写一个库、ACL写另一个无事务关联的表后假设永远同步。每个检索候选在返回前按当前身份过滤。

### 11.2 摄取时与查询时

摄取时验证ACL格式和来源；查询时用当前身份/策略执行。只在摄取时过滤生成“每用户索引”可能难以撤权；只在模型生成后过滤则泄露已发生。权限过滤必须早于内容进入模型上下文。

### 11.3 ACL变化

正文未变但权限撤销，索引必须及时更新/失效。记录acl_version和更新事件；用不变量检查无ACL chunk为零、租户交集为空。日志不要记录完整敏感ACL列表。

## 12. 血缘

血缘描述输出怎样由输入产生：run_id、source snapshot、loader/parser/normalizer版本、配置hash、父记录、时间、状态和错误链。未来chunk再引用normalized_document_id和位置。

血缘支持回答：“这段答案来自哪个版本的哪一页？当时谁有权？用哪个解析器？为什么今天结果变了？”没有血缘的向量无法可靠引用和删除。

## 13. 错误隔离

解析失败不能静默跳过，也不应让一个坏文件阻断整个批次。Quarantine记录document ID、来源版本、阶段、错误类型、安全摘要、重试性、原始hash和run ID。敏感正文不写日志。

### 13.1 可重试与永久错误

网络超时可能重试；格式不支持需人工/新解析器；ACL缺失在元数据修复前不应重试风暴。重试有上限、退避和幂等键。成功后保留失败历史用于审计。

### 13.2 部分解析

PDF 100页中第50页失败，策略可整篇隔离或发布已验证页并标`partial`。不能标complete。用户答案必须知道覆盖范围；高风险手册更倾向整篇隔离。

### 13.3 错误预算

报告成功、隔离、跳过未变、删除和ACL更新数量。100%进程成功但隔离暴增不是健康。按来源/解析器监控失败率。

## 14. 幂等与重跑

幂等键可由document_id+source_version+pipeline_version组成。相同输入重跑产生相同normalized hash和记录，不重复写。若输出不同，阻断并比较非确定步骤。

写入可用暂存→验证→原子发布。批次失败时旧有效语料继续服务，新run不半发布。删除/撤回也有显式墓碑和下游传播。

## 15. 测试

### 15.1 黄金夹具

小型Markdown覆盖标题、列表、代码、Unicode、换行；PDF抽取夹具覆盖页码/页眉/多栏标记；CSV覆盖引号、空值、ACL。黄金输出需人工审查，变更不能盲更新。

### 15.2 重摄取

同输入同版本运行两次，hash/ID一致且无重复。改变换行若规范规则视为等价，raw hash可变而normalized hash相同；改变正文则新hash。

### 15.3 失败注入

无效UTF-8、损坏文件、缺ACL、重复版本不同hash、未知媒体类型、超限大小。断言进入正确隔离阶段且有效语料不污染。

### 15.4 血缘审计

每个published记录有来源、版本、两个hash、parser/normalizer、ACL、run ID；每个quarantined有安全错误。随机抽样能回到原位置。

## 16. FactoryCare设计

来源包括维修手册Markdown、厂商PDF和设备元数据CSV。Java文档/权限服务拥有租户和ACL事实；Python摄取任务以只读授权读取快照，生成规范文档。正文与ACL一起持久化，任何缺ACL记录隔离。

PDF真实解析在受限worker；学习资产只用抽取文本。每页保留source_page。规范hash用UTF-8 LF文本；raw hash用原字节。版本由来源revision+pipeline revision组成。下游chunk/embedding可删除重建。

## 17. 诊断案例

### 17.1 文档消失但任务绿

批次输入100，输出99，进程0。检查阶段计数发现一个解析异常被`except: continue`吞掉。修复记录quarantine并使摘要不平衡门禁失败；重跑损坏夹具，期望隔离1而非静默。

### 17.2 来源URI丢失

文本存在但引用只能显示`chunk-123`。首证据是规范记录source_uri为空，早于chunk。修复模式必需字段和连接anti-join，重建下游。

### 17.3 ACL与正文分离

正文已写、ACL事务失败，索引按默认公开。修复ACL缺失拒绝发布、原子写和查询前过滤；扫描现有无ACL记录并撤下。不能只在回答后隐藏引用。

### 17.4 同版本hash漂移

两次摄取source_version相同，normalized hash不同。比较raw hash、parser版本、环境与非确定步骤；若来源字节变则版本系统错误，若原字节同则管线不确定/版本未升级。隔离冲突，不覆盖。

## 18. 删除、撤回与重建

RAG语料不是只增不减。来源删除、用户行使删除权、文档撤回、保留期到期或ACL收紧，都必须传播到规范语料和所有下游派生物。删除事件至少包含document_id、source_version/范围、原因、发生时间、来源策略版本和run ID。

不要只删规范文本却留下chunk、向量和缓存；也不要只在索引标隐藏而永久保留不应保存的原文。建立派生关系清单：raw snapshot→normalized document→chunk→embedding→index entries→answer cache。删除任务按血缘定位并可重试，完成后用反向查询证明所有应删除对象已不可检索。

### 18.1 墓碑

分布式流程可写墓碑表示“该版本已撤回”，防旧重试把内容复活。墓碑不是保存敏感正文，只保留最小标识和合规所需审计。墓碑也有保留策略。写入新版本前检查更晚的撤回事件。

### 18.2 重建优先

规范语料与索引应能从授权来源、版本化代码和配置重建。这样解析器升级、Embedding升级或索引损坏时无需手工修补。重建不意味着忽略成本：保存检查点、批次清单和幂等键，避免重复解析与计费。

### 18.3 权限撤销延迟

ACL撤销要有明确SLO，从来源事件到检索不可见需要多久。高敏感系统可能同步阻断，再异步清理；不能等夜间全量重建。测试模拟正文hash不变但acl_version更新，确认候选立即被过滤。

## 19. 解析质量验收表

每种格式建立黄金集和指标，而不是一个“解析成功率”。文本指标可含页覆盖率、字符数比、空白页数、替换字符、乱码规则、标题/列表/代码结构保留、表格单元格覆盖、阅读顺序抽检和引用位置可回跳。

### 19.1 不同来源不同门槛

Markdown可要求结构解析精确；扫描PDF允许OCR不确定但低置信页隔离；CSV要求模式/行宽/主键严格。把所有格式用同一“非空文本”门禁会放过大量错误。

### 19.2 抽样与人工复核

自动指标抓不住语义错序。每次解析器升级抽样渲染原页与规范文本对照，覆盖多栏、表格、脚注、中文、公式和旋转页。保存审查结论与样本ID，不上传敏感页面到未经批准工具。

### 19.3 差异审查

同一原文从parser v1到v2，生成结构化diff：总字符、页数、标题、删除/新增段和hash。大差异需解释。不能因为新版本号更高就自动接受，也不能盲更新黄金文件。

## 20. ACL不变量与对抗测试

构造两个租户A/B、公开/角色限定/拒绝覆盖等小矩阵。摄取后断言每个规范记录ACL非空且tenant匹配；派生模拟时ACL逐项相同；查询模拟用A身份永远看不到B。再注入缺ACL、未知组、撤权和策略版本变化。

### 20.1 内容相同权限不同

A和B上传完全相同手册，内容hash相同。存储层可去重blob，但两个document authorization records独立。查询A返回A的source ID，不能暴露B存在。删除A不应删掉B合法blob引用，删除B亦然；引用计数/所有权需事务验证。

### 20.2 管理员不是默认万能

管理员范围也由策略定义。开发调试身份、后台任务和模型服务账号都用最小权限，不使用“超级token”绕过过滤。摄取服务读取ACL不代表生成服务可返回所有正文。

### 20.3 权限元数据不进自然语言判断

不要让模型读一句“仅管理员”后自己决定。ACL是结构化字段，由检索/工具层执行。文档正文可以伪造权限声明，只有权威权限服务字段可信。

## 21. 运行清单和发布协议

一次摄取run先冻结输入清单：预期document ID、版本、ACL版本和来源摘要。执行后产生published/quarantined/unchanged/deleted四类清单，集合互斥且并集等于输入及删除事件。数量不平衡使run失败。

### 21.1 暂存验证

新记录先写staging，运行模式、hash冲突、ACL完整、黄金质量和下游兼容检查。通过后原子切换active revision；失败保持旧版本。大批次可按文档幂等发布，但查询层需按run状态避免混合不一致版本。

### 21.2 可观测字段

指标：各阶段时长、字节/页/字符、成功/隔离、错误类型、重试、hash命中、ACL更新、删除延迟。日志带run/document安全标识和correlation ID，不含完整正文、签名URL或ACL成员名单。

### 21.3 恢复演练

模拟worker中断，从manifest检查点继续；相同文档不重复写；隔离项仍可追踪；发布切换只有一次。模拟索引全部删除，从规范语料重建；模拟规范语料删除，从授权快照和代码重建。未实际演练不能声称可恢复。

## 22. 从规范文档到下一阶段的交接

交给切块阶段的记录必须包含完整规范文本/结构、document ID、source URI/version、normalized hash、ACL及版本、parser/normalizer版本、语言/标题、页/段位置和状态。切块器不得重新猜来源或从另一张松散表补ACL。

定义交接不变量：只有published/complete记录可进入；每个chunk将引用父document ID与hash；父ACL完整复制或通过不可断开的引用继承；父撤回可找到全部子项；任何不同pipeline版本不会混在同一索引版本。

这一步仍不选择chunk大小或Embedding模型。清晰阶段边界避免“调检索效果”时顺手修改解析文本，却没有触发hash、版本和权限审计。

## 23. 摄取评审问题

1. 来源和版本如何唯一识别，能否回取？
2. 原始字节是否安全限制，解析器是否隔离？
3. 规范化哪些变换不可逆，版本如何记录？
4. raw/normalized hash分别计算什么字节？
5. ACL缺失、撤回和独立更新怎样传播？
6. 失败是否进入有阶段的隔离，而非静默？
7. 相同输入重跑是否幂等，冲突是否阻断？
8. 黄金集是否覆盖真实格式难点且经人工抽检？
9. 删除能否沿血缘清理所有派生物并防复活？
10. 发布失败能否继续使用上一可信版本并回滚？

## 24. 常见误区

- 解析器退出0就认为内容正确；
- `errors=ignore`吞解码字节；
- 全部空白压缩破坏结构；
- 只存文件名不存来源和版本；
- hash证明内容正确/可信；
- 同hash跨租户合并ACL；
- ACL缺失默认公开；
- 解析失败直接continue；
- 正文更新才触发权限同步，忽略ACL独立变更；
- 直接在摄取章切块/嵌入，无法定位阶段。

## 25. 自测与参考答案

1. **raw/normalized hash区别？** 原字节与规范文本摘要。
2. **hash能证明来源真实吗？** 不能，只比较字节一致性。
3. **ACL缺失怎么办？** 拒绝发布/隔离，不默认公开。
4. **PDF抽到文字就可信吗？** 不，需页/版面/OCR质量验证。
5. **同版本不同hash？** 冲突，隔离并查来源/管线。
6. **解析失败能跳过吗？** 不能静默；记录隔离与阶段。
7. **为什么保留parser版本？** 同原文不同版本可能产不同规范文本。
8. **source URI能直接展示吗？** 不一定，需权限和安全转换。
9. **语料是业务事实吗？** 是来源的可重建派生表示，原文/ACL仍权威。
10. **越界反例？** 选择chunk大小和Embedding模型，属于下一章。

## 26. 验收清单

- [ ] 能拆Loader/Parser/Normalizer/Validator/Writer/Quarantine。
- [ ] 能定义含来源、版本、hash、ACL和血缘的规范模式。
- [ ] 能说明Markdown/PDF/CSV解析特有风险。
- [ ] 能做不破坏结构的版本化规范化。
- [ ] 能区分raw/normalized hash并处理版本冲突。
- [ ] 能确保ACL随正文和下游派生物传播。
- [ ] 能保存可重试/永久错误的隔离记录。
- [ ] 能验证重摄取幂等和原子发布。
- [ ] 能用黄金夹具、失败注入和血缘审计。
- [ ] 能明确真实PDF/权限/生产平台未验证。

## 27. 版本与验证边界

来源、版本、hash、ACL、血缘、隔离和幂等是稳定合同；Python/pytest及具体解析器会变化。资产只验证Markdown/“PDF抽取文本”/CSV样式合成夹具，不声称 pandas 能力，也没有实际解析PDF字节、OCR、外部知识库、生产ACL或恶意文件沙箱。

资料链接复核日期：**2026-07-24**。

- [W3C PROV-O Recommendation](https://www.w3.org/TR/prov-o/)：核对 Entity、Activity、Agent 及派生/来源关系的标准化 provenance 语义；
- [NIST FIPS 180-4 Secure Hash Standard](https://csrc.nist.gov/pubs/fips/180-4/upd1/final)：核对 SHA 系列摘要算法的标准来源与“检测摘要生成后内容是否改变”的用途边界；
- [OWASP File Upload Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html)：核对外部文件的类型、大小、存储、权限与恶意内容防护清单。

哈希只能比较内容摘要，不能证明来源真实、解析正确、文件无害或访问已获授权；W3C provenance 模型也不会替应用自动执行租户 ACL。真实 PDF/OCR 与权限系统仍需单独测试。
