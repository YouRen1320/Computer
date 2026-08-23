# P9 AI 辅助预审：卷 13 ML/PyTorch、卷 14 LLM/RAG/Agents 与卷 15 Production/FactoryCare

- `actor_class=AI`
- `review_mode=read-only`
- `attestation_class=not-human-attestation`
- `dod_human_gate=OPEN`
- `review_date=2026-07-24`
- `scope=volume-13-ml-pytorch,volume-14-llm-rag-agents,volume-15-production-factorycare`

> 本记录是只读 AI 辅助预审，不是独立真人复核、真实学习者试读或人类 attestation。除创建本记录这一项经授权的记录写入外，预审过程没有修改教材、示例、练习、实验、私有答案、endpoint、manifest、attestation、release 或 `PROGRESS`。本记录不能关闭 Definition of Done 中的真人试读、独立人工复核、真实运行时、跨平台、无障碍、出版和来源支持性门槛，也不能把任何章节推进到 `review`、`verified` 或可公开发行状态。

## 1. 范围、方法与结论

范围为卷 13 的 16 章、卷 14 的 16 章和卷 15 的 17 章，共 49 章正文，以及每章公开 `examples`、`exercises`、`labs` 和只读对照的 `solutions-private` 接口。评审依据为 `records/encyclopedia/REVIEW-RUBRIC.md`、章节 outcomes/prerequisites、版本目录和 FactoryCare 事实所有权边界。

本次逐章阅读并检查：零基础前置是否闭合；定义、术语、边界和故障分类是否准确；正文、示例、练习、实验和私有参考是否对齐；公开练习能否从稳定红灯修到原验证绿色；安全、隐私、重试、取消、幂等、算法适用条件是否完整；Java、Python、客户端和运维面的 FactoryCare 所有权是否一致；版本敏感结论和已验证/未验证边界是否诚实。`clean` 只表示本轮 AI 阅读未形成可证实 finding，不表示通过真人复核或 DoD。

总体结论：发现 0 个 S0、3 个 S1、4 个 S2、3 个 S3。RAG 示例存在正文明确禁止的原始 query 遥测和不完整缓存身份，工具调用 Lab 的批准与幂等键未绑定载荷，RAG 评估指标又使用错误语义/分母。按 `REVIEW-RUBRIC.md:59-63` 的安全、正确性和已知问题披露要求，当前范围结论为 `FAIL`，不能关闭最终 P9 质量门。

## 2. 逐章结论索引

### 2.1 卷 13

| 章节 | AI 预审结果 |
|---|---|
| `ch.math.algebra-units` | clean |
| `ch.math.functions-graphs` | clean |
| `ch.math.gradients` | clean |
| `ch.math.linear-algebra` | clean |
| `ch.math.probability-statistics` | clean |
| `ch.ml.attention-sequences` | clean；真实模型质量仍是运行门 |
| `ch.ml.metrics-validation` | finding F01 |
| `ch.ml.monitoring-ethics` | clean；公平、隐私和组织治理仍是人工门 |
| `ch.ml.neural-networks` | clean |
| `ch.ml.preprocessing-features` | clean |
| `ch.ml.problem-data-split` | clean；真实标签与切分仍是数据门 |
| `ch.ml.supervised-learning` | finding F01 |
| `ch.ml.unsupervised-learning` | finding F01 |
| `ch.pytorch.foundations` | clean；GPU/MPS/CUDA 仍是运行门 |
| `ch.pytorch.inference` | clean；真实制品与服务运行仍是运行门 |
| `ch.pytorch.training` | finding F06；GPU/分布式/任意中断续训仍是运行门 |

### 2.2 卷 14

