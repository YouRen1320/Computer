---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.executors-virtual-threads
title: Executor、Future、取消与虚拟线程
responsibility: 教授任务调度、等待和协作式取消，不把虚拟线程当作消除共享状态问题的工具
volume: '03'
order: 13
level: L2
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.executors-virtual-threads.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-engineering.threads-jmm
version_surfaces:
- jdk-25
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释Executor、Future、取消与虚拟线程的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-executor-future
  - java-cancellation-virtual-thread
  covers_topics:
  - java.executor
  - java.future-result
  - java.task-failure
  - java.interruption-cancellation
  - java.timeout
  - java.virtual-thread-boundary
  uses_capabilities:
  - java.concurrency-runtime
  - java.exceptions-resources
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：用 Executor 提交带超时的独立维修查询任务，收集 Future 成功/异常/取消结果并对比虚拟线程版本
  covers_topic_groups:
  - java-executor-future
  - java-cancellation-virtual-thread
  covers_topics:
  - java.executor
  - java.future-result
  - java.task-failure
  - java.interruption-cancellation
  - java.timeout
  - java.virtual-thread-boundary
  uses_capabilities:
  - java.concurrency-runtime
  - java.exceptions-resources
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入任务吞中断、Future 永久等待和 Executor 未关闭，利用线程/超时证据实现协作式取消
  covers_topic_groups:
  - java-executor-future
  - java-cancellation-virtual-thread
  covers_topics:
  - java.executor
  - java.future-result
  - java.task-failure
  - java.interruption-cancellation
  - java.timeout
  - java.virtual-thread-boundary
  uses_capabilities:
  - java.concurrency-runtime
  - java.exceptions-resources
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Executor、Future、取消与虚拟线程

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《线程、Java 内存模型、同步与锁》](ch.java-engineering.threads-jmm.md)：独立完成任务与结果、取消与虚拟线程前，必须先具备「线程、Java 内存模型、同步与锁」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套 Java 25 oracle 只使用内存中的合成 FactoryCare 工单，以 latch、barrier 和 semaphore 固定并发条件；它不连接真实外部服务，不把调度概率、精确耗时或长期挂起当证据。官方资料复核日期为 **2026-07-17**。零基础试读、生产负载测试、具体数据库驱动取消能力和全书回归尚未验证，因此不能晋升为 `verified`，也不会修改 `PROGRESS.md`。

上一章直接创建 `Thread`，让你看见线程生命周期、共享状态和 Java 内存模型。真实业务通常更关心“有一项维修查询要执行”，而不是“亲自管理第几个线程”。`Executor` 把任务提交与执行策略分离；`ExecutorService` 再提供结果、批量调用和关闭；`Future` 表示一次异步计算的结果协议。超时只限制等待，取消只是协作请求，关闭执行器也要等待任务响应。虚拟线程让大量等待型任务可以保持简单的同步代码，但不让 CPU 变快、不扩容数据库连接，也不修复竞态。

本章围绕 FactoryCare 的设备与工单查询建立完整闭环：成功值、任务异常、等待超时、取消、中断响应、平台线程池关闭、虚拟线程逐任务执行、外部资源限流，以及 JDK 25 结构化并发的预览边界。

## 1. 完成定义与非目标

完成本章时，你应能提供以下证据：

1. 在 120 秒内解释任务、线程、Executor、ExecutorService、Callable、Future 的职责，并给出“Future 已取消但任务仍运行”的失败反例；
2. 用固定线程池提交成功和失败查询，分别取得返回值与 `ExecutionException.getCause()`；
3. 每个外部等待都有明确上限，timeout 后按策略取消，并区分 `TimeoutException`、`CancellationException`、`ExecutionException` 与等待者自身的 `InterruptedException`；
4. 用 latch 重放一个吞中断任务，证明 `cancel(true)` 或 `shutdownNow()` 都不保证线程已经终止；
5. 执行器关闭后拒绝新任务，`awaitTermination` 成功，受控平台 worker 存活数为 0；
6. 用 `newVirtualThreadPerTaskExecutor()` 证明任务运行在虚拟线程，同时用 semaphore 限制两个稀缺资源槽；
7. 用 barrier 强制两个虚拟线程同时读旧值，得到丢更新 1，再用原子操作得到 2；
8. 说明 JDK 25 的结构化并发仍为 preview，为什么本路线默认资产不启用它。

