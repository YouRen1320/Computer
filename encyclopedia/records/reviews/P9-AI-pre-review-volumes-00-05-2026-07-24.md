# P9 AI 独立预审：卷 00—05（2026-07-24）

> **actor: AI（Codex 多代理语义预审）**
> **review_kind: AI-assisted pre-review, not human review**
> **attestation_effect: none**
> 本记录不是独立真人复核，不是零基础学习者试读，不是无障碍人工验收，也不能创建、替代或关闭 `verification/review-attestations/<chapter-id>.yml`。任何 `PASS` 只表示本轮 AI 阅读没有发现章级阻断，不表示章节可晋升 `review/verified`，更不表示可以公开发行。

## 1. 范围、方法与判定边界

- 范围：`book/volume-00-computer-foundations` 至 `book/volume-05-spring-backend`，共 91 章；逐章同时阅读 front matter、正文教学链，以及同章 `examples/`、`exercises/`、`labs/` 的 README、入口脚本和关键 oracle/故障形状。
- 标准：[`REVIEW-RUBRIC.md`](../REVIEW-RUBRIC.md) 的七个评审面，以及每章 `responsibility`、`prerequisites`、三项 `outcomes`。
- 阅读关注点：零基础是否能从“为什么/会看到什么”进入术语；概念先后；术语首次定义；example/exercise/lab 是否覆盖解释、构建、诊断；expected-red 是否存在可到达的 green；错误、安全、版本和未验证边界；FactoryCare 映射是否越权。
- 结论：`PASS`、`PASS_WITH_FOLLOW_UP`、`FAIL`。严重度使用 `none`、`minor`、`major`、`blocker`；`FAIL` 表示当前教学路径有阻断，不表示正文所有技术内容都错误。
- 已核对但不重复冒充的机器事实：章节仍为 `drafting`；公开端点的机器执行与 manifest/Runner 属于另一证据层。本文没有重跑 91 章全部工具链，也没有把现有绿灯当作可学性证明。
- 明确未执行：真人逐字事实复核、来源蕴含逐条确认、零基础计时试读、Windows/Linux 复现、真实 PostgreSQL/容器/浏览器矩阵、键盘/读屏/版式验收。
- 本轮只新增此记录；未修改教材、公开端点、manifest、attestation、release 文件或 `PROGRESS.md`。

## 2. 总体结论

**结论：`FAIL`（存在跨章练习闭环阻断）。** 正文整体呈现清晰的先修链、术语边界、FactoryCare 例子、故障注入和未验证声明；卷 00—02 的概念梯度尤其连贯。阻断集中在公开练习入口：若干章节的 README 要求学习者修复 starter，但 `verify.sh` 只接受原始 expected-red，修复正确后反而报“starter unexpectedly passed”或退出其他错误；卷 04 还有未写明完成态 oracle 命令与两处过时退出码说明。这直接破坏“预测 → 红 → 修复 → 同一 oracle 绿 → 复跑”的零基础路径。

AI 预审不能关闭以下正式门：91 章独立真人内容复核、真实零基础试读、来源蕴含复核、人工无障碍/版式，以及与当前字节绑定的 review attestation。

| 分卷 | PASS | PASS_WITH_FOLLOW_UP | FAIL | 小计 |
| --- | ---: | ---: | ---: | ---: |
| 卷 00 | 0 | 15 | 0 | 15 |
| 卷 01 | 11 | 0 | 0 | 11 |
| 卷 02 | 9 | 0 | 3 | 12 |
| 卷 03 | 11 | 2 | 5 | 18 |
| 卷 04 | 0 | 4 | 13 | 17 |
| 卷 05 | 0 | 0 | 18 | 18 |
| **合计** | **31** | **21** | **39** | **91** |

## 3. 跨章发现

### F-00-01 — 卷 00 的 green 只检查五个标题，且 README 未说明 `submission.md` 合同

- 严重度：`major`
- 影响：卷 00 全部 15 章。
- 证据：例如 `exercises/encyclopedia/ch.foundations.learning-evidence/verify.sh:4-14` 要求一个 README 未说明的 `submission.md`，只检查“预测/实验/失败/修复/复述”五个二级标题；空章节也会得到 `EXERCISE_GREEN evidence loop is structurally complete`。同一结构出现在卷 00 的 15 个 exercise 入口。
- 判断：脚本明确说“structurally complete”，所以没有伪称语义掌握；但零基础读者不知道应创建什么文件，也无法通过该 green 判断回答、命令、诊断或复述是否正确。
- 建议：每个 README 提供统一 `submission.md` 模板和执行命令；机器 green 继续只称“结构完成”，并在周验收明确要求教师/真人语义批改，不能晋升章节。

### F-02-01 — 三个 OOP 练习只有 starter-red，没有可到达的完成态入口

