---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.generics-type-safety
title: 泛型、类型参数、边界与通配符
responsibility: 教授编译期类型参数和读写边界，不在本章引入具体集合性能或反射泛型信息
volume: '03'
order: 2
level: L1
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.generics-type-safety.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.interfaces-polymorphism
version_surfaces:
- jdk-25
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释泛型、类型参数、边界与通配符的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-generic-types
  - java-generic-bounds
  covers_topics:
  - java.generic-class-method
  - java.type-parameter
  - java.generic-invariance
  - java.bounded-type
  - java.wildcard-extends-super
  - java.type-erasure-boundary
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.methods
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现泛型 Result<T> 与 copy(List<? extends T>, List<? super T>)，用编译通过/失败片段证明读写边界，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - java-generic-types
  - java-generic-bounds
  covers_topics:
  - java.generic-class-method
  - java.type-parameter
  - java.generic-invariance
  - java.bounded-type
  - java.wildcard-extends-super
  - java.type-erasure-boundary
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.methods
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入 raw type、错误通配符方向和不安全强转，依据编译警告或 ClassCastException 消除类型漏洞
  covers_topic_groups:
  - java-generic-types
  - java-generic-bounds
  covers_topics:
  - java.generic-class-method
  - java.type-parameter
  - java.generic-invariance
  - java.bounded-type
  - java.wildcard-extends-super
  - java.type-erasure-boundary
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.methods
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 泛型、类型参数、边界与通配符

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《接口、抽象类、多态与动态分派》](../../volume-02-java-objects/chapters/ch.java-oop.interfaces-polymorphism.md)：独立完成泛型声明、边界与通配符前，必须先具备「接口、抽象类、多态与动态分派」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。正文与配套代码可用于试读和运行，但自动验证只证明这些工件在当前基线下满足固定断言，不证明学习者已经掌握，也不会自动修改 `PROGRESS.md`。

接口与多态让不同实现可以通过共同上层类型被调用，但还没有回答另一个问题：一个容器、结果或工具方法怎样在保留“内部值具体是什么类型”的同时复用同一份实现？如果所有位置都写成 `Object`，存入什么都可以，取出时却只能强转；错误可能躲到很晚的运行时。Java 泛型把类型关系写进声明，让编译器在调用边界检查。

泛型不是“尖括号语法大全”。它的核心是：**把类型当作编译期参数，表达多个位置必须保持的关系**。`Result<Device>` 表示成功值是 `Device`；`copy(List<? extends T>, List<? super T>)` 表示来源只承诺生产某种 `T`，目标承诺能消费这种 `T`。这种关系能让错误在编译期暴露，而不是变成生产环境的 `ClassCastException`。

本章从零解释泛型类、泛型接口、泛型方法、类型推断、上界、不变性、通配符、PECS、raw type、unchecked 警告与擦除边界。只借用 `List` 作为类型载体，不提前讲 List 的实现、复杂度、遍历算法或完整集合 API；也不展开反射读取泛型签名。版本基线是 **JDK 25**，官方资料复核日期为 **2026-07-16**。

## 1. 学完后必须留下什么证据

1. **解释证据**：在 120 秒内说明类型参数与普通方法参数的区别、`Result<T>` 中三处 `T` 的关系、不变性、上界、通配符和类型擦除；给出一个 raw type 让错误延迟到运行时的反例。
2. **构建证据**：实现 `Result<T>`、泛型静态工厂与 `copy(List<? extends T>, List<? super T>)`；通过固定断言证明来源和目标可以使用不同但兼容的参数化类型。
3. **编译失败证据**：保留三段独立错误源码，分别证明 `List<Integer>` 不是 `List<Number>`、不能向 `List<? extends Number>` 任意写入、错误通配符方向不能满足复制合同。
4. **警告证据**：用 `javac -Xlint:all -Werror` 编译正确代码，确保没有 raw/unchecked 警告；单独编译故障片段，观察 raw type 或 unchecked conversion 的第一处位置。
5. **诊断证据**：让 raw type 接受错误对象，观察强转时的 `ClassCastException`，然后删除 raw type 和不安全强转，使问题回到编译期。

