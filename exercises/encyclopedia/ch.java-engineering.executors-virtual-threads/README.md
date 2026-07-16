# 练习：修复 Future 结果协议

公开 starter 会编译，但故意把 `ExecutionException` 的 cause 丢成 `UNKNOWN`。验证脚本把这个红灯视为预期 fixture：

```bash
exercises/encyclopedia/ch.java-engineering.executors-virtual-threads/verify.sh
```

先保存预测，然后独立完成：

1. 保留真实 cause 的类型和消息，不把失败伪装成普通结果；
2. 加入一个被 latch 阻塞的查询，用带上限 `get` 观察 timeout；
3. timeout 后请求 `cancel(true)`，让任务恢复中断状态并退出；
4. 证明取消后的 `get` 抛 `CancellationException`；
5. 关闭执行器并证明 `isTerminated()`，关闭后提交必须被拒绝；
6. 记录任务是否运行在虚拟线程，但不要据此删除共享状态保护；
7. 不看私有解，注入一次“吞中断”并在 2 秒内安全释放。

完成版不应依赖联网、真实数据库、裸 `Future.get()`、随机 sleep 或后台遗留线程。提交 expected / actual、退出码、故障修复复跑和 120 秒口述。