本章不教授 `CompletableFuture` 流水线、Fork/Join 算法、响应式框架、生产线程池自动调参或分布式任务队列。它也不承诺中断能终止任意第三方 I/O；实际取消能力必须查所用 API、驱动和库。

配套工件：

- [最小结果协议示例](../../../examples/encyclopedia/ch.java-engineering.executors-virtual-threads/README.md)
- [执行器生命周期实验](../../../labs/encyclopedia/ch.java-engineering.executors-virtual-threads/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.executors-virtual-threads/README.md)

公开练习的红灯是故意保留的失败 fixture。先预测再运行，私有解不进入公开链接图。

## 2. 从零建立模型：任务不是线程

`Runnable` 或 `Callable<T>` 描述“做什么”。线程描述“一条执行路径”。Executor 描述“由什么策略接收并安排任务”。这三者可以变化而互不改写业务逻辑：同一个查询任务可以在当前线程、单个平台 worker、固定线程池或一个新虚拟线程中执行。

```text
提交者 ── submit(task) ──> ExecutorService ── 调度/排队 ──> worker/thread
  │                              │                                │
  └──────────── Future<T> <──────┴──── 成功值 / 异常 / 取消 ──────┘
```

最简单的 `Executor` 只有 `execute(Runnable)`。接口没有说任务必须异步，也没有结果或关闭方法；一个实现甚至可以直接在调用线程执行。不要从变量类型 `Executor` 猜“肯定新开线程”。执行策略由实现和配置决定。

`ExecutorService` 扩展这个概念：它能 `submit` 并返回 `Future`，能关闭、等待终止，也能批量 `invokeAll` / `invokeAny`。它还是 `AutoCloseable`，因此 Java 25 可在合适场景用 try-with-resources 管理生命周期。

### TypeScript / Vue 类比及失效处

可以把 `Future<T>` 暂时类比为 JavaScript 的 `Promise<T>`：两者都代表尚未得到的结果，成功和失败在稍后可见。类比很快失效：`Future.get()` 是阻塞当前 Java 线程；Promise 的 handler 由事件循环排队，不阻塞等待；Future 有中断、取消尝试和 executor 生命周期，Promise 本身没有通用强制取消。不能把 `await promise` 的直觉机械搬到线程池容量和中断语义。

## 3. Runnable、Callable、execute 与 submit

`Runnable.run()` 返回 `void`，不能声明受检异常；`Callable<V>.call()` 返回 `V`，可以抛异常。需要查询结果或明确失败时，优先提交 `Callable<V>`。只表示“执行一个动作”的任务可以用 Runnable，但仍要定义失败如何观测。

```java
Callable<String> query = () -> "WO-101:READY";
Future<String> future = executor.submit(query);
String result = future.get(1, TimeUnit.SECONDS);
```

`execute(runnable)` 不返回 Future。若任务抛未捕获运行时异常，处理路径与 worker 线程及其 `UncaughtExceptionHandler` 有关。`submit(runnable/callable)` 会把任务完成封装到 Future；异常通常在调用 `get` 时以 `ExecutionException` 暴露。若只 submit 却从不检查 Future，失败可能静默躺在对象里。

选择不是“哪个更高级”，而是结果协议：

| 需求 | 常见入口 | 必须保存的证据 |
| --- | --- | --- |
| 无返回值、失败由统一 handler 记录 | `execute(Runnable)` | handler、任务身份、线程上下文 |
| 需要返回值或逐任务失败 | `submit(Callable)` | Future 成功值或 cause |
| 多任务全部完成 | `invokeAll` | 每个 Future 的独立状态 |
| 多个候选取一个成功 | `invokeAny` | 选中结果、其余任务取消与清理策略 |

不要用 `submit(() -> { try {...} catch (Exception e) {} })` 把失败吞掉；这会让 Future 正常返回，调用者无法区分真正成功与“任务内部假装成功”。

## 4. Future 是一次计算的结果协议

Future 不是线程句柄，也不是长期可复用容器。它对应一次提交：

- `get()` 等到完成并取值；
- `get(timeout, unit)` 最多等待给定时间；
- `cancel(mayInterruptIfRunning)` 尝试取消；
- `isDone()` 表示已经以成功、异常或取消中的任一种完成；
- `isCancelled()` 表示正常完成前被取消；
- Java 19 起的 `state()`、`resultNow()`、`exceptionNow()` 便于已知完成后的非阻塞检查。

