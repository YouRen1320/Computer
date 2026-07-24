---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.logging-jvm-diagnostics
title: 结构化日志、线程转储、JFR 与 JVM 故障诊断
responsibility: 教授从日志和 JVM 运行时证据定位故障，不在本章建立分布式追踪或 SLO 告警体系
volume: '03'
order: 18
level: L2+
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.logging-jvm-diagnostics.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-engineering.maven-reproducible-builds
- ch.java-engineering.threads-jmm
version_surfaces:
- jdk-25
- maven-3
- observability
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释结构化日志、线程转储、JFR 与 JVM 故障诊断的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-structured-logging
  - java-jvm-diagnostics
  covers_topics:
  - java.logging-level-context
  - java.structured-log
  - java.sensitive-log-redaction
  - java.thread-dump
  - java.jfr
  - java.gc-memory-symptom
  uses_capabilities:
  - java.build-testing
  - java.concurrency-runtime
  - java.exceptions-resources
  - foundation.verification-debug-test
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：为并发工单任务输出含 trace/order/thread 的结构化日志，并采集一次线程转储和短 JFR 记录关联症状
  covers_topic_groups:
  - java-structured-logging
  - java-jvm-diagnostics
  covers_topics:
  - java.logging-level-context
  - java.structured-log
  - java.sensitive-log-redaction
  - java.thread-dump
  - java.jfr
  - java.gc-memory-symptom
  uses_capabilities:
  - java.build-testing
  - java.concurrency-runtime
  - java.exceptions-resources
  - foundation.verification-debug-test
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入线程阻塞、日志缺关联 ID 和敏感字段泄露，使用 dump/JFR/日志定位并加脱敏与上下文
  covers_topic_groups:
  - java-structured-logging
  - java-jvm-diagnostics
  covers_topics:
  - java.logging-level-context
  - java.structured-log
  - java.sensitive-log-redaction
  - java.thread-dump
  - java.jfr
  - java.gc-memory-symptom
  uses_capabilities:
  - java.build-testing
  - java.concurrency-runtime
  - java.exceptions-resources
  - foundation.verification-debug-test
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# 结构化日志、线程转储、JFR 与 JVM 故障诊断

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Maven 生命周期、依赖范围、插件与可重复构建》](ch.java-engineering.maven-reproducible-builds.md)：独立完成结构化日志、JVM 诊断前，必须先具备「Maven 生命周期、依赖范围、插件与可重复构建」已经验证的知识与失败边界
- [《线程、Java 内存模型、同步与锁》](ch.java-engineering.threads-jmm.md)：独立完成结构化日志、JVM 诊断前，必须先具备「线程、Java 内存模型、同步与锁」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。正文与离线夹具可以训练证据阅读，但不能替代目标环境授权、现场采样与容量基线，也不会自动修改 `PROGRESS.md`。

日志与 JVM 工具的共同目标不是“多打印一点”，而是把故障假设变成可检验的证据。用户说“系统卡了”只是症状；一条 WARN、一次线程快照或一段 GC 日志也只是观测。可靠诊断要建立时间窗、请求关联、线程/锁关系、资源趋势和对照基线，再说明证据能支持什么、不能支持什么。

本章从结构化日志开始，覆盖级别、稳定字段、correlation ID、异常因果链与敏感信息边界；再建立 `jcmd`、`jstack`、线程转储、JFR、统一 JVM/GC 日志与性能测量的证据模型。重点是“先保全、再关联、后归因”，不会把一次快照写成确定根因，也不会在未授权进程上执行高影响命令。

配套工程以 **JDK 25** 的语言与工具语义为基线，Java 资产只读取固定夹具或运行本进程内检查，完全离线且输出确定。真实 `jcmd`／JFR 采样必须由学习者在自有、获授权的测试 JVM 上单独完成。官方资料复核日期为 **2026-07-17**。

## 1. 完成定义：从事件到证据链

完成本章应能交付：

