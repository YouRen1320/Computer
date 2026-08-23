# 隔离解析：终端、Shell、命令与引用

完成公开练习并保存预测后再阅读。

## A

终端负责输入与显示，zsh 读取字符并按语法形成命令名和参数，命令只看到解析后的 argv。提示符是 Shell 展示“可以输入”的界面文字；照抄提示符会把无关字符送回解析器。

## B

相对路径必须绑定 cwd。从 `/practice` 解释时目标是 `/practice/Factory Care/pump status.txt`；从 `/practice/Factory Care` 解释同一文本会错误尝试 `/practice/Factory Care/Factory Care/pump status.txt`。先用 `pwd` 观察 cwd，再核对参数边界和实际树，而不是创建同名副本。

## C

- `alpha beta`：两个参数；
- 未引用 `Factory Care`：两个参数；
- 单引号、双引号或转义空格：一个值为 `Factory Care` 的参数；
- 引用 `'*'` 与转义 `\*`：一个值为 `*` 的参数。

引号字符本身通常不进入 argv，它们指导 Shell 解析。

## D

`*.txt` 在固定目录展开为两个 `.txt` 名称；`'*'` 与 `\*` 都是字面星号；未引用 `literal*.note` 会匹配名称 `literal*.note`，但得到相同可见文字并不能证明“没有展开”，要改变固定夹具或用无匹配案例辨别阶段。本章不把 glob 当正则。

## E

故障发生在命令运行前的 Shell glob 阶段。第一处可信观察是 argv 或 zsh 对无匹配模式的诊断。若业务需要把模式文字交给程序，应引用或转义；若业务需要 Shell 展开，就必须明确零个、一个和多个匹配的合同。添加偶然文件只掩盖隐含前提。

## F

目录参数使用 `'incoming work orders'` 或 `incoming\ work\ orders`；字面星号文件名整体引用。至少保留普通、空格、字面 `*` 三种 argv 预言，并从固定 cwd 复跑。
