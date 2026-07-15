# 第 5 周：Lambda、Stream 与 Optional

## 定位

本周学习 Java 的声明式数据处理工具，但不把所有循环改成 Stream。目标是能判断什么时候 Lambda/Stream 更清晰、什么时候显式循环更可靠，并正确使用 Optional 表达“查询可能无结果”。

时间预算：15—18 小时。所有 Stream 管道都必须能用普通循环复述其输入、输出、复杂度和副作用。

## 前置

- 熟练使用集合、泛型、Comparator 和 JUnit。
- FactoryCare 内存仓储、JSON 导入导出和时间模型可用。
- 能写清晰的 for 循环并处理空集合。
- 了解方法应尽量职责单一，核心查询不应修改输入集合。

## 目标

- 理解函数式接口、Lambda 捕获和方法引用。
- 使用 Stream 完成筛选、映射、扁平化、排序、聚合与分组。
- 理解惰性、中间操作、终止操作和短路。
- 控制副作用，不在管道中偷偷修改领域对象。
- 正确使用 Optional，避免 `get()`、嵌套 Optional 和字段滥用。
- 为 FactoryCare 实现工单查询与运维统计服务。

## 完整概念清单

### Lambda 与函数式接口

- 函数式接口只有一个抽象方法；`@FunctionalInterface` 的作用。
- `Predicate`、`Function`、`Consumer`、`Supplier`、`UnaryOperator`、`BinaryOperator`。
- Lambda 参数、表达式体、块体和类型推断。
- 方法引用的四种常见形式，只在更易读时使用。
- 捕获局部变量必须 effectively final。
- Lambda 中的 `this` 与匿名类不同，只理解行为差异。
- 不把复杂业务流程塞进超长 Lambda。

### Stream 模型

- Stream 不是集合，不保存数据，通常只能消费一次。
- 数据源、中间操作、终止操作。
- 惰性求值、操作融合和短路的直觉。
- `filter`、`map`、`flatMap`、`distinct`、`sorted`、`limit/skip`。
- `findFirst/findAny`、`anyMatch/allMatch/noneMatch`。
- `count`、`reduce` 与单位元；数值聚合优先 primitive stream 或统计收集器。
- `toList`、`Collectors.toSet/toMap/groupingBy/partitioningBy/joining`。
- `toMap` 的重复 key 合并策略必须显式。
- 多级 grouping 和 downstream collector 只做可读范围内的组合。

### 副作用、性能与调试

- 中间操作应尽量无状态、无副作用。
- 不在 `map/peek` 中修改共享集合或领域实体。
- `peek` 主要用于观察调试，不承担业务动作。
- 一次清晰循环可能优于多次遍历和复杂 Collector。
- 大 O、装箱、排序和多次扫描的基本成本意识。
- `parallelStream` 并非“加一个 parallel 就更快”，本周禁止用于项目代码。

### Optional

- Optional 是“可能无值的返回结果”容器，不是通用 null 替代品。
- `of`、`ofNullable`、`empty`。
- `map`、`flatMap`、`filter`、`orElse`、`orElseGet`、`orElseThrow`。
- `orElse` 会立即计算参数，昂贵后备值使用 `orElseGet`。
- 不直接 `get()`，不把 Optional 作为实体字段、方法参数或集合元素。
- Optional 链过长时使用清晰分支。
- 在应用边界把“无值”转换为明确业务结果或异常。

### 查询设计

- 查询条件对象与硬编码筛选的边界。
- 排序、过滤、分页的稳定顺序。
- 统计结果 DTO/record 与领域实体分离。
- 空结果、重复 key、未知状态和 null 数据的策略。

## 任务分配

| 模块 | 时间 | 任务 |
| --- | ---: | --- |
| Lambda | 2h | 函数式接口、捕获和方法引用练习 |
| Stream | 4h | 筛选、映射、扁平化、聚合、分组和短路 |
| Optional | 2h | 查询缺失、后备值和异常边界练习 |
| 可读性比较 | 1.5h | 循环与 Stream 两版实现及性能直觉 |
| FactoryCare | 3—4h | 查询与统计服务、测试和错误样例 |
| 无 AI 训练 | 2h | 新报表与管道调试 |
| 求职动作 | 1h | Stream/Optional 高频题与投递 |

