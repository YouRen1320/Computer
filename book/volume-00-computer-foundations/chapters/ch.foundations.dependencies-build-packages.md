---
schema_version: 2
edition: 2026.2-draft
id: ch.foundations.dependencies-build-packages
title: 依赖、包管理、构建生命周期与可重复性
responsibility: 教授依赖解析和构建阶段的通用模型，不替代 Maven、pnpm 或 uv 的专门章节
volume: '00'
order: 13
level: L1
status: drafting
path: book/volume-00-computer-foundations/chapters/ch.foundations.dependencies-build-packages.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.environment-tool-resolution
- ch.foundations.testing-oracles
version_surfaces:
- maven-3
- pnpm
- uv
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释依赖、包管理、构建生命周期与可重复性的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - dependency-resolution
  - build-lifecycle
  covers_topics:
  - build.direct-transitive-dependency
  - build.version-constraint-lock
  - build.repository-cache
  - build.phase-lifecycle
  - build.input-output
  - build.reproducible-environment
  uses_capabilities:
  - foundation.shell-command-stream
  - foundation.verification-debug-test
  - foundation.toolchain-env-build
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：记录 PATH/环境覆盖后实际工具来源，为含直接/传递依赖的工程画解析树、锁定版本并追踪 clean→compile→test→package 输入输出，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - dependency-resolution
  - build-lifecycle
  covers_topics:
  - build.direct-transitive-dependency
  - build.version-constraint-lock
  - build.repository-cache
  - build.phase-lifecycle
  - build.input-output
  - build.reproducible-environment
  uses_capabilities:
  - foundation.shell-command-stream
  - foundation.verification-debug-test
  - foundation.toolchain-env-build
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入 PATH 选错工具、环境未传入子进程、缓存掩盖缺依赖和未锁版本漂移，按解析/构建阶段恢复可重复性
  covers_topic_groups:
  - dependency-resolution
  - build-lifecycle
  covers_topics:
  - build.direct-transitive-dependency
  - build.version-constraint-lock
  - build.repository-cache
  - build.phase-lifecycle
  - build.input-output
  - build.reproducible-environment
  uses_capabilities:
  - foundation.shell-command-stream
  - foundation.verification-debug-test
  - foundation.toolchain-env-build
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 依赖、包管理、构建生命周期与可重复性

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《环境变量、PATH 与工具版本解析》](ch.foundations.environment-tool-resolution.md)：独立完成依赖与包、构建与复现前，必须先具备「环境变量、PATH 与工具版本解析」已经验证的知识与失败边界
- [《预期值、测试预言、断言、AAA 与测试层级》](ch.foundations.testing-oracles.md)：独立完成依赖与包、构建与复现前，必须先具备「预期值、测试预言、断言、AAA 与测试层级」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

在自己的电脑上执行一次 `build` 成功，常让人产生三个过度结论：“依赖都齐了”“测试跑过了”“同事一定能得到同一个包”。真实情况可能完全不同：工具由错误的 PATH 命中；依赖只因旧缓存还在而可用；允许范围今天解析到 1.1、明天变成 1.2；test 已失败，但目录里残留着昨天的 package；打包内容还混入当前时间、用户名和绝对路径。

本章把这些现象统一成一条可验证链路：确定实际工具与环境，读取项目声明，解析依赖图，取得并校验包，按阶段把输入转换成输出，测试失败时停止，最后比较产物摘要并记录证据。Ruby、Java、JavaScript 和 Python 的具体命令不同，但这条心智模型可复用。

本章不替代 Maven、pnpm 或 uv 专章。示例中的 `1.x`、本地源仓库和 lock 格式是透明教学模型，不冒充任一真实工具的语法或解析算法。

## 一、先定义五个经常混用的词

### 依赖

依赖表示“当前项目要完成某项职责，需要另一个组件提供的契约”。它可以是运行库、编译 API、测试框架、构建插件、代码生成器或系统工具。依赖不仅是下载的文件，还包含版本、使用阶段、平台和解析规则。

### 包与制品

包（package）通常是可发布、可解析的分发单元；制品（artifact）强调构建或仓库中的具体输出，例如 JAR、wheel、压缩包或元数据文件。不同生态命名不同，不要把 Java package 声明、npm package 和 Maven artifact 当成完全相同的概念。

### 清单

