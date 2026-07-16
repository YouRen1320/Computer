# 练习：Java 程序结构

这些题按“预测 → 模仿 → 修改 → 故障 → 独立构建”排列。先把答案写在纸上或自己的学习记录中，再运行代码。不要先搜索答案目录。

## 1. 预测

阅读下面的源码，不运行：

```java
package com.factorycare.learning;

class StructurePrediction {
    public static void main(String[] commandLineArguments) {
        System.out.println("A");
        {
            // This comment does not print B.
            System.out.println("C");
        }
    }
}
```

回答：

1. 标准输出有几行，逐行是什么？
2. `commandLineArguments` 是关键字、字面量还是标识符？
3. 哪些分号是语句的一部分？哪些右花括号分别结束嵌套块、main 块和 class 块？
4. 如果删除注释，class 文件路径和运行输出是否应改变？为什么？

## 2. 模仿

不复制正例，从空文件写一个 `InspectionConsole.java`：

- package 为 `com.factorycare.learning`；
- 有一个 class 和传统 main 入口；
- main 内包含一个嵌套块；
- 两条语句分别输出 `inspection` 与 `ready`；
- 至少使用两种注释形式。

先写预期 class 路径和输出，再编译运行。

## 3. 修改需求

在第 2 题的基础上完成三次小改动，每次都重新编译：

1. 只把 main 参数名改为 `arguments`；
2. 只调整缩进和空行；
3. 只修改第二个字符串字面量为 `verified`。

分别说明哪些改动影响运行输出、哪些只影响人类阅读、哪些会产生新的 class 文件内容但保持相同类名。

## 4. 故障诊断

在自己的副本中依次制造以下故障，不要一次制造多个：

1. 把 class 名改成 `3InspectionConsole`；
2. 删除第一条输出语句末尾的分号；
3. 删除 main 的右花括号；
4. 把 package 改成 `com.factorycare.wrong`，但仍按原完整类名运行。

对每次实验记录：失败阶段、退出码、第一条可信日志、你实际修改的原因、修复后的重新运行结果。注意第 4 项在“直接编译单文件”时可能编译成功，却会在按原类名启动时失败；解释它与实验脚本中 `-sourcepath` 编译失败场景的差异。

## 5. 关闭 AI 独立构建

限时 20 分钟，从空目录创建 `RepairIntake.java`，要求：

- 文件路径、package 和 class 名相互匹配；
- 传统 main 入口的每个部分都能口述；
- 含 `//` 与 `/* ... */` 注释；
- 含一个额外嵌套块；
- 恰好输出 `repair intake`、`FactoryCare`、`ready` 三行；
- 用 `javac --release 25 -encoding UTF-8 -d out ...` 编译；
- 用完整类名运行；
- 主动制造并修复一次括号错误。

提交物是源码、命令、退出码、实际输出和 120 秒复述录音/口述记录。评分重点不是背诵关键字，而是能在日志中找到第一个可信位置并独立恢复绿色结果。

## 自检边界

- 你可以使用 JDK 官方文档和本章速查表。
- 独立题开始后不要让 AI 生成源码或解释错误；若使用了 AI，就把本次标记为练习而非独立验收。
- 公开题目不附答案。完成尝试后由老师按提交物批改，避免把“看懂答案”误当作会写。
