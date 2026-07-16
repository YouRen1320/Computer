# 值、变量、基本类型与输出：可运行正例

这个项目只依赖 JDK 25 和 Maven。`DeviceSnapshot` 展示本章正式教授的内容；`FieldDefaultBoundary` 只用于观察“字段有默认值、局部变量没有可直接读取的默认值”这一边界，不要求在本章独立设计字段。

## 先预测

运行前打开 `DeviceSnapshot.java`，逐项写下：

1. 9 个业务变量各自的类型和值；
2. `statusText` 最后输出哪段文本；
3. 两个代码块为什么都能声明 `displaySection`；
4. `print`、`println` 和 `printf` 分别在哪一处结束当前行。

## 构建并运行

```bash
mvn clean package
java -cp target/classes com.factorycare.learning.DeviceSnapshot
```

机器核对输出：

```bash
java -cp target/classes com.factorycare.learning.DeviceSnapshot > target/actual-output.txt
diff -u expected-output.txt target/actual-output.txt
```

`diff` 没有输出且退出码为 `0`，表示实际文本与预期逐字一致。`BUILD SUCCESS` 只证明编译成功，不能替代这一步。

观察字段默认值边界：

```bash
java -cp target/classes com.factorycare.learning.FieldDefaultBoundary
```

预期为：

```text
ticketCount=0, enabled=false, note=null
```

不要把这个结果套到 `main` 中声明的局部变量上；读取未明确赋值的局部变量会在编译期失败。
