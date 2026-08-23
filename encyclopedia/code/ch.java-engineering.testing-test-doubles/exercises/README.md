# 独立练习：完成 fake 与 spy

starter 的 SUT 已完整，两个测试替身故意未完成。不要修改业务类来迎合测试。

## 任务

1. 先预测 5 次测试调用中哪些通过、哪些失败，并把失败归为 fixture、动作或 oracle。
2. 在 `CandidateFakeRepository` 中实现实例级内存保存；不得使用 static。
3. 在 `CandidateSpyNotificationSender` 中捕获“接收者|消息”；不得打印、联网或 sleep。
4. 保留参数化非法优先级与 Mockito 边界验证，不添加无业务意义的调用顺序。
5. 完成后让 `mvn --offline clean test` 通过，并说明为什么这仍不证明真实数据库/通知服务。

统一验证入口：

```bash
./verify.sh
```

同一个入口覆盖完整学习状态：原始 starter 返回 `41` 并输出 `EXPECTED_RED`；完成 fake 与 spy、移除两处 `TODO` 且 5 次测试全部通过时返回 `0` 并输出 `EXERCISE_GREEN`；部分修改、编译错误、测试数量变化或工具链不匹配返回 `43` 并输出 `UNKNOWN_STATE`。不要绕过 `./verify.sh`，Maven 原始日志只用于定位失败。
