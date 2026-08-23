# Java：异常、文件、时间与 JSON

## 1. 这一章是一条“外部数据进入程序”的链路

只在内存中计算时，输入通常已经是 Java 值。真实程序还要面对文件不存在、磁盘权限不足、文本编码不一致、JSON 字段缺失、日期格式错误等情况。

可以把一次离线工单导入拆成下面这条链路：

```text
文件路径
  → 读取字节
  → 按字符集解码成文本
  → 按 JSON 语法解析
  → 映射成 Java 数据
  → 检查业务规则
  → 交给领域对象或服务
```

每一层都有自己的失败原因。异常让失败沿调用链传播；资源管理保证失败时文件仍能关闭；时间和 JSON 类型决定数据怎样表达。理解这条边界链，比背几十个 API 更重要。

## 2. 异常：正常返回之外的失败通道

方法成功时可以返回结果；无法完成承诺时，可以抛出异常：

```java
static int requirePositive(int value) {
    if (value <= 0) {
        throw new IllegalArgumentException("value must be positive");
    }
    return value;
}
```

执行 `throw` 后，当前方法不会继续执行后面的普通语句。JVM 会沿调用栈向上寻找能够处理该异常的 `catch`。如果一直没有合适处理者，线程结束，主线程中的未处理异常通常会让进程以非零状态退出并打印堆栈。

异常不只是“程序崩了”。它是一份失败合同：什么情况不能正常完成、谁知道怎样处理、调用方还能获得哪些可信信息。

### 2.1 Throwable 的大方向

常见层次可以先简化为：

```text
Throwable
├── Error
└── Exception
    ├── RuntimeException
    └── 其他受检异常
```

- `Error` 往往表示 JVM 或运行环境的严重问题，普通业务代码通常不试图统一吞掉；
- `RuntimeException` 及其子类是非受检异常；
- 其他 `Exception` 常属于受检异常，编译器要求调用方捕获或在 `throws` 中继续声明。

不要写一个 `catch (Throwable ignored)` 把所有内容都变成“成功”。它可能吞掉严重错误、中断信号和真正需要终止的故障。

### 2.2 受检异常和非受检异常怎样理解

受检异常（checked exception）会进入方法签名：

```java
static String load(Path path) throws IOException {
    return Files.readString(path);
}
```

调用方必须选择捕获或继续传播。它适合提醒调用者：即使输入合理，外部操作仍可能因文件、网络或环境失败。

非受检异常不要求写进 `throws`：

```java
throw new IllegalArgumentException("blank device code");
```

它常用来表示调用契约被违反、非法状态或无法在当前层恢复的程序问题。

这不是“可恢复就 checked，不可恢复就 runtime”的绝对公式。真正选择要看 API 边界、调用者能否采取有意义行动以及团队约定。关键是合同一致，而不是随意把所有异常包装成同一种。

## 3. 异常怎样传播、捕获和转换

### 3.1 throws 表示当前方法不在这里处理

```java
static List<String> loadLines(Path path) throws IOException {
    return Files.readAllLines(path, StandardCharsets.UTF_8);
}
```

`throws IOException` 不会创建异常，也不会自动记录日志。它只是声明：如果读取过程产生这种失败，当前方法允许它继续交给调用者。

### 3.2 catch 只在当前层能采取行动时使用

```java
try {
    String json = Files.readString(path, StandardCharsets.UTF_8);
    importJson(json);
} catch (NoSuchFileException error) {
    System.err.println("import file does not exist: " + path);
}
```

一个有价值的 `catch` 通常会做至少一件事：

- 使用备用方案；
- 把技术失败转换成当前层可理解的结果；
- 添加必要上下文后继续传播；
- 清理或补偿已经开始的动作；
- 在程序边界决定日志、用户消息或退出状态。

下面的写法会让程序看似成功，实际数据没有导入：

```java
try {
    importFile(path);
} catch (Exception ignored) {
}
```

这叫吞异常。除非合同明确允许忽略，并且有可观察记录，否则不要这样做。

### 3.3 从具体到宽泛排列 catch

