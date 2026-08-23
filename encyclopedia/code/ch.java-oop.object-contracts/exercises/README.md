# 练习：修复 DeviceId 的直接契约
+
## 同一验证入口

只编辑本目录 `src/` 中的 starter，并始终运行 `./verify.sh`：完整 starter 精确返回 `41` 与 `EXPECTED_RED`；全部合同及独立故障夹具通过时返回 `0` 与 `EXERCISE_GREEN`；编译失败、只修了一部分、故障夹具被削弱或其他未知状态返回 `43` 并保留首个诊断。

因此修正后无需改跑私有脚本，也不要修改 `failures/`、验证器或退出码来制造绿灯。

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

未修复时 `./verify.sh` 应以 41 返回 `EXPECTED_RED`。修好后，同一验证器应观察程序输出 `challenge.assertions=16 passed`、保留独立编译负例，并以 0 返回 `EXERCISE_GREEN`。