配套工件：

- [泛型关系观察台](../../../examples/encyclopedia/ch.java-engineering.generics-type-safety/README.md)
- [FactoryCare 类型安全实验](../../../labs/encyclopedia/ch.java-engineering.generics-type-safety/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.generics-type-safety/README.md)

私有解与公开 starter 物理隔离。第一次练习时不要打开私有目录，也不要让 AI 直接重写整个签名；先预测哪个位置应当编译失败。

## 2. 从 Object 方案看泛型为什么存在

假设要包装一次设备查询结果：

```java
final class Result {
    Object value;
}
```

这个类可以保存任何对象，但调用者取出时只知道它是 `Object`。若期望 `Device`，就要强转：

```java
Device device = (Device) result.value;
```

编译器无法知道包装时是否误放了 `String`。错误直到这行执行才以 `ClassCastException` 暴露。更糟的是，写入和读取可能位于不同模块、不同人员甚至不同日期，堆栈只指向最终强转，不直接指出最早的错误写入。

把类写成 `Result<T>` 后，创建 `Result<Device>` 会把 `T` 替换为本次使用的类型实参 `Device`。编译器检查构造、返回与赋值关系。它不是为每个 T 复制一份源码，而是在编译期使用参数化类型规则，随后通过擦除等机制生成普通 JVM 字节码。

TypeScript 开发者可以把它类比为 `Result<T>`，但不能直接套用所有 TS 直觉。Java 泛型通常是不变的，存在擦除，基本类型不能直接作为类型实参，而且通配符是 Java 使用处变型的重要工具。

## 3. 类型参数、类型实参与普通参数

声明中的 `<T>` 引入类型参数：

```java
final class Box<T> {
    private final T value;

    Box(T value) {
        this.value = value;
    }

    T value() {
        return value;
    }
}
```

`T` 是占位类型名，不是变量，也不保存运行时值。`Box<Device>` 中 `Device` 是类型实参；`new Box<>(pump)` 中 `pump` 是普通构造参数值。类型参数在编译时约束类型关系，普通参数在运行时把值传入方法或构造器。

命名约定常用 `T` 表示 Type、`E` 表示 Element、`K/V` 表示 Key/Value、`R` 表示 Result。约定不是语法要求。复杂业务里 `TDevice` 也不一定更清楚；真正清楚来自小而稳定的职责、合理的签名和文档。

同一个泛型类可创建不同参数化类型：`Box<Device>` 与 `Box<String>`。它们共享类声明，但编译期视为不同类型。diamond `<>` 允许编译器从左侧或实参推断类型，例如 `Box<Device> box = new Box<>(pump)`；若推断结果含糊，应显式写出类型，而不是依赖读者猜测。

## 4. 泛型类表达跨成员的类型关系

`Result<T>` 的价值不在“能存任意类型”，而在成功工厂、字段和读取方法共享同一个 T：

```java
final class Result<T> {
    private final T value;
    private final String error;

    private Result(T value, String error) {
        this.value = value;
        this.error = error;
    }

    static <T> Result<T> success(T value) {
        return new Result<>(value, null);
    }
}
```

静态方法前的 `<T>` 很重要。类的类型参数属于实例语境，静态方法不绑定某个实例的 T，因此静态工厂要声明自己的方法类型参数。`static Result<T> success(T value)` 若没有方法前 `<T>`，编译器找不到这个 T。

本章允许用 `null` 简化结果结构，只为了聚焦泛型关系；生产实现应通过状态、sealed hierarchy 或不变量避免“value 与 error 同时为空/同时存在”。这些领域不变量属于对象建模，而非泛型自动提供。

泛型接口同理，例如 `Mapper<S, T>` 表达输入 S 与输出 T。实现类可固定类型，也可继续传递参数：`DeviceMapper implements Mapper<Row, Device>` 或 `IdentityMapper<T> implements Mapper<T, T>`。接口的动态分派和泛型的编译期检查是两个层次，可以同时存在。

## 5. 泛型方法只参数化一次调用关系

一个方法可以独立于类声明自己的类型参数：

