# P1R 卷 07—15 零基础扩充设计

## 1. 结论与边界

- 设计对象：卷 07—15。
- 设计依据：curriculum/catalog.yml 与 P1 教学语义前置审计。
- 目标读者：没有前端、移动端、Python、数学、机器学习或 Agent 基础的学习者。
- 推荐规模：卷 07—15 从 94 章扩充为 145 章，分卷数量为 13、18、15、12、19、19、16、16、17。
- 联合预算：如果卷 00—06 按约 98 章重构，全书约 243 章，落在 230—260 章的新预算内。
- 当前事实：所有章节仍为 planned；本设计不代表正文、示例、实验、练习、评审或学习进度已经完成。
- 本文件只提出目标目录、迁移和验证合同，不修改 catalog、routes、gates、book、sources 或 PROGRESS.md。

### 1.1 设计原则

1. outcome 只能使用本章明确首教，或硬前置闭包已经教授的概念。
2. recommended_after 只负责阅读连贯，不能承担完成 outcome 所需知识。
3. 语言语法、框架实践、平台适配和生产深化必须分层，不能让框架章重新冒充基础概念的 canonical teacher。
4. 每章只有一个主要责任，最多再带一个紧密关联的次级认知簇。
5. 具体实验依赖与路线完成门禁不能污染通用章节的硬依赖图。
6. 任何“测试”要求都必须说明测试预言、断言和所用验证层级来自哪里。
7. 当前全部为 planned，目录重构不得自动修改 PROGRESS.md 或授予任何阶段通过。

## 2. 稳定 ID 决策

### 2.1 可行方案

| 方案 | 实施成本 | 迁移成本 | 风险 | 回滚难度 | 长期维护 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 保留旧 ID，新章追加 c14、c15 后用 order 插入 | 低 | 低 | ID 与阅读顺序永久错位 | 低 | 差 |
| 全量重编号为新的 v07.c01 形式 | 高 | 高 | 下一次插章仍需全量重编号 | 中 | 中 |
| 改为 ch.domain.slug，卷号和顺序独立 | 高 | 高，但当前全为 planned | 一次性迁移面较大但可验证 | 中 | 最好 |

### 2.2 推荐

推荐使用稳定语义 ID：

~~~yaml
id: ch.vue.reactivity
volume: "09"
order: 4
~~~

不保留运行时 legacy alias。旧 ID 与新 ID 的关系进入一次性迁移账本，供 catalog、routes、gates、source mappings 和审查记录迁移使用。

~~~yaml
old_id: v09.c02.reactivity
primary_new_id: ch.vue.reactivity
new_ids:
  - ch.vue.reactivity
reason: stable-semantic-id
~~~

## 3. 跨卷硬前置锚点

卷 00—06 也会重构，因此下面用语义锚点表达跨卷依赖，并记录当前旧 ID。联合实施时必须解析为早期卷最终稳定 ID。

| 锚点 | 当前对应 | 联合重构要求 |
| --- | --- | --- |
| F-SHELL | v00.c04.terminal-shell | Shell、命令、退出码 |
| F-FILES | v00.c03.files-paths-encoding | 文件、路径、编码 |
| F-ENV | v00.c06.environment-path | 环境变量和 PATH |
| F-GIT | v00.c08.git-security | Git 与安全基线 |
| F-HTTP | v00.c09.network-http-curl | 必须真实教授 HTTP 报文、curl、状态码与 Header |
| F-DEPS | v00.c10.dependencies-build-ai | 依赖与构建基础 |
| F-DOCKER | v00.c11.docker-foundations | Docker 首教层 |
| F-TEST | 当前缺失 | 新增测试预言、断言、AAA 与失败证据 canonical teacher |
| SEC-AUTH | v06.c01.auth-session-password | 认证、Session 与密码模型 |
| SEC-WEB | v06.c02.web-security-threats | Web 威胁模型 |
| SEC-RBAC | v06.c05.rbac-multitenancy-audit | RBAC 与数据权限概念 |
| STATE-IDEMP | v06.c07.state-sla-idempotency | 状态与幂等 |
| BACKEND-OBS | v06.c10.modular-monolith-observability | 后端可观测性 |
| DB-REL | v04.c01.relational-model | 关系模型 |
| DB-INDEX | v04.c08.indexes-explain | 索引与 EXPLAIN |
| DB-TX | v04.c09.transactions-locks | 事务与锁 |
| DB-MIGRATION | v04.c10.migration-jdbc-mybatis | 数据库迁移；早期卷重构后应指向真正的迁移 canonical teacher |

## 4. 精确目录

角色说明：

- 首教：第一次正式教授概念。
- 语言：在特定语言中首次实现已知工程概念。
- 框架：复用语言和平台概念进行框架实践。
- 平台：宿主或设备平台适配。
- 生产：生产环境深化。
- 门禁：综合验收，不负责补语言或框架基础。

### 4.1 卷 07：Web 平台基础，共 13 章

| 顺序 | ID | 标题 | 角色 | 关键硬前置 |
| ---: | --- | --- | --- | --- |
| 1 | ch.web.browser-render-devtools | 浏览器请求、解析、渲染与 DevTools 观察 | 首教 | F-HTTP |
| 2 | ch.web.origin-cookie-cache | Origin、同源、Cookie、缓存与 CORS 浏览器模型 | 首教 | ch.web.browser-render-devtools、F-HTTP |
| 3 | ch.web.semantic-html | 语义 HTML、文档结构与元数据 | 首教 | ch.web.browser-render-devtools |
| 4 | ch.web.forms-validation | 表单控件、提交语义与原生校验 | 首教 | ch.web.semantic-html |
| 5 | ch.web.media-assets | 图片、响应式资源、音视频与资源边界 | 首教 | ch.web.semantic-html |
| 6 | ch.web.accessibility-interaction | 无障碍、键盘、焦点与屏幕阅读器 | 首教 | ch.web.semantic-html、ch.web.forms-validation |
| 7 | ch.css.cascade | CSS 语法、选择器、层叠、优先级与继承 | 首教 | ch.web.semantic-html |
| 8 | ch.css.box-position | 盒模型、display、定位与层叠上下文 | 首教 | ch.css.cascade |
| 9 | ch.css.flexbox | Flexbox 一维布局 | 首教 | ch.css.box-position |
| 10 | ch.css.grid | Grid 二维布局 | 首教 | ch.css.box-position |
| 11 | ch.css.responsive-typography | 响应式单位、断点、排版与资源适配 | 首教 | ch.web.media-assets、ch.css.flexbox、ch.css.grid |
| 12 | ch.css.theme-variables | 颜色、主题与 CSS 自定义属性 | 首教 | ch.css.cascade |
| 13 | ch.css.motion-compositing | 过渡、变换、动画、合成与减少动效 | 首教 | ch.css.box-position、ch.web.accessibility-interaction |

