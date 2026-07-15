# Week 05 实验、FactoryCare 增量与故障注入

## 0. 实验纪律

- 每条 Stream 先用一句自然语言说明输入与输出；
- 在代码旁或笔记中标出每个阶段元素类型；
- 任何聚合先定义空集合、重复 key 和并列规则；
- 先有普通循环基线，再决定是否使用 Stream；
- 本周禁止 parallelStream；
- 不引入 Spring、数据库和响应式框架。

## 实验 1：函数式接口与捕获

### 任务

为工单建立以下规则：

    Predicate<WorkOrder> open
    Predicate<WorkOrder> critical
    Function<WorkOrder, WorkOrderRow> toRow
    Comparator<WorkOrder> displayOrder
    Supplier<WorkOrderRow> emptyFallback

把 open.and(critical) 组合成一个规则，并用普通命名方法写等价版本。比较：

- 哪个更容易测试；
- 业务名字是否清楚；
- 重复使用时是否值得提取。

### effectively final 实验

先写：

    int minimum = 3;
    Predicate<DeviceStats> frequent =
        stats -> stats.failureCount() >= minimum;

然后尝试在 Lambda 后修改 minimum，观察编译错误。

再捕获一个 final List，并在 Lambda 内 add。它可能编译，但这是可变副作用。写下：

> effectively final 约束的是局部变量绑定，不保证对象不可变。

### this 实验

在一个实例类中分别用 Lambda 和匿名类打印 this.getClass()，观察指向差异。只记录行为，不研究生成字节码。

## 实验 2：惰性、短路与一次性

### 惰性

构造带计数器的映射函数：

    AtomicInteger mapped = new AtomicInteger();

    Stream<WorkOrder> pipeline = orders.stream()
        .map(order -> {
            mapped.incrementAndGet();
            return order;
        });

在终止操作前断言 mapped 为 0。先执行 `toList()`，证明实际消费时 mapper 被调用。然后重新创建同一管道并执行 `count()`：对已知大小且 map 不改变元素数量的集合源，JDK 25 允许直接计算数量并完全省略 map，计数器可能仍为 0。这不是“终止操作失效”，而是 Stream 可以消除不影响结果的阶段；也正说明业务不能依赖行为参数的副作用。这里的 AtomicInteger 仅用于实验观测。

### 短路

用 anyMatch 查找第一个紧急未关闭工单，记录检查元素数。改变紧急工单位置，观察数量变化。

### 一次性

对同一个 pipeline 调用两次终止操作，记录异常。结论：需要重复计算时重新从数据源创建 Stream，或先收集为值。

## 实验 3：map、flatMap 与 distinct

数据结构：

    WorkOrder
      └─ List<PartUsage>

完成：

1. map 得到 Stream<List<PartUsage>>；
2. flatMap 得到 Stream<PartUsage>；
3. 映射为 partCode；
4. distinct；
5. 排序并收集。

故障注入：故意破坏 PartCode 的 equals/hashCode，证明 distinct 结果错误，再修复。

类型轨迹必须写出：

    Stream<WorkOrder>
    Stream<List<PartUsage>>
    Stream<PartUsage>
    Stream<PartCode>
    List<PartCode>

## 实验 4：排序与稳定性

准备多个优先级、相同 createdAt 的工单。先只按优先级和时间排序，重复打乱输入后运行，观察并列项顺序依赖输入。

加入唯一 id tie-breaker，定义最终顺序：

1. 业务优先级高到低；
2. createdAt 早到晚；
3. id 升序。

不要直接依赖 enum.ordinal 表达业务优先级。创建显式 rank 或 Comparator。

## 实验 5：toMap、groupingBy 与空集合

### 重复 key

将工单按 equipmentId 收集为 Map。故意让同设备有两张工单，观察无 merge function 的异常。

实现三种不同业务语义：

- equipmentId → 最早未关闭工单；
- equipmentId → 最新工单；
- equipmentId → 工单列表。

证明 merge function 不是语法补丁，而是业务决定。

### 分组

实现：

- 按状态计数；
- 按设备统计未关闭工单数；
- 按优先级分区或分组；
- 对所有工单状态占比。

空集合时返回空 Map 或显式全零 DTO，选择一种并测试。禁止出现 NaN。

### reduce

用 reduce 求总工时，再用 mapToLong.sum 或 collector 实现，比较可读性。说明单位元为什么必须正确。

## 实验 6：Optional 求值行为

### orElse 与 orElseGet

写一个会增加计数的 fallback：

    WorkOrder createFallback() {
        fallbackCalls.incrementAndGet();
        return ...;
    }

分别对有值 Optional 调用：

    optional.orElse(createFallback())
    optional.orElseGet(this::createFallback)

