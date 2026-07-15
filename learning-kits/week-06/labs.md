# Week 06 实验、FactoryCare 增量与故障注入

## 0. 安全规则

- 所有并发版本先与串行结果做相等断言；
- 每个 Future 等待都有超时；
- 不在单元测试里制造无法清理的永久死锁；
- Executor 必须由创建者关闭；
- 测试失败后不得遗留后台线程阻止 Maven 退出；
- 不使用 common pool 承担 FactoryCare 关键任务；
- 不开启 preview；
- 不接真实外部 API、数据库或消息队列。

## 实验 1：可重复的 lost update

普通循环多跑几次仍不能证明线程安全。为了稳定复现，创建一个教学专用 BrokenCounter：

1. 两个任务各自读取同一个 count；
2. 读取后通过 CyclicBarrier 会合；
3. 两者再写入 local + 1；
4. 最终结果稳定为 1 而不是 2。

该屏障只用于控制故障时序，不进入业务代码。

分别修复：

- synchronized increment；
- AtomicInteger.incrementAndGet。

然后回答：若更新同时涉及 count 和 lastUpdatedAt，AtomicInteger 是否足够？正确方向是保护跨字段不变量，不能只修一个计数。

## 实验 2：可见性与 volatile

创建一个工作线程循环检查 stopRequested。先使用普通 boolean，观察实验可能无法稳定重现；不要把偶然终止当成正确证明。

改为 volatile boolean，并用 Future.get(timeout) 验证能结束。记录：

- volatile 适合单一停止标志；
- 它不让 check-then-act 或 count++ 原子；
- 实际取消更应优先使用 interrupt，而不是自己发明一套标志。

## 实验 3：中断传播

创建模拟慢源：

    Result load() throws InterruptedException {
        latch.countDown();
        Thread.sleep(30_000);
        return result;
    }

测试步骤：

1. 提交任务；
2. 等 latch 确认已进入；
3. future.cancel(true)；
4. 任务捕获 InterruptedException；
5. 错误版本吞异常后继续循环；
6. 正确版本恢复中断并退出；
7. 断言 Executor 可在期限内终止。

不要通过固定 sleep 猜任务是否开始。

## 实验 4：有界 ThreadPoolExecutor

### 配置

创建教学池：

    new ThreadPoolExecutor(
        2,
        4,
        30,
        TimeUnit.SECONDS,
        new ArrayBlockingQueue<>(2),
        namedThreadFactory,
        new ThreadPoolExecutor.AbortPolicy()
    )

数字仅用于让饱和容易观察，不是生产参数。

### 饱和实验

用 CountDownLatch 阻塞已接收任务，连续提交超过：

    maximumPoolSize + queueCapacity

记录：

- 前两个任务使用核心线程；
- 后续先入队；
- 队列满后扩到 maximum；
- 再提交触发 RejectedExecutionException。

释放 latch 并正确关闭。

### 对照

观察 Executors.newFixedThreadPool 的队列类型，解释为什么它不满足本实验“有界积压”的需求。不要用内存耗尽来证明。

### CallerRuns 变体

换 CallerRunsPolicy，记录哪一个线程执行被回压的任务。说明它可能拖慢提交者、改变请求线程延迟，不能机械当最佳策略。

## 实验 5：Future 异常与关闭

提交一个会抛异常的 Callable：

- 不调用 get 时，观察为何业务代码可能没有处理失败；
- 调用 get 时捕获 ExecutionException，检查 cause；
- 使用 get(timeout)；
- 关闭流程覆盖 shutdown、await、shutdownNow 和中断恢复。

为线程命名，例如 factorycare-enrichment-1，便于线程转储定位。

## 实验 6：CompletableFuture 组合

### 三个数据源

建立可配置模拟器：

- MaintenanceSource：返回保养摘要；
- PartsSource：返回备件信息；
- FailureStatsSource：返回最近故障统计。

每个模拟器可配置：

- 成功结果；
- 等待 latch；
- 抛异常；
- 响应延迟；
- 记录当前并发数和历史最大并发数。

### 依赖图