浏览器首章只要求观察和解释主线程、请求与渲染阶段；修复 JavaScript 阻塞和 layout thrashing 延后到 ch.js.browser-performance。

### 4.2 卷 08：JavaScript 与 TypeScript，共 18 章

| 顺序 | ID | 标题 | 角色 | 关键硬前置 |
| ---: | --- | --- | --- | --- |
| 1 | ch.js.runtime-esm | JavaScript 运行时、Node、pnpm 与 ESM | 首教 | F-ENV、F-DEPS |
| 2 | ch.js.statements-variables | 源码、语句、变量、表达式、输出与最小预言 | 首教 | ch.js.runtime-esm |
| 3 | ch.js.values-operators | 值、类型、转换、运算符、相等与空值 | 首教 | ch.js.statements-variables |
| 4 | ch.js.control-flow | 条件、switch、循环与控制转移 | 首教 | ch.js.values-operators |
| 5 | ch.js.functions | 函数、参数、返回值与回调入口 | 首教 | ch.js.values-operators、ch.js.control-flow |
| 6 | ch.js.scope-closures | 词法作用域、闭包与函数状态 | 首教 | ch.js.functions |
| 7 | ch.js.collections | 数组、对象、Map、Set 与不可变更新 | 首教 | ch.js.control-flow、ch.js.functions |
| 8 | ch.js.object-model | this、原型、class 与对象模型 | 首教 | ch.js.functions、ch.js.collections |
| 9 | ch.js.testing-debugging | 异常、调试、测试预言与 Vitest | 语言 | ch.js.functions、ch.js.collections、F-TEST |
| 10 | ch.js.dom-mutation | DOM 树、查询、创建、更新与删除 | 语言 | ch.js.collections、ch.web.semantic-html |
| 11 | ch.js.events-forms | 事件传播、监听器、表单与默认行为 | 语言 | ch.js.dom-mutation、ch.js.functions、ch.web.forms-validation |
| 12 | ch.js.event-loop | 事件循环、任务、Promise 与 async/await | 首教 | ch.js.functions、ch.js.scope-closures |
| 13 | ch.js.fetch-cancellation-race | Fetch、AbortController、超时、重试与竞态 | 语言 | ch.js.testing-debugging、ch.js.event-loop、F-HTTP、ch.web.origin-cookie-cache |
| 14 | ch.js.browser-performance | 强制重排、任务阻塞、监听清理与内存边界 | 语言 | ch.js.dom-mutation、ch.js.events-forms、ch.js.event-loop、ch.css.motion-compositing |
| 15 | ch.ts.foundations | 类型标注、推断、数组、对象、元组与函数类型 | 首教 | ch.js.functions、ch.js.collections |
| 16 | ch.ts.modeling-narrowing | interface、type、联合、unknown、never 与收窄 | 首教 | ch.ts.foundations |
| 17 | ch.ts.generics-utilities | 泛型、约束、工具类型、映射与条件类型 | 首教 | ch.ts.modeling-narrowing |
| 18 | ch.ts.runtime-boundaries | 运行时 Schema、类型边界与 TypeScript 质量工具链 | 语言 | ch.ts.modeling-narrowing、ch.js.testing-debugging、ch.js.fetch-cancellation-race |

Vue 入门只硬依赖 TypeScript 基础，不得再硬依赖高级泛型、条件类型或运行时 Schema。

### 4.3 卷 09：Vue 3 与 Nuxt，共 15 章

| 顺序 | ID | 标题 | 角色 | 关键硬前置 |
| ---: | --- | --- | --- | --- |
| 1 | ch.vue.vite-sfc | Vite、Vue 应用、SFC 与项目结构 | 框架 | ch.js.runtime-esm、ch.ts.foundations、ch.css.cascade |
| 2 | ch.vue.template-directives | 插值、绑定、事件、条件与列表指令 | 框架 | ch.vue.vite-sfc、ch.js.functions |
| 3 | ch.vue.forms-vmodel | 表单、v-model、修饰符与校验边界 | 框架 | ch.vue.template-directives、ch.web.forms-validation |
| 4 | ch.vue.reactivity | ref、reactive、computed 与响应式边界 | 框架 | ch.vue.vite-sfc、ch.js.collections |
| 5 | ch.vue.effects-lifecycle | watch、effect、生命周期与副作用清理 | 框架 | ch.vue.reactivity、ch.js.event-loop |
| 6 | ch.vue.components-contracts | Props、事件、Slot 与组件 v-model | 框架 | ch.vue.template-directives、ch.vue.forms-vmodel、ch.vue.reactivity |
| 7 | ch.vue.composables-di | Composable、依赖注入与模块边界 | 框架 | ch.vue.effects-lifecycle、ch.vue.components-contracts |
| 8 | ch.vue.router-navigation | Router、导航、布局与页面边界 | 框架 | ch.vue.components-contracts |
| 9 | ch.vue.pinia-state | Pinia 与客户端状态所有权 | 框架 | ch.vue.reactivity、ch.vue.components-contracts |
| 10 | ch.vue.server-state | 服务端状态、加载、错误、取消与竞态 | 框架 | ch.vue.effects-lifecycle、ch.vue.pinia-state、ch.js.fetch-cancellation-race |
| 11 | ch.vue.auth-permissions | 登录态、路由保护、权限 UI 与安全边界 | 框架 | ch.vue.router-navigation、ch.vue.server-state、SEC-AUTH、SEC-RBAC |
| 12 | ch.vue.component-testing | 组件测试、Mock、异步断言与端到端边界 | 框架 | ch.vue.components-contracts、ch.vue.server-state、ch.js.testing-debugging |
| 13 | ch.vue.accessibility | Vue 组件无障碍、焦点恢复与动态提示 | 框架 | ch.vue.components-contracts、ch.web.accessibility-interaction |
| 14 | ch.vue.performance | 渲染分析、懒加载、错误恢复与性能预算 | 框架 | ch.vue.effects-lifecycle、ch.vue.server-state、ch.vue.component-testing |
| 15 | ch.nuxt.rendering-hydration | Nuxt SSR、SSG、水合与服务端数据获取 | 框架 | ch.vue.components-contracts、ch.js.event-loop、F-HTTP |

