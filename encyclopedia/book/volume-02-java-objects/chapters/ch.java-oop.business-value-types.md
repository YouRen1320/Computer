---
schema_version: 2
edition: 2026.2-draft
id: ch.java-oop.business-value-types
title: 正则、BigDecimal、日期时间、UUID 与业务值
responsibility: 用标准值类型表达格式、金额、时间和标识边界，不在本章设计实体生命周期或数据库映射
volume: '02'
order: 11
level: L1
status: drafting
path: book/volume-02-java-objects/chapters/ch.java-oop.business-value-types.md
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
  text: 在 120 秒内解释正则、BigDecimal、日期时间、UUID 与业务值的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-text-money-values
  - java-time-id-values
  covers_topics:
  - java.regex-validation
  - java.bigdecimal-money
  - java.rounding-scale
  - java.java-time
  - java.timezone-instant
  - java.uuid
  uses_capabilities:
  - java.values-types-string
  - java.encapsulation-immutability
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现 Money、WorkOrderId 和 ServiceTime 值类型，分别使用 BigDecimal、UUID、Instant/ZoneId 与正则格式校验
  covers_topic_groups:
  - java-text-money-values
  - java-time-id-values
  covers_topics:
  - java.regex-validation
  - java.bigdecimal-money
  - java.rounding-scale
  - java.java-time
  - java.timezone-instant
  - java.uuid
  uses_capabilities:
  - java.values-types-string
  - java.encapsulation-immutability
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入 double 金额误差、默认时区漂移、BigDecimal equals 尺度误判和宽松正则，逐项修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - java-text-money-values
  - java-time-id-values
  covers_topics:
  - java.regex-validation
  - java.bigdecimal-money
  - java.rounding-scale
  - java.java-time
  - java.timezone-instant
  - java.uuid
  uses_capabilities:
  - java.values-types-string
  - java.encapsulation-immutability
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 正则、BigDecimal、日期时间、UUID 与业务值

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《final、常量与不可变对象》](ch.java-oop.final-immutability.md)：独立完成文本与金额值、时间与标识值前，必须先具备「final、常量与不可变对象」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文与工件可以用于学习和作者验证，但不会证明学习者已经独立完成构建、诊断和复述，也不会自动更新 `PROGRESS.md`。

字符串、数字和日期看似足以承载所有输入：工单号可以是 `String`，金额可以是 `double`，预约时间可以是 `LocalDateTime`。问题是这些通用类型允许表达太多无效状态。空字符串也能冒充工单号；`double` 的二进制近似会进入十进制金额；没有时区的本地时间无法唯一定位时间线上的一刻。业务值类型把“数据长什么样、怎样比较、哪些值绝不允许存在”集中在一个不可变边界中。

本章使用 Java 25 标准库的 `Pattern`、`BigDecimal`、`RoundingMode`、`java.time` 与 `UUID`，实现 `Money`、`WorkOrderId` 和 `ServiceTime`。它不设计设备或工单的身份生命周期，不讨论数据库列、ORM 转换、分布式 ID 服务或完整状态机。稳定概念与 JDK 25 API 已于 **2026-07-16** 按一手资料复核。

## 1. 本章完成证据

学习完成不是“看懂三段代码”，而是留下三组可重放证据：

1. **解释**：120 秒内说明为什么正则只能验证形式、为什么金额不能把舍入留给调用者、为什么 `Instant` 与 `LocalDateTime` 不是同类事实，以及 UUID 为什么不等于授权令牌。
2. **构建**：实现不可变的 Money、WorkOrderId、ServiceTime；正常值、边界值和非法值都有直接断言，输出固定而不依赖机器默认时区。
3. **诊断**：真实复现 `new BigDecimal(double)` 尾数、`equals` 的尺度误判、默认时区漂移和宽松正则误收；从第一条 expected/actual 证据修复并复跑。

配套工件：

- [业务值观察台](../../../examples/encyclopedia/ch.java-oop.business-value-types/README.md)
- [Money、WorkOrderId 与 ServiceTime 实验](../../../labs/encyclopedia/ch.java-oop.business-value-types/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-oop.business-value-types/README.md)

## 2. 从原始值到业务值

原始值回答“它在内存中是什么类型”，业务值回答“它在这个领域中代表什么”。`String` 可以同时表示租户号、工单号、备注和密钥，但这些值的合法字符、长度、脱敏方式和相等边界完全不同。把它们都作为 String 传递，编译器无法阻止参数位置颠倒，也无法保证每个入口执行同一套校验。

