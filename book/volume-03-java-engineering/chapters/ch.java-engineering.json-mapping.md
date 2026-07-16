---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.json-mapping
title: JSON 数据边界、对象映射与未知字段处理
responsibility: 教授外部 JSON 与内部类型之间的显式映射和兼容策略，不把 JSON 当作领域模型或数据库 schema
volume: '03'
order: 11
level: L2
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.json-mapping.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-engineering.nio-files-charsets
- ch.java-oop.enum-record-sealed
- ch.java-engineering.maven-reproducible-builds
version_surfaces:
- jdk-25
- maven-3
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释JSON 数据边界、对象映射与未知字段处理的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - json-shape-mapping
  - json-compatibility
  covers_topics:
  - json.object-array-scalar
  - java.json-object-mapping
  - java.json-null-missing
  - java.json-unknown-field
  - java.json-invalid-input
  - java.json-version-compatibility
  uses_capabilities:
  - java.exceptions-resources
  - foundation.files-path-encoding
  - java.build-testing
  - java.encapsulation-immutability
  - java.io-json
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：用 Path/Files 以 UTF-8 和安全资源边界读取 JSON，把 WorkOrder record 双向映射并定义缺失/null、枚举、未知字段和版本策略
  covers_topic_groups:
  - json-shape-mapping
  - json-compatibility
  covers_topics:
  - json.object-array-scalar
  - java.json-object-mapping
  - java.json-null-missing
  - java.json-unknown-field
  - java.json-invalid-input
  - java.json-version-compatibility
  uses_capabilities:
  - java.exceptions-resources
  - foundation.files-path-encoding
  - java.build-testing
  - java.encapsulation-immutability
  - java.io-json
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入错误字符集、文件资源失败、字段漂移、非法枚举和未知字段静默吞噬，按IO或映射阶段分别修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - json-shape-mapping
  - json-compatibility
  covers_topics:
  - json.object-array-scalar
  - java.json-object-mapping
  - java.json-null-missing
  - java.json-unknown-field
  - java.json-invalid-input
  - java.json-version-compatibility
  uses_capabilities:
  - java.exceptions-resources
  - foundation.files-path-encoding
  - java.build-testing
  - java.encapsulation-immutability
  - java.io-json
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# JSON 数据边界、对象映射与未知字段处理

> 本章状态为 `drafting`。Java 25 离线 oracle 证明的是本章固定 WorkOrder 形状、UTF-8 文件与故障合同；它不是通用 JSON 库认证。P9 零基础试读、人工版式/无障碍检查、独立全面审查、Maven 全集成和全书回归尚未执行，因此不能晋升为 `verified`，也不会修改 `PROGRESS.md`。

JSON 看起来像 JavaScript 对象，却只是跨边界的文本数据模型。`{"amount":0.1}` 不自带货币、精度或舍入规则；`"2026-07-16T09:30:00"` 不自带时区；缺少 `assignee` 与 `"assignee":null` 可能代表不同业务动作；新增 `priorityLabel` 对旧消费者可能安全，也可能触发严格校验失败。若直接把外部 JSON 当领域对象，协议变化、无效值和攻击输入就会穿透系统。

本章把对象映射拆成明确阶段：字节与字符集、JSON 语法、结构形状、标量转换、边界校验、领域构造和兼容策略。连续场景是 FactoryCare 工单快照，使用 record、enum、`Instant`、`BigDecimal` 和三态可选字段。生产工程应使用经过审计的 JSON 库并通过 Maven 固定依赖；配套离线资产为让每项决策可见，只实现本章固定的扁平 JSON object 教学 codec，明确不支持通用嵌套 JSON，也不可替代生产解析器。官方资料复核日期为 **2026-07-16**。

## 1. 完成定义与证据