Nuxt 基础不硬依赖完整认证和请求竞态；生产部署进入卷 15。

### 4.4 卷 10：小程序与 uni-app，共 12 章

| 顺序 | ID | 标题 | 角色 | 关键硬前置 |
| ---: | --- | --- | --- | --- |
| 1 | ch.miniapp.runtime | 小程序运行模型、配置、生命周期与宿主边界 | 首教 | F-SHELL |
| 2 | ch.uniapp.toolchain-pages | uni-app 工具链、页面、路由与项目结构 | 平台 | ch.miniapp.runtime、ch.vue.vite-sfc |
| 3 | ch.uniapp.template-components | uni-app 模板、组件、表单与 Vue 差异 | 平台 | ch.uniapp.toolchain-pages、ch.vue.template-directives、ch.vue.forms-vmodel |
| 4 | ch.uniapp.network-auth-storage | 网络、认证、存储与多环境配置 | 平台 | ch.uniapp.toolchain-pages、F-HTTP、SEC-AUTH、SEC-WEB |
| 5 | ch.uniapp.platform-conditional | 平台 API、条件编译与能力检测 | 平台 | ch.uniapp.toolchain-pages |
| 6 | ch.uniapp.device-capabilities | 上传、扫码、定位、权限与失败路径 | 平台 | ch.uniapp.template-components、ch.uniapp.network-auth-storage、ch.uniapp.platform-conditional |
| 7 | ch.uniapp.testing-debugging | 单元/组件测试、Mock、真机和网络调试 | 平台 | ch.uniapp.template-components、ch.uniapp.network-auth-storage、ch.js.testing-debugging |
| 8 | ch.uniapp.packages-performance | 分包、启动性能、缓存与资源预算 | 平台 | ch.uniapp.toolchain-pages、ch.uniapp.testing-debugging |
| 9 | ch.uniapp.offline-idempotency | 离线队列、重试、冲突与幂等重放 | 平台 | ch.uniapp.network-auth-storage、ch.uniapp.packages-performance、STATE-IDEMP |
| 10 | ch.uniapp.privacy-review | 隐私、安全、平台声明与审核证据 | 平台 | ch.uniapp.device-capabilities、ch.uniapp.testing-debugging、SEC-WEB |
| 11 | ch.uniapp.release-monitoring | 构建、版本、灰度、发布与监控 | 平台 | ch.uniapp.testing-debugging、ch.uniapp.packages-performance、ch.uniapp.privacy-review |
| 12 | ch.uniapp.factorycare-reporter | FactoryCare 报修端集成与验收 | 门禁 | ch.uniapp.device-capabilities、ch.uniapp.offline-idempotency、ch.uniapp.release-monitoring、ch.vue.server-state |

小程序运行模型不依赖 Vue；Vue 从 uni-app 工具链章开始。

### 4.5 卷 11：Dart 与 Flutter，共 19 章

| 顺序 | ID | 标题 | 角色 | 关键硬前置 |
| ---: | --- | --- | --- | --- |
| 1 | ch.dart.toolchain | Dart SDK、CLI、pubspec 与包工具 | 首教 | F-SHELL、F-ENV |
| 2 | ch.dart.types-null-safety | 变量、类型、运算符与空安全 | 首教 | ch.dart.toolchain |
| 3 | ch.dart.control-functions | 条件、循环、函数、参数与返回值 | 首教 | ch.dart.types-null-safety |
| 4 | ch.dart.collections-patterns | List、Map、Set、record、模式与解构 | 首教 | ch.dart.control-functions |
| 5 | ch.dart.oop-generics | 类、泛型、mixin、extension 与对象边界 | 首教 | ch.dart.types-null-safety、ch.dart.collections-patterns |
| 6 | ch.dart.exceptions-resources | 异常、资源所有权与错误建模 | 首教 | ch.dart.control-functions、ch.dart.oop-generics |
| 7 | ch.dart.future-cancellation | Future、async/await、超时与取消协议 | 首教 | ch.dart.control-functions、ch.dart.exceptions-resources |
| 8 | ch.dart.streams-isolates | Stream、背压边界、Isolate 与并发 | 首教 | ch.dart.collections-patterns、ch.dart.future-cancellation |
| 9 | ch.dart.testing-lints | Dart test、断言、Mock、lint 与包质量 | 语言 | ch.dart.control-functions、ch.dart.oop-generics、ch.dart.exceptions-resources、F-TEST |
| 10 | ch.flutter.toolchain-project | Flutter SDK、项目结构、run、hot reload 与 DevTools | 框架 | ch.dart.toolchain、ch.dart.oop-generics |
| 11 | ch.flutter.widget-tree | MaterialApp、基础 Widget、Widget 树与 BuildContext | 框架 | ch.flutter.toolchain-project、ch.dart.oop-generics |
| 12 | ch.flutter.layout-accessibility | 约束布局、响应式、渲染与无障碍 | 框架 | ch.flutter.widget-tree |
| 13 | ch.flutter.state-lifecycle | 状态、生命周期、mounted、Key 与异步更新 | 框架 | ch.flutter.widget-tree、ch.dart.future-cancellation |
| 14 | ch.flutter.navigation-forms | 导航、路由、表单与页面契约 | 框架 | ch.flutter.layout-accessibility、ch.flutter.state-lifecycle |
| 15 | ch.flutter.architecture-state | 状态管理、模块边界与依赖方向 | 框架 | ch.flutter.state-lifecycle、ch.flutter.navigation-forms |
| 16 | ch.flutter.network-storage-offline | 网络取消、安全存储、缓存与离线队列 | 框架 | ch.dart.future-cancellation、ch.flutter.state-lifecycle、F-HTTP、STATE-IDEMP |
| 17 | ch.flutter.device-apis | 相机、扫码、定位、权限与平台通道 | 平台 | ch.flutter.state-lifecycle、ch.flutter.network-storage-offline |
| 18 | ch.flutter.testing-performance | Widget/集成/Golden 测试、性能与内存分析 | 框架 | ch.dart.testing-lints、ch.flutter.navigation-forms、ch.flutter.architecture-state |
| 19 | ch.flutter.release-monitoring | 构建、签名、发布、符号与崩溃监控 | 平台 | ch.flutter.toolchain-project、ch.flutter.testing-performance |

