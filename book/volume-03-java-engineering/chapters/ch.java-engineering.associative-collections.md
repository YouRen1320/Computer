---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.associative-collections
title: Set、Map、键相等性与哈希契约
responsibility: 教授去重和键值索引及其相等性要求，不在本章展开缓存或数据库索引
volume: '03'
order: 4
level: L1
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.associative-collections.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-engineering.sequential-collections
- ch.java-oop.object-contracts
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
  text: 在 120 秒内解释Set、Map、键相等性与哈希契约的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-set
  - java-map
  covers_topics:
  - java.set-contract
  - java.hashset-equality
  - java.duplicate-element
  - java.map-contract
  - java.hash-key-stability
  - java.missing-key
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.references-objects
  - java.encapsulation-immutability
  - java.collections-generics
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：从保序 List 输入构造 Set 去重 DeviceId、Map 统计类别数量，比较三者顺序/重复/键语义并证明 equals/hashCode 契约
  covers_topic_groups:
  - java-set
  - java-map
  covers_topics:
  - java.set-contract
  - java.hashset-equality
  - java.duplicate-element
  - java.map-contract
  - java.hash-key-stability
  - java.missing-key
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.references-objects
  - java.encapsulation-immutability
  - java.collections-generics
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入误用 List 查重、可变字段参与 hash、只覆写 equals 和把 null/缺失混同，复现成本或查找失败后修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - java-set
  - java-map
  covers_topics:
  - java.set-contract
  - java.hashset-equality
  - java.duplicate-element
  - java.map-contract
  - java.hash-key-stability
  - java.missing-key
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.references-objects
  - java.encapsulation-immutability
  - java.collections-generics
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Set、Map、键相等性与哈希契约

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《List、Queue、Deque 与迭代》](ch.java-engineering.sequential-collections.md)：独立完成Set 去重契约、Map 键值契约前，必须先具备「List、Queue、Deque 与迭代」已经验证的知识与失败边界
- [《equals、hashCode 与 toString 直接契约》](../../volume-02-java-objects/chapters/ch.java-oop.object-contracts.md)：独立完成Set 去重契约、Map 键值契约前，必须先具备「equals、hashCode 与 toString 直接契约」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套自动化只证明固定 Java 25 输入下的集合合同与故障预言；P9 的零基础试读、人工版式/无障碍检查、独立全面审查和全仓回归尚未执行，因此不能把本章称为 `verified`，也不会修改 `PROGRESS.md`。

上一章的 List 能忠实保留 `PUMP-01, PUMP-02, PUMP-01` 三次输入，但它不会回答“这是不是同一台设备”，也不会快速回答“PUMP-02 当前对应哪张工单”。如果每次加入前都遍历 List 查重，或者每次查询都从头扫描，代码可能在小样例中正确，却随着数据规模形成平方级工作。

`Set<E>` 表达“一组按相等性不重复的元素”，`Map<K,V>` 表达“每个键最多关联一个值”。哈希实现先用 `hashCode` 缩小候选范围，再用 `equals` 确认逻辑相等；因此对象合同不是装饰，而是索引正确性的组成部分。最典型故障是键加入 HashMap 后改变了参与 hash 的字段：对象明明还在内部，却从新 hash 指向的桶里找不到。

本章从零解释 Set/Map 合同、HashSet/HashMap 机制与复杂度、相等键、重复输入、缺失键、null 歧义、键稳定性、LinkedHashMap 的 encounter order，以及 TreeSet/TreeMap 中排序与相等性的边界。不展开缓存淘汰、数据库索引、并发 Map 或通用排序算法。基线是 **JDK 25**，官方资料复核日期为 **2026-07-16**。

## 1. 完成标准：用结果证明，不靠“看懂了”

你需要形成以下证据：

