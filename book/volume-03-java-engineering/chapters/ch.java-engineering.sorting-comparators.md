---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.sorting-comparators
title: Comparable、Comparator 与稳定排序
responsibility: 教授自然顺序和外部排序策略，不在本章实现通用排序算法或数据库 ORDER BY
volume: '03'
order: 5
level: L1
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.sorting-comparators.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-engineering.sequential-collections
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
  text: 在 120 秒内解释Comparable、Comparator 与稳定排序的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-order-contract
  - java-sorting
  covers_topics:
  - java.comparable
  - java.comparator
  - java.order-equality-consistency
  - java.stable-sort
  - java.comparator-chain
  - java.null-ordering
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.methods
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为工单定义优先级降序、创建时间升序、ID 兜底的 Comparator 链，并验证稳定排序与 null 策略
  covers_topic_groups:
  - java-order-contract
  - java-sorting
  covers_topics:
  - java.comparable
  - java.comparator
  - java.order-equality-consistency
  - java.stable-sort
  - java.comparator-chain
  - java.null-ordering
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.methods
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入比较器不满足反对称/传递或用减法溢出，构造三元素反例并改用安全比较方法，并把异常定位到第一处可信证据
  covers_topic_groups:
  - java-order-contract
  - java-sorting
  covers_topics:
  - java.comparable
  - java.comparator
  - java.order-equality-consistency
  - java.stable-sort
  - java.comparator-chain
  - java.null-ordering
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.methods
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Comparable、Comparator 与稳定排序

> 本章状态为 `drafting`。固定 Java 25 oracle 只能证明示例在当前机器满足排序合同；P9 的零基础试读、人工版式/无障碍检查、独立全面审查和全书回归尚未执行，不能因此晋升为 `verified`，也不会修改 `PROGRESS.md`。

“把工单排一下”不是一个完整需求。按优先级排时，高优先级在前还是在后？优先级相同后看创建时间还是 SLA 截止时间？时间也相同怎么办？缺失时间放首、放尾还是拒绝？两条记录比较为 0 时，是否依靠稳定排序保留输入次序？这些问题若不写成合同，同一批数据可能在列表、TreeSet、页面和测试里出现彼此矛盾的结果。

Java 用 `Comparable<T>` 表达类型自身的自然顺序，用 `Comparator<T>` 表达类型外部、可替换的排序策略。比较方法只返回负数、0 或正数，符号表达先后；它必须满足反对称方向、传递性和“比较为 0 的对象对第三者方向一致”等合同。排序算法依赖这些规则，就像 HashMap 依赖 equals/hashCode。

本章以 FactoryCare 工单为连续场景，覆盖自然顺序、外部比较器、组合链、降序、null 策略、稳定排序、与 equals 一致性、TreeSet/TreeMap 等价类、整数减法溢出和故障测试。不实现通用排序算法，也不讨论数据库 `ORDER BY`。版本基线为 **JDK 25**，官方资料复核日期为 **2026-07-16**。

## 1. 学完后必须留下的证据

1. 在 120 秒内说明 Comparable 与 Comparator 的所有权差异、compare 返回值的符号含义、三个核心合同和稳定排序的定义。
2. 构造“优先级降序 → 创建时间升序 → ID 升序”的 Comparator 链，用至少六张工单手算并断言完整顺序。
3. 构造只比较优先级的比较器，证明相等主键的元素经稳定 List 排序后保持原 encounter order。
4. 明确处理 null 元素和 null 字段；验证 `nullsFirst/nullsLast` 放在哪一层会产生什么结果。
5. 复现减法溢出、循环顺序和 comparator=0/equals=false 在 TreeSet 中吞元素的故障，再用安全比较与完整 tie-breaker 修复。

配套工件：

- [比较器与稳定排序示例](../../../examples/encyclopedia/ch.java-engineering.sorting-comparators/README.md)
- [FactoryCare 工单顺序合同实验](../../../labs/encyclopedia/ch.java-engineering.sorting-comparators/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.sorting-comparators/README.md)

公开 starter 初始失败是练习起点；在没有独立预测、运行和诊断前不要查看私有解。

## 2. 排序的最小模型：成对比较产生一个顺序关系

