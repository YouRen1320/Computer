---
schema_version: 2
edition: 2026.2-draft
id: ch.js.object-model
title: this、原型、class 与对象模型
responsibility: 解释属性查找、this 绑定、原型链和 class 语法糖，能在组合与共享方法之间选择，不把 class 等同于 Java 类。
volume: '08'
order: 8
level: L2
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.js.object-model.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.js.collections
version_surfaces:
- node-24-lts
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“this、原型、class 与对象模型”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - js-this-prototype
  - js-class-composition
  covers_topics:
  - js.this-call-site
  - js.prototype-chain
  - js.property-lookup
  - js.own-vs-inherited
  - js.class-syntax
  - js.constructor-new
  - js.private-field
  - js.composition-object
  - js.array-index-iteration
  uses_capabilities:
  - web.javascript-language
  - web.javascript-objects
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现组合式工单对象和共享原型方法并证明实例状态隔离；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - js-this-prototype
  - js-class-composition
  covers_topics:
  - js.this-call-site
  - js.prototype-chain
  - js.property-lookup
  - js.own-vs-inherited
  - js.class-syntax
  - js.constructor-new
  - js.private-field
  - js.composition-object
  - js.array-index-iteration
  uses_capabilities:
  - web.javascript-language
  - web.javascript-objects
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: property-lookup-trace-identity-assertions-call-site-matrix
- id: diagnose
  kind: fault-diagnosis
  text: 面对“方法脱离调用者、原型污染或共享可变字段造成的行为漂移”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - js-this-prototype
  - js-class-composition
  covers_topics:
  - js.this-call-site
  - js.prototype-chain
  - js.property-lookup
  - js.own-vs-inherited
  - js.class-syntax
  - js.constructor-new
  - js.private-field
  - js.composition-object
  - js.array-index-iteration
  uses_capabilities:
  - web.javascript-language
  - web.javascript-objects
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# this、原型、class 与对象模型

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《数组、对象、Map、Set 与不可变更新》](ch.js.collections.md)：对象属性、键身份和数据集合提供验证原型与实例边界的基础。
<!-- END GENERATED LEARNING PREREQUISITES -->

把 `workOrder.summary` 保存到变量再调用，为什么原来能用的方法突然读不到 `id`？两个实例为什么能共享同一个方法函数，却不应共享同一个 `notes` 数组？给对象赋一个与原型同名的属性后，为什么删除自身属性又“恢复”旧值？`class` 看起来像 Java 类，它在 JavaScript 中是否建立了相同的类型、访问控制和继承模型？

这些现象来自同一套对象模型：对象有自身属性和一个原型；读取属性时沿原型链查找；普通方法里的 `this` 由调用方式提供，不由函数写在哪个对象字面量里永久固定；`class` 用更集中、更严格的语法建立构造器、原型方法和实例元素，但底层仍在 JavaScript 的动态对象与原型机制上。本章要用属性来源追踪、调用点矩阵和引用身份断言证明这些边界。

## 完成定义与 canonical 预言

你需要完成三类证据：

1. 在 120 秒内解释 `this` 调用点、属性查找、原型链、自身/继承属性、`class/new`、私有字段与组合，并给出不应由对象模型解决的反例；
2. 从空目录实现组合式工单对象与共享原型方法，证明多个实例的可变状态相互隔离；
3. 对方法脱离调用者、原型污染、共享可变字段三类故障，定位首个可信证据，修复后重跑同一验证。

本章 T1 预言原文是：**不同调用方式、实例和原型修改下的 this、属性来源和引用身份与追踪表一致。** 验证方法是 `property-lookup-trace`、`identity-assertions` 和 `call-site-matrix`。只看到最终字符串正确还不够：若两个实例碰巧还没修改共享数组，别名已经是失败；若绑定方法能运行，却把接收者固定错了，也失败。

## JavaScript 对象不是“装字段的袋子”

对象是一组属性以及一个指向对象或 `null` 的原型联系。属性键是字符串或 Symbol；属性可由数据描述符或访问器描述符定义。日常代码的 `object.key` 会触发语言的内部获取过程，而不是仅查询一张自身字段表。

先建立一个不依赖 `class` 的最小模型：

