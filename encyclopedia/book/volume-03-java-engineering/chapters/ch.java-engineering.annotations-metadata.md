---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.annotations-metadata
title: 注解声明、目标、保留策略与元数据
responsibility: 教授注解作为结构化元数据的声明和可见性，并仅用窄反射探针验证运行时可见性；不教授通用成员扫描、类加载或代理
volume: '03'
order: 14
level: L1
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.annotations-metadata.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.classes-objects
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
  text: 在 120 秒内解释注解声明、目标、保留策略与元数据的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-annotation-declaration
  - java-annotation-visibility
  covers_topics:
  - java.annotation-type
  - java.annotation-element
  - java.meta-annotation
  - java.junit-test-annotation-mechanics
  - java.annotation-target
  - java.annotation-retention
  - java.annotation-repeatable
  uses_capabilities:
  - java.platform-entry
  - java.references-objects
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 声明 @RequiresRole 注解并设置 Target/Retention/可重复策略，同时解释此前 @Test 标记在运行时被发现的条件
  covers_topic_groups:
  - java-annotation-declaration
  - java-annotation-visibility
  covers_topics:
  - java.annotation-type
  - java.annotation-element
  - java.meta-annotation
  - java.junit-test-annotation-mechanics
  - java.annotation-target
  - java.annotation-retention
  - java.annotation-repeatable
  uses_capabilities:
  - java.platform-entry
  - java.references-objects
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入 Retention=SOURCE、Target 错误和缺元注解导致运行时不可见，读取 class/反射观察后修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - java-annotation-declaration
  - java-annotation-visibility
  covers_topics:
  - java.annotation-type
  - java.annotation-element
  - java.meta-annotation
  - java.junit-test-annotation-mechanics
  - java.annotation-target
  - java.annotation-retention
  - java.annotation-repeatable
  uses_capabilities:
  - java.platform-entry
  - java.references-objects
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 注解声明、目标、保留策略与元数据

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《类、实例、字段与实例方法》](../../volume-02-java-objects/chapters/ch.java-oop.classes-objects.md)：独立完成注解声明、目标与保留前，必须先具备「类、实例、字段与实例方法」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文和配套工件是学习材料与作者验证证据，不代表学习者已经通过任何阶段门，也不会自动更新 `PROGRESS.md`。Java 25 语言与工具行为已依据 Oracle/OpenJDK 一手资料于 **2026-07-17** 复核。

注解（annotation）是贴在程序结构或类型使用位置上的**结构化元数据**。它可以表达“这个方法需要某角色”“这个类型将由编译器生成索引”“这个方法是测试入口”等声明，但注解本身不会检查权限、运行测试或生成代码。真正赋予它语义的是消费者：Java 编译器、注解处理器、静态分析器、文档工具，或者运行时框架。

本章建立一条从声明到证据的完整链路：先声明 `@RequiresRole`，约束它能出现的位置和保留时间；再分别用 `javac`、显式编译期处理器、`javap -v` 与最小运行时探针观察它。这里的反射只用于回答“元数据是否可见”这一窄问题，不教授成员扫描、访问控制、类加载器或代理；完整反射与框架扫描仍属于后续章节。

## 1. 本章完成定义

完成本章不能只说“会写 `@interface`”，而要留下三类独立证据：

1. **解释证据**：120 秒内说明声明位置、合法元素值、`@Target`、`@Retention`、`@Repeatable`、`@Inherited` 的职责；给出一个编译失败反例和一个“编译成功但运行时读不到”的反例。
2. **构建证据**：独立声明 FactoryCare 的 `@RequiresRole`；它可用于类和方法、可重复、运行时可见，并有明确默认值；解释测试引擎发现类似 `@Test` 标记必须满足的条件。
3. **诊断证据**：依次注入错误目标、`SOURCE` 保留、遗漏 `@Retention`；用编译退出码、class 文件内容和运行时探针定位第一处可信证据，修复后重跑同一个 oracle。

配套资产：

