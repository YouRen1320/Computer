---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.sequential-collections
title: List、Queue、Deque 与迭代
responsibility: 教授有序和队列型集合的契约与选择，不在本章讨论哈希键或并发集合
volume: '03'
order: 3
level: L1
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.sequential-collections.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-engineering.generics-type-safety
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
  text: 在 120 秒内解释List、Queue、Deque 与迭代的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-list
  - java-queue-deque
  covers_topics:
  - java.list-contract
  - java.iterator
  - java.mutable-unmodifiable-list
  - java.queue-fifo
  - java.deque-stack
  - java.collection-operation-choice
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.arrays
  - java.methods
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 用 List 保存工单顺序、Queue 调度待处理项、Deque 实现撤销栈，并比较可变与不可修改视图
  covers_topic_groups:
  - java-list
  - java-queue-deque
  covers_topics:
  - java.list-contract
  - java.iterator
  - java.mutable-unmodifiable-list
  - java.queue-fifo
  - java.deque-stack
  - java.collection-operation-choice
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.arrays
  - java.methods
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入遍历时结构修改、空队列错误读取和把 Queue 当随机访问列表，定位异常/复杂度后修复
  covers_topic_groups:
  - java-list
  - java-queue-deque
  covers_topics:
  - java.list-contract
  - java.iterator
  - java.mutable-unmodifiable-list
  - java.queue-fifo
  - java.deque-stack
  - java.collection-operation-choice
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.arrays
  - java.methods
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# List、Queue、Deque 与迭代

> 本章状态为 `drafting`。正文和代码用于学习与自动检查；它们尚未经过 P9 的零基础读者试读、人工版式/无障碍检查和全书一致性审查，不能据此宣称章节已 `verified`，也不会修改 `PROGRESS.md`。

一个集合不是“能装很多值的变量”这么简单。保存报修单时，系统可能要保留提交顺序；调度时要让最早进入的任务最先离开；撤销操作时却要让最后一次动作最先恢复。三者都能装多个元素，但它们承诺的**访问方式**不同。若只看具体类名而不先写清业务顺序，代码即使编译也可能稳定地产生错误结果。

本章只讨论单线程中的顺序型集合：`List` 的位置与重复元素、`Queue` 的队首语义、`Deque` 的双端与栈语义、`Iterator` 的遍历和安全删除，以及可变集合、不可修改视图与独立快照的区别。哈希键、`Set` 和 `Map` 留到下一章，并发集合留到并发卷。版本基线是 **JDK 25**；官方 API 资料复核日期为 **2026-07-16**。

## 1. 学完后要留下的可观察证据

阅读完成不是证据。你应当能留下四组可以被别人复跑的结果：

1. 在 120 秒内不看笔记说明 `List`、`Queue`、`Deque` 的核心契约，分别举出一个 FactoryCare 用例和一个选错结构的后果。
2. 用一个 `List` 保留工单输入顺序与重复项，用一个 `Queue` 证明 FIFO，用一个 `Deque` 证明 LIFO；每一步都先写 expected，再运行 actual。
3. 证明空队列上的 `poll`/`peek` 返回 `null`，而 `remove`/`element` 抛异常；说明为什么业务流程通常要显式选择其中一组，而不能混用。
4. 复现遍历时直接结构修改造成的 `ConcurrentModificationException`、不可修改集合写入造成的 `UnsupportedOperationException`，再用迭代器自身的 `remove`、`removeIf` 或先收集后修改修复。

配套工件：

- [顺序集合观察示例](../../../examples/encyclopedia/ch.java-engineering.sequential-collections/README.md)
- [FactoryCare 调度与撤销实验](../../../labs/encyclopedia/ch.java-engineering.sequential-collections/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.sequential-collections/README.md)

私有解与公开 starter 物理隔离。第一次做练习时不要读取私有目录；先预测第一处失败、执行公开验证器、依据断言修复，再重跑同一个命令。

## 2. 先把“有顺序”拆成三个不同问题

“这些数据有顺序”至少可能指三件事。第一，集合是否记住元素的**位置**，让调用者能说“第 0 个”和“最后一个”；这是 `List` 的职责。第二，元素是否按进入次序被消费；这是 FIFO 队列的职责。第三，是否允许从两端操作，或者把最后一次加入当成下一次取出；这是 `Deque` 的职责。它们不是同义词。