断言第一次会调用后备创建，第二次不会。

### map 与 flatMap

从：

    Optional<WorkOrder>

获取：

    Optional<Equipment>

先用 map 产生嵌套 Optional，再用 flatMap 修正。

### 应用边界

Repository 保持返回 Optional；ApplicationService 使用 orElseThrow 转换为 WorkOrderNotFound。不要让 Optional 一路进入 DTO。

## 实验 7：FactoryCare 组合查询

### 查询对象

建立不可变查询条件。为避免把 Optional 变成字段，使用有业务名字的条件类型：

    record WorkOrderQuery(
        Set<WorkOrderStatus> statuses,
        Set<Priority> priorities,
        EquipmentCriterion equipment,
        CreatedAtCriterion createdAt
    ) {}

    sealed interface EquipmentCriterion
        permits AnyEquipment, SpecificEquipment {}

    record AnyEquipment() implements EquipmentCriterion {}
    record SpecificEquipment(EquipmentId id)
        implements EquipmentCriterion {}

时间条件同理使用 AllTime 或 CreatedWithin，而不是 null、Optional 字段或魔法最小/最大时间。专用类型会多几行代码，但能让调用方显式选择“不过滤”或“按条件过滤”。

推荐时间范围使用半开区间：

    createdAt >= from
    createdAt < before

### 双版本

实现：

1. 清晰普通循环；
2. Stream 管道。

两版必须通过同一参数化测试。比较：

- 业务规则可见性；
- 元素类型；
- 遍历次数；
- 调试；
- 增加一个新条件时的修改成本。

最终只保留更可维护的一版，另一版可放学习笔记或测试夹具，不在生产包留下重复实现。

## 实验 8：FactoryCare 看板统计

实现 MaintenanceDashboardService：

- 每个状态数量；
- 每台设备未关闭工单数；
- 状态占比；
- 重复故障最多设备；
- 每种优先级最早创建的未关闭工单。

### 语义先决策

- 没有工单时占比返回什么；
- 多台设备并列第一是否全部返回；
- “重复故障”是所有工单还是只算已关闭故障；
- 相同 createdAt 如何稳定选择；
- 未知或未来状态如何处理。

### 最低测试矩阵

| 数据 | 应证明 |
| --- | --- |
| 空仓储 | 无除零、无 get 异常 |
| 单条 | 每项统计正确 |
| 多状态 | 过滤与分组正确 |
| 同设备多单 | 计数与最早项正确 |
| 多设备并列 | 按约定全部返回或稳定决胜 |
| 同时间 | 唯一键 tie-breaker |
| 缺失 ID | Optional 转明确异常 |

## 实验 9：栈与队列算法副线

### 题目 A：有效括号

使用 Deque<Character> 作为栈，不使用旧式 Stack。要求：

- 遇左括号入栈；
- 遇右括号时检查栈非空且类型匹配；
- 结束时栈必须为空；
- 测试空串、单个符号、嵌套、交叉和提前右括号。

### 题目 B：用队列做层次处理

给定简单树或任务依赖层，使用 ArrayDeque 按层遍历。说明：

- offer/poll/peek；
- 为什么不使用 remove 导致空队列异常；
- 时间 O(n)，队列空间 O(w)，w 为最大层宽。

无 AI 考核至少完成一道，另一道作为补考变体。

## 故障注入总表

| 编号 | 故障 | 观察 | 修复 |
| --- | --- | --- | --- |
| F05-01 | 无终止操作却期待 map 执行 | 计数为 0 | 理解惰性 |
| F05-02 | 重用已消费 Stream | IllegalStateException | 重新建流或收集 |
| F05-03 | map 中写外部 List | 隐藏结果和副作用 | 使用 collect/toList |
| F05-04 | peek 保存实体 | 短路导致保存次数不确定 | 显式命令循环 |
| F05-05 | toMap 随手保留第一条 | 数据质量被掩盖 | 明确 merge 业务语义 |
| F05-06 | orElse 创建昂贵后备 | 有值仍调用 | orElseGet |
| F05-07 | Optional.get | 空时崩溃 | map/orElseThrow/分支 |
| F05-08 | 排序无 tie-breaker | 并列顺序漂移 | 唯一键稳定排序 |
| F05-09 | 空集合占比 | NaN/除零 | 明确空语义 |
| F05-10 | parallelStream | common pool 与副作用风险 | 删除，保持串行 |

## 证据

至少保存：

    mvn -q test

以及：

- 每步元素类型说明；
- 循环/Stream 选择记录；
- orElse/orElseGet 调用计数测试；
- 重复 key 与并列测试；
- 故障注入前后差异；
- 栈或队列边界测试；
- [无 AI 考核评分](./assessment.md)。
