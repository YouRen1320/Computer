---
schema_version: 2
edition: 2026.2-draft
id: ch.js.scope-closures
title: 词法作用域、闭包与函数状态
responsibility: 解释词法环境、遮蔽、生命周期和闭包捕获，用受控闭包封装状态，不把全局可变状态伪装成闭包。
volume: '08'
order: 6
level: L1-L2
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.js.scope-closures.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.js.functions
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
  text: 在 120 秒内解释“词法作用域、闭包与函数状态”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - js-lexical-scope
  - js-closure-state
  covers_topics:
  - js.lexical-environment
  - js.block-function-scope
  - js.shadowing
  - js.temporal-dead-zone
  - js.closure-capture
  - js.closure-lifetime
  - js.factory-function
  - js.private-state-closure
  - js.callback-entry
  uses_capabilities:
  - web.javascript-language
  - web.javascript-functions-closures
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“词法作用域、闭包与函数状态”构建可运行程序与测试：实现两个相互隔离的闭包计数器并保存作用域追踪表；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - js-lexical-scope
  - js-closure-state
  covers_topics:
  - js.lexical-environment
  - js.block-function-scope
  - js.shadowing
  - js.temporal-dead-zone
  - js.closure-capture
  - js.closure-lifetime
  - js.factory-function
  - js.private-state-closure
  - js.callback-entry
  uses_capabilities:
  - web.javascript-language
  - web.javascript-functions-closures
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: scope-trace-prediction-assertion-script
- id: diagnose
  kind: fault-diagnosis
  text: 面对“循环变量捕获、遮蔽或意外共享闭包状态造成的错误”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - js-lexical-scope
  - js-closure-state
  covers_topics:
  - js.lexical-environment
  - js.block-function-scope
  - js.shadowing
  - js.temporal-dead-zone
  - js.closure-capture
  - js.closure-lifetime
  - js.factory-function
  - js.private-state-closure
  - js.callback-entry
  uses_capabilities:
  - web.javascript-language
  - web.javascript-functions-closures
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 词法作用域、闭包与函数状态

一个函数返回后，它的局部绑定理应“消失”吗？为什么工厂函数返回的计数器仍能记住上一次调用？为什么两个看起来相同的计数器有时互不影响，有时却偷偷共享同一个数字？为什么在循环里创建的多个回调可能都读到最后一个索引？

这些问题的共同根基是词法环境。JavaScript 按源码嵌套关系解析名字；函数值在创建时与它可访问的外层环境建立联系。只要返回的函数仍可达，它引用的外层绑定也可能继续存活，这就是闭包行为。本章用可画出来的作用域链和两个独立计数器建立模型，不把“能藏住变量”误认为安全、持久化或并发控制。

## 学完以后，你应当能交出什么

你需要证明：

1. 在 120 秒内解释词法环境、块/函数作用域、遮蔽、暂时性死区、捕获、生命周期、工厂函数和闭包私有状态，并给出一个不应由闭包解决的反例；
2. 从空目录实现两个相互隔离的闭包计数器，为创建与每次调用保存作用域追踪表，断言不同调用时刻的值；
3. 对循环变量捕获、遮蔽和意外共享状态三类故障，指出第一个绑定解析或状态分歧，修复后重跑原断言；
4. 对生命周期只作可达性预测，不伪造垃圾回收发生时刻。

canonical T1 预言是：不同调用时刻与捕获位置下的绑定值、共享/独立状态和垃圾可达性预测都与实际输出一致。stdout 相同但两个实例共享状态，仍然不通过。

## 名字解析地图：从当前环境向外找

规范用 Environment Record（环境记录）描述标识符与绑定的关联，并用 `[[OuterEnv]]` 表示外层环境。它是规范模型，不保证引擎内存里真的存在同名对象；程序也不能直接读取这个记录。

```text
当前块环境
  └── OuterEnv → 当前函数环境
        └── OuterEnv → 模块环境
              └── OuterEnv → 全局环境
```

读取名字时，从当前词法环境开始；若没有该绑定，就沿外层引用查找。找到最近同名绑定就停止。这个“最近”由源码嵌套决定，不由函数从哪里调用决定，所以叫词法（静态）作用域。

```js
// 模块级 source 是外层绑定。
const source = "module";

function readSource() {
  // 函数体没有同名局部绑定，所以沿词法外层读取 module。
  return source;
}

function callReader() {
  // 调用位置的局部 source 不会动态改写 readSource 的定义环境。
  const source = "caller";
  return readSource();
}

console.log(callReader()); // module
```

