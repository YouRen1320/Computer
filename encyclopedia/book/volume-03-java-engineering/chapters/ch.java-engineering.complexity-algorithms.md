---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.complexity-algorithms
title: 复杂度、搜索、排序与基础数据结构选择
responsibility: 用可测规模解释时间空间成本并选择基础结构，不追求算法竞赛技巧或严格数学证明
volume: '03'
order: 6
level: L1
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.complexity-algorithms.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-engineering.associative-collections
- ch.java-engineering.sorting-comparators
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
  text: 在 120 秒内解释复杂度、搜索、排序与基础数据结构选择的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - algorithm-complexity
  - algorithm-choice
  covers_topics:
  - algorithm.big-o
  - algorithm.time-space-tradeoff
  - algorithm.input-size
  - algorithm.linear-binary-search
  - algorithm.sorting-cost
  - algorithm.list-set-map-choice
  uses_capabilities:
  - java.collections-generics
  - java.arrays
  - java.methods
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：为 10²/10⁴/10⁶ 条工单比较线性查找、排序后二分、HashMap 查找的操作次数与内存取舍
  covers_topic_groups:
  - algorithm-complexity
  - algorithm-choice
  covers_topics:
  - algorithm.big-o
  - algorithm.time-space-tradeoff
  - algorithm.input-size
  - algorithm.linear-binary-search
  - algorithm.sorting-cost
  - algorithm.list-set-map-choice
  uses_capabilities:
  - java.collections-generics
  - java.arrays
  - java.methods
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 从嵌套扫描和每次查询重复排序的实现中定位复杂度热点，替换结构后用规模曲线复核
  covers_topic_groups:
  - algorithm-complexity
  - algorithm-choice
  covers_topics:
  - algorithm.big-o
  - algorithm.time-space-tradeoff
  - algorithm.input-size
  - algorithm.linear-binary-search
  - algorithm.sorting-cost
  - algorithm.list-set-map-choice
  uses_capabilities:
  - java.collections-generics
  - java.arrays
  - java.methods
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 复杂度、搜索、排序与基础数据结构选择

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Set、Map、键相等性与哈希契约》](ch.java-engineering.associative-collections.md)：独立完成复杂度与规模、搜索排序与结构前，必须先具备「Set、Map、键相等性与哈希契约」已经验证的知识与失败边界
- [《Comparable、Comparator 与稳定排序》](ch.java-engineering.sorting-comparators.md)：独立完成复杂度与规模、搜索排序与结构前，必须先具备「Comparable、Comparator 与稳定排序」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。局部 oracle 只验证固定输入的结果、操作次数和趋势，不等于生产性能证明；P9 的零基础试读、人工版式/无障碍检查、独立全面审查和全仓回归尚未执行，章节不能据此成为 `verified`，也不会修改 `PROGRESS.md`。

程序在 10 条数据上“一瞬间完成”，不代表 100 万条仍可接受。反过来，一段在共享笔记本上偶尔慢 2 毫秒的代码，也不能仅凭一次墙钟读数被判定为算法问题。复杂度提供一种与具体机器分开的语言：先定义输入规模 n，再数核心操作如何随 n 增长，最后结合常数、内存、数据分布和真实测量做选择。

FactoryCare 中常见问题很朴素：按 ID 查一张工单，是每次扫描 List，先排序后二分，还是建立 Map？导入时查重复，是嵌套 contains，还是 Set？展示一次排序与每次查询重复排序，成本完全不同。结构不是越“高级”越好；正确选择取决于需要保留顺序/重复、查询次数、更新频率、规模上限和内存预算。

本章从零解释输入规模、Big-O、常数与低阶项、最好/最坏/平均、摊还成本、时间—空间取舍、线性/二分搜索、排序成本、List/Set/Map 选型，以及 Java 微基准误区。不追求严格数学证明和算法竞赛技巧。基线为 **JDK 25**，官方资料复核日期为 **2026-07-16**。

## 1. 可观察完成证据

1. 在 120 秒内用自己的例子解释 O(1)、O(log n)、O(n)、O(n log n)、O(n²)，并强调它们不是秒数。
2. 为 n=10²、10⁴、10⁶ 写出最坏线性比较次数、二分比较上界和一次建立索引后的查询操作模型，不用墙钟充当 oracle。
3. 实现线性搜索与二分搜索，验证相同 found/missing 结果；证明未排序输入直接二分是前置条件错误。
4. 从双重 List 查重和“每次查询都复制+排序”中识别热点，改用 Set/Map 或复用已排序快照，并用固定规模曲线复核增长趋势。
5. 写明优化增加的空间、构建成本、更新成本和语义变化；不能只报“更快”。

