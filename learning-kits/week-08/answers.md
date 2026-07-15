# Week 08 独立答案册

> 只有在 Week 08 考核 A 和阶段门 G1 都提交后才阅读。本文件是判断锚点，不是可复制的完整项目。

## 1. 概念自测参考

### 1.1 count++ 为什么不原子

它包含读取、计算和写回。两个线程可能读取同一旧值并覆盖彼此更新。volatile 只能改善可见性/顺序，不能把三步合为原子操作。

### 1.2 ConcurrentHashMap 的复合竞态

单个 containsKey 和 put 各自线程安全，不代表二者组合原子。两个线程可能都看到不存在再各自创建。使用 putIfAbsent/computeIfAbsent，或在业务不变量更复杂时用适当同步。

### 1.3 中断恢复

InterruptedException 会清除中断状态。若当前层不能完整消费取消语义，应 Thread.currentThread().interrupt() 恢复，再向上转换/退出，让更外层知道任务被取消。

### 1.4 无界队列与 maximum

ThreadPoolExecutor 在核心线程满后优先入队。无界队列几乎永不满，因此通常不会扩到 maximum；任务可能无限积压并耗尽内存。

### 1.5 submit 异常

异常保存在 Future 中，并在 get 时用 ExecutionException 暴露。若提交后丢弃 Future，业务层可能没有处理失败。线程工厂 uncaught handler 也不能替代 Future 观察。

### 1.6 thenApply 与 thenCompose

thenApply 对结果做普通 T→R 映射；若函数返回 Future，会形成嵌套。thenCompose 把 T→CompletionStage<R> 铺平成单一阶段。

### 1.7 超时不等于终止

orTimeout 改变 CompletableFuture 的完成状态，底层工作可能仍运行。要依赖客户端 I/O 超时、协作中断和资源生命周期，并用测试观察退出。

### 1.8 虚拟线程不池化

虚拟线程本身廉价，通常按任务创建。若要限制下游容量，应限制连接、许可或请求，而不是用固定虚拟线程池把“资源限流”伪装为“线程限流”。

### 1.9 CPU 密集

CPU 核数未增加。无限 CPU 任务只会争抢承载线程和缓存，增加调度与延迟。应有界并行并测量。

### 1.10 堆与栈现象

堆 OOM 常与对象保留/分配有关；StackOverflowError 常见于单线程调用栈过深。进程内存高还可能来自直接/本地内存，不能只看堆。

### 1.11 nanoTime

一次测量受类加载、JIT、GC、OS 调度和热状态影响。至少多轮、预热、等工作量；严谨微基准使用 JMH。本周只做趋势实验。

### 1.12 不用结构化并发

JDK 25 中仍是 preview。项目策略是不启用 preview 作为主路径；学习任务生命周期理念，但用稳定 Executor/Future API。

## 2. 考核 A 参考结构

### 2.1 结果不使用 null

一种表达：

    record SourceResult<T>(
        Optional<T> value,
        Optional<SourceFailure> failure
    ) {
        static <T> SourceResult<T> success(T value) { ... }
        static <T> SourceResult<T> degraded(SourceFailure failure) { ... }
    }

也可以为每个源建 sealed result。重点是“无数据”和“源失败”可区分。

### 2.2 平台池

参考参数只用于考试：

    ThreadPoolExecutor executor = new ThreadPoolExecutor(
        3,
        6,
        30,
        SECONDS,
        new ArrayBlockingQueue<>(12),
        namedFactory,
        new ThreadPoolExecutor.AbortPolicy()
    );

真实参数需根据请求率、任务时间、下游承载和内存测量，不把这里抄进生产。

### 2.3 先启动再聚合

    maintenanceFuture = supplyAsync(loadMaintenance, executor)
    partsFuture = supplyAsync(loadParts, executor)
    statsFuture = supplyAsync(loadStats, executor)

    // 到聚合边界再组合/等待，不在每行立即 join。

使用具名变量或具名 record，避免按完成顺序 List.get(0/1/2) 错配。

### 2.4 失败策略

