# Week 02 独立答案册

> **警告：考前勿看。** 先提交[无 AI 考核](./assessment.md)。参考答案只展示关键边界，不是完整 FactoryCare 项目，也不代表唯一设计。

## A. 设计要点

- `EquipmentCode` 由规范值定义相等，没有独立生命周期，因此是 Value Object；
- 创建时规范化让“对象存在”意味着值已经可用，避免调用方忘记 trim/大写；
- `Locale.ROOT` 避免用户默认 locale 导致大小写结果不稳定；
- 专门类型防止与普通字符串/其他编号混用，并集中规则；
- `{4,12}` 只约束 `EQ-` 后正文，完整规范值长度为 7—15 个 ASCII 字符。

## B. `EquipmentCode` 参考实现

```java
package com.factorycare.asset;

import java.util.Locale;
import java.util.regex.Pattern;

public record EquipmentCode(String value) {
    private static final Pattern FORMAT =
            Pattern.compile("EQ-[A-Z0-9]{4,12}");

    public EquipmentCode {
        if (value == null) {
            throw new IllegalArgumentException("equipment code must not be null");
        }
        value = value.strip().toUpperCase(Locale.ROOT);
        if (!FORMAT.matcher(value).matches()) {
            throw new IllegalArgumentException(
                    "equipment code must match EQ-[A-Z0-9]{4,12}");
        }
    }
}
```

compact constructor 中重新赋值参数后，隐式 canonical assignment 会把规范值赋给组件。这里用 `strip()` 落实契约中未限定为 ASCII 的“首尾空白”；若业务只允许普通 ASCII 空格，则应把该限制写进契约，而不是含糊使用 `trim()`。错误写法包括：调用 `strip()` 却不接收返回值；用默认 locale；正则没有整串匹配；在访问器里每次临时规范化。

## Equipment 参考边界

```java
package com.factorycare.asset;

public final class Equipment {
    private final EquipmentId id;
    private final EquipmentCode code;
    private final String name;

    public Equipment(EquipmentId id, EquipmentCode code, String name) {
        if (id == null) {
            throw new IllegalArgumentException("equipment id must not be null");
        }
        if (code == null) {
            throw new IllegalArgumentException("equipment code must not be null");
        }
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("equipment name must not be blank");
        }
        this.id = id;
        this.code = code;
        this.name = name.trim();
    }

    public EquipmentId id() { return id; }
    public EquipmentCode code() { return code; }
    public String name() { return name; }
}
```

本周刻意不重写 Entity 的 equals/hashCode；Week 03 再基于稳定 `EquipmentId` 决策。没有 setter 不代表永远不能变化，未来需要重命名时应加入维护不变量的业务方法。

## C. 测试关键点

```java
@Test
void normalizesWhitespaceAndCase() {
    var code = new EquipmentCode("  eq-ab12  ");
    assertEquals("EQ-AB12", code.value());
}

@Test
void normalizedValuesHaveValueEquality() {
    var first = new EquipmentCode("eq-ab12");
    var second = new EquipmentCode(new String(" EQ-AB12 "));
    assertAll(
            () -> assertEquals(first, second),
            () -> assertEquals(first.hashCode(), second.hashCode()));
}

@Test
void rejectsBodyShorterThanFourCharacters() {
    assertThrows(IllegalArgumentException.class,
            () -> new EquipmentCode("EQ-A12"));
}
```

还需：正文4和12成功、13失败、null/blank、缺前缀、下划线、额外连字符、中文，以及 `Equipment` 的 null code。不要只断言异常基类 `Exception`。

## D. 防御性复制参考

```java
public record SeverityThresholds(int[] values) {
    public SeverityThresholds {
        if (values == null) {
            throw new IllegalArgumentException("values must not be null");
        }
        values = values.clone();
    }

    @Override
    public int[] values() {
        return values.clone();
    }
}
```

构造时复制防止原数组后改，访问时复制防止调用方经访问器修改内部数组。仍需注意：Java数组的 `equals` 默认按数组对象身份，不按元素内容；record 自动 equals 会调用组件相等语义，因此这个组件未必能提供预期的“按元素值相等”。更稳妥的长期设计可能使用具有明确值相等且不可变的组件，正式集合在 Week 03 学。

## E. 第一个唯一 ASCII 字符

```java
public static char firstUniqueAscii(String body) {
    if (body == null || body.isEmpty()) {
        throw new IllegalArgumentException("body must not be empty");
    }

    int[] frequency = new int[128];
    for (int i = 0; i < body.length(); i++) {
        char value = body.charAt(i);
        if (value >= 128 || !(value >= 'A' && value <= 'Z')
                && !(value >= '0' && value <= '9')) {
            throw new IllegalArgumentException("body must be uppercase ASCII letters or digits");
        }
        frequency[value]++;
    }

    for (int i = 0; i < body.length(); i++) {
        char value = body.charAt(i);
        if (frequency[value] == 1) {
            return value;
        }
    }
    return '\0';
}
```

题目允许自定“无结果”约定；若用 `\0` 必须记录调用方不能把它当真实编码字符。时间 `O(n)`（两次扫描仍是线性），频次数组固定128，按 n 衡量额外空间 `O(1)`。

