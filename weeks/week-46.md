# 第 46 周：可观测、备份恢复、性能、安全与故障演练

## 定位

Week 45 已建立 Linux、镜像、Compose、Nginx/TLS 和 CI/CD。本周证明系统发生故障时能被发现、定位、降级和恢复：建立日志/指标/trace，完成备份恢复、安全检查、性能基线和八类故障演练，形成 G7 生产化证据。

时间预算：15—18 小时。不新增业务功能，不用漂亮监控面板替代恢复验证。

## 前置

- 测试环境可重复部署和回滚；
- 服务、数据库、Redis、对象存储和 Nginx 的日志/健康入口可访问；
- 有无敏感数据的可重置演示环境；
- 备份目标、保留、RPO/RTO 初始假设和故障清单已写明；
- 故障操作范围和回滚步骤经确认。

## 目标

- 设计结构化日志、关联 ID 和敏感数据策略；
- 使用 metrics/SLI/SLO/alert 的高层方法监控主链路；
- 建立 Java/Python/HTTP/事件的分布式 trace；
- 为 PostgreSQL 与对象存储执行备份和真实恢复；
- 理解 Redis 不是业务事实备份；
- 建立性能基线，定位慢 SQL、线程/连接/事件循环/前端瓶颈；
- 执行依赖/镜像/secret/权限/安全 header 检查；
- 对 8 类故障记录现象、检测、定位、影响、处置、恢复和预防；
- 明确降级、回滚、RPO/RTO 和未验证项；
- 通过 G7。

## 完整概念清单

### Logs、metrics、traces、profiles

- log 记录离散事件，metric 聚合趋势，trace 连接请求路径，profile 分析资源热点；
- structured event、level、timestamp、service/version/environment；
- trace/correlation ID 贯穿 HTTP、SSE、event、background task；
- log sampling/retention/rotation 与成本；
- 不记录密钥、完整 token、隐私文档或敏感 prompt；
- RED（rate/error/duration）与 USE（utilization/saturation/errors）；
- counter/gauge/histogram 和高基数标签风险；
- span/parent/context propagation、async/event link；
- profile/JFR/py-spy/browser profile 按问题使用；
- observability 是提问能力，不是工具堆积。

### SLI、SLO 与告警

- SLI 是测量，SLO 是目标，SLA 是外部约定；
- availability、latency、correctness/freshness 指标；
- error budget 高层概念；
- alert 必须可行动并有 owner/runbook；
- symptom alert 优先，cause alert 辅助；
- health endpoint 不是业务 SLI；
- AI 质量/拒答/引用/成本也是独立观测维度；
- 测试环境阈值用于实验，不伪装生产容量承诺。

### 备份与恢复

- backup、replication、high availability 不是同一件事；
- PostgreSQL logical/physical/WAL/PITR 高层概念；
- RPO 最大可接受数据丢失，RTO 最大恢复时间；
- 备份加密、访问、保留、异地和删除策略；
- 只看到 backup success 不算恢复验证；
- restore 到隔离环境，校验 schema、行数、业务不变量和应用可读；
- 对象存储版本、生命周期、元数据与数据库引用一致性；
- Redis 可重建缓存和不可丢技术状态需区分；
- RAG chunk/embedding 可重建，原文/元数据才是权威来源。

### 性能与容量

- baseline、workload、percentile、throughput、latency、saturation；
- 先测量和定位，再优化；
- PostgreSQL EXPLAIN/慢查询/连接池/锁；
- JVM heap/GC/thread/virtual thread pinning/connection limits；
- Python event loop blocking、worker/concurrency、model latency；
- Redis/object storage/network timeout；
- Web bundle/render/long task/network waterfall；
- load test 使用受控数据和上限，不攻击外部服务；
- 单机演示结果不能声称生产 QPS。

### 安全与供应链

- least privilege、network exposure、service identity、secret rotation；
- dependency/image/SBOM/license scan；
- secret scan 与历史泄漏后必须轮换；
- TLS/header/CORS/CSRF/XSS/API auth/RBAC/tenant 回归；
- file upload、object access、path/content type/size；
- prompt injection/tool allowlist/ACL/人工确认；
- fail secure、rate limit、audit；
- 扫描结果需分级、验证和修复，不机械追零告警。

### Incident 与复盘

- detection、triage、containment、mitigation、recovery、follow-up；
- incident timeline、owner、communication、decision log；
- runbook 可执行、包含前置/风险/验证/回滚；
- postmortem 无责但具体，区分触发、根因和促成因素；
- rollback、roll-forward、feature flag、degradation；
- 恢复后验证业务而不只看进程启动；
- 临时措施需有过期/永久修复项。

## 八类必须演练

1. PostgreSQL 慢查询或连接/锁等待；
2. Redis 中断或缓存数据丢失；
3. Python/模型超时与不可用；
4. 对象存储上传/读取失败；
5. 重复 HTTP/事件提交；
6. PostgreSQL 与对象存储备份恢复；
7. 配置/密钥缺失或权限过宽；
8. Java/Python/Nuxt 服务重启与处理中请求恢复。

每次记录：预期、注入方式、现象、告警/日志/trace、影响、定位、处置、恢复验证、预防、未验证点。

## 时间与任务

| 任务 | 时间 | 产出 |
| --- | ---: | --- |
| 日志/指标/trace | 3h | 全链路关联与可行动面板/查询 |
| 备份恢复 | 3—4h | 隔离恢复、业务校验、实测 RPO/RTO |
| 性能基线 | 2—3h | 主流程负载、瓶颈和一项证据优化 |
| 安全/供应链 | 2—3h | 扫描、权限、密钥和回归记录 |
| 故障演练 | 4—5h | 八类脚本/runbook/恢复证据 |
| G7 答辩/复盘 | 1h | 已验证、未验证、风险和下一步 |

## FactoryCare 交付物

- observability 说明与最小 dashboard/query；
- traceId 跨 Java、Python、SSE、event 的样例；
- PostgreSQL/对象存储 backup/restore runbook 与真实恢复日志；
- 性能基线和优化前后对比，不夸大容量；
- 安全/依赖/镜像/secret 扫描记录及处置；
- 八类故障演练报告；
- G7 评分、缺口和补考计划（如需要）。

## 无 AI 任务（120—150 分钟）

随机抽取两类未知故障，在只给现象的情况下使用日志、metric、trace、系统/数据库工具定位；执行降级或恢复并验证一条业务不变量。不得盲目重启或重写。提交时间线、证据、根因/促因和预防措施。

## 验收

- 能比较 log/metric/trace/profile 和 SLI/SLO/SLA；
- 备份已真实恢复并通过业务校验；
- 八类故障都从现象走到恢复验证；
- 性能结论有固定 workload/环境/指标；
- 严重安全问题已处置，密钥泄漏按轮换而非只删除文件；
- Redis/Python/AI 故障不会静默破坏核心业务；
- 能完成 20 分钟 G7 答辩并明确未验证事项。

## 非目标

- 不新建 Kubernetes/Service Mesh 平台；
- 不声称演示环境等于生产规模；
- 不以 100% 测试覆盖或零扫描告警作为唯一目标；
- 不新增业务大功能。