- 严重度：`blocker`
- 影响：`ch.java-oop.business-value-types`、`ch.java-oop.exceptions-failure-contracts`、`ch.java-oop.object-contracts`。
- 证据：`business-value-types/README.md:3-17` 要求逐项修复并只给 `./verify.sh`；对应 `verify.sh:20-28` 固定要求 starter 的 exit 8/7 和原始错误文本，末尾无条件 exit 41。另两章同样固定原始故障形状并无条件 exit 41；`object-contracts` 甚至说明“程序自身”应绿、但没有给出可复跑的完成命令。
- 判断：修复第一处故障后入口不会暴露下一条 oracle，也不能确认最终 green；与 chapter outcome 的独立构建/诊断闭环冲突。
- 建议：把 wrapper 改成双态合同：精确 starter → 41，精确 solved → 0 + `EXERCISE_GREEN`，部分修复/未知状态 → 43；README 固定同一命令完成红—绿复跑。

### F-03-01 — 注解章的 responsibility 与实际教学/诊断范围自相矛盾

- 严重度：`major`
- 影响：`ch.java-engineering.annotations-metadata`。
- 证据：front matter `responsibility` 写“不在本章读取反射”；同一 front matter 的 diagnose outcome 明确要求“读取 class/反射观察”，正文“从声明到证据”又说明用最小运行时探针，后文实际教授 `getAnnotation`、`getDeclaredAnnotation`、`getAnnotationsByType`。
- 判断：正文通过“只做窄可见性探针、不做通用扫描”给出了合理边界，但权威责任字段仍与内容相反，会污染目录/路线和后续自动审查。
- 建议：把 responsibility 改成“仅用窄反射探针验证元数据可见性，不教授通用成员扫描、类加载或代理”，并让 outcomes/capabilities 同步声明这一依赖。

### F-03-02 — 五个 Java 工程练习没有完成态验证入口

- 严重度：`blocker`
- 影响：`ch.java-engineering.executors-virtual-threads`、`functional-pipelines`、`json-mapping`、`lambdas-functional-interfaces`、`threads-jmm`。
- 证据：五份 README 都把 `./verify.sh` 作为练习命令并要求修复 TODO；五个脚本都固定要求 starter 非零及原始 sentinel，随后无条件 exit 41。修复正确后只会进入“starter no longer exposes expected red”或 shell assertion failure，没有 solved 分支，也没有 README 指定的替代完成命令。
- 判断：正文与 lab 的并发、异常、映射、函数边界仍有教学价值，但公开独立构建 outcome 无法闭环。
- 建议：采用与卷 01 成熟练习相同的三态 wrapper，并保留独立故障 fixture 在 solved 状态仍必须失败。

### F-03-03 — JVM 诊断章没有精确完成命令，真实 dump/JFR outcome 也未执行

- 严重度：`major`
- 影响：`ch.java-engineering.logging-jvm-diagnostics`。
- 证据：exercise 的 `verify.sh` 只认 starter-red，README 只说“直接编译运行程序”，没有给精确 `javac`/`java` 命令、classpath 或预期两行文本；正文 build outcome 要求采集线程转储和短 JFR，但正文、lab README 与 verifier 均披露当前只读固定 fixtures，没有执行真实 `jcmd`/JFR。
- 判断：结构化日志、脱敏、correlation、dump/JFR 解释与证据边界本身清楚；但零基础完成路径仍有隐藏步骤，且当前机器证据不能证明 build outcome 已达成。作为对照，`testing-test-doubles` 虽也把 red wrapper 与完成态拆开，但 README 明确给出 `mvn --offline clean test`，green 可达，故该章本轮为 `PASS`。
- 建议：把完成态并入同一 wrapper，或至少提供可复制的编译/运行命令与精确输出；另建只附着自启测试 JVM 的受控 real-tool lab，声明权限、磁盘、隐私和清理边界。

### F-04-01 — 卷 04 多数练习没有给零基础读者完成态命令

- 严重度：`blocker`
- 影响：除明确写出 `ruby oracle.rb answer.*` 的 `aggregates`、`postgresql-types`、`scalar-functions`、`select-rowsets` 外，其余 13 章。
- 证据：这些目录都含 `oracle.rb`，但 README 只说修复 `answer.sql/json` 和运行 red-only `./verify.sh`；该 wrapper 在 oracle 成功时输出 `starter-unexpectedly-passed` 并退出 1。代表性证据：`exercises/encyclopedia/ch.data.ddl-constraints/README.md` 与 `verify.sh`、`ch.data.jdbc/README.md` 与 `verify.sh`。
- 判断：熟练者可以猜出如何直接调用 Ruby oracle，零基础读者不应依赖猜测；expected-red 到 green 的命令合同未闭合。
- 建议：统一双态 wrapper，或至少逐章写出精确完成态命令、预期输出和退出码；推荐双态 wrapper，避免学习者在两个入口间切换。

### F-04-02 — 两份 README 仍声称 expected-red 退出 0，实际已规范为 41

- 严重度：`major`
- 影响：`ch.data.postgresql-psql`、`ch.data.relational-model`。
- 证据：`ch.data.postgresql-psql/README.md:14` 与 `ch.data.relational-model/README.md:17` 写“退出 0”；对应 `verify.sh:15-16` 均打印 `EXPECTED_RED` 后 exit 41。
- 判断：这是可直接复现的文档—入口矛盾，会让已学退出码的读者错误判断实验失败。
- 建议：README 改为 41，并说明 0=solved、41=已识别教材预期红、43=未知/基础设施状态。

### F-04-03 — 卷 04 的离线 oracle 没有执行真实 PostgreSQL 18

