---
schema_version: 2
edition: 2026.2-draft
id: ch.java.loops
title: for、while、计数、累积与哨兵循环
responsibility: 教授有界重复和循环不变量，不提前使用数组、集合或递归作为主要数据来源
volume: '01'
order: 6
level: L1
status: drafting
path: book/volume-01-java-language/chapters/ch.java.loops.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java.branching
version_surfaces:
- jdk-25
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释for、while、计数、累积与哨兵循环的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-loop-forms
  - java-loop-control
  covers_topics:
  - java.for-loop
  - java.while-loop
  - java.do-while-loop
  - java.counter-accumulator
  - java.sentinel-loop
  - java.break-continue
  uses_capabilities:
  - java.values-types-string
  - java.control-flow
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：综合 if/switch 与 for/while：按优先级分支处理1..N项、哨兵计数和可提前退出查找，并记录循环不变量，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - java-loop-forms
  - java-loop-control
  covers_topics:
  - java.for-loop
  - java.while-loop
  - java.do-while-loop
  - java.counter-accumulator
  - java.sentinel-loop
  - java.break-continue
  uses_capabilities:
  - java.values-types-string
  - java.control-flow
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入分支边界遗漏、switch漏状态、off-by-one、哨兵不更新和break位置错误，借助路径/计数轨迹修复
  covers_topic_groups:
  - java-loop-forms
  - java-loop-control
  covers_topics:
  - java.for-loop
  - java.while-loop
  - java.do-while-loop
  - java.counter-accumulator
  - java.sentinel-loop
  - java.break-continue
  uses_capabilities:
  - java.values-types-string
  - java.control-flow
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# for、while、计数、累积与哨兵循环

> 本章状态为 `drafting`。正文和配套工件可以试读、运行与修改，但文件存在或脚本通过不等于学习者已经过关，也不会自动更新学习进度。

前一章解决“这一次走哪条路径”，本章解决“在什么条件下重复走一段路径，以及何时一定停下来”。FactoryCare 可能需要处理编号 1..N 的工单、对剩余数量倒计时、累计已处理数量，或读到一个结束标记后停止。复制粘贴五遍代码只适用于恰好五项；循环把重复规则和变化状态分离。

循环最危险的地方不是关键字拼错，而是边界和终止：少做一次、多做一次、累计到错误变量、`continue` 跳过必要更新、哨兵永远不变，都会让程序得到错结果或一直运行。AI 很容易生成一段看起来标准的 `for`；你必须能证明它在 N=0、N=1 和 N>1 时分别执行几次，并指出每轮有什么量在逼近退出条件。

本章不使用数组、集合、递归或控制台输入作为主要数据来源。所有重复都由可手算的整数状态驱动；下一章再把循环用于数组。版本基线为 **JDK 25**，官方资料复核日期为 **2026-07-16**。

## 1. 学完后必须留下什么证据

1. **解释证据**：在 120 秒内说清前测/后测循环、初始化、条件、循环体、更新、计数器、累加器、哨兵、`break`、`continue`、循环不变量和终止量。
2. **构建证据**：不用数组和集合，分别写出 0..N 有界循环、倒计时 while、至少执行一次的 do-while、哨兵循环，以及跳过一项和提前停止的路径；记录固定输入与结果。
3. **诊断证据**：注入 `<`/`<=` 边界错误、错误累计、遗漏状态更新和错误 break 位置，用每轮轨迹找到第一处偏差，修复后复跑 N=0、1、4。

配套工件：

- [循环状态观察台](../../../examples/encyclopedia/ch.java.loops/README.md)
- [0、1、N 与终止边界实验](../../../labs/encyclopedia/ch.java.loops/README.md)
- [公开独立练习：维修批次循环](../../../exercises/encyclopedia/ch.java.loops/README.md)

先完成公开练习的第一次尝试，再核对私有解析。配套故障探针带固定安全预算，不会真的无限运行；不要擅自在无保护情况下启动故意死循环。

## 2. 前置自检：循环由条件和分支组成

开始前应能预测：

```java
int i = 1;
System.out.println(i <= 3); // true
i++;
System.out.println(i <= 3); // true
i = 4;
System.out.println(i <= 3); // false
```

