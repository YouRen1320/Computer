---
schema_version: 2
edition: 2026.2-draft
id: ch.js.functions
title: 函数、参数、返回值与回调入口
responsibility: 用函数声明/表达式、参数、返回值和函数值封装单一计算，首次认识回调入口但不在本章教授闭包状态。
volume: '08'
order: 5
level: L1
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.js.functions.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.js.control-flow
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
  text: 在 120 秒内解释“函数、参数、返回值与回调入口”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - js-function-contract
  - js-function-values
  covers_topics:
  - js.function-declaration-expression
  - js.parameter-argument
  - js.return-value
  - js.default-rest-parameter
  - js.arrow-function
  - js.function-as-value
  - js.callback-entry
  - js.pure-function-boundary
  uses_capabilities:
  - web.javascript-language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“函数、参数、返回值与回调入口”构建可运行程序与测试：把一段工单统计脚本拆成可独立调用和验证的小函数；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - js-function-contract
  - js-function-values
  covers_topics:
  - js.function-declaration-expression
  - js.parameter-argument
  - js.return-value
  - js.default-rest-parameter
  - js.arrow-function
  - js.function-as-value
  - js.callback-entry
  - js.pure-function-boundary
  uses_capabilities:
  - web.javascript-language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: input-output-table-assertion-script-call-trace
- id: diagnose
  kind: fault-diagnosis
  text: 面对“参数顺序、缺失 return 或意外共享副作用造成的结果错误”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - js-function-contract
  - js-function-values
  covers_topics:
  - js.function-declaration-expression
  - js.parameter-argument
  - js.return-value
  - js.default-rest-parameter
  - js.arrow-function
  - js.function-as-value
  - js.callback-entry
  - js.pure-function-boundary
  uses_capabilities:
  - web.javascript-language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 函数、参数、返回值与回调入口

前几章的脚本已经能验证值、分支和循环，但所有步骤挤在顶层时，读者必须每次从头追踪整份文件。函数把一段有名字的行为变成可重复调用的单位：调用方提供实参，函数通过形参接收输入，执行单一职责，并以返回值或明确副作用交出结果。

函数不是“把很多代码塞进花括号”的整理技巧。一个可验证函数必须有合同：接受什么、返回什么、可能产生什么副作用、会被调用几次。JavaScript 的函数本身又是值，可以赋给绑定、作为参数传入另一个函数，于是出现回调入口。本章只认识同步回调和纯函数边界，不教授闭包状态；下一章才追踪函数保存外部绑定的生命周期。

## 学完以后，你应当能交出什么

你需要完成三类证据：

1. 在 120 秒内解释函数声明/表达式、形参/实参、返回值、默认/剩余参数、箭头函数、函数值、回调和纯函数边界，并给出一个本章不应解决的反例；
2. 从空目录把一段工单统计脚本拆为可独立验证的小函数，为每个函数保存输入—输出表、副作用说明和调用轨迹；
3. 注入参数顺序颠倒、缺失 `return` 和意外共享副作用，指出第一条合同分歧，单点修复后重跑相同断言与调用轨迹。

canonical T1 预言是：每个函数的输入、返回值、副作用和调用次数都与合同表一致，缺失 `return` 能被断言准确定位。仅看最终 stdout 正确，不能证明中间函数没有多调用、改全局状态或偶然抵消错误。

## 函数合同：先写四格，再写语法

以“合计有效处理分钟”为例：

| 合同维度 | 明确内容 |
| --- | --- |
| 输入 | `activeMinutes` 与 `reviewMinutes`，都应是已验证的非负数字 |
| 返回 | 两者之和的 Number 值 |
| 副作用 | 无；不输出、不写外部绑定、不修改调用方数据 |
| 调用次数 | 每个断言案例调用一次；重复相同输入应得到相同结果 |

然后才写：

```js
// 纯计算函数只根据两个已验证分钟值求和，不读取或修改外部状态。
function totalMinutes(activeMinutes, reviewMinutes) {
  return activeMinutes + reviewMinutes;
}

// 调用方提供两个实参，并保存函数返回值用于断言或输出。
const total = totalMinutes(35, 5);
console.log(`total=${total}`);
```

