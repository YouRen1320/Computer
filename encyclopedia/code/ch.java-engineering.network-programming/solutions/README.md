# 私有解答：网络边界与可关闭客户端

本目录给评审者提供完整 oracle。`NetworkProgrammingSolution` 使用 4 字节大端长度前缀完成 UTF-8 TCP echo，以单个 UDP datagram 完成消息 echo，并用 Java 25 `HttpClient` 调用同进程、loopback、临时端口上的 `HttpServer`。

实现刻意保留以下边界：connect/read/request timeout 分开设置；HTTP 客户端固定直连且不读取系统代理；非 2xx 状态由调用方检查；所有 Socket、DatagramSocket、HttpClient、监听器、exchange 和执行器都有明确所有者；帧长度在分配前受上限保护。

~~~bash
cd solutions-private/encyclopedia/ch.java-engineering.network-programming
./verify.sh
~~~

验证器不访问公网、真实 DNS、凭据或固定服务端口。五个独立夹具分别注入 unresolved 预连接拒绝、连接拒绝、读超时、未关闭 Socket 观察点和超大帧长度；每个夹具在退出前都主动清理资源。