还应理解：`if` 只决定一次路径，`while` 会在条件为真时回到条件处再次判断；`break` 让控制流离开当前循环；局部变量有代码块作用域。若 `&&`、`if/else`、边界闭开区间仍不稳定，先回到分支章节。

本章偶尔在循环体里使用 `if` 和 switch，但不会重新教授分支穷尽性。循环加入后，分支路径数量会放大：一个错误条件可能在每一轮重复。因此先把单轮规则写清，再包进循环。

## 3. 循环的五个组成部分

先不背语法，把任何有界循环拆成五问：

1. **初始状态**：第一次判断前，变化变量是什么值？
2. **继续条件**：什么情况下还要执行一轮？
3. **循环体**：这一轮做什么业务动作？
4. **状态更新**：哪个值在每轮变化，怎样靠近停止条件？
5. **循环后状态**：退出时能确定哪些事实？

例如从 1 打印到 3：

```java
int i = 1;
while (i <= 3) {
    System.out.println(i);
    i++;
}
System.out.println("after=" + i);
```

初始 i=1；条件 i<=3；循环体打印；更新 i++；退出后 i=4。逐轮表：

| 判断前 i | 条件 | 打印 | 更新后 i |
| ---: | --- | ---: | ---: |
| 1 | true | 1 | 2 |
| 2 | true | 2 | 3 |
| 3 | true | 3 | 4 |
| 4 | false | 不执行 | 不更新 |

循环体不是在 i=4 时执行完再退出，而是先判断 false，根本不进入该轮。这个顺序是理解 off-by-one 的核心。

## 4. for 循环：把有界计数写在同一行

标准形式：

```java
for (初始化; 继续条件; 更新) {
    循环体
}
```

等价思考顺序：初始化只执行一次；每轮前判断条件；条件为 true 执行循环体；正常完成一轮后执行更新；再回到条件。示例：

```java
int sum = 0;
for (int i = 1; i <= 3; i++) {
    sum += i;
}
System.out.println(sum); // 6
```

执行轨迹：

| 轮次 | 进入时 i | 进入前 sum | `sum += i` 后 | 更新后 i |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | 0 | 1 | 2 |
| 2 | 2 | 1 | 3 | 3 |
| 3 | 3 | 3 | 6 | 4 |

`int i` 在 for 头声明，它的作用域覆盖循环头和循环体，循环结束后通常不能在外面访问。若后续确实需要退出值，可以在外层声明，但不要只为调试扩大作用域；更简单的是记录业务结果或在循环内打印轨迹。

### 4.1 `i++`、`++i` 与本章边界

在 for 的独立更新位置，`i++` 与 `++i` 都会在下一次条件判断前把 i 加 1，通常结果相同。本章统一用 `i++`，不把自增嵌入更复杂表达式。把“更新”和“使用值”混在一行会增加预测负担，也容易让 AI 审查遗漏顺序问题。

### 4.2 何时优先选择 for

当开始前就知道计数边界，或明确写成“从 start 到 end，每次 step”时，for 把三项控制信息集中起来：处理 1..N、固定次数重试、倒数若干步。它并不要求一定递增，也不保证自动终止；若更新方向与条件不匹配，for 同样会无限执行。

## 5. 0、1、N：每个循环的最低边界验收

假设任务是处理编号 1..N：

```java
for (int i = 1; i <= n; i++) {
    processed++;
}
```

必须先手算：

| N | 第一次条件 | 执行次数 | 退出时事实 |
| ---: | --- | ---: | --- |
| 0 | `1 <= 0` false | 0 | processed 不变 |
| 1 | `1 <= 1` true | 1 | 处理编号 1 |
| 4 | true | 4 | 处理编号 1、2、3、4 |

N=0 不是“特殊到可以忽略”，而是最容易暴露错误初值和错误默认结果的边界。N=1 能暴露“条件写成 `< n`”而少做一次；N>1 才能验证更新与累计。至少这三类都符合预言，才有资格说循环边界基本正确。

## 6. `<` 与 `<=`：先写区间再选符号

“处理 1..N”中的两个端点都包含，应使用 `i = 1; i <= n`。若需求是“重复 N 次并让计数从 0 到 N-1”，则使用 `i = 0; i < n`。两种形式都正确，取决于计数代表什么：

