# P3 sidecar 出版管线

本目录实现 P3-R0 已确认的隔离出版控制面。R1—R3 只在被 Git 忽略的
`build/publication/<profile-id>/` 生成内部工件，不修改 `site/generated` 的
P2 五文件契约，也不自动修改章节状态或 `PROGRESS.md`。

## 权威边界

- `profiles/` 只用显式章节 ID 选择内容，不接受 glob、卷查询或自由输出路径；
- schema v1 只支持当前 P3 `internal-preview`；`release/public` 必须在未来以新 schema 版本完整建模，不能复用内部 `noindex` 通知和内部输出枚举；
- `manifests/public-artifacts/` 逐文件声明四个黄金样章的公开工件；
- `toolchain.yml` 区分当前观察值与仍待 R3 固定的工具，不把本机观察冒充长期或跨平台支持；
- 工具 ID、命令、启用阶段和观察/延期状态由 Ruby allowlist 固定；YAML 只能记录安全的版本前缀和说明，不能注入任意命令或正则；
- `schemas/publication-*.schema.json` 与 `schemas/public-artifact-manifest.schema.json`
  是 P3 独立 schema v1；P3 只通过严格校验后的 baseline 消费 P2 runtime schema v3，
  不把两套 schema 合并；
- 输出目录由合法 `profile_id` 推导，配置不能把 sidecar 指向 `site/generated`；
- 章节 Markdown 由 canonical catalog 选择，不在公共工件清单中重复登记。

R1-A 的入口是：

```bash
ruby scripts/build-publication-plan.rb --profile publication/profiles/p3-gold.yml
ruby scripts/build-publication-plan.rb --profile publication/profiles/p3-gold.yml --check
```

生成的 `publication-plan.json` 只含规范相对路径、摘要、字节数、状态投影和
计划输出，不嵌入正文，不包含运行时生成时间、主机时间、用户名、主机名或绝对
工作目录。`source_date_epoch` 是 profile 固定的可复现构建输入，不是本次运行时间。

三个摘要的集合语义固定如下：

- `content_input_digest`：4 个章节正文 + 54 个显式公共工件，共 58 项；
- `publisher_input_digest`：schema、plan/renderer 实现、确定性 PDF 入口、模板、三套 CSS、profile/toolchain/catalog、P2 v3 schema 与基线 manifest、4 份逐章 manifest 和 4 个显式 `.gitignore`，共 31 项；
- `build_input_digest`：上述两组的无重复并集，共 89 项。

三者都使用 `sha256(path + NUL + bytes + NUL)` 的有序集合算法；它们是 P3 自己的
内容/出版/总构建摘要，不冒充 P2 v3 的 `audit_security` 分类摘要，也不证明清单之外
的仓库文件安全。`p2_baseline` 另行固定 P2 manifest 的算法、三类摘要、总摘要与计数。

计划生成时每个输入的首次读取会冻结为内存字节快照；逐项 SHA、字节数和三个集合
摘要都只基于这份快照，提交前再逐项重读，发现变化即失败。该机制防止一次构建形成
自相矛盾的混合摘要，但不是仓库锁、文件系统快照或针对恶意同用户并发进程的 OS 级
隔离。Unix executable 位不属于本摘要。

## 内容优先阶段的黄金样章验证

2026-07-16 起，P3—P8 采用内容优先节奏。四个黄金样章先由代码内固定 recipe 的
轻量 Runner 验证；出版级 verification manifest、严格未声明输出封闭和原子证据树
集中到 P9。当前入口是：

```bash
ruby scripts/verify-gold-samples.rb
ruby scripts/verify-gold-samples.rb --json
```

Runner 固定 11 个 recipe 和 9 个物理脚本入口，每个 recipe 都复制到独立临时目录
执行；Maven 强制使用 offline 模式。`java-values-types-starter` 只验证 lab harness 与可重现诊断，
因而期望退出码 `0` 并显式保留 learner output 未验证边界；真正的公开练习红灯
`java-values-types-exercise` 预先声明退出码 `41`。其余 recipe 期望退出码 `0`。
`java-values-types-example` 不借用不适用的 lab wrapper，而是执行固定的
Maven 构建和两个精确 stdout 预言机。

该 Runner 是内容生产期的损坏防线，不是 OS 级网络/文件系统沙箱，也不证明没有
未声明输出、跨平台可复现、人工教学质量或出版合规。完整门仍在 P9。

R1-A 的回归测试可以独立运行：

