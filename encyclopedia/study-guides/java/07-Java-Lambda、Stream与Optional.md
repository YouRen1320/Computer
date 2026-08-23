# Java：Lambda、Stream 与 Optional

## 1. 为什么要把“行为”也作为参数

以前的方法参数主要是数字、字符串或对象：

```java
calculatePriority(category, affectedUsers);
```

有时变化的不是数据，而是“怎样判断”或“怎样转换”。例如同一批工单，页面想筛选高优先级，报表想筛选已超时，通知任务想筛选尚未发送的记录。如果每种规则都复制一套遍历代码，修改和组合会越来越困难。

Java 可以用对象表示一段行为。调用方把行为传进方法，方法在合适时机执行：

```java
Predicate<WorkOrder> urgent = order -> order.priority() >= 4;
```

这里的 Lambda `order -> order.priority() >= 4` 表示“接收一个工单，返回它是否紧急”。它不是立即执行的结果，而是一段符合特定接口合同的行为。

这一章的主线是：

```text
函数式接口规定行为形状
  → Lambda 或方法引用提供实现
  → Stream 把多个行为连成数据处理管道
  → Optional 表达一次查找可能没有结果
```

## 2. 函数式接口：只有一个抽象行为的接口

可以先定义自己的接口：

```java
@FunctionalInterface
interface PriorityRule {
    boolean isUrgent(WorkOrder order);
}
```

然后使用 Lambda 提供实现：

```java
PriorityRule rule = order -> order.priority() >= 4;
```

函数式接口要求只有一个需要实现的抽象方法。它仍然可以有 `default`、`static` 方法，也会继承 `Object` 的公共方法，因此“函数式接口只有一个方法”并不准确。

`@FunctionalInterface` 不是必需，但它能让编译器检查未来修改是否破坏单一抽象方法合同。

### 2.1 Lambda 不能脱离目标类型独立存在

下面的 Lambda 怎样解释，取决于左边接口：

```java
Predicate<WorkOrder> urgent = order -> order.priority() >= 4;
```

编译器从 `Predicate<WorkOrder>` 得知：

- 输入参数是 `WorkOrder`；
- 返回结果是 `boolean`；
- Lambda 要实现的方法是 `test`。

这种由上下文决定 Lambda 类型的机制叫作**目标类型（target typing）**。同一段形状有时能匹配多个重载，若上下文不足就可能出现重载歧义。此时可以使用清楚的变量类型或显式强转，不要靠猜编译器会选哪个。

## 3. 四种常见行为形状

JDK 在 `java.util.function` 中提供许多通用函数式接口。先掌握四种：

| 接口 | 输入 | 输出 | 常见用途 |
| --- | --- | --- | --- |
| `Predicate<T>` | `T` | `boolean` | 判断是否符合条件 |
| `Function<T, R>` | `T` | `R` | 把一种值转换成另一种 |
| `Consumer<T>` | `T` | 无返回值 | 使用值并产生副作用 |
| `Supplier<T>` | 无参数 | `T` | 延迟提供一个值 |

例子：

```java
Predicate<WorkOrder> open = order -> !order.isCompleted();
Function<WorkOrder, String> toId = order -> order.id().value();
Consumer<String> print = text -> System.out.println(text);
Supplier<Instant> now = () -> Instant.now();
```

还有针对基本类型的专门接口，如 `IntPredicate`、`ToIntFunction<T>`，可以避免在大量计算中把基本值反复装箱成对象。现阶段知道它们存在，遇到性能或 API 需要时再查。

### 3.1 形状相同不代表语义相同

两个 `Predicate<WorkOrder>` 都接收工单并返回布尔值，但一个可能表示“允许派工”，另一个表示“需要报警”。它们不能仅因类型相同就互换。

接口类型描述参数和返回值；方法名、变量名、文档和业务测试还要说明行为合同、空值政策、副作用和失败方式。

## 4. Lambda 语法：省略样板，不省略合同

最完整的写法可以有参数类型和代码块：

```java
Predicate<WorkOrder> urgent = (WorkOrder order) -> {
    return order.priority() >= 4;
};
```

当编译器能推断类型且只有一个表达式时，可以简写：