- [注解可见性观察台](../../../examples/encyclopedia/ch.java-engineering.annotations-metadata/README.md)
- [FactoryCare 角色元数据实验](../../../labs/encyclopedia/ch.java-engineering.annotations-metadata/README.md)
- [`@RequiresRole` 独立练习](../../../exercises/encyclopedia/ch.java-engineering.annotations-metadata/README.md)

明确不做：不实现真实鉴权、不扫描整个 classpath、不写依赖注入容器、不依赖 IDE 自动注册处理器，也不把注解当成替代业务校验的魔法。

## 2. 先分清“元数据”和“行为”

下面的代码表达了一条声明：

```java
@RequiresRole("ADMIN")
void closeWorkOrder() { }
```

它不会自动检查当前用户。若没有任何编译器、处理器或运行时组件读取 `RequiresRole`，程序行为与没写它时完全相同。即使运行时能读取，也仍要有可信身份来源、角色映射、租户边界、拒绝策略和实际拦截点。注解是输入，不是执行者。

可以把注解看作一张字段受限的小表单：注解接口定义字段名、字段类型和默认值；使用注解时填写值；消费者在某个阶段读取。这个类比的边界是：注解不能保存任意对象，也没有普通方法体和可变状态。

## 3. 用 `@interface` 声明注解接口

Java 25 的规范术语是 annotation interface。基本形式是：

```java
public @interface RequiresRole {
    String value();
    Scope scope() default Scope.TENANT;
}
```

`@interface` 是一个整体语法，不是“先加 `@` 再声明普通接口”。注解接口不能声明类型参数，也不能选择 `extends`；它的直接超接口固定为 `java.lang.annotation.Annotation`。使用者通常不自己 `new` 一个实现，编译器和运行时用受规范约束的表示来提供注解值。

注解接口可以是顶层或成员接口，但不能是局部接口。公开注解一般一个文件一个顶层类型，包名和可见性是它的长期 API 身份；随意改全限定名会让旧 class 文件和处理器失去匹配。

没有元素的是**标记注解**，例如 `@Audited`。只有一个元素时习惯命名为 `value`，于是 `@RequiresRole(value = "ADMIN")` 可简写为 `@RequiresRole("ADMIN")`。一旦同时填写别的元素，仍可省略 `value =`，但其他元素必须写名称：

```java
@RequiresRole(value = "DISPATCHER", scope = Scope.REGION)
```

注解中的 `String value();` 看起来像无参抽象方法，但它定义的是**元素**。元素不能有形参、类型参数或 `throws`，不能是 `private`、`static` 或 `default` 方法，也不能写业务方法体。

## 4. 元素类型不是任意 Java 类型

JLS 9.6.1 只允许以下元素返回类型：

- 任意基本类型，如 `boolean`、`int`、`long`；
- `String`；
- `Class` 或 `Class` 的参数化形式，如 `Class<? extends Rule>`；
- 枚举类型；
- 另一个注解接口类型；
- 上述任一类型的一维数组。

因此这些声明是合法的：

```java
@interface Policy {
    boolean enabled() default true;
    int priority() default 10;
    String owner();
    Class<? extends Runnable> hook() default Runnable.class;
    Scope scope() default Scope.TENANT;
    Audit audit() default @Audit("metadata");
    String[] tags() default {};
}
```

而 `Object`、`Integer`、`List<String>`、类型变量、函数对象和二维数组都不合法。注解的值必须能稳定编码进源码或 class 文件，而不是指向某个任意运行时对象。`String[][]` 也被明确禁止，即使一维数组本身合法。

元素不能直接或间接引用自己的注解类型，否则会形成规范无法表示的递归值。元素名也不能与 `Object` 或 `Annotation` 的某些方法形成等价签名，例如不能把 `hashCode()` 当成自定义元素。

## 5. 注解值也受限制

使用注解时，值必须与元素类型相容。常见合法值包括编译期常量表达式、枚举常量、类字面量、嵌套注解和数组初始化器：

```java
@Policy(
    owner = "platform-team",
    priority = 5 + 5,
    hook = CleanupJob.class,
    scope = Scope.REGION,
    audit = @Audit("role-change"),
    tags = {"security", "factorycare"}
)
```

