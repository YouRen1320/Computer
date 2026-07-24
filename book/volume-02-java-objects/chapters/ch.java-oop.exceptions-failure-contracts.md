---
schema_version: 2
edition: 2026.2-draft
id: ch.java-oop.exceptions-failure-contracts
title: 异常分类、传播、捕获、转换与失败契约
responsibility: 教授以异常表达不可正常返回的失败并保存因果链，不在本章绑定具体 IO 资源类型
volume: '02'
order: 12
level: L1
status: drafting
path: book/volume-02-java-objects/chapters/ch.java-oop.exceptions-failure-contracts.md
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
  text: 在 120 秒内解释异常分类、传播、捕获、转换与失败契约的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-exception-model
  - java-failure-contract
  covers_topics:
  - java.checked-unchecked-exception
  - java.throw-propagation
  - java.stack-trace
  - java.catch-boundary
  - java.exception-translation
  - java.cause-preservation
  uses_capabilities:
  - java.methods
  - java.inheritance-polymorphism
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为工单创建写出 checked/unchecked 选择、领域异常与边界异常转换，保留 cause 并控制捕获位置
  covers_topic_groups:
  - java-exception-model
  - java-failure-contract
  covers_topics:
  - java.checked-unchecked-exception
  - java.throw-propagation
  - java.stack-trace
  - java.catch-boundary
  - java.exception-translation
  - java.cause-preservation
  uses_capabilities:
  - java.methods
  - java.inheritance-polymorphism
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入 catch(Exception) 吞错、丢失 cause 和把可恢复输入错误包装成系统错误，读堆栈后最小修复
  covers_topic_groups:
  - java-exception-model
  - java-failure-contract
  covers_topics:
  - java.checked-unchecked-exception
  - java.throw-propagation
  - java.stack-trace
  - java.catch-boundary
  - java.exception-translation
  - java.cause-preservation
  uses_capabilities:
  - java.methods
  - java.inheritance-polymorphism
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 异常分类、传播、捕获、转换与失败契约

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《接口、抽象类、多态与动态分派》](ch.java-oop.interfaces-polymorphism.md)：独立完成异常模型、捕获与转换前，必须先具备「接口、抽象类、多态与动态分派」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文与验证工件可以用于学习和作者自检，但不代表学习者已经独立通过 G1，也不会自动修改 `PROGRESS.md`。

方法通常通过 return 交付结果，但有些执行无法产生承诺的正常结果：输入违反前置条件、目标工单冲突、下层存储不可用、程序访问了越界索引。Java 用异常把控制从失败点转移到能够处理该类型的 catch，沿途保留消息、堆栈、cause 和 suppressed 异常。异常不是“任何不满意结果”的同义词，而是一份方法如何失败的契约。

本章以 FactoryCare 工单创建为贯穿例子，学习 Throwable 层次、checked/unchecked 选择、throw/throws、传播、捕获边界、异常转换、因果链、恢复和 try-with-resources。示例资源只是最小 `AutoCloseable` 教学替身，不绑定文件、数据库连接或网络流等具体 I/O 类型。基线为 **Java 25 / JDK 25**，一手规范复核日期为 **2026-07-16**。

## 1. 本章完成证据

至少留下三类可重放证据：

1. **解释**：120 秒内画出 Throwable—Error/Exception—RuntimeException 层次，说明 checked 与 unchecked 的编译差别、传播如何寻找 handler，以及“能 catch”为什么不等于“应该 catch”。
2. **构建**：为工单创建声明一个调用者必须决定的 checked 失败、一个前置条件 unchecked 失败和一个边界转换异常；成功、已知失败、未知失败与资源关闭都有固定 oracle。
3. **诊断**：真实复现空 catch 吞错、转换丢 cause、把可恢复输入错误包装成系统错误与未处理 checked 异常的编译失败；从堆栈第一处可信应用帧做最小修复。

配套工件：

- [异常与失败契约观察台](../../../examples/encyclopedia/ch.java-oop.exceptions-failure-contracts/README.md)
- [工单创建异常边界实验](../../../labs/encyclopedia/ch.java-oop.exceptions-failure-contracts/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-oop.exceptions-failure-contracts/README.md)

