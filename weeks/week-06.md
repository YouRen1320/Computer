# 第 6 周：异常、I/O、时间与 JSON

## 定位

本周让 FactoryCare 开始接触系统边界：失败如何表达、文件如何安全读写、业务时间如何可测试、领域对象如何映射为 JSON。目标是显式处理边界，而不是用 `throws Exception`、系统当前时间和随意序列化掩盖问题。

时间预算：15—18 小时。JSON 仅作为导入导出格式，不充当数据库。

## 前置

- 掌握类、Value Object、集合、泛型和相等性。
- 内存仓储能够保存和查询设备、工单。
- 能用 JUnit 验证异常和集合结果。
- 了解所有外部输入都不可信，不能直接构造有效领域对象。

## 目标

- 区分业务失败、技术失败、编程错误和不可恢复错误。
- 设计有语义的异常并保留根因，不吞异常。
- 使用 NIO.2、UTF-8 和 try-with-resources 安全处理文件。
- 正确选择 `Instant`、本地日期时间、时区、Duration 和 Clock。
- 将 JSON DTO 与领域对象分离，显式处理未知、缺失和非法字段。
- 为 FactoryCare 实现设备目录导入和工单快照导出。

## 完整概念清单

### 异常模型

- `Throwable`、`Error`、checked exception、runtime exception 的边界。
- 业务异常、输入校验异常、基础设施异常和编程 bug 的区别。
- `throw` 与 `throws`；异常传播和调用栈。
- `try/catch/finally`；只捕获能处理或转换的异常。
- try-with-resources 与 `AutoCloseable`。
- 保留原始 cause；包装异常时添加业务上下文但不泄漏敏感数据。
- 不捕获 `Exception` 后返回假成功，不用异常代替正常分支。
- 批量导入时 fail-fast 与收集错误两种策略。

### 文件与流

- byte stream 与 character stream；编码决定文本解释。
- NIO.2 的 `Path`、`Files`、相对/绝对路径、规范化。
- UTF-8 明确指定，不依赖机器默认编码。
- 小文件整体读取与大文件流式处理的选择。
- 原子写入的高层思路：临时文件、成功后替换。
- 文件不存在、权限不足、路径穿越、部分写入和资源关闭。
- 用户提供文件名不能直接拼接到任意系统路径。

### 日期时间

- `Instant` 表示时间线上的时刻，适合持久化审计时间。
- `LocalDate` 表示日期；`LocalDateTime` 不包含时区或偏移。
- `OffsetDateTime`、`ZonedDateTime` 的用途和时区规则。
- `ZoneId`、UTC、系统默认时区和夏令时风险。
- `Duration` 与 `Period` 的区别。
- `Clock` 注入使“现在”可测试；不在核心规则中散落 `now()`。
- 格式化、解析和 ISO-8601；展示格式不等于存储格式。

### JSON 边界

- JSON object/array/string/number/boolean/null。
- JSON 字段与 Java 类型的映射风险：数字范围、null、未知字段、时间格式。
- Jackson 3 的高层对象映射流程；使用当前稳定版本和明确配置。
- 输入 DTO、输出 DTO 与领域对象的职责分离。
- 先解析 DTO，再通过领域工厂校验；反序列化成功不代表业务有效。
- enum 使用稳定 code 的映射策略，不依赖 ordinal。
- 不直接暴露内部实体全部字段，不序列化密码、密钥和内部异常。
- 版本兼容：字段新增、缺失和废弃需有明确策略。

### 可测试边界

- 临时目录、固定 Clock 和测试 fixture。
- 正常、空文件、损坏 JSON、未知字段、重复数据和部分错误。
- 错误报告包含记录位置与原因，不包含敏感原文。
- I/O 适配器与领域服务分离。

## 任务分配

| 模块 | 时间 | 任务 |
| --- | ---: | --- |
| 异常 | 2.5h | 设计异常分类、传播、转换和根因测试 |
| NIO/I/O | 2.5h | UTF-8 读写、临时文件、路径和错误实验 |
| 日期时间 | 2.5h | Instant/Local/Zoned/Duration/Clock 练习 |
| JSON | 2.5h | DTO 映射、时间/enum 配置和非法输入测试 |
| FactoryCare | 3—4h | 设备导入、工单快照导出和错误报告 |
| 无 AI 训练 | 2h | 修复导入失败与时区变体 |
| 求职动作 | 1h | 异常、I/O、时间面试口述 |

