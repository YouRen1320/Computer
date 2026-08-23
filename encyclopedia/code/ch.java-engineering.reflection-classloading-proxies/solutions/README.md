# 私有参考实现：显式接口角色代理

参考实现把契约 Class、目标、角色与事件收集器显式传入代理工厂；它拒绝非接口和错误目标，从接口 Method 读取注解，处理 Object 方法，并把 InvocationTargetException 解包为目标 cause。

~~~bash
cd solutions-private/encyclopedia/ch.java-engineering.reflection-classloading-proxies
./verify.sh
~~~

验证器在 Java 25 下运行参考实现并重放五类故障。它不扫描 classpath、不加载外部 JAR，也不打开模块私有包。
