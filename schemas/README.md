# 百科全书元数据契约

本目录定义“教材是什么”的机器可读契约，但不把结构校验冒充内容质量审查。

## 两层元数据

1. [`curriculum/catalog.yml`](../curriculum/catalog.yml) 是章节身份、顺序、依赖、路线和状态的唯一目录；章节文件不得另造一套路线关系。
2. 每个章节 Markdown 的 YAML front matter 记录章节身份和写作/验证证据，并遵循 [`chapter.schema.json`](chapter.schema.json)。

版本基线集中记录在 [`versions/registry.yml`](../versions/registry.yml)，遵循 [`version-registry.schema.json`](version-registry.schema.json)。v2 只允许原子产品、规范、运行时或实现 ID；每项用 `sources[]` 分别记录一手来源、发布者、检查日期和该来源实际支持的精确 claim，旧单值 `source_url` 已被禁止。`reviewed_at` 只表示人工检查日期，不等同于版本事实永久正确；`promotion_mode: manual-only` 与 `automatic_promotion: false` 禁止根据 schema 通过或 URL 可达性把 `conceptual`/`provisional` 自动升级为 `verified`。站点配置遵循 [`site-config.schema.json`](site-config.schema.json)。章节只引用稳定的 `version_surfaces` ID（复数数组），不保留旧 `versioned_surface` 字段，也不在正文各处复制“当前版本”。

FactoryCare 的八阶段门禁由 [`factorycare-stage-gates.schema.json`](factorycare-stage-gates.schema.json) 约束，实例位于 [`curriculum/factorycare-stage-gates.yml`](../curriculum/factorycare-stage-gates.yml)。路线计划只引用 `gate_id`；门禁注册表独立拥有 93 个权威验收编号的唯一 primary 归属、可选 secondary 归属、负向场景、证据种类和阶段工件路径。这个分离防止路线排期与可验收合同互相复制后漂移。

48 模块加速路线的源计划遵循 [`accelerated-route-plan.schema.json`](accelerated-route-plan.schema.json)。章节 `level` 只表示百科参考内容深度；模块 `required_mastery` 才是路线退出要求，且必须与 `evidence_requirements` 的固定 profile 逐项一致。因此 ML 可按 L1–L2 通过路线，AI 可按 L2+ 通过路线，但百科中已有的 L3 参考内容不被删除或降级。

schema v2 使用语义 ID `ch.<domain>.<slug>`。front matter 必须逐字对齐 catalog 的 `edition`、`responsibility`、`path`、硬前置、版本面与路线标签；旧 `vNN.cNN.*` ID 只允许留在迁移账本和冻结审计记录，不能进入 catalog、章节元数据、工件或证据路径。

## 状态与门槛

| 状态 | 含义 | 可以公开为教材正文 |
|---|---|---|
| `planned` | 只有架构占位；没有正文完成声明 | 否 |
| `drafting` | 正文正在编写，证据可能不完整 | 否 |
| `review` | 正文、公开工件、私有解析、来源和当前阶段要求的独立证据齐备；允许因传递硬前置尚未闭合而停留在此状态 | 否（仅内部预览） |
| `verified` | 七类审查门、发布导航覆盖和全部传递硬前置均有独立通过证据 | 是 |

状态只能前进到实际证据支持的位置。`BUILD SUCCESS`、链接可访问或 AI 自检都不能单独把一章变成 `verified`。

`planned` 是生成器拥有的最小占位：必须携带 `generated_by: scripts/generate-curriculum.rb` 与匹配 catalog 的 `generated_spec_digest`，不能携带人工 authoring/review 字段。`drafting`、`review`、`verified` 是人工章节，必须移除这两个占位所有权字段，并声明 `stable_core` 与恰好三个结构化 outcomes；顺序固定为 `explain`、`build`、`diagnose`，kind 固定对应 `concept`、`independent-build`、`fault-diagnosis`。outcome 只能使用本章 capability 合同声明的能力。

## 校验边界

`ruby scripts/validate-encyclopedia.rb` 会执行本目录声明的 JSON Schema 2020-12 受控子集，并对跨文件引用、真实路径、日期和发布门执行语义校验。布尔 schema、`$ref` sibling 都遵循 2020-12 语义；不支持的 schema 关键字、重复 JSON 对象成员、重复 YAML mapping key 会 fail-closed，不能依赖 last-wins 改写机器契约。校验器本身会先运行严格课程目录校验，且在读取前拒绝 canonical input 的符号链接。