## 2. 正常结果与异常结果

一个返回 `WorkOrder` 的方法，正常完成时必须真的有一个 WorkOrder。若失败时返回 null，调用者无法从类型看出 null 是“没找到”“输入非法”“下游超时”还是程序 bug。异常提供独立通道，并能携带类型与上下文，使调用者不必靠魔法值猜测。

但不是所有“没有值”都异常。查询一个可不存在的对象可以返回 Optional；校验器可以返回一组预期的字段错误；状态查询可以返回枚举。关键问题是：这种结果是不是方法契约中普通、可枚举的分支？若是，显式返回类型通常更清楚；若方法无法完成承诺且需要非本地退出，异常合适。

## 3. 异常是一种突然完成

执行 throw 后，当前表达式、语句和方法不会正常完成。JVM 沿调用栈向上寻找第一个能处理该异常类型的 catch；途中未完成方法的后续语句不会执行。若始终没有 handler，当前线程交给未捕获异常处理机制，通常打印堆栈并终止。

这种非本地控制流很强，也容易隐藏路径。阅读带异常的方法时，不仅看显式 throw，还要看被调用方法的 throws、运行时前置条件和资源关闭。测试成功路径不足以说明失败后的状态、日志和资源是否正确。

## 4. Throwable 层次

只有 Throwable 或其子类实例可以被 throw 和 catch。Throwable 的两个直接分支是 Error 与 Exception。Exception 表示普通程序可能考虑处理的异常；RuntimeException 是 Exception 的子类。Error 通常表示 JVM、链接或严重资源问题，普通业务代码一般不尝试恢复。

层次是多态：`catch (Exception e)` 能接住其下的 checked Exception 和 RuntimeException，却接不住 Error；`catch (Throwable t)` 连 Error 也接住，通常过宽。类型系统允许的操作不等于合理边界。

## 5. Error 通常不属于业务恢复

OutOfMemoryError、LinkageError 等问题往往意味着运行环境或程序完整性已受损。业务代码不应 catch Error 后返回“创建成功”或继续执行未知状态。顶层框架可能为了记录和有序退出观察 Throwable，但那不是普通领域恢复。

不要把自定义业务失败继承 Error，也不要为了绕过 checked 检查选择 Error。业务异常应继承 Exception 或 RuntimeException，选择依据是公开契约和调用者义务。

## 6. checked 与 unchecked 的精确定义

RuntimeException 及其子类、Error 及其子类属于 unchecked；其他 Throwable 子类属于 checked。一个方法可能抛出的 checked 异常，必须在当前方法捕获，或在 `throws` 子句中声明继续传播，否则编译失败。unchecked 异常不受这项编译检查。

checked/unchecked 描述的是编译器义务，不自动等同“可恢复/不可恢复”“用户错误/程序错误”或“严重/轻微”。RuntimeException 也可能被边界稳定映射，checked 异常也可能最终只能终止当前操作。设计应从调用者能做什么开始，而不是背口号。

## 7. 何时考虑 checked 异常

若调用者在每次调用处都必须明确选择替代动作，而且这是该方法特有、稳定且可合理处理的失败，checked 可以把义务写入签名。例如教学示例中的 `DuplicateWorkOrderException` 要求创建用例明确映射为冲突结果，而不能假装成功。

成本是签名传播、lambda/函数式接口适配和 API 演进压力。若绝大多数调用者只能原样向上抛，checked 可能制造样板而没有增加决策信息。主流项目会结合层次边界形成一致政策，而不是每个类独立偏好。

## 8. 何时考虑 unchecked 异常

前置条件违反、不可满足的不变量和程序使用错误常用 IllegalArgumentException、IllegalStateException 或自定义 RuntimeException。调用者不被迫在每一层写无意义 catch，但边界仍可统一转换为安全响应。

“unchecked 不用声明”不等于“不用文档和测试”。公开方法应说明重要失败类型、触发条件和原子性。大量含义模糊的 RuntimeException 会让调用者只能 catch Exception 猜测，等于放弃失败契约。