若你预测 `caller`，说明把 JavaScript 当成动态作用域。调试时应画“函数写在哪里”，而不是只看“函数从哪里被调用”。

## 模块、函数和块分别建立哪些边界

### 模块作用域

ESM 顶层 `const`、`let` 和函数属于模块环境，不会简单变成 `globalThis` 属性。其他模块只能通过 export/import 合同访问导出名字。模块实例通常按解析后的模块身份缓存，顶层可变状态可能被多个导入者共享；这不是闭包封装，后文会区分。

### 函数作用域

每次调用普通 ECMAScript 函数都会建立本次调用环境，包含形参和函数体顶层绑定：

```js
function totalMinutes(activeMinutes, reviewMinutes) {
  // total 只属于本次函数调用，外部不能直接读取。
  const total = activeMinutes + reviewMinutes;
  return total;
}
```

两次调用产生不同参数/局部绑定。函数返回后，如果没有仍可达的内部函数引用这些绑定，相关环境可以不再保留；“何时释放”由实现决定。

### 块作用域

`let` 和 `const` 受最近花括号块约束：

```js
const status = "CREATED";

if (true) {
  // blockLabel 只在这个 if 块中可访问。
  const blockLabel = "inside";
  console.log(`${status}:${blockLabel}`);
}

// 这里读取 blockLabel 会得到 ReferenceError。
```

for 头部的 let 也有词法作用域，并且规范为每次迭代提供适合捕获的独立绑定语义。`var` 不是块作用域，属于变量/函数环境；新代码默认使用 let/const，把 var 留给遗留代码诊断和循环捕获反例。

函数声明写在块中的行为还牵涉 Web 遗留兼容，ESM 严格模式虽更一致，仍不要用它制造含混。需要条件选择函数值时，用块外清晰绑定与显式赋值，并写断言。

## 遮蔽：新绑定挡住外层同名绑定

内层声明与外层同名时，名字解析会命中内层，这叫 shadowing（遮蔽）：

```js
const status = "CREATED";

function preview() {
  // 局部 status 是新绑定，遮蔽模块级 status；它不是对外层重新赋值。
  const status = "ASSIGNED";
  return status;
}

console.log(preview()); // ASSIGNED
console.log(status);    // CREATED
```

遮蔽合法，但相同名字表示不同业务概念时会误导。可用 `initialStatus`、`previewStatus` 等明确名字。诊断时画绑定身份：模块 status 与函数 status 是两个槽位，不能只画“status 值变了”。

### 遮蔽和重赋值的区别

```js
let status = "CREATED";

function advancePreview() {
  // 没有声明新 status，因此赋值解析到外层绑定并产生共享副作用。
  status = "ASSIGNED";
}
```

若写 `let status = "ASSIGNED"`，则创建局部遮蔽，不改外层。少一个 `let` 会从“局部临时值”变成“修改共享状态”。严格 ESM 会阻止完全未声明名字，但不会阻止合法地写入外层 `let`。副作用合同仍需断言。

## 暂时性死区：绑定已存在但尚未初始化

进入包含 `let`/`const` 的词法环境时，绑定被创建，但执行到声明初始化之前不能访问。这段区域常称 TDZ（temporal dead zone）：

```js
// 反例：currentStatus 绑定已经属于当前块，但尚未初始化。
console.log(currentStatus); // ReferenceError
const currentStatus = "CREATED";
```

这不是“引擎没看见声明”，恰恰是它知道当前环境有一个尚未初始化的同名绑定，所以不会退到外层：

```js
const status = "outer";

{
  // 内层 status 从块开始就遮蔽外层，但到声明行前不可访问。
  console.log(status); // ReferenceError，不会打印 outer
  const status = "inner";
}
```

在 TDZ 中即使用 `typeof status` 也可能抛 ReferenceError；“typeof 未声明名安全”不适用于尚未初始化的词法绑定。修复是按依赖顺序声明初始化后再使用，不是把 const 改成 var 以获得 undefined。

函数声明、var、let/const 的初始化时机不同，不能用一句“都提升”概括。教学主线避免声明前调用，让源码顺序暴露依赖；遇到 ReferenceError 时结合声明种类和环境边界诊断。

