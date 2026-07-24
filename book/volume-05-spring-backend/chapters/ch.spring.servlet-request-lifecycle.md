---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.servlet-request-lifecycle
title: HTTP 请求生命周期、Servlet 与线程边界
responsibility: 把 HTTP 报文落实为 Java Web 请求响应生命周期，不提前引入 Spring IoC、Controller 或安全过滤链
volume: '05'
order: 1
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.servlet-request-lifecycle.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.api-contract-basics
- ch.java-engineering.maven-reproducible-builds
version_surfaces:
- jdk-25
- jakarta-ee
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
  text: 在 120 秒内解释HTTP 请求生命周期、Servlet 与线程边界的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - servlet-request-response
  - servlet-lifecycle-thread
  covers_topics:
  - servlet.container
  - servlet.request-response
  - servlet.filter-chain-basic
  - servlet.request-lifecycle
  - servlet.thread-per-request-boundary
  - servlet.async-boundary
  uses_capabilities:
  - foundation.http-message
  - java.build-testing
  - backend.servlet-request
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现最小 Servlet/Filter：记录 method/path/thread，读取参数并返回明确 status/header/body，保存并发请求证据
  covers_topic_groups:
  - servlet-request-response
  - servlet-lifecycle-thread
  covers_topics:
  - servlet.container
  - servlet.request-response
  - servlet.filter-chain-basic
  - servlet.request-lifecycle
  - servlet.thread-per-request-boundary
  - servlet.async-boundary
  uses_capabilities:
  - foundation.http-message
  - java.build-testing
  - backend.servlet-request
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入响应提交后再改状态、请求对象跨线程保存和 Filter 不继续链，依据容器日志/响应修复
  covers_topic_groups:
  - servlet-request-response
  - servlet-lifecycle-thread
  covers_topics:
  - servlet.container
  - servlet.request-response
  - servlet.filter-chain-basic
  - servlet.request-lifecycle
  - servlet.thread-per-request-boundary
  - servlet.async-boundary
  uses_capabilities:
  - foundation.http-message
  - java.build-testing
  - backend.servlet-request
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# HTTP 请求生命周期、Servlet 与线程边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《API 资源、错误、版本、分页、缓存与幂等语义》](../../volume-00-computer-foundations/chapters/ch.foundations.api-contract-basics.md)：独立完成Servlet 请求响应、生命周期与线程前，必须先具备「API 资源、错误、版本、分页、缓存与幂等语义」已经验证的知识与失败边界
- [《Maven 生命周期、依赖范围、插件与可重复构建》](../../volume-03-java-engineering/chapters/ch.java-engineering.maven-reproducible-builds.md)：独立完成Servlet 请求响应、生命周期与线程前，必须先具备「Maven 生命周期、依赖范围、插件与可重复构建」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文与工件是作者级教材证据，不自动修改 `PROGRESS.md`，也不代表学习者已经独立通过 G2。

浏览器或 API 客户端发送的是 HTTP 报文，Java 方法收到的却是 `HttpServletRequest`，写回的是 `HttpServletResponse`。中间的 Servlet 容器负责监听连接、解析协议、选择 Web 应用和映射、建立请求响应对象、调用 Filter 链与目标 Servlet、提交响应并回收本次请求资源。理解这条链，才能判断一个 400、500、空 body、串请求数据或“响应已提交”究竟发生在哪一层。

本章只讲 Jakarta Servlet 基础边界。它不引入 Spring IoC、`DispatcherServlet`、Controller、Security Filter Chain 或生产容器配置；末尾只给出通向 Spring MVC 的位置图。离线工件使用 JDK 25、Maven 3.9.16 与 Jakarta Servlet 6.1 API，通过内存请求/响应替身验证 Filter、Servlet、并发与异步状态，不监听端口。官方资料复核日期为 **2026-07-17**。

## 1. 本章完成证据

完成不是“背出 Servlet 三个方法”。你需要在 120 秒内说清 HTTP 报文如何变成 request/response 对象，Filter 为什么必须决定是否继续链，以及同一 Servlet 实例为何会同时处理多条请求。构建证据必须包含正常 200、缺参数 400、Filter 前后顺序、两个并发请求互不串值和资源收尾。

