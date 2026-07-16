# FactoryCare JSON 映射实验

正常 oracle 覆盖 UTF-8 文件、语义往返、missing/null/value、严格/宽松未知字段、enum、Instant、BigDecimal、重复字段和版本。`JsonSupport` 的扁平 codec 只是教学夹具，不用于生产。

先为六个字段写 shape 表，再预测六个故障：

```bash
./verify.sh
```

验收要求：25 个正常断言通过；错误字符集、缺失文件、字段漂移、非法 enum、静默 unknown 和 double 精度损失必须在独立进程失败。I/O 与 mapping 证据不能合并成一个泛化错误。
