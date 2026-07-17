---
schema_version: 2
edition: 2026.2-draft
id: ch.js.values-operators
title: 值、类型、转换、运算符、相等与空值
responsibility: 建立 JavaScript 原始值、对象引用、显式/隐式转换、运算优先级和相等规则，不在本章用控制流掩盖类型问题。
volume: '08'
order: 3
level: L1
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.js.values-operators.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.js.statements-variables
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
  text: 在 120 秒内解释“值、类型、转换、运算符、相等与空值”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - js-values-types
  - js-conversion-operators
  covers_topics:
  - js.primitive-values
  - js.object-reference-intro
  - js.typeof
  - js.null-undefined
  - js.nan-infinity
  - js.explicit-conversion
  - js.coercion
  - js.operator-precedence
  - js.strict-equality
  - js.nullish-coalescing
  uses_capabilities:
  - foundation.toolchain-env-build
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“值、类型、转换、运算符、相等与空值”构建可运行程序与测试：建立覆盖数字、字符串、布尔、null、undefined 和 NaN 的值与转换矩阵；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - js-values-types
  - js-conversion-operators
  covers_topics:
  - js.primitive-values
  - js.object-reference-intro
  - js.typeof
  - js.null-undefined
  - js.nan-infinity
  - js.explicit-conversion
  - js.coercion
  - js.operator-precedence
  - js.strict-equality
  - js.nullish-coalescing
  uses_capabilities:
  - foundation.toolchain-env-build
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: value-table-prediction-assertion-script
- id: diagnose
  kind: fault-diagnosis
  text: 面对“宽松相等、隐式转换或空值回退造成的条件误判”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - js-values-types
  - js-conversion-operators
  covers_topics:
  - js.primitive-values
  - js.object-reference-intro
  - js.typeof
  - js.null-undefined
  - js.nan-infinity
  - js.explicit-conversion
  - js.coercion
  - js.operator-precedence
  - js.strict-equality
  - js.nullish-coalescing
  uses_capabilities:
  - foundation.toolchain-env-build
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 值、类型、转换、运算符、相等与空值

上一章建立了“声明绑定、顺序赋值、输出预言”。现在要回答更基础也更容易出错的问题：绑定里究竟保存了什么值？字符串 `"0"` 和数字 `0` 为什么看起来相似却不是同一类型？一个输入缺失时，`null`、`undefined`、空字符串和数字零能不能统一当成“没有”？为什么程序没有报错，结果却从 `5 + 1` 变成了 `"51"`？

JavaScript 会在一些运算中自动转换值。便利之处是少写代码，危险之处是错误可能产生一个“完全合法但业务错误”的结果。本章不借助 `if`、循环或函数把问题包起来，而是逐项建立值与转换矩阵：先写输入、类型、表达式和预期，再运行断言。下一章才用这些可信布尔结果驱动控制流。

## 学完以后，你应当能交出什么

你需要完成三类证据：

1. 在 120 秒内解释原始值、对象引用、`typeof`、`null`/`undefined`、`NaN`/`Infinity`、显式转换、隐式强制转换、优先级、严格相等与 `??` 的边界，并给出一个本章不应处理的反例；
2. 从空目录建立可运行值矩阵，覆盖数字、字符串、布尔、`null`、`undefined` 和 `NaN`，保存运行前预测、实际值、`typeof`、断言结果、Node 路径/版本与退出码；
3. 注入宽松相等、隐式 `+` 转换和错误空值回退，指出第一个预期—实际分歧，修复后重跑同一验证并说明残余风险。

本章 canonical 验证级别是 T1。只打印一堆结果不够；每个表达式都要先有预期，断言脚本再逐项比较。若断言失败，错误消息应指出是哪一行矩阵合同不一致。

## 前置：绑定不是类型，值才有类型

JavaScript 是动态类型语言：绑定本身不会被固定为某个语言类型，同一个 `let` 可以先保存数字再保存字符串。动态不等于随意。若业务合同要求 SLA 分钟为数字，运行时仍必须在边界转换、验证并保持这一不变量。

```js
// rawSlaMinutes 模拟表单或环境变量原始输入，数据源类型是字符串。
const rawSlaMinutes = "30";

// Number 显式把边界文本转换为后续计算需要的数字值。
const slaMinutes = Number(rawSlaMinutes);

// 输出同时保留值和类型，形成最小诊断证据。
console.log(`raw=${rawSlaMinutes},type=${typeof rawSlaMinutes}`);
console.log(`parsed=${slaMinutes},type=${typeof slaMinutes}`);
```