```js
// workOrderBehavior 只保存可共享行为，不保存任何实例可变数组。
const workOrderBehavior = {
  kind: "work-order",
  summary() {
    return `${this.id}:${this.status}`;
  },
};

// first 以 workOrderBehavior 为原型，再拥有自己的 id/status/notes。
const first = Object.create(workOrderBehavior);
first.id = "WO-101";
first.status = "CREATED";
first.notes = [];
```

`Object.create(proto)` 让新对象的原型成为 `proto`。`first.id` 是自身属性；`first.kind` 不是自身属性，却能沿原型读到；`first.summary` 解析到原型上的同一个函数，然后以 `first` 作为调用接收者。

规范中的 `[[Prototype]]` 是内部槽名称，不等于普通属性 `prototype`。构造函数的 `prototype` 属性通常被 `new` 用作新实例的 `[[Prototype]]`；实例本身通常没有一个名为 `prototype` 的特殊自身属性。把这三个概念分开，是避免原型题混乱的第一步。

## 属性查找：自身、原型、直到 null

对普通对象读取 `receiver.name`，可以用以下追踪模型预测：

1. 检查 `receiver` 自身是否有 `name`；
2. 若没有，取得 `receiver` 的原型；
3. 在该原型检查自身 `name`；
4. 重复，直到找到属性或原型为 `null`；
5. 找不到的数据属性读取结果通常是 `undefined`。

```js
// 这些检查把值、来源和链路分开。
console.log(first.kind);                          // work-order
console.log(Object.hasOwn(first, "kind"));       // false
console.log("kind" in first);                    // true
console.log(Object.getPrototypeOf(first) === workOrderBehavior); // true
```

`Object.hasOwn(object, key)` 只检查自身；`key in object` 检查整条链；直接读取告诉你最终值，却不告诉来源。三者回答不同问题，调试时不能互换。

### 自身属性遮蔽原型属性

```js
// 写入同名自身属性后，查找在 first 就停止。
first.kind = "urgent-work-order";
console.log(first.kind);                    // urgent-work-order
console.log(Object.hasOwn(first, "kind")); // true

// 删除自身属性不会删除原型属性；下一次读取又沿链找到 work-order。
delete first.kind;
console.log(first.kind);                    // work-order
```

这不是原型值被“复制回来”，而是查找路径改变。调试行为漂移应记录每一步的 `owner`、`key`、描述符和值，不要只打印最终值。

### 赋值不总是简单创建自身属性

若原型上是普通可写数据属性，给接收者赋值通常会在接收者创建同名自身属性；若原型属性不可写，严格模式赋值会失败；若原型上是 setter，赋值会调用 setter，是否创建自身数据属性取决于 setter。完整语义由属性描述符和 `[[Set]]` 决定。

```js
// getOwnPropertyDescriptor 给出属性来源处的数据/访问器描述。
const descriptor = Object.getOwnPropertyDescriptor(workOrderBehavior, "kind");
console.log(descriptor.writable);   // true
console.log(descriptor.enumerable); // true（对象字面量数据属性）
```

本章资产用普通可写数据属性与方法，避免把访问器副作用混进主预言；遇到“赋值后没有自身属性”时，检查原型链上的描述符。

### 不用 __proto__ 作为主线 API

读取原型用 `Object.getPrototypeOf`，创建指定原型对象用 `Object.create`。`Object.setPrototypeOf` 会在运行时改变链路，可能影响优化并增加推理成本；业务对象优先在创建时固定原型。`__proto__` 是遗留访问器，不是教学与生产代码的默认 API。

## this：看调用表达式，不看“函数属于谁”

普通函数不会因赋给某个属性就永久记住该对象。以下两个调用使用同一个函数值，却提供不同 `this`：

```js
// summary 来自原型；点调用把点左侧 first 作为接收者。
const direct = first.summary();

const second = Object.create(workOrderBehavior);
second.id = "WO-102";
second.status = "ASSIGNED";
second.notes = [];

// call 显式把 second 作为本次调用的 this。
const borrowed = first.summary.call(second);
```

预测 `this` 时先圈出“真正的调用括号”，再看该函数如何被调用。

