---
schema_version: 2
edition: 2026.2-draft
id: ch.java-oop.object-contracts
title: equals、hashCode 与 toString 直接契约
responsibility: 教授对象值相等、哈希一致性和可读表示，不提前用 Set/Map 行为证明契约
volume: '02'
order: 10
level: L1
status: drafting
path: book/volume-02-java-objects/chapters/ch.java-oop.object-contracts.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.final-immutability
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
  text: 在 120 秒内解释equals、hashCode 与 toString 直接契约的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-equality-hash
  - java-object-string
  covers_topics:
  - java.equals-contract
  - java.hashcode-contract
  - java.identity-vs-equality
  - java.tostring-contract
  - java.debug-representation
  - java.sensitive-field-redaction
  uses_capabilities:
  - java.references-objects
  - java.encapsulation-immutability
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为不可变 DeviceId 实现 equals/hashCode/toString，构造自反、对称、传递、相等哈希和脱敏输出断言，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - java-equality-hash
  - java-object-string
  covers_topics:
  - java.equals-contract
  - java.hashcode-contract
  - java.identity-vs-equality
  - java.tostring-contract
  - java.debug-representation
  - java.sensitive-field-redaction
  uses_capabilities:
  - java.references-objects
  - java.encapsulation-immutability
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入 equals 比较字段与 hashCode 字段不一致、toString 泄露敏感值，定位契约失败并修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - java-equality-hash
  - java-object-string
  covers_topics:
  - java.equals-contract
  - java.hashcode-contract
  - java.identity-vs-equality
  - java.tostring-contract
  - java.debug-representation
  - java.sensitive-field-redaction
  uses_capabilities:
  - java.references-objects
  - java.encapsulation-immutability
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# equals、hashCode 与 toString 直接契约

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《final、常量与不可变对象》](ch.java-oop.final-immutability.md)：独立完成相等与哈希、对象表示前，必须先具备「final、常量与不可变对象」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文与验证工件可用于学习和作者自检，不代表学习者已完成无 AI 构建、诊断或复述，也不会自动修改 `PROGRESS.md`。

两个 `new DeviceId("TENANT-A", "DEV-001")` 是两个不同对象，还是同一个业务值？答案可能同时是：引用身份不同，设备标识值相等。Java 的 `==` 检查引用是否指向同一对象，`equals` 由类型定义“逻辑上相等”；一旦定义值相等，`hashCode` 必须保持相等对象得到相同哈希；`toString` 则给人提供简洁可读的调试表示，同时不能泄露租户、令牌或其他受保护值。

这三种方法都来自 `java.lang.Object`，每个普通 Java 对象最终都有默认实现。覆盖它们不是生成几行模板就结束，而是在发布类型契约：哪些字段定义值、修改后是否还是同一个值、子类是否能保持对称、哈希是否使用相同字段、日志字符串是否安全。错误通常不会在覆盖方法那一行立刻报错，而会以不对称结果、相等哈希不一致或敏感信息泄漏出现。

本章只用**直接断言**验证 Object 契约，不借助 Set/Map 的表现间接推测；集合和哈希表行为在下一卷学习。基线为 **Java 25 / JDK 25**，一手资料复核日期为 **2026-07-16**。

## 1. 本章完成证据

至少留下三类证据：

1. **解释**：120 秒内区分引用身份和值相等，背出 equals 五条要求与 hashCode 两个关键方向，并说明 toString 为何不是序列化或安全日志保证。
2. **构建**：为不可变 DeviceId 选择 tenantId + value 作为相等字段，实现 equals/hashCode/toString；直接断言自反、对称、传递、一致、null、异类、相等哈希和脱敏输出。
3. **诊断**：复现 equals 与 hashCode 使用不同字段、equals 重载而非重写、继承相等不对称、null/异类强转失败和 toString 泄露；记录第一条可信 expected/actual 后修复并复跑。

配套工件：

- [Object 契约观察台](../../../examples/encyclopedia/ch.java-oop.object-contracts/README.md)
- [FactoryCare DeviceId 直接契约实验](../../../labs/encyclopedia/ch.java-oop.object-contracts/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-oop.object-contracts/README.md)

私有答案不得进入公开材料。验证器要求故障真实非零退出；删除反例、只比较一个对象、让所有 hash 固定后宣称“完全正确”，或把 secret 改成另一个硬编码文本都不是修复证据。

## 2. 前置知识补救

开始前应能：

- 画出两个引用变量指向同一或不同对象；
- 区分基本类型值与引用值；
- 写 private final 字段、构造校验和只读访问器；
- 解释不可变对象在构造后不暴露可观察状态变化；
- 使用 `@Override`，知道参数列表改变会变成重载。

若 `a == b` 仍被解释为“字段逐个比较”，先回到引用章节。对引用类型，`==` 的问题是“两个引用值是否指向同一个对象（或都为 null）”；它不自动进入对象字段。

