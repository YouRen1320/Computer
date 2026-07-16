# 实验：FactoryCare Maven 构建取证

目标不是再写一次业务方法，而是把构建输入和证据做成可重放合同。实验工程显式声明三个 JUnit 6 测试构件、固定四个实际执行的插件版本和输出时间戳，并记录 Maven 3.9.16 Wrapper 分发 URL 与 SHA-256。

先填写预测：

| 检查 | 预测 | 第一处可信证据 |
| --- | --- | --- |
| `clean test` 的测试数 | ? | ? |
| compile scope 是否含 JUnit | ? | ? |
| test scope 是否含 Jupiter Engine | ? | ? |
| 普通 JAR 是否含测试 class | ? | ? |
| 两次 package 哈希是否一致 | ? | ? |
| 错误 scope POM 的 compile 树 | ? | ? |

运行：

```bash
cd labs/encyclopedia/ch.java-engineering.maven-reproducible-builds
./verify.sh
```

验收条件：

1. Maven JVM 与 Java 都是 25，Maven 是 3.9.16；
2. 所有 Maven 命令都带 `--offline`，缺缓存时明确失败，不自动联网补取；
3. 3 个 JUnit 测试通过；JUnit 不在 compile 树，在 test 树中版本为 6.1.1；
4. 普通 JAR 不含测试 class；两次干净打包哈希相同；
5. `faults/scope-leak/pom.xml` 的 JUnit 故意使用 compile scope，验证器必须识别这条泄漏；
6. Wrapper 属性精确固定 Maven 3.9.16 分发和 SHA-256；脚本不执行 Wrapper 下载，因此这只是 Wrapper 配置证据，不假装已做首次离线引导；
7. 输出 `LAB PASS`。

变更实验：给 `WorkOrderCost` 增加上限校验，先制造一个失败测试，再修复并重跑。不要删测试、加 `-DskipTests` 或去掉 `--offline` 来制造绿色。

诊断练习：在临时分支删除 `maven-surefire-plugin` 的版本，保存 Maven 实际选择的版本；把 JUnit scope 改为 compile，保存两棵依赖树；让 IDE Maven Runner 使用不同 JDK，比较 IDE 与 `mvn -v`。这些操作有环境差异，固定验证器不会自动改你的 IDE。
