# P0—P3 集成审计与 P3 收口决策

## 审计结论

- 审计日期：2026-07-16
- 审计基线：`66ab0a9`（P3-B1 四个 Java 黄金样章）
- 审计性质：只读核查后的决策记录；本文件不实施架构变化
- 当前判断：**P0—P2 基础控制面可继续使用；P3-B1 内容批次通过并带后续项，但 P3 阶段尚未完成**
- 当前章节状态：251 个 `planned`、4 个 `drafting`、0 个 `review`、0 个 `verified`
- R0 决策状态：用户已确认全部八项推荐；实施状态仍为未开始，下一步按 R1—R4 推进，不直接进入 P4

本审计把“样章内容写完”“可以生成文件”“达到 P3 阶段完成”“可以公开发布”分成四个不同结论，避免把其中任何一个误当成另外三个。

## 目标、范围与完成标准

### 本次目标

1. 核对 P0—P3 之间的状态、构建、安全、依赖和出版契约是否一致；
2. 区分会阻断 P3 的问题与可以延后处理的风险；
3. 为下一批实现列出可选择方案、影响、迁移和回滚；
4. 保持 `PROGRESS.md` 不变，不把课程建设记作用户学习进度。

### 本次完成标准

- 所有结论能定位到仓库代码、配置、测试或独立烟雾验证；
- 大改只形成方案和推荐，不提前实现；
- 未验证的 HTML/PDF/EPUB、真实学习者、跨平台和远端可见性必须明确标注；
- 不修改章节生命周期、不安装发布依赖、不发布远端产物。

### 明确不在本次范围

- 不实现 Pandoc/WeasyPrint 出版流水线；
- 不迁移私有答案；
- 不修改 `site/generated` 五文件契约；
- 不补写七个基础依赖章节；
- 不建立统一代码 Runner；
- 不把任何章节提升为 `review` 或 `verified`。

## 已验证的稳定基础

### P0 回滚与学习进度边界

- P0 回滚标签仍指向 `6aa8e2358f25f126eeb29ba5920f971f7e28a549`，并且是当前提交祖先；
- P3-B1 提交为 `66ab0a9`，形成新的可回滚原子边界；
- `PROGRESS.md` 相对 P0 未变化，课程编写没有伪造学习完成记录。

### P1/P2 权威目录与控制面

- 目录当前包含 255 个稳定语义章节 ID、16 卷和四条路线；
- 校验器会检查章节状态、路径、依赖、七类证据、输出集合和传递硬前置；
- `site/generated` 当前恰好只有五个受控文件，连续构建字节一致；
- 公共搜索索引只接受 `verified`，当前 `publishable_count=0`；
- 安全测试会拒绝额外文件、符号链接、目录逃逸和私有答案进入公共 manifest。

### P3-B1 内容与代码

- 四个 Java 黄金样章均包含正文、示例、实验、练习和隔离答案；
- 已提交的 P3-B1 评审记录报告：Java 示例、正向测试、预期失败测试和 JDK 25 门禁已在本机通过；本次集成审计没有重新执行全部章节脚本；
- P3-B1 内容评审结论为 `PASS_WITH_FOLLOW_UP`，无内容级 blocker；
- 当前仍为 `drafting` 是正确状态：内容通过不等于已完成真实出版、学习者试读和跨平台验证。

## 阻断 P3 阶段完成的问题

### B1：没有真实章节出版流水线

当前 `scripts/build-book.rb` 只生成目录、导航、搜索索引、README 和 manifest。`site/index.html` 是读取目录 JSON 的静态壳，章节标题没有正文链接。仓库没有把权威 Markdown 转换成分章 HTML、PDF 或 EPUB 的正式管线，也没有这些产物的链接、无障碍、版式和确定性门禁。

因此，当前的 `BOOK BUILD CHECK OK` 只能证明控制面和五个 JSON/Markdown 产物有效，不能证明章节可阅读、可打印或可发行。

推荐方案已经在 `P3-rendering-architecture-audit.md` 中展开：保留 Ruby 权威门禁，让 Pandoc 从有序 Markdown 产生一份受摘要保护的 canonical JSON AST，再由三个 writer 生成 HTML、EPUB 和打印 HTML，最后由 WeasyPrint 生成 PDF/UA 候选文件；P3 先输出到忽略的 `build/publication/`，不打开 P2 五文件契约。

