# 修复错误存活策略

starter 把数据库故障当作进程存活失败。运行 `./verify.sh` 会稳定得到 2 个测试中的 1 个失败，哨兵为 `EXPECTED_LIVENESS_INDEPENDENT_FROM_DATABASE`。

修复 `ProbePolicy.evaluate`：liveness 只由 processHealthy 决定；readiness 再组合数据库状态。
