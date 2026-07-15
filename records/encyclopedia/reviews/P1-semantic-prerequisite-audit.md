# P1 教学语义前置审计

- 审计对象：`curriculum/catalog.yml`
- 审计日期：2026-07-16
- 审计范围：16 卷、170 章的标题、outcomes、硬前置、推荐顺序、卷内顺序与跨卷语义依赖
- 审计视角：真正零基础读者
- 审计结论：**FAIL**

## 1. 总体结论

本次逐章读取了 `curriculum/catalog.yml` 的 170 章，没有仅依赖 `teaches_capabilities` 或 `uses_capabilities` 数字进行判断。

当前目录对有经验开发者可以作为知识地图，但还不能作为“真正零基础学习合同”。即使严格按卷顺序阅读，也有章节要求读者独立完成尚未学过的语法、数据结构、测试方法或框架操作；如果允许按硬依赖图跳读，问题会更严重。

卷 01 必须结构性重构，不能只补几个 `prerequisites`。卷 00、卷 05—06、卷 08—09、卷 11—14 也存在需要优先处理的语义断层。

## 2. 审计方法与证据边界

本次检查包括：

1. 逐章读取标题和三个 outcomes，识别完成 outcome 实际需要的语言语法、运行模型、数据结构、工具和工程动作。
2. 检查这些隐性概念是否已在本章之前真实教授，而不是只看 capability 名称是否出现。
3. 对重点问题查询硬依赖祖先，确认所需章节是否真正在 `prerequisites` 图中。
4. 区分硬前置缺失、硬前置过度、卷内顺序不合理、标题与 outcome 不一致、主题过载、重复和遗漏。

审计边界：本次只审查 `catalog.yml` 的教学合同，没有以未来章节正文可能“顺便解释”作为通过理由。即使正文能临时补救，只要目录中的 outcome 要求未来知识、硬依赖图却未表达，仍属于课程架构问题。

## 3. P0：会直接卡住零基础读者

