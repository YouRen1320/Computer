# Week 03 面试训练

## 使用方式

每题 60—90 秒，先说业务访问模式，再谈实现和复杂度；涉及 FactoryCare 状态时只使用唯一词表。保存整轮回答后，再查看[答案册的面试校准](./answers.md#面试校准)。

## 集合选择

### 1. List、Set、Map 如何选择？

追问：按首次出现顺序去重选什么？

### 2. ArrayList 和 LinkedList 有何区别？

追问：LinkedList 中间插入一定更快吗？

### 3. 为什么队列优先用 ArrayDeque 而不是 Stack？

追问：Deque 能表达哪些栈、队列和双端操作？

### 4. HashMap 是否有序？

追问：本机输出稳定为何仍不能依赖？

## equals/hashCode

### 5. HashMap 查询的高层过程？

追问：两个 hash 相同怎么办？

### 6. equals 契约有哪些？

追问：重写 equals 为何必须重写 hashCode？

### 7. 可变对象为什么不适合作 Map key？

追问：FactoryCare WorkOrder 能否作为 key，和直接使用 WorkOrderId 相比如何？

### 8. Entity 的 equals 应包含哪些字段？

追问：ORM 生成 id 或代理类型出现时怎么办？

## 泛型

### 9. 泛型解决什么？raw type 有什么问题？

追问：类型安全是否完整保留到运行时？

### 10. 为什么 `List<Dog>` 不是 `List<Animal>`？

追问：怎样只读接受各种 Animal 子类列表？

### 11. PECS 是什么？

追问：从 `? super WorkOrder` 读取出来时，静态类型能保证什么？

### 12. 类型擦除有哪些影响？

追问：能否 `new T()`、`new T[]` 或 `instanceof List<String>`？

## 快照、排序与仓储

### 13. `unmodifiableList` 与 `List.copyOf` 有何区别？

追问：两者会深拷贝 WorkOrder 吗？

### 14. Comparable 与 Comparator 有何区别？

追问：工单优先级排序为何适合 Comparator？

### 15. 为什么排序 Priority 不用 ordinal？

追问：如何替代并验证？

### 16. 仓储为何不能直接返回内部 Map？

追问：返回 `values()` 是否安全？

### 17. 为什么不建万能 BaseRepository？

追问：减少重复代码是否足以成为理由？

## 算法与项目题

### 18. 双指针原地去重的前提是什么？

追问：输入无序时有哪些方案，复杂度和顺序语义如何变化？

### 19. “未关闭”在 FactoryCare 中是什么？

追问：VERIFIED 算关闭吗？

### 20. 你的仓储快照证明了什么，没证明什么？

追问：它能否证明线程安全、事务或持久化？

## 提交与校准

保存回答、集合契约/失败测试引用和未验证项后，再打开[面试校准](./answers.md#面试校准)。提前查看时，本轮只能作为练习。

## 自评分

每题 0—3 分，共 60。45 分以上，且第 6、10、13、16、19 题至少 2 分为通过。若答案背 HashMap 源码常量但说不清 FactoryCare 的顺序与快照，相关题不得超过 1 分。
