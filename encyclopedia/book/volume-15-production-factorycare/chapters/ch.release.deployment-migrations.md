---
schema_version: 2
edition: 2026.2-draft
id: ch.release.deployment-migrations
title: 部署、expand-contract、前向修复与回滚
responsibility: 以不可变制品和 expand-contract 数据迁移执行可观测部署，分别定义应用回滚与数据库前向修复，不承诺不可逆迁移可一键回滚。
volume: '15'
order: 13
level: L3
status: drafting
path: book/volume-15-production-factorycare/chapters/ch.release.deployment-migrations.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.release.artifacts-promotion
- ch.ops.backup-recovery
- ch.architecture.observability-slo
version_surfaces:
- github-actions-hosted-runner
- docker
- docker-compose
- nginx
- postgresql-18
- flyway
- opentelemetry-specification
- opentelemetry-semantic-conventions
- opentelemetry-collector
- ubuntu-server-26.04
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“部署、expand-contract、前向修复与回滚”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - release-deployment-strategy
  - release-migration-safety
  covers_topics:
  - release.rolling-deployment
  - release.canary
  - release.readiness-gate
  - release.rollback-trigger
  - release.expand-contract
  - release.backward-compatible-schema
  - release.forward-fix
  - release.migration-checkpoint
  uses_capabilities:
  - ops.container-proxy-delivery
  - data.schema-migration
  - data.transactions-locks
  - architecture.observability
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 演练工单字段 expand/backfill/contract 与两版应用并存，执行 canary、自动门禁、应用回滚和数据库前向修复；独立保存可复现工件与判断结果
  covers_topic_groups:
  - release-deployment-strategy
  - release-migration-safety
  covers_topics:
  - release.rolling-deployment
  - release.canary
  - release.readiness-gate
  - release.rollback-trigger
  - release.expand-contract
  - release.backward-compatible-schema
  - release.forward-fix
  - release.migration-checkpoint
  uses_capabilities:
  - ops.container-proxy-delivery
  - data.schema-migration
  - data.transactions-locks
  - architecture.observability
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: mixed-version-test-canary-gate-migration-failure-drill
- id: diagnose
  kind: fault-diagnosis
  text: 面对“新旧版本不兼容同一 schema、contract 过早删列、迁移失败仍切流量或回滚到读取不了新数据的旧制品”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - release-deployment-strategy
  - release-migration-safety
  covers_topics:
  - release.rolling-deployment
  - release.canary
  - release.readiness-gate
  - release.rollback-trigger
  - release.expand-contract
  - release.backward-compatible-schema
  - release.forward-fix
  - release.migration-checkpoint
  uses_capabilities:
  - ops.container-proxy-delivery
  - data.schema-migration
  - data.transactions-locks
  - architecture.observability
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 部署、expand-contract、前向修复与回滚

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《制品、来源证明、环境晋级与发布元数据》](ch.release.artifacts-promotion.md)：部署只能选择已通过门禁且 digest 不变的晋级制品。
- [《备份、恢复、RPO/RTO 与恢复演练》](ch.ops.backup-recovery.md)：数据库变更前必须具备已演练恢复点与明确 RPO/RTO。
- [《日志、指标、追踪、SLO 与告警闭环》](../../volume-06-enterprise-architecture/chapters/ch.architecture.observability-slo.md)：canary 门禁、切流量和回滚触发器必须读取已验证的日志、指标、链路与 SLO。
<!-- END GENERATED LEARNING PREREQUISITES -->

应用回滚和数据库回滚不是同一件事。容器制品可以把流量切回旧 digest，只要旧应用仍能理解当前 schema 和数据；已经提交的数据迁移可能持锁、重写大量行、被外部系统观察，甚至不可逆。可靠发布不承诺“任何失败都一键回到过去”，而是用不可变制品、兼容窗口、expand/backfill/contract、canary 门禁和前向修复，把每一步变成可停止、可观察、可收敛的状态机。

本章负责从已晋级制品到可观测部署，并把 FactoryCare 工单字段迁移作为综合演练。它不重新构建镜像，不替代备份恢复，不教授 CI 基础，也不让 Python/AI 决定工单最终状态。Java 新旧版本必须共同遵守业务合同；Flyway/PostgreSQL 负责 schema 变更轨迹；部署控制面根据就绪、错误、延迟和迁移状态决定流量。