| 章节 | 暗用但尚未教授的概念 | 建议 |
| --- | --- | --- |
| `v00.c02.computer-model` | 系统命令、PID、资源诊断，但终端在 `v00.c04` | 移到终端之后，或把操作改成教师演示，不作为独立 outcome |
| `v00.c03.files-paths-encoding` | “往返读写 UTF-8 文件”需要编辑器或终端 | 将 `v00.c04` 设为实践前置，或只保留路径/编码概念 |
| `v00.c07.editor-ide-debugger` | 断点、步入、调用栈、错误分支需要已有可调试程序 | IDE 导航可留卷 00；真正调试移到 Java 条件/方法之后 |
| `v00.c09.network-http-curl` | ID 声称教授 HTTP/curl，outcomes 却只有 DNS、IP、TCP、TLS | 拆成“网络分层”和“HTTP/curl 基础”，否则后续 `uses=http` 没有真实来源 |
| `v00.c12.ai-collaboration-verification` | 要求用测试证伪 AI 补丁，但此前没有测试预言、断言、测试类型基础 | 卷 00 增加最小验证/测试模型，或把 outcome 缩成命令和输出验证 |
| `v01.c01.java-platform` | 最小 Java 程序已经使用 `class`、`main`、`String[]`、`public static void` | 明确标为“暂借样板，不要求解释”；只验编译链和运行链 |
| `v01.c02.program-structure` | “跨包调用”需要方法、`static`、参数和访问控制；访问控制在 `v02.c03` | 本章只做文件名、目录、package、入口类；跨包调用移到封装章节 |
| `v01.c03.console-io` | 校验 CLI 和处理非法输入/EOF 需要变量、类型、运算符、条件、循环、数组/String，甚至异常 | 必须移到条件、循环、数组、方法之后；早期仅教授 `println` 和观察参数 |
| `v01.c04.variables-scope`、`v01.c05.primitive-types` | 变量先于类型；“写断言”先于 JUnit；FactoryCare 字段选型又暗用 String、时间、枚举和金额类型 | 合并为“变量、基本类型、String、作用域和输出”，字段选型只限本章已教类型 |
| `v01.c06.operators-conversion` | “实现订单金额计算”暗用方法；“精度”容易暗指尚未教授的 BigDecimal | 明确只用整数分和溢出；方法实现放到方法章节之后 |
| `v01.c07.conditionals-switch` | “实现并测试决策表”先于方法和 JUnit | 可先做 main 内分支与手工用例；正式可测试方法放到 `methods` 后 |
| `v01.c08.loops-control` | “查找循环”通常需要数组/String/集合，但数组在下一章、String 在卷 02 | 本章只做计数、累积和哨兵循环；查找移到数组章节 |
| `v01.c10.arrays-debug-test` | 标题包含“调试与 JUnit”，三个 outcomes 却全部只验数组 | 必须增加 JUnit、测试结构、断言、失败日志和调试 outcome，或拆章 |
| `v02.c04.static-final-immutability` | 防御性复制和“集合引用泄漏”先于 `v03.c01.collections` | 将不可变集合部分移到集合之后；本章只讲字段和值对象不可变 |
| `v02.c08.object-contract` | 要求验证 Set/Map 行为，但 Set/Map 下一卷才教 | 移到集合之后，或先只验证 `equals/hashCode` 的直接契约 |
| `v04.c01.relational-model` | 要求修复主键/外键错误，但 DDL、约束在 `v04.c06` 才教 | 本章使用预建 schema，只观察关系；创建和修复约束移到 `v04.c06` |
| `v05.c08.services-transactions-aop`、`v05.c09.mybatis-integration` | Spring 事务集成测试需要真实持久化层，但 MyBatis 集成在下一章；下一章又硬依赖本章 | 构成教学语义循环。应先完成 Repository/MyBatis，再讲 Service 事务与 AOP |
| `v06.c01.auth-session-password` | 要求实现安全登录、退出和 session fixation 测试，但 Spring Security 在 `v06.c04` | 前三章只讲模型和威胁；安全实现统一放到 Spring Security 之后 |
| `v07.c01.browser-render-devtools` | 要求修复主线程阻塞和强制重排，但 HTML/CSS/JS 尚未学 | 本章只能观察和解释；真正修复分别移到 CSS/JS 性能章节 |
| `v07.c10.motion-performance` | `layout thrashing` 通常由 JS 读写布局交错造成，JS 在卷 08 | 本章只处理 CSS 动画成本；layout thrashing 移到 DOM/性能章节 |
| `v08.c02.values-types-equality` | “写真值表并由测试验证”发生在变量、控制流、函数和测试工具之前 | 先增加 JS 语句、变量、运算符、输出与最小断言 |
| `v08.c03.scope-functions-closures` | 把作用域、控制流、函数、一等函数、闭包一次教授，跨度过大 | 至少拆成“变量/控制流/函数”和“作用域/闭包”两层 |
| `v08.c09.typescript-setup-strict` | 直接进入 strict、联合、unknown、never、收窄，却没有基础类型标注、对象类型、接口、类型别名、函数类型 | 增加 TypeScript 基础层，再进入 strict 与高级收窄 |
| `v08.c10.typescript-advanced-tooling` | 一章同时容纳泛型、映射类型、条件类型、运行时 schema、测试和构建 | 必须拆分或缩小；当前无法给零基础读者建立稳定台阶 |
| `v09.c01.vite-sfc-app`—`v09.c04.components-contracts` | Vue 目录完全没有明确教授模板插值、`v-bind`、`v-on`、`v-if`、`v-for`、表单绑定等基本模板语法 | 在响应式和组件前增加“模板、指令、事件、列表、表单”章节 |
| `v11.c02.dart-control-functions` | “工单过滤规则”暗用 List，List 在 `v11.c03`；还要求测试，但 Flutter/Dart 测试在最后 | 本章只做标量规则；集合过滤移到 `v11.c03`，并明确使用内置 assert 还是 test 包 |
| `v11.c06.flutter-runtime` | 直接从 Dart OOP 跳到 Widget/Element/RenderObject，没有 Flutter SDK、项目结构、run/hot reload、MaterialApp、基础 Widget | 先增加 Flutter 工具链与最小界面，内部渲染模型后移 |
| `v11.c08.state-lifecycle-mounted` | mounted 晚到更新依赖 Future/异步，但没有硬依赖 `v11.c05` | 增加 `v11.c05` 硬前置 |
| `v12.c02.types-io-control` | 校验 CLI 需要函数、集合或异常处理；函数在 c03，异常在 c06 | 本章只做基本输入、转换和分支；健壮 CLI 移到异常之后 |
| `v12.c05.classes-dataclass-protocol` | Protocol 和“类型检查验证”先于 `v12.c07` 的 typing/类型检查工具 | 将基础 typing 与检查器前移，Protocol 再建立在其上 |
| `v13.c01.vectors-matrices-tensors`—`v13.c03.derivatives-gradients` | 默认读者已经理解代数式、函数、坐标、指数、求和、斜率和图像；这些没有任何前置章节 | 增加数学桥接层：算术/代数、函数与图像、指数对数、求和符号，再进入线代/概率/微积分 |
| `v14.c06.retrieval-rerank` | outcome 要比较“召回率”，但 gold set、检索评估和指标在 `v14.c07` 才教 | c06 只完成检索和计划比较；召回率比较移到 c07，或先教评估集 |

