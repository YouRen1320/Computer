# 实验：参数、重载、作用域与递归边界

本实验建立可重放的方法契约，而不是只证明一个调用能运行。

| 场景 | 固定预期 |
| --- | --- |
| 金额 1999×0/1/3 | 0、1999、5997 |
| remaining(10,3)/(3,10) | 7、-7，展示同类型实参顺序风险 |
| 优先级 0/4 | INVALID、URGENT |
| 两个 ticketLabel 重载 | `T-7`、`T-7:ASSIGNED` |
| 基本类型形参修改 | 调用者仍为 3 |
| 数组元素修改 | 调用者观察 5 |
| 数组形参重新赋值 | 调用者仍观察 5 |
| countdown 0/1/4 | 0、1、4并终止 |

```bash
cd labs/encyclopedia/ch.java.methods
./verify.sh
```

验收要求：正常输出精确匹配；`java -ea` 输出 `assertions=18 passed`；漏 return、越过作用域、重载歧义三个源码都必须编译失败；无基线递归必须运行失败；最后出现 `LAB PASS`。