## 已确认的 P3 完成定义

### D1：四个样章无法独立达到 `verified`

四个黄金样章的传递硬前置中有七个仍为 `planned` 的基础章节：

1. `ch.foundations.terminal-shell`
2. `ch.foundations.files-paths-encoding`
3. `ch.foundations.computer-process-model`
4. `ch.foundations.cli-streams-exit-codes`
5. `ch.foundations.testing-oracles`
6. `ch.foundations.environment-tool-resolution`
7. `ch.foundations.dependencies-build-packages`

现有校验器会拒绝把硬前置闭包未全部 `verified` 的章节提升为 `verified`。这个门禁符合零基础教学逻辑，不应通过删除真实依赖或放宽验证器绕过。

这七项是传递闭包中仍为 `planned` 的基础章节，不是全部非 verified 节点。Java 草稿链还依次包含 `ch.java.platform-toolchain`、`ch.java.program-structure`、`ch.java.values-variables-types` 和 `ch.java.expressions-conversions` 自身。

现行 `IMPLEMENTATION-CONTRACT.md` 原先没有写明 P3 结束时章节必须达到 `verified`。用户现已确认 P3 以四章进入 `review` 为阶段终点，因此上述依赖不阻断 P3 内部阶段完成，但必然阻断四章晋升 `verified`、进入公共搜索与正式发布。

可行路径：

| 路径 | 实现成本 | 迁移成本 | 风险 | 回滚难度 | 长期维护 |
|---|---:|---:|---:|---:|---|
| A. P3 终点定义为四章 `review` + 真实渲染证据（已选择） | 低 | 低 | 低 | 低 | 高 |
| B. 扩大 P3，同时完成七个基础前置 | 高 | 中 | 工期与评审面扩张 | 低 | 高 |
| C. 更换为无未完成依赖的根章节样章 | 中高 | 高 | 丢失已完成样章验证价值 | 中 | 中 |

已选择 A。P3 证明模板、内容方法和出版方法可用；P4 再按前置顺序完成基础章节，届时四章才能晋升 `verified` 并公开发布。本轮 R0 同步 `IMPLEMENTATION-CONTRACT.md`、`schemas/README.md`、`REVIEW-RUBRIC.md` 和 P3-B1 评审记录。

### D2：真实学习者试读与跨平台验证的门槛

P3-B1 记录把“尚无真实零基础读者试读”和“尚未完成其他平台验证”列为 follow-up，但当前顶层契约没有明确它们是 P3 blocker 还是允许登记后进入 P4 的 follow-up。

已确认：

- 在宣布 P3 完成前，至少完成一轮编程零基础读者试读；参与者、固定任务、允许提示、卡点、误解、用时、修改和复测遵循 P3-R0 决策；
- 章节代码/JDK 已验证基线是 macOS arm64 + Temurin 25.0.3；正式出版构建仅为 `smoke_observed`，成品在浏览器/阅读器/辅助技术中的互操作为 `not_evaluated`；
- Windows/Linux、其他 JDK 发行版和其他阅读系统作为明确登记的 P4 前置 follow-up，不伪称已验证；
- 平台 follow-up 若暴露已知错误，必须回修样章；不得用 follow-up 标签掩盖错误。

## 发布前必须关闭的高风险

### H1：公共输入会递归纳入构建产物

`EncyclopediaInputSet.expand_public_path` 会递归收集 `review/verified` 章节声明的 examples、labs、exercises 和 evidence 目录下所有普通文件或符号链接，目前不排除 `target/`、`build/`、`dist/`、日志、二进制或未被 Git 跟踪的临时文件。

后果：

- 同一章在执行实验前后可能得到不同 publication manifest；
- 干净克隆和开发者本机可能收集不同输入；
- 编译产物、缓存或日志可能被意外纳入公共发布边界。

可行方案：

| 方案 | 实现成本 | 迁移成本 | 风险 | 回滚难度 | 长期维护 |
|---|---:|---:|---:|---:|---|
| A. 每章机器可读 manifest 显式列出公共源文件 | 中 | 中 | 最低；fail-closed | 低 | 最好 |
| B. 只接受 Git 已跟踪文件并拒绝已知构建目录 | 低 | 低 | 仍可能误收跟踪的无关文件 | 低 | 中 |
| C. 依赖构建前手工清理目录 | 低 | 低 | 高；不可审计 | 低 | 差 |

