# 练习：终端、Shell、命令与引用
+
## 提交文件与同一验证入口

本目录已提供可编辑的 `submission.md`。先保留五个占位行运行 `./verify.sh`，确认得到精确的教材预期红；再把每个 `TODO：请替换本行。` 改成自己的预测、实验、失败证据、修复复跑和复述。

- `0` + `EXERCISE_GREEN`：五个栏目均有内容，机器只确认结构完成；
- `41` + `EXPECTED_RED`：仍是完整的公开 starter；
- `43`：文件缺失、只改了一部分占位行、标题损坏或其他未知状态，需要先读诊断，不能冒充预期红。

`EXERCISE_GREEN` 不批改答案含义，也不证明掌握；正文结论、命令输出与复述仍需教师或独立真人语义复核。

先保存答案和预测，再看隔离解析。除题目给出的固定练习目录外，不对真实用户目录做任何修改。

## A. 画边界

画出“键盘输入 → 终端 → zsh 解析 → 命令收到 argv → 终端显示”的最小图。指出窗口、Shell 和命令分别是什么，说明提示符为什么不是命令的一部分。

## B. 工作目录

给定 cwd 为 `/practice`，目录中有 `Factory Care/pump status.txt`。解释 `Factory Care/pump status.txt` 从哪里开始寻找；进入 `/practice/Factory Care` 后，同一个文本会指向什么不同目标？写出不依赖猜测的观察步骤。

## C. 参数预测

对每行写出 `argc` 与每个 `argv`，不要先运行：

```text
ruby argv_probe.rb alpha beta
ruby argv_probe.rb Factory Care
ruby argv_probe.rb 'Factory Care'
ruby argv_probe.rb "Factory Care"
ruby argv_probe.rb Factory\ Care
ruby argv_probe.rb '*'
ruby argv_probe.rb \*
```

## D. glob 边界

固定目录只有 `fan.txt`、`pump.txt`、`literal*.note`。预测 `*.txt`、`'*'`、`\*` 和 `literal*.note` 分别交给命令什么。解释 glob 是 Shell 在命令启动前做的名称匹配，不是正则表达式，也不是命令自己必然实现的功能。

## E. 故障诊断

一条命令在开发者机器“能用”，在空目录失败。已知它依赖未引用的 `*.csv`。写出：故障阶段、第一处可信观察、受目录内容影响的隐含条件、只改变引用方式的修复，以及为什么不能靠“再放一个文件进去”掩盖问题。

## F. FactoryCare 变更

原设备导入目录名为 `imports`，现在改成 `incoming work orders`，其中还可能存在名为 `literal*.csv` 的文件。写出安全的参数传递方案和三组预测：普通名称、空格名称、字面星号名称。不要引入管道或重定向。

## G. 无 AI

关闭 AI，限时 40 分钟完成 A—E；然后用 120 秒解释“引用改变的是 Shell 解析，不是文件内容”。保留一次预测错误，并注明错在 cwd、token、quote、escape 还是 glob。