1. 在 120 秒内说明 JSON 的六类值、object/array 顺序差异、序列化与反序列化方向，以及 JSON DTO 与领域模型的边界。
2. 从 UTF-8 文件读取工单 JSON，区分 I/O、语法、形状、标量和领域错误，并安全关闭 reader/writer。
3. 把 `schemaVersion`、`id`、`status`、`openedAt`、`amount` 与 `assignee` 映射为不可变类型，再序列化并证明语义往返一致。
4. 对 `assignee` 的 missing、explicit null、string value 三种输入给出不同结果和测试。
5. 为未知字段分别实现严格拒绝与显式宽松策略，证明兼容新增字段不是“默认吞掉一切”。
6. 重放错误字符集、缺失文件、字段漂移、非法枚举、未知字段静默吞噬和精度丢失故障，定位到第一处可信证据。

配套工件：

- [JSON 边界最小示例](../../../examples/encyclopedia/ch.java-engineering.json-mapping/README.md)
- [FactoryCare JSON 映射实验](../../../labs/encyclopedia/ch.java-engineering.json-mapping/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.json-mapping/README.md)

公开 starter 初始失败是练习起点。先为每个字段写输入形状、目标类型、缺失策略和错误码，再实现 TODO；不要查看或链接私有解。

## 2. JSON 数据模型：值只有六类，业务含义不在文本里

RFC 8259 定义四类原始值：string、number、boolean、null，以及两类结构值：object、array。object 是名称/值对的无序集合，array 是有顺序的值序列。最外层 JSON text 可以是任意 JSON value，不只 object；业务 API 若要求 object，必须在自己的形状合同中额外限制。

object 的名称是 string，值可以是任意 JSON value。协议中写 `"priority":4` 与 `"priority":"4"` 是不同类型，不能依赖 mapper 随意把字符串强制成数字。`true` 与 `"true"` 也不同。宽松 coercion 虽能兼容某些历史输入，却会让拼写和类型漂移静默通过；是否允许必须显式配置并测试。

object 名称应唯一。重复键如 `{"status":"OPEN","status":"CLOSED"}` 在不同实现中可能保留第一项、最后一项、全部或直接拒绝，互操作性差。边界最佳实践是拒绝重复键，避免攻击者利用代理、日志和业务解析器理解不同。配套教学 codec 会把重复字段作为语法/形状错误。

object 成员顺序通常不属于语义。`{"id":"WO-101","status":"OPEN"}` 与顺序相反的 object 在语义上相同；字节串、缩进和转义形式也可不同。array 顺序则属于语义，工单事件时间线不能任意重排。测试 round trip 应比较映射后的结构与类型，不要求输出字节和输入完全相等，除非另有签名或规范化合同。

## 3. 从字节到领域对象：五道边界不能揉成一个异常

完整输入路径可以画成：文件字节 → UTF-8 字符 → JSON tokens → object 字段 → Java 边界 record → 领域对象。每一层都有不同失败原因和责任。

第一层是 I/O：路径不存在、权限不足、读到一半失败。它应保留 path、操作和 `IOException` cause，不要伪装成“JSON 格式错误”。第二层是字符解码：协议约定 UTF-8，却用平台默认编码或 ISO-8859-1 读取，中文可能乱码或解码失败。第三层是 JSON 语法：缺引号、尾随逗号、非法转义、数字语法错误。第四层是映射/形状：需要 object 却收到 array，必填字段缺失，status 类型不是 string。第五层是领域校验：priority 超出 1..5、amount 为负、时间违反业务约束。

错误分类让运维和客户端能采取正确动作。缺文件可能重试或修复部署；语法错误应返回输入问题；未知枚举可能表示版本不兼容；领域不变量失败应指向字段。一个 catch `Exception` 后统一抛 `InvalidJsonException` 会丢掉最有价值的证据。

配套 mapper 使用稳定错误码，如 `JSON_SYNTAX`、`MISSING_FIELD:id`、`NULL_REQUIRED:status`、`INVALID_ENUM:status`、`INVALID_TIME:openedAt`、`INVALID_AMOUNT:amount`、`UNKNOWN_FIELD:x`。测试断言错误码与阶段，不依赖第三方库整段本地化消息。

## 4. 生产 mapper 与教学 codec：不要手写通用解析器

