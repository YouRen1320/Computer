---
schema_version: 2
edition: 2026.2-draft
id: ch.foundations.cli-streams-exit-codes
title: stdin、stdout、stderr、管道与退出码
responsibility: 教授命令行进程的数据通道和成功失败协议，不扩展到网络套接字或应用日志框架
volume: '00'
order: 5
level: L1
status: drafting
path: book/volume-00-computer-foundations/chapters/ch.foundations.cli-streams-exit-codes.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.computer-process-model
version_surfaces: []
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释stdin、stdout、stderr、管道与退出码的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - cli-streams
  - process-result
  covers_topics:
  - shell.stdin-stdout-stderr
  - shell.redirect
  - shell.pipeline
  - shell.exit-code
  - shell.short-circuit
  - shell.failure-propagation
  uses_capabilities:
  - foundation.os-process-memory
  - foundation.files-path-encoding
  - foundation.shell-command-stream
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：在含空格参数的 shell 命令中正确引用输入，组合读取 stdin、分别写 stdout/stderr、经管道传递并返回成功/失败退出码的三段实验
  covers_topic_groups:
  - cli-streams
  - process-result
  covers_topics:
  - shell.stdin-stdout-stderr
  - shell.redirect
  - shell.pipeline
  - shell.exit-code
  - shell.short-circuit
  - shell.failure-propagation
  uses_capabilities:
  - foundation.os-process-memory
  - foundation.files-path-encoding
  - foundation.shell-command-stream
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入参数未引用、stderr 被重定向丢失、管道前段失败却被末段 0 掩盖，定位 token/stream/exit 三类边界并修复
  covers_topic_groups:
  - cli-streams
  - process-result
  covers_topics:
  - shell.stdin-stdout-stderr
  - shell.redirect
  - shell.pipeline
  - shell.exit-code
  - shell.short-circuit
  - shell.failure-propagation
  uses_capabilities:
  - foundation.os-process-memory
  - foundation.files-path-encoding
  - foundation.shell-command-stream
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# stdin、stdout、stderr、管道与退出码

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《CPU、内存、磁盘、程序与进程》](ch.foundations.computer-process-model.md)：独立完成标准流与重定向、退出与失败前，必须先具备「CPU、内存、磁盘、程序与进程」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

在终端里运行一个命令后，屏幕出现几行文字，人们常说“程序把结果打印出来了”。这句话在日常交流中勉强可用，却不足以诊断真实故障：文字来自程序的正常结果还是诊断信息？程序是否读取了键盘输入？屏幕上没有报错是否代表成功？前一个命令失败以后，后一个命令为什么仍然运行？自动化系统又凭什么判断这一轮可以继续？

本章建立命令行程序最基础的输入、输出与结果合同。一个进程通常拥有三个约定好的标准流：标准输入 `stdin`、标准输出 `stdout`、标准错误 `stderr`；结束时还会把一个整数退出状态交还给父进程。Shell 可以把流连接到终端、文件或另一个进程，也可以依据退出状态决定是否执行下一条命令。文字内容与退出状态是两条不同证据，缺少任意一条都可能产生误判。

本章只学习可观察的基础规则，不把 Shell 变成第二门编程语言。我们不会编写复杂脚本、函数、循环或任务调度，也不会把标准流扩展到网络套接字、应用日志框架和分布式追踪。所有实验都在固定临时目录里运行，使用无破坏性的 Ruby 探针和 `/bin/zsh -f`，避免读取个人配置、覆盖真实项目文件或把秘密环境变量写入报告。

## 学完后你必须能做什么

完成正文、示例和实验后，你应当能够：