JDK 25 的 `Future.State` 包含 RUNNING、SUCCESS、FAILED、CANCELLED。`isDone()==true` 不等于成功；只有 state 或 `get` 的结果协议能区分。调用 `resultNow()` 前必须已知是 SUCCESS，调用 `exceptionNow()` 前必须已知是 FAILED，否则抛 `IllegalStateException`。

Future 还提供内存一致性边：异步计算中的动作 happens-before 另一个线程在相应 `Future.get()` 之后的动作。它让 get 后读取任务结果具有可见性，但不会让多个任务对同一计数器的复合更新自动原子。

## 5. 四类终局不能混在一起

### 成功

任务正常返回，`get` 返回值。`null` 也可能是合法成功值，因此不要用 null 同时表示失败或取消。

### 失败

任务抛异常，`get` 抛 `ExecutionException`。诊断重点是 `getCause()`：类型、消息和业务上下文。`ExecutionException` 只是跨线程结果包装；日志若只打印包装层，会丢掉真正原因。

### 取消

Future 在正常完成前被取消，`get` 抛 `CancellationException`，state 为 CANCELLED。Future 层结果已不可取得，但执行代码是否已停必须另外观察。

### 等待者被中断

调用 `get` 的当前线程收到中断时，`get` 抛 `InterruptedException`。这是“等待者不再愿意等”，不是被等待任务的业务异常。通常在不能继续处理时应取消相关任务、清理执行器并恢复当前线程中断状态：

```java
catch (InterruptedException e) {
    future.cancel(true);
    Thread.currentThread().interrupt();
    throw e;
}
```

是否重新抛出取决于方法契约，但静默吞掉中断会让上层取消失效。

## 6. Timeout 只限制等待，不会自动停止任务

裸 `future.get()` 可以永久等下去。只要任务依赖外部系统、锁、队列或未知代码，就应先定义等待上限。`get(200, MILLISECONDS)` 超时会抛 `TimeoutException`，但任务仍可能继续运行，Future 仍可能是 RUNNING。

因此 timeout 后还要作业务决定：

1. 是否允许任务后台继续并稍后取结果？
2. 是否 `cancel(true)` 请求停止？
3. 是否关闭底层 socket、statement 或其他资源？
4. 是否返回部分结果、降级或整体失败？
5. 如何记录 deadline、取消原因和未完成任务？

不要给每个子任务都重新分配完整 2 秒。一次请求有 2 秒总预算，先等待 A 1.8 秒，再等 B 2 秒，整体就可能超过 SLA。更可靠的是计算一个绝对 deadline，每次等待使用 `deadline - now` 的剩余预算；系统时长计算宜使用单调时间源 `System.nanoTime()`，展示给人的时间另用 wall clock。

测试 timeout 时不要让任务“sleep 51 ms”，再断言 50 ms 必超时；调度抖动会制造 flaky。本章让任务等待尚未释放的 latch，所以无论机器快慢，在释放前都不可能完成。测试只断言抛 TimeoutException，不断言恰好经过多少毫秒。

## 7. 取消是协作协议，不是 kill

`future.cancel(true)` 在任务已开始时会尝试中断执行线程；参数 false 允许正在运行的任务完成。官方合同明确说 cancel 是 attempt：其返回值本身甚至不保证“现在已取消”，最终要查 `isCancelled()`；即使已经 CANCELLED，也不等同“线程已经停止”。典型实现用 `Thread.interrupt()`，而中断是状态 / 通知协议。

### 7.1 阻塞方法如何响应

`sleep`、`wait`、`join` 和许多 `java.util.concurrent` 阻塞方法会在中断时抛 `InterruptedException`，并清除中断状态。若方法不能把异常继续抛给上层，应在清理后调用 `Thread.currentThread().interrupt()` 恢复状态，让更外层看见。

```java
try {
    queue.take();
} catch (InterruptedException e) {
    Thread.currentThread().interrupt();
    return; // 结束任务，而非继续无限循环
}
```

CPU 循环不会自动抛异常，应定期检查 `isInterrupted()` 并退出。检查频率取决于每轮成本和取消延迟目标，不能在每条极小指令上机械检查，也不能数分钟不检查。

### 7.2 吞中断为什么危险

```java
catch (InterruptedException ignored) {
    // 继续等待
}
```

这会产生三个不同状态：Future 已标记 CANCELLED；任务代码仍在运行；Executor 无法 TERMINATED。调用者若只看 `future.isCancelled()` 就会误报“取消成功”。本章实验等任务明确记录收到中断，再让它继续等待；`awaitTermination` 在释放 latch 前必为 false，释放后才为 true。故障不会长期挂起，但能证明合同差异。

