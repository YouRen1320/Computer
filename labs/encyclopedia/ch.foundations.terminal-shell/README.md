# 实验：空格路径、字面星号与工作目录

本实验在仓库内提供只读固定夹具。不要改名或删除夹具；不要把命令换成自己的用户目录。先在 `worksheet.md` 写预测，再在本实验目录启动 zsh 并逐条观察。

建议动作：

1. 用 `pwd` 记录实验起点；
2. 用 `cd 'fixture/Factory Care'` 进入含空格目录，再用 `pwd` 复核；
3. 运行 `ruby ../../argv_probe.rb 'pump status.txt' '*' \*`；
4. 分别去掉空格参数的引号、去掉星号的引号，预测参数边界如何改变；
5. 用 `ls` 观察固定名称，但不要用 `rm`、`mv`、`cp` 改夹具；
6. 返回实验根，解释同一相对路径为何随 cwd 改变。

夹具自动检查：

```text
ruby verify.rb
```

预期最后一行是 `terminal-shell lab fixture: PASS`。它只证明固定目录与固定 argv 预言仍成立，不批改你的预测、诊断和复述。
