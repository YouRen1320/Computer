# Java：集合、泛型、相等性与排序

## 1. 数组不够用时，为什么要有集合

数组适合数量已经确定、元素类型固定的数据：

```java
String[] deviceCodes = new String[3];
```

但业务数据经常会变化：工单会不断加入，已经处理的任务会移除，还需要去重、按编号查找或按优先级排序。Java 集合框架为这些常见需求提供了不同数据结构。

最常用的四类接口是：

| 接口 | 主要特点 | FactoryCare 例子 |
| --- | --- | --- |
| `List` | 有顺序，可重复，按索引访问 | 工单查询结果 |
| `Queue` | 按排队规则取出待处理项 | 等待派工队列 |
| `Set` | 不保留重复元素 | 已通知的工单 ID |
| `Map` | 一个键对应一个值 | 工单 ID 到工单对象 |

选择集合时先问业务语义，不要先问“哪个类更快”：是否需要顺序？是否允许重复？是否按键查找？是否经常从两端加入和移除？只有先回答这些问题，复杂度比较才有意义。

### 1.1 接口类型和具体实现

常见写法是左边声明接口，右边选择实现：

```java
List<String> ids = new ArrayList<>();
Map<String, WorkOrder> byId = new HashMap<>();
```

调用方依赖 `List` 或 `Map` 的契约，创建位置再决定使用 `ArrayList`、`HashMap` 等实现。以后更换实现时，影响范围更小。

泛型尖括号中的 `String`、`WorkOrder` 规定元素类型。它会在后面单独解释。

## 2. List：保存有顺序、允许重复的一批元素

`List` 中的元素有索引，允许多个内容相等的元素：

```java
List<String> statuses = new ArrayList<>();
statuses.add("CREATED");
statuses.add("ASSIGNED");
statuses.add("ASSIGNED");

System.out.println(statuses.get(0)); // CREATED
System.out.println(statuses.size()); // 3
```

常见操作包括：

- `add(element)`：添加元素；
- `get(index)`：按索引读取；
- `set(index, element)`：替换某个位置；
- `remove(...)`：删除；
- `contains(element)`：检查是否存在；
- `size()`：元素数量；
- `isEmpty()`：是否为空。

索引仍然从 `0` 开始，最后一个合法索引是 `size() - 1`。空列表没有合法索引。

### 2.1 ArrayList 是常用默认实现

`ArrayList` 内部使用可扩容数组，适合：

- 按索引频繁读取；
- 经常在末尾追加；
- 大部分遍历按顺序进行。

在中间或开头插入、删除时，后面的元素可能需要移动。是否真的构成性能问题，要看数据规模和操作频率，不能看到一次插入就立即换结构。

`LinkedList` 同时实现 `List` 和 `Deque`，但它的每个节点有额外对象和引用成本，按索引访问还需要走链表。普通业务列表不应因为“插入理论上快”就默认改用它；若需求是队列或双端操作，通常直接把变量声明成 `Deque` 更能表达意图。

### 2.2 创建固定内容列表

```java
List<String> allowed = List.of("CREATED", "ASSIGNED");
```

`List.of(...)` 返回不能通过普通修改方法改变的列表，也不接受 `null` 元素。它适合固定规则或只读输入。

```java
List<String> snapshot = List.copyOf(source);
```

`List.copyOf(...)` 根据当前内容得到不可修改列表。它能防止调用者通过列表结构增删，但如果元素本身是可变对象，元素内部仍可能变化。列表不可修改不等于整个对象图深不可变。

### 2.3 不可修改视图和独立副本

```java
List<String> view = Collections.unmodifiableList(source);
```

这个 `view` 不能通过自身修改，但它通常仍是原列表的视图。其他代码修改 `source` 后，`view` 可能看到变化。

`List.copyOf(source)` 更接近当时内容的独立结构快照。二者都不会自动深复制可变元素。选择时要明确想要的是“禁止从这个入口修改”，还是“冻结当前结构内容”。

## 3. 遍历集合：读取和结构修改要分清

增强 `for` 可以逐项读取：

```java
for (WorkOrder order : orders) {
    System.out.println(order.id());
}
```

也可以显式使用迭代器：

