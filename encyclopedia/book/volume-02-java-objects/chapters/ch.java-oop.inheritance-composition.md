---
schema_version: 2
edition: 2026.2-draft
id: ch.java-oop.inheritance-composition
title: 继承、重写、super、组合与复用选择
responsibility: 教授 is-a 与 has-a 的复用边界，优先用组合表达可替换依赖，不在本章引入接口多态
volume: '02'
order: 7
level: L1
status: drafting
path: book/volume-02-java-objects/chapters/ch.java-oop.inheritance-composition.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.final-immutability
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
  text: 在 120 秒内解释继承、重写、super、组合与复用选择的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-inheritance
  - java-composition
  covers_topics:
  - java.extends
  - java.override
  - java.super-call
  - java.composition
  - java.is-a-has-a
  - java.liskov-warning
  uses_capabilities:
  - java.encapsulation-immutability
  - java.references-objects
  - java.methods
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 分别用继承和组合实现通知发送策略，写出替换条件并选择组合版本作为可切换依赖
  covers_topic_groups:
  - java-inheritance
  - java-composition
  covers_topics:
  - java.extends
  - java.override
  - java.super-call
  - java.composition
  - java.is-a-has-a
  - java.liskov-warning
  uses_capabilities:
  - java.encapsulation-immutability
  - java.references-objects
  - java.methods
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入子类违反父类前置条件和 super 调用遗漏，比较行为后重构为不破坏契约的组合，并把异常定位到第一处可信证据
  covers_topic_groups:
  - java-inheritance
  - java-composition
  covers_topics:
  - java.extends
  - java.override
  - java.super-call
  - java.composition
  - java.is-a-has-a
  - java.liskov-warning
  uses_capabilities:
  - java.encapsulation-immutability
  - java.references-objects
  - java.methods
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 继承、重写、super、组合与复用选择

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《final、常量与不可变对象》](ch.java-oop.final-immutability.md)：独立完成继承与重写、组合与复用前，必须先具备「final、常量与不可变对象」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文与验证工件可用于学习和作者自检，但不代表学习者已完成无 AI 构建、故障诊断或复述，也不会自动修改 `PROGRESS.md`。

当两个类都有“发送通知”或“描述设备”的代码时，初学者很容易把复用等同于 `extends`。继承确实能让子类取得父类的一部分状态和行为，还能重写实例方法；但它同时建立了一个很强的类型承诺：在父类可用的地方，子类也应当保持父类契约。若只是想借用几行代码，却不能承担这个承诺，继承会把暂时的重复变成长期耦合。

组合采用另一种关系：一个对象把另一个对象保存为字段，并通过调用它完成部分工作。前者“拥有或使用”后者，是 **has-a**，不宣称自己“就是”后者。组合通常更适合可替换依赖、策略和协作者。本章用普通类层次完成替换实验，不提前讲接口多态；接口、抽象类以及完整动态分派模型在下一章系统展开。

本章基线为 **Java 25 / JDK 25**，示例不使用 preview 功能。一手资料复核日期为 **2026-07-16**。

## 1. 学完后要留下什么证据

不要用“看懂了”作为完成证据。至少留下三类可复放结果：

1. **解释**：在 120 秒内说清 `extends`、重写、`super`、is-a、has-a 和替换警告，并举出“正方形继承可变矩形”或“紧急通知继承短信通知”中的一个失败反例。
2. **构建**：先用父类和子类实现通知格式，再用一个持有格式器字段的服务实现组合；固定输入下两种方式输出可比较，组合依赖可单独换掉。
3. **诊断**：真实运行“子类加强输入限制”和“遗漏 `super` 导致基础审计丢失”两个故障；保存非零退出码和第一条可信错误，再修复并复跑。

配套工件：

- [继承与组合观察台](../../../examples/encyclopedia/ch.java-oop.inheritance-composition/README.md)
- [FactoryCare 通知复用实验](../../../labs/encyclopedia/ch.java-oop.inheritance-composition/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-oop.inheritance-composition/README.md)

私有答案只用于独立尝试后的校准，不应复制到公开练习。验证脚本要求故障真实发生；删除故障源码、把异常吞掉或直接打印 `PASS` 都不算证据。

## 2. 前置知识补救

进入本章前，应能解释类、对象、字段、实例方法、构造器、访问控制和 `final`。若这些词仍混在一起，先回到前置章做三个最小检查：

- 能画出“引用变量指向对象”，并说明两个引用可能指向同一个对象；
- 能写一个构造器，在对象创建时建立非空编号不变量；
- 能解释 `private` 字段由类自己维护，`final` 引用不等于对象不可变。

继承不会替代封装。父类把字段改成 `protected` 只是为了让子类随意写，通常是在扩大可变面；子类也不能修复一个从创建起就非法的父类对象。若构造、不变量和可见性尚不清楚，继承层次只会把错误藏得更深。

## 3. 两种复用关系的直觉模型

先不用语法，问两个业务问题：