配套工件：

- [复杂度与搜索计数示例](../../../examples/encyclopedia/ch.java-engineering.complexity-algorithms/README.md)
- [FactoryCare 结构选型实验](../../../labs/encyclopedia/ch.java-engineering.complexity-algorithms/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.complexity-algorithms/README.md)

所有自动验证固定输入、固定操作计数，不读取网络、当前时间或随机数。公开 starter 的预期失败不是完成证据。

## 2. 第一步永远是定义输入规模 n

“这个方法是 O(n)”之前必须说 n 是什么。对 List 查找，n 通常是列表元素数；对矩阵，可能有行 r 和列 c；对图，可能是节点 V 和边 E；对字符串比较，还可能受共同前缀长度影响。

FactoryCare 导入去重中，n 是导入行数；如果每行设备 ID 长度有上限，可把字符串比较常数视作有界。若 ID 可长到百万字符，`equals` 本身就不能简单当 O(1)。模型必须抓住会随业务规模变化的量。

一次 API 请求有 100 条，但系统累计有 100 万条时，查询究竟扫请求内数组还是全库缓存？如果答错 n，复杂度结论再漂亮也无用。先画出数据边界、所有权和循环范围，再数操作。

多参数复杂度不要急着合并。将 n 条新数据与 m 条旧数据逐对比较是 O(nm)；只有在 n≈m 的特定场景才简写成 O(n²)。保留 n/m 能帮助发现“批次小但历史表巨大”的真实风险。

## 3. Big-O 描述增长上界，不是运行时间单位

Big-O 关注当 n 增大时，某项资源增长的阶。`3n + 20` 记作 O(n)，因为常数倍和固定项不会改变长期增长类别；`n² + n` 记作 O(n²)，高阶项最终主导。它不说 n=10 时谁更快，也不说执行需要多少毫秒。

常见阶：

| 阶 | n 扩大 10 倍的直觉 | 典型场景 |
| --- | --- | --- |
| O(1) | 操作数大致不随 n 增长 | 良好散列下 HashMap 单次 get 的平均模型 |
| O(log n) | 只增加固定几步 | 随机访问有序数组上的二分搜索 |
| O(n) | 大致 10 倍 | 最坏线性扫描、完整遍历 |
| O(n log n) | 略高于 10 倍 | 通用比较排序 |
| O(n²) | 大致 100 倍 | 两两比较、List 嵌套查重 |

O(1) 也可能有很大常数；O(n) 的小 n 可能更快。Big-O 不是忽略现实，而是先隔离增长风险。做工程决定时再加入常数、局部性、分配、GC、并行、输入分布和维护成本。

严格分析还会用 Θ 表示紧确增长、Ω 表示下界。本章重点是能识别工程热点，不强迫初学者做形式证明；但不能把 Big-O 误称“平均时间”或“最坏秒数”。说明是最坏、平均还是摊还模型。

## 4. 最好、最坏、平均与业务分布

线性搜索第一个元素时只比较 1 次，最好 O(1)；目标在末尾或缺失时比较 n 次，最坏 O(n)。如果目标位置均匀，平均仍随 n 线性增长。生产查询若大部分缺失，最坏路径可能就是常态。

HashMap 在 hash 分布良好时基本 get/put 平均接近常数，但糟糕碰撞会退化；官方措辞也带前提。不能把“HashMap O(1)”写成无条件保证。键合同错误首先是正确性问题，碰撞分布才是性能问题。

排序对已排序、逆序和高重复输入可能有不同常数或适应行为。JDK 25 List.sort 的实现说明是适应性稳定归并排序，但业务合同不依赖其内部阈值。若输入分布可预测，测量应包含代表数据而非只有随机唯一值。

报告要写场景：“n=10000，目标缺失，线性比较 10000 次”；不要只写“平均很快”。把数据分布、命中率、更新率和查询次数作为模型输入。

## 5. 如何从代码数出复杂度

一个从 0 到 n-1 的循环，每步固定工作，是 O(n)。两个先后独立循环各 n 次，总计 2n，仍 O(n)；两个嵌套循环各 n 次，总计 n²，才是 O(n²)。不要看到两个 for 就自动判平方。