中断安全还要求 cleanup：释放 semaphore permit、锁、临时文件和连接。`finally` 是常见手段；若底层库不响应中断，要使用它自己的取消 / 关闭 API，并把“不可中断”写入超时架构。

## 8. 线程池：控制昂贵平台 worker 和排队策略

平台线程通常对应整个生命周期占用的 OS 线程，创建和保有成本较高，所以常用池复用。池不是“让任务自动安全”，而是一组容量、队列、拒绝、线程工厂和关闭策略。

### 8.1 常用工厂只隐藏了配置

- `newSingleThreadExecutor()`：一个 worker，任务串行；前一任务永久阻塞会堵住全部后续任务；
- `newFixedThreadPool(n)`：最多 n 个活跃 worker，默认无界队列可能无限堆积；
- `newCachedThreadPool()`：按需创建并复用线程，持续过载可能产生大量线程；
- `newWorkStealingPool()`：工作窃取，执行顺序与线程身份不固定，适合特定可拆分任务；
- `newScheduledThreadPool(n)`：延迟和周期任务，不等于可靠的持久化调度系统。

工厂方便入门，却不消除容量设计。对生产入口应知道底层队列是否有界、最大并发、拒绝策略和监控指标。

### 8.2 ThreadPoolExecutor 的三步决策

JDK 25 官方文档描述：提交任务时，worker 少于 corePoolSize 则优先创建线程；达到 core 后优先入队；无法入队时，若未达 maximumPoolSize 则增线程，否则执行拒绝策略。由此可见，使用无界队列时，队列通常永不“满”，maximumPoolSize 可能根本不起作用。

三类队列各有代价：

- `SynchronousQueue` 直接移交，无容量；能减少任务依赖互锁，但可能导致线程无界增长或拒绝；
- 无界 `LinkedBlockingQueue` 吸收突发，却可能在长期输入大于处理能力时耗尽内存并放大延迟；
- 有界队列限制资源，却必须显式决定满载时拒绝、调用者执行、丢弃还是降级。

`RejectedExecutionException` 不是“偶发 Java 错误”，而是容量 / 生命周期信号：池已关闭，或任务与队列容量已满。不能无日志无限重试，否则只把过载移到提交线程。

### 8.3 ThreadFactory 是可观测性边界

自定义 ThreadFactory 可设置有意义的名称、未捕获异常 handler 等。不要依赖把所有 worker 设为 daemon 来掩盖未关闭：daemon 线程不会阻止 JVM 退出，可能让任务静默丢失。正确证据是 shutdown、termination 与业务完成协议。

## 9. ExecutorService 生命周期：RUNNING 不是永久资源

可以把生命周期简化为：

```text
RUNNING --shutdown()--> SHUTDOWN --任务清空--> TERMINATED
    └--shutdownNow()--> STOP ----任务响应中断----┘
```

`shutdown()` 拒绝新任务，但允许已提交任务执行；它立即返回，不等待完成。`shutdownNow()` 阻止尚未开始的排队任务，返回它们，并尝试停止活动任务；它也不等待，且任务不响应中断时可能永不终止。`awaitTermination` 在 shutdown 请求后等待：全部结束返回 true，上限到达返回 false，等待者被中断则抛 InterruptedException。

### 9.1 两阶段关闭

通用思路是：

1. `shutdown()` 停止接收；
2. 在明确上限内 `awaitTermination`；
3. 未结束则 `shutdownNow()` 请求取消并取得未开始任务；
4. 再次有上限地等待；
5. 若关闭线程自身被中断，调用 `shutdownNow()` 并恢复中断状态；
6. 仍未结束则报告任务身份与线程证据，而非假装成功。

关闭预算属于应用生命周期，不应照抄官方示例中的 60 秒。短命令、Web 应用优雅停机和批处理有不同 SLA。

### 9.2 close 与 try-with-resources

JDK 25 中 ExecutorService 扩展 AutoCloseable。默认 `close()` 发起有序 shutdown，并等待所有已提交任务完成和执行器终止；若等待期间当前线程被中断，它会按规范升级处理并最终恢复中断状态。对已知会结束的作用域，这使代码清晰：

```java
try (ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor()) {
    Future<String> result = executor.submit(this::query);
    use(result.get(1, TimeUnit.SECONDS));
}
```

