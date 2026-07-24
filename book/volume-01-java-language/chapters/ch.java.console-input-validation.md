---
schema_version: 2
edition: 2026.2-draft
id: ch.java.console-input-validation
title: 控制台输入、缺参数、EOF、合法性校验与退出码
responsibility: 综合基础语法实现可靠控制台边界，只复制 Scanner 构造外壳而不解释其对象模型
volume: '01'
order: 9
level: L1
status: drafting
path: book/volume-01-java-language/chapters/ch.java.console-input-validation.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java.methods
version_surfaces:
- jdk-25
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释控制台输入、缺参数、EOF、合法性校验与退出码的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-console-input
  - java-input-contract
  covers_topics:
  - java.console-token-line
  - java.command-argument-validation
  - java.eof
  - java.parse-validation
  - java.retry-or-fail
  - java.process-exit-code
  uses_capabilities:
  - java.methods
  - java.arrays
  - java.control-flow
  - foundation.shell-command-stream
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现读取工单数量与单价的 CLI：支持 args 或 stdin、检测缺参数/EOF/非法数字、成功打印总额并设置退出码
  covers_topic_groups:
  - java-console-input
  - java-input-contract
  covers_topics:
  - java.console-token-line
  - java.command-argument-validation
  - java.eof
  - java.parse-validation
  - java.retry-or-fail
  - java.process-exit-code
  uses_capabilities:
  - java.methods
  - java.arrays
  - java.control-flow
  - foundation.shell-command-stream
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入 EOF 后无限重试、parse 前未校验和所有路径都返回 0，依据 stderr/退出码定位并修复
  covers_topic_groups:
  - java-console-input
  - java-input-contract
  covers_topics:
  - java.console-token-line
  - java.command-argument-validation
  - java.eof
  - java.parse-validation
  - java.retry-or-fail
  - java.process-exit-code
  uses_capabilities:
  - java.methods
  - java.arrays
  - java.control-flow
  - foundation.shell-command-stream
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 控制台输入、缺参数、EOF、合法性校验与退出码

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《方法、参数传递、返回值、重载与递归边界》](ch.java.methods.md)：独立完成控制台输入、输入与退出契约前，必须先具备「方法、参数传递、返回值、重载与递归边界」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。正文和脚本可以试读、运行与修改，但脚本通过不等于学习者已经完成本章，也不会自动更新学习进度。

前面写的 Java 程序大多把输入直接写在源码里。这样的程序能说明语法，却不能代表真实边界：用户可能少给一个值，把“3”写成“three”，输入一个业务不允许的负数，也可能在程序等待时直接结束输入。可靠程序必须把这些情况变成**明确、有限、可验证的结果**，而不是卡住、打印一长串内部错误，或者以成功状态悄悄结束。

本章只讨论控制台边界。它使用已经学过的数组、条件、循环与方法，并复制 `Scanner` 的创建外壳；不展开对象模型、文件读写、网络请求或 Java 异常体系。为了把文字解析失败转成稳定结果，会使用一小段固定的 `try/catch` 边界包装，但只要求理解“转换失败时走备用分支”，完整异常知识留到后续章节。运行基线为 **JDK 25**，官方资料复核日期为 **2026-07-16**。

## 1. 学完后必须留下什么证据

1. **解释证据**：在 120 秒内说清 `args`、stdin、stdout、stderr、token、line、EOF、解析、业务校验、重试策略和退出码之间的关系；给出一个 EOF 无限循环反例。
2. **构建证据**：实现一个工单金额 CLI，既能接收两个命令行参数，也能在无参数时读取标准输入；固定输入产生固定 stdout、stderr 和退出码。
3. **诊断证据**：分别重放缺参数、空行、EOF、非法整数、负数量和合法零数量；说明每例在哪一层失败，修复后重新跑全部用例。

配套入口：

- [输入契约示例](../../../examples/encyclopedia/ch.java.console-input-validation/README.md)
- [EOF 与输入边界实验](../../../labs/encyclopedia/ch.java.console-input-validation/README.md)
- [独立练习：工单批量录入 CLI](../../../exercises/encyclopedia/ch.java.console-input-validation/README.md)

私有解析只在独立尝试后核对，不进入公开教材、提交记录或学习证据。

## 2. 直觉模型：程序门口的验票员