清单是项目对工具声明的期望输入，例如 Maven 的 `pom.xml`、Node 的 `package.json`、Python 的 `pyproject.toml`。它通常说明直接依赖和约束，但未必穷举最终图中的每个传递依赖。

### 锁文件

锁文件保存一次解析后的精确选择，常包含具体版本、来源或完整性摘要。各工具能力不同：pnpm、uv 有各自锁文件；Maven 3 的常规依赖治理主要依赖显式版本、`dependencyManagement`、BOM 和仓库策略，并不存在一个可与所有生态锁文件机械等同的通用核心 lockfile。正文说“锁”时先讲通用职责，真实项目必须服从所用工具。

### 仓库与缓存

仓库是保存包及元数据的来源；缓存是为复用已取得内容而保存的本地副本。缓存命中不等于上游仓库完整，也不等于新机器能解析。两者物理上可能采用相似目录布局，职责仍不同。

## 二、直接依赖和传递依赖形成图

假设 FactoryCare 报表模块显式声明 `fc-report@1.0.0`，而 `fc-report` 又声明 `fc-format@1.0.0`：

```text
factorycare-build-demo
└── fc-report@1.0.0       直接依赖
    └── fc-format@1.0.0   传递依赖
```

直接依赖是根项目清单明确声明的第一层边；传递依赖是沿依赖边继续到达的节点。`fc-format` 最终进入构建，并不意味着根项目一定写过它。反过来，根项目为了控制版本而显式声明某组件，也不说明业务源码直接调用它；应查看工具的依赖树和实际使用。

依赖不是简单列表，而是有向图。多个路径可指向同一包的不同版本：

```text
app ── A ── C@2
  └── B ── C@1
```

解析器必须决定是否允许并存、选择其中一个、按最近路径仲裁，或判为冲突。算法是工具契约的一部分，不能凭经验跨生态猜测。Apache Maven 官方依赖机制说明：Maven 对传递依赖的版本冲突采用“nearest definition”，同深度时先声明者优先；根项目还可通过显式依赖或 dependency management 控制选择。这个事实只描述 Maven，不是所有包管理器的统一规则。

### 为什么要画树

依赖树用于回答：某包为何出现、从哪条路径进入、哪个声明控制版本、删除哪条边才真正消失、漏洞或许可证影响哪些路径。树是图的一种展开视图，同一节点可能重复显示；大型项目还需结构化报告。

“我没有直接添加这个库”不能证明它不在产物里。诊断应从根项目沿路径追踪，而不是在缓存目录里随意删除文件碰运气。

## 三、版本、约束、选择和锁是四个时点

精确版本 `1.0.3` 表示一个候选；约束 `允许 1.x` 表示一个集合；解析是在给定仓库和规则下从集合中选择；锁文件把这次选择保存下来。把四者分开，才能解释漂移。

设清单允许 1.x：

1. 周一仓库只有 1.0 和 1.1，解析策略选 1.1；
2. 周二仓库新增 1.2，源码和清单没变；
3. 未锁解析可能改选 1.2；
4. 已锁且包仍可取得时，应继续选锁定版本；
5. 主动升级时更新锁、审查差异并重跑验证。

因此“没有改代码”不等于构建输入没变。仓库候选、插件版本、父配置、环境、平台和时钟都可能变化。

### 动态版本和快照

诸如 latest、宽范围、snapshot 或分支引用会让名字保持不变而内容变化。它们可用于探索，但发布和可追溯构建通常需要更强固定。即使使用精确版本，也要防止仓库内容被替换；内容摘要、签名、不可变发布政策和内部仓库治理共同降低风险。

### 锁不是安全或正确证明

锁只记录选择，不证明所选版本没有漏洞、许可证合适或业务行为正确。锁也会过期，需要有节奏地更新。合理流程是：生成差异、解释为何升级、运行测试和扫描、能回滚到前一份锁，而不是永远冻结或每次无审查刷新。

## 四、仓库与缓存：热构建可能是假安全

取得依赖的一般路径是：

```text
清单/锁 → 解析坐标 → 查本地缓存 → 未命中则查允许仓库 → 校验内容 → 放入缓存
```

Apache Maven 官方仓库指南区分本地与远程仓库：本地仓库缓存远程下载并保存本地安装制品，远程仓库可经 `file://` 或 `https://` 等协议访问。Maven 的 `-o` 可请求离线构建；官方文档也谨慎说明许多插件遵守离线设置，而不是承诺所有任意插件行为都绝对无网络。

