# 第 5 周：集合、泛型与 equals/hashCode

## 定位

本周解决“多个对象如何组织、查找、去重、排序和复用类型安全代码”。重点不是背集合 API，而是根据业务语义选择结构，并保证对象相等性不会破坏 Set、Map 和仓储行为。

时间预算：15—18 小时。FactoryCare 将获得可替换的内存仓储，为后续 Spring DI 和数据库持久化保留清晰接口。

## 前置

- 能使用 class、record、enum、interface 和 Value Object 建模。
- FactoryCare 的设备、工单、优先级和状态模型测试通过。
- 能解释 Entity 身份和值对象相等性。
- 本周不使用 Stream 完成主要练习；先掌握集合和显式循环。

## 目标

- 根据顺序、重复、查找、队列和排序需求选择集合。
- 理解泛型带来的编译期类型安全、类型擦除和基本边界。
- 正确实现并验证 `equals/hashCode` 契约。
- 理解可变对象作为 HashMap key/HashSet 元素的风险。
- 使用 Comparator 表达不同排序规则。
- 为 FactoryCare 建立内存仓储和查询服务。

## 完整概念清单

### 集合抽象与选择

- `Collection`、`List`、`Set`、`Queue`、`Deque`、`Map` 的职责。
- `ArrayList`：顺序、随机访问、尾部追加和中间移动成本。
- `LinkedList` 了解存在即可；不要因“插入快”在缺乏测量时选择。
- `HashSet`：基于相等性去重，不保证业务排序。
- `LinkedHashSet/LinkedHashMap`：保留迭代顺序的场景。
- `TreeSet/TreeMap`：基于排序比较，比较结果与 equals 一致性风险。
- `HashMap`：key 唯一、value 可重复、`null` 能力不应成为业务设计依据。
- `ArrayDeque`：栈和队列；业务代码优先 `Deque` 而不是旧 `Stack`。
- 常见操作的平均复杂度只作为选择参考，不背实现源码。

### 迭代、修改和边界

- 增强 for、Iterator、下标循环的适用场景。
- 遍历时结构修改与 fail-fast；fail-fast 不是线程安全保证。
- 空集合优于返回 `null`。
- `List.of/Set.of/Map.of` 的不可变工厂。
- `Collections.unmodifiableX` 是只读视图，不等于底层数据不可变。
- 防御性复制与 `List.copyOf`。
- `contains`、去重和查找结果依赖正确相等性。

### 泛型

- 泛型类、泛型接口、泛型方法和类型参数命名。
- 原始类型会丢失类型安全，禁止在新代码中使用 raw type。
- 泛型不协变：`List<Dog>` 不是 `List<Animal>`。
- 上界 `? extends T`、下界 `? super T` 和 PECS 的直觉用法。
- 无界通配符 `?` 与 `Object` 的区别。
- 类型擦除的高层含义；不能 `new T()`、不能创建泛型数组等常见限制。
- 不为了“通用”创建难以理解的多层泛型抽象。

### equals/hashCode

- `==` 比较引用身份，`equals` 表达逻辑相等。
- equals 的自反、对称、传递、一致和非 null 契约。
- 相等对象必须有相同 hashCode；不同对象允许哈希碰撞。
- HashMap/HashSet 先使用哈希定位，再使用相等性确认的高层流程。
- record 默认基于全部组件生成相等性。
- Entity 的相等性通常基于稳定身份；可变业务字段不应进入 hash key。
- 重写 equals 必须同步重写 hashCode。
- 作为 Map key/Set 元素后修改参与相等性的字段会导致“找不到对象”。

### 排序

- `Comparable` 表达单一自然顺序，`Comparator` 表达外部多种排序。
- 比较器组合、升降序、null 排序策略。
- 比较函数必须稳定并满足比较契约。
- 排序展示规则不应改变对象相等性。

### 仓储与查询

- 仓储接口表达领域需要，而不是暴露底层 Map。
- `Optional` 只作为查询缺失的预告，本周暂不系统学习。
- 保存、按 ID 查询、存在性检查、列出快照和删除的边界。
- 内存仓储也要防止外部修改内部集合。

## 任务分配