- 严重度：`major`
- 影响：卷 04 全部 17 章，尤其 JDBC、MyBatis、事务/锁、迁移、索引/计划与 PostgreSQL 类型章节。
- 证据：各章正文均诚实标明真实 PostgreSQL/psql/pgJDBC/Flyway 路径尚未验证；例如 `ch.data.select-rowsets` 的正文说明固定 CSV/Ruby oracle 不能证明 SQL 被 PostgreSQL 解析执行，`ch.data.jdbc` 明确说没有加载 pgJDBC 或连接 PostgreSQL，`ch.data.transactions-locking` 明确说未发生真实 MVCC/锁/死锁。
- 判断：离线 oracle 对关系语义、固定数据和错误分类有价值，也没有冒充实机证据；但它不能关闭 PostgreSQL 18 的类型解析、时区、SQLSTATE、锁、计划、驱动映射或迁移 outcome。四个有独立 Ruby green 命令的章节因此仍是 `PASS_WITH_FOLLOW_UP`，其余 13 章还叠加 F-04-01 blocker。
- 建议：保留快速离线层，再补一次性 PostgreSQL 18 环境的 T3 路径；保存版本、schema/fixture、命令、退出码、结果和清理证据，失败时明确区分基础设施与 SQL/业务错误。

### F-05-01 — 卷 05 的 18 个练习把正确完成态当成异常

- 严重度：`blocker`
- 影响：卷 05 全部 18 章。
- 证据：代表性 `ch.spring.ioc-di/README.md:5-13` 明确要求同一 `./verify.sh` 从 expected-red 转 `state=completed`；对应 `verify.sh:17-20` 在 Maven 测试 exit 0 时输出 `STARTER UNEXPECTEDLY PASSED` 并 exit 42，末尾只可能以 expected-red 41 结束。`domain-modeling`、`boot-autoconfiguration`、`datasource-pooling` 等入口使用同一失败模式；多数 README 明说“同一入口全绿/接受完成态”。
- 判断：这是 README 与可执行合同的直接反例，阻断从 Spring Core 到测试/事务/可观测的所有公开独立练习。
- 建议：18 个 wrapper 统一实现三态：测试集合精确全绿 → 0/`state=completed`；登记的唯一 starter 失败 → 41；其他编译、测试数量、错误形状或基础设施变化 → 43。修复后必须对 starter 和 private/临时 solved copy 都跑一次。

### F-05-02 — 配置章的 canonical 环境变量名在正文与练习中不一致

- 严重度：`major`
- 影响：`ch.spring.configuration-profiles`。
- 证据：正文把 `factorycare.api-base-url` 的 canonical 环境变量写为 `FACTORYCARE_APIBASEURL`，并明确说 `FACTORYCARE_API_BASE_URL` 是错误写法；example 也使用前者。exercise README 与 `EndpointPriorityExercise.java` 却要求后者。
- 判断：这不是风格差异，而是同章对相同绑定合同给出相反答案；即使 F-05-01 修好，学习者也无法同时满足正文认知和练习目标。
- 建议：统一 canonical 名；若练习有意展示 Spring 宽松绑定别名，应显式称为 alias，并新增对 canonical、alias、未知键和优先级的独立测试，不能把 alias 写成 canonical。

### F-05-03 — Spring 的真实 PostgreSQL/Testcontainers 路径仍有明确未验证项

- 严重度：`major`
- 影响：`ch.spring.testing-testcontainers`，并延伸到 `datasource-pooling`、`mybatis-repositories`、`transactions` 的 PostgreSQL 专属行为。
- 证据：Testcontainers lab README 规定 Docker 不可用时只做静态检查并输出 `UNVERIFIED`；其 verifier 的 fallback 确实不会启动 PostgreSQL。其他三章使用 H2 的路径也明确不证明 PostgreSQL 方言、隔离、锁或容量行为。
- 判断：这些披露是正确的安全边界，H2/静态检查仍能证明部分 wiring；但不能被公开端点“PASS”或静态 green 解释成真实 PostgreSQL 18、Flyway、tenant SQL、乐观锁和 Spring context 集成已经运行。
- 建议：F-05-01 修复后，在 Docker 可用 runner 执行锁定镜像的真实 8-test 路径并保存 stdout；对 H2 章节补最小 PostgreSQL 合同矩阵，保留 Docker 缺失时的显式 `UNVERIFIED`，不可静默降级。

## 4. 逐章结论

证据列中的“正文及同章 example/exercise/lab”展开为：该行章节 ID 对应的 `book/volume-*/chapters/<chapter-id>.md`、`examples/encyclopedia/<chapter-id>/`、`exercises/encyclopedia/<chapter-id>/`、`labs/encyclopedia/<chapter-id>/`；出现“同章”时沿用这一精确映射，不代表抽样。建议中的“真人复核”不表示本 AI 已代替真人。

### 卷 00：计算机、工具与验证基础