1. 为同一 FactoryCare 请求输出包含 timestamp、level、event、correlation_id、order_id、thread 与 outcome 的结构化事件，字段名稳定且值可脱敏。
2. 解释 TRACE、DEBUG、INFO、WARN/WARNING、ERROR 的运行语义，并能指出“级别高”不自动等于“需要报警”。
3. 记录异常对象而非只拼接 message，保留类型、cause 与栈；避免同一异常在每层重复打印。
4. 从线程转储找出 BLOCKED 线程、锁标识、拥有者和相关栈；明确一次 dump 只能证明采样瞬间。
5. 为已授权测试 JVM 写出 `jcmd`／JFR 采样计划，包括命令影响、时长、输出路径、磁盘与隐私风险。
6. 从 GC/JFR 证据区分暂停、分配速率、live set 与泄漏假设，不以单次回收前后值或一次 `nanoTime` 宣称性能结论。

配套入口：

- [结构化日志与证据摘要示例](../../../examples/encyclopedia/ch.java-engineering.logging-jvm-diagnostics/README.md)
- [FactoryCare JVM 诊断实验](../../../labs/encyclopedia/ch.java-engineering.logging-jvm-diagnostics/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.logging-jvm-diagnostics/README.md)

公开练习使用脱敏、固定的线程 dump 与 GC 日志片段，不连接生产、不发现本机其他进程。私有解析只在完成预测与修复后核对。

## 2. 日志是事件记录，不是散文

“开始处理”“这里到了”“出错了”对作者当下可能有用，却缺少机器可关联的主体、动作与结果。结构化日志把一条事件表示成稳定字段集合；存储格式可以是 JSON、logfmt 或日志框架的键值参数，关键是字段语义先于渲染格式。

一条业务事件至少考虑：

- `timestamp`：事件发生时间，明确时区，跨系统通常使用 UTC；
- `level`：严重程度与运营意图；
- `event`：稳定、低基数的事件名，如 `work_order.assignment.failed`；
- `correlation_id`：一次请求或工作流的关联标识；
- 领域标识：`order_id`、`equipment_id` 等非敏感键；
- `component`／`operation`：哪个边界正在执行什么；
- `thread`：本地并发诊断需要时记录，不能替代请求上下文；
- `outcome`／`error_code`：稳定结果分类；
- `duration_ms`：有清晰起止定义时记录；
- throwable：异常类型、message、stack 与 cause，由日志后端作为异常对象处理。

字段 schema 应像 API 一样受控。把 `orderId`、`order_id`、`workOrder` 三种名字混用，会让查询、仪表板和告警各写一套兼容逻辑。重命名字段是数据契约变更，应有迁移窗口或查询同步更新。自由文本 message 可供人阅读，但不能成为唯一可查询信息。

结构化不等于把整个对象序列化。请求 DTO、用户对象和 HTTP headers 往往含密码、token、Cookie、地址与个人信息。字段应按允许列表选择，不按“先全打再黑名单删除”。对象 `toString()` 可能在未来新增敏感字段，日志调用却不会提醒你。

## 3. 日志级别：表达运营语义

JDK 25 `System.Logger.Level` 按严重度定义 ALL、TRACE、DEBUG、INFO、WARNING、ERROR、OFF；常见第三方框架把 WARNING 命名为 WARN。名称映射由具体后端决定，业务团队仍需定义自己的使用合同。

可采用以下基线：

| 级别 | 适用语义 | 不应滥用 |
| --- | --- | --- |
| TRACE | 极细粒度诊断，短时开启，量大 | 生产长期记录每次循环或完整载荷 |
| DEBUG | 开发/诊断上下文，可关闭 | 关键审计事实只放 DEBUG |
| INFO | 正常生命周期中的重要、低频事实 | 每条数据读取都写 INFO |
| WARN | 可恢复异常、退化或需要关注的趋势 | 用户正常输错、每次重试都报警 |
| ERROR | 当前操作失败或数据一致性受威胁 | 已由上层完整处理的普通分支 |

