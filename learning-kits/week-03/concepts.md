# Week 03 系统讲义

## 1. 先问访问模式，再选集合

集合选择不是背“哪个更快”，而是把业务需求翻译为约束：

| 业务问题 | 首选抽象 | 说明 |
| --- | --- | --- |
| 保留顺序、允许重复、按位置访问 | `List` | 例如稳定展示结果 |
| 唯一元素、只关心是否存在 | `Set` | 唯一性依赖相等语义 |
| 按唯一 key 找 value | `Map` | key契约决定查询正确性 |
| 先进先出/两端操作 | `Queue`/`Deque` | `ArrayDeque`通常优先 |
| 按比较规则有序 | `TreeSet/TreeMap` 或排序后的List | 比较契约必须一致 |

“数据量小”不能替代语义选择；“HashMap 快”也不能解释需要重复顺序的列表。

### TypeScript 类比与失效

JS/TS 的 Array、Set、Map 可帮助理解顺序、唯一和键值关系。

类比失效：Java 集合有静态泛型、primitive 需包装、`equals/hashCode` 决定哈希集合语义；JS Map 的对象 key 更接近引用身份。不能用 JS 经验猜 Java `HashMap` 的逻辑相等行为。

## 2. Collection、Map 与常见实现

`Collection<E>` 是 List/Set/Queue 等的根抽象之一；`Map<K,V>` 不是 Collection，因为它存键值映射。

### ArrayList

- 保持插入顺序、允许重复；
- 按索引读取通常 `O(1)`；
- 尾部追加摊销 `O(1)`；
- 中间插入/删除通常需移动元素 `O(n)`；
- 查找某值通常 `O(n)`。

### LinkedList

知道它是链式 List/Deque 实现即可。“节点插入 O(1)”常忽略先找到位置的 `O(n)`、内存局部性和额外节点开销。没有测量和真实两端需求时，不因面试口号选择它。

### HashSet 与 HashMap

- HashSet 用相等性表达唯一；
- HashMap key 唯一，value可重复；
- 平均查找/插入通常视为 `O(1)`，最坏情况和常数受哈希质量、冲突、容量等影响；
- 业务设计不应依赖它允许 null 的实现细节；
- 不承诺业务排序。

### LinkedHashSet/LinkedHashMap

在哈希语义上额外维护可预测的迭代顺序，适合“首次出现顺序去重”和稳定内存展示。顺序语义必须写入契约，而不是偶然观察 HashMap 输出。

### TreeSet/TreeMap

基于自然顺序或 Comparator 组织，操作通常 `O(log n)`。若比较器认为两个元素比较结果为 0，TreeSet 会把它们当成同一个排序位置；若这与 equals 不一致，调用方会困惑。

### ArrayDeque

适合栈/队列两端操作，业务代码优先 `Deque` 抽象，不使用旧 `Stack`。不要把 null 当队列哨兵。

## 3. 迭代与结构修改

- 增强 for：顺序读取清楚；
- Iterator：需要受控遍历删除时使用其 `remove`；
- 下标循环：需要位置或双指针；
- 遍历集合时直接结构修改可能触发 fail-fast 异常；
- fail-fast 是尽早发现某类错误的实现行为，不是线程安全承诺。

空集合通常优于返回 null：调用方可以直接遍历。但“空”与“无权限/查询失败”不能都用空集合掩盖，错误契约后续单独表达。

## 4. 不可变工厂、只读视图与快照

三个概念必须区分：

### `List.of(...)`

创建不可修改集合，不接受某些无效元素（如 null，具体看 API）。元素对象自身未必不可变。

### `Collections.unmodifiableList(source)`

返回禁止调用方通过该视图修改的包装，但若其他代码仍持有 `source` 并修改，视图会看到变化。它是只读视图，不自动成为时间点快照。

### `List.copyOf(source)`

创建不与源容器共享结构的不可修改结果。之后增删 source 不改变结果；元素引用仍可能指向同一可变实体，所以是**结构快照**，不是对象深拷贝。

