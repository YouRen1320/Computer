# P9 全局技术审计与诚实收口记录（2026-07-24）

## 最终结论

**P9 的机器工程基线已经闭合，正式 P9 仍为 `incomplete`。** 当前 255 章都具备
executable verification manifest，公开 Runner 的 765 个 recipe 与私有答案 Runner 的
255 个 recipe 均在本机 clean-copy 合同下成功；P3、P8、最终 Pandoc AST 和出版无障碍
机器检查也都绑定到当前字节并通过各自机械门。

这些结果不等于真人教学审查、零基础可学性验证、无障碍认证、跨平台复现或公开发行批准。
Definition of Done v2 仍记录 255 章真人批准为 0，四项发行门均为 required；255 章继续保持
`drafting`，没有自动晋升章节状态，也没有修改 `PROGRESS.md` 或公开发布任何工件。

| 分系统 | 当前机器状态 | 结论边界 |
| --- | --- | --- |
| curriculum / routes | `passed` | 255 章、765 个 outcome 与 Week 00–48、三条完整路线保持同一权威来源；不证明真人可学性 |
| endpoint audit | `passed` | 1,020/1,020 端点通过；是本机 clean-copy 机器观察，不是人工验收 |
| exercise contracts | `observed-unreviewed` | 255 章、510 次运行、255/255 `EXPECTED_RED`、机械缺口 0；不得作为学习者 evidence |
| public verification | `succeeded` | 255/255 manifests、765/765 recipes、255 个 expected-nonzero recipe 通过；不是 human-reviewed final |
| private verification | `succeeded-internal-only` | 255/255 私有 recipe 通过；内部证据不进入公共 D5 覆盖 |
| P3 publication | `passed-machine-checks` | 4 个黄金章节、93 个输入、9 个实际输出；仍是内部候选 |
| P8 publication | `passed-machine-checks` | 255 章、16 卷、4,205 companions、4,479 inputs、345 planned paths、344 actual outputs |
| final AST links | `passed-structure-only` | 2,013 个最终 Link/Image 节点，结构失败 0；没有伪造新的 live 网络结果 |
| accessibility | `machine-passed` | 307 个工件、324/324 检查通过、机器失败 0、人工复核信号 68；不是认证 |
| Definition of Done | `human-review-required` | structure / manifest / current Runner 均为 255，真人批准 0，release validation 为 required |

## 权威范围与判定口径

本记录以当前仓库字节和以下证据为准：`curriculum/catalog.yml`、`book/`、生成路线与周适配层、
公开/私有 Runner evidence、P3/P8 plan 与 output manifest、AST v2、accessibility report 和 DoD v2。
各类证据不能相互替代：

- executable manifest 只定义机器命令、输入、预言和输出闭包，不代表独立真人已复核；
- Runner 成功只证明当前输入和记录环境满足机械合同，不代表教学内容正确或学习者已掌握；
- URL 可达性不证明来源权威、引用蕴含或正文事实正确；
- axe、EPUBCheck、Ace、veraPDF 的机器绿灯不构成 WCAG、EPUB Accessibility 或 PDF/UA 认证；
- 同机 clean copy 不等于另一执行方、另一操作系统或完全断网环境中的独立复现；
- 生成成功、文件数量和 AI 审查不能替代真人试学、内容审查与最终发行批准。

## 课程、周计划与路线

当前权威课程包含 16 卷、255 章、94 项 capability、394 条硬先修边和 4 个先修根节点；
硬先修图覆盖 255/255，未知边、自环和环均为 0。每章固定 `explain`、`build`、`diagnose`
三个 outcome，共 765 个。

Week 00–48 共 49 周，765 个主学习 outcome 在周计划中具有唯一归属。三条完整路线
`zero-base`、`accelerated-48`、`reference` 均覆盖 255/255；48 模块加速路线的
`m01`–`m48` 连续，每章恰好有一个 primary 模块。`factorycare-project` 是显式 selective
路线，包含 8 个固定阶段、93 个具有唯一 primary 阶段的 acceptance ID，覆盖 206/255 章；
剩余 49 章仍被三条完整路线覆盖，不是孤立内容。

