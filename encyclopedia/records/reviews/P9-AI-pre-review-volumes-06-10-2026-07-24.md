# P9 AI 独立预审：卷 06—10（2026-07-24）

- `actor_class=AI`
- `review_kind=AI-assisted-independent-pre-review`
- `human_review=false`
- `attestation_effect=none`
- `dod_human_gate=OPEN`
- `review_date=2026-07-24`
- `base_commit=6bb82f14c6c3`（同时阅读了当时工作树中的未提交教材端点）
- `scope=volume-06-enterprise-architecture,volume-07-web-platform,volume-08-javascript-typescript,volume-09-vue-nuxt,volume-10-uniapp-miniprogram`

> 本记录由 AI 对当前字节进行只读语义预审。它不是独立真人内容复核、不是零基础学习者试读、不是人工无障碍/版式验收，也不是 review attestation。它不能创建、替代或关闭 `verification/review-attestations/<chapter-id>.yml`，不能关闭 Definition of Done 的真人门，不能把任何章节推进到 `review`、`verified` 或公开发行状态。下文的 `AI-clean` 只表示本轮 AI 阅读没有发现可定位的章级问题，不等于最终 `PASS`。

## 1. 范围、方法和证据边界

- 逐章阅读卷 06—10 的 77 章正文：卷 06 为 19 章、卷 07 为 13 章、卷 08 为 18 章、卷 09 为 15 章、卷 10 为 12 章。
- 对每章同时阅读同 ID 的公开 `examples/encyclopedia/`、`exercises/encyclopedia/`、`labs/encyclopedia/`；只读检查相应 `solutions-private/encyclopedia/` 的接口与 oracle 形状，不把私有解泄露给公开内容。
- 按 [`REVIEW-RUBRIC.md`](../REVIEW-RUBRIC.md) 的技术正确性、零基础教学、代码与可重复性、安全/隐私/可靠性、可访问性、版本与来源、出版与导航七个评审面检查，并对照 front matter 的 prerequisites、responsibility 和三类 outcomes。
- 检查重点包括：概念首次出现与先修图、从预测到 expected-red 再到 green 的可达性、错误/竞态/取消/幂等/授权边界、离线模型与真实框架/浏览器/设备证据的区别、FactoryCare 事实所有权和版本敏感陈述。
- 静态完整性结果：范围内 77/77 章均有正文及同章 example/exercise/lab/private-solution 角色；共检查 403 个 Markdown 文件中的 344 个相对链接，未发现断链。
- 为保持预审只读，没有执行会删除/重建目录或下载依赖的 77 章全量 verifier，没有启动 Spring/PostgreSQL/Redis/消息代理、真实浏览器、DCloud/微信开发者工具或移动设备。因此本记录不宣称真实运行时通过。
- 本轮只新增本记录；未修改教材、示例、练习、实验、私有解、manifest、attestation、release 或 `PROGRESS.md`。

## 2. 总体结论

**AI 预审结论：`FAIL`。** 77 章中，33 章存在 blocker，3 章存在不单独阻断整章但必须修复的 major follow-up，41 章为 `AI-clean`。blocker 主要不是正文概念错误，而是公开练习的完成态不可达，以及两个零基础硬前置图与实际独立实现任务不一致。

| 分卷 | AI-clean | AI-follow-up | FAIL | 小计 |
| --- | ---: | ---: | ---: | ---: |
| 卷 06：企业架构、安全与分布式系统 | 1 | 0 | 18 | 19 |
| 卷 07：Web 平台与 CSS | 1 | 0 | 12 | 13 |
| 卷 08：JavaScript 与 TypeScript | 16 | 2 | 0 | 18 |
| 卷 09：Vue 与 Nuxt | 13 | 0 | 2 | 15 |
| 卷 10：uni-app 与小程序 | 10 | 1 | 1 | 12 |
| **合计** | **41** | **3** | **33** | **77** |

按七个评审面汇总：

| 评审面 | AI 预审结论 | 说明 |
| --- | --- | --- |
| 技术正确性 | PASS_WITH_FOLLOW_UP | 稳定核心、简化模型和真实环境边界总体清楚；版本表面仍需真人按正式冻结日复核。 |
| 零基础教学 | FAIL | F02、F03 是硬前置图无法解释的必需概念，命中 rubric 阻断项。 |
| 代码与可重复性 | FAIL | F01 使 32 个公开练习的统一入口无法从登记 starter 到达 solved green。 |
| 安全、隐私与可靠性 | PASS_WITH_FOLLOW_UP | 未发现鼓励明文凭据、前端单独授权或把 mock 当生产保证；仍需真实系统安全验证。 |
| 可访问性与包容性 | PASS_WITH_FOLLOW_UP | 语义、键盘、焦点、对比度、读屏和减少动画均有教学入口；尚无人工 AT/设备证据。 |
| 版本与来源 | PASS_WITH_FOLLOW_UP | 版本敏感面有复核日期和官方入口；Nuxt、Vite、TypeScript 等当前版本仍需发行前重新冻结。 |
| 出版与导航 | PASS_WITH_FOLLOW_UP | 本范围静态相对链接未断；未执行 HTML/EPUB/PDF 与人工版式/阅读顺序验收。 |

## 3. 有证据的跨章 findings

