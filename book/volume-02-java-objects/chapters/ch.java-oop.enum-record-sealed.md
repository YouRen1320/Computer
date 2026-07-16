---
schema_version: 2
edition: 2026.2-draft
id: ch.java-oop.enum-record-sealed
title: enum、record、sealed 与受限类型建模
responsibility: 教授用受限类型表达有限状态和数据载体，不替代完整领域聚合建模
volume: '02'
order: 9
level: L1
status: drafting
path: book/volume-02-java-objects/chapters/ch.java-oop.enum-record-sealed.md
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
  text: 在 120 秒内解释enum、record、sealed 与受限类型建模的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-enum-record
  - java-sealed-model
  covers_topics:
  - java.enum
  - java.record
  - java.data-carrier
  - java.sealed-permits
  - java.pattern-switch
  - java.exhaustive-model
  uses_capabilities:
  - java.encapsulation-immutability
  - java.inheritance-polymorphism
  - java.control-flow
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：用 enum 表示工单状态、record 表示坐标值、sealed 层次表示有限命令，并用穷尽 switch 处理
  covers_topic_groups:
  - java-enum-record
  - java-sealed-model
  covers_topics:
  - java.enum
  - java.record
  - java.data-carrier
  - java.sealed-permits
  - java.pattern-switch
  - java.exhaustive-model
  uses_capabilities:
  - java.encapsulation-immutability
  - java.inheritance-polymorphism
  - java.control-flow
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 新增一个 permitted 类型制造非穷尽 switch 或用字符串拼错状态，依据编译/行为证据修复
  covers_topic_groups:
  - java-enum-record
  - java-sealed-model
  covers_topics:
  - java.enum
  - java.record
  - java.data-carrier
  - java.sealed-permits
  - java.pattern-switch
  - java.exhaustive-model
  uses_capabilities:
  - java.encapsulation-immutability
  - java.inheritance-polymorphism
  - java.control-flow
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# enum、record、sealed 与受限类型建模

> 本章状态为 **drafting**。正文与工件可用于学习和作者验证，不代表学习者已完成无 AI 构建、诊断或复述，也不会自动修改 `PROGRESS.md`。

许多业务错误不是“算法算错”，而是程序允许表达本不该存在的值。状态写成任意字符串时，`IN_PROGRESS` 少一个 S 仍能进入系统；坐标只是三个散落参数时，调用者会把巷道与货位传反；命令只有一个大接口时，新增类型可能落入默认分支后被静默忽略。Java 提供三种互补的受限建模工具：`enum` 固定一组命名实例，`record` 紧凑表达一组数据组件，`sealed` 限制一个父类型的直接子类型集合。

受限类型不是“自动完成领域建模”。FactoryCare 的十二个工单状态可以用 enum 表达，但 enum 并不决定哪些状态转换合法、谁有权限、并发版本怎样校验；record 能承载设备坐标，却不自动成为有身份和生命周期的设备实体；sealed 命令层次能让编译器检查类型覆盖，却不替代租户、授权、审计和事务边界。

本章基线为 **Java 25 / JDK 25**，示例不使用 preview 特性。一手资料复核日期为 **2026-07-16**。

## 1. 本章完成证据

至少留下三类可重放证据：

1. **解释**：120 秒内分别说清 enum、record、sealed 的约束对象，说明为何字符串状态、可变数组 record 或带 default 的封闭 switch 会失败。
2. **构建**：用完整十二状态 `WorkOrderStatus`、经过校验的 `EquipmentCoordinate` record、三个 permitted 命令 record 与无 default 的穷尽 switch 完成固定输出。
3. **诊断**：复现拼错状态的运行失败、record 数组组件的相等/别名陷阱、未获许可子类型的编译失败，以及新增 permitted 类型后非穷尽 switch 的编译失败；保存退出码与首条可信诊断。

配套工件：

- [受限类型观察台](../../../examples/encyclopedia/ch.java-oop.enum-record-sealed/README.md)
- [FactoryCare 状态、坐标与命令实验](../../../labs/encyclopedia/ch.java-oop.enum-record-sealed/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-oop.enum-record-sealed/README.md)

私有解答只用于独立尝试后的校准。验证器中的编译与运行失败必须真实发生；删除新分支、加一个吞掉一切的 default 或只打印 `PASS` 都不构成证据。

## 2. 前置知识补救

开始前应能：

- 用 if/switch 处理固定输入；
- 写构造器校验并说明对象不变量；
- 区分引用身份和值相等；
- 定义接口和多个实现，理解父类型引用与动态分派；
- 解释 final 类不能继承、final 字段只完成一次赋值。

若仍把“类型”理解成文件名标签，先回到引用与接口章节：变量的静态类型决定编译期允许的操作，对象的实际类型决定重写实例方法。sealed 正是在这个类型层次上限制直接子类型，不是在运行时扫描包后临时列清单。

## 3. 为什么 String 不是有限状态类型

