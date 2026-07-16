---
schema_version: 2
edition: 2026.2-draft
id: ch.java-oop.interfaces-polymorphism
title: 接口、抽象类、多态与动态分派
responsibility: 教授面向契约编程和运行时动态分派，不在本章展开反射代理或泛型变型
volume: '02'
order: 8
level: L1
status: drafting
path: book/volume-02-java-objects/chapters/ch.java-oop.interfaces-polymorphism.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.inheritance-composition
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
  text: 在 120 秒内解释接口、抽象类、多态与动态分派的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-abstraction
  - java-polymorphism
  covers_topics:
  - java.interface
  - java.abstract-class
  - java.contract-implementation
  - java.upcast
  - java.dynamic-dispatch
  - java.substitution
  uses_capabilities:
  - java.encapsulation-immutability
  - java.references-objects
  - java.methods
  - java.inheritance-polymorphism
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 对比继承与组合后定义 NotificationSender 接口、两个实现和只依赖接口的服务，用运行时注入证明多态与动态分派
  covers_topic_groups:
  - java-abstraction
  - java-polymorphism
  covers_topics:
  - java.interface
  - java.abstract-class
  - java.contract-implementation
  - java.upcast
  - java.dynamic-dispatch
  - java.substitution
  uses_capabilities:
  - java.encapsulation-immutability
  - java.references-objects
  - java.methods
  - java.inheritance-polymorphism
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入违反父契约的子类、向具体实现强转和分支判断类型，在新增第三实现时暴露后改为组合/多态调用
  covers_topic_groups:
  - java-abstraction
  - java-polymorphism
  covers_topics:
  - java.interface
  - java.abstract-class
  - java.contract-implementation
  - java.upcast
  - java.dynamic-dispatch
  - java.substitution
  uses_capabilities:
  - java.encapsulation-immutability
  - java.references-objects
  - java.methods
  - java.inheritance-polymorphism
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 接口、抽象类、多态与动态分派

> 本章状态为 **drafting**。正文和工件提供学习与作者验证环境，不代表学习者已经完成无 AI 构建、诊断、G1 门禁或复述，也不会自动修改 `PROGRESS.md`。

上一章用普通父类让短信和邮件共享实现，又让通知服务组合格式器。这已经能工作，但调用端仍依赖一个带具体实现和状态可能性的类。如果调用端真正需要的只有“给定工单通知请求，返回一个可观察结果”，更准确的边界是把这项能力声明为接口。短信、邮件和控制台记录器可以彼此毫无类继承关系，只要显式实现同一契约，通知服务就能通过同一种调用方式使用它们。

**多态**不是“同一个变量随便装任何东西”，而是一个父类型引用可以指向多个符合契约的实际对象；调用点先由编译器依据静态类型检查，运行时再为被重写的实例方法定位实际实现。这个分成编译期与运行期的过程，是理解“为什么打印 Email 而不是 NotificationSender”“为什么强转能编译却在运行时崩溃”的核心。

本章以 FactoryCare 的 `NotificationSender` 为主线，对比接口与抽象类，建立向上转型、替换和动态分派模型。示例基线为 **Java 25 / JDK 25**，不使用 preview 特性；反射、动态代理、泛型变型与框架自动注入留给后续章节。一手资料复核日期为 **2026-07-16**。

## 1. 本章完成证据

至少留下三类证据：

1. **解释**：120 秒内区分接口与抽象类，说清引用静态类型、对象运行时类型、向上转型和动态分派，并举出错误向下转型失败。
2. **构建**：定义 `NotificationSender`，实现短信、邮件和内存记录三个实现；`WorkOrderNotificationService` 只保存接口字段，创建时传入不同实现，服务源码不改而输出改变。
3. **诊断**：复现缺少接口方法的编译错误、向错误具体类强转的 `ClassCastException`、按 `instanceof` 分支遗漏第三实现，以及某个实现违反共同契约；根据第一条可信证据修复并复跑。

配套工件：

- [接口与动态分派观察台](../../../examples/encyclopedia/ch.java-oop.interfaces-polymorphism/README.md)
- [FactoryCare 三渠道替换实验](../../../labs/encyclopedia/ch.java-oop.interfaces-polymorphism/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-oop.interfaces-polymorphism/README.md)

私有答案只用于独立尝试后的校准。验证器里的非零退出码必须来自真实编译或运行失败，不能通过删除故障、吞异常或伪造输出绕过。

## 2. 前置知识补救

开始前应能：

- 写父类与子类，使用 `@Override` 和 `super`；
- 说明 is-a 与 has-a，不把复用几行代码当继承理由；
- 用父类型引用接收子类对象，并知道这不会复制对象；
- 用构造器和 private final 字段组合协作者；
- 用固定输入发现子类加强前置条件的替换故障。

如果“父类型变量”和“父对象”仍混淆，先画两层图：左边是带静态类型的变量槽位，右边是唯一实际对象。改变变量声明不会改变对象的运行时类；多个变量也可指向同一个对象。本章的所有分派和强转都建立在这个引用模型上。

## 3. 接口是能力契约，不是半成品对象

最小接口：

