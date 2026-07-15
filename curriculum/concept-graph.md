<!-- GENERATED: factorycare-curriculum; DO NOT EDIT -->
# FactoryCare 课程概念与依赖图

- edition: `2026.2-draft`
- chapters: 255
- capabilities: 94
- spec digest: `c4ab6a6d3852f5df0035931f4368ab3957981daddc02fe9f2212db8bc3e99cca`

## Capability teachers

| Capability | Teacher | Requires |
| --- | --- | --- |
| `foundation.learning-evidence` | `ch.foundations.learning-evidence` |  |
| `foundation.os-process-memory` | `ch.foundations.computer-process-model` | `foundation.files-path-encoding` |
| `foundation.files-path-encoding` | `ch.foundations.files-paths-encoding` |  |
| `foundation.shell-command-stream` | `ch.foundations.cli-streams-exit-codes` | `foundation.files-path-encoding` |
| `foundation.toolchain-env-build` | `ch.foundations.dependencies-build-packages` | `foundation.shell-command-stream`, `foundation.verification-debug-test` |
| `foundation.verification-debug-test` | `ch.foundations.testing-oracles` | `foundation.shell-command-stream` |
| `foundation.git-security` | `ch.foundations.git-collaboration-security` | `foundation.files-path-encoding`, `foundation.shell-command-stream` |
| `foundation.network-transport` | `ch.foundations.network-layers` | `foundation.os-process-memory`, `foundation.shell-command-stream` |
| `foundation.http-message` | `ch.foundations.http-curl` | `foundation.network-transport`, `foundation.shell-command-stream` |
| `foundation.docker-runtime` | `ch.foundations.docker-basics` | `foundation.files-path-encoding`, `foundation.shell-command-stream`, `foundation.network-transport` |
| `java.platform-entry` | `ch.java.platform-toolchain` | `foundation.shell-command-stream`, `foundation.toolchain-env-build` |
| `java.values-types-string` | `ch.java.values-variables-types` | `java.platform-entry` |
| `java.control-flow` | `ch.java.loops` | `java.values-types-string` |
| `java.arrays` | `ch.java.arrays-command-args` | `java.control-flow` |
| `java.methods` | `ch.java.methods` | `java.control-flow`, `java.arrays` |
| `java.references-objects` | `ch.java-oop.references-null-identity` | `java.values-types-string`, `java.methods` |
| `java.encapsulation-immutability` | `ch.java-oop.final-immutability` | `java.references-objects` |
| `java.inheritance-polymorphism` | `ch.java-oop.interfaces-polymorphism` | `java.encapsulation-immutability` |
| `java.exceptions-resources` | `ch.java-engineering.io-resource-lifecycle` | `java.methods`, `java.inheritance-polymorphism`, `foundation.files-path-encoding` |
| `java.collections-generics` | `ch.java-engineering.associative-collections` | `java.arrays`, `java.references-objects`, `java.inheritance-polymorphism` |
| `java.io-json` | `ch.java-engineering.json-mapping` | `java.exceptions-resources`, `foundation.files-path-encoding` |
| `java.concurrency-runtime` | `ch.java-engineering.threads-jmm` | `java.encapsulation-immutability`, `java.exceptions-resources` |
| `java.build-testing` | `ch.java.maven-junit-smoke` | `java.methods`, `foundation.toolchain-env-build`, `foundation.verification-debug-test` |
| `data.relational-schema` | `ch.data.relational-model` |  |
| `data.sql-query` | `ch.data.select-rowsets` | `data.relational-schema` |
| `data.sql-aggregate-join` | `ch.data.joins` | `data.sql-query` |
| `data.transactions-locks` | `ch.data.transactions-locking` | `data.relational-schema`, `data.sql-query` |
| `data.index-plan` | `ch.data.indexes-explain` | `data.relational-schema`, `data.sql-query` |
| `data.persistence-access` | `ch.data.jdbc` | `data.relational-schema`, `data.sql-query`, `data.transactions-locks`, `java.exceptions-resources` |
| `data.schema-migration` | `ch.data.schema-migrations` | `data.relational-schema`, `data.transactions-locks`, `foundation.toolchain-env-build` |
| `backend.servlet-request` | `ch.spring.servlet-request-lifecycle` | `foundation.http-message`, `java.build-testing` |
| `backend.spring-di-config` | `ch.spring.boot-autoconfiguration` | `java.inheritance-polymorphism`, `java.build-testing` |
| `backend.spring-mvc-contract` | `ch.spring.mvc-routing-binding` | `backend.servlet-request`, `backend.spring-di-config`, `foundation.http-message` |
| `backend.spring-persistence-tx` | `ch.spring.transactions` | `backend.spring-di-config`, `data.persistence-access`, `data.transactions-locks` |
| `security.authentication` | `ch.security.session-authentication` | `security.web-threat`, `backend.spring-mvc-contract`, `foundation.http-message`, `foundation.verification-debug-test` |
| `security.web-threat` | `ch.security.untrusted-input-xss-ssrf` | `foundation.http-message`, `backend.spring-mvc-contract` |
| `security.authorization-policy` | `ch.security.authorization-rbac-abac` | `security.authentication`, `security.web-threat`, `backend.spring-persistence-tx` |
| `security.multitenancy-isolation` | `ch.security.multitenancy-data-isolation` | `security.authorization-policy`, `backend.spring-persistence-tx` |
| `architecture.domain-invariants` | `ch.architecture.domain-modeling` | `java.encapsulation-immutability`, `java.inheritance-polymorphism` |
| `architecture.idempotency-consistency` | `ch.architecture.idempotency-concurrency` | `architecture.domain-invariants`, `data.transactions-locks` |
| `architecture.events-outbox` | `ch.distributed.messaging-delivery` | `architecture.idempotency-consistency`, `backend.spring-persistence-tx`, `foundation.network-transport` |
| `architecture.observability` | `ch.architecture.observability-slo` | `backend.spring-mvc-contract`, `foundation.verification-debug-test` |
| `web.browser-rendering` | `ch.web.browser-render-devtools` | `foundation.http-message` |
| `web.browser-origin-state` | `ch.web.origin-cookie-cache` | `web.browser-rendering`, `foundation.http-message` |
| `web.html-semantic-form` | `ch.web.forms-validation` | `web.browser-rendering` |
| `web.accessibility` | `ch.web.accessibility-interaction` | `web.html-semantic-form` |
| `web.css-foundations` | `ch.css.box-position` | `web.browser-rendering` |
| `web.css-flex-layout` | `ch.css.flexbox` | `web.css-foundations` |
| `web.css-grid-layout` | `ch.css.grid` | `web.css-foundations` |
| `web.javascript-language` | `ch.js.control-flow` | `foundation.toolchain-env-build`, `foundation.verification-debug-test` |
| `web.javascript-functions-closures` | `ch.js.scope-closures` | `web.javascript-language` |
| `web.javascript-objects` | `ch.js.object-model` | `web.javascript-language` |
| `web.javascript-dom` | `ch.js.events-forms` | `web.javascript-objects`, `web.html-semantic-form` |
| `web.javascript-async-runtime` | `ch.js.event-loop` | `web.javascript-functions-closures` |
| `web.javascript-network-race` | `ch.js.fetch-cancellation-race` | `web.javascript-async-runtime`, `web.browser-origin-state`, `foundation.http-message`, `web.javascript-testing-debugging` |
| `web.typescript-types` | `ch.ts.modeling-narrowing` | `web.javascript-language`, `web.javascript-objects` |
| `web.vue-template` | `ch.vue.forms-vmodel` | `web.html-semantic-form`, `web.javascript-language`, `web.javascript-functions-closures` |
| `web.vue-reactivity-lifecycle` | `ch.vue.effects-lifecycle` | `web.vue-template`, `web.javascript-async-runtime` |
| `web.vue-components-contracts` | `ch.vue.components-contracts` | `web.vue-template`, `web.vue-reactivity-lifecycle` |
| `web.vue-router-navigation` | `ch.vue.router-navigation` | `web.vue-components-contracts` |
| `web.vue-client-state` | `ch.vue.pinia-state` | `web.vue-components-contracts`, `web.vue-reactivity-lifecycle` |
| `web.javascript-testing-debugging` | `ch.js.testing-debugging` | `web.javascript-language`, `foundation.verification-debug-test` |
| `web.component-e2e-testing` | `ch.vue.component-testing` | `web.javascript-testing-debugging`, `web.vue-components-contracts`, `web.javascript-network-race` |
| `mobile.miniprogram-runtime` | `ch.miniapp.runtime` | `foundation.shell-command-stream` |
| `mobile.uniapp-platform` | `ch.uniapp.platform-conditional` | `mobile.miniprogram-runtime`, `web.vue-template` |
| `mobile.uniapp-device-permissions` | `ch.uniapp.device-capabilities` | `mobile.uniapp-platform` |
| `mobile.uniapp-offline-idempotency` | `ch.uniapp.offline-idempotency` | `mobile.uniapp-platform`, `architecture.idempotency-consistency` |
| `mobile.dart-language` | `ch.dart.oop-generics` | `foundation.toolchain-env-build` |
| `mobile.dart-future-cancellation` | `ch.dart.future-cancellation` | `mobile.dart-language` |
| `mobile.dart-streams-isolates` | `ch.dart.streams-isolates` | `mobile.dart-language`, `mobile.dart-future-cancellation` |
| `mobile.flutter-tooling-widget` | `ch.flutter.widget-tree` | `mobile.dart-language` |
| `mobile.flutter-layout-lifecycle` | `ch.flutter.state-lifecycle` | `mobile.dart-future-cancellation`, `mobile.flutter-tooling-widget`, `web.accessibility` |
| `mobile.flutter-network-offline` | `ch.flutter.network-storage-offline` | `mobile.dart-future-cancellation`, `foundation.http-message`, `architecture.idempotency-consistency` |
| `mobile.flutter-device-permissions` | `ch.flutter.device-apis` | `mobile.flutter-network-offline`, `mobile.flutter-layout-lifecycle` |
| `python.language` | `ch.python.collections` | `foundation.toolchain-env-build` |
| `python.io-errors` | `ch.python.exceptions-context` | `python.language`, `foundation.files-path-encoding` |
| `python.typing-oop` | `ch.python.protocol-generics` | `python.language` |
| `python.testing-debugging` | `ch.python.testing-logging-debug` | `python.language`, `python.io-errors`, `foundation.verification-debug-test` |
| `python.asyncio-cancellation` | `ch.python.asyncio-cancellation` | `python.language`, `python.io-errors` |
| `data.numpy-pandas` | `ch.data.pandas` | `python.language` |
| `math.algebra-functions` | `ch.math.functions-graphs` |  |
| `math.linear-calculus` | `ch.math.gradients` | `math.algebra-functions` |
| `math.probability-statistics` | `ch.math.probability-statistics` | `math.algebra-functions` |
| `ml.problem-classical-evaluation` | `ch.ml.metrics-validation` | `data.numpy-pandas`, `math.algebra-functions`, `math.probability-statistics` |
| `ml.neural-pytorch` | `ch.pytorch.foundations` | `ml.problem-classical-evaluation`, `math.linear-calculus` |
| `ml.training-inference` | `ch.pytorch.inference` | `ml.neural-pytorch` |
| `ai.llm-model-api` | `ch.llm.api-prompts-cost` | `ml.neural-pytorch`, `python.language`, `foundation.http-message` |
| `ai.structured-tool-calling` | `ch.llm.tool-calling` | `ai.llm-model-api`, `security.web-threat` |
| `ai.rag-ingestion-retrieval` | `ch.ir.hybrid-rerank` | `ai.llm-model-api`, `data.numpy-pandas`, `math.linear-calculus` |
| `ai.rag-evaluation-security` | `ch.rag.security-observability` | `ai.structured-tool-calling`, `ai.rag-ingestion-retrieval`, `security.authorization-policy`, `security.multitenancy-isolation`, `architecture.observability` |
| `ai.agent-graph-mcp` | `ch.agent.mcp-boundaries` | `ai.structured-tool-calling`, `ai.rag-evaluation-security`, `python.asyncio-cancellation`, `python.testing-debugging` |
| `ops.linux-service-network` | `ch.ops.network-diagnostics` | `foundation.shell-command-stream`, `foundation.network-transport` |
| `ops.container-proxy-delivery` | `ch.release.artifacts-promotion` | `foundation.docker-runtime`, `ops.linux-service-network`, `foundation.toolchain-env-build`, `foundation.verification-debug-test` |
| `ops.recovery-deployment` | `ch.ops.incident-dr` | `ops.container-proxy-delivery`, `architecture.observability`, `data.transactions-locks`, `data.schema-migration` |

