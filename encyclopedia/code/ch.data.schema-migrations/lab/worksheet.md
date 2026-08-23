# 迁移故障记录

运行前先预测三项故障的第一可信证据：

1. 已应用 V1 被编辑后，history 和 resolved checksum 如何分叉？
2. 有三条旧数据时一步加入无默认值的 NOT NULL 列为何失败？
3. 回填遇到非法 priority=9 时，事务、history 和已写数据应处于什么状态？

每项写出影响、迁移/forward-fix、停止条件和恢复方案。禁止用 `repair` 或手改 history 让未知状态静默变绿。
