# 第 23 周：JavaScript 值、作用域、函数、对象、原型与模块

## 定位

本周把“会写 Vue 中的 JS”还原成可解释的 JavaScript 语言能力。重点是值与引用、作用域/闭包、函数调用、对象/原型、类语法和模块；DOM、事件循环与网络在 Week 24。已有经验不重复刷教程，而是通过预测、最小实现和故障说明校准心智模型。

时间预算：15—18 小时。使用 Node LTS 运行纯 JS 测试，禁止用 TypeScript 类型提示掩盖运行时行为。

## 前置

- Week 22 的原生 HTML/CSS 页面和可访问性基线通过；
- 能使用 Node、pnpm、ES modules 和测试运行器；
- 能在 DevTools/Node 调试器设置断点；
- 接受对熟悉语法重新验证，而不是按工作年限免测。

## 目标

- 理解 primitive、object、引用共享、相等性和类型转换；
- 掌握 lexical scope、hoisting、temporal dead zone 与 closure；
- 理解函数声明/表达式/箭头、参数、返回值、rest/spread；
- 理解调用方式决定 `this`，箭头函数不创建自己的 `this`；
- 正确创建、读取、复制和遍历对象/数组；
- 理解 prototype chain、constructor/class 语法与私有字段；
- 使用 ES modules 设计明确边界并识别循环依赖；
- 用纯函数实现 FactoryCare 状态与统计规则。

## 完整概念清单

### 值、类型与转换

- `undefined/null/boolean/number/bigint/string/symbol` 与 object；
- `typeof` 的边界，`typeof null` 历史行为；
- number 浮点、NaN、Infinity、`Object.is`、`Number.isNaN`；
- truthy/falsy 与显式判断，`||` 和 `??` 不同；
- `==` 隐式转换风险、默认使用 `===`；
- primitive 按值复制，对象变量复制引用；
- 浅复制、深复制、`structuredClone` 的能力和限制；
- const 限制重新赋值，不使对象不可变；
- 可变数据、不可变更新和结构共享的成本。

### 作用域与闭包

- global/module/function/block scope；
- `let/const/var`、hoisting、TDZ 和重复声明；
- lexical scope 由定义位置决定；
- closure 保留可访问环境，不等于必然内存泄漏；
- 循环闭包、计时器和 `var` 的经典陷阱；
- closure 适合封装状态/工厂，长期引用大型对象会增加保留；
- 模块顶层不是浏览器全局对象属性。

### 函数

- 声明、表达式、箭头、IIFE 了解；
- JS 不按参数类型/个数重载，额外参数与缺少参数行为；
- default/rest 参数、spread 调用、destructuring 参数；
- 函数是一等值，可传递、返回和存入对象；
- callback、高阶函数和纯函数；
- parameter/argument、返回 `undefined`、早返回；
- 默认参数和解构的副作用/求值时机；
- 递归、调用栈与基础终止条件。

### this 与调用方式

- 普通函数的 `this` 由调用形式决定；
- method call、plain call、constructor call、`call/apply/bind`；
- 箭头函数捕获外层 `this`，不适合作为需要动态接收者的方法；
- 解构/传递方法导致接收者丢失；
- class 方法默认严格模式；
- 能避免 `this` 就保持简单，不为面试谜题设计代码。

### 对象、数组与属性

- object literal、computed key、shorthand、destructuring；
- property descriptor、enumerable/writable/configurable 只做基础实验；
- own 与 inherited 属性，`Object.hasOwn`；
- `Object.keys/values/entries/fromEntries`；
- optional chaining 与 nullish coalescing；
- array 是特殊对象，稀疏数组、length 和常用 mutating/non-mutating 方法；
- sort 默认字符串比较，比较函数必须一致；
- Map/Set/WeakMap/WeakSet 的高层选择。

### 原型与 class

- 对象内部原型链与属性查找；
- constructor function、`new` 的高层步骤；
- `prototype` 属性与对象原型不要混淆；
- `class` 是基于原型的语法层，不把 JS 当 Java；
- constructor、instance/static method、public/private field、extends/super；
- 组合通常比复杂继承更清晰；
- prototype pollution 高层风险，不合并不可信特殊键。

### 模块

- ESM 的 named/default export、static import、dynamic import；
- live binding、模块单例和顶层副作用；
- browser/Node 模块解析差异由工具配置处理；
- 循环依赖可能读取未初始化绑定；
- CommonJS 只为读旧项目建立概念；
- 模块边界按职责/变化组织，不创建 `utils` 垃圾桶。

## 时间与任务

| 任务 | 时间 | 产出 |
| --- | ---: | --- |
| 值/相等/复制 | 2h | 预测表和浅复制故障 |
| 作用域/闭包 | 2—3h | 计数器、循环捕获和资源保留实验 |
| 函数/this | 2—3h | 四种调用方式与丢失接收者复现 |
| 对象/原型/class | 3h | 属性查找、组合与继承对比 |
| 模块与测试 | 2h | 纯 ESM 规则包和循环依赖反例 |
| FactoryCare/复盘 | 3—5h | 纯 JS 工单规则、故障和独立变更 |

## FactoryCare 增量

- 纯 JS 实现 `canTransition(order, nextStatus)`、筛选和技师负载统计；
- 不修改输入对象，测试证明浅复制嵌套对象可能仍共享；
- 把状态表、规则函数、统计函数分成明确 ESM；
- 制造 `this` 丢失、闭包捕获旧状态、隐式转换三个故障；
- 与 Java 版本比较：类型、对象模型、相等性、模块和运行时验证差异。

## 无 AI 任务（120 分钟）

实现纯 JS `workOrderStore`：添加、按 ID 查询、状态转换、过滤和订阅变化。要求不暴露内部可变数组、取消订阅有效、重复 ID 明确失败、测试覆盖闭包状态和引用泄漏。答辩为何使用 closure、class 或普通对象。

## 验收

- 能解释 `const`、浅复制、`===`、`Object.is` 和引用共享；
- 能画出一个闭包保留的变量，不把所有闭包叫内存泄漏；
- 能依据调用形式判断 `this`，并修复方法脱离对象问题；
- 能说明 class 与 prototype 的关系；
- 纯 JS 规则包和测试可从命令行运行；
- 能独立修改状态规则且不破坏模块边界。

## 非目标

- 不做晦涩 coercion/`this` 面试谜题题海；
- 不进入 DOM、Promise 调度和 Fetch，留到 Week 24；
- 不用 TypeScript 或 Vue；
- 不深入 JS 引擎源码和 GC 算法。