## FactoryCare项目增量

实现两个边界适配器：

1. `EquipmentCatalogImporter`
   - 从 UTF-8 JSON 文件读取设备目录 DTO。
   - 校验设备编码、名称和必要字段，再转换为领域对象。
   - 对损坏 JSON 直接失败；对批量业务错误输出带记录索引的报告。
   - 不允许同一设备编码静默覆盖。
2. `WorkOrderSnapshotExporter`
   - 将工单只读快照导出为稳定 JSON。
   - 时间使用 ISO-8601；审计时刻使用 `Instant`。
   - 先写临时文件，再完成替换，避免留下半个文件。

为工单加入 `createdAt`，由注入的 `Clock` 产生；测试固定时间，不依赖真实系统时钟。

## AI协作边界

可以让 AI：

- 生成损坏 JSON、编码、时区和文件异常的测试候选。
- 审查异常是否被吞掉、cause 是否丢失。
- 比较 `Instant`、`LocalDateTime`、`ZonedDateTime` 的适用场景。
- 在你定义 DTO 契约后生成机械映射代码。

必须由你完成：

- 决定失败是拒绝整批、跳过单条还是返回错误报告。
- 决定业务时间含义、存储时区和展示边界。
- 检查路径、编码、资源关闭、敏感字段和原子写入。
- 能在没有 AI 时定位一次损坏 JSON 和一次时区错误。

## 无AI训练

本周从求职/复盘时段预留45—60分钟完成并记录：链表基础题；画出指针变化并覆盖空链表、单节点和环的概念。

关闭 AI，限时120分钟：

1. 为导入器增加“同一文件重复设备编码”检测。
2. 使用临时目录构造 UTF-8 文件，补成功、重复、空字段和损坏 JSON 测试。
3. 将固定 Clock 从 UTC 改为 `Asia/Shanghai`，说明 `Instant` 为什么不随展示时区改变。
4. 人为删除异常 cause，观察调试信息变化后修复。

## 求职动作（恢复求职后启用）

- 准备 checked/unchecked、finally、try-with-resources、字符流/字节流、Instant/LocalDateTime、时区的回答。
- 为“线上导入文件失败如何排查”写一份 5 步排查模板。
- 在项目周报中记录输入校验和错误报告，不把 JSON 文件称为“持久化数据库”。
- 投递或收藏至少 5 个与 Java/Vue 全栈匹配的岗位，记录是否要求 Jackson、文件处理或时间任务。

## 交付物

- 设备目录 JSON 契约样例和导入器。
- 工单快照导出器及原子写入策略说明。
- 领域异常与基础设施异常分类表。
- 固定 Clock、临时目录、损坏 JSON 和时区测试。
- 无 AI 故障定位记录。

## 验收标准

- 能区分业务失败、技术失败、编程错误和 Error，不用一类异常包办。
- 所有资源正确关闭，文本明确使用 UTF-8，路径输入经过约束。
- 能解释 Instant、LocalDateTime、ZonedDateTime、Duration 和 Clock。
- JSON DTO 与领域对象分离，非法业务数据不能因解析成功进入仓储。
- 导入错误可定位到记录，导出失败不会留下被误认成功的完整文件。
- 测试不依赖真实当前时间和用户主目录固定路径。
- 能独立排查损坏 JSON、编码或时区问题。

## 明确不做

- 不使用 Java 原生对象序列化作为业务格式。
- 不把 JSON 文件当长期数据库，不实现文件锁和大规模 ETL。
- 不深入 Jackson 模块源码、自定义解析器内部或字符编码理论细节。
- 不接入 HTTP 上传、对象存储、Spring MVC 或数据库。
- 不设计跨时区日历排班和复杂节假日 SLA；后续按业务需要处理。

## 官方资料

- [Java Exceptions](https://docs.oracle.com/javase/tutorial/essential/exceptions/)
- [Java SE 25：java.nio.file](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/file/package-summary.html)
- [Java SE 25：java.time](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/time/package-summary.html)
- [Clock API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/time/Clock.html)
- [Jackson 官方文档仓库](https://github.com/FasterXML/jackson-docs)
- [JSON 标准 RFC 8259](https://www.rfc-editor.org/rfc/rfc8259)