`List<E>` 是序列：元素有从 0 开始的索引，可以重复，通常允许按位置读取、替换、插入和删除，但具体实现可能不支持某些可选修改操作。`Queue<E>` 描述“队首”以及插入/检查/移除队首的操作；队列通常是 FIFO，却不保证所有实现都 FIFO，例如优先队列会按优先级决定队首。`Deque<E>` 是双端队列，可从首尾插入、查看和删除；约定只从尾部压入、从尾部弹出时，它也能表达 LIFO 栈。

接口声明的是合同，具体类决定存储机制和性能。写 `List<WorkOrder> orders = new ArrayList<>();`，左侧让调用代码只依赖 List 能力，右侧选择动态数组。若业务以后真的需要另一种实现，可以在边界处替换；但不能认为所有实现复杂度相同，也不能因为左侧是接口就忽略右侧机制。

## 3. List 的合同：位置、重复与元素相等性

列表保留元素的 encounter order。向末尾依次加入 A、B、A，遍历会看到 A、B、A；重复不会自动消失。`size()` 是元素数量，不是最后一个索引。空列表大小为 0，没有合法索引；大小为 n 时，合法索引是 0 到 n-1。访问 n 会抛 `IndexOutOfBoundsException`。

常用操作可以按意图分组：

| 意图 | API | 重要边界 |
| --- | --- | --- |
| 追加 | `add(e)`、`addLast(e)` | 可变实现才支持；返回值/异常按接口与实现合同处理 |
| 按位置插入 | `add(index, e)` | 之后元素右移；index 可等于 size 表示尾插 |
| 读取 | `get(index)`、`getFirst()`、`getLast()` | 空列表或非法索引会失败 |
| 替换 | `set(index, e)` | 不改变大小，通常不算结构修改 |
| 删除 | `remove(index)`、`remove(object)` | 一个按位置，一个用 `equals` 找匹配值 |
| 查找 | `contains`、`indexOf`、`lastIndexOf` | 依赖元素的 `equals`，普通列表通常线性扫描 |
| 切片视图 | `subList(from, to)` | 通常是与原列表联动的视图，不是自动复制 |
| 排序 | `sort(comparator)` | 原地修改可变列表；比较器合同另章详解 |

`remove(1)` 与 `remove(Integer.valueOf(1))` 是经典边界：在 `List<Integer>` 中，前者优先匹配索引重载，后者表示删除值 1。看到“删错元素”时，先检查编译期选择了哪个方法签名，不要只盯运行结果。

`contains` 与 `remove(object)` 使用相等性，而不是必须使用 `==`。两个不同实例只要 `equals` 返回 true，就被列表查找视为相等。列表允许它们同时存在；“能查到相等值”不等于“自动去重”。如果业务真正要求唯一性，下一章会用 Set 表达，而不是每次向 List 加入前做一次全表扫描。

## 4. ArrayList：动态数组为何通常是 List 默认选择

`ArrayList` 内部以可增长数组保存引用。位置 i 对应数组中的槽位，所以 `get(i)` 和 `set(i, value)` 能直接定位，JDK 25 API 将这些操作列为常数时间。尾部追加在仍有容量时只写一个槽位；容量不足时要分配更大的存储并复制已有引用，因此单次扩容较贵，但一串追加的平均成本是摊还常数时间。

“摊还 O(1)”不是“每一次都同样快”。若一次导入明确知道大约会有十万条，可以用合适初始容量或 `ensureCapacity` 降低反复扩容；不要为了微小列表猜容量，也不要把增长策略的具体倍数写进业务合同，因为官方只保证摊还成本，不保证内部倍率。

在中间插入或删除时，后续引用需要移动，通常是 O(n)。`contains`、`indexOf` 也要从前向后比较，最坏 O(n)。遍历整个列表本来就是 O(n)。这些复杂度描述的是规模增长趋势，不是某台机器上的固定毫秒数；n 很小时，简单、连续内存友好的 ArrayList 往往比更复杂结构更好。

ArrayList 的容量不等于 `size()`。容量是内部可放多少元素，size 是已经存在多少元素。清空、删除和扩容细节不应从反射或序列化结果猜测。业务测试只断言合同可观察行为，例如顺序、元素、大小与异常；不要断言私有数组长度。

