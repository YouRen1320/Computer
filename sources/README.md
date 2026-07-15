# 来源账本

本目录是百科教材的公开、版权保守型来源证据层。公开文件只保存不可逆定位哈希、聚合元数据、原创概念标签和对权威课程目录的候选映射；不保存来源正文、代码、图片、PDF、完整路径或逐节原始标题。

## 固定来源

| 仓库 | 规范来源 | 提交 | 文件 | Markdown | PDF | 章节候选映射 | 许可证状态 |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| `java-note` | https://github.com/YouRen1320/Java-Note.git | `3c4928bf78b24d6550538ea388240fe3b4ce407e` | 3077 | 370 | 2 | 6638 | `no-root-license-file-detected` |
| `note` | https://github.com/YouRen1320/Note.git | `72b27e3bad732fa86d5fd9d9c990c6d5ecaf9f96` | 347 | 73 | 12 | 2536 | `no-root-license-file-detected` |

全部 9174 条映射的 `review_status` 都是 `unreviewed`。它们是用于防遗漏的机器候选，不代表人工确认、教材覆盖完成或技术结论正确。

## 公开文件

- `catalog.yml`：固定来源、聚合计数、课程目录版本和产物摘要。
- `files.csv`：逐文件哈希化元数据；没有原始路径。
- `mappings.csv`：以稳定 `section_id` 为键的候选章节映射；没有原始标题或路径。
- `migration-policy.md`：人工复核门槛和版权边界。
- `ADVERSARIAL-REVIEW.md`：本批次的反例检查与未完成项。

`target_kind=volume` 的 `target_id` 和全部 `chapter_ids` 都在构建时从 `curriculum/catalog.yml` 解析并验证。附录、未来扩展、来源元数据和人工分流使用不同的 `target_kind`，不再伪装成卷目录。

## 私有原始审计账本

如确需核对原始位置，可用 `--include-private` 在 `sources/private/` 生成 JSONL。该目录被 `.gitignore` 排除，目录权限为 `0700`、文件权限为 `0600`，包含无许可材料的逐节标题和完整相对路径，必须保持本地或访问受控，永不进入 Git、网站、书籍、制品或分享包。原子切换使用的暂存与备份目录也必须先通过 Git 忽略检查，否则生成器拒绝写入原始账本。

## 重建与检查

```bash
ruby scripts/build-source-inventory.rb --include-private
ruby scripts/build-source-inventory.rb --check --include-private
ruby tests/source_inventory/test_build_source_inventory.rb
```

源仓库 URL 是生成器中的规范常量，不读取本地 `remote.origin.url`。构建不含时间戳；在受支持的 Ruby/Psych 工具链内，相同提交、目录和规则应逐字节一致。

## 已知边界

- 哈希证明字节身份，不证明作者、许可、质量或合法使用权。
- 关键词和标题评分可能误报或漏报；所有映射仍需人工逐条复核。
- HTML、PDF、Office、归档和图片只进入文件级覆盖统计，不提取内容结构。
- 正式采用某个知识点前，仍须补当前官方来源、版本、验证证据和版权决定。