1. 120 秒解释 List、Set、Map 的数据形状；说明 HashMap 查找为什么同时需要 hashCode 和 equals，并给出一个可变键失联反例。
2. 从保序 List 构造 Set 去重 DeviceId、用 Map 统计设备类别数量；证明相等但非同一引用的键能命中同一映射。
3. 分别测试重复元素、重复键覆盖、缺失键、显式 null 值、稳定 encounter order、排序比较为 0 的边界。
4. 复现并修复四类故障：用 List 做大规模查重、equals/hashCode 不一致、键入表后变异、把 `get == null` 直接解释为“没有键”。
5. 公开练习先得到确定的 `STARTER EXPECTED FAILURE`，修复后再得到 `EXERCISE PASS`；私有解只在独立尝试后查阅。

配套工件：

- [关联集合观察示例](../../../examples/encyclopedia/ch.java-engineering.associative-collections/README.md)
- [FactoryCare 设备索引实验](../../../labs/encyclopedia/ch.java-engineering.associative-collections/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.associative-collections/README.md)

## 2. 三种数据形状：序列、集合、映射

List 是序列：每次出现都占一个位置，重复有意义。Set 是集合：只关心某个逻辑元素是否属于其中，不允许按集合相等性重复。Map 是映射：键不重复，每个键指向一个当前值；值可以相同，键和值承担不同角色。

用数学直觉可以帮助区分，但 Java API 是可执行合同。Set 的 `add(e)` 返回 true 表示集合因此改变；加入相等元素通常返回 false，size 不增加。Map 的 `put(k, v)` 若键不存在会新增映射；若已有相等键，会替换对应值并返回旧值。它不是把相同键保留两份。

选择错误会把业务含义藏在循环中。若“设备编号必须唯一”，Set 比 `if (!list.contains(id)) list.add(id)` 更直接；若“编号映射到设备详情”，Map 比两条位置同步的 List 更安全。若确实要保存每次扫描事件，包括重复事件，则 List 才是正确合同，不能因为 Set 查找快就丢掉审计事实。

泛型参数也反映角色：`Set<DeviceId>` 只有元素类型 E；`Map<DeviceId, WorkOrder>` 同时声明键 K 和值 V。键应是稳定身份，值可以是会更新的业务状态。不要把整个可变实体塞进键，只因为它“字段比较齐全”。

## 3. Set 合同：不重复不等于自动整理数据

Set 判断“已经存在”依赖实现采用的相等关系。HashSet 使用 equals/hashCode；TreeSet 使用自然顺序或 Comparator 的比较结果来确定元素位置和等价类。两个结构都不允许重复，但“重复”的判定路径不完全相同。

`add` 的 boolean 很有价值：

```java
boolean firstSeen = deviceIds.add(new DeviceId("PUMP-01"));
if (!firstSeen) {
    // 显式处理重复扫描，而不是静默吞掉业务事实
}
```

Set 去重只保留一个代表元素，不会自动合并重复对象的其他字段，也不会告诉你重复了多少次。若需要频次，使用 Map 计数；若需要全部原始记录，先保留 List，再派生 Set。数据清洗时经常同时需要三者：List 是事实输入，Set 是唯一标识，Map 是汇总。

`Set.of` 创建不可修改 Set，拒绝 null，也拒绝重复实参；其迭代顺序未指定且可能变化。不要把当前输出顺序当稳定合同。`Set.copyOf(collection)` 返回不可修改 Set；如果输入含重复元素，它会保留每个等价类的一个代表，但具体选择和顺序不应被业务依赖。

## 4. Map 合同：键唯一，值不是

Map 的核心问题是“给定 K，当前 V 是什么”。常见 API：

| 意图 | API | 关键边界 |
| --- | --- | --- |
| 写入/覆盖 | `put(k, v)` | 返回旧值；旧值为 null 仍可能歧义 |
| 仅缺失时写入 | `putIfAbsent(k, v)` | 某些合同把映射到 null 也视作 absent |
| 读取 | `get(k)` | 缺失通常返回 null；也可能是显式 null 值 |
| 判定键存在 | `containsKey(k)` | 区分缺失与映射到 null |
| 提供默认值 | `getOrDefault(k, fallback)` | 不写入 Map，只决定本次返回值 |
| 计数/合并 | `merge(k, one, combiner)` | remapping 返回 null 时可能删除映射 |
| 按需计算 | `computeIfAbsent` | mapping 返回 null 时不记录；函数应可解释 |
| 删除 | `remove(k)`、`remove(k,v)` | 后者要求键和值都匹配 |
| 遍历 | `entrySet()` | 同时用键和值时优于重复 get |