## 3. 所有类最终继承 Object

普通类未写 extends 时，直接父类通常是 `java.lang.Object`；即使有其他父类，继承链最终也到 Object。常见方法包括：

- `getClass()`：当前对象的运行时类；
- `equals(Object)`：逻辑相等契约，默认退化为身份相等；
- `hashCode()`：与 equals 协作的整数哈希；
- `toString()`：非 null 的文本表示；
- 线程协调和 clone 等其他成员，分别在对应章节学习。

本章只覆盖 equals/hashCode/toString 以及用于理解它们的 getClass/身份。不要把 Object 当“没有类型的万能袋子”，也不要通过向上转型 Object 丢失业务契约。

## 4. 默认 equals 是身份相等

Object 的默认 equals 对非 null 引用成立，当且仅当 `this == obj`。因此：

~~~java
DeviceId a = new DeviceId("TENANT-A", "DEV-001");
DeviceId b = new DeviceId("TENANT-A", "DEV-001");

System.out.println(a == b);       // false：两个对象
System.out.println(a.equals(b));  // 若未重写，也是 false
~~~

默认行为并非错误。对只关心独立身份、没有值替换语义的对象，它可能合适。覆盖 equals 前必须先定义业务相等，而不是因为 IDE 能生成。

## 5. 身份与值相等是两个问题

`==` 回答引用身份；`equals` 回答类型作者定义的逻辑关系：

~~~java
boolean sameObject = a == b;
boolean sameDeviceIdValue = a.equals(b);
~~~

两个不同对象可以值相等；同一对象当然应与自身 equal。值相等不合并内存、不让两个引用自动改为同一个对象，也不意味着它们未来所有副作用共享。

String 已覆盖 equals 以比较字符序列，所以字符串内容比较用 equals；偶尔看到字面量 `==` 为 true 可能来自字符串池，不应把它当内容契约。

## 6. 先定义“什么字段构成相等”

FactoryCare 的 DeviceId 可由 tenantId 与设备 code 共同定义。不同租户都可能有 `DEV-001`，只比较 code 会把两个业务标识误判相等；展示名称、导入时间或状态不是标识组成，不应加入。

写代码前列一张表：

| 字段 | 参与 equals | 参与 hashCode | 出现在 toString |
| --- | --- | --- | --- |
| tenantId | 是 | 是 | 只显示 `<redacted>` |
| value | 是 | 是 | 是 |
| displayName | 否 | 否 | 可选，通常不放 DeviceId |
| accessToken | 不应属于 DeviceId | 不应 | 绝不明文 |

相等和 hash 字段必须一致；toString 是可观察性决策，可以更少且脱敏。

## 7. 值对象与实体的相等边界

DeviceId 是值对象：tenantId + code 相同就可替换。WorkOrder 是有身份和生命周期的实体：状态从 CREATED 变到 ASSIGNED 后仍是同一工单。若实体 equals 包含 status、assignee 或 updatedAt，业务变化会改变相等结果，调用者很难推理。

实体常按稳定 ID 定义相等，也可能保留身份相等，取决于生命周期和持久化边界。不能把“所有字段”当默认答案；先问哪些对象在业务上应属于同一等价类。

## 8. equals 的正确签名

~~~java
@Override
public boolean equals(Object other) {
    // ...
}
~~~

参数必须是 Object，返回 boolean，方法为 public。若写成 `equals(DeviceId other)`，那是重载，不是覆盖；通过 DeviceId 静态类型调用时可能看似正常，通过 Object 引用调用时仍执行 Object.equals，造成同一对对象结果取决于调用点静态类型。

始终写 `@Override`。编译器会在签名错误时直接报警；不要删除注解来“修复”。

## 9. final 值类的 equals 模板

~~~java
public final class DeviceId {
    private final String tenantId;
    private final String value;

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        if (!(other instanceof DeviceId candidate)) {
            return false;
        }
        return tenantId.equals(candidate.tenantId)
                && value.equals(candidate.value);
    }
}
~~~

先处理同一引用是快速且清晰的自反路径；类型检查同时安全处理 null 与异类；最后比较全部逻辑字段。构造器先拒绝 null，字段比较就不需到处补空判断。

## 10. equals 契约一：自反性

对任意非 null 引用 x，`x.equals(x)` 应为 true。若方法受当前时间、随机数或每次递增计数影响，自反性或一致性可能失败。

直接断言：

~~~java
check(a.equals(a), "reflexive");
~~~

不要只测两个不同对象；自反是最低成本的故障定位点。

## 11. equals 契约二：对称性

对任意非 null x、y，`x.equals(y)` 与 `y.equals(x)` 必须相同。继承最容易破坏：父类只比较 code，子类还要求 tenant；父看子为 equal，子看父为 unequal。

~~~java
check(a.equals(b) == b.equals(a), "symmetric");
~~~

