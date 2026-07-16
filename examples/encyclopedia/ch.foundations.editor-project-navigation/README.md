# 示例：用路径角色和符号关系导航

`sample-project/` 是一个故意很小的 FactoryCare Java 目录模型。它同时包含生产源码、测试引用与 `target/generated-sources/` 中的同名派生文件，目的是训练导航，不是提前教授 Java 语法或调试器。

先阅读项目树并预测：

1. 项目根标记在哪里；
2. `DeviceStatusFormatter` 有几个同名候选；
3. 哪个文件是规范定义，哪个是测试引用，哪个不能手工修改；
4. 只把 `sample-project/src/` 当根时会丢失什么。

然后在本目录执行：

```text
/usr/bin/ruby --disable-gems verify.rb
```

验证器会复制样例到全新临时目录，只通过固定 `/usr/bin/ruby` 与 `/bin/zsh -f` 观察路径；它不读取个人 shell 配置、不联网、不修改样例和真实项目。最后一行应为：

```text
editor navigation example: PASS
```

其中两条 `expected failure` 是受控边界：把 `src/` 当根时找不到根标记；把生成副本当规范源码时角色断言失败。它们被精确观察后，验证器整体仍以 0 结束。
