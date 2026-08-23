# Servlet 请求生命周期：可运行示例

这个最小工程不启动端口，而是直接调用 Jakarta Servlet 6.1 的真实 Filter、FilterChain 与 HttpServlet.service 合同。内存请求/响应适配器只实现测试需要的方法，未实现的方法会立即失败，避免把测试替身误当成完整容器。

先预测五个测试的结果，再运行 ./verify.sh。

五个测试分别证明：

- Filter 进入顺序、Servlet 调用以及 Filter 逆序退出；
- 校验 Filter 能返回完整的 400，并且不再调用目标 Servlet；
- flushBuffer() 提交响应后，迟到的状态修改不会重写已经提交的响应；
- 忘记继续链会让请求静默停止；
- 把请求对象保存在共享字段中会被后续请求覆盖。

验证器固定要求 JDK 25、Maven 3.9.16，并用离线模式执行。Servlet API 使用 provided scope，因为真实部署时由 Servlet 容器提供。

## 证据边界

通过结果证明本工程建模的同步调用与提交规则；它没有启动真实容器、解析 TCP/HTTP 字节、执行 URL 映射或验证容器线程池。内存适配器不是 Servlet 容器替代品。