```text
业务编号：1, 2, ..., N      -> 1 <= i <= N
次数索引：0, 1, ..., N-1    -> 0 <= i < N
```

不要因为看到别人常写 `< length` 就机械复制；数组还没学习，当前 i 是业务编号还是执行次数必须说清。混用起点 1 与条件 `< n` 会只执行 N-1 次，混用起点 0 与 `<= n` 会执行 N+1 次。

off-by-one（差一错误）通常编译、运行和退出码都正常。第一可信证据是逐轮轨迹或最终计数与手算不同，而不是错误日志。

## 7. while 循环：先判断，次数由状态决定

形式：

```java
while (继续条件) {
    循环体
}
```

while 没有专门的初始化和更新槽，它们必须在循环外与循环体里明确出现：

```java
int remaining = 3;
int steps = 0;

while (remaining > 0) {
    remaining--;
    steps++;
}

System.out.println("steps=" + steps);       // 3
System.out.println("remaining=" + remaining); // 0
```

while 是**前测循环**：第一次进入前就判断。若 remaining 初始为 0，循环体执行 0 次。它适合“只要还有剩余就继续”“直到状态达到哨兵前持续处理”等次数由状态决定的场景。

while 并不天然比 for 更灵活，也不天然更危险。危险来自控制状态分散：初始化可能在十行前，更新可能藏在分支里。审查时把这三处圈出来，并证明每条会继续的路径最终都更新状态。

### 7.1 多条路径都必须推进

```java
while (remaining > 0) {
    if (remaining == 2) {
        continue;
    }
    remaining--;
}
```

当 remaining=2 时，`continue` 直接回到条件，跳过 `remaining--`；状态永远是 2，循环不终止。修复可以把必要更新放在 continue 前，也可以重写条件结构。关键不是“continue 不好”，而是每条回到循环头的路径都要推进终止状态。

## 8. do-while：先执行一次，再判断是否继续

```java
int attempts = 0;
do {
    attempts++;
} while (attempts < 1);
```

do-while 是**后测循环**。即使继续条件一开始就为 false，循环体也执行一次。语法最后的 `while (...);` 带分号，这是结构的一部分，不是多余空语句。

适用语义是“至少做一次，然后决定是否再做”，例如至少展示一次菜单、至少尝试一次固定操作。不要仅为了展示语法把本应允许 0 次的任务改成 do-while。若 N=0 时业务要求不处理任何工单，for 或 while 更符合契约。

对比表：

| 初始条件 | while 执行次数下限 | do-while 执行次数下限 |
| --- | ---: | ---: |
| false | 0 | 1 |
| true 后变 false | 1 | 1 |
| 一直 true | 均可能不终止 | 均可能不终止 |

## 9. 计数器与累加器不是同一种状态

**计数器**回答“发生了多少次”，通常每次加 1：

```java
int processed = 0;
for (int ticket = 1; ticket <= 4; ticket++) {
    processed++;
}
```

**累加器**回答“各项值的总和是多少”，每次加入当前贡献：

```java
int priorityTotal = 0;
for (int priority = 1; priority <= 4; priority++) {
    priorityTotal += priority;
}
```

四轮后 processed=4，priorityTotal=10。常见错误是把累加器写成 `priorityTotal++`，结果只得到项数；或把计数器写成 `processed += ticket`，结果变成总和。变量名和初值应表达角色。

### 9.1 初值来自“还没处理任何项”的数学身份

计数和加法累积通常从 0 开始，因为尚未发生时次数和总和都是 0。不要为了让某个样例通过从 1 开始补偿边界错误。乘法累积会有不同身份值，但不属于本章主要任务。

若结果类型可能溢出，应回到表达式章节选择 `long` 或精确检查。循环会重复运算，更容易把小误差和范围风险放大；循环语法不会自动扩大类型。

## 10. 循环不变量：每轮前后都保持为真的关系

循环不变量不是 Java 关键字，而是用来解释正确性的陈述。例如累加 1..N 时，在每轮开始前：

```text
sum 等于已经处理过的所有编号之和；
count 等于已经处理过的编号数量；
i 是下一项尚未处理的编号。
```

初始时还没处理任何项，sum=0、count=0、i=1，陈述成立。循环体把 i 加入 sum 并增加 count，更新后 i 指向下一项，陈述继续成立。退出时 i>N，结合不变量可得所有 1..N 都处理完，sum 是完整总和。

