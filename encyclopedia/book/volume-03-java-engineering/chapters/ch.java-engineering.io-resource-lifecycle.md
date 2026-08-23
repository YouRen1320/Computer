---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.io-resource-lifecycle
title: 字节流、字符流、资源所有权与 try-with-resources
responsibility: 教授具体 IO 资源的所有权和确定性关闭，不在本章处理 NIO 原子移动或 JSON 映射
volume: '03'
order: 9
level: L1
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.io-resource-lifecycle.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.exceptions-failure-contracts
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
  text: 在 120 秒内解释字节流、字符流、资源所有权与 try-with-resources的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-io-streams
  - java-resource-lifecycle
  covers_topics:
  - java.input-output-stream
  - java.reader-writer
  - java.buffering
  - java.closeable-owner
  - java.try-with-resources
  - java.suppressed-exception
  uses_capabilities:
  - foundation.files-path-encoding
  - java.inheritance-polymorphism
  - java.methods
  - java.exceptions-resources
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现UTF-8文本复制：声明checked/unchecked失败契约、保留cause，明确输入/输出流所有者并用try-with-resources关闭
  covers_topic_groups:
  - java-io-streams
  - java-resource-lifecycle
  covers_topics:
  - java.input-output-stream
  - java.reader-writer
  - java.buffering
  - java.closeable-owner
  - java.try-with-resources
  - java.suppressed-exception
  uses_capabilities:
  - foundation.files-path-encoding
  - java.inheritance-polymorphism
  - java.methods
  - java.exceptions-resources
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入catch吞错、cause丢失、流未关闭、关闭异常覆盖读取异常，检查堆栈/句柄/suppressed后修复
  covers_topic_groups:
  - java-io-streams
  - java-resource-lifecycle
  covers_topics:
  - java.input-output-stream
  - java.reader-writer
  - java.buffering
  - java.closeable-owner
  - java.try-with-resources
  - java.suppressed-exception
  uses_capabilities:
  - foundation.files-path-encoding
  - java.inheritance-polymorphism
  - java.methods
  - java.exceptions-resources
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 字节流、字符流、资源所有权与 try-with-resources

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《异常分类、传播、捕获、转换与失败契约》](../../volume-02-java-objects/chapters/ch.java-oop.exceptions-failure-contracts.md)：独立完成字节流与字符流、资源所有权前，必须先具备「异常分类、传播、捕获、转换与失败契约」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文与工件用于学习和作者验证，不代表学习者已独立通过 G1，也不会自动更新 `PROGRESS.md`。

Java 程序读取文件、网络响应或内存数据时，都面对同一类问题：数据按什么单位流动？谁创建资源、谁负责关闭？读取到一半失败时，输入和输出能否确定释放？主体异常与关闭异常同时出现时，哪一个是主失败？如果这些问题只靠“最后记得 close”，资源泄漏和证据丢失迟早发生。

本章从 `InputStream`/`OutputStream` 的字节世界进入 `Reader`/`Writer` 的字符世界，再用缓冲装饰器、明确所有权和 try-with-resources 建立确定生命周期。贯穿任务是离线复制固定 UTF-8 文本并保留失败因果。本章不处理 NIO 原子替换、目录遍历、JSON 映射或网络协议；这些属于后续边界。Java 25 一手资料复核日期为 **2026-07-16**。

## 1. 本章完成证据

至少留下三类证据：

1. **解释**：120 秒内区分字节流和字符流，说明缓冲解决什么、flush 与 close 有何不同，以及“创建者关闭、借用者不关闭”的所有权规则。
2. **构建**：复制普通与空 UTF-8 文本；输入、输出、桥接器和缓冲器由一个清晰边界创建并用 try-with-resources 关闭；失败被转换且 cause 保留。
3. **诊断**：真实注入 catch 吞错、cause 丢失、流未关闭和关闭异常覆盖读取异常；断言关闭事件、主异常与 suppressed，而不是只看“程序结束了”。

配套工件：

- [流与所有权观察台](../../../examples/encyclopedia/ch.java-engineering.io-resource-lifecycle/README.md)
- [UTF-8 文本复制生命周期实验](../../../labs/encyclopedia/ch.java-engineering.io-resource-lifecycle/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.io-resource-lifecycle/README.md)