```bash
ruby tests/publication/test_publication_plan.rb
ruby tests/publication/test_publication_security.rb
ruby tests/publication/test_atomic_tree_writer.rb
ruby tests/publication/test_gold_sample_runner.rb
```

## P3 黄金样章渲染

R2 当前只实现已冻结的 `p3-gold`，不接受自定义 profile、自由输入路径或 255 章
整书构建。先生成并检查 sidecar plan，再运行固定入口：

```bash
ruby scripts/build-publication-plan.rb --profile publication/profiles/p3-gold.yml
ruby scripts/build-publication-plan.rb --profile publication/profiles/p3-gold.yml --check
ruby scripts/build-publication.rb
ruby scripts/check-publication-output.rb
```

PDF 通过项目内 `publication/lib/deterministic_weasyprint.py` 调用锁定的
WeasyPrint 68.1 / pydyf 0.12.1。该入口只把带标签表格原本依赖进程内存地址的
表头标识改为稳定顺序标识，并在依赖版本漂移时拒绝构建。它用于保证当前机器、
固定工具链下的重复字节，不构成 PDF/UA 合规声明。

渲染器在执行任何工具前重新读取 plan 的 89 个显式输入，逐项核对大小、SHA-256
和三个集合摘要。Pandoc 只在一个命令中读取四个有序 Markdown 并生成 canonical
JSON AST；整书 HTML、四个分章 HTML、EPUB 和打印 HTML 都只读取该 AST 或它的
确定性分章投影，WeasyPrint 只读取打印 HTML。远程图片、远程原始 HTML 资源、
模板/CSS 中的远程资源、私有 canary、私有路径和本机绝对路径都会在原子提交前失败。

输出先写入同级临时树并校验精确文件集合，成功后才替换
`build/publication/p3-gold/`。`publication-output-manifest.json` 按既有 schema 记录
9 个非 manifest 工件；manifest 不把自身列入摘要集合，以避免自引用摘要。
HTML、EPUB 和 PDF 三种交付格式都标为 `internal-review-candidate`，网络隔离准确记录为
`not-os-enforced`。构建结果不自动修改章节状态、`PROGRESS.md` 或 P2 五文件契约。

最后一条命令是独立的 R2 成品检查门：它只读取已经存在的完整 P3 输出，不调用
Pandoc/WeasyPrint、不重新构建、不写文件，也不触碰 mtime。它会核对精确文件与目录
集合、canonical manifest/schema、plan 绑定、工件 SHA-256/字节数、输出集合摘要、
固定命令/工具清单、文件类型和 HTML/EPUB/PDF 基本结构；缺失、额外项、摘要漂移、
symlink、特殊文件、私有标记或本机绝对路径都会 fail-closed。

R1-A 的 `build-publication-plan.rb --check` 仍严格表示“只含
`publication-plan.json` 的 sidecar 树”，因此必须在 R2 渲染前运行；不能把它改成
接受完整渲染树。再次生成 plan 会有意替换掉旧的 ignored 预览树。要验证已经生成的
完整树，必须使用 `check-publication-output.rb`。统一默认入口和 R1/R2 兼容清理由 P9
的独立迁移决策处理，本实现不提前选择。

R2 回归测试入口是：

```bash
ruby tests/publication/test_renderer.rb
```

## P8 内部完整出版 v2

P8 在不改变上述 `p3-gold` v1 合同的前提下增加了独立的
`internal-complete` v2 管线。它只接受 canonical catalog 的全部 255 章和固定
16 卷，不提供按 glob、状态或任意路径删减正文的入口。所有章节保持目录中的真实
状态；当前 profile 明确锁定 `drafting: 255`，构建成功不会把任何章节提升为
`review` 或 `verified`。

完整计划与实体构建入口是：

```bash
ruby scripts/build-complete-publication-plan.rb
ruby scripts/build-complete-publication-plan.rb --check
ruby scripts/build-complete-publication.rb
ruby scripts/build-complete-publication.rb --check
```

输出仅位于被 Git 忽略的 `build/publication/internal-complete/`。计划的写入与检查
只原子更新或比对 `publication-plan-v2.json`，不会删除同目录下已有的渲染树；实体
构建则在同级 staging 树完成精确文件集、链接、摘要、私有标记和文件类型检查后，
再整体替换旧树。

v2 只让 Pandoc 读取一次按 canonical catalog 顺序排列的 255 个 Markdown，得到一份 canonical full
AST。整书、16 卷和 255 个章节页面都从该 AST 的确定性投影生成；分章投影只复制
当前章的块，分卷投影只复制当前卷的块，不再为每章深拷整本 AST。网站同时生成
整书 HTML、16 个卷页面、255 个章页面、导航索引和含正文文本的 255 条搜索索引。

