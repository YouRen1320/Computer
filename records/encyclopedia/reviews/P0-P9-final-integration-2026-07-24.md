# P0–P9 最终工程集成记录（2026-07-24）

## 1. 结论与边界

本轮已经完成 P0–P9 的工程化底座、课程适配层、构建链、验证链和机器审计链的统一
集成。当前教材在机器可验证的结构上没有脱离 49 周教程：255 章、765 个主学习结果
均唯一归入 Week 00–48，48 个模块和 8 个 FactoryCare 项目阶段保持同一知识源。

“工程系统完成”不等于“255 章已完成真人语义验收”。当前 255 章仍为 `drafting`，
只有 4 章拥有 reviewed final verification manifest，251 章仍缺最终清单；真人语义批准
为 0。任何机器报告都禁止自动提升章节状态。

## 2. 最终可复核结果

| 范围 | 最终结果 |
|---|---|
| 课程编译 | 255 章、16 卷、94 项能力、48 个模块、8 个 FactoryCare 阶段；生成物逐字节一致 |
| 周计划 | 49 周、765 个主学习结果唯一归属；Week 00 为 8–12 小时，Week 01–48 为 15–18 小时 |
| 路线对齐 | 三条完整阅读路线覆盖 255/255；FactoryCare 选择路线覆盖 205/255；393 条硬前置无环 |
| 学习资产 | 1,377 个 Markdown 文件、9,794 项检查通过 |
| P2 | schema v3，5 个生成文件；`content`、`audit_security`、`build_control` 输入闭包互斥并可重算 |
| P3 | 4 个黄金章节、93 个输入、9 个实际输出；计划、渲染和独立输出检查均通过 |
| P8 | 4,127 个 Git companion、4,401 个输入、345 个计划路径；344 个实际输出、324 条渲染命令 |
| PDF | Pandoc → Typst 0.15.1，17/17 PDF 候选进入 veraPDF PDF/UA-1 机器审计 |
| 链接 AST | 255 章、2,012 个最终 Link/Image 节点；1,224 个唯一外部 HTTPS 目标、222 个内部引用，结构失败 0 |
| 版本登记 | 71 个原子条目、93 条 official/primary 来源；实时可达 93/93，未自动提升 provisional/conceptual |
| 无障碍 | 307 个交付工件、324/324 项机器检查通过：273 axe、17 EPUBCheck、17 Ace、17 veraPDF |
| Definition of Done | 4/255 章结构就绪、251 章缺 final manifest、2,040 项真人审查待办、语义批准 0 |
| 自动测试 | 26 个测试文件；334 runs、21,179 assertions、0 failures、0 errors；1 个显式全量重建开关 skip |

公开四章的最终真实 fresh-copy 运行通过 4 份 manifest、12 个 recipe，其中 4 个预期
非零失败路径均按合同命中；证据 SHA-256 为
`5c04a9db90b270838f791ae4f3d095f39d58bc47513feb48b66f5c9a125e08b2`，边界为
`automated-local-only`。私有 255 章 clean-copy 全量运行在本轮早期已通过，内部证据
SHA-256 为 `a473bd1be7da6f8b79e7ea311593fc19365c239349aee147ac8711372a7d8845`；
其后涉及私有/公开端点的输入闭包未漂移，最终 `--check` 仍通过。两者都不是人工教学
批准。

无障碍正式机器报告：
`records/encyclopedia/evidence/machine/publication-accessibility-2026-07-24.json`，
SHA-256 为 `aa3452c3834ee70f077336a795db33f738a84fe4dd342361545c531f03f82658`。
324 项结果全部为 `passed`，但报告同时保留 68 个人工复核信号，并固定声明
`machine-only-not-certification`、`not-certified` 和 `forbidden-without-human-review`。

Definition of Done 报告：
`records/encyclopedia/evidence/machine/definition-of-done-2026-07-24.json`，
SHA-256 为 `78dfe2536b6adb2d622ee3808ca27585e902a0c3f074da5b52f8db5b70d6d028`。

## 3. 最终集成中发现并修复的问题

1. 版本登记 v2 已用 `reviewed_at`，P2 仍读取旧 `verified_at`。已一次性迁移为
   `registry_reviewed_at`，没有保留双读兼容层。
2. 新增 String 示例与两个行为失败实验未进入 P3 公共工件清单。已逐文件声明，P3
   输入从 89 更新为 93，公开工件从 54 更新为 58。
3. Nginx 的 `$remote_addr` 与 `$http_x_forwarded_for` 在普通 Markdown 中被 Pandoc
   误判为数学公式，Typst PDF/UA 因缺少公式替代文本而失败。已改为语义正确的行内代码。
4. 13.8 MB 整书 HTML 的 axe 默认全规则运行超过 900 秒。审计合同现固定为 WCAG
   2.0/2.1/2.2 A/AA 标签；整书实测约 252 秒，逐调用上限为 600 秒。
5. 整书 axe 结构化输出超过旧 32 MiB 瞬时限制。现使用有界 256 MiB 临时内存上限；
   正式报告只保留计数、规则 ID 和摘要哈希，不保存原始 stdout/stderr。
6. 学习资产校验器仍按旧 `chapter_ids` 周计划结构检查。已迁移为
   `chapter#outcome`、角色映射和每周唯一归属检查。

## 4. 未完成且不能自动伪造的事项

- 251 章 reviewed final verification manifest；
- 255 章技术、教学、代码、安全、无障碍、版本来源、出版导航和最终语义人审；
- 真实零基础学习者的完整试学、理解度与留存数据；
- 屏幕阅读器、键盘顺序、认知负担等人工辅助技术验收；
- 跨 macOS/Linux/Windows 的独立复现；
- 公开发行、版权编辑、印刷签样和任何第三方合规认证。

这些项目被明确列为后续验证，不影响现在开始 Week 00 学习；但在完成前，不能把
`drafting` 批量改成 `verified`，也不能声称百科全书已经获得真人教学或无障碍认证。

## 5. 兼容性处理与有意破坏

- 保留 P2 的五个历史文件名和历史测试文件名，内部契约升级到 schema v3；
- 保留 `weeks/` 与 `learning-kits/` 作为自动生成适配层，不保留第二套手写教程；
- 保留 P3 schema v1 与 WeasyPrint 黄金样章分支；P8 仍使用 schema v2，但 PDF 内部
  渲染器改为 Typst，旧草稿 PDF 字节与旧命令 ID 不兼容；
- 旧链接 v1 报告只作历史留档，不兼容或冒充 AST v2；
- 版本登记 v2 有意拒绝旧 `source_url` 和已拆分聚合 ID，不提供双读兼容；
- 没有为了兼容旧输入而保留 `input_digest`；P2 只接受分类摘要与总摘要。

## 6. 复核命令

```bash
ruby scripts/generate-curriculum.rb --check
ruby scripts/validate-encyclopedia.rb --check-generated
ruby scripts/validate-learning-assets.rb
ruby scripts/build-book.rb --check
ruby scripts/check-publication-output.rb
ruby scripts/build-complete-publication-plan.rb --check
ruby scripts/build-complete-publication.rb --check
ruby scripts/run-private-verification.rb --check
ruby scripts/run-verification.rb --check
```

`ruby scripts/run-verification.rb --check --require-complete` 当前必须失败并报告
`251 of 255 chapters lack final manifests`。这是未完成人审清单的真实状态，不是构建器
故障。