稳定核心是兼容优先、先扩后缩、迁移有 checkpoint、坏 canary 自动停止、应用回滚边界明确、数据库失败以经验证前向修复收敛。GitHub Actions、Docker/Compose、Nginx、PostgreSQL 18、Flyway 和 OpenTelemetry 的命令与默认行为属于版本表面，执行前按实际版本核对。

## 1. 把发布建模为状态机

一次发布可分为 candidate-verified、expand-applied、mixed-version-green、canary-running、canary-green、traffic-promoted、backfill-complete、old-readers-zero、contract-applied、observed 等状态。每个迁移只接受前一状态的同一 release ID、artifact digest、schema version 和证据，不允许脚本遇错后“尽量继续”。

状态机要记录动作和观察，而不只记录最终绿色。谁在何时部署哪个 digest、Flyway 执行哪些迁移、canary 比例、门禁窗口、触发回滚原因、checkpoint、旧副本数量和 contract 审批，都是事故诊断证据。聊天消息“刚才回滚了”没有对象身份和时间，不能证明运行状态。

并发发布需要环境锁。候选 A 正在 canary 时，候选 B 不能覆盖代理配置，让 A 的指标实际来自 B。锁要有所有者、租约、取消和恢复规则；GitHub Actions 的 `environment` 与 `concurrency` 是不同概念，必须显式配置而非假设环境自动串行。

## 2. 只部署已验证的不可变制品

候选来自上一章发布清单，包含完整 commit、OCI digest、SBOM/来源证明与门禁。部署测试、canary 和正式流量必须解析到同一 digest；环境之间只改变外部配置。若生产阶段重新 `docker build`，即使源码 commit 相同也产生新候选，必须重新验证。

tag 可以用于人类发现，但会移动。部署记录保存 registry 完整引用和 digest，并在节点实际拉取后再核对。多架构镜像要保存 index 与目标平台 manifest；本地 arm64 绿色不能证明 Ubuntu amd64 节点运行对象。

回滚目标同样必须是已知 digest，且有与当前 schema 的兼容证据。选择“上一个 tag”可能取到已移动或更早对象。清单应提前计算 rollback candidate，不在事故中临时猜版本。

## 3. Rolling deployment 的真实含义

滚动发布逐批替换副本，使新旧版本在一段时间共存。它减少一次性切换风险，但把兼容性变成强制条件：同一请求可能先到 v1，重试后到 v2；两版同时读写一个数据库；后台任务和事件消费者也可能混合。若 schema 只支持新版本，第一批替换后旧副本立即失败。

批大小、最大不可用、额外容量、就绪等待和终止宽限决定风险。一次替换全部副本只是带“rolling”名字的重建。容量不足时，新旧并存和可观测开销可能让系统在发布时过载，因此发布前要使用上一章的余量证据。

旧副本退出要停止接新流量、完成/取消在途请求、释放租约与消费者分区、刷新必要状态。仅容器进程结束不证明没有后台工作。Nginx 或服务发现摘除、应用 readiness、连接 draining 和终止信号要一起验证。

## 4. Canary 是小范围决策实验

canary 让少量真实或代表性流量进入新制品，在影响面受控时观察。它不是“先启动一个容器看看日志”，也不是按固定五分钟后无条件放量。每个阶段有流量比例、最小样本/窗口、健康指标、业务 oracle、停止条件和最大影响预算。

门禁至少读取 readiness、错误率、p95/p99、关键业务失败、资源、依赖和 migration state，并与当前稳定版本或 SLO 比较。低流量下没有足够写请求时，零错误不具统计意义；canary 可先运行合成 smoke，再等待真实代表性样本。高风险业务应限制可用用户/租户并准备补偿。

自动门禁必须 fail closed。指标缺失、查询超时、版本标签不一致或迁移状态未知，应停止晋级而不是把缺数据当零。门禁自身要版本化、测试，并保存原始查询与判决。人工可覆盖时要记录理由、批准者和风险，不应直接修改数据库状态掩盖红线。

## 5. readiness 不是 liveness

