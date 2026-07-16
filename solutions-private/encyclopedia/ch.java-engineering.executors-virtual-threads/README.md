# 私有解析：Future 结果协议

先完成公开练习并保存红绿证据，再阅读本目录。

参考解保留 `ExecutionException.getCause()`，所有 `get` 都有上限，timeout 后协作取消，取消结果由 `CancellationException` 证明，执行器通过 try-with-resources 等待终止；同时记录虚拟线程身份而不把它当线程安全证明。

```bash
solutions-private/encyclopedia/ch.java-engineering.executors-virtual-threads/verify.sh
```

这只是一个答案，不是唯一实现。生产实现还要按 SLA 分配总 deadline、限制数据库连接等稀缺资源、保存取消原因和观测指标，并验证具体驱动是否响应中断。