循环变量每次翻倍：1、2、4、8……到 n，只需约 log₂n 步，是 O(log n)。二分搜索每次丢掉一半候选区间也有同样增长。

循环体里调用的方法必须展开分析：遍历 n 个元素，每次 `list.contains` 最坏又扫描 n，整体 O(n²)；遍历 LinkedList 时每次 `get(i)` 也可能把访问放大成平方。方法名短不等于成本固定。

递归不在本章深入，但也要数每层子问题数量和规模。不要仅因函数调用自身就说 O(n)；二分递归深度是 log n，朴素分叉递归可能指数增长。

## 6. 摊还成本：偶尔昂贵，整段操作仍可预测

ArrayList 尾部 add 在有容量时近似常数；容量不足会分配更大数组并复制已有引用。某一次扩容是 O(n)，但连续添加 n 项的总复制量仍与 n 同阶，所以称尾部追加摊还 O(1)。这不表示每次延迟相同。

HashMap 超过阈值时重建桶也会出现昂贵单次操作。预估容量可减少扩容，但过大容量占内存并影响 HashMap 迭代成本。摊还分析告诉总体趋势，延迟敏感系统仍要关注尖峰。

“平均”与“摊还”不同。平均常依赖输入/概率分布；摊还是对一个操作序列分摊偶发重成本，不需要假设随机输入。报告中不要混用两个词。

测试单次 add 的纳秒无法证明摊还复杂度。可用操作计数或多规模总趋势辅助理解；正式延迟测量要记录分位数、预热和环境。

## 7. 空间复杂度与时间—空间取舍

只保留 List 原数据需要 O(n) 引用空间；再建立 `Map<Id, WorkOrder>` 会增加 O(n) 个索引条目和桶/节点开销，换取大量查询的平均快速定位。不能说 Map “O(1) 所以免费”。

排序副本需要额外 O(n) 列表引用；某些排序实现还使用临时空间。就地排序减少一份容器，却改变输入顺序，可能破坏审计或共享状态。空间选择同时是所有权选择。

预计算每个工单的昂贵排序键增加 O(n) 空间和构建时间，却避免 O(n log n) 次重复解析。键若随对象变化，还要保证失效/重建，否则用空间换来了错误。

内存分析不要用“对象数×字段数”假装精确字节。对象头、引用宽度、对齐、JVM 参数和实现都会影响。L1 先报告阶和主要附加结构；需要精确容量时使用受控工具与目标 JVM 实测。

## 8. 线性搜索：无前置排序，适合一次或小规模查询

线性搜索从头逐项比较，找到即返回，缺失扫完。它适用于未排序数据、只查一次、小集合、或必须按 encounter order 找第一项的场景。实现简单且局部性好，不能仅因 O(n) 就否定。

```java
static int linearSearch(List<String> ids, String target) {
    for (int index = 0; index < ids.size(); index++) {
        if (ids.get(index).equals(target)) {
            return index;
        }
    }
    return -1;
}
```

对 ArrayList 按索引遍历可保持 O(n)；更通用写法用增强 for/Iterator，避免对 LinkedList 的重复 get。若要返回所有匹配，找到后不能提前结束，成本必然完整扫描。

线性搜索不需要额外索引，也没有维护成本。数据每次只使用一次时，先建 Map 可能做了更多工作；选择要考虑查询次数 q，而不仅是单次复杂度。

## 9. 二分搜索：O(log n) 查询建立在有序、同一比较器之上

二分搜索检查中点，根据比较结果丢弃一半区间。n=100 最多约 7 次划分，n=10000 约 14 次，n=1000000 约 20 次；这是增长直觉，不是保证 API 恰好调用比较器这些次数。

前置条件极重要：输入必须按与搜索相同的自然顺序或 Comparator 排好。未排序输入调用 `Collections.binarySearch`，结果未定义；“这次恰好找到”也不合法。排序用优先级、搜索用 ID 是另一种前置错配。

binarySearch 返回非负索引表示命中；负值编码插入点 `-(insertionPoint)-1`，不能把所有负值只解释成 -1。若列表有多个比较为 0 的元素，命中哪个不保证；需要首/末边界要另行设计。

`Collections.binarySearch` 对 RandomAccess 列表提供 log(n) 比较模型；对大型非 RandomAccess 列表会使用基于迭代器的二分，仍有 O(log n) 元素比较但可能 O(n) 链接遍历。结构的访问成本与算法比较次数要分开。