不能调用一个普通方法来现算值，不能传 `new ArrayList<>()`，也不能用 `null` 表示“没填”。需要“未指定”语义时，应选择清楚的哨兵：专门的枚举值、空字符串、空数组或标记类；消费者必须明确区分哨兵与真实值。哨兵不是万能答案，若“不存在”和“空值”业务含义不同，优先重新设计元数据结构。

数组只有一个值时可省略花括号，例如 `tags = "security"`；为了 diff 清晰和未来扩展，团队也可以统一保留花括号。元素书写顺序通常跟声明一致便于阅读，但不应成为业务语义。

## 6. 默认值用 `default`，不是字段初始化

```java
Scope scope() default Scope.TENANT;
```

没有默认值的元素，每次使用都必须填写；漏填是编译错误。有默认值的元素可以省略。这里的 `default` 不是普通接口默认方法，也不会产生方法体。

一个容易忽略的二进制边界是：默认值存放在**注解接口声明**中，不是复制到每个使用该注解的位置。读取一个未显式填写的元素时，运行时应用当前可见注解接口中的默认值。因此修改默认值可能改变未重新编译的旧业务类被读取时的结果。对权限、事务、序列化这类高风险元数据，修改默认值应按 API 契约变更处理，做兼容性分析和全量回归，不能当作无害重构。

向已有注解增加无默认值的新元素也有兼容风险：旧 class 文件没有该值，读取时可能出现 `IncompleteAnnotationException`。改变元素类型可能导致 `AnnotationTypeMismatchException`，引用已不存在的类型或枚举常量还可能在读取时失败。注解 schema 也需要版本纪律。

## 7. 元注解：给注解本身加元数据

贴在注解接口声明上的注解叫元注解。最常见的组合是：

```java
@Documented
@Inherited
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE, ElementType.METHOD})
@Repeatable(RequiresRoles.class)
public @interface RequiresRole { ... }
```

这些元注解彼此职责不同：`@Target` 管“哪里能写”，`@Retention` 管“保留到哪个阶段”，`@Repeatable` 管“同一位置能否写多次”，`@Inherited` 只影响特定类查询的继承规则，`@Documented` 表示文档工具应把该注解视为公开契约的一部分。

元注解不会自动传递。给 `@SecurityPolicy` 标记 `@Documented`，不等于所有被 `@SecurityPolicy` 修饰的其他注解都自动获得相同语义；只有对应规范明确规定的行为才成立。

## 8. `@Target`：限制可以出现的位置

`@Target` 的值来自 `ElementType`。常用声明位置包括 `TYPE`、`FIELD`、`METHOD`、`PARAMETER`、`CONSTRUCTOR`、`LOCAL_VARIABLE`、`ANNOTATION_TYPE`、`PACKAGE`、`MODULE`、`TYPE_PARAMETER` 和 `RECORD_COMPONENT`；`TYPE_USE` 表示类型出现的上下文。

```java
@Target({ElementType.TYPE, ElementType.METHOD})
@interface RequiresRole { }
```

这个声明允许把 `@RequiresRole` 写在类、接口、枚举、record 等类型声明以及方法声明上，写在字段上会由编译器拒绝。目标错误首先是**编译期错误**，无需等到运行时框架才发现。

若完全省略 `@Target`，JLS 规定该注解适用于所有声明上下文，但不适用于类型上下文。省略不是“没有限制且包含一切”，尤其不自动等价于 `TYPE_USE`。面向团队 API 时应显式列出真正支持的位置，避免注解被贴到消费者从不读取的地方。

`@Target({})` 也是合法设计：该注解不能直接贴在任何程序元素上，只能作为另一个注解的嵌套元素值。这适合表达结构化子配置。

## 9. 声明注解与类型使用注解不同

`FIELD` 修饰的是“字段声明”，`TYPE_USE` 修饰的是“字段所使用的类型”。二者在源码中有时紧邻，语义却不同：

```java
@FieldAudit String deviceId;              // 字段声明元数据
List<@NonEmpty String> tags;               // 类型参数位置
@NonNull String owner;                     // owner 使用的 String 类型
String @ReadOnly [] serials;               // 数组层级上的类型使用
```

