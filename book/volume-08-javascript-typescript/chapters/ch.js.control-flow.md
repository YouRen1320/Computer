---
schema_version: 2
edition: 2026.2-draft
id: ch.js.control-flow
title: 条件、switch、循环与控制转移
responsibility: 用布尔条件、互斥分支和有界循环表达选择与重复，明确 break/continue 的局部控制边界，不引入函数或集合抽象。
volume: '08'
order: 4
level: L1
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.js.control-flow.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.js.values-operators
version_surfaces:
- node-24-lts
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“条件、switch、循环与控制转移”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - js-branching
  - js-loops-control
  covers_topics:
  - js.truthiness
  - js.boolean-expression
  - js.if-else
  - js.switch
  - js.for-loop
  - js.while-loop
  - js.for-of-intro
  - js.break-continue
  uses_capabilities:
  - foundation.toolchain-env-build
  - foundation.verification-debug-test
  - web.javascript-language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现含边界校验、互斥分支和有界循环的工单优先级脚本；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - js-branching
  - js-loops-control
  covers_topics:
  - js.truthiness
  - js.boolean-expression
  - js.if-else
  - js.switch
  - js.for-loop
  - js.while-loop
  - js.for-of-intro
  - js.break-continue
  uses_capabilities:
  - foundation.toolchain-env-build
  - foundation.verification-debug-test
  - web.javascript-language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: prediction-boundary-table-assertion-script
- id: diagnose
  kind: fault-diagnosis
  text: 面对“truthiness 误用、遗漏分支或循环边界偏一”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - js-branching
  - js-loops-control
  covers_topics:
  - js.truthiness
  - js.boolean-expression
  - js.if-else
  - js.switch
  - js.for-loop
  - js.while-loop
  - js.for-of-intro
  - js.break-continue
  uses_capabilities:
  - foundation.toolchain-env-build
  - foundation.verification-debug-test
  - web.javascript-language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 条件、switch、循环与控制转移

到目前为止，程序只会从上到下执行每一条语句。真实程序还要选择：输入非法时拒绝，分数达到阈值时分配优先级，重试次数为零时一次都不执行，多次时重复固定动作。控制流就是把“哪些语句会执行、执行多少次、在哪里停止”写成可预测的结构。

控制流最容易制造两种假象：某个示例输入恰好走对分支，于是遗漏路径没有暴露；循环在常用次数下结束，于是零次、最大次数或偏一错误没有暴露。本章以边界表为核心：每个分支先列互斥条件，每个循环先列零次、一次、多次和非法输入，再运行脚本与断言。函数、数组等集合抽象留给后续章节，避免一次引入太多移动部件。

## 学完以后，你应当能交出什么

你需要证明：

1. 在 120 秒内解释 truthiness、布尔表达式、`if/else`、`switch`、`for`、`while`、`for...of`、`break` 和 `continue` 的职责与局部边界；
2. 从空目录实现含输入校验、互斥优先级分支和有界重复的 FactoryCare 教学脚本，保存零次、一次、多次、非法输入四类预言与实测结果；
3. 分别注入 truthiness 误用、遗漏分支和循环边界偏一，找到第一个失败案例与对应控制点，单点修复后重跑同一边界表；
4. 明确反例：JavaScript 前端分支不能授权工单状态迁移，Java 后端的权限、版本、唯一状态机、审计与事务仍是权威。

canonical 验证级别为 T1。一个默认示例绿色不算完成；边界表里的每一行都必须有固定输入、预期 stdout/stderr/退出码，并由断言或字节比较验证。

## 前置：条件依赖可信值

控制流不会修复类型错误。若表单给出字符串 `"0"`，`if (rawCount)` 会因为非空字符串而进入 truthy 分支；这不是 `if` 语法错，而是输入未显式转换。进入本章前应能：

- 用 `Number(...)` 显式转换文本，并用 `Number.isFinite`/`Number.isInteger` 和范围验证；
- 默认使用 `===`/`!==`，不用宽松相等猜输入；
- 区分 `null`、`undefined`、`0`、`false`、`""` 与 `NaN`；
- 使用 `??` 只处理 nullish 缺失；
- 在运行前写值与类型预言。

