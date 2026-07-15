# Week 02 系统讲义

## 1. 面向对象的目标是保护业务事实

面向对象不是“把函数塞进 class”，也不是“每张表一个实体”。在本周语境中，它解决三个问题：

1. 把相关数据和规则放进一个有名字的边界；
2. 通过创建入口和公开行为维护不变量；
3. 让调用方依赖业务语义，而不是随意修改字段。

例如，裸 `String equipmentCode` 可以为空、空白或格式不一致。`EquipmentCode` 类型可以在创建时统一规范并拒绝非法值；一旦创建成功，调用方就不必在每一层重复判断。

## 2. 类、对象与生命周期

- **class** 是类型定义，描述实例拥有的状态与行为；
- **object** 是运行时实例；
- 字段保存对象状态；
- 实例方法作用于某个实例；
- 构造器建立对象的初始合法状态；
- `this` 指向当前接收者；
- 对象不再可达后，回收由 JVM 管理，本周不研究分配细节。

### TypeScript 类比与失效

TS class 的字段、构造器、方法和访问修饰符能帮助迁移。Vue composable 也体现“把相关状态与操作放在一个边界”。

类比失效处：

- TypeScript `private` 的编译/运行时语义与 Java 访问控制不同；
- JS 对象形状更动态，Java 对象属于编译期声明类型；
- TS interface 通常只参与类型检查，Java interface 参与 JVM 类型系统和动态分派；
- Vue reactive proxy 的状态模型不能直接套到普通 Java 对象；
- Java class 不是默认的数据库实体或 Spring Bean。

## 3. 封装与不变量

不变量是对象在所有可观察合法时刻都必须成立的事实，例如：

- `EquipmentId` 不为空；
- `FaultDescription` 去除首尾空白后长度在约定范围；
- 新工单状态为 `CREATED`；
- 优先级只能属于有限集合。

`private` 字段加 public getter/setter 只是访问包装，不自动构成封装。如果任意调用方都能把未经校验的字符串传给 `setStatus(...)`，对象无法维护状态合法性。

好的公开方法表达业务意图，如 `reviseFaultDescription(...)`；坏的接口暴露通用 `setX`，让每个调用方自行维护规则。

### 前置、后置和不变量

- 前置条件：调用前输入必须满足什么；
- 后置条件：成功返回后保证什么；
- 不变量：对象整个合法生命周期始终满足什么。

构造器/工厂方法先验证前置条件，创建后建立不变量。异常应尽量在错误进入边界时发生，而不是几层以后空指针。

## 4. 访问控制与包边界

| 修饰符 | 可见范围直觉 | 本周策略 |
| --- | --- | --- |
| `private` | 当前顶级类内部 | 字段默认选择 |
| 包可见 | 同 package | 内部协作可用，需清晰包边界 |
| `protected` | 包内及子类相关 | 不为未来继承预留 |
| `public` | 所有调用方 | 只暴露稳定业务入口 |

最小可见性不是机械地“全部 private”，而是避免无必要承诺。public API 一旦被多处依赖，修改成本更高。

## 5. `static`、`final` 与不可变

- static 成员属于类，不属于某个实例；
- 常量可用 `static final`，可变业务状态不要放 static 字段；
- final 字段的引用不能重新指向别处，不代表引用对象深层不可变；
- 不可变对象创建后可观察状态不变，通常更易推理、测试和并发使用。

### 浅层不可变陷阱

```java
public record Thresholds(int[] values) {}
```

record 自身组件 final，但调用方仍可修改传入数组，或通过访问器取得同一数组后修改。要实现深层不可变承诺，需要构造时复制、访问时也返回副本，或使用真正不可变组件。

这与 Vue 的 `readonly()` 也不能简单等同：readonly proxy、TypeScript `Readonly<T>` 和 Java 对象深层不可变各有不同边界。

## 6. 创建入口：构造器与工厂方法

构造器适合直接建立清晰对象。静态工厂方法可以：

- 使用业务命名，如 `WorkOrder.create(...)`；
- 隐藏固定初始状态 `CREATED`；
- 返回缓存/子类型（本周不需要）；
- 区分不同创建场景。

不要同时提供绕过校验的 public 无参构造器和任意 setter。未来框架若有需求，应通过明确适配策略处理，不能提前破坏领域不变量。

## 7. record：值语义的数据载体

record 自动提供：

- private final 组件字段；
- 同名访问器，如 `id.value()`；
- 基于所有组件的 `equals/hashCode`；
- `toString`；
- canonical constructor。

适合：标识值对象、不可变命令/结果、坐标等值语义数据。未必适合：需要独立身份和可变生命周期的实体、深层可变组件、需要复杂代理行为的类型。

### compact constructor

```java
public record WorkOrderId(String value) {
    public WorkOrderId {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("work order id must not be blank");
        }
        value = value.trim();
    }
}
```

compact constructor 中可校验并规范参数，隐式字段赋值在构造器体之后发生。规范化是业务决定：不是所有字符串都应自动 trim/大写，例如密码绝不能随意改写。

## 8. enum：有限业务集合

enum 是一组受控实例，可拥有字段、构造器和方法：

```java
public enum Priority {
    LOW("LOW"),
    MEDIUM("MEDIUM"),
    HIGH("HIGH"),
    CRITICAL("CRITICAL");

    private final String code;

    Priority(String code) { this.code = code; }

    public String code() { return code; }
}
```

不要持久化或对外承诺 `ordinal()`：调整声明顺序会改变数值。稳定业务 code 与展示文案应分离。`name()` 是否能作为外部稳定值，也需明确契约；本项目显式 code 更清楚。