- “短信通知是不是一种通知？”若任何接收通知的代码都能安全接收短信通知，可能存在 is-a 关系。
- “工单服务是不是一种短信格式器？”显然不是。工单服务只是**使用**格式器，这是 has-a 关系。

is-a 是类型关系，影响可替换性；has-a 是对象协作关系，影响依赖装配。代码形状可能很像，但承诺强度完全不同。继承把父类公开与受保护契约带进子类；组合只需要协作者提供调用方真正使用的行为。

判断时不要问“能否复用代码”，而要问：“未来有人只按父类型编程时，这个子类是否仍然正确？”若回答需要补一句“除了某些输入、某些顺序、某些调用”，就已经出现替换风险。

## 4. `extends` 的最小语法

Java 类使用 `extends` 指定直接父类：

~~~java
class Notice {
    String render(String workOrderId) {
        return "NOTICE|" + workOrderId;
    }
}

class SmsNotice extends Notice {
}
~~~

`SmsNotice` 没有声明 `render`，但可通过继承得到可访问的实例方法。创建 `new SmsNotice()` 时仍然只创建一个对象，不是“里面再装一个完整 Notice 对象”。这个对象包含其类层次定义的实例状态；运行时类信息知道它是 `SmsNotice`，也属于 `Notice` 类型。

每个普通类最多直接扩展一个类，这叫类的单继承。若没写 `extends`，除 `Object` 本身外，直接父类默认为 `java.lang.Object`。所以 `toString`、`equals`、`hashCode` 等契约最终来自 Object，但它们的系统讨论留到对象契约章节。

## 5. 继承成员不等于复制源码

“子类继承父类成员”是语言关系，不是把父类源码粘贴到子类。成员是否可在子类源码中直接访问，还受访问控制影响：

- `public` 成员可按公开契约使用；
- `protected` 成员在子类和同包范围有专门访问规则，不等于“对所有人半公开”；
- 包访问成员只在包边界允许时可见；
- `private` 成员不能由子类名称直接访问，但父类对象状态仍可能包含它们，子类应通过父类提供的行为协作。

把父类字段做成 `private final`，再提供维护不变量的方法，通常比让子类直接修改 `protected` 字段稳健。继承不是绕过父类封装的许可证。

## 6. 方法重写：替换父类的实例行为

子类声明与可重写父类实例方法具有匹配签名的方法，就可以重写该行为：

~~~java
class SmsNotice extends Notice {
    @Override
    String render(String workOrderId) {
        return "SMS|" + workOrderId;
    }
}
~~~

`@Override` 是编译器可检查的意图声明。若误写成 `renders`，或参数从 `String` 变成 `int`，编译器会指出它没有重写任何超类型方法。没有注解时，这个拼写错误可能悄悄变成一个新重载方法，使父类行为继续被调用。因此，重写实例方法时默认写 `@Override`。

重写不是“同名就行”。方法签名、返回类型兼容性、可见性和异常声明都受规则约束。L1 阶段先牢牢记住：参数列表不能随意改变，访问权限不能比父方法更窄；返回类型可在语言允许的范围内更具体。受检异常的细节在异常章节学习。

## 7. 重写、重载与隐藏不要混为一谈

三个概念的区别直接影响调试：

- **重写 override**：子类替换父类的实例方法实现，选择与对象实际类型有关；
- **重载 overload**：同一可见范围内有同名但参数列表不同的方法，编译器依据调用点静态信息选择签名；
- **隐藏 hide**：字段和 `static` 方法不是实例方法重写，名称解析遵循不同规则。

~~~java
class Base {
    static String kind() { return "BASE"; }
    String label() { return "base"; }
}

class Child extends Base {
    static String kind() { return "CHILD"; } // 隐藏，不是重写
    @Override String label() { return "child"; }
}
~~~

不要用静态方法实验推导实例方法多态，也不要给字段加同名字段期待“重写字段”。需要变化的行为放在实例方法后再测试。

## 8. `super` 调用父类实现

在重写方法中，`super.method(...)` 明确调用父类版本：

~~~java
class SmsNotice extends Notice {
    @Override
    String render(String workOrderId) {
        String base = super.render(workOrderId);
        return "SMS|" + base;
    }
}
~~~

这适合在保留父类保证的基础上增加行为。例如父类统一校验工单编号并生成审计前缀，子类只追加渠道信息。`super` 不是另一个对象引用，也不能保存到变量；它是从当前对象的父类视角解析成员的专用表达式。

遗漏 `super` 不一定编译失败。若父方法只是拼字符串，子类完全替换它是合法的；但若父类承担校验、审计或不变量维护，遗漏会成为业务故障。因此需要输出断言，而不能只依赖编译器。

## 9. `super(...)` 与构造链

子类构造最终必须连接到父类构造。最常见写法：

~~~java
class Notice {
    private final String tenantId;

    Notice(String tenantId) {
        this.tenantId = tenantId;
    }
}

