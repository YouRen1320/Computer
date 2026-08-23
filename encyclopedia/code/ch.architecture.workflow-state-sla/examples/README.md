# 状态机与 SLA 示例

本示例用 JDK 25 的 `Instant`、`Clock.fixed` 和明确命名的 `DemoTicket` 教学投影演示允许边、guard、非法转换不变、终态、暂停延长 deadline 与时区展示。

```bash
./verify.sh
```

投影中的五个状态与 FactoryCare 同名状态一一映射，但省略 `TRIAGED`、`ACCEPTED`、`PENDING_PARTS`、`PENDING_APPROVAL`、`RESOLVED`、`VERIFIED`、`REOPENED`，并把处理完成简化为直接进入 `CLOSED`。因此它不是 FactoryCare `WorkOrder`，也不能复制“CLOSED 是终态”的教学规则；正式合同允许 `CLOSED → REOPENED`。示例不启动数据库、事务管理器或调度器。
