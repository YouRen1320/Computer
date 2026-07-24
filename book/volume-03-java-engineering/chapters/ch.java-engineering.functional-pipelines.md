---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.functional-pipelines
title: Stream、Collector 与 Optional 边界
responsibility: 教授惰性数据管道和缺失值表达边界，不把 Stream 用于所有循环或副作用编排
volume: '03'
order: 8
level: L1
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.functional-pipelines.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-engineering.associative-collections
- ch.java-engineering.lambdas-functional-interfaces
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
  text: 在 120 秒内解释Stream、Collector 与 Optional 边界的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-stream
  - java-collector-optional
  covers_topics:
  - java.stream-lazy-pipeline
  - java.stream-map-filter-reduce
  - java.stream-side-effect
  - java.collector
  - java.optional-boundary
  - java.optional-anti-pattern
  uses_capabilities:
  - java.collections-generics
  - java.inheritance-polymorphism
  - java.methods
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 把工单列表经 filter→map→groupingBy/reduce 生成类别汇总，并用 Optional 显式表达可能缺失的最大值
  covers_topic_groups:
  - java-stream
  - java-collector-optional
  covers_topics:
  - java.stream-lazy-pipeline
  - java.stream-map-filter-reduce
  - java.stream-side-effect
  - java.collector
  - java.optional-boundary
  - java.optional-anti-pattern
  uses_capabilities:
  - java.collections-generics
  - java.inheritance-polymorphism
  - java.methods
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入 Stream 重复消费、peek 修改状态和 Optional.get 空值，依据异常/重复结果改为无副作用管道
  covers_topic_groups:
  - java-stream
  - java-collector-optional
  covers_topics:
  - java.stream-lazy-pipeline
  - java.stream-map-filter-reduce
  - java.stream-side-effect
  - java.collector
  - java.optional-boundary
  - java.optional-anti-pattern
  uses_capabilities:
  - java.collections-generics
  - java.inheritance-polymorphism
  - java.methods
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Stream、Collector 与 Optional 边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Set、Map、键相等性与哈希契约》](ch.java-engineering.associative-collections.md)：独立完成Stream 管道、收集与缺失值前，必须先具备「Set、Map、键相等性与哈希契约」已经验证的知识与失败边界
- [《Lambda、函数式接口与方法引用》](ch.java-engineering.lambdas-functional-interfaces.md)：独立完成Stream 管道、收集与缺失值前，必须先具备「Lambda、函数式接口与方法引用」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。固定 Java 25 oracle 证明的是当前示例在空、单项和多项输入上的合同，以及故障夹具可重放；它没有完成 P9 零基础试读、人工版式/无障碍检查、独立全面审查或全书回归，不能据此晋升为 `verified`，也不会修改 `PROGRESS.md`。

把一个列表写成 `stream().filter(...).map(...).toList()` 很容易，真正困难的是解释它何时执行、哪些操作可能被省略、数据能否保持 encounter order、为什么同一个 Stream 不能再次消费、Collector 怎样在拆分后仍得到相同结果，以及空结果到底应返回空集合、0、异常还是 Optional。若这些边界没有合同，短代码只会把错误压缩到一行。

本章用 FactoryCare 工单汇总建立惰性数据管道模型，覆盖 `filter`、`map`、`flatMap`、`reduce`、`collect`、`groupingBy`、`toMap`、Collector 的 supplier/accumulator/combiner/finisher、无副作用要求、单次消费、Optional 返回边界、`orElse` 与 `orElseGet`、并行误区和调试。每个 Stream 实现都与一份普通循环 oracle 比较；不把 Stream 用于所有循环，不用它编排数据库写入、通知或重试。版本基线为 **JDK 25**，官方资料复核日期为 **2026-07-16**。

## 1. 完成定义与证据

1. 在 120 秒内画出 source → intermediate operations → terminal operation，并解释惰性、单次消费、non-interference 和 stateless behavior。
2. 用 `filter → map → collect/reduce` 生成开放工单 ID、类别计数、预计工时合计与最高优先级，空、单项、多项结果和循环基准完全一致。
3. 用 `groupingBy` 得到稳定可手算的类别汇总，说明 Map 类型、键顺序、下游 Collector 与重复键策略。
4. 让最大优先级在空输入上返回 `OptionalInt.empty()`，调用方不用 `get` 或 `getAsInt` 猜测存在性。
5. 重放 Stream 重复消费、`peek` 隐藏写入、空 Optional 强取值、非结合归约四类故障，并用异常或稳定证据码定位。
6. 说明为什么 `parallelStream()` 不是性能按钮，列出正确性、规模、拆分、合并、顺序、副作用与基准测试证据门槛。