函数名应是动作或计算结果，如 `totalMinutes`、`formatPriorityLabel`、`isValidScore`。`doThing` 不能告诉读者合同。一个函数若同时验证、写数据库、发通知、改页面和格式化文本，很难用一个输入—输出表证明；先拆职责，再讨论复用。

### “纯”是可观察合同，不是赞美词

纯函数对同样输入返回同样结果，而且不产生调用方可观察的副作用。它可以创建局部绑定、使用控制流；关键是结果只由显式输入决定，且不改外部世界。

```js
// score 与阈值是显式输入；函数不读当前时间、全局变量或网络。
function classifyPriority(score) {
  if (score >= 80) {
    return "P1";
  }
  if (score >= 50) {
    return "P2";
  }
  return "P3";
}
```

`console.log`、写文件、修改模块级计数器、改变传入对象、发网络请求都是副作用。副作用不等于永远错误，真实系统必须与外界交互；但要放在清楚的边缘函数中并写入合同。纯计算更容易预测、复用和测试。

## 函数声明：给行为一个稳定名字

函数声明的基本形状：

```js
function formatWorkOrder(workOrderId, status) {
  return `${workOrderId}:${status}`;
}
```

`function` 开始声明，`formatWorkOrder` 是绑定名，括号中是形参列表，花括号是函数体。定义函数不会执行函数体；只有求值调用表达式 `formatWorkOrder("WO-1001", "CREATED")` 才进入一次调用。

在模块顶层，函数声明的绑定会在模块初始化过程中建立，因此源码中较早位置可以调用稍后写出的函数声明。语言允许不代表组织上总应这样做。本书优先“先定义后使用”，让阅读顺序与调用证据一致。块级函数声明还有历史 Web 兼容细节，零基础代码不要把函数声明塞进条件块再依赖宿主差异。

每次调用会创建新的执行上下文和参数/局部绑定。两个调用的 `activeMinutes` 不是同一个槽位：

```js
// 两次调用各自接收实参并独立计算，不共享局部 total。
function totalMinutes(activeMinutes, reviewMinutes) {
  const total = activeMinutes + reviewMinutes;
  return total;
}

console.log(totalMinutes(10, 2));
console.log(totalMinutes(30, 5));
```

函数返回后，普通局部状态不再被调用方直接访问。下一章会解释：若返回的函数仍引用局部绑定，该环境可以继续存活。

## 函数表达式：先产生函数值，再赋给绑定

函数表达式出现在表达式位置，可赋给 `const`：

```js
// 函数表达式产生函数值，formatPriorityLabel 绑定保存这个值。
const formatPriorityLabel = function (priority) {
  return `priority=${priority}`;
};

console.log(formatPriorityLabel("P1"));
```

此处 `const` 绑定在初始化前处于暂时性死区，不能在声明行之前调用。函数声明与函数表达式的“何时可调用”不同，诊断 ReferenceError 时要先确认定义形式和调用位置。

命名函数表达式也可以给内部栈轨迹更清楚的名字：

```js
// 外部通过 normalizeMinutes 调用，内部名字可帮助递归或栈追踪；本例不做递归。
const normalizeMinutes = function normalizeMinutesValue(minutes) {
  return Number(minutes);
};
```

日常选择不只看短长：顶层具名公共行为常用函数声明；需要把函数作为某个表达式结果或局部值时可用函数表达式/箭头函数。团队一致性和可读调用轨迹比“全部改成一种”更重要。

## 形参与实参：位置就是合同的一部分

定义中的名字是参数（形参），调用时提供的值是实参：

```js
// workOrderId 是第一个形参，status 是第二个形参。
function formatWorkOrder(workOrderId, status) {
  return `${workOrderId}:${status}`;
}

// 两个字符串是本次调用的实参，按位置绑定到形参。
const summary = formatWorkOrder("WO-1001", "CREATED");
```

JavaScript 不会根据变量名自动重排。调用 `formatWorkOrder("CREATED", "WO-1001")` 完全合法，却得到颠倒结果。两个参数类型相同尤其危险，因为运行时不会抛类型错误。合同表必须包含有辨识度的值，让颠倒能从输出看见。

