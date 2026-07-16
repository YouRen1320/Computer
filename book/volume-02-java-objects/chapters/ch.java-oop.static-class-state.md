---
schema_version: 2
edition: 2026.2-draft
id: ch.java-oop.static-class-state
title: static、类成员与共享状态
responsibility: 区分类级成员与实例成员并识别共享可变状态风险，不把 static 当作默认工具函数容器
volume: '02'
order: 5
level: L1
status: drafting
path: book/volume-02-java-objects/chapters/ch.java-oop.static-class-state.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.encapsulation-packages
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
  text: 在 120 秒内解释static、类成员与共享状态的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-static-members
  - java-shared-state
  covers_topics:
  - java.static-field-method
  - java.class-vs-instance-member
  - java.static-initialization
  - java.shared-mutable-state
  - java.utility-method
  - java.global-state-test-risk
  uses_capabilities:
  - java.references-objects
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现实例编号计数器、静态工厂和无状态工具方法，对比多个实例字段与共享 static 字段
  covers_topic_groups:
  - java-static-members
  - java-shared-state
  covers_topics:
  - java.static-field-method
  - java.class-vs-instance-member
  - java.static-initialization
  - java.shared-mutable-state
  - java.utility-method
  - java.global-state-test-risk
  uses_capabilities:
  - java.references-objects
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入测试间共享计数泄漏和把实例规则误写 static，证明顺序依赖后移除全局可变状态
  covers_topic_groups:
  - java-static-members
  - java-shared-state
  covers_topics:
  - java.static-field-method
  - java.class-vs-instance-member
  - java.static-initialization
  - java.shared-mutable-state
  - java.utility-method
  - java.global-state-test-risk
  uses_capabilities:
  - java.references-objects
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# static、类成员与共享状态

> 本章状态为 **drafting**。正文、实验和验证器可用于学习，但运行成功不等于已经独立掌握，也不会自动修改 **PROGRESS.md**。

前几章里的每个 `Device` 对象都有自己的编码和状态：泵的状态改变，不应让阀门同步改变。但程序还需要另一类成员，例如所有工单共享的编号前缀、无需创建对象就能执行的文本判断、从输入参数创建对象的命名入口。Java 用 `static` 表示成员属于**类本身**，不用 `static` 的字段和普通方法属于**某个实例**。

`static` 解决的是“成员由类拥有还是由对象拥有”，不是“这段代码方便不方便调用”。一旦把可变字段声明为 `static`，同一运行环境里所有调用者会观察同一份状态；隐藏依赖、测试顺序污染和跨请求串值往往由此开始。本章既学语法，也学判断：什么时候类级成员准确表达事实，什么时候它只是披着方便外衣的全局变量。

本章不会展开线程竞争、Java 内存模型、依赖注入框架、类加载器体系或继承中的静态方法隐藏。它们需要后续知识。这里先建立能解释、能预测、能编译、能故意破坏并修复的单线程模型。基线是 **JDK 25**，一手资料复核日期为 **2026-07-16**。

## 1. 本章完成证据

完成不是“读懂了”或“AI 已经写好”，而是同时留下三类证据：

1. **解释证据**：120 秒内区分类字段、实例字段、类方法、实例方法；说明静态上下文为什么没有 `this`；给出共享可变状态让测试依赖顺序的反例。
2. **构建证据**：实现一个有实例序号状态的编号器、一个静态工厂和一个无状态静态工具方法；创建两个编号器并证明它们互不污染。
3. **诊断证据**：稳定复现“静态方法直接读取实例字段”的编译错误，以及“第二个测试受到第一个测试留下的静态计数影响”的运行失败；再修复并复跑固定断言。

配套工件：

- [类成员观察台](../../../examples/encyclopedia/ch.java-oop.static-class-state/README.md)
- [FactoryCare 工单编号实验](../../../labs/encyclopedia/ch.java-oop.static-class-state/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-oop.static-class-state/README.md)