本章所有条件都从已命名、已转换的值构造。若你无法说明条件两侧的类型，先回到上一章值矩阵，不要靠多加分支碰碰运气。

## 控制流地图

```text
输入边界
  ↓ 显式转换与有效性布尔表达式
选择
  ├── if / else if / else：范围、复合条件、互斥路径
  └── switch：一个离散值对应多个 case
重复
  ├── for：已知计数与显式更新
  ├── while：条件满足期间重复，进度必须可证明
  └── for...of：按顺序读取一个可迭代值
局部转移
  ├── break：离开最近的循环或 switch
  └── continue：跳过当前轮剩余语句，进入下一轮
```

控制流只改变语句执行路径，不改变值转换与业务权限规则。每一个箭头都应能在边界表或输出轨迹中观察。

## truthiness：条件位置会执行 ToBoolean

`if (expression)` 不要求表达式本来就是 Boolean；语言会把结果转成布尔意义。这个规则称为 truthiness。以下常规值是 falsy：

```text
false
0
-0
0n
""（空字符串）
null
undefined
NaN
```

除规范中的浏览器历史特殊对象外，其他普通值都是 truthy：非零数字、非空字符串（包括 `"false"` 和 `"0"`）、对象、数组和函数都 truthy。浏览器遗留的 `document.all` 有特殊兼容语义，不应出现在新业务判断中。

```js
// 字符串 "0" 来自未转换输入，它非空，因此 truthy。
const rawRetryCount = "0";

// Boolean 只展示 truthiness，不证明输入满足数值合同。
console.log(Boolean(rawRetryCount)); // true
console.log(Boolean(0));             // false
```

truthiness 适合判断“这个值是否按语言规则为真”，不适合自动回答“字段是否提供”“数字是否合法”“集合是否非空”或“权限是否存在”。对象即使没有任何业务属性也 truthy；字符串 `"false"` 也 truthy。输入边界应使用精确条件。

### 把业务问题写成布尔表达式

好的条件可以读成一句完整问题：

```js
// score 已在边界转换；该表达式明确验证有限整数和闭区间 0..100。
const scoreIsValid = Number.isInteger(score) && score >= 0 && score <= 100;
```

逻辑与 `&&` 从左到右短路：左侧 falsy 时不再求值右侧；逻辑或 `||` 左侧 truthy 时不再求值右侧。它们返回被选中的操作数，不保证返回 Boolean，但比较表达式本身会产生 Boolean。将复杂条件先命名，可以输出 `scoreIsValid` 并定位哪个原子条件失败。

不要把重要副作用藏在短路右侧，例如 `isValid && console.log(...)`。虽然合法，却把选择和输出混成表达式，初学时不利于证据追踪。本章用完整块语句表达行为。

### 否定运算符

`!value` 先取 truthiness 再取反，结果一定是 Boolean；`!!value` 常用于显式布尔化。它不等于业务验证。`!retryCount` 会同时匹配 0 和 NaN，若 0 合法就会误判。更清楚的条件是 `Number.isInteger(retryCount) && retryCount >= 0`。

## `if`、`else if`、`else`：有顺序的互斥选择

最小形式：

```js
// 条件为 true 时执行花括号内语句，否则跳过整个块。
if (score >= 80) {
  console.log("priority=P1");
}
```

花括号即使块里只有一条语句也保留。这样未来添加日志不会意外落在分支之外，diff 也更清楚。

二选一：

```js
// 已验证 score 后，两条路径恰好执行一条。
if (score >= 80) {
  console.log("priority=P1");
} else {
  console.log("priority=NORMAL");
}
```

多级互斥分支按源码顺序检查；命中第一项后跳过后续：

```js
// 阈值从高到低排列，确保每个有效分数只落入一个优先级。
let priority = "P3";
if (score >= 80) {
  priority = "P1";
} else if (score >= 50) {
  priority = "P2";
} else {
  priority = "P3";
}

// 输出是互斥分支的可观察预言。
console.log(`priority=${priority}`);
```

顺序很重要。如果先写 `score >= 50`，90 会在第一项就命中 P2，永远到不了 P1。调试时列区间，而不是只看条件文字：