`book/` 和 canonical curriculum spec 是正文权威；`weeks/` 与 Week 00–08 的
`learning-kits/*/concepts.md` 是生成的兼容入口，不是第二套教程。`PROGRESS.md` 仍由真实
学习证据驱动，本次课程工程收口没有写入学习时长、分数、日期或通过状态。

## 全端点与 Exercise 合同

`records/encyclopedia/evidence/machine/endpoint-audit-2026-07-24.json` 当前 SHA-256 为：

```text
87fabb1147e58c780372ade4e003b6acb48024d1ce5aea49271650d5b0b966fb
```

报告为 255 章、1,020 个端点、1,020 passed、0 failed。example、exercise、lab、private
solution 各 255 个；三个公开角色各在两份独立 fresh copy 中运行，私有解析运行一份。
审计检查输入漂移、非法 symlink、特殊文件、进程超时与输出边界，但不是 OS 文件系统或网络沙箱。

`exercise-contracts-2026-07-24.json` 当前 SHA-256 为
`5745b7cb069c8f3cb5ffa9acb0787cc378c1f36f4ac839c549ab25509c56f490`。报告记录：

- 255 章、510 次 fresh-copy exercise 运行；
- 255 章均存在标准 `EXPECTED_RED` marker，缺失 0；
- 标准 expected-red 退出码为 41，机械失败 0；
- 255 个安全标准化候选，但状态仍为 `observed-unreviewed`，禁止冒充学习者 evidence。

## 公开与私有 Runner

公开成功 evidence 位于 `verification/evidence/last-run/evidence.json`，SHA-256 为：

```text
df959abe8e1e3f11f5694bde7f85ad8e04e65937c3c7aa6362ace1256653501d
```

其当前事实为：

- `schema_version: 2`、`result: succeeded`；
- manifests 255/255、recipes 765/765、expected-nonzero recipes 255；
- 当前控制面 14 项，控制面摘要
  `dcf828981f9b5cac064d1adbcd7c5502f2aa7830aad7a68ca809d42e51a2793b`；
- 固定 Maven、pnpm、uv、Dart Pub 缓存策略；Python 禁止写 `__pycache__` 并固定 hash seed；
- Corepack 禁网配置被显式传入，Docker Compose 插件按 SHA-256 和大小冻结后放入 clean HOME；
- 每个 recipe 在独立 clean copy 中运行，失败、超时、资源越界、输入修改、非法路径或未声明输出均 fail closed。

静态重放 `ruby scripts/run-verification.rb --check --require-complete` 当前通过并报告
`manifests=255 recipes=765 inputs=4189`。这关闭的是 executable machine coverage，
不是 255 章真人教学门。

私有成功 evidence 位于被 Git 忽略的
`verification/private-evidence/last-run/evidence.json`，SHA-256 为：

```text
8f2da415443202f25fe50fbd15d3f4a816699e8113b0014affad8786199df1b4
```

其 `result: succeeded`，覆盖 255 章、255 个 recipe；私有 Runner 仅复制每章声明的最小公开
输入闭包，不再依赖 clean copy 中不存在的父目录文件。该证据只证明当前私有入口在本机固定
环境下返回 0，不公开答案内容、不进入公共 manifest，也不证明教学质量。

## P3 与 P8 内部出版候选

### P3 黄金样章

P3 当前包含 4 个黄金章节、93 个冻结输入、10 个 planned paths（其中一个是 manifest
自身）和 9 个实际输出。`ruby scripts/build-book.rb --check` 与
`ruby scripts/check-publication-output.rb` 均通过；output manifest SHA-256 为：

```text
1a479f836d0d0c8610df7839bdd3cdb2df6a82a5a5cf0732953276ce233a492f
```

P3 保持隔离 sidecar，不改写 P2 五文件站点合同，也不提升章节状态。

### P8 完整内部候选

P8 当前 plan v2 与 output manifest v2 分别为：

```text
plan     61574ce95d24dba9a670299c2349fd5b5e7096177b827f002bb05c54da96a447
manifest ed516c12b06c50441deab1238209c1df5b39778b147a333d9070f7c8df80f231
```