不可变值类设为 final 能关闭子类添加相等状态的风险。可扩展类需要更谨慎的等价设计；不要在 L1 自创复杂 canEqual 协议而没有完整证明。

## 12. equals 契约三：传递性

若 x equal y 且 y equal z，则 x 必须 equal z。常见破坏来自近似数值、子类兼容规则或“任一字段相同就算 equal”这类非等价关系。

直接构造 a、b、c 三个独立 DeviceId，同 tenant/value：

~~~java
check(a.equals(b), "a=b");
check(b.equals(c), "b=c");
check(a.equals(c), "a=c transitive");
~~~

只测一对对象无法发现传递故障。

## 13. equals 契约四：一致性

在用于相等比较的信息未修改时，多次 `x.equals(y)` 应稳定返回相同结果。契约明确有这个条件：比较字段变化后，结果可变化；但这说明把可变字段放入 equals 会提高风险。

不可变 DeviceId 让 tenant/value 构造后不变，直接重复调用即可验证。不要让 equals 依赖数据库、远程服务、当前用户或系统时间，它应是对象本地、无副作用、可重复的判断。

## 14. equals 契约五：与 null 比较

对任意非 null x，`x.equals(null)` 应为 false，不应抛异常。`instanceof` 检查天然让 null 返回 false：

~~~java
if (!(other instanceof DeviceId candidate)) {
    return false;
}
~~~

直接强转 `DeviceId candidate = (DeviceId) other` 会在异类时 ClassCastException；先访问 `other.getClass()` 会在 null 时 NPE。类型和 null 边界应在读取字段前完成。

## 15. 异类对象应该怎样

`DeviceId.equals("DEV-001")` 应返回 false，不因字符串内容相同就跨类型相等。跨类型相等很难保持对称：String 不会反过来认为自己等于 DeviceId。

值的解析与对象相等是两件事。若输入是字符串，先通过显式工厂解析成 DeviceId，再比较 DeviceId；不要让 equals 兼任转换器。

## 16. getClass 与 instanceof 的选择

两种常见类型检查：

~~~java
if (other == null || getClass() != other.getClass()) return false;
// 或
if (!(other instanceof DeviceId candidate)) return false;
~~~

对于 final DeviceId，没有子类，二者在本类比较上效果接近。对可继承类，instanceof 允许父子比较，可能引出对称/传递问题；getClass 要求运行时类完全相同，可能与代理或特定框架预期冲突。

没有脱离上下文的万能模板。L1 的不可变值对象优先 final，关闭继承后让契约更简单；框架实体与代理在后续持久化章节单独设计。

## 17. hashCode 为什么和 equals 绑定

hashCode 返回 int，用于把对象映射到哈希空间。它不是唯一 ID、内存地址、安全摘要或随机数。Object 契约最关键的方向：

> 如果 `a.equals(b)` 为 true，那么 `a.hashCode() == b.hashCode()` 必须为 true。

反方向不成立：两个不 equal 对象允许哈希相同，这叫碰撞。不要写断言要求所有不等对象 hash 不同；int 空间有限，对象可能无限多，碰撞无法彻底消除。

## 18. hashCode 的稳定范围

同一应用执行期间，只要 equals 使用的信息未修改，对同一对象重复调用 hashCode 应返回同一 int。契约不要求跨不同 JVM 启动仍保持同值，也不要求等于某个机器地址。

因此：

- 不把默认 hash 输出当持久 ID；
- 不写依赖某个具体整数的跨版本协议；
- 不在计算中加入随机数、当前时间或可变计数；
- 相等字段不可变会让稳定性更容易保证。

## 19. equals 与 hashCode 必须使用同一逻辑字段

危险实现：

~~~java
// equals 只比较 value
return value.equals(other.value);

// hashCode 却同时使用 tenantId 和 value
return 31 * tenantId.hashCode() + value.hashCode();
~~~

两个不同 tenant、同 value 的对象会被 equals 判为相等，却得到不同 hash，直接违反契约。修复不是让 hash 只返回零就结束，而是先决定相等是否真的应忽略 tenant；FactoryCare DeviceId 应同时比较 tenant/value，hash 同样使用两者。

## 20. 一个清晰的 hashCode 实现

~~~java
@Override
public int hashCode() {
    int result = tenantId.hashCode();
    result = 31 * result + value.hashCode();
    return result;
}
~~~

31 是常见组合因子，不是语言强制。也可使用 `Objects.hash(tenantId, value)` 简化，但应知道它按传入字段计算并有可变参数包装成本。L1 更重要的是字段集合与 equals 一致、结果稳定，不是背某个公式。

哈希质量影响后续哈希结构性能，但“不同对象必须不同 hash”不是正确性契约。

## 21. 只覆盖 equals 不覆盖 hashCode

Object API 明确提醒：覆盖 equals 时通常必须同时覆盖 hashCode，以保持相等对象相同哈希。若只写 equals，Object 默认 hash 多半与对象身份相关，两个值相等的新对象可能返回不同整数。