### 冷缓存和热缓存回答不同问题

- **热缓存**：依赖已经存在，主要证明重复构建能复用当前本地内容；
- **冷缓存**：在隔离空缓存中取得全部声明输入，能暴露源仓库缺包、镜像配置和隐式本地安装；
- **离线冷缓存**：只有项目随附本地仓库、预置依赖包或经过准备的离线镜像时才可能成功；“加 `--offline`”不会凭空生成缺失内容。

若热缓存通过、冷缓存失败，最小结论是“当前机器的缓存遮蔽了缺失来源”。不能立刻断言上游删除了包，也不能先清空用户全局缓存。先保存工具版本、配置和日志，再用临时隔离缓存复现。

### 缓存完整性

缓存文件存在仍可能损坏或被错误替换。解析报告应绑定包名、版本和内容摘要；摘要不符时失败，而不是静默继续。清理也要限定教学缓存目录，禁止为了排障递归删除整个用户仓库。

### 私有仓库与凭据

代理、镜像和认证常位于用户或 CI 配置。报告可以记录“使用哪个配置来源”和脱敏仓库标识，不应提交密码、token、完整 `settings.xml`、`.npmrc` 或私有地址查询串。离线示例故意不需要任何凭据。

## 五、构建生命周期是阶段图，不是一条魔法命令

构建把声明的输入通过一组有顺序的动作转成输出。教学主线是：

```text
clean → validate → compile → test → package
```

- **clean**：删除目标范围内旧产物，使后续证据属于本次运行；
- **validate**：检查清单、锁、环境与依赖是否满足前置；
- **compile**：把源输入转换为可执行或中间表示；
- **test**：运行预言和断言，产生通过/失败计数；
- **package**：在所有必要前置通过后生成分发制品。

这是一条跨工具教学模型。真实 Maven 有 default、clean、site 三个内建生命周期；default 包含 validate、compile、test、package、verify、install、deploy 等阶段。执行后面的 phase 会按顺序执行此前 phase，而 phase 内由插件 goal 完成具体工作。Maven 的 clean 是另一个生命周期，不要把表格误认为完整 Maven 定义。

pnpm scripts、uv build、Gradle task graph 也有自己的语义。迁移命令时要先问“目标是哪个输出、哪些前置会自动运行、失败后还会不会继续”，而不是把名称相似当成等价。

### 失败必须阻断错误产物

若 test 失败，本次 package 应为 not-run 或失败，不能保留一个看似新鲜的成功结论。最危险的情况是输出目录已有昨天的包：test 红了，文件仍存在，脚本只检查“文件存在”便上传。

防线包括：

1. 在可控目标目录执行 clean；
2. 每个阶段失败返回非零并停止依赖它的阶段；
3. 报告记录阶段状态，不只记录最终文件；
4. 产物摘要绑定本次输入和运行；
5. 发布使用本次流水线明确输出，而不是模糊通配旧目录。

clean 也不是“越猛越好”。只删除项目声明的构建目录，不删除源码、用户缓存或共享仓库；清理前知道所有权和回滚边界。

## 六、输入、操作、输出：构建证据的最小三元组

一次构建报告至少回答：

| 类别 | 应记录的非敏感信息 |
| --- | --- |
| 输入 | 源码提交、清单摘要、锁摘要、工具版本、目标平台、必要 profile |
| 操作 | 实际命令、工作目录、阶段顺序、是否离线、缓存策略 |
| 输出 | 每阶段状态、测试计数、制品路径与 SHA-256、退出码 |

只写“BUILD SUCCESS”缺少输入绑定；只保存包缺少生成过程；只保存命令缺少实际结果。三者结合，别人才有机会复现和反驳。

### 摘要是什么

SHA-256 把任意字节映射为固定长度摘要。相同字节得到相同摘要；不同摘要可确定字节不同。相同摘要在正常工程语境下是强同一证据，但不证明业务正确、来源可信或无恶意。摘要比较的是字节，不是“看起来相同”的文件内容。

如果压缩包包含当前时间，即使程序逻辑相同，字节摘要也会不同。应固定或去除非语义时间戳、稳定条目顺序、编码、权限和生成器版本。

## 七、可重复、可复现和密闭不是一句话

团队对术语有不同精确定义，本章使用以下操作性区分：

