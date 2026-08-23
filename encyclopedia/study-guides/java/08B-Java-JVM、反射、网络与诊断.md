# Java：JVM、反射、网络与诊断

## 1. 从源码到运行中的 JVM

Java 程序经历的主链路是：

```text
.java 源码
  → javac 编译
  → .class 字节码
  → java 启动 JVM 进程
  → 类加载、校验、链接和初始化
  → 找到 main 或其他入口
  → 解释或即时编译并执行方法
```

`javac` 负责把源码编译为 JVM 能理解的 class 文件；`java` 负责启动 JVM，并根据 classpath、模块路径和完整类名装入需要的类。

JVM 不是“直接运行 Java 源码”的抽象说法。虽然某些启动方式可以接收单文件源码，背后仍然包含编译与运行阶段。诊断时要分清失败发生在源码编译、类查找、类初始化还是方法执行。

### 1.1 一份程序可以启动多个进程

同一个 JAR 可以同时运行多次，每次都有独立 JVM 进程、堆、线程和普通静态状态。进程 ID 是临时运行标识，进程重启后可能变化，也可能被操作系统重复使用。

因此：

- `static` 字段不是跨进程全局数据库；
- JVM 内存中的缓存不会自动在多个实例之间同步；
- 杀掉进程不会删除磁盘上的 JAR；
- 删除 JAR 也不会立刻回收已经运行进程占用的内存。

## 2. JVM 运行时内存先建立足够准确的地图

初学时可以分成几类观察区域：

- **Java 堆（heap）**：大部分普通对象和数组的逻辑存放区域，由垃圾收集器管理；
- **线程栈（stack）**：每个线程的方法调用帧、局部变量和操作状态；
- **元空间（metaspace）**：类元数据等本地内存区域；
- **代码缓存**：JIT 编译后的机器代码；
- **直接内存和其他本地内存**：NIO 缓冲、线程栈、JNI、JVM 自身结构等。

这是一张诊断地图，不是源码层可以依赖的精确对象物理布局。JIT 可能做逃逸分析、标量替换等优化；“所有局部变量永远在栈、所有对象永远固定在堆地址”是过度简化。

### 2.1 不同内存耗尽不是同一问题

常见错误可能包括：

- `Java heap space`：Java 堆无法满足分配；
- `Metaspace`：类元数据区域受限；
- `unable to create native thread`：操作系统线程或本地资源不足；
- direct buffer memory：直接缓冲区相关限制；
- `StackOverflowError`：单线程调用栈过深，常见于无终止递归。

看到 `OutOfMemoryError` 不能只把 `-Xmx` 调大。先识别具体区域、对象增长来源和外部限制；增加上限可能只把泄漏推迟。

## 3. 垃圾收集：回收不可达对象，不替你管理所有资源

JVM 根据对象是否仍可从 GC Roots 等位置到达，决定它是否有资格被回收。变量离开作用域不代表对象立刻回收；对象不可达也不保证在某个确定时刻马上收集。

垃圾收集主要管理 Java 内存，不替代显式关闭文件、Socket、数据库连接和执行器。一个对象最终会被 GC，不代表其外部资源可以一直占用。

### 3.1 分代直觉

很多应用会快速创建大量短命对象，少部分对象存活很久。分代收集器利用这种常见行为，把新对象和长期存活对象分开处理。但“年轻对象一定在某块固定地址”“对象达到某次数必然晋升”等内部细节会受收集器和参数影响，不应成为业务逻辑。

### 3.2 G1 的定位

在 JDK 25 的大多数常见硬件与操作系统配置中，G1 是默认垃圾收集器。它把堆划分成多个 region，按收益优先回收，并把一部分工作与应用并发执行，目标是在吞吐与暂停时间之间取得平衡。

“Garbage First” 不表示完全没有 stop-the-world 暂停，也不承诺每次都精确满足暂停目标。活跃数据量、分配速度、堆大小、CPU 和引用处理都会影响结果。

选择或调优 GC 前先收集：

- 堆上限与实际使用；
- 分配速率；
- GC 暂停分布；
- GC 后存活量；
- CPU 使用；
- 请求延迟和吞吐；
- 是否存在对象持续增长。

没有证据时先让 JVM 使用合理默认值，而不是复制一串来历不明的 `-XX` 参数。低延迟、最高吞吐和最小内存占用往往不能同时最大化。