私有答案只用于完成尝试后校准。公开练习的初始失败是教学设计，不要通过删除断言、固定写死输出或让验证器无条件返回零来“修好”。

## 2. 先问归属：这份数据属于谁

面对字段或方法，先不要问“能不能加 static”，而要问：

- 每个对象都可能不同吗？若是，通常属于实例。
- 所有对象是否真的共享同一个事实？若是，可能属于类。
- 方法的结果是否只由参数决定，不读取可变对象状态？若是，可能成为无状态类方法。
- 方法是在命名一种创建方式吗？若是，静态工厂可能合适。
- 这份共享数据会变化吗？若会，必须额外审查生命周期、测试隔离和未来并发风险。

例如设备编码、设备状态、所属站点显然属于每个设备；系统协议版本和固定编号前缀可能属于类级常量；“编码是否为空白”可以是无状态工具方法；“让当前设备开始维修”必须知道具体设备，所以应是实例方法。

这条归属规则比背语法更重要。把实例规则误写成静态规则，编译器有时会阻止；如果开发者又把相关字段全部改成静态，代码反而能编译，却让所有对象共享错误状态。

## 3. 实例字段：每次创建对象都有一份

~~~java
final class Device {
    private String status = "REGISTERED";

    String status() {
        return status;
    }
}

Device pump = new Device();
Device valve = new Device();
~~~

`pump` 和 `valve` 指向两个对象，每个对象各有一份 `status`。修改 `pump` 的字段不会自动修改 `valve`。实例字段必须经由某个对象引用访问，普通实例方法被调用时也有一个当前接收者，即 `this`。

“每个实例一份”不表示字段一定存放在某个教材图的固定物理区域；它描述语言层面的对象状态归属。JVM 真实布局、压缩指针和逃逸分析不是本章结论的依据。

## 4. 静态字段：类级共享的一份

~~~java
final class DeviceTicket {
    private static int createdCount;
    private final int number;

    DeviceTicket() {
        createdCount++;
        number = createdCount;
    }

    static int createdCount() {
        return createdCount;
    }

    int number() {
        return number;
    }
}
~~~

`number` 是实例字段，每张票保留自己的编号；`createdCount` 是类字段，所有 `DeviceTicket` 实例访问同一份计数。创建两张票后，第一张的 `number` 仍为一，第二张为二，而类级 `createdCount()` 返回二。

教材常说“静态字段只有一份”，完整表达应是：对某个已初始化的类，在相应类加载身份与运行环境中有类变量。它不是整个互联网、所有 JVM 进程、所有测试机器共享的唯一数据库值。重启进程会丢失普通内存状态；多实例部署也各有一份，因此静态计数器不能承担全局业务编号。

## 5. 类方法与实例方法

类方法在声明中带 `static`：

~~~java
static boolean hasText(String value) {
    return value != null && !value.isBlank();
}
~~~

推荐通过类名调用：

~~~java
boolean valid = TextRules.hasText(input);
~~~

普通实例方法通过具体对象调用：

~~~java
ticket.cancel();
~~~

Java 语法可能允许通过对象表达式调用静态方法，但这会制造“方法使用了这个对象”的错觉，应避免。IDE 常会提示改成类名。调用形式本身不能决定设计是否合理；真正的问题仍是方法读取什么状态、维护什么规则。

## 6. 静态上下文为什么没有 this

`this` 表示当前实例。类方法可以在没有任何实例的情况下通过类名调用，因此它没有一个天然的当前对象：

~~~java
final class Device {
    private String siteCode;

    static String label() {
        return siteCode; // 编译失败：不知道读取哪个 Device 的 siteCode
    }
}
~~~

如果规则确实需要一个设备，应把对象作为参数显式传入，或者把方法改为实例方法：

~~~java
static String labelOf(Device device) {
    return device.siteCode();
}

String label() {
    return siteCode;
}
~~~

第一种表达“这是一个针对任意 Device 的外部计算”；第二种表达“这是该 Device 的行为”。两者都比偷偷读取共享字段清楚。不要为了消除编译红线把 `siteCode` 改成 static；那会让所有设备只剩一个站点编码。