class SmsNotice extends Notice {
    SmsNotice(String tenantId) {
        super(tenantId);
    }
}
~~~

若构造器没有显式写 `this(...)` 或 `super(...)`，编译器只会尝试插入无参数 `super()`；父类没有可访问无参构造器时，子类必须显式选择父构造器。父类部分先初始化，随后才轮到子类实例初始化和构造体后续部分，因此父类应先建立自己的不变量。

Java 25 已采用灵活构造器体规则，受限制的语句可以位于显式构造器调用之前；但在父构造完成前不能任意使用尚未构造好的当前对象。初学代码仍建议把参数的纯校验保持简单，把 `super(...)` 关系写得一眼可见。不要背诵旧版“文本上永远必须是第一条语句”后忽略版本，也不要把新规则误解为可以提前调用任意实例方法。

## 10. 初始化顺序的可观察模型

对 `new SmsNotice(...)` 建立足够调试用的顺序：

1. 为整个对象分配空间，实例字段先处于默认值阶段；
2. 沿构造链进入父类构造；
3. 父类实例字段初始化器和实例初始化块按语言规定执行；
4. 父类构造体完成其部分；
5. 返回子类，执行子类字段初始化和构造体其余部分；
6. 构造表达式完成，调用者取得已构造引用。

这是语言级观察模型，不要把它画成“父对象和子对象各在一块独立内存”，也不要擅自声称 JVM 必须采用某种物理布局。需要定位问题时，使用构造日志、断言和堆栈，而不是靠想象具体地址。

## 11. 危险失败：父构造器调用可重写方法

父类构造器里调用可重写实例方法，可能在子类字段尚未初始化时进入子类实现：

~~~java
class BaseNotice {
    BaseNotice() {
        validate();
    }
    void validate() { }
}

class SmsNotice extends BaseNotice {
    private final String phone = "13800000000";
    @Override void validate() {
        // 被父构造调用时，phone 可能尚未执行字段初始化。
    }
}
~~~

这类问题看起来像“final 字段怎么会是 null”，根因却是构造期间发生了可重写调用。调试时从堆栈第一条业务帧向下看构造链，确认对象是否已完成创建。设计上让构造器只建立自身状态，避免把开放扩展点放进构造过程。

## 12. 哪些行为不能重写

常见边界：

- `final` 实例方法禁止子类重写，可用来固定不变量流程；
- `final` 类禁止被扩展，适合不希望出现替换语义的值对象或安全边界；
- `private` 方法不是子类可见的重写目标，子类出现同名方法也不是重写它；
- `static` 方法发生隐藏，不参与实例方法重写；
- 构造器不被继承，也不能重写。

不要为了测试方便移除关键 `final`，也不要把所有方法都设为可重写。每个扩展点都需要说明子类允许改变什么、必须保留什么；没有这种说明的“开放”通常只是未来故障入口。

## 13. 父类型引用与替换预告

子类对象可以赋给父类型变量：

~~~java
Notice notice = new SmsNotice("TENANT-A");
~~~

这叫向上转型，通常不需显式强转。调用点能写哪些成员首先由变量的静态类型 `Notice` 决定；若调用的是被重写实例方法，运行时会使用实际对象相应实现。这里先用它验证“父类型用例能否接收子类”，完整的静态类型、运行时类型和动态分派流程在下一章展开。

向上转型不会创建副本，也不会切掉子类部分。变量和此前子类引用仍可指向同一个对象。千万不要用“对象被转成父对象”理解它。

## 14. is-a 不是中文句子通顺就成立

“A 是一种 B”只是第一轮筛选，不能代替契约检查。例如“紧急短信是一种短信”听起来通顺，但若父类 `SmsNotice.send` 接受任何合法文本，子类却只接受以 `URGENT:` 开头的文本，那么父类型调用者传普通文本时会在子类失败。名词分类成立，不代表行为替换成立。

更可靠的检查：

1. 父类接受的合法输入，子类是否都接受？
2. 父类承诺的结果和副作用，子类是否至少保持？
3. 父类维护的不变量，子类是否会破坏？
4. 父类允许的调用顺序，子类是否偷偷增加前置步骤？
5. 父类型测试换成子类实例后，是否无需改断言？

这就是本章所需的 Liskov 替换警告，不要求先掌握形式化逻辑，但必须用固定输入验证。

## 15. 加强前置条件为什么危险

父类契约说“非空消息都可发送”，子类改成“至少五个字符才可发送”，就是加强前置条件。调用者按父契约传入 `OK` 完全合理，换成子类却抛异常：

~~~java
class NoticeSender {
    String send(String text) {
        if (text == null || text.isBlank()) throw new IllegalArgumentException();
        return text;
    }
}

class StrictSender extends NoticeSender {
    @Override String send(String text) {
        if (text.length() < 5) throw new IllegalArgumentException("too short");
        return super.send(text);
    }
}
~~~