## 5. LinkedList：知道它，不把“链表插入 O(1)”当万能结论

`LinkedList` 是双向链表，同时实现 `List` 与 `Deque`。每个节点保存元素以及前后链接。已握有某个节点位置时，改链接可以很快；但 List API 通常给的是数值索引，`get(i)` 必须从首端或尾端沿链接走到目标，距离决定成本。循环中反复 `get(i)` 遍历 LinkedList，可能把本应 O(n) 的工作放大成 O(n²)。

所以“链表中间插入是 O(1)”省略了寻找插入点的成本。若调用者只有索引，先 O(n) 找位置，再做链接修改；若调用者持有 `ListIterator` 且已走到位置，局部插删才具有不同成本。真实选择还要考虑每个节点的额外引用、对象分配、缓存局部性和代码可读性。

对普通业务列表，默认从 `ArrayList` 开始通常更可解释。需要队列或栈时，优先表达为 `Deque` 并使用 `ArrayDeque`；不要仅因为 LinkedList 同时实现多个接口就把它当通用容器。只有测量和访问模式证明链式结构合适时再选它。

## 6. 复杂度速查不是承诺所有实现相同

以下是典型单线程实现的选择提示，不是 `List`/`Queue` 接口对所有实现的统一保证：

| 操作 | ArrayList | LinkedList | ArrayDeque |
| --- | --- | --- | --- |
| 按索引读取 | O(1) | O(n) | 不提供随机索引 |
| 尾部追加 | 摊还 O(1) | O(1) | 摊还 O(1) |
| 首部插入/删除 | O(n) | O(1) | 摊还 O(1) |
| 中间按索引插删 | O(n) | 查找 O(n)，定位后改链 | 不适用 |
| 查找某值 | O(n) | O(n) | O(n) |
| 全量遍历 | O(n) | O(n)（用迭代器） | O(n) |

复杂度只是一项决策维度。还要问：是否需要索引、是否允许重复、顺序是位置/FIFO/LIFO 中哪一种、是否要稳定快照、空集合如何表达、调用者能否修改、是否跨线程。先选合同，再选实现，最后在有性能证据时调整。

## 7. Iterator：一次遍历会话，而不是另一个集合

`Iterable` 表示对象能产生迭代器；增强 for 循环会使用迭代协议。`Iterator<E>` 代表一次有当前位置的遍历会话，核心操作是 `hasNext()`、`next()` 和可选的 `remove()`。`hasNext` 只询问是否还有元素；`next` 才推进并返回元素。没有下一个元素时调用 `next` 会抛 `NoSuchElementException`。

最基础写法是：

```java
Iterator<WorkOrder> iterator = orders.iterator();
while (iterator.hasNext()) {
    WorkOrder order = iterator.next();
    if (order.cancelled()) {
        iterator.remove();
    }
}
```

`iterator.remove()` 删除最近一次 `next()` 返回的元素。还未调用 `next` 就 remove，或对同一个元素连续 remove，行为会被合同拒绝。并非每个迭代器都支持删除；不可修改集合的迭代器会抛 `UnsupportedOperationException`。

增强 for 适合只读遍历。需要在遍历中删除当前项时，显式迭代器能把修改与遍历状态绑定。若条件简单，`removeIf(predicate)` 更直接。若要加入多个新项或重排，常见安全做法是先计算变更，再在遍历结束后统一应用，或者构造新列表。

## 8. 为什么 foreach 中直接 list.remove 会失败

ArrayList 和 LinkedList 的迭代器通常是 fail-fast。迭代器建立后，如果集合在迭代器之外发生结构修改，下一次迭代检查可能抛 `ConcurrentModificationException`。这是尽早暴露 bug 的机制，不是线程安全保证，也不能成为业务正确性依赖。

“结构修改”通常指加入或删除元素、改变底层结构；单纯 `set` 替换已有位置的值通常不算。但不要依赖模糊猜测，阅读具体实现合同并优先写清晰代码。即使某次错误修改没有立刻抛异常，也不表示合法；官方明确说明 fail-fast 是 best effort。

