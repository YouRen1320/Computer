# 版本注册表 v2 原子来源审查

## 结论

- 审查对象：[`versions/registry.yml`](../../../versions/registry.yml)
- 结构契约：[`schemas/version-registry.schema.json`](../../../schemas/version-registry.schema.json)
- 审查日期：2026-07-24
- 注册表：71 个唯一原子条目、93 条 `sources[]`、69 个被课程引用的版本面、2 个补充条目
- 状态：26 `verified`、37 `provisional`、8 `conceptual`
- v2 结构结论：PASS
- v2 实时来源可达性：PASS，93/93，0 失败
- 机器报告：[`version-sources-v2-2026-07-24.json`](../evidence/machine/version-sources-v2-2026-07-24.json)
- 绑定的 registry SHA-256：`bf683ed8c1bf9495c6015ef6ffa8527c1ef66b7089d0e427c210b3f52f944cd7`

PASS 只表示 v2 的结构、原子边界和 2026-07-24 的来源可达性闭合。它不表示 71 个条目
永久正确，也不表示 URL 内容已经被机器理解。条目状态只能人工复核后修改；审计器只读，
`conceptual` 或 `provisional` 绝不因链接可达而自动升级为 `verified`。

## v2 治理合同

1. 顶层 `schema_version` 固定为 2，日期字段使用 `reviewed_at`，避免把一次审阅误称为永久验证。
2. `policy.source_authority` 固定为 `official-or-primary-only`；每条来源记录稳定 ID、类型、
   发布者、authority、检查日期、精确 claim 和 HTTPS URL。
3. `policy.promotion_mode` 固定为 `manual-only`，`automatic_promotion` 固定为 `false`。
4. 旧单值 `source_url` 被 schema 的 `additionalProperties: false` 明确拒绝，不提供 v1 双读。
5. 同一条目的 source ID 必须唯一；来源日期不得晚于条目审阅日期，条目日期不得晚于注册表日期。
6. 来源审计逐 source 建立独立网络结果，拒绝 HTTP、userinfo、HTTPS→HTTP 降级、TLS 失败、
   非 200/206、重复 YAML key 和 worker 异常，并绑定注册表原始字节 SHA。

## 13 个历史 WARN 的关闭方式

| v1 ID | v2 处理 | 仍保留的证据边界 |
|---|---|---|
| `browser` | 改为 `chrome-stable`，分别记录 Stable 发布和 channel 模型 | 每次实验仍记录四段完整版本与 OS |
| `browser-devtools` | 改为 `chrome-devtools`，与记录的 Chrome build 绑定 | 不外推 Firefox/Safari 面板和行为 |
| `ci` | 改为 `github-actions-hosted-runner`，来源覆盖 runner 合同与 image manifests | workflow label 不是不可变镜像；保存 `ImageVersion` |
| `git` | 保留原子产品 ID，删除不存在的统一 supported 窗口声明 | 记录 executable path、发行方和完整版本 |
| `jakarta-ee` | 拆为 `jakarta-servlet-6.1` 与 `jakarta-validation-3.1` | Spring 项目实际依赖仍由 Boot 组合解析 |
| `jdbc` | 拆为 `jdbc-api-jdk-25` 与 `pgjdbc` | pgJDBC patch 由 Maven 锁定并用 PostgreSQL 18 集成测试 |
| `model-api` | 收窄为 `openai-api` | 不把 OpenAI SDK、模型或端点行为外推为提供商中立协议 |
| `observability` | 拆为 specification、semantic conventions、Java、Python、Collector 五项 | 每个 signal、SDK 和 convention group 单独接受成熟度，不声明整体 stable |
| `spring-modulith` | 保留 2.1.x，但把“Boot 4.1 已兼容”改成“注册表未证明” | 章节必须提交真实 Boot 4.1 构建、结构测试和集成测试 |
| `toolchains` | 删除聚合 ID；编辑器章使用 VS Code/IntelliJ，构建章使用 Maven/pnpm/uv | IDE 成功不代替命令行构建证据 |
| `uni-app` | 拆为 Vue 3 CLI 与 mp-weixin compiler package set | 精确 `@dcloudio/*` 组合保存在 lockfile，不声称单一 stable 号 |
| `wechat-miniprogram` | 拆为基础库与微信开发者工具 | 真机客户端和 OS 完整版本仍进入章节证据 |
| `zsh` | 改为 `zsh-5.9` 并从 verified 降为 provisional | 上游手册不证明 macOS 捆绑版本；本机路径/version 由命令输出证明 |

关键一手事实来自 Chrome for Developers/Chrome Releases、GitHub Docs 与
`actions/runner-images`、Eclipse Foundation Jakarta Servlet 6.1 与 Validation 3.1、
Oracle Java SE 25 `java.sql`、pgJDBC 官方下载/文档、OpenAI 官方模型文档与 Python SDK、
OpenTelemetry 分组件状态/规范/语言文档/Collector releases、Spring Modulith 2.1 文档和
兼容矩阵、DCloud CLI/编译器文档及主仓、微信开放文档、Zsh 5.9 上游手册与发布目录。

## 课程迁移

全部 canonical chapter specs、`curriculum/catalog.yml`、reference route 和 255 章 Markdown
front matter 中的 `version_surfaces` 已迁移到 v2 ID。映射按章节责任区分：Servlet/MVC 不再
携带 Validation，Java/Python/运维可观测章节分别引用对应 SDK 或 Collector，通用架构章节
只引用 specification 与 semantic conventions。迁移后这些课程面中不存在 11 个已退役 v1 ID。

## 兼容、回滚与非目标

- 向后兼容：刻意不提供。v1 `source_url` 与 11 个聚合/误命名 ID 已删除；保留它们会让旧 WARN
  继续潜伏。调用者必须原子迁移 schema、registry 和所有课程引用。
- 回滚：在形成单一迁移提交后优先 `git revert <migration-commit>`，同时恢复 schema、registry、
  validator/auditor、测试和课程引用；不得只回滚其中一层制造未知 ID。
- 非目标：本次不自动选择章节精确 patch、不替章节生成兼容性证据、不增加其他模型提供商、
  不把 93/93 URL 可达性解释为内容真值，也不修改任何章节状态或学习进度。
