# 第 8 周：并发、线程池、CompletableFuture、虚拟线程与 JVM 基础

## 定位

本周建立足够应对企业 Java 开发和面试的并发/JVM 基础：知道共享状态为什么危险，知道如何选择平台线程池、CompletableFuture 或虚拟线程，也知道如何通过线程转储和日志定位阻塞。重点是正确性、资源边界和可取消，不研究底层调度器源码。

时间预算：15—18 小时。所有并发实验都必须先有串行正确版本和可重复测试。

## 前置

- 熟练使用集合、异常、时间、Lambda、Stream 和 JUnit。
- FactoryCare 查询与统计服务为纯 Java，可构造固定测试数据。
- 能区分 CPU 计算和模拟 I/O 等待。
- 使用 JDK 25 LTS，不启用 preview 特性。

## 目标

- 理解线程、任务、并发、并行、竞态、可见性和原子性。
- 正确使用 ExecutorService、队列、拒绝策略和生命周期。
- 使用 CompletableFuture 组合独立任务并处理超时和异常。
- 理解虚拟线程适合阻塞 I/O，不适合长时间 CPU 密集工作的原因。
- 知道虚拟线程不消除数据库连接、限流和共享状态约束。
- 建立 JVM 运行时、类加载、堆栈、GC、JIT 和诊断工具的高层模型。
- 为 FactoryCare 实现受控的设备信息并发补全实验。

## 完整概念清单

### 并发基本问题

- 进程、平台线程、虚拟线程、任务。
- 并发与并行；吞吐量与延迟。
- 共享可变状态、竞态条件、原子性、可见性、顺序性。
- `synchronized` 的互斥和可见性高层语义。
- `volatile` 保证可见性和一定顺序，不使复合操作自动原子。
- `AtomicInteger/AtomicReference` 的适用场景。
- 不可变对象、线程封闭和减少共享优先于加锁。
- 死锁、活锁、饥饿的识别；不深入形式化证明。

### 线程中断与协调

- `start`、`join`、sleep 和线程状态的高层含义。
- interrupt 是协作式取消信号，不是强制杀死线程。
- 捕获 `InterruptedException` 后恢复中断状态或向上处理。
- `CountDownLatch`、Semaphore 的基本使用场景。
- 并发集合与普通集合的区别；复合业务操作仍需设计原子边界。

### ExecutorService 与线程池

- 将任务提交与线程创建分离。
- core/max pool、工作队列、线程工厂、拒绝策略的高层关系。
- 无界队列、无限提交和线程池耗尽风险。
- CPU 密集与阻塞 I/O 对并发度的不同约束，不死背固定公式。
- `submit/execute`、Future、取消、超时、shutdown/awaitTermination。
- 应用拥有的 Executor 必须显式管理生命周期。
- 不在业务代码中随处创建新线程池；不依赖默认 common pool 承担关键任务。

### CompletableFuture

- 创建已完成结果、异步 supplier、指定 Executor。
- `thenApply`、`thenCompose`、`thenCombine`、`allOf`。
- 同步/Async 后缀的执行线程含义。
- `exceptionally`、`handle`、`whenComplete` 的不同职责。
- `orTimeout/completeOnTimeout` 与业务降级。
- 异常包装、部分成功、取消传播和上下文丢失。
- 不使用 `join()` 把所有异步流程重新串行化。

### 虚拟线程

- JDK 虚拟线程由运行时调度，创建成本远小于平台线程。
- 适合大量彼此独立、主要阻塞等待 I/O 的任务。
- 不适合把 CPU 密集任务无限并发。
- 使用 `Thread.ofVirtual()`、`Thread.startVirtualThread`、`Executors.newVirtualThreadPerTaskExecutor()` 的基本方式。
- 不池化虚拟线程；按任务创建，同时对数据库连接、外部 API 等稀缺资源设置独立并发上限。
- ThreadLocal、锁竞争和 pinning 只了解风险与诊断，不研究实现源码。
- 虚拟线程让同步代码更易扩展，但不自动提供超时、重试、幂等和背压。

### JVM 基础

- Java 源码、字节码、类加载、验证、链接和初始化的高层流程。
- 堆、线程栈、Metaspace、直接内存的用途。
- 对象通常在堆上，局部变量/栈帧的简化模型；避免绝对化表述。
- GC 回收不可达对象；年轻代/老年代只做实现层直觉。
- JIT 根据热点编译优化；基准测试不能用一次 `nanoTime` 下结论。
- StackOverflowError、OutOfMemoryError、死锁和高 CPU 的现象区别。
- `jcmd`、`jstack`/线程转储、JFR 的用途；本周只做基础采集和阅读。

### 并发测试与观测

- 并发测试避免只靠 sleep；使用 latch/barrier 协调。
- 超时、防止测试永久挂起。
- 记录任务 ID、线程名、开始结束和失败原因。
- 对比前先确保工作量一致，区分正确性实验与性能基准。

## 任务分配

