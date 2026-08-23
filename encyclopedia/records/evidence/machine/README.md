# 百科全书机器观察报告

本目录只保存可追溯、脱敏的本机机器观察结果。这里的 JSON 不是学习者提交的 evidence，
不是章节人工评审结论，也不能把章节、练习或 verification candidate 晋升为 final。
机器通过只说明声明的命令在记录的环境与输入下满足机械合同。

## 命名与边界

- 文件名使用 `<scope>-YYYY-MM-DD.json`，同一天同一 scope 由对应审计器原子覆盖。
- JSON 不记录生成时间、绝对路径、用户名、Token 或命令原始诊断。缓存位置只记录脱敏摘要；端点审计另为 pnpm 与 Dart Pub 保存运行前后有界内容清单，不把位置摘要冒充内容冻结。
- `observed-unreviewed`、`machine-only-not-learner-evidence`、
  `machine-only-not-certification` 与
  `forbidden-without-human-review` 是刻意的边界，不得手工改成通过或 final。
- exercise 与 candidate v2 都记录来源 endpoint JSON 原始文件字节的
  `source_endpoint_report_sha256`。candidate 的 `endpoint_observation_set_sha256` 只绑定
  三个公开角色的稳定投影；它不是整份来源文件摘要。candidate 的工具版本探针在生成
  candidate 时另行执行，不是 endpoint 审计运行时产生的探针。
- 本目录不能被 `verification/manifests/`、章节 front matter 或学习进度记录当作人工门证据。

## 2026-07-24 当前机器快照

以下数字来自当前绑定的机器报告（采用各自现行 schema）与最后一次成功 Runner evidence；
“机器完成”只表示相应机械合同在记录的本机环境中闭合，不表示真人教学审查、学习者掌握、
无障碍认证或发行批准。

| 范围 | 当前机器事实 | 边界 |
|---|---|---|
| 公开 Runner | schema v2；255 个 executable manifest、765 个 recipe、255 个 expected-red；`result: succeeded`；evidence SHA-256 `df959abe8e1e3f11f5694bde7f85ad8e04e65937c3c7aa6362ace1256653501d` | [`verification/evidence/last-run/evidence.json`](../../../../verification/evidence/last-run/evidence.json) 是自动化本机证据，不是独立真人 attestation |
| 私有 Runner | internal evidence schema v1；255 章、255 个私有 recipe；`result: succeeded`；evidence SHA-256 `8f2da415443202f25fe50fbd15d3f4a816699e8113b0014affad8786199df1b4` | `verification/private-evidence/last-run/evidence.json` 是 Git 忽略的 internal-only 证据，不属于公共 D5，也不可作为发行材料 |
| 全端点 | schema v2；255 章、1020/1020 端点通过、0 失败、0 基础设施失败 | 每章 example/lab/exercise/private-solution 各 255 个端点；仍不是 OS 沙箱 |
| 练习合同 | schema v2；255/255 `EXPECTED_RED`；510 次 fresh-copy 观察；255 次退出码 41；0 机械失败 | `observed-unreviewed`，禁止在无人审下晋升 |
| 最终 AST 链接 | schema v2；255 章、2013 个最终 Link/Image AST 节点、1446 个唯一目标、0 结构失败 | 本次为 `structure-only`；1224 个外部 HTTPS 目标未做新 live 探测 |
| 出版无障碍 | 307 个工件、324/324 机器检查通过、0 失败、68 个人工复核信号 | `machine-only-not-certification`，不等于键盘、读屏、真实设备或 PDF/UA 人工合规 |
| 版本来源 | schema v2；71 个原子 registry 条目、93/93 条 official/primary HTTPS 来源可达、0 失败 | 只证明检查日 HTTP 200/206，不证明 claim 正确、兼容或章节事实成立 |
| 完成定义 | 255/255 结构、manifest 和 current Runner evidence 已闭合；独立真人 attestation 0/255；发行门 0/4 | `global_completion_ready: false`、`release_ready: false`，当前状态为 `human-review-required` |

公开 Runner evidence v2 固定 14 项控制面文件，并保存实际 Ruby、15 个声明工具、资源上限、
确定性 Python 环境和完整 manifest/recipe 结果。Maven、pnpm、uv、Dart/Flutter 的 Pub 缓存只从
显式仓库外固定目录解析；Runner 不回退到用户默认缓存。pnpm 同时依赖调用者预置的 Corepack
运行时，执行环境显式继承 `COREPACK_HOME` 并强制 `COREPACK_ENABLE_NETWORK=0`。需要
`docker compose` 的章节只使用显式指定、按字节摘要冻结的 Compose 插件；插件被复制到 fresh
HOME 的无凭据 Docker 配置中。上述策略是 fail-closed 的进程级约束，但网络和仓库外文件系统
仍未由操作系统隔离。