把“值”“值的类型”“绑定名”“业务含义”分开。`30` 是 Number 类型值；`"30"` 是 String 类型值；`slaMinutes` 是绑定名；“响应 SLA 分钟”是领域含义。名字写得再像数字，也不能改变字符串的运行时类型。

## ECMAScript 的语言值地图

ECMAScript 语言类型包括 Undefined、Null、Boolean、String、Symbol、Number、BigInt 和 Object。前七类通常称为原始类型，Object 是对象类型。原始值不是对象引用；对象则有身份，两个外观相同的对象也可能不是同一个对象。

| 类型 | 最小示例 | `typeof` 常见结果 | 本章关注点 |
| --- | --- | --- | --- |
| Undefined | `undefined` | `"undefined"` | 尚未提供、缺少属性等场景常见 |
| Null | `null` | `"object"` | 明确的空值；`typeof` 有历史特殊结果 |
| Boolean | `true`、`false` | `"boolean"` | 逻辑值，不等同字符串 `"false"` |
| String | `"P1"`、`""` | `"string"` | 表单、URL、环境变量常以文本到达 |
| Number | `0`、`3.5`、`NaN`、`Infinity` | `"number"` | 浮点数、特殊数值与精度边界 |
| BigInt | `9007199254740993n` | `"bigint"` | 任意精度整数，不能与 Number 直接混算 |
| Symbol | `Symbol("id")` | `"symbol"` | 唯一标识用途；零基础先识别边界 |
| Object | `{ status: "CREATED" }` | `"object"` | 引用身份、可变属性、`const` 不等于深冻结 |

规范类型名称与 `typeof` 返回字符串不是同一张表。尤其 `typeof null` 是 `"object"`，这是为 Web 兼容保留的历史行为，不代表 `null` 真的是可访问属性的普通对象。判断空值应直接使用严格相等或空值合同，不能靠 `typeof value === "object"`。

### 原始值按值观察

两个同类型、同内容的字符串严格相等；两个相同数字严格相等。把原始值从一个绑定赋给另一个绑定，后续重新赋值其中一个不会“改写”另一个：

```js
// 两个绑定起初都保存同一个字符串值；后续只更新 currentStatus。
let currentStatus = "CREATED";
const capturedStatus = currentStatus;
currentStatus = "ASSIGNED";

// capturedStatus 仍是 CREATED，输出用于证明赋值时取得了原始值。
console.log(`current=${currentStatus}`);
console.log(`captured=${capturedStatus}`);
```

### 对象按引用身份比较

对象字面量每次求值通常创建新的对象身份：

```js
// firstSnapshot 与 secondSnapshot 内容相似，但来自两次对象创建。
const firstSnapshot = { status: "CREATED" };
const secondSnapshot = { status: "CREATED" };
const aliasSnapshot = firstSnapshot;

// 严格相等比较对象身份；两个独立对象不等，同一引用别名相等。
console.log(firstSnapshot === secondSnapshot); // false
console.log(firstSnapshot === aliasSnapshot);  // true
```

`const` 只阻止绑定重新指向另一个对象，不会自动冻结对象属性。通过 `aliasSnapshot` 修改属性，`firstSnapshot` 也会观察到，因为两者指向同一对象。完整对象模型、复制、冻结和结构相等留到对象章节；本章先建立“外观相同不等于引用相同”的边界。

## `typeof`：快速探针，不是完整验证器

`typeof` 是一元运算符，返回描述操作数类型的字符串：

```js
// 每行同时验证典型值和 typeof 的实际字符串。
console.log(typeof 42);          // number
console.log(typeof "42");        // string
console.log(typeof false);       // boolean
console.log(typeof undefined);   // undefined
console.log(typeof null);        // object
console.log(typeof NaN);         // number
console.log(typeof 42n);         // bigint
console.log(typeof Symbol("x")); // symbol
console.log(typeof {});          // object
```

三个常见陷阱：