`review` 与 `verified` 必须分别声明 `examples`、`labs`、`exercises` 和 `solutions_private` 四组非空工件。每一项只能位于对应的 `*/encyclopedia/<chapter-id>/` 子树；文件必须是非空白普通文件，目录必须至少含一个非隐藏、非空白普通文件，任何层级的符号链接和越界路径都会被拒绝。两种状态的正文都不能含占位标记，必须至少有两个 H2，且规范化正文不少于 200 个字符；`verified` 还必须满足全部发布门，并且硬前置的传递闭包已全部 `verified`。

P2 五文件由 [`site-publication-manifest-v3.schema.json`](site-publication-manifest-v3.schema.json)
约束。schema v3 删除旧单值 `input_digest`，要求 `content`、`audit_security`、
`build_control` 三个互斥输入映射、分类计数、分类摘要、可重算总摘要以及四个非 manifest
输出摘要。`public-artifact-manifest.schema.json` 为 `review`/`verified` 章节逐文件声明
公共工件及 repository metadata；磁盘中的 managed root 与 manifest 必须精确相等，
不能再用递归扫描悄悄吸收临时文件。该迁移不提供 schema v2 双读。

P3 出版控制面使用独立 sidecar：`publication-profile.schema.json` 固定 profile、状态和
不可分发预览边界，schema v1 只接受 P3 `internal-preview`；四份逐章 manifest 显式列出
54 个公共工件；`publication-toolchain.schema.json` 记录观察与延期工具，实际工具 ID、
命令、阶段和状态另由 Ruby allowlist 固定；`publication-plan.schema.json` 显式投影资源
策略与内部通知，并把 P2 schema v3 的分类摘要、计数和 manifest SHA 固定为 baseline；
`publication-output-manifest.schema.json` 定义 R2 输出契约。sidecar 输出只位于被忽略的
`build/publication/<profile-id>/`，不改变 P2 的五个输出文件名。

P2 输入/摘要迁移已经落到机器合同，但它不等于完整 D5 生命周期门。章节晋升仍需要
verification manifest、统一 Runner、测试数量/预期失败/未声明输出校验、合法生命周期、
真实渲染、人工教学审查与零基础试读；不能用 schema、sidecar plan 或自动化测试手工
绕过章节状态门。

`verification-manifest.schema.json` 定义 P9 D5 的章级机器验证合同。manifest 逐文件锁定 SHA-256 与模式，命令只能在独立临时副本中通过固定解释器执行，并声明工具版本、精确退出码、输出观察和完整文件系统增量。统一 Runner 对绝对路径、私有目录、符号链接、输入漂移、工具漂移、输入修改和未声明输出 fail-closed；成功证据通过 staging/rename 原子替换 `verification/evidence/last-run/`。它不提供 OS 级网络或文件系统沙箱，也不把机器通过自动解释为人工教学、无障碍、跨平台或正式发布证据。
该 schema 只约束输入 manifest，不约束 `evidence.json` 输出元数据；后者当前由生成器与回归测试固定，包括 Runner 的 Ruby 身份、实际执行策略和完整控制面摘要。若未来为 evidence 新增独立 schema，应作为单独合同设计，并同步重新定义控制面闭包，不能把输出字段误塞进输入 manifest schema。

P9 的大规模机械审计另有四个不可晋升的报告契约：
`encyclopedia-endpoint-audit.schema.json` 约束 1020 个端点的 fresh-copy 执行与输出闭包；
`exercise-contract-audit.schema.json` 约束 255 个练习的双运行、可空精确退出码、
可空 SHA-256 观察、完整来源 endpoint 文件摘要和 `EXPECTED_RED` 观察；
`observed-verification-candidates-v2.schema.json` 约束缺少 final
manifest 章节的完整静态输入闭包、生成时工具探针、双运行候选与完整来源文件摘要；
[`chapter-pandoc-link-audit-v2.schema.json`](chapter-pandoc-link-audit-v2.schema.json)
约束基于 P8 canonical Pandoc AST 最终 `Link`/`Image` 节点的链接报告，并逐字节绑定
P8 plan、output manifest 与其中唯一的 `ast/book.json` output entry。v2 不再重新用正则
解析 Markdown；每个节点保留章节 ID 与 JSON Pointer，查询、fragment、凭据和原始错误
不会写入报告。structure-only 与 live 都是机器观察，live 的人工复核项不能自动通过。
它们都只是脱敏机器观察，
不得写入 `verification/manifests/`、不得代替学习者证据或人工 final 审查。