plan 包含 255 章、16 卷、4,205 个 Git companion 和 4,479 个总输入；声明 345 个计划路径，
其中 output manifest 为避免自引用不枚举自身，因此最终 manifest 记录 344 个实际输出与
324 条构建命令。plan check 和 output check 当前均通过。

整书关键工件摘要为：

| 工件 | SHA-256 |
| --- | --- |
| canonical AST | `52034aa906f325813a5d9b9c56fc4dc2358740cdf073b1b0f7d809d556f47adb` |
| whole HTML | `8fa9369fc891347bd6d7e81525a53e84c79db0d4e815ea1b1fdbbc189231c686` |
| whole EPUB | `e6ccc8e1cbb8ca6596fa5561361a96fb4599c1ebedeeae58395ed2836843c56b` |
| whole PDF | `ef939bbdd2c5d0ec90f1fb9cfa5083df4fe29d026009e113a82065720c2d2fc7` |

所有工件仍标记为 internal review candidate，`distribution_allowed=false`；机器构建通过不
授权公开发行。

## 最终 AST、版本来源与历史 live 结果

当前 AST v2 报告
`records/encyclopedia/evidence/machine/chapter-ast-links-v2-2026-07-24.json` 的 SHA-256 为
`6a02dc387012318926da22d24d1f1e33a0bab63e5280dc6cea7ff7ebc7a1cb0e`。它逐字节绑定当前
P8 plan、output manifest 与 canonical AST，遍历 255 章的 2,013 个最终节点：Link 2,013、
Image 0；唯一目标 1,446，其中外部 HTTPS 1,224、内部引用 222；结构失败 0。

该报告运行于 `structure-only`，1,224 个外部目标均为 `not-probed`。因此它证明最终 AST
节点清单和结构合同，不声称 2026-07-24 之后的网络可达性。旧
`chapter-live-links-2026-07-24.json` 只保留为 Markdown 正则口径的历史 live 快照，不能冒充
当前 AST v2 的 live 结果。

版本注册 v2 绑定 71 个原子条目与 93 条 official/primary 来源；当前
`version-sources-v2-2026-07-24.json` SHA-256 为
`9f51128192f614df6153e53ac59facc97f52574f842dec6a8ab0b0ae50e29aaf`，记录 93/93 可达、
失败 0。可达性仍不证明版本 claim、发布日期、兼容性或正文事实正确，也不允许自动把
`provisional`/`conceptual` 提升为 `verified`。

## 出版无障碍机器观察

`publication-accessibility-2026-07-24.json` 当前 SHA-256 为：

```text
2d0dfd93fde5e8acb966b3025d6bcd29563690333b8d060cbd193941f6a2a461
```

报告逐字节绑定当前 P8 plan 和 output manifest，覆盖 307 个工件：273 HTML、17 EPUB、
17 PDF。324 项检查全部 `passed`，机器失败 0：

- axe-core：273；
- EPUBCheck：17；
- Ace：17；
- veraPDF：17。

报告同时保留 68 个人工复核信号，全部来自 Ace 的认证元数据提示。它的声明边界固定为
`machine-only-not-certification`、`not-certified`、`human_review: required` 和
`forbidden-without-human-review`。所以“324/324 机器通过”不能改写成 WCAG、EPUB
Accessibility、PDF/UA、键盘、焦点、阅读顺序或读屏人工验收通过。

## Definition of Done v2

当前 DoD 报告
`records/encyclopedia/evidence/machine/definition-of-done-2026-07-24.json` 的 SHA-256 为：

```text
87fad3ae22899dad10f4d59015b36ab788d78f098ccf9445d394855599bfe98f
```

报告的当前状态为 `human-review-required`：

| DoD 维度 | 当前值 |
| --- | ---: |
| structurally ready | 255/255 |
| executable manifest | 255/255 |
| current Runner evidence | 255/255 |
| approved human attestation | 0/255 |
| semantic approval | 0/255 |
| passed release gates | 0/4 |
| `global_completion_ready` | `false` |
| `release_ready` | `false` |

四项真实世界发行门均保持 required：零基础学习者试学、辅助技术/真实设备矩阵、独立干净
环境构建复现、全局路线/实际版式/发行批准。仓库没有生成
`verification/release-validation.yml` 占位文件，也没有伪造真人 reviewer 或 attestation。