1. 用自己的话区分 `stdin`、`stdout`、`stderr` 与退出状态，而不是把它们统称为“控制台输出”；
2. 说明终端只是标准流的一种当前连接对象，重定向不会改变业务算法本身；
3. 在运行前预测固定输入会进入哪条流、每条流包含什么、退出状态是多少；
4. 使用基础的 `<`、`>`、`>>`、`2>` 完成受控输入与分流，知道覆盖与追加的差异；
5. 说明管道连接的是前一进程的 `stdout` 与后一进程的 `stdin`，不会自动传递 `stderr`；
6. 解释为什么默认管道状态可能只反映最后一段，并用 zsh 的 `PIPE_FAIL` 选项暴露前段失败；
7. 解释 `&&`、`||` 的短路条件，区分它们与无条件顺序执行；
8. 从日志中识别“内容正确但退出非零”“错误文字在 stdout”“前段失败被末段零掩盖”等合同错误；
9. 为 FactoryCare 的一个只读工单筛选命令写出输入、正常结果、诊断和退出状态合同；
10. 审查 AI 生成的命令，指出它会覆盖哪些文件、会丢失哪条流、依据哪一个状态判断成功。

掌握标准不是背下四个符号。你需要独立完成一次预测、一次构建、一次受控破坏、一次修复复跑，并能在 120 秒内解释“可见文字”和“进程结果”为什么不能互相代替。

## 零基础补救：进程开始和结束时发生了什么

上一章已经把程序与进程分开：磁盘上的程序是静态文件，运行后才成为拥有状态的进程。父进程启动子进程时，会为它准备参数、工作目录、环境以及输入输出连接；子进程运行期间读取输入、写出结果；结束时把状态交还父进程。交互 zsh 启动普通命令时，zsh 是父进程，命令是子进程。

在最简单的终端场景里，可以画成：

```text
键盘 ──stdin──> 命令进程 ──stdout──> 终端正常显示
                         └─stderr──> 终端诊断显示
命令进程结束 ──exit status──> zsh
```

因为 `stdout` 和 `stderr` 默认都可能显示在同一个终端窗口中，肉眼常看不出它们的来源。颜色也不是可靠证据：终端主题、程序格式和 IDE 面板都可能改变颜色。要证明来源，应使用受控重定向分别捕获，而不是凭“红色像报错”猜测。

退出状态也不是屏幕上一行普通文字。它是进程终止合同的一部分，由父进程接收。程序完全可以在 `stdout` 写出 `SUCCESS` 却以非零结束，也可能一句话不写但以零结束。这样的设计是否合理取决于程序合同，但调用者必须分别观察文字与状态。

## 直觉模型：三条传送带和一张回执

把进程想成一个检验工作台。`stdin` 是送入待检数据的传送带，`stdout` 是送出合格业务结果的传送带，`stderr` 是送出无法完成、输入非法或运行异常等诊断的传送带。退出状态是一张单独回执，告诉上游“本次是否按照合同完成”。

这个比喻有四个重要边界：

- 传送带承载字节流，不天然知道“工单”“JSON”或“整数”；格式由双方合同解释；
- `stderr` 名称中的 error 不表示它只能写致命错误，程序也可能把警告或进度写进去；
- `stdout` 名称中的 standard 不保证内容正确，程序缺陷同样能产生错误业务数据；
- 退出状态只是一枚有限的整数信号，不包含完整原因，原因通常还要结合诊断内容和上下文。

因此，可靠自动化一般同时约定：什么输入可接受、成功时 `stdout` 的格式、失败时 `stderr` 的诊断边界、每类结果对应的退出状态。只约定“屏幕会显示什么”是不完整接口。

## stdin：程序从哪里读取输入

### 默认连接到终端并不等于永远来自键盘

交互运行时，程序的标准输入常连接到终端，所以你敲入的字符会被程序读取。但 Shell 可以把一个文件或前一进程的输出接到同一入口。对程序而言，它仍然读取 `stdin`；改变的是入口连接，不一定是程序代码。

配套探针接受一行设备状态：

```text
printf 'IN_PROGRESS\n' | ruby stream_probe.rb
```

这里 `printf` 把文本写到自己的 `stdout`，管道把它连接给 Ruby 探针的 `stdin`。探针读取到一行后验证状态。合法时，它在 `stdout` 写规范化结果并返回零；非法时，它在 `stderr` 写诊断并返回非零。

### EOF 是“输入结束”，不是一个普通字符

流需要某种方式表示没有更多数据。文件读到末尾、管道写端关闭或终端发出相应结束信号时，读取方会观察到 EOF。EOF 不是业务文本中的三个字母，也不保证前面一定有换行。初学实验要分别考虑：正常一行、空输入、最后一行没有换行、额外多行。