配套工件：

- [惰性管道示例](../../../examples/encyclopedia/ch.java-engineering.functional-pipelines/README.md)
- [FactoryCare 汇总合同实验](../../../labs/encyclopedia/ch.java-engineering.functional-pipelines/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.functional-pipelines/README.md)

公开 starter 的失败是练习起点。先写空/单项/多项的手算表，再运行；不要通过删除空输入或改 expected 来制造绿灯。

## 2. Stream 不是集合，而是一条一次性的计算描述

`List<WorkOrder>` 保存元素并可在合同允许时多次遍历。`Stream<WorkOrder>` 代表从某个 source 出发的一系列聚合操作，它不拥有一份可随意重复读取的数据副本。Stream 管道通常包括一个源、零个或多个中间操作、一个终止操作。中间操作返回新的 Stream 描述，终止操作才产生非 Stream 结果或边界动作。

```java
List<String> ids = orders.stream()
        .filter(WorkOrder::open)
        .map(WorkOrder::id)
        .toList();
```

这里 `orders` 是 source，`filter` 和 `map` 是中间操作，`toList` 是终止操作。`filter` 不会先造一个完整过滤列表再交给 map；实现可以按元素穿过多个阶段，并利用短路、融合或其他优化。程序应依赖 API 的语义结果，而不是假定每个 Lambda 恰好调用一次、按某个内部循环逐阶段执行。

Stream 更像“一张只能执行一次的查询计划”，但这个类比也有边界：它不是数据库查询语言，没有持久化事务、远程优化器或实体跟踪。source 可以是内存集合、数组、生成器或 I/O 资源；是否需要关闭、是否有 encounter order、是否可高效拆分都取决于来源和操作。

不要把 Stream 字段长期存储以便稍后反复使用。保存可重复创建 Stream 的集合，或保存 `Supplier<Stream<T>>` 并明确每次产生新管道，通常更符合生命周期。若源是文件等 I/O 资源，创建和关闭必须处于同一清楚边界，不能把依赖已关闭资源的 Stream 返回给外层。

## 3. 惰性：没有终止操作，就没有完整计算承诺

中间操作是惰性的。创建 `orders.stream().filter(rule).map(mapper)` 只组装管道；没有终止操作时，不应期待 rule 和 mapper 已经运行。配套示例用计数器证明：构建管道后计数仍为 0，调用 `toList` 后才与实际经过 filter 的元素数一致。

惰性使短路成为可能。`findFirst` 找到第一个满足项后可停止；`anyMatch` 得到 true 后无需检查剩余元素；`limit(3)` 可能只请求足够的上游元素。于是行为参数不能依赖“所有元素都会被访问”。把审计写在 filter、map 或 peek 中，会因短路、优化或未来的管道修改而漏记。

API 还允许实现消除不影响结果的阶段。尤其 `count()` 在能从 source 大小直接得出结果时，某些中间阶段的副作用不保证发生。`peek` 文档定位于调试观察，不是可靠的业务动作通道。若每张工单都必须发通知，先用 Stream 纯计算出通知命令集合，再在明确循环或边界服务中逐项执行并记录结果。

调试惰性问题时问三个问题：终止操作在哪里？它是否短路？我观察的行为属于结果合同，还是仅仅碰巧发生的 Lambda 调用？把“断点没进”立即解释成数据为空可能误判，终止操作缺失或优化也能导致相同表象。

## 4. 单次消费：一个 Stream 实例只有一条生命周期

对一个 Stream 调用终止操作后，再对同一实例调用另一个终止操作通常会抛 `IllegalStateException`，消息常见为“stream has already been operated upon or closed”。不要依赖完整消息；异常类型和自己的上下文才是稳定证据。中间操作也可能让原引用进入已被链接的状态，因此保留多条对同一实例的变量引用同样危险。

```java
Stream<WorkOrder> open = orders.stream().filter(WorkOrder::open);
long count = open.count();
// open.toList(); // 已经消费，合同错误
```

