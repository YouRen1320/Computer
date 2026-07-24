---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.network-programming
title: Socket、Datagram、URL/HttpClient 与超时
responsibility: 把网络分层落实为 Java 客户端与套接字边界，不在本章实现应用协议服务器或重试框架
volume: '03'
order: 16
level: L2
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.network-programming.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.http-curl
- ch.java-engineering.io-resource-lifecycle
version_surfaces:
- jdk-25
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释Socket、Datagram、URL/HttpClient 与超时的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-socket-datagram
  - java-http-client
  covers_topics:
  - java.tcp-socket
  - java.udp-datagram
  - java.network-resource-owner
  - java.uri-url
  - java.http-client
  - java.connect-read-timeout
  uses_capabilities:
  - foundation.network-transport
  - foundation.http-message
  - java.exceptions-resources
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现带 connect/read timeout 的 HttpClient 请求和本地 TCP echo 客户端，明确 URI、编码与资源关闭
  covers_topic_groups:
  - java-socket-datagram
  - java-http-client
  covers_topics:
  - java.tcp-socket
  - java.udp-datagram
  - java.network-resource-owner
  - java.uri-url
  - java.http-client
  - java.connect-read-timeout
  uses_capabilities:
  - foundation.network-transport
  - foundation.http-message
  - java.exceptions-resources
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入 DNS 错、连接拒绝、读超时和未关闭 Socket，按网络层与异常类型分别处理
  covers_topic_groups:
  - java-socket-datagram
  - java-http-client
  covers_topics:
  - java.tcp-socket
  - java.udp-datagram
  - java.network-resource-owner
  - java.uri-url
  - java.http-client
  - java.connect-read-timeout
  uses_capabilities:
  - foundation.network-transport
  - foundation.http-message
  - java.exceptions-resources
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Socket、Datagram、URL/HttpClient 与超时

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《HTTP 报文、方法、状态码、Header、Body 与 curl》](../../volume-00-computer-foundations/chapters/ch.foundations.http-curl.md)：独立完成Socket 与 Datagram、URL 与 HttpClient前，必须先具备「HTTP 报文、方法、状态码、Header、Body 与 curl」已经验证的知识与失败边界
- [《字节流、字符流、资源所有权与 try-with-resources》](ch.java-engineering.io-resource-lifecycle.md)：独立完成Socket 与 Datagram、URL 与 HttpClient前，必须先具备「字节流、字符流、资源所有权与 try-with-resources」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文和工件是作者级学习材料与可重复验证，不自动改动 `PROGRESS.md`，也不代表学习者已经独立通过阶段门。

网络调用不是“把 URL 交给库就结束”。客户端要把名称解析成地址，选择端口和传输协议，建立连接，定义消息边界，设置超时，完整读取响应，并在成功或失败时释放资源。任何一层都可能独立失败：名称无法解析、端口拒绝、连接建立后对端不发数据、UDP 报文截断、HTTP 返回非 2xx，或 TLS 身份验证不通过。

本章把这些边界落实到 Java 25 的 `InetAddress`、`Socket`、`ServerSocket`、`DatagramSocket`、`URI` 和 `HttpClient`。工件只绑定 loopback 地址与操作系统分配的临时端口，不访问公网、不读取代理配置、不使用真实域名、凭据或危险端口。测试内的小型 echo/HTTP 服务仅是确定性 oracle，不是生产应用协议服务器。Java 25 官方 API 复核日期为 **2026-07-17**。

## 1. 本章完成证据

完成证据包括：120 秒内解释端点、DNS、TCP/UDP、framing、connect/read/request timeout 与 TLS 信任边界；实现 loopback TCP/UDP echo 和本地 HttpClient 请求，内容、状态与资源关闭都有断言；注入未解析地址、连接拒绝、读超时和未关闭 Socket，能在时间上限内按异常类型分类。

配套工件：

- [Socket、UDP 与本地 HTTP 观察台](../../../examples/encyclopedia/ch.java-engineering.network-programming/README.md)
- [framing、超时与资源所有权实验](../../../labs/encyclopedia/ch.java-engineering.network-programming/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.network-programming/README.md)

## 2. 从分层模型到 Java API

