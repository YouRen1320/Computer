# Week 05 概念讲义

## 1. 从命令步骤到数据流

命令式循环通常描述“怎么做”：

    创建结果
    遍历工单
    如果未关闭且属于设备，则加入结果
    对结果排序
    返回结果

Stream 倾向描述“数据经过什么变换”：

    工单流
      → 过滤未关闭
      → 过滤设备
      → 按优先级和创建时间排序
      → 映射为只读行
      → 收集为列表

两者都可能清楚，也都可能写坏。核心不是语法长短，而是业务规则是否可见。

## 2. 函数式接口与 Lambda

### 2.1 什么是函数式接口

函数式接口只有一个抽象方法，因此 Lambda 可以提供该方法的实现。default、static 和与 Object 等价的方法不计入抽象方法数量。@FunctionalInterface 让编译器帮助维护这个约束。

常用接口：

| 接口 | 输入 | 输出 | FactoryCare 示例 |
| --- | --- | --- | --- |
| Predicate<T> | T | boolean | 工单是否未关闭 |
| Function<T,R> | T | R | WorkOrder 转 DashboardRow |
| Consumer<T> | T | 无返回 | 输出调试信息；业务副作用要慎用 |
| Supplier<T> | 无输入 | T | 延迟创建后备值 |
| UnaryOperator<T> | T | T | 标准化一个值 |
| BinaryOperator<T> | T,T | T | 合并两个同类型统计结果 |

Java 的 void 不等于 TypeScript 的 undefined。Consumer 表达无返回行为；Function 必须产生结果。

### 2.2 类型推断

Lambda 的参数类型由目标类型决定：

    Predicate<WorkOrder> open = order -> !order.isClosed();

同一个 Lambda 文本离开目标类型可能无法独立确定类型。TS 的上下文类型推断可类比，但 Java 重载、泛型和基本类型装箱会产生不同约束。

### 2.3 捕获与 effectively final

Lambda 可以读取局部变量，但该变量必须在赋值后不再改变：

    int threshold = 3;
    Predicate<DeviceStats> frequent =
        stats -> stats.failures() >= threshold;

这不是说引用指向的对象一定不可变。一个 effectively final 的 List 仍可被修改。捕获可变对象并在并发或 Stream 中写入，仍会制造副作用和竞态。

Java Lambda 中的 this 指向外部实例；匿名类中的 this 指向匿名类实例。面试只需解释行为差异，不背字节码实现。

### 2.4 方法引用

常见四种形式：

- 静态方法：Type::staticMethod；
- 某个对象的实例方法：instance::method；
- 任意该类型对象的实例方法：Type::method；
- 构造器：Type::new。

仅在读者能立刻看出参数流时使用。复杂转换写成命名方法往往比连续方法引用更清晰。

## 3. Stream 的执行模型

### 3.1 Stream 不是集合

Stream：

- 不持有业务数据；
- 表示一次计算管道；
- 通常只能消费一次；
- 终止操作触发执行；
- 中间操作通常是惰性的。

把 Stream 存成字段或跨方法长期传递通常会模糊生命周期。领域和 DTO 应返回集合或明确结果，而不是一次性管道。

### 3.2 中间与终止操作

中间操作返回新 Stream，例如 filter、map、flatMap、sorted。终止操作产生非 Stream 结果或副作用，例如 toList、count、reduce、forEach。

    orders.stream()                  // Stream<WorkOrder>
        .filter(WorkOrder::isOpen)   // Stream<WorkOrder>
        .map(WorkOrder::equipmentId) // Stream<EquipmentId>
        .distinct()                  // Stream<EquipmentId>
        .toList();                   // List<EquipmentId>

每写一步，都应能标注元素类型。

### 3.3 惰性与融合

建立管道时 filter/map 不一定立即遍历。终止操作出现后，运行时通常按元素穿过多个操作，而不是先生成每一步完整中间集合。但“发起终止操作”不保证每个中间函数一定被调用：如果实现能证明某阶段不影响终止结果，就可以消除该阶段。例如已知大小的集合执行 `map(...).count()` 时，`map` 可能完全不运行。行为参数必须无干扰、尽量无状态，不能依赖其中的副作用。

这能解释短路：

    orders.stream()
        .filter(WorkOrder::isOpen)
        .anyMatch(order -> order.priority() == CRITICAL);

找到第一个匹配后可停止。若先 toList 再 anyMatch，就失去这次短路机会。

### 3.4 有状态操作

sorted 和 distinct 往往需要观察更多元素，不能简单按一个元素立即完成。limit 与有序性也影响行为。不要把所有中间操作都想象成零成本。

## 4. 核心操作

### 4.1 filter 与 map

filter 决定保留哪个元素，类型通常不变；map 将一个元素变成一个新元素，数量通常一对一。