实参数量也不是严格 arity 检查：缺少的形参通常得到 `undefined`，多出的普通实参可以被函数忽略。`formatWorkOrder("WO-1001")` 可能返回 `WO-1001:undefined` 而不是抛错。若缺失非法，函数应显式验证，测试也必须覆盖；本章不把 TypeScript 静态检查冒充运行时保护。

参数传递的是值。原始值直接传递其值；对象实参传递的是引用值的副本，因此函数可经该引用观察或修改同一对象。完整对象变更策略留到集合章；纯函数主线先使用数字和字符串，避免意外共享。

## `return`：结束当前函数并交回一个值

`return expression;` 先求值表达式，然后立即结束当前函数，把值交给调用表达式。函数体走到末尾、执行裸 `return;`，或某条路径没有 return，调用结果都是 `undefined`。

```js
// 每条有效控制路径都返回一个明确字符串。
function classifyPriority(score) {
  if (score >= 80) {
    return "P1";
  }
  if (score >= 50) {
    return "P2";
  }
  return "P3";
}
```

`console.log(total)` 不等于 `return total`。日志是副作用，调用方收到的仍可能是 undefined：

```js
// 反例：函数只打印计算值，没有把值返回给调用者。
function totalMinutes(activeMinutes, reviewMinutes) {
  const total = activeMinutes + reviewMinutes;
  console.log(`debugTotal=${total}`);
}

const result = totalMinutes(10, 2); // result 是 undefined
```

断言应该检查返回值，而不是从日志猜。缺失 return 的首证据通常是 `actual: undefined`，再沿调用轨迹回到函数体各路径。

### return 后的语句不可到达

一旦执行 return，当前函数后续语句不会运行。早返回可先拒绝非法输入：

```js
// 非整数输入提前返回固定错误标记，不进入分类分支。
function classifyPriority(score) {
  if (!Number.isInteger(score)) {
    return "INVALID";
  }
  if (score >= 80) {
    return "P1";
  }
  return "P2_OR_P3";
}
```

不要在 return 后放关键副作用并以为会执行。静态工具可能标记不可达代码，测试应验证副作用次数。

### return 与换行

`return` 后若立即换行，自动分号插入会让它等价于裸 return：

```js
// 反例：换行让函数返回 undefined，下一行对象字面量不会成为返回值。
function buildResult() {
  return
  { status: "CREATED" };
}
```

把返回表达式写在同一行起始位置；多行对象用括号明确包围。格式化器能降低风险，但不能替代理解。

## 默认参数：只在实参缺失或为 undefined 时启用

```js
// reviewMinutes 缺失时默认 0；显式 null 不会触发默认值。
function totalMinutes(activeMinutes, reviewMinutes = 0) {
  return activeMinutes + reviewMinutes;
}

console.log(totalMinutes(10));            // 10
console.log(totalMinutes(10, undefined)); // 10
console.log(totalMinutes(10, 5));         // 15
```

传入 `null`、0、false 或空字符串不会使用默认值。`totalMinutes(10, null)` 在加法规则下可能得到 10，但那是隐式转换，不是默认参数。若 null 非法，应显式拒绝，不要依赖偶然结果。

默认表达式在每次需要默认值的调用时求值，可引用前面已初始化的参数，但不应藏入时间、随机数或外部副作用，否则相同显式输入难以复现。默认参数也会影响函数 `.length` 等反射细节，本章不作为合同主线。

## 剩余参数：把多余实参收进一个明确绑定

```js
// ...minutes 收集本次调用剩余的所有分钟实参，形成一个新数组值。
function sumMinutes(...minutes) {
  let total = 0;
  for (const minute of minutes) {
    total += minute;
  }
  return total;
}

console.log(sumMinutes());         // 0
console.log(sumMinutes(5));        // 5
console.log(sumMinutes(5, 10, 2)); // 17
```

剩余参数必须位于形参列表最后，且只能有一个。它不同于旧式 `arguments` 对象，是真正数组；数组完整 API 留到下一章，本章只借用 `for...of`。rest 不验证元素类型，`sumMinutes(5, "10")` 仍可能触发字符串拼接。输入—输出表要覆盖零个、一个、多个以及非法类型边界。