| 章节 | 结论 | 严重度 | 阅读证据 | 发现与建议 |
| --- | --- | --- | --- | --- |
| `ch.foundations.learning-evidence` | PASS_WITH_FOLLOW_UP | major | `book/volume-00-computer-foundations/chapters/ch.foundations.learning-evidence.md`; `examples/.../ch.foundations.learning-evidence`; `exercises/.../ch.foundations.learning-evidence`; `labs/.../ch.foundations.learning-evidence` | claim→evidence→next-review、反遗忘和学习账本与三项 outcome 对齐；受 F-00-01 影响。补模板并由真人批改内容。 |
| `ch.foundations.files-paths-encoding` | PASS_WITH_FOLLOW_UP | major | `book/volume-00-computer-foundations/chapters/ch.foundations.files-paths-encoding.md`; 同章 example/exercise/lab | 从界面、树、绝对/相对路径到 UTF-8/换行，先后自然，实验含路径/编码故障；受 F-00-01 影响。 |
| `ch.foundations.terminal-shell` | PASS_WITH_FOLLOW_UP | major | `book/volume-00-computer-foundations/chapters/ch.foundations.terminal-shell.md`; 同章 example/exercise/lab | 终端、Shell、token、argv、quote、glob 首次定义清楚，明确不偷跑管道；受 F-00-01 影响。 |
| `ch.foundations.computer-process-model` | PASS_WITH_FOLLOW_UP | major | `book/volume-00-computer-foundations/chapters/ch.foundations.computer-process-model.md`; 同章 example/exercise/lab | CPU/内存/磁盘/程序/进程的简化模型有物理布局边界，子进程实验对齐；受 F-00-01 影响。 |
| `ch.foundations.cli-streams-exit-codes` | PASS_WITH_FOLLOW_UP | major | `book/volume-00-computer-foundations/chapters/ch.foundations.cli-streams-exit-codes.md`; 同章 example/exercise/lab | stdin/out/err、pipeline 与 exit status 区分明确，预期非零反例可观察；受 F-00-01 影响。 |
| `ch.foundations.environment-tool-resolution` | PASS_WITH_FOLLOW_UP | major | `book/volume-00-computer-foundations/chapters/ch.foundations.environment-tool-resolution.md`; 同章 example/exercise/lab | 父子环境、PATH 顺序、绝对路径和版本来源与用户此前 JDK 经验一致，边界准确；受 F-00-01 影响。 |
| `ch.foundations.editor-project-navigation` | PASS_WITH_FOLLOW_UP | major | `book/volume-00-computer-foundations/chapters/ch.foundations.editor-project-navigation.md`; 同章 example/exercise/lab | 项目树、磁盘、符号、引用和生成文件定位分开讲，错误候选回到规范源码的实验有效；受 F-00-01 影响。 |
| `ch.foundations.git-collaboration-security` | PASS_WITH_FOLLOW_UP | major | `book/volume-00-computer-foundations/chapters/ch.foundations.git-collaboration-security.md`; 同章 example/exercise/lab | 四层状态、冲突、ignore 与凭据轮换边界正确，未把 `.gitignore` 当历史删除；受 F-00-01 影响。 |
| `ch.foundations.network-layers` | PASS_WITH_FOLLOW_UP | major | `book/volume-00-computer-foundations/chapters/ch.foundations.network-layers.md`; 同章 example/exercise/lab | IP/DNS/port/TCP/TLS 五问模型与回环故障矩阵对齐，明确未教授 HTTP；受 F-00-01 影响。 |
| `ch.foundations.http-curl` | PASS_WITH_FOLLOW_UP | major | `book/volume-00-computer-foundations/chapters/ch.foundations.http-curl.md`; 同章 example/exercise/lab | 报文、method/status/header/body 和传输失败分层清楚，本地固定服务避免真实外部写入；受 F-00-01 影响。 |
| `ch.foundations.api-contract-basics` | PASS_WITH_FOLLOW_UP | major | `book/volume-00-computer-foundations/chapters/ch.foundations.api-contract-basics.md`; 同章 example/exercise/lab | resource/representation、Problem、cursor、ETag、idempotency 的边界完整，明确不等于鉴权/事务；受 F-00-01 影响。 |
| `ch.foundations.testing-oracles` | PASS_WITH_FOLLOW_UP | major | `book/volume-00-computer-foundations/chapters/ch.foundations.testing-oracles.md`; 同章 example/exercise/lab | expected/actual、oracle/assertion、AAA、T0—T4 与红—绿循环定义准确；受 F-00-01 影响。 |
| `ch.foundations.dependencies-build-packages` | PASS_WITH_FOLLOW_UP | major | `book/volume-00-computer-foundations/chapters/ch.foundations.dependencies-build-packages.md`; 同章 example/exercise/lab | 依赖图、解析、锁、缓存和生命周期区分清楚，教学 resolver 明确不冒充 Maven/pnpm/uv；受 F-00-01 影响。 |
| `ch.foundations.docker-basics` | PASS_WITH_FOLLOW_UP | major | `book/volume-00-computer-foundations/chapters/ch.foundations.docker-basics.md`; 同章 example/exercise/lab | image/container/writable layer/volume/port/network 概念先后合理，未外推生产加固；受 F-00-01 影响。 |
| `ch.foundations.ai-assisted-verification` | PASS_WITH_FOLLOW_UP | major | `book/volume-00-computer-foundations/chapters/ch.foundations.ai-assisted-verification.md`; 同章 example/exercise/lab | 候选、权限、证据三线与隐私/许可证/回滚负测完整，静态离线 fixture 不冒充真实模型；受 F-00-01 影响。 |

