# 消息投递独立练习

修复八个 `TODO`：outbox 原子性、confirm 后标记、稳定 eventId、提交后 ack、幂等消费、有限退避、unroutable 可见和永久错误 DLQ。

```bash
./verify.sh
```

起始代码固定红灯于 `BUSINESS_OUTBOX_NOT_ATOMIC`，不得删除负向断言或宣称 Exactly Once。