类型使用注解还可出现在强制转换、`new`、泛型实参、数组层级、`throws` 类型等类型上下文。它通常服务于类型检查器或更精细的运行时类型元数据。仅仅写 `@NonNull` 并不会让 JVM 自动做 null 检查；必须有静态分析器、编译插件、字节码工具或业务代码解释它。

运行时读取类型使用注解时，需要从 `getAnnotatedType()`、`AnnotatedParameterizedType` 等“带注解类型”视图进入，而不是只调用字段的 `getAnnotation`。本章示例只验证一个字段类型位置，不延伸为完整反射教学。

## 10. `@Retention`：SOURCE、CLASS、RUNTIME

保留策略回答“元数据存活到哪一阶段”，不回答“谁会使用它”。三种策略必须精确区分：

| 策略 | 源码阶段 | class 文件 | Java 反射读取 | 典型消费者 |
| --- | --- | --- | --- | --- |
| `SOURCE` | 有 | 编译器必须丢弃 | 不可读 | 编译器、注解处理器、源代码检查 |
| `CLASS` | 有 | 有 | VM 不必在运行时保留，通常反射不可读 | class 文件工具、字节码分析；也是省略 `@Retention` 的默认值 |
| `RUNTIME` | 有 | 有 | 平台反射 API 必须可用 | 运行时框架、最小元数据探针 |

`SOURCE` 并不意味着“处理器看不到”。处理器运行在编译过程中，正好能读取源模型；只是编译输出中不再保留。`CLASS` 也不意味着“运行时一定能读”，它只保证进入二进制表示。`RUNTIME` 则同时进入 class 文件并由 VM 保留供反射读取。

最危险的默认认知错误是省略 `@Retention` 后以为默认 `RUNTIME`。实际默认是 `CLASS`：编译成功，`javap -v` 能看到对应的 runtime-invisible 属性，但 `isAnnotationPresent` 返回 false。配套实验专门重放这一故障。

还有精细边界：局部变量**声明**上的注解、lambda 形参声明上的注解，即使写了 `CLASS`/`RUNTIME` 也不保留在二进制表示；但其**类型**上的类型使用注解在策略合适时可以保留。声明位置与类型位置不能混为一谈。

## 11. 用 class 文件和反射分别取证

观察保留策略要使用与问题对应的工具：

```bash
javac --release 25 -d build/classes src/Policy.java
javap -v -classpath build/classes factorycare.Policy
java -cp build/classes factorycare.VisibilityProbe
```

`javap -v` 能区分 class 文件中的 `RuntimeVisibleAnnotations` 与 `RuntimeInvisibleAnnotations`。名字中的 “RuntimeInvisible” 并不等于无效，它通常正是 `CLASS` 元数据的证据。运行时探针再用 `isAnnotationPresent` 或 `getAnnotation` 判断 VM 暴露了什么。

如果运行时读不到，先按证据顺序排查：源码目标是否合法；编译的是不是刚修改的源文件；`javap` 中是否有注解描述符；注解接口是否为 `RUNTIME`；探针是否拿到了正确的类/方法；类路径上是否混入旧版本。不要一上来怪“反射不稳定”。清理输出目录能排除陈旧 class 文件。

## 12. `@Repeatable` 与容器注解

同一位置默认不能出现两个相同注解。要允许：

```java
@RequiresRole("ADMIN")
@RequiresRole("DISPATCHER")
class WorkOrderPolicy { }
```

需要为被重复注解指定容器：

```java
@Repeatable(RequiresRoles.class)
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE, ElementType.METHOD})
@interface RequiresRole {
    String value();
}

@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE, ElementType.METHOD})
@interface RequiresRoles {
    RequiresRole[] value();
}
```

容器不是随便写一个数组就行。它必须有返回 `RequiresRole[]` 的 `value()`；其他元素必须有默认值；保留时间至少兼容被重复注解；目标范围必须满足规范的包含关系。如果 `RequiresRole` 使用 `@Inherited` 或 `@Documented`，容器也要满足相应兼容要求。违反这些关系是编译错误。