### F01 — blocker：32 个公开练习的统一入口无法接受正确完成态

影响范围：卷 06 的 18 章、卷 07 的 12 章、卷 09 的 2 章，共 32 章。

卷 06 受影响章节：

- `ch.architecture.domain-events-outbox`
- `ch.architecture.idempotency-concurrency`
- `ch.architecture.modular-monolith`
- `ch.architecture.workflow-state-sla`
- `ch.distributed.messaging-delivery`
- `ch.distributed.redis-cache-rate-limit`
- `ch.security.audit-events-privacy`
- `ch.security.authorization-rbac-abac`
- `ch.security.cookie-session-model`
- `ch.security.identity-password-lifecycle`
- `ch.security.jwt-resource-server`
- `ch.security.multitenancy-data-isolation`
- `ch.security.oauth2-oidc`
- `ch.security.origin-cors-csrf`
- `ch.security.session-authentication`
- `ch.security.spring-security-architecture`
- `ch.security.threat-model-trust-boundaries`
- `ch.security.untrusted-input-xss-ssrf`

代表性证据：

- `exercises/encyclopedia/ch.architecture.domain-events-outbox/README.md:3-9` 要求修复 8 个 TODO，只给 `./verify.sh`。
- 同章 `verify.sh:11-27` 编译运行 public starter；程序修复后退出 0 时，脚本在 `:12-14` 反而输出 `STARTER UNEXPECTEDLY PASSED` 并退出 42；只有原始 marker 与精确 TODO 数仍存在时才返回 expected-red 41。
- `src/DomainEventsOutboxChallenge.java:9-40` 已把八个 TODO 和成功输出定义为学习者的可编辑目标，因此问题不是“没有答案”，而是公开完成命令不可达。
- `ch.security.cookie-session-model/README.md:11-22`、`ch.security.origin-cors-csrf/README.md:13-22`、`ch.security.session-authentication/README.md:5-14`、`ch.security.spring-security-architecture/README.md:5-14`、`ch.security.untrusted-input-xss-ssrf/README.md:5-14` 甚至写出了正确目标输出，但同章 public wrapper 仍把该输出视为 unexpected pass。

卷 07 受影响章节：

- `ch.web.browser-render-devtools`
- `ch.web.origin-cookie-cache`
- `ch.web.semantic-html`
- `ch.web.forms-validation`
- `ch.web.media-assets`
- `ch.web.accessibility-interaction`
- `ch.css.cascade`
- `ch.css.box-position`
- `ch.css.flexbox`
- `ch.css.grid`
- `ch.css.theme-variables`
- `ch.css.motion-compositing`

代表性证据：

- `exercises/encyclopedia/ch.css.cascade/verify.sh:9-22` 的内层合同硬要求 oracle 返回 1、输出精确匹配 `expected-red.out`，然后显式 `exit 1`。
- 同脚本 `:31-42` 后加了 `contract_status == 0` 的 green 分支，但正确答案使内层 oracle 返回 0，内层随即在 `:12-15` 将其转换为 2；因此外层 green 分支不可达，最终返回 43。
- `exercises/encyclopedia/ch.web.browser-render-devtools/README.md:3-9` 与 `ch.web.origin-cookie-cache/README.md:3-9` 只把 `./verify.sh` 作为公开验证器；其他章节即使提到可直接调用内层 Ruby oracle，也同时把 public wrapper 描述成练习验证入口，形成两个互相矛盾的退出码合同。

卷 09 受影响章节：

- `ch.vue.auth-permissions`
- `ch.vue.server-state`

代表性证据：

- `exercises/encyclopedia/ch.vue.auth-permissions/verify.sh:8-18` 硬要求 checker 返回 1 并在快照匹配后显式 `exit 1`；`:27-38` 的外层 green 分支因此不可达。
- `exercises/encyclopedia/ch.vue.server-state/verify.sh` 使用相同形状。其 README 虽给出直接运行 `node scripts/check-contract.mjs` 的完成方向，public `./verify.sh` 本身仍固定为 starter-only，无法承担统一的构建 outcome。

判断：私有解使用另一份类或另一条脚本只能证明“存在解”，不能证明学习者修复公开 starter 后可用公开主命令闭环。该问题破坏“预测 → 同一入口 expected-red → 修改 → 同一入口 green → 保留负向 fixture”的可重复学习合同，故按代码与零基础教学面判为 blocker。

建议统一所有公开入口为三态合同：

1. 精确完成态通过正例及全部独立负向/fault fixtures：退出 0，并输出 `EXERCISE_GREEN`；
2. 仅登记的原始 starter 失败形状：退出 41，并输出 `EXPECTED_RED`；
3. 部分修复、错误数量/输出漂移、编译/基础设施异常：退出 43（或项目正式登记的 unknown 状态），不得伪装成 expected-red；
4. 在全新临时副本分别证明 starter=41、solved=0、partial/unknown=43，并把 README 中唯一主命令固定为 `./verify.sh`；
5. 继续保留越权、竞态、重复投递、XSS/SSRF、键盘/焦点、类型错误等负向 fixture，不能只为获得绿灯删除断言。

### F02 — blocker：卷 07 第一章要求从空白独立写 HTML/CSS/SVG，但硬前置图只有 HTTP

证据：