排序算法会反复问比较器：“左值与右值谁应在前？”`compare(left, right)` 返回负数表示 left 小于 right，0 表示当前排序合同认为二者处于同一等价类，正数表示 left 大于 right。调用者只能依赖符号，不能依赖恰好返回 -1、0、1。

“小”不等于业务上的低优先级。若希望严重工单排在前，可以让较高 priority 在比较结果中被视为更小，或先构造升序比较器再 `reversed()`。关键是变量名和测试表达清楚，不在不同位置一会儿把 5 当最高、一会儿当最低。

比较器不是一次性 if。排序会以不同顺序比较许多对元素，可能重复比较同一对，也可能先比较 A/B、再 B/C、最后 A/C。比较函数必须对相同可观察输入给出稳定结果，不能读当前时间、随机数、会变化的全局状态或顺手修改对象。

一个合法顺序关系让排序算法可以推理；非法关系即使小输入“看起来排好了”，也可能在另一排列或数据规模下得到错误结果、抛 `IllegalArgumentException`，或让 TreeSet/TreeMap 丢条目。

## 3. Comparable：类型声明一个自然顺序

类实现 `Comparable<T>` 后，通过 `compareTo(T other)` 声明自然顺序。`String`、`Integer`、`LocalDateTime` 等标准类型已经提供自然顺序，因此可直接用于 `Comparator.naturalOrder()` 或无显式 Comparator 的排序结构。

自然顺序应当是该类型最普遍、跨场景稳定且不会频繁争议的顺序。例如版本号值对象可能有明确语义顺序；工单却可能按 ID、创建时间、优先级、截止时间或负责人排序，很难选唯一“自然”策略。为了省一个 Comparator 就让 WorkOrder 实现 Comparable，往往把某个页面需求硬编码进领域类型。

如果确实实现 Comparable，推荐泛型写成 `Comparable<DeviceId>` 而不是 raw Comparable。`compareTo` 一般应与 equals 一致：`a.compareTo(b)==0` 当且仅当 `a.equals(b)`。官方称这不是 Comparable 的绝对强制要求，但强烈推荐；BigDecimal 是标准库里著名的不一致例外。

自然顺序不接受 null 作为另一个同类实例；`x.compareTo(null)` 应抛 NullPointerException。需要排序含 null 的输入时，在调用边界用 Comparator 的 null 包装器明确处理，而不是让每个领域 compareTo 猜测 null 的位置。

## 4. Comparator：把可变策略留在类型外部

`Comparator<T>` 是函数式接口，核心方法是 `int compare(T left, T right)`。同一个 WorkOrder 可拥有多个命名策略：`BY_PRIORITY`、`BY_CREATED_AT`、`DISPATCH_ORDER`、`AUDIT_EXPORT_ORDER`。策略在使用处被选择，领域对象不需要为每个页面改 compareTo。

最基础工厂：

```java
Comparator<WorkOrder> byCreatedAt =
        Comparator.comparing(WorkOrder::createdAt);

Comparator<WorkOrder> byPriorityDescending =
        Comparator.comparingInt(WorkOrder::priority).reversed();
```

`comparingInt/Long/Double` 使用对应基本类型提取器，避免不必要装箱，也让数值比较意图明确。字符串、时间和自定义值可用 `comparing(keyExtractor)`；若键本身需要特殊顺序，使用带 keyComparator 的重载。

比较器适合声明为命名常量或返回明确策略的方法。长链直接埋在 Controller 中难以复用和测试；但也不要建立一个接收任意字符串并反射字段的“万能排序器”，那会把类型安全、null 和授权边界变成运行时问题。

## 5. 比较器合同：符号反向、传递与零等价一致

Comparator 官方合同可转成三个可测试规则。

第一，符号反向：`sign(compare(a,b)) == -sign(compare(b,a))`。如果 A 在 B 前，那么交换参数后 B 必须在 A 后；如果一边抛异常，另一边也应抛。不要只断言某个方向。

第二，传递：若 A>B 且 B>C，则 A>C。剪刀石头布式规则——紧急胜普通、普通胜维护、维护又胜紧急——无法形成全序。排序需要的是一致顺序，不是循环胜负游戏。

