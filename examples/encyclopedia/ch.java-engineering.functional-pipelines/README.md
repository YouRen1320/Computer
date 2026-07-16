# Stream、Collector 与 Optional 示例

这个 Java 25 示例用五张固定工单演示：中间操作在终止操作前不执行；`filter → map → toList` 保留开放工单；`groupingBy` 用 `LinkedHashMap` 固定首次遇见顺序；总和与最大值分别用数值归约和 Optional 表达。

运行前预测 `lazy.before`、`lazy.after`、三组工时和空输入最大值：

```bash
./verify.sh
```

脚本逐行比较八条输出，并要求重复消费同一 Stream 的独立进程失败。它不测墙钟时间，也不把并行调度顺序当 oracle。