```java
static <T> T first(T left, T right) {
    return left;
}
```

调用 `first("A", "B")` 时，编译器推断 T 为 String。调用 `first(deviceA, deviceB)` 时可推断为 Device。若传入不相关类型，编译器可能寻找共同上层类型，而不一定报错；赋值目标也参与推断。因此“推断成功”不等于得到你心中最具体的类型。

类型参数声明写在返回类型之前。`<T>` 声明本方法使用 T，后面的 `T` 才是返回类型。记忆顺序不如读成一句合同：“对某种 T，接收两个 T，返回一个 T”。

泛型方法适合表达参数间关系。如果方法只接收 `Object` 并返回 boolean，未必需要泛型；如果输入与输出必须保持同一类型，泛型能保留信息。不要为了显得高级给每个方法加 `<T>`。

## 6. 上界：允许一组类型并获得可用能力

无界 T 只能安全使用 `Object` 提供的操作。若算法要求每个值都有设备编号，可以使用上界：

```java
interface Identified {
    String id();
}

static <T extends Identified> String idOf(T value) {
    return value.id();
}
```

`extends` 在类型参数边界中同时用于“继承某类”与“实现某接口”的约束，不写 `implements`。上界告诉编译器：任何 T 至少是 Identified，因此可调用 `id()`。调用者仍保留具体 T，而不是被降成 Identified。

多重边界可写 `<T extends Base & Auditable & Comparable<T>>`。若有类边界，它必须在第一位，后面是接口。边界过长常意味着职责过载；先问算法真正需要哪一个最小能力接口。

上界不是运行时过滤器。传入不满足边界的类型会在编译期失败，方法体不会启动。若数据来自 JSON、数据库或外部输入，仍需运行时验证；泛型只能约束经过编译的 Java 类型关系，不能验证不可信字节。

## 7. 不变性：List<Integer> 不是 List<Number>

即使 `Integer` 是 `Number` 的子类型，`List<Integer>` 也不是 `List<Number>` 的子类型。原因可以用写入反证：若允许把整数列表赋给数字列表引用，那么后者可合法加入 `Double`，原整数列表就被污染。

```java
List<Integer> integers = new ArrayList<>();
// List<Number> numbers = integers; // 编译错误
```

这叫参数化类型的不变性。它保护写入安全，不是编译器“太笨”。数组在 Java 中是协变的，`Integer[]` 可以赋给 `Number[]`，但写入 Double 会在运行时抛 `ArrayStoreException`；泛型选择在编译期拒绝同类风险。

不要用强转绕过不变性。`(List<Number>) (List<?>) integers` 可能骗过部分检查，却把类型漏洞留给后来读取。正确方向通常是重新设计方法签名，用类型参数或通配符描述需要的读写能力。

## 8. 通配符表示“某个未知但受约束的类型”

`List<?>` 不是 `List<Object>`。前者表示“元素类型未知的某种 List”，可能是 `List<Device>`；后者明确表示元素类型就是 Object，可以写入任意对象。对 `List<?>`，可以安全读取为 Object，但除了 `null` 外不能任意写入，因为编译器不知道实际元素类型。

`? extends Number` 表示某个未知的 Number 子类型。它可能是 Integer，也可能是 Double。读取一个元素可以视为 Number，但不能写入任意 Integer 或 Double，因为实际列表类型未知。

`? super Integer` 表示某个未知的 Integer 超类型，可能是 Integer、Number 或 Object。可以安全写入 Integer；读取时只能当作 Object，因为实际列表可能是 Object，原有元素不保证是 Integer。

通配符描述的是使用处视角：调用者交来的具体参数化类型被隐藏，只暴露当前方法需要的最小能力。它不创建新集合，也不改变运行时对象。

## 9. PECS：生产者 extends，消费者 super

PECS 是 “Producer Extends, Consumer Super”。如果参数只向方法提供 T，就用 `? extends T`；如果参数只接收方法写入的 T，就用 `? super T`。

```java
static <T> void copy(
        List<? extends T> source,
        List<? super T> target) {
    for (T item : source) {
        target.add(item);
    }
}
```

