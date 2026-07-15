# Week 02 深度教学包：OOP、record、enum 与 Value Object

本周把 Week 01 的字符串和参数，升级为能表达业务身份、不变量和值语义的纯 Java 模型。重点不是“类越多越专业”，而是让非法设备编号、空故障描述和魔法字符串更难进入系统。

对应[原 Week 02 计划](../../weeks/week-02.md)。仍然只使用 Java 25、JUnit 和内存对象，不接 Spring、数据库、JSON、Lombok 或完整状态机。

## 文件导航

1. [系统讲义](./concepts.md)：对象、封装、不可变、record、enum、interface、Entity/VO/DTO。
2. [实验手册](./labs.md)：对象边界、浅层可变故障、FactoryCare 第一版模型和字符串算法。
3. [无 AI 考核](./assessment.md)：120 分钟实现 `EquipmentCode` 并接入模型。
4. [独立答案册](./answers.md)：参考模型、关键代码、测试与常见错误。
5. [面试训练](./interview.md)：只含 OOP 高频题与追问；提交回答后在独立答案册校准。
6. [FactoryCare 项目规格](../../PROJECT_SPEC.md)：状态候选必须使用唯一词表。

## 15—18 小时时间映射

| 环节 | 时间 | 证据 |
| --- | ---: | --- |
| 讲义、官方资料、TS类比 | 3h | 类型选择表和类比失效记录 |
| class与封装实验 | 2h | 无公共setter的行为模型 |
| record/enum实验 | 2.5h | 不变量、稳定code、相等性测试 |
| interface与组合实验 | 1.5h | 一个小契约和方案比较 |
| 深层不可变故障实验 | 1h | 失败测试、修复和解释 |
| FactoryCare领域模型 | 3—4h | 设备、工单、值对象、规则重构 |
| 字符串/哈希思想算法 | 0.75—1h | ASCII约束、频次算法、复杂度 |
| 无AI考核 | 2h | 代码、测试、口述 |
| 求职与复盘 | 1h | OOP口述、旧TS模型对照 |

## 本周建模边界

### 应当产生

- `EquipmentId`、`WorkOrderId`、`FaultDescription` Value Object；
- `Priority` 与 `WorkOrderStatus` enum；
- `Equipment` 与 `WorkOrder` 普通 class；
- 优先级规则返回 `Priority`；
- 一个小型 interface 用于表达协作契约；
- 每种类型的不变量与行为测试。

### 刻意不产生

- 完整工单状态转换方法；
- 仓储实现和集合；
- 任意 `setStatus`；
- `BaseEntity`、复杂继承、DDD术语层级；
- Jackson/MyBatis需要的无参构造器；
- Spring注解和数据库字段。

## 唯一状态词表

`WorkOrderStatus` 只能声明项目已经确认的候选：

`CREATED`、`TRIAGED`、`ASSIGNED`、`ACCEPTED`、`IN_PROGRESS`、`PENDING_PARTS`、`PENDING_APPROVAL`、`RESOLVED`、`VERIFIED`、`CLOSED`、`REOPENED`、`CANCELLED`。

本周只让新工单以 `CREATED` 创建，不实现状态图，也不增加任何近义状态词。

## 通过标准

- 能结合代码区分 class、record、enum、interface；
- 能解释封装是不变量，不是 getter/setter 数量；
- 能区分 Entity、Value Object、DTO；
- 关键对象构造时拒绝明显非法状态；
- record 的引用组件不会因外部修改破坏不可变承诺；
- enum 使用稳定 code，不用 ordinal；
- 模型无公共可变字段、万能 setter、可变静态业务状态或无意义继承；
- 字符串算法明确字符集假设、重复规则和复杂度；
- 无 AI 完成 `EquipmentCode` 变更及测试。

按[考核标准](../../ASSESSMENTS.md)达到 75 分后进入[Week 03](../week-03/README.md)。
