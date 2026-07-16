# 练习：修复角色代理的三条边界

`src/ReflectionProxyChallenge.java` 可以编译，但会绕过 `@RequiresRole`、依赖线程上下文 ClassLoader，并把目标异常留在反射包装层。请保持显式接口 API，逐项修复：

1. 从接口 Method 读取 RUNTIME 注解，拒绝不匹配角色且不调用目标；
2. 用接口定义加载器创建代理，不猜当前线程环境；
3. 解包 InvocationTargetException，把业务 cause 原样交给调用方；
4. 拒绝非接口或目标未实现接口的输入。

~~~bash
cd exercises/encyclopedia/ch.java-engineering.reflection-classloading-proxies
./verify.sh
~~~

起点以 `mode=starter` 通过，证明预期授权绕过已被捕获。完成后同一验证器应输出 `COMPLETED CHALLENGE PASS assertions=10`；部分修复会落入其他非零状态。