### 卷 01：Java 语言基础

| 章节 | 结论 | 严重度 | 阅读证据 | 发现与建议 |
| --- | --- | --- | --- | --- |
| `ch.java.platform-toolchain` | PASS | none | 正文及同章 example/exercise/lab | JDK/JVM/javac/java/class version 与 PATH/JAVA_HOME 前置衔接，编译/运行失败证据清楚；保留 JDK 25 版本复核。 |
| `ch.java.program-structure` | PASS | none | 正文及同章 example/exercise/lab | comment/identifier/literal/statement/block/class/main/package 从最小程序展开，package 路径失败有真实 javac oracle。 |
| `ch.java.values-variables-types` | PASS | none | 正文及同章 example/exercise/lab | 值/类型/变量、八基本类型、String/作用域/输出分层；对字段默认值、null、static 明确标为后章支架。 |
| `ch.java.expressions-conversions` | PASS | none | 正文及同章 example/exercise/lab | 运算、转换、溢出、整数分与守恒 oracle 对齐；金额单位和错误边界没有提前引入 BigDecimal 设计。 |
| `ch.java.branching` | PASS | none | 正文及同章 example/exercise/lab | 布尔集合、短路、guard、区间顺序、switch 穷尽与 fallthrough 先后正确，边界输入可杀死错误条件。 |
| `ch.java.loops` | PASS | none | 正文及同章 example/exercise/lab | for/while、计数/累积、break/continue/哨兵与终止性逐层建立，0/1/N 和故障 oracle 对齐。 |
| `ch.java.arrays-command-args` | PASS | none | 正文及同章 example/exercise/lab | `length`、0-based、空/单/多、不规则二维数组、args 和越界栈顺序清楚，starter 与 solved 双态可达。 |
| `ch.java.methods` | PASS | none | 正文及同章 example/exercise/lab | signature、参数按值、return、overload 与递归基线不混淆；修改与故障任务能定位同一方法合同。 |
| `ch.java.console-input-validation` | PASS | none | 正文及同章 example/exercise/lab | 参数、Scanner、EOF、解析/范围/退出码分层，输入不可信与错误输出边界明确。 |
| `ch.java.maven-junit-smoke` | PASS | none | 正文及同章 example/exercise/lab | source/test tree、JUnit、Surefire、Tests run 与 BUILD SUCCESS 的差异对应用户已做实验；练习能从红到绿。 |
| `ch.java.debugging-failures` | PASS | none | 正文及同章 example/exercise/lab | compile/runtime/failure/logical 分类和首个可信位置清楚；同一 wrapper 识别 starter 与 fixed 两态。 |

### 卷 02：Java 对象模型

| 章节 | 结论 | 严重度 | 阅读证据 | 发现与建议 |
| --- | --- | --- | --- | --- |
| `ch.java-oop.references-null-identity` | PASS | none | 正文及同章 example/exercise/lab | 引用/身份/别名、String 身份与内容、null/空/空白逐层区分，简化堆栈模型有明确边界。 |
| `ch.java-oop.classes-objects` | PASS | none | 正文及同章 example/exercise/lab | class/new/field/instance method/this 先后自然，字段遮蔽和双实例隔离有可达红—绿。 |
| `ch.java-oop.constructors-invariants` | PASS | none | 正文及同章 example/exercise/lab | 默认构造器、字段初始化、`this(...)` 与对象不变量对齐，三类构造故障可定位。 |
| `ch.java-oop.encapsulation-packages` | PASS | none | 正文及同章 example/exercise/lab | public/protected/package-private/private 与 package 路径/模块职责区分，未把 private 冒充安全边界。 |
| `ch.java-oop.static-class-state` | PASS | none | 正文及同章 example/exercise/lab | 类/实例归属、初始化、无状态工具、静态工厂和全局可变状态污染对齐，完成态可验证。 |
| `ch.java-oop.final-immutability` | PASS | none | 正文及同章 example/exercise/lab | final 引用/对象、不可变性、防御性复制和线程安全边界明确，编译与运行 oracle 互补。 |
| `ch.java-oop.inheritance-composition` | PASS | none | 正文及同章 example/exercise/lab | is-a、override/super、LSP 风险与组合选择有对照，避免把继承当默认复用。 |
| `ch.java-oop.interfaces-polymorphism` | PASS | none | 正文及同章 example/exercise/lab | interface/abstract class、动态分派、默认方法冲突和策略替换梯度合理，构建任务与 outcome 对齐。 |
| `ch.java-oop.enum-record-sealed` | PASS | none | 正文及同章 example/exercise/lab | 有限集合、透明数据载体和封闭层次职责分开，pattern/switch 的版本边界有 JDK 25 来源。 |
| `ch.java-oop.object-contracts` | FAIL | blocker | 正文；同章 example/exercise/lab；见 F-02-01 | equals/hashCode/toString 正文和安全泄漏负测良好，但公开练习入口永久绑定 starter failure；实现双态 wrapper 后重审。 |
| `ch.java-oop.business-value-types` | FAIL | blocker | 正文；同章 example/exercise/lab；见 F-02-01 | regex/BigDecimal/time/UUID 的边界、ReDoS 与时区反例完整；练习无法按说明逐故障修到 green。 |
| `ch.java-oop.exceptions-failure-contracts` | FAIL | blocker | 正文；同章 example/exercise/lab；见 F-02-01 | checked/unchecked、cause/suppressed、catch/translate 边界清楚；公开练习只认原始三故障，不接受完成态。 |