直接检查，不等集合章节：

~~~java
check(a.equals(b), "equal fixture");
check(a.hashCode() == b.hashCode(), "equal hash");
~~~

这个 oracle 比“放进某容器看找不找得到”更靠近契约根因。

## 22. 让 hashCode 返回常数是否正确

若所有对象 `hashCode()` 都返回 1，相等对象确实得到同值，从纯正确性方向看未违反“equal -> same hash”。但所有对象碰撞会让哈希结构失去性能优势，也掩盖字段选择错误。

因此常量 hash 不是本章合格实现。测试应验证相等一致性和直接字段预期，不应把“碰巧没违反一条”当设计完成。

## 23. 可变相等字段的风险

~~~java
class Device {
    String code;
    String status;
    // equals/hashCode 同时包含 status
}
~~~

状态变化后，同一对象的 equals/hashCode 结果改变。契约的一致性条件允许“比较信息修改后”结果变化，但调用方很难安全使用这种对象。对实体，选择稳定 ID；对值对象，保持字段不可变并让“变化”产生新对象。

不要为了当前测试把 updatedAt、状态、展示名全部加入 IDE 生成列表。相等字段是领域决策。

## 24. 默认 toString 做什么

Object 的默认 toString 形式等价于运行时类名、`@` 和 hashCode 的无符号十六进制表示：

~~~text
com.factorycare.DeviceId@1a2b3c
~~~

这不是可靠内存地址，也不一定是身份哈希；若类覆盖 hashCode，默认 toString 的尾部会反映该调用结果。默认形式通常不能直接说明哪个设备值，因此值类宜提供更有信息的表示。

## 25. toString 的直接契约

Java SE 25 Object API 要求返回非 null，并建议表示简洁、有信息、便于人阅读。它是调试表示，不是：

- JSON 或稳定 API 响应；
- 数据库存储格式；
- 可逆解析协议；
- 审计事件完整载荷；
- 自动安全脱敏机制；
- 跨版本字节一致保证。

测试应验证必要语义和敏感字段缺失，而不是除非项目明确冻结，否则把全部标点格式当永久协议。

## 26. DeviceId 的安全 toString

~~~java
@Override
public String toString() {
    return "DeviceId[tenant=<redacted>, value=" + value + "]";
}
~~~

它保留类型和值以便定位，隐藏完整 tenantId。若 value 本身也敏感，则只显示安全尾部或不可逆指纹；脱敏规则必须来自数据分类，不是随意保留前三位。

不要先拼完整对象再用字符串 replace secret；遗漏编码、大小写或多字段时会泄露。直接只构造允许出现的字段更安全。

## 27. toString 与日志

字符串一旦生成，可能进入控制台、异常、日志聚合、监控或外部工单。即使当前代码只调试，未来的字符串拼接会隐式调用 toString：

~~~java
System.out.println("device=" + deviceId);
~~~

因此 toString 是安全边界的一部分。绝不输出密码、token、会话、完整手机号、私密备注或跨租户内部标识。日志还应防止未处理换行制造伪造行；输入在构造边界规范化，输出只包含安全值。

## 28. toString 不应抛异常或改变状态

调试和异常处理经常在系统已经失败时调用 toString。若它访问远程服务、延迟加载资源、修改计数或对可空字段直接解引用，会掩盖原始故障。

保持 toString 本地、快速、无副作用；即使对象处于允许的边界状态，也应返回非 null 可读文本。不要 catch 后返回敏感完整序列化作为“兜底”。

## 29. equals 也不应有副作用

equals 不应递增“比较次数”、写日志、修正字段或触发网络。调用者可能多次比较且不承诺次数；副作用会让一致性、性能和调试都失控。

它也不应抛出“比较对象类型错误”异常；异类和 null 按契约返回 false。真正非法的是 DeviceId 自身构造状态，应在构造器拒绝，不在 equals 临时修复。

## 30. 继承如何破坏对称性

~~~java
class DeviceCode {
    final String value;
    public boolean equals(Object other) {
        return other instanceof DeviceCode code && value.equals(code.value);
    }
}

class TenantDeviceCode extends DeviceCode {
    final String tenant;
    // 还要求 tenant 相同
}
~~~

父实例可能只看 value 而认为子实例相等；子实例要求 tenant 又认为父实例不等。修复方向通常是让值类 final，或用组合把 tenant + code 定义为另一个独立值，而不是在可继承相等层次持续加字段。

## 31. equals 重载故障

~~~java
boolean equals(DeviceId other) {
    return value.equals(other.value);
}
~~~

这不覆盖 Object.equals。若写 `DeviceId a,b; a.equals(b)`，编译器可能选这个重载并返回 true；若写 `Object x=a, y=b; x.equals(y)`，执行默认身份 equals 返回 false。故障证据是同一对象对在不同静态类型调用下结果不一致。

