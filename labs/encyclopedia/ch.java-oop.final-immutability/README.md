# 实验：FactoryCare 不可变 Money 与时间槽

`Money` 位于 domain 包，调用端只能使用公开构造、查询和 `plus`；private final 字段维持金额与币种不变量。`MaintenanceWindow` 用 `int[]` 演示输入、输出两侧的复制。

~~~bash
cd labs/encyclopedia/ch.java-oop.final-immutability
./verify.sh
~~~

验收包括十六个运行断言，以及 final 字段重新赋值的编译失败、可变 Money 原地加法和数组 getter 泄漏两种运行失败。需求变更：增加 `minus`，结果不得为负，且旧对象必须保持原值。
