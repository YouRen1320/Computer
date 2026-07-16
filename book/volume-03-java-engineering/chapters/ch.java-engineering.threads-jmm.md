---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.threads-jmm
title: 线程、Java 内存模型、同步与锁
responsibility: 教授线程间可见性、原子性和互斥，不在本章引入 Executor 调度或分布式锁
volume: '03'
order: 12
level: L2
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.threads-jmm.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.static-class-state
- ch.java-engineering.io-resource-lifecycle
version_surfaces:
- jdk-25
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释线程、Java 内存模型、同步与锁的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-thread-jmm
  - java-synchronization
  covers_topics:
  - java.thread-lifecycle
  - java.jmm-visibility
  - java.happens-before
  - java.race-condition
  - java.synchronized-lock
  - java.atomicity
  uses_capabilities:
  - java.encapsulation-immutability
  - java.exceptions-resources
  - java.references-objects
  - java.concurrency-runtime
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现两个线程累加工单计数的错误版与 synchronized/Lock 正确版，用重复运行展示竞态和 happens-before
  covers_topic_groups:
  - java-thread-jmm
  - java-synchronization
  covers_topics:
  - java.thread-lifecycle
  - java.jmm-visibility
  - java.happens-before
  - java.race-condition
  - java.synchronized-lock
  - java.atomicity
  uses_capabilities:
  - java.encapsulation-immutability
  - java.exceptions-resources
  - java.references-objects
  - java.concurrency-runtime
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入可见性标志不终止、check-then-act 丢更新和错误锁对象，抓线程状态后建立正确同步边
  covers_topic_groups:
  - java-thread-jmm
  - java-synchronization
  covers_topics:
  - java.thread-lifecycle
  - java.jmm-visibility
  - java.happens-before
  - java.race-condition
  - java.synchronized-lock
  - java.atomicity
  uses_capabilities:
  - java.encapsulation-immutability
  - java.exceptions-resources
  - java.references-objects
  - java.concurrency-runtime
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 线程、Java 内存模型、同步与锁

> 本章状态为 `drafting`。Java 25 离线 oracle 通过受控屏障重放错误交错，并高频验证正确计数；它不能证明任意生产并发程序无竞态、死锁或饥饿。P9 零基础试读、人工版式/无障碍检查、独立全面审查和全书回归尚未执行，不能晋升为 `verified`，也不会修改 `PROGRESS.md`。

单线程里，`count++` 看起来就是“加一”。两个线程同时执行时，它至少包含读取、计算、写回，两个线程可能都读到 0，再都写 1，最终丢一次更新。更隐蔽的问题是：线程 A 已写 `ready=true`，线程 B 是否保证看见？某段代码用 `synchronized`，却锁了每次新建的对象，是否真的互斥？答案不能靠“我的机器跑了没错”，而要靠 Java 内存模型定义的可见性、顺序和 happens-before 关系。

本章从 `Thread` 生命周期开始，建立共享状态、数据竞态、可见性、原子性、互斥、happens-before、`volatile`、`synchronized`、`Lock`、不可变与安全发布模型。连续场景是 FactoryCare 工单计数。实验不用 `Executor`、虚拟线程或分布式锁，不以 sleep 和概率重跑制造红灯；错误版用 `CyclicBarrier`/`CountDownLatch` 强制危险交错，正确版重复运行并恒定。官方资料复核日期为 **2026-07-16**。

## 1. 完成定义与证据

1. 在 120 秒内说明 Thread 与任务的区别、六种 `Thread.State`、`start/run/join` 的责任和“启动一次”合同。
2. 分别解释可见性、原子性与互斥；用两线程受控交错证明普通/volatile `read-modify-write` 仍会丢更新。
3. 画出 program order、monitor unlock/lock、volatile write/read、Thread start、termination/join 与 latch 的 happens-before 边。
4. 用同一个 monitor 的 `synchronized` 和同一个 `ReentrantLock` 实现计数器，高频重跑结果恒定且无死锁。
5. 重放 check-then-act、错误锁对象、缺失 visibility edge、volatile 非原子和锁顺序环五类故障，区分安全性与活性问题。
6. 读取线程 dump 的 state、stack、monitor/ownable synchronizer，能从第一处业务栈帧提出修复，而非只加 sleep。