应用层决定 HTTP 或自定义消息语义，传输层决定 TCP/UDP，网络层负责 IP 寻址，链路层负责本地传输。Java API 隐藏许多细节，但异常仍来自不同层。把所有 `IOException` 都叫“网络坏了”会丢掉修复方向。

`HttpClient` 处理 HTTP 报文和连接管理；`Socket` 暴露 TCP 字节流；`DatagramSocket` 暴露 UDP 报文。不要用 TCP API 自己拼 HTTP，除非目标就是学习协议或实现经审查的底层库。

## 3. 端点由地址和端口组成

IP 地址标识主机或接口范围，端口标识该主机上的传输端点。`InetSocketAddress` 把两者组合。相同数字端口在 TCP 与 UDP 中属于不同协议空间，也不代表同一服务。

客户端不能只记录“连接 8080 失败”，还需要安全地记录逻辑主机、协议、阶段和超时类别。不要记录 URI 中的密码、token 或敏感 query。

## 4. 主机名不是 IP 地址

`factorycare.local` 是名称，`127.0.0.1` 和 `::1` 是地址表示。名称可能解析成多个 IPv4/IPv6 地址，结果顺序、缓存和可用性随环境变化。业务配置应保留原始逻辑主机，同时把实际远端地址作为诊断证据。

不要用字符串是否含点来判断 IP。需要地址对象时使用 `InetAddress` 或 `InetSocketAddress`，并明确解析发生在哪个边界。

## 5. DNS 解析

`InetAddress.getByName(name)` 可能查询系统解析器并抛 `UnknownHostException`。解析成功只证明获得地址，不证明目标端口可连接；连接成功也不证明 HTTP 状态成功。

DNS 缓存和 hosts 配置会影响结果，因此离线测试不查询真实域名。本章先创建 unresolved 地址，再由显式的 pre-connect guard 注入 `UnknownHostException` 分类分支；这不声称真实解析器已经失败或通过。

## 6. loopback 是测试边界

`InetAddress.getLoopbackAddress()` 返回本机 loopback，可能是 IPv4 `127.0.0.1` 或 IPv6 `::1`。服务端和客户端都使用同一个返回对象，避免硬编码地址族不一致。

loopback 流量不会验证路由器、防火墙、企业 DNS、代理或远端 TLS，但能稳定验证 Java API、framing、超时和关闭逻辑。局部通过不能外推为公网可用。

## 7. IPv4 与 IPv6

地址字符串和长度不同，IPv6 URI 字面量需要方括号。代码不应假设 `getHostAddress()` 总含三个点，也不应把 `localhost` 必然当 IPv4。

测试以 `InetAddress.isLoopbackAddress()` 断言边界，不对具体文本做唯一假设。生产监听 wildcard 地址会扩大暴露面，本章服务显式绑定 loopback。

## 8. resolved 与 unresolved 地址

`new InetSocketAddress(host,port)` 可能解析；`InetSocketAddress.createUnresolved` 只保存名称和端口。`isUnresolved()` 让上层看见尚未得到 IP 的状态。后续 Socket 连接可能再调用解析器，所以 unresolved 不是一个跨环境必然失败的连接 oracle。

配置解析层可以先保持 URI/名称，连接边界再解析；若安全政策禁止未解析端点，就在 connect 前显式拒绝。错误分类必须保留主机名和阶段，既不要把 unresolved 当作“稍后一定成功”，也不要假定 Socket 一定原样拒绝它。

## 9. 端口范围与端口 0

有效远端端口通常是 1—65535；端口 0 不能作为普通目标服务端口。测试服务绑定端口 0 表示让操作系统分配临时可用端口，随后从 `getLocalPort()` 读取真实端口给客户端。

不要在测试硬编码 8080、3306 等常用端口，也不要扫描端口。系统分配能减少冲突，服务停止后端口仍不应被长期缓存。

## 10. `ServerSocket` 只做测试支架

ServerSocket 绑定 loopback 后 `accept()` 返回一个已连接 Socket。监听 Socket 和每个连接 Socket 都是独立资源，都需要关闭。关闭监听端不会自动替你管理所有已接受连接。

本章服务线程只接受固定数量连接、处理固定小消息并在上限内结束。它没有认证、限流、并发治理或优雅停机，不是可部署应用服务器。