## 10. 排序一次再查，何时值得

未排序 List 做 q 次线性查询，最坏比较量约 qn。先复制并排序的成本约 n log n，再做 q 次二分约 q log n，总模型 n log n + q log n。q 很小时，排序前置成本可能不值；q 增大或需要有序输出时，复用排序快照更合理。

若每次查询都重新复制+排序，成本变成 q·n log n，可能比线性更差。常见热点不是“排序慢”，而是排序放在错误生命周期：本可在数据版本变化时构建一次，却在每个请求循环里重建。

排序快照要处理更新。原 List 新增后，旧快照不再包含新项；需要版本号、所有权或明确重建时点。本章只讨论单线程内存结构，不设计缓存一致性。

若只按 ID 查值而不需要有序遍历，HashMap 的一次 O(n) 建索引 + 平均 O(1) 查询通常更直接。二分的优点是紧凑有序数组、无需哈希键；Map 的优点是查询与排序无关。它们是取舍，不是胜负排名。

## 11. List、Set、Map 的选择表

| 需求 | 推荐结构 | 典型成本模型 | 语义/空间代价 |
| --- | --- | --- | --- |
| 保留全部顺序与重复 | ArrayList | 尾加摊还 O(1)，查找 O(n) | 额外索引无 |
| 成员判断/去重 | HashSet | 良好散列下平均 O(1) | O(n) 哈希结构，不保顺序 |
| 去重且保首次顺序 | LinkedHashSet | 平均快速成员判断 | 多维护 encounter links |
| 键到值查询 | HashMap | 建 O(n)，平均查询 O(1) | O(n) 索引，键必须稳定 |
| 按键有序/范围 | TreeMap | O(log n) 查改 | 比较器合同、树节点空间 |
| 一次有序输出 | List 副本+sort | O(n log n) | O(n) 副本，原顺序保留 |

先保证数据语义：List 的重复可能是审计事实，Set 去重会丢出现次数；Map 每键一个值可能覆盖旧值；TreeSet compare=0 会形成同一等价类。复杂度优化不能默默改变结果。

API 暴露最小能力。方法只遍历可接收 `Iterable`，成员判断需要 Set，按键查询需要 Map。不要参数声明 List 后在内部每次 contains，并让调用者承担隐藏平方成本。

## 12. 用操作次数验证趋势，而不是用睡眠和秒表

教学 oracle 可以给比较函数加计数器。最坏线性搜索 n 个缺失值应比较 n 次；手写二分在固定无重复有序数组中比较次数不超过 `ceil(log2(n+1))` 一类上界；嵌套查重可精确数比较对。计数不受 CPU 调频和后台任务影响。

规模曲线至少取三个点，例如 100、10000、1000000。为了避免测试分配百万对象，可以对公式/模型与小型真实运行分层：真实代码用 128/1024 验证结果和计数，模型报告用 long 安全计算大规模上界。不能把只算公式冒充真实百万数据运行。

优化前后必须先证明业务结果相同：found/missing、重复报告、原始顺序和覆盖策略一致。只比较“新代码比较次数少”可能掩盖新代码丢重复。

操作计数也不是生产耗时。一次 String.equals 与一次 int compare 成本不同，缓存与分配也未计入。它是复杂度证据的一层，不是最终性能结论。

## 13. Java 基准测试常见误区

### 13.1 单次 nanoTime 不是基准

`System.nanoTime` 适合测量经过时间，但第一次运行包含类加载、JIT 编译等；一次差值会受调度、频率、GC 和后台负载影响。结果必须消费，否则 JIT 可能消除无用工作。不要在单元测试里断言“必须小于 5ms”。

### 13.2 预热、分叉与状态隔离

JVM 会根据热点优化代码。正式微基准需要预热与多次测量；同一进程先跑 A 再跑 B 可能让二者相互污染。不同 fork、参数化输入和状态 scope 必须明确。OpenJDK JMH 专门处理大量这类机制，应优先使用，而不是自制 for 循环秒表。

### 13.3 常量折叠和死代码消除

若输入是编译期常量、结果从不使用，编译器可能提前计算或移除。打印每次结果又把 I/O 变成主要成本。基准框架的参数和 Blackhole 等机制帮助保留真实工作，但仍需理解被测内容。

### 13.4 分配与 GC