## 9. 本章的选择示例

FactoryCare 工单创建采用三类失败：空标题属于调用前置条件，抛 `InvalidWorkOrderRequestException extends RuntimeException`；重复工单是用例要求调用者明确处理的已知冲突，抛 checked `DuplicateWorkOrderException`；底层端口出现未知技术故障时，应用边界转换为 unchecked `WorkOrderCreationException` 并保留 cause。

这是一套可解释的教学政策，不是所有系统唯一答案。团队也可把冲突建模为结果类型，或统一领域异常为 unchecked。重要的是同层一致、调用者动作明确、因果证据不丢失。

## 10. `throw` 与 `throws`

`throw` 是语句，后面跟一个 Throwable 实例，表示此刻失败；`throws` 写在方法签名，声明方法可能传播哪些 checked 异常。一个方法声明 throws 不代表每次调用都会失败，也不会自动创建异常。

~~~java
WorkOrder create(Request request) throws DuplicateWorkOrderException {
    if (request.title().isBlank()) {
        throw new InvalidWorkOrderRequestException("title must have text");
    }
    return gateway.insert(request);
}
~~~

unchecked 异常可以写进 throws 用作文档，但编译器不要求调用者处理。签名应避免罗列所有可能的 NullPointerException 等实现细节，只声明对调用者有稳定意义的契约。

## 11. 创建异常对象

异常通常在发现失败的地方新建，使堆栈从真实失败点开始。消息应包含操作和安全上下文，例如 `work order already exists: key=REQ-7`，而不是只有 `error`。异常字段可保存机器可读错误码或安全标识，避免上层解析自然语言消息。

不要复用同一个异常实例跨多次失败；它携带创建时的堆栈，复用会误导定位。也不要把完整请求、令牌或个人信息放入消息，异常常会进入日志和监控。

## 12. 传播与调用栈

假设 controller 调 application service，service 调 gateway，gateway 的适配器失败。若中间层都不捕获，异常按相反方向传播。每退出一层，正常返回路径被跳过，直到某个 catch 类型匹配。传播不是复制异常；通常是同一个对象沿栈移动。

允许传播是一项设计选择。若当前层既不能恢复、不能增加有意义抽象、也不是日志边界，什么都不 catch 往往比 catch 后原样抛更好。无意义的 `catch (e) { throw e; }` 只增加噪音。

## 13. handler 如何匹配

catch 按源码顺序检查，选择第一个其参数类型能接纳该异常对象的分支。子类 catch 必须写在父类之前；先写 `catch (Exception)` 会让后面的具体 Exception 分支不可达并编译失败。

多 catch `catch (A | B e)` 适合两个无继承关系的异常采取完全相同动作。不要为了少几行把需要不同恢复或映射的失败合并。捕获类型本身就是政策说明。

## 14. 最小捕获范围

try 块应尽量只包围可能产生目标失败的操作。若把解析、授权、存储和输出全部放进一个大 try，再 catch IllegalArgumentException，就无法知道失败来自用户输入还是内部代码错误。范围越大，越容易误分类。

缩小 try 后，catch 能针对一个明确操作：解析失败映射字段错误，插入冲突映射已存在，未知端口错误转换系统失败。可读性和诊断精度同时提高。

## 15. catch 边界的三个条件

一个合理捕获位置通常至少能做一件事：真正恢复并继续；把底层异常转换成当前抽象的失败；或在最外层终止当前请求并输出安全响应。若什么都做不了，就继续传播。

“这里方便打印日志”不是充分理由。每层都记录同一堆栈会制造重复告警。通常在拥有请求关联 ID、用户可见映射和最终处理决定的边界记录一次，内层通过类型、消息和 cause 提供信息。

## 16. 恢复的含义

恢复不是 catch 后程序还在运行，而是失败被转换成契约允许的明确结果，系统状态仍满足不变量。例如发现重复工单后返回稳定冲突响应；可选缓存失效后读取权威来源；用户输入错误后提示修正且没有写入半成品。