配套工件：

- [Servlet 请求观察台](../../../examples/encyclopedia/ch.spring.servlet-request-lifecycle/README.md)
- [Filter、提交与并发实验](../../../labs/encyclopedia/ch.spring.servlet-request-lifecycle/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.spring.servlet-request-lifecycle/README.md)

## 2. 从 HTTP 报文开始

请求报文包含 method、request target、协议版本、headers 与可选 body；响应包含状态码、headers 与可选 body。Servlet API 没有改变这些语义，只是把容器已解析的内容暴露为 Java 接口。`getMethod()`、`getRequestURI()`、`getHeader()` 和输入流分别对应不同报文部分。

把 request 当普通 Map 会丢失编码、重复 header、流式 body、提交状态和 dispatch 类型。先按 HTTP 契约判断，再选 Servlet API；不能因为 Java 方法返回字符串就忘记最终仍要形成合法响应。

## 3. 连接不等于请求

TCP 连接可能承载一个或多个 HTTP 请求，HTTP/2 还可能复用并发流。Servlet 编程模型围绕一次 dispatch 的 request/response 对，而不是让业务代码直接拥有底层 Socket。容器负责协议和连接复用，应用不要关闭客户端连接对应的底层流。

一次 request 生命周期也不必等于一个线程生命周期。同步 dispatch 常在容器线程上完成，异步模式则会把完成点延后。把“一个请求永远一个线程”当规范，会在 async、error 或 redispatch 时出错。

## 4. Servlet 容器的职责

容器例如符合规范的 Tomcat 实现监听、协议解析、Web 应用隔离、组件生命周期、映射、并发调度、Filter 链、错误 dispatch 和响应提交。Servlet 类只实现应用端契约，不自己解析 HTTP 起始行，也不创建请求对象。

容器不是业务层。它不知道“设备是否存在”或“工单能否关闭”；这些规则仍应由应用服务和领域模型决定。本章的测试替身只模拟必要契约，不宣称替代真实兼容性测试。

## 5. Web 应用与映射

容器先根据 host/context path 选择 Web 应用，再根据 URL pattern 选择 Servlet 与适用 Filter。映射可能来自部署描述符、注解或程序化注册。多个 pattern 的优先规则属于容器契约，不能靠类名猜测。

请求 URI、context path、servlet path 与 path info 含义不同。日志应记录明确字段；把它们拼成一个“path”后再做授权，容易在 forward 或 async dispatch 时使用错目标。

## 6. Servlet 实例生命周期

典型顺序是容器创建 Servlet 实例，调用一次 `init`，随后多次调用 `service`，最后在下线时调用一次 `destroy`。初始化失败时组件不会正常进入服务；销毁用于释放实例生命周期资源，不处理某一条请求的业务结束。

生命周期回调由容器控制，业务代码不要自行重复调用 `init` 或 `destroy`。实例长寿命而请求短寿命，这个不对称正是“不能把请求数据存进实例字段”的根因。

## 7. `HttpServlet.service` 的分派

`HttpServlet` 的 public `service(ServletRequest,ServletResponse)` 检查 HTTP 类型，再由 HTTP 版本的 `service` 根据 method 调用 `doGet`、`doPost` 等方法。普通应用很少重写总 `service`，而是只覆盖支持的方法。

未实现的方法应由基类产生规范定义的结果，而不是所有 method 都进入同一业务分支。GET、POST、PUT、DELETE 的 HTTP 语义仍要由 API 契约决定，Servlet 方法名不自动提供幂等性。

## 8. `HttpServletRequest` 是容器视图

request 提供 method、URI、query、header、cookie、参数、body、attributes、locale、会话和 dispatch 信息。它通常由容器复用内部结构并受当前生命周期约束，不是可永久保存的 DTO。

边界层应尽快读取必要值、校验并复制成自己的不可变输入。把整个 request 传到领域层，会让业务依赖容器 API，也会诱发跨线程和生命周期泄漏。

## 9. 参数与 body 不是一回事