源码中的多个注解在二进制表示中可能通过容器间接存在。因此读取重复注解优先使用：

```java
RequiresRole[] roles = type.getAnnotationsByType(RequiresRole.class);
```

不要假设 `getAnnotation(RequiresRole.class)` 会替你展开多个值，也不要让业务代码直接耦合容器的存储细节。`getDeclaredAnnotationsByType` 只关注直接/间接声明，`getAnnotationsByType` 还会应用“关联”和继承规则；选择哪个取决于契约。

重复只表示有多个值，不自动定义“任一满足”“全部满足”或覆盖顺序。FactoryCare 若用多个角色，应由授权规则明确是 OR 还是 AND，并为重复、冲突和空角色写测试。

## 13. `@Inherited` 只对类级查询有窄作用

`@Inherited` 最容易被名字误导。它只影响：当查询**类声明**上的某种注解，而当前类没有直接值时，沿超类链继续寻找。它不做这些事：

- 不从实现的接口继承给类；
- 不让父类方法上的注解自动出现在重写方法上；
- 不传播字段、构造器、参数或类型使用注解；
- 不让 `getDeclaredAnnotation` 把继承值说成直接声明；
- 不替业务对象建立角色继承关系。

```java
@Inherited
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
@interface DomainFamily { }

@DomainFamily class BaseWorkOrder { }
class UrgentWorkOrder extends BaseWorkOrder { }
```

此时 `UrgentWorkOrder.class.isAnnotationPresent(DomainFamily.class)` 为 true，而 `getDeclaredAnnotation` 返回 null。若把 `@DomainFamily` 放在一个接口上，实现类查询仍不会因此得到它。配套示例同时断言这三个结果。

对安全策略，隐式继承会让读者难以看出最终权限，也可能在子类出现直接注解时改变合并方式。是否使用 `@Inherited` 应由明确规则决定；高风险配置常更适合要求每个具体入口显式声明。

## 14. 运行时读取：只做最小可见性探针

`Class`、`Method`、`Field` 等实现 `AnnotatedElement`。本章只需要以下窄接口：

- `isAnnotationPresent(T.class)`：是否存在；
- `getAnnotation(T.class)`：存在则返回一个值，否则 null；
- `getDeclaredAnnotation(T.class)`：只看直接声明；
- `getAnnotationsByType(T.class)`：展开可重复注解并应用对应关联规则；
- `getDeclaredAnnotationsByType(T.class)`：只看直接/间接声明的重复值。

读取到的对象提供元素访问器，例如 `role.scope()`。这不等于注解拥有可变实例状态；注解值受 `equals`、`hashCode` 和表示规则约束。数组元素不应被当成共享可变配置来修改。

完整运行时扫描还涉及查找哪些类、继承和覆盖规则、模块开放、访问控制、类初始化与缓存，这些都不在本章。实验直接引用固定的类和固定的方法，是为了隔离“保留策略是否正确”这个变量。

## 15. 为什么类似 `@Test` 的标记能被测试引擎发现

`@Test` 不是 Java 关键字，也不是 JVM 自动执行开关。一个运行时测试引擎要发现类似标记，至少需要：

1. 对应注解接口允许出现在引擎支持的声明位置；
2. 注解被保留到运行时，或引擎采用了别的明确编译期机制；
3. 测试类和方法进入引擎的发现范围；
4. 引擎读取该元数据并按自己的生命周期、参数和可见性规则调用方法；
5. 构建工具确实启动了匹配版本的测试引擎。

所以“方法上写了 `@Test` 但没运行”不应只检查拼写。先检查导入的到底是哪一个同名注解、实际元注解、测试引擎与构建配置、发现日志和过滤条件。本章不锁定某个 JUnit 版本的具体扫描规则；应以项目中实际依赖的注解声明和引擎文档为准。

若把一个供运行时发现的标记误改为 `SOURCE`，源码仍好看、编译也可能成功，但运行时引擎看不到。这与配套实验中的角色注解故障是同一个机制。

## 16. 编译期注解处理不是运行时反射