## Chapter hard prerequisites

### 00 计算机、工具与验证基础

- `ch.foundations.learning-evidence` ← root
- `ch.foundations.files-paths-encoding` ← root
- `ch.foundations.terminal-shell` ← `ch.foundations.files-paths-encoding`
- `ch.foundations.computer-process-model` ← `ch.foundations.terminal-shell`
- `ch.foundations.cli-streams-exit-codes` ← `ch.foundations.computer-process-model`
- `ch.foundations.environment-tool-resolution` ← `ch.foundations.cli-streams-exit-codes`
- `ch.foundations.editor-project-navigation` ← `ch.foundations.files-paths-encoding`
- `ch.foundations.git-collaboration-security` ← `ch.foundations.cli-streams-exit-codes`
- `ch.foundations.network-layers` ← `ch.foundations.cli-streams-exit-codes`
- `ch.foundations.http-curl` ← `ch.foundations.network-layers`
- `ch.foundations.api-contract-basics` ← `ch.foundations.http-curl`
- `ch.foundations.testing-oracles` ← `ch.foundations.cli-streams-exit-codes`
- `ch.foundations.dependencies-build-packages` ← `ch.foundations.environment-tool-resolution`, `ch.foundations.testing-oracles`
- `ch.foundations.docker-basics` ← `ch.foundations.network-layers`, `ch.foundations.testing-oracles`
- `ch.foundations.ai-assisted-verification` ← `ch.foundations.git-collaboration-security`, `ch.foundations.dependencies-build-packages`