若同时需要 count 和列表，有三种常见选择：先收集一次再从结果取 size；使用一个 Collector 同时累计需要的信息；或从可重复 source 创建两条独立 Stream。怎样选取决于数据量、内存和结果需求。不能通过捕获异常后偷偷重建来掩盖不清楚的所有权。

集合产生的 Stream 通常不需要显式关闭，但 I/O backed Stream 需要。`Files.lines` 等返回的 Stream 应在 try-with-resources 中消费完毕。Stream 实现 `AutoCloseable` 不等于所有 Stream 都必须手写 close；要看 source 是否持有资源。资源所有权将在专门 I/O 章节深入，本章只固定“创建者必须知道谁关闭”的边界。

## 5. filter、map、flatMap：选择、转换与展平是三种责任

`filter(Predicate<T>)` 保留使谓词为 true 的元素，元素类型不变。谓词应不干扰 source，通常也应无状态。过滤 null 是一项显式策略；如果领域列表合同不允许 null，更好的做法可能是在入口拒绝，而不是每条管道都悄悄 `filter(Objects::nonNull)`。

`map(Function<T,R>)` 为每个经过的元素产生一个结果，可能改变类型。工单映射为 ID、priority 或不可变汇总行都很自然。map 不应同时修改原工单；否则读者看到“映射”却得到源数据变化，后续重复计算也不稳定。

`flatMap` 用于一个输入产生零到多个输出，再把嵌套结果展平。例如每张工单有多个标签，`map(WorkOrder::tags)` 得到 `Stream<List<String>>`，`flatMap(order -> order.tags().stream())` 才得到标签流。不要用 flatMap 只是为了显得函数式；当一对一映射足够时 map 更清楚。

管道顺序会影响语义和成本。若先 filter 掉关闭工单，再做昂贵映射，就不会计算被淘汰项；若映射本身决定过滤字段，顺序可能不能交换。优化前必须证明等价。本章用调用计数仅做确定性教学，不把次数直接当生产性能结论。

## 6. reduce：从多个元素合成一个值，关键是单位元与结合性

归约把元素反复组合成一个结果。求工时总和可以 `mapToInt(WorkOrder::minutes).sum()`，也可以用带 identity 的 reduce。最高优先级没有自然的空输入结果，使用无 identity 的 `max` 或 reduce 会返回 Optional 形态，迫使调用方处理缺失。

带 identity 的归约要求 identity 是单位元：与任何部分结果组合不改变它。加法的 0、乘法的 1、字符串拼接的空串是常见候选，但仍要考虑溢出、顺序和业务含义。combiner 还应满足结合性，使 `(a op b) op c` 与 `a op (b op c)` 等价；并行分区会改变分组方式。

减法不是结合运算。对 10、3、2，左分组得到 5，另一分组得到 9。顺序流按某种 encounter order 看起来“能用”不代表可以安全并行，也不代表自定义 Collector 合法。配套故障夹具直接计算两种分组并抛出 `NON_ASSOCIATIVE_REDUCER`，用确定性代数反例说明问题，不依赖线程调度。

可变容器通常用 collect 而不是 reduce。用 reduce 不断复制 List 会产生不必要分配；用同一个可变 List 同时作为 identity 和 accumulator 又会破坏隔离与并行合同。选择 API 时先区分“合成不可变值”与“向可变结果容器累计”。

## 7. Collector 模型：供应、累计、合并、收尾

Collector 描述一次可变归约，核心是四个函数：supplier 创建新的结果容器；accumulator 把一个输入折入容器；combiner 合并两个部分容器；finisher 可把累计类型转换成最终结果。`Collector<T,A,R>` 中 T 是输入元素，A 是中间累计容器，R 是最终结果。

顺序执行可以只创建一个容器并逐项 accumulator；并行执行会为分区创建多个容器，随后 combiner。正因为执行可能拆分，Collector 必须满足 identity 与 associativity 约束。combiner 不能假定“右容器永远为空”，supplier 不能返回共享单例可变集合，accumulator 不能把容器泄漏给无关代码。

`Collectors.toList()`、`toSet()`、`joining()`、`counting()`、`summingInt()`、`groupingBy()` 和 `toMap()` 覆盖大量场景。JDK 25 的 `Stream.toList()` 返回不可修改 List，而 Collector 工厂对具体实现类型和可变性的承诺应按各自文档读取。不要因为当前看到 ArrayList/HashMap 就把实现类型写入业务合同。

