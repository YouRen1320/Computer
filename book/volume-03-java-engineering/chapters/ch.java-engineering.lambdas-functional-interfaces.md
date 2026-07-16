---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.lambdas-functional-interfaces
title: Lambda、函数式接口与方法引用
responsibility: 教授行为作为值传递的语言机制，不在本章引入 Stream 管道或响应式框架
volume: '03'
order: 7
level: L1
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.lambdas-functional-interfaces.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.interfaces-polymorphism
version_surfaces:
- jdk-25
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释Lambda、函数式接口与方法引用的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-functional-interface
  - java-lambda
  covers_topics:
  - java.sam-interface
  - java.function-consumer-predicate
  - java.behavior-contract
  - java.lambda-expression
  - java.method-reference
  - java.effectively-final-capture
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.methods
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 定义工单过滤 Predicate、优先级 Function 和通知 Consumer，用 Lambda 与方法引用互换实现
  covers_topic_groups:
  - java-functional-interface
  - java-lambda
  covers_topics:
  - java.sam-interface
  - java.function-consumer-predicate
  - java.behavior-contract
  - java.lambda-expression
  - java.method-reference
  - java.effectively-final-capture
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.methods
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入捕获后修改局部变量、接口有两个抽象方法和 Lambda 内隐藏副作用，读取编译/行为证据修复
  covers_topic_groups:
  - java-functional-interface
  - java-lambda
  covers_topics:
  - java.sam-interface
  - java.function-consumer-predicate
  - java.behavior-contract
  - java.lambda-expression
  - java.method-reference
  - java.effectively-final-capture
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.methods
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Lambda、函数式接口与方法引用

> 本章状态为 `drafting`。固定 Java 25 oracle 只能证明配套示例在当前机器满足本章合同；P9 零基础试读、人工版式与无障碍检查、独立全面审查和全书回归尚未执行，因此不能把本章视为 `verified`，也不会据此修改 `PROGRESS.md`。

普通方法把数据作为参数传入，把数据作为结果返回。很多业务需求还需要把“如何判断”“如何转换”“完成后做什么”交给调用方决定：派单器可以接收不同的工单规则，告警器可以接收不同的通知动作，格式化器可以接收不同的标签生成策略。Java 的 Lambda 不是一种新的独立函数类型，而是用简洁语法创建某个函数式接口的实例。接口给出合同，Lambda 提供那一个抽象行为的实现，变量、参数和返回值则让这段行为像其他对象一样被传递。

本章从零建立“行为作为值”的模型，覆盖单一抽象方法接口（SAM）、`Predicate`/`Function`/`Consumer`/`Supplier`、目标类型、Lambda 语法、四类方法引用、闭包捕获、有效 final、行为合同、组合、异常和副作用测试。不进入 Stream 管道，不把 Lambda 等同于纯函数，也不讨论响应式框架。连续场景仍是 FactoryCare 工单规则。版本基线为 **JDK 25**，官方资料复核日期为 **2026-07-16**。

## 1. 学完必须留下的证据

1. 在 120 秒内解释“函数式接口是类型，Lambda 是该类型的一个实现”，并说明目标类型为什么决定参数与返回值。
2. 为工单分别定义过滤 `Predicate`、标签 `Function`、通知 `Consumer` 和延迟创建 `Supplier`，用成功、边界和非法输入断言合同。
3. 把可读的 Lambda 替换成等价方法引用，说明接收者、参数顺序和返回值如何匹配，而不是只说“写法更短”。
4. 预测并复现局部变量不再有效 final 的编译错误；区分“不能重新赋值捕获变量”与“捕获的可变对象仍可能被修改”。
5. 复现双抽象方法接口不能作为 Lambda 目标类型、通知行为隐藏重复写入、方法引用签名不匹配等故障，并指出第一处可信证据。

配套工件：

- [Lambda 与方法引用示例](../../../examples/encyclopedia/ch.java-engineering.lambdas-functional-interfaces/README.md)
- [FactoryCare 行为合同实验](../../../labs/encyclopedia/ch.java-engineering.lambdas-functional-interfaces/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.lambdas-functional-interfaces/README.md)

公开 starter 初始失败是练习合同的一部分。先写预测、运行并定位错误，再修改 TODO；私有解答不进入公开教材或链接图。