配套工件：

- [线程/JMM 最小示例](../../../examples/encyclopedia/ch.java-engineering.threads-jmm/README.md)
- [FactoryCare 同步合同实验](../../../labs/encyclopedia/ch.java-engineering.threads-jmm/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.threads-jmm/README.md)

公开 starter 初始失败是练习合同的一部分。先画可能交错与锁身份，再改 TODO；私有解不进入公开链接图。

## 2. 线程、任务与共享状态：先知道谁在执行什么

进程是运行中的程序资源容器，线程是 JVM 内可独立调度的一条执行路径。一个 `Runnable` 只是“要做什么”的任务对象；`Thread` 表示“由一条线程执行”的生命周期。调用 `thread.start()` 才请求 JVM 启动新线程并在其上调用 `run`；直接 `thread.run()` 只是当前线程的普通方法调用，没有并发。

两个线程可以访问同一堆对象与 static 字段，各自有调用栈和局部变量。局部变量并非天然永远安全：若局部引用指向共享可变对象，仍会竞争。判断共享要追踪对象可达性与所有权，而不是只看变量声明位置。

`static` 只表示属于类，不提供同步。单例字段、缓存、计数器和注册表因此常成为共享状态。实例字段也可能被多个线程共享，例如同一 service 被多请求调用。相反，每个线程独占的 builder、方法内新建且不逃逸的集合无需加锁。

并发设计先列出：共享对象是谁、可变字段有哪些、允许哪些不变量、谁读写、采用哪一种同步策略。给“所有访问必须在同一锁下”写成类级合同，比在 bug 后零散补 `synchronized` 更可靠。

## 3. 生命周期与 Thread.State：状态是诊断快照，不是业务协议

Java `Thread.State` 有 NEW、RUNNABLE、BLOCKED、WAITING、TIMED_WAITING、TERMINATED。NEW 表示尚未 start；RUNNABLE 包含 JVM 中正在执行或可执行，不等同某一时刻占用 CPU；BLOCKED 表示等待进入 monitor；WAITING/TIMED_WAITING 表示等待其他动作或带时限等待；TERMINATED 表示 run 已结束。

这些是 JVM 状态，不是一一对应的操作系统线程状态。`getState()` 是瞬时快照，下一条指令前就可能改变，不能用“等到恰好 RUNNABLE”作为脆弱业务同步。实验只断言 start 前 NEW 与 join 后 TERMINATED；中间协作使用 latch/barrier 明确协议。

一个 Thread 实例最多 start 一次，第二次会抛 `IllegalThreadStateException`。任务要再执行应创建新 Thread；后续章节会用 Executor 把任务生命周期与线程管理分离。本章不提前引入调度池。

未捕获异常会终止该线程，不会自动在创建线程中重新抛出。可以设置 `UncaughtExceptionHandler` 记录失败，但业务结果和失败传播应有明确协议。简单 `join` 只等待结束，不返回结果；Future 在后续章节处理。

## 4. start、join 与中断：生命周期本身也建立顺序

在主线程调用 `start` 之前完成的动作 happens-before 新线程中的动作，因此先构造不可变输入再 start 是一种安全传递。线程中的全部动作 happens-before 另一个线程通过 `join` 成功检测到它终止后的动作，所以 join 后读取 worker 写入的结果具有可见性。

`join` 是等待，不是互斥；它不能防止两个仍并行的 worker 同时修改 count。若主线程在两个 worker 都 join 后读取，读取可见并不代表中间更新没有丢失。可见性和原子性必须分开。