| 章节 | AI 预审结果 |
|---|---|
| `ch.agent.langchain` | clean；真实 provider 与版本升级仍是运行门 |
| `ch.agent.langgraph` | clean；持久 checkpointer 与恢复仍是运行门 |
| `ch.agent.mcp-boundaries` | clean；真实 stdio/HTTP/OAuth/TLS 与 Java 工具仍是运行门 |
| `ch.ir.dense-pgvector` | clean；真实 PostgreSQL/pgvector、ANN 与 `EXPLAIN` 仍是运行门 |
| `ch.ir.evaluation` | clean；真实语料标注和统计功效仍是人工/数据门 |
| `ch.ir.hybrid-rerank` | clean；真实重排模型与延迟仍是运行门 |
| `ch.ir.lexical-retrieval` | clean |
| `ch.llm.api-prompts-cost` | finding F01、F05、F08；真实 API/价格/usage 仍是运行门 |
| `ch.llm.model-foundations` | clean |
| `ch.llm.streaming-resilience` | finding F01；真实流式协议、代理和取消仍是运行门 |
| `ch.llm.structured-output` | finding F01；真实模型遵循率仍是运行门 |
| `ch.llm.tool-calling` | finding F01、F03；真实 Java 事务/审批仍是运行门 |
| `ch.rag.chunking-embeddings` | clean；真实 embedding/语料/召回仍是运行门 |
| `ch.rag.citations-evaluation` | finding F04 |
| `ch.rag.ingestion-metadata` | finding F10；真实 PDF/OCR/ACL/恶意文件仍是运行门 |
| `ch.rag.security-observability` | finding F02；真实跨租户、RLS、红队和事件响应仍是运行门 |

### 2.3 卷 15

| 章节 | AI 预审结果 |
|---|---|
| `ch.architecture.system-design` | clean；容量假设与架构评审仍是人工门 |
| `ch.ops.backup-recovery` | clean；真实 PostgreSQL restore/PITR 演练仍是运行门 |
| `ch.ops.capacity-performance` | clean；真实负载、瓶颈与容量模型仍是运行门 |
| `ch.ops.compose-services` | finding F01；Docker daemon 冷启动/网络/卷仍是运行门 |
| `ch.ops.config-secrets-supply-chain` | finding F01；真实 secret manager、扫描、SBOM/provenance 仍是运行门 |
| `ch.ops.docker-production` | finding F01；真实 build、digest、PID 1、只读根和 volume 仍是运行门 |
| `ch.ops.incident-dr` | clean；真实事故和灾备演练仍是人工/运行门 |
| `ch.ops.linux-services` | clean；目标 Ubuntu/systemd/权限仍是运行门 |
| `ch.ops.logs-health` | finding F01；真实 Java/Nginx/DB 链路仍是运行门 |
| `ch.ops.metrics-traces-slo` | finding F01、F09；真实 Prometheus/Alertmanager 仍是运行门 |
| `ch.ops.network-diagnostics` | finding F07；真实 DNS/TLS/代理路径仍是运行门 |
| `ch.ops.nginx-tls` | finding F01；目标 Nginx、证书链和外部 smoke 仍是运行门 |
| `ch.portfolio.interview` | clean；履历真实性与人工面试仍是人类门 |
| `ch.release.artifacts-promotion` | clean；真实 registry、签名、晋级和回滚仍是运行门 |
| `ch.release.ci-quality` | clean；真实 CI provider 与分支保护仍是运行门 |
| `ch.release.deployment-migrations` | clean；真实环境迁移、灰度与回滚仍是运行门 |
| `ch.release.factorycare-acceptance` | clean；三客户端、Java、数据、AI 与运维端到端验收仍全部开放 |

## 3. 有证据的 findings

### F01 — S2：13 个公开练习的原验证器只能固定红，无法完成“修复后重跑原验证”

证据：

- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.ml.metrics-validation/verify.sh:4-61`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.ml.supervised-learning/verify.sh:4-67`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.ml.unsupervised-learning/verify.sh:4-62`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.llm.api-prompts-cost/verify.sh:4-9`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.llm.streaming-resilience/verify.sh:4-9`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.llm.structured-output/verify.sh:4-9`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.llm.tool-calling/verify.sh:4-9`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.ops.compose-services/verify.sh:4-9`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.ops.config-secrets-supply-chain/verify.sh:4-13`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.ops.docker-production/verify.sh:4-9`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.ops.logs-health/verify.sh:4-13`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.ops.metrics-traces-slo/verify.sh:4-13`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.ops.nginx-tls/verify.sh:4-9`
- `/Users/youren/Desktop/Study/Computer/book/volume-13-ml-pytorch/chapters/ch.ml.metrics-validation.md:377-394`
- `/Users/youren/Desktop/Study/Computer/book/volume-14-llm-rag-agents/chapters/ch.llm.streaming-resilience.md:356-364`
- `/Users/youren/Desktop/Study/Computer/book/volume-14-llm-rag-agents/chapters/ch.llm.structured-output.md:352-360`
- `/Users/youren/Desktop/Study/Computer/book/volume-14-llm-rag-agents/chapters/ch.llm.tool-calling.md:378-386`
- `/Users/youren/Desktop/Study/Computer/book/volume-15-production-factorycare/chapters/ch.ops.compose-services.md:359-365`
- `/Users/youren/Desktop/Study/Computer/book/volume-15-production-factorycare/chapters/ch.ops.logs-health.md:368-372`

三项 ML 练习把错误输入直接写在 verifier 的 heredoc 中，目录里没有可编辑 starter；其余十项虽然有测试或可编辑源，但测试一旦变绿，verifier 反而进入 `UNEXPECTED_GREEN` 并返回 1/42，失败时固定返回 41。正文同时要求修复并重跑原测试/原验证，因此 failure-log-fix-rerun outcome 不可达。

建议：把故障实现移到可编辑 starter；checker 精确识别 starter 的预期红灯并返回 41，完成实现通过所有 acceptance 时返回 0 和 `EXERCISE_GREEN`，错误失败形状返回其他非零码。私有答案继续独立验证，不作为公开 checker 永远红的替代。

### F02 — S1：RAG 安全示例把完整 query 写入 trace，缓存身份也缺少正文要求的版本边界

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-14-llm-rag-agents/chapters/ch.rag.security-observability.md:179-205`
- `/Users/youren/Desktop/Study/Computer/book/volume-14-llm-rag-agents/chapters/ch.rag.security-observability.md:227-237`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.rag.security-observability/secure_rag.py:27-46`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.rag.security-observability/secure_rag.py:62-83`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.rag.security-observability/test_secure_rag.py:34-53`

正文明确说明自由文本可能含 PII、密钥和医疗信息，默认遥测应保存长度/哈希而非全文；示例却把 `query=query` 交给通用 `Trace.emit`。`redact()` 只覆盖邮箱和中国大陆手机号，任意姓名、地址、身份证、精确位置、医疗信息或其他 secret 会原样进入 trace。缓存键只绑定 tenant、subject、roles、query，遗漏正文要求的权限版本/资源集合、索引版本和模型/提示版本，权限或索引变化后可能复用陈旧结果。

建议：trace 使用事件级字段 allowlist，query 只记录受控摘要、长度和分类，不让任意 `**attributes` 自动变成日志；缓存键绑定权限版本、可见资源/策略版本、索引版本和模型/提示版本，或实现可证明的主动失效。增加非正则 PII、canary secret、权限撤销和索引升级回归。

### F03 — S1：工具调用 Lab 的 approval 和 idempotency 没有绑定载荷

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-14-llm-rag-agents/chapters/ch.llm.tool-calling.md:203-221`
- `/Users/youren/Desktop/Study/Computer/book/volume-14-llm-rag-agents/chapters/ch.llm.tool-calling.md:233-249`
- `/Users/youren/Desktop/Study/Computer/book/volume-14-llm-rag-agents/chapters/ch.llm.tool-calling.md:378-399`
- `/Users/youren/Desktop/Study/Computer/labs/encyclopedia/ch.llm.tool-calling/test_lab.py:19-37`
- `/Users/youren/Desktop/Study/Computer/labs/encyclopedia/ch.llm.tool-calling/test_lab.py:40-75`
- `/Users/youren/Desktop/Study/Computer/labs/encyclopedia/ch.llm.tool-calling/test_lab.py:95-103`

Lab 只用 `approved_call_ids` 判断批准，未绑定 principal、tool、严格参数、资源版本或过期时间；同一 call ID 的参数改变后仍可消费旧批准。Repository fixture 遇到已存在幂等键时直接返回旧 receipt，不比较 order/resolution；同一 key 配不同载荷不会返回正文定义的 `idempotency_conflict`。现有测试只覆盖相同载荷重放，正文反而把“同 key 不同 resolution”留作学习者自己补的测试。

