# 实验：FactoryCare 工单包边界

实验把 WorkOrder 放在 domain 包，把控制台放在 app 包。字段私有，状态只能由 assign 与 start 改变；StatusPolicy 保持 package-private。

~~~bash
cd labs/encyclopedia/ch.java-oop.encapsulation-packages
./verify.sh
~~~

验收包括十二个运行断言、一个 public 可变字段导致的运行故障，以及 private 字段直写、错误 import、跨包策略访问三个编译故障。最后必须输出 **LAB PASS**。