通用 Flutter 测试和发布不硬依赖全部设备 API。

### 4.6 卷 12：Python、FastAPI 与数据工具，共 19 章

| 顺序 | ID | 标题 | 角色 | 关键硬前置 |
| ---: | --- | --- | --- | --- |
| 1 | ch.python.runtime-uv | Python 运行时、uv、虚拟环境与依赖 | 首教 | F-SHELL、F-ENV |
| 2 | ch.python.syntax-values-io | 语句、变量、对象、表达式与基础输入输出 | 首教 | ch.python.runtime-uv |
| 3 | ch.python.control-flow | 条件、循环与控制转移 | 首教 | ch.python.syntax-values-io |
| 4 | ch.python.functions-scope | 函数、参数、返回值与作用域 | 首教 | ch.python.control-flow |
| 5 | ch.python.collections | list、tuple、dict、set 与推导式 | 首教 | ch.python.control-flow、ch.python.functions-scope |
| 6 | ch.python.typing-foundations | 基础类型标注、联合、容器类型与类型检查器 | 首教 | ch.python.syntax-values-io、ch.python.functions-scope |
| 7 | ch.python.modules-packages | 模块、包、导入与项目布局 | 首教 | ch.python.functions-scope、ch.python.typing-foundations |
| 8 | ch.python.files-json-time | Path、编码、文件、JSON 与时间数据 | 首教 | ch.python.modules-packages、ch.python.functions-scope |
| 9 | ch.python.classes-dataclass | 类、对象模型、dataclass 与 enum | 首教 | ch.python.functions-scope、ch.python.typing-foundations |
| 10 | ch.python.protocol-generics | 泛型、Protocol、Callable 与结构类型 | 首教 | ch.python.typing-foundations、ch.python.classes-dataclass |
| 11 | ch.python.exceptions-context | 异常、上下文管理器与资源清理 | 首教 | ch.python.functions-scope、ch.python.classes-dataclass |
| 12 | ch.python.iterators-decorators | 迭代器、生成器、惰性计算与装饰器 | 首教 | ch.python.functions-scope、ch.python.collections、ch.python.exceptions-context |
| 13 | ch.python.testing-logging-debug | pytest、fixture、Mock、日志与调试证据 | 语言 | ch.python.functions-scope、ch.python.exceptions-context、F-TEST |
| 14 | ch.python.asyncio-cancellation | asyncio、Task、超时、取消与结构化并发边界 | 首教 | ch.python.functions-scope、ch.python.exceptions-context |
| 15 | ch.python.pydantic-validation | Pydantic 模型、校验、序列化与错误 | 框架 | ch.python.typing-foundations、ch.python.classes-dataclass、ch.python.exceptions-context |
| 16 | ch.fastapi.web-foundations | FastAPI 路由、依赖、请求响应与错误 | 框架 | ch.python.modules-packages、ch.python.exceptions-context、ch.python.pydantic-validation、F-HTTP |
| 17 | ch.fastapi.security-testing-openapi | FastAPI 安全集成、测试与 OpenAPI 合同 | 框架 | ch.python.testing-logging-debug、ch.python.asyncio-cancellation、ch.fastapi.web-foundations、SEC-AUTH、SEC-WEB |
| 18 | ch.data.numpy | NumPy 数组、形状、广播与向量化 | 框架 | ch.python.collections |
| 19 | ch.data.pandas | Pandas 表格、缺失值、连接与数据清洗 | 框架 | ch.python.files-json-time、ch.data.numpy |

Protocol 位于 typing 与类型检查器之后；健壮 CLI 实验位于异常和测试之后。

### 4.7 卷 13：数学、机器学习与 PyTorch，共 16 章

| 顺序 | ID | 标题 | 角色 | 关键硬前置 |
| ---: | --- | --- | --- | --- |
| 1 | ch.math.algebra-units | 算术、比例、单位、代数式与方程 | 首教 | 无 |
| 2 | ch.math.functions-graphs | 函数、坐标、图像、斜率、指数、对数与求和 | 首教 | ch.math.algebra-units |
| 3 | ch.math.linear-algebra | 向量、矩阵、张量、形状与运算 | 首教 | ch.math.algebra-units、ch.math.functions-graphs |
| 4 | ch.math.probability-statistics | 概率、统计、分布、期望与方差 | 首教 | ch.math.algebra-units、ch.math.functions-graphs |
| 5 | ch.math.gradients | 导数、梯度、链式法则与优化 | 首教 | ch.math.functions-graphs、ch.math.linear-algebra |
| 6 | ch.ml.problem-data-split | 问题定义、数据集、划分与数据泄漏 | 首教 | ch.math.probability-statistics、ch.data.pandas |
| 7 | ch.ml.preprocessing-features | 清洗、编码、缩放、特征与 Pipeline | 首教 | ch.ml.problem-data-split、ch.data.pandas |
| 8 | ch.ml.supervised-learning | 回归、分类与决策边界 | 首教 | ch.math.linear-algebra、ch.math.probability-statistics、ch.ml.preprocessing-features |
| 9 | ch.ml.unsupervised-learning | 聚类、降维与无监督结果边界 | 首教 | ch.math.linear-algebra、ch.math.probability-statistics、ch.ml.preprocessing-features |
| 10 | ch.ml.metrics-validation | 指标、基线、交叉验证与误差分析 | 首教 | ch.math.probability-statistics、ch.ml.problem-data-split、ch.ml.supervised-learning |
| 11 | ch.ml.neural-networks | 神经网络、损失、反向传播与优化器 | 首教 | ch.math.linear-algebra、ch.math.probability-statistics、ch.math.gradients |
| 12 | ch.ml.attention-sequences | Softmax、序列表示、注意力与 Transformer 桥接 | 首教 | ch.math.functions-graphs、ch.math.linear-algebra、ch.ml.neural-networks |
| 13 | ch.pytorch.foundations | Tensor、Dataset、Module 与 Autograd | 框架 | ch.ml.neural-networks、ch.python.classes-dataclass、ch.data.numpy |
| 14 | ch.pytorch.training | 训练循环、复现、过拟合、评估与调参 | 框架 | ch.ml.metrics-validation、ch.ml.neural-networks、ch.pytorch.foundations |
| 15 | ch.pytorch.inference | 保存、加载、推理、批处理与服务边界 | 框架 | ch.pytorch.foundations、ch.pytorch.training |
| 16 | ch.ml.monitoring-ethics | 漂移、监控、公平性、伦理与使用边界 | 生产 | ch.ml.metrics-validation、ch.pytorch.inference |