第三，零等价一致：若 compare(A,B)==0，那么对任意 C，A 与 C、B 与 C 的比较符号必须相同。否则算法一会儿把 A/B 当同一等价类，一会儿又允许第三者把它们分开，结构无法可靠定位。

此外通常要求 `compare(a,a)==0`。测试应覆盖所有代表值的自比较、所有有序对和所有三元组。固定小域的穷举比依赖随机碰巧撞到反例更确定；较大域可用固定 seed 生成样本，但 seed、生成器和期望必须记录。

## 6. 与 equals 一致：List 排序与有序 Set 的风险不同

List 排序允许 comparator 对两个不 equals 的元素返回 0；稳定算法会保留它们的原相对顺序，两个元素仍都在列表里。比如只按 priority 排序，两张不同 ID 的 P1 工单比较为 0，List 不会去重。

TreeSet/TreeMap 则使用比较结果决定排序等价类。若两张不同工单 compare 为 0，TreeSet 可能只保留一张，TreeMap 可能把它们视为同一排序键。此时结构行为与 Set/Map 基于 equals 的通用直觉冲突。官方建议排序与 equals 一致，或者明确文档声明不一致。

因此“页面排序”可以只比较显示字段并依靠稳定性；“TreeSet 唯一键”通常要加入足以区分逻辑对象的 tie-breaker。不能把同一个窄比较器不加审查地用于两种场景。

equals/hashCode 与 Comparator 是两套合同。HashSet 看 equals/hashCode，TreeSet 看 compare；修复 TreeSet 丢元素不能只改 hashCode。调试时同时打印 `equals`、两个 hash 和 `compare`，先确认结构实际使用哪条路径。

## 7. 用组合链表达多字段业务规则

FactoryCare 调度合同：优先级数值越大越靠前；同优先级创建越早越靠前；仍相同按 ID 升序，保证总结果确定。

```java
Comparator<WorkOrder> dispatchOrder =
        Comparator.comparingInt(WorkOrder::priority).reversed()
                .thenComparing(WorkOrder::createdAt)
                .thenComparing(WorkOrder::id);
```

`thenComparing` 只在前一比较器返回 0 时启用后续策略。读这条链时按“先……相同再……”翻译，逐级写手算表。若 ID 唯一且最后加入 ID tie-breaker，不同工单通常不会再 compare 为 0；这会带来确定总序，但也意味着稳定性不再负责保存同主键项的原顺序。

`reversed()` 的位置极重要。对 `comparingInt(priority).reversed().thenComparing(createdAt)`，只反转 priority；如果在整条链末尾 `.reversed()`，优先级和创建时间方向都会反转。需求常是“优先级降序、时间升序”，两者不能用整体 reversed 偷懒。

命名比较器能降低方向错误：先定义 `PRIORITY_DESCENDING` 与 `CREATED_AT_ASCENDING`，再组合。测试要让每一层单独决定一次结果；若所有样例 priority 都不同，根本没有测试 thenComparing。

## 8. 安全数值比较：不要用减法返回差值

看似简洁的 `return left.priority() - right.priority();` 会溢出。若 left 是 `Integer.MIN_VALUE`、right 是 1，数学结果小于 int 最小值，Java int 环绕后可能变成正数，于是较小值被误判为较大。长整型转 int 更危险，还会截断。

使用 `Integer.compare(left, right)`、`Long.compare`、`Double.compare` 或 `Comparator.comparingInt/Long/Double`。这些 API 表达的是顺序符号，不要求保存真实差值。降序使用交换参数或 reversed，不使用 `right-left` 重复引入溢出。

浮点排序还有 NaN、正负零规则，使用 `Double.compare` 比手写 `<`/`>` 更完整。金额通常不应使用 double；那属于数值建模合同，但比较器仍必须使用与值类型一致的 compareTo，而不是转换为 double。

故障验证必须包含极值。只测 1、2、3 永远看不到减法溢出。固定反例 `MIN_VALUE`、0、`MAX_VALUE` 可同时检查自比较、反向符号与传递性。

## 9. null 策略：区分 null 元素与 null 排序字段