写不变量的价值：

- 能发现累计写在错误分支里；
- 能判断 `continue` 是否跳过必要动作；
- 能解释循环结束后结果为什么可信；
- 让代码审查从“看起来对”变成可验证关系。

零基础阶段不要求形式化证明。先用一句自然语言和 N=0、1、4 的轨迹验证即可。

## 11. 终止量：必须向一个有界终点单向靠近

循环终止需要的不只是“写了条件”。还要有一个可观察量每轮朝退出方向变化，并且不能无限越过：

```java
int remaining = 3;
while (remaining > 0) {
    remaining--;
}
```

remaining 是终止量：非负，且每轮减 1，最终到 0。反例：

```java
while (remaining > 0) {
    processed++;
}
```

改变了 processed，却没有改变控制条件读取的 remaining。代码可以编译，也不会自动抛异常，只会持续运行。诊断时问“条件读取哪些变量，循环体在哪条路径更新它们”，比搜索 `++` 更准确。

实际无限循环可能占用 CPU、持续写日志或阻塞流水线。本章的探针设置固定安全步数并主动非零退出，用来获取证据；不要用 Ctrl+C 后一句“它卡住了”代替可重放诊断。

## 12. 哨兵循环：遇到一个特殊值时结束

**哨兵值**是数据流中专门表示“结束、没有下一项或停止”的值。为了不提前引入控制台输入和数组，本章用固定整数状态观察：

```java
int nextTicket = 3;
int processed = 0;

while (nextTicket != 0) {
    processed++;
    nextTicket--;
}

System.out.println("processed=" + processed); // 3
System.out.println("sentinel=" + nextTicket); // 0
```

这里 0 是实验约定的结束标记，不代表所有系统都应拿 0 当哨兵。真实输入可能用 `END`、EOF 或“无下一项”的协议状态，后续输入章节会建立边界。

哨兵本身通常不算业务项。判断发生在处理之前，所以 nextTicket=0 时执行 0 次。若把处理动作写在读取/判断之前，可能把结束标记错误计入；若循环体从不让 nextTicket 接近 0，则永不结束。

审查哨兵循环的四问：

1. 哨兵是否可能与合法业务值冲突？
2. 第一次判断前是否已有明确状态？
3. 哨兵是否在业务处理前被识别？
4. 每轮如何取得或产生下一个状态？失败路径会更新吗？

## 13. break：立即离开当前循环

```java
int stoppedAt = 0;
for (int ticket = 1; ticket <= 6; ticket++) {
    if (ticket == 5) {
        stoppedAt = ticket;
        break;
    }
    System.out.println("processed=" + ticket);
}
```

输出 1、2、3、4，遇到 5 后记录停止位置并离开；循环体中 break 后的语句和后续轮次都不执行。控制流继续到循环之后，而不是结束整个程序。

break 适合“已经找到目标”“收到停止信号”“继续处理没有意义”。它改变了循环正常退出条件，因此验收要区分：是因为 `ticket > 6` 自然结束，还是在 5 提前停止？记录 stoppedAt 可以让原因可见。

错误位置会造成多处理或少处理：

```java
processed++;
if (ticket == 5) {
    break;
}
```

如果规则是“5 不应处理”，把 break 放在 processed++ 后就晚了一步。第一可信证据是 processed 计数或总和多出 5，而不是 break 关键字本身。

## 14. continue：跳过本轮剩余部分，继续下一轮

```java
int skipped = 0;
for (int ticket = 1; ticket <= 4; ticket++) {
    if (ticket == 2) {
        skipped++;
        continue;
    }
    System.out.println("processed=" + ticket);
}
```

编号 2 不执行后面的打印，for 会先执行更新 `ticket++`，再判断下一轮条件。因此输出 1、3、4，skipped=1。

在 while 中没有自动更新槽：

```java
while (ticket <= 4) {
    if (ticket == 2) {
        continue; // 若此前没有 ticket++，会永远停在 2
    }
    ticket++;
}
```

所以同一个 continue 在 for 与 while 中可能有不同终止风险。它们都跳过本轮剩余语句，但 for 的更新表达式仍会执行，while 只执行你显式写出的更新。

