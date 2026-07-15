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
| `review` | 正文、示例、实验、练习、私有解析和来源齐备，等待独立复核 | 否（可作为内部预览） |
| `verified` | 七类审查门以及发布导航覆盖检查均有独立证据 | 是 |

状态只能前进到实际证据支持的位置。`BUILD SUCCESS`、链接可访问或 AI 自检都不能单独把一章变成 `verified`。

`planned` 是生成器拥有的最小占位：必须携带 `generated_by: scripts/generate-curriculum.rb` 与匹配 catalog 的 `generated_spec_digest`，不能携带人工 authoring/review 字段。`drafting`、`review`、`verified` 是人工章节，必须移除这两个占位所有权字段，并声明 `stable_core` 与恰好三个结构化 outcomes；顺序固定为 `explain`、`build`、`diagnose`，kind 固定对应 `concept`、`independent-build`、`fault-diagnosis`。outcome 只能使用本章 capability 合同声明的能力。

## 校验边界

`ruby scripts/validate-encyclopedia.rb` 会执行本目录声明的 JSON Schema 2020-12 受控子集，并对跨文件引用、真实路径、日期和发布门执行语义校验。布尔 schema、`$ref` sibling 都遵循 2020-12 语义；不支持的 schema 关键字、重复 JSON 对象成员、重复 YAML mapping key 会 fail-closed，不能依赖 last-wins 改写机器契约。校验器本身会先运行严格课程目录校验，且在读取前拒绝 canonical input 的符号链接。

`review` 与 `verified` 必须分别声明 `examples`、`labs`、`exercises` 和 `solutions_private` 四组非空工件。每一项只能位于对应的 `*/encyclopedia/<chapter-id>/` 子树；文件必须是非空白普通文件，目录必须至少含一个非隐藏、非空白普通文件，任何层级的符号链接和越界路径都会被拒绝。两种状态的正文都不能含占位标记，必须至少有两个 H2，且规范化正文不少于 200 个字符；`verified` 还必须满足全部发布门，并且硬前置的传递闭包已全部 `verified`。

七个门是 `technical`、`pedagogical`、`code`、`security`、`accessibility`、`version_sources` 和 `publication_navigation`。最后一门还必须分别给出链接、键盘/语义和实际渲染审查覆盖；键盘/语义确实不适用时仍需证据和具体理由。所有门及版本证据只能引用 `records/encyclopedia/evidence/<chapter-id>/` 下的真实非空白普通文件。作者和 reviewer 去除 Unicode 空白并做 NFKC+casefold 后都至少两字符，且不能相同。

章节 `source_refs.id` 必须唯一；URL 必须可解析为有 host、无 userinfo 的 HTTPS URI。允许 fragment，以便指向官方文档的精确章节。`verified_versions.constraint` 必须逐字匹配 registry 对应条目的约束，实际测试 patch 记录在证据文件中。registry、catalog 和 site 的 edition 必须一致。

私有解析只允许位于 `solutions-private/encyclopedia/<chapter-id>/`，发布构建和 manifest 会显式排除整个 `solutions-private/` 子树。