- `book/volume-07-web-platform/chapters/ch.web.browser-render-devtools.md:13-14` 的唯一章节前置是 `ch.foundations.http-curl`。
- 同章 `:46-64` 把“制作一个最小页面”登记为独立 build outcome，`:317-331` 使用 `python3 -m http.server`，但 Python 运行时既不在前置图中，也尚未进入 Python 卷。
- 同章 `:416-424` 明确说本章不系统教授 CSS；`:428-439` 又要求读者从空目录独立编写 HTML、外部 CSS 和本地 SVG。
- `curriculum/capabilities.yml:650-657` 中 `web.browser-rendering` 只 requires `foundation.http-message`；`curriculum/concept-graph.md:55-61` 也把 browser rendering 放在 semantic HTML/CSS capability 之前。
- `records/encyclopedia/REVIEW-RUBRIC.md:57-63` 把“零基础路线出现无法由前置图解释的必需概念”列为 `FAIL`。

判断：正文对浏览器加载、Network/DOM/computed style 与证据包的解释本身清楚；阻断发生在“读者能否凭已登记前置独立完成 build”这一合同。会运行 curl 并不等于会从空白编写 HTML/CSS/SVG，也不自动拥有 Python。

建议二选一并同步 capability graph：

1. 在该章之前增加“最小静态 HTML/CSS 页面与本地服务”能力/章节，明确教授最少语法、文件引用和可用 server 工具；或
2. 保留当前顺序，但把本章 build 改为修改/诊断仓库已提供的完整 fixture，把从空白创作延后到 semantic HTML/CSS 章节。

若继续使用 Python server，必须把它作为可验证工具前置，提供精确命令、工作目录、停止方式和无 Python 时的仓库内 fallback，不能静默假设存在。

### F03 — blocker：小程序运行时章的硬前置图遗漏 JavaScript 语言与异步模型

证据：

- `book/volume-10-uniapp-miniprogram/chapters/ch.miniapp.runtime.md:13-14` 只前置 `ch.foundations.cli-streams-exit-codes`。
- 同章 `:45-64` 登记独立创建原生双页面小程序的 build outcome，`:91-94` 生成的先修说明仍只有 CLI。
- 同章 `:102-111` 要求读者创建双页面应用；`:123-131`、`:168-170` 引入 JavaScript 宿主和对象字面量；`:212-225` 直接使用 `Page({...})`、方法简写、`const`、空值合并、三元表达式和 `this.setData`；`:245-255` 又使用函数、Promise 与 callback；`:275-293`、`:312-328` 使用 App/Page 对象、可选链和生命周期逻辑。
- `curriculum/capabilities.yml:1012-1018` 的 `mobile.miniprogram-runtime` 只 requires shell；`curriculum/concept-graph.md:296-300` 同样没有 JavaScript/异步能力边。

判断：顺序通读全书的读者大概率在卷 08 学过 JavaScript，但正式 prerequisites/capability graph 同时承担零基础跳转、补救和加速路线合同。它当前宣称“仅凭 CLI 即可独立写上述程序”，与实际任务不符，命中 rubric 的隐藏必需前置 blocker。

建议：给章节和 capability 增加 JavaScript runtime/语句变量、函数、对象模型和 event-loop/Promise 的硬前置（至少对应 `ch.js.runtime-esm`、`ch.js.statements-variables`、`ch.js.functions`、`ch.js.object-model`、`ch.js.event-loop`）；或者把本章改为使用已给定 fixture 的概念观察，等这些前置满足后再要求独立写页面逻辑。

### F04 — major：15 处文档仍声明 public expected-red 退出 1，当前 wrapper 已对外返回 41

证据位置：

- 卷 07：`exercises/encyclopedia/ch.css.box-position/README.md:9`、`ch.css.cascade/README.md:9`、`ch.css.flexbox/README.md:9`、`ch.css.grid/README.md:9`、`ch.css.motion-compositing/README.md:5`、`ch.css.theme-variables/README.md:5`、`ch.web.accessibility-interaction/README.md:9`、`ch.web.forms-validation/README.md:9`、`ch.web.media-assets/README.md:9`、`ch.web.semantic-html/README.md:9`。
- 卷 08：`exercises/encyclopedia/ch.ts.generics-utilities/README.md:13`、`ch.ts.modeling-narrowing/README.md:12`。
- 卷 09：`exercises/encyclopedia/ch.vue.auth-permissions/README.md:5`、`ch.vue.server-state/README.md:5`。
- 卷 10：`book/volume-10-uniapp-miniprogram/chapters/ch.uniapp.factorycare-reporter.md:458`。
- 当前对外形状可由 `exercises/encyclopedia/ch.css.cascade/verify.sh:35-42`、`ch.ts.generics-utilities/verify.sh:55-66`、`ch.vue.auth-permissions/verify.sh:27-38`、`ch.uniapp.factorycare-reporter/verify.sh:18-29` 复核：登记 starter 被外层转换为 41。

判断：退出 1 可能仍是内层 Ruby/Node oracle 的原始失败码，但文档明确把它写成 public `./verify.sh` 的结果，学习者会把正确的 41 误判为脚本漂移。F04 与 F01 重叠时由 blocker 主导；仅受 F04 影响的两个 TypeScript 章和 FactoryCare reporter 章记为 major follow-up。

