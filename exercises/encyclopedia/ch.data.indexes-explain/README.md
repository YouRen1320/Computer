# 练习：索引证据决策

当前 `answer.json` 是故意失败的 starter。执行 `./verify.sh` 应得到 `EXPECTED_RED`；第一处错误是建前后结果指纹不同，证明正确性优先于性能结论。

修复时保持固定分布，按“status 等值、created_at 范围、稳定排序”选择复合列顺序；只有 buffers 证据改善才保留候选；拒绝无收益状态索引；把函数谓词改为半开时间范围，并写出回滚 DDL。