| 分支 | 实际覆盖区间（已验证 0..100） |
| --- | --- |
| `score >= 80` | 80..100 |
| `score >= 50` | 50..79 |
| `else` | 0..49 |

边界样例至少包含 79/80、49/50 和非法值。只有 90、60、20 三个“典型值”不能证明阈值边界没有偏一。

### 先校验，再分类

非法输入不应被 `else` 悄悄归为最低优先级：

```js
// rawScore 来自 Node 命令行文本；先显式转换再判断业务范围。
const score = Number(process.argv[2]);
const scoreIsValid = Number.isInteger(score) && score >= 0 && score <= 100;

// 非法路径与分类路径互斥，避免 NaN 落入 P3。
if (!scoreIsValid) {
  console.log("result=INVALID_SCORE");
  process.exitCode = 2;
} else if (score >= 80) {
  console.log("priority=P1");
} else if (score >= 50) {
  console.log("priority=P2");
} else {
  console.log("priority=P3");
}
```

设置 `process.exitCode` 是 Node 宿主证据，不是浏览器 API。它允许输出稳定错误结果并在自然结束时返回非零。浏览器页面需用 UI 状态、测试运行器或网络合同表达失败，不能直接复制 `process`。

## `switch`：按一个离散值匹配 case

当一个已验证的离散值对应多个清晰类别时，`switch` 可比长串严格相等更直观：

```js
// priority 已由前面的互斥阈值分支得到。
let queue = "standard";
switch (priority) {
  case "P1":
    queue = "emergency";
    break;
  case "P2":
    queue = "expedited";
    break;
  case "P3":
    queue = "standard";
    break;
  default:
    queue = "invalid";
    break;
}

// queue 是 switch 结果的唯一输出合同。
console.log(`queue=${queue}`);
```

`switch` 先求值判别表达式，再按严格相等语义寻找匹配 case。数字 `1` 不会匹配字符串 `"1"`。case 标签不是自动范围表达式，因此 `case score >= 80` 这种写法会把布尔 case 与数字 score 比较，不是区间分类方案；范围应使用 `if/else if`。

### `break` 与贯穿

匹配 case 后，若没有 `break` 或其他离开结构的转移，执行会继续进入后续 case 的语句，这叫 fall-through。它有合法用途，例如多个状态共享同一展示组：

```js
// CREATED 与 TRIAGED 在本教学投影中共享“待调度”标签，故意贯穿到同一赋值。
let stageLabel = "未知";
switch (status) {
  case "CREATED":
  case "TRIAGED":
    stageLabel = "待调度";
    break;
  default:
    stageLabel = "其他";
    break;
}
```

故意贯穿应以注释解释；意外漏 `break` 会覆盖前一个结果或执行额外副作用。每个 switch 应考虑 `default`。即使上游声称值已穷尽，运行时仍可能收到新版本或脏数据；default 可产生明确故障证据，而不是静默沿用旧值。

不要用 switch 复制 FactoryCare 后端状态机。前端可以映射 12 个已知状态的显示标签，却无权决定哪个迁移合法。增加 `case "CLOSED": status="IN_PROGRESS"` 不能实现合法重开。

## 重复之前先写循环合同

每个循环都应回答四个问题：

1. 初始状态是什么？
2. 继续条件是什么？
3. 每轮产生什么可观察行为？
4. 哪个进度量保证最终结束？

再列边界：次数为 0 时循环体应执行零次；为 1 时一次；为 3 时三次；非法或超上限时应在进入循环前拒绝。无限循环常不是语法错误，而是继续条件始终为真或进度变量没有向终止方向变化。

## `for`：计数循环的三段合同

```js
// retryCount 已验证为 0..3 的整数；index 从 0 开始，每轮加 1。
for (let index = 0; index < retryCount; index += 1) {
  // 输出轮次使用 index + 1，避免把人类编号与零基索引混淆。
  console.log(`retry=${index + 1}`);
}
```

