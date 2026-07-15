# Week 07 无 AI 考核与评分标准

## 1. 规则

- 编码 120 分钟，口述 20 分钟；
- 允许 JDK 官方 API 和项目源码；
- 禁止任何 AI、答案搜索和复制现成报表；
- 必须先写输入、输出、空结果、重复与并列规则；
- 完成后提交代码、测试、决策记录；
- 提交前不能阅读[答案册](./answers.md)。

## 2. 主任务：每种优先级中最早的未关闭工单

实现一个报表：

    Map<Priority, WorkOrderSummary>

需求：

- 只统计未关闭工单；统一定义为 `WorkOrderStatus` 既不是 `CLOSED` 也不是 `CANCELLED`；
- 每种优先级保留 createdAt 最早的一张；
- createdAt 相同时以 workOrderId 升序决定；
- 空仓储返回空 Map；
- 不修改输入工单；
- 输出是只读 Summary，不暴露实体；
- 不使用 parallelStream。

### 阶段 A：循环版

先写普通循环，明确：

- 如何集中复用“不是 `CLOSED/CANCELLED`”的未关闭语义；
- 如何比较候选；
- 如何处理新 priority；
- 为什么时间 O(n)；
- 额外空间与优先级种类有关。

### 阶段 B：Stream 版

再写 Stream 版。可以使用 groupingBy/minBy，也可以使用 toMap + merge，但必须：

- 说清每一步元素类型；
- 处理 Optional 结果；
- merge/min Comparator 包含 tie-breaker；
- 不调用 Optional.get；
- 不把副作用藏在 peek/map。

### 阶段 C：选择

只保留一版进入正式服务。写 150—300 字说明：

- 可读性；
- 遍历次数；
- 重复/并列语义；
- 错误处理；
- 调试与团队维护；
- 为什么没有选择另一版。

“Stream 更高级”或“循环一定更快”不得分。

## 3. 附加 FactoryCare 任务

为 MaintenanceDashboardService 增加：

- 各状态数量；
- 状态占比；
- 空集合时明确结果；
- 设备未关闭工单 Top 3；
- 并列时按 equipmentId 升序稳定输出；
- 仓储 findById 缺失转为 WorkOrderNotFound。

必测：

1. 空仓储；
2. 一条关闭工单；
3. 多状态；
4. 相同优先级和相同创建时间；
5. 多设备并列；
6. Optional 缺失；
7. 重复 key 规则。

## 4. 算法任务：有效括号

使用 Deque 实现：

- 输入仅包含圆、方、花括号；
- 空串有效；
- 交叉嵌套无效；
- 提前出现右括号无效；
- 结束时有剩余左括号无效；
- 时间 O(n)，空间 O(n) 最坏。

禁止使用字符串反复 replace 作为主解。

## 5. 口述

1. 函数式接口和 Lambda 目标类型；
2. effectively final 不代表对象不可变；
3. Stream 惰性与短路；
4. map 与 flatMap；
5. toMap 重复 key；
6. groupingBy 与 partitioningBy；
7. peek 的合理用途；
8. 为什么本周禁止 parallelStream；
9. Optional.map 与 flatMap；
10. orElse 与 orElseGet；
11. Optional 不适合哪些位置；
12. 循环比 Stream 更好的一个真实场景。

## 6. 100 分评分

| 部分 | 分值 | 满分标准 |
| --- | ---: | --- |
| 概念解释 | 20 | 口述至少 9/12 正确，能结合代码 |
| 最小实验 | 15 | 惰性、短路、重复 key、Optional 求值均有证据 |
| 项目增量（FactoryCare） | 25 | 报表与统计语义完整、输出 DTO、排序稳定 |
| 测试与排错 | 20 | 空、重复、并列、缺失、副作用均验证 |
| 无 AI 任务 | 15 | 两版实现、决策和算法题完成 |
| 复盘与求职 | 5 | 决策有证据，完成一组口述复盘 |

FactoryCare 25 分：

- 主报表循环版：5；
- Stream 版正确：5；
- 最终选择论证：4；
- 看板统计：6；
- Optional 边界与输出 DTO：5。

测试与排错 20 分：

- 空与单条：4；
- 重复/并列/稳定排序：6；
- Optional 和 orElse 行为：4；
- 无副作用、无 parallelStream：3；
- 失败测试先红后绿记录：3。

无 AI 15 分：

- 120 分钟内完成核心：8；
- 有效括号与测试：4；
- 能逐步说明元素类型：3。

## 7. 硬性门槛

总分至少 75，且：

- 项目增量（FactoryCare）至少 15/25；
- 测试与排错至少 12/20；
- 无 AI 至少 9/15；
- 无 Optional.get；
- 无 parallelStream；
- 无 map/peek 修改共享集合或实体；
- 排序有明确 tie-breaker；
- 空集合不除零；
- 两版使用同一测试语义。

硬性项失败需补考。

## 8. 补考变体

- 报表改为“每台设备最新一张已关闭工单”；
- 并列从 id 决胜改为全部返回；
- 统计 Top 3 改为所有并列第三名都返回；
- 有效括号改为最小栈；
- Optional 实验改为昂贵默认设备摘要。

## 9. 复盘

    总用时与得分：
    我最先写清的业务语义：
    我遗漏的空/重复/并列规则：
    Stream 中最难解释的一步：
    最终保留循环或 Stream：
    选择证据：
    AI 最容易在这里生成的坏代码：
    补考日期：
