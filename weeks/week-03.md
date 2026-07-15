# 第 3 周：类、对象、构造器、封装、static 与 final

## 定位

前两周主要使用静态方法和简单数据，本周第一次系统建立对象模型：类是类型定义，对象是运行时实例，字段保存状态，构造器建立有效对象，方法维护不变量。继承、接口、record 和 enum 留到 Week 04，避免概念拥挤。

时间预算：15—18 小时。使用纯 Java 和 JUnit，不引入 Spring/数据库。

## 前置

- 能使用类型、变量、方法、String、数组、条件和循环；
- 能写/运行 JUnit 并从日志定位问题；
- `WorkOrderPriorityCalculator` 的控制流版本通过测试；
- 能解释方法参数、返回值、scope 和按值传递。

## 目标

- 区分类、对象、引用、实例状态和对象身份；
- 定义字段、构造器、实例方法并使用 `this`；
- 使用访问控制和包边界隐藏实现；
- 通过构造器/行为保护对象不变量；
- 理解对象引用共享、aliasing 和浅层不可变性；
- 正确使用 instance/static 成员，避免全局可变 static 状态；
- 理解 `final` 对变量/字段/引用的实际限制；
- 使用工厂方法、构造器重载和封装后的集合快照；
- 建立 FactoryCare 第一版 `Device` 与 `WorkOrder` 类。

## 完整概念清单

### 类、对象与引用

- class 声明定义新引用类型；`new` 创建对象并调用构造器；
- reference variable 可以指向对象或 null；
- 两个引用可指向同一对象，修改通过任一引用可见；
- 对象身份、状态和行为；
- 局部变量、参数、字段的生命周期第一层模型；
- `null` 解引用与在构造边界快速拒绝；
- 垃圾回收只负责不可达内存，不替代文件/连接关闭。

### 字段、方法与 this

- instance field vs local variable；字段有默认值，局部变量必须初始化；
- instance method 隐式接收当前对象；
- `this.field` 解决名称遮蔽并表达当前实例；
- 方法可以读取/改变本对象状态，但不应暴露任意写入口；
- query 方法与 command 方法的直觉区别；
- getter/setter 不是自动封装，setter 可能破坏不变量；
- 返回内部可变数组/集合引用会泄漏状态。

### 构造器

- 构造器无返回类型，名称与类相同；
- 默认构造器只在未声明任何构造器时出现；
- 构造器参数、字段赋值、校验和对象建立；
- `this(...)` 构造器委托必须先执行；
- 构造器重载应保持一个主初始化路径；
- 构造器不要进行远程 I/O、启动线程或发布未完成对象；
- static factory method 可有名字、缓存或选择实现，但本周只做命名创建入口；
- 无效状态应尽量在创建时拒绝。

### 访问控制与 package

- public/protected/package-private/private；
- 类级 public/package-private；
- 最小可见性和公开 API 面积；
- 测试同 package 可访问 package-private，不代表一切都应 public；
- private 不是安全边界，权限仍需服务端业务规则；
- package 按职责组织，避免全部类放同一个包。

### static

- static member 属于类，instance member 属于对象；
- static method 没有当前实例 `this`；
- 常量、纯工具函数、命名工厂与 static 的合理用途；
- mutable static field 是进程级共享状态，导致测试污染/并发风险；
- static initialization 高层概念；
- `main` 为什么是 static；
- 不为避免 `new` 把所有业务方法写 static。

### final 与不可变性

- final local/parameter/field 只能赋值一次；
- final reference 不能改指向，但对象内部仍可变；
- immutable object 需要状态不可变、无泄漏和构造防御性复制；
- defensive copy、快照和 read-only view 的差别；
- 常量使用 `static final` 且名称明确；
- final class/method 留 Week 04 与继承一起学习。

### 封装与职责

- invariant、precondition、postcondition；
- 告诉对象做事，而不是取出字段在外部任意改；
- 行为名称表达业务，例如 `assignTo` 而非 `setTechnicianId`；
- 方法保持原子业务动作，失败后对象不应半更新；
- 单一职责指变化原因清晰，不是每类一个方法；
- 领域对象、输入 DTO、显示模型的边界只建立概念，Week 10 深入 DTO。

## 时间与任务

| 任务 | 时间 | 产出 |
| --- | ---: | --- |
| 类/对象/引用 | 2h | 两个对象、共享引用和 null 实验 |
| 构造器/this | 2—3h | 有效创建、重载和失败测试 |
| 封装/访问控制 | 3h | 从 public fields 重构为行为 API |
| static/final | 2h | 测试污染和浅不可变故障 |
| FactoryCare 增量 | 4—5h | Device/WorkOrder 类和行为 |
| 无 AI/复盘 | 2—3h | 独立规则、故障恢复和口述 |

## FactoryCare 增量

建立最小类模型：

- `Device`：id、name、enabled；创建时拒绝空 id/name；提供 `disable()`；
- `WorkOrder`：number、deviceId、description、priority、assigneeId；
- 工单号/设备 ID 本周可先使用 String，Week 04 再提取值对象；
- `assignTo` 拒绝空技师和重复非法分配；
- 不提供所有字段 setter；查询返回明确值；
- 如内部保存 tags/notes，构造和返回时防御性复制；
- 测试有效创建、非法构造、行为变化、共享引用泄漏和 static 测试污染。

## 故障实验

1. 两个变量引用同一对象，证明赋值不是复制对象；
2. final List 仍能 add，说明 final 不等于深不可变；
3. mutable static counter 导致测试顺序相关；
4. 返回内部数组/列表后外部修改，证明封装泄漏；
5. 构造器校验晚于字段部分赋值，讨论如何保持简单原子创建。

## 无 AI 任务（120 分钟）

实现 `Technician` 与 `DailyAssignment`：技师 ID/姓名非空；每日分配最多 5 个不同工单；重复和第 6 个明确失败；外部不能修改内部列表。提供正常、边界、非法、引用泄漏测试，并在 15 分钟内把上限改为构造参数。

## 验收

- 能用图解释类、对象、引用和共享修改；
- 能自己写字段、构造器、`this`、实例方法和访问控制；
- 能解释 static/instance、final/immutable 的区别；
- FactoryCare 类在创建/行为入口维护不变量；
- 测试能发现 public setter/内部集合泄漏；
- 能独立增加一个行为而不是增加无约束 setter；
- 60—120 秒口述“构造有效对象并用行为维护状态”。

## 非目标

- 不学习继承、接口、抽象类、多态、record、enum（Week 04）；
- 不深入 equals/hashCode（Week 05）；
- 不使用 Lombok、Spring 或 ORM；
- 不追求 DDD 术语和复杂聚合设计。

## 官方资料

- Java classes/objects/constructors/access control/static/final 官方语言资料；
- JUnit User Guide；以项目 JDK 25 稳定语法为准。