`getParameter` 可能组合 query string 和特定表单 body；JSON body 则通常通过输入流或 reader 读取。参数缺失返回 null，空字符串与缺失不同，必须由 API 契约决定是否均为 400。

读取 body 前要确定字符编码、media type 和大小上限。输入流一般只能消费一次；Filter 若提前读完又不包装并重放，下游会看到空 body。

## 10. 字符编码边界

URI、header 与 body 有各自编码规则。对文本 body，应在读取前按协议或默认规则确定 charset；写响应时应在取得 writer 前设置 content type 与编码。事后再改可能来不及影响已经创建的 writer。

固定 UTF-8 是应用常见政策，但不能把字节长度写成 `String.length()`。容器负责传输编码，业务仍需验证解码后的结构和长度。

## 11. request attributes

attribute 是本次请求/dispatch 内部协作空间，适合 Filter 写入 correlation ID、解析后的主体或计时信息，再由下游读取。它不同于客户端参数，客户端不能直接控制 attribute。

名称要使用稳定命名空间，值要有清晰所有者。attributes 仍属于 request 生命周期，不应被全局缓存；异步与包装场景还需遵守容器对 supplied request 的规则。

## 12. `HttpServletResponse` 是可变输出状态

response 允许设置状态、header、content type、编码并写 body。开始时它尚未提交，应用可调整；一旦 buffer 被 flush、填满或容器决定提交，状态和 headers 就不能再可靠修改。

响应对象不是最终网络报文的副本，而是容器正在构造的输出。测试必须同时断言 status、headers、body 与 committed 状态，不能只看 body 文本。

## 13. 状态码先于 body

成功不是“写出了内容”，而是状态与内容共同满足契约。缺必填参数用明确 4xx，未处理异常通常进入 5xx/error dispatch。不要写一段错误 JSON 却保留默认 200。

设置状态应发生在写 body 之前。对 204 等无 body 状态不要继续输出内容；重定向和错误辅助方法可能同时影响状态、header、body 与提交行为，应查具体 API。

## 14. headers 与重复值

`setHeader` 替换同名值，`addHeader` 追加值。Content-Type、Location、Cache-Control 等有各自语义，不能把逗号拼接当通用多值规则。响应 header 必须在提交前完成。

请求 header 来自不可信客户端。日志不要记录 Authorization、Cookie 或完整个人信息；用于程序分支时要处理缺失、重复、大小写和非法值。

## 15. writer 与 output stream

文本响应通常使用 writer，二进制使用 output stream。规范不允许同一响应随意混用两者；取得其中一个后再取另一个会失败。Controller 尚未出现时，这就是最直接的消息转换边界。

关闭或 flush writer 可能推进提交。应用通常写完后让容器负责最终关闭；不要为了“保险”同时关闭 response、writer 和底层连接。

## 16. buffer 与 committed

buffer 允许在尚未发送时积累 body，从而仍有机会改变状态或 reset。`isCommitted()` 表示状态和 headers 是否已写向客户端；`resetBuffer` 只清 body，`reset` 的范围更大，且提交后调用会失败。

“先 flush 再 setStatus(500)”是本章故障之一。可信证据不是代码执行到了 setStatus，而是客户端实际状态仍是原值或容器报告已提交。

## 17. Filter 的位置

Filter 位于容器映射和目标资源之间，可检查或包装 request/response，记录日志，拒绝请求，或调用 `chain.doFilter` 继续。一个请求可能经过多个 Filter，配置顺序决定嵌套顺序。

Filter 适合协议级横切行为，不应装入完整业务流程。本章只用普通 tracing/required-parameter Filter，不提前实现 Spring Security 过滤链。

## 18. Filter 链的进入与返回

若顺序为 A、B、Servlet，进入事件是 `A.before → B.before → servlet`，返回事件是 `B.after → A.after`。after 逻辑必须放在 `try/finally`，否则下游抛异常时无法稳定收尾。

这与函数嵌套或 Vue middleware 的“前置/next/后置”相似，但 Servlet Filter 的 request/response 由容器管理。事件断言应按单个请求关联，避免并发日志交错造成假失败。

## 19. Filter 可以终止链