把控制台输入想成进入业务区之前的门口。门外是字符串世界，门内才是可信的 `int`、`boolean` 与业务值。验票员不能看到一串字符就放行，而要依次确认：票有没有送到、字段够不够、字符能否转换成目标类型、数值是否满足业务规则。任何一步失败，都应从同一个入口返回可理解结果。

一条可靠链路可以概括为：

```text
选择来源 -> 检查是否有数据 -> 读取字符串 -> 拆分字段
        -> 解析类型 -> 校验业务范围 -> 执行业务计算
        -> 选择输出通道 -> 返回进程退出码
```

这个顺序很重要。没有数据时不能先解析；能解析成整数不代表业务合法；业务失败不应仍返回 0；诊断文字不应混进供脚本消费的成功输出。把这些职责混在一个巨大表达式里，失败时就很难知道是哪一层出了问题。

## 3. 一个进程有三个常用控制台通道

Java 进程启动时通常连接三个标准流：

- **stdin**：标准输入，程序从这里读取字节或文本；终端键盘、管道和重定向文件都可以成为来源。
- **stdout**：标准输出，放正常结果，便于人阅读，也便于下一个程序继续处理。
- **stderr**：标准错误，放诊断信息；即使 stdout 被管道转走，错误仍可单独显示或保存。

它们不是“页面上的三个区域”，而是进程边界上的三个通道。下面两条命令对 Java 来说都只是从 stdin 收到文本：

```bash
printf '1999 3\n' | java WorkOrderAmountCli
java WorkOrderAmountCli < input.txt
```

本章不教授如何在 Java 代码里打开 `input.txt`。重定向由 shell 完成，Java 程序仍只读 stdin。这正是标准流的价值：业务程序不必知道输入来自键盘、管道还是文件重定向。

## 4. 命令行参数和 stdin 不是同一件事

`main(String[] args)` 中的 `args` 在 JVM 调用 `main` 前已经由启动命令提供。例如：

```bash
java WorkOrderAmountCli 1999 3
```

此时 `args.length == 2`，两个元素分别是字符串 `"1999"` 和 `"3"`。程序不需要等待键盘。如果执行：

```bash
java WorkOrderAmountCli
```

`args.length == 0`，但这不表示 stdin 一定有内容。stdin 可能随后由用户输入，也可能已经到达 EOF。可靠程序必须先决定来源，再按该来源的契约处理，不能“参数不够就随便再读几个 token”，否则自动化脚本可能意外阻塞。

一种清楚策略是：恰好两个 args 就使用 args；零个 args 才读取 stdin 一行；其他数量立即报告用法错误。这个策略不是 Java 强制规则，而是本程序公开的输入契约。调用者可以据此预测行为。

## 5. `Scanner` 与 `BufferedReader`：选择解析便利还是边界清晰

零基础阶段常见两个文本入口：

```java
Scanner scanner = new Scanner(System.in);
```

```java
BufferedReader reader = new BufferedReader(
        new InputStreamReader(System.in));
```

`Scanner` 提供 `hasNextLine`、`nextLine`、`hasNextInt`、`nextInt` 等便利方法，适合小型交互程序与教学。它会进行 token 化和类型扫描，但方法混用时容易留下换行符认知错误。`BufferedReader` 主要按行读取，边界更直接，通常先得到一个字符串，再由程序自己拆分和解析；它适合明确的行协议，代码会多一些。

本章示例选 `Scanner.hasNextLine()` 加 `nextLine()`：先把一整行当作输入边界，再自行拆字段。这样避免在 `nextInt()` 与 `nextLine()` 之间处理残留换行。选择原则不是“哪个永远更快”，而是输入协议是什么、失败需要怎样被观察。对于这里的两字段 CLI，按行读取更容易重放。

创建、关闭和对象生命周期属于后续对象与资源章节。本章只复制构造外壳；不要据此推断所有标准输入程序都必须在每个方法里创建并关闭 Scanner。

## 6. token 与 line：先定义输入协议

**token** 是由空白等分隔符切开的字段，**line** 是换行前的一整段文本。若协议是“价格 数量”，按 token 读取很方便；若第二个字段可能包含空格，例如“3 motor temperature high”，就要限制拆分次数，把第一段作为 priority，剩余整段作为 description。

```java
String[] fields = line.trim().split("\\s+", 2);
```

这里先 `trim` 去除首尾空白，再按一个或多个空白最多拆成两段。空行必须在拆分前单独判断，因为空字符串的 split 结果容易让初学者误判字段数量。输入协议要写清楚：是否允许多余空格、描述能否为空、是否接受第三个独立字段、大小写是否敏感。没有协议，“能读到”就没有明确含义。