头部三段分别是：初始化 `let index = 0`，每轮前检查 `index < retryCount`，每轮结束执行 `index += 1`。当 retryCount 为 0，第一次检查就是 `0 < 0` false，循环体零次；为 1 时只执行 index=0；为 3 时执行 0、1、2。

最常见 off-by-one 是把 `<` 写成 `<=`。若 retryCount 表示“总共执行几次”，`index <= retryCount` 会执行 retryCount+1 次。不要凭最后一行判断，边界表要记录输出行数和每轮编号。

计数器名字应表达含义。`i` 在极短循环中常见，但教材优先 `attemptIndex`、`position`。更新表达式必须实际改变继续条件相关状态；漏掉更新会无限循环。验收脚本应限制输入上界，并由外层测试超时防护，但超时只是最后护栏，不替代终止证明。

## `while`：条件驱动，进度写在循环体中

当进入前知道继续条件，却不自然地写成固定计数头部时使用 `while`：

```js
// remainingRetries 是已验证的小整数；每轮都减 1，形成终止度量。
let remainingRetries = retryCount;
while (remainingRetries > 0) {
  console.log(`remaining=${remainingRetries}`);
  remainingRetries -= 1;
}
```

`while` 在每轮前检查条件，所以也可以执行零次。与 for 相比，初始化和更新散落在外部/循环体，更容易漏进度。阅读时圈出所有可能影响条件的语句，确认每条路径都向终止推进。

若写 `while (remainingRetries >= 0)`，初值 0 也会执行一次；若忘记减 1，就永不结束。故障诊断先记录最近几轮进度量，而不是立刻增大超时时间。

`do...while` 会先执行一次再检查，因此永远至少一次。canonical 主线不要求它；当业务合同允许零次时，普通 while 更直接。不要为了少写一行把零次语义改掉。

## `for...of`：按顺序读取可迭代值

`for...of` 逐个取得可迭代对象产生的值。本章不引入数组/集合抽象，使用字符串展示最小语义：

```js
// channelCodes 是固定教学字符串；for...of 按字符串迭代语义取得每个码点值。
const channelCodes = "SM";
for (const channelCode of channelCodes) {
  // 每轮绑定只读当前字符，输出顺序与源字符串一致。
  console.log(`channel=${channelCode}`);
}
```

输出两行：S、M。空字符串执行零次。`for...of` 取值，而 `for...in` 枚举属性键；二者不是换个介词的同义语法。遍历数组值通常用 for...of，但数组和迭代器细节留到集合章节。

字符串按 Unicode 码点迭代，比按索引读取 UTF-16 代码单元更适合观察完整字符，但字素簇仍可能由多个码点组成。UI 字符计数是更深问题，本章只使用 ASCII 代码避免混淆。

## `break`：离开最近的循环或 switch

```js
// 扫描固定状态码文本，遇到分隔符后终止最近的 for...of。
for (const character of "P1:URGENT") {
  if (character === ":") {
    break;
  }
  console.log(`prefix=${character}`);
}
```

输出 P、1，然后离开循环。`break` 不会自动结束整个 Node 进程，也不会跳出外层函数（本章尚未引入函数）。在嵌套结构中，无标签 break 只离开最近的循环或 switch。若必须跨多层跳出，通常先重审结构；标签语句虽是语言能力，但不进入本章主线。

在 switch 里 break 防止贯穿；在循环里 break 表达“已满足停止条件”。它不能替代正常终止条件。一个以 `while (true)` 配合隐藏 break 的循环，比显式有界条件更难证明安全，零基础和生产批处理都应谨慎。

## `continue`：跳过当前轮剩余语句

```js
// 输入字符串中的连字符只是格式分隔符，不参与有效代码输出。
for (const character of "P-1") {
  if (character === "-") {
    continue;
  }
  console.log(`code=${character}`);
}
```

遇到 `-` 时，当前轮后续语句被跳过，下一轮读取 `1`。continue 只能用于循环，不能单独用在 switch 中；语法层会拒绝不在迭代语句内的 continue。

在 `for` 中，continue 后仍会执行更新部分再检查条件。在 `while` 中，continue 直接回到条件检查；若进度更新写在 continue 之后，可能被跳过并形成无限循环：