## 7. 访问矩阵：谁可以直接使用谁

| 当前代码位置 | 静态字段/方法 | 实例字段/方法 |
| --- | --- | --- |
| 静态方法 | 可直接按类成员解析 | 必须先获得明确对象引用 |
| 实例方法 | 可以通过类名访问 | 可通过 `this` 或其他对象访问 |
| 静态初始化块 | 可访问已允许引用的类成员 | 没有当前实例 |
| 构造器 | 可访问，但共享写入需谨慎 | 正在初始化当前实例 |

“能访问”不等于“应该访问”。构造器每创建一次对象就修改静态字段，会形成共享副作用；实例方法频繁写静态缓存，也会让对象表面 API 隐藏全局变化。代码审查要同时检查语法权限和行为影响范围。

## 8. 类初始化：默认值、显式初始化与静态块

类变量在类初始化前先得到默认值；类的静态字段初始化器和静态初始化块再按源码中的文本顺序执行。看一个只为观察顺序而写的例子：

~~~java
final class BootOrder {
    static int first = mark("first", 10);

    static {
        System.out.println("block sees first=" + first);
        second = 20;
    }

    static int second = mark("second", 30);

    private static int mark(String name, int value) {
        System.out.println(name + "=" + value);
        return value;
    }
}
~~~

预测时要按文本顺序：先执行 `first` 初始化，再执行静态块；块对 `second` 的赋值随后会被 `second` 的显式初始化覆盖，所以最终为三十。不要在业务代码中依赖这种绕弯顺序；把初始化关系写得简单、局部、无外部副作用。

对初学者最实用的规则是：静态初始化不是“源文件一出现就执行”，通常由首次主动使用触发；类初始化失败会阻止正常使用；初始化期间读取尚未显式赋值的字段可能看到默认值，但语言也禁止某些非法前向引用。完整触发清单以 JLS 为准，不靠一次 IDE 运行猜测。

## 9. 什么会触发初始化，什么可能不会

创建实例、调用静态方法、读写非常量静态字段通常需要初始化声明类。父类会在子类之前初始化。另一方面，读取已在调用方编译期内联的常量变量，可能不会初始化声明它的类：

~~~java
static final int MAX_RETRY = 3;
~~~

因此不要依靠“读取某个常量”来触发注册、日志或配置加载。静态初始化块也不应承担必须显式确认成功的外部操作，例如连数据库、写远端消息或读取会变化的用户配置。那些行为需要清晰的启动流程和错误处理。

## 10. 类初始化失败怎样看日志

如果静态字段初始化器抛出异常，第一次主动使用常会看到 `ExceptionInInitializerError`，根因链里才是最初异常；之后在同一运行环境再次使用，可能出现“无法初始化类”一类错误。诊断顺序：

1. 找首次失败，而不是只看最后一次调用；
2. 展开 `Caused by`，定位静态字段初始化器或静态块行号；
3. 检查是否读取缺失配置、做除零、解引用 null 或形成循环依赖；
4. 把有风险的外部动作移到显式方法，由调用者处理失败；
5. 新进程复跑，因为失败后的类状态不适合用热修改猜测。

本章工件主要验证编译失败和测试污染，不故意让整个类初始化永久失败；这段模型用于你读真实启动日志。

## 11. 常量入口：static final 的合适用途

类级常量通常写成：

~~~java
static final String WORK_ORDER_PREFIX = "WO-";
static final int MAX_CATEGORY_LENGTH = 40;
~~~

它们表达所有实例共享且不会重新赋值的事实，通常用大写下划线命名。访问控制仍然重要：只在包内需要就不要公开；公开常量会成为调用者可能编译依赖的 API。

不是所有 `static final` 字段都是编译期常量，也不是所有引用指向的对象都不可变。下一章会详细区分 final 变量、final 引用与不可变对象。本章只建立入口判断：固定原始值或字符串规则适合常量；可变数组、集合或业务对象即使引用 final，仍不应作为公共“常量”暴露。