不要写出“程序会一直等，所以它坏了”的武断结论。它可能按合同等待尚未结束的 `stdin`。诊断时先确认输入端是否仍然打开、程序期望多少数据，再判断是阻塞、输入未结束还是逻辑错误。

### `<` 把文件作为标准输入

下面让探针从固定文件读取，而不是由键盘输入：

```text
ruby stream_probe.rb < 'fixtures/valid status.txt'
```

zsh 先打开文件，把该文件接到子进程的 `stdin`，再启动命令。如果路径错误或当前进程没有读取权限，重定向阶段就可能失败，目标程序甚至尚未按预期运行。路径含空格仍要遵守前章引用规则；重定向不会替你修复参数边界。

## stdout：可供下一环节消费的正常结果

`stdout` 通常承载程序的主要机器可消费结果。例如，一个设备筛选命令可以把符合条件的设备 ID 每行写一个。人能在终端看到它只是附带效果；更重要的是下一条命令或文件捕获可以在不解析提示语的情况下消费它。

如果程序把“正在连接数据库……”和设备 ID 混在同一个 `stdout`，人眼可能觉得友好，管道消费者却无法区分进度与数据。基础原则是让 `stdout` 的业务格式稳定，把诊断、警告和进度放到合适的诊断通道。后续应用日志章节会讨论更复杂方案，本章只守住这条边界。

### `>` 覆盖目标文件

```text
ruby stream_probe.rb < input.txt > result.txt
```

Shell 会为 `stdout` 打开 `result.txt`。若文件已经存在，通常会截断后从头写入；这意味着即使目标程序随后失败，原文件也可能已经被清空。不要在真实配置、源码或证据文件上试验。先在固定临时目录确认目标路径和覆盖语义。

`>` 只改变 `stdout` 的去向。若程序同时写 `stderr`，诊断仍会连接到原来的终端，除非另行重定向。看到终端还有文字并不能证明 `>` 没生效，那些文字可能来自 `stderr`。

### `>>` 追加不是“更安全的覆盖”

`>>` 通常把后续 `stdout` 加到文件末尾。它保留旧内容，却带来重复、顺序和历史污染问题。验证结果若每次追加，第二次运行就可能与第一次不一致；旧错误也可能被误认为本轮输出。什么时候覆盖、什么时候追加必须由证据生命周期决定，不能把 `>>` 当作不会丢数据的万能选择。

### 不要用“文件存在”代替输出预言

空文件也存在，旧文件也存在，失败前被创建的文件仍存在。验证 `stdout` 重定向结果至少要核对本轮退出状态、内容、条目数量或摘要，并证明文件来自本轮运行。后续测试章节会把这些预言形式化。

## stderr：诊断通道不是失败本身

`stderr` 让程序在主要结果另行传递时仍能报告诊断。例如：

```text
ruby stream_probe.rb < bad.txt > result.txt 2> diagnostic.txt
```

这里正常结果与诊断被分开。`2>` 中的 `2` 是标准错误常用文件描述符编号；标准输入、标准输出、标准错误通常对应 0、1、2。零基础阶段只需理解这个固定映射和分流作用，不需要学习进程文件描述符表的全部系统调用细节。

一个常见错误是把业务错误写进 `stdout`，同时返回零。人能看到“invalid status”，自动化却会把它当作可继续消费的正常结果。另一个错误是仅因 `stderr` 非空就断言失败：某些工具会把警告或版本信息写到 `stderr`，最终仍返回零。正确判断必须依据目标工具合同，同时记录两条流和退出状态。

`2>/dev/null` 会丢弃诊断。它可能让演示界面变安静，却会删除定位故障的重要证据。本课程的诊断训练禁止用它掩盖未理解的错误。若日志中确有预期噪声，应先明确来源和过滤规则，再考虑如何处理，而不是把整个诊断通道扔掉。

## 退出状态：父进程收到的结果信号

### 零与非零的基础约定

在 POSIX Shell 使用习惯中，零表示成功，非零表示未成功。不同程序会为不同失败原因选择不同非零数值；数值含义必须查该程序文档，不能把所有 `1`、`2`、`127` 背成跨工具统一字典。

