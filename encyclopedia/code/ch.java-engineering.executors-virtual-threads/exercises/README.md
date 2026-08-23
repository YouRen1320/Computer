# 练习：修复 Future 结果协议
+
## 同一验证入口

只修改本目录 `src/` 中的可编辑 starter，并始终运行 `./verify.sh`。完整 starter 的登记故障返回 `41` 与 `EXPECTED_RED`；实现全部合同且保留独立负例后返回 `0` 与 `EXERCISE_GREEN`；编译错误、部分修复、负例被削弱或其他未知状态返回 `43`。

不要修改 `failures/`、测试数据或验证器来制造绿灯；状态 43 会保留当前首个诊断，修正后仍复跑同一命令。

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