Java 的 Pluggable Annotation Processing API 位于 `javax.annotation.processing`，语言模型位于 `javax.lang.model`。处理器面对的是 `Element`、`TypeElement`、`TypeMirror` 等编译模型，不是已经加载的业务 `Class<?>`。因此它可以读取 `SOURCE` 注解、检查声明、报告编译诊断并生成新源文件或资源。

一个处理器通常继承 `AbstractProcessor`，声明支持的注解名称，并实现：

```java
boolean process(
    Set<? extends TypeElement> annotations,
    RoundEnvironment roundEnv
)
```

处理分轮进行：编译器扫描当前输入，调用匹配处理器；若处理器生成新源文件，新文件进入下一轮；不再生成时还有结束轮；除非使用 `-proc:only`，随后编译原始和生成的源文件。处理器必须能面对多轮调用，不能每轮重复创建同一文件。

`Filer` 用于创建源、class 或资源；`Messager` 用于把错误、警告和提示绑定到编译诊断。验证输入失败时，应报告 `Diagnostic.Kind.ERROR`，让构建以非零状态失败，而不是悄悄生成不完整结果。

## 17. 显式运行处理器，避免环境猜测

JDK 25 的 `javac` 支持：

```bash
javac \
  --processor-path build/processor \
  -processor factorycare.processor.RequiresRoleProcessor \
  -s build/generated \
  -d build/classes \
  src/factorycare/app/WorkOrderPolicy.java
```

`--processor-path` 指定从哪里找处理器，`-processor` 明确运行哪些类并绕过默认发现，`-s` 指定生成源码目录。`-proc:only` 只执行处理，`-proc:full` 执行处理并继续编译；JDK 25 在显式配置处理时会执行处理和编译。本章实验显式给出路径和类名，不依赖 `META-INF/services`、IDE 开关或外部构建插件，因此离线复现更可靠。

处理器本身是在编译期间执行的代码，拥有构建进程所拥有的权限。把不可信依赖放进 processor path 不是“只读取元数据”，而是供应链代码执行面。真实项目应锁定来源与版本、审查升级、限制 CI 权限，并避免让处理器访问网络、密钥或不必要目录。

## 18. 让生成结果可重复

注解处理器可能从集合、文件系统或编译轮次得到不稳定顺序。生成器应主动排序；不要写当前时间、随机数、机器绝对路径或网络响应；使用确定编码与换行；同一输入应产生相同字节。

配套处理器只处理显式标了 `@CompileReport` 的类型，把角色项排序后生成 `factorycare.generated.RoleIndex`。实验会清空构建目录、重新编译、检查生成源码、运行生成类，再比较固定输出。它没有服务注册、没有外部依赖，也不长期挂起。

生成源码不是天然可信。需要同时检查：输入选择是否正确、错误是否让编译失败、生成目录是否隔离、重复轮次是否安全、生成代码是否可编译、输出是否稳定。若生成文件提交仓库，还要明确它是来源还是派生物，避免手改与重新生成互相覆盖。

## 19. FactoryCare：角色元数据的正确边界

本章用以下注解表达运维操作所需角色：

```java
@Inherited
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE, ElementType.METHOD})
@Repeatable(RequiresRoles.class)
public @interface RequiresRole {
    String value();
    Scope scope() default Scope.TENANT;
}
```

编译期处理器可以生成“哪些类型声明了哪些角色”的审计索引；运行时探针可以证明角色元数据存在。但生产鉴权仍需要从可信会话取得主体、校验租户/区域、定义类级与方法级合并规则、默认拒绝、记录审计，并保证每个真实入口都经过拦截。任何一项缺失，都可能出现“注解写了但没生效”。

角色名称用 `String` 便于跨模块，但会允许拼写错误；改用 enum 能获得编译期闭集，却增加跨服务演进耦合。这里是教学取舍，不是生产方案定案。真正设计应比较权限是否动态配置、跨服务协议、迁移成本和失败策略。

## 20. 分层验证矩阵