## 闭包：函数值与定义时词法环境的联系

考虑工厂函数：

```js
// 工厂每次调用都创建新的 count 绑定，并返回引用该绑定的函数值。
function createCounter() {
  let count = 0;

  function increment() {
    count += 1;
    return count;
  }

  return increment;
}

const counter = createCounter();
console.log(counter()); // 1
console.log(counter()); // 2
```

`createCounter` 第一次返回后，它的普通调用栈帧结束，但返回的 increment 仍可达，并引用那次调用环境的 count。因此 count 继续存活。闭包不是把源代码复制一份，也不是自动把 count 序列化；它是函数执行时解析外部名字所需的环境联系。

### 捕获的是绑定，不是创建时值快照

```js
function createReader() {
  let status = "CREATED";

  const read = () => status;
  status = "ASSIGNED";
  return read;
}

const readStatus = createReader();
console.log(readStatus()); // ASSIGNED
```

read 捕获 status 绑定，调用时读取它的当前值；不是创建箭头函数时复制 `"CREATED"`。若确实需要快照，要创建另一个不会再更新的绑定：

```js
function createSnapshotReader() {
  let status = "CREATED";
  const capturedStatus = status;
  status = "ASSIGNED";
  return () => capturedStatus;
}
```

区分“实时绑定”与“派生快照”是诊断 stale closure 的关键。原生闭包通常没有“过期”魔法；过期来自捕获了不再代表当前事实的值、生命周期边界不对，或框架在不同渲染/实例中创建了不同环境。

## 工厂函数：每次调用应产生独立状态

canonical build 要求两个相互隔离的计数器：

```js
// 每次调用把 count 放在新的函数环境内，两个返回对象不会共享它。
function createCounter(name) {
  let count = 0;

  function increment() {
    count += 1;
    return `${name}:${count}`;
  }

  function read() {
    return count;
  }

  // 只暴露允许的操作，调用方无法直接按名字访问 count。
  return { increment, read };
}

const first = createCounter("first");
const second = createCounter("second");

console.log(first.increment()); // first:1
console.log(first.increment()); // first:2
console.log(second.increment()); // second:1
console.log(first.read()); // 2
console.log(second.read()); // 1
```

追踪表：

| 步骤 | 操作 | first.count | second.count | 返回/输出 |
| --- | --- | ---: | ---: | --- |
| 1 | 创建 first | 0 | 尚不存在 | 返回第一组函数 |
| 2 | 创建 second | 0 | 0 | 返回第二组函数 |
| 3 | first.increment | 1 | 0 | `first:1` |
| 4 | first.increment | 2 | 0 | `first:2` |
| 5 | second.increment | 2 | 1 | `second:1` |
| 6 | 分别 read | 2 | 1 | `2`、`1` |

两个工厂调用建立两个环境，方法只闭合各自环境。仅仅创建两个返回对象不保证隔离；状态必须定义在工厂内部。如果 count 在模块顶层，两个实例仍共享。

## “私有状态”是访问边界，不是安全边界

调用方没有词法路径直接读取 count，只能通过 returned methods 操作，因此可称封装的私有状态。它能减少误写和集中不变量，但有重要边界：

- 浏览器用户仍可修改自己运行的前端代码，闭包不能保护服务器秘密；
- Node 进程内闭包不持久，进程重启状态丢失；
- 多进程、多标签页、多设备各有不同内存，不自动一致；
- 闭包没有事务、乐观锁、审计或权限；
- 若返回的方法泄露内部对象引用，调用方仍可能绕过操作边界；
- 调试器可观察运行时状态，不应把密钥放进前端闭包。

闭包适合 UI 临时状态、工厂实例配置和局部缓存；数据库事实、授权与跨请求协调必须用适合的系统边界。

## 回调为什么经常形成闭包

回调函数若引用定义位置外层绑定，就形成闭包：

```js
function createStatusLogger(prefix) {
  // 返回的回调稍后被调用时仍读取本次工厂调用的 prefix。
  return (status) => {
    console.log(`${prefix}:${status}`);
  };
}

const logPreview = createStatusLogger("preview");
logPreview("CREATED");
```

回调何时调用仍由接收方/宿主合同决定。同步调用、DOM 事件、定时器和 Promise 都可能持有闭包，但时间顺序不同。本章只验证同步/手动调用；事件循环在后续异步章系统学习。

