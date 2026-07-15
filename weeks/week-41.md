# 第 41 周：文档管线、pgvector、混合检索与带引用RAG

## 本周定位

本周实现RAG的数据和检索基础。重点不是“把PDF塞进向量库”，而是文档版本、解析质量、租户ACL、可重建索引、混合检索、引用和撤回。

## 前置条件

- 模型adapter和流式协议通过；
- PostgreSQL 18、pgvector和对象存储可用；
- Java知识模块已有文档发布/撤回元数据与事件；
- 准备合法使用的设备手册和自建知识文档。

## 本周目标

- 建立异步、幂等、可重试的文档入库管线；
- 理解解析、OCR、清洗、切块和元数据；
- 使用PostgreSQL全文与pgvector进行混合检索；
- 理解HNSW/IVFFlat、精确/近似搜索和过滤影响；
- 在检索阶段执行tenant、ACL和发布状态过滤；
- 输出可点击、可验证的引用；
- 支持版本更新、撤回和索引重建。

## 必须理解的概念

- RAG解决的范围与不能解决的问题；
- 原文件、解析文本、chunk、embedding、索引都是不同层；
- PDF文本层、扫描PDF/OCR、表格、图片和页码映射；
- normalization、去页眉页脚、编码和重复内容；
- 固定长度、语义、结构/标题切块及overlap代价；
- embedding维度、距离函数、归一化和模型版本；
- exact search、HNSW、IVFFlat的速度/召回/内存/构建取舍；
- metadata filter和近似索引过滤后召回问题；
- PostgreSQL全文检索、向量检索、hybrid和RRF概念；
- reranker与生成模型职责不同；
- tenant/ACL/doc status必须进入检索查询；
- source URI、document/page/section/chunk定位；
- parent-child retrieval和上下文扩展概念；
- 索引是派生数据，原文/元数据才是可重建来源；
- 文档更新、撤回、删除、embedding迁移和双索引切换。

## 时间与任务（15—18小时）

下方120分钟无AI训练计入任务5的发布/撤回链路，不在总时长之外重复增加。

### 任务1：数据和schema（2小时）

- 设计`source_document/source_version/chunk/index_version`；
- 每个chunk保存tenant、ACL、发布状态、文档/版本、页码/章节、内容哈希和embedding版本；
- Python数据库角色只写`ai` schema；
- Flyway或受控迁移创建扩展与表；
- 建立唯一约束保证重复事件幂等。

### 任务2：解析与切块（4小时）

- 至少处理文本PDF、DOCX和CSV各一种；
- 扫描PDF只做OCR概念或一个小样，不追求复杂版面识别；
- 保存页码/章节映射；
- 比较两种切块策略和overlap；
- 对空页、表格错乱、重复页眉和超大文件记录失败；
- 原文件存对象存储，解析结果带版本和哈希。

### 任务3：Embedding和索引（3小时）

- 批量embedding，处理限流、部分失败和断点；
- 记录模型、维度和归一化；
- 小数据先做精确搜索，再添加HNSW或适合索引；
- 用`EXPLAIN`观察查询；
- 设计重建命令和新旧索引版本切换。

### 任务4：混合检索与引用（3—4小时）

- 构建全文和向量候选；
- 使用简单RRF或显式权重融合；
- 加metadata/tenant/ACL/doc status过滤；
- 可选加入rerank；
- 返回citation ID、标题、版本、页/章节和片段；
- 生成回答时只能引用检索结果，证据不足返回无答案。

### 任务5：发布/撤回链路（2小时）

- 消费`KnowledgeDocumentPublished.v1`幂等入库；
- 同一事件重复不会重复chunk；
- 新版本与旧版本状态清楚；
- 撤回事件使其立即不可检索，再异步清理；
- 测试跨租户、未发布和撤回文档。

### 任务6：初始评估（1小时）

- 建立至少30条query→相关source标注；
- 测量候选命中、引用和无答案；
- 保存失败样例，为Week 42优化。

## FactoryCare项目增量

- 知识文档入库worker；
- `ai` schema和pgvector；
- 文档解析/切块/embedding/index版本；
- 混合检索和引用API；
- 发布、更新、撤回链路；
- 初始30条评估集。
- Vue诊断面板展示可点击引用、无答案与文档版本，仍只通过Java公共API访问。

## AI协作边界

AI可以建议切块和测试query，但不能自动把生成问题当作独立真实评估。必须人工检查解析文本、引用页码、ACL查询和SQL。不要把所有文档全文发送给模型“让它自己找”。

## 无AI训练（120分钟）

新增文档撤回：从Java事件到Python索引不可见，重复事件幂等；补跨租户和旧版本不可检索测试，并解释为什么先标记不可见再异步删除。

## 求职动作（恢复求职后启用）

- 准备白板讲解“文档→chunk→embedding→hybrid retrieve→rerank→generation→citation”；
- 模拟回答：向量库是不是数据库事实源；为什么需要全文检索；切块越小是否越好；如何删除用户文档；
- R4简历开始写“带ACL和引用的RAG”，附实际评估数量。

## 交付物

- [ ] `ai` schema和迁移；
- [ ] 三类文档解析记录；
- [ ] 两种切块对比；
- [ ] embedding/index版本和重建命令；
- [ ] hybrid检索、ACL和citation；
- [ ] 发布/撤回幂等测试；
- [ ] 30条初始评估和失败集。

## 验收标准

- 跨租户、未发布和撤回文档零召回；
- 引用能定位原文页/章节；
- 解析和embedding部分失败可重试；
- 索引可以从原文/元数据重建；
- 能解释HNSW/IVFFlat而不要求调优到专家；
- Python不读取/写入未授权core表。

## 本周明确不做

- 一开始引入独立向量数据库；
- 复杂OCR/版面模型训练；
- 用聊天体验替代检索评估；
- 索引未发布或跨租户内容；
- 让向量索引成为唯一文档存储。

## 官方资料

- [pgvector](https://github.com/pgvector/pgvector)
- [PostgreSQL full text search](https://www.postgresql.org/docs/current/textsearch.html)
- [Spring AI ETL concepts](https://docs.spring.io/spring-ai/reference/api/etl-pipeline.html)
- 使用所选解析库的官方文档并记录许可证。