~~~java
interface NotificationSender {
    String send(String workOrderId, String message);
}
~~~

它声明调用者可以要求什么：提供两个字符串，得到一个字符串结果。接口本身不能用 `new NotificationSender()` 直接实例化，也没有每个实例一份的字段或构造器。实现类显式写 `implements`：

~~~java
final class SmsSender implements NotificationSender {
    @Override
    public String send(String workOrderId, String message) {
        return "SMS|" + workOrderId + "|" + message;
    }
}
~~~

接口中这个方法隐含 `public abstract`；实现时必须是 public，不能降为包访问。推荐仍写 `@Override`，让编译器校验方法名、参数和返回类型。

## 4. 契约不只是一行方法签名

签名只能表达名称、参数类型、返回类型和部分异常边界，不能自动保证业务语义。`NotificationSender` 还需要人和测试共同维护的规则，例如：

- `workOrderId` 与 `message` 非 null 且非空白；
- 合法输入成功时返回非空渠道结果；
- 结果必须保留工单编号，便于审计关联；
- 不得把真实手机号、密钥或完整敏感正文写入日志；
- 非法输入以同类失败表达，不由某个实现悄悄接受 null；
- 调用失败是否产生副作用必须说明。

一个类能通过编译只证明它提供了形状兼容的方法，不证明它遵守这些规则。每个实现都要运行共同契约测试。

## 5. 接口中可以有什么

Java 25 的普通接口可声明：

- 抽象实例方法；
- 带方法体的 `default` 实例方法；
- `static` 方法；
- 为复用接口内部实现而用的 `private` 方法；
- 字段，但接口字段隐含 `public static final`，是类级常量变量候选，不是实例状态；
- 嵌套类型。

因此“接口里所有方法都抽象”是过时口号，“接口可以保存对象实例字段”则是错误。L1 设计优先保持接口窄而清楚，不要因为语法允许就把工具方法、常量和默认实现全部塞进去。

## 6. 接口字段为何要谨慎

~~~java
interface NotificationSender {
    int MAX_ATTEMPTS = 3; // 隐含 public static final
}
~~~

它属于接口类型，不属于每个 sender 对象。若暴露可变数组，final 仍只固定引用，所有实现和调用者会共享可变对象；若公开编译期常量，调用方还可能内联旧值。重试次数通常是部署配置或策略，不应只因“所有实现都用”就放进接口常量。

接口最重要的资产是小而稳定的行为契约，而不是全局常量仓库。

## 7. 一个类可实现多个接口

Java 类只能直接扩展一个类，但可以实现多个接口：

~~~java
final class SmsSender
        extends AuditedSender
        implements NotificationSender, HealthCheckable {
    // ...
}
~~~

这允许一个对象显式支持多项能力，而不需要多重类继承。接口之间也可以 `extends` 多个父接口。能力拆分应来自调用者真实需求；不要把一个大接口机械拆成几十个单方法接口，只为追求数量。

若两个接口声明兼容的同签名抽象方法，实现一个方法可能同时满足它们；若默认方法冲突，则需要按语言规则显式解决，不能期待随机选择。

## 8. 抽象类是什么

抽象类用 `abstract class` 声明，不能直接实例化，但可以拥有：

- 实例字段与类字段；
- 构造器；
- 普通具体方法；
- 抽象方法；
- private、protected、public 等成员；
- 对共享状态和模板流程的封装。

~~~java
abstract class AuditedSender implements NotificationSender {
    private final String channel;

    AuditedSender(String channel) {
        this.channel = channel;
    }

    protected final String auditPrefix(String workOrderId) {
        return channel + "|AUDIT|" + workOrderId;
    }
}
~~~

具体子类必须实现仍未实现的抽象方法，除非它自己也保持 abstract。抽象类有构造器，是为了初始化子类对象中的父类部分，不代表可以 `new AuditedSender()`。

## 9. 接口与抽象类如何选

| 维度 | 接口 | 抽象类 |
| --- | --- | --- |
| 主要目的 | 声明能力与调用契约 | 共享类层次状态、构造和模板实现 |
| 实例字段 | 没有接口实例字段 | 可以有封装实例状态 |
| 构造器 | 没有 | 可以有，供子类构造链调用 |
| 实现数量 | 一个类可实现多个接口 | 一个类只能直接扩展一个类 |
| 无关类共享 | 很合适 | 会强迫进入同一类层次 |
| 默认实现 | 可有 default，但应谨慎 | 可有任意可见具体方法 |
| 状态不变量 | 由实现各自维护 | 父类可集中维护共享状态 |
| 演进风险 | 增加抽象方法会影响实现 | 修改父状态/模板可能影响子类 |

二者可以配合：外部调用端依赖 `NotificationSender` 接口，短信和邮件实现可直接实现，也可继承一个内部 `AuditedSender` 抽象类共享审计前缀。调用端不需要知道实现如何复用。

## 10. 不要创建“一实现一接口”仪式

接口的价值来自边界：多个实现、替身、模块隔离或稳定的调用方契约。如果一个包内私有类只有一个调用者、没有替换需求，且接口与实现永远一起变化，立刻增加同名接口可能只增加导航成本。