添加 `@Override` 会让编译器直接指出签名。正确方法接受 Object 并自行做类型检查。

## 32. 错误强转故障

~~~java
@Override
public boolean equals(Object other) {
    DeviceId candidate = (DeviceId) other;
    return value.equals(candidate.value);
}
~~~

`a.equals("DEV-001")` 抛 ClassCastException，`a.equals(null)` 后续可能 NPE，都违反 equals 对异类/null 的预期。先身份、再类型检查、再读字段；不要 catch ClassCastException 后继续比较字符串。

## 33. 数组字段的比较与哈希

数组继承 Object 的身份 equals/hashCode。若 DeviceId 含 byte[] 并希望按内容相等，直接 `array.equals` 不够；需要 `Arrays.equals` 与对应 `Arrays.hashCode`，还要输入/输出复制阻断可变别名。

这与上一章 record 数组陷阱一致。L1 的 DeviceId 使用非 null String，避免把数组、深对象图和循环引用引入基础契约。遇到数组时先列出内容语义和不可变边界，再同步实现比较与哈希。

## 34. record、enum 与 Object 契约

record 自动生成基于组件的 equals/hashCode/toString，因此简单不可变组件值常无需手写；组件本身的相等语义仍决定结果，数组仍按身份。默认 record toString 会展示组件，敏感数据仍可能泄露。

enum 的 equals/hashCode 来自 Enum 并是 final，常量以唯一实例表示，通常用 `==`。不要复制 enum 经验到普通类。理解 Object 契约能解释这些受限类型为什么表现不同。

## 35. Objects 工具类的范围

`Objects.equals(a,b)` 能安全处理两个可能 null 的引用：都 null 为 true，一个 null 为 false，否则调用第一个对象 equals。`Objects.hash(...)` 可组合字段哈希；`Objects.hashCode(o)` 对 null 返回零。

工具减少样板，不决定业务字段，也不能修复不对称 equals。使用前仍需写契约表和直接断言。本章核心实现手写两字段逻辑，便于看见每个决定。

## 36. 相等不是排序

equals 定义等价关系，不回答“小于、先后、优先级”。`Comparable.compareTo` 与 `Comparator` 属于排序契约，在卷 03 专章学习。不要用 hashCode 大小排序，也不要把 toString 字典序当默认业务顺序。

未来若一个类型同时实现 Comparable，需要明确 `compareTo(a,b)==0` 是否与 equals 一致；不一致可能让有序结构产生意外。本章只冻结相等，不提前实现排序。

## 37. 哈希不是安全摘要

hashCode 只有 int，不抗碰撞，不用于密码、签名、租户隔离或防篡改。攻击者可能构造碰撞，运行时也不保证跨执行稳定。需要安全摘要或签名时使用安全章节规定的算法和密钥管理，不能复用对象 hash。

同样，`Integer.toHexString(hashCode())` 看起来像十六进制标识，也不应暴露为外部追踪 ID。

## 38. FactoryCare DeviceId 模型

~~~java
public final class DeviceId {
    private final String tenantId;
    private final String value;

    public DeviceId(String tenantId, String value) {
        this.tenantId = requireText(tenantId, "tenantId");
        this.value = requireText(value, "value");
    }

    // equals/hashCode 使用 tenantId + value
    // toString 只输出 value，tenant 脱敏
}
~~~

两个租户同 code 不是同一 DeviceId；同租户同 code 的不同实例值相等。字段 final 且 String 不可变，让契约稳定。真实格式校验、UUID 和数据库映射在业务值章节展开。

## 39. 多租户为何必须参与相等

若 equals 只比较 `DEV-001`，TENANT-A 与 TENANT-B 的设备 ID 会被误判相等；即使本章不使用集合，直接断言已经能暴露：

~~~java
check(!tenantA.equals(tenantB), "tenant scopes identity");
~~~

hashCode 同样包含 tenant。toString 却不应明文输出 tenant，这是“相等字段”和“日志字段”集合不同的正常例子。

## 40. 直接 oracle：身份与值

构造 a、b 同值，c 同值，otherTenant 不同 tenant，otherCode 不同 code。断言：

- `a != b`；
- a equals b；
- 自反；
- a/b 对称；
- a/b/c 传递；
- 重复调用一致；
- a 不等 null、String、otherTenant、otherCode；
- equal a/b/c hash 相同。

这些都直接观察方法契约，不依赖任何容器副作用。

## 41. 直接 oracle：toString 脱敏

固定 tenant `TENANT-SECRET-42` 与 value `DEV-001`，断言：

- 结果非 null；
- 包含 `DeviceId`，便于辨认类型；
- 包含安全 value；
- 不包含完整 tenant；
- 不包含 token/password/secret 字段；
- 多次调用相同且不修改对象。

测试错误输出时也不要把真实秘密写入 fixture。本仓只用虚构 canary，并用 `contains` 检查它没有泄漏。