若 catch 后返回伪造对象、空字符串或 null，只是掩盖失败。调用者会继续在错误前提上运行，真正异常出现在更远位置，因果链更难追踪。

## 17. 重试不是默认恢复

暂时性失败可能适合重试，但必须知道操作是否幂等、失败发生在提交前还是提交后、上限和退避政策。创建工单在超时后可能已经成功；盲目重试会重复创建。异常类型若不能区分“肯定未执行”与“结果未知”，调用者就没有足够依据安全重试。

本章不实现重试框架，只要求别在 catch 中立即无限循环。后续可靠性章节会结合幂等键、超时和观测设计恢复。

## 18. 异常转换的目的

下层异常名称常暴露实现细节。应用用例若直接声明某个驱动异常，调用者会与当前适配器绑定。转换把失败提升到当前抽象：`GatewayAccessException` 转为 `WorkOrderCreationException`，消息描述“创建工单失败”，cause 保存原始技术证据。

转换不是把所有异常改成一个 `BusinessException`。已知冲突、无效输入和未知系统失败需要不同动作，就应保持可区分类型或错误码。抽象应减少无关细节，不应抹平决策信息。

## 19. 保留 cause

正确转换通常使用 `new HigherLevelException(message, cause)`。`getCause()` 让上层或日志看到原始类型与堆栈。若只复制 `cause.getMessage()`，原始类型、位置和更深原因都会丢失，而且消息可能为空或含敏感信息。

cause 是纵向因果链：当前异常因谁而起。它不同于 suppressed 异常，后者表示在传播主失败时还有其他异常被压制，例如资源关闭失败。诊断时两者都要查看。

## 20. 不要重复包装同一抽象

若当前异常已经是 `WorkOrderCreationException`，每经过一层又包成同类型，会形成没有新信息的洋葱链。转换只发生在跨抽象边界时，消息应增加当前操作和安全上下文。单纯“重新抛出”保持原对象即可。

也不要把可预期的 InvalidWorkOrderRequestException 包装成系统错误。这样用户可修复的输入会变成 500 类故障，监控被污染，调用者失去正确动作。

## 21. 读堆栈：先看什么

典型堆栈顶部是异常类型与消息，随后第一帧是创建/抛出位置，再沿调用方向列出栈帧。转换后会出现 `Caused by:` 段。定位时先确认最外层失败契约，再沿 cause 找最深根因，寻找第一条属于自己代码且与输入/状态相关的可信帧。

“最底部就是根因”只是线索，不是机械规则。根因类型可能是通用异常，真正错误是更上层传入非法参数；也可能多层 cause 中每层都增加关键语义。把输入、操作、线程和关联 ID 与堆栈一起分析。

## 22. 第一处可信证据

可信证据是可重放、与契约直接相关的 expected/actual 或编译诊断。例如 `expected cause=GatewayAccessException, actual cause=null` 比“程序挂了”更有用；`expected INVALID_INPUT, actual SYSTEM_ERROR` 直接揭示错误分类。

修复从最早偏差开始，避免追随后续 NullPointerException。若空 catch 先吞掉异常，之后的 null 解引用只是二次症状。保留故障用例能防止未来再次吞错。

## 23. 空 catch 是信息黑洞

~~~java
try {
    gateway.insert(request);
} catch (Exception ignored) {
}
return null;
~~~

这里同时丢失类型、消息、堆栈和操作结果，并用 null 制造新的模糊失败。变量命名为 ignored 并不会让忽略合理。只有真正可选且已有明确替代语义的操作，才可能有意忽略某个非常具体的异常，而且仍应有测试或度量说明。

## 24. `catch (Exception)` 的风险

宽捕获可能把程序 bug、前置条件错误和预期领域失败都误当成同一种情况。尤其在大 try 块中，它会吞掉 NullPointerException、ClassCastException 等本应暴露的问题。边界层可以最后捕获 Exception 以生成安全的未知错误响应，但必须在具体分支之后、记录 cause，并终止当前操作。