~~~java
String status = "IN_PROGRES"; // 少了一个 S，仍然是合法 String
~~~

String 类型只保证它是一串字符，不保证属于业务允许集合。可以到处写比较和校验，但每个入口都可能漏掉、大小写策略可能不一致、重命名无法由编译器完整追踪。一个状态变量若只有十二个合法值，类型本身应尽量表达这个有限集合。

“数据库里最终也是文本”不构成反对。外部文本在边界解析成 enum，内部依赖受限类型；输出时再按明确协议编码。边界失败应报告未知值，而不是让拼错字符串继续传播。

## 4. enum 的最小语法

~~~java
enum WorkOrderStatus {
    CREATED,
    TRIAGED,
    ASSIGNED
}
~~~

每个名称是该 enum 类的一个预先声明实例，不是 int 常量，也不是可随意 new 的普通对象。变量只能引用这些常量之一或 null；编译器不会允许 `WorkOrderStatus status = "CREATED"`。

常量通常使用大写下划线命名。末尾分号在只有常量列表时可省略；若后面还声明字段、构造器或方法，常量列表后需要分号。

## 5. FactoryCare 的十二状态唯一词表

本项目确认的状态是：

~~~java
enum WorkOrderStatus {
    CREATED,
    TRIAGED,
    ASSIGNED,
    ACCEPTED,
    IN_PROGRESS,
    PENDING_PARTS,
    PENDING_APPROVAL,
    RESOLVED,
    VERIFIED,
    CLOSED,
    REOPENED,
    CANCELLED
}
~~~

不要创造 `DONE`、`PROCESSING`、`CANCELED` 等近义词。enum 只收紧词表，不证明 `CREATED -> CLOSED` 合法。完整状态转换、角色权限、版本冲突、审批记录、审计和 outbox 在后续领域与事务章节实现；本章不得用 public setter 假装状态机。

## 6. enum 常量是对象

可以调用方法：

~~~java
WorkOrderStatus status = WorkOrderStatus.CLOSED;
String name = status.name();
boolean same = status == WorkOrderStatus.CLOSED;
~~~

每个 enum 常量在一个类加载器范围内是唯一声明实例，因此 enum 常用 `==` 比较；它也继承 Enum 提供的 final equals/hashCode 等行为。不要把这个规则推广到普通值对象，普通 `new DeviceId("D-1")` 的两个实例仍可能需要 equals 判断值相等。

enum 常量可以实现接口行为或拥有常量专属类体，但 L1 优先保持状态 enum 简单。若每个状态包含巨大工作流和外部依赖，可能把完整聚合规则错误塞进了枚举。

## 7. values 与 valueOf

编译器为 enum 提供 `values()` 和 `valueOf(String)`：

~~~java
for (WorkOrderStatus status : WorkOrderStatus.values()) {
    System.out.println(status.name());
}

WorkOrderStatus parsed = WorkOrderStatus.valueOf("IN_PROGRESS");
~~~

`valueOf` 要求名称精确匹配，大小写、空格或拼写错误会抛 IllegalArgumentException；null 会导致另一种失败。不要不加说明地 `trim().toUpperCase()`，因为是否容忍大小写是外部协议决策。解析函数应在输入边界统一处理并把失败映射为稳定业务错误。

## 8. name、toString 与外部编码

`name()` 返回声明中的精确名称。enum 可重写 `toString()` 展示友好文本，但持久化/API 若混用 toString，展示文案变化会破坏协议。更清晰的做法是显式定义稳定外部 code：

~~~java
enum Priority {
    NORMAL("normal"), URGENT("urgent");

    private final String code;
    Priority(String code) { this.code = code; }
    String code() { return code; }
}
~~~

是否使用 name 还是 code 必须有版本与迁移策略。本章不实现数据库映射，只建立“展示字符串不自动等于持久协议”的边界。

## 9. 不要持久化 ordinal

`ordinal()` 是常量在声明列表中的位置，从零开始。新增或重排常量会改变位置，因此不能把 ordinal 当稳定数据库值、消息值或权限码。它主要服务 Enum 的底层与少数内部算法，不是业务 ID。

如果旧数据保存了 4，而代码重排后 4 指向另一个状态，程序可能无异常却解释错误，风险比显式解析失败更大。外部数据应保存有语义、可迁移的稳定编码。

## 10. enum 可以有字段、构造器和方法

~~~java
enum WorkOrderStatus {
    CLOSED(true), CANCELLED(true), CREATED(false);

    private final boolean terminal;

    WorkOrderStatus(boolean terminal) {
        this.terminal = terminal;
    }

    boolean isTerminal() {
        return terminal;
    }
}
~~~

enum 构造器不供业务代码 new；常量声明时由语言创建实例。字段应尽量不可变，方法适合与单个值稳定绑定的只读语义。“已关闭”在 FactoryCare 指 CLOSED 或 CANCELLED，可以集中为查询语义；完整合法边仍不应藏进零散方法。

## 11. enum switch