liveness 回答进程是否需要重启，readiness 回答实例当前是否能接流量。Java 进程启动不等于 Flyway 完成、连接池可用、必要配置正确或缓存初始化完成。readiness 应检查本实例能否执行关键轻量依赖操作，但不能做昂贵全链路或因单个非关键依赖抖动持续重启。

发布门禁还要验证制品身份。旧实例 `/health` 返回 200 可能误导；响应或遥测应包含 release ID/commit/digest 的受控只读标识，代理 smoke 断言命中新候选。身份元数据不能由任意环境变量伪造。

Compose 的 `depends_on` 仅表达创建顺序时不等于真正就绪；当前 Docker 文档要求使用健康检查与 `service_healthy` 等条件才等待依赖健康。真实生产编排器有自己的 readiness 语义，不能直接把 Compose 行为外推。

## 6. 为什么直接改名或删列会破坏混合版本

假设旧版读取/写入 `assignee_name`，新版希望使用 `assignee_display_name`。一次迁移直接 rename 后，新版可用而旧副本 SQL 报列不存在；先部署新版再 rename，新版在旧 schema 上也可能失败。安全路径是增加新列而保留旧列，建立一段双方都能工作的兼容窗口。

兼容不只在列存在。类型、NULL、默认值、约束、索引、枚举和值语义都可能破坏旧应用。例如把 nullable 立即改为 NOT NULL，而旧版仍不写新列；把字符串状态改枚举但旧版发送未知值；修改事件 JSON 字段使旧消费者无法解析。契约测试必须运行 v1 对 expanded schema、v2 对 expanded schema，以及两版交错读写。

API 与数据库兼容窗口应对齐。v2 若只写新列，v1 读旧列会看不到新事实；因此过渡期常用 dual-write 或数据库同步机制。双写必须在同一事务并定义冲突来源，不能先写一个再异步“尽量”写另一个。更复杂方案要明确唯一事实源和对账。

## 7. Expand 阶段

Expand 只增加向后兼容能力：新增 nullable 列、表、索引或接受新旧格式的代码，不删除旧合同。对于字段迁移，可以先添加新列且不强制旧版无法满足的约束；部署能回退读取旧列并双写的 v2；运行 mixed-version 测试。

PostgreSQL 18 文档说明添加带常量默认值的列通常可避免逐行更新，读取时返回默认并在后续重写应用；volatile 默认则需要为每行计算并可能重写。具体锁级、表大小和版本行为仍需在接近生产的隔离副本测量。即使 DDL 执行很快，等待锁也可能很久，因此设置 lock timeout、statement timeout 和观察阻塞链。

新增索引若使用阻塞方式会影响写入。`CREATE INDEX CONCURRENTLY` 有自己的阶段、失败状态和事务限制，不能仅凭名字认为无风险。迁移工具如何包事务必须按数据库与 Flyway 配置核对，并保存实际 schema history 和 PostgreSQL 日志。

## 8. Backfill 是可恢复的数据作业

Backfill 把历史 `assignee_name` 复制/转换到新列。大表一次 UPDATE 可能产生长事务、锁、WAL、复制延迟、膨胀和回滚压力。采用按稳定主键分批，限制 batch 大小/速率，每批独立提交并保存最后确认 checkpoint。checkpoint 代表已提交且验证的边界，不是客户端已发送的位置。

作业必须幂等：同一 batch 重跑得到相同结果；使用 `WHERE new_column IS NULL` 或版本条件时要理解并发写。v2 双写新数据，backfill 只填历史空值，避免覆盖发布后用户更新。若转换复杂，保存转换版本和错误表，单行坏数据不能让团队无证据地跳过。

每批记录开始/结束主键、扫描/更新/跳过/失败数量、事务时间、锁等待、WAL/复制延迟、查询计划与 checksum。遇到门禁阈值停止，修复后从最后成功 checkpoint 继续。完成判据不是“循环到表尾”，而是全表残余查询为零、计数/摘要一致，并在并发流量下重复检查。

## 9. Switch read 与观察期

数据完整后，新版从“新列优先、旧列回退”切换为“只读新列”，但过渡期仍可双写。用 feature flag 时记录配置修订和时间，避免多个节点状态不一致。切换先小范围 canary，监控读取 fallback 次数、空值、差异和业务错误。