每次查询重建 List/Map 会产生分配，GC 可能在某轮集中发生。只看平均耗时会隐藏尾延迟。记录分配率、吞吐与分位数，并用与生产相近的数据大小和 JVM 参数。

### 13.5 微基准不等于系统性能

一个 Map.get 的纳秒结果不能预测带数据库、网络、锁和序列化的 API。先用复杂度定位可疑增长，再用 profiler/指标确定热点，最后在恰当层级测量。不要优化没有证据的代码。

## 14. FactoryCare 场景：三种查询计划

有 n 张工单、q 次按 ID 查询。

方案 A：保留 List，每次线性扫描。空间最小，构建几乎免费；最坏操作 qn。适合 n/q 小、只查一次、要找 encounter order 第一项。

方案 B：按 ID 排序一个 ArrayList 快照，然后复用 binarySearch。构建约 n log n，查询 q log n，额外 O(n) 引用空间；适合还需要按 ID 有序输出且更新批次明确。

方案 C：建立 HashMap<WorkOrderId,WorkOrder>。构建 O(n)，良好散列下查询平均 O(1)，额外 O(n) 哈希结构；适合大量键查询，不提供排序输出。重复 ID 需要先定义拒绝/覆盖策略。

对 n=100、10000、1000000，模型报告同时列出线性最坏比较 n、二分对数级划分约 7/14/20、Map 构建条目 n 与查询的条件性常数模型。不要写“Map 查询永远 1 次 equals”，碰撞和实现会改变实际调用。

若工单持续更新，索引维护也有成本。List append 快、查询慢；Map put 同时更新索引；排序快照要重建或增量维护。本章不设计生产缓存或数据库索引。

## 15. 故障诊断手册

### 15.1 数据翻 10 倍，延迟近 100 倍

查嵌套循环与循环内 contains/indexOf。把调用成本展开，记录比较计数。若是去重/成员判断，用 Set；若需原始顺序，同时保留 List，不要直接替换丢数据。

### 15.2 二分搜索偶尔找不到存在元素

验证列表是否按同一 Comparator 排序，更新后是否仍有序，搜索 key 与元素比较方向是否一致。保留未排序反例；不要在失败时退回线性并隐藏索引失效。

### 15.3 优化后结果不一样

检查 Set 是否丢重复、Map 是否覆盖、排序是否改原列表、键 equals/hashCode 是否正确。先恢复等价 oracle，再谈性能。复杂度改进不授权语义改动。

### 15.4 HashMap 仍慢

检查键 hash 分布、equals 成本、容量、重建和是否每次查询都重新建 Map。不要把 Map 初始化算在 A 方案外却算在 B 方案内；比较生命周期必须一致。

### 15.5 基准每次结论相反

检查预热、fork、输入是否被优化、结果是否消费、GC、后台负载和样本数。使用 JMH；若只是教材 oracle，退回确定性操作计数，不声明墙钟胜负。

### 15.6 内存暴涨

列出同时存在的原 List、排序副本、Map、Set 和预计算键。确认生命周期结束后引用是否释放，是否为每请求重建百万条索引。用目标 JVM 工具实测，不凭对象个数猜精确 MB。

## 16. 测试与验证矩阵

功能：空、单项、首项命中、末项命中、缺失、重复、排序前后。复杂度：三个规模、最坏/最好位置、重复分布、操作计数趋势。结构：List 保序、Set 去重、Map 覆盖/缺失、二分有序前置。空间：记录新增容器数和生命周期。

故障测试要让错误稳定：未排序数组 `[9,1,7,3]` 二分查 9 可得到错误缺失；每查询重排用排序调用计数器；嵌套查重用全唯一输入达到最大比较对。不要依赖毫秒阈值触发。

测试结果应写“在固定 n 与输入分布下，操作计数符合模型”，不写“已经证明生产更快”。生产结论还需目标硬件、JVM、数据与系统级测量。

## 17. 与 TypeScript/JavaScript 对照

JS 数组 `find`/`includes` 是线性扫描；Set/Map 也用于成员与键查询。TypeScript 类型不会改变运行时复杂度。前端 computed 每次渲染都重新 sort/filter，类似 Java 每请求重复排序；缓存计算要处理依赖变化和失效。

JS object/Map 的键语义与 Java HashMap equals/hashCode 不同，不能直接搬操作模型；但“建立索引用 O(n) 空间换多次查询”是共同思想。浏览器基准同样有 JIT、GC、预热和计时噪声。