~~~java
String bucket = switch (status) {
    case CLOSED, CANCELLED -> "TERMINAL";
    case VERIFIED -> "VERIFYING";
    default -> "OPEN";
};
~~~

当业务确实只关心三个分类，default 可表达“其余均开放”。当目标是逐一处理每个状态、并希望新增状态触发编译提醒时，列出全部常量并省略 default 更安全。两种选择对应不同变更契约，不能机械规定永远有或永远没有 default。

本章的 sealed 命令处理器要求逐类覆盖，因此故意不写 default，让新增命令暴露为编译失败。

## 12. enum 的 null 边界

enum 类型仍是引用类型，变量可以是 null。对 null 调方法或用普通 switch 处理而无 null 分支会失败。不要因为 enum 有有限常量就忽略 null；构造器、解析边界和字段不变量仍应拒绝缺失值。

若业务存在“未知/未设置”，决定它是非法缺失、独立 enum 常量还是另一个外层状态。随手用 null 会让每个调用点重复判断，也模糊未知与未提供的区别。

## 13. record 的最小语法

~~~java
record EquipmentCoordinate(String site, int aisle, int slot) {
}
~~~

record 声明一组组件。编译器提供与组件对应的 private final 字段、同名访问器 `site()`、`aisle()`、`slot()`、规范构造器，以及基于组件的 equals、hashCode 和 toString。访问器不是 JavaBean 风格的 `getSite()`。

创建方式：

~~~java
EquipmentCoordinate point = new EquipmentCoordinate("NC-1", 3, 7);
System.out.println(point.site());
~~~

它适合“主要由一组数据定义”的载体和值，不是任何只有字段的类都必须改成 record。

## 14. record 是受限类

record 隐式 final，不能被其他类继承；它隐式扩展 `java.lang.Record`，不能再 extends 普通父类，但可以 implements 接口。不能声明额外实例字段来藏一份未出现在组件中的状态；可以声明 static 成员、方法和嵌套类型。

这些限制让 record 的状态形状一眼可见，也让生成的值方法有明确组件来源。若对象需要延迟加载、代理子类、隐藏可变生命周期或大量额外状态，普通类可能更合适。

## 15. 规范构造器与紧凑构造器

record 的构造参数顺序与组件一致。需要校验或规范化时可写紧凑构造器：

~~~java
record EquipmentCoordinate(String site, int aisle, int slot) {
    EquipmentCoordinate {
        if (site == null || site.isBlank()) {
            throw new IllegalArgumentException("site must have text");
        }
        site = site.trim();
        if (aisle < 1 || slot < 1) {
            throw new IllegalArgumentException("aisle and slot must be positive");
        }
    }
}
~~~

紧凑构造器省略参数列表和显式组件字段赋值；正常完成后由编译器把可能规范化后的参数写入组件字段。先校验、再让对象产生，不能创建半合法 record 后靠 setter 修复。

## 16. record 不自动深不可变

组件字段引用不能重新赋值，不表示引用对象不可变：

~~~java
record Snapshot(int[] readings) {
}
~~~

调用者可在构造后修改原数组，也可通过 `readings()` 得到同一数组并修改。record 自动生成的 equals 对数组组件调用数组自身 equals，而数组默认按引用身份比较；两个内容相同的新数组可能使两个 Snapshot 不相等。

因此 record 只是浅层状态约束。可变组件需要在构造和访问边界复制，或改用真正不可变表示；完整集合复制留到集合章节。不要用“record 是不可变对象”一句话掩盖对象图。

## 17. record 的值相等

~~~java
EquipmentCoordinate a = new EquipmentCoordinate("NC-1", 3, 7);
EquipmentCoordinate b = new EquipmentCoordinate("NC-1", 3, 7);

boolean sameIdentity = a == b;       // false
boolean sameValue = a.equals(b);     // true
boolean sameHash = a.hashCode() == b.hashCode(); // true
~~~

record 生成方法基于所有组件。若某个组件不应参与逻辑相等，可能说明组件选择错误或这个对象并非纯数据值。可以显式覆盖生成方法，但必须继续满足 Object 契约；多数 L1 场景更应先改模型而不是手写特殊相等。

## 18. record 的 toString 不是安全日志保证

默认 toString 会列出组件名称和值，便于调试，也可能泄露 token、手机号、租户秘密或完整消息正文。不要把敏感值直接做成会被自动打印的 record 组件，或为安全边界提供脱敏表示并控制日志。

toString 格式不应当作 JSON、数据库或稳定 API。解析默认 record 字符串会把调试表示误当协议，一旦组件重命名或 JDK 细节变化就破坏调用者。

## 19. record 适合数据载体，不代表贫血设计

record 可以有验证和行为：坐标可以提供 `sameSite`，金额 record 可以执行加法，只要行为围绕其值和不变量。问题不在“有没有方法”，而在它是否主要由固定组件定义。