## 2. 先建立模型：接口是插座，Lambda 是可插拔行为

假设派单方法内部写死“优先级至少 3 才派发”。下一次需求改成“未关闭且优先级至少 3”，再下一次又按区域、技能或 SLA 判断。如果每个变化都复制整个派单循环，遍历、日志和错误处理会与业务规则缠在一起。更稳的分解是让派单方法接收一个判断行为：派单器负责“何时调用”，规则负责“给定一张工单是否通过”。

Java 变量必须有静态类型。不能只写一段悬空的 `(order) -> order.priority() >= 3` 就期待编译器永远猜出含义；同样的参数与返回形状可能对应 `Predicate<WorkOrder>`、自定义 `DispatchRule`，甚至带受检异常的另一个接口。赋值、实参、返回或强制转换所在的上下文给 Lambda 一个目标类型。目标函数式接口的唯一抽象方法决定参数个数、参数类型、返回类型和允许抛出的异常。

```java
Predicate<WorkOrder> urgent = order -> order.priority() >= 3;
boolean accepted = urgent.test(order);
```

这里变量 `urgent` 保存的不是已经算出的布尔值，而是一个可在以后用 `test` 调用的行为对象。`order` 的类型来自 `Predicate<WorkOrder>.test(WorkOrder)`，表达式结果必须能转换为 `boolean`。把相同 Lambda 赋给 `Function<WorkOrder, Boolean>` 可能也能编译，但调用方法变成 `apply`，装箱和语义名字也不同。形状相似不代表合同相同。

“行为作为值”仍然遵守对象和接口规则。可以把它传参、返回、放入字段或集合，可以用多态替换实现，也可以因为捕获外部状态而携带上下文。Lambda 没有取消类型系统、异常合同、线程安全或测试义务；它只是减少实现一个简单接口时的样板代码。

## 3. 函数式接口：一个抽象行为，不是只能有一个方法

函数式接口有一个函数描述符，也常称 SAM（single abstract method）合同。判断时看的是抽象实例方法集合，而不是源码里所有方法的数量。接口可以有 `default` 方法和 `static` 方法；与 `Object` 公共方法签名相同的方法也不会平白增加一个函数描述符。真正存在两个互不覆盖的抽象业务方法时，编译器无法知道 Lambda 同时怎样实现两者，它就不是合法目标类型。

```java
@FunctionalInterface
interface DispatchRule {
    boolean accepts(WorkOrder order);

    default DispatchRule and(DispatchRule other) {
        return order -> accepts(order) && other.accepts(order);
    }
}
```

`@FunctionalInterface` 不是让接口“变成”函数式接口的开关；满足规则的接口即使不写注解也能作为目标类型。注解的价值是把设计意图交给编译器守护：后来有人加入第二个抽象方法，编译会立刻失败，而不是等调用方的 Lambda 在远处一起坏掉。面向业务的 SAM 应有清楚名字、参数和返回语义，例如 `DispatchRule.accepts` 比泛化的 `execute` 更容易读懂。

也不要为每个一行规则都创建新接口。若标准 `java.util.function` 类型准确表达合同，优先复用；若业务需要领域名称、专属组合方法、受检异常策略或更强文档，再定义自有接口。选择维度不是“自定义更专业”或“标准接口更短”，而是调用处能否一眼看出责任，以及接口是否真的携带标准类型无法表达的合同。

一个常见误解是“函数式接口的方法必须叫 apply”。实际方法名任意；`Runnable.run`、`Comparator.compare` 和自定义 `accepts` 都可以形成函数描述符。另一个误解是“Lambda 可以实现抽象类”。Lambda 的目标必须是函数式接口，抽象类即使只有一个抽象方法也不符合这套转换规则；需要抽象类状态或构造过程时，使用普通子类或组合。

## 4. 四个基础形状：先问输入和输出，再选类型

`Predicate<T>` 接收一个 `T` 并返回 `boolean`，适合“是否满足”。FactoryCare 中可以表达“是否高优先级”“是否属于当前班组”。它的核心方法是 `test`，并提供 `and`、`or`、`negate` 组合。谓词名字应能读成问题；若内部同时发通知或改工单状态，就把查询和命令混在了一起。

