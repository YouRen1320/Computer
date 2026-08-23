# 示例：三条标准流与退出状态

`stream_probe.rb` 实现一个刻意缩小的命令行合同：从 `stdin` 读取一个状态，允许 `ASSIGNED` 与 `IN_PROGRESS`；成功只写 `stdout` 并返回 0，空输入与非法输入只写 `stderr` 并分别返回 64、65。

在本目录执行：

```text
ruby verify.rb
```

验证器会在全新的系统临时目录复制探针并创建固定输入，核对：

- 合法、非法、空输入的两条输出和退出状态；
- `<`、`>`、`>>`、`2>` 的固定结果；
- 默认 zsh 管道如何被末段零掩盖；
- `PIPE_FAIL` 如何暴露前段 65；
- `&&` 与 `||` 的短路行为。

最后一行必须是 `cli-streams verification: PASS`。验证器只调用绝对路径 `/usr/bin/ruby`、`/bin/zsh` 和系统基础工具，使用 `zsh -f`、清空继承环境，不加载个人配置，不联网，不读取用户目录，也不在临时目录外写文件。输出里的 expected failures 是被精确核对的受控反例。
