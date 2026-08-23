# 示例：FactoryCare 可重复 Maven 构建

这个最小工程不使用 Spring。它固定 JDK release、JUnit BOM、Compiler、Surefire、JAR 和 Dependency 插件版本，并固定 JAR 条目时间。验证器只使用本机已经存在的 Maven 缓存，所有 Maven 调用都带 `--offline`，绝不在验证过程中下载依赖。

运行前预测：

1. `mvn test` 会执行到哪个生命周期阶段；
2. `junit-jupiter` 是否会出现在 compile scope 依赖树；
3. 普通 JAR 是否包含 `OrderAmountCalculatorTest.class`；
4. 两次 `clean package` 的 JAR SHA-256 是否一致；
5. 删除本地缓存后离线构建为何可能失败。

```bash
cd examples/encyclopedia/ch.java-engineering.maven-reproducible-builds
./verify.sh
```

固定验收：2 个 JUnit 测试通过；compile scope 树没有 JUnit；test scope 树有 JUnit Jupiter 6.1.1；JAR 只有业务 class，不含测试 class；两次干净打包哈希相同。脚本验证的是当前机器上的受控重放，不声称操作系统级网络隔离或第三方独立复现。