- `typeof NaN` 是 `"number"`。它说明 NaN 属于 Number 类型，不说明它是有效业务数字。
- `typeof null` 是 `"object"`。要判断明确空值，使用 `value === null`。
- 数组、普通对象和 `null` 都可能给出 `"object"`；`typeof` 无法完成对象细分类。

对一个完全未声明的标识符使用 `typeof` 有特殊行为，常返回 `"undefined"`；但在同一作用域中、仍处于 `let`/`const` 暂时性死区的名字仍可能抛错。不要把 `typeof missingName` 当成通用配置发现机制。输入合同应显式传入和验证。

## `undefined` 与 `null`：两种空，不是两个拼写

`undefined` 是 Undefined 类型唯一的值，常表示“没有提供”“尚未得到”或“属性不存在”。`null` 是 Null 类型唯一的值，通常由应用合同显式表达“此处有意为空”。语言不替你的业务自动决定两者含义；API、数据库和 UI 必须约定。

```js
// 缺省值模拟未提供的可选字段；显式 null 模拟调用方主动清空负责人。
const omittedAssignee = undefined;
const clearedAssignee = null;

// 两者严格不相等，但都属于 nullish 值。
console.log(omittedAssignee === undefined); // true
console.log(clearedAssignee === null);       // true
console.log(omittedAssignee === clearedAssignee); // false
```

JSON 没有 `undefined` 字面量。对象属性值为 `undefined` 时，序列化行为与 `null` 不同；数组中也有不同处理。这个跨边界差异将在 JSON 章节详讲。本章规则是：在进入序列化、API 或数据库边界前先对空值语义达成合同，不能让 `undefined` 和 `null` 随意互换。

不要用“falsy”代替空值。数字 `0`、空字符串 `""` 和布尔 `false` 都可能是合法业务值，却不是 nullish。下一章会列完整 truthiness；本章先用 `??` 保住合法零值。

## Number、`NaN` 与 `Infinity`

JavaScript 的普通 Number 使用 IEEE 754 双精度浮点格式。它既表示整数也表示小数，因此有精度和范围边界。`0.1 + 0.2` 不会精确等于十进制 `0.3`；金额和计量策略不能靠“屏幕显示差不多”决定。FactoryCare 的金额、时长和数量应按领域精度、单位与后端合同建模，本章不擅自定义财务规则。

### `NaN` 是失败数值，不是异常对象

`Number("not-a-number")` 返回 `NaN`，通常不会抛异常。后续算术往往继续传播 NaN，所以错误可能离边界很远才被发现。

```js
// 原始输入无法转换为数字；Number 返回 NaN 作为可观察失败值。
const parsedMinutes = Number("thirty");

// Number.isNaN 不做额外类型转换，适合验证转换结果。
console.log(`value=${parsedMinutes}`);
console.log(`type=${typeof parsedMinutes}`);
console.log(`isNaN=${Number.isNaN(parsedMinutes)}`);
```

`NaN === NaN` 为 `false`，所以不能用严格相等判断 NaN。使用 `Number.isNaN(value)`；全局 `isNaN` 会先转换输入，容易把字符串等不同问题混在一起。若要求有限数值，使用 `Number.isFinite(value)`，它会同时拒绝 `NaN`、`Infinity` 和 `-Infinity`，且不对字符串做数值强制转换。

### `Infinity` 也是 Number 值

`1 / 0` 得到 `Infinity`，`-1 / 0` 得到 `-Infinity`，通常不会像某些语言的整数除零那样抛异常。`typeof Infinity` 仍是 `"number"`。因此“类型是 number”不足以验证 SLA 分钟、价格或次数。业务数字常需同时检查：转换成功、有限、整数要求、范围和单位。

Number 的安全整数边界可用 `Number.isSafeInteger` 检查。超大整数 ID 不应先变成 Number 再期待完整精度；可能应保留字符串，或在纯整数算法中使用 BigInt。选择取决于接口合同，不应仅因能写 `n` 后缀就改 API 类型。

## 显式转换：让边界变化可见

最常用的三个显式转换入口是 `Number(value)`、`String(value)` 和 `Boolean(value)`。它们仍遵循语言规则，但读者能从源码看到转换意图。

### `Number(...)`

重要结果应写入矩阵，而不是凭直觉：