业务值通常具备四个性质：构造后不变；创建时建立不变量；相等由全部业务组成部分定义；公开行为使用领域词汇。`Money.add` 比散落的 `amount.add` 更容易固定币种规则，`WorkOrderId.parse` 比每个控制器各写一次正则更容易保持一致，`ServiceTime.atZone` 比任意读取系统默认时区更可预测。

## 3. 值对象不是实体

值对象靠内容区分，实体靠持续身份区分。两个金额同为 CNY 10.00 时可以互换；两张不同工单即使标题、金额和创建时间相同，仍是不同实体。`WorkOrderId` 本身是一个值，它指向的工单才是实体。不要因为类名里有 Id 就把 ID 包装类做成拥有状态和生命周期的聚合。

本章的值类型也不决定持久化策略。是存 UUID 原生列、字符列还是二进制列，是把金额拆成数值与币种两列还是使用复合类型，都属于数据库和映射契约。先把内存中的语义说清，再在后续章节选择映射，能避免让某个数据库细节污染基础语言模型。

## 4. 不变量：对象永远为真之事

不变量不是“页面提示最好这样”，而是任何成功构造的实例都必须满足的条件。例如 Money 的币种不为空、金额尺度固定且在允许范围内；WorkOrderId 必须有固定前缀和规范 UUID；ServiceTime 的 `Instant` 与 `ZoneId` 都存在。若对象能先以非法状态存在、稍后再由调用者补救，它就没有真正封装边界。

创建失败应立即、明确且一致。公开解析方法可以把底层 `NumberFormatException` 或 `DateTimeException` 转换为带字段语义的 `IllegalArgumentException`，但不能吞掉错误后生成零金额、随机 ID 或当前时间。静默兜底会把输入错误改写成另一条看似成功的业务事实。

## 5. 工厂方法与构造器的选择

构造器适合一种显而易见的创建语义；命名工厂适合多种输入或需要突出政策的情形。`Money.of("10.25", "CNY")` 表达从十进制文本创建，`Money.ofMinor(1025, "CNY")` 表达从最小货币单位创建，两者不应共用一个含义模糊的数值参数。`WorkOrderId.parse` 表明输入来自外部文本，`WorkOrderId.of(UUID)` 表明 UUID 已由上游建立。

工厂方法也便于规范化：去除允许的外围空白、统一币种大写、输出 UUID 小写。规范化必须是契约的一部分，不能随意“猜用户意思”。工单号内部多一个空格、破折号位置错误或币种拼错时，应拒绝而不是删掉字符后悄悄接受。

## 6. 正则表达式的职责

正则表达式描述字符序列的形式约束，适合“固定前缀 + 固定分组 + 有限字符集”这类问题。它能判断 `WO-550e8400-e29b-41d4-a716-446655440000` 是否具有目标外形，却不能证明该 UUID 对应真实工单、属于当前租户、尚未被删除或允许当前用户访问。形式验证与业务存在性、权限验证必须分层。

把正则编译为 `static final Pattern` 可以让意图集中，也避免每次调用重复编译。名称应表达用途，例如 `WORK_ORDER_ID_TEXT`，而不是 `P1`。复杂表达式要拆解说明每个分组，测试合法、边界与近似非法输入，不能只测一个“看起来正确”的样本。

## 7. `matches` 与 `find` 不是同一问题

`Matcher.matches()` 要求整个输入匹配，`find()` 只寻找任意子串。验证一个完整标识时使用 `find()`，会让 `prefix-WO-...-suffix` 因内部含有合法片段而通过。`String.matches` 也做整串匹配，但每次调用都会处理表达式；共享规则更适合预编译 Pattern 后调用 `matcher(input).matches()`。

锚点 `^` 与 `$` 能强调从头到尾，但在 Java 不同匹配模式和行终止符语义下仍需理解。完整值验证优先依赖 `matches()` 的整串语义，再用清晰的字符类描述内容。不要把“加了锚点”当成已覆盖空白、Unicode 或长度攻击。

## 8. Java 字符串中的双重转义

正则语法和 Java 字符串字面量各解析一次反斜杠。正则中的 `\d` 写入 Java 源码时通常是 `"\\d"`；匹配字面点号的正则 `\.` 在字符串中是 `"\\."`。初学者常把编译通过误认为表达式正确，实际却匹配了不同字符。

对固定文本片段，可以用 `Pattern.quote` 而不是手工逐个转义。对动态规则，不要直接把不可信输入拼进正则；即便转义正确，攻击者仍可能放大匹配耗时或改变规则含义。规则应由程序拥有，数据只作为待匹配文本。

## 9. 字符类、长度与规范形式

业务标识应明确字符集。若协议要求 ASCII 十六进制，就写 `[0-9a-f]` 并在解析后统一小写，而不是宽泛的 `\w`；后者还包含下划线，并可能与预期的国际字符范围不一致。长度也是边界：先限制输入总长度，再执行复杂匹配，可减少误收和资源消耗。

