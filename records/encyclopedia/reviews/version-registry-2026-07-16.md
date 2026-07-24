# 版本注册表 2026-07-16 官方来源审查

> 历史冻结说明：本文件保留 v1 的 44 PASS / 13 WARN / 4 FAIL 原始结论。2026-07-24 的
> 原子 ID、逐来源 claim 与 manual-only 晋升修订见
> [`version-registry-v2-2026-07-24.md`](version-registry-v2-2026-07-24.md)；不得用 v2 结果
> 回写或美化本次历史审查。

## 审查对象与结论

- 审查对象：[versions/registry.yml](../../../versions/registry.yml)
- 结构契约：[schemas/version-registry.schema.json](../../../schemas/version-registry.schema.json)
- 审查日期：2026-07-16
- 审查方式：本地 schema/一致性检查、61 项静态检查、全部来源 URL 可达性检查，以及高风险项目的官方文档、发布页和兼容矩阵联网核验。
- 总体结论：**FAIL**
- 项目文件改动：本报告之外无改动；没有修改版本注册表、课程目录或进度记录。

逐项语义结论为：

- PASS：44 项
- WARN：13 项
- FAIL：4 项

本报告中的 PASS 表示：当前约束没有被官方资料否定，来源是一手来源，并且动态版本存在正确的官方解析入口。PASS 不表示所有 patch 已永久冻结；注册表的 <code>patch_resolution: at-chapter-verification</code> 仍要求在章节验证时解析并记录实际 patch。

## P1R 修正状态（同日追加）

上面的 44/13/4 是修正前 2026.1 注册表的冻结审查结果，不得改写成“当时已通过”。P1R 已按推荐方案修改 `versions/registry.yml`：

1. Flyway 的约束改为服从所选 Spring Boot 4.1.x dependency management；主证据改为 Spring Boot 官方 managed coordinates。Boot 4.1.0 当前列出的 Flyway 版本为 12.4.0。
2. 泛型 `linux` 收窄为不声明发行版版本的 conceptual 项；新增 `ubuntu-server-26.04` 作为生产实验基线。Ubuntu 官方 26.04 LTS 发布说明声明标准安全维护到 2031 年 4 月。
3. `oauth2-oidc` 拆为 `oauth2-security-bcp`（RFC 9700）和 `oidc-core`（OpenID Connect Core 1.0 errata set 2），分别证明授权安全与身份层规范。
4. 删除未被课程引用且官方仓库已归档的 `minio` current-stable 声明；对象存储只保留实现无关的 S3 契约 topic，未来若选具体实现必须新建独立版本项。

修正后注册表为 62 个唯一条目、edition `2026.2-draft`。四个原 FAIL 已在规范层关闭；13 个 WARN 继续作为章节验证前的显式跟进，不因这次修正自动升级为 PASS。最终结论仍须等待 P1R catalog、P2 schema、来源映射和确定性构建全部回归通过。

## 静态与机器校验结果

实际执行：

~~~text
ruby scripts/validate-encyclopedia.rb

ENCYCLOPEDIA VALID
schemas_executed=3
chapters=170
status_planned=170
status_drafting=0
status_review=0
status_verified=0
registry_entries=61
referenced_version_surfaces=59
supplemental_registry_entries=2
generated=not-checked
content_truth=not-asserted
~~~

静态检查确认：

- 顶层 <code>schema_version: 1</code>、<code>registry_id: factorycare-version-registry</code> 符合 schema。
- <code>edition: 2026.1-draft</code> 与 curriculum catalog、site config 一致。
- 61 个条目均具备全部必需字段，没有额外字段。
- ID 无重复，均满足 ID 格式。
- 61 个 <code>verified_at</code> 均为合法日期，不晚于顶层日期 2026-07-15，也不晚于审查日期。
- 状态分布：verified 24、provisional 29、conceptual 8。
- 类型分布：platform 4、tool 14、service 8、standard 6、language 2、framework 14、runtime 3、library 8、protocol 2。
- 全部来源均使用 HTTPS；没有 userinfo、空 host 或明显第三方转载来源。
- URL 可达性探测结果为 60 个 HTTP 200、1 个 HTTP 404；404 是 Flyway 旧发布页。

