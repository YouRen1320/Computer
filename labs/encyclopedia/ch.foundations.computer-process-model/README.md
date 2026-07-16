# 实验：观察一个子进程的出生、存活与退出

本实验只启动仓库提供的固定 Ruby 子进程，不查看电脑上的其他用户进程。先阅读 `child_probe.rb` 的三项行为：记录 PID/PPID、等待不超过一秒、自然退出。先预测，再运行：

```text
ruby verify.rb
```

预期最后一行是 `process-model lab fixture: PASS`。把输出填入 `worksheet.md`，再分析 `resource-report.json` 的三行固定快照：10:00 的 CPU、10:05 的内存、10:10 的磁盘证据各自说明什么，哪些结论仍不能证明。

实验禁止扩大为遍历全机进程、强制结束陌生 PID、制造内存耗尽或填满磁盘。自动验证器不批改资源诊断和 120 秒复述。