- **重复构建**：同一环境再次运行得到相同结果；
- **可复现构建**：独立环境用声明输入能得到字节相同或按契约等价的制品；
- **密闭构建**：构建只依赖明确提供的输入，不偷偷读取主机时间、网络、用户目录等；
- **可追溯构建**：能从制品反查源、依赖、工具和构建证据。

同机连续两次摘要相同只是起点。Apache Maven 可重复构建指南也明确提醒，本地比较不能证明第三方复现，因为用户名、当前目录等环境泄漏仍可能存在。真正验证要换独立环境。

### 常见环境泄漏

- 当前时间和时区；
- 用户名、home 和绝对工作路径；
- 区域设置、默认字符编码和换行；
- 文件系统遍历顺序与权限；
- CPU/操作系统目标；
- 未固定的 JDK、构建工具和插件；
- 环境变量、代理与隐式配置；
- 网络仓库当天状态；
- 未清理的上次输出或全局缓存。

Maven 项目可使用 `project.build.outputTimestamp` 等机制控制部分输出时间；具体插件仍需支持。不要因为配置了一个属性就宣布整个构建可复现。

## 八、PATH、wrapper 与子进程环境是构建输入

shell 按 PATH 顺序寻找命令。终端 `mvn -v` 正确，不代表 IDE、CI 或脚本子进程使用同一路径。证据应包括：

1. `type -a` 或平台等价命令列出的候选；
2. 实际解析的绝对可执行文件；
3. 工具报告的自身版本和运行时；
4. 项目 wrapper 或固定入口；
5. CI 中同样的版本输出。

wrapper 的价值是把构建工具入口和版本约束项目化，但它本身也有脚本和下载来源，需要审查与校验。全局工具可用于启动 wrapper，不能凭全局版本替代项目证据。

环境变量只存在于进程及其派生环境。父进程设置后，子进程是否看见取决于是否导出、启动方式和显式覆盖；子进程修改不会反向改变已经运行的父进程。若脚本清空环境或 IDE 从旧进程启动，变量可能缺失。

报告只保存必要的非敏感变量，例如 `BUILD_PROFILE=offline`；不要打印整个 `env`，其中可能有云密钥、token 和内部代理。

## 九、依赖还有使用阶段、可选性和排除边界

版本只是依赖契约的一维。真实工具通常还区分依赖在哪个阶段可见。Java 项目可有编译、运行、测试等 classpath；前端项目常区分运行依赖与开发工具；Python 也可按开发、测试或可选功能分组。名称相似不代表语义相同，应查对应工具官方定义。

若测试框架意外进入生产运行包，会增加体积和攻击面；若运行所需驱动只在 compile 阶段可见，本地编译能过，启动却失败。因此依赖树报告至少要能回答“通过哪条路径、在哪个阶段、为什么进入”。只比较版本列表可能漏掉 scope 变化。

可选依赖表达“提供方支持某功能，但消费者不会无条件继承”；排除规则切断某条传递边。它们不是随手消除冲突的按钮。排除 B 后，如果源码或运行时确实需要 B，问题会从解析冲突变成编译/启动失败。每个 exclusion 都应有原因、替代依赖和测试证据。

### 构建插件也是输入

编译器插件、测试运行器、打包器和代码生成器可以改变输出，必须像库依赖一样治理。固定项目库却让插件使用动态版本，仍可能得到漂移产物。Maven 官方依赖机制还特别说明，项目 dependency management 不会自动管理插件自身的传递依赖；不要以为一张 BOM 控制了整条构建工具链。

生成代码也要注明生成器版本、输入 schema、参数和输出校验。若生成文件提交仓库，要验证重新生成无差异；若不提交，构建环境必须能离线取得生成器并在正确阶段执行。

## 十、把“可重复”写成可验收矩阵

一个可操作验收不写“应该可重复”，而是分场景预测：

| 场景 | 受控变量 | expected |
| --- | --- | --- |
| 同机热缓存两次 | 同提交、锁、工具、环境 | 阶段全过，artifact 摘要相同 |
| 同机隔离冷缓存 | 新临时缓存，本地源仓库固定 | 可取得全部锁定包，摘要相同 |
| 缺一个锁定包 | 空缓存、源仓库删包 | validate 失败，package not-run |
| 仓库新增允许版本 | 未锁解析 | 解析树可能变化，故障被观察 |
| 仓库新增允许版本 | 已锁解析 | 选择与 artifact 不变 |
| 注入测试缺陷 | 输入保持，oracle 变红 | test failed，无本次 artifact |
| 独立机器 | 相同声明输入、不同用户名/路径 | 摘要相同才增加第三方复现证据 |