## 12. 无状态工具方法

合适的工具方法具有可见输入和可见输出：

~~~java
final class WorkOrderIds {
    private WorkOrderIds() {
    }

    static String format(String site, int sequence) {
        if (site == null || site.isBlank()) {
            throw new IllegalArgumentException("site must have text");
        }
        return site + "-%04d".formatted(sequence);
    }
}
~~~

相同输入得到相同结果，方法不读隐藏的当前用户、系统时钟或全局计数，也不修改共享字段。这种方法容易手算、测试和复用。私有构造器表达该类型不打算实例化，但不要把整个业务领域都塞进 `Utils`：如果规则拥有状态、不变量或生命周期，就应由相应对象承担。

工具方法常见坏味道是参数很少、却从多个静态字段取得真正依赖。调用点看不见配置来源，测试只能反射或重置全局值。改进方向不是换一个更漂亮的工具类名，而是把依赖变成参数或放进有明确生命周期的对象。

## 13. 静态工厂：类级方法也可以创建实例

静态工厂是返回对象的静态方法：

~~~java
final class WorkOrder {
    private final String id;
    private final String status;

    private WorkOrder(String id, String status) {
        this.id = id;
        this.status = status;
    }

    static WorkOrder open(String id) {
        return new WorkOrder(id, "CREATED");
    }
}
~~~

`open` 有业务名称，可以固定初始状态并隐藏构造细节。它仍然不该依赖隐蔽静态计数器；编号器可以作为显式参数传入。静态工厂与构造器如何取舍没有一条机械答案：构造器直接、语言原生；静态工厂可命名并控制创建路径。本章只要求会写一个清晰入口，不提前讨论缓存实例、继承返回型或复杂创建框架。

## 14. 共享可变状态：看不见的输入与输出

~~~java
final class WorkOrderIds {
    private static int next = 1;

    static String nextId() {
        return "WO-%04d".formatted(next++);
    }
}
~~~

表面上 `nextId()` 没参数，实际上结果依赖隐藏的 `next`；方法还修改它。任何调用者都改变后续调用的结果。单个演示里输出一、二似乎正确，但会出现这些问题：

- 两个测试在同一 JVM 运行，前一个消耗编号，后一个期望一却得到二；
- 两个业务场景无法拥有独立序列；
- 失败测试没有清理状态，后续症状与真正原因分离；
- 重启后计数回到一，无法作为可靠业务主键；
- 将来有并发调用时还有竞争风险，但本章不展开并发机制。

共享状态并非绝对禁止。只读元数据、进程级指标或受明确生命周期管理的缓存可能合理；但“方便少传一个参数”不足以证明合理。对 L1 学习，默认先做实例状态和显式参数，直到需求能清楚证明共享范围。

## 15. 从静态全局计数改为实例编号器

~~~java
final class WorkOrderIdGenerator {
    private int next;

    WorkOrderIdGenerator(int first) {
        if (first < 1) {
            throw new IllegalArgumentException("first must be positive");
        }
        next = first;
    }

    String nextId(String siteCode) {
        return "%s-%04d".formatted(siteCode, next++);
    }
}
~~~

现在调用者显式创建并持有编号器。南昌站点与南京站点可以各有实例；测试每次创建新的 `WorkOrderIdGenerator(1)`，不需要依赖之前的清理动作。状态仍然会变化，但归属和生命周期变得可见。

这不是生产分布式编号方案。数据库序列、唯一约束和多实例部署将在数据与架构章节处理。本章实例编号器只用于证明“共享范围可以从整个类缩小到明确对象”。

## 16. 测试顺序污染如何形成

设两个测试都认为自己从干净状态开始：

~~~java
void firstTest() {
    assertEquals("WO-0001", GlobalIds.nextId());
}

void secondTest() {
    assertEquals("WO-0001", GlobalIds.nextId());
}
~~~

若在同一进程按上述顺序运行，第二个得到 `WO-0002`；单独运行第二个却可能通过。交换顺序，失败者也可能变化。这就是顺序依赖：测试结果不仅取决于被测输入，还取决于其他测试留下的历史。

