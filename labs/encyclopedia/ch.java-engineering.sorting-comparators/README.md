# 实验：FactoryCare 工单排序合同

实验定义“优先级降序、创建时间升序、ID 升序”的调度 Comparator，用六张工单覆盖每一层；另用窄比较器证明稳定排序、用字段级 nullsLast 处理缺失截止时间。Oracle 对六元素做 36 个有序对和 216 个三元组穷举，验证自比较、符号反向、传递与零等价一致。

运行前手算：

| 比较对/组 | 第一决定层 | expected |
| --- | --- | --- |
| WO-101(P3) 与 WO-104(P2) | ? | ? |
| WO-101/WO-103 同 P3 不同时间 | ? | ? |
| WO-101/WO-102 同 P3 同时间 | ? | ? |
| A(P2)、B(P1)、C(P2)、D(P1) | stable group | ? |
| dueAt 09:00、10:00、null | null policy | ? |

```bash
cd labs/encyclopedia/ch.java-engineering.sorting-comparators
./verify.sh
```

验收条件：正例 JDK 25 零警告，输出 `assertions=18 passed` 和 `triples:216`；输入列表不被修改；相等主键保持 encounter order；null 放末尾；五个故障分别证明减法溢出、循环传递、符号不反向、null 字段未包装和 TreeSet 比较等价类碰撞；最终输出 `LAB PASS`。

变更练习：增加“超时优先”键，但禁止 comparator 内调用当前时间。给定固定 `evaluationTime` 预计算 overdue，并新增边界等于截止时刻、null dueAt、排序过程中对象状态变化的测试。