## 4. P1：缺失的硬依赖

经硬依赖图核对，下列真实语义前置均不是目标章节的祖先：

| 应先教授 | 当前提前使用位置 | 问题与建议 |
| --- | --- | --- |
| `v00.c04.terminal-shell` | `v00.c02.computer-model` | 系统工具证据需要终端；增加前置或后移实验 |
| 基础测试模型或 `v01.c10.arrays-debug-test` | `v00.c12.ai-collaboration-verification` | AI 补丁测试验证没有测试来源；增加语言无关的测试预言基础 |
| `v01.c04.variables-scope`、`v01.c07.conditionals-switch` | `v01.c03.console-io` | 输入校验先于变量和条件；重排卷 01 |
| `v03.c01.collections` | `v02.c04.static-final-immutability`、`v02.c08.object-contract` | 防御性复制及 Set/Map 合同先于集合；后移相关实践 |
| `v03.c06.io-nio-json` | `v02.c10.exceptions-resources` | 资源所有权/关闭先于具体 IO 类型；可先讲异常，将资源部分后移 |
| `v04.c04.aggregate-group-having` | `v04.c05.joins-subquery-cte` | “统计问题”和窗口结果暗用聚合，但聚合只是软顺序；增加硬前置或缩小 outcome |
| `v04.c11.jdbc-pool-mybatis` 或 `v05.c09.mybatis-integration` | `v05.c08.services-transactions-aop` | 持久化应先于 Spring 事务集成验证；重排 c08/c09 |
| `v07.c01.browser-render-devtools` | `v06.c02.web-security-threats` | CORS、XSS 需要浏览器 origin、DOM 和执行上下文；把浏览器/HTTP 基础前移或拆分威胁章节 |
| `v05.c09.mybatis-integration` | `v06.c05.rbac-multitenancy-audit` | 跨租户数据隔离测试需要真实数据访问层；增加持久化前置 |
| `v06.c01.auth-session-password`、`v06.c04.spring-security` | `v09.c06.router-navigation-auth` | Vue 页面权限只依赖 HTTP，没有认证/授权前置；增加安全概念前置 |
| `v06.c07.state-sla-idempotency` | `v10.c06.packages-performance-offline` | 离线队列重放需要幂等语义；增加硬前置 |
| `v11.c03.dart-collections-patterns` | `v11.c02.dart-control-functions` | 集合过滤先于 List；缩小 c02 或后移实验 |
| `v11.c05.dart-async-errors` | `v11.c08.state-lifecycle-mounted` | mounted 晚到更新需要 Dart Future；增加硬前置 |
| `v12.c07.typing-testing-logging` 中的 typing/检查器 | `v12.c05.classes-dataclass-protocol` | Protocol 与类型检查器顺序倒置；将基础 typing 前移 |
| `v12.c06.exceptions-iterators-decorators` 中的异常 | `v12.c02.types-io-control` | 健壮 CLI 提前需要异常；后移完整校验 |
| `v13.c07.neural-networks` | `v13.c08.pytorch-foundations` | 最小可训练 PyTorch 模型没有神经网络硬前置；增加前置 |
| `v13.c07.neural-networks` | `v14.c01.llm-model` | Transformer 心智模型没有神经网络/注意力来源；增加前置或在 c01 内明确补足 |
| `v14.c07.rag-citations-evaluation` 的评估方法 | `v14.c06.retrieval-rerank` | 检索指标先于检索评估；重排 outcome |