PyTorch 可训练模型必须硬依赖神经网络；神经网络只依赖数学桥，不强制先完成全部经典 ML。

### 4.8 卷 14：LLM、信息检索、RAG 与 Agent，共 16 章

| 顺序 | ID | 标题 | 角色 | 关键硬前置 |
| ---: | --- | --- | --- | --- |
| 1 | ch.llm.model-foundations | Transformer、Token、上下文与 Embedding 心智模型 | 首教 | ch.ml.attention-sequences、ch.python.functions-scope |
| 2 | ch.llm.api-prompts-cost | 模型 API、消息、提示、Token 与成本 | 框架 | ch.llm.model-foundations、ch.python.functions-scope、F-HTTP |
| 3 | ch.llm.structured-output | 结构化输出、Schema 与运行时校验 | 框架 | ch.llm.api-prompts-cost、ch.python.pydantic-validation |
| 4 | ch.llm.streaming-resilience | 流式输出、重试、超时、取消与降级 | 框架 | ch.llm.api-prompts-cost、ch.python.asyncio-cancellation |
| 5 | ch.llm.tool-calling | 工具调用、参数验证与信任边界 | 框架 | ch.llm.structured-output、ch.llm.streaming-resilience、SEC-WEB |
| 6 | ch.rag.ingestion-metadata | 文档解析、清洗、权限元数据与可追溯性 | 首教 | ch.python.files-json-time、ch.llm.api-prompts-cost |
| 7 | ch.rag.chunking-embeddings | 分块、Embedding、批处理与语料管线 | 首教 | ch.llm.model-foundations、ch.llm.api-prompts-cost、ch.rag.ingestion-metadata |
| 8 | ch.ir.lexical-retrieval | 词项、倒排索引、TF-IDF 与 BM25 | 首教 | ch.python.collections、ch.math.functions-graphs |
| 9 | ch.ir.evaluation | 固定查询集、相关性标签、Precision、Recall 与排序指标 | 首教 | ch.ir.lexical-retrieval、ch.math.probability-statistics |
| 10 | ch.ir.dense-pgvector | 向量检索、pgvector、索引与距离 | 框架 | ch.rag.chunking-embeddings、ch.math.linear-algebra、DB-REL、DB-INDEX |
| 11 | ch.ir.hybrid-rerank | 稀疏/稠密混合检索、候选融合与重排 | 框架 | ch.ir.lexical-retrieval、ch.ir.evaluation、ch.ir.dense-pgvector |
| 12 | ch.rag.citations-evaluation | RAG 生成、引用、测试集与端到端评估 | 框架 | ch.llm.structured-output、ch.ir.evaluation、ch.ir.hybrid-rerank |
| 13 | ch.rag.security-observability | 提示注入、ACL、PII、日志与可观测性 | 生产 | ch.llm.tool-calling、ch.rag.citations-evaluation、SEC-RBAC |
| 14 | ch.agent.langchain | LangChain 组件、直接 SDK 对照与边界 | 框架 | ch.llm.structured-output、ch.llm.streaming-resilience、ch.rag.citations-evaluation |
| 15 | ch.agent.langgraph | LangGraph 状态、检查点、恢复与人工审批 | 框架 | ch.llm.tool-calling、ch.agent.langchain、ch.python.asyncio-cancellation |
| 16 | ch.agent.mcp-boundaries | MCP、Agent 模式/反模式与 Java/Python 职责边界 | 框架 | ch.llm.tool-calling、ch.agent.langgraph |

模型 API 不硬依赖 FastAPI；MCP 不硬依赖 Spring Security。Java/Spring 生产集成属于实验前置。

### 4.9 卷 15：生产化、发布与作品表达，共 17 章

| 顺序 | ID | 标题 | 角色 | 关键硬前置 |
| ---: | --- | --- | --- | --- |
| 1 | ch.ops.linux-services | Linux 用户、文件、权限、进程与服务 | 生产 | F-FILES、F-SHELL |
| 2 | ch.ops.network-diagnostics | DNS、端口、代理、TCP、TLS 与网络诊断 | 生产 | ch.ops.linux-services、F-HTTP |
| 3 | ch.ops.docker-production | 镜像层、容器、卷、网络与运行时边界 | 生产 | ch.ops.linux-services、F-DOCKER |
| 4 | ch.ops.compose-services | Compose 多服务、配置、健康检查与依赖 | 生产 | ch.ops.docker-production |
| 5 | ch.ops.nginx-tls | Nginx、TLS、反向代理与静态资源 | 生产 | ch.ops.network-diagnostics、ch.ops.compose-services |
| 6 | ch.release.ci-quality | CI 流水线、测试门禁与失败证据 | 生产 | F-GIT、F-DEPS、F-TEST |
| 7 | ch.release.artifacts-promotion | 制品、来源证明、环境晋级与发布元数据 | 生产 | ch.ops.docker-production、ch.release.ci-quality |
| 8 | ch.ops.config-secrets-supply-chain | 配置、密钥、依赖、SBOM 与供应链 | 生产 | ch.ops.docker-production、ch.release.ci-quality、SEC-WEB |
| 9 | ch.ops.logs-health | 结构化日志、关联 ID 与健康检查 | 生产 | ch.ops.compose-services、BACKEND-OBS |
| 10 | ch.ops.metrics-traces-slo | 指标、链路、SLI/SLO、告警与噪声 | 生产 | ch.ops.logs-health |
| 11 | ch.ops.backup-recovery | 备份、恢复、RPO/RTO 与恢复演练 | 生产 | ch.ops.compose-services、DB-TX |
| 12 | ch.ops.capacity-performance | 容量、负载模型、性能测试与瓶颈证据 | 生产 | ch.ops.metrics-traces-slo、ch.ops.backup-recovery、DB-INDEX |
| 13 | ch.release.deployment-migrations | 部署、expand-contract、前向修复与回滚 | 生产 | ch.ops.nginx-tls、ch.release.artifacts-promotion、ch.ops.backup-recovery、DB-MIGRATION |
| 14 | ch.ops.incident-dr | 事故响应、灾难恢复、复盘与改进闭环 | 生产 | ch.ops.metrics-traces-slo、ch.ops.backup-recovery、ch.release.deployment-migrations |
| 15 | ch.architecture.system-design | 需求、边界、容量、可靠性与系统设计取舍 | 生产 | ch.ops.metrics-traces-slo、ch.ops.capacity-performance、BACKEND-OBS |
| 16 | ch.release.factorycare-acceptance | FactoryCare 端到端验收与可回滚发布 | 门禁 | ch.ops.incident-dr、ch.architecture.system-design |
| 17 | ch.portfolio.interview | 作品集、技术表达、岗位映射与面试复盘 | 门禁 | ch.release.factorycare-acceptance、AI 协作验证 canonical teacher |

