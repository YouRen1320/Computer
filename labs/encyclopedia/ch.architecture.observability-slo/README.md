# 可观测闭环故障实验

`faults.json` 固定注入六种常见失败：日志无 trace、metric 高基数、异步 trace 断裂、liveness 错绑数据库、SLI 分母漏掉系统错误、瞬时尖峰直接 page。`verify.rb` 不是检查“修好了的漂亮样本”，而是先证明每个故障确实满足其红灯条件，再证明每项给出了可执行修复和原预言重放要求。

运行：

```bash
./verify.sh
```

建议先在 [worksheet.md](worksheet.md) 手写每个故障的用户影响、检测证据、最小修复与重跑预言，再查看 JSON 中的参考诊断。该实验完全离线，不替代真实 PostgreSQL/Python 断连、线程池上下文丢失、Collector 停机或告警通知演练。
