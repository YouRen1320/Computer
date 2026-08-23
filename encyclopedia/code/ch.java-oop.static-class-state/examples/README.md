# 示例：类成员与实例成员观察台

示例同时观察实例序号、类级创建计数、静态工厂、无状态工具方法和必要的类初始化顺序。

~~~bash
cd examples/encyclopedia/ch.java-oop.static-class-state
./verify.sh
~~~

验证器要求 JDK 25，比较完整标准输出，并确认两个真实失败：静态上下文直接读取实例字段必须编译失败；两个场景共享全局计数必须产生顺序污染运行失败。成功末行是 `EXAMPLE PASS`。