FactoryCare 验收的 Vue、uni-app、Flutter、AI 等要求进入 FactoryCare 路线或 G8 的 completion_requires，不进入通用系统设计硬依赖。

## 5. 旧 ID 迁移映射

### 5.1 卷 07

- v07.c01.browser-render-devtools → ch.web.browser-render-devtools；修复阻塞/强制重排迁到 ch.js.browser-performance。
- v07.c02.semantic-html → ch.web.semantic-html。
- v07.c03.forms-media-validation → ch.web.forms-validation、ch.web.media-assets。
- v07.c04.accessibility → ch.web.accessibility-interaction。
- v07.c05.css-cascade → ch.css.cascade。
- v07.c06.box-position-stacking → ch.css.box-position。
- v07.c07.flex-grid → ch.css.flexbox、ch.css.grid。
- v07.c08.responsive-typography → ch.css.responsive-typography。
- v07.c09.color-theme-variables → ch.css.theme-variables。
- v07.c10.motion-performance → ch.css.motion-compositing、ch.js.browser-performance。
- 新增缺口：ch.web.origin-cookie-cache。

### 5.2 卷 08

- v08.c01.runtime-node-pnpm-esm → ch.js.runtime-esm。
- v08.c02.values-types-equality → ch.js.statements-variables、ch.js.values-operators；测试部分迁到 ch.js.testing-debugging。
- v08.c03.scope-functions-closures → ch.js.control-flow、ch.js.functions、ch.js.scope-closures。
- v08.c04.arrays-objects-collections → ch.js.collections。
- v08.c05.this-prototype-class-module → ch.js.object-model；ESM 留在 runtime。
- v08.c06.dom-events-storage → ch.js.dom-mutation、ch.js.events-forms；浏览器存储模型并入 ch.web.origin-cookie-cache。
- v08.c07.event-loop-promises → ch.js.event-loop。
- v08.c08.fetch-abort-race → ch.js.fetch-cancellation-race。
- v08.c09.typescript-setup-strict → ch.ts.foundations、ch.ts.modeling-narrowing。
- v08.c10.typescript-advanced-tooling → ch.ts.generics-utilities、ch.ts.runtime-boundaries；测试部分迁到 JS 测试章。

### 5.3 卷 09

- v09.c01.vite-sfc-app → ch.vue.vite-sfc。
- v09.c02.reactivity → ch.vue.reactivity。
- v09.c03.watch-lifecycle-cleanup → ch.vue.effects-lifecycle。
- v09.c04.components-contracts → ch.vue.components-contracts。
- v09.c05.composables-boundaries → ch.vue.composables-di。
- v09.c06.router-navigation-auth → ch.vue.router-navigation、ch.vue.auth-permissions。
- v09.c07.pinia-server-state-forms → ch.vue.forms-vmodel、ch.vue.pinia-state、ch.vue.server-state。
- v09.c08.requests-race-errors → ch.vue.server-state。
- v09.c09.testing-a11y-performance → ch.vue.component-testing、ch.vue.accessibility、ch.vue.performance。
- v09.c10.nuxt-rendering-deployment → ch.nuxt.rendering-hydration；部署部分迁到卷 15。
- 新增缺口：ch.vue.template-directives。

### 5.4 卷 10

- v10.c01.miniprogram-runtime → ch.miniapp.runtime。
- v10.c02.uniapp-vue-pages → ch.uniapp.toolchain-pages、ch.uniapp.template-components。
- v10.c03.network-auth-storage → ch.uniapp.network-auth-storage。
- v10.c04.platform-api-conditional → ch.uniapp.platform-conditional。
- v10.c05.upload-scan-location → ch.uniapp.device-capabilities。
- v10.c06.packages-performance-offline → ch.uniapp.packages-performance、ch.uniapp.offline-idempotency。
- v10.c07.testing-device-debug → ch.uniapp.testing-debugging。
- v10.c08.privacy-security-review → ch.uniapp.privacy-review。
- v10.c09.publish-monitoring → ch.uniapp.release-monitoring。
- v10.c10.factorycare-reporter → ch.uniapp.factorycare-reporter。

### 5.5 卷 11

- v11.c01.dart-cli-types → ch.dart.toolchain、ch.dart.types-null-safety。
- v11.c02.dart-control-functions → ch.dart.control-functions；集合过滤迁到集合章。
- v11.c03.dart-collections-patterns → ch.dart.collections-patterns。
- v11.c04.dart-oop-generics → ch.dart.oop-generics。
- v11.c05.dart-async-errors → ch.dart.exceptions-resources、ch.dart.future-cancellation、ch.dart.streams-isolates。
- v11.c06.flutter-runtime → ch.flutter.toolchain-project、ch.flutter.widget-tree。
- v11.c07.layout-render-accessibility → ch.flutter.layout-accessibility。
- v11.c08.state-lifecycle-mounted → ch.flutter.state-lifecycle。
- v11.c09.navigation-network-device → ch.flutter.navigation-forms；网络与设备分别迁入对应章节。
- v11.c10.architecture-testing-release → ch.flutter.architecture-state；测试和发布拆出。
- v11.c11.flutter-network-storage → ch.flutter.network-storage-offline。
- v11.c12.flutter-device-apis → ch.flutter.device-apis。
- v11.c13.flutter-testing-performance-release → ch.flutter.testing-performance、ch.flutter.release-monitoring。
- 新增缺口：ch.dart.testing-lints。