生产项目应选用成熟、维护中的 JSON 库，固定版本，审计传递依赖与安全公告。Jackson 官方项目当前文档以 `ObjectMapper`/`JsonMapper` 展示 POJO 与 JSON 双向映射；Jackson 3.x 使用 `tools.jackson.databind` 命名空间。mapper 通常应完成配置后复用，而不是每次请求临时创建并依赖不同默认值。

Maven 依赖要在 POM 或 dependency management 中直接声明关键组件和版本策略，用 `dependency:tree` 检查实际解析图。不能因为某个框架传递带入 mapper 就假定版本、模块和行为永远稳定。Java 时间模块、参数名/record 支持和框架自动配置也应在真实构建中验证。

本章离线资产不用 Maven 下载依赖，因为目标是任意断网环境下用 JDK 25 重放合同。`JsonSupport.FlatJson` 只识别一个扁平 object，值仅允许 string、number、null，并实现必要转义与重复键拒绝；不支持 array、嵌套 object、boolean 或流式大文档。它是透明教学夹具，不是推荐生产实现。章节明确列出限制，避免“样例能跑”被误解为库选型。

把 mapper 隔离在边界 adapter 后，生产中可以换成 Jackson，而领域层仍只看到 `WorkOrderInput` 或 `WorkOrder`。测试分两层：纯映射合同固定字段语义，库集成测试固定真实配置。这样既不让 JSON 注解扩散到领域模型，也不需要自己维护通用 parser。

## 5. 序列化与反序列化：方向相反，风险不对称

序列化把受控 Java 值转换为 JSON；反序列化把外部不可信 JSON 转为 Java。写出时系统通常掌握类型和不变量，读入时必须假定字段缺失、类型错误、超长、重复、未知或恶意嵌套。因此“能序列化”不证明“能安全反序列化”。

边界 record 应只包含协议所需字段，构造时验证基础不变量。领域实体可能含行为、内部状态、缓存、审计字段和敏感信息，不应直接让 mapper 反射全部字段。专用 DTO/record 让允许输入和输出可审查，也避免新增内部字段意外出现在 API。

输出合同要决定字段名、空值策略、数字格式、时间格式、枚举表示、默认字段是否省略和版本字段。序列化顺序可以固定以便日志和快照可读，但不要把 object 顺序冒充语义。敏感字段如 token、内部备注必须通过白名单 DTO 排除，而不是寄望某个全局忽略配置。

反序列化后不要立即把对象视为可信。mapper 能证明 `"priority":4` 是整数，不代表用户有权把 priority 设为 4，也不代表状态迁移合法。结构校验、领域校验、授权是不同层，不能由 JSON 映射替代。

## 6. missing、null、默认值：三种状态先建模再压缩

JSON object 中字段可能不存在，也可能存在且值为 null，还可能有实际值。对 PATCH 或配置合并，这三种状态常有不同含义：missing 表示“不改变”，null 表示“清除”，string 表示“设置”。若一反序列化就都变成 Java null，信息不可恢复。

本章用 `OptionalText(Presence, value)` 明确 `MISSING`、`EXPLICIT_NULL`、`VALUE`。这不是建议所有 DTO 都套一层类型，而是提醒先确认协议语义。若 create 请求中 assignee 缺失和 null 都表示未分配，可以在边界验证后压缩成同一状态；若 PATCH 中不同，就必须保留。

Java `Optional` 不天然表达 missing 与 explicit null，因为两者通常都会成为 empty。Optional 主要适合返回值的可能缺失，不是通用 JSON 三态容器。mapper 框架可能提供 setter 调用信息、树模型或专用 nullable wrapper；选择后应有三案例测试。

默认值也有版本含义。新增可选 `priority` 字段，旧消息缺失时可以应用协议规定默认值；显式 null 是否也用默认，必须另定。默认值放在 mapper、DTO 构造器还是领域服务会影响重用与迁移，应选择唯一责任点并记录。

必填字段不应因 Java primitive 默认值而静默出现。若缺失 `int schemaVersion` 被映射成 0，系统可能把缺失当合法旧版本。读取阶段应先检查字段存在和类型，再解析为 int；配套 mapper 正是这样做。

## 7. 未知字段：严格与宽松都是策略，不是道德判断