自定义 Collector 是高级边界，不应为了少写两行循环就创建。先考虑标准 Collector 的下游组合，如 `groupingBy(WorkOrder::category, summingInt(WorkOrder::minutes))`。确需自定义时，分别测试空输入、单项、多个分区的手工合并、顺序/并行等价和 characteristics；只测顺序快乐路径不足以证明 combiner 正确。

## 8. groupingBy 与 toMap：键合同、顺序和冲突策略必须显式

`groupingBy(classifier)` 按键把元素分组，默认结果 Map 的具体类型和迭代顺序不应被业务依赖。若报告要求类别按首次出现顺序，使用带 Map supplier 的重载，例如 `LinkedHashMap::new`；若 UI 会自行按明确字段排序，也可在边界排序。不要用“我的机器输出刚好稳定”替代合同。

下游 Collector 决定每个键的值。默认得到 List；类别计数用 `counting()`，工时用 `summingInt()`，每组最高优先级可用 `maxBy()`，复杂汇总可以 `teeing` 或先构造明确 accumulator。一个巨大嵌套 Collector 虽可能一遍完成，却可能难以调试；命名 classifier、downstream 和结果类型会更清楚。

`toMap(keyMapper, valueMapper)` 遇到重复键时默认抛异常。工单 ID 若合同保证唯一，这个失败能暴露脏数据；若输入是事件历史，同一 ID 合法重复，就必须提供 merge function 并说明保留第一条、最后一条还是按版本合并。随手写 `(left, right) -> right` 会把数据丢弃策略藏起来。

merge function 同样要考虑结合性，尤其未来并行时。保留最高版本可以用可手算且确定的比较；“谁最后到就用谁”在无 encounter order 或并行组合中可能模糊。数据合同优先于 Collector 技巧。

## 9. Optional：表达可能缺失的返回值，不是万能空值容器

`Optional<T>` 表示一个非 null 值存在或不存在。Java SE 25 API 明确将它主要定位为方法返回类型：当没有结果需要显式表达，而返回 null 容易被误用时使用。查询“开放工单中最高优先级”在空列表上没有值，`OptionalInt` 或 `Optional<WorkOrder>` 能让调用方看到分支。

Optional 变量自身不应为 null。`null` Optional 制造了两层缺失状态，完全破坏目的。`Optional.of(value)` 要求 value 非 null；`ofNullable(value)` 把 null 转为空；`empty()` 明确构造空。不要先写 `of` 再靠捕获空指针处理缺失。

调用方优先使用能表达意图的操作：`map` 转换存在值，`flatMap` 避免嵌套 Optional，`filter` 保留满足条件的存在值，`orElseThrow` 在合同要求必须存在时抛领域异常，`orElse` 或 `orElseGet` 提供默认值，`ifPresentOrElse` 处理两个动作边界。直接 `get()` 或基本类型的 `getAsInt()` 只有在存在性已由同一局部控制流证明且更清楚时才考虑；业务代码中无条件强取通常是故障。

空集合与 Optional 集合表达不同问题。查询“满足条件的所有工单”没有结果时通常返回空 List，而不是 `Optional<List<WorkOrder>>`；列表已经能表达零项。查询“唯一的最高优先工单”才有存在/缺失分支。一个返回类型同时要求调用者先拆 Optional 再遍历集合，往往增加无价值层次。

## 10. orElse 与 orElseGet：默认值是否惰性是可观察合同

`optional.orElse(fallback())` 会在调用 orElse 前先求值方法实参，所以即使 Optional 有值，`fallback()` 也已执行。`orElseGet(this::fallback)` 接收 Supplier，仅在缺失时调用。若 fallback 只是常量，两者语义容易；若它会查数据库、生成 ID、记录日志或抛异常，差异非常重要。

配套故障通过一个会抛 `EAGER_FALLBACK` 的默认方法证明：`Optional.of("known").orElse(failingFallback())` 仍会进入 fallback。修复为 `orElseGet` 只解决“仅缺失时求值”，不自动让副作用合理；仍需问 fallback 是否应发生在这个层次。

Optional 也不是异常替代品。缺失是预期分支，例如按可选筛选条件找不到最大值；数据库不可用、输入格式损坏是失败，应通过异常或结果类型表达，不要统统变成 empty 丢失原因。反过来，查无数据若是正常现象，也不必用异常制造控制流。