调用可以是从 `List<RepairTicket>` 复制到 `List<WorkItem>`，前提是 RepairTicket 是 WorkItem 子类型。source 中读取的每项至少是 T；target 保证能接收 T。这个签名比 `List<T>, List<T>` 更灵活，也比两个 raw List 更安全。

PECS 是判断工具，不是无脑规则。一个参数既读又写同一种具体类型时，`List<T>` 可能更合适；若方法需要返回捕获的精确未知类型，可能需要辅助泛型方法。先写出方法对参数做的操作，再决定边界。

通配符方向写反会产生清晰的能力冲突：`List<? super T>` 不能生产 T，只能读取 Object；`List<? extends T>` 不能消费任意 T。看到编译错误时不要立刻加强转，先问该参数究竟是输入源还是输出目标。

## 10. 类型参数与通配符怎么选

当同一个未知类型需要在两个或多个位置建立关系时，命名类型参数。例如“输入两个相同类型并返回同类型”需要 T；“复制来源元素到目标”也需要 T 连接两侧。若只想表达一个参数可接受任意元素类型，而不需要在别处引用该类型，`?` 更简洁。

比较：

```java
static void printAll(List<?> values) { ... }
static <T> T choose(List<T> values, int index) { ... }
```

第一个方法只把元素当 Object 打印，不需命名未知类型。第二个要把列表元素类型保留到返回值，必须命名 T。两种写法都不是“更高级”，而是合同是否需要关联类型。

公共 API 应避免把不必要的实现细节暴露为复杂泛型。调用者若需要读三遍签名才能猜用途，可能应拆分方法、引入语义类型或收窄职责。

## 11. raw type 是丢弃泛型检查的兼容入口

`List list`、`Result result` 没有类型实参，称为 raw type。它主要为旧 Java 代码兼容而保留。raw type 允许不安全写入，编译器通常给出 `rawtypes` 或 `unchecked` 警告：

```java
List<String> names = new ArrayList<>();
List raw = names;
raw.add(42);
String first = names.get(0); // 运行到这里才可能 ClassCastException
```

警告不是装饰。它表示编译器无法证明类型安全。学习和新项目应使用 `javac -Xlint:all -Werror` 或构建插件对应配置，让 raw/unchecked 警告阻断构建。处理旧 API 时若确实无法避免，应把不安全操作封装在最小边界，先运行时验证元素，再局部、带理由地 `@SuppressWarnings`；不能在整个类上消音。

把 `List` 改成 `List<Object>` 并不总是正确修复。若列表本来只应存 String，正确修复是 `List<String>`；`List<Object>` 仍允许混入整数，只是这次属于显式设计。

## 12. 类型擦除：编译期信息不等于运行时实体

Java 为兼容既有 JVM 与类库实现了类型擦除。粗略模型是：无界类型参数擦除为 Object，有界类型参数擦除为其首个边界；编译器在需要处插入强转，并可能生成 bridge method 维持多态。擦除不等于“泛型毫无运行时信息”，class 文件还能保存部分签名元数据；本章只关注运行时不能像普通类那样完全区分参数化类型。

因此通常不能写 `new T()`、`T.class`、`new T[10]`，不能用 `instanceof List<String>` 检查元素参数，也不能重载两个擦除后签名相同的方法。若运行时确实要创建 T，可显式传入工厂或 `Class<T>`；若要验证外部元素，逐个检查实际对象。

```java
// if (value instanceof List<String>) { } // 非法：参数化类型不可具体化
if (value instanceof List<?>) { /* 只能确认它是某种 List */ }
```

`List<String>` 与 `List<Integer>` 通常对应同一个运行时 List 类。编译期类型安全依赖所有参与代码尊重泛型合同；raw type、unchecked cast、反射或外部序列化都能越过边界，所以运行时边界仍需验证。

## 13. bridge method 只需理解问题，不需背字节码

考虑 `Comparable<Device>` 或泛型父类方法被子类具体化。擦除后父方法可能以 Object 为参数，而子类声明具体 Device。编译器可生成合成 bridge method，在擦除后的调用协议与具体方法之间转发，维持重写和动态分派。