## 42. 不要把具体 hash 整数冻成协议

可以对手写公式用固定字段手算以验证实现，但章节验收更重要的是相等对象同 hash、重复稳定、字段变更符合相等定义。若把某个 `-1837291` 写进外部 API 快照，重构合法公式也会造成伪兼容压力。

本章验证器精确比较摘要输出，不把 hash 数字打印为业务数据；故障 fixture 使用刻意不同 version 字段制造确定性不一致。

## 43. 故障定位顺序

遇到契约失败：

1. 保存 JDK 版本、命令、退出码、expected/actual；
2. 列两个对象的运行时类、身份比较和安全字段摘要；
3. 逐项跑自反、对称、传递、null、异类；
4. 列 equals 使用字段；
5. 列 hashCode 使用字段，做集合差异；
6. 确认比较字段是否被修改；
7. 搜索 equals 是否签名重载或错误强转；
8. 检查 toString 只允许字段白名单；
9. 修复后复跑所有 oracle，而非只改失败一行。

不要先把失败对象完整 toString 打进日志，因为 toString 本身可能正是泄漏根因。

## 44. 对称失败怎么读

记录四个值：`leftClass`、`rightClass`、`left.equals(right)`、`right.equals(left)`。若结果 true/false，查看父子类型检查与额外字段。若两类无继承却跨类型相等，检查是否 equals 接受 String 或接口并忽略另一方契约。

修复后至少加入父/子与同类三组用例。对值对象，final + 组合通常比允许继承更容易长期维护。

## 45. hash 不一致怎么读

先确认 `left.equals(right)` 真为 true，再打印两个 hash 作为诊断证据；不要因为数字不同就立即换算法。比较两段源码/生成配置使用的字段与顺序，确认 null 处理和数组方法一致。

若 equals 忽略 tenant 而 hash 包含 tenant，可能 equals 本身才错。领域定义优先于“让测试变绿”的最小改动。

## 46. 泄漏故障怎么读

对 toString 使用虚构 canary，例如 `TENANT-SECRET-42`。失败消息只报告“contains protected tenant=true”，必要时显示字段名，不再复制完整 secret。定位拼接、自动 record toString、嵌套对象 toString 和异常包装路径。

修复采用输出白名单：类型 + 安全 value + `<redacted>`。再搜索日志是否有手工 getter 拼接绕过 toString。

## 47. 安全与隐私清单

- equals/hashCode 不调用外部系统，不读取当前用户；
- hashCode 不作安全摘要或权限键；
- toString 不输出 token、密码、手机号、完整 tenant、私密正文；
- 异常信息不包含完整对象快照；
- 测试 canary 为虚构值；
- 值对象构造拒绝控制字符或按协议规范化；
- 记录运行时类时不依赖类名做授权；
- 跨租户字段参与业务相等，但可从调试表示中隐藏。

通过这些检查仍不代表完成全系统安全评审；这里只验证对象直接契约。

## 48. 性能取舍

equals/hashCode 可能被频繁调用，应保持本地、确定、与对象规模相称。不要每次序列化完整对象、排序大数组或请求数据库。不可变值可考虑缓存昂贵 hash，但两字段 String 的计算很小，缓存会增加状态与复杂度，先用真实剖析证明需要。

toString 也不应构建巨大图或递归循环引用。调试表示简洁比“打印所有字段”更可靠。

## 49. 与 TypeScript / JavaScript 对照

JavaScript/TypeScript 中两个普通对象使用 `===` 通常按引用身份比较，即使属性相同也为 false；类型接口是编译期结构，不自动生成运行时 equals。开发者常用深比较库或手工键，语义取决于实现。

Java 把 `equals(Object)` 作为 Object 可覆盖契约，并把 hashCode 与之绑定。不要用 `JSON.stringify` 思路实现 Java equals：字段顺序、非业务字段、循环引用和敏感值都会出问题。

TypeScript readonly 与 Java final 类似只解决部分可变性；嵌套数组仍需边界设计。record 的生成相等也只尊重组件自身契约。

## 50. 预测题

先写答案再执行：

1. 两个不同 new 的 DeviceId，`==` 与 equals 能否分别 false/true？
2. 未覆盖 equals 时默认比较什么？
3. `equals(DeviceId)` 是否覆盖 Object.equals？
4. `x.equals(null)` 应返回什么？
5. 父 equals 接受子类、子 equals 要求额外字段，会破坏哪条？
6. equal 对象 hash 必须相同吗？反过来成立吗？
7. hashCode 是否跨 JVM 启动稳定？
8. 所有对象 hash 返回 1 是否违反 equal->same？为何仍糟糕？
9. 默认 toString 尾部是可靠内存地址吗？
10. toString 能否作为 JSON 协议？
11. tenant 参与 equals 是否也必须明文出现在 toString？
12. equals 与 compareTo 是同一契约吗？