另一方面，“当前只有一个实现”也不能自动否定接口。FactoryCare 的外部网关边界即使暂时只有短信供应商，也需要隔离供应商 SDK 和测试副作用。决策要看变化方向、测试边界和依赖所有权，而不是数文件。

## 11. 静态类型与运行时类型

~~~java
NotificationSender sender = new SmsSender();
~~~

这里至少有两个类型事实：

- 变量 `sender` 的**静态类型**是 `NotificationSender`，编译器据此判断哪些成员可调用、参数是否匹配；
- 当前引用所指对象的**运行时类**是 `SmsSender`，被重写实例方法最终使用它的实现。

静态类型来自声明并在编译期确定；变量以后可改指向另一个实现，运行时类随当前对象变化。对象自己不会因为被接口变量引用就失去字段或变成接口实例。

## 12. 向上转型

实现类引用可以赋给接口类型或父类类型：

~~~java
SmsSender sms = new SmsSender();
NotificationSender sender = sms;
~~~

这是扩宽引用转换，也常称向上转型，通常隐式完成。两个变量仍指向同一对象，`sms == sender` 为 true。接口变量只能直接使用接口公开能力，这是有意缩窄调用表面，不是删除对象能力。

向上转型让 `WorkOrderNotificationService` 不必知道 SmsSender 构造、供应商字段或特有调试方法。若调用端频繁想“拿回”具体类型，接口边界可能太窄，也可能调用端承担了不属于它的实现职责。

## 13. 动态分派的两阶段心智模型

对下面调用：

~~~java
NotificationSender sender = new EmailSender();
String result = sender.send("WO-1001", "inspect");
~~~

分成两阶段理解：

1. **编译期**：依据 `sender` 静态类型查找可适用的 `send(String, String)`，检查访问、参数与返回类型；找不到就不能生成可运行程序。
2. **运行期**：求值目标引用和参数；若目标为 null，调用失败；否则为实例方法定位实际对象类中最具体的重写实现，因而执行 EmailSender 的 `send`。

这就是动态分派的核心。JVM 实现可用方法表、内联缓存和即时编译优化，但语言学习不应把某个物理实现当规范保证。先掌握可观察选择规则。

## 14. 多态调用不等于重载选择

~~~java
void send(Object value) { }
void send(String value) { }

Object value = "WO-1001";
send(value);
~~~

重载签名主要在编译期依据表达式静态类型选出，因此这里选择 `send(Object)`，不会因为运行时对象是 String 自动改选重载。若选中的实例方法又被子类重写，运行时才在该签名上做动态分派。

调试“为什么进了这个方法”时先问：编译期选中了哪个签名？再问：这个实例方法在运行时落到哪个 override？把两步混在一起会产生大量误判。

## 15. 字段与 static 方法不参与同样的动态分派

接口或父类引用访问同名字段，名称由静态类型规则决定；static 方法也属于类型并发生隐藏，而不是对象实例重写。不要用下面的实验解释多态：

~~~java
class Base { String label = "base"; }
class Child extends Base { String label = "child"; }

Base value = new Child();
System.out.println(value.label); // 不是实例方法动态分派
~~~

需要多态变化的业务行为应放在实例方法中，并保持字段封装。公开同名字段既破坏封装又制造静态/动态类型困惑。

## 16. `super` 调用与普通多态调用不同

在子类方法中写 `super.send(...)`，明确从父类实现解析，不是对某个“父对象”再次做普通动态分派。它适合保留父类模板步骤，但也让子类耦合父实现。

接口默认方法可用 `InterfaceName.super.method()` 在满足规则时选择某个直接父接口默认实现；这是冲突解决的显式语法，不代表接口有实例字段。L1 只需识别，不应把多重默认方法链当主要复用机制。

## 17. 替换性：实现接口不等于遵守接口

编译器能确认 `SmsSender` 提供了 public `send`，却不能确认它接受所有契约允许输入。若接口说任何非空消息都合法，而 `UrgentOnlySender` 只接受 `URGENT:` 前缀，它在接口位置会破坏调用者。

共同契约测试至少覆盖：

- 同一组正常输入；
- null、空白和边界长度；
- 返回结果结构；
- 调用前后重要状态；
- 失败类型和是否保留原因；
- 敏感数据是否未泄漏到输出。

每增加一个实现，都把相同测试套件跑一遍。只为每个类写不同断言，无法证明多态替换。

## 18. 接口引用让调用端保持稳定

~~~java
final class WorkOrderNotificationService {
    private final NotificationSender sender;

    WorkOrderNotificationService(NotificationSender sender) {
        if (sender == null) throw new IllegalArgumentException("sender required");
        this.sender = sender;
    }

    String notify(String workOrderId, String message) {
        return sender.send(workOrderId, message);
    }
}
~~~

服务只依赖接口。创建位置可传 `new SmsSender()`、`new EmailSender()` 或测试记录器；`notify` 源码不出现渠道分支。这是手工依赖注入：依赖由外部构造并交给对象，不需要 Spring 才成立。

private final 固定服务生命周期内的依赖引用，构造器拒绝 null。它不保证实现对象完全不可变，也不自动决定哪个实现应在生产使用；装配配置是另一项职责。