识别信号包括“整套失败、单测通过”“随机顺序偶发失败”“必须手工调用 reset”“并行执行更容易红”。最小修复通常是每个测试构造自己的状态拥有者；如果共享确实是需求，也要提供由测试框架生命周期控制的隔离，而不是靠测试作者记得清理。

## 17. reset 为什么只是有限工具

给静态类增加 `resetForTest()` 能暂时让测试变绿，但有代价：生产代码暴露只为测试存在的入口；漏调用仍会污染；测试并行时重置可能打断另一个测试；真实调用链仍隐藏依赖。

在遗留系统诊断中，reset 可以帮助证明根因确实是共享状态，但不应自动成为最终设计。先用它做实验，再评估能否把状态移到实例、参数、测试夹具或更明确的外部存储边界。这个顺序能区分“定位手段”和“产品方案”。

## 18. 静态字段不是数据库、配置中心或会话

静态字段只活在当前运行时边界里。把登录用户、当前租户、请求语言、数据库连接、工单编号或可变权限列表放进普通静态字段，容易造成：

- 请求 A 的值泄露给请求 B；
- 多进程之间状态不一致；
- 进程重启后数据丢失；
- 测试与本地运行无法模拟部署拓扑；
- 敏感值长期驻留并被无关代码读取。

本章不设计替代基础设施，只建立负面判断：需要持久化、一致性、按请求隔离或安全授权的数据，不应因为 `static` 访问方便就变成类字段。

## 19. FactoryCare 场景：三种不同归属

FactoryCare 工单创建包含三类容易混淆的信息：

1. `MAX_CATEGORY_LENGTH`：所有创建请求遵循的固定规则，可作为私有或包内类级常量。
2. `category` 与 `status`：每张工单不同，属于实例字段。
3. `nextSequence`：会变化。教学实验把它放入显式 `WorkOrderIdGenerator` 实例；生产方案以后由持久化唯一性设计决定。

静态工厂 `WorkOrder.open(generator, siteCode, category)` 可以命名创建动作；它调用传入的编号器，而不是读隐藏全局计数。`TextRules.hasText(category)` 是无状态工具。这样一行调用能展示真正依赖，也能在测试中替换为新实例。

当需求变为“每个站点分别编号”，实例编号器自然表达多个状态所有者；全局静态字段则需要另加映射、重置与同步，设计复杂度暴露了最初归属选择不合适。

## 20. 正例、边界例与失败例

| 类别 | 例子 | 预期 |
| --- | --- | --- |
| 正例 | 两个编号器都从一开始 | 相互独立 |
| 正例 | 相同参数调用纯格式化方法 | 输出一致 |
| 边界 | 首个序号为零 | 构造时拒绝 |
| 边界 | 站点编码为空白 | 方法拒绝 |
| 失败 | static 方法直接读取实例字段 | javac 编译失败 |
| 失败 | 两个测试共用静态 next | 第二个受顺序污染 |
| 失败 | 用 static 保存当前用户 | 跨请求数据串扰风险 |
| 失败 | 读取常量来期待启动副作用 | 初始化可能不发生 |

测试时要明确每个例子的 oracle。编译失败的 oracle 是非零退出码和目标诊断；运行失败的 oracle 是非零退出码及明确业务消息；正常运行则比较完整输出或固定断言计数，不能只看最后有没有 `PASS` 字样。

## 21. 编译诊断：non-static variable cannot be referenced

典型源码：

~~~java
final class Ticket {
    private String category;

    static int categoryLength() {
        return category.length();
    }
}
~~~

编译器报告实例变量不能从静态上下文引用。第一处可信位置是 `category` 使用行，而不是 Maven 或 shell 最后的 `BUILD FAILURE`。修复前回答：方法到底属于具体 Ticket，还是应接收一个 Ticket/字符串参数？只有确定归属后才改代码。