字段名与单位也属于协议。`1999` 是 1999 分还是 1999 元？`3` 是数量还是优先级？程序无法从字符本身知道业务含义。命令说明、变量名、验证信息与测试 expected 必须使用同一单位。

## 7. EOF 不是空字符串，也不是“再等等”

EOF 表示输入源已经结束，之后不会再产生新内容。它可能来自管道发送完毕、重定向文件到末尾，或者终端用户发出结束信号。EOF 与用户输入一个空行不同：空行是一条长度为零的行，EOF 则根本没有下一行。

对 Scanner，应先判断：

```java
if (!scanner.hasNextLine()) {
    System.err.println("ERROR EOF");
    return 66;
}
String line = scanner.nextLine();
```

如果直接 `nextLine()`，EOF 会让读取失败；如果在 `while` 中发现没有下一行后继续循环，又没有任何状态变化，程序会空转或一直等待。正确选择通常有两个：当前协议允许输入结束，就正常结束；当前命令必须收到一条记录，就报告 EOF 并以非零状态结束。不要把 EOF 当成无效 token 后无限重试。

交互式“请重新输入”只有在输入源仍开放且产品规则明确允许时才合理。对管道式 CLI，失败后退出通常更可预测，因为调用方可以修正输入后重新启动。

## 8. 从字符串到业务值的四层验证

以 `1999 3` 为例，至少有四层：

1. **存在性**：有下一行或两个 args。
2. **结构**：恰好两个字段。
3. **类型解析**：两个字段都能转换成 int。
4. **业务范围**：单价大于 0，数量大于等于 0。

`abc` 在类型解析层失败；`-1` 可以成功解析为 int，却在业务范围层失败；数量 0 也能解析，而且若业务允许“空订单预估”，结果应该是 0，不能因为“看起来没意义”随意拒绝。分层能让错误信息、退出码与测试用例更精确。

不要用一个默认值掩盖错误。例如解析失败就当 0，会把 `abc` 与合法数量 0 混在一起。下游看到 0 无法知道用户真的输入 0，还是程序悄悄修正了错误。可靠边界宁可明确失败，也不制造无法追溯的数据。

## 9. 解析失败要被转换成可控结果

`Integer.parseInt(text)` 对合法十进制字符串返回 int；对不合法文本会以异常方式报告失败。完整异常模型以后再学。本章把下面方法当作一个固定边界适配器：成功返回整数，失败返回 `null`，调用者立刻检查。

```java
static Integer parseInteger(String text) {
    try {
        return Integer.valueOf(text);
    } catch (NumberFormatException ignored) {
        return null;
    }
}
```

这不表示“异常都应该忽略”。`ignored` 只表示不使用异常对象的内部信息，因为 CLI 已决定给用户稳定的 `ERROR DATA`。也不表示 null 是通用最佳设计；这里范围很小，调用点紧邻检查。未来会学习异常传播、结果对象和更清楚的领域建模。

解析前仍要检查字段数量。若数组只有一个元素却访问 `fields[1]`，失败就不再是“用户少给字段”的受控错误，而会变成程序运行异常。先结构、后解析，是减少这类错误的简单规则。

## 10. 合法性校验不是解析的同义词

“能变成 int”只证明字符形式符合整数，不证明它适合当前业务。FactoryCare 的 priority 可能只允许 1—5；quantity 可以是 0，但不能是负数；unitPriceCents 可能必须大于 0。把规则写成命名清楚的条件：

```java
if (unitPriceCents <= 0 || quantity < 0) {
    System.err.println("ERROR DATA: price must be positive and quantity non-negative");
    return 65;
}
```

边界值必须由规则推导，而不是凭直觉选几个“正常数字”。若允许范围是 1—5，应测试 1、5、0、6；若数量允许 0，应测试 0、1、-1。超大整数在解析阶段可能无法放进 int，也应作为非法输入处理。本章不展开金额溢出与更大数值类型，但不能声称所有数值规模都安全。

错误信息要说明违反的规则，但不要回显秘密、完整个人信息或未经处理的巨大输入。CLI 接收设备 token 或密码时，更不能把原值写入 stderr。示例只处理脱敏金额、数量和描述。

## 11. “重试”与“失败退出”必须是显式策略

