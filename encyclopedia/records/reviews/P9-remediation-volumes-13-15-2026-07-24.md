# P9 AI 辅助修复记录：卷 13–15

- `actor_class=AI`
- `review_mode=remediation-and-focused-verification`
- `attestation_class=not-human-attestation`
- `dod_human_gate=OPEN`
- `remediation_date=2026-07-24`
- `scope=volume-13-ml-pytorch,volume-14-llm-rag-agents,volume-15-production-factorycare`
- `source_review=P9-AI-pre-review-volumes-13-15-2026-07-24.md`

> 本记录说明 AI 对预审 F01–F10 所做的修复和聚焦验证。它不是独立真人复核、真实学习者试读、真实生产环境验证、人类 attestation 或 release approval，不能关闭 Definition of Done 中的人工与真实环境门，也不能据此更新 `PROGRESS` 或晋升章节状态。

## 1. 修复结论

预审记录中的 3 个 S1、4 个 S2 和 3 个 S3 均已在正文、公开资产、实验或机器可读课程源中得到对应修复。13 个原本只能固定返回红灯的公开练习现已形成三态合同：

- 未修改的精确 starter 运行失败：返回 `41` 与 `EXPECTED_RED`；
- 学习者完成实现并通过原公开测试：返回 `0` 与 `EXERCISE_GREEN`；
- starter 被部分修改但仍失败、测试 oracle 被改写、语法/收集失败或基础设施失败：返回 `43`，不会伪装成预期红灯。

所有私有参考答案继续位于 `solutions-private/`，公开 checker 不导入、不复制也不比较私有答案源码。公开测试验证行为，SHA-256 只用于识别精确 starter 与保护公开测试 oracle。

## 2. Finding 对应修复

| Finding | 严重度 | 修复结果 | 主要工件 |
|---|---:|---|---|
| F01 | S2 | 13 个公开练习改为可编辑 starter + 行为测试 + 三态 checker；补齐 README、私有解和独立私有测试 | `exercises/encyclopedia/ch.ml.*`、`ch.llm.*`、`ch.ops.*` 对应 13 目录；`solutions-private/encyclopedia/` 对应目录；相关章节 |
| F02 | S1 | trace 改为事件级字段 allowlist；query 只记录长度、SHA-256 与有限分类；缓存身份绑定主体、租户、角色、权限版本、可见资源集合摘要、索引、模型和提示版本 | `examples/encyclopedia/ch.rag.security-observability/secure_rag.py`、测试、Lab audit、章节 |
| F03 | S1 | approval 绑定 principal、tool、规范化参数摘要、资源版本、purpose、expiry；幂等记录绑定请求摘要和原 receipt，同 key 异载荷稳定返回冲突 | `labs/encyclopedia/ch.llm.tool-calling/test_lab.py`、`verify.sh`、章节和公开练习 |
| F04 | S1 | 回归案例显式记录 relevant source；检索命中按相关且 active 的来源计算；不同 fact key 不制造冲突；回答、拒答、引用结构和 citation precision 使用各自明确分母 | `examples/encyclopedia/ch.rag.citations-evaluation/grounded_rag.py`、测试、README 和章节 |
| F05 | S2 | Usage 统一校验非负整数、`cached <= input`、可选 total 一致性；费率键、有限性与非负性受检；非法 provider usage 进入独立错误通道 | `examples/encyclopedia/ch.llm.api-prompts-cost/`、`labs/encyclopedia/ch.llm.api-prompts-cost/`、章节和练习 |
| F06 | S2 | 不再把“最佳检查点加载并复测”写成任意中断续训；机器元数据和正文统一为 `best-checkpoint-roundtrip` | `curriculum/chapters/volume-13.yml`、`book/volume-13-ml-pytorch/chapters/ch.pytorch.training.md` |
| F07 | S3 | 健康合同只接受 2xx；3xx 被分类为 redirect、跨 host、循环或缺 Location，且不泄露原始 Location | `labs/encyclopedia/ch.ops.network-diagnostics/local_probe.py`、测试和章节 |
| F08 | S3 | 公开练习移除 provider-key 外观的硬编码 fixture；测试通过构造方式检查危险前缀，不把该前缀直接写进公开资产 | `exercises/encyclopedia/ch.llm.api-prompts-cost/test_exercise.py`、README 和章节 |
| F09 | S2 | 建立统一事件计数不变量；零流量与遥测缺失成为显式状态，告警决策分别为 pending 或 telemetry alert | `examples/encyclopedia/ch.ops.metrics-traces-slo/reliability.py`、测试和章节 |
| F10 | S3 | 从摄取章节的课程源和 frontmatter 删除未被实际使用的 pandas capability/version surface；保留真实 Python/pytest 边界 | `curriculum/chapters/volume-14.yml`、`book/volume-14-llm-rag-agents/chapters/ch.rag.ingestion-metadata.md` |

## 3. 公开练习三态证据