建议：统一文档说明 public wrapper 的精确合同：0=完成态 green、41=已识别的登记 starter、43=未知/部分修复/基础设施状态。若教学需要展示“内层 oracle 返回 1”，必须显式写“这是内层命令，不是 `./verify.sh`”，并给出两条命令各自的输出。

## 4. 逐章 AI 预审索引

表中“同章端点”指该章节 ID 对应的正文、example、exercise、lab 和 private-solution 接口均已阅读。`AI-clean` 仍保留右栏中的真人/真实环境门；它不是最终 PASS。

### 4.1 卷 06：企业架构、安全与分布式系统

| 章节 | AI 结果 | 严重度 | 本轮阅读结论与后续门 |
| --- | --- | --- | --- |
| `ch.security.threat-model-trust-boundaries` | FAIL（F01） | blocker | 资产、主体、数据流、信任边界、滥用场景和 control→verification 追踪链清楚，含内部人和负例；公开练习完成态不可达。真人需复核威胁覆盖而非只看矩阵存在。 |
| `ch.security.identity-password-lifecycle` | FAIL（F01） | blocker | 密码记录、salt/pepper、统一响应、一次性恢复、credential version 和 session 撤销边界正确，未要求自造密码算法；公开 wrapper 只认 starter。真实 PasswordEncoder/节流/通知仍需集成验证。 |
| `ch.security.cookie-session-model` | FAIL（F01） | blocker | host-only、Path/Secure/HttpOnly/SameSite、发送条件、轮换与服务端失效讲解对齐；README 给出完成输出但入口拒绝它。需真实浏览器 Cookie jar 与代理/TLS 路径验证。 |
| `ch.security.origin-cors-csrf` | FAIL（F01） | blocker | origin 三元组、same-site、预检、凭据型 CORS、CSRF 与 signed double-submit 分层明确；练习入口不能 green。需真实浏览器和服务端 Origin/CSRF 集成验证。 |
| `ch.security.untrusted-input-xss-ssrf` | FAIL（F01） | blocker | 输出上下文、CSRF、精确出站 allowlist、逐跳 redirect 与 DNS rebinding 边界完整，且未把最小 encoder 冒充 sanitizer；公开完成态不可达。需真实模板引擎/HTTP client/DNS 策略测试。 |
| `ch.security.spring-security-architecture` | FAIL（F01） | blocker | first-match FilterChain、Authentication/Context、default-deny、401/403 与清理顺序准确，离线模型边界明确；公开 wrapper 不能接受正确实现。需真实 Spring Security filter/context 测试。 |
| `ch.security.session-authentication` | FAIL（F01） | blocker | 登录失败一致性、Session ID 轮换、恢复一次性、credential version、撤销和并发上限有正反 oracle；公开完成态不可达。需真实 session store、并发登录和时钟验证。 |
| `ch.security.jwt-resource-server` | FAIL（F01） | blocker | credential 来源、算法固定、签名、issuer/audience、exp/nbf、token profile 与日志脱敏边界齐全；wrapper 固定红。需真实 JWT 库、JWK rotation 与 clock-skew 测试。 |
| `ch.security.oauth2-oidc` | FAIL（F01） | blocker | state/nonce/redirect/PKCE、Token 去向、refresh token 和 public client secret 边界清楚；wrapper 固定红。需在获批 Provider 上验证 discovery、回调和错误路径。 |
| `ch.security.authorization-rbac-abac` | FAIL（F01） | blocker | RBAC 粗粒度与 tenant/object/冲突 ABAC 组合、unknown default-deny、service/repository 三层均有覆盖，未把 UI 隐藏当授权；公开完成态不可达。需真实方法/数据查询授权矩阵。 |
| `ch.security.multitenancy-data-isolation` | FAIL（F01） | blocker | 可信租户来源、查询/写入/缓存/后台任务/关联/目录 scope 一致，明确前端租户 ID 不可信；公开完成态不可达。需 PostgreSQL policy/query 与跨租户负测。 |
| `ch.security.audit-events-privacy` | FAIL（F01） | blocker | 审计事实、actor/trace 分离、只追加、租户可见性、掩码与字段最小化准确，夹具为合成数据；公开完成态不可达。需真实 retention/access/export 和防篡改设计复核。 |
| `ch.architecture.workflow-state-sla` | FAIL（F01） | blocker | 状态允许边、guard、不变性、固定 Clock、暂停/恢复和 SLA 观察边界清楚，并明确教学终态不等于 FactoryCare canonical 状态机；公开完成态不可达。需真实数据库并发与调度器验证。 |
| `ch.architecture.idempotency-concurrency` | FAIL（F01） | blocker | fingerprint/scope、响应重放、先声明后副作用、乐观版本/影响行数与冲突重试区分正确；公开完成态不可达。需数据库唯一约束、事务与并发压测。 |
| `ch.distributed.redis-cache-rate-limit` | FAIL（F01） | blocker | tenant key、提交后失效、TTL jitter、原子计数、窗口清理和 fail-open/closed 取舍明确；公开完成态不可达。需真实 Redis Lua/cluster/failover 与容量证据。 |
| `ch.architecture.domain-events-outbox` | FAIL（F01） | blocker | 领域事件时序、同事务 outbox、eventId/payload version、claim lease、幂等消费与隔离边界完整，未宣称 exactly-once；公开完成态不可达。需 PostgreSQL 事务与 crash/retry 演练。 |
| `ch.distributed.messaging-delivery` | FAIL（F01） | blocker | publish confirm、提交后 ack、重复消费、有限退避、unroutable 与 DLQ 边界准确；公开完成态不可达。需真实 broker 的 redelivery/crash/ordering 证据。 |
| `ch.architecture.modular-monolith` | FAIL（F01） | blocker | internal 隔离、无环、owner、shared kernel、失败隔离与可拆分证据连贯；公开完成态不可达。需在真实 Spring 模块/ArchUnit 或等价边界工具验证。 |
| `ch.architecture.observability-slo` | AI-clean | none | signal、structured event、trace/metric/log、SLI/SLO/error budget 与高基数/敏感字段边界清楚；example/exercise/lab 对齐且未把固定样本冒充生产观测。仍需真人复核 SLI 语义及真实 telemetry/load/alert 演练。 |