Filter 不调用 `chain.doFilter` 就会阻断后续。合法场景是已经写出明确拒绝响应；错误场景是忘记调用链，最终得到空的默认响应或半成品。

阻断分支必须设置 status、content type 和受限 body，并保证不会再执行目标 Servlet。正常分支必须恰好继续一次；调用两次会重复执行业务。

## 20. Filter 包装

`HttpServletRequestWrapper` 和 `HttpServletResponseWrapper` 可局部覆盖行为，例如缓存 body 或统计输出字节。包装必须把未改变的方法委托原对象，并在 async/dispatch 生命周期中保留正确对象。

自己实现整个接口容易遗漏规范演进。优先使用 wrapper 基类，只覆盖必要方法；本章内存替身仅用于测试，不作为生产 wrapper 模板。

## 21. DispatcherType

Filter 可针对 REQUEST、FORWARD、INCLUDE、ERROR、ASYNC 等 dispatch 类型配置。同一逻辑请求可能经历多个 dispatch，Filter 也可能被再次调用。把 Filter 次数等同于客户端请求数并不总正确。

日志应包含 dispatcher type 和稳定 request ID。某些行为只应在初始 REQUEST 执行一次，另一些如安全检查可能需要覆盖后续 dispatch；具体政策必须显式。

## 22. forward、include 与 error dispatch

forward 把控制交给另一个资源，include 把另一个资源输出包含进当前响应，error dispatch 让容器处理异常或错误状态。它们会影响路径属性、响应提交和 Filter 匹配。

本章不实现页面分派，但要求知道 request URI 不一定等于当前目标。诊断时同时查看 dispatcher type、映射与错误 attributes，而不是只看浏览器地址栏。

## 23. 通向 Spring MVC 的位置

后续 Spring MVC 会把一个 `DispatcherServlet` 注册为目标 Servlet，再由它做 handler mapping、参数解析、Controller 调用与响应转换。容器和外层 Filter 仍在它之前，Controller 也仍受 response 提交和线程边界约束。

本章不创建 DispatcherServlet 或 Controller。先掌握原生链，下一章之后再把“目标 Servlet 内部”展开，避免把所有 Web 行为误认成 Spring 注解魔法。

## 24. Servlet 通常被并发调用

容器通常为一个 Servlet 实例并发调用 `service`。不同请求可能在不同平台线程或虚拟线程上执行，顺序不保证。实例字段因此是共享状态，不是请求变量。

局部变量位于本次调用栈，request attributes 绑定本次请求，不可变协作者可安全共享。共享可变集合、StringBuilder 或“currentUser”字段会串请求并产生数据竞争。

## 25. 不要把请求数据放实例字段

错误 Servlet 把 `request.getParameter("id")` 保存到 `this.currentId`，随后再读取。两个并发请求可互相覆盖，哪怕单机测试偶尔通过。加 synchronized 虽可能隐藏竞争，却会串行化所有请求且仍混淆生命周期。

修复是让 id 保持局部值，或复制进本次请求专属的不可变 command。共享字段只保存线程安全、跨请求的协作者或配置。

## 26. ThreadLocal 不是默认请求仓库

ThreadLocal 可绑定当前线程上下文，但容器线程会复用，async 还可能换线程。忘记 finally remove 会把一个请求的数据泄漏给下一个请求，造成身份和内存风险。

优先显式参数和 request attributes。若框架边界确实使用线程上下文，必须定义设置、读取、清理和异步传播政策，并用复用线程故障测试。

## 27. request 对象不能任意跨线程保存

容器提供的 request/response 只在规范允许的生命周期内有效。把它们放进静态字段、普通线程池队列或延迟回调，原请求结束后再读取，结果未定义或失败。

需要异步处理时使用 Servlet async API，或在请求线程内复制最小不可变数据后提交独立后台任务。后台任务不能继续写已经完成的 response。

## 28. 同步请求的所有权

同步链中，容器进入 Filter/Servlet，应用返回后容器完成响应。应用拥有自己创建的临时流或资源，但不拥有 request/response 本体。Filter finally 是清理 request-scope 观测状态的可靠位置。

数据库连接等资源以后也必须在本次调用范围释放。不能期待容器 destroy 为每个请求收尾；destroy 只在组件整体退出时调用。