修复不是让所有父调用者知道 `StrictSender` 特例。可选方向是：恢复父契约；把更严格规则变成调用前独立校验协作者；或承认它不是可替换子类型，改用组合并给它独立名称。

## 16. 削弱结果保证与破坏不变量

替换失败不只来自输入。父类承诺“成功返回非空审计编号”，子类可能返回 null；父类承诺“发送失败不修改重试计数”，子类却先写状态再抛异常；父类保证租户编号永不变化，子类通过暴露的 `protected` 字段绕过校验。这些都让父类型调用者原有推理失效。

测试子类时复用父契约用例：相同合法输入、相同非法边界、相同前后状态断言。只测试子类新增的“快乐路径”无法证明可替换。

## 17. 经典警告：可变矩形与正方形

假设 `Rectangle` 分别允许 `setWidth(5)` 和 `setHeight(4)`，调用者期望面积为 20。若 `Square extends Rectangle` 为保持边长相等，在两个 setter 中同时改宽高，那么同一调用序列得到面积 16 或 25。几何分类说正方形是矩形，但这个**可变 API 契约**不可替换。

问题不一定靠“更聪明的 override”解决。可以把宽高建模为不可变值并一次构造，或让 `Square` 与 `Rectangle` 组合共享面积计算，而不是共享可变 setter 契约。设计类型要看程序行为，不是只看现实世界分类学。

## 18. 继承用于什么更合适

继承较适合以下同时成立的情况：

- 业务上确有稳定 is-a 关系；
- 父类有清晰、可测试、面向子类说明的契约；
- 子类能通过父类全部契约测试；
- 共享状态和模板流程确实需要由同一层次维护；
- 层次较浅，变化方向可预期；
- 调用者真会按父类型使用这些对象，而不只是为了拿到工具方法。

如果唯一理由是“少写十行”，先提取普通协作者或无状态函数。复制一小段清晰代码有时也比错误抽象更便宜；复用数量不是设计质量指标。

## 19. 组合：把协作者放进字段

组合的最小形态：

~~~java
class NoticeFormatter {
    String format(String workOrderId) {
        return "NOTICE|" + workOrderId;
    }
}

class WorkOrderNotifier {
    private final NoticeFormatter formatter;

    WorkOrderNotifier(NoticeFormatter formatter) {
        if (formatter == null) throw new IllegalArgumentException("formatter required");
        this.formatter = formatter;
    }

    String notify(String workOrderId) {
        return formatter.format(workOrderId);
    }
}
~~~

`WorkOrderNotifier` 不是 `NoticeFormatter`，它拥有一个格式器并委托工作。构造器注入让依赖显式、非空且可在创建时决定。字段设为 `final` 固定协作关系，但格式器对象是否可变仍由其类型契约决定。

## 20. 委托不是把所有方法原样转发

组合对象通常只暴露自身业务需要的能力。`WorkOrderNotifier` 可以先校验工单归属、再调用格式器、最后记录结果；它不必把格式器所有方法公开。若机械生成几十个一行转发方法，可能说明协作者边界过大或类型职责不清。

委托的价值在于重新定义边界：调用者依赖通知服务，通知服务依赖格式能力。每一层只公开自己的契约，内部对象可替换而不会自动扩大外部 API。

## 21. 用普通类演示可替换组合依赖

本章尚未引入接口，可先用一个稳定父类作为字段静态类型：

~~~java
class NoticeFormatter {
    String format(String id) { return "NOTICE|" + id; }
}

class SmsFormatter extends NoticeFormatter {
    @Override String format(String id) { return "SMS|" + super.format(id); }
}

class MailFormatter extends NoticeFormatter {
    @Override String format(String id) { return "MAIL|" + super.format(id); }
}

WorkOrderNotifier sms = new WorkOrderNotifier(new SmsFormatter());
WorkOrderNotifier mail = new WorkOrderNotifier(new MailFormatter());
~~~

服务本身不需要继承短信或邮件类；变化被限制在字段依赖。下一章会把 `NoticeFormatter` 抽象成更窄的接口，使调用者只依赖真正需要的契约。

## 22. 组合为何更容易局部变化

假设增加“夜间发送要脱敏手机号”。继承方案若把手机号、格式、发送、审计都塞进深层父类，修改一个模板可能影响所有子类。组合方案可让脱敏器、格式器和发送器分别承担职责，替换其中一个对象即可。

组合的代价也真实存在：对象数量和装配代码会增加；协作链过长时定位调用路径更难；若接口或父类型设计过宽，仍会形成耦合。因此推荐“优先考虑组合”，不是“禁止继承”或“字段越多越好”。

## 23. 继承与组合决策表