`Comparator.nullsFirst(delegate)`/`nullsLast(delegate)` 处理整个被比较对象为 null。例如 `Comparator.nullsLast(dispatchOrder)` 允许 List 本身含 null 工单，并把它们放末尾。是否应允许 null 工单是数据质量决策；很多领域边界更适合先拒绝，而不是排序时隐藏。

对象非 null，但某个字段如 dueAt 可为 null，需要把 null 包装器放在键比较器上：

```java
Comparator<WorkOrder> byDueAt = Comparator.comparing(
        WorkOrder::dueAt,
        Comparator.nullsLast(Comparator.naturalOrder()));
```

这与 `Comparator.nullsLast(byDueAt)` 不同：后者只保护 WorkOrder 本身，提取到 null dueAt 后自然顺序仍会失败。排查 NPE 时看堆栈究竟在对象比较、keyExtractor 还是键比较器。

nullsFirst/nullsLast 的 delegate 也可为 null，此时所有非 null 值被视为同一等价类；这通常不如显式比较器清楚。业务输出最好定义缺失值含义：未知截止时间放末尾、必须人工修复，或输入直接拒绝。

## 10. 稳定排序：比较为 0 时保留先来后到

稳定排序保证：若比较器认为两个元素相等，它们在排序结果中的相对顺序与输入一致。JDK 25 的 `List.sort` 和 `Collections.sort` 明确保证稳定；对象数组的相关 `Arrays.sort` 也明确保证稳定。

示例输入按接收顺序为 `A(P2)`、`B(P1)`、`C(P2)`、`D(P1)`，只按 priority 降序稳定排序后应为 A、C、B、D。P2 组保持 A 在 C 前，P1 组保持 B 在 D 前。若给比较器再加入 ID，A/C 不再比较为 0，“稳定”对这对元素就没有可观察作用。

稳定性适合多阶段排序，但更推荐一次写出完整链。先按 createdAt 排，再按 priority 稳定排可以产生组合效果，顺序却不易审查，任何一步换成不稳定实现都会改变结果。`thenComparing` 直接表达优先级层次。

稳定排序不是“不修改输入”。`List.sort` 原地重排可变列表；不可修改 List 会抛 UnsupportedOperationException。需要保留原输入时先 `new ArrayList<>(source)` 或 stream 产生新结果，并明确浅复制仍共享元素对象。

## 11. API 选择与修改边界

`list.sort(comparator)` 修改该列表并返回 void。`Collections.sort(list, comparator)` 同样修改列表，现代代码通常直接用 List 方法。`stream.sorted(comparator).toList()` 返回新结果而不重排源列表，但 Stream 的惰性、并行和 encounter order 属于后续章节；本章资产用显式副本减少隐藏前置。

自然顺序可传 null comparator 给 List.sort，也可用 `Comparator.naturalOrder()`，后者在组合链中更清楚。`Comparator.reverseOrder()` 表示自然顺序的逆序，不等于任意业务比较器的 reversed。

对只读边界，先复制再排序，再 `List.copyOf` 发布。不要先 `List.copyOf` 后调用 sort；异常是不可修改合同的正确表现。若列表由 `subList` 等视图得到，排序可能同步改变 backing list 的对应区间，所有权必须先明确。

## 12. 复杂度与比较器成本

基于比较的通用排序通常需要 O(n log n) 量级比较；JDK 25 List.sort 的实现说明是稳定、适应性归并排序，并可能使用临时数组。具体算法是实现说明而非所有未来版本的永久业务合同，代码只依赖稳定与 Comparator 合同。

总成本不只是“比较次数”。若 keyExtractor 每次比较都解析 JSON、格式化时间或访问网络，O(n log n) 次比较会放大昂贵副作用。比较器必须纯、快速；可在排序前校验并预计算不可变键，但要权衡额外 O(n) 空间与数据过期风险。

字符串比较成本还与共同前缀长度有关；大对象排序移动的是引用而非复制全部对象，但临时结构仍占内存。不要只凭 Big-O 宣称某实现更快，下一章会系统讨论规模、常数、内存和测量。

## 13. FactoryCare 完整场景

六张工单分别覆盖三层规则：P3 较新与较旧、P2 两张同时间不同 ID、P1 一张，以及 dueAt 缺失。先手算表：列出 priority 的负向排序键、createdAt 正向键、ID 正向键，再得到唯一 expected 序列。

