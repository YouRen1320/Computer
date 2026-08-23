# 示例：在临时环境中证明工具来源

验证器在新系统临时目录创建两个假的工具根 `<TOOL_A>`、`<TOOL_B>`，不会调用或修改真实 Java、Maven、Homebrew、Shell 配置。它证明：

- 子命令临时覆盖不会反向修改父 Shell 环境；
- 普通 Shell 变量与 `export` 后的子进程可见性不同；
- `type -a`、`command -v` 与 PATH 先后顺序一致；
- 绝对入口可以绕过 PATH 选择；
- `JAVA_HOME=B`、PATH 首个 `java=A` 时，模拟 Maven 可使用 B；
- 在单个子会话同时对齐 PATH/JAVA_HOME 后，二者都使用 B；
- PATH 没有目标时得到受控 127 预期失败。

运行：

```text
ruby verify.rb
```

最后一行必须是 `environment-tool-resolution verification: PASS`。脚本使用固定 `/bin/zsh -f`、`/usr/bin/ruby`，清空继承环境，不读取个人启动文件、不联网、不在临时目录外写入。临时绝对路径在比较时替换为 `<TMP>`。