级别不是报警策略。大量 ERROR 可能来自同一根因；单个 INFO 也可能是重要审计事件。告警通常基于错误率、延迟、饱和度和业务影响的聚合条件，本章不设计 SLO/告警体系。

一个异常只在拥有处理语义的边界记录。底层若只转换并继续抛出，上层会记录包含 cause 的完整异常，底层无需先打一遍 ERROR。每层都打印会产生三条栈、扩大成本并误导事件数。若底层必须补充不可由异常携带的边界信息，可用结构化字段记录一次，仍要避免泄密。

## 4. correlation ID：把同一工作流连起来

correlation ID 是跨多条日志的关联键，不等于安全凭据，也不必等于分布式 trace ID。入口处理规则通常是：

1. 从受信头或消息属性读取候选值；
2. 校验长度、字符集和格式，拒绝换行等日志注入字符；
3. 无值时生成；
4. 写入当前请求上下文和响应；
5. 调用下游时显式传播；
6. 异步任务创建时复制所需上下文；
7. 请求结束清理线程局部状态。

不能盲信客户端提供的值。攻击者可以提交超长字符串、换行或与他人请求相同的 ID，污染查询与日志。correlation ID 只用于关联，不用于授权、租户隔离或幂等判断。

`ThreadLocal` 在传统线程池中必须清理，否则线程复用会把前一个请求 ID 泄露给下一个请求。虚拟线程降低了某些复用问题，但上下文仍不会自动跨所有异步边界；具体框架可能使用 MDC、ScopedValue 或任务包装器。最稳妥的领域代码仍是把相关上下文作为显式参数或不可变上下文对象传递，在适配层绑定到日志框架。

一个请求可能触发多个子任务。可同时记录 correlation ID 与 task/job/order ID：前者串起入口旅程，后者让后台重试跨请求继续关联。字段含义必须文档化，避免同一个 `traceId` 有时代表 HTTP、有时代表工单。

## 5. 异常日志：保留因果，不制造泄露

只记录 `ex.getMessage()` 会丢失异常类型、栈和 cause；字符串拼接异常对象也可能只调用 `toString`。日志 API 通常有专门的 throwable 参数，应把异常对象传给它，让后端渲染完整链。

异常事件至少回答：

- 哪个稳定操作失败；
- 哪个非敏感实体受影响；
- 稳定错误码与恢复策略；
- 异常类型、栈和 cause；
- 是否会重试、已重试次数；
- correlation ID。

异常 message 本身也可能包含 SQL 参数、路径、邮箱、URL query、token 或上游完整响应。不能因为“这是异常”就绕过脱敏。可对外部输入先校验并用错误码描述；记录异常时设置访问控制与保留期；展示给用户的错误消息与内部诊断详情分离。

捕获后仅日志再吞掉异常会制造假成功。若当前层能恢复，应返回明确结果或转换为领域失败；若不能恢复，应保留 cause 继续传播。`throw new X(ex.getMessage())` 丢 cause，应使用带 cause 的构造器。日志不是异常处理策略。

## 6. 敏感信息与日志注入

默认不得记录：

- 密码、验证码、API key、Authorization、Cookie、session；
- 私钥、完整证书材料与数据库连接密码；
- 完整身份证、银行卡、手机号、邮箱等个人数据；
- 完整请求/响应体，除非经过数据分类和最小化审批；
- 用户上传文件内容或模型提示中的秘密；
- 可直接重放的签名 URL 与 reset token。

脱敏有多种强度：完全删除；固定标记 `[REDACTED]`；保留末四位；不可逆带密钥哈希用于关联。选择取决于用途与威胁模型。普通 hash 对低熵手机号可被枚举，不自动匿名。日志平台访问控制、传输加密、保留期和删除流程同样属于安全边界。

