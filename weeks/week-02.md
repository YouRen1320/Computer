# 第 2 周：OOP、record、enum 与 Value Object

## 定位

本周从“把代码写在方法里”升级到“用对象表达业务”。重点不是背面向对象术语，而是让无效状态更难出现、职责更清楚、规则更容易测试。FactoryCare 会形成第一版纯 Java 领域模型。

时间预算：15—18 小时。AI 可以协助生成样板，但对象边界、身份、不可变性和业务规则由你决定。

## 前置

- 能使用 Java 类型、方法、控制流和 JUnit。
- `WorkOrderPriorityCalculator` 测试全部通过。
- 能解释基本类型与引用类型、`String.equals` 和参数按值传递。
- 本周仍使用内存和纯 Java，不依赖 Spring 或数据库。

## 目标

- 理解类、对象、封装、构造、访问控制、静态成员和不可变性。
- 区分类、record、enum、interface 的适用场景。
- 区分 Entity、Value Object 和普通 DTO 的基本语义。
- 优先使用组合和接口边界，不把继承当默认复用工具。
- 用构造时校验阻止非法对象进入系统。
- 建立 FactoryCare 的设备、工单标识、优先级和状态模型。

## 完整概念清单

### 类与对象

- 类是类型定义，对象是运行时实例。
- 字段、实例方法、构造器、`this` 和对象生命周期。
- `public`、包可见、`protected`、`private` 的含义；默认最小可见性。
- getter 不是封装本身；真正的封装是通过行为维护不变量。
- `static` 属于类，实例成员属于对象；不把业务状态放进可变静态字段。
- `final` 字段、不可变引用和对象深层可变性的区别。
- 构造器校验、工厂方法和有意义的创建入口。

### 封装与职责

- 不变量、前置条件、后置条件。
- “贫血数据袋”与“所有逻辑都塞进实体”两个极端。
- 告诉对象做事，而不是取出所有字段在外部随意修改。
- 单一职责是变化原因清晰，不等于每个类只能有一个方法。
- 包边界和可见性也属于设计工具。

### record

- record 自动生成的组件访问器、构造器、`equals/hashCode/toString`。
- record 适合不可变数据载体和值语义，不等于任何 DTO 都必须用 record。
- compact constructor 中的校验。
- record 组件引用的对象仍可能可变；需要防御性复制。
- record 不适合需要可变生命周期、框架代理或复杂实体身份的场景。

### enum

- enum 是受限实例集合，不只是字符串常量。
- enum 字段、构造器和方法；避免依赖 `ordinal()` 持久化业务含义。
- 使用稳定业务码与显示文案分离。
- `switch` 对 enum 的穷尽检查。
- 当前只表达状态和优先级，完整状态机放到第 15 周。

### interface、抽象与组合

- interface 表达能力或协作契约。
- 实现类、动态分派和面向接口依赖。
- 抽象类只理解使用边界，不深入复杂继承层次。
- 组合优先于继承；“is-a”与“has-a”的基本判断。
- 默认方法和静态接口方法只了解存在，不作为主要复用手段。
- sealed class/interface 了解其封闭层级用途，不使用 preview 特性。

### Entity 与 Value Object

- Entity 通过身份连续性区分；Value Object 通过全部有效值相等。
- 标识对象优于到处传裸 `long/String`。
- Value Object 应不可变、自校验、具有领域名称。
- DTO 是边界传输形状，不承担核心领域不变量。
- 时间、金额、编号、描述、优先级都可能成为值对象，但不要为每个字段机械包一层。

### 对象关系与创建

- 一对一、一对多只作为对象关系，不提前映射数据库。
- 聚合概念仅做直觉介绍：一起维护一致性的对象范围。
- 工厂方法命名表达业务意图。
- 防止循环依赖、双向关系和任意 setter。

## 任务分配

| 模块 | 时间 | 任务 |
| --- | ---: | --- |
| 类与封装 | 3h | 构造器、访问控制、不可变性和行为方法练习 |
| record/enum | 2.5h | 创建并测试标识、描述、优先级和状态 |
| 接口与组合 | 2h | 定义仓储契约雏形和通知能力，不实现框架 |
| Value Object | 2.5h | 设计相等性、校验和防御性复制 |
| FactoryCare | 3—4h | 重构第 1 周规则并建立领域模型 |
| 无 AI 训练 | 2h | 新增值对象与规则变体 |
| 求职动作 | 1h | 准备 OOP 高频问题口述 |

建议练习：

1. 将裸字符串工单编号重构为 `WorkOrderId` record。
2. 将优先级和状态重构为 enum，并为其提供稳定 code。
3. 设计 `FaultDescription`，拒绝空白和超长内容。
4. 让 `WorkOrder` 通过行为修改必要状态，而不是公开所有 setter。
5. 比较“继承一个 BaseEntity”与“组合标识和值对象”的利弊，本周不引入 BaseEntity。

