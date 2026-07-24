---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.reflection-classloading-proxies
title: 反射、类加载边界与动态代理
responsibility: 教授运行时类型检查和接口代理的边界与风险，不构建通用 DI 容器或修改字节码
volume: '03'
order: 15
level: L2
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.reflection-classloading-proxies.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-engineering.annotations-metadata
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
  text: 在 120 秒内解释反射、类加载边界与动态代理的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-reflection-classloading
  - java-dynamic-proxy
  covers_topics:
  - java.class-object
  - java.reflect-member-access
  - java.classloader-boundary
  - java.proxy-invocation-handler
  - java.interface-proxy
  - java.reflection-risk
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.exceptions-resources
  - java.references-objects
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：反射读取带 @RequiresRole 的方法并用 JDK Proxy 包装接口调用，记录类加载器、方法和委托链
  covers_topic_groups:
  - java-reflection-classloading
  - java-dynamic-proxy
  covers_topics:
  - java.class-object
  - java.reflect-member-access
  - java.classloader-boundary
  - java.proxy-invocation-handler
  - java.interface-proxy
  - java.reflection-risk
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.exceptions-resources
  - java.references-objects
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入代理目标无接口、反射成员不可访问和上下文 ClassLoader 错误，定位边界后改为显式契约，并把异常定位到第一处可信证据
  covers_topic_groups:
  - java-reflection-classloading
  - java-dynamic-proxy
  covers_topics:
  - java.class-object
  - java.reflect-member-access
  - java.classloader-boundary
  - java.proxy-invocation-handler
  - java.interface-proxy
  - java.reflection-risk
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.exceptions-resources
  - java.references-objects
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 反射、类加载边界与动态代理

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《注解声明、目标、保留策略与元数据》](ch.java-engineering.annotations-metadata.md)：独立完成反射与类加载、动态代理前，必须先具备「注解声明、目标、保留策略与元数据」已经验证的知识与失败边界
- [《字节流、字符流、资源所有权与 try-with-resources》](ch.java-engineering.io-resource-lifecycle.md)：独立完成反射与类加载、动态代理前，必须先具备「字节流、字符流、资源所有权与 try-with-resources」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文和工件是作者级学习材料与可重复验证，不自动更新 `PROGRESS.md`，也不代表学习者已经独立通过阶段门。

普通 Java 代码在编译时直接写出类型和方法；反射则在运行时拿到 `Class`、`Method`、`Field` 等元数据，再检查或调用未知类型。类加载器决定同一串二进制名称最终由哪份字节定义，JDK 动态代理则为一组接口在运行时生成代理类，把每次调用交给 `InvocationHandler`。三者共同支撑注解驱动框架、插件发现、序列化和横切行为，也共同放大访问、异常、类身份与安全风险。

本章用一个带 `@RequiresRole` 的 FactoryCare 接口展示显式反射读取和接口代理：代理调用前检查角色、记录方法与委托链，业务返回值保持不变，目标异常保留 cause。本章不构建通用 DI 容器、不扫描整个 classpath、不修改字节码，也不把反射当作绕过模块封装的捷径。Java 25 官方 API 复核日期为 **2026-07-17**。

## 1. 本章完成证据

至少留下三类证据：第一，120 秒内解释 `Class` 对象、定义类加载器、父级委派、反射访问与接口动态代理的边界；第二，从空文件实现一个只代理明确接口的角色检查器，普通返回值、注解读取和调用日志均有断言；第三，注入无接口目标、私有成员不可访问、错误上下文类加载器和目标方法抛错，能从第一处可信异常定位并修复。

配套工件：

- [反射与代理观察台](../../../examples/encyclopedia/ch.java-engineering.reflection-classloading-proxies/README.md)
- [类身份、注解与委托链实验](../../../labs/encyclopedia/ch.java-engineering.reflection-classloading-proxies/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.reflection-classloading-proxies/README.md)

## 2. 为什么需要运行时类型信息

编译器已知 `DeviceService` 时，直接调用最清楚、最快，也最容易重构。只有当类型直到运行时才确定，例如加载插件、读取运行期注解或为多种接口统一加审计，反射才有价值。先问“静态多态能否解决”，再引入运行时机制。

