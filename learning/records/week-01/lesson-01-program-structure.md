# Week 01 课次 1：Java 程序结构与启动链

- 日期：2026-07-26
- 模式：老师模式
- 真实学习时间：10 分钟（`0.17` 小时，按两位小数记录）
- 结论：课次 1 已通过；Week 01 尚未完成

## 已验证

- 学习者创建经典入口类 `ProgramStructureDemo`，能够从 IntelliJ 使用 JDK 25 启动，输出 `FactoryCare ready`，退出码为 `0`；
- 学习者使用 `javac --release 25 -encoding UTF-8 -d target/manual-classes` 手工编译源码，生成 `target/manual-classes/com/factorycare/learning/ProgramStructureDemo.class`；
- 学习者使用 classpath 根和完整类名手工启动程序，实际输出与预言一致；
- 使用简单类名启动时真实复现 `ClassNotFoundException`，能区分“找不到类”和编译失败；
- 把 `main` 改为 `start` 后，`javac`仍成功，但 Java 启动器报告找不到 `main`；恢复经典入口后原命令重新成功，退出码为 `0`；
- `System.out` 与 `System.err` 分别重定向到 stdout/stderr 文件，内容为 `FactoryCare ready` 与 `FactoryCare diagnostic`；
- 最终复述能正确解释 package、简单类名、完整类名、classpath 映射、两类启动错误和两个输出流。

## 纠正过的误区

- `ProgramStructureDemo`是简单类名，完整类名还包含 package；
- `java -cp ... 完整类名`不接收 Java 源码，而是启动 JVM 装入已有 class；
- 完整类名是逻辑名称，不是文件地址；classpath 根与完整类名共同映射到 class 文件；
- `ClassNotFoundException`表示类装入失败；“找不到 main”表示类已找到但入口缺失；
- stdout 与 stderr 默认都连接终端，但可以用 `>` 和 `2>`独立重定向。

## 自动复验

课程结束后重新运行 `mvn clean test`：3 个正式源码编译成功；2 个 JUnit 测试通过，`BUILD SUCCESS`。

## 未验证与下一步

- 本课不是无 AI 考试，也不产生 Week 01 验收分；
- 尚未学习变量、作用域、基本/引用类型、字面量、转换、溢出、控制台输入、方法深入和本周独立任务；
- 下一步进入变量、作用域、基本类型、字面量与输出表达式。