你不需要手写 bridge method，也不应把它当作普通业务 API。调试堆栈或反射结果偶尔看到 bridge/synthetic 标记时，应知道它可能来自泛型擦除，而不是重复定义的业务方法。完整 class loading 与反射将在后续章节讨论。

## 14. 常见限制及其原因

类型实参必须是引用类型，不能写 `List<int>`，应使用 `List<Integer>`。装箱会带来对象与空值语义，不能假设它与 `int[]` 性能和行为完全相同。

不能创建泛型类型数组如 `new List<String>[10]`，因为数组在运行时检查组件类型，而参数化类型经擦除不可具体化，两套模型会冲突。若需要组合，通常使用集合或受控的 `List<?>[]`，并明确警告边界。

泛型类的静态字段不能使用类级 T，因为静态字段属于整个类，而 `Box<String>` 与 `Box<Device>` 共享同一静态状态。方法级静态泛型必须自己声明 `<T>`。

不能在 catch 中捕获类型参数，也不能直接实例化 T。这些限制都可以从“运行时需要明确、可具体化的类，而 T 主要是编译期关系”推导，不必死背清单。

## 15. 泛型异常与空值不是同一个问题

`Result<T>` 能保证成功值的静态类型，却不能自动保证非 null、错误状态互斥或异常已处理。`Result<Device>` 仍可能被错误实现为 value 为 null。类型安全是一层合同，不取代对象不变量和运行时验证。

不要把所有异常都用 `Result<T>` 包住，也不要认为泛型返回值天然优于异常。预期业务失败、不可恢复系统失败与编程错误有不同表达。此处使用 Result 只是展示类型关系；异常合同在前置对象卷和后续工程章节中单独处理。

## 16. FactoryCare：设备结果与工单复制

FactoryCare 中可以用 `Result<Device>` 表示按编号查询设备的成功值类型，用 `Result<RepairTicket>` 表示创建工单的结果。调用者不能把前者直接赋给后者，因为不同参数化类型表达不同合同。若所有结果都返回 Object，错误就会从服务边界泄漏到强转位置。

复制任务展示 PECS。假设 `RepairTicket implements WorkItem`，一个 `List<RepairTicket>` 是生产者；审计汇总可把这些项复制到 `List<WorkItem>` 或 `List<Object>` 消费者。`copy` 不需要知道集合的性能或实现，只需要最小的读写类型边界。

公开实验会验证：`Result.success(device).value()` 的静态类型是 Device；复制后目标含相同对象引用；来源不能通过 extends 视角写入另一 WorkItem；目标通过 super 视角读取只能先当 Object。这里验证类型关系，不讨论线程安全、集合可变性或持久化。

## 17. 三类故障的定位方法

### 17.1 不变性误判

编译器报告 `List<RepairTicket> cannot be converted to List<WorkItem>`。不要把它解释成“RepairTicket 不是 WorkItem”，错误位于参数化类型整体。若方法只读，改为 `List<? extends WorkItem>`；若又读又写，重新审查合同，可能需要 `List<T>`。

### 17.2 通配符方向错误

若从 `List<? super T>` 读取并赋给 T，编译器只保证 Object。若向 `List<? extends T>` 写入 T，编译器不知道实际子类型。诊断时标注每个参数在方法体里是生产、消费还是双向，不要靠交换 extends/super 碰运气。

### 17.3 raw type 与延迟失败

`javac -Xlint:all` 首先报告 raw 或 unchecked 警告，程序随后可能在读取强转处抛 `ClassCastException`。第一处可信证据是编译警告，不是最终异常。最小修复是恢复完整类型参数并删除不安全写入；若只捕获异常，类型漏洞仍存在。

## 18. 编译失败也是可验证工件

正确教材不能只给“能跑”的例子。泛型很多边界必须由编译器拒绝来证明。配套验证器把每个非法片段单独编译，要求退出码非零，并匹配关键诊断；如果某个失败源码意外编译成功，验证器反而失败。