建议：approval reference 保存并验证 principal、tool、规范化参数摘要、资源版本、目的和 expiry；幂等记录保存请求摘要并在 key 相同、摘要不同的情况下稳定拒绝。增加逐字段变更、过期批准、状态版本变化和同 key 不同 resolution 的 handler 调用次数断言。

### F04 — S1：RAG 评估示例的 retrieval/citation 指标语义与分母错误

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-14-llm-rag-agents/chapters/ch.rag.citations-evaluation.md:203-236`
- `/Users/youren/Desktop/Study/Computer/book/volume-14-llm-rag-agents/chapters/ch.rag.citations-evaluation.md:246-250`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.rag.citations-evaluation/grounded_rag.py:60-93`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.rag.citations-evaluation/grounded_rag.py:96-147`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.rag.citations-evaluation/test_grounded_rag.py:34-47`

正文把 `retrieval_hit` 定义为“相关来源进入 eligible candidate set”，代码却只要存在任意 active 来源就加一，既没有相关性标注，也没有使用 question。`citation_validity` 把所有 `audit_answer()` 无失败的案例计入分子，并除以全部案例；非回答状态没有引用时也被算作 citation valid，违反正文“实际回答上的 citation precision”分母。生成器还忽略 question，并对所有 active 来源的不同 `fact_value` 判冲突，没有先限定同一 `fact_key`。测试把这套结果断言为 1.0，掩盖了指标语义错误。

建议：回归案例显式保存 relevant source/fact judgments；检索命中按相关来源计算；引用结构有效、引用蕴含和引用 precision 分开，并以 answered/cited case 或 citation 为明确分母；拒答指标使用不可回答集合。增加“active 但不相关”“不同 fact_key 的不同值”“非回答无引用”和“回答无有效引用”回归。

### F05 — S2：Token usage 的正文不变量没有进入成本示例和 Lab

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-14-llm-rag-agents/chapters/ch.llm.api-prompts-cost.md:158-174`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.llm.api-prompts-cost/demo.py:5-20`
- `/Users/youren/Desktop/Study/Computer/labs/encyclopedia/ch.llm.api-prompts-cost/test_lab.py:14-21`
- `/Users/youren/Desktop/Study/Computer/labs/encyclopedia/ch.llm.api-prompts-cost/test_lab.py:40-60`
- `/Users/youren/Desktop/Study/Computer/labs/encyclopedia/ch.llm.api-prompts-cost/test_lab.py:63-80`

正文要求 usage 非负、cached 不超过 input，并在供应商定义允许时检查 total 一致性；示例和 Lab 直接做 `input-cached_input`。负 Token 或 cached 大于 input 会产生负的 uncached/cost，而现有测试只有正常值与 provider error。

建议：在不可变 Usage 边界统一验证非负、`cached <= input`、供应商 total 关系和费率字段/非负性；非法 provider usage 应进入独立错误而不是账单。加入所有边界和极端大整数回归。

### F06 — S2：PyTorch 训练 verification metadata 声称 checkpoint resume，资产只验证最佳权重恢复

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-13-ml-pytorch/chapters/ch.pytorch.training.md:50-64`
- `/Users/youren/Desktop/Study/Computer/book/volume-13-ml-pytorch/chapters/ch.pytorch.training.md:233-248`
- `/Users/youren/Desktop/Study/Computer/book/volume-13-ml-pytorch/chapters/ch.pytorch.training.md:336-350`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.pytorch.training/training.py:101-160`
- `/Users/youren/Desktop/Study/Computer/labs/encyclopedia/ch.pytorch.training/oracle.py:56-75`

机器可读 `verification_mode` 是 `...checkpoint-resume`，但正文诚实说明只验证“从头同种子复跑”和“加载最佳模型评估”，不宣称任意中断续训。示例保存 optimizer state 却从未恢复 optimizer 或继续一个训练 step；Lab 只检查必需键。机器元数据因而强于实际证据。

建议：若当前目标只是最佳检查点 round trip，把 mode 改成 `...best-checkpoint-roundtrip`；若要保留 resume，则在安全边界保存/恢复 optimizer、scheduler、随机状态、sampler/step 和 early-stop 状态，并比较 uninterrupted 与 resumed 轨迹，同时继续明确任意 batch 的限制。

