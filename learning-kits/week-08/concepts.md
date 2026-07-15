# Week 08 概念讲义

## 1. 一张图理解并发选择

    业务任务
       │
       ├─是否需要并发？否──> 串行版本
       │
       ▼
    任务主要在做什么？
       ├─CPU 密集──> 有界平台线程并行，按核心与测量决定
       └─阻塞等待──> 平台线程池 或 每任务虚拟线程
                            │
                            ▼
                     稀缺资源是否有限？
                            ├─数据库连接池
                            ├─第三方 API 限额
                            └─文件描述符/内存
                            │
                            ▼
                     独立限流、超时、取消、降级

虚拟线程改变“等待期间占用平台线程”的成本，不改变外部世界的容量。

## 2. 基本词汇

| 词 | 含义 | 常见混淆 |
| --- | --- | --- |
| 进程 | 独立运行与资源边界 | 不是一个线程 |
| 平台线程 | 操作系统线程的 Java 表达 | 数量成本较高 |
| 虚拟线程 | JVM 调度的轻量线程 | 不是更快的 CPU |
| 任务 | 要完成的一段工作 | 不必与线程一一固定绑定 |
| 并发 | 多个任务时间上交错推进 | 不保证同时执行 |
| 并行 | 多个任务同一时刻执行 | 需要执行资源 |
| 吞吐量 | 单位时间完成数量 | 不等于单请求延迟 |
| 延迟 | 单个请求完成时间 | 并发过高可能更差 |

TS 类比：Promise 表达异步结果，不等于新线程；浏览器事件循环的并发与 Java 多线程共享内存模型不同。Web Worker 更像独立执行环境，但也不能直接类比平台线程。

## 3. 共享状态为什么危险

### 3.1 原子性

count++ 不是不可分步骤，概念上包含读、加一、写。两个线程都读到 5，最后可能只写成 6，而不是 7。

### 3.2 可见性

一个线程写入普通字段后，另一个线程不一定按你期望的时机观察到。编译器、JIT、CPU 缓存与内存模型共同影响可见顺序。不要用“我本机每次都看到”当证明。

### 3.3 顺序性

只要单线程可观察行为不变，指令可能被优化重排。同步原语建立 happens-before 关系。基础阶段只需知道正确同步带来可见性与顺序保证，不形式化背 JMM。

### 3.4 优先策略

按优先级选择：

1. 不共享；
2. 使用不可变值；
3. 每个任务线程封闭；
4. 使用并发集合提供的原子操作；
5. 使用原子变量处理简单单值；
6. 用 synchronized/Lock 保护复合不变量；
7. 最后才考虑复杂无锁结构。

锁保护的是不变量，不是某一行代码。多个字段必须一起变化时，单独 AtomicInteger 未必足够。

## 4. synchronized、volatile 与原子类

### synchronized

- 同一监视器上互斥；
- 进入与退出建立可见性关系；
- 适合保护小范围复合不变量；
- 锁范围过大降低并发；
- 锁顺序不一致可能死锁。

### volatile

- 保证对该变量的写对后续读可见，并提供相应顺序语义；
- 不让 count++ 变原子；
- 适合状态标志或独立配置引用；
- 多字段复合一致性不能靠多个 volatile 自动得到。

### AtomicInteger/AtomicReference

- 提供 compare-and-set 等原子操作；
- 适合单变量状态转换/计数；
- check-then-act 跨多个对象仍需要更高层同步；
- LongAdder 只作为高争用统计概念了解，本周不作为业务精确快照答案。

### 并发集合

ConcurrentHashMap 的单个操作线程安全，但：

    if (!map.containsKey(key)) {
        map.put(key, value);
    }

这两个操作组合不原子。应考虑 putIfAbsent、computeIfAbsent，或对整个业务不变量设计同步。

## 5. 线程生命周期、中断与协调

### 5.1 start 与 run

调用 thread.start 启动新线程执行 run；直接调用 run 只是当前线程普通方法调用。