观察期要至少覆盖代表性业务周期和所有消费者。HTTP 节点归零不代表离线任务、导出、报表、Python 服务和旧移动客户端不再读取旧字段。数据库查询审计、代码搜索、运行遥测与所有者确认组合，才能支持 legacy read count 为零。

若发现差异，先停止晋级，保留旧列，修复双写/backfill 并前向收敛。不要通过修改旧列使测试暂时一致而忘记确定权威值。FactoryCare 的最终业务事实由 Java 服务规则与审计历史判断。

## 10. Contract 阶段

Contract 删除旧列、兼容代码和双写，是独立发布，不应与 expand 同一窗口完成。前置条件包括：所有旧副本与消费者归零；新列全量完整；mixed-version 契约曾通过；新版本 canary/正式观察绿色；备份恢复演练有效；迁移无失败；应用回滚策略已更新。

删除列前再次查询实际依赖：视图、函数、触发器、索引、约束、报表和外部工具。PostgreSQL 对依赖有 RESTRICT/CASCADE 语义，不能为了命令成功随意使用 CASCADE。先在隔离副本运行并保存锁/耗时/依赖结果。

Contract 完成后，旧应用可能无法回滚。此时 rollback candidate 必须是理解新 schema 的前一新版本，或选择 roll-forward。发布清单应把兼容区间建模为矩阵，而不是永久写“上一个版本”。

## 11. Flyway 迁移纪律

Flyway versioned migration 按顺序应用，并在 schema history 保存版本、描述、checksum、执行与成功状态。已经应用的 versioned 文件应视为不可变；修改 checksum 会让 `validate` 失败。正确做法通常是新增修复迁移，而不是改历史脚本让新环境与旧环境产生不同历史。

官方当前文档说明 `validate` 比较已应用与本地可解析迁移的名称、类型、checksum 和缺失/待应用状态。它证明历史一致性的一部分，不证明 SQL 业务安全、锁时长或数据正确。`repair` 会调整 schema history 的失败记录/checksum 等；它不是修复业务数据的魔法命令。只有实际数据库状态与迁移文件经人工证明一致时才能受控使用，并保存审批。

不同数据库的 DDL 事务支持不同；Flyway 遇错在可能时回滚，不能统一假设每个迁移原子。每个脚本要在同 PostgreSQL 大版本、真实数据规模和权限上演练。关闭 `clean` 的生产权限，限制迁移账号，secret 不进入日志。

## 12. 应用回滚与数据库前向修复

应用回滚把流量/副本切回已验证 digest，前提是旧制品能读写当前 schema 和数据。Expand 兼容窗口内，v1 仍有旧列，因此可以回滚应用；contract 后旧列消失，v1 不再是合法目标。回滚动作还要处理连接 draining、后台任务、缓存/事件版本和配置。

数据库“回滚脚本”常比名称危险。删除新列可能丢失只写入新列的数据；逆向转换可能不一一对应；DDL 已被其他事务观察。遇到 backfill 中断，更安全的路径通常是停止流量晋级、保留兼容 schema、修正迁移逻辑，从 checkpoint 重跑前向修复，使数据库收敛到已声明目标。

前向修复必须版本化、测试和审计。它可以是新 Flyway migration、幂等数据作业或配置修正；完成后运行原业务 oracle、schema history validate 和 canary 门禁。不能手工在线改几行后仅口头说明。

备份恢复是灾难路径，不是每次 migration 失败的首选撤销。恢复整个数据库会回退同期其他业务写入，可能违反更严格 RPO。发布前演练备份提供最后安全网，但是否恢复要根据影响、数据分叉和外部副作用决策。

## 13. 回滚触发器与中止条件

触发器必须在发布前定义，例如新版本 5xx 比稳定版高 1 个百分点持续三分钟、关键创建工单失败一次、p95 超 SLO、readiness 不满、migration state 非 success、数据差异不为零。阈值要结合样本量与影响预算；严重数据完整性问题可以一次即停。

指标缺失本身是触发器。若 canary 没有 release 标签、trace 断链或门禁查询失败，不能继续。部署控制面先停止扩大流量，再选择应用回滚、保持当前兼容版本、或前向修复数据库。动作顺序写入 runbook。