## 5. P1：过度的硬依赖

下列关系更适合作为推荐顺序、特定实验前置或 FactoryCare 路线门禁，而不是真正“不可豁免”的章节知识前置：

| 章节 | 当前过度前置 | 建议 |
| --- | --- | --- |
| `v00.c11.docker-foundations` | 完整依赖/构建基础 | Docker 基础只需终端、文件和网络；构建工具可设推荐前置 |
| `v05.c02.ioc-di-beans` | `v03.c09.annotations-reflection-proxy` | 理解构造器注入只需 OOP；反射/代理是实现细节，改为推荐前置 |
| `v04.c11.jdbc-pool-mybatis` | 完整 Flyway 迁移章节 | JDBC/MyBatis 可先独立学习；迁移作为项目集成前置，而非概念硬前置 |
| `v09.c01.vite-sfc-app` | `v08.c10.typescript-advanced-tooling` | Vue 入门不需要条件类型和运行时 schema；只硬依赖 TypeScript 基础 |
| `v09.c10.nuxt-rendering-deployment` | 路由认证和请求竞态 | Nuxt SSR/SSG 基础不需要完整认证场景；集成实验再依赖 |
| `v10.c01.miniprogram-runtime` | Vue/Vite 应用 | 小程序运行模型本身与 Vue 无关；Vue 从 uni-app 章节开始依赖 |
| `v13.c07.neural-networks` | 通过指标章强制完成整套经典 ML | 经典 ML 是合理推荐路线，但并非理解神经网络的不可豁免前置 |
| `v14.c02.model-api-prompts` | `v12.c09.fastapi-pydantic` | 调用模型 API 只需要 Python、HTTP 客户端和异步/错误处理；移除 FastAPI 硬依赖 |
| `v14.c10.mcp-agent-boundary` | `v06.c04.spring-security` | 学习 MCP/Agent 不必先掌握 Spring Security；仅 Java/Python 生产集成实验需要 |
| `v11.c13.flutter-testing-performance-release` | 所有设备 API | 普通 Flutter 应用也可学习测试、性能和发布；设备 API 作为 FactoryCare 路线门禁 |
| `v15.c10.system-design-portfolio` | mini-app、Flutter、Agent 全部完成 | 将“通用系统设计章节前置”和“FactoryCare 最终验收门禁”分开 |

## 6. 标题、ID 与 outcomes 不一致

这些不一致会让后续章节或依赖图误以为某个主题已经教授：

| 章节 | 标题/ID 声称包含 | outcomes 实际缺失 |
| --- | --- | --- |
| `v00.c09.network-http-curl` | HTTP、curl | HTTP、curl |
| `v01.c10.arrays-debug-test` | 调试、JUnit | 两者均缺 |
| `v02.c09.core-value-types` | 时间 API、BigDecimal | 两者均缺 |
| `v03.c06.io-nio-json` | JSON | JSON |
| `v03.c10.maven-testing-jvm` | testing、JVM | 测试与 JVM |
| `v04.c10.migration-jdbc-mybatis` | JDBC、MyBatis | 两者均缺 |
| `v11.c09.navigation-network-device` | network、device | 网络与设备 |
| `v11.c10.architecture-testing-release` | testing、release | 测试与发布 |

170 章全部使用高度相似的三段式 outcome，31 章在 outcome 中直接要求“测试”，但多种语言的测试工具在很后面才正式出现。目录必须明确早期“测试”究竟指手算、main 内断言、语言内置 assert，还是测试框架。

## 7. 主题过载

建议优先拆分或缩小这些章节：