矩阵把“成功路径”和“应该失败的路径”并列。只验证全绿无法证明阶段边真的连接；只有缺包时 validate 红、测试错时 package 不运行，才说明构建器会拒绝不完整输入。

### 变更、迁移与回滚

升级依赖或工具时先保存旧解析树、锁、artifact 摘要和验证命令；再更新一个有边界的集合，解释直接/传递变化，执行冷/热构建与故障用例。回滚不是清空所有缓存，而是恢复旧清单/锁和工具入口，从隔离缓存重建旧 artifact。

若新版本包含安全修复但破坏兼容，应明确影响、迁移期限和临时缓解，不能无限冻结旧版；也不能为追“最新”跳过测试。长期目标是自动、可审查的更新流水线，失败时保留旧可部署制品和完整证据。

## 十一、运行完全离线的教学构建器

示例位于 [examples/encyclopedia/ch.foundations.dependencies-build-packages](../../../examples/encyclopedia/ch.foundations.dependencies-build-packages/README.md)。它只使用 Ruby 标准库和随仓库提交的 JSON，不读写用户 Maven/pnpm/uv 缓存：

```bash
ruby examples/encyclopedia/ch.foundations.dependencies-build-packages/verify.rb
```

先预测以下结果：

1. wrong-bin 在 PATH 前时选择教学工具 0.8，顺序修复后选择 1.0；
2. 显式继承 `FACTORYCARE_BUILD_PROFILE=offline` 的子进程 exit 0，移除变量后 exit 9；
3. `fc-report` 直接依赖 `fc-format`，lock 固定二者 1.0.0 和内容摘要；
4. 冷缓存两次 miss、热缓存两次 hit，但 artifact SHA-256 相同；
5. 源仓库删掉传递依赖时，热缓存会遮蔽，空缓存 validate 失败；
6. 候选新增 1.2.0 后未锁最高选择漂移，已锁构建仍生成相同 artifact；
7. 注入 test failure 后 package 为 not-run，artifact 摘要为 null。

验证器把临时缓存和产物放入系统临时目录，并在进程结束后释放。它不会改 PATH、shell 配置或全局仓库。`project.lock.json` 是本章教学格式，不应复制到真实 Maven 项目假装官方锁文件。

## 十二、四类故障的分阶段诊断

### 故障一：PATH 选错工具

症状可能是参数不认识、插件行为不同或产物格式变化。先记录命令解析路径和版本；把预期工具目录放在正确位置或使用项目 wrapper；重新打开对应进程并复验。不要先改源码迁就错误工具。

### 故障二：环境没有传入子进程

父 shell 显示变量，但构建子进程报告缺失。确认变量是否 export、脚本是否清空环境、IDE/CI 的进程起点和显式覆盖。用一个只打印目标变量是否存在的脱敏探针验证，避免泄露完整环境。

### 故障三：缓存掩盖缺依赖

老机器通过、新机器失败。保存热缓存结果后，在临时空缓存中重建；若缺少锁定包，首个可信失败应在解析/validate，不应继续 compile/package。修复仓库来源或离线包集合，再同时重跑冷、热路径。

### 故障四：未锁版本漂移

源码不变但解析树或摘要变化。比较前后解析报告、候选仓库和约束；引入工具支持的锁定/依赖管理，明确升级动作；恢复后从隔离缓存重建。不要用“把今天解析结果手写进日志”代替项目约束。

### 故障五：测试失败却看到包

检查包的时间和摘要是否属于本次运行。若 clean 未执行或流水线继续，旧包就是不可信证据。修复阶段依赖，注入一个真实 test failure 确认 package not-run，再恢复测试并重新生成包。

## 十三、FactoryCare 独立构建任务

使用 [实验目录](../../../labs/encyclopedia/ch.foundations.dependencies-build-packages/README.md)：

1. 在 worksheet 先写工具、环境、依赖、缓存、漂移和阶段 expected；
2. 画根项目→直接依赖→传递依赖树；
3. 记录 lock 中版本和摘要；
4. 执行离线验证器，保存冷/热 artifact 摘要；
5. 找出缓存遮蔽时的首个可信失败；
6. 解释未锁 1.1→1.2 与已锁 1.0 不变；
7. 解释 test failed 后为何 package 必须 not-run；
8. 写明 T1 教学模型没有验证真实 Maven、pnpm、uv 或第三方跨机器重建。

