# Week 06 概念讲义

## 1. 一张图理解本周

    JSON 文件
       │ 字节 → UTF-8 字符 → JSON token → DTO
       ▼
    边界校验 ──技术失败──> 基础设施异常（保留 cause）
       │
       ├─业务字段错误──> ImportReport（记录索引与原因）
       ▼
    领域工厂 ──业务拒绝──> 领域异常
       │
       ▼
    内存仓储

反方向导出时，领域对象先变成稳定的快照 DTO，再序列化到临时文件，写完并关闭后才替换目标文件。

这张图中每一层只回答一种问题：

- I/O 层：字节有没有安全地读到或写出？
- JSON 层：文本是否符合契约、能否映射成 DTO？
- 边界校验层：字段格式、缺失、范围是否可接受？
- 领域层：该设备或工单在业务上是否有效？
- 仓储层：是否重复，保存是否成功？

## 2. 异常不是“报错”，而是失败契约

### 2.1 Throwable 家族的工作边界

| 类型 | 典型例子 | 谁应处理 | 本周策略 |
| --- | --- | --- | --- |
| 业务拒绝 | 重复设备编码、非法状态 | 调用方或应用边界 | 有稳定语义，不伪装成功 |
| 输入/契约错误 | 缺少必填字段、JSON 格式损坏 | 边界适配器 | 区分语法失败与业务字段失败 |
| 基础设施失败 | 文件不存在、权限不足、磁盘写失败 | 适配器转换，外层决定恢复 | 包装并保留原始 cause |
| 编程错误 | 空指针、越界、违反内部不变量 | 修代码 | 不捕获后继续运行 |
| Error | OutOfMemoryError、StackOverflowError | 运行环境与运维 | 通常不在业务代码中捕获 |

checked 与 unchecked 不是“可恢复”和“不可恢复”的自动分类。更实用的判断问题是：

1. 调用方能否在当前抽象层做有意义的恢复？
2. 是否希望编译器强迫所有调用方显式处理？
3. 这是外部资源操作，还是领域前置条件被拒绝？
4. 团队是否已有一致的异常边界？

IOException 是 checked，因为文件调用天然要求面对外部失败。领域中的 InvalidEquipmentCode 往往使用 unchecked，因为它代表调用者违反领域契约，而且每层机械声明会制造噪声。两者都必须有语义。

### 2.2 只捕获你能处理的异常

下面的代码制造了假成功：

    try {
        importFile(path);
    } catch (Exception ignored) {
        return ImportReport.success();
    }

问题不只是捕获范围过大：

- 真实故障被吞掉；
- 调用方得到错误事实；
- 日志缺少 cause；
- 编程 bug 也可能被伪装成业务成功；
- 后续重试、告警和测试都失去依据。

合理的转换应当保留根因和业务上下文：

    try {
        return jsonGateway.read(path);
    } catch (IOException cause) {
        throw new CatalogReadException(
            "无法读取设备目录: " + safeFileName(path),
            cause
        );
    }

消息里加入安全且有用的上下文，不加入文件完整内容、口令或用户隐私。

### 2.3 finally 与 try-with-resources

try-with-resources 适用于实现 AutoCloseable 的资源。资源按声明的相反顺序关闭。若业务代码和 close 同时失败，主异常被抛出，关闭失败通常作为 suppressed exception 保留。排错时不要只看 message，也检查 cause 和 suppressed。

finally 保证在正常返回或异常传播时执行，但它不等于“所有情况下都执行”：进程被强制终止、JVM 崩溃等情况无法保证。不要在 finally 中 return，它会覆盖原有返回或异常。

## 3. I/O：先分清字节、字符与路径

### 3.1 字节流和字符流

- byte 是原始数据单元，适合图片、压缩包和任意二进制；
- char/Reader/Writer 表示经过字符集解释的文本；
- UTF-8 是字节与字符之间的编码规则；
- JSON 是文本格式，因此读写时必须明确 UTF-8。

TS 中的 fetch().json() 隐藏了网络读取、解码和解析层次。Java 文件 API 会迫使你更明确地处理这些层。类比的失效处是：浏览器和 Node 运行时已经替你决定了许多默认行为，而服务端 Java 必须面对机器默认编码、文件权限和路径边界。

### 3.2 Path 不是普通字符串

Path 表示文件系统路径。对用户提供的相对文件名，最小约束流程是：