- `v03.c09.annotations-reflection-proxy`：注解、反射、类加载器、动态代理。
- `v04.c05.joins-subquery-cte`：JOIN、子查询、CTE、窗口函数。
- `v05.c07.validation-errors-files`：校验、Problem Details、文件上传、分页。
- `v05.c10.testing-openapi-actuator`：测试切片、Testcontainers、OpenAPI、Actuator。
- `v06.c02.web-security-threats`：CORS、CSRF、XSS、SSRF。
- `v06.c05.rbac-multitenancy-audit`：RBAC、ABAC、多租户、数据权限、审计。
- `v08.c10.typescript-advanced-tooling`：高级类型、运行时校验、测试、构建。
- `v11.c05.dart-async-errors`：异常、Future、Stream、Isolate、取消。
- `v11.c13.flutter-testing-performance-release`：三层测试、性能、构建、发布。
- `v12.c06.exceptions-iterators-decorators`：异常、上下文、迭代器、生成器、装饰器。
- `v12.c09.fastapi-pydantic`：FastAPI、Pydantic、依赖、安全、OpenAPI。
- `v13.c05.classical-ml`：预处理、回归、分类、聚类。
- `v14.c06.retrieval-rerank`：dense/sparse/hybrid、pgvector、索引、rerank、评估。
- `v15.c08.backup-capacity-performance`：备份恢复、RPO/RTO、容量、性能验证。

## 8. 重复主题需要明确分层

这些重复并非都应删除，但必须标明“首次教授、框架实践、平台适配、生产深化”，不能让每章重新从头讲：

- HTTP：`v00.c09`、`v03.c11`、`v05.c01`/`v05.c05`、`v08.c08`、`v15.c02`。
- Docker：`v00.c11` 与 `v15.c03`。
- MyBatis：`v04.c11` 与 `v05.c09`。
- 请求竞态：`v08.c08`、`v09.c08`、`v11.c08`/`v11.c11`。
- 可观测性：`v05.c10`、`v06.c10`、`v15.c07`。
- 无障碍：`v07.c04`、`v09.c09`、`v11.c07`。
- 发布：`v09.c10`、`v10.c09`、`v11.c13`、卷 15。
- 离线队列：`v10.c06` 与 `v11.c11`，两者都应复用统一幂等前置。

## 9. 明显遗漏

### 9.1 通用基础

- HTTP 报文与 REST/API 基础：方法、状态码、Header、Body、Content-Type、缓存、Cookie、同源。
- 通用测试基础：预期值、测试预言、Arrange–Act–Assert、单元/集成边界。
- API 资源、错误、版本、分页、幂等的设计基础。

### 9.2 Java 与算法

- Java 基础中的 String、字面量、语句/代码块、注释、参数传递。
- 数据结构与算法：当前复杂度章没有覆盖搜索、排序、栈/队列、树、图、哈希和基本解题方法。
- `StringBuilder`、包装类型/装箱、可变参数等是否属于正文内部主题，目录合同无法确认。

### 9.3 Web 前端

- JavaScript 的变量声明、运算符、分支、循环、错误处理和基础测试，目前被压在闭包/高级章节之间。
- TypeScript 的基础类型标注、接口、类型别名、函数类型和对象/数组类型。
- Vue 模板插值、指令、事件、条件、列表与表单体系。
- 浏览器同源、Cookie、缓存与 CORS 的基础心智模型。

### 9.4 Flutter 与 Python

- Flutter 工具链、项目结构、`flutter run`、hot reload、MaterialApp 和基础 Widget。
- Python 的基础类型标注与类型检查器，应早于 Protocol。
- Python 异常处理应早于“健壮 CLI”和安全文件 I/O 的完整 outcome。

### 9.5 数据、机器学习与 AI

- 机器学习前的数学桥接层。
- RAG 前的信息检索基础：倒排索引、词项、BM25、召回率、精确率和固定查询集。
- Transformer 之前的神经网络、注意力、softmax 与序列表示衔接。

## 10. 卷 01 重构建议

### 10.1 是否需要重构

需要，而且是结构性重构。原因不是“章节名字不够漂亮”，而是 c01—c08 多次要求读者独立使用未来章节才教授的语法和工具。单纯增加硬依赖会制造向后依赖或循环，无法修复教学顺序。

### 10.2 推荐顺序

建议保留 10 章规模，但重写顺序与边界：