内层优先捕获能采取明确动作的具体类型。不要 catch Throwable；不要把 Error 伪装成普通业务响应。

## 25. checked 异常编译失败是证据

调用声明 checked 异常的方法而既不 catch 也不 throws，javac 会拒绝编译。这种编译故障体现了签名强制调用者做决定。教学工件应保存一个 `.java.txt` 失败源并由验证器复制编译，检查稳定的诊断键，而不是提交无法编译的正常源码。

修复选择有两种：当前层能够处理就 catch；当前层不能处理就把 throws 加到自己的契约。为了让编译变绿而 catch 后忽略，形式上满足编译器，语义上仍失败。

## 26. unchecked 仍会传播

unchecked 只是不强制声明，并不意味着 JVM 自动处理。若没有匹配 handler，它同样展开调用栈并可能终止线程。对用户输入的 unchecked 异常，应用边界应有稳定映射；对未知 bug，边界可返回通用错误并保留内部诊断。

不要在每个方法签名列出所有 unchecked 异常，也不要假设调用者能从实现猜到关键失败。稳定且对决策重要的失败仍需文档和测试。

## 27. 异常与方法原子性

方法抛异常时，之前已经发生的外部副作用不会自动回滚。列表可能已修改，文件可能已写一半，远端请求可能已发送。异常机制只转移控制，不提供事务。方法契约应说明失败前后哪些状态可能改变。

先验证后修改、先构建临时结果再一次替换、使用事务或补偿机制，都是后续的原子性策略。本章的纯内存示例在验证通过后才调用 gateway，避免明显半成品。

## 28. `finally` 的保证与边界

finally 在 try 正常、return 或抛异常时通常都会执行，适合释放无法用更好机制管理的资源或恢复临时全局状态。它不应该返回值或抛出无关异常覆盖主失败。`return` 写在 finally 会吞掉 try 中的 return 或异常，是危险反例。

进程被强制终止等情形不能依赖 finally。清理重要外部状态需要更高层可靠性设计，不能把 finally 当成绝对承诺。

## 29. try-with-resources

实现 AutoCloseable 的资源可放在 try 括号中，离开块时自动 close。多个资源按初始化相反顺序关闭；已成功初始化的资源即使后续初始化或主体失败也会尝试关闭。这比手写嵌套 finally 更不易遗漏。

本章用 `TraceScope` 教学替身观察 open/use/close 顺序，不绑定文件或连接。核心契约适用于各种资源，具体 I/O 语义留到后续章节。

## 30. suppressed 异常

若 try 主体先抛异常，close 又抛异常，try-with-resources 保留主体异常为主失败，并把关闭异常加入 `getSuppressed()`。若只打印 message 而不看 suppressed，会错过清理故障；若手写 finally 直接抛 close 异常，甚至可能覆盖原始失败。

测试可构造一个主体失败和关闭失败同时发生的 AutoCloseable，断言主异常类型不变、suppressed 数量为 1。不要为了简化输出吞掉关闭失败。

## 31. 资源关闭顺序

`try (A a = ...; B b = ...)` 先创建 A 再创建 B，关闭时先 B 后 A。这符合依赖栈：后创建资源可能依赖先创建资源。顺序应通过固定事件列表验证，而不是凭肉眼相信语法。

若资源构造 B 失败，A 仍会关闭，B 因未成功创建不会关闭。资源初始化本身也在失败契约内。

## 32. 捕获与资源生命周期

扩展 try-with-resources 的 catch 在资源关闭之后接管，因此进入 catch 时资源已尝试关闭。若 catch 要读取资源状态，必须依赖安全摘要，不能继续使用已关闭资源。finally 执行时同样已完成资源关闭尝试。

把资源变量泄露到块外、关闭后继续使用，会形成生命周期错误。类型系统不会对所有 AutoCloseable 用法阻止这种行为，需由封装和测试保证。

## 33. 领域异常应携带什么

领域异常应携带调用者决策需要的最小信息，例如稳定 code、可安全显示的工单键和原因类型。自然语言消息适合人读，不应成为上层分支条件。若上层通过 `message.contains("duplicate")` 判断冲突，文案修改就会破坏协议。