错误修复是给 `category` 加 static。它消除了红线，却让最后一个对象覆盖所有对象的分类。正确修复通常是去掉方法的 static，或者把所需值变成参数。验证器保留这份失败源码为 `.java.txt`，正常构建不会误编译它，然后复制到临时目录单独确认预期失败。

## 22. 运行诊断：expected WO-0001 but was WO-0002

顺序污染不会编译失败。日志可能只有断言差异：

~~~text
ORDER_DEPENDENCY expected=WO-0001 actual=WO-0002
~~~

按以下顺序定位：

1. 找谁生成 `actual`；
2. 查看该函数是否读取或写入 static 可变字段；
3. 单独运行失败场景，比较是否转绿；
4. 在同一进程先执行另一个场景，再复现；
5. 用新建实例替代共享状态，按两种顺序复跑；
6. 保留回归断言，防止以后又引入全局计数。

不要先把期望改成二。测试的业务前提是每个场景独立；若前提合理，改期望只会把污染合法化。

## 23. 测试策略：证明归属，不只证明一个输出

至少覆盖：

- 两个实例字段取值不同；
- 类级只读常量对两者一致；
- 两个状态拥有者从相同初值独立演进；
- 静态工厂创建的对象满足初始不变量；
- 无状态工具方法覆盖 null、空白、正常值；
- 非法初始序号在边界被拒绝；
- 静态访问实例字段稳定编译失败；
- 全局计数器的顺序污染稳定运行失败。

一个进程里只跑一次正例无法证明隔离。应创建两个实例、交换调用顺序、重复构造，并断言各自结果。测试名要表达契约，例如 `twoGeneratorsStartIndependently`，而不是 `test1`。

## 24. 安全与可靠性边界

共享静态变量扩大了数据影响范围。尤其不要保存明文令牌、当前用户、租户 ID、请求 DTO 或可修改权限数据。`private static` 只限制普通源码访问，不提供加密和请求隔离；日志、反射、内存转储或类内其他方法仍可能接触它。

无状态工具方法也必须校验不可信输入，不能因为没有字段就自动安全。静态工厂仍要维护构造不变量。类初始化里的异常如果包含敏感配置，不应把完整值输出给终端或用户。访问范围、数据敏感性和生命周期必须分别评估。

## 25. TypeScript 与 Vue 对照

| Java | TS/Vue 中相近直觉 | 不能直接等同之处 |
| --- | --- | --- |
| 实例字段 | `new Class()` 后每个对象的属性 | JS 对象模型与 JVM 类语义不同 |
| static 字段 | 类构造器属性或模块级变量 | ES 模块缓存与类初始化规则不同 |
| static 工具方法 | 导出纯函数 | Java 有编译期类成员与访问控制 |
| 共享可变 static | 模块顶层可变变量 | 打包、SSR 与多实例边界不同 |
| 实例方法的 this | JS 方法里的 `this` | JS 的 this 绑定更动态 |
| Vue 组件内 `ref` | 组件实例状态 | 组合式 API 的闭包不是 Java 字段 |

前端开发者常把 `static` 类比为模块导出。这个类比只用于“调用不需要对象”的第一层直觉。Nuxt SSR 中模块级状态也可能跨请求共享，因此风险方向相似；但具体运行时、初始化和隔离机制不能用 Java 规则替代。

## 26. AI 生成代码审查清单

AI 为了减少参数，容易建立 `GlobalContext`、`CurrentUserHolder`、`Counters` 或巨型 `Utils`。逐项检查：

1. 每个 static 字段是否真正类级且生命周期明确？
2. 字段是否可变；谁写、谁清理、谁观察？
3. 方法是否从隐藏静态字段读取真实输入？
4. 静态方法是否因无法访问实例字段而把字段也错误改静态？
5. 工具方法能否由输入完全解释输出？
6. 静态工厂的依赖是否显式传入？
7. 测试是否整套失败、单独通过？
8. 进程重启、多实例部署后语义是否仍成立？
9. static 是否保存用户、租户或令牌？
10. 常量是否暴露了可变对象？

