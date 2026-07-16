# 私有解析：排序比较器挑战

只在公开 starter 逐项暴露方向、溢出、null 或稳定性失败，并完成独立尝试后阅读。

修复要点：对 priority 比较器立即 reversed，再链升序时间与 ID；数值使用 `Integer.compare`；nullsLast 包装 dueAt 的自然顺序；稳定性比较器不加入 ID tie-breaker。排序始终作用于副本，最终用 List.copyOf 发布。

```bash
cd solutions-private/encyclopedia/ch.java-engineering.sorting-comparators
./verify.sh
```

私有验证要求 14 个断言零警告通过，并确认独立循环比较器仍产生 `CYCLIC_ORDER`。私有解不得被公开正文或 starter 引用。