## 11. TCP 是有序字节流

TCP 提供有序、可靠的双向字节流，但不保留应用消息边界。一次 `write` 不保证对应对端一次 `read`，一次 `read` 也可能只返回部分消息。把“一个 read 就是一条请求”当协议会在负载和分片下失败。

InputStream 返回正数表示实际字节数，-1 表示对端关闭发送方向。循环必须按实际 count 处理，并设置总长度上限。

## 12. 连接超时

`Socket.connect(endpoint, timeoutMillis)` 的 timeout 限制建立连接阶段。使用 `new Socket(host,port)` 便捷构造器时很难先设置清晰 connect timeout，因此更可控的流程是先创建未连接 Socket，再 connect。

连接超时为 0 表示无限等待，不适合作为安全默认。具体超时值由 SLO、网络环境和调用预算决定，不复制一个数字到所有服务。

## 13. 读取超时

`socket.setSoTimeout(ms)` 限制关联 InputStream 的阻塞 read；到期抛 `SocketTimeoutException`，Socket 仍可能有效。它不是 connect timeout，也不是整个业务调用总时限。

必须在进入阻塞读取前设置。成功读到一个字节会重新进入下一次读取，因此多段协议还需要总 deadline，防止对端慢慢发送永不完成。

## 14. 写入超时不是同一选项

经典 Socket API 没有与 `setSoTimeout` 对称的通用写超时。写小数据在 loopback 常很快，但对端不读和缓冲耗尽时仍可能阻塞。高风险系统使用通道、异步 API、任务 deadline 或关闭 Socket 来中断。

不要把 `SO_TIMEOUT` 宣称同时保护 read/write。错误文档会让调用线程在写路径无限等待。

## 15. 资源所有权

创建 Socket 的客户端边界拥有它，并用 try-with-resources 关闭。`getInputStream()` 和 `getOutputStream()` 与 Socket 关联；关闭返回流会关闭关联 Socket，因此不要让多个层争夺关闭权。

高层方法若只借用 Socket，应明确不关闭；更常见的客户端方法内部创建并关闭，返回完整结果而不是泄漏流到外层。

## 16. 关闭与异常

连接、写入、读取任一阶段失败都必须关闭 Socket。TWR 保留主体异常为主异常，把关闭失败加入 suppressed。catch 后返回空字符串会把读超时伪装成合法空响应。

关闭只能释放资源，不能把部分响应恢复成完整响应。协议层必须拒绝短帧和超长帧。

## 17. 半关闭

`shutdownOutput()` 表示本端不再发送但仍可读取；`shutdownInput()` 表示不再接收。某些请求/响应协议用输出 EOF 标识请求结束，但它不是普遍消息边界。

半关闭后 Socket 本身仍需 close。不要在不了解协议时调用 shutdownOutput 期待“flush”。

## 18. 为什么需要 framing

TCP 没有消息边界，应用协议必须定义。常见方案包括固定长度、分隔符、长度前缀、EOF 或更完整的 HTTP framing。选择取决于内容能否含分隔符、是否流式和最大大小。

本章用四字节大端长度前缀 + UTF-8 payload。它足以展示边界，但不含版本、校验、认证和多路复用。

## 19. 长度前缀协议

发送方先把 UTF-8 字节长度写成 int，再写 payload 并 flush。接收方先读 int，检查 `0 <= length <= MAX_FRAME_BYTES`，再精确读取 length 字节。

长度是字节数，不是 String.length。中文与 emoji 的 UTF-8 字节数大于 UTF-16 code unit 数；写字符数会造成短读或粘入下一帧。

## 20. `readFully` 与短帧

`DataInputStream.readFully` 会持续读取直到填满或遇到 EOF，并以 EOFException 报短帧。自己写循环也必须累计 offset，不能假设一次 read 填满。

短帧是协议错误，不应返回部分字符串。故障夹具声明长度 4 只发送 2 字节，再结束输入，稳定得到 EOF 证据。

## 21. 长度上限

在分配 byte[] 前检查长度。攻击者可声明 2 GB 而不发送内容，若先分配会造成内存耗尽。负数也必须拒绝。

上限是协议的一部分，客户端与服务端需要一致。错误报告只含实际长度和最大值，不回显巨大 payload。