`Function<T,R>` 把一个 `T` 转成一个 `R`，适合“从工单得到优先级标签”或“从 DTO 映射领域值”。核心方法是 `apply`，可以用 `andThen` 表达先执行当前转换再执行下一个，用 `compose` 表达先执行参数函数再执行当前函数。两者顺序相反，必须以具体值手算，不能只背方法名。

`Consumer<T>` 接收 `T` 而不返回业务结果，适合通知、写入或输出等明确副作用。核心方法是 `accept`。`void` 不等于没有结果：它通常意味着结果发生在外部世界，因此要测试调用次数、目标、顺序、幂等要求和失败传播。把所有逻辑都塞进 Consumer 会让数据流不可观察；应尽量先计算要发送的命令，再在边界执行。

`Supplier<T>` 不接收参数而提供一个 `T`，适合延迟创建、默认值或向业务逻辑注入时钟/ID 来源。核心方法是 `get`。Supplier 每次调用是否应返回相同对象，是合同问题而不是类型能表达的事实。测试 ID 生成器时可以注入确定性 Supplier；生产中再接真实 UUID 来源。

还有 `UnaryOperator<T>`、`BinaryOperator<T>`、`BiFunction<T,U,R>`、`BiPredicate<T,U>` 与原始类型特化如 `IntFunction<R>`。初学时不要靠名字堆砌记忆。先画“输入槽位 → 输出槽位”：一入一布尔是 Predicate，一入一出是 Function，一入无返回是 Consumer，无入一出是 Supplier。涉及两个输入再看 `Bi`；输入输出同类型再看 Operator；大量基本数值计算才评估特化接口以减少装箱。

## 5. Lambda 语法：省略的是样板，不是合同

Lambda 由参数列表、箭头和主体组成。单个推断类型参数可省略圆括号；多个或零个参数需要圆括号。单表达式主体会把表达式结果作为返回值；代码块主体必须像普通方法一样处理每条可达路径的返回。参数类型可以由目标类型推断，也可以显式写出，但同一参数列表不要一半显式一半省略。

```java
Predicate<WorkOrder> urgent = order -> order.priority() >= 3;
Function<WorkOrder, String> label = order -> {
    Objects.requireNonNull(order, "order");
    return "P" + order.priority();
};
Consumer<WorkOrder> notify = order -> notifier.send(order.id());
Supplier<String> nextId = () -> "WO-201";
```

短不等于清楚。若主体需要多次条件分支、异常翻译、重试或多项副作用，把它提取成有名字的方法，再用 Lambda 或方法引用连接。提取后不仅调用处更短，还能单独测试核心逻辑。反过来，一行 `order -> isUrgent(order)` 若没有捕获或适配，通常可以考虑 `this::isUrgent`；但只在方法名确实比 Lambda 更能表达意图时替换。

Lambda 参数会引入局部作用域，但 Lambda 本身不像匿名类那样建立新的 `this`。Lambda 中的 `this` 指向包围实例，不能把它理解成“Lambda 对象自身”。这在注册回调时尤其重要：`this::handle` 与 `event -> this.handle(event)` 都绑定外层对象，可能延长该对象生命周期。章节实验不依赖 GC 时机，但设计评审应问清回调由谁持有、何时解除。

## 6. 目标类型与重载：编译器推断也需要足够上下文

Lambda 是多态表达式，其类型来自使用位置。赋值给明确变量最容易读；直接传给重载方法时，若多个候选函数式接口的参数形状相近，编译器可能无法消歧。解决办法包括改善 API 名称、先声明带类型变量、显式标注参数类型或做窄而有意义的强制转换。不要靠随意加转换让调用“能编译”，转换必须代表真实合同。

例如 `register(Predicate<WorkOrder>)` 与 `register(Function<WorkOrder, Boolean>)` 同时存在，`register(order -> order.priority() > 2)` 会把人和编译器都置于模糊处境。两个 API 虽形状近似，但一个是判定、一个是转换；更好的设计往往是用 `registerRule` 与 `registerMapper` 显式区分责任。重载解析困难经常是 API 语义拥挤的信号，不只是语法障碍。

返回值也参与适配。一个有结果的方法可以在某些语句表达式上下文被适配给 Consumer，因为调用结果被丢弃；这虽然可能合法，却容易让读者误以为结果被使用。若丢弃结果是关键决策，写出命名包装方法或显式 Lambda，并用注释说明边界。可编译只证明形状兼容，不证明业务意图正确。

