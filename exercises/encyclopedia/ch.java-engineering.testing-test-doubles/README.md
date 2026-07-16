# 独立练习：完成 fake 与 spy

starter 的 SUT 已完整，两个测试替身故意未完成。不要修改业务类来迎合测试。

## 任务

1. 先预测 5 次测试调用中哪些通过、哪些失败，并把失败归为 fixture、动作或 oracle。
2. 在 `CandidateFakeRepository` 中实现实例级内存保存；不得使用 static。
3. 在 `CandidateSpyNotificationSender` 中捕获“接收者|消息”；不得打印、联网或 sleep。
4. 保留参数化非法优先级与 Mockito 边界验证，不添加无业务意义的调用顺序。
5. 完成后让 `mvn --offline clean test` 通过，并说明为什么这仍不证明真实数据库/通知服务。

运行 starter 验证：

```bash
./verify.sh
```

当前验证器预期 starter 非零退出并输出 `EXERCISE READY`。实现后应直接运行 Maven 测试；此时 starter 验证器因“不再失败”而提醒你进入完成态，这是预期行为。
