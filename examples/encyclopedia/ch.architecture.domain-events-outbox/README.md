# 领域事件与 Outbox 离线示例

本示例用事务快照模型演示关闭工单与 `WorkOrderClosed.v1` 同提交/同回滚，以及 relay 在“发送成功、标记前崩溃”后用相同 `eventId` 重投，消费者只产生一次受保护副作用。

```bash
./verify.sh
```

它不启动 Spring、MyBatis、PostgreSQL 或消息代理；真实行锁、事务代理、JSON Schema 和进程故障仍需 Testcontainers T4 证据。