## 报告清单

| 文件 | 产生方式 | 含义 |
|---|---|---|
| `endpoint-audit-2026-07-24.json` | `ruby scripts/audit-encyclopedia-endpoints.rb --output ...` | schema v2；255 章的 1020/1020 个公开/私有端点通过；公开端点各运行两份独立 fresh copy，私有解析运行一份 |
| `endpoint-audit-failed-975-of-1020-2026-07-24.json` | 首次全量审计的只读留档 | 旧报告结构下的历史失败诊断（975/1020）；仅用于说明修复来源，不满足当前 endpoint schema，也不是当前通过证据 |
| `exercise-contracts-2026-07-24.json` | `ruby scripts/audit-exercise-contracts.rb --endpoint-report ... --output ...` | schema v2；从双 fresh-copy 观察提取 255 个练习、510 次运行、255 个 `EXPECTED_RED` 和退出码 41，0 机械失败；仍为未人工复核观察 |
| `observed-candidates-v2-2026-07-24.json` | 晋升前执行的 `ruby scripts/generate-verification-manifests.rb --bootstrap-candidates ...` | **晋升前历史来源快照**：251 个 candidate、753 个公开端点；它保存当时用于 manifest 晋升的来源观察，不是当前 manifest 缺口或当前 coverage，禁止自动晋升 |
| `version-sources-2026-07-24.json` | v1 单 URL 审计历史留档 | 旧 `source_url` 口径；不满足 registry v2 的逐来源、claim 与人工晋升边界，不能冒充当前报告 |
| `version-sources-v2-2026-07-24.json` | `ruby scripts/audit-version-sources.rb --checked-at 2026-07-24 --pretty --output ...` | 逐条探测 71 个原子条目的 93 条 official/primary 来源，绑定 registry 原始字节 SHA；93/93 可达、0 失败 |
| `chapter-live-links-2026-07-24.json` | 历史 v1 Markdown 正则链接 live 审计 | 冻结的旧口径观察；未绑定 P8 AST，不能冒充 v2 最终节点清单 |
| `chapter-ast-links-v2-2026-07-24.json` | `ruby scripts/audit-chapter-markdown-links.rb --mode structure-only --observation-date 2026-07-24 ...` | schema v2；逐字节绑定 P8 plan/output manifest/canonical AST，遍历 255 章的 2013 个最终 `Link`/`Image` 节点；0 结构失败，本报告未伪造新的 live 网络结果 |
| `definition-of-done-2026-07-24.json` | `ruby scripts/audit-encyclopedia-definition-of-done.rb --output ...` | schema v2；255 章结构、manifest、current Runner evidence 全部闭合，真人 attestation 0/255、release gate 0/4；报告正确保持 `human-review-required` |
| `publication-accessibility-2026-07-24.json` | `ruby scripts/audit-publication-accessibility.rb --jobs 4 --timeout 600 --output ...` | 绑定 Typst 全量重建后的 307 个交付工件；324/324 项 axe/EPUBCheck/Ace/veraPDF 机器检查通过，仍有 68 个人工复核信号且不构成认证 |

Definition of Done 当前遵循
[`schemas/encyclopedia-definition-of-done-v2.schema.json`](../../../../schemas/encyclopedia-definition-of-done-v2.schema.json)。
旧 `encyclopedia-definition-of-done.schema.json` 仅保留历史 v1 形状，不再授权通过章节 front matter
冒充真人 attestation。v2 把机器合同、当前执行、独立真人复核和四项全局发行门分离，逐字节绑定
实际 evidence；机器结果禁止自动晋升章节、manifest、学习进度或发行状态。

前三份报告分别遵循
[`schemas/encyclopedia-endpoint-audit.schema.json`](../../../../schemas/encyclopedia-endpoint-audit.schema.json)、
[`schemas/exercise-contract-audit.schema.json`](../../../../schemas/exercise-contract-audit.schema.json) 与
[`schemas/observed-verification-candidates-v2.schema.json`](../../../../schemas/observed-verification-candidates-v2.schema.json)。
新的 AST 链接报告遵循
[`schemas/chapter-pandoc-link-audit-v2.schema.json`](../../../../schemas/chapter-pandoc-link-audit-v2.schema.json)；
旧 `chapter-live-links` 文件保留 schema v1 历史语义，不自动迁移或自动判通过。

版本来源 v2 报告只证明所绑定注册表中的每条 HTTPS 来源在检查日返回 HTTP 200/206，
不证明 claim 语义、跨产品兼容性或章节事实。报告保留每条来源的 entry/source ID、发布者、
精确 claim、最终 HTTPS URL 与网络结果，并固定
`promotion: forbidden-without-human-review`；审计器不会写注册表，也不会把
`conceptual`/`provisional` 自动改成 `verified`。