回调持有的外部环境可能比预期活得久。若捕获大型对象或过期页面状态，可能造成内存保留或 stale closure。解决前先画可达图：谁持有回调？回调引用哪些绑定？何时删除监听或放弃引用？不要把所有内存增长都归因于“闭包泄漏”，也不要声称一次置 null 就证明已 GC。

## 循环变量捕获：`var` 共享，`let` 按迭代建立绑定

受控故障：

```js
let readFirst;
let readSecond;

// var index 属于同一函数/模块变量环境，两份回调读取同一个最终绑定。
for (var index = 0; index < 2; index += 1) {
  if (index === 0) {
    readFirst = () => index;
  } else {
    readSecond = () => index;
  }
}

console.log(readFirst());  // 2，不是 0
console.log(readSecond()); // 2，不是 1
```

循环结束时共享 index 为 2，之后调用两份函数都读 2。主线修复是 for 头部使用 let：规范为每次迭代提供新的绑定，使第一回调捕获 0 那轮绑定、第二回调捕获 1 那轮绑定。

```js
for (let index = 0; index < 2; index += 1) {
  // 每轮 index 绑定不同，稍后回调分别读取 0 与 1。
}
```

不要用 setTimeout 延迟差异来解释根因；即使手动在循环后同步调用，也能观察共享绑定问题。修复后重跑 0/1 预言，并检查闭包是否还捕获了其他共享可变值。

## 意外共享：状态放错一层

```js
// 故障：sharedCount 位于工厂外，所有实例闭合相同模块绑定。
let sharedCount = 0;

function createCounter() {
  return {
    increment() {
      sharedCount += 1;
      return sharedCount;
    },
    read() {
      return sharedCount;
    },
  };
}
```

创建 first 和 second 后，first.increment 会让 second.read 也得到 1。首证据是隔离矩阵中未被调用的 second 状态改变。修复是把 count 声明移入 createCounter，使每次调用建立新绑定。残余风险是返回方法仍可能引用模块级配置、对象或指标；逐个检查自由变量。

“自由变量”是函数体使用但未在本函数内声明/作为参数提供的名字。它可能是合理只读配置，也可能是共享泄漏。用编辑器查引用或手工列出，而不是只看变量名是否叫 private。

## 遮蔽导致更新了错误绑定

```js
function createCounter() {
  let count = 0;

  function increment() {
    // 故障：局部 count 遮蔽外层闭包状态；外层始终不变。
    let count = 10;
    count += 1;
    return count;
  }

  return {
    increment,
    read: () => count,
  };
}
```

increment 返回 11，但 read 仍是 0。最终日志若只看 increment 可能误以为计数成功。首证据是“increment 返回值”与“read 观察的外层状态”在同一次调用后不一致。删除错误局部声明，让赋值解析到工厂环境 count；或改名表达它真的是临时值。修复后重跑连续两次和第二实例隔离案例。

## stale closure：先问捕获的是哪个绑定/快照

```js
function createStatusView() {
  let currentStatus = "CREATED";
  const snapshot = currentStatus;

  return {
    update(nextStatus) {
      currentStatus = nextStatus;
    },
    readCurrent() {
      return currentStatus;
    },
    readSnapshot() {
      return snapshot;
    },
  };
}
```

update("ASSIGNED") 后，readCurrent 返回 ASSIGNED，readSnapshot 仍返回 CREATED。这不是引擎忘了更新，而是两个函数捕获不同绑定：一个可变当前值，一个不可变创建时快照。若调用方误把 readSnapshot 当 current，就产生 stale 语义。

诊断问题：需求要当前值还是创建时快照？捕获发生在哪次工厂/渲染调用？谁仍持有旧回调？不要通过把所有状态改成全局变量“解决陈旧”，那会引入共享泄漏。Vue composable 每次实例化与组件生命周期也会产生作用域边界；具体响应式规则留到 Vue 卷，本章只保留语言层模型。

## 生命周期与垃圾可达性

闭包使环境能够超越外层函数返回而存活，但不是永生。以 counter 为例：

```text
模块绑定 first
  → 返回对象
    → increment/read 函数
      → createCounter 的环境
        → count/name 绑定
```

只要 first 或其他引用仍能到达这些函数，环境就可达。如果所有返回方法都不可达，环境及其只被该环境引用的数据可以成为垃圾回收候选。候选不等于立即回收；GC 时机、内存布局和优化由引擎决定。

