# 练习：JDK、JVM、编译与运行

先把答案写进自己的学习记录，再运行或查看隔离解析。

## A. 预测

1. `javac --release 25 -d out src/com/example/App.java` 成功后，若源码声明 `package com.example;`，最可能生成哪个路径？
2. `java -cp out com.example.App` 中，`out` 是 class 文件本身还是搜索根？
3. 只有 `javac` 成功时，会不会出现程序的 `System.out` 输出？为什么？
4. `JAVA_HOME` 临时改为 JDK 21，但 `PATH` 第一项仍是 JDK 25 的 `bin`，直接运行 `java -version` 最可能看到哪一个？还需要什么证据才能确认？

## B. 日志分类

给每段日志标注 `shell/compile/JVM加载/程序运行`，写出首个可信证据和下一条检查命令。

```text
zsh: command not found: javacc
```

```text
error: release version 99 not supported
```

```text
Error: Could not find or load main class com.example.App
Caused by: java.lang.ClassNotFoundException: com.example.App
```

```text
Exception in thread "main" java.lang.IllegalStateException: device missing
    at com.example.App.main(App.java:8)
```

## C. 动手修改

1. 从空目录写一个固定输出 `FactoryCare JDK 25 READY` 的源文件；
2. 编译到 `out/classes`，记录源文件与 class 文件的 SHA-256；
3. 用显式 classpath 运行，断言精确输出和退出码；
4. 修改输出文本，证明旧 class 不会自动变化，再重编译验证新摘要。

## D. 故障与恢复

1. 注入错误 `--release`，保存 stderr 和退出码；
2. 注入错误 classpath，保存 stderr 和退出码；
3. 对每个故障只改一个条件，恢复后重跑同一个正常预言；
4. 写出为什么不能只用最后一行 `BUILD FAILURE` 作为根因。

## E. 需求变更

产品把固定输出从 `FactoryCare JDK 25 READY` 改成两行：第一行输出应用名，第二行输出 `READY`。先更新预言，再修改源码和验证命令。报告要能区分“编译成功但输出仍旧”与“输出满足新需求”。

## F. 关闭 AI 独立任务

在一个新的临时目录中，仅凭本章速查表完成：工具取证、编译、class 版本检查、运行、两种故障、修复复跑。限时 30 分钟，最后用 120 秒口述整条运行链。
