# 实验：把内容、通道与状态分开

本实验只处理固定的 FactoryCare 教学状态，不读取真实工单。先在 `worksheet.md` 写预测，不要先运行；随后在本目录逐步执行合法输入、非法输入、重定向、管道和短路案例。

建议顺序：

1. 画 `stdin`、`stdout`、`stderr` 和退出回执连接图；
2. 预测 `fixtures/valid status.txt` 与 `fixtures/invalid status.txt` 的精确行为；
3. 把两条输出分别重定向到临时结果，紧接着记录状态；
4. 用固定前段失败、末段成功对照默认管道与 `PIPE_FAIL`；
5. 用 `&&`、`||` 证明是否启动右侧，而不是看左侧文字；
6. 每次只注入一个故障并在表中记录第一处可信证据。

夹具自动检查：

```text
ruby verify.rb
```

预期最后一行是 `cli-streams lab fixture: PASS`。验证器只在新临时目录写入，清空继承环境、不加载个人 zsh 配置、不联网。它不批改你的预测、需求变更和 120 秒复述。
