# FactoryCare JVM 诊断证据实验

实验把“日志相关联”“线程锁证据”“GC 暂停摘要”和“性能结论门禁”放进一个确定性闭环。自动验证只读取 `fixtures/` 中的脱敏文本：

- 三条事件必须共享 `corr-42`，authorization 明文不得出现；
- 异常必须保留类型、cause 和非空栈；
- 线程 dump 包含 5 个线程、两个互相等待的 BLOCKED 线程和 deadlock 标记；
- GC 夹具含 3 次 pause，其中 1 次 Full，汇总暂停 18.500ms；
- 至少两次线程样本才允许声称“持续”，性能证据至少要有 warmup 与多个样本。

先回答：

1. `RUNNABLE` 为什么不等于正在独占 CPU？
2. dump 中 `dispatch-worker` 等待哪个锁，谁持有？
3. 18.500ms 的 GC 总暂停能否解释任意 8 秒请求？
4. 一次 `nanoTime` 为什么不能证明优化？

然后运行：

```bash
./verify.sh
```

验证器还执行四个预期失败：明文泄露、单快照越权、一次 benchmark、只有 message 没有 throwable。

## 真实工具边界

实验不运行 `jcmd`、`jstack`、`jfr`，也不枚举 PID。若要练习真实采样，只能对自己启动且无业务数据的测试 JVM，先执行 `jcmd <pid> help`，记录命令影响、时间窗、磁盘和清理计划。固定 parser 只适配本目录夹具，不能直接投入生产。