```java
try {
    importFile(path);
} catch (NoSuchFileException error) {
    // 更具体的文件不存在
} catch (IOException error) {
    // 其他 I/O 失败
}
```

子类型必须放在父类型前面，否则更宽的 `catch` 已经拦住所有子类型，后面的分支无法到达。

### 3.4 转换异常时保留原始原因

底层 `IOException` 对业务调用者可能太技术化，可以在边界转换：

```java
try {
    return Files.readString(path, StandardCharsets.UTF_8);
} catch (IOException cause) {
    throw new ImportException("cannot read work-order import", cause);
}
```

第二个构造参数保存原异常作为 **cause**。日志和堆栈仍能追到最初文件失败。只创建一条新消息而丢掉 cause，会切断诊断链。

异常消息应该提供必要上下文，但不要回显令牌、完整用户隐私、密钥或大段原始输入。

### 3.5 finally 和资源清理

`finally` 会在 `try` 正常结束或抛异常后执行，适合必须完成的清理：

```java
Resource resource = open();
try {
    use(resource);
} finally {
    resource.close();
}
```

但文件、流、Socket 等实现 `AutoCloseable` 的资源，优先使用 `try-with-resources`，它能正确处理关闭顺序和关闭时的附加异常。

## 4. try-with-resources：谁打开，谁负责关闭

```java
try (BufferedReader reader = Files.newBufferedReader(
        path, StandardCharsets.UTF_8)) {
    return reader.readLine();
}
```

离开 `try` 时，无论正常返回还是发生异常，`reader.close()` 都会被调用。

多个资源按声明的相反顺序关闭：

```java
try (InputStream input = Files.newInputStream(source);
     OutputStream output = Files.newOutputStream(target)) {
    input.transferTo(output);
}
```

### 4.1 资源所有权

最重要的判断是：谁创建资源，谁拥有关闭责任？

- 方法内部打开文件流，通常也应在方法内部关闭；
- 调用者传入已经打开的流时，要由合同说明当前方法是否负责关闭；
- `System.in`、`System.out` 是进程级标准流，普通小方法通常不应随意关闭；
- 返回惰性读取结果时，资源生命周期必须和消费者行为一起设计。

双重关闭有些资源可能无害，有些会产生额外失败；完全不关闭则可能耗尽文件描述符。让所有权在 API 上清楚，比到处补 `close()` 更可靠。

### 4.2 关闭时也可能失败

如果业务代码先抛异常，随后关闭资源又失败，try-with-resources 会保留主要异常，并把关闭失败放入 suppressed exceptions。诊断复杂 I/O 时可以查看 `getSuppressed()`，不要假设堆栈只有一个失败原因。

## 5. 字节流和字符流：先分清数据是什么

文件和网络底层传输的是字节。图片、压缩包、PDF 等二进制数据适合字节流：

- `InputStream` 读取字节；
- `OutputStream` 写入字节。

文本需要把字节按字符集解码成字符：

- `Reader` 读取字符；
- `Writer` 写入字符。

```java
try (Reader reader = Files.newBufferedReader(
        path, StandardCharsets.UTF_8)) {
    // 按字符读取文本
}
```

### 5.1 编码必须在读写两端一致

同一串中文写成 UTF-8 字节，却用其他字符集解码，就会乱码。不要依赖机器默认字符集：

```java
String text = Files.readString(path, StandardCharsets.UTF_8);
Files.writeString(target, text, StandardCharsets.UTF_8);
```

字符集声明和真实字节必须一致。文件扩展名叫 `.json` 并不能证明内容真是 UTF-8 或合法 JSON。

### 5.2 缓冲减少大量小操作

`BufferedReader`、`BufferedWriter` 会在内存中暂存一批数据，减少频繁底层读写。缓冲区没有提交前，数据不一定已经到达目标，因此需要正常关闭或按合同 `flush()`。

不要无条件把整个巨大文件读进一个字符串。小配置和受控导入文件可以 `readString`；大文件应流式处理并设置大小上限。

## 6. Path 和 Files：把路径与文件操作分开

`Path` 表示一个路径值：

```java
Path path = Path.of("data", "work-orders.json");
```

它本身不表示文件一定存在，也不会因为创建 `Path` 就访问磁盘。`Files` 提供实际操作：