机器校验器明确输出 <code>content_truth=not-asserted</code>。因此 schema 通过只证明结构闭合，不证明版本事实、兼容关系或来源覆盖范围正确，本报告的联网语义审查不能被机器校验替代。

## FAIL：必须修正的 4 项

### 1. Flyway 来源失效且不能证明 Boot BOM 约束

- YAML 路径：<code>entries[id=flyway].source_url</code>
- 当前值：https://documentation.red-gate.com/flyway/reference/release-notes
- 实测结果：HTTP 404
- 当前约束：<code>Spring Boot 4.1 BOM-compatible release</code>

问题有两层：

1. 当前 URL 已失效。
2. Flyway 自身最新发布页只能说明 Flyway 当前版本，不能说明 Spring Boot 4.1 实际管理哪个版本。

建议：

- 将约束写成“由所选 Spring Boot 4.1.x dependency management 管理的版本”。
- 以 [Spring Boot 4.1 Managed Dependency Coordinates](https://docs.spring.io/spring-boot/appendix/dependency-versions/coordinates.html) 作为该约束的主证据。
- Spring Boot 4.1.0 当前管理 Flyway 12.4.0；不要因为 Flyway 自身已发布更新版本就擅自覆盖 Boot 组合。
- 将 [Flyway Engine 官方发布记录](https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine) 作为上游版本和安全信息的补充来源。

### 2. Linux 约束是发行版，来源却是内核

- YAML 路径：<code>entries[id=linux].constraint</code>、<code>entries[id=linux].source_url</code>
- 当前约束：<code>current supported LTS server distribution</code>
- 当前来源：https://www.kernel.org/category/releases.html

kernel.org 的页面记录 Linux kernel LTS，不是服务器发行版生命周期。发行版还包含用户空间、包仓库、安全维护和镜像策略，不能用内核 LTS 页面证明。

建议优先采用以下结构：

- 保留泛型 <code>linux</code>，但只作为 conceptual 平台概念，不声明某个发行版版本。
- 新增具体部署基线，例如 <code>ubuntu-server-26.04</code>，约束为 <code>26.04 LTS</code>。
- 使用 [Ubuntu 官方生命周期](https://ubuntu.com/about/release-cycle) 和 [Ubuntu 26.04 LTS 发布说明](https://documentation.ubuntu.com/release-notes/26.04/)。

若课程确实只想记录内核，则应将 ID 和名称改成 Linux kernel，并把约束改成“current supported kernel LTS”。

### 3. OAuth/OIDC 的唯一来源只覆盖 OAuth

- YAML 路径：<code>entries[id=oauth2-oidc].source_url</code>
- 当前约束：<code>current OAuth security best practice plus OIDC Core</code>
- 当前来源：https://www.rfc-editor.org/rfc/rfc9700.html

[RFC 9700](https://www.rfc-editor.org/rfc/rfc9700.html) 是 OAuth 2.0 Security Best Current Practice，不是 OpenID Connect Core。当前单一 URL 无法证明约束的 OIDC 部分。

建议：

- 最佳方案：拆成 <code>oauth2-security-bcp</code> 与 <code>oidc-core</code> 两个条目。
- OAuth 条目引用 RFC 9700。
- OIDC 条目引用 [OpenID Connect Core 1.0 incorporating errata set 2](https://openid.net/specs/openid-connect-core-1_0-errata2.html)。
- 如果不拆条目，则 schema 需要从单个 <code>source_url</code> 扩展为可保存多个权威来源的结构。

### 4. MinIO 已归档，不能再称 current stable

- YAML 路径：<code>entries[id=minio].constraint</code>
- 当前约束：<code>current stable S3-compatible local release</code>
- 当前来源：https://github.com/minio/minio/releases

[MinIO 官方仓库](https://github.com/minio/minio/releases) 已于 2026-04-25 归档。最后一个开源 release 是 <code>RELEASE.2025-10-15T17-29-55Z</code>，后期分发已经转成 source-only。归档项目不存在可持续解析的“current stable”发布通道。

建议在架构评审中二选一：

1. 将最后版本精确冻结，明确标成 archived、evaluation-only，禁止将其作为当前生产推荐。
2. 替换为仍维护的 S3 兼容本地实现，并为新实现建立独立版本项和官方来源。

如果需要保留历史记录，schema 最好增加 retired/deprecated 状态。相关风险还应结合 [MinIO 官方安全页](https://github.com/minio/minio/security) 复核。

## WARN：需要收紧范围或补充证据的 13 项

| ID | 当前问题 | 建议 |
|---|---|---|
| browser | 名称是泛型 Web browser，来源只覆盖 Chrome | 若主线固定 Chrome，改成 Chrome；否则按浏览器拆分并分别记录版本 |
| browser-devtools | 名称是泛型 DevTools，来源只覆盖 Chrome DevTools | 与 browser 使用相同产品边界 |
| ci | 名称是泛型 CI runner，约束和来源实际都是 GitHub Actions | 改成 GitHub Actions runner，或增加其他 CI 实现的来源 |
| git | Git 官方没有统一的 supported stable 支持窗口，docs 首页也不是发布历史 | 改成“selected toolchain current stable”，章节记录实际版本和发行方 |
| jakarta-ee | 没写具体规范级别；Spring 只采用部分 Jakarta 规范，不依赖整个 EE 平台 | 记录实际 Servlet、Validation、Persistence 等 API 级别，或明确 Jakarta EE 11 仅是规范集合参照 |
| jdbc | Oracle URL 只证明 JDK JDBC API，不能证明 PostgreSQL driver | 拆成 jdbc-api 与 pgjdbc；驱动使用 [pgJDBC 官方下载页](https://jdbc.postgresql.org/download/) |
| model-api | ID 和约束是 provider-neutral，唯一来源却是 OpenAI | 若只教 OpenAI，改成 openai-api 并使用 [OpenAI 官方 SDK 页面](https://developers.openai.com/api/docs/libraries/)；多提供商应拆条目 |
| observability | OpenTelemetry 各信号、SDK 和 semantic convention group 成熟度混合 | 只使用逐项标记为 stable 的部分，并分别锁定 Java、Python、Collector 和 semconv 版本 |
| spring-modulith | 当前文档显示 2.1.0，但兼容表仍只列 2.0 snapshot 与 Boot 4.0 | 保持 provisional；进入章节后使用 Boot 4.1 实际构建、结构测试和集成测试证明 |
| toolchains | 泛型工具链概念却只引用 asdf | 改成 asdf，或只作为 conceptual 聚合项并引用具体 JDK、Node、Python、Flutter ID |
| uni-app | 官方首页没有统一、可复现的 stable 版本标识 | 同时记录 CLI/HBuilderX、编译器、Vue line 和目标平台版本 |
| wechat-miniprogram | Framework 首页不能解析当前基础库、开发者工具和客户端的精确组合 | 章节验证时记录基础库、开发者工具、客户端与真机版本 |
| zsh | zsh 官方手册不能证明 macOS 26 捆绑版本 | 本机只读核验为 zsh 5.9；应配合本机证据和 Apple 系统证据，状态宜为 provisional |

OpenTelemetry 的混合成熟度可由 [Specification Status Summary](https://opentelemetry.io/docs/specs/status/) 与 [Semantic Conventions 1.43.0](https://opentelemetry.io/docs/specs/semconv/) 交叉确认。

## 61 项逐项结果

| # | ID | 结果 | 结论 |
|---:|---|---|---|
| 1 | browser | WARN | 泛型范围与 Chrome 来源不一致 |
| 2 | browser-devtools | WARN | 泛型范围与 Chrome 来源不一致 |
| 3 | ci | WARN | 实际是 GitHub Actions 专用项 |
| 4 | css | PASS | W3C 一手来源，约束合理 |
| 5 | dart-stable | PASS | Flutter 3.44.6 当前捆绑 Dart 3.12.2 |
| 6 | docker | PASS | 官方 release notes 可解析，provisional 合理 |
| 7 | fastapi | PASS | 当前稳定线支持 Python 3.14 和 Pydantic 2 |
| 8 | flutter-stable | PASS | 当前 stable 为 3.44.x |
| 9 | flyway | FAIL | URL 404，且来源不能证明 Boot 管理版本 |
| 10 | git | WARN | supported stable 的定义不明确 |
| 11 | html-living-standard | PASS | WHATWG Living Standard |
| 12 | jakarta-ee | WARN | 未明确 Spring 实际采用的 Jakarta 规范级别 |
| 13 | jdbc | WARN | 一个来源无法覆盖 API 与 PostgreSQL driver |
| 14 | jdk-25 | PASS | JDK 25 是 LTS |
| 15 | junit-6 | PASS | JUnit 6 当前成立；Boot 4.1 管理 6.0.3 |
| 16 | langchain | PASS | 1.x 官方稳定线 |
| 17 | langgraph | PASS | 1.x 官方稳定线 |
| 18 | linux | FAIL | 内核来源不能证明服务器发行版 |
| 19 | macos-26 | PASS | macOS 26.x 当前成立 |
| 20 | maven-3 | PASS | Maven 3.9.16 官方发布日期可确认 |
| 21 | mcp | PASS | 官方 latest 当前指向 2025-11-25 规范 |
| 22 | model-api | WARN | provider-neutral 与 OpenAI-only 来源冲突 |
| 23 | mybatis | PASS | MyBatis Core 3.5 与 Starter 4.0 的边界正确 |
| 24 | nginx | PASS | 官方 stable 解析入口正确 |
| 25 | node-24-lts | PASS | Node 24 当前为 LTS |
| 26 | numpy | PASS | 当前稳定线支持 CPython 3.14 |
| 27 | nuxt-4 | PASS | Nuxt 4 当前 active/stable |
| 28 | oauth2-oidc | FAIL | 唯一来源遗漏 OIDC Core |
| 29 | observability | WARN | OpenTelemetry 组件成熟度并不统一 |
| 30 | pandas | PASS | 当前稳定线支持 Python 3.14 |
| 31 | pinia | PASS | 一手来源正确，动态 patch 延后解析合理 |
| 32 | pnpm | PASS | 11.x 与 Node 24 兼容 |
| 33 | postgresql-18 | PASS | PostgreSQL 18.x 当前受支持 |
| 34 | python-3.14 | PASS | CPython 3.14.x 当前稳定线 |
| 35 | pytorch-stable | PASS | 官方安装页明确覆盖 Python 3.14 |
| 36 | redis | PASS | Redis 8.x 当前成立，最新稳定线已到 8.8 |
| 37 | spring-boot-4.1 | PASS | Spring Boot 4.1.0 GA |
| 38 | spring-framework-7 | PASS | Boot 4.1 使用 Spring Framework 7.0.8+ |
| 39 | spring-modulith | WARN | 官方兼容表不足以证明 Boot 4.1 组合 |
| 40 | spring-security | PASS | Boot 4.1 管理 Spring Security 7.1.0 |
| 41 | toolchains | WARN | 泛型概念与 asdf 单一来源不匹配 |
| 42 | typescript | PASS | 官方发布入口正确，实际版本延后锁定 |
| 43 | uni-app | WARN | 缺少统一、可复现的 stable 标识 |
| 44 | uv | PASS | 官方 versioning policy 正确 |
| 45 | vite | PASS | Vite 8 stable，Node 24 主线合理 |
| 46 | vue-3 | PASS | Vue 3 当前稳定线 |
| 47 | wechat-miniprogram | WARN | 基础库与工具版本未具体化 |
| 48 | zsh | WARN | 来源不能证明 macOS 捆绑版本 |
| 49 | spring-ai-2 | PASS | Spring AI 2.0.x 支持 Boot 4.0/4.1 |
| 50 | mysql-8.4 | PASS | MySQL 8.4 LTS 正确 |
| 51 | pgvector | PASS | pgvector 0.8.2 已明确支持 PostgreSQL 18 |
| 52 | pydantic-2 | PASS | Pydantic 2 与当前 FastAPI/Python 3.14 路线一致 |
| 53 | pytest | PASS | pytest 8.4.1+ 正式支持 Python 3.14 |
| 54 | vitest | PASS | 官方来源正确，可随所选 Vite 解析 |
| 55 | playwright | PASS | 当前稳定发布入口正确 |
| 56 | docker-compose | PASS | Compose v2 主线正确 |
| 57 | minio | FAIL | 官方项目已归档，不能称 current stable |
| 58 | rabbitmq | PASS | RabbitMQ 4.3 当前为最新完整支持系列 |
| 59 | testcontainers | PASS | Boot 4.1 管理 Testcontainers 2.0.5 |
| 60 | mockito | PASS | Boot 4.1 管理 Mockito 5.23.0 |
| 61 | openapi | PASS | 当前规范 3.2.0；按工具链选择受支持版本合理 |

## 已联网确认的关键版本主线

- Flutter 官方发布数据当前为 Flutter 3.44.6 与 Dart 3.12.2：[Flutter SDK archive](https://docs.flutter.dev/install/archive)。
- JDK 25 是 LTS：[Oracle Java SE Support Roadmap](https://www.oracle.com/java/technologies/java-se-support-roadmap.html)。
- Node 24 是 LTS：[Node.js Releases](https://nodejs.org/en/about/previous-releases)。
- Maven 3.9.16 于 2026-05-13 发布：[Maven Version History](https://maven.apache.org/docs/history.html)。
- Spring Boot 4.1.0 要求 Java 17+，并要求 Spring Framework 7.0.8 或以上：[Spring Boot System Requirements](https://docs.spring.io/spring-boot/system-requirements.html)。
- Boot 4.1.0 当前管理 JUnit 6.0.3、Flyway 12.4.0、Mockito 5.23.0 和 Testcontainers 2.0.5：[Boot Managed Dependency Coordinates](https://docs.spring.io/spring-boot/appendix/dependency-versions/coordinates.html)。
- Spring AI 2.0.x 支持 Boot 4.0.x 与 4.1.x：[Spring AI Getting Started](https://docs.spring.io/spring-ai/reference/getting-started.html)。
- MyBatis Spring Boot Starter 4.0.0 对应 Boot 4.0+、MyBatis-Spring 4.0，而 Core 仍为 3.5+：[MyBatis Starter Requirements](https://mybatis.org/spring-boot-starter/mybatis-spring-boot-autoconfigure/)。
- Python 当前 3.14.x 稳定线：[Python Downloads](https://www.python.org/downloads/)。
- NumPy 当前稳定线支持 Python 3.14：[NumPy News](https://numpy.org/news/)。
- pandas 当前稳定线支持 Python 3.14：[pandas Release Notes](https://pandas.pydata.org/pandas-docs/stable/whatsnew/index.html)。
- pytest 已正式支持 Python 3.14：[pytest Changelog](https://docs.pytest.org/en/stable/changelog.html)。
- FastAPI 当前路线要求 Pydantic 2，Python 3.14 不应继续使用 Pydantic 1：[FastAPI Pydantic Migration](https://fastapi.tiangolo.com/how-to/migrate-from-pydantic-v1-to-pydantic-v2/)。
- PostgreSQL 18 当前受支持：[PostgreSQL Versioning Policy](https://www.postgresql.org/support/versioning/)。
- pgvector 0.8.2 已提供 PostgreSQL 18 构建与镜像说明：[pgvector 官方仓库](https://github.com/pgvector/pgvector)。
- Nuxt 4 是当前 active 版本：[Nuxt Roadmap](https://nuxt.com/docs/4.x/community/roadmap/)。
- Vite 8 已发布稳定版：[Vite 8 Announcement](https://vite.dev/blog/announcing-vite8)。
- Redis 当前已到 8.8，仍属于约束中的 8.x：[Redis Open Source Release Notes](https://redis.io/docs/latest/operate/oss_and_stack/stack-with-enterprise/release-notes/redisce/)。
- RabbitMQ 4.3 是当前最新完整支持系列：[RabbitMQ Release Information](https://www.rabbitmq.com/release-information)。
- OpenAPI 最新发布规范为 3.2.0：[OpenAPI Specification Versions](https://spec.openapis.org/oas/)。
- MCP 当前 latest 为 2025-11-25：[MCP Specification](https://modelcontextprotocol.io/specification/)。
- OpenAI 官方 SDK 与 Responses API 的当前入口：[OpenAI SDKs and CLI](https://developers.openai.com/api/docs/libraries/)。

## 无法完全验证的边界

- PyTorch 安装页是动态选择器。已确认官方页面接受 Python 3.14，但本次没有把精确 PyTorch patch 写入注册表。
- Spring Modulith 官方当前文档显示 2.1.0，但公开兼容表不足以证明 2.1 与 Boot 4.1 的组合；必须使用真实项目构建和测试证据。
- uni-app、微信基础库和开发者工具缺少统一、稳定、机器可解析的版本入口，必须在章节验证时记录完整工具组合。
- model-api 只核验了当前唯一来源 OpenAI；没有 Anthropic、Google 或其他 provider 的注册来源，不能从 OpenAI 文档外推。
- 写成 current stable 的 provisional 项，只确认了官方稳定渠道和兼容方向；精确 patch 仍由章节验证解析。
- 本次没有为 MinIO 选择替代产品，因为这属于存储架构决策，需要单独比较迁移成本、兼容性、安全维护和回滚方案。

## Schema 与治理风险

当前文件能够通过 schema，但 schema 本身不能表达或强制以下语义：

- <code>edition</code> 只要求非空，跨 registry、catalog、site 的一致性依赖额外校验逻辑。
- JSON Schema 无法按对象内的 <code>id</code> 强制唯一，目前由仓库校验器补充保证。
- 只有一个 <code>source_url</code>，无法正确表达 OAuth+OIDC、JDBC+pgJDBC 等复合约束。
- <code>stable_only</code> 不能根据自由文本 channel、constraint 自动识别 preview、beta 或已归档项目。
- verified、provisional、conceptual 都被要求填写 <code>verified_at</code>，字段语义实际上更接近 reviewed_at。
- 动态约束和具体兼容关系都保存在自由文本中，schema 无法验证“Boot 4.1 管理哪个版本”这类事实。

## 建议处理顺序

1. 先关闭 4 个 FAIL：修 Flyway 来源、明确 Linux 发行版、拆 OAuth/OIDC、决定 MinIO 退役或替代策略。
2. 再处理来源模型：让 schema 支持一个约束对应多个官方来源，或将复合条目拆成原子条目。
3. 收紧泛型 ID：browser、DevTools、CI、model API、toolchains 应与真实实现边界一致。
4. 为动态平台建立章节证据模板：记录产品、完整版本、操作系统、锁文件、命令输出和验证日期。
5. 保持所有 provisional 项在章节进入 review 前重新联网核验，不因本报告的 PASS 跳过章级 evidence。

## 有意未做

- 没有修改 [versions/registry.yml](../../../versions/registry.yml)。
- 没有修改 schema、curriculum、book、site 或 PROGRESS.md。
- 没有替课程选择 MinIO 替代品。
- 没有把 schema 校验成功解释为内容事实已经验证。
- 没有将任何章节从 planned 推进到 drafting、review 或 verified。
