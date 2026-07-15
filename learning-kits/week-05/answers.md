# Week 05 独立答案册

> **警告：考前勿看。** 以下只是一种参考实现。先完成[无 AI 考核](./assessment.md)，再用失败测试和契约比较，而不是逐字符替换。

## A. 集合选择

一种合理分解：

1. `LinkedHashMap<WorkOrderId, WorkOrder>`：`putIfAbsent` 按 id 去重并保留首次出现顺序；
2. `LinkedHashMap<EquipmentId, List<WorkOrder>>`：按设备分组并保留设备首次出现顺序；
3. 每组使用 `ArrayList` 追加，保持工单顺序；
4. 冻结时每个 List 使用 `List.copyOf`；
5. 把冻结后的条目放入一个新 LinkedHashMap，再用不可修改 Map 包装。

平均情况下去重和分组为 `O(n)`；冻结也遍历一次，总体 `O(n)` 时间，返回结果本身占 `O(n)` 空间。哈希最坏情况不能笼统保证常数，但无需背实现树化细节。

TreeMap 会按 key 排序而非首次出现；普通 HashMap 不承诺本题顺序；嵌套 List 每次扫描查重复容易到 `O(n²)`。

## B. 参考实现

```java
package com.factorycare.workorder;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class OpenWorkOrderIndex {
    public Map<EquipmentId, List<WorkOrder>> build(List<WorkOrder> input) {
        if (input == null) {
            throw new IllegalArgumentException("input must not be null");
        }

        var firstById = new LinkedHashMap<WorkOrderId, WorkOrder>();
        for (WorkOrder order : input) {
            validate(order);
            firstById.putIfAbsent(order.id(), order);
        }

        var mutableGroups = new LinkedHashMap<EquipmentId, List<WorkOrder>>();
        for (WorkOrder order : firstById.values()) {
            if (isClosed(order.status())) {
                continue;
            }
            mutableGroups
                    .computeIfAbsent(order.equipmentId(), ignored -> new ArrayList<>())
                    .add(order);
        }

        var snapshot = new LinkedHashMap<EquipmentId, List<WorkOrder>>();
        for (var entry : mutableGroups.entrySet()) {
            snapshot.put(entry.getKey(), List.copyOf(entry.getValue()));
        }
        return Collections.unmodifiableMap(snapshot);
    }

    private boolean isClosed(WorkOrderStatus status) {
        return status == WorkOrderStatus.CLOSED
                || status == WorkOrderStatus.CANCELLED;
    }

    private void validate(WorkOrder order) {
        if (order == null) {
            throw new IllegalArgumentException("work order must not be null");
        }
        if (order.id() == null || order.equipmentId() == null || order.status() == null) {
            throw new IllegalArgumentException(
                    "work order id, equipment id and status must not be null");
        }
    }
}
```

注意：示例沿用 `WorkOrder` 以便突出集合逻辑；若你的实体只能从 `CREATED` 合法创建，就把相同算法应用到只读 `WorkOrderSnapshot`，测试中的其他状态只代表已有样本。不要为了让示例编译而加入 public `setStatus`。返回 Map 包装的是新建的 `snapshot`，方法外没有其他可变引用；每个 value 又是 `List.copyOf`。WorkOrder 对象本身仍共享，这是题目明确接受的结构快照。

另一种实现可用 LinkedHashSet 保存 seen ids 并直接分组，只要 null 校验、首次顺序和冻结仍正确。上面两阶段更易解释和测试。

## C. 测试关键点

- 两个相同 id、不同后续内容时保留第一项；
- 第一个设备A、第二个B、第三个A，外层顺序为A/B，A组内保留首次顺序；
- `CLOSED` 与 `CANCELLED` 被排除；
- `VERIFIED`、`RESOLVED` 等仍保留，因为它们尚未 `CLOSED`；
- `result.put(...)` 抛 `UnsupportedOperationException`；
- `result.get(id).add(...)` 也抛；
- 之后修改输入 List 的结构不会改变结果；
- 空输入返回空且不可修改；
- null元素/关键字段按契约拒绝。

不要测试 HashMap 某次运行“刚好乱序”来证明错误；正确证据是它的 API 不承诺首次顺序，因此实现选择与契约不匹配。可执行测试应针对所选 LinkedHashMap 的预期顺序。

## D. 可变 key 故障

错误示意：

```java
final class MutableKey {
    String value;

    MutableKey(String value) { this.value = value; }

    @Override
    public boolean equals(Object other) {
        return other instanceof MutableKey key && value.equals(key.value);
    }

    @Override
    public int hashCode() { return value.hashCode(); }
}
```

放入 Map 后改变 `value`，查询会用新 hash 定位，与保存位置不一致。正确做法不是每次遍历全 Map，而是让 key 不可变，实体 hash 只使用稳定 id。

final Entity 基于 id 的示意：

```java
@Override
public boolean equals(Object other) {
    if (this == other) return true;
    if (!(other instanceof WorkOrder that)) return false;
    return id.equals(that.id);
}

@Override
public int hashCode() {
    return id.hashCode();
}
```

前提是 id 创建时非 null、稳定且 WorkOrder 为 final；未来 ORM 代理/id生成策略需要重新评估，不能把此例宣称为所有项目通解。

## E. 双指针参考

```java
public static int deduplicateSorted(int[] values) {
    if (values == null) {
        throw new IllegalArgumentException("values must not be null");
    }
    if (values.length == 0) {
        return 0;
    }

    int write = 1;
    for (int read = 1; read < values.length; read++) {
        if (values[read] != values[write - 1]) {
            values[write] = values[read];
            write++;
        }
    }
    return write;
}
```

