# 示例：构造、初始化顺序与不变量观察台

本示例观察字段初始化器、主构造器体和重载委托的固定顺序，并证明空白编码无法产生可用对象。

~~~bash
cd examples/encyclopedia/ch.java-oop.constructors-invariants
./verify.sh
~~~

运行前先预测七行正常输出。验证器还运行一个未捕获的非法构造：它必须非零退出，错误类型必须是 **IllegalArgumentException**，否则不能算作目标失败。