| 模块 | 时间 | 任务 |
| --- | ---: | --- |
| 集合选择 | 3h | List/Set/Map/Deque 对照练习和复杂度判断 |
| 泛型 | 2.5h | 泛型仓储、小型分页容器和通配符练习 |
| 相等性 | 2.5h | equals/hashCode、HashSet/HashMap 故障实验 |
| 排序与快照 | 1.5h | 多条件 Comparator、防御性复制 |
| FactoryCare | 3—4h | 内存设备/工单仓储与查询服务 |
| 无 AI 训练 | 2h | 去重和查询变体 |
| 求职动作 | 1h | 集合与泛型高频题口述 |

## FactoryCare项目增量

实现以下接口与内存实现：

- `EquipmentRepository`：保存、按 `EquipmentId` 查询、判断编码是否存在、列出设备快照。
- `WorkOrderRepository`：保存、按 `WorkOrderId` 查询、列出全部工单。
- `InMemoryEquipmentRepository`、`InMemoryWorkOrderRepository`：内部可使用 Map，但不得直接返回内部可变集合。
- `PageResult<T>` 或轻量查询结果：验证泛型类的实际价值，不实现完整分页框架。
- 工单排序：优先级降序、创建顺序稳定排序；真实时间字段留到第 6 周。

必须验证：重复 ID、重复设备编码、查询不存在、保存后外部集合修改、相同 Value Object 去重，以及实体字段变化不破坏仓储查找。

## AI协作边界

可以让 AI：

- 根据访问模式提出 List、Set、Map 的候选选择。
- 生成复杂度和边界测试清单。
- 审查泛型签名是否过度抽象。
- 构造一个违反 equals/hashCode 契约的反例供你调试。

必须由你完成：

- 先说明业务需要的是顺序、唯一、按 key 查找还是队列。
- 决定 Entity 和 Value Object 的相等语义。
- 解释仓储为何不能暴露内部可变集合。
- 独立定位 AI 生成代码中 raw type、错误通配符和可变 key 问题。

## 无AI训练

本周从求职/复盘时段预留45—60分钟完成并记录：双指针题；给出循环不变量、边界测试和复杂度。

关闭 AI，限时120分钟：

1. 实现“按设备 ID 分组的未关闭工单索引”，使用恰当的 Map/List 组合。
2. 去除重复工单 ID，保持首次出现顺序。
3. 返回不可被调用方修改的结果快照。
4. 补齐重复、空集合、不存在和排序相同优先级的测试。
5. 口述 HashMap 查询的高层步骤及错误 hashCode 的后果。

## 求职动作（恢复求职后启用）

- 准备 List、Set、Map、ArrayList/LinkedList、HashMap、泛型擦除、PECS、equals/hashCode 的口述答案。
- 每个答案必须结合 FactoryCare 代码，不背源码扩容常量。
- 从目标岗位中记录是否明确要求数据结构与算法；若要求，仅建立后续基础题清单，不偏离本周。
- 更新项目周报：描述内存仓储的业务边界，不把它包装成数据库经验。

## 交付物

- 设备和工单仓储接口及内存实现。
- 泛型查询结果或分页结果的小型实现。
- 集合选择决策表与复杂度速查表。
- equals/hashCode 正反例及对应测试。
- 无 AI 训练代码和复盘。

## 验收标准

- 面对访问需求能说明为何选 List、Set、Map 或 Deque。
- 能解释泛型不协变、PECS 和类型擦除的高层影响。
- 能陈述 equals/hashCode 契约并用失败测试演示破坏后果。
- 内存仓储不暴露内部可变 Map/List；重复 ID 行为明确。
- 能使用 Comparator 实现稳定多条件排序。
- 所有测试通过，无 raw type 和无业务理由的强制类型转换。
- 无 AI 完成分组、去重、快照和边界测试。

## 明确不做

- 不学习 HashMap 红黑树、扩容源码和集合微优化。
- 不使用 Stream/parallelStream 代替本周核心循环；第 7 周系统学习。
- 不实现数据库、缓存、线程安全仓储或 Spring Bean。
- 不创建“万能 BaseRepository<T, ID>”和多层抽象。
- 不刷大量竞赛算法题。

## 官方资料

- [Java Collections Framework](https://docs.oracle.com/en/java/javase/25/core/java-collections-framework.html)
- [Java SE 25：java.util](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/package-summary.html)
- [Java Tutorials：Generics](https://docs.oracle.com/javase/tutorial/java/generics/)
- [Object.equals/hashCode API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Object.html)
- [Comparator API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Comparator.html)
- [JUnit User Guide](https://docs.junit.org/current/user-guide/)