异常名包含 Concurrent，不代表只有多线程才会发生。单线程 foreach 中直接 `orders.remove(order)` 就足以触发。排查时看堆栈的第一处业务源码：找到迭代器创建/推进位置，再找期间所有结构修改路径。不要用 catch 后忽略异常，也不要为了“修复”而换成索引循环却遗漏相邻元素。

## 9. 可变、不可修改、只读视图与快照

Java 的“不可修改”首先描述通过某个引用允许的操作，不自动保证元素对象自身不可变，也不必然说明数据是否与原集合共享。

`List.of(a, b)` 创建不可修改列表，不能 add/remove/set，并拒绝 null。`List.copyOf(source)` 返回包含 source 当前迭代结果的不可修改列表；对通常的可变 source，它提供一个集合结构快照，之后 source 增删不会改变这个结果。若元素本身可变，两个列表仍可能引用同一元素，所以这只是浅层快照。

`Collections.unmodifiableList(source)` 返回不可修改**视图**。调用者不能通过视图修改，但原 source 的合法修改会在视图中可见。它适合“由所有者继续维护、观察者只读”的边界；不适合要求历史时点稳定的审计快照。把视图误称为 immutable copy，会制造很隐蔽的时间变化。

如果把内部可变列表直接从 getter 返回，调用者可绕过类的不变量。可根据合同返回 `List.copyOf`、不可修改视图，或只暴露业务操作。反过来，如果方法参数收到调用者列表并准备长期保存，也要决定是取得所有权、复制，还是明确约定共享；不要默默共享后再惊讶于外部修改。

## 10. Queue：成对 API 把空队列策略写进代码

Queue 的操作成对出现：

| 意图 | 抛异常形式 | 特殊值形式 |
| --- | --- | --- |
| 插入 | `add(e)` | `offer(e)` 返回 boolean |
| 读取并移除队首 | `remove()` | `poll()` 空时返回 null |
| 只读取队首 | `element()` | `peek()` 空时返回 null |

无容量限制的 ArrayDeque 中 `offer` 通常成功；有界队列可能拒绝插入并返回 false。选择 `add` 还是 `offer` 不是风格问题，而是在表达“插入失败是异常合同，还是正常可处理分支”。本章不进入并发/阻塞队列，但这个判断习惯会延续到后续。

Queue 通常但不必然是 FIFO。若具体实现是 ArrayDeque，尾部 offer、首部 poll 就是 FIFO。优先队列则根据优先级选队首。因此变量类型写 Queue 只说明允许的操作，仍要知道实现提供的顺序合同。

队列实现一般不允许 null，因为 `poll`/`peek` 用 null 表示空。即使某个实现允许，也会让“空”与“真实 null 元素”难以区分。FactoryCare 待处理队列应存有效任务对象；缺失任务应在进入队列前被校验或用明确结果类型处理。

## 11. Deque：一套双端 API，清楚表达队列或栈

Deque 从两端提供 `addFirst/addLast`、`offerFirst/offerLast`、`removeFirst/removeLast`、`pollFirst/pollLast`、`getFirst/getLast`、`peekFirst/peekLast`。把方向写全通常比依赖简写更易审查。

实现 FIFO：统一 `offerLast(e)`，统一 `pollFirst()`。实现 LIFO：统一 `push(e)` 与 `pop()`，它们对应首端；也可以统一 `addLast(e)` 与 `removeLast()`，但团队必须保持一套方向。最危险的是一处向尾部加、另一处也从尾部取，却把结果称为 FIFO。

`ArrayDeque` 是可增长数组实现，不允许 null，大多数双端操作是摊还 O(1)。JDK 25 API 明确提示，它通常比旧 `Stack` 用作栈更快，也通常比 LinkedList 用作队列更快。它不是线程安全容器；本章所有示例都在单线程执行，不能把同一实例直接共享给并发工人。

撤销栈只保存“可撤销动作”还不够。还要定义动作是否已经成功、撤销失败怎么办、是否支持 redo、栈最大长度与敏感数据清理。本章只验证 LIFO 容器语义，不把一个 Deque 冒充完整事务或审计系统。

## 12. 选择准则：先问访问语义，再问实现

可以按下面顺序做决定：

