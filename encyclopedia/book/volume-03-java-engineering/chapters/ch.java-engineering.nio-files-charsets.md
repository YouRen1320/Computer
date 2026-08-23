---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.nio-files-charsets
title: Path、Files、缓冲、字符集与原子文件操作
responsibility: 教授现代文件 API 和编码显式性，不在本章解析业务 JSON 或实现分布式文件锁
volume: '03'
order: 10
level: L1
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.nio-files-charsets.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-engineering.io-resource-lifecycle
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
  text: 在 120 秒内解释Path、Files、缓冲、字符集与原子文件操作的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-nio-path-files
  - java-file-safety
  covers_topics:
  - java.nio-path
  - java.files-read-write
  - java.directory-walk
  - java.charset-explicit
  - java.atomic-move
  - java.temp-file-replace
  uses_capabilities:
  - java.exceptions-resources
  - foundation.files-path-encoding
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 用 Path/Files 读取 UTF-8 配置，写入临时文件后原子替换目标，并遍历目录时过滤符号链接边界
  covers_topic_groups:
  - java-nio-path-files
  - java-file-safety
  covers_topics:
  - java.nio-path
  - java.files-read-write
  - java.directory-walk
  - java.charset-explicit
  - java.atomic-move
  - java.temp-file-replace
  uses_capabilities:
  - java.exceptions-resources
  - foundation.files-path-encoding
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入默认字符集乱码、直接覆盖中断留下半文件和相对路径基准错误，逐项修复
  covers_topic_groups:
  - java-nio-path-files
  - java-file-safety
  covers_topics:
  - java.nio-path
  - java.files-read-write
  - java.directory-walk
  - java.charset-explicit
  - java.atomic-move
  - java.temp-file-replace
  uses_capabilities:
  - java.exceptions-resources
  - foundation.files-path-encoding
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Path、Files、缓冲、字符集与原子文件操作

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《字节流、字符流、资源所有权与 try-with-resources》](ch.java-engineering.io-resource-lifecycle.md)：独立完成Path 与 Files、编码与原子性前，必须先具备「字节流、字符流、资源所有权与 try-with-resources」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文与工件可用于学习和作者验证，不自动改变 `PROGRESS.md`，也不证明学习者已独立通过阶段门。

上一章解决“流由谁关闭”，却没有解决“路径相对谁解析、文本按什么编码、写到一半如何保护旧文件、遍历会不会跟随符号链接逃出目录”。现代 Java 用 `Path` 表达文件系统位置，用 `Files` 执行操作，用 `Charset` 明确字节与字符转换，并可通过“同目录临时文件 + 原子移动”缩小替换窗口。

本章实现一份小型 UTF-8 配置的安全读取和替换，并遍历受控目录而不跟随符号链接。它不解析 JSON、不实现分布式锁、不承诺所有文件系统支持同样的原子性或持久化语义。Java 25 API 已于 **2026-07-16** 按一手资料复核。

## 1. 本章完成证据

1. **解释**：120 秒内说明 Path 与真实文件的区别、相对路径为何必须有明确 base、字符集为何属于协议、原子移动保证什么以及符号链接为何突破词法检查。
2. **构建**：用 Path/Files 读写 UTF-8，先写目标同目录临时文件，再以 `ATOMIC_MOVE` 替换；失败时旧目标完整、临时文件清理；目录遍历不跟随符号链接。
3. **诊断**：真实复现默认字符集乱码、直接 truncate 后中断留下半文件、错误工作目录解析和符号链接逃逸，从第一条 expected/actual 修复。

配套工件：

- [Path/Files 安全操作观察台](../../../examples/encyclopedia/ch.java-engineering.nio-files-charsets/README.md)
- [UTF-8 配置原子替换实验](../../../labs/encyclopedia/ch.java-engineering.nio-files-charsets/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.nio-files-charsets/README.md)

## 2. Path 是位置描述，不是文件内容

Path 是文件系统提供者创建的层次路径对象。`Path.of("config", "app.txt")` 成功，只说明字符串可转换成路径结构，不说明文件存在、可读、是普通文件或属于当前租户。真实操作由 Files 触发并可能抛 IOException。

