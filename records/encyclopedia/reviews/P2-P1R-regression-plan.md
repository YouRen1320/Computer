# P2 对 P1R（2026.2-draft）的回归计划

## 1. 目标与范围

P1R 将课程从位置编码的 170 章目录迁移为语义稳定 ID 的 255 章规范输入。P2 的发布安全合同必须在不降低 fail-closed 强度的前提下接受新目录，并继续保护人工正文、证据、版本基线和确定性构建。

本次回归包含：

1. `schemas/chapter.schema.json` 接受结构化 outcome 与语义稳定章节 ID；
2. `scripts/validate-encyclopedia.rb` 从 schema v2 catalog 读取派生字段，并继续校验正文元数据与目录字节级一致；
3. `scripts/build-book.rb` 以 255 章目录生成确定性站点索引和 manifest；
4. `site/config.yml`、`versions/registry.yml` 与 catalog 的 edition 对齐为 `2026.2-draft`；
5. P2 安全测试、source inventory 测试与 curriculum v2 测试共同通过；
6. 旧 ID 只允许存在于迁移账本和冻结审计记录，不进入运行时输出。

非目标：不把 planned placeholder 视为正文，不自动升级任何章节状态，不重写人工正文，不修改 `PROGRESS.md`，不把来源候选自动标为已审查。

## 2. 已确认的破坏性决策

- canonical ID 使用 `ch.<domain>.<slug>`，不提供旧 ID alias、redirect 或 shadow placeholder。
- 章节规范输入与生成输出分离；P2 只消费受生成器验证的 canonical catalog。
- outcome 从字符串升级为固定的 explain/build/diagnose 对象；旧字符串格式不兼容。
- 版本注册表删除未使用且已归档的 MinIO 项，将 OAuth 2.0 Security BCP 与 OIDC Core 拆为两个来源边界。

回滚方式：整体恢复 P1/P2 冻结基线 `pre-encyclopedia-2026-07-16`；不支持在同一运行时混用 2026.1 与 2026.2 目录。

## 3. 受影响面

### Schema 与元数据

- `schemas/chapter.schema.json`
- `schemas/site-config.schema.json`
- `schemas/version-registry.schema.json`（仅在状态模型确需扩展时；删除 MinIO 不要求扩展）
- `schemas/README.md`

### 校验与构建

- `scripts/validate-encyclopedia.rb`
- `scripts/build-book.rb`
- `scripts/build-source-inventory.rb`

### 测试

- `tests/encyclopedia/test_encyclopedia_security.rb`
- `tests/source_inventory/test_build_source_inventory.rb`
- `tests/curriculum/test_*_v2.rb`

### 生成与配置

- `site/config.yml`
- `site/generated/**`
- `versions/registry.yml`
- `sources/catalog.yml`、`sources/mappings.csv` 及其公开审计产物

## 4. 必须保留的 P2 安全不变量

1. 所有 JSON/YAML 输入继续拒绝重复 key；schema、catalog、front matter 和 registry 均 fail-closed。
2. canonical input、章节、artifact、evidence、输出和 manifest 路径继续拒绝 symlink 逃逸。
3. 作者与审阅者继续使用 NFKC/casefold 后独立比较。
4. `review`/`verified` 正文继续要求至少两个二级标题、足够的规范化正文长度，且不含 placeholder/TODO。
5. catalog、front matter、version surface、edition、outcome、route tag 和 prerequisite 必须逐字段一致。
6. verified 章节所需版本约束和完整硬前置闭包继续可验证；planned 章不得因生成成功而升级。
7. manifest 必须覆盖所有实际校验输入，并保持两次构建字节完全一致。
8. 私有答案、临时目录、旧 ID redirect 与来源原始私有账本不得进入发布产物。

## 5. 新增对抗测试

1. 旧 `vNN.cNN.*` ID 写入 catalog、front matter、artifact 或 evidence 路径时失败。
2. outcome 缺少任一结构字段、顺序错误、kind 错误或使用未授权 capability 时失败。
3. catalog schema v2 与 chapter metadata schema v1 混用时失败。
4. catalog 已迁移但 `site/config.yml`/registry edition 仍为 2026.1 时失败。
5. 删除或篡改任一规范输入后，旧 manifest 不得继续通过。
6. generated planned placeholder 被伪装成人工 `review` 正文时失败。
7. 255 章中任一 path 与语义 ID 所属目录不一致时失败。
8. 运行时输出出现旧 ID、alias 或 redirect 时失败。
9. source mapping 仍指向已退休 ID 时失败；拆分来源仍须保持 `unreviewed` 和人工复核要求。
10. OAuth/OIDC 章节只声明一个不完整版本来源，或继续引用已删除 `oauth2-oidc` 项时失败。

## 6. 完成标准

- canonical generator `--check` 通过，目录精确 16 卷、255 章、94 capabilities；该数量从能力注册表动态读取，测试只固定当前 edition 的声明值；
- P2 security suite、curriculum v2 suite、source inventory suite 全部通过；
- 两次完整 build 的文件集合、文件顺序、SHA-256 与 manifest 字节一致；
- 公开运行时输出中旧章节 ID 数量为 0；迁移账本覆盖旧 170 ID 恰好一次；
- 版本注册表 4 个既有 FAIL 全部关闭，13 个 WARN 明确保留为章节验证跟进；
- `git diff -- PROGRESS.md` 为空；
- 独立对抗审查没有高严重度未解决项。

## 7. 有意不做

- 不为迁移便利保留任何运行时兼容层。
- 不因目录、placeholder、测试或构建通过而声称章节已出版或学习者已掌握。
- 不在 P2 回归中编写几十万字正文；正文生产从 P3 金样章开始。
- 不把未完成人工版权、质量和事实审查的 Note/Java-Note 来源变成可直接出版材料。
