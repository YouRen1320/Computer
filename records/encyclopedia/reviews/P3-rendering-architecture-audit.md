# P3 渲染与出版架构审计

## 状态

- 审计日期：2026-07-16
- 审计基线：`66ab0a9`（四个 Java 黄金样章批次）
- 决策状态：**已形成推荐，尚未实施架构变更**
- 推荐：方案 A——保留 Ruby 权威门禁，以受摘要保护的 canonical Pandoc JSON AST 建立 HTML/EPUB/打印 HTML 管线，再由 WeasyPrint 生成 PDF/UA 候选文件
- 当前 P3 状态：未完成；四章仍为 `drafting`

这是一次大改前的选项审查。它不安装依赖、不改变 `site/generated` v2 契约、不提升章节状态，也不产生用户学习完成记录。

## 目标与范围

目标是让同一组权威 Markdown 章节可以产生：

1. 无 JavaScript 也能阅读全文的分章静态 HTML；
2. 可重排、有目录与可访问性元数据的 EPUB3；
3. 有中文文本层、书签、页码、运行页眉和可验证结构的 PDF/UA 候选文件；
4. 能证明章节状态过滤、私有答案隔离、输入摘要、工具版本、输出摘要和人工复核结论的 publication manifest。

推荐把 P3 范围定义为四个黄金样章的**受控审查预览**，并以进入 `review`、具备真实渲染证据和零基础读者试读为阶段终点；这项完成定义尚待用户确认，确认后需要同步顶层契约和评审记录。无论如何，P3 都不授权把 `drafting` 章节公开发布，也不要求此时替换 P2 的公共站点契约。P8 才决定全 16 卷的最终部署与发行入口。

## 当前事实与问题

### 已验证的仓库事实

- `site/index.html` 是目录壳；`site/assets/site.js` 只读取 `generated/catalog.json`，章节标题没有正文链接。
- `scripts/build-book.rb` 只生成 5 个受控文件：`README.md`、`catalog.json`、`navigation.json`、`publication-manifest.json`、`search-index.json`。
- 构建器、校验器和安全测试共同要求 `site/generated` **恰好**包含这 5 个普通文件；多一个文件、符号链接、字节漂移或原子替换失败都会被拒绝。
- `publish_statuses` 固定为 `[verified]`，`preview_statuses` 固定为 `[review]`，但当前 builder 没有消费 preview 状态。
- `solutions-private/` 被 manifest、公共输出和安全测试显式排除。
- 四个黄金样章均为 `drafting`。第一章还硬依赖 planned 状态的 `ch.foundations.dependencies-build-packages`，因此即使渲染成功，也不能绕过传递前置闭包直接成为 `verified`。
- 根 `.gitignore` 已忽略 `build/` 和 `dist/`，适合放可再生的本地出版物；这不等于这些目录天然安全，新的 publisher 仍需路径、符号链接和原子替换测试。

### 当前工具烟雾验证

本机已有 Pandoc 3.9.0.2、WeasyPrint 68.1、Poppler 26.05、`xmllint`、`unzip` 和 Apple Books；未安装 EPUBCheck、veraPDF、Ace by DAISY 与 axe-core。

只读审稿人在系统临时目录把四章直接转换为 HTML5、EPUB3 和 PDF/UA-1 候选文件，随后删除临时产物。观察结果：

- HTML 可以生成；在同一台 Mac、同一工具环境的连续两次烟雾构建中字节一致；
- EPUB 可以生成；默认随机 identifier 会漂移，固定 identifier 与 `SOURCE_DATE_EPOCH` 后，在同一环境的连续两次烟雾构建中字节一致；
- PDF 可以生成，共 82 页、A4、PDF 1.7、`Tagged: yes`，无 JavaScript；
- PDF 字体已嵌入并带 Unicode 映射，`pdftotext` 提取出 133,038 字节、4,425 行，中文文本层存在；
- 抽查页未见中文黑块，但默认 TOC 占两页、没有页码与运行页眉，长代码块会跨页；
- 默认样式触发 WeasyPrint 不支持的 CSS 警告；系统字体混用 Times、Songti、Hiragino、Menlo、PingFang 与 Nanum，无法作为跨平台基线；
- PDF 即使固定 identifier，连续构建仍非字节一致。