交互程序可以提示后重试，批处理命令通常应失败退出。二者没有绝对高下，关键是调用者能否预测。设计前回答：

- 输入来自人在终端实时输入，还是脚本/管道？
- 最多重试几次？EOF 是否立即终止？
- 每次失败是否消耗一行？
- 最终失败使用什么退出码？
- 调用方如何知道哪条记录失败？

无上限的 `while (true)` 加模糊 `continue` 很危险。即使允许重试，也应让每轮消耗新输入，并在 EOF 或次数上限结束。对本章固定 CLI，选择“单次读取，非法即退出”，便于测试七条独立用例。

前端类比是表单校验：用户点击提交后，先验证字段，再决定阻止提交或发送请求。不同点是 CLI 没有可视组件状态，stdout、stderr 和退出码就是它的外部契约。

## 12. 退出码：机器可读的成功或失败

进程结束时会返回整数状态。惯例是 0 表示成功，非 0 表示失败。shell 可以读取上一条命令的状态：

```bash
java WorkOrderAmountCli 1999 3
echo $?
```

Java main 正常返回时进程通常为 0；失败路径可以调用 `System.exit(nonZero)`。本章示例使用 64 表示用法错误、65 表示数据错误、66 表示 EOF，只为建立稳定区分，不要求背诵一套跨平台永恒标准。真实项目应在 README 固定含义。

所有路径都返回 0 是常见 bug：屏幕上虽有 `ERROR`，自动化脚本仍认为命令成功，后续步骤继续执行。反过来，成功结果正确但返回非 0，也会让 CI 或调用脚本误判失败。文本与状态必须一起验证。

退出码也不是完整错误详情。它适合机器分支，stderr 适合人定位，两者互补。不要让调用方通过解析一段中文错误文本来猜成功与否。

## 13. stdout 与 stderr 的稳定契约

成功时只输出：

```text
totalCents=5997
```

失败时 stdout 为空，stderr 输出一行稳定诊断。这样调用者可以安全地做：

```bash
total=$(java WorkOrderAmountCli 1999 3)
```

若程序把“正在计算……”或错误堆栈也写到 stdout，`total` 就不再是可直接消费的结果。教学时打印调试变量很方便，但进入固定 CLI 后应删除或改为受控诊断。稳定不等于永不改文案，而是任何契约变化都要同步更新调用者和测试。

敏感输入不得原样打印。即使 stderr 看似只在本地，它也可能进入 CI 日志、监控系统或工单附件。错误信息应提供字段名与规则，不需要复制秘密值。

## 14. 一次调用的精确执行链

执行 `java WorkOrderAmountCli 1999 3` 时：shell 先把三个词组成进程参数；JVM 把类名之后两个参数放进 String 数组；main 调用 `run`；`run` 选择 args 分支；字段数量为 2；解析产生两个整数；范围校验通过；乘法得到 5997；stdout 写一行；run 返回 0；main 不调用 `System.exit`；JVM 正常结束并向 shell 返回 0。

执行 `printf '' | java WorkOrderAmountCli` 时：args 长度为 0；Scanner 连接到已经结束的 stdin；`hasNextLine()` 为 false；程序向 stderr 写 EOF；run 返回 66；main 调用 `System.exit(66)`；不会进入字段拆分和解析，也不会等待新输入。

能逐步说清执行链，比背 API 更重要。遇到错误时，你可以问“链路最后成功完成到哪一步”，而不是从整个程序里随机改代码。

## 15. 用例矩阵：输入、通道和状态一起写

只写“测试非法输入”太模糊。一个可重放矩阵至少包含来源、原始输入、预期 stdout、预期 stderr 与退出码：

| 场景 | 来源 | 输入 | stdout | stderr | 状态 |
| --- | --- | --- | --- | --- | ---: |
| 多件商品 | args | `1999 3` | `totalCents=5997` | 空 | 0 |
| 零数量 | args | `1999 0` | `totalCents=0` | 空 | 0 |
| 少一个参数 | args | `1999` | 空 | 用法错误 | 64 |
| 非整数 | args | `abc 3` | 空 | 数据错误 | 65 |
| 负数量 | args | `1999 -1` | 空 | 范围错误 | 65 |
| 正常行 | stdin | `1250 2` | `totalCents=2500` | 空 | 0 |
| 输入结束 | stdin | EOF | 空 | EOF 错误 | 66 |

