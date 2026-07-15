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

生成器不把 `planned` 占位写入搜索索引，也不把 `review` 自动升级为公开正文。百科校验器自身会运行严格课程目录校验，构建器只调用这一单一入口以避免规则分叉。`publication-manifest.json` 覆盖严格校验器实际读取的 `ASSESSMENTS.md`、`PROGRESS.md`、全部 `book/`/`curriculum/` 规范输入，以及 schema、版本登记、卷 README、章节、公开示例/实验/练习、审查证据、站点资源与生成器摘要；不含当前时间，因此相同输入会得到相同字节。

构建使用仓库内临时目录生成完整文件集，再整体替换 `generated/`。检查模式要求输出目录只含 manifest 声明的五个文件：残留文件、符号链接、字节漂移或仓库外路径都会失败。`solutions-private/` 永远不是发布输入、manifest 条目或输出。