## FactoryCare项目增量

实现 `WorkOrderQueryService` 和 `MaintenanceDashboardService`：

- 按状态、优先级、设备 ID 和时间范围组合筛选。
- 按优先级、创建时间稳定排序。
- 按设备统计未关闭工单数。
- 按状态分组并计算占比；分母为零行为明确。
- 找出重复故障最多的设备，处理并列与空数据。
- 将仓储 `findById` 的缺失结果使用 Optional 表达，并在应用服务转换为明确异常。

至少选择一个查询分别用循环和 Stream 实现，比较可读性、遍历次数、错误处理和测试难度；保留更适合团队维护的一版。

## AI协作边界

可以让 AI：

- 将你的自然语言查询拆成数据流步骤。
- 为 Collector 的重复 key、空集合和并列结果生成反例。
- 审查 Stream 是否包含副作用、重复遍历或难读嵌套。
- 比较循环与 Stream 实现，但最终选择由你解释。

必须由你完成：

- 先写输入、输出、排序和空结果语义。
- 对每个中间操作说清元素类型如何变化。
- 检查 `orElse` 的提前计算、Optional.get 和 `parallelStream` 滥用。
- 能把 AI 生成的 Stream 改写成正确循环以验证理解。

## 无AI训练

本周从求职/复盘时段预留45—60分钟完成并记录：栈或队列题；说明所选结构、边界和复杂度。

关闭 AI，限时120分钟：

1. 实现“每种优先级中最早创建的未关闭工单”报表。
2. 明确重复、空结果和并列规则。
3. 先写普通循环，再写 Stream 版本，选择并说明保留哪一版。
4. 补齐空仓储、单条、多状态和相同时间测试。
5. 口述 `map/flatMap`、惰性、短路、`orElse/orElseGet`。

## 求职动作

- 准备 Lambda、函数式接口、Stream 惰性、map/flatMap、reduce、parallelStream、Optional 的 90 秒回答。
- 用 FactoryCare 报表代码作为示例，不背孤立 API。
- 完成至少 5 个匹配岗位的定向投递或简历适配；记录 Java 基础反馈。
- 若面试题要求手写 Stream，先写数据流再编码，不追求一行完成。

## 交付物

- FactoryCare 查询服务与运维统计服务。
- 至少一项循环/Stream 对比记录。
- 空集合、重复 key、并列排序和 Optional 缺失测试。
- Stream 管道类型变化图或文字说明。
- 无 AI 报表实现和复盘。

## 验收标准

- 能解释常用函数式接口、Lambda 捕获和方法引用。
- 能逐步说明 Stream 管道的输入输出类型、惰性和终止点。
- 项目 Stream 无可见副作用、无 `parallelStream`、无无理由多次遍历。
- Optional 不作为字段或参数，不调用无保护 `get()`。
- 能说明 `orElse` 与 `orElseGet` 的实际行为差异。
- 查询排序稳定，空结果、重复 key 和并列规则有测试。
- 无 AI 完成新报表并在循环/Stream 之间做可维护性判断。

## 明确不做

- 不深入 Stream Spliterator、内部流水线或 JIT 优化源码。
- 不使用 parallelStream 做并发；第 6 周学习显式并发工具。
- 不引入响应式编程、Reactor、RxJava 或函数式框架。
- 不为了“函数式”消灭所有 if、循环和局部变量。
- 不接入数据库或 Web API。

## 官方资料

- [Java SE 25：java.util.function](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/function/package-summary.html)
- [Java SE 25：Stream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/stream/Stream.html)
- [Java SE 25：Collectors](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/stream/Collectors.html)
- [Java SE 25：Optional](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Optional.html)
- [Java Language Specification：Lambda Expressions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.27)