Map 不继承 Collection，因为一条映射同时有键和值，无法自然回答“add 一个什么”。`keySet()`、`values()`、`entrySet()` 是映射的集合视图，通常与原 Map 联动。通过视图迭代器删除会影响原 Map；不是独立快照。

遍历键值对时用 `for (Map.Entry<K,V> entry : map.entrySet())`，避免先遍历 keySet 再每次 `get`。后者对 HashMap 平均也许仍快，但重复表达查找，且难以区分并发/联动变化；entry 已经携带本次映射视图。

## 5. HashMap/HashSet 的直觉机制：桶、hash 与 equals

可以把哈希表想成许多桶。写入键时先计算 `hashCode`，经实现的扩散和容量映射选择候选桶；桶里可能已有其他键，于是再用 `equals` 区分真正相等与哈希碰撞。读取时必须重复相同路线：当前键的 hash 导向相同候选位置，再用 equals 找到匹配。

这说明三条关键事实：

1. 两个 equals 为 true 的对象必须产生相同 hashCode，否则它们可能被送进不同桶，Set 会同时保留，Map 会把它们当两把键。
2. 相同 hashCode 不要求 equals 为 true。碰撞是允许的，容器会继续比较 equals；只是碰撞太多会降低性能。
3. 对象作为键留在 Map/Set 期间，参与 equals/hashCode 的信息必须稳定。否则读取用新 hash 去新桶，而对象仍挂在旧位置。

HashSet 的机制通常借助哈希映射保存元素，但代码不要依赖内部私有表示。业务合同是唯一性、contains/add/remove 的行为；实现如何树化冲突桶、何时扩容属于可变细节，除非官方明确承诺，否则不写进测试。

## 6. equals 与 hashCode：一条正确性合同，不是性能小技巧

Object 官方合同要求 equals 是自反、对称、传递、一致，并且非 null 对象与 null 不相等。hashCode 要求：只要 equals 所用信息未变，同一次执行期间重复调用保持一致；若两个对象 equals 为 true，它们的 hashCode 必须相同。反向不成立，不相等对象可以碰撞。

只覆写 equals 不覆写 hashCode，List 中 `contains` 可能表现正常，因为它线性调用 equals；一换 HashSet/HashMap 就出现重复或查找失败。这种“List 测试通过”正是危险信号。对象合同测试必须同时验证相等实例 hash 相同，并在实际 HashSet/HashMap 中验证查找。

最适合作为业务键的是不可变值对象，例如：

```java
record DeviceId(String value) {
    DeviceId {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("device id is required");
        }
    }
}
```

record 会根据组件生成 equals/hashCode，组件又是 final 引用。若组件指向可变集合，仍可能间接变化，所以“record”不自动等于深度不可变。DeviceId 使用不可变 String，更适合稳定键。

实体的显示名、位置、在线状态会改变，不适合参与身份键。让 `Device` 整体作为键并按所有字段生成 equals/hashCode，任何业务更新都可能让键失联。更清晰的是 Map 以 DeviceId 为键，Device 为值：身份稳定，状态可更新。

## 7. 可变键失联是怎样发生的

考虑一个键的 hash 由 `site` 与 `code` 组成。put 时 site=`A`，对象进入桶 3；之后把 site 改成 `B`，新的 hash 映射到桶 9。调用 `map.get(sameReference)` 也会从桶 9 开始，找不到仍在桶 3 的条目。相同引用并不能绕过哈希路线。