## 19. 三种实现为何能彼此无关

短信发送器可能封装供应商客户端，邮件发送器可能组合模板渲染器，内存记录器只保存测试观察值。它们不需要共享父类状态，只需显式实现 NotificationSender：

~~~java
final class RecordingSender implements NotificationSender {
    private String observedWorkOrderId;

    @Override
    public String send(String workOrderId, String message) {
        observedWorkOrderId = workOrderId;
        return "RECORDED|" + workOrderId;
    }
}
~~~

调用端面向接口，内部复用方式各自决定。这比为了共同类型强迫所有实现继承一个携带无用状态的类更灵活。

## 20. 抽象类作为实现细节

如果短信与邮件确实共享经过验证的输入校验和审计前缀，可引入抽象类：

~~~java
abstract class AuditedSender implements NotificationSender {
    protected final String checkedPrefix(String channel, String id) {
        if (id == null || id.isBlank()) throw new IllegalArgumentException("id required");
        return channel + "|" + id;
    }
}

final class EmailSender extends AuditedSender {
    @Override
    public String send(String id, String message) {
        return checkedPrefix("MAIL", id) + "|" + message;
    }
}
~~~

调用端仍只看接口。若以后某个实现无法合理继承 AuditedSender，它可直接实现接口。抽象类不应成为外部必须向下转型的隐藏协议。

## 21. 模板方法与开放扩展点

抽象类可把稳定流程做成 final 方法，把可变小步骤声明为 protected abstract：

~~~java
abstract class ValidatingSender implements NotificationSender {
    @Override
    public final String send(String id, String message) {
        validate(id, message);
        return deliver(id, message);
    }

    protected abstract String deliver(String id, String message);
}
~~~

这样所有子类都经过统一校验，不能遗漏；子类只实现 deliver。代价是继承耦合，且父类必须能稳定定义通用流程。若渠道差异需要不断绕过模板，改用若干组合协作者可能更清楚。

## 22. default 方法解决什么

接口 default 方法允许在接口中提供实例方法体：

~~~java
interface NotificationSender {
    String send(String id, String message);

    default String channelName() {
        return "unknown";
    }
}
~~~

它可为实现提供兼容默认行为或小型派生操作，但不是把抽象父类全部搬进接口。default 没有接口实例字段可维护；若默认行为依赖大量状态或可变模板，抽象类或组合更合适。

给既有接口增加 default 方法有演进价值，但不等于任何二进制、源代码和语义组合都自动安全。实现类已有同签名方法、多个接口冲突和调用方假设都要测试。

## 23. 默认方法冲突的最小规则

当多个来源都有同签名具体方法时，Java 使用明确规则，不随机选择。L1 记住：类层次中的实例方法优先于接口 default；更具体的子接口可能优先；两个无关接口的 default 冲突通常要求实现类显式 override。

~~~java
class MultiSender implements SmsCapable, MailCapable {
    @Override
    public String channelName() {
        return "SMS+MAIL";
    }
}
~~~

若需要频繁手工消解大量默认方法冲突，可能说明能力切分或默认实现位置不合理。接口多继承适合能力契约，不应模拟复杂类状态继承。

## 24. 向下转型是什么

接口变量只暴露接口方法。有时开发者写：

~~~java
NotificationSender sender = loadSender();
SmsSender sms = (SmsSender) sender;
~~~

这是向下转型。编译器可能认为类型关系允许这种可能性，但运行时必须检查当前对象是否真是 SmsSender。若实际是 EmailSender，就抛 `ClassCastException`。强转不会把 EmailSender 变成 SmsSender，也不会调用转换构造器。

需要偶尔恢复具体类型的框架边界有其场景，但业务服务频繁强转通常表示它其实依赖具体实现，接口设计或职责划分需要重看。

## 25. `instanceof` 能防崩溃，但不自动修复设计

~~~java
if (sender instanceof SmsSender) {
    SmsSender sms = (SmsSender) sender;
    // 使用短信特有能力
}
~~~

先检查可避免错误强转。Java 还支持模式形式以减少重复强转，但本章重点不是语法糖。若服务对每个实现写一串 `if/else instanceof`，新增 ConsoleSender 时必须修改服务，说明多态行为没有放回实现契约。

并非所有类型分支都坏。序列化边界、诊断工具或封闭类型穷尽处理可能需要分支；但“发送通知”这种实现自身知道如何发送的行为，应直接调用 `sender.send`。

## 26. 第三个实现如何暴露分支设计缺陷

假设旧服务：

~~~java
if (sender instanceof SmsSender) {
    return "sms:" + ...;
} else if (sender instanceof EmailSender) {
    return "mail:" + ...;
}
throw new IllegalArgumentException("unsupported sender");
~~~

加入 RecordingSender 后，即使它正确实现 NotificationSender，服务仍抛 unsupported。错误不是第三个实现“不兼容”，而是调用端复制了实现选择。修复为 `return sender.send(...)`，并把渠道差异留在实现；然后共同契约测试自然覆盖第三种实现。

## 27. null 不参与成功分派

接口变量可以保存 null，但对 null 调用实例方法没有实际对象可分派，会抛 `NullPointerException`：