“人眼相似”不代表码点相同。全角字母、组合字符、不可见空白可能绕过基于视觉的判断。是否做 Unicode 规范化必须由协议决定。机器标识通常直接限定 ASCII 并拒绝其他字符；人员姓名等自然语言数据则不能沿用这种粗暴规则。

## 10. 宽松正则反例

表达式 `WO-.*` 只证明字符串以 `WO-` 开头，空后缀、任意空格甚至控制字符都可能进入系统。表达式 `[0-9a-f-]+` 没有固定破折号位置，也会接受多个连续破折号。一个可靠的工单 ID 外形规则应写出 8-4-4-4-12 的每组长度，再交给 `UUID.fromString` 做语义解析。

验证器必须包含“几乎正确”的反例：缺一位、前缀小写、破折号错位、尾随字符、非十六进制字符、全空白和超长输入。只有成功样本无法说明规则拒绝能力；只测试明显乱码，也无法揭露过宽表达式。

## 11. 正则不是解析器万能替代品

日期、数字和 UUID 已有标准解析器时，正则最多做协议外形的第一道门，不应重写完整语法。正则能接受 `2026-02-31` 的形状，却不能让不存在的日期合法；`LocalDate.parse` 才理解日历规则。金额正则也不能处理精度、舍入和数值上限，仍需 BigDecimal 与领域不变量。

同样，不要用一个巨大正则同时承担提取、校验、权限和错误消息。将步骤分成长度/字符外形、标准解析、业务范围三层，失败时才能指出第一处可信原因，也便于针对每层写测试。

## 12. 正则性能与拒绝服务边界

某些包含嵌套量词和大量回溯路径的表达式，在恶意长输入上可能消耗极长 CPU 时间。业务输入即使通常很短，也应先设长度上限，避免如 `(a+)+` 一类不必要结构，并用接近上限的失败样本做性能观察。不能仅凭表达式短就断言安全。

本章的 UUID 格式可以用固定长度字符类完成，不需要回溯技巧。正则引擎的高级构造不是目标；目标是选择最简单、可审核、失败范围明确的规则。网络层超时和限流是另一层防线，不能替代安全的表达式本身。

## 13. 为什么金额不用 `double`

`double` 使用二进制浮点表示，许多十进制小数无法精确表示。`0.1 + 0.2` 的内部结果通常不是精确十进制 `0.3`。科学计算常接受可量化误差，业务金额却需要可声明的十进制精度、尺度与舍入政策；因此使用不可变的 BigDecimal。

问题不只是最终显示多几位。若中间计算、阈值比较、税费分摊或累计已经基于近似值，最后格式化为两位小数只能遮住证据，不能恢复丢失的十进制语义。金额边界应从输入开始保持十进制。

## 14. 安全构造 BigDecimal

来自 JSON、表单或配置的十进制金额，优先保留原始十进制文本并调用 `new BigDecimal(String)`。整数最小单位可以调用 `BigDecimal.valueOf(long, scale)`。已有 double 且无法改变上游时，`BigDecimal.valueOf(double)` 通常比 `new BigDecimal(double)` 更接近其十进制字符串表现，但它不能证明原始业务值未在更早阶段丢失精度。

`new BigDecimal(0.1)` 会精确捕获那个 double 的二进制近似，产生很长小数；这不是 BigDecimal 自己算错，而是构造输入已经不是十进制 0.1。故障 oracle 应打印实际 `toPlainString()`，让第一处类型转换清楚可见。

## 15. unscaled value、scale 与 precision

BigDecimal 可以理解为“任意精度整数 × 10 的负 scale 次方”。`12.30` 的 unscaled value 是 1230，scale 是 2；precision 是有效数字个数 4。scale 不是“允许的最大两位小数”这一业务规则，而是对象当前表示的一部分。

`setScale(2, mode)` 返回新对象，不会修改原对象。降低尺度可能丢弃数字，所以必须提供舍入模式，或使用 `UNNECESSARY` 要求输入本来就能精确表示到目标尺度。忽略返回值是常见错误，因为 BigDecimal 与 java.time 类型一样不可变。

## 16. `equals` 与 `compareTo` 的差别

BigDecimal 的 `equals` 同时比较数值与 scale，因此 `2.0` 不 equals `2.00`；`compareTo` 做数值顺序比较，两者比较结果为 0。业务金额若规定统一 scale=2，可以在构造边界规范化后安全依赖 equals；若没有统一尺度，就不能用 BigDecimal 原始 equals 代表“金额数值相等”。