反射不是另一套对象模型。它仍受 Java 类型、访问控制、模块、异常和类加载规则约束，只是把部分检查从编译期推迟到运行期。因此每个字符串类名和方法名都需要失败契约。

## 3. `Class` 对象是什么

运行中的类、接口、数组、枚举、record、注解接口、基本类型和 `void` 都由 `Class` 对象描述。`String.class` 的静态类型是 `Class<String>`；类型未知时使用 `Class<?>`，不要退化成裸 `Class`。

`Class` 没有公开构造器。JVM 在类定义过程中创建它，同一个运行时类型共享同一 `Class` 实例。它是类型元数据句柄，不是该类型的业务对象。

## 4. 获得 `Class` 的三种入口

已知类型用 `DeviceService.class`，已有非 null 对象用 `value.getClass()`，只有运行时字符串时才考虑 `Class.forName(...)` 或特定 `ClassLoader.loadClass(...)`。类字面量最可读，也能被编译器和 IDE 安全重构。

`getClass()` 的结果描述对象实际运行时类型，不一定是变量声明类型。对代理对象调用 `getClass()` 得到生成的代理类；判断契约应看 `instanceof` 或接口，而非生成类名。

## 5. `Class<T>` 与类型令牌

`Class<T>` 把运行时类型与编译期泛型连接起来，常作为类型令牌传入 `read(Class<T> type)`。`type.cast(value)` 比手写强制转换更适合运行时检查，失败时仍是清晰的 `ClassCastException`。

泛型参数通常被擦除，`List<String>.class` 不存在；只有 `List.class`。需要完整泛型形状时要使用 `Type`、`ParameterizedType` 或框架自己的类型令牌，但本章不构建泛型映射器。

## 6. 类名的几种形式

`getName()` 常返回二进制名称，如 `java.util.Map$Entry`；`getCanonicalName()` 适合有规范名称的类型，但匿名、局部或隐藏类可能返回 null；`getSimpleName()` 适合展示，不保证唯一。日志与协议必须说明使用哪一种。

`Class.forName` 需要二进制名称，不接受任意源代码写法。把用户展示名直接当类名是脆弱协议，也可能扩大可加载类型范围。

## 7. 基本类型和数组

`int.class`、`void.class` 与 `String[].class` 都是合法 `Class`。数组类的类加载器与其引用组件类型相关，基本类型数组则没有普通定义类加载器。`isArray()`、`getComponentType()`、`isPrimitive()` 应显式区分这些形状。

反射调用会做装箱、拆箱和部分方法调用转换，但不会替你修正任意参数形状。测试应包含 null、数组和错误参数类型，不能只测一个字符串。

## 8. 类型检查方向

`expected.isInstance(value)` 等价于运行时的 `value instanceof Expected` 思路，并安全处理 null。`A.isAssignableFrom(B)` 问的是“B 的实例能否赋给 A 变量”；方向写反是常见错误。

可以用一句话校验：左边是接收者类型，右边是候选实现类型。接口 `DeviceService.class.isAssignableFrom(DeviceServiceImpl.class)` 应为 true，反向通常为 false。

## 9. 运行时类身份

JVM 中的类身份不只由二进制名称决定，而是“名称 + 定义它的类加载器”。两份字节即使名称完全相同，由不同定义加载器加载后也是不同类型，彼此强制转换会失败。

插件系统中看到“`Plugin` cannot be cast to `Plugin`”并不矛盾，先记录两侧 `Class.getClassLoader()` 和接口来源。修复通常是让共享 API 由共同父加载器定义，而非继续强制转换。

## 10. 公共成员与声明成员

`getMethods()` 返回可访问的 public 方法并包含继承成员；`getDeclaredMethods()` 返回该类直接声明的方法，含 private/protected/package 成员但不含继承方法。字段和构造器有对应的 public/declared 区分。

选择 API 要对应业务契约。若代理契约只允许 public 接口方法，使用接口的 `getMethod` 更清楚；扫描 declared 成员再强行开放会无意扩大访问面。

## 11. 方法查找需要精确签名

`getMethod("repair", String.class)` 同时使用名称和参数类型定位重载。只按方法名过滤，在出现重载、桥接方法或编译器生成方法时会得到不稳定结果。返回类型不参与 Java 重载选择。