先写 expected，再运行 actual。若先看程序输出再补 expected，很容易把当前实现当成需求。计算结果应手算；错误通道与状态应来自公开契约。

## 16. 三个典型失败及诊断顺序

### 16.1 EOF 后无限循环

现象是空管道运行不结束或 CPU 空转。先确认输入确实是 EOF，再看循环中 EOF 分支是否 `return`/`break`。若分支只 `continue`，且没有新状态，下一轮仍是 EOF。最小修复是让 EOF 终止，不是增加随机 sleep。

### 16.2 未检查结构就解析

少字段时出现数组越界或读取异常，而不是稳定用法错误。先检查 `fields.length` 的位置是否在任何下标访问之前。修复后重跑少字段、空行、EOF 和正常行，防止只覆盖一条路径。

### 16.3 错误路径仍返回 0

stderr 明明显示 ERROR，但 `echo $?` 为 0。沿着失败分支看方法返回值与 main 是否真正把状态交给进程。不要只把文字改成更醒目；机器判断依赖退出码。

诊断记录应分开写：观察事实、原因假设、最小修改、复跑证据。比如“事实：EOF 例 2 秒后仍未结束；假设：EOF 分支 continue；修改：return 66；证据：同一空输入在有限时间结束且状态 66”。

## 17. FactoryCare 场景：工单批量录入边界

设一个维修人员在终端录入 `priority description`。priority 只允许 1—5，description 去除首尾空白后不能为空。合法输入输出接受摘要；非法输入不创建任何工单。这里最重要的不是 Scanner，而是**业务动作只能发生在全部验证之后**。

如果先创建工单，再发现 priority 非法并返回错误，就产生“命令说失败但数据已变化”的矛盾。虽然本章不连接数据库，也应养成顺序：读取、解析、验证完成后才调用业务方法。以后进入 Web 控制器、消息消费者和移动端表单时，同一边界原则仍成立。

输入描述可能包含设备位置等敏感信息。诊断只说 description 为空或格式不合法，不把整段内容回显。公开示例使用虚构设备，不出现真实客户、token、手机号或地址。

## 18. 安全与资源边界

控制台并不天然可信。自动化任务、其他程序或恶意调用者都能提供输入。至少考虑：字段数量、长度、数字范围、重复输入与敏感内容。一个超长描述可能占用大量内存或污染日志；本章不实现完整长度限制，但应知道生产命令需要上限。

不要把用户输入拼成 shell 命令再执行；不要因输入是本机终端就跳过校验；不要把密码作为普通命令行参数，因为它可能出现在进程列表或 shell 历史。本章金额 CLI 不接收凭据。后续安全章节会系统讨论命令注入与秘密管理。

整数乘法也有上限。`unitPriceCents * quantity` 可能溢出 int。本章目标是输入边界而非数值溢出，因此固定用小值；在真实金额系统中应使用合适类型、范围约束并增加极值测试。明确非目标比假装“已经安全”更诚实。

## 19. 预测题：运行前先写答案

对每项写 stdout、stderr、退出码和停止层次，再运行配套脚本：

1. args 为 `1999 3`。
2. args 为 `1999 0`。
3. args 为 `1999`，stdin 中恰好还有 `3`。
4. args 为空，stdin 是空行。
5. args 为空，stdin 已 EOF。
6. args 为 `1999 three`。
7. args 为 `-1 3`。

第三项用于检查来源策略：既然非零 args 数量不符合契约，就应立即用法失败，不能偷偷从 stdin 补齐。第四项有一条空行，因此不是 EOF；它在字段结构层失败。预测错了不要只改答案，要写下你混淆的是来源、存在性、结构、解析还是业务范围。

## 20. 构建路径：从纯规则到进程边界

推荐按以下顺序实现：先写输入输出矩阵；再写接收字符串数组并返回状态的核心方法；用固定字符串测试结构、解析和范围；最后才把 args、Scanner、stdout、stderr 与 System.exit 接上。这样大部分规则不用每次人工敲键盘。

配套 example 的验证脚本会编译一次，然后分别启动七个新 JVM 进程。每个进程的输入、输出文件和状态都独立保存。这样既验证 Java 内部逻辑，也验证 shell 看见的真实退出码。lab 则把字符串放进内存 Scanner，快速断言六条规则，并单独暴露 EOF 重试 bug。

不要把 build 目录中的输出当作源码提交。它是可重建证据；真实提交应包含源文件、固定脚本和说明。删除 build 后重跑仍得到同样结论，才说明验证可重复。