### 01 Java 语言基础

- `ch.java.platform-toolchain` ← `ch.foundations.dependencies-build-packages`
- `ch.java.program-structure` ← `ch.java.platform-toolchain`
- `ch.java.values-variables-types` ← `ch.java.program-structure`
- `ch.java.expressions-conversions` ← `ch.java.values-variables-types`
- `ch.java.branching` ← `ch.java.expressions-conversions`
- `ch.java.loops` ← `ch.java.branching`
- `ch.java.arrays-command-args` ← `ch.java.loops`
- `ch.java.methods` ← `ch.java.arrays-command-args`
- `ch.java.console-input-validation` ← `ch.java.methods`
- `ch.java.maven-junit-smoke` ← `ch.java.methods`
- `ch.java.debugging-failures` ← `ch.java.maven-junit-smoke`, `ch.foundations.editor-project-navigation`

### 02 Java 对象模型

- `ch.java-oop.references-null-identity` ← `ch.java.methods`
- `ch.java-oop.classes-objects` ← `ch.java-oop.references-null-identity`
- `ch.java-oop.constructors-invariants` ← `ch.java-oop.classes-objects`
- `ch.java-oop.encapsulation-packages` ← `ch.java-oop.constructors-invariants`
- `ch.java-oop.static-class-state` ← `ch.java-oop.encapsulation-packages`
- `ch.java-oop.final-immutability` ← `ch.java-oop.encapsulation-packages`
- `ch.java-oop.inheritance-composition` ← `ch.java-oop.final-immutability`
- `ch.java-oop.interfaces-polymorphism` ← `ch.java-oop.inheritance-composition`
- `ch.java-oop.enum-record-sealed` ← `ch.java-oop.interfaces-polymorphism`
- `ch.java-oop.object-contracts` ← `ch.java-oop.final-immutability`
- `ch.java-oop.business-value-types` ← `ch.java-oop.final-immutability`
- `ch.java-oop.exceptions-failure-contracts` ← `ch.java-oop.interfaces-polymorphism`