| 决策问题 | 倾向继承 | 倾向组合 |
| --- | --- | --- |
| 关系语义 | 稳定 is-a | uses/has-a |
| 父类型调用 | 子类必须长期可替换 | 外部不需要把宿主当协作者 |
| 变化方向 | 同一模板流程下少量受控扩展 | 策略、渠道、规则会独立变化 |
| 状态共享 | 父类统一维护不变量 | 各对象各自维护状态 |
| 复用目的 | 共享类型契约与实现 | 只复用某项能力 |
| 测试 | 父契约套件适用于所有子类 | 可给宿主注入可控替身 |
| 耦合 | 子类依赖父类可见行为 | 宿主依赖协作者公开边界 |
| 迁移 | 改父类可能影响整棵层次 | 可逐个替换装配点 |

若仍犹豫，先用对象图写出各自职责和变化原因。两个类“经常一起改”不是继承证据；同一个业务名词也不自动构成 is-a。

## 24. 深继承层次的维护成本

当 `A <- B <- C <- D` 四层都重写同一方法时，阅读 D 的行为可能需要来回跳转多文件，确认每层是否调用 `super`、是否改变状态、是否吞掉异常。父类一个看似无害的修改会影响未知子类，这常被称为脆弱基类问题。

控制手段包括：保持层次浅；把不变量流程做成不可重写入口，把可变小步骤做成明确扩展点；为父契约建立可复用测试；避免 `protected` 可变字段；当变化轴相互独立时拆成组合协作者。不要把“设计模式名称”当修复，先用失败用例定位真正耦合。

## 25. `super` 调用过多也是信号

子类每个方法都必须先 `super`，再修补父结果，说明子类可能只是包装父类。若调用顺序必须严格为“父前—子—父后”，父类模板流程也许合理；若各子类不断绕过、撤销或重复父行为，更可能应改为宿主持有协作者并明确编排。

重构前先冻结现有可观察契约：固定输入、输出、异常、状态变化和审计记录。然后把一项行为移到字段对象，复跑父契约用例。没有回归断言的“继承改组合”容易丢失隐蔽副作用。

## 26. FactoryCare：设备分类不要从表名直接推继承

FactoryCare 有泵、阀门、传感器。可以设计 `Device` 父类与具体子类，但先问共同契约是否稳定：所有设备是否都有同一身份、位置和启停行为？传感器可能不可被平台“启动”，阀门开合与泵启停的状态也不同。若父类强行声明 `start()`，某些子类只能抛“不支持”，这已经破坏替换预期。

更稳妥的第一步通常是把共同数据建模为设备身份值，把可选能力作为独立协作者；接口能力将在下一章继续。不要为了映射一张数据库父表就建立 Java 继承，也不要因为现实世界有分类就默认软件行为相同。

## 27. FactoryCare：通知渠道适合组合

工单通知服务负责“何时通知、通知谁、关联哪个工单”；短信或邮件协作者负责“如何形成并发送某渠道消息”。服务不是一种短信，也不是一种邮件，因此 has-a 清晰：

~~~text
WorkOrderNotificationService
  ├─ uses WorkOrderRepository（后续章节）
  ├─ has NoticeFormatter
  └─ records NotificationResult
~~~

本章实验只用内存对象和固定字符串，不连接真实短信网关，不记录真实手机号。切换 `SmsFormatter` 与 `MailFormatter` 时服务调用代码不改，证明变化边界；下一章再用接口让三种无关实现共享契约。

## 28. 子类契约故障的诊断顺序

遇到“父类型测试在某个子类失败”，按证据顺序排查：

1. 保存完整命令、JDK 版本、退出码、标准输出与错误输出；
2. 找第一条由本项目代码抛出的异常或断言，不先被后续包装信息带走；
3. 记录变量的静态类型和对象实际类；
4. 定位最终执行了哪一个重写方法；
5. 对照父契约输入，检查子类是否加强前置条件；
6. 比较调用前后状态，检查结果保证和不变量；
7. 检查遗漏或重复的 `super` 调用；
8. 用同一固定输入修复后复跑父类和所有子类。

只在失败子类上改期望值会掩盖替换问题。若新期望确属业务变更，应先修改父契约和所有实现测试，而不是悄悄制造特例。

## 29. 编译错误怎么读

### 29.1 `method does not override`

看到 `@Override` 相关编译错误，先比较方法名、参数个数、参数类型、包导入与父方法可见性。不要第一反应删除注解；注解正在揭示你的意图和代码事实不一致。

### 29.2 `cannot find symbol: method ...`

确认变量静态类型是否声明该方法。子类对象放入父类型变量后，只能直接调用父类型可见契约；若业务必须频繁向下转型才能调用子类特有方法，父抽象可能选错。

### 29.3 `constructor ... cannot be applied`

检查子构造器的 `super(...)` 参数是否匹配父构造器，以及父无参构造器是否存在且可访问。不要为消除错误随手加一个产生非法对象的空构造器。

### 29.4 `overridden method is final`

这表示父类明确关闭了该扩展点。先确认需求是否应通过组合实现；不要未经契约评估就移除 final。

## 30. 测试继承：父契约测试套件

即使暂不使用测试框架，也能写一个接收父类型对象的检查方法：