## 22. 文本编码

framing 处理字节边界，Charset 处理字节与字符映射。两者不能互相替代。协议明确 UTF-8，编码和解码都写 `StandardCharsets.UTF_8`。

二进制协议不经过 String。若 payload 是 JSON，JSON 结构验证属于更高层；本章只验证字节长度和往返一致。

## 23. 缓冲与 flush

DataOutputStream 可包在 BufferedOutputStream 上；写完一帧后 flush 让下层尽快看到数据。flush 不关闭连接，也不保证物理网络已送达或对端处理成功。

每写一个字段都 flush 会增加系统调用。以完整协议帧作为 flush 边界更合理。

## 24. 服务端并发与线程

一个阻塞 accept/read 会占用线程。本章测试服务只处理一次并由有界线程结束。生产服务需并发上限、拒绝策略、超时、观测和停机协议。

虚拟线程可降低阻塞线程成本，却不会自动提供 framing、超时或资源关闭。不要用并发机制掩盖协议错误。

## 25. 连接拒绝

目标地址可达但没有 TCP 监听者时通常得到 `ConnectException: Connection refused`。这与 DNS 失败不同：名称/地址已确定，失败发生在连接阶段。

离线夹具先让 loopback ServerSocket 获取临时端口再关闭，随后立即连接并期望 ConnectException。它验证本机 TCP 栈，不使用公网端口。

## 26. 读取超时故障

静默服务接受连接但在固定窗口内不发送字节。客户端连接成功，设置短 SO_TIMEOUT 后 read 抛 SocketTimeoutException。这个证据区分“端口开放”和“协议及时响应”。

服务线程最终关闭已接受连接，并受总等待上限保护。测试不依赖当前时间的输出，只断言在外层上限内完成。

## 27. 未关闭 Socket 故障

错误客户端连接并返回而不 close，`socket.isClosed()` 为 false。夹具在记录泄漏证据后主动关闭，避免测试自己真的留下句柄。

修复不是只在成功末尾 close；连接后任何 write/read 异常都会跳过。把创建 Socket 的整个作用域放进 TWR。

## 28. UDP 是报文协议

UDP 通过 DatagramPacket 保留单个报文边界，一次 send 对应一个报文；receive 每次取得一个报文。它不建立可靠字节流，不保证到达、顺序或唯一性。

loopback 成功只能证明本次报文往返。生产协议仍需序号、去重、超时和重传政策，或选择 TCP/QUIC 等更合适传输。

## 29. DatagramPacket 长度

接收 packet 使用调用者提供的缓冲。若报文大于缓冲，超出部分被截断；packet.getLength() 是本次有效长度。解码必须使用 offset/length，不能把整个旧缓冲变成字符串。

复用 DatagramPacket 前要重置长度，否则上一次短报文可能限制下一次接收容量。资产使用独立小报文避免隐含状态。

## 30. UDP 的“连接”

`DatagramSocket.connect` 主要固定默认远端并过滤其他来源，不执行 TCP 式握手。调用成功不证明远端进程存在。对不可达端口是否抛 PortUnreachableException 没有保证。

因此确定性测试不把“UDP 连接拒绝”当 oracle，而用 receive SO_TIMEOUT 证明无报文到达。

## 31. UDP 超时

`DatagramSocket.setSoTimeout` 限制 receive 阻塞，到期抛 SocketTimeoutException，Socket 仍可继续使用。发送通常只是把报文交给本机协议栈，不代表对端收到。

超时后是否重试、重试次数和幂等由应用协议决定。本章不实现重试框架。

## 32. UDP 资源关闭

DatagramSocket 实现 Closeable，应由创建者 TWR 管理。关闭能让阻塞 receive 失败返回，但异常类型可能依实现和线程模式，不把具体消息作为跨平台契约。

DatagramPacket 只是内存对象，不需要 close；它引用的 byte[] 仍由应用管理。

## 33. URI 与 URL

URI 是资源标识的语法结构，创建和解析本身不发网络请求。URL 结合 scheme handler，传统 `openConnection/openStream` 可能触发 I/O。现代 HTTP 客户端通常以 URI 构建 HttpRequest。