更糟的是，遍历 entrySet 可能仍看见这个条目，size 也仍是 1，于是日志呈现“明明在 Map 里但 get 不到”。remove 也可能失败，形成逻辑泄漏。修复不是在查询时遍历所有 entry，而是让键稳定：使用不可变 ID，或者在身份变化时以旧键 remove 后再用新键 put，并把这次迁移作为明确业务操作。

排查步骤：打印/断言 put 前后的业务键字段与 hashCode；使用创建时等价的新键测试；遍历 entrySet 观察对象；找到所有修改 equals/hashCode 字段的位置。不要依赖 `System.identityHashCode` 修复值对象键，它只会把合同改回引用身份。

## 8. 复杂度：平均 O(1) 依赖良好散列，不是绝对保证

JDK 25 HashMap 文档说明，在 hash 能把键合理分散时，基本 get/put 是常数时间。HashSet 的 add/remove/contains 也有同样前提。这里应读成平均/期望行为，不是任意恶意键和任意负载下的严格最坏界。

哈希表有容量和负载因子。条目数量超过容量与负载因子的阈值时会重建/扩容。默认负载因子 0.75 是官方给出的时间与空间折中。知道大致数量时可合理预估容量，减少扩容；不要盲目设得极大，因为 HashMap 的视图迭代成本与容量加 size 有关。

所有键返回同一个 hashCode 仍可保持 equals 正确，却把大量候选放在一起，查找成本上升。现代实现可能在某些冲突情况下使用比较顺序帮助，但这不是允许糟糕 hash 的借口，也不要依赖内部树化阈值。先确保合同正确和分布合理，再用真实数据测量。

用 List 去重：第 1 个比较少量，第 n 个可能比较前 n-1 个，总工作近似 O(n²)。用 HashSet 逐个 add，在良好散列下总体通常 O(n)。但 n 很小或顺序/重复记录必须保留时，List 仍有价值；复杂度不能覆盖业务语义。

## 9. 顺序边界：Hash、LinkedHash、Tree 是三种不同承诺

`HashSet` 和 `HashMap` 不保证迭代顺序，也不保证顺序随时间保持不变。当前 JVM 恰好按某种顺序打印，不构成合同。测试若断言 HashMap 的具体迭代文本，就是在测试偶然实现细节。

`LinkedHashSet` 和 `LinkedHashMap` 在哈希结构之外维护 encounter order，通常是插入顺序。重新 put 已存在键不会像新键那样自动移到末尾；JDK 25 的 SequencedMap 还提供显式首尾操作。需要“去重但保留第一次出现顺序”时，LinkedHashSet 很合适；需要 API 响应按录入顺序稳定输出时，可使用 LinkedHashMap 或在边界显式排序。

`TreeSet`/`TreeMap` 根据自然顺序或 Comparator 排序，基本操作是 O(log n)。它们用比较结果定位等价类；若 comparator 对两个不 equals 的对象返回 0，TreeSet 可能只保留一个，TreeMap 可能让后来的值占据同一比较键位置。官方要求排序与 equals 一致才能完整遵守 Set/Map 通用合同。

因此“需要稳定顺序”要继续问：第一次出现顺序，还是按字段排序？前者用 linked 变体，后者用 tree 变体或输出前排序。不要用 TreeSet 仅为去重而随便写一个只比较 site 的 Comparator，它可能吞掉同站点不同设备。

## 10. 缺失键、null 与 Optional 的责任边界

`map.get(key)` 返回 null 有两种可能：没有这个键，或键明确映射到 null（在允许 null 的实现中）。`containsKey` 能区分。最简单的业务策略是 Map 不保存 null 值，让 get null 唯一表示缺失；但这必须是项目不变量，不能假设所有传入 Map 都遵守。

`getOrDefault` 对缺失键返回 fallback，但不会把 fallback 写入 Map。若要建立列表桶，可使用 `computeIfAbsent(key, ignored -> new ArrayList<>())`；若只计数，可使用 `merge(key, 1, Integer::sum)`。这些 API 的函数如果返回 null 可能表示不记录或删除，必须读合同，不能把 null 当普通值随手返回。