反射枚举顺序不应成为协议。需要输出报告时按声明类、方法名和参数类型显式排序，避免文件或 JVM 实现差异让测试漂移。

## 12. 构造对象

旧的 `Class.newInstance()` 已弃用，因为它混淆访问和构造器异常。现代代码先 `getDeclaredConstructor(...)`，再按访问契约决定是否可调用，最后 `newInstance(args)`。

更好的插件 API 往往使用显式工厂或 `ServiceLoader`，避免框架假设“每个实现都有无参构造器”。反射构造失败应保留原构造器 cause。

## 13. 调用 `Method.invoke`

`method.invoke(receiver, args...)` 对实例方法需要兼容 receiver；静态方法 receiver 可为 null。参数数量或类型错误抛 `IllegalArgumentException`，访问失败抛 `IllegalAccessException`，目标自身异常则包装在 `InvocationTargetException`。

调用成功只说明反射机制完成，不说明业务授权或输入可信。代理应先完成显式角色检查，再委托业务接口。

## 14. 目标异常必须解包

目标方法抛 `DeviceOfflineException` 时，`Method.invoke` 外层是 `InvocationTargetException`，真正业务失败在 `getCause()`。若 InvocationHandler 直接把包装异常抛出，调用者会看到错误抽象，甚至再被包装成 `UndeclaredThrowableException`。

正确代理捕获 `InvocationTargetException` 后抛其 cause；日志记录业务异常类型但不吞掉。离线资产断言 cause 身份与消息，而不是搜索一段堆栈文本。

## 15. 反射参数与可变参数

`invoke` 本身是 varargs API，传数组时容易出现“把数组当参数列表还是单个参数”的歧义。目标方法若接收一个数组，通常需要把它作为单个 `Object` 参数表达。错误夹具应报告 expected parameter count 与 actual。

反射不会进行任意字符串到数字的业务转换。先在边界解析和验证，再传类型正确的对象；不要把 `Method.invoke` 当动态脚本解释器。

## 16. 字段访问的边界

`Field.get/set` 可读写字段，但直接改 private 状态绕过构造器、不变量和领域方法。序列化框架有专门契约与测试时可能使用，业务代码应优先调用公开方法或 record 访问器。

final、静态字段及模块封装还有额外限制。即使某次 JVM 上“能改”，也不应把未承诺行为变成业务依赖。

## 17. Java 语言访问检查

拿到 `Method` 不等于有权调用。public、protected、包访问和 private 的语言规则仍生效。`canAccess(receiver)` 可以检查当前反射对象是否允许对给定 receiver 访问；静态成员 receiver 要按 API 规则传 null。

访问失败是契约证据，不应该被统一转换成“method missing”。`NoSuchMethodException` 与 `IllegalAccessException` 指向完全不同的修复方向。

## 18. `trySetAccessible`

`trySetAccessible()` 尝试压制语言访问检查，成功返回 true，无法开放时返回 false；相比 `setAccessible(true)` 失败时直接抛 `InaccessibleObjectException`，它更适合显式分支。返回 false 时应停止并报告所需公开契约。

“能打开”不等于“应该打开”。本章通过 public 接口代理业务，只用私有成员故障说明边界，不把深反射作为默认实现。

## 19. 模块的 exports 与 opens

命名模块的 `exports` 允许其他模块正常访问包内 public API；`opens` 允许深反射访问包内非 public 成员。两者职责不同。未命名模块较宽松不代表生产模块也会宽松。

框架需要反射时，应在 `module-info.java` 中最小化 `opens ... to ...`，而不是全局 `open module`。不要把 `--add-opens` 当永久修复，它更适合迁移诊断并需记录风险。

## 20. `Class.forName` 与初始化

单参数 `Class.forName(name)` 会加载并初始化类，可能触发静态字段和静态块。三参数形式可以指定是否初始化和使用哪个加载器；`ClassLoader.loadClass` 通常只加载，不主动初始化。

扫描候选类时意外初始化会执行未知代码、读取配置或失败。若只需元数据，必须理解初始化参数和注解访问是否触发其他类型解析。