嵌套 `Map<K,List<V>>` 要逐层冻结：只冻结外层 Map，内层 List 仍可改；只冻结内层但复用外层也会泄漏。

## 5. 泛型解决什么

泛型把“元素类型”变成编译期参数：

```java
List<WorkOrder> orders;
PageResult<Equipment> page;
RepositoryResult<WorkOrderId, WorkOrder> result; // 只有真实价值时才这样设计
```

收益：减少强转、在编译期发现混入错误类型、复用真正相同的算法/容器。

### raw type 风险

`List orders` 丢失元素类型信息，可能在运行时才发生 `ClassCastException`。新代码禁止 raw type；与旧 API 交互时把不安全边界局部化并记录。

### 泛型不协变

即使 `Technician` 是 `User`，`List<Technician>` 也不是 `List<User>`。否则若允许把一个普通 User 加进后者，原技师列表的类型承诺被破坏。

### 通配符和 PECS

- `? extends T`：把集合视为 T 的生产者，安全读取为 T，但通常不能加入具体 T；
- `? super T`：把集合视为 T 的消费者，可加入 T，读取只保证 Object；
- PECS：Producer Extends, Consumer Super；
- `List<?>` 表示未知元素类型，不等于 `List<Object>`。

只在 API 真正需要接受一族相关类型时使用通配符。内部简单方法不要堆叠通配符显示“高级”。

### 泛型方法与类

`PageResult<T>` 适合因为页内容类型变化而结构完全相同。`<T> List<T> snapshot(...)` 是泛型方法。不要为设备/工单所有操作提前创建万能 Repository；它们的业务查询和重复规则会分化。

## 6. 类型擦除的高层影响

Java 泛型大多通过类型擦除实现，编译后并非为每个 T 复制一套类。高层限制：

- 不能直接 `new T()`；
- 不能直接创建 `new T[]`；
- 运行时通常不能用 `instanceof List<String>` 区分元素参数；
- static 成员不属于某个具体 T；
- 某些重载因擦除后签名相同而冲突。

不要求背编译器 bridge method。本周能解释“编译期类型安全不等于运行时保存所有类型参数”即可。

## 7. `==`、equals 与 hashCode

### 两种相等

- `==` 对引用类型比较是否为同一引用目标；
- `equals` 表达类型定义的逻辑相等；
- Object 默认 equals 与身份相近；record 按每个组件自身的 `equals/hashCode` 语义生成相等性，数组组件仍是身份相等而不是深度元素比较；
- FactoryCare Value Object 由规范值相等；Entity 通常由稳定 id 相等。

### equals 契约

应满足：

- 自反：`x.equals(x)`；
- 对称：x等于y，则y等于x；
- 传递：x=y、y=z，则x=z；
- 一致：相关状态不变时多次结果一致；
- 对非null返回false。

### hashCode 契约

- equals 相等的对象必须有相同 hashCode；
- hashCode 相同不代表 equals 相等，碰撞合法；
- 重写 equals 必须同步重写 hashCode；
- 参与 equals/hashCode 的值在对象作为哈希 key/元素期间不应改变。

### HashMap/HashSet 高层查询

1. 计算 key 的 hash；
2. 定位候选区域；
3. 在候选中用 equals 确认真正 key。

若保存后改变参与 hash 的字段，新的 hash 可能定位到另一处，即使对象还在容器里也“找不到”。这不是 HashMap 丢数据，而是 key 违反契约。

## 8. Entity 相等性策略

FactoryCare 的 `Equipment` 和 `WorkOrder` 已有应用生成的稳定 ID，因此本周可以把实体相等定义为：同一具体类型且 id 相等。为降低继承下的对称性复杂度，实体类当前为 final。

不要把名称、描述、优先级、状态等可变业务字段加入 hashCode。工单从 `CREATED` 变化后仍是同一个工单，HashMap 按 id 查询应保持稳定。

