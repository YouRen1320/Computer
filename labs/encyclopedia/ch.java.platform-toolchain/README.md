# 实验：从源码到 JVM，并用故障证明阶段边界

## 目标

从 starter 源码独立产出 class，记录工具来源、版本、class 主版本、正常输出和退出码；再分别注入不支持的 release 与错误 classpath，完成“预测—观察—修复—复跑”。

## 规则

- 在本实验目录工作，不修改示例答案；
- 所有生成物放入本实验目录的 `work/`；
- 先写预测，再执行命令；
- 报告不得包含 Token、密码或完整生产环境变量；
- 卡住 20 分钟后可以只向 AI 描述“阶段、命令、第一条错误”，不要让 AI 直接交付整份报告。

## 步骤一：建立证据表

复制 `starter/` 到 `work/`，建立 `work/report.md`：

```markdown
| 项目 | 预测 | 实际 | 证据位置 |
| --- | --- | --- | --- |
| java 路径/版本 | | | |
| javac 路径/版本 | | | |
| 正常编译退出码 | | | |
| class 路径与 major version | | | |
| 正常运行输出/退出码 | | | |
| release 99 退出码/第一条错误 | | | |
| 空 classpath 退出码/第一条错误 | | | |
| 修复后复跑 | | | |
```

## 步骤二：正确编译和运行

你需要自己补全以下占位参数：

```zsh
javac --release __ -d __ __/ToolchainProbe.java
java -cp __ com.factorycare.learning.ToolchainProbe
```

正常预言：

```text
FactoryCare probe READY
```

退出码应为 0。用 `javap -verbose` 记录 major version。

## 步骤三：证明源码修改会产生新 class

把输出改为 `FactoryCare probe JDK 25 READY`。记录修改前后的源码摘要、class 摘要和修改时间；清理输出后重编译。只改源码但不重编译不算完成。

## 步骤四：注入两个故障

1. 把 `--release` 改成 99，记录失败命令、退出码和第一条具体错误，归类为 compile；
2. 恢复正常编译，用空目录作为 `-cp`，记录退出码和第一条具体错误，归类为 JVM 加载。

每次故障后都要恢复正确配置、清理并重跑正常预言。

## 验收

- `java`/`javac` 实际路径与完整版本都有证据；
- 正常编译/运行退出码均为 0；
- class 位于与 package 对应的目录，JDK 25 主版本为 69；
- 修改源码后 class 摘要发生变化，输出精确匹配新预言；
- 两个故障均为非 0，第一条错误和失败阶段分类正确；
- 最终复跑恢复为 0；
- `report.md` 可让另一位读者在空目录复现。