关键测试：`ABAC → B`、全重复、首字符唯一、末字符唯一、空/null、非法小写/中文。题目说输入已规范化，因此小写应拒绝而不是再次悄悄规范化。

## F. FactoryCare 模型骨架要点

`Priority` 使用稳定 code；`WorkOrderStatus` 的常量与 code 必须严格为：

```java
public enum WorkOrderStatus {
    CREATED("CREATED"),
    TRIAGED("TRIAGED"),
    ASSIGNED("ASSIGNED"),
    ACCEPTED("ACCEPTED"),
    IN_PROGRESS("IN_PROGRESS"),
    PENDING_PARTS("PENDING_PARTS"),
    PENDING_APPROVAL("PENDING_APPROVAL"),
    RESOLVED("RESOLVED"),
    VERIFIED("VERIFIED"),
    CLOSED("CLOSED"),
    REOPENED("REOPENED"),
    CANCELLED("CANCELLED");

    private final String code;

    WorkOrderStatus(String code) {
        this.code = code;
    }

    public String code() {
        return code;
    }
}
```

当前 code 与常量名一致，但仍显式声明契约，不使用 `ordinal()`。本周不写 `canTransitionTo` 或 `setStatus`。创建工厂把状态固定为 `CREATED`，完整转换仍由 Week 15 处理。

## 常见错误

- 正则写成 `EQ-[A-Z0-9]{4,12}` 却用只检查局部匹配的 API；
- compact constructor 规范化了局部副本，但实际字段仍保留原值（误用显式构造写法时）；
- `Equipment` 仍同时保留 String code setter；
- 用 record 建 Entity，所有字段变化就改变相等性；
- 防御性复制只做一侧；
- `Locale.getDefault()` 让结果依赖机器；
- 字符算法用 char 处理任意用户可见 Unicode 却未声明限制；
- 为“完整”提前实现 Spring/JPA 状态机。

## 面试校准

> 先提交[面试题](./interview.md)的独立回答再阅读。以下要点必须用本周真实对象和失败测试说明。

1. **类/对象**：类定义类型、状态边界和行为，对象是运行时实例。领域类在无数据库时也成立，不自动等于表或 ORM entity。
2. **封装**：隐藏表示并通过创建入口和公开行为维护不变量。private 字段配万能 setter 仍允许非法状态进入，不构成有效封装。
3. **static/实例**：static 属于类或类加载器范围，共享可变业务状态会造成全局耦合、测试污染和并发风险；具体工单属于实例并由仓储管理。
4. **final/不可变**：final 引用不能重新赋值，但数组/对象内容仍可修改。深层不可变承诺需要不可变组件，或构造和访问两侧防御性复制。
5. **类型选择**：class 适合有身份和演进生命周期的对象，record 适合由组件相等语义定义的值载体，enum 表达有限集合，interface 表达协作契约。WorkOrder 有稳定身份和可变生命周期，不宜让所有组件定义相等。
6. **record 边界**：自动提供组件字段/访问器、canonical constructor、toString 以及按组件自身语义生成的 equals/hashCode。它不保证组件深层不可变；数组组件仍可变，且默认相等是数组身份而非元素深比较。
7. **enum 外部值**：ordinal 随声明顺序变化。name 是否稳定取决于重命名契约；项目使用显式稳定 code，并把展示文案分离。
8. **interface/抽象类**：interface 强调能力契约和多实现，抽象类可共享受控状态/实现但带来继承耦合。只有真实替换或边界需求才加接口，不机械制造一对一 Service/Impl。
9. **Entity/Value Object**：Entity 由稳定身份连续性定义；Value Object 由全部有效值定义。EquipmentCode 没有独立生命周期，规范值相同即相等，并在创建时自校验。
10. **DTO/VO**：DTO 是外部传输形状，VO 是核心语义和不变量。领域对象还可能由文件、消息、测试等入口创建，不能只靠 HTTP DTO 校验。
11. **不变量**：所有合法可观察状态都应持续成立。本周可证明 id/设备/描述/优先级非空、新建状态为 CREATED；完整转换权限、版本、SLA、审计仍未实现，不能提前声称。
12. **组合/继承**：组合让协作者替换和变化更局部；继承要求真实 is-a 与可替换契约。稳定封闭层级或共享模板行为时可能合理，不是绝对禁止。
13. **BaseEntity**：共用 id 字段不等于共用行为契约；不同实体的 id 类型和生命周期不同，基类会增加耦合。少量重复通常低于错误抽象的长期成本。
14. **状态机边界**：完整转换还依赖权限、并发版本、SLA、审计和事件，Week 15 统一处理。当前使用受控 WorkOrderStatus、新建固定 CREATED、没有 public setStatus。
15. **框架适配**：不能为尚不存在的框架要求破坏领域入口。未来通过 DTO、mapper、构造策略或框架支持的适配层处理，并用测试证明不变量仍成立。
16. **TS 类比风险**：JS 动态对象、TS readonly/interface、string 身份、undefined 等运行时语义不同。满分回答应引用数组防御性复制、record 数组相等或运行时校验的一项真实证据。

压力题结构：承认专门类型有代码和认知成本；按混淆风险、独立规则、复用频率和不变量收益选择。EquipmentId/EquipmentCode 能防止错传并集中规则，纯展示 label 通常不包装；用一个实际删除的无收益包装证明不是为 DDD 术语堆类型。