| 调用表达式（ESM/严格语境） | 普通函数中的 `this` | 说明 |
| --- | --- | --- |
| `object.method()` | `object` | 属性引用保留接收者 |
| `method()` | `undefined` | 脱离对象的普通调用 |
| `method.call(value, a)` | `value` | 显式逐个参数 |
| `method.apply(value, args)` | `value` | 显式参数数组/类数组 |
| `bound()` | 创建 bound 时固定的值 | `bind` 返回新函数 |
| `new Constructor()` | 新建实例 | 构造调用有专门语义 |
| 箭头函数调用 | 取定义处词法 `this` | call/apply/bind 不能改其 `this` |

非严格传统脚本对普通调用的 `this` 有全局对象替换等历史行为。本章所有 `.mjs` 都是 ESM 严格语义，脱离调用者后 `this === undefined`，从而尽早失败。不要用“浏览器里 this 总是 window”作为通则。

### 方法脱离调用者

```js
// 错误边界：只保存函数值，属性引用中的接收者 first 丢失。
const detached = first.summary;
detached(); // TypeError：summary 读取 undefined.id
```

首个可信证据可以是调用点形状从 `first.summary()` 变成 `detached()`；TypeError 是后续表现。修复选项取决于合同：

- 调用时仍有对象：写 `first.summary()`；
- 本次借用给另一对象：`detached.call(second)`；
- 回调 API 需要长期保留接收者：`const bound = first.summary.bind(first)`；
- 函数其实只需要显式数据：改为 `summary(first)` 的纯函数，消除动态接收者。

不要见到 `this` 错误就全部 `bind`。绑定函数创建新身份，会影响移除事件监听器、测试替换和内存生命周期；显式参数往往更适合无状态转换。

### 括号、条件与回调传递会改变调用形状

`array.map(first.summary)` 把函数交给 `map`；`map` 调用回调时不会自动把 `first` 当接收者，还会传元素、索引和数组。正确做法可能是 `array.map(() => first.summary())`、预先绑定，或把方法重构为接受元素的函数。先写回调合同，不要靠参数恰好对齐。

### 箭头函数的词法 this

箭头函数没有自己的 `this` 绑定，它读取定义处外层 `this`。这对保留外层接收者的内部回调有用：

```js
// schedulePreview 的普通方法由调用点提供 this；内部箭头继续读取同一个 this。
const presenter = {
  id: "WO-101",
  schedulePreview(run) {
    run(() => this.id);
  },
};
```

把需要动态接收者的共享方法写成箭头属性则会改变设计：每个实例往往得到一个新函数，并捕获创建上下文；对象字面量顶层箭头也不会把对象自身作为 `this`。需要原型共享和动态接收者时使用普通方法语法。

## 原型链：共享行为，不共享实例可变状态

两个实例可以解析到同一个原型方法：

```js
// 两个读取结果指向同一个函数对象，这是共享行为证据。
console.log(first.summary === second.summary); // true
console.log(first.notes === second.notes);     // false
```

方法通常无状态，读取调用接收者上的数据；因此共享一个函数节省创建成本并保持统一行为。数组、对象或 `Map` 这类可变实例状态必须在每个实例创建时新建。

### 共享可变字段的经典故障

```js
// 错误：notes 放在原型上，所有没有自身 notes 的实例都会读到同一数组。
const brokenBehavior = {
  notes: [],
  addNote(note) {
    this.notes.push(note);
  },
};

const left = Object.create(brokenBehavior);
const right = Object.create(brokenBehavior);
left.addNote("checked");
console.log(right.notes.length); // 1，发生跨实例泄漏
```

首个可信证据是创建后 `left.notes === right.notes` 为真，不必等第二个工单显示别人的备注。修复是在工厂或构造器中为每个实例创建 `notes = []`。残余风险是数组元素若为共享可变对象，仍可能在更深层别名。

### 原型污染为何危险

原型污染泛指不受信数据或无约束代码向共享原型写入属性，使许多对象的查找结果一起改变。最危险的是修改 `Object.prototype` 等广泛祖先：

```js
// 反例：禁止把外部键和值直接写入 Object.prototype。
Object.prototype.isAdmin = true;
```

之后没有自身 `isAdmin` 的对象也可能通过 `"isAdmin" in object` 或直接读取看到污染值。不要运行此反例于应用进程。边界措施包括：不合并危险键到原型、使用字段白名单、对记录数据用明确 schema 验证、需要无原型字典时用 `Object.create(null)`，以及检查 `Object.hasOwn`。但无原型对象也缺少常用原型方法，并非所有普通对象的替代品。