不要把所有函数都改为 rest 来逃避形参设计。固定语义位置应保留具名参数；真正同质、可变个数的值才适合剩余参数。

## 箭头函数：函数表达式的紧凑形式

```js
// 单表达式箭头函数隐式返回表达式结果。
const formatPriority = (priority) => `priority=${priority}`;

// 块体箭头函数必须显式 return，否则调用结果为 undefined。
const totalMinutes = (activeMinutes, reviewMinutes) => {
  const total = activeMinutes + reviewMinutes;
  return total;
};
```

只有一个简单形参时括号可省略，但本书常保留以便修改；零个或多个参数必须有括号。表达式体无需写 return，块体需要。若隐式返回对象字面量，要用括号避免花括号被解释为块：

```js
// 括号明确表示表达式结果是一个对象，而不是函数块。
const buildPreview = (status) => ({ status, source: "teaching" });
```

箭头函数没有自己的 `this`、`arguments`、`super` 或 `new.target`，也不能作为构造器。`this` 与对象模型留到后续章节；当前规则是：纯转换和短回调可用箭头函数，不要仅为缩短字符盲目替换需要自身调用上下文的方法。

## 函数也是值

定义完成后，函数可以像其他值一样保存和传递：

```js
// formatPriority 是函数值；formatter 保存同一个函数引用，没有立即调用。
const formatPriority = (priority) => `priority=${priority}`;
const formatter = formatPriority;

// 括号在这里才发起调用。
console.log(formatter("P1"));
```

区分 `formatPriority` 与 `formatPriority("P1")`：前者取得函数值，后者调用并取得返回值。把回调参数写成 `formatPriority()` 会提前执行，并把字符串结果传给原本期待函数的位置。

`typeof formatPriority` 是 `"function"`。函数仍是对象的一种可调用值，可以拥有属性，但本章不借属性保存业务状态，以免把函数合同与闭包/对象模型混在一起。

## 回调入口：把“稍后由调用方执行的函数”作为参数

回调是传给另一个函数、由接收方决定何时和以什么实参调用的函数值。它不天然异步：

```js
// applyFormatter 的合同是同步调用 formatter 一次，并返回它的结果。
function applyFormatter(value, formatter) {
  return formatter(value);
}

// 箭头函数作为回调值传入；本例调用在当前栈中立即发生。
const label = applyFormatter("P1", (priority) => `priority=${priority}`);
console.log(label);
```

回调合同至少要说明：

- 谁调用：`applyFormatter`，不是回调自己；
- 何时调用：当前函数内同步，还是宿主未来事件；
- 调几次：恰好一次、最多一次、零到多次；
- 传什么：实参顺序、类型和错误信号；
- 用返回值吗：被接收方返回、忽略或聚合；
- 副作用允许什么：是否可以输出、改状态或重试。

```js
// runTwice 明确调用 callback 两次，调用次数是可断言合同。
function runTwice(value, callback) {
  callback(value);
  callback(value);
}

let callCount = 0;
runTwice("P1", (priority) => {
  // 计数是验证外壳的可观察副作用，证明回调被调用两次。
  callCount += 1;
  console.log(`callback=${callCount},priority=${priority}`);
});
```

浏览器点击事件、Node 定时器和数组方法都会使用回调，但各自时机/错误合同不同。异步、事件循环和 DOM 留到后续章节；不要从一个同步回调推断异步顺序。

## 调用轨迹：不要只盯最终值

对嵌套调用写轨迹：

```text
1. 顶层调用 applyFormatter("P1", formatter)
2. applyFormatter 进入：value="P1"，formatter=<function>
3. applyFormatter 调用 formatter("P1")，这是第 1 次也是唯一一次
4. formatter 返回 "priority=P1"
5. applyFormatter 返回同一字符串
6. 顶层保存 label 并输出
```

若结果错，先找轨迹第一处分歧：实参在第 1 步就颠倒？回调在第 3 步被调用两次？第 4 步得到 undefined 因为缺 return？还是第 5 步忘记把回调结果返回？调用栈的错误位置、断言 actual/expected 和手写轨迹应能相互解释。