不要把 Path 命名成 file 后就忘记检查类型。目录、符号链接、设备文件和不存在条目都能由 Path 表示。每个操作应按需求验证实际属性。

## 3. Path 的组成

Path 可能含 root、若干 name element 和 fileName。Unix 风格 `/srv/app/config.txt` 有根 `/`，Windows 提供者可能有盘符或 UNC 规则；分隔符由提供者决定。使用 `resolve` 和 `getFileName`，不要手工拼接 `/`。

Path 实现与其 FileSystem 绑定。默认文件系统之外还可能有 zip 或自定义提供者；比较或 resolve 不同提供者路径可能失败。教学资产使用默认本地文件系统。

## 4. `Path.of` 与旧 Paths

Java 11 起可直接 `Path.of`，Paths.get 只是转调。字符串重载适合应用入口，把上层提供的 base Path 继续向下传更灵活。库代码若到处调用 `Path.of`，会暗中绑定默认文件系统和进程环境。

URI 转 Path 需要匹配的提供者，不能把普通 URL 文本直接当本地路径。网络下载与文件系统定位是不同边界。

## 5. 相对路径

`Path.of("config.txt")` 是相对路径。`toAbsolutePath()` 通常按进程默认目录解析，但这个目录可能因 IDE、shell、测试和服务管理器不同而变化。把“开发机项目根”当默认是常见部署故障。

业务方法应接收明确 base，如 `loadConfig(configRoot, "device.txt")`，先 `base.resolve(child)`。程序启动层解析配置目录并记录安全摘要，内层不读取 `user.dir` 猜测。

## 6. 绝对路径

绝对 Path 有 root，不依赖另一个 base。需要注意：`base.resolve(absoluteChild)` 会直接返回 absoluteChild，忽略 base。若 child 来自不可信输入，必须先拒绝 `isAbsolute()`，否则所谓沙箱瞬间失效。

绝对并不等于真实或安全；它仍可能包含符号链接，目标也可能变化。它只消除了相对基准歧义。

## 7. `resolve` 与 `resolveSibling`

`base.resolve("a/b")` 把相对子路径接到 base；`path.resolveSibling("other")` 用同一父目录替换末尾名称，适合旁路临时文件但要注意 path 可能没有 parent。明确使用目标 parent 创建临时文件更可靠。

不要用字符串拼 `base + "/" + child`，这会绕过提供者分隔规则，并让绝对 child、空段和转义更难审查。

## 8. `normalize` 是词法操作

normalize 移除可消解的 `.` 和 `name/..`，不访问文件系统，也不解析符号链接。`base.resolve(user).normalize()` 有助于发现普通 `../` 穿越；检查结果 `startsWith(base.normalize())` 是第一层词法约束。

它不能证明真实目标仍在 base。若中间元素是指向外部的符号链接，词法路径仍以 base 开头。安全边界还需符号链接政策与真实路径检查。

## 9. `toAbsolutePath` 与 `toRealPath`

toAbsolutePath 只建立绝对表示，通常不要求目标存在；toRealPath 访问文件系统，要求存在，并解析冗余元素与默认情况下的符号链接，返回定位同一文件的真实路径。传 `NOFOLLOW_LINKS` 会改变链接处理。

真实路径检查有时间竞争：检查后攻击者可能替换目录项。对于对手可写目录，单次 `toRealPath` 不能构成完美沙箱；需要操作系统权限、SecureDirectoryStream 或更强架构。

## 10. `relativize`

`base.relativize(child)` 产生从 base 到 child 的相对路径，常用于报告和清单。两者必须兼容，通常同为绝对或同为相对且同一提供者。relativize 不检查文件存在。

输出相对路径前仍应确认 child 在允许 base 内，避免日志或清单出现大量 `..` 造成误用。

## 11. Path 相等不等于同一文件

Path.equals 比较提供者定义的路径表示，不必访问文件系统。不同词法路径、大小写形式或符号链接可以指向同一文件。`Files.isSameFile` 会访问文件系统判断，但结果也只反映检查时刻。

业务键不应直接依赖平台路径相等语义。路径是边界值，规范化和身份政策要由具体应用定义。

## 12. Files 是操作入口