### 卷 03：Java 工程能力

| 章节 | 结论 | 严重度 | 阅读证据 | 发现与建议 |
| --- | --- | --- | --- | --- |
| `ch.java-engineering.maven-reproducible-builds` | PASS | none | `book/volume-03-java-engineering/chapters/ch.java-engineering.maven-reproducible-builds.md`; 同章 example/exercise/lab | lifecycle/goal、scope、插件锁定、offline/cold build 与 artifact digest 的证据边界完整；exercise 有可达 green。 |
| `ch.java-engineering.generics-type-safety` | PASS | none | 正文及同章 example/exercise/lab | type parameter/bound/wildcard/PECS/erasure 从 Object 反例展开，编译失败作为 oracle，未把泛型冒充运行时校验。 |
| `ch.java-engineering.sequential-collections` | PASS | none | 正文及同章 example/exercise/lab | List/Queue/Deque/iterator、顺序/重复/视图/快照职责分开，ConcurrentModification 故障和 FactoryCare 调度对齐。 |
| `ch.java-engineering.associative-collections` | PASS | none | 正文及同章 example/exercise/lab | Set/Map、key equality/hash contract、顺序承诺和缺失键边界依赖 OOP object-contracts，梯度合理。 |
| `ch.java-engineering.sorting-comparators` | PASS | none | 正文及同章 example/exercise/lab | Comparable 与外部 Comparator、稳定性、tie-breaker、null 和减法溢出反例均有对应 oracle。 |
| `ch.java-engineering.complexity-algorithms` | PASS | none | 正文及同章 example/exercise/lab | 先定义 n，再用操作计数解释增长；没有把 Big-O 当毫秒或算法竞赛，索引生命周期边界明确。 |
| `ch.java-engineering.lambdas-functional-interfaces` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-03-02 | SAM/Lambda/method reference/capture/副作用正文与故障夹具对齐；公开 TODO 修复没有可到达 green。 |
| `ch.java-engineering.functional-pipelines` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-03-02 | Stream 惰性/一次性、collector/Optional 与副作用边界清楚；exercise wrapper 永远只认 `PIPELINE_CONTRACT` starter。 |
| `ch.java-engineering.io-resource-lifecycle` | PASS | none | 正文及同章 example/exercise/lab | byte/char、ownership、try-with-resources、primary/suppressed close failure 顺序清楚；同一脚本支持 starter 与 completed。 |
| `ch.java-engineering.nio-files-charsets` | PASS | none | 正文及同章 example/exercise/lab | Path/Files/charset/temp+move/atomic fallback 与 symlink/traversal 风险明确，实验限定本地临时边界。 |
| `ch.java-engineering.json-mapping` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-03-02 | bytes→decode→parse→boundary→domain 五层和 unknown-field 兼容策略准确；exercise 只验证 starter 与 charset 负例。 |
| `ch.java-engineering.threads-jmm` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-03-02 | lifecycle、visibility/atomicity/order、monitor/lock 与确定性交错设计良好；修好两个 counter 后入口无 solved 分支。 |
| `ch.java-engineering.executors-virtual-threads` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-03-02 | task/thread、Future value/error/timeout/cancel、interrupt 与 virtual-thread 资源限制边界完整；公开练习无法确认完成。 |
| `ch.java-engineering.annotations-metadata` | PASS_WITH_FOLLOW_UP | major | 正文及同章 example/exercise/lab；见 F-03-01 | Target/Retention/Repeatable/Inherited 与编译期/二进制/运行时证据链具体，exercise 可从编译红到 green；修正权威 responsibility。 |
| `ch.java-engineering.reflection-classloading-proxies` | PASS | none | 正文及同章 example/exercise/lab | Class/member access/classloader identity/JDK Proxy/cause chain 有明确窄边界，未扩展为 DI 容器或字节码修改。 |
| `ch.java-engineering.network-programming` | PASS | none | 正文及同章 example/exercise/lab | TCP framing/UDP/HttpClient/TLS、connect/read timeout、resource/body limits 与 loopback 测试分层合理。 |
| `ch.java-engineering.testing-test-doubles` | PASS | none | 正文及同章 example/exercise/lab | 参数化测试、fake/stub/spy/mock 与“真实边界不能由 mock 证明”的说明准确；README 给出精确完成态 `mvn --offline clean test`，green 可达。统一 wrapper 可改善体验，但不是章级阻断。 |
| `ch.java-engineering.logging-jvm-diagnostics` | PASS_WITH_FOLLOW_UP | major | 正文及同章 example/exercise/lab；见 F-03-03 | structured log/redaction/correlation、dump/JFR 与多样本证据边界良好；补齐可复制完成命令，并实际执行受控 dump/JFR outcome。 |

### 卷 04：数据与 PostgreSQL