这些只是可行性烟雾证据。临时文件已删除，且没有 EPUBCheck、PDF/UA 独立验证和真实读屏记录，因此不能冒充 P3 渲染完成证据。

## 可行方案

### 方案 A：Ruby 权威门禁 + Pandoc 单一出版 AST + WeasyPrint（推荐）

Ruby 从 canonical catalog 生成唯一 `publication-plan.json`，负责章节顺序、状态过滤、路径安全、输入摘要与私有答案隔离。Pandoc 按该计划把有序 Markdown 解析、过滤一次，产生一份受摘要保护的 canonical JSON AST；HTML、EPUB 和打印 HTML writer 只能消费这份 AST，不能重新读取 Markdown。分章 HTML 由固定章节边界从 AST 投影，WeasyPrint 仅把打印 HTML 转换为 PDF/UA 候选文件。

优点：

- HTML、EPUB 与 PDF 共享同一 Markdown 解析器、Lua filter、标题 ID 和链接重写逻辑；
- 现有 Ruby 校验器继续是唯一发布政策来源；
- P3 输出先隔离在 `build/publication/`，不破坏 v2 的 5 文件公共契约；
- JavaScript 只增强搜索，正文初始 HTML 本身可读；
- P8 若继续采用，16 卷可按 profile 构建整套或分卷出版物。

代价与风险：需要编写模板、filter、三套 CSS、字体锁、manifest 和验证器；技术文档站的交互体验需自行维护，不能直接获得完整主题生态。

### 方案 B：Ruby 门禁 + VitePress HTML + Pandoc/WeasyPrint EPUB/PDF

Ruby 仍生成允许渲染的章节投影；VitePress 负责 HTML 站点，Pandoc/WeasyPrint 负责 EPUB/PDF。

优点：VitePress 专为 Markdown 技术文档生成静态 HTML，提供成熟的导航、代码块、主题与 Vue 扩展；本机 Node 22 满足当前官方前置要求。

代价与风险：

- 同一 Markdown 要经过 VitePress 与 Pandoc 两套解析器，标题 ID、脚注、raw HTML、链接和扩展语法可能漂移；
- Node/pnpm lock 与 Pandoc/Python 工具链同时存在，离线、供应链和升级面更大；
- 必须先把允许章节投影到隔离 source root，否则 VitePress 的文件路由可能把 planned 正文或不应公开的资源纳入构建；
- 长期 HTML 体验较强，但出版一致性和回归成本高于方案 A。

### 方案 C：Quarto Book 全面接管 HTML/EPUB/PDF 出版层

保留 canonical catalog，但把目录投影、模板和多格式渲染交给 Quarto Book，并选用 Typst 或 HTML→PDF 后端。

优点：多格式书籍能力集中，目录、交叉引用和主题生态成熟。

代价与风险：本机尚未安装，当前无法验证；会引入第二套项目/配置模型，与现有 Ruby compiler、状态门和 manifest 职责重叠；迁移面最大，回滚和离线版本固定更难。除非以后明确决定替换当前出版层，不建议 P3 采用。

## 决策维度比较

| 维度 | A：Pandoc 单一 AST | B：VitePress + Pandoc | C：Quarto 接管 |
|---|---|---|---|
| 实现成本 | 中 | 中高 | 高 |
| 迁移成本 | 低；新增隔离层 | 中；HTML 架构新增 Node 投影 | 高；重整出版配置和职责 |
| 主要风险 | 自维护站点模板/CSS | 双解析器漂移、供应链扩大 | 双权威、迁移失败、工具未验证 |
| 回滚难度 | 低；删除新入口即可 | 中低；删除 Node 站点投影 | 中高；需恢复被接管的出版职责 |
| 长期维护 | 高；格式语义统一 | 中；HTML 强但双栈回归重 | 中；工具集中但与现有 compiler 重叠 |
| 私有/状态门复用 | 直接复用 | 需对两条管线分别证明 | 需重新集成并证明 |
| HTML 交互体验 | 够用，需自建增强 | 最强 | 较强 |
| HTML/EPUB/PDF 一致性 | 最强 | 中 | 较强，依后端而定 |

## 推荐与判断边界