```js
// 反例：当 remaining 为 2 时，continue 跳过递减，循环永远停在 2。
let remaining = 3;
while (remaining > 0) {
  if (remaining === 2) {
    continue;
  }
  remaining -= 1;
}
```

修复不是随意移动 continue，而是确保每条迭代路径都推进终止度量。若 continue 让进度难以证明，改写为正向条件块通常更清晰。

## 边界表：零次、一次、多次、非法

canonical build 是工单优先级脚本。命令行输入两个文本：`score` 为 0..100 整数，`retryCount` 为 0..3 整数。输出优先级、队列和每轮重试。先写表：

| case | score | retryCount | 预期优先级/结果 | 循环输出行数 | 退出码 |
| --- | ---: | ---: | --- | ---: | ---: |
| zero | 80 | 0 | P1 / emergency | 0 | 0 |
| one | 50 | 1 | P2 / expedited | 1 | 0 |
| many | 49 | 3 | P3 / standard | 3 | 0 |
| lower edge | 0 | 0 | P3 / standard | 0 | 0 |
| upper edge | 100 | 1 | P1 / emergency | 1 | 0 |
| invalid score | 101 | 1 | INVALID_SCORE | 0 | 2 |
| invalid count | 80 | -1 | INVALID_RETRY_COUNT | 0 | 2 |
| non-number | bad | 1 | INVALID_SCORE | 0 | 2 |

阈值边界还应补 79/80 与 49/50。每个案例都捕获 stdout、stderr 和退出码。非法输入可以把稳定错误结果写 stdout 或 stderr，但合同必须统一；本章资产将错误结果写 stdout、stderr 留空并以 2 退出，便于区分可预期输入拒绝与运行时崩溃。

不要把多个案例写进脚本内部数组再循环，这会提前引入集合与测试抽象。当前阶段由唯一 `verify.sh` 多次启动同一入口，每次只给一个输入，证明进程边界也可重复。

## 三类故障怎样定位

### truthiness 误用

故障：用 `if (!retryCount)` 判断非法，导致合法 0 被拒绝；或直接判断原始 `"0"`，因非空而当成 true。

首个可信证据是 zero 案例：输入转换后值为 0、类型 number、整数与范围都合法，但分支进入 INVALID。把条件拆为 `Number.isInteger(retryCount)`、`retryCount >= 0`、`retryCount <= 3`，输出每个原子结果。修复为精确有效性表达式后重跑完整边界表。残余风险是 `Number("")` 为 0，所以空文本应在转换前单独按合同处理。

### 遗漏分支

故障：if 链只处理 P1/P3，或 switch 漏掉 P2，导致 score=50 的边界进入 default。首证据是 one 案例的预期 P2 与实际 invalid/standard 第一次分歧。

先画覆盖区间和离散 case 集合，确认是需求漏项还是实现漏项。增加唯一缺失分支并重跑 49/50、79/80、default 非法值。不要把 default 改成 P2 来隐藏未知输入；default 应保留未知保护。残余风险是后端将来新增优先级，前端合同需要显式演进。

### 循环边界偏一

故障：`index <= retryCount` 让 zero 执行一次、three 执行四次。首证据通常是 zero 案例第一行不该出现，或 stdout 行数第一处多一。

写出索引序列：期望 count=3 对应 0,1,2；继续条件应为 index<count。修复一个比较符后重跑零、1、3和最大上界。残余风险包括人类显示编号 index+1、嵌套循环或 continue 跳过更新。

### 无限循环

虽然 canonical 注入项是偏一，本章还必须能识别无限循环风险。若 verifier 卡住，不要只等待：检查条件变量初值、每条路径的更新、continue 前后位置和是否向终止方向变化。用外部超时终止是安全护栏，不能作为“程序正确结束”的证据。保存被终止的命令与最后进度值，修复后重跑原边界表。

## 调试流水线

```text
1. 输入证据：原始值、typeof、是否为空文本
2. 规范化/转换：结果值、Number.isNaN/Integer/范围
3. 条件求值：每个原子布尔值
4. 分支选择：命中哪个 if/case，是否意外贯穿
5. 循环轨迹：初值、每轮索引/剩余量、更新后值
6. 局部转移：break/continue 作用于哪个最近结构
7. 外部预言：stdout、stderr、退出码、行数
```

