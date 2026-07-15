# Week 07 深度教学包：Lambda、Stream 与 Optional

本教学包服务于[第 7 周计划](../../weeks/week-07.md)。目标不是把循环换成链式调用，而是学会：

> 先定义输入、输出、排序、空结果和错误语义，再选择循环或 Stream；声明式写法只有在数据流更清楚时才有价值。

## 本周完成标准

完成后你应当能够：

1. 解释函数式接口、Lambda 捕获、方法引用和 effectively final；
2. 逐步说清 Stream 每个阶段的元素类型；
3. 解释惰性、中间操作、终止操作和短路；
4. 使用 filter、map、flatMap、排序、分组、聚合与 toMap；
5. 主动处理重复 key、空集合、并列和稳定排序；
6. 识别 map/peek 中的副作用和 parallelStream 风险；
7. 正确选择 Optional 的 map、flatMap、orElseGet 和 orElseThrow；
8. 知道 Optional 不应普遍用于字段、参数或集合元素；
9. 为 FactoryCare 完成组合查询与统计服务；
10. 无 AI 完成栈或队列题，并说明复杂度。

## 建议学习顺序

| 顺序 | 材料 | 时间 | 证据 |
| --- | --- | ---: | --- |
| 1 | [概念讲义](./concepts.md) | 3—4h | 一张 Stream 元素类型变化图 |
| 2 | [最小实验与故障注入](./labs.md) | 5—6h | 循环/Stream 对照和失败测试 |
| 3 | FactoryCare 增量 | 3—4h | 查询、看板统计、稳定排序 |
| 4 | [面试追问](./interview.md) | 1h | 录音回答 8—10 题 |
| 5 | [无 AI 考核](./assessment.md) | 2h | 报表、两种实现、栈/队列题 |
| 6 | [答案册](./answers.md) | 1h | 对照后完成一个变体 |

## 本周最重要的判断

不要问“这个需求能否用 Stream”，而要问：

- 这个过程是否是一条清晰的数据变换管道？
- 是否需要复杂提前退出、异常恢复或多处状态更新？
- 一次循环是否比嵌套 Collector 更容易审查？
- 排序和并列规则是否被代码显式表达？
- 数据量和遍历次数是否可接受？
- 未来维护者能否在调试器里看懂？

循环和 Stream 都是工具。本周满分答案经常是“保留循环版，因为它更清晰”。

## FactoryCare 本周切片

- WorkOrderQueryService：状态、优先级、设备与时间范围组合筛选；
- MaintenanceDashboardService：状态占比、设备未关闭数、重复故障设备；
- Repository.findById：用 Optional 表达可能缺失；
- 应用边界：把缺失转换为明确业务异常；
- 同一项查询的循环/Stream 对照与决策记录。

仍然不接 Spring、数据库或 Web API。

## AI 使用边界

可以让 AI：

- 把自然语言查询拆成数据流；
- 生成重复 key、空集合、并列的反例；
- 审查副作用、重复遍历与错误 Optional；
- 比较实现，但必须提供具体证据。

必须由你：

- 先写查询语义和稳定排序；
- 说清每一步元素类型；
- 亲手把一个 Stream 改回循环；
- 解释为什么选择最终版本；
- 无 AI 完成新报表和算法题。

## 交付清单

- [ ] 函数式接口与捕获实验；
- [ ] Stream 惰性、短路、flatMap、toMap、groupingBy 实验；
- [ ] Optional 的正确/错误用法对照；
- [ ] FactoryCare 查询与看板统计；
- [ ] 循环/Stream 决策记录；
- [ ] 空、重复、并列、稳定排序测试；
- [ ] 栈或队列无 AI 题；
- [ ] 周评分至少 75，关键分项过线。

## 索引

- [概念讲义](./concepts.md)
- [实验、FactoryCare 增量与故障注入](./labs.md)
- [无 AI 考核](./assessment.md)
- [独立答案册](./answers.md)
- [面试题与追问](./interview.md)
- [阶段考核总规则](../../ASSESSMENTS.md)
- [FactoryCare 总规格](../../PROJECT_SPEC.md)