已选择 A；B 只作为迁移期额外安全网，不能用 C 作为发布契约。P3 内部预览先把 A 实现在隔离的 `build/publication/` sidecar plan 中，不触碰 P2；四章晋升 `review` 前，再迁移现有 `EncyclopediaInputSet` 与 publication manifest 语义。即使输出文件名仍是五个，这也是 P2 schema/内容/摘要契约变化，必须同步 builder、validator、schema、测试、影响和回滚。

### H2：答案是“构建隔离”，不是“存储隔离”

`solutions-private/**` 下当前有 12 个文件已被同一 Git 仓库跟踪；其中包含 README、验证脚本和答案工件，并非 12 份纯答案正文。现有测试证明它们不会进入公共站点 manifest，却不能阻止这些内容随仓库克隆、远端权限或 Git 历史传播。

可行方案：

| 方案 | 实现成本 | 迁移成本 | 风险 | 回滚难度 | 长期维护 |
|---|---:|---:|---:|---:|---|
| A. 主仓永久私有，只发布经过 allowlist 验证的生成物 | 低 | 低 | 权限配置错误仍可能暴露 | 低 | 中高 |
| B. 建立不携带 private Git 历史的新公共发行仓；答案留在独立私有存储 | 中 | 中 | 边界最清晰 | 中 | 最好 |
| C. 公开当前仓前重写全部相关历史并清理受控远端 | 高 | 高 | 无法撤回第三方副本、fork 或缓存 | 高 | 中低 |

已选择让开发权威仓保持私有，只发布 allowlist 生成物；若未来公开源码，则建立不携带 private 历史的新公共发行仓。C 是破坏性备选，若未来采用仍必须另行确认影响、备份、远端/fork/Release 处置和回滚边界。历史重写不能撤回第三方已经取得的副本，也不能把既有泄漏“撤销”。当前不能仅凭本地分支没有远端跟踪就判断答案从未在远端可见。

### H3：没有统一的章节代码验证协议

当前四章混用 Maven、根目录 `verify.sh`、子目录 `scripts/verify.sh` 和 `verify-failures.sh`。全局测试不会自动发现并运行每个非 planned 章节的全部代码；schema 也没有声明工具版本、命令、期望退出码、测试数量和预期失败。

推荐为每章增加机器可读 verification manifest，并由统一 Runner 在干净临时目录中：

- 自动发现全部 `review/verified` 章节并把完整 manifest 作为硬门；
- 对 `drafting` 允许验证声明暂不完整；存在 manifest 时执行，或由显式 P3/internal-preview allowlist 强制执行；
- 执行示例、实验、练习和私有答案的规定命令；
- 校验运行时版本、退出码、测试数量和预期失败预言；
- `review/verified` 缺少验证声明、状态晋升时证据不完整或产生未声明文件时 fail-closed；
- 输出可归档的批次证据。

## 中等级契约漂移

### M1：`edition.status` 没有枚举校验

`curriculum/edition.yml` 当前值为 `authoring`。编译器拒绝未知顶层键，却没有校验 status 的允许值；只有值恰好为 `architecture` 时才应用相应限制。拼写错误可能使预期门禁失效。

推荐定义明确枚举和 phase/status 合法组合，并增加拼写错误、非法组合的负向测试。

### M2：学习状态被纳入出版内容摘要

`EncyclopediaInputSet.files` 把 `PROGRESS.md` 与 `ASSESSMENTS.md` 纳入 publication manifest 输入。这样可以证明学习状态没有被悄悄修改，但也意味着一次正常学习记录更新会让书籍输出摘要失效。

推荐拆成两个摘要：

- publication content digest：只覆盖实际出版输入；
- repository safety/audit digest：继续覆盖学习状态与隔离边界。

### M3：章节数量权威口径漂移

审计时顶层 `IMPLEMENTATION-CONTRACT.md` 仍写“约 140—170 个章节 ID”，而 canonical edition 已是精确的 255 章，导致 P4—P9 存在两个权威口径。P3-R0 已把实施契约同步为当前 2026.2 edition 的 255 章。