`examples/encyclopedia`、`labs/encyclopedia` 与 `exercises/encyclopedia` 的公开配套
工件只通过 `git ls-files -s -z` 纳入。计划和 `companions.json` 记录每个已跟踪普通
文件的路径、Git mode/blob、SHA-256 与字节数；正文只显示每章数量摘要，不内联
4,127 个文件。未跟踪文件不会进入清单，常见 generated/build 输出目录即使被误跟踪
也会拒绝；symlink、私有根、越界路径、private canary 和非普通 Git mode 同样
fail-closed。`solutions-private` 与本机 `/Users/...` 引用在
AST 投影中移除，任何此类标记若仍进入计划或输出则拒绝提交。

v2 计划固定 345 个路径；输出 manifest 不自我摘要，因此记录其中 344 个实体。
实体包括 canonical AST、16 份卷 AST、整书/分卷打印 HTML、网站、导航/搜索/配套
索引、整书与 16 卷 EPUB，以及整书与 16 卷带标签 PDF 候选。`--check` 是非变异的
生产集成门；测试入口是：

P8 的 PDF 分支使用 Pandoc 3.9.0.2 的 Typst writer 与 Typst 0.15.1，固定
`--pdf-standard=ua-1`、A4、`SOURCE_DATE_EPOCH` 对应的 creation timestamp。适配器只
消除生成的 chapter Div 与语义标题之间的重复 label，并把没有 bibliography 的
Markdown `@` 词恢复成可见字面文本；它会逐项断言最终 canonical AST 中的 Link 与
Image 节点数量完全不变。迁移前的 Java 卷 A4 PoC 在两个固定时间戳构建中逐字节
一致，veraPDF PDF/UA-1 为 106/106 条规则、942454/942454 个检查通过。这个结果只
触发 P8 渲染器迁移，不能代替整书重建后的机器报告、人工阅读顺序或辅助技术验收；
P3 黄金样章仍保留冻结的 WeasyPrint 分支。

```bash
ruby tests/publication/test_complete_publication_v2.rb
FACTORYCARE_REBUILD_COMPLETE_PUBLICATION=1 ruby tests/publication/test_complete_publication_v2.rb \
  -n test_full_production_entity_generation_when_explicitly_requested
```

第二条命令会真实重建全量实体，耗时和内存显著高于普通测试，故必须显式启用。
HTML/EPUB/PDF 的存在、标签和基本结构仍不等于 WCAG、EPUB Accessibility 或
PDF/UA 合规，也不构成人工教学评审、零基础试读、跨平台复现或公开发布授权。

P9 链接审计只读取上述构建已经声明的唯一 `ast/book.json`，并要求当前
`publication-plan-v2.json` 的字节 SHA 与 output manifest 的 `plan_sha256` 相同，
同时复核 canonical AST output entry 的路径、种类、媒体类型、大小和 SHA-256。它遍历
最终 Pandoc `Link`/`Image` 节点，不重新正则解析 Markdown，也不反推发布阶段之前的
image 语法。快速结构检查为：

```bash
ruby scripts/audit-chapter-markdown-links.rb \
  --root . --mode structure-only --observation-date 2026-07-24 \
  --output records/encyclopedia/evidence/machine/chapter-ast-links-v2-2026-07-24.json --pretty
```

`live` 模式只探测最终 AST 中唯一的合法外部 HTTPS 目标；内部锚点仍计入节点清单，
但不冒充网络成功。报告遵循
[`chapter-pandoc-link-audit-v2.schema.json`](../schemas/chapter-pandoc-link-audit-v2.schema.json)，
只记录明确传入的日期，不记录时间戳、绝对路径、URL 查询/fragment、凭据或原始网络
诊断。HTTP 200/206 也不证明来源权威、引用蕴含或长期可用；所有 manual-review 项都
保持未通过，且报告不能晋升章节状态或学习进度。

P9 无障碍审计使用独立的
[`accessibility-toolchain.yml`](accessibility-toolchain.yml)、toolchain schema、报告 schema
和审计入口，不复用 P8 “文件存在/基本结构”检查来冒充无障碍结论。审计器从当前 P8
plan 与 output manifest 重新选择 273 份 HTML、17 份 EPUB 和 17 份 PDF，共 307 个
交付工件；矩阵固定重算为 273 次 axe、17 次 EPUBCheck、17 次 Ace 和 17 次 veraPDF，
即 324 次检查。其余 37 个 manifest 输出是 AST、机器索引或打印中间件，不在这组
交付格式审计范围内。