不要为了让测试通过就把所有比较改成 `compareTo == 0`。Money 还包含币种，CNY 2.00 与 USD 2.00 不相等。正确做法是先定义业务相等边界，再规范化组成字段，让 equals、hashCode 与显示规则一致。

## 17. 舍入是一条业务政策

`HALF_UP`、`HALF_EVEN`、`DOWN` 等模式对中点和正负值的处理不同。没有“金融场景统一选某一个”的语言级答案；税务、结算、展示与统计可能采用不同政策。代码必须在最靠近规则的位置写明模式，测试正数、负数、恰好中点和非中点。

若 API 接收的金额必须已经是两位小数，可以用 `setScale(2, UNNECESSARY)` 拒绝 `10.001`，避免偷偷改写客户输入。若某项费用计算允许产生更多小数，则在明确的结算步骤统一舍入。输入规范化和计算舍入是两个不同动作。

## 18. 除法为何经常抛异常

某些十进制除法没有有限小数表示，例如 1 除以 3。调用不带舍入上下文的 `divide` 会抛 `ArithmeticException`，这是提醒调用者缺少政策，而不是要求 catch 后返回零。应选择目标 scale 与 RoundingMode，或传入经业务确认的 MathContext。

分摊还会产生余数。把 10.00 平均分给三人得到 3.33 后仍剩 0.01，谁获得余数是领域规则，不能只靠 BigDecimal API 自动决定。基础值类型可提供精确运算，完整分摊策略留给领域服务。

## 19. 币种是金额的一部分

裸 BigDecimal 只表达十进制数，不表达单位。Money 至少包含 amount 和 currency；相加前必须检查币种一致，不能把 CNY 与 USD 直接相加。币种字符串可暂时使用固定三位大写格式，但“格式正确”不保证它是系统支持的真实币种；可再由白名单或 `Currency` 边界验证。

本章示例固定两位 scale 以保持练习可预测，并不宣称所有币种都是两位小数，也不处理汇率。真实系统应根据支持币种、合同和法规设计精度。跨币种转换需要汇率来源、时间点、舍入和审计，明显超出一个值对象的职责。

## 20. 金额范围与资源边界

BigDecimal 是任意精度，不代表应用应接受任意长度。数百万位数字会消耗内存与 CPU，极大正负 scale 也会制造异常输出。创建 Money 前应限制文本长度、整数位数和绝对值，并拒绝科学计数法还是允许它，都要写入外部契约。

`toPlainString` 能避免科学计数法，但对恶意巨大负 scale 的值可能生成非常长字符串。业务值在构造时建立合理上限，日志和序列化才有稳定成本。任意精度是能力，不是输入政策。

## 21. Money 的最小契约

一个入门 Money 可以声明：amount 非 null；currency 符合三位大写；amount 必须精确到两位；绝对值不超过约定上限；构造后不可变；同币种才能 add；equals 使用规范化 amount 与 currency；toString 输出固定的 `CNY 10.25`。是否允许负值应由使用语境决定。

退款金额与支付金额可能共享数值结构，却有不同符号不变量。与其让一个通用 Money 猜测所有场景，不如 Money 表达带币种的数值，再由 `ChargeAmount`、`RefundAmount` 或操作方法固定方向规则。不要把所有业务政策塞进一个基础类型。

## 22. 时间有多种不同事实

“2026-07-16 09:00”可能是日历上的本地时间、带固定偏移的时间、某地区时区规则下的时间，或时间线上的绝对瞬间。`java.time` 用不同类型迫使我们区分这些事实：LocalDate 只有日期；LocalTime 只有时刻；LocalDateTime 没有偏移和时区；OffsetDateTime 带偏移；ZonedDateTime 带地区规则；Instant 是 UTC 时间线上的点。

错误做法是看到类型多就统一成 String。字符串只能延迟问题，而且比较、计算、格式校验与夏令时规则会散落。先问业务问题需要“墙上显示的时间”还是“全局同一瞬间”，再选择类型。

## 23. `Instant`：跨系统事件时间

Instant 适合记录创建、接收、开始、结束等已经发生或确定的瞬间。两个地区看到的本地钟表值不同，只要转换自同一 Instant，它们仍代表同一事件。跨服务传输和持久化事件时间时，Instant 是清晰基线。

Instant 本身不包含用户地区语义。把它显示为南昌时间，需要显式 `ZoneId.of("Asia/Shanghai")`；显示为巴黎则使用相应 ZoneId。同一瞬间转换时区只改变表示，不改变时间线位置。测试应断言 Instant 相等，而不只比较格式化字符串。

## 24. `LocalDate` 与 `LocalDateTime`