第一处偏离就是优先调查点。例如输入和转换都正确，score=50 时 `score >= 80` false、`score >= 50` true，却输出 P3，说明分支实现/输出之间有问题；不要先更换 Node。若 actual Node 路径或版本不符合目标，工具链证据先失败，语言诊断结果只能标为兼容性观察。

## 浏览器与 Node 的控制流边界

`if`、switch、循环和 break/continue 属于 ECMAScript，浏览器与 Node 核心语义一致。差异来自输入、输出与宿主生命周期：

- Node CLI 常从 `process.argv`/`process.env` 获得字符串，能用退出码表达拒绝；
- 浏览器常从 DOM 表单获得字符串，在事件回调中运行，页面不会因某个分支自然“退出”；
- 浏览器主线程上的无限循环会冻结交互与渲染；Node 事件循环也会被同步无限循环阻塞；
- DevTools 的暂停按钮和断点有助于观察，但截图不替代边界表和自动预言。

本章资产选择 Node 是因为 stdout/exit code 易于固定。浏览器中的同一逻辑还要验证 DOM 输入、事件触发、可访问错误提示与页面恢复，这些属于后续 DOM 章节。

## FactoryCare：教学优先级，不是领域授权

FactoryCare 的唯一工单状态机包含 12 个状态：`CREATED`、`TRIAGED`、`ASSIGNED`、`ACCEPTED`、`IN_PROGRESS`、`PENDING_PARTS`、`PENDING_APPROVAL`、`RESOLVED`、`VERIFIED`、`CLOSED`、`REOPENED`、`CANCELLED`。每条真实迁移还要校验角色、租户/数据范围、必填证据、版本、审批、SLA、审计和领域事件。

本章的 score→P1/P2/P3 只是可重复教学分类，不等于产品正式优先级算法，更不等于状态机。AI 可以提出优先级建议，Java 后端仍验证并持久化权威事实。循环打印三次“notification”也不代表真的发送了三条消息；实际通知需要幂等、失败重试、外部 Provider 和 outbox 契约。

反例：前端 switch 看到 CLOSED 后直接赋 IN_PROGRESS。即使 UI 输出正确，也绕过合法的 `CLOSED → REOPENED → IN_PROGRESS` 两步、权限、版本与审计。此问题必须由后端命令拒绝，不能靠增加一个 case 修复。

适合本章的 FactoryCare 小实验是：对已验证的固定风险分数进行展示优先级分类，对 0..3 次本地预览动作生成精确轨迹。所有注释都要写明“数据源是教学输入、输出是预言、副作用不代表真实业务已发生”。

## 常见误解

### “`if (value)` 就是检查 value 存在”

它检查 truthiness，会把 0、false、空字符串、NaN 与 nullish 一起当 falsy。存在性要按合同精确判断。

### “else 会处理所有合法低值”

如果没有先验证，NaN、越界值也会进入 else。先校验，后分类。

### “switch 比 if 更高级”

两者适用问题不同。范围条件用 if 链，单个离散值匹配可用 switch。选择依据是合同，不是语法炫技。

### “case 自动在下一项停止”

不会。缺少 break 会贯穿。故意贯穿要注释并有覆盖案例。

### “重试 3 次应该写 `<= 3`”

如果索引从 0 开始，`0..3` 是四次。用 `index < retryCount` 表示总次数最清楚。

### “while 总会至少执行一次”

while 先检查条件，可能零次；do...while 才至少一次。别让结构改变业务零次语义。

### “break 会结束整个程序”

无标签 break 只离开最近循环或 switch；后续外部语句仍执行。

### “continue 只是更短的 if”

它会跳过当前轮剩余语句，while 中可能跳过进度更新并造成无限循环。必须证明每条路径推进。

## 练习资产