严格模式遇到未知字段立即失败，优点是抓住拼写错误、字段漂移和未评审输入；缺点是生产者新增字段会破坏旧消费者。宽松模式忽略未知字段，利于向前兼容；缺点是客户端把 `opened_at` 拼错时可能被吞掉，关键值完全没生效。

选择应按边界决定。配置文件、部署清单和内部命令通常更适合严格，因为拼写错误必须尽早暴露。跨版本事件或响应 DTO 可能允许新增字段，但仍可记录受控指标，且关键必填字段继续严格。安全敏感命令不能仅靠“忽略 extras”规避注入；应使用白名单 DTO 和授权。

配套 mapper 要求调用者显式传 `UnknownFieldPolicy.REJECT` 或 `IGNORE`，没有隐藏全局默认。严格案例断言 `UNKNOWN_FIELD:priorityLabel`；宽松案例证明已知字段仍正确映射。另一个故障夹具故意宽松读取含 `currency` 的金额，随后抛出 `UNKNOWN_FIELD_SILENTLY_IGNORED`，展示忽略可能丢失业务含义。

未知枚举不是未知字段。字段名 `status` 已知而值 `PAUSED` 未知，说明 producer 使用了消费者不理解的新取值。直接映射到 enum 应失败并保留原 token；若协议设计有 `UNKNOWN` 哨兵，也要决定是否保留原值、是否允许业务继续。不能把未知枚举一律当 null。

## 8. 时间：先决定时间线、偏移还是本地日历语义

`2026-07-16T09:30:00` 没有 offset，无法唯一定位全球时间线。工单创建时刻通常应使用带 `Z` 或 offset 的 ISO-8601 文本，映射为 `Instant` 或 `OffsetDateTime`。门店每天 09:00 的排班可能是 `LocalTime` 加明确 zone 规则，不能硬塞 Instant 后丢掉业务时区。

本章字段 `openedAt` 要求 `Instant.parse` 可接受的 ISO-8601 表示，如 `2026-07-16T01:30:00Z`。输出使用 `Instant.toString`，稳定为 UTC 语义。输入没有 offset、格式非法或超范围时产生 `INVALID_TIME:openedAt`，不使用系统默认时区补猜。

时间兼容还包括精度。生产者从秒提升到毫秒通常仍能被 Instant 解析，但若签名、数据库精度或快照比较依赖固定格式，必须单独约定。不要用字符串字典序比较不同 offset 表示的时刻；先解析成时间类型。

“北京时间”是展示选择，不应隐含在 wire format。API 保存 Instant，UI 按用户时区格式化；若业务必须保留原 offset，则同时建模 OffsetDateTime 或原始字段。类型应服务语义，不只是让 parser 通过。

## 9. 金额与 JSON number：十进制语义不能经过 binary double

JSON number 语法不规定所有实现都支持任意精度。金额若先读成 double 再 `BigDecimal.valueOf`，某些小数计算和原始精度可能已发生变化。Java `BigDecimal` 是任意精度十进制数，由 unscaled value 与 scale 组成，适合显式金额规则。

本章 parser 保留 number 原始 token，mapper 直接 `new BigDecimal(token)`，再要求非负且 scale 位于 0..2；正指数表示因此不会在往返后悄悄改变 scale。输出用 `toPlainString`，避免科学计数法意外进入简单金额协议。`1234.50` 往返后仍保留 scale 2；语义测试同时检查 value 与 scale。

金额合同还必须包含币种和舍入。单独 amount 没有完整货币意义；真实 DTO 应包含 currency，或协议上下文明确定义唯一币种。除法和税费计算要指定 `RoundingMode`，不能在 JSON 层猜。配套简化 WorkOrder 只验证 decimal 映射，不代表完整 Money 类型。

有些协议把金额写成字符串或最小单位整数，能避开跨语言浮点解析差异；另一些使用 JSON number 配合 schema。两者都有迁移成本，不能擅自改变 wire type。确定后做跨语言契约测试，而不是只测 Java 自己序列化再读回。

## 10. enum 与受限字符串：失败、兼容和大小写都要明确

