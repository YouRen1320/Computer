# 消息投递故障注入实验

安全基线后依次注入：无 outbox、confirm 前标记、timeout 换 ID、处理前 ack、提交后 ack 前崩溃、无限 requeue、忽略 unroutable、未知版本反复重试。

```bash
./verify.sh
```

每个 fault 对应唯一 oracle；`REDELIVERY_EXPECTED` 是至少一次合同，消费者必须用稳定 eventId 吸收。
