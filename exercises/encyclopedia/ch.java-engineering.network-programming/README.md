# 练习：修复 UTF-8 TCP 帧长度

`src/NetworkProgrammingChallenge.java` 能在 loopback 上发送 TCP 帧，但起点错误地把 Java 字符数写入“字节长度”字段。ASCII 测试会掩盖问题，包含中文的负载会稳定暴露它。

请保持 4 字节大端长度前缀协议，完成以下修复：

1. 先用 UTF-8 编码，再写入 `payload.length`，不要写 `String.length()`；
2. 在分配数组前拒绝负长度和超过 `MAX_FRAME_BYTES` 的长度；
3. 用 `readFully` 读取完整帧，不假设一次 `read` 就能读完；
4. 保留 connect/read timeout、loopback、端口 0 和 try-with-resources 所有权边界。

~~~bash
cd exercises/encyclopedia/ch.java-engineering.network-programming
./verify.sh
~~~

起点以 `mode=starter` 通过，证明 UTF-8 长度错误被 oracle 捕获。完成后同一验证器应输出 `COMPLETED CHALLENGE PASS assertions=10`。四个独立故障夹具还会验证未解析地址、连接拒绝、读超时与 Socket 泄漏分类；它们都只使用离线数据或本机 loopback。