| 章节 | 结论 | 严重度 | 阅读证据 | 发现与建议 |
| --- | --- | --- | --- | --- |
| `ch.data.relational-model` | FAIL | blocker | `book/volume-04-data-postgresql/chapters/ch.data.relational-model.md`; 同章 example/exercise/lab；见 F-04-01/F-04-02 | row meaning、key/relation/cardinality 与宽表反例适合零基础；README 既无完成态命令，又写错 expected-red 退出码。 |
| `ch.data.postgresql-psql` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-04-01/F-04-02 | service/client/target/session/startup file/ON_ERROR_STOP 与只读事务边界明确；练习完成路径缺失且 exit 0 说明过时。 |
| `ch.data.select-rowsets` | PASS_WITH_FOLLOW_UP | major | 正文及同章 example/exercise/lab；见 F-04-03 | projection/filter/NULL/precedence/full-order pagination 与三故障对齐；README 已给直接 `ruby oracle.rb answer.sql` green，但仍需统一 wrapper 并补 PostgreSQL 18 解析/执行证据。 |
| `ch.data.scalar-functions` | PASS_WITH_FOLLOW_UP | major | 正文及同章 example/exercise/lab；见 F-04-03 | 标量/聚合边界、CAST、timezone-before-truncation、CASE 与索引影响清楚；green 需切到直接 oracle，且固定偏移/Ruby 不能证明 PG overload、IANA timezone 或表达式索引。 |
| `ch.data.aggregates` | PASS_WITH_FOLLOW_UP | major | 正文及同章 example/exercise/lab；见 F-04-03 | COUNT(*)/column、NULL、GROUP BY、WHERE/HAVING 与 DISTINCT 输入集合讲解准确；README 有直接 oracle，但双入口增加认知负担，真实 PG 类型/NULL 展示仍未验证。 |
| `ch.data.joins` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-04-01 | key/cardinality、INNER/LEFT、ON-vs-WHERE、COUNT nullable side 和重复行对齐；README 未给完成态 oracle 命令。 |
| `ch.data.subqueries-cte` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-04-01 | scalar/list/correlated/EXISTS、CTE/recursive/materialization 边界完整；exercise 只能确认 starter。 |
| `ch.data.window-functions` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-04-01 | 保留明细、PARTITION/ORDER/frame、tie-breaker 与 NULL 边界清楚；无文档化 green 命令。 |
| `ch.data.ddl-constraints` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-04-01 | PK/FK/UNIQUE/CHECK/NOT NULL/RESTRICT 与 destructive ALTER 边界对齐；练习 wrapper 对正确答案返回 starter-unexpected。 |
| `ch.data.postgresql-types` | PASS_WITH_FOLLOW_UP | major | 正文及同章 example/exercise/lab；见 F-04-03 | UUID/JSONB/array/domain/enum 选择矩阵守住关系建模与迁移边界；README 指向独立 oracle green，但应补可复制命令及 PG18 cast/operator/index/constraint 证据。 |
| `ch.data.dml` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-04-01 | INSERT/UPDATE/DELETE/UPSERT/RETURNING、版本条件和影响行数证据准确；无完成态命令。 |
| `ch.data.transactions-locking` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-04-01 | ACID/isolation/lock/deadlock/whole-transaction retry 与 stable command id 对齐；exercise 只有原始死锁红灯入口。 |
| `ch.data.indexes-explain` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-04-01 | query fingerprint、distribution、plan/buffers、write cost 与 rollback 先正确后性能；未写 green oracle 命令。 |
| `ch.data.normalization-modeling` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-04-01 | row fact、FD/candidate key/anomalies/lossless decomposition 与反规范化边界清楚；完成态入口未说明。 |
| `ch.data.schema-migrations` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-04-01 | history/checksum、forward-fix、expand/backfill/validate/contract 与空库/升级库一致性对齐；red-only wrapper 阻断完成。 |
| `ch.data.jdbc` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-04-01 | DataSource→Connection→Statement→ResultSet ownership、prepared parameter、SQLState/cause/transaction 清楚；无 green 命令。 |
| `ch.data.mybatis-core` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-04-01 | namespace/id、`#{}`、dynamic SQL、result mapping、N+1 与 transaction ownership 边界准确；exercise 完成验证依赖读者猜 oracle。 |

### 卷 05：Spring 后端

以下 18 章的正文、example 和 lab 均有章级价值；`FAIL` 均由 F-05-01 的公开 exercise 可执行合同阻断触发，不代表整章技术内容错误。