局部业务原型同样可能被意外修改：

```js
// 修改共享 behavior 会同时改变所有未遮蔽 kind 的实例。
workOrderBehavior.kind = "polluted";
```

第一个可信证据是写入目标的所有者为共享原型，而不是单个实例。修复不是在每个读取处打补丁，而是收紧写入入口、避免让外部数据决定属性路径，并在需要时冻结由应用拥有的行为对象。冻结是浅层机制，不能替代输入验证。

### 不修改内建原型

不要为了方便给 `Array.prototype`、`Object.prototype` 或 `Map.prototype` 增加业务方法。它会影响整个 realm、第三方代码、枚举与未来标准同名方法。写普通函数、模块导出或组合对象即可。数组确实通过 `Array.prototype` 获得 `map/filter` 等方法，这一事实用来理解查找，不是鼓励 monkey patch。

## 构造函数与 new：旧语法也走原型

在 `class` 之前，普通可构造函数配合 `new` 建立实例：

```js
// WorkOrder 构造器只初始化每个实例自己的状态。
function WorkOrder(id, status) {
  this.id = id;
  this.status = status;
  this.notes = [];
}

// summary 放在 prototype 上，由所有实例共享。
WorkOrder.prototype.summary = function summary() {
  return `${this.id}:${this.status}`;
};

const item = new WorkOrder("WO-201", "CREATED");
```

把 `new WorkOrder(...)` 作为概念步骤理解：

1. 创建一个新对象；
2. 通常把新对象的原型连接到 `WorkOrder.prototype`；
3. 以新对象作为 `this` 调用构造器；
4. 若构造器没有显式返回另一个对象，返回这个新对象。

细节还涉及 `newTarget`、派生构造器和显式返回值，主线先用身份断言确认：

```js
console.log(Object.getPrototypeOf(item) === WorkOrder.prototype); // true
console.log(item.summary === WorkOrder.prototype.summary);        // true
```

遗漏 `new` 调用传统构造函数，在严格模式会因 `this === undefined` 尽早失败；非严格脚本可能污染全局。`class` 构造器则语法层面要求通过 `new` 调用，更安全清晰。

## class：原型机制上的集中语法

`class` 把构造器、实例方法、静态方法、字段和私有元素写在一个声明里：

```js
// Formatter 是组合进来的能力；WorkOrderView 不负责决定合法状态迁移。
class WorkOrderView {
  #status;

  constructor(id, status, formatter) {
    this.id = id;
    this.#status = status;
    this.formatter = formatter;
    this.notes = [];
  }

  summary() {
    return this.formatter.format(this.id, this.#status);
  }

  addNote(note) {
    this.notes.push(note);
  }

  get status() {
    return this.#status;
  }
}
```

`summary` 与 `addNote` 位于 `WorkOrderView.prototype`，不同实例读取到同一方法函数；`id`、`formatter`、`notes` 与 `#status` 在实例初始化时建立。类体代码按严格模式执行，类声明受词法作用域和初始化时机约束，类构造器不能当普通函数调用。

`class` 不只是字符级“语法糖”：它提供方法属性特征、严格语义、派生类初始化、字段与私有元素等成套规则；但它没有把 JavaScript 变成 Java 的名义静态类型系统。实例的普通公开属性仍可动态添加/删除，方法仍通过原型查找，`this` 仍受调用方式影响。

### 方法共享与字段初始化时机

```js
const formatter = {
  // format 是无状态协作者；数据通过显式参数进入。
  format(id, status) {
    return `${id}:${status}`;
  },
};

const alpha = new WorkOrderView("WO-301", "CREATED", formatter);
const beta = new WorkOrderView("WO-302", "ASSIGNED", formatter);

console.log(alpha.summary === beta.summary); // true
console.log(alpha.notes === beta.notes);     // false
```

若把 `notes = []` 写成公共实例字段，规范也会为每个实例初始化一次；若写成 `static notes = []`，则它属于类构造器并被共享。判断是否安全不要只看方括号位置，要问“初始化发生几次，属性所有者是谁”。

### 静态方法不属于实例

`static fromSnapshot(snapshot, formatter)` 会成为 `WorkOrderView.fromSnapshot`，不在 `alpha` 的原型查找路径上。静态工厂适合创建实例或提供与特定实例无关的类级操作；不要把可变租户数据放在静态字段里伪装全局仓库。

