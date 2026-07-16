# 实验：FactoryCare 工单编号的状态归属

实验使用两个 `WorkOrderIdGenerator` 实例表达两个站点的独立序列；`WorkOrder.open` 是静态工厂，`TextRules` 是无状态工具，不读取隐藏共享状态。

~~~bash
cd labs/encyclopedia/ch.java-oop.static-class-state
./verify.sh
~~~

验收包括十四个运行断言、一个“实例规则误写 static”的编译失败，以及一个共享全局计数导致顺序依赖的运行失败。修改需求时增加第三个站点，证明它也从一开始，不能增加 `resetForTest`。