错误味道：用 map 修改原对象并返回它。若目标是变换，应创建新值；若目标是命令副作用，Stream 往往不是最佳表达。

### 4.2 flatMap

flatMap 把“每个元素产生一个容器/流”铺平：

    List<WorkOrder> orders
      → map: Stream<List<PartUsage>>
      → flatMap: Stream<PartUsage>

TS 中 Array.flatMap 可类比。失效处包括 Java 泛型、Stream 一次性消费以及 Optional.flatMap 的不同容器类型。

### 4.3 distinct

distinct 依赖 equals/hashCode。Week 03 的相等性错误会直接影响这里。若实体相等性不正确，用 distinct 可能静默丢数据或保留重复。

### 4.4 sorted 与稳定规则

排序要显式定义主键和 tie-breaker：

    Comparator.comparing(WorkOrder::priority)
        .thenComparing(WorkOrder::createdAt)
        .thenComparing(WorkOrder::id);

最后的唯一键能让结果在并列时稳定。注意 enum 自然顺序依赖声明顺序；业务优先级顺序最好显式比较。

### 4.5 limit 与 skip

必须先定义排序再谈稳定分页。内存 skip/limit 只用于本周实验；数据库分页在后续阶段实现。先过滤、排序、再 skip/limit 是常见语义，但需由需求确认。

## 5. 聚合与 Collector

### 5.1 count、reduce 和统计

reduce 需要理解单位元、结合性和类型。求和优先考虑 mapToInt.sum 或 summarizingInt，而不是写难读的 reduce。

错误单位元会破坏结果。例如最大值没有通用的 0 单位元，因为数据可能全为负；此类聚合自然返回 Optional。

### 5.2 toList

Stream.toList 返回的列表不保证可修改，不应假设能 add。若业务需要特定可变集合，显式使用合适 collector 或拷贝，并说明原因。

### 5.3 toMap

没有重复 key 语义时，toMap 遇到重复会抛异常。这通常是好事，因为它暴露了错误假设。若业务允许重复，必须显式定义 merge function：

- 保留最早；
- 保留最新；
- 合并计数；
- 收集成列表。

不要随手写 (a, b) -> a 掩盖数据质量问题。

### 5.4 groupingBy 与 partitioningBy

groupingBy 按 key 分成多组；partitioningBy 只分 true/false 两组。下游 collector 可以 count、map 或求和。

两层 grouping 加多层 collectingAndThen 很快变难读。可以拆成命名方法或中间 record，或者直接使用循环。

### 5.5 空集合与分母为零

count 返回 0，但 average、max、min 可能返回 Optional。状态占比的总数为 0 时，必须定义结果：

- 返回空映射；
- 返回各状态 0；
- 或返回 NoData 类型。

不要让除零、NaN 或空 Optional 悄悄穿过边界。

## 6. 副作用、调试与性能

### 6.1 什么是可见副作用

- 修改外部 List/Map；
- 修改 WorkOrder 实体；
- 写文件、发消息、记录数据库；
- 依赖处理顺序更新累计状态。

中间操作尽量纯。下面是错误用法：

    List<Row> rows = new ArrayList<>();
    orders.stream()
        .filter(WorkOrder::isOpen)
        .map(order -> {
            rows.add(toRow(order));
            return order;
        })
        .count();

这把结果藏在外部状态里，也会在未来并行化时出现并发问题。

### 6.2 peek

peek 主要用于临时观察元素，不承载保存、通知或修改实体等业务动作。由于惰性和短路，peek 是否执行、执行多少次取决于终止操作。

### 6.3 循环可能更好

适合循环的情况：

- 多个累积结果需要同时更新；
- 有复杂 break/continue 或提前错误恢复；
- 每步需清楚记录失败；
- Stream 需要多个临时容器和嵌套 Collector；
- 调试和团队可读性明显更好。

### 6.4 性能直觉

至少检查：

- 遍历次数；
- sorted 的 O(n log n)；
- distinct/grouping 的额外空间；
- 装箱与 primitive stream；
- 多次重复计算；
- 数据量。

不要用一次 nanoTime 得出结论，也不要默认 Stream 比循环快或慢。

### 6.5 禁止 parallelStream

本周项目禁止 parallelStream，因为：

- 默认 common pool 资源边界不受业务控制；
- 副作用和线程安全更复杂；
- 小数据常被拆分开销抵消；
- 阻塞 I/O 会污染共享池；
- 顺序与异常行为更难说明。

第 6 周会学习显式并发，但也不代表可以随意并行 Stream。

## 7. Optional 的正确语义

### 7.1 表达“返回可能没有”

Repository.findById 返回 Optional<WorkOrder> 能明确区分“找到”和“没找到”。空集合则直接返回空 List，不要用 Optional<List<T>>。