### 03 Java 工程能力

- `ch.java-engineering.maven-reproducible-builds` ← `ch.java.maven-junit-smoke`
- `ch.java-engineering.generics-type-safety` ← `ch.java-oop.interfaces-polymorphism`
- `ch.java-engineering.sequential-collections` ← `ch.java-engineering.generics-type-safety`
- `ch.java-engineering.associative-collections` ← `ch.java-engineering.sequential-collections`, `ch.java-oop.object-contracts`
- `ch.java-engineering.sorting-comparators` ← `ch.java-engineering.sequential-collections`
- `ch.java-engineering.complexity-algorithms` ← `ch.java-engineering.associative-collections`, `ch.java-engineering.sorting-comparators`
- `ch.java-engineering.lambdas-functional-interfaces` ← `ch.java-oop.interfaces-polymorphism`
- `ch.java-engineering.functional-pipelines` ← `ch.java-engineering.associative-collections`, `ch.java-engineering.lambdas-functional-interfaces`
- `ch.java-engineering.io-resource-lifecycle` ← `ch.java-oop.exceptions-failure-contracts`
- `ch.java-engineering.nio-files-charsets` ← `ch.java-engineering.io-resource-lifecycle`
- `ch.java-engineering.json-mapping` ← `ch.java-engineering.nio-files-charsets`, `ch.java-oop.enum-record-sealed`, `ch.java-engineering.maven-reproducible-builds`
- `ch.java-engineering.threads-jmm` ← `ch.java-oop.static-class-state`, `ch.java-engineering.io-resource-lifecycle`
- `ch.java-engineering.executors-virtual-threads` ← `ch.java-engineering.threads-jmm`
- `ch.java-engineering.annotations-metadata` ← `ch.java-oop.classes-objects`
- `ch.java-engineering.reflection-classloading-proxies` ← `ch.java-engineering.annotations-metadata`, `ch.java-engineering.io-resource-lifecycle`
- `ch.java-engineering.network-programming` ← `ch.foundations.http-curl`, `ch.java-engineering.io-resource-lifecycle`
- `ch.java-engineering.testing-test-doubles` ← `ch.java-engineering.maven-reproducible-builds`, `ch.java-oop.exceptions-failure-contracts`
- `ch.java-engineering.logging-jvm-diagnostics` ← `ch.java-engineering.maven-reproducible-builds`, `ch.java-engineering.threads-jmm`

### 04 关系数据、SQL 与 PostgreSQL

- `ch.data.relational-model` ← root
- `ch.data.postgresql-psql` ← `ch.data.relational-model`, `ch.foundations.cli-streams-exit-codes`
- `ch.data.select-rowsets` ← `ch.data.postgresql-psql`
- `ch.data.scalar-functions` ← `ch.data.select-rowsets`
- `ch.data.aggregates` ← `ch.data.select-rowsets`
- `ch.data.joins` ← `ch.data.aggregates`
- `ch.data.subqueries-cte` ← `ch.data.aggregates`
- `ch.data.window-functions` ← `ch.data.joins`, `ch.data.subqueries-cte`
- `ch.data.dml` ← `ch.data.select-rowsets`
- `ch.data.ddl-constraints` ← `ch.data.postgresql-psql`
- `ch.data.normalization-modeling` ← `ch.data.ddl-constraints`
- `ch.data.postgresql-types` ← `ch.data.ddl-constraints`
- `ch.data.indexes-explain` ← `ch.data.select-rowsets`, `ch.data.ddl-constraints`, `ch.foundations.testing-oracles`
- `ch.data.transactions-locking` ← `ch.data.dml`, `ch.data.ddl-constraints`, `ch.foundations.testing-oracles`
- `ch.data.schema-migrations` ← `ch.data.transactions-locking`, `ch.foundations.dependencies-build-packages`
- `ch.data.jdbc` ← `ch.java-engineering.maven-reproducible-builds`, `ch.java-engineering.io-resource-lifecycle`, `ch.data.transactions-locking`
- `ch.data.mybatis-core` ← `ch.data.jdbc`, `ch.java-engineering.generics-type-safety`