## 21. 加载、链接、初始化

加载从字节创建 Class；链接包含验证、准备和解析；初始化执行静态初始化逻辑。这三个阶段可能交错或延迟，不能把“找到 class 文件”说成“类已可成功使用”。

静态初始化失败可能抛 `ExceptionInInitializerError`；后续再使用还可能看到 `NoClassDefFoundError`。保存第一处失败比只看后续症状重要。

## 22. ClassLoader 层次

常见视角包括 bootstrap、platform 和 application/system class loader。bootstrap 由虚拟机表示，`Object.class.getClassLoader()` 常返回 null；null 是特殊含义，不是“类没有加载器”。

自定义或框架加载器可位于应用之下。不要根据类名字符串猜层次，直接记录加载器名称、对象身份与 parent 链。

## 23. 父级委派

标准 ClassLoader 通常先检查已加载类型，再委托 parent，parent 找不到后才调用自身 `findClass`。这保护平台类的一致性并让共享 API 只定义一次。官方文档称其为 delegation model，而不是不可打破的宇宙定律。

某些容器或插件采用 child-first 变体解决依赖隔离，但成本是类型冲突、资源顺序和安全审查更复杂。本章不实现 child-first 加载器。

## 24. 为什么不能伪造 `java.*`

父级委派和 JVM 限制共同避免应用随意替换核心类。自己创建名为 `java.lang.String` 的字节并不能安全覆盖平台 String。把自定义类加载器当安全边界或核心补丁机制是错误方向。

依赖冲突应由构建、模块、插件 API 与隔离策略解决，不通过冒充平台包。

## 25. `ClassNotFoundException` 与 `NoClassDefFoundError`

显式按名称加载找不到目标常得到受检 `ClassNotFoundException`；已经编译引用的类在运行期缺失或先前初始化失败，常表现为 `NoClassDefFoundError`。一个偏显式查找失败，一个是链接/定义可用性错误。

不要 catch `Throwable` 后都返回“插件不存在”。记录请求类名、使用的加载器、第一 cause 和当前模块，才能区分路径、版本与初始化问题。

## 26. 链接错误

`NoSuchMethodError`、`IncompatibleClassChangeError` 等 `LinkageError` 常意味着编译时与运行时字节版本不一致。反射的 `NoSuchMethodException` 则是显式查找结果。两者名字相似但修复层不同。

前者检查依赖树、classpath/module path 和加载来源；后者检查方法名、参数与扫描契约。不要用增加 accessible 权限修复版本不匹配。

## 27. 上下文 ClassLoader

线程上下文 ClassLoader（TCCL）让上层平台代码按当前应用或插件环境发现实现。SPI、日志和框架可能依赖它，但业务方法不应到处读取 TCCL 猜类型来源。

若某个作用域临时设置 TCCL，必须在 finally 恢复原值。线程池复用线程时，忘记恢复会把一个请求的加载环境泄漏给下一个请求。

## 28. 错误 TCCL 的确定性证据

资产使用一个明确拒绝目标类名的 ClassLoader 作为临时上下文，然后证明按它加载会抛 `ClassNotFoundException`；恢复后再由显式应用加载器成功获取类型。故障不依赖磁盘扫描或第三方插件。

修复不是永远改全局 TCCL，而是把期望加载器作为参数传入，或只在受控 SPI 边界短暂切换并恢复。

## 29. 类路径资源

`Class.getResource`、`ClassLoader.getResource` 的相对名称规则不同。类方法中不以 `/` 开头通常相对包，ClassLoader 名称通常从根开始且不以 `/` 开头。资源存在也不代表可转成本地文件 Path，JAR 内资源不是普通文件。

`getResourceAsStream` 返回的流遵循所有权规则，必须关闭。读取配置时固定 UTF-8，并限制大小；本章资产不扫描真实 classpath。

## 30. 可关闭的加载器

`URLClassLoader` 实现 Closeable，持有 JAR 资源时由创建它的插件容器关闭。关闭加载器不会卸载仍被对象、线程、缓存或 Class 引用的类。类卸载取决于定义加载器与其所有类都不可达等条件。

缓存 `Class`/`Method` 时要考虑加载器生命周期。全局静态 Map 以插件 Class 为 key 会阻止插件卸载，形成元空间与文件句柄泄漏。