## 4. 类加载不是简单“找到文件”

JVM 使用类加载器把 class 定义装入运行时。可以把完整过程先分为：

1. **加载（loading）**：根据名字找到字节并创建对应 `Class` 表示；
2. **链接（linking）**：验证 class、准备静态字段存储、解析符号引用；
3. **初始化（initialization）**：按规则执行静态字段初始化器和静态块。

加载到类定义不等于已经执行类初始化。某些主动使用才触发初始化，编译期常量读取还可能绕过声明类初始化。

### 4.1 Class 对象表示运行时类型

获取 `Class` 的常见方式：

```java
Class<WorkOrder> literal = WorkOrder.class;
Class<?> runtime = order.getClass();
Class<?> byName = Class.forName("com.factorycare.WorkOrder");
```

- `.class` 不需要先有实例；
- `getClass()` 取得实际对象运行时类；
- `Class.forName(...)` 按二进制类名查找，并且常见重载会触发初始化。

`Class<T>` 常用作类型令牌，让泛型 API 在运行时保留一部分明确类型信息。

### 4.2 同名类不一定是同一运行时类型

JVM 中的类身份包含类的二进制名字和定义它的类加载器。两个不同类加载器各自装入同名字节时，得到的类型可能彼此不可赋值。这能解释插件系统中“类名一模一样却转型失败”的问题。

### 4.3 父级委派

常见类加载器会先把加载请求交给父级，再尝试自己查找。这有助于核心类保持唯一可信定义，也避免应用伪造 `java.*` 核心类。

插件、应用服务器和模块化环境可能使用更复杂加载器层次。不要假设系统 classpath 上的类一定能被所有插件加载器看见。

### 4.4 两类常见“找不到类”

- `ClassNotFoundException` 常见于代码主动按名字加载，但所选加载器找不到目标；
- `NoClassDefFoundError` 常见于某个类编译时存在，运行时解析依赖却无法得到定义，或该类之前初始化失败。

它们都不能只靠“把 JAR 再加一遍”盲修。检查完整类名、classpath/module path、实际加载器、依赖版本、类初始化 cause 和是否有重复类。

## 5. classpath 和资源路径是两套查找概念

完整类名 `com.factorycare.Main` 会相对 classpath 根查找类似：

```text
com/factorycare/Main.class
```

classpath 必须指向这棵目录的根或包含该条目的 JAR，不是直接指向 `Main.class` 所在包目录。

类路径资源可以使用类加载器读取：

```java
try (InputStream input =
        WorkOrderService.class.getResourceAsStream("/defaults.json")) {
    // ...
}
```

它和 `Path.of("defaults.json")` 不同：

- `Path` 通常访问文件系统并受工作目录影响；
- classpath resource 由类加载器从目录或 JAR 中查找；
- JAR 内资源不一定能当普通可写文件使用。

配置、模板和用户上传文件要先明确属于哪一种资源，再选择 API。

## 6. 注解：给程序元素附加结构化元数据

注解本身通常不执行行为：

```java
@Deprecated
void oldMethod() {
}
```

它只是声明元数据。编译器、测试框架、运行时反射或注解处理器是否读取它，才决定后续发生什么。看到 `@Transactional`、`@Test` 或自定义注解，不能说“注解自己拦截了方法”。

### 6.1 声明注解接口

```java
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface RequiresRole {
    String value();
}
```

使用：

```java
@RequiresRole("TECHNICIAN")
public void completeWorkOrder() {
}
```

注解元素可用类型受语言限制，常见包括基本类型、`String`、`Class`、枚举、其他注解及其数组。它不是任意 Java 对象字段。

### 6.2 @Target：允许注解放在哪里

`@Target` 可以限制注解用于类、方法、字段、参数或类型使用位置等。把注解放错位置时，编译器会阻止。

声明注解和类型使用注解要区分：

```java
@Marker String value;       // 声明位置
List<@NonNull String> names; // 类型使用位置
```

后者可为静态分析工具表达更细类型信息，但是否真正执行检查取决于工具链。

### 6.3 @Retention：元数据保留到哪一阶段