1. 需要保留每个位置、允许重复、可能随机读取吗？选 `List`，通常从 ArrayList 开始。
2. 只需要按处理顺序加入和取出吗？暴露 `Queue`，通常用 ArrayDeque；明确实现是否真的 FIFO。
3. 需要两端操作或撤销栈吗？暴露 `Deque`，通常用 ArrayDeque。
4. 需要唯一元素或按键查值吗？不要强行用 List；下一章选择 Set/Map。
5. 需要排序吗？区分“偶尔生成一个排序列表”与“集合始终维护排序”；比较器和排序集合在后续章节展开。
6. 需要多线程共享吗？本章结构不够；要定义所有权、同步或使用并发集合。

API 参数也要暴露最小能力。只需要遍历时可接收 `Iterable` 或 `Collection`，不必索引就不要强迫调用者传 `List`。只需要 FIFO 操作时接收 Queue，避免方法内部随意按索引读取。返回类型同理：合同只承诺 List 时，不要让调用者依赖 ArrayList 私有选择。

## 13. equals、排序与本章边界

List 的位置合同不要求元素唯一，但多个方法依赖 `equals`：`contains`、`indexOf`、按对象 remove 等。如果领域对象只继承 Object 默认 `equals`，两个字段相同但实例不同的工单仍不相等；若 record 表达值对象，它会按组件生成值相等性。相等性的完整规则在对象合同章，哈希相等性在下一章。

这些 List 查找通常不使用 `hashCode`。因此“只覆写 equals、忘记 hashCode”的错误在 List 测试里可能暂时不暴露，一换成 HashSet/HashMap 就失败；相等对象必须拥有相同 hashCode。这里把它作为迁移边界提醒，不提前实现哈希集合机制。

列表排序会调用自然顺序或 Comparator。比较器若不稳定、一会儿返回不同结果，排序可能失败或产生难以理解结果。若比较结果为 0，不代表两个对象必须 `equals`；对 List 排序，这通常只影响相对顺序和查找解释，而对 TreeSet/TreeMap 会影响是否被视为同一键，下一章会专门标出。

不要用排序掩盖错误的数据结构。例如每次从 List 取“最早工单”前都全量排序，可能说明真正需要优先队列或数据库查询；反过来，仅为了页面展示一次按名称排序，复制列表后排序通常比让领域集合永久按名称维护更简单。

## 14. FactoryCare 连续场景：输入、调度、撤销、发布

FactoryCare 接收三张报修单 `WO-101`、`WO-102`、`WO-103`。接入层先用 List 保留原始提交顺序，便于生成确定的校验报告；这里允许相同对象重复出现，以便诊断上游重试，不能悄悄去重。验证通过后，把可调度任务依次 `offerLast` 到 ArrayDeque，工人分配器用 `pollFirst` 获取，形成 FIFO。

管理员在编辑工单时，把每个已成功动作压入独立 Deque。点击撤销时弹出最后一个动作，形成 LIFO。这里的动作栈属于一次编辑会话，不与全局调度队列混用；即使两者底层都用 ArrayDeque，它们的业务合同也不同。

发布给报修人的时间线需要稳定。服务内部可以继续维护可变 ArrayList，但响应边界返回 `List.copyOf(timeline)`。若返回 `Collections.unmodifiableList(timeline)`，调用者虽然不能写，服务后续追加仍会改变已持有视图；如果响应被用于签名或审计，这会违反时点一致性。

一个最小骨架如下：

```java
List<String> received = new ArrayList<>(List.of("WO-101", "WO-102"));
Queue<String> dispatch = new ArrayDeque<>();
dispatch.addAll(received);
String first = dispatch.poll();

Deque<String> undo = new ArrayDeque<>();
undo.push("assign:" + first);
String latestAction = undo.pop();

List<String> published = List.copyOf(received);
```

这段代码只展示合同，不处理持久化、并发、事务、权限或消息重放。不要把内存队列当成可靠消息系统；进程退出会丢失状态，多个实例也不会自动共享顺序。

## 15. 故障诊断：从第一处可信证据开始

### 15.1 ConcurrentModificationException

先读异常类型和第一处业务栈帧，确认是在 iterator 的 `next`、`remove` 还是集合其他操作处发现。回看同一遍历会话中谁改变了结构。修复为迭代器 remove、`removeIf`、收集待删项后统一删除，或构造新列表。不要 catch 后继续，因为遍历状态已经不可信。

### 15.2 NoSuchElementException