Files 提供创建、读取、写入、复制、移动、删除、属性和遍历。方法通常接收 Path，并以具体 IOException 子类报告不存在、已存在、拒绝访问等。不要先把所有异常 catch 成 `file error`，具体类型能帮助稳定分类。

但异常子类在不同提供者上可能有差异。外部契约应映射必要类别，并保留 cause，而不是依赖某个 OS 消息文本。

## 13. `exists` 的局限

`Files.exists(path)` 返回 false 既可能是不存在，也可能是无法确定；更重要的是，检查之后文件状态可立刻改变。`if (exists) read` 不能避免 read 抛异常，`if (!exists) create` 也有竞态。

直接执行目标原子操作并处理异常。exists 适合界面提示或非安全观察，不是授权、锁或事务。

## 14. 文件类型检查

读取配置通常要求 regular file，可用 `Files.isRegularFile(path, NOFOLLOW_LINKS)` 做意图检查，但仍有竞态。默认选项会跟随链接，是否允许必须显式。目录不能因为可读就当文件。

文件大小、权限、owner 等属性也可能在检查后变化。把这些检查视为拒绝明显错误和建立审计，不把它们误称绝对安全保证。

## 15. 文本与二进制

文件只是字节。只有协议声明字符集时才是文本。`Files.readAllBytes`/write 适合二进制；`readString`/writeString 或 Reader/Writer 适合文本。将图片交给 `readString` 可能因 malformed/unmappable 输入抛出 IOException，而且即使偶然可解码也不能还原二进制语义；将文本只当字节则无法做字符级处理。

扩展名只能提示，不能证明内容。FactoryCare 配置契约明确 UTF-8，因此按文本读取；附件保持字节。

## 16. Charset 是映射规则

Charset 定义字节序列与 Unicode 字符之间的映射。相同字节用 UTF-8 和 ISO-8859-1 解码会得到不同字符；相同字符串用不同编码会生成不同字节。编码不是显示层装饰，而是文件协议的一部分。

始终在边界写 `StandardCharsets.UTF_8`。标准字符集常量保证所有 Java 实现可用，也避免名称拼写和受检 UnsupportedEncodingException。

## 17. 默认字符集为何仍危险

较新 JDK 的默认 UTF-8 提升一致性，但代码依赖默认仍没有表达文件协议，启动参数或兼容模式也可能改变环境。旧数据可能采用其他编码。显式 Charset 让代码审查、测试和迁移都能看到选择。

故障工件会在子 JVM 设 `-Dfile.encoding=ISO-8859-1`，让未指定编码的往返失败。输出只报告默认字符集名和布尔证据，避免终端本身再混入乱码。

## 18. UTF-8 的多字节

ASCII 字符在 UTF-8 中一字节，常见中文三字节，补充码点通常四字节。字符串 length 统计 UTF-16 code unit，不等于 UTF-8 byte 数，也不等于人眼字符数。限制文件大小时要说明限制字节还是字符。

使用 Charset 编解码器让分块边界正确处理多字节；不要把每个 byte 块独立 new String 后拼接。

## 19. malformed 与 unmappable

解码时非法字节序列是 malformed；编码时合法字符无法映射到目标字符集是 unmappable。CharsetDecoder/Encoder 可选择 REPORT、REPLACE、IGNORE。配置和安全边界通常使用 REPORT，避免错误内容静默变成替换字符。

高层便捷方法的错误策略需逐个查 API：`Files.readString(path, charset)` 对 malformed 或 unmappable 输入抛 IOException。需要显式选择 REPORT/REPLACE/IGNORE，或需要精确断言 CharacterCodingException 时，再直接配置 decoder。

## 20. BOM

UTF-8 BOM 可选，是否接受/删除由文件协议决定。`Files.readString(..., UTF_8)` 不替你定义业务 BOM 政策，开头 U+FEFF 可能进入内容。UTF-16 还涉及大小端和 BOM。

本章配置格式明确无 BOM；读到 BOM 时拒绝并报告，而不是隐式 strip 所有不可见字符。

## 21. 换行

`readString` 保留实际换行字符；`readAllLines` 返回不含终止符的行列表。再用系统换行连接会改写 `\n`/`\r\n` 和末尾换行。需要字节或字符保真时整串读写或流式复制。