本章验收只预测可达性：

- 工厂返回前，局部环境由当前调用可达；
- 返回后，只要返回函数被保存，捕获环境可达；
- 删除最后外部引用后，若无其他路径，环境可成为不可达候选；
- 不能用一次内存快照或 `global.gc()` 声称精确回收时间。

若需要诊断内存，使用目标 Node/浏览器版本的 heap snapshot、分配时间线和保留路径；那是性能章节任务。本章不启用非默认 GC 标志作为 canonical 证据。

## 两个实例的完整作用域追踪

独立 build 的追踪表应同时记录绑定身份与值：

| 时刻 | 活动调用 | 名字解析 | 环境身份 | 值 | 可达原因 |
| --- | --- | --- | --- | ---: | --- |
| A | createCounter("A") | count 局部 | env-A | 0 | 当前调用 |
| B | 返回 A API | increment/read→count | env-A | 0 | `counterA` 持有函数 |
| C | createCounter("B") | count 局部 | env-B | 0 | 当前调用 |
| D | A.increment | count→env-A | env-A | 1 | counterA 调用 |
| E | B.read | count→env-B | env-B | 0 | counterB 调用 |
| F | A.increment | count→env-A | env-A | 2 | counterA 调用 |

不要只写“count=1”，必须区分 env-A.count 与 env-B.count。遮蔽故障还要增加 inner-call.count。可达性列是预测，不要求引擎暴露环境对象。

## 调试顺序

```text
1. 找调用时实际执行的函数值
2. 找该函数定义位置，而非只看调用位置
3. 列函数内声明、参数和自由变量
4. 对每个自由变量沿词法外层找最近绑定
5. 标注绑定身份、创建时刻和当前值
6. 标注谁持有返回函数/回调，判断可达路径
7. 对比隔离矩阵、调用顺序和 stdout/断言第一处分歧
```

ReferenceError 可能来自 TDZ 或作用域外访问；值错误可能来自遮蔽；实例互相影响可能来自状态层级过高；所有回调读最终索引多半来自 var 共享绑定。每次修复一个绑定位置或声明种类，再原样复跑。

## 浏览器与 Node 边界

词法作用域与闭包属于 ECMAScript，在浏览器和 Node 中核心语义一致。宿主差异影响谁长期持有回调：浏览器事件监听器、定时器、DOM 节点可能保留函数；Node 模块缓存、事件发射器、定时器和服务进程也可能保留。

Node CLI 进程结束会丢失内存闭包；浏览器刷新/关闭页面也会重建环境。热更新、测试隔离和模块加载器可能改变模块实例生命周期，不能把开发体验当生产持久性。正式内存诊断记录宿主、版本、注册/移除路径和快照；本章局部资产只验证语言输出。

## FactoryCare：闭包不是状态机、权限或数据库

闭包可用于页面内的临时预览计数器、单次交互的去抖配置或封装某个 composable 实例状态。它不适合保存权威工单状态、乐观版本、租户权限或审计历史。

真实 FactoryCare 工单只有契约中的 12 个状态，Java 后端是写入权威。前端闭包即使把 status 藏起来，也不能阻止用户改代码，不能跨设备一致，不能处理并发，不会写 transition/audit/outbox。Python/LangGraph 的 checkpoint 也不是工单状态权威。反例是用闭包 `setStatus("CLOSED")` 声称完成关单；正确方案必须调用有授权、版本和前置校验的后端命令。

两个闭包计数器的名称使用 `previewA`/`previewB`，注释明确数据来自教学输入。它们证明隔离语义，不代表真实通知重试、SLA 或幂等计数。真正跨请求计数需要持久化和并发合同。

## 常见误解

### “闭包会复制外部值”

通常捕获的是绑定联系，调用时读当前值。要快照应创建独立绑定并明确命名。

### “外层函数返回后局部变量一定消失”

若仍可达的内部函数引用它，环境继续可达。返回只结束调用，不切断所有引用。

### “闭包变量就是安全私有字段”

它提供词法访问边界，不提供服务器授权、加密、持久化或跨进程一致性。

### “两个工厂返回值看起来不同，所以状态一定独立”

若状态声明在工厂外，两份方法仍引用同一绑定。必须用交叉调用断言隔离。

### “调用位置的局部变量会影响被调用函数”

JavaScript 是词法作用域，函数按定义位置解析自由变量，不是动态作用域。

