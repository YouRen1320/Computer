# 实验：Money、WorkOrderId 与 ServiceTime

实验把三种值的输入、操作和结果写成固定报告。Money 区分“输入必须精确”和“结算允许 HALF_UP”；WorkOrderId 同时执行外形与标准 UUID 解析；ServiceTime 显式使用 ZoneId，并观察夏令时 gap/overlap 是否一一对应 Instant。

~~~bash
cd labs/encyclopedia/ch.java-oop.business-value-types
./verify.sh
~~~

先预测 24 条断言，再运行验证器。除四个指定反例外，实验还要求跨币种相加真实失败。成功末行是 `LAB PASS`。
