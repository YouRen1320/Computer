# P1R 2026.1 → 2026.2 迁移账本独立审计

> 审计日期：2026-07-16
>
> 结论：**PASS（设计映射预言）**。170 个旧章节 ID 与 255 个当前章节 ID 构成完整、无孤儿、无越界的迁移图。

## 1. 范围与证据

本审计刻意不读取迁移 ledger 的条目作为映射事实，以避免“用账本证明账本”的循环验证。映射事实只来自以下三类输入：

- 旧目录：`curriculum/catalog.yml`，170 个 2026.1 旧 ID。
- 设计映射：`records/encyclopedia/reviews/P1R-volumes-00-06-design.md` 的“76 个旧 ID 的迁移账本”，以及 `records/encyclopedia/reviews/P1R-volumes-07-15-design.md` 的“旧 ID 迁移映射”。
- 当前规格：`curriculum/chapters/volume-00.yml` 至 `curriculum/chapters/volume-15.yml`，合计 255 个 2026.2 活跃 ID。

显式的“迁到 / 并入 / 留在”跨章说明均被记录为边；没有根据名称相似度、共同单词或模糊匹配补边。

## 2. 审计结果

| 检查项 | 结果 |
|---|---:|
| 旧 ID 总数 | 170 |
| 已建立出边的旧 ID | 170 |
| 缺失旧 ID / 未知旧 ID | 0 / 0 |
| 当前活跃 ID 总数 | 255 |
| 被旧内容覆盖的活跃 ID | 248 |
| 零来源新增 ID | 7 |
| 未知目标 ID | 0 |
| 精确迁移边 | 275 |
| 连通分量 | 151 |
| preserve / split / merge / repartition / new | 84 / 43 / 0 / 17 / 7 |

这里的“每个 ID 恰好一次”指：下方分量表的“旧顶点集”对 170 个旧 ID 形成严格分区，“新顶点集”对 255 个当前 ID 形成严格分区；没有重复顶点，也没有遗漏顶点。一个新 ID 可以有多个旧来源，一个旧 ID 也可以拆到多个新 ID，因此不能把“恰好一次”误解为每个顶点只能有一条边。

## 3. 分类定义

| 类型 | 图结构 | 本次数量 |
|---|---|---:|
| preserve | 1 个旧顶点 → 1 个新顶点 | 84 |
| split | 1 个旧顶点 → 多个新顶点 | 43 |
| merge | 多个旧顶点 → 1 个新顶点 | 0 |
| repartition | 多个旧顶点与多个新顶点在同一连通分量中重新分配 | 17 |
| new | 0 个旧顶点 → 1 个新顶点 | 7 |

## 4. 七个零来源新增章节

| # | 新 ID | 设计依据 |
|---:|---|---|
| 1 | `ch.foundations.api-contract-basics` | 卷 00–06 设计明确新增 |
| 2 | `ch.foundations.testing-oracles` | 卷 00–06 设计明确新增 |
| 3 | `ch.vue.template-directives` | 卷 07–15 设计明确新增缺口 |
| 4 | `ch.dart.testing-lints` | 卷 07–15 设计明确新增缺口 |
| 5 | `ch.math.algebra-units` | 卷 07–15 设计新增数学桥 |
| 6 | `ch.math.functions-graphs` | 卷 07–15 设计新增数学桥 |
| 7 | `ch.ml.attention-sequences` | 卷 07–15 设计新增 LLM 桥 |

特别说明：设计文档把 `ch.web.origin-cookie-cache` 称为“新增缺口”，但同一映射段又明确把 `v08.c06.dom-events-storage` 的浏览器存储模型并入该章。因此从迁移图的来源语义看，它不是第八个零来源新增章，而属于 split 分量。

## 5. 裸词 runtime 假阳性排除

本审计使用完整 ID 与设计中的显式箭头，未按 `runtime` 裸词检索或扩散。以下四组只保留各自领域的明确映射：

- `v08.c01.runtime-node-pnpm-esm` → `ch.js.runtime-esm`。
- `v10.c01.miniprogram-runtime` → `ch.miniapp.runtime`。
- `v11.c06.flutter-runtime` → `ch.flutter.toolchain-project`、`ch.flutter.widget-tree`。
- `v12.c01.runtime-uv-env` → `ch.python.runtime-uv`。

