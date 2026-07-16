# 实验：为本地网络调用建立帧、超时与资源所有权证据

本实验对应[《Socket、Datagram、URL/HttpClient 与超时》](../../../book/volume-03-java-engineering/chapters/ch.java-engineering.network-programming.md)。它不要求公网环境，而是把所有不确定性压进进程内可复验夹具：loopback 地址、系统分配端口、固定 UTF-8 消息、显式超时和有上限的执行器收尾。

## 目标

完成实验后，你应能从代码中指出：

1. TCP 的应用帧在哪里写入 4 字节大端长度头，为什么长度必须是 UTF-8 字节数；
2. `readFully` 如何跨多次短读恢复完整帧，截断输入为什么得到 `EOFException`；
3. 最大帧限制为什么必须发生在分配负载数组之前；
4. 两次 UDP `receive` 为什么得到两个独立包，而不是一段连续字节流；
5. connect timeout、Socket read timeout 与 `HttpRequest.timeout` 各自限制哪一个等待点；
6. 200 与 503 为什么都属于 HTTP 响应，以及 Socket、DatagramSocket、HttpClient、HttpServer 和执行器由谁关闭。

## 运行

```bash
cd labs/encyclopedia/ch.java-engineering.network-programming
./verify.sh
```

需要 JDK 25，不使用 preview。验证器用 `--add-modules jdk.httpserver` 编译和运行进程内 HTTP 服务。

## 先预测

1. 字符串 `维修单-84` 的 `length()` 与 UTF-8 字节数是否相同？帧头应该记录哪一个？
2. 底层输入每次最多返回 2 字节时，`DataInputStream.readFully` 能否仍读出 12 字节负载？
3. 帧头宣称 4 字节但流中只有 2 字节时，应该补零、等待无限久，还是抛出什么异常？
4. UDP 先后发送 1 字节和 6 字节负载，接收端会看到 7 字节流还是两个包？
5. 本地 HTTP 返回 503 时，`HttpClient.send` 会抛异常吗？
6. 客户端已连接但服务端不写任何字节时，connect timeout 还是 read timeout 生效？

## 验收证据

- 空帧、含中文 UTF-8 帧、2 字节短读、截断帧和超长帧均有确定输出；
- TCP 请求/响应采用同一长度前缀协议，并证明客户端、监听端和 worker 全部关闭；
- UDP 连续交换两个数据报，分别保留 1 与 6 字节包长；
- URI 明确使用 `http`、`/ok` 与系统分配端口；
- HttpClient 在 try-with-resources 中关闭，200、503 与请求超时分别处理；
- 四类网络边界故障和一类帧长故障由独立子 JVM 以退出码 4—8 重放；
- 成功末行是 `LAB PASS assertions=40 expected_failures=5`。

## 故障矩阵

| 故障夹具 | 退出码 | 可信证据 | 清理保证 |
| --- | ---: | --- | --- |
| `UnresolvedAddressFailure` | 4 | pre-connect guard 抛 `UnknownHostException` | 未调用 resolver 或 connect |
| `ConnectionRefusedFailure` | 5 | 已关闭的 loopback listener 导致 `ConnectException` | client 已关闭 |
| `ReadTimeoutFailure` | 6 | 已连接静默 peer 导致 `SocketTimeoutException` | latch 释放、双方关闭、executor 终止 |
| `SocketLeakFailure` | 7 | 业务边界观察到 `closed=false` | 夹具随后主动 close |
| `FrameLengthFailure` | 8 | 1,025 字节声明超过 1,024 上限 | 在数组分配前拒绝 |

## 修改练习

把最大帧改为 64 字节，并增加一个恰好 64 字节的成功边界与 65 字节的拒绝边界。修改前先预测输出；不要删除超长检查，也不要把读取改成单次 `read`。完成后用同一个验证器复验，并用 120 秒解释“传输层字节流”和“应用层消息”的区别。

## 明确不做

- 不访问公共 DNS、真实 API、代理、TLS 端点或固定服务端口；
- 不把毫秒级本地夹具参数复制成生产 SLA；
- 不实现重试、连接池、服务端框架、TLS 信任策略或 UDP 可靠传输；
- 不把 `shutdownNow`、垃圾回收或进程退出当作正常资源所有权模型。