## 历史快照与当前事实的分界

下列文件继续保留，用于解释修复来源和迁移过程，但不是当前失败或缺口：

- `endpoint-audit-failed-975-of-1020-2026-07-24.json`：首次端点审计失败快照；当前权威端点结果为 1,020/1,020；
- `observed-candidates-v2-2026-07-24.json`：manifest 批量生成前的 251 章候选快照；当前 executable manifests 已为 255/255；
- `chapter-live-links-2026-07-24.json`：旧 Markdown 正则 live 口径；当前最终结构权威为 AST v2；
- `version-sources-2026-07-24.json`：单 URL registry v1 历史结果；当前权威为 registry/report v2；
- AI pre-review、remediation 与早期 PDF/UA 失败报告：只记录当时观察，不能覆盖当前字节或关闭真人门。

历史报告不得删除或静默改写，也不得因文件仍存在而把其中的 4/255 manifests、251 个缺口、
私有 clean-copy 失败、旧 P8 输入数或旧 PDF/UA 失败重新当作当前结论。

## 兼容性、已知不兼容与迁移影响

有意保留的兼容面：Week 00–48、49 行进度表、P2 五文件站点合同、P3 `p3-gold` v1、
P8 `internal-complete` v2、生成的周适配层和被 Git 忽略的可重建 `build/`。没有预填
FactoryCare 学习 evidence，也没有把机器 evidence 合并进学习进度。

本轮治理有意采用长期可维护的新合同，而不是双读旧证据：

- shell 入口统一到可审计的 Bash 语义；endpoint schema v2 接受经 PathGuard 校验的安全 POSIX 路径；
- exercise contract v2 固定精确 Bash 命令、`EXPECTED_RED` 和退出码 41；
- Runner evidence 从 v1 升级到 v2，旧 evidence 不提供兼容读取；
- DoD 从 v1 升级到 v2，机器合同、当前执行、真人 attestation 与发行门不再混为一体；
- 直接先修块与 Web fixture 采用显式合同，不接受隐式父目录依赖；
- runtime、缓存、Corepack 与 Docker Compose 采用确定性、显式、fail-closed 配置。

回滚必须对同一变更集执行完整 `git revert`，再从相应冻结输入重建 P2/P3/P8 和机器报告；
只恢复某个旧 schema、旧 manifest 或旧周页面会造成控制面与 evidence 字节不一致。

## 可复核命令

```bash
ruby scripts/generate-curriculum.rb --check
ruby scripts/sync-legacy-learning-entry.rb --check
ruby scripts/sync-chapter-prerequisites.rb --check
ruby scripts/validate-learning-assets.rb
ruby scripts/validate-encyclopedia.rb --check-generated
ruby scripts/build-book.rb --check
ruby scripts/check-publication-output.rb
ruby scripts/build-complete-publication-plan.rb --check
ruby scripts/build-complete-publication.rb --check
ruby scripts/run-verification.rb --check --require-complete
ruby scripts/run-private-verification.rb --check
```

`--require-complete` 当前应通过 machine manifest coverage；治理覆盖与 DoD 命令仍应因真人
attestation 和 release validation 未完成而返回非零。这是诚实的人工门，不是构建器故障。

## 明确非目标与收口判定

- 不公开发布 HTML、EPUB、PDF、站点、Release、软件包或私有答案；
- 不把 255 章从 `drafting` 晋升，不把正式 P9 标为完成；
- 不把 executable manifest、Runner 绿灯、candidate 或 AI 审查称为真人批准；
- 不声称 WCAG、EPUB Accessibility、PDF/UA 或辅助技术人工验收通过；
- 不声称 Linux、Windows、其他 patch 版本或独立执行方已复现；
- 不根据文件存在、AI 生成或一次运行推断用户已经掌握；
- 不修改真实学习时长、成绩、完成日期、求职记录或工作经历。

因此，当前最准确的结论是：**机器侧 P0–P9 工程基线已全量闭合，教材可以用于开始和继续
学习；正式 P9 仍等待 255 章独立真人复核与四项发行门，尚不可声称真人验收或可公开发行。**