在 zsh 中，刚结束的前台命令状态可通过 `$?` 观察：

```text
ruby stream_probe.rb < input.txt
echo $?
```

必须紧接着观察，因为下一条命令结束会覆盖 `$?`。如果先运行 `pwd` 再 `echo $?`，看到的是 `pwd` 的状态，不再是探针状态。自动验证器通常直接通过进程 API 获取子进程状态，避免这个观察窗口被意外覆盖。

### 状态与文字的四象限

| 可见内容 | 退出状态 | 可能含义 | 是否足以判定 |
| --- | ---: | --- | --- |
| 正常结果 | 0 | 常见成功合同 | 仍要核对内容预言 |
| 诊断文字 | 非 0 | 常见失败合同 | 仍要核对失败类型 |
| 正常文字 | 非 0 | 部分结果后失败，或合同设计异常 | 不能只看文字 |
| 无文字 | 0 | 静默成功 | 不能因安静判失败 |

还有“诊断文字但状态为 0”的组合，它可能是警告，也可能是错误地报告成功。调用者应依赖明确合同，而不是把自然语言中的 `ERROR` 当作唯一信号。

### 预期失败不是验证器失败

故障练习会故意传入非法状态，预言探针返回非零并只写 `stderr`。当这一预言成立时，整个验证器应报告 PASS，因为它证明失败合同工作正常。若把所有非零都当作测试器失败，就无法验证错误路径；若忽略非零，又会把意外失败吞掉。验证器必须显式区分“预期的子命令失败”和“验证器自身未满足预言”。

## 重定向的执行顺序与安全边界

在简单命令中，zsh 解析出重定向并准备连接，然后启动或执行命令。由此得到两个诊断规则：

1. 重定向目标打不开时，错误可能来自 Shell，目标程序没有产生业务输出；
2. 输出文件可能在业务逻辑完成前就被创建或截断，存在文件不证明命令成功。

Shell 还支持把流合并，例如常见的 `2>&1`。它表达“让标准错误去标准输出当前指向的位置”，顺序会影响结果。这个机制在阅读构建日志时不可避免，但零基础实验优先使用 `>result.txt 2>diagnostic.txt` 分开捕获。只有在确实需要一个合并、保序并接受交错的通道时，才使用合并；不要机械追加到每条命令。

重定向目标路径也属于不可信输入边界。AI 给出 `> report.txt` 时，先确认 cwd、目标是否已存在、是否允许覆盖、失败后如何保留旧证据。固定验证器只在新建临时目录写入，并在退出时由标准库清理，不接触用户主目录。

## 管道：连接两个进程，不是把命令文字粘起来

### `|` 连接 stdout 与 stdin

```text
printf 'IN_PROGRESS\n' | ruby stream_probe.rb
```

zsh 创建管道并启动两侧进程。左侧 `printf` 的 `stdout` 成为右侧探针的 `stdin`。左侧 `stderr` 仍按自己的连接发送，不会因为 `|` 自动混进右侧输入。右侧的 `stdout` 和 `stderr` 也各自保留后续连接。

管道中的进程可能并发运行：右侧可以边读取边处理，左侧也可能因右侧提前退出而无法继续写。不要把管道想成“左边完整生成文件，结束后右边再开始”。本章不深入缓冲、信号和并发调度，只要求不把显示顺序误当成严格执行顺序。

### 默认管道状态可能掩盖前段失败

在 zsh 的默认规则下，管道整体状态通常取最后一个命令的状态。于是：

```text
/bin/sh -c 'exit 7' | /usr/bin/true
echo $?
```

可能得到 0。前段明确失败，末段 `true` 成功，默认管道回执只反映末段。若把该状态交给 CI，就会产生假成功。

zsh 提供 `PIPE_FAIL` 选项：

```text
setopt PIPE_FAIL
/bin/sh -c 'exit 7' | /usr/bin/true
echo $?
```

启用后，只要管道某一段非零，整体不会被末段零轻易掩盖；zsh 会使用符合其文档规则的非零状态。这里的教学重点不是背某个数字，而是明确失败传播策略。固定验证器用 `/bin/zsh -f` 排除个人配置，分别证明默认行为与 `PIPE_FAIL` 行为。