Node 的堆栈通常列出失败函数和调用位置；浏览器 DevTools 也可逐帧查看局部绑定。界面不同，语言调用与返回规则相同。不要把调试器里临时改值当成源码已修复证据；修复后重跑原断言。

## 三类规定故障

### 参数顺序颠倒

```js
function formatWorkOrder(workOrderId, status) {
  return `${workOrderId}:${status}`;
}

// 故障：两个字符串实参顺序相反，运行时仍能生成合法字符串。
const summary = formatWorkOrder("CREATED", "WO-1001");
```

首证据是调用入口实参表与函数形参表不一致，实际 `CREATED:WO-1001` 对比预期 `WO-1001:CREATED`。修复调用位置并重跑所有案例。残余风险是同类型位置参数仍易错；未来可使用对象参数，但那属于对象合同设计，不应在本章顺手重构全项目。

### 缺失 return

函数内部计算或日志看似正确，调用结果却是 undefined。首证据是断言 `actual: undefined`，再检查所有控制路径是否显式返回。修复为 return 计算值，而不是让测试读取日志。残余风险是只有部分分支漏 return，应覆盖每条边界路径。

### 意外共享副作用

```js
let sharedCallCount = 0;

// 反例：名为纯计算的函数修改模块级计数，调用顺序会改变外部状态。
function totalMinutes(activeMinutes, reviewMinutes) {
  sharedCallCount += 1;
  return activeMinutes + reviewMinutes;
}
```

返回值可能始终正确，但副作用/调用次数合同失败。首证据是调用前后 sharedCallCount 变化。若计数只为测试，把轨迹放在明确验证外壳；若是业务指标，建立专门的边缘接口。残余风险包括修改传入对象、日志、时间读取或网络调用，不能只检查一个全局变量。

## FactoryCare 场景：纯预览，不是业务命令

适合函数章的示例是纯格式化和统计：

```js
// 输入是已验证的教学快照；函数只计算展示总分钟，不写业务事实。
function totalRecordedMinutes(activeMinutes, reviewMinutes = 0) {
  return activeMinutes + reviewMinutes;
}

// 标签映射用于教学展示，不定义 FactoryCare 唯一状态机。
const formatStatus = (status) => `status=${status}`;
```

不适合本章的反例是 `closeWorkOrder(id)` 只在前端返回 `"CLOSED"` 并声称工单已关闭。真实迁移必须由 Java 后端校验当前状态、角色/租户/数据范围、必填证据、乐观版本、审计和 outbox。Python/AI 也只能提供建议，不是状态写入权威。函数封装能改善代码合同，不能创造权限、事务和持久性。

纯函数可以在 Vue computed、服务端验证或测试中复用，但必须保持数据源说明。如果函数内部读取可变全局配置，它就不再只由形参决定；要把配置显式传入或把副作用写进合同。

## 独立构建：把顶层脚本拆成小函数

目标工件至少包含：

1. 一个函数声明：根据分数返回 P1/P2/P3；
2. 一个函数表达式：合计两个分钟值，第二参数有默认 0；
3. 一个 rest 函数：合计零个、一个、多个已验证分钟；
4. 一个箭头函数：把优先级格式化为纯文本；
5. 一个同步回调入口：调用 formatter 恰好一次并返回其结果；
6. 一份输入—输出—副作用—调用次数合同表；
7. 严格断言与调用轨迹，覆盖正常、边界和三类故障。

先写表，后实现。输出应稳定，不使用当前时间、随机数或网络。保存 Node 路径/完整版本、源码、预测、stdout、stderr 与退出码。资产可在当前 Node 22+ 观察稳定语义，但 canonical 目标仍是 Node 24.x LTS。

## 常见误解

### “定义函数就会执行”

定义创建函数值；只有调用表达式才执行函数体。回调值也要由接收方调用。

### “打印结果等于返回结果”

日志是副作用；没有 return 的调用结果通常是 undefined。

### “参数名会帮我匹配实参名”

普通调用按位置绑定。变量名相似不会自动重排。

### “默认参数会处理 null、0 和空字符串”

默认只在缺失或显式 undefined 时启用，其他值原样进入函数。

### “箭头函数只是更短的 function”