continue 太多会把循环体切成难以追踪的路径。简单场景也可以用 if 包住正常处理。选择依据不是“少写几行”，而是跳过语义是否明确、必要更新是否在所有路径发生。

## 15. break、continue 与分支顺序

FactoryCare 规则：编号 2 暂时跳过；编号 5 是全局停止；其余处理。若检查顺序为：

```java
if (ticket == 2) {
    continue;
}
if (ticket == 5) {
    break;
}
processed++;
```

对当前固定值没有冲突。但若未来“停止编号也可能被标为跳过”，两个条件先后就会改变结果。每个控制转移都应有优先级规则。可以写路径表：

| ticket | skip 条件 | stop 条件 | 动作 |
| ---: | --- | --- | --- |
| 1 | false | false | 处理 |
| 2 | true | 不检查 | 跳过 |
| 3 | false | false | 处理 |
| 4 | false | false | 处理 |
| 5 | false | true | 停止 |

路径表还能验证累计：processed=3，skipped=1，stoppedAt=5，总和 1+3+4=8。

## 16. 循环中使用 switch：一轮只处理一个当前状态

本章目标 outcome 要求综合上一章分支。可以在每轮按当前编号推导一个有限标签，再用 switch 记录动作：

```java
for (int priority = 1; priority <= 3; priority++) {
    String action = switch (priority) {
        case 1 -> "QUEUE";
        case 2 -> "ASSIGN";
        case 3 -> "ESCALATE";
        default -> "REJECT";
    };
    System.out.println(priority + ":" + action);
}
```

循环负责“处理哪一轮”，switch 负责“这一轮选哪个动作”。不要把职责混成一个不断修改循环变量的 switch；控制变量的更新最好集中在 for 头或一个清晰位置。

若 switch 漏状态，可能每一轮都把某类输入送入 default。诊断时先确认循环是否到达该编号，再确认分支是否命中；不要看到最终计数错就同时重写循环和 switch。

## 17. FactoryCare 最小批次：1..N、跳过、停止、计数与累积

```java
public class MaintenanceBatch {
    public static void main(String[] args) {
        int n = 5;
        int processed = 0;
        int skipped = 0;
        int stoppedAt = 0;
        int priorityTotal = 0;

        for (int ticket = 1; ticket <= n; ticket++) {
            if (ticket == 2) {
                skipped++;
                continue;
            }
            if (ticket == 5) {
                stoppedAt = ticket;
                break;
            }
            processed++;
            priorityTotal += ticket;
        }

        System.out.println("processed=" + processed);
        System.out.println("skipped=" + skipped);
        System.out.println("stoppedAt=" + stoppedAt);
        System.out.println("priorityTotal=" + priorityTotal);
    }
}
```

先逐轮预测：

| ticket | 进入 processed | 动作 | 离开 processed | total |
| ---: | ---: | --- | ---: | ---: |
| 1 | 0 | 处理 | 1 | 1 |
| 2 | 1 | skipped++，continue | 1 | 1 |
| 3 | 1 | 处理 | 2 | 4 |
| 4 | 2 | 处理 | 3 | 8 |
| 5 | 3 | stoppedAt=5，break | 3 | 8 |

退出后不变量：processed 等于真正完成处理的项数；skipped 等于显式跳过数；priorityTotal 只含已处理编号；stoppedAt 记录提前结束原因。它没有证明所有 1..N 都处理过，因为 break 明确提前停止。

## 18. 嵌套循环为何暂不作为主线

循环体里可以再写循环，但执行次数会相乘，边界和变量作用域也更容易混淆。例如三轮外层、两轮内层会执行六次。二维数组、表格坐标和成对组合会在后续章节给出真实需求。

本章若看到嵌套，只需能画出少量轨迹，不要求设计复杂算法。不要为了“练高级”提前写三层循环；当前验收重点是单循环的 0、1、N、状态更新和终止证明。

## 19. 五类常见故障

### 19.1 off-by-one：少一次或多一次

需求处理 1..4，错误写成 `i < 4`，实际只处理 1、2、3。程序退出 0。第一可信证据是 count=3 或轨迹缺少 4。修复比较符后复跑 N=0、1、4，避免只让当前样例碰巧通过。

### 19.2 更新方向错误