不要把 Optional 存进每个 Map 值来逃避设计。可以在仓储查询边界返回 `Optional<V>` 表示缺失，但 Map 内部是否允许 null、缺失是否正常、默认值是否有业务含义仍需先定义。`getOrDefault(id, UNKNOWN_DEVICE)` 若 UNKNOWN 是真实设备对象，可能掩盖数据完整性错误。

Map.of/Map.copyOf 创建不可修改 Map，拒绝 null 键和值；Map.of 也拒绝重复键。它们的迭代顺序未指定。若需要稳定输出，不能因为参数书写顺序固定就依赖返回 Map 的迭代顺序。

## 11. 重复输入如何处理：拒绝、覆盖、保留还是汇总

“重复”不是单一技术动作。相同设备扫描两次可能是上游重试，应保留 List 证据并告警；导入配置出现重复键可能必须拒绝；统计类别需要汇总；接收最新状态可能允许覆盖。先定义业务策略，再选择 Set/Map API。

Map `put` 默认覆盖并返回旧值。若重复必须失败，应在 put 前/后检查：`putIfAbsent` 的返回合同在 null 值存在时需谨慎，或者先 `containsKey`。若需要保留所有值，结构是 `Map<K,List<V>>`，而不是让同一 K 在普通 Map 中出现多次。若需要计数，`Map<K,Integer>` 配合 merge 更直接。

Set add 返回 false 可用于检测重复，但如果只忽略返回值，重复被静默吞掉。测试应断言重复策略：输入三条，唯一数两条，重复报告一条；不要只断言最终 Set size，因为那无法证明业务是否记录了拒绝原因。

## 12. 视图、迭代与修改规则

`keySet`、`values`、`entrySet` 是 Map 的 backing views。通过视图删除通常删除原映射；原 Map 改变也反映在视图中。把它们复制进 `List.copyOf`/`Set.copyOf` 才得到结构快照。返回视图前要明确所有权，不能只看接口是 Set 就假设独立。

HashMap/HashSet 的迭代器同样通常 fail-fast：迭代建立后，经非迭代器路径结构修改可能抛 `ConcurrentModificationException`，且只是 best effort。遍历 entrySet 时可用 iterator.remove 删除当前条目；改变已有键对应的 value 是否算结构修改依实现合同，但不要在复杂回调中依赖边缘行为。

`Map.Entry.setValue` 可能允许修改 backing map 的值，来自不可修改 Map 的 entry 则拒绝。把 Entry 长期保存也要小心，它可能是联动视图。跨层返回时通常转换为自己的不可变 DTO，而不是泄漏内部 Entry。

`compute`/`merge` 回调里再次结构修改同一 Map 会让行为难以推理，某些实现会检测并抛异常。回调保持局部、无外部副作用；复杂规则先算出结果，再显式 put/remove。

## 13. FactoryCare 场景：保留输入、去重身份、索引状态、统计类别

一次设备导入包含：`PUMP-01/pump`、`FAN-02/fan`、`PUMP-01/pump`。接入层先保留 `List<ImportRow>`，确保第三行重复事实仍能定位。随后把每行的不可变 `DeviceId` 加入 `LinkedHashSet`，获得 `[PUMP-01, FAN-02]`，既去重又保留首次出现顺序。

设备详情存为 `Map<DeviceId, Device>`。用另一个 `new DeviceId("PUMP-01")` 查询应命中同一条映射，这证明键使用值相等而不是引用身份。Device 的状态字段可更新，因为它是 value；DeviceId 本身不变。

类别统计使用 `Map<String,Integer>` 和 `merge(category, 1, Integer::sum)`，得到 pump=2、fan=1。这与唯一设备计数不同：如果统计“导入行类别”就是 3 行；若统计“唯一设备类别”，应在去重之后统计。集合结构不能替你决定统计口径，测试输入必须让两种口径产生不同结果以防混淆。