失败源码必须与正常源码隔离，否则整个示例永远无法编译。常用方式是放入 `failures/` 并逐文件调用 `javac`。不要把非法代码只写在注释里然后声称“已测试”。同时不要对完整英文错误文本做脆弱精确匹配；本章以退出码和关键符号为主要 oracle。

`-Xlint:all -Werror` 让警告成为错误，适合正确源码的零警告门禁。故意的 raw type 故障则单独用 `-Xlint:rawtypes,unchecked` 编译并要求出现警告。正例和反例要有不同预期，不能用一个“忽略所有错误”的脚本。

## 19. 安全边界：泛型不能验证不可信输入

从网络得到的 JSON 没有自动携带可信的 `Result<Device>` 保证。反序列化器、数据库映射或外部库可能使用反射与 unchecked cast。进入已类型化领域模型前，仍要验证字段、鉴权、长度、枚举值与业务不变量。

泛型可减少内部误用，却不能阻止恶意对象、资源耗尽、并发修改或越权。`List<? extends WorkItem>` 只表达元素类型上界，不表示列表不可变，也不表示调用者无权查看每个工单。类型合同与安全策略必须分层。

未经审查的 AI 常通过 raw type、`@SuppressWarnings("unchecked")` 或双重强转让红线消失。看到“编译通过”时检查是否牺牲了类型信息。警告被消掉不等于风险被消除。

## 20. 预测—构建—破坏—修复

运行示例前先预测：`Result.success(device)` 的 T 从哪里推断；`List<RepairTicket>` 能否赋给 `List<WorkItem>`；`List<? extends WorkItem>` 能读取成什么、能写什么；`List<? super RepairTicket>` 能写什么、读取成什么；raw type 的错误在写入还是读取时抛出。

构建正确实现后，逐个引入故障：删除 `static` 泛型方法前的 `<T>`；把 source 改成 `? super T`；把 target 改成 `? extends T`；把一个参数化类型删成 raw；添加未经检查的强转。每次只改一处，先读 `javac` 第一条诊断，说明它保护的类型不变量，再做最小恢复。

变更练习不是重新生成整套代码。把 `RepairTicket` 换成另一个 WorkItem 子类型，或让目标从 `List<WorkItem>` 改为 `List<Object>`；若签名符合 PECS，调用应保持成立。你要能解释为什么，不只是看到绿色。

## 21. 无 AI 训练

关闭 AI，限时 45 分钟：

1. 手写最小 `Box<T>`，标注类型参数、类型实参和普通值参数；
2. 写 `static <T> Result<T> success(T value)`，解释两个 T 和一个 `<T>` 各自位置；
3. 在纸上证明为什么 `List<Integer>` 不能赋给 `List<Number>`；
4. 不看笔记实现 copy 的 PECS 签名，并给三组合法调用；
5. 写一段向 `? extends` 写入而失败的代码，先预测编译器拒绝哪行；
6. 制造 raw type 污染，找到编译警告与运行异常，恢复为零警告；
7. 用 120 秒复述类型参数、上界、不变性、通配符、PECS、raw type 与擦除。

验收重点是能从读写操作推导签名，而不是背“extends 读、super 写”八个字后仍不会改代码。

## 22. 复习与速查

### 一句话规则

- 泛型表达编译期类型关系，不是给类型换名字。
- 类型参数写在声明中，类型实参在使用时提供，普通参数在运行时传值。
- 泛型类的 T 关联多个实例成员；静态泛型方法必须声明自己的 `<T>`。
- 上界给 T 最小可用能力；边界不是运行时输入验证。
- Java 参数化类型通常不变：子类型关系不会自动传到 `G<...>`。
- `?` 表示未知类型，`List<?>` 不等于 `List<Object>`。
- 生产者用 `? extends T`，消费者用 `? super T`，双向时重新审查合同。
- 需要跨位置关联未知类型时用命名 T，只在一个位置接受未知类型时常用 `?`。
- raw type 丢弃检查；unchecked 警告代表编译器无法证明安全。
- 擦除使许多参数化类型不能在运行时被完整区分。
- 泛型不能替代 null 不变量、外部输入验证、鉴权或并发控制。