## 21. 无 AI 训练

关闭 AI，限时 45—60 分钟：

1. 手写一个支持 args 或 stdin 的两字段 CLI，不查看私有解析。
2. 先列七条用例，计算 expected，之后再运行。
3. 故意把 EOF 分支改成继续循环，用可控方式确认风险后立即恢复；不要让无限进程长期占用机器。
4. 故意把非法输入路径状态改成 0，从 shell 观察误报成功，再修复。
5. 不看笔记解释为什么空行不等于 EOF、解析成功不等于业务合法。

无 AI 训练不要求背完整 API。允许查看 JDK 方法签名，但输入协议、边界值、退出策略和诊断必须由你决定。验收时随机修改规则，例如 priority 从 1—5 改成 0—4；你应能定位校验与测试，而不是重新生成整个程序。

## 22. 120 秒复述模板

“Java CLI 的外部输入最初都是字符串。命令行参数在启动前进入 args，stdin 则由程序运行时读取；stdout 放正常结果，stderr 放诊断，退出码让机器判断成功或失败。我先确定来源，再检查 EOF 和字段结构，然后解析类型、校验业务范围，最后才执行计算。EOF 表示输入结束，不能无限重试；空行则是一条存在但没有有效字段的行。Scanner 适合小程序的便捷扫描，按行读取能减少 token/换行混淆。成功与失败都要用固定输入重放，同时断言两个输出通道和退出码。反例是捕获错误后打印 ERROR 却仍返回 0，脚本会误判成功。”

如果讲不清“空行和 EOF”或“解析和校验”，回到用例矩阵重新分类，不要继续堆代码。

## 23. 复习与速查

### 当天

- 画出来源选择到退出码的九步链路。
- 运行 example 七例，指出每例最后通过的层。
- 手算金额，不从 actual 反推 expected。

### 48 小时后

- 不看正文重写空行、EOF、非法数字和负数四条测试。
- 把输入协议改成 `priority description`，说明为什么 split 要限制为 2。
- 解释为何错误只写 stderr。

### 一周后

- 从空目录重建 exercise。
- 注入 EOF 重试 bug 和全路径返回 0，分别诊断并修复。
- 进行 120 秒复述，要求包含一个失败反例和安全边界。

### 速查表

| 问题 | 首先检查 |
| --- | --- |
| 程序一直等 | 来源是否会提供数据、是否已 EOF、循环是否终止 |
| 少字段却运行异常 | 下标访问前是否检查字段数量 |
| `abc` 被当成 0 | 是否用默认值掩盖解析失败 |
| `-1` 被接受 | 是否只解析而没有业务范围校验 |
| 脚本误报成功 | stderr 之外是否返回非零退出码 |
| 成功结果无法被管道使用 | stdout 是否混入提示和诊断 |

## 24. 术语表

- **CLI**：命令行界面的程序入口与交互契约。
- **stdin/stdout/stderr**：标准输入、标准输出、标准错误三个进程通道。
- **argument**：启动命令传给 main 的字符串参数。
- **token**：按分隔规则切出的字段。
- **line**：换行之前的一整段文本。
- **EOF**：输入源结束，不等于空行。
- **parse**：把字符串转换成目标类型表示。
- **validation**：判断已解析值是否符合结构和业务规则。
- **exit code**：进程返回给调用方的整数状态，通常 0 成功、非 0 失败。
- **oracle**：事先确定的预期结果，用来和实际结果比较。
- **retry policy**：哪些失败允许重试、最多几次、何时终止的规则。

## 25. 官方资料与版本说明

- [Java SE 25 API：Scanner](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Scanner.html)，复核于 2026-07-16；支持 `hasNextLine`、`nextLine` 等稳定 API 说明。
- [Java SE 25 API：System](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/System.html)，复核于 2026-07-16；支持标准流与 `exit` 的平台定义。
- [Java SE 25 API：Integer](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Integer.html)，复核于 2026-07-16；支持整数解析接口与范围语义。
- [JDK 25 文档首页](https://docs.oracle.com/en/java/javase/25/)，复核于 2026-07-16。

稳定核心是标准流、EOF、分层解析校验、输出通道和退出码契约；具体错误码数字、文案和输入字段属于应用约定。未在本章验证文件 I/O、网络输入、完整异常设计、金额大数精度、国际化解析和操作系统信号处理。