回滚后仍要观察旧版本、队列、数据库和外部依赖。已进入 canary 的写请求不会因容器切回自动消失；验证幂等、状态历史和事件/outbox。事故关闭前保存坏 digest、受影响请求、迁移 checkpoint 与恢复结果。

## 14. Nginx/代理与流量切换

代理可以按 upstream、权重、header/cookie 或其他策略分配 canary，但策略必须防止越权和缓存混淆。若同一用户旅程需粘性，说明选择；若重试可以跨版本，必须有混合版本兼容。代理日志记录 request ID、release/upstream、状态和时间，避免记录敏感 token。

Nginx 官方控制文档说明 HUP 触发 master 检查语法并尝试应用新配置；失败时继续使用旧配置，成功后启动新 worker 并优雅关闭旧 worker。实际切流前仍应运行配置测试、核对 upstream 身份并做 smoke。向错误 PID 发信号或容器重建语义不同，不能只看到命令退出零。

canary 配置本身应成为版本化制品/配置修订，支持原子切换和回滚。多个代理节点要确认全部收敛；一半节点旧权重会让实际比例与报告不同。观测按实际命中的 release，而不是按预期配置分组。

## 15. 四类故障的首个可信证据

新旧版本不兼容同一 schema：失败阶段是 expand/mixed-version gate。首个可信证据是 v1 或 v2 契约测试出现列不存在、NULL/类型错误，或交错读写差异。修复为恢复向后兼容 schema 和 dual-read/write，再让两版重跑同一矩阵；不能先关旧副本绕过测试。

Contract 过早删列：失败阶段是 contract gate。首个证据是 old replica count、legacy read count 非零，或 backfill 残余不为零。立即停止 contract；若已执行，旧应用不能盲目回滚，应部署兼容前向迁移重新增加合同或 roll-forward，随后验证数据语义。

迁移失败仍切流量：失败阶段是 readiness/canary gate。首个证据是 Flyway schema history / migration job 为 failed 或 unknown，而代理已提高权重。停止流量、保留证据、确定事务实际提交边界，新增/重跑幂等前向修复；不要直接 `repair` 把状态改绿。

回滚到读不了新数据的旧制品：失败阶段是 rollback candidate 选择。首个证据是兼容矩阵显示 contract 后旧列不存在，或旧版契约测试红。选择理解新 schema 的已验证 digest或继续前向修复；恢复数据库只在灾难决策后使用。

## 16. 端到端演练示例

目标是把 `assignee_name` 迁到 `assignee_display_name`。发布 A：Flyway 增加 nullable 新列；记录锁等待和 schema history；v1/v2 对 expanded schema 契约绿色。发布 B：v2 新代码读新回退旧、同事务双写；以 immutable digest 启动一个 canary，readiness、错误、p95 和身份门禁通过后逐批替换。

后台 backfill 按工单 ID 分批，checkpoint 保存最后提交 ID。注入 ID 处失败后，确认此前 batch 已提交、失败 batch 未被误标，修复转换并从 checkpoint 重跑。残余查询为零，规范化摘要一致，fallback 指标逐步归零。

观察期让旧副本、离线任务和旧消费者全部退出。发布 C 切为只读新列但暂保旧列，canary 与功能回归绿色。另一独立窗口执行 contract，只有 old replicas=0、legacy reads=0、backfill complete、备份恢复演练有效、canary green 才删旧列。此后应用回滚目标更新为 C 的前一兼容 digest，而不是 v1。

演练同时注入坏 canary：错误率超阈值后自动恢复代理权重，数据库不执行 contract；注入 migration failed：readiness/门禁保持红，流量不晋级；完成前向修复后重跑原混合版本和业务 oracle。

## 17. 证据包与职责边界

证据包至少包含：发布清单与 digest；CI 门禁链接；环境配置修订；Flyway migration 文件摘要、validate/info/schema history；PostgreSQL 版本、锁/执行日志；两版契约矩阵；backfill checkpoint 与计数/hash；canary 查询和原始指标；代理实际权重；回滚/前向修复记录；FactoryCare 业务不变量。