有独立身份和生命周期的 `WorkOrder` 不应只因字段多就改成 record。工单状态会受命令、权限、版本、审计和事务控制；把所有字段放进 record 再到处 new 新状态，可能绕开聚合规则。本章只用 record 表示坐标与命令数据。

## 20. sealed 类型解决什么

普通接口允许未知代码继续添加实现。若领域明确要求父类型只有一组已知形态，可以声明 sealed：

~~~java
sealed interface WorkOrderCommand
        permits AssignCommand, StartCommand, CloseCommand {
}
~~~

`permits` 列出允许的**直接**子类型。它让类型作者显式控制第一层扩展，并让编译器在 switch 中利用封闭信息检查覆盖。sealed 的主要价值是受限类型建模，不是复用实现代码。

## 21. permitted 子类型必须表态

直接实现 sealed 父类型的类必须明确或隐式成为下列之一：

- `final`：到此关闭，不能继续有子类；
- `sealed`：继续列出下一层允许子类型；
- `non-sealed`：重新开放，从这一层允许自由扩展。

record 隐式 final，因此很适合作为 sealed 命令的叶子：

~~~java
record AssignCommand(String technicianId) implements WorkOrderCommand { }
record StartCommand(String actorId) implements WorkOrderCommand { }
record CloseCommand(String resolution) implements WorkOrderCommand { }
~~~

这三个 record 可以有不同数据形状，却共享一个受限父契约。

## 22. permits 的可见与部署边界

若 sealed 父类型处于 named module，permitted 直接子类型必须在同一模块；若处于 unnamed module，则要在同一 package。编译器需要在受控边界内确认层次，不是运行时扫描任意插件目录。

在满足规则且直接子类型与父类型位于同一编译单元等可推断情形时，可省略显式 permits；教学与跨文件代码常显式写出，便于阅读。具体模块组织在 Java 工程卷展开。

## 23. 未获许可子类型是编译错误

~~~java
final class DeleteCommand implements WorkOrderCommand {
}
~~~

若 DeleteCommand 不在 permits 中，编译器拒绝。不能靠反射或包扫描把它“注册”成合法直接子类型。要新增命令，必须修改父层次声明、实现数据校验、更新全部穷尽处理器和测试，这正是受控变更。

把 permits 改成 non-sealed 只为消除错误会丢掉封闭保证。先确认业务是否真的需要第三方扩展；插件体系通常不适合封闭父类型。

## 24. sealed 与 final 的区别

final 类完全禁止子类；sealed 类型允许一份明确直接子类型名单；non-sealed 子类型从指定位置重新开放。三者表达不同扩展政策：

- `final DeviceId`：这个值类型完成，不允许继承改变相等；
- `sealed WorkOrderCommand`：命令形态有限，但每个形态不同；
- `non-sealed VendorCommand`：核心层承认一条开放扩展支线。

不要因为“更安全”给所有接口加 sealed。未知实现、测试适配器或插件是合法需求时，普通接口更合适。

## 25. pattern switch 处理不同数据形状

~~~java
static String describe(WorkOrderCommand command) {
    return switch (command) {
        case AssignCommand assign -> "ASSIGN|" + assign.technicianId();
        case StartCommand start -> "START|" + start.actorId();
        case CloseCommand close -> "CLOSE|" + close.resolution();
    };
}
~~~

每个 case 是类型模式：匹配成功后得到对应静态类型变量，无需手工 instanceof 加强转。因为 sealed 父类型的 permitted 叶子已全部覆盖，switch 表达式可省略 default 并通过穷尽检查。

## 26. 穷尽性是变更报警器

在 permits 中新增 `CancelCommand`，却没更新上面的 switch，编译器会报告 switch 不覆盖所有可能输入。这不是麻烦，而是迁移清单：所有需要区分命令形态的位置必须决定新类型行为。

若原 switch 写了 `default -> "UNKNOWN"`，新增类型仍能编译，可能在生产被静默归为 UNKNOWN。若业务需要未来未知类型的兼容降级，default 是明确选择；若要求每种核心命令被审查，则不要用 default 掩盖。

## 27. switch 表达式必须产生结果

箭头 case 可直接返回表达式；复杂分支用代码块和 `yield`：

~~~java
case CloseCommand close -> {
    String normalized = close.resolution().trim();
    yield "CLOSE|" + normalized;
}
~~~

每个可到达分支都要产生兼容结果类型。这里的 switch 是表达式，结果赋给变量或 return；不要与传统冒号 case 的 fall-through 混用心智模型。L1 推荐箭头形式，避免漏 break。

## 28. null 与 pattern switch

sealed 限制对象的类型，不排除引用为 null。对 null selector 的 switch 若没有明确 `case null`，通常会在运行时失败。选择在命令构造/服务入口拒绝 null，或显式处理：

~~~java
return switch (command) {
    case null -> throw new IllegalArgumentException("command required");
    case AssignCommand assign -> ...;
    // 其他 permitted 类型
};
~~~

不要用 default 误以为一定接住 null。更重要的是让边界契约说明缺失命令是否合法。

