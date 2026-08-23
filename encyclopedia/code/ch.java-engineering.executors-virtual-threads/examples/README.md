# 示例：Future 四种结果与虚拟线程身份

本示例使用 Java 25 标准库演示成功值、`ExecutionException` 的原始 cause、带上限的 `Future.get`、协作式取消、执行器终止，以及 `newVirtualThreadPerTaskExecutor()` 中的线程身份。任务只访问内存中的合成 FactoryCare 工单，不联网、不依赖真实服务。

```bash
examples/encyclopedia/ch.java-engineering.executors-virtual-threads/verify.sh
```

输出次序由主线程收集结果决定；worker 不直接打印。等待任务由 `CountDownLatch` 固定在未完成状态，因此 timeout 不依赖“机器恰好慢”；所有等待都有 2 秒安全上限。脚本使用临时构建目录并在退出时删除。

通过只能证明这些固定输入在当前 JDK 25 上符合 oracle。它不证明生产线程池容量合理、不证明外部 I/O 一定可中断，也不证明虚拟线程会让 CPU 密集任务更快。