| 输入 | `Number(input)` | 说明 |
| --- | ---: | --- |
| `"42"` | `42` | 数字文本转换成功 |
| `" 42 "` | `42` | 首尾空白可被数值语法处理 |
| `""` | `0` | 空字符串转零，常是表单陷阱 |
| `"abc"` | `NaN` | 转换失败但不自动抛异常 |
| `true` | `1` | 布尔到数值 |
| `false` | `0` | 布尔到数值 |
| `null` | `0` | 明确空值转零，常不符合业务语义 |
| `undefined` | `NaN` | 缺失值转换失败 |

“语言能转换”不等于“业务允许转换”。空表单是否应当成为 0，必须在调用 Number 之前根据合同处理。不要先把所有缺失值转成数字，再试图猜 0 是用户输入还是空值产物。

### `String(...)`

`String(42)` 得到 `"42"`，`String(null)` 得到 `"null"`，`String(undefined)` 得到 `"undefined"`。它适合明确格式化，但把空值变成字面文本未必适合 UI。模板字面量也会进行字符串化：`` `value=${null}` `` 得到 `value=null`。显示层应先决定空值文案，不要把内部空值意外展示给用户。

### `Boolean(...)`

`Boolean` 根据 truthiness 转换。数字 `0`、`NaN`、空字符串、`null`、`undefined` 和 `false` 会变成 `false`；非空字符串包括 `"false"` 与 `"0"` 都会变成 `true`。所以从环境变量读到 `FEATURE_ENABLED="false"` 后直接 `Boolean(raw)` 会得到 true，这是常见配置故障。布尔文本需要明确解析合同，而不是按非空判断。

## 隐式强制转换：能预测，尽量不依赖

一些运算符会请求操作数转成适合的类型。最著名的是 `+`：若相关操作数走字符串连接路径，结果是字符串；否则可能数值相加。

```js
// 同一个加号会因操作数类型不同而选择数值相加或字符串连接。
console.log(5 + 1);       // 6
console.log("5" + 1);     // 51
console.log(5 + "1");     // 51
console.log("5" - 1);     // 4
```

减号没有字符串拼接含义，会把 `"5"` 转成数字；这不是推荐的输入解析技巧。若 `rawCount` 来自表单，先 `Number(rawCount)`，验证后再算术。这样失败证据位于边界，而不是藏在某个运算符里。

模板字面量、字符串连接、关系比较和宽松相等也可能触发转换。调试时写出每个操作数的值和 `typeof`，再查该运算符规则；不要只看最终结果。对对象，转换还可能调用对象的原始值转换钩子，产生用户代码副作用，本章不把它当日常技巧。

### 浏览器和 Node 最常见的字符串入口

浏览器表单控件的 `.value` 通常是字符串，即使用户看见的是数字输入框。URL 查询参数也以文本出现。Node 的 `process.env.NAME` 是字符串或 `undefined`。两端都需要“原始输入 → 空值处理 → 显式转换 → 有效性验证”的边界链。

浏览器与 Node 对 ECMAScript 核心转换规则一致，但输入来源、对象和开发者工具显示不同。不要因为浏览器 Console 把对象展示得方便，就假定它和 Node stdout 是相同的序列化合同。

## 运算符优先级：解析顺序不是阅读愿望

表达式先按语法优先级和结合性形成结构，再按语言规则求值。乘法优先于加法：

```js
// 第一个表达式先乘后加；括号让第二个表达式先加后乘。
console.log(2 + 3 * 4);   // 14
console.log((2 + 3) * 4); // 20
```

初学阶段应掌握相对层级，而不是背完整表：

```text
括号
→ 一元运算（typeof、!、正负号）
→ 乘除余
→ 加减
→ 关系比较（<、<=、>、>=）
→ 相等（===、!==、==、!=）
→ 逻辑与 &&
→ 逻辑或 ||
→ 空值合并 ??
→ 赋值
```

括号可以表达业务分组，但不能让非法组合变合法。规范禁止不加括号直接混用 `??` 与 `&&`/`||`，例如 `a || b ?? c` 是语法错误；必须明确写 `(a || b) ?? c` 或 `a || (b ?? c)`，两者含义可能不同。

逻辑运算符会短路，而且返回被选中的操作数，不保证返回 Boolean：`"P1" && "urgent"` 得到 `"urgent"`，`0 || 30` 得到 `30`。本章只观察这一值选择行为；下一章才用布尔表达式驱动分支。若合同要求真正布尔值，使用明确比较或 `Boolean(...)` 并先理解输入语义。