| 策略 | 保留范围 | 常见用途 |
| --- | --- | --- |
| `SOURCE` | 只在源码阶段 | 编译检查、源码工具 |
| `CLASS` | 写入 class，但运行时反射不保证可见 | 字节码工具 |
| `RUNTIME` | 运行时反射可读取 | 测试框架、运行时框架 |

运行时读不到注解时，先检查 retention，而不是立即怀疑反射失效。

### 6.4 编译期处理与运行时反射不同

注解处理器在编译阶段读取注解，可以生成源码或资源；运行时反射则在程序执行时读取已保留元数据。二者的阶段、权限和可重复构建要求不同。

自动生成代码应由构建工具显式配置，不能依赖某台 IDE 恰好启用了处理器。生成结果、输入版本和失败日志都要可复现。

## 7. 反射：运行时检查类型和成员

普通代码在编译时写死成员调用：

```java
order.status();
```

反射允许程序在运行时取得 `Class`、查找字段、方法和构造器，再动态操作：

```java
Method method = WorkOrder.class.getMethod("status");
Object result = method.invoke(order);
```

这适合框架、序列化、测试引擎、依赖注入容器和插件系统。普通业务代码已知类型时，直接调用更安全、清楚，也更容易由编译器重构。

### 7.1 public 成员和 declared 成员

- `getMethod` 查找公开方法，并考虑继承；
- `getDeclaredMethod` 查找当前类声明的方法，不自动包含父类成员；
- 字段、构造器也有相应 public/declared API。

方法查找需要精确参数类型：

```java
getMethod("assign", TechnicianId.class)
```

只给方法名无法区分重载。

### 7.2 invoke 会包装目标方法异常

如果被调用方法本身抛异常，`Method.invoke` 通常抛 `InvocationTargetException`。真正业务原因在 `getCause()`：

```java
try {
    method.invoke(target);
} catch (InvocationTargetException error) {
    Throwable cause = error.getCause();
}
```

日志只记录外层“反射调用失败”而不保留 cause，会掩盖真正规则错误。

### 7.3 反射不能假装访问边界不存在

访问私有成员时可能遇到语言访问检查、模块 `exports/opens` 和运行环境限制。`trySetAccessible()` 只是在规则允许时尝试开放，不保证成功。

不要为了序列化方便就把整个模块开放，也不要把反射当作绕过领域 API 的日常写法。框架使用反射时，应限定扫描范围、成员类型和可见性策略。

### 7.4 不可信类名和成员名

下面的设计风险很高：

```java
Class<?> type = Class.forName(userInput);
```

若外部用户能决定任意类名、方法名或构造参数，程序可能访问本不应触及的类型，触发类初始化副作用或扩大攻击面。使用固定白名单或注册表，把外部协议值映射到明确实现：

```java
Map<String, Class<? extends Command>> allowed = Map.of(...);
```

反射提供技术能力，不提供授权。

## 8. 动态代理：在接口调用前后统一增加行为

JDK 动态代理可以在运行时创建一个实现指定接口的代理对象：

```java
NotificationSender proxy = (NotificationSender) Proxy.newProxyInstance(
        NotificationSender.class.getClassLoader(),
        new Class<?>[]{NotificationSender.class},
        handler
);
```

调用代理方法时，`InvocationHandler` 收到代理对象、被调用方法和参数：

```java
Object invoke(Object proxy, Method method, Object[] args) throws Throwable
```

处理器可以：

1. 检查权限；
2. 记录开始时间；
3. 调用真实目标；
4. 记录结果或失败；
5. 返回原方法结果。

### 8.1 JDK 动态代理主要代理接口

目标没有接口时，JDK `Proxy` 不能凭空代理普通类。其他框架可能通过生成子类实现类代理，但会受到 `final` 类、`final` 方法、构造器和模块边界影响。Spring AOP 会在后续章节具体学习。

### 8.2 代理必须保持原合同

代理不能忘记返回真实结果，也不能把所有异常都改成无关类型。还要正确处理 `equals`、`hashCode`、`toString` 和默认接口方法等边界。

日志代理不可打印密码、令牌或完整用户输入；授权代理必须以可信身份上下文判断，不能只检查一个可伪造字符串参数。

### 8.3 何时普通装饰器更好

如果只有一个接口、两三个方法，并且行为稳定，手写类通常更清楚：