阻塞等待可能抛 `InterruptedException`。本章示例在顶层 oracle 中把它传播或恢复中断状态，不静默吞掉。中断是协作信号，不是强制杀线程；完整取消、超时和 Executor/Future 由下一章负责。

`Thread.sleep` 只暂停当前线程一段最短时间，不建立业务 happens-before，也不释放当前持有的 monitor。用 sleep 等另一个线程“应该完成”既慢又不可靠；用 join、latch 或 condition 表达事件。

## 5. Java 内存模型解决什么：允许优化，同时给正确同步以保证

编译器、JIT、CPU 和缓存可以重排或延迟普通读写，只要单线程可观察语义允许。Java 内存模型（JMM）定义线程间动作哪些执行合法、读能看到哪个写，以及同步动作如何建立顺序。它不是“所有线程共享一份立即一致内存”的直觉模型。

若两个冲突访问针对同一变量、至少一个是写，并且没有 happens-before 排序，就存在数据竞态。含数据竞态的程序可能出现反直觉结果；一次看似顺序一致的运行不能证明正确。无数据竞态的正确同步程序才能按更易推理的顺序一致方式理解。

JMM 中“先发生”不是墙钟更早，也不是源码行号更小。happens-before 是形式化偏序：若写 W happens-before 读 R，R 必须在内存模型允许的规则下看到 W 或更后写；若没有边，硬件恰好传播也没有语言保证。

并发 bug 常把三个问题混淆：可见性是“能否看到别线程写”；原子性是“一个操作能否被中间穿插”；有序性是“多个动作对别线程按何种顺序可见”。锁可同时提供互斥与内存同步，volatile 主要提供特定字段的可见/顺序，不让任意复合动作原子。

## 6. happens-before 的核心边

对本章最常用的规则：

1. 同一线程内，program order 中前动作 happens-before 后动作。
2. 对同一 monitor 的 unlock happens-before 后续成功 lock。
3. 对同一 volatile 字段的写 happens-before 后续读。
4. 调用 `Thread.start` happens-before 被启动线程中的动作。
5. 线程中的全部动作 happens-before 其他线程检测到它终止，例如 `join` 返回。
6. `CountDownLatch` 文档规定 countDown 前动作 happens-before 另一个线程成功 await 后动作。
7. happens-before 具有传递性。

关键词是“同一”。锁 A 释放与锁 B 获取没有这条 monitor 边；volatile `ready` 的写读不自动使另一个无关协议正确，除非数据写在 ready 写之前、数据读在 ready 读之后并通过传递性连接。同步策略必须覆盖所有相关访问。

`Lock` 实现要求成功 lock/unlock 具有与 monitor lock/unlock 对应的内存同步效果。失败的 tryLock 没有成功获取边。使用 `ReentrantLock` 时 lock 对象身份同样必须一致。

画 HB 图时把普通动作与同步动作分开：主线程写 config → start → worker 读；worker 写 result → 终止 → join 返回 → 主线程读。图中没有路径的共享读写就是审查重点。

## 7. 可见性与 volatile：信号可以，复合不变量不行

普通 boolean stop 的 worker 自旋，另一线程写 true，JMM 不保证 worker 何时或是否看见。`volatile boolean stop` 让写与后续读建立同步边，适合单字段状态信号。volatile 读写本身有明确内存语义，但业务仍需处理中断、资源清理和 CPU 自旋。

volatile 不提供互斥。`volatile int count; count++` 仍是读取 count、加一、写回。两个线程可读同一旧值再覆盖。配套故障用 barrier 强制两个线程都读取后才写，最终每次为 1 而非 2，确定性证明“volatile 可见 ≠ ++ 原子”。

多个字段共同构成不变量时，一个 volatile 标志可作为安全发布边：先写 data，再 volatile 写 ready；读线程先 volatile 读到 true，再读 data。但协议必须严格遵循顺序，后续更新和 check-then-act 仍可能需要锁或不可变快照。初学阶段不要用 volatile 拼复杂状态机。