## 31. 反射结果缓存

重复查找 Method 有成本，可以按“定义 Class + 精确签名”缓存，但不能只用类名字符串，否则不同加载器会串线。弱引用是否合适要根据生命周期和并发策略设计。

先测量再缓存。初学实现保持局部、确定、可验证，避免用复杂缓存掩盖访问和身份错误。

## 32. 动态代理解决什么

JDK `Proxy` 为一组接口生成实现类，所有接口调用转给一个 InvocationHandler。适合审计、计时、权限或重试等围绕接口调用的横切逻辑。它不修改目标类字节，也不是任意具体类子类代理。

与 TypeScript/Vue 类比：Java 代理在运行期拦截调用，但它只承诺声明的 Java 接口；不是 Vue 响应式 Proxy，也不能观察任意字段赋值。

## 33. 只代理接口

目标类没有实现接口时，JDK Proxy 无法让返回对象强制转换成该具体类。代理构造应接收明确接口 `Class<T>`，检查 `isInterface()`，并检查接口是否可从目标类型赋值。

需要代理具体类通常依赖字节码生成或手写子类，涉及 final 方法、构造器和模块限制，超出本章。最佳默认是先设计清晰接口。

## 34. 创建代理的三个输入

`Proxy.newProxyInstance(loader, interfaces, handler)` 需要能看见所有接口的加载器、非空接口数组和 handler。接口重复、不可见、非接口或非 public 接口不兼容都可能抛 `IllegalArgumentException`。

一般使用接口的定义加载器或经过验证的共同可见加载器，不盲目使用当前线程 TCCL。代理返回后以接口类型暴露，不依赖生成类名和包名。

## 35. InvocationHandler 的职责

`invoke(proxy, method, args)` 中的 proxy 是代理对象，不是目标；在 handler 内对 proxy 再调用同一接口会无限递归。委托必须调用保存的 target。

args 对无参方法可能为 null，日志代码需处理。不要把参数 `toString()` 全量写日志，工单描述、token 或个人信息可能泄露。

## 36. 委托链与返回值

最小 handler 顺序是：识别方法与注解；执行授权；记录安全的调用前事件；调用 target；记录结果类别；返回原业务值。除非契约明确，横切层不能修改返回内容。

验收断言代理前后 `findDevice("A-17")` 返回完全相同值，并且事件序列恰好一次 before/after。只断言“日志出现”会漏掉重复调用。

## 37. 注解读取位置

接口方法与实现方法是不同的 Method 对象。`@RequiresRole` 若声明在接口方法，handler 收到的 Method 通常正适合读取；若只写在实现方法，则需明确查找目标实现签名。注解是否继承不能凭感觉。

本章契约把授权注解放在接口方法并要求 RUNTIME 保留。生产设计应选一个唯一来源，避免接口与实现冲突时临时决定谁优先。

## 38. `Object` 三个方法

代理上的 `equals`、`hashCode`、`toString` 也会进入 handler。若一律当业务方法检查角色或反射调用，可能产生意外日志、递归或不稳定集合行为。

明确政策：可以让 `toString` 返回不含敏感数据的代理描述，让 `hashCode` 使用代理身份，让 `equals` 使用身份比较；也可显式委托，但必须成组测试。不要默认 `method.invoke(target,args)` 就一定符合代理身份语义。

## 39. 默认接口方法

接口 default 方法也可能进入 handler。是委托到 target、调用默认实现，还是作为普通契约方法处理要明确。JDK 提供 `InvocationHandler.invokeDefault` 支持调用默认实现，但本章基本代理不依赖它。

复杂默认方法组合、菱形冲突与动态模块访问应单独测试，不能只在一个实现上偶然工作就泛化。

## 40. 代理异常透明性

handler 可以抛运行时异常、Error，或接口方法 `throws` 声明兼容的受检异常。其他受检异常可能被代理包装成 `UndeclaredThrowableException`。这会改变调用者契约。

反射委托应解包 `InvocationTargetException` 并抛目标 cause。授权失败使用稳定的领域异常；审计失败是否阻止业务也必须由明确政策决定。