### F07 — S3：网络健康探针把 3xx 重定向算作成功

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-15-production-factorycare/chapters/ch.ops.network-diagnostics.md:234-250`
- `/Users/youren/Desktop/Study/Computer/book/volume-15-production-factorycare/chapters/ch.ops.network-diagnostics.md:296-302`
- `/Users/youren/Desktop/Study/Computer/labs/encyclopedia/ch.ops.network-diagnostics/local_probe.py:17-43`
- `/Users/youren/Desktop/Study/Computer/labs/encyclopedia/ch.ops.network-diagnostics/test_local_probe.py:8-40`

正文区分 2xx 成功与 3xx 重定向，并提醒转发头错误可造成重定向循环；Lab 的 `/health` 探针却以 `200 <= status < 400` 设置 `ok=true`，测试只覆盖 204 与 503。健康地址跳到登录、错误 host 或循环重定向时会被误报健康。

建议：健康合同默认只接受约定的 2xx（必要时精确到 200/204），3xx 返回独立分类并保留 Location 的安全摘要。增加 301、跨 host、循环和缺 Location 回归。

### F08 — S3：公开练习使用 provider-key 外观的 secret，直接违背本章测试规则

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-14-llm-rag-agents/chapters/ch.llm.api-prompts-cost.md:120-128`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.llm.api-prompts-cost/test_exercise.py:1-13`

正文明确说形似真实 key 的字符串会触发扫描器，因此 fixture 应使用明显的 test-only 文本；公开练习却包含 `sk-hard-coded-example`。虽然它不是有效凭据，仍可能触发宽泛 secret scanner，并把 provider 前缀硬编码进公开教学资产。

建议：用不含真实 provider 前缀的明显测试常量或 AST 规则表达“源码中出现凭据赋值”的故障；scanner fixture 若必须测试格式，应在隔离、不可误用的测试数据格式中生成，并明确 allowlist 理由。

### F09 — S2：SLO 最小模型未定义零流量，却宣称覆盖该验证场景

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-15-production-factorycare/chapters/ch.ops.metrics-traces-slo.md:234-253`
- `/Users/youren/Desktop/Study/Computer/book/volume-15-production-factorycare/chapters/ch.ops.metrics-traces-slo.md:548-566`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.ops.metrics-traces-slo/reliability.py:15-36`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.ops.metrics-traces-slo/test_reliability.py:12-23`

`availability_sli()` 会拒绝无效分母，`burn_rate()` 却不校验 total/bad，零流量直接触发 `ZeroDivisionError`，负数或 `bad > total` 也可产生无意义结果。正文要求合成规则验证“零流量”和遥测缺失，并称 fixture 是这类测试的最小模型；现有测试没有该边界。

建议：为事件计数建立共用不变量；把 zero-traffic/no-data 建模为显式状态而非浮点数或偶发异常，再由告警策略决定“不 page、保持 pending 或 telemetry alert”。增加零流量、坏数超总数、负数和窗口缺数据矩阵。

### F10 — S3：RAG 摄取元数据声明 pandas 能力与版本表面，但正文和资产没有使用它

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-14-llm-rag-agents/chapters/ch.rag.ingestion-metadata.md:12-25`
- `/Users/youren/Desktop/Study/Computer/book/volume-14-llm-rag-agents/chapters/ch.rag.ingestion-metadata.md:38-50`
- `/Users/youren/Desktop/Study/Computer/book/volume-14-llm-rag-agents/chapters/ch.rag.ingestion-metadata.md:438-449`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.rag.ingestion-metadata/verify.sh:1-5`
- `/Users/youren/Desktop/Study/Computer/labs/encyclopedia/ch.rag.ingestion-metadata/verify.sh:1-5`

frontmatter 声明 `version_surfaces: pandas` 和 `uses_capabilities: data.numpy-pandas`，但 prerequisites 没有 pandas 章，正文与四类工件只是标准库式 Markdown/PDF-text/CSV 合成夹具；验证器只安装 pytest。该元数据会让前置图、版本审计和能力覆盖产生假阳性。

建议：若不需要 pandas，删除该版本表面和能力；若该能力是教学目标，则显式加入 `ch.data.pandas` 前置、受控 CSV/DataFrame 边界和锁定 pandas 验证，不要只靠文件格式名称宣称能力。