调度列表使用完整 tie-breaker，确保日志、测试和 API 输出可重放。页面“按优先级分组并保留接收顺序”则使用只比较 priority 的窄比较器，依靠 List.sort 稳定性。二者不能共用一个含 ID 的比较器，否则组内接收顺序被 ID 重排。

SLA 视图按 dueAt 升序，null 放末尾；同时返回“缺失截止时间”标志，不能因为排到末尾就忽略数据质量。TreeSet 若用于保存唯一工单，比较器必须包含 ID；若只是临时排序展示，优先使用 List 副本，不借 Set 的去重副作用。

排序发生在内存快照上，不保证数据库、多实例或并发更新后的全局顺序。本章不把 Java Comparator 规则冒充 SQL ORDER BY，也不处理分页过程中数据变化。

## 14. 故障诊断手册

### 14.1 Comparison method violates its general contract

先保留最小失败输入和原始顺序。对其中所有 a/b/c 计算符号矩阵，检查交换方向、三元传递和 compare=0 对第三者一致。不要只在 catch 中重试排序；同一个非法关系不会因重试变合法。

### 14.2 结果方向整体或局部相反

打印每层键，不打印对象完整 toString。检查 reversed 放在主比较器之后还是整条链之后。使用让第一层相同、第二层不同的样例定位局部方向。

### 14.3 极值顺序错误

搜索比较器中的减法、强转和 `(int)(longDiff)`。用 MIN/0/MAX 重跑反向和传递断言，替换成 `Integer.compare`/`Long.compare` 或 comparingX。

### 14.4 null 仍然 NPE

区分 null 元素与 null 字段。检查 nullsLast 包装层级；先对整个 WorkOrder 包装不能保护 dueAt 提取结果。决定是排序、默认、还是在输入边界拒绝。

### 14.5 TreeSet 少了元素

对丢失的两个对象检查 equals 与 compare。compare=0 就是 TreeSet 的同一排序等价类；加入 ID tie-breaker，或承认需求本来就是按该字段唯一。hashCode 在这里不是修复点。

### 14.6 稳定性测试没有意义

如果比较器最后有唯一 ID，所有不同元素都非 0，无法观察稳定性。单独构造只比较主键的 comparator，输入交错组并断言组内 encounter order。

## 15. 如何测试一个比较器

功能 oracle 要覆盖每一层：priority 不同；priority 同、时间不同；两者同、ID 不同；完全相同引用；字段 null；整个元素 null（若允许）。断言完整列表比只断言第一个元素强。

合同 oracle 对固定域做穷举：每个 x 检查 compare(x,x)==0；每对 x/y 检查符号反向；每个三元组检查传递与零等价一致。比较结果用 `Integer.signum` 归一化，因为 Comparator 不承诺返回绝对值。

稳定性 oracle 保存输入位置，在只比较主键的排序后检查相同主键组的位置递增。TreeSet 边界 oracle 用 equals=false、compare=0 的两个对象证明 size 变化，再用完整 comparator 修复。

故障测试应确定性触发：减法溢出使用固定极值；循环比较器使用固定 A/B/C；null 使用明确字段。不要把“随机跑一万次没失败”当合同证明。

## 16. 与 TypeScript/JavaScript 对照

JavaScript `array.sort((a,b)=>...)` 也使用负/零/正比较结果，减法比较数值时同样需要考虑 Number 语义、NaN 和字段缺失。Java 通过泛型 Comparator、基本类型 compare 工厂和 null 包装器让合同更显式，但不会自动阻止逻辑不传递。

TypeScript 的可选字段常表现为 `undefined`，Java 业务模型可能用 null 或 Optional；无论语言，都要在比较器中定义缺失值位置。前端页面的 localeCompare 也提醒我们：String 自然顺序不是面向人的本地化排序。用户可见文本排序应明确 Locale/Collator 需求，本章不展开国际化规则。

Vue computed 中排序时若直接对响应式源数组原地 sort，会改变共享状态；Java 对共享 List 原地 sort 有类似所有权风险。先复制再排序是一条可跨语言复用的边界规则。

## 17. 练习、变更与关闭 AI