配置协议可固定 `\n`，但必须显式。不要让 `System.lineSeparator()` 决定跨平台文件格式。

## 22. `readString` 的范围

readString 适合已知小且有上限的文本。它把整个文件放入内存，不适合任意用户上传或巨大日志。先检查 size 只能初筛，文件仍可能变化；更强边界使用受限 Reader 流式读取并在超过阈值时失败。

本章资产文件很小，使用 readString 保持重点在路径与替换，同时正文明确内存边界。

## 23. `readAllLines` 和 `lines`

readAllLines 同样整读内存；Files.lines 返回惰性 Stream，背后保持打开文件，必须 try-with-resources 关闭。终端操作结束不应被当成关闭保证。若把 Stream 返回到方法外，所有权必须连同它一起转移。

逐行处理仍要设行长度、行数或总字符上限，避免单行巨量输入。

## 24. `newBufferedReader`/Writer

Files.newBufferedReader(path, UTF_8) 与 newBufferedWriter 提供显式编码和缓冲，适合流式文本。它们返回 Closeable，遵循上一章所有权规则。打开成功后必须 TWR。

StandardOpenOption 决定创建、截断或追加。默认行为需查方法契约；关键写入不要依赖“我记得默认是什么”，把意图写出来。

## 25. 写入选项

`CREATE` 在不存在时创建，`CREATE_NEW` 要求不存在并可避免覆盖竞争，`TRUNCATE_EXISTING` 打开后立即截断已有文件，`APPEND` 在末尾写。组合是否支持由提供者决定。

更新配置直接使用 TRUNCATE_EXISTING 风险很高：进程在写半段时失败，旧完整内容已经消失。临时文件替换把失败隔离在目标之外。

## 26. 直接覆盖故障

错误程序先以 TRUNCATE 打开目标，写入 `new-` 后模拟崩溃。读回得到半文件，证明 close 正确也不能恢复旧内容。第一处证据是 `expected=old-complete actual=new-`。

修复不是 catch 后再写旧文本，因为旧内容可能很大、已经变化或恢复也会失败。应先在独立临时文件完成全部写入和关闭。

## 27. 临时文件原则

目标为 `/base/config.txt` 时，在同一目录用 `Files.createTempFile(parent, ".config-", ".tmp")` 创建临时文件。同目录通常位于同一 FileStore，提高原子 rename 支持概率，也让目录权限边界一致。

临时名不可由不可信输入直接拼接；createTempFile 提供唯一性。权限和属性是否需要复制或限制必须另行定义，本章只处理内容与替换。

## 28. 完整替换流程

流程是：解析并验证目标；创建同目录临时文件；按 UTF-8 写完整内容；成功关闭；可选重新读回/校验；使用 Files.move 替换；finally 若临时仍存在则删除。只有 move 成功才报告新配置生效。

写临时期间失败，目标未被打开，因此旧内容保持。清理临时失败不能覆盖主异常，应作为 suppressed 或记录的清理故障。

## 29. `ATOMIC_MOVE`

Files.move 使用 `StandardCopyOption.ATOMIC_MOVE` 请求文件系统把移动作为一个原子操作；不支持时抛 AtomicMoveNotSupportedException。原子意味着观察者不会看到移动的中间状态，不等于跨所有系统必定支持。

若业务要求原子更新，应 fail closed，不要无声退化为普通 move。若允许降级，应由显式政策、监控和测试决定，而不是 catch 后自动重试非原子操作。

## 30. `REPLACE_EXISTING` 的细节

普通 move 的 REPLACE_EXISTING 意图清楚；规范指出 ATOMIC_MOVE 下其他选项会被忽略，目标已存在时替换还是失败可能依实现而异。实际应用需要在支持的文件系统上验证约定，或设计平台适配层。

本地教学资产在当前文件系统验证 `ATOMIC_MOVE` 替换；跨提供者行为列为未验证，不把一次通过推广成普遍承诺。

## 31. 原子不等于耐久

原子移动保证命名空间观察的不可分割性，不自动保证断电后内容和目录项都持久。写缓冲、存储设备缓存和目录元数据可能需要 FileChannel.force 与平台协议。Java 没有一个跨平台调用完全保证所有硬件场景。