字段是否 volatile 是结构证据的一部分。不能可靠写测试要求未同步 worker 必须永不停止，因为 bug 是否显现受 JIT/硬件影响。实验的 `MissingVisibilityEdgeFailure` 检查共享 ready 既非 volatile、访问方法也无 synchronized，并以 `MISSING_VISIBILITY_EDGE` 失败；正确版再用 volatile/latch 验证边。

## 8. 原子性：单次读写与业务操作不是一回事

对引用和大多数基本类型的单次读写具备一定原子性，不代表“检查后修改”整体原子。`count++`、`balance = balance - amount`、`if (!set.contains(id)) set.add(id)` 都跨多个动作。线程可以在动作之间交错。

原子操作的边界由业务不变量决定。若“仅当库存足够才扣减”，检查与扣减必须同一临界区；把 count 换成 `AtomicInteger` 只能原子加减，不能自动覆盖库存、审计和状态的组合不变量。

`AtomicInteger.incrementAndGet` 适合独立数值计数，它用原子 read-modify-write 和内存效果避免丢更新。CAS 更新函数可能被重试，函数不得隐藏不可重复副作用。复杂状态可用不可变对象加 `AtomicReference` CAS，但已超出零基础本章实现范围。

受控丢更新实验不是依赖一百万次碰运气：两个线程各读取 0，barrier 确认两次读取完成，再各写 1。无论谁最后写，结果都是 1。这个 schedule 是故障放大器，证明存在合法错误交错；它不声称真实调度总按此顺序。

## 9. check-then-act：每一步线程安全，组合仍可能竞态

“如果没有就加入”需要检查与加入作为一个原子业务动作。即使集合每个单独方法线程安全，两个线程都可能在 contains 时得到 false，再都 add。使用 `Collections.synchronizedList` 后在外部不锁同一包装对象，组合仍不原子。

修复选择取决于数据结构和语义：在同一 monitor 内包住检查+写；使用 Set 的原子 add 返回值；使用 ConcurrentHashMap 的 `putIfAbsent/computeIfAbsent`；或让单一所有者串行处理。不能只在 add 上加锁而让 contains 无锁。

本章夹具让两个线程先同时完成 `contains(false)`，再同时 add 到列表，稳定得到两个相同 ID 并抛 `CHECK_THEN_ACT_DUPLICATE`。正确实验用同一锁保护完整临界区，并断言恰好一项。

## 10. synchronized：monitor 身份与临界区决定合同

`synchronized (lock) { ... }` 获取对象关联 monitor，退出块时释放；异常退出也会释放。实例 synchronized 方法锁 `this`，static synchronized 方法锁对应 `Class` 对象。它们不是同一 monitor，混用可能没有互斥。

所有访问共享状态的路径必须遵循同一策略。写在锁内、读在锁外会破坏可见性和不变量；用 getter 加锁却直接暴露可变集合引用，调用方仍可绕过。把 lock 字段设为 private final，并在类注释说明 guarded-by 规则。

错误锁对象是高频 bug：每次调用 `synchronized (new Object())`，每个线程锁不同对象，等于没有互斥；两个 service 实例各锁 this 却修改同一 static 字段，也无效。配套故障用两个不同 monitor 加受控读写，稳定丢更新并报告 `WRONG_LOCK_IDENTITY`。

synchronized 是可重入的：同一线程持有 monitor 时可再次进入同一 monitor 的同步代码。可重入避免某些内部方法调用自死锁，但不解决多锁顺序环。临界区应只包含保护不变量所需代码，避免在锁内做未知耗时 I/O 或调用外部回调。

## 11. ReentrantLock：更灵活，也更容易忘记释放

`ReentrantLock` 提供与 synchronized 类似的互斥语义，并支持 tryLock、可中断获取、超时、公平选项和 Condition。若不需要这些能力，synchronized 往往更简洁并自动释放；不是“显式锁一定更高级/更快”。

