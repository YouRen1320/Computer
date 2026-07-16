# 线程/JMM 同步独立练习

完成两个计数器，不改轮次、expected 或并发调用：

1. SynchronizedCounter 的全部读写使用同一 monitor；
2. LockedCounter 的全部读写使用同一 final ReentrantLock；
3. lock 后立即 try，finally 释放；
4. 两线程各加 200 次，重复运行恒为 400；
5. 保留 barrier 强制的错误版，解释 actual=1 的交错。

```bash
./verify.sh
```

starter 通过结构和运行探针确定性报 `COUNTER_CONTRACT`，不是概率竞态。修复后故障夹具仍应以 `LOST_UPDATE` 失败。