Vue 响应式源数组若原地 sort 会改变共享状态；Java List.sort 也会改变源。空间换所有权的决策可跨语言复用：复制保护输入，但增加 O(n) 引用和分配。

## 18. 练习、变更与关闭 AI

### 预测题

1. 两个先后循环各 n 次是 O(n) 还是 O(n²)？为什么？
2. n=1024 的二分最多需要多少次“减半”直觉？
3. q=1 时，为 List 建 Map 一定更好吗？要比较哪些成本？
4. Map 优化后唯一数变少，可能是优化还是语义变化？

### 动手题

实现计数版线性/二分搜索，在 128 个有序 ID 上验证首、末、缺失。生成 100/10000/1000000 的模型表，用 long 计算，不宣称真实运行百万对象。

### 故障题

在未排序数组上直接二分，保留错误结果；在每次查询前排序，记录 sortCalls=q；用 List.contains 做全唯一去重，验证比较数 n(n-1)/2。逐项修复并重跑结果等价 oracle。

### 需求变更题

系统变成 90% 写、10% 查，且必须保留全部重复事件。重新比较 List、Map 和双结构；明确更新两份结构的一致性成本，不因上一版“Map 更快”沿用结论。

### 关闭 AI 独立练习

限时 45 分钟完成公开 starter：消除嵌套查重和每查询重复排序，保留输入/重复报告，建立可复用索引；让操作计数曲线和结果 oracle 都通过。

## 19. 复述、间隔复习与速查

### 120 秒复述模板

“复杂度先定义 n，再看核心操作随 n 的增长，不是秒数。线性查找 O(n) 无排序前置；二分 O(log n) 但必须按同一 Comparator 有序，且 RandomAccess 与链式访问成本不同。排序一次约 n log n，可服务多次查询；每次重排会放大。Map 用 O(n) 额外空间和构建成本换良好散列下平均快速查询。摊还不是每次恒定。教学用操作计数验证趋势，生产基准要处理 JIT、预热、GC、fork，并优先用 JMH。”

### 复习计划

- 1 天后：不看表写出五种常见阶和一个真实例子。
- 3 天后：手算 n=100/10000/1000000 的线性与二分增长。
- 7 天后：从一段嵌套 contains 代码画调用成本并修复。
- 14 天后：对一个真实查询写时间、空间、更新、语义和测量五栏决策。

### 速查表

| 现象/需求 | 先问 | 常见方向 |
| --- | --- | --- |
| 数据放大后变慢 | n 与嵌套调用是什么 | 数操作、找高阶项 |
| 一次未排序查询 | 是否值得建索引 | 线性扫描可能最简单 |
| 多次有序查询 | 快照何时更新 | 排序一次+二分 |
| 多次键查询 | 顺序是否需要 | Map，写明空间/键合同 |
| 去重 | 重复事实是否需保留 | List+Set 双结构 |
| 尾部追加偶尔慢 | 是否发生扩容 | 摊还成本与尖峰 |
| 微基准摇摆 | 预热/fork/GC/消费结果 | JMH，不用单次 nanoTime |

## 20. 官方资料与当前性边界

以下为 Oracle Java SE 25 或 OpenJDK 官方一手资料，复核日期为 **2026-07-16**：

- [ArrayList](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/ArrayList.html)：随机访问、线性操作、尾加摊还成本与容量边界。
- [HashMap](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/HashMap.html)：良好散列前提下的基本操作成本、容量/负载因子、迭代成本。
- [TreeMap](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/TreeMap.html)：基本操作 O(log n) 与排序合同。
- [Collections.binarySearch](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Collections.html)：有序前置、负插入点、RandomAccess 与链式遍历成本。
- [List.sort](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/List.html)：稳定排序保证与 JDK 25 实现说明。
- [System](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/System.html)：`nanoTime` 的经过时间测量及差值用法边界。
- [OpenJDK JMH](https://openjdk.org/projects/code-tools/jmh/)：面向 JVM 语言的 nano/micro/milli/macro benchmark harness。

Big-O、输入规模和时间—空间取舍是稳定核心；具体容器内部阈值、对象字节数、JIT 优化与当前硬件耗时不是跨环境保证。当前局部验证只覆盖本机 macOS arm64 Java 25 和确定性操作计数；未执行 JMH 性能基准、profiler、其他系统/JDK 或生产规模百万对象实跑。