不变量：每次迭代前 `[0, write)` 是已处理前缀的有序唯一值，最后一个唯一值在 `write-1`。时间 `O(n)`，额外空间 `O(1)`，会修改输入。只验证 `[0, returnedLength)`；尾部是无意义旧数据。

该实现假定输入已排序。若需要验证排序，可额外一次扫描，但要把失败策略写入契约；题目本身不要求。

## F. 泛型和快照口述校准

- `List<Child>` 不是 `List<Parent>`，否则可加入非Child破坏类型承诺；
- `? extends T` 适合读取生产者，`? super T` 适合写入消费者；
- 擦除导致不能 `new T()`、不能区分 `instanceof List<String>`；
- `unmodifiableList(source)` 会反映source后续结构变化；`List.copyOf`是结构快照；两者都不深拷贝元素；
- Comparable是类型自然顺序，Comparator是外部场景顺序；
- 设备与工单仓储业务方法不同，过早BaseRepository会泄漏通用CRUD并压平规则。

## 常见错误

- `Map.copyOf` 后假定必然保留 LinkedHashMap 迭代顺序；若顺序是契约，应选择有明确顺序保证的返回策略并测试；
- 只把外层 Map 设为不可修改；
- 先过滤再去重，导致重复第一项已关闭、第二项未关闭时语义变成“保留后项”，违反先去重契约；
- 用 `status != CLOSED`，忘记 `CANCELLED`；
- 误排除 `VERIFIED`；
- raw type 让错误推迟到运行时；
- 双指针返回 `write-1` 或断言数组整个尾部；
- equals 使用可变 status/description。

## 面试校准

> 先提交[面试题](./interview.md)的独立回答再阅读。以下答案要连接本周真实集合、仓储和故障实验。

1. **List/Set/Map**：List 表达顺序和可重复，Set 表达唯一，Map 按唯一 key 映射值。首次出现顺序去重使用 LinkedHashSet 或 LinkedHashMap，并把顺序写进契约。
2. **ArrayList/LinkedList**：ArrayList 适合索引和尾部摊销追加；LinkedList 是节点结构。即使节点插入本身 O(1)，按位置找到节点仍 O(n)，还要考虑节点内存和局部性，不能只背口号。
3. **Deque/Stack**：Deque 同时表达栈、队列和双端操作，ArrayDeque 通常优先；Stack 是旧类。队列不要用 null 充当哨兵。
4. **HashMap 顺序**：不承诺业务迭代顺序；当前实现和数据使输出稳定也不是 API 契约。需要插入顺序用 LinkedHashMap，需要业务排序则显式 Comparator。
5. **HashMap 查询**：先由 hash 定位候选区域，再用 equals 区分真实 key。碰撞合法，不同对象可拥有相同 hashCode。
6. **equals/hashCode 契约**：equals 自反、对称、传递、一致，对 null 为 false；equals 相等的对象必须有相同 hashCode，否则哈希容器可能从不同区域寻找。
7. **可变 key**：参与 hash 的字段变化后，新 hash 与原保存位置不一致。优先使用不可变 WorkOrderId；即使 final WorkOrder 仅按稳定 id 计算 hash 理论可用，专门 id 类型仍更清晰且避免携带实体。
8. **Entity 相等**：当前应用生成稳定 id 且实体 final，可按同一类型与 id；不含描述、状态等可变字段。ORM 生成 id、代理类型和持久化前无 id 会改变问题，本阶段不能泛化答案。
9. **泛型/raw**：泛型提供编译期元素约束并减少强转；raw type 丢失检查，错误推迟到运行时。类型擦除意味着运行时通常没有完整参数信息。
10. **不协变**：若 List<Dog> 可当 List<Animal>，调用方就能加入 Cat，破坏原列表承诺。只读生产者使用 `List<? extends Animal>`。
11. **PECS**：Producer Extends, Consumer Super。`? super WorkOrder` 可安全加入 WorkOrder，但读取的静态类型只保证 Object。
12. **擦除限制**：通常不能直接 `new T()`、`new T[]` 或用 `instanceof List<String>` 区分元素参数；某些重载也会因擦除冲突。不必背 bridge method 源码。
13. **视图/快照**：`unmodifiableList(source)` 是不可通过包装修改的视图，会反映 source 后续变化；`List.copyOf(source)` 是结构快照。两者都不深拷贝元素对象。
14. **Comparable/Comparator**：Comparable 定义类型的一个自然顺序，Comparator 定义外部场景顺序。工单有优先级、时间等多种视图，使用 Comparator 避免把展示顺序绑进实体。
15. **Priority 排序**：ordinal 会随声明顺序改变。使用显式业务 rank 或映射并写排序契约测试，code 负责外部稳定值而不是自动等于 rank。
16. **仓储返回**：内部 Map 或 `values()` 通常是联动视图，调用方可绕过重复检查和规则修改内部状态。返回独立不可修改结构快照，并暴露有领域含义的查询。
17. **BaseRepository**：设备编码唯一、工单状态查询等规则不同，过早抽象会压平领域并暴露通用 CRUD。重复模式稳定且语义相同时再提取，不因几行 Map 代码先统一。
18. **双指针**：有序输入是原地去重前提；read/write 维护唯一前缀。无序时可用 Set 保首次顺序，或先排序，但会改变额外空间、总复杂度、原顺序和输入修改语义。
19. **未关闭**：统一定义为 WorkOrderStatus 既不是 CLOSED 也不是 CANCELLED；VERIFIED 尚未进入 CLOSED，因此仍保留。不能创造近义状态或在 Week 07 重新发明定义。
20. **快照保证**：证明调用方不能增删返回结构，且结果不共享仓储内部容器；元素仍可能共享引用。它不证明线程安全、事务、持久化或合法状态流转，这些均尚未实现。
