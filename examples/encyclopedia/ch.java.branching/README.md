# 分支选择观察台

这个最小工程只依赖 JDK 25，用固定输入观察布尔逻辑、`if/else if/else`、短路求值、传统 `switch` 与 `switch` 表达式。它不读取控制台，也不使用数组或集合，因而每次运行都应得到完全相同的结果。

运行前先写下预测：

1. 优先级 1、3、5、0 分别应进入哪条互斥规则；
2. `denominator != 0 && 10 / denominator > 1` 在分母为 0 时会不会求值右侧；
3. 状态 `ASSIGNED` 会由哪个 `switch` 分支处理；
4. 缺少 `default` 的 `String` switch 表达式能否编译。

然后运行：

```bash
cd examples/encyclopedia/ch.java.branching
./verify.sh
```

脚本会确认 Java/Javac 25，编译并逐行核对正例，再要求 `failures/MissingSwitchCase.java.txt` 编译失败。预期失败不是脚本坏了：它证明非穷尽 switch 表达式在 `compile` 阶段被拒绝。

所有 class、标准输出和错误日志都写入 `build/`，不应提交。