## FactoryCare项目增量

建立第一版纯 Java 领域模型：

- `EquipmentId`：不可为空且格式稳定的 Value Object。
- `WorkOrderId`：业务身份，不与数据库自增主键绑定。
- `FaultDescription`：自校验的文本 Value Object。
- `Priority`：enum，具备稳定业务 code，不依赖 ordinal。
- `WorkOrderStatus`：enum，只表达候选状态，暂不实现完整流转图。
- `Equipment`：具备设备身份和基本信息。
- `WorkOrder`：具备身份、设备、故障描述、优先级和当前状态。

将第 1 周计算器改为返回 `Priority`，并让创建工单时复用规则。所有构造入口必须拒绝关键字段缺失；不要为了 Jackson、MyBatis 或未来数据库提前添加无参构造和任意 setter。

## AI协作边界

可以让 AI：

- 根据你写出的对象职责检查是否存在明显重复或泄漏。
- 列出 class、record、enum、interface 的候选方案和取舍。
- 生成构造器、工厂方法、`toString` 等机械样板。
- 在你完成模型后寻找可构造的非法状态。

必须由你完成：

- 决定对象身份、相等语义、不变量和公开行为。
- 说明为什么某个类型是 Entity、Value Object、enum 或普通类。
- 检查 AI 是否偷偷加入公共 setter、可变静态状态或无业务含义的继承。
- 修改一个对象规则并确保调用方和测试同步变化。

如果 AI 给出“最佳实践”但无法结合 FactoryCare 的具体不变量说明理由，不直接采用。

## 无AI训练

本周从求职/复盘时段预留45—60分钟完成并记录：字符串与哈希表基础题；说明字符编码、重复键和复杂度边界。

关闭 AI，限时120分钟：

1. 新增 `EquipmentCode` Value Object：去除首尾空白、只接受约定格式、相同规范值相等。
2. 将 `Equipment` 中的裸字符串替换为该类型。
3. 补齐成功、空值、非法格式和相等性测试。
4. 口述为什么 Value Object 应在创建时校验，以及为什么 `record` 的引用组件仍可能破坏深层不可变。

## 求职动作

- 准备 90 秒内的口述：封装、继承与组合、interface 与抽象类、class 与 record、enum 为什么优于魔法字符串。
- 从 5 个南昌 Java 岗位中统计 OOP、设计模式、DDD 是否为必选或加分，不因“DDD”关键词提前学习完整战术模式。
- 将 FactoryCare 项目描述补充为“使用不可变 Value Object 表达工单身份和业务约束”，但不写“DDD 落地经验”。
- 找一个自己旧 NestJS/TypeScript 模型，写一页 Java 与 TypeScript 建模差异，不重写旧项目。

## 交付物

- FactoryCare 第一版纯 Java 领域模型。
- 所有 Value Object、enum 和核心实体的行为测试。
- 一页对象职责表：类型、身份、可变性、不变量、公开行为。
- 一页方案记录：为何使用组合，哪些地方刻意没有使用继承。
- 无 AI 训练代码与复盘。

## 验收标准

- 能用具体代码解释类、对象、封装、不可变性和访问控制。
- 能分别给出 class、record、enum、interface 合适与不合适的场景。
- 能区分 Entity、Value Object 和 DTO，不只背定义。
- 关键对象不能通过公开 API 创建空编号、空故障描述等明显非法状态。
- enum 不使用 ordinal 作为业务值；Value Object 的相等性符合业务语义。
- 领域模型没有公共可变字段、任意 setter、可变静态业务状态和无意义继承。
- 所有测试通过；你能独立新增字段规则并修复受影响测试。

## 明确不做

- 不实现完整工单状态机、SLA、审计或权限；这些在后续周次处理。
- 不学习 GoF 设计模式大全、复杂 DDD 聚合、领域事件或六边形架构术语堆砌。
- 不使用 Lombok 掩盖尚未理解的构造器、相等性和可变性。
- 不接入 Spring、数据库、JSON 或前端。
- 不研究对象头、内存布局、反射源码和 JVM 对象分配细节。

## 官方资料

- [Java SE 25 Language Updates](https://docs.oracle.com/en/java/javase/25/language/)
- [Java Language Specification：Classes](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html)
- [Java Language Specification：Interfaces](https://docs.oracle.com/javase/specs/jls/se25/html/jls-9.html)
- [Record Classes API Guide](https://docs.oracle.com/en/java/javase/25/language/records.html)
- [Java Language Specification：Enum Classes](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.9)
- [JUnit User Guide](https://docs.junit.org/current/user-guide/)