P9 发布无障碍检查由
[`publication-accessibility-toolchain.schema.json`](publication-accessibility-toolchain.schema.json)
和 [`publication-accessibility-audit.schema.json`](publication-accessibility-audit.schema.json)
共同约束。前者固定 307 个交付工件与 324 次工具检查的可重算矩阵，以及四个审计引擎
和 axe 的两个运行时依赖；后者逐字节绑定 P8 plan/output manifest、307 个工件摘要、
工具入口/版本身份和每项规范化结果。缺失、重复、漂移和解析失败均 fail-closed；报告
禁止绝对路径、时间戳和原始日志，并固定声明 `machine-only-not-certification` 与
`forbidden-without-human-review`，因此 schema 通过不能自动关闭人工无障碍门。

`encyclopedia-definition-of-done.schema.json` 约束 255 章的结构化完成定义盘点：每章必须
完整列出结构项和人工审查项，缺失与人工待审不能混为一类，`not-applicable` 必须给出理由。
报告按 5–8 章一批生成稳定人工复核队列，并固定声明“结构全绿不等于语义批准”；机器结果禁止
自动晋升章节、final manifest 或学习进度。

七个门是 `technical`、`pedagogical`、`code`、`security`、`accessibility`、`version_sources` 和 `publication_navigation`。最后一门还必须分别给出链接、键盘/语义和实际渲染审查覆盖；键盘/语义确实不适用时仍需证据和具体理由。所有门及版本证据只能引用 `records/encyclopedia/evidence/<chapter-id>/` 下的真实非空白普通文件。作者和 reviewer 去除 Unicode 空白并做 NFKC+casefold 后都至少两字符，且不能相同。

章节 `source_refs.id` 必须唯一；URL 必须可解析为有 host、无 userinfo 的 HTTPS URI。允许 fragment，以便指向官方文档的精确章节。`verified_versions.constraint` 必须逐字匹配 registry 对应条目的约束，实际测试 patch 记录在证据文件中。registry、catalog 和 site 的 edition 必须一致。

私有解析只允许位于 `solutions-private/encyclopedia/<chapter-id>/`，发布构建和 manifest 会显式排除整个 `solutions-private/` 子树。这只证明构建隔离，不证明 Git 历史或仓库存储隔离。开发权威仓保持私有；若建立公共发行入口，必须使用不携带 `solutions-private` 历史的新公共发行仓。历史重写不能撤回第三方已经取得的副本。

P3-R0 历史方案把正式 HTML/EPUB/PDF 预览、七类审查和至少一轮编程零基础读者试读设为 P3 阶段门。2026-07-16 后续确认的 content-first 策略只改变执行时点：P3—P8 完成直接相关的 schema、边界、代码和构建自动检查后可继续内容生产，全面人工版式/无障碍、独立复审、零基础试读和跨平台证据统一在 P9 闭环。延期不等于通过：四章在这些证据完整前仍保持 `drafting`，不能进入公开发行；正式边界以 [`CONTENT-FIRST-EXECUTION.md`](../records/encyclopedia/CONTENT-FIRST-EXECUTION.md) 和 P9 审计为准。

P8 的内部完整出版使用独立 v2 合同：`publication-profile-v2.schema.json` 把选择固定为
catalog 全部 255 章与 16 卷；`publication-plan-v2.schema.json` 约束章节、卷、Git 已
跟踪公开配套工件摘要、精确 345 项计划输出和零安全计数；
`publication-output-manifest-v2.schema.json` 约束 344 个非自引用实体的摘要及实际
命令记录。v2 不替代或放宽 P3 v1，也没有 public/release 模式。其完整构建成功只证明
当前输入和工具链下生成了内部候选实体，不改变 255 章的 `drafting` 状态，不关闭
人工评审、无障碍、阅读器互操作、独立复现和公开发布门。