### 7.2 创建

- Optional.of(value)：value 必须非 null；
- Optional.ofNullable(value)：null 变 empty；
- Optional.empty()：明确无值。

不要用 ofNullable 掩盖本应禁止的 null。若领域不变量要求非 null，应尽早拒绝。

### 7.3 map 与 flatMap

若函数返回普通值，用 map；若函数本身返回 Optional，用 flatMap 避免 Optional<Optional<T>>。

    repository.findById(id)
        .map(WorkOrder::equipmentId)
        .flatMap(equipmentRepository::findById);

链条过长或包含多个不同失败原因时，清晰分支更好。

### 7.4 orElse 与 orElseGet

orElse 的参数在调用前就求值，即使 Optional 有值也会创建后备对象。orElseGet 接收 Supplier，只在空时求值。

若后备值是常量，orElse 很清楚；若创建昂贵或有副作用，使用 orElseGet。真正带副作用的后备创建还要审查是否适合隐藏在表达式里。

### 7.5 orElseThrow

应用边界可把仓储缺失转换为明确异常：

    repository.findById(id)
        .orElseThrow(() -> new WorkOrderNotFound(id));

异常 Supplier 只在空时调用。

### 7.6 不推荐的位置

- 实体字段：使模型和序列化复杂，通常字段本身应明确 nullable/状态；
- 方法参数：调用者被迫包装，重载或清晰参数契约更好；
- 集合元素：Optional 与 null 双重“无值”语义；
- DTO 字段：影响外部契约映射；
- 仅为了链式风格包装任何值。

Optional 是 API 返回语义，不是全面替代 null 的宗教。

## 8. TS/Vue 类比与失效

| TS/Vue 概念 | Java 类比 | 类比失效 |
| --- | --- | --- |
| Array.filter/map/flatMap | Stream 同名操作 | Array 操作通常立即产生数组；Stream 惰性且一次性 |
| 箭头函数 | Lambda | 捕获局部变量需 effectively final，目标类型更强 |
| 可选值 T 或 undefined | Optional<T> 返回语义 | Optional 是运行时对象，不宜到处传播 |
| nullish coalescing | orElse/orElseGet | orElse 参数会提前求值；不是完全等价 |
| computed | 派生结果 | computed 有响应式缓存；Stream 没有响应式依赖追踪 |
| Vue watch 副作用 | Stream forEach/外部动作 | Stream 中间操作不应承担响应式副作用 |
| Pinia getter | 查询/聚合 | 服务端数据可能更大，排序与复杂度必须显式 |

最重要失效点：Vue 的数组处理通常面向 UI 状态且数据量较小；Java 服务端查询未来可能下推到数据库，内存 Stream 不能替代 SQL、索引和分页。

## 9. FactoryCare 查询语义检查表

“未关闭”已经在 Week 03 确认为排除 `CLOSED/CANCELLED`。为避免每个查询重复判断，可在 `WorkOrderStatus` 上加入只读语义方法（这不是完整状态转换机）：

```java
public boolean isClosed() {
    return this == CLOSED || this == CANCELLED;
}
```

后续过滤统一调用该方法；`VERIFIED` 仍未关闭。

在编码前写清：

- 输入过滤条件可否缺失；
- 时间范围是闭区间还是半开区间；
- 状态“未关闭”复用已确认语义：`WorkOrderStatus` 既不是 `CLOSED` 也不是 `CANCELLED`；
- 排序方向与 tie-breaker；
- 空结果返回空列表还是异常；
- 重复 key 如何处理；
- 占比分母为零怎么办；
- 并列第一是否返回全部；
- 统计 DTO 是否泄漏实体；
- 一次还是多次遍历更清楚。

## 10. 自测

1. Lambda 捕获的引用 effectively final，为什么对象仍可能被修改？
2. Stream 什么时候真正执行？
3. map 和 flatMap 的类型变化有什么不同？
4. distinct 依赖什么契约？
5. 为什么 toMap 默认重复 key 异常可能是好事？
6. 状态占比分母为零怎么设计？
7. peek 为什么不能承担保存动作？
8. parallelStream 的资源边界在哪里？
9. orElse 为什么可能产生意外开销？
10. 为什么 Repository.findAll 不应返回 Optional<List<T>>？
11. 什么情况下循环比 Stream 更合适？
12. 内存 Stream 查询为什么不能替代后续数据库查询？

## 11. 官方资料

- [Java SE 25 函数式接口](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/function/package-summary.html)
- [Java SE 25 Stream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/stream/Stream.html)
- [Java SE 25 Collectors](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/stream/Collectors.html)
- [Java SE 25 Optional](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Optional.html)
- [JLS Lambda](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.27)