复合表达式一旦难以口述，就拆成有名字的中间值。可读性比展示“我会背优先级”更重要。诊断矩阵应记录括号化后的意图，避免读者与运行时解析不同。

## 严格相等：默认合同

`===` 和 `!==` 不在两侧类型不同的时候做数值/字符串强制转换。类型不同通常直接不等：

```js
// 严格相等保留输入类型差异，宽松相等会执行额外转换。
console.log("0" === 0);  // false
console.log("0" == 0);   // true
console.log(false === 0); // false
console.log(false == 0);  // true
```

本书业务代码默认使用严格相等。它不能替代输入转换：若接口允许数字文本，应先显式转成数字并验证，再与数字比较。把 `==` 当“兼容各种输入”的捷径，会把 `""`、`0`、`false`、`null` 等不同业务状态通过复杂规则折叠。

宽松相等有完整规范，不是随机行为；但它增加读者必须模拟的转换步骤。一个有限的惯例是 `value == null` 同时匹配 `null` 和 `undefined`，但本教程仍优先写明确空值合同或使用 `??`，避免团队混合风格。历史网页对象 `document.all` 还有特殊兼容行为，更说明不要把宽松相等当通用验证器。

### 相等的边界值

- `NaN === NaN` 为 false；用 `Number.isNaN`。
- `0 === -0` 为 true；`Object.is(0, -0)` 为 false。
- `Object.is(NaN, NaN)` 为 true，但不是把所有业务相等都换成 `Object.is` 的理由。
- 两个独立对象即使属性相同，`===` 仍比较引用身份并得到 false。
- BigInt 与 Number 即使数学值相似，`1n === 1` 仍为 false，而且二者不能直接相加。

选择相等算法要从合同出发。本章常规标量匹配使用严格相等；NaN 有专用探针；对象结构相等留给测试和对象章节。

## `??`：只为空值提供默认值

空值合并运算符 `left ?? fallback` 只在左侧为 `null` 或 `undefined` 时返回右侧，否则保留左侧：

```js
// 0 是合法的“无需重试”，?? 保留它；|| 会错误替换为默认 3。
const configuredRetries = 0;
const safeRetries = configuredRetries ?? 3;
const lossyRetries = configuredRetries || 3;

console.log(`safe=${safeRetries}`);   // safe=0
console.log(`lossy=${lossyRetries}`); // lossy=3
```

同理，`false ?? true` 保留 false，`"" ?? "未填写"` 保留空字符串，`NaN ?? 0` 保留 NaN。`??` 不是有效性验证器，只解决 nullish 缺失。若 NaN 或空字符串非法，需要独立合同判断，不能指望空值合并修复。

右侧表达式只在左侧 nullish 时求值，这是短路。若右侧包含日志、计数或其他副作用，是否执行会依赖左值；零基础主线让 fallback 保持无副作用的固定值，降低诊断难度。

可选链 `?.` 常与 `??` 组合，但它属于对象访问章节。本章不要用长链掩盖哪个字段缺失。先把输入拆成清晰中间值并记录类型。

## 建立可验收的值与转换矩阵

canonical build 要覆盖数字、字符串、布尔、`null`、`undefined` 和 `NaN`。推荐表头：

| case | 原始表达式 | 预期值 | 预期 `typeof` | 验证方式 |
| --- | --- | --- | --- | --- |
| number | `42` | `42` | `number` | 严格相等 |
| string | `"42"` | `42` 文本 | `string` | 严格相等 |
| boolean | `false` | `false` | `boolean` | 严格相等 |
| null | `null` | `null` | `object` | `value === null` |
| undefined | `undefined` | `undefined` | `undefined` | 严格相等 |
| NaN | `Number("bad")` | NaN | `number` | `Number.isNaN` |
| explicit number | `Number("42")` | `42` | `number` | 严格相等 |
| strict equality | `"0" === 0` | `false` | `boolean` | 严格相等 |
| nullish zero | `0 ?? 30` | `0` | `number` | 严格相等 |

“预期值”要能无歧义编码。NaN 不能用 `===` 自比；对象不能靠普通 `===` 判断结构。断言方法也是合同的一部分。矩阵写完并签下“预测先于运行”后才执行脚本。