本章验收是“进程内故障前旧文件完整、成功后新文件完整且无临时残留”，不宣称断电安全。生产要求必须单独定义耐久级别。

## 32. 临时文件清理

finally 使用 `deleteIfExists(temp)`，但仅在 move 未成功或临时仍存在时。绝不能误删 target。若删除失败且已有主异常，可 `primary.addSuppressed(cleanup)`；若没有主异常，清理失败本身是否使操作失败由契约决定。

定期清理陈旧临时文件需要识别前缀、owner、年龄与并发实例，超出本章。不能启动时删除目录里所有 `.tmp`。

## 33. 目标父目录

createTempFile 需要父目录存在。更新方法应拒绝 target 没有 parent 或 parent 不在允许 base；是否创建缺失目录由 API 契约决定。自动 `createDirectories` 可能把路径拼写错误变成新目录树。

FactoryCare 配置根由启动层创建并授权，更新方法不越权创建根外目录。

## 34. 遍历目录

Files.walkFileTree 用 FileVisitor 深度优先访问，可在 preVisitDirectory、visitFile、visitFileFailed、postVisitDirectory 返回 CONTINUE、SKIP_SUBTREE、SKIP_SIBLINGS 或 TERMINATE。它适合需要显式错误和控制的大型遍历。

Files.walk 返回惰性 Stream，语法简洁但必须 TWR 关闭。两者默认不跟随符号链接，除非显式 FOLLOW_LINKS。

## 35. 遍历顺序

文件系统条目顺序通常未定义，测试和报告不能依赖自然遍历顺序。收集相对路径后显式排序，再输出确定报告。排序规则也要明确大小写和 locale；Path 自然顺序受提供者语义影响。跨平台文本报告逐个连接名称元素并固定用 `/`，不直接把平台相关的 `Path.toString()` 当报告协议。

遍历期间目录可变化，结果是弱一致观察，不是快照。需要快照或事务必须用更强存储协议。

## 36. 深度和数量上限

不可信目录可能极深、文件极多。Files.walk 可设 maxDepth；Visitor 可计数并在超过上限 TERMINATE 或抛专用异常。无限遍历会消耗时间、句柄和内存。

收集所有 Path 再排序也要限制数量。资产使用很小树并固定 maxDepth。

## 37. 遍历失败

visitFileFailed 提供具体 IOException。跳过不可读条目、终止整个任务或记录部分结果是业务政策。不能空 catch 后输出“扫描完成”，否则调用者不知道清单不完整。

安全扫描通常 fail closed；用户界面搜索可能允许带警告的部分结果。结果类型应区分 complete 与 partial。

## 38. 符号链接是什么

符号链接是一个目录项，内容指向另一路径。链接本身位于允许 base 内，目标可能在外部。Files.isSymbolicLink 检查目录项，NOFOLLOW_LINKS 让属性操作观察链接本身。

删除或移动链接通常作用于链接，不自动作用于目标；跟随后的读写则访问目标。每个 API 的链接语义必须查契约。

## 39. 默认不跟随

Files.walk/walkFileTree 默认不跟随目录符号链接，这是安全基线。不要为了“扫全”随手加 FOLLOW_LINKS。普通符号链接文件仍会作为条目出现，可明确过滤 `Files.isSymbolicLink(path)`。

资产遍历只收集以 `NOFOLLOW_LINKS` 判定的普通文件且显式过滤符号链接，并输出相对路径。外部目标内容不能进入清单。

## 40. FOLLOW_LINKS 与循环

跟随链接可能进入 base 外，还可能形成循环。walkFileTree 会尽力检测循环并报告 FileSystemLoopException，但检测有成本且依文件系统标识。不能把循环检测当沙箱保证。

确需跟随时，要限定真实根、深度、数量、允许 FileStore 和错误策略；本章不启用。

## 41. 词法穿越

输入 `../../secret.txt` 经 base.resolve 后可能离开根。先拒绝绝对路径，再 `base.resolve(input).normalize()` 并检查 startsWith 规范 base。检查前确保 base 自身是绝对规范路径，避免相对比较混乱。

