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

## 报告清单

| 文件 | 产生方式 | 含义 |
|---|---|---|
| `endpoint-audit-2026-07-24.json` | `ruby scripts/audit-encyclopedia-endpoints.rb --output ...` | 1020 个公开/私有端点；公开端点各运行两份独立 fresh copy，私有解析运行一份 |
| `endpoint-audit-failed-975-of-1020-2026-07-24.json` | 首次全量审计的只读留档 | 旧报告结构下的历史失败诊断（975/1020）；仅用于说明修复来源，不满足当前 endpoint schema，也不是当前通过证据 |
| `exercise-contracts-2026-07-24.json` | `ruby scripts/audit-exercise-contracts.rb --endpoint-report ... --output ...` | 仅接受完整通过的 1020 端点来源，从双 fresh-copy 观察提取 255 个练习的精确退出码、`EXPECTED_RED`、诊断集合与输出闭包 |
| `observed-candidates-v2-2026-07-24.json` | `ruby scripts/generate-verification-manifests.rb --bootstrap-candidates --endpoint-report ... --output ...` | 仅接受完整通过的 1020 端点来源；记录缺少 final manifest 章节的完整静态输入、生成时工具探针和端点观察候选；禁止自动晋升 |
| `version-sources-2026-07-24.json` | v1 单 URL 审计历史留档 | 旧 `source_url` 口径；不满足 registry v2 的逐来源、claim 与人工晋升边界，不能冒充当前报告 |
| `version-sources-v2-2026-07-24.json` | `ruby scripts/audit-version-sources.rb --checked-at 2026-07-24 --pretty --output ...` | 逐条探测 71 个原子条目的 93 条 official/primary 来源，绑定 registry 原始字节 SHA；93/93 可达、0 失败 |
| `chapter-live-links-2026-07-24.json` | 历史 v1 Markdown 正则链接 live 审计 | 冻结的旧口径观察；未绑定 P8 AST，不能冒充 v2 最终节点清单 |
| `chapter-ast-links-v2-2026-07-24.json` | `ruby scripts/audit-chapter-markdown-links.rb --mode structure-only --observation-date 2026-07-24 ...` | v2 逐字节绑定 P8 plan/output manifest/canonical AST，遍历最终 `Link`/`Image` 节点；本报告只做结构审计，未伪造新的 live 网络结果 |
| `definition-of-done-2026-07-24.json` | `ruby scripts/audit-encyclopedia-definition-of-done.rb --output ...` | 255 章结构项、缺失项、人工待审项与 42 个 6–7 章复核批次；结构全绿不等于语义批准 |
| `publication-accessibility-2026-07-24.json` | `ruby scripts/audit-publication-accessibility.rb --jobs 4 --timeout 600 --output ...` | 绑定 Typst 全量重建后的 307 个交付工件；324/324 项 axe/EPUBCheck/Ace/veraPDF 机器检查通过，仍有 68 个人工复核信号且不构成认证 |

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