## 41. 代理类与模块

代理类放在哪个包和模块取决于接口可见性。public 接口可能生成在运行时动态模块的非导出、非开放包；含 non-public 接口时，接口必须位于兼容的同一包和模块。

不要反射构造代理生成类。官方契约明确应使用 `Proxy.newProxyInstance`；生成类名、模块名和包名都不是稳定 API。

## 42. 手写装饰器何时更好

接口少、横切规则稳定时，手写 `AuditedDeviceService` 更易阅读、调试和静态检查。动态代理适合许多同形接口、规则来自运行期元数据的场景，但增加反射异常和调用链成本。

选型维度包括实现量、运行时失败风险、模块限制、性能、调试和长期维护。不要因为“框架都用反射”就为两个方法建立小框架。

## 43. MethodHandle 边界

`java.lang.invoke` 的 MethodHandle 可提供更强类型化的调用与 JVM 优化路径，但查找权限同样受模块和 Lookup 约束。它不是绕开访问控制的后门。

本章先掌握 Method 与 Proxy 的可观察失败。性能热点经基准证明后再评估 MethodHandle 或生成代码。

## 44. 不可信类名风险

让外部请求直接提供任意类名会扩大初始化副作用、资源消耗和可用类型面。即使没有远程代码下载，加载 classpath 上已有危险类型也可能触发意外行为。

使用服务 ID 到已审核实现的 allowlist，或 `ServiceLoader` 加显式模块契约。错误消息不回显完整内部 classpath、模块路径或文件位置。

## 45. 不可信成员名风险

把请求字段直接映射成任意 getter/setter，会暴露未计划的属性并产生 mass assignment。反射序列化必须有字段 allowlist、大小/深度限制和版本契约。

权限注解扫描也不能把“有注解”当身份认证。注解是元数据，真实主体和角色必须来自可信安全上下文。

## 46. 日志与敏感参数

InvocationHandler 很容易记录全部参数和返回值，但设备备注、维修人员信息、认证头或异常消息可能敏感。日志只记录方法 ID、授权结果、耗时类别和脱敏业务键。

toString 也可能执行代码或抛异常。安全日志不递归序列化未知对象，不让日志失败覆盖业务 cause。

## 47. 反射与性能

反射查找、访问检查、参数数组和代理分派有额外成本，但多数管理系统瓶颈在数据库和网络。没有基准前不要以性能为理由复制复杂缓存，也不要把每行数据都做全量成员扫描。

优化顺序是缩小扫描范围、缓存稳定元数据、批量处理，再测量。正确性、异常透明和模块兼容先于微优化。

## 48. FactoryCare 授权代理

`DeviceAction` 接口的危险操作标记 `@RequiresRole("MAINTAINER")`。工厂接收接口、目标和当前角色，读取接口 Method 注解；角色不符时拒绝，符合时记录 `before:method`，委托目标，再记录 `after:method`。

这只是教学授权边界，不替代 Spring Security、会话认证、租户校验或数据库授权。代理前后的业务返回必须一致，角色输入由测试显式提供。

## 49. 正常 oracle

固定方法 `inspect("A-17")` 返回 `device=A-17`。断言接口类型检查、Class 名称、定义加载器、注解值、事件顺序、业务调用次数和返回值。所有报告只含稳定逻辑名，不打印机器路径或生成代理类名。

`proxy instanceof DeviceAction` 为 true，`proxy instanceof DeviceActionImpl` 为 false。这个对比直接证明 JDK Proxy 是接口实现而非目标子类。

## 50. 无接口目标故障

错误工厂从目标类接口数组自动猜契约；传入无接口目标后数组为空或调用方错误强转。确定性夹具应先检查接口不是 interface 或目标不实现接口，并以固定非零退出码报告 expected/actual。

修复为显式 `create(Class<T> contract,T target,...)`，而不是继续遍历目标所有接口猜一个“最像的”。

## 51. 私有成员故障

夹具取得另一个顶层类的 private 成员并直接调用，稳定观察语言访问异常；若边界换成未开放包中的命名模块，`trySetAccessible=false` 还能进一步证明模块拒绝深反射。资产不依赖 JDK 内部成员，因此不会随平台实现漂移。

