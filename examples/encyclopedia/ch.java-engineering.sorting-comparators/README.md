# 示例：自然顺序、Comparator 链、稳定排序与 null

示例用 DeviceId 的 Comparable 表达唯一自然顺序；用“优先级降序、创建时间升序、ID 升序”组合 FactoryCare 调度顺序；用只比较优先级的窄比较器证明 List 稳定排序；用字段级 `nullsLast` 处理缺失 dueAt。独立故障程序证明整数减法比较在极值处溢出。

运行前预测：

1. 四张工单分别由比较链哪一层决定先后；
2. A(P2)、B(P1)、C(P2)、D(P1) 稳定降序后的完整顺序；
3. dueAt 为 null 的工单放在哪里；
4. 排序副本后原输入是否改变；
5. `Integer.MIN_VALUE - 1` 的比较符号是否正确。

```bash
cd examples/encyclopedia/ch.java-engineering.sorting-comparators
./verify.sh
```

验证器要求 Java 25、`-Xlint:all -Werror` 零警告、正例精确输出 8 行；溢出程序必须非零退出并出现 `OVERFLOW_ORDER`。`EXAMPLE PASS` 只证明固定合同。