## 7. 方法引用：把已经有名字的行为接到目标接口

方法引用仍然需要目标类型，不是直接调用方法。它告诉编译器：当函数式接口方法被调用时，把收到的参数按匹配规则交给这个已有方法。常见四种形式如下。

1. `TypeName::staticMethod` 引用静态方法，例如 `WorkOrderRules::isUrgent`。SAM 参数依次成为静态方法参数。
2. `instance::instanceMethod` 绑定一个已经存在的接收者，例如 `notifications::add`。SAM 参数传给该实例的方法，接收者已固定。
3. `TypeName::instanceMethod` 是未绑定实例方法引用，例如 `WorkOrder::id`。SAM 的第一个参数成为方法接收者，其余参数才是方法实参。
4. `TypeName::new` 引用构造器，例如 `ArrayList::new`。具体选择哪个重载构造器仍由目标类型的参数形状决定。

```java
Predicate<WorkOrder> a = WorkOrderRules::isUrgent;
Function<WorkOrder, String> b = WorkOrder::id;
Consumer<String> c = notifications::add;
Supplier<ArrayList<String>> d = ArrayList::new;
```

判断是否等价时，逐项核对接收者、参数数目、参数顺序、可转换类型、返回值和异常。`WorkOrder::hasPriority` 若实例方法还接收一个阈值，需要 `BiPredicate<WorkOrder,Integer>`，而不是 `Predicate<WorkOrder>`。重载方法引用若目标上下文不足也会歧义。方法引用不是盲目的“IDE 灰色建议”，更不是性能优化；它主要是命名与可读性选择。

方法引用还可能在创建时就求值绑定接收者。`service::send` 需要先得到 `service`；若接收者表达式为 null，问题可能在构造引用时出现，而不是将来调用时才出现。相比之下，`message -> service.send(message)` 对字段的读取发生在执行主体时。不要用这种差异玩技巧，但调试空指针或生命周期问题时要知道绑定时机。

## 8. 闭包与有效 final：捕获的是稳定变量绑定

Lambda 可以读取包围方法中的局部变量，这种携带词法环境的行为常被称为闭包。Java 要求被捕获的局部变量是 final 或“有效 final”：声明后没有再次赋值，即使没有显式写 `final` 也可以。循环变量、参数同样按规范检查。规则让捕获的局部绑定保持稳定，避免栈上局部变量生命周期结束后又出现“到底看旧值还是新值”的含混模型。

```java
int threshold = 3;
Predicate<WorkOrder> urgent = order -> order.priority() >= threshold;
// threshold++; // 此时 threshold 不再是 effectively final，编译失败
```

要先分清两个层次。不能给 `threshold` 重新赋值，不等于捕获的一切都不可变。如果捕获的是 `List<String> notifications` 的引用，变量绑定可以保持不变，而 Lambda 仍可 `notifications.add(...)` 修改列表。编译器保护的是局部变量绑定，不替你保证对象不可变、线程安全或无副作用。

“用长度为 1 的数组绕过有效 final”通常是坏修复。它把清楚的编译失败变成共享可变状态，让调用次数和并发次序影响结果。若确实需要累计，优先让方法返回新值，由明确所有者在循环外更新；若需求本身是边界写入，封装成职责清晰的对象并测试其同步与生命周期。`AtomicInteger` 也不是让副作用合理的魔法，它只解决特定原子操作，不解决业务顺序和重复执行。

捕获值还影响对象生命周期。一个长期存活的回调若捕获整个页面、服务或大集合，持有回调的注册中心也会间接持有那些对象。是否构成泄漏取决于所有权和注销机制，不能只看 Lambda 只有一行。工程审查应问：谁保存它、保存多久、能否只捕获必要值、何时解除注册。

## 9. 行为合同：相同形状不保证相同语义

函数式接口只描述输入输出形状，许多重要语义仍需文档与测试表达。一个 `Predicate<WorkOrder>` 是否允许 null？是否读取当前时间？同一输入重复调用是否必须一致？失败时抛异常还是返回 false？一个 `Consumer<WorkOrder>` 能否重复执行？通知顺序是否重要？调用方会不会重试？这些都不是泛型参数能回答的。