## 29. 为什么有 async

长轮询、异步 I/O 或需要等待其他结果时，同步占住容器线程可能浪费资源。`request.startAsync()` 把 response 完成点从当前 dispatch 返回之后延长，并得到 `AsyncContext`。

async 不是“方法自动变快”，也不保证底层操作非阻塞。错误的无限等待会换一种方式耗尽资源，所以仍需 timeout、完成和错误政策。

## 30. asyncSupported 是整条链约束

Servlet 与经过的 Filter 都要支持 async，request 才能进入异步模式。任一组件不支持时调用 startAsync 会抛 `IllegalStateException`。部署配置必须与代码预期一致。

Filter 包装了 request/response 时，还要决定异步操作使用原对象还是 wrapper。只在单元替身上通过不足以证明真实容器映射正确。

## 31. `AsyncContext.complete`

异步工作最终必须 `complete` 或 dispatch 回容器。complete 关闭该异步操作对应的响应并触发 listener 完成通知。重复 complete、在错误时序读写 request/response 会失败。

使用 `AsyncListener` 观察 complete、timeout、error 与新一轮 async。监听器用于收尾与证据，不把复杂业务塞进回调。

## 32. async timeout

`AsyncContext.setTimeout` 的计时从发起 async 的容器 dispatch 返回后生效；0 或负值表示无超时，不应作为安全默认。超时时容器通知 listener，并按规范尝试错误 dispatch/完成。

timeout 不代表后台业务一定停止。后台任务仍需取消或忽略迟到结果，写响应前检查生命周期；测试应证明 timeout 后没有第二次成功写入。

## 33. `dispatch` 与线程变化

`AsyncContext.dispatch` 把 request/response 重新交给容器线程执行，方法本身快速返回。新的 dispatch 类型为 ASYNC，路径与原始路径可通过标准 attributes 区分。

因此“同一请求始终同一线程名”是错误断言。应该断言业务相关 ID 和数据连续，而不是固定线程身份。

## 34. Servlet 对象不自动线程安全

容器管理生命周期不等于给实例字段加锁。HttpServlet 官方文档明确提醒多线程调用；Filter 实例也可能并发执行。线程安全来自状态设计、不可变对象和受控并发结构。

把 mutable collaborator 注入 Servlet 后同样要审查。一个线程安全 Servlet 调用非线程安全单例缓存，整体仍不安全。

## 35. ServletContext 与 session 也会共享

ServletContext attribute 跨整个 Web 应用共享，session attribute 跨同一会话多个请求共享，都需要并发与生命周期设计。它们不是“比实例字段更安全”的替代品。

本章不实现 session。需要保存业务状态时优先领域存储；不要把大型对象、请求对象或密码放入共享 attribute。

## 36. 阻塞 I/O 与容器容量

同步 Servlet 中的慢数据库或网络调用会占住当前请求执行线程。超时、连接池上限和容量规划仍必要。虚拟线程可能降低线程占用成本，但不会修复无限等待、共享状态或响应提交错误。

本章工件完全离线，不用 sleep 模拟吞吐结论。并发测试只用 latch 控制两个请求交错，证明状态隔离，不声称代表性能。

## 37. 异常如何离开链

Servlet/Filter 可抛 `ServletException` 或 `IOException`，运行时异常也可能被容器捕获并进入 error dispatch。Filter finally 仍应执行；若响应已经部分提交，容器可能无法替换成完整错误页面。

不要 catch 所有异常后返回 200 空 body。协议边界应把已知输入错误映射为明确 4xx，未知故障交给统一错误机制并保留 cause。

## 38. Filter finally 的证据

tracing Filter 在进入时写 `before:<id>`，调用链，finally 写 `after:<id>`。下游成功或失败都要留下成对事件。若 after 只在正常路径执行，故障时 ThreadLocal 或计时资源会泄漏。

事件列表在并发测试中按 request ID 分组，而不是依赖全局精确交错。只断言总行数无法发现 A 的 after 错配到 B。

## 39. correlation ID

边界可接受经过验证的外部 request ID，或生成内部 ID，放入 request attribute 与响应 header。它用于关联，不是认证凭据，也不能允许换行或无限长度。

