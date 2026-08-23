# 私有解析：Maven 构建合同

只在公开练习完成独立预测和第一次修复后阅读。

关键不是复制 XML，而是把缺口映射到职责：JUnit 的 `test` scope 保护业务类路径；`outputTimestamp` 控制支持该机制的归档时间；显式插件版本防止默认绑定随环境漂移；Dependency 插件版本使依赖树取证可重放。

```bash
cd solutions-private/encyclopedia/ch.java-engineering.maven-reproducible-builds
./verify.sh
```

固定验证器全程离线，要求两个测试、零 compile scope JUnit、普通 JAR 无测试 class 和两次哈希一致。私有目录不得被公开章节或 starter 引用。