但 close 的“等待”不是自动 timeout。若任务吞中断或永久阻塞，离开 try 块也可能长期等待。高风险生命周期仍要在任务协议中落实 deadline、资源关闭和可诊断取消，而不是把 `close()` 当强制杀死。

执行器未关闭常让非 daemon 平台 worker 阻止 JVM 退出；测试框架可能表现为“断言全过但进程不结束”。诊断应查看线程 dump、worker 名称、`isShutdown/isTerminated`、队列与任务栈，而非在 shell 外层永久等待。

## 10. 批量任务与结果顺序

`invokeAll(tasks)` 等所有任务完成，返回 Future 列表通常与输入迭代顺序对应，不是完成顺序。带 timeout 的版本在上限到达时取消未完成任务，但仍要检查每个 Future。一个失败任务不会自动让其他 Future 的 `get` 变成功。

`invokeAny(tasks)` 返回一个成功完成的结果；其他任务会被取消。它适合多个等价来源竞速，不适合“任选一个工单查询结果”。重复调用外部服务还涉及幂等、配额和费用，不能只看线程 API。

需要按完成顺序消费而不等待慢任务时，可学习 `ExecutorCompletionService`；需要依赖图和异步组合时再学习 `CompletableFuture`。不要为追求 API 数量混用所有模型。

## 11. 虚拟线程：便宜的等待线程，不是更快 CPU

虚拟线程和平台线程都是 `java.lang.Thread`。平台线程在整个生命周期绑定 OS 线程；虚拟线程由 JDK 调度，可在执行时挂载到 carrier 平台线程，阻塞等待时通常卸载，让 carrier 执行其他虚拟线程。大量等待型任务因此可保持一任务一线程的简单同步代码。

JEP 444 在 JDK 21 正式交付虚拟线程，JDK 25 的 `Thread.ofVirtual()` 与 `Executors.newVirtualThreadPerTaskExecutor()` 都是正式 API，无需 `--enable-preview`。后者为每个提交任务启动一个新虚拟线程，名字虽然含 Executor，却不是“虚拟线程池”。

### 11.1 适合与不适合

适合：大量并发、每项任务大部分时间等待文件、网络、数据库或队列，目标是提高整体吞吐和硬件利用率。

不适合用来宣称：

- 单个任务延迟更低；
- CPU 密集循环更快；
- 数据库能承受无限连接；
- 内存无限；
- 第三方阻塞 API 都能良好卸载；
- 共享对象自动线程安全。

Oracle JDK 25 指南明确说虚拟线程提供 scale / throughput，不是 speed / latency；长时间 CPU 密集操作不会因线程更多超过处理器核心能力。

### 11.2 不要池化虚拟线程

平台线程池共享昂贵 worker；虚拟线程便宜，每个并发任务应拥有自己的虚拟线程。若外部服务只能同时处理 10 个请求，限制的是服务 / 连接资源，不是虚拟线程数量。使用 `Semaphore(10)` 或连接池表达该资源上限：

```java
Semaphore slots = new Semaphore(10);
slots.acquire();
try {
    return callLimitedService();
} finally {
    slots.release();
}
```

本章 lab 同时启动六个虚拟任务，semaphore 保证最多两个进入合成资源。线程可以很多，资源合同仍明确。

### 11.3 ThreadLocal 与观测

虚拟线程支持 ThreadLocal，但线程可能非常多。把昂贵可变对象缓存在每个 ThreadLocal 中会复制成大量实例，违背原本“少量池线程复用”的假设。请求 ID 之类上下文也要确认生命周期和清理；JDK 25 已正式提供 Scoped Values，但本章不扩展其 API。

`Thread.isVirtual()` 可验证身份；`jcmd <pid> Thread.dump_to_file` 能以 text / JSON 查看虚拟线程；JFR 有虚拟线程启动、结束、pinned 和提交失败事件。实验不调用外部诊断进程，只在生产诊断章节再练。

### 11.4 JDK 25 的 pinning 当前边界

旧资料常说“虚拟线程在 synchronized 内阻塞会 pin carrier，应全部改 ReentrantLock”。JEP 491 已在 JDK 24 交付，使虚拟线程在 synchronized、monitor 获取和 Object.wait 等场景通常可以卸载；JDK 25 不应继续把“避免 synchronized pinning”当普遍迁移理由。

