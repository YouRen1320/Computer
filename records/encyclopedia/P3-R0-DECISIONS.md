# P3-R0 出版、生命周期与发布边界决策

> 后续实施注记（2026-07-16）：R1 已拆为 R1-A（profile、显式公共工件、确定性 sidecar plan 与安全写入）和 R1-B（verification manifest 与统一 Runner）。本文件下方“已接受，尚未实施”是 R0 决策提交时的历史状态，不表示后续批次仍未开始；当前实施证据以对应 R1 记录为准。
>
> **执行节奏覆盖（2026-07-16）：** 用户随后决定 P3—P8 内容生产优先，不再逐阶段执行独立 Agent 全面复审、长审查报告、人工版式/无障碍检查、零基础试读和全仓穷举回归；这些工作统一集中到 P9。P3 的统一验证先采用代码内固定 recipe 的轻量 Runner，D5 中出版级 verification manifest、严格输出封闭与完整证据树也集中到 P9。下方 D2、D5、D6、实施顺序和 R0 完成标准保留当时决策的历史原文，不再作为 P3—P8 的即时阻塞门。最终质量要求没有取消，且延期审查期间章节不得因此晋升 `verified` 或正式公开发布。当前规则以 [`CONTENT-FIRST-EXECUTION.md`](./CONTENT-FIRST-EXECUTION.md) 为准。

## 决策状态

- 状态：**已接受，尚未实施**
- 决策日期：2026-07-16
- 决策基线：`d6cf00f`
- 决策依据：用户已明确“全部按推荐执行”；推荐组合来自 `reviews/P3-rendering-architecture-audit.md` 与 `reviews/P0-P3-integrated-audit-2026-07-16.md`
- 当前生命周期：4 个黄金样章仍为 `drafting`，251 章仍为 `planned`

“已接受”只表示方案选择完成，不表示 renderer、Runner、P2 迁移、真实读者试读或跨平台验证已经完成。本记录不是用户学习证据，不修改 `PROGRESS.md`。

## 目标与范围

本决策冻结 P3 后续实现所需的八个选择，使 R1—R4 不再同时维护互相矛盾的出版、章节状态和发布边界。

本批只更新权威文档：

- 不创建 HTML/PDF/EPUB；
- 不安装 Pandoc、WeasyPrint 或验证工具；
- 不修改 builder、validator、schema 机器行为或五个生成文件；
- 不迁移私有答案或 Git 历史；
- 不把章节提升为 `review`/`verified`；
- 不修改学习进度、远端仓库或公开发行状态。

## 已接受的八项决策

### D1：统一出版 AST

采用 Ruby 权威门禁 + canonical Pandoc JSON AST + WeasyPrint：

1. Ruby 从 canonical catalog 和显式 profile 生成确定性的 `publication-plan.json`；
2. Pandoc 只按 plan 读取有序 Markdown，解析和过滤一次，生成受摘要保护的 canonical JSON AST；
3. HTML、EPUB 和打印 HTML writer 只能消费该 AST，不能各自重新读取 Markdown；
4. WeasyPrint 只把打印 HTML 转为 PDF/UA 候选文件；
5. JavaScript 只增强搜索，HTML 正文本身必须可读。

VitePress 不是 P3 默认工具。P8 只有在真实用户证据证明静态 HTML 体验不足时才重新评估，而且不能让 VitePress 专属语法污染 canonical Markdown。