```java
Iterator<WorkOrder> iterator = orders.iterator();
while (iterator.hasNext()) {
    WorkOrder order = iterator.next();
    System.out.println(order.id());
}
```

### 3.1 遍历时不要直接改集合结构

下面的写法常导致 `ConcurrentModificationException`：

```java
for (WorkOrder order : orders) {
    if (order.isCompleted()) {
        orders.remove(order);
    }
}
```

增强 `for` 背后使用迭代器，而外部直接改变了集合结构，迭代器发现遍历基础发生变化。这里的 “Concurrent” 不一定表示多线程，它也可能是同一线程中的不允许修改。

可以使用迭代器自己的删除入口：

```java
Iterator<WorkOrder> iterator = orders.iterator();
while (iterator.hasNext()) {
    if (iterator.next().isCompleted()) {
        iterator.remove();
    }
}
```

或者使用表达意图的批量操作：

```java
orders.removeIf(WorkOrder::isCompleted);
```

若要根据旧集合产生新结果，创建一个新列表通常更容易推理。具体选哪种，要看是否允许原地修改和调用者是否共享同一列表。

## 4. Queue 和 Deque：按处理顺序取出元素

`Queue` 表示队列。最常见语义是先加入的先取出：

```java
Queue<WorkOrder> pending = new ArrayDeque<>();
pending.offer(first);
pending.offer(second);

WorkOrder next = pending.poll();
```

成对方法的差别：

| 操作 | 失败时返回特殊值 | 失败时抛异常 |
| --- | --- | --- |
| 加入 | `offer` | `add` |
| 读取但不移除队首 | `peek` | `element` |
| 读取并移除队首 | `poll` | `remove` |

空队列是正常情况时，`peek` 和 `poll` 往往更容易处理；空队列表示调用错误时，异常版本可能更明确。不要只凭方法名短来选择。

### 4.1 Deque 可以操作两端

`Deque` 是双端队列：

```java
Deque<String> history = new ArrayDeque<>();
history.addLast("ASSIGNED");
history.addLast("IN_PROGRESS");
String latest = history.removeLast();
```

它既可以表达队列，也可以表达栈。现代 Java 代码通常用 `ArrayDeque` 代替旧的 `Stack` 类。

`ArrayDeque` 不允许 `null` 元素。这样 `poll()` 返回 `null` 可以清楚表示队列为空，不会和真实元素混淆。

## 5. Set：根据相等规则去重

`Set` 不保留重复元素：

```java
Set<DeviceId> visited = new HashSet<>();
visited.add(new DeviceId("PUMP-01"));
visited.add(new DeviceId("PUMP-01"));
```

最终是否只有一个元素，不取决于两个变量是否是同一对象，而取决于 `DeviceId.equals()` 和 `hashCode()` 的契约。

常见实现：

- `HashSet`：不承诺有意义的遍历顺序，通常提供快速哈希查找；
- `LinkedHashSet`：保留插入顺序；
- `TreeSet`：按自然顺序或比较器排序，同时用比较结果判断是否重复。

如果业务输出要求稳定顺序，不要依赖 `HashSet` 当前运行碰巧展示的顺序。明确选择保序实现，或在输出前排序。

### 5.1 去重不是自动的数据清洗

`Set` 只根据对象相等规则去重。`"PUMP-01"`、`"pump-01"` 和 `" PUMP-01 "` 是否代表同一设备，应先在输入边界规范化或使用业务值类型。不能期望集合猜出业务语义。

## 6. Map：用键找到对应的值

`Map<K, V>` 保存键到值的映射：

```java
Map<WorkOrderId, WorkOrder> byId = new HashMap<>();
byId.put(order.id(), order);

WorkOrder found = byId.get(new WorkOrderId("WO-1001"));
```

每个键最多对应一个当前值。再次 `put` 相同键通常会替换旧值，并返回之前的值。

### 6.1 缺失和 null 值要有明确政策

`Map.get(key)` 在“键不存在”时返回 `null`。某些 `Map` 实现又允许值本身是 `null`，于是仅凭 `get` 无法区分两种情况：

```java
if (byId.containsKey(id)) {
    // 键存在，即使对应值可能为 null
}
```