```java
boolean exists = Files.exists(path);
String json = Files.readString(path, StandardCharsets.UTF_8);
```

### 6.1 相对路径依赖当前工作目录

```java
Path path = Path.of("data", "work-orders.json");
```

这是相对路径，要从当前进程的工作目录解析。IDE、Maven 和终端可能使用不同工作目录，因此“同一段代码在终端能找到、IDE 找不到”常常不是文件消失，而是解析起点不同。

调试时可以查看：

```java
System.out.println(Path.of("").toAbsolutePath());
System.out.println(path.toAbsolutePath().normalize());
```

不要把个人电脑的绝对路径硬编码进可移植项目。应用数据、classpath 资源和用户上传文件也不是同一种定位方式，应分别设计。

### 6.2 normalize 和 toRealPath 不一样

`normalize()` 只在路径文本层面消除多余的 `.` 和可配对的 `..`，不保证目标存在，也不解析符号链接。

`toRealPath()` 会访问文件系统，要求路径存在，并解析真实路径规则。安全检查不能只做字符串前缀比较；不可信文件名还要考虑 `..`、绝对路径、符号链接和平台差异。

### 6.3 常见文件操作

```java
Files.createDirectories(directory);
Files.copy(source, target);
Files.move(source, target);
Files.deleteIfExists(target);
```

覆盖、保留属性、是否原子移动等行为由选项和文件系统能力决定。不要在不确认目标的情况下递归删除或覆盖用户文件。

### 6.4 安全写文件：先写临时文件，再替换

直接覆盖目标文件时，进程中途失败可能留下半份内容。较稳妥的常见思路是：

1. 在同一文件系统的临时路径写完整内容；
2. 正常关闭并确认写入；
3. 使用移动替换正式文件；
4. 文件系统支持时请求原子移动；
5. 失败时保留或清理临时文件，并明确恢复策略。

```java
Files.move(temp, target,
        StandardCopyOption.REPLACE_EXISTING,
        StandardCopyOption.ATOMIC_MOVE);
```

不是所有文件系统都支持原子移动，可能抛出 `AtomicMoveNotSupportedException`。是否允许退化成普通替换由业务风险决定。

## 7. Java 时间：先决定你在表达哪一种时间

“时间”不是一个统一类型：

| 类型 | 表达什么 | 常见场景 |
| --- | --- | --- |
| `Instant` | 全球时间线上的瞬间 | 事件创建时间、审计时间 |
| `LocalDate` | 不带时区的日历日期 | 保养日期、生日 |
| `LocalTime` | 一天中的本地时间 | 每日班次开始时间 |
| `LocalDateTime` | 本地日期与时间，无时区 | 尚未绑定地区的计划时间 |
| `OffsetDateTime` | 日期时间加固定偏移 | API 中保留调用时偏移 |
| `ZonedDateTime` | 日期时间加地区时区规则 | 按具体地区安排日程 |
| `Duration` | 秒和纳秒意义的持续量 | 请求耗时、超时 |
| `Period` | 年月日意义的日历差 | 每三个月保养 |

### 7.1 Instant 适合跨系统事件时间

```java
Instant createdAt = Instant.now();
```

它不依赖当前机器怎样显示本地时间。展示给用户时，再结合 `ZoneId` 转换：

```java
ZonedDateTime local = createdAt.atZone(ZoneId.of("Asia/Shanghai"));
```

### 7.2 LocalDateTime 不能独自表示唯一瞬间

`2026-11-01T01:30` 在某些有夏令时切换的地区可能出现两次，也可能有本地时间根本不存在。要把它变成时间线瞬间，必须有时区规则或偏移。

因此不能把服务器默认时区悄悄当成所有业务时区：

```java
ZoneId.systemDefault()
```

它在开发机和生产容器中可能不同。业务时区应来自明确配置或数据。

### 7.3 当前时间是一项依赖

规则内部到处直接调用 `Instant.now()`，测试就会随真实时钟变化。可以传入 `Clock`：

```java
class SlaCalculator {
    private final Clock clock;

    SlaCalculator(Clock clock) {
        this.clock = clock;
    }

    Instant now() {
        return Instant.now(clock);
    }
}
```

