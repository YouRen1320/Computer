# FactoryCare 函数式管道合同实验

这个实验同时保留普通循环 oracle 与 Stream 实现，要求空、单项、多项输入的开放 ID、类别工时、总工时和最大优先级逐项一致。`LinkedHashMap` 明确固定报告类别首次遇见顺序，Optional fallback 用调用计数验证惰性。

运行前手算六项报告，并预测五个故障夹具：

```bash
./verify.sh
```

验收：22 个正常断言通过；重复消费、无终止操作的 peek、副作用式 Optional 强取、非结合 reducer 与 eager fallback 都必须在独立进程失败。测试不访问网络、不依赖线程顺序或耗时阈值。