不存在 JavaScript runtime、miniapp runtime、Flutter runtime、Python runtime 之间因共享单词而产生的边。

## 6. 精确双向覆盖表

读法：每个分量内，旧顶点按 O1、O2……编号，新顶点按 N1、N2……编号；“精确边”用局部编号表达。这样每个完整旧 ID 和新 ID 在顶点列中只出现一次，同时仍保留全部 275 条边的精确拓扑。

| 分量 | 类型 | 旧顶点集（2026.1） | 新顶点集（2026.2） | 精确边 |
|---:|---|---|---|---|
| C001 | preserve | O1 `v00.c01.learning-evidence` | N1 `ch.foundations.learning-evidence` | O1→N1 |
| C002 | preserve | O1 `v00.c02.computer-model` | N1 `ch.foundations.computer-process-model` | O1→N1 |
| C003 | preserve | O1 `v00.c03.files-paths-encoding` | N1 `ch.foundations.files-paths-encoding` | O1→N1 |
| C004 | preserve | O1 `v00.c04.terminal-shell` | N1 `ch.foundations.terminal-shell` | O1→N1 |
| C005 | preserve | O1 `v00.c05.pipes-exit-codes` | N1 `ch.foundations.cli-streams-exit-codes` | O1→N1 |
| C006 | preserve | O1 `v00.c06.environment-path` | N1 `ch.foundations.environment-tool-resolution` | O1→N1 |
| C007 | repartition | O1 `v00.c07.editor-ide-debugger`<br>O2 `v01.c10.arrays-debug-test`<br>O3 `v01.c08.loops-control`<br>O4 `v03.c10.maven-testing-jvm`<br>O5 `v03.c12.java-testing-mocking` | N1 `ch.foundations.editor-project-navigation`<br>N2 `ch.java.debugging-failures`<br>N3 `ch.java.arrays-command-args`<br>N4 `ch.java.maven-junit-smoke`<br>N5 `ch.java.loops`<br>N6 `ch.java-engineering.maven-reproducible-builds`<br>N7 `ch.java-engineering.testing-test-doubles` | O1→N1,N2<br>O2→N3,N4,N2<br>O3→N5,N3<br>O4→N6,N4<br>O5→N7,N4 |
| C008 | preserve | O1 `v00.c08.git-security` | N1 `ch.foundations.git-collaboration-security` | O1→N1 |
| C009 | split | O1 `v00.c09.network-http-curl` | N1 `ch.foundations.network-layers`<br>N2 `ch.foundations.http-curl` | O1→N1,N2 |
| C010 | preserve | O1 `v00.c10.dependencies-build-ai` | N1 `ch.foundations.dependencies-build-packages` | O1→N1 |
| C011 | preserve | O1 `v00.c11.docker-foundations` | N1 `ch.foundations.docker-basics` | O1→N1 |
| C012 | preserve | O1 `v00.c12.ai-collaboration-verification` | N1 `ch.foundations.ai-assisted-verification` | O1→N1 |
| C013 | preserve | O1 `v01.c01.java-platform` | N1 `ch.java.platform-toolchain` | O1→N1 |
| C014 | repartition | O1 `v01.c02.program-structure`<br>O2 `v02.c03.constructors-encapsulation` | N1 `ch.java.program-structure`<br>N2 `ch.java-oop.encapsulation-packages`<br>N3 `ch.java-oop.constructors-invariants` | O1→N1,N2<br>O2→N3,N2 |
| C015 | repartition | O1 `v01.c03.console-io`<br>O2 `v01.c04.variables-scope`<br>O3 `v01.c05.primitive-types`<br>O4 `v02.c09.core-value-types` | N1 `ch.java.console-input-validation`<br>N2 `ch.java.values-variables-types`<br>N3 `ch.java-oop.business-value-types` | O1→N1,N2<br>O2→N2<br>O3→N2<br>O4→N3,N2 |
| C016 | preserve | O1 `v01.c06.operators-conversion` | N1 `ch.java.expressions-conversions` | O1→N1 |
| C017 | preserve | O1 `v01.c07.conditionals-switch` | N1 `ch.java.branching` | O1→N1 |
| C018 | preserve | O1 `v01.c09.methods` | N1 `ch.java.methods` | O1→N1 |
| C019 | preserve | O1 `v02.c01.references-null-memory` | N1 `ch.java-oop.references-null-identity` | O1→N1 |
| C020 | preserve | O1 `v02.c02.classes-fields-methods` | N1 `ch.java-oop.classes-objects` | O1→N1 |
| C021 | repartition | O1 `v02.c04.static-final-immutability`<br>O2 `v03.c01.collections`<br>O3 `v02.c08.object-contract` | N1 `ch.java-oop.static-class-state`<br>N2 `ch.java-oop.final-immutability`<br>N3 `ch.java-engineering.sequential-collections`<br>N4 `ch.java-engineering.associative-collections`<br>N5 `ch.java-oop.object-contracts` | O1→N1,N2,N3<br>O2→N3,N4<br>O3→N5,N4 |
| C022 | preserve | O1 `v02.c05.inheritance-composition` | N1 `ch.java-oop.inheritance-composition` | O1→N1 |
| C023 | preserve | O1 `v02.c06.polymorphism-interfaces` | N1 `ch.java-oop.interfaces-polymorphism` | O1→N1 |
| C024 | preserve | O1 `v02.c07.enum-record-sealed` | N1 `ch.java-oop.enum-record-sealed` | O1→N1 |
| C025 | repartition | O1 `v02.c10.exceptions-resources`<br>O2 `v03.c06.io-nio-json` | N1 `ch.java-oop.exceptions-failure-contracts`<br>N2 `ch.java-engineering.io-resource-lifecycle`<br>N3 `ch.java-engineering.nio-files-charsets`<br>N4 `ch.java-engineering.json-mapping` | O1→N1,N2<br>O2→N2,N3,N4 |
| C026 | split | O1 `v03.c02.generics-comparator` | N1 `ch.java-engineering.generics-type-safety`<br>N2 `ch.java-engineering.sorting-comparators` | O1→N1,N2 |
| C027 | preserve | O1 `v03.c03.complexity-data-structures` | N1 `ch.java-engineering.complexity-algorithms` | O1→N1 |
| C028 | preserve | O1 `v03.c04.lambdas-functions` | N1 `ch.java-engineering.lambdas-functional-interfaces` | O1→N1 |
| C029 | preserve | O1 `v03.c05.streams-optional` | N1 `ch.java-engineering.functional-pipelines` | O1→N1 |
| C030 | preserve | O1 `v03.c07.threads-jmm` | N1 `ch.java-engineering.threads-jmm` | O1→N1 |
| C031 | preserve | O1 `v03.c08.executors-virtual-threads` | N1 `ch.java-engineering.executors-virtual-threads` | O1→N1 |
| C032 | split | O1 `v03.c09.annotations-reflection-proxy` | N1 `ch.java-engineering.annotations-metadata`<br>N2 `ch.java-engineering.reflection-classloading-proxies` | O1→N1,N2 |
| C033 | preserve | O1 `v03.c11.java-networking` | N1 `ch.java-engineering.network-programming` | O1→N1 |
| C034 | preserve | O1 `v03.c13.logging-jvm-diagnostics` | N1 `ch.java-engineering.logging-jvm-diagnostics` | O1→N1 |
| C035 | repartition | O1 `v04.c01.relational-model`<br>O2 `v04.c07.postgres-types-psql`<br>O3 `v04.c06.dml-ddl-normalization` | N1 `ch.data.relational-model`<br>N2 `ch.data.postgresql-psql`<br>N3 `ch.data.ddl-constraints`<br>N4 `ch.data.postgresql-types`<br>N5 `ch.data.dml`<br>N6 `ch.data.normalization-modeling` | O1→N1,N2,N3<br>O2→N4,N2<br>O3→N5,N3,N6 |
| C036 | preserve | O1 `v04.c02.sql-query-basics` | N1 `ch.data.select-rowsets` | O1→N1 |
| C037 | preserve | O1 `v04.c03.sql-functions` | N1 `ch.data.scalar-functions` | O1→N1 |
| C038 | preserve | O1 `v04.c04.aggregate-group-having` | N1 `ch.data.aggregates` | O1→N1 |
| C039 | split | O1 `v04.c05.joins-subquery-cte` | N1 `ch.data.joins`<br>N2 `ch.data.subqueries-cte`<br>N3 `ch.data.window-functions` | O1→N1,N2,N3 |
| C040 | preserve | O1 `v04.c08.indexes-explain` | N1 `ch.data.indexes-explain` | O1→N1 |
| C041 | preserve | O1 `v04.c09.transactions-locks` | N1 `ch.data.transactions-locking` | O1→N1 |
| C042 | preserve | O1 `v04.c10.migration-jdbc-mybatis` | N1 `ch.data.schema-migrations` | O1→N1 |
| C043 | split | O1 `v04.c11.jdbc-pool-mybatis` | N1 `ch.data.jdbc`<br>N2 `ch.data.mybatis-core` | O1→N1,N2 |
| C044 | preserve | O1 `v05.c01.web-jakarta-lifecycle` | N1 `ch.spring.servlet-request-lifecycle` | O1→N1 |
| C045 | split | O1 `v05.c02.ioc-di-beans` | N1 `ch.spring.ioc-di`<br>N2 `ch.spring.beans-lifecycle-scopes` | O1→N1,N2 |
| C046 | preserve | O1 `v05.c03.configuration-profiles` | N1 `ch.spring.configuration-profiles` | O1→N1 |
| C047 | preserve | O1 `v05.c04.boot-autoconfiguration` | N1 `ch.spring.boot-autoconfiguration` | O1→N1 |
| C048 | repartition | O1 `v05.c05.mvc-controllers`<br>O2 `v05.c07.validation-errors-files` | N1 `ch.spring.mvc-routing-binding`<br>N2 `ch.spring.validation`<br>N3 `ch.spring.problem-details-errors` | O1→N1<br>O2→N2,N3,N1 |
| C049 | preserve | O1 `v05.c06.dto-serialization` | N1 `ch.spring.dto-json-content-negotiation` | O1→N1 |
| C050 | split | O1 `v05.c08.services-transactions-aop` | N1 `ch.spring.service-use-cases`<br>N2 `ch.spring.aop-proxy-model`<br>N3 `ch.spring.transactions` | O1→N1,N2,N3 |
| C051 | split | O1 `v05.c09.mybatis-integration` | N1 `ch.spring.datasource-pooling`<br>N2 `ch.spring.mybatis-repositories` | O1→N1,N2 |
| C052 | split | O1 `v05.c10.testing-openapi-actuator` | N1 `ch.spring.testing-testcontainers`<br>N2 `ch.spring.openapi-contracts`<br>N3 `ch.spring.actuator-health-metrics` | O1→N1,N2,N3 |
| C053 | repartition | O1 `v06.c01.auth-session-password`<br>O2 `v06.c04.spring-security`<br>O3 `v06.c05.rbac-multitenancy-audit` | N1 `ch.security.identity-password-lifecycle`<br>N2 `ch.security.cookie-session-model`<br>N3 `ch.security.session-authentication`<br>N4 `ch.security.spring-security-architecture`<br>N5 `ch.security.authorization-rbac-abac`<br>N6 `ch.security.multitenancy-data-isolation`<br>N7 `ch.security.audit-events-privacy` | O1→N1,N2,N3<br>O2→N4,N3,N5<br>O3→N5,N6,N7 |
| C054 | split | O1 `v06.c02.web-security-threats` | N1 `ch.security.threat-model-trust-boundaries`<br>N2 `ch.security.origin-cors-csrf`<br>N3 `ch.security.untrusted-input-xss-ssrf` | O1→N1,N2,N3 |
| C055 | split | O1 `v06.c03.jwt-oauth-oidc` | N1 `ch.security.jwt-resource-server`<br>N2 `ch.security.oauth2-oidc` | O1→N1,N2 |
| C056 | preserve | O1 `v06.c06.domain-modeling` | N1 `ch.architecture.domain-modeling` | O1→N1 |
| C057 | repartition | O1 `v06.c07.state-sla-idempotency`<br>O2 `v06.c10.modular-monolith-observability` | N1 `ch.architecture.workflow-state-sla`<br>N2 `ch.architecture.idempotency-concurrency`<br>N3 `ch.architecture.observability-slo`<br>N4 `ch.architecture.modular-monolith` | O1→N1,N2,N3<br>O2→N4,N3 |
| C058 | preserve | O1 `v06.c08.redis-cache-rate-limit` | N1 `ch.distributed.redis-cache-rate-limit` | O1→N1 |
| C059 | split | O1 `v06.c09.events-outbox-messaging` | N1 `ch.architecture.domain-events-outbox`<br>N2 `ch.distributed.messaging-delivery` | O1→N1,N2 |
| C060 | repartition | O1 `v07.c01.browser-render-devtools`<br>O2 `v07.c10.motion-performance` | N1 `ch.web.browser-render-devtools`<br>N2 `ch.js.browser-performance`<br>N3 `ch.css.motion-compositing` | O1→N1,N2<br>O2→N3,N2 |
| C061 | preserve | O1 `v07.c02.semantic-html` | N1 `ch.web.semantic-html` | O1→N1 |
| C062 | split | O1 `v07.c03.forms-media-validation` | N1 `ch.web.forms-validation`<br>N2 `ch.web.media-assets` | O1→N1,N2 |
| C063 | preserve | O1 `v07.c04.accessibility` | N1 `ch.web.accessibility-interaction` | O1→N1 |
| C064 | preserve | O1 `v07.c05.css-cascade` | N1 `ch.css.cascade` | O1→N1 |
| C065 | preserve | O1 `v07.c06.box-position-stacking` | N1 `ch.css.box-position` | O1→N1 |
| C066 | split | O1 `v07.c07.flex-grid` | N1 `ch.css.flexbox`<br>N2 `ch.css.grid` | O1→N1,N2 |
| C067 | preserve | O1 `v07.c08.responsive-typography` | N1 `ch.css.responsive-typography` | O1→N1 |
| C068 | preserve | O1 `v07.c09.color-theme-variables` | N1 `ch.css.theme-variables` | O1→N1 |
| C069 | repartition | O1 `v08.c01.runtime-node-pnpm-esm`<br>O2 `v08.c05.this-prototype-class-module` | N1 `ch.js.runtime-esm`<br>N2 `ch.js.object-model` | O1→N1<br>O2→N2,N1 |
| C070 | repartition | O1 `v08.c02.values-types-equality`<br>O2 `v08.c10.typescript-advanced-tooling` | N1 `ch.js.statements-variables`<br>N2 `ch.js.values-operators`<br>N3 `ch.js.testing-debugging`<br>N4 `ch.ts.generics-utilities`<br>N5 `ch.ts.runtime-boundaries` | O1→N1,N2,N3<br>O2→N4,N5,N3 |
| C071 | split | O1 `v08.c03.scope-functions-closures` | N1 `ch.js.control-flow`<br>N2 `ch.js.functions`<br>N3 `ch.js.scope-closures` | O1→N1,N2,N3 |
| C072 | preserve | O1 `v08.c04.arrays-objects-collections` | N1 `ch.js.collections` | O1→N1 |
| C073 | split | O1 `v08.c06.dom-events-storage` | N1 `ch.js.dom-mutation`<br>N2 `ch.js.events-forms`<br>N3 `ch.web.origin-cookie-cache` | O1→N1,N2,N3 |
| C074 | preserve | O1 `v08.c07.event-loop-promises` | N1 `ch.js.event-loop` | O1→N1 |
| C075 | preserve | O1 `v08.c08.fetch-abort-race` | N1 `ch.js.fetch-cancellation-race` | O1→N1 |
| C076 | split | O1 `v08.c09.typescript-setup-strict` | N1 `ch.ts.foundations`<br>N2 `ch.ts.modeling-narrowing` | O1→N1,N2 |
| C077 | preserve | O1 `v09.c01.vite-sfc-app` | N1 `ch.vue.vite-sfc` | O1→N1 |
| C078 | preserve | O1 `v09.c02.reactivity` | N1 `ch.vue.reactivity` | O1→N1 |
| C079 | preserve | O1 `v09.c03.watch-lifecycle-cleanup` | N1 `ch.vue.effects-lifecycle` | O1→N1 |
| C080 | preserve | O1 `v09.c04.components-contracts` | N1 `ch.vue.components-contracts` | O1→N1 |
| C081 | preserve | O1 `v09.c05.composables-boundaries` | N1 `ch.vue.composables-di` | O1→N1 |
| C082 | split | O1 `v09.c06.router-navigation-auth` | N1 `ch.vue.router-navigation`<br>N2 `ch.vue.auth-permissions` | O1→N1,N2 |
| C083 | repartition | O1 `v09.c07.pinia-server-state-forms`<br>O2 `v09.c08.requests-race-errors` | N1 `ch.vue.forms-vmodel`<br>N2 `ch.vue.pinia-state`<br>N3 `ch.vue.server-state` | O1→N1,N2,N3<br>O2→N3 |
| C084 | split | O1 `v09.c09.testing-a11y-performance` | N1 `ch.vue.component-testing`<br>N2 `ch.vue.accessibility`<br>N3 `ch.vue.performance` | O1→N1,N2,N3 |
| C085 | repartition | O1 `v09.c10.nuxt-rendering-deployment`<br>O2 `v15.c09.deployment-rollback-incident` | N1 `ch.nuxt.rendering-hydration`<br>N2 `ch.release.deployment-migrations`<br>N3 `ch.ops.incident-dr` | O1→N1,N2<br>O2→N2,N3 |
| C086 | preserve | O1 `v10.c01.miniprogram-runtime` | N1 `ch.miniapp.runtime` | O1→N1 |
| C087 | split | O1 `v10.c02.uniapp-vue-pages` | N1 `ch.uniapp.toolchain-pages`<br>N2 `ch.uniapp.template-components` | O1→N1,N2 |
| C088 | preserve | O1 `v10.c03.network-auth-storage` | N1 `ch.uniapp.network-auth-storage` | O1→N1 |
| C089 | preserve | O1 `v10.c04.platform-api-conditional` | N1 `ch.uniapp.platform-conditional` | O1→N1 |
| C090 | preserve | O1 `v10.c05.upload-scan-location` | N1 `ch.uniapp.device-capabilities` | O1→N1 |
| C091 | split | O1 `v10.c06.packages-performance-offline` | N1 `ch.uniapp.packages-performance`<br>N2 `ch.uniapp.offline-idempotency` | O1→N1,N2 |
| C092 | preserve | O1 `v10.c07.testing-device-debug` | N1 `ch.uniapp.testing-debugging` | O1→N1 |
| C093 | preserve | O1 `v10.c08.privacy-security-review` | N1 `ch.uniapp.privacy-review` | O1→N1 |
| C094 | preserve | O1 `v10.c09.publish-monitoring` | N1 `ch.uniapp.release-monitoring` | O1→N1 |
| C095 | preserve | O1 `v10.c10.factorycare-reporter` | N1 `ch.uniapp.factorycare-reporter` | O1→N1 |
| C096 | split | O1 `v11.c01.dart-cli-types` | N1 `ch.dart.toolchain`<br>N2 `ch.dart.types-null-safety` | O1→N1,N2 |
| C097 | repartition | O1 `v11.c02.dart-control-functions`<br>O2 `v11.c03.dart-collections-patterns` | N1 `ch.dart.control-functions`<br>N2 `ch.dart.collections-patterns` | O1→N1,N2<br>O2→N2 |
| C098 | preserve | O1 `v11.c04.dart-oop-generics` | N1 `ch.dart.oop-generics` | O1→N1 |
| C099 | split | O1 `v11.c05.dart-async-errors` | N1 `ch.dart.exceptions-resources`<br>N2 `ch.dart.future-cancellation`<br>N3 `ch.dart.streams-isolates` | O1→N1,N2,N3 |
| C100 | split | O1 `v11.c06.flutter-runtime` | N1 `ch.flutter.toolchain-project`<br>N2 `ch.flutter.widget-tree` | O1→N1,N2 |
| C101 | preserve | O1 `v11.c07.layout-render-accessibility` | N1 `ch.flutter.layout-accessibility` | O1→N1 |
| C102 | preserve | O1 `v11.c08.state-lifecycle-mounted` | N1 `ch.flutter.state-lifecycle` | O1→N1 |
| C103 | repartition | O1 `v11.c09.navigation-network-device`<br>O2 `v11.c11.flutter-network-storage`<br>O3 `v11.c12.flutter-device-apis` | N1 `ch.flutter.navigation-forms`<br>N2 `ch.flutter.network-storage-offline`<br>N3 `ch.flutter.device-apis` | O1→N1,N2,N3<br>O2→N2<br>O3→N3 |
| C104 | repartition | O1 `v11.c10.architecture-testing-release`<br>O2 `v11.c13.flutter-testing-performance-release` | N1 `ch.flutter.architecture-state`<br>N2 `ch.flutter.testing-performance`<br>N3 `ch.flutter.release-monitoring` | O1→N1,N2,N3<br>O2→N2,N3 |
| C105 | preserve | O1 `v12.c01.runtime-uv-env` | N1 `ch.python.runtime-uv` | O1→N1 |
| C106 | split | O1 `v12.c02.types-io-control` | N1 `ch.python.syntax-values-io`<br>N2 `ch.python.control-flow` | O1→N1,N2 |
| C107 | split | O1 `v12.c03.functions-collections` | N1 `ch.python.functions-scope`<br>N2 `ch.python.collections` | O1→N1,N2 |
| C108 | split | O1 `v12.c04.modules-files-json` | N1 `ch.python.modules-packages`<br>N2 `ch.python.files-json-time` | O1→N1,N2 |
| C109 | split | O1 `v12.c05.classes-dataclass-protocol` | N1 `ch.python.classes-dataclass`<br>N2 `ch.python.protocol-generics` | O1→N1,N2 |
| C110 | split | O1 `v12.c06.exceptions-iterators-decorators` | N1 `ch.python.exceptions-context`<br>N2 `ch.python.iterators-decorators` | O1→N1,N2 |
| C111 | split | O1 `v12.c07.typing-testing-logging` | N1 `ch.python.typing-foundations`<br>N2 `ch.python.testing-logging-debug` | O1→N1,N2 |
| C112 | preserve | O1 `v12.c08.async-cancellation` | N1 `ch.python.asyncio-cancellation` | O1→N1 |
| C113 | split | O1 `v12.c09.fastapi-pydantic` | N1 `ch.python.pydantic-validation`<br>N2 `ch.fastapi.web-foundations`<br>N3 `ch.fastapi.security-testing-openapi` | O1→N1,N2,N3 |
| C114 | split | O1 `v12.c10.numpy-pandas` | N1 `ch.data.numpy`<br>N2 `ch.data.pandas` | O1→N1,N2 |
| C115 | preserve | O1 `v13.c01.vectors-matrices-tensors` | N1 `ch.math.linear-algebra` | O1→N1 |
| C116 | preserve | O1 `v13.c02.probability-statistics` | N1 `ch.math.probability-statistics` | O1→N1 |
| C117 | preserve | O1 `v13.c03.derivatives-gradients` | N1 `ch.math.gradients` | O1→N1 |
| C118 | preserve | O1 `v13.c04.problem-data-split` | N1 `ch.ml.problem-data-split` | O1→N1 |
| C119 | split | O1 `v13.c05.classical-ml` | N1 `ch.ml.preprocessing-features`<br>N2 `ch.ml.supervised-learning`<br>N3 `ch.ml.unsupervised-learning` | O1→N1,N2,N3 |
| C120 | preserve | O1 `v13.c06.metrics-validation` | N1 `ch.ml.metrics-validation` | O1→N1 |
| C121 | preserve | O1 `v13.c07.neural-networks` | N1 `ch.ml.neural-networks` | O1→N1 |
| C122 | preserve | O1 `v13.c08.pytorch-foundations` | N1 `ch.pytorch.foundations` | O1→N1 |
| C123 | preserve | O1 `v13.c09.training-evaluation` | N1 `ch.pytorch.training` | O1→N1 |
| C124 | split | O1 `v13.c10.inference-monitoring-ethics` | N1 `ch.pytorch.inference`<br>N2 `ch.ml.monitoring-ethics` | O1→N1,N2 |
| C125 | preserve | O1 `v14.c01.llm-model` | N1 `ch.llm.model-foundations` | O1→N1 |
| C126 | preserve | O1 `v14.c02.model-api-prompts` | N1 `ch.llm.api-prompts-cost` | O1→N1 |
| C127 | split | O1 `v14.c03.structured-stream-retry` | N1 `ch.llm.structured-output`<br>N2 `ch.llm.streaming-resilience` | O1→N1,N2 |
| C128 | preserve | O1 `v14.c04.tool-calling-boundaries` | N1 `ch.llm.tool-calling` | O1→N1 |
| C129 | split | O1 `v14.c05.ingestion-chunking` | N1 `ch.rag.ingestion-metadata`<br>N2 `ch.rag.chunking-embeddings` | O1→N1,N2 |
| C130 | split | O1 `v14.c06.retrieval-rerank` | N1 `ch.ir.lexical-retrieval`<br>N2 `ch.ir.evaluation`<br>N3 `ch.ir.dense-pgvector`<br>N4 `ch.ir.hybrid-rerank` | O1→N1,N2,N3,N4 |
| C131 | preserve | O1 `v14.c07.rag-citations-evaluation` | N1 `ch.rag.citations-evaluation` | O1→N1 |
| C132 | preserve | O1 `v14.c08.rag-security-observability` | N1 `ch.rag.security-observability` | O1→N1 |
| C133 | split | O1 `v14.c09.langchain-langgraph` | N1 `ch.agent.langchain`<br>N2 `ch.agent.langgraph` | O1→N1,N2 |
| C134 | preserve | O1 `v14.c10.mcp-agent-boundary` | N1 `ch.agent.mcp-boundaries` | O1→N1 |
| C135 | preserve | O1 `v15.c01.linux-operations` | N1 `ch.ops.linux-services` | O1→N1 |
| C136 | preserve | O1 `v15.c02.network-diagnostics` | N1 `ch.ops.network-diagnostics` | O1→N1 |
| C137 | split | O1 `v15.c03.docker-compose` | N1 `ch.ops.docker-production`<br>N2 `ch.ops.compose-services` | O1→N1,N2 |
| C138 | preserve | O1 `v15.c04.nginx-tls-proxy` | N1 `ch.ops.nginx-tls` | O1→N1 |
| C139 | split | O1 `v15.c05.ci-quality-artifacts` | N1 `ch.release.ci-quality`<br>N2 `ch.release.artifacts-promotion` | O1→N1,N2 |
| C140 | preserve | O1 `v15.c06.config-secrets-supply-chain` | N1 `ch.ops.config-secrets-supply-chain` | O1→N1 |
| C141 | split | O1 `v15.c07.logs-metrics-traces` | N1 `ch.ops.logs-health`<br>N2 `ch.ops.metrics-traces-slo` | O1→N1,N2 |
| C142 | split | O1 `v15.c08.backup-capacity-performance` | N1 `ch.ops.backup-recovery`<br>N2 `ch.ops.capacity-performance` | O1→N1,N2 |
| C143 | split | O1 `v15.c10.system-design-portfolio` | N1 `ch.architecture.system-design`<br>N2 `ch.release.factorycare-acceptance` | O1→N1,N2 |
| C144 | preserve | O1 `v15.c11.portfolio-interview` | N1 `ch.portfolio.interview` | O1→N1 |
| C145 | new | ∅ | N1 `ch.foundations.api-contract-basics` | ∅→N1 |
| C146 | new | ∅ | N1 `ch.foundations.testing-oracles` | ∅→N1 |
| C147 | new | ∅ | N1 `ch.vue.template-directives` | ∅→N1 |
| C148 | new | ∅ | N1 `ch.dart.testing-lints` | ∅→N1 |
| C149 | new | ∅ | N1 `ch.math.algebra-units` | ∅→N1 |
| C150 | new | ∅ | N1 `ch.math.functions-graphs` | ∅→N1 |
| C151 | new | ∅ | N1 `ch.ml.attention-sequences` | ∅→N1 |