- maintenance 的异常不恢复成空值，转为整体 EnrichmentFailed；
- parts exceptionally/handle 转为 SourceResult.degraded；
- stats 同理；
- whenComplete 可记录 source、设备、耗时，但不泄漏敏感数据；
- CompletionException 解包时保留根 cause。

### 2.5 虚拟线程与 Semaphore

    final class LimitedPartsSource {
        private final Semaphore permits = new Semaphore(2);

        PartsAvailability load(EquipmentId id) {
            boolean acquired = false;
            try {
                permits.acquire();
                acquired = true;
                return delegate.load(id);
            } catch (InterruptedException cause) {
                Thread.currentThread().interrupt();
                throw new SourceInterrupted("parts interrupted", cause);
            } finally {
                if (acquired) {
                    permits.release();
                }
            }
        }
    }

若 delegate.load 也声明 InterruptedException，放在同一 try 并继续恢复中断。最关键是未成功 acquire 时不能 release。

### 2.6 生命周期

局部实验可：

    try (ExecutorService executor = ...) {
        ...
    }

应用级池则由拥有它的组件在生命周期结束时 shutdown/await。不要让服务方法每次请求创建共享平台池；虚拟线程 per-task executor 的作用域也需清楚。

## 3. lowerBound 参考

    int lowerBound(int[] values, int target) {
        int left = 0;
        int right = values.length;

        while (left < right) {
            int mid = left + (right - left) / 2;
            if (values[mid] < target) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }

        return left;
    }

不变量：

- [0,left) 的值都小于 target；
- [right,n) 的值都大于等于 target；
- 候选区间是 [left,right)。

每轮候选区间严格缩小。使用 left + (right-left)/2 避免 left+right 潜在溢出。

## 4. G1 参考模块边界

一种可接受结构：

    domain/
      Equipment
      WorkOrder
      WorkOrderStatus
      Priority
      value objects
      domain exceptions
    application/
      EquipmentService
      WorkOrderService
      WorkOrderQueryService
    repository/
      EquipmentRepository
      WorkOrderRepository
      in-memory implementations

不要求照搬分层名。判分关注：

- WorkOrder 自己拒绝非法状态；
- Service 编排仓储和跨对象规则；
- 仓储返回快照/只读集合；
- DTO/summary 不泄漏可变实体集合；
- 测试按行为，而非私有方法。

### 4.1 唯一编号

应用服务先检查能给友好错误，但内存仓储仍应在 save 时维护唯一索引并拒绝重复。Week 15 后真正唯一性要有数据库约束；本周不能声称并发安全。

### 4.2 状态转换

    void triage() {
        requireStatus(CREATED);
        status = TRIAGED;
    }

    void assign(TechnicianId technicianId) {
        requireStatus(TRIAGED);
        this.technicianId = requireNonNull(technicianId);
        status = ASSIGNED;
    }

比 `setStatus(WorkOrderStatus any)` 更能保护不变量。

### 4.3 查询

空结果返回空列表。过滤可使用循环或清晰 Stream；按 Priority rank、createdAt、id 稳定排序。条件对象可表达可选条件，但不把 Optional 当核心实体字段。

### 4.4 按技师统计

明确定义“未关闭”。G1 最小词表均未关闭，但代码仍应使用状态语义方法，例如 status.isClosed()，为后续词表扩展留出单一规则位置。

## 5. 现场变更参考

### 受监管设备最低 `HIGH`

不要新增已经存在的枚举值。现场变更应把新业务规则放入明确的优先级策略，并同步检查：

- 非受监管设备保持原结果；
- 原本 `LOW/MEDIUM` 的受监管设备提升到 `HIGH`；
- 原本 `HIGH/CRITICAL` 不降级；
- 参数化测试覆盖监管标志与原规则交叠；
- 查询排序仍使用显式业务 rank；
- 若策略输入或摘要增加监管标志，映射与测试同步更新。

### 时间半开区间

    !createdAt.isBefore(from)
        && createdAt.isBefore(before)