```java
Predicate<WorkOrder> urgent = order -> order.priority() >= 4;
```

常见形式：

```java
() -> Instant.now()
text -> text.strip()
(left, right) -> left + right
order -> {
    audit(order);
    return order.priority();
}
```

只有一个参数时可以省略括号；没有参数或多个参数时保留括号。代码块需要明确 `return`，表达式形式则把表达式结果作为返回值。

简写的目标是让核心行为更清楚。若 Lambda 有十几行分支、多个副作用和异常处理，把它提取成有名字的方法通常更易读。

## 5. 方法引用：把已有方法接到接口上

如果 Lambda 只是调用一个现成方法：

```java
Function<String, String> normalize = text -> text.strip();
```

可以写成方法引用：

```java
Function<String, String> normalize = String::strip;
```

常见形状：

```java
ClassName::staticMethod
object::instanceMethod
ClassName::instanceMethod
ClassName::new
```

例如：

```java
Consumer<String> printer = System.out::println;
Supplier<List<String>> factory = ArrayList::new;
```

方法引用仍然需要目标函数式接口，编译器会根据接口参数匹配具体方法。它不是比 Lambda 更高级的机制，只是已有方法的简写。

如果方法引用让读者必须反复推断参数位置，普通 Lambda 反而更清楚：

```java
orders.sort((left, right) -> compareForDispatch(left, right));
```

## 6. 闭包和有效 final：Lambda 可以读取外部稳定变量

Lambda 可以读取外层局部变量：

```java
int threshold = 4;
Predicate<WorkOrder> urgent = order -> order.priority() >= threshold;
```

局部变量 `threshold` 必须是 `final` 或**有效 final（effectively final）**，也就是初始化后没有再次赋值。下面会编译失败：

```java
int threshold = 4;
Predicate<WorkOrder> urgent = order -> order.priority() >= threshold;
threshold = 5;
```

Lambda 捕获的是稳定变量绑定，不是让局部变量变成可随时共享写入的盒子。

### 6.1 捕获引用不等于对象不可变

```java
List<String> audit = new ArrayList<>();
Consumer<String> recorder = text -> audit.add(text);
```

变量 `audit` 没有改指向，因此满足有效 final；Lambda 仍然修改了列表对象。这会形成副作用和共享可变状态，在并行或重复执行时尤其危险。

不要用单元素数组或列表绕过有效 final，只为了在 Lambda 中修改计数：

```java
int[] count = {0};
items.forEach(item -> count[0]++);
```

它技术上可能编译，却隐藏可变状态。普通循环、`count()`、`reduce()` 或明确的累加器通常更合适。

## 7. 行为组合：把小规则连起来

`Predicate` 可以组合：

```java
Predicate<WorkOrder> urgent = order -> order.priority() >= 4;
Predicate<WorkOrder> open = order -> !order.isCompleted();

Predicate<WorkOrder> urgentAndOpen = urgent.and(open);
```

还有：

```java
urgent.or(open)
urgent.negate()
```

组合会保留布尔短路语义。例如 `urgent.and(open)` 在第一项为 `false` 时，不会执行第二个判断。若判断中含日志或写状态，执行次数会受组合顺序影响，这也是为什么判断函数最好没有副作用。

`Function` 可以连接转换：

```java
Function<WorkOrder, String> id = order -> order.id().value();
Function<String, String> upper = text -> text.toUpperCase(Locale.ROOT);

Function<WorkOrder, String> normalizedId = id.andThen(upper);
```

### 7.1 副作用应该放在清楚边界

副作用不是绝对禁止：写数据库、发消息、记录日志本来就会影响外部。但不要把它藏进看起来只是筛选或转换的函数：

```java
orders.stream()
        .filter(order -> {
            sender.send(order); // 隐藏副作用
            return order.priority() >= 4;
        });
```

`filter` 的职责应该是判断是否保留。通知发送应放在明确的终止步骤或服务边界，让执行次数、失败和重试可以被看见。

### 7.2 受检异常不会自动适配标准接口

`Function.apply` 等标准方法没有声明任意受检异常，因此直接在 Lambda 中调用抛 `IOException` 的方法可能无法编译。可选做法包括：