### 预测题

1. comparator 只比较 priority，输入 A(P2)、B(P1)、C(P2) 稳定降序后是什么？
2. 在完整链末尾 reversed 会反转哪些层？
3. `Integer.MIN_VALUE - 1` 用作比较结果为何会错？
4. 两对象 equals=false、compare=0，放 List 与 TreeSet 各有什么差异？

### 动手题

为六张工单建立调度比较器，先手算 expected，再断言排序。另建只比较 priority 的稳定性测试和 dueAt nullsLast 测试。

### 故障题

实现剪刀石头布式 comparator，穷举三个值找出传递反例；实现整数减法 comparator，用 MIN/MAX 找出反向失败。修复后重跑原 oracle，不删故障样例。

### 需求变更题

产品要求“已超时工单始终在最前，其余仍按原调度规则”。先定义 `overdue` 的参考时刻，禁止 comparator 内部直接调用当前时间；把固定 evaluationTime 预先传入或预计算键，保证一次排序期间结果稳定。

### 关闭 AI 独立练习

限时 40 分钟完成公开 starter。依次修复方向、thenComparing、null 字段和安全整数比较；保留稳定性测试，最后口述每个样例由哪一层决定。

## 18. 复述、间隔复习与速查

### 120 秒复述模板

“Comparable 是类型内唯一自然顺序，Comparator 是外部可替换策略。compare 只看符号，必须满足交换方向、传递和零等价一致，通常与 equals 一致。组合链按前者为 0 才进入后者；reversed 的位置决定反转范围。数值用 compare/comparingX，不用减法。null 元素和 null 字段分层处理。稳定排序只保证 compare=0 的元素保持输入相对顺序；List 保留二者，TreeSet 可能把 compare=0 当同一元素。”

### 复习计划

- 1 天后：默写三条 Comparator 合同并用 A/B/C 解释。
- 3 天后：从业务句子重建三层链，手算六元素顺序。
- 7 天后：不看旧代码重做溢出、null 和 TreeSet 三种故障。
- 14 天后：审查一个真实排序，说明所有权、稳定性、equals 一致性和缺失值策略。

### 速查表

| 需求 | 推荐表达 | 常见错误 |
| --- | --- | --- |
| 类型唯一自然顺序 | `Comparable<T>` | 把页面排序固化进领域类型 |
| 多个业务顺序 | 命名 `Comparator<T>` | 一个万能动态比较器 |
| int/long/double | `comparingInt/Long/Double` | left-right 溢出 |
| 多字段 | `thenComparing` | 样例未进入后续层 |
| 只反转主键 | 主 comparator `.reversed()` 后再链 | 整条链末尾 reversed |
| null 对象 | `nullsFirst/Last(delegate)` | 误以为保护 null 字段 |
| null 字段 | `comparing(extractor, nullsX(...))` | 包装层级错误 |
| 保留组内输入顺序 | 稳定 List 排序、主键 comparator | 加唯一 tie-breaker 后仍谈稳定性 |
| TreeSet 唯一 | 与 equals 一致的完整排序键 | compare=0 吞不同元素 |

## 19. 官方资料与当前性边界

以下均为 Oracle Java SE 25 官方 API，复核日期为 **2026-07-16**：

- [Comparable](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Comparable.html)：自然顺序、传递/符号合同及与 equals 一致性的建议。
- [Comparator](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Comparator.html)：比较器总序合同、`comparing`、`thenComparing`、`reversed`、`nullsFirst/nullsLast`。
- [List.sort](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/List.html)：稳定排序保证、可修改边界与 JDK 25 实现说明。
- [Collections](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Collections.html)：稳定 `sort` 与排序/查找工具。
- [Arrays](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Arrays.html)：对象数组稳定排序及基本类型/对象数组的不同 API。
- [Integer](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Integer.html)：`compare` 的安全 int 顺序比较。

稳定核心是顺序合同、比较器组合和稳定性定义；JDK 25 当前 List.sort 的具体算法、临时数组策略和完整异常消息是实现说明或非稳定细节。当前资产只在本机 macOS arm64 Java 25 基线运行；其他 JDK 构建、操作系统、并发变化、数据库排序和本地化 Collator 未在本批验证。