### 5.6 卷 12

- v12.c01.runtime-uv-env → ch.python.runtime-uv。
- v12.c02.types-io-control → ch.python.syntax-values-io、ch.python.control-flow。
- v12.c03.functions-collections → ch.python.functions-scope、ch.python.collections。
- v12.c04.modules-files-json → ch.python.modules-packages、ch.python.files-json-time。
- v12.c05.classes-dataclass-protocol → ch.python.classes-dataclass、ch.python.protocol-generics。
- v12.c06.exceptions-iterators-decorators → ch.python.exceptions-context、ch.python.iterators-decorators。
- v12.c07.typing-testing-logging → ch.python.typing-foundations、ch.python.testing-logging-debug。
- v12.c08.async-cancellation → ch.python.asyncio-cancellation。
- v12.c09.fastapi-pydantic → ch.python.pydantic-validation、ch.fastapi.web-foundations、ch.fastapi.security-testing-openapi。
- v12.c10.numpy-pandas → ch.data.numpy、ch.data.pandas。

### 5.7 卷 13

- v13.c01.vectors-matrices-tensors → ch.math.linear-algebra。
- v13.c02.probability-statistics → ch.math.probability-statistics。
- v13.c03.derivatives-gradients → ch.math.gradients。
- v13.c04.problem-data-split → ch.ml.problem-data-split。
- v13.c05.classical-ml → ch.ml.preprocessing-features、ch.ml.supervised-learning、ch.ml.unsupervised-learning。
- v13.c06.metrics-validation → ch.ml.metrics-validation。
- v13.c07.neural-networks → ch.ml.neural-networks。
- v13.c08.pytorch-foundations → ch.pytorch.foundations。
- v13.c09.training-evaluation → ch.pytorch.training。
- v13.c10.inference-monitoring-ethics → ch.pytorch.inference、ch.ml.monitoring-ethics。
- 新增数学桥：ch.math.algebra-units、ch.math.functions-graphs。
- 新增 LLM 桥：ch.ml.attention-sequences。

### 5.8 卷 14

- v14.c01.llm-model → ch.llm.model-foundations。
- v14.c02.model-api-prompts → ch.llm.api-prompts-cost。
- v14.c03.structured-stream-retry → ch.llm.structured-output、ch.llm.streaming-resilience。
- v14.c04.tool-calling-boundaries → ch.llm.tool-calling。
- v14.c05.ingestion-chunking → ch.rag.ingestion-metadata、ch.rag.chunking-embeddings。
- v14.c06.retrieval-rerank → ch.ir.lexical-retrieval、ch.ir.evaluation、ch.ir.dense-pgvector、ch.ir.hybrid-rerank。
- v14.c07.rag-citations-evaluation → ch.rag.citations-evaluation。
- v14.c08.rag-security-observability → ch.rag.security-observability。
- v14.c09.langchain-langgraph → ch.agent.langchain、ch.agent.langgraph。
- v14.c10.mcp-agent-boundary → ch.agent.mcp-boundaries。

### 5.9 卷 15

- v15.c01.linux-operations → ch.ops.linux-services。
- v15.c02.network-diagnostics → ch.ops.network-diagnostics。
- v15.c03.docker-compose → ch.ops.docker-production、ch.ops.compose-services。
- v15.c04.nginx-tls-proxy → ch.ops.nginx-tls。
- v15.c05.ci-quality-artifacts → ch.release.ci-quality、ch.release.artifacts-promotion。
- v15.c06.config-secrets-supply-chain → ch.ops.config-secrets-supply-chain。
- v15.c07.logs-metrics-traces → ch.ops.logs-health、ch.ops.metrics-traces-slo。
- v15.c08.backup-capacity-performance → ch.ops.backup-recovery、ch.ops.capacity-performance。
- v15.c09.deployment-rollback-incident → ch.release.deployment-migrations、ch.ops.incident-dr。
- v15.c10.system-design-portfolio → ch.architecture.system-design、ch.release.factorycare-acceptance。
- v15.c11.portfolio-interview → ch.portfolio.interview。

## 6. 机器验证规则

### 6.1 目录与 ID

1. 全书章数目标改为 230..260；单卷允许 8..20，不能保留旧 140..170 上限。
2. ID 改为稳定语义格式：

   ~~~text
   \Ach\.[a-z0-9-]+\.[a-z0-9-]+\z
   ~~~

3. volume 与 order 独立；每卷 order 连续且 catalog 按 volume、order 排序。
4. 迁移账本必须覆盖全部 94 个卷 07—15 旧 ID；每个新 ID 必须声明 origin: migrated 或 origin: new。
5. 一对多迁移必须指定 primary_new_id 和 reason。
6. 旧 ID 不得残留在 catalog、routes、gates、source mappings、front matter 或生成物中。

### 6.2 教学语义

每章新增并校验：

~~~yaml
instructional_role:
primary_responsibility:
concepts_taught:
concepts_assumed:
concepts_practiced:
prerequisite_rationales:
lab_prerequisites:
completion_gate_requires:
verification_mode:
~~~

规则：

1. concepts_assumed 必须是硬前置闭包中 concepts_taught 的子集。
2. concepts_practiced 必须指向唯一 canonical teacher。
3. 基础概念只能有一个 first-teach canonical teacher。
4. framework-practice、platform-adaptation 和 production-deepening 不能重新声明基础概念为首教。
5. outcome 使用的概念必须来自本章 concepts_taught 或硬前置闭包。
6. 每章只能有一个主要责任，最多一个紧密关联的次级认知簇。
7. 非门禁章直接硬前置建议不超过 4 个；超过时必须逐边给出 rationale。
8. 冗余传递硬边至少产生警告，防止重新形成机械单链。
9. lab_prerequisites 只约束具体实验，不能被用来证明章节 outcome 已有前置。
10. completion_gate_requires 只用于路线或阶段门，不能进入通用 DAG。

### 6.3 测试顺序