异常类不应保存整个可变实体或敏感请求。必要字段设为 final，通过只读访问器暴露。异常自身也应保持简单，避免构造异常时再抛新异常。

## 34. 自定义异常构造器

用于转换的异常至少提供 `(String message, Throwable cause)`；领域已知失败可提供稳定字段构造器。没有 cause 构造器会诱导开发者丢链。若异常不允许 cause，应是经过明确设计的叶子失败，而不是忘记实现。

不要覆盖 `fillInStackTrace` 只为“性能优化”，除非有测量和完整观测替代；这会删除重要定位证据。基础学习阶段保留标准行为。

## 35. 异常消息不是用户文案

内部异常消息面向开发诊断，用户界面需要本地化、安全且稳定的响应。边界把异常类型/code 映射为用户消息，不直接回传堆栈、类名、SQL、路径或 secret。日志可记录更多，但仍需脱敏。

同一 DuplicateWorkOrderException 可在 HTTP 映射为冲突、CLI 映射为一行提示、批处理映射为拒绝记录。领域异常不依赖具体传输层。

## 36. 日志只记录一次

若 gateway、service、controller 都以 error 记录同一异常，会得到三条堆栈和三个告警。通常由最终决定请求结果且拥有关联上下文的边界记录一次；内层只在真正恢复、降级或添加独立事件时记录。

日志字段应包括安全操作名、关联 ID、异常类型和结果，避免拼接完整输入。测试不必绑定日志框架，但应验证转换后 cause 可供边界记录。

## 37. 输入错误不能伪装成系统错误

用户能修正的标题为空、格式非法等错误，应稳定映射为 INVALID_INPUT，不应被 `catch (Exception)` 包成 WorkOrderCreationException。否则客户端会重试无效请求，监控误报服务故障，用户看不到可行动信息。

先在 try 外做前置校验，或在 catch 中先重新抛具体输入异常，再处理未知异常。最小 try 范围通常更清楚。

## 38. 未知异常仍要保留根因

未知不等于忽略。应用层可将端口异常转换为当前抽象的系统失败，边界返回通用安全响应，同时日志通过 cause 保留底层证据。调用者不需要依赖适配器类名，但运维仍能追踪。

若根因是 RuntimeException bug，是否转换取决于边界。领域内部不应把所有 RuntimeException 包装；最外层可统一响应，但必须区分内部记录与外部显示。

## 39. “先 log 再 throw”反例

每层 `log.error(e); throw e;` 不改变控制流，只重复记录。若必须添加当前层上下文，优先通过结构化异常字段或转换消息，并让最终边界记录。若本层启动了异步任务或跨越无法保留上下文的边界，记录政策另行设计。

不要为了消除重复日志而完全不记录未捕获失败。目标是一个拥有足够上下文的权威记录，而不是零条或多条相同记录。

## 40. 返回 null 反例

catch 后返回 null 把明确失败改成模糊值。下一层可能在完全无关的代码行抛 NullPointerException，堆栈不再指向原始 gateway 故障。若“未找到”是正常分支，用 Optional；若创建失败，传播或转换异常；若降级返回缓存结果，类型和日志都要说明来源。

验证器应要求故障进程非零退出或得到显式失败结果，不能把没有崩溃当成成功。

## 41. 过度捕获 NullPointerException

通过 catch NullPointerException 判断字段缺失，会把方法内部其他 bug 一并当成用户错误。应在边界显式校验 null 并抛有字段语义的异常。NPE 的精确消息有助诊断，但不应作为正常分支控制。

同理，catch ClassCastException、IndexOutOfBoundsException 后继续，通常掩盖程序不变量破坏。修复数据与索引逻辑，而不是把 bug 包装成“暂无数据”。

## 42. 中断异常的特殊提醒

若未来遇到 InterruptedException，catch 后既不传播也不恢复中断标记，会让上层取消机制失效。当前线程不能完成恢复时，通常重新 `Thread.currentThread().interrupt()` 后退出当前操作，或按签名继续抛。具体并发政策在后续章节展开。

