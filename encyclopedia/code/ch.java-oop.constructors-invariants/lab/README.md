# 实验：FactoryCare 合法设备创建

实验把字段初始化顺序、构造器委托与对象不变量放在同一条可重放路径中。

~~~bash
cd labs/encyclopedia/ch.java-oop.constructors-invariants
./verify.sh
~~~

先写预测，再运行。验收要求：

1. 正常设备输出精确匹配；
2. **ConstructionOracle** 输出 **assertions=13 passed**，其中一条精确验证两个字段初始化器与构造器体的顺序；
3. 构造期间发布半成品的故障必须非零退出；
4. 两个构造器互相委托必须在编译阶段失败并包含 **recursive constructor invocation**；
5. 验证器最后输出 **LAB PASS**。
