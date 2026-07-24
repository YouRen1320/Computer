---
schema_version: 2
edition: 2026.2-draft
id: ch.js.statements-variables
title: 源码、语句、变量、表达式、输出与最小预言
responsibility: 教会读者从上到下阅读 JavaScript 源码，用声明、赋值、表达式和输出验证状态变化，不提前使用分支、循环或函数抽象。
volume: '08'
order: 2
level: L1
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.js.statements-variables.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.js.runtime-esm
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
  text: 在 120 秒内解释“源码、语句、变量、表达式、输出与最小预言”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - js-source-statements
  - js-bindings-output
  covers_topics:
  - js.source-file
  - js.statement
  - js.expression-statement
  - js.comment-semicolon
  - js.let-binding
  - js.const-binding
  - js.assignment
  - js.console-log
  - js.execution-order
  uses_capabilities:
  - foundation.toolchain-env-build
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 编写并逐行预测一个只含声明、赋值和输出的状态变化脚本；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - js-source-statements
  - js-bindings-output
  covers_topics:
  - js.source-file
  - js.statement
  - js.expression-statement
  - js.comment-semicolon
  - js.let-binding
  - js.const-binding
  - js.assignment
  - js.console-log
  - js.execution-order
  uses_capabilities:
  - foundation.toolchain-env-build
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: prediction-stdout-oracle-exit-code
- id: diagnose
  kind: fault-diagnosis
  text: 面对“未声明标识符、const 重赋值或执行顺序误判”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - js-source-statements
  - js-bindings-output
  covers_topics:
  - js.source-file
  - js.statement
  - js.expression-statement
  - js.comment-semicolon
  - js.let-binding
  - js.const-binding
  - js.assignment
  - js.console-log
  - js.execution-order
  uses_capabilities:
  - foundation.toolchain-env-build
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 源码、语句、变量、表达式、输出与最小预言

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《JavaScript 运行时、Node、pnpm 与 ESM》](ch.js.runtime-esm.md)：语言实验必须先有可复现的运行时、模块入口和命令退出证据。
<!-- END GENERATED LEARNING PREREQUISITES -->

程序最小的可验证故事不是“写了一段看起来像代码的文本”，而是：运行时按确定顺序读取源码，执行声明与赋值，状态发生可解释的变化，观察点输出与事先写下的预言完全一致。只要这条故事说不清，增加分支、循环、函数或框架只会让猜测藏得更深。

本章故意把世界缩小到一条直线：一个 ESM 源文件，从上到下，只含注释、`const`/`let` 声明、赋值和 `console.log` 输出。不提前讲分支、循环和函数抽象。你会用“纸面状态表 → stdout 预言 → 实际运行 → 退出码”的闭环证明自己真正理解每一行，而不是靠反复运行碰答案。

## 学完以后，你应当能做到什么

完成本章后，你应当能够：

1. 在 120 秒内区分源文件、语句、表达式、表达式语句、声明、绑定、赋值和输出，并说明注释与分号的边界；
2. 对一个只含顺序语句的脚本逐行编号，在运行前写出每个可观察点的绑定值和精确 stdout；
3. 独立编写 FactoryCare 状态快照脚本，保存源码、预言、实际 stdout、stderr、Node 路径/版本和退出码；
4. 面对未声明标识符、`const` 重赋值和执行顺序误判，找到最早发生分歧的语句，单点修复后重跑原验证；
5. 给出边界反例：真正的工单状态迁移合法性不能靠顺序打印脚本决定，它属于领域状态机、持久化和权限契约。

本章 canonical 验证级别是 T1：不仅要“进程跑了”，还要在运行前作出预测，并把预测与实际 stdout 逐字比较。看到答案后再补写预言，不算通过。

## 前置知识：先有可信入口，再讨论每一行

你应已完成上一章的最小 Node/ESM 运行链，知道怎样证明：

- 当前 shell 实际启动了哪个 `node`；
- 项目为何按 ESM 解释源码；
- stdout、stderr 和退出码是不同证据；
- 相对模块路径需要清楚合同；
- 工具版本漂移与语言错误不能混为一谈。

