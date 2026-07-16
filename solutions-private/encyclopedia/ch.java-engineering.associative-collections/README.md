# 私有解析：关联集合挑战

只在公开 starter 的键合同失败已经复现、你已独立修复并能解释为何 List 测试不足后阅读。

私有解使用 `record DeviceKey(String id)` 生成一致且稳定的 equals/hashCode；LinkedHashSet 保留首次出现顺序；Map.merge 累加类别；getOrDefault 显式给出缺失计数。返回的 Set/Map 包装在不可修改边界内。

```bash
cd solutions-private/encyclopedia/ch.java-engineering.associative-collections
./verify.sh
```

验证器要求零警告、14 个断言通过，并确认独立可变键故障仍产生 `LOST_HASH_KEY`。私有解不得被公共教材或 starter 引用。