三个调用互相独立：

    maintenance ─┐
    parts ───────┼─> combine -> EquipmentEnrichment
    stats ───────┘

使用显式 Executor 的 supplyAsync。可以 thenCombine 两两组合，或 allOf 后在聚合边界读取结果。

### 错误策略

- maintenance 必须成功：失败则整体失败；
- parts 可降级为 unavailable，并保留 degradation reason；
- stats 可降级为空统计，但保留 source failure；
- 总结果包含 completedSources 和 degradedSources；
- 不允许返回 null 表示降级。

### 超时

对 parts 设置超时后备，对整体设置总期限。验证：

- 调用方按期得到失败/降级；
- 底层模拟任务是否仍在运行；
- Executor 关闭能否使其响应中断；
- 日志保留 source 名称。

不要把 orTimeout 测试误写成“证明底层任务被杀死”。

## 实验 7：每任务虚拟线程

使用：

    Executors.newVirtualThreadPerTaskExecutor()

提交同样三个阻塞源，保持同步任务代码。验证任务中的 Thread.currentThread().isVirtual()。

### 稀缺资源限制

模拟 PartsSource 最多允许 3 个并发：

    Semaphore permits = new Semaphore(3);

对 50 台设备并发补全，记录 source 的最大活跃数，断言不超过 3。正确 acquire/release 结构：

    boolean acquired = false;
    try {
        permits.acquire();
        acquired = true;
        return source.load();
    } catch (InterruptedException cause) {
        Thread.currentThread().interrupt();
        throw ...
    } finally {
        if (acquired) {
            permits.release();
        }
    }

### 对照结论

- 可以创建很多虚拟线程；
- 进入 PartsSource 的并发仍是 3；
- 排队从线程池队列转为等待许可的虚拟线程；
- 仍需总超时和取消；
- CPU 密集计算不因此加速。

## 实验 8：CPU 与阻塞任务对照

准备两种相同数量任务：

1. sleep 或 latch 模拟阻塞；
2. 固定规模的纯 CPU 计算。

分别用串行、有限平台池、虚拟线程运行多轮。只记录本地实验数据：

- 硬件/CPU 核数；
- JDK 版本；
- 任务数量与单任务工作；
- 预热方式；
- 中位数或多轮范围。

不要以一次结果写“虚拟线程提升 X%”。预期理解是：虚拟线程主要提高阻塞型并发的可伸缩性，不制造更多 CPU。

## 实验 9：线程转储与死锁诊断

### 安全方式

创建单独的 DeadlockDemo main，而不是 JUnit 内永久挂起：

- 线程 A 获得 lockA 后等待 lockB；
- 线程 B 获得 lockB 后等待 lockA；
- 用 latch 确保双方先各持一把锁；
- 将进程单独启动；
- 使用 jcmd 或 jstack 采集转储；
- 观察线程名、状态、等待锁和持有锁；
- 终止演示进程。

命令按本机实际 PID：

    jcmd
    jcmd <pid> Thread.print -l

若当前 JDK 工具提供更适合虚拟线程的 dump 命令，可按官方帮助使用：

    jcmd <pid> help

### 修复

统一锁顺序，或使用可超时 tryLock 并设计回退。再次采集，证明不再形成同一死锁。

## 实验 10：JFR 与 JVM 观察

启动一个持续 30—60 秒的实验进程，包含：

- CPU 计算；
- 对象分配；
- 平台线程等待；
- 虚拟线程阻塞源。

使用 jcmd 查看可用命令并启动短 JFR。记录而非背命令：

- 哪类事件能看到 CPU 热点；
- 哪类事件能看到分配或锁；
- 事件对应哪个代码方法；
- 这是否足以证明根因。

JFR 文件可能含业务信息，不提交敏感生产记录。本周只使用自建数据。

## 实验 11：FactoryCare 三版补全服务

### 统一契约

输入：

    EquipmentId
    EnrichmentPolicy
      - totalTimeout
      - partsFallback
      - maxPartsConcurrency

输出：

    EquipmentEnrichment
      - maintenanceSummary
      - partsAvailability
      - recentFailureStats
      - degradedSources
      - completedAt