## 私有字段：词法私有名与实例品牌

`#status` 不是名为 `"#status"` 的普通字符串属性。它使用私有名，在类定义可见范围内解析，并要求接收者具有相应私有元素：

```js
console.log(alpha.status); // 通过公开 getter 读取

// 在类体外写 alpha.#status 是语法错误，不是得到 undefined。
```

用另一个类的方法强行读取不具备品牌的对象，会在运行时失败。`Object.keys`、对象 spread 和普通属性反射不会把私有字段当作自身可枚举字符串属性。下划线字段 `_status` 只是一种命名约定，外部仍可直接读写，不等于 `#status`。

私有字段适合保护对象内部不变量免受普通调用者误用，但它不是安全边界：运行时代码仍可调用对象公开方法，浏览器用户控制自己的进程，服务端授权不能靠前端私有字段。它也不是持久化格式；序列化要通过明确 DTO 方法选出公开数据。

### 私有状态与测试

测试不应绕过 `#status`。通过公开行为验证不变量：构造后 `summary()`、合法公开更新方法、非法输入错误。若必须读取每一个内部槽才能测试，设计可能把职责混得太大。私有字段的“看不见”不是免测，而是要求面向合同测试。

## 组合：把能力作为对象传入

组合让对象持有协作者而不是继承其实现：

```js
// createPresenter 的数据源是调用者给出的 formatter 与 clock。
function createPresenter(formatter, clock) {
  return {
    preview(workOrder) {
      return {
        label: formatter.format(workOrder.id, workOrder.status),
        renderedAt: clock.now(),
      };
    },
  };
}
```

这里 presenter “拥有/使用”格式化与时钟能力，不声称自己“是一个 Formatter”或“是一个 Clock”。测试可传入确定性协作者；生产可替换语言格式或时间来源。组合的关键不是把所有东西塞进对象，而是给协作者小而明确的合同。

### 何时选择共享原型方法

适合：

- 多个实例都有同一无状态行为；
- 方法通过动态 `this` 读取实例自身状态；
- 需要方法身份共享；
- 对象确实有稳定的行为边界。

不适合：

- 函数只做输入到输出的转换，显式参数更清楚；
- 方法经常脱离实例作为回调，动态接收者只制造风险；
- 所谓“对象”只是网络 DTO，没有生命周期或行为；
- 为复用几行代码建立深继承层级。

### 何时优先组合

当关系是“使用某能力”而不是稳定的 “is-a”，或需要独立替换策略、格式器、存储端口时，组合通常更清楚。继承会把原型链、构造顺序、可重写行为和父类不变量绑在一起；这些内容在后续专章系统讨论，本章只要求能在共享方法与组合协作者之间作出解释。

## 不把 class 等同于 Java 类

| 维度 | JavaScript `class` | Java 类（概念对比） |
| --- | --- | --- |
| 核心运行模型 | 对象、原型、函数与内部槽 | 类加载、名义类型、字段/方法布局等 JVM 模型 |
| 类型检查 | JS 本身动态；运行时按值与操作 | 编译期名义类型检查为主 |
| 公开属性 | 可动态增删普通属性 | 字段由类声明，反射是另一机制 |
| 方法分派 | 属性查找沿原型链，`this` 由调用方式提供 | 实例方法接收者由调用语法和 JVM 调度规则确定 |
| 私有 | `#name` 私有名/品牌检查 | `private` 访问控制与类成员模型 |
| 复用 | 原型、组合、类继承 | 类/接口继承、组合 |

这个表只帮助防止错误类比，不在 JavaScript 章教授完整 Java 对象模型。TypeScript 可在编译期增加结构类型与可见性检查，但运行时仍执行 JavaScript；TypeScript 专章再讨论“类型擦除”和运行时验证边界。

## 调用点矩阵：先预测再执行

以 `summary` 为普通原型方法，准备两个实例：