## 2. I/O 是边界，不只是 API

I/O 表示程序与外部或另一段数据源之间的输入/输出。外部数据可能延迟、截断、损坏或在中途失败；资源可能占用文件描述符、缓冲内存或系统句柄。因此 I/O 方法不能只说明正常返回值，还要声明失败和生命周期。

内存中的 `ByteArrayInputStream` 关闭成本很低，文件和网络流却关联操作系统资源。统一的父类型让算法可以测试，但不能据此假设所有实现都无需关闭。面向抽象编程时，按最严格的所有权契约管理资源。

## 3. 流是顺序视图

流把数据看成按顺序可读或可写的序列。InputStream 的当前位置随读取前进，OutputStream 的内容随写入累积。很多流不能倒退，不能知道总长度，也不能重复读取。若需要重放，应明确缓存到受限内存、临时存储或重新打开来源。

“stream”不保证异步、无限或网络；它只描述访问模型。`java.util.stream.Stream` 是元素计算管道，与 `java.io.InputStream` 不是同一个层次，但某些基于 I/O 的 Stream 同样需要关闭。

## 4. InputStream 读取字节

InputStream 的基本单位是 8 位 byte。`read()` 返回 0—255 的 int，使用 -1 表示流结束；不能把返回值直接存 byte 后再判断 -1，否则符号转换会混淆。批量 `read(byte[])` 返回实际读取数量或 -1。

一次 read 不承诺填满数组。文件、网络和自定义流都可能只返回部分数据。正确循环使用返回的 count，只写 `buffer[0..count)`，直到 -1。把整个缓冲数组每次都写出，会把上一次残留或未填区域复制到结果。

## 5. `read` 返回 0 的边界

对长度为零的目标数组，批量读取返回 0。对长度大于零的数组，InputStream 契约会阻塞到至少读到一个字节、检测到 EOF 或抛出异常，因此结果应为正数或 -1；合规的自定义 InputStream 也必须如此。非阻塞 Channel 可以用 0 表示暂时无进展，但那是另一套 API 契约。

因此经典 InputStream 复制循环按“正数则处理实际 count，-1 则结束”编写，不为非阻塞语义自行增加猜测。若自定义实现违约返回 0，应修复该实现，而不是把 0 解释成 EOF。

## 6. OutputStream 写入字节

OutputStream 接收原始字节。`write(int)` 只写低八位，批量 `write(byte[], off, len)` 写指定片段。复制时必须传实际读取长度。写成功返回并不一定表示物理介质已持久化，甚至不一定越过用户态缓冲；它只满足该流实现声明的写入契约。

OutputStream 没有通用回滚。写到一半抛 IOException 时，目标可能已有前缀。原子替换需要临时文件和 NIO move，由下一章处理；本章只承诺资源关闭和失败可见。

## 7. 二进制数据保持字节

图片、压缩包、加密数据和任意协议帧都应按字节复制。若把它们先解码成字符再编码，任意字节序列可能不是合法文本，替换字符和换行处理会破坏内容。判断依据不是扩展名，而是协议是否定义了字符集。

二进制复制的 oracle 应比较完整 byte 数组或摘要及长度，不使用肉眼字符串。空输入也是合法边界，输出应为零字节。

## 8. Reader 读取字符

Reader 把数据视为 Unicode 字符序列，基本单位是 Java `char`。`read(char[])` 同样可能部分读取并以 -1 表示结束。字符流适合已经确定编码的文本、逐行处理和字符级变换。

Java char 是 UTF-16 code unit，不保证一个 char 就是一个人眼字符。补充平面码点可能由两个 char 组成，组合字符也可能多个码点构成。复制文本通常无需自行拆码点，让 Reader/Writer 保持字符序列即可。

## 9. Writer 写出字符

Writer 接受 char、字符数组或 String。它最终若连接字节目标，必须按某个 Charset 编码。Writer 的 `append` 返回自身以便链式调用，但仍可能抛 IOException。不要因为调用接受 String 就以为编码不存在；编码只是在桥接层发生。