### 4.2 卷 07：Web 平台与 CSS

| 章节 | AI 结果 | 严重度 | 本轮阅读结论与后续门 |
| --- | --- | --- | --- |
| `ch.web.browser-render-devtools` | FAIL（F01、F02） | blocker | 浏览器请求→解析→CSSOM→render/layout/paint/composite 与 Network/DOM/computed 第一证据链清楚；但 public wrapper 不能 green，且从空白写 HTML/CSS/SVG/Python server 缺硬前置。需真实浏览器/HAR/DOM/timeline/screenshot 复核。 |
| `ch.web.origin-cookie-cache` | FAIL（F01） | blocker | origin/site、Cookie 候选、preflight、脚本可读性、服务端授权与 cache reuse 分层正确；公开 wrapper 无完成态。需真实浏览器 Cookie/cache/network 矩阵。 |
| `ch.web.semantic-html` | FAIL（F01、F04） | blocker | 内容职责、landmark、标题、文本语义与“原生优先”讲解连贯，离线 checker 不冒充 AT；统一入口不能 green，README 退出码过时。需 HTML validator、accessibility tree 与读屏任务。 |
| `ch.web.forms-validation` | FAIL（F01、F04） | blocker | label/name/value、constraint validation、multipart、服务端再验证与幂等边界清楚；统一入口不能 green，退出码过时。需真实 ValidityState、Network multipart 和接收端负测。 |
| `ch.web.media-assets` | FAIL（F01、F04） | blocker | picture/srcset、alt、装饰图、MIME/codec、字幕和 transcript 的证据边界完整；统一入口不能 green，退出码过时。需 currentSrc、HTTP/MIME、字幕 UI 与 AT 验证。 |
| `ch.web.accessibility-interaction` | FAIL（F01、F04） | blocker | 键盘、焦点、accessible name、ARIA 状态、DOM 顺序和动态删除后的焦点恢复均有负例；统一入口不能 green，退出码过时。需键盘和屏幕阅读器人工任务。 |
| `ch.css.cascade` | FAIL（F01、F04） | blocker | origin/importance/layer/specificity/source order、inheritance 与低权重策略清楚；wrapper 的 green 分支不可达，README 退出码过时。需真实 computed style/禁用规则对照。 |
| `ch.css.box-position` | FAIL（F01、F04） | blocker | box sizing、containing block、absolute、stacking context、overflow/clip 可手算且有故障矩阵；统一入口不能 green，退出码过时。需 DevTools box model/DOMRect/滚动与截图差分。 |
| `ch.css.flexbox` | FAIL（F01、F04） | blocker | 主/交叉轴、basis/grow/shrink、`min-width: 0`、wrap/gap 与 DOM/视觉/Tab 顺序一致性讲解准确；统一入口不能 green，退出码过时。需 Flex overlay/Tab/视觉差分。 |
| `ch.css.grid` | FAIL（F01、F04） | blocker | explicit/implicit track、line/area、`minmax(0,1fr)` 与 sparse placement 边界清楚；统一入口不能 green，退出码过时。需 Grid overlay/track/DOM-Tab 验证。 |
| `ch.css.responsive-typography` | AI-clean | none | viewport/container、fluid typography、line length、zoom/reflow、overflow 与 image/font loading 的边界连贯；同章端点能观察正例和失效形状。仍需 200%/400% zoom、窄视口、字体加载及多浏览器人工验收。 |
| `ch.css.theme-variables` | FAIL（F01、F04） | blocker | custom property 继承/fallback、token scope、暗色/显式主题、forced-colors 与对比度边界合理；public wrapper 固定红且文档仍写 1。需真实 forced-colors/contrast/读屏验证。 |
| `ch.css.motion-compositing` | FAIL（F01、F04） | blocker | transform/opacity、layout/paint/composite、`will-change` 生命周期、可中断动效和 `prefers-reduced-motion` 讲解准确；public wrapper 固定红且退出码过时。需真实性能 timeline、键盘与 reduced-motion 验收。 |

### 4.3 卷 08：JavaScript 与 TypeScript