推荐方案 A。这个结论是结合当前仓库证据作出的工程判断，不是“Pandoc 对所有文档站都优于 VitePress”的普遍事实。

选择 A 的原因：这套百科不仅是网站，还是分卷书、长期参考书和可审计课程。当前最昂贵的风险不是缺少炫酷主题，而是三种格式出现不同章节、不同链接和不同发布边界。一份受摘要保护的 canonical Pandoc JSON AST 与既有 Ruby 门禁把这个风险降到最低。

VitePress 可在 P8 重新评估：如果真实用户测试证明 Pandoc 静态站的搜索、导航或交互达不到要求，再以相同 `publication-plan.json` 作为唯一 source projection 添加 VitePress；不要在 P3 同时引入两套尚未被需求证明的渲染器。

## 实施前置风险

出版实现开始前，还必须关闭 `P0-P3-integrated-audit-2026-07-16.md` 记录的两个输入边界问题：

1. 当前 `expand_public_path` 会递归纳入 examples、labs、exercises 和 evidence 目录里的 `target/`、`build/`、日志与其他临时文件；推荐改为每章显式公共文件 manifest，并让构建目录 fail-closed；
2. `solutions-private/` 虽不会进入公共生成物，但已有答案工件和验证脚本仍由同一个 Git 仓库跟踪；若主仓未来公开，仅迁移当前文件不够，推荐建立不携带 private Git 历史的新公共发行仓，并把答案留在独立私有存储。历史重写是破坏性备选，也无法撤回第三方已经取得的副本。

这两项不是 Pandoc、VitePress 或 Quarto 能自动解决的问题。无论选择哪套渲染器，都应由 Ruby publication plan 和安全回归测试统一执行发布边界。

## 推荐目标结构

```text
publication/
  README.md
  profiles/
    p3-gold.yml
  templates/
    html.html
    print.html
  filters/
    chapter-contract.lua
  assets/
    screen.css
    print.css
    epub.css
  fonts.lock.yml
scripts/
  build-publication.rb
  verify-publication.rb
tests/publication/
records/encyclopedia/evidence/<chapter-id>/<gate>/
records/encyclopedia/reviews/<publication-batch-review>.md
build/publication/<profile>/
  ast/book.json
```

- `publication-plan.json` 和所有 HTML/PDF/EPUB 放在忽略的 `build/publication/`；
- 批次汇总放在 `records/encyclopedia/reviews/`；章节晋升所引用的验证报告、截图、工具版本、摘要与人工结论必须分别落在现有 schema 允许的 `records/encyclopedia/evidence/<chapter-id>/<gate>/`，且不含本机绝对路径和敏感信息；
- P3 profile 可以显式 allowlist 四个 `drafting` 章节，但页面标题、正文开头和文档元数据必须包含可感知的“内部审查预览”文字标识，并禁止复制到公开站点；标识不能仅靠颜色或背景水印，也不能在每页反复打断读屏；
- 常规 preview 只接受 `review`，正式发布只接受 `verified`；任何 profile 都不得读取 `solutions-private/`；
- 构建期间只允许本地 `file:`/`data:` 资源；外部 HTTPS 只作为可点击来源，不在构建时抓取。

## 分阶段实施与完成标准

### R1：出版计划与安全边界

- 定义 profile schema、输出 schema 和工具版本清单；
- Ruby 确定性生成 `publication-plan.json`；
- P3 preview 的显式公共文件清单先作为 `build/publication/` 中的 sidecar plan，仅约束新 publisher，不修改现有 `EncyclopediaInputSet`、`publication-manifest.json` 或五文件 schema；
- 正反测试覆盖 planned/drafting/review/verified、显式 P3 allowlist、路径穿越、符号链接、额外文件、原子替换和 rollback；
- 私有答案路径与已知答案标记在计划、AST 和输出中均为 0；
- 不修改 `site/generated` 五文件集合。

在四章从 `drafting` 晋升 `review` 之前，必须另行确认 P2 契约迁移：把现有 `EncyclopediaInputSet.expand_public_path` 改为显式公共输入并决定 publication manifest 摘要职责。即使输出文件名仍是五个，这也会改变 P2 的 schema、内容和摘要语义，必须同步 builder、validator、schema、测试、影响和回滚；不能用 sidecar plan 假装现有 P2 风险已经关闭。