LocalDate 适合生日、合同日、盘点日期等不要求一天中具体瞬间的事实。LocalDateTime 适合“当地钟表上的日期和时间”，但没有足够信息唯一转换为 Instant。直接调用 `atZone(ZoneId.systemDefault())` 会把机器配置偷偷写入业务结果。

若输入来自用户预约，应同时收集或从可信上下文确定地区 ZoneId。若协议已经给出 UTC 偏移，可解析 OffsetDateTime。不要拿服务器所在地区代替用户地区，也不要因为开发机和生产机暂时都在同一时区就省略契约。

## 25. ZoneId 与 ZoneOffset

ZoneOffset 如 `+08:00` 是某一时刻相对 UTC 的固定偏移；ZoneId 如 `Asia/Shanghai` 或 `Europe/Paris` 表示一组随历史和政策变化的地区规则。未来预约通常需要地区规则，因为届时偏移可能随夏令时或法规变化；已发生事件可保存 Instant，并按展示地区转换。

三个字母的短时区名容易歧义，优先使用 IANA 地区名或明确偏移。ZoneId 的规则数据会随 JDK 时区数据库更新，未来本地时间的解析可能受到政策变更影响；重要预约系统需要记录规则与重新计算策略，本章只建立显式 ZoneId 边界。

## 26. 默认时区漂移反例

同一 `LocalDateTime.of(2026, 7, 16, 9, 0)` 在 UTC 机器上转换为一个 Instant，在 Asia/Shanghai 机器上转换为另一个，相差八小时。若测试只在开发机运行，就可能把环境依赖当成正确。故障程序应在一次进程中显式切换默认时区，证明两个结果不同。

修复不是把默认时区硬编码为开发者所在地区，而是让 ZoneId 成为输入或配置依赖，并在 ServiceTime 中保存它。程序启动日志可以记录默认时区供诊断，但业务计算不应依赖它。

## 27. 夏令时缺口与重叠

某些地区春季调钟会跳过一段本地时间，形成 gap；秋季调回会让一段本地时间出现两次，形成 overlap。一个 LocalDateTime 加 ZoneId 并不总是一一对应一个 Instant。`atZone` 有默认解析策略，但关键预约不能在不了解策略的情况下默默接受。

应利用 `ZoneRules.getValidOffsets(localDateTime)` 检查：零个偏移表示不存在，一个表示明确，两个表示歧义。遇到 gap 是拒绝、顺延还是提示用户，遇到 overlap 选择较早还是较晚偏移，都应成为界面与领域契约。本章实验保留显式 ZoneId，并用固定非歧义时刻保持输出稳定。

## 28. `withZoneSameInstant` 与“同一墙上时间”

把 ZonedDateTime 转到另一时区时，`withZoneSameInstant` 保持 Instant 不变，本地钟表显示随地区变化；`withZoneSameLocal` 尝试保持本地字段，通常会改变实际瞬间。跨地区展示一个已确定事件应使用前者。后者只适用于业务明确要求“把 09:00 搬到另一个地区仍是当地 09:00”的特殊操作。

方法名很相似，测试必须同时断言 Instant 和 local time，不能只看其中一个。把这种选择藏在通用工具方法里，会让调用者不知自己改变了事实；命名应直接表达“保持瞬间”或“保持当地时间”。

## 29. 时间计算：Duration 与 Period

Duration 基于秒和纳秒，适合时间线上经过的时长；Period 基于年、月、日，适合日历运算。夏令时切换日的“明天同一当地时间”与“恰好 24 小时后”可能不同。ZonedDateTime 加一天和 Instant 加 24 小时回答的是不同问题。

SLA 若定义为连续经过的 4 小时，可在 Instant 上加 Duration；保养计划若定义为每月第一个工作日，需要日历规则。不要只因两个结果在普通日期相同，就把 Duration 与 Period 混用。

## 30. 当前时间是一项依赖

直接调用 `Instant.now()` 会让测试结果随运行时刻变化。业务方法需要“现在”时，接收 `Clock`，生产使用系统时钟，测试使用 `Clock.fixed`。这样超时、未来时间和边界条件都能确定性重放。

值对象通常只保存已经提供的时间，不主动读取现在。若 ServiceTime 构造器内部调用 now 判断是否未来，重放旧数据可能突然失败，也让构造承担易变政策。将“是否允许过去预约”放到具有 Clock 的领域服务更清晰。

## 31. ServiceTime 的职责

入门 ServiceTime 可以保存 `Instant scheduledAt` 与 `ZoneId displayZone`。scheduledAt 决定跨系统相等的瞬间，displayZone 决定用户如何观察。`localView()` 由 instant.atZone(zone) 计算，切换展示区域时保持同一 Instant。