~~~java
NotificationSender sender = null;
sender.send("WO-1", "inspect");
~~~

不要用 null 表示“禁用通知”后在每个调用点加判断。可在装配时明确选择一个遵守契约的 `NoOpNotificationSender`，但它的结果和审计语义必须清楚；也可让上层显式决定不调用。选择取决于“无操作”是否真是合法业务实现，不能只为消除异常。

## 28. 编译错误：实现不完整

常见诊断是具体类“不是 abstract 且没有覆盖接口抽象方法”。排查顺序：

1. 对照接口方法名；
2. 对照参数顺序和类型；
3. 对照返回类型；
4. 确认实现方法是 public；
5. 确认导入的是预期同名接口；
6. 保留 `@Override`，不要删除诊断线索。

若类本就不应提供完整行为，可声明 abstract；若它是可实例化生产实现，就必须完成契约。不要加一个返回 null 的空方法只为通过编译。

## 29. 编译错误：不能实例化抽象类型

`new NotificationSender()` 或 `new AuditedSender()` 会编译失败，因为接口和抽象类都不能直接实例化。需要创建具体实现：

~~~java
NotificationSender sender = new SmsSender();
~~~

左边依赖抽象，右边选择具体对象。测试中可创建小型 RecordingSender；生产装配中创建真实实现。错误发生在“new 后面的类型”，不是左侧接口变量不能存在。

## 30. 运行错误：ClassCastException

JDK 25 的 `ClassCastException` 表示代码试图把对象强转为它并非实例的子类或实现类型。阅读堆栈时：

1. 找异常首行中的实际类与目标类；
2. 找第一条本项目源码帧和行号；
3. 记录赋值链，确认接口变量当前来自哪个装配点；
4. 问为什么调用端需要具体类；
5. 优先把所需行为放入合适契约或移动到拥有实现知识的边界；
6. 修复后用至少两个实现复跑，避免只让这一次 cast 成功。

把强转包进 try/catch 然后忽略，不是修复；它只把确定故障改成静默丢行为。

## 31. FactoryCare 的接口边界

FactoryCare 可定义：

~~~java
interface NotificationSender {
    String send(String workOrderId, String message);
}
~~~

`SmsSender`、`EmailSender` 和 `RecordingSender` 都实现它。应用服务只做工单通知用例编排，不读取供应商特有字段。真实系统的返回值更适合用专门结果类型表达渠道、供应商消息 ID 和状态，本章为保持零基础范围使用固定 String；record 和 enum 下一章学习。

接口放在拥有业务调用需求的边界，而不是直接暴露某家供应商 SDK 接口。这样替换供应商时，迁移成本集中在适配实现，FactoryCare 服务契约保持稳定。

## 32. 手工注入与框架注入

本章直接写构造器：

~~~java
NotificationSender sender = new SmsSender();
WorkOrderNotificationService service = new WorkOrderNotificationService(sender);
~~~

这已经体现依赖倒置和注入：高层服务依赖抽象，外部决定实现。Spring Core 会自动管理创建和装配，但不会替你设计正确接口，也不会让违反契约的实现变安全。先能手工画出对象图，后续才不会把注解当魔法。

装配位置应明确选择唯一实现或选择规则。接口有三个实现而运行时报“无法决定注入哪个”，属于配置问题，不是多态本身随机。

## 33. 用记录型实现测试服务

不连接真实短信网关，写 RecordingSender：

~~~java
final class RecordingSender implements NotificationSender {
    String observedId;
    String observedMessage;

    @Override
    public String send(String id, String message) {
        observedId = id;
        observedMessage = message;
        return "RECORDED|" + id;
    }
}
~~~

注入服务后断言 observedId、observedMessage 和返回值。这样测试的是服务是否正确委托，而不是供应商网络。实现类测试则独立验证请求转换。记录型实现只保存虚构测试数据，测试结束后不作为生产审计库。

## 34. 共同契约测试

可以写接收接口的检查方法：

~~~java
static int verifySenderContract(NotificationSender sender) {
    int passed = 0;
    passed += check(sender.send("WO-1", "inspect").contains("WO-1"));
    passed += expectIllegal(() -> sender.send(" ", "inspect"));
    return passed;
}
~~~

依次传短信、邮件和记录实现。所有实现都必须保留工单号并拒绝空白编号；渠道前缀可不同。将共同保证与实现特有行为分开：契约套件不应断言所有渠道都以 SMS 开头。

当前工件用简单 main 断言形成 T0 可重放证据；后续 Java 测试章节会用 JUnit 参数化或测试契约组织同样思想。

## 35. 安全与隐私

接口越宽，实现获得的数据越多。通知发送器若只需工单号、脱敏接收目标和模板参数，就不应接收包含所有租户、附件和内部备注的聚合对象。最小参数能减少误用和日志泄露，但参数过多时应引入经过设计的请求值类型，而不是永远堆 String。

不同实现必须遵守同一安全契约：不记录令牌，不在异常中回显完整手机号，不让测试实现意外进入生产装配。接口并不自动提供权限控制、输入净化或加密；这些仍需边界校验、配置和测试。

## 36. 可观察性与分派调试