```java
final class AuditingSender implements NotificationSender {
    private final NotificationSender delegate;

    // 明确调用、明确返回、编译器可检查
}
```

动态代理适合大量统一横切行为，不能仅为少写一个类就增加运行时复杂度。

这一组必须掌握：注解是元数据，读取者才产生行为；反射在运行时检查类型，动态代理拦截接口调用；这些机制常用于框架，但不替代访问控制、业务合同和授权。

## 9. 网络编程先从分层和端点开始

网络调用可以粗略看成：

```text
应用协议（HTTP、你的消息格式）
  → 传输协议（TCP 或 UDP）
  → IP 路由
  → 网络接口和物理链路
```

一个网络端点通常由地址和端口组成。主机名不是 IP 地址，DNS 负责把名字解析到一个或多个地址。`localhost`/loopback 只在当前机器内部回环，不能代表外部网络真实可达。

### 9.1 端口 0 的测试用途

本地测试服务可以绑定端口 `0`，让操作系统选择一个空闲端口，然后通过 API 读取实际端口。这样比硬编码 `8080` 更少与其他进程冲突。

不要扫描、连接或结束不属于当前任务的进程和端口。网络测试优先使用自己启动的 loopback 服务。

## 10. TCP Socket：可靠有序的字节流

客户端连接：

```java
try (Socket socket = new Socket()) {
    socket.connect(address, connectTimeoutMillis);
    socket.setSoTimeout(readTimeoutMillis);
    // 使用输入输出流
}
```

TCP 提供有序字节流，不保留应用消息边界。一次 `write` 不保证接收端一次 `read` 正好读到同样一段；读取也可能只得到部分数据。

### 10.1 应用协议必须定义 framing

常见消息边界方式：

- 固定长度；
- 分隔符；
- 长度前缀；
- 连接关闭表示结束；
- 使用 HTTP 等已有协议。

长度前缀协议也必须设置最大允许长度，不能相信对端声称“下一条消息有 20 GB”后直接分配数组。

### 10.2 三种超时不是一回事

- 连接超时：建立连接最多等多久；
- 读取超时：连接建立后等响应数据多久；
- 整体业务截止时间：包括 DNS、连接、写入、读取、解析和重试的总预算。

某些 API 没有简单的“写超时”选项。超时发生也不代表对端没有完成操作，因此重试写请求前要考虑幂等性。

### 10.3 flush 和关闭

带缓冲输出需要按协议 `flush()`，但频繁 flush 会影响效率。关闭 Socket 通常会关闭关联流；所有权要集中，避免一层关闭后另一层仍尝试使用。

## 11. UDP Datagram：一条发送对应一个报文

UDP 保留报文边界，但不保证：

- 到达；
- 只到达一次；
- 按顺序到达；
- 不被截断；
- 自动重传。

```java
DatagramSocket socket = new DatagramSocket();
DatagramPacket packet = new DatagramPacket(bytes, bytes.length, address);
socket.send(packet);
```

接收缓冲区太小时，报文可能被截断。应用如果需要可靠性、去重、顺序或确认，必须自行设计，或者直接选择 TCP/HTTP。

UDP 的 `connect` 只是限定默认对端和过滤部分数据，不建立 TCP 那样的可靠连接。

## 12. URI、URL 和 HttpClient

`URI` 表示结构化资源标识：

```java
URI uri = URI.create("https://api.example.com/work-orders/WO-1001");
```

它能解析 scheme、host、path、query 等组成，但一个 URI 格式合法不代表目标可信、当前用户有权限或网络可达。

### 12.1 复用 HttpClient

```java
HttpClient client = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(2))
        .build();
```

`HttpClient` 适合复用，以利用连接管理。请求单独定义方法、URI、Header、body 和超时：

```java
HttpRequest request = HttpRequest.newBuilder(uri)
        .timeout(Duration.ofSeconds(5))
        .GET()
        .build();

HttpResponse<String> response = client.send(
        request,
        HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8)
);
```

### 12.2 HTTP 状态和 body 要分别处理

网络调用正常返回不代表业务成功：

```java
int status = response.statusCode();
String body = response.body();
```

`404`、`409`、`500` 都是成功收到的 HTTP 响应，不一定抛网络异常。先按状态合同处理，再决定是否解析 body。错误 body 也可能很大或含敏感内容，不能无上限读入和记录。