本章示例给规则规定：输入工单不可为 null；优先级阈值在构造规则时固定；相同不可变工单得到相同结果；规则不得修改工单或通知列表。通知 Consumer 则明确允许写入测试替身一次，空输入拒绝，异常向调用方传播。把纯判断与边界副作用分开后，Predicate 可以靠输入输出断言，Consumer 可以靠记录器断言次数和内容。

非法输入策略必须一致。`order -> order != null && order.priority() >= 3` 把 null 当“不通过”，`order -> Objects.requireNonNull(order).priority() >= 3` 把 null 当合同违例；两种都可能合理，但调用方含义不同。不要在某个 Lambda 悄悄吞掉 null，而同类规则抛异常。选择后用命名、文档与失败测试固定。

行为对象放入字段后，还要考虑依赖变化。捕获配置快照意味着后来配置更新不影响已建规则；捕获可变配置对象意味着同一个行为可能随时间改变。前者可预测但需重建，后者动态但测试和并发复杂。不是所有闭包都应纯粹，不过变化来源必须显式，不能藏在简短语法背后。

## 10. 组合：把小行为连接起来，但保留短路与顺序语义

`Predicate.and` 与 `Predicate.or` 具有短路行为：`and` 的左侧为 false 时不调用右侧，`or` 的左侧为 true 时不调用右侧。若右侧偷偷记录审计，是否执行就会依赖左侧结果，这再次说明谓词不应隐藏副作用。`negate` 反转判断结果，但不能自动创造更好的业务名字；把组合赋给 `dispatchable` 比在调用处堆三层括号更易解释。

`Function.andThen` 先应用左函数，再把结果传给右函数；`compose` 则先应用传入函数。用类型轨道检查最可靠：`Function<A,B>` 连接 `Function<B,C>` 才形成 `Function<A,C>`。若把工单先转 priority，再转标签，写成 `extractPriority.andThen(formatPriority)`；手算一张 P4 工单能快速抓住顺序反转。

`Consumer.andThen` 串联两个副作用，前一个抛异常时后一个不会执行。若业务要求“通知失败仍要记录审计”或两者都尝试，普通 `andThen` 不是完整编排策略；需要显式错误处理和可观察结果。本章只展示顺序合同，不把副作用链当事务。

组合层数过深会牺牲调试性。当堆栈只显示多个合成 Lambda，给关键阶段命名并拆出方法更容易设置断点、记录输入和定位异常。可组合不是必须组合；三段以内、输入输出清楚通常合适，包含分支、重试或资源生命周期时用普通方法更稳。

## 11. 异常边界：标准函数式接口不会替你翻译受检异常

标准 `Function`、`Consumer` 等抽象方法没有声明任意受检异常。Lambda 调用一个会抛受检异常的方法时，必须在主体内处理，或选择一个合同允许该异常的自定义函数式接口。把异常一律包成 `RuntimeException` 虽能编译，却可能丢失领域语义和恢复策略。

若读取外部模板是边界操作，可以在普通方法里捕获 `IOException`，转换成明确的 `TemplateLoadException`，再把该方法作为 Function 使用。若调用者确实应决定如何处理受检异常，可以定义 `ThrowingFunction<T,R,E extends Exception>`，但它会传播到所有组合与调用点。两种设计要按责任选，不要为追求一行 Lambda 隐藏失败。

异常测试应断言异常类型、稳定的错误码或关键上下文，不依赖整段 JDK 消息。方法引用和 Lambda 只是调用路径；真正的错误合同仍属于被引用的方法或行为接口。调试时先找到业务栈帧和最早异常，再判断适配层是否丢了原因。

## 12. 副作用不是禁词，但必须被放在边界并可观察

判断、映射最好只由参数决定结果，因为它们可能被多次调用、换序调用或在未来进入并行上下文。通知、数据库写入和日志天然有副作用，不能假装不存在。工程目标是让副作用显式集中：纯行为先产生通知命令，边界 Consumer 再执行；测试用记录器代替真实外部系统，精确断言次数和载荷。

一个典型故障是把 `notifications.add(order.id())` 写进 Predicate，之后调用方为了记录原因又测试一次，结果同一工单写入两次。函数签名仍是 `Predicate`，编译器无法指出语义错误。故障夹具通过对同一输入调用两次并检查列表大小，把“隐藏写入”转成确定证据。修复不是换成线程安全列表，而是移走写入。