- `examples/encyclopedia/ch.js.control-flow/`：单一输入的绿色优先级、switch 和多种循环轨迹；
- `labs/encyclopedia/ch.js.control-flow/`：边界表覆盖零、一次、多次、阈值和非法输入，并确认三类受控故障；
- `exercises/encyclopedia/ch.js.control-flow/`：公开稳定红灯，要求修复 0 的 truthiness、P2 分支和 off-by-one；
- `solutions-private/encyclopedia/ch.js.control-flow/`：相同边界合同的绿色参考答案。

每目录只有一个 verify.sh。资产使用命令行重复启动入口，不引入自定义函数或数组测试表；shell 验证器只是测试外壳。所有 JS 注释说明职责、输入来源、映射与副作用。

## 120 秒口述模板

> 条件位置会把值按 truthiness 转为布尔；falsy 包括 false、0、-0、0n、空字符串、null、undefined、NaN，非空字符串 "0" 仍 truthy。业务条件应在显式转换后写成精确布尔表达式。if/else if 按顺序选择第一条命中路径，适合范围；switch 用严格匹配处理离散值，break 防止意外贯穿。for 适合显式计数，while 必须证明进度，for...of 按顺序取可迭代值。break 离开最近循环/switch，continue 跳到下一轮且不能跳过终止更新。我的证据是零、一次、多次、非法与阈值边界表。前端控制流不能授权 FactoryCare 状态迁移，是边界反例。

## 独立构建验收单

- [ ] 从空目录创建，只用 Node ESM、声明、值、分支和循环，不复制私有答案。
- [ ] score 与 retryCount 先处理空文本、显式转换并验证整数/范围。
- [ ] 优先级区间互斥且覆盖全部有效输入；switch 有 P1/P2/P3/default。
- [ ] 循环有可证明上界，零次不输出、一次一行、多次精确 N 行。
- [ ] 至少展示 for、while 和字符串 for...of 的最小正确边界。
- [ ] break/continue 的最近结构和进度影响有注释与预言。
- [ ] 保存运行前边界表、Node 路径/完整版本、实际 stdout/stderr 与退出码。

## 故障诊断验收单

- [ ] truthiness：合法 0 不被当成缺失，原始 "0" 不被当成已验证数字。
- [ ] 遗漏分支：49/50、79/80 与 default 都有案例。
- [ ] off-by-one：0、1、3、最大值的输出次数精确。
- [ ] 能检查 while 每条路径的进度，识别 continue 跳过更新风险。
- [ ] 每次保存失败、只修一个原因、原样复跑完整边界表并说明残余风险。

## 本章边界与后续

本章不引入自定义函数、返回值、数组/集合算法、异常处理、异步回调、DOM 事件或 TypeScript 收窄。`process.argv` 和 Node 断言只作为固定宿主/验证外壳。下一章会把这些分支与循环封装进函数；在此之前，先能逐条画出控制流图和终止证明。

## 官方资料与核验日期

以下一手资料于 **2026-07-17** 核验：

- [ECMAScript 2026：ToBoolean](https://tc39.es/ecma262/2026/multipage/abstract-operations.html#sec-toboolean)
- [ECMAScript 2026：The if Statement](https://tc39.es/ecma262/2026/multipage/ecmascript-language-statements-and-declarations.html#sec-if-statement)
- [ECMAScript 2026：Iteration Statements](https://tc39.es/ecma262/2026/multipage/ecmascript-language-statements-and-declarations.html#sec-iteration-statements)
- [ECMAScript 2026：The continue Statement](https://tc39.es/ecma262/2026/multipage/ecmascript-language-statements-and-declarations.html#sec-continue-statement)
- [ECMAScript 2026：The break Statement](https://tc39.es/ecma262/2026/multipage/ecmascript-language-statements-and-declarations.html#sec-break-statement)
- [ECMAScript 2026：The switch Statement](https://tc39.es/ecma262/2026/multipage/ecmascript-language-statements-and-declarations.html#sec-switch-statement)
- [Node.js Releases](https://nodejs.org/en/about/previous-releases)
- [Node.js v24 Process](https://nodejs.org/download/release/latest-v24.x/docs/api/process.html)

控制结构语义是稳定核心；Node 维护状态和 patch 属于易变事实。核验日 v24（Krypton）仍列为 LTS，正式证据需记录实际 Node 24.x patch，而不是从教材日期推断。
