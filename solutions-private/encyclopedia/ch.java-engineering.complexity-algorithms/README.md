# 私有解析：复杂度与索引挑战

只在公开 starter 已暴露操作次数或索引失败，并独立完成结果等价检查后阅读。

私有解用 LinkedHashSet 一次处理每个输入并保首次顺序；排序副本只建一次，供全部 binarySearch 复用；LinkedHashMap 按输入顺序 put，让相同 ID 的最新事件覆盖旧值。原始 audit List 始终保留重复，返回值都不可修改。

```bash
cd solutions-private/encyclopedia/ch.java-engineering.complexity-algorithms
./verify.sh
```

验证器要求 15 个断言零警告通过，并确认未排序二分故障仍产生 `UNSORTED_PRECONDITION`。私有解不得被公开资产引用。