1. **Java 平台、编译运行、暂借 Hello World 样板**：只理解源码到 class 再到 JVM 的链路。
2. **程序词法与结构**：注释、标识符、字面量、语句、代码块、class、main、package。
3. **变量、基本类型、String、作用域与基本输出**。
4. **运算符、类型转换、溢出与整数分金额**。
5. **布尔逻辑、条件与 switch**。
6. **for/while、计数、累积与哨兵循环**。
7. **数组、二维数组、String 基础和命令行参数**。
8. **方法、参数、返回值与重载**；递归降为选学或延后。
9. **控制台输入、缺参数、EOF、合法性校验与退出码**。
10. **Maven/JUnit 最小测试、断言、失败日志和断点调试**。

### 10.3 配套调整

- 将“跨包访问控制”移到 `v02.c03.constructors-encapsulation`。
- 将 String 从 `v02.c09.core-value-types` 前移；该章保留正则、时间与 BigDecimal。
- 将“查找”练习移到数组章节。
- 明确 c01 中 `public static void main(String[] args)` 是暂借样板，不能要求零基础读者提前解释。
- c10 必须真正教授测试，而不只是把 JUnit 写在标题里。
- c09 可以使用 `Scanner.hasNext*` 处理合法性，完整异常解析留到异常章节，避免再次提前消费未来知识。

## 11. 卷级整改判断

| 卷 | 判断 | 主要动作 |
| --- | --- | --- |
| 00 | 需要较大调整 | 终端前置、调试后移、补 HTTP 与通用测试基础 |
| 01 | 必须重构 | 按语法认知顺序重排全部 10 章 |
| 02—03 | 定点重排 | 集合/不可变/Object 合同、IO/资源、Maven/JUnit 顺序 |
| 04—05 | 需要修复语义循环 | DDL/外键、MyBatis/Service 事务顺序 |
| 06 | 需要重排 | 领域建模应早于部分应用服务；安全概念、框架实现和数据隔离分层 |
| 07—09 | 需要补基础层 | 浏览器/HTTP、JS 基础、TS 基础、Vue 模板 |
| 10 | 中度调整 | 离线幂等前置、测试提前、平台基础与 Vue 依赖分离 |
| 11 | 需要较大调整 | Dart 集合/测试顺序、Flutter 工具链、异步前置 |
| 12 | 需要拆分基础层 | CLI/异常、typing/Protocol、测试工具顺序 |
| 13 | 必须增加数学桥接 | 数学基础、PyTorch/神经网络硬前置 |
| 14 | 需要调整 | Transformer 前置、检索/评估顺序、移除 FastAPI 过度依赖 |
| 15 | 整体较稳但需澄清 | Docker 深化边界、Flyway 回滚语义、通用章节与最终门禁分离 |

## 12. 建议的课程治理规则

1. 每个 outcome 只能要求本章明确引入或硬前置祖先已经教授的概念。
2. `recommended_after` 不能承担完成 outcome 所必需的知识。
3. 给关键基础概念增加 `concepts_taught`、`concepts_assumed`、`concepts_practiced`，但仍保留人工语义审查，不能退化为编号校验。
4. 将“章节知识前置”“具体实验前置”“路线完成门禁”分成三个字段，避免把所有技术栈都变成通用章节硬前置。
5. 每章默认只引入一至两个主要认知簇；四个以上独立主题必须拆分或缩小 outcome。
6. 重复主题标记为首次教授、语言实现、框架集成、平台适配或生产深化。
7. 在任何章节首次要求“测试”前，先教授测试预言、断言和最小测试循环，并明确允许的验证工具。
8. outcome 应写出可观察行为和知识边界，不能只靠统一模板证明课程完整。

## 13. 推荐整改顺序

1. 先重构卷 00—01，并补 HTTP/测试基础。
2. 修复集合、IO、SQL、Spring 事务的语义倒置。
3. 补 JS/TS/Vue、Flutter、Python 的语言级台阶。
4. 增加数学桥接与检索评估前置。
5. 将路线完成门禁与章节不可豁免前置分开。
6. 最后再做 capability/依赖自动校验；否则自动化只会验证一张语义仍然错误的图。

## 14. 有意未做事项

- 未修改 `curriculum/catalog.yml`。
- 未修改 routes、book、`PROGRESS.md` 或任何课程正文。
- 未替目录作者推定正文中未声明的“顺便讲解”。
- 未验证具体软件版本；版本准确性属于独立版本审查。
- 未将当前结论当作对 170 份未来章节正文质量的评价，本报告只判断目录合同能否安全指导零基础学习。
