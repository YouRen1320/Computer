# Week 05 深度教学包：集合、泛型与 equals/hashCode

本周从“一个设备/工单”扩展到“多个对象如何组织、查找、去重、排序和安全返回”。FactoryCare 会得到领域仓储接口和内存实现，但仍不接 Spring、数据库、缓存、线程或 Stream。

对应[Week 05 计划](../../weeks/week-05.md)。核心判断顺序是：先说明业务需要顺序、唯一、按 key 查找、队列还是排序，再选择集合；不能先选 `HashMap` 再反推理由。

## 文件导航

1. [权威概念入口](./concepts.md)：转到百科中的集合选择、复杂度、泛型、相等性、排序、快照和仓储章节。
2. [实验手册](./labs.md)：可变 key、只读视图、泛型结果、内存仓储和双指针。
3. [无 AI 考核](./assessment.md)：120 分钟分组、去重、快照、测试和口述。
4. [独立答案册](./answers.md)：关键实现、测试点和错误校准。
5. [面试训练](./interview.md)：Java集合/泛型高频追问。
6. [FactoryCare 状态机](../../PROJECT_SPEC.md#4-工单状态机)：本周不得新增状态词。

## 15—18 小时时间映射

| 环节 | 时间 | 证据 |
| --- | ---: | --- |
| 讲义与集合选择表 | 2.5h | 访问模式→集合决策表 |
| 集合/迭代实验 | 1.75h | List/Set/Map/Deque边界测试 |
| 泛型与PECS | 1.75h | `PageResult<T>`和签名说明 |
| equals/hashCode故障 | 2h | HashSet/HashMap失败复现 |
| Comparator与快照 | 1.25h | 稳定排序、结构快照测试 |
| FactoryCare内存仓储 | 3—3.5h | 两个接口、两个实现、查询服务 |
| 双指针算法 | 0.75h | 不变量、边界、复杂度 |
| 集成复验与AI审查 | 1.5h | 故障测试、diff审查、命令行复验 |
| 无AI考核 | 2h | 分组去重实现与测试 |
| 求职与复盘 | 1h | 集合/泛型口述与项目证据 |

以上合计约 17.5—18 小时；已有集合基础时，优先压缩讲义，不压缩故障实验和无 AI 考核。

## FactoryCare 本周完成定义

- `EquipmentRepository`：保存、按 id 查询、判断编码是否存在、列出结构快照；
- `WorkOrderRepository`：保存、按 id 查询、列出结构快照；
- 内存实现内部使用恰当 Map，但不暴露内部可变集合；
- 重复 id、重复设备编码和查询不存在的行为明确；
- `PageResult<T>` 或同等轻量泛型结果有真实用例；
- 工单按优先级降序、创建顺序稳定排序；
- WorkOrder/Equipment 的实体相等性基于稳定 id，且有契约测试；
- “未关闭”统一指状态既不是 `CLOSED` 也不是 `CANCELLED`；后续周次复用该领域语义，不重新发明定义，也不创建词表之外的状态。

由于完整状态转换要到 Week 18 才实现，本周查询测试中的非 `CREATED` 工单只作为**已有状态样本**：优先使用 `src/test` 中的 fixture；若生产实体不允许安全构造此类样本，可为查询练习使用不可变的 `WorkOrderSnapshot` 投影。不得为了测试加入 public `setStatus`，也不能声称这些样本已证明合法转换链路。

结构快照只保证调用方不能增删返回的集合，也不与仓储内部容器共享；若元素实体本身仍可变，要明确它不是深拷贝。

## 通过标准

- 根据访问模式解释 List/Set/Map/Deque 选择；
- 能说出 ArrayList、HashMap/HashSet 常见操作的平均复杂度及退化边界；
- 理解泛型不协变、raw type 风险、PECS 和类型擦除；
- 陈述 equals/hashCode 契约并复现可变 key 故障；
- Comparator 不依赖 ordinal，排序与相等性分离；
- 仓储不泄漏内部 Map/List，重复行为有测试；
- 无 AI 完成分组、去重、嵌套快照和边界测试；
- 双指针题能给循环不变量、`O(n)` 时间与 `O(1)` 额外空间。

## 明确不做

- 不研究 HashMap 红黑树、扩容常量或源码；
- 不用 Stream/parallelStream 替代主要循环；
- 不实现线程安全、数据库、缓存或 Spring Bean；
- 不创建万能 `BaseRepository<T, ID>`；
- 不引入任何自创工单状态；
- 不刷竞赛题数量。

通过后回到[Week 06 正式计划](../../weeks/week-06.md)。
