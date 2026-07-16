# 状态机与 SLA 示例

本示例用 JDK 25 的 `Instant`、`Clock.fixed` 和一个缩小的工单状态表演示允许边、guard、非法转换不变、终态、暂停延长 deadline 与时区展示。

```bash
./verify.sh
```

这里的 `NEW → ASSIGNED → IN_PROGRESS → CLOSED/CANCELLED` 是 canonical 独立练习模型；FactoryCare 项目使用唯一 12 状态，且允许 `CLOSED → REOPENED`，不能直接复制“CLOSED 是终态”的教学规则。示例不启动数据库、事务管理器或调度器。