另一个故障是捕获可变阈值容器，测试先调用一次、更新容器、再调用一次，同一工单结果改变。若这正是动态配置合同，应把配置提供者命名并记录版本；若期望快照，就在创建行为前提取不可变值。把时间、随机数也作为 Supplier 注入，可让规则在测试中确定，在生产中仍使用真实来源。

## 13. 调试顺序：先确定目标合同，再看简写语法

遇到“Lambda 不能编译”，按下面顺序缩小范围：

1. 找目标类型，写出它的唯一抽象方法完整签名。
2. 数参数，核对每个参数类型、返回类型和允许异常。
3. 检查接口是否真的只有一个抽象函数描述符，查看 `@FunctionalInterface` 的错误。
4. 检查被捕获局部变量是否发生过赋值，包括条件分支和自增。
5. 若是方法引用，改写成显式 Lambda，标出接收者与参数流；这样常能暴露顺序或重载问题。
6. 若编译通过但行为错，记录每次调用的输入、输出和次数，检查隐藏状态和副作用。

不要从“把箭头改成匿名类”开始碰运气。匿名类可能让错误信息变化，却不修复合同。也不要依赖 IDE 自动选择重载后就停止思考；把推断出的类型写进临时变量，是验证理解的快速办法。

编译错误本身是证据。本章实验保留两份不能进入正常编译集合的故障源码：修改捕获变量会出现 effectively-final 相关诊断，双抽象方法接口会出现 not-a-functional-interface 诊断。验证脚本单独调用 `javac`，要求失败并匹配稳定关键词；如果意外编译成功，脚本反而失败。

运行时错误则用独立进程验证。隐藏副作用夹具故意在重复调用后抛出带稳定证据码的异常，正常 oracle 不捕获并伪装成功。这样既证明故障确实可复现，也避免只展示“修好的代码”让学习者看不到诊断链。

## 14. 测试行为对象：用表格覆盖成功、边界、非法和等价实现

Predicate 至少测试阈值下方、等于阈值、上方与 null 策略；Function 测试代表值和边界值，并检查输入未被修改；Consumer 测试调用次数、顺序、载荷与异常；Supplier 测试“每次相同还是每次新建”的约定。不要只测一个快乐路径后说“Lambda 已掌握”。

方法引用等价性可以用同一输入表同时调用 Lambda 版和引用版，比较 expected、lambdaActual、referenceActual。等价只对当前合同成立：若一个版本捕获不同接收者或调用不同重载，语法相似也不等价。配套实验还检查六张工单的每个规则、三个阈值边界和通知列表，错误消息包含案例名称。

测试可变副作用时不要只看最终集合包含某项；还要检查恰好一次、总顺序和来源未改变。若系统允许重试，幂等性是更上层合同，应另设用例。这里的 T1 oracle 不连接外部通知服务，只用内存记录器证明调用行为。

## 15. FactoryCare 完整切片：规则、标签、通知各守一条边界

实验把 `WorkOrder` 设计成不可变 record。`Predicate<WorkOrder>` 只判断 priority 与 open 状态；`Function<WorkOrder,String>` 只生成 `P4:WO-101` 标签；`Consumer<WorkOrder>` 在明确边界把 `notify:WO-101` 写入测试记录器；`Supplier<String>` 提供固定追踪 ID。阈值在构造 Predicate 时作为有效 final 快照捕获。

首先手算输入：P4 开放工单通过，P3 开放工单在阈值为 3 时通过，P2 不通过，已关闭 P5 按组合规则不通过。再运行 oracle。随后把标签 Lambda 替换成 `WorkOrderRules::priorityLabel`，把通知 Lambda 替换成绑定实例方法引用，要求所有输出不变。最后运行三个故障：捕获后修改、双抽象方法、隐藏副作用。

这个切片刻意不调用 `stream()`。普通 `for` 循环足以证明行为被传入和调用，避免把 Lambda 与 Stream 绑成一个概念。下一章才讨论惰性管道、Collector 和 Optional。若学习者不能在普通方法中解释 Predicate 的调用时机，进入 Stream 后只会更难定位惰性与重复消费问题。

## 16. 与 TypeScript/Vue 的类比，以及类比失效处

TypeScript 中可以直接写函数类型 `(order: WorkOrder) => boolean`，Java 通常以命名或标准函数式接口承载同样形状。两者都能捕获词法作用域，也都可能把副作用藏进回调。Vue 的事件处理器、数组 `filter` 回调和 composable 返回的函数能帮助理解“行为被保存后再调用”。

