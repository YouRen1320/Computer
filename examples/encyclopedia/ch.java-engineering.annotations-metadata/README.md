# 示例：注解可见性观察台

这个示例把同一份类型声明上的 `SOURCE`、`CLASS`、`RUNTIME` 注解分别交给编译器、`javap` 和最小反射探针观察，并验证重复注解、默认值、类型使用注解与 `@Inherited` 的类继承边界。

```bash
cd examples/encyclopedia/ch.java-engineering.annotations-metadata
./verify.sh
```

运行前先预测：哪两种注解会进入 class 文件，哪一种能由运行时探针读到；接口上的 `@Inherited` 是否会传给实现类。成功末行是 `EXAMPLE PASS`。脚本只使用 JDK 25 自带的 `javac`、`java` 与 `javap`，不会访问网络。