### 5.2 interrupt 是协作式取消

interrupt 不会强杀线程：

- 某些阻塞方法抛 InterruptedException；
- 非阻塞计算需主动检查 isInterrupted；
- 捕获后若不能完成处理，应恢复中断状态或向上传播；
- 吞掉中断会让关闭和取消失效。

典型恢复：

    catch (InterruptedException cause) {
        Thread.currentThread().interrupt();
        throw new EnrichmentInterruptedException("补全被取消", cause);
    }

不要恢复中断后继续无限重试。

### 5.3 CountDownLatch 与 Semaphore

CountDownLatch 适合“一组参与者等待事件发生”，计数到 0 后不能重置。Semaphore 表示同时可持有的许可数，适合限制外部资源并发。获取许可后必须 finally 释放；只有成功 acquire 后才能 release。

### 5.4 死锁、活锁、饥饿

- 死锁：互相等待永不推进；
- 活锁：持续响应对方但业务不推进；
- 饥饿：某任务长期得不到资源。

固定锁顺序、缩小锁范围和超时获取能降低风险。线程转储可看到互相等待的锁。

## 6. ExecutorService 与线程池

### 6.1 任务与线程解耦

Executor 接收任务；ExecutorService 增加 Future、关闭等生命周期。业务不应为每个方法随手 new Thread 或 new pool。

### 6.2 ThreadPoolExecutor 的参数关系

重点不是背数字，而是理解：

- corePoolSize：通常维持的核心工作线程；
- maximumPoolSize：允许的上限；
- workQueue：线程忙时任务如何等待；
- keepAliveTime：非核心空闲线程回收；
- ThreadFactory：命名、异常与可观测性；
- RejectedExecutionHandler：饱和时明确行为。

执行大致顺序是：核心线程未满先建核心；核心满后入队；队列满再扩到 maximum；都满后拒绝。因此使用无界队列时 maximum 常常不起作用。

Executors.newFixedThreadPool 使用无界队列，不满足“有界排队”要求。学习实验用显式 ThreadPoolExecutor。

### 6.3 拒绝策略

- AbortPolicy：明确抛 RejectedExecutionException；
- CallerRunsPolicy：提交线程自己执行，能产生反馈，但会改变延迟与上下文；
- Discard/DiscardOldest：可能静默丢任务，核心业务通常危险。

选择必须连接业务语义。FactoryCare 本周推荐明确拒绝并记录来源，不静默丢。

### 6.4 submit、execute 与 Future

execute 没有 Future；未捕获异常交给线程的异常处理机制。submit 返回 Future，任务异常在 get 时以 ExecutionException 包装。若从不 get，失败可能被忽略。

Future.get 需要超时策略；cancel(true) 只是发出中断请求，任务仍需协作。

### 6.5 关闭

拥有 Executor 的组件负责：

1. 停止接收新任务；
2. shutdown；
3. awaitTermination；
4. 超时后 shutdownNow 发出中断；
5. 再次等待并记录未终止任务；
6. 捕获 InterruptedException 时恢复中断。

本地变量可使用 try-with-resources 管理支持 AutoCloseable 的 ExecutorService；应用级共享池由组合根/生命周期组件管理。

## 7. CompletableFuture

### 7.1 它是什么

CompletableFuture 同时表示未来结果和可组合阶段。它不是“自动开线程”；supplyAsync 未指定 Executor 时通常使用 common pool，本项目关键任务必须显式指定。

### 7.2 核心组合

| 方法 | 输入函数 | 用途 |
| --- | --- | --- |
| thenApply | T → R | 同步变换结果 |
| thenCompose | T → CompletionStage<R> | 串联异步依赖，避免嵌套 |
| thenCombine | T 与 U → R | 合并两个独立结果 |
| allOf | 多个 stage → 完成信号 | 等待一组，结果仍需单独读取 |
| exceptionally | Throwable → T | 失败恢复为值 |
| handle | T/Throwable → R | 成功失败都转换 |
| whenComplete | 观察 T/Throwable | 记录/清理，不宜改变结果 |