禁止用 null 表示失败。

### 版本 1：串行

按 maintenance、parts、stats 顺序调用。它是正确性 oracle：

- 所有成功字段；
- maintenance 失败整体失败；
- parts/stats 按策略降级；
- source 名和 cause 可追踪；
- 固定 Clock 产生 completedAt。

### 版本 2：平台池 + CompletableFuture

- 显式有界 ThreadPoolExecutor；
- 每个任务带 equipmentId/source；
- 三个源并发；
- parts/stats 降级；
- maintenance 失败；
- 总超时；
- 生命周期完整；
- 结果按 source 绑定，不按完成顺序塞入 List。

### 版本 3：虚拟线程

- 每任务虚拟线程；
- 保持同步 load 方法；
- PartsSource 用 Semaphore；
- 相同失败策略；
- 中断不吞；
- 不使用结构化并发 preview；
- 聚合过程可使用 Future，但必须有超时。

### 统一测试

同一参数化测试或契约测试运行三版：

| 场景 | 预期 |
| --- | --- |
| 全成功 | 字段完全相等 |
| maintenance 失败 | 整体失败且 source 明确 |
| parts 超时 | 结果成功但 degraded |
| stats 失败 | 空统计 + 失败元数据 |
| 完成顺序变化 | 字段不串位 |
| 调用取消 | 中断传播，资源关闭 |
| 大量设备 | Parts 最大并发不超限 |
| Executor 饱和 | 明确拒绝，不静默丢 |

## 实验 12：排序与二分算法副线

### 排序

实现或手推插入排序，只用于理解：

- 已排序前缀不变量；
- 最好/最坏时间；
- 稳定性；
- 为什么业务代码通常使用标准库排序。

不要在 FactoryCare 重写排序算法。

### 二分查找

实现半开区间 [left, right)：

    left = 0
    right = length

循环条件 left < right。查找第一个大于等于 target 的位置 lowerBound：

- 若 midValue < target，left = mid + 1；
- 否则 right = mid；
- 返回 left。

测试：

- 空数组；
- 单元素；
- target 小于所有；
- 大于所有；
- 存在多个重复；
- 不存在但位于中间。

写清有序前提、区间语义、循环不变量和 O(log n)。

## 故障注入总表

| 编号 | 故障 | 证据 | 修复 |
| --- | --- | --- | --- |
| F06-01 | count++ 并发丢失 | 屏障稳定复现 | 同步/原子操作 |
| F06-02 | volatile count++ | 仍丢更新 | 不把可见性当原子性 |
| F06-03 | containsKey + put | 重复创建 | 原子 Map API/更高层锁 |
| F06-04 | 吞 InterruptedException | 关闭超时 | 恢复中断并退出 |
| F06-05 | 无界队列 | 积压无上限 | 有界队列和拒绝 |
| F06-06 | submit 后不 get | 失败无业务处理 | 收集 Future/统一观察 |
| F06-07 | 每个 CF 立即 join | 实际串行 | 先启动独立任务后聚合 |
| F06-08 | exceptionally 返回 null | 下游 NPE/假成功 | 明确降级值或传播 |
| F06-09 | orTimeout 当作取消 | 底层仍运行 | 底层超时、中断与资源关闭 |
| F06-10 | 虚拟线程无限打第三方 | 下游过载 | Semaphore/服务限额 |
| F06-11 | 按完成顺序组装字段 | 数据源错配 | 具名 Future/结果类型 |
| F06-12 | Executor 未关闭 | Maven 不退出/线程泄漏 | 所有者管理生命周期 |
| F06-13 | 二分闭开区间混用 | 越界/死循环 | 固定 [left,right) 不变量 |

## 最终证据

    java -version
    mvn -q test
    jcmd

保存：

- 三版统一契约测试；
- 有界池饱和证据；
- 中断前后证据；
- Semaphore 最大并发计数；
- 一份线程转储注释；
- 本地实验限制说明；
- 二分边界测试；
- [无 AI 与 G1 评分](./assessment.md)。