from 包含，before 不包含；验证相等边界。

### 技师未关闭工单上限

把上限放在应用服务的分配用例中：先按 `TechnicianId` 查询当前工单，只统计 `!status.isClosed()`，已有 2 张时允许分配，已有 3 张时拒绝。测试还要覆盖 `CLOSED/CANCELLED` 不占用名额、查询属于另一技师的工单不计入，以及拒绝后目标工单仍为 `TRIAGED`、没有保存半成品 assignment。

本周内存仓储只能证明单进程顺序调用的规则，不能声称并发下永不超额；数据库阶段需要重新设计事务与锁/约束策略。现场变更若抽到此题，必须明确这个证据边界。

### 统计按优先级再分组

把原“技师 → 未关闭数量”改为“技师 → 优先级 → 未关闭数量”。先复用同一个 `!status.isClosed()` 过滤规则，再按 `TechnicianId` 和 `Priority` 两级聚合；不要复制一份新的“未关闭”定义。返回只读快照，并用显式 `Priority.rank()` 固定优先级展示顺序，不依赖 enum 声明顺序或 `HashMap` 迭代顺序。

测试至少覆盖：同一技师两个优先级、两名技师相同优先级、`CLOSED/CANCELLED`排除、空结果、稳定顺序，以及修改返回Map不能污染仓储/服务内部状态。循环或清晰的分组实现都可；满分关键是语义唯一、复杂度能解释（一次扫描平均 `O(n)`）并同步修改调用方断言。

### 摘要增加设备编码

修改输出 record 和 mapper，不给 WorkOrder 暴露任意可变 Equipment 引用，也不让调用方自行去仓储拼装 N+1 概念（数据库阶段再深入）。

## 6. 三个常见 AI 质量问题

阶段门要求至少指出三个，候选包括：

- 生成公开 setStatus 绕过状态机；
- HashMap 唯一检查与保存分离，错误声称并发安全；
- 返回内部 List，外部可修改仓储；
- Optional.get；
- Stream peek 修改实体；
- equals/hashCode 使用可变状态；
- catch Exception 返回 false；
- 时间使用 Instant.now() 导致测试不稳定；
- 无界线程池或 common pool；
- 虚拟线程无限打下游；
- 测试只覆盖成功路径。

必须从实际提交里找证据，不能机械列清单。

## 7. 线程转储阅读锚点

先按线程名找到任务，再看：

- RUNNABLE、WAITING、TIMED_WAITING、BLOCKED；
- 最上方业务栈帧；
- waiting to lock / locked 信息；
- 是否存在 JVM 报告的 deadlock；
- 多个线程是否卡在同一外部调用；
- 是否只是采样瞬间。

一次 dump 是快照。复杂问题应多次采集或使用 JFR/trace 关联。

## 8. 评分判断

### 通过且可进入 Spring

- 能独立写、测、改内存工单；
- 并发实验没有资源泄漏；
- 知道虚拟线程的适用与边界；
- 能用证据定位至少一个故障；
- 不把概念实验包装成生产高并发经验。

### 暂缓

- 无法解释状态/集合/异常；
- 测试只有成功路径；
- Future 超时后后台永远运行；
- 吞中断；
- 用 parallelStream/common pool 逃避设计；
- 二分区间频繁混用；
- 口述严重依赖答案措辞。

## 9. 考后变体

1. 把 Semaphore 许可改为 1，取消一个等待许可的任务，证明许可数不增加；
2. 把 parts 改为必须成功，maintenance 改为可降级，检查策略没有写死在基础设施类；
3. 实现 upperBound：第一个大于 target；
4. 用 lowerBound 和 upperBound 返回重复 target 的区间；
5. G1 新建“检查任务”最小服务，使用不同状态和唯一键。

## 面试校准

> 先提交[面试题](./interview.md)的独立回答再阅读。以下提供机制、选择和诚实边界，不是可直接背诵的稿件。