对字段名做规范化后再判定敏感性，例如大小写、连字符和下划线。黑名单会漏掉未来新字段，生产更推荐允许列表。对自由文本移除 CR/LF 或让结构化编码器转义，防止伪造新日志行。值长度也应设上限，避免日志放大与索引高基数。

不要在验证器里使用真实 token 证明脱敏。固定夹具应使用明显的虚构值；断言输出完全不含原文，并包含稳定脱敏标记。

## 7. 诊断流程：症状、假设、证据、结论

面对“下午 14:05 工单创建卡住”，先固定事实：

1. 影响起止时间、用户范围、版本与环境；
2. correlation/order ID 和入口结果；
3. CPU、内存、请求率、错误率与依赖状态；
4. 同时段日志、线程 dump、JFR/GC 证据；
5. 正常基线或变更前对照。

然后写可证伪假设，例如“线程在仓库连接池获取处等待”“锁竞争导致处理器 BLOCKED”“GC 暂停覆盖延迟峰值”。每个假设列所需证据和反证。不要先决定“肯定是 GC”再只寻找支持材料。

证据强度逐级增加：单条日志 < 同一关联链多事件 < 多次线程快照 < JFR 时间序列 < 可控环境复现。不同工具也会影响目标进程；采样前记录命令、操作者、时间、PID、JDK、影响级别与输出校验和。

## 8. `jcmd`：首选的 HotSpot 诊断入口

JDK 25 的 `jcmd` 向正在运行的 JVM 发送诊断命令。它必须在同一机器运行，并满足目标 JVM 的有效用户/组权限要求；容器中的 PID 与可见进程还受 namespace 限制。可用命令必须以目标 JVM 上的 `jcmd <pid> help` 为准，不能假定每个 JVM 都支持文档列出的全部命令。

常见只读/采样命令：

- `jcmd -l`：列出工具可见的 Java 进程；命令行可能含敏感参数，输出需保护。
- `jcmd <pid> VM.version` 与 `VM.flags`：记录运行时和实际 flag。
- `jcmd <pid> Thread.print -l`：打印线程栈及并发锁信息，官方标记影响为 Medium。
- `jcmd <pid> Thread.dump_to_file -format=json <file>`：JDK 25 可把线程信息写成 plain 或 JSON，适合大量虚拟线程，但格式仍属工具表面。
- `jcmd <pid> GC.heap_info`：通用堆摘要，影响为 Medium。
- `jcmd <pid> GC.class_histogram`：对象统计，官方标记 High，成本随堆大小与内容变化。
- `jcmd <pid> JFR.start ...`、`JFR.dump ...`、`JFR.stop ...`：控制 Flight Recording。

命令名中的 GC 不代表安全。`GC.run` 会请求 `System.gc()`；`GC.heap_dump` 与 class histogram 可能高影响、触发停顿、占用大量磁盘并包含敏感对象。生产执行前必须有授权、容量评估、输出保护与回滚/终止计划。本章验证器绝不对任意 PID 运行这些命令。

## 9. `jstack` 与线程转储

`jstack -l <pid>` 能打印线程栈与额外锁信息，但 JDK 25 工具文档明确标记它为 experimental、unsupported，并提示未来可能移除。新诊断流程优先 `jcmd <pid> Thread.print -l` 或 `Thread.dump_to_file`；保留 jstack 只是因为现场环境仍常见。不同 JDK 大版本的工具不应混用诊断另一个版本的 JVM。

线程转储是某一瞬间的 JVM 线程状态。平台线程常见字段包括线程名、Java 状态、栈帧、等待的 monitor 地址和锁拥有者。JDK `Thread.State` 语义：

- RUNNABLE：在 JVM 中可运行或运行，仍可能等待操作系统资源；不等于正在占满 CPU；
- BLOCKED：等待进入或重新进入 `synchronized` monitor；
- WAITING：无限期等待另一个动作，如 `Object.wait`、`join`、`park`；
- TIMED_WAITING：带时限的 sleep、wait、join 或 park；
- NEW／TERMINATED：未启动或已结束。