API 输出要求与输入顺序一致时使用 LinkedHashMap，要求按设备编号排序时在输出边界排序或选择 TreeMap。内部 HashMap 不保证迭代顺序，不能把一次本地打印当接口合同。数据库持久化、跨节点缓存和并发更新不在本章；内存 Map 不替代这些机制。

## 14. 一个最小、可解释的正例

```java
record DeviceId(String value) {}

List<DeviceId> input = List.of(
        new DeviceId("PUMP-01"),
        new DeviceId("FAN-02"),
        new DeviceId("PUMP-01"));

Set<DeviceId> unique = new LinkedHashSet<>(input);
Map<DeviceId, String> states = new HashMap<>();
states.put(new DeviceId("PUMP-01"), "ACTIVE");

boolean hit = states.containsKey(new DeviceId("PUMP-01"));
String state = states.get(new DeviceId("PUMP-01"));
```

这段代码验证 List 保留三项、Set 留两项、Map 用等价键命中。生产代码还要校验 ID、定义缺失分支、避免 null、处理并发与持久化。示例选择 record 是为了稳定值键，不是要求所有实体都改为 record。

## 15. 失败调试手册

### 15.1 Set 出现“重复对象”

先判断两对象按业务是否真的应相等。直接打印字段、`a.equals(b)`、`a.hashCode()` 与 `b.hashCode()`；如果 equals true 而 hash 不同，修复 hashCode。若 equals false，检查是否错误地包含可变状态、大小写/空白规范化不一致，或根本该使用 DeviceId 而不是整个 Device。

### 15.2 Map put 后 get 不到

记录 put 时与 get 时键的业务字段和 hashCode；检查键是否变异。再用新建等价键查询。如果 entrySet 仍能遍历到，几乎可确认索引路线被破坏。不要改成 entrySet 全扫描，那只是把错误 Map 降级为慢 List。

### 15.3 get 返回 null

先 `containsKey` 区分缺失和显式 null；确认实现是否允许 null、项目是否禁止。检查 key 的 equals/hashCode、规范化和类型。不要立刻 `getOrDefault` 掩盖；默认值只有在业务上有定义时才正确。

### 15.4 输出顺序在机器或运行间变化

检查是否使用 HashMap/HashSet 或 Map.of/Set.of 并误依赖迭代顺序。若合同是插入顺序，使用 linked 变体并断言；若合同是排序，使用明确 Comparator，并用多个不同键测试。不要在测试中把当前 HashMap 顺序硬编码为“修复”。

### 15.5 TreeSet 吞掉了不同对象

对被吞对象同时打印 equals 和 comparator.compare。若 equals false 但 compare 为 0，比较器没有表达完整排序键。增加稳定 tie-breaker，或承认业务确实按该比较字段视为同一等价类；二者必须明确选择。

### 15.6 性能随输入平方增长

搜索 `list.contains`、嵌套循环、每行都全表查找。用 10/100/1000 个唯一键以及高重复数据观察比较次数。若业务是成员判断，改 Set；若是键值查询，改 Map；同时保留必要的原始 List，避免为了性能丢审计数据。

## 16. 测试矩阵：功能、边界、故障与复杂度信号

Set 测试至少包含：同一引用重复加入、不同引用但 equals 相同、hash 碰撞但不 equals、null 策略、不可修改写入、HashSet 顺序不做断言、LinkedHashSet 明确断言首次出现顺序。Map 测试至少包含：新键、等价键覆盖、相同值不同键、缺失键、显式 null（若允许）、containsKey 区分、merge 计数、不可修改写入。

键合同测试要直接检查自反/对称/传递的代表样例，以及 equals true 时 hash 相同；再放入 HashSet/HashMap 进行行为测试。可变键故障必须用可控 hash 值，确保失联不是概率事件。排序结构要测试 compare=0/equals=false 的边界。