| 声明或故障 | `javac` | 注解处理器 | `javap -v` | 运行时探针 |
| --- | --- | --- | --- | --- |
| 正确 `RUNTIME` | 通过 | 可见 | visible 属性 | 可读 |
| `CLASS` | 通过 | 可见 | invisible 属性 | 通常不可读 |
| `SOURCE` | 通过 | 可见 | 不存在 | 不可读 |
| `@Target` 错误 | 非零失败 | 不应进入正常生成 | 无可信产物 | 不运行 |
| 未写 `@Retention` | 通过 | 可见 | 默认为 CLASS | 不可读 |
| 重复容器不兼容 | 非零失败 | 不应生成 | 无可信产物 | 不运行 |

这张表说明为什么单一证据不够。“编译通过”不能证明运行时可读；“反射读不到”不能区分 `SOURCE`、`CLASS`、旧 class 文件或查错目标；“生成文件存在”也可能是上次构建残留。可靠流程从干净目录开始，让每一层回答自己的问题。

## 21. 常见失败与第一处可信证据

### 21.1 注解写在错误位置

现象：`javac` 非零并指向注解位置。第一证据是编译诊断，不是框架日志。检查 `@Target` 和实际语法位置；字段声明与字段类型使用尤其容易混淆。

### 21.2 运行时读不到

先用 `javap -v` 看 class 文件。完全没有描述符，多半是 `SOURCE`、编错源或旧输出；在 `RuntimeInvisibleAnnotations` 中则多半是 `CLASS`；在 visible 属性中再检查探针是否查对类/成员与类路径。

### 21.3 省略元注解

省略 `@Retention` 默认为 CLASS；省略 `@Target` 是所有声明上下文、无类型上下文；省略 `@Repeatable` 则不能同位置重复。默认规则不同，不能用“都比较宽松”概括。

### 21.4 处理器没运行

检查命令是否真的有 `-processor` 或其他显式处理配置、processor path 是否含处理器及其依赖、支持的全限定注解名是否一致、生成目录是否为本轮创建。不要先复制服务配置来碰运气。

### 21.5 处理器生成两次

若每轮都创建同一个文件，`Filer` 会拒绝。保存“已生成”状态，理解新增源文件会触发下一轮，只在有完整输入的适当轮次生成一次。

### 21.6 把 `@Inherited` 当接口继承

用四个探针区分：父类直接声明、子类 `getAnnotation`、子类 `getDeclaredAnnotation`、接口实现类查询。只看一个 true 无法证明边界。

### 21.7 改 oracle 让结果变绿

删除负向断言、跳过 `javap` 或把预期改成实际输出，只会隐藏契约。修复必须改元注解声明或消费者，随后用同一组 SOURCE/CLASS/RUNTIME 与失败样例重跑。

## 22. 实验执行顺序

在 [FactoryCare 角色元数据实验](../../../labs/encyclopedia/ch.java-engineering.annotations-metadata/README.md) 中，先预测再执行：

1. 预测 `CompileReport`、`ClassAudit`、`RequiresRole` 分别在哪一层可见。
2. 编译元数据类型和处理器到隔离目录。
3. 用 `--processor-path` 与 `-processor` 显式编译应用，检查生成的 `RoleIndex.java`。
4. 运行固定类探针，验证重复角色、默认值、SOURCE/CLASS 不可反射和类继承。
5. 用 `javap -v` 证明 CLASS 仍在二进制、SOURCE 已丢弃。
6. 编译错误目标样例，要求非零退出；运行错误保留样例，要求固定失败证据。
7. 再运行一次，确认输出没有时间戳、随机顺序或残留依赖。

不要把 `build/` 中旧文件当成本轮证据。验证脚本首先删除并重建目录；若某一步失败，应保留 stderr 定位，不手工复制一个“看起来正确”的生成文件。

## 23. 独立练习与修改边界

公开练习故意让 `RequiresRole` 使用 `SOURCE`、只允许 `TYPE`，并缺少 `@Repeatable` 与 `@Inherited`。oracle 同时需要类上重复、方法目标、运行时读取、超类继承和默认 `TENANT`。只允许修改两个注解声明文件；修改 `ChallengeApp` 的断言属于破坏验收。