业务 Map 通常更清楚的做法是避免存 `null` 值，让 `null` 专门表示缺失；或把查找结果转换为明确的 `Optional`/领域结果。是否允许 `null` 由契约决定，不要只因为 `HashMap` 技术上允许就使用。

### 6.2 统计频次

```java
Map<String, Integer> counts = new HashMap<>();
for (WorkOrder order : orders) {
    counts.merge(order.category(), 1, Integer::sum);
}
```

`merge` 在键不存在时放入 `1`，存在时用给定函数合并旧值和新值。也可以用 `getOrDefault` 手动写清过程：

```java
int next = counts.getOrDefault(category, 0) + 1;
counts.put(category, next);
```

初学时能读懂显式版本更重要；熟悉后再根据团队可读性选择便利 API。

### 6.3 Map 不是数据库

内存 Map 只属于当前 JVM 对象生命周期。它不自动提供：

- 进程重启后的持久化；
- 多实例之间的一致数据；
- 事务、权限和租户隔离；
- 无限容量；
- 并发访问安全。

它可以作为局部索引、缓存实验或批处理结构，但不能因为查找方便就冒充持久化存储。

这一组必须掌握：`List` 管顺序和重复，`Queue/Deque` 管取出顺序，`Set` 管唯一性，`Map` 管键值查找；集合语义和对象相等契约必须一起考虑。

## 7. 泛型：让容器在编译阶段知道元素类型

没有泛型时，一个容器只能把元素当 `Object`，读取后需要强制转换，错误可能拖到运行阶段。泛型把类型信息写进声明：

```java
List<WorkOrder> orders = new ArrayList<>();
orders.add(new WorkOrder(...));

WorkOrder first = orders.get(0);
```

编译器会阻止向 `List<WorkOrder>` 加入不相关类型，也会让读取结果直接具有 `WorkOrder` 静态类型。

### 7.1 类型参数

可以定义自己的泛型类：

```java
final class Result<T> {
    private final T value;

    Result(T value) {
        this.value = value;
    }

    T value() {
        return value;
    }
}
```

`T` 是类型参数。使用时由具体类型替代：

```java
Result<WorkOrder> result = new Result<>(order);
```

类型参数表示“这段结构对多种类型都成立”，不应该只是为了显示高级而添加。若逻辑只适用于 `WorkOrder`，普通具体类型可能更清楚。

### 7.2 原始类型会丢失检查

```java
List raw = new ArrayList();
raw.add("not a work order");
```

省略类型参数的旧写法叫作**原始类型（raw type）**。它会产生警告并把一部分错误推迟到运行时强转。新代码不要忽略这些警告；与遗留 API 交界时，把不安全转换集中在一个小边界，并尽快恢复具体类型。

### 7.3 类型擦除先理解边界

Java 泛型主要通过编译期检查实现，很多类型参数在运行时会被擦除。因此通常不能写 `new T()`，也不能简单判断 `value instanceof T`。数组和泛型组合也有额外限制。

当前必须理解的是：泛型提供编译期类型安全，不等于运行时会保留任意 `T` 的完整信息。反射和类型令牌会在后续章节再讲。

## 8. 泛型不是普通继承：List<子类> 不是 List<父类>

假设 `EmailNotification` 是 `Notification` 的子类，下面仍不能直接赋值：

```java
List<EmailNotification> emails = new ArrayList<>();
// List<Notification> notifications = emails; // 编译失败
```

原因是如果允许赋值，调用者就可以向 `notifications` 加入 `SmsNotification`，从而破坏原本只允许邮件的列表。

这种性质叫作**不变（invariant）**：`List<A>` 与 `List<B>` 的子类型关系不会自动跟随 `A` 与 `B`。

### 8.1 ? extends T：主要从中读取 T

```java
static void printAll(List<? extends Notification> items) {
    for (Notification item : items) {
        System.out.println(item);
    }
}
```

它可以接收 `List<EmailNotification>` 或 `List<SmsNotification>`。因为具体元素类型未知，通常可以安全读取为 `Notification`，却不能随意加入某个具体子类。

### 8.2 ? super T：主要向其中写入 T

```java
static void addDefaults(List<? super EmailNotification> target) {
    target.add(new EmailNotification());
}
```