### 管道传数据，参数仍由 Shell 解析

下面路径仍须引用：

```text
cat 'Factory Care/status.txt' | ruby stream_probe.rb
```

管道不会修复未引用空格。若写成 `cat Factory Care/status.txt`，故障首先发生在 token/argv 边界，而不是 `stdin` 内容边界。诊断时按实际顺序寻找第一处可信变化：Shell 参数 → 重定向/管道连接 → 程序输入解析 → 输出内容 → 退出状态。

## `&&`、`||` 与短路执行

管道把数据连接起来，`&&` 与 `||` 则依据前一命令状态决定是否执行后一命令：

- `A && B`：只有 A 成功（状态为零）才执行 B；
- `A || B`：只有 A 未成功（状态非零）才执行 B；
- `A ; B`：B 通常无条件在 A 之后执行，不传播“只在成功时继续”的意图。

安全演示：

```text
/usr/bin/true  && printf 'continued\n'
/usr/bin/false && printf 'must-not-run\n'
/usr/bin/false || printf 'recovered\n'
```

短路判断只看退出状态，不阅读前一条命令的中文或英文输出。如果程序错误地在失败时返回零，`&&` 仍会继续；如果成功完成却返回非零，`&&` 会阻止后续步骤。调用者与被调用者必须共同遵守状态合同。

不要把 `A || B` 自动理解为“异常处理”。B 成功后，整个列表最终看起来可能成功，原故障也可能被掩盖。恢复步骤应说明它是否真的恢复业务结果、是否仅记录诊断、是否需要重新返回失败。本章只观察短路，不提前教授复杂脚本控制流。

## 一条命令的完整执行顺序

面对含参数、重定向和管道的基础命令，可以按下面顺序推理：

1. zsh 读取字符并按引用规则形成命令、参数与操作符；
2. glob 等展开可能改变 argv；
3. Shell 准备文件、管道以及各标准流连接；
4. Shell 找到并启动相应命令进程；
5. 进程从 `stdin` 读取字节，按自己的格式规则解析；
6. 进程向 `stdout` 写业务结果，向 `stderr` 写诊断；
7. 每个进程结束并返回自己的状态；
8. zsh 按单命令、管道或短路列表规则计算下一步是否执行；
9. 父进程或验证器比较实际内容、流来源和状态预言。

若第 1 步空格参数已经被拆成多个 argv，就不应把后续“输入非法”归咎于管道。若第 3 步输出路径打不开，程序的业务解析可能尚未开始。若第 6 步内容正确但第 7 步非零，就要检查部分输出和失败合同。按边界定位比凭最后一行猜测稳定得多。

## 故障诊断：四个常见假象

### 假象一：屏幕有正确文字，所以成功

程序可能先写出一部分正常数据，随后校验失败并返回非零。第一处可信证据是分开的 `stdout`、`stderr` 与实际状态，而不是最后看到的某一行。修复后复跑同一输入，并确认三项同时符合合同。

### 假象二：屏幕没有红字，所以没有错误

错误可能被 `2>` 写入文件、被错误地写入 `stdout`，或者完全没有诊断但状态非零。先查看连接图和状态。不要为了“看见错误”删除重定向后宣称问题消失；那只改变了观察位置。

### 假象三：管道整体是 0，所以每一段都成功

默认管道状态可能来自末段。用固定的前段 `exit 7` 与末段 `true` 复现，再启用 `PIPE_FAIL` 对照。修复不是在日志末尾写一句“前段可能失败”，而是让调用合同真实阻止假成功。

### 假象四：生成了 result.txt，所以程序完成

Shell 可能先创建文件，程序随后失败；文件也可能来自上次运行。先记录运行前状态，在隔离目录执行，获取本轮退出状态，再核对内容预言。必要时用临时文件加成功后的明确替换策略，后续工程章节再系统学习原子发布。

### 最小诊断记录