## 29. case 顺序与支配

模式从上到下匹配。若先写覆盖范围更宽的父类型模式，后面的具体类型可能永远不可达，编译器会报告支配问题。sealed 叶子 switch 通常直接列具体 record，避免宽泛 `case WorkOrderCommand command` 抢先匹配。

复杂守卫和 record 解构模式属于后续深化；本章只用类型模式加访问器，先建立可预测的覆盖关系。

## 30. enum 与 sealed 如何选择

| 问题 | enum | sealed 层次 |
| --- | --- | --- |
| 值形态 | 同一 enum 类的一组命名实例 | 多个不同类/record 形态 |
| 每项数据 | 可有固定字段，但结构相同 | 每个子类型可有不同组件 |
| 创建 | 常量预先存在，不能业务 new 新成员 | 可按允许叶子构造多个对象 |
| 典型用途 | 状态、优先级、类别 | 命令、结果、事件变体 |
| 分支 | 按常量 case | 按类型模式 case |
| 扩展 | 修改 enum 声明 | 修改 permits 与叶子类型 |

工单状态用 enum；“分配命令含 technicianId、关闭命令含 resolution”用 sealed record 层次。不要把每个状态做成一个无数据 class，也不要把形状不同的命令塞进一个 enum 加一堆可空字段。

## 31. record 与普通类如何选择

选择 record 前问：

1. 对象是否主要由固定组件定义？
2. 所有组件是否应参与生成的值语义？
3. 是否能在构造时完成校验？
4. 是否不需要隐藏额外实例状态？
5. 是否不需要子类和代理扩展？
6. 组件是否不可变，或已设计防御边界？

若多数答案为是，record 很合适。若对象有稳定身份、复杂生命周期、受控状态变化或框架代理需求，普通 final/非 final 类更清晰。语法短不是首要决策维度。

## 32. 三者组合的对象模型

FactoryCare 本章最小模型：

~~~text
WorkOrderStatus enum
  └─ 只表达十二个合法名称和少量只读分类

EquipmentCoordinate record
  └─ site + aisle + slot，构造即合法，按组件值相等

WorkOrderCommand sealed interface
  ├─ AssignCommand record
  ├─ StartCommand record
  └─ CloseCommand record
~~~

这些是类型词汇，不是完整业务服务。谁能关闭、当前状态能否关闭、版本是否过期，仍由聚合和应用边界校验。

## 33. 失败案例：字符串状态漂移

若数据库、API、测试各自写 String，可能同时出现 `CANCELED` 与项目标准 `CANCELLED`。简单修复不是在每个 if 加两个拼法，而是在输入边界建立明确解析/迁移，内部统一 enum，输出只使用冻结 code。

诊断时保存原始输入、解析目标类型和异常类别，但不要把整条含敏感数据的请求写日志。未知值应定位到边界，不应在深层 switch 才以 default 消失。

## 34. 失败案例：用 ordinal 作为协议

第一版 `CREATED` ordinal 0、`CLOSED` ordinal 1；第二版在中间插入 `VERIFIED`，旧数据 1 被解释为 VERIFIED。所有数字都在范围内，测试若只验证“能解析”会漏掉。

使用明确 code，并为重命名/废弃做数据迁移。回滚时也要知道新 code 是否已写入旧版本不认识的存储；这属于数据演进，不由 enum 自动解决。

## 35. 失败案例：record 包装可变数组

两个 `new Snapshot(new int[]{1,2})` 内容相同，生成 equals 仍可能 false；调用 `snapshot.readings()[0]=9` 又能修改可观察状态。问题来自组件本身的数组语义，不是 record 编译器坏了。

修复要同时考虑输入别名、输出泄漏和值比较。可以复制数组并自定义访问器/equals/hashCode，或选择真正不可变组件类型；集合方案留到下一卷。只在 equals 里用 Arrays.equals 而继续泄漏数组，仍未得到不可变值。

## 36. 失败案例：default 吞掉新增命令

核心命令 switch 写 `default -> "ignored"` 后，新增 CancelCommand 会悄悄返回 ignored。编译器无法提醒每个处理器；审计可能缺失，调用者却看到正常返回。

若封闭集合的每个成员都必须审查，删掉 default 并列全 permitted 叶子。新增类型时先让编译失败列出影响点，再逐处设计行为和测试，而不是先加宽泛 default 恢复绿色。

## 37. 失败案例：sealed 代替权限

只有 `CloseCommand` 在 permits 中，不代表当前用户有关闭权限。任何能调用公开构造器的代码都可能创建这个 record。sealed 只控制**谁能成为类型家族成员**，不控制**谁能创建/提交实例**。

授权必须检查认证主体、角色、租户范围、当前工单状态和版本；命令处理还要写审计。不要把类型安全当安全授权证明。

## 38. 调试 enum 解析失败

遇到 IllegalArgumentException：