| 章节 | AI 结果 | 严重度 | 本轮阅读结论与后续门 |
| --- | --- | --- | --- |
| `ch.js.runtime-esm` | AI-clean | none | 浏览器/Node host、script/module、scope、import/export、URL 与运行命令边界明确；离线 Node 证据未冒充浏览器模块/CORS。需 Node 24 LTS 与真实浏览器 module 复核。 |
| `ch.js.statements-variables` | AI-clean | none | statement/expression、`const`/`let`、声明初始化赋值、block、ASI 与输入输出从零展开，练习边界可观察。需当前 Node 版本复跑。 |
| `ch.js.values-operators` | AI-clean | none | primitive/reference、truthy/nullish、严格相等、转换、Number/BigInt 与金额边界清楚，避免把 `||` 当通用默认。需真实 JSON/API 边界复核。 |
| `ch.js.control-flow` | AI-clean | none | if/switch/loop/guard、短路、副作用、边界顺序与故障诊断连续，任务不依赖后章隐藏概念。 |
| `ch.js.functions` | AI-clean | none | declaration/expression/arrow、parameter/return、pure/side effect、callback 与错误边界按梯度展开。需真人确认零基础读者不会把 callback 等同异步。 |
| `ch.js.scope-closures` | AI-clean | none | lexical environment、closure、factory、共享状态与生命周期/泄漏边界准确，未把“函数调用函数”误称为泄漏。需 DevTools heap 观察作为真人门。 |
| `ch.js.collections` | AI-clean | none | Array/Map/Set、mutation/copy、iteration、sort/comparator 与集合转换边界完整，示例保持稳定顺序。 |
| `ch.js.object-model` | AI-clean | none | object/property、prototype、class syntax、`this`、descriptor 与 composition 的简化模型标注充分。需真人复核 prototype 图示理解。 |
| `ch.js.testing-debugging` | AI-clean | none | oracle/assertion、unit/integration、AAA、debugger/stack、mock 边界与 expected-red 循环对齐，未把 build success 当功能正确。需真实 DevTools 调试任务。 |
| `ch.js.dom-mutation` | AI-clean | none | DOM tree/query/create/update/remove、textContent/innerHTML 安全边界和批量 mutation 讲解清楚；需真实 browser layout/accessibility tree 验证。 |
| `ch.js.events-forms` | AI-clean | none | capture/target/bubble、default action、delegation、FormData/validation 与 teardown 边界正确；需真实键盘/IME/提交行为验证。 |
| `ch.js.event-loop` | AI-clean | none | call stack、task/microtask、render opportunity、Promise 与 starvation 的教学模型准确并声明简化；需浏览器/Node 顺序对照。 |
| `ch.js.fetch-cancellation-race` | AI-clean | none | fetch 的 HTTP/transport 区分、AbortController、latest-run identity、旧 finally 破坏 loading 与 unmount 取消边界完整。需真实慢网/超时/stream body 测试。 |
| `ch.js.browser-performance` | AI-clean | none | measurement-first、Core Web Vitals/long task、layout thrash、资源预算与优化风险讲解不越权；固定 fixture 不冒充真实用户。需真实浏览器 profile 与设备矩阵。 |
| `ch.ts.foundations` | AI-clean | none | TS 编译期、类型擦除、tsconfig、inference/annotation、unknown 与 JS 运行时关系准确。需 TypeScript 7 正式工具链 clean install。 |
| `ch.ts.modeling-narrowing` | AI-follow-up（F04） | major | union/discriminant/guard/exhaustiveness 与 runtime shape 检查覆盖 null/array/inherited/missing fields，负向 TS fixture 有价值；README 仍把 public expected-red 写成 1。修正文档后跑 TS 7 正/负矩阵。 |
| `ch.ts.generics-utilities` | AI-follow-up（F04） | major | type parameter、constraint、`keyof`、indexed access、mapped/utility type 的梯度合理，并保留 invalid-key 负测；README public 退出码过时。修正文档后跑 TS 7 精确 diagnostic。 |
| `ch.ts.runtime-boundaries` | AI-clean | none | `unknown`→validation→domain、JSON/HTTP/storage 边界、schema 版本与错误路径清楚，明确类型不验证运行时输入。需真实 API/schema 库集成与恶意输入测试。 |

### 4.4 卷 09：Vue 与 Nuxt