本机真实运行需要显式给出已经安装在仓库外的 Node 工具目录、Chrome 和匹配的
ChromeDriver；审计器不会在仓库内下载依赖：

```bash
export FACTORYCARE_ACCESSIBILITY_NODE_BIN="$HOME/.cache/factorycare/p9/accessibility-node-tools/node_modules/.bin"
export FACTORYCARE_CHROME_EXECUTABLE="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
export FACTORYCARE_CHROMEDRIVER="$HOME/.cache/factorycare/p9/chromedriver-150/chromedriver-mac-arm64/chromedriver"

ruby scripts/audit-publication-accessibility.rb --root . --jobs 4 --timeout 600 \
  --output records/encyclopedia/evidence/machine/publication-accessibility-2026-07-24.json
```

axe 固定运行 WCAG 2.0/2.1/2.2 的 A/AA 标签；不把其他 best-practice 规则混入
“WCAG 机器检查”口径。默认逐调用上限为 600 秒，因为 13.8 MB 的整书聚合 HTML 在
本机实测约需 252 秒，而旧 240 秒上限会把有效计算误判为超时。超时仍然失败关闭，
不会跳过整书页或产生部分通过报告；实际 jobs、timeout 和标签集合会写入报告合同。
整书 axe 原始 JSON 只在内存中短暂解析，设置 256 MiB 硬上限；正式报告只保留规则
计数、规则 ID 和摘要哈希，禁止保存原始 stdout/stderr。

审计前、每项执行时和报告提交前都会复核工件大小与 SHA-256；plan/manifest 摘要、
307 个工件身份、六个工具/运行时入口身份和 324 个结果摘要都写入稳定绑定。路径重复、
缺失、输入漂移、工具版本漂移或结构化输出解析失败一律 fail-closed，且不会用不完整
结果覆盖报告。规范化 JSON 不保存绝对路径、生成时间戳、命令行、stdout/stderr 或
原始工具日志。`machine-passed` 仍明确标为 `machine-only-not-certification`、
`not-certified` 和 `forbidden-without-human-review`；它不能替代键盘、阅读顺序、缩放、
屏幕阅读器、EPUB 阅读器或 PDF 辅助技术的人工互操作评估。

## 当前能证明与不能证明的事

R1-A 可以证明 profile/status allowlist、文件所有权、普通文件与 symlink 边界、
显式文件集合、确定性 plan、可捕获进程内失败时的完整树回滚和 P2 byte-exact
隔离。这里的完整树替换不是断电级 crash-atomic：两次目录 rename 之间进程若被
强制终止，可能需要根据保留的 stage/backup 人工恢复；目录 `fsync` 在不支持的
平台上也是 best effort。R2 进一步证明当前固定环境能从同一 canonical AST 生成
schema-valid 的内部候选 manifest 与 HTML/EPUB/PDF 实体，但它不能证明：

- 命令在 OS 级文件系统或网络沙箱中运行；
- WCAG、EPUB Accessibility 或 PDF/UA 合规；
- PDF 已由独立执行方或跨平台逐字节复现；
- 浏览器、EPUB/PDF 阅读器或辅助技术互操作已经人工通过；
- 四个 `drafting` 章节已经达到 `review`。

`publication-output-manifest.schema.json` 是 R2 输出契约；当前固定入口会生成
符合该 schema 的实例。它明确记录 `network_policy: forbidden` 只是策略，同时要求
`network_isolation: not-os-enforced`，避免把无网络调用冒充 OS 级断网沙箱。

当前本机固定工具链下，P3 两个干净目录的连续构建已观察到 AST、HTML、打印 HTML、
EPUB 和 PDF 逐字节一致。这只能称为**本机字节重复性证据**；在独立执行方按声明环境
复现之前，仍不能声称 reproducible build 或跨平台可复现。PDF 也仍只是 PDF/UA-1
候选文件，标签存在、字节稳定或机器检查通过都不能替代完整机器门和人工无障碍评估。
其余 251 章的完整 verification manifest、人工检查、零基础试读和独立总审查仍未
关闭；延期不表示已经通过。P2 v3 只关闭输入清单与摘要职责的机器契约，不替代这些
内容和发布证据。

此外，集成审计 M1 记录的 `edition.status` 枚举与 phase/status 合法组合门纳入
R1-B-L 已完成该生命周期门；R1-A 只校验当前 sidecar profile 的章节状态投影，
不能替代 canonical curriculum lifecycle 的拼写错误与非法组合门。