不要通过字符串拼接 query。对每个组件编码并明确允许的 scheme、host 和 port；`URI.create` 对非法语法抛 IllegalArgumentException，外部输入可用受检构造器或显式转换失败。

## 34. URI 不等于授权

语法合法的 URI 仍可能指向 loopback、链路本地、云元数据、内网管理端或 file scheme。接收外部 URL 的服务必须防 SSRF：scheme allowlist、解析后地址政策、重定向复查和网络出口隔离。

本章客户端 URI 由测试代码构造为 loopback，不接受用户输入。不要把“只允许 https 字符串前缀”当完整安全策略。

## 35. HttpClient 生命周期

Java 25 的 HttpClient 实现 AutoCloseable；close 会发起有序关闭并等待已提交操作结束。可复用客户端通常由应用级组件拥有，而不是每个请求新建；短生命周期教学资产用 TWR 清晰释放资源。

流式 BodyHandler 返回的 InputStream 等资源还需读取完或关闭。只关闭 client 不能替代消费响应体契约。

## 36. 构建 HttpRequest

请求至少包含 URI、方法和可选 body/header。Builder 可复用配置思路但不是线程安全共享对象；每次 build 得到独立请求。GET 是默认方法，写操作应显式 POST/PUT 与 BodyPublisher。

请求头值来自外部时要防 CRLF 和敏感信息泄露。HttpClient 会限制部分受控头，不应尝试伪造 Host 或 Content-Length。

## 37. 读取 HttpResponse

`client.send(request, BodyHandler)` 返回状态码、headers、body、最终 URI 和版本。HTTP 404/500 通常不是 Java 异常，而是正常响应状态；调用者必须按契约判断。

只返回 body 会丢状态和诊断。结果类型至少保留 status、必要 header 和受限 body 摘要。

## 38. BodyHandler 与内存边界

`BodyHandlers.ofString(UTF_8)` 适合已知很小的教学响应，会把 body 放内存。大响应使用文件、InputStream 或自定义 subscriber，并设置字节上限和关闭策略。

Content-Length 可缺失或不可信，不能只靠 header 防大响应。读取流时仍需实际计数。

## 39. HTTP 状态与 body

状态分类提供第一层语义：2xx 成功、3xx 重定向、4xx 客户端请求问题、5xx 服务端失败，但具体 API 可定义更窄集合。错误 body 也要限制长度和脱敏。

资产本地 `/unavailable` 固定返回 503 与短 ASCII body，证明 send 成功不等于业务成功；正常 `/ok` 返回短 UTF-8 body 与明确 200。

## 40. Client connect timeout

`HttpClient.Builder.connectTimeout(Duration)` 设置新连接建立超时，`client.connectTimeout()` 返回 Optional。连接池复用已有连接时，不一定再次发生连接阶段，因此它不是每请求总 deadline。

DNS 解析耗时和系统行为也可能不完全由此参数覆盖。外层调用预算仍需覆盖解析、排队、连接、响应与消费。

## 41. Request timeout

`HttpRequest.Builder.timeout(Duration)` 设置等待响应的请求超时；未设置等同无限等待。到期时同步 send 抛 HttpTimeoutException，异步请求异常完成。

它与 Socket SO_TIMEOUT 语义不同，不能把毫秒值机械映射。资产的 `/slow` 在本地延迟，客户端以短 request timeout 得到确定异常。

## 42. 超时不是重试

超时只终止等待或报告预算耗尽，不说明服务端是否执行过请求。对 POST 自动重试可能重复创建工单或执行维修动作。重试需要幂等键、方法语义、退避和总预算。

本章不实现重试框架；故障一次失败并保留分类，不在 catch 中悄悄再发请求。

## 43. 重定向

HttpClient 默认重定向政策需显式查看；Builder 可选 NEVER、NORMAL、ALWAYS。重定向可能改变主机和 scheme，也可能把凭据带到新目标。

安全客户端对每个 Location 重新执行目标策略，并限制次数。本章本地服务不返回重定向，避免把它与核心超时混在一起。

## 44. 同步与异步

`send` 阻塞当前线程直到响应或失败；`sendAsync` 返回 CompletableFuture。异步不会自动增加超时、取消、body 上限或资源管理，异常通常包在 CompletionException 中。