修复是提供 public 接口或受控访问器，不在验证器加 `--add-opens`。

## 52. 错误加载器故障

拒绝加载目标名称的 ClassLoader 收到请求后抛固定 `ClassNotFoundException`。报告同时记录 requested loader 与 expected loader 的逻辑标签，不依赖 JDK 内部加载器类名。

修复把接口定义加载器显式传给代理，并在临时切换 TCCL 后 finally 恢复。恢复本身也要有断言。

## 53. 目标异常故障

目标方法固定抛 `IllegalStateException("device offline")`。错误 handler 直接传播 InvocationTargetException，第一证据是 actual wrapper；正确 handler 解包后调用者看到同一个 IllegalStateException cause。

测试还断言 after-success 事件没有出现，避免失败也被记成成功。可以另记 failure 事件，但不能改变主异常。

## 54. 预测练习

运行前预测：`getMethods` 是否含继承方法；`getDeclaredMethods` 是否含父类方法；同名类由两个加载器加载后是否相等；`Object.class.getClassLoader()` 是什么；代理能否强转为目标类；目标异常外层是什么；handler 内调用 proxy 会怎样。

把预测写成布尔或异常类型，再运行工件。对照后把误区改写成一条边界规则，而不是只抄输出。

## 55. 独立构建任务

从空文件声明 RUNTIME/METHOD 的 `@RequiresRole`、`DeviceAction` 接口和实现。实现代理工厂时必须接收显式接口 Class，读取接口方法注解，验证角色并解包 InvocationTargetException。

至少测试普通返回、无注解方法、拒绝角色、目标异常、Object 方法和无接口契约。报告 Class、加载器逻辑名、方法与事件链。

## 56. 修改任务

把单一角色改为允许两个角色，保持注解元素与代理工厂局部变化；增加一个 default 方法并明确处理政策。不能删除原故障测试或重写整个代理。

再把日志参数从完整设备对象改为只记录设备 ID，解释为什么这是数据最小化而非功能倒退。

## 57. 诊断顺序

先读异常类型：ClassNotFound、NoSuchMethod、IllegalAccess、InvocationTarget、ClassCast、UndeclaredThrowable 分别属于不同边界。再记录请求类型、定义加载器、接口列表、Method 声明类、模块和 cause。

一次只修一个故障并复跑正常路径。不要用 catch Throwable、全局 setAccessible 或随意换 TCCL 抹掉证据。

## 58. 120 秒复述提纲

不看正文说明：Class 对象代表什么？类身份为何含加载器？父级委派解决什么？public 与 declared 成员差别？exports 与 opens 差别？JDK Proxy 为何只能代理接口？InvocationHandler 如何保持返回值与异常透明？

最后讲“同名类不能转换”或“目标异常被包装”中的一个失败链，指出第一处可信证据和修复边界。

## 59. 验收清单

- Class 获取、名称、类型检查方向和成员查找有确定断言。
- `@RequiresRole` 从约定位置读取，保留策略为 RUNTIME。
- 代理只接收显式接口，目标必须实现它，业务返回与调用次数不变。
- 目标异常解包，授权拒绝和反射失败不被吞掉。
- 定义加载器、parent/TCCL 和临时恢复有可观察证据。
- 私有成员失败不会通过 `--add-opens` 或全局 accessible 掩盖。
- 不扫描真实 classpath，不下载类，不记录敏感参数。
- 四类资产均在 Java 25 下离线运行。

## 60. 有意不做

本章不实现 DI 容器、classpath/JAR 全量扫描、热部署、child-first 插件系统、字节码生成、CGLIB/Byte Buddy、Spring AOP 或完整模块化插件安全。也不把 `SecurityManager` 当现代沙箱方案。

没有为“任意具体类也能代理”做兼容妥协；JDK Proxy 的接口限制被保留为显式契约。需要具体类代理时应另行比较生成代码、维护成本、模块与安全风险。

## 61. 一手资料

- [Class，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Class.html)
- [ClassLoader，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/ClassLoader.html)
- [AccessibleObject，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/reflect/AccessibleObject.html)
- [Proxy，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/reflect/Proxy.html)
- [InvocationHandler，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/reflect/InvocationHandler.html)