| 章节 | 结论 | 严重度 | 阅读证据 | 发现与建议 |
| --- | --- | --- | --- | --- |
| `ch.spring.servlet-request-lifecycle` | FAIL | blocker | `book/volume-05-spring-backend/chapters/ch.spring.servlet-request-lifecycle.md`; 同章 example/exercise/lab | request/response/filter/chain/thread/encoding 与 null/blank early failure 清楚；README 要 completed，wrapper 将全绿视为 exit42。 |
| `ch.spring.ioc-di` | FAIL | blocker | 正文及同章 example/exercise/lab | 普通对象→IoC/DI/DIP→constructor graph→missing/ambiguous/cycle 的先后自然；修正双态 wrapper。 |
| `ch.spring.beans-lifecycle-scopes` | FAIL | blocker | 正文及同章 example/exercise/lab | definition/instance/lifecycle/singleton/prototype/provider/destroy 与线程安全边界完整；同一入口无法 completed。 |
| `ch.spring.configuration-profiles` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-05-02 | source precedence/type binding/profile/secret 与环境覆盖清楚，不把 profile 当秘密存储；除 wrapper 合同反向外，canonical 环境变量名在正文/example 与 exercise 中相互矛盾。 |
| `ch.spring.boot-autoconfiguration` | FAIL | blocker | 正文及同章 example/exercise/lab | Boot/Framework、starter/BOM、conditional/back-off、scan/startup failure 与用户 Bean 边界准确；solved 被报 unexpected。 |
| `ch.spring.aop-proxy-model` | FAIL | blocker | 正文及同章 example/exercise/lab | join point/pointcut/advice/proxy/self-invocation/final/private/exception propagation 边界清楚；练习无法全绿结束。 |
| `ch.architecture.domain-modeling` | FAIL | blocker | 正文及同章 example/exercise/lab | entity/value/aggregate/invariant/command 与 12 状态模型对齐，明确不绑 Controller/表；public setter 修好后 wrapper exit42。 |
| `ch.spring.datasource-pooling` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-05-03 | connection ownership/pool exhaustion/transaction binding/migration-readiness 顺序合理；修复归还连接后入口拒绝，H2 也不关闭 PG 方言/隔离/容量证据。 |
| `ch.spring.mybatis-repositories` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-05-03 | domain port→MyBatis adapter、tenant predicate、mapping cardinality 与事务归属清楚；green 不可达，现有 H2 路径不证明 PG18 锁/隔离/方言。 |
| `ch.spring.service-use-cases` | FAIL | blocker | 正文及同章 example/exercise/lab | load→domain command→save、idempotency/outbox/rollback boundary 与 CRUD 转发反例准确；wrapper 只认 starter。 |
| `ch.spring.mvc-routing-binding` | FAIL | blocker | 正文及同章 example/exercise/lab | DispatcherServlet/controller/routing/binding/status 与 404/400 分层准确；修复 404 后同一入口不能 green。 |
| `ch.spring.dto-json-content-negotiation` | FAIL | blocker | 正文及同章 example/exercise/lab | DTO/wire contract/domain separation/explicit mapping/media type 与敏感字段泄露负例对齐；solved rejected。 |
| `ch.spring.validation` | FAIL | blocker | 正文及同章 example/exercise/lab | binding/field/cross-field/group/service/DB/auth 分层清楚，要求 validation before use case；完成态被误报。 |
| `ch.spring.problem-details-errors` | FAIL | blocker | 正文及同章 example/exercise/lab | internal exception→stable safe Problem Details、HTTP/body status、correlation 与泄密边界完整；wrapper 无 green。 |
| `ch.spring.openapi-contracts` | FAIL | blocker | 正文及同章 example/exercise/lab | runtime/design/OpenAPI triangle、required compatibility、security scheme 与 generated-doc 边界合理；完成 gate 无法通过公开入口。 |
| `ch.spring.testing-testcontainers` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-05-03 | unit/slice/context/real SQL boundary、container lifecycle/image/version 与 Docker limitations 清楚；假集成修好后仍被 wrapper 当异常，当前 fallback 只证明静态合同并明确 `UNVERIFIED`。 |
| `ch.spring.transactions` | FAIL | blocker | 正文及同章 example/exercise/lab；见 F-05-03 | proxy boundary/propagation/rollback/isolation/after-commit 与 outbox 非目标说明准确；练习完成态不可达，H2 证据不关闭 PostgreSQL 锁/隔离路径。 |
| `ch.spring.actuator-health-metrics` | FAIL | blocker | 正文及同章 example/exercise/lab | liveness/readiness/health/metric/cardinality/security exposure 区分清楚；数据库与存活策略修好后同一入口不接受。 |

## 5. 人工复核与修复优先级

1. P0：修复 F-05-01 的 18 个 Spring 练习双态 wrapper；这是当前最大连续学习阻断。
2. P0：修复 F-02-01 的三个 OOP 练习。
3. P0：修复 F-03-02 的五个 Java 工程练习双态 wrapper。
4. P0：为卷 04 所有 red starter 补统一完成态命令，优先修复 13 个未写命令的章节。
5. P1：统一 F-05-02 的环境变量合同，并更正卷 04 两处“退出 0”过时说明。
6. P1：给卷 00 统一提供 `submission.md` 模板，并把结构 green 与语义验收分开显示。
7. P1：在可用 runner 补 PostgreSQL 18、pgJDBC/MyBatis/Flyway/Testcontainers/JFR 的实机证据，未执行时保持 `UNVERIFIED`。
8. 修复后由不同 actor 在临时副本逐章执行 starter→41、solved→0、未知状态→43；再开展真实零基础试读和真人内容/来源复核。AI 本记录不能签署这些门。

## 6. 明确非目标

- 不创建或填写任何人类 review attestation；
- 不把 AI 阅读称为真人审稿、学习者试读或来源事实认证；
- 不修改教材、代码、练习、manifest、release、`PROGRESS.md`；
- 不公开发行，也不建议在上述 blocker 修复前把卷 02/03/04/05 标为完成；
- 不用本报告替代当前 Runner evidence、无障碍人工矩阵或独立重建证据。