若来自 `ArrayDeque.remove`、`element`、`pop`，检查空集合是不是正常业务分支。正常空分支使用 poll/peek 并显式处理 null；若空意味着不变量被破坏，保留抛异常形式并在更早位置验证。不要无条件把异常 API 全换成 null API，否则真正的状态错误会被吞掉。

### 15.3 UnsupportedOperationException

查看集合来源：`List.of`、`List.copyOf`、`Collections.unmodifiableList`、`Arrays.asList` 都有不同修改边界。异常不是“Java 集合随机坏了”，而是调用了该实现不支持的可选操作。若业务需要修改，创建明确可变副本 `new ArrayList<>(source)`；若不该修改，修复调用者而不是偷偷复制。

### 15.4 IndexOutOfBoundsException

同时记录 index 和 size。常见错误是使用 `<= size`、把 size 当最后索引、删除后仍用旧索引，或异步状态变化。本章单线程示例先用最小输入 0、1、2 个元素复现。能用 foreach/iterator 表达时，不为遍历制造索引。

### 15.5 顺序正确但业务顺序错误

程序不抛异常，却把 `pollLast` 写成 FIFO，属于更危险的静默错误。测试应使用至少三个有区别的元素，断言完整离开顺序；只用一个元素无法区分 FIFO 与 LIFO。日志要记录 operation、before、returned、after，而不是只打印 size。

### 15.6 性能随数据量恶化

先画出嵌套操作：循环 n 次，每次 `contains` O(n)，整体 O(n²)；LinkedList 循环按索引 get 也可能 O(n²)。用 10、100、1000 等规模观察趋势，但不要把一次微基准当普遍结论。若问题是唯一性或索引，换合同；若只是小集合，保持简单实现。

## 16. 测试设计：断言合同，而不是实现偶然细节

顺序集合至少覆盖：空、单元素、多元素、重复元素、首尾、非法索引、空队列、不可修改写入、遍历删除。FIFO 测试要断言 A/B/C 的输出是 A/B/C；LIFO 要断言 C/B/A。快照测试要在生成结果后修改源集合，确认 copy 不变、view 随源变化，并确认两者都拒绝经自身引用修改。

异常测试应同时验证异常类型和触发操作，但不要依赖完整英文错误消息，因为消息不是跨实现稳定合同。复杂度不能由单元测试精确证明；可以检查实现选择与访问模式，并用受控规模实验作为诊断证据。

所有配套验证器固定输入、固定输出，不读取网络、当前时间、随机数或环境语言消息。故障程序只对异常类名做断言，因此在离线 JDK 25 基线下可重复。

## 17. 与 TypeScript/Vue 经验对照

Java `List` 类似“明确元素类型的有序数组接口”，但不能把 Java ArrayList 等同 JavaScript Array。JS Array 同时承担动态数组、稀疏索引和许多高阶操作；Java 集合接口与实现分得更细，泛型主要在编译期生效，修改操作还可能是 optional。

Java 的 `List.copyOf` 可类比在边界创建浅层只读快照，但 TypeScript 的 `readonly T[]` 主要是静态类型限制，运行时对象仍可能被其他引用修改。Vue 响应式只读代理也不等同 Java 不可修改集合。对照的价值是问“谁能通过哪个引用修改、底层是否共享、元素是否也不可变”，而不是机械翻译语法。

JS 常用数组 `shift` 做队列，但连续移动元素可能代价高；Java ArrayDeque 直接表达双端操作。前端状态里“撤销栈”和“待处理队列”也有相同 FIFO/LIFO 区别，因此先写出进入端和离开端的习惯可以跨语言复用。

## 18. 分层练习与需求变更

### 预测题

1. List `[A, B, A]` 的 size、`indexOf(A)` 和 `lastIndexOf(A)` 各是什么？
2. 向 Deque 尾部加入 A/B/C，再连续 `pollFirst`，输出顺序是什么？改成 `pollLast` 呢？
3. `List.copyOf(source)` 与 `unmodifiableList(source)` 建立后，source 加入 D，各自是否看见 D？
4. foreach 中直接删除当前元素，异常一定在 remove 那一行抛吗？为什么不能依赖它保证正确？

### 动手题