- 在更合适的外层捕获；
- 定义有清楚异常合同的专用函数式接口；
- 在边界转换异常并保留 cause；
- 不把这段 I/O 强行塞进 Stream。

不要为了让链式代码更短就吞掉异常或包装成没有上下文的 `RuntimeException`。

这一组必须掌握：函数式接口规定行为形状，Lambda 和方法引用提供实现；捕获变量必须保持绑定稳定，但被引用对象仍可能可变。

## 8. Stream：一条一次性的计算描述，不是集合

从集合可以创建 Stream：

```java
Stream<WorkOrder> stream = orders.stream();
```

集合负责保存元素，Stream 负责描述“这些元素要经过什么处理”。它通常不拥有数据，也不允许按索引随机读取。

```java
List<String> urgentIds = orders.stream()
        .filter(order -> order.priority() >= 4)
        .map(order -> order.id().value())
        .toList();
```

这条管道包含：

1. 数据源 `orders`；
2. 中间操作 `filter`；
3. 中间操作 `map`；
4. 终止操作 `toList`。

### 8.1 中间操作通常是惰性的

只写：

```java
orders.stream()
        .filter(order -> order.priority() >= 4)
        .map(WorkOrder::id);
```

没有终止操作时，通常不会完成整条遍历。Stream 先记录管道，真正需要结果时才拉取元素。

因此不要依赖一个没有终止操作的管道产生副作用；也不要以为写到 `map` 就已经得到新列表。

### 8.2 Stream 只能消费一次

```java
Stream<WorkOrder> stream = orders.stream();
long count = stream.count();
// stream.toList(); // 再使用会失败
```

一个 Stream 实例在终止操作后已经关闭其消费生命周期。需要另一个结果时，重新从数据源创建 Stream，或者一次收集成可重复使用的集合。

## 9. filter、map 和 flatMap：三种不同责任

### 9.1 filter 选择元素

```java
orders.stream()
        .filter(WorkOrder::isOpen)
```

输入一个元素，判断是否保留。元素类型通常不变。

### 9.2 map 转换每个元素

```java
orders.stream()
        .map(WorkOrder::id)
```

每个工单转换成一个 ID。元素数量可能因上游操作变化，但 `map` 自己通常是一对一转换。

### 9.3 flatMap 展开嵌套结果

假设每张工单有多个标签：

```java
Stream<String> tags = orders.stream()
        .flatMap(order -> order.tags().stream());
```

普通 `map` 会得到 `Stream<List<String>>`，`flatMap` 把每个子 Stream 展开，形成一条标签流。

可以用一句话区分：

- `filter`：要不要这个元素；
- `map`：把这个元素变成什么；
- `flatMap`：一个元素产生零个、一个或多个结果，再把嵌套层摊平。

### 9.4 顺序会影响语义和成本

```java
orders.stream()
        .filter(WorkOrder::isOpen)
        .map(this::expensiveView)
```

先过滤可以避免转换不需要的元素。若 `map` 影响过滤条件，顺序又不能随意交换。优化前先保持语义正确，并确认转换是否真的是热点。

## 10. reduce：把多个元素合成一个结果

求金额总和：

```java
long total = amounts.stream()
        .reduce(0L, Math::addExact);
```

`0L` 是单位元，表示空输入时结果为零，也应满足 `0 + x = x`。合并函数要能按不同分组顺序得到一致结果，尤其在并行时需要**结合性**。

并不是所有累加都适合 `reduce`。把元素加入可变 `ArrayList` 的任务通常用 `collect`；求基本数值还可以使用 `mapToLong(...).sum()`，语义更直接。

### 10.1 不要在 reduce 中修改共享对象

下面把同一个可变列表当单位元，会破坏 reduce 的组合假设：

```java
List<WorkOrder> result = orders.stream().reduce(
        new ArrayList<>(),
        (list, order) -> { list.add(order); return list; },
        (left, right) -> { left.addAll(right); return left; }
);
```

收集列表直接使用 `toList()` 或 `collect(...)`。`reduce` 更适合不可变值合并。

## 11. Collector：把管道结果收集成结构

常见终止操作：

```java
List<WorkOrder> open = orders.stream()
        .filter(WorkOrder::isOpen)
        .toList();
```

