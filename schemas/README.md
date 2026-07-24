# 百科全书元数据契约

本目录定义“教材是什么”的机器可读契约，但不把结构校验冒充内容质量审查。

## 两层元数据

1. [`curriculum/catalog.yml`](../curriculum/catalog.yml) 是章节身份、顺序、依赖、路线和状态的唯一目录；章节文件不得另造一套路线关系。
2. 每个章节 Markdown 的 YAML front matter 记录章节身份和写作/验证证据，并遵循 [`chapter.schema.json`](chapter.schema.json)。

版本基线集中记录在 [`versions/registry.yml`](../versions/registry.yml)，遵循 [`version-registry.schema.json`](version-registry.schema.json)。站点配置遵循 [`site-config.schema.json`](site-config.schema.json)。章节只引用稳定的 `version_surfaces` ID（复数数组），不保留旧 `versioned_surface` 字段，也不在正文各处复制“当前版本”。

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

P3-R1-A 已把出版控制面实现为独立 sidecar：`publication-profile.schema.json` 固定 profile、状态和不可分发预览边界，schema v1 只接受 P3 `internal-preview`；`public-artifact-manifest.schema.json` 配合四份逐章 manifest 显式列出 54 个公共工件；`publication-toolchain.schema.json` 记录观察与延期工具，实际工具 ID、命令、阶段和状态另由 Ruby allowlist 固定；`publication-plan.schema.json` 显式投影资源策略与内部通知，并约束不含正文、绝对路径和私有 canary 的确定性计划；`publication-output-manifest.schema.json` 预定义 R2 输出契约，但 R1-A 尚未生成实例。sidecar 输出只位于被忽略的 `build/publication/<profile-id>/`，P2 五个生成文件保持逐字节不变。

R1-A 还不是完整 D5 生命周期门：`review/verified` 的 verification manifest、干净临时目录统一 Runner、测试数量/预期失败/未声明输出校验，以及 `edition.status` 枚举与 phase/status 合法组合属于 R1-B；HTML/EPUB/PDF 实体属于 R2；P2 的递归公共输入与双摘要迁移仍须在四章晋升 `review` 前单独完成。因此当前四章继续为 `drafting`，不能用 sidecar plan 或自动化测试手工绕过状态门。

`verification-manifest.schema.json` 定义 P9 D5 的章级机器验证合同。manifest 逐文件锁定 SHA-256 与模式，命令只能在独立临时副本中通过固定解释器执行，并声明工具版本、精确退出码、输出观察和完整文件系统增量。统一 Runner 对绝对路径、私有目录、符号链接、输入漂移、工具漂移、输入修改和未声明输出 fail-closed；成功证据通过 staging/rename 原子替换 `verification/evidence/last-run/`。它不提供 OS 级网络或文件系统沙箱，也不把机器通过自动解释为人工教学、无障碍、跨平台或正式发布证据。
该 schema 只约束输入 manifest，不约束 `evidence.json` 输出元数据；后者当前由生成器与回归测试固定，包括 Runner 的 Ruby 身份、实际执行策略和完整控制面摘要。若未来为 evidence 新增独立 schema，应作为单独合同设计，并同步重新定义控制面闭包，不能把输出字段误塞进输入 manifest schema。

P9 的大规模机械审计另有三个不可晋升的报告契约：
`encyclopedia-endpoint-audit.schema.json` 约束 1020 个端点的 fresh-copy 执行与输出闭包；
`exercise-contract-audit.schema.json` 约束 255 个练习的双运行、可空精确退出码、
可空 SHA-256 观察、完整来源 endpoint 文件摘要和 `EXPECTED_RED` 观察；
`observed-verification-candidates-v2.schema.json` 约束缺少 final
manifest 章节的完整静态输入闭包、生成时工具探针、双运行候选与完整来源文件摘要。
它们都只是脱敏机器观察，
不得写入 `verification/manifests/`、不得代替学习者证据或人工 final 审查。

七个门是 `technical`、`pedagogical`、`code`、`security`、`accessibility`、`version_sources` 和 `publication_navigation`。最后一门还必须分别给出链接、键盘/语义和实际渲染审查覆盖；键盘/语义确实不适用时仍需证据和具体理由。所有门及版本证据只能引用 `records/encyclopedia/evidence/<chapter-id>/` 下的真实非空白普通文件。作者和 reviewer 去除 Unicode 空白并做 NFKC+casefold 后都至少两字符，且不能相同。

章节 `source_refs.id` 必须唯一；URL 必须可解析为有 host、无 userinfo 的 HTTPS URI。允许 fragment，以便指向官方文档的精确章节。`verified_versions.constraint` 必须逐字匹配 registry 对应条目的约束，实际测试 patch 记录在证据文件中。registry、catalog 和 site 的 edition 必须一致。

私有解析只允许位于 `solutions-private/encyclopedia/<chapter-id>/`，发布构建和 manifest 会显式排除整个 `solutions-private/` 子树。这只证明构建隔离，不证明 Git 历史或仓库存储隔离。开发权威仓保持私有；若建立公共发行入口，必须使用不携带 `solutions-private` 历史的新公共发行仓。历史重写不能撤回第三方已经取得的副本。

P3 黄金样章的阶段门另要求正式 HTML/EPUB/PDF 预览和至少一轮符合 P3-R0 定义的编程零基础读者试读。当前只验证了章节代码/JDK 的 macOS arm64 + Temurin 25.0.3 基线；正式出版构建仅为 `smoke_observed`，浏览器/阅读器/辅助技术为 `not_evaluated`，必须由 R2/R3 产生各自证据。P3 完成时四章只进入 `review`；Windows、Linux、其他 JDK 和阅读系统是明确披露的 P4 follow-up，不能写成已验证。

P8 的内部完整出版使用独立 v2 合同：`publication-profile-v2.schema.json` 把选择固定为
catalog 全部 255 章与 16 卷；`publication-plan-v2.schema.json` 约束章节、卷、Git 已
跟踪公开配套工件摘要、精确 345 项计划输出和零安全计数；
`publication-output-manifest-v2.schema.json` 约束 344 个非自引用实体的摘要及实际
命令记录。v2 不替代或放宽 P3 v1，也没有 public/release 模式。其完整构建成功只证明
当前输入和工具链下生成了内部候选实体，不改变 255 章的 `drafting` 状态，不关闭
人工评审、无障碍、阅读器互操作、独立复现和公开发布门。
