# 线程/JMM 同步独立练习
+
## 同一验证入口

只修改本目录 `src/` 中的可编辑 starter，并始终运行 `./verify.sh`。完整 starter 的登记故障返回 `41` 与 `EXPECTED_RED`；实现全部合同且保留独立负例后返回 `0` 与 `EXERCISE_GREEN`；编译错误、部分修复、负例被削弱或其他未知状态返回 `43`。

不要修改 `failures/`、测试数据或验证器来制造绿灯；状态 43 会保留当前首个诊断，修正后仍复跑同一命令。

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