~~~java
static int verifyNoticeContract(Notice notice) {
    int passed = 0;
    passed += check(notice.render("WO-1001").contains("WO-1001"));
    passed += expectIllegal(() -> notice.render(" "));
    return passed;
}
~~~

把父对象、每个子对象依次传入。固定合法输入验证结果保证，空白和 null 验证输入边界，调用前后验证状态。若只有父对象通过，就不能声称子类型可替换。

测试 `super` 时不要查看源码猜“应该调用了”。让父行为产生可观察但不敏感的计数或前缀，再断言恰好出现一次。真实生产审计应使用受控日志或事件，不应为了测试泄露手机号和正文。

## 31. 测试组合：替换协作者

组合对象的测试关注两件事：宿主是否以正确输入调用协作者；更换协作者是否不改宿主业务代码。本章没有接口，可定义一个记录参数的普通父类测试替身：

~~~java
class RecordingFormatter extends NoticeFormatter {
    String observedId;
    @Override String format(String id) {
        observedId = id;
        return "RECORDED";
    }
}
~~~

将它传给 `WorkOrderNotifier`，断言 `observedId` 和返回值。下一章用接口后，替身不必继承带实现父类，契约会更窄。

## 32. 安全、隐私与可观察性边界

继承会扩大可见和可变边界。`protected String phone` 让所有子类都能读取并意外记录手机号；`protected` setter 可能绕过租户和状态校验。优先保留私有状态，以受控方法提供最小能力。组合协作者也不能获得“整个工单对象”只因调用方便，应传递它完成职责所需的最小数据。

故障日志记录工单测试编号、渠道类型、规则名称和异常类别即可，不写真实手机号、通知正文、令牌或供应商密钥。本仓示例使用虚构编号；真实网关调用、凭据管理、重试和幂等都不属于本章范围。

## 33. 性能判断不要先于正确边界

继承方法调用与组合委托都可能被 JVM 优化，不能只看源码多一层调用就断言组合更慢。实际性能取决于热点、对象逃逸、内联条件和工作负载；通知系统通常先受网络与外部网关影响。先建立正确契约和可测试边界，有真实剖析证据后再优化。

同样，不要为了“少创建一个对象”把所有策略塞进深父类。维护风险、错误隔离和测试成本通常比一个小协作者对象更值得关注。

## 34. 与 TypeScript / Vue 的对照

TypeScript 也有 `class Child extends Base` 和 `super(...)`，Vue 组件则更常通过 props、composable 与子组件组合能力。直觉上，Java 组合类似把服务对象作为构造参数保存，而不是让业务服务继承工具类。

关键差异是不要把 TypeScript 的结构类型直觉直接搬来：Java 类关系是显式、名义化的，`extends` 建立声明关系；两个类恰好有同名方法，不会自动成为同一父子类型。Java 接口的显式 `implements` 在下一章学习。

Vue 中“mixin 冲突、来源难追踪”的经验也能帮助理解深继承：行为来自多层隐式合并时，修改风险增大。组合把依赖放到清晰字段和构造位置，更容易导航，但仍需控制协作者数量。

## 35. 失败案例：为复用工具方法继承

~~~java
class StringHelpers {
    String normalize(String value) { return value.trim(); }
}

class WorkOrderService extends StringHelpers {
}
~~~

工单服务不是一种字符串助手。这个继承只为拿到方法，会让所有 public/protected 成员进入服务类型表面，并限制未来真正需要的父类。改成 `private final WorkOrderCodeNormalizer normalizer`，或在职责明确时使用无状态函数，比伪造 is-a 更准确。

## 36. 失败案例：用异常表示“不支持父行为”

若 `Device` 父类公开 `start()`，`PassiveSensor extends Device` 只能抛 `UnsupportedOperationException`，调用者就无法只按 Device 契约安全编程。可以拆分共同身份与可启动能力；下一章会用接口表达能力。当前至少要承认层次契约过宽，而不是在文档角落列特殊子类。

“多数子类支持”仍不等于父类应声明。父类型公开的方法必须对所有合法实例有清晰行为。

## 37. 从继承迁移到组合的安全步骤

1. 列出现有父类公开、受保护行为与所有子类；
2. 用固定输入冻结正常、边界、异常和状态副作用；
3. 找出只因复用实现而存在、并非 is-a 的子类；
4. 提取一个职责单一的协作者类；
5. 让原类通过 private final 字段委托；
6. 先保留外部调用契约，逐个迁移装配点；
7. 复跑父契约和故障用例；
8. 确认没有调用者依赖 protected 字段或向下转型后，再删除旧层次。

生产迁移还需要影响清单和回滚点。本章实验是新建小程序，不包含兼容 API，因而可直接比较两种设计，不模拟未验证的线上迁移。

## 38. 预测题

执行前先写答案：