正常 HTTP 路径用同步调用保持故障链直观；超时观察台只为协调本地慢处理器而使用 `sendAsync`，并显式检查 Future 的 cause、超时和收尾。需要业务并发时仍要另行设计取消协议。

## 45. 代理与环境差异

HttpClient 可配置 ProxySelector。系统代理、PAC 和企业网络会改变真实路由，因此离线资产同时使用 loopback URI 和只返回 `Proxy.NO_PROXY` 的 selector，不读取外部代理配置或凭据，也不声称验证了企业代理。

诊断报告要区分目标逻辑 URI 与实际代理连接，但不能打印代理账号密码。

## 46. TLS 位于 HTTP 之下

HTTPS 在 TCP 上先进行 TLS 握手，协商版本/密码套件并验证证书和主机身份，再传 HTTP。TCP connect 成功不代表 TLS 成功，TLS 成功也不代表 HTTP 2xx。

常见失败包括证书过期、链不受信、主机名不匹配、协议/算法不兼容。它们不应被笼统转换成 read timeout。

## 47. 信任与主机名验证

信任管理器验证证书链是否由可信根建立，端点识别验证证书身份是否匹配请求主机。两者缺一不可。使用 IP 访问只含 DNS 名称的证书常会主机名不匹配。

不要在生产创建“信任所有证书”的 TrustManager 或关闭 hostname verification。那会把加密通道变成可被中间人冒充的通道。

## 48. SSLContext 边界

HttpClient 可配置 SSLContext 和 SSLParameters，但密钥库、信任库与客户端证书属于部署安全配置。代码不硬编码私钥、密码或真实证书路径。

本章不启动自签名 TLS 服务，因为那会把证书生成和信任配置混入网络基础 oracle。TLS 行为以官方 JSSE 契约解释，需在部署环境另做集成验证。

## 49. 安全目标限制

真实网络客户端应限制 scheme、host、解析后 IP、端口、重定向和响应大小，并使用最小出站权限。DNS rebinding 说明“第一次解析安全”不等于连接时仍安全；关键系统需要连接层地址校验与网络隔离。

本章资产完全不接受外部 URI，只使用由 ServerSocket/HttpServer 暴露的 loopback 临时端口。

## 50. 本地 HttpServer oracle

JDK `jdk.httpserver` 模块提供轻量测试 HTTP 服务。处理器固定返回 200/503 或延迟，绑定 loopback:0，验证结束 stop。它仅作为测试替身，不展示生产 HTTP 服务器设计。

验证器编译运行时显式加入 `--add-modules jdk.httpserver`，使模块依赖可见而不安装第三方库。

## 51. 故障分类表

UnknownHostException 指向名称/未解析地址；ConnectException 指向 TCP 连接拒绝等连接失败；SocketTimeoutException 指向 Socket 阻塞操作超时；HttpTimeoutException 指向 HttpClient 请求预算；SSLHandshakeException 指向 TLS 握手。

异常层次只提供起点，仍需记录阶段、目标逻辑 ID、超时配置和 cause。不要依赖操作系统本地化 message 做程序分支。

## 52. 离线 DNS 故障替身

资产使用 `InetSocketAddress.createUnresolved("offline.invalid", port)`，先证明 unresolved 状态，再由 pre-connect guard 主动抛出并分类 `UnknownHostException`；guard 不调用 resolver 或 connect。`.invalid` 只是逻辑标签。

这是注入的错误处理分支，不是“Socket 遇到 unresolved 必然抛该异常”，更不是“DNS 服务器测试通过”。真实 resolver、缓存、搜索域和多地址回退列为未验证。

## 53. 三种网络故障上限

未解析地址不进入网络；连接拒绝只访问 loopback；读超时由 loopback 静默服务制造。每个夹具有固定退出码和 ASCII 诊断，外层验证器还有总进程上限思想，避免测试永久挂起。

未关闭 Socket 是第四种资源故障：先证明 `closed=false`，再主动清理。网络错误和资源错误分别取证。

## 54. FactoryCare 场景

FactoryCare 可向本地设备网关发长度前缀 TCP 查询，或通过 HTTPS 调用受信后端。端点来自受控配置，connect/request timeout 与总预算明确，结果类型保留状态和失败类别。

本章不实现真实设备协议、认证、重试、熔断或服务发现，也不把 loopback echo 当设备兼容性证明。