Writer 的 close 通常会先 flush 再关闭下层资源。失败时仍可能只写出部分文本，且 close 自身也可能失败。生命周期与异常证据必须一起设计。

## 10. 字节与字符之间的桥

`InputStreamReader` 用 CharsetDecoder 将字节解码为字符，`OutputStreamWriter` 用 CharsetEncoder 将字符编码为字节。UTF-8 的一个字符可能跨越多次底层 read；桥接器会保存必要状态，手工把每个字节块分别 `new String` 容易在多字节边界产生乱码。

桥接时显式传 `StandardCharsets.UTF_8`。即使当前 JDK 默认字符集常为 UTF-8，协议明确性仍比环境巧合可靠。输入和输出编码可以不同，但转码必须是有意需求。

## 11. FileReader/FileWriter 的边界

现代构造方式可以显式 Charset，但初学者容易沿用未写编码的旧重载。更清楚的组合是从拥有的 InputStream/OutputStream 建立 InputStreamReader/OutputStreamWriter，并在同一方法看见编码和所有权。

这不是说 FileReader 永远错误，而是可审查性优先。后续 Path/Files API 还提供 `newBufferedReader`、`readString` 等显式 Charset 方法。

## 12. 缓冲为何存在

逐字节或逐字符调用可能频繁进入底层系统操作。BufferedInputStream、BufferedOutputStream、BufferedReader、BufferedWriter 在内存中批量交换，减少调用次数，并为 `readLine` 等便利行为提供支持。缓冲改变性能和交付时机，不改变数据含义。

缓冲大小不是越大越好。过小增加调用，过大增加每个并发任务内存且未必提升吞吐。先用标准默认值，只有真实测量和负载模型支持时再调优。

## 13. 装饰器链

Java I/O 常用装饰器：底层 FileInputStream 提供字节，InputStreamReader 解码，BufferedReader 缓冲。外层对象通常委托并在 close 时关闭下层。创建顺序从底层到外层，使用时面向最外层。

若把链中每一层都单独放入 try-with-resources，关闭会重复传递。多数 Closeable 重复 close 无害，但 AutoCloseable 并不保证幂等，而且多余关闭使异常顺序难理解。常见做法是只管理最外层包装器，前提是其契约明确拥有并关闭下层。

## 14. `flush` 与 `close`

flush 请求把已缓存输出推向下层，但不会释放资源；close 结束生命周期，通常也会 flush。需要在资源保持打开时让对端及时看见数据，才显式 flush，例如交互协议的一个完整消息。每写一个字符都 flush 会损害性能。

flush 成功不等于数据耐久落盘。文件系统缓存、设备缓存和断电语义需要 FileChannel.force 等更强协议；本章不承诺持久化原子性。

## 15. `readAllBytes` 的便利与风险

InputStream 的 `readAllBytes` 适合已知很小、受信且有上限的数据。对不可信或未知长度输入，它可能分配巨大内存。流式复制使用固定缓冲，可以让内存与总文件大小解耦。

便利方法不会自动关闭流。无论 `readAllBytes`、`transferTo` 还是 Reader 的整读方法，仍由所有者通过 try-with-resources 管理生命周期。方法名含 all 不代表“读完就关”。

## 16. `transferTo` 做了什么

InputStream.transferTo(OutputStream) 把剩余字节传到给定输出并返回数量，但不会关闭任一流。Reader 也有对应字符传输。它适合透明复制，无法在每块加入大小限制、进度或故障注入时，则写显式循环。

不要把简短代码等同完整契约。输入总量限制、输出所有权、异常转换和部分写入仍需外层设计。

## 17. `available()` 不是总长度

InputStream.available 表示不阻塞可读的估计字节数，不保证等于剩余长度，更不能用 0 判断 EOF。文件实现可能恰好接近剩余大小，网络实现则常只有当前已到达数据。复制循环唯一可靠的结束信号是 read 返回 -1。

用 available 分配整个输入数组也会面对不准确和内存风险。固定缓冲或协议声明长度更可靠。

## 18. `mark` 与 `reset`