### R2：同源多格式渲染

- Pandoc 固定模板、Lua filter、identifier、时间戳和三套 CSS；有序输入只解析一次并生成带摘要的 canonical JSON AST，三个 writer 只能读取该 AST；
- 分章 HTML 含 `lang=zh-CN`、skip link、`header/nav/main/footer`、章节目录和前后章链接；
- EPUB3 含固定 identifier、modified、导航/spine、`dc:language`、各 XHTML 的 `lang/xml:lang`，以及与内容事实一致的 accessibilityFeature、accessMode、hazard 等发现元数据；完成全部 WCAG 与 EPUB Accessibility 评估前禁止写入 `dcterms:conformsTo`；
- 打印 HTML 含 A4、页码、运行页眉、标题避孤、表头重复和代码块分页策略；
- WeasyPrint 生成 PDF/UA 候选文件；字体必须有许可、版本、摘要并强制嵌入。

### R3：自动与人工验证

| 目标 | 自动门 | 人工门 |
|---|---|---|
| HTML | 对所有生成页面扫描：唯一 `<title>`/ID、页面语言、skip link、landmarks、标题结构、表头关联、内链 0 失败、HTML validator、axe/ACT、320 CSS px 与 400% 重排；正文无 JavaScript 也可用；外链在线活性另行报告 | 全键盘与焦点、VoiceOver rotor、代码横向滚动区键盘可达、表格、重排后不丢内容或功能 |
| PDF | `pdfinfo`、`pdffonts`、`pdftotext`、全文哨兵/顺序/完整性比较、全页栅格、veraPDF；检查 `/Lang`、Title、outline、标签树、标题层级、表头、代码块、链接注释、图片替代文本和 artifact 标记 | 搜索/复制中文、标签与完整阅读顺序、目录、章节首页、代码/表格分页、装饰图片、页码/页眉/页脚、VoiceOver |
| EPUB | 固定环境双构建摘要、`unzip -t`、XML、identifier/modified/nav/spine/语言/发现元数据真实性、EPUBCheck、Ace by DAISY | 在记录版本的 Apple Books + VoiceOver 中检查目录、前后章、代码、表格、字体/行距/颜色覆盖、放大、深色模式和重排 |
| 离线/安全 | 断网二次构建、无 HTTP 资源抓取、无本机绝对路径、无 private bytes | 抽查 manifest 与输出 |

自动工具不能替代人工可访问性检查：axe 零错误不等于 WCAG 合规，EPUBCheck 只检查 EPUB 结构，Ace 也不能证明完整 EPUB Accessibility；veraPDF 只覆盖机器可验证的 PDF/UA 条款。Apple Books 与 VoiceOver 的结果也只代表记录中的具体版本和阅读系统。没有完整自动门、人工门和适用范围记录时，只能标记未验证，不能宣称 PDF/UA、EPUB Accessibility 或 WCAG 通过。

### R4：生命周期收口

- 若用户确认推荐完成定义，四章通过内容评审、渲染评审、P3 七维审查和至少一轮真实零基础读者试读后可进入 `review`；
- Windows/Linux 与其他 JDK 是否为 P3 硬门仍待确认；推荐把 macOS/JDK 25 作为 P3 已验证基线，并将其他平台明确登记为 P4 follow-up；
- P3 阶段完成不等于四章 `verified` 或公开发布；
- 要成为 `verified`，还必须补齐并验证传递硬前置，尤其是 `ch.foundations.dependencies-build-packages`；
- 渲染成功绝不自动修改章节状态或 `PROGRESS.md`。

## PDF 确定性决策

- HTML 与固定 identifier/时间戳后的 EPUB：本机烟雾测试曾观察到连续两次字节一致；正式门仍要求在干净目录、固定工具、字体、locale 和 timezone 后复验，未做跨机验证时不得外推为跨平台可复现构建；
- PDF：当前实测无法字节一致。R2/R3 必须先尝试固定字体、元数据、identifier、工具版本和环境；
- 若仍不一致，不得降低事实标准或伪造稳定摘要。允许的显式兼容选项是：记录页数、文本摘要、字体集合、书签结构和逐页栅格摘要，把它们称为“同一固定环境下的语义与版式回归证据”；这不等同于 PDF 字节可复现，也不满足 reproducible build 声明。是否接受这一兼容项，必须在实施前单独确认。