1. `Child extends Base` 但不声明构造器，父类只有 `Base(String id)`，能否编译？为什么？
2. 子方法把参数从 `String` 改成 `Object` 并写 `@Override`，是在重写还是重载，编译器会怎样？
3. 父字段 private，子对象中是否完全不存在这份状态？子类能否直接按字段名访问？
4. `Base ref = new Child()` 是否创建了一个 Base 副本？
5. `super.render(id)` 会调用另一个父对象吗？
6. 父类接收任意非空消息，子类拒绝长度小于五的消息，哪条替换规则被破坏？
7. 工单服务继承 `SmsSender` 只为调用发送方法，是 is-a 还是 has-a？
8. final 类能否被继承？final 方法能否在子类重写？

答完再运行示例，把每个错因写成一句可复用规则。

## 39. 动手与故障训练

### 39.1 最小构建

写 `NoticeFormatter`、`SmsFormatter` 和 `MailFormatter`。子类重写 `format` 并使用一次 `super.format`。再写 `WorkOrderNotifier`，以 private final 字段保存父类型格式器。固定输入 `WO-1001`，验证两种格式都保留工单编号。

### 39.2 故障注入

在 SmsFormatter 中拒绝长度小于八的合法工单号，运行同一个父契约检查并保存非零退出码。另一次删除 `super.format`，让审计前缀消失。两次故障分别修复，不要同时修改以免失去因果证据。

### 39.3 需求变更

新增夜班格式器，要求服务调用代码不改，只改创建时传入的协作者。然后要求所有格式必须对空白编号失败，确认规则应留在稳定父类还是独立校验对象，并说明选择。

### 39.4 设计反驳

有人提议 `WorkOrderNotificationService extends SmsFormatter` 以减少一个字段。写出 is-a、替换测试、未来邮件渠道、状态封装和回滚难度五个维度的反驳；若你支持继承，也必须给出父契约和可替换证据。

## 40. 无 AI 独立训练

限时 75 分钟，从空目录开始：

1. 建一个两层类继承，使用 `@Override` 与 `super`；
2. 输出并手算构造顺序；
3. 写一个接收父类型的契约检查，跑父类和两个子类；
4. 制造一次拼错方法名的 `@Override` 编译失败；
5. 制造一次子类加强前置条件的运行失败；
6. 制造一次遗漏 `super` 的审计失败；
7. 把一个伪 is-a 服务改为持有协作者字段；
8. 通过构造参数切换两个协作者；
9. 完成一个新增渠道需求，不重写整个程序；
10. 120 秒复述继承和组合选择。

允许查看 JLS、JDK API 和 `javac` 帮助；不允许让 AI 生成最终代码。提交源码、命令、预期与实际输出、失败退出码、修复后输出和复述提纲。

## 41. 高频误区

1. **“继承就是复制父类代码。”** 它建立类型与成员继承关系，不是源码复制。
2. **“中文能说 A 是 B 就一定适合 extends。”** 还要通过行为契约替换。
3. **“同名方法都是重写。”** 参数不同可能是重载，static 方法是隐藏。
4. **“删除 @Override 就修好了。”** 这通常只是掩盖没有重写的事实。
5. **“private 字段不在子对象里。”** 状态仍属于对象，只是子类不能直接按名访问。
6. **“super 是父对象。”** super 是成员解析方式，不是独立对象引用。
7. **“构造器会被继承。”** 构造器不继承；子构造连接父构造链。
8. **“父构造调用 override 很方便。”** 子字段可能尚未初始化。
9. **“子类可以拒绝更多输入。”** 这会破坏父调用者的替换预期。
10. **“protected 等于安全扩展点。”** 可变字段会扩大不变量破坏面。
11. **“组合绝对优于继承。”** 两者服务不同关系，都有成本。
12. **“多一层委托一定慢。”** 没有剖析证据不能下结论。
13. **“为了复用工具方法可以 extends。”** 这通常是假 is-a。
14. **“父类型变量会裁掉子对象。”** 向上转型不复制、不裁剪对象。
15. **“只测子类新增路径就能证明替换。”** 必须复用父契约测试。
16. **“异常表示不支持也没关系。”** 若父契约承诺支持，子类特例就是风险。

## 42. 120 秒复述模板

“继承用 extends 建立 is-a 类型关系，Java 类只有一个直接父类。子类可以继承可访问成员，并用 Override 重写可重写实例方法；super 可调用父实现或连接父构造。继承的关键不是少写代码，而是子类在父类型位置保持输入、结果和不变量契约。子类加强前置条件、遗漏父校验或用异常表示不支持，都会破坏替换。组合是宿主以字段持有协作者的 has-a 关系，适合通知渠道这类独立变化依赖。我的验证用同一父契约跑所有子类，再通过构造参数替换格式器；若 is-a 不稳定，我优先选择组合。”

## 43. 间隔复习

- 当天：画出 `Notice <- SmsNotice` 类型箭头和 `Service -> Formatter` 持有箭头；
- 第 2 天：默写重写、重载、隐藏的区别，复现 `@Override` 拼写故障；
- 第 7 天：从空目录重建父契约测试和加强前置条件失败；
- 第 14 天：把一个工具类继承重构为组合，说明影响与回滚；
- 第 30 天：审查 FactoryCare 一个候选继承层次，用五条替换问题做决定。