仍有少量 pinning 情况，例如 native / foreign function 回调中阻塞、某些类加载和类初始化路径。Pinning 通常影响可扩展性，不自动改变业务正确性。选择 synchronized 或 Lock 应根据所需语义、可中断 / 定时锁、公平性和可维护性；无论哪种锁，都应缩小临界区并避免持锁做长 I/O。

## 12. 虚拟线程仍服从 JMM：共享状态问题原样存在

把两个任务从平台线程换成虚拟线程，没有增加 happens-before。普通 `counter++` 仍是读、加、写；两个虚拟线程都读到 0，再各写 1，结果就是 1。

配套 lab 用 `CyclicBarrier` 让两个虚拟线程都在写前完成读取，因此错误不是概率事件。随后 `AtomicInteger.incrementAndGet()` 得到 2。结论是：虚拟线程改变线程成本与调度，不改变 `synchronized`、Lock、原子类、不可变对象和安全发布的职责。

大量虚拟线程还可能放大共享热点：10 万个任务争同一锁仍会排队；10 万个任务同时向无界集合写入仍可能耗尽内存；10 万个失败同时记录堆栈会造成日志风暴。并发度提升必须配合背压、资源预算和可观测性。

## 13. 结构化并发：理解目标，守住 JDK 25 preview 边界

普通 Executor 允许任务脱离创建它的调用栈：父请求返回了，子 Future 可能仍活着；一个子任务失败，兄弟任务未必取消；线程 dump 也难看出父子关系。结构化并发把一组相关子任务的生命周期限制在明确词法作用域内：进入 scope、fork、join、组合结果，离开 scope 前子任务必须完成或被取消。

截至 2026-07-17，JEP 505 在 JDK 25 交付 **Structured Concurrency (Fifth Preview)**。它使用 `StructuredTaskScope.open()` 工厂和 Joiner 设计；相较前一轮又有 API 变化。编译和运行都要显式 `--enable-preview --release 25`。JEP 的非目标也很重要：它不替代 ExecutorService / Future，不发明新的强制取消机制，也不取代现有中断。

本路线主线不启用 preview，原因不是它“不能用”，而是：

- 生产主线承诺不依赖预览 API；
- JDK 25 API 已改变且后续轮次仍可能改变；
- 本章先验证 Future、取消和关闭的稳定合同；
- 默认资产要用普通 `javac --release 25` 复现。

如果实验性分支评估 StructuredTaskScope，必须隔离源码与构建配置，记录 preview flags、JDK 精确版本、迁移和回滚；不要把 preview 代码悄悄混入主线。其设计思想仍可立即采用：相关任务同生共死、失败传播、deadline 共享、退出作用域前清理完成。

## 14. FactoryCare 场景：三项维修查询

假设请求需要读取设备状态、工单状态和 SLA 规则。先写任务表：

| 任务 | 结果类型 | 业务上限 | 失败策略 | 取消资源 | 并发边界 |
| --- | --- | --- | --- | --- | --- |
| 设备状态 | `DeviceState` | 剩余 deadline | 整体失败或明确降级 | driver / Future | 连接池 |
| 工单状态 | `WorkOrderState` | 剩余 deadline | 整体失败 | statement / Future | 连接池 |
| SLA 规则 | `SlaRule` | 剩余 deadline | 使用已验证缓存 | cache call | 缓存容量 |

不要先选“固定池还是虚拟线程”，先判断：任务是否独立、是否等待密集、外部资源上限、失败是否应取消兄弟、结果是否允许部分返回。平台固定池可同时限制 worker 和间接限制并发，但队列会隐藏等待；虚拟线程让每任务一线程更清晰，连接池 / semaphore 仍负责稀缺资源。

所有结果应带任务身份和原因，不能只收集字符串：

```text
SUCCESS(device, value)
FAILED(workOrder, IllegalStateException: unknown-device)
TIMED_OUT(sla, deadline-exhausted)
CANCELLED(peer-failed)
```

若业务需要审计，记录的是任务、deadline、尝试、cause 与最终决策，不是把完整客户数据和线程 dump 无差别写日志。

## 15. 配套 oracle 为什么不 flaky

公开 lab 验证四组合同：

### 成功、异常与关闭

两个平台 worker 执行成功和异常任务。主线程按固定顺序取结果，异常 cause 必须是 `IllegalArgumentException:unknown-device`。shutdown 完成后提交必抛 `RejectedExecutionException`，记录的 worker 都不再 alive。

### timeout 与协作取消