1. **并发/并行**：并发是多个任务在时间上交错推进，并行是同一时刻实际执行。单核可以并发但 CPU 任务不能真正并行。async 表达结果/调度，不自动等于并行；增加并发可能提高吞吐，也可能因排队与争用增加延迟。
2. **线程/任务**：任务描述工作，线程是执行载体。线程池让一个线程依次执行多个任务；CompletableFuture 的不同阶段也可能由不同线程执行，它本身不是线程。
3. **count++**：包含读、计算、写回，多个线程可能丢更新。单值计数可用 AtomicInteger，复合字段不变量需锁或不可变状态整体替换。LongAdder 适合高争用统计，但 `sum()` 不是业务余额的原子瞬时快照。
4. **原子/可见/顺序**：原子性关心操作是否不可分；可见性关心一个线程何时看见另一个线程写入；顺序性关心重排与 happens-before。单个并发容器操作安全不自动保护跨操作业务不变量。
5. **synchronized/volatile**：synchronized 在同一监视器上提供互斥及进入/退出可见性；volatile 提供该变量的可见与顺序语义，不让复合操作原子。锁对象必须稳定。JDK 24 起虚拟线程已改进 synchronized 相关 pinning，JDK 25 不能再背“一定 pin”，仍需诊断锁竞争及 native/foreign 阻塞。
6. **ConcurrentHashMap**：contains+put 是两个原子操作组成的竞态；按 key 的简单创建可用 putIfAbsent/computeIfAbsent，复杂跨 Map 不变量仍需更高层同步。映射函数应短小，慢 I/O 会阻塞相关更新并放大争用。
7. **中断**：协作式取消信号，不是强杀。许多阻塞方法抛 InterruptedException 并清除标志；当前层不消费取消语义时应恢复标志并退出/传播。cancel(true) 只是请求，CPU 循环还需主动检查状态。
8. **sleep/wait/join**：sleep 暂停当前线程且不释放已有监视器；Object.wait 必须在对应监视器内并释放它等待通知；join 等线程结束。测试用 latch/barrier 表达阶段，不靠 sleep 猜时序。
9. **死锁/活锁/饥饿**：死锁是循环等待，活锁是持续响应却无进展，饥饿是长期拿不到资源。固定锁顺序、缩小范围、超时与业务回退可降低风险；线程转储可展示等待与持有关系。
10. **线程池参数**：提交时通常先补 core，core 满后入队，队列满再扩到 maximum，最后拒绝；无界队列使 maximum 常失效并可能无限积压。参数由到达率、任务耗时、CPU/阻塞比例、下游容量和内存测量决定。
11. **拒绝策略**：Abort 明确失败；CallerRuns 让提交线程执行并形成反馈，但会拖慢 Web 请求线程；Discard/DiscardOldest 可能静默丢核心业务。重试必须有上限、退避和幂等，不能把拒绝变成重试风暴。
12. **execute/submit**：execute 无 Future，未捕获异常进入线程异常处理；submit 返回 Future，异常在 get 时以 ExecutionException 暴露。丢弃 Future 会让失败缺少业务观察；get 应有期限，cancel 仍是协作请求。
13. **关闭**：所有者停止接收任务，shutdown，有限 await，超时后 shutdownNow 请求中断，再次等待并记录未结束任务；自身被中断时恢复状态。每请求创建共享平台池会反复分配且难管理；测试不退出先查非 daemon 池和卡住任务。
14. **CF 组合**：thenApply 普通映射，thenCompose 铺平异步依赖，thenCombine 合并独立结果，allOf 只给完成信号，值需从具名 stage 读取。Async 后缀未指定 Executor 时通常进入 common pool；每创建一个就 join 会重新串行化。
15. **异常阶段**：exceptionally 仅失败时恢复为值；handle 在成功/失败都转换；whenComplete 主要观察和记录。返回 null 会制造“成功 null”；CompletionException 要保留根 cause 和 source 上下文。
16. **超时/取消**：orTimeout 让同一 CompletableFuture 异常完成，completeOnTimeout 提供后备值，都不保证底层 I/O 停止。底层还需客户端超时、协作中断和资源关闭，并测试 Executor 能在期限内终止。
17. **虚拟线程**：JDK 21 起稳定，由 JVM 调度，适合大量阻塞等待并保留同步代码，不制造更多 CPU。按任务创建，不建固定虚拟线程池；可用 `Thread.currentThread().isVirtual()` 检查。
18. **仍需限流**：线程廉价不代表连接、API 配额、文件描述符或内存无限。大量虚拟线程等待少量连接仍会排队并占资源；用连接池/Semaphore/服务限额，只有 acquire 成功才在 finally release，中断时恢复并退出。
19. **CPU 密集**：核心数没增加，无限虚拟线程只增加竞争。CPU 任务使用有界并行并测量；混合流程把阻塞等待和计算阶段分开设置资源边界，不能按线程类型直接下结论。
20. **JDK 25 边界**：Structured Concurrency 是第五次 preview，本项目不开 preview，不使用 StructuredTaskScope；Scoped Values 在 JDK 25 已正式定稿，但基础阶段没有必须使用它的上下文传播需求。简历只能写了解结构化并发概念，不能写成项目已采用。
21. **堆/栈**：堆主要承载对象实例，线程栈承载栈帧和执行状态；这是高层模型，JIT 可做逃逸分析。深递归常触发 StackOverflowError；堆 OOM 看对象保留/分配，进程内存还可能来自 Metaspace、direct/native 和线程栈。
22. **Metaspace**：主要保存类元数据，位于本地内存而不是 Java heap。大量动态类与类加载器泄漏可耗尽；可用 jcmd/JFR/类直方图等结合实际版本观察。
23. **GC/JIT**：GC 回收不可达对象，但何时执行不由“刚不可达”直接决定，`System.gc()` 也不是立即回收保证；JIT 编译优化热点代码，因此冷启动一次计时包含类加载和编译影响，需要预热与多轮。
24. **线程转储**：能看到线程状态、栈、锁、死锁和采样时的阻塞位置。WAITING 可能是正常等待，单次 dump 不能证明长期根因；用线程名、taskId、多次采样和 JFR/日志关联源码。大量虚拟线程按当前 JDK 提供的 dump/JFR 命令诊断。
25. **JFR**：低开销记录 CPU、分配、锁、I/O 等事件，比单次 dump 更有时间维度；仍需映射到业务代码。记录可能含路径、类名和业务数据，不能直接公开。满分回答要引用本周真实事件，否则说未验证。
26. **并发测试**：用 latch/barrier 控制时序、Future timeout 防挂起、串行 oracle 做契约对照。屏障可让两个线程都读旧值后再写，稳定复现 lost update。测试通过只覆盖已构造交错，不是线程安全形式证明。
27. **模型选择**：先看依赖图、CPU/阻塞、失败组合、运行环境和下游限额。平台池适合显式有限线程/队列，CompletableFuture 适合组合阶段，虚拟线程适合大量阻塞同步任务；可组合但不能为了简历混用。共同取消若不用 preview，需用稳定 Future/Executor 手工管理并诚实说明局限。
28. **二分边界**：常见错是闭/半开区间混用、区间不缩小、mid 溢出、有序前提或重复语义不清。lowerBound 的 `[0,left)` 都小于 target、`[right,n)` 都大于等于 target；不存在时返回插入位置，upperBound 把判断改为寻找第一个大于 target。
29. **诚实项目表达**：只有串行、有界平台池+CF、每任务虚拟线程三版、统一契约测试和 Semaphore 上限记录真实存在后，才能用过去时介绍。说明必须成功/可降级/超时/中断/错配/关闭证据，并明确这是可控模拟，不是生产 QPS。学习对照可保留，业务主路径只选一版并写决策。
30. **反向审查清单**：优先检查无界队列、关键任务 common pool、吞中断、无期限 get/join、null 降级、按完成顺序错配、虚拟线程无限压下游、Executor/permit 泄漏、sleep 猜测测试、preview API、一次计时冒充性能结论。每项都要连接可执行失败测试、线程转储、JFR 或生命周期日志，不能只列名词。
