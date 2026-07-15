# Week 01 深度教学包：Java 程序结构、I/O、类型、方法与 JUnit

本包对应 [Week 01 周计划](../../weeks/week-01.md)。目标是从现有 `OrderAmountCalculator` 建立 Java 最小可执行模型；条件、循环和数组不作为本周考核主体，留到 Week 02。

## 文件导航

| 文件 | 用途 |
| --- | --- |
| [concepts.md](./concepts.md) | 程序结构、控制台 I/O、类型、运算、方法和测试反馈 |
| [labs.md](./labs.md) | 从完整可运行代码到 CLI 金额计算器 |
| [assessment.md](./assessment.md) | 无 AI 综合题；考试时只打开此文件 |
| [answers.md](./answers.md) | 提交后批改与参考实现 |
| [interview.md](./interview.md) | 一次一题的基础追问 |

## 前置证据

- `java -version`、`mvn -v`、IDE 使用同一 JDK 25；
- 能运行 `mvn test` 并读文件/行号/expected/actual；
- G0 计时桥接完成；
- 当前工程路径和包名清楚。

## 15—18 小时映射

| 块 | 时间 | 对应材料 |
| --- | ---: | --- |
| 程序结构与 I/O | 3h | concepts 1—3；Lab 1—2 |
| 类型、运算与转换 | 3h | concepts 4—5；Lab 3 |
| 方法与按值传递 | 2—3h | concepts 6；Lab 4 |
| JUnit 与反馈分类 | 2—3h | concepts 7；Lab 5 |
| 项目增量 | 3—4h | Lab 6 |
| 独立改动、复述、复盘 | 1—2h | Lab 7 + assessment |

## 学习顺序

1. 逐词阅读一个完整类、经典 `main` 和一个测试；
2. 先预测编译/运行/测试结果，再执行；
3. 把控制台 I/O 与纯计算方法拆开；
4. 每新增一个规则先写例子与边界；
5. 故意制造类型、语法、解析和断言错误；
6. 关闭 AI 完成一个小规则变化并复述链路。

## 本周结果

- 一个可由命令行运行的金额/服务费 CLI；
- production/test 目录和 package 正确；
- 正常、0、非法和溢出/边界测试；
- 一份四类反馈定位记录；
- 一次关闭 AI 的独立修改。

## 通过标准

- 构建与测试证据真实；
- 能写经典 main、基础输入输出和纯计算方法；
- 能解释基本/引用类型第一层差异、整数除法、转换和溢出；
- 能解释 `static` 在当前方法中的作用，不要求完整对象模型；
- 能从日志判断 compile、testCompile、runtime、assertion failure；
- 无 AI 任务达到 75 分且关键项不低于 60%。

## 非目标

- 不系统学习 String API、null 设计、数组和循环；
- 不学习对象构造、继承、集合或 Spring；
- 不把 Maven 命令背诵当 Java 能力。