如果业务关心用户最初输入的当地文本、解析时选定的偏移或时区规则版本，还需额外审计字段；本章不假装两个字段覆盖所有调度需求。值类型只承诺目前声明的不变量，不应暗含未实现的历史追踪。

## 32. UUID 是什么

UUID 是 128 位标识值，标准文本常写成 8-4-4-4-12 个十六进制字符。`UUID.randomUUID()` 生成随机型 UUID，`UUID.fromString` 解析文本。它非常适合在没有中心自增服务时生成低碰撞概率标识，但“概率极低”不是数学上的业务存在证明。

UUID 没有租户归属、实体类型、创建时间授权或防伪语义。知道一个 UUID 不等于有权访问对应对象；随机性也不应替代鉴权。日志、URL 和错误消息是否暴露标识，需要单独威胁建模。

## 33. UUID 的规范文本

外部契约应决定是否只接受小写规范形式，是否允许大写，是否带业务前缀。解析后调用 `toString()` 会得到规范连字符表示；可以用解析后再格式化进行规范化。为了拒绝 Java 解析器可能接受的非目标形式，先用固定长度正则约束，再调用 UUID.fromString。

不要只检查总长度 36 或破折号数量。每段必须是十六进制且位置固定。解析失败要报告字段与规则，不回显完整不可信输入，尤其不要在日志中复制超长或包含控制字符的数据。

## 34. WorkOrderId 的业务前缀

`WO-` 前缀让日志和人工沟通能快速区分标识类型，也能防止把 DeviceId 误传到只接受 WorkOrderId 的方法。强类型包装才是编译期保护，前缀只是外部文本协议和可读性，不应成为唯一类型检查。

WorkOrderId 可保存 UUID 字段，`parse` 接受 `WO-` 加规范 UUID，`toString` 固定输出相同形式，equals/hashCode 委托 UUID。构造后无需保存原始大小写或多余空白，因为它们不属于业务值。

## 35. 生成、解析与查找要分开

`newId()` 生成一个新标识，`parse(text)` 解析外部标识，仓储 `find(id)` 查询实体，这三件事不能混在一起。parse 成功只说明文本可表示 WorkOrderId，不说明数据库存在对应工单。把查找放进值对象会引入 I/O、生命周期和异常边界，破坏其小而确定的职责。

同样，解析失败不应自动生成新 UUID，否则输入拼写错误会创建或访问完全不同的对象。生成只由明确命令触发，失败输入保持失败。

## 36. 相等、哈希与规范化

业务值创建时完成规范化，equals 就可以比较规范字段。Money 把 amount 固定到 scale 2 并统一 currency；WorkOrderId 保存 UUID；ServiceTime 明确相等是否同时包含 displayZone。本章选择两个 ServiceTime 只有瞬间和展示区域都相同才完全相等，因为展示区域是已声明组成部分。

若业务只关心同一 Instant，应提供命名方法如 `sameMomentAs`，而不是偷偷让 equals 忽略 zone。equals 是通用对象契约，专门业务关系用显式方法更容易阅读。所有参与 equals 的字段也必须参与 hashCode。

## 37. 不可变并不等于不需验证

BigDecimal、UUID、Instant 和 ZoneId 自身不可变，但它们的任意组合仍可能违反业务规则。`null` BigDecimal、不支持币种、过大金额、错误前缀和不允许时区仍需在外层值类型拒绝。标准类型提供语言语义，不提供 FactoryCare 全部政策。

record 可以简化字段和 Object 方法，但规范构造器仍需校验和重赋规范化参数。record 自动 equals 会使用所有组件；若组件 BigDecimal 未先统一 scale，尺度差异也会进入 record 相等。语法简洁不会替你设计不变量。

## 38. 防御性边界与数组陷阱

本章选用的标准值类型都不可变，因此直接保存引用是安全的。若未来值对象加入 `byte[]` 或可变集合，就必须在构造和访问时复制，否则调用者可从外部改变对象状态，破坏哈希和不变量。不可变类声明 final 只是第一步。

不要把 `Collections.unmodifiableList` 当成深拷贝；底层列表或元素仍可能变化。值对象越靠近核心边界，越应优先组合真正不可变组件，减少防御复制和别名推理负担。

## 39. 错误消息与敏感信息

校验错误应说明字段、期望规则和可安全展示的摘要，例如 `workOrderId must match WO-<uuid>`，不要把完整令牌、租户秘密或任意长输入拼进消息。金额错误可报告允许 scale 与范围，时间错误可报告 ZoneId 或格式，但仍需控制外部文本。

