# 实验：FactoryCare 设备引用地图

目标不是背“栈和堆”，而是用可重放断言证明：同一对象的两个别名、状态相同但身份不同的两个对象、String 身份与内容相等的差异，以及 `null`/空/空白文本的语义边界。

开始前画图并预测：

```text
primary ─┐
         ├──> 设备 A(code=PUMP-01, status=IDLE)
alias   ─┘
peer    ────> 设备 B(code=PUMP-01, status=IDLE)
missing ────> null（没有对象）
```

然后运行：

```bash
cd labs/encyclopedia/ch.java-oop.references-null-identity
./verify.sh
```

验收条件：

1. `ReferenceMapLab` 输出别名修改后的状态和安全 null 分支；
2. `ReferenceMapOracle` 在 `-ea` 下打印 `assertions=15 passed`，其中包含 String 身份/内容和 null/空/空白边界；
3. 把“字段相同”误写成“身份相同”的探针必须非零退出；
4. 未判空解引用探针必须抛出 `NullPointerException`；
5. 最后一行出现 `LAB PASS`。

记录预测、第一次输出、故障证据和修复后输出。不要记录对象地址或 `identityHashCode`，它们不是本实验的稳定 oracle。