将 Optional 大量用于实体字段、DTO 参数或序列化模型通常会增加框架兼容与语义负担，这是工程判断而非一条 JLS 禁令。边界对象应按其协议明确 nullable、必填或缺省；领域方法返回值再用 Optional 表达“可能不存在”往往更清楚。本章只把它固定为查询返回边界，不规定所有项目层的统一序列化政策。

## 11. 无干扰与无状态：管道正确性的核心不是“看起来函数式”

Stream 文档要求行为参数不干扰数据源，并在多数情况下保持无状态。non-interfering 意味着执行管道期间不修改 source；stateless 意味着结果不依赖会在处理元素之间变化的状态。对同一个 ArrayList 一边 stream 一边 add/remove，可能抛并发修改异常，也可能产生未定义于业务合同的结果。

有状态去重的错误写法常捕获外部 `HashSet`，在 filter 中 `seen.add(key)`。顺序场景可能“能用”，但行为依赖先前元素，重复执行会继承旧状态，并行时还存在竞争。若要按 key 去重，先澄清保留哪一条，再用 Map merge、分组或明确循环表达。没有标准 `distinctByKey` 并不意味着外部 Set hack 就正确。

map 中修改元素、peek 中写审计、forEach 中向共享 ArrayList 添加，都是需要警惕的副作用。`forEach` 是终止操作且允许动作，但并行时顺序和共享容器安全仍要显式处理；若最终目标就是边界动作，普通循环往往更便于失败恢复、重试和逐项日志。

不可变 record 能降低干扰风险，却不能保证 Lambda 无状态；它仍可能读取当前时间或写全局计数。测试要覆盖重复执行与 source 未变化，而不是只比较一次最终值。

## 12. encounter order、排序与 forEachOrdered

某些 source 有 encounter order，例如 List；HashSet 通常没有业务可依赖的顺序。中间操作可能保留、改变或移除有序性，终止操作也有自己的顺序合同。`toList` 对有序管道按 encounter order 产生结果；`forEach` 在并行管道不保证 encounter order，`forEachOrdered` 保序但可能牺牲并行收益。

如果报告顺序是业务需求，应在管道中显式 `sorted` 或选择有序数据结构并在测试里断言完整序列。不能只断言集合元素相同，因为页面或导出文件会感知顺序。若顺序无关，测试也不应无意固定 HashMap 的当前迭代结果。

`unordered()` 不是“随机化”，而是允许实现忽略 encounter-order 约束；只有业务结果确实无序时才可调用。为了追求并行性能移除顺序，需要先确认消费者不依赖它，并有回归测试证明。

## 13. 并行 Stream：先证明可分、可合、值得，再谈更快

`parallelStream()` 或 `parallel()` 选择并行执行模式，但不保证更快，也不为行为参数修复线程安全。收益取决于输入规模、每元素计算成本、source 的拆分能力、合并成本、可用处理器、公共 ForkJoinPool 竞争、装箱、缓存局部性与顺序约束。小集合或廉价操作常被调度与合并开销吞掉。

正确性门槛先于性能：行为必须 non-interfering、通常 stateless；reduce/Collector 的 identity 与 associativity 必须成立；共享副作用要移除或通过合适 Collector 隔离；结果顺序合同要明确。若这些证明做不到，顺序流慢一点也比并行错误好。

阻塞 I/O 放进并行 Stream 是高风险默认：公共池线程可能被占满，超时、取消、背压和每项错误也难以编排。异步 I/O、虚拟线程或结构化并发有各自适用模型，不能仅因语法短就塞入 parallelStream。本章不教授并发实现，只要求识别错误边界。

性能结论必须来自代表性数据和 JMH 等可靠基准设计，包含预热、多个 fork、结果消费、规模分层和环境说明。一次 `System.nanoTime`、运行顺序固定的 A/B 对比或“CPU 看起来很忙”都不能证明收益。局部实验故意不测墙钟时间，只用代数反例和结果 oracle 验证合同。

## 14. 循环还是 Stream：按意图、控制流与失败边界选择

Stream 适合从一个数据源进行声明式选择、转换、聚合，尤其每个阶段可命名且无副作用时。普通循环适合复杂控制流、多个可变累积结果、逐项失败恢复、需要下标、早退逻辑难以用短路表达，或团队更容易维护的场景。二者都能写出好代码或坏代码。