每次故障保留：固定输入、完整 argv 预言、三条流的连接图、实际 `stdout`、实际 `stderr`、每段状态、管道传播策略、只改一项的修复、原输入复跑结果以及仍未验证的边界。不要只写“加了 pipefail 就好了”，因为它没有说明哪一段失败、为什么之前被掩盖。

## 安全：流操作也会造成真实数据损失

### 覆盖前确认对象

`>` 可能在命令完成前截断文件。执行前先确认 cwd、目标绝对含义、是否为固定练习目录、是否允许覆盖。不要把教材示例的短文件名替换为生产配置路径；不要在不理解的命令后追加 `> /dev/null` 或 `2>/dev/null`。

### 不把秘密送进错误通道

标准流可能被终端历史、CI、IDE、日志收集器或上游调用者保存。诊断信息不应包含令牌、完整密码、私人绝对路径和客户数据。错误消息应提供可定位的阶段与安全标识，而不是把原始秘密输入整段打印出来。

### 管道右侧也是程序

将数据通过管道交给另一程序，等同于把这些字节提供给它处理。先知道右侧命令来源和职责，不把凭据、生产导出或隐私文件送入未知工具。管道看起来只是竖线，不会减少数据暴露。

### expected failure 必须受控

故障实验只使用固定非法状态和临时文件，不通过删除权限、杀死真实服务或损坏项目制造错误。验证器应确认预期非零与诊断内容，再把整体验证判为通过；意外退出、超时或输出超限必须判失败。

## FactoryCare 场景：只读工单状态筛选器

假设 FactoryCare 需要一个本地只读命令：从 `stdin` 读取一行状态，允许 `ASSIGNED` 或 `IN_PROGRESS`，成功时把 `accepted=<状态>` 写到 `stdout` 并返回 0；状态非法或输入为空时不产生正常结果，只在 `stderr` 写安全诊断并返回指定非零状态。

先写合同，而不是先拼命令：

| 场景 | stdin | stdout | stderr | 状态 |
| --- | --- | --- | --- | ---: |
| 合法状态 | `IN_PROGRESS` | `accepted=IN_PROGRESS` | 空 | 0 |
| 非法状态 | `CLOSED` | 空 | `invalid status` | 非 0 |
| 空输入 | EOF | 空 | `missing status` | 非 0 |

接着验证文件输入、直接管道、分别捕获两条输出、默认管道掩盖与 `PIPE_FAIL`。如果未来需求允许 `CLOSED`，修改的是允许集合、预言和测试，不应把所有非零硬改成零，也不应把诊断混入正常结果让旧消费者突然解析失败。

这个场景只演示命令行边界，不连接真实 FactoryCare 数据库，不读取生产工单，不实现权限、审计或网络 API。业务名帮助迁移概念，不能成为越过安全边界的理由。

## 配套示例、实验与答案隔离

可运行示例位于 [`examples/encyclopedia/ch.foundations.cli-streams-exit-codes`](../../../examples/encyclopedia/ch.foundations.cli-streams-exit-codes/README.md)。它在全新临时目录验证合法输入、非法输入、空输入、`stdout`/`stderr` 分流、覆盖与追加、默认管道状态和 `PIPE_FAIL`。运行：

```text
ruby verify.rb
```

最后一行应为 `cli-streams verification: PASS`。其中的 expected failures 是已核对的子场景，不等于验证器失败。

实验位于 [`labs/encyclopedia/ch.foundations.cli-streams-exit-codes`](../../../labs/encyclopedia/ch.foundations.cli-streams-exit-codes/README.md)。先在 `worksheet.md` 预测三条流与状态，再运行固定夹具。自动检查只验证夹具和固定预言，不会替你批改文字解释。

公开练习位于 [`exercises/encyclopedia/ch.foundations.cli-streams-exit-codes`](../../../exercises/encyclopedia/ch.foundations.cli-streams-exit-codes/README.md)。隔离解析保存在 `solutions-private/encyclopedia/ch.foundations.cli-streams-exit-codes/`，不会进入公开教材。先保存独立答案与一次错误预测，再阅读解析。

## 预测—构建—诊断—变更训练

### 预测

对每个固定输入先写：argv、`stdin` 字节、`stdout` 精确内容、`stderr` 精确内容、子命令状态、管道整体状态与是否执行短路右侧。信息不足时写“需确认 Shell 选项或工具合同”，不要猜。