1. 保存原始值的可见表示，确认前后空格、大小写和拼写；
2. 打印目标 enum 类型和允许 code 列表，但不泄露完整请求；
3. 确认调用的是 name-based valueOf 还是自定义 code 解析；
4. 检查版本是否新增/删除/重命名常量；
5. 在边界修复映射，不把未知值随意映射 CREATED；
6. 加入固定失败样例并复跑。

`valueOf` 报错是可信边界证据，不要 catch 后返回 null，让错误更晚变成 NPE。

## 39. 调试 record 值异常

看到两个看似相同 record 不 equal：

1. 分别打印每个组件的类型和值；
2. 检查数组、可变对象或未规范化字符串；
3. 检查是否一个 site 带空格、大小写不同；
4. 观察 `a == b` 与 `a.equals(b)`，不要混淆身份；
5. 对数组分别验证同一引用与相同内容；
6. 确定业务相等应包含哪些组件；
7. 修复构造边界或模型，再验证 hash 一致。

下一章会完整讲 equals/hashCode 直接契约。本章只使用 record 生成值语义并暴露可变组件反例。

## 40. 调试 sealed/switch 编译失败

新增类型后收到 non-exhaustive switch：

1. 查看 sealed 父类型 permits；
2. 列出每个 direct subtype 的 final/sealed/non-sealed 状态；
3. 找 switch 实际 selector 静态类型；
4. 列出已覆盖类型模式；
5. 决定新类型的真实行为，而不是先加 default；
6. 处理所有编译点并补固定输出；
7. 复跑 null 和非法输入。

未获许可错误则检查包/模块、direct relation 和 permits 拼写。不要通过取消 sealed 逃避模型决定。

## 41. 直接测试 enum

不需要集合也能验证：

- `values().length == 12`；
- `valueOf("IN_PROGRESS") == IN_PROGRESS`；
- `CLOSED.isTerminal()` 与 `CANCELLED.isTerminal()` 为 true；
- `VERIFIED.isTerminal()` 为 false；
- 拼错值真实抛异常；
- ordinal 不进入任何外部输出断言。

长度断言是本项目冻结词表的警报，不是所有 enum 都必须固定数量。新增状态属于业务契约变更，需要同时更新状态机与上下游。

## 42. 直接测试 record

固定 a、b、c 三个坐标：a/b 同组件、c 不同 slot。断言：

- a 与 b 不是同一引用；
- a.equals(b) 与 b.equals(a)；
- 相等对象 hash 相同；
- a 不等于 c 和 null；
- trim 后组件是规范值；
- 非法 site/aisle/slot 构造失败；
- toString 可定位但不被当协议解析。

record 数组失败单独运行，避免把错误期望混入正确坐标值测试。

## 43. 直接测试 sealed 穷尽处理

对每个 permitted record 构造固定对象并调用同一个 `describe(WorkOrderCommand)`：

- Assign 保留 technicianId；
- Start 保留 actorId；
- Close 保留 resolution；
- null 在边界稳定失败；
- 处理器没有 default；
- 新增 Cancel fixture 时先观察编译失败，再补 case。

源码检查“没有 default”不是唯一证据；真正的非穷尽 fixture 让 javac 以非零退出证明编译器门生效。

## 44. 安全、隐私与可观察性

record 默认 toString 会打印组件，命令 record 不应携带明文密钥、完整手机号或无需传播的工单私密备注。若必须携带敏感值，提供脱敏日志表示并限制记录边界。enum 解析日志记录字段名和未知 code，不回显整个请求。

sealed 不做授权，enum 不做状态机，record final 不做深不可变。安全评审要逐项检查输入、权限、租户、可变别名和日志，而不是看到三个关键字就标记通过。

## 45. 性能与表示取舍

enum 常量和 record 访问器通常很轻量，sealed switch 也可被 JVM 优化，但不能据此承诺具体对象布局、分派表或内联结果。选择它们首先因为约束更清楚、编译器能提供更多检查。

不要为了少一个对象把不同命令塞进 `Object[]`，也不要为避免 switch 创建反射注册表。真实热点出现后用剖析证据优化，仍需保持类型与安全契约。

## 46. 与 TypeScript / Vue 的对照

TypeScript 常用字符串字面量联合表示有限状态，用 discriminated union 表示不同数据形状；Java enum 类似受限命名值，sealed interface + record 类似显式、名义化的判别联合。差异是 Java 类必须声明 permits/implements，record 是运行时类并有生成方法，不只是编译期结构。

TypeScript object 的 readonly 也常是浅只读，和 record 不自动深不可变相似。Vue props 的 readonly 视图不能保证嵌套对象永远不变，同样要看可达对象。

不要把 TypeScript 的 `default: never` 技巧原样当 Java 规则；Java switch 穷尽性由语言对 enum/sealed 类型覆盖进行检查。

## 47. 预测题

先写答案再运行：