### 05 Spring Web、数据与事务

- `ch.spring.servlet-request-lifecycle` ← `ch.foundations.api-contract-basics`, `ch.java-engineering.maven-reproducible-builds`
- `ch.spring.ioc-di` ← `ch.java-oop.interfaces-polymorphism`, `ch.java.maven-junit-smoke`
- `ch.spring.beans-lifecycle-scopes` ← `ch.spring.ioc-di`
- `ch.spring.configuration-profiles` ← `ch.spring.beans-lifecycle-scopes`
- `ch.spring.boot-autoconfiguration` ← `ch.spring.configuration-profiles`, `ch.java-engineering.maven-reproducible-builds`
- `ch.spring.mvc-routing-binding` ← `ch.spring.servlet-request-lifecycle`, `ch.spring.boot-autoconfiguration`
- `ch.spring.dto-json-content-negotiation` ← `ch.spring.mvc-routing-binding`, `ch.java-engineering.json-mapping`
- `ch.spring.validation` ← `ch.spring.dto-json-content-negotiation`
- `ch.spring.problem-details-errors` ← `ch.spring.validation`
- `ch.architecture.domain-modeling` ← `ch.java-oop.interfaces-polymorphism`, `ch.java-oop.business-value-types`
- `ch.spring.datasource-pooling` ← `ch.spring.boot-autoconfiguration`, `ch.data.jdbc`, `ch.data.schema-migrations`
- `ch.spring.mybatis-repositories` ← `ch.spring.datasource-pooling`, `ch.data.mybatis-core`, `ch.architecture.domain-modeling`
- `ch.spring.service-use-cases` ← `ch.spring.mybatis-repositories`
- `ch.spring.aop-proxy-model` ← `ch.spring.beans-lifecycle-scopes`, `ch.java-engineering.reflection-classloading-proxies`
- `ch.spring.testing-testcontainers` ← `ch.spring.mvc-routing-binding`, `ch.spring.mybatis-repositories`, `ch.java-engineering.testing-test-doubles`, `ch.foundations.docker-basics`
- `ch.spring.transactions` ← `ch.spring.service-use-cases`, `ch.spring.aop-proxy-model`, `ch.spring.testing-testcontainers`
- `ch.spring.openapi-contracts` ← `ch.spring.problem-details-errors`
- `ch.spring.actuator-health-metrics` ← `ch.spring.testing-testcontainers`

### 06 安全与企业架构

- `ch.security.threat-model-trust-boundaries` ← `ch.foundations.api-contract-basics`, `ch.foundations.testing-oracles`
- `ch.security.identity-password-lifecycle` ← `ch.java-oop.business-value-types`, `ch.foundations.api-contract-basics`
- `ch.security.cookie-session-model` ← `ch.security.identity-password-lifecycle`
- `ch.security.origin-cors-csrf` ← `ch.security.cookie-session-model`, `ch.security.threat-model-trust-boundaries`
- `ch.security.untrusted-input-xss-ssrf` ← `ch.security.origin-cors-csrf`, `ch.spring.problem-details-errors`
- `ch.security.spring-security-architecture` ← `ch.security.untrusted-input-xss-ssrf`
- `ch.security.session-authentication` ← `ch.security.spring-security-architecture`, `ch.spring.testing-testcontainers`
- `ch.security.jwt-resource-server` ← `ch.security.session-authentication`
- `ch.security.oauth2-oidc` ← `ch.security.jwt-resource-server`
- `ch.security.authorization-rbac-abac` ← `ch.security.jwt-resource-server`, `ch.spring.transactions`
- `ch.security.multitenancy-data-isolation` ← `ch.security.authorization-rbac-abac`
- `ch.security.audit-events-privacy` ← `ch.security.multitenancy-data-isolation`, `ch.java-engineering.logging-jvm-diagnostics`
- `ch.architecture.workflow-state-sla` ← `ch.architecture.domain-modeling`, `ch.data.transactions-locking`
- `ch.architecture.idempotency-concurrency` ← `ch.architecture.workflow-state-sla`, `ch.spring.transactions`, `ch.java-engineering.threads-jmm`
- `ch.distributed.redis-cache-rate-limit` ← `ch.architecture.idempotency-concurrency`
- `ch.architecture.domain-events-outbox` ← `ch.architecture.idempotency-concurrency`
- `ch.distributed.messaging-delivery` ← `ch.architecture.domain-events-outbox`
- `ch.architecture.modular-monolith` ← `ch.distributed.messaging-delivery`
- `ch.architecture.observability-slo` ← `ch.spring.actuator-health-metrics`, `ch.architecture.modular-monolith`, `ch.security.audit-events-privacy`