### 7.3 同步与 Async 后缀

thenApply 可能由完成前序阶段的线程执行；thenApplyAsync 会异步调度，未指定 Executor 仍可能进入 common pool。不要为了“更异步”给每段都加 Async。

### 7.4 异常

异步异常常被 CompletionException 包装。要保留原始来源和业务上下文。不要在每一级 exceptionally 返回 null，否则下游会以“成功 null”继续。

### 7.5 超时不等于取消底层工作

orTimeout 让 future 在超时后异常完成；completeOnTimeout 提供后备值。它们不应被理解为可靠终止底层 I/O。底层任务仍要有自身超时和中断协作。

CompletableFuture.cancel 也不能假定一定打断底层计算。测试需观察资源是否真正释放。

### 7.6 join 的边界

在聚合边界等待最终结果可以 join/get；如果每创建一个 Future 就立即 join，流程仍串行。画依赖图能发现这种伪异步。

## 8. 虚拟线程

### 8.1 解决的问题

阻塞式同步代码中，大量任务多数时间等待 I/O。每个任务占一个平台线程成本高；虚拟线程让运行时在阻塞等待时更高效地调度承载线程。

### 8.2 适用

- 大量彼此独立；
- 大部分时间阻塞等待；
- 希望保留同步代码与直观 stack trace；
- 每个任务有明确生命周期。

不适用：

- 无限制 CPU 密集计算；
- 依赖大量共享锁竞争；
- 以为线程数等于下游承载能力；
- 用虚拟线程掩盖无超时、无取消或无背压。

### 8.3 不池化虚拟线程

使用每任务虚拟线程：

    try (ExecutorService executor =
             Executors.newVirtualThreadPerTaskExecutor()) {
        Future<Result> future = executor.submit(task);
        ...
    }

线程不是此处的稀缺资源，因此不为“节省虚拟线程”建固定池。真正稀缺的第三方调用用 Semaphore 限制：

    permits.acquire();
    try {
        return externalCall();
    } finally {
        permits.release();
    }

必须正确处理中断，不能未 acquire 就 release。

### 8.4 ThreadLocal 与诊断

虚拟线程可以使用 ThreadLocal，但每任务一个线程时，大量 ThreadLocal 值可能增加内存和隐式上下文风险。Scoped Values 在 JDK 25 已正式定稿，但本轮不引入，避免在基础阶段把上下文传播复杂化。

现代 JDK 已持续改进虚拟线程与监视器相关的 pinning；不要背“synchronized 一定 pin”这种过时绝对结论。仍需关注锁竞争、native/foreign 调用等阻塞点，并以 JFR/线程诊断的实际事件为证据。

### 8.5 明确不用结构化并发

JDK 25 的结构化并发仍是 preview。它与本周“任务有共同生命周期”的理念相关，但项目不开 preview，不使用 StructuredTaskScope。不要为了学习新 API 修改编译参数。

## 9. 并发测试

### 9.1 不依赖长 sleep

sleep 只能延迟，不能证明线程到达具体阶段。使用：

- CountDownLatch 协调开始；
- CyclicBarrier 同步阶段；
- Semaphore 控制进入资源；
- Future.get(timeout) 防止永久挂起；
- Awaitility 等库本周不额外引入。

短 sleep 可用于模拟阻塞源，但断言不应依赖精确毫秒调度。

### 9.2 先证明正确性，再测性能

三个版本使用同一输入和结果断言。性能实验必须说明：

- 硬件和 JDK；
- 任务类型；
- 并发数；
- 下游限额；
- 预热与多轮结果；
- 只代表本地实验。

正式微基准应使用 JMH，但本周不展开。

## 10. JVM 高层模型

### 10.1 从源码到执行

源码经 javac 编译为字节码；类加载器加载，JVM 验证、链接和初始化；解释器先执行，热点代码可能被 JIT 编译优化。不是“Java 一直解释执行”。

