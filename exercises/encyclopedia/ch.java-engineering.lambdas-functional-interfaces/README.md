# Lambda 行为合同独立练习

不要先追求最短语法。先在纸上写出 `Predicate<WorkOrder>.test`、`Function<WorkOrder,String>.apply` 和 `Consumer<WorkOrder>.accept` 的完整签名，再完成源码中的 TODO。

任务：

1. 实现“开放且优先级至少达到阈值”的 Predicate，并拒绝非法阈值；
2. 实现 `P{priority}:{id}` 标签 Function；
3. 实现恰好写入一次 `notify:{id}` 的 Consumer；
4. 用同一输入表证明标签 Lambda 与静态方法引用等价；
5. 运行隐藏副作用夹具，解释为什么线程安全集合不是正确修复。

```bash
./verify.sh
```

starter 应以 `BEHAVIOR_CONTRACT` 失败。修复后，把输出、你制造的一次故障和 120 秒讲回提纲作为学习证据。