它的 this/arguments/构造能力不同；当前只在纯转换和短回调使用。

### “回调一定异步”

回调描述控制权转交，不描述时间。接收方可以同步立即调用，也可以由宿主稍后调用。

### “返回值对了就证明函数纯”

还需检查外部绑定、输入对象、stdout、文件/网络和调用次数等副作用。

## 练习资产

- `examples/encyclopedia/ch.js.functions/`：声明、表达式、默认/rest、箭头与同步回调绿色轨迹；
- `labs/encyclopedia/ch.js.functions/`：输入输出表与三类受控故障；
- `exercises/encyclopedia/ch.js.functions/`：公开红灯，依次修复参数顺序、缺失 return 和共享副作用；
- `solutions-private/encyclopedia/ch.js.functions/`：同一合同的绿色参考答案。

每目录只有一个 verify.sh。所有 JS 注释说明函数职责、输入来源、非显然映射和副作用；Node assert 是验证外壳，不是业务实现。

## 120 秒口述模板

> 函数把输入映射为返回值或明确副作用。声明和表达式都产生函数值，但绑定初始化时机不同。定义中的形参按位置接收调用实参；缺参通常是 undefined，多参可能被忽略。return 结束当前函数并交回值，遗漏或裸 return 得到 undefined。默认参数只处理缺失/undefined，rest 收集剩余实参。箭头函数适合纯转换和短回调，但调用上下文能力不同。函数可以作为值传入另一个函数形成回调，接收方决定时机、实参和次数。纯函数只依赖显式输入且无可观察副作用。前端函数不能替代 FactoryCare 后端状态机，是边界反例。

## 验收清单

### Explain

- [ ] 能区分声明/表达式、形参/实参、定义/调用、日志/返回。
- [ ] 能解释默认/rest、箭头语法和函数值。
- [ ] 能口述回调的调用者、时机、次数、实参、返回与副作用合同。
- [ ] 能给出一个函数封装不应解决的领域权威反例。

### Build

- [ ] 每个函数都有输入、返回、副作用和调用次数四格合同。
- [ ] 覆盖声明、表达式、默认参数、rest、箭头与同步回调。
- [ ] 正常、边界和缺失输入有运行前预言与严格断言。
- [ ] 调用轨迹能解释每次进入、回调、返回和输出。
- [ ] 保存 Node 路径/版本、stdout、stderr 与退出码。

### Diagnose

- [ ] 参数顺序故障定位到调用入口，而不是修改预期掩盖。
- [ ] 缺失 return 从 actual undefined 回溯到具体路径。
- [ ] 返回正确但共享副作用变化时仍判失败。
- [ ] 修复后重跑相同断言和调用轨迹，并说明同类型参数、分支漏返、输入修改等残余风险。

## 本章边界与后续

本章不教授闭包捕获、长期函数状态、异步/Promise、DOM 事件、对象参数设计、数组高阶方法、`this`、原型或类。下一章将解释函数值为何能在外层调用结束后继续访问某些绑定。先确保普通参数、返回和回调调用次数已经可独立追踪。

## 官方资料与核验日期

以下一手资料于 **2026-07-17** 核验：

- [ECMAScript 2026：ECMAScript Language — Functions and Classes](https://tc39.es/ecma262/2026/multipage/ecmascript-language-functions-and-classes.html)
- [ECMAScript 2026：Function Definitions](https://tc39.es/ecma262/2026/multipage/ecmascript-language-functions-and-classes.html#sec-function-definitions)
- [ECMAScript 2026：Arrow Function Definitions](https://tc39.es/ecma262/2026/multipage/ecmascript-language-functions-and-classes.html#sec-arrow-function-definitions)
- [ECMAScript 2026：The return Statement](https://tc39.es/ecma262/2026/multipage/ecmascript-language-statements-and-declarations.html#sec-return-statement)
- [Node.js Releases](https://nodejs.org/en/about/previous-releases)
- [Node.js v24 Assert](https://nodejs.org/download/release/latest-v24.x/docs/api/assert.html)

函数调用语义是稳定核心；Node 维护状态和 patch 是易变事实。核验日 v24（Krypton）仍列为 LTS，正式项目仍需记录实际 Node 24.x patch。