验证方法：直接运行仓库 starter；在临时副本中只用对应私有 `solution.py`/`audit.py` 替换可编辑文件后运行同一个公开 `verify.sh`；另在临时副本中分别制造“只改注释但测试仍失败”和“无效 Python”两类非精确 starter。临时副本不回写公开目录。

| 章节 | 完成解公开测试数 | 精确 starter | 完成解 | 部分修改仍失败 | 未知/语法失败 | 私有验证 |
|---|---:|---:|---:|---:|---:|---:|
| `ch.ml.metrics-validation` | 3 | 41 | 0 | 43 | 43 | 0 |
| `ch.ml.supervised-learning` | 4 | 41 | 0 | 43 | 43 | 0 |
| `ch.ml.unsupervised-learning` | 4 | 41 | 0 | 43 | 43 | 0 |
| `ch.llm.api-prompts-cost` | 6 | 41 | 0 | 43 | 43 | 0 |
| `ch.llm.streaming-resilience` | 3 | 41 | 0 | 43 | 43 | 0 |
| `ch.llm.structured-output` | 6 | 41 | 0 | 43 | 43 | 0 |
| `ch.llm.tool-calling` | 3 | 41 | 0 | 43 | 43 | 0 |
| `ch.ops.compose-services` | 2 | 41 | 0 | 43 | 43 | 0 |
| `ch.ops.config-secrets-supply-chain` | 3 | 41 | 0 | 43 | 43 | 0 |
| `ch.ops.docker-production` | 2 | 41 | 0 | 43 | 43 | 0 |
| `ch.ops.logs-health` | 3 | 41 | 0 | 43 | 43 | 0 |
| `ch.ops.metrics-traces-slo` | 1 | 41 | 0 | 43 | 43 | 0 |
| `ch.ops.nginx-tls` | 2 | 41 | 0 | 43 | 43 | 0 |

补充检查：

- 13 个公开 checker 中保存的 starter SHA-256 与当前可编辑 starter 全部精确匹配；测试 oracle SHA-256 与当前公开测试全部精确匹配。
- 13 个公开 `verify.sh` 和 13 个私有 `verify.sh` 均可执行；公开脚本全部通过 `bash -n`。
- 对公开 13 目录搜索 `solutions-private`、`SOLUTION_GREEN`、`TO_FILL` 和 `REPLACE_ME` 无命中，没有私有答案路径或占位答案泄漏。
- API 练习重新修改测试 oracle 后单独复测：starter=`41`、完成解=`0`、部分修改=`43`、语法/收集失败=`43`。

## 4. 聚焦运行验证

以下结果在本地 macOS arm64 环境于 2026-07-24 实际运行；它们只证明对应 fixture/test 合同，不外推到真实 provider、集群或生产环境。

| 工件 | 结果 |
|---|---|
| PyTorch training example | `PASS`；同 seed 状态精确、测试集只读一次、30 epochs |
| PyTorch training Lab | `PASS`；mode、validation-grad、test reuse、incomplete checkpoint 故障被覆盖 |
| RAG security example | 4 tests passed |
| RAG security Lab | 4 tests passed |
| Tool calling Lab | 5 tests passed；approval payload binding 与 idempotency conflict 被覆盖 |
| RAG citations/evaluation example | 4 tests passed |
| LLM API/usage example | `EXAMPLE_GREEN` |
| LLM API/usage Lab | 8 tests passed |
| Network diagnostics Lab | 3 tests passed |
| Metrics/traces/SLO example | 6 tests passed |
| RAG ingestion example | 1 test passed |
| RAG ingestion Lab | 2 tests passed |

静态与课程源验证：

- `git diff --check` 通过。
- 定向扫描未发现旧的 provider-key fixture、原始 query trace 赋值或 `checkpoint-resume` 元数据。
- `ruby scripts/generate-curriculum.rb --plan` 成功解析 `255` 章、`16` 卷、`94` capabilities 和 `48` modules，没有课程源结构错误。
- 该 plan 显示 `curriculum/catalog.yml`、`concept-graph.md`、`gates.yml` 与四条 route 需要由总集成步骤统一重建；本修复按任务边界没有直接改写这些派生文件。
- `PROGRESS.md` 无本任务差异；manifest、DoD、attestation 与 release 记录未修改。

## 5. 仍然开放的边界

本轮刻意没有完成、也没有宣称完成：

- 独立真人逐章审校与真正零基础学习者试读；
- 真实 OpenAI/其他 provider 的认证、usage、价格、流式与工具调用；
- 真实 PDF/OCR、PostgreSQL/pgvector、ACL/RLS、跨租户红队和缓存主动失效；
- GPU/MPS/CUDA、任意 batch 中断续训、分布式训练和真实模型质量；
- Docker daemon、Compose 网络/卷、Nginx/TLS、Prometheus/OpenTelemetry/Alertmanager 与生产发布；
- 跨平台、无障碍、正式 HTML/EPUB/PDF 出版和来源逐条支持性复核；
- `PROGRESS`、verification manifest、attestation、release approval 或章节状态晋升。

因此，F01–F10 的代码/教材修复与聚焦回归已完成，但 P9 的真人和真实环境质量门仍保持 `OPEN`。