### WorkOrderStatus 边界

本周 enum 只声明[项目唯一状态词表](../../PROJECT_SPEC.md#4-工单状态机)：

`CREATED`、`TRIAGED`、`ASSIGNED`、`ACCEPTED`、`IN_PROGRESS`、`PENDING_PARTS`、`PENDING_APPROVAL`、`RESOLVED`、`VERIFIED`、`CLOSED`、`REOPENED`、`CANCELLED`。

不要在 enum 内实现完整转换图。Week 15 才统一处理权限、必填条件、版本、SLA、审计和事件。现在只保证新工单从 `CREATED` 开始，且没有通用 setter。

## 9. interface、实现与动态分派

interface 表达协作能力或契约：调用方依赖“能做什么”，实现决定“怎么做”。

```java
public interface PriorityPolicy {
    Priority calculate(int severity, boolean downtime,
                       boolean safetyRisk, int affectedEquipmentCount);
}
```

接口的价值来自真实替换/边界，而不是每个类都机械配一个 `IClass`。本周可让优先级计算器实现接口，测试针对契约；不要创建多层 `AbstractBasePriorityFactory`。

Java interface 与 TS interface 都能帮助依赖抽象，但 Java interface 是运行时类型，可有默认/静态方法。默认方法不是主要复用机制。

## 10. 组合优先于继承

继承表达稳定的 is-a 替换关系，且子类型必须遵守父类型契约。组合表达 has-a 协作关系，通常耦合更小。

FactoryCare 中：

- `WorkOrder` **拥有** `WorkOrderId`、`EquipmentId`、`FaultDescription` 和 `Priority`；
- 不应为了复用 id 字段让 `WorkOrder extends BaseEntity`；
- 设备与工单都“有标识”不等于它们是同一父类的行为子类型。

抽象类在共享状态/受控模板行为时可能有价值，但本周没有真实需求。不要为未来假设建立继承树。

sealed class/interface 在 JDK 25 已是稳定语言特性，可限制允许的子类型；本周只理解用途，不为简单枚举问题替代 enum，也不启用任何 preview API。

## 11. Entity、Value Object 与 DTO

### Entity

关注身份连续性。工单描述改变后，仍是同一个 `WorkOrderId` 对应的工单。实体不等于数据库表；本周尚无数据库。

### Value Object

由全部有效值定义相等；通常不可变、自校验、有领域名称。例如两个规范值相同的 `EquipmentCode` 应相等，无论由哪个字符串对象创建。

### DTO

用于边界传输的形状。DTO 可以反映请求/响应需要，不应成为核心不变量的唯一守门人。本周没有 HTTP/JSON，因此不需要创建 DTO。

### 选择问题

问自己：

1. 这个概念是否有独立身份和生命周期？
2. 相等由身份还是全部值决定？
3. 它是否能在创建时保持合法？
4. 创建专门类型是否减少错误，还是只增加无意义包装？

不要把每个字符串都包装。`EquipmentId`、`FaultDescription` 有明确规则与混淆风险，因此值得；纯展示临时标签未必值得。

## 12. Entity 相等性暂缓到 Week 03

概念上 Entity 以稳定身份判断同一对象，但手写 `equals/hashCode` 的契约和哈希集合行为在 Week 03 系统学习。本周：

- Value Object 使用 record 值相等；
- `Equipment`、`WorkOrder` 暂不手写实体相等性；
- 不把可变字段塞进自动生成的实体 `equals`；
- 记录待决策，Week 03 用测试确定。

这不是遗漏，而是避免在不了解哈希契约时复制 IDE 代码。

## 13. 字符串与“哈希表思想”算法

本周算法支线要求理解：按 key 记录频次可把重复扫描从 `O(n²)` 降为一次统计加一次查询。Java `HashMap` API 在 Week 03 学，本周可以：

- 对明确限制为 ASCII 的设备编码使用固定 `int[128]` 频次数组；
- 用伪代码描述 `frequency[key]++`；
- 写明字符集假设，不能把 `char` 当任意 Unicode 用户字符；
- 解释重复 key 时是覆盖、累计还是拒绝，这是业务契约；
- 说明时间 `O(n)`，固定 ASCII 表额外空间相对 n 为 `O(1)`。

TypeScript 中用 `Map<string, number>` 的经验可帮助理解键值频次；类比失效处是 Java 泛型、`equals/hashCode` 和 primitive/boxing 规则不同，正式用法留到 Week 03。

## 常见错误

- class 只有字段、getter、setter，规则仍散落外部；
- record 包住可变数组却宣称深层不可变；
- enum 依赖 ordinal 或把展示中文作为稳定 code；
- 所有类都先做 interface/implementation 两件套；
- 为共用 `id` 引入 `BaseEntity`；
- 构造器允许空值，指望未来 Controller 校验；
- 为未来 Jackson/MyBatis 提前添加无参构造与 setter；
- Entity 用全部可变字段生成 equals/hashCode；
- 自创项目词表之外的近义工单状态；
- 字符算法未声明 ASCII/Unicode 边界。

## 官方资料

- [JLS 25：Classes](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html)
- [JLS 25：Interfaces](https://docs.oracle.com/javase/specs/jls/se25/html/jls-9.html)
- [Record Classes](https://docs.oracle.com/en/java/javase/25/language/records.html)
- [JLS：Enum Classes](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.9)
- [Object API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Object.html)
- [JUnit User Guide](https://docs.junit.org/current/user-guide/)

完成后进入[实验](./labs.md)。