空路径、`.`、目标等于 base 也需按操作拒绝。写配置需要普通文件目标，不允许根目录。

## 42. 符号链接穿越

`base/link/secret` 词法上 startsWith(base)，但 link 可指向 `/outside`。对已存在路径，比较 `base.toRealPath()` 与 `target.toRealPath()` 能发现当前逃逸；创建新目标则需检查最近存在父目录的真实路径和后续目录项政策。

检查与打开之间仍有 TOCTOU。对手可写目录不能只靠 Java 字符串检查防护；使用操作系统权限隔离，使不可信主体无法替换父目录，是更基础的防线。

## 43. `NOFOLLOW_LINKS`

`readAttributes`、`exists`、`isRegularFile` 等查询可接受 `LinkOption.NOFOLLOW_LINKS`。它只影响该次操作，不是传染给后续所有调用；`Files.delete` 没有这个选项，删除符号链接时删除的是链接本身而非其目标。每个步骤都要查签名并明确链接政策。

`Files.newByteChannel` 与遍历的链接行为需看具体选项和提供者。不要封装一个名叫 `safePath` 的 Path 后假设所有后续操作自动安全。

## 44. SecureDirectoryStream

某些提供者支持 SecureDirectoryStream，可相对已打开目录句柄执行操作，减少路径替换竞态。但并非所有平台提供，API 也更复杂。高对抗文件沙箱应评估它或把操作放进受限进程/容器。

本章只讲其存在，不实现跨平台适配，也不夸大 normalize + startsWith 的安全程度。

## 45. 文件名与敏感信息

用户输入文件名可能含控制字符、超长文本、保留名或看似路径分隔符。机器生成内部名比清洗任意原名更安全；展示名与存储名可以分开。日志输出需转义控制字符和限制长度。

不把租户 ID、token 或完整外部路径写入错误消息。Path.toString 不是自动脱敏表示。

## 46. 临时目录测试

离线资产使用 `Files.createTempDirectory` 建立隔离根，在退出前以受控 walkFileTree 或等价逆序遍历删除自己创建的树。测试绝不写用户真实配置或任何非自建路径。固定文件内容和相对报告保证可重放。

临时根的绝对名称随机，输出不打印它，只打印相对路径、内容和布尔证据。

## 47. UTF-8 严格读取

便捷 `readString(path, UTF_8)` 对小文件清晰，并会在 malformed/unmappable 输入时抛 IOException。需要显式展示 REPORT 政策或精确区分 CharacterCodingException 时，可读 bytes 后用 `UTF_8.newDecoder().onMalformedInput(REPORT).onUnmappableCharacter(REPORT).decode`。成功后再做 BOM、长度和业务格式验证。

字符集成功不代表内容可信。JSON、键值语法和字段业务规则在后续章节处理。

## 48. 写入前验证

原子写入保护旧文件，却不会保证新内容正确。先在内存中验证字符数、无禁止 BOM、必要末尾换行等文件层契约，再写 temp。业务 JSON 验证留给下一章。

若内容太大不能整存内存，使用流式写临时文件并在过程中验证，完成后再 move。原理不变。

## 49. 原子写入函数契约

一个清晰方法接收已确认 base、相对目标和 String 内容；拒绝 null、绝对/穿越路径；要求目标 parent 位于 base；创建同目录 temp；UTF-8 写完并关闭；原子 move；清理残留。返回目标 Path 或 void，不返回 temp。

IOException 可按工程边界继续 checked 或转换并保留 cause。AtomicMoveNotSupportedException 不静默降级。

## 50. 故障注入点

为了证明旧文件保护，在 temp 写完一部分后由注入 hook 抛 IOException。断言 target 仍为 `old-complete`，temp 被删。成功复跑断言 target 为完整新文本且目录中没有 temp 前缀。

hook 只用于离线测试，不让生产调用者任意执行代码。真实实现可把写临时阶段抽成包内策略。

## 51. 相对基准错误

错误方法直接 `Path.of("config.txt").toAbsolutePath()`，运行目录若不是配置根就定位错误。故障报告不打印机器绝对路径，只断言 `actualStartsWithExpectedBase=false`。修复为 `base.resolve(relative).normalize()`。