标准结构是 lock 调用后立即进入 try，在 finally 第一件事 unlock：

```java
lock.lock();
try {
    count++;
} finally {
    lock.unlock();
}
```

不要把 `lock.lock()` 放在 try 内后无条件 unlock，因为获取前若异常，可能释放未持有锁；也不要在 finally 前 return/throw 漏掉释放。正确类把同一个 final lock 用于所有 count 访问。

公平锁在竞争时倾向等待最久线程，但不保证线程调度公平，吞吐也可能下降；无参 ReentrantLock 默认非公平。不要为“看起来公平”开启而无饥饿证据。`tryLock()` 的公平行为还有文档细节，需要按具体方法合同使用。

## 12. 不可变、线程封闭与安全发布：最好的共享写是没有共享写

不可变 record 的 final 字段、不可修改集合和构造时防御复制能减少同步需求。若对象构造后不变，多线程只读更容易安全。但引用仍须正确发布，例如在 start 前构造后传给 worker、通过 volatile/锁/latch 发布，或放入正确并发容器。

构造期间不要让 `this` 逃逸到 static 注册表或启动线程，否则其他线程可能看到未完成状态，final 字段特殊语义也有前提。builder 在一个线程完成后生成不可变快照，再发布，是常见模式。

线程封闭让每个线程使用自己的可变 accumulator，结束后通过 join/latch 汇总不可变结果，可避免细粒度共享。消息传递与单一所有者也是选择；本章不引入 Actor 或 Executor，但应认识到“给每个字段加锁”不是唯一架构。

`List.copyOf` 创建不可修改快照，但其中元素若可变仍可能变化；浅不可变与深不可变要区分。配套示例使用不可变 String ID 列表，worker 读取快照，原 builder 后续变化不影响已发布值。

## 13. 锁顺序、死锁、饥饿与活锁

安全性问题产生错误结果；活性问题让正确结果永远到不了。死锁是线程形成循环等待，例如 A 持 lock1 等 lock2，B 持 lock2 等 lock1。没有超时的 join 会让测试和程序一起挂住。

主流预防是全局锁顺序：所有代码按稳定 key 顺序获取多把锁，并逆序释放；或减少同时持锁。`identityHashCode` 不是天然业务全序且可能碰撞，真实设计需明确 tie lock。不要靠 sleep 改变先后。

实验不真的制造永久死锁。`LockOrderCycleFailure` 接受两条锁顺序 A→B 与 B→A，确定性检测有向环并抛 `LOCK_ORDER_CYCLE`。生产诊断再用 thread dump 查 “Found one Java-level deadlock”、BLOCKED 栈和 owned monitor。

饥饿是某线程长期拿不到资源，活锁是线程不断响应对方却无进展。公平锁可能缓解特定饥饿但有成本，不能替代有界等待和指标。局部单元测试不应承诺证明“永不饥饿”。

## 14. 等待与通知：优先高级协作器，理解 monitor 规则

`Object.wait` 必须持有同一对象 monitor，调用后释放 monitor 并等待；`notify/notifyAll` 也要求持有 monitor。醒来后要重新竞争锁，并在 while 中重新检查条件，因为可能虚假唤醒或条件已被其他线程改变。

零基础业务代码优先用 `CountDownLatch`、barrier、并发队列等语义清楚的工具，不手写 wait/notify 协议。latch 是一次性门闩，count 到 0 后不能重置；barrier 适合一组线程在阶段点汇合。选型要匹配生命周期。

本章用 latch 表达“所有 worker 准备好”和“主线程允许开始”，用 barrier 表达两次读取都完成。协作器本身建立 HB 边，因此不要用它来声称“无同步程序自然可见”；它只用于控制 schedule，把竞态的非原子部分暴露。

## 15. 确定性并发测试：证明错误交错存在，不等它碰巧出现

