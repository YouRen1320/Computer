# 独立练习：修复键合同、保序去重、计数与缺失分支

关闭 AI，限时 40 分钟。starter 可以零警告编译，但 `DeviceKey` 让 equals 相等的对象返回不同 hash，第一条去重 oracle 必须失败。验证器输出 `STARTER EXPECTED FAILURE` 只是起点。

要求：

1. 把 DeviceKey 改成只由不可变 id 决定 equals/hashCode 的值键，删除错误 hash 输入；
2. 去重后保留第一次出现顺序，并返回调用者不能修改的 Set；
3. 类别计数对重复类别累加，而不是每行覆盖为 1；
4. 缺失类别返回显式 0，不让 null 自动拆箱；
5. Map<DeviceKey,String> 能用相等但不同引用的键命中；
6. 禁止用 List 全扫描、`System.identityHashCode`、宽范围 catch 或把 null 变成空字符串；
7. 最终输出 `exercise.assertions=14 passed` 和 `EXERCISE PASS`。

```bash
cd exercises/encyclopedia/ch.java-engineering.associative-collections
./verify.sh
```

完成后变更：设备 ID 改为租户内唯一。用不可变组合键新增同 ID 不同租户、同租户重复和缺失租户测试；解释为什么仅在显示字符串中拼接租户不是可靠键合同。
