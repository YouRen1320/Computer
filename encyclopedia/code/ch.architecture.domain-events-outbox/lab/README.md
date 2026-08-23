# 领域事件与 Outbox 故障注入实验

验证器先比较安全基线，再注入八个崩溃/合同错误：业务先提交、状态前发事件、发送后标记前崩溃、重试换 eventId、payload 无版本、发送前标记、claim 无租约、吞掉 outbox 失败。

```bash
./verify.sh
```

`SEND_THEN_MARK_CRASH` 的重复是至少一次合同本身；危险在于换 ID 或消费者不幂等。离线实验不替代 PostgreSQL 行锁、Spring 事务和真实进程终止测试。
