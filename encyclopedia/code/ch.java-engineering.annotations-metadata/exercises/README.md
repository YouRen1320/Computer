# 练习：修复 `@RequiresRole` 元注解契约

起始声明故意使用 `SOURCE`、只允许类目标，并缺少重复与继承策略；因此最初会在编译期失败。只修改 `RequiresRole.java` 与 `RequiresRoles.java`，让它满足以下契约：

- 可标在类和方法上；
- 同一位置可重复，容器的目标和保留策略兼容；
- 运行时可读取；
- 类上的角色可通过超类继承给子类，但不要误以为接口或方法也会自动继承；
- `scope` 缺省时仍为 `TENANT`。

```bash
cd exercises/encyclopedia/ch.java-engineering.annotations-metadata
./verify.sh
```

未完成时脚本输出 `STARTER EXPECTED FAILURE`；完成后输出 `COMPLETED CHALLENGE PASS`。不要修改 `ChallengeApp.java` 中的 oracle 来让测试变绿。