任务先 countDown started，再等待关闭的 release latch。主线程只有看到 started 才调用带上限 get，所以 timeout 的原因确定；取消后任务捕获 InterruptedException、记录观察、恢复中断并结束。Future 的 get 再抛 CancellationException。

### 吞中断故障

任务收到中断后故意继续等待第二个 latch。Future 已 CANCELLED，但 shutdown 后的第一次 awaitTermination 必为 false。主线程随后释放 latch，任务结束，第二次 awaitTermination 才为 true。全过程有 2 秒守护，不留下挂起线程。

### 虚拟线程、资源门和竞态

六项任务各用一个虚拟线程；两个 permit 使 max-resource-use 恒为 2。另两个虚拟线程通过 barrier 同读旧计数，得到 1；原子计数得到 2。没有真实数据库、端口、DNS 或远程服务。

运行：

```bash
labs/encyclopedia/ch.java-engineering.executors-virtual-threads/verify.sh
```

验证脚本只接受 JDK 25，使用临时构建目录，结束后删除。连续复跑输出应字节一致；这仍不能证明其他 JVM 实现、操作系统、驱动和生产负载的时序。

## 16. 故障诊断顺序

### 进程不退出

先查是否存在未关闭 Executor、非 daemon worker、永久阻塞任务。查看线程名、栈、isShutdown/isTerminated 和队列，而不是先强制杀进程。修复生命周期后复跑同一 oracle。

### Future 永久等待

定位裸 get、任务在等什么、是否有 deadline、底层资源能否取消。先把等待改成有界并保存 TimeoutException，再决定取消 / 降级；不要只在 shell 外套一个巨大超时。

### cancel true 但任务仍占资源

确认任务是否已经开始、是否收到中断、catch 是否吞掉、CPU 循环是否检查状态、第三方 I/O 是否支持中断、finally 是否释放资源。Future state 只能证明结果协议，不能证明业务副作用停止。

### 异常“消失”

检查是否用 submit 却没 get，是否 catch 后返回默认值，是否日志只打印 ExecutionException。保留 cause 与任务 ID，并让测试主动抛已知异常验证失败通道。

### 线程池越来越慢

检查输入速率、任务耗时分布、active count、队列长度、拒绝数和外部资源。无界队列可让“没有拒绝”同时意味着延迟与内存不断增长。

### 换虚拟线程后仍慢

确认工作负载是否 CPU 密集、瓶颈是否数据库连接 / rate limit / 单锁、是否使用大量 ThreadLocal 缓存、是否有 native pinning、是否本来并发量很小。虚拟线程不是通用性能开关，必须以负载测试和 JFR / 指标验证。

## 17. 测试矩阵与证据边界

| 维度 | 必测用例 | 可信证据 | 不能推出 |
| --- | --- | --- | --- |
| 成功 | Callable 返回明确值 | get 值与 state | 外部系统稳定 |
| 异常 | 任务抛已知异常 | ExecutionException cause | 所有异常已覆盖 |
| timeout | latch 未释放 | TimeoutException | 任务已停止 |
| 取消 | 任务响应中断 | interrupt-observed、finally | 任意驱动可取消 |
| 吞中断 | cancel 后继续等 | termination false，释放后 true | 生产不会泄漏 |
| 关闭 | shutdown 后提交 | RejectedExecutionException、0 live workers | JVM 中无其他线程 |
| 虚拟线程 | `isVirtual` | true | 吞吐一定提升 |
| 资源上限 | semaphore=2 | max active=2 | 数据库容量就是 2 |
| 共享竞态 | barrier 同读 | 普通 1 / atomic 2 | 任意竞态都已消除 |

报告必须区分 verified 和 unverified。一次离线 PASS 证明 API 合同与教学模型，不证明真实 SLA、长时间稳定性、驱动中断、CPU / 内存容量或预览 API 兼容。

## 18. AI 协作审查清单

让 AI 生成并发代码前，先给任务表、deadline、取消和关闭 oracle。收到候选后逐项问：

1. 是否出现裸 `get()` 或无界队列？
2. timeout 后任务是否继续，资源如何关闭？
3. InterruptedException 是否被吞，是否错误地清除状态？
4. Future 的异常 cause 是否可见？
5. Executor 在成功、失败和中断路径都关闭吗？
6. `shutdownNow()` 是否被误写成强制终止？
7. 虚拟线程是否被池化，是否误称 CPU 加速？
8. 连接、文件描述符和 rate limit 是否另有资源门？
9. 共享状态是否仍有同步或原子合同？
10. 是否偷偷启用了 JDK 25 preview，编译与运行 flags 是否一致？