类比会在类型与运行模型处失效。Java Lambda 必须适配目标函数式接口；TypeScript 主要按结构兼容，Java 接口是名义类型。Java 有基本类型特化、受检异常、重载方法引用和有效-final 局部捕获规则；JavaScript 闭包可直接重写外层 `let`。Vue 响应式引用故意让 `.value` 可变，不应拿来证明 Java 捕获对象“就是响应式”。

还有一个重要差异：浏览器回调常与事件循环、组件卸载和 DOM 生命周期绑定；本章 Java 行为对象没有自动调度语义。传入 Consumer 不等于异步，Lambda 本身也不创建线程。是否并发取决于调用者；看到箭头不能推断执行时机或线程。

## 17. 常见错误与可复用修复规则

- 错误：把 Lambda 当成无类型的独立函数。修复：先写目标接口的抽象方法签名。
- 错误：为了能用箭头，把两个业务动作硬塞进一个 SAM。修复：按单一责任拆合同，编排留给明确调用方。
- 错误：所有一行 Lambda 都替换成方法引用。修复：只有现有方法名更清楚且签名流可解释时替换。
- 错误：用数组或 AtomicInteger 绕过有效 final。修复：先问是否应返回累计结果，或把可变性放到有所有者的边界对象。
- 错误：在 Predicate/Function 内写通知或修改输入。修复：查询与命令分离，给 Consumer 的副作用做次数与载荷测试。
- 错误：Consumer 没返回值所以无需测试。修复：副作用越不可见，越要记录调用证据。
- 错误：编译器能推断就不写领域名字。修复：在复杂组合和重载边界引入有意义的局部变量。
- 错误：把 Lambda 当异步或更快。修复：执行策略由调用者决定，语法不提供性能保证。

## 18. 独立练习、预测与讲回

公开练习要求实现 `dispatchable(int threshold)`、`priorityLabel(WorkOrder)`、`notifier(List<String>)` 和方法引用等价检查。运行前写下四个预测：阈值等于 priority 是否通过；关闭工单是否通过；两次通知后列表内容；方法引用与 Lambda 对 null 的失败是否一致。starter 会因 TODO 合同失败，这是预期红灯。

完成后制造一个故障：在 Predicate 内向审计列表追加 ID，再让测试对同一输入调用两次。只凭最终布尔值看不出问题，要用调用次数证据定位。修复后用 60—120 秒讲回：函数式接口提供什么、目标类型决定什么、有效 final 禁止什么但没有禁止什么、方法引用怎样核对、为什么副作用要显式。

可以把下面五问作为复习：

1. 接口含一个抽象方法、两个 default 方法，能否用 Lambda？为什么？
2. `TypeName::instanceMethod` 的第一个 SAM 参数去了哪里？
3. 捕获 final `ArrayList` 后调用 `add` 为什么仍能编译？这是否安全？
4. `Predicate.and` 的右侧是否总执行？隐藏审计会造成什么后果？
5. 方法引用和显式 Lambda 都能编译时，如何证明行为等价而非只比较输出一次？

## 19. 本章边界与下一步

本章完成的是把单个行为变成有类型、可替换、可测试的值。它不证明所有行为都是纯函数，不负责数据管道、并行执行、响应式流、异步回调、重试事务或外部消息投递。普通方法、匿名类和策略对象仍然有位置；当状态、多个操作或生命周期是核心时，它们可能比 Lambda 更清楚。

下一章会把这些 Predicate、Function 和 Consumer 放入 Stream 管道，讨论中间操作何时真正执行、流为何只能消费一次、Collector 如何合并分区结果，以及 Optional 应只在哪些缺失值边界出现。进入前应能不依赖 Stream 独立写出并测试本章四类行为。

## 官方资料

- [JLS 25：Lambda Expressions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.27)
- [JLS 25：Method Reference Expressions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.13)
- [JLS 25：final Variables 与 effectively final](https://docs.oracle.com/javase/specs/jls/se25/html/jls-4.html#jls-4.12.4)
- [Java SE 25：java.util.function 包](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/function/package-summary.html)
- [Java SE 25：FunctionalInterface](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/FunctionalInterface.html)