它可以接收 `List<EmailNotification>`、`List<Notification>` 或 `List<Object>`。可以安全写入 `EmailNotification`，但读取时通常只能当 `Object`。

常见记忆法是 **PECS**：Producer Extends，Consumer Super。

- 数据源“生产”出 `T` 给你读取：`? extends T`；
- 目标“消费”你写入的 `T`：`? super T`。

这只是快速判断法。若方法既要频繁读又要写同一精确类型，使用明确的 `List<T>` 往往更清楚。

### 8.3 通配符不等于“随便什么都能放”

`List<?>` 表示元素具体类型未知。你可以读取为 `Object`，可以检查大小或遍历，但不能安全加入任意非 `null` 对象。它比原始类型安全得多，因为编译器仍然守住未知类型的一致性。

这一节必须掌握：泛型把类型错误提前到编译阶段；`List<子类>` 不是 `List<父类>`；`extends` 偏读取，`super` 偏写入。

## 9. equals 和 hashCode 决定哈希集合怎样看待对象

`HashSet` 去重、`HashMap` 查找键时，会一起使用 `hashCode` 和 `equals`：

1. 先根据哈希值缩小候选范围；
2. 再用 `equals` 判断是否是真正相同的键。

最重要的契约是：

```text
如果 a.equals(b) 为 true，a.hashCode() 必须等于 b.hashCode()
```

反过来不要求成立，不同对象允许发生哈希碰撞。

### 9.1 只重写 equals 会发生什么

两个 `DeviceId` 按值相等，却产生不同哈希值时，它们可能进入不同桶。`HashSet` 会保留两个逻辑重复值，`HashMap` 也可能用等值新对象查不到原键。

因此值类型应让二者使用同一组字段：

```java
@Override
public boolean equals(Object other) {
    if (this == other) return true;
    if (!(other instanceof DeviceId that)) return false;
    return value.equals(that.value);
}

@Override
public int hashCode() {
    return value.hashCode();
}
```

### 9.2 不要在键放入后修改相等字段

如果一个可变对象放进 `HashMap` 后，参与 `equals/hashCode` 的字段变化，它的新哈希位置和原来存放位置可能不同，于是集合“明明有这个对象却找不到”。

作为键的类型最好不可变，并使用稳定业务身份。不要让状态、显示名称等会变化的字段参与实体键相等。

### 9.3 TreeSet 和 TreeMap 看比较结果

有序集合用比较器或自然顺序判断元素位置。若比较结果为 `0`，它们通常把两个值视为同一排序键，即使 `equals` 返回 `false`。比较顺序与相等不一致会产生令人意外的去重结果，因此用作有序键时也要明确契约。

## 10. Comparable：类型自己的自然顺序

如果一种值只有一个稳定、自然的默认顺序，可以实现 `Comparable<T>`：

```java
record Priority(int level) implements Comparable<Priority> {
    @Override
    public int compareTo(Priority other) {
        return Integer.compare(this.level, other.level);
    }
}
```

然后可以：

```java
priorities.sort(null);
```

自然顺序应该长期稳定且容易说明。例如日期按时间先后、编号按规范值排序可能合理。工单既可以按优先级、创建时间、SLA 或负责人排序，没有唯一自然顺序时，不必强行实现 `Comparable`。

### 10.1 不要用减法写整数比较器

```java
return left.priority() - right.priority();
```

差值可能溢出，导致顺序错误。使用 `Integer.compare`、`Long.compare` 等比较方法更安全。

## 11. Comparator：为某个场景定义排序规则

`Comparator<T>` 把排序规则放在对象外部：

```java
Comparator<WorkOrder> byPriority =
        Comparator.comparingInt(WorkOrder::priority).reversed();
```

可以继续组合多个条件：

```java
Comparator<WorkOrder> orderForDispatch =
        Comparator.comparingInt(WorkOrder::priority).reversed()
                .thenComparing(WorkOrder::createdAt)
                .thenComparing(WorkOrder::id);
```

这表示：优先级高的在前；优先级相同则创建早的在前；仍相同则按 ID 兜底。兜底条件让输出更稳定，日志和测试更容易比较。

### 11.1 比较器必须形成一致顺序

比较器应满足：