三种格式采用彼此独立的目标和证据：HTML 目标是 WCAG 2.2 Level AA；EPUB 目标是 EPUB 3.3、EPUB Accessibility 1.1 + WCAG 2.2 Level AA；PDF 目标是 PDF/UA-1。完整评估前只能写“以该标准为目标，尚未完成合规评估”，不能用“所有格式均无障碍”合并声明。截至 2026-07-16，[EPUB Accessibility 1.1](https://www.w3.org/TR/epub-a11y-11/) 是 W3C Recommendation；[1.2](https://www.w3.org/TR/epub-a11y-12/) 仍是 Working Draft，只监控，不作为正式合规基线。

P3 内部预览要求三种格式分别达到 `manual_checks_passed`，不要求也不得自动写成 `conformant`。只有逐项完成对应标准的完整评估，才能把某一格式单独标为 `conformant`：

- HTML 声明必须记录日期、准确页面或 build manifest 范围、WCAG 版本/级别、依赖技术、测试浏览器/辅助技术、评估者和报告，并覆盖完整页面、响应式变体和完整流程；
- EPUB 必须评估整本出版物、全部 XHTML、nav、spine、package metadata、fallback 和实际阅读顺序；正式声明值精确为 `EPUB Accessibility 1.1 - WCAG 2.2 Level AA`，同时记录 `a11y:certifiedBy`、评估日期和报告；
- PDF 只有机器门与人工门全部通过，且报告绑定最终分发 PDF 的 SHA-256，才可以声明已按 PDF/UA-1 完成评估。

### D2：P3 阶段终点

P3 的阶段终点是：

- 四个黄金样章完成内容、代码、安全、版本、无障碍、零基础教学和出版七类审查；
- 产生并验证真实 HTML/PDF/EPUB 内部预览；
- 至少一名符合 D6 定义的编程零基础读者完成规定试读任务，卡点和修订有记录；
- 四章满足现有 `review` 门并进入 `review`。

P3 完成不等于 `verified` 或公开发布。四章的传递硬前置闭包尚未全部 `verified`，因此公共搜索和正式发布继续为 0；P4 按依赖顺序补齐前置后再推进 `verified`。

### D3：PDF 可复现性边界

依据 [Reproducible Builds 定义](https://reproducible-builds.org/docs/definition/)，只有独立执行方依据已声明的源码、指令和环境生成 SHA-256 与逐字节完全相同的指定 PDF，才称为 reproducible build。同一台机器连续两次相同只称为本机字节重复性证据。

固定环境至少记录：源码提交与 canonical AST 摘要、模板/filter/CSS 摘要、完整命令、OS/架构、Pandoc、WeasyPrint、Python 及其 PDF 依赖、Poppler、veraPDF、字体文件及摘要、locale、timezone、`SOURCE_DATE_EPOCH`、工作目录策略和断网策略。先在两个干净目录追求 PDF 字节一致。

如果仍不能字节一致，接受以下受限结论：

- 保存同一固定环境下的页数、文本摘要、字体集合、outline、标签结构和逐页栅格摘要；
- manifest 保存实际 PDF SHA-256、`byte_reproducible: false`、`regression_scope: fixed_environment` 和 `pdfua_status: candidate`；
- 只称为“同一固定环境下的语义与版式回归证据”；
- 明确写出 PDF binary 不一致；
- 不声称 reproducible build，也不把 `Tagged: yes` 或 veraPDF 零错误冒充完整 PDF/UA 合规。

回归门至少比较页数、规范化全文及顺序、outline、链接、字体嵌入与 Unicode 映射、标签树、逐页栅格、veraPDF 结果和人工阅读顺序。像素容差必须事先固定，任何未解释漂移均失败。WeasyPrint 输出始终先称为 PDF/UA-1 候选文件；机器门和人工门全部通过且报告绑定最终 PDF SHA-256 后，才可以声明已按 PDF/UA-1 完成评估。

HTML 与 EPUB 的字节一致也必须在干净目录和固定环境复验。同机固定环境双构建相同只称为本机字节重复性；在独立执行方复现前，既不称 reproducible build，也不称跨平台可复现。

EPUB 完整评估前不得写入声称通过 EPUB Accessibility/WCAG 的 `dcterms:conformsTo`；发现元数据只能描述实际验证过的特征。EPUBCheck 与 Ace 只是证据组成，不单独证明 EPUB Accessibility。正式通过后的声明值必须精确绑定最终工件与报告；Apple Books + VoiceOver 结论只适用于记录中的具体版本。

### D4：私有答案与公共发行边界

开发权威仓保持私有，只发布经过 allowlist 验证的生成物。若未来需要公开源码，建立不携带 `solutions-private/**` Git 历史的新公共发行仓，答案继续位于独立私有存储。

不采用“只删除当前文件就公开”的做法；旧 Git 对象仍可能包含内容。历史重写只能作为另行审批的破坏性备选，而且无法撤回第三方已经取得的 clone、fork、缓存或 Release。

本决策不证明当前远端从未暴露，也不执行任何 GitHub 权限或历史操作。

### D5：显式公共工件与统一 Runner

每章采用机器可读的显式公共工件 manifest；目录清理和 `.gitignore` 不能代替发布 allowlist。

统一 Runner 的生命周期规则：

- `review/verified`：完整 verification manifest 是硬门，缺失即失败；
- `drafting`：允许不完整；存在 manifest 时执行，或由显式 P3/internal-preview allowlist 强制执行；
- 在干净临时目录执行示例、实验、练习和私有答案；
- 校验工具版本、命令、退出码、测试数量、预期失败和未声明生成物；
- 状态晋升证据不完整时 fail-closed。

章节晋升引用的证据仍必须位于 `records/encyclopedia/evidence/<chapter-id>/<gate>/`；共享批次结论放在 `records/encyclopedia/reviews/`，不新增绕过 schema 的共享 evidence 根。

### D6：真实零基础读者是 P3 硬门

本阶段选择“编程零基础”作为参与者定义：从未独立完成过程序、课程项目或真实开发任务。有其他语言开发经验但没学 Java 的参与者只能称为 Java 零基础，不能满足本门。

至少一名符合定义、未提前接触样章或答案的参与者，在固定环境中完成 20—30 分钟试读。任务至少覆盖：找到章节与前置补救、用自己的话解释一个概念、运行示例、修改一个小需求、诊断一个故障、完成 120 秒复述。允许帮助必须预先限定；环境安装帮助与任何内容提示分别记录。

记录必须包含匿名参与者画像、工件摘要、格式/章节范围、任务结果、起止时间、卡点、误解、非计划帮助、修改及复测结果。关键导航、理解或实操阻断未关闭时 P3 失败；正文修改后必须让同一参与者或另一名符合定义者复测受影响任务。

AI 自审、作者代读、自动化测试和“文件存在”都不能替代这项证据。这是发现性试点，只证明在该范围发现并处理了问题，不证明所有零基础读者都能学会或具有长期学习效果，也不替代残障用户和辅助技术测试。这是教材阶段证据，不写入用户的个人学习进度。

### D7：P3 平台基线

“跨平台”拆成三类分别记录，任一类通过都不能替代另外两类：

1. 出版构建可移植性：OS/架构、Pandoc/WeasyPrint/native dependencies 和字体；
2. 章节代码/JDK 兼容性：OS/架构、JDK 厂商/版本、shell 和构建工具；
3. 成品互操作性：浏览器、EPUB/PDF 阅读器、辅助技术及其版本。

当前三类证据状态分别是：

- 章节代码/JDK：`verified`，仅限 macOS arm64 + Eclipse Temurin 25.0.3；
- 正式出版构建：`smoke_observed`，仅有已删除临时产物的本机烟雾观察，尚无可重放 R2/R3 证据；
- 浏览器、Apple Books、PDF 阅读器和 VoiceOver 成品互操作：`not_evaluated`。

Windows、Linux、其他 JDK 25 发行版和其他阅读系统登记为 `not_tested` 的 P4 follow-up；在完成前不写“预计兼容”或“跨平台通过”。follow-up 必须记录目标矩阵、命令、验收门、证据路径和责任里程碑，并阻断对应平台支持声明。

平台差异若暴露正文或验证脚本错误，必须回修黄金样章；follow-up 不代表允许忽略已知错误。

### 证据状态与失效规则

出版证据统一使用 `not_evaluated`、`smoke_observed`、`automated_checks_passed`、`manual_checks_passed`、`conformant`、`not_tested`。只有 `conformant` 可以形成对应标准声明。

合规与试读证据绑定具体源码、AST、模板、filter、CSS、字体、工具版本和最终工件摘要。正文结构、导航、样式、信息性图片、渲染器或字体发生实质变化后，受影响格式恢复为 `not_evaluated`，不得静默继承旧结论。

即使输入未变，只要最终工件生成了新的 SHA-256，对应合规状态也不能自动继承：至少重跑全部机器门；人工证据必须重新执行，或通过预先定义的等价性审查证明仍可继承。报告中的 SHA-256 必须与实际分发工件逐字匹配。

### D8：P2 输入与摘要契约迁移

R1—R3 先在 `build/publication/` 使用隔离 sidecar plan，不修改 P2 的五个输出文件及其现有 schema/内容。

四章晋升 `review` 前，单独实施 P2 契约迁移：

- 用显式公共输入替代 `EncyclopediaInputSet.expand_public_path` 的无差别递归收集；
- 把 publication content digest 与 repository safety/audit digest 分离；
- 同步 builder、validator、schema、测试、迁移说明和回滚；
- 即使仍保留五个输出文件名，也承认其内容和摘要语义已经变化。

P8 只决定最终站点、整卷构建和发行入口，不把这项安全迁移延后到 P8。

## 实施顺序

以下顺序是 R0 接受时的历史计划。2026-07-16 后续决定已把其中 R3 的人工检查/试读、R4 独立复审及 P4—P8 的逐批全面审查集中到 P9；P3—P8 仅保留必要自动检查并连续推进内容生产。

1. R1：sidecar profile、plan、public-artifact manifest、路径/私有/状态安全门；
2. R2：canonical JSON AST、HTML/EPUB/打印 HTML 和 PDF 候选渲染；
3. R3：自动验证、人工无障碍/版式检查和编程零基础读者试读；
4. P2 migration：显式输入与双摘要契约；
5. R4：独立复审、证据归档、四章推进 `review`；
6. P4：按传递前置顺序写作并逐批推进 `verified`。

## R0 完成标准

以下条目描述 R0 文档批次当时的完成标准，其中“独立复审无 blocker”是已发生批次的历史事实，不构成后续 P3—P8 必须重复执行独立审查的规则。

- 八项选择在本文件中逐项冻结；
- `IMPLEMENTATION-CONTRACT.md`、`REVIEW-RUBRIC.md`、`schemas/README.md`、P3-B1 评审和两份 P3 审计口径一致；
- 当前机器 schema、builder、validator 和生成文件没有改变；
- 原有课程/构建验证全绿；
- `PROGRESS.md` 无差异；
- 独立复审无 blocker；
- 形成单一可 revert 的文档提交。

## 未来实施影响

- 新增 publication profile/schema、Pandoc filter/template/CSS、字体锁、Runner 和验证工具；
- P2 migration 会改变公共输入和摘要语义，属于需单独原子提交的契约迁移；
- R4 会修改四章 catalog 状态、front matter、review metadata 和 evidence 引用；
- 公共发行若启用，将新增不携带 private 历史的独立仓库流程。

## 回滚

R0 只修改文档，使用 `git revert <P3-R0-commit>` 即可完整回滚，不需要删除生成物或改章节状态。

未来 R1—R4 必须分别原子提交：

- sidecar 回滚不能误称已回滚 P2 migration；
- P2 migration 回滚必须同时恢复 InputSet、manifest schema、builder、validator 和测试；
- R4 回滚必须恢复四章 `drafting` 状态、front matter、review metadata、evidence 引用和 canonical outputs；
- 仓库结构回滚不能撤销已经发生的第三方内容传播。

## 明确非目标

- 不在 R0 证明 PDF/UA、WCAG 或 EPUB Accessibility 合规；
- 不把本机烟雾渲染当成可重放出版证据；
- 不把 P3 完成等同四章 `verified`；
- 不把平台 follow-up 伪装成已验证；
- 不为旧的 140—170 章口径保留兼容；当前 2026.2 edition 的冻结目标是 255 章。