每次复习先闭卷预测，再运行。只重复阅读不会形成诊断能力。

## 44. 一页速查

| 问题 | 最小结论 |
| --- | --- |
| `extends` | 建立直接类继承；普通类最多一个直接父类 |
| 默认父类 | 未声明时通常为 `Object` |
| 继承成员 | 受成员种类与访问控制约束，不是复制源码 |
| 重写 | 子类提供兼容签名的实例方法实现 |
| `@Override` | 让编译器核验重写意图 |
| 重载 | 同名、不同参数签名，主要由编译期选择 |
| static/字段同名 | 隐藏，不是实例方法重写 |
| `super.method()` | 从父类实现开始解析当前调用 |
| `super(...)` | 子构造连接父构造链 |
| final 类/方法 | 分别禁止继承、禁止重写 |
| is-a | 稳定类型关系，必须支持替换 |
| has-a | 宿主持有或使用协作者 |
| 替换警告 | 不加强前置、不削弱保证、不破坏不变量 |
| 组合 | 字段 + 构造注入 + 委托 |
| 继承适用 | 稳定父契约、浅层次、真正父类型调用 |
| 组合适用 | 策略或依赖独立变化，不需要宿主成为其子类型 |
| 首要测试 | 同一父契约用例运行父类和所有子类 |
| 首要调试 | 实际类、执行方法、第一条业务失败、调用前后状态 |

## 45. 术语表

- **父类 / 超类**：被另一个类通过 extends 直接或间接扩展的类。
- **子类**：扩展父类并可增加或重写行为的类。
- **单继承**：一个类最多有一个直接父类。
- **继承成员**：依据语言与可见性规则从父类获得的成员。
- **重写**：子类为父类可重写实例方法提供兼容实现。
- **重载**：同名方法使用不同参数签名。
- **隐藏**：子类同名字段或 static 方法遮蔽父类名称的现象。
- **super**：访问父类成员实现或连接父构造的专用语法。
- **向上转型**：把子类引用赋给父类型变量，不创建新对象。
- **is-a**：对象属于某个更一般类型的关系。
- **has-a**：对象持有或使用另一个对象的组合关系。
- **替换性**：父类型可用处换成子类型后，原契约仍成立。
- **前置条件**：调用者在调用前必须满足的输入或状态要求。
- **结果保证**：成功或失败后实现承诺的结果、状态与副作用。
- **不变量**：对象在可观察稳定状态必须持续满足的规则。
- **组合**：通过字段连接对象并委托行为。
- **委托**：宿主把部分工作转交协作者执行。
- **脆弱基类**：父类变化意外影响未知子类的维护风险。
- **父契约测试**：对所有子类型重复执行的共同契约用例。

## 46. 本章边界与官方来源

本章要求掌握类的 `extends`、实例方法重写、`@Override`、`super` 方法与构造调用、is-a/has-a 判断、替换警告和组合委托；能够复现加强前置条件及遗漏父行为；能够为 FactoryCare 通知选择组合。接口与抽象类、三个无关实现共享契约、完整动态分派和错误向下转型留到下一章；sealed 层次、模式匹配、反射代理和泛型变型不在本章展开。

以下一手资料已于 **2026-07-16** 按 Java SE 25 / JDK 25 复核：

- [JLS 25 §8.1.4 Superclasses and Subclasses](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.1.4)：类扩展与直接父类规则。
- [JLS 25 §8.2 Class Members](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.2)：类成员与继承边界。
- [JLS 25 §8.4.8 Inheritance, Overriding, and Hiding](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.4.8)：实例方法重写、static 隐藏及约束。
- [JLS 25 §8.4.3.3 final Methods](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.4.3.3)：final 方法的重写限制。
- [JLS 25 §8.8.7 Constructor Body](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.8.7)：Java 25 构造器体、prologue 与 epilogue 规则。
- [JLS 25 §8.8.7.1 Explicit Constructor Invocations](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.8.7.1)：`this(...)`、`super(...)` 与构造链。
- [JLS 25 §15.11.2 Accessing Superclass Members using super](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.11.2)：`super` 成员访问。
- [Override API, Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Override.html)：`@Override` 的编译器检查语义。
- [OpenJDK JDK 25 Project](https://openjdk.org/projects/jdk/25/)：JDK 25 参考实现与 GA 信息。
- [javac 25 Tool Guide](https://docs.oracle.com/en/java/javase/25/docs/specs/man/javac.html)：`--release 25` 与编译诊断入口。

稳定核心是：继承建立强类型承诺，重写必须保持父契约；组合建立显式对象协作，适合独立变化依赖。Java 25 对构造器体的具体语法比旧版本更灵活，因此教材明确标注版本；替换性、封装与固定输入验证不依赖补丁诊断文本。