Java enum 能限制 `OPEN`、`IN_PROGRESS`、`CLOSED`，比任意 String 更安全。默认 `valueOf` 区分大小写；是否允许 `open` 是协议决策。宽松转大写可能接受拼写，却也改变签名和审计原文。本章严格接受 canonical token。

新增 enum 值通常是兼容风险。生产者认为 additive，旧消费者却无法理解。方案包括版本协商、旧消费者明确 UNKNOWN 分支、生产者在兼容窗口不发送新值或升级消费者先行。每种都需要发布顺序和回滚计划，不应只给 mapper 加 `default` 吞掉。

错误证据应包含字段名和脱敏 token。对超长或敏感值不要把全部原文写日志；记录长度、位置、请求追踪 ID。枚举失败属于映射阶段，不应报告为 I/O。

## 11. 版本兼容：兼容是一段有退出条件的协议，不是永久别名

安全的 additive change 通常是新增消费者可忽略或有默认的字段，但只有测试覆盖旧消费者时才能确认。删除必填字段、改变类型、重命名、改变 null/default、收紧范围、改变 enum 都可能破坏。`schemaVersion` 能帮助路由，却不能自动解决语义差异。

字段重命名 `opened_at → openedAt` 有三种常见路径：立即破坏性切换；限时双读、只写新名；引入新版本 endpoint/message。选择维度包括调用方数量、迁移成本、风险、回滚和长期维护。长期目标应只有一个 canonical 字段；双读必须有遥测、截止日期和删除测试，不能成为永久兼容分支。

若同时收到旧名和新名，应拒绝冲突而不是随机选一个。若值相同是否接受也要明定。序列化通常只写新名，避免继续扩大旧协议。回滚计划要说明旧消费者仍能否读取、数据库/事件是否已产生不可逆新值。

版本策略应通过 fixture 验证：v1 缺新增可选字段仍能读；v2 多出字段在允许边界被显式忽略；必填字段类型变化必须失败；过期别名删除后测试更新。兼容性是契约测试集合，不是一句“JSON 向前兼容”。

## 12. 文件、UTF-8 与资源所有权

RFC 8259 对开放系统交换的 JSON 使用 UTF-8。Java 读取时应显式 `StandardCharsets.UTF_8`，不要依赖平台默认。配套 `JsonFiles` 用 `Files.newBufferedReader/newBufferedWriter` 和 try-with-resources，关闭所有者一目了然；小文件也可使用显式 charset 的 `readString/writeString`。

读取边界应设置大小限制，避免一次把无限文件读入内存。教学 codec 为小 fixture，读取后检查字符数；生产系统还需在流、HTTP server 和 parser 层限制 bytes、深度、数组长度、字符串长度和数字长度。JSON 合法不代表资源安全。

写文件时“成功返回”与“崩溃后原子可见”不同。配置快照可能需要同目录临时文件、flush/fsync 策略和 atomic move；这些属于 NIO 原子文件章节，本章只演示安全关闭和 UTF-8 语义，不声称具备崩溃一致性。

错误字符集夹具写入 `机泵` 的 UTF-8 bytes，再故意用 ISO-8859-1 读取并比较，确定性产生 `WRONG_CHARSET`。它不依赖某个平台默认编码，因此在不同机器上仍能重放。

## 13. 边界验证与安全：白名单形状、限制资源、拒绝含混

对不可信 JSON 至少限制总大小、嵌套深度、集合长度、字段数、字符串长度和数字长度。拒绝重复键，决定尾随数据、非标准注释、NaN/Infinity 和前导零策略。宽松 parser feature 每开启一项都扩大输入语言，应有实际兼容需求与测试。

反序列化类型白名单尤其重要。不要根据外部类名任意实例化类型，也不要开启不受限多态反序列化。sealed hierarchy 可以配合显式 type discriminator 和允许子类型表，但授权仍在业务层。

边界 record 构造器检查 id 非空、版本受支持、金额非负/scale、状态和时间。跨字段规则如 CLOSED 必须有 closeTime 可留给领域 factory，因为它可能依赖更多上下文。校验失败返回稳定字段路径，不把整份可能含隐私的 JSON 写日志。