失败测试若是“两个线程各加一百万次，最终可能少”会有两种坏结果：机器快时一直绿，CI 负载变化又偶发红；提高次数只增加概率和耗时。更好的方式是把复合操作拆成可控阶段。

`DeterministicLostUpdate` 的两个 worker 执行 read → barrier → write。barrier 不保护 count，只强制危险交错，因此每次 expected 2、actual 1。`WrongLock` 在不同 monitor 内做相同阶段，证明“有 synchronized 关键字”不等于共享锁。

正确计数器测试则不依赖错误必须显现：50 轮，每轮两线程从同一 start gate 开始，各增加固定次数，join 后必须精确等于 expected。synchronized 与 ReentrantLock 两版都跑；脚本设置有界 join，并检查线程不存活，防止测试挂死。

可见性错误不应通过无限循环验证。测试检查同步结构、用 volatile/latch 正例验证消息传递，并在代码审查/JMM 推理中证明反例缺边。并发测试的超时是“测试未完成”的保护，不是业务正确性证明。

## 16. 调试线程问题：状态、栈、锁身份、进展指标

第一步保存进程 ID、时间、负载、线程名、业务 ID 与多份间隔 thread dump。单份 dump 是快照；多份能看栈是否变化。JDK `jcmd <pid> Thread.print -l` 可打印线程栈及 `java.util.concurrent` locks；本地还可用 `jstack`，生产权限和开销需评估。

看 dump 时先分组：RUNNABLE 是否在 CPU 循环或 I/O；BLOCKED 在等哪个 monitor、谁拥有；WAITING/TIMED_WAITING 在 join、latch、park 还是 sleep；线程是否都按相反顺序持锁。`-l` 的 ownable synchronizer 对 ReentrantLock 很重要。

线程名应包含稳定角色而非敏感数据，例如 `work-order-counter-1`。未命名线程堆栈难以关联。日志记录临界区前后会改变 timing，不能因此断言 bug 修好；用计数/状态指标与受控复现。

若结果错，画实际 read/write schedule；若不终止，找等待图与缺少 signal；若偶发旧值，找 HB 路径；若 CPU 高，找自旋和重试。修复后重跑原失败夹具和正确高频 oracle，不能只跑新快乐路径。

## 17. FactoryCare 同步实验设计

`SynchronizedCounter` 的 private int 只通过同步 increment/get 访问；`LockedCounter` 的所有访问使用同一 final ReentrantLock 和 try/finally；`AtomicInteger` 作为独立计数对照。每轮两个命名平台线程从 latch 同时开始，各加 200 次，50 轮应恒定 400。

生命周期 oracle 断言 start 前 NEW，worker 读取 start 前发布的 immutable snapshot，join 后 TERMINATED 并看到 result。volatile signal 正例用有界 join，不让测试无限挂。latch 的 memory consistency 保证也单独验证。

故障夹具共五类：barrier 强制丢更新；不同 monitor 强制丢更新；volatile count 的复合更新仍丢；check-then-act 产生重复 ID；锁顺序图出现环；另有结构性 missing visibility edge。每个进程只验证一种失败并输出稳定证据码。

实验不创建 Executor、不测墙钟性能、不依赖线程先后输出、不真的死锁。这样既覆盖 canonical 失败模式，也能在离线 CI 中稳定重放。

## 18. 与 TypeScript/Vue 的类比，以及失效处

JavaScript 主线程事件循环让普通同步代码通常不会被另一个 JS 回调在任意指令间抢占，Vue 响应式更新也有调度批次。这可帮助理解“共享可变状态需要明确所有者”，却不能直接类比 Java 多线程共享堆。

Web Worker 通过 structured clone/message 传递数据，更接近消息传递；SharedArrayBuffer/Atomics 才引入共享内存同步。Java 对象默认可被多个线程引用，没有自动 clone。Java `volatile` 也不是 Vue `ref`：前者是内存模型同步字段，后者是响应式依赖跟踪。