- `compare(a, b)` 与 `compare(b, a)` 的符号相反；
- 若 `a < b` 且 `b < c`，应有 `a < c`；
- 相同输入重复比较结果稳定；
- 返回 `0` 的含义明确。

违反这些规则可能让排序抛异常、结果不稳定或有序集合行为异常。

### 11.2 null 顺序必须明确

如果数据允许 `null`，可以显式选择：

```java
Comparator<String> names = Comparator.nullsLast(String::compareTo);
```

但更重要的问题是：这里为什么允许缺失值？如果名称本来就是必填，应该在输入边界拒绝，而不是靠排序把错误数据推到末尾。

### 11.3 稳定排序

稳定排序会保留比较结果相等元素原来的相对顺序。Java `List.sort` 和对象数组的常用排序承诺稳定，但不要用稳定性掩盖缺少明确业务兜底。如果输出需要跨来源、跨查询仍保持相同顺序，应把全部排序键写入比较器或数据库 `ORDER BY`。

这一节必须掌握：自然顺序用 `Comparable`，场景顺序用 `Comparator`；多条件排序用比较器链，比较器必须满足一致性契约。

## 12. 复杂度：数据变大后，操作量怎样增长

复杂度不是精确运行时间，而是描述数据规模 `n` 增大时，主要操作数量怎样增长。常见记号：

| 记号 | 直觉 | 例子 |
| --- | --- | --- |
| `O(1)` | 规模变大，步骤大致不随之增长 | 数组按索引读取、平均哈希查找 |
| `O(log n)` | 每步排除一大部分 | 有序数组二分查找 |
| `O(n)` | 大致逐项看一遍 | 列表线性查找 |
| `O(n log n)` | 常见高效比较排序 | 通用对象排序 |
| `O(n²)` | 每个元素又扫描大部分元素 | 双层全量比较 |

`O(1)` 不表示永远只执行一条指令，`O(n)` 也不表示一定慢。小数据上的清楚代码可能比复杂索引更合适；百万条数据中的嵌套扫描则值得关注。

### 12.1 时间和空间要一起看

为了把反复查找从线性扫描变成平均常数时间，可以先建立 `HashMap`：

```java
Map<WorkOrderId, WorkOrder> index = new HashMap<>();
for (WorkOrder order : orders) {
    index.put(order.id(), order);
}
```

这需要额外内存和建索引时间。如果只查一次，直接扫描可能更简单；如果查十万次，索引通常更合理。

### 12.2 排序后二分也有前提

二分查找是 `O(log n)`，但前提是数据已经按相同规则排序。若每次查询前都重新排序，总成本可能比线性扫描更高。分析整个工作流，不能只摘一个 API 的复杂度。

### 12.3 数据结构选择清单

1. 数据有多少，大概会增长到多少？
2. 最频繁的是追加、随机读取、删除、去重还是按键查找？
3. 是否需要稳定顺序？
4. 是否允许重复或 `null`？
5. 相等和排序规则是什么？
6. 集合是否会共享、修改或并发访问？
7. 为速度增加的索引需要多少内存和维护成本？

先用符合语义的最简单结构；出现真实规模证据后，再针对热点调整。

## 13. 这一章的完整选择顺序

面对一批数据，可以按下面顺序判断：

1. 数量固定且只需简单索引：数组可能足够；
2. 需要有序、可重复的数据：`List`；
3. 按先后顺序处理：`Queue` 或 `Deque`；
4. 需要唯一性：`Set`，同时确认相等契约；
5. 需要由键快速找到值：`Map`，键最好稳定不可变；
6. API 要适配一族类型：使用泛型和合适的通配符；
7. 需要排序：确定自然顺序还是场景比较器；
8. 数据规模变大后：再比较整体时间与空间复杂度。

必须掌握：四类集合的语义、泛型的类型安全、`equals/hashCode` 对哈希集合的影响、`Comparable` 与 `Comparator` 的区别，以及常见复杂度的大致含义。

见过即可：不可修改视图与副本的区别、PECS、稳定排序、`TreeSet` 比较为零的去重行为。

需要时查询：各集合实现的精确复杂度、容量扩张、并发集合、排序算法细节、泛型擦除和复杂通配符推断。实际项目中先查接口合同和当前 JDK 文档，不凭印象背底层数字。