## 51. 动手与故障训练

### 51.1 最小构建

写 final DeviceId，构造器拒绝空 tenant/value。实现 equals/hashCode/toString；构造 a/b/c/otherTenant/otherCode，完成至少十六个直接断言。

### 51.2 字段错配

让 equals 只比较 value、hash 包含 tenant，固定两个不同 tenant 同 code 对象，保存 equal=true、hash 不同故障。决定正确业务相等后同步修复两方法。

### 51.3 重载故障

临时把 equals 参数改成 DeviceId 并去掉 Override；分别通过 DeviceId 与 Object 静态类型调用，观察结果差异。恢复 Object 签名和注解。

### 51.4 泄漏故障

让 toString 拼入 `TENANT-SECRET-42`，验证器必须非零。改为安全白名单，断言类型和值可定位、tenant 不出现。

### 51.5 需求变更

新增 region 组件。先决定它是否属于 DeviceId 业务值：若是，同步 equals/hash/构造 oracle；若只为显示，不应塞进 ID。写出迁移成本与回滚，不用 IDE 全选字段代替决定。

## 52. 无 AI 独立训练

限时 90 分钟：

1. 从空目录实现不可变 DeviceId；
2. 写 identity 与 value equality 预测；
3. 覆盖 equals 正确签名；
4. 覆盖 hashCode 相同字段；
5. 写脱敏 toString；
6. 构造自反、对称、传递、一致、null、异类 oracle；
7. 制造 equals/hash 字段错配；
8. 制造 equals 重载而非重写；
9. 制造父子不对称；
10. 制造 toString canary 泄漏；
11. 修复并完整复跑；
12. 120 秒复述直接契约。

允许查看 Object/Objects API、JLS 与 javac 帮助，不允许 AI 直接生成最终类。提交源码、命令、预测、断言计数、四类非零失败、修复输出和复述提纲。

## 53. 高频误区

1. **“== 会比较所有字段。”** 引用类型的 == 比较引用身份。
2. **“默认 equals 会比较字段。”** Object 默认等价于身份相等。
3. **“所有类都必须覆盖 equals。”** 只有明确逻辑相等时才覆盖。
4. **“IDE 选所有字段就是业务相等。”** 字段集合必须由领域决定。
5. **“equals(DeviceId) 已经重写。”** 正确参数是 Object。
6. **“删除 Override 可修复编译。”** 这会掩盖重载错误。
7. **“equals 可以对异类抛异常。”** 应安全返回 false。
8. **“equal 对象 hash 可以不同。”** 这是直接契约违反。
9. **“hash 相同就 equal。”** 碰撞允许，反方向不成立。
10. **“hashCode 是唯一 ID。”** 它只有 int 且可碰撞。
11. **“hashCode 是安全哈希。”** 它不抗碰撞、不用于安全。
12. **“不等对象必须 hash 不同。”** 契约不要求，测试也不应要求。
13. **“所有 hash 返回常数就完美。”** 可能勉强正确但性能与设计糟糕。
14. **“可变状态加入 equals 更完整。”** 它会让逻辑值随生命周期漂移。
15. **“toString 是序列化格式。”** 它是人读调试表示，格式可变化。
16. **“默认 toString 打印内存地址。”** 规范形式基于类名和 hashCode，不承诺地址。
17. **“record toString 自动安全。”** 组件可能被完整打印。
18. **“tenant 参与 equals 就必须打印。”** 相等字段与日志字段集合可不同。
19. **“equals 定义排序。”** 排序是 Comparable/Comparator 的独立契约。
20. **“容器测试绿就证明契约。”** 本章要求直接逐条 oracle。

## 54. 120 秒复述模板

“所有普通对象最终有 Object 的 equals、hashCode、toString。引用 == 判断是否同一对象；默认 equals 也是身份语义，值类可覆盖逻辑相等。equals 必须自反、对称、传递，在比较信息不变时一致，并对 null 返回 false。正确签名是 public equals(Object)，异类先返回 false。hashCode 必须保证 equal 对象同 hash，同 hash 不保证 equal；计算字段要与 equals 一致，且不把 hash 当 ID 或安全摘要。toString 返回非 null、简洁可读调试表示，但不是序列化协议；FactoryCare DeviceId 的 tenant 和 value 参与相等/hash，toString 只显示安全 value 并把 tenant 脱敏。所有结论用直接断言，不靠 Set/Map 间接猜。”

## 55. 间隔复习

- 当天：画 `a == b` 与 `a.equals(b)` 两条不同问题；
- 第 2 天：闭卷写 final DeviceId 和五条 equals oracle；
- 第 7 天：复现字段错配、重载和泄漏三个故障；
- 第 14 天：分析一个实体的可变字段为何不应加入相等；
- 第 30 天：审查 FactoryCare 三个值/实体，分别写相等字段与日志白名单。