### 10.2 内存区域

| 区域 | 直觉 | 常见现象 |
| --- | --- | --- |
| 堆 | 多数对象实例 | 堆耗尽、GC 压力 |
| 线程栈 | 每线程栈帧、局部执行状态 | 深递归 StackOverflowError |
| Metaspace | 类元数据等本地内存 | 动态类加载泄漏 |
| 直接/本地内存 | NIO、JVM 与 native 使用 | 进程内存高但堆不一定满 |

“局部变量都在栈、对象都在堆”只是入门简化，JIT 逃逸分析可能优化分配。面试避免绝对化。

### 10.3 GC 与 JIT

GC 回收不可达对象，不等于“内存满才运行”；停顿、吞吐与延迟是权衡。JIT 根据热点优化，所以冷启动一次计时不能代表稳态性能。

### 10.4 现象区分

- StackOverflowError：常见于深或无限递归；
- heap OOM：对象存活量超过堆；
- native/direct OOM：不一定在 heap dump 明显；
- deadlock：线程互等，CPU 可能低；
- 高 CPU：忙循环、热点计算或频繁 GC 等；
- 阻塞：线程等待锁、I/O 或条件。

## 11. 诊断工具

- jcmd：列进程、线程、GC、类直方图、JFR 等入口；
- 线程转储：看线程状态、栈、锁与死锁；
- JFR：低开销记录 CPU、分配、锁、I/O 等事件；
- heap dump：分析对象保留，但可能较大且含敏感数据；
- 日志：记录 taskId、设备 ID、安全上下文、开始/结束/失败，不记录密钥。

工具输出只是证据，不自动给根因。必须把线程栈位置对应到源码和业务现象。

## 12. TS/Vue 类比与失效

| 已有经验 | 可类比 | 失效处 |
| --- | --- | --- |
| Promise.all | allOf/thenCombine | Promise 基于事件循环；CF 的执行线程和 Executor 要显式理解 |
| async/await | 同步风格组合结果 | Java 阻塞等待可能占线程；虚拟线程改变成本但不改变资源限额 |
| AbortController | interrupt/cancel | interrupt 是协作式信号，不是强制终止 |
| Web Worker | 并行执行 | Worker 通常隔离内存；Java 线程共享堆 |
| Vue 状态竞态 | 旧请求覆盖新请求 | Java 还要面对真实多线程内存可见性 |
| 并发请求限流 | Semaphore/连接池 | 前端限流不能保护服务端全部调用者 |

## 13. 自测

1. count++ 为什么不是原子？
2. volatile 为什么不能修复所有竞态？
3. ConcurrentHashMap 为什么仍可能有复合竞态？
4. 捕获 InterruptedException 后为什么常需恢复中断？
5. 无界队列为何让 maximumPoolSize 常失去意义？
6. submit 的任务异常为什么可能被忽略？
7. thenCompose 与 thenApply 的差别？
8. orTimeout 为什么不等于底层任务已停止？
9. 虚拟线程为什么不池化？
10. 为什么仍要用 Semaphore 限第三方 API？
11. CPU 密集任务为何不能无限创建虚拟线程？
12. 堆 OOM 与 StackOverflowError 如何区分？
13. 一次 nanoTime 为什么不能证明虚拟线程更快？
14. JDK 25 为什么不使用结构化并发？

## 14. 官方资料

- [Java SE 25 并发指南](https://docs.oracle.com/en/java/javase/25/core/concurrency.html)
- [Thread API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Thread.html)
- [Executors API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/Executors.html)
- [CompletableFuture API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/CompletableFuture.html)
- [Java 虚拟线程](https://docs.oracle.com/en/java/javase/25/core/virtual-threads.html)
- [JDK 25 JVM 指南](https://docs.oracle.com/en/java/javase/25/vm/)
- [JDK Flight Recorder](https://docs.oracle.com/en/java/javase/25/jfapi/)