要求 AI 说明每个类成员的所有者与生命周期，再接受补丁。若答案只是“这样调用方便”，证据不足。

## 27. 预测—构建—破坏—需求变更

### 27.1 预测

不运行先写答案：创建两张票后实例序号与类计数分别是多少；静态方法直接写 `this.status` 在哪个阶段失败；两个独立生成器交错调用会输出什么；静态全局生成器在第二个测试中为什么从二开始；读取编译期常量是否必然触发静态块。

### 27.2 构建

完成实验中的 `WorkOrderIdGenerator`、`WorkOrder.open` 和 `TextRules.hasText`。使用 `javac --release 25` 编译，运行固定断言。解释每个字段是类级还是实例级，不接受“IDE 自动生成”作为解释。

### 27.3 故意破坏

一次只改一处：把编号器的 `next` 改成 static；把工厂使用的 category 改为隐藏静态字段；让 static 方法直接访问实例字段；让两个场景共用同一个全局编号器。记录失败阶段、首条可信证据、原因与最小修复。

### 27.4 需求变更

新增“每个站点独立编号”。先修改测试，让 NC 与 NJ 都从一开始，再调整实例创建。第二个变更是“格式化方法支持固定前缀”，把前缀作为参数或只读常量，不引入可变全局配置。整个修改过程不重新生成所有文件。

## 28. 无 AI 独立训练

限时 60 分钟，从空目录完成：

1. 写一个含实例字段和 static 计数的最小观察类；
2. 手算三次构造后的输出再运行；
3. 写一个无状态工具方法和一个静态工厂；
4. 把共享计数重构到实例编号器；
5. 写至少十个断言证明两个编号器隔离；
6. 制造静态上下文访问实例字段的编译失败；
7. 制造顺序污染运行失败并读出 expected/actual；
8. 在不使用 reset 的前提下修复；
9. 用 120 秒解释为何“private static”仍是共享状态。

允许查 `javac --help` 和本章速查，不允许让 AI 直接给最终实现。训练证据包括命令、退出码、失败日志和修复后的完整复跑。

## 29. 高频误区

1. **“static 表示不能修改。”** 不可重新赋值由 final 讨论，static 只说明类级归属。
2. **“static 就是全世界唯一。”** 通常只在相应运行时和类加载身份内共享。
3. **“工具方法都应 static。”** 先判断是否无状态、边界是否清楚。
4. **“静态方法效率更高，所以都加。”** 设计归属不能由未经测量的性能猜测决定。
5. **“通过对象调用 static 就是实例方法。”** 推荐类名调用，声明才决定性质。
6. **“static 方法不能使用任何对象。”** 它可以使用参数或自己创建的对象，只是没有当前 `this`。
7. **“编译红线用把字段改 static 修复。”** 这常把实例状态错误升级为共享状态。
8. **“每个测试前 reset 就彻底隔离。”** 漏调用、并行和隐藏依赖仍存在。
9. **“private static 对其他请求安全。”** private 不是请求或租户隔离。
10. **“static final 一定是不可变对象。”** final 引用与对象可变性在下一章区分。
11. **“读取常量一定执行静态块。”** 编译期常量可能被内联。
12. **“本地计数器可当生产全局 ID。”** 重启和多实例会破坏假设。

## 30. 复述、复习与检索

### 30.1 120 秒复述模板

“实例成员属于具体对象，因此每个对象可以有不同状态；静态成员属于类，可在没有实例时使用。静态上下文没有 this，所以需要实例规则时应改为实例方法或显式传对象。无状态工具方法、命名静态工厂和只读类级常量是常见合理用途。可变 static 字段把历史变成隐藏输入，会导致测试顺序污染、跨请求串值和部署不一致。我的失败证据是……，我通过把状态移到显式实例并复跑……证明修复。”

### 30.2 间隔复习

