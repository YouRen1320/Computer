# 百科全书机器观察报告

本目录只保存可追溯、脱敏的本机机器观察结果。这里的 JSON 不是学习者提交的 evidence，
不是章节人工评审结论，也不能把章节、练习或 verification candidate 晋升为 final。
机器通过只说明声明的命令在记录的环境与输入下满足机械合同。

## 命名与边界

- 文件名使用 `<scope>-YYYY-MM-DD.json`，同一天同一 scope 由对应审计器原子覆盖。
- JSON 不记录生成时间、绝对路径、用户名、Token 或命令原始诊断。缓存位置只记录脱敏摘要；端点审计另为 pnpm 与 Dart Pub 保存运行前后有界内容清单，不把位置摘要冒充内容冻结。
- `observed-unreviewed`、`machine-only-not-learner-evidence` 与
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
| `version-sources-2026-07-24.json` | `ruby scripts/audit-version-sources.rb` | 版本来源机械审计；由该审计任务单独维护，本目录其他任务不得覆盖 |
| `chapter-live-links-2026-07-24.json` | 章节链接 live 审计 | 章节外部链接的脱敏机器可达性观察；不证明内容正确或长期可用 |

前三份报告分别遵循
[`schemas/encyclopedia-endpoint-audit.schema.json`](../../../../schemas/encyclopedia-endpoint-audit.schema.json)、
[`schemas/exercise-contract-audit.schema.json`](../../../../schemas/exercise-contract-audit.schema.json) 与
[`schemas/observed-verification-candidates-v2.schema.json`](../../../../schemas/observed-verification-candidates-v2.schema.json)。