1. 从可信 baseDir 开始；
2. baseDir.resolve(userPart)；
3. normalize；
4. 确认结果仍 startsWith(normalizedBaseDir)；
5. 对真实存在路径且涉及符号链接时，再评估 toRealPath 的策略；
6. 最终操作仍需面对检查与使用之间状态变化。

单独 normalize 不能解决符号链接逃逸，也不能消除 TOCTOU 风险。本周要建立风险意识，不实现完整沙箱。

### 3.3 小文件与流式处理

Files.readString 简洁，适合明确受限的小文件。大文件整体读取可能占满堆，此时用受控 buffer 或 Jackson 流式 API。但本周不做大规模 ETL；可通过文件大小上限保护小文件方案。

### 3.4 原子写入的真实含义

安全导出的基本步骤：

1. 在目标目录创建唯一临时文件；
2. 写入、flush、关闭；
3. 可选地验证内容；
4. 使用 move 替换目标文件；
5. 失败时清理临时文件；
6. 只有 move 成功才报告导出成功。

ATOMIC_MOVE 是请求，不是所有文件系统都支持；跨文件系统移动通常不能原子。还要注意：一旦指定 `ATOMIC_MOVE`，Java 规范规定其他 move 选项会被忽略；目标已存在时究竟原子替换还是失败，由具体文件系统 provider 决定。因此不能用 `ATOMIC_MOVE + REPLACE_EXISTING` 声称获得可移植的“原子覆盖”。实现应明确支持的平台/provider，以真实旧目标集成测试验证；不满足时安全失败，不悄悄降低语义。

## 4. 时间：先问“这是什么时间”

### 4.1 常用类型的业务语义

| 类型 | 表达什么 | FactoryCare 示例 | 不适合 |
| --- | --- | --- | --- |
| Instant | UTC 时间线上的唯一时刻 | 工单创建、审计事件发生 | “每天 9 点” |
| LocalDate | 无时区日期 | 计划检查日期 | 精确发生时刻 |
| LocalDateTime | 无时区本地日期时间 | 用户输入的当地预约墙钟时间 | 跨区审计 |
| OffsetDateTime | 带固定偏移的日期时间 | API 中保留原偏移的时间 | 未来地区夏令时规则 |
| ZonedDateTime | 带 ZoneId 规则 | 按上海/纽约规则展示或调度 | 单纯存储审计时刻 |
| Duration | 秒/纳秒尺度的时长 | 响应耗时、SLA 已用时间 | “一个月” |
| Period | 年/月/日历日期差 | 保修期按月 | 精确秒数 |

Instant 在 UTC 和 Asia/Shanghai 下不改变；改变的是它转换后的显示值。LocalDateTime 没有足够信息独立转换为 Instant，必须结合 ZoneId 或 offset。

### 4.2 Clock 是可替换的“现在”

把 Clock 注入领域服务：

    final class WorkOrderFactory {
        private final Clock clock;

        WorkOrderFactory(Clock clock) {
            this.clock = clock;
        }

        WorkOrder create(...) {
            return new WorkOrder(..., Instant.now(clock));
        }
    }

测试使用 Clock.fixed，生产组合根使用 Clock.systemUTC。不要把 Clock 作为参数一路暴露给每个业务方法；它是基础能力依赖，由对象构造时提供。

### 4.3 TypeScript 类比与失效

JavaScript Date 内部代表时间戳，但 API 同时混杂本地展示与 UTC 方法，容易把不同语义装进同一个类型。Java time API 通过不同类型强迫你表达语义。

失效点：

- TS 类型别名无法改变 Date 的运行时语义；
- Java LocalDateTime 不是“格式不同的 Instant”；
- ZoneId 是地区规则，ZoneOffset 只是某一刻的固定偏移；
- 系统默认时区是部署环境状态，不能作为隐含业务规则。

## 5. JSON：成功解析只是第一道门

### 5.1 四层契约

1. 语法层：是否是合法 JSON；
2. 结构层：字段是否存在、类型是否可映射；
3. 边界层：字符串长度、枚举 code、数字范围是否合规；
4. 领域层：设备编码是否重复、状态转换是否允许。

一个值可能通过前三层，却因业务规则失败。例如设备编码格式正确，但当前目录中已存在。

### 5.2 DTO 与领域对象分离