证据目录至少保存：源码、预期表、实际 stdout、stderr、退出码、Node 路径/完整版本和失败复跑记录。正式目标是 Node 24.x LTS；局部资产使用稳定语言核心，可在 Node 22+ 观察，但不能把兼容性观察冒充目标工具链证据。

## 三类规定故障的首证据

### 宽松相等误判

场景：表单给出 `"0"`，代码用 `raw == 0` 判断“无需重试”。表达式得到 true，但输入仍是字符串，其他格式如空字符串也可能被折叠为零。

首个可信证据不是最终分支，而是矩阵中 `raw` 的值/类型和 `raw == 0` 与 `raw === 0` 的不同。修复为：在边界明确 `Number(raw)`，验证结果符合整数与范围合同，再使用严格相等。残余风险是空字符串和 `null` 经 Number 可变成 0，因此空值处理必须早于数值转换。

### 隐式转换导致拼接

场景：已有处理时长 `5`，新增文本 `"1"`，`5 + "1"` 得到 `"51"`。进程没有异常，stdout 也是合法字符串。

首证据是加号两侧 `typeof` 与预期矩阵第一次分歧。修复应在输入边界显式转换和验证，而不是改成减法、乘以 1 或在结果上再 Number。残余风险包括小数精度、NaN、Infinity 和单位混用。

### 空值回退丢失合法值

场景：重试次数 `0` 经 `0 || 3` 变成 3，布尔 false 或空字符串也会丢失。首证据是原值为 0、类型为 number，而回退表达式结果是 3。

若合同只把 `null`/`undefined` 当缺失，修复为 `value ?? 3`。若空字符串也代表缺失，应先明确规范化，不能假装 `??` 会处理。残余风险是 NaN 非 nullish；仍需有效性验证。

每次都按“保存失败 → 定位第一处分歧 → 单点修复 → 原断言复跑 → 记录残余风险”。不要一次把 `==`、转换和 fallback 全改了后只留下绿色截图。

## FactoryCare 场景：边界值不是状态机

FactoryCare 前端可能收到 SLA 分钟、重试次数、优先级建议和可选负责人。下面是适合本章的纯值问题：

```js
// rawRetryCount 模拟表单输入；文本来源必须在进入计算前显式转换。
const rawRetryCount = "0";
const parsedRetryCount = Number(rawRetryCount);

// 0 是合法配置，只有 null/undefined 才应触发默认值。
const effectiveRetryCount = parsedRetryCount ?? 3;

// stdout 暴露原始类型、转换类型和最终值，便于矩阵逐项核对。
console.log(`rawType=${typeof rawRetryCount}`);
console.log(`parsedType=${typeof parsedRetryCount}`);
console.log(`effective=${effectiveRetryCount}`);
```

真实系统还必须验证整数、范围、租户权限和 API 合同。本章不能决定工单是否能从 `CREATED` 进入 `TRIAGED`，也不能用 `priority == "P1"` 绕过 Java 后端。唯一 12 状态机、合法边、版本检查、审计和 outbox 仍以后端契约为权威。值转换正确只证明数据形状的一小部分，不证明迁移有权且原子。

一个明确反例是“用户用修改前端值把 CLOSED 工单直接改成 IN_PROGRESS”。这不是换成严格相等能解决的；必须由后端命令、权限、当前状态、版本和审计共同拒绝。

## 常见误解

### “`typeof value === "number"` 就是可用数字”

NaN 和 Infinity 也都是 number。按合同再检查 `Number.isFinite`、整数性与范围。

### “空值都可以写 `!value`”

这会把 0、false、空字符串和 NaN 一起视为 falsy。若只处理 null/undefined，使用明确空值判断或 `??`。

### “`==` 会智能地帮我转换”

它按固定但复杂的抽象相等规则转换，不知道业务意图。边界显式转换，内部严格相等。

### “`const` 对象不会变化”

`const` 禁止绑定重赋值，不深度冻结对象。多个别名可观察同一对象属性变化。

### “NaN 等于自己，所以可以直接断言”

NaN 与任何值（包括自身）的普通相等都为 false。使用 `Number.isNaN`。

### “`??` 能修复所有无效输入”

它只处理 null 和 undefined；NaN、Infinity、空字符串和越界数字会被原样保留。

### “加括号只是为了好看”

