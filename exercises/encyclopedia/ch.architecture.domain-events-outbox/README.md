# 领域事件与 Outbox 独立练习

修复 `src/DomainEventsOutboxChallenge.java` 中八个 `TODO`：同事务、状态后事件、稳定 eventId、payload 版本、消费者幂等、发送后标记、claim 租约与不支持版本隔离。

```bash
./verify.sh
```

起始代码必须稳定红灯，首个证据为 `STATE_AND_EVENT_NOT_ATOMIC`。不要删除负向断言，也不要声称 Exactly Once。