实现一个 5 条输入的调度器：List 保存原输入，Queue 消费，Deque 保存最近三个已执行动作。打印每步 before/operation/result/after，固定断言 FIFO、LIFO 和空 poll。

### 故障题

把 Queue 的 `poll` 改为 `remove`，让程序在消费完后多取一次；保留异常证据。随后决定空队列是正常结束还是状态错误，并选择匹配 API。再把迭代器删除改成 list 直接删除，复现并修复 CME。

### 需求变更题

调度规则改为“紧急任务优先，同优先级按进入顺序”。普通 Queue 已不足以描述全部顺序。先写合同和可验证样例，不急着改为某个具体类；指出哪些规则属于后续优先队列/比较器章节。

### 关闭 AI 独立练习

限时 35 分钟完成公开 starter。要求不查私有解，先写 expected，运行初始失败，逐个修复 FIFO、LIFO、安全删除与稳定快照，最后口述为什么每个修复与合同匹配。

## 19. 复述、间隔复习与速查

### 120 秒复述模板

“List 管位置和重复，典型 ArrayList 用动态数组，随机读取 O(1)、中间移动 O(n)。Queue 管队首，FIFO 只是一类实现；成对 API 决定空/容量失败是异常还是特殊值。Deque 管两端，也能表达栈。遍历中结构修改要通过迭代器或另行安排；fail-fast 只检测 bug。不可修改视图可能与源联动，copyOf 是集合结构快照。选择时先看访问语义，再看实现和复杂度。”

### 复习节奏

- 1 天后：不看表重画 List/Queue/Deque 的允许操作和方向。
- 3 天后：用三个元素手算 FIFO、LIFO、首尾 API，并解释两组空队列 API。
- 7 天后：重做一次 CME 与不可修改视图故障，不看旧修复。
- 14 天后：为一个真实模块解释为何选择 ArrayList 或 ArrayDeque，并指出未解决的并发/持久化问题。

### 最小速查

| 需求 | 首选表达 | 常见实现 | 避免 |
| --- | --- | --- | --- |
| 有位置、可重复 | `List<E>` | `ArrayList` | 默认用 LinkedList 做随机访问 |
| FIFO | `Queue<E>`/`Deque<E>` | `ArrayDeque` | 用一个元素测试顺序 |
| LIFO/撤销 | `Deque<E>` | `ArrayDeque` | 新代码使用旧 Stack |
| 空时正常返回 | `poll`/`peek` | 明确 null 分支 | 与允许 null 的设计混用 |
| 空是合同破坏 | `remove`/`element`/`pop` | 让异常暴露 | catch 后忽略 |
| 稳定浅快照 | `List.copyOf` | 不可修改 List | 把 view 当 copy |
| 观察所有者变化 | `unmodifiableList` | 共享只读视图 | 宣称深度不可变 |
| 遍历删除当前项 | `Iterator.remove`/`removeIf` | 可变集合 | foreach 中直接改结构 |

## 20. 官方资料与当前性边界

以下均为 Oracle Java SE 25 官方 API，复核日期为 **2026-07-16**：

- [List](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/List.html)：位置、重复、可选操作、`of`/`copyOf` 的不可修改合同。
- [ArrayList](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/ArrayList.html)：动态数组、常数/摊还/线性成本以及 fail-fast 的 best-effort 边界。
- [LinkedList](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/LinkedList.html)：双向链表、按索引遍历机制以及 List/Deque 双接口。
- [Iterator](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Iterator.html)：`next`、可选 `remove` 与底层集合被其他方式修改后的未指定行为。
- [Queue](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Queue.html)：成对操作、队首与“通常但不一定 FIFO”。
- [Deque](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Deque.html) 与 [ArrayDeque](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/ArrayDeque.html)：双端、FIFO/LIFO 映射、null 禁止和典型复杂度。
- [Collections](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Collections.html)：`unmodifiableList` 不可修改视图与 backing list 的共享关系。
- [Object.equals/hashCode](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Object.html)：List 的相等性查找与后续哈希集合迁移边界。

稳定核心是接口合同、遍历规则和复杂度分析方法。JDK 内部容量增长倍率、异常消息文本和未承诺的迭代偶然顺序不是本章合同。其他 JDK、Windows/Linux、非 Oracle 构建和并发访问尚未在本批验证；使用时应重新核对目标运行时官方文档。