- 当天：画类成员/实例成员访问矩阵，完成预测题；
- 第 2 天：从空目录重建计数示例和编译失败；
- 第 7 天：随机交换两个场景顺序，解释污染证据；
- 第 14 天：审查一个 `Utils` 类，标出隐藏输入；
- 第 30 天：从 FactoryCare 选三个字段，说明正确生命周期，不立即重构生产代码。

## 31. 一页速查

| 问题 | 最小结论 |
| --- | --- |
| `static` 字段 | 类级共享状态 |
| 普通字段 | 每个对象一份 |
| `static` 方法 | 无当前实例与 `this` |
| 实例方法 | 针对接收者对象调用 |
| 推荐调用静态方法 | `TypeName.method()` |
| static 直接读实例字段 | 编译失败，缺明确对象 |
| 类初始化顺序 | 默认值后，字段初始化器与静态块按文本顺序 |
| 首次主动使用 | 通常触发类初始化 |
| 编译期常量读取 | 可能不触发声明类初始化 |
| 无状态工具方法 | 依赖显式参数，无隐藏可变状态 |
| 静态工厂 | 有名称的类级创建入口 |
| 可变 static | 隐藏输入、共享副作用、测试污染风险 |
| 测试整套失败单独通过 | 优先排查共享状态与顺序依赖 |
| reset | 可辅助定位，不自动成为理想设计 |
| 业务全局编号 | 不能由普通内存 static 保证 |

## 32. 术语表

- **类成员**：由类拥有的 static 字段或方法。
- **实例成员**：由具体对象拥有或针对具体对象调用的字段与方法。
- **类变量**：static 字段，在相应类运行边界中共享。
- **实例变量**：每个对象分别拥有的字段。
- **类方法**：static 方法，没有当前实例。
- **实例方法**：相对于某个接收者对象调用的方法。
- **静态上下文**：没有当前外围实例可供隐式使用的代码上下文。
- **类初始化**：执行类变量显式初始化器和静态初始化块的过程。
- **主动使用**：会要求相关类完成初始化的一类语言操作。
- **静态工厂**：用 static 方法命名并执行对象创建的入口。
- **无状态工具方法**：结果由显式输入决定且不修改隐藏共享状态的方法。
- **共享可变状态**：多个调用者观察并能间接或直接改变的同一份数据。
- **隐藏依赖**：调用签名没有展示、却影响结果的外部状态。
- **测试污染**：一个测试留下的状态改变另一个测试结果。
- **顺序依赖**：交换执行顺序会改变成功或失败结果。
- **生命周期**：状态从创建、使用到释放或重置所处的范围。

## 33. 本章边界与官方来源

本章要求能区分类级和实例级成员；解释 static 上下文没有 `this`；预测必要的类初始化顺序；合理使用只读常量入口、静态工厂和无状态工具方法；以编译失败和顺序污染证据识别错误共享状态。线程安全、JMM、类加载器细节、依赖注入和分布式编号留到后续。

以下一手资料已于 **2026-07-16** 按 Java SE 25 / JDK 25 复核：

- [JLS 25 §8.2 Class Members](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.2)：类成员总体分类。
- [JLS 25 §8.3.1.1 static Fields](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.3.1.1)：类变量与实例变量。
- [JLS 25 §8.4.3.2 static Methods](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.4.3.2)：类方法及静态上下文限制。
- [JLS 25 §8.7 Static Initializers](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.7)：静态初始化块。
- [JLS 25 §12.4 Initialization of Classes and Interfaces](https://docs.oracle.com/javase/specs/jls/se25/html/jls-12.html#jls-12.4)：初始化触发、顺序和过程。
- [JLS 25 §15.12 Method Invocation Expressions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.12)：方法调用表达式。
- [javac 25 Tool Guide](https://docs.oracle.com/en/java/javase/25/docs/specs/man/javac.html)：`--release`、`-XDrawDiagnostics` 与编译退出状态。

稳定核心是“先决定状态和行为的所有者，再决定是否 static；把真正输入和副作用显式化；用独立实例与顺序交换证明隔离”。诊断文字和具体工具输出可能随补丁版本变化，类成员语义不会因此改变。