并非所有流支持 mark/reset；先看 `markSupported()`。BufferedInputStream/BufferedReader 可在缓冲限制内支持，但读取超过 read-ahead limit 后 reset 可能失败。不能把它当成任意回退或随机访问。

解析器需要大量回看时，考虑受限缓存、PushbackReader 或更适合的协议解析结构。基础复制不使用 mark。

## 19. 资源是什么

资源是需要确定结束生命周期的对象：文件描述符、Socket、目录流、压缩流、数据库连接，乃至测试中的跟踪对象。Java 对象被垃圾回收只说明内存可回收，不保证外部句柄何时释放。

依赖终结器或 Cleaner 作为正常关闭机制，会把释放时机交给不可预测的 GC。Cleaner 可作为最后防线或诊断，不替代显式 close。

## 20. 所有权问题

每个资源边界必须能回答：谁创建？谁关闭？关闭是否级联？方法返回后资源还能否使用？所有权含糊会导致两类相反错误：没人关造成泄漏，多方都关导致借用者后续失败。

最简单规则是“创建者负责关闭”。若方法只借用调用者提供的流，默认不关闭，除非方法名或文档明确转移所有权。API 需要在签名附近说明这一点。

## 21. 拥有型 API

`copyFile(source, target)` 若内部打开两条流，它拥有两者并在返回前关闭。调用者只得到复制结果或异常，不接触流。这样的高层 API 容易安全使用。

拥有型 API 也要说明部分输出：本章复制失败可能留下目标前缀。不能因为资源已关就宣称操作原子成功。

## 22. 借用型 API

`copy(InputStream in, OutputStream out)` 通常借用两者：它读写但不关闭，方便调用者串联多个操作。调用者在更外层 try-with-resources 统一关闭。方法可以 flush 吗也需约定；通常不擅自 flush，让所有者决定消息边界。

若借用方法用 try-with-resources 包住参数，会提前关闭调用者仍需使用的流。测试应在调用后再次读写，验证借用契约。

## 23. 所有权转移

有些方法接收资源并声明“调用后无论成功失败都关闭”，这是所有权转移。命名、文档与类型应非常清晰，因为调用者不能再使用对象。相比隐式转移，返回拥有资源的封装器并让其实现 AutoCloseable 往往更易理解。

本章练习同时展示拥有型 UTF-8 copy 和借用型字符 copy，避免把一种规则套到所有方法。

## 24. System.in/out 的特殊性

System.in、System.out、System.err 生命周期通常属于进程，不属于某个业务方法。把它们包进 try-with-resources 会关闭全局流，后续代码无法使用。业务方法应借用它们，测试则注入内存流。

同理，框架注入的响应流或连接可能由容器拥有。没有明确契约时不要擅自关闭；查看创建边界和 API 文档。

## 25. Closeable 与 AutoCloseable

Closeable 继承 AutoCloseable，并把 close 异常收窄为 IOException，且要求已关闭时再次 close 无效果。AutoCloseable 的 close 可抛 Exception，不强制幂等，尽管实现通常应尽量幂等。

try-with-resources 接受任意 AutoCloseable。编写自定义资源时应释放内部状态后再抛关闭异常，避免异常导致句柄仍占用；不要随意让 close 抛 InterruptedException。

## 26. try-with-resources 的基本形式

~~~java
try (InputStream in = openInput();
     OutputStream out = openOutput()) {
    copy(in, out);
}
~~~

资源成功初始化后，无论主体正常、return 或抛异常，都会自动尝试 close。它把生命周期与词法作用域绑定，比在多个 return 路径手写 close 更可靠。

## 27. 初始化顺序

多个资源从左到右初始化。若打开输入成功、打开输出失败，已成功创建的输入仍会关闭；未成功创建的输出没有 close。验证器可用事件列表证明，而不是只测主体失败。

若第二个资源依赖第一个，声明顺序要反映依赖。复杂创建失败可拆工厂方法并保留 cause。

## 28. 关闭顺序

资源按初始化相反顺序关闭：先 out，再 in。包装链和依赖栈通常需要这种后进先出顺序。若两次 close 都失败，最右侧资源的关闭异常成为主异常，后续关闭异常被 suppressed。

