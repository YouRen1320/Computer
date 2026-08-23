# 公开练习：事件流所有权与 CPU 隔离

补全 `starter.dart` 的四个可编辑函数：

1. 用 broadcast controller 证明订阅前事件不回放，并观察 onCancel 清理；
2. 在名为 `urgent-worker` 的 `Isolate.run` 中聚合优先级；
3. 保留 worker 抛出的 `StateError('worker-boom')` 类型、消息和非空 stack；
4. 对同一 subscription 重复 cancel 时只释放生产者一次，并等待返回的 Future。

公开 starter 会稳定红；同一个 `./verify.sh` 在四项全部完成后转绿。
