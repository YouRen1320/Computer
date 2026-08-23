# FactoryCare Lambda 行为合同实验

目标是把“能写箭头”升级为“能解释并验证行为合同”。正常 oracle 覆盖 `Predicate`、`Function`、`Consumer`、`Supplier`、四类方法引用、组合短路、有效-final 捕获快照和 null 边界。

先预测再运行：

1. 阈值下方、等于阈值、上方各自结果；
2. `open.and(urgent)` 在 closed 工单上是否调用右侧；
3. Lambda 标签与静态方法引用是否对每个输入一致；
4. 三份非法源码会分别出现哪类编译证据；
5. 重复调用带写入的 Predicate 为什么属于行为故障。

```bash
./verify.sh
```

验收要求：20 个正常断言通过；三份编译故障必须被 `javac` 拒绝；一份隐藏副作用必须在独立进程失败。不要把预期红灯删除成“全绿”。