按类别分组：

```java
Map<String, List<WorkOrder>> byCategory = orders.stream()
        .collect(Collectors.groupingBy(WorkOrder::category));
```

统计每类数量：

```java
Map<String, Long> counts = orders.stream()
        .collect(Collectors.groupingBy(
                WorkOrder::category,
                Collectors.counting()
        ));
```

### 11.1 toMap 必须考虑重复键

```java
Map<WorkOrderId, WorkOrder> byId = orders.stream()
        .collect(Collectors.toMap(WorkOrder::id, Function.identity()));
```

若输入有重复 ID，默认会失败。不能为了让程序继续就随便“保留第一个”或“保留最后一个”；先决定重复键是数据错误、版本覆盖还是业务允许，然后写明确合并策略：

```java
Collectors.toMap(
        WorkOrder::id,
        Function.identity(),
        (existing, replacement) -> chooseByVersion(existing, replacement)
)
```

### 11.2 收集结果的可变性和顺序

`Stream.toList()` 返回的列表不能假设可修改。若后续确实需要可变列表，可以明确：

```java
List<WorkOrder> mutable = orders.stream()
        .collect(Collectors.toCollection(ArrayList::new));
```

`groupingBy` 或 `toMap` 的具体实现类型、遍历顺序也不要靠默认猜测。业务要求顺序时，显式排序或提供集合工厂。

## 12. Optional：让“可能没有结果”出现在返回类型中

查找工单可能找不到：

```java
Optional<WorkOrder> findById(WorkOrderId id) {
    return orders.stream()
            .filter(order -> order.id().equals(id))
            .findFirst();
}
```

调用方必须面对存在和缺失两种情况：

```java
WorkOrder order = repository.findById(id)
        .orElseThrow(() -> new WorkOrderNotFoundException(id));
```

### 12.1 Optional 适合返回值，不是万能容器

它常用于“本次查询可能没有单个结果”。通常不建议机械地把所有字段、方法参数、集合元素和 DTO 字段都包成 `Optional`。

- 多个结果用空集合表达没有元素；
- 参数是否可选可以用重载、请求模型或清楚的 `null` 合同；
- 持久化和 JSON 框架对 Optional 字段的行为需要单独确认；
- Optional 自己也不应为 `null`。

### 12.2 常见操作

```java
optional.map(WorkOrder::status)
optional.filter(WorkOrder::isOpen)
optional.ifPresent(this::display)
optional.orElse(defaultOrder)
optional.orElseGet(this::loadDefault)
optional.orElseThrow(...)
```

`map` 在有值时转换，没有值时保持空；如果转换函数本身返回 Optional，使用 `flatMap` 避免嵌套 `Optional<Optional<T>>`。

### 12.3 orElse 和 orElseGet 的执行差别

```java
WorkOrder result = optional.orElse(loadDefault());
```

`loadDefault()` 会在调用 `orElse` 前先执行，即使 Optional 有值。

```java
WorkOrder result = optional.orElseGet(this::loadDefault);
```

`orElseGet` 接收 Supplier，只有缺失时才调用。默认值创建昂贵、有副作用或可能失败时，这个差别很重要。

### 12.4 不要立即 get

```java
optional.get();
```

没有值时会抛 `NoSuchElementException`。如果刚创建 Optional 就无条件 `get()`，通常等于把清楚的缺失合同又变回运行异常。使用 `orElseThrow` 写出领域异常，或用分支处理缺失。

这一组必须掌握：Stream 描述一次性惰性管道；`filter`、`map`、`flatMap` 责任不同；Optional 用返回类型表达可能缺失，`orElseGet` 才会惰性计算默认值。

## 13. 顺序、无干扰和并行边界

### 13.1 不要在管道执行时修改数据源

Stream 要求中间行为通常保持无干扰：不要在遍历 `orders` 时又改变 `orders` 的结构。否则可能抛异常、漏数据或产生依赖执行方式的结果。

也要尽量保持 Lambda 无状态：

```java
List<String> output = new ArrayList<>();
orders.parallelStream().forEach(order -> output.add(order.id()));
```

多个线程同时修改普通 `ArrayList` 不安全，结果可能丢失或损坏。即使顺序 Stream 暂时正常，这种隐藏累加也让管道难以复用。