这个例子说明：恢复动作取决于异常语义，不能用统一 catch 模板处理所有类型。

## 43. 异常与继承/接口契约

重写方法不能新增比父方法声明更宽的 checked 异常，否则调用者通过父类型引用时无法履行原契约。可以声明更窄的 checked 子类，或不抛 checked。unchecked 不受同样签名限制，但仍应保持行为替换原则。

接口方法的 throws 是实现者和调用者的共同边界。不要让适配器实现把具体驱动 checked 异常泄漏到一个原本抽象的接口；在实现内部转换为接口声明的异常。

## 44. 异常层次不要过深

为每个字符串创建一个异常类会增加认知成本；所有失败共用一个无 code 异常又无法分类。合理层次通常围绕调用者动作：无效请求、冲突、暂时不可用、未知系统失败，并在类或字段中保留细节。

先写失败矩阵，再决定类型。若两种失败在所有边界都采取相同动作且无需独立统计，可能不需要两个类；若动作不同，仅靠不同消息不足以稳定区分。

## 45. FactoryCare 创建流程

创建服务先验证标题和请求键，再调用 WorkOrderGateway。gateway 返回成功则生成工单；检测重复则抛 DuplicateWorkOrderException；端口不可用则抛 GatewayAccessException。应用服务让重复冲突按 checked 契约传播，把未知端口失败转换为 WorkOrderCreationException(cause)。

边界层映射：成功为 CREATED；InvalidWorkOrderRequestException 为 INVALID_INPUT；DuplicateWorkOrderException 为 CONFLICT；WorkOrderCreationException 为 SYSTEM_ERROR，并记录内部 cause。没有分支返回 null，没有空 catch。

## 46. 为什么冲突选择 checked

本实验故意让调用者必须写出冲突决策，便于观察 javac 编译检查。它不宣称所有重复键都应 checked。若项目约定领域预期失败使用 sealed result，或统一 unchecked + 全局映射，也可以成立。

学习者必须能说出选择的成本：checked 强化显式处理但传播样板更多；unchecked 签名简洁但依赖文档、测试和边界纪律。最佳选择来自一致契约，不来自个人对关键字的喜好。

## 47. 成功路径不能受失败代码影响

过宽 try/catch 可能在成功后格式化响应时捕获 bug 并误报 gateway 失败。验证器应单独断言成功只调用一次 gateway、输出稳定且资源关闭。失败映射代码不能改变正常返回值。

性能也要注意：异常用于异常路径，不用 throw/catch 实现普通循环分支。构造堆栈有成本，但在没有测量前不要牺牲诊断证据做微优化。

## 48. 故障一：空 catch 吞错

构造一个 gateway 总是抛 `GatewayAccessException`，错误服务 catch Exception 后返回 null。oracle 要求打印 `SWALLOWED_FAILURE result=null causeLost=true` 并非零退出。第一处偏差是服务没有传播/转换，不是后续调用者 NPE。

最小修复为删除无能力处理的 catch，或转换为 WorkOrderCreationException 并传 cause。复跑还要确认成功路径不变。

## 49. 故障二：转换丢 cause

错误代码 `throw new WorkOrderCreationException("create failed")` 没传原异常。测试直接断言 `getCause()`，得到 null 就失败。只让消息包含底层文字不能修复，因为类型和堆栈仍丢失。

修复构造器与调用点后，断言最外层类型、cause 类型、消息安全性和最深根因。不要只看控制台有 `Caused by`，直接对象断言更稳定。

## 50. 故障三：错误分类

一个大 catch 把 InvalidWorkOrderRequestException 包装成 WorkOrderCreationException，边界输出 SYSTEM_ERROR。oracle 比较期望 INVALID_INPUT 与实际 SYSTEM_ERROR。修复可把校验移出 try，或增加具体 catch 重新传播。

测试同时验证 gateway 没被调用，证明无效输入没有产生副作用。仅修改响应标签而仍调用存储，不是完整修复。

## 51. 故障四：未处理 checked