生产使用系统时钟，测试使用固定时钟。这样“现在”从隐藏输入变成可见依赖。

### 7.4 格式化不是时间语义

`DateTimeFormatter` 负责文本格式与时间对象互转，但格式正确不代表业务时间有效。解析 API 时间时应规定是否要求偏移、是否允许无时区文本、精度到秒还是毫秒。

## 8. JSON：一种数据交换格式，不是 Java 对象本身

JSON 只有六类值：

- object；
- array；
- string；
- number；
- boolean；
- null。

```json
{
  "id": "WO-1001",
  "priority": 5,
  "urgent": true,
  "assignee": null
}
```

JSON 中没有 Java 的 `Instant`、`BigDecimal`、枚举或构造器。程序必须决定某段 JSON 文本怎样映射成 Java 类型，以及映射后还要检查哪些业务规则。

### 8.1 序列化和反序列化

- **序列化**：Java 数据变成 JSON；
- **反序列化**：JSON 变成 Java 数据。

反序列化风险通常更高，因为输入可能不可信：字段类型错误、层级过深、数字过大、未知字段、超长字符串都可能进入解析器。

### 8.2 使用成熟映射库，不手写通用 JSON 解析器

项目中常用 Jackson 等库：

```java
ObjectMapper mapper = new ObjectMapper();
WorkOrderInput input = mapper.readValue(json, WorkOrderInput.class);
String output = mapper.writeValueAsString(input);
```

这段代码依赖项目已经加入相应库。映射器配置应由应用集中管理，特别是时间模块、未知字段策略、命名规则和安全限制；不要在每个方法里临时创建一套不一致配置。

教学中可以手写只支持一个固定格式的小解析器来理解边界，但不能把它扩展成生产通用 JSON 解析器。

## 9. JSON 映射中最容易混淆的边界

### 9.1 字段缺失、显式 null 和默认值

下面三段输入语义可能不同：

```json
{}
```

```json
{"assignee": null}
```

```json
{"assignee": ""}
```

- 字段缺失可能表示调用方没有提供；
- 显式 `null` 可能表示清除或明确为空；
- 空字符串是一个真实字符串，通常还要做格式校验。

映射框架可能把前两者压成同一个 Java `null`。若 API 需要区分 PATCH 中的“未修改”和“清空”，必须用更明确的数据模型，不能等映射后再猜。

### 9.2 未知字段策略

新客户端多发一个字段时，旧服务可以：

- 严格拒绝，及时发现拼写和协议错误；
- 宽松忽略，允许向前兼容。

两种都可能合理。外部长期演进协议往往会允许某些未知字段；安全敏感配置可能要求严格。关键是策略要明确、可测试、可观测，不要因为默认配置碰巧如此就当作永久契约。

### 9.3 enum 的外部编码

JSON 中枚举通常还是字符串：

```json
{"status": "IN_PROGRESS"}
```

未知值、大小写、历史别名和未来新增值怎样处理，应由版本策略决定。不要持久化 `ordinal()`，也不要随意让 `toString()` 成为协议值。

### 9.4 金额和 JSON number

JSON number 没有直接规定 Java 二进制浮点语义。十进制金额不应经过 `double` 再转 `BigDecimal`。可以在协议中使用固定小数位字符串、整数分单位或直接精确映射 `BigDecimal`，但必须定义范围、尺度和舍入政策。

### 9.5 时间文本

跨系统事件时间常用包含 `Z` 或偏移的 ISO 8601 文本，例如：

```json
{"createdAt": "2026-07-29T08:30:00Z"}
```

仅有本地日期时间却没有时区时，调用双方可能解释成不同瞬间。协议应明确类型、时区、精度和是否允许缺失。

### 9.6 版本兼容不是无限保留别名

字段改名时可以短期同时接受旧名和新名，但要记录：

- 哪个版本开始迁移；
- 服务端输出哪个规范名；
- 旧名支持到什么时候；
- 如何监控旧客户端仍在使用；
- 移除时怎样发布和回滚。

永久保留每个历史字段会让协议越来越含糊。兼容是一段有退出条件的迁移，不是默认无限累积。