### 12.3 重定向和重试是安全决策

自动跟随重定向可能把认证 Header 或请求带到意外主机；重试非幂等请求可能重复创建工单。明确允许的主机、协议、重定向范围、请求幂等键和重试条件。

### 12.4 TLS 不只是“地址以 https 开头”

TLS 负责加密传输、验证服务器身份和保护完整性。客户端需要可信证书链和主机名验证。不要为解决本地证书错误就在生产代码中信任所有证书或关闭主机名检查。

自定义 `SSLContext`、代理和证书库都是部署边界，必须有明确配置和安全审查。

## 13. 网络故障要按阶段分类

| 现象 | 可能阶段 |
| --- | --- |
| 主机名无法解析 | DNS |
| `Connection refused` | 地址可达但端口无人监听，或主动拒绝 |
| 连接超时 | 路由、防火墙、远端不响应等 |
| 读取超时 | 已连接但迟迟没有足够响应 |
| TLS 握手失败 | 信任、证书、主机名、协议不匹配 |
| HTTP 401/403 | 应用身份或授权 |
| HTTP 5xx | 远端应用失败，不一定是网络断开 |
| JSON 解析失败 | 收到 body，但内容不符合预期 |

“请求失败”不能直接等于“网络问题”。保留目标主机的安全标识、阶段、持续时间、状态码、重试次数和异常 cause，才能在正确层修复。

## 14. 日志：给事件留下可查询证据

日志不是把变量随手拼成散文。一个有用事件通常包含：

- 时间；
- 级别；
- 事件名称；
- correlation ID / trace ID；
- 业务对象的安全标识；
- 结果和耗时；
- 异常类型与 cause；
- 必要的环境或版本信息。

结构化形式更容易检索：

```text
event=work_order_import_failed batchId=B-42 stage=json_parse
```

### 14.1 日志级别表达运营含义

- `ERROR`：当前操作失败，需要关注；
- `WARN`：出现异常情况或降级，但系统仍能继续；
- `INFO`：重要业务或生命周期事件；
- `DEBUG`：开发诊断细节；
- `TRACE`：更细粒度的高量信息。

不要把预期的用户输入校验都记成系统 ERROR，也不要把真实数据丢失只记成 DEBUG。级别应帮助告警和排障，而不是表达开发者情绪。

### 14.2 correlation ID 串起一次工作流

一个 HTTP 请求可能经过 Controller、服务、数据库和外部通知。各层记录同一个 correlation ID，可以把分散事件串起来。它不是认证凭据，也不能由不可信输入无限制覆盖。

### 14.3 异常只在负责的边界记录

每层都记录同一个异常会生成五份重复堆栈。一般在能够补充关键上下文或最终决定失败的边界记录一次，并保留 cause。底层库可以传播，不必每层“log and throw”。

### 14.4 敏感信息和日志注入

绝不记录密码、访问令牌、完整 Cookie、私钥和不必要的个人数据。用户文本中的换行和控制字符还可能伪造日志行；结构化日志库和安全编码能降低风险。

日志本身也有容量和权限成本。采样、保留周期、访问控制和脱敏属于系统设计的一部分。

## 15. jcmd、线程转储和 JFR 各回答什么问题

### 15.1 jcmd 是 HotSpot 的主要诊断入口

先列出当前用户可见的 Java 进程：

```bash
jcmd -l
```

查询某个 JVM 支持的命令：

```bash
jcmd <pid> help
```

常见只读或采样命令包括：

```bash
jcmd <pid> VM.command_line
jcmd <pid> GC.heap_info
jcmd <pid> Thread.print -l
jcmd <pid> Thread.dump_to_file -format=json threads.json
```

命令和影响级别会随 JDK 版本及 JVM 实现变化，实际使用前先运行 `help <command>`。`jcmd` 通常要在同一机器，并使用与目标 JVM 相同的有效用户/组权限；不要对不属于自己的生产进程采样。

### 15.2 线程转储是一张瞬时照片

线程 dump 展示采样时各线程的堆栈、状态和锁信息，适合分析：

- 死锁；
- 长时间等待；
- 热点调用位置；
- 线程数量异常；
- 哪个线程持有什么锁。

一次快照可能碰巧采到正常等待。间隔取得多份，并结合请求进展、CPU 和队列指标，才能判断线程是否真正卡住。