WAITING 不自动是故障，线程池 worker 和队列消费者正常空闲时就会等待。BLOCKED 也要看数量、持续时间、关键路径和锁拥有者。一次 dump 只能证明采样瞬间；经验上应在症状窗口采集多次、保留间隔和时间戳，观察同一线程是否反复停在同一栈。具体次数与间隔属于运营判断，不是 JDK 规范。

## 10. 如何读锁与死锁证据

先从受影响请求的线程或业务栈定位，再看最顶层非框架帧。若线程 `waiting to lock <0x...>`，搜索同一锁地址的 `locked <0x...>` 或 `Lock owner`，得到拥有者；继续查看拥有者在做什么。大量线程等待同一锁、拥有者执行慢 I/O，说明锁范围可能包住外部调用。

JVM 可以在转储末尾报告检测到的 Java-level deadlock，列出线程与互相等待的锁。这是强证据，但仍要保存完整 dump，确认涉及业务代码和时间窗。没有 deadlock 报告不等于没有活锁、线程饥饿、连接池耗尽、条件等待或外部 I/O 卡顿。

虚拟线程数量可能巨大，传统纯文本 dump 不适合逐行人工阅读。JDK 25 `Thread.dump_to_file` 的 JSON 输出和 JFR 事件更适合聚合；仍需用 task/correlation 字段把业务事件与线程证据关联。虚拟线程 WAITING 很常见，不应以数量直接判故障。

## 11. JFR：时间序列而非单张照片

Java Flight Recorder 在 JVM 内记录事件，可覆盖 CPU 采样、线程停顿、monitor、I/O、异常、分配与 GC。`default.jfc` 面向低开销持续记录，`profile.jfc` 收集更多信息、影响更大。官方 JDK 25 文档称标准固定时长 profiling recording 对多数应用的开销低于约 2%，但这是通用说明，不是你的服务保证；必须在代表性负载下测量自身开销。

一个受控短记录计划应写清：

- 目标 PID、环境和授权；
- 问题时间窗与预计 duration；
- settings 为 default 还是 profile；
- filename、磁盘余量、文件权限与保留期；
- 是否需要异常、socket、monitor、allocation 等事件；
- 记录开始/结束时间和关联发布版本；
- 停止、dump 与校验文件的步骤。

`path-to-gc-roots` 和 heap statistics 可能显著增加成本，甚至触发 old GC。只在怀疑泄漏且已有授权时开启，不应作为“多收一点总没坏处”的默认项。JFR 也是采样/事件数据：低样本数的 hot method 不能精确证明 CPU 百分比，未记录事件可能因为阈值、配置或采样不足。

使用 `jfr summary file.jfr` 查看事件概况，再按事件筛选或用 JMC 分析。诊断结论应引用事件类型、时间窗、样本数和基线，而不是只贴一张火焰图截图。

## 12. JVM 统一日志与 GC 证据

现代 HotSpot 使用 `-Xlog` 统一日志框架。`-Xlog:gc` 提供 GC 概要，`-Xlog:gc*` 展开相关 tag；G1 调优文档建议诊断时可从 `-Xlog:gc*=debug` 开始，再按需要收窄。详细度越高，输出量与开销越大，生产应先容量评估并设置文件轮转。

一条 GC pause 常含时间、GC id、原因、回收前后 heap 和暂停时长。它能证明某次收集发生及其暂停，但不能单独证明：

- 整个请求延迟都由 GC 造成，除非时间窗关联并排除其他停顿；
- heap 前后下降代表没有泄漏；
- heap 长期上升必然是泄漏，可能只是流量、缓存或尚未收集；
- Full GC 原因一定是 heap 太小，也可能是显式 `System.gc()`、humongous allocation 或外部工具；
- 某收集器参数在另一个负载上仍更优。