验收不是“脚本最后打印 PASS”而已。你必须能指出每个 expected 的来源、改变一个版本规则、读懂报告并制造—恢复一个故障。

## 十四、常见反模式

### “能下载就是依赖正确”

下载只证明有字节可取。还要验证坐标、版本、来源、摘要、使用阶段和测试。

### “缓存越大越可靠”

大缓存让热构建快，也更容易遮蔽缺失来源。保留缓存，同时加入隔离冷构建证据。

### “每次取最新最安全”

最新可能含修复，也可能引入不兼容。安全更新应是主动、可审查、可回滚的变更，而非无人知晓的解析漂移。

### “lock 提交后永不更新”

冻结降低漂移但会积累风险。按节奏更新，记录原因与验证。

### “package 文件存在就发布”

存在可能来自旧运行。发布必须绑定本次成功阶段和摘要。

### “清缓存解决一切”

直接删除全局缓存会破坏证据和其他项目。先隔离临时缓存复现，确认所有权后才做定向维护。

## 十五、AI 协作审查清单

AI 可以帮助解释树、生成报告解析器或提出故障假设，但要逐项核对：

- 是否把不同生态的约束/锁机制混为一谈；
- 是否编造版本或插件参数；
- 是否偷偷加入公网下载；
- 是否建议删除整个用户缓存；
- 是否把认证配置输出到日志；
- 是否在 test 失败后继续打包；
- 是否比较了真实 artifact 字节摘要；
- 是否将同机两次相等夸大为跨机器复现；
- 是否记录未验证的插件、平台和 CI 行为。

AI 生成的绿色脚本仍要通过故障注入证明会红。最有价值的反例是：删掉本地源包但保留热缓存；若脚本仍宣称仓库完整，预言就不够。

## 十六、120 秒复述模板

> 直接依赖由根清单声明，传递依赖沿依赖图进入。版本约束定义候选集合，解析器选择具体版本，锁或依赖管理固定选择；算法因工具而异。仓库是来源，缓存是副本，热缓存通过不能证明冷机器完整。构建生命周期把声明输入依次变成输出，test 失败必须阻断 package。可重复性要固定源码、依赖、插件、工具和环境，并比较产物字节摘要；同机两次相同仍不能证明第三方复现。反例是 test 已失败但旧包仍在目录，脚本只检查文件存在便误报成功。

## 复习检查

1. 直接依赖与传递依赖如何从图上识别？
2. 约束、解析结果和锁文件分别处于哪个时点？
3. Maven nearest definition 为什么不能当成所有生态规则？
4. 热缓存通过、冷缓存失败能推出什么？
5. `--offline` 为什么不能生成缺失包？
6. phase 和具体 task/goal 有何区别？
7. test 失败后旧 package 为何不可信？
8. 构建报告的输入、操作、输出分别是什么？
9. SHA-256 相同能证明什么，不能证明什么？
10. 哪些环境泄漏会破坏字节复现？
11. PATH 与子进程环境怎样影响实际工具？
12. 如何安全诊断缓存，而不删除用户全局仓库？

## 官方一手资料与范围声明

以下资料于 **2026-07-16** 从 Apache Maven 官方站点复核：

- [Maven 依赖机制](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html)：传递依赖、nearest definition、dependency management 与 BOM；
- [Maven 构建生命周期](https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle)：default/clean/site、phase 顺序与 plugin goal；
- [Maven 仓库介绍](https://maven.apache.org/guides/introduction/introduction-to-repositories.html)：本地/远程仓库、缓存与 `-o` 离线构建；
- [Maven 可重复构建指南](https://maven.apache.org/guides/mini/guide-reproducible-builds.html)：`project.build.outputTimestamp`、产物比较和本地复验的证据边界；
- [Maven 3.9.16 发布说明](https://maven.apache.org/docs/3.9.16/release-notes.html)：复核日官方当前 Maven 3 下载线为 3.9.16；本章不据此假定所有机器已升级。

教学 resolver、`1.x`、最低/最高策略、JSON lock 与五阶段报告属于本章**设计判断和可执行模型**，不是 Maven 规范。未验证项包括真实 Maven/pnpm/uv 解析、插件联网行为、私有仓库认证、跨操作系统制品复现、供应链签名与独立第三方重建；它们留待对应专章和后续 review。