### 15.3 JFR 是一段时间内的事件记录

Java Flight Recorder（JFR）可以低开销记录一段时间内的线程、锁、分配、GC、I/O 和其他 JVM 事件：

```bash
jcmd <pid> JFR.start name=diagnosis duration=60s filename=diagnosis.jfr
```

之后可用 `jfr summary`、`jfr view` 或 JDK Mission Control 分析。JFR 比单张线程 dump 更适合回答“过去一分钟发生了什么、峰值前后有什么变化”。

采样也有成本和隐私边界。先确认目标、时长、配置、文件位置和谁能读取，再在生产环境运行。

## 16. JVM 统一日志和 GC 证据

JVM 可以通过统一日志输出 GC、类加载等信息，例如项目可能使用：

```bash
java -Xlog:gc* -jar app.jar
```

具体标签、级别、文件轮转和格式应按当前 JDK `java -Xlog:help` 查询。

分析 GC 时不要只数次数。把以下时间线对齐：

- 请求延迟峰值；
- CPU；
- 堆使用和 GC 后存活量；
- 分配速率；
- GC 暂停；
- 线程、连接池和队列；
- 部署或流量变化。

“发生 GC 时应用慢”不一定说明 GC 是根因；高分配可能是业务流量上升的共同结果。需要从时间相关性走向可证伪假设。

## 17. 一套可靠的 JVM 故障诊断流程

### 17.1 先写清症状

不要只写“Java 很慢”。记录：

- 哪个行为慢或失败；
- 从什么时候开始；
- 影响哪些请求或租户；
- 延迟、错误率、吞吐或内存具体怎样变化；
- 最近有什么部署、配置或流量变化。

### 17.2 提出可以被证伪的假设

例如：

- 线程都在等待同一个锁；
- 数据库连接池耗尽；
- 某类对象持续增长；
- GC 暂停造成尾延迟；
- DNS 或远端服务超时；
- 类加载器无法释放，导致 metaspace 增长。

每个假设都要对应证据。线程锁假设看多份线程 dump；对象增长看 heap/JFR/类直方图；远端超时看网络阶段和调用指标。

### 17.3 先用低风险证据

通常从日志、指标、健康状态和低影响 `jcmd` 命令开始。堆转储可能很大、会带来暂停并包含敏感数据；主动 `GC.run` 也会改变现场。高影响操作前必须有权限、磁盘容量和回滚计划。

### 17.4 把结论分级

- **已观察事实**：三份线程 dump 中同一批线程都等待同一锁；
- **当前解释**：锁竞争很可能造成请求排队；
- **尚未验证**：某次提交是否引入该锁范围；
- **下一步证据**：对比提交、在测试环境重放并测量。

不要把一次相关性直接写成确定根因。

## 18. 本章掌握边界

必须掌握：

- 源码、class、JVM 进程和类加载的关系；
- 堆、线程栈、元空间和本地资源的大致职责；
- GC 回收不可达 Java 对象，不替代资源关闭；
- 注解是元数据，处理者才产生行为；
- 反射通过 `Class` 和成员对象进行运行时检查；
- JDK 动态代理围绕接口和 `InvocationHandler` 工作；
- TCP 是字节流，必须有消息边界和超时；
- HTTP 状态、网络异常、TLS 和 JSON 解析是不同阶段；
- 结构化日志、线程 dump、JFR 和 GC 日志分别提供什么证据。

见过即可：

- 类加载器身份与父级委派；
- 模块 `exports/opens` 对反射的影响；
- UDP 的报文与不可靠交付；
- G1 region、并发和暂停目标；
- JFR 与 `jcmd` 的常见命令。

需要时查询：

- JVM 规范中的加载、链接与初始化细则；
- 当前 JDK 的反射、代理和模块访问规则；
- Socket 半关闭、TLS 配置和代理行为；
- GC 参数、JFR 配置和 heap dump 分析；
- 生产诊断命令的权限、影响级别和数据合规。

本章可以记成一条证据链：JVM 把 class 装入进程并管理线程与内存；注解、反射和代理让框架在运行时发现并包裹行为；网络把程序带到进程外部；日志、dump、JFR 和 GC 事件则让这些运行时行为重新变得可观察。任何结论都要和对应层次的证据匹配。