若未来 ORM 生成 id、代理类型或持久化前无 id，策略会更复杂；本周尚无 ORM，不假装已经解决该问题。

## 9. Comparable 与 Comparator

- `Comparable<T>` 表达一个稳定自然顺序；
- `Comparator<T>` 表达外部、多种场景排序；
- FactoryCare 工单有“按优先级”“按创建顺序”等多种视图，优先使用 Comparator；
- Comparator 可用 `comparing`、`thenComparing`、`reversed` 组合；
- 比较结果要稳定、传递；
- 展示排序不改变 equals。

Priority 排序不能依赖 enum ordinal，因为声明顺序不是对外业务契约。给 Priority 明确 rank，或用显式映射。

### 稳定排序

若两个工单优先级相同，需要保持创建顺序。Java List 的标准排序具有稳定性承诺时仍应读对应 API 文档；也可显式添加创建序号作为 tie-breaker。本周没有真实时间字段，可由仓储插入顺序或测试序号表示。

## 10. 仓储接口是领域需要，不是 Map 外壳

仓储隐藏保存与查找机制，接口命名表达领域用例：

- `save` 的重复 id 是拒绝、覆盖还是更新？必须定义；
- 设备编码是否唯一？由哪个边界检查？
- 查询不存在返回 Optional、null 还是异常？本周可用 Optional 预告“可能不存在”，不系统深入；
- `findAll` 返回结构快照，不能暴露内部 Map；
- 不把 `Map` getter 暴露给调用方自行查询。

不要创建万能 `BaseRepository<T,ID>`：设备有按 code 判断，工单有按状态/优先级查询，过早统一会把业务方法退化成通用查询 DSL。

## 11. 本周仓储契约建议

- `save` 只接受新实体，重复 id 明确抛错；
- Equipment 还拒绝重复 code；
- `findById` 返回 `Optional<T>`；
- `findAll` 返回插入顺序的不可修改结构快照；
- 仓储不是线程安全的；
- 实体元素本身若可变，快照不保证深拷贝；
- 数据库语义、事务和更新留到后续。

这是学习阶段契约，不是声称所有仓储都应如此。

## 12. 双指针算法

双指针不是固定模板，而是用两个位置利用输入结构，避免重复扫描。常见前提：有序数组、窗口、原地压缩或从两端逼近。

### 有序数组原地去重

- `read` 扫描每个元素；
- `write` 指向下一个唯一值应写入的位置；
- 不变量：`[0, write)` 已经是已处理前缀的唯一有序值；
- 时间 `O(n)`，额外空间 `O(1)`；
- 结果通常返回有效长度，数组尾部旧值不再有意义。

若输入未排序，这个算法不能保证去重。不能省略前提，也不能为了使用双指针先排序却忘记排序的 `O(n log n)` 和顺序变化。

## 常见错误

- 用 HashMap 却依赖观察到的迭代顺序；
- 认为 LinkedList 任意插入总是 O(1)；
- 把 `unmodifiableList` 当时间点快照；
- 外层不可变但内层 List 可改；
- 使用 raw type 或无意义强转；
- 误认为 `List<Child>` 是 `List<Parent>`；
- 重写 equals 未重写 hashCode；
- 把可变状态放入实体 hashCode；
- Comparator 用 ordinal，或比较为0但equals不同却未意识；
- 仓储返回内部 `values()` 视图；
- 将 `VERIFIED` 误当 `CLOSED`，或新增词表之外的状态；
- 未排序输入硬套有序双指针。

## 官方资料

- [Java Collections Framework](https://docs.oracle.com/en/java/javase/25/core/java-collections-framework.html)
- [java.util API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/package-summary.html)
- [Java Generics Tutorial](https://docs.oracle.com/javase/tutorial/java/generics/)
- [Object.equals/hashCode](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Object.html)
- [Comparator API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Comparator.html)
- [List API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/List.html)
- [Map API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Map.html)
- [JUnit User Guide](https://docs.junit.org/current/user-guide/)

继续完成[实验](./labs.md)。