“没有循环”不是质量指标。一个五层 `groupingBy(mapping(filtering(...)))` 可能比十行循环难读；反过来，三个嵌套循环与散落临时变量也可能比清楚管道差。主流实践是让数据变换的意图直接可见，并把副作用和错误处理放在明确边界。

本章保留循环 oracle 不是鼓励重复生产实现，而是教学与重构保护：先用最直白算法写出 expected，再验证 Stream 版空/单/多输入完全一致。生产代码最终可只保留一份实现和参数化测试，但迁移时的双实现对照能发现遗漏的顺序、重复键和缺失值语义。

## 15. 调试惰性管道：把一行链恢复成可观察阶段

当结果错误时，先固定最小输入和 expected，不要立即给每一步塞 println。把复杂 Lambda 提取成命名 Predicate/Function，单独测试；检查终止操作和短路；确认 source 是否被改、Stream 是否重复消费、Optional 是否为空。必要时临时将某个阶段收集成不可变列表作诊断检查点，修复后再评估是否保留。

`peek` 可以临时观察元素，但不要让测试依赖它一定执行。日志若用于诊断，应带阶段名、稳定 ID 和受控数据量；生产中对大流逐元素日志会改变性能和噪声。并行问题先切回 sequential 获得可重复最小反例，再验证运算结合性和共享状态，不能把“顺序就好了”当最终修复。

异常堆栈里会出现 Stream 内部帧和 Lambda 合成名称。先找最早业务帧、输入 ID 与根异常；给关键映射提取方法能让堆栈更可读。不要 catch 所有 RuntimeException 后返回 empty Optional，这会把真实失败伪装成合法缺失。

故障测试应在独立进程运行：重复消费必须抛异常；空 Optional 的 `get` 必须失败；peek 写入因无终止操作必须被检测为未执行；非结合 reducer 必须展示两种分组不同。脚本检查稳定证据而非整段本地化消息。

## 16. 测试矩阵：空、单项、多项、顺序、重复与非法

空输入验证：过滤/映射结果为空列表；计数和总和为 0；分组为空 Map；最大值是 empty Optional；fallback 只在选择的缺失分支执行。单项输入验证 identity、标签和唯一最大值，能抓出错误初始值。多项输入验证过滤、分组、归约、稳定顺序与重复键策略。

来源输入还应包含关闭工单、两个类别、相同 priority、重复类别与手算分钟数。每个 Stream 结果与循环 oracle 比较，source 列表在前后保持相等。对于 Map，若顺序属于合同就比较 entry 顺序；若不属于合同只比较键值，不把当前实现偶然顺序写入测试。

Optional 测试至少覆盖 present 和 empty；`orElseGet` 用调用计数证明 present 时 Supplier 不执行、empty 时恰好执行一次。并行相关测试优先验证顺序/并行结果等价和代数性质，不在普通单元测试里断言某个线程名、完成顺序或毫秒阈值。

## 17. FactoryCare 汇总切片：从开放工单到类别报告

实验数据有六张工单，类别为机械、电气与网络，包含开放/关闭、相同优先级和可手算 minutes。循环 oracle 一次遍历得到开放工单 ID、按首次遇见顺序的类别工时、总工时和最大优先级；Stream 版分别使用 filter/map/toList、groupingBy + summingInt、mapToInt + sum、max。

运行前先手算：空列表报告应是空 ID、空 Map、总工时 0、无最大值；单项开放工单各结果就是自身；多项只排除关闭项，类别键顺序由 `LinkedHashMap` supplier 固定。所有案例比较结构值，不比较 `Map.toString` 的偶然格式作为唯一证明。

然后重放四个故障。重复消费暴露生命周期；peek 隐藏审计暴露惰性；Optional.get 暴露缺失分支；非结合减法暴露并行归约前提。修复后再运行 22 个断言，输出精简报告和故障计数。

实验刻意不访问数据库、不发送通知、不用 parallelStream 测耗时。这样局部验证离线、确定，并把本章责任限制在数据管道与缺失值边界。

## 18. 与 TypeScript/Vue 的类比，以及类比失效处