1. 能否 `new WorkOrderStatus()`？为什么？
2. `valueOf("in_progress")` 是否自动忽略大小写？
3. ordinal 能否作为稳定数据库状态码？
4. enum 变量能否为 null？
5. record 访问器叫 `site()` 还是 `getSite()`？
6. record 含 int[] 后是否自动深不可变？
7. 两个数组内容相同的 record 一定 equal 吗？
8. record 能否 extends 普通类？能否 implements 接口？
9. permitted 子类为什么必须 final/sealed/non-sealed？
10. 新增 permitted 类型后，无 default 的 switch 会怎样？
11. 有 default 是否一定是错误？它选择了什么演进策略？
12. sealed 是否能阻止无权限用户创建合法命令对象？

## 48. 动手与故障训练

### 48.1 enum 构建

写出 FactoryCare 十二状态，不实现转换。增加 `isTerminal`，只让 CLOSED/CANCELLED 返回 true。验证数量、精确解析、终态分类和拼错输入失败。

### 48.2 record 构建

写 EquipmentCoordinate，site trim，aisle/slot 必须大于零。构造三对象验证身份、值相等、hash 与失败输入。再把组件临时换成数组，观察相等和别名问题后恢复安全模型。

### 48.3 sealed 构建

定义 Assign/Start/Close 三个 command record 和无 default switch。输出三个固定摘要。加入 CancelCommand 但不加 case，保存编译失败；再设计 Cancel 数据并补齐。

### 48.4 需求变更

新增 `RequestApprovalCommand(reason)`。先让所有穷尽处理器编译失败形成影响清单，再补 case、空白 reason 构造失败和脱敏日志。不要顺便实现审批权限或数据库状态迁移。

## 49. 无 AI 独立训练

限时 90 分钟：

1. 从空目录写十二状态 enum；
2. 写一个 enum 字段和只读语义方法；
3. 复现 valueOf 拼写失败；
4. 写带紧凑构造校验的坐标 record；
5. 证明两个 record 身份不同但值相等；
6. 复现数组组件相等/别名陷阱；
7. 写 sealed 命令接口和三个 record 叶子；
8. 写无 default 的 pattern switch；
9. 加第四叶子制造非穷尽编译失败；
10. 制造未获许可实现编译失败；
11. 补齐新类型并复跑；
12. 120 秒复述三种受限工具边界。

允许查看 JLS、Java SE API 与 javac 帮助，不允许 AI 直接生成最终代码。提交源码、命令、预测、正常输出、四类失败退出码、修复输出和复述提纲。

## 50. 高频误区

1. **“enum 是一组 int。”** 它是受限 enum 类的命名实例。
2. **“valueOf 会容错大小写。”** 它按声明名精确匹配。
3. **“ordinal 是稳定业务码。”** 重排和插入会改变它。
4. **“enum 自动实现状态机。”** 它只约束状态词表。
5. **“enum 绝不会 null。”** enum 仍是引用类型。
6. **“record 只是少写 getter。”** 它定义组件、规范构造和值方法等受限类语义。
7. **“record 自动深不可变。”** 可变组件仍会泄漏和变化。
8. **“record 数组按内容 equal。”** 数组默认 equals 是身份语义。
9. **“record 适合所有实体。”** 有身份生命周期的聚合通常需要普通类边界。
10. **“sealed 就是 final。”** sealed 允许受控子类型，final 完全关闭。
11. **“permits 列所有后代。”** 它列直接子类型。
12. **“permitted 类可不声明扩展政策。”** 它必须 final/sealed/non-sealed 或有相应隐式状态。
13. **“default 永远最好。”** 它可能吞掉新增封闭分支。
14. **“无 default 永远最好。”** 兼容未知类型时可能需要明确降级。
15. **“sealed 提供权限控制。”** 它控制类型扩展，不控制业务授权。
16. **“switch 模式会自动处理 null。”** null 边界必须显式决定。
17. **“toString 可作为稳定序列化。”** 它是调试表示，不是协议。
18. **“类型受限后无需运行测试。”** 组件校验、权限和副作用仍需测试。

## 51. 120 秒复述模板

“enum 定义有限命名实例，适合 FactoryCare 十二状态；valueOf 精确解析，ordinal 不能做稳定协议，enum 本身不实现状态转换。record 用固定组件表达数据载体，生成访问器、规范构造、equals/hashCode/toString；它隐式 final 但只是浅层约束，可变数组组件仍会泄漏且按身份相等。sealed 父类型通过 permits 限制直接子类型，叶子必须 final、sealed 或 non-sealed；不同命令可用不同 record 组件。pattern switch 可利用封闭层次做穷尽检查，新增 permitted 类型会让无 default 处理器编译失败。三者提升可表达约束，但都不替代聚合、权限、审计和事务。”

## 52. 间隔复习

- 当天：画 enum 实例、record 组件、sealed 类型树三张图；
- 第 2 天：闭卷写十二状态与坐标 record，复现两个失败；
- 第 7 天：写三命令和穷尽 switch，新增第四类型让编译器报警；
- 第 14 天：分析一个数组 record 的输入/输出别名与相等；
- 第 30 天：审查 FactoryCare 一个 String 状态和一个大 DTO，决定是否迁移及非目标。