推荐修复顺序：先根据第一条编译诊断补 `@Repeatable`；再让注解与容器的 `@Target`、`@Retention`、`@Inherited` 兼容；编译通过后观察运行时断言；最后解释为什么接口和方法仍不因 `@Inherited` 自动传播。不要一次复制答案而跳过故障定位。

## 24. 120 秒口述模板

可以用下面结构自测，但不要逐字背诵：

> 注解是受限类型的结构化元数据，不会自行执行。`@interface` 声明元素，合法类型只有基本类型、String、Class、enum、注解及其一维数组；默认值用 `default`。`@Target` 限制声明或类型使用位置。`SOURCE` 只活到编译期，`CLASS` 进入 class 文件但默认不能反射，`RUNTIME` 可由反射读取；没写 Retention 默认 CLASS。`@Repeatable` 依赖兼容容器，读取时用 by-type API。`@Inherited` 只在类查询时沿超类链生效，不含接口和方法。编译期处理器用语言模型分轮生成，运行时框架用可见元数据，两者不是一回事。反例是把运行时规则改成 SOURCE：编译可能通过，但 `javap` 和探针证明运行时读不到。

若无法在 120 秒内说出“省略 Retention 默认 CLASS”和“接口不参与 Inherited”，说明边界还不稳；回到实验预测，不要只重复运行脚本。

## 25. 检索题

1. 为什么 `@RequiresRole` 编译通过仍不等于权限已执行？
2. `Integer`、`List<String>`、`String[][]` 为什么不能作为注解元素类型？
3. 修改注解默认值为什么可能影响未重新编译的旧业务类？
4. 省略 `@Target` 是否包含 `TYPE_USE`？
5. `CLASS` 与 `RUNTIME` 都进入 class 文件，运行时可见性有何不同？
6. 为什么 SOURCE 注解仍能被编译期处理器读取？
7. 可重复注解的容器至少要满足哪些约束？
8. `@Inherited` 为什么不会从接口传播给实现类？
9. `getAnnotation` 与 `getDeclaredAnnotation` 在子类上可能返回什么不同结果？
10. 一个类似 `@Test` 的标记要被运行时引擎发现，需要哪几层条件？
11. 处理器为什么必须考虑多轮，为什么生成结果应排序？
12. 运行时读不到注解时，`javac`、`javap`、探针的排查顺序是什么？

## 26. 官方一手资料

以下链接均在 **2026-07-17** 按 Java SE/JDK 25 复核；语言核心是稳定语义，命令行默认与工具选项是版本表面，升级 JDK 时应重新核对。

- [Java Language Specification 25，第 9.6—9.7 节：注解接口与注解](https://docs.oracle.com/javase/specs/jls/se25/html/jls-9.html#jls-9.6)
- [Java SE 25 `ElementType`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/annotation/ElementType.html)
- [Java SE 25 `RetentionPolicy`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/annotation/RetentionPolicy.html)
- [Java SE 25 `Target`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/annotation/Target.html)
- [Java SE 25 `Repeatable`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/annotation/Repeatable.html)
- [Java SE 25 `Inherited`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/annotation/Inherited.html)
- [Java SE 25 `AnnotatedElement`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/reflect/AnnotatedElement.html)
- [Java SE 25 注解处理包](https://docs.oracle.com/en/java/javase/25/docs/api/java.compiler/javax/annotation/processing/package-summary.html)
- [JDK 25 `javac` 命令与 Annotation Processing](https://docs.oracle.com/en/java/javase/25/docs/specs/man/javac.html#annotation-processing)

## 27. 本章非目标与后续衔接

本章刻意没有实现通用反射扫描、动态代理、Spring 元注解组合、JUnit 扩展、模块开放、增量构建缓存或生产授权。也没有证明某个框架会按这里的规则合并类级和方法级注解；那是框架契约，不是 Java 语言自动保证。

进入后续反射章节前，应能独立指出：元数据声明在哪里，何时被保留，谁读取，读取不到时第一证据是什么。若这四问没有答案，增加扫描代码只会扩大不确定性。
