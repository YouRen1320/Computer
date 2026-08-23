# singleton 获取 prototype：私有参考答案

参考实现保持 `TicketIssuer` 为 singleton、`PrototypeTicket` 为 prototype，但把依赖从“一个已经创建的 ticket”改为 `ObjectProvider<PrototypeTicket>`。`issue()` 在每次业务调用时执行 `getObject()`，因此每次都跨过容器查找边界并创建新实例。

运行：

```bash
./verify.sh
```

验收输出应为 3 个测试全部通过，并显示 `SOLUTION PASS`。验证器使用 JDK 25、Maven 3.9.16、Spring Framework 7.0.8，且 Maven 只以离线模式运行。

这个答案只解决“长生命周期对象如何逐次取得短生命周期对象”。它没有替 prototype 自动关闭资源；若 prototype 持有资源，调用方仍需明确负责释放。
