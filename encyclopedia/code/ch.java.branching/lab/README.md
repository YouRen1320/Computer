# 实验：FactoryCare 工单优先级与状态路由

本实验验证两套互不混淆的选择规则：数值优先级使用有顺序的 `if/else if/else`，有限状态文本使用穷尽的 switch 表达式。固定边界如下：

| 输入 | 预期 |
| --- | --- |
| 优先级 1 | `ROUTINE` |
| 优先级 3 | `HIGH` |
| 优先级 5 | `CRITICAL` |
| 优先级 0 或 6 | `REJECTED` |
| 状态 `ASSIGNED` | `WORK` |

先逐项手算，再运行：

```bash
cd labs/encyclopedia/ch.java.branching
./verify.sh
```

验收条件：

1. 五类边界输出逐行精确匹配；
2. `PriorityRoutingOracle` 在 `-ea` 下打印 `assertions=9 passed`；
3. 一个故意省略 `break` 的传统 switch 必须非零退出，并在日志中明确出现 `FALLTHROUGH_DETECTED`；
4. 最后一行是 `LAB PASS`。

这里的 Java `assert` 与故障探针是已经提供的验证支架，只需要复制运行、读取证据。本章不要求设计正式测试框架，也不提前讲异常对象。