复杂度不是普通断言能严格证明，但可以记录 equals/hashCode 调用次数或随规模变化的趋势。不要用墙钟纳秒作为离线确定性 oracle；共享机器负载会让结果抖动。配套验证器只使用固定输入、确定输出和异常类名，不读取网络、时间或随机数。

## 17. 安全、隐私与数据边界

不要把密码、token、完整身份证号等敏感值作为 Map 键并写进 `toString`/日志；键往往出现在诊断输出。集合本身不校验外部输入，设备编号在构造 DeviceId 前仍需长度、字符集、租户边界校验。不同租户若都存在 PUMP-01，键可能需要组合 `TenantId + DeviceId`，否则逻辑相等会错误覆盖。

哈希表不应直接接受攻击者可控制的大量糟糕散列键而不考虑资源限制，但本章不设计防 DoS 容器。先限制请求大小、验证输入、监测异常冲突/延迟，再在安全章节讨论更完整控制。不要自行用 hashCode 当密码学哈希、签名或持久 ID；Object hash 只服务集合定位。

返回 Map 时要防内部可变状态泄漏。`Map.copyOf` 只让映射结构不可修改，value 对象仍可能可变。跨 API 边界通常映射为不可变 DTO，并明确排序；这也是让输出可测试、避免调用者绕过领域规则的做法。

## 18. 与 TypeScript/JavaScript 对照

JavaScript `Set`/`Map` 也表达成员唯一和键值映射，但相等语义、对象键和迭代保证不能直接照搬。JS Map 对象键常按对象身份；Java HashMap 可通过覆写 equals/hashCode 让不同实例成为相等键。Java record 值键更像显式定义结构化身份，不等于把普通 JS 对象内容自动深比较。

TypeScript 的类型不会在运行时替 Map 验证外部 JSON。Java 泛型也同样主要是编译期约束：`Map<DeviceId,Device>` 不能保证反序列化输入合法，也不能保证 key 对象不被其内部可变成员改变。跨语言共同问题仍是合同、所有权、缺失值和输入验证。

JS Object 常被当字符串键字典，Java Map 支持任意满足合同的键类型；但“任意”不等于“适合”。无论语言，都应优先使用小而稳定的身份值，不把庞大可变对象当索引键。

## 19. 选择准则与明确非目标

| 需求 | 结构 | 典型实现 | 关键风险 |
| --- | --- | --- | --- |
| 保留全部出现与位置 | List | ArrayList | 查重/查询线性，不能静默丢重复 |
| 唯一成员、无顺序合同 | Set | HashSet | equals/hashCode 与可变键 |
| 唯一且保留首次顺序 | Set | LinkedHashSet | 额外顺序维护成本 |
| 唯一且始终排序 | Set | TreeSet | Comparator=0 决定等价类 |
| 键到值快速查询 | Map | HashMap | 缺失/null、键稳定、无顺序保证 |
| 键值且保留 encounter order | Map | LinkedHashMap | 重放/访问顺序模式要明确 |
| 键值且按键排序/范围 | Map | TreeMap | O(log n)、排序与 equals 一致性 |

本章不把 Map 当缓存，不设计 TTL/LRU、一致性或分布式失效；不把 HashMap 类比数据库索引后就推导数据库复杂度；不处理 ConcurrentHashMap 原子复合操作；不教授 Comparator 的完整组合 API。遇到这些需求时记录前置与风险，转到对应章节。

## 20. 预测、动手、故障与需求变更

### 预测题

1. 两个 `new DeviceId("A")` 放入 HashSet 后 size 应是多少？需要哪些合同成立？
2. HashMap 已有键 A 映射 null，`get(A)` 与 `get(missing)` 各返回什么？如何区分？
3. LinkedHashMap 对已有键再次 put，正常插入顺序是否把它移到最后？
4. Comparator 只比较设备 site，两个同 site 不同 id 放 TreeSet 会怎样？

### 动手题

输入五行设备数据，其中两个重复 ID、三个类别。保留原 List，生成 LinkedHashSet 唯一 ID，生成 Map 类别频次和 Map<DeviceId,Device>。打印输入数、唯一数、重复数、稳定顺序、频次和缺失分支。