使用收集操作：

```java
List<String> output = orders.parallelStream()
        .map(order -> order.id().value())
        .toList();
```

### 13.2 encounter order

有些数据源有明确遇到顺序，例如 `List`；`HashSet` 没有业务可依赖的稳定顺序。`sorted()` 会建立排序顺序，`forEachOrdered` 在并行管道中按遇到顺序消费，但可能降低并行收益。

如果结果顺序是接口合同，要显式排序或使用有序数据源，不能依赖一次打印结果。

### 13.3 parallelStream 不是免费加速按钮

并行处理要同时满足：

- 数据量足够大；
- 单项工作值得并行；
- 操作容易拆分和安全合并；
- 没有共享可变状态；
- 阻塞 I/O、线程池和运行环境经过评估；
- 用测量证明收益大于开销。

普通 Web 请求中随意调用 `parallelStream()` 会使用共享执行资源，可能和其他任务互相影响。I/O 并发、虚拟线程和专用执行器在下一章学习。

## 14. 什么时候用循环，什么时候用 Stream

适合 Stream 的情况：

- 选择、转换、分组、汇总的意图可以清楚串起来；
- 没有复杂早退、重试或多步状态变化；
- 中间行为大多无副作用；
- 结果是一批新数据或一个汇总值。

适合普通循环的情况：

- 需要细致的 `break`、`continue` 或多阶段失败处理；
- 每一步都要更新多个相关状态；
- 调试时需要清楚观察每次变化；
- Stream 链为了追求短而变得难读；
- 操作本质上是命令式资源交互。

下面两种写法没有高低之分，关键是意图是否清楚：

```java
for (WorkOrder order : orders) {
    if (order.isOpen()) {
        total += order.amountCents();
    }
}
```

```java
long total = orders.stream()
        .filter(WorkOrder::isOpen)
        .mapToLong(WorkOrder::amountCents)
        .sum();
```

不要把每个循环都改成 Stream，也不要因为 Stream 是新语法就拒绝它。

## 15. 怎样调试一条看不懂的管道

先把一整行恢复成有名字的阶段：

```java
Predicate<WorkOrder> open = WorkOrder::isOpen;
Function<WorkOrder, String> toCategory = WorkOrder::category;

Stream<WorkOrder> source = orders.stream();
Stream<WorkOrder> filtered = source.filter(open);
Stream<String> categories = filtered.map(toCategory);
List<String> result = categories.toList();
```

然后逐个确认：

1. 数据源有哪些元素、是否有顺序；
2. 每个中间操作的输入和输出类型；
3. 哪个终止操作真正触发执行；
4. 空、单项、重复和 `null` 怎样处理；
5. 是否有共享可变状态或隐藏 I/O；
6. 重复键、缺失值和异常在哪一层出现。

必要时可临时使用 `peek` 观察元素，但它主要用于调试，不应承担业务副作用。更稳定的方法是把复杂行为提取成可单独调用的方法并检查中间结果。

## 16. 本章的掌握边界

必须掌握：

- 函数式接口是 Lambda 的目标合同；
- `Predicate`、`Function`、`Consumer`、`Supplier` 的输入输出形状；
- Lambda、方法引用和有效 final；
- Stream 的惰性、一次性消费和终止操作；
- `filter`、`map`、`flatMap`、`reduce`、`collect` 的不同责任；
- Optional 表达可能缺失，以及 `orElse`/`orElseGet` 的差别；
- 管道中避免共享可变状态和隐藏副作用。

见过即可：

- 原始类型专用函数接口；
- Collector 的供应、累加、合并和收尾模型；
- 遇到顺序与 `forEachOrdered`；
- 并行 reduce 对结合性的要求。

需要时查询：

- 每个 Collector 的参数和返回特征；
- 复杂泛型推断与重载歧义；
- 受检异常适配方案；
- 自定义 Spliterator、并行性能和线程池细节。

整章可以记成一句话：先用函数式接口把一段行为变成明确合同，再让 Stream 按顺序组合选择、转换和汇总；可能没有单个结果时用 Optional 明确表达，而不是把副作用和空值悄悄藏进链条。