序列化也要防数据泄漏和日志注入。输出 DTO 使用字段白名单，字符串由 JSON generator 正确转义；不要拼接引号。配套 FlatJson 的 quote 只覆盖教学范围并有转义测试，生产仍使用库 generator。

## 14. 调试：先定位阶段，再缩小到一个字段

收到失败时先保留脱敏 fixture、字节长度、charset、schema version 和 mapper 配置摘要。若是 IOException，检查 path/cause；若是 JSON syntax，检查位置附近 token；若是 mapping，检查 expected shape、actual token type 与 field path；若是 domain，检查不变量和业务上下文。

不要从“把 unknown fields 全关掉”或“允许所有 coercion”开始。那可能把第一个可见错误藏起来，后面以默认值造成更大损失。把失败 JSON 缩到最小 object，每次只改一个字段，再重放原测试集。

库异常通常包含多层 cause 和 reference chain。找到第一处业务可信证据后进行错误翻译，保留 cause；API 对外可返回稳定 code，内部日志保留 parser location 和追踪 ID。不要把第三方完整消息当长期 API 合同。

对兼容问题同时运行 producer 新 fixture 与 consumer 旧配置。只看当前服务单元测试无法证明跨版本。Maven 依赖问题用 `dependency:tree` 核对实际 mapper 模块和版本，不以 IDE 自动补全为准。

## 15. 测试矩阵：往返、三态、未知、非法、文件和版本

成功案例至少含 ASCII 与中文、转义引号、整数版本、带 Z 时间、两位小数金额和每个 enum 值。序列化再反序列化比较 record 语义，另断言输出没有泄露未知/内部字段。object member order不作为输入语义。

三态案例用三份 fixture：没有 assignee、`assignee:null`、`assignee:"tech-7"`。断言 presence 分别为 MISSING、EXPLICIT_NULL、VALUE，value 只在第三种存在。未知字段分别跑 REJECT 与 IGNORE；严格失败、宽松保留已知字段。

非法案例覆盖缺 id、id null、status 数字、未知 enum、无 offset 时间、负金额、三位小数、重复字段、尾随文本和不支持 array。每个失败映射到正确阶段。文件案例覆盖 UTF-8 往返与缺失路径 IOException，不用 mock 掩盖真实 NIO 边界。

版本案例覆盖当前 schemaVersion 1、缺版本、未来版本和 additive unknown。未来版本是否拒绝由合同决定；本章拒绝不支持版本，避免错误解释。高层集成使用真实 Jackson 配置时应复用同一 fixture 表。

## 16. FactoryCare 离线实验设计

`WorkOrderJsonMapper` 接受固定字段：`schemaVersion`、`id`、`status`、`openedAt`、`amount`、`assignee`。parser 返回保留原始 number token 的 `FlatJson.Value`，mapper 再做类型和业务验证。输出固定字段顺序仅便于证据阅读，不宣称 JSON object 有序。

正常 oracle 创建一张中文工单，写到 verify 脚本提供的 build 路径，以 UTF-8 读回；比较 record、amount scale、Instant、enum 和三态。随后运行 missing/null/value、unknown strict/lenient 与转义案例。故障进程分别证明错误字符集、文件 I/O、字段漂移、非法枚举、静默 unknown 和 double 精度风险。

`FlatJson` 不解析嵌套对象/数组/boolean，遇到就明确 `UNSUPPORTED_VALUE`。这项限制是实验完成定义，不是遗漏。生产迁移到 Jackson 时，保留 `WorkOrderJsonMapper` 的字段合同和 fixtures，替换 parser adapter；不应复制 FlatJson 到业务项目。

## 17. 与 TypeScript/Vue 的类比，以及失效处

TypeScript interface 只在编译期帮助代码，`JSON.parse` 返回的运行时值仍不可信；这与 Java mapper 后仍需边界校验相似。前端可用 Zod 等 schema 工具做 runtime validation，Java 可用 DTO、mapper 配置和 Bean Validation/领域 factory。Vue API client 也应把 wire DTO 映射成页面模型，而不是把后端原始 object 散布到组件。

