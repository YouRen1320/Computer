# 表达式观察台

这个最小工程只依赖 JDK 25。它把“看起来应该如此”的猜测变成可重复输出，并把三种故障当作预期证据：除零、误用非短路 `&`、`int` 乘法溢出。另有一个单独的窄化转换编译失败样例。

在运行前，先把下面各项写在纸上：

1. `2 + 3 * 4` 和 `(2 + 3) * 4` 的值；
2. `5 / 2` 赋给 `double` 后的值；
3. `1_073_741_824 * 2` 使用 `int` 运算后的值；
4. `false && (10 / zero > 1)` 是否会抛异常；
5. `"sum=" + 1 + 2` 的结果。

然后运行：

```bash
cd examples/encyclopedia/ch.java.expressions-conversions
./verify.sh
```

脚本会：

- 确认当前 `javac` 是 25；
- 用 `javac --release 25` 编译可运行源码；
- 逐行核对正常输出；
- 要求三个故障进程非零退出且包含 `ArithmeticException`；
- 要求窄化转换源码编译失败，并在日志中出现 `possible lossy conversion from long to int`。

所有临时 class 和日志写入 `build/`，该目录不应提交。