```java
for (int i = 1; i <= 4; i--) {
    // i 越来越小，条件始终为真
}
```

条件要求 i 最终大于 4，更新却让它远离终点。看到 `i--` 本身不能断定错误；要结合条件和起点判断终止量方向。

### 19.3 累计变量错位

应写 `sum += i` 却写 `sum++`，执行次数正确、总和错误。把 count 和 sum 同时打印，可以定位“循环次数正确，单轮贡献错误”。若两者都错，先找第一轮开始偏离的位置。

### 19.4 哨兵或 while 状态不更新

条件读取 sentinel，但循环体只改 processed。程序不终止。实验探针在第五步打印 `LOOP_BUDGET_EXCEEDED sentinel=2 safetySteps=5` 并非零退出。第一可信证据是 sentinel 多轮保持 2，而不是“电脑变慢”。

### 19.5 break/continue 位置错误

先累计再 break 会多算停止项；while 中先 continue 再更新会停在同一项。画出控制转移箭头，标出被跳过的语句，比反复加随机打印更有效。

## 20. 安全诊断无限循环

不要在没有保护的脚本、CI 或共享环境里故意运行 `while (true)`。本章采用**步数预算**：

```java
int safetySteps = 0;
while (remaining > 0) {
    safetySteps++;
    // 故意缺 remaining--
    if (safetySteps == 4) {
        System.err.println("NON_TERMINATING_GUARD remaining=" + remaining);
        System.exit(4);
    }
}
```

这不是生产超时方案，只是教学探针。它把“可能永远运行”转换成有限、可重放的非零失败。诊断记录应包含初始状态、条件、每轮更新、预算触发值和修复后的正常退出。

若真实程序已经卡住，先停止进程并保留最小证据，再在副本中添加受控预算。不要为了看更多日志让无限循环持续写满磁盘。

## 21. 日志轨迹：只记录能定位第一处偏差的状态

调试可暂时输出：

```java
System.out.println(
        "iteration=" + steps
        + " ticket=" + ticket
        + " processed=" + processed
        + " sum=" + sum
);
```

理想轨迹包含轮次、控制变量、关键累计和路径标签。若每轮打印几十个无关变量，第一处偏差会淹没。固定小 N=4 最适合观察；确认后删除或降低调试输出，避免真实系统日志膨胀。

诊断顺序：先核对初始状态；再看第一次条件；再看第一轮体与更新；找到第一次实际值不同于手算的地方后停止扩散；做最小修复；用原边界表复跑。最终值错误往往只是早期偏差累积的结果。

## 22. 实验闭环

进入[0、1、N 与终止边界实验](../../../labs/encyclopedia/ch.java.loops/README.md)。

### 22.1 预测表

运行前手写：N=0 的 count/sum；N=1；N=4；while 从 3 到 0 的步数；do-while 初始条件不满足时的次数；哨兵和 break/continue 的最终状态。

### 22.2 运行

```bash
cd labs/encyclopedia/ch.java.loops
./verify.sh
```

有效证据至少包含七行正常输出、`assertions=10 passed`、`LOOP_BUDGET_EXCEEDED` 的非零预期失败和 `LAB PASS`。预期失败属于验收组成，不应删除探针来获得全绿。

### 22.3 修改

选择一项：把 N=4 改成 5并手算 15；把哨兵从 3 改成 4；把跳过编号从 2 改成 3；把停止编号从 5 改成 6并同步上界。每次只改一组契约相关值，保存预测、实际和恢复结果。

### 22.4 故障—修复—复跑

删除一次必要更新，或把 `<=` 改成 `<`。先判断是少一次、无限循环还是错误累计，再运行受控验证。修复后完整复跑，而不是只运行一个 class。

## 23. 公开练习与无 AI 训练

进入[维修批次循环](../../../exercises/encyclopedia/ch.java.loops/README.md)，关闭 AI，限时 25 分钟。起始代码有三处错误，但会终止，便于你从四行输出反推边界、break 和计数更新。

提交证据：

- 错误版本四行预测与实际；
- 三处最小修改及各自影响；
- 正确的 `processed=3`、`skipped=1`、`stoppedAt=5`、`totalPriority=8`；
- 把停止编号扩为 6 后的手算；
- 说明为什么不能直接运行无保护的“删除 ticket++”版本；
- 60 秒口述一个循环不变量和一个终止量。