输入 DTO 应忠实表达外部契约，领域对象应保护业务不变量。不要为了 JSON 框架给领域实体增加无参构造、任意 setter 或 nullable 字段。

    record EquipmentImportRow(
        String code,
        String name,
        String modelCode
    ) {}

    Equipment toDomain(EquipmentImportRow row) {
        return Equipment.create(
            EquipmentCode.of(row.code()),
            EquipmentName.of(row.name()),
            ModelCode.of(row.modelCode())
        );
    }

输出也使用快照 DTO，只公开契约字段，避免以后给领域对象新增内部字段时意外泄漏。

### 5.3 未知、缺失、null 和版本

这四种情况不能混为一谈：

- 未知字段：生产导入可选择拒绝以发现拼写错误，也可为前向兼容忽略；必须显式决定；
- 缺失字段：取决于是否必填以及是否有稳定默认值；
- 显式 null：可能代表清空，也可能非法；
- 新版本字段：新增通常比修改原字段语义安全。

开发与批量导入场景通常适合对未知字段严格，因为错误文件应该尽早暴露。公共 API 的兼容策略可能不同，留到 Web 阶段设计。

### 5.4 enum 不使用 ordinal

ordinal 随枚举声明顺序变化。对外使用稳定 code：

    enum Priority {
        LOW("low"),
        HIGH("high");

        private final String code;
        // 显式 fromCode，未知 code 拒绝。
    }

### 5.5 Jackson 的学习边界

本周理解 ObjectMapper 的高层职责：

- 把 JSON token 映射到 Java 类型；
- 注册时间等模块；
- 配置未知字段、枚举和 null 策略；
- 在 DTO 边界生成明确异常。

实际 import 与 API 随 Jackson 3 锁定版本为准，不背内部实现，不把 mapper 散落为任意全局可变对象。

## 6. TS/Vue 经验如何迁移

| TS/Vue 经验 | 可用类比 | 类比失效处 |
| --- | --- | --- |
| try/catch/finally | Java 基本控制流相似 | Java 有 checked exception，catch 类型和资源关闭更强约束 |
| Promise rejection | 异步失败会传播 | 本周同步调用栈；Java 异常不是 Promise 状态 |
| fetch 后 schema 校验 | JSON DTO 仍需校验 | TS interface 在运行时不存在，Java 映射成功也不等于领域有效 |
| Date/日期库 | 都需区分存储与展示 | Java 标准库用多个类型编码不同语义 |
| File/Blob | 字节与文本有区别 | 服务端文件系统多了权限、路径穿越、原子替换 |
| Vue error boundary/全局 handler | 边界统一转换错误 | 不能在底层吞异常再让 UI 猜失败 |

## 7. 常见错误清单

- catch Exception 后只打印 message；
- catch 后返回空列表，让“无数据”和“读取失败”不可区分；
- 包装异常时丢掉 cause；
- 使用默认字符集；
- 把用户文件名直接 resolve 后读写；
- 写目标文件中途失败，旧文件已被破坏；
- 在领域方法里到处调用 Instant.now()；
- 用 LocalDateTime 保存审计时刻；
- 把 ZoneOffset 当成 ZoneId 的完整替代；
- Jackson 直接反序列化领域实体；
- 使用 enum ordinal；
- 默认接受未知字段却没有测试；
- 测试依赖用户主目录、真实当前时间或本机时区。

## 8. 官方阅读路线

先读与你的实验直接相关的部分：

- [Java 异常教程](https://docs.oracle.com/javase/tutorial/essential/exceptions/)
- [Java SE 25 NIO 文件包](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/file/package-summary.html)
- [Java SE 25 时间包](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/time/package-summary.html)
- [Clock API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/time/Clock.html)
- [Jackson 官方文档仓库](https://github.com/FasterXML/jackson-docs)
- [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259)

## 9. 自测问题

1. 为什么业务异常和 IOException 不应被一个 ImportFailedException 无差别吞并？
2. 什么情况下你会把 checked exception 转成 unchecked，转换边界在哪里？
3. try-with-resources 中业务逻辑和 close 同时失败时如何排查？
4. normalize 为什么不能完整防止符号链接路径逃逸？
5. 为什么临时文件应尽量和目标文件在同一目录或文件系统？
6. Instant 和 LocalDateTime 哪一个能独立代表唯一时刻？
7. Clock.fixed 解决了哪类测试不稳定？
8. JSON 解析成功后还需要哪三层校验？
9. 输入 DTO 和领域对象合并会给演进带来什么风险？
10. 导出方法返回成功之前，必须证明哪些事实？