### 07 Web 平台、HTML 与 CSS

- `ch.web.browser-render-devtools` ← `ch.foundations.http-curl`
- `ch.web.origin-cookie-cache` ← `ch.web.browser-render-devtools`
- `ch.web.semantic-html` ← `ch.web.browser-render-devtools`
- `ch.web.forms-validation` ← `ch.web.semantic-html`, `ch.web.origin-cookie-cache`
- `ch.web.media-assets` ← `ch.web.semantic-html`
- `ch.web.accessibility-interaction` ← `ch.web.forms-validation`
- `ch.css.cascade` ← `ch.web.semantic-html`
- `ch.css.box-position` ← `ch.css.cascade`
- `ch.css.flexbox` ← `ch.css.box-position`
- `ch.css.grid` ← `ch.css.box-position`
- `ch.css.responsive-typography` ← `ch.web.media-assets`, `ch.css.flexbox`, `ch.css.grid`
- `ch.css.theme-variables` ← `ch.css.cascade`
- `ch.css.motion-compositing` ← `ch.css.box-position`, `ch.web.accessibility-interaction`

### 08 JavaScript 与 TypeScript

- `ch.js.runtime-esm` ← `ch.foundations.dependencies-build-packages`
- `ch.js.statements-variables` ← `ch.js.runtime-esm`
- `ch.js.values-operators` ← `ch.js.statements-variables`
- `ch.js.control-flow` ← `ch.js.values-operators`
- `ch.js.functions` ← `ch.js.control-flow`
- `ch.js.scope-closures` ← `ch.js.functions`
- `ch.js.collections` ← `ch.js.functions`
- `ch.js.object-model` ← `ch.js.collections`
- `ch.js.testing-debugging` ← `ch.js.collections`
- `ch.js.dom-mutation` ← `ch.js.collections`, `ch.web.semantic-html`
- `ch.js.events-forms` ← `ch.js.dom-mutation`, `ch.js.object-model`, `ch.web.forms-validation`
- `ch.js.event-loop` ← `ch.js.scope-closures`
- `ch.js.fetch-cancellation-race` ← `ch.js.testing-debugging`, `ch.js.event-loop`, `ch.web.origin-cookie-cache`
- `ch.js.browser-performance` ← `ch.js.events-forms`, `ch.js.event-loop`, `ch.css.motion-compositing`
- `ch.ts.foundations` ← `ch.js.collections`
- `ch.ts.modeling-narrowing` ← `ch.ts.foundations`, `ch.js.object-model`
- `ch.ts.generics-utilities` ← `ch.ts.modeling-narrowing`
- `ch.ts.runtime-boundaries` ← `ch.ts.modeling-narrowing`, `ch.js.fetch-cancellation-race`

### 09 Vue 3 与 Nuxt

- `ch.vue.vite-sfc` ← `ch.ts.foundations`, `ch.css.cascade`
- `ch.vue.template-directives` ← `ch.vue.vite-sfc`
- `ch.vue.forms-vmodel` ← `ch.vue.template-directives`, `ch.web.forms-validation`, `ch.js.scope-closures`
- `ch.vue.reactivity` ← `ch.vue.vite-sfc`
- `ch.vue.effects-lifecycle` ← `ch.vue.reactivity`, `ch.vue.forms-vmodel`, `ch.js.fetch-cancellation-race`
- `ch.vue.components-contracts` ← `ch.vue.effects-lifecycle`
- `ch.vue.composables-di` ← `ch.vue.components-contracts`
- `ch.vue.router-navigation` ← `ch.vue.components-contracts`
- `ch.vue.pinia-state` ← `ch.vue.components-contracts`
- `ch.vue.server-state` ← `ch.vue.pinia-state`
- `ch.vue.auth-permissions` ← `ch.vue.router-navigation`, `ch.vue.server-state`, `ch.security.authorization-rbac-abac`
- `ch.vue.component-testing` ← `ch.vue.server-state`
- `ch.vue.accessibility` ← `ch.vue.components-contracts`, `ch.web.accessibility-interaction`
- `ch.vue.performance` ← `ch.vue.component-testing`
- `ch.nuxt.rendering-hydration` ← `ch.vue.components-contracts`

### 10 小程序与 uni-app