内存泄漏更接近“在相似负载与 GC 后，live set 持续增长且对象无法释放”。需要趋势、分配速率、对象直方图/heap dump 或 JFR path-to-roots 等进一步证据。heap dump 含完整对象图和敏感数据，体积与停顿风险高，必须受保护。

## 13. 把日志、dump、JFR 与指标对齐

单一工具很少给出完整根因。典型关联链：

1. INFO 记录请求入口 correlation_id 与 order_id；
2. WARN 显示仓库获取连接超过阈值；
3. 同时间多次 dump 显示关键线程 WAITING 在连接池；
4. JFR SocketRead 或 monitor 事件显示持续时长；
5. 数据库/依赖指标显示连接占满；
6. 修复后同负载基线的吞吐与延迟恢复。

如果 dump 显示 BLOCKED，而 JFR monitor 事件时间很短、CPU 饱和，锁可能不是主因。若 GC pause 为 12ms，而请求延迟为 8s，不能把 GC 当作充分解释。诊断要比较量级与时间重叠。

correlation ID 主要连接应用事件；线程名与 Java thread id 连接 dump/JFR；timestamp 连接 GC 与指标。不同机器时钟偏差会破坏关联，应有时钟同步与明确时区。本章固定夹具已对齐时间，仅用于训练，不证明真实系统时钟正确。

## 14. 性能证据边界

一次 `System.nanoTime` 前后相减不是可靠 benchmark。JVM 有解释执行、JIT 编译、类加载、逃逸分析、GC 与动态频率；操作系统还有调度和缓存。第一个样本与稳定状态可能完全不同，过小代码还会被消除或常量折叠。

微基准应使用 OpenJDK JMH，配置 warmup、measurement、fork、参数和结果单位，防止常见 JVM 优化陷阱；再报告硬件、JDK、JVM flags、样本分布与置信信息。即便 JMH 结果可靠，也只证明该微场景，不能外推完整 API 的吞吐与尾延迟。

服务性能验证还要有代表性数据、并发、请求分布、预热、稳态时长、资源上限与对照版本。至少报告 p50/p95/p99、吞吐、错误率、CPU、分配与 GC，而不是只报平均值。统计阈值和样本数由风险决定；“至少三次”之类只是经验起点，不是规范保证。

诊断工具会影响被测对象。详细日志增加 I/O 与分配，JFR profile 增加采样，class histogram/heap dump 可能停顿。报告必须写明采样配置和影响，最好用未采样基线对照。没有基线只能叫观测，不能叫回归结论。

## 15. 结构化日志的工程实现

在业务代码中定义稳定事件名与字段常量；在边界适配层把它们交给 SLF4J、Log4j2、System.Logger 或组织标准后端。本章不指定唯一框架。无论后端：

- 使用参数化/延迟消息，避免关闭级别时仍构造昂贵字符串；
- 让编码器处理转义，不手拼不合法 JSON；
- 键顺序不应成为查询合同，但确定性测试可使用有序 map；
- 数值保持数值，布尔保持布尔，不全部字符串化；
- 时间用明确格式与时区；
- exception 作为独立 throwable 参数；
- 高基数正文不作为 metric label；
- 日志写失败不能悄悄破坏核心交易，也不能无限递归记录自身失败。

生产日志异步化会改变丢失、顺序和背压语义。缓冲满时是阻塞、丢弃还是降级必须由系统策略决定。测试不能只看内存 appender；还要在组件层验证最终编码、rotation 和采集配置。

## 16. FactoryCare 故障场景

工单分派服务在高峰期“偶尔卡住”。应用事件记录 `work_order.dispatch.started`、`repository.connection.wait` 和 `work_order.dispatch.completed`，共享 correlation_id/order_id。第一次 dump 显示一个 worker BLOCKED 在 `AssignmentRegistry.assign`，另一个线程持有该 monitor 并在通知客户端读取 socket；第二、三次仍相同。JFR 同时间显示长 SocketRead 与 monitor enter，GC 最大暂停只有十几毫秒。