日志记录 method、受限 path、dispatcher、状态与安全 ID；不记录完整 query、body、cookie 或认证头。线程名可辅助诊断，但不能成为请求身份。

## 40. 缺参数应早失败

示例要求 `equipmentId`。缺失或全空白时 Filter/Servlet 返回 400，固定 content type 和短错误 body，并且业务目标不执行。错误要可由客户端修复，不抛 NullPointerException 变成 500。

边界校验只处理结构要求；设备是否存在属于应用规则，留到后续服务层。不要在 Filter 中访问仓储。

## 41. 正常响应 oracle

固定 GET `/work-orders?equipmentId=EQ-7` 经过 tracing Filter，Servlet 返回 200、`Content-Type: text/plain;charset=UTF-8`、correlation header 和 `equipment=EQ-7`。事件顺序为 before、servlet、after。

oracle 不打印随机线程名或时间。线程证据用“两个任务使用隔离的 request 值且都完成”表达，从而跨机器可重放。

## 42. committed 后改状态故障

故障 Servlet 先写 200 body 并 flush，再尝试 setStatus(500)。第一处可信证据是 `isCommitted=true` 与最终状态仍为 200，而不是最后一行代码的意图。

修复为在写 body 前决定状态；若业务可能失败，就先完成必要计算再开始输出，或采用明确流式错误协议，不能假装回滚已经发送的字节。

## 43. Filter 漏调链故障

错误 Filter 记录 before 后直接返回，却没有设置拒绝响应。目标 Servlet 调用次数为 0，body 为空；这证明故障在链控制而非 Controller/业务。

修复根据分支选择：合法请求恰好调用一次 chain；拒绝请求明确构造 4xx。不要无条件在 finally 再调用 chain。

## 44. 请求对象跨线程故障

故障处理器把 request 保存到实例字段，第二个请求覆盖后第一个任务再读取，得到错误 equipmentId。确定性测试用 latch 排列覆盖顺序，不靠概率竞争。

修复是在进入异步前复制字符串值，或使用 `startAsync` 并遵守完成边界。即使测试替身仍可读取，生命周期设计也必须拒绝保存容器对象。

## 45. 并发请求隔离 oracle

同一个 Servlet 实例同时接收 EQ-A 与 EQ-B。每次调用把参数留在局部变量，并分别写入各自 response。两个响应必须精确对应，事件中的 correlation ID 不交叉。

这证明局部状态隔离，不证明所有协作者线程安全。下一步仍要审查共享 repository、cache 和 formatter。

## 46. async 状态 oracle

同步内存替身明确报告 asyncSupported=false 与 isAsyncStarted=false，调用未建模的 startAsync 会显式失败；测试不会伪装成一个完整容器。独立的 AsyncBoundary 先从 request 复制 requestId 与 equipmentId，再把这两个不可变值交给命名 worker，断言结果来自不同线程且没有保存 request 本体。

这组 oracle 证明“跨线程前复制所需值”和“线程身份会变化”，不证明 Servlet 异步已经启用。真实容器还需集成测试 startAsync、AsyncContext.complete、Filter 映射、listener 时序和 timeout error dispatch。

## 47. 测试替身的边界

工件使用动态代理实现 request/response 的最小方法集，并实际调用 Jakarta `Filter`、`FilterChain` 与 `HttpServlet`。未支持的方法会显式失败，防止测试悄悄返回错误默认值。

它比手写几十个空方法更聚焦，但不验证网络解析、容器 mapping、buffer 大小和部署描述符。生产前仍需一个真实 Servlet 6.1 兼容容器测试。

## 48. Maven 依赖边界

`jakarta.servlet-api:6.1.0` 在部署应用通常使用 `provided`，因为兼容容器提供实现；把 API JAR 打进应用可能造成类冲突。离线单元测试仍把它放入测试 classpath。

工件固定 JDK release 25、compiler/Surefire 插件和 JUnit 版本，verify 使用 Maven `-o`。先在线准备依赖，随后断网可重复并不等于生产容器通过。

## 49. FactoryCare 最小场景