| 模块 | 时间 | 任务 |
| --- | ---: | --- |
| 并发问题 | 2.5h | 竞态、可见性、原子性、不可变与锁实验 |
| 线程池 | 2.5h | 有界池、队列、拒绝、Future、关闭和中断 |
| CompletableFuture | 2.5h | 组合、超时、异常和指定 Executor |
| 虚拟线程 | 2h | 阻塞 I/O 模拟、资源限流和平台线程对比 |
| JVM/诊断 | 2h | 堆栈模型、线程转储、jcmd/JFR 基础 |
| FactoryCare | 2.5—3.5h | 设备信息补全、取消、超时、部分失败测试 |
| 无 AI训练 | 2h | 限时故障定位与口述 |
| 求职动作 | 1h | Java并发/JVM口述与投递 |

## FactoryCare项目增量

实现 `EquipmentEnrichmentService`，模拟从三个独立慢数据源补全设备信息：保养摘要、备件可用性、最近故障统计。

实现并比较：

1. 串行版本：作为正确性基线。
2. 有界平台线程池 + CompletableFuture：显式 Executor、超时、部分失败策略。
3. 每任务虚拟线程：保持同步风格，对模拟外部资源使用 Semaphore 限制并发。

统一要求：

- 总超时和单任务失败行为明确。
- 中断不被吞掉；Executor 正确关闭。
- 同一设备结果可关联，不能因完成顺序错配。
- 失败来源可从日志定位，测试不会永久挂起。
- 只做可控实验，不宣称微基准代表生产性能。

## AI协作边界

可以让 AI：

- 根据串行流程提出并发依赖图。
- 审查线程池是否无界、Executor 是否泄漏、中断是否丢失。
- 生成超时、部分失败、顺序错配和资源耗尽测试候选。
- 帮助解释线程转储，但你必须对应到代码位置验证。

必须由你完成：

- 先保证串行版本和业务结果正确。
- 决定哪些任务独立、哪些结果必须全部成功、哪些可降级。
- 选择平台池或虚拟线程并说明资源边界。
- 能亲手修复一个竞态、一次中断吞噬和一次线程池未关闭。

## 无AI训练

本周从求职/复盘时段预留45—60分钟完成并记录：排序或二分题；写清有序前提、区间语义和复杂度。

关闭 AI，限时120分钟：

1. 给补全服务增加一个会超时的数据源。
2. 实现“保养摘要必须成功，备件信息可以降级”的策略。
3. 修复一处故意加入的共享 ArrayList 并发写问题。
4. 采集线程转储，指出等待、运行和已完成任务的大致位置。
5. 口述为什么虚拟线程不能突破数据库连接池或第三方 API 限额。

## 求职动作（恢复求职后启用）

- 准备线程/进程、并发/并行、synchronized/volatile、线程池参数、CompletableFuture、虚拟线程、堆/栈/GC/JIT 的口述。
- 回答时优先讲正确性、资源和故障，不背线程池“标准参数答案”。
- 从 5 个 Java 岗位记录并发和 JVM 要求层级，区分“了解”“熟悉”“调优经验”。
- 简历只写“完成有界线程池、CompletableFuture 与虚拟线程对照实验”，不写“高并发架构经验”。

## 交付物

- 串行、平台线程池、虚拟线程三版补全实验。
- 超时、部分失败、中断、错配和资源关闭测试。
- 一份线程模型选择记录与风险清单。
- 一份线程转储和 JVM 运行时高层示意。
- 无 AI 并发故障修复记录。

## 验收标准

- 能用具体例子解释竞态、可见性、原子性和中断。
- 线程池有界、拒绝行为明确、生命周期完整，不使用关键业务默认 common pool。
- CompletableFuture 能组合、超时、降级并保留失败来源。
- 能说明虚拟线程适合阻塞 I/O、为何不池化、为何仍要限制稀缺资源。
- 能区分堆、栈、Metaspace、GC、JIT、死锁和 OOM 的高层职责/现象。
- 测试不会依赖长时间 sleep 或永久挂起。
- 无 AI 修复至少一个竞态和一个取消/超时问题。

## 明确不做

- 不研究 JDK 调度器、ForkJoinPool、锁实现、JMM 形式化规则或 GC 算法源码。
- 不使用仍为 preview 的结构化并发；Scoped Values虽已在JDK 25正式定稿，本轮也不作为项目依赖。
- 不做伪生产压测，不根据一次本机计时宣称性能提升。
- 不引入 Reactor、WebFlux、消息队列、分布式锁或缓存。
- 不把所有方法异步化，不为 CPU 密集任务无限创建虚拟线程。

## 官方资料

- [Java SE 25 Concurrency Guide](https://docs.oracle.com/en/java/javase/25/core/concurrency.html)
- [Thread API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Thread.html)
- [Executors API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/Executors.html)
- [CompletableFuture API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/CompletableFuture.html)
- [Java Virtual Threads](https://docs.oracle.com/en/java/javase/25/core/virtual-threads.html)
- [JDK 25 JVM Guide](https://docs.oracle.com/en/java/javase/25/vm/)
- [JDK Flight Recorder](https://docs.oracle.com/en/java/javase/25/jfapi/)