如果不会写，先画 1..5 路径表，不要让 AI 直接输出答案。完成后可让 AI 审查“是否有未推进路径”，但每项结论都要用 N=0、1、5 或步数轨迹验证。

## 24. AI 协作审查清单

面对 AI 生成循环，逐项问：

1. 计数代表业务编号还是零起点次数？
2. 需要执行 0 次吗？N=0 时实际怎样？
3. 条件是开区间还是闭区间，端点依据是什么？
4. 哪些变量出现在继续条件中？每条回边路径都更新了吗？
5. counter、accumulator 和 sentinel 初值各自为什么正确？
6. `continue` 跳过了哪些语句？for 更新是否仍执行？
7. `break` 在累计前还是后，停止项应不应该计入？
8. 用什么不变量解释结果？用什么单调量解释终止？
9. 大 N 会不会使数值溢出或日志爆炸？
10. 哪些行为经过运行验证，哪些只是模型声称？

需求变更提示词应包含旧边界、新边界和固定 oracle。例如：“停止编号从 5 改为 6，保持编号 2 跳过；先列受影响输入和新总和，再给最小改动。”不要用“优化循环”授权整段重写。

## 25. 120 秒复述模板

> 循环在条件为真时重复控制流。任何循环都要找到初始状态、继续条件、循环体、状态更新和退出后事实。for 把初始化、条件、更新放在头部，适合明确的有界计数；while 在每轮前判断，适合由状态决定次数；do-while 在循环体后判断，所以至少执行一次。counter 统计次数，accumulator 汇总每轮贡献，sentinel 表示结束。break 离开当前循环，continue 跳过本轮剩余内容；for 的 continue 之后仍执行更新，而 while 没有自动更新。正确性用 N=0、1、N 和循环不变量检查，终止性用一个每轮朝有界终点推进的量解释。编译成功和退出 0 不能发现 off-by-one 或错误累计；遗漏更新甚至可能一直运行，所以要用小输入轨迹和安全步数预算诊断。

再给一个反例：while 条件读取 remaining，但循环体只增加 processed，remaining 不变，因此没有终止进展。第一可信证据是受控轨迹中 remaining 连续保持同值。

## 26. 自测题

1. `for (int i=1; i<=3; i++)` 的判断、循环体、更新顺序是什么？
2. 上述循环执行几次，退出前最后一次条件读取的 i 是多少？
3. N=0 时 `i=1; i<=n` 为什么执行 0 次？
4. 处理 0..N-1 与 1..N 分别怎样写，二者有什么语义差异？
5. while 与 do-while 在初始条件 false 时有何不同？
6. counter 和 accumulator 的初值与更新分别表达什么？
7. 写出累加 1..N 的一句自然语言不变量。
8. 什么是终止量？条件中出现变量是否就保证终止？
9. 哨兵为什么通常不应作为业务项处理？
10. for 中遇 continue 后更新表达式是否执行？while 呢？
11. break 放在累计前后会怎样改变结果？
12. `<` 写成 `<=` 可能出现多少次差异，为什么通常没有错误日志？
13. 如何安全验证遗漏更新，而不真的让程序无限运行？
14. count 正确但 sum 错，首先检查哪一类语句？
15. 编译成功、退出 0 为什么不能证明循环正确？
16. 若循环体含 switch，怎样区分“没到该轮”和“到了但分错支”？

每题至少给一个具体 N 或轨迹。只说“for 是循环次数固定”不够，因为错误更新仍可能不终止。

## 27. 间隔复习

| 时间 | 任务 | 通过证据 |
| --- | --- | --- |
| 当天 | 观察台、实验、公开练习 | 正常轨迹、预期非零失败、独立修复齐全 |
| 第 1 天 | 不看书写出 for 执行顺序 | 能解释 0、1、4 次边界 |
| 第 3 天 | 用 while 重写一个 for，保持输出 | 两版边界与终止解释一致 |
| 第 7 天 | 注入 `<`、错累计、漏更新、错 break | 找到第一次偏差并最小修复 |
| 第 14 天 | 审查 AI 生成批处理 | 标出不变量、终止量和未覆盖路径 |
| 第 30 天 | 在数组或项目循环中迁移 | 新数据来源下仍能证明边界和退出 |