请求查询某设备的工单摘要。Filter 只做 request ID 与必填参数结构检查，Servlet 把值转换成不可变 command 并返回协议结果。它不访问数据库、不做认证、不进入 Spring 容器。

这个切片只为观察生命周期。后续 Controller 会调用应用服务，但线程与 response 提交规则不会消失。

## 50. 预测练习

运行前预测：同一 Servlet 实例是否会并发？Filter 不调用 chain 会怎样？writer flush 后还能否可靠改 status？request parameter 与 attribute 谁可由客户端提供？startAsync 后是否保证原线程？两个 dispatch 是否可能重复经过 Filter？

每项先写布尔、状态或事件顺序，再运行资产。把错误预测改成一条生命周期规则，不只抄输出。

## 51. 独立构建任务

从空项目实现 required-parameter Filter、tracing Filter 与 `WorkOrderServlet`。记录 method、URI、dispatcher 和逻辑 request ID，返回明确 status/header/body；请求值只能放局部变量或 attribute。

至少写正常、缺参数、Filter 顺序、下游异常、已提交响应和两个并发请求测试。每个测试断言目标调用次数与最终响应。

## 52. 修改任务

把必填参数从一个改为 `equipmentId` 与 `limit`，其中 limit 必须是 1—100。保持 Filter 只做协议结构校验；把解析后的不可变值交给 Servlet，增加边界 1、100、0、101 和非数字测试。

再增加一个 ERROR dispatch 事件样本，说明哪些 Filter 应覆盖它。不要引入 Spring MVC 或 Security。

## 53. 诊断顺序

先记录 dispatcher type、Filter 进入/返回、目标调用次数、response status/committed/body，再定位参数读取、链控制、业务异常或提交时机。并发问题再加 request ID 与实例字段快照。

一次只改一个边界并复跑原故障。不要通过删除 flush、禁用并发或捕获所有异常让测试表面变绿。

## 54. 120 秒复述提纲

说明容器如何把 HTTP 变成 request/response，Servlet 的 init/service/destroy 为何与单请求不同，Filter 的 before/chain/after 顺序，以及 response committed 的含义。再说明同一 Servlet 实例并发导致什么风险。

最后讲一个 async 反例：普通线程池保存 request 并在请求结束后写 response，为什么错误，正确边界是什么。

## 55. 验收清单

- 能从 HTTP 报文映射到 request、response 与容器职责。
- Servlet 生命周期和单次请求生命周期不混淆。
- Filter 正常、阻断、异常三条链路可观察。
- status、header、body、encoding 与 committed 均有断言。
- 缺参数稳定返回 400，业务目标不执行。
- 同一实例并发请求不使用请求级实例字段。
- async 说明 timeout、complete/dispatch 与线程变化。
- Maven 完全离线复跑通过，故障案例确定。

## 56. 有意不做

本章不实现 Spring IoC、Spring MVC Controller、自动配置、Security Filter Chain、真实认证、JSON 转换、文件上传、数据库、session 集群或生产 Servlet 容器调优。也不把内存代理称为 TCK。

没有为旧 `javax.servlet` 包保留兼容层；基线使用 Jakarta Servlet 6.1 的 `jakarta.servlet`。迁移旧项目需要单独评估依赖、容器、源码 import 与回滚，不能混在本章工件中。

## 57. 一手资料

- [Jakarta Servlet 6.1 规范](https://jakarta.ee/specifications/servlet/6.1/)
- [HttpServlet API](https://jakarta.ee/specifications/servlet/6.1/apidocs/jakarta.servlet/jakarta/servlet/http/httpservlet)
- [Filter API](https://jakarta.ee/specifications/servlet/6.1/apidocs/jakarta.servlet/jakarta/servlet/filter)
- [AsyncContext API](https://jakarta.ee/specifications/servlet/6.1/apidocs/jakarta.servlet/jakarta/servlet/asynccontext)
- [ServletResponse API](https://jakarta.ee/specifications/servlet/6.1/apidocs/jakarta.servlet/jakarta/servlet/servletresponse)
- [Maven 3.9.16 Reference](https://maven.apache.org/ref/3.9.16/)