失败源直接调用声明 `throws DuplicateWorkOrderException` 的 create，却没有 catch/throws。javac 应给出“必须捕获或声明”的编译诊断。公开正常源码保持可编译，失败源以 `.java.txt` 保存并由脚本临时复制。

学习者分别写出两个修复版本：边界 catch 并映射冲突；中间层增加 throws 继续传播。解释哪个层拥有处理信息。

## 52. 故障五：关闭异常覆盖主失败

手写 finally 中直接 close，close 抛异常时可能覆盖主体失败。try-with-resources 会把关闭失败放入 suppressed。oracle 同时断言主消息 `operation failed` 与 suppressed 消息 `close failed`，确保两份证据都在。

不要 catch 关闭异常后什么都不做；也不要反过来让关闭故障成为唯一可见异常。主次关系由资源语义和语言规则决定。

## 53. 预测练习

运行前预测：RuntimeException 是否要求 throws；子类异常与父类 catch 的匹配顺序；throw 后同方法下一行是否执行；主体和 close 同时失败时哪个是 cause、哪个是 suppressed；转换时只复制 message 会丢什么。

写下答案再运行工件，把错误预测改写成一条可复用规则。不要用“Java 就这样”代替原因。

## 54. 独立构建任务

从空文件实现 WorkOrderCreator 与边界映射。要求：空标题 unchecked；重复请求 checked；未知 gateway 失败转换并保留 cause；成功固定输出；具体 catch 在宽 catch 之前；没有 null 失败值和空 catch。再用最小 AutoCloseable 验证关闭顺序与 suppressed。

完成后把一个规则改为“重复冲突返回显式结果而不是 checked 异常”，列出签名、调用者和测试如何变化；无需实现整个替代方案，但必须理解迁移成本。

## 55. 故障报告模板

每次记录：命令与 JDK；输入/故障注入；expected；actual；退出码；第一条可信异常/编译诊断；cause/suppressed；根因；最小修复；复跑结果。堆栈可截取必要帧，不复制含机器隐私的完整路径到公开材料。

把“已验证”与“推测”分开。看到异常名只能形成假设，能用固定测试重放才是证据。

## 56. 120 秒复述提纲

不看正文回答：checked 与 unchecked 的精确定义是什么？throw 和 throws 有何区别？异常如何沿栈传播并选择 catch？什么层才该捕获？转换为何要保留 cause？suppressed 从哪里来？为什么空 catch、返回 null 和 catch(Throwable) 危险？

最后用工单创建说出三个失败类型和各自调用者动作。若只能背类名却说不出动作，契约仍未建立。

## 57. 验收清单

- 成功路径输出稳定，失败代码不影响正常结果。
- checked 冲突由调用者捕获或声明；unchecked 输入错误有稳定边界映射。
- 未知端口失败转换到应用抽象并保留原始 cause。
- 具体 catch 先于宽 catch，try 范围只包含目标操作。
- 没有空 catch、null 失败值、重复日志或 Throwable 业务恢复。
- try-with-resources 的关闭顺序和 suppressed 由断言证明。
- 四类工件均在 Java 25 下确定性运行，失败必须真实非零或编译失败。

## 58. 有意不做

本章不绑定文件、Socket、数据库连接等具体 I/O 资源，不设计 HTTP 全局异常处理器、重试框架、事务、可观测平台、并发取消或跨服务错误协议。不修改 FactoryCare API 合同，也不把异常层次扩展成完整企业基类库。

这些内容需要结合后续 I/O、Spring、数据、并发与生产化章节。本章只建立语言级失败模型和清晰边界。

## 59. 一手资料与继续阅读

- [JLS 25 第 11 章：Exceptions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-11.html)：异常种类、checked 检查与运行时处理。
- [JLS 25 §14.20：try 与 try-with-resources](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html#jls-14.20)：catch、finally、关闭顺序与 suppressed 规则。
- [Throwable，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Throwable.html)：cause、堆栈和 suppressed API。
- [AutoCloseable，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/AutoCloseable.html)：资源关闭契约。