### 故障题

实现一个键类，让可变整数直接作为 hashCode；put 后改变整数，复现 containsKey=false 和 remove 失败。随后改成不可变 record 键，重跑同一 oracle。再实现 equals true/hashCode 不同的错误类，证明 List.contains 通过但 HashSet 去重失败。

### 需求变更题

现在 PUMP-01 可在不同租户重复。比较三种键：拼接字符串、嵌套 Map、`record DeviceKey(TenantId tenant, DeviceId device)`。从实现成本、迁移成本、碰撞/规范化风险和长期维护性解释选择，不直接改数据库合同。

### 关闭 AI 独立练习

限时 40 分钟完成公开 starter：修复键合同、保序去重、类别计数和缺失分支。禁止用 List 全扫描替代 Map、禁止 identityHashCode、禁止把所有 null 变成空字符串。最后用 120 秒说明为何每个修复正确。

## 21. 复述与间隔复习

### 120 秒复述模板

“List 保留每次出现；Set 保证按相等关系唯一；Map 保证每个键最多一个值。Hash 结构先用 hashCode 找候选桶，再用 equals 确认，所以相等对象必须同 hash，且键在容器期间要稳定。HashMap 平均查询快但不承诺顺序；LinkedHashMap 保 encounter order；TreeMap 按比较器排序，compare 为 0 会形成同一排序键。get 返回 null 可能是缺失或显式 null，要用 containsKey 或禁止 null 的不变量区分。”

### 复习计划

- 1 天后：不看书画出 put/get 的 hash→桶→equals 路径。
- 3 天后：手写 equals/hashCode 合同和可变键失联时间线。
- 7 天后：用同一输入分别构造 List、LinkedHashSet、HashMap、TreeMap，解释输出差异。
- 14 天后：从一个真实模块找出所有 Map 键，审查稳定性、null、顺序和租户边界。

### 诊断速查

| 现象 | 第一检查 | 常见修复 |
| --- | --- | --- |
| Set 有逻辑重复 | equals 与 hash 是否一致 | 使用稳定值键，同时覆写合同 |
| put 后 get 不到 | 键字段/hash 是否变化 | 不可变键或显式旧键迁移 |
| get 为 null | containsKey、null 策略 | 显式缺失分支，不盲目默认 |
| 输出顺序漂移 | 是否依赖 Hash/of 顺序 | linked 变体或明确排序 |
| TreeSet 丢元素 | compare=0 但 equals=false | 完整 tie-breaker/重定义等价类 |
| 去重变慢 | List.contains 嵌套 | Set/Map，同时保留原始 List |

## 22. 官方资料与当前性边界

以下均为 Oracle Java SE 25 官方 API，复核日期为 **2026-07-16**：

- [Set](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Set.html) 与 [Map](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Map.html)：唯一性、键值合同、不可修改工厂、null 与迭代顺序边界。
- [HashSet](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/HashSet.html)：无顺序保证、良好散列下的基本操作成本和 fail-fast 限制。
- [HashMap](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/HashMap.html)：桶/容量/负载因子、get/put 条件性常数成本、迭代成本、null 与顺序边界。
- [LinkedHashMap](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/LinkedHashMap.html)：双向链接维护 encounter order、重插入已有键与访问顺序模式。
- [TreeSet](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/TreeSet.html) 与 [TreeMap](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/TreeMap.html)：O(log n) 操作、自然/外部排序以及排序与 equals 一致性的要求。
- [Object.equals/hashCode](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Object.html)：等价关系与“相等对象必须有相同 hash”的直接合同。

本章的稳定核心是集合合同、键相等性与选择方法。HashMap 内部树化阈值、容量具体增长、未承诺的迭代偶然顺序和完整异常消息都不是业务合同。当前代码只在本机 macOS arm64 的 Java 25 基线执行；其他 JDK 构建、操作系统、并发访问、数据库与缓存行为未在本批验证。