不要通过在测试里 `System.setProperty("user.dir", ...)` 假装可靠切换工作目录；默认文件系统的解析不承诺随该属性动态改变。

## 52. 默认编码故障

错误程序把 UTF-8 bytes 用默认 Charset 解码，再与原文本比较。验证器用子 JVM 参数把默认设成 ISO-8859-1，往返不等后退出非零。第一证据是 `roundTrip=false`，不是终端显示的乱码形状。

修复在每个文本边界显式 UTF-8，而不是要求所有部署记住 JVM 参数。

## 53. 半文件故障

错误程序对真实目标 `TRUNCATE_EXISTING` 后写前缀并抛异常。finally 关闭 Writer 只能保证前缀刷出，不能恢复 old。oracle 断言 `oldPreserved=false`。修复改为写 temp；不能在 catch 中把 old 常量写回。

正常和失败都检查临时残留，防止长期占满目录。

## 54. 符号链接故障

在 temp 根内建立 `allowed/link -> outside`，词法检查通过，读取会得到外部 secret。故障程序报告 `lexicalInside=true realInside=false`。安全遍历不跟随并过滤 link；定向访问则比较真实父路径且依赖目录权限。

符号链接创建是文件系统可选能力；本地验证会记录当前平台结果，跨平台未验证时不能声称普遍一致。

## 55. 预测练习

运行前预测：Path.of 是否创建文件；normalize 是否访问磁盘；base.resolve(absolute) 返回什么；Files.exists 后 read 是否仍会失败；readString 是否适合无限文件；Files.walk 是否需 close；ATOMIC_MOVE 不支持时发生什么；默认 walk 是否跟随链接。

再预测故障时 target、temp 和链接外文件各自状态，运行后把差异写成规则。

## 56. 独立构建任务

从空文件实现 `resolveConfined`、`readUtf8Strict`、`replaceUtf8Atomically` 和 `listRegularFilesNoLinks`。所有输入使用测试 temp 根，不访问网络。先写正常和空文件，再注入中断、乱码、穿越和链接。

输出验证报告记录 INPUT、OP、RESULT，路径只用相对形式。任何 IOException 不得被空 catch。

## 57. 修改任务

把文件上限改为 64 字节，并增加中文恰好/超过边界样本，说明字符数为何不能代替 UTF-8 字节数。再把遍历深度从 2 改为 1，验证深层文件消失而链接仍不跟随。

只修改对应策略与测试，不重写整个工具。能局部调整才说明理解生成代码。

## 58. 120 秒复述提纲

不看正文回答：Path 与文件区别？相对路径以谁为基准？normalize、absolute、real path 差别？为什么显式 UTF-8？文本和二进制如何选？临时文件 + atomic move 的成功线性点在哪里？原子为何不等于耐久？默认遍历如何处理符号链接？

最后讲一个直接覆盖中断的失败链，并指出旧目标、临时文件和异常证据。

## 59. 验收清单

- 中文 UTF-8 往返一致，非法 UTF-8 按 REPORT 失败。
- 所有相对输入以显式 base 解析，绝对和 `..` 逃逸被拒绝。
- 注入 temp 写失败时旧目标完整且无临时残留。
- 成功替换后目标完整；ATOMIC_MOVE 不支持时按明确政策失败。
- 遍历结果排序、限制深度和数量，不跟随并过滤符号链接。
- Files.walk 等 I/O Stream 在 TWR 中关闭，异常保留 cause/suppressed。
- 故障验证不依赖网络、当前时间、真实用户目录或人工看乱码。

## 60. 有意不做

本章不解析 JSON、不实现数据库或分布式文件锁、不处理多进程并发写仲裁、不承诺断电耐久、不建立敌对用户可写目录的完美沙箱。也不静默兼容不支持 ATOMIC_MOVE 的文件系统。

平台差异需要在目标部署文件系统上再验证。当前资产证明本机 Java 25 行为，不把局部通过泛化为所有提供者保证。

## 61. 一手资料

- [Path，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/file/Path.html)
- [Files，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/file/Files.html)
- [StandardCharsets，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/charset/StandardCharsets.html)
- [CharsetDecoder，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/charset/CharsetDecoder.html)