每次先预测 expected/actual，再执行；记录一条误区、一条可复用规则和下次复习日期。

## 56. 一页速查

| 问题 | 最小结论 |
| --- | --- |
| Object | 普通类继承链根，提供默认对象契约 |
| 引用 `==` | 是否指向同一对象或同为 null |
| 默认 equals | 身份相等 |
| 值 equals | 类型作者定义逻辑等价 |
| 正确签名 | `public boolean equals(Object other)` |
| 自反 | `x.equals(x)` 为 true |
| 对称 | x=y 当且仅当 y=x |
| 传递 | x=y 且 y=z，则 x=z |
| 一致 | 比较信息不变时结果稳定 |
| null | 非 null x 对 null 返回 false |
| 异类 | 通常返回 false，不强转崩溃 |
| hash 关键方向 | equal -> same hash |
| hash 反方向 | same hash 不推出 equal |
| hash 稳定 | 同次执行且比较信息不变时稳定 |
| hash 用途边界 | 不是 ID、地址、排序或安全摘要 |
| toString | 非 null、简洁、有信息的人读表示 |
| 默认 toString | 类名 + @ + hashCode 十六进制 |
| 安全表示 | 只输出白名单字段，敏感值脱敏 |
| 值类建议 | final + 不可变字段简化契约 |
| 直接验证 | 五条 equals + equal hash + 安全 toString |

## 57. 术语表

- **对象身份**：一个对象区别于其他对象的引用身份。
- **引用相等**：两个引用值指向同一对象，使用 == 判断。
- **逻辑相等**：类型依据业务值定义的 equals 关系。
- **等价关系**：满足自反、对称和传递的关系。
- **自反性**：任何非 null 对象与自身相等。
- **对称性**：x 对 y 的相等结果与 y 对 x 相同。
- **传递性**：x=y、y=z 推出 x=z。
- **一致性**：比较信息未变时重复结果稳定。
- **相等字段**：决定对象逻辑等价的字段集合。
- **哈希码**：对象依据契约产生的 int 摘要值。
- **哈希碰撞**：不相等对象产生同一 hashCode。
- **身份哈希**：与对象身份相关的哈希视角，不等于业务值哈希。
- **调试表示**：面向人的简洁对象文本，不是序列化协议。
- **脱敏**：隐藏或变换受保护值，仅保留允许观察的信息。
- **输出白名单**：只拼接经明确允许的字段，而非先输出全部再删除。
- **重载误判**：写 equals(具体类型) 而未覆盖 equals(Object)。
- **契约 oracle**：直接计算 expected/actual 并在偏差时失败的断言。
- **排序契约**：Comparable/Comparator 定义的顺序关系，与 equals 分开。

## 58. 本章边界与官方来源

本章要求理解 Object 默认契约、引用身份与值相等；为 final 不可变 DeviceId 正确实现 equals(Object)、hashCode、脱敏 toString；直接验证自反、对称、传递、一致、null、异类和 equal hash；诊断字段错配、重载、继承不对称、错误强转与敏感泄漏。Set/Map、哈希表实现、Comparable/Comparator 排序、持久化代理、深对象图、浮点/BigDecimal 特例和安全密码摘要不在本章展开。

以下一手资料已于 **2026-07-16** 按 Java SE 25 / JDK 25 复核：

- [Object API, Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Object.html)：equals 五条关系、hashCode 一致性与 toString 表示契约。
- [Objects API, Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Objects.html)：null-safe equals、hashCode 与 hash 工具边界。
- [JLS 25 §4.3.1 Objects](https://docs.oracle.com/javase/specs/jls/se25/html/jls-4.html#jls-4.3.1)：对象、引用与身份定位。
- [JLS 25 §4.3.2 The Class Object](https://docs.oracle.com/javase/specs/jls/se25/html/jls-4.html#jls-4.3.2)：Object 作为类层次根。
- [JLS 25 §15.21.3 Reference Equality Operators](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.21.3)：引用 `==` / `!=` 语义。
- [JLS 25 §8.4.8.1 Overriding](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.4.8.1)：equals(Object) 重写关系。
- [Override API, Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Override.html)：编译器核验重写意图。
- [System.identityHashCode API, Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/System.html#identityHashCode(java.lang.Object))：身份哈希诊断边界。
- [String API, Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/String.html)：String 内容相等与不可变字符序列契约。
- [OpenJDK JDK 25 Project](https://openjdk.org/projects/jdk/25/)：JDK 25 参考实现与 GA 信息。
- [javac 25 Tool Guide](https://docs.oracle.com/en/java/javase/25/docs/specs/man/javac.html)：`--release 25` 与编译诊断入口。

稳定核心是：身份与逻辑相等分开；equals 定义等价关系，hashCode 保持 equal 对象同值，toString 提供安全人读表示。具体 hash 整数、默认表示文本、JVM 对象布局与优化策略不应成为业务协议，验证器只登记直接契约和本基线可观察故障。
