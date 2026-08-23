# FactoryCare 测试边界实验

目标是保留业务 oracle，同时识别三种常见越界：

1. 正常套件用 `Clock.fixed` 控制时间、手写 fake 保存状态、手写 spy 捕获通知，并用 Mockito 只验证必要边界。
2. `OverspecifiedInteractionOrderFault` 故意要求错误的实现顺序，证明过度 `InOrder` 会冻结实现。
3. `SharedFixturePollutionFault` 用 static 仓库让后一测试继承前一状态，证明加排序不是隔离方案。
4. `MockDatabaseProofFault` 让 mock 永远回答“不重复”，再错误声称已验证唯一约束；第二次保存不会触发真实数据库约束。

先为每个故障写出首个失败类别，再执行：

```bash
./verify.sh
```

验证器先要求正常套件 8 次调用全部通过，再逐个运行三个预期失败。故障测试不属于默认发现命名，避免把红灯混入正常套件。

Surefire 显式用测试级 `-javaagent` 启动 Mockito，避免 JDK 25 self-attach；这不授权生产 JVM 动态附着，也不改变“只 mock 自有接口”的边界。

## 修复要求

- 顺序故障：删除非业务顺序期待，保留保存状态与一次通知 oracle；
- 污染故障：每例创建新仓库，不使用 `@Order` 隐藏共享；
- 数据库证明故障：明确 mock 只证明调用合同，并把唯一约束交给真实数据库集成测试。

本实验没有启动数据库，因此修复第三项时只能写出集成测试计划，不能把 fake 的绿灯改名为已验证。