### “把 var 改成 let 只是代码风格”

循环捕获时语义不同：var 共享一个绑定，for-let 为迭代建立独立绑定。

### “置为 null 后可以断言内存已经释放”

最多移除一条引用；还可能有其他路径，GC 时间也不确定。只能先预测可达性。

## 练习资产

- `examples/encyclopedia/ch.js.scope-closures/`：两个独立计数器、遮蔽与实时/快照读取的绿色轨迹；
- `labs/encyclopedia/ch.js.scope-closures/`：隔离断言和循环捕获、遮蔽、共享状态三类故障；
- `exercises/encyclopedia/ch.js.scope-closures/`：公开红灯，依次修复共享层级、遮蔽和 var 循环捕获；
- `solutions-private/encyclopedia/ch.js.scope-closures/`：同一合同绿色参考。

每个目录只有一个 verify.sh。所有 JS 注释标明环境职责、状态来源、非显然绑定映射与输出/修改副作用。

## 120 秒口述模板

> JavaScript 按源码嵌套形成词法环境，名字从当前环境沿 OuterEnv 找最近绑定。let/const 是块作用域；函数调用建立本次参数和局部环境；同名内层绑定会遮蔽外层。let/const 从环境创建到声明初始化之间处于 TDZ。函数值创建时保留解析自由变量所需的词法联系，返回后只要函数仍可达，捕获环境也可达；闭包读取绑定当前值，不必是创建时快照。工厂每次把状态声明在内部才能得到两个独立实例。var 循环回调共享最终索引，for-let 按迭代捕获。闭包私有状态不是 FactoryCare 的持久化、授权或状态机，这是边界反例。

## 验收清单

### Explain

- [ ] 能画模块→函数→块的外层环境链并按定义位置解析名字。
- [ ] 能区分遮蔽、外层重赋值和 TDZ。
- [ ] 能解释捕获绑定、实时值与显式快照。
- [ ] 能解释闭包可达性但不承诺 GC 时刻。
- [ ] 能说明闭包私有与系统安全/持久性的边界。

### Build

- [ ] 两次工厂调用产生 env-A/env-B 两个 count 绑定。
- [ ] A 连续调用得到 1、2，B 初次得到 1，交叉 read 证明隔离。
- [ ] 作用域追踪表记录创建、捕获、调用、当前值和可达原因。
- [ ] 回调入口能说明谁持有/调用闭包。
- [ ] 保存 Node 路径/完整版本、预测、stdout/stderr 与退出码。

### Diagnose

- [ ] var 循环捕获从共享最终绑定定位并用 for-let 修复。
- [ ] 遮蔽故障区分 inner count 与 factory count。
- [ ] 共享泄漏找到状态声明层级过高，而不是重置第二实例掩盖。
- [ ] 每次只改一个绑定位置/声明种类，原样复跑隔离矩阵并写残余风险。

## 本章边界与后续

本章不教授响应式框架闭包细节、异步竞态、WeakRef/FinalizationRegistry、手工 GC、对象原型、类私有字段或跨请求状态管理。下一章数组/对象/Map/Set 会扩展数据边界；闭包示例返回的小对象只作为固定 API 外壳，不在此展开集合方法。

## 官方资料与核验日期

以下一手资料于 **2026-07-17** 核验：

- [ECMAScript 2026：Executable Code and Execution Contexts](https://tc39.es/ecma262/2026/multipage/executable-code-and-execution-contexts.html)
- [ECMAScript 2026：Environment Records](https://tc39.es/ecma262/2026/multipage/executable-code-and-execution-contexts.html#sec-environment-records)
- [ECMAScript 2026：Let and Const Declarations](https://tc39.es/ecma262/2026/multipage/ecmascript-language-statements-and-declarations.html#sec-let-and-const-declarations)
- [ECMAScript 2026：Function Definitions](https://tc39.es/ecma262/2026/multipage/ecmascript-language-functions-and-classes.html#sec-function-definitions)
- [Node.js Releases](https://nodejs.org/en/about/previous-releases)
- [Node.js v24 Assert](https://nodejs.org/download/release/latest-v24.x/docs/api/assert.html)

词法环境和函数创建语义是稳定核心；Node 维护状态和 patch 是易变事实。核验日 v24（Krypton）仍列为 LTS，正式证据需在实际 Node 24.x 环境复跑。