| 编号 | 表达式 | 预测 this | 预测结果 |
| --- | --- | --- | --- |
| C1 | `alpha.summary()` | `alpha` | `WO-301:CREATED` |
| C2 | `const f = alpha.summary; f()` | `undefined` | TypeError |
| C3 | `f.call(beta)` | `beta` | `WO-302:ASSIGNED` |
| C4 | `f.apply(beta, [])` | `beta` | `WO-302:ASSIGNED` |
| C5 | `f.bind(beta)()` | 固定 `beta` | `WO-302:ASSIGNED` |
| C6 | `alpha.summary.call({ id: "X" })` | 普通对象 | 若依赖 `#status`，品牌检查失败 |

C6 揭示普通公开字段方法与私有字段方法的差异：前者可能被任意形状相似对象借用，后者要求接收者具有该类私有品牌。不要把此差异简单归为“更安全”；它是可借用性与封装边界的设计选择。

## 属性查找追踪表

每次行为异常，记录如下：

| 步骤 | receiver | key | owner | own? | value/descriptor |
| --- | --- | --- | --- | --- | --- |
| P1 | `first` | `kind` | `workOrderBehavior` | 否 | `"work-order"` |
| P2 | `first`（写入后） | `kind` | `first` | 是 | `"urgent"` |
| P3 | `first`（delete 后） | `kind` | `workOrderBehavior` | 否 | `"work-order"` |
| P4 | `first` | `summary` | `workOrderBehavior` | 否 | 与 `second.summary` 同一函数 |

必要时用以下只读探针：

```js
// traceProperty 只返回诊断数据，不修改链。
function traceProperty(receiver, key) {
  const trace = [];
  let current = receiver;

  while (current !== null) {
    trace.push({
      owner: current,
      hasOwn: Object.hasOwn(current, key),
      descriptor: Object.getOwnPropertyDescriptor(current, key),
    });
    if (Object.hasOwn(current, key)) {
      break;
    }
    current = Object.getPrototypeOf(current);
  }

  return trace;
}
```

不要把对象直接 JSON 序列化来追原型：JSON 只处理选定自身可枚举字符串属性，不保存原型链、方法、Symbol 或私有元素。

## 三类关键故障

### 1. this-binding-loss

现象：`const render = item.summary; render()` 失败或读取错误对象。

首个可信证据：调用表达式没有基值对象，ESM 中普通函数接收 `undefined`。修复：保持点调用、明确 `call`、只在需要长期回调时 `bind`，或改为显式参数纯函数。残余风险：绑定函数身份不同；如果之后还需要用原函数移除监听器，必须保存同一 bound 引用。

### 2. prototype-pollution

现象：未赋值的对象突然有 `isAdmin/kind/status`，多个无关实例一起变化。

首个可信证据：`Object.hasOwn(receiver, key) === false`，却有 `key in receiver`，追踪 owner 指向共享原型。修复：停止不受控原型写入，白名单复制键，必要时用无原型字典或冻结应用自有行为对象。残余风险：更高层原型、其他 realm、已有污染值和依赖库输入路径仍需检查。

### 3. shared-instance-state

现象：向 alpha 的 `notes` 添加值后 beta 也出现。

首个可信证据：修改前 `alpha.notes === beta.notes` 为真，且属性 owner 位于原型或静态对象。修复：构造时为每个实例新建可变集合。残余风险：notes 内元素对象仍可能共享，组合协作者若有内部可变状态也可能跨实例共享。

## 故障诊断顺序

1. 固定两个实例和一个可重复调用；
2. 写调用点矩阵，圈出调用括号与接收者；
3. 对异常属性同时运行直接读取、`Object.hasOwn`、`in`；
4. 沿 `Object.getPrototypeOf` 追 owner，不先改链；
5. 对数组、对象、`Map` 等可变字段做 `===` 身份断言；
6. 检查字段在哪个时刻初始化：原型创建、静态初始化还是每次构造；
7. 一次只修一个根因，重跑原矩阵和追踪表；
8. 记录尚未验证的访问器、Proxy、跨 realm 或第三方合并路径。

`instanceof` 可作为补充证据，但它通常检查构造器 `prototype` 是否出现在对象原型链上；原型被替换、跨 realm 或自定义 `Symbol.hasInstance` 时，直觉会失效。不要用它替代业务 schema 验证。

## FactoryCare 边界

本章的对象可作为前端展示模型：共享 `summary` 行为、组合 formatter、为每个工单保存独立的 UI notes。它不能成为 FactoryCare 工单状态权威。`#status` 只阻止普通 JavaScript 代码直接访问私有名，不会校验 `CREATED → TRIAGED`、租户权限、审批、SLA、乐观锁、审计或领域事件。