不要依赖未写入契约的具体实现副作用；测试只断言语言保证的顺序和自己的资源事件。

## 29. effectively final 资源

Java 9 起，已在外部声明且 final 或 effectively final 的变量可直接放入 try 资源列表。这样仍会在块结束时关闭它，所有权语义没有改变。若调用者原本只想借用，不能因为语法方便就把参数写进资源列表。

变量不能在资源使用前后重新赋值，否则不满足 effectively final。编译器拒绝有助于避免关闭对象与变量指向对象不一致。

## 30. catch 何时执行

扩展 try-with-resources 的 catch 在资源关闭完成或尝试完成后接管。因此 catch 观察到的是主体加关闭过程的最终异常，资源已不能继续使用。finally 同样位于资源关闭之后。

若需要区分打开失败、读取失败、写入失败和关闭失败，可通过具体异常、阶段上下文与 suppressed 分析，不能在 catch 中重新使用流探测。

## 31. 主异常与 suppressed

主体先抛 `read failed`，close 又抛 `close failed` 时，主体异常继续传播，关闭异常进入 `getSuppressed()`。这样不让清理故障覆盖导致操作失败的第一证据，同时仍保留第二故障。

suppressed 与 cause 不同。cause 表示“当前抽象失败由哪个下层失败引起”；suppressed 表示“传播主失败时还有其他失败被压制”。一个异常可以同时有 cause 和多个 suppressed。

## 32. 关闭本身失败

若主体正常但 close 失败，关闭异常就是主异常，try-with-resources 整体失败。不能因为数据似乎复制完成就忽略，因为缓冲数据可能在 close/flush 阶段才写出。成功必须包含成功关闭。

验证正常输出时应在 try 块结束后再读取目标，确保 Writer 已完成 flush/close。

## 33. 手写 finally 的覆盖陷阱

~~~java
try {
    read();
} finally {
    resource.close();
}
~~~

若 read 与 close 都抛异常，简单 finally 可能让 close 异常覆盖读取异常。正确手写 suppression 很复杂，语言规范对 try-with-resources 已给出可靠转换。除非维护旧结构或特殊协议，优先使用 TWR。

## 34. 空 catch 吞错

catch IOException 后返回 0 或空字符串，会把复制失败伪装成合法空文件。后续系统无法区分源确实为空与读取中断。错误工件应让进程非零退出并打印 `SWALLOWED_IO`，证明静默返回是契约破坏。

已知失败可转换成稳定结果，但必须明确类型、保留证据且不伪造成功。空文件是一条正常输入，不能被当成通用失败占位。

## 35. cause 丢失

应用方法可把 IOException 转换为 `TextCopyException`，使调用者不依赖底层 API；构造时必须传 cause。只复制 message 会丢底层类型、堆栈和 suppressed。测试直接断言 `getCause()` 类型与其 suppressed，而不是搜索控制台文字。

若当前层本就公开 IOException，可能无需转换。转换发生在抽象边界，不是每层例行包装。

## 36. 中途读取失败

自定义 InputStream 可在若干字节后抛 IOException。正确 TWR 仍关闭输入与输出，转换异常保留读取 cause。输出可能已有前缀，因此调用者不能把目标当成完整文件。

验收同时断言：异常类型正确、cause 正确、input.closed 和 output.closed 均为 true、已写长度符合故障位置。只断言异常会漏掉资源泄漏。

## 37. 写入失败

OutputStream 也可能因空间不足、权限变化或自定义限制中途失败。输入仍需关闭；输出 close 也需尝试。若写失败后继续读输入没有意义，应立即传播并让 TWR 清理。

错误消息应包含安全操作名而非整段文本。部分输出处理由更高层决定，下一章使用临时文件隔离目标。

## 38. 未关闭流如何检测

测试流可覆盖 close 设置布尔标志或记录事件。成功、空输入、读失败、写失败和构造失败都检查预期所有权。比观察系统文件句柄数量更快、更确定。

集成环境还可用句柄监控、压力循环或操作系统工具发现泄漏，但不能替代单元级生命周期 oracle。GC 后“似乎释放”不是确定关闭证据。

## 39. 双重关闭与幂等

