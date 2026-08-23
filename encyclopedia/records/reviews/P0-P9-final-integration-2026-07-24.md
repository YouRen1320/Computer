# P0–P9 最终工程集成记录（2026-07-24）

## 1. 集成结论与边界

P0–P9 的课程单一权威源、49 周兼容层、P2/P3/P8 出版链、公开/私有验证链和 P9 机器
审计链已经完成当前字节上的工程集成。255 章的 executable manifests 与 current Runner
evidence 均为 255/255；公开 765 个 recipe 和私有 255 个 recipe 均成功。路线、出版、AST
和无障碍报告也已重新绑定最终 P8 工件。

这不是“255 章已完成真人语义验收”或“可以公开发行”。Definition of Done v2 仍记录独立
真人批准 0/255、semantic approval 0/255、release gate 0/4，因而
`global_completion_ready=false`、`release_ready=false`。255 章继续为 `drafting`；
`PROGRESS.md` 未被本轮工程结果改写。

## 2. 当前最终可复核结果

| 范围 | 当前结果 |
| --- | --- |
| 课程编译 | 255 章、16 卷、94 项 capability、394 条硬前置；生成适配层仍引用同一 canonical 内容 |
| 周计划 | Week 00–48 共 49 周；每章 3 个 outcome，共 765 个主学习结果并保持唯一归属 |
| 路线对齐 | `zero-base`、`accelerated-48`、`reference` 各覆盖 255/255；48 模块 primary 唯一；FactoryCare selective 路线 8 阶段、93 acceptance ID、覆盖 206/255 |
| P2 | 五文件站点合同逐字节检查通过；schema v3 的 `content`、`audit_security`、`build_control` 输入闭包可重算 |
| P3 | 4 个黄金章节、93 个输入、10 个计划路径、9 个实际输出；output manifest SHA-256 为 `1a479f836d0d0c8610df7839bdd3cdb2df6a82a5a5cf0732953276ce233a492f` |
| P8 | 255 章、16 卷、4,205 companions、4,479 inputs、345 planned paths、344 actual outputs、324 条命令 |
| endpoint | 1,020/1,020 通过，失败 0；exercise 为 255/255 `EXPECTED_RED`、机械缺口 0 |
| public Runner | 255/255 manifests、765/765 recipes、255 个 expected-nonzero recipe 成功 |
| private Runner | 255/255 internal-only recipes 成功，不泄露私有路径或答案内容 |
| 链接 AST | 255 章、2,013 个最终节点、1,224 个唯一外部 HTTPS 目标、222 个内部引用、结构失败 0；本轮为 structure-only |
| 版本登记 | 71 个原子条目、93 条 official/primary 来源；审计日 93/93 可达、失败 0 |
| 无障碍 | 307 个工件；324/324 机器检查通过、失败 0、人工复核信号 68；明确 `not-certified` |
| Definition of Done | structural / manifest / current Runner 均 255；真人 attestation 0、semantic approval 0、release gate 0/4 |

关键证据摘要：

| 证据 | SHA-256 |
| --- | --- |
| public Runner evidence v2 | `df959abe8e1e3f11f5694bde7f85ad8e04e65937c3c7aa6362ace1256653501d` |
| private Runner evidence | `8f2da415443202f25fe50fbd15d3f4a816699e8113b0014affad8786199df1b4` |
| P8 publication plan v2 | `61574ce95d24dba9a670299c2349fd5b5e7096177b827f002bb05c54da96a447` |
| P8 output manifest v2 | `ed516c12b06c50441deab1238209c1df5b39778b147a333d9070f7c8df80f231` |
| AST links v2 | `6a02dc387012318926da22d24d1f1e33a0bab63e5280dc6cea7ff7ebc7a1cb0e` |
| publication accessibility | `2d0dfd93fde5e8acb966b3025d6bcd29563690333b8d060cbd193941f6a2a461` |
| Definition of Done v2 | `87fad3ae22899dad10f4d59015b36ab788d78f098ccf9445d394855599bfe98f` |

## 3. 最终集成中关闭的问题

1. **机器合同覆盖从 4/255 补到 255/255。** 旧 251 章 candidate 通过同一次完整
   1,020/1,020 endpoint 证据生成 executable manifests；provenance 明确标注
   `machine-generated-executable-contract` 与 `not-human-reviewed`，没有伪造真人 final。
2. **公开 Runner 完成全量重放。** evidence v2 记录 255 manifests、765 recipes、255 个
   expected-nonzero recipe；路径合同支持经过 PathGuard 校验的安全 POSIX 文件名，仍拒绝
   绝对路径、穿越、反斜杠、控制字符、symlink 和未声明输出。
3. **私有 clean-copy 输入闭包已修复。** 每章私有入口只复制显式声明的同章公开输入，完整
   255/255 clean-copy 执行成功；早期父目录引用导致的失败不再是当前状态。
4. **运行环境从隐式继承改为显式固定。** Runner 保留调用者 PATH 优先级；Java、Node/pnpm、
   Python、Dart/Flutter、Maven/uv 缓存、Corepack 禁网和 Docker Compose 插件均通过明确策略
   进入 clean HOME。Python 禁止写 bytecode 并固定 hash seed。