## 10. 从 JSON 到领域对象不要一步揉完

可以把边界分成几个清楚阶段：

```text
原始字节
  → UTF-8 文本
  → JSON 语法树或输入 DTO
  → 字段级格式验证
  → 业务值对象
  → 领域命令或实体
```

输入 DTO 只表示“调用方提交了什么”，领域对象表示“系统认可的合法业务状态”。二者不一定是同一个类。

例如：

```java
record WorkOrderInput(String deviceCode, String createdAt) {
}
```

映射后再转换：

```java
DeviceCode code = new DeviceCode(input.deviceCode());
Instant time = Instant.parse(input.createdAt());
CreateWorkOrder command = new CreateWorkOrder(code, time);
```

这样能区分：

- JSON 语法错误；
- 字段类型或日期格式错误；
- 设备编码业务格式错误；
- 创建工单规则拒绝。

如果所有失败都变成同一句“invalid JSON”，调用者和开发者都无法知道应该修哪一层。

## 11. 不可信文件和 JSON 的安全边界

解析成功不等于输入安全。至少要考虑：

- 文件大小上限；
- JSON 嵌套深度和字符串长度；
- 数组元素数量；
- 数字范围；
- 路径遍历和符号链接；
- 压缩包解压膨胀；
- 反序列化允许创建哪些类型；
- 错误信息是否泄露内部路径或敏感值；
- 导入是否需要权限、租户和审计。

不要让不可信 JSON 提供任意 Java 类名，然后通过反射创建对象。类型白名单和固定 DTO 比“万能多态反序列化”更容易审计。

文件扩展名、Content-Type 或用户提供的类型名称都只是声明，必要时还要检查真实内容和业务权限。

## 12. 失败时怎样按层定位

同一个“导入失败”可能发生在完全不同阶段：

| 证据 | 更可能的层次 |
| --- | --- |
| `NoSuchFileException` | 路径或工作目录 |
| `AccessDeniedException` | 文件权限 |
| 中文乱码但没有异常 | 编码不一致 |
| JSON 语法位置错误 | 文本不是合法 JSON |
| 某字段无法映射成数字/时间 | 数据映射 |
| `IllegalArgumentException` 来自值对象 | 业务格式或范围 |
| 创建工单被拒绝 | 领域规则 |
| 输出文件只写了一半 | 写入和替换策略 |

诊断顺序：

1. 先确定编译、启动、读取、解析、映射还是业务阶段；
2. 找异常链中第一处属于自己代码的行；
3. 查看最具体异常类型和 cause；
4. 固定一个最小输入重现；
5. 一次只验证一个边界；
6. 修复后同时复跑合法输入与原失败输入。

日志应该记录路径的安全标识、导入批次 ID、失败阶段和相关字段名，而不是把整份用户文件或令牌输出。

## 13. 本章必须掌握、见过和查询的内容

必须掌握：

- 异常会沿调用栈传播，`catch` 只在能处理时使用；
- 转换异常要保留 cause，不能静默吞掉；
- `try-with-resources` 管理可关闭资源；
- 字节流与字符流的区别，文本必须明确字符集；
- 相对路径依赖工作目录；
- `Instant`、本地日期时间和时区不是同一概念；
- JSON 解析、映射和业务验证是不同阶段；
- missing、`null`、空字符串和默认值不能随便合并。

见过即可：

- suppressed exceptions；
- 原子移动不受所有文件系统支持；
- `Clock` 能把当前时间变成可替换依赖；
- 未知字段的严格与宽松都是协议策略；
- DTO 与领域对象可以是不同类型。

需要时查询：

- 每个 `Files` 操作的覆盖和链接规则；
- Jackson 当前版本的模块与安全配置；
- 夏令时缺口和重叠的处理 API；
- 大文件流式 JSON、压缩格式和原子持久化细节；
- 自定义异常层次与跨服务错误协议。

把整章记成一条主线即可：外部字节先经过路径、资源、字符集和 JSON 边界，得到经过验证的 Java 数据；任何一层失败都用清楚的异常合同表达，并且无论成功失败都正确释放资源。