| 章节 | AI 结果 | 严重度 | 本轮阅读结论与后续门 |
| --- | --- | --- | --- |
| `ch.vue.vite-sfc` | AI-clean | none | Vite dev/build、SFC 三块、module graph、env 边界和入口职责清楚；需 Node 24/pnpm 11/Vite 当前线 clean install/build。 |
| `ch.vue.template-directives` | AI-clean | none | template expression、`v-bind`/`v-on`、条件/列表/key、派生值与副作用边界明确；需真实 DOM/编译警告复核。 |
| `ch.vue.forms-vmodel` | AI-clean | none | `v-model` 展开、modifier、checkbox/select、验证与服务端再校验边界正确；需 IME、键盘和提交行为人工验证。 |
| `ch.vue.reactivity` | AI-clean | none | ref/reactive/computed、dependency tracking、identity/destructure 和 mutation 边界连贯；同章故障可观察。需当前 Vue runtime 复跑。 |
| `ch.vue.effects-lifecycle` | AI-clean | none | watch/watchEffect、cleanup、mounted/unmounted、请求取消、latest-run guard 与“mounted 只防销毁后提交”解释准确。需真实组件慢网/销毁竞态验证。 |
| `ch.vue.components-contracts` | AI-clean | none | props/emits/slots、单向数据流、controlled contract 与事件命名边界清楚；需 runtime warning/type check 复核。 |
| `ch.vue.composables-di` | AI-clean | none | composable 责任、effect ownership/cleanup、provide/inject key 与测试替身边界完整；需真实 component scope 验证。 |
| `ch.vue.router-navigation` | AI-clean | none | route location、nested/dynamic route、guard、return URL 与组件复用边界正确，未把前端 guard 当服务端授权。需真实 history/refresh/404 验证。 |
| `ch.vue.pinia-state` | AI-clean | none | store state/getter/action、归属、持久化白名单与服务端状态分离清楚；需 HMR/SSR/persist 边界实测。 |
| `ch.vue.server-state` | FAIL（F01、F04） | blocker | cache/freshness/dedup、竞态、旧 error/finally 与 dispose 后提交的模型准确；public wrapper green 不可达且 README 退出码过时。修复后还需 Vue 组件与真实网络验证。 |
| `ch.vue.auth-permissions` | FAIL（F01、F04） | blocker | bootstrap 未决态、safe return URL、UI 可见性与服务端授权、401/403 区分均正确；public wrapper green 不可达且 README 退出码过时。需真实 IdP/RBAC/API 负测。 |
| `ch.vue.component-testing` | AI-clean | none | unit/component/E2E 分层、mount/interaction/assert、timer/network stub 与不过度测实现细节边界清楚。需真实 browser runner 与 flaky 重复测试。 |
| `ch.vue.accessibility` | AI-clean | none | semantic first、键盘、焦点、route/live region、表单错误和自动化扫描边界完整。仍必须真人键盘、读屏、zoom/contrast 验收。 |
| `ch.vue.performance` | AI-clean | none | 测量、bundle/render/network、virtualization、lazy load 与优化副作用讲解清楚；需 production build、真实 profile 和低端设备数据。 |
| `ch.nuxt.rendering-hydration` | AI-clean | none | SSR/CSR/SSG、server/client boundary、hydration mismatch、data fetching、secret exposure 与 route middleware 边界完整。章节注明按 2026-07-17 的 Nuxt 4.4.8 复核；发行冻结前需按当前 Nuxt 4.x（含其后发布的 minor）重跑 Node/pnpm/browser/SSR 矩阵。 |

### 4.5 卷 10：uni-app 与小程序

| 章节 | AI 结果 | 严重度 | 本轮阅读结论与后续门 |
| --- | --- | --- | --- |
| `ch.miniapp.runtime` | FAIL（F03） | blocker | App/Page、逻辑层/视图层、数据桥、生命周期和宿主 API 的最小模型本身清楚；正式 prerequisites 却不足以支撑所要求的 JavaScript/Promise 独立实现。需修先修图后在真实微信开发者工具验证。 |
| `ch.uniapp.toolchain-pages` | AI-clean | none | HBuilderX/CLI、pages manifest、路由与构建产物边界有版本披露，未把目录存在当编译成功。需锁定 DCloud CLI/compiler 包并做 clean build。 |
| `ch.uniapp.template-components` | AI-clean | none | template/directive/component、props/emits/slot 与平台组件差异边界清楚；需微信/H5/App 目标的真实编译和交互验证。 |
| `ch.uniapp.network-auth-storage` | AI-clean | none | request、认证 bootstrap、Token 不进日志、storage 非安全保险箱、401/403 与取消边界正确，未把客户端存储当授权。需真实后端、代理、过期/撤销和设备存储验证。 |
| `ch.uniapp.platform-conditional` | AI-clean | none | compile-time conditional、runtime capability、adapter 与共享 domain 边界清楚，避免散布平台判断。需多目标 build 和产物差分。 |
| `ch.uniapp.device-capabilities` | AI-clean | none | 扫码/相机/文件、permission denied/limited/cancel、生命周期与资源清理边界完整；需物理设备权限矩阵，模拟器不能替代。 |
| `ch.uniapp.testing-debugging` | AI-clean | none | pure logic/component/platform adapter/E2E 分层、日志脱敏、故障注入和设备证据边界明确。需开发者工具、真机和 CI 重复执行。 |
| `ch.uniapp.packages-performance` | AI-clean | none | package/subpackage、lazy loading、bundle/首屏/内存指标与优化取舍讲解合理；需真实构建报告、分包阈值与低端设备 profile。 |
| `ch.uniapp.offline-idempotency` | AI-clean | none | local queue、stable idempotency key、retry/backoff、conflict/reconciliation 与用户可见状态边界准确；未宣称 exactly-once。需真实持久化、断网/杀进程/恢复和后端幂等测试。 |
| `ch.uniapp.privacy-review` | AI-clean | none | 最小权限、just-in-time purpose、拒绝路径、数据清单/retention/删除与平台申报区分清楚；需真人隐私/法务和商店表单复核。 |
| `ch.uniapp.release-monitoring` | AI-clean | none | build/channel/version/rollback、source map/脱敏、crash/metric 与灰度边界完整，未把本地 mock 当发布证据。需真实签名、审核、灰度、回滚和监控演练。 |
| `ch.uniapp.factorycare-reporter` | AI-follow-up（F04） | major | 扫码、附件 readiness、提交意图、stable idempotency、服务端状态映射和 release buildId 组合边界正确，明确 Java 后端拥有工单事实；正文仍写 public starter 退出 1，而 wrapper 对外为 41。修正文档后仍需真机+后端+发布 E2E。 |