## 55. 正常 oracle

TCP echo 使用包含中文的 UTF-8 payload，长度前缀按字节写，返回完全一致；UDP echo 断言 packet length 和内容；HTTP `/ok` 断言状态 200、body 与 URI host 是 loopback。

服务线程均有固定连接/报文次数并在 finally 关闭。输出不打印随机临时端口，只报告布尔和计数，确保可重放。

## 56. 预测练习

运行前预测：TCP 一次 write 是否对应一次 read；端口 0 的含义；SO_TIMEOUT 是否限制 connect/write；UDP connect 是否握手；HTTP 503 是否让 send 抛异常；URI.create 是否发网络；关闭 Socket 的 OutputStream 会怎样；TLS connect 与 HTTP 状态先后关系。

为每项写 expected 类型或布尔，再运行工件。错题改写为一条分层规则。

## 57. 独立构建任务

从空文件实现 `sendFrame/readFrame`、loopback TCP echo 客户端和带 connect/request timeout 的 HttpClient 请求。所有地址由测试支架提供，不允许硬编码公网 host 或固定端口。

加入中文、空 payload、超长长度、短帧、503 和慢响应用例。每条失败都有 expected/actual、异常类型和关闭证据。

## 58. 修改任务

把实验的最大 frame 上限改为 64 字节，增加恰好 64 字节的成功样本与 65 字节的拒绝样本；不能改成字符数。再把 HTTP body 上限加入结果读取，证明超过上限时请求失败且流关闭。

添加一个 UDP 两报文测试，证明两次 receive 保留边界。不要把两报文拼成 TCP 式流。

## 59. 诊断顺序

先判断阶段：URI 解析、名称解析、connect、TLS、write、read、HTTP 状态还是 body 消费。再看异常具体类型、cause、超时配置和资源 closed 状态。

一次只修一个层，复跑正常路径和边界。不要通过删超时、改公网地址或 catch IOException 返回空值让测试“变绿”。

## 60. 120 秒复述提纲

不看正文说明：主机名、地址、端口是什么？TCP/UDP 区别？TCP 为何需要 framing？connect、SO_TIMEOUT、HttpRequest timeout 各保护哪段？Socket 与流谁关闭？HTTP 非 2xx 为何通常不是异常？TLS 验证哪两类身份？

最后讲连接成功但读超时的失败链，指出它排除了什么、仍未证明什么。

## 61. 验收清单

- 所有服务只绑定 `InetAddress.getLoopbackAddress()` 和系统临时端口。
- TCP framing 按 UTF-8 字节长度，短帧与超长帧明确失败。
- UDP 使用 packet offset/length，并认识到丢失、乱序与重复不受保证。
- Socket connect/read 和 HttpClient connect/request timeout 不混淆。
- TCP、UDP、HttpClient 与流式 body 的所有权清楚。
- pre-connect UnknownHost 注入、Connect、SocketTimeout、HttpTimeout 分类稳定，不依赖本地化消息。
- TLS 不关闭证书链或主机名验证，不使用真实密钥。
- 无公网、真实 DNS、固定服务端口、凭据或端口扫描。

## 62. 有意不做

本章不实现生产应用协议服务器、WebSocket、QUIC、HTTP/2 帧、服务发现、代理认证、重试/熔断、真实设备协议或 TLS 证书部署。loopback 资产不验证防火墙、企业 DNS、NAT 和公网延迟。

没有以删除超时、信任所有证书或自动重试保留错误兼容性。需要降级时必须单独定义幂等、预算、安全影响、迁移与回滚。

## 63. 一手资料

- [Socket，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/net/Socket.html)
- [DatagramSocket，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/net/DatagramSocket.html)
- [InetAddress，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/net/InetAddress.html)
- [URI，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/net/URI.html)
- [HttpClient，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.net.http/java/net/http/HttpClient.html)
- [HttpRequest.Builder timeout，Java SE 25 API](https://docs.oracle.com/en/java/javase/25/docs/api/java.net.http/java/net/http/HttpRequest.Builder.html)
- [JSSE 参考指南，Java 25](https://docs.oracle.com/en/java/javase/25/security/java-secure-socket-extension-jsse-reference-guide.html)
