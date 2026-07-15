# Week 04 系统讲义

## 1. 继承表达 is-a 契约

```java
class BasePolicy {
    int priority(Input input) { return 2; }
}

final class SafetyPolicy extends BasePolicy {
    @Override
    int priority(Input input) { return 5; }
}
```

- `extends` 建立子类型关系和实现复用；
- 子对象可在需要父类型的位置使用；
- 父构造器通过 `super` 初始化父部分；
- 重写需保持父契约，使用 `@Override`；
- final class/method 限制扩展；
- 字段隐藏不是动态多态，应避免。

继承不是“少复制几行”的默认工具。若子类加强前置条件、削弱后置条件或抛出调用者无法处理的新失败，就可能违反 LSP。

## 2. 重载、重写与动态分派

- overload：同类同名不同参数，编译期根据静态类型/参数选择；
- override：子类型替换实例方法实现，运行时按实际对象分派；
- static 方法不参与实例动态分派；
- parent reference 可以指向 child object；
- 编译期可调用的成员由引用静态类型决定；
- 向下转型需要检查且通常提示抽象边界不足。

## 3. 接口与抽象类

```java
interface NotificationSender {
    void send(Notification notification);
}
```

接口描述调用者需要的能力。一个类可实现多个接口。default 方法可提供演化/公共行为，但不能成为状态垃圾桶。

抽象类可以：

- 持有实例状态和构造器；
- 提供部分实现/模板；
- 定义抽象方法；
- 但占用单继承位置并耦合实现层次。

选择：可替换端口/能力优先接口；稳定共同状态/模板才考虑抽象类；只有一个实现也可以先用具体类，等待真实替换需求。

## 4. 多态的价值

调用者依赖统一契约，不需要知道每个实现：

```java
final class AlertService {
    private final NotificationSender sender;
    AlertService(NotificationSender sender) { this.sender = sender; }
}
```

测试可注入 in-memory sender，生产以后可接真实适配器。Week 09 Spring 只负责装配，不创造这个设计原则。

重复 `if (type == ...)` 有时提示应使用多态；但有限数据映射用 enum/switch 可能更简单。不要模式化过度。

## 5. 组合、委托与 Strategy

- has-a：对象拥有另一个对象/端口；
- delegation：把任务交给成员；
- strategy：把可变算法封装为统一接口；
- factory：集中有意义的创建/选择；
- composition 更容易替换、测试和控制职责；
- 组合也可能层次过多，保持最小设计。

“组合优先”不是“继承永不使用”，而是先确认真正稳定 is-a 契约。

## 6. record 与值语义

```java
record WorkOrderId(String value) {
    WorkOrderId {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("value is required");
        }
        value = value.strip();
    }
}
```

record 自动提供组件、构造器、accessor、`equals/hashCode/toString`。适合不可变数据载体和值对象；不适合需要可变生命周期、框架代理或复杂身份的实体。

record 是浅不可变：组件若是 List/array，可通过引用改内部；需要防御复制。toString 也可能泄漏敏感数据。

## 7. enum 与有限集合

```java
enum Priority {
    LOW(1), NORMAL(2), HIGH(4), CRITICAL(5);
    private final int level;
    Priority(int level) { this.level = level; }
}
```

- enum 是受限实例，可有字段/行为；
- 使用稳定 code/name 持久化，不依赖 ordinal；
- switch 可对 enum 做穷尽检查；
- 外部字符串必须解析/验证；
- 经常变化的管理员配置不应硬编码 enum。

## 8. sealed 类型与穷尽状态

sealed class/interface 控制允许的直接子类型，适合有限结果/命令层次。与 record 组合可表达 success/failure 等结构。

注意：完整工单状态机到 Week 18；本周只用少量状态/结果练习，不提前实现 12 状态权限/SLA。

## 9. Entity、Value Object 与 DTO

- Entity：由身份和生命周期区分，例如 WorkOrder；
- Value Object：由值定义相等、自校验、通常不可变，例如 WorkOrderId；
- DTO：跨边界传输形状，校验输入格式但不拥有所有领域规则；
- record 是语法/数据载体，Value Object 是业务语义；两者可重合但不等同。

## 10. equals/hashCode 的预告

record 自动值相等。普通实体如何定义相等、作为 Set/Map key 的风险在 Week 05 系统学习。本周禁止为“测试好看”随意基于所有可变字段生成实体 equals。

## 11. 算法连接

多态遍历 n 个策略/通知不会改变基本扫描 O(n)。策略选择若固定按顺序试到匹配，最坏 O(k)；k 是策略数。不要为很小 k 提前建复杂注册框架。

## 常见误区

- 为复用字段创建 BaseEntity；
- 子类拒绝父类允许的输入；
- 以为 static method 会动态重写；
- 一个实现也创建十层 interface/factory；
- record 当深不可变/实体默认；
- enum ordinal 入库；
- `instanceof` 一出现就强行多态；
- DTO/value object/entity 混为一谈。