### 构建

用固定探针完成三段实验：合法状态从文件进入 `stdin`；非法状态把正常与诊断分别捕获；合法结果通过管道交给只读匹配器。每段只在临时或教材实验目录写文件，运行后核对内容和状态。

### 诊断

依次注入三个独立故障：去掉含空格输入路径的引用；把 `stderr` 丢弃；让前段返回 7、末段返回 0。每次指出故障最先出现在哪个边界，只改一项，使用原预言复跑。不要同时改输入、重定向和状态传播。

### 需求变更

把允许状态增加为 `WAITING_PART`，把成功格式改为 `accepted_status=<值>`。列出受影响的生产者、管道消费者、输出预言和练习答案；保留非法输入仍非零的回归证据。若 AI 重写整个探针，逐行指出合同在哪里实现，而不是仅接受新文件。

## 无 AI 训练

关闭 AI，限时 45 分钟：

1. 画一个进程的三条标准流和退出回执；
2. 对合法、非法、空输入逐项写四列预言；
3. 完成一次文件输入和 stdout/stderr 分流；
4. 复现默认管道掩盖前段 7，再用 `PIPE_FAIL` 暴露；
5. 用 `false && ...`、`false || ...` 解释短路；
6. 制造一个诊断被误写到 stdout 的反例并给出合同修复；
7. 用 120 秒复述为什么“有输出”和“成功”是两种证据。

允许查看本章速查表与系统手册，不允许先看私有解析。若固定验证器通过但无法解释哪条流被连接、哪一个状态被观察，仍未达到独立掌握。

## 复述题与间隔复习

### 当天复述

- `stdin`、`stdout`、`stderr` 分别是谁的入口或出口？
- 为什么两条输出都显示在终端时不能靠颜色判断来源？
- `>` 和 `>>` 对已有文件有什么不同风险？
- 管道连接哪两条流？
- 为什么前段失败可能得到管道整体 0？
- `&&` 和 `||` 依据文字还是状态短路？

### 第 1 天检索

不看正文画连接图，对合法和非法输入写精确预言。若只写“错误会报错”，补上错误在哪条流、状态是否非零、正常结果是否为空。

### 第 3 天诊断

给出一段“stdout 正确、stderr 有诊断、状态 7”的记录，解释为什么不能判成功，也不能仅因 stdout 存在删除它。写出下一条最小验证动作。

### 第 7 天迁移

为另一个只读命令设计输入、结果、诊断和状态合同，再将结果接给第二个消费者。明确消费者不应收到哪些诊断文字。

### 第 14 天教回

面向零基础同学在 120 秒内解释“三条传送带和一张回执”，必须包含一个管道前段失败被掩盖的反例和一个覆盖文件风险。

## 速查表

| 机制 | 最小含义 | 首个观察 | 常见误解 |
| --- | --- | --- | --- |
| `stdin` | 进程的标准输入字节流 | 固定输入与 EOF | 永远来自键盘 |
| `stdout` | 主要正常结果字节流 | 分开捕获内容 | 屏幕文字都在 stdout |
| `stderr` | 独立诊断字节流 | `2>` 分开捕获 | 非空必然代表失败 |
| exit status | 进程交给父进程的整数结果 | 紧接着观察或用进程 API | 输出正确就一定为 0 |
| `< file` | 文件连接到 stdin | 文件路径与输入内容 | 程序自己必然打开文件 |
| `> file` | stdout 覆盖写入文件 | 运行前目标与运行后内容 | 失败不会动文件 |
| `>> file` | stdout 追加到文件 | 旧内容与新增边界 | 追加永远安全 |
| `2> file` | stderr 写入文件 | 诊断文件 | 会同时捕获 stdout |
| `A | B` | A.stdout 接到 B.stdin | 两端内容与每段状态 | 自动传递 stderr 与失败 |
| `A && B` | A 为 0 才执行 B | A 状态、B 是否启动 | 阅读 A 的输出决定 |
| `A || B` | A 非 0 才执行 B | A 状态、B 是否启动 | 自动完成正确恢复 |
| `PIPE_FAIL` | zsh 的管道失败传播选项 | 固定前败后成对照 | 能修复程序业务错误 |

