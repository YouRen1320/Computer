# 练习：修复 DeviceId 的直接契约

起始代码可以编译，但故意让 `equals` 与 `hashCode` 使用不同字段，并让 `toString` 暴露租户值。你的任务是让值相等范围、哈希字段集合和安全诊断表示达成一致，同时保持类型不可变。

约束：

1. 不改测试数据与退出码；
2. 不用容器行为充当契约 oracle；
3. `equals(null)` 必须返回 `false`，相等必须满足自反、对称、传递和一致；
4. 相等对象的哈希值必须相等；
5. 固定输出中不得出现原始租户值。

~~~bash
cd exercises/encyclopedia/ch.java-oop.object-contracts
./verify.sh
~~~

未修复时应看到 `STARTER EXPECTED FAILURE status=8`。修好后，程序自身应输出 `challenge.assertions=16 passed`；验证器仍把初始故障当作预期教学证据。
