# Week 03 深度教学包：类、对象、构造器与封装

本包对应 [Week 03 周计划](../../weeks/week-03.md)。本周只建立 class/object/reference/constructor/encapsulation/static/final；record、enum、interface、继承和多态在 Week 04。

## 文件导航

| 文件 | 用途 |
| --- | --- |
| [concepts.md](./concepts.md) | 类、对象、引用、构造器、访问控制、不变量、static/final |
| [labs.md](./labs.md) | 从 public 数据袋重构为有行为的对象 |
| [assessment.md](./assessment.md) | 无 AI 对象建模题 |
| [answers.md](./answers.md) | 提交后的设计/测试校准 |
| [interview.md](./interview.md) | 类与封装追问 |

## 前置证据

- Week 02 控制流/数组/方法/调试通过；
- 能写纯静态方法和 JUnit；
- 优先级规则有决策表；
- 不使用 Lombok/Spring/ORM 生成对象模型。

## 时间

| 块 | 时间 |
| --- | ---: |
| 类、对象、引用 | 2—3h |
| 构造器、this、访问控制 | 3h |
| 封装、不变量、行为 | 3h |
| static/final/防御性复制 | 2—3h |
| FactoryCare Device/WorkOrder | 4—5h |
| 无 AI/复述/复盘 | 1—2h |

## 通过结果

- 不再把所有业务代码放 static 工具类；
- Device/WorkOrder 只能通过有效入口创建；
- 状态变化用行为方法而非任意 setter；
- 能证明 reference alias、mutable static 和内部数组泄漏；
- 能关闭 AI 增加一条不变量。