## 4. 额外静态检查

- 只读统计 49 章：卷 13 为 16 章，卷 14 为 16 章，卷 15 为 17 章。
- 49 章均存在同 ID 的 `examples`、`exercises`、`labs` 和 `solutions-private` 目录；目录存在不代表内容已通过。
- 只读解析 49 章中的 95 个相对链接，未发现断链。
- 章节总体能区分稳定核心、版本表面和本地 fixture 限制；LangChain/LangGraph/MCP、OpenAI、pgvector、PyTorch、Docker/Nginx/发布等真实能力普遍标为未验证，没有因文档存在而直接宣称生产验证。
- FactoryCare 所有权总体一致：Java 拥有工单、设备、主体、授权、状态机和事务；Python 负责 ML/RAG/Agent 派生建议和协议编排；客户端经 Java API 使用。F03 是这一边界在 Lab 中未完整落实的例外。
- 本预审没有把共享脏工作树中的其他更改归于本任务，也没有重新运行会下载依赖、创建缓存、启动 daemon/服务或改写证据的全量 endpoint。因此本记录不输出任何“49 章运行通过”声明。
- 来源链接存在性不等于来源逐条支持正文；版权、引用额度和版本当天有效性仍需真人复核。

## 5. 仍需真人或真实环境完成的门

以下门保持开放，本记录不能关闭：

- 真正编程零基础读者按当前 prerequisites 完成预测、运行、修改、独立实现和故障诊断；记录卡点、提示、用时和修订后复测。
- 独立真人逐章复核技术正确性、教学连续性、来源逐条支持关系、术语和跨章一致性。
- PyTorch 的真实 CPU/GPU/MPS/CUDA、数据加载、混合精度、分布式、制品兼容、恢复与线上推理。
- 真实 OpenAI/其他模型 API 的认证、流式事件、usage、价格、限流、取消、结构化输出、工具调用和模型质量；必须有授权、预算、脱敏和 kill switch。
- 真实 PostgreSQL/pgvector 的隔离、RLS、exact/ANN、过滤计划、`EXPLAIN`、索引迁移、备份和恢复。
- LangChain/LangGraph 的真实 provider、持久 checkpointer、并发恢复；MCP 的 stdio/HTTP/OAuth/TLS、能力协商和真实 Java 工具。
- RAG 的真实 PDF/OCR、恶意文件沙箱、ACL 撤销、跨租户红队、缓存失效、语义引用审计、评估标注与 PII 政策。
- Docker/Compose/Nginx/TLS/systemd/Ubuntu 的真实构建、启动、网络、卷、健康、PID 1、只读文件系统、证书链和代理 smoke。
- 真实 Prometheus/OpenTelemetry/Alertmanager 的 staleness、零流量、采样、基数、trace continuity、告警检测/恢复和 runbook 演练。
- 真实 CI、分支保护、registry digest、SBOM、provenance、签名、审批、制品晋级、数据库迁移、灰度、回滚、事故和灾备演练。
- Vue、uni-app、Flutter 三客户端与 Java/Python/数据/运维面的 FactoryCare 端到端验收；包含网络失败、离线、权限、并发、幂等和可访问性。
- 键盘、焦点、屏幕阅读器、对比度、减少动画、移动设备和多阅读器人工 QA。
- HTML/EPUB/PDF 正式构建、分页、代码块、链接、书签、阅读顺序、字体和跨阅读器验证。
- 履历与项目证据真实性、个人信息脱敏、来源版权和出版编辑复核。

## 6. 记录边界

本文件只保存 AI 预审发现，不能作为：

- 独立真人复核记录；
- 人类 attestation；
- 真实学习者试读证据；
- 运行验证 manifest 或 endpoint 通过证明；
- 真实服务、硬件、平台、模型或版本兼容证明；
- release approval；
- 章节状态晋升依据；
- Definition of Done 关闭依据；
- `PROGRESS` 更新依据。

任何 findings 修复后，仍须由不依赖本 AI 结论的真人和真实环境重新验证受影响章节、相邻章节与公共端点。若只修 verifier 而不复测 starter 红灯、完成实现绿灯和错误失败形状，也不能关闭 F01。