Promise/async 不等于线程，`await` 也不等于 monitor wait。Java Thread 可以真正并行执行 CPU 指令；执行在哪条线程由调用方/调度器决定。后续 Executor/虚拟线程章节再讨论任务调度。

## 19. 常见错误与可复用规则

- 错误：直接调用 `run` 以为启动线程。修复：理解 start 一次合同，用 join/协作器等待。
- 错误：static 字段天然共享所以天然可见。修复：为所有访问建立同一同步策略。
- 错误：volatile count++ 原子。修复：用 AtomicInteger 或锁覆盖完整 read-modify-write。
- 错误：只给写加锁、读不加。修复：所有相关读写遵循同一 monitor/Lock。
- 错误：`synchronized(new Object())`。修复：private final 稳定锁身份，测试不同实例/static 边界。
- 错误：用 sleep 修竞态。修复：用 happens-before 推理与 latch/join/lock 表达事件。
- 错误：多跑几次没失败即线程安全。修复：构造危险交错，正确版高频精确断言。
- 错误：锁内调用慢 I/O/未知回调。修复：缩短临界区，分离状态变更与边界动作。
- 错误：ReentrantLock 忘记 finally。修复：lock 后立即 try，finally 第一件事 unlock。
- 错误：真的死锁来做单测。修复：检测锁顺序环或用有界诊断夹具，避免挂住测试。

## 20. 独立练习与讲回

公开练习提供 start gate、join 超时和固定轮次，要求补齐 synchronized 与 ReentrantLock 计数器。starter 的 unsynchronized 实现会被 barrier 放大并以 `COUNTER_CONTRACT` 失败。不得通过降低 expected、删掉轮次或串行调用 worker 修复。

完成后运行 wrong-lock 与 volatile-not-atomic 夹具，画出每个 read/barrier/write；再用 `jcmd Thread.print -l` 输出字段列表说明若生产挂死要看什么。最后 120 秒讲回：可见/原子/互斥差异、六条 HB 边、锁身份、不可变发布和确定性测试原则。

复习五问：

1. `thread.run()` 与 `thread.start()` 的执行线程有何不同？
2. join 后 count 可见，为何仍可能少？
3. volatile 写读建立什么保证，为什么 `++` 仍不安全？
4. 两段 synchronized 何时互斥，锁对象不同会怎样？
5. 为什么要求错误版“有时失败”是糟糕的测试合同？

## 21. 本章边界与下一步

本章只建立原始 Thread、JMM、同步与锁的基础，不教授 Executor/Future、任务失败聚合、取消/超时、虚拟线程、并发集合全 API、结构化并发、无锁算法或分布式锁。`synchronized` 解决单 JVM 同一内存中的互斥，不能保护多个进程或数据库记录。

掌握后应能为一个共享字段指出所有访问、同步边和不变量，能从 thread dump 找等待关系，能用受控 schedule 复现竞态，并能说明何时用不可变/线程封闭减少锁。下一章再把任务提交、Future 结果、中断取消和虚拟线程放入更高层调度模型。

## 官方资料

- [JLS 25 第 17 章：Threads and Locks](https://docs.oracle.com/javase/specs/jls/se25/html/jls-17.html)
- [JLS 25：Happens-before Order](https://docs.oracle.com/javase/specs/jls/se25/html/jls-17.html#jls-17.4.5)
- [Java SE 25：Thread](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Thread.html)
- [Java SE 25：Thread.State](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Thread.State.html)
- [Java SE 25：Lock](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/locks/Lock.html)
- [Java SE 25：ReentrantLock](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/locks/ReentrantLock.html)
- [Java SE 25：CountDownLatch](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/CountDownLatch.html)
- [Java SE 25：AtomicInteger](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/atomic/AtomicInteger.html)
- [JDK 25 `jcmd` 手册](https://docs.oracle.com/en/java/javase/25/docs/specs/man/jcmd.html)
