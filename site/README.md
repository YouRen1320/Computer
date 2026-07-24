# 无依赖发布骨架

本目录提供一个不需要 Node、Bundler 或第三方模板引擎的最小发布入口。它的目标是让目录、状态和可发布章节可检查，而不是在正文尚未完成时制造“已经有一本书”的假象。

## 构建与检查

```bash
ruby scripts/validate-encyclopedia.rb
ruby scripts/build-book.rb
ruby scripts/build-book.rb --check
ruby scripts/validate-encyclopedia.rb --check-generated
```

然后在仓库根目录运行任意静态 HTTP 服务器，例如：

```bash
python3 -m http.server 8000
```

访问 `http://localhost:8000/site/`。直接双击 `index.html` 时浏览器可能禁止 `fetch` 本地 JSON，因此推荐使用本地 HTTP 服务。

## 产物边界

- `generated/catalog.json`：全部章节的目录元数据，明确标记是否可发布；
- `generated/navigation.json`：按卷分组的稳定导航；
- `generated/search-index.json`：只包含达到 `publish_statuses` 的章节；
- `generated/publication-manifest.json`：输入摘要、状态计数和发布数量；
- `generated/README.md`：给代码审查者看的生成说明。

生成器不把 `planned` 占位写入搜索索引，也不把 `review` 自动升级为公开正文。百科
校验器自身会运行严格课程目录校验，构建器只调用这一单一入口以避免规则分叉。
`publication-manifest.json` 使用 runtime schema v3，并把输入显式划分为三个互斥集合：

- `content`：章节、卷说明、课程内容规范、版本基线以及逐文件声明的公开示例/实验/练习；
- `audit_security`：评估、学习进度、迁移账本、FactoryCare 验收目录、审查与验证证据；
- `build_control`：schema、校验器、生成器、站点资源和逐章公共工件 manifest。

每个输入先记录内容 SHA-256；分类摘要固定使用
`sha256(path + NUL + content_sha256 + NUL)`，总摘要再按
`content`、`audit_security`、`build_control` 的固定顺序使用
`sha256(category + NUL + category_digest + NUL)` 计算。因此任一分类摘要和总摘要都能从
manifest 重算，分类之间不得重叠或遗漏。

严格校验器实际读取的 `ASSESSMENTS.md`、`PROGRESS.md`、全部 `book/`/`curriculum/`
规范输入，以及 schema、版本登记、卷 README、章节、公开工件、审查证据、站点资源与
生成器都会进入上述清单。`review`/`verified` 章节的公共工件不再递归猜测：章节必须把
三个 canonical managed root 写入 front matter，并提供
`publication/manifests/public-artifacts/<chapter-id>.yml`，其中逐文件清单必须与磁盘
完全一致。输入必须已由 Git 跟踪且为普通文件；符号链接、未声明文件、未跟踪文件以及
缓存、日志和临时产物都会 fail-closed。manifest 不含当前时间，因此相同输入会得到
相同字节。

构建使用仓库内临时目录生成完整文件集，再整体替换 `generated/`。检查模式要求输出
目录只含 manifest 声明的五个文件：残留文件、符号链接、字节漂移或仓库外路径都会
失败。`solutions-private/` 永远不是发布输入、manifest 条目或输出。

v3 是原子破坏性迁移：五个输出文件名保持不变，但不再读取或写出旧的单值
`input_digest`，也不提供 schema v2/v3 双读。回滚必须同时恢复 builder、validator、
schema、P3 消费端、测试和五个生成文件，再依次重跑 validator、build 与 `--check`；
只回退某一个 JSON 字段会留下不可验证的混合契约。