需要确认实际实现时，可记录非敏感渠道名或 `sender.getClass().getName()` 作为诊断，但不要让生产业务逻辑依赖类名字符串。日志至少包含测试工单号、接口操作、实现类别、结果状态与相关追踪号；不包含密钥和正文。

调试步骤：

1. 打印或在调试器查看变量静态声明；
2. 查看实际对象类；
3. 对照接口签名确认编译期选择；
4. 定位实际 override；
5. 检查是否被 wrapper/抽象父类模板调用；
6. 用第二、第三实现复跑；
7. 发生强转时保存异常实际类和目标类；
8. 修复后删除只为调试加入的敏感输出。

## 37. 失败案例：接口过宽

~~~java
interface DeviceOperations {
    void start();
    void stop();
    void calibrate();
    void exportFirmware();
}
~~~

被动传感器可能不能 start，普通维修员也不应 exportFirmware。实现类只能抛“不支持”，调用者无法依赖统一契约。应按真实调用者能力拆分，例如 Startable、Calibratable 与受权限控制的固件服务；名称只是示意，拆分数量由用例决定。

小接口不是目的，可替换且权限最小的边界才是目的。

## 38. 失败案例：标记接口与类型分支

没有行为的标记接口有少数平台用途，但业务代码若只用它做 `instanceof` 分类，再在中央服务写所有分支，新增类型仍修改中央逻辑。若差异是对象自身行为，给契约一个有意义的方法；若差异只是数据分类，enum、sealed 或显式字段可能更准确，后续章节再展开。

不要为避免一个字符串就制造没有契约说明的接口。

## 39. 失败案例：泄漏实现特有 API

若服务构造器接收 NotificationSender，却立即强转 VendorSmsSender 调用 `vendorClient()`，接口只是装饰。测试替身和邮件实现都会失败。修复方向：把服务真正需要的业务行为提升到合适接口；把供应商配置留在适配器内部；或承认该服务就是供应商专用边界并显式命名，不虚假承诺通用。

抽象不是把具体类型藏在字段声明后面，而是让调用方推理确实只依赖契约。

## 40. 接口演进的取舍

给公共接口新增抽象方法会要求既有实现补齐，影响范围可能跨模块；新增 default 可提供默认行为，但可能与既有方法或其他接口冲突，也可能不符合每个实现的语义。删除或改签名则更明显破坏调用者。

演进前列出所有实现与调用者，增加契约测试，提供迁移步骤和回滚。内部新项目可以尽早修正错误接口，不必默认永久兼容；对外发布 API 则要按版本与兼容策略处理。本章小程序没有外部消费者，不模拟线上兼容承诺。

## 41. 性能与动态分派

动态分派比直接源码看起来多一步，但现代 JVM 会依据运行热点进行内联和优化。不能看到接口调用就断言性能差，也不能保证所有接口调用都被内联。通知用例通常由网络、序列化和外部服务延迟主导。

先用接口建立正确可测试边界，只有真实剖析显示分派是瓶颈时才讨论具体优化。为了猜测的纳秒收益复制业务分支，通常会显著提高维护与故障风险。

## 42. 与 TypeScript / Vue 的对照

TypeScript 的 `interface` 主要采用结构类型：对象形状兼容时可满足接口，即使没有显式 `implements`。Java 接口是名义化关系，类需显式 `implements`（或通过父类已有关系）才能作为该接口类型。不要因为两个 Java 类都有 `send` 方法就认为它们自动共享接口。

Vue 中父组件通过 prop 接收回调或 composable 返回契约，可类比调用端依赖能力而非实现；测试时替换 composable，也类似注入 RecordingSender。但 Java 的构造器、访问控制、编译期类型检查和运行时强转规则需要按 Java 自身理解。

TypeScript 的联合类型收窄常依赖分支，Java 的对象多态更倾向把行为放进实现。sealed 类型穷尽分支属于下一章，不要把所有情况一概而论。

## 43. 预测题

先写答案再运行：

1. `NotificationSender s = new SmsSender()` 中静态类型和运行时类型分别是什么？
2. 接口变量只看得到接口方法，是否表示对象的具体字段被删除？
3. 两个无关类都有同名 send 方法，但都未 implements，能否赋给 NotificationSender？
4. 实现接口方法时省略 public 会怎样？
5. 抽象类有构造器，为什么仍不能直接 new？
6. `NotificationSender s = new EmailSender(); (SmsSender) s` 在什么阶段失败？
7. 先 `instanceof` 再强转是否说明设计一定正确？
8. 重载签名和重写实现分别主要在哪个阶段选择？
9. 接口字段能否保存每个对象不同的重试次数？
10. 新增 RecordingSender 后，中央 `if instanceof` 服务为什么暴露缺陷？

## 44. 动手、故障与需求变更

### 44.1 最小构建

定义 NotificationSender，写 SmsSender 与 EmailSender；服务构造器接收接口并保存 private final 字段。创建两个服务，固定输入 `WO-1001`，预测并核对两种输出。

### 44.2 第三个实现

写 RecordingSender 保存 observedId 和 observedMessage。服务源码不改，注入后断言参数和结果。若必须修改服务分支，先记录失败，再把分支改成多态调用。