常用观察形式：

```text
command < input.txt > result.txt 2> diagnostic.txt
echo $?
setopt PIPE_FAIL
producer | consumer
echo $?
```

不要把 `command`、文件名或输出内容原样替换成生产对象；先在固定练习目录画连接和预测。

## 术语表

- **standard stream / 标准流**：进程启动时按约定准备的标准输入输出通道。
- **stdin**：standard input，标准输入，常对应文件描述符 0。
- **stdout**：standard output，标准输出，常对应文件描述符 1。
- **stderr**：standard error，标准错误，常对应文件描述符 2。
- **byte stream / 字节流**：有顺序的字节序列；文本编码和记录格式需另行约定。
- **EOF**：end-of-file，表示输入流结束的状态，而不是普通业务字符。
- **redirection / 重定向**：由 Shell 改变标准流连接对象的机制。
- **pipeline / 管道**：把一个进程的标准输出连接给另一个进程标准输入的进程组合。
- **exit status / 退出状态**：进程终止后交给父进程的整数结果。
- **short-circuit / 短路**：根据左侧状态决定是否执行右侧命令。
- **oracle / 预言**：用于比较实际行为的明确期望，包括内容、通道与状态。
- **expected failure / 预期失败**：特意构造并被验证器确认的失败路径，不等于验证器自身故障。
- **false success / 假成功**：某个步骤实际失败，但组合命令或不完整检查最终报告成功。

## 一手资料与复核边界

本章稳定核心不绑定特定工具 patch；运行资产只承诺在固定 macOS `/bin/zsh`、系统 Ruby 与临时夹具中验证。资料链接复核日期：**2026-07-16**。本次网络检索受限，因此链接与稳定语义依据仓库已核对的一手资料记录整理，页面当日可达性未重新验证。

- [Apple《Redirect Terminal input and output on Mac》](https://support.apple.com/guide/terminal/redirect-input-and-output-apd1dbe647b/mac)：终端中标准输入、输出、重定向与管道的用户级说明。
- [The Open Group POSIX Shell Command Language](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html)：重定向、管道、命令列表与退出状态的可移植规范来源。
- [The Open Group `read`](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/read.html)：从标准输入读取的 Shell 工具语义边界。
- [zsh Redirection](https://zsh.sourceforge.io/Doc/Release/Redirection.html)：zsh 文件描述符、重定向和多重重定向实现说明。
- [zsh Shell Grammar](https://zsh.sourceforge.io/Doc/Release/Shell-Grammar.html)：simple command、pipeline、list 与 `&&`/`||` 语法。
- [zsh Options](https://zsh.sourceforge.io/Doc/Release/Options.html)：`PIPE_FAIL` 等选项的实现规则。
- [Ruby `IO`](https://docs.ruby-lang.org/en/master/IO.html)：配套探针读取标准输入、写标准输出/错误和流对象的官方 API 入口。

POSIX 说明可移植核心，zsh 文档说明本章固定 Shell；二者不应混为“所有 Shell 完全相同”。未验证 Bash、fish、PowerShell、Windows 命令解释器、个人 zsh 插件、远程终端、交互程序的终端控制、信号和大数据缓冲行为。

## 本章明确不做

- 不教授复杂 Shell 脚本、函数、条件块、循环、数组、作业控制和信号处理；
- 不扩展到网络 socket、HTTP 流、应用日志框架、结构化日志或分布式追踪；
- 不保证所有程序都按同一方式使用 stderr 或非零状态，具体合同仍需查文档；
- 不在真实用户目录、生产配置或项目证据上练习覆盖与追加；
- 不用丢弃 stderr、伪造退出码或只检查文件存在来让验证“变绿”；
- 不把固定验证器 PASS、阅读完成或 AI 解释当作独立掌握证据。

下一章将使用本章的状态与流观察方法，学习进程环境、父子继承、`PATH` 查找以及同名工具版本来源。标准流告诉你“程序说了什么并如何结束”，环境与工具解析将回答“究竟启动了哪个程序，以及它看到了哪些启动条件”。