`toString` 是调试表示，不是序列化格式。Money 可以安全显示币种和金额；WorkOrderId 是否完整显示取决于威胁模型；ServiceTime 可显示 Instant 与地区，但不应夹带用户隐私。公开 API 格式由明确序列化层承担。

## 40. FactoryCare 三种值的边界

FactoryCare 示例采用：Money 表示工单费用的十进制金额与币种；WorkOrderId 表示带 `WO-` 前缀的规范 UUID；ServiceTime 表示安排瞬间和展示地区。这三者都可以在无数据库、无网络的纯 Java 程序中构造和验证。

它们不判断工单状态能否变更、不检查当前用户权限、不生成账单、不查询时区服务、不保证标识存在。把这些非目标写出来，防止学习者看到“业务值”就提前构造大而全的领域聚合。

## 41. 建议实现顺序

先写一张契约表：输入类型、规范形式、不变量、相等字段、安全输出与失败类型。然后实现最小构造路径，先跑一个成功样本；再逐条增加边界断言。最后才加入运算方法。这样出现失败时，能定位是哪条规则，而不是在巨大类中猜测。

Money 先固定 scale/币种，再实现 add；WorkOrderId 先外形、再 UUID 解析；ServiceTime 先保存显式 Instant/ZoneId，再实现展示转换。每一步都保留 expected/actual，避免多个规则同时失败。

## 42. 失败一：double 污染

症状是 `new BigDecimal(0.1).toPlainString()` 出现长尾。第一处可信证据是 BigDecimal 构造结果，而不是最终账单总额。沿数据流向上追踪，找到文本何时被转换成 double；修复为保留十进制文本或最小单位整数，并复跑中点和累计样本。

若外部库只能给 double，应明确这是有损边界，记录转换政策和可接受误差。不要声称换成 `valueOf` 就恢复了从未保留的原始精度。

## 43. 失败二：尺度相等误判

症状是 `new BigDecimal("10.0").equals(new BigDecimal("10.00"))` 为 false，而业务认为金额相同。先打印 value、scale、compareTo 和 equals，确认不是数值差异。修复可在 Money 构造时统一 scale，再由 Money equals 比较规范字段。

另一种设计是允许不同 scale 并在 equals 中用 compareTo，但必须同步设计 hashCode；直接忽略 scale 而沿用 BigDecimal hashCode 会破坏相等哈希契约。入门实现选择构造规范化，规则更容易验证。

## 44. 失败三：默认时区漂移

症状是同一输入在 CI 与开发机生成不同 Instant。证据应同时打印 LocalDateTime、实际 ZoneId 和结果 Instant。看到 ZoneId.systemDefault 就能确认环境进入业务计算。修复为显式参数，并用 UTC 与 Asia/Shanghai 两个输入证明同一规则下结果可预测。

不要通过设置测试进程全局默认时区永久“修好”。全局设置会让测试相互影响，并掩盖生产配置。故障实验可短暂切换并在 finally 恢复，只为证明隐式依赖。

## 45. 失败四：宽松正则

症状是带尾随文本、错位破折号或空 UUID 的字符串被接收。第一条证据是具体非法输入与匹配结果。修复表达式后，还要调用标准 UUID 解析器，并把所有近似非法样本保留为回归测试。

不要只增加一个 if 针对刚出现的字符串。契约应概括合法语言，测试围绕边界生成。若表达式变得难以审核，拆成前缀、长度和 UUID 三步通常更可靠。

## 46. 失败五：舍入位置错误

每一步计算都先舍入可能累积偏差，全部留到最终一步又可能违反法规或合同。诊断需要画出计算阶段、每阶段精度和政策来源，比较逐步与最终舍入结果。语言 API 不知道正确答案，只有业务契约能决定。

测试至少包括恰好中点、略低和略高中点、正负数、多项累计。只测 `10.123 -> 10.12` 不足以区别多个模式，也不足以证明负数方向。

## 47. 失败六：UUID 被当成安全令牌

接口因 UUID 难猜就省略授权，是安全设计错误。攻击者可能从日志、链接、浏览器历史或其他接口获得 ID；即便完全随机，拥有标识也不代表拥有权限。值类型只保证格式和类型隔离，访问控制必须验证主体、租户与资源关系。

也不要把 UUID 版本或 variant 当成实体真实性证明。可在边界要求特定版本以满足生成政策，但仍需仓储存在性和授权检查。

## 48. 测试矩阵：Money

成功类包含整数、两位小数、零、允许的负值或正值边界、同币种相加；失败类包含 null、空币种、小写/未知币种、超过两位且不允许舍入、超范围和跨币种运算。若政策允许自动舍入，则用明确的中点样本验证模式。