### 44.3 错误强转

把 EmailSender 放入接口变量后强转 SmsSender，保存 `ClassCastException`、退出码和第一条项目帧。修复时删除调用端对短信特有 API 的需求，不把 cast 换成另一个猜测。

### 44.4 违反契约

让一个实现接受空白工单号或拒绝父契约允许的 NORMAL 消息，用共同套件暴露。修复并复跑所有实现，证明没有只改某个期望。

### 44.5 需求变更

新增 ConsoleSender；要求只新增实现和装配代码，服务类不改。再增加非敏感 `channelName` 查询，比较抽象方法、default 与独立结果类型三种选择，说明迁移成本和语义风险。

## 45. 无 AI 独立训练

限时 90 分钟：

1. 从空目录写一个接口和三个彼此无关实现；
2. 写只依赖接口的服务和手工装配；
3. 写一个抽象类集中共同校验，让两个实现选择继承它；
4. 画变量静态类型、对象运行时类型和调用箭头；
5. 用共同契约方法验证三个实现；
6. 制造缺少接口方法的编译失败；
7. 制造错误强转的 ClassCastException；
8. 制造按类型分支遗漏第三实现的运行失败；
9. 制造一个实现加强前置条件并修复；
10. 新增第四实现，不修改服务；
11. 解释接口和抽象类选择；
12. 120 秒闭卷复述动态分派。

允许查看 JLS、Java SE API 与 `javac` 帮助，不允许 AI 直接生成最终代码。提交源码、命令、预测、正常输出、三个非零失败、修复后输出、对象图和复述提纲。

## 46. 高频误区

1. **“接口就是没有实现的抽象类。”** 接口没有实例状态/构造器，类可实现多个接口，边界不同。
2. **“接口所有方法都抽象。”** 现代 Java 还有 default、static 和 private 方法。
3. **“接口字段是每个对象一份。”** 它们隐含 public static final。
4. **“implements 就证明遵守业务契约。”** 编译器只验证类型形状，语义靠实现和测试。
5. **“抽象类没有构造器。”** 它可以有，供子类对象初始化父类部分。
6. **“接口变量里装的是接口对象。”** 实际对象仍是具体实现。
7. **“向上转型会复制或裁剪对象。”** 它只改变引用的静态视角。
8. **“运行时会按实际参数类型重新选重载。”** 重载主要在编译期选择。
9. **“字段也动态分派。”** 字段和 static 方法遵循静态名称规则。
10. **“强转会转换对象。”** 它只检查并改变引用视角，错误时抛 ClassCastException。
11. **“加 instanceof 就是多态。”** 中央类型分支常是未使用多态的信号。
12. **“default 方法可以替代所有抽象类。”** 它没有接口实例字段，状态模板仍不同。
13. **“一个实现就绝不需要接口。”** 外部边界和测试隔离也可能需要。
14. **“每个类都配接口是最佳实践。”** 没有边界价值时只是仪式。
15. **“接口调用一定慢。”** 必须以真实剖析为证据。
16. **“Spring 才有依赖注入。”** 构造器外部传入依赖已经是注入。
17. **“返回 null 是未实现方法的安全占位。”** 它把编译问题变成更晚的运行故障。
18. **“第三实现失败说明第三实现有问题。”** 也可能是调用端复制了类型分支。

## 47. 120 秒复述模板

“接口声明调用方需要的能力，类用 implements 显式实现；抽象类不能直接实例化，但可以有构造器、实例状态、具体方法和抽象方法。一个类只能直接扩展一个类，却能实现多个接口。接口变量的静态类型决定编译期可见方法和签名，当前对象的运行时类型决定被重写实例方法最终执行哪个实现，这就是动态分派。向上转型不复制对象；错误向下转型会在运行时抛 ClassCastException。实现接口只证明方法形状，所有实现还必须通过共同契约测试。FactoryCare 服务通过 private final 接口字段组合 sender，注入短信、邮件或记录实现时服务源码不改；新增第三实现若让 instanceof 分支失败，就应改回 sender.send 的多态调用。”

## 48. 间隔复习

- 当天：画出 NotificationSender 静态类型与 SmsSender 运行时对象；
- 第 2 天：闭卷写接口、抽象类和三实现，复现缺方法编译错误；
- 第 7 天：复现错误强转和第三实现分支故障，再改成多态；
- 第 14 天：给三个实现跑同一契约套件，注入记录型测试替身；
- 第 30 天：审查 FactoryCare 一个接口，判断是否过宽、是否泄露供应商、是否真有替换证据。

每次先预测签名与实现，再执行；把“编译期选择”和“运行时选择”分别写一行。

## 49. 一页速查