Closeable 要求重复 close 无效果，但一般 AutoCloseable 不保证。包装器级联关闭下层后，外层又单独关闭下层可能重复触发自定义副作用。明确只由一个所有者关闭可避免依赖幂等。

测试故障夹具可以故意让第二次 close 抛异常，揭示所有权重复。生产标准流通常较宽容，不应因此形成坏习惯。

## 40. 缓冲器的关闭所有权

BufferedReader.close 会关闭其 Reader，InputStreamReader.close 又关闭底层 InputStream。因此拥有整个链时，把最外层 BufferedReader 放入 TWR 即可。输出链同理。

如果底层流是借用的，需要一个不级联关闭的包装策略或改变 API 边界，而不能直接套标准外层并 close。常见最佳实践是让高层方法接收 Reader/Writer 且不关闭，由创建链的外层所有者管理。

## 41. UTF-8 文本复制

拥有型复制方法内部打开字节流，显式构造 UTF-8 Reader/Writer，再缓冲字符复制。普通中文、换行和补充码点应往返一致；空文件输出为空。字符块边界由桥接器处理。

若需求只是“不改变任何字节”，即便文件声称 UTF-8，也应使用字节复制；字符复制可能规范化错误输入或受编码器错误策略影响。选择依据是是否需要文本语义。

## 42. 解码错误政策

Decoder 对 malformed/unmappable 输入可以 REPORT、REPLACE 或 IGNORE。配置文本通常应 REPORT，避免错误字节静默变成 U+FFFD；面向人类的容错导入可能选择替换，但必须记录质量损失。

InputStreamReader 的便捷构造器使用解码器默认策略细节时，可审查性不如显式 CharsetDecoder。高风险边界可创建 decoder 并设置 `CodingErrorAction.REPORT`。

## 43. 行与换行符

BufferedReader.readLine 返回一行但不包含行终止符。若逐行读取再 `writer.newLine()`，输出会使用当前平台换行并可能改变文件末尾是否有换行。要求逐字符等价时使用字符块复制，不使用 readLine 重建。

若业务明确处理“行”，应定义输出换行协议，例如固定 `\n`。不要让机器平台替你决定跨系统文本格式。

## 44. BOM 边界

UTF-8 BOM 是可选字节序列。标准 UTF-8 Reader 可能把它解码为 U+FEFF 字符，而不是自动当作元数据删除。是否接受或移除必须由文件协议决定。本章固定样本无 BOM，避免隐含政策。

UTF-16 的字节序和 BOM 更复杂，后续需要时单独定义；不要通过“看起来能读”猜编码。

## 45. 大文件与背压

固定大小缓冲让内存占用有界，但输出慢时复制线程会阻塞，这是阻塞 I/O 的正常背压。不能无限把所有输入先缓存到内存“提速”。若需要异步和并发通道，属于 NIO/并发后续主题。

还要设总字节或字符上限，防止不可信输入持续流入。达到上限应失败并关闭双方资源，不能简单截断后宣称完整复制。

## 46. 线程安全

多数流与 Reader/Writer 不应由多个线程无协调共享。即使某些方法同步，跨多次调用的协议仍可能交错。所有权最好同时限定线程或作用域。

并发写同一目标需要更高层锁、队列或原子文件协议，不由单个 BufferedWriter 自动解决。本章资产单线程确定执行。

## 47. FactoryCare 场景

FactoryCare 可导入一份小型 UTF-8 运维说明或复制附件流。文本说明用字符流并固定 UTF-8；二进制附件保持字节。应用服务选择失败映射，I/O 边界负责资源所有权和 cause。

本章不解析说明中的 JSON、不验证工单状态、不保存数据库，也不把示例当成上传安全实现。文件路径和原子替换在下一章。

## 48. 正常复制 oracle

固定输入 `设备=A-17\n状态=运行\n`，复制后按 UTF-8 解码必须逐字符相等，报告字符数和关闭事件。空输入复制后长度为零且双方关闭。输出在 try 块结束后读取。

字节复制另用包含 0x00、0xFF 的数组，证明未经过字符编码。两个测试回答不同契约。