可支持的假设是“锁范围覆盖慢 I/O，造成关键线程竞争”；不能只凭第一张 dump 声称死锁，也不能看到一次 GC 就调 heap。修复方向是缩小 synchronized 区域、把外部调用移出锁并保留一致性策略。修复后用相同负载重测吞吐、尾延迟、错误率与锁等待，再确认日志关联和脱敏仍有效。

如果通知失败包含 Authorization header，先把日志泄露当安全事件处理：限制访问、按保留策略处置、轮换可能暴露的凭据，再修复字段允许列表。仅把后续输出改成 `***` 不能撤销已写入历史。

## 17. 实验工作流

### 17.1 示例

示例创建固定时间、固定 correlation 的结构化事件，证明字段顺序、换行转义与敏感键脱敏；再解析内嵌线程/GC 夹具。验证器还运行“缺 correlation”和“明文 token”两个预期失败。先读 README 写出精确输出，再运行。

### 17.2 诊断实验

实验读取固定线程 dump 与统一 GC 日志，输出状态计数、锁拥有者、deadlock 标记、暂停总量和最大值。四个故障分别证明：敏感值泄露、一次快照越权归因、单样本 benchmark 和只记异常 message 都必须失败。夹具是教学证据，不代表解析器可兼容所有 JDK 文本格式。

### 17.3 独立练习

starter 的脱敏器、correlation 校验与证据门禁未完成，验证器应稳定失败。学习者先预测首个故障，再实现允许列表与采样下限；完成后运行相同 JDK 25 命令，最后核对私有解析。不得把真实生产 dump 或 token 复制进练习。

### 17.4 真实工具练习（手动、需授权）

只对自己启动的测试 JVM：

1. 保存 `java -version`、PID 与启动参数的脱敏摘要；
2. 运行 `jcmd <pid> help`，记录可用命令；
3. 在无业务数据的测试负载下采集 `Thread.print -l`；
4. 启动短 `JFR.start duration=... settings=profile filename=...`；
5. 用 `jfr summary` 检查文件；
6. 删除或受控保存证据。

教材自动验证不执行这一段，因此它是明确的未验证现场项。

## 18. 故障矩阵

| 现象 | 不能直接下的结论 | 下一证据 |
| --- | --- | --- |
| 一条 ERROR | 服务整体不可用 | 同时间错误率、入口结果、影响范围 |
| RUNNABLE 很多 | CPU 一定满 | OS/JFR CPU 与多次栈采样 |
| 一线程 BLOCKED | 发生死锁 | 锁拥有者、等待环、多次 dump |
| WAITING 很多 | 线程泄漏 | 线程角色、队列、趋势与基线 |
| GC 后 heap 降低 | 没有泄漏 | 相似负载下 post-GC live set 趋势 |
| Full GC 一次 | 必须加 heap | 原因、分配率、humongous、显式 GC |
| JFR hot method 居首 | 精确占用该百分比 | 样本数、CPU load、调用树与复现 |
| 一次耗时变快 | 优化成功 | 预热、多个 fork/样本与代表性负载 |
| correlation 缺失 | 只能加 message | 入口生成、传播与异步上下文边界 |
| token 已脱敏 | 日志完全安全 | 允许列表、异常、headers、访问/保留 |

## 19. 120 秒口述模板

1. 结构化日志以稳定 event 和字段描述业务事件；level 表达运营语义，报警另有聚合策略。
2. correlation ID 在入口校验/生成，显式传播，不能用于授权；异常要作为 throwable 保留 cause 与栈。
3. 敏感字段默认不记录，使用允许列表和编码转义；脱敏不替代访问控制与保留期。
4. `jcmd Thread.print -l` 是 JDK 25 的主要线程诊断入口；`jstack` 仍可用但官方标记 experimental/unsupported。
5. dump 是瞬时快照；RUNNABLE 不等于占 CPU，WAITING 不等于故障，应以多次样本、锁拥有者和 JFR 时间序列关联。
6. GC 日志与 JFR 支持假设，但一次 pause、一次 heap 前后值或一次计时都不能证明泄漏和性能结论。