已确认 255 是当前 2026.2 edition 的冻结目标，旧的 170 章记录只作为历史快照；不兼容旧章节数量。

## 实施顺序建议

### R0：已确认的八个决策

1. 出版架构采用 Ruby + canonical Pandoc JSON AST + WeasyPrint；
2. P3 以四章进入 `review`、具备真实渲染证据为阶段终点，并同步四份契约/评审文档；
3. PDF 若仍不能字节一致，接受“同一固定环境下的语义与版式回归证据”，并明确它不等同字节可复现或 reproducible build；
4. 开发权威仓保持私有；若公开源码，建立不携带 private 历史的新公共发行仓；
5. 公共工件采用每章显式 manifest + 统一 Runner；
6. 符合 P3-R0 定义的编程零基础读者试读作为 P3 硬门；
7. 平台证据按出版构建、章节代码/JDK 和成品互操作三类记录；Windows/Linux、其他 JDK 和其他阅读系统明确登记为 P4 follow-up；
8. 四章晋升 `review` 前单独迁移 P2 公共输入与 manifest 摘要契约；内部 preview sidecar 不能替代该迁移。

### R1：先封安全契约

- 出版 profile 和 plan schema；
- 在 `build/publication/` sidecar plan 中建立显式公共文件清单，R1—R3 不修改 P2 五文件 schema/内容；
- private、状态、路径、符号链接、额外文件和原子回滚负向测试；
- 统一 verification manifest 的最小 schema；
- `edition.status` 枚举；
- publication content digest 与 repository safety/audit digest 的职责拆分作为独立 P2 契约迁移，在 R0-8 确认后实施并同步测试。

### R2：实现四章多格式预览

- Pandoc 固定模板、Lua filter、三套 CSS、identifier、时间戳与字体锁；
- HTML/EPUB 在干净目录、固定工具、字体、locale 和 timezone 中连续构建字节一致；同机固定环境双构建相同只称为“本机字节重复性”，独立执行方复现前既不得称为 `reproducible build`，也不得称为跨平台可复现；
- PDF 尽力达到字节可重复，否则按确认后的兼容决策记录同一固定环境下的语义与版式回归证据；
- 任何产物不进入 `site/generated` v2，也不改变章节状态。

### R3：自动与人工验证

- HTML：扫描所有生成页面，检查结构、页面语言、skip link、landmarks、标题、表格、内链、键盘、焦点、320 CSS px/400% 重排和 VoiceOver；axe 零错误不等于 WCAG 合规；外链活性与离线内链门分开；
- PDF：文本层与源章节顺序/完整性、字体、`/Lang`、Title、outline、标签树、表头、代码、链接注释、artifact、图片替代文本、全页栅格、veraPDF 和真人读屏；veraPDF 零错误不能替代人工检查；
- EPUB：容器/XML、identifier、modified、nav/spine、语言和发现元数据真实性、EPUBCheck、Ace、Apple Books 重排和 VoiceOver；未完成完整评估前禁止写 `dcterms:conformsTo`，EPUBCheck/Ace 均不单独证明 EPUB Accessibility；
- 学习者：至少一名编程零基础读者按固定任务试读，记录允许帮助、卡点、误解、用时、观察、修订和复测；
- 平台：保留章节代码/JDK 的 macOS arm64 + Temurin 25.0.3 已验证基线；R2/R3 单独验证出版构建和成品互操作，其他组合按 R0 决策登记；
- 保存工具版本、命令、摘要、报告、代表截图和未验证平台。

### R4：生命周期收口

- 先完成经确认的 P2 公共输入/manifest 契约迁移，关闭现有递归收集风险；
- 四章通过内容、出版审查和编程零基础读者门后进入 `review`；
- 保持公共发布为 0，直到七个硬前置和四章全部 `verified`；
- P4 按依赖顺序补齐基础章节，再运行全量状态迁移门禁。

## 影响、迁移与回滚

### 影响

- 新增 publication 配置、模板、filter、CSS、字体锁、验证工具和 evidence；
- 新增统一章节代码执行协议；
- 若选择独立私有答案存储，需要调整本地开发与 CI 取证流程；
- R1—R3 的 sidecar preview 不改变权威章节 ID、四条路线或现有 P2 五文件输出；
- R4 前若迁移 P2 公共输入和摘要职责，五个文件名可以保留，但 schema、内容、摘要与测试都会变化，必须视为明确的 P2 契约迁移。