| 问题 | 最小结论 |
| --- | --- |
| interface | 声明能力契约，不能直接实例化 |
| implements | 类显式承诺实现接口类型 |
| 接口抽象方法 | 隐含 public abstract；实现必须 public |
| 接口字段 | 隐含 public static final，不是实例状态 |
| default | 接口提供实例默认实现，无接口实例字段 |
| abstract class | 可有构造、状态、具体与抽象方法，不能直接 new |
| 多实现关系 | 类可实现多个接口，只能直接扩展一个类 |
| 静态类型 | 编译期可见成员、重载适用性和签名检查依据 |
| 运行时类型 | 当前实际对象的具体类 |
| 向上转型 | 实现引用赋给接口/父类型，不复制对象 |
| 动态分派 | 运行时为重写实例方法定位实际实现 |
| 字段/static | 不按实例方法方式动态分派 |
| 向下转型 | 运行时检查，错误则 ClassCastException |
| instanceof | 可检查类型；大量分支仍可能是设计气味 |
| 替换 | 所有实现保持共同输入、结果和副作用契约 |
| 构造注入 | 外部创建实现，服务保存接口依赖 |
| 测试替身 | 实现同一接口，记录调用，不连接真实网关 |
| 共同套件 | 相同契约用例运行所有实现 |

## 50. 术语表

- **接口**：声明类型能力与成员契约的引用类型。
- **实现类**：通过 implements 提供接口所需行为的类。
- **抽象方法**：没有实现体、要求具体子类型实现的方法。
- **默认方法**：接口中以 default 声明并带方法体的实例方法。
- **抽象类**：不能直接实例化、可混合状态与抽象/具体行为的类。
- **具体类**：满足所有抽象成员、可以按构造规则实例化的类。
- **静态类型**：表达式或变量在编译期的类型。
- **运行时类型**：引用当前指向对象的实际类。
- **多态**：一个父类型引用可指向多个遵守契约的具体实现。
- **动态分派**：运行时为重写实例方法选择实际实现的过程。
- **向上转型**：从实现/子类引用扩宽为接口/父类引用。
- **向下转型**：把父类型引用收窄为具体子类型并在运行时检查。
- **ClassCastException**：对象不是目标子类或实现时的错误强转异常。
- **替换性**：实现替换后调用者原有契约推理仍成立。
- **共同契约测试**：对所有实现重复执行的接口保证测试。
- **依赖注入**：由对象外部提供协作者，而非对象内部硬编码创建。
- **记录型实现**：保存收到参数并返回固定结果的测试实现。
- **类型分支**：依据实际类型选择行为的 if/switch 逻辑。
- **供应商适配器**：把外部 SDK 细节转换为本系统接口契约的实现。

## 51. 本章边界与官方来源

本章要求掌握接口声明与实现、抽象类的状态和模板能力、接口/抽象类选择、静态与运行时类型、向上转型、动态分派、替换、错误强转、第三实现暴露类型分支，以及 FactoryCare 的手工依赖注入。sealed、record、enum 与穷尽模式匹配在下一章；反射、动态代理、字节码生成、泛型变型、Spring 容器自动装配和供应商网络调用不在本章展开。

以下一手资料已于 **2026-07-16** 按 Java SE 25 / JDK 25 复核：

- [JLS 25 Chapter 9 Interfaces](https://docs.oracle.com/javase/specs/jls/se25/html/jls-9.html)：接口声明、成员、继承与重写总规范。
- [JLS 25 §9.1 Interface Declarations](https://docs.oracle.com/javase/specs/jls/se25/html/jls-9.html#jls-9.1)：接口类型与 extends 关系。
- [JLS 25 §9.3 Field Declarations](https://docs.oracle.com/javase/specs/jls/se25/html/jls-9.html#jls-9.3)：接口字段的 public static final 语义。
- [JLS 25 §9.4 Method Declarations](https://docs.oracle.com/javase/specs/jls/se25/html/jls-9.html#jls-9.4)：抽象、default、static 与 private 接口方法。
- [JLS 25 §8.1.1.1 abstract Classes](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.1.1.1)：抽象类不能直接实例化及其子类责任。
- [JLS 25 §8.4.3.1 abstract Methods](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.4.3.1)：抽象方法与实现要求。
- [JLS 25 §5.1.5 Widening Reference Conversion](https://docs.oracle.com/javase/specs/jls/se25/html/jls-5.html#jls-5.1.5)：实现/子类到接口/父类型的扩宽转换。
- [JLS 25 §5.5 Casting Contexts](https://docs.oracle.com/javase/specs/jls/se25/html/jls-5.html#jls-5.5)：引用强转与运行时检查边界。
- [JLS 25 §15.12 Method Invocation Expressions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.12)：编译期方法选择与运行期求值。
- [JLS 25 §15.12.4.4 Locate Method to Invoke](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.12.4.4)：运行时实例方法定位。
- [ClassCastException API, Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/ClassCastException.html)：错误引用强转的标准异常。
- [OpenJDK JDK 25 Project](https://openjdk.org/projects/jdk/25/)：JDK 25 参考实现与 GA 信息。
- [javac 25 Tool Guide](https://docs.oracle.com/en/java/javase/25/docs/specs/man/javac.html)：`--release 25` 和编译诊断入口。

稳定核心是：调用端依赖小而明确的父契约；静态类型负责编译期可用性，实际对象负责重写实例方法的运行时实现；所有实现以共同契约证明可替换。具体诊断文本和 JVM 优化策略可能随实现或补丁变化，因此验证器只对本基线登记固定证据，不把内部优化当语言保证。
