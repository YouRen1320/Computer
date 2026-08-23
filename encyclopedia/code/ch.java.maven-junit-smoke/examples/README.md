# Maven + JUnit 最小闭环

这是一个非 Spring 的标准 Maven 工程。业务源码位于 `src/main/java`，测试源码位于 `src/test/java`。`pom.xml` 只声明 JDK 25、JUnit 6.1.1 与 Surefire 3.5.5。

运行：

```bash
bash verify.sh
```

验证脚本强制 Maven 离线执行，不会下载依赖；因此第一次运行前，本机 Maven 缓存必须已经包含这些固定版本。脚本不把 `BUILD SUCCESS` 单独当成测试证据，而会在日志中断言 `Tests run: 2, Failures: 0, Errors: 0, Skipped: 0`。
