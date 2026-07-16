# 示例：List 输入、Set 去重、Map 索引与稳定键

示例保留三行导入 List，用 LinkedHashSet 去重并保留首次 encounter order，用 LinkedHashMap 统计类别，用 HashMap 证明“相等但不是同一引用”的 DeviceId 可以命中，再用 TreeSet 生成明确排序。故障程序把可变整数直接作为 hash，入表后修改，必须产生 `LOST_HASH_KEY`。

运行前预测：

1. 三行输入中两个相等 DeviceId，List 与 Set 的 size 各是多少；
2. 相等 record 键是否必须是同一引用才能命中；
3. `get(missing)` 和 `containsKey(missing)` 的组合结果；
4. TreeSet 的输出顺序由什么决定；
5. 同一键引用入表后改变 hash，`containsKey` 是否仍能命中。

```bash
cd examples/encyclopedia/ch.java-engineering.associative-collections
./verify.sh
```

验证器要求 JDK 25、零 lint 警告、正例精确输出 10 行；可变键程序必须非零退出且出现 `LOST_HASH_KEY`。`EXAMPLE PASS` 不代表已完成零基础试读或学习验收。