Java 代码拥有状态转换、权限、幂等与最终写入。Vue/Flutter/uni-app 适应 API 兼容合同，不直接依赖数据库列。Python 可以做离线分析或辅助回填，但需要受控接口/脚本、最小权限和可重入 checkpoint，不能绕过 Java 生成“更正确”的工单状态。

本仓库示例使用内存 `dict`/`set` 模拟 schema，验证两版共存、checkpoint、坏 canary 和 contract gate；lab 审计合成发布记录。它不模拟 DDL 锁、Flyway 事务、PostgreSQL 复制、真实容器或代理流量，因此绿色只属于逻辑夹具。

## 18. 当前官方来源与版本口径

本章于 2026-07-24 核对 PostgreSQL 18 [Modifying Tables](https://www.postgresql.org/docs/18/ddl-alter.html)，特别是新增列默认值可能避免或触发行重写的边界；真实锁行为仍需隔离演练。当前 18 文档展示 18.4，实际实验保存服务端完整版本。

Flyway 当前一手资料包括 [Migrations](https://documentation.red-gate.com/flyway/flyway-concepts/migrations)、[Validate](https://documentation.red-gate.com/flyway/reference/commands/validate) 与 [Schema History Table](https://documentation.red-gate.com/flyway/flyway-concepts/migrations/flyway-schema-history-table)。文档在 2026 年仍持续更新，功能和版本会变化；本机未执行 Flyway，因此本文不声明某个已安装版本。

代理行为参考 Nginx 官方 [Controlling nginx](https://nginx.org/en/docs/control.html)；部署环境/保护规则参考 GitHub 官方 [Deployment environments](https://docs.github.com/en/actions/concepts/workflows-and-actions/deployment-environments)。GitHub 套餐、保护规则和 runner 能力需在组织账户核对。Docker、Compose、Nginx、CI 和 Ubuntu 26.04 均未由本章内存夹具实际启动。

## 19. 学习、练习与过关

公开练习故意让 `contract_ready` 只检查 backfill，所以旧副本仍在线、旧读取存在或 canary 红时会错误返回真。学习者要补齐所有 fail-closed 条件，并解释为何 contract 是独立发布。示例/私有答案绿色不代表真实数据库迁移。

独立构建证据需要真实隔离 PostgreSQL 与两版 Java 应用：expand schema；v1/v2 混合契约；canary 自动门禁；分批回填和故障 checkpoint；应用回滚；迁移失败后的前向修复；contract gate。每次保存实际 digest、版本、日志、指标和业务 oracle。

120 秒讲解应说明 rolling 为什么要求混合版本兼容、canary 为什么不是定时等待、readiness 与 liveness 的差别、expand/backfill/switch/contract 的顺序、应用回滚为何不同于数据库逆迁移、contract 后回滚目标为何改变。越界反例是为了“一键回滚”直接删新列，导致发布后只存在新列的数据永久丢失。

## 20. 上线前清单

- 候选和回滚对象是否为已验证完整 digest，而不是可变 tag？
- 环境锁是否防止并发候选污染 canary 证据？
- v1/v2 是否在 expanded schema 上通过读写交错契约？
- DDL 锁、超时、表重写、WAL 和复制影响是否在近似数据上测量？
- Backfill 是否分批、幂等、有最后提交 checkpoint 和残余 oracle？
- Read switch 是否可观察 fallback、差异和所有消费者？
- Canary 是否有代表性样本、自动门禁、缺指标 fail closed 和影响预算？
- 迁移 state 非 success 时是否阻止 readiness/流量晋级？
- Contract 是否等待旧副本/读取归零、数据完整、恢复演练和 canary 全绿？
- 应用 rollback candidate 是否仍理解当前 schema 和数据？
- 数据库失败是否有新增迁移/幂等作业的前向修复，而非篡改历史？
- 修复后是否重跑原混合版本、功能、不变量和发布门禁？

安全发布不是从旧版本瞬间跳到新版本，而是在一系列兼容状态之间移动，每一步都有对象身份、前置条件、观测、停止和收敛路径。做到这一点，团队才能诚实地说“应用可回滚到哪里、数据库如何前向修复”，而不是在事故发生后才发现所谓的一键回滚并不存在。
