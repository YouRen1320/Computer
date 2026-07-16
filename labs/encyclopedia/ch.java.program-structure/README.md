# 实验：从字符到可启动的 Java 类

## 实验目标

你要独立写出一个普通 Java 编译单元，并用命令证明确认以下事实：

- package 与输出目录层级一致；
- class、main 和两层代码块的括号配对；
- 注释不改变预定输出；
- 字符串字面量所在的输出语句以分号结束；
- 非法标识符、缺分号、括号错位、package/路径不一致四类故障都在编译阶段失败；
- 独立构建的 `RepairConsole` 修复后仍只输出事先写下的两行文本；四个故障夹具修复后则各自保持夹具中原定的单行输出。

## 环境门槛

```bash
javac -version
java -version
```

两者必须是 JDK 25 系列。若不是，暂停实验并回到工具链前置章；不要临时删掉 `--release 25`。

## A. 先验证教材正例

从仓库根目录执行：

```bash
bash examples/encyclopedia/ch.java.program-structure/verify.sh
```

在运行前先写下预测：编译会产生哪个 `.class` 路径、运行命令为什么使用点号而不是斜杠、标准输出有几行。

## B. 独立构建

不要复制教材正例。在一个仓库外的临时目录中创建：

```text
src/com/factorycare/learning/RepairConsole.java
```

必须同时满足：

1. package 是 `com.factorycare.learning`；
2. class 名是 `RepairConsole`；
3. 使用传统 `public static void main(String[] args)` 入口；
4. 同时出现行尾注释和跨行注释；
5. main 内有一对额外花括号形成嵌套代码块；
6. 只有两条输出语句，预定输出分别是 `FactoryCare repair console` 和 `structure verified`；
7. 源码中没有 Token、密码、真实手机号或真实工单信息。

使用以下命令模型，但把 `<临时目录>` 换成你的实际路径：

```bash
javac --release 25 -encoding UTF-8 \
  -d <临时目录>/out \
  <临时目录>/src/com/factorycare/learning/RepairConsole.java

java -cp <临时目录>/out com.factorycare.learning.RepairConsole
```

验收时需出示：源码、编译退出码、生成的 class 路径、运行退出码和两行实际输出。

## C. 故障注入

先逐个预测最先可信的文件与行号，再执行：

```bash
bash labs/encyclopedia/ch.java.program-structure/verify-failures.sh
```

脚本通过 `-J-Duser.language=en -J-Duser.country=US` 让纳入证据的编译器消息稳定为英文，`-J-Dfile.encoding=UTF-8` 固定编译器 JVM 的默认字符集；源码字符集则由 `-encoding UTF-8` 明确指定。理解日志时按“文件 → 行号 → 第一条错误 → 源码插入符”读取。四个目录分别演示：

| 目录 | 注入故障 | 首要观察 |
|---|---|---|
| `illegal-identifier` | class 名以数字开头 | 编译器无法在该位置得到合法标识符 |
| `missing-semicolon` | 输出语句末尾缺 `;` | 日志把错误定位到语句结束处附近 |
| `bracket-mismatch` | class 少一个 `}` | 日志通常在文件末尾报告解析尚未完成 |
| `package-path` | 被依赖源码的声明 package 与期待路径不一致 | `javac -sourcepath` 找到文件后发现其中没有期待的完整类名 |

package/路径故障之所以使用一个固定的 `Launcher` 外壳，是因为“直接把任意路径的单个 `.java` 文件交给 javac”并不一定因目录与 package 不同而失败。实验刻意让编译器通过 source path 按完整名称查找源码，才得到真实、可重复的编译错误。

## D. 修复与回归

不要改测试脚本。把四个故障目录复制到仓库外，再逐个修复。每次只改一个原因，并记录：

1. 修复前的第一条错误；
2. 修改的一个字符或一行；
3. 修复后的编译退出码；
4. 运行输出是否仍等于该工件原先的预言：独立 `RepairConsole` 是两行；每个故障夹具是它自己源码中已有的一行，不能彼此套用。

`package-path` 用例包含教材尚未教授的固定调用外壳，你只需保持它不变并让声明 package 与它期待的完整名称一致；这里不考查方法调用或访问控制。

## 验收清单

- [ ] 教材正例验证退出码为 0。
- [ ] 独立程序从空文件写出，而非复制后改名。
- [ ] 能逐字符指出 package、class、main、两层代码块、字面量和语句边界。
- [ ] 4/4 故障在 `javac` 阶段以非 0 退出。
- [ ] 每个故障日志都包含 `.java:行号` 来源位置。
- [ ] 独立 `RepairConsole` 修复后编译和运行均为 0，且两行输出未漂移。
- [ ] 四个故障夹具逐个修复后编译和运行均为 0，且各自的单行输出未漂移。
- [ ] 能用 120 秒解释“为什么 BUILD/命令成功不等于结构之外的业务功能一定正确”。

文件存在或脚本由 AI 生成不代表学习已通过；验收还需要本人预测、独立构建、故障定位和复述证据。