## 7. 可复核的不变量

本报告生成前执行并通过了以下断言：

1. `old_ids - mapped_old_ids == []`，且 `mapped_old_ids - old_ids == []`。
2. 所有边的目标都属于当前 255 个规格 ID。
3. 连通分量旧顶点排序后与 170 个旧 ID 完全一致。
4. 连通分量新顶点排序后与 255 个当前 ID 完全一致。
5. 零来源集合与第 4 节列出的七个 ID 完全相等。
6. 边数为 275，分量数为 151，分类计数为 84 / 43 / 0 / 17 / 7。

## 8. 已验证、未验证与非目标

**已验证：** ID 集合、显式设计边、跨章迁移说明、双向顶点覆盖、连通分量分类、七个零来源新增章，以及 runtime 裸词负例。

**未验证：** 本报告没有把当前 `curriculum/migrations/2026.1-to-2026.2.yml` 的条目作为输入，也不宣称该文件已经与本预言一致；应由独立编译器/校验器拿本报告预言去核对 ledger。

**刻意不做：** 不修改 ledger、sources、PROGRESS、catalog 或 chapter specs；不审查章节正文的教学质量；不创建 alias/redirect；不使用模糊 ID 猜测。

## 9. 兼容性说明

本次是只读审计，没有实现变更，因此没有为向后兼容作出任何妥协，也没有迁移或回滚操作。
