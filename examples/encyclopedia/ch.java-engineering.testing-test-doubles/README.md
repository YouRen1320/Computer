# 参数化测试与替身角色示例

这个离线 Maven 工程把同一对象在测试里的职责说清楚：

- 固定 ID lambda 是 **stub**：只给出预设响应；
- `FakeRepository` 是 **fake**：有可工作的内存状态，但不证明真实数据库；
- Mockito 创建的 `NotificationSender` 在成功用例中承担 **mock**：只验证业务要求的一次通知；
- 参数化测试覆盖优先级 3/4 的分界，并为每次调用创建全新 fixture。

先预测 6 次测试调用的结果，再运行：

```bash
./verify.sh
```

验证器要求 JDK 25、Maven 3.9.16，并以 `--offline` 执行。它还确认 JUnit 与 Mockito 没有进入 compile scope。

POM 在测试 JVM 上显式加载 Mockito 的 `-javaagent`，避免 JDK 25 下依赖运行时 self-attach；该参数只属于 Surefire 测试进程，不进入业务 JAR。首次离线运行前仍需在受控联网步骤预热已锁定依赖。

## 证据边界

通过结果证明领域路由、内存保存和通知合同满足当前 oracle；没有启动数据库、消息系统或网络，因此不证明 SQL、事务、序列化与真实投递。不要把 `FakeRepository` 改名为“数据库集成测试”来扩大结论。
