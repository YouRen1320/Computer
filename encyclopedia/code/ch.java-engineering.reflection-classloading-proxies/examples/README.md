# 示例：反射、类加载器与接口代理观察台

本示例只使用当前 JVM 中声明的类型，不扫描 classpath、不读取外部 JAR。它读取运行期 `@RequiresRole`，创建显式接口代理，验证返回值与调用次数，并证明目标异常解包和上下文 ClassLoader 恢复。

~~~bash
cd examples/encyclopedia/ch.java-engineering.reflection-classloading-proxies
./verify.sh
~~~

验证器还会重放非接口代理、private 成员访问、错误上下文加载器和未解包目标异常。成功末行是 `EXAMPLE PASS`。