## 5. 本轮没有发现、但不得外推的事项

- 未发现正文鼓励硬编码真实 Token、密码、账号或个人信息；夹具使用合成标识符。这个结论不等于完成秘密扫描或隐私合规审计。
- 未发现把前端按钮/路由可见性当成最终授权；安全、Vue、uni-app 章节反复要求服务端 default-deny。这个结论不等于真实 API 已执行越权负测。
- 未发现把离线纯 JDK/Ruby/Node 模型冒充 Spring、PostgreSQL、Redis、broker、浏览器或设备实机证据；各章大多主动披露模型边界。披露正确不等于真实 build outcome 已完成。
- 未发现把 mounted/unmounted 当作网络自动取消；JavaScript、Vue 和移动章节区分“停止 UI 提交”“请求取消”“底层资源真正释放”。仍需真实慢网和 teardown 测试。
- 未发现卷 08—10 的 FactoryCare 示例让 Python/前端/小程序成为工单 canonical 事实所有者；正式状态、授权和幂等结果仍归 Java 服务端。仍需跨端合同人工复核。

## 6. 必须由真人或真实环境关闭的门

1. **独立真人内容复核**：由未参与作者生产的 actor 逐章核对定义、来源蕴含、版本结论、FactoryCare 事实边界和发现修复，不得复用本 AI 记录签字。
2. **真实零基础试读**：至少一名符合 rubric 定义的零基础读者完成固定任务，记录用时、卡点、误解、额外提示和修订后复测；重点验证 F02/F03 的先修修复。
3. **练习三态复现**：在新的临时副本逐章执行 starter=41、solved=0、partial/unknown=43；必须由不同 actor 检查未删除负向断言。F01 修复前不能关闭代码/教学门。
4. **企业后端实机**：Temurin 25、Spring Security、PostgreSQL 18、Redis 和所选消息代理的真实集成；执行事务/crash/retry/redelivery、并发、幂等、租户越权、JWT/session 撤销、容量和故障恢复。
5. **Web/无障碍矩阵**：Chrome、Firefox、Safari 中执行 Network/DOM/computed/layout/performance；人工键盘、焦点、200%/400% zoom、对比度、reduced motion、至少一种屏幕阅读器任务。静态 Ruby oracle 不能关闭此门。
6. **JS/TS/Vue/Nuxt 工具链**：锁定 Node 24 LTS、pnpm 11、TypeScript 7、Vite/Vue/Nuxt 当前批准版本，从空缓存 clean install/build/test/SSR/hydration；版本冻结日后重新对照官方 release notes。
7. **uni-app/小程序平台矩阵**：锁定 DCloud CLI/compiler、微信开发者工具与基础库；至少覆盖微信小程序、H5 和批准的 App 目标，执行真机权限、扫码/相机、断网/杀进程恢复、隐私申报、签名、审核、灰度、监控和回滚。
8. **出版与导航**：构建正式 HTML/EPUB/PDF，检查代码块、表格、分页、outline、链接、字体、替代文字、阅读顺序和辅助技术互操作；本轮 344 个相对链接的静态检查不能替代成品验收。
9. **字节绑定 attestation**：修复后重算正式 manifest，由授权真人把结论绑定到精确章节/端点摘要；本记录不能被复制为 attestation。

## 7. 建议修复顺序与复审完成条件

1. 先修 F01：统一 32 个 public wrapper 的三态合同，并为 starter/solved/partial 保存独立执行证据。
2. 同批修 F04：清除 15 处退出码漂移，明确 public wrapper 与 inner oracle 的差别。
3. 修 F02、F03：选择“补硬前置”或“把独立从空白实现改为给定 fixture 观察”，同步 chapters、capabilities 和 concept graph；这是路线/图谱变更，实施前应按项目决策流程确认方案。
4. 重新运行范围内公开端点和静态链接检查，确认没有把已登记 expected-red、负向 fixture 或真实环境 `UNVERIFIED` 消音。
5. 完成第 6 节的真人/真实环境门，并由不同 actor 逐章给出正式 `PASS`、`PASS_WITH_FOLLOW_UP` 或 `FAIL`。

本范围只有在以下条件同时满足时，才可认为 P9 对卷 06—10 的质量闭环完成：F01—F04 均关闭；77 章各自有独立真人内容结论；零基础试读与修订复测有记录；目标运行时/浏览器/设备和 HTML/EPUB/PDF 证据存在；最终 attestation 与修复后精确字节绑定。任何一项缺失都应保持 `dod_human_gate=OPEN`。

## 8. 明确非目标与兼容性说明

- 本轮没有修改任何缺陷，只记录发现；因此没有实现层面的向后兼容折中。
- 没有把旧 exit 1 行为保留为推荐兼容路径。长期可维护目标是一个公开三态合同；若必须临时兼容 inner oracle 的 exit 1，应只作为显式内部细节，不得继续写成 public 合同。
- 没有扩大到卷 00—05 或卷 11—12；它们由各自 P9 AI 预审记录覆盖。
- 没有执行发布、提交、推送、attestation、进度更新或章节状态晋升。
- 没有声称真实平台“预计兼容”；所有未执行组合均保持未验证。