模型说“没有线程泄漏”不是证据。运行受控红例，检查线程 / termination，恢复后复跑；不理解的并发改动不进入工作树。

## 19. 120 秒复述模板

> 任务描述要做什么，线程是执行路径，Executor 把提交和执行策略分离，ExecutorService 再提供 Future 和关闭。Future 有成功、失败、取消和等待者中断四类结果，isDone 不等于成功；任务异常要从 ExecutionException 的 cause 读取。带 timeout 的 get 只限制等待，不会停止任务；cancel true 只是尝试中断，任务必须协作响应、恢复中断并清理资源。shutdown 拒绝新任务但不等待，shutdownNow 也只是 best effort，要用 awaitTermination 证明结束。平台线程昂贵时用有边界的池和拒绝策略；虚拟线程为每个等待型任务新建，不要池化，也不能让 CPU 更快或共享状态安全。稀缺连接用 semaphore / 连接池限制。JDK 25 中 synchronized 的大多数 pinning 已由 JEP 491 消除，但 native 等情况仍可能 pin；结构化并发在 JDK 25 仍是第五次 preview，不进入稳定主线。失败反例是 Future 已 CANCELLED，但任务吞中断继续等待，Executor 因而不能 TERMINATED。

若不能解释 timeout 后任务去向、关闭证据和虚拟线程资源门，仍未达到独立使用标准。

## 20. 自检题

1. Executor 为什么不保证异步？ExecutorService 多了哪些职责？
2. execute 与 submit 的异常路径有什么差异？
3. `isDone()==true` 可能是哪四种结果？
4. 为什么要保留 `ExecutionException.getCause()`？
5. `get(timeout)` 抛 TimeoutException 后，任务处于什么状态？
6. `cancel(true)` 返回 true 为什么不能证明任务已停？
7. InterruptedException 为什么常要恢复中断状态？
8. shutdown、shutdownNow、awaitTermination、close 分别做什么？
9. 无界队列为何可能让 maximumPoolSize 失效？
10. 虚拟线程为何不能用来限制数据库并发？
11. JDK 25 中关于 synchronized pinning 的旧建议哪里已过时？
12. 虚拟线程为何仍会丢更新？
13. StructuredTaskScope 在 JDK 25 的状态是什么？主线为何不用？
14. 如何设计一个不靠 sleep 概率的吞中断测试？

## 21. 官方一手资料

以下资料均于 **2026-07-17** 核对。API 合同以 JDK 25 文档为准；实现和预览状态在升级 JDK 时必须重新检查。

- Oracle，[ExecutorService — Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/ExecutorService.html)：提交、关闭、等待终止、close 和 happens-before。
- Oracle，[Future — Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/Future.html)：结果、异常、timeout、取消和 Future.State。
- Oracle，[ThreadPoolExecutor — Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/ThreadPoolExecutor.html)：core / max、队列和拒绝决策。
- Oracle，[Executors — Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/Executors.html)：常用工厂与逐任务虚拟线程 executor。
- Oracle，[Thread — Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Thread.html)：interrupt、状态、平台 / 虚拟线程共同合同。
- Oracle，[Virtual Threads — JDK 25 Core Libraries Guide](https://docs.oracle.com/en/java/javase/25/core/virtual-threads.html)：采用场景、吞吐边界、不要池化、semaphore、ThreadLocal 与诊断。
- OpenJDK，[JEP 444: Virtual Threads](https://openjdk.org/jeps/444)：JDK 21 正式交付目标与设计。
- OpenJDK，[JEP 491: Synchronize Virtual Threads without Pinning](https://openjdk.org/jeps/491)：JDK 24 的 monitor pinning 更新与剩余边界。
- OpenJDK，[JEP 505: Structured Concurrency (Fifth Preview)](https://openjdk.org/jeps/505)：JDK 25 预览状态、API 变化和非目标。

## 22. 最后边界

并发代码的完成条件不是“结果打印出来”，而是所有任务都有结果协议，所有等待都有上限，所有取消都有任务响应证据，所有执行器都有终止证据，所有共享状态都有同步策略，所有稀缺资源都有容量边界。

虚拟线程把“线程太贵”从许多等待型设计中移开，却把真正的业务限制暴露得更清楚。若只是把固定池换成虚拟线程 executor，却保留裸 get、吞中断、无界外部调用和竞态，系统只是更快地产生更多未完成工作。