- `ch.miniapp.runtime` ← `ch.foundations.cli-streams-exit-codes`
- `ch.uniapp.toolchain-pages` ← `ch.miniapp.runtime`, `ch.vue.vite-sfc`
- `ch.uniapp.template-components` ← `ch.uniapp.toolchain-pages`, `ch.vue.components-contracts`
- `ch.uniapp.network-auth-storage` ← `ch.uniapp.toolchain-pages`, `ch.security.session-authentication`
- `ch.uniapp.platform-conditional` ← `ch.uniapp.template-components`
- `ch.uniapp.device-capabilities` ← `ch.uniapp.network-auth-storage`, `ch.uniapp.platform-conditional`
- `ch.uniapp.testing-debugging` ← `ch.uniapp.template-components`, `ch.uniapp.network-auth-storage`
- `ch.uniapp.packages-performance` ← `ch.uniapp.testing-debugging`
- `ch.uniapp.offline-idempotency` ← `ch.uniapp.platform-conditional`, `ch.uniapp.packages-performance`, `ch.architecture.idempotency-concurrency`
- `ch.uniapp.privacy-review` ← `ch.uniapp.device-capabilities`, `ch.uniapp.testing-debugging`
- `ch.uniapp.release-monitoring` ← `ch.uniapp.packages-performance`, `ch.uniapp.privacy-review`
- `ch.uniapp.factorycare-reporter` ← `ch.uniapp.offline-idempotency`, `ch.uniapp.release-monitoring`, `ch.vue.server-state`

### 11 Dart 与 Flutter

- `ch.dart.toolchain` ← `ch.foundations.dependencies-build-packages`
- `ch.dart.types-null-safety` ← `ch.dart.toolchain`
- `ch.dart.control-functions` ← `ch.dart.types-null-safety`
- `ch.dart.collections-patterns` ← `ch.dart.control-functions`
- `ch.dart.oop-generics` ← `ch.dart.collections-patterns`
- `ch.dart.exceptions-resources` ← `ch.dart.oop-generics`
- `ch.dart.future-cancellation` ← `ch.dart.exceptions-resources`
- `ch.dart.streams-isolates` ← `ch.dart.future-cancellation`
- `ch.dart.testing-lints` ← `ch.dart.exceptions-resources`
- `ch.flutter.toolchain-project` ← `ch.dart.oop-generics`
- `ch.flutter.widget-tree` ← `ch.flutter.toolchain-project`
- `ch.flutter.layout-accessibility` ← `ch.flutter.widget-tree`, `ch.web.accessibility-interaction`
- `ch.flutter.state-lifecycle` ← `ch.flutter.layout-accessibility`, `ch.dart.future-cancellation`
- `ch.flutter.navigation-forms` ← `ch.flutter.state-lifecycle`
- `ch.flutter.architecture-state` ← `ch.flutter.navigation-forms`
- `ch.flutter.network-storage-offline` ← `ch.flutter.state-lifecycle`, `ch.architecture.idempotency-concurrency`
- `ch.flutter.device-apis` ← `ch.flutter.network-storage-offline`, `ch.security.untrusted-input-xss-ssrf`
- `ch.flutter.testing-performance` ← `ch.dart.testing-lints`, `ch.flutter.architecture-state`
- `ch.flutter.release-monitoring` ← `ch.flutter.testing-performance`

### 12 Python、FastAPI 与数据工具

- `ch.python.runtime-uv` ← `ch.foundations.dependencies-build-packages`
- `ch.python.syntax-values-io` ← `ch.python.runtime-uv`
- `ch.python.control-flow` ← `ch.python.syntax-values-io`
- `ch.python.functions-scope` ← `ch.python.control-flow`
- `ch.python.collections` ← `ch.python.functions-scope`
- `ch.python.typing-foundations` ← `ch.python.collections`
- `ch.python.modules-packages` ← `ch.python.typing-foundations`
- `ch.python.files-json-time` ← `ch.python.modules-packages`
- `ch.python.classes-dataclass` ← `ch.python.typing-foundations`
- `ch.python.protocol-generics` ← `ch.python.classes-dataclass`
- `ch.python.exceptions-context` ← `ch.python.classes-dataclass`, `ch.python.files-json-time`
- `ch.python.iterators-decorators` ← `ch.python.exceptions-context`
- `ch.python.testing-logging-debug` ← `ch.python.exceptions-context`
- `ch.python.asyncio-cancellation` ← `ch.python.exceptions-context`
- `ch.python.pydantic-validation` ← `ch.python.exceptions-context`
- `ch.fastapi.web-foundations` ← `ch.python.pydantic-validation`, `ch.foundations.http-curl`
- `ch.fastapi.security-testing-openapi` ← `ch.python.testing-logging-debug`, `ch.python.asyncio-cancellation`, `ch.fastapi.web-foundations`, `ch.security.session-authentication`
- `ch.data.numpy` ← `ch.python.collections`
- `ch.data.pandas` ← `ch.python.files-json-time`, `ch.data.numpy`

### 13 数学、机器学习与 PyTorch

