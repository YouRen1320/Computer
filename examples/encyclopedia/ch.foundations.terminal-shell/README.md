# 示例：看见 Shell 交给程序的参数

`argv_probe.rb` 不解释 Shell 语法，只把程序最终收到的参数逐项打印出来。固定验证器在系统临时目录创建 `Factory Care/`、两个 `.txt` 文件和一个名称含 `*` 的文件，然后比较以下情况：

- 普通参数；
- 单引号、双引号和反斜杠保护的空格；
- 未引用空格造成的两个参数；
- 引用或转义后的字面 `*`；
- 未引用 `*.txt` 产生的两个匹配名称；
- `cd` 前后的工作目录。

在本目录执行：

```text
ruby verify.rb
```

预期最后一行是 `terminal-shell verification: PASS`。脚本只使用 `/bin/zsh`、`/usr/bin/ruby` 与 Ruby 标准库；它清空继承环境，在新临时目录工作，不读取 shell 配置、用户文件或秘密变量，也不删除临时目录以外的内容。两个“expected faults”是受控反例，不是验证器故障。
