# 示例：封装与包边界观察台

领域类与调用端位于不同 package。正常调用只能使用 public 构造器、命令和查询；包内策略由同包探针间接验证。

~~~bash
cd examples/encyclopedia/ch.java-oop.encapsulation-packages
./verify.sh
~~~

验证器还单独编译两个故障：跨包直接写 private 字段、跨包导入 package-private 类型。两者都必须在 javac 阶段失败并命中目标诊断。