## 49. 失败 oracle：读取与关闭同时失败

跟踪 Reader 在首次读取时抛 `IOException("read failed")`，close 再抛 `IOException("input close failed")`；Writer close 也可失败。TWR 的主异常与 suppressed 顺序按资源声明和关闭顺序断言。

应用层转换为 TextCopyException 后，cause 是主 IOException，其 `getSuppressed()` 保存关闭异常。不能把 suppressed 错当 cause 的兄弟链。

## 50. 失败 oracle：输出未关闭

错误方法只复制不 close，跟踪输出 `closed=false`。即使 ByteArrayOutputStream 内容可读，这仍违反面向一般 OutputStream 的所有权契约。故障程序以非零退出证明泄漏，而不是等待操作系统报“too many open files”。

修复不是在成功末尾加 close；中途失败仍会跳过。把资源放入 TWR 或由明确外层所有者统一关闭。

## 51. 预测练习

运行前预测：read(buffer) 是否总填满；available=0 是否 EOF；transferTo 是否关闭；多个资源关闭顺序；主体和两个 close 同时失败时主异常是谁；借用型 copy 是否应关闭参数；readLine 是否保留原换行。

记录预测后运行工件，把错误改写成一句所有权或流规则。只记输出数字无法迁移到真实文件和网络。

## 52. 独立构建任务

从空文件实现 `copyUtf8Owned` 与 `copyBorrowed`。前者由工厂创建 Reader/Writer 并负责关闭，后者接收已有 Reader/Writer 且不关闭。两者都使用字符块、实际 count 和固定 UTF-8，不读取默认编码。

追加普通、空、补充码点、中途读取失败和输出失败测试。失败报告包含 expected/actual、closed 标志、cause 与 suppressed。

## 53. 修改任务

把最大字符数从无限改为 64，再让 65 字符输入失败。只能局部加入计数和测试，不能改成整读字符串。解释失败后输出为何可能已有前缀，以及原子替换为何要留到下一章。

再把一条借用 API 改为拥有 API，列出调用者生命周期如何变化。若无法说明谁关闭，就不能合并改动。

## 54. 故障诊断任务

依次运行四个故障：吞 IOException、转换丢 cause、资源未关闭、手写 finally 覆盖主失败。每次保存退出码、首条可信证据、关闭事件和异常链。一次只修一个，复跑正常与空输入。

额外设计一个错误：把每次读取忽略 count 写满缓冲，或用 readLine 改写换行。说明它破坏数据还是生命周期。

## 55. 120 秒复述提纲

不看正文解释：字节流与字符流如何选择？Charset 在哪一层？缓冲改变什么、不改变什么？flush 与 close 区别？拥有与借用怎样决定谁关？TWR 的初始化/关闭顺序？cause 和 suppressed 怎样同时保留？

最后讲一个中途读取失败链，指出输入、输出为何仍关闭，以及部分输出为何不能当成功。

## 56. 验收清单

- 普通和空文本复制一致，中文与补充码点不在缓冲边界损坏。
- 二进制样本按字节复制，不经过 Reader/Writer。
- 拥有型 API 成功和失败都关闭，借用型 API 不抢夺所有权。
- 读取/写入异常转换时保留 cause，关闭失败进入 suppressed。
- 关闭顺序、初始化失败和未关闭反例有确定事件 oracle。
- 没有空 catch、null 失败值、available EOF 判断或默认字符集。
- 所有资产在 Java 25 下离线运行，不读取网络和当前时间。

## 57. 有意不做

本章不使用 Path/Files 设计目录与原子移动，不保证失败后目标文件完整，不解析 JSON，不实现上传安全、异步通道、文件锁或持久化刷盘。下一章才处理临时文件替换、遍历和符号链接边界。

没有为旧式手写 finally 保留兼容实现；教学默认采用主流 try-with-resources。若维护遗留代码，应逐步迁移并用 suppression 测试保护语义。

## 58. 一手资料

- [java.io 包，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/package-summary.html)
- [Reader，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/Reader.html)
- [AutoCloseable，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/AutoCloseable.html)
- [JLS 25 §14.20.3 try-with-resources](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html#jls-14.20.3)