## 影响、迁移与回滚

### 影响

- 新增 Pandoc、WeasyPrint、字体和验证工具的版本/供应链面；
- 新增 publication schema、profile、模板、filter、CSS、测试与 evidence；
- R1—R3 的内部预览不改变 canonical Markdown、课程目录 ID、四条路线、`site/generated` v2 或 private solution 位置；
- R4 若获确认并把四章推进到 `review`，会修改 catalog、章节 front matter、review metadata 和 evidence 引用；在此之前还必须单独迁移 P2 输入/manifest 语义。

### 迁移

1. 先只对 P3 四章启用显式 profile；
2. 完成 R1 安全门后再接渲染器；
3. 通过 R3 后记录证据并把章节推进到 `review`；
4. P8 再评估整卷、整站和是否扩展/替换公共站点 v2。

### 回滚

- publication 迁移使用原子提交，回滚时优先执行 `git revert <migration-commit>`；恢复 catalog 与四章 front matter 的原状态，删除 publication 入口、profile、模板、filter、CSS、测试和 evidence 引用，再重新生成 canonical outputs；
- 删除忽略的 `build/publication/`；
- 若实施过 P2 `EncyclopediaInputSet`、manifest schema、builder、validator 或测试迁移，必须一并 revert；完整回退后重新运行 P2/P3 验证，`site/generated` 五文件摘要才应恢复为实施前结果；
- 不回滚章节 ID 和路线。仅当 R1—R3 sidecar 从未改动 v2 builder 时，v2 builder 无需回滚；若实施过 P2 输入/manifest 迁移，则按上一项整体 revert。若曾把章节推进到 `review`，必须同步回滚状态、review metadata 和 evidence 引用，否则校验会失败；
- private 存储/公共发行仓的迁移与 publication 回滚分开处理；恢复仓库结构不能撤销已经发生的内容传播。

## 明确非目标

- 本批不安装 EPUBCheck、veraPDF、Ace、axe 或 Quarto；
- 不提交 82 页烟雾 PDF 或其他临时二进制；
- 不把 `drafting` 当成 `review`/`verified`，不公开未验证正文；
- 不把 PDF `Tagged: yes` 等同 PDF/UA 合规；
- 不宣称系统字体可以跨平台复现；
- 不在本审计中部署网站、发布 Release 或修改用户学习进度。

## 官方依据

- [VitePress：Markdown 生成静态 HTML 的定位与适用场景](https://vitepress.dev/guide/what-is-vitepress)
- [VitePress：当前安装前置与文件路由](https://vitepress.dev/guide/getting-started)
- [Pandoc 官方手册与多格式示例](https://pandoc.org/MANUAL.html)
- [WeasyPrint 68.1：PDF 输出与 PDF/UA 验证责任](https://doc.courtbouillon.org/weasyprint/v68.1/api_reference.html#pdf)
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- [EPUB Accessibility 1.1](https://www.w3.org/TR/epub-a11y-11/)
- [EPUB Accessibility Techniques 1.1](https://www.w3.org/TR/epub-a11y-tech-11/)
- [EPUBCheck 官方文档](https://w3c.github.io/epubcheck/docs/)
- [veraPDF 验证范围](https://docs.verapdf.org/validation/)
- [Ace by DAISY](https://github.com/daisy/ace)
- [Quarto Book](https://quarto.org/docs/books/)

## 实施前需要确认的决策

1. 是否采用推荐的方案 A，而不是 B 或 C；
2. 若固定环境后 PDF 仍无法字节一致，是否接受“同一固定环境下的语义与版式回归证据 + 明确披露 binary 不一致”，还是把 PDF 构建继续视为阻断；该证据不称为 reproducible build；
3. P3 是否以四章进入 `review`、完成七维渲染审查并完成至少一轮真实零基础读者试读为阶段终点，把 `verified` 与公开发布留给硬前置闭包完成之后。

private 历史、统一 Runner、跨平台门和 P2 输入/manifest 迁移等另外五项决策，以 `P0-P3-integrated-audit-2026-07-16.md` 的 R0 清单为准，不能只确认本节三项就开始 R1。