反例可以讲：“看到一个 BLOCKED 线程就宣布死锁并重启。实际上没有等待环，下一张 dump 已消失；正确做法是保存多次 dump、查锁拥有者与症状时间窗，再决定根因。”

## 20. 采样前后清单

### 采样前

- 目标进程、环境、PID 和版本已确认；
- 获得权限，命令影响级别已查；
- 症状窗口、假设和所需事件明确；
- 磁盘、文件权限、敏感数据与保留期已评估；
- 有停止、清理与服务降级计划；
- 不使用跨大版本 JDK 工具诊断目标 JVM。

### 日志审查

- event/字段名稳定且文档化；
- correlation/order/thread 能关联但不承担授权；
- throwable 类型、cause、stack 保留；
- token、Cookie、密码、个人数据不出现；
- 自由文本换行被转义，值长度受限；
- 同一异常没有在多层重复 ERROR；
- DEBUG/TRACE 可关闭且无关键审计事实丢失。

### 结论前

- 有时间窗与正常基线；
- 单快照与趋势明确区分；
- 样本数、阈值和工具配置已记录；
- 相关性没有被写成因果；
- 工具开销与数据缺口已声明；
- 修复后在同条件重放原症状与对照指标。

## 21. 版本敏感面

`jcmd` 可用命令、影响描述、线程 dump 文本/JSON、JFR 事件和 `-Xlog` tag 都属于 HotSpot/JDK 工具表面。运行时必须先查询目标 JVM 的 help。第三方日志框架的 MDC、结构化参数、异步队列、默认后端和敏感数据插件也会随版本变化；本章只规定通用合同。

JDK `System.Logger` 的级别名为 WARNING，而许多框架显示 WARN；不要因此创建两个业务严重度。JFR 默认阈值和配置会影响“没有看到事件”的含义。GC 日志格式明确可能演进，教学解析器只针对提交的固定夹具，不应直接成为生产解析器。

## 22. 官方资料

- [JDK 25 System.Logger.Level API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/System.Logger.Level.html)
- [JDK 25 jcmd 工具说明](https://docs.oracle.com/en/java/javase/25/docs/specs/man/jcmd.html)
- [JDK 25 jstack 工具说明](https://docs.oracle.com/en/java/javase/25/docs/specs/man/jstack.html)
- [JDK 25 jfr 工具说明](https://docs.oracle.com/en/java/javase/25/docs/specs/man/jfr.html)
- [JDK 25：使用 JFR 排查性能问题](https://docs.oracle.com/en/java/javase/25/troubleshoot/troubleshoot-performance-issues-using-jfr.html)
- [JDK 25 Thread.State API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Thread.State.html)
- [JDK 25 GC Tuning Guide](https://docs.oracle.com/en/java/javase/25/gctuning/index.html)
- [OpenJDK JEP 158：Unified JVM Logging](https://openjdk.org/jeps/158)
- [OpenJDK JEP 271：Unified GC Logging](https://openjdk.org/jeps/271)
- [OpenJDK JMH](https://openjdk.org/projects/code-tools/jmh/)

命令影响、JFR 开销与线程状态以官方资料为准；“采多次 dump”“先状态验证再归因”等具体诊断顺序是行业经验，应结合现场风险、权限和项目基线。

## 23. 明确不做

本章不搭建 Elasticsearch/Loki、OpenTelemetry、分布式追踪、指标平台、SLO 或告警策略；不对生产 PID 自动执行诊断；不采集 heap dump；不把固定夹具解析器包装成通用运维工具；不做 GC 参数调优结论；不把一次 benchmark 当容量承诺。目标是建立结构化日志、安全字段、线程/JFR/GC 证据边界与可重放诊断思维。