每次先预测编译还是运行失败，再执行。记录一条误区、一条可复用规则和下一次复习日期。

## 53. 一页速查

| 问题 | 最小结论 |
| --- | --- |
| enum | 固定一组命名实例的受限类 |
| 创建 enum | 使用常量，业务代码不能 new 新成员 |
| `values()` | 返回声明常量序列供遍历 |
| `valueOf` | 按 name 精确解析，未知值失败 |
| `name()` | 声明名；展示与协议仍需设计 |
| `ordinal()` | 声明位置，不用作稳定外部码 |
| enum 比较 | 常量唯一，通常用 `==` |
| record | 固定组件的数据载体类 |
| record 访问器 | 与组件同名，无 get 前缀 |
| 紧凑构造器 | 校验/规范化参数，隐式完成字段赋值 |
| record 相等 | 基于全部组件及其自身相等语义 |
| record 可变组件 | 不自动复制，不自动深不可变 |
| sealed | 限制直接子类型集合 |
| permits | 列允许的直接子类型 |
| 叶子政策 | final / sealed / non-sealed |
| pattern switch | 按运行时类型模式处理不同形状 |
| 穷尽 switch | 覆盖所有可能类型，可省略 default |
| default 取舍 | 兼容降级或掩盖新增类型，必须显式决定 |
| 安全边界 | enum/record/sealed 都不替代授权与审计 |

## 54. 术语表

- **enum 类**：定义有限命名实例的受限类。
- **enum 常量**：enum 声明预先创建的命名实例。
- **外部编码**：跨数据库、API 或消息传输的稳定文本/数值表示。
- **ordinal**：enum 常量声明位置，不是业务标识。
- **record 类**：由固定组件描述状态的受限数据载体类。
- **record 组件**：record 头部声明的名称与类型。
- **规范构造器**：参数列表与 record 组件对应的构造器。
- **紧凑构造器**：省略参数列表和显式组件赋值的 record 构造体。
- **浅不可变**：外层字段绑定稳定，但可达子对象仍可能变化。
- **数据载体**：主要在边界间携带一组值的对象。
- **sealed 类型**：只允许已知直接子类型的类或接口。
- **permitted subtype**：在 permits 中或由规则推断允许的直接子类型。
- **non-sealed**：从 sealed 层次某一支重新开放继承。
- **类型模式**：在匹配类型的同时引入该静态类型变量的模式。
- **穷尽性**：switch 覆盖 selector 所有可能值/类型的性质。
- **支配**：前一模式覆盖后一模式，使后一分支不可到达。
- **封闭模型**：类型成员集合由源码边界明确控制的模型。
- **迁移报警器**：新增成员后用编译失败暴露所有待决定处理点。

## 55. 本章边界与官方来源

本章要求用 enum 表达 FactoryCare 十二状态词表、用 record 表达经过构造校验的坐标值、用 sealed interface + record 表达不同命令形状，并用无 default pattern switch 验证穷尽；能复现拼错状态、数组 record、未许可子类型和新增分支失败。完整状态机、权限、聚合、持久化迁移、集合防御复制、record pattern 深化、反射与框架序列化不在本章展开。

以下一手资料已于 **2026-07-16** 按 Java SE 25 / JDK 25 复核：

- [JLS 25 §8.9 Enum Classes](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.9)：enum 声明、常量与受限类语义。
- [Enum API, Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Enum.html)：name、ordinal、valueOf 与 enum 基类契约。
- [JLS 25 §8.10 Record Classes](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.10)：record 组件、成员与构造器。
- [Record API, Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Record.html)：record 基类与生成方法契约定位。
- [JLS 25 §8.1.1.2 sealed, non-sealed, and final Classes](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.1.1.2)：sealed 扩展政策。
- [JLS 25 §8.1.6 Permitted Direct Subclasses](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.1.6)：permits、模块与直接子类限制。
- [JLS 25 §9.1.4 Permitted Direct Subclasses and Subinterfaces](https://docs.oracle.com/javase/specs/jls/se25/html/jls-9.html#jls-9.1.4)：sealed interface 的允许实现。
- [JLS 25 §14.11 switch Statements](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html#jls-14.11)：switch 模式、覆盖与穷尽性。
- [JLS 25 §15.28 switch Expressions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.28)：switch 表达式求值与结果。
- [OpenJDK JDK 25 Project](https://openjdk.org/projects/jdk/25/)：JDK 25 参考实现与 GA 信息。
- [javac 25 Tool Guide](https://docs.oracle.com/en/java/javase/25/docs/specs/man/javac.html)：`--release 25` 与编译诊断入口。

稳定核心是：enum 约束命名值集合，record 约束数据组件形状，sealed 约束直接子类型集合；穷尽 switch 把封闭模型变化转成编译期迁移信号。具体诊断文本、对象布局和 JVM 优化不是语言层保证，验证器只登记本基线的可观察证据。
