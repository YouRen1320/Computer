# 示例：本地 TCP、UDP 与 HttpClient 边界观察台

这个示例把[《Socket、Datagram、URL/HttpClient 与超时》](../../../book/volume-03-java-engineering/chapters/ch.java-engineering.network-programming.md)中的三条网络路径放在同一个离线观察台里：

- TCP 使用 4 字节大端长度头和 UTF-8 负载，读取端先限制最大帧，再用 `readFully` 读完一帧；
- UDP 把一条消息放进一个数据报，接收端只按 `DatagramPacket.getLength()` 解码，保留包边界；
- HTTP 只访问进程内 `HttpServer`，同时观察 200、503 和请求超时，并用 Java 25 `HttpClient` 的 try-with-resources 关闭生命周期。

所有服务都绑定 `InetAddress.getLoopbackAddress()` 与端口 `0`。连接、读取、请求、latch、Future 和执行器终止都有明确上限；脚本不会查询公共 DNS、连接公网或使用固定服务端口。

## 运行

```bash
cd examples/encyclopedia/ch.java-engineering.network-programming
./verify.sh
```

需要 JDK 25，且不使用 preview。`jdk.httpserver` 是 JDK 自带模块，验证脚本会显式加入它。

## 先看契约，再看输出

1. `writeInt(bytes.length)` 写的是 UTF-8 字节数，不是 `String.length()`。
2. TCP 是字节流；一次 `read` 不承诺返回一整条消息，所以本例用长度头和 `readFully` 恢复应用帧。
3. UDP 的一次 `receive` 得到一个数据报；缓冲区过小会截断，不会像 TCP 那样继续读取“剩余半包”。
4. connect timeout 只限制建连；Socket 的 `setSoTimeout` 限制阻塞读取；HTTP 请求 timeout 限制整个请求等待。三者不能互相替代。
5. 503 是有效 HTTP 响应，不等于 Java 调用抛异常。调用方必须先读取状态码，再决定业务动作。

## 故障证据

验证器还会启动四个独立子 JVM，并要求它们以固定状态结束：

| 故障 | 退出码 | 第一处可信证据 |
| --- | ---: | --- |
| 已显式保持 unresolved 的离线地址 | 4 | `UnknownHostException`，没有发起 DNS 查询 |
| 本地监听端口关闭后连接 | 5 | `ConnectException` |
| 已连接的本地对端保持静默 | 6 | `SocketTimeoutException` |
| Socket 离开业务步骤时仍未关闭 | 7 | 先观察 `closed=false`，再由夹具主动关闭 |

成功末行是 `EXAMPLE PASS assertions=26 expected_failures=4`。输出不包含随机端口、时长或线程名，因此可以逐字节复验。

## 明确不做

- 不访问真实网站、公共 DNS、代理、云服务或 TLS 证书；
- 不实现生产协议服务器、重试框架、连接池、UDP 可靠传输或 TLS 信任配置；
- 不把本地毫秒级超时值当成生产 SLA；
- 不演示“信任所有证书”、无限等待或依赖垃圾回收关闭 Socket。