本章继续使用 Node 24.x LTS 作为教材目标版本。Node 的维护状态属于易变事实，已于 **2026-07-17** 对照官方 [Previous Releases](https://nodejs.org/en/about/previous-releases) 核验；语句与声明语义对照 [ECMAScript 2026](https://tc39.es/ecma262/2026/multipage/ecmascript-language-statements-and-declarations.html)。本章使用的顺序执行、`let`、`const`、赋值与字符串输出是稳定语言核心，但正式验收仍记录实际 Node 完整 patch 和路径。

## 一张从文本到证据的地图

```text
源文件中的字符
   ↓ 解析：这些字符是否组成合法模块、声明、语句和表达式？
模块中的语句列表
   ↓ 求值：按照本例的顺序执行，每一步读取或改变哪些绑定？
运行中状态
   ↓ console.log：把选定状态转换为外部可见文本
stdout / stderr / exit code
   ↓ 与运行前预言比较
通过，或在第一个分歧点诊断
```

这张图有两个重要边界。第一，源码是输入文本，不等于正在运行的状态；文件里写了 `status = "ASSIGNED"` 不证明那一行已经执行。第二，输出是对状态的观察，不是状态本身；没有打印某个绑定，不等于它不存在，打印正确也不自动证明其他未观察状态正确。

## 源文件：给运行时解析的完整输入

源文件是按某种字符编码保存的文本。本项目统一使用 UTF-8，并把 JavaScript 模块纳入版本控制。Node 读取入口后先解析整个模块；即使语法错误位于最后一行，前面的 `console.log` 也通常不会“先执行一点再失败”，因为程序还没有形成可求值的合法模块。

文件名和扩展名参与运行合同。上一章已说明：在明确的 `type: "module"` 包里，`.js` 可作为 ESM；`.mjs` 也明确表示 ESM。本章资产使用 `.mjs`，让局部练习不依赖邻近包清单。扩展名只决定模块格式边界之一，不能修复内部语法和状态预测。

### 先读结构，再读细节

拿到一个零基础脚本时，按以下顺序阅读：

1. 确认入口文件与运行命令，避免读错同名副本。
2. 标出每一条声明：引入了哪些名字，初始值来自哪个表达式。
3. 标出每一条赋值：改变哪个现有绑定，右侧在当时会得到什么值。
4. 圈出每一个输出观察点：它读取的是赋值前还是赋值后的状态。
5. 在纸上写逐行状态表，再写精确 stdout；最后才运行。

不要一开始就问“这段代码总体想做什么”。总体故事可能掩盖局部顺序错误。先能解释每一行对状态的作用，再组合成整体。

## 语句：让程序采取一步动作

语句可以粗略理解为模块中的执行单位，但不同语句的语法和效果不同。本章只需要三类：词法声明、表达式语句和空语句的边界认识。

```js
const workOrderId = "WO-1001";       // 词法声明
let currentStatus = "CREATED";       // 词法声明
currentStatus = "ASSIGNED";          // 含赋值表达式的表达式语句
console.log(currentStatus);           // 含调用表达式的表达式语句
```

前两行创建绑定并初始化。第三行计算右侧字符串，再把结果写入已有绑定；整个赋值表达式作为一条语句出现。第四行计算 `console.log(...)` 调用表达式并把它作为语句执行；它的关键副作用是输出。

“一行”等于“一个语句”只是排版习惯，不是语法真理。一个语句可以跨多行，多条简单语句也可能写在同一行。为了可读、可调试和便于状态表，本书每行只放一个简单语句。报错的行列位置是定位线索，真正语义边界仍要看语法结构。

### 表达式与表达式语句不是同一个层级

表达式求值得到一个值，或者在求值时产生副作用。字符串字面量 `"CREATED"` 是表达式；名字 `currentStatus` 出现在读取位置时也是表达式；赋值 `currentStatus = "ASSIGNED"` 是赋值表达式；`console.log(currentStatus)` 是调用表达式。

当某个允许作为语句开头的表达式后面形成语句，它就是表达式语句：

```js
currentStatus = "ASSIGNED";
console.log(currentStatus);
```

第一个表达式的主要价值是改变状态，第二个表达式的主要价值是产生输出副作用。不要把“表达式有值”误解为“这个值一定被保存”。若没有赋给绑定、传给其他操作或输出，计算结果可能立刻被丢弃。独立写一个字符串：

```js
"IN_PROGRESS";
```

它是合法的表达式语句，但在这个脚本中既不改变绑定也不输出内容，通常没有教学外的实际意义。

## 绑定、变量和值：把三个概念分开

初学材料常把 `let status = "CREATED"` 全部叫“变量”。更精确的模型是：

```text
标识符 status ──命名──> 绑定槽位 ──当前保存──> 值 "CREATED"
```

标识符是源码里的名字；绑定是运行环境把名字关联到值的机制；值是当下保存的数据。赋值改变绑定当前关联的值，不会把源码文件里的旧字符串擦掉。运行结束后，内存状态通常消失；要跨进程保存，需要文件、数据库或其他持久化机制，那不属于本章。

### `const`：绑定不能被重新赋值

```js
// 工单 ID 在这次状态追踪中保持不变，因此用 const 表达意图。
const workOrderId = "WO-1001";
```

`const` 声明必须在声明时初始化，而且这个绑定之后不能出现在重新赋值的左侧。它表达“这段作用域内，这个名字始终指向首次初始化得到的值”。对本章的字符串值，这可以直接理解为不能把 `workOrderId` 改成另一个字符串。

`const` 并不等于“宇宙中的数据永久不变”，也不等于“业务对象已被冻结”。后续学到对象后会看到，`const` 限制的是绑定重赋值，不自动深度冻结对象内部。本章先只用字符串，避免把两个问题混在一起。

### `let`：允许有意的后续赋值

```js
// currentStatus 表示本次线性演示中的当前快照，后面会按步骤更新。
let currentStatus = "CREATED";
currentStatus = "ASSIGNED";
```

`let` 允许后续重新赋值。使用它不是因为“写起来方便”，而是因为建模对象确实会在这段顺序脚本中变化。名字应描述当前状态，例如 `currentStatus`，不要用 `x1` 或 `temp2` 迫使读者追忆。

如果绑定在初始化后不应改变，默认选 `const`；只有确实需要按步骤改变时才用 `let`。这项习惯让意外重赋值更早变成错误，也减少阅读者必须追踪的状态。

### 本章为何不使用 `var`

`var` 是语言中的历史声明形式，函数作用域和提升行为与 `let`/`const` 不同。它仍存在于旧代码，但不是本章新代码主线。零基础先用块级词法绑定建立准确模型；阅读遗留 `var` 的细节留到作用域章节。不要把“暂时不教”误解成语法不存在，也不要机械地把遗留 `var` 全局替换而不验证作用域行为。

## 声明与赋值：创建和更新不是一回事

```js
let currentStatus = "CREATED";
currentStatus = "ASSIGNED";
```

第一行是声明并初始化：创建 `currentStatus` 绑定，并把初值设为 `"CREATED"`。第二行是赋值：要求绑定已经可用，先计算右侧表达式，再更新该绑定。若把第二行单独放在严格 ESM 中而从未声明 `currentStatus`，会得到 `ReferenceError`，而不是自动创建一个可靠的全局变量。

把等号读成“把右边计算结果赋给左边绑定”，不要读成数学上的“恒等”。下面两行并不矛盾：

```js
let inspectionCount = 1;
inspectionCount = 2;
```

它们描述两个不同时刻。第一个语句之后值是 `1`，第二个语句之后值是 `2`。本章暂不使用算术、自增和复合赋值，避免运算规则干扰顺序模型。

### 赋值发生在输出之前还是之后

比较两段代码：

```js
let currentStatus = "CREATED";
console.log(`status=${currentStatus}`);
currentStatus = "ASSIGNED";
```

```js
let currentStatus = "CREATED";
currentStatus = "ASSIGNED";
console.log(`status=${currentStatus}`);
```

第一段输出 `status=CREATED`，第二段输出 `status=ASSIGNED`。源码里都出现两个状态，但观察点位于不同位置。调试执行顺序时，不要只搜索最终赋值；给语句编号，并写出每个输出发生当时的状态。

## 注释：解释意图，但不参与求值

单行注释从 `//` 开始到行末；块注释位于 `/*` 与 `*/` 之间。注释供人和工具阅读，正常求值时不会创建绑定或输出。好的注释解释代码本身不容易表达的职责、数据来源、非显然映射或重要副作用：

```js
// 该标签只是前端演示映射，正式状态权限仍以后端契约为准。
const assignedLabel = "已指派";

// 此输出是验证脚本的外部预言，修改格式时必须同步审阅合同。
console.log(`label=${assignedLabel}`);
```

以下注释信息量很低：

```js
// 定义 label。
const label = "已指派";
```

注释不能修复错误源码。把一条语句“注释掉”虽然可能让错误消失，却也改变了验收输入；只有当需求明确删除该行为时才是修复。块注释也不应被用来长期保存整段死代码，版本控制已经承担历史记录。

### 注释与字符串不要混淆

`"// not a comment"` 中的斜线属于字符串内容；`console.log("/* text */")` 会打印星号和斜线。反过来，注释里的 `console.log(...)` 不会执行。预测 stdout 时先确认字符处于字符串、模板字面量还是注释区域。

## 分号与自动分号插入

JavaScript 语法在某些位置允许自动分号插入（ASI），因此下面代码常能运行：

```js
const workOrderId = "WO-1001"
console.log(workOrderId)
```

但“常能运行”不等于换行永远等于分号。ASI 只在规范定义的受限条件中插入，不是格式美学规则，也不会主动修复所有歧义。后续出现以 `(`、`[`、模板字面量等开头的行时，无分号风格需要一致工具规则和更强理解。

本书示例统一写分号，目的不是宣称另一种风格无效，而是让初学者清楚看到简单语句边界，并减少复制片段时的连接歧义。团队若采用无分号风格，应由格式化器和 lint 规则统一执行；不要在同一文件随意混搭。

一个单独的分号 `;` 可以形成空语句。它什么也不做，却可能在未来控制结构附近产生意外含义。本章不需要主动写空语句。看到连续 `;;` 时，先判断它是无害残留还是掩盖了原本应有的代码，不要仅凭程序能跑就保留。

## 顺序执行：画状态表，不在脑中跳跃

本章的脚本没有分支、循环、函数调用栈或异步回调，所以模块进入求值后可按顶层语句顺序建立状态表。考虑：

```js
// 工单号来自本次演示输入，状态机权威仍在后端领域层。
const workOrderId = "WO-1001";

// currentStatus 保存线性追踪中的当前状态快照。
let currentStatus = "CREATED";

// 每条输出都是预言的一部分，顺序变化也算合同变化。
console.log(`workOrder=${workOrderId}`);
console.log(`before=${currentStatus}`);
currentStatus = "ASSIGNED";
console.log(`after=${currentStatus}`);
```

运行前写表：

| 步骤 | 正在执行的语句 | `workOrderId` | `currentStatus` | 新增 stdout |
| --- | --- | --- | --- | --- |
| 1 | `const workOrderId = ...` | `WO-1001` | 尚未声明 | 无 |
| 2 | `let currentStatus = ...` | `WO-1001` | `CREATED` | 无 |
| 3 | 输出工单号 | `WO-1001` | `CREATED` | `workOrder=WO-1001` |
| 4 | 输出更新前状态 | `WO-1001` | `CREATED` | `before=CREATED` |
| 5 | 赋值 `ASSIGNED` | `WO-1001` | `ASSIGNED` | 无 |
| 6 | 输出更新后状态 | `WO-1001` | `ASSIGNED` | `after=ASSIGNED` |

由表得到精确预言：

```text
workOrder=WO-1001
before=CREATED
after=ASSIGNED
```

结尾换行也属于文件比较的一部分。预言中不要加入终端提示符、颜色或执行命令；它只描述程序的 stdout。stderr 应为空，退出码应为 `0`。

### 最小预言为什么比肉眼检查更可靠

人容易忽略顺序、空格、大小写和缺行。“差不多是三行”不能发现 `before` 与 `after` 调换。稳定的预言文件可以被 `cmp` 逐字比较，使同一合同能在本机和 CI 自动复跑。

一个最小预言由四部分组成：固定输入、精确输出、预期 stderr 条件、预期退出码。若包含当前时间、随机数或机器路径，输出就不再稳定；本章不引入这些不确定源。未来确实需要它们时，应显式注入或归一化，而不是删掉断言。

## `console.log`：把不可见状态变成可比较文本

`console.log` 是宿主提供的输出能力，不是 ECMAScript 核心状态存储。Node CLI 中它通常把一行写到 stdout；浏览器中它显示在开发者工具 Console。对于纯字符串，本章可以稳定预测文本；复杂对象在不同开发者工具中的展开和格式可能不同，不能照搬为跨宿主预言。

模板字面量用反引号包围，`${...}` 位置读取当时的表达式值：

```js
const workOrderId = "WO-1001";
console.log(`workOrder=${workOrderId}`);
```

本章使用它只为避免逗号格式化差异。模板里的读取不会把绑定“锁住”；若后面 `let` 被赋新值，再次输出会读取新值。

输出本身是副作用：改变或移动 `console.log` 会改变可观察合同。调试日志可以临时增加，但验收时应区分合同输出和诊断输出。若诊断行混入 stdout，字节比较会失败；可以在明确约定下把诊断写到 stderr，但本章绿色基线要求 stderr 为空。

### 浏览器与 Node 的输出差异

相同的 `console.log("status=CREATED")` 在两端都容易阅读，但证据采集方式不同。Node 可以重定向 stdout/stderr 并记录退出码；浏览器页面没有完全等价的“页面退出码”，要结合 Console、Network、测试运行器和页面状态。浏览器 DevTools 对对象常采用交互式、延迟展开展示，显示的属性可能反映展开时而非打印时的细节。

因此本章的 canonical T1 验证在 Node 中执行纯文本脚本。把脚本复制到浏览器 Console 只能算补充观察，不能替代目标 Node 路径、版本、输出文件和退出码证据。反过来，Node 绿色也不证明页面 DOM 集成正确。

## 三类故障怎样找到第一个证据

先区分两个阶段：解析期错误意味着合法程序尚未开始执行；求值期错误意味着模块已解析并在某条语句执行时失败。输出预言不一致则可能进程成功，却在业务观察上失败。

```text
入口与工具正确？
   ↓
整个源文件能解析？ —— 否 → SyntaxError，先修语法位置
   ↓ 是
逐条求值是否中断？ —— 是 → ReferenceError / TypeError，找首条失败语句
   ↓ 否
stdout 是否等于预言？ —— 否 → 找第一行、第一字符、第一状态分歧
   ↓ 是
stderr 为空且 exit=0？ —— 否 → 仍未通过
```

### 故障一：未声明标识符

```js
// 拼写错误导致读取一个从未声明的绑定。
const workOrderId = "WO-1001";
console.log(workorderId);
```

JavaScript 标识符区分大小写。`workOrderId` 与 `workorderId` 是两个名字。模块在执行第二行时无法解析该名字对应的绑定，Node 抛出 `ReferenceError`，后续语句不会执行，进程通常非零退出。

首个可信证据是 stderr 中错误类型、未定义名字和源码位置；不是“Console 没打印”。修复前检查声明处、使用处和需求词汇，确认究竟哪个拼写是合同。只在使用处改对后，重跑原预言比较。残余风险是相似拼写可能还存在于未执行路径或其他模块；后续 lint 与测试会扩大覆盖。

在旧式非严格脚本中，对未声明名字赋值曾可能意外创建全局属性，但 ESM 天然是严格模式，不应依赖这种行为。显式声明所有绑定。

### 故障二：`const` 重赋值

```js
// 工单号本应稳定；重新赋值会暴露建模错误。
const workOrderId = "WO-1001";
workOrderId = "WO-1002";
```

第一行成功创建不可重赋值绑定，第二行求值时抛出 `TypeError`。不要一看到错误就把所有 `const` 改成 `let`。先问业务意图：如果同一次追踪不应切换工单，正确修复是删除错误赋值或使用另一个有意义的绑定；只有确实建模“当前选择会改变”时才改用 `let`，并更新预言。

首个可信证据是指向重赋值语句的 TypeError。修复后必须确认原始工单号仍符合输入，stdout 未被意外改写。残余风险是把 `const` 改为 `let` 虽能消除异常，却扩大可变状态并掩盖领域错误。

### 故障三：执行顺序预言错误

```js
let currentStatus = "CREATED";
console.log(`observed=${currentStatus}`);
currentStatus = "ASSIGNED";
```

若预言写 `observed=ASSIGNED`，Node 可以以 0 退出，stderr 为空，但 T1 仍失败。首个可信证据是预期 stdout 与实际 stdout 的第一处差异。给语句编号，定位输出位于赋值前，状态表会显示当时只能读取 `CREATED`。

修复有两种可能，但必须由需求决定：如果应观察更新前状态，改预言；如果应对外报告更新后状态，移动赋值或输出。不能为了让测试变绿随便选。修复后重跑同一命令与比较。残余风险是需求本身可能未说明观察时点，因此要把 `before`/`after` 写进输出合同。

## 调试时常见的错误动作

### 一次改很多行

同时改声明类型、名字、赋值顺序和预言，即使变绿也不知道哪项修复有效。保存失败证据，每次只修一个已证实原因，再原样复跑。

### 在报错前后狂加日志

日志能帮助观察，但也会改变 stdout 合同。先读异常类型、位置和现有状态表；若确实增加诊断，明确把它作为临时证据，完成后恢复并重跑正式预言。

### 只看最后一个值

最终 `ASSIGNED` 不能证明此前输出了 `CREATED`，也不能证明每一步顺序正确。状态变化脚本的合同包含中间观察点。

### 把工具问题当语言问题

若实际 Node 路径不是目标工具链，先解决环境证据。不要因为旧 Node 或错误入口报错就改语言语义。每份故障记录都先写命令、cwd、入口摘要和版本。

### 看到绿色就删除预言

没有独立预言的脚本只能证明“它每次输出同样东西”，不能证明东西正确。预言必须在运行前依据需求推导，并与源码分开保存。

## FactoryCare 场景：状态快照，不是状态机

下面的线性脚本适合学习：

```js
// 演示输入来自固定练习；正式工单身份由后端和数据库维护。
const workOrderId = "WO-1001";

// currentStatus 只保存这次顺序追踪的当前快照。
let currentStatus = "CREATED";

// 输出点建立可逐字比较的教学证据。
console.log(`workOrder=${workOrderId}`);
console.log(`before=${currentStatus}`);
currentStatus = "ASSIGNED";
console.log(`after=${currentStatus}`);
```

它能教会绑定、赋值和顺序，却不能批准真实状态迁移。FactoryCare 的正式 12 状态模型、角色权限、并发检查、持久化事务和审计记录由领域契约与 Java 后端负责。前端或 Node 脚本不能通过写 `currentStatus = "RESOLVED"` 越过这些规则。

这正是本章的反例：如果用户没有权限完成工单，或数据库中的版本已被另一位工程师更新，顺序赋值脚本无法解决冲突。需要后端状态机、鉴权、并发控制和 API 错误处理。把教学状态称为 `currentStatus` 而不是 `authoritativeStatus`，并在注释中说明数据来源，可以减少误用。

另一方面，这种最小脚本很适合复现展示问题：给定后端返回的固定快照，前端在赋值前后究竟输出了什么？先用直线程序确定最小事实，再把它放回复杂页面。调试小实验应保持无网络、无数据库、无随机数，让失败只指向正在学习的概念。

## 从空目录完成独立构建

目标目录可以是：

```text
factorycare-state-trace/
├── package.json
├── src/
│   └── state-trace.mjs
├── expected.stdout
└── evidence/
    ├── toolchain.txt
    ├── actual.stdout
    ├── actual.stderr
    └── exit-code.txt
```

工作顺序：

1. 写需求句子：“固定工单 WO-1001，先观察 CREATED，再赋值 ASSIGNED，再观察。”
2. 在纸上列绑定：不变的工单号用 `const`，有意变化的当前状态用 `let`。
3. 编写只含声明、赋值和输出的 `.mjs`；不用分支、循环、函数、网络和时间。
4. 给每条语句编号，填写逐行状态表。
5. 根据表手写 `expected.stdout`，注明预期 stderr 为空、exit 为 0。
6. 保存实际 Node 路径和完整版本，再执行脚本并捕获三类进程证据。
7. 逐字比较预期与实际。若失败，保存第一处分歧，修复一个原因后重跑原命令。
8. 注入三类规定故障并各走一遍“首证据 → 修复 → 原验证 → 残余风险”。

不要复制仓库私有答案作为构建证据。独立 build outcome 要保留你自己的需求、预测表、源码、运行记录和解释；摘要或截图可以辅助，但不能替代可复跑文件。

### 推荐的证据记录格式

```text
cwd=<绝对项目目录>
entry=src/state-trace.mjs
source_sha256=<实测摘要>
node_path=<command -v node 的实测值>
node_version=<node --version 的实测值>
prediction_written_before_run=yes
stdout_match=yes
stderr_bytes=0
exit_code=0
```

尖括号是模板，不是合格证据。若使用本机 Node 22 观察资产，只能记录“在 Node 22 观察通过”；本书目标 Node 24 的验收要在对应环境另行执行，不能推断等价。

## 练习资产怎样使用

本章提供四类局部资产：

- `examples/encyclopedia/ch.js.statements-variables/`：展示一条绿色顺序脚本和精确 stdout；
- `labs/encyclopedia/ch.js.statements-variables/`：保存绿色基线及三种故障注入，适合练习首证据；
- `exercises/encyclopedia/ch.js.statements-variables/`：公开练习故意保持稳定红灯，必须按 TODO 推导而不是抄结果；
- `solutions-private/encyclopedia/ch.js.statements-variables/`：使用同一合同的绿色参考答案。

每个目录恰好一个 `verify.sh`。验证入口只执行稳定、本地、无依赖的 Node 脚本，不联网、不修改全局环境。JS 文件中的注释解释职责、数据来源、非显然映射和输出副作用。局部 verifier 证明资产合同，不代表已完成正式 Node 24 环境记录或 120 秒口述。

## 120 秒口述模板

> 源文件是运行时解析的文本；模块包含按语法组织的声明和语句。表达式求值得到值，赋值表达式会更新已有绑定，调用表达式作为语句可以产生输出副作用。`const` 创建不可重赋值绑定，`let` 用于有意变化的绑定；赋值和声明不是同一动作。注释不执行，分号标明语句边界，ASI 只按规范条件插入。对直线脚本，我先列逐行状态表，再写 stdout 预言，最后比较实际 stdout、stderr 和退出码。数据库中的工单状态合法性不是这段脚本能决定的反例。

口述时还应能现场解释一行输出读取的是哪个时刻的值。如果只会念名词而无法给出状态表，不算掌握。

## 自测题

1. `const` 是让值永远不变，还是让绑定不可重新赋值？本章字符串示例为何暂时看不出更深区别？
2. 为什么 `status = "ASSIGNED"` 不能替代 `let status = "ASSIGNED"`？在 ESM 中未声明名字会怎样？
3. `"ASSIGNED";` 是表达式语句吗？它在本例中有什么外部证据？
4. 为什么一个位于文件末尾的语法错误可能让文件开头的输出也不出现？
5. 两段源码含相同声明、赋值和输出，只是行序不同，为什么 stdout 会不同？
6. 为什么肉眼看 Console 不足以完成 T1？
7. 哪些信息应写在注释中，哪些注释只是重复代码？
8. 为什么不能看到 `Assignment to constant variable` 就把所有 `const` 改成 `let`？
9. Node 绿色基线为什么不证明浏览器页面集成正确？
10. FactoryCare 的真实状态迁移为什么不能由这个顺序脚本授权？

## 验收清单

### Explain

- [ ] 120 秒内说清源码、语句、表达式语句、声明、绑定、赋值与输出。
- [ ] 能解释注释不求值、分号与 ASI 的有限关系。
- [ ] 能给出浏览器与 Node 的输出证据差异。
- [ ] 给出一个本章不应解决的 FactoryCare 领域反例。

### Build

- [ ] 从空目录创建，不借用旧源码或私有答案。
- [ ] 脚本只含声明、赋值和输出，没有分支、循环或自定义函数抽象。
- [ ] `const`/`let` 选择有业务意图，名字明确，注释解释数据源与副作用。
- [ ] 运行前已写逐行状态表与精确 stdout，不是看到输出后补写。
- [ ] 保存 Node 路径、完整版本、源码摘要、stdout、stderr 和退出码。
- [ ] 预言与 stdout 逐字一致，stderr 为空，exit 为 0。

### Diagnose

- [ ] 未声明标识符：能从 ReferenceError 的名字和位置找到首个失败语句。
- [ ] `const` 重赋值：先判断建模意图，再决定删除赋值、换绑定或改为 `let`。
- [ ] 顺序误判：能定位预期与实际第一处分歧，并用状态表解释。
- [ ] 每次保存原失败证据，只做一个有依据的修复，重跑完全相同的验证。
- [ ] 写出残余风险，不把局部绿色扩大为完整业务正确性。

## 本章边界与后续入口

本章建立的是稳定核心：直线源码、绑定、赋值、观察和最小预言。它没有教授值类型与转换、运算优先级、分支、循环、作用域细节、函数、对象、异步、DOM、网络或 TypeScript。不要为了完成练习提前引入这些结构；它们会让失败边界失焦。

下一章会在已经可信的顺序观察能力上加入值、类型、转换和运算符。届时仍沿用这里的纪律：先预测，再运行；先找第一处分歧，再修复。随着程序变复杂，状态表会演进为测试、调试器和结构化日志，但“输入—状态变化—可观察预言—证据”这条链不会消失。

## 参考资料与核验日期

以下一手资料均于 2026-07-17 核验；语言规范是稳定语义依据，Node 维护状态与文档版本属于易变事实：

- [ECMAScript 2026：Statements and Declarations](https://tc39.es/ecma262/2026/multipage/ecmascript-language-statements-and-declarations.html)
- [ECMAScript 2026：ECMAScript Language — Lexical Grammar](https://tc39.es/ecma262/2026/multipage/ecmascript-language-lexical-grammar.html)
- [ECMAScript 2026：Automatic Semicolon Insertion](https://tc39.es/ecma262/2026/multipage/ecmascript-language-lexical-grammar.html#sec-automatic-semicolon-insertion)
- [ECMAScript 2026：Scripts and Modules](https://tc39.es/ecma262/2026/multipage/ecmascript-language-scripts-and-modules.html)
- [Node.js Previous Releases](https://nodejs.org/en/about/previous-releases)
- [Node.js v24 Console](https://nodejs.org/download/release/latest-v24.x/docs/api/console.html)

若未来主版本、维护状态或 Console 实现说明改变，应重新核验版本表面；不能因此改写 `let`、`const` 和顺序求值的稳定语义。