前端也不应通过修改 `WorkOrderView.prototype` 动态下发业务规则；服务端返回事实与允许操作，前端对象只呈现并发出明确命令。若网络 DTO 只是数据，保留普通对象可能比建立类更清楚。只有稳定行为、生命周期或封装价值足够时才引入类。

## 环境与版本证据

教材版本面是 `node-24-lts`。截至 2026-07-17，Node.js 官方发布表列 v24 “Krypton”为 LTS；ECMAScript 2026 规范定义本章使用的普通对象内部方法、函数调用、类定义、私有元素与数组原型链。资产使用 `.mjs`，确保严格 ESM 下脱离方法的 `this` 可预测。

建议保存：

```bash
node --version
node --check src/object-model.mjs
./verify.sh
```

不同运行时的对象格式化和错误栈文本可能不同，因此 verifier 比较稳定的业务输出与自定义故障标记，不逐字锁定引擎 TypeError 文案。浏览器未实际执行就标记未验证；规范一致性不是设备兼容性测试。

## 120 秒讲述模板

> JavaScript 对象有自身属性和一个指向对象或 null 的原型。读取属性先查自身，再沿原型链；Object.hasOwn 只看自身，in 会看整条链。普通方法的 this 由调用点决定：obj.method() 接收 obj，ESM 中脱离后的 method() 接收 undefined，call/apply/bind 可显式提供。共享无状态方法适合放在原型，可变数组必须每个实例初始化。class 把构造器、原型方法、字段与私有元素集中书写，但运行时仍是 JavaScript 对象和原型，不等同于 Java 的名义静态类。组合用于“使用某能力”，例如注入 formatter。证据是调用点矩阵、属性 owner 追踪和实例引用身份。不应由本章解决的反例是服务端状态迁移和权限。

讲述若只背“this 指向调用者”，必须补充箭头函数、严格普通调用与 `new`；若只说“class 是语法糖”，必须说明类严格语义、字段和私有元素；若把私有字段说成安全授权，说明越过了运行环境边界。

## 独立练习

1. 画出 `first.summary()` 的两段过程：先查找函数，再用 first 调用；
2. 预测自身 kind、遮蔽 kind、删除后 kind 的 owner，并用描述符验证；
3. 用同一方法完成点调用、detached、`call`、`apply`、`bind` 五行矩阵；
4. 建立两个实例，断言方法身份相同、notes 身份不同；
5. 故意把 notes 放在原型，保存第一次失败，再迁回构造初始化；
6. 在隔离故障程序中演示共享业务原型被写后两个实例一起漂移，不修改内建原型；
7. 用 `class` 与 `#status` 重写实例，并证明普通对象借用私有方法失败；
8. 把 formatter 作为组合协作者传入，说明为什么不需要继承；
9. 给 FactoryCare 展示对象写边界说明：能格式化，不能授权或迁移状态；
10. 从空目录运行公开 exercise，依次修复三个故障标记，不查看 private solution。

## 官方一手资料

以下页面于 **2026-07-17** 核对：

- [ECMAScript 2026：Ordinary and Exotic Objects Behaviours](https://tc39.es/ecma262/2026/multipage/ordinary-and-exotic-objects-behaviours.html)：普通对象的原型、属性查找与设置内部方法；
- [ECMAScript 2026：ECMAScript Language Functions and Classes](https://tc39.es/ecma262/2026/multipage/ecmascript-language-functions-and-classes.html)：函数调用、`this` 模式、构造器、类与字段；
- [ECMAScript 2026：Expressions](https://tc39.es/ecma262/2026/multipage/ecmascript-language-expressions.html)：属性访问、调用表达式、对象初始化器与箭头函数；
- [ECMAScript 2026：Indexed Collections](https://tc39.es/ecma262/2026/multipage/indexed-collections.html)：数组作为 exotic object 及 `Array.prototype`；
- [Node.js Releases](https://nodejs.org/en/about/previous-releases)：v24 LTS 状态；
- [Node.js v24 assert 文档](https://nodejs.org/download/release/latest-v24.x/docs/api/assert.html)：验证资产的严格断言接口。

规范确认语言合同，不能代替本机、浏览器或跨版本运行证据。