- `ch.math.algebra-units` ← root
- `ch.math.functions-graphs` ← `ch.math.algebra-units`
- `ch.math.linear-algebra` ← `ch.math.functions-graphs`
- `ch.math.probability-statistics` ← `ch.math.functions-graphs`
- `ch.math.gradients` ← `ch.math.linear-algebra`
- `ch.ml.problem-data-split` ← `ch.math.probability-statistics`, `ch.data.pandas`
- `ch.ml.preprocessing-features` ← `ch.ml.problem-data-split`
- `ch.ml.supervised-learning` ← `ch.math.linear-algebra`, `ch.ml.preprocessing-features`
- `ch.ml.unsupervised-learning` ← `ch.math.linear-algebra`, `ch.ml.preprocessing-features`
- `ch.ml.metrics-validation` ← `ch.ml.supervised-learning`
- `ch.ml.neural-networks` ← `ch.math.probability-statistics`, `ch.math.gradients`
- `ch.ml.attention-sequences` ← `ch.ml.neural-networks`
- `ch.pytorch.foundations` ← `ch.ml.neural-networks`, `ch.ml.metrics-validation`, `ch.python.classes-dataclass`
- `ch.pytorch.training` ← `ch.pytorch.foundations`
- `ch.pytorch.inference` ← `ch.pytorch.training`
- `ch.ml.monitoring-ethics` ← `ch.pytorch.inference`

### 14 LLM、RAG 与 Agent

- `ch.llm.model-foundations` ← `ch.ml.attention-sequences`, `ch.python.collections`
- `ch.llm.api-prompts-cost` ← `ch.llm.model-foundations`, `ch.pytorch.foundations`, `ch.foundations.http-curl`
- `ch.llm.structured-output` ← `ch.llm.api-prompts-cost`, `ch.python.pydantic-validation`
- `ch.llm.streaming-resilience` ← `ch.llm.api-prompts-cost`, `ch.python.asyncio-cancellation`
- `ch.llm.tool-calling` ← `ch.llm.structured-output`, `ch.llm.streaming-resilience`, `ch.security.untrusted-input-xss-ssrf`
- `ch.rag.ingestion-metadata` ← `ch.python.exceptions-context`, `ch.llm.api-prompts-cost`
- `ch.rag.chunking-embeddings` ← `ch.rag.ingestion-metadata`
- `ch.ir.lexical-retrieval` ← `ch.python.collections`, `ch.math.functions-graphs`
- `ch.ir.evaluation` ← `ch.ir.lexical-retrieval`, `ch.math.probability-statistics`
- `ch.ir.dense-pgvector` ← `ch.rag.chunking-embeddings`, `ch.data.indexes-explain`
- `ch.ir.hybrid-rerank` ← `ch.ir.evaluation`, `ch.ir.dense-pgvector`
- `ch.rag.citations-evaluation` ← `ch.llm.structured-output`, `ch.ir.hybrid-rerank`
- `ch.rag.security-observability` ← `ch.llm.tool-calling`, `ch.rag.citations-evaluation`, `ch.architecture.observability-slo`
- `ch.agent.langchain` ← `ch.llm.streaming-resilience`, `ch.rag.citations-evaluation`
- `ch.agent.langgraph` ← `ch.llm.tool-calling`, `ch.agent.langchain`
- `ch.agent.mcp-boundaries` ← `ch.agent.langgraph`, `ch.rag.security-observability`, `ch.python.testing-logging-debug`

### 15 生产化与 FactoryCare 验收

- `ch.ops.linux-services` ← `ch.foundations.cli-streams-exit-codes`
- `ch.ops.network-diagnostics` ← `ch.ops.linux-services`, `ch.foundations.http-curl`
- `ch.ops.docker-production` ← `ch.ops.network-diagnostics`, `ch.foundations.docker-basics`
- `ch.ops.compose-services` ← `ch.ops.docker-production`
- `ch.ops.nginx-tls` ← `ch.ops.compose-services`
- `ch.release.ci-quality` ← `ch.foundations.git-collaboration-security`, `ch.foundations.dependencies-build-packages`
- `ch.release.artifacts-promotion` ← `ch.ops.nginx-tls`, `ch.release.ci-quality`
- `ch.ops.config-secrets-supply-chain` ← `ch.ops.docker-production`, `ch.release.ci-quality`, `ch.security.untrusted-input-xss-ssrf`
- `ch.ops.logs-health` ← `ch.ops.compose-services`, `ch.architecture.observability-slo`
- `ch.ops.metrics-traces-slo` ← `ch.ops.logs-health`
- `ch.ops.backup-recovery` ← `ch.ops.compose-services`, `ch.data.transactions-locking`, `ch.architecture.domain-modeling`
- `ch.ops.capacity-performance` ← `ch.ops.metrics-traces-slo`, `ch.ops.backup-recovery`, `ch.data.indexes-explain`
- `ch.release.deployment-migrations` ← `ch.release.artifacts-promotion`, `ch.ops.backup-recovery`, `ch.architecture.observability-slo`
- `ch.ops.incident-dr` ← `ch.ops.metrics-traces-slo`, `ch.release.deployment-migrations`
- `ch.architecture.system-design` ← `ch.ops.capacity-performance`
- `ch.release.factorycare-acceptance` ← `ch.ops.incident-dr`, `ch.architecture.system-design`, `ch.vue.component-testing`, `ch.uniapp.release-monitoring`, `ch.flutter.testing-performance`, `ch.flutter.device-apis`, `ch.agent.mcp-boundaries`
- `ch.portfolio.interview` ← `ch.release.factorycare-acceptance`, `ch.foundations.ai-assisted-verification`, `ch.foundations.learning-evidence`