首次要求自动化测试前，硬闭包必须包含 F-TEST，并声明：

~~~yaml
verification_mode: manual-oracle | builtin-assert | unit-framework | integration | e2e
~~~

目录中的“测试”不得继续含糊地混用手算、main 内 assert、单元测试框架和端到端测试。

### 6.4 强制语义边与反过度依赖

必须满足：

- ch.vue.vite-sfc 依赖 TypeScript 基础，但不得硬依赖 TS 高级类型或运行时 Schema。
- ch.vue.auth-permissions 依赖认证和 RBAC 模型。
- ch.uniapp.offline-idempotency 与 ch.flutter.network-storage-offline 依赖 STATE-IDEMP。
- ch.flutter.state-lifecycle 依赖 ch.dart.future-cancellation。
- ch.pytorch.foundations 依赖 ch.ml.neural-networks。
- ch.llm.model-foundations 依赖 ch.ml.attention-sequences。
- ch.ir.dense-pgvector 依赖关系模型、数据库索引和线性代数。
- ch.ir.hybrid-rerank 依赖 IR 基础、IR 评估和 dense retrieval。
- ch.architecture.system-design 不得硬依赖 uni-app、Flutter 或 Agent。
- ch.release.factorycare-acceptance 的多客户端/AI要求只能位于路线门禁。

### 6.5 路线、门禁与来源

1. 零基础路线完整覆盖所有新章，并满足硬前置顺序。
2. accelerated-48 仍为 48 个模块，一个模块可组合多个连续的小章。
3. FactoryCare 路线使用 completion_gate_requires 表达多客户端和 AI 产物。
4. reference 路线收录全部新 ID，但保持非线性。
5. G4—G8 原子迁移到新 ID，不得保留未知章节引用。
6. 一对多 source mapping 不得自动复制成 reviewed；必须标记 needs-reclassification，并继续保持 unreviewed。

### 6.6 必须增加的负向回归

- JS 测试章删除 F-TEST 后失败。
- Vue 入门重新依赖 TS advanced 后失败。
- Flutter state 删除 Future 前置后失败。
- PyTorch foundations 删除 neural-networks 前置后失败。
- LLM foundations 删除 attention 前置后失败。
- RAG hybrid 在 IR evaluation 前出现后失败。
- system-design 硬依赖 Flutter 或 Agent 后失败。
- 一对多旧 ID 未进入迁移账本后失败。
- routes、gates 或 source mappings 残留旧 ID 后失败。
- lab_prerequisites 被错误当作 chapter prerequisite 后失败。
- completion_gate_requires 被写入全局硬 DAG 后失败。

## 7. 可合并但非默认的候选

只有联合目录超过预算时才讨论以下压缩：

| 候选 | 可节省 | 代价 |
| --- | ---: | --- |
| ch.js.dom-mutation + ch.js.events-forms | 1 | DOM 状态和事件流认知同时出现 |
| ch.vue.accessibility + ch.vue.performance | 1 | 必须保留两个独立实验与验收 |
| ch.uniapp.testing-debugging + ch.uniapp.packages-performance | 1 | 测试顺序和性能诊断容易再次过载 |
| ch.dart.exceptions-resources + ch.dart.future-cancellation | 1 | 异常与异步取消边界变得拥挤 |
| ch.ml.supervised-learning + ch.ml.unsupervised-learning | 1 | 经典 ML 跨度增大 |
| ch.rag.ingestion-metadata + ch.rag.chunking-embeddings | 1 | 文档语义与向量管线重新耦合 |
| ch.release.ci-quality + ch.release.artifacts-promotion | 1 | 测试门禁与制品晋级责任混合 |

不建议合并：

- JavaScript 语句、控制流、函数。
- TypeScript 基础、收窄、高级类型。
- Vue 模板、响应式、组件。
- Flutter 工具链、Widget、生命周期。
- Python typing 与 Protocol。
- 数学桥、线性代数、概率、梯度。
- IR 基础、IR 评估、向量检索。
- 通用系统设计、FactoryCare 验收、作品表达。

## 8. 实施影响、迁移与回滚

### 8.1 受影响范围

- curriculum/catalog.yml
- curriculum/validate_catalog.rb
- curriculum/routes/*.yml
- curriculum/gates.yml
- book/volume-07 至 volume-15
- schemas/chapter.schema.json
- scripts/validate-encyclopedia.rb
- scripts/build-book.rb
- tests/curriculum 与 tests/encyclopedia
- sources/mappings.csv 及来源生成器
- 生成的 publication manifest、目录、导航和搜索索引

### 8.2 推荐迁移顺序

1. 冻结当前 P1/P2 基线和旧 ID 清单。
2. 先落迁移账本和新 ID schema。
3. 原子生成新 catalog、占位章节与卷 README。
4. 通过迁移账本重写 routes、gates 和 source mappings。
5. 加入概念首教/实践字段和语义负例。
6. 更新 P2 schema、manifest 输入和生成物。
7. 运行所有目录、来源、百科和生成检查。
8. 确认 PROGRESS.md 零差异后再提交。

### 8.3 回滚

- 在迁移前保留独立 Git 提交。
- 迁移只在所有旧引用可由账本解析、所有验证同时通过后提交。
- 失败时整体回退该迁移提交；不保留双 ID、兼容 alias 或半迁移 routes。

## 9. 完成标准

- 卷 07—15 恰为 145 章，分卷数为 13、18、15、12、19、19、16、16、17。
- 联合目录总章数位于 230—260。
- 全部旧 ID 可追溯，无运行时兼容 alias。
- DAG 无环，零基础路线完整，隐藏首用为 0。
- 框架章的 concepts_practiced 均可到达 canonical teacher。
- G4—G8、四条路线和 source mappings 完成原子迁移。
- P1、P2、来源清单、生成物检查和新增语义负例全部通过。
- 全部章节仍为 planned；没有把占位、文件存在或测试通过当成正文完成。
- PROGRESS.md 零差异。

## 10. 明确非目标

- 不在本批编写教材正文、示例、实验、练习或答案。
- 不联网核验具体软件版本或外链。
- 不修改学习周次、分数、小时、阶段门状态或求职进度。
- 不保留旧 ID 兼容层。
- 不因为目录结构通过而声称学习者已经掌握相关技术。