### 读写速查

| 声明 | 安全读取 | 安全写入 |
| --- | --- | --- |
| `List<T>` | `T` | `T` |
| `List<?>` | `Object` | 除 null 外无通用值 |
| `List<? extends T>` | `T` | 除 null 外不能写任意 T |
| `List<? super T>` | `Object` | `T` 及其子类型实例 |
| raw `List` | 表面上 Object，伴随风险 | 任意对象，伴随警告和污染 |

### 选择流程

先问方法是否只读取、只写入或双向操作；再问未知类型是否要在返回值或其他参数复用；最后选择 `? extends`、`? super`、`T` 或非泛型具体类型。不要从“我想用高级语法”出发。

## 23. 术语表

- **泛型**：用类型参数表达可复用且受编译器检查的类型关系。
- **类型参数**：声明中的占位类型，如 T、E、K、V。
- **类型实参**：使用泛型时给出的具体类型，如 Device。
- **参数化类型**：`Result<Device>`、`List<String>` 这类带类型实参的类型。
- **泛型类/接口**：在类或接口声明上引入类型参数。
- **泛型方法**：在方法返回类型前独立声明类型参数的方法。
- **上界**：`T extends X` 对允许类型及可用能力的约束。
- **不变性**：A 是 B 子类型，不推出 G<A> 是 G<B> 子类型。
- **通配符**：`?` 表示某个未知类型，可带 extends 或 super 边界。
- **PECS**：Producer Extends, Consumer Super 的签名判断原则。
- **raw type**：省略泛型类型实参的兼容形式，会丢失部分检查。
- **unchecked warning**：编译器不能验证某次转换或调用类型安全的警告。
- **类型擦除**：编译器把类型参数映射到边界或 Object，并插入必要转换的实现机制。
- **可具体化类型**：运行时能完整识别的类型；多数具体参数化类型不是。
- **bridge method**：编译器为擦除后的重写与多态兼容生成的合成转发方法。
- **heap pollution**：参数化变量引用了不符合其类型实参的对象所造成的堆类型污染。

## 24. 官方资料与版本说明

以下资料均于 **2026-07-16** 复核：

- [JDK 25 文档](https://docs.oracle.com/en/java/javase/25/)
- [Java Language Specification 25](https://docs.oracle.com/javase/specs/jls/se25/html/)
- [JLS 4.4：类型变量](https://docs.oracle.com/javase/specs/jls/se25/html/jls-4.html#jls-4.4)
- [JLS 4.5：参数化类型](https://docs.oracle.com/javase/specs/jls/se25/html/jls-4.html#jls-4.5)
- [JLS 4.6：类型擦除](https://docs.oracle.com/javase/specs/jls/se25/html/jls-4.html#jls-4.6)
- [Oracle Java Tutorials：泛型](https://docs.oracle.com/javase/tutorial/java/generics/)
- [Oracle Java Tutorials：类型擦除](https://docs.oracle.com/javase/tutorial/java/generics/erasure.html)

Oracle 旧 Java Tutorials 明确提示其示例基于 JDK 8；本章只用它解释稳定泛型概念，语言规范以 Java SE 25 JLS 为准，不把旧教程当作 JDK 25 新特性清单。

## 25. 完成检查

你应能独立回答：为什么 Object 容器会把错误推迟到强转；为什么静态工厂要写 `<T>`；为什么 `List<Integer>` 不是 `List<Number>`；为什么 extends 可读却不能任意写，super 可写却只能按 Object 读；为什么 `List<?>` 与 `List<Object>` 不同；为什么 raw type 警告必须处理；为什么不能检查 `instanceof List<String>`；为什么泛型不能保证外部 JSON 合法。

最后完成一次需求变更：新增 `InspectionTicket implements WorkItem`，不改 copy 方法体，让它既能从 `List<InspectionTicket>` 复制到 `List<WorkItem>`，也能复制到 `List<Object>`；再写一个非法目标使编译失败。运行固定验证器，保留正例断言、失败退出码与零 warning 证据，并用自己的话解释 PECS 签名为什么能承受这次变化。