差异在数值与类型：JavaScript number 通常是 IEEE 754 double，Java 可用 BigDecimal 保留十进制；TypeScript 的 `field?: T | null` 能在类型上提示 missing/null，但 `JSON.parse` 不会自动验证。Java record/enum 是运行时类型，mapper 失败会抛异常。

JS object 属性通常有可观察枚举顺序规则，但 JSON RFC 的 object 语义仍是无序；不能用前端当前 stringify 顺序作为跨系统合同。Date 在 JSON 中也只是 string，前后端必须共享带 offset 的格式与精度策略。

## 18. 常见错误与可复用规则

- 错误：把 JSON object 当领域实体。修复：边界 DTO 白名单映射，领域 factory 再验证。
- 错误：缺失与 null 都落成 Java null。修复：先判断业务是否三态，再显式建模。
- 错误：金额先经 double。修复：从十进制 token/string 直接构造 BigDecimal，固定 scale/rounding。
- 错误：无 offset 时间用系统默认时区猜。修复：wire contract 要求 offset/Instant，展示层再转换。
- 错误：全局忽略 unknown 以“兼容”。修复：按边界选择策略，严格必填，宽松也有 fixture 与遥测。
- 错误：未知 enum 当 null。修复：区分字段未知和值未知，制定版本/UNKNOWN 策略。
- 错误：round trip 比较字节串。修复：比较语义结构；签名需求另做规范化协议。
- 错误：catch 所有异常为 invalid JSON。修复：保留 I/O、syntax、mapping、domain 阶段。
- 错误：复制教学 parser 到生产。修复：使用成熟库、Maven 固定与安全更新，保留边界 adapter。
- 错误：永久双读旧字段。修复：明确兼容窗口、遥测、截止日期、删除和回滚计划。

## 19. 独立练习与讲回

公开练习提供 FlatJson 支撑代码，要求补齐 `WorkOrderJsonMapper` 的必填字段、enum、Instant、BigDecimal、三态和 unknown policy。运行前写下六份 fixture 的 expected；starter 会以 `JSON_MAPPING_CONTRACT` 失败。不得通过忽略全部异常或把 expected 改成默认值修复。

完成后手工注入 `opened_at` 字段漂移，说明严格 unknown 与缺必填各提供什么证据；再把 `0.10` 经 double 转换，检查 scale/值为何可能不满足金额合同。最后用 120 秒讲回五层边界、missing/null、未知字段取舍、时间金额类型和兼容退出条件。

复习五问：

1. JSON object 与 array 的顺序合同有什么不同？
2. `assignee` missing 与 null 在 PATCH 中为何不能自动合并？
3. 新增字段何时对旧消费者兼容，如何用测试证明？
4. 为什么 `BigDecimal(double)` 不适合作为 JSON 金额入口？
5. 文件不存在和 status 非法为何必须产生不同错误阶段？

## 20. 本章边界与非目标

本章负责外部 JSON 到内部类型的显式映射，不把 JSON 定义成数据库 schema，不教授 OpenAPI/JSON Schema 全套、网络 HTTP、Jackson 全 API、多态反序列化、流式超大文档、数字签名或原子文件替换。配套 codec 是局部教学工具，生产依赖集成仍需 Maven 测试。

掌握本章后，学习者应能审查任一 JSON DTO：列出每个字段的 JSON type、Java type、必填/null/default、unknown 与版本策略，能用最小 fixture 定位失败阶段，并能解释为何“能 parse”远远不等于“边界安全”。

## 官方资料

- [RFC 8259：The JavaScript Object Notation (JSON) Data Interchange Format](https://www.rfc-editor.org/rfc/rfc8259.html)
- [Java SE 25：BigDecimal](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/math/BigDecimal.html)
- [Java SE 25：Instant](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/time/Instant.html)
- [Java SE 25：Files](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/file/Files.html)
- [Apache Maven：Dependency Mechanism](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html)
- [FasterXML：jackson-databind 官方项目](https://github.com/FasterXML/jackson-databind)