5. **P3/P8 冻结输入已重建。** P3 最终为 93 inputs / 9 outputs；P8 最终为 4,205
   companions / 4,479 inputs / 345 planned / 344 actual，并由 plan/output check 校验。
6. **链接审计迁移到最终 AST。** v2 绑定当前 P8 canonical AST，遍历 2,013 个最终节点且
   结构失败 0；旧正则 live 报告明确降为历史快照。
7. **出版无障碍管线绑定最终工件。** 273 axe、17 EPUBCheck、17 Ace、17 veraPDF，共
   324/324 机器检查通过；68 个 Ace 元数据人工信号仍保留，机器绿灯没有冒充认证。
8. **DoD v2 分离机器、人审与发行。** 结构、manifest、current execution 可各自为 255，
   同时仍能诚实报告真人 0、release required，避免机器覆盖自动晋升章节。

## 4. 历史快照不再代表当前缺口

以下报告有意保留以解释修复过程，不删除也不重写历史：

- `endpoint-audit-failed-975-of-1020-2026-07-24.json` 是首次失败快照；当前端点为 1,020/1,020；
- `observed-candidates-v2-2026-07-24.json` 的 251 候选是 manifest 生成前快照；当前 manifests 为 255/255；
- 旧 public evidence 中的 4 manifests / 12 recipes 与旧 private clean-copy 失败不再是当前结果；
- `chapter-live-links-2026-07-24.json` 与 `version-sources-2026-07-24.json` 分别是 link/registry v1 历史口径；
- AI pre-review、remediation、早期 P8/PDF/UA 报告只绑定当时字节，不能覆盖当前 P8、AST、accessibility 或 DoD v2。

保留历史不等于保留旧结论。当前状态必须以本记录第 2 节列出的最终证据及其 SHA-256 为准。

## 5. 尚未关闭且不能自动伪造的事项

- 255 章与当前 manifest、Runner evidence 和源提交绑定的独立真人 review attestation；
- 真实零基础学习者按固定任务完成导航、运行、修改、诊断、复述与复测的观察证据；
- 目标浏览器、阅读器和真实设备上的键盘、焦点、缩放/重排、阅读顺序与 VoiceOver/读屏验收；
- 由独立执行方在干净环境中的最终构建复现；
- 全局路线、最终 HTML/EPUB/PDF 实际版式和公开发行批准；
- 外部来源对正文 claim 的逐条人工蕴含判断，以及必要的版权、编辑、印刷或第三方认证。

仓库因此没有生成 `verification/release-validation.yml`，也没有将 255 章从 `drafting`
改为 `verified`。这些人类门不阻止现在开始 Week 00 学习，但在真实关闭前不能声称教材已
完成真人验收、无障碍认证、跨平台复现或公开发行准备。

## 6. 兼容性处理与有意不兼容

保留的兼容面：P2 五个历史站点文件、P3 `p3-gold` schema v1、P8
`internal-complete` schema v2、Week 00–48 编号、49 行进度表以及自动生成的
`weeks/` / `learning-kits/` 适配层。它们继续服务旧入口，但不形成第二套手写正文。

为长期可维护性，本轮没有为旧证据保留双读兼容层：

- Bash 入口语义统一并规范化；
- endpoint schema 升级到 v2 的安全路径合同；
- exercise contract v2 固定精确 Bash 命令、`EXPECTED_RED` 和退出码 41；
- Runner evidence v1 升级到 v2，旧 evidence 有意失效；
- DoD v1 升级到 v2，机器、人审和发行门分离；
- 直接先修块与 Web fixture 改用显式输入合同；
- runtime/cache/Corepack/Docker Compose 改为显式确定性策略。

兼容性折中只有“保留旧入口名称与历史报告供迁移阅读”；旧 schema、旧 evidence 和旧数字
不被当作当前状态继续接受。需要回滚时应对完整变更集执行 `git revert`，再从匹配的冻结输入
重建全部生成物，不能只恢复单个旧清单或报告。

## 7. 当前重放命令

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

本轮只读复核中，公开静态合同报告
`VERIFICATION CONTRACTS VALID manifests=255 recipes=765 inputs=4189`；私有静态合同报告
`PRIVATE VERIFICATION CONTRACT VALID chapters=255`；P2、P3、P8 的上述检查也全部通过。
治理 coverage / DoD 命令仍应因真人 attestation 和四项 release validation 未完成返回非零。

## 8. 最终判定

**已验证：** 当前 P0–P9 机器工程链、255 章公开 executable coverage、255 章私有 clean-copy、
P3/P8 当前输出、最终 AST 结构和无障碍机器检查。

**未验证：** 真人逐章语义批准、零基础试学、人工辅助技术、独立构建复现和最终发行批准。

所以现在可以依据同一套百科与 49 周适配层开始学习，但不能把机器集成完成表述成教材已由
真人验收或已经具备公开发行资格。
