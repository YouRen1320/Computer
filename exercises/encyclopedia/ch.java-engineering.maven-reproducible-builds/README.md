# 独立练习：修复不可审计的 Maven 工程

关闭 AI，限时 40 分钟。业务代码和两个测试已经存在，POM 故意保留三类工程缺口：JUnit scope 错误、输出时间未固定、构建插件未全部锁版本。

要求：

1. 使用 JUnit BOM 6.1.1，并让 `junit-jupiter` 仅为 `test` scope；
2. 增加固定 `project.build.outputTimestamp`；
3. 固定 Compiler 3.15.0、Surefire 3.5.5、JAR 3.5.0、Dependency 3.7.0；
4. 所有 Maven 验证保持 `--offline`，不得新增仓库或跳过测试；
5. 让两个测试通过、compile scope 无 JUnit、普通 JAR 无测试 class；
6. 两次 `clean package` 的 SHA-256 相同；
7. 写 150 字说明“本机两次相同”仍不能证明什么。

```bash
cd exercises/encyclopedia/ch.java-engineering.maven-reproducible-builds
./verify.sh
```

初始版本应打印 `STARTER EXPECTED FAILURE` 并列出 POM 合同缺口；完成后打印 `EXERCISE PASS`。不要从私有目录复制完整 POM。修复前先预测每个缺口影响依赖类路径、插件选择还是产物字节。

变更题：新增负数工时测试，让业务方法拒绝非法输入；先保存红测，再修复并重跑同一验证器。