JavaScript/TypeScript 数组的 `filter`、`map`、`reduce` 形状与 Java Stream 相似，Vue 中也常由原始响应式数组计算派生列表。可以借它理解“选择 → 转换 → 聚合”和副作用应离开计算属性。TypeScript 的 `undefined`、联合类型与可选链可帮助理解缺失分支。

关键差异是 JS Array 方法通常立即遍历并产生数组，而 Java Stream 中间操作惰性、Stream 单次消费。Java Optional 是具体值对象，不是 TypeScript 的 `T | undefined` 语法；Java 的基本类型 Stream/Optional 特化、Collector 分区合并和 parallel mode 也没有直接相同的前端模型。

Vue computed 有响应式缓存和依赖追踪，Java Stream 没有。source 列表变化不会自动让已经消费的结果更新；要重新创建并执行管道。Java Stream 也不是 RxJS/Reactive Streams：没有订阅协议、背压或异步事件序列。看到链式 API 不能把运行模型混为一谈。

## 19. 常见错误与修复规则

- 错误：构建 Stream 后期待 filter 已运行。修复：找到终止操作，说明短路和惰性。
- 错误：保存同一 Stream 做 count 再 toList。修复：一次收集、一次 Collector，或从 source 创建两条流。
- 错误：在 peek 中发通知。修复：纯管道产生命令，边界显式执行。
- 错误：空结果直接 Optional.get。修复：按合同 map/orElseGet/orElseThrow，测试 present 与 empty。
- 错误：查询多项也返回 Optional<List<T>>。修复：通常返回空 List，让 Optional 留给单值缺失。
- 错误：toMap 重复键随手保留右值。修复：先定义数据合同和 merge 语义。
- 错误：默认 Map 迭代结果当报告顺序。修复：提供 Map supplier、显式排序或声明无序。
- 错误：parallelStream 当性能开关。修复：先证明正确性与可拆合，再用可靠基准测代表规模。
- 错误：为了“函数式”把清楚循环改成嵌套 Collector。修复：以可维护意图和失败边界为选择标准。
- 错误：catch 全部异常后返回 Optional.empty。修复：区分合法缺失与系统失败，保留根因。

## 20. 独立练习、预测与讲回

公开练习要求实现开放工单 ID、按类别累计 minutes、总 minutes、最高 priority Optional 和惰性 fallback。先对空、单项、四项混合输入写 expected；再完成 TODO。starter 会以 `PIPELINE_CONTRACT` 失败。修复后不得修改输入列表，也不得用无条件 get。

完成后把一次 `peek` 审计写入管道但不加终止操作，预测记录器内容并运行故障夹具。再把减法 reducer 的两种括号分组手算出来，解释为何顺序运行的一次结果不能证明可并行。最后用 120 秒讲回：Stream 与集合区别、惰性、单次消费、Collector 四函数、Optional 边界和并行证据门槛。

复习五问：

1. `map` 后没有终止操作，mapper 是否必须运行？
2. 同时需要列表和数量时，为什么不能复用已消费 Stream？
3. `groupingBy` 的 key 顺序由什么决定，什么时候必须提供 Map supplier？
4. present Optional 调用 `orElse(expensive())` 时 expensive 是否执行？
5. 一个 reducer 在顺序输入上输出正确，还缺哪些证据才能并行？

## 21. 本章边界与下一步

本章完成的是内存数据的惰性选择、转换、归约与缺失值表达。它不负责数据库 `ORDER BY/GROUP BY`、响应式流、异步任务、并发结构、事务副作用、重试、I/O 资源所有权或生产性能调优。Stream 不是替换所有 for 循环的目标，Optional 也不是替换所有 null、空集合和异常的统一容器。

能独立通过本章实验后，应能拿一段 Stream 链画出每个类型、终止位置、顺序和缺失分支，能把它暂时改写成循环核对语义，并能从异常证据定位重复消费与强取空值。后续 I/O 章节会进一步讨论资源-backed Stream 的关闭所有权；并发章节再系统处理线程与虚拟线程。

## 官方资料

- [Java SE 25：Stream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/stream/Stream.html)
- [Java SE 25：Collector](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/stream/Collector.html)
- [Java SE 25：Collectors](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/stream/Collectors.html)
- [Java SE 25：Optional](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Optional.html)
- [Java SE 25：OptionalInt](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/OptionalInt.html)
- [OpenJDK：JMH](https://openjdk.org/projects/code-tools/jmh/)