## 28. 速查表

### 28.1 形式选择

```text
明确 start/end/step 的有界计数 -> for
次数由状态或哨兵决定          -> while
必须先执行一次再判断          -> do-while
跳过当前项                    -> continue
提前结束整个当前循环          -> break
```

### 28.2 循环检查清单

```text
初始状态是什么？
第一次条件为 true 还是 false？
边界包含端点吗？
每轮业务动作是什么？
counter 与 accumulator 各更新什么？
continue/break 跳过哪些语句？
每条回到条件的路径都推进了吗？
什么不变量在每轮保持？
什么量单调逼近退出？
N=0、1、多项分别执行几次？
自然退出与提前退出怎样区分？
固定 oracle 检查了结果还是只看退出码？
```

### 28.3 现象到首查位置

| 现象 | 首先检查 |
| --- | --- |
| 少处理最后一项 | 起点 1 时是否误用 `< n` |
| 多处理一项 | 起点 0 时是否误用 `<= n` |
| 循环停不下来 | 条件变量是否在每条路径推进 |
| 停在某一个值 | 该值触发的 continue 是否跳过更新 |
| 次数正确、总和错误 | accumulator 是否加入当前贡献 |
| 停止项被计入 | break 是否放在累计之后 |
| do-while 多执行一次 | 需求是否其实允许 0 次 |
| 日志无限增长 | 是否缺少终止进展和诊断预算 |

## 29. 术语表

| 术语 | 本章定义 |
| --- | --- |
| iteration | 循环体的一次执行，也称一轮 |
| 初始化 | 第一次判断前建立循环控制状态 |
| 继续条件 | 为 true 时允许进入下一轮的布尔表达式 |
| 更新 | 一轮后改变控制状态的操作 |
| 前测循环 | 进入循环体前判断，如 for、while |
| 后测循环 | 执行循环体后判断，如 do-while |
| counter | 统计事件或处理项数量的变量 |
| accumulator | 汇总每轮贡献的变量 |
| sentinel | 表示停止或没有下一项的特殊值 |
| off-by-one | 循环次数或边界相差一的逻辑错误 |
| loop invariant | 初始化后、每轮前后都保持成立的关系 |
| termination variant | 每轮向有界终点推进、用于解释终止的量 |
| break | 立即离开当前循环 |
| continue | 跳过本轮剩余语句，转向下一轮控制点 |
| safety budget | 教学诊断中限制故障循环步数的固定保护 |

## 30. 本章明确不教什么

本章不把数组、二维数组、集合、迭代器、Stream、递归、控制台 Scanner、文件读取、并发循环、定时任务、重试退避和复杂算法作为数据来源或主任务；这些各有后续章节。只在固定 `main` 中使用整数和 String 状态，也不抽取方法或设计对象。

本章不追求“最短循环”或微观性能技巧。先保证边界、状态角色、不变量和终止都可解释。无限服务循环、线程中断与资源生命周期属于并发和生产化内容，不能拿本章安全步数探针直接代替。

## 31. JDK 25 官方来源

以下官方资料复核日期为 **2026-07-16**：

- [Java Language Specification 25, §14.14 The `for` Statement](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html#jls-14.14)：基本 for 的初始化、条件、更新和执行顺序。
- [Java Language Specification 25, §14.12 The `while` Statement](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html#jls-14.12)：前测 while 的条件与循环体语义。
- [Java Language Specification 25, §14.13 The `do` Statement](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html#jls-14.13)：后测 do-while 至少执行一次的语义。
- [Java Language Specification 25, §14.15 The `break` Statement](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html#jls-14.15)：break 的控制转移边界。
- [Java Language Specification 25, §14.16 The `continue` Statement](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html#jls-14.16)：continue 对 while、do 与 for 继续点的影响。
- [Java Language Specification 25, §14.22 Unreachable Statements](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html#jls-14.22)：编译器可判定的不可达语句边界；它不等于一般终止证明。

规范说明语言行为，实验说明当前代码是否符合你的业务预言。先用小 N 逐轮观察，再回官方条款确认执行顺序；若 AI 或博客与 JDK 25 的可重复行为冲突，以官方规范和实际证据为准。