### 迁移

1. 先仅对四个黄金样章启用显式 profile；
2. 安全门和 Runner 先于渲染器落地；
3. 真实验证通过后才推进 `review`；
4. P4 再逐批迁移其他章节；
5. P8 才决定公共站点 v2 是否升级或替换。

### 回滚

- publication 回滚：使用原子迁移提交并优先执行 `git revert <migration-commit>`；恢复 catalog 与四章 front matter 的原状态，删除新增 publication 入口、schema、模板、filter、CSS、Runner 和 evidence 引用，再重新生成 canonical outputs；
- P2 契约回滚：若迁移过 `EncyclopediaInputSet`、publication manifest schema、builder、validator 或测试，必须整体 revert；只有完整回退并重建后才能声称五文件摘要恢复；
- 删除被忽略的 `build/publication/`；
- private 存储迁移回滚：在确认新存储完整前保留受控只读归档和映射清单；若采用新公共发行仓，回滚只停止/替换发行，不把 private 历史复制回公共仓；若采用历史重写，备份只能恢复仓库结构，不能撤销已经发生的传播；
- 重新运行 P2/P3 全量验证，五文件输出和 canonical catalog 应恢复到迁移前摘要。

## 已验证与未验证

### 本次独立复验

- P0 标签、P3-B1 提交和当前状态计数；
- curriculum、builder 与五文件字节一致校验；
- `solutions-private/**` 下 12 个文件由本地 Git 跟踪；
- `expand_public_path` 的递归收集行为；
- 七个 planned 传递硬前置。

### 由已提交评审记录继承的已报告证据

- P3-B1 记录报告 curriculum、builder、inventory、security、learning-assets 全部通过；
- P3-B1 记录报告四章本机 JDK 25 示例、实验、练习和私有答案通过；
- 渲染审计报告同一台 Mac 上的临时 HTML、EPUB 与 PDF 可行性烟雾观察，包括 82 页 PDF 和中文文本层；临时文件已删除，仓库尚无完整可重放渲染脚本、日志和输出摘要，因此不把它视为正式出版证据。

### 未验证

- 正式 HTML/PDF/EPUB 流水线，因为尚未实现；
- PDF/UA、WCAG 或 EPUB Accessibility 合规，因为缺少完整工具和人工记录；
- 真实零基础读者试读；
- Windows、Linux、其他 JDK 发行版与 CI；
- 私有答案是否曾被任何远端或第三方获得；
- 255 章全量出版性能与最终部署方式。

## 兼容性与有意保留项

- 本审计没有为向后兼容作实现妥协；推荐仍以长期可维护性为优先；
- P3 R1—R3 保留 P2 的五个输出文件外壳并用隔离 sidecar 验证新架构；四章晋升 `review` 前迁移 P2 公共输入和摘要语义，P8 只决定最终站点、整卷构建与发行入口；
- 用户已确认 PDF fallback：先追求字节一致；固定环境后仍失败时，接受语义与版式回归证据，并明确不声称 reproducible build；
- R0 已确认不兼容旧的 140—170 章口径；它只作为历史决策保留，不是当前完成条件。

## R0 已确认决定

用户已确认以下八项；R1 实现必须逐项遵守，决策接受不等于实现完成：

1. 采用 Ruby + Pandoc + WeasyPrint；
2. P3 终点采用四章 `review` + 真实渲染证据，并同步契约；
3. PDF 先追求字节一致，失败后允许同一固定环境下的语义与版式回归证据并明确披露其不等同 reproducible build；
4. 开发权威仓保持私有；若需公开源码，建立不携带 private Git 历史的新公共发行仓，答案保留在独立私有存储；
5. 公共工件采用显式 manifest，统一 Runner 作为 `review/verified` 和状态晋升硬门；
6. 编程零基础读者试读作为 P3 硬门；
7. 平台证据分三类；Windows/Linux、其他 JDK 和其他阅读系统明确登记为 P4 follow-up，不伪称 P3 已验证；
8. 内部 preview 先使用隔离 sidecar plan；四章晋升 `review` 前，单独迁移 P2 公共输入与 manifest 摘要契约。