相等测试要覆盖 `10.0` 与 `10.00` 经工厂后是否相等、相等哈希、不同币种不等。输出测试固定 locale 无关的格式，避免机器区域设置改变小数点或币种位置。

## 49. 测试矩阵：WorkOrderId

成功类包含一个固定规范 UUID，并验证 parse—format—parse 往返与相等哈希。失败类包含 null、空白、错误前缀、缺位、额外字符、非十六进制、错位破折号和超长输入。随机生成只能作为补充，固定样本才可重放。

不要在测试中只调用 `randomUUID` 后立刻解析自己的输出，那只能证明两个库方法兼容，无法验证外部错误输入。每个失败都应有明确退出码或断言标签。

## 50. 测试矩阵：ServiceTime

用固定 Instant 和两个 ZoneId，断言转换后的当地时间不同但 Instant 相同。用明确 LocalDateTime + ZoneId 构造，断言预期 UTC 结果。加入 null、非法 ZoneId、DST gap/overlap 检查或至少记录政策。

测试禁止依赖真实当前时间、系统默认时区和本地语言环境。若确需 now，注入 fixed Clock。确定性不是为了漂亮输出，而是为了任何机器都能重放同一业务事实。

## 51. 预测练习

运行前写下预测：`new BigDecimal("2.0").equals(new BigDecimal("2.00"))`、两者 compareTo、统一到 scale 2 后的 Money equals；同一 LocalDateTime 分别在 UTC 与 Asia/Shanghai 得到的 Instant 是否相同；合法 UUID 前后加文本后 `find` 与 `matches` 的结果。

预测后再执行，把差异写成一句规则。若只是复制输出，没有形成原因模型，下次遇到新数值或新时区仍会猜错。

## 52. 独立构建任务

不看参考实现，从空文件写出三个值类型。先写契约表，再实现：Money 从 String 创建并固定两位与币种；WorkOrderId 解析规范前缀 UUID；ServiceTime 从 Instant/ZoneId 创建并提供本地展示。主程序输出固定验证报告。

随后各修改一条需求：Money 改为拒绝负数；WorkOrderId 接受输入大写但输出小写；ServiceTime 增加 `sameMomentAs`。只能局部修改而不重写整个程序，才算能维护生成代码。

## 53. 故障诊断任务

依次运行四个反例，每次只处理一个：double 长尾、BigDecimal 尺度误判、默认时区漂移、宽松正则。记录命令、输入、expected、actual、第一条可信证据、根因、最小修复和复跑结果。不要在失败时同时改多个类。

追加一个自己设计的失败：跨币种相加、DST 不存在时间或超长 ID。解释为什么它属于值边界，而不是控制器、数据库或状态机职责。

## 54. 120 秒复述提纲

不看正文回答：业务值如何减少非法状态？正则验证了什么、没有验证什么？为什么 BigDecimal 仍需要 scale 与 rounding 政策？equals 与 compareTo 有何差别？Instant、LocalDateTime、ZoneId 分别表达什么？UUID 为什么既适合标识又不能充当授权？

最后说出一个失败链：例如 double 输入如何污染 BigDecimal，或默认时区如何让同一 LocalDateTime 漂移。能指出第一处证据比只背 API 名称更重要。

## 55. 验收清单

- 三个值类型构造后不可变，非法输入不能产生实例。
- Money 的币种、scale、舍入与范围政策可从代码和断言读出。
- WorkOrderId 同时执行规范外形和 UUID 解析，格式与存在性没有混淆。
- ServiceTime 不读取系统默认时区，同一 Instant 跨区域保持不变。
- 四个指定故障都真实失败，退出码和首条证据固定。
- 公开练习没有泄露私有答案，验证结果与学习进度分开。

## 56. 有意不做

本章不设计实体生命周期、数据库主键与 ORM、分布式 ID 生成、汇率服务、税务分摊、完整预约引擎、租户授权或 API 序列化格式。也不声称 UUID 绝不碰撞，不声称固定两位适合所有币种，不用修改 JVM 默认时区作为业务修复。

这些非目标不是遗漏，而是保持章节单一职责。后续领域、数据库、安全和 I/O 章节会在已有值边界上继续组合。

## 57. 一手资料与继续阅读

- [BigDecimal，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/math/BigDecimal.html)：十进制值、scale、舍入、equals 与 compareTo。
- [Pattern，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/regex/Pattern.html)：编译表达式、Matcher 与匹配语义。
- [java.time 包，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/time/package-summary.html)：日期、当地时间、瞬间与地区时区的类型边界。
- [ZoneId，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/time/ZoneId.html)：地区规则与固定偏移的区别。
- [UUID，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/UUID.html)：128 位标识、生成、解析与规范表示。