括号能改变表达式结构和结果，也能让 `??` 与 `||`/`&&` 的组合语法明确。先按合同分组再求值。

## 练习资产

- `examples/encyclopedia/ch.js.values-operators/`：绿色标量与转换矩阵；
- `labs/encyclopedia/ch.js.values-operators/`：绿色基线加宽松相等、隐式拼接、空值丢失三类受控故障；
- `exercises/encyclopedia/ch.js.values-operators/`：公开稳定红灯，要求修正 `typeof null` 预言、边界转换、严格相等与 `??`；
- `solutions-private/encyclopedia/ch.js.values-operators/`：相同合同的绿色参考答案。

每个目录只有一个 `verify.sh`。资产不联网、无第三方依赖，使用 Node 内置严格断言。调用断言是验证外壳，不在本章教授自定义函数设计。

## 120 秒口述模板

> JavaScript 的值有 Undefined、Null、Boolean、String、Symbol、Number、BigInt 和 Object 类型，前七类是原始类型，对象比较引用身份。`typeof` 是快速探针，但 null 返回 object、NaN 返回 number。输入边界应先区分缺失，再显式 Number/String/Boolean 转换并验证；隐式 `+`、宽松相等和逻辑回退可能折叠不同类型。内部默认用严格相等；NaN 用 Number.isNaN；只有 null/undefined 缺失时用 `??`，从而保留 0、false 和空字符串。我的证据是运行前值矩阵、实际值与 typeof、断言和退出码。前端值检查不能替代 FactoryCare 后端状态机，是本章边界反例。

## 验收清单

### Explain

- [ ] 能列出语言类型并解释原始值与对象引用身份。
- [ ] 能解释 `typeof null`、`typeof NaN` 两个陷阱。
- [ ] 能区分 null、undefined、falsy 和无效数字。
- [ ] 能说明显式转换、隐式转换、优先级和严格相等边界。
- [ ] 能给出一个不属于本章的领域授权反例。

### Build

- [ ] 从空目录创建，不复制私有答案。
- [ ] 覆盖 number、string、boolean、null、undefined、NaN。
- [ ] 每项在运行前有预期值、预期 typeof 和正确断言方法。
- [ ] 有显式转换、严格相等和保留零值的空值合并案例。
- [ ] 保存源码、预测、实际 stdout/stderr、退出码、Node 路径和完整版本。

### Diagnose

- [ ] 能用值+类型证据定位宽松相等误判。
- [ ] 能用操作数类型定位 `+` 拼接，而不是改用隐蔽转换技巧。
- [ ] 能证明 `||` 丢失 0，并按合同改为 `??`。
- [ ] 每次单点修复并重跑原断言，说明 NaN、空字符串或对象引用残余风险。

## 边界与后续

本章不教授分支、循环、函数、对象完整模型、JSON、DOM 表单验证或 TypeScript 类型收窄。下一章会把这里得到的布尔值、严格比较和空值规则用于选择与重复。若值矩阵还不能独立预测，不要急着用 `if` 把类型错误藏成某个分支。

## 官方资料与核验日期

以下一手资料于 **2026-07-17** 核验：

- [ECMAScript 2026：Data Types and Values](https://tc39.es/ecma262/2026/multipage/ecmascript-data-types-and-values.html)
- [ECMAScript 2026：Type Conversion](https://tc39.es/ecma262/2026/multipage/abstract-operations.html#sec-type-conversion)
- [ECMAScript 2026：Testing and Comparison Operations](https://tc39.es/ecma262/2026/multipage/abstract-operations.html#sec-testing-and-comparison-operations)
- [ECMAScript 2026：Equality Operators](https://tc39.es/ecma262/2026/multipage/ecmascript-language-expressions.html#sec-equality-operators)
- [ECMAScript 2026：Coalesce Expression](https://tc39.es/ecma262/2026/multipage/ecmascript-language-expressions.html#sec-coalesce-expression)
- [Node.js Releases](https://nodejs.org/en/about/previous-releases)
- [Node.js v24 Assert](https://nodejs.org/download/release/latest-v24.x/docs/api/assert.html)

语言类型、严格相等与求值规则是稳定核心；Node 维护状态和 patch 版本是易变事实。核验日 Node v24（Krypton）仍列为 LTS，正式项目通过版本文件与 CI 固定实际 patch。
